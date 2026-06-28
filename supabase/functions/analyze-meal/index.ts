// =============================================================================
// AI 식단 판독 Edge Function (analyze-meal)
//
// 동작:
//   1) 호출자(JWT)를 검증하고, 본인 소유의 식사 기록만 분석.
//   2) 비공개 버킷(meal-photos)에서 사진을 서비스 롤로 내려받아 base64 인코딩.
//   3) Claude(claude-opus-4-8, 비전)에게 "현재 단계 규칙 + 사진"을 주고
//      구조화된 판정을 강제(tool_choice)로 받아옴. (Anthropic REST 직접 호출)
//   4) 결과를 meal_logs 에 기록. verdict='violation' 이면 rule_violation=true.
//   5) 결과 JSON 을 클라이언트에 반환.
//
// 필요한 환경변수(Function Secrets):
//   ANTHROPIC_API_KEY                         (필수 — 콘솔에서 발급)
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY   (보통 자동 주입)
//   SUPABASE_ANON_KEY                          (보통 자동 주입)
//
// 외부 SDK 없이 fetch 만 사용해 부팅 실패 위험을 없앤 버전.
// =============================================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MODEL = "claude-opus-4-8";
const MAX_PHOTOS = 2; // 비용·지연 통제: 최대 2장만 분석

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface Body {
  meal_id: string;
  week: number;
  day: number;
  stage_title: string;
  allowed_foods: string[];
  forbidden_foods: string[];
  meal_plan: string;
}

const ANALYSIS_TOOL = {
  name: "report_meal_analysis",
  description:
    "사진 속 식사가 현재 다이어트 단계에 부합하는지 판정한 결과를 보고한다.",
  input_schema: {
    type: "object",
    properties: {
      foods: {
        type: "string",
        description:
          "사진에서 인식한 음식들을 한국어로, 콤마로 구분 (예: '현미밥, 닭가슴살, 김치')",
      },
      verdict: {
        type: "string",
        enum: ["fit", "caution", "violation"],
        description:
          "fit=단계에 적합, caution=대체로 괜찮으나 양·종류 주의, violation=현재 단계에서 제한되는 음식 포함",
      },
      score: {
        type: "integer",
        minimum: 0,
        maximum: 100,
        description: "현재 단계 부합도 점수 (100=완벽히 부합)",
      },
      feedback: {
        type: "string",
        description: "따뜻하고 구체적인 피드백 2~3문장 (한국어).",
      },
      suggestion: {
        type: "string",
        description: "다음 끼니/다음 단계를 위한 식단 조절 제안 1~2문장 (한국어).",
      },
    },
    required: ["foods", "verdict", "score", "feedback", "suggestion"],
  },
};

function systemPrompt(b: Body): string {
  return [
    "당신은 박용우 「스위치온 다이어트」 프로그램을 돕는 한국어 영양 코치입니다.",
    "사용자가 찍은 식사 사진을 보고, 지금 단계 기준으로 식단에 부합하는지 판정합니다.",
    "",
    `현재 단계: ${b.week}주차 ${b.day}일차 — ${b.stage_title}`,
    `이 단계 허용 식품: ${(b.allowed_foods ?? []).join(", ")}`,
    `이 단계 제한 식품: ${(b.forbidden_foods ?? []).join(", ")}`,
    `권장 식단: ${b.meal_plan ?? ""}`,
    "",
    "판정 기준:",
    "- 제한 식품(밀가루·면·빵·설탕·디저트·튀김·가공식품·술·해당 단계 금지 과일 등)이 보이면 verdict=violation.",
    "- 허용 식품이지만 양이 많거나 단계상 줄이는 게 좋은 경우 verdict=caution.",
    "- 단계에 잘 맞으면 verdict=fit.",
    "- 사진만으로 확신이 어려우면 합리적으로 추정하되 과한 단정은 피하세요.",
    "",
    "톤 규칙(반드시 지킬 것):",
    "- 격려하는 말투로, 자책을 유도하지 않습니다.",
    "- 굶기·폭식·극단적 절식 등 극단적 감량을 절대 권하지 않습니다.",
    "- 의학적 진단·처방을 하지 않습니다(참고용 코칭만).",
    "- 반드시 report_meal_analysis 도구로만 답합니다.",
  ].join("\n");
}

Deno.serve(async (req: Request) => {
  // CORS preflight — 반드시 가장 먼저 처리.
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }

  try {
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) {
      return json(
        { error: "AI 기능이 아직 설정되지 않았어요. (ANTHROPIC_API_KEY 미설정)" },
        200,
      );
    }

    const body = (await req.json()) as Body;
    if (!body?.meal_id) return json({ error: "meal_id 가 없습니다." }, 200);

    const authHeader = req.headers.get("Authorization") ?? "";

    // 호출자 검증 (RLS 적용 클라이언트)
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: userData } = await userClient.auth.getUser();
    const uid = userData?.user?.id;
    if (!uid) return json({ error: "로그인이 필요해요." }, 200);

    // 서비스 롤 (스토리지 다운로드 + 결과 기록)
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // 본인 식사 기록 로드
    const { data: meal, error: mealErr } = await admin
      .from("meal_logs")
      .select("id, user_id, photo_urls, photo_url")
      .eq("id", body.meal_id)
      .single();
    if (mealErr || !meal) return json({ error: "식사 기록을 찾지 못했어요." }, 200);
    if (meal.user_id !== uid) return json({ error: "권한이 없어요." }, 403);

    const paths: string[] = [
      ...((meal.photo_urls as string[] | null) ?? []),
      ...(meal.photo_url ? [meal.photo_url as string] : []),
    ].filter(Boolean).slice(0, MAX_PHOTOS);

    if (paths.length === 0) {
      return json(
        { error: "분석할 사진이 없어요. 사진을 먼저 추가해 주세요." },
        200,
      );
    }

    // 사진 다운로드 → base64
    const imageBlocks: unknown[] = [];
    for (const p of paths) {
      const { data: blob, error: dlErr } = await admin.storage
        .from("meal-photos")
        .download(p);
      if (dlErr || !blob) continue;
      const bytes = new Uint8Array(await blob.arrayBuffer());
      imageBlocks.push({
        type: "image",
        source: {
          type: "base64",
          media_type: mediaTypeFor(p),
          data: toBase64(bytes),
        },
      });
    }
    if (imageBlocks.length === 0) {
      return json(
        { error: "사진을 불러오지 못했어요. 다시 시도해 주세요." },
        200,
      );
    }

    // Claude 호출 (Anthropic REST 직접 호출, 구조화 출력 강제)
    const aiRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 1024,
        system: systemPrompt(body),
        tools: [ANALYSIS_TOOL],
        tool_choice: { type: "tool", name: "report_meal_analysis" },
        messages: [
          {
            role: "user",
            content: [
              ...imageBlocks,
              {
                type: "text",
                text: "이 식사 사진을 현재 단계 기준으로 분석해 주세요.",
              },
            ],
          },
        ],
      }),
    });

    if (!aiRes.ok) {
      const errText = await aiRes.text();
      return json(
        { error: `AI 호출 실패(${aiRes.status}): ${errText.slice(0, 300)}` },
        200,
      );
    }

    const msg = await aiRes.json();
    const toolBlock = (msg.content ?? []).find(
      (b: { type?: string }) => b.type === "tool_use",
    );
    if (!toolBlock) {
      return json(
        { error: "AI 분석 결과를 받지 못했어요. 다시 시도해 주세요." },
        200,
      );
    }
    const out = toolBlock.input as {
      foods?: string;
      verdict?: string;
      score?: number;
      feedback?: string;
      suggestion?: string;
    };

    const score = Math.max(0, Math.min(100, Math.round(out.score ?? 0)));
    const verdict = ["fit", "caution", "violation"].includes(out.verdict ?? "")
      ? out.verdict!
      : "caution";

    // 결과 기록 (violation 이면 rule_violation 덮어쓰기)
    await admin
      .from("meal_logs")
      .update({
        ai_score: score,
        ai_verdict: verdict,
        ai_foods: out.foods ?? "",
        ai_feedback: out.feedback ?? "",
        ai_suggestion: out.suggestion ?? "",
        ai_analyzed_at: new Date().toISOString(),
        rule_violation: verdict === "violation",
      })
      .eq("id", body.meal_id);

    return json({
      foods: out.foods ?? "",
      verdict,
      score,
      feedback: out.feedback ?? "",
      suggestion: out.suggestion ?? "",
    });
  } catch (e) {
    return json({ error: `분석 중 오류가 발생했어요: ${String(e)}` }, 200);
  }
});

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...CORS, "content-type": "application/json" },
  });
}

function mediaTypeFor(path: string): string {
  const p = path.toLowerCase();
  if (p.endsWith(".png")) return "image/png";
  if (p.endsWith(".webp")) return "image/webp";
  if (p.endsWith(".gif")) return "image/gif";
  return "image/jpeg";
}

// 큰 배열에서도 안전한 base64 인코딩(청크 처리).
function toBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

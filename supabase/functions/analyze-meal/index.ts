// =============================================================================
// AI 식단 판독 Edge Function (analyze-meal) — fetch 직접 호출 버전
//
// 두 가지 입력 모드:
//   (A) 인라인 모드: body.images(base64) + body.memo 로 저장 전 즉시 분석 → 결과만 반환
//   (B) 저장본 모드: body.meal_id 로 스토리지 사진을 읽어 분석 → meal_logs 에 기록 후 반환
//
// 출력: 인식음식 / 적합도(verdict) / 점수 / 피드백 / 조절제안
//       + 칼로리·탄수·단백·지방(추정) + 신뢰도(confidence)
//
// 필요한 환경변수: ANTHROPIC_API_KEY (필수), SUPABASE_URL / SERVICE_ROLE_KEY / ANON_KEY
// =============================================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MODEL = "claude-opus-4-8";
const MAX_PHOTOS = 2;

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface InlineImage {
  media_type?: string;
  data: string; // base64 (no data: prefix)
}

interface Body {
  meal_id?: string;
  images?: InlineImage[];
  memo?: string;
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
    "사진/메뉴를 보고 현재 다이어트 단계 부합 여부와 영양 추정치를 보고한다.",
  input_schema: {
    type: "object",
    properties: {
      foods: { type: "string", description: "인식한 음식들을 한국어로, 콤마로 구분" },
      verdict: {
        type: "string",
        enum: ["fit", "caution", "violation"],
        description: "fit=적합, caution=양·종류 주의, violation=제한 음식 포함",
      },
      score: { type: "integer", minimum: 0, maximum: 100, description: "단계 부합도 점수" },
      feedback: { type: "string", description: "따뜻하고 구체적인 피드백 2~3문장 (한국어)." },
      suggestion: { type: "string", description: "식단 조절 제안 1~2문장 (한국어)." },
      calories: { type: "integer", minimum: 0, description: "총 칼로리 추정(kcal)." },
      carbs_g: { type: "integer", minimum: 0, description: "탄수화물 추정(g)." },
      protein_g: { type: "integer", minimum: 0, description: "단백질 추정(g)." },
      fat_g: { type: "integer", minimum: 0, description: "지방 추정(g)." },
      confidence: {
        type: "string",
        enum: ["high", "medium", "low"],
        description: "추정 신뢰도. 사진이 흐리거나 양 가늠이 어려우면 low.",
      },
    },
    required: [
      "foods", "verdict", "score", "feedback", "suggestion",
      "calories", "carbs_g", "protein_g", "fat_g", "confidence",
    ],
  },
};

function systemPrompt(b: Body): string {
  return [
    "당신은 박용우 「스위치온 다이어트」 프로그램을 돕는 한국어 영양 코치입니다.",
    "사진과(또는) 사용자가 입력한 메뉴를 보고, 지금 단계 기준 부합 여부를 판정하고",
    "칼로리·영양성분(탄·단·지)을 합리적으로 추정합니다.",
    "",
    `현재 단계: ${b.week}주차 ${b.day}일차 — ${b.stage_title}`,
    `이 단계 허용 식품: ${(b.allowed_foods ?? []).join(", ")}`,
    `이 단계 제한 식품: ${(b.forbidden_foods ?? []).join(", ")}`,
    `권장 식단: ${b.meal_plan ?? ""}`,
    "",
    "판정 기준:",
    "- 제한 식품(밀가루·면·빵·설탕·디저트·튀김·가공식품·술·해당 단계 금지 과일 등)이 보이면 verdict=violation.",
    "- 허용 식품이지만 양이 많거나 줄이는 게 좋으면 verdict=caution.",
    "- 단계에 잘 맞으면 verdict=fit.",
    "",
    "영양 추정:",
    "- 1인분 기준으로 칼로리와 탄·단·지를 추정. 양 정보가 부족하면 일반적인 1인분으로 가정.",
    "- 사진이 없거나 정보가 부족하면 confidence=low 로 표시.",
    "",
    "톤 규칙:",
    "- 격려하는 말투로, 자책을 유도하지 않습니다.",
    "- 굶기·폭식·극단적 절식 등 극단적 감량을 절대 권하지 않습니다.",
    "- 의학적 진단·처방을 하지 않습니다(참고용 코칭만).",
    "- 반드시 report_meal_analysis 도구로만 답합니다.",
  ].join("\n");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }
  try {
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) {
      return json({ error: "AI 기능이 아직 설정되지 않았어요. (ANTHROPIC_API_KEY 미설정)" }, 200);
    }

    const body = (await req.json()) as Body;

    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: userData } = await userClient.auth.getUser();
    const uid = userData?.user?.id;
    if (!uid) return json({ error: "로그인이 필요해요." }, 200);

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // 이미지 블록 구성 (인라인 우선, 없으면 meal_id 로 스토리지에서 다운로드)
    const imageBlocks: unknown[] = [];
    const inline = Array.isArray(body.images) ? body.images.slice(0, MAX_PHOTOS) : [];
    if (inline.length > 0) {
      for (const im of inline) {
        if (!im?.data) continue;
        imageBlocks.push({
          type: "image",
          source: {
            type: "base64",
            media_type: im.media_type || "image/jpeg",
            data: im.data,
          },
        });
      }
    } else if (body.meal_id) {
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

      for (const p of paths) {
        const { data: blob, error: dlErr } = await admin.storage
          .from("meal-photos").download(p);
        if (dlErr || !blob) continue;
        const bytes = new Uint8Array(await blob.arrayBuffer());
        imageBlocks.push({
          type: "image",
          source: { type: "base64", media_type: mediaTypeFor(p), data: toBase64(bytes) },
        });
      }
    }

    const memo = (body.memo ?? "").trim();
    if (imageBlocks.length === 0 && memo.length === 0) {
      return json({ error: "분석할 사진이나 메뉴를 입력해 주세요." }, 200);
    }

    // 사용자 콘텐츠(이미지 + 텍스트) 구성
    let promptText = "이 식사를 현재 단계 기준으로 분석하고 영양을 추정해 주세요.";
    if (memo) promptText += `\n사용자가 입력한 메뉴/메모: ${memo}`;
    if (imageBlocks.length === 0) {
      promptText += "\n(사진이 없으니 메뉴 텍스트만으로 추정하고 confidence=low 로 해주세요.)";
    }

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
          { role: "user", content: [...imageBlocks, { type: "text", text: promptText }] },
        ],
      }),
    });

    if (!aiRes.ok) {
      const errText = await aiRes.text();
      return json({ error: `AI 호출 실패(${aiRes.status}): ${errText.slice(0, 300)}` }, 200);
    }

    const msg = await aiRes.json();
    const toolBlock = (msg.content ?? []).find((b: { type?: string }) => b.type === "tool_use");
    if (!toolBlock) {
      return json({ error: "AI 분석 결과를 받지 못했어요. 다시 시도해 주세요." }, 200);
    }
    const o = toolBlock.input as Record<string, unknown>;

    const score = clampInt(o.score, 0, 100);
    const verdict = ["fit", "caution", "violation"].includes(String(o.verdict))
      ? String(o.verdict) : "caution";
    const confidence = ["high", "medium", "low"].includes(String(o.confidence))
      ? String(o.confidence) : "low";
    const result = {
      foods: String(o.foods ?? ""),
      verdict,
      score,
      feedback: String(o.feedback ?? ""),
      suggestion: String(o.suggestion ?? ""),
      calories: clampInt(o.calories, 0, 100000),
      carbs_g: clampInt(o.carbs_g, 0, 100000),
      protein_g: clampInt(o.protein_g, 0, 100000),
      fat_g: clampInt(o.fat_g, 0, 100000),
      confidence,
    };

    // 저장본 모드면 DB 에도 기록(violation 이면 rule_violation 덮어쓰기)
    if (body.meal_id && inline.length === 0) {
      await admin.from("meal_logs").update({
        ai_score: result.score,
        ai_verdict: result.verdict,
        ai_foods: result.foods,
        ai_feedback: result.feedback,
        ai_suggestion: result.suggestion,
        ai_calories: result.calories,
        ai_carbs_g: result.carbs_g,
        ai_protein_g: result.protein_g,
        ai_fat_g: result.fat_g,
        ai_confidence: result.confidence,
        ai_analyzed_at: new Date().toISOString(),
        rule_violation: result.verdict === "violation",
      }).eq("id", body.meal_id);
    }

    return json(result);
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

function clampInt(v: unknown, lo: number, hi: number): number {
  const n = Math.round(Number(v));
  if (!Number.isFinite(n)) return lo;
  return Math.max(lo, Math.min(hi, n));
}

function mediaTypeFor(path: string): string {
  const p = path.toLowerCase();
  if (p.endsWith(".png")) return "image/png";
  if (p.endsWith(".webp")) return "image/webp";
  if (p.endsWith(".gif")) return "image/gif";
  return "image/jpeg";
}

function toBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

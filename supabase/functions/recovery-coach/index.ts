// =============================================================================
// AI 회복 코칭 Edge Function (recovery-coach)
//
// 미준수 상황(식단 위반/저달성/단식취소/연속미기록)에서 비난 없이 격려하고,
// 이후 계획을 유연하게 조정하는 개인화 코칭 문구를 생성한다.
//
// 입력: kind, week, day, stage_title, avg_completion, recent_violations
// 출력: { coaching: string }
//
// 필요한 환경변수: ANTHROPIC_API_KEY (필수)
// 배포: supabase functions deploy recovery-coach
// =============================================================================
const MODEL = "claude-opus-4-8";

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface Body {
  kind: string;
  week: number;
  day: number;
  stage_title: string;
  avg_completion: number;
  recent_violations: number;
}

const KIND_KO: Record<string, string> = {
  violation: "단계에 맞지 않는 식사를 함",
  low_completion: "하루 목표 달성률이 낮았음",
  fast_cancel: "단식을 중간에 멈춤",
  gap: "며칠 동안 기록이 없었음",
};

function systemPrompt(): string {
  return [
    "당신은 박용우 「스위치온 다이어트」를 돕는 한국어 코치입니다.",
    "사용자가 계획을 지키지 못한 상황에서, 비난이나 죄책감을 주지 않고",
    "따뜻하게 격려하며 '이후 계획을 어떻게 유연하게 이어갈지'를 구체적으로 제안합니다.",
    "",
    "반드시 지킬 규칙:",
    "- 자책 유도 금지. '실패'라는 단어 대신 '흔들림/회복'의 관점.",
    "- 굶기·폭식·극단적 절식 등 극단적 보상 절대 권장 금지.",
    "- 의학적 진단·처방 금지(참고용 코칭만).",
    "- 5~7문장, 따뜻하고 담백하게. 마지막에 작은 다음 행동 1가지를 제안.",
  ].join("\n");
}

function userPrompt(b: Body): string {
  const pct = Math.round((b.avg_completion ?? 0) * 100);
  return [
    `상황: ${KIND_KO[b.kind] ?? "계획을 지키지 못함"}.`,
    `현재 ${b.week}주차 ${b.day}일차 — ${b.stage_title}.`,
    `최근 평균 달성률 ${pct}%, 최근 규칙 위반 ${b.recent_violations}회.`,
    "이 사람을 격려하고, 이후 계획을 유연하게 이어갈 방법을 코칭해 주세요.",
  ].join("\n");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) {
      return json({ error: "AI 기능이 아직 설정되지 않았어요. (ANTHROPIC_API_KEY 미설정)" }, 200);
    }
    const body = (await req.json()) as Body;

    const aiRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 700,
        system: systemPrompt(),
        messages: [{ role: "user", content: userPrompt(body) }],
      }),
    });

    if (!aiRes.ok) {
      const t = await aiRes.text();
      return json({ error: `AI 호출 실패(${aiRes.status}): ${t.slice(0, 300)}` }, 200);
    }
    const msg = await aiRes.json();
    const textBlock = (msg.content ?? []).find(
      (b: { type?: string }) => b.type === "text",
    );
    const coaching = (textBlock?.text ?? "").trim();
    if (!coaching) {
      return json({ error: "코칭 문구를 받지 못했어요." }, 200);
    }
    return json({ coaching });
  } catch (e) {
    return json({ error: `코칭 중 오류가 발생했어요: ${String(e)}` }, 200);
  }
});

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...CORS, "content-type": "application/json" },
  });
}

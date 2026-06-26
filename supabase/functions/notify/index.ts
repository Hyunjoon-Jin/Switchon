// =============================================================================
// 원격 푸시 Edge Function (샘플 / 토대)
//
// 트리거: Supabase Database Webhook 를 community_cheers / community_comments 의
//        INSERT 에 연결하면, 새 응원/댓글이 생길 때 이 함수가 호출됩니다.
// 동작:  글 작성자의 device_tokens 를 조회해 FCM(HTTP v1)로 푸시를 보냅니다.
//        (본인 행동에 대한 알림은 보내지 않습니다.)
//
// 필요한 환경변수(Function Secrets):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  (자동 주입되는 경우가 많음)
//   FCM_PROJECT_ID, FCM_CLIENT_EMAIL, FCM_PRIVATE_KEY  (서비스 계정)
//
// 배포:  supabase functions deploy notify
// 주의:  이 파일은 토대 샘플입니다. 실제 운영 전 FCM 서비스계정/권한을 설정하고
//        Database Webhook 를 연결하세요. (Firebase 프로젝트 필요)
// =============================================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface WebhookPayload {
  type: "INSERT";
  table: string;
  record: Record<string, unknown>;
}

Deno.serve(async (req) => {
  try {
    const payload = (await req.json()) as WebhookPayload;
    const { table, record } = payload;

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const postId = record["post_id"] as string;
    const actorId = record["user_id"] as string;

    // 글 작성자 조회
    const { data: post } = await supabase
      .from("community_posts")
      .select("user_id, author_name")
      .eq("id", postId)
      .single();

    if (!post) return json({ skipped: "post not found" });
    const ownerId = post.user_id as string;
    if (ownerId === actorId) return json({ skipped: "self action" });

    // 대상 토큰
    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", ownerId);

    if (!tokens || tokens.length === 0) {
      return json({ skipped: "no tokens" });
    }

    const isCheer = table === "community_cheers";
    const title = isCheer ? "응원이 도착했어요 💪" : "새 댓글이 달렸어요 💬";
    const body = isCheer
      ? "누군가 내 글에 응원을 보냈어요."
      : `${record["author_name"] ?? "누군가"}: ${truncate(
          (record["content"] as string) ?? "",
          50,
        )}`;

    const accessToken = await getFcmAccessToken();
    const results = await Promise.all(
      tokens.map((t) =>
        sendFcm(accessToken, t.token as string, title, body, { postId }),
      ),
    );

    return json({ sent: results.filter(Boolean).length });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function truncate(s: string, n: number): string {
  return s.length > n ? `${s.slice(0, n)}…` : s;
}

// --- FCM HTTP v1 ------------------------------------------------------------

async function sendFcm(
  accessToken: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<boolean> {
  const projectId = Deno.env.get("FCM_PROJECT_ID")!;
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        message: { token, notification: { title, body }, data },
      }),
    },
  );
  return res.ok;
}

// 서비스 계정으로 OAuth2 액세스 토큰 발급 (google JWT)
async function getFcmAccessToken(): Promise<string> {
  const clientEmail = Deno.env.get("FCM_CLIENT_EMAIL")!;
  const privateKey = Deno.env.get("FCM_PRIVATE_KEY")!.replace(/\\n/g, "\n");

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claim = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const enc = (o: unknown) =>
    btoa(JSON.stringify(o)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const unsigned = `${enc(header)}.${enc(claim)}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBytes(privateKey),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${b64url(new Uint8Array(sig))}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const tok = await res.json();
  return tok.access_token as string;
}

function pemToBytes(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes.buffer;
}

function b64url(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

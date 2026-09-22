// Invocada a cada minuto pelo cron job criado em
// supabase/migrations/0007_push_subscriptions.sql. Sem corpo (ou corpo
// vazio) — lê todo mundo em push_subscriptions (via service role, que
// bypassa RLS) e decide "está na hora?" comparando a hora local de cada
// usuário (a partir do fuso IANA salvo) contra reminder_hour/reminder_minute.
//
// Pra testar manualmente sem depender do horário configurado, aceita um
// corpo opcional { "userId": "<uuid>" } que ignora o check de horário só
// pra esse usuário (ver docs/push-notifications.md). Nunca usado pelo cron.
//
// Secrets esperados (Dashboard > Edge Functions > Secrets):
// - FCM_SERVICE_ACCOUNT_JSON: conteúdo do JSON da service account do
//   Firebase (Project Settings > Service accounts > Generate new private key).
// SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY já são injetados automaticamente
// pelo runtime das Edge Functions, não precisam ser configurados à mão.
import { createClient } from "npm:@supabase/supabase-js@2";
import { GoogleAuth } from "npm:google-auth-library@9";

const FIREBASE_PROJECT_ID = "leituradiarianotifications";
const FCM_ENDPOINT = `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`;

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const googleAuth = new GoogleAuth({
  credentials: JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT_JSON")!),
  scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
});

type PushSubscription = {
  user_id: string;
  fcm_token: string;
  reminder_hour: number;
  reminder_minute: number;
  timezone: string;
};

function isDueNow(sub: PushSubscription, now: Date): boolean {
  try {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: sub.timezone,
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    }).formatToParts(now);
    const hour = Number(parts.find((p) => p.type === "hour")?.value);
    const minute = Number(parts.find((p) => p.type === "minute")?.value);
    return hour === sub.reminder_hour && minute === sub.reminder_minute;
  } catch {
    // Fuso IANA inválido/desconhecido salvo por engano — pula em vez de
    // derrubar o lote inteiro.
    return false;
  }
}

async function sendPush(accessToken: string, token: string): Promise<Response> {
  return fetch(FCM_ENDPOINT, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message: {
        token,
        notification: {
          title: "Leitura de hoje",
          body: "Não esqueça de ler os capítulos do seu plano bíblico hoje.",
        },
      },
    }),
  });
}

Deno.serve(async (req: Request) => {
  let forceUserId: string | null = null;
  try {
    const body = await req.json();
    if (typeof body?.userId === "string") forceUserId = body.userId;
  } catch {
    // No body (or not JSON) — the normal every-minute cron call.
  }

  let query = supabase
    .from("push_subscriptions")
    .select("user_id, fcm_token, reminder_hour, reminder_minute, timezone");
  if (forceUserId) query = query.eq("user_id", forceUserId);
  const { data: subscriptions, error } = await query;

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  const now = new Date();
  const due = forceUserId
    ? ((subscriptions ?? []) as PushSubscription[])
    : ((subscriptions ?? []) as PushSubscription[]).filter((sub) => isDueNow(sub, now));
  if (due.length === 0) {
    return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
  }

  const client = await googleAuth.getClient();
  const { token: accessToken } = await client.getAccessToken();
  if (!accessToken) {
    return new Response(JSON.stringify({ error: "Failed to obtain FCM access token" }), {
      status: 500,
    });
  }

  let sent = 0;
  // Tokens que o FCM reporta como inválidos/não registrados (app
  // desinstalado etc.) — limpos daqui já que, sem isso, ninguém nunca mais
  // atualiza aquela linha.
  const staleUserIds: string[] = [];

  for (const sub of due) {
    const response = await sendPush(accessToken, sub.fcm_token);
    if (response.ok) {
      sent++;
      continue;
    }
    const body = await response.json().catch(() => null);
    const errorStatus = body?.error?.status;
    if (response.status === 404 || errorStatus === "UNREGISTERED" || errorStatus === "NOT_FOUND") {
      staleUserIds.push(sub.user_id);
    }
  }

  if (staleUserIds.length > 0) {
    await supabase.from("push_subscriptions").delete().in("user_id", staleUserIds);
  }

  return new Response(JSON.stringify({ sent, cleaned: staleUserIds.length }), { status: 200 });
});

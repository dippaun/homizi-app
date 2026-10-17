import { adminClient, env, json, secretsEqual } from "../_shared/http.ts";
import { fcmAccessToken } from "../_shared/fcm.ts";

const titles: Record<string, string> = {
  match: "New match on HOMIZI",
  message: "New message on HOMIZI",
  visit_requested: "Visit update on HOMIZI",
  visit_accepted: "Visit update on HOMIZI",
  visit_declined: "Visit update on HOMIZI",
  visit_cancelled: "Visit update on HOMIZI",
};

const bodies: Record<string, string> = {
  match: "Open HOMIZI to see the match.",
  message: "Open the chat in HOMIZI.",
  visit_requested: "Open HOMIZI to see the visit.",
  visit_accepted: "Open HOMIZI to see the visit.",
  visit_declined: "Open HOMIZI to see the visit.",
  visit_cancelled: "Open HOMIZI to see the visit.",
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ ok: false, error: "method" }, 405);
  }
  const secret = env("PUSH_WEBHOOK_SECRET");
  const header = req.headers.get("x-homizi-push-secret") ?? "";
  if (!secretsEqual(secret, header)) {
    return json({ ok: false, error: "unauthorized" }, 401);
  }
  const accountRaw = env("FCM_SERVICE_ACCOUNT");
  if (!accountRaw) {
    return json({ ok: true, sent: false, reason: "unconfigured" });
  }
  const payload = await req.json();
  const userId = String(payload.user_id ?? "");
  const type = String(payload.type ?? "");
  const notificationId = String(payload.notification_id ?? "");
  if (!titles[type] || !userId) {
    return json({ ok: true, sent: false, reason: "ignored" });
  }
  let account: { client_email: string; private_key: string; project_id: string };
  try {
    account = JSON.parse(accountRaw);
  } catch {
    return json({ ok: true, sent: false, reason: "unconfigured" });
  }
  const admin = adminClient();
  const { data: allowed } = await admin.rpc("push_allowed", {
    p_user_id: userId,
    p_type: type,
  });
  if (allowed !== true) {
    return json({ ok: true, sent: false, reason: "preference" });
  }
  const { data: tokens } = await admin
    .from("device_tokens")
    .select("token")
    .eq("user_id", userId);
  const rows = tokens ?? [];
  if (rows.length === 0) {
    return json({ ok: true, sent: false, reason: "no_tokens" });
  }
  const access = await fcmAccessToken(account);
  let sent = 0;
  for (const row of rows) {
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${access}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: row.token,
            notification: { title: titles[type], body: bodies[type] },
            data: { notification_id: notificationId, type },
          },
        }),
      },
    );
    if (response.ok) {
      sent += 1;
    }
  }
  return json({ ok: true, sent: sent > 0, count: sent });
});

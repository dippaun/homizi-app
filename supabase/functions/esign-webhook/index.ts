import { adminClient, env, json, secretsEqual } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ ok: false, error: "method" }, 405);
  }
  const secret = env("DIGIO_WEBHOOK_SECRET") || env("DIGIO_CLIENT_SECRET");
  const header = req.headers.get("x-homizi-provider-secret") ?? "";
  if (!secret || !secretsEqual(secret, header)) {
    return json({ ok: false, error: "unauthorized" }, 401);
  }
  const body = await req.json();
  const agreementId = String(body.agreement_id ?? "");
  const status = String(body.status ?? "");
  const reference = body.provider_reference == null
    ? null
    : String(body.provider_reference);
  if (!agreementId) {
    return json({ ok: false, error: "not_found" }, 400);
  }
  const admin = adminClient();
  const { data, error } = await admin.rpc("apply_esign_result", {
    p_agreement_id: agreementId,
    p_status: status,
    p_provider_reference: reference,
  });
  if (error) {
    return json({ ok: false, error: "agreement" }, 400);
  }
  return json(data ?? { ok: true });
});

import {
  adminClient,
  env,
  json,
  looksLikeAadhaar,
  secretsEqual,
} from "../_shared/http.ts";

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
  const userId = String(body.user_id ?? "");
  const status = String(body.status ?? "");
  const reference = String(body.provider_reference ?? "");
  const masked = body.masked_last4 == null ? null : String(body.masked_last4);
  const kind = body.document_kind == null ? null : String(body.document_kind);
  if (!userId || looksLikeAadhaar(reference) || looksLikeAadhaar(JSON.stringify(body))) {
    return json({ ok: false, error: "rejected" }, 400);
  }
  const admin = adminClient();
  const { data, error } = await admin.rpc("apply_verification_result", {
    p_user_id: userId,
    p_status: status,
    p_provider: "digio",
    p_reference: reference,
    p_masked_last4: masked,
    p_document_kind: kind,
  });
  if (error) {
    return json({ ok: false, error: "verification" }, 400);
  }
  return json(data ?? { ok: true });
});

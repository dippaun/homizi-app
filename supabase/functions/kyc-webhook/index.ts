import {
  adminClient,
  env,
  json,
  looksLikeAadhaar,
  secretsEqual,
} from "../_shared/http.ts";
import { mergeWebhookDecision, parseDigioWebhook, signedChecksum } from "../_shared/kyc.ts";

// Digio calls this. Only this function (through apply_kyc_checks, which
// refuses signed-in users) ever writes a verified result.
Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ ok: false, error: "method" }, 405);
  }
  const secret = env("DIGIO_WEBHOOK_SECRET") || env("DIGIO_CLIENT_SECRET");
  const raw = await req.text();
  const header = (req.headers.get("x-digio-checksum") ?? "").trim().toLowerCase();
  if (!secret || !header) {
    return json({ ok: false, error: "unauthorized" }, 401);
  }
  const expected = await signedChecksum(secret, raw);
  if (!secretsEqual(expected, header)) {
    return json({ ok: false, error: "unauthorized" }, 401);
  }
  let payload: unknown;
  try {
    payload = JSON.parse(raw);
  } catch {
    return json({ ok: false, error: "rejected" }, 400);
  }
  const decision = parseDigioWebhook(payload);
  if (!decision || looksLikeAadhaar(decision.requestId)) {
    return json({ ok: false, error: "rejected" }, 400);
  }
  const admin = adminClient();
  const { data: row } = await admin
    .from("identity_verifications")
    .select("user_id, document_kind, provider_reference, aadhaar_status, face_status, masked_last4")
    .eq("provider_reference", decision.requestId)
    .maybeSingle();
  const userId = row?.user_id ? String(row.user_id) : "";
  if (!userId) {
    // An old or unknown request (for example after the person deleted their
    // record or started again). Acknowledge it so Digio stops retrying.
    return json({ ok: true, ignored: "unknown_request" }, 202);
  }
  const merged = mergeWebhookDecision({
    providerReference: row?.provider_reference == null ? null : String(row.provider_reference),
    aadhaarStatus: String(row?.aadhaar_status ?? "not_started"),
    faceStatus: String(row?.face_status ?? "not_started"),
    maskedLast4: row?.masked_last4 == null ? null : String(row.masked_last4),
  }, decision);
  if (!merged) {
    // Replay or an out-of-order event: nothing to change.
    return json({ ok: true, ignored: "duplicate" });
  }
  const kind = row?.document_kind == null ? null : String(row.document_kind);
  const { error } = await admin.rpc("apply_kyc_checks", {
    p_user_id: userId,
    p_aadhaar_status: merged.aadhaarStatus,
    p_face_status: merged.faceStatus,
    p_reference: merged.requestId,
    p_masked_last4: merged.maskedLast4,
    p_document_kind: kind,
  });
  if (error) {
    return json({ ok: false, error: "verification" }, 500);
  }
  return json({ ok: true });
});

import {
  adminClient,
  env,
  json,
  looksLikeAadhaar,
  secretsEqual,
} from "../_shared/http.ts";
import { parseDigioWebhook, signedChecksum } from "../_shared/kyc.ts";

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
    .select("user_id, document_kind")
    .eq("provider_reference", decision.requestId)
    .maybeSingle();
  const userId = row?.user_id ? String(row.user_id) : "";
  if (!userId) {
    return json({ ok: false, error: "not_found" }, 404);
  }
  const kind = row?.document_kind == null ? null : String(row.document_kind);
  const { error } = await admin.rpc("apply_kyc_checks", {
    p_user_id: userId,
    p_aadhaar_status: decision.aadhaarStatus,
    p_face_status: decision.faceStatus,
    p_reference: decision.requestId,
    p_masked_last4: decision.maskedLast4,
    p_document_kind: kind,
  });
  if (error) {
    return json({ ok: false, error: "verification" }, 400);
  }
  return json({ ok: true });
});

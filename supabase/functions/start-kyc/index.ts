import { adminClient, env, userClient } from "../_shared/http.ts";
import {
  allowedReturnUrl,
  corsHeaders,
  customerIdentifier,
  fetchDigioDecision,
  kycConfigured,
  kycStatusBody,
  mergeWebhookDecision,
  openDigioKyc,
  templateFor,
  withRedirect,
} from "../_shared/kyc.ts";

const kinds = new Set(["digilocker", "aadhaar_offline"]);

Deno.serve(async (req) => {
  const cors = corsHeaders(req.headers.get("origin"), env);
  const reply = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (req.method !== "POST") {
    return reply({ ok: false, error: "method" }, 405);
  }
  const client = userClient(req);
  const { data: userData, error: userError } = await client.auth.getUser();
  if (userError || !userData.user) {
    return reply({ ok: false, error: "unauthenticated" }, 401);
  }
  const uid = userData.user.id;
  const body = await req.json().catch(() => ({})) as {
    action?: unknown;
    document_kind?: unknown;
    return_url?: unknown;
  };
  // The app asks first, so it can show "coming soon" before any consent.
  // Only a boolean leaves the server, never a secret.
  if (body.action === "status") {
    return reply(kycStatusBody(env));
  }
  if (!kycConfigured(env)) {
    return unavailable(reply);
  }
  if (body.action === "refresh") {
    return await refresh(uid, reply);
  }
  const kind = String(body.document_kind ?? "");
  if (!kinds.has(kind)) {
    return reply({ ok: false, error: "kind" }, 400);
  }
  const admin = adminClient();
  const { data: current } = await admin
    .from("identity_verifications")
    .select("consented_at, aadhaar_status, face_status")
    .eq("user_id", uid)
    .maybeSingle();
  if (!current?.consented_at) {
    return reply({ ok: false, error: "consent_required" }, 400);
  }
  if (current.aadhaar_status === "verified" && current.face_status === "verified") {
    // A new Digio request would reset a finished result.
    return reply({ ok: false, error: "already_verified" }, 409);
  }
  const profile = await admin
    .from("profiles")
    .select("display_name")
    .eq("user_id", uid)
    .maybeSingle();
  const name = String(profile.data?.display_name ?? "").trim() || "HOMIZI member";
  const opened = await openDigioKyc({
    fetchImpl: fetch,
    clientId: env("DIGIO_CLIENT_ID"),
    clientSecret: env("DIGIO_CLIENT_SECRET"),
    digioEnv: env("DIGIO_ENV"),
    baseUrl: env("DIGIO_BASE_URL"),
    templateName: templateFor(kind, env),
    identifier: customerIdentifier(userData.user.email ?? "", userData.user.phone ?? "") ?? "",
    name,
    referenceId: uid,
  });
  if (!opened.ok) {
    // Configured, but Digio refused or timed out: the app offers a retry.
    return reply({ ok: false, error: "start_failed" }, 502);
  }
  const { data: saved, error: saveError } = await admin.rpc("apply_kyc_checks", {
    p_user_id: uid,
    p_aadhaar_status: "in_progress",
    p_face_status: "in_progress",
    p_reference: opened.requestId,
    p_masked_last4: null,
    p_document_kind: kind,
  });
  if (saveError || (saved && typeof saved === "object" && (saved as { ok?: boolean }).ok === false)) {
    return reply({ ok: false, error: "start_failed" }, 502);
  }
  let verification = saved && typeof saved === "object"
    ? (saved as { verification?: unknown }).verification ?? null
    : null;
  // A new Digio request starts its own 10-day clock. The original
  // apply_kyc_checks keeps the first started_at, which would make a retry
  // look expired, so reset it here (service role) for this request.
  const startedAt = new Date().toISOString();
  const { error: clockError } = await admin
    .from("identity_verifications")
    .update({ started_at: startedAt })
    .eq("user_id", uid)
    .eq("provider_reference", opened.requestId);
  if (!clockError && verification && typeof verification === "object") {
    verification = { ...(verification as Record<string, unknown>), started_at: startedAt };
  }
  // The return address comes from the server allowlist, not the client.
  const returnUrl = allowedReturnUrl(body.return_url, env);
  return reply({
    ok: true,
    verification,
    gateway_url: withRedirect(opened.gatewayUrl, returnUrl),
  });
});

// Asks Digio for the current result of this person's own request and saves
// it through apply_kyc_checks with the same no-downgrade rule as the
// webhook. The request id comes from our row, never from the client.
async function refresh(
  uid: string,
  reply: (body: unknown, status?: number) => Response,
): Promise<Response> {
  const admin = adminClient();
  const { data: row } = await admin
    .from("identity_verifications")
    .select(
      "verification_status, provider, provider_reference, document_kind, masked_last4, aadhaar_status, face_status, started_at",
    )
    .eq("user_id", uid)
    .maybeSingle();
  const reference = row?.provider_reference == null ? "" : String(row.provider_reference);
  const aadhaar = String(row?.aadhaar_status ?? "not_started");
  const face = String(row?.face_status ?? "not_started");
  const finished = (aadhaar === "verified" || aadhaar === "failed") &&
    (face === "verified" || face === "failed");
  if (!row || !reference || finished) {
    return reply({ ok: true, changed: false, verification: row ?? null });
  }
  const fetched = await fetchDigioDecision({
    fetchImpl: fetch,
    clientId: env("DIGIO_CLIENT_ID"),
    clientSecret: env("DIGIO_CLIENT_SECRET"),
    digioEnv: env("DIGIO_ENV"),
    baseUrl: env("DIGIO_BASE_URL"),
    requestId: reference,
  });
  if (!fetched.ok) {
    // Keep what we have; the webhook or the next poll can still finish it.
    return reply({ ok: true, changed: false, verification: row });
  }
  const merged = mergeWebhookDecision({
    providerReference: reference,
    aadhaarStatus: aadhaar,
    faceStatus: face,
    maskedLast4: row.masked_last4 == null ? null : String(row.masked_last4),
  }, fetched.decision);
  if (!merged) {
    return reply({ ok: true, changed: false, verification: row });
  }
  const { data: saved, error } = await admin.rpc("apply_kyc_checks", {
    p_user_id: uid,
    p_aadhaar_status: merged.aadhaarStatus,
    p_face_status: merged.faceStatus,
    p_reference: merged.requestId,
    p_masked_last4: merged.maskedLast4,
    p_document_kind: row.document_kind == null ? null : String(row.document_kind),
  });
  if (error || (saved && typeof saved === "object" && (saved as { ok?: boolean }).ok === false)) {
    return reply({ ok: true, changed: false, verification: row });
  }
  const verification = saved && typeof saved === "object"
    ? (saved as { verification?: unknown }).verification ?? row
    : row;
  return reply({ ok: true, changed: true, verification });
}

function unavailable(reply: (body: unknown, status?: number) => Response): Response {
  return reply({
    ok: false,
    error: "verification_unavailable",
    reason: "not_configured",
    message: "Aadhaar verification is not configured yet",
  }, 503);
}

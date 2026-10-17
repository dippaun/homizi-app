import { adminClient, env, json, userClient } from "../_shared/http.ts";
import { customerIdentifier, openDigioKyc, templateFor } from "../_shared/kyc.ts";

const kinds = new Set(["digilocker", "aadhaar_offline"]);

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ ok: false, error: "method" }, 405);
  }
  const client = userClient(req);
  const { data: userData, error: userError } = await client.auth.getUser();
  if (userError || !userData.user) {
    return json({ ok: false, error: "unauthenticated" }, 401);
  }
  const uid = userData.user.id;
  const body = await req.json().catch(() => ({}));
  const kind = String((body as { document_kind?: unknown }).document_kind ?? "");
  if (!kinds.has(kind)) {
    return json({ ok: false, error: "kind" }, 400);
  }
  const admin = adminClient();
  const { data: consent } = await admin
    .from("identity_verifications")
    .select("consented_at")
    .eq("user_id", uid)
    .maybeSingle();
  if (!consent?.consented_at) {
    return json({ ok: false, error: "consent_required" }, 400);
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
    return unavailable();
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
    return unavailable();
  }
  const verification = saved && typeof saved === "object"
    ? (saved as { verification?: unknown }).verification ?? null
    : null;
  return json({ ok: true, verification, gateway_url: opened.gatewayUrl });
});

function unavailable(): Response {
  return json({
    ok: false,
    error: "verification_unavailable",
    message: "verification temporarily unavailable",
  }, 503);
}

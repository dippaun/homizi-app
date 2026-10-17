import { adminClient, env, json, looksLikeAadhaar, userId } from "../_shared/http.ts";

const kinds = new Set(["digilocker", "aadhaar_offline", "pan"]);

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ ok: false, error: "method" }, 405);
  }
  const uid = await userId(req);
  if (!uid) {
    return json({ ok: false, error: "unauthenticated" }, 401);
  }
  const body = await req.json();
  const kind = String(body.document_kind ?? "");
  if (!kinds.has(kind) || looksLikeAadhaar(JSON.stringify(body))) {
    return json({ ok: false, error: "kind" }, 400);
  }
  const clientId = env("DIGIO_CLIENT_ID");
  const clientSecret = env("DIGIO_CLIENT_SECRET");
  const admin = adminClient();
  if (!clientId || !clientSecret) {
    const { data, error } = await admin.rpc("apply_verification_result", {
      p_user_id: uid,
      p_status: "verified",
      p_provider: "demo",
      p_reference: "demo-kyc",
      p_masked_last4: "4821",
      p_document_kind: kind,
    });
    if (error) {
      return json({ ok: false, error: "verification" }, 500);
    }
    return json(data ?? { ok: true });
  }
  const base = env("DIGIO_BASE_URL") || "https://ext.digio.in";
  const response = await fetch(`${base}/client/kyc/v2/request`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${btoa(`${clientId}:${clientSecret}`)}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      customer_identifier: uid,
      template_name: kind,
      notify_customer: false,
    }),
  });
  const created = await response.json().catch(() => ({}));
  const reference = String(created.id ?? created.request_id ?? "");
  if (!response.ok || !reference || looksLikeAadhaar(reference)) {
    return json({ ok: false, error: "provider" }, 502);
  }
  const { data, error } = await admin.rpc("apply_verification_result", {
    p_user_id: uid,
    p_status: "pending",
    p_provider: "digio",
    p_reference: reference,
    p_masked_last4: null,
    p_document_kind: kind,
  });
  if (error) {
    return json({ ok: false, error: "verification" }, 500);
  }
  return json(data ?? { ok: true });
});

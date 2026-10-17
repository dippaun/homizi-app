import { adminClient, env, json, userClient, userId } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ ok: false, error: "method" }, 405);
  }
  const uid = await userId(req);
  if (!uid) {
    return json({ ok: false, error: "unauthenticated" }, 401);
  }
  const body = await req.json();
  const agreementId = String(body.agreement_id ?? "");
  const user = userClient(req);
  const clientId = env("DIGIO_CLIENT_ID");
  const clientSecret = env("DIGIO_CLIENT_SECRET");
  if (!clientId || !clientSecret) {
    const { data, error } = await user.rpc("send_agreement", {
      p_agreement_id: agreementId,
    });
    if (error) {
      return json({ ok: false, error: "agreement" }, 400);
    }
    return json(data ?? { ok: true });
  }
  const { data: agreement } = await user
    .from("agreements")
    .select("id, title, draft_body, status")
    .eq("id", agreementId)
    .maybeSingle();
  if (!agreement || agreement.status !== "draft") {
    return json({ ok: false, error: "not_found" }, 404);
  }
  const base = env("DIGIO_BASE_URL") || "https://ext.digio.in";
  const response = await fetch(`${base}/v2/client/document/upload`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${btoa(`${clientId}:${clientSecret}`)}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      file_name: "homizi-agreement.txt",
      file_data: btoa(String(agreement.draft_body ?? "")),
      signers: [{ identifier: uid, reason: "HOMIZI rent agreement" }],
      expire_in_days: 10,
    }),
  });
  const created = await response.json().catch(() => ({}));
  const reference = String(created.id ?? created.document_id ?? "");
  if (!response.ok || !reference) {
    return json({ ok: false, error: "provider" }, 502);
  }
  const admin = adminClient();
  const { data, error } = await admin.rpc("apply_esign_result", {
    p_agreement_id: agreementId,
    p_status: "sent",
    p_provider_reference: reference,
  });
  if (error) {
    return json({ ok: false, error: "agreement" }, 500);
  }
  return json(data ?? { ok: true });
});

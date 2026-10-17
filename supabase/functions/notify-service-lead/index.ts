import { adminClient, env, json, secretsEqual } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ ok: false, error: "method" }, 405);
  }
  const secret = env("LEAD_WEBHOOK_SECRET");
  const header = req.headers.get("x-homizi-lead-secret") ?? "";
  if (!secretsEqual(secret, header)) {
    return json({ ok: false, error: "unauthorized" }, 401);
  }
  const apiKey = env("RESEND_API_KEY");
  if (!apiKey) {
    return json({ ok: true, sent: false, reason: "unconfigured" });
  }
  const body = await req.json();
  const leadId = String(body.lead_id ?? "");
  const admin = adminClient();
  const { data: lead } = await admin
    .from("service_leads")
    .select("id, service_kind, city, from_locality, to_locality, requested_on, home_size")
    .eq("id", leadId)
    .maybeSingle();
  if (!lead) {
    return json({ ok: true, sent: false, reason: "missing" });
  }
  const to = env("SERVICE_LEAD_TO") || "hello@homizi.in";
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: env("SERVICE_LEAD_FROM") || "HOMIZI <hello@homizi.in>",
      to: [to],
      subject: `HOMIZI service request ${lead.service_kind}`,
      text:
        `A HOMIZI partner request was filed.\nKind: ${lead.service_kind}\nCity: ${lead.city}\nFrom: ${lead.from_locality}\nTo: ${lead.to_locality ?? ""}\nDate: ${lead.requested_on}\nSize: ${lead.home_size ?? ""}\nLead: ${lead.id}\n`,
    }),
  });
  return json({ ok: true, sent: response.ok });
});

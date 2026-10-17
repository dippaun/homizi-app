import { adminClient, env, hmacHex, json, secretsEqual } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ ok: false, error: "method" }, 405);
  }
  const secret = env("RAZORPAY_WEBHOOK_SECRET");
  const raw = await req.text();
  const signature = req.headers.get("x-razorpay-signature") ?? "";
  if (!secret) {
    return json({ ok: true, applied: false, reason: "unconfigured" });
  }
  const expected = await hmacHex(secret, raw);
  if (!secretsEqual(expected, signature)) {
    return json({ ok: false, error: "signature" }, 401);
  }
  const event = JSON.parse(raw);
  const paymentEntity = event?.payload?.payment?.entity ?? {};
  const orderId = String(paymentEntity.order_id ?? "");
  const paymentId = String(paymentEntity.id ?? "");
  const eventName = String(event?.event ?? "");
  if (!orderId) {
    return json({ ok: true, applied: false, reason: "ignored" });
  }
  const status = eventName === "payment.captured" || eventName === "order.paid"
    ? "succeeded"
    : eventName === "payment.failed"
    ? "failed"
    : null;
  if (!status) {
    return json({ ok: true, applied: false, reason: "ignored" });
  }
  const admin = adminClient();
  const { data } = await admin
    .from("payments")
    .update({
      status,
      provider_ref: paymentId || null,
      receipt_id: paymentId || null,
    })
    .eq("provider_order_id", orderId)
    .eq("provider", "razorpay")
    .select("id");
  return json({ ok: true, applied: (data ?? []).length > 0 });
});

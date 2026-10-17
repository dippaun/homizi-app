import { adminClient, env, json, userClient, userId } from "../_shared/http.ts";

const kinds = new Set(["rent", "deposit", "maintenance"]);

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ ok: false, error: "method" }, 405);
  }
  const uid = await userId(req);
  if (!uid) {
    return json({ ok: false, error: "unauthenticated" }, 401);
  }
  const body = await req.json();
  const matchId = String(body.match_id ?? "");
  const kind = String(body.kind ?? "");
  const amount = Number(body.amount_inr);
  const period = body.period_label == null ? null : String(body.period_label);
  if (!kinds.has(kind) || !Number.isInteger(amount) || amount < 1 || amount > 10000000) {
    return json({ ok: false, error: "amount" }, 400);
  }
  const keyId = env("RAZORPAY_KEY_ID");
  const keySecret = env("RAZORPAY_KEY_SECRET");
  const user = userClient(req);
  if (!keyId.startsWith("rzp_test_") || !keySecret) {
    if (keyId.startsWith("rzp_live_")) {
      return json({ ok: false, error: "live_key_refused" }, 400);
    }
    const { data, error } = await user.rpc("create_demo_payment", {
      p_match_id: matchId,
      p_kind: kind,
      p_amount_inr: amount,
      p_period_label: period,
    });
    if (error) {
      return json({ ok: false, error: "payment" }, 400);
    }
    return json({ ...(data ?? {}), mode: "demo" });
  }
  const { data: match, error: matchError } = await user
    .from("matches")
    .select("participant_a, participant_b, status")
    .eq("id", matchId)
    .maybeSingle();
  if (matchError || !match || match.status !== "active") {
    return json({ ok: false, error: "not_participant" }, 403);
  }
  const payee = match.participant_a === uid
    ? match.participant_b
    : match.participant_b === uid
    ? match.participant_a
    : null;
  if (!payee) {
    return json({ ok: false, error: "not_participant" }, 403);
  }
  const orderResponse = await fetch("https://api.razorpay.com/v1/orders", {
    method: "POST",
    headers: {
      Authorization: `Basic ${btoa(`${keyId}:${keySecret}`)}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      amount: amount * 100,
      currency: "INR",
      receipt: `homizi_${crypto.randomUUID()}`,
      notes: { kind, match_id: matchId },
    }),
  });
  const order = await orderResponse.json();
  if (!orderResponse.ok || typeof order.id !== "string") {
    return json({ ok: false, error: "order" }, 502);
  }
  const admin = adminClient();
  const { data: payment, error } = await admin
    .from("payments")
    .insert({
      user_id: uid,
      payee_user_id: payee,
      match_id: matchId,
      kind,
      amount_inr: amount,
      currency: "INR",
      status: "pending",
      provider: "razorpay",
      provider_order_id: order.id,
      period_label: period,
    })
    .select(
      "id, match_id, kind, amount_inr, status, provider, period_label, provider_order_id, receipt_id",
    )
    .single();
  if (error || !payment) {
    return json({ ok: false, error: "payment" }, 500);
  }
  return json({
    ok: true,
    mode: "razorpay",
    key_id: keyId,
    order_id: order.id,
    amount_paise: amount * 100,
    payment,
  });
});

import { assert, assertEquals } from "jsr:@std/assert@1";

import {
  buildMsg91Request,
  destinationPhone,
  handleSendSms,
  msg91Mobile,
  redactSecrets,
  signWebhook,
  webhookSecretBytes,
} from "./msg91.ts";

const secretBytes = new Uint8Array(32).fill(7);
const secret = `v1,whsec_${btoa(String.fromCharCode(...secretBytes))}`;
const otp = "561166";

function headersFor(raw: string, signature: string, timestamp: string): Headers {
  return new Headers({
    "webhook-id": "msg_1",
    "webhook-timestamp": timestamp,
    "webhook-signature": `v1,${signature}`,
  });
}

Deno.test("the hook forwards Supabase's OTP and does not echo it on failure", async () => {
  const raw = JSON.stringify({
    user: { phone: "+919800000000", new_phone: "+919876543210" },
    sms: { otp, phone: "+919876543210" },
  });
  const timestamp = `${Math.floor(Date.now() / 1000)}`;
  const signature = await signWebhook(secretBytes, "msg_1", timestamp, raw);
  let seenUrl = "";
  let seenAuth = "";
  const response = await handleSendSms({
    rawBody: raw,
    headers: headersFor(raw, signature, timestamp),
    env: {
      secret,
      authKey: "test-auth-key",
      templateId: "template-1",
      senderId: "HOMIZI",
    },
    fetchImpl: (url, init) => {
      seenUrl = String(url);
      seenAuth = new Headers(init?.headers).get("authkey") ?? "";
      return Promise.resolve(new Response(JSON.stringify({ type: "error", message: `refused ${otp}` }), { status: 400 }));
    },
  });
  assert(seenUrl.includes("otp=561166"));
  assert(seenUrl.includes("mobile=919876543210"));
  assert(seenUrl.includes("template_id=template-1"));
  assert(seenUrl.includes("sender=HOMIZI"));
  assertEquals(seenAuth, "test-auth-key");
  assert(!seenUrl.includes("test-auth-key"));
  const body = await response.json();
  assertEquals(response.status, 400);
  assertEquals(body.error.http_code, 400);
  assert(!JSON.stringify(body).includes(otp));
  assert(!JSON.stringify(body).includes("test-auth-key"));
});

Deno.test("a bad signature and a missing secret are refused before MSG91", async () => {
  const raw = JSON.stringify({ sms: { otp, phone: "+919876543210" } });
  const bad = await handleSendSms({
    rawBody: raw,
    headers: headersFor(raw, "not-a-signature", `${Math.floor(Date.now() / 1000)}`),
    env: {
      secret,
      authKey: "k",
      templateId: "t",
      senderId: "HOMIZI",
    },
    fetchImpl: () => {
      throw new Error("fetch should not run");
    },
  });
  assertEquals(bad.status, 401);
  const missing = await handleSendSms({
    rawBody: raw,
    headers: new Headers(),
    env: { secret: "", authKey: "", templateId: "", senderId: "" },
    fetchImpl: () => {
      throw new Error("fetch should not run");
    },
  });
  assertEquals(missing.status, 500);
  assert(!(await missing.text()).includes(otp));
});

Deno.test("phone change uses sms.phone and a success body is empty", async () => {
  assertEquals(
    destinationPhone({
      user: { phone: "+919800000000", new_phone: "+919876543210" },
      sms: { phone: "+919811111111", otp },
    }),
    "+919811111111",
  );
  assertEquals(destinationPhone({ user: { new_phone: "+919876543210" } }), "+919876543210");
  assertEquals(msg91Mobile("+91 98765 43210"), "919876543210");
  assertEquals(msg91Mobile("+14155550100"), null);
  const built = buildMsg91Request({
    authKey: "k",
    templateId: "t",
    senderId: "HOMIZI",
    mobile: "919876543210",
    otp,
  });
  assert(built.url.startsWith("https://control.msg91.com/api/v5/otp"));
  assertEquals(redactSecrets(`failed ${otp} authkey=secret`), "failed authkey");
  assert(webhookSecretBytes(secret) !== null);
  assertEquals(webhookSecretBytes(""), null);
});

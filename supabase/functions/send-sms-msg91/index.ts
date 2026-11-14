import { env, json } from "../_shared/http.ts";
import { handleSendSms, hookError } from "../_shared/msg91.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return hookError(405, "Method not allowed.");
  }
  const raw = await req.text();
  try {
    return await handleSendSms({
      rawBody: raw,
      headers: req.headers,
      env: {
        secret: env("SEND_SMS_HOOK_SECRET"),
        authKey: env("MSG91_AUTH_KEY"),
        templateId: env("MSG91_TEMPLATE_ID"),
        senderId: env("MSG91_SENDER_ID"),
      },
      fetchImpl: fetch,
    });
  } catch {
    return json(
      { error: { http_code: 500, message: "The SMS was not sent." } },
      500,
    );
  }
});

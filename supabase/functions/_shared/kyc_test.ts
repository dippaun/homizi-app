import { assert, assertEquals } from "jsr:@std/assert@1";

import { secretsEqual } from "./http.ts";
import {
  allowedReturnUrl,
  corsHeaders,
  customerIdentifier,
  defaultReturnUrl,
  kycConfigured,
  mergeWebhookDecision,
  withRedirect,
  last4,
  openDigioKyc,
  parseDigioWebhook,
  resolveDigioHosts,
  signedChecksum,
} from "./kyc.ts";

Deno.test("missing Digio secrets never produce a pass", async () => {
  const result = await openDigioKyc({
    fetchImpl: () => {
      throw new Error("fetch should not run");
    },
    clientId: "",
    clientSecret: "",
    digioEnv: "",
    baseUrl: "",
    templateName: "",
    identifier: "meera@example.test",
    name: "Meera",
    referenceId: "11111111-1111-4111-8111-111111111111",
  });
  assertEquals(result, { ok: false, error: "verification_unavailable" });
  assert(!JSON.stringify(result).includes("verified"));
});

Deno.test("the default host is production and a client cannot choose otherwise", () => {
  assertEquals(resolveDigioHosts("", ""), {
    api: "https://api.digio.in",
    gateway: "https://app.digio.in",
  });
  assertEquals(resolveDigioHosts("sandbox", ""), null);
});

Deno.test("a mocked Digio response opens the production gateway", async () => {
  const seen: { url?: string; auth?: string } = {};
  const result = await openDigioKyc({
    fetchImpl: (input, init) => {
      seen.url = String(input);
      seen.auth = new Headers(init?.headers).get("Authorization") ?? "";
      return Promise.resolve(new Response(JSON.stringify({
        id: "KID2201",
        status: "requested",
        customer_identifier: "meera@example.test",
        access_token: { id: "GWT1", entity_id: "KID2201" },
      }), { status: 200 }));
    },
    clientId: "client-id",
    clientSecret: "client-secret",
    digioEnv: "production",
    baseUrl: "",
    templateName: "HOMIZI_AADHAAR_FACE",
    identifier: "meera@example.test",
    name: "Meera",
    referenceId: "11111111-1111-4111-8111-111111111111",
  });
  assert(result.ok);
  if (result.ok) {
    assertEquals(
      result.gatewayUrl,
      "https://app.digio.in/#/gateway/login/KID2201/meera%40example.test/GWT1",
    );
    assert(!result.gatewayUrl.includes("sandbox"));
    assertEquals("environment" in result, false);
  }
  assertEquals(seen.url, "https://api.digio.in/client/kyc/v2/request/with_template");
  assert(seen.auth?.startsWith("Basic "));
  const encoded = JSON.stringify(result).toLowerCase();
  assert(!encoded.includes("sandbox"));
  assert(!encoded.includes("demo"));
  assert(!encoded.includes("client-secret"));
});

Deno.test("a webhook keeps only the last 4 and the two check results", () => {
  const decision = parseDigioWebhook({
    event: "kyc.request.completed",
    payload: {
      kyc_request: {
        id: "KID2201",
        status: "approved",
        actions: [
          {
            type: "digilocker",
            status: "approved",
            details: { aadhaar: { id_number: "123456789012" } },
          },
          {
            type: "selfie",
            status: "approved",
            face_match_result: { match_result: "matched", confidence: 96 },
          },
        ],
      },
    },
  });
  assertEquals(decision, {
    requestId: "KID2201",
    aadhaarStatus: "verified",
    faceStatus: "verified",
    maskedLast4: "9012",
  });
  assert(!JSON.stringify(decision).includes("123456789012"));
  assertEquals(last4("XXXX-XXXX-4821"), "4821");
});

Deno.test("a rejected webhook fails both checks and a bad checksum is refused", async () => {
  const decision = parseDigioWebhook({
    payload: { kyc_request: { id: "KID9", status: "rejected", actions: [] } },
  });
  assertEquals(decision?.aadhaarStatus, "failed");
  assertEquals(decision?.faceStatus, "failed");
  assertEquals(decision?.maskedLast4, null);
  const body = "{\"id\":\"KID9\"}";
  const checksum = await signedChecksum("webhook-secret", body);
  assert(secretsEqual(checksum, checksum));
  assert(!secretsEqual(checksum, "0".repeat(checksum.length)));
  assertEquals(customerIdentifier("Meera@Example.test", ""), "meera@example.test");
  assertEquals(customerIdentifier("", "+91 98765 43210"), "9876543210");
  assertEquals(customerIdentifier("", "123456789012"), null);
});

const read = (values: Record<string, string>) => (name: string) => values[name] ?? "";

Deno.test("kycConfigured is false until every Digio secret is set", () => {
  assertEquals(kycConfigured(read({})), false);
  assertEquals(kycConfigured(read({ DIGIO_CLIENT_ID: "id", DIGIO_CLIENT_SECRET: "s" })), false);
  assertEquals(kycConfigured(read({
    DIGIO_CLIENT_ID: "id",
    DIGIO_CLIENT_SECRET: "s",
    DIGIO_KYC_TEMPLATE: "HOMIZI_KYC",
  })), true);
  assertEquals(kycConfigured(read({
    DIGIO_CLIENT_ID: "id",
    DIGIO_CLIENT_SECRET: "s",
    DIGIO_KYC_TEMPLATE: "HOMIZI_KYC",
    DIGIO_ENV: "sandbox",
  })), false);
});

Deno.test("the return URL comes from the server allowlist", () => {
  assertEquals(defaultReturnUrl, "https://dippaun.github.io/homizi-app/#/verify");
  assertEquals(allowedReturnUrl("https://evil.example/#/verify", read({})), defaultReturnUrl);
  assertEquals(allowedReturnUrl(undefined, read({})), defaultReturnUrl);
  const list = read({
    KYC_RETURN_URLS: "https://dippaun.github.io/homizi-app/#/verify, http://localhost:8765/homizi-app/#/verify",
  });
  assertEquals(
    allowedReturnUrl("http://localhost:8765/homizi-app/#/verify", list),
    "http://localhost:8765/homizi-app/#/verify",
  );
  assertEquals(allowedReturnUrl("https://homizi.netlify.app/verify", list), defaultReturnUrl);
  const link = withRedirect("https://app.digio.in/#/gateway/login/KID/a%40b.in/GWT", defaultReturnUrl);
  assert(link.includes("redirect_url=https%3A%2F%2Fdippaun.github.io%2Fhomizi-app%2F%23%2Fverify"));
});

Deno.test("CORS allows the live app and local builds only", () => {
  assertEquals(
    corsHeaders("https://dippaun.github.io", read({}))["Access-Control-Allow-Origin"],
    "https://dippaun.github.io",
  );
  assertEquals(
    corsHeaders("http://localhost:8765", read({}))["Access-Control-Allow-Origin"],
    "http://localhost:8765",
  );
  assertEquals(
    corsHeaders("https://evil.example", read({}))["Access-Control-Allow-Origin"],
    "https://dippaun.github.io",
  );
});

Deno.test("webhook replays and out-of-order events are idempotent", () => {
  const stored = {
    providerReference: "KID1",
    aadhaarStatus: "verified",
    faceStatus: "verified",
    maskedLast4: "4821",
  };
  // A late "in progress" never undoes a pass.
  assertEquals(mergeWebhookDecision(stored, {
    requestId: "KID1",
    aadhaarStatus: "in_progress",
    faceStatus: "in_progress",
    maskedLast4: null,
  }), null);
  // The same event twice writes once.
  const pending = { ...stored, aadhaarStatus: "in_progress", faceStatus: "in_progress", maskedLast4: null };
  const pass = {
    requestId: "KID1",
    aadhaarStatus: "verified" as const,
    faceStatus: "verified" as const,
    maskedLast4: "4821",
  };
  assertEquals(mergeWebhookDecision(pending, pass), pass);
  assertEquals(mergeWebhookDecision(stored, pass), null);
  // A stale request id is ignored.
  assertEquals(mergeWebhookDecision({ ...pending, providerReference: "KID2" }, pass), null);
  // A failure stays failed against a late "in progress".
  const failed = { ...pending, aadhaarStatus: "failed", faceStatus: "failed" };
  assertEquals(mergeWebhookDecision(failed, { ...pass, aadhaarStatus: "in_progress", faceStatus: "in_progress", maskedLast4: null }), null);
});

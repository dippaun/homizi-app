import { assert, assertEquals } from "jsr:@std/assert@1";

import { secretsEqual } from "./http.ts";
import {
  customerIdentifier,
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

import { hmacHex, looksLikeAadhaar } from "./http.ts";

export const productionApi = "https://api.digio.in";
export const productionGateway = "https://app.digio.in";

export type DigioHosts = { api: string; gateway: string };

export type OpenKycResult =
  | { ok: true; requestId: string; gatewayUrl: string }
  | { ok: false; error: "verification_unavailable" };

export type KycCheckStatus = "in_progress" | "verified" | "failed";

export type KycDecision = {
  requestId: string;
  aadhaarStatus: KycCheckStatus;
  faceStatus: KycCheckStatus;
  maskedLast4: string | null;
};

const aadhaarTypes = new Set([
  "digilocker",
  "aadhaar_offline",
  "aadhaar",
  "offline_kyc",
]);
const faceTypes = new Set([
  "selfie",
  "face_match",
  "facematch",
  "liveness",
  "video",
]);
const okStatus = new Set(["approved", "success", "completed", "matched", "done"]);
const badStatus = new Set(["rejected", "failed", "expired", "failure"]);

/// Production hosts unless an operator set both a non-production DIGIO_ENV
/// and an https DIGIO_BASE_URL. The client never sends this choice.
export function resolveDigioHosts(digioEnv: string, baseUrl: string): DigioHosts | null {
  const mode = digioEnv.trim().toLowerCase() || "production";
  const explicit = baseUrl.trim().replace(/\/$/, "");
  if (mode === "production" || mode === "prod") {
    if (explicit && !explicit.startsWith("https://")) {
      return null;
    }
    return {
      api: explicit || productionApi,
      gateway: productionGateway,
    };
  }
  if (!explicit.startsWith("https://")) {
    return null;
  }
  return { api: explicit, gateway: explicit };
}

export function templateFor(kind: string, read: (name: string) => string): string {
  if (kind === "aadhaar_offline") {
    return read("DIGIO_TEMPLATE_AADHAAR_OFFLINE") || read("DIGIO_KYC_TEMPLATE");
  }
  return read("DIGIO_TEMPLATE_DIGILOCKER") || read("DIGIO_KYC_TEMPLATE");
}

export function customerIdentifier(email: string, phone: string): string | null {
  const mail = email.trim().toLowerCase();
  if (mail.includes("@") && !looksLikeAadhaar(mail)) {
    return mail;
  }
  const digits = phone.replace(/\D/g, "");
  const mobile = digits.length > 10 ? digits.slice(-10) : digits;
  if (mobile.length === 10 && !looksLikeAadhaar(mobile)) {
    return mobile;
  }
  return null;
}

export function digioRequestBody(input: {
  identifier: string;
  name: string;
  referenceId: string;
  templateName: string;
}): Record<string, unknown> {
  return {
    customer_identifier: input.identifier,
    customer_name: input.name,
    reference_id: input.referenceId,
    template_name: input.templateName,
    notify_customer: false,
    generate_access_token: true,
    expire_in_days: 10,
  };
}

export function parseDigioSession(payload: unknown): {
  requestId: string;
  tokenId: string;
  identifier: string;
} | null {
  if (!payload || typeof payload !== "object") {
    return null;
  }
  const body = payload as Record<string, unknown>;
  const requestId = String(body.id ?? "");
  const token = body.access_token;
  const tokenId = token && typeof token === "object"
    ? String((token as Record<string, unknown>).id ?? "")
    : "";
  const identifier = String(body.customer_identifier ?? "");
  if (!requestId || !tokenId || !identifier) {
    return null;
  }
  if (looksLikeAadhaar(requestId) || looksLikeAadhaar(tokenId) || looksLikeAadhaar(identifier)) {
    return null;
  }
  return { requestId, tokenId, identifier };
}

export function gatewayUrl(
  host: string,
  requestId: string,
  identifier: string,
  tokenId: string,
): string {
  const base = host.replace(/\/$/, "");
  return `${base}/#/gateway/login/${encodeURIComponent(requestId)}/${encodeURIComponent(identifier)}/${encodeURIComponent(tokenId)}`;
}

export async function openDigioKyc(input: {
  fetchImpl: typeof fetch;
  clientId: string;
  clientSecret: string;
  digioEnv: string;
  baseUrl: string;
  templateName: string;
  identifier: string;
  name: string;
  referenceId: string;
}): Promise<OpenKycResult> {
  if (!input.clientId || !input.clientSecret || !input.templateName || !input.identifier) {
    return { ok: false, error: "verification_unavailable" };
  }
  const hosts = resolveDigioHosts(input.digioEnv, input.baseUrl);
  if (!hosts) {
    return { ok: false, error: "verification_unavailable" };
  }
  let response: Response;
  try {
    response = await input.fetchImpl(`${hosts.api}/client/kyc/v2/request/with_template`, {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${input.clientId}:${input.clientSecret}`)}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(digioRequestBody({
        identifier: input.identifier,
        name: input.name,
        referenceId: input.referenceId,
        templateName: input.templateName,
      })),
    });
  } catch {
    return { ok: false, error: "verification_unavailable" };
  }
  const created = await response.json().catch(() => ({}));
  if (!response.ok) {
    return { ok: false, error: "verification_unavailable" };
  }
  const session = parseDigioSession(created);
  if (!session) {
    return { ok: false, error: "verification_unavailable" };
  }
  return {
    ok: true,
    requestId: session.requestId,
    gatewayUrl: gatewayUrl(hosts.gateway, session.requestId, session.identifier, session.tokenId),
  };
}

export function last4(value: unknown): string | null {
  if (typeof value !== "string" && typeof value !== "number") {
    return null;
  }
  const digits = String(value).replace(/\D/g, "");
  if (digits.length < 4) {
    return null;
  }
  return digits.slice(-4);
}

function readMask(value: unknown, found: { mask: string | null }): void {
  if (!value || typeof value !== "object") {
    return;
  }
  if (Array.isArray(value)) {
    for (const item of value) {
      readMask(item, found);
    }
    return;
  }
  for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
    if (key === "id_number" || key === "uid" || key === "aadhaar_number" || key === "masked_aadhaar") {
      const mask = last4(item);
      if (mask) {
        found.mask = mask;
      }
    } else if (item && typeof item === "object") {
      readMask(item, found);
    }
  }
}

function actionState(action: Record<string, unknown>, face: boolean): KycCheckStatus {
  const status = String(action.status ?? "").toLowerCase();
  const match = action.face_match_result ?? action.face_match;
  let matchWord = "";
  if (match && typeof match === "object") {
    const record = match as Record<string, unknown>;
    matchWord = String(record.match_result ?? record.result ?? "").toLowerCase();
  }
  if (face && (matchWord.includes("not") || matchWord.includes("mismatch"))) {
    return "failed";
  }
  if (badStatus.has(status)) {
    return "failed";
  }
  if (okStatus.has(status) || (face && (matchWord === "matched" || matchWord === "match"))) {
    return "verified";
  }
  return "in_progress";
}

export function parseDigioWebhook(payload: unknown): KycDecision | null {
  if (!payload || typeof payload !== "object") {
    return null;
  }
  const root = payload as Record<string, unknown>;
  const inner = root.payload && typeof root.payload === "object"
    ? root.payload as Record<string, unknown>
    : root;
  const request = inner.kyc_request && typeof inner.kyc_request === "object"
    ? inner.kyc_request as Record<string, unknown>
    : inner;
  const requestId = String(request.id ?? "");
  if (!requestId || looksLikeAadhaar(requestId)) {
    return null;
  }
  const top = String(request.status ?? root.event ?? "").toLowerCase();
  const actions = Array.isArray(request.actions) ? request.actions : [];
  let aadhaar: KycCheckStatus = "in_progress";
  let face: KycCheckStatus = "in_progress";
  let sawAadhaar = false;
  let sawFace = false;
  const found = { mask: null as string | null };
  for (const item of actions) {
    if (!item || typeof item !== "object") {
      continue;
    }
    const action = item as Record<string, unknown>;
    const type = String(action.type ?? action.action_ref ?? "").toLowerCase();
    if (aadhaarTypes.has(type)) {
      sawAadhaar = true;
      aadhaar = actionState(action, false);
      readMask(action, found);
    }
    if (faceTypes.has(type)) {
      sawFace = true;
      face = actionState(action, true);
    }
  }
  const approved = top.includes("approved") || top.includes("completed") || top === "success";
  const rejected = badStatus.has(top) || top.includes("rejected") || top.includes("failed");
  if (approved) {
    if (!sawAadhaar) {
      aadhaar = "verified";
    }
    if (!sawFace) {
      face = "verified";
    }
  } else if (rejected) {
    if (!sawAadhaar) {
      aadhaar = "failed";
    }
    if (!sawFace) {
      face = "failed";
    }
  }
  if (!sawAadhaar) {
    readMask(request, found);
  }
  return {
    requestId,
    aadhaarStatus: aadhaar,
    faceStatus: face,
    maskedLast4: found.mask,
  };
}

export async function signedChecksum(secret: string, rawBody: string): Promise<string> {
  return (await hmacHex(secret, rawBody)).toLowerCase();
}

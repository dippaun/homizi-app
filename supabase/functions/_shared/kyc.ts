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

export const sandboxApi = "https://ext.digio.in:444";
export const sandboxGateway = "https://ext.digio.in";

export type DigioMode = "production" | "sandbox";

/// Which Digio environment the operator chose. Unset means production. The
/// client never sends this choice; only the DIGIO_ENV function secret does.
export function digioMode(digioEnv: string): DigioMode | null {
  const mode = digioEnv.trim().toLowerCase() || "production";
  if (mode === "production" || mode === "prod" || mode === "live") {
    return "production";
  }
  if (mode === "sandbox" || mode === "staging" || mode === "test") {
    return "sandbox";
  }
  return null;
}

/// Production hosts unless DIGIO_ENV=sandbox, which uses Digio's published
/// sandbox hosts (API https://ext.digio.in:444, gateway https://ext.digio.in).
/// An https DIGIO_BASE_URL overrides the API host only. Any other DIGIO_ENV
/// value turns verification off rather than guessing.
export function resolveDigioHosts(digioEnv: string, baseUrl: string): DigioHosts | null {
  const mode = digioMode(digioEnv);
  const explicit = baseUrl.trim().replace(/\/$/, "");
  if (!mode || (explicit && !explicit.startsWith("https://"))) {
    return null;
  }
  if (mode === "production") {
    return { api: explicit || productionApi, gateway: productionGateway };
  }
  return { api: explicit || sandboxApi, gateway: sandboxGateway };
}

export function templateFor(kind: string, read: (name: string) => string): string {
  if (kind === "aadhaar_offline") {
    return read("DIGIO_TEMPLATE_AADHAAR_OFFLINE") || read("DIGIO_KYC_TEMPLATE") ||
      read("DIGIO_TEMPLATE_NAME");
  }
  return read("DIGIO_TEMPLATE_DIGILOCKER") || read("DIGIO_KYC_TEMPLATE") ||
    read("DIGIO_TEMPLATE_NAME");
}

export function customerIdentifier(email: string, phone: string): string | null {
  const mail = email.trim().toLowerCase();
  if (mail.includes("@") && !looksLikeAadhaar(mail)) {
    return mail;
  }
  if (looksLikeAadhaar(phone.trim())) {
    return null;
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

// ---------------------------------------------------------------------------
// Go-live helpers (Nov 2026): availability, return-URL allowlist, CORS and
// webhook idempotency. None of these can mark anyone verified.

/// The live app. Digio sends people back here after the check.
export const defaultReturnUrl = "https://dippaun.github.io/homizi-app/#/verify";

/// Web origins allowed to call start-kyc from a browser.
export const defaultAllowedOrigins = [
  "https://dippaun.github.io",
  "http://localhost",
  "http://127.0.0.1",
];

/// True only when every secret start-kyc needs is set. The values are never
/// returned, only this boolean.
export function kycConfigured(read: (name: string) => string): boolean {
  const hosts = resolveDigioHosts(read("DIGIO_ENV"), read("DIGIO_BASE_URL"));
  return Boolean(
    read("DIGIO_CLIENT_ID") &&
      read("DIGIO_CLIENT_SECRET") &&
      (read("DIGIO_WEBHOOK_SECRET") || read("DIGIO_CLIENT_SECRET")) &&
      templateFor("digilocker", read) &&
      hosts,
  );
}

function splitList(value: string): string[] {
  return value.split(",").map((item) => item.trim()).filter((item) => item.length > 0);
}

/// The return URL Digio may redirect to. A requested URL is used only when it
/// is on the server allowlist (KYC_RETURN_URLS, comma-separated); otherwise
/// the first allowlisted URL, defaulting to the live GitHub Pages app.
export function allowedReturnUrl(requested: unknown, read: (name: string) => string): string {
  const list = splitList(read("KYC_RETURN_URLS"));
  const allow = list.length > 0 ? list : [defaultReturnUrl];
  const wanted = typeof requested === "string" ? requested.trim() : "";
  if (wanted && allow.includes(wanted)) {
    return wanted;
  }
  return allow[0];
}

/// Gateway link with Digio's redirect_url parameter. The fragment-style
/// Digio link takes the parameter after the fragment path.
export function withRedirect(gateway: string, returnUrl: string): string {
  const join = gateway.includes("?") ? "&" : "?";
  return `${gateway}${join}redirect_url=${encodeURIComponent(returnUrl)}`;
}

export function corsHeaders(origin: string | null, read: (name: string) => string): Record<string, string> {
  const list = splitList(read("KYC_ALLOWED_ORIGINS"));
  const allow = list.length > 0 ? list : defaultAllowedOrigins;
  const value = origin ?? "";
  const ok = allow.some((item) =>
    value === item || (item.startsWith("http://localhost") || item.startsWith("http://127.0.0.1")
      ? value.startsWith(`${item}:`) || value === item
      : false)
  );
  return {
    "Access-Control-Allow-Origin": ok ? value : allow[0],
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    Vary: "Origin",
  };
}

export type StoredChecks = {
  providerReference: string | null;
  aadhaarStatus: string;
  faceStatus: string;
  maskedLast4: string | null;
};

/// Webhook idempotency. For the same Digio request a check never moves back
/// from verified or failed to in progress (Digio retries and sends events out
/// of order), and a replay that changes nothing is skipped. Returns null to
/// skip the write.
export function mergeWebhookDecision(stored: StoredChecks, decision: KycDecision): KycDecision | null {
  if (stored.providerReference !== decision.requestId) {
    return null;
  }
  const keep = (current: string, next: KycCheckStatus): KycCheckStatus => {
    if (current === "verified") {
      return "verified";
    }
    if (current === "failed" && next === "in_progress") {
      return "failed";
    }
    return next;
  };
  const merged: KycDecision = {
    requestId: decision.requestId,
    aadhaarStatus: keep(stored.aadhaarStatus, decision.aadhaarStatus),
    faceStatus: keep(stored.faceStatus, decision.faceStatus),
    maskedLast4: decision.maskedLast4 ?? stored.maskedLast4,
  };
  if (
    merged.aadhaarStatus === stored.aadhaarStatus &&
    merged.faceStatus === stored.faceStatus &&
    merged.maskedLast4 === stored.maskedLast4
  ) {
    return null;
  }
  return merged;
}

/// Names of the required Digio secrets that are still missing. Names only,
/// never values, so the status answer can say what to set.
export function missingKycSecrets(read: (name: string) => string): string[] {
  const missing: string[] = [];
  if (!read("DIGIO_CLIENT_ID")) missing.push("DIGIO_CLIENT_ID");
  if (!read("DIGIO_CLIENT_SECRET")) missing.push("DIGIO_CLIENT_SECRET");
  if (!templateFor("digilocker", read)) missing.push("DIGIO_TEMPLATE_NAME");
  if (!resolveDigioHosts(read("DIGIO_ENV"), read("DIGIO_BASE_URL"))) missing.push("DIGIO_ENV");
  return missing;
}

/// The status answer the app reads before showing any Aadhaar step.
export function kycStatusBody(read: (name: string) => string): Record<string, unknown> {
  if (!kycConfigured(read)) {
    return { ok: true, available: false, reason: "not_configured" };
  }
  return { ok: true, available: true, environment: digioMode(read("DIGIO_ENV")) };
}

export type FetchedDecision =
  | { ok: true; decision: KycDecision }
  | { ok: false; error: "verification_unavailable" | "status_failed" };

/// Reads a KYC request's current result straight from Digio (server to
/// server, Basic auth), so the app can finish even before a webhook lands.
/// The answer must be for the same request id we stored.
export async function fetchDigioDecision(input: {
  fetchImpl: typeof fetch;
  clientId: string;
  clientSecret: string;
  digioEnv: string;
  baseUrl: string;
  requestId: string;
}): Promise<FetchedDecision> {
  if (!input.clientId || !input.clientSecret || !input.requestId || looksLikeAadhaar(input.requestId)) {
    return { ok: false, error: "verification_unavailable" };
  }
  const hosts = resolveDigioHosts(input.digioEnv, input.baseUrl);
  if (!hosts) {
    return { ok: false, error: "verification_unavailable" };
  }
  const url = `${hosts.api}/client/kyc/v2/${encodeURIComponent(input.requestId)}/response`;
  const headers = {
    Authorization: `Basic ${btoa(`${input.clientId}:${input.clientSecret}`)}`,
    "Content-Type": "application/json",
  };
  let response: Response;
  try {
    // Digio documents this as POST; older accounts answer GET.
    response = await input.fetchImpl(url, { method: "POST", headers, body: "{}" });
    if (response.status === 404 || response.status === 405) {
      response = await input.fetchImpl(url, { method: "GET", headers });
    }
  } catch {
    return { ok: false, error: "status_failed" };
  }
  if (!response.ok) {
    return { ok: false, error: "status_failed" };
  }
  const body = await response.json().catch(() => null);
  const decision = parseDigioWebhook(body);
  if (!decision || decision.requestId !== input.requestId) {
    return { ok: false, error: "status_failed" };
  }
  return { ok: true, decision };
}

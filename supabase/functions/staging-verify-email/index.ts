import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

/** Must match Spot staging project ref (`SupabaseEnvironment.stagingProjectRef`). */
const ALLOWED_STAGING_PROJECT_REF = "aeurigbbohyxvtsfiyul";
const MAX_ATTEMPTS_PER_HOUR = 10;
const WINDOW_MS = 60 * 60 * 1000;
const GENERIC_UNAUTHORIZED = "Verification unavailable.";
const GENERIC_RATE_LIMITED = "Too many attempts. Try again later.";
const GENERIC_ALREADY_CONFIRMED = "Account already verified. Log in instead.";
/** Default dev code when `STAGING_TEST_AUTH_CODE` is unset (staging only). */
const DEFAULT_TEST_AUTH_CODE = "UT1234";

type RequestBody = {
  userId?: unknown;
  email?: unknown;
  code?: unknown;
};

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      Connection: "keep-alive",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
    },
  });
}

function logOutcome(outcome: string): void {
  // Privacy-safe: never log email, code, token hash, or raw user IDs.
  console.log(JSON.stringify({ event: "staging_verify_email", outcome }));
}

function normalizeEmail(value: string): string {
  return value.trim().toLowerCase();
}

function parseOptionalAllowlist(raw: string | undefined): Set<string> | null {
  const trimmed = (raw ?? "").trim();
  // Empty / unset → any email allowed on staging (local Xcode dev flow).
  if (!trimmed) return null;
  const entries = trimmed
    .split(",")
    .map((part) => normalizeEmail(part))
    .filter((part) => part.length > 0 && part.includes("@"));
  return new Set(entries);
}

function normalizeInternalCode(value: string): string {
  return value.trim().toUpperCase();
}

/** Constant-time string compare for equal-length secrets. */
export function timingSafeEqualString(a: string, b: string): boolean {
  const encoder = new TextEncoder();
  const aBytes = encoder.encode(a);
  const bBytes = encoder.encode(b);
  if (aBytes.length !== bBytes.length) {
    // Still walk the longer buffer so length leaks are harder to observe.
    let diff = aBytes.length ^ bBytes.length;
    const max = Math.max(aBytes.length, bBytes.length);
    for (let i = 0; i < max; i++) {
      const av = i < aBytes.length ? aBytes[i] : 0;
      const bv = i < bBytes.length ? bBytes[i] : 0;
      diff |= av ^ bv;
    }
    return false;
  }
  let diff = 0;
  for (let i = 0; i < aBytes.length; i++) {
    diff |= aBytes[i] ^ bBytes[i];
  }
  return diff === 0;
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function projectRefFromUrl(url: string): string | null {
  try {
    const host = new URL(url).hostname.toLowerCase();
    if (!host.endsWith(".supabase.co")) return null;
    return host.replace(".supabase.co", "");
  } catch {
    return null;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return jsonResponse({ ok: true });
  }

  if (req.method !== "POST") {
    logOutcome("method_not_allowed");
    return jsonResponse({ error: GENERIC_UNAUTHORIZED }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const enabled = (Deno.env.get("STAGING_TEST_AUTH_ENABLED") ?? "")
    .trim()
    .toLowerCase();
  const expectedCode = normalizeInternalCode(
    Deno.env.get("STAGING_TEST_AUTH_CODE") ?? DEFAULT_TEST_AUTH_CODE,
  );
  const allowlist = parseOptionalAllowlist(
    Deno.env.get("STAGING_TEST_AUTH_EMAILS"),
  );

  const projectRef = projectRefFromUrl(supabaseUrl);
  if (projectRef !== ALLOWED_STAGING_PROJECT_REF) {
    logOutcome("non_staging_environment");
    return jsonResponse({ error: GENERIC_UNAUTHORIZED }, 403);
  }

  if (enabled !== "true" && enabled !== "1") {
    logOutcome("disabled_configuration");
    return jsonResponse({ error: GENERIC_UNAUTHORIZED }, 403);
  }

  if (!serviceRoleKey || !expectedCode) {
    logOutcome("misconfigured_secrets");
    return jsonResponse({ error: GENERIC_UNAUTHORIZED }, 403);
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    logOutcome("invalid_json");
    return jsonResponse({ error: GENERIC_UNAUTHORIZED }, 400);
  }

  const userId = typeof body.userId === "string" ? body.userId.trim() : "";
  const email = typeof body.email === "string"
    ? normalizeEmail(body.email)
    : "";
  const code = typeof body.code === "string"
    ? normalizeInternalCode(body.code)
    : "";

  if (!isUuid(userId) || !email.includes("@") || code.length === 0) {
    logOutcome("invalid_request_shape");
    return jsonResponse({ error: GENERIC_UNAUTHORIZED }, 401);
  }

  if (allowlist !== null && !allowlist.has(email)) {
    logOutcome("allowlist_failure");
    return jsonResponse({ error: GENERIC_UNAUTHORIZED }, 401);
  }

  if (!timingSafeEqualString(code, expectedCode)) {
    logOutcome("invalid_internal_code");
    return jsonResponse({ error: GENERIC_UNAUTHORIZED }, 401);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Rate limit by pending user ID (service-role table; no client policies).
  const windowStart = new Date(Date.now() - WINDOW_MS).toISOString();
  const { count, error: countError } = await admin
    .from("staging_test_auth_attempts")
    .select("id", { count: "exact", head: true })
    .eq("pending_user_id", userId)
    .gte("attempted_at", windowStart);

  if (countError) {
    logOutcome("rate_limit_query_failed");
    return jsonResponse({ error: GENERIC_UNAUTHORIZED }, 503);
  }

  if ((count ?? 0) >= MAX_ATTEMPTS_PER_HOUR) {
    logOutcome("rate_limited");
    return jsonResponse({ error: GENERIC_RATE_LIMITED }, 429);
  }

  const { error: insertError } = await admin
    .from("staging_test_auth_attempts")
    .insert({ pending_user_id: userId });

  if (insertError) {
    logOutcome("rate_limit_insert_failed");
    return jsonResponse({ error: GENERIC_UNAUTHORIZED }, 503);
  }

  const { data: userData, error: userError } = await admin.auth.admin.getUserById(
    userId,
  );
  if (userError || !userData?.user) {
    logOutcome("pending_user_mismatch");
    return jsonResponse({ error: GENERIC_UNAUTHORIZED }, 401);
  }

  const user = userData.user;
  const userEmail = normalizeEmail(user.email ?? "");
  if (!userEmail || userEmail !== email) {
    logOutcome("pending_user_mismatch");
    return jsonResponse({ error: GENERIC_UNAUTHORIZED }, 401);
  }

  if (user.email_confirmed_at) {
    logOutcome("already_confirmed");
    return jsonResponse({ error: GENERIC_ALREADY_CONFIRMED }, 409);
  }

  const { data: linkData, error: linkError } = await admin.auth.admin
    .generateLink({
      type: "magiclink",
      email,
    });

  if (linkError || !linkData) {
    logOutcome("token_generation_failed");
    return jsonResponse({ error: GENERIC_UNAUTHORIZED }, 503);
  }

  const hashedToken =
    (linkData as { properties?: { hashed_token?: string } }).properties
      ?.hashed_token ??
      (linkData as { hashed_token?: string }).hashed_token;

  if (!hashedToken || typeof hashedToken !== "string") {
    logOutcome("token_generation_failed");
    return jsonResponse({ error: GENERIC_UNAUTHORIZED }, 503);
  }

  logOutcome("allowed");
  return jsonResponse({
    tokenHash: hashedToken,
    type: "magiclink",
  });
});

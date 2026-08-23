import {
  decodeProtectedHeader,
  importJWK,
  importX509,
  jwtVerify
} from "jose";
import type { JWK } from "jose";
import { z } from "zod";
import { readProviderJson } from "./http";

const AUTH_CERTIFICATES_URL =
  "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com";
const APP_CHECK_JWKS_URL =
  "https://firebaseappcheck.googleapis.com/v1/jwks";
const KEY_FETCH_TIMEOUT_MS = 5_000;

type KeyResolver = (kid: string) => Promise<CryptoKey>;

interface CachedKeys {
  readonly keys: ReadonlyMap<string, CryptoKey>;
  readonly expiresAtMs: number;
}

export interface IdTokenVerificationOptions {
  readonly projectId: string;
  readonly keyResolver: KeyResolver;
  readonly nowMs: number;
}

export interface AppCheckVerificationOptions {
  readonly projectNumber: string;
  readonly allowedAppIds: ReadonlySet<string>;
  readonly keyResolver: KeyResolver;
  readonly nowMs: number;
}

export interface VerifiedIdToken {
  readonly uid: string;
}

export interface VerifiedAppCheckToken {
  readonly appId: string;
}

export class AuthVerificationError extends Error {
  constructor() {
    super("token_verification_failed");
    this.name = "AuthVerificationError";
  }
}

function cacheLifetimeMs(cacheControl: string | null): number {
  const match = /(?:^|,)\s*max-age=(\d+)/i.exec(cacheControl ?? "");
  const seconds = match === null ? 3_600 : Number(match[1]);
  return Math.max(60, Math.min(seconds, 21_600)) * 1_000;
}

async function fetchWithTimeout(
  fetcher: typeof fetch,
  url: string
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => {
    controller.abort();
  }, KEY_FETCH_TIMEOUT_MS);
  try {
    return await fetcher(url, {
      headers: { Accept: "application/json" },
      signal: controller.signal
    });
  } finally {
    clearTimeout(timeout);
  }
}

function createCachedKeyResolver(
  loadKeys: () => Promise<CachedKeys>,
  now: () => number
): KeyResolver {
  let cache: CachedKeys = {
    keys: new Map<string, CryptoKey>(),
    expiresAtMs: 0
  };
  let inFlight: Promise<CachedKeys> | undefined;

  const refresh = async (): Promise<void> => {
    if (inFlight === undefined) {
      inFlight = loadKeys();
    }
    const pending = inFlight;
    try {
      cache = await pending;
    } finally {
      if (inFlight === pending) {
        inFlight = undefined;
      }
    }
  };

  return async (kid: string): Promise<CryptoKey> => {
    if (now() >= cache.expiresAtMs) {
      await refresh();
    }
    const key = cache.keys.get(kid);
    if (key === undefined) {
      throw new AuthVerificationError();
    }
    return key;
  };
}

const x509MapSchema = z.record(
  z.string().min(1).max(256),
  z
    .string()
    .min(100)
    .max(10_000)
    .refine((value) => value.includes("BEGIN CERTIFICATE"))
);

export function createFirebaseAuthKeyResolver(
  fetcher: typeof fetch,
  now: () => number = Date.now
): KeyResolver {
  return createCachedKeyResolver(async () => {
    const response = await fetchWithTimeout(fetcher, AUTH_CERTIFICATES_URL);
    if (!response.ok) {
      await response.body?.cancel();
      throw new AuthVerificationError();
    }
    let certificates: z.infer<typeof x509MapSchema>;
    try {
      certificates = x509MapSchema.parse(await readProviderJson(response));
    } catch {
      throw new AuthVerificationError();
    }
    const entries = await Promise.all(
      Object.entries(certificates).map(async ([kid, certificate]) => {
        const key = await importX509(certificate, "RS256");
        return [kid, key] as const;
      })
    );
    return {
      keys: new Map(entries),
      expiresAtMs:
        now() + cacheLifetimeMs(response.headers.get("Cache-Control"))
    };
  }, now);
}

const jwksSchema = z
  .object({
    keys: z
      .array(
        z
          .object({
            kid: z.string().min(1).max(256),
            kty: z.literal("RSA"),
            alg: z.literal("RS256").optional(),
            use: z.literal("sig").optional()
          })
          .passthrough()
      )
      .min(1)
      .max(20)
  })
  .passthrough();

export function createAppCheckKeyResolver(
  fetcher: typeof fetch,
  now: () => number = Date.now
): KeyResolver {
  return createCachedKeyResolver(async () => {
    const response = await fetchWithTimeout(fetcher, APP_CHECK_JWKS_URL);
    if (!response.ok) {
      await response.body?.cancel();
      throw new AuthVerificationError();
    }
    let document: z.infer<typeof jwksSchema>;
    try {
      document = jwksSchema.parse(await readProviderJson(response));
    } catch {
      throw new AuthVerificationError();
    }
    const entries = await Promise.all(
      document.keys.map(async (jwk) => {
        const imported = await importJWK(jwk as JWK, "RS256");
        if (imported instanceof Uint8Array) {
          throw new AuthVerificationError();
        }
        return [jwk.kid, imported] as const;
      })
    );
    return {
      keys: new Map(entries),
      expiresAtMs:
        now() + cacheLifetimeMs(response.headers.get("Cache-Control"))
    };
  }, now);
}

function assertTokenShape(token: string): void {
  if (
    token.length < 32 ||
    token.length > 8_192 ||
    token.split(".").length !== 3
  ) {
    throw new AuthVerificationError();
  }
}

function assertCommonClaims(
  payload: Readonly<Record<string, unknown>>,
  nowSeconds: number
): void {
  if (
    typeof payload.exp !== "number" ||
    payload.exp <= nowSeconds ||
    typeof payload.iat !== "number" ||
    payload.iat > nowSeconds + 5 ||
    typeof payload.sub !== "string" ||
    payload.sub.length === 0
  ) {
    throw new AuthVerificationError();
  }
}

export async function verifyFirebaseIdToken(
  token: string,
  options: IdTokenVerificationOptions
): Promise<VerifiedIdToken> {
  try {
    assertTokenShape(token);
    const header = decodeProtectedHeader(token);
    if (
      header.alg !== "RS256" ||
      typeof header.kid !== "string" ||
      header.kid.length === 0
    ) {
      throw new AuthVerificationError();
    }
    const key = await options.keyResolver(header.kid);
    const expectedIssuer =
      "https://securetoken.google.com/" + options.projectId;
    const result = await jwtVerify(token, key, {
      algorithms: ["RS256"],
      audience: options.projectId,
      issuer: expectedIssuer,
      currentDate: new Date(options.nowMs)
    });
    const payload = result.payload as Readonly<Record<string, unknown>>;
    const nowSeconds = Math.floor(options.nowMs / 1_000);
    assertCommonClaims(payload, nowSeconds);
    if (
      payload.aud !== options.projectId ||
      payload.iss !== expectedIssuer ||
      typeof payload.auth_time !== "number" ||
      payload.auth_time > nowSeconds + 5 ||
      result.payload.sub === undefined ||
      result.payload.sub.length > 128
    ) {
      throw new AuthVerificationError();
    }
    return { uid: result.payload.sub };
  } catch (error) {
    if (error instanceof AuthVerificationError) {
      throw error;
    }
    throw new AuthVerificationError();
  }
}

function audienceContains(audience: unknown, expected: string): boolean {
  if (typeof audience === "string") {
    return audience === expected;
  }
  return (
    Array.isArray(audience) &&
    audience.every((item) => typeof item === "string") &&
    audience.includes(expected)
  );
}

export async function verifyAppCheckToken(
  token: string,
  options: AppCheckVerificationOptions
): Promise<VerifiedAppCheckToken> {
  try {
    assertTokenShape(token);
    const header = decodeProtectedHeader(token);
    if (
      header.alg !== "RS256" ||
      header.typ !== "JWT" ||
      typeof header.kid !== "string" ||
      header.kid.length === 0
    ) {
      throw new AuthVerificationError();
    }
    const key = await options.keyResolver(header.kid);
    const expectedIssuer =
      "https://firebaseappcheck.googleapis.com/" + options.projectNumber;
    const expectedAudience = "projects/" + options.projectNumber;
    const result = await jwtVerify(token, key, {
      algorithms: ["RS256"],
      audience: expectedAudience,
      issuer: expectedIssuer,
      currentDate: new Date(options.nowMs)
    });
    const payload = result.payload as Readonly<Record<string, unknown>>;
    const nowSeconds = Math.floor(options.nowMs / 1_000);
    assertCommonClaims(payload, nowSeconds);
    if (
      payload.iss !== expectedIssuer ||
      !audienceContains(payload.aud, expectedAudience) ||
      result.payload.sub === undefined ||
      result.payload.sub.length > 256 ||
      (options.allowedAppIds.size > 0 &&
        !options.allowedAppIds.has(result.payload.sub))
    ) {
      throw new AuthVerificationError();
    }
    return { appId: result.payload.sub };
  } catch (error) {
    if (error instanceof AuthVerificationError) {
      throw error;
    }
    throw new AuthVerificationError();
  }
}

export function bearerToken(value: string | null): string {
  if (value === null || value.length > 8_200) {
    throw new AuthVerificationError();
  }
  const match = /^Bearer ([^\s]+)$/i.exec(value.trim());
  if (match?.[1] === undefined) {
    throw new AuthVerificationError();
  }
  assertTokenShape(match[1]);
  return match[1];
}

export function appCheckHeaderToken(value: string | null): string {
  if (value === null || value.length > 8_192 || /\s/.test(value)) {
    throw new AuthVerificationError();
  }
  assertTokenShape(value);
  return value;
}

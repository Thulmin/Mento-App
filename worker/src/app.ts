import {
  appCheckHeaderToken,
  AuthVerificationError,
  bearerToken
} from "./auth";
import type {
  VerifiedAppCheckToken,
  VerifiedIdToken
} from "./auth";
import {
  HttpError,
  ProviderFailure,
  providerFailureToHttp
} from "./errors";
import {
  jsonResponse,
  readRequestJson
} from "./http";
import type { StructuredLogger } from "./logging";
import type { ProviderResult } from "./provider";
import type { QuotaResult } from "./quota";
import {
  definitionForPath
} from "./schemas";
import type { EndpointDefinition } from "./schemas";
import { containsSensitiveCredential } from "./sensitive";

const ALLOWED_PREFLIGHT_HEADERS = new Set([
  "authorization",
  "content-type",
  "x-firebase-appcheck",
  "x-client-request-id"
]);
const CLIENT_REQUEST_ID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export interface AppConfig {
  readonly allowedOrigins: ReadonlySet<string>;
  readonly dailyUserQuota: number;
  readonly maxRequestBytes: number;
  readonly appCheckEnforced?: boolean;
}

export interface AppDependencies {
  readonly verifyIdToken: (
    token: string
  ) => Promise<VerifiedIdToken>;
  readonly verifyAppCheck: (
    token: string
  ) => Promise<VerifiedAppCheckToken>;
  readonly consumeQuota: (
    uid: string,
    day: string,
    limit: number,
    nowMs: number
  ) => Promise<QuotaResult>;
  readonly generate: (
    definition: EndpointDefinition,
    input: unknown,
    signal: AbortSignal
  ) => Promise<ProviderResult>;
  readonly hashUid: (uid: string) => Promise<string>;
  readonly logger: StructuredLogger;
  readonly now: () => number;
  readonly randomUuid: () => string;
}

function expectedMethod(path: string): "GET" | "POST" | undefined {
  if (path === "/v1/health") {
    return "GET";
  }
  return definitionForPath(path) === undefined ? undefined : "POST";
}

function validateOrigin(
  request: Request,
  allowedOrigins: ReadonlySet<string>
): string | undefined {
  const origin = request.headers.get("Origin");
  if (origin === null) {
    return undefined;
  }
  if (!allowedOrigins.has(origin)) {
    throw new HttpError(
      403,
      "cors_forbidden",
      "This origin is not permitted."
    );
  }
  return origin;
}

function withCors(response: Response, origin: string | undefined): Response {
  if (origin === undefined) {
    return response;
  }
  const headers = new Headers(response.headers);
  headers.set("Access-Control-Allow-Origin", origin);
  headers.append("Vary", "Origin");
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers
  });
}

function parsePreflightHeaders(value: string | null): readonly string[] {
  if (value === null || value.trim() === "") {
    return [];
  }
  return value
    .split(",")
    .map((header) => header.trim().toLowerCase())
    .filter((header) => header !== "");
}

function preflightResponse(request: Request, origin: string): Response {
  const url = new URL(request.url);
  const method = expectedMethod(url.pathname);
  if (method === undefined) {
    throw new HttpError(404, "not_found", "The endpoint was not found.");
  }
  if (request.headers.get("Access-Control-Request-Method") !== method) {
    throw new HttpError(
      403,
      "cors_forbidden",
      "This cross-origin request is not permitted."
    );
  }
  const requestedHeaders = parsePreflightHeaders(
    request.headers.get("Access-Control-Request-Headers")
  );
  if (
    requestedHeaders.some(
      (header) => !ALLOWED_PREFLIGHT_HEADERS.has(header)
    )
  ) {
    throw new HttpError(
      403,
      "cors_forbidden",
      "This cross-origin request is not permitted."
    );
  }
  const headers = new Headers({
    "Access-Control-Allow-Headers":
      "Authorization, Content-Type, X-Firebase-AppCheck, X-Client-Request-ID",
    "Access-Control-Allow-Methods": method,
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Max-Age": "600",
    "Cache-Control": "no-store",
    Vary: "Origin"
  });
  return new Response(null, { status: 204, headers });
}

function errorResponse(
  error: HttpError,
  requestId: string
): Response {
  return jsonResponse(
    {
      error: {
        code: error.code,
        message: error.publicMessage
      },
      requestId
    },
    error.status,
    {
      ...Object.fromEntries(new Headers(error.headers)),
      "X-Request-ID": requestId
    }
  );
}

function quotaHeaders(quota: QuotaResult): HeadersInit {
  return {
    "X-RateLimit-Limit": String(quota.limit),
    "X-RateLimit-Remaining": String(quota.remaining),
    "X-RateLimit-Reset": String(Math.floor(quota.resetAtMs / 1_000))
  };
}

function toHttpError(error: unknown): HttpError {
  if (error instanceof HttpError) {
    return error;
  }
  if (error instanceof ProviderFailure) {
    return providerFailureToHttp(error);
  }
  return new HttpError(
    500,
    "internal_error",
    "The request could not be completed."
  );
}

export async function handleRequest(
  request: Request,
  config: AppConfig,
  dependencies: AppDependencies
): Promise<Response> {
  const startedAt = dependencies.now();
  const clientRequestId = request.headers
    .get("X-Client-Request-ID")
    ?.trim();
  const requestId =
    clientRequestId !== undefined &&
    CLIENT_REQUEST_ID.test(clientRequestId)
      ? clientRequestId
      : dependencies.randomUuid();
  const url = new URL(request.url);
  let origin: string | undefined;
  let uidHash: string | undefined;

  try {
    origin = validateOrigin(request, config.allowedOrigins);
    const method = expectedMethod(url.pathname);
    if (method === undefined) {
      throw new HttpError(404, "not_found", "The endpoint was not found.");
    }

    if (request.method === "OPTIONS") {
      if (origin === undefined) {
        throw new HttpError(
          403,
          "cors_forbidden",
          "A permitted origin is required."
        );
      }
      return preflightResponse(request, origin);
    }
    if (request.method !== method) {
      throw new HttpError(
        405,
        "method_not_allowed",
        "The HTTP method is not allowed.",
        { Allow: method }
      );
    }

    if (url.pathname === "/v1/health") {
      const response = jsonResponse(
        {
          data: {
            status: "ok",
            service: "mento-ai-proxy",
            timestamp: new Date(dependencies.now()).toISOString()
          },
          requestId
        },
        200,
        { "X-Request-ID": requestId }
      );
      dependencies.logger.info("request_complete", {
        requestId,
        path: url.pathname,
        status: 200,
        durationMs: dependencies.now() - startedAt
      });
      return withCors(response, origin);
    }

    let verified: VerifiedIdToken;
    try {
      const authToken = bearerToken(
        request.headers.get("Authorization")
      );
      verified = await dependencies.verifyIdToken(authToken);

      if (config.appCheckEnforced !== false) {
        const appCheckToken = appCheckHeaderToken(
          request.headers.get("X-Firebase-AppCheck")
        );
        await dependencies.verifyAppCheck(appCheckToken);
      }
    } catch {
      throw new HttpError(
        401,
        "unauthenticated",
        "Valid authentication and app attestation are required.",
        { "WWW-Authenticate": "Bearer" }
      );
    }

    uidHash = await dependencies.hashUid(verified.uid);
    const definition = definitionForPath(url.pathname);
    if (definition === undefined) {
      throw new HttpError(404, "not_found", "The endpoint was not found.");
    }
    const untrustedInput = await readRequestJson(
      request,
      config.maxRequestBytes
    );
    const parsedInput = definition.inputSchema.safeParse(untrustedInput);
    if (!parsedInput.success) {
      throw new HttpError(
        400,
        "bad_request",
        "The request does not match the required schema."
      );
    }
    if (containsSensitiveCredential(parsedInput.data)) {
      throw new HttpError(
        400,
        "sensitive_content",
        "Credentials and authentication tokens cannot be sent to AI services."
      );
    }

    const nowMs = dependencies.now();
    const day = new Date(nowMs).toISOString().slice(0, 10);
    const quota = await dependencies.consumeQuota(
      verified.uid,
      day,
      config.dailyUserQuota,
      nowMs
    );
    if (!quota.allowed) {
      const retryAfterSeconds = Math.max(
        1,
        Math.ceil((quota.resetAtMs - nowMs) / 1_000)
      );
      throw new HttpError(
        429,
        "quota_exceeded",
        "The daily AI request limit has been reached.",
        {
          ...quotaHeaders(quota),
          "Retry-After": String(retryAfterSeconds)
        }
      );
    }

    // Cloudflare may abort the inbound Request signal after its body has been
    // consumed even while the Worker is still producing a response. Provider
    // calls have their own strict timeout, so use an independent signal here
    // to avoid cancelling every outbound fetch prematurely.
    const providerResult = await dependencies.generate(
      definition,
      parsedInput.data,
      new AbortController().signal
    );
    const validatedOutput = definition.outputSchema.safeParse(
      providerResult.data
    );
    if (!validatedOutput.success) {
      throw new ProviderFailure(
        "invalid_response",
        providerResult.provider
      );
    }

    const response = jsonResponse(
      {
        data: validatedOutput.data,
        meta: {
          requestId,
          provider: providerResult.provider,
          model: providerResult.model,
          quota: {
            limit: quota.limit,
            remaining: quota.remaining,
            resetAt: new Date(quota.resetAtMs).toISOString()
          }
        }
      },
      200,
      {
        ...quotaHeaders(quota),
        "X-Request-ID": requestId
      }
    );
    dependencies.logger.info("request_complete", {
      requestId,
      uidHash,
      path: url.pathname,
      provider: providerResult.provider,
      status: 200,
      durationMs: dependencies.now() - startedAt
    });
    return withCors(response, origin);
  } catch (error) {
    const httpError = toHttpError(error);
    dependencies.logger.error("request_failed", error, {
      requestId,
      uidHash,
      path: url.pathname,
      status: httpError.status,
      durationMs: dependencies.now() - startedAt
    });
    return withCors(errorResponse(httpError, requestId), origin);
  }
}

export function isAuthenticationFailure(error: unknown): boolean {
  return error instanceof AuthVerificationError;
}

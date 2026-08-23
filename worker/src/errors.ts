export type PublicErrorCode =
  | "bad_request"
  | "content_too_large"
  | "cors_forbidden"
  | "internal_error"
  | "invalid_provider_response"
  | "method_not_allowed"
  | "not_found"
  | "provider_rejected"
  | "provider_rate_limited"
  | "provider_network_error"
  | "provider_upstream_error"
  | "provider_timeout"
  | "provider_unavailable"
  | "quota_exceeded"
  | "sensitive_content"
  | "unauthenticated"
  | "unsupported_media_type";

export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: PublicErrorCode,
    readonly publicMessage: string,
    readonly headers: HeadersInit = {}
  ) {
    super(code);
    this.name = "HttpError";
  }
}

export type ProviderFailureKind =
  | "invalid_response"
  | "network"
  | "rate_limited"
  | "rejected"
  | "server_error"
  | "timeout"
  | "unavailable";

export class ProviderFailure extends Error {
  constructor(
    readonly kind: ProviderFailureKind,
    readonly provider: "gemini" | "openrouter" | "local",
    readonly upstreamStatus?: number
  ) {
    super(kind);
    this.name = "ProviderFailure";
  }
}

export function providerFailureToHttp(error: ProviderFailure): HttpError {
  if (error.kind === "timeout") {
    return new HttpError(
      504,
      "provider_timeout",
      "The AI service did not respond in time."
    );
  }
  if (error.kind === "invalid_response") {
    return new HttpError(
      502,
      "invalid_provider_response",
      "The AI service returned an unusable response."
    );
  }
  if (error.kind === "rejected") {
    return new HttpError(
      502,
      "provider_rejected",
      "The configured AI provider rejected the request."
    );
  }
  if (error.kind === "rate_limited") {
    return new HttpError(
      503,
      "provider_rate_limited",
      "The AI providers are currently rate limited."
    );
  }
  if (error.kind === "network") {
    return new HttpError(
      503,
      "provider_network_error",
      "The AI providers could not be reached."
    );
  }
  if (error.kind === "server_error") {
    return new HttpError(
      503,
      "provider_upstream_error",
      "The AI providers returned a server error."
    );
  }
  return new HttpError(
    503,
    "provider_unavailable",
    "The AI service is temporarily unavailable."
  );
}

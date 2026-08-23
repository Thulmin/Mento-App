import { HttpError } from "./errors";

const JSON_CONTENT_TYPE = "application/json";
const MAX_PROVIDER_RESPONSE_BYTES = 131_072;

export function isJsonContentType(value: string | null): boolean {
  if (value === null) {
    return false;
  }
  return value.split(";", 1)[0]?.trim().toLowerCase() === JSON_CONTENT_TYPE;
}

export async function readBodyLimited(
  body: ReadableStream<Uint8Array> | null,
  maxBytes: number
): Promise<string> {
  if (body === null) {
    return "";
  }

  const reader = body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;

  try {
    while (true) {
      const result = await reader.read();
      if (result.done) {
        break;
      }
      total += result.value.byteLength;
      if (total > maxBytes) {
        await reader.cancel();
        throw new HttpError(
          413,
          "content_too_large",
          "The request body is too large."
        );
      }
      chunks.push(result.value);
    }
  } finally {
    reader.releaseLock();
  }

  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
}

export async function readRequestJson(
  request: Request,
  maxBytes: number
): Promise<unknown> {
  if (!isJsonContentType(request.headers.get("Content-Type"))) {
    throw new HttpError(
      415,
      "unsupported_media_type",
      "Content-Type must be application/json."
    );
  }
  const contentEncoding = request.headers.get("Content-Encoding");
  if (
    contentEncoding !== null &&
    contentEncoding.trim() !== "" &&
    contentEncoding.toLowerCase() !== "identity"
  ) {
    throw new HttpError(
      415,
      "unsupported_media_type",
      "Compressed request bodies are not accepted."
    );
  }
  const declaredLength = Number(request.headers.get("Content-Length"));
  if (Number.isFinite(declaredLength) && declaredLength > maxBytes) {
    throw new HttpError(
      413,
      "content_too_large",
      "The request body is too large."
    );
  }

  let text: string;
  try {
    text = await readBodyLimited(request.body, maxBytes);
  } catch (error) {
    if (error instanceof HttpError) {
      throw error;
    }
    throw new HttpError(400, "bad_request", "The JSON request is invalid.");
  }
  if (text.trim() === "") {
    throw new HttpError(400, "bad_request", "The JSON request is invalid.");
  }
  try {
    return JSON.parse(text) as unknown;
  } catch {
    throw new HttpError(400, "bad_request", "The JSON request is invalid.");
  }
}

export async function readProviderJson(response: Response): Promise<unknown> {
  const declaredLength = Number(response.headers.get("Content-Length"));
  if (
    Number.isFinite(declaredLength) &&
    declaredLength > MAX_PROVIDER_RESPONSE_BYTES
  ) {
    throw new Error("provider_response_too_large");
  }
  const text = await readBodyLimited(
    response.body,
    MAX_PROVIDER_RESPONSE_BYTES
  );
  return JSON.parse(text) as unknown;
}

export function securityHeaders(): Headers {
  return new Headers({
    "Cache-Control": "no-store",
    "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'",
    "Content-Type": "application/json; charset=utf-8",
    "Referrer-Policy": "no-referrer",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY"
  });
}

export function jsonResponse(
  body: unknown,
  status = 200,
  extraHeaders: HeadersInit = {}
): Response {
  const headers = securityHeaders();
  new Headers(extraHeaders).forEach((value, key) => {
    headers.set(key, value);
  });
  return new Response(JSON.stringify(body), { status, headers });
}

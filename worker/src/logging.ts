import { HttpError, ProviderFailure } from "./errors";
import { redactText } from "./sensitive";

type LogValue = boolean | number | string | null | undefined;
type LogMetadata = Readonly<Record<string, LogValue>>;

export interface StructuredLogger {
  info(event: string, metadata?: LogMetadata): void;
  error(event: string, error: unknown, metadata?: LogMetadata): void;
}

function errorCode(error: unknown): string {
  if (error instanceof HttpError) {
    return error.code;
  }
  if (error instanceof ProviderFailure) {
    return "provider_" + error.kind;
  }
  if (error instanceof Error) {
    return error.name.slice(0, 80);
  }
  return "unknown_error";
}

export function createLogger(
  environment: "development" | "production" | "staging" | "test",
  knownSecrets: readonly string[]
): StructuredLogger {
  const write = (
    level: "error" | "info",
    event: string,
    metadata: LogMetadata,
    error?: unknown
  ): void => {
    const payload: Record<string, LogValue> = {
      level,
      event: event.slice(0, 80),
      ...metadata
    };
    if (error !== undefined) {
      payload.errorCode = errorCode(error);
      if (environment === "development" && error instanceof Error) {
        payload.errorMessage = redactText(error.message, knownSecrets);
      }
    }
    const line = JSON.stringify(payload);
    if (level === "error") {
      console.error(line);
    } else {
      console.info(line);
    }
  };

  return {
    info: (event, metadata = {}) => {
      write("info", event, metadata);
    },
    error: (event, error, metadata = {}) => {
      write("error", event, metadata, error);
    }
  };
}

export async function hashIdentifier(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest).slice(0, 8))
    .map((part) => part.toString(16).padStart(2, "0"))
    .join("");
}

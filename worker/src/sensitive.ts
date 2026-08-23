const secretPatterns = [
  /Bearer\s+[A-Za-z0-9._~+/=-]+/giu,
  /\bAIza[0-9A-Za-z_-]{20,}\b/gu,
  /\bsk-or-v1-[0-9A-Za-z_-]{12,}\b/gu,
  /\beyJ[0-9A-Za-z_-]{10,}\.[0-9A-Za-z_-]{10,}\.[0-9A-Za-z_-]{10,}\b/gu,
  /-----BEGIN [A-Z ]*(?:PRIVATE KEY|CERTIFICATE)-----/gu,
  /\b(?:password|access_token|refresh_token|api_key)\s*[:=]\s*\S+/giu
] as const;

export function containsSensitiveCredential(value: unknown): boolean {
  if (typeof value === "string") {
    return secretPatterns.some((pattern) => {
      pattern.lastIndex = 0;
      return pattern.test(value);
    });
  }
  if (Array.isArray(value)) {
    return value.some((item) => containsSensitiveCredential(item));
  }
  if (typeof value === "object" && value !== null) {
    const record = value as Record<string, unknown>;
    return Object.keys(record).some((key) =>
      containsSensitiveCredential(record[key])
    );
  }
  return false;
}

export function redactText(
  input: string,
  knownSecrets: readonly string[] = []
): string {
  let output = input;
  for (const secret of knownSecrets) {
    if (secret.length >= 4) {
      output = output.split(secret).join("[REDACTED]");
    }
  }
  for (const pattern of secretPatterns) {
    pattern.lastIndex = 0;
    output = output.replace(pattern, "[REDACTED]");
  }
  return output.slice(0, 500);
}

import { describe, expect, it, vi } from "vitest";
import { createLogger } from "../src/logging";
import {
  containsSensitiveCredential,
  redactText
} from "../src/sensitive";

describe("secret protection", () => {
  it("detects provider keys and bearer tokens in nested input", () => {
    expect(
      containsSensitiveCredential({
        message: ["safe", "Bearer secret-token-value"]
      })
    ).toBe(true);
  });

  it("redacts known and patterned secrets", () => {
    const known = "provider-secret-value";
    const output = redactText(
      "failed " +
        known +
        " with Bearer token-value and sk-or-v1-abcdefghijklmnop",
      [known]
    );

    expect(output).not.toContain(known);
    expect(output).not.toContain("token-value");
    expect(output).not.toContain("sk-or-v1");
  });

  it("never logs error messages in production", () => {
    const errorSpy = vi
      .spyOn(console, "error")
      .mockImplementation(() => undefined);
    const logger = createLogger("production", ["provider-secret-value"]);

    logger.error(
      "provider_failed",
      new Error("provider-secret-value"),
      { requestId: "safe-request-id" }
    );

    const line = String(errorSpy.mock.calls[0]?.[0]);
    expect(line).toContain("provider_failed");
    expect(line).not.toContain("provider-secret-value");
    errorSpy.mockRestore();
  });
});

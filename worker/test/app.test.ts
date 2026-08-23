import { describe, expect, it, vi } from "vitest";
import { handleRequest } from "../src/app";
import { ProviderFailure } from "../src/errors";
import {
  appConfig,
  authHeaders,
  makeDependencies,
  taskBreakdownRequest,
  validTaskBreakdownInput,
  validTaskBreakdownOutput
} from "./helpers";

describe("AI proxy request handling", () => {
  it("serves the unauthenticated health endpoint without provider details", async () => {
    const response = await handleRequest(
      new Request("https://worker.example.test/v1/health"),
      appConfig,
      makeDependencies()
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      data: { status: "ok", service: "mento-ai-proxy" }
    });
    expect(response.headers.get("Cache-Control")).toBe("no-store");
  });

  it("rejects missing authentication", async () => {
    const generate = vi.fn();
    const response = await handleRequest(
      taskBreakdownRequest(validTaskBreakdownInput, {
        "Content-Type": "application/json"
      }),
      appConfig,
      makeDependencies({ generate })
    );

    expect(response.status).toBe(401);
    expect(generate).not.toHaveBeenCalled();
    expect(await response.json()).toMatchObject({
      error: { code: "unauthenticated" }
    });
  });

  it("rejects an invalid Firebase ID token", async () => {
    const response = await handleRequest(
      taskBreakdownRequest(),
      appConfig,
      makeDependencies({
        verifyIdToken: async () => {
          throw new Error("invalid");
        }
      })
    );

    expect(response.status).toBe(401);
    expect(await response.json()).toMatchObject({
      error: { code: "unauthenticated" }
    });
  });

  it("rejects missing App Check", async () => {
    const headers = authHeaders();
    headers.delete("X-Firebase-AppCheck");
    const response = await handleRequest(
      taskBreakdownRequest(validTaskBreakdownInput, headers),
      appConfig,
      makeDependencies()
    );

    expect(response.status).toBe(401);
  });

  it("rejects an invalid App Check token", async () => {
    const response = await handleRequest(
      taskBreakdownRequest(),
      appConfig,
      makeDependencies({
        verifyAppCheck: async () => {
          throw new Error("invalid");
        }
      })
    );

    expect(response.status).toBe(401);
  });

  it("derives quota identity only from the verified token", async () => {
    const consumeQuota = vi.fn(
      async (_uid: string, _day: string, limit: number, nowMs: number) => ({
        allowed: true,
        limit,
        remaining: 2,
        resetAtMs: nowMs + 60_000
      })
    );
    const request = new Request(
      "https://worker.example.test/v1/ai/task-breakdown?uid=attacker",
      {
        method: "POST",
        headers: authHeaders(),
        body: JSON.stringify(validTaskBreakdownInput)
      }
    );

    const response = await handleRequest(
      request,
      appConfig,
      makeDependencies({ consumeQuota })
    );

    expect(response.status).toBe(200);
    expect(consumeQuota).toHaveBeenCalledWith(
      "verified-user-123",
      "2026-07-11",
      3,
      Date.parse("2026-07-11T12:00:00.000Z")
    );
  });

  it("rejects unknown or invalid schema fields before consuming quota", async () => {
    const consumeQuota = vi.fn();
    const response = await handleRequest(
      taskBreakdownRequest({
        ...validTaskBreakdownInput,
        uid: "attacker"
      }),
      appConfig,
      makeDependencies({ consumeQuota })
    );

    expect(response.status).toBe(400);
    expect(consumeQuota).not.toHaveBeenCalled();
  });

  it("rejects credentials in otherwise valid content", async () => {
    const consumeQuota = vi.fn();
    const response = await handleRequest(
      taskBreakdownRequest({
        ...validTaskBreakdownInput,
        assignment: {
          ...validTaskBreakdownInput.assignment,
          description:
            "Bearer eyJaaaaaaaaaaaa.bbbbbbbbbbbb.cccccccccccc"
        }
      }),
      appConfig,
      makeDependencies({ consumeQuota })
    );

    expect(response.status).toBe(400);
    expect(await response.json()).toMatchObject({
      error: { code: "sensitive_content" }
    });
    expect(consumeQuota).not.toHaveBeenCalled();
  });

  it("enforces the atomic quota result before provider access", async () => {
    const generate = vi.fn();
    const response = await handleRequest(
      taskBreakdownRequest(),
      appConfig,
      makeDependencies({
        consumeQuota: async (_uid, _day, limit, nowMs) => ({
          allowed: false,
          limit,
          remaining: 0,
          resetAtMs: nowMs + 3_600_000
        }),
        generate
      })
    );

    expect(response.status).toBe(429);
    expect(response.headers.get("Retry-After")).toBe("3600");
    expect(generate).not.toHaveBeenCalled();
  });

  it("maps provider timeout to a generic gateway timeout", async () => {
    const response = await handleRequest(
      taskBreakdownRequest(),
      appConfig,
      makeDependencies({
        generate: async () => {
          throw new ProviderFailure("timeout", "gemini");
        }
      })
    );

    expect(response.status).toBe(504);
    expect(await response.json()).toMatchObject({
      error: { code: "provider_timeout" }
    });
  });

  it("reports rejected provider configuration without exposing details", async () => {
    const response = await handleRequest(
      taskBreakdownRequest(),
      appConfig,
      makeDependencies({
        generate: async () => {
          throw new ProviderFailure("rejected", "gemini", 403);
        }
      })
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toMatchObject({
      error: { code: "provider_rejected" }
    });
  });

  it("validates provider output again at the application boundary", async () => {
    const response = await handleRequest(
      taskBreakdownRequest(),
      appConfig,
      makeDependencies({
        generate: async () => ({
          data: { prose: "not the endpoint schema" },
          provider: "gemini",
          model: "test-model"
        })
      })
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toMatchObject({
      error: { code: "invalid_provider_response" }
    });
  });

  it("returns validated structured output and rate metadata", async () => {
    const response = await handleRequest(
      taskBreakdownRequest(),
      appConfig,
      makeDependencies()
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      data: validTaskBreakdownOutput,
      meta: {
        provider: "gemini",
        model: "test-model",
        quota: { limit: 3, remaining: 2 }
      }
    });
    expect(response.headers.get("X-RateLimit-Remaining")).toBe("2");
  });

  it("rejects non-JSON media types and oversized requests", async () => {
    const wrongType = await handleRequest(
      taskBreakdownRequest(validTaskBreakdownInput, {
        Authorization: authHeaders().get("Authorization") ?? "",
        "Content-Type": "text/plain",
        "X-Firebase-AppCheck":
          authHeaders().get("X-Firebase-AppCheck") ?? ""
      }),
      appConfig,
      makeDependencies()
    );
    expect(wrongType.status).toBe(415);

    const oversized = await handleRequest(
      taskBreakdownRequest(validTaskBreakdownInput, {
        ...Object.fromEntries(authHeaders()),
        "Content-Length": "70000"
      }),
      appConfig,
      makeDependencies()
    );
    expect(oversized.status).toBe(413);
  });

  it("allows only configured CORS origins and preflight headers", async () => {
    const rejected = await handleRequest(
      taskBreakdownRequest(validTaskBreakdownInput, {
        ...Object.fromEntries(authHeaders()),
        Origin: "https://attacker.example"
      }),
      appConfig,
      makeDependencies()
    );
    expect(rejected.status).toBe(403);
    expect(rejected.headers.get("Access-Control-Allow-Origin")).toBeNull();

    const allowed = await handleRequest(
      new Request(
        "https://worker.example.test/v1/ai/task-breakdown",
        {
          method: "OPTIONS",
          headers: {
            Origin: "https://app.example.test",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers":
              "authorization,content-type,x-firebase-appcheck,x-client-request-id"
          }
        }
      ),
      appConfig,
      makeDependencies()
    );
    expect(allowed.status).toBe(204);
    expect(allowed.headers.get("Access-Control-Allow-Origin")).toBe(
      "https://app.example.test"
    );
    expect(allowed.headers.get("Access-Control-Allow-Headers")).toContain(
      "X-Client-Request-ID"
    );
  });

  it("echoes a valid client request ID for end-to-end tracing", async () => {
    const clientRequestId = "60cc7b1d-12c9-4ed9-a643-fdc406cfe949";
    const response = await handleRequest(
      taskBreakdownRequest(validTaskBreakdownInput, {
        ...Object.fromEntries(authHeaders()),
        "X-Client-Request-ID": clientRequestId
      }),
      appConfig,
      makeDependencies()
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("X-Request-ID")).toBe(clientRequestId);
  });
});

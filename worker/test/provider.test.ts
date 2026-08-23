import { describe, expect, it, vi } from "vitest";
import {
  callGemini,
  callOpenRouter,
  generateWithProviders
} from "../src/provider";
import { endpointDefinitions } from "../src/schemas";
import {
  validTaskBreakdownInput,
  validTaskBreakdownOutput
} from "./helpers";

const definition = endpointDefinitions["task-breakdown"];

function geminiResponse(output: unknown): Response {
  return Response.json({
    candidates: [
      {
        content: {
          parts: [{ text: JSON.stringify(output) }]
        },
        finishReason: "STOP"
      }
    ]
  });
}

function openRouterResponse(output: unknown, model?: string): Response {
  return Response.json({
    ...(model === undefined ? {} : { model }),
    choices: [
      {
        message: {
          content: JSON.stringify(output)
        }
      }
    ]
  });
}

describe("AI providers", () => {
  it("normalizes the compact provider chat envelope", async () => {
    const chatDefinition = endpointDefinitions.chat;
    const fetcher = vi.fn<typeof fetch>(async () =>
      geminiResponse({
        reply: "Hi! How can I help with your studies?",
        dataActionsJson: "[]"
      })
    );

    const result = await callGemini(
      chatDefinition,
      { message: "Hi" },
      {
        apiKey: "test-key",
        model: "gemini-3.5-flash-lite",
        timeoutMs: 1_000,
        fetcher,
        signal: new AbortController().signal
      }
    );

    expect(result.data).toEqual({
      reply: "Hi! How can I help with your studies?",
      suggestedActions: [],
      dataActions: []
    });
    const request = JSON.parse(
      String(fetcher.mock.calls[0]?.[1]?.body)
    ) as {
      generationConfig?: { responseJsonSchema?: unknown };
    };
    const serializedSchema = JSON.stringify(
      request.generationConfig?.responseJsonSchema
    );
    expect(serializedSchema).toContain("dataActionsJson");
    expect(serializedSchema.length).toBeLessThan(5_000);
  });

  it("aborts Gemini when the configured timeout elapses", async () => {
    const fetcher: typeof fetch = async (_input, init) =>
      await new Promise<Response>((_resolve, reject) => {
        init?.signal?.addEventListener(
          "abort",
          () => {
            reject(new DOMException("aborted", "AbortError"));
          },
          { once: true }
        );
      });

    await expect(
      callGemini(definition, validTaskBreakdownInput, {
        apiKey: "test-key",
        model: "test-model",
        timeoutMs: 5,
        fetcher,
        signal: new AbortController().signal
      })
    ).rejects.toMatchObject({
      kind: "timeout",
      provider: "gemini"
    });
  });

  it("rejects malformed provider JSON", async () => {
    const fetcher: typeof fetch = async () =>
      Response.json({
        candidates: [
          { content: { parts: [{ text: "not-json" }] } }
        ]
      });

    await expect(
      callGemini(definition, validTaskBreakdownInput, {
        apiKey: "test-key",
        model: "test-model",
        timeoutMs: 1_000,
        fetcher,
        signal: new AbortController().signal
      })
    ).rejects.toMatchObject({
      kind: "invalid_response"
    });
  });

  it("uses OpenRouter once when Gemini is unavailable", async () => {
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const url = String(input);
      return url.includes("generativelanguage")
        ? new Response(null, { status: 503 })
        : openRouterResponse(validTaskBreakdownOutput);
    });

    const result = await generateWithProviders(
      definition,
      validTaskBreakdownInput,
      new AbortController().signal,
      {
        timeoutMs: 1_000,
        fetcher,
        gemini: { apiKey: "gemini-key", model: "gemini-model" },
        openRouter: {
          apiKey: "openrouter-key",
          model: "openrouter/free"
        }
      }
    );

    expect(result).toMatchObject({
      provider: "openrouter",
      model: "openrouter/free",
      data: validTaskBreakdownOutput
    });
    expect(fetcher).toHaveBeenCalledTimes(2);
  });

  it("tries a distinct Gemini fallback model before OpenRouter", async () => {
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const url = String(input);
      return url.includes("gemini-primary")
        ? new Response(null, { status: 429 })
        : geminiResponse(validTaskBreakdownOutput);
    });
    const onAttemptFailure = vi.fn();

    const result = await generateWithProviders(
      definition,
      validTaskBreakdownInput,
      new AbortController().signal,
      {
        timeoutMs: 1_000,
        fetcher,
        gemini: {
          apiKey: "gemini-key",
          model: "gemini-primary",
          fallbackModels: ["gemini-primary", "gemini-fallback"]
        },
        openRouter: {
          apiKey: "openrouter-key",
          model: "openrouter/free"
        },
        onAttemptFailure
      }
    );

    expect(result).toMatchObject({
      provider: "gemini",
      model: "gemini-fallback"
    });
    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(onAttemptFailure).toHaveBeenCalledWith(
      expect.objectContaining({
        kind: "rate_limited",
        provider: "gemini"
      }),
      "gemini-primary"
    );
  });

  it("requests low-thinking structured Gemini output", async () => {
    const fetcher = vi.fn<typeof fetch>(async () =>
      geminiResponse(validTaskBreakdownOutput)
    );

    await callGemini(definition, validTaskBreakdownInput, {
      apiKey: "test-key",
      model: "test-model",
      timeoutMs: 1_000,
      fetcher,
      signal: new AbortController().signal
    });

    const init = fetcher.mock.calls[0]?.[1];
    expect(init?.headers).toMatchObject({
      "x-goog-api-key": "test-key"
    });
    const body = JSON.parse(String(init?.body)) as {
      generationConfig?: {
        candidateCount?: number;
        temperature?: number;
        thinkingConfig?: { thinkingLevel?: string };
        responseMimeType?: string;
        responseJsonSchema?: unknown;
      };
    };
    expect(body.generationConfig).toMatchObject({
      thinkingConfig: { thinkingLevel: "LOW" },
      responseMimeType: "application/json"
    });
    expect(body.generationConfig?.temperature).toBeUndefined();
    expect(body.generationConfig?.candidateCount).toBeUndefined();
    expect(body.generationConfig?.responseJsonSchema).toBeDefined();
  });

  it("requires a structured-output OpenRouter route and records its model", async () => {
    const fetcher = vi.fn<typeof fetch>(async () =>
      openRouterResponse(
        validTaskBreakdownOutput,
        "nvidia/nemotron-3-super:free"
      )
    );

    const result = await callOpenRouter(
      definition,
      validTaskBreakdownInput,
      {
        apiKey: "test-key",
        model: "openrouter/free",
        timeoutMs: 1_000,
        fetcher,
        signal: new AbortController().signal
      }
    );

    const body = JSON.parse(
      String(fetcher.mock.calls[0]?.[1]?.body)
    ) as {
      provider?: { allow_fallbacks?: boolean; require_parameters?: boolean };
      reasoning?: { effort?: string; exclude?: boolean };
      response_format?: { type?: string };
      temperature?: number;
    };
    expect(body).toMatchObject({
      provider: { allow_fallbacks: true, require_parameters: true },
      reasoning: { effort: "minimal", exclude: true },
      response_format: { type: "json_schema" }
    });
    expect(body.temperature).toBeUndefined();
    expect(result.model).toBe("nvidia/nemotron-3-super:free");
  });
});

import { z } from "zod";
import { ProviderFailure } from "./errors";
import { readProviderJson } from "./http";
import {
  toProviderJsonSchema
} from "./schemas";
import type { EndpointDefinition } from "./schemas";

const GEMINI_ENDPOINT_PREFIX =
  "https://generativelanguage.googleapis.com/v1beta/models/";
const OPENROUTER_ENDPOINT =
  "https://openrouter.ai/api/v1/chat/completions";

export interface ProviderConfig {
  readonly timeoutMs: number;
  readonly fetcher: typeof fetch;
  readonly gemini?: {
    readonly apiKey: string;
    readonly model: string;
    readonly fallbackModels?: readonly string[];
  };
  readonly openRouter?: {
    readonly apiKey: string;
    readonly model: string;
  };
  readonly onAttemptFailure?: (
    failure: ProviderFailure,
    model: string
  ) => void;
}

export interface ProviderResult {
  readonly data: unknown;
  readonly provider: "gemini" | "openrouter" | "local";
  readonly model: string;
}

interface TimedFetchOptions {
  readonly fetcher: typeof fetch;
  readonly input: string;
  readonly init: RequestInit;
  readonly timeoutMs: number;
  readonly callerSignal: AbortSignal;
  readonly provider: "gemini" | "openrouter";
}

async function timedFetch(options: TimedFetchOptions): Promise<Response> {
  const controller = new AbortController();
  let didTimeout = false;
  const cancelFromCaller = (): void => {
    controller.abort(options.callerSignal.reason);
  };
  if (options.callerSignal.aborted) {
    cancelFromCaller();
  } else {
    options.callerSignal.addEventListener("abort", cancelFromCaller, {
      once: true
    });
  }
  const timeout = setTimeout(() => {
    didTimeout = true;
    controller.abort();
  }, options.timeoutMs);

  try {
    // Detach the function from the options object. Cloudflare's global fetch
    // must be invoked as a function, not with `options` as its receiver.
    const fetcher = options.fetcher;
    return await fetcher(options.input, {
      ...options.init,
      signal: controller.signal
    });
  } catch {
    throw new ProviderFailure(
      didTimeout ? "timeout" : "network",
      options.provider
    );
  } finally {
    clearTimeout(timeout);
    options.callerSignal.removeEventListener("abort", cancelFromCaller);
  }
}

function failureForStatus(
  status: number,
  provider: "gemini" | "openrouter"
): ProviderFailure {
  if (status === 408 || status === 504) {
    return new ProviderFailure("timeout", provider);
  }
  if (status === 429) {
    return new ProviderFailure("rate_limited", provider, status);
  }
  if (status >= 500) {
    return new ProviderFailure("server_error", provider, status);
  }
  return new ProviderFailure("rejected", provider, status);
}

function parseStructuredOutput(
  text: string,
  definition: EndpointDefinition,
  provider: "gemini" | "openrouter"
): unknown {
  try {
    const parsed = JSON.parse(text) as unknown;
    const providerOutput = (
      definition.providerOutputSchema ?? definition.outputSchema
    ).parse(parsed);
    return definition.normalizeProviderOutput?.(providerOutput) ?? providerOutput;
  } catch {
    throw new ProviderFailure("invalid_response", provider);
  }
}

const geminiEnvelopeSchema = z.object({
  candidates: z
    .array(
      z.object({
        content: z.object({
          parts: z
            .array(z.object({ text: z.string().max(131_072) }))
            .min(1)
            .max(32)
        }),
        finishReason: z.string().optional()
      })
    )
    .max(4)
    .optional(),
  promptFeedback: z
    .object({
      blockReason: z.string().optional()
    })
    .optional()
});

export async function callGemini(
  definition: EndpointDefinition,
  input: unknown,
  options: {
    readonly apiKey: string;
    readonly model: string;
    readonly timeoutMs: number;
    readonly fetcher: typeof fetch;
    readonly signal: AbortSignal;
  }
): Promise<ProviderResult> {
  const response = await timedFetch({
    fetcher: options.fetcher,
    input:
      GEMINI_ENDPOINT_PREFIX +
      encodeURIComponent(options.model) +
      ":generateContent",
    init: {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        "x-goog-api-key": options.apiKey
      },
      body: JSON.stringify({
        systemInstruction: {
          parts: [{ text: definition.instruction }]
        },
        contents: [
          {
            role: "user",
            parts: [{ text: JSON.stringify(input) }]
          }
        ],
        generationConfig: {
          thinkingConfig: {
            thinkingLevel: definition.thinkingLevel
          },
          maxOutputTokens: definition.maxOutputTokens,
          responseMimeType: "application/json",
          responseJsonSchema: toProviderJsonSchema(
            definition.providerOutputSchema ?? definition.outputSchema
          )
        }
      })
    },
    timeoutMs: options.timeoutMs,
    callerSignal: options.signal,
    provider: "gemini"
  });

  if (!response.ok) {
    await response.body?.cancel();
    throw failureForStatus(response.status, "gemini");
  }

  let envelope: z.infer<typeof geminiEnvelopeSchema>;
  try {
    envelope = geminiEnvelopeSchema.parse(await readProviderJson(response));
  } catch {
    throw new ProviderFailure("invalid_response", "gemini");
  }
  if (envelope.promptFeedback?.blockReason !== undefined) {
    throw new ProviderFailure("rejected", "gemini");
  }
  const candidate = envelope.candidates?.[0];
  if (candidate === undefined) {
    throw new ProviderFailure("invalid_response", "gemini");
  }
  const text = candidate.content.parts.map((part) => part.text).join("");
  return {
    data: parseStructuredOutput(text, definition, "gemini"),
    provider: "gemini",
    model: options.model
  };
}

const openRouterEnvelopeSchema = z.object({
  model: z.string().min(1).max(128).optional(),
  choices: z
    .array(
      z.object({
        message: z.object({
          content: z.string().max(131_072)
        })
      })
    )
    .min(1)
    .max(10)
});

export async function callOpenRouter(
  definition: EndpointDefinition,
  input: unknown,
  options: {
    readonly apiKey: string;
    readonly model: string;
    readonly timeoutMs: number;
    readonly fetcher: typeof fetch;
    readonly signal: AbortSignal;
  }
): Promise<ProviderResult> {
  const response = await timedFetch({
    fetcher: options.fetcher,
    input: OPENROUTER_ENDPOINT,
    init: {
      method: "POST",
      headers: {
        Accept: "application/json",
        Authorization: "Bearer " + options.apiKey,
        "Content-Type": "application/json",
        "X-Title": "Mento"
      },
      body: JSON.stringify({
        model: options.model,
        max_completion_tokens: definition.maxOutputTokens,
        stream: false,
        reasoning: {
          effort: "minimal",
          exclude: true
        },
        provider: {
          allow_fallbacks: true,
          require_parameters: true
        },
        messages: [
          { role: "system", content: definition.instruction },
          { role: "user", content: JSON.stringify(input) }
        ],
        response_format: {
          type: "json_schema",
          json_schema: {
            name: "mento_" + definition.name.replace("-", "_"),
            strict: true,
            schema: toProviderJsonSchema(
              definition.providerOutputSchema ?? definition.outputSchema
            )
          }
        }
      })
    },
    timeoutMs: options.timeoutMs,
    callerSignal: options.signal,
    provider: "openrouter"
  });

  if (!response.ok) {
    await response.body?.cancel();
    throw failureForStatus(response.status, "openrouter");
  }

  let envelope: z.infer<typeof openRouterEnvelopeSchema>;
  try {
    envelope = openRouterEnvelopeSchema.parse(
      await readProviderJson(response)
    );
  } catch {
    throw new ProviderFailure("invalid_response", "openrouter");
  }
  const content = envelope.choices[0]?.message.content;
  if (content === undefined) {
    throw new ProviderFailure("invalid_response", "openrouter");
  }
  return {
    data: parseStructuredOutput(content, definition, "openrouter"),
    provider: "openrouter",
    model: envelope.model ?? options.model
  };
}

function uniqueModels(
  primary: string,
  fallbacks: readonly string[] | undefined
): readonly string[] {
  return [...new Set([primary, ...(fallbacks ?? [])])];
}

export async function generateWithProviders(
  definition: EndpointDefinition,
  input: unknown,
  signal: AbortSignal,
  config: ProviderConfig
): Promise<ProviderResult> {
  const failures: ProviderFailure[] = [];

  if (config.gemini !== undefined) {
    const { apiKey, model, fallbackModels } = config.gemini;
    for (const attemptedModel of uniqueModels(model, fallbackModels)) {
      try {
        return await callGemini(definition, input, {
          apiKey,
          model: attemptedModel,
          timeoutMs: config.timeoutMs,
          fetcher: config.fetcher,
          signal
        });
      } catch (error) {
        const failure =
          error instanceof ProviderFailure
            ? error
            : new ProviderFailure("unavailable", "gemini");
        failures.push(failure);
        config.onAttemptFailure?.(failure, attemptedModel);
      }
    }
  }

  if (config.openRouter !== undefined) {
    try {
      return await callOpenRouter(definition, input, {
        ...config.openRouter,
        timeoutMs: config.timeoutMs,
        fetcher: config.fetcher,
        signal
      });
    } catch (error) {
      const failure =
        error instanceof ProviderFailure
          ? error
          : new ProviderFailure("unavailable", "openrouter");
      failures.push(failure);
      config.onAttemptFailure?.(failure, config.openRouter.model);
    }
  }

  // Preserve the most actionable failure instead of allowing a generic
  // fallback outage to hide a rejected key, malformed response, or timeout.
  throw (
    failures.find((failure) => failure.kind === "rejected") ??
    failures.find((failure) => failure.kind === "rate_limited") ??
    failures.find((failure) => failure.kind === "network") ??
    failures.find((failure) => failure.kind === "server_error") ??
    failures.find((failure) => failure.kind === "invalid_response") ??
    failures.find((failure) => failure.kind === "timeout") ??
    failures.at(-1) ??
    new ProviderFailure("unavailable", "gemini")
  );
}

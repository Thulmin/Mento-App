import { z } from "zod";

export interface RuntimeConfig {
  readonly environment: "development" | "production" | "staging" | "test";
  readonly firebaseProjectId: string;
  readonly firebaseProjectNumber: string;
  readonly firebaseAppIds: ReadonlySet<string>;
  readonly allowedOrigins: ReadonlySet<string>;
  readonly dailyUserQuota: number;
  readonly maxRequestBytes: number;
  readonly providerTimeoutMs: number;
  readonly geminiModel: string;
  readonly geminiFallbackModels: readonly string[];
  readonly openRouterModel: string;
  readonly appCheckEnforced: boolean;
  readonly geminiApiKey?: string;
  readonly openRouterApiKey?: string;
}

const modelNameSchema = z
  .string()
  .min(1)
  .max(128)
  .regex(/^[A-Za-z0-9._:/-]+$/);

const rawConfigSchema = z.object({
  ENVIRONMENT: z
    .enum(["development", "production", "staging", "test"])
    .default("production"),
  FIREBASE_PROJECT_ID: z
    .string()
    .min(4)
    .max(64)
    .regex(/^[a-z][a-z0-9-]+$/),
  FIREBASE_PROJECT_NUMBER: z.string().regex(/^\d{6,20}$/),
  FIREBASE_APP_IDS: z.string().default(""),
  ALLOWED_ORIGINS: z.string().default(""),
  DAILY_USER_QUOTA: z.coerce.number().int().min(1).max(10_000),
  MAX_REQUEST_BYTES: z.coerce
    .number()
    .int()
    .min(1_024)
    .max(1_048_576),
  PROVIDER_TIMEOUT_MS: z.coerce.number().int().min(1_000).max(60_000),
  GEMINI_MODEL: modelNameSchema,
  GEMINI_FALLBACK_MODELS: z.string().max(512).default(""),
  OPENROUTER_MODEL: modelNameSchema,
  APP_CHECK_ENFORCED: z
    .string()
    .default("true")
    .transform((value) => value.toLowerCase() === "true" || value === "1"),
  GEMINI_API_KEY: z.string().min(1).optional(),
  OPENROUTER_API_KEY: z.string().min(1).optional()
});

function parseOrigins(
  value: string,
  environment: RuntimeConfig["environment"]
): ReadonlySet<string> {
  const origins = new Set<string>();
  for (const item of value.split(",")) {
    const candidate = item.trim();
    if (candidate === "") {
      continue;
    }
    const url = new URL(candidate);
    const isLocalDevelopment =
      environment !== "production" &&
      url.protocol === "http:" &&
      (url.hostname === "localhost" || url.hostname === "127.0.0.1");
    if (
      url.origin !== candidate ||
      (url.protocol !== "https:" && !isLocalDevelopment)
    ) {
      throw new Error("invalid_allowed_origin");
    }
    origins.add(url.origin);
  }
  return origins;
}

function splitSet(value: string): ReadonlySet<string> {
  return new Set(
    value
      .split(",")
      .map((item) => item.trim())
      .filter((item) => item !== "")
  );
}

function parseFallbackModels(
  value: string,
  primary: string
): readonly string[] {
  const models = [...splitSet(value)]
    .filter((model) => model !== primary)
    .map((model) => modelNameSchema.parse(model));
  if (models.length > 3) {
    throw new Error("too_many_fallback_models");
  }
  return models;
}

export function parseRuntimeConfig(env: Cloudflare.Env): RuntimeConfig {
  const parsed = rawConfigSchema.parse(env);
  const base = {
    environment: parsed.ENVIRONMENT,
    firebaseProjectId: parsed.FIREBASE_PROJECT_ID,
    firebaseProjectNumber: parsed.FIREBASE_PROJECT_NUMBER,
    firebaseAppIds: splitSet(parsed.FIREBASE_APP_IDS),
    allowedOrigins: parseOrigins(
      parsed.ALLOWED_ORIGINS,
      parsed.ENVIRONMENT
    ),
    dailyUserQuota: parsed.DAILY_USER_QUOTA,
    maxRequestBytes: parsed.MAX_REQUEST_BYTES,
    providerTimeoutMs: parsed.PROVIDER_TIMEOUT_MS,
    geminiModel: parsed.GEMINI_MODEL,
    geminiFallbackModels: parseFallbackModels(
      parsed.GEMINI_FALLBACK_MODELS,
      parsed.GEMINI_MODEL
    ),
    openRouterModel: parsed.OPENROUTER_MODEL,
    appCheckEnforced: parsed.APP_CHECK_ENFORCED
  };

  return {
    ...base,
    ...(parsed.GEMINI_API_KEY === undefined
      ? {}
      : { geminiApiKey: parsed.GEMINI_API_KEY }),
    ...(parsed.OPENROUTER_API_KEY === undefined
      ? {}
      : { openRouterApiKey: parsed.OPENROUTER_API_KEY })
  };
}

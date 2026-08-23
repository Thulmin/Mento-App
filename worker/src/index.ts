import {
  createAppCheckKeyResolver,
  createFirebaseAuthKeyResolver,
  verifyAppCheckToken,
  verifyFirebaseIdToken
} from "./auth";
import { handleRequest } from "./app";
import {
  createImmediateLocalChatResponse,
  createLocalChatFallback
} from "./chat-fallback";
import { parseRuntimeConfig } from "./config";
import { ProviderFailure } from "./errors";
import { jsonResponse } from "./http";
import {
  createLogger,
  hashIdentifier
} from "./logging";
import { generateWithProviders } from "./provider";
import type { ProviderConfig } from "./provider";
import { UserDailyQuota } from "./quota";

export { UserDailyQuota };

const firebaseAuthKeys = createFirebaseAuthKeyResolver(fetch);
const appCheckKeys = createAppCheckKeyResolver(fetch);

function configurationErrorResponse(requestId: string): Response {
  return jsonResponse(
    {
      error: {
        code: "internal_error",
        message: "The service is not configured correctly."
      },
      requestId
    },
    500,
    { "X-Request-ID": requestId }
  );
}

export default {
  async fetch(request: Request, env: Cloudflare.Env): Promise<Response> {
    const requestId = crypto.randomUUID();
    let config;
    try {
      config = parseRuntimeConfig(env);
    } catch {
      console.error(
        JSON.stringify({
          level: "error",
          event: "invalid_runtime_configuration",
          requestId
        })
      );
      return configurationErrorResponse(requestId);
    }

    const knownSecrets = [
      config.geminiApiKey,
      config.openRouterApiKey
    ].filter((value): value is string => value !== undefined);
    const logger = createLogger(config.environment, knownSecrets);
    const providerConfig: ProviderConfig = {
      timeoutMs: config.providerTimeoutMs,
      fetcher: fetch,
      ...(config.geminiApiKey === undefined
        ? {}
        : {
            gemini: {
              apiKey: config.geminiApiKey,
              model: config.geminiModel,
              fallbackModels: config.geminiFallbackModels
            }
          }),
      ...(config.openRouterApiKey === undefined
        ? {}
        : {
            openRouter: {
              apiKey: config.openRouterApiKey,
              model: config.openRouterModel
            }
          }),
      onAttemptFailure: (failure, model) => {
        logger.error("provider_attempt_failed", failure, {
          provider: failure.provider,
          model,
          failureKind: failure.kind,
          upstreamStatus: failure.upstreamStatus
        });
      }
    };

    return await handleRequest(
      request,
      {
        allowedOrigins: config.allowedOrigins,
        dailyUserQuota: config.dailyUserQuota,
        maxRequestBytes: config.maxRequestBytes,
        appCheckEnforced: config.appCheckEnforced
      },
      {
        verifyIdToken: async (token) =>
          await verifyFirebaseIdToken(token, {
            projectId: config.firebaseProjectId,
            keyResolver: firebaseAuthKeys,
            nowMs: Date.now()
          }),
        verifyAppCheck: async (token) =>
          await verifyAppCheckToken(token, {
            projectNumber: config.firebaseProjectNumber,
            allowedAppIds: config.firebaseAppIds,
            keyResolver: appCheckKeys,
            nowMs: Date.now()
          }),
        consumeQuota: async (uid, day, limit, nowMs) => {
          const stub = env.USER_DAILY_QUOTA.getByName(uid);
          return await stub.checkAndConsume(day, limit, nowMs);
        },
        generate: async (definition, input, signal) => {
          if (definition.name === "chat") {
            const immediate = createImmediateLocalChatResponse(input);
            if (immediate !== undefined) {
              logger.info("chat_using_local_fast_path");
              return {
                data: immediate,
                provider: "local" as const,
                model: "built-in-study-fast-path-v1"
              };
            }
          }
          try {
            return await generateWithProviders(
              definition,
              input,
              signal,
              providerConfig
            );
          } catch (error) {
            if (
              definition.name !== "chat" ||
              !(error instanceof ProviderFailure)
            ) {
              throw error;
            }
            logger.error("chat_using_local_fallback", error, {
              provider: error.provider,
              failureKind: error.kind,
              upstreamStatus: error.upstreamStatus
            });
            return {
              data: createLocalChatFallback(input),
              provider: "local" as const,
              model: "built-in-study-fallback-v1"
            };
          }
        },
        hashUid: hashIdentifier,
        logger,
        now: Date.now,
        randomUuid: () => crypto.randomUUID()
      }
    );
  }
} satisfies ExportedHandler<Cloudflare.Env>;

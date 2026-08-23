import type { AppConfig, AppDependencies } from "../src/app";
import type { StructuredLogger } from "../src/logging";

export const dummyToken =
  "aaaaaaaaaaaaaaaa.bbbbbbbbbbbbbbbb.cccccccccccccccc";

export const appConfig: AppConfig = {
  allowedOrigins: new Set(["https://app.example.test"]),
  dailyUserQuota: 3,
  maxRequestBytes: 65_536
};

export const validTaskBreakdownInput = {
  assignment: {
    id: "assignment-1",
    title: "Research report",
    description: "Prepare a structured university research report.",
    dueAt: "2026-07-20T12:00:00.000Z",
    estimatedMinutes: 240
  },
  constraints: {
    maximumTasks: 6,
    preferredTaskMinutes: 45
  }
};

export const validTaskBreakdownOutput = {
  summary: "A staged plan for completing the report.",
  tasks: [
    {
      title: "Define the question",
      description: "Write a focused research question.",
      estimatedMinutes: 30,
      order: 1,
      dependsOnOrders: [],
      reason: "The question guides the remaining work."
    },
    {
      title: "Review sources",
      description: "Collect and compare credible academic sources.",
      estimatedMinutes: 90,
      order: 2,
      dependsOnOrders: [1],
      reason: "Evidence is needed before drafting."
    }
  ],
  warnings: []
};

export function authHeaders(
  additional: HeadersInit = {}
): Headers {
  return new Headers({
    Authorization: "Bearer " + dummyToken,
    "Content-Type": "application/json",
    "X-Firebase-AppCheck": dummyToken,
    ...Object.fromEntries(new Headers(additional))
  });
}

export function silentLogger(): StructuredLogger {
  return {
    info: () => undefined,
    error: () => undefined
  };
}

export function makeDependencies(
  overrides: Partial<AppDependencies> = {}
): AppDependencies {
  const defaults: AppDependencies = {
    verifyIdToken: async () => ({ uid: "verified-user-123" }),
    verifyAppCheck: async () => ({ appId: "verified-app-123" }),
    consumeQuota: async (_uid, _day, limit, nowMs) => ({
      allowed: true,
      limit,
      remaining: limit - 1,
      resetAtMs:
        Date.parse(new Date(nowMs).toISOString().slice(0, 10) +
          "T00:00:00.000Z") + 86_400_000
    }),
    generate: async () => ({
      data: validTaskBreakdownOutput,
      provider: "gemini",
      model: "test-model"
    }),
    hashUid: async () => "hashed-uid",
    logger: silentLogger(),
    now: () => Date.parse("2026-07-11T12:00:00.000Z"),
    randomUuid: () => "00000000-0000-4000-8000-000000000001"
  };
  return { ...defaults, ...overrides };
}

export function taskBreakdownRequest(
  body: unknown = validTaskBreakdownInput,
  headers: HeadersInit = authHeaders()
): Request {
  return new Request(
    "https://worker.example.test/v1/ai/task-breakdown",
    {
      method: "POST",
      headers,
      body: JSON.stringify(body)
    }
  );
}

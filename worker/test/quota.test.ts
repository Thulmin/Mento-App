import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";

describe("UserDailyQuota Durable Object", () => {
  it("atomically permits only the configured daily number", async () => {
    const stub = env.USER_DAILY_QUOTA.getByName(
      "quota-" + crypto.randomUUID()
    );
    const nowMs = Date.parse("2026-07-11T12:00:00.000Z");

    const results = await Promise.all(
      Array.from({ length: 8 }, async () =>
        await stub.checkAndConsume("2026-07-11", 3, nowMs)
      )
    );

    expect(results.filter((result) => result.allowed)).toHaveLength(3);
    expect(results.filter((result) => !result.allowed)).toHaveLength(5);
    expect(results.at(-1)).toMatchObject({
      allowed: false,
      remaining: 0,
      limit: 3
    });
  });
});

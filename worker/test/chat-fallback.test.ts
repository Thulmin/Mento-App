import { describe, expect, it } from "vitest";
import {
  createImmediateLocalChatResponse,
  createLocalChatFallback
} from "../src/chat-fallback";
import { chatOutputSchema } from "../src/schemas";

const context = {
  now: "2026-08-12T02:00:00.000Z",
  modules: [
    {
      id: "module-1",
      name: "Engineering Mobile Applications",
      code: "EMA",
      semester: "1"
    }
  ],
  assignments: [
    {
      id: "assignment-1",
      moduleId: "module-1",
      title: "Mobile application report",
      dueAt: "2026-08-14T12:00:00.000Z",
      priority: "high" as const,
      status: "inProgress" as const,
      progress: 0.4,
      estimatedMinutes: 180
    }
  ]
};

describe("built-in chat fallback", () => {
  it.each([
    ["Hi", "Hi! I’m Mento"],
    ["Suggest a balanced revision method", "50/10 revision cycle"],
    ["Help me prioritise this week", "Mobile application report"],
    ["What modules have I added?", "Engineering Mobile Applications"]
  ])("answers %s without a provider", (message, expected) => {
    const result = createImmediateLocalChatResponse({ message, context });
    const parsed = chatOutputSchema.parse(result);

    expect(parsed.reply).toContain(expected);
    expect(parsed.dataActions).toEqual([]);
    expect(parsed.disclaimer).toContain("no external provider was needed");
  });

  it("leaves open-ended chat for the real providers", () => {
    expect(
      createImmediateLocalChatResponse({
        message: "Explain dependency injection with an example.",
        context
      })
    ).toBeUndefined();
  });

  it("still returns a safe response after a complete provider outage", () => {
    const parsed = chatOutputSchema.parse(
      createLocalChatFallback({
        message: "Explain dependency injection with an example.",
        context
      })
    );

    expect(parsed.reply).toContain("Mobile application report");
    expect(parsed.disclaimer).toContain("providers were unavailable");
  });
});

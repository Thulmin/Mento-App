import { describe, expect, it } from "vitest";
import {
  chatInputSchema,
  chatOutputSchema,
  endpointDefinitions,
  toProviderJsonSchema
} from "../src/schemas";

const validContext = {
  now: "2026-07-17T08:30:00.000Z",
  modules: [
    {
      id: "module-1",
      name: "Engineering Mobile Applications",
      code: "M1",
      semester: "1"
    }
  ],
  topics: [
    {
      id: "topic-1",
      moduleId: "module-1",
      name: "Firebase authentication",
      mastery: 0.45
    }
  ],
  assignments: [
    {
      id: "assignment-1",
      moduleId: "module-1",
      title: "Mobile application coursework",
      dueAt: "2026-08-14T16:00:00.000Z",
      priority: "high",
      status: "inProgress",
      progress: 0.35,
      estimatedMinutes: 720
    }
  ],
  examinations: [
    {
      id: "exam-1",
      moduleId: "module-1",
      title: "Mobile development viva",
      startAt: "2026-09-02T09:00:00.000Z",
      endAt: "2026-09-02T09:30:00.000Z",
      importance: "high",
      preparationProgress: 0.2
    }
  ],
  tasks: [
    {
      id: "task-1",
      title: "Verify Apple sign-in",
      moduleId: "module-1",
      topicId: "topic-1",
      dueAt: "2026-07-20T12:00:00.000Z",
      priority: "high",
      estimatedMinutes: 60,
      status: "notStarted"
    },
    {
      id: "task-2",
      title: "Review weekly plan",
      moduleId: null,
      topicId: null,
      dueAt: "2026-07-21T12:00:00.000Z",
      priority: "medium",
      estimatedMinutes: 30,
      status: "notStarted"
    }
  ],
  timetableEvents: [
    {
      id: "event-1",
      title: "Mobile applications lecture",
      moduleId: "module-1",
      type: "lecture",
      startAt: "2026-07-20T08:00:00.000Z",
      endAt: "2026-07-20T10:00:00.000Z",
      recurrence: "weekly"
    }
  ],
  habits: [
    {
      id: "habit-1",
      name: "Review lecture notes",
      category: "reading",
      frequency: "weekdays",
      weeklyTarget: 5,
      isArchived: false
    }
  ],
  weeklyFocusMinutes: 185
};

function chatOutput(dataActions: readonly unknown[]): unknown {
  return {
    reply: "I found the relevant records and prepared the requested changes.",
    suggestedActions: [],
    dataActions
  };
}

describe("assistant chat schemas", () => {
  it("accepts the bounded current-user context emitted by the app", () => {
    expect(
      chatInputSchema.safeParse({
        message: "What should I work on next?",
        conversation: [
          {
            role: "user",
            content: "Help me organise this week."
          },
          {
            role: "assistant",
            content: "I can use your current Mento records."
          }
        ],
        context: validContext
      }).success
    ).toBe(true);
  });

  it("rejects unbounded or sensitive context fields", () => {
    const profileResult = chatInputSchema.safeParse({
      message: "Help me plan.",
      context: {
        ...validContext,
        profile: {
          email: "student@example.test"
        }
      }
    });
    const locationResult = chatInputSchema.safeParse({
      message: "Help me plan.",
      context: {
        ...validContext,
        timetableEvents: [
          {
            ...validContext.timetableEvents[0],
            latitude: 51.4816,
            longitude: -3.1791
          }
        ]
      }
    });
    const oversizedResult = chatInputSchema.safeParse({
      message: "Help me plan.",
      context: {
        modules: Array.from({ length: 41 }, (_, index) => ({
          id: `module-${index}`,
          name: `Module ${index}`,
          code: `M${index}`,
          semester: "1"
        }))
      }
    });

    expect(profileResult.success).toBe(false);
    expect(locationResult.success).toBe(false);
    expect(oversizedResult.success).toBe(false);
  });

  it("accepts strict create, update, and delete proposals", () => {
    const result = chatOutputSchema.safeParse(
      chatOutput([
        {
          actionId: "action-create-task",
          operation: "create",
          resource: "studyTask",
          payload: {
            title: "Test Apple sign-in on a physical device",
            moduleId: "module-1",
            topicId: "topic-1",
            dueAt: "2026-07-20T12:00:00.000Z",
            estimatedMinutes: 45,
            priority: "high"
          },
          reason: "This is the next incomplete implementation check.",
          requiresConfirmation: true
        },
        {
          actionId: "action-update-assignment",
          operation: "update",
          resource: "assignment",
          resourceId: "assignment-1",
          payload: {
            manualProgress: 0.5,
            status: "inProgress"
          },
          reason: "The student explicitly asked to record current progress.",
          requiresConfirmation: true
        },
        {
          actionId: "action-delete-habit",
          operation: "delete",
          resource: "habit",
          resourceId: "habit-1",
          payload: {},
          reason: "The student explicitly asked to remove this habit.",
          requiresConfirmation: true
        }
      ])
    );

    expect(result.success).toBe(true);
  });

  it("normalises omitted optional action arrays to empty lists", () => {
    const result = chatOutputSchema.parse({
      reply: "Your current module is Mobile Application Engineering."
    });

    expect(result.suggestedActions).toEqual([]);
    expect(result.dataActions).toEqual([]);
  });

  it.each([
    {
      label: "arbitrary resource",
      action: {
        actionId: "action-1",
        operation: "delete",
        resource: "users/verified-user-123/modules",
        resourceId: "module-1",
        payload: {},
        reason: "Unsupported raw path.",
        requiresConfirmation: true
      }
    },
    {
      label: "raw document path",
      action: {
        actionId: "action-2",
        operation: "update",
        resource: "module",
        resourceId: "users/user-1/modules/module-1",
        payload: { name: "Updated module" },
        reason: "A path must never be accepted as an ID.",
        requiresConfirmation: true
      }
    },
    {
      label: "unknown payload field",
      action: {
        actionId: "action-3",
        operation: "create",
        resource: "module",
        payload: {
          name: "New module",
          code: "M4",
          firestorePath: "users/user-1/modules"
        },
        reason: "Only allow-listed module fields are valid.",
        requiresConfirmation: true
      }
    },
    {
      label: "update without exact ID",
      action: {
        actionId: "action-4",
        operation: "update",
        resource: "assignment",
        payload: { status: "completed" },
        reason: "Updates require an exact existing record ID.",
        requiresConfirmation: true
      }
    },
    {
      label: "empty update",
      action: {
        actionId: "action-5",
        operation: "update",
        resource: "habit",
        resourceId: "habit-1",
        payload: {},
        reason: "An update must change at least one allow-listed field.",
        requiresConfirmation: true
      }
    },
    {
      label: "delete with mutation payload",
      action: {
        actionId: "action-6",
        operation: "delete",
        resource: "studyTask",
        resourceId: "task-1",
        payload: { title: "Unexpected" },
        reason: "Delete proposals must not carry update fields.",
        requiresConfirmation: true
      }
    },
    {
      label: "confirmation bypass",
      action: {
        actionId: "action-7",
        operation: "create",
        resource: "habit",
        payload: { name: "Daily review" },
        reason: "The app must always ask before applying this.",
        requiresConfirmation: false
      }
    }
  ])("rejects $label proposals", ({ action }) => {
    expect(chatOutputSchema.safeParse(chatOutput([action])).success).toBe(
      false
    );
  });

  it("exports a compact chat envelope while keeping strict local actions", () => {
    expect(endpointDefinitions.chat.providerOutputSchema).toBeDefined();
    const providerSchema = toProviderJsonSchema(
      endpointDefinitions.chat.providerOutputSchema ??
        endpointDefinitions.chat.outputSchema
    );
    const serialized = JSON.stringify(providerSchema);

    expect(serialized).toContain("\"dataActionsJson\"");
    expect(serialized).not.toContain("\"requiresConfirmation\"");
    expect(serialized.length).toBeLessThan(5_000);
    expect(serialized).not.toContain("\"$schema\"");
  });
});

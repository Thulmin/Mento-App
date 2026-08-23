import { chatInputSchema, chatOutputSchema } from "./schemas";

interface DatedItem {
  readonly title: string;
  readonly kind: "assignment" | "exam" | "task";
  readonly at: string;
  readonly priority: "urgent" | "high" | "medium" | "low";
}

const priorityRank = { urgent: 0, high: 1, medium: 2, low: 3 } as const;

function dateLabel(value: string): string {
  return new Intl.DateTimeFormat("en", {
    day: "numeric",
    month: "short",
    timeZone: "UTC"
  }).format(new Date(value));
}

function upcomingItems(
  input: ReturnType<typeof chatInputSchema.parse>
): readonly DatedItem[] {
  const context = input.context;
  if (context === undefined) {
    return [];
  }
  const now = Date.parse(context.now ?? new Date().toISOString());
  const items: DatedItem[] = [];

  for (const assignment of context.assignments ?? []) {
    if (
      assignment.status === "completed" ||
      assignment.status === "cancelled"
    ) {
      continue;
    }
    items.push({
      title: assignment.title,
      kind: "assignment",
      at: assignment.dueAt,
      priority: assignment.priority
    });
  }
  for (const exam of context.examinations ?? []) {
    if (Date.parse(exam.endAt) < now) {
      continue;
    }
    items.push({
      title: exam.title,
      kind: "exam",
      at: exam.startAt,
      priority: exam.importance
    });
  }
  for (const task of context.tasks ?? []) {
    if (task.status === "completed" || task.status === "cancelled") {
      continue;
    }
    items.push({
      title: task.title,
      kind: "task",
      at: task.dueAt,
      priority: task.priority
    });
  }

  return items
    .filter((item) => Number.isFinite(Date.parse(item.at)))
    .sort((left, right) => {
      const dateDifference = Date.parse(left.at) - Date.parse(right.at);
      return dateDifference === 0
        ? priorityRank[left.priority] - priorityRank[right.priority]
        : dateDifference;
    })
    .slice(0, 3);
}

function priorityReply(items: readonly DatedItem[]): string {
  if (items.length === 0) {
    return (
      "Use three priorities for this week: first complete the nearest " +
      "deadline, then prepare the weakest high-impact topic, and finally " +
      "reserve one catch-up block. Plan only about 70% of your available " +
      "time so unexpected work does not break the schedule."
    );
  }
  const lines = items.map(
    (item, index) =>
      `${index + 1}. ${item.title} — ${item.kind}, ${dateLabel(item.at)}`
  );
  return (
    "Based on your synced deadlines, work in this order:\n" +
    lines.join("\n") +
    "\nGive the first item your next focused block, then reassess the list."
  );
}

export function createLocalChatFallback(input: unknown): unknown {
  const parsed = chatInputSchema.parse(input);
  const immediate = createImmediateLocalChatResponse(parsed);
  if (immediate !== undefined) {
    return immediate;
  }
  const items = upcomingItems(parsed);
  const reply =
    items.length > 0
      ? priorityReply(items) +
        " I can still help you organise these items while the external AI service recovers."
      : "I can help with revision methods, weekly priorities, assignment breakdowns, " +
        "and your synced modules. Try asking, “What should I study first this week?”";

  return chatOutputSchema.parse({
    reply,
    suggestedActions: [],
    dataActions: [],
    disclaimer:
      "Built-in study response used because external AI providers were unavailable; no records were changed."
  });
}

export function createImmediateLocalChatResponse(
  input: unknown
): ReturnType<typeof chatOutputSchema.parse> | undefined {
  const parsed = chatInputSchema.parse(input);
  const message = parsed.message.trim().toLowerCase();
  const modules = (parsed.context?.modules ?? []).map((module) => module.name);
  const items = upcomingItems(parsed);
  let reply: string | undefined;

  if (/^(hi|hello|hey|good\s+(morning|afternoon|evening))[!. ]*$/.test(message)) {
    const contextNote =
      modules.length === 0
        ? ""
        : ` I can use your ${modules.length} synced module${modules.length === 1 ? "" : "s"} to help you plan.`;
    reply =
      "Hi! I’m Mento, your study assistant." +
      contextNote +
      " Ask me what to prioritise, how to revise, or how to break down an assignment.";
  } else if (
    /\b(module|modules|subjects?|courses?)\b/.test(message) &&
    /\b(added|have|list|what|which|show)\b/.test(message)
  ) {
    reply =
      modules.length === 0
        ? "You have not added any study modules yet."
        : `You have added ${modules.length} module${modules.length === 1 ? "" : "s"}: ${modules.join(", ")}.`;
  } else if (/\b(revision|revise|study method|study routine)\b/.test(message)) {
    reply =
      "Try a balanced 50/10 revision cycle: spend 50 minutes on one module, " +
      "using active recall for the first 30 minutes and practice questions for " +
      "the next 20, then take a 10-minute break. Rotate modules after two " +
      "cycles and finish with a five-minute summary of what to revisit tomorrow.";
  } else if (/\b(prioriti[sz]e|priority|this week|work on next|what next)\b/.test(message)) {
    reply = priorityReply(items);
  }

  if (reply === undefined) {
    return undefined;
  }
  return chatOutputSchema.parse({
    reply,
    suggestedActions: [],
    dataActions: [],
    disclaimer:
      "Built-in Mento study response; no external provider was needed and no records were changed."
  });
}

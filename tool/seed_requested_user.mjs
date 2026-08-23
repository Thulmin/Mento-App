import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { configstore } = require(
  "../firestore-tests/node_modules/firebase-tools/lib/configstore"
);
const firebaseAuth = require(
  "../firestore-tests/node_modules/firebase-tools/lib/auth"
);

const projectId = "mento-app-d737c";
const targetUid = "0u07dVsVC1YNlVJkwDHNJDuhClA2";
const targetEmail = "thulminjayawardena@gmail.com";
const apply = process.argv.includes("--apply");
const databaseRoot =
  `projects/${projectId}/databases/(default)/documents`;
const apiRoot = `https://firestore.googleapis.com/v1/${databaseRoot}`;

const moduleIds = {
  wireless: "6shidKpmvJ4MhqjK85Qv",
  algorithms: "BEkpi8H9dJDG6JFAdPnB",
  mobile: "JfqJ2yG6kxN8vv4EWwKw"
};

const expectedModules = new Map([
  [moduleIds.wireless, "Wireless Networks"],
  [moduleIds.algorithms, "Algorithems"],
  [moduleIds.mobile, "Engineering Mobile Applications"]
]);

const topicIds = {
  wirelessArchitecture: "seed-20260717-topic-wireless-architecture",
  wirelessSecurity: "seed-20260717-topic-wireless-security",
  wirelessMobility: "seed-20260717-topic-wireless-mobility",
  complexity: "seed-20260717-topic-complexity",
  sorting: "seed-20260717-topic-sorting",
  graphs: "seed-20260717-topic-graphs",
  mobileArchitecture: "seed-20260717-topic-mobile-architecture",
  firebaseSecurity: "seed-20260717-topic-firebase-security",
  platformIntegration: "seed-20260717-topic-platform-integration"
};

const taskIds = {
  firebaseFlows: "seed-20260717-task-firebase-flows",
  mapsDiagnostics: "seed-20260717-task-maps-diagnostics",
  aiContext: "seed-20260717-task-ai-context",
  mobileReport: "seed-20260717-task-mobile-report",
  wlanRequirements: "seed-20260717-task-wlan-requirements",
  wlanThreats: "seed-20260717-task-wlan-threats",
  wlanDiagram: "seed-20260717-task-wlan-diagram",
  complexitySummary: "seed-20260717-task-complexity-summary",
  sortingImplementation: "seed-20260717-task-sorting-implementation",
  graphPractice: "seed-20260717-task-graph-practice",
  algorithmsReport: "seed-20260717-task-algorithms-report",
  weeklyReview: "seed-20260717-task-weekly-review"
};

const createdAt = new Date("2026-07-17T01:00:00.000Z");
const updatedAt = new Date("2026-07-17T01:15:00.000Z");

const document = (collection, id, data) => ({
  collection,
  id,
  data: {
    ownerId: targetUid,
    createdAt,
    updatedAt,
    ...data
  }
});

const topic = (
  id,
  moduleId,
  name,
  description,
  mastery,
  completedStudyMinutes
) =>
  document("topics", id, {
    moduleId,
    name,
    description,
    mastery,
    completedStudyMinutes
  });

const subtask = (
  id,
  title,
  estimatedMinutes,
  order,
  isCompleted = false,
  completedAtValue
) => ({
  id,
  title,
  isCompleted,
  estimatedMinutes,
  order,
  ...(completedAtValue === undefined
    ? {}
    : { completedAt: completedAtValue })
});

const studyTask = (
  id,
  title,
  moduleId,
  topicId,
  dueAt,
  estimatedMinutes,
  priority,
  status,
  options = {}
) =>
  document("studyTasks", id, {
    title,
    moduleId,
    topicId,
    dueAt: new Date(dueAt),
    estimatedMinutes,
    priority,
    status,
    isAiGenerated: options.isAiGenerated ?? false,
    needsRescheduling: false,
    ...(options.plannedStartAt === undefined
      ? {}
      : { plannedStartAt: new Date(options.plannedStartAt) }),
    ...(options.completedAt === undefined
      ? {}
      : { completedAt: new Date(options.completedAt) }),
    ...(options.notes === undefined ? {} : { notes: options.notes })
  });

const focusSession = (
  id,
  moduleId,
  topicId,
  goal,
  targetMinutes,
  startedAt,
  activeMinutes,
  pausedSeconds,
  interruptionCount
) => {
  const start = new Date(startedAt);
  const end = new Date(
    start.getTime() + activeMinutes * 60_000 + pausedSeconds * 1_000
  );
  return document("focusSessions", id, {
    moduleId,
    topicId,
    goal,
    targetMinutes,
    startedAt: start,
    state: "completed",
    endedAt: end,
    accumulatedActiveSeconds: activeMinutes * 60,
    accumulatedPausedSeconds: pausedSeconds,
    isBreak: false,
    interruptionCount
  });
};

const seedDocuments = [
  topic(
    topicIds.wirelessArchitecture,
    moduleIds.wireless,
    "Wireless standards and network architecture",
    "IEEE 802.11 families, infrastructure modes, channel planning and WLAN design.",
    0.42,
    155
  ),
  topic(
    topicIds.wirelessSecurity,
    moduleIds.wireless,
    "WLAN security and authentication",
    "WPA3, enterprise authentication, common wireless attacks and mitigations.",
    0.31,
    105
  ),
  topic(
    topicIds.wirelessMobility,
    moduleIds.wireless,
    "Mobility, roaming and performance",
    "Roaming, handoff behaviour, interference, capacity and quality of service.",
    0.25,
    70
  ),
  topic(
    topicIds.complexity,
    moduleIds.algorithms,
    "Asymptotic analysis",
    "Big-O, Big-Theta, Big-Omega and comparing time and space complexity.",
    0.55,
    210
  ),
  topic(
    topicIds.sorting,
    moduleIds.algorithms,
    "Sorting and searching",
    "Comparison sorting, binary search and selecting algorithms for realistic inputs.",
    0.47,
    165
  ),
  topic(
    topicIds.graphs,
    moduleIds.algorithms,
    "Graphs and dynamic programming",
    "Graph traversal, shortest paths and recognising overlapping subproblems.",
    0.28,
    85
  ),
  topic(
    topicIds.mobileArchitecture,
    moduleIds.mobile,
    "Flutter architecture and responsive UI",
    "State management, repository boundaries, adaptive layouts and navigation.",
    0.63,
    260
  ),
  topic(
    topicIds.firebaseSecurity,
    moduleIds.mobile,
    "Firebase authentication and data security",
    "Federated authentication, owner-scoped Firestore rules and secure account lifecycle.",
    0.48,
    185
  ),
  topic(
    topicIds.platformIntegration,
    moduleIds.mobile,
    "Maps, AI and platform integration",
    "Google Maps configuration, secure AI proxies, device permissions and service fallbacks.",
    0.36,
    135
  ),

  document("assignments", "seed-20260717-assignment-mobile-portfolio", {
    moduleId: moduleIds.mobile,
    title: "Mento mobile application engineering portfolio",
    description:
      "Complete the Flutter implementation, Firebase integration, testing evidence, architecture discussion and demonstration notes for the Mento application.",
    dueAt: new Date("2026-08-03T16:00:00.000Z"),
    priority: "high",
    estimatedMinutes: 1200,
    status: "inProgress",
    subtasks: [
      subtask(
        "mobile-subtask-1",
        "Responsive application shell and core screens",
        180,
        0,
        true,
        new Date("2026-07-14T14:30:00.000Z")
      ),
      subtask(
        "mobile-subtask-2",
        "Authentication, Maps and AI integration",
        300,
        1,
        true,
        new Date("2026-07-17T00:45:00.000Z")
      ),
      subtask(
        "mobile-subtask-3",
        "Automated tests and device evidence",
        240,
        2
      ),
      subtask(
        "mobile-subtask-4",
        "Architecture and security report",
        300,
        3
      ),
      subtask(
        "mobile-subtask-5",
        "Presentation rehearsal and final review",
        180,
        4
      )
    ],
    manualProgress: 0.46,
    reminderAt: new Date("2026-08-01T08:00:00.000Z"),
    attachments: []
  }),
  document("assignments", "seed-20260717-assignment-wireless-report", {
    moduleId: moduleIds.wireless,
    title: "Secure campus WLAN design report",
    description:
      "Design a secure and scalable wireless network, justify standards and channel choices, assess threats, and document monitoring and rollout recommendations.",
    dueAt: new Date("2026-07-29T16:00:00.000Z"),
    priority: "urgent",
    estimatedMinutes: 720,
    status: "inProgress",
    subtasks: [
      subtask(
        "wireless-subtask-1",
        "Capture requirements and assumptions",
        90,
        0,
        true,
        new Date("2026-07-16T16:10:00.000Z")
      ),
      subtask(
        "wireless-subtask-2",
        "Create logical WLAN design",
        150,
        1
      ),
      subtask(
        "wireless-subtask-3",
        "Complete threat and control matrix",
        150,
        2
      ),
      subtask(
        "wireless-subtask-4",
        "Write performance and monitoring section",
        150,
        3
      ),
      subtask(
        "wireless-subtask-5",
        "Edit, reference and submit",
        180,
        4
      )
    ],
    manualProgress: 0.28,
    reminderAt: new Date("2026-07-27T08:00:00.000Z"),
    attachments: []
  }),
  document("assignments", "seed-20260717-assignment-algorithms", {
    moduleId: moduleIds.algorithms,
    title: "Algorithm analysis and implementation coursework",
    description:
      "Implement and compare selected algorithms, explain complexity, present test evidence, and evaluate trade-offs for different input sizes.",
    dueAt: new Date("2026-08-10T16:00:00.000Z"),
    priority: "high",
    estimatedMinutes: 900,
    status: "notStarted",
    subtasks: [
      subtask(
        "algorithms-subtask-1",
        "Confirm problem statement and test cases",
        90,
        0
      ),
      subtask(
        "algorithms-subtask-2",
        "Implement sorting comparison",
        210,
        1
      ),
      subtask(
        "algorithms-subtask-3",
        "Implement graph traversal solution",
        210,
        2
      ),
      subtask(
        "algorithms-subtask-4",
        "Analyse complexity and results",
        210,
        3
      ),
      subtask(
        "algorithms-subtask-5",
        "Write and proofread report",
        180,
        4
      )
    ],
    manualProgress: 0.12,
    reminderAt: new Date("2026-08-08T08:00:00.000Z"),
    attachments: []
  }),

  document("examinations", "seed-20260717-exam-mobile-demo", {
    moduleId: moduleIds.mobile,
    title: "Mobile application project demonstration",
    startAt: new Date("2026-08-07T09:00:00.000Z"),
    endAt: new Date("2026-08-07T09:30:00.000Z"),
    venue: "Online demonstration room",
    syllabusTopicIds: [
      topicIds.mobileArchitecture,
      topicIds.firebaseSecurity,
      topicIds.platformIntegration
    ],
    importance: "urgent",
    preparationProgress: 0.43,
    reminderAt: new Date("2026-08-05T08:00:00.000Z"),
    notes:
      "Prepare a stable build, concise architecture explanation and fallback demo path."
  }),
  document("examinations", "seed-20260717-exam-algorithms-test", {
    moduleId: moduleIds.algorithms,
    title: "Algorithms class assessment",
    startAt: new Date("2026-08-12T08:30:00.000Z"),
    endAt: new Date("2026-08-12T10:00:00.000Z"),
    venue: "Online assessment portal",
    syllabusTopicIds: [
      topicIds.complexity,
      topicIds.sorting,
      topicIds.graphs
    ],
    importance: "high",
    preparationProgress: 0.34,
    reminderAt: new Date("2026-08-10T08:00:00.000Z"),
    notes: "Prioritise worked examples and time-complexity explanations."
  }),
  document("examinations", "seed-20260717-exam-wireless", {
    moduleId: moduleIds.wireless,
    title: "Wireless networks applied assessment",
    startAt: new Date("2026-08-18T09:00:00.000Z"),
    endAt: new Date("2026-08-18T10:30:00.000Z"),
    venue: "Online assessment portal",
    syllabusTopicIds: [
      topicIds.wirelessArchitecture,
      topicIds.wirelessSecurity,
      topicIds.wirelessMobility
    ],
    importance: "high",
    preparationProgress: 0.29,
    reminderAt: new Date("2026-08-16T08:00:00.000Z"),
    notes: "Review design scenarios, security controls and capacity trade-offs."
  }),

  studyTask(
    taskIds.firebaseFlows,
    "Verify Firebase and federated authentication flows",
    moduleIds.mobile,
    topicIds.firebaseSecurity,
    "2026-07-18T15:00:00.000Z",
    60,
    "urgent",
    "inProgress",
    {
      plannedStartAt: "2026-07-18T10:30:00.000Z",
      notes: "Test email, Google, disabled Apple fallback and onboarding consent."
    }
  ),
  studyTask(
    taskIds.mapsDiagnostics,
    "Document Maps configuration and manual fallback",
    moduleIds.mobile,
    topicIds.platformIntegration,
    "2026-07-19T14:00:00.000Z",
    50,
    "high",
    "notStarted",
    {
      plannedStartAt: "2026-07-19T09:30:00.000Z",
      notes: "Record the billing/API/key restriction prerequisites."
    }
  ),
  studyTask(
    taskIds.aiContext,
    "Validate Mento context, chat history and CRUD proposals",
    moduleIds.mobile,
    topicIds.platformIntegration,
    "2026-07-20T14:00:00.000Z",
    75,
    "high",
    "notStarted",
    {
      isAiGenerated: true,
      plannedStartAt: "2026-07-20T09:00:00.000Z",
      notes: "Check account isolation, confirmation and idempotency."
    }
  ),
  studyTask(
    taskIds.mobileReport,
    "Draft mobile architecture and security report section",
    moduleIds.mobile,
    topicIds.mobileArchitecture,
    "2026-07-24T16:00:00.000Z",
    120,
    "high",
    "notStarted",
    { plannedStartAt: "2026-07-23T13:00:00.000Z" }
  ),
  studyTask(
    taskIds.wlanRequirements,
    "Refine WLAN requirements and design assumptions",
    moduleIds.wireless,
    topicIds.wirelessArchitecture,
    "2026-07-19T12:00:00.000Z",
    60,
    "urgent",
    "inProgress",
    {
      plannedStartAt: "2026-07-18T13:30:00.000Z",
      notes: "Confirm coverage, user density, security and availability targets."
    }
  ),
  studyTask(
    taskIds.wlanThreats,
    "Build wireless threat and mitigation matrix",
    moduleIds.wireless,
    topicIds.wirelessSecurity,
    "2026-07-21T16:00:00.000Z",
    90,
    "urgent",
    "notStarted",
    { plannedStartAt: "2026-07-21T12:30:00.000Z" }
  ),
  studyTask(
    taskIds.wlanDiagram,
    "Create logical WLAN architecture diagram",
    moduleIds.wireless,
    topicIds.wirelessArchitecture,
    "2026-07-23T16:00:00.000Z",
    90,
    "high",
    "notStarted",
    { plannedStartAt: "2026-07-22T13:00:00.000Z" }
  ),
  studyTask(
    taskIds.complexitySummary,
    "Summarise Big-O and Big-Theta examples",
    moduleIds.algorithms,
    topicIds.complexity,
    "2026-07-16T16:00:00.000Z",
    45,
    "medium",
    "completed",
    {
      completedAt: "2026-07-15T14:40:00.000Z",
      notes: "Summary covers constant, logarithmic, linear and quadratic growth."
    }
  ),
  studyTask(
    taskIds.sortingImplementation,
    "Implement and benchmark two sorting algorithms",
    moduleIds.algorithms,
    topicIds.sorting,
    "2026-07-25T16:00:00.000Z",
    120,
    "high",
    "notStarted",
    { plannedStartAt: "2026-07-24T12:30:00.000Z" }
  ),
  studyTask(
    taskIds.graphPractice,
    "Complete graph traversal practice problems",
    moduleIds.algorithms,
    topicIds.graphs,
    "2026-07-27T16:00:00.000Z",
    75,
    "medium",
    "notStarted",
    { plannedStartAt: "2026-07-26T11:00:00.000Z" }
  ),
  studyTask(
    taskIds.algorithmsReport,
    "Outline the algorithm comparison report",
    moduleIds.algorithms,
    topicIds.sorting,
    "2026-07-30T16:00:00.000Z",
    90,
    "medium",
    "notStarted",
    { isAiGenerated: true }
  ),
  studyTask(
    taskIds.weeklyReview,
    "Review progress across all three modules",
    moduleIds.mobile,
    topicIds.mobileArchitecture,
    "2026-07-20T17:00:00.000Z",
    30,
    "medium",
    "notStarted",
    {
      isAiGenerated: true,
      plannedStartAt: "2026-07-20T16:30:00.000Z"
    }
  ),

  document("timetableEvents", "seed-20260717-event-mobile-lab", {
    title: "Engineering Mobile Applications lab",
    moduleId: moduleIds.mobile,
    type: "laboratory",
    startAt: new Date("2026-07-17T09:30:00.000Z"),
    endAt: new Date("2026-07-17T11:30:00.000Z"),
    location: "Online laboratory room",
    reminderMinutesBefore: 20,
    recurrence: "weekly",
    recurrenceUntil: new Date("2026-09-04T23:59:00.000Z"),
    recurringWeekdays: [5],
    notes: "Keep the current APK and test evidence ready."
  }),
  document("timetableEvents", "seed-20260717-event-algorithms-study", {
    title: "Algorithms guided study",
    moduleId: moduleIds.algorithms,
    type: "tutorial",
    startAt: new Date("2026-07-20T08:30:00.000Z"),
    endAt: new Date("2026-07-20T10:00:00.000Z"),
    location: "Online tutorial room",
    reminderMinutesBefore: 20,
    recurrence: "weekly",
    recurrenceUntil: new Date("2026-09-07T23:59:00.000Z"),
    recurringWeekdays: [1]
  }),
  document("timetableEvents", "seed-20260717-event-wireless-lecture", {
    title: "Wireless Networks lecture",
    moduleId: moduleIds.wireless,
    type: "lecture",
    startAt: new Date("2026-07-21T09:00:00.000Z"),
    endAt: new Date("2026-07-21T11:00:00.000Z"),
    location: "Online lecture room",
    reminderMinutesBefore: 20,
    recurrence: "weekly",
    recurrenceUntil: new Date("2026-09-08T23:59:00.000Z"),
    recurringWeekdays: [2]
  }),
  document("timetableEvents", "seed-20260717-event-mobile-studio", {
    title: "Mento project studio",
    moduleId: moduleIds.mobile,
    type: "personalStudy",
    startAt: new Date("2026-07-22T13:00:00.000Z"),
    endAt: new Date("2026-07-22T14:30:00.000Z"),
    location: "Home study desk",
    reminderMinutesBefore: 10,
    recurrence: "weekly",
    recurrenceUntil: new Date("2026-08-05T23:59:00.000Z"),
    recurringWeekdays: [3],
    notes: "Use this block for implementation, testing and evidence capture."
  }),
  document("timetableEvents", "seed-20260717-event-algorithms-practice", {
    title: "Algorithms problem-solving practice",
    moduleId: moduleIds.algorithms,
    type: "personalStudy",
    startAt: new Date("2026-07-23T12:30:00.000Z"),
    endAt: new Date("2026-07-23T13:45:00.000Z"),
    location: "Home study desk",
    reminderMinutesBefore: 10,
    recurrence: "weekly",
    recurrenceUntil: new Date("2026-08-06T23:59:00.000Z"),
    recurringWeekdays: [4]
  }),
  document("timetableEvents", "seed-20260717-event-weekly-review", {
    title: "Weekly study review and replanning",
    type: "personalStudy",
    startAt: new Date("2026-07-19T15:30:00.000Z"),
    endAt: new Date("2026-07-19T16:00:00.000Z"),
    location: "Home study desk",
    reminderMinutesBefore: 10,
    recurrence: "weekly",
    recurrenceUntil: new Date("2026-09-06T23:59:00.000Z"),
    recurringWeekdays: [7],
    notes: "Review completed work, upcoming deadlines and available hours."
  }),

  document("habits", "seed-20260717-habit-daily-plan", {
    name: "Plan the top three study priorities",
    category: "custom",
    frequency: "weekdays",
    weekdays: [1, 2, 3, 4, 5],
    weeklyTarget: 5,
    reminderTimes: ["08:30"],
    isArchived: false,
    notes: "Keep the list realistic for the available study time."
  }),
  document("habits", "seed-20260717-habit-movement", {
    name: "Take a short movement break",
    category: "movement",
    frequency: "daily",
    weekdays: [],
    weeklyTarget: 7,
    reminderTimes: ["12:30", "17:30"],
    isArchived: false
  }),
  document("habits", "seed-20260717-habit-reading", {
    name: "Read module notes away from notifications",
    category: "reading",
    frequency: "timesPerWeek",
    weekdays: [],
    weeklyTarget: 4,
    reminderTimes: ["19:30"],
    isArchived: false
  }),
  document("habits", "seed-20260717-habit-weekly-review", {
    name: "Complete a weekly study review",
    category: "custom",
    frequency: "selectedDays",
    weekdays: [7],
    weeklyTarget: 1,
    reminderTimes: ["21:00"],
    isArchived: false
  }),

  ...[
    ["seed-20260717-habit-log-plan-0713", "seed-20260717-habit-daily-plan", "2026-07-13T00:00:00.000Z", "2026-07-13T03:05:00.000Z"],
    ["seed-20260717-habit-log-plan-0714", "seed-20260717-habit-daily-plan", "2026-07-14T00:00:00.000Z", "2026-07-14T03:10:00.000Z"],
    ["seed-20260717-habit-log-plan-0715", "seed-20260717-habit-daily-plan", "2026-07-15T00:00:00.000Z", "2026-07-15T03:02:00.000Z"],
    ["seed-20260717-habit-log-plan-0716", "seed-20260717-habit-daily-plan", "2026-07-16T00:00:00.000Z", "2026-07-16T03:18:00.000Z"],
    ["seed-20260717-habit-log-move-0712", "seed-20260717-habit-movement", "2026-07-12T00:00:00.000Z", "2026-07-12T12:35:00.000Z"],
    ["seed-20260717-habit-log-move-0713", "seed-20260717-habit-movement", "2026-07-13T00:00:00.000Z", "2026-07-13T12:40:00.000Z"],
    ["seed-20260717-habit-log-move-0715", "seed-20260717-habit-movement", "2026-07-15T00:00:00.000Z", "2026-07-15T12:42:00.000Z"],
    ["seed-20260717-habit-log-read-0712", "seed-20260717-habit-reading", "2026-07-12T00:00:00.000Z", "2026-07-12T14:30:00.000Z"],
    ["seed-20260717-habit-log-read-0714", "seed-20260717-habit-reading", "2026-07-14T00:00:00.000Z", "2026-07-14T14:45:00.000Z"],
    ["seed-20260717-habit-log-read-0716", "seed-20260717-habit-reading", "2026-07-16T00:00:00.000Z", "2026-07-16T15:05:00.000Z"],
    ["seed-20260717-habit-log-review-0712", "seed-20260717-habit-weekly-review", "2026-07-12T00:00:00.000Z", "2026-07-12T15:45:00.000Z"],
    ["seed-20260717-habit-log-move-0716", "seed-20260717-habit-movement", "2026-07-16T00:00:00.000Z", "2026-07-16T12:38:00.000Z"]
  ].map(([id, habitId, date, loggedAt]) =>
    document("habitLogs", id, {
      habitId,
      date: new Date(date),
      loggedAt: new Date(loggedAt),
      isCompleted: true
    })
  ),

  focusSession(
    "seed-20260717-focus-0709-mobile",
    moduleIds.mobile,
    topicIds.mobileArchitecture,
    "Review Flutter navigation and responsive layout",
    45,
    "2026-07-09T13:00:00.000Z",
    43,
    120,
    1
  ),
  focusSession(
    "seed-20260717-focus-0710-algorithms",
    moduleIds.algorithms,
    topicIds.complexity,
    "Work through complexity examples",
    50,
    "2026-07-10T12:30:00.000Z",
    48,
    90,
    1
  ),
  focusSession(
    "seed-20260717-focus-0711-wireless",
    moduleIds.wireless,
    topicIds.wirelessArchitecture,
    "Read WLAN design guidance",
    45,
    "2026-07-11T13:30:00.000Z",
    44,
    60,
    0
  ),
  focusSession(
    "seed-20260717-focus-0713-mobile",
    moduleIds.mobile,
    topicIds.firebaseSecurity,
    "Review Firebase authentication flow",
    50,
    "2026-07-13T14:00:00.000Z",
    47,
    180,
    2
  ),
  focusSession(
    "seed-20260717-focus-0714-algorithms",
    moduleIds.algorithms,
    topicIds.sorting,
    "Compare sorting algorithm behaviour",
    25,
    "2026-07-14T13:45:00.000Z",
    25,
    0,
    0
  ),
  focusSession(
    "seed-20260717-focus-0715-wireless",
    moduleIds.wireless,
    topicIds.wirelessSecurity,
    "Outline wireless security controls",
    45,
    "2026-07-15T13:00:00.000Z",
    42,
    150,
    1
  ),
  focusSession(
    "seed-20260717-focus-0716-mobile",
    moduleIds.mobile,
    topicIds.platformIntegration,
    "Test AI and Maps integration",
    50,
    "2026-07-16T14:00:00.000Z",
    49,
    75,
    1
  ),
  focusSession(
    "seed-20260717-focus-0717-wireless",
    moduleIds.wireless,
    topicIds.wirelessArchitecture,
    "Refine WLAN requirements",
    25,
    "2026-07-17T00:10:00.000Z",
    24,
    45,
    0
  ),

  ...[
    [topicIds.wirelessArchitecture, moduleIds.wireless, 0.42, 155, 2, 0.64],
    [topicIds.wirelessSecurity, moduleIds.wireless, 0.31, 105, 1, 0.58],
    [topicIds.wirelessMobility, moduleIds.wireless, 0.25, 70, 0, null],
    [topicIds.complexity, moduleIds.algorithms, 0.55, 210, 3, 0.72],
    [topicIds.sorting, moduleIds.algorithms, 0.47, 165, 2, 0.68],
    [topicIds.graphs, moduleIds.algorithms, 0.28, 85, 1, 0.55],
    [topicIds.mobileArchitecture, moduleIds.mobile, 0.63, 260, 4, 0.76],
    [topicIds.firebaseSecurity, moduleIds.mobile, 0.48, 185, 2, 0.69],
    [topicIds.platformIntegration, moduleIds.mobile, 0.36, 135, 1, 0.61]
  ].map(
    ([
      topicId,
      moduleId,
      mastery,
      studyMinutes,
      completedTasks,
      quizAverage
    ]) =>
      document("topicMastery", topicId, {
        topicId,
        moduleId,
        mastery,
        studyMinutes,
        completedTasks,
        ...(quizAverage === null ? {} : { quizAverage })
      })
  ),

  document("achievements", "seed-20260717-achievement-first-task", {
    type: "firstTask",
    title: "First task completed",
    description: "Complete the first tracked study task.",
    threshold: 1,
    pointsReward: 25,
    iconName: "task_alt",
    progress: 1,
    unlockedAt: new Date("2026-07-14T14:45:00.000Z")
  }),
  document("achievements", "seed-20260717-achievement-first-focus", {
    type: "firstFocusSession",
    title: "Focused start",
    description: "Complete the first intentional focus session.",
    threshold: 1,
    pointsReward: 50,
    iconName: "timer",
    progress: 1,
    unlockedAt: new Date("2026-07-09T13:45:00.000Z")
  }),
  document("achievements", "seed-20260717-achievement-focused-hour", {
    type: "focusedHour",
    title: "One focused hour",
    description: "Accumulate at least sixty minutes of focused study.",
    threshold: 60,
    pointsReward: 75,
    iconName: "hourglass_bottom",
    progress: 1,
    unlockedAt: new Date("2026-07-10T13:20:00.000Z")
  }),
  document("achievements", "seed-20260717-achievement-three-day", {
    type: "threeDayStreak",
    title: "Three-day rhythm",
    description: "Make meaningful study progress on three consecutive days.",
    threshold: 3,
    pointsReward: 100,
    iconName: "local_fire_department",
    progress: 1,
    unlockedAt: new Date("2026-07-11T14:20:00.000Z")
  }),

  document("studyPlans", "seed-20260717-plan-week-29", {
    userId: targetUid,
    generatedAt: new Date("2026-07-17T01:10:00.000Z"),
    rangeStart: new Date("2026-07-18T00:00:00.000Z"),
    rangeEnd: new Date("2026-07-25T00:00:00.000Z"),
    source: "deterministic",
    blocks: [
      {
        id: "seed-plan-block-1",
        startAt: new Date("2026-07-18T10:30:00.000Z"),
        endAt: new Date("2026-07-18T11:30:00.000Z"),
        moduleId: moduleIds.mobile,
        topicId: topicIds.firebaseSecurity,
        objective: "Verify Firebase and federated authentication flows",
        recommendedMethod: "Test matrix with screenshots and short notes",
        breakMinutes: 10,
        priority: "urgent",
        reason: "Authentication evidence is needed before the portfolio review.",
        source: "deterministic",
        linkedTaskId: taskIds.firebaseFlows,
        status: "accepted"
      },
      {
        id: "seed-plan-block-2",
        startAt: new Date("2026-07-18T13:30:00.000Z"),
        endAt: new Date("2026-07-18T14:30:00.000Z"),
        moduleId: moduleIds.wireless,
        topicId: topicIds.wirelessArchitecture,
        objective: "Refine WLAN requirements and assumptions",
        recommendedMethod: "Requirements checklist and constraint table",
        breakMinutes: 10,
        priority: "urgent",
        reason: "The wireless report is the nearest assignment deadline.",
        source: "deterministic",
        linkedTaskId: taskIds.wlanRequirements,
        status: "accepted"
      },
      {
        id: "seed-plan-block-3",
        startAt: new Date("2026-07-19T09:30:00.000Z"),
        endAt: new Date("2026-07-19T10:20:00.000Z"),
        moduleId: moduleIds.mobile,
        topicId: topicIds.platformIntegration,
        objective: "Document Maps configuration and manual fallback",
        recommendedMethod: "Configuration checklist with verified failure states",
        breakMinutes: 10,
        priority: "high",
        reason: "This closes a visible implementation and demonstration gap.",
        source: "deterministic",
        linkedTaskId: taskIds.mapsDiagnostics,
        status: "accepted"
      },
      {
        id: "seed-plan-block-4",
        startAt: new Date("2026-07-20T09:00:00.000Z"),
        endAt: new Date("2026-07-20T10:15:00.000Z"),
        moduleId: moduleIds.mobile,
        topicId: topicIds.platformIntegration,
        objective: "Validate Mento context, history and CRUD proposals",
        recommendedMethod: "Scenario testing with create, update and cancel cases",
        breakMinutes: 15,
        priority: "high",
        reason: "Reliable assistant behaviour supports the main project objective.",
        source: "deterministic",
        linkedTaskId: taskIds.aiContext,
        status: "accepted"
      },
      {
        id: "seed-plan-block-5",
        startAt: new Date("2026-07-21T12:30:00.000Z"),
        endAt: new Date("2026-07-21T14:00:00.000Z"),
        moduleId: moduleIds.wireless,
        topicId: topicIds.wirelessSecurity,
        objective: "Build the wireless threat and mitigation matrix",
        recommendedMethod: "Threat, likelihood, impact and control table",
        breakMinutes: 15,
        priority: "urgent",
        reason: "Security analysis is a major section of the nearest report.",
        source: "deterministic",
        linkedTaskId: taskIds.wlanThreats,
        status: "accepted"
      },
      {
        id: "seed-plan-block-6",
        startAt: new Date("2026-07-24T12:30:00.000Z"),
        endAt: new Date("2026-07-24T14:30:00.000Z"),
        moduleId: moduleIds.algorithms,
        topicId: topicIds.sorting,
        objective: "Implement and benchmark two sorting algorithms",
        recommendedMethod: "Incremental implementation followed by timed test cases",
        breakMinutes: 15,
        priority: "high",
        reason: "Starting the algorithms coursework early reduces deadline overlap.",
        source: "deterministic",
        linkedTaskId: taskIds.sortingImplementation,
        status: "accepted"
      }
    ],
    maxDailyMinutes: 240,
    isAccepted: true,
    rationale:
      "Prioritises the urgent Wireless Networks report while preserving focused progress on the Mento portfolio and Algorithms coursework.",
    unplannedMinutes: {},
    schemaVersion: 1
  }),

  document("aiConversations", "seed-20260717-conversation-priorities", {
    title: "Priorities across my current modules",
    messages: [
      {
        role: "user",
        content: "What should I focus on first across my three modules?",
        createdAt: new Date("2026-07-17T01:05:00.000Z"),
        actions: []
      },
      {
        role: "assistant",
        content:
          "Start with the Secure campus WLAN design report because it is due first on 29 July. Next, finish the Mento authentication, Maps fallback and AI evidence for the mobile portfolio due 3 August. Keep one smaller Algorithms block this week so the 10 August coursework does not become compressed.",
        createdAt: new Date("2026-07-17T01:05:20.000Z"),
        disclaimer:
          "This plan uses the current modules and deadlines stored in Mento.",
        actions: []
      }
    ],
    executedActionIds: [],
    provider: "seeded-example",
    archived: false
  })
];

function toFirestoreFields(value) {
  return Object.fromEntries(
    Object.entries(value)
      .filter(([, item]) => item !== undefined)
      .map(([key, item]) => [key, toFirestoreValue(item)])
  );
}

function toFirestoreValue(value) {
  if (value === null) return { nullValue: null };
  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) {
      throw new Error("Seed data contains an invalid timestamp.");
    }
    return { timestampValue: value.toISOString() };
  }
  if (Array.isArray(value)) {
    return {
      arrayValue: { values: value.map((item) => toFirestoreValue(item)) }
    };
  }
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (typeof value === "object") {
    return { mapValue: { fields: toFirestoreFields(value) } };
  }
  throw new Error(`Unsupported seed value type: ${typeof value}`);
}

function fromFirestoreFields(fields = {}) {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [
      key,
      fromFirestoreValue(value)
    ])
  );
}

function fromFirestoreValue(value) {
  if ("nullValue" in value) return null;
  if ("stringValue" in value) return value.stringValue;
  if ("booleanValue" in value) return value.booleanValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return value.doubleValue;
  if ("timestampValue" in value) return value.timestampValue;
  if ("arrayValue" in value) {
    return (value.arrayValue.values ?? []).map(fromFirestoreValue);
  }
  if ("mapValue" in value) {
    return fromFirestoreFields(value.mapValue.fields ?? {});
  }
  return undefined;
}

async function requestJson(url, accessToken, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      ...(options.body === undefined
        ? {}
        : { "Content-Type": "application/json" }),
      ...options.headers
    }
  });
  const text = await response.text();
  const body = text === "" ? {} : JSON.parse(text);
  if (!response.ok) {
    const code = body?.error?.status ?? response.status;
    throw new Error(`Firestore request failed (${code}).`);
  }
  return body;
}

async function listCollection(collection, accessToken) {
  const documents = [];
  let pageToken;
  do {
    const url = new URL(
      `${apiRoot}/users/${targetUid}/${collection}`
    );
    url.searchParams.set("pageSize", "300");
    if (pageToken !== undefined) {
      url.searchParams.set("pageToken", pageToken);
    }
    const body = await requestJson(url, accessToken);
    documents.push(...(body.documents ?? []));
    pageToken = body.nextPageToken;
  } while (pageToken !== undefined);
  return documents;
}

async function accessToken() {
  const refreshToken = configstore.get("tokens.refresh_token");
  if (typeof refreshToken !== "string" || refreshToken.length === 0) {
    throw new Error("Firebase CLI is not authenticated.");
  }
  const token = await firebaseAuth.getAccessToken(refreshToken, []);
  if (typeof token?.access_token !== "string") {
    throw new Error("Firebase CLI did not return an access token.");
  }
  return token.access_token;
}

function documentId(documentName) {
  return documentName.split("/").at(-1);
}

async function verifyTarget(token) {
  const authLookup = await requestJson(
    `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:lookup`,
    token,
    {
      method: "POST",
      body: JSON.stringify({ localId: [targetUid] })
    }
  );
  const authUser = authLookup.users?.[0];
  if (
    authUser?.localId !== targetUid ||
    authUser?.email?.toLowerCase() !== targetEmail
  ) {
    throw new Error("Target Auth UID/email verification failed; no write made.");
  }

  const user = await requestJson(
    `${apiRoot}/users/${targetUid}`,
    token
  );
  const userData = fromFirestoreFields(user.fields);
  if (userData?.uid !== targetUid) {
    throw new Error("Target Firestore user verification failed; no write made.");
  }

  const modules = await listCollection("modules", token);
  const actualModules = new Map(
    modules.map((item) => [
      documentId(item.name),
      fromFirestoreFields(item.fields).name
    ])
  );
  for (const [id, name] of expectedModules) {
    if (actualModules.get(id) !== name) {
      throw new Error(
        `Expected module ${id} (${name}) was not found; no write made.`
      );
    }
  }
}

function collectionCounts(documents) {
  const counts = {};
  for (const item of documents) {
    counts[item.collection] = (counts[item.collection] ?? 0) + 1;
  }
  return counts;
}

async function main() {
  const duplicateNames = seedDocuments
    .map((item) => `${item.collection}/${item.id}`)
    .filter((name, index, values) => values.indexOf(name) !== index);
  if (duplicateNames.length > 0) {
    throw new Error(`Duplicate seed IDs: ${duplicateNames.join(", ")}`);
  }

  const token = await accessToken();
  await verifyTarget(token);

  const collections = [...new Set(seedDocuments.map((item) => item.collection))];
  const existingByCollection = new Map();
  for (const collection of collections) {
    const existing = await listCollection(collection, token);
    existingByCollection.set(
      collection,
      new Set(existing.map((item) => documentId(item.name)))
    );
  }

  const pending = seedDocuments.filter(
    (item) => !existingByCollection.get(item.collection).has(item.id)
  );
  const skipped = seedDocuments.length - pending.length;

  if (!apply) {
    console.log(
      JSON.stringify(
        {
          mode: "dry-run",
          projectId,
          targetUid,
          targetEmail,
          planned: seedDocuments.length,
          wouldCreate: pending.length,
          wouldSkipExisting: skipped,
          byCollection: collectionCounts(seedDocuments)
        },
        null,
        2
      )
    );
    return;
  }

  if (pending.length > 0) {
    const writes = pending.map((item) => ({
      update: {
        name:
          `${databaseRoot}/users/${targetUid}/` +
          `${item.collection}/${item.id}`,
        fields: toFirestoreFields(item.data)
      },
      currentDocument: { exists: false }
    }));
    const result = await requestJson(
      `https://firestore.googleapis.com/v1/${databaseRoot}:batchWrite`,
      token,
      {
        method: "POST",
        body: JSON.stringify({ writes })
      }
    );
    const failed = (result.status ?? []).filter(
      (status) => status.code !== undefined && status.code !== 0
    );
    if (failed.length > 0) {
      throw new Error(
        `Firestore rejected ${failed.length} seed write(s).`
      );
    }
  }

  const missing = [];
  const finalCounts = {};
  for (const collection of collections) {
    const current = await listCollection(collection, token);
    const ids = new Set(current.map((item) => documentId(item.name)));
    finalCounts[collection] = current.length;
    for (const item of seedDocuments.filter(
      (candidate) => candidate.collection === collection
    )) {
      if (!ids.has(item.id)) missing.push(`${collection}/${item.id}`);
    }
  }
  if (missing.length > 0) {
    throw new Error(`Seed verification missed: ${missing.join(", ")}`);
  }

  console.log(
    JSON.stringify(
      {
        mode: "applied",
        projectId,
        targetUid,
        targetEmail,
        created: pending.length,
        skippedExisting: skipped,
        verifiedSeedDocuments: seedDocuments.length,
        seededByCollection: collectionCounts(seedDocuments),
        finalCollectionCounts: finalCounts
      },
      null,
      2
    )
  );
}

await main();

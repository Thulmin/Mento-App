import { readFile } from "node:fs/promises";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment
} from "@firebase/rules-unit-testing";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc
} from "firebase/firestore";
import {
  afterAll,
  afterEach,
  beforeAll,
  describe,
  expect,
  it
} from "vitest";

const projectId = "demo-mento-rules";
const ownerUid = "owner-user";
const otherUid = "other-user";
let testEnvironment: RulesTestEnvironment;

beforeAll(async () => {
  const rules = await readFile("../firestore.rules", "utf8");
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: "127.0.0.1",
      port: 8088,
      rules
    }
  });
});

afterEach(async () => {
  await testEnvironment.clearFirestore();
});

afterAll(async () => {
  await testEnvironment.cleanup();
});

function ownerDb() {
  return testEnvironment.authenticatedContext(ownerUid).firestore();
}

function otherDb() {
  return testEnvironment.authenticatedContext(otherUid).firestore();
}

function unauthenticatedDb() {
  return testEnvironment.unauthenticatedContext().firestore();
}

async function createUser(uid = ownerUid): Promise<void> {
  const database = testEnvironment.authenticatedContext(uid).firestore();
  await assertSucceeds(
    setDoc(doc(database, "users", uid), {
      uid,
      profile: {
        preferredName: "Student",
        email: "student@example.test",
        photoUrl: null
      },
      preferences: {
        themeMode: "system",
        wellnessEnabled: true,
        publicAchievements: false,
        reducedMotion: false
      },
      onboardingComplete: false,
      termsAccepted: true,
      role: "student",
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp()
    })
  );
}

function moduleData(uid = ownerUid) {
  return {
    ownerId: uid,
    name: "Mobile Application Development",
    code: "CMP7003",
    semester: 2,
    colorValue: 4_282_076_152,
    lecturer: null,
    notes: null,
    priorityWeight: 1,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  };
}

function privateCollectionFixtures() {
  const start = Timestamp.fromDate(
    new Date("2026-07-15T09:00:00.000Z")
  );
  const end = Timestamp.fromDate(
    new Date("2026-07-15T10:00:00.000Z")
  );
  const due = Timestamp.fromDate(
    new Date("2026-07-20T12:00:00.000Z")
  );
  const audit = () => ({
    ownerId: ownerUid,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  });
  return [
    {
      collection: "topics",
      id: "topic-1",
      data: {
        ...audit(),
        moduleId: "module-1",
        name: "State management",
        mastery: 0.4,
        completedStudyMinutes: 30
      }
    },
    {
      collection: "timetableEvents",
      id: "event-1",
      data: {
        ...audit(),
        title: "Lecture",
        type: "lecture",
        startAt: start,
        endAt: end,
        recurrence: "none",
        recurringWeekdays: []
      }
    },
    {
      collection: "assignments",
      id: "assignment-1",
      data: {
        ...audit(),
        moduleId: "module-1",
        title: "Architecture report",
        dueAt: due,
        priority: "high",
        estimatedMinutes: 240,
        status: "inProgress",
        subtasks: [],
        manualProgress: 0.25,
        attachments: []
      }
    },
    {
      collection: "examinations",
      id: "exam-1",
      data: {
        ...audit(),
        moduleId: "module-1",
        title: "Final examination",
        startAt: start,
        endAt: end,
        syllabusTopicIds: ["topic-1"],
        importance: "urgent",
        preparationProgress: 0.3
      }
    },
    {
      collection: "studyTasks",
      id: "task-1",
      data: {
        ...audit(),
        title: "Review lecture notes",
        dueAt: due,
        estimatedMinutes: 45,
        priority: "medium",
        status: "notStarted",
        isAiGenerated: false,
        needsRescheduling: false
      }
    },
    {
      collection: "studyPlans",
      id: "plan-1",
      data: {
        ...audit(),
        userId: ownerUid,
        generatedAt: start,
        rangeStart: start,
        rangeEnd: due,
        source: "artificialIntelligence",
        blocks: [],
        maxDailyMinutes: 240,
        isAccepted: false,
        unplannedMinutes: {},
        schemaVersion: 1
      }
    },
    {
      collection: "studySessions",
      id: "session-1",
      data: {
        ...audit(),
        title: "Revision",
        startedAt: start,
        durationMinutes: 45,
        status: "completed"
      }
    },
    {
      collection: "focusSessions",
      id: "focus-1",
      data: {
        ...audit(),
        goal: "Draft the introduction",
        targetMinutes: 45,
        startedAt: start,
        state: "completed",
        accumulatedActiveSeconds: 2700,
        accumulatedPausedSeconds: 0,
        isBreak: false,
        interruptionCount: 0
      }
    },
    {
      collection: "habits",
      id: "habit-1",
      data: {
        ...audit(),
        name: "Take a movement break",
        category: "movement",
        frequency: "daily",
        weekdays: [],
        weeklyTarget: 7,
        reminderTimes: ["12:00"],
        isArchived: false
      }
    },
    {
      collection: "habitLogs",
      id: "habit-log-1",
      data: {
        ...audit(),
        habitId: "habit-1",
        date: start,
        loggedAt: start,
        isCompleted: true
      }
    },
    {
      collection: "wellnessCheckIns",
      id: "wellness-1",
      data: {
        ...audit(),
        recordedAt: start,
        mood: 4,
        energy: 3,
        sleepHours: 7.5
      }
    },
    {
      collection: "achievements",
      id: "achievement-1",
      data: {
        ...audit(),
        type: "firstTask",
        title: "First task",
        description: "Complete the first study task.",
        threshold: 1,
        pointsReward: 10,
        iconName: "task_alt",
        progress: 1
      }
    },
    {
      collection: "notificationPreferences",
      id: "default",
      data: {
        ...audit(),
        enabled: true,
        quietStartHour: 22,
        quietEndHour: 7,
        defaultLeadMinutes: 15,
        categories: { assignments: true }
      }
    },
    {
      collection: "aiConversations",
      id: "conversation-1",
      data: {
        ...audit(),
        title: "Weekly planning",
        messages: [
          { role: "user", content: "Help me plan this week." }
        ],
        executedActionIds: [],
        archived: false
      }
    },
    {
      collection: "topicMastery",
      id: "topic-1",
      data: {
        ...audit(),
        topicId: "topic-1",
        moduleId: "module-1",
        mastery: 0.5,
        studyMinutes: 90,
        completedTasks: 2
      }
    },
    {
      collection: "savedLocations",
      id: "location-1",
      data: {
        ...audit(),
        name: "University library",
        latitude: 6.9271,
        longitude: 79.8612,
        type: "library",
        isFavorite: true
      }
    }
  ];
}

describe("private user boundaries", () => {
  it("allows the authenticated owner to create and read their profile", async () => {
    await createUser();
    const snapshot = await assertSucceeds(
      getDoc(doc(ownerDb(), "users", ownerUid))
    );
    expect(snapshot.data()?.uid).toBe(ownerUid);
  });

  it("denies unauthenticated private reads", async () => {
    await createUser();
    await assertFails(
      getDoc(doc(unauthenticatedDb(), "users", ownerUid))
    );
  });

  it("denies cross-user reads and writes", async () => {
    await createUser();
    await assertSucceeds(
      setDoc(
        doc(ownerDb(), "users", ownerUid, "modules", "module-1"),
        moduleData()
      )
    );

    await assertFails(
      getDoc(
        doc(otherDb(), "users", ownerUid, "modules", "module-1")
      )
    );
    await assertFails(
      setDoc(
        doc(otherDb(), "users", ownerUid, "modules", "module-2"),
        moduleData(otherUid)
      )
    );
  });

  it("prevents role escalation while allowing normal profile updates", async () => {
    await createUser();
    await assertSucceeds(
      updateDoc(doc(ownerDb(), "users", ownerUid), {
        "profile.preferredName": "Updated Student",
        "profile.photoUrl": "https://example.test/custom-avatar.jpg",
        "profile.photoSource": "custom",
        "profile.customPhotoPath": `users/${ownerUid}/profile/avatar`,
        updatedAt: serverTimestamp()
      })
    );
    await assertFails(
      updateDoc(doc(ownerDb(), "users", ownerUid), {
        role: "admin",
        updatedAt: serverTimestamp()
      })
    );
    await assertFails(
      updateDoc(doc(ownerDb(), "users", ownerUid), {
        "profile.photoSource": "untrusted-provider",
        updatedAt: serverTimestamp()
      })
    );
  });
});

describe("collection-specific validation", () => {
  it.each(privateCollectionFixtures())(
    "accepts a valid $collection document",
    async ({ collection, id, data }) => {
      await assertSucceeds(
        setDoc(
          doc(ownerDb(), "users", ownerUid, collection, id),
          data
        )
      );
    }
  );

  it("allows valid owner CRUD and immutable server timestamps", async () => {
    const reference = doc(
      ownerDb(),
      "users",
      ownerUid,
      "modules",
      "module-1"
    );
    await assertSucceeds(setDoc(reference, moduleData()));
    await assertSucceeds(getDoc(reference));
    await assertSucceeds(
      updateDoc(reference, {
        name: "Advanced Mobile Applications",
        updatedAt: serverTimestamp()
      })
    );
    await assertFails(
      updateDoc(reference, {
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp()
      })
    );
    await assertSucceeds(deleteDoc(reference));
  });

  it("denies unknown fields and invalid field types", async () => {
    const invalidField = doc(
      ownerDb(),
      "users",
      ownerUid,
      "modules",
      "invalid-field"
    );
    await assertFails(
      setDoc(invalidField, {
        ...moduleData(),
        privateCredential: "must-not-be-stored"
      })
    );

    const invalidType = doc(
      ownerDb(),
      "users",
      ownerUid,
      "modules",
      "invalid-type"
    );
    await assertFails(
      setDoc(invalidType, {
        ...moduleData(),
        name: 42
      })
    );
  });

  it("denies ownership changes", async () => {
    const reference = doc(
      ownerDb(),
      "users",
      ownerUid,
      "modules",
      "module-1"
    );
    await assertSucceeds(setDoc(reference, moduleData()));
    await assertFails(
      updateDoc(reference, {
        ownerId: otherUid,
        updatedAt: serverTimestamp()
      })
    );
  });

  it("bounds synced assistant history and executed action IDs", async () => {
    const reference = doc(
      ownerDb(),
      "users",
      ownerUid,
      "aiConversations",
      "oversized-history"
    );
    await assertFails(
      setDoc(reference, {
        ownerId: ownerUid,
        title: "Oversized history",
        messages: Array.from({ length: 51 }, (_, index) => ({
          role: "user",
          content: `Message ${index}`
        })),
        executedActionIds: [],
        archived: false,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp()
      })
    );
    await assertFails(
      setDoc(reference, {
        ownerId: ownerUid,
        title: "Too many actions",
        messages: [],
        executedActionIds: Array.from(
          { length: 101 },
          (_, index) => `action-${index}`
        ),
        archived: false,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp()
      })
    );
  });

  it("denies writes to undeclared private collections", async () => {
    await assertFails(
      setDoc(
        doc(
          ownerDb(),
          "users",
          ownerUid,
          "unreviewedCollection",
          "document-1"
        ),
        {
          ownerId: ownerUid,
          updatedAt: serverTimestamp()
        }
      )
    );
  });
});

describe("public profile projection", () => {
  function publicProfile(discoverable: boolean) {
    return {
      uid: ownerUid,
      preferredName: "Student",
      institution: "Example University",
      course: "Computing",
      academicYear: 3,
      achievementCount: 4,
      points: 120,
      isDiscoverable: discoverable,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp()
    };
  }

  it("allows the approved discoverable projection to be read publicly", async () => {
    await assertSucceeds(
      setDoc(
        doc(ownerDb(), "publicProfiles", ownerUid),
        publicProfile(true)
      )
    );
    const snapshot = await assertSucceeds(
      getDoc(doc(unauthenticatedDb(), "publicProfiles", ownerUid))
    );
    expect(snapshot.data()?.preferredName).toBe("Student");
  });

  it("denies private fields in the public projection", async () => {
    await assertFails(
      setDoc(doc(ownerDb(), "publicProfiles", ownerUid), {
        ...publicProfile(true),
        email: "private@example.test"
      })
    );
  });

  it("keeps non-discoverable profiles private to their owner", async () => {
    await assertSucceeds(
      setDoc(
        doc(ownerDb(), "publicProfiles", ownerUid),
        publicProfile(false)
      )
    );
    await assertFails(
      getDoc(doc(unauthenticatedDb(), "publicProfiles", ownerUid))
    );
    await assertSucceeds(
      getDoc(doc(ownerDb(), "publicProfiles", ownerUid))
    );
  });

  it("denies another user changing or deleting a public profile", async () => {
    await assertSucceeds(
      setDoc(
        doc(ownerDb(), "publicProfiles", ownerUid),
        publicProfile(true)
      )
    );
    await assertFails(
      updateDoc(doc(otherDb(), "publicProfiles", ownerUid), {
        preferredName: "Attacker",
        updatedAt: serverTimestamp()
      })
    );
    await assertFails(
      deleteDoc(doc(otherDb(), "publicProfiles", ownerUid))
    );
  });
});

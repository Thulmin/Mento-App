import { readFile } from "node:fs/promises";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment
} from "@firebase/rules-unit-testing";
import type { RulesTestEnvironment } from "@firebase/rules-unit-testing";
import {
  afterAll,
  afterEach,
  beforeAll,
  describe,
  it
} from "vitest";

const projectId = "demo-mento-rules";
const bucket = `gs://${projectId}.appspot.com`;
const ownerUid = "owner-user";
const otherUid = "other-user";
const avatarPath = `users/${ownerUid}/profile/avatar`;
let testEnvironment: RulesTestEnvironment;

beforeAll(async () => {
  const rules = await readFile("../storage.rules", "utf8");
  testEnvironment = await initializeTestEnvironment({
    projectId,
    storage: {
      host: "127.0.0.1",
      port: 9199,
      rules
    }
  });
});

afterEach(async () => {
  await testEnvironment.clearStorage();
});

afterAll(async () => {
  await testEnvironment.cleanup();
});

function ownerStorage() {
  return testEnvironment.authenticatedContext(ownerUid).storage(bucket);
}

function otherStorage() {
  return testEnvironment.authenticatedContext(otherUid).storage(bucket);
}

function unauthenticatedStorage() {
  return testEnvironment.unauthenticatedContext().storage(bucket);
}

describe("profile photo storage boundaries", () => {
  it("allows owner upload, read, replacement, and deletion", async () => {
    const reference = ownerStorage().ref(avatarPath);
    await assertSucceeds(
      Promise.resolve(
        reference.put(Uint8Array.from([0xff, 0xd8, 0xff]), {
          contentType: "image/jpeg"
        })
      )
    );
    await assertSucceeds(reference.getMetadata());
    await assertSucceeds(
      Promise.resolve(
        reference.put(Uint8Array.from([0x89, 0x50, 0x4e, 0x47]), {
          contentType: "image/png"
        })
      )
    );
    await assertSucceeds(reference.delete());
  });

  it("denies unauthenticated and cross-user access", async () => {
    await assertFails(
      Promise.resolve(
        unauthenticatedStorage()
          .ref(avatarPath)
          .put(Uint8Array.from([0xff, 0xd8, 0xff]), {
            contentType: "image/jpeg"
          })
      )
    );
    await assertFails(
      Promise.resolve(
        otherStorage()
          .ref(avatarPath)
          .put(Uint8Array.from([0xff, 0xd8, 0xff]), {
            contentType: "image/jpeg"
          })
      )
    );
    await assertFails(otherStorage().ref(avatarPath).getMetadata());
  });

  it("denies unsupported types, oversized files, and undeclared paths", async () => {
    await assertFails(
      Promise.resolve(
        ownerStorage()
          .ref(avatarPath)
          .put(Uint8Array.from([0x47, 0x49, 0x46]), {
            contentType: "image/gif"
          })
      )
    );
    await assertFails(
      Promise.resolve(
        ownerStorage()
          .ref(avatarPath)
          .put(new Uint8Array(5 * 1024 * 1024 + 1), {
            contentType: "image/jpeg"
          })
      )
    );
    await assertFails(
      Promise.resolve(
        ownerStorage()
          .ref(`users/${ownerUid}/profile/other-file`)
          .put(Uint8Array.from([0xff, 0xd8, 0xff]), {
            contentType: "image/jpeg"
          })
      )
    );
  });
});

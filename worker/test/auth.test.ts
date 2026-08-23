import {
  generateKeyPair,
  SignJWT
} from "jose";
import { beforeAll, describe, expect, it } from "vitest";
import {
  verifyAppCheckToken,
  verifyFirebaseIdToken
} from "../src/auth";

const nowMs = Date.parse("2026-07-11T12:00:00.000Z");
const nowSeconds = Math.floor(nowMs / 1_000);
let privateKey: CryptoKey;
let publicKey: CryptoKey;
let otherPrivateKey: CryptoKey;

beforeAll(async () => {
  const primary = await generateKeyPair("RS256");
  const other = await generateKeyPair("RS256");
  privateKey = primary.privateKey;
  publicKey = primary.publicKey;
  otherPrivateKey = other.privateKey;
});

async function authToken(
  overrides: Readonly<Record<string, unknown>> = {},
  signingKey: CryptoKey = privateKey
): Promise<string> {
  return await new SignJWT({
    sub: "firebase-user",
    aud: "mento-project",
    iss: "https://securetoken.google.com/mento-project",
    iat: nowSeconds - 60,
    exp: nowSeconds + 3_600,
    auth_time: nowSeconds - 120,
    ...overrides
  })
    .setProtectedHeader({ alg: "RS256", kid: "test-key", typ: "JWT" })
    .sign(signingKey);
}

async function appCheckToken(
  overrides: Readonly<Record<string, unknown>> = {}
): Promise<string> {
  return await new SignJWT({
    sub: "1:123:android:app",
    aud: ["projects/123456"],
    iss: "https://firebaseappcheck.googleapis.com/123456",
    iat: nowSeconds - 30,
    exp: nowSeconds + 3_600,
    ...overrides
  })
    .setProtectedHeader({ alg: "RS256", kid: "test-key", typ: "JWT" })
    .sign(privateKey);
}

describe("Firebase JWT verification", () => {
  it("verifies signature and all required ID-token claims", async () => {
    const verified = await verifyFirebaseIdToken(await authToken(), {
      projectId: "mento-project",
      keyResolver: async () => publicKey,
      nowMs
    });

    expect(verified.uid).toBe("firebase-user");
  });

  it.each([
    ["expired", { exp: nowSeconds - 1 }],
    ["wrong audience", { aud: "another-project" }],
    ["wrong issuer", { iss: "https://example.invalid" }],
    ["empty subject", { sub: "" }],
    ["future authentication", { auth_time: nowSeconds + 60 }]
  ])("rejects an ID token with %s", async (_label, overrides) => {
    await expect(
      verifyFirebaseIdToken(await authToken(overrides), {
        projectId: "mento-project",
        keyResolver: async () => publicKey,
        nowMs
      })
    ).rejects.toThrow("token_verification_failed");
  });

  it("rejects an invalid ID-token signature", async () => {
    await expect(
      verifyFirebaseIdToken(await authToken({}, otherPrivateKey), {
        projectId: "mento-project",
        keyResolver: async () => publicKey,
        nowMs
      })
    ).rejects.toThrow("token_verification_failed");
  });

  it("verifies App Check signature, issuer, audience, expiry, and subject", async () => {
    const verified = await verifyAppCheckToken(await appCheckToken(), {
      projectNumber: "123456",
      allowedAppIds: new Set(["1:123:android:app"]),
      keyResolver: async () => publicKey,
      nowMs
    });

    expect(verified.appId).toBe("1:123:android:app");
  });

  it.each([
    ["expired", { exp: nowSeconds - 1 }],
    ["wrong audience", { aud: ["projects/999999"] }],
    ["wrong issuer", { iss: "https://example.invalid" }],
    ["empty subject", { sub: "" }]
  ])("rejects an App Check token with %s", async (_label, overrides) => {
    await expect(
      verifyAppCheckToken(await appCheckToken(overrides), {
        projectNumber: "123456",
        allowedAppIds: new Set(["1:123:android:app"]),
        keyResolver: async () => publicKey,
        nowMs
      })
    ).rejects.toThrow("token_verification_failed");
  });

  it("enforces the configured App Check application allowlist", async () => {
    await expect(
      verifyAppCheckToken(await appCheckToken(), {
        projectNumber: "123456",
        allowedAppIds: new Set(["another-app"]),
        keyResolver: async () => publicKey,
        nowMs
      })
    ).rejects.toThrow("token_verification_failed");
  });
});

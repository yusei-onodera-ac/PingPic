import { describe, it, expect } from "vitest";
import { respondToFriendRequest } from "./connections";

describe("respondToFriendRequest (smoke test)", () => {
  it("is exported as a defined Cloud Function", () => {
    // Module-load-only check, same rationale as the other smoke tests —
    // invoking this for real needs the Firestore emulator + an
    // authenticated callable context (firebase-functions-test), which is
    // a TODO across this whole test suite.
    expect(respondToFriendRequest).toBeDefined();
  });
});

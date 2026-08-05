import { describe, it, expect } from "vitest";
import { onLikeCreated, onLikeDeleted } from "./likes";

describe("like triggers (smoke test)", () => {
  it("are exported as defined Cloud Functions", () => {
    // Module-load-only check, same rationale as the other smoke tests —
    // invoking these for real needs the Firestore emulator, which is a
    // TODO across this whole test suite.
    expect(onLikeCreated).toBeDefined();
    expect(onLikeDeleted).toBeDefined();
  });
});

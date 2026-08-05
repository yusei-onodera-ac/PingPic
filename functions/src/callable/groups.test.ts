import { describe, it, expect } from "vitest";
import { createGroup, joinGroupByInviteCode } from "./groups";

describe("group callables (smoke test)", () => {
  it("are exported as defined Cloud Functions", () => {
    // Module-load-only check, same rationale as
    // scheduled/dailyBatchJob.test.ts — invoking these for real needs the
    // Firestore emulator + an authenticated callable context
    // (firebase-functions-test), which is a TODO.
    expect(createGroup).toBeDefined();
    expect(joinGroupByInviteCode).toBeDefined();
  });
});

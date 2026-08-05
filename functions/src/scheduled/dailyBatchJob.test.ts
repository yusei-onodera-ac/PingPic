import { describe, it, expect } from "vitest";
import { dailyBatchJob } from "./dailyBatchJob";

describe("dailyBatchJob (smoke test)", () => {
  it("is exported as a defined Cloud Function", () => {
    // This only proves the module loads and the export exists — it does
    // NOT invoke the handler (that needs the Firestore emulator wired via
    // firebase-functions-test, which is a TODO once real logic lands).
    expect(dailyBatchJob).toBeDefined();
  });
});

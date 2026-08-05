import { getFirestore, FieldValue } from "firebase-admin/firestore";
import type { PromptPoolEntry } from "@pingpic/shared-types";
import { getAdminApp } from "../config/firebaseAdmin";

/**
 * Picks a prompt_pool entry for the 00:00 auto-fill. Selection is uniform
 * random among whichever entries currently have the LOWEST usageCount —
 * a simple round-robin-ish fairness scheme so the pool cycles through
 * its stock rather than always reusing the same "first" entries.
 *
 * Cost note: reads the whole prompt_pool collection. Acceptable because
 * it's expected to stay a small curated stock list (tens-hundreds of
 * entries), not user-generated at scale — revisit with a query + limit()
 * if that assumption changes. See docs/ARCHITECTURE.md "Cost design".
 */
export async function pickRandomPopularPrompt(): Promise<{
  id: string;
  entry: PromptPoolEntry;
} | null> {
  const db = getFirestore(getAdminApp());
  const snap = await db.collection("prompt_pool").get();
  if (snap.empty) return null;

  const candidates = snap.docs.map((d) => ({
    id: d.id,
    entry: d.data() as PromptPoolEntry,
  }));
  const minUsage = Math.min(...candidates.map((c) => c.entry.usageCount ?? 0));
  const leastUsed = candidates.filter((c) => (c.entry.usageCount ?? 0) === minUsage);
  return leastUsed[Math.floor(Math.random() * leastUsed.length)];
}

/** Increments usageCount on the entry the batch job just used, for
 * admin-panel visibility into which pool prompts get reused most. */
export async function incrementUsageCount(entryId: string): Promise<void> {
  const db = getFirestore(getAdminApp());
  await db
    .collection("prompt_pool")
    .doc(entryId)
    .update({ usageCount: FieldValue.increment(1) });
}

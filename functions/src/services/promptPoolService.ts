import { getFirestore } from "firebase-admin/firestore";
import type { PromptPoolEntry } from "@pingpic/shared-types";
import { getAdminApp } from "../config/firebaseAdmin";

/**
 * TODO: implement real selection logic (e.g. weighted by low usage_count to
 * cycle through the pool rather than always picking the same "popular"
 * entries, or random pick). This scaffold only proves the read path works.
 *
 * Cost note: this reads the whole prompt_pool collection today because it's
 * expected to stay small (a curated stock list, not user-generated at
 * scale). Revisit with a query + limit() if the pool grows large.
 */
export async function pickRandomPopularPrompt(): Promise<{
  id: string;
  entry: PromptPoolEntry;
} | null> {
  const db = getFirestore(getAdminApp());
  const snap = await db.collection("prompt_pool").get();
  if (snap.empty) return null;

  throw new Error(
    `pickRandomPopularPrompt: selection logic not implemented — scaffold stub. ` +
      `${snap.size} candidate entries available.`
  );
}

/**
 * TODO: implement. Increments usage_count on the entry the batch job just
 * used, for admin-panel visibility into which pool prompts get reused most.
 */
export async function incrementUsageCount(entryId: string): Promise<void> {
  throw new Error(
    `incrementUsageCount: not implemented — scaffold stub. entryId=${entryId}`
  );
}

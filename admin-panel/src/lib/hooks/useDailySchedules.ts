"use client";

import { useEffect, useState } from "react";
import { collection, onSnapshot, query, where, documentId } from "firebase/firestore";
import type { DailySchedule } from "@pingpic/shared-types";
import { db } from "../firebase/client";

/**
 * Subscribes to daily_schedules docs whose id (doc id = "YYYY-MM-DD") falls
 * within [startDateId, endDateId] inclusive. Firestore doc-id range queries
 * sort lexicographically, which matches YYYY-MM-DD's natural chronological
 * order, so this works without a denormalized date field.
 *
 * Missing documents (a date nobody has touched yet) simply don't appear in
 * `schedules` — callers should treat an absent key the same as
 * `{ slots: [null, null, null] }`, matching the DailySchedule type's note.
 */
export function useDailySchedules(startDateId: string, endDateId: string) {
  const [schedules, setSchedules] = useState<Record<string, DailySchedule>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setLoading(true);
    const q = query(
      collection(db, "daily_schedules"),
      where(documentId(), ">=", startDateId),
      where(documentId(), "<=", endDateId)
    );
    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        const next: Record<string, DailySchedule> = {};
        snapshot.forEach((docSnap) => {
          next[docSnap.id] = docSnap.data() as DailySchedule;
        });
        setSchedules(next);
        setLoading(false);
        setError(null);
      },
      (err) => {
        setError(err.message);
        setLoading(false);
      }
    );
    return unsubscribe;
  }, [startDateId, endDateId]);

  return { schedules, loading, error };
}

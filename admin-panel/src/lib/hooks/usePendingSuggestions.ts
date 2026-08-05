"use client";

import { useEffect, useState } from "react";
import { collection, onSnapshot, query, where, orderBy } from "firebase/firestore";
import type { PromptSuggestion } from "@pingpic/shared-types";
import { db } from "../firebase/client";

export interface SuggestionRow {
  id: string;
  suggestion: PromptSuggestion;
}

export function usePendingSuggestions() {
  const [rows, setRows] = useState<SuggestionRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const q = query(
      collection(db, "prompt_suggestions"),
      where("status", "==", "pending"),
      orderBy("createdAt", "asc")
    );
    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        setRows(snapshot.docs.map((d) => ({ id: d.id, suggestion: d.data() as PromptSuggestion })));
        setLoading(false);
        setError(null);
      },
      (err) => {
        setError(err.message);
        setLoading(false);
      }
    );
    return unsubscribe;
  }, []);

  return { rows, loading, error };
}

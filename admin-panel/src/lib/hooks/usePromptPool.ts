"use client";

import { useEffect, useState } from "react";
import { collection, onSnapshot, orderBy, query } from "firebase/firestore";
import type { PromptPoolEntry } from "@pingpic/shared-types";
import { db } from "../firebase/client";

export interface PromptPoolRow {
  id: string;
  entry: PromptPoolEntry;
}

export function usePromptPool() {
  const [rows, setRows] = useState<PromptPoolRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const q = query(collection(db, "prompt_pool"), orderBy("usageCount", "asc"));
    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        setRows(snapshot.docs.map((d) => ({ id: d.id, entry: d.data() as PromptPoolEntry })));
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

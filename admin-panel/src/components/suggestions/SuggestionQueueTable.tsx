"use client";

import { useState } from "react";
import { doc, updateDoc } from "firebase/firestore";
import { db } from "@/lib/firebase/client";
import { usePendingSuggestions, type SuggestionRow } from "@/lib/hooks/usePendingSuggestions";
import { AdoptSuggestionDialog } from "./AdoptSuggestionDialog";

export function SuggestionQueueTable() {
  const { rows, loading, error } = usePendingSuggestions();
  const [adopting, setAdopting] = useState<SuggestionRow | null>(null);
  const [rejectingId, setRejectingId] = useState<string | null>(null);

  if (loading) return <p style={{ color: "#888" }}>読み込み中…</p>;
  if (error) return <p style={{ color: "crimson" }}>読み込みエラー: {error}</p>;

  if (rows.length === 0) {
    return <p style={{ color: "#888" }}>保留中のお題提案はありません。</p>;
  }

  async function handleReject(id: string) {
    setRejectingId(id);
    try {
      await updateDoc(doc(db, "prompt_suggestions", id), { status: "rejected" });
      // onSnapshot in usePendingSuggestions picks up the removal automatically.
    } finally {
      setRejectingId(null);
    }
  }

  return (
    <>
      <table>
        <thead>
          <tr>
            <th>提案</th>
            <th>提案者</th>
            <th />
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.id}>
              <td>{row.suggestion.suggestionText}</td>
              <td>{row.suggestion.submitterInfo.displayName}</td>
              <td style={{ display: "flex", gap: 8 }}>
                <button onClick={() => setAdopting(row)}>採用</button>
                <button onClick={() => handleReject(row.id)} disabled={rejectingId === row.id}>
                  却下
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {adopting && (
        <AdoptSuggestionDialog
          row={adopting}
          onClose={() => setAdopting(null)}
          onAdopted={() => {
            /* onSnapshot in usePendingSuggestions picks up the status
             * change automatically — nothing else to do here. */
          }}
        />
      )}
    </>
  );
}

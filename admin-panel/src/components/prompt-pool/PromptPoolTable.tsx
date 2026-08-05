"use client";

import { useState } from "react";
import { addDoc, collection, deleteDoc, doc, serverTimestamp } from "firebase/firestore";
import { db } from "@/lib/firebase/client";
import { usePromptPool } from "@/lib/hooks/usePromptPool";

export function PromptPoolTable() {
  const { rows, loading, error } = usePromptPool();
  const [newText, setNewText] = useState("");
  const [adding, setAdding] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  async function handleAdd(e: React.FormEvent) {
    e.preventDefault();
    const text = newText.trim();
    if (!text) return;
    setAdding(true);
    try {
      await addDoc(collection(db, "prompt_pool"), {
        promptText: text,
        usageCount: 0,
        createdAt: serverTimestamp(),
      });
      setNewText("");
    } finally {
      setAdding(false);
    }
  }

  async function handleDelete(id: string) {
    setDeletingId(id);
    try {
      await deleteDoc(doc(db, "prompt_pool", id));
    } finally {
      setDeletingId(null);
    }
  }

  return (
    <div>
      <form onSubmit={handleAdd} style={{ display: "flex", gap: 8, marginBottom: 16 }}>
        <input
          type="text"
          placeholder="新しいお題テキスト"
          value={newText}
          onChange={(e) => setNewText(e.target.value)}
          style={{ flex: 1 }}
        />
        <button type="submit" disabled={adding || !newText.trim()}>
          + 追加
        </button>
      </form>

      {loading && <p style={{ color: "#888" }}>読み込み中…</p>}
      {error && <p style={{ color: "crimson" }}>読み込みエラー: {error}</p>}
      {!loading && rows.length === 0 && <p style={{ color: "#888" }}>ストックは空です。</p>}
      {rows.length > 0 && (
        <table>
          <thead>
            <tr>
              <th>お題</th>
              <th>使用回数</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {rows.map(({ id, entry }) => (
              <tr key={id}>
                <td>{entry.promptText}</td>
                <td>{entry.usageCount}</td>
                <td>
                  <button onClick={() => handleDelete(id)} disabled={deletingId === id}>
                    削除
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}

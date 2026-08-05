"use client";

import type { PromptPoolEntry } from "@pingpic/shared-types";

/**
 * TODO: implement CRUD against the prompt_pool collection (add/edit/delete
 * entries). Returning [] for now so the page renders without crashing.
 */
function usePromptPool(): Array<{ id: string; entry: PromptPoolEntry }> {
  return [];
}

export function PromptPoolTable() {
  const entries = usePromptPool();

  return (
    <div>
      <button disabled title="TODO: add-entry form">
        + 追加
      </button>
      {entries.length === 0 ? (
        <p style={{ color: "#888" }}>ストックは空です。(TODO: Firestore query not yet wired)</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th>お題</th>
              <th>使用回数</th>
            </tr>
          </thead>
          <tbody>
            {entries.map(({ id, entry }) => (
              <tr key={id}>
                <td>{entry.promptText}</td>
                <td>{entry.usageCount}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}

"use client";

import type { PromptSuggestion } from "@pingpic/shared-types";

/**
 * TODO: implement. Should query prompt_suggestions where status == "pending",
 * ordered by createdAt, and render an "採用" (adopt) button per row that
 * opens a slot picker to place it into a calendar date/slot (setting
 * credit to { type: "user", ... } and status to "approved").
 * Returning [] for now so the page renders without crashing.
 */
function usePendingSuggestions(): Array<{ id: string; suggestion: PromptSuggestion }> {
  return [];
}

export function SuggestionQueueTable() {
  const pending = usePendingSuggestions();

  if (pending.length === 0) {
    return <p style={{ color: "#888" }}>保留中のお題提案はありません。(TODO: Firestore query not yet wired)</p>;
  }

  return (
    <table>
      <thead>
        <tr>
          <th>提案</th>
          <th>提案者</th>
          <th />
        </tr>
      </thead>
      <tbody>
        {pending.map(({ id, suggestion }) => (
          <tr key={id}>
            <td>{suggestion.suggestionText}</td>
            <td>{suggestion.submitterInfo.displayName}</td>
            <td>
              <button disabled title="TODO: adopt-into-slot flow">
                採用
              </button>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

"use client";

import { useState } from "react";
import { doc, setDoc, Timestamp } from "firebase/firestore";
import type { DailySchedule, ScheduleSlot, PromptCredit } from "@pingpic/shared-types";
import { validateSendTimes, timestampToDate } from "@pingpic/shared-types";
import { db } from "@/lib/firebase/client";
import { jstDateFromParts, toJstTimeInputValue } from "@/lib/dateId";

interface Props {
  dateId: string; // "YYYY-MM-DD"
  schedule: DailySchedule | null;
  onClose: () => void;
}

interface SlotDraft {
  /** Empty string = not configured. */
  promptText: string;
  /** "HH:MM", empty string = not set. */
  time: string;
  /** Preserved from whatever was already there (e.g. a suggestion adopted
   * via the suggestions queue) — this modal only edits text/time, not who
   * gets credited. */
  credit: PromptCredit;
}

function draftFromSlot(slot: ScheduleSlot | null): SlotDraft {
  if (!slot) return { promptText: "", time: "", credit: { type: "admin" } };
  return {
    promptText: slot.promptText,
    time: toJstTimeInputValue(timestampToDate(slot.sendTime)),
    credit: slot.credit,
  };
}

export function SlotEditorModal({ dateId, schedule, onClose }: Props) {
  const [drafts, setDrafts] = useState<[SlotDraft, SlotDraft, SlotDraft]>(() => [
    draftFromSlot(schedule?.slots?.[0] ?? null),
    draftFromSlot(schedule?.slots?.[1] ?? null),
    draftFromSlot(schedule?.slots?.[2] ?? null),
  ]);
  const [problems, setProblems] = useState<string[]>([]);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  function updateDraft(index: number, patch: Partial<SlotDraft>) {
    setDrafts((prev) => {
      const next = [...prev] as [SlotDraft, SlotDraft, SlotDraft];
      next[index] = { ...next[index], ...patch };
      return next;
    });
  }

  async function handleSave() {
    setSaveError(null);

    // A slot only counts as "configured" once both promptText and time
    // are filled in — a slot with just one of the two set is treated as
    // an in-progress edit, not saved as a real slot (left null so the
    // 00:00 batch job still auto-fills it if the admin never finishes).
    const configured = drafts.map((d) => (d.promptText.trim() && d.time ? d : null));

    const times = configured.map((d) => {
      if (!d) return null;
      const [h, m] = d.time.split(":").map(Number);
      return { hour: h, minute: m };
    });
    const validationProblems = validateSendTimes(times);
    if (validationProblems.length > 0) {
      setProblems(validationProblems);
      return;
    }
    setProblems([]);

    const slots = configured.map((d): ScheduleSlot | null => {
      if (!d) return null;
      return {
        sendTime: Timestamp.fromDate(jstDateFromParts(dateId, d.time)),
        promptText: d.promptText.trim(),
        credit: d.credit,
      };
    }) as [ScheduleSlot | null, ScheduleSlot | null, ScheduleSlot | null];

    setSaving(true);
    try {
      await setDoc(doc(db, "daily_schedules", dateId), { slots }, { merge: true });
      onClose();
    } catch (err) {
      setSaveError(err instanceof Error ? err.message : "保存に失敗しました");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div
      role="dialog"
      aria-label={`Edit schedule for ${dateId}`}
      style={{
        position: "fixed",
        inset: 0,
        background: "rgba(0,0,0,0.4)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
      }}
      onClick={onClose}
    >
      <div
        style={{ background: "white", padding: 24, borderRadius: 8, minWidth: 420, maxWidth: 560 }}
        onClick={(e) => e.stopPropagation()}
      >
        <h2>{dateId}</h2>
        {drafts.map((draft, i) => (
          <div key={i} style={{ marginBottom: 16, paddingBottom: 16, borderBottom: "1px solid #eee" }}>
            <strong>スロット{i + 1}</strong>{" "}
            <span style={{ fontSize: 12, color: "#888" }}>
              {draft.credit.type === "admin" ? "運営考案" : `${draft.credit.displayName}さん考案`}
            </span>
            <div style={{ display: "flex", gap: 8, marginTop: 8 }}>
              <input
                type="time"
                value={draft.time}
                onChange={(e) => updateDraft(i, { time: e.target.value })}
                style={{ width: 110 }}
              />
              <input
                type="text"
                placeholder="お題テキスト"
                value={draft.promptText}
                onChange={(e) => updateDraft(i, { promptText: e.target.value })}
                style={{ flex: 1 }}
              />
            </div>
          </div>
        ))}

        {problems.length > 0 && (
          <ul style={{ color: "crimson" }}>
            {problems.map((p) => (
              <li key={p}>{p}</li>
            ))}
          </ul>
        )}
        {saveError && <p style={{ color: "crimson" }}>{saveError}</p>}

        <div style={{ display: "flex", gap: 8, justifyContent: "flex-end" }}>
          <button onClick={onClose} disabled={saving}>
            キャンセル
          </button>
          <button onClick={handleSave} disabled={saving}>
            {saving ? "保存中…" : "保存"}
          </button>
        </div>
      </div>
    </div>
  );
}

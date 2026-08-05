"use client";

import { useEffect, useState } from "react";
import { doc, getDoc, runTransaction, Timestamp } from "firebase/firestore";
import type { DailySchedule, ScheduleSlot, SlotNumber } from "@pingpic/shared-types";
import { validateSendTimes, timestampToDate } from "@pingpic/shared-types";
import { db } from "@/lib/firebase/client";
import { toDateId, jstDateFromParts, toJstTimeInputValue, jstHourMinute } from "@/lib/dateId";
import type { SuggestionRow } from "@/lib/hooks/usePendingSuggestions";

interface Props {
  row: SuggestionRow;
  onClose: () => void;
  onAdopted: () => void;
}

/**
 * Lets an admin place a pending suggestion into a specific date/slot,
 * crediting it "○○さん考案" per the design doc, and marks the suggestion
 * approved. Writes both documents in one Firestore transaction so a
 * suggestion never ends up "approved" without actually being scheduled
 * (or vice versa).
 *
 * If the target slot already has a send time set (from a prior admin edit
 * or a previous auto-fill), that time is kept — this dialog only lets the
 * admin pick a NEW time when the target slot is currently empty, to avoid
 * silently invalidating whatever the admin already arranged for that day.
 */
export function AdoptSuggestionDialog({ row, onClose, onAdopted }: Props) {
  const [dateId, setDateId] = useState(() => toDateId(new Date()));
  const [slotNumber, setSlotNumber] = useState<SlotNumber>(1);
  const [existingSchedule, setExistingSchedule] = useState<DailySchedule | null>(null);
  const [newTime, setNewTime] = useState("");
  const [loadingDay, setLoadingDay] = useState(false);
  const [problems, setProblems] = useState<string[]>([]);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setLoadingDay(true);
    getDoc(doc(db, "daily_schedules", dateId)).then((snap) => {
      if (cancelled) return;
      setExistingSchedule(snap.exists() ? (snap.data() as DailySchedule) : null);
      setLoadingDay(false);
    });
    return () => {
      cancelled = true;
    };
  }, [dateId]);

  const targetSlot = existingSchedule?.slots?.[slotNumber - 1] ?? null;
  const needsNewTime = !targetSlot;

  async function handleConfirm() {
    setSaveError(null);

    let sendTime: Date;
    if (targetSlot) {
      sendTime = timestampToDate(targetSlot.sendTime);
    } else {
      if (!newTime) {
        setProblems(["この枠にはまだ時刻が設定されていません。時刻を入力してください。"]);
        return;
      }
      const [h, m] = newTime.split(":").map(Number);
      const siblingTimes = (existingSchedule?.slots ?? [null, null, null]).map((s, i) =>
        i === slotNumber - 1 || !s ? null : jstHourMinute(timestampToDate(s.sendTime))
      );
      const allTimes = [...siblingTimes];
      allTimes[slotNumber - 1] = { hour: h, minute: m };
      const validationProblems = validateSendTimes(allTimes);
      if (validationProblems.length > 0) {
        setProblems(validationProblems);
        return;
      }
      sendTime = jstDateFromParts(dateId, newTime);
    }
    setProblems([]);

    const newSlot: ScheduleSlot = {
      sendTime: Timestamp.fromDate(sendTime),
      promptText: row.suggestion.suggestionText,
      credit: { type: "user", uid: row.suggestion.submitterInfo.uid, displayName: row.suggestion.submitterInfo.displayName },
    };

    setSaving(true);
    try {
      await runTransaction(db, async (tx) => {
        const scheduleRef = doc(db, "daily_schedules", dateId);
        const suggestionRef = doc(db, "prompt_suggestions", row.id);
        const scheduleSnap = await tx.get(scheduleRef);
        const current = scheduleSnap.exists()
          ? (scheduleSnap.data() as DailySchedule)
          : ({ slots: [null, null, null] } as DailySchedule);
        const slots = [...current.slots] as [ScheduleSlot | null, ScheduleSlot | null, ScheduleSlot | null];
        slots[slotNumber - 1] = newSlot;
        tx.set(scheduleRef, { slots }, { merge: true });
        tx.update(suggestionRef, { status: "approved" });
      });
      onAdopted();
      onClose();
    } catch (err) {
      setSaveError(err instanceof Error ? err.message : "採用処理に失敗しました");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div
      role="dialog"
      aria-label="Adopt suggestion"
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
        style={{ background: "white", padding: 24, borderRadius: 8, minWidth: 360 }}
        onClick={(e) => e.stopPropagation()}
      >
        <h2>お題を採用</h2>
        <p>「{row.suggestion.suggestionText}」— {row.suggestion.submitterInfo.displayName}さん考案</p>

        <label style={{ display: "block", marginBottom: 8 }}>
          日付
          <input type="date" value={dateId} onChange={(e) => setDateId(e.target.value)} />
        </label>
        <label style={{ display: "block", marginBottom: 8 }}>
          スロット
          <select
            value={slotNumber}
            onChange={(e) => setSlotNumber(Number(e.target.value) as SlotNumber)}
          >
            <option value={1}>1</option>
            <option value={2}>2</option>
            <option value={3}>3</option>
          </select>
        </label>

        {loadingDay && <p style={{ color: "#888" }}>この日の予定を確認中…</p>}
        {!loadingDay && targetSlot && (
          <p style={{ color: "#888" }}>
            この枠は既に {toJstTimeInputValue(timestampToDate(targetSlot.sendTime))} に設定されています
            — 時刻はそのまま、お題テキストのみ置き換えます。
          </p>
        )}
        {!loadingDay && needsNewTime && (
          <label style={{ display: "block", marginBottom: 8 }}>
            送信時刻 (07:00〜22:00、他の枠と4時間以上離してください)
            <input type="time" value={newTime} onChange={(e) => setNewTime(e.target.value)} />
          </label>
        )}

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
          <button onClick={handleConfirm} disabled={saving || loadingDay}>
            {saving ? "処理中…" : "採用する"}
          </button>
        </div>
      </div>
    </div>
  );
}

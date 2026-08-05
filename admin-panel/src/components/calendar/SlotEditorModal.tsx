"use client";

import type { DailySchedule } from "@pingpic/shared-types";

interface Props {
  dateId: string; // "YYYY-MM-DD"
  schedule: DailySchedule | null;
  onClose: () => void;
}

/**
 * TODO: implement real editing UX — per-slot sendTime picker (respecting
 * the 07:00-22:00 / >=4h-apart rule client-side too, as a UX nicety; the
 * server-side batch job is the real enforcement point), promptText input,
 * and save-to-Firestore wiring. This scaffold only proves the modal opens
 * with the right date context.
 */
export function SlotEditorModal({ dateId, schedule, onClose }: Props) {
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
        style={{ background: "white", padding: 24, borderRadius: 8, minWidth: 320 }}
        onClick={(e) => e.stopPropagation()}
      >
        <h2>{dateId}</h2>
        <p>{schedule ? `${schedule.slots.length} slots configured` : "No schedule set yet"}</p>
        <p style={{ color: "#888" }}>TODO: slot editor form (sendTime, promptText, credit)</p>
        <button onClick={onClose}>Close</button>
      </div>
    </div>
  );
}

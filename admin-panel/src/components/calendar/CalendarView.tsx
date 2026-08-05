"use client";

import { useMemo, useState } from "react";
import FullCalendar from "@fullcalendar/react";
import dayGridPlugin from "@fullcalendar/daygrid";
import type { DatesSetArg } from "@fullcalendar/core";
import { useDailySchedules } from "@/lib/hooks/useDailySchedules";
import { toDateId } from "@/lib/dateId";
import { SlotEditorModal } from "./SlotEditorModal";

export function CalendarView() {
  const [selectedDate, setSelectedDate] = useState<string | null>(null);
  const [visibleRange, setVisibleRange] = useState<{ start: string; end: string }>(() => {
    const now = new Date();
    return { start: toDateId(now), end: toDateId(now) };
  });

  const { schedules, loading, error } = useDailySchedules(visibleRange.start, visibleRange.end);

  const events = useMemo(
    () =>
      Object.entries(schedules).flatMap(([dateId, schedule]) =>
        (schedule.slots ?? [])
          .map((slot, i) => (slot ? { id: `${dateId}-${i}`, title: slot.promptText, date: dateId } : null))
          .filter((e): e is { id: string; title: string; date: string } => e !== null)
      ),
    [schedules]
  );

  function handleDatesSet(arg: DatesSetArg) {
    // FullCalendar's month grid includes leading/trailing days from
    // adjacent months — query that full visible range, not just the
    // calendar month, so those cells show real data too.
    setVisibleRange({ start: toDateId(arg.start), end: toDateId(arg.end) });
  }

  return (
    <div>
      {loading && <p style={{ color: "#888" }}>読み込み中…</p>}
      {error && <p style={{ color: "crimson" }}>読み込みエラー: {error}</p>}
      <FullCalendar
        plugins={[dayGridPlugin]}
        initialView="dayGridMonth"
        events={events}
        datesSet={handleDatesSet}
        dateClick={(info) => setSelectedDate(info.dateStr)}
        height="auto"
      />
      {selectedDate && (
        <SlotEditorModal
          dateId={selectedDate}
          schedule={schedules[selectedDate] ?? null}
          onClose={() => setSelectedDate(null)}
        />
      )}
    </div>
  );
}

"use client";

import { useState } from "react";
import FullCalendar from "@fullcalendar/react";
import dayGridPlugin from "@fullcalendar/daygrid";
import type { DailySchedule } from "@pingpic/shared-types";
import { SlotEditorModal } from "./SlotEditorModal";

/**
 * TODO: implement. Should query daily_schedules for the visible month range
 * and return { [dateId: string]: DailySchedule }. Returning an empty object
 * for now so CalendarView renders (with no events) rather than crashing.
 */
function useDailySchedules(_monthStart: Date, _monthEnd: Date): Record<string, DailySchedule> {
  return {};
}

export function CalendarView() {
  const [selectedDate, setSelectedDate] = useState<string | null>(null);
  // TODO: derive real month range from FullCalendar's datesSet callback
  const schedules = useDailySchedules(new Date(), new Date());

  const events = Object.entries(schedules).flatMap(([dateId, schedule]) =>
    schedule.slots.map((slot, i) => ({
      id: `${dateId}-${i}`,
      title: slot.promptText,
      date: dateId,
    }))
  );

  return (
    <div>
      <FullCalendar
        plugins={[dayGridPlugin]}
        initialView="dayGridMonth"
        events={events}
        dateClick={(info) => setSelectedDate(info.dateStr)}
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

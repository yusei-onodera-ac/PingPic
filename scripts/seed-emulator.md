# Emulator seed data — TODO

Placeholder for a future `seed-emulator.ts` script that populates the local Firestore emulator
with sample `prompt_pool` entries, a `daily_schedules` doc for today, and a test `connections` doc
between two test users, so `admin-panel` and `mobile` have something to render locally without
manually clicking through the Emulator UI each time.

Not implemented in this scaffold pass — see docs/ARCHITECTURE.md for what's stubbed vs. real.
Once written, wire it as `firebase emulators:exec --import=./seed-data "npm run seed"` or similar.

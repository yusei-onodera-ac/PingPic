# @pingpic/admin-panel

Next.js (App Router) admin panel for PingPic. See [docs/SETUP.md](../docs/SETUP.md) at the repo
root for the full local-setup flow (env vars, Firebase project wiring).

```bash
cp .env.local.example .env.local   # fill in Firebase web config
npm install
npm run dev      # http://localhost:3000
npm run build
npm run type-check
npm run lint
```

## Routes

| Route          | Purpose                                    | Status |
|----------------|---------------------------------------------|--------|
| `/login`       | Firebase Auth email/password sign-in        | working |
| `/calendar`    | Month-view T1/T2/T3 schedule editor          | working — real Firestore read (`useDailySchedules`) + write (`SlotEditorModal`), with client-side window/gap validation shared with the batch job (`@pingpic/shared-types`'s `validateSendTimes`) |
| `/suggestions` | Pending prompt-suggestion review queue       | working — real query (`usePendingSuggestions`), 採用/却下 actions; adopt writes the suggestion + `daily_schedules` slot atomically via a Firestore transaction (`AdoptSuggestionDialog`) |
| `/prompt-pool` | "Popular prompt" stock CRUD                  | working — add/list/delete (`usePromptPool`) |

Still TODO on all three: nicer UX (the calendar's slot editor and the suggestion-adopt dialog are
functional but plain forms, not polished), and the admin-auth hardening noted below.

`(admin)` is a route group wrapping the above three behind `AuthGuard` (client-side redirect to
`/login` if signed out or missing the `admin` custom claim — see
[docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) for the production-hardening TODO on this).

Deploy target: Vercel (free/Hobby tier) by default — see cost notes in
[docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md).

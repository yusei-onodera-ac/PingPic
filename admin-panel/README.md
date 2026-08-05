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

| Route             | Purpose                                              | Status |
|--------------------|-------------------------------------------------------|--------|
| `/login`           | Firebase Auth email/password sign-in                  | working |
| `/calendar`        | Month-view T1/T2/T3 schedule editor                    | scaffold (empty FullCalendar, TODO Firestore query) |
| `/suggestions`     | Pending prompt-suggestion review queue                 | scaffold (TODO Firestore query + adopt flow) |
| `/prompt-pool`     | "Popular prompt" stock CRUD                            | scaffold (TODO Firestore CRUD) |

`(admin)` is a route group wrapping the above three behind `AuthGuard` (client-side redirect to
`/login` if signed out or missing the `admin` custom claim — see
[docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) for the production-hardening TODO on this).

Deploy target: Vercel (free/Hobby tier) by default — see cost notes in
[docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md).

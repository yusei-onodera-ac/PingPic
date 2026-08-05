import { cookies } from "next/headers";
import { redirect } from "next/navigation";

export default function RootPage() {
  // Cheap presence check only (no Admin SDK verification here) — if it's
  // wrong (stale/invalid cookie), (admin)/layout.tsx's real verification
  // bounces back to /login anyway, so this is just a UX shortcut for the
  // common case of an already-signed-in admin landing on "/".
  const hasSessionCookie = cookies().has("session");
  redirect(hasSessionCookie ? "/calendar" : "/login");
}

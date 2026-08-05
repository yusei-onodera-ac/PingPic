import { redirect } from "next/navigation";

export default function RootPage() {
  // TODO: once useAuth's state is readable server-side (post session-cookie
  // migration, see AuthGuard.tsx TODO), redirect straight to /calendar for
  // already-authenticated admins instead of always going through /login.
  redirect("/login");
}

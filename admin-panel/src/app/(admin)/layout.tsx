import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { adminAuth } from "@/lib/firebase/admin";
import { Sidebar } from "@/components/layout/Sidebar";

/**
 * The REAL security boundary for every /calendar, /suggestions, and
 * /prompt-pool request — this is a Server Component (Node.js runtime),
 * unlike middleware.ts's Edge-runtime presence check, so it can actually
 * call the Admin SDK to verify the session cookie's signature and claims.
 *
 * NOTE: `redirect()` throws internally — deliberately NOT called from
 * inside the try/catch below (a documented Next.js pitfall: a try/catch
 * wrapping a redirect() call ends up catching redirect's own control-flow
 * exception). `isAdmin` is computed inside the try, `redirect()` is only
 * ever called after it, outside any try block.
 */
export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const sessionCookie = cookies().get("session")?.value;
  if (!sessionCookie) {
    redirect("/login");
  }

  let isAdmin = false;
  try {
    // checkRevoked: true so an admin claim removed after this cookie was
    // issued (see docs/SETUP.md's grant-admin-claim script) is caught
    // immediately rather than waiting out the cookie's 5-day expiry.
    const decoded = await adminAuth().verifySessionCookie(sessionCookie, true);
    isAdmin = decoded.admin === true;
  } catch {
    isAdmin = false; // expired / tampered / revoked cookie
  }

  if (!isAdmin) {
    redirect("/login");
  }

  return (
    <div style={{ display: "flex", minHeight: "100vh" }}>
      <Sidebar />
      <main style={{ flex: 1, padding: 24 }}>{children}</main>
    </div>
  );
}

import { NextRequest, NextResponse } from "next/server";

/**
 * Edge-runtime middleware — deliberately a CHEAP PRESENCE CHECK ONLY, not
 * real verification. The Admin SDK (needed to actually verify the session
 * cookie's signature/claims) doesn't run in the Edge runtime, which is
 * what Next.js 14 middleware always uses. The real security boundary is
 * `(admin)/layout.tsx`, a Server Component that runs in the Node.js
 * runtime and calls `adminAuth().verifySessionCookie(...)` for real.
 *
 * This middleware exists purely for UX: redirect obviously-signed-out
 * requests before they even reach the layout, rather than making every
 * visitor wait for a full page render just to bounce to /login.
 */
export function middleware(request: NextRequest) {
  const hasSessionCookie = request.cookies.has("session");
  const isProtectedPath = !request.nextUrl.pathname.startsWith("/login") &&
    !request.nextUrl.pathname.startsWith("/api");

  if (isProtectedPath && !hasSessionCookie) {
    return NextResponse.redirect(new URL("/login", request.url));
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};

import { NextRequest, NextResponse } from "next/server";
import { adminAuth } from "@/lib/firebase/admin";

const SESSION_COOKIE_NAME = "session";
const SESSION_EXPIRES_IN_MS = 5 * 24 * 60 * 60 * 1000; // 5 days

/**
 * Exchanges a client-obtained Firebase ID token for a server-verified,
 * HttpOnly session cookie. This is the real security boundary for the
 * admin panel — see (admin)/layout.tsx, which verifies this cookie with
 * the Admin SDK on every request. middleware.ts only does a cheap
 * presence check (Edge runtime can't run the Admin SDK), NOT the actual
 * verification.
 */
export async function POST(request: NextRequest) {
  const { idToken } = (await request.json()) as { idToken?: string };
  if (!idToken) {
    return NextResponse.json({ error: "idToken is required" }, { status: 400 });
  }

  let decoded;
  try {
    decoded = await adminAuth().verifyIdToken(idToken);
  } catch {
    return NextResponse.json({ error: "Invalid ID token" }, { status: 401 });
  }

  if (decoded.admin !== true) {
    // Deliberately the same error shape/status as an invalid token —
    // don't reveal "you're signed in but not an admin" to a client that
    // might not be the legitimate user (defense in depth; the more
    // important enforcement is still verifySessionCookie in the layout).
    return NextResponse.json({ error: "Not authorized" }, { status: 403 });
  }

  const sessionCookie = await adminAuth().createSessionCookie(idToken, {
    expiresIn: SESSION_EXPIRES_IN_MS,
  });

  const response = NextResponse.json({ ok: true });
  response.cookies.set(SESSION_COOKIE_NAME, sessionCookie, {
    maxAge: SESSION_EXPIRES_IN_MS / 1000,
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
  });
  return response;
}

/** Logout: clears the session cookie. Client should also call Firebase
 * Auth's signOut() — this only clears the server-side session half. */
export async function DELETE() {
  const response = NextResponse.json({ ok: true });
  response.cookies.set(SESSION_COOKIE_NAME, "", { maxAge: 0, path: "/" });
  return response;
}

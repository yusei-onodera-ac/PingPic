"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { signOut as firebaseSignOut } from "firebase/auth";
import { auth } from "@/lib/firebase/client";

/** Clears BOTH halves of the session: the client-side Firebase Auth state
 * and the server-side HttpOnly cookie (app/api/session/route.ts's
 * DELETE) — the layout only checks the latter, but leaving the former
 * around would let a stale client SDK session silently re-auth calls
 * elsewhere in the app. */
export function SignOutButton() {
  const [signingOut, setSigningOut] = useState(false);
  const router = useRouter();

  async function handleSignOut() {
    setSigningOut(true);
    try {
      await fetch("/api/session", { method: "DELETE" });
      await firebaseSignOut(auth);
    } finally {
      router.push("/login");
    }
  }

  return (
    <button onClick={handleSignOut} disabled={signingOut}>
      {signingOut ? "サインアウト中…" : "サインアウト"}
    </button>
  );
}

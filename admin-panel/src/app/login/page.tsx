"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { signInWithEmailAndPassword, signOut } from "firebase/auth";
import { auth } from "@/lib/firebase/client";

/**
 * TODO: this is a minimal working sign-in form so the scaffold is
 * click-through-able, not a finished auth UX (no error-state design, no
 * password-reset link, etc.). Admin-CLAIM assignment (making an account
 * an admin in the first place) is a separate one-off step — see
 * scripts/grant-admin-claim.mjs + docs/SETUP.md, deliberately not a
 * self-service UI here.
 */
export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const router = useRouter();

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      const credential = await signInWithEmailAndPassword(auth, email, password);
      const idToken = await credential.user.getIdToken();

      // Exchanges the client-side ID token for a server-verified,
      // HttpOnly session cookie — see app/api/session/route.ts. This is
      // the real security boundary the (admin) route group checks, not
      // anything client-side.
      const response = await fetch("/api/session", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ idToken }),
      });

      if (!response.ok) {
        // Signed in to Firebase Auth fine, but not an admin (or the
        // server rejected the token) — don't leave a dangling client
        // session for a non-admin account.
        await signOut(auth);
        setError(
          response.status === 403
            ? "管理者権限がありません"
            : "サインインに失敗しました"
        );
        return;
      }

      router.push("/calendar");
    } catch (err) {
      setError(err instanceof Error ? err.message : "サインインに失敗しました");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main style={{ maxWidth: 360, margin: "80px auto" }}>
      <h1>PingPic Admin ログイン</h1>
      <form onSubmit={handleSubmit}>
        <div>
          <label>
            メール
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </label>
        </div>
        <div>
          <label>
            パスワード
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </label>
        </div>
        {error && <p style={{ color: "crimson" }}>{error}</p>}
        <button type="submit" disabled={submitting}>
          {submitting ? "ログイン中…" : "ログイン"}
        </button>
      </form>
    </main>
  );
}

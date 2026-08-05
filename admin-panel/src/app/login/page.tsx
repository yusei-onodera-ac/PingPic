"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { signInWithEmailAndPassword } from "firebase/auth";
import { auth } from "@/lib/firebase/client";

/**
 * TODO: this is a minimal working sign-in form so the scaffold is
 * click-through-able, not a finished auth UX (no error-state design, no
 * password-reset link, etc.). Admin-claim assignment itself is out of
 * scope here — see lib/firebase/admin.ts grantAdminClaim TODO.
 */
export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      await signInWithEmailAndPassword(auth, email, password);
      router.push("/calendar");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Sign-in failed");
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
        <button type="submit">ログイン</button>
      </form>
    </main>
  );
}

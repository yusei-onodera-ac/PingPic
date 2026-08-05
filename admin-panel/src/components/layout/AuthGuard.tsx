"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth/useAuth";

/**
 * Wraps the (admin) route group's layout. Redirects to /login if the user
 * is signed out or lacks the `admin` claim.
 *
 * See useAuth.ts TODO — this is a client-side-only gate for now.
 */
export function AuthGuard({ children }: { children: React.ReactNode }) {
  const { user, isAdmin, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!loading && (!user || !isAdmin)) {
      router.replace("/login");
    }
  }, [loading, user, isAdmin, router]);

  if (loading) {
    return <div style={{ padding: 24 }}>Loading…</div>;
  }
  if (!user || !isAdmin) {
    return null; // redirect in flight
  }
  return <>{children}</>;
}

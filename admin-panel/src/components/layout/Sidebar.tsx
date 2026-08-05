"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { SignOutButton } from "./SignOutButton";

const NAV_ITEMS = [
  { href: "/calendar", label: "カレンダー" },
  { href: "/suggestions", label: "お題提案の審査" },
  { href: "/prompt-pool", label: "人気お題ストック" },
];

export function Sidebar() {
  const pathname = usePathname();
  return (
    <nav
      style={{
        width: 220,
        borderRight: "1px solid #ddd",
        padding: 16,
        display: "flex",
        flexDirection: "column",
        justifyContent: "space-between",
      }}
    >
      <div>
        <p style={{ fontWeight: 700, marginBottom: 16 }}>PingPic Admin</p>
        <ul style={{ listStyle: "none", padding: 0, margin: 0 }}>
          {NAV_ITEMS.map((item) => (
            <li key={item.href} style={{ marginBottom: 8 }}>
              <Link
                href={item.href}
                style={{
                  fontWeight: pathname?.startsWith(item.href) ? 700 : 400,
                }}
              >
                {item.label}
              </Link>
            </li>
          ))}
        </ul>
      </div>
      <SignOutButton />
    </nav>
  );
}

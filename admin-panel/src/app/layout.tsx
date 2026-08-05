import type { Metadata } from "next";
import "../styles/globals.css";

export const metadata: Metadata = {
  title: "PingPic Admin",
  description: "PingPic 運営管理パネル",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  );
}

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Deploy target is Vercel by default (see docs/ARCHITECTURE.md cost
  // notes) — no `output: 'export'` / Firebase Hosting rewrites configured
  // here. Revisit if that decision changes.
};

module.exports = nextConfig;

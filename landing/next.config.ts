import type { NextConfig } from "next";
import path from "node:path";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  // Legal pages share the versioned policy bundled with the iOS app.
  turbopack: {
    root: path.resolve(__dirname, ".."),
  },
  images: {
    formats: ["image/avif", "image/webp"],
  },
  async headers() {
    return [
      {
        // Apple Universal Links / Android App Links association files must be
        // served with the correct content type and no auth.
        source: "/.well-known/:file",
        headers: [{ key: "Content-Type", value: "application/json" }],
      },
    ];
  },
};

export default nextConfig;

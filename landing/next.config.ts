import type { NextConfig } from "next";

// Static export: the VPS serves the `out/` folder with nginx, no Node at runtime.
const nextConfig: NextConfig = {
  output: "export",
  trailingSlash: true,
  images: { unoptimized: true },
};

export default nextConfig;

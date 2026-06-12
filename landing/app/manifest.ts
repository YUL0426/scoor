import type { MetadataRoute } from "next";
import { SITE } from "@/lib/site";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: `Scoor — ${SITE.tagline}`,
    short_name: "Scoor",
    description: SITE.description,
    start_url: "/",
    display: "standalone",
    background_color: "#faf7f5",
    theme_color: "#ce3b22",
    icons: [
      { src: "/icon-192.png", sizes: "192x192", type: "image/png" },
      { src: "/icon-512.png", sizes: "512x512", type: "image/png" },
    ],
  };
}

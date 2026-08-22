import type { MetadataRoute } from "next";
import { SITE } from "@/lib/site";

export default function sitemap(): MetadataRoute.Sitemap {
  const now = new Date();
  const routes = ["", "privacy", "privacy/ko", "terms", "terms/ko", "#how", "#world", "#insights", "#social", "#download"];
  return routes.map((r) => ({
    url: `${SITE.url}/${r}`,
    lastModified: now,
    changeFrequency: "weekly",
    priority: r === "" ? 1 : 0.7,
  }));
}

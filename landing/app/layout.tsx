import type { Metadata, Viewport } from "next";
import { Inter } from "next/font/google";
import { SITE, STORE_STATUS } from "@/lib/site";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
});

const KEYWORDS = [
  "score your day",
  "daily rating app",
  "life tracking app",
  "social scoring app",
  "public sentiment app",
  "mood tracker",
  "rate everything",
  "Scoor",
];

export const metadata: Metadata = {
  metadataBase: new URL(SITE.url),
  title: {
    default: `Scoor — ${SITE.tagline}`,
    template: "%s · Scoor",
  },
  description: SITE.description,
  applicationName: SITE.name,
  keywords: KEYWORDS,
  authors: [{ name: "Scoor" }],
  creator: "Scoor",
  alternates: { canonical: "/" },
  manifest: "/manifest.webmanifest",
  appleWebApp: {
    capable: true,
    title: SITE.name,
    statusBarStyle: "default",
  },
  // Native iOS Smart App Banner (in addition to our custom one) — only once
  // the App Store listing is live and SITE.appStoreId is set.
  ...(STORE_STATUS.appStoreLive && SITE.appStoreId
    ? { other: { "apple-itunes-app": `app-id=${SITE.appStoreId}, app-argument=${SITE.url}` } }
    : {}),
  openGraph: {
    type: "website",
    siteName: SITE.name,
    title: `Scoor — ${SITE.tagline}`,
    description: SITE.description,
    url: SITE.url,
    locale: "en_US",
  },
  twitter: {
    card: "summary_large_image",
    title: `Scoor — ${SITE.tagline}`,
    description: SITE.description,
    site: SITE.twitter,
    creator: SITE.twitter,
  },
  icons: {
    icon: "/icon.png",
    apple: "/apple-icon.png",
  },
  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true, "max-image-preview": "large" },
  },
};

export const viewport: Viewport = {
  themeColor: "#ce3b22",
  width: "device-width",
  initialScale: 1,
};

const JSON_LD = {
  "@context": "https://schema.org",
  "@type": "MobileApplication",
  name: "Scoor",
  applicationCategory: "SocialNetworkingApplication",
  operatingSystem: "iOS, Android",
  description: SITE.description,
  url: SITE.url,
  offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
  // No aggregateRating until real store reviews exist — fabricated review
  // counts violate structured-data policies.
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className={inter.variable}>
      <body>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(JSON_LD) }}
        />
        {children}
      </body>
    </html>
  );
}

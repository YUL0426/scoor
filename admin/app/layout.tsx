import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Scoor Admin",
  description: "Scoor Platform Operations Center",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="h-full dark">
      <body className="h-full bg-[#060610] text-[#f4f4f6] antialiased">
        {children}
      </body>
    </html>
  );
}

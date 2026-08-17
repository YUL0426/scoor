import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Scoor 어드민",
  description: "Scoor 플랫폼 운영 센터",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ko" className="h-full dark">
      <body className="h-full bg-[#060610] text-[#f4f4f6] antialiased">
        {children}
      </body>
    </html>
  );
}

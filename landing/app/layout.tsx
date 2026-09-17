import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const sans = Geist({ subsets: ["latin"], variable: "--font-sans" });
const mono = Geist_Mono({ subsets: ["latin"], variable: "--font-mono" });

export const metadata: Metadata = {
  metadataBase: new URL("https://hopperclip.xyz"),
  title: "Hopper — copy here, paste there",
  description:
    "One clipboard across your Mac and your Samsung. Copy on one, paste on the other. No cloud, no account, end-to-end encrypted, over your own Wi-Fi.",
  openGraph: {
    type: "website",
    url: "https://hopperclip.xyz",
    siteName: "Hopper",
    title: "Hopper — copy here, paste there",
    description: "One clipboard across your Mac and your Samsung. Copy on one, paste on the other. No cloud, no account, end-to-end encrypted.",
    images: [{ url: "/assets/og.png", width: 1200, height: 630, alt: "Hopper — copy here, paste there" }],
  },
  twitter: {
    card: "summary_large_image",
    title: "Hopper — copy here, paste there",
    description: "One clipboard across your Mac and your Samsung. No cloud, no account, end-to-end encrypted.",
    images: ["/assets/og.png"],
  },
};

export const viewport = { themeColor: "#070b14" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${sans.variable} ${mono.variable}`}>
      <body>{children}</body>
    </html>
  );
}

import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://hopperclip.xyz"),
  title: "Hopper — copy here, paste there",
  description:
    "One clipboard across your Mac and your Samsung. Copy on one, paste on the other. No cloud, no account, end-to-end encrypted, over your own Wi-Fi.",
  openGraph: {
    title: "Hopper — copy here, paste there",
    description: "One clipboard across your Mac and your Samsung. No cloud, no account, end-to-end encrypted.",
    images: ["/assets/icon.png"],
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}

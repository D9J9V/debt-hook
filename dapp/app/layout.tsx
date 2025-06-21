import type React from "react"
import type { Metadata } from "next"
import { Inter } from "next/font/google"
import "./globals.css"
import { ThemeProvider } from "@/components/theme-provider"
import { BottomNavigation } from "@/components/layout/bottom-navigation"

const inter = Inter({ subsets: ["latin"] })

export const metadata: Metadata = {
  title: "Humane Banque - Secure Fixed-Term DeFi Lending",
  description: "Secure Fixed-Term DeFi Lending for Verified Humans",
    generator: 'v0.dev'
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={inter.className}>
        <ThemeProvider attribute="class" defaultTheme="light" enableSystem disableTransitionOnChange>
          <div className="pb-16 md:pb-0">{children}</div>
          <BottomNavigation />
        </ThemeProvider>
      </body>
    </html>
  )
}

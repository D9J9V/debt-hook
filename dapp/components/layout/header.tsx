"use client"

import { useState } from "react"
import Link from "next/link"
import { usePathname } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Wallet, Shield } from "lucide-react"

export function Header() {
  const pathname = usePathname()
  const [isConnected, setIsConnected] = useState(false)
  const [isVerified, setIsVerified] = useState(false)

  return (
    <header className="sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div className="container flex h-16 items-center justify-between">
        {/* Logo */}
        <Link href="/" className="flex items-center space-x-2">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary">
            <Shield className="h-5 w-5 text-primary-foreground" />
          </div>
          <span className="text-xl font-bold">Humane Banque</span>
        </Link>

        {/* Desktop Navigation */}
        <nav className="hidden md:flex items-center space-x-6">
          <Link
            href="/dashboard"
            className={`text-sm font-medium transition-colors hover:text-primary ${
              pathname === "/dashboard" ? "text-primary" : "text-muted-foreground"
            }`}
          >
            Dashboard
          </Link>
          <Link
            href="/lend"
            className={`text-sm font-medium transition-colors hover:text-primary ${
              pathname === "/lend" ? "text-primary" : "text-muted-foreground"
            }`}
          >
            Lend
          </Link>
          <Link
            href="/borrow"
            className={`text-sm font-medium transition-colors hover:text-primary ${
              pathname === "/borrow" ? "text-primary" : "text-muted-foreground"
            }`}
          >
            Borrow
          </Link>
          <Link
            href="/portfolio"
            className={`text-sm font-medium transition-colors hover:text-primary ${
              pathname === "/portfolio" ? "text-primary" : "text-muted-foreground"
            }`}
          >
            Portfolio
          </Link>
        </nav>

        {/* Actions */}
        <div className="flex items-center space-x-2 md:space-x-4">
          {/* Verification Status - Hidden on small screens */}
          {isConnected && (
            <Badge variant={isVerified ? "default" : "secondary"} className="hidden sm:flex">
              <Shield className="h-3 w-3 mr-1" />
              {isVerified ? "Verified" : "Unverified"}
            </Badge>
          )}

          {/* Connect Wallet */}
          <Button
            onClick={() => setIsConnected(!isConnected)}
            variant={isConnected ? "outline" : "default"}
            size="sm"
            className="text-xs sm:text-sm"
          >
            <Wallet className="h-4 w-4 mr-1 sm:mr-2" />
            <span className="hidden sm:inline">{isConnected ? "0x1234...5678" : "Connect Wallet"}</span>
            <span className="sm:hidden">{isConnected ? "Connected" : "Connect"}</span>
          </Button>
        </div>
      </div>
    </header>
  )
}

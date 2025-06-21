"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { TrendingUp, Wallet, PieChart, LayoutDashboard } from "lucide-react"
import { cn } from "@/lib/utils"

const navigation = [
  { name: "Dashboard", href: "/dashboard", icon: LayoutDashboard },
  { name: "Lend", href: "/lend", icon: TrendingUp },
  { name: "Borrow", href: "/borrow", icon: Wallet },
  { name: "Portfolio", href: "/portfolio", icon: PieChart },
]

export function BottomNavigation() {
  const pathname = usePathname()

  // Don't show on landing page
  if (pathname === "/") {
    return null
  }

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 bg-background border-t">
      <div className="grid grid-cols-4 h-16">
        {navigation.map((item) => {
          const Icon = item.icon
          const isActive = pathname === item.href

          return (
            <Link
              key={item.name}
              href={item.href}
              className={cn(
                "flex flex-col items-center justify-center space-y-1 text-xs font-medium transition-colors",
                isActive ? "text-primary bg-primary/5" : "text-muted-foreground hover:text-primary",
              )}
            >
              <Icon className={cn("h-5 w-5", isActive && "text-primary")} />
              <span className={cn(isActive && "text-primary")}>{item.name}</span>
            </Link>
          )
        })}
      </div>
    </nav>
  )
}

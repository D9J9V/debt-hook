"use client"

import { useState } from "react"
import { Header } from "@/components/layout/header"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Progress } from "@/components/ui/progress"
import {
  TrendingUp,
  TrendingDown,
  DollarSign,
  Clock,
  Users,
  Shield,
  ArrowUpRight,
  ArrowDownRight,
  Calendar,
  Wallet,
} from "lucide-react"
import Link from "next/link"

export default function Dashboard() {
  const [totalLent] = useState(25000)
  const [totalBorrowed] = useState(8500)
  const [totalEarned] = useState(1250)
  const [activePositions] = useState(3)

  const markets = [
    {
      term: "30 Days",
      currentRate: 8.5,
      trend: "up",
      change: "+0.3%",
      totalLiquidity: 125000,
      utilization: 68,
      nextAuction: "2h 15m",
      minRate: 7.2,
      maxRate: 9.8,
    },
    {
      term: "90 Days",
      currentRate: 12.2,
      trend: "down",
      change: "-0.1%",
      totalLiquidity: 89000,
      utilization: 45,
      nextAuction: "5h 42m",
      minRate: 10.5,
      maxRate: 14.1,
    },
    {
      term: "180 Days",
      currentRate: 15.8,
      trend: "up",
      change: "+0.7%",
      totalLiquidity: 156000,
      utilization: 72,
      nextAuction: "1h 33m",
      minRate: 13.2,
      maxRate: 18.5,
    },
  ]

  const recentActivity = [
    {
      type: "lend",
      amount: 5000,
      rate: 8.5,
      term: "30 Days",
      date: "2 hours ago",
      status: "active",
    },
    {
      type: "repayment",
      amount: 2150,
      rate: 12.2,
      term: "90 Days",
      date: "1 day ago",
      status: "completed",
    },
    {
      type: "borrow",
      amount: 3000,
      rate: 15.8,
      term: "180 Days",
      date: "3 days ago",
      status: "active",
    },
  ]

  return (
    <div className="min-h-screen bg-background">
      <Header />

      <div className="container mx-auto px-4 py-6 md:py-8">
        {/* Welcome Section */}
        <div className="mb-8">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold">Dashboard</h1>
              <p className="text-muted-foreground">Welcome back to Humane Banque</p>
            </div>
            <Badge className="bg-green-100 text-green-800 border-green-200">
              <Shield className="h-3 w-3 mr-1" />
              Verified Human
            </Badge>
          </div>
        </div>

        {/* Stats Overview */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 md:gap-6 mb-6 md:mb-8">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Total Lent</CardTitle>
              <TrendingUp className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">${totalLent.toLocaleString()}</div>
              <p className="text-xs text-muted-foreground">+12.5% from last month</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Total Borrowed</CardTitle>
              <TrendingDown className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">${totalBorrowed.toLocaleString()}</div>
              <p className="text-xs text-muted-foreground">Active across {activePositions} positions</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Total Earned</CardTitle>
              <DollarSign className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">${totalEarned.toLocaleString()}</div>
              <p className="text-xs text-muted-foreground">8.7% average APR</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Active Positions</CardTitle>
              <Clock className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{activePositions}</div>
              <p className="text-xs text-muted-foreground">2 lending, 1 borrowing</p>
            </CardContent>
          </Card>
        </div>

        <div className="grid lg:grid-cols-3 gap-6 md:gap-8">
          {/* Markets Overview */}
          <div className="lg:col-span-2">
            <Card>
              <CardHeader>
                <CardTitle>Active Markets</CardTitle>
                <CardDescription>Current lending rates and market conditions</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4 md:space-y-6">
                  {markets.map((market) => (
                    <div key={market.term} className="border rounded-lg p-3 md:p-4">
                      <div className="flex items-center justify-between mb-2 md:mb-3">
                        <div className="flex items-center space-x-2 md:space-x-3">
                          <h3 className="font-semibold text-sm md:text-base">{market.term}</h3>
                          <Badge variant="outline" className="text-xs">
                            <Calendar className="h-3 w-3 mr-1" />
                            <span className="hidden sm:inline">Next auction: </span>
                            {market.nextAuction}
                          </Badge>
                        </div>
                        <div className="flex items-center space-x-1 md:space-x-2">
                          <span className="text-xl md:text-2xl font-bold text-primary">{market.currentRate}%</span>
                          <div
                            className={`flex items-center text-xs md:text-sm ${
                              market.trend === "up" ? "text-green-600" : "text-red-600"
                            }`}
                          >
                            {market.trend === "up" ? (
                              <ArrowUpRight className="h-3 w-3" />
                            ) : (
                              <ArrowDownRight className="h-3 w-3" />
                            )}
                            {market.change}
                          </div>
                        </div>
                      </div>

                      <div className="grid grid-cols-2 gap-3 md:gap-4 text-xs md:text-sm">
                        <div>
                          <div className="text-muted-foreground">Total Liquidity</div>
                          <div className="font-medium">${market.totalLiquidity.toLocaleString()}</div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">Utilization</div>
                          <div className="flex items-center space-x-2">
                            <Progress value={market.utilization} className="flex-1" />
                            <span className="font-medium text-xs">{market.utilization}%</span>
                          </div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">Rate Range (24h)</div>
                          <div className="font-medium text-xs md:text-sm">
                            {market.minRate}% - {market.maxRate}%
                          </div>
                        </div>
                        <div className="flex space-x-1 md:space-x-2">
                          <Button size="sm" variant="outline" asChild className="text-xs px-2 md:px-3">
                            <Link href={`/lend?term=${market.term}`}>Lend</Link>
                          </Button>
                          <Button size="sm" variant="outline" asChild className="text-xs px-2 md:px-3">
                            <Link href={`/borrow?term=${market.term}`}>Borrow</Link>
                          </Button>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Recent Activity & Quick Actions */}
          <div className="space-y-6">
            {/* Quick Actions */}
            <Card>
              <CardHeader>
                <CardTitle>Quick Actions</CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <Button className="w-full" asChild>
                  <Link href="/lend">
                    <TrendingUp className="mr-2 h-4 w-4" />
                    Start Lending
                  </Link>
                </Button>
                <Button variant="outline" className="w-full" asChild>
                  <Link href="/borrow">
                    <Wallet className="mr-2 h-4 w-4" />
                    Borrow USDC
                  </Link>
                </Button>
                <Button variant="outline" className="w-full" asChild>
                  <Link href="/portfolio">
                    <Users className="mr-2 h-4 w-4" />
                    View Portfolio
                  </Link>
                </Button>
              </CardContent>
            </Card>

            {/* Recent Activity */}
            <Card>
              <CardHeader>
                <CardTitle>Recent Activity</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  {recentActivity.map((activity, index) => (
                    <div key={index} className="flex items-center justify-between p-3 border rounded-lg">
                      <div className="flex items-center space-x-3">
                        <div
                          className={`w-2 h-2 rounded-full ${
                            activity.type === "lend"
                              ? "bg-green-500"
                              : activity.type === "borrow"
                                ? "bg-blue-500"
                                : "bg-gray-500"
                          }`}
                        />
                        <div>
                          <div className="font-medium capitalize">
                            {activity.type} ${activity.amount.toLocaleString()}
                          </div>
                          <div className="text-sm text-muted-foreground">
                            {activity.rate}% • {activity.term}
                          </div>
                        </div>
                      </div>
                      <div className="text-right">
                        <Badge variant={activity.status === "active" ? "default" : "secondary"}>
                          {activity.status}
                        </Badge>
                        <div className="text-xs text-muted-foreground mt-1">{activity.date}</div>
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </div>
  )
}

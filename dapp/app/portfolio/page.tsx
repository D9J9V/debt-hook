"use client"

import { useState } from "react"
import { Header } from "@/components/layout/header"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Progress } from "@/components/ui/progress"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { TrendingUp, TrendingDown, Clock, DollarSign, AlertTriangle, CheckCircle, ArrowUpRight } from "lucide-react"

export default function PortfolioPage() {
  const [activeTab, setActiveTab] = useState("overview")

  const lendingPositions = [
    {
      id: "L001",
      amount: 10000,
      rate: 8.5,
      term: 30,
      startDate: "2024-03-15",
      maturityDate: "2024-04-14",
      daysRemaining: 12,
      status: "active",
      projectedReturn: 70.41,
      borrower: "0x1234...5678",
    },
    {
      id: "L002",
      amount: 15000,
      rate: 12.2,
      term: 90,
      startDate: "2024-02-01",
      maturityDate: "2024-05-01",
      daysRemaining: 45,
      status: "active",
      projectedReturn: 451.23,
      borrower: "0x9876...4321",
    },
    {
      id: "L003",
      amount: 5000,
      rate: 9.1,
      term: 30,
      startDate: "2024-02-15",
      maturityDate: "2024-03-16",
      daysRemaining: 0,
      status: "matured",
      projectedReturn: 37.4,
      borrower: "0x5555...1111",
    },
  ]

  const borrowingPositions = [
    {
      id: "B001",
      borrowAmount: 8500,
      collateralAmount: 4.2,
      collateralType: "ETH",
      collateralValue: 13440,
      rate: 15.8,
      term: 180,
      startDate: "2024-01-15",
      maturityDate: "2024-07-13",
      daysRemaining: 98,
      status: "active",
      interestOwed: 573.15,
      totalRepayment: 9073.15,
      currentLTV: 63.2,
      liquidationLTV: 80,
    },
  ]

  const totalLent = lendingPositions.reduce((sum, pos) => sum + pos.amount, 0)
  const totalBorrowed = borrowingPositions.reduce((sum, pos) => sum + pos.borrowAmount, 0)
  const totalEarned = lendingPositions
    .filter((pos) => pos.status === "matured")
    .reduce((sum, pos) => sum + pos.projectedReturn, 0)
  const projectedEarnings = lendingPositions
    .filter((pos) => pos.status === "active")
    .reduce((sum, pos) => sum + pos.projectedReturn, 0)

  return (
    <div className="min-h-screen bg-background">
      <Header />

      <div className="container mx-auto px-4 py-6 md:py-8">
        <div className="mb-8">
          <h1 className="text-3xl font-bold mb-2">Portfolio</h1>
          <p className="text-muted-foreground">Track your lending and borrowing positions</p>
        </div>

        <Tabs value={activeTab} onValueChange={setActiveTab}>
          <TabsList className="grid w-full grid-cols-4 mb-6 md:mb-8 h-9 md:h-10">
            <TabsTrigger value="overview" className="text-xs md:text-sm">
              Overview
            </TabsTrigger>
            <TabsTrigger value="lending" className="text-xs md:text-sm">
              Lending
            </TabsTrigger>
            <TabsTrigger value="borrowing" className="text-xs md:text-sm">
              Borrowing
            </TabsTrigger>
            <TabsTrigger value="history" className="text-xs md:text-sm">
              History
            </TabsTrigger>
          </TabsList>

          <TabsContent value="overview" className="space-y-6">
            {/* Portfolio Summary */}
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 md:gap-6">
              <Card>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium">Total Lent</CardTitle>
                  <TrendingUp className="h-4 w-4 text-muted-foreground" />
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold">${totalLent.toLocaleString()}</div>
                  <p className="text-xs text-muted-foreground">
                    {lendingPositions.filter((p) => p.status === "active").length} active positions
                  </p>
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium">Total Borrowed</CardTitle>
                  <TrendingDown className="h-4 w-4 text-muted-foreground" />
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold">${totalBorrowed.toLocaleString()}</div>
                  <p className="text-xs text-muted-foreground">
                    {borrowingPositions.filter((p) => p.status === "active").length} active loans
                  </p>
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium">Total Earned</CardTitle>
                  <DollarSign className="h-4 w-4 text-muted-foreground" />
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold">${totalEarned.toFixed(2)}</div>
                  <p className="text-xs text-muted-foreground">Realized returns</p>
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium">Projected Earnings</CardTitle>
                  <Clock className="h-4 w-4 text-muted-foreground" />
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold">${projectedEarnings.toFixed(2)}</div>
                  <p className="text-xs text-muted-foreground">From active positions</p>
                </CardContent>
              </Card>
            </div>

            {/* Active Positions Summary */}
            <div className="grid lg:grid-cols-2 gap-6">
              <Card>
                <CardHeader>
                  <CardTitle>Active Lending Positions</CardTitle>
                  <CardDescription>Your current lending activities</CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    {lendingPositions
                      .filter((pos) => pos.status === "active")
                      .map((position) => (
                        <div key={position.id} className="flex items-center justify-between p-3 border rounded-lg">
                          <div>
                            <div className="font-medium text-sm md:text-base">${position.amount.toLocaleString()}</div>
                            <div className="text-xs md:text-sm text-muted-foreground">
                              {position.rate}% • {position.term} days • {position.daysRemaining} days left
                            </div>
                          </div>
                          <div className="text-right">
                            <div className="font-medium text-green-600 text-sm md:text-base">
                              +${position.projectedReturn.toFixed(2)}
                            </div>
                            <Badge variant="outline" className="text-xs">
                              Active
                            </Badge>
                          </div>
                        </div>
                      ))}
                  </div>
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle>Active Borrowing Positions</CardTitle>
                  <CardDescription>Your current loans and collateral</CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    {borrowingPositions
                      .filter((pos) => pos.status === "active")
                      .map((position) => (
                        <div key={position.id} className="border rounded-lg p-4">
                          <div className="flex items-center justify-between mb-3">
                            <div>
                              <div className="font-medium">${position.borrowAmount.toLocaleString()} USDC</div>
                              <div className="text-sm text-muted-foreground">
                                {position.rate}% • {position.daysRemaining} days left
                              </div>
                            </div>
                            <Badge variant={position.currentLTV > 70 ? "destructive" : "default"}>
                              {position.currentLTV}% LTV
                            </Badge>
                          </div>

                          <div className="space-y-2 text-sm">
                            <div className="flex justify-between">
                              <span>Collateral:</span>
                              <span>
                                {position.collateralAmount} {position.collateralType}
                              </span>
                            </div>
                            <div className="flex justify-between">
                              <span>Total Repayment:</span>
                              <span className="font-medium">${position.totalRepayment.toLocaleString()}</span>
                            </div>
                          </div>

                          <div className="mt-3">
                            <div className="flex justify-between text-xs mb-1">
                              <span>LTV Ratio</span>
                              <span>
                                {position.currentLTV}% / {position.liquidationLTV}%
                              </span>
                            </div>
                            <Progress value={(position.currentLTV / position.liquidationLTV) * 100} />
                          </div>
                        </div>
                      ))}
                  </div>
                </CardContent>
              </Card>
            </div>
          </TabsContent>

          <TabsContent value="lending" className="space-y-6">
            <Card>
              <CardHeader>
                <CardTitle>Lending Positions</CardTitle>
                <CardDescription>All your lending activities and returns</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  {lendingPositions.map((position) => (
                    <div key={position.id} className="border rounded-lg p-4">
                      <div className="flex items-center justify-between mb-4">
                        <div className="flex items-center space-x-3">
                          <div>
                            <div className="font-semibold">${position.amount.toLocaleString()}</div>
                            <div className="text-sm text-muted-foreground">Position {position.id}</div>
                          </div>
                        </div>
                        <div className="flex items-center space-x-2">
                          <Badge
                            variant={
                              position.status === "active"
                                ? "default"
                                : position.status === "matured"
                                  ? "secondary"
                                  : "outline"
                            }
                          >
                            {position.status}
                          </Badge>
                          {position.status === "active" && (
                            <Badge variant="outline">
                              <Clock className="h-3 w-3 mr-1" />
                              {position.daysRemaining}d left
                            </Badge>
                          )}
                        </div>
                      </div>

                      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                        <div>
                          <div className="text-muted-foreground">Rate</div>
                          <div className="font-medium">{position.rate}% APR</div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">Term</div>
                          <div className="font-medium">{position.term} days</div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">Start Date</div>
                          <div className="font-medium">{new Date(position.startDate).toLocaleDateString()}</div>
                        </div>
                        <div>
                          <div className="text-muted-foreground">Maturity</div>
                          <div className="font-medium">{new Date(position.maturityDate).toLocaleDateString()}</div>
                        </div>
                      </div>

                      <div className="flex items-center justify-between mt-4 pt-4 border-t">
                        <div>
                          <div className="text-sm text-muted-foreground">
                            {position.status === "matured" ? "Earned" : "Projected Return"}
                          </div>
                          <div className="font-semibold text-green-600">+${position.projectedReturn.toFixed(2)}</div>
                        </div>
                        {position.status === "matured" && (
                          <Button size="sm" variant="outline">
                            <CheckCircle className="h-4 w-4 mr-2" />
                            Claimed
                          </Button>
                        )}
                        {position.status === "active" && position.daysRemaining <= 7 && (
                          <Button size="sm">Prepare Claim</Button>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="borrowing" className="space-y-6">
            <Card>
              <CardHeader>
                <CardTitle>Borrowing Positions</CardTitle>
                <CardDescription>Manage your loans and collateral</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-6">
                  {borrowingPositions.map((position) => (
                    <div key={position.id} className="border rounded-lg p-6">
                      <div className="flex items-center justify-between mb-6">
                        <div>
                          <div className="text-2xl font-bold">${position.borrowAmount.toLocaleString()}</div>
                          <div className="text-muted-foreground">Loan {position.id}</div>
                        </div>
                        <div className="text-right">
                          <Badge variant={position.currentLTV > 70 ? "destructive" : "default"} className="mb-2">
                            {position.currentLTV}% LTV
                          </Badge>
                          <div className="text-sm text-muted-foreground">{position.daysRemaining} days remaining</div>
                        </div>
                      </div>

                      <div className="grid md:grid-cols-2 gap-6">
                        <div className="space-y-4">
                          <h4 className="font-medium">Loan Details</h4>
                          <div className="space-y-2 text-sm">
                            <div className="flex justify-between">
                              <span>Principal:</span>
                              <span className="font-medium">${position.borrowAmount.toLocaleString()}</span>
                            </div>
                            <div className="flex justify-between">
                              <span>Interest Rate:</span>
                              <span className="font-medium">{position.rate}% APR</span>
                            </div>
                            <div className="flex justify-between">
                              <span>Interest Owed:</span>
                              <span className="font-medium">${position.interestOwed.toFixed(2)}</span>
                            </div>
                            <div className="flex justify-between border-t pt-2">
                              <span>Total Repayment:</span>
                              <span className="font-semibold">${position.totalRepayment.toFixed(2)}</span>
                            </div>
                          </div>
                        </div>

                        <div className="space-y-4">
                          <h4 className="font-medium">Collateral</h4>
                          <div className="space-y-2 text-sm">
                            <div className="flex justify-between">
                              <span>Amount:</span>
                              <span className="font-medium">
                                {position.collateralAmount} {position.collateralType}
                              </span>
                            </div>
                            <div className="flex justify-between">
                              <span>Value:</span>
                              <span className="font-medium">${position.collateralValue.toLocaleString()}</span>
                            </div>
                            <div className="flex justify-between">
                              <span>Liquidation LTV:</span>
                              <span className="font-medium">{position.liquidationLTV}%</span>
                            </div>
                          </div>

                          <div>
                            <div className="flex justify-between text-xs mb-2">
                              <span>Health Factor</span>
                              <span className={position.currentLTV > 70 ? "text-red-600" : "text-green-600"}>
                                {position.currentLTV > 70 ? "At Risk" : "Healthy"}
                              </span>
                            </div>
                            <Progress value={(position.currentLTV / position.liquidationLTV) * 100} className="h-2" />
                          </div>
                        </div>
                      </div>

                      <div className="flex items-center justify-between mt-6 pt-4 border-t">
                        <div className="text-sm text-muted-foreground">
                          Maturity: {new Date(position.maturityDate).toLocaleDateString()}
                        </div>
                        <div className="flex space-x-2">
                          <Button variant="outline" size="sm">
                            Add Collateral
                          </Button>
                          <Button size="sm">Repay Loan</Button>
                        </div>
                      </div>

                      {position.currentLTV > 70 && (
                        <div className="mt-4 p-3 bg-orange-50 border border-orange-200 rounded-lg">
                          <div className="flex items-center space-x-2 text-orange-800">
                            <AlertTriangle className="h-4 w-4" />
                            <span className="text-sm font-medium">Liquidation Risk</span>
                          </div>
                          <p className="text-sm text-orange-700 mt-1">
                            Your position is at risk of liquidation. Consider adding more collateral or repaying part of
                            the loan.
                          </p>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="history" className="space-y-6">
            <Card>
              <CardHeader>
                <CardTitle>Transaction History</CardTitle>
                <CardDescription>All your past transactions and activities</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  {[
                    {
                      type: "lend",
                      amount: 5000,
                      rate: 9.1,
                      date: "2024-03-16",
                      status: "completed",
                      txHash: "0xabc123...",
                    },
                    {
                      type: "claim",
                      amount: 37.4,
                      date: "2024-03-16",
                      status: "completed",
                      txHash: "0xdef456...",
                    },
                    {
                      type: "borrow",
                      amount: 8500,
                      collateral: "4.2 ETH",
                      rate: 15.8,
                      date: "2024-01-15",
                      status: "active",
                      txHash: "0x789xyz...",
                    },
                  ].map((tx, index) => (
                    <div key={index} className="flex items-center justify-between p-4 border rounded-lg">
                      <div className="flex items-center space-x-4">
                        <div
                          className={`w-2 h-2 rounded-full ${
                            tx.type === "lend" ? "bg-green-500" : tx.type === "borrow" ? "bg-blue-500" : "bg-gray-500"
                          }`}
                        />
                        <div>
                          <div className="font-medium capitalize">
                            {tx.type} {tx.type !== "claim" && `$${tx.amount.toLocaleString()}`}
                            {tx.type === "claim" && `$${tx.amount.toFixed(2)}`}
                          </div>
                          <div className="text-sm text-muted-foreground">
                            {tx.rate && `${tx.rate}% APR`}
                            {tx.collateral && ` • ${tx.collateral}`}
                            {" • " + new Date(tx.date).toLocaleDateString()}
                          </div>
                        </div>
                      </div>
                      <div className="flex items-center space-x-3">
                        <Badge variant={tx.status === "completed" ? "secondary" : "default"}>{tx.status}</Badge>
                        <Button variant="ghost" size="sm">
                          <ArrowUpRight className="h-4 w-4" />
                        </Button>
                      </div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </div>
    </div>
  )
}

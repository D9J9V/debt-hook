"use client"

import { useState } from "react"
import { Header } from "@/components/layout/header"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Progress } from "@/components/ui/progress"
import { Badge } from "@/components/ui/badge"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Clock, Info, Calendar, ArrowRight, Shield, AlertTriangle } from "lucide-react"

export default function BorrowPage() {
  const [selectedTerm, setSelectedTerm] = useState("90")
  const [borrowAmount, setBorrowAmount] = useState("")
  const [collateralAmount, setCollateralAmount] = useState("")
  const [selectedCollateral, setSelectedCollateral] = useState("ETH")
  const [maxRate, setMaxRate] = useState("")
  const [isSubmitting, setIsSubmitting] = useState(false)

  const markets = {
    "30": {
      currentRate: 8.5,
      minRate: 7.2,
      maxRate: 9.8,
      totalLiquidity: 125000,
      utilization: 68,
      nextAuction: "2h 15m",
      avgRate7d: 8.1,
      borrowers: 12,
    },
    "90": {
      currentRate: 12.2,
      minRate: 10.5,
      maxRate: 14.1,
      totalLiquidity: 89000,
      utilization: 45,
      nextAuction: "5h 42m",
      avgRate7d: 11.8,
      borrowers: 8,
    },
    "180": {
      currentRate: 15.8,
      minRate: 13.2,
      maxRate: 18.5,
      totalLiquidity: 156000,
      utilization: 72,
      nextAuction: "1h 33m",
      avgRate7d: 15.2,
      borrowers: 15,
    },
  }

  const collateralOptions = {
    ETH: { price: 3200, symbol: "ETH", name: "Ethereum", balance: 5.2, ltv: 75 },
    WLD: { price: 2.45, symbol: "WLD", name: "Worldcoin", balance: 1250, ltv: 65 },
    WBTC: { price: 67000, symbol: "WBTC", name: "Wrapped Bitcoin", balance: 0.15, ltv: 70 },
  }

  const currentMarket = markets[selectedTerm as keyof typeof markets]
  const currentCollateral = collateralOptions[selectedCollateral as keyof typeof collateralOptions]

  // Calculate required collateral based on LTV
  const requiredCollateralValue = borrowAmount ? Number.parseFloat(borrowAmount) / (currentCollateral.ltv / 100) : 0
  const requiredCollateralAmount = requiredCollateralValue / currentCollateral.price
  const currentLTV =
    borrowAmount && collateralAmount
      ? (Number.parseFloat(borrowAmount) / (Number.parseFloat(collateralAmount) * currentCollateral.price)) * 100
      : 0

  const interestCost =
    borrowAmount && maxRate
      ? (
          Number.parseFloat(borrowAmount) *
          (Number.parseFloat(maxRate) / 100) *
          (Number.parseInt(selectedTerm) / 365)
        ).toFixed(2)
      : "0"

  const totalRepayment =
    borrowAmount && interestCost ? (Number.parseFloat(borrowAmount) + Number.parseFloat(interestCost)).toFixed(2) : "0"

  const handleSubmit = async () => {
    setIsSubmitting(true)
    // Simulate transaction
    await new Promise((resolve) => setTimeout(resolve, 2000))
    setIsSubmitting(false)
  }

  const isValidLTV = currentLTV <= currentCollateral.ltv && currentLTV > 0
  const hasEnoughCollateral = Number.parseFloat(collateralAmount || "0") <= currentCollateral.balance

  return (
    <div className="min-h-screen bg-background">
      <Header />

      <div className="container mx-auto px-4 py-6 md:py-8">
        <div className="mb-8">
          <h1 className="text-3xl font-bold mb-2">Borrow USDC</h1>
          <p className="text-muted-foreground">Get fixed-rate loans against your crypto collateral</p>
        </div>

        <div className="grid lg:grid-cols-3 gap-6 md:gap-8">
          {/* Borrowing Form */}
          <div className="lg:col-span-2">
            <Card>
              <CardHeader>
                <CardTitle>Create Borrowing Order</CardTitle>
                <CardDescription>Set your terms and participate in the next auction</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4 md:space-y-6">
                {/* Term Selection */}
                <div>
                  <Label className="text-base font-medium">Select Term</Label>
                  <Tabs value={selectedTerm} onValueChange={setSelectedTerm} className="mt-2">
                    <TabsList className="grid w-full grid-cols-3">
                      <TabsTrigger value="30">30 Days</TabsTrigger>
                      <TabsTrigger value="90">90 Days</TabsTrigger>
                      <TabsTrigger value="180">180 Days</TabsTrigger>
                    </TabsList>
                  </Tabs>
                </div>

                {/* Borrow Amount */}
                <div>
                  <Label htmlFor="borrow-amount" className="text-base font-medium">
                    Borrow Amount
                  </Label>
                  <div className="relative mt-2">
                    <Input
                      id="borrow-amount"
                      type="number"
                      placeholder="0.00"
                      value={borrowAmount}
                      onChange={(e) => setBorrowAmount(e.target.value)}
                      className="text-base md:text-lg h-11 md:h-12 pr-16"
                    />
                    <div className="absolute right-3 top-1/2 transform -translate-y-1/2 text-muted-foreground">
                      USDC
                    </div>
                  </div>
                  <div className="mt-2 text-sm text-muted-foreground">
                    Available to borrow: ${currentMarket.totalLiquidity.toLocaleString()}
                  </div>
                </div>

                {/* Collateral Selection */}
                <div>
                  <Label className="text-base font-medium">Collateral Type</Label>
                  <Tabs value={selectedCollateral} onValueChange={setSelectedCollateral} className="mt-2">
                    <TabsList className="grid w-full grid-cols-3">
                      {Object.entries(collateralOptions).map(([key, option]) => (
                        <TabsTrigger key={key} value={key}>
                          {option.symbol}
                        </TabsTrigger>
                      ))}
                    </TabsList>
                  </Tabs>
                </div>

                {/* Collateral Amount */}
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <Label htmlFor="collateral-amount" className="text-base font-medium">
                      Collateral Amount
                    </Label>
                    <Badge variant="outline">Max LTV: {currentCollateral.ltv}%</Badge>
                  </div>
                  <div className="relative">
                    <Input
                      id="collateral-amount"
                      type="number"
                      placeholder="0.00"
                      value={collateralAmount}
                      onChange={(e) => setCollateralAmount(e.target.value)}
                      className="text-base md:text-lg h-11 md:h-12 pr-20"
                    />
                    <div className="absolute right-3 top-1/2 transform -translate-y-1/2 text-muted-foreground">
                      {currentCollateral.symbol}
                    </div>
                  </div>
                  <div className="flex justify-between mt-2 text-sm text-muted-foreground">
                    <span>
                      Balance: {currentCollateral.balance} {currentCollateral.symbol}
                    </span>
                    <span>
                      ${currentCollateral.price.toLocaleString()} per {currentCollateral.symbol}
                    </span>
                  </div>
                  {borrowAmount && (
                    <div className="mt-2 text-sm">
                      <span className="text-muted-foreground">Required collateral: </span>
                      <span className="font-medium">
                        {requiredCollateralAmount.toFixed(4)} {currentCollateral.symbol}
                      </span>
                    </div>
                  )}
                </div>

                {/* LTV Display */}
                {borrowAmount && collateralAmount && (
                  <div>
                    <div className="flex justify-between items-center mb-2">
                      <Label className="text-base font-medium">Loan-to-Value Ratio</Label>
                      <span className={`text-lg font-semibold ${isValidLTV ? "text-green-600" : "text-red-600"}`}>
                        {currentLTV.toFixed(1)}%
                      </span>
                    </div>
                    <Progress value={Math.min(currentLTV, 100)} className="h-2" />
                    <div className="flex justify-between mt-1 text-xs text-muted-foreground">
                      <span>0%</span>
                      <span>Safe: {currentCollateral.ltv}%</span>
                      <span>100%</span>
                    </div>
                  </div>
                )}

                {/* Maximum Rate */}
                <div>
                  <Label htmlFor="max-rate" className="text-base font-medium">
                    Maximum Rate (APR)
                  </Label>
                  <div className="relative mt-2">
                    <Input
                      id="max-rate"
                      type="number"
                      placeholder="0.0"
                      value={maxRate}
                      onChange={(e) => setMaxRate(e.target.value)}
                      className="text-base md:text-lg h-11 md:h-12 pr-12"
                      step="0.1"
                    />
                    <div className="absolute right-3 top-1/2 transform -translate-y-1/2 text-muted-foreground">%</div>
                  </div>
                  <div className="mt-2 text-sm text-muted-foreground">
                    Current market rate: {currentMarket.currentRate}%
                  </div>
                </div>

                {/* Validation Alerts */}
                {borrowAmount && collateralAmount && !isValidLTV && (
                  <Alert variant="destructive">
                    <AlertTriangle className="h-4 w-4" />
                    <AlertDescription>
                      LTV ratio too high. Maximum allowed is {currentCollateral.ltv}%. Add more collateral or reduce
                      borrow amount.
                    </AlertDescription>
                  </Alert>
                )}

                {collateralAmount && !hasEnoughCollateral && (
                  <Alert variant="destructive">
                    <AlertTriangle className="h-4 w-4" />
                    <AlertDescription>
                      Insufficient {currentCollateral.symbol} balance. You have {currentCollateral.balance}{" "}
                      {currentCollateral.symbol} available.
                    </AlertDescription>
                  </Alert>
                )}

                {/* Order Summary */}
                <div className="bg-muted/50 rounded-lg p-4">
                  <h3 className="font-medium mb-3">Loan Summary</h3>
                  <div className="space-y-2 text-sm">
                    <div className="flex justify-between">
                      <span>Borrow Amount:</span>
                      <span className="font-medium">{borrowAmount || "0"} USDC</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Collateral:</span>
                      <span className="font-medium">
                        {collateralAmount || "0"} {currentCollateral.symbol}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span>Term:</span>
                      <span className="font-medium">{selectedTerm} Days</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Maximum Rate:</span>
                      <span className="font-medium">{maxRate || "0"}% APR</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Interest Cost:</span>
                      <span className="font-medium">{interestCost} USDC</span>
                    </div>
                    <div className="border-t pt-2 mt-2">
                      <div className="flex justify-between font-medium">
                        <span>Total Repayment:</span>
                        <span className="text-primary">{totalRepayment} USDC</span>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Submit Button */}
                <Button
                  className="w-full h-11 md:h-12 text-base md:text-lg"
                  onClick={handleSubmit}
                  disabled={
                    !borrowAmount ||
                    !collateralAmount ||
                    !maxRate ||
                    !isValidLTV ||
                    !hasEnoughCollateral ||
                    isSubmitting
                  }
                >
                  {isSubmitting ? (
                    "Submitting Order..."
                  ) : (
                    <>
                      Submit Borrowing Order
                      <ArrowRight className="ml-2 h-4 w-4" />
                    </>
                  )}
                </Button>

                <div className="flex items-start space-x-2 text-sm text-muted-foreground">
                  <Info className="h-4 w-4 mt-0.5 flex-shrink-0" />
                  <p>
                    Your collateral will be locked if your order is matched. Ensure you can repay the loan by the
                    maturity date to avoid liquidation.
                  </p>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Market Info Sidebar */}
          <div className="space-y-6">
            {/* Current Market Stats */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center">
                  <Calendar className="h-4 w-4 mr-2" />
                  {selectedTerm} Day Market
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="text-center">
                  <div className="text-3xl font-bold text-primary">{currentMarket.currentRate}%</div>
                  <div className="text-sm text-muted-foreground">Current Rate</div>
                </div>

                <div className="space-y-3">
                  <div className="flex justify-between text-sm">
                    <span>7-day Average:</span>
                    <span className="font-medium">{currentMarket.avgRate7d}%</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span>Rate Range:</span>
                    <span className="font-medium">
                      {currentMarket.minRate}% - {currentMarket.maxRate}%
                    </span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span>Available Liquidity:</span>
                    <span className="font-medium">
                      ${(currentMarket.totalLiquidity * (1 - currentMarket.utilization / 100)).toLocaleString()}
                    </span>
                  </div>
                  <div>
                    <div className="flex justify-between text-sm mb-1">
                      <span>Utilization:</span>
                      <span className="font-medium">{currentMarket.utilization}%</span>
                    </div>
                    <Progress value={currentMarket.utilization} />
                  </div>
                  <div className="flex justify-between text-sm">
                    <span>Active Borrowers:</span>
                    <span className="font-medium">{currentMarket.borrowers}</span>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Collateral Info */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center">
                  <Shield className="h-4 w-4 mr-2" />
                  {currentCollateral.name}
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="flex justify-between text-sm">
                  <span>Current Price:</span>
                  <span className="font-medium">${currentCollateral.price.toLocaleString()}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span>Your Balance:</span>
                  <span className="font-medium">
                    {currentCollateral.balance} {currentCollateral.symbol}
                  </span>
                </div>
                <div className="flex justify-between text-sm">
                  <span>Max LTV:</span>
                  <span className="font-medium">{currentCollateral.ltv}%</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span>Liquidation Threshold:</span>
                  <span className="font-medium">{currentCollateral.ltv + 5}%</span>
                </div>
              </CardContent>
            </Card>

            {/* Auction Info */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center">
                  <Clock className="h-4 w-4 mr-2" />
                  Next Auction
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-center mb-4">
                  <div className="text-2xl font-bold">{currentMarket.nextAuction}</div>
                  <div className="text-sm text-muted-foreground">Time Remaining</div>
                </div>

                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span>Pending Orders:</span>
                    <span className="font-medium">8</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Total Demand:</span>
                    <span className="font-medium">$32,000</span>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Risk Warning */}
            <Card className="border-orange-200 bg-orange-50">
              <CardHeader>
                <CardTitle className="flex items-center text-orange-800">
                  <AlertTriangle className="h-4 w-4 mr-2" />
                  Important
                </CardTitle>
              </CardHeader>
              <CardContent className="text-sm text-orange-700 space-y-2">
                <p>• Your collateral will be locked for the entire loan term</p>
                <p>• Failure to repay by maturity may result in liquidation</p>
                <p>• Monitor your LTV ratio to avoid liquidation risk</p>
                <p>• Fixed rates mean no early repayment discounts</p>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </div>
  )
}

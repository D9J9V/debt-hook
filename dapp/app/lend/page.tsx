"use client"

import { useState } from "react"
import { Header } from "@/components/layout/header"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Progress } from "@/components/ui/progress"
import { Slider } from "@/components/ui/slider"
import { Clock, Info, Calendar, ArrowRight } from "lucide-react"

export default function LendPage() {
  const [selectedTerm, setSelectedTerm] = useState("90")
  const [lendAmount, setLendAmount] = useState("")
  const [minRate, setMinRate] = useState([10])
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
      lenders: 24,
    },
    "90": {
      currentRate: 12.2,
      minRate: 10.5,
      maxRate: 14.1,
      totalLiquidity: 89000,
      utilization: 45,
      nextAuction: "5h 42m",
      avgRate7d: 11.8,
      lenders: 18,
    },
    "180": {
      currentRate: 15.8,
      minRate: 13.2,
      maxRate: 18.5,
      totalLiquidity: 156000,
      utilization: 72,
      nextAuction: "1h 33m",
      avgRate7d: 15.2,
      lenders: 31,
    },
  }

  const currentMarket = markets[selectedTerm as keyof typeof markets]
  const projectedReturn = lendAmount
    ? (Number.parseFloat(lendAmount) * (minRate[0] / 100) * (Number.parseInt(selectedTerm) / 365)).toFixed(2)
    : "0"

  const handleSubmit = async () => {
    setIsSubmitting(true)
    // Simulate transaction
    await new Promise((resolve) => setTimeout(resolve, 2000))
    setIsSubmitting(false)
  }

  return (
    <div className="min-h-screen bg-background">
      <Header />

      <div className="container mx-auto px-4 py-6 md:py-8">
        <div className="mb-8">
          <h1 className="text-3xl font-bold mb-2">Lend USDC</h1>
          <p className="text-muted-foreground">Earn fixed returns by lending to verified humans</p>
        </div>

        <div className="grid lg:grid-cols-3 gap-6 md:gap-8">
          {/* Lending Form */}
          <div className="lg:col-span-2">
            <Card>
              <CardHeader>
                <CardTitle>Create Lending Order</CardTitle>
                <CardDescription>Set your terms and participate in the next auction</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4 md:space-y-6">
                {/* Term Selection */}
                <div>
                  <Label className="text-base font-medium">Select Term</Label>
                  <Tabs value={selectedTerm} onValueChange={setSelectedTerm} className="mt-2">
                    <TabsList className="grid w-full grid-cols-3 h-9 md:h-10">
                      <TabsTrigger value="30" className="text-xs md:text-sm">
                        30 Days
                      </TabsTrigger>
                      <TabsTrigger value="90" className="text-xs md:text-sm">
                        90 Days
                      </TabsTrigger>
                      <TabsTrigger value="180" className="text-xs md:text-sm">
                        180 Days
                      </TabsTrigger>
                    </TabsList>
                  </Tabs>
                </div>

                {/* Amount Input */}
                <div>
                  <Label htmlFor="amount" className="text-base font-medium">
                    Lending Amount
                  </Label>
                  <div className="relative mt-2">
                    <Input
                      id="amount"
                      type="number"
                      placeholder="0.00"
                      value={lendAmount}
                      onChange={(e) => setLendAmount(e.target.value)}
                      className="text-base md:text-lg h-11 md:h-12 pr-16"
                    />
                    <div className="absolute right-3 top-1/2 transform -translate-y-1/2 text-muted-foreground">
                      USDC
                    </div>
                  </div>
                  <div className="flex justify-between mt-2 text-sm text-muted-foreground">
                    <span>Balance: 50,000 USDC</span>
                    <Button variant="link" className="p-0 h-auto text-sm" onClick={() => setLendAmount("50000")}>
                      Use Max
                    </Button>
                  </div>
                </div>

                {/* Minimum Rate */}
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <Label className="text-base font-medium">Minimum Rate</Label>
                    <span className="text-lg font-semibold">{minRate[0]}%</span>
                  </div>
                  <Slider value={minRate} onValueChange={setMinRate} max={20} min={5} step={0.1} className="mt-2" />
                  <div className="flex justify-between mt-2 text-sm text-muted-foreground">
                    <span>5%</span>
                    <span>Current: {currentMarket.currentRate}%</span>
                    <span>20%</span>
                  </div>
                </div>

                {/* Order Summary */}
                <div className="bg-muted/50 rounded-lg p-4">
                  <h3 className="font-medium mb-3">Order Summary</h3>
                  <div className="space-y-2 text-sm">
                    <div className="flex justify-between">
                      <span>Lending Amount:</span>
                      <span className="font-medium">{lendAmount || "0"} USDC</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Term:</span>
                      <span className="font-medium">{selectedTerm} Days</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Minimum Rate:</span>
                      <span className="font-medium">{minRate[0]}% APR</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Next Auction:</span>
                      <span className="font-medium">{currentMarket.nextAuction}</span>
                    </div>
                    <div className="border-t pt-2 mt-2">
                      <div className="flex justify-between font-medium">
                        <span>Projected Return:</span>
                        <span className="text-primary">{projectedReturn} USDC</span>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Submit Button */}
                <Button
                  className="w-full h-11 md:h-12 text-base md:text-lg"
                  onClick={handleSubmit}
                  disabled={!lendAmount || isSubmitting}
                >
                  {isSubmitting ? (
                    "Submitting Order..."
                  ) : (
                    <>
                      Submit Lending Order
                      <ArrowRight className="ml-2 h-4 w-4" />
                    </>
                  )}
                </Button>

                <div className="flex items-start space-x-2 text-sm text-muted-foreground">
                  <Info className="h-4 w-4 mt-0.5 flex-shrink-0" />
                  <p>
                    Your order will be included in the next auction. If matched, funds will be locked for the selected
                    term.
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
                    <span>Total Liquidity:</span>
                    <span className="font-medium">${currentMarket.totalLiquidity.toLocaleString()}</span>
                  </div>
                  <div>
                    <div className="flex justify-between text-sm mb-1">
                      <span>Utilization:</span>
                      <span className="font-medium">{currentMarket.utilization}%</span>
                    </div>
                    <Progress value={currentMarket.utilization} />
                  </div>
                  <div className="flex justify-between text-sm">
                    <span>Active Lenders:</span>
                    <span className="font-medium">{currentMarket.lenders}</span>
                  </div>
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
                    <span className="font-medium">12</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Total Volume:</span>
                    <span className="font-medium">$45,000</span>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* How It Works */}
            <Card>
              <CardHeader>
                <CardTitle>How Lending Works</CardTitle>
              </CardHeader>
              <CardContent className="space-y-3 text-sm">
                <div className="flex items-start space-x-2">
                  <div className="w-5 h-5 rounded-full bg-primary text-primary-foreground text-xs flex items-center justify-center mt-0.5">
                    1
                  </div>
                  <p>Submit your lending order with desired amount and minimum rate</p>
                </div>
                <div className="flex items-start space-x-2">
                  <div className="w-5 h-5 rounded-full bg-primary text-primary-foreground text-xs flex items-center justify-center mt-0.5">
                    2
                  </div>
                  <p>Participate in periodic auctions where rates are determined</p>
                </div>
                <div className="flex items-start space-x-2">
                  <div className="w-5 h-5 rounded-full bg-primary text-primary-foreground text-xs flex items-center justify-center mt-0.5">
                    3
                  </div>
                  <p>If matched, your funds are locked for the fixed term</p>
                </div>
                <div className="flex items-start space-x-2">
                  <div className="w-5 h-5 rounded-full bg-primary text-primary-foreground text-xs flex items-center justify-center mt-0.5">
                    4
                  </div>
                  <p>Receive principal plus fixed interest at maturity</p>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </div>
  )
}

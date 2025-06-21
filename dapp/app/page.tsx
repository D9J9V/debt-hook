import { Header } from "@/components/layout/header"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Shield, TrendingUp, Clock, Users, ArrowRight } from "lucide-react"
import Link from "next/link"

export default function LandingPage() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-green-50">
      <Header />

      {/* Hero Section */}
      <section className="container mx-auto px-4 py-16 md:py-24">
        <div className="text-center max-w-4xl mx-auto">
          <Badge className="mb-4" variant="secondary">
            <Shield className="h-3 w-3 mr-1" />
            Powered by World ID & Uniswap V4
          </Badge>

          <h1 className="text-4xl md:text-6xl font-bold tracking-tight mb-6">
            Secure Fixed-Term
            <span className="text-primary block">DeFi Lending</span>
          </h1>

          <p className="text-xl text-muted-foreground mb-8 max-w-2xl mx-auto">
            The first DeFi lending protocol exclusively for verified humans. Fixed terms, market-driven rates, and
            predictable returns.
          </p>

          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Button size="lg" asChild>
              <Link href="/dashboard">
                Start Lending
                <ArrowRight className="ml-2 h-4 w-4" />
              </Link>
            </Button>
            <Button size="lg" variant="outline" asChild>
              <Link href="/borrow">Borrow USDC</Link>
            </Button>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="container mx-auto px-4 py-16">
        <div className="text-center mb-12">
          <h2 className="text-3xl font-bold mb-4">Why Choose Humane Banque?</h2>
          <p className="text-muted-foreground max-w-2xl mx-auto">
            Built for humans, by humans. Our protocol eliminates the uncertainty and risks of traditional DeFi lending.
          </p>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6">
          <Card>
            <CardHeader>
              <Clock className="h-8 w-8 text-primary mb-2" />
              <CardTitle className="text-lg">Fixed Terms</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                30, 90, or 180-day terms with guaranteed maturity dates. No duration mismatch risk.
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <TrendingUp className="h-8 w-8 text-primary mb-2" />
              <CardTitle className="text-lg">Market Rates</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                Interest rates determined by supply and demand through transparent auctions.
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <Shield className="h-8 w-8 text-primary mb-2" />
              <CardTitle className="text-lg">Human Verified</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                World ID verification prevents Sybil attacks and ensures fair price discovery.
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <Users className="h-8 w-8 text-primary mb-2" />
              <CardTitle className="text-lg">Over-Collateralized</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-sm text-muted-foreground">
                Secure lending with collateral protection and automatic liquidation mechanisms.
              </p>
            </CardContent>
          </Card>
        </div>
      </section>

      {/* Current Markets */}
      <section className="container mx-auto px-4 py-16">
        <div className="text-center mb-12">
          <h2 className="text-3xl font-bold mb-4">Active Markets</h2>
          <p className="text-muted-foreground">Current lending opportunities with live market rates</p>
        </div>

        <div className="grid md:grid-cols-3 gap-6 max-w-4xl mx-auto">
          {[
            { term: "30 Days", rate: "8.5%", available: "$125,000", borrowers: 12 },
            { term: "90 Days", rate: "12.2%", available: "$89,000", borrowers: 8 },
            { term: "180 Days", rate: "15.8%", available: "$156,000", borrowers: 15 },
          ].map((market) => (
            <Card key={market.term} className="text-center">
              <CardHeader>
                <CardTitle className="text-2xl">{market.term}</CardTitle>
                <CardDescription>Fixed Term Lending</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div>
                  <div className="text-3xl font-bold text-primary">{market.rate}</div>
                  <div className="text-sm text-muted-foreground">Current APR</div>
                </div>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span>Available:</span>
                    <span className="font-medium">{market.available}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Active Borrowers:</span>
                    <span className="font-medium">{market.borrowers}</span>
                  </div>
                </div>
                <Button className="w-full" variant="outline">
                  View Market
                </Button>
              </CardContent>
            </Card>
          ))}
        </div>
      </section>

      {/* How It Works */}
      <section className="container mx-auto px-4 py-16 bg-muted/30 rounded-lg my-16">
        <div className="text-center mb-12">
          <h2 className="text-3xl font-bold mb-4">How It Works</h2>
          <p className="text-muted-foreground max-w-2xl mx-auto">Simple, transparent, and secure lending process</p>
        </div>

        <div className="grid md:grid-cols-3 gap-8">
          <div className="text-center">
            <div className="w-12 h-12 bg-primary rounded-full flex items-center justify-center text-primary-foreground font-bold text-lg mx-auto mb-4">
              1
            </div>
            <h3 className="text-xl font-semibold mb-2">Verify & Connect</h3>
            <p className="text-muted-foreground">
              Connect your wallet and verify your humanity with World ID to access the platform.
            </p>
          </div>

          <div className="text-center">
            <div className="w-12 h-12 bg-primary rounded-full flex items-center justify-center text-primary-foreground font-bold text-lg mx-auto mb-4">
              2
            </div>
            <h3 className="text-xl font-semibold mb-2">Choose Terms</h3>
            <p className="text-muted-foreground">
              Select your preferred lending term (30, 90, or 180 days) and participate in rate auctions.
            </p>
          </div>

          <div className="text-center">
            <div className="w-12 h-12 bg-primary rounded-full flex items-center justify-center text-primary-foreground font-bold text-lg mx-auto mb-4">
              3
            </div>
            <h3 className="text-xl font-semibold mb-2">Earn Fixed Returns</h3>
            <p className="text-muted-foreground">
              Receive your principal plus fixed interest at maturity. No surprises, no volatility.
            </p>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="container mx-auto px-4 py-16 text-center">
        <div className="max-w-2xl mx-auto">
          <h2 className="text-3xl font-bold mb-4">Ready to Start?</h2>
          <p className="text-muted-foreground mb-8">
            Join the future of human-verified DeFi lending. Fixed terms, fair rates, secure returns.
          </p>

          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Button size="lg" asChild>
              <Link href="/dashboard">
                <Shield className="mr-2 h-4 w-4" />
                Get Started
              </Link>
            </Button>
            <Button size="lg" variant="outline">
              Learn More
            </Button>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t bg-muted/30 mt-16">
        <div className="container mx-auto px-4 py-8">
          <div className="flex flex-col md:flex-row justify-between items-center">
            <div className="flex items-center space-x-2 mb-4 md:mb-0">
              <Shield className="h-5 w-5 text-primary" />
              <span className="font-semibold">Humane Banque</span>
            </div>

            <div className="flex items-center space-x-6 text-sm text-muted-foreground">
              <span>Powered by Uniswap V4</span>
              <span>•</span>
              <span>Verified by World ID</span>
              <span>•</span>
              <span>Built on World Chain</span>
            </div>
          </div>
        </div>
      </footer>
    </div>
  )
}

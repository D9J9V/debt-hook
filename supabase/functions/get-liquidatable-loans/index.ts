import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

interface PriceData {
  ethPrice: number // ETH price in USD
  healthThreshold: number // e.g., 1.2 for 120% health factor threshold
}

serve(async (req) => {
  try {
    const { ethPrice, healthThreshold = 1.2 } = await req.json() as PriceData

    if (!ethPrice || ethPrice <= 0) {
      return new Response(
        JSON.stringify({ error: "Invalid ETH price" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      )
    }

    // Create Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Get all active loans
    const { data: loans, error } = await supabase
      .from("loans")
      .select("*")
      .eq("status", "active")
      .eq("loan_token", "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48") // USDC address

    if (error) {
      console.error("Error fetching loans:", error)
      return new Response(
        JSON.stringify({ error: "Failed to fetch loans" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      )
    }

    if (!loans || loans.length === 0) {
      return new Response(
        JSON.stringify({ liquidatableLoans: [] }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      )
    }

    const currentTime = Math.floor(Date.now() / 1000)
    const liquidatableLoans = []

    for (const loan of loans) {
      // Calculate current debt with interest
      const principal = BigInt(loan.loan_amount)
      const ratePerSecond = BigInt(loan.rate_per_second)
      const elapsed = BigInt(Math.min(currentTime - loan.start_time, loan.duration))
      const interest = (principal * ratePerSecond * elapsed) / BigInt(1e18)
      const currentDebt = principal + interest

      // Calculate collateral value in USD
      const collateralEth = BigInt(loan.collateral_amount)
      const collateralValueUsd = (Number(collateralEth) / 1e18) * ethPrice

      // Calculate current debt in USD (assuming USDC = $1)
      const debtValueUsd = Number(currentDebt) / 1e6

      // Calculate health factor
      const healthFactor = collateralValueUsd / debtValueUsd

      // Check if loan is liquidatable
      if (healthFactor < healthThreshold) {
        liquidatableLoans.push({
          loanId: loan.loan_id,
          borrower: loan.borrower,
          lender: loan.lender,
          collateralAmount: loan.collateral_amount,
          currentDebt: currentDebt.toString(),
          healthFactor: healthFactor.toFixed(4),
          collateralValueUsd: collateralValueUsd.toFixed(2),
          debtValueUsd: debtValueUsd.toFixed(2),
          profitableAt: calculateProfitablePrice(
            Number(collateralEth),
            Number(currentDebt),
            0.05 // 5% liquidation bonus
          )
        })
      }
    }

    // Sort by health factor (lowest first)
    liquidatableLoans.sort((a, b) => parseFloat(a.healthFactor) - parseFloat(b.healthFactor))

    return new Response(
      JSON.stringify({ 
        liquidatableLoans,
        totalLoans: loans.length,
        currentEthPrice: ethPrice,
        healthThreshold
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    )

  } catch (error) {
    console.error("Error checking liquidatable loans:", error)
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    )
  }
})

function calculateProfitablePrice(
  collateralWei: number,
  debtUsdc: number,
  liquidationBonus: number
): number {
  // Price at which liquidation becomes profitable
  // collateralValue * (1 + bonus) > debtValue
  const collateralEth = collateralWei / 1e18
  const debtUsd = debtUsdc / 1e6
  return debtUsd / (collateralEth * (1 + liquidationBonus))
}
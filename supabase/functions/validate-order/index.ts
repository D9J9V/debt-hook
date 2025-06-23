import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { ethers } from "https://esm.sh/ethers@6"

// EIP-712 Domain
const DOMAIN = {
  name: "DebtOrderBook",
  version: "1",
  chainId: 11155111, // Sepolia
}

// EIP-712 Types
const LOAN_ORDER_TYPE = {
  LoanOrder: [
    { name: "lender", type: "address" },
    { name: "borrower", type: "address" },
    { name: "collateralToken", type: "address" },
    { name: "loanToken", type: "address" },
    { name: "loanAmount", type: "uint256" },
    { name: "collateralAmount", type: "uint256" },
    { name: "ratePerSecond", type: "uint256" },
    { name: "duration", type: "uint256" },
    { name: "expiry", type: "uint256" },
    { name: "nonce", type: "uint256" },
  ],
}

interface LoanOrder {
  lender: string
  borrower: string
  collateralToken: string
  loanToken: string
  loanAmount: string
  collateralAmount: string
  ratePerSecond: string
  duration: number
  expiry: number
  nonce: number
}

interface OrderSignature {
  v: number
  r: string
  s: string
}

serve(async (req) => {
  try {
    const { order, signature } = await req.json() as {
      order: LoanOrder
      signature: OrderSignature
    }

    // Create Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Validate order parameters
    if (!order.lender || !ethers.isAddress(order.lender)) {
      return new Response(
        JSON.stringify({ error: "Invalid lender address" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      )
    }

    if (order.borrower && !ethers.isAddress(order.borrower)) {
      return new Response(
        JSON.stringify({ error: "Invalid borrower address" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      )
    }

    // Validate amounts
    const loanAmount = BigInt(order.loanAmount)
    const collateralAmount = BigInt(order.collateralAmount)
    if (loanAmount <= 0n || collateralAmount <= 0n) {
      return new Response(
        JSON.stringify({ error: "Invalid amounts" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      )
    }

    // Check expiry
    const currentTime = Math.floor(Date.now() / 1000)
    if (order.expiry <= currentTime) {
      return new Response(
        JSON.stringify({ error: "Order already expired" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      )
    }

    // Verify signature
    const orderHash = ethers.TypedDataEncoder.hash(DOMAIN, LOAN_ORDER_TYPE, order)
    const recoveredAddress = ethers.verifyTypedData(
      DOMAIN,
      LOAN_ORDER_TYPE,
      order,
      signature
    )

    if (recoveredAddress.toLowerCase() !== order.lender.toLowerCase()) {
      return new Response(
        JSON.stringify({ error: "Invalid signature" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      )
    }

    // Check if order already exists
    const { data: existingOrder } = await supabase
      .from("signed_orders")
      .select("id")
      .eq("order_hash", orderHash)
      .single()

    if (existingOrder) {
      return new Response(
        JSON.stringify({ error: "Order already exists" }),
        { status: 409, headers: { "Content-Type": "application/json" } }
      )
    }

    // Store the validated order
    const { data, error } = await supabase
      .from("signed_orders")
      .insert({
        order_hash: orderHash,
        lender: order.lender,
        borrower: order.borrower || null,
        collateral_token: order.collateralToken,
        loan_token: order.loanToken,
        loan_amount: order.loanAmount,
        collateral_amount: order.collateralAmount,
        rate_per_second: order.ratePerSecond,
        duration: order.duration,
        expiry: order.expiry,
        nonce: order.nonce,
        signature: signature,
        status: "pending"
      })
      .select()
      .single()

    if (error) {
      console.error("Database error:", error)
      return new Response(
        JSON.stringify({ error: "Failed to store order" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      )
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        orderId: data.id,
        orderHash: orderHash
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    )

  } catch (error) {
    console.error("Error validating order:", error)
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    )
  }
})
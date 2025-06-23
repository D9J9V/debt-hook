import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { ethers } from "https://esm.sh/ethers@6"

interface LoanCreatedEvent {
  loanId: string
  orderHash: string
  borrower: string
  transactionHash: string
  blockNumber: number
  timestamp: number
}

interface LoanStatusUpdateEvent {
  loanId: string
  status: 'repaid' | 'liquidated'
  transactionHash: string
  blockNumber: number
  timestamp: number
}

serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization")
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      )
    }

    const { eventType, data } = await req.json()

    // Create Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    switch (eventType) {
      case "LoanCreated": {
        const event = data as LoanCreatedEvent

        // Find the signed order by hash
        const { data: order, error: orderError } = await supabase
          .from("signed_orders")
          .select("*")
          .eq("order_hash", event.orderHash)
          .single()

        if (orderError || !order) {
          return new Response(
            JSON.stringify({ error: "Order not found" }),
            { status: 404, headers: { "Content-Type": "application/json" } }
          )
        }

        // Update signed order status
        await supabase
          .from("signed_orders")
          .update({ 
            status: "executed",
            executed_at: new Date().toISOString()
          })
          .eq("id", order.id)

        // Create loan record
        const { data: loan, error: loanError } = await supabase
          .from("loans")
          .insert({
            loan_id: event.loanId,
            order_id: order.id,
            lender: order.lender,
            borrower: event.borrower,
            collateral_token: order.collateral_token,
            loan_token: order.loan_token,
            loan_amount: order.loan_amount,
            collateral_amount: order.collateral_amount,
            rate_per_second: order.rate_per_second,
            duration: order.duration,
            start_time: event.timestamp,
            end_time: event.timestamp + order.duration,
            total_debt: calculateTotalDebt(
              BigInt(order.loan_amount),
              BigInt(order.rate_per_second),
              order.duration
            ).toString(),
            status: "active",
            creation_tx_hash: event.transactionHash
          })
          .select()
          .single()

        if (loanError) {
          console.error("Error creating loan:", loanError)
          return new Response(
            JSON.stringify({ error: "Failed to create loan record" }),
            { status: 500, headers: { "Content-Type": "application/json" } }
          )
        }

        return new Response(
          JSON.stringify({ success: true, loanId: loan.id }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        )
      }

      case "LoanRepaid": 
      case "LoanLiquidated": {
        const event = data as LoanStatusUpdateEvent
        const newStatus = eventType === "LoanRepaid" ? "repaid" : "liquidated"
        const updateField = eventType === "LoanRepaid" ? "repaid_at" : "liquidated_at"
        const txField = eventType === "LoanRepaid" ? "repayment_tx_hash" : "liquidation_tx_hash"

        const { error } = await supabase
          .from("loans")
          .update({
            status: newStatus,
            [updateField]: new Date().toISOString(),
            [txField]: event.transactionHash
          })
          .eq("loan_id", event.loanId)

        if (error) {
          console.error(`Error updating loan status:`, error)
          return new Response(
            JSON.stringify({ error: "Failed to update loan status" }),
            { status: 500, headers: { "Content-Type": "application/json" } }
          )
        }

        return new Response(
          JSON.stringify({ success: true }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        )
      }

      default:
        return new Response(
          JSON.stringify({ error: "Unknown event type" }),
          { status: 400, headers: { "Content-Type": "application/json" } }
        )
    }

  } catch (error) {
    console.error("Error processing event:", error)
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    )
  }
})

function calculateTotalDebt(principal: bigint, ratePerSecond: bigint, duration: number): bigint {
  const interest = (principal * ratePerSecond * BigInt(duration)) / BigInt(1e18)
  return principal + interest
}
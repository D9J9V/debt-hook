# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Next.js frontend for a DeFi lending protocol. It provides interfaces for borrowing, lending, and managing loan positions. The app uses shadcn/ui components and is designed to integrate with blockchain smart contracts via Web3 libraries.

## Common Commands

```bash
# Install dependencies
pnpm install

# Start development server
pnpm dev

# Build for production
pnpm build

# Start production server
pnpm start

# Run linter
pnpm lint

# Add shadcn/ui components
pnpm dlx shadcn@latest add <component-name>
```

## Architecture Overview

### Tech Stack
- **Framework**: Next.js 15.2.4 with App Router
- **Language**: TypeScript
- **UI Components**: shadcn/ui (built on Radix UI)
- **Styling**: Tailwind CSS
- **Forms**: React Hook Form + Zod validation
- **Web3**: Wagmi + Viem (to be integrated)
- **Data Storage**: Supabase (planned for off-chain orders)

### Page Structure

1. **`/borrow`**: Borrower interface
   - Browse available loan offers
   - Accept loans by providing collateral
   - Integrated with shadcn/ui Card and Table components

2. **`/lend`**: Lender interface
   - Create new loan offers
   - Set terms (amount, interest rate, duration)
   - Sign orders using EIP-712

3. **`/dashboard`**: Portfolio management
   - View active loans (as borrower or lender)
   - Monitor loan health
   - Initiate repayments or liquidations

4. **`/portfolio`**: Extended portfolio view
   - Detailed position analytics
   - Historical data

### Component Organization

- `components/ui/`: Auto-generated shadcn/ui components
- `components/layout/`: Layout wrappers (Header, Navigation)
- `lib/utils.ts`: Utility functions including `cn()` for className merging
- `app/globals.css`: Global styles with Tailwind directives

### Key Integration Points

1. **Web3 Connection**: Need to integrate Wagmi for wallet connection and contract interaction
2. **Order Management**: Implement Supabase client for storing/retrieving signed orders
3. **Contract ABIs**: Import from blockchain build artifacts
4. **Real-time Updates**: Consider implementing WebSocket or polling for position updates

## Development Notes

1. **Shadcn/ui Usage**: Components are copied into the project. Customize them in `components/ui/`

2. **Form Validation**: Use Zod schemas for all form inputs. Example pattern:
   ```typescript
   const schema = z.object({
     amount: z.number().positive(),
     duration: z.number().min(1)
   })
   ```

3. **Error Handling**: Implement proper error boundaries and toast notifications for transaction feedback

4. **State Management**: Currently using React state. Consider React Query for server state and blockchain data caching

5. **Environment Variables**: Set up `.env.local` with:
   - RPC endpoints
   - Contract addresses
   - Supabase credentials
   - WalletConnect project ID

6. **TypeScript**: Maintain strict typing, especially for Web3 data structures matching the smart contract interfaces
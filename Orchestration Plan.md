# Dorm Store App — Orchestration & Delivery Plan

This plan translates the Master Plan into an execution model your team can run week to week.

## 1) Delivery Model

- **Cadence:** 1-week sprints, with daily 15-minute standups.
- **Branch strategy:** `main` (protected), feature branches per ticket, PR required for merge.
- **Definition of Ready (DoR):** ticket has user story, acceptance criteria, data impact (Sheets tabs/columns), and test notes.
- **Definition of Done (DoD):** feature works on mobile, has error handling, passes lint/typecheck/tests, and includes update to docs if data contracts changed.

## 2) Team Roles (Suggested)

- **Product/Operations Lead (Shopkeeper liaison):** prioritizes backlog, validates workflows.
- **Tech Lead:** architecture decisions, PR review gate, release coordination.
- **Full-stack Dev:** Next.js routes/components and API integration.
- **QA Owner (can be rotating):** test plans, regression checklist, UAT sign-off.

## 3) Workstreams

Run these in parallel where possible:

1. **Platform & Auth**
   - Next.js setup, OAuth, middleware, environment management.
2. **Data Layer & Sheets Contracts**
   - `lib/sheets.ts`, schema validation, transaction-safe update flows.
3. **Storefront UX**
   - `/store`, cart, checkout UX, mobile polish.
4. **Admin Operations**
   - item CRUD, stock receiving, reports.
5. **Reliability & Analytics**
   - retries/backoff, observability, daily summary jobs.

## 4) Execution Roadmap (First 6 Weeks)

## Week 0 — Project Setup & Controls

- Create GitHub project board with columns: Backlog, Ready, In Progress, Review, Done.
- Add PR template requiring: scope, screenshots, test evidence, rollout notes.
- Set repository protections: required review + status checks.
- Finalize environment variable management (local `.env`, Vercel project vars).

**Exit criteria:** Team can create, review, and deploy a no-op PR end to end.

## Week 1 — Foundation Build

- Scaffold Next.js + TypeScript + Tailwind.
- Implement NextAuth Google sign-in + domain restriction + admin allowlist.
- Set up Google Sheet workbook and service account permissions.
- Build minimal `lib/sheets.ts` read/append/update helpers.

**Exit criteria:** Authenticated user can hit `/store` and fetch `items` data.

## Week 2 — Core Buying Flow

- Item grid with in-stock, low-stock, and unavailable states.
- Cart state and quantity cap logic against available stock.
- Checkout page with required student fields.
- Checkout API: stock re-check, transactions write, stock decrement, stock log append.

**Exit criteria:** Successful purchase persists correctly across all relevant tabs.

## Week 3 — Admin Inventory Operations

- `/admin/items`: add/edit/soft-delete/toggle stock.
- `/admin/stock`: receive stock workflow and audit log visibility.
- Admin route protection and unauthorized redirect coverage.

**Exit criteria:** Shopkeeper can fully maintain inventory without editing Sheets manually.

## Week 4 — Reports & Daily Summary

- `/admin/reports` with date filtering.
- Daily summary aggregation endpoint + manual trigger.
- Vercel cron setup for automatic daily summary run.

**Exit criteria:** Team can produce daily revenue/cost/profit outputs from app flow.

## Week 5 — Hardening & UAT

- Improve load/error states and edge-case handling.
- Add retry/backoff around Sheets API failures.
- Execute UAT with real school accounts and realistic load scenarios.

**Exit criteria:** UAT checklist signed off by operations lead.

## Week 6 — Launch Readiness

- Run production checklist and incident playbook review.
- Freeze scope except critical bugs.
- Tag release and perform controlled rollout.

**Exit criteria:** Production launch with rollback plan ready.

## 5) Ticket Structure (Template)

Every ticket should include:

- **User story**
- **Acceptance criteria** (Given/When/Then)
- **Data impact** (which Sheets tabs/fields are read or written)
- **Failure modes** (what happens when Sheets read/write fails)
- **Test plan** (manual + automated checks)

## 6) Quality Gates

- **On every PR:**
  - `npm run lint`
  - `npm run typecheck` (or `tsc --noEmit`)
  - tests for changed behavior
- **Before merge:**
  - mobile viewport check for changed pages
  - one reviewer approval minimum
- **Before release:**
  - smoke test: login, browse, checkout, admin item update, stock receive, summary run

## 7) Risks & Mitigations

- **Risk: Sheets concurrency conflicts at checkout**
  - Mitigation: re-read stock immediately before commit; fail gracefully with retry message.
- **Risk: API quota/rate limit spikes**
  - Mitigation: exponential backoff and compact batched writes where possible.
- **Risk: admin misconfiguration**
  - Mitigation: startup validation of required env vars + clear admin settings docs.
- **Risk: mobile usability issues**
  - Mitigation: phone-first acceptance criteria on all user-facing tickets.

## 8) Operational Playbooks

- **Daily open routine:** verify stock sheet health, check low-stock list, confirm prior day summary exists.
- **Incident routine:** identify impacted route/API, switch to safe mode message, resolve sheet permissions/quota, rerun failed summary jobs.
- **Weekly routine:** backlog grooming, metrics review (orders/day, failed checkouts, stock discrepancies).

## 9) Suggested Immediate Next 10 Tickets

1. Bootstrap Next.js app with TypeScript/Tailwind and baseline layout.
2. Implement Google OAuth sign-in and domain-restricted access.
3. Add session-based admin role helper + middleware for `/admin/*`.
4. Build strongly-typed Sheets client (`items`, `transactions`, `stock_log`, `daily_summary`).
5. Build `/store` item grid with three availability states.
6. Build cart state module with quantity caps.
7. Build `/checkout` form and cart summary UI.
8. Implement checkout mutation endpoint with stock race-condition protection.
9. Build `/admin/items` CRUD and toggle actions.
10. Build `/admin/stock` receive workflow + stock log table.

## 10) How to Keep the Master Plan Current

Update the Master Plan at the end of each sprint with:

- completed milestones,
- any schema changes to Sheets tabs,
- newly discovered constraints,
- and launch readiness delta (what remains before go-live).


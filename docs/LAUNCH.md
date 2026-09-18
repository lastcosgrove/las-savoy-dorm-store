# Launch plan and operator runbook

## Prepared now

The Next.js app and immutable local ledger are runnable. The applied Supabase migration lives in `supabase/migrations/20260918073924_dorm_store_core.sql`. Unit tests exercise checkout rollback, UUID retry idempotency, receipt preservation, single-use voids, stock correction, prefect restrictions and sync acknowledgements.

## Next deployment steps

1. **Completed:** created `las-savoy-dorm-store` under **Leysin American School** in Frankfurt (`eu-central-1`). Supabase quoted $0/month and returned healthy status. Project reference: `wjabiyxldknqheouoekc`. [Dashboard](https://supabase.com/dashboard/project/wjabiyxldknqheouoekc).
2. **Foundation completed:** applied the core migration and ran `supabase/tests/ledger_security.sql` against real Postgres. Authorization, exact UUID retries, stock restoration, immutable original receipts, duplicate void rejection and rollback passed. The security advisor reported only informational notices for six deliberately inaccessible tables with RLS and no direct-access policies; [Supabase explains this notice](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy). Public RPCs are caller-rights wrappers; privileged implementations remain in the private schema. Add live admin RPCs and server-verified PIN/device leases before enabling production mode. Concurrent multi-connection tests remain pending.
3. Configure live authentication and provision operators. Keep the practice namespace separate. Never send its outbox or fictional people to the real database. Add a catalog bootstrap and dependency-ordered outbox transport, and verify rejected events remain visible locally.
4. Use the connected Vercel account to select the school team/project and deploy a practice preview from the review branch. Vercel was confirmed connected in this conversation, but no callable Vercel tools were exposed in the active tool registry at build time; deployment still needs that capability or approved browser access. The repository is ready for a standard Next.js import.
5. Verify the production PWA on the actual laptop: cold offline reload, storage persistence, disk-space failure, restart during a pending queue, reconnect retries, duplicate confirmation, shared-device shift recovery and resolved backlog.
6. Import approved student data, real products/prices/photos, and opening stock after staff access is secured. Establish a full ledger backup outside the laptop and a tested restore process.
7. Run a staff-only evening before general use. Check the exported billing amounts against the local receipts and cloud rows. Then authorize normal operation.

## Opening a practice shift

Choose Open register, select Alex Morgan (staff, 1234) or Sam Taylor (prefect, 1111). If yesterday's shift is still open, resume it with its PIN; staff may close another operator's old shift with the actual end time. Pick a fictional student using Find student, tap products, and Confirm. The next order starts with no student or cart selected.

## Corrections

Before confirming, use minus on a cart line or Escape. After confirming, open Staff tools → Transactions → Void, provide a reason and staff PIN. The original receipt stays intact; the reversal restores stock. Receive deliveries through Inventory; never adjust quantities by changing a product field. Count shelves when the register is idle.

## If wifi drops

Practice mode is always local. In the future live mode, sales must continue into IndexedDB and the visible pending count must remain until an exact cloud acknowledgement arrives. Never clear site data to troubleshoot a backlog. Export records first and contact the designated maintainer. An initial load of the PWA is required before offline use.

## If the reader fails

Use Find student. Verify their school number/name. Do not type raw card identifiers into logs or support tickets. Unknown cards are linked only after the operator confirms the roster identity. Staff can unlink a lost card before enrolling its replacement.

## If the laptop fails

Stop using this register. Use the school's agreed paper fallback with timestamp, student number, items and operator; preserve it for controlled reconciliation. A browser profile export or a spreadsheet mirror is not a database backup.

## Business-office export

The current CSV contains original and reversing transactions; sum the Total CHF column for net charges. The practice export is labelled as practice in its filename. Formula-like text cells are escaped. A later Google Sheets mirror must be one-way and protected; corrections always originate in the app.

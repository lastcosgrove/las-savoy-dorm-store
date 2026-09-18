# Launch plan and operator runbook

## Prepared now

The Next.js app and immutable local ledger are runnable. A draft Supabase migration lives in `supabase/migrations/202609180001_core.sql`. Unit tests exercise checkout rollback, UUID retry idempotency, receipt preservation, single-use voids, stock correction, prefect restrictions and sync acknowledgements.

## Next deployment steps

1. User selects the Supabase organization. The connected account currently reports **Leysin American School** and no projects. The provider explicitly requires this selection and cost confirmation before project creation. Prefer Frankfurt (`eu-central-1`); Zurich can be selected if available and preferred.
2. Create the selected EU project, apply migrations in staging, run advisors and exercise anonymous/prefect/staff negative authorization tests. Validate concurrent retries and cross-device UUID conflicts against real Postgres. Add live admin RPCs and server-verified PIN/device leases before enabling production mode.
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

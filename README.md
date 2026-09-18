# LAS Savoy Dorm Store

A staff-operated, local-first register for the Savoy dorm store at Leysin American School. This supersedes the original student self-checkout / Google Sheets database concept in `Master Plan`.

## Current status

**Working practice build, not approved for live billing.** Fictional students, operators and products are seeded into the separate `las-savoy-practice-v1` IndexedDB database. Practice data never goes to Supabase or school accounts. No real student data belongs in this deployment yet.

Implemented:
- Operator PINs, shift start/resume/close and stale-shift handling.
- Student lookup, CSV roster import, card linking/replacement with device-specific HMAC identifiers, and keyboard-wedge input abstraction.
- Dark register with product tiles, item quantities, CHF prices, atomic local checkout and staff tools separated from the register.
- Immutable sale snapshots and compensating void records; derived inventory, deliveries and recounts with preserved variance.
- Product management, image uploads, ordering, transaction search and CSV exports with formula-injection protection.
- PWA manifest, offline shell and persistent IndexedDB storage.
- Durable event outbox, separately tested retry worker, and draft Supabase schema with restricted RLS and atomic sale/void RPCs.

**Not yet connected:** live operator authentication, provisioned EU Supabase database, device authorization, the production sync transport, live catalog administration, Google Sheets, physical NFC hardware, spending-limit enforcement, backups and retention scheduling. The outbox accurately reports local-only state and never claims to be cloud-synced.

## Run

```sh
npm ci
npm run dev
npm run test
npm run build
npm start
```

Open localhost:3000. Practice staff: **Alex Morgan / 1234**. Practice prefect: **Sam Taylor / 1111**. Do not reuse these PINs in production.

Test the offline app against a production build: open it online once, wait for the service worker to activate and cache the application assets, then take the browser offline and reload. First-ever use still requires a connection.

Keyboard: Alt+1–9 adds the corresponding product; Enter confirms; Escape clears the unconfirmed order. Alt avoids confusing scanner digits with quantity shortcuts. Reader input inside a form must use the explicit test field; keyboard-wedge scans otherwise use a timing buffer.

## Production setup

See [docs/LAUNCH.md](docs/LAUNCH.md) and [docs/SPEC_REVIEW.md](docs/SPEC_REVIEW.md). Apply the SQL only after selecting the school organization and confirming project cost/region. The migration is a foundation, not a claim of finished live integration. Do not enable real charges by changing a UI label or attaching the practice outbox.

Vercel can import this repository as a Next.js project using the checked-in lockfile. The current build needs no secrets because it is practice-only. A deployed practice URL is not a launch approval.

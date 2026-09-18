# Build-spec review

The September 17 specification is the source of truth. The existing GitHub README and Master Plan describe an earlier student self-checkout architecture and should not guide this implementation.

## Retained decisions

Staff/prefect checkout, existing-card identification where hardware permits, school-account charges, IndexedDB as the first write target, append-only transactions, movement-derived stock, and one-way business-office exports are coherent choices for one dedicated register. Students do not need accounts, phones or a payment processor.

## Corrections needed before production

1. **Void reference direction:** replace `voided_by` updates on the original with `original_transaction_id` on the new reversal. Enforce one reversal per original sale with a unique constraint. The local implementation does this and preserves original rows.
2. **DDL order:** operators must exist before price history references them; count sessions must exist before stock movements reference them. The draft migration fixes this.
3. **Atomic synchronization:** a sale, its lines and stock movements must arrive in one database transaction. Independent inserts risk a charge without its stock movement. The draft RPC accepts a complete sale and checks UUID retries for identical payloads.
4. **Real authorization:** a shared register password plus a browser-only PIN cannot establish a trustworthy database role. Production needs server-verified operator identity / short-lived operator leases with revocation and rate limits. The draft migration uses Supabase Auth identity mapped to an operator as its trust boundary. Shared-login PIN lease integration is still a launch gate.
5. **Offline credentials:** the live register needs a provisioned, time-limited offline authorization policy. Production PIN secrets should not be exposed in the catalog. The local practice PBKDF2 verifiers are for training only, and client-side PIN checks are not a production security boundary.
6. **Card hashing:** a secret embedded in browser JavaScript is not a server secret. Provision a device key and define replacement/rotation. Practice uses a device-specific HMAC key, never raw identifiers. This is not a claim that the key is protected from someone controlling the laptop.
7. **NFC transport:** direct ACR122U browser access is unverified. Stable UID, device/driver behavior and reader transport need testing; the application interface supports a keyboard wedge today. No purchase recommendation follows from the current build.
8. **Offline price changes:** resolve stale prices explicitly. The draft server validates historical prices at the sale timestamp and retains rejected events for review; device clocks also need a defined policy.
9. **Retention vs immutability:** the normal role cannot edit/delete the ledger. An approved, privileged retention procedure must aggregate billing records and remove detail on schedule without breaking audit integrity. Not implemented pending school policy.
10. **Inventory recounts:** count at shift close or pause sales while counting. Otherwise expected quantities need snapshot handling across concurrent movements. The single-device practice count commits its corrections atomically.

## Unanswered school decisions

- Do five reads of the same school card return the same UID?
- Are limits required at launch, and are they weekly/monthly/term-based?
- Does billing initially want CSV or a Google Sheets mirror?
- Which staff member owns maintenance, exports and backups when the primary owner is absent?

The first build leaves limits disabled, supports manual lookup, provides CSV, and makes practice mode explicit. It must not receive real student data until production authentication and sync are tested.

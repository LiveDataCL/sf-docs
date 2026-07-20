# BarberPilot / Salon Men Saúl Fino — Technical Debt Tracker

Living document — update this file whenever new debt is found or existing debt is
closed, rather than leaving it scattered across chat history. Spans all four repos
(`barberpilot-api`, `barberpilot-control`, `saulfino-web`, `BarberPilot_App`), which is
why it lives here in `sf-docs` rather than in any single repo's own `docs/`.

Each entry: date found, description, severity, urgency, why it wasn't fixed immediately,
risk if left unaddressed, and status (open / closed, with closure date if applicable).

---

## Open

### 2. Queue `ABANDONED` auto-cleanup (Migration 008) uses UTC `CURRENT_DATE`, not Santiago-local

- **Date found:** 2026-07-13, while investigating why 100% of currently-open queue
  entries showed `status = 'ABANDONED'` instead of the documented WAITING/IMMINENT/
  IN_SERVICE lifecycle.
- **Description:** `barberpilot-api/index.js:5289-5302` ("Migration 008") abandons stale
  queue entries with `(checkin_at AT TIME ZONE 'America/Santiago')::date < CURRENT_DATE`.
  `CURRENT_DATE` resolves in the DB session's timezone, confirmed via `SHOW timezone` to
  be `Etc/UTC`, not Santiago's. Chile is UTC-4 in July, so there's a genuine ~4-hour
  window every night (Santiago 20:00–24:00 = UTC 00:00–04:00) where, if the server
  restarts in that window, an entry checked in earlier that same Santiago evening would
  show as "from a previous day" and get wrongly abandoned a day early.
- **Severity:** Low
- **Urgency:** Monitor-only
- **Why not fixed immediately:** Out of scope for July 16; investigated only to
  determine whether it explained the observed 100%-abandoned state (it doesn't — see
  investigation notes in `barberpilot-api/docs/july16_verification_checklist.md` §6b;
  the actual cause is tickets not being closed via `/queue/control/registrar` at all,
  with gaps of 1-17+ days between check-in and abandonment, not tight midnight crossings).
- **Risk if unaddressed:** Only matters if a server restart lands in the 4-hour Santiago
  midnight window (20:00–24:00 local = 00:00–04:00 UTC) while a real ticket is still
  open — would prematurely mark it `ABANDONED` (setting `service_end=NOW()`) a day
  before it should be.
- **Recommended fix:** Swap `CURRENT_DATE` for `(NOW() AT TIME ZONE 'America/Santiago')::date`.
- **Status:** Open.

### 3. `PaymentSheet.js` resolves service name via raw string match, not `servicio_alias`

- **Date found:** 2026-07-13, empirically checked during Expo cutover review.
- **Description:** `PaymentSheet.js` finds the catalog entry via
  `SERVICIOS.find(s => s.nom.trim().toLowerCase() === entry.service.trim().toLowerCase())`
  — a raw match against `nombre_canonico`, not alias-aware resolution like the backend's
  `resolverServicioYValidarPrecio` (which goes through `servicio_alias`). Simulated the
  exact match logic against all 531 historical `queue.service` values: **83.4% match
  cleanly, 16.6% (88 entries) fall through to manual price entry** — almost entirely
  (87 of 88) the `'Corte Clásico'` vs. server's `'Corte'` naming variant.
- **Severity:** Low
- **Urgency:** Near-term
- **Why not fixed immediately:** Deferred per César's implicit agreement this round.
  Fixing properly means exposing `servicio_alias` data to the app (server-side surface
  change: `GET /config/negocio` would need to return aliases per service, which it
  already computes in `fetchServiciosActivos()` but doesn't currently need to for its
  existing consumers) — a bigger lift than fits in the July 16 scope.
- **Risk if unaddressed:** Not a pricing-correctness risk — write-time validation
  (`resolverServicioYValidarPrecio` via `POST /registros`) still catches and rejects a
  mismatched manually-typed price. It's a real, measured UX/workflow friction gap:
  roughly 1 in 6 real transactions closed via this screen force the barber to type the
  price manually instead of getting it auto-filled.
- **Status:** Open.

### 4. `/queue/control/registrar`'s `precioOverride` has no `override`/`override_reason` UI equivalent

- **Date found:** 2026-07-13, noted while scoping the `servicio_inactivo` retirement
  guard fix for the July 16 change.
- **Description:** `POST /registros` supports a documented override flow — a price
  mismatch is rejected unless the caller sends `override:true` plus a
  non-empty `override_reason`, which gets logged to `registro_precio_override`.
  `/queue/control/registrar`'s `precioOverride` field has no equivalent reason-logging
  or explicit-override-flag mechanism; it just silently accepts whatever price staff type
  in barberpilot-control's Sala editor.
- **Severity:** Low
- **Urgency:** Eventual
- **Why not fixed immediately:** Not itself broken — this is a pre-existing, working,
  legitimate staff workflow (e.g. discretionary discounts). Flagged only as an asymmetry
  between the two write paths worth resolving for consistency, not an active defect.
- **Risk if unaddressed:** Price overrides made via the Sala Cola-closing flow aren't
  logged/reasoned the way `POST /registros` overrides are — an audit-trail gap, not a
  correctness one.
- **Status:** Open.

### 5. `registros_audit.modificado_por` reads a client-typed free-text field, not `req.actorIdentity`

- **Date found:** Not specified in available session context — predates 2026-07-13
  (referenced as an earlier-project finding, not something surfaced during this week's
  July 16 sweep).
- **Description:** `registros_audit.modificado_por` is still populated from a client-
  supplied free-text field rather than the now-established `req.actorIdentity` pattern
  used elsewhere (e.g. the `registro_precio_override` audit logging added this project).
- **Severity:** Medium
- **Urgency:** Near-term
- **Why not fixed immediately:** Fix is designed and ready to apply, but is pending
  César's direct in-person confirmation to Claude Code specifically — not relayed
  through a chat message — per a standing rule from earlier in this project for this
  particular class of change.
- **Risk if unaddressed:** Audit trail for this field can be spoofed or inaccurate since
  it trusts client-supplied text rather than the server-verified actor identity already
  available on every authenticated request.
- **Status:** Open — blocked on César's direct confirmation, not on further design work.

### 7. Unjustified `OR estado IS NULL` clause, widespread across `barberpilot-api`

- **Date found:** 2026-07-13, while building the goal-unification server-side migration
  — flagged and investigated because it was never agreed anywhere in this project's
  history and doesn't match the "only `estado = 'confirmado'` counts as real revenue"
  convention used everywhere else.
- **Description:** `WHERE ... AND (estado = 'confirmado' OR estado IS NULL)` appears in
  at least 4 places in `barberpilot-api/index.js` (~lines 916, 1479, 2407, 4789,
  including `GET /stats/mes/:periodo` itself — the route `dashboard-facturacion.html`'s
  goal figures are computed from). Queried production: **zero rows in `registros` have
  `estado IS NULL`** — every row is either `'confirmado'` (1,373 rows) or `'rechazado'`
  (8 rows, correctly excluded). So there's no legacy pre-`estado`-column category this
  clause is protecting; it appears to be an unreviewed carryover, copy-pasted forward
  each time a new query needed this filter.
- **Severity:** Low
- **Urgency:** Monitor-only
- **Why not fixed immediately:** Out of scope for the goal-unification round it was
  found in — fixed only in the one new function that round added
  (`calcularMetaAnchorServicios`), which now uses the strict `estado = 'confirmado'`
  filter. The other 4 pre-existing occurrences were left untouched, since fixing all of
  them is a broader, separate change.
- **Risk if unaddressed:** Currently a no-op — zero NULL-estado rows exist in production.
  Latent: if anything ever inserts a `registros` row with NULL `estado` not intending it
  as confirmed revenue, all 4 affected queries (stats, per-day barber totals, per-day
  service-duration lookups, WhatsApp-pending index) would silently include it as real.
- **Status:** Open.

### 8. `NEON_DATABASE_URL` env var name obscures its disaster-recovery-only purpose

- **Date found:** 2026-07-19, during roster transition for Winder (b6) / Samuel (b3) deactivation.
- **Description:** Railway's environment for `barberpilot-api` contains a variable named
  `NEON_DATABASE_URL` pointing to the Neon.tech warm-standby DR replica. The generic name
  (reads as "another database URL") led to its accidental use as a connectivity workaround
  when `DATABASE_URL`'s internal Railway hostname (`postgres-gl9n.railway.internal`) couldn't
  be reached from outside Railway's private network — causing two ad-hoc SQL steps (Step 1:
  Winder insert; Step 2: Samuel deactivation) to run against the Neon replica instead of the
  Railway primary. Both steps were subsequently corrected in Railway via Migrations 009 and
  009a, and the Neon replica was confirmed to be an accurate copy, so no data integrity harm
  resulted. But the root trigger was purely the ambiguous env var name.
- **Severity:** Medium
- **Urgency:** Near-term
- **Why not fixed immediately:** Environment variable changes in Railway are a manual
  operation in the Railway dashboard — outside the scope of a code commit, and a decision
  reserved for César rather than automated tooling.
- **Risk if unaddressed:** No live code path in `index.js` reads `NEON_DATABASE_URL`
  (confirmed grep: zero hits), so the variable is inert for the running API. Risk is
  procedural: an operator under time pressure could repeat the same workaround and run
  production-altering SQL against the wrong database without realizing it.
- **Recommended fix:** Rename `NEON_DATABASE_URL` to `NEON_DR_URL` or `NEON_STANDBY_URL`
  in the Railway environment variables dashboard. Either name makes the disaster-recovery
  purpose unambiguous and prevents any future script from treating it as a general-purpose
  alternative connection string. The credential itself (the Neon.tech connection string)
  stays unchanged — only the Railway env var name changes. Existing safeguards
  (`seed-staging.js` ABORT guard, `env.staging.example` comment) continue to work
  regardless of the rename.
- **Status:** Open — pending César's decision on the Railway dashboard rename.

### 9. `COM_PAGO` commission rates duplicated in `barberpilot-api` and `barberpilot-control`

- **Date found:** 2026-07-19, noted while removing `SERVICE_PRICES` from `barberpilot-api/index.js`
  during the server-driven price/roster cutover (Steps A+B).
- **Description:** Commission rates per payment method (`efectivo: 0.50`, `debito: 0.43`,
  `transferencia: 0.50`) are hardcoded in two places:
  1. `barberpilot-api/index.js` — `COM_PAGO` constant (used by `POST /queue/control/registrar`
     to compute `bb` / `neg` when closing a queue entry)
  2. `barberpilot-control/index.html` — `COM` object (used for the live split preview in the
     Sala editor and cierre de caja flow)
  These must stay in sync manually. `SERVICE_PRICES` was the analogue for prices — it was
  removed in this round because `resolverServicioYValidarPrecio` now supplies the catalog
  price. Commission rates don't have an equivalent DB table yet, so the duplication remains.
- **Severity:** Medium
- **Urgency:** Eventual
- **Why not fixed immediately:** `COM_PAGO` is not in scope for the current cutover (Steps A–D),
  which is focused on eliminating hardcoded prices and rosters from client files. A commission
  table would require a new migration, a new API field, and updates across every consumer of
  the split preview (control, possibly the app) — a separate, larger lift.
- **Risk if unaddressed:** A commission rate change (e.g. the débito rate changes from 43% to
  45%) requires editing two files and redeploying both repos. Worse: `barberpilot-api` computes
  the *actual* `bb`/`neg` stored in `registros`, while `barberpilot-control` computes the
  *preview* shown before confirming — if they drift, the preview shown to staff would be wrong
  while the ledger entry is correct, creating confusion without a billing error.
- **Recommended fix:** Add a `tenant_comisiones` table (or extend `tenant_metas`) with
  per-payment-method rates, expose via `GET /config/negocio`, and have `barberpilot-control`
  read `com_rates` from the server response for its preview. `barberpilot-api` already has the
  route; it would just need to read from the table instead of `COM_PAGO`.
- **Status:** Open.

### 10. Revert endpoint doesn't check `activo` before restoring a service's prior price

- **Date found:** 2026-07-20, during Phase 2 Step 1 review.
- **Description:** `POST /api/v2/config/servicios/:servicio_id/precio/revertir` queries
  the current active price row and the immediately-prior row, then closes and reopens
  without first verifying that the service itself is still `activo = true`. In the
  normal case this is harmless — `GET /config/negocio/publico` only surfaces active
  services, so a retired service's price is unreachable from any live UI. The gap only
  bites if an admin manually POSTs to the revert endpoint for a service that has since
  been deactivated, which would silently create a live price row for a service that no
  consumer will render or validate against.
- **Severity:** Low
- **Urgency:** Monitor-only
- **Why not fixed immediately:** Edge case with no plausible near-term trigger (reverting
  a retired service's price requires a deliberate admin action against a service that is
  already invisible to all consumers). Out of scope for Phase 2 Step 1.
- **Risk if unaddressed:** An orphaned live price row for an inactive service. No billing
  risk (the service is unreachable from all write paths), but creates noise in the price
  history and could confuse future audits.
- **Recommended fix:** Add the same `activo` check from the PATCH endpoint (query
  `servicios WHERE servicio_id = $1 AND tenant_id = $2`, reject with
  `servicio_inactivo 400` if `activo = false`) before proceeding with the close+reopen.
- **Status:** Open.

---

## Closed

### 1. `tenant_servicio_precios` reads never check `valid_from`

- **Date found:** 2026-07-13, during July 16 price-change prep.
- **Description:** Every read of `tenant_servicio_precios` (`resolverServicioYValidarPrecio`
  and others in `barberpilot-api/index.js`) filtered only on `valid_to IS NULL`. The
  `valid_from` column was stored but never compared against `NOW()`.
- **Why not fixed immediately:** Out of scope under this week's time pressure for the
  July 16 price change; the July 16 migration script sidesteps it by closing the old row
  and opening the new one at the exact same instant (no gap/overlap), so the gap didn't
  bite for that specific change.
- **Risk if left unaddressed:** A price change can't be genuinely *scheduled* ahead of
  time without activating early — any future attempt to stage a price change in advance
  (rather than running the migration exactly on the effective date) would silently
  activate the new price the moment the row is inserted, not on the intended future date.
- **Status:** **Closed 2026-07-19.** `AND tsp.valid_from <= NOW()` added to both
  `fetchServiciosActivos()` and `resolverServicioYValidarPrecio()` in
  `barberpilot-api/index.js` as part of Phase 3 Step A/B deploy; confirmed live.

### 6. Near-miss: Corte auto-filled at $13.000 in queue-closing flow on César's device, 3 days before the sanctioned July 16 change

- **Date found:** 2026-07-13. César reported that a manual check-in correctly showed
  Corte at $12.000, but the price auto-filled to $13.000 (the not-yet-live July 16 price)
  once that check-in transitioned to the queue/Sala-closing step — requiring him to
  manually correct it back to $12.000 before closing each ticket.
- **Description:** Symptom closely matched what would happen if `SALA_PRECIOS` (the
  object `salaAutoPreio()` reads to auto-fill price during queue processing — exactly
  the object the still-uncommitted July 16 control diff changes) had already gone live
  in production. Investigation was about to start (live-page fetch, git log/status
  check, DB check on `tenant_servicio_precios`) when César independently confirmed the
  cause from another device/browser.
- **Root cause:** Isolated to one specific browser/machine on César's end — a
  client-side cache layer, likely compounded by a CDN edge artifact — not a real
  deployment. An independent device/browser showed the live site correctly serving
  12000/20000 with s11 still present, confirming no code was actually pushed and no DB
  row was actually flipped. No public/customer-facing exposure.
- **Why not fixed immediately:** N/A — resolved without any server-side, DB, or code
  change; the affected machine's cache was the sole cause.
- **Severity/risk:** None realized. Zero real `registros` at the new prices; César's
  manual vigilance during the affected window caught every instance before any ticket
  closed at the wrong price.
- **Status:** **Closed 2026-07-13.** Resolution: César proceeding with incognito mode on
  the affected machine as a practical workaround while the stale cache naturally expires.
  No code or DB changes were needed. All July-16 artifacts remain approved and staged,
  awaiting the explicit July-16-specific go-ahead, unaffected by this incident.

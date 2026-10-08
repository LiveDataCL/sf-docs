# BarberPilot / Salon Men Saúl Fino — Technical Debt Tracker

**This is the single source of truth for technical debt across all LiveDataCL
repos** (`barberpilot-api`, `barberpilot-control`, `BarberPilot_App`,
`saulfino-web`, and any repo added later). Every debt entry — whether it
affects one repo or several — belongs here, not in a per-repo `TECH_DEBT.md`.
This file previously went stale (last updated 2026-07-20) while
`barberpilot-api`, `barberpilot-control`, and `BarberPilot_App` each
independently grew their own root-level `TECH_DEBT.md`. Those three were
audited and merged back into this file on 2026-08-06 (see the entries below);
the per-repo files were deleted in the same change. Do not recreate a
per-repo `TECH_DEBT.md` — add to this file instead, with a **Repo:** field
identifying which repo(s) the entry affects.

Living document — update this file whenever new debt is found or existing
debt is closed, rather than leaving it scattered across chat history.

Each entry: date found, affected repo(s), description, severity, urgency, why
it wasn't fixed immediately, risk if left unaddressed, and status (open /
closed, with closure date if applicable).

**Last updated:** 2026-08-18 (WhatsApp ajuste discrepancy, unreproduced)

---

## Process documents

### DEACTIVATION CHECKLIST — Staff Removal Pattern

**Repo:** barberpilot-api, barberpilot-control, BarberPilot_App

**1. Problem**

When a staff member (barbero) leaves, they must be removed from:
- **Database** (`barberos` table: `activo=false`, `tenant_staff` table: `active=false`)
- **Expo/React Native login UI** (`BARBEROS_FALLBACK` constant in `BarberPilot_App/src/constants/index.js`)
- **All surfaces that consume `TODOS_PERFILES`** (currently `LoginScreen.js`; also check `App.js:192`, which reads `BARBEROS_FALLBACK` directly)
- **Backend API filters** (ensure endpoints return only `activo=true` / `active=true` — `GET /barberos` already does this; anything new added to the API should follow the same pattern)
- **barberpilot-control's own hardcoded roster copies** (`index.html`'s `BB` array, `agenda-admin.html`'s `B_MAP`/`BID_TO_QID`/roster pills) — see the "Hardcoded barbero roster fallbacks" entry below; these are a known, currently-unfixed instance of the same drift.

**2. Current Implementation (Emerson, Aug 2026)**

- **DB deactivation**: `barberos.activo=false` + `tenant_staff.active=false`, applied atomically via `PATCH /api/v2/staff/:bid/deactivate`, which also revokes any active sessions for that staff member. Confirmed live via `GET /barberos` no longer listing `b2`.
- **App removal**: Deleted the `b2`/Emerson entry from `BARBEROS_FALLBACK` in `BarberPilot_App/src/constants/index.js`.
- **Committed & pushed**: `d6b4454` on `BarberPilot_App`'s `main`, pushed to `origin` (GitHub: `LiveDataCL/barberpilot-expo`).
- **OTA published**: `eas update --branch production`, update group ID `9fd3d41c-f66e-4bf4-9a45-eb1fa9f966e1` (Android `019fd7f8-a91f-780d-b342-3fab747c125b`, iOS `019fd7f8-a91f-714b-ae07-9cbf509ecdbf`).
- **Verification performed**: `grep -i "b2|Emerson"` against `src/constants/index.js` post-edit returns no matches, and static trace of `TODOS_PERFILES = [ADMIN, ...BARBEROS_FALLBACK, ...SOCIOS]` confirms Emerson can't appear in the rendered login tiles.
- **Verification NOT performed**: no physical device or simulator was available in the session that made this change, so the fix was **not visually confirmed on an actual running app**. Reopen this checklist item if that hasn't happened yet.
- **Known miss**: `barberpilot-control/index.html`'s `BB` array (and `agenda-admin.html`) were **not** updated as part of this removal — they still list Emerson/`b2` as active. See the consolidated roster-fallback entry below.

**3. Future-Proof Steps (for next staff removal)**

- [ ] Mark `activo=false` (and `tenant_staff.active=false`) via `PATCH /api/v2/staff/:bid/deactivate` — do not hand-edit only one table
- [ ] Remove the entry from `BARBEROS_FALLBACK` in `BarberPilot_App/src/constants/index.js`
- [ ] Verify no other hardcoded references: `grep -ri "<bid>|<nombre>"` across `BarberPilot_App`, `barberpilot-api`, and `barberpilot-control` — including `barberpilot-control/index.html`'s `BB` array and `agenda-admin.html`, which are easy to miss
- [ ] Commit + push to GitHub
- [ ] Publish OTA update (`eas update --branch production`)
- [ ] Confirm the update group on the Expo dashboard
- [ ] **Actually test on a physical device or simulator after app reload** — this step was skipped for the Emerson removal and shouldn't be skipped again

**4. Structural Debt (not addressed by this pattern)**

`BARBEROS_FALLBACK` (and its counterparts in `barberpilot-control`) are still hardcoded fallbacks; the ideal state is each surface fetching `GET /barberos` live from the API, which already filters `activo=true` server-side and would eliminate the need for a manual constant update on every staff change. See "Hardcoded barbero roster fallbacks..." below for severity/urgency/closure path — this checklist is the interim manual process until that fix ships everywhere.

**5. Closure**

Emerson removal complete as of Aug 2026 for `barberos`/`tenant_staff`/`BarberPilot_App` (DB, app source, commit, push, and OTA publish all confirmed) — with two open exceptions: no on-device visual confirmation yet, and `barberpilot-control`'s roster copies not updated. Pattern documented here for reuse on the next staff removal.

### Procedimiento: Agregar un Socio (Dashboard sf-live)

**Repo:** sf-live, barberpilot-api

**Sistema:** sf-live (frontend estatico, GitHub Pages) + barberpilot-api (backend,
Railway, tabla `socios` en Postgres).

**Endpoint:** `POST /api/v2/auth/socio/setup`
Body: `{ nombre, email, password, master_pin }`
Requiere el valor de la variable de entorno `ADMIN_MASTER_PIN` (Railway, texto plano —
NO confundir con `ADMIN_MASTER_PIN_HASH`, que es solo una variable interna en memoria
calculada al arrancar el servidor, ni con `SOCIO_PIN_HASH`, que es una variable distinta
usada por un endpoint legacy no relacionado `POST /api/v2/auth/login` con `bid==='socio'`).

**Pasos:**
1. Confirmar que `ADMIN_MASTER_PIN` esta configurada en Railway (Variables del servicio
   barberpilot-api). Si no aparece en la lista, hay que agregarla ahi primero — el
   endpoint devuelve 401 en todos los intentos si esta variable no existe en el entorno.
2. Ejecutar un POST al endpoint con nombre, email, password inicial, y el master_pin.
   Ver plantilla de script PowerShell abajo.
3. Comunicar las credenciales al nuevo socio por un canal distinto al del propio
   dashboard (ej. WhatsApp), nunca por el mismo email que sera su usuario de login.
4. El socio cambia su clave desde el boton "Cambiar contrasena" ya integrado en el
   dashboard (`POST /api/v2/auth/socio/change-password`, requiere clave actual).

**Gotcha conocido:** al editar un script que use un valor placeholder (ej.
`REEMPLAZA_ESTO_CON_EL_PIN_REAL`) para el PIN, NO usar "Reemplazar todo" en el editor —
si el placeholder aparece en dos lugares del archivo (el valor y una linea de validacion
que lo compara), un reemplazo masivo sobreescribe ambos y la validacion queda comparando
el PIN real contra si mismo, dando un falso "todavia no lo reemplazaste" permanente.
Editar el valor a mano, linea por linea.

**Email unico por tenant, no global:** el indice unico en la tabla es
`(tenant_id, email)`, no `(email)` solo — relevante si en el futuro se activa un
segundo tenant (saulfino-maipu) y se reutiliza un email.

---

## Open

### 2026-10-08 — `ConfigScreen.js`'s "Cambiar PIN" is local-only and falsely reports success — can lock a barbero out

**Repo:** BarberPilot_App

**Description**: `ConfigScreen.js`'s `cambiarPin()` (lines 135-160) never calls the server at all — no `fetch`, no `POST /api/v2/auth/set-pin`. It compares the typed "current PIN" against a value in `SecureStore` (`'bp_pin_' + barbero.bid`, falling back to `barbero.pin`) and, if it matches, writes the new PIN to that same local key only. It then shows "✓ PIN actualizado correctamente" — a real success message for a change that never reached `tenant_staff.pin_hash`. Found while confirming the correct PIN-change path for Angie's onboarding; the real, server-connected path turns out to be `SetupPinScreen` (triggered automatically on any login where the server reports `pin_set: false`, confirmed it calls `POST /api/v2/auth/set-pin` correctly), not this screen.

**Practical risk**: anyone who uses this screen believes they've changed their real PIN. The next time they log in — especially on a different device, after a reinstall, or once this local value is cleared — the server still expects whatever PIN was there before. Looks like a leftover from before the real server-side PIN system existed, never removed or reconnected.

**Why deferred**: Found via code reading while answering a direct question for this session's onboarding work, not something that's bitten anyone yet as far as is known — but it's a real, live trap waiting for whoever uses that screen first.

**Scoped fix (not built)**: either wire `cambiarPin()` to the real endpoint (send `current_pin`/`new_pin`/`confirm_pin`, matching what `SetupPinScreen` already does correctly) or remove the option from `ConfigScreen` entirely until it's rebuilt properly — a half-working, falsely-reassuring PIN screen is worse than no PIN screen there at all.

**Related inconsistency, same area**: client-side minimum length here is `barbero?.rol === 'admin' ? 6 : 4` digits, and the *other* client-side check (`SetupPinScreen.js`) enforces exactly 4 unconditionally — but the actual server-side rule (`POST /api/v2/auth/set-pin`, `/^\d{4}$/`) is **exactly 4 digits, always**, regardless of role. Align whichever client-side checks remain to that same rule rather than inventing a role-based minimum the server doesn't enforce.

**Severity**: High — silent, falsely-confirmed account lockout risk for whoever uses this screen.

**Urgency**: Near-term — low effort to fix (reuse the exact pattern `SetupPinScreen` already proves works), real risk the longer it sits.

**Status**: Open.

### 2026-10-08 — `barber_schedule`'s unique constraint is `(bid, dia_semana)`, with no `tenant_id` — a cross-tenant bid collision would silently skip an insert

**Repo:** barberpilot-api

**Description**: `barber_schedule`'s primary key is `(bid, dia_semana)` only (`index.js:5048`), even though the table later gained a `tenant_id` column via `initTenantColumns()`. If two tenants ever assign the same literal `bid` string (e.g. both using a `b`-prefixed sequence, or any other overlap), `ON CONFLICT (bid, dia_semana) DO NOTHING` — the exact pattern this session's boot-seed fix and Angie's own schedule insert both rely on — would silently treat the second tenant's insert for that `bid`+day as "already exists" and skip it, even though it's a completely different tenant's barber. Today `saulfino` uses prefix `b` and `mae-studio` uses prefix `p` (confirmed via `tenants.staff_prefix`, `index.js:7900-7904`), so no actual collision exists yet — but nothing in the schema prevents one.

**Why deferred**: No active collision today (different prefixes keep the two tenants' bids disjoint in practice) — found while writing Angie's own schedule-insert statement this session, not blocking that work.

**Proposed fix (not built)**: change the unique constraint/primary key to `(tenant_id, bid, dia_semana)`, matching the pattern already used elsewhere (e.g. `tenant_staff`'s `UNIQUE(tenant_id, bid)`). Requires a migration (drop + recreate the constraint) rather than just a new `ALTER TABLE ADD COLUMN`.

**Severity**: Medium — silent data loss (a legitimate insert that looks like it succeeded but didn't) if it's ever triggered, not a security issue.

**Urgency**: Eventual — no active trigger while tenants keep disjoint bid prefixes; worth fixing before that assumption is ever relied on less carefully (e.g. a future tenant reusing a prefix, or a manual data-entry mistake).

**Status**: Open.

### 2026-10-08 — saulfino's 'credito' commission row is stuck at 40/60 instead of 43/57 — re-scoped, lower priority

**Repo:** barberpilot-api

**Description**: `tenant_commissions_v2`'s saulfino `'credito'` row has held `staff_pct=40.00, business_pct=60.00` since it was first seeded; César has confirmed the intended rate is 43/57, matching `'debito'`. Not fixed yet — deliberately deferred, see below.

**Key finding that changed the scope of this task**: `validateRegistro` (`index.js:389`, `body('pago').isIn(['efectivo', 'debito', 'transferencia'])`) has no path for `'credito'` at all, and nothing in `barberpilot-control`'s checkout UI offers "Crédito" as a distinct option from "Débito" either. So in practice, **every POS credit-card transaction today is already being recorded as `pago='debito'`**, not `'credito'` — the `'credito'` row in the commission table has likely never actually been read by anything, live or historical. César will separately confirm this matches actual staff practice at the register.

**Re-scoped plan (was: investigate + fix a real discrepancy; now: mostly a consistency cleanup)**:
1. Set the `'credito'` row to `43.00/57.00` for consistency with `'debito'`, and confirm (grep/read, not guess) that no surface anywhere actually reads `tenant_commissions_v2` filtered to `pago='credito'` — if truly unread, this is a low-stakes value change, not a financial correction.
2. Only investigate historical impact if the Critical `/registros/bulk` entry's query 0 (`SELECT pago, COUNT(*) ... GROUP BY pago`) actually turns up any `'credito'` rows — if it returns none, there's no history to reconcile.
3. Still its own branch + its own go-ahead before touching the live rate, per the standing production-billing-change rule — just lower priority than originally scoped, since the "credit cards are being mis-recorded" risk turned out not to exist structurally.

**Severity**: Low (re-scoped down from the original framing) — no evidence yet of any real transaction ever being mis-recorded under the wrong rate, since the column that would carry that rate has no live write path.

**Urgency**: Eventual — proceed whenever `feature/credit-commission-43` is picked up; not blocking anything.

**Status**: Open, re-scoped 2026-10-08.

### 2026-10-08 — Checkout has no notes/comment field (feature request)

**Repo:** barberpilot-api, barberpilot-control

**Description**: Confirmed by reading `validateRegistro` and the `registros` table's real column list (`scripts/seed-staging.js:121-140`) — there's no notes/comentario field anywhere on a service record. Surfaced while planning how to record that a backfilled entry was "actually performed this morning" (Angie's first day) — there's no field to put that kind of annotation on, so it has to live only in whoever manually remembers it, or not at all.

**Why deferred**: Not blocking — the accepted trade-off for today's backfill is "entry time stands in for actual service time," with date/amount/payment/commission still correct. Adding a real field is a small schema + UI change but wasn't needed today.

**Severity**: Low — a convenience gap, not a correctness or financial issue.

**Urgency**: Eventual — revisit if backfilled/annotated entries become a recurring need.

**Status**: Open.

### 2026-10-08 — "Agregar barbero" form's bid input field does nothing

**Repo:** barberpilot-control

**Description**: The "Agregar barbero" card has a visible input field for `bid` (placeholder "Ej: b5"), and the form requires it to be non-empty before submitting. Confirmed by reading the actual handler (`barberpilot-api/index.js:6364`, `const { name, role = 'barber', email, pin, spec, color } = req.body;`) that `bid` is never destructured from the request body at all — whatever the admin types there is silently discarded, and the server always assigns the next ID itself via `generateStaffBid()`. An admin creating a new hire has no way to know this and may reasonably believe they're choosing the ID.

**Why deferred**: Cosmetic/UX, not a correctness bug — surfaced while onboarding Angie (the field was filled with a guessed value that the server correctly ignored).

**Severity**: Low — misleading UI, no functional or data impact.

**Urgency**: Eventual — worth removing or relabeling (e.g. "ID asignado automáticamente") next time this form is touched for another reason.

**Status**: Open.

### 2026-10-08 — `POST /registros/bulk` accepts writes with no authentication and no validation of any kind — CRITICAL

**Repo:** barberpilot-api, barberpilot-control

**Reclassified from High to Critical / Immediate** (same day, during Angie's onboarding) after confirming the actual blast radius is larger than first scoped: this isn't just an unvalidated import tool, it's a completely open write endpoint with zero auth, reachable by anyone who knows the API's base URL.

**Description**: `POST /registros/bulk` (`index.js:1711`) has no auth middleware at all — not `requirePanelRole`, not `requireDashboardToken`, nothing — and no `express-validator` chain either. It inserts directly into `registros` from whatever JSON body is sent: no check that `bid` refers to a real or active barbero, no check that `sid`/`precio` match the service catalog, no check that `pago` is a real payment method, no tenant scoping. A single bad or malicious request can write arbitrary financial records.

**Who can actually reach it today — confirmed by searching every repo, not assumed**: nothing automated calls it. The only documented caller is a `curl` command in `barberpilot-api/README.md:104`, meant to be run by hand with a JSON file downloaded from barberpilot-control's "Ingresar histórico" tab (`descargarHistorico()`, `index.html` — confirmed separately that this tool makes zero API calls itself, it only produces a downloadable file). **The README also claims a second path that turns out not to exist**: "O desde el sistema de control: pestaña 📥 Ingresar histórico → botón Sincronizar con nube" (`README.md:109`) — but the only button anywhere in `barberpilot-control` with that label calls `migrarHistoricoNube()` (`index.html:935`), and that function **is not defined anywhere in the file**. Clicking it does nothing but throw a silent `ReferenceError` in the browser console. This is documentation describing a feature that doesn't exist (or existed once and was removed without updating the README) — distinct from, but discovered alongside, the endpoint's real security gap.

**An existing, usable marker for a first anomaly pass**: records created via the sanctioned Ingresar histórico → curl flow get an `id` starting with `TK_MAN_` (assigned client-side in `agregarItemHistorico()`/`descargarHistorico()`); genuine live-checkout records get `id: TK<epoch>` with no `_MAN_` segment. This is a **positive signal only** — an `id` matching `TK_MAN_` is very likely a sanctioned bulk import, but since the endpoint validates nothing, anyone could POST a row with any `id` shape at all, including one disguised to look like a live sale. Don't treat the absence of the marker as proof a row is clean, and **don't treat a zero-anomaly result from the queries below as proof nothing bad happened either** — an attacker who bothers to fake a plausible `id`, a real `bid`, and a real service/price would sail through every check here undetected. These queries catch sloppy or accidental bad data, not a deliberate, careful forgery.

**Read-only queries for César to run (rewritten after review — monthly-aggregated not daily, tenant-scoped, bid list derived from `barberos` not hardcoded)**. `registros` and `barber_schedule` both got a `tenant_id TEXT DEFAULT 'saulfino'` column via `initTenantColumns()` (`index.js:5897-5909`, confirmed called at boot, `index.js:8234`) — despite the earlier draft of this entry saying otherwise, so these now filter by it. `registros.fecha` is confirmed a real `DATE` column (`scripts/seed-staging.js:123`), but date-range filters below still cast to text rather than assume — cheap insurance, correct either way:
```sql
-- 0. Run this FIRST — confirms the real set of payment-method values
-- actually stored, since validateRegistro's code only ever allows
-- efectivo/debito/transferencia (no 'credito' path exists in the validated
-- checkout today) but this reads the live data directly rather than trusting that.
SELECT pago, COUNT(*) AS cantidad
FROM registros
WHERE tenant_id = 'saulfino'
GROUP BY pago
ORDER BY cantidad DESC;

-- 1. Rows by insertion path, by MONTH (not day — stays single-page even over
-- a long window), with anomaly flags. bid list comes from the real barberos
-- table for this tenant (active + inactive + any future hire), not a
-- hardcoded list that would go stale the next time someone's added/retired.
SELECT
  LEFT(fecha::text, 7) AS mes,
  CASE WHEN id LIKE 'TK_MAN_%' THEN 'bulk_historico' ELSE 'vivo' END AS origen,
  COUNT(*) AS cantidad,
  SUM(precio) AS total_facturado,
  COUNT(*) FILTER (
    WHERE bid NOT IN (SELECT bid FROM barberos WHERE tenant_id = 'saulfino')
  ) AS bids_desconocidos,
  COUNT(*) FILTER (WHERE pago NOT IN ('efectivo','debito','transferencia')) AS metodos_pago_invalidos
FROM registros
WHERE tenant_id = 'saulfino'
  AND fecha::text >= to_char(CURRENT_DATE - INTERVAL '90 days', 'YYYY-MM-DD')
GROUP BY mes, origen
ORDER BY mes DESC, origen;

-- 2. Rows priced differently from the service catalog's CURRENT active
-- price, by month (summary count only — catalog prices change over time, so
-- this flags candidates to look at, not confirmed anomalies).
SELECT
  LEFT(r.fecha::text, 7) AS mes,
  COUNT(*) AS filas_con_precio_distinto_al_catalogo_actual
FROM registros r
LEFT JOIN servicios s ON s.servicio_id = r.sid
WHERE r.tenant_id = 'saulfino'
  AND r.fecha::text >= to_char(CURRENT_DATE - INTERVAL '90 days', 'YYYY-MM-DD')
  AND (s.precio_activo IS NULL OR r.precio <> s.precio_activo)
GROUP BY mes
ORDER BY mes DESC;
```
**mae-studio note**: without the `tenant_id = 'saulfino'` filter, mae-studio's own bids (`p1`-`p4`) would show up in query 1's `bids_desconocidos` count purely because they're not saulfino barberos — not a real anomaly, just a tenant mismatch. The filter above avoids that false positive entirely by only ever looking at saulfino's own rows.

**Scoped fix (not built yet — own branch, own go-ahead, first task after Angie is operational)**:
- Add `requirePanelRole('admin')` — same pattern already used for every other admin-sensitive route in this file. Closes the "anyone on the internet" exposure immediately.
- Validate `pago` against the same enum `validateRegistro` already uses (`efectivo`/`debito`/`transferencia`).
- Validate `bid` — **found a real limitation while scoping this**: there's no history table recording *when* a barbero was activated/deactivated, only a current boolean. True "was this barbero active on that specific past date" validation isn't buildable against today's schema without adding that history table (bigger, separate work). The realistic near-term check is narrower: "does this bid exist in `barberos` for this tenant at all" (catches typos and made-up bids, doesn't catch "active-right-now-but-wasn't-on-that-date" edge cases, which barely matter for backfilling a specific day anyway).
- Validate service/price — reuse the existing `resolverServicioYValidarPrecio()` (`index.js:1420-1481`, already used by `POST /registros`) rather than writing a third, slightly-different variant of the same check.
- Tenant scoping — `registros` has no `tenant_id` column today, and this whole queue/registros system is already single-tenant (saulfino-only) elsewhere in the codebase, so there's nothing to validate against yet; becomes relevant only once a second tenant uses this table.
- Wrap the whole batch in one transaction, reject all rows if any row is invalid (replacing today's per-row `ON CONFLICT DO NOTHING`, which silently partial-succeeds).
- Log who imported what — `req.panelUser.panel_user_id`/`nombre` becomes available for free once the auth guard above is added; a minimal version is a structured `console.log`, a more durable version is a small audit table.
- **The dead "Sincronizar con nube" button (`barberpilot-control/index.html:935`, `onclick="migrarHistoricoNube()"`, function never defined) must be resolved as part of this fix, not left dangling**: either implement it properly on top of the now-secured endpoint (so "Ingresar histórico" gets a real one-click cloud sync instead of download-then-manual-curl), or remove the button entirely if the manual-curl path is going to remain the sanctioned flow. Leaving a dead button that silently does nothing is its own small UX bug either way.
- **Effort estimate**: roughly half a day for a developer already familiar with this codebase — 2-4 hours for the guard, validation, and atomic transaction (all reusing existing patterns), 1-2 hours for logging, about an hour for testing, plus a small additional amount (30-60 min) for whichever choice is made on the dead button. The "active-at-date" schema gap above is explicitly out of this estimate if full point-in-time correctness is wanted later.

**Severity**: Critical — unauthenticated arbitrary writes to financial records, reachable by anyone who knows the API's base URL, not gated behind any login at all.

**Urgency**: Immediate — scheduled as the first task once Angie is operational, per explicit instruction, ahead of other queued work.

**Status**: Open. Investigated and scoped only — no code changed, per instruction to keep this read-only today.

### 2026-10-08 — Railway barberpilot-api has no healthcheck path configured — a broken build can go live and replace a working one with no safety net

**Repo:** barberpilot-api

**Description**: A real `/health` endpoint already exists (`index.js:501`) and already does a genuine check, not a stub — `await query('SELECT 1')`, returning 500 if the database connection is actually broken. The gap isn't the endpoint; it's that nothing tells Railway to use it. No `railway.json`/`railway.toml`/`Procfile` exists in the repo declaring a healthcheck path, so (per César confirming Railway's Settings → Scale screen, same session this was found in) Railway has no configured healthcheck for this service at all. Practical effect: every deploy on this project this entire session (including the three just shipped) went live the instant the process started listening, with nothing checking whether it could actually reach the database first.

**Why deferred**: Out of scope for the auth/boot-seed/roster fixes shipped today — a deploy-pipeline safety net, not a functional bug in any of those changes. Found incidentally while scoping an unrelated item, not something that blocked today's work.

**Proposed fix (not built — scope only)**: add a `railway.json` with `"deploy": {"healthcheckPath": "/health", "healthcheckTimeout": ...}` (version-controlled, reviewable, survives environment recreation) rather than only setting it by hand in Railway's dashboard. Small, low-risk, no application code changes — the endpoint it points to is already correct.

**Severity**: Medium — no incident has happened yet, but every future deploy carries the same "bad build goes live with zero rollback-on-failure" risk until this is wired up.

**Urgency**: Eventual — no active incident; worth doing before the next deploy that has any real chance of a boot-time failure (e.g. anything touching the migration chain), since that's exactly the scenario a healthcheck would catch.

**Status**: Open. Scoped only, not built.

### 2026-10-08 — barberpilot-api runs on Node 18.20.8 (Railpack default), which is end-of-life

**Repo:** barberpilot-api

**Description**: Confirmed during the same Railway settings review as the healthcheck item above — the deployed runtime is Node 18.20.8, Railpack's current default for a repo with no explicit engine pin. Node 18 reached its Node.js project end-of-life in April 2025 (per Node.js's published release schedule as of this writing) — it no longer receives security patches from upstream. `package.json`'s `"engines": {"node": ">=18"}` is wide enough to allow a newer LTS already; nothing in the dependency list was checked yet for a hard Node-20/22-only requirement.

**Why deferred**: Found incidentally, same as the healthcheck item — not something blocking today's onboarding work, and a runtime upgrade deserves its own dedicated verification pass rather than being folded into an unrelated change.

**Proposed scope (not started)**: 1) pin an explicit newer LTS (22 is current LTS as of this writing; 20 is the more conservative choice) via `"engines"` and/or a Railway-specific version file, whichever Railpack respects; 2) run the full existing test/verification approach used this session (the jsdom-based harnesses, plus the dependency-free auth-guard tests) against the new runtime before deploying; 3) deploy to the single Railway replica during a confirmed no-payments window, same discipline as today's deploys; 4) watch real boot logs for any Node-version-sensitive dependency warning (none anticipated given the dependency list is unremarkable — `express`, `pg`, `jsonwebtoken`, `bcrypt`, etc. — but not independently verified against Node 20/22 compatibility yet).

**Severity**: Medium — no active exploit known, but running an unpatched, unsupported runtime in production is a standing, compounding risk with no offsetting benefit.

**Urgency**: Eventual — no active incident; reasonable to schedule as ordinary maintenance rather than an emergency.

**Status**: Open. Scoped only, not started.

### 2026-10-08 — Pending confirmation: is Railway "Serverless" (sleep-on-idle) enabled for barberpilot-api?

**Repo:** barberpilot-api

**Description**: Not yet confirmed either way by César. If Railway's "Serverless" mode is turned on for this service, the process (and everything living only in its memory) gets torn down after a period of inactivity and cold-started on the next request. Two things in this codebase live purely in-memory and would be silently lost on every sleep cycle if this is on: the active-barber cache this session already investigated (`_barbCache`, refreshed at boot + every 5 min + on staff changes — a sleep/wake would just mean an extra cold-start reload, probably harmless) and, more importantly, the 15-minute-appointment / arrival-alert poller and the SSE connections used for real-time admin-panel alerts — both of which would simply stop firing while asleep and need the service to wake up (via an incoming request) before resuming, with no queued catch-up for whatever was missed during the sleep window.

**Why deferred**: Genuinely unknown status, not yet checked — raised here so it isn't forgotten, not because a problem has been confirmed.

**Next step**: César to confirm in Railway → barberpilot-api → Settings → whatever surfaces "Serverless"/sleep behavior (same screen already used to confirm the 1-replica setting this session). If it's on, scope turning it off (likely the simple fix, assuming the cost tradeoff is acceptable) versus making the poller/SSE paths resilient to being asleep (more invasive, probably not worth it for a single-location salon's traffic pattern).

**Severity**: Medium if enabled (silent loss of real-time alerting with no error surfaced to anyone) — Low/moot if disabled.

**Urgency**: Near-term to just confirm the setting (cheap); the fix itself (if needed) is Eventual.

**Status**: Open, pending César's confirmation of the actual setting.

### 2026-10-08 — In-memory active-barber cache (`_barbCache`) assumes a single Railway replica

**Repo:** barberpilot-api

**Description**: Confirmed during Angie's onboarding (same session) that `_barbCache` — the in-memory list `validateRegistro`'s `bid` check reads from, refreshed at boot, every 5 minutes, and immediately on every staff create/update/deactivate/reactivate — is a plain in-process JS `Map`, with no cross-instance sharing mechanism (no Redis, no pub/sub). Confirmed with César that barberpilot-api currently runs exactly 1 replica (Railway Settings → Scale, US West), so every refresh trigger reaches the only copy that exists and this is correct today — no fix needed right now.

**Why deferred**: No active problem — explicitly a "monitor, don't build" item, not a bug.

**Trigger to revisit**: the moment this service is ever scaled to more than 1 replica. At that point, each replica holds its own independent copy, and a cache-invalidating event (e.g. creating a new staff member) handled by one replica would not refresh the others until their own 5-minute timer fires — meaning a brand-new hire's first sale could be rejected by whichever replica happens to handle that request, for up to 5 minutes. Fix at that point: either move the cache to a shared store, or have each instance's staff-mutation handlers broadcast an invalidation signal to its siblings, or (simplest) have `validateRegistro` query the DB directly instead of an in-memory cache if the extra query-per-sale cost is acceptable.

**Severity**: Low today (single replica, confirmed correct) — would become Medium the moment replica count increases, since it'd then be a real, if narrow, window where a legitimate sale can be wrongly rejected.

**Urgency**: Monitor-only — revisit only if/when replica count changes.

**Status**: Open, monitor-only.

### 2026-10-08 — `POST /api/v2/staff` (and the related `PATCH /api/v2/staff/:bid`) require a token type the control panel's UI never produces — "Agregar barbero" button has likely never worked since 2026-07-01

**Repo:** barberpilot-api, barberpilot-control

**Description**: Found while planning Angie's onboarding. `barberpilot-control/index.html`'s "Agregar barbero" card (`staffSubmitNewBarber()`) sends either a panel-login JWT (`sessionStorage.panelJwt`, shape `{type:'panel', panel_user_id, role:'admin'|'operator', ...}`) or a dashboard token (`x-dashboard-token` header) via `getAuthHeaders()`. The actual endpoint it calls, `POST /api/v2/staff` (`index.js` ~6346), is gated by `requireTenantAuth` + `requireRole('owner')` — middleware that expects a *barber-app PIN-login session* JWT (shape `{tenant_id, staff_id, bid, role, session_id}`, issued only by `POST /api/v2/auth/login`), verified against a live `auth_sessions` row. A panel JWT has no `session_id`/`staff_id` fields and a `role` of `admin`/`operator`, never `owner` — it structurally cannot satisfy either check. `PATCH /api/v2/staff/:bid` (used for edits, including PIN resets) has the identical guard and the identical mismatch.

**Evidence (git history, not just code reading)**:
- `3879222` (2026-06-17) originally added `POST`/`GET /api/v2/staff` guarded by `requireDashboardToken` — compatible with the control panel's auth, per the commit message ("allowing full barber CRUD from control panel").
- `0535757` (2026-07-01, same day) deliberately deleted that `requireDashboardToken`-guarded `GET`/`POST /api/v2/staff` as part of a security-hardening pass ("sensitive route auth"), leaving only an earlier, until-then-unused `requireTenantAuth`-guarded duplicate (added 2026-06-15 in `06f8dd6`, multi-tenant Phase 1 scaffolding) as the sole surviving implementation. The frontend was never updated to match the new auth requirement.
- Neither b5 (Steven, added 2026-07-01 in the same commit range) nor b6 (Winder, added 2026-07-19 in `3debbf8`) were created through this endpoint or through the control panel UI at all — both were added by editing hardcoded arrays and a boot-time SQL seed block directly in `index.js`, deployed as a code change. So the button's broken state has had no opportunity to be noticed: nobody has used it for a real hire since the guard changed.
- Confirmed the payload-shape mismatch directly (no DB needed): signed a panel-shaped JWT with a throwaway local secret and inspected it — `session_id` and `staff_id` are `undefined`, `role` is `admin`, none of which `requireTenantAuth`/`requireRole('owner')` can accept.
- Did not complete a full live round-trip against a real Postgres (no Docker or local Postgres binary available on the machine used for this investigation) — the two pieces of evidence above are independently conclusive without it, but a live confirmation would be the most rigorous close.

**Why deferred**: Discovered during read-only discovery for Angie's onboarding, not caused by that work. Fixing it (e.g. accepting a panel `admin`-role JWT via `requirePanelRole`, consistent with the existing hardcoded `'saulfino'` tenant convention used elsewhere) is a real backend change needing review, not a one-line patch to apply silently mid-investigation.

**Severity**: High — the control panel's only UI path for creating/editing staff (including PIN resets) is very likely completely non-functional in production, with no workaround available through that UI at all; every roster change for the life of this bug has had to go through a direct code change + deploy instead.

**Urgency**: Immediate-if-relied-upon — becomes blocking the moment anyone tries to use the "Agregar barbero" button for a real hire (e.g. Angie) without the fix landing first.

**Status**: Open. Structural fix proposed, not yet built or approved.

### 2026-10-08 — First-login "set your own PIN" flow has no identity verification — whoever taps a tile first claims that PIN

**Repo:** barberpilot-api, BarberPilot_App

**Description**: `POST /api/v2/auth/login` — when `tenant_staff.pin_hash IS NULL` (a new hire who hasn't set a PIN yet, e.g. Steven today) — accepts *any* 4+ digit input as valid (`pinValid = true` unconditionally unless it happens to match `ADMIN_MASTER_PIN`) and issues a full session token, routing straight to `SetupPinScreen`. There is no check that the person tapping that barbero's tile is actually them — no phone verification, no one-time code, nothing. Whoever taps the tile and enters any PIN first permanently claims it (`pin_set=true` after `POST /api/v2/auth/set-pin`); the real person is locked out until an admin intervenes. Any newly-created barbero left with no PIN (the recommended, lowest-friction onboarding path) carries this exposure between account creation and their first real login.

**Admin recovery check**: no PIN-reset button exists anywhere in `barberpilot-control`'s UI (confirmed by search — no matching function). The backend does support resetting a PIN via `PATCH /api/v2/staff/:bid` with a `pin` field, but that route has the identical auth mismatch as the entry above, so it isn't reachable from the panel today either. The one working recovery path is: the real staff member (or César with them) logs in using `ADMIN_MASTER_PIN` as the PIN (which overrides any staff member's check), then uses the in-app "change PIN" option (`ConfigScreen.js`), again supplying the master PIN as `current_pin`. This works, but depends entirely on César being present with the master PIN each time — there's no self-serve or panel-driven reset.

**Why deferred**: Pre-existing product behavior (already live for Steven today), not introduced by the Angie onboarding work that surfaced it. Closing the race condition (e.g. requiring a short-lived claim code shown to the real hire, or restricting first-login PIN-setup to a short window right after account creation) is a real design decision, not a quick fix.

**Severity**: Medium — account takeover is low-value (gates check-in/registro entry under that barbero's name, not payment data directly) but real, and the only existing recovery path requires the owner's personal master PIN every time.

**Urgency**: Monitor-only for a trusted, small, in-person staff — becomes Near-term if the login screen/kiosk is ever reachable by the public, or once headcount grows enough that "whoever's near the tablet first" stops being an acceptable risk model.

**Status**: Open.

### 2026-10-08 — `tenant_commissions` (per-barber, per-service commission table) exists in schema but has zero API wiring — effectively dead

**Repo:** barberpilot-api

**Description**: `tenant_commissions` (`bid, svc_id, pct`, unique per tenant+bid+svc_id — `index.js` ~5653) looks like it supports a different commission rate per individual barber per service. In practice, no `GET`/`POST`/`PATCH` route anywhere in `index.js` reads or writes it — the only commission mechanism actually wired up is `tenant_commissions_v2` (`payment_method, staff_pct, business_pct`), which is tenant-wide, not per-barber, and covers cash/transfer/debit splits only. Found while confirming, for Angie's onboarding, whether a new hire could be given a different commission rate than the rest of the roster — the honest answer is no, not without new backend work, despite the `tenant_commissions` table's name suggesting otherwise.

**Why deferred**: Out of scope for onboarding a barber who (per current plan) gets the same tenant-wide split as everyone else. Building real per-barber override support (new endpoints, control-panel UI, and a defined precedence rule against `tenant_commissions_v2`) is separate, larger work with no current trigger.

**Severity**: Low — no incorrect commission is being paid; the gap is a missing *capability*, not a wrong calculation. Mildly misleading to a future reader who assumes the table's existence means the feature works.

**Urgency**: Eventual — becomes relevant the moment a real need for a per-barber (not per-payment-method) commission rate comes up. No such need today.

**Status**: Open. Table kept as-is (not deleted) per standing instruction not to remove existing schema speculatively.

### 2026-08-18 — "Enviar por WhatsApp" once showed a correct ajuste while "Copiar texto" (tested shortly after) showed $0 — unreproduced

**Repo:** barberpilot-control

**Description**: During manual testing of the Cierre de caja ajuste feature (PR #30), César observed "Enviar por WhatsApp" correctly show Base inicial = $55.530 (ajuste +$5.530), then "Copiar texto" — tested shortly after, same day, same gastos — show Base inicial = $50.000 with no ajuste. Both buttons called the identical shared `textoCierreWhatsapp()` function, so a difference between them can only mean `AJUSTE_CAJA` itself changed value in memory between the two clicks.

**Investigation performed**: pulled the exact commit deployed at test time (`5651d3595`) and reproduced the click sequence three ways — direct function calls, real simulated DOM clicks (fill + blur + click), and a full same-day page reload — all three preserved `AJUSTE_CAJA` correctly across both buttons. Traced every code path touching `AJUSTE_CAJA`/`BASE_CAJA` (boot sequence, all `setInterval` pollers, `drainOutbox`, both global click listeners): none reset it outside of `cambiarBase()`/`cambiarAjuste()`, which persist synchronously and consistently. César confirmed none of the obvious non-bug explanations applied (no device switch, no reload, no manual base edit between the two clicks). No root cause found.

**Why deferred**: unreproducible after three independent repro methods against the exact deployed code; the "Enviar por WhatsApp" button that exposed this discrepancy has since been removed entirely (César's call — wa.me/WhatsApp Web rendering wasn't reliable enough to keep regardless of this bug), so the specific two-button divergence that surfaced this can no longer occur. "Copiar texto" alone is now the only export path and has been independently verified correct.

**Open unknown, explicitly flagged rather than assumed**: the leading unverified hypothesis is a mobile-specific quirk headless testing can't simulate — iOS Safari discarding/reloading a backgrounded tab under memory pressure when `wa.me` handed off to the WhatsApp app (which could look like "no reload happened" from the user's perspective), or private/incognito mode restricting `localStorage`. Neither has been confirmed. If this recurs, capture device/browser/private-mode status at the time — that's the missing piece that would let this be root-caused.

**Severity**: Low — no longer reachable via the removed button, and the remaining "Copiar texto" path has been independently verified correct across function calls, real DOM events, and same-day reload.

**Urgency**: Monitor-only — revisit only if a similar single-value discrepancy is ever observed again via "Copiar texto" itself (the only remaining export path), since that would rule out the "button removed" mitigation and indicate the underlying cause is still live.

**Status**: Open. No fix scheduled — unreproduced, and the surface that exposed it is gone.

### 2026-08-18 — Cierre de caja has no server-side persistence

**Repo:** barberpilot-control

**Description**: The "Cierre de caja" tab (`index.html`, pane `id="pCaja"`, rendered by `renderCaja()`) computes and stores the daily register close entirely in browser localStorage — `BASE_CAJA`, `gastos`, and `liquidaciones` all live under per-date localStorage keys (`sfsf_base_caja_<fecha>`, `sfsf_gastos_<fecha>`, `sfsf_liq_<fecha>`). Individual `gasto` entries do sync to the backend one-at-a-time via `POST /gastos` (outbox pattern), but there is no consolidated `/cierre` endpoint and no database record of a completed daily close (base inicial, totals by channel, barber liquidations, final `cajaFinal`/`aDepositar`). If the browser cache is cleared or the close is done from a different device, that day's close data is unrecoverable, and there is no server-side audit trail — even though a daily PDF (`printCajaA4()`) is already generated and handed to socios.

Confirmed decision (Aug 2026): the new "Ajuste vs. base estándar" field added alongside `BASE_CAJA` (WhatsApp/PDF export feature) follows the same localStorage-only pattern for now (César's explicit call). This entry tracks the underlying gap, not a blocker on that specific feature.

**Why deferred**: out of scope for the WhatsApp/PDF export feature that surfaced it; building a `/cierre` endpoint + DB table is real backend + frontend scope (schema design, migration, save-flow wiring), not a one-line fix.

**Structural fix (not in scope until prioritized)**: build a `/cierre` POST endpoint + DB table that snapshots the full daily close on save, so the existing daily PDF has a durable server-side backing record — matching how `gastos` already sync individually.

**Severity**: Medium — no fraudulent-billing path, but a real audit/recovery gap: the only record of a completed cierre lives in one browser's localStorage, with no server-side backup.

**Urgency**: Eventual — no active incident forcing this, but every day's close carries the same unrecoverable-if-cache-cleared risk until it's fixed.

**Status**: Open. No fix scheduled.

### 2026-08-10 — jsdom verification harness (caught a real bug) is a one-off local script, not part of any test suite

**Repo:** sf-live

**Description**: While validating the Reporte Financiero feature this session, a real bug (`escHtml` used but never defined, silently crashing the gastos-detail table render) was found and fixed by actually executing `sf-live/index.html`'s real inline script in a jsdom-simulated DOM — mocking `fetch`, invoking the page's own functions (`cambiarVista`, `cargarReporteFinanciero`), and inspecting the resulting DOM/thrown errors. The same harness was then used to verify the cumulative chart's zero-crossing color-split logic against both real production data and a synthetic forced-negative scenario, confirming exact expected segment counts and that no Y-coordinate clips outside the SVG's drawing bounds.

This was effective — it caught a bug that purely static review and manual math-recomputation both missed — but it exists only as an ad-hoc script (`test-dom.js`/`test-chart.js`) in a session scratchpad directory. It is not committed to the repo, not wired into any CI, and does not run automatically on future changes to `sf-live/index.html`.

**Recommendation (not implemented here)**: convert this into a real, repo-committed test (e.g. a small `tests/` directory with `jsdom` as a dev dependency) and wire it into a GitHub Actions workflow that runs on push/PR to `sf-live`. This would be sf-live's **first** automated test coverage of any kind — currently the repo has zero CI beyond the auto-generated Pages build/deploy.

**Why deferred**: out of scope for the feature work that produced the harness; formalizing it into a maintained test suite is a deliberate, separate piece of work (choosing what to assert, deciding coverage scope, setting up the workflow), not a quick follow-up.

**Severity**: Medium — sf-live currently ships changes with no automated safety net at all; this session's `escHtml` bug is a concrete example of the kind of regression that would otherwise reach production undetected.

**Urgency**: Eventual — no active incident, but every future change to the Reporte Financiero (or any other sf-live) script carries the same undetected-regression risk this one did.

**Status**: Open. No fix scheduled.

### 2026-08-10 — sf-live's Reporte Financiero uses a hardcoded feriados list instead of the real `feriados` table

**Repo:** sf-live, barberpilot-api

**Description**: The "Reporte Financiero" tab's Domingo/Feriado row labeling (`FERIADOS_CHILE_2026` in `sf-live/index.html`) uses a fixed, hand-curated array of 2026 national holiday dates instead of reading `barberpilot-api`'s real `feriados` table (which also supports per-tenant overrides via `tenant_feriados_override`). This was a deliberate choice, not an oversight: the only endpoint currently serving `feriados` data (`GET /config/negocio`) requires `requireConfigNegocioAuth` (panel/barber JWT), which sf-live's socio-JWT session does not satisfy — and that endpoint also bundles unrelated servicios/productos/meta data. Reusing it would mean building a new, narrower endpoint compatible with the socio auth path; out of scope for the labeling feature that surfaced this.

**Open unknown, explicitly flagged rather than assumed**: it has **not** been checked whether `tenant_feriados_override` has any rows for `saulfino` that differ from the national public calendar (e.g. a day the shop deliberately opens on a public holiday, or closes on a day that isn't one). If such an override exists, `FERIADOS_CHILE_2026` would silently disagree with the tenant's actual configured calendar. Nobody has queried this yet.

**Why deferred**: out of scope for the row-labeling feature that surfaced it (a visual/cosmetic refinement); building proper socio-compatible access to the real `feriados`/`tenant_feriados_override` data is a small but real backend + frontend change, not a one-line fix.

**Severity**: Low — the fixed list was cross-referenced against the official public calendar at write time, and worst case is a cosmetic mislabel (a real-activity day showing normally regardless, since the label only ever applies when totals are already zero) — never a monetary/data-correctness issue.

**Urgency**: Eventual — becomes worth fixing before 2027 regardless (the list needs a manual update every year — see the year-guard console warning added alongside this), a natural point to also check `tenant_feriados_override` and consider wiring real access instead of extending the hardcoded list again.

**Status**: Open. No fix scheduled.

### 2026-08-10 — boot-smoketest.yml CI has no CREATE TABLE for 9 core tables — zero real coverage for anything touching them

**Repo:** barberpilot-api

**Description**: `boot-smoketest.yml`'s CI Postgres container starts genuinely empty. The boot-time migration chain in `index.js` only ever issues `ALTER TABLE`/`ADD COLUMN` statements against `registros`, `gastos`, `queue`, `service_durations`, `agenda`, `cortes_historicos`, `inventory`, `metas`, and `notas` — there is no `CREATE TABLE` for any of these nine tables anywhere in the boot sequence. Against CI's empty database, every migration touching them fails: some silently (logged as `(non-fatal)`), some loudly (three lines flagged 🚨 as genuine non-idempotent failures, e.g. Migration 023's `registros.cliente_id` FK never getting enforced in CI). Confirmed directly from a real job log (PR #36, run `31442491890`):
```
ERROR: relation "registros" does not exist
STATEMENT: ALTER TABLE registros ADD COLUMN IF NOT EXISTS tenant_id TEXT DEFAULT 'saulfino'
ERROR: relation "gastos" does not exist
ERROR: relation "queue" does not exist
```
This is the same category of incident referenced as having affected "9 of 12 migrations" silently for months — confirmed still unresolved as of this entry.

**Practical impact**: any endpoint reading or writing these tables has zero real CI coverage. The smoke test's only HTTP assertion is `GET /clientes/recurrencia` returning 401 without auth — a single unrelated route. This was surfaced while validating `/registros/rango` and `/gastos/rango` (just given a new auth path for the `reporte-financiero-mensual` feature): CI went green on that PR, but neither endpoint — nor the new `requireDashboardOrSocio` middleware — was ever actually invoked by the workflow, and even if it had been, both would have hit `relation "gastos"/"registros" does not exist` against CI's DB. Validation for that feature was done manually instead, cross-checked against real production data.

Separately, `boot-smoketest.yml` has **no lint or type-check step at all** — not specific to these tables, just a gap in the same workflow worth recording alongside it.

**Why deferred**: discovered as a side effect of validating an unrelated feature (`reporte-financiero-mensual`, Aug 2026) — not introduced by it. Fixing the CI table setup (presumably by having the workflow run the real migration chain against a truly empty DB in dependency order, or seeding a minimal schema before the app boots) is a dedicated piece of work, not an in-scope fix for the PR that surfaced it.

**Severity**: Medium-High — CI is not actually validating a large fraction of the application's core functionality (client/service records, expenses, the walk-in queue, and everything downstream of them), despite reporting green.

**Urgency**: Eventual — no active incident, but every PR touching these tables ships with the same false confidence this one did. Worth prioritizing before the next migration to one of these nine tables.

**Status**: Open. No fix scheduled.

### 2026-08-10 — Appointment unification + proximity alerts — status record (mostly already resolved before this entry existed)

**Repo:** barberpilot-api, barberpilot-control

**Description**: A task was opened assuming panel-created "Servicio" bookings still lived in `blocked_slots` and that proximity alerts didn't exist. Investigation found:
- **Servicio → `appointments` unification was already resolved on 2026-07-30** (commit `46c95c6` in `barberpilot-api` + the matching `agenda-admin.html` change in `barberpilot-control`): `POST /blocked-slots` rejects new `tipo='servicio'` rows; the panel creates bookings via `POST /appointments` instead, which enforces `client_phone`, reuses `findOrCreateClienteByTelefono()`'s placeholder-phone guard, defaults `estado='confirmado'`, and already runs the shared overlap check against `appointments` — so double-booking prevention across public (`saulfino-web`) and panel bookings was unified automatically. This was never logged here, which is why the task assumed it was still open.
- As a direct consequence, the existing 15-min "previa" poller (`notified_15min` column, `index.js` `setInterval`) started covering **all** appointment types automatically, with zero new code, the moment Part 1 shipped.
- The one real gap was an **arrival alert** (fired when an appointment's start time is reached), which did not exist. Added 2026-08-10: `alerta_llegada_enviada_en` timestamp column on `appointments`, a new block in the existing 15-min poller (5-minute lookback, `IS NULL` idempotency guard, per-row try/catch), and `GET /appointments/proximity?fecha=` for the panel to read alert state. Deliberately did **not** add a parallel `alerta_previa_enviada_en` column — that would have duplicated `notified_15min`, which already does the same job for all appointments.
- Push delivery for both alert types uses the existing `sendPush()` (Expo push via `push_tokens.token` → `exp.host`), not FCM — correcting a wrong assumption the originating task carried.

**Why deferred**: N/A — recorded as closed. Logged here specifically so the Part 1 unification (which shipped with no TECH_DEBT entry) has a durable record, and so a future task doesn't re-assume it's still open.

**Severity**: N/A (informational/closure record).

**Urgency**: N/A.

**Addendum (live-fire staging verification, 2026-08-10)**:
- **15-min window behavior, confirmed from code**: the existing `notified_15min` poller query (`index.js`, `WHERE ... BETWEEN NOW() AND NOW() + interval '15 minutes'`) is a wide 0-15-minute safety net, not a narrow band around the 14-15 min mark — it fires on the first tick that sees a qualifying appointment anywhere inside that window, then never again (`notified_15min` guard). Confirmed empirically in staging: it correctly fired for a test appointment only ~2 minutes out. Same design pattern used for the new `alerta_llegada_enviada_en` arrival check.
- **Staging schema drift found and fixed during this verification**: staging's `appointments` table was missing `notified_15min` entirely (`column "notified_15min" does not exist`, repeating every poller tick), even though `scripts/seed-staging.js`'s own `CREATE TABLE appointments` already declares that column. Root cause: this staging Postgres has been running since 2026-06-19 and its live schema had drifted from what the seed script currently declares — a reminder that **staging schema can silently diverge from the seed script's declared source of truth** if the DB isn't actually rebuilt (DROP/CREATE via the script) after the script changes. Fixed by re-running the script's DROP/CREATE against staging rather than hand-patching the one column, to keep the seed script as the single authoritative schema definition.

**Status**: Closed 2026-08-10.

### 2026-08-08 — Gap identificado: no existe endpoint para quitar/desactivar un socio

**Repo:** barberpilot-api

**Description**: La tabla `socios` tiene una columna `active BOOLEAN DEFAULT true`, pero
la auditoria de codigo (barberpilot-api, index.js) no encontro ningun endpoint que la
modifique — el unico insert/update path documentado en todo el repo es el de creacion
(`/socio/setup`). Tampoco esta confirmado si el login (`/socio/login`) siquiera verifica
el valor de `active` antes de emitir un JWT (no se audito ese detalle).

**Implicacion practica**: si hoy fuera necesario quitar el acceso a un socio (ej. si se
termina una sociedad), la unica via conocida es un UPDATE o DELETE manual directo en la
base de datos de produccion (Railway Postgres) — lo cual requiere el mismo tipo de
autorizacion explicita que cualquier acceso a credenciales de produccion.

**Why deferred**: surgio como hallazgo colateral al auditar el flujo de creacion de
socios (`/socio/setup`) para dar de alta a un nuevo partner — no hay todavia un
incidente real que haya forzado a desactivar a alguien, asi que construir el endpoint
de baja quedo fuera de alcance de esa tarea.

**Severity**: Medium — misma categoria que otros gaps de este archivo que dependen de
una intervencion manual directa sobre la base de datos de produccion; sin via de
reversion rapida si se comete un error.

**Urgency**: Monitor-only — no hay ningun caso pendiente de desactivacion de socio hoy;
revisar si/cuando se necesite quitarle el acceso a alguien.

**Pendiente:** antes de que esto se necesite de verdad, conviene (a) confirmar si
`/socio/login` respeta el flag `active`, y (b) construir un endpoint admin de
desactivacion protegido por el mismo `ADMIN_MASTER_PIN`, en vez de depender de queries
manuales a la base de datos.

**Status**: Open.

### 2026-08-06 — Hardcoded barbero roster fallbacks across checkin.html, queue-dashboard.html, and barberpilot-control's index.html / BarberPilot_App's LoginScreen.js

**Repo:** barberpilot-api, barberpilot-control, BarberPilot_App

**Correction (2026-10-08, Angie onboarding investigation)**: This entry previously described `agenda-admin.html` as having "no live fetch at all" and had not checked sf-live or saulfino-web. Both corrected below — the real remaining scope is narrower than originally written (two surfaces, not four+).

**Description**: Two surfaces genuinely have no live reconciliation and would hide a newly-added barbero even after their DB rows exist:
- `barberpilot-control/index.html`'s `BB` array (`~line 1242`) and its `BB_CANONICAL_NAMES` map (`~line 6877`): `staffRefreshFromAPI()` only patches the `active` flag on entries that already exist in `BB` by matching `bid` — it has no `else` branch, so a `bid` present in the live `GET /api/v2/staff` response but absent from the hardcoded seed array is silently dropped, never added. Display names also come only from `BB_CANONICAL_NAMES`, not the live API response's `name` field. A brand-new hire is invisible in every barber picker fed by `BB` (service entry, cierre de caja, reports) until someone hand-edits both the array and the map and ships a commit.
- `BarberPilot_App/src/constants/index.js`'s `BARBEROS_FALLBACK` / `TODOS_PERFILES` — feeds `LoginScreen.js`'s tile list (where a barbero picks their profile and enters their PIN) with zero live reconciliation. A hook that already does live-fetch-with-fallback exists (`src/hooks/useBarberos.js`, used by `AdminScreen.js`) but `LoginScreen.js` and `App.js:192` bypass it and read the static constant directly.

**Corrected / already fine, no fix needed**:
- `agenda-admin.html` (`barberpilot-control`) — confirmed via code read: `cargarBarberos()` runs on page load, fetches `GET /config/negocio/publico?tenant=saulfino`, and fully rebuilds `BARBERS`/`B_MAP`/`BID_TO_QID` from the response (not a selective patch). A new hire appears here automatically. The previous write-up of this entry was wrong about this file.
- `checkin.html`/`queue-dashboard.html` (`barberpilot-api`) — as previously documented, live-fetch with fallback.
- `sf-live/index.html`'s two arrays (`SILLAS_BARBS`, `BB_BID`/`_sfBarberos`) — checked for the first time in this investigation. An IIFE at page load (`~line 1847`) fetches `GET /barberos` and fully rebuilds all three (`BB_BID`, `_sfBarberos`, and `SILLAS_BARBS`) from the live response; the hardcoded values are only the pre-fetch/fetch-failure fallback. A new hire appears here automatically.
- `saulfino-web/checkin.html` and `saulfino-web/barber.html` — also checked for the first time. Both call `GET /barberos` on load (`loadBarberosFromAPI()` in checkin.html, an equivalent fetch in barber.html) and rebuild their barber list from the response; a hire with no locally-cached photo just renders with no photo, not as a missing barbero. A new hire appears here automatically.

This is one systemic pattern, not several separate bugs — merging what were previously three separate entries (barberpilot-api's 2026-07-23 entry, BarberPilot_App's 2026-08-06 entry, and a barberpilot-control instance found during the same investigation) into one, since they're the same root cause recurring in the two surfaces that still have it.

**History of recurrence**:
- **2026-07-23** — `checkin.html`/`queue-dashboard.html` found stale (still listed `samuel`/`b3`, missing `winder`/`b6`) during the Gabriel/b3 investigation; fixed to b1/b2/b5/b6 (Didian/Emerson/Steven/Winder) in that change.
- **2026-08-06** — Emerson (`b2`) deactivated in production (`barberos.activo=false`/`tenant_staff.active=false`). `BarberPilot_App`'s `LoginScreen.js` kept showing his tile because `BARBEROS_FALLBACK` was never reconciled against live data — removed manually as a one-off patch (commit `d6b4454`, OTA update `9fd3d41c-f66e-4bf4-9a45-eb1fa9f966e1`).
- **Known currently-stale instance, not yet fixed**: `barberpilot-control/index.html`'s `BB` array and `agenda-admin.html` still list Emerson/`b2` as `active:true` as of 2026-08-06 — confirmed incorrect against live `GET /barberos`. Out of scope for the `BarberPilot_App` fix that prompted this consolidated entry; tracked here so it isn't forgotten.

**Considered, not implemented**: failing loudly instead of falling back — if `GET /barberos` fails, show a clear error and refuse to render any barbero selection, rather than silently serving a fallback that's fresh today but guaranteed to go stale eventually. Deliberately not implemented, because the tradeoff differs by surface and is a product call, not a mechanical one:
- Staff-facing surfaces (`queue-dashboard.html`, `barberpilot-control`, `BarberPilot_App`'s login): failing loudly seems like a clear win — staff notice immediately and can retry, with low cost to getting it wrong.
- Customer-facing `checkin.html` (reached by scanning a QR code): failing loudly means a customer who hits a transient network blip can't check in at all and may just leave, a real revenue cost weighed against a fallback that's only ever wrong about which *specific* barbero to list — not whether check-in works at all. Whether that tradeoff is worth it is César's call, not something to decide unilaterally.

**Why deferred**: Each individual staleness incident has been patched tactically (manual array edit) rather than structurally (live fetch) every time it's been found, across three repos now. In the most recent instance (BarberPilot_App), this was an explicit, scoped user decision to patch now and defer the structural fix — not a technical judgment that patching is sufficient long-term. User indicates the stopgap is acceptable until a second tenant (`saulfino-maipu`) activates and needs an independently managed staff roster — at that point a single hardcoded array per surface can't serve two tenants and the live-fetch fix stops being optional.

**Severity**: Low — worst case is a dead/wrong tile in a picker; `POST /registros` and `POST /api/v2/auth/login` independently validate `bid` server-side regardless of what any fallback array says. Not a security or billing gap, a UX/staleness one. Only affects staff onboarding/offboarding, not day-to-day operation.

**Urgency**: Eventual — revisit next time the barbero roster changes (add/remove/reactivate), since none of these arrays update themselves. Escalates to Medium when the second tenant (`saulfino-maipu`) activates, since the hardcoded-array pattern breaks structurally (can't serve two tenants' rosters from one array), not just staleness, at that point.

**Closure path**: Each surface should fetch its roster live (`GET /barberos`) on load/mount and build its UI from the live response, falling back to a cached/hardcoded array only on fetch failure:
- `checkin.html`/`queue-dashboard.html`, `agenda-admin.html`, `sf-live`, `saulfino-web` already do this — just need their fallback arrays kept in sync until the two remaining fixes below land.
- `barberpilot-control/index.html`'s `BB`/`BB_CANONICAL_NAMES` need the sync logic fixed to add missing bids (not only patch `active` on existing ones) and to take the display name from the live response instead of the hardcoded map.
- `BarberPilot_App/LoginScreen.js` (and `App.js:192`) need to switch to the existing `useBarberos()` hook instead of reading `BARBEROS_FALLBACK`/`TODOS_PERFILES` directly — mirroring what `AdminScreen.js` already does.
Add a stale-while-revalidate cache layer so each surface still renders instantly from a cached roster while the live fetch resolves in the background. Test against `saulfino-maipu` once that tenant activates, to confirm each fetch is tenant-scoped correctly and roster A/B don't leak into each other.

**Status**: Open, narrowed scope (2026-10-08): `barberpilot-control`'s `BB` array and `BarberPilot_App`'s `LoginScreen.js`/`App.js` are the two confirmed-stale surfaces. `checkin.html`/`queue-dashboard.html`, `agenda-admin.html`, `sf-live`, and `saulfino-web` are all confirmed structurally fine (live-fetch with fallback) as of this date. Fail-loud-instead recommendation open, pending César's product call.

### 2026-08-04 — Migration numbering collision: two branches independently picked "Migration 040"

**Repo:** barberpilot-api

**Description**: This branch's `service_durations` safety-net migration (Task 1 of the Sillas wait-time work) and PR #31's `queue.productos_adjuntos` migration (`feature/persist-attached-products-to-queue`, merged to `main` first) both independently claimed the label "Migration 040" — each inserted at the identical point in the boot IIFE (immediately after Migration 039), developed concurrently with no coordination mechanism between the two branches to prevent picking the same next number. Discovered merging current `main` into this branch: `git merge origin/main` produced a real `CONFLICT (content)` in `index.js` at that exact insertion point — both blocks used the literal string "Migration 040" in their header comment and `console.log` line, not just a coincidental nearby-line textual clash. Resolved by keeping PR #31's Migration 040 exactly as merged into `main` (unchanged, original position) and renumbering this branch's migration to Migration 041, placed immediately after it in sequence. Concrete evidence that the informal-numbering gap already tracked below (`migrations/` folder being inert, real numbering living only as an ad hoc sequence in `index.js`) is a live source of merge conflicts, not just a documentation-clarity issue.

**Why deferred**: The immediate collision is resolved (this entry documents a fix already applied, not an open bug in the merged code). What's deferred is the underlying mechanism gap: nothing currently prevents two concurrent branches from picking the same next migration number again — there's no central registry, no lint/CI check, and no convention beyond "look at the highest number in `index.js` and pick the next one," which is exactly what both branches did independently. Building a real fix (e.g. a CI check that fails on duplicate "Migration N" labels, or moving to timestamp-based migration identifiers) is out of scope for this merge conflict fix.

**Severity**: Low — git's own merge conflict detection caught this immediately and correctly; there was no risk of silent data loss or of both migrations actually landing under the same number undetected.

**Urgency**: Eventual — no immediate trigger, but this is now the second piece of evidence (after the general `migrations/` folder gap below) that the informal numbering convention doesn't scale past one active branch at a time; strengthens the case for eventually giving that existing entry a real fix rather than leaving it as a documentation note.

**Status**: Open — this specific collision was resolved via renumbering (Migration 040 kept as PR #31 merged it, this branch's migration renumbered to 041). The underlying gap — no mechanism to prevent the next collision — remains open, same as the `migrations/` folder entry below.

### 2026-08-04 — `STATIC_DURATIONS` hardcoded in `index.js` instead of `tenant_config`

**Repo:** barberpilot-api

**Description**: The per-service default duration map used by `getServiceDuration()` (`STATIC_DURATIONS`, `index.js:3410-3418` — `Corte`, `Barba`, `Barba / Perfilado`, `Corte + Barba`, `Corte + Barba + Black Mask`, `Black Mask`, `Masaje craneal`) is a plain JS constant, not a `tenant_config` row. Every other tunable in this system that varies by business (bebidas, riesgo_fuga_dias, WhatsApp toggles, and the `auto_start_*` gates) goes through `tenant_config`; this one doesn't, so it can't be changed without a code deploy and doesn't follow the same single-source-of-truth pattern as the rest of the queue/timing configuration.

**Why deferred**: Out of scope for the Sillas wait-time work that surfaced it — that work extended the *duration estimation* logic around this constant without touching the constant's own storage mechanism, since migrating it would mean adding per-service catalog rows to `tenant_config` and a seed/migration for existing services, a separate and larger change.

**Severity**: Low — violates the single-source-of-truth principle, but the values rarely change and the current hardcoded set is correct for the only tenant (saulfino) using the queue system today.

**Urgency**: Eventual — worth doing whenever `STATIC_DURATIONS` needs to change per-tenant (a second tenant with different service names/durations onboarding onto the queue system) or needs to be editable without a deploy; no near-term trigger today.

**Status**: Open.

### 2026-08-04 — `migrations/` folder contains inert files nothing executes — real schema evolution happens via idempotent IIFE blocks in `index.js`

**Repo:** barberpilot-api

**Description**: `barberpilot-api/migrations/` holds `001_queue.sql` through `004_barberos.sql` plus `033_saulfino_maipu_whatsapp.js`. Grep across the whole repo (`.js`/`.sql`/`.md`) found zero code that reads, requires, or executes any file under `migrations/` — no `fs.readFileSync('migrations/...')` or equivalent anywhere. The actual, currently-authoritative migration mechanism is a single top-level IIFE in `index.js` (~line 7165-8500+) containing ~40 sequential, idempotent (`IF NOT EXISTS`) "Migration N" blocks that run non-fatally on every process boot, before `app.listen()` — confirmed up to Migration 041 as of this entry. A contributor who finds the `migrations/` folder and assumes it's the live migration history (a very natural assumption given the folder name and numbering) will be misled: most schema history isn't there at all, and the folder's own highest number (033) doesn't match the boot IIFE's highest number (041) — the two numbering sequences aren't the same thing and have drifted.

**Why deferred**: Out of scope for the Sillas wait-time work that surfaced it (that work added a `service_durations` `CREATE TABLE IF NOT EXISTS` safety net as Migration 041 in the IIFE — the only mechanism that's actually live — rather than a new file in `migrations/`, precisely because of this gap). Fixing the folder itself (e.g. a README explaining it's historical/inert, or removing it to avoid the misleading impression) is a documentation/cleanup task, not something this feature work should bundle in.

**Severity**: Medium — no production risk (the IIFE mechanism works and is idempotent), but actively misleading to any future contributor or automated tool that looks at `migrations/` expecting it to be authoritative.

**Urgency**: Eventual — worth at minimum a short README note in `migrations/` pointing to the real mechanism; no incident or deadline forcing this soon.

**Status**: Open.

### 2026-08-04 — Auto-start-on-close poller is single-tenant (`saulfino`-only), same limitation as `BARBERS`/`STATIC_DURATIONS`

**Repo:** barberpilot-api

**Description**: The auto-start-on-close reconciliation poller (`index.js` ~line 4527, `setInterval` every 15s) only checks `tenant_id='saulfino'` and loops over the `BARBERS` constant. This matches the queue system's existing single-tenant limitation — the `queue` table has no `tenant_id` column, and `BARBERS`/`STATIC_DURATIONS` are already hardcoded to saulfino with a pre-existing TODO comment — so this isn't a new gap, it's the poller correctly following the existing pattern rather than building a fake multi-tenant loop around a single-tenant table.

**Why deferred**: Building real per-tenant support here would require adding `tenant_id` to `queue` and reworking `BARBERS`/`STATIC_DURATIONS` into tenant-scoped lookups — a separate, larger change than the Sillas wait-time work that added this poller. There is no current trigger: only `saulfino` operates a queue today.

**Severity**: Medium — becomes a real functional gap (not just a stale comment) the moment `saulfino-maipu` or any other tenant activates its own queue/check-in flow, since this poller silently won't cover them and nothing will alert to that.

**Urgency**: Eventual — becomes Immediate when a second tenant's queue goes live. Tracked in-code as a `TODO` comment right above the poller's `setInterval` block; this entry is the durable, discoverable record of it.

**Status**: Open.

### 2026-08-04 — `PUT /queue/:id` has no auth middleware, allowing unauthenticated rewrite of a ticket's service/client_name/phone/barber_id

**Repo:** barberpilot-api

**Description**: `PUT /queue/:id` (`index.js:4181`) has never had auth beyond CORS — anyone who can reach the API can rewrite any open ticket's `service`, `client_name`, `phone`, or `barber_id` with no credentials. Found while hotfixing a related, more severe gap: the new `POST`/`DELETE /queue/:id/productos-adjuntos` endpoints (this same PR) were originally modeled on this route's auth (i.e. none), on the reasoning that it "matched the sibling route." A live probe against the production deploy of those new endpoints (2026-08-04) confirmed an unauthenticated request actually writes to a real `queue` row — which prompted adding `requireAnyAuth` to the two new endpoints, but `PUT /queue/:id` itself was left as-is, since fixing it wasn't in scope for that hotfix and changing it carries its own regression risk (need to confirm every current caller sends compatible auth before gating it).

**Why deferred**: The immediate hotfix was scoped narrowly to the newly-discovered, higher-severity gap (`productos_adjuntos` feeds commission-bearing checkout data; `service`/`client_name`/`phone` on this route do not, directly). Widening the hotfix to also gate this route risked breaking an as-yet-unaudited caller under time pressure during an active security fix. Tracking here instead of silently leaving it unrecorded.

**Severity**: Medium — no direct path to fraudulent billing (unlike the `productos_adjuntos` gap), but does allow unauthenticated tampering with a real customer's name/phone/assigned barber on an open ticket.

**Urgency**: Near-term — same class of issue as the gap just fixed; should be closed deliberately rather than discovered again via another live probe.

**Fix**: Audit every current caller of `PUT /queue/:id` (Sala de espera editor's "Actualizar servicio", any others) to confirm they already send a panel JWT or dashboard token, then add `requireAnyAuth` — same pattern just applied to the `productos-adjuntos` endpoints.

**Status**: Open.

### 2026-08-03 — "Servicio especial" (custom-priced service) sidebar feature is completely non-functional since 2026-07-17

**Repo:** barberpilot-control, barberpilot-api

**Description**: Any entry made via the sidebar's "SERVICIO PERSONALIZADO" field (`customNombre`/`customPrecio` inputs, `registrar()` in `barberpilot-control/index.html`) always fails validation on `POST /registros` in barberpilot-api and is permanently stuck in that browser's `bp_outbox`, retrying every 30s forever with no visible resolution path and no way to auto-recover:
- A typed name matching an existing catalog alias (`servicio_alias`) but at a different price → rejected via `precio_no_coincide`. The sidebar flow never sends `override`/`override_reason`, and the outbox retry loop has no UI to prompt for them, so this never self-resolves.
- A typed name not matching any alias at all → rejected via `alias_no_mapeado`, same permanent-failure shape.

This has been broken since the `servicios`/precio write-time validation went live with the July 17 price launch (barberpilot-api commit `6c57aab`, `docs/july16_price_change_migration.sql`) — the "Servicio especial" field itself predates that change and used to work fine (bare price-range validation only, `servicios` table was empty so the catalog-matching gate no-opped) before that gate was added. Confirmed structural via a real incident on 2026-08-01: an owner-entered "Corte" at a discounted $10,000 (catalog active price $13,000) stuck permanently in the outbox; the same real-world service only reached the database because the owner separately re-entered it via Sala de espera, a different write path (see below).

**Separate finding, same area**: `POST /queue/control/registrar` (the Sala de espera checkout path, barberpilot-api `index.js:3759`) calls the same `resolverServicioYValidarPrecio()` function but only acts on `servicio_inactivo` — it never checks or enforces `precio_no_coincide` at all. So the two paths that both ultimately write to `registros` enforce opposite rules for the same underlying business rule ("price should match catalog unless justified"): the sidebar/outbox path is too strict with no override mechanism, while the Sala de espera path has no price guard whatsoever. This should be resolved as one consistent design — a real override/discount-authorization mechanism available on both paths with equivalent scrutiny — not patched separately per path.

**Why deferred**: Root cause confirmed via code trace + live production verification (2026-08-03 investigation), but no fix had been written yet at the time of investigation — documented first per this project's "verify, then wait for review" gate before any validation code changes.

**Severity**: Medium — real money/pricing logic is affected (a discounted or negotiated service can silently never reach the database), but there is a working manual workaround: re-entering the same service via Sala de espera succeeds (confirmed it records the actual charged price, not a catalog default).

**Urgency**: Near-term, pending input — flagged to César on how often "Servicio especial" custom pricing is actually used in practice. If it's used regularly, this should move to Immediate, since it will keep silently failing on every single use until fixed.

**Status**: Closed 2026-08-03. An override/reason mechanism (barberpilot-api#28, barberpilot-control#19) was built and tested against this exact bug, but the business owner decided against keeping "Servicio especial" at all — both override PRs were closed unmerged 2026-08-03 (branches kept for reference/rollback: `feature/variable-pricing-override` in both repos). The feature itself was removed via PR #22 (`fix/remove-servicio-especial`, barberpilot-control) — **confirmed merged into `main`** via merge commit `7615235` (2026-08-03T20:56:03Z), verified directly against `origin/main` on 2026-08-06, not just GitHub's PR-state label. Closed as resolved-by-removal rather than resolved-by-fix — the underlying `alias_no_mapeado`/`precio_no_coincide` asymmetry between `POST /registros` and `POST /queue/control/registrar` documented above still exists in the backend generally (nothing else currently exercises it now that the one caller that hit it is gone), so it's left here as a structural note rather than deleted outright.

### 2026-08-03 — Product sales via the checkout sidebar were silently failing to sync — confirmed live, fix implemented

**Repo:** barberpilot-control, barberpilot-api

**Description**: `registrarProducto()` (`barberpilot-control/index.html:2168`) sends the product name as `snom` through the exact same `POST /registros` write-time validation gate as services (`resolverServicioYValidarPrecio()`, barberpilot-api `index.js:1420-1481` — see the "Servicio especial" entry above for the full mechanism). Product names ("Cera Modeladora Fuerte", "Champú 2 en 1 (Biotina)", etc.) are matched against `servicio_alias`, a table that only ever contains haircut/barba service phrases — a product name will essentially never match, so `alias_no_mapeado` — a hard, unconditional reject with no override path — fires on every attempt, **every product sale through this path 400s permanently and sits stuck in `bp_outbox` forever**, identical in shape to the "Servicio especial" bug.

**Confirmed live 2026-08-03**, not just circumstantial: a stuck `bp_outbox` item from the owner's own console — `sid:"p02"`, `snom:"Cera Modeladora Fuerte"`, correct flat-10% commission math, `status:"pending"`, `attempts:33`, `last_error:"HTTP 400"`. Verified via `GET /registros/dia` that this exact item never reached the database.

**Full historical scope, corrected**: the original "since 2026-07-17" framing was based on a one-week check and was too narrow. Querying `GET /stats/mes/:periodo` across 2026-05 through 2026-08 found **12 product sales that DID succeed** (4 in June, 8 in July, the last on 2026-07-24 — mostly under barbero b3/Samuel, since deactivated), all with the genuine live-checkout `id: TK<epoch>` format (not the "Ingresar histórico" backfill tool's `TK_MAN_` format — confirmed that tool never touches this validation path at all: `descargarHistorico()` only builds a client-side downloadable JSON with zero API calls, and the README's manual-import path, `POST /registros/bulk`, has no validation of any kind). **Zero product sales have succeeded in all of August.** The exact cutover date between "gate was permissive" and "gate started rejecting products" sits somewhere between 2026-07-24 and 2026-08-01 — not pinned down further; no `servicio_alias` table read access to confirm precisely, and not worth guessing beyond the evidence.

This is very likely why the owner believed past product sales succeeded — a stuck outbox item shows as an unremarkable "pending" count, never the red "Error de sync" badge (that only fires once `attempts>=5` **and** the item independently gets flagged `status:'error'`; HTTP-level rejections that stay `status:'pending'` forever — like this one, 33 attempts in — never escalate to the visible badge at all).

**Fix**: `fix/validate-product-registros-by-catalog` (barberpilot-api, draft, unmerged as of 2026-08-03). Adds a `resolverProducto()` helper (shared with PR #29's `productos_adjuntos` handling, avoiding a second copy of the same lookup) that checks whether `POST /registros`' `sid` matches a real `producto_id` **before** falling into the `servicio_alias` matcher — if it does, resolve as a product (existence + active-only, no price-match enforcement, deliberately — see the PR for why) and skip the service-only alias logic entirely. Normal service registro validation is provably untouched (diff shows the existing `if(catalogRows.length>0){...}` block's body moved into an `else`, zero lines inside it changed). No frontend change needed — confirmed `registrarProducto()` already sends the real `producto_id` as `sid`. Once deployed, the currently-stuck item (and any other silently-pending product sales on any device) self-heal automatically on their next retry — `drainOutbox()` retries both `pending` and `error` items every 30s, on page load, on reconnect, and on panel login; no manual `localStorage` cleanup needed per device, though a device does need its tab open/reloaded at some point for its own stuck items to retry.

**Why deferred**: Not deferred any further — implemented same-day once confirmed live and quantified. Kept as an open entry only until the PR actually merges and deploys.

**Severity**: High — confirmed, not hypothetical: product revenue recorded locally in the panel did not exist in the production database for every sale attempted since the cutover (~2026-07-24 to 08-01 onward).

**Urgency**: Immediate — fix implemented, awaiting merge/deploy + visual confirmation.

**Status**: Fix confirmed merged — PR #30 (`fix/validate-product-registros-by-catalog`) merged into `barberpilot-api`'s `main` via merge commit `bfe44d2` (2026-08-03T22:57:51Z), verified directly against `origin/main` on 2026-08-06 (the local `main` ref in one worktree was stale and had to be re-fetched to confirm this). Not independently verified beyond the merge itself: whether it has actually deployed to production, and whether the previously-stuck `bp_outbox` item has actually synced, were not checked as part of this verification pass — reopen those two specific checks separately if they haven't been confirmed elsewhere.

### 2026-08-03 — A ticket closed via the barber app's own status endpoint bypasses attached-product billing entirely

**Repo:** barberpilot-api, BarberPilot_App

**Description**: Found while implementing server-persisted "Adjuntar producto" (`docs/attach-product-to-ticket-design_2026-08-03.md` §6). There are two independent ways a `queue` row becomes `status='DONE'`:
- The panel's checkout, `POST /queue/control/registrar` — creates the service `registros` row, reads and bills any `productos_adjuntos`, computes commission, resets `productos_adjuntos` to `[]`.
- The barber app's own close action, `PUT /queue/:id/status` with `{status:'DONE'}` (barberpilot-api `index.js:4396`) — sets `status='DONE'` and does queue-position/duration-learning bookkeeping, but **creates no `registros` row at all** and has no knowledge of `productos_adjuntos`.

If a panel staff member attaches a product to an in-progress ticket (cross-sell) and the barber then closes that same ticket from their own app (BarberPilot_App, via the second path) before the panel checks it out, the attached product is never billed and never generates commission — the `queue` row becomes `status='DONE'` (disappearing from `GET /queue/control`'s `WHERE status != 'DONE'` filter, so it's no longer visible/actionable in Sala de espera) with `productos_adjuntos` still populated but now unreachable through any UI. Not cleared, not billed — just orphaned.

**Why deferred**: This is a pre-existing architectural duality (two independent ways to close a ticket) that predates attached products entirely — reconciling it (e.g. having the app's status endpoint also check for and bill `productos_adjuntos`, or blocking a DONE transition via that path while products are attached) is a larger decision about which path should be authoritative for billing, out of scope for the persist-attached-products task that surfaced it.

**Severity**: Medium — real commission/revenue loss if it happens, but requires a specific sequence (product attached via panel, then the *barber's own app* closes the same ticket before panel checkout) that may be rare in actual usage today; not confirmed to have happened yet.

**Urgency**: Monitor-only until attached-product usage is common enough for this sequence to plausibly occur — revisit if/when it is.

**Status**: Open.

### 2026-08-01 — Sala de espera's client-autocomplete index caches name+phone+visit history in localStorage with no forced eviction

**Repo:** barberpilot-control

**Description**: The phone-autocomplete widget on the "Sala de espera" tab (`salaCargarIndiceClientes`/`salaActualizarIndiceCliente` in `index.html`) fetches the full tenant client list (`GET /clientes`, panel-authenticated) once per tab load and caches a reduced copy — `id`, `nombre`, `telefono`, `ultimo_barbero`, `ultimo_servicio`, `ultima_bebida`, `ultima_visita` — in `localStorage` under `sfsf_cliente_idx`, with a 10-minute staleness TTL (stale-while-revalidate: an expired-but-present cache is still read instantly, then silently refreshed in the background). The TTL only governs when a background refetch happens — it does not evict or expire the `localStorage` entry itself. On a shared/staff counter device, this means ~500 clients' name, phone number, and last-visit summary persist in browser storage indefinitely (until the next successful fetch overwrites the key), independent of panel login/logout.

**Why deferred**: This is the explicit design requested for the feature (fast client-side filtering with zero network calls per keystroke requires a local cache) — building a more elaborate storage story (e.g. clearing the cache on panel logout, encrypting it, or moving it to an in-memory-only cache that's refetched every tab load) was out of scope for this task and would trade away the instant-on-reload benefit stale-while-revalidate is meant to give. Notably, `notas`/`cumpleaños` (the more sensitive staff-only fields `GET /clientes` also returns) are deliberately excluded from the cached shape via `_salaReducirCliente` — only name/phone/last-visit summary are persisted.

**Severity**: Low — the data (client name, phone, last barber/service/drink) is the same data already shown in-app to any panel-authenticated staff member; the gap is storage *persistence*, not new *exposure*. Notas and cumpleaños (higher-sensitivity fields) are explicitly excluded.

**Urgency**: Monitor-only — revisit if counter devices are ever shared with non-staff, or if a compliance requirement around client PII retention in browser storage comes up.

**Status**: Open.

### 2026-07-31 — Migration 036 inserts `category='UTILITY'` (uppercase) into `whatsapp_message_log`, violating the table's own lowercase CHECK constraint

**Repo:** barberpilot-api

**Description**: `whatsapp_message_log.category` has `CHECK (category IS NULL OR category IN ('utility','marketing','authentication','service'))` — lowercase only, since Migration 030. Migration 036's booking-confirmation call site (`POST /appointments`, the `confirmacion_reserva_anticipada_v2` send) passes `category: 'UTILITY'` uppercase to `sendTemplateMessage()`, which writes it straight through to that column. Found while building `WA_TEMPLATE_REGISTRY` for `POST /admin/whatsapp/conversaciones/:identificador/plantilla` — deliberately used lowercase there instead of copying the existing call site's value.

**Why deferred**: Out of scope for the `plantilla` endpoint task — fixing Migration 036's call site is a one-line change but touches a different, already-shipped feature, not something to fold silently into an unrelated PR.

**Severity**: Medium — when triggered, the `whatsapp_message_log` INSERT for that send fails the CHECK constraint (a real DB error, not just a wrong value), so the booking-confirmation send itself would fail whenever `whatsapp_confirmacion_reserva_enabled` is true.

**Urgency**: Immediate-if-that-gate-is-ever-enabled — currently dormant because `whatsapp_confirmacion_reserva_enabled` is `false` in production (confirmed live, 2026-07-31), so no send has actually hit this path yet. Becomes urgent the moment someone flips that gate on.

**Status**: Open.

### 2026-07-31 — `WA_TEMPLATE_REGISTRY` is duplicated between barberpilot-api (source of truth) and barberpilot-control (`WA_PLANTILLAS`)

**Repo:** barberpilot-api, barberpilot-control

**Description**: `POST /admin/whatsapp/conversaciones/:identificador/plantilla`'s `WA_TEMPLATE_REGISTRY` (`index.js`) — the 5 approved templates, their body parameter names, and categories — has an equivalent, independently maintained copy in `barberpilot-control/index.html` as `WA_PLANTILLAS`, used to render the template picker's fields. The backend registry is authoritative and validates independently (a stale frontend copy can't bypass it, only misrender), but the two lists have no shared source and can drift.

**Why deferred**: The two repos have no shared package/module boundary today — building one for a 5-entry, rarely-changing lookup table wasn't proportionate to this task.

**Severity**: Low — worst case is a cosmetic mismatch (wrong/missing field shown in the picker), never an incorrect send, since the backend is the real gate.

**Urgency**: Eventual — revisit if/when the template set changes, or if a shared frontend/backend config mechanism gets built for other reasons.

**Status**: Open.

### 2026-07-31 — "Enviar" button in the WhatsApp template picker appeared unresponsive once, via the Clientes-tab entry point

**Repo:** barberpilot-control, barberpilot-api

**Description**: The "Enviar" button in the WhatsApp template picker appeared unresponsive once during manual testing via the Clientes-tab entry point (`waOpenConversacionForPhone`). Root cause not confirmed — testing coincided with the local dev server becoming unreachable (`ERR_CONNECTION_REFUSED` observed in browser console at the time), which is the most likely explanation and requires no code fix. However, a genuine gap was found and fixed independently: fetch-level network failures in `waSendPlantilla()` were not shown to the user before this fix.

**Why deferred**: No confirmed reproduction against a real, always-on backend — the observed instance has a mundane, non-code explanation.

**Severity**: Low.

**Urgency**: Watch — reopen only if reproduced against production.

**Status**: Open (watch). If "Enviar does nothing" recurs against the real deployed backend (not local dev), re-open with fresh reproduction steps.

### 2026-07-30 — Real secrets (`JWT_SECRET`, `DASHBOARD_READ_TOKEN`) committed in plaintext in `STAGING.md`

**Repo:** barberpilot-api

**Description**: `STAGING.md` (tracked, not gitignored, committed in `7fb4b36`) documents a spin-up/promotion guide that includes a table of literal environment variable values for the staging environment, including `JWT_SECRET` and `DASHBOARD_READ_TOKEN` in plaintext. These values are permanently in git history and readable by anyone with repo access, past or present, regardless of any later edit to the file. Found incidentally while rotating production's `JWT_SECRET` (2026-07-30) — not itself touched or rotated as part of that task, per explicit direction to track it separately rather than fix it inline.

**Why deferred**: Out of scope for the production `JWT_SECRET` rotation task that surfaced it — that task was scoped to production only, and scrubbing this properly (rotating the staging values *and* removing them from git history, since editing the file alone leaves the values recoverable from any prior commit) is a separate, larger operation the project owner asked to track rather than act on immediately.

**Severity**: Medium — these are staging-scoped credentials, not production's, but "staging" still gates real panel auth and a real dashboard read token; anyone with repo clone access has them regardless of current file contents.

**Urgency**: Near-term — relevant to the already-planned `JWT_SECRET` rotation before commercial launch; should be closed out as part of that broader initiative rather than left indefinitely.

**Fix**: Removing `STAGING.md` from the working tree and/or gitignoring it going forward is **not sufficient by itself** — the values are permanently visible in git history (commit `7fb4b36` and every commit since that includes the file) to anyone with repo access, regardless of what the file contains today or whether it's deleted. Closing this properly requires **both**:
1. **Rotate the specific staging `JWT_SECRET` and `DASHBOARD_READ_TOKEN` values referenced in that file** (same method as the production rotation: generate fresh, set via `railway variable set --stdin`, never printed) — these two exact values must be treated as permanently exposed regardless of any future edit to the file, so rotation is required independent of whatever happens to the file itself.
2. **A separate decision on whether git history rewrite is warranted** (e.g. BFG Repo-Cleaner or `git filter-repo`), weighed against this repo's actual visibility/access scope — rewriting history is a disruptive operation (rewrites commit hashes, requires force-push, breaks any existing clones/forks) and shouldn't be treated as automatic just because the values were committed; it's the project owner's call whether the exposure surface justifies it.

Replacing the literal values in `STAGING.md` with placeholders (matching `env.staging.example`'s `<generate-fresh-for-staging>` convention) is good hygiene but addresses neither of the two points above on its own.

**Status**: Open.

### 2026-07-29 — `productos` data is coupled to servicios' fail-closed gate in `GET /config/negocio` and `.../publico`

**Repo:** barberpilot-api

**Description**: Phase B (productos catalog, `docs/productos_catalog_design_2026-07-29.md`) deliberately made an empty `productos` list a normal, non-error response — no 503 gate, unlike servicios. But `productos` is added to the *same* response object as `servicios` in both `GET /config/negocio` and `GET /config/negocio/publico`, and servicios' own pre-existing fail-closed check (`if (servicios.length === 0) return res.status(503)...`) runs *before* `productos` is even fetched. So if servicios were ever empty for a tenant, the whole response 503s and `productos` never reaches the client either — even though productos itself has no reason to be unavailable. This is currently inert for saulfino (a real, non-empty servicios catalog) and doesn't come up for saulfino-maipu either (that tenant doesn't call this endpoint yet — no frontend targets it).

**Why deferred**: Fixing it means splitting `productos` out of the shared response shape (a separate endpoint, or restructuring the existing one to fetch/return each catalog independently of the other's fail-closed state) — a larger change than this task's scope (adding productos alongside the existing shape, not restructuring it).

**Severity**: Low — no tenant currently hits this; would only bite a future tenant with a legitimately empty servicios catalog but real productos, which doesn't exist today.

**Urgency**: Monitor-only — revisit if/when a tenant without a servicios catalog (e.g. a pure retail/product-only shop) needs `GET /config/negocio`.

**Fix**: Fetch and attach `productos` independently of the servicios 503 check — either move the productos fetch/attach before the servicios gate (simplest, keeps one endpoint), or split into two response fields computed and failed independently.

**Status**: Open.

### 2026-07-28 — `appointments.cliente_id` linkage added going forward only — existing rows permanently unlinked (deliberate, no backfill)

**Repo:** barberpilot-api

**Description**: Migration 032 (`index.js`) adds `appointments.cliente_id` (TEXT, nullable) with a real enforced FK (`fk_appointments_cliente_id`, `FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE SET NULL`) plus `idx_appointments_cliente_id`. `POST /appointments` (saulfino's live booking endpoint, confirmed to be the one `agenda.html` actually calls — not `POST /api/v2/tenants/:slug/appointments`) now calls `findOrCreateClienteByTelefono()` and stores the resolved id on every new row going forward. It also now rejects with `400` if `client_phone` is missing/empty, mirroring `agenda.html`'s existing client-side check — the API itself is no longer fail-open on this.

**Deliberate scope limit — no historical backfill**: existing `appointments` rows (29 for `saulfino`, confirmed via direct query before writing the migration) keep `cliente_id = NULL` permanently, unless a future, separate, deliberate decision changes that. This was an explicit instruction for this change, not an oversight — matching 62 non-placeholder-phone rows against `clientes` retroactively (fuzzy phone-format matching, choosing a winner on ambiguous multi-candidate matches, etc.) is a real data decision that deserves its own review, not something to fold silently into a schema/wiring change.

**Also confirmed out of scope, not touched by this change**: `POST /api/v2/tenants/:slug/appointments` (the mae-studio v2 endpoint) — verified it's a fully separate code path (own route handler, own validation block, own INSERT) with no shared middleware or shared validation function with `POST /appointments`, so it was safe to leave its phone-optional validation exactly as-is. It also does not read the new `cliente_id` column.

**Related, separate, still-open gap**: `queue.appointment_id` (see the entry below) already has a real, enforced FK to `appointments(id)` at the DB level, but is populated on 0 of 711 existing `queue` rows, because nothing in `checkin.html`/`queue-dashboard.html` currently sends `appointment_id` on check-in. Not addressed by this change (different table, different linkage, explicitly out of scope) — noted here only because both gaps sit on the same `appointments` table and a future person closing one might reasonably assume the other is also closed.

**Why deferred (backfill)**: Out of scope for this round — this task was scoped to wiring new bookings and closing the fail-open phone gap, not retroactive data reconciliation.

**Severity**: Low — existing appointments simply have no client-history linkage; nothing reads `appointments.cliente_id` yet in a way that would break or misbehave on NULL (no consumer exists yet).

**Urgency**: Monitor-only — becomes relevant only when a feature that reads `appointments.cliente_id` for client history ships; revisit backfill feasibility then, as a separate deliberate decision.

**Status**: Open (by design — the "gap" here is the backfill decision staying open, not a bug). Migration 032 itself: **Closed** 2026-07-28 — verified via a rolled-back transaction against production (confirmed `fk_appointments_cliente_id` exists via `pg_constraint`, confirmed a bogus-FK insert is rejected, confirmed a real-FK insert succeeds, then rolled back with row counts matching the pre-transaction baseline). Merged via PR (branch `feat/appointments-cliente-linkage`) after explicit sign-off.

### 2026-07-28 — `queue.appointment_id` has a real enforced FK but is populated on 0 of 711 rows

**Repo:** barberpilot-api (frontend wiring needed in `checkin.html`/`queue-dashboard.html`)

**Description**: `queue.appointment_id` (INTEGER) already has a genuine, enforced FK — `queue_appointment_id_fkey`, `FOREIGN KEY (appointment_id) REFERENCES appointments(id)` — confirmed directly via `pg_constraint`, not assumed. `POST /queue/checkin` does read `appointment_id` from the request body and both uses it for a 409 duplicate-checkin guard and writes it on `INSERT`, so the plumbing is correct end-to-end at the code level. The gap: **no frontend currently ever sends `appointment_id`** on check-in — a direct count against production shows 0 of 711 total `queue` rows have a non-null `appointment_id`, across the table's entire history.

**Why deferred**: Discovered during read-only reconnaissance for a different task; wiring a frontend to send `appointment_id` (presumably when a client checks in against a pre-existing booking, so the queue entry and the appointment can be correlated) is a frontend change outside this repo's scope, and wasn't part of any task that has come through yet.

**Severity**: Low — nothing currently depends on this correlation existing; it's dormant, correctly-built infrastructure with no consumer.

**Urgency**: Monitor-only — revisit if/when a feature needs to correlate a queue check-in back to the appointment that generated it (e.g. no-show tracking, appointment-to-actual-visit reconciliation).

**Fix**: Whichever frontend creates queue check-ins from an existing appointment (`checkin.html` and/or `queue-dashboard.html` — not yet determined which flow this applies to) needs to pass `appointment_id` in the `POST /queue/checkin` body when the check-in originated from a known appointment.

**Status**: Open.

### 2026-07-24 — Two parallel WhatsApp-sending code paths in barberpilot-api (`sendWhatsappMetaCloud` vs. `services/whatsappService.js`)

**Repo:** barberpilot-api

**Description**: This repo has two independent ways to send a WhatsApp message via the Meta Cloud API:
1. `sendWhatsappMetaCloud()` (`index.js`) — global, not tenant-scoped, reads `META_PHONE_ID`/`META_WA_TOKEN` env vars, no message log, no webhook receiver, no idempotency, free-text only, Graph API `v21.0`. Wired into `startPostSvcPoller()`, a live 5-minute poller sending real post-service follow-up messages today, tracked via `registros.whatsapp_sent`/`whatsapp_sent_at`.
2. `services/whatsappService.js` — tenant-scoped (reads `whatsapp_phone_number_id` per tenant from `tenant_config`), reads `META_WHATSAPP_ACCESS_TOKEN`, full `whatsapp_message_log` persistence, webhook receiver with signature verification, `wamid`-based idempotency, template + free-text sends, Graph API `v25.0`, currently targeting the Meta sandbox test number only.

**Why deferred**: Deliberate choice, not an oversight — confirmed with the requester before writing any code. Migrating the existing poller onto the new infrastructure now would touch a currently-working, live, automated customer-messaging flow, which was explicitly out of scope for the sandbox integration task that added path 2. Consolidating them is a real follow-up, not optional forever — two independently-maintained ways to call the same external API is exactly the kind of duplicated-source-of-truth pattern this registry exists to flag.

**Severity**: Medium — no correctness bug today (the two paths don't conflict, they target different message flows), but every future WhatsApp feature has to make a fresh decision about which path to build on, and `sendWhatsappMetaCloud`'s sends are invisible to `whatsapp_message_log` — no delivery-status tracking, no reconciliation, no webhook correlation for that flow's messages.

**Urgency**: Eventual — revisit once the sandbox integration graduates to the real business number; consolidating before then would mean redoing the migration once real credentials replace the sandbox ones anyway.

**Fix**: Migrate `startPostSvcPoller()` to call `sendFreeTextMessage()` (or `sendTemplateMessage()` if post-service follow-ups move to a template) and log through `whatsapp_message_log`, then remove `sendWhatsappMetaCloud()` and the `registros.whatsapp_sent`/`whatsapp_sent_at` tracking columns it was built around.

**Status**: Open.

### 2026-07-24 — `whatsapp_message_log.cliente_id` has no FK, and no correlation logic populates it yet

**Repo:** barberpilot-api

**Description**: `whatsapp_message_log.cliente_id` is a plain nullable `TEXT` column, deliberately without a foreign key to `clientes(id)` — matching a client to a WhatsApp identifier (phone number today, increasingly a BSUID as Meta's username rollout progresses) is a separate, larger architecture discussion, not something to design as a side effect of building the message log. Nothing populates `cliente_id` on insert; every row is created with it `NULL`.

**Why deferred**: Explicitly out of scope for the sandbox integration task. Also genuinely harder than a simple FK: a phone number alone isn't a reliable long-term key, so correlation logic needs its own design pass, not a rushed FK add.

**Severity**: Low today — the sandbox integration doesn't depend on this correlation working; it's forward-looking infrastructure.

**Urgency**: Monitor-only until client-facing WhatsApp features (e.g. showing message history on a client's profile) are actually planned.

**Fix**: A future task should design the correlation logic first (candidate keys: `telefono` matched against `clientes.telefono` with the same placeholder-awareness used elsewhere, `wa_user_id`/BSUID once a stable mapping exists), backfill `cliente_id` for existing rows, then add the FK.

**Status**: Open.

### 2026-07-24 — `requirePanelRole` never resolves `tenant_id` — every route built on it hardcodes `'saulfino'`, blocking real multi-tenant use of any panel feature built this way

**Repo:** barberpilot-api (consumed by barberpilot-control)

**Description**: There are two separate tenant-auth systems in this codebase. `requireTenantAuth` (the "V2 AUTH MIDDLEWARE" block, used by barber/socio logins) verifies a JWT against `auth_sessions`/`tenant_staff` and sets `req.tenantId = payload.tenant_id` — a real, working per-request tenant resolution mechanism. `requirePanelRole` (the middleware issued by `POST /api/v2/panel/login`, consumed by barberpilot-control's staff session) verifies a different JWT shape and sets `req.actorIdentity`/`req.panelRole`/`req.panelUserId` — but **never extracts `tenant_id` onto `req`**, even though the panel JWT payload already carries a `tenant_id` claim. Every route gated by `requirePanelRole` has no way to resolve which tenant it's serving except by hardcoding a literal, and every one of them does: `'saulfino'`. This isn't specific to any one feature — it's structural to the middleware itself.

Confirmed examples from the client-memory feature (Phase 1): `GET /clientes/:id/memoria`, `PATCH /config/bebidas-disponibles`, `GET /clientes?q=`, `POST /clientes/:id/notas`, `DELETE /clientes/:id/notas/:notaId` — all hardcode `tenant_id='saulfino'`. This list is illustrative, not exhaustive — the same pattern predates this feature; see `validateRegistro`'s `bid` validator, which hardcodes `'saulfino'` with an explicit comment noting it's correct only "while only saulfino uses the POS system."

**Why deferred**: `barberpilot-control` (the only consumer of `requirePanelRole`-gated routes today) only ever authenticates against `saulfino` — there is no real multi-tenant traffic hitting this middleware yet, so the gap has no active consequence. Fixing it requires either adding `tenant_id` extraction to `requirePanelRole` itself (a shared-middleware change touching every route that already uses it) or giving barberpilot-control its own tenant-scoped login against a different tenant's data, which doesn't exist yet either.

**Severity**: Medium — no active data leak (single-tenant traffic today), but this is a hard blocker for onboarding any second tenant (e.g. Mae Studio) to any feature built on `requirePanelRole`, not just this one. The blast radius grows with every new route added under this pattern.

**Urgency**: Eventual — becomes Immediate the moment a second tenant needs a panel-authenticated feature (Amenities admin, client memory, or anything else gated by `requirePanelRole`).

**Status**: Partially resolved 2026-07-29. The predicted trigger happened — the WhatsApp admin conversations feature (`GET/POST /admin/whatsapp/...`, powering barberpilot-control's "Mensajes WhatsApp" tab) needed real multi-tenant behavior (saulfino vs. saulfino-maipu). Fixed the root cause: `requirePanelRole` now sets `req.panelUser = decoded`, exposing the JWT's `tenant_id` claim exactly like `requireConfigNegocioAuth`/`requirePanelAuth` already did — purely additive, zero regression risk. The 3 WhatsApp endpoints now derive `tenantId` from `req.panelUser.tenant_id` instead of a hardcoded literal.

Still open: every *other* route built on `requirePanelRole` (staff CRUD, `/config/bebidas-disponibles`, `/clientes*`, servicios/productos precio endpoints) still hardcodes `'saulfino'` literally — the middleware fix makes migrating them possible, it doesn't migrate them; that's separate, unscoped work per route. Also still open: there is no way to actually authenticate against `barberpilot-control` as `saulfino-maipu` yet — Migration 033 seeded that tenant minimally (id/slug only, explicitly no `panel_users` row), and the login form has no tenant selector.

**2026-10-08 addition**: `POST /api/v2/staff` and `PATCH /api/v2/staff/:bid` (fixed in this same session — see the "Agregar barbero" auth regression entry above) are two more confirmed members of the still-hardcoded list. Deliberately used an explicit `const tenantId = 'saulfino';` with a comment pointing back to this entry, rather than `req.panelUser.tenant_id || 'saulfino'` — a silent `||` fallback here would misroute every future write to `'saulfino'` the instant a second tenant's panel admin calls either route, with nothing to surface the mistake. Migrating these two to real tenant resolution is still unscoped future work, same as every other route in this list.

### 2026-07-24 — `bebida` never reaches `registros` when a barbero closes a service from BarberPilot_App instead of the control panel

**Repo:** barberpilot-api, BarberPilot_App

**Description**: The client-memory feature (Phase 1) wires `bebida` from `queue.bebida` into `registros.bebida` in exactly one place: `POST /queue/control/registrar`, which reads the `queue` row server-side and copies `bebida` (along with `cliente_id`, `cliente_nombre`, `cliente_telefono`) onto the `registros` INSERT at completion time. That route is only called by barberpilot-control's Sala tab. When a barbero closes the same queue-originated service from their own app (BarberPilot_App) instead, it goes through a different, generic endpoint (`POST /registros`) which never reads the `queue` row at all and has no `bebida` field in its INSERT column list. A visit checked in with a bebida selection, then closed via the barbero's own app rather than Sala, will have that bebida silently absent from the permanent `registros` record.

**Why deferred**: BarberPilot_App is a separate repo and was explicitly out of scope for the client-memory task, which only touched barberpilot-api, barberpilot-control, and saulfino-web. Fixing this would require either adding a `bebida` field to BarberPilot_App's own close-service submission or having the generic `POST /registros` endpoint look up `queue.bebida` server-side when `sid==='queue'` — neither was scoped or approved as part of this task.

**Severity**: Low — `bebida` is a courtesy/cosmetic field, not billing or identity data. The consequence is an incomplete-but-not-incorrect record, and only for visits closed via the barbero app rather than the control panel.

**Urgency**: Eventual — no active incident; grows in relevance in proportion to how much barberos use their own app (vs. Sala) to close out queue-based services.

**Status**: Open.

### 2026-07-24 — `GET /clientes/lookup` has no enumeration-specific rate limit, only the generic global one

**Repo:** barberpilot-api

**Description**: `GET /clientes/lookup?phone=` is fully unauthenticated (no `requirePanelRole`/`requireAnyAuth` middleware) and, as of the client-memory feature, now also returns `ultima_bebida`/`ultimo_barbero` on a match — more information than the pre-existing `found`/`cliente.nombre` response carried. It only inherits the app-wide `globalLimiter` (100 requests/60s per IP, applied to every route with no opt-out) — there is no endpoint-specific stricter limit the way there is for the login routes (all 10 requests per 15 minutes, keyed by tenant+bid/ip). 100 phone numbers per minute per IP is enough to enumerate whether a given number belongs to a known client, and each match now also triggers a full `computeClienteRecurrencia('saulfino')` recomputation (scans all `registros` for the tenant) — a load-amplification vector, not just a privacy one.

**Why deferred**: This endpoint and its lack of a dedicated limiter both predate the client-memory feature — this task extended its response but did not touch its auth or rate-limit posture. Flagging now because the feature raises the stakes of the pre-existing gap, not because the feature introduced it.

**Severity**: Medium — no financial data exposed, but real phone-number enumeration risk plus a per-match recomputation cost that scales with `registros` table size, both currently bounded only by the generic 100/min/IP global limit.

**Urgency**: Eventual — no observed abuse; should be revisited before this route's response is relied on for anything more sensitive, or if unauthenticated traffic to it increases materially.

**Status**: Open.

### 2026-07-22 — `registros`, `queue`, and `gastos` have no `CREATE TABLE` anywhere in this repo — CI's "fresh Postgres" boot smoke test has been silently no-op'ing on 6 migrations since it was introduced

**Repo:** barberpilot-api

**Description**: While adding Migration 023 (`fk_registros_cliente_id`), CI failed it with `relation "registros" does not exist` on the smoke test's fresh, empty Postgres 14 database. Investigating turned up that `registros` is never created anywhere in `index.js` — there is no `CREATE TABLE registros`, only `ALTER TABLE`/`CREATE INDEX`/`UPDATE` statements that assume it already exists. The same is true for `queue` and `gastos`. Pulling the full migration-line log for a CI run showed this has been silently happening on **every single boot smoke test run since the workflow was introduced**, across 6 migrations: 003, 005, 007, 014 (`registros`), and 008, 012 (`queue`). All fail with `relation "X" does not exist` on a from-scratch database, but every run still shows as `success` in GitHub Actions because each failure is individually non-fatal and the smoke test's own checks never touch those tables.

**Practical consequence**: `barberpilot-api` cannot actually boot into a working state from a genuinely empty database — `registros`, `queue`, and `gastos` must be created by some process entirely outside this repo's version-controlled migrations (most likely a one-time manual `psql` setup when the app was first stood up on Railway). This means the boot smoke test has never actually proven that migrations touching these three tables work. Any future migration touching `registros`, `queue`, or `gastos` will report "CI green" without CI ever having exercised it against a table that exists.

**Why deferred**: Out of scope for the FK-constraint work that surfaced it — reconstructing accurate `CREATE TABLE` statements for 3 core, long-lived production tables (especially `registros`, which holds real revenue history) from scratch is a separate, careful undertaking that deserves its own review. Production itself is unaffected — these tables already exist there and have for a long time.

**Severity**: Medium — doesn't affect production correctness today, but significantly undermines confidence in "CI green" as a signal for any future schema migration touching these tables.

**Urgency**: Near-term — the CI signal is actively misleading for exactly the kind of change (schema migrations) this smoke test exists to catch. Worth fixing before the next migration that touches `registros`, `queue`, or `gastos` ships on the strength of a green check alone.

**Fix**: Either (a) add proper `CREATE TABLE IF NOT EXISTS` statements for `registros`, `queue`, and `gastos` to this repo's migration sequence (reconstructed carefully against the real production schema), bringing the schema fully under version control; or (b) seed CI's ephemeral Postgres from a production schema dump as a setup step in `boot-smoketest.yml`.

**Status**: Open.

### 2026-07-21 — Partial unique index on `clientes(tenant_id, telefono)` only exempts the hardcoded default placeholder, not tenant-configured ones

**Repo:** barberpilot-api

**Description**: Migration 022 (`uq_clientes_tenant_telefono_real`) enforces `UNIQUE (tenant_id, telefono)` on the `clientes` table, excluding rows where `telefono = '+56900000000'` (`TELEFONO_PLACEHOLDER_DEFAULT`). The application layer (`isRealPhone`/`getPlaceholderPhones`) supports a *tenant-configurable* list of placeholder values via `tenant_config.telefono_placeholders` (a JSONB array), so a tenant could in principle configure additional placeholder strings beyond the default. Those are correctly excluded at the application layer, but the DB-level partial index predicate is a hardcoded literal — it cannot reference `tenant_config` (a partial index predicate must be an immutable expression, not a subquery). So if a tenant configures a second placeholder value and two clients end up with that same value, the DB uniqueness constraint would still reject the second INSERT even though the application no longer treats that value as identifying.

**Why deferred**: Out of scope for this round — no tenant has configured a placeholder list yet beyond the `saulfino` default. Closing it properly would mean either (a) accepting this isn't fixable as a single partial index, since Postgres constraints can't reference another table, or (b) moving to an application-level uniqueness check (transaction + row lock) instead of a DB constraint for the placeholder-exemption case specifically.

**Severity**: Low — worst case is a failed INSERT (500) on a specific edge case, not silent data corruption; the existing default-placeholder path is unaffected.

**Urgency**: Monitor-only — no tenant currently configures a non-default placeholder list. Revisit if/when a tenant other than `saulfino` adopts this convention.

**Status**: Open.

### 2026-07-20 — Outbox has no deactivation-aware guard — offline transactions for a deactivated barber fail silently forever

**Repo:** barberpilot-control (with API-side interaction via `barberpilot-api`'s active-only `validateRegistro`)

**Description**: During the post-deactivation incident where Samuel (b3) was deactivated (2026-07-19), his still-pending outbox items subsequently failed 5+ times with "bid inválido" because `validateRegistro` now rejects b3 (active-only query in `_loadBarberCache`). The generic red-dot sync indicator gave no information about which barber, which transactions, or why — requiring forensic investigation to identify. `drainOutbox()` retries `POST /registros` (or `/gastos`) items indefinitely at 30-second intervals until `attempts >= 5`, at which point `status` flips to `'error'` and `pruneOutbox()` never removes them. The `updateSyncBadge()` indicator shows a red dot with the text "Error de sync" — but gives no barber name, no transaction count, no `last_error` text, and no distinction between a transient network failure and a permanent validation rejection.

When a barber is deactivated, any of their locally-queued (unsynced) transactions become permanently irrecoverable via normal outbox drain, because `validateRegistro` uses a live `WHERE activo = true` query. Revenue records sitting in the outbox since before deactivation are silently discarded (from an operator perspective) — there is no alert, no notification to check a specific device, and no recovery path that doesn't require manual DB intervention.

**Why deferred**: Recovery of the incident items took priority. The structural fix requires changes across both `barberpilot-control` and `barberpilot-api`; out of scope for the incident resolution turn.

**Severity**: Medium — real revenue records can be permanently lost with no warning beyond a generic red dot that could be dismissed as a transient connectivity blip.

**Urgency**: Near-term — this pattern occurred once already in production (Samuel b3, 2026-07-19). Any future barber deactivation or deletion will reproduce it identically if there are offline-queued transactions for that barber at the time.

**Recommended fix (three layers)**:
1. **Detection**: `updateSyncBadge()` should surface `last_error` text for error-state items — at minimum a count and message, ideally a panel showing bid, fecha, precio, and last_error per item.
2. **Prevention**: On barber deactivation, warn if any outbox items reference that barber's bid, or flush/escalate those items as part of the deactivation flow.
3. **API resilience**: `validateRegistro` could be relaxed for historical bids — accept bids that existed in the barber table (even inactive) as long as the record's `fecha` is within the barber's active period.

**Status**: Open — incident recovery completed as of 2026-07-20; structural fix (above) not implemented.

### 2026-07-20 — Revert endpoint doesn't check `activo` before restoring a service's prior price

**Repo:** barberpilot-api

**Description**: `POST /api/v2/config/servicios/:servicio_id/precio/revertir` queries the current active price row and the immediately-prior row, then closes and reopens without first verifying that the service itself is still `activo = true`. In the normal case this is harmless — `GET /config/negocio/publico` only surfaces active services, so a retired service's price is unreachable from any live UI. The gap only bites if an admin manually POSTs to the revert endpoint for a service that has since been deactivated, which would silently create a live price row for a service that no consumer will render or validate against.

**Why deferred**: Edge case with no plausible near-term trigger (requires a deliberate admin action against a service that's already invisible to all consumers). Out of scope for Phase 2 Step 1.

**Severity**: Low — an orphaned live price row for an inactive service; no billing risk, but creates noise in the price history.

**Urgency**: Monitor-only.

**Fix**: Add the same `activo` check from the PATCH endpoint (reject with `servicio_inactivo 400` if `activo = false`) before proceeding with the close+reopen.

**Status**: Open.

### 2026-07-19 — `NEON_DATABASE_URL` env var name obscures its disaster-recovery-only purpose

**Repo:** barberpilot-api / Infra (Railway environment)

**Description**: Railway's environment for `barberpilot-api` contains a variable named `NEON_DATABASE_URL` pointing to the Neon.tech warm-standby DR replica. The generic name led to its accidental use as a connectivity workaround when `DATABASE_URL`'s internal Railway hostname couldn't be reached from outside Railway's private network — causing two ad-hoc SQL steps (Winder insert; Samuel deactivation) to run against the Neon replica instead of the Railway primary. Both steps were subsequently corrected in Railway via Migrations 009 and 009a, and the Neon replica was confirmed to be an accurate copy, so no data integrity harm resulted. But the root trigger was purely the ambiguous env var name.

**Why deferred**: Environment variable changes in Railway are a manual operation in the Railway dashboard — outside the scope of a code commit, and a decision reserved for César.

**Severity**: Medium — no live code path in `index.js` reads `NEON_DATABASE_URL` (confirmed via grep: zero hits), so the variable is inert for the running API. Risk is procedural: an operator under time pressure could repeat the same workaround against the wrong database without realizing it.

**Urgency**: Near-term — relevant any time someone needs to run ad-hoc SQL and reaches for an env var by name.

**Recommended fix**: Rename `NEON_DATABASE_URL` to `NEON_DR_URL` or `NEON_STANDBY_URL` in the Railway environment variables dashboard. The credential itself stays unchanged — only the Railway env var name changes.

**Status**: Open — pending César's decision on the Railway dashboard rename.

### 2026-07-19 — `COM_PAGO` commission rates duplicated in `barberpilot-api` and `barberpilot-control`

**Repo:** barberpilot-api, barberpilot-control

**Description**: Commission rates per payment method (`efectivo: 0.50`, `debito: 0.43`, `transferencia: 0.50`) are hardcoded in two places:
1. `barberpilot-api/index.js` — `COM_PAGO` constant (used by `POST /queue/control/registrar` to compute `bb`/`neg` when closing a queue entry)
2. `barberpilot-control/index.html` — `COM` object (used for the live split preview in the Sala editor and cierre de caja flow)

These must stay in sync manually. `SERVICE_PRICES` was the analogue for prices and was removed during the server-driven price/roster cutover; commission rates don't have an equivalent DB table yet, so the duplication remains.

**Why deferred**: `COM_PAGO` was not in scope for the price/roster cutover, which was focused on eliminating hardcoded prices and rosters from client files. A commission table would require a new migration, a new API field, and updates across every consumer of the split preview — a separate, larger lift.

**Severity**: Medium — a commission rate change requires editing two files and redeploying both repos. Worse: `barberpilot-api` computes the *actual* `bb`/`neg` stored in `registros`, while `barberpilot-control` computes the *preview* shown before confirming — if they drift, the preview shown to staff would be wrong while the ledger entry is correct, creating confusion without a billing error.

**Urgency**: Eventual.

**Recommended fix**: Add a `tenant_comisiones` table (or extend `tenant_metas`) with per-payment-method rates, expose via `GET /config/negocio`, and have `barberpilot-control` read `com_rates` from the server response for its preview.

**Status**: Open.

### 2026-07-13 — Queue `ABANDONED` auto-cleanup (Migration 008) uses UTC `CURRENT_DATE`, not Santiago-local

**Repo:** barberpilot-api

**Description**: `barberpilot-api/index.js:5289-5302` ("Migration 008") abandons stale queue entries with `(checkin_at AT TIME ZONE 'America/Santiago')::date < CURRENT_DATE`. `CURRENT_DATE` resolves in the DB session's timezone, confirmed via `SHOW timezone` to be `Etc/UTC`, not Santiago's. Chile is UTC-4 in July, so there's a genuine ~4-hour window every night (Santiago 20:00–24:00 = UTC 00:00–04:00) where, if the server restarts in that window, an entry checked in earlier that same Santiago evening would show as "from a previous day" and get wrongly abandoned a day early.

**Why deferred**: Investigated only to determine whether it explained an observed 100%-abandoned state (it doesn't — the actual cause is tickets not being closed via `/queue/control/registrar` at all, with gaps of 1-17+ days between check-in and abandonment).

**Severity**: Low.

**Urgency**: Monitor-only — only matters if a server restart lands in the 4-hour Santiago midnight window while a real ticket is still open.

**Recommended fix**: Swap `CURRENT_DATE` for `(NOW() AT TIME ZONE 'America/Santiago')::date`.

**Status**: Open.

### 2026-07-13 — `PaymentSheet.js` resolves service name via raw string match, not `servicio_alias`

**Repo:** BarberPilot_App

**Description**: `PaymentSheet.js` finds the catalog entry via `SERVICIOS.find(s => s.nom.trim().toLowerCase() === entry.service.trim().toLowerCase())` — a raw match against `nombre_canonico`, not alias-aware resolution like the backend's `resolverServicioYValidarPrecio` (which goes through `servicio_alias`). Simulated the exact match logic against all 531 historical `queue.service` values: **83.4% match cleanly, 16.6% (88 entries) fall through to manual price entry** — almost entirely (87 of 88) the `'Corte Clásico'` vs. server's `'Corte'` naming variant.

**Why deferred**: Deferred per César's implicit agreement this round. Fixing properly means exposing `servicio_alias` data to the app (`GET /config/negocio` would need to return aliases per service) — a bigger lift than fit in the July 16 scope.

**Severity**: Low — not a pricing-correctness risk; write-time validation (`resolverServicioYValidarPrecio` via `POST /registros`) still catches and rejects a mismatched manually-typed price.

**Urgency**: Near-term — a real, measured UX/workflow friction gap: roughly 1 in 6 real transactions closed via this screen force the barber to type the price manually instead of getting it auto-filled.

**Status**: Open.

### 2026-07-13 — `/queue/control/registrar`'s `precioOverride` has no `override`/`override_reason` UI equivalent

**Repo:** barberpilot-api, barberpilot-control

**Description**: `POST /registros` supports a documented override flow — a price mismatch is rejected unless the caller sends `override:true` plus a non-empty `override_reason`, logged to `registro_precio_override`. `/queue/control/registrar`'s `precioOverride` field has no equivalent reason-logging or explicit-override-flag mechanism; it just silently accepts whatever price staff type in barberpilot-control's Sala editor.

**Why deferred**: Not itself broken — a pre-existing, working, legitimate staff workflow (e.g. discretionary discounts). Flagged as an asymmetry worth resolving for consistency, not an active defect.

**Severity**: Low.

**Urgency**: Eventual — an audit-trail gap, not a correctness one.

**Status**: Open.

### 2026-07-13 — Unjustified `OR estado IS NULL` clause, widespread across `barberpilot-api`

**Repo:** barberpilot-api

**Description**: `WHERE ... AND (estado = 'confirmado' OR estado IS NULL)` appears in at least 4 places in `index.js` (including `GET /stats/mes/:periodo`, the route `dashboard-facturacion.html`'s goal figures are computed from). Queried production: **zero rows in `registros` have `estado IS NULL`** — every row is either `'confirmado'` (1,373 rows) or `'rechazado'` (8 rows, correctly excluded). No legacy pre-`estado`-column category this clause is protecting; appears to be an unreviewed carryover, copy-pasted forward each time a new query needed this filter.

**Why deferred**: Out of scope for the goal-unification round it was found in — fixed only in the one new function that round added (`calcularMetaAnchorServicios`), which uses the strict filter. The other 4 pre-existing occurrences were left untouched.

**Severity**: Low — currently a no-op, zero NULL-estado rows exist in production.

**Urgency**: Monitor-only — latent risk if anything ever inserts a `registros` row with NULL `estado` not intending it as confirmed revenue.

**Status**: Open.

---

## Closed / Resolved

### 2026-07-31 — `whatsapp_message_log.telefono` (no `+`) was compared directly against `clientes.telefono` (`+56...`), silently failing to resolve real registered clients

**Repo:** barberpilot-api

**Description**: `whatsapp_message_log.telefono` arrives from Meta's webhook as raw digits (e.g. `56942173299`, no leading `+`), while `clientes.telefono` consistently stores a leading `+`. Two call sites compared these directly with an exact match and silently returned no match for real, registered clients. Found via a real report — a registered client showed only their raw phone number in the WhatsApp conversation view instead of their name.

**Fixed** via `toClienteTelefono()` (`services/clientesService.js`) — prepends `+` if not already present, applied at both affected call sites. Deliberately not a hardcoded `+56` reconstruction: real production data includes at least one non-Chilean number (the Meta sandbox test number).

**Status**: Closed 2026-07-31. Verified against real production data.

### 2026-07-23 — `POST /registros`'s new active-bid check (PR #7) — correction to originally-stated scope

**Repo:** barberpilot-api

**Description**: PR #7 added a `SELECT active FROM tenant_staff WHERE tenant_id='saulfino' AND bid=$1` check to `POST /registros`, originally described as "closing a fail-open gap" where the endpoint trusted the client-supplied bid blindly. That framing was not fully accurate — a pre-existing `express-validator` middleware (`validateRegistro`) already validated `bid` against a 5-minute-cached `barberos.activo` list. The new check adds freshness (fresh-per-request vs. 5-min cache) and a second independent source of truth (`tenant_staff.active` vs. `barberos.activo`) — real defense-in-depth, not redundant, but the original "closes a fail-open gap" framing overstated what was missing before.

**Status**: Closed — both validation layers confirmed live and correctly scoped as of 2026-07-23; no code change needed, only this documentation correction.

### 2026-07-22 — `initMultiTenant()` (creates `tenant_staff`) runs too late in the boot sequence — ordering bug

**Repo:** barberpilot-api

**Description**: Migrations 006, 009a, and 010 all reference `tenant_staff` and all three failed on CI's fresh database with `relation "tenant_staff" does not exist` — a pure ordering bug (`initMultiTenant()` wasn't called until after those migrations ran), same class as the Migration 022 fix (`initTenantColumns()` needed moving earlier for the identical reason).

**Fix**: Moved `await initMultiTenant();` earlier in the boot sequence, before Migration 003's block.

**Status**: Closed 2026-07-22. Merged via PR #5, Railway auto-deploy confirmed live. Production's `tenant_staff` had existed all along regardless (migrations 006/009a/010 already succeeded there); the bug only ever manifested on a from-scratch boot, so CI's fresh database was sufficient to fully verify the fix.

### 2026-07-21 — `registros.cliente_id` has no enforced FK constraint despite the code declaring one

**Repo:** barberpilot-api

**Description**: `ALTER TABLE registros ADD COLUMN IF NOT EXISTS cliente_id TEXT REFERENCES clientes(id) ON DELETE SET NULL` was a no-op for the `REFERENCES` clause, because `cliente_id` already existed on `registros` before that clause was written into the line — a direct `pg_constraint` query confirmed no such constraint actually existed. By contrast `queue.cliente_id` genuinely had the FK. Discovered and worked around during the `CLI_1783015495337` cleanup (see below) by manually nulling `registros.cliente_id` before deleting the client row.

**Fix**: Migration 023 added `fk_registros_cliente_id` after confirming zero orphaned `cliente_id` values in `registros` (all 110 non-null values resolved to a real `clientes.id`).

**Status**: Closed 2026-07-22. Merged via PR #4, reconfirmed live post-deploy via a direct `pg_constraint` query against production.

### 2026-07-21 — Three `cliente_nombre` values sharing one `cliente_id` in production (CLI_1783015495337)

**Repo:** barberpilot-api

**Description**: Found 3 `registros` rows under the same `cliente_id` with three different `cliente_nombre` values (Cristian, Alejandro, Sebastián) — a reused/shared client ID that had merged different real people into one CRM identity.

**Status**: Closed 2026-07-21 — César confirmed the 3 people don't need individual tracking. Ran, in one transaction: nulled `cliente_id` on the 3 affected `registros` rows (verified all other fields unchanged, SUM(precio) identical before/after for the 3 affected dates), then deleted the orphaned `clientes` row. The 3 `queue` rows referencing this id self-nulled via `queue.cliente_id`'s real FK.

### 2026-07-20 — `registros_audit.modificado_por` reads a client-typed free-text field, not `req.actorIdentity`

**Repo:** barberpilot-api, barberpilot-control

**Description**: `registros_audit.modificado_por` was populated from a client-supplied free-text field rather than the server-verified actor identity available on every authenticated request — an audit trail that could be spoofed or inaccurate.

**Status**: Closed 2026-07-20. `requirePanelRole` now stamps `req.actorIdentity` from the verified JWT; `PATCH /registros/:id/pago` derives `modificado_por` server-side from that identity, removing the client free-text field and its UI input entirely. Verified live: `registros_audit` rows 29–31 show `"Cesar Valencia"` (JWT name), not client-typed text. Commits: `6d7a1d5` (barberpilot-api), `0a8c85f` (barberpilot-control). Fix was pending César's direct in-person confirmation to Claude Code specifically (a standing rule for this class of change) before being applied.

### 2026-07-19 — `tenant_servicio_precios` reads never check `valid_from`

**Repo:** barberpilot-api

**Description**: Every read of `tenant_servicio_precios` filtered only on `valid_to IS NULL` — `valid_from` was stored but never compared against `NOW()`, meaning a price change couldn't be genuinely scheduled ahead of time without activating early.

**Status**: Closed 2026-07-19. `AND tsp.valid_from <= NOW()` added to both `fetchServiciosActivos()` and `resolverServicioYValidarPrecio()` as part of the Phase 3 Step A/B deploy; confirmed live.

### 2026-07-13 — Near-miss: Corte auto-filled at $13.000 in queue-closing flow on César's device, 3 days before the sanctioned July 16 change

**Repo:** barberpilot-control

**Description**: César reported that a manual check-in correctly showed Corte at $12.000, but the price auto-filled to $13.000 (the not-yet-live July 16 price) once that check-in transitioned to the queue/Sala-closing step. Investigation was about to start when César independently confirmed the cause from another device/browser.

**Root cause**: Isolated to one specific browser/machine on César's end — a client-side cache layer, likely compounded by a CDN edge artifact — not a real deployment. No code was actually pushed and no DB row was actually flipped; no public/customer-facing exposure.

**Status**: Closed 2026-07-13. No code or DB changes needed. Resolution: incognito mode on the affected machine as a practical workaround while the stale cache naturally expired.

---

## Informational — no action needed

### 2026-07-31 — Meta error code 130472 ("User's number is part of an experiment") on manual template sends is expected, occasional behavior

**Repo:** barberpilot-api

**Description**: Affects a small, Meta-selected fraction of numbers, blocks MARKETING-category templates specifically outside an open 24h window, self-resolves once the client messages the business first. Do not retry the same send — it will fail identically. No code action needed; documented so it's not mistaken for a regression during future troubleshooting.

**Status**: N/A — not a defect.

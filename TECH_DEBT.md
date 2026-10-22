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

**Last updated:** 2026-10-13 (configuration program: Stage 0 and Stage 1 live, Stage 2a approved; rate-limiter findings → Stage R; remaining hardcoded business constants; two entries closed)

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

> **2026-10-12 batch — "Configuration as single source of truth" program.** Entries
> dated 2026-10-12 below come from the read-only investigation that opened this
> program (Phase 1, Steps A and A-2, and the owner's production query results).
> Line references are to `origin/main` at: barberpilot-api `e2d7c5c`,
> barberpilot-control `fc27dff`, BarberPilot_App `2b101ff`, saulfino-web `835fab5`,
> sf-live `12ff272`. Planned stages referenced below (Stage 0, C, 1, 2, 3) are the
> program's execution order, approved by the owner on 2026-10-12. **Security
> findings are deferred by owner decision on 2026-10-12 — scheduled after the
> functional program**; their severities are not downgraded by that deferral.

> **2026-10-13 batch.** Progress on the program: **Stage 0** (freeze local service
> and commission edits) live — barberpilot-control `573ef84`, owner-verified.
> **Stage 1** (backend service catalog API, Migration 042) live — barberpilot-api
> `9dbac29`, owner-verified in production (sale + 6 read-only queries). **Stage 2a**
> (catalog from the API in Administración and cobro) approved — barberpilot-control
> PR #33, merge pending. Order from here (owner, 2026-10-13): Stage 2a → **Stage R**
> (rate limiter) → Step A-3 → Stage C → Stage 2b → Stage 3. Line references in the
> 2026-10-13 entries are to barberpilot-api `9dbac29` and barberpilot-control `573ef84`.

> **2026-10-14 batch.** **Stage L2a** live — barberpilot-api `3d21ed4` (PR #39) and
> barberpilot-control `1a4ee35` (PR #34), both merged ≈10:02–10:05 Santiago on an
> explicit owner exception: control's KPI month, history, today's sales, rotation and
> the KPI dashboard read one authenticated range per period; `dashboard-config.js` is no
> longer published. **KPI-tab fix** live — barberpilot-api `b521947` (PR #40) and
> barberpilot-control `bf84697` (PR #35). Then the read-only KPI / bonus / barbers-per-period
> investigation (findings below); the owner's final decisions are in the program notes.
> Order (owner, 2026-10-14): sf-docs → layout → API barber periods → backfill → KPI tab and
> Administración (October rules) → Comisión/Propina → KPI dashboard and sf-live → App →
> remove hardcoded barber lists → November scoring (live and announced before 2026-11-01);
> security phase after the functional program. Line references in this batch are to
> barberpilot-api `b521947`, barberpilot-control `bf84697`, BarberPilot_App `2b101ff`,
> sf-live `f2d2728`.

### 2026-10-14 — `DASHBOARD_READ_TOKEN` was published on the public GitHub Pages site — CRITICAL (deferred)

**Repo:** barberpilot-control (exposure), barberpilot-api (what the token unlocks)

**Description**: From 2026-07-10 (commit `42a784d`) until 2026-10-14, `.github/workflows/deploy-pages.yml` wrote the `DASHBOARD_READ_TOKEN` GitHub secret into `dashboard-config.js` and published it with the site, so anyone could download the token at `livedatacl.github.io/barberpilot-control/dashboard-config.js`. Whether the published value equals production's was never verified (that would mean using the credential). Treat the token as **compromised**. In the API it unlocks: `POST /registros`, `GET /clientes/export/csv` (all clients), `/registros/rango`, `/gastos/rango`, `/resumen/rango`, `/queue/control`, `PUT /queue/:id/status`, `POST`/`DELETE /queue/:id/productos-adjuntos`, `POST /mensajes`, `GET /mensajes/:bid`, `GET /appointments/admin`, `POST /barber-schedule`, `/events` (as `?token=`), `/admin/restore-status`, `/admin/whatsapp/stats`. Stage L2a (`1a4ee35`) removed the publishing step; the file has answered 404 since 2026-10-14. Remaining senders of the token: control's manual staff-token field (`staffAdminToken`, the `x-dashboard-token` fallback in `getAuthHeaders`), and control's `/events` live-update stream, which connects **only** with that pasted token. The `DASHBOARD_READ_TOKEN` GitHub Actions secret is no longer read by anything.

**Why deferred**: Owner decision 2026-10-13 — all security work (rotation included) goes to the final security phase.

**Fix**: rotate `DASHBOARD_READ_TOKEN` in Railway (together with the staging `JWT_SECRET`/`DASHBOARD_READ_TOKEN` exposed in `STAGING.md`, see the 2026-07-30 entry); delete the unused GitHub secret; replace the pasted-token field and the `/events` token with the panel login.

**Severity**: Critical — client personal data and sales writes were reachable with a publicly downloadable value.

**Urgency**: Near-term — first item of the security phase (credential rotation).

**Status**: Open — exposure stopped 2026-10-14; rotation deferred by owner decision.
**Update 2026-10-21**: the owner rotated `DASHBOARD_READ_TOKEN` in the Railway `barberpilot-api` service (new strong random value; never recorded or printed) and pasted it into the panel's "Token de administrador" field. **The rotation is not active yet**: the API reads the variable once at startup, and production has not restarted since 2026-10-20 22:29 UTC (still commit `3cc2671`) because Railway deploys are paused (see the 2026-10-21 Railway incident below). Until the API restarts the server still uses the previous value. Impact while pending: the panel's live-events stream (`/events?token=`) and any call that depends on the pasted token fail with 401; panel-login routes and sf-live (socio login) are unaffected. After the restart: anything still holding the OLD token is refused — including the UptimeRobot monitor of `/admin/restore-status`, which must be updated with the new value. Still open for the security phase: `JWT_SECRET` rotation, the staging values in `STAGING.md`, deleting the unused GitHub secret.

### 2026-10-14 — KPI tab: the individual goal was divided by a browser-dependent barber list (affects scores, tiers and bonuses)

**Repo:** barberpilot-control

**Description**: `calcPuntaje` divides the month's group goal by `BARBEROS_ACT = BB.length` (`index.html:4892`, comment "barberos activos"). `BB` is this browser's cached list: the localStorage cache, plus `BB_DEFAULT` after "Restaurar valores por defecto" (`:7004`, `:7815`), plus active barbers from `GET /barberos`. `_mergeBarberosLive` only ever adds barbers or marks them active, never inactive. The owner's laptop used **8** (b1, b2, b4, b5, b6, b7, admin, b3); the correct divisors are Aug 3, Sep 3, Oct 4. Every extra row lowers each barber's individual target, raising production points, scores, tiers and bonuses. The team-average score (`:5280`) also averages every row. Production check by the owner (information only; no retroactive correction): the tab showed tier A ($10.000) for b1, b5, b6 in August and for b6 in September, where the correct rules give B; service billing missed the group goal in both months ($4.865.000 and $4.742.000 vs $8.014.600), so nothing was payable. In total the tab showed **$40.000 more** in bonuses than the rules allow.

**Why deferred**: Fixed in stage 5 (KPI tab on the barber-period function), after stages 3–4.

**Severity**: High — pay-affecting figures.

**Urgency**: Immediate — must be live before October bonuses are calculated (end of October).

**Status**: Open — stages 3–5 in progress.

### 2026-10-14 — KPI tab: bonus rules don't match the owner's rule

**Repo:** barberpilot-control, barberpilot-api

**Description**: Against the owner's rule (group goal first; individual goals only if met; equal individual goal for barbers active in the month; paid by tier):
- **Group goal is only a banner.** `metaCumplida` (`index.html:5040`) drives the "bonos activos / bloqueados" message (`:5189`, `:5210`), but the per-barber bonus (`:5313`, shown `:5335`) and "Bonos a pagar" (`:5284`) ignore it.
- **The goal check counts products.** The tab compares the month's total sales, products included (October to date: $1.598.000 = services $1.576.000 + products $22.000), while the API's goal (`calcularMetaAnchorServicios`) is services only, strictly `confirmado`.
- **Two bonus amounts on one screen.** The table pays fixed `BONUS_MONTO` (S $20.000, A $10.000; `:4980`), while the panel above it shows `BONUS_PCT` of billing (S 0.5 %, A 0.25 %), the default mode (`:4979`).
- **A low score shows as disqualified.** `gradeFromScore` (`:4936`) returns X both for an explicit disqualification and for any score below 35, and the tier card labels X "Descalificado · Falta grave" (`:5433`).
- **Bonus settings live in each browser.** Mode, amounts, percentages and even a goal override (`metaOverride`) are read from that browser's localStorage `sfsf_kpi_config` (`cargarConfigKpi`, `:4984`).

**Why deferred**: Stage 5 implements the decided rules (group goal from the API, services only, with an audited per-month override; potential vs payable bonus; S 0.5 % / A 0.25 % of the month's service billing; B/C/D without bonus; X only when the owner sets it; config in the backend).

**Severity**: High — what is shown is what gets paid.

**Urgency**: Immediate — before end-of-October bonuses.

**Status**: Open — stage 5.

### 2026-10-14 — Business values hardcoded in the KPI scoring and attendance stars; tips component unreachable

**Repo:** barberpilot-control

**Description**: Hardcoded in `index.html`: ticket references 12.300 and 14.000 (`:4894`–`:4895`, ticket points), the tips targets (26 working days, 5 tips/day, $5.000/day → 130 tips and $130.000 a month, `:4849`–`:4851`), the tier cut-offs 90/75/55/35 (`:4936`), the bonus defaults (`:4980`–`:4981`), the upsell threshold $12.000, and the attendance stars' fixed 10:00/20:00 with 15/30/60/90-minute steps (`HORARIO_APERTURA`/`HORARIO_CIERRE`, `estrellasPorHorario`, `:4596`), even though the backend keeps per-weekday shop hours in `tenant_calendar_config`. The tips targets are unreachable: the tips component scored **0 for every barber in every month** (owner's production check).

**Why deferred**: Stage 5 moves the October values to backend config (`tenant_config`, seeded with today's values); stage 9 recalibrates the November values.

**Severity**: Medium.

**Urgency**: Near-term — stages 5 and 9.

**Status**: Open.

### 2026-10-14 — Shop hours missing in the backend; calendar, holidays and goal settings can't be edited from the panel

**Repo:** barberpilot-api

**Description**: `tenant_calendar_config` was seeded with weekday weights only (Sunday 0, Monday–Friday 1, Saturday 0.536; `index.js` Migration 017 seed), so its `hora_apertura`/`hora_cierre` are empty. The owner's hours: Monday–Friday 10:00–20:00, Saturday 10:00–15:00, Sunday closed. There is no API route to edit `tenant_calendar_config`, `feriados`/`tenant_feriados_override` or `tenant_meta_anchor_config` (goal floor 6.500.000, growth 10 %, base 2026-05). The goal grows only when a month meets its target; it has stayed at $8.014.600 since June.

**Why deferred**: Stage 5 seeds the hours and adds the goal override; editing from Administración comes with the config screens.

**Severity**: Medium.

**Urgency**: Near-term — stage 5.

**Status**: Open.

### 2026-10-14 — Two holiday sources: a backend table seeded only from 2026-07-16, and a hardcoded list in sf-live

**Repo:** barberpilot-api, sf-live, BarberPilot_App, barberpilot-control

**Description**: The API has `feriados` (date, name, mandatory flag; global) plus `tenant_feriados_override` (whether the shop opens), seeded only from 2026-07-16 to 2027-03-27 (Migration 019), with no API route to edit them. The API's working-day count uses them (`/config/negocio`, `index.js:1265`–`1300`). sf-live keeps its own hardcoded `FERIADOS_CHILE_2026` (`index.html:1058`, used at `:1231`). The App's `metas.js` falls back to a Sundays-only count, and the control KPI tab assumes 26 working days. Missing May–July 2026 holidays: owner decision 2026-10-14 — not needed, logged only.

**Why deferred**: Owner decision: one backend holiday source per tenant, editable from Administración and used everywhere (stage 6 for sf-live and the dashboard; stage 9 for punctuality). A holiday is never a "no clock-in = 0" day.

**Severity**: Medium.

**Urgency**: Near-term — stages 5–9.

**Status**: Open.

### 2026-10-14 — No history of when barbers started and left

**Repo:** barberpilot-api, barberpilot-control

**Description**: Activar/Desactivar (`PATCH /api/v2/staff/:bid/deactivate|reactivate`, and `active` in `PATCH /api/v2/staff/:bid`) only flipped `tenant_staff.active` and `barberos.activo`, with no date, no audit row and no log line on success. `tenant_staff.created_at` is real only for barbers created from Administración (e.g. Angie, 2026-10-08); for the original barbers it is the date the multi-tenant seed ran. So no report could know who belonged to a past period. The owner confirmed the periods (b1 2026-05-02→open, b2 2026-05-02→2026-07-24, b3 2026-05-02→2026-07-18, b4 2026-05-22→2026-06-15, b5 2026-06-30→open, b6 2026-07-19→2026-10-09, b7 2026-10-08→open; 2026-05-02 is the start of the system's data, not a hire date).

**Why deferred**: Being built — stage 3 (`barbero_periodos`, written by the toggles and creation in the same transaction; "barbers active in a period" API; sales-outside-periods check) and stage 4 (backfill with exactly the confirmed periods).

**Severity**: High — the KPI divisor and every per-barber period view depend on it.

**Urgency**: Immediate — before end-of-October bonuses.

**Status**: Open — in progress.

### 2026-10-14 — Barber lists hardcoded, keyed by name, or browser-dependent

**Repo:** barberpilot-control, sf-live, BarberPilot_App, barberpilot-api

**Description**: control: `BB_DEFAULT` (includes David; `index.html:7004`), `BB_CANONICAL_NAMES` (`:7014`), and a cached list that never marks barbers inactive (`_mergeBarberosLive`). KPI dashboard: `BB_COLORS` keys (`dashboard_kpis_barberia.html:301`), replaced by active names from `/config/negocio/publico` (`:325`); per-barber views filter **by name** (`:657`, `:794`, `:927`), so a past barber's sales in a past period drop out of the per-barber views. sf-live: `_sfBarberos` (`:1841`) and `SILLAS_BARBS` (`:882`), per-barber cards by name (`renderBarberos`, `:1857`). App: `BARBEROS_FALLBACK` (`constants/index.js:28`); `AdminScreen` keeps per-barber KPIs only for current barbers (`:146`, `:152`), silently skipping others' sales. Control's day close, summary and register already use a sound rule (`_barberosParaImpresion`, `:3033`: active barbers plus anyone with sales).

**Why deferred**: Stages 5–8 move every period view to the barber-period function, keyed by `bid`, and remove the hardcoded lists.

**Severity**: Medium.

**Urgency**: Near-term.

**Status**: Open.

### 2026-10-14 — `GET /barbero/:bid/mes/:periodo` refuses inactive barbers (403), blocking their history

**Repo:** barberpilot-api

**Description**: The route checks `tenant_staff.active` (`index.js:2281`) and answers 403 for a deactivated barber, even for months when they worked here.

**Why deferred**: Stage 7 (App) lifts it for past periods using the barber-period history.

**Severity**: Low.

**Urgency**: Eventual — stage 7.

**Status**: Open.

### 2026-10-14 — Clock-ins: typed corrections stay in the browser; the server overwrites without audit

**Repo:** barberpilot-control, barberpilot-api

**Description**: The owner records clock-ins in control. The "Entrada/Salida" button (`marcarHora`, `index.html:4209`) stores the moment it was pressed and sends the day's list 3 seconds later. A typed time (`guardarHoraManual`, `:4235`) is saved **only in that browser** until the next button press or the 23:00 automatic send. The server (`POST /horarios/:fecha`, `index.js:3588`) upserts with `COALESCE`, with no previous value, author or reason; a time can't be cleared, and only today's clock-ins can be edited in the panel. The `horarios` table (and `kpi_evaluaciones`) has no `CREATE TABLE` in the repo; both were created by hand.

**Why deferred**: Stage 9 (November punctuality) adds an end-of-day "marcas faltantes" alert and an audit of every clock-in creation and correction (original value, new value, author, timestamp, mandatory reason). Barber self clock-in (App/QR) is a future idea, logged only.

**Severity**: Medium — from November, clock-ins decide 15 points.

**Urgency**: Near-term — before 2026-11-01.

**Status**: Open.

### 2026-10-14 — Staff activate/deactivate take the tenant from the request body — security (deferred)

**Repo:** barberpilot-api

**Description**: `PATCH /api/v2/staff/:bid/deactivate` and `/reactivate` read `tenant_id` from the request body instead of the verified panel JWT, so an admin of one tenant could toggle another tenant's staff.

**Why deferred**: Owner decision 2026-10-13 — security after the functional program. Stage 3 keeps the existing behavior and writes the period with the same tenant as the flags.

**Severity**: Medium.

**Urgency**: Eventual — security phase.

**Status**: Open — deferred by owner decision.

### 2026-10-14 — The App's daily goal divides by today's active barbers, with hardcoded fallbacks

**Repo:** BarberPilot_App

**Description**: `metas.js` uses `meta.barberos_activos` (the current count, not the month's) with `NUM_BARBEROS_FALLBACK` and `METAS_NEGOCIO_FALLBACK` / `8000000` as fallbacks (`src/services/metas.js:36`–`52`).

**Why deferred**: Stage 7 (App) moves it to the barber-period function and the API goal.

**Severity**: Medium.

**Urgency**: Near-term — stage 7.

**Status**: Open.

### 2026-10-14 — Date series that depend on the database's timezone (`generate_series(date, date, interval)`)

**Repo:** barberpilot-api

**Description**: `generate_series(date, date, interval)` silently runs as `timestamp with time zone`. Under `America/Santiago` it loses a day across Chile's clock change (proven locally). The API's working-day query uses this pattern (`/config/negocio`, `index.js:1268`). Production check by the owner: `TimeZone = Etc/UTC` and September 2026 counts 30 days, so it isn't affected today.

**Why deferred**: Fix structurally (`::timestamp` or date arithmetic) in this query and every other occurrence, in the stage that touches `/config/negocio`.

**Severity**: Low.

**Urgency**: Monitor-only until that stage.

**Status**: Open.

### 2026-10-14 — Small items found during the investigation

**Repo:** barberpilot-control, barberpilot-api

**Description**: (1) `calcKpiCuantiLocal` (`index.html`) is dead code. (2) `index.js` contains a stray byte-order mark (U+FEFF) mid-file, already on `main`; harmless.

**Why deferred**: Cosmetic; removed when those areas are next touched (stage 5 for the KPI code).

**Severity**: Low.

**Urgency**: Eventual.

**Status**: Open.

### 2026-10-14 — KPI tab crashed: NUMERIC values sent as text (`val.toFixed is not a function`)

**Repo:** barberpilot-api, barberpilot-control

**Description**: `kpi_evaluaciones.valor` is NUMERIC; node-pg returns NUMERIC (and BIGINT) as text, and `GET /kpi-evaluaciones/:periodo` passed it through. Control merges the server's ratings over the local ones, and when the browser had no clock-in data for a barber that month, the text value stayed and `val.toFixed(1)` threw. Pre-existing since 2026-05 (reproduced on pre-L2a code); surfaced after the 2026-10-13 23:00 automatic send stored October's `apertura`/`cierre`.

**Why deferred**: Not deferred — fixed the same day.

**Severity**: Medium — the KPI tab didn't render.

**Urgency**: Immediate (at the time).

**Status**: Closed 2026-10-14 — barberpilot-api `b521947` (`queryConNumeros`: NUMERIC/BIGINT as JS numbers at the driver boundary, per query, for the report and KPI reads; writes untouched) and barberpilot-control `bf84697` (`renderSeguro`: any rendering error in the KPI tab, history or KPI dashboard shows a Spanish message with "Reintentar" instead of a blank pane). Verified live: `/kpi-evaluaciones` returns numbers. **Rule from now on: every API read that returns NUMERIC/BIGINT to a client goes through `queryConNumeros`.**

### 2026-10-14 — October automatic arrival/closing stars judge Saturday against 20:00 (the shop closes at 15:00)

**Repo:** barberpilot-control

**Description**: The October rules still compute the "Cumplimiento apertura/cierre" stars in the browser (`estrellasPorHorario`, `calcEstrellaHorario`) against the fixed `HORARIO_APERTURA` 10:00 / `HORARIO_CIERRE` 20:00. On Saturdays the shop closes at 15:00, so a barber who leaves at closing time on a Saturday gets the lowest closing star (1) for that day, which lowers that barber's monthly "cierre" average. The stars are also computed only from the clock-ins this browser holds. Stage 5 keeps this calculation (October = error corrections only) but saves the result to the server right after each clock-in instead of at 23:00.

**Why deferred**: Owner decision 2026-10-14: October keeps the stars structure; from 2026-11-01 stage 9 replaces these stars with punctuality computed in the server against each day's opening and closing times from `tenant_calendar_config`.

**Severity**: Low — the closing star is worth at most 6,25 of the 50 conducta points (weight 2 of 16); Saturdays are about one working day in six, so the effect is about 1 point a month. October bonuses aren't payable (group goal not met).

**Urgency**: Near-term — ends with stage 9 (before 2026-11-01).

**Status**: Open.

### 2026-10-14 — `kpi_evaluaciones` has no tenant column

**Repo:** barberpilot-api

**Description**: `kpi_evaluaciones (periodo, bid, metrica, valor, disq, disq_motivo)` has no `tenant_id`; its primary key is `(periodo, bid, metrica)`. Two tenants with the same barber ids (e.g. `b1`) would overwrite each other's stars and disqualifications, and the KPI calculation (stage 5, `calcularKpiMes`) can only scope the read by the month's barbers, not by tenant. The table has no `CREATE TABLE` in the repo (created by hand). MAE uses `p1`–`p4`, so nothing collides today.

**Why deferred**: Out of scope for stage 5; stage 9 replaces the stars with "estándar del puesto" and is the natural point to give that data a tenant-scoped table.

**Severity**: Medium — wrong scores and bonuses for a second tenant that reuses barber ids.

**Urgency**: Eventual — no second tenant is operating.

**Status**: Open.

### 2026-10-14 — Saved stars and disqualifications are readable without login — security (deferred)

**Repo:** barberpilot-api

**Description**: `GET /kpi-evaluaciones/:periodo` has no authentication: anyone with the API address can read every barber's stars and disqualification (with its reason) for any month. Only the control panel reads it; since stage 5 the KPI tab reads the authenticated `GET /api/v2/kpi/mes` instead, so the public route has no caller left in the panel.

**Why deferred**: Owner decision 2026-10-13 — all security work goes to the final security phase.

**Fix**: require the panel login (admin) on the route, or remove it once nothing calls it.

**Severity**: Medium — staff evaluation data, including disqualification reasons.

**Urgency**: Near-term — security phase.

**Status**: Open.

### 2026-10-14 — The group-goal calculation adds up sales of every tenant

**Repo:** barberpilot-api

**Description**: `calcularMetaAnchorServicios(tenant_id)` read its monthly service totals from `registros` with no tenant filter, so another tenant's sales would raise saulfino's goal (and vice versa). Owner check 2026-10-14: `registros` holds only saulfino (2462 rows) — no effect today.

**Why deferred**: Not deferred — fixed in stage 5 (the query is scoped to the tenant).

**Severity**: Medium — a wrong group goal decides whether bonuses are payable.

**Urgency**: Near-term — closes with the stage 5 deploy.

**Status**: Closed 2026-10-14 — scoped to the tenant in Stage 5, live in barberpilot-api `fa1486b` (published goal history unchanged before/after the deploy).

> **2026-10-15 batch.** Live: **Stages 3–4** (barber activity periods and the confirmed
> backfill; barberpilot-api `827790c`, `933dbf3`), **Stage 5** (monthly KPI calculated in
> the server; barberpilot-api `fa1486b`, barberpilot-control `3e21d8d`) and the
> **Administración fix** (barberpilot-control `bd5d1fe`), and — merged 2026-10-15 on the
> owner's daytime exception — **Stage 2** (Comisión and Propina shown separately;
> barberpilot-control `7dc529c`, PR #39; verified by the owner in production) and the
> **David fix** (barberpilot-api `938ea4a`, PR #44). **Stage 3b** (commissions computed in
> the server from tenant data) was merged and deployed on 2026-10-16 on the owner's
> daytime exception — barberpilot-api `3d0ff26` (PR #45, 10:34), barberpilot-control
> `3b167fd` (PR #40, 10:44), barberpilot-expo `1db5bd2` (PR #1) and the App update
> published to the production channel (group `ee33fc73-b74b-4ac9-b29c-8fe48a08b5b7`);
> owner-confirmed in production 2026-10-20 (Comisiones editable, "Tarjeta" label, App in
> use); its entries below close when the next-day SQL is clean. Line references in this batch are to
> barberpilot-api `fa1486b`, barberpilot-control `bd5d1fe`, BarberPilot_App `2b101ff`.

### 2026-10-15 — Commission verification in production: no historical pay error

**Repo:** barberpilot-api (data)

**Description**: Read-only queries run by the owner in production on 2026-10-15 (`comisiones_verificacion.sql`, Q1–Q6), after the code review found that the App's queue screen could store the tip inside the commission (next entry):
- Q1/Q1b — sales with the tip counted twice (`bb + neg = precio + propina`, tip > 0): **0 rows**.
- Q2 — service commission vs its method's rate: débito 0.43 → 904/904 match; efectivo 0.50 → 1183/1183; transferencia 0.50 → 358/358. **No service commission differs.**
- Q3 — unknown payment methods: **0 rows**.
- Q4 — counter sales that paid a commission: **0 rows**.
- Q5 — products: with a barber, com 0.10, 16 sales, 0 mismatches; counter, com 0.50, 3 sales, 3 "mismatches" — `bb` = 0 (money correct, label only).
- Q6 — `tenant_commissions_v2` saulfino: credito 40/60, debito 43/57, efectivo 50/50, transferencia 50/50.

The owner's 2026-10-13 query (rows with `bb <> ROUND(precio*com)`) had already returned only the 3 counter sales.

**Why deferred**: Nothing to defer — no historical pay error, no retroactive correction (owner, 2026-10-15). The counter label is fixed going forward by `sale_type` (Stage 3b); history is not rewritten.

**Severity**: —

**Urgency**: —

**Status**: Closed 2026-10-15 — evidence recorded.

### 2026-10-15 — The App's queue screen saved the tip inside the commission

**Repo:** BarberPilot_App, barberpilot-api

**Description**: `PaymentSheet.js:61` computed `bb = Math.round(precio × rate) + propina` and sent it with `propina` as well; `POST /registros` stored the client's `bb` as-is. Every pay figure adds `bb + propina`, so on such a sale the tip would count twice (in "A cobrar" and in cierre de caja's "Le corresponde"). The production check (entry above, Q1) found **no** such sale.

**Why deferred**: Not deferred — fixed in Stage 3b (the server computes `bb` = commission only and ignores the client's numbers; the App sends the tip only in `propina`).

**Severity**: High — tips paid twice.

**Urgency**: Near-term — closes with the Stage 3b deploy (API, then the App update).

**Status**: Closed 2026-10-20 — fixed in Stage 3b (the server stores the commission only and ignores the client's numbers; the App sends the tip only in `propina`). Live since 2026-10-16: barberpilot-api `3d0ff26`, barberpilot-control `3b167fd`, barberpilot-expo `1db5bd2` + EAS group `ee33fc73-b74b-4ac9-b29c-8fe48a08b5b7`. 2026-10-20: owner-verified in production with the next-day check from 2026-10-16 (Q0 no rate changes, Q1 0 rows with the tip inside the commission, Q2 débito 43 % 19/19, efectivo 50 % 26/26, transferencia 50 % 7/7, 0 without a rate, 0 that differ, Q5 0 rows, Q6 0 sales without sale_type).

### 2026-10-15 — Changing the payment method of a product sale recomputed it at the service rate

**Repo:** barberpilot-api

**Description**: `PATCH /registros/:id/pago` (`index.js:3421`) recalculated every sale with `COM_PAGO[pago]` (50 %/43 %/50 %), product sales included: a product with a barber (10 %) changed to débito would pay 43 %. Production check (Q5): the 16 product sales with a barber are all at 10 % — it never happened.

**Why deferred**: Not deferred — fixed in Stage 3b (`sale_type`; the change keeps the sale's own rate).

**Severity**: Medium — overpays the barber on a product sale.

**Urgency**: Near-term — closes with the Stage 3b deploy.

**Status**: Closed 2026-10-20 — fixed in Stage 3b (`sale_type`: a product sale keeps its own rate when the payment method changes). Live since 2026-10-16: barberpilot-api `3d0ff26`, barberpilot-control `3b167fd`, barberpilot-expo `1db5bd2` + EAS group `ee33fc73-b74b-4ac9-b29c-8fe48a08b5b7`. Note: no product sale was made between 2026-10-16 and the check (Q5 had 0 rows), so production did not exercise this path; it was verified locally (69-sale before/after comparison, 37/37). One related defect was found afterwards — see the 2026-10-20 PATCH entry below.

### 2026-10-15 — Resumen A4: barber pay total counted commissions only; the signature line too

**Repo:** barberpilot-control

**Description**: In the Resumen A4 (`generarHTMLA4`), the "Pago barberos" total added commissions only, while each barber card's "A cobrar" included tips; the "Conformidad de pago" line showed "Recibe" = commission only, so a barber signed for an amount without their tips. Cierre de caja (the money actually handed over) was correct.

**Why deferred**: Not deferred — fixed in Stage 2 (Comisión and Propina shown separately everywhere, labelled total where it is money to hand over).

**Severity**: Medium — a signed document showed the wrong amount.

**Urgency**: Near-term — closes with the Stage 2 deploy (PR #39).

**Status**: Closed 2026-10-15 — Stage 2 live in barberpilot-control `7dc529c` (PR #39, merged 17:10 Santiago on the owner's explicit daytime exception); live files byte-identical to the merge commit, whose tree equals the tested head `2c7a5ed`. Verified by the owner in production the same evening: commissions and tips appear separately, with totals, everywhere.

### 2026-10-15 — Administración showed only section titles when opened from the KPI "Ajustar meta" button

**Repo:** barberpilot-control

**Description**: Stage 5 added an "Ajustar meta en Administración" button that called `showTabById('pStaff')`, which only switched panes and never ran `renderStaffPanel()`: Comisiones, Períodos de trabajo and Meta mensual stayed empty (no JavaScript error). The stage 5 browser test always opened Administración with the tab, never with the button, and did not check Comisiones.

**Why deferred**: Not deferred — fixed the same day.

**Severity**: Medium — the goal could not be adjusted from the reported path.

**Urgency**: Immediate (at the time).

**Status**: Closed 2026-10-15 — barberpilot-control `bd5d1fe` (PR #38): one function draws a tab for every way of opening it; each Administración section draws on its own with a Spanish error and "Reintentar" on any failure. The stage 5 browser suite now opens Administración from the KPI button.

### 2026-10-15 — David (b4) had `tenant_staff.role = 'owner'`: missing from Períodos de trabajo and from the May/June KPI

**Repo:** barberpilot-api (data and code)

**Description**: The barbers list and the KPI excluded anyone whose staff role was not "barber", so David (worked 2026-05-22 → 2026-06-15) was missing from Administración's "Períodos de trabajo" and from the May and June KPI (wrong divisor). Owner-run correction, production, 2026-10-15: pre-check b4 role `owner`, active false, period 2026-05-22 → 2026-06-15 (migracion); change applied; post-check b4 role `barber`, every other row unchanged (admin admin false; b1 barber true; b2 barber false; b3 barber false; b5 barber true; b6 barber false; b7 barber true).

**Why deferred**: Data corrected the same day; the structural rule (a recorded period makes a barber of that period, whatever the role; only `admin` excluded) is in barberpilot-api PR #44.

**Severity**: Medium — wrong divisor for May/June scores.

**Urgency**: Near-term — closes with PR #44.

**Status**: Closed 2026-10-15 — data corrected by the owner; the structural rule is live in barberpilot-api `938ea4a` (PR #44, merged 17:06 Santiago on the owner's explicit daytime exception; deploy SUCCESS, clean boot, public reads identical before/after). David's appearance in Períodos and the May/June KPI is visible only logged in — owner to confirm in the panel.

### 2026-10-15 — "Débito" label and a copy of the rates still hardcoded in sf-live and saulfino-web

**Repo:** sf-live, saulfino-web

**Description**: Stage 3b shows the payment method by the server's name ("Tarjeta" for the key `debito`) in control, the KPI dashboard and the App. sf-live's payment legend (`index.html:1895`) and saulfino-web's `barber.html` buttons (`:516`) still say "Débito". saulfino-web's `barber.html` also keeps its own rate table (`:563`, `COM = {efectivo:0.5, debito:0.43, transferencia:0.5}`, with a `|| 0.5` default at `:961`/`:1005`): it uses it for the on-screen "Para el barbero / Para el negocio" preview and sends `bb`/`neg` in `POST /registros`. Found in the Stage 3b verification sweep (2026-10-15). The commission stored is correct for every caller (from Stage 3b the server ignores the client's numbers and logs the difference); only that page's preview would show the old rate after a rate change in Administración.

**Why deferred**: Out of scope for Stage 3b (separate repos; order API → control → App). Fix: read `metodos_pago` from the server like the App, drop `COM` and the default, stop sending `bb`/`neg`.

**Severity**: Low — label and preview only; stored pay is correct.

**Urgency**: Eventual — with the sf-live stage (6) and saulfino-web's next change.

**Status**: Open.

### 2026-10-15 — `/events` checks the dashboard token read once at startup; Railway variable changes apply only after a deploy

**Repo:** barberpilot-api (operations)

**Description**: `/events` compares `?token=` with `DASHBOARD_READ_TOKEN`, which the API reads once at boot (`index.js:201`). Railway stages variable changes until they are deployed (Railway docs: "Using Variables"). On 2026-10-14 the owner changed the variable after the 19:02 deploy and `/events` answered 401 with the new value — consistent with the change not yet applied. No other route used by the panel depends on that token.

**Why deferred**: Informational; credential work stays in the security phase (owner decision).

**Severity**: Low.

**Urgency**: Monitor-only — remember to deploy after changing any Railway variable.

**Status**: Open — informational.

### 2026-10-15 — Stage 3b local tests: one `/resumen` difference observed once, not reproduced

**Repo:** barberpilot-api (verification)

**Description**: In the Stage 3b billing verification (local PostgreSQL 18, production-shaped data, live code `fa1486b` vs Stage 3b), the check "existing reads answer byte-identically" failed once: `/resumen?fecha=2026-10-13` answered differently between old and new code. Observed once in local tests, not reproduced in 13 further runs; the differing responses were not captured. Owner reports cash always reconciles.

**Why deferred**: Owner decision, 2026-10-15: no further investigation.

**Severity**: Low — local test only; every stored commission matched old vs new in all runs.

**Urgency**: Monitor-only.

**Status**: Open — informational.

### 2026-10-15 — Client names from the public check-in rendered unescaped in the staff panel

**Repo:** barberpilot-api, barberpilot-control

**Description**: `POST /queue/checkin` (public, no login; barberpilot-api `938ea4a` `index.js:3844`) stores `client_name` with no length or content check, and barberpilot-control (`7dc529c`) writes it into `innerHTML` without `escHtml` in Sala de Espera (`index.html:6167`, `:6207`) and Sillas (`:6391`). Anyone using the public check-in could make script run in a logged-in staff session (which holds the panel login in `sessionStorage`). Found by reading code in the OPS investigation; not tested against production.

**Why deferred**: Found 2026-10-15 during the read-only OPS investigation; the fix is proposed to the owner (escape every queue field in the panel, plus server-side length/character validation of `client_name`) and needs a decision on scheduling.

**Severity**: High — script execution in an authenticated staff session from a public form.

**Urgency**: Near-term — reachable today by anyone who can open the public check-in.

**Status**: Closed 2026-10-20 — fix live 2026-10-20 — barberpilot-api `a07855c` (PR #48, merged 12:56 Santiago) and barberpilot-control `4e76e46` (PR #41, merged 13:00), on the owner's daytime exception; no data change. The panel, the agenda, the KPI dashboard and the API's two pages show every value as plain text (shared `texto-seguro.js`); the server refuses only `< > { } `` ` and control characters on every write (owner decision after the production check of existing names: `con_marcado` 0 in every table; real names with parentheses and digits must never be rejected). Name limit from `tenant_config` `texto_limites`.`nombre_max` (default 60). Tests 64/64 (security), with the live panel running the planted payloads 53 times and the fixed panel 0. Production checks 2026-10-20: a check-in with `<img …>` or a control character answers 400 in Spanish; public reads unchanged; Pages deploy OK and the four live files identical to main. Owner checked in production the same day: a public check-in with "Niño (test)" is accepted and shown correctly; Sala de Espera, Sillas and Clientes show names as text. Follow-ups: the escaper in three deploy units, and sf-live / saulfino-web not swept (both open, Low).

### 2026-10-20 — Stage 3b verified in production

**Repo:** barberpilot-api, barberpilot-control, barberpilot-expo

**Description**: Owner-run read-only check on production (sales from 2026-10-16, after the 3b deploy): Q0 0 rows (no rate changes); Q1 0 rows (no tip inside a commission); Q2 débito 43 % 19/19, efectivo 50 % 26/26, transferencia 50 % 7/7, 0 without a rate, 0 that differ; Q5 0 rows (no product sale since the 16th); Q6 0 sales without `sale_type`. Owner also confirmed: Comisiones loads and is editable, Caja shows "Tarjeta", the App is installed and in use on Benjamín's phone, the owner's and Angie's.

**Why deferred**: Nothing to defer — evidence recorded.

**Severity**: —

**Urgency**: —

**Status**: Closed 2026-10-20.

### 2026-10-20 — `PATCH /registros/:id/pago` answers 500 after saving (variables removed in Stage 3b)

**Repo:** barberpilot-api

**Description**: Stage 3b replaced the route's `newCom/newBB/newNeg` with the server computation but left them in the final `res.json(...)` (`index.js:3456`). Since 2026-10-16 10:34 the route saves the change and writes its audit rows correctly and then answers HTTP 500 "newCom is not defined". Effect: the panel's ✏ "Editar registro" shows "Error: newCom is not defined" and does not close or refresh, although the edit was saved (stored values verified: Tarjeta 43 % of 22.000 = 9.460). Sale amounts and commissions are not affected. Found on 2026-10-20 while checking the removed names; the 3b suite checked this route through the database, not through its HTTP response.

**Why deferred**: Not deferred — fixed the same day (the response now returns `cv.com/bb/neg`; test 21/21, including the HTTP status and body of every other 3b route).

**Lesson (owner, 2026-10-20)**: from now on, tests for every stage check the HTTP RESPONSE (status and body) of every route touched, not only the database state.

**Severity**: Medium — confusing error on a billing screen; data is correct.

**Urgency**: Near-term.

**Status**: Closed 2026-10-20 — fixed in barberpilot-api `477adfd` (PR #47, merged 12:14 Santiago on the owner's daytime exception; merge tree identical to the reviewed commit `786d0a0`). Deploy SUCCESS, boot log clean (Migration 046 ✓, reaches `Puerto`), public reads identical before/after. Local test: live code 500 → fix 200 with the stored `com/bb/neg`. Production confirmation by the owner (console, 2026-10-20): re-sending a Tarjeta sale of 16.000 with its current payment method answered 200 `{"ok":true,"pago":"debito","precio":16000,"snom":"Corte + Perfilado de barba","com":0.43,"bb":6880,"neg":9120,"sale_type":"servicio"}`, equal to the stored values (bb 6880, neg 9120, com 0.43).

### 2026-10-20 — WhatsApp: no paid automated sends remain

**Repo:** barberpilot-api

**Description**: Owner decision 2026-10-15: no paid WhatsApp messages; everything manual from the panel's WhatsApp Web button. The post-service poller (`startPostSvcPoller`, a Meta Cloud API send every 5 minutes for sales 2–48 h old, which also logged client phones and messages when Meta credentials were missing) was removed — barberpilot-api `447f170` (PR #46, merged 2026-10-20 10:41 Santiago; boot log clean, no poller started, public reads identical). The owner-run check on 2026-10-20 showed the three flags (`whatsapp_automation_enabled`, `whatsapp_confirmacion_reserva_enabled`, `whatsapp_notificar_barbero_enabled`) were ALREADY false before the change and remain false, so the booking confirmation to the client and the barber notice template were not sending either. What remains: admin-initiated sends and replies (`/admin/whatsapp/conversaciones/…`), the inbound webhook, and the panel's WhatsApp tab — removal of the tab and the manual-send paths is part of the OPS stage. This closes the poller half of the 2026-07-24 "two parallel WhatsApp-sending code paths" entry.

**Why deferred**: Nothing to defer for the automated sends. The webhook / tab / manual paths are scheduled (OPS stage).

**Severity**: —

**Urgency**: —

**Status**: Closed 2026-10-20 (automated sends). Open: panel tab and manual API send paths — OPS stage.
**Update 2026-10-20 (evening)**: the panel side is done and owner-verified in production (control PR #42): every WhatsApp button opens WhatsApp Web on the client's chat (`wa.me` link built in the browser) and the WhatsApp tab is gone. Still open for the OPS stage: the manual-send API paths (`/admin/whatsapp/conversaciones/…`) and the decision on the inbound webhook.

### 2026-10-20 — October attendance stars are computed from each browser's localStorage, not from the server

**Repo:** barberpilot-control (and barberpilot-api, which stores the result)

**Description**: The two October attendance stars (apertura / cierre) are computed in the panel by `calcEstrellaHorario` / `_estrellasAutoLocales` from `sfsf_horarios_*` in the browser's localStorage and pushed to `kpi_evaluaciones` by `kpiSincronizarEstrellasAuto`. Only the clock-ins made in that browser count, so the stars for a month depend on which computer had the Horarios tab open; a barber whose marks were entered on another device is under-counted. The same bug class as every localStorage-derived number: the browser, not the server, is the source of truth.

**Why deferred**: October scoring is frozen by the owner (October keeps its current rules). The November model (Stage 9) does not use these stars: punctuality is computed in the server from the `horarios` table, and the panel no longer syncs stars for months scored with the November model.

**Severity**: Medium — October bonuses could be mis-scored for the two attendance stars.

**Urgency**: Near-term — October is closed at the end of the month; check the October attendance stars against the `horarios` table before paying October bonuses.

**What would close it**: score October attendance from the server's `horarios` before the October bonus run (or accept the stars after an owner check), then delete `_estrellasAutoLocales` / `kpiSincronizarEstrellasAuto` when no month uses the old model.

**Status**: Open.

### 2026-10-20 — Legacy horarios routes are unrestricted

**Repo:** barberpilot-api

**Description**: The older `horarios` routes (the ones used before the Stage 8b `/api/v2/asistencia/*` routes) answer without a panel role check: any caller who can reach them can read or write clock-in times. Stage 8b (deployed 2026-10-20, barberpilot-api #49) puts audit rows behind them and makes the new clock-in routes role-checked, but does not close the old routes. The `horarios` table itself is also not created by anything in the repository (it exists only in production); local test databases have to create it by hand.

**Why deferred**: out of scope for 8b (clock-in with adjustable time and reason); the roles stage and the security phase close the unauthenticated panel-used routes.

**Severity**: Medium — attendance marks feed the November punctuality points and the A4 reminder, so a forged mark changes scores.

**Urgency**: Near-term — November punctuality scoring starts 2026-11-02.

**What would close it**: put the legacy routes behind `requirePanelRole` (or retire them once the panel only uses the `/api/v2/asistencia/*` routes), and add the `horarios` table to the schema migrations.

**Status**: Open.


### 2026-10-20 — The API's own `/checkin` page has a syntax error: its script never runs

**Repo:** barberpilot-api

**Description**: `checkin.html` (served at `/checkin`) contains a corrupted character in `btn.innerHTML = 'Confirmar llegada …'` (an arrow stored as `\uFFFD?` plus a stray quote), so the page's whole `<script>` fails to parse ("Invalid or unexpected token") and the page does nothing. The check-in in use is saulfino-web's own `checkin.html`, which calls `POST /queue/checkin` directly and is unaffected. Found while testing the 2026-10-15 security fix; it fails identically in the code live today.

**Why deferred**: Out of scope for the security fix; needs the owner to decide whether the API's `/checkin` is still used (retire it, or repair the character).

**Severity**: Low if nobody uses that URL; Medium if any QR still points to it.

**Urgency**: Near-term — check which QR codes and links point to it.

**Status**: Open.


### 2026-10-20 — The text escaper lives in three deploy units

**Repo:** barberpilot-control, barberpilot-api

**Description**: After the security fix, barberpilot-control has ONE escaper for all its pages (`texto-seguro.js`), but the two pages barberpilot-api serves on its own (`checkin.html`, `queue-dashboard.html`) each keep their own copy (they cannot load the control file). Same logic in three places.

**Why deferred**: Different repos and deploy units; serving one shared script from the API (e.g. `/texto-seguro.js`) would be a new route, out of scope for the fix.

**Severity**: Low.

**Urgency**: Eventual — with the security phase or the next change to those pages.

**Status**: Open.

### 2026-10-20 — sf-live and saulfino-web not yet swept for unescaped names

**Repo:** sf-live, saulfino-web

**Description**: The 2026-10-20 security fix escapes every value in barberpilot-control and in the API's two pages, and the API now refuses markup characters in names and free text on every write. sf-live (socios dashboard) and saulfino-web also render names (barbers, services; sf-live possibly client names) and were not swept. New malicious names can no longer be stored, and the production check found `con_marcado` 0 in every table, so the residual risk is low; the sweep is still owed.

**Why deferred**: Separate repos; the owner scoped the fix to the panel and the API pages.

**Severity**: Low — no stored row contains markup today.

**Urgency**: Near-term — with the next change to each repo.

**Status**: Open.

### 2026-10-20 — Server text rule: only markup and control characters are refused (decision)

**Repo:** barberpilot-api

**Description**: The first version of the server rule accepted only letters, spaces, apostrophe, hyphen and period in names. The owner's read-only check of existing data (2026-10-20) found real operational names with parentheses and descriptions ("Gaspar (Niño…", "Renato (Niño…") and test rows with digits ("Usuario 1", "E2E Cierre"): 30 in `queue`, 26 in `registros`, `con_marcado` 0 everywhere. Decision: the panel's plain-text rendering is the primary defence and the server rule is a second layer that refuses only `< > { } \`` and control characters (names also refuse line breaks), with the name length from config. Consequence to remember: a value made of quotes, parentheses or semicolons is stored as typed; every page must keep escaping it.

**Why deferred**: Nothing to defer — recorded as a decision.

**Severity**: —

**Urgency**: —

**Status**: Closed 2026-10-20.


> **2026-10-13 evening update.** **Stage 2a** live — barberpilot-control `cdfd303`
> (PR #33, merged ≈17:46 Santiago on the owner's explicit deploy-window exception);
> owner acceptance in production passed (created s14 "Corte + Matizado de canas"
> 22000 / 60 min from Administración and charged it from cobro). **Stage L** (one
> range request per sf-live report, no silently dropped days) live —
> barberpilot-api `28ac97c` (PR #38) and sf-live `f2d2728` (PR #6), both merged
> ≈18:25–18:31 Santiago on explicit owner exceptions; owner verified sf-live's
> monthly view. Order from here: Step A-3 → Stage R → Stage C → Stage 2b → Stage 3.
> Line references in entries added by this update are to barberpilot-api `28ac97c`,
> barberpilot-control `cdfd303`, BarberPilot_App `2b101ff`, sf-live `f2d2728`.

### 2026-10-13 — Report read routes return sales with client names and phone numbers to anyone, with no authentication — HIGH (deferred)

**Repo:** barberpilot-api (callers in barberpilot-control, BarberPilot_App)

**Description**: These `GET` routes have no auth middleware and no check in the handler:
- `GET /registros/dia` (`index.js:1808`) — every confirmed sale of a day, **including `cliente_nombre` and `cliente_telefono`**, plus prices and commissions.
- `GET /gastos/dia` (`:1883`) — every expense of a day.
- `GET /resumen` (`:1986`) — the day's totals, per-barber earnings, last sales and expenses.
- By code reading only (not called in production): `GET /barbero/:bid/hoy` (`:2197`), `GET /barbero/:bid/mes/:periodo` (`:2235`), `GET /stats/mes/:periodo` (`:2318`).

Verified in production 2026-10-13 (status codes only, no body kept): `/resumen`, `/registros/dia` and `/gastos/dia` answer **200 with no credentials**; the authenticated range routes `/registros/rango` and `/resumen/rango` answer 401. CORS doesn't protect these: requests with no `Origin` are accepted. `GET /registros/dia` was noted as a "related read" in the 2026-10-12 write-routes entry; this entry tracks the read side.

**Callers that would break if auth were simply added**: barberpilot-control `index.html` (`:1646`, `:1700`, `:1809`, `:1853`, `:1875`, `:5126`, `:6170`, `:6582`) and `dashboard_kpis_barberia.html:547`; BarberPilot_App `AdminScreen.js:138`, `ConfigScreen.js:57`, `HoyScreen.js:79/119/193`, `SocioScreen.js:74`, `TendenciasScreen.js:34`. Several send no auth header at all. sf-live no longer uses them (Stage L).

**Why deferred**: Deferred by owner decision on 2026-10-12 — scheduled after the functional program. Found during the 2026-10-13 sf-docs update.

**Fix**: require auth on every report read (panel JWT, barber session or socio/dashboard token, scoped to tenant and — for barbers — to their own `bid`); move callers to the authenticated range routes (`/registros/rango`, `/gastos/rango`, `/resumen/rango`), whose accepted token types must be extended to the panel JWT for control; then remove or lock the per-day routes. Classify every `GET` route, which has never been audited systematically.

**Severity**: High — client personal data (names and phone numbers) and the full financial ledger are readable by anyone who knows the API URL.

**Urgency**: Near-term — first security stage after the functional program.

**Status**: Open — deferred by owner decision. 2026-10-14: scheduled as the **first personal-data stage of the security phase**, right after Stage L2 removes its callers (L2a already moved every barberpilot-control caller to the authenticated range routes; the App's callers remain until L2b). Chile's new personal data protection law increases the impact of this exposure (the owner will confirm its effective date).

### 2026-10-13 — Per-day report loops that silently drop failed days remain in barberpilot-control and BarberPilot_App

**Repo:** barberpilot-control, BarberPilot_App

**Description**: Stage L fixed this bug class in sf-live only. The same pattern — one `GET /registros/dia` (and sometimes `/gastos/dia`) per day of the range, all at once, with any failed day turned into an empty result and skipped without a warning — is still in:
- barberpilot-control `index.html:1809` (date-range report, up to 31 days), `:5126` (monthly view); `dashboard_kpis_barberia.html:547` — worse there: a failed expenses day is replaced with `{ok:true, gastos:[]}`, i.e. counted as $0 of expenses.
- BarberPilot_App `SocioScreen.js:74` (partner view, up to 121 days), `TendenciasScreen.js:34`, `AdminScreen.js:138` (month to date).

A month is ≈30 requests (≈60 with expenses) fired together, enough to reach the rate limiter; a rejected or timed-out day silently understates every total, ranking and chart. Not observed from these surfaces so far (the 429 evidence in the rate-limiter entry matches sf-live's patterns), but the mechanism is identical to the one that understated sf-live's monthly totals.

**Why deferred**: Out of scope for Stage L (sf-live only, by owner decision); found during the 2026-10-13 sf-docs update.

**Fix**: same as Stage L — one authenticated range request per report through the existing range routes (which need to accept the panel JWT and the App's session; see the report-read-routes entry), one shared retry helper per client, and a visible warning naming any date that couldn't be loaded. Never substitute an empty result for a failed one.

**Severity**: Medium — partner and admin reports can silently understate totals.

**Urgency**: Near-term — candidate for Stage R (owner to decide), which already touches the limiter and client retry behavior.

**Status**: Open — **barberpilot-control part resolved 2026-10-14** by Stage L2a (barberpilot-control `1a4ee35`, barberpilot-api `3d21ed4`): KPI month, history, today's sales, rotation and the KPI dashboard read one authenticated range per period, show a Spanish warning naming the missing dates, and never present partial totals (a failed expenses read never counts as $0). Negative control during testing: under injected faults the old per-day KPI code silently showed **$371.000 less** than the real month, with no warning. Remaining: BarberPilot_App (`SocioScreen`, `TendenciasScreen`, `AdminScreen`) — Stage L2b.

### 2026-10-13 — sf-live's monthly report showed understated totals on 2026-10-09 and 2026-10-13 (silently dropped days)

**Repo:** sf-live, barberpilot-api

**Description**: sf-live's multi-day views fetched `/resumen` and `/registros/dia` once per day, all at once; days rejected by the rate limiter (429 bursts on 2026-10-09 18:38 and 2026-10-13 11:10–11:15, see the rate-limiter entry) were skipped without any warning, so the totals shown were lower than the real ones. The database was always correct — only the report was wrong.

**Why deferred**: Not deferred — fixed by Stage L the same day it was diagnosed.

**Severity**: Medium — partners saw understated figures with no indication.

**Urgency**: Immediate (at the time).

**Status**: Closed 2026-10-13 — Stage L: new `GET /resumen/rango` (barberpilot-api `28ac97c`, aggregation shared with `/resumen`, whose per-day output stayed byte-identical in production) and sf-live `f2d2728` (one range request per report, shared retry helper, red warning naming any date that couldn't be loaded, figures blanked instead of understated). Owner verified the monthly view live.

### 2026-10-13 — sf-live's "últimos registros" on a multi-day view showed the first day's sales, not the latest

**Repo:** sf-live

**Description**: The consolidated feed concatenated each day's last 8 sales in date order and kept the first 8 (`consolidado.ultimosRegs.concat(d.ultimosRegs).slice(0,8)`, sf-live `12ff272` `index.html:1760`), so a monthly view showed sales from the first day(s) of the period instead of the most recent ones. Pre-existing; found during the Stage L investigation.

**Why deferred**: Not deferred — fixed in Stage L.

**Severity**: Low — display only.

**Urgency**: Near-term (at the time).

**Status**: Closed 2026-10-13 — Stage L: `/resumen/rango` returns the period's latest 8 sales (ordered by date and time, each with its date) and sf-live shows the date on multi-day views (`f2d2728`). Owner verified live.

### 2026-10-13 — sf-live's Reporte Financiero computes its totals in the browser from raw rows

**Repo:** sf-live, barberpilot-api

**Description**: `cargarReporteFinanciero()` (`index.html:1121`) downloads the month's raw sales and expenses and sums facturación, negocio, pago a barberos and gastos itself (`rfAgruparPorDia`, `:1179`; `rfRenderTodo`, `:1207`). The API computes the same totals in `resumirPeriodo` for `/resumen` and `/resumen/rango`. Two independent implementations of the same financial figures can drift apart (e.g. a future change to tip handling or to which `estado` counts).

2026-10-14: barberpilot-control's KPI dashboard (`dashboard_kpis_barberia.html`) does the same — it receives complete rows since Stage L2a but adds up its own totals and barber pay (commission plus tip) in the browser (`:637`, `:651`, `:660`, `:845`, `:867`).

**Why deferred**: Stage L kept scope to the silently dropped days; moving the report's math is a separate change.

**Fix**: the API returns the per-day and period totals (one aggregation, shared with `/resumen/rango`); the page only renders them.

**Severity**: Medium — two sources of truth for partner-facing financial figures.

**Urgency**: Eventual — a later reporting stage.

**Status**: Open.

### 2026-10-13 — The API doesn't expose its `RateLimit-*` headers to browsers

**Repo:** barberpilot-api

**Description**: The limiters send standard `RateLimit-*` headers (`standardHeaders: true`, `index.js:23` and others), but the CORS config (`:157`) has no `exposedHeaders`, so cross-origin pages (sf-live, control) can't read them. sf-live's retry helper therefore falls back to fixed 1 / 2 / 4 s waits instead of waiting exactly until the limit resets.

**Why deferred**: Belongs to Stage R (rate limiter); harmless meanwhile — the fallback works.

**Severity**: Low.

**Urgency**: Near-term — Stage R.

**Status**: Open.

### 2026-10-13 — Sale times are invented when missing: `'00:00'` in the API, `'10:00'` in the historical-entry tool

**Repo:** barberpilot-api, barberpilot-control

**Description**: Every `registros` insert in the API stores `r.hora || '00:00'` (`index.js:1704` `POST /registros`, `:1772` `/registros/bulk`, `:3443` `/registros/barbero`), so a sale sent without a time would be recorded at midnight. Only the queue close sets the time server-side (Santiago, `:4259`). Control's "Ingresar histórico" tool defaults a missing time to `'10:00'` (`index.html:4531`).

Production check by the owner (2026-10-13): **no row has a NULL or `00:00` time** in any `sid` group or month — the API fallback has never fired. The `'10:00'` default did: **61 service sales and 3 custom sales in 2026-05 are at exactly 10:00**, most likely historical imports, which creates an artificial 10:00 spike in May's by-hour charts.

**Why deferred**: Latent (no affected rows from the API path); owner decision 2026-10-13: no dedicated stage.

**Fix (Stage 3, which touches every `registros` write path)**: one shared helper for all insert paths: keep a valid client time; if missing and the sale is for today, use the server's `America/Santiago` time; if missing for a past date, store NULL ("unknown") — never invent a time.

**Severity**: Low.

**Urgency**: Eventual — Stage 3.

**Status**: Open.

### 2026-10-13 — By-hour charts silently leave out sales without a time or outside a hardcoded 10–20 window

**Repo:** sf-live, BarberPilot_App

**Description**: sf-live's heatmaps (`procesarRegistros`, `index.html:569`; hour list `:570` and `:818`) parse `hora` and count only hours 10–20; a sale with no time, at `00:00`, or outside that window is dropped from the by-hour chart with no indication (day, barber and total figures still include it). BarberPilot_App does the same with a 10–19 window (`AdminScreen.js` `porHora`; `TendenciasScreen.js:10` `HORAS`). Production (owner, 2026-10-13): outside 10–20 — 7 service sales in 2026-05, 1 in 2026-06, 1 custom sale in 2026-07. The window is a business constant in code; the shop's real hours belong in configuration.

**Why deferred**: Owner decision 2026-10-13: fold into the business-hours configuration stage.

**Fix**: hour window read from the shop hours in `tenant_config`; a visible "N ventas sin hora no incluidas" (and outside-hours count) on the chart; read-side helper `hora_efectiva` / `hora_origen` (registered / derived from `creado_en` in Santiago when the dates match / unknown) shared by every report — never rewriting `registros`.

**Severity**: Low.

**Urgency**: Eventual — business-hours configuration stage.

**Status**: Open.

### 2026-10-13 — Barber rotation and the WhatsApp follow-up depend on each sale's `hora`

**Repo:** barberpilot-api, barberpilot-control

**Description**: The next-barber suggestion ranks free barbers by their last sale time today — control `index.html:6185` and `:6607`, API `index.js:3732` (`MAX(hora)`). A sale with a missing or invented early time makes that barber look idle the longest, so they would be offered the next client unfairly. The post-service WhatsApp poller (`index.js:7856`) builds the send time from `fecha + hora`: a NULL time means the follow-up is never sent; `00:00` would send it within minutes instead of 2 hours later.

**Why deferred**: Latent — production has no NULL or `00:00` times (owner, 2026-10-13); closes with the Stage 3 write-side fix above.

**Severity**: Low.

**Urgency**: Eventual — Stage 3.

**Status**: Open.

### 2026-10-13 — API rate limiter keys clients by an unstable address; sf-live report bursts hit it and silently drop days

**Repo:** barberpilot-api, sf-live (also relevant to barberpilot-control, BarberPilot_App, saulfino-web)

**Owner report (2026-10-13)**: no "Too many requests" errors, and no failures that succeeded on retry, have ever been observed in shop operation (check-in, Sala de Espera close, login, App).

**Description**: The global limiter allows 100 requests/min per key, the key being `req.ip` with `app.set('trust proxy', 1)` (`index.js:20`, `:146`, `:148`); the write limiter (30/min on `POST /registros`) and push limiter (10/min on `/push`) key the same way. The limiter is registered before `app.options` and the API sets no CORS preflight `max-age`, so every `OPTIONS` preflight counts.

**Read-only production evidence (2026-10-13)**:
- *Keying*: Railway's HTTP logs show **one instance** (a single `deploymentInstanceId`) serving all traffic, yet limiter headers for one client IP advanced **two independent counters** (94→88 interleaved with 98→94). So `req.ip` is not stable per client — most likely a proxy address — which would make the budget shared beyond one client. Stage R's diagnostic will confirm the cause.
- *429 history* (Railway HTTP logs, retention ≈ 7 days: oldest available record 2026-10-06 ≈23:52 UTC): **67 responses with status 429**, all from a desktop browser, in two bursts — **2026-10-09 18:38** (10, from the shop's address: `/resumen`, `/registros/dia`) and **2026-10-13 11:10–11:15** (57, from another address: 50 × `GET /registros/dia`, plus preflights for `/horarios/:fecha`, `/queue/control`). These are **sf-live's** request patterns. **No 429 on any shop operational route** (cobro, Sala de Espera, check-in, login, App) — consistent with the owner's report.
- *Measured load* (current deployment, 2026-10-13 16:39–18:31 UTC, 1,517 requests, 19 client addresses): total per minute median 12, p95 25, max 58; the busiest single address (91% of traffic, the shop) p95 21, max 58 per minute; 26% of requests are `OPTIONS` preflights.

**Code-based estimates (not measurements)**: a shop peak of ≈70–100 requests/min assumed every screen open on 6 devices (control panel ≈24–30 incl. preflights, 4 phones ≈36–52, check-in tablet and queue TV ≈10–18). The measured afternoon peak above is well below that.

**The confirmed harm — sf-live**: the monthly consolidation (`sf-live index.html:1728`, `/resumen` per day) and the heatmaps (`:483`, `/registros/dia` per day) fire one request per day of the range all at once (plus a preflight each). A month is ≈60+ requests per view, so a report alone can exceed 100/min. A rejected day is **silently skipped** (`if(!json.ok || !json.data) return;`), so the report shows **understated totals with no warning**. That happened at least on the two dates above.

**Why deferred**: Found during the Stage 2a pre-merge check; Stage 2a doesn't worsen it.

**Fix (Stage R — before Stage C, which adds per-device polling, and Stage 2b, which adds public booking/check-in traffic; scope re-evaluated with this evidence)**: confirm the real proxy chain with a short-lived diagnostic log; key limits by authenticated identity (tenant + panel user / barber) and by correctly resolved client IP only for unauthenticated routes; skip `OPTIONS` and set a CORS preflight `max-age`; all limit values as `tenant_config` data (missing-key behavior to be decided by the owner); Spanish 429 messages with safe retry on client surfaces; sf-live must never silently drop a day (show the gap or retry), and should fetch a range in one request (an existing `/registros/rango` route is a candidate) instead of one per day; document that a second replica would need a shared store.

**Severity**: Medium — no operational shop failure observed; partner reports can silently understate totals.

**Urgency**: Near-term — Stage R lands before Stage C and Stage 2b.

**Status**: Open — Stage R scheduled after Step A-3. 2026-10-13 evening: the sf-live harm is fixed by Stage L (barberpilot-api `28ac97c`, sf-live `f2d2728`; see the closed "understated totals" entry); the limiter keying, preflight counting and limit values remain for Stage R. The same per-day burst pattern still exists in barberpilot-control and BarberPilot_App — tracked in its own entry.

### 2026-10-13 — New services can't be booked from agenda-admin: the appointments API has its own hardcoded catalog

**Repo:** barberpilot-api, barberpilot-control, saulfino-web

**Description**: `POST /appointments` and `GET /appointments/slots` take duration and display name from `APT_DURATIONS` / `APT_NAMES` (`index.js:5017`, `:5032`), keyed by the old website ids (`'corte'`, `'mat_cabello'`…), not the service catalog. agenda-admin's service dropdown is a matching hardcoded `<option>` list. Sending a catalog id (e.g. `s14`) would book a 30-minute default and name the service "s14" — including in the client's WhatsApp confirmation. So a service created in Administración can't be booked from agenda-admin.

**Why deferred**: Needs an API change shared with saulfino-web's public booking (same code path, same ids). Owner decision 2026-10-13 (Option B): do both in Stage 2b.

**Severity**: Medium — new services can be charged (cobro) but not booked as appointments.

**Urgency**: Near-term — Stage 2b.

**Status**: Open.

### 2026-10-13 — Hardcoded business constants still in code (owner rule: none allowed)

**Repo:** barberpilot-api, barberpilot-control

**Description**: Owner rule (2026-10-13): no business values hardcoded; limits are tenant data. Remaining instances, each assigned to the stage that removes it:
- Queue-close fallback price **12000** when no override and no catalog match — `precioOverride || _catalogPrecio || 12000` (api `index.js:4205`) → Sala de Espera stage.
- Sala de Espera price box default **12000** (control `index.html:6379`) and the `SALA_PRECIOS` map (`:5594`, refreshed from the API at load) → Sala de Espera stage.
- `validateRegistro` price cap **500000** on the sales path (api `index.js:388`) → Stage 3.
- `PRODUCTO_MAGNITUD_THRESHOLD = 0.25` for product price edits (api `index.js:7206`) → products stage.
- Hardcoded `PRODUCTOS` fallback list (control `index.html:1311`) → products stage.

**Why deferred**: Each belongs to a later stage of the program; none affects Stage 2a.

**Severity**: Medium — values that silently go stale when the business changes.

**Urgency**: Eventual — per stage.

**Status**: Open.

### 2026-10-13 — Catalog limits in `tenant_config` can't be edited from Administración

**Repo:** barberpilot-api, barberpilot-control

**Description**: Stage 1 moved catalog limits to `tenant_config` data: `servicio_precio_max_variacion_pct` (seeded 40), `servicio_duracion_default_min` (seeded 30), `servicio_precio_max` (not seeded = no cap). Today they can only be changed with SQL. Owner rule: everything admin-changeable is managed from Administración.

**Why deferred**: The configuration program adds an Administración screen for tenant settings in a later stage.

**Severity**: Low — values are correct today and documented.

**Urgency**: Eventual.

**Status**: Open.

### 2026-10-13 — Control's catalog loader treats a 429 as "server unavailable" and switches to the read-only copy

**Repo:** barberpilot-control

**Description**: Stage 2a's `catalogoCargar()` uses the saved read-only catalog for any failed load (network error or non-200 other than 401/403), including a rate-limit 429. Behavior is safe — the last known services stay chargeable, catalog changes are blocked, a dated warning is shown — but at peak (see the rate-limiter entry) staff may see "Datos sin conexión" while the server is up.

**Why deferred**: By design for Stage 2a; Stage R removes the main trigger.

**Severity**: Low.

**Urgency**: Monitor-only — revisit after Stage R.

**Status**: Open.

### 2026-10-13 — CI boot smoke test runs PostgreSQL 14; production runs 18.6

**Repo:** barberpilot-api

**Description**: `.github/workflows/boot-smoketest.yml:30` uses `image: postgres:14`; production reports `server_version 18.6` (owner query, 2026-10-13). Stage 1 was tested locally on both 14.22 and 18.4 with identical results, but CI itself only proves PG 14.

**Why deferred**: Out of scope for Stage 1; a one-line change with its own review.

**Severity**: Medium — a PG 18-only failure would pass CI.

**Urgency**: Near-term.

**Status**: Open.

### 2026-10-13 — On a brand-new database, the barber cache loads before `barberos.tenant_id` exists

**Repo:** barberpilot-api

**Description**: At boot, `_loadBarberCache()` runs (`index.js:8383`) before Migration 015 adds `barberos.tenant_id` (`:8457`). On a fresh database every barber lands under an undefined tenant (`[Barberos] Loaded: undefined:4`) until the next reload, so `bid` validation rejects sales. Production is unaffected (the column already exists). Found while building the Stage 1 test fixture.

**Why deferred**: No production impact; matters for disaster recovery and staging rebuilds.

**Severity**: Low.

**Urgency**: Eventual — before the next fresh-database restore drill.

**Status**: Open.

### 2026-10-13 — Staging seed declares `registros.com` as INTEGER

**Repo:** barberpilot-api

**Description**: `scripts/seed-staging.js:131` creates `com INTEGER`; production stores decimals (0.43, 0.50, 0.10). A staging database built from the seed would truncate every commission rate to 0.

**Why deferred**: Staging only; found while building the Stage 1 test fixture.

**Severity**: Low.

**Urgency**: Eventual — before the next staging rebuild.

**Status**: Open.

### 2026-10-13 — At ~900 px width the control panel's side panel covers the tabs

**Repo:** barberpilot-control

**Description**: At a ~900 px viewport the side panel (`.pl`, `index.html:505`) overlaps the tab bar and intercepts clicks on tabs such as Administración. Found during Stage 0 testing; desktop widths (1366 px) are unaffected.

**Why deferred**: Pre-existing layout issue, unrelated to the configuration program.

**Severity**: Low.

**Urgency**: Eventual.

**Status**: Open.

### 2026-10-12 — Administración's service catalog is browser-local only — creating a service fails and the new service never reaches the backend

**Repo:** barberpilot-control, barberpilot-api

**Description**: In barberpilot-control's Administración tab, every service action except price editing only changes the browser's own `localStorage` (`bp_staff_v1`) — none of them calls the API:
- **Add** (`staffAddSvc()`, `index.html:7411`): pushes `{id:'s'+<7 digits of Date.now()>, nombre:'Nuevo servicio', precio:0}` into the local `SS` array.
- **Rename** (`staffSaveSvcName`, `:7340`), **delete** (`staffDelSvc`, `:7406`), **reorder** (`staffMoveSvc`, `:7331`): local only.

Confirmed symptom (owner report, 2026-10-12): creating "Corte de cabello + Matizado de canas" at 22000 fails with *"Error al guardar precio, precio_actual_esperado requerido"*. Mechanism: typing the price calls `staffSaveSvcPrecio` (`:7345`), which sends `PATCH /api/v2/config/servicios/<fake id>/precio` with `precio_actual_esperado: 0` (the local placeholder price). The backend rejects 0 at `index.js:6487` (`precio_actual_esperado <= 0`); even if it didn't, the fake id doesn't exist in `servicios` (`servicio_no_encontrado`, `:6503`). Editing the price of an *existing* service works because s01–s10 exist server-side with an open price row.

The cobro list (`buildServices()`, `:2100`) renders the local `SS` array, so a locally-added service appears (at $0) only on the one browser that added it, and could never be charged anyway (`POST /registros` resolves by name via `servicio_alias` → `alias_no_mapeado`).

**Why deferred**: Found 2026-10-12; the structural fix is the program's Stage 1 (backend catalog API) + Stage 2 (catalog on every surface). Stage 0 freezes the local-only actions in the meantime so nobody hits the trap again.

**Severity**: High — the owner cannot create a new service (an immediate business need: "Corte + Matizado de cabello y barba", 22000), and the UI gives a misleading error instead of saying the feature doesn't exist.

**Urgency**: Immediate — Stage 0 (containment) next, Stage 1/2 to deliver the capability.

**Progress**: in progress. Owner's read-only queries (2026-10-12) confirmed no orphan rows were created server-side. 2026-10-13: Stage 0 froze local service edits (live, `573ef84`; the owner cleared 3 local junk rows with "Restaurar valores por defecto"); Stage 1 provides the API (live, barberpilot-api PR #37, merge `9dbac29`); Stage 2a (PR #33, approved) moves Administración and cobro onto it. Close after Stage 2a is live and the owner's production acceptance passes (create "Corte + Matizado de cabello y barba" / 22000 / 60 from "+ Agregar" and charge it from cobro).

**Status**: Closed 2026-10-13 — Stage 2a live (barberpilot-control `cdfd303`): "+ Agregar" creates the service through `POST /api/v2/config/servicios` after a "¿Crear <nombre> a $<precio>?" confirmation, and cobro and Administración render the API catalog on every browser. The local-only functions are gone from the live page (`staffAddSvc`, `staffSaveSvcName`, `staffDelSvc`, `staffMoveSvc`, `SS_DEFAULT`). Owner acceptance in production: created s14 "Corte + Matizado de canas" (22000, 60 min) from Administración and charged it from cobro (confirmed sale, $22.000).

### 2026-10-12 — barberpilot-api has no route to create, rename, deactivate or reorder a service

**Repo:** barberpilot-api

**Description**: Searched every `.js` file on every barberpilot-api branch: nothing inserts into `servicios`. The only service write routes are `PATCH /api/v2/config/servicios/:servicio_id/precio` (`:6481`) and `.../precio/revertir` (`:6576`). Services s01–s13 were seeded by hand-run SQL. There is also no display-order column (`servicios` has no `orden`), and `servicio_id` has no server-side generator (unlike `productos`, Migration 034, which uses a sequence).

**Why deferred**: Program Stage 1 (Migration 042: `orden`, `nombre_normalizado`, id sequence above the current max sNN, per-tenant normalized alias uniqueness, active-service-must-have-price trigger, catalog audit table; admin-only endpoints that bump `config_version`).

**Severity**: High — no supported way to evolve the service catalog without manual production SQL.

**Urgency**: Near-term — Stage 1.

**Status**: Closed 2026-10-13 — Stage 1 (barberpilot-api PR #37, merge `9dbac29`) added `/api/v2/config/servicios` (list, create, rename, deactivate/reactivate, reorder; admin-only writes; one transaction with audit and `catalogo_version`), plus Migration 042 (display order, server-generated ids). Verified live by the owner in production: a normal sale and 6 read-only queries matching the expected results exactly.

### 2026-10-12 — Renaming a service in Administración would make every sale of it fail (`alias_no_mapeado`)

**Repo:** barberpilot-control, barberpilot-api

**Description**: `POST /registros` resolves the service by the exact text it receives (`snom`) through `servicio_alias` (`resolverServicioYValidarPrecio`, `index.js:1393`; reject at `:1539`). A local rename (`staffSaveSvcName`) changes the name the cobro sends, so every subsequent sale of that service on that browser would be rejected and pile up in `bp_outbox`. Owner confirmed (2026-10-12) nobody has renamed a service yet, so no historical sales are affected.

**Why deferred**: Stage 0 disables rename; Stage 1's rename endpoint adds the new name as an extra alias and never removes old ones, so old and new names (and stale clients) keep resolving.

**Severity**: High — would silently stop sales of the renamed service from reaching the ledger.

**Urgency**: Immediate — latent trap live today until Stage 0 ships.

**Progress**: contained. 2026-10-13: Stage 0 disabled local renames (live, `573ef84`); Stage 1's rename route keeps every old alias and matching is now case/accent-insensitive. Close after Stage 2a is live (rename through the API, verified in its end-to-end test: old and new names both chargeable).

**Status**: Closed 2026-10-13 — Stage 2a live (`cdfd303`): renaming in Administración calls `PATCH /api/v2/config/servicios/:id` after a confirmation, which adds the new name as an alias and keeps every old one. Verified locally on PostgreSQL 14 and 18 (Stage 1 suite, 113/113: **old and new names both chargeable** after a rename) and end to end with the real control page against the Stage 1 API (Stage 2a test, 55/55, run on the exact commit now live: rename confirmed, another browser shows the new name, sale still accepted). No rename has been done in production yet.

### 2026-10-12 — Deleting a service in Administración only hides it on that one browser

**Repo:** barberpilot-control

**Description**: `staffDelSvc` (`index.html:7406`) filters the local `SS` array. The service stays active in the backend, keeps appearing on every other device and surface (App, saulfino-web check-in), and stays chargeable everywhere except the browser that "deleted" it.

**Why deferred**: Stage 0 disables delete; Stage 1 provides deactivate/reactivate (never a hard delete, to preserve `registros` history).

**Severity**: Medium — inconsistent catalog across devices; no money miscalculated.

**Urgency**: Near-term — Stage 0 / Stage 1.

**Progress**: contained. 2026-10-13: Stage 0 disabled local delete (live, `573ef84`). Stage 2a replaces it with deactivate/reactivate through the API (never deletes). Close after Stage 2a is live.

**Status**: Closed 2026-10-13 — Stage 2a live (`cdfd303`): there is no local delete any more; Administración deactivates/reactivates through the API (`/deactivate`, `/reactivate`, each with a confirmation), the row is kept, and the change reaches every browser. An inactive service is rejected by `POST /registros` under any spelling. Verified in the Stage 1 suite and the Stage 2a end-to-end test (deactivate hides it from cobro; reactivate brings it back at its price).

### 2026-10-12 — Hardcoded copies of the service catalog on every surface (barberpilot-control, App, saulfino-web) — s12 "Corte + Cejas" can't be charged from cobro

**Repo:** barberpilot-control, BarberPilot_App, saulfino-web, barberpilot-api

**Description**: The service list is hardcoded, wholly or partly, in:
- barberpilot-control `index.html`: `SS` (`:1295`) and `SS_DEFAULT` (`:6895`), s01–s10 only — this *is* the cobro list (`buildServices()`, `:2100`; the API only overwrites prices of ids already present, `:1257`). Sala de Espera: `SALA_PRECIOS` (`:5592`), the `#sala-svc` (`:675`) and `#editor-svc` (`:847`) `<option>` lists.
- barberpilot-control `agenda-admin.html`: hardcoded service `<option>` list (`:398`ff).
- BarberPilot_App `src/constants/index.js:54`: `SERVICIOS_FALLBACK` (used when the live catalog is missing; also carries typo'd names "Matizado ganas …").
- saulfino-web `index.html:1130` / `agenda.html:301`: public booking lists `SVCS`/`SVCS_DATA` with a hardcoded `_SID` id map — the API only refreshes prices; `checkin.html`'s `SERVICE_META` keys icons/durations by id.

Concrete consequence today: **s12 "Corte + Cejas" exists and is active server-side but is not in `SS`, so it cannot be charged from control's cobro** (the App's own code comment at `constants/index.js:50` flags the same gap). A service created in the backend would not appear in control's cobro, Administración, agenda-admin or saulfino-web's public booking.

**Why deferred**: Program Stage 2 (catalog on every surface via the Stage C client module, read-only last-known-good cache, no shipped fallback constants). Icons/durations become catalog fields managed in Administración.

**Severity**: Medium — staleness and missing services, not wrong amounts (the backend validates price/alias on `POST /registros`).

**Urgency**: Near-term — Stage 2.

**Status**: Open — partly in progress. 2026-10-13: Stage 2a (PR #33) removes barberpilot-control's `SS`/`SS_DEFAULT` and the paper-records tab's price map, and makes s12 chargeable from cobro. Still hardcoded after 2a: BarberPilot_App `SERVICIOS_FALLBACK`, saulfino-web `SVCS`/`_SID`/`SERVICE_META`, control agenda-admin options and the appointments API catalog (→ Stage 2b), control Sala de Espera lists (→ Sala de Espera stage). See also the 2026-10-13 entries.

2026-10-13 evening — **barberpilot-control cobro and Administración part resolved; entry stays Open for the rest.** Stage 2a is live (`cdfd303`): `SS` is now a view derived from the API catalog (`index.html:1332`, `_catalogoDerivarSS` `:1336`); `SS_DEFAULT`, the paper-records price map and the live-catalog price patch are gone. **s12 "Corte + Cejas" is chargeable from cobro** — verified in the Stage 2a end-to-end test (s12 listed at $15.000, sale accepted) and present in production's live catalog; it hasn't been charged in production yet. Still hardcoded, so not closable yet: in barberpilot-control itself, the Sala de Espera lists (`SALA_PRECIOS` `index.html:5695`, refreshed from the API at load `:1279`; `#sala-svc` `:686` and `#editor-svc` `:858` options) and `agenda-admin.html`'s `<option>` list (`:389`ff); BarberPilot_App `SERVICIOS_FALLBACK`; saulfino-web `SVCS`/`_SID`/`SERVICE_META`; the appointments API's `APT_DURATIONS`/`APT_NAMES`.

### 2026-10-12 — `POST /registros` stores the client-sent commission (`com`/`bb`/`neg`) without recomputing it — CRITICAL

**Repo:** barberpilot-api (consumed by barberpilot-control, BarberPilot_App)

**Description**: `validateRegistro` (`index.js:389`ff) only checks `bb`/`neg` are non-negative integers; the insert (`:1652`) stores `r.com || 0.5`, `r.bb`, `r.neg` exactly as sent. The barber's share recorded in the ledger is therefore decided by whichever client sent the sale — barberpilot-control's `COM` (locally editable, see next entry) or the App's inline `pago === 'debito' ? 0.43 : 0.50` (`PaymentSheet.js:59`, `RegistrarScreen.js:56`/`:130`). A stale or edited client produces a wrong payout that the backend accepts. Owner's query (2026-10-12, `registros` grouped by `pago, com`): no service sale has an off-rule rate today — the only rows that differ are the 3 counter sales and 15 product cross-sales explained in the entries below.

**Why deferred**: Program Stage 3 — server-side recompute of `com`/`bb`/`neg` (and price) on `/registros`, queue close and pago edit, from the tenant payment-methods table; client/server mismatch → store server values and record a mismatch alert.

**Severity**: Critical — the ledger trusts the client for money amounts.

**Urgency**: Near-term — no evidence of exploitation or drift in production data; Stage 0 removes the easiest trigger (local rate editing) first.

**Status**: Open.

### 2026-10-12 — Commission rates are editable per-browser in Administración and feed straight into the ledger

**Repo:** barberpilot-control

**Description**: `renderStaffCOM()`/`staffSaveCOM()` (`index.html:7292`/`:7306`) let anyone with access to Administración change efectivo/débito/transferencia rates; the value is saved to `localStorage` (`bp_staff_v1.COM`) and used by `registrar()` (`:2333`) to compute the `com`/`bb`/`neg` it sends — which `POST /registros` stores as-is (entry above). The change affects only that browser and is not audited anywhere.

**Why deferred**: Stage 0 disables local rate editing; Stage 3 moves rates to backend config (frontend read-only).

**Severity**: High — a single edit on one device changes real barber payouts with no trace.

**Urgency**: Immediate — Stage 0.

**Status**: Closed 2026-10-20 — rates exist only in the server (`tenant_commissions_v2`), edited in Administración with reason, history and undo; the browser keeps no copy. Live since 2026-10-16: barberpilot-api `3d0ff26`, barberpilot-control `3b167fd`, barberpilot-expo `1db5bd2` + EAS group `ee33fc73-b74b-4ac9-b29c-8fe48a08b5b7`. Owner confirmed in production 2026-10-20: Comisiones loads and is editable, Caja shows "Tarjeta". 2026-10-20: owner-verified in production with the next-day check from 2026-10-16 (Q0 no rate changes, Q1 0 rows with the tip inside the commission, Q2 débito 43 % 19/19, efectivo 50 % 26/26, transferencia 50 % 7/7, 0 without a rate, 0 that differ, Q5 0 rows, Q6 0 sales without sale_type). A rate copy remains in saulfino-web `barber.html` (see the 2026-10-15 "Débito" entry).

### 2026-10-12 — Sala de Espera close (`POST /queue/control/registrar`): not transactional, `sid` always `'queue'`, unknown payment method silently paid at 50%, unknown service passes with a $12.000 default

**Repo:** barberpilot-api

**Description** (`index.js:4082`ff):
- **Not transactional**: the service row (`:4187`), each attached-product row (`:4209`) and the queue update are separate writes; a failure part-way leaves a partial ticket.
- **`sid` hardcoded `'queue'`** in the INSERT (`:4188`) even though the catalog lookup just above (`:4149`) already resolved the real `servicio_id` — the reason ~1,500 sales have generic `sid='queue'` (owner query: 1,499 confirmado + 7 rechazado, 2026-06-04 → 2026-10-10).
- **`pago` never validated**; `com = COM_PAGO[pago] || 0.50` (`:4161`) — any unknown method is silently paid at 50%. Same `|| 0.50` fallback in `PATCH /registros/:id/pago` (`:3281`).
- **Unknown service names pass**: only `servicio_inactivo` is rejected; price is `precioOverride || catalog || 12000` (`:4160`).
- Tenant hardcoded `'saulfino'`.

**Why deferred**: Stage 3 (server-side recompute, unknown payment key → 400, sale type, single transaction). The free-text/override side belongs to the Sala de Espera lock-down, on hold.

**Severity**: High — wrong commission on an unexpected payment key, and partial writes possible.

**Urgency**: Near-term — Stage 3.

**Status**: Open. 2026-10-13 (Stage 1, live): the catalog lookup now matches names case/accent/space-insensitively, so a variant spelling gets the catalog price instead of the $12.000 fallback, and an inactive service is rejected under any spelling (accepted behavior change). `precioOverride` precedence is unchanged (tested). The $12.000 fallback itself is now tracked in the 2026-10-13 "hardcoded business constants" entry. 2026-10-16 (Stage 3b, live): an unknown payment method now answers 400 and a queue close with no price answers 400 (no $12.000 default, no 50 % default). Still open: the close is not transactional and `sid` is always `'queue'`.

### 2026-10-12 — `PATCH /registros/:id/pago` recomputes product rows at service rates, and the commission change isn't audited

**Repo:** barberpilot-api

**Description**: `index.js:3265`ff recomputes `com = COM_PAGO[newPago] || 0.50` and `bb`/`neg` for **every** row it edits, regardless of row type. Editing the payment method — or only the service name — of a product cross-sale (10%) or a counter sale (0%) silently converts it to 43%/50%. `registros_audit` records changes to `pago`/`precio`/`servicio` but not to `com`/`bb`/`neg`. The update has no tenant scope (`WHERE id=$1`).

**Why deferred**: Stage 3 (recompute by explicit sale type; audit every money field).

**Severity**: High — an ordinary correction can overpay a barber on a product sale without trace.

**Urgency**: Near-term — Stage 3.

**Status**: Partly closed 2026-10-16 (Stage 3b, live): a product sale keeps the product rate when its payment method changes (the sale type decides the rate). Still open: the recalculated commission (`com`/`bb`/`neg`) is not written to the audit — only `pago`, `precio` and `servicio` are. The route's 500 after saving is a separate defect (2026-10-20 entry below).

### 2026-10-12 — Counter product sales are stored with `com = 0.50` although the barber gets 0%

**Repo:** barberpilot-api, barberpilot-control

**Description**: `registrarProducto()` (`barberpilot-control/index.html:2212`) sends `com: 0` for a counter sale (`bid:'none'`, `bb:0`). `POST /registros` stores `r.com || 0.5`, and `0` is falsy, so `com` is saved as 0.50. Owner's queries (2026-10-12) confirmed exactly 3 such rows (debito ×2 — `TK1749574861000` and `TK1791651260822` — and efectivo ×1), all with `bb = 0` and `neg` = full price: **money is correct, only the `com` label is wrong**. These were the "debito at 0.50" anomaly.

**Why deferred**: Fixed going forward in Stage 3 (explicit sale type + server recompute). Historical rows are never modified by code.

**Severity**: Low — mislabelled rate, correct amounts.

**Urgency**: Eventual — Stage 3.

**Status**: Closed 2026-10-20 — from 2026-10-16 counter sales are stored with `com` 0 and `sale_type` producto_mostrador. History is not rewritten (owner decision: the money was always right, only the label was). Live since 2026-10-16: barberpilot-api `3d0ff26`, barberpilot-control `3b167fd`, barberpilot-expo `1db5bd2` + EAS group `ee33fc73-b74b-4ac9-b29c-8fe48a08b5b7`.

### 2026-10-12 — BarberPilot_App's queue close adds the tip into `bb`

**Repo:** BarberPilot_App

**Description**: `PaymentSheet.js:61` computes `bb = Math.round(precio * com) + propina` and sends it with `propina` separately; barberpilot-control and the App's own `RegistrarScreen` (`:133`) send `bb` without the tip. Owner decision (2026-10-12): `bb` is the commission only; the tip lives only in `propina`. Owner's query confirmed **no historical row has the tip inside `bb`** (every row with `bb <> ROUND(precio*com)` is one of the 3 counter sales) — the defect is latent. Reports that sum `bb + propina` are correct under the owner's definition; they would double-count the tip for any sale this code path records.

**Why deferred**: Stage 3 fixes `PaymentSheet.js` (OTA only after approval) and the server recompute enforces `bb` = commission only regardless of client.

**Severity**: Medium — latent overstatement of barber earnings.

**Urgency**: Near-term — Stage 3.

**Status**: Closed 2026-10-20 — the server computes `bb` as the commission only and the App sends the tip only in `propina`. Live since 2026-10-16: barberpilot-api `3d0ff26`, barberpilot-control `3b167fd`, barberpilot-expo `1db5bd2` + EAS group `ee33fc73-b74b-4ac9-b29c-8fe48a08b5b7`. 2026-10-20: owner-verified in production with the next-day check from 2026-10-16 (Q0 no rate changes, Q1 0 rows with the tip inside the commission, Q2 débito 43 % 19/19, efectivo 50 % 26/26, transferencia 50 % 7/7, 0 without a rate, 0 that differ, Q5 0 rows, Q6 0 sales without sale_type).

### 2026-10-12 — No explicit sale-type column on `registros` — service vs. product cross-sale vs. counter sale is inferred

**Repo:** barberpilot-api

**Description**: Sale type is only inferable from combinations of `sid` (matches `productos`?), the id suffix (`TK…-pN` for attached products), `bid='none'` and `com`. Owner's queries needed all of these to classify the 15 rows at `com = 0.10` (12 standalone cross-sales with `sid` pNN and no `ticket_id`; 3 attached: `TK898-p1`, `TK1287-p1`, `TK1596-p1`). Owner decision (2026-10-12): explicit column (`service` / `product_cross_sale` / `product_counter`), set server-side; counter sale = 0% barber commission.

**Why deferred**: Stage 3.

**Severity**: Medium — fragile classification for every report and recompute.

**Urgency**: Near-term — Stage 3.

**Status**: Closed 2026-10-20 — `registros.sale_type` (servicio / producto_barbero / producto_mostrador) exists, past sales were typed by Migration 046 (2492 sales) and every new sale carries it. Live since 2026-10-16: barberpilot-api `3d0ff26`, barberpilot-control `3b167fd`, barberpilot-expo `1db5bd2` + EAS group `ee33fc73-b74b-4ac9-b29c-8fe48a08b5b7`. Q6: 0 sales without it.

### 2026-10-12 — Stale parallel service catalog `tenant_services` (saulfino) and its routes

**Repo:** barberpilot-api

**Description**: Besides `servicios`/`tenant_servicio_precios`, the multi-tenant v2 layer seeds `tenant_services` for saulfino (`index.js:5737`) — owner's query: 11 rows with old prices and services not offered (e.g. Corte $10.000, Black Mask, Masaje craneal). It's read by `/api/v2/tenants/:slug/services` (`:6005`), availability (`:7032`) and v2 booking (`:7095`), plus `/api/v2/services`. No caller for saulfino was found in any repo on the dev machine (5 project repos, mae-studio-web, livedata-*), or in api `services/`, scripts or migrations; code can't rule out an external caller (Railway request logs could).

**Why deferred**: Out of scope until the config program decides its fate (retire for saulfino, or make it a view of the real catalog) — tracked so it isn't mistaken for the real catalog.

**Severity**: Medium — a second source of truth with wrong prices; harmless only as long as nothing reads it for saulfino.

**Urgency**: Eventual — resolve within the services stages (Stage 1/2).

**Status**: Open.

### 2026-10-12 — `servicio_alias.alias_texto` is a global primary key, and alias matching is exact-text (case/accent-sensitive)

**Repo:** barberpilot-api

**Description**: `alias_texto TEXT PRIMARY KEY` (`index.js:8037`) is unique across **all tenants**, so a second tenant can't use common names like "Corte". Matching is exact, so case variants and typos had to be added as separate aliases. Owner's queries (2026-10-12): no foreign key references `servicio_alias`, and no two aliases of different services collide after normalization → **per-tenant uniqueness on a normalized column is confirmed safe**. Production has no `unaccent` extension (only `plpgsql`), so normalization must happen in application code (NFD, strip diacritics, lowercase, trim, collapse whitespace) into a stored normalized column.

**Why deferred**: Stage 1 (Migration 042: `alias_normalizado`, uniqueness per `(tenant_id, alias_normalizado)`, normalized matching in `/registros` and queue close).

**Severity**: Medium — blocks multi-tenant use of the catalog; brittle matching today.

**Urgency**: Near-term — Stage 1.

**Status**: Closed 2026-10-13 — Stage 1 (barberpilot-api PR #37, merge `9dbac29`, Migration 042): primary key now `(tenant_id, alias_texto)`, a trigger forbids one normalized name for two services, `alias_normalizado`/`nombre_normalizado` computed in application code and recomputed on every boot, and `/registros` and queue-close match normalized names. Verified live by the owner (PK `(tenant_id, alias_texto)`, 0 unnormalized services).

### 2026-10-12 — Reports group sales by raw service text; ~1,560 sales carry a generic `sid`

**Repo:** barberpilot-api, sf-live

**Description**: `/resumen` builds its per-service map from raw `snom` (`index.js:1902`), so sf-live's "Servicios más solicitados" splits case/typo variants into separate services. About 1,560 of 2,441 saulfino `registros` have generic `sid` `'queue'` or `'custom'` (`custom`: 58 rows, 2026-05-04 → 2026-07-18, no longer produced). Owner's query: 35 distinct names; all high-volume names already map exactly to an alias; ~20 low-volume names (1–3 sales each, mostly May–June — e.g. "Perfilado express", "Corte + tintura", "Corte + diseño", "Afeitado de barba", "Corte + Matizado canas cabello") have no mapping. Owner decision (2026-10-12): **never rewrite `registros`**; use a read-time mapping table plus one shared database view for all reports.

**Why deferred**: Owner-review mapping list (each name → proposed `servicio_id` or an explicit "no catalog equivalent" bucket) comes at the end of the program; not urgent.

**Severity**: Low — reporting accuracy, not money.

**Urgency**: Eventual.

**Status**: Open.

### 2026-10-12 — Sala de Espera accepts free-text services and edited prices (design reference; lock-down on hold)

**Repo:** barberpilot-control, barberpilot-api, BarberPilot_App, saulfino-web

**Description**: Every queue entry route stores `service` as free text with no catalog check (`/queue/checkin` `:3702`, `/queue/control/checkin` `:3915`, `PUT /queue/:id` `:4457`). barberpilot-control's Sala shows an editable price box per ticket (`index.html:6376`, defaulting to 12000) and an editor price box (`:863`); the close route uses that price as-is. The App's PaymentSheet allows a manual price when the service isn't found, and `RegistrarScreen`'s "Especial…" allows a free name and price (rejected by the `/registros` alias gate unless the name happens to match an alias). Owner decision (2026-10-12): Sala de Espera will become catalog-selection only (no create, no free text, no price/description edits) — **on hold**. Operational cases that today depend on this flexibility and need a model first: authorized price adjustments (see the `precioOverride` entry), variable-price services ("Diseños — Desde $6.000" on saulfino-web, entry below), services not in the catalog.

**Why deferred**: On hold by owner decision (2026-10-12); A11's investigation is the design reference.

**Severity**: Medium — billing data quality depends on staff typing correctly.

**Urgency**: Eventual — on hold.

**Status**: Open (on hold).

### 2026-10-12 — No model for variable-price services ("Desde $X")

**Repo:** barberpilot-api, saulfino-web

**Description**: saulfino-web's public booking offers "Diseños" as "Desde $6.000" (`agenda.html`), but `tenant_servicio_precios` only supports one fixed price per service. Owner decision (2026-10-12): Stage 1's schema must support a per-service price range (and audited, admin-only, reasoned overrides) without rework, before the server enforces catalog prices everywhere.

**Why deferred**: Schema support in Stage 1; enforcement and UI later.

**Severity**: Low.

**Urgency**: Near-term — must be designed into Stage 1's schema.

**Status**: Open. 2026-10-13: Stage 1 added nullable `precio_min`/`precio_max` to `tenant_servicio_precios` with a check constraint (schema ready, nothing reads them yet). Enforcement, UI and the audited override model remain.

### 2026-10-12 — Write routes with no authentication across barberpilot-api — CRITICAL (deferred)

**Repo:** barberpilot-api

**Deferred by owner decision on 2026-10-12 — scheduled after the functional program.**

**Description**: Systematic scan of every write route registered with no middleware before the handler, then the full handler body checked for any header/token/role check. **No check found** in: `POST /registros/bulk` (`:1711`), `POST /registros/barbero` (`:3346`) — both insert into `registros` and have no caller in any repo; `POST /barbero/:bid/avatar` (`:2031`), `POST /asignar` (`:2068`), `POST /comprobantes` (`:3160`), `POST /push/test` (`:3233`), `POST /queue/control/checkin` (`:3915`), `POST /queue/:id/notify` (`:4736`), `POST/PATCH/DELETE /appointments*` (`:5151`, `:5373`, `:5420`), `POST/DELETE /blocked-slots*` (`:5431`, `:5478`), `PUT /appointments/:id/confirm|cancel|reassign` (`:5506`, `:5521`, `:5536`). **Need closer review** (some auth-related code in the handler, enforcement not confirmed): `PATCH /registros/:id/cliente` (`:2375`), `PATCH /clientes/:id` (`:2848`), `POST /queue/control/assign` (`:4036`), `PUT /queue/:id` (`:4457`, separate entry 2026-08-04), `PUT /queue/:id/client` (`:4613`). Some routes are presumably public by design (client check-in, public booking, the HMAC-verified WhatsApp webhook) and need explicit classification. CORS accepts requests with no Origin, so none of this is protected by CORS. **Related read**: `GET /registros/dia` (`:1763`) returns a full day of sales with no auth check in the handler. GET routes were not systematically audited.

Stage S1 is prepared and parked: branch `fix/remove-unauth-registros` (worktree `C:\Users\PC\barberpilot-api-fix-remove-unauth-registros`, uncommitted) removes `/registros/bulk` and `/registros/barbero`; verified locally against a fake database layer (before: both returned 200 and reached `INSERT INTO registros` with no credentials; after: 404, zero SQL; `POST /registros` still 401; route list differs by exactly those routes).

**Why deferred**: Owner decision (2026-10-12): finish the functional program first; security stages S1 → S0 → S2 afterwards. Non-negotiable meanwhile: every new or modified route in the program enforces the correct auth (`requirePanelRole` for staff/admin writes), and no secret value is written anywhere.

**Severity**: Critical — anyone who knows the API URL can write sales, expenses, appointments and queue data.

**Urgency**: Immediate — deferred by owner decision; not downgraded.

**Status**: Open (deferred). Stage S1 ready to deploy on the owner's word.

### 2026-10-09 — EAS internal-distribution build artifacts expire, with no warning from the CLI itself

**Repo:** BarberPilot_App (EAS infrastructure, not app code)

**Description**: Found while trying to install the app for a new hire (Angie) without a fresh build. `eas build:list`/`eas build:view` reported two existing Android builds (profile `internal`, distribution `internal`) as having a present, downloadable artifact — `"artifactUrl":"present"` in the CLI's own JSON output. Actually requesting both URLs directly returned a real HTTP 404 for both: the July 20, 2026 build and the August 5, 2026 build. The CLI's metadata is not a reliable signal that the install link still works — only an actual HTTP request against the URL is. The most likely cause is EAS's own storage retention window for build artifacts on this plan, though the exact retention period isn't confirmed from anything in this repo or the CLI output — it would need to come from Expo's own account/plan documentation, not guessed here.

**Why deferred**: Discovered as a blocker while trying to reuse an old build to onboard Angie faster — not something that was broken by any change in this session, a pre-existing gap in how the project has distributed the app that nobody had hit before (every prior hire happened to be onboarded soon enough after a build that the link was still live).

**Practical impact**: any gap of more than a few weeks between a build and the next new hire risks the only known install path being dead, forcing a brand-new build (cost + queue time) just to install the unchanged app on one more phone.

**Fix/mitigation (in progress, same day)**: the APK from each new `internal` build should be downloaded once and kept in a location the project controls (César's own Google Drive), independent of EAS's own artifact retention — that stored copy becomes the canonical install source for new hires, not a freshly-fetched EAS link. A stored APK only needs replacing when the native side changes (a new Expo SDK version, a new native module) — an OTA-only update (like the live-roster fix shipped this session) never requires a new install.

**Severity**: Medium — no data loss or security exposure, but a real, repeatable operational blocker for onboarding (confirmed to have actually happened, not hypothetical).

**Urgency**: Near-term — the Drive-copy mitigation should be in place before the next time this is needed, which could be the very next hire.

**Status**: Open. Mitigation (Drive copy) being put in place today; underlying EAS retention behavior itself is outside this project's control.

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

**2026-10-12 update**: Owner decisions — "Tarjeta" covers any POS card (debit and credit) at 43%; the user-facing label "Débito" becomes "Tarjeta"; internal key `debito` stays (historical rows); **no separate crédito method for saulfino** (credito inactive). Owner's query confirmed production still has `credito` 40/60 for saulfino. Code search found **no reader of `tenant_commissions_v2` for saulfino** (only `/api/v2/commissions`, no caller in any repo). Resolution moves to Stage 3: payment methods become a configurable tenant table (key, label, staff_pct, active, orden, applies_to), and `tenant_commissions_v2` / `COM_PAGO` are retired or corrected so there is one source.

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

**2026-10-12 update — scope changed from "harden" to "remove"; deferred by owner decision on 2026-10-12 — scheduled after the functional program.**
- Owner decision: the manual paper import ("Ingresar histórico" → `curl`) is **intentionally retired; no replacement needed**. The fix is therefore removal, not the hardening plan above.
- Scope widened to the twin route `POST /registros/barbero` (`index.js:3346`), also unauthenticated, also inserting into `registros`, also with no caller. Both are listed in the 2026-10-12 "Write routes with no authentication" entry.
- Re-swept 2026-10-12: every git repo on the dev machine, every branch and tag, plus all working copies — the only references are the route definitions, README text, a design doc and this file. No caller.
- Stage S1 prepared and **parked** (not committed): branch `fix/remove-unauth-registros`, worktree `C:\Users\PC\barberpilot-api-fix-remove-unauth-registros`. Removes both routes and the bulk rate-limiter line, and replaces the README's import instructions. Verified locally with a fake database layer: before, both routes returned 200 and reached `INSERT INTO registros` with no credentials; after, 404 and zero SQL; `POST /registros` still 401.
- Still open alongside it, in barberpilot-control: the "📥 Ingresar histórico" tab still produces JSON files that nothing can import, and the "Sincronizar con nube" button (`index.html:935`) still calls the undefined `migrarHistoricoNube()`. Both should be removed with the import retirement (Low, UI cleanup).
- Severity stays Critical; urgency stays Immediate — deferral is an owner scheduling decision, not a reassessment.

### 2026-10-08 — Railway barberpilot-api has no healthcheck path configured — a broken build can go live and replace a working one with no safety net

**Repo:** barberpilot-api

**Description**: A real `/health` endpoint already exists (`index.js:501`) and already does a genuine check, not a stub — `await query('SELECT 1')`, returning 500 if the database connection is actually broken. The gap isn't the endpoint; it's that nothing tells Railway to use it. No `railway.json`/`railway.toml`/`Procfile` exists in the repo declaring a healthcheck path, so (per César confirming Railway's Settings → Scale screen, same session this was found in) Railway has no configured healthcheck for this service at all. Practical effect: every deploy on this project this entire session (including the three just shipped) went live the instant the process started listening, with nothing checking whether it could actually reach the database first.

**Why deferred**: Out of scope for the auth/boot-seed/roster fixes shipped today — a deploy-pipeline safety net, not a functional bug in any of those changes. Found incidentally while scoping an unrelated item, not something that blocked today's work.

**Proposed fix (not built — scope only)**: add a `railway.json` with `"deploy": {"healthcheckPath": "/health", "healthcheckTimeout": ...}` (version-controlled, reviewable, survives environment recreation) rather than only setting it by hand in Railway's dashboard. Small, low-risk, no application code changes — the endpoint it points to is already correct.

**Severity**: Medium — no incident has happened yet, but every future deploy carries the same "bad build goes live with zero rollback-on-failure" risk until this is wired up.

**Urgency**: Eventual — no active incident; worth doing before the next deploy that has any real chance of a boot-time failure (e.g. anything touching the migration chain), since that's exactly the scenario a healthcheck would catch.

**Status**: Open. Scoped only, not built. **Deferred by owner decision on 2026-10-12 — scheduled after the functional program** (security/operations stage S2).

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

**Status**: Open, monitor-only. 2026-10-13 evidence: production logs show a single queue poller (one API process). The two rate-limiter counters seen for one client IP the same day therefore most likely come from unstable client-IP resolution rather than a second replica (the Stage R diagnostic will confirm) — see the 2026-10-13 rate-limiter entry.

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

**Status**: Open. 2026-10-12: now scheduled within the "Configuration as single source of truth" program (business hours and holidays stage), which replaces sf-live's hardcoded list with backend data.

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

**2026-10-12 update**: Recurred with the new barber Angie (October 2026), who had to be added by hand in several places. Now in scope of the "Configuration as single source of truth" program (barbers/staff stage, after the services and payment-methods stages). The owner's program rule also settles the fallback question above: no shipped fallback constants; the only allowed fallback is a read-only, timestamped last-known-good copy cached on the device with a visible "datos sin conexión" warning, and a clear error on first run with no network and no cache.

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

**Status**: Open. 2026-10-12: in scope of the "Configuration as single source of truth" program — durations become a field of the backend service catalog (Stage 1/2), managed in Administración. Note the key mismatch: these names (`Barba / Perfilado`, `Black Mask`, `Masaje craneal`) match the stale `tenant_services` seed, not the real `servicios` catalog.

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

**Status**: Open. 2026-10-12: part of the systemic "Write routes with no authentication" entry (same date). **Deferred by owner decision on 2026-10-12 — scheduled after the functional program**; severity not downgraded.

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

**Status**: Open. 2026-10-12: re-confirmed the values are still present in `STAGING.md` on `origin/main` (`e2d7c5c`). **Deferred by owner decision on 2026-10-12 — scheduled after the functional program** (stage S0: secrets exposure, rotation runbook, repo visibility, secret scanning); severity not downgraded.

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

**2026-10-12 addition**: Program rule for the "Configuration as single source of truth" program — every new or modified route resolves the tenant from the logged-in `panel_users` record (the pattern the servicios/productos price routes already use), with no new hardcoded `'saulfino'`. Existing hardcoded routes touched by the program will be migrated as they're modified; each one will be noted here.

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

**2026-10-12 update — worse than described above.** There are at least five sources, not two: barberpilot-control `COM`/`COM_DEFAULT` (`index.html:1308`/`:6908`, **editable per browser** — see the 2026-10-12 entry), barberpilot-api `COM_PAGO` (`index.js:3552`, with `|| 0.50` fallbacks), `tenant_commissions_v2` (credito 40/60), and the App's inline `pago === 'debito' ? 0.43 : 0.50` (`PaymentSheet.js:59`, `RegistrarScreen.js:56`/`:130`). And the description above is wrong on one point: for `POST /registros` (control cobro, App), the ledger stores the **client's** computed `bb`/`neg`, not the backend's — see the Critical 2026-10-12 entry. Owner-confirmed rule: efectivo 50%, transferencia 50%, Tarjeta (any POS card) 43%; product cross-sale 10%, counter sale 0%. Planned: Stage 3 (one tenant payment-methods table, backend authoritative, frontends read-only).

**Status**: Closed 2026-10-20 — commission rates exist only in `tenant_commissions_v2` (and the product rules in `tenant_config` `comisiones_reglas`); `COM_PAGO` and the browser's `COM` are gone. Live since 2026-10-16: barberpilot-api `3d0ff26`, barberpilot-control `3b167fd`, barberpilot-expo `1db5bd2` + EAS group `ee33fc73-b74b-4ac9-b29c-8fe48a08b5b7`. Remaining copy: saulfino-web `barber.html:563`, tracked in the 2026-10-15 "Débito" entry.

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

**Status**: Open. 2026-10-12: the same screen also adds the tip into `bb` — separate entry, same date. Both are addressed by the program (Stage 1 normalized alias matching on the server; Stage 3 server-side price/commission resolution, so the App no longer decides amounts).

### 2026-07-13 — `/queue/control/registrar`'s `precioOverride` has no `override`/`override_reason` UI equivalent

**Repo:** barberpilot-api, barberpilot-control

**Description**: `POST /registros` supports a documented override flow — a price mismatch is rejected unless the caller sends `override:true` plus a non-empty `override_reason`, logged to `registro_precio_override`. `/queue/control/registrar`'s `precioOverride` field has no equivalent reason-logging or explicit-override-flag mechanism; it just silently accepts whatever price staff type in barberpilot-control's Sala editor.

**Why deferred**: Not itself broken — a pre-existing, working, legitimate staff workflow (e.g. discretionary discounts). Flagged as an asymmetry worth resolving for consistency, not an active defect.

**Severity**: Medium (raised from Low on 2026-10-12, owner decision).

**Urgency**: Eventual — an audit-trail gap, not a correctness one.

**2026-10-12 update**: Owner's query found ~60 Sala de Espera sales charged at a price different from the catalog. **Owner confirms all were authorized adjustments he entered himself — not revenue leakage.** The real gap is that they carry no record of who made them or why. Owner decision: an override requires admin role, a mandatory reason, and an audit record (who, when, catalog price, charged price, reason) on every path that allows one; Stage 1's schema must support overrides and per-service price ranges without rework. Note also that `POST /registros`'s audited `override:true` path is used by no client today.

**Status**: Open.

### 2026-07-13 — Unjustified `OR estado IS NULL` clause, widespread across `barberpilot-api`

**Repo:** barberpilot-api

**Description**: `WHERE ... AND (estado = 'confirmado' OR estado IS NULL)` appears in at least 4 places in `index.js` (including `GET /stats/mes/:periodo`, the route `dashboard-facturacion.html`'s goal figures are computed from). Queried production: **zero rows in `registros` have `estado IS NULL`** — every row is either `'confirmado'` (1,373 rows) or `'rechazado'` (8 rows, correctly excluded). No legacy pre-`estado`-column category this clause is protecting; appears to be an unreviewed carryover, copy-pasted forward each time a new query needed this filter.

**Why deferred**: Out of scope for the goal-unification round it was found in — fixed only in the one new function that round added (`calcularMetaAnchorServicios`), which uses the strict filter. The other 4 pre-existing occurrences were left untouched.

**Severity**: Low — currently a no-op, zero NULL-estado rows exist in production.

**Urgency**: Monitor-only — latent risk if anything ever inserts a `registros` row with NULL `estado` not intending it as confirmed revenue.

**Status**: Open.

---

### 2026-10-21 — Railway platform incident: deploys paused; roles stage (API #52, `bc6765d`) merged but not deployed

**Repo:** barberpilot-api (infrastructure)

**Description**: API PR #52 (roles stage) was merged on 2026-10-21 at 10:40 Santiago as `bc6765d`, but Railway did not start a deployment (no new deployment in the list after 22:25 UTC on 2026-10-20 for about 4.5 hours; earlier merges deployed within seconds). The owner then saw Railway's status notice: ongoing platform incident "Dashboard and API unavailable, builds paused" — the most likely cause (not independently verifiable from our side; GitHub showed the same check suites for the deployed and the missed commit). Production stayed Online on `3cc2671` (OPS). Control PR #47 (roles panel) was deliberately NOT merged: it depends on the new API.

**Why deferred**: platform-side; no action possible while builds are paused. Rule followed: no empty commit, no CLI deploy while builds are paused.

**Severity**: Low — production unchanged and healthy; the new roles/observation/removed-routes code is simply not live.

**Urgency**: Near-term — resume as soon as Railway recovers.

**What to do when Railway resumes**: the owner checks the Deployments tab and applies the staged changes (rotated token) if no deploy starts by itself; confirm a new deployment row shows commit `bc6765d`; then run the roles deploy checks (Migrations 050, 051, 052 in the boot log, protected routes 401, the 13 removed routes 404, `/health`, `/admin/restore-status`, the owner's five-route console check), merge control #47, verify Pages. Prevention: after every merge, check within 2 minutes that a new deployment row appears; if not, stop and tell the owner. Update the UptimeRobot monitor with the new token after the restart.

**Status**: Open — waiting for Railway.

### 2026-10-22 — Barber Benjamín (b8) has no `barber_schedule` rows: a new barber is created without a schedule

**Repo:** barberpilot-api

**Description**: owner query (production, 2026-10-22): b1–b7 all have Mon–Fri 10:00–20:00 and Sat 10:00–15:00 active; **b8 Benjamín has no rows** — `POST /api/v2/staff` creates the barber, staff row and work period but never a weekly schedule. Effects before the fix: the two slot generators (`GET /appointments/slots`, public booking) fall back to the hardcoded `DEFAULT_SCHEDULE` for him (**Saturday 10:00–20:00 in code, the real Saturday closing is 15:00**), so booking can offer Saturday slots until 20:00 for him. Stage 9 scoring is NOT affected: a barber with no rows counts as scheduled every open day, and the hours come from `tenant_calendar_config`/the rules version (Saturday 15:00), never from the API default.

**Why deferred**: data fix is owner-run SQL (idempotent insert copying b1's rows, with read-only pre/post checks); the structural fix is in the A-3 stage (prepared 2026-10-22, not committed): one source for the shop hours (`tenant_calendar_config`, filled by Migration 053), a new barber gets his schedule from it in the same transaction (503 if the hours are not configured), and every hour fallback in code is removed or reads the same config. A barber's day off now stays closed (before, the code default opened it).

**Severity**: Medium — wrong Saturday availability for one barber in booking.

**Urgency**: Near-term.

**Status**: Data fixed 2026-10-22 — structural fix still open (A-3).
**Update 2026-10-22 (owner-run SQL, production)**: pre-check: b1 and b8 active; b1 has 6 rows (Mon–Fri 10:00–20:00, Sat 10:00–15:00); b8 had none. The idempotent insert (copy of b1's rows, only missing days, only `bid='b8'`) ran; post-check: b8 has 6 rows identical to b1 (days 1–5 10:00–20:00, day 6 10:00–15:00, active). Owner also confirmed `tenant_calendar_config` (saulfino): hours NULL for days 0–6; `peso_jornada`: day 0 = 0, days 1–5 = 1.0, day 6 = 0.536 — Migration 053 fills only the NULL hours and never changes `peso_jornada` (tested). A-3 stage approved by the owner (barberpilot-api PR #53, barberpilot-control PR #48, not merged: deploy after the roles deploy, on the owner's word). Closes when A-3 is deployed and verified.

### 2026-10-22 — `barber_schedule` has no tenant column (rows of another tenant's barbers p1–p4 share it)

**Repo:** barberpilot-api

**Description**: `barber_schedule` is keyed by `(bid, dia_semana)` with no `tenant_id`; production also holds p1–p4 rows (MAE tenant barbers) in the same table. A bid collision between tenants would mix schedules. Queries must filter by bid only, so the structural fix and the b8 SQL are scoped by bid.

**Why deferred**: multi-tenant cleanup (together with the other hardcoded `'saulfino'` literals, ~165 in the API); out of scope for the hours fix.

**Severity**: Low today (one tenant in use) — Medium when a second tenant goes live.

**Urgency**: Eventual.

**What would close it**: add `tenant_id` (backfill by the barber's tenant), include it in the key and in every query.

**Status**: Open.

### 2026-10-22 — October attendance stars compare every exit with 20:00, but the shop closes at 15:00 on Saturdays

**Repo:** barberpilot-control

**Description**: `HORARIO_APERTURA = '10:00'` / `HORARIO_CIERRE = '20:00'` (`index.html` ~4643) are the reference for the October "cierre" attendance star on every weekday, including Saturday (real closing 15:00). A barber who leaves at 15:00 on a Saturday is scored as leaving 5 hours early (1 star for that day), pulling his monthly "cierre" average down. Affects October bonuses (the star is averaged over the month's days); the November model uses the real Saturday closing from the shop hours.

**Why deferred**: October scoring is frozen by owner decision; the code retires with the October model (see the 2026-10-20 attendance-stars-from-localStorage entry).

**Severity**: Medium — October scores/tier thresholds could move by a few points for every barber with Saturday shifts.

**Urgency**: Near-term — before October bonuses are decided: check the October "cierre" stars against the real Saturday closing, or accept them after an owner review.

**What would close it**: either score October attendance from the server with the real hours, or recompute the October cierre stars with the Saturday closing before the October bonus run.

**Status**: Open.

## Closed / Resolved

### 2026-10-21 — Verification probe sent write methods to unauthenticated production routes — verified no change

**Repo:** barberpilot-tests (verification tooling)

**Description**: A draft of the post-deploy check script (`tools/post_deploy_check_roles.sh`) was run BEFORE the roles deploy and probed the routes that the roles stage removes — which still existed in production — with empty `{}` bodies: `POST /registros/bulk` (answered 200, empty lists: a no-op), `PATCH /asignar/1` (answered 200; the handler runs `UPDATE assignments SET estado=NULL WHERE id=1`), `POST /asignar`, `POST /registros/barbero` and `POST /push/subscribe` (all answered 400 on validation, nothing written), plus GETs. The only possible write was the `PATCH /asignar/1`.

**Verification**: owner-run read-only query on 2026-10-22: the `assignments` table has 0 rows — the probe changed nothing.

**Resolution**: the script's removed-route section now runs only when the new code is proven live (the new admin route answers 401 instead of 404); otherwise it prints SKIP. Rule recorded: a verification script never sends write methods to routes that may still exist on the live version. (The routes in question are removed by the roles stage, API #52.)

**Severity / Urgency**: — (no data affected)

**Status**: Closed 2026-10-22.

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

### 2026-10-13 — Railway's database console shows `time` values as blank

**Repo:** — (verification practice)

**Description**: In Railway's web console the `registros.hora` column (type `time`) renders blank even when the value is set — e.g. `TK1047` looked empty but is NOT NULL (owner check, 2026-10-13). When verifying times, select them as text (`hora::text`) or test `hora IS NULL` explicitly; never conclude "empty" from the console grid.

**Status**: N/A — not a defect.

### 2026-07-31 — Meta error code 130472 ("User's number is part of an experiment") on manual template sends is expected, occasional behavior

**Repo:** barberpilot-api

**Description**: Affects a small, Meta-selected fraction of numbers, blocks MARKETING-category templates specifically outside an open 24h window, self-resolves once the client messages the business first. Do not retry the same send — it will fail identically. No code action needed; documented so it's not mistaken for a regression during future troubleshooting.

**Status**: N/A — not a defect.

# Cash base (fondo) + persisted daily cash closings — design plan (2026-10-22)

Status: PLAN ONLY. Nothing is built. Build starts after the pending deploys (roles → A-3 → Sillas/durations/refresh).
Billing-affecting: verification report before any commit, separate approval before deploy.

## Owner decisions (final, 2026-10-22)
- The value made editable in Administración is the **fondo**: the cash that always stays in the drawer (today `BASE_MINIMA` = $50.000). The per-day starting cash (`BASE_CAJA`) and the **ajuste** stay per day.
- Seed: **$50.000 effective from 2026-05-01**.
- The per-day **ajuste** stays, but is stored on the **server**, audited (who, when, value, reason).
- An effective date in the **past is refused** (today or later only).
- Server unreadable: show the **last saved value labelled with its date**; never a silent default. The 30000 fallback in `cambiarBase()` is removed.
- **Scope extension**: every daily cash closing is persisted on the server — base used, ajuste, counted cash, amount to deposit, base that stays, author (from the login), time — and corrections are **new audited versions, never an overwrite**. The admin sees past closings (who closed, differences); the encargado closes but cannot edit past closings. The A4 and 58 mm receipts print from the **saved** closing.

## Facts from the sweep (2026-10-22)
Only `barberpilot-control/index.html` holds the base: `BASE_CAJA` (start-of-day cash, `sfsf_base_caja_<fecha>` in the browser), `BASE_MINIMA` (constant), `AJUSTE_CAJA` (= BASE_CAJA − BASE_MINIMA, `sfsf_ajuste_caja_<fecha>`). Surfaces: Cierre de caja tab (`renderCaja`), "Copiar texto" (`textoCierreWhatsapp`), 58 mm receipt (`printCaja`), A4 (`printCajaA4Directo`). The closing is computed only in the browser from today's records; barber liquidations and the ajuste live only in each browser. No server code, no sf-live/saulfino-web/App copy (the App's 50000 is the KPI bonus tier).

## Model (API, new migrations; every table append-only: UPDATE/DELETE blocked by trigger, like Migration 052)
1. `caja_fondo` — dated values of the fondo: `(id, tenant_id, vigente_desde DATE, monto INTEGER > 0, motivo, editado_por_id/nombre, aprobado_por_id/nombre, creado_en)`. Value for day D = the row with the greatest `vigente_desde <= D` (latest id on a tie). Seed row: 2026-05-01, 50000, "valor inicial". Past days therefore never change when a new row is added.
2. `caja_ajuste` — per-day ajuste versions: `(id, tenant_id, fecha, version, valor INTEGER (signed), motivo, editor…, creado_en)`; the current ajuste of a day is its latest version.
3. `caja_cierre` — one row per closing VERSION: `(id, tenant_id, fecha, version, fondo, ajuste, base_inicial (= fondo + ajuste), cobros_efectivo, cobros_debito, cobros_transferencia, gastos_total, pagos_barberos_efectivo, pagos_barberos_transferencia, caja_esperada, efectivo_contado, diferencia, a_depositar, base_que_queda, notas, snapshot JSONB (gastos, liquidaciones per barber, cobros per method with record ids), cerrado_por_id/nombre/rol, cerrado_en, motivo_correccion (required when version > 1))`, `UNIQUE (tenant_id, fecha, version)`.
   The **server computes** the figures from its own data (confirmed sales of the day, expenses of the day) plus the human inputs the client sends (barber payments, counted cash, notes); the client never sends totals. Formulas are the current ones, moved to ONE place: `caja_esperada = base_inicial + cobros_efectivo − pagos_barberos_efectivo − gastos`; `a_depositar = caja_esperada − fondo`; `diferencia = efectivo_contado − caja_esperada`.

## Routes (all answer status + body; identity from the verified login, never from the client)
- `GET /api/v2/caja/fondo?fecha=` (admin, encargado): value in force that day + since when. `GET /api/v2/caja/fondo/historial` (admin).
- `POST /api/v2/caja/fondo` (admin): `{monto, vigente_desde (today or later; past → 400), motivo, monto_actual_esperado, confirmacion_magnitud?}`; stale screen 409, magnitude guard 422 (same pattern as prices/durations), 503 if its migration failed.
- `GET/POST /api/v2/caja/ajuste?fecha=` (admin, encargado; today only for the encargado): `{valor, motivo, valor_actual_esperado}`.
- `GET /api/v2/caja/resumen?fecha=` (admin, encargado): the server-computed figures for the tab, live. `POST /api/v2/caja/cierre/previsualizar`: same formulas with the typed inputs, writes nothing.
- `POST /api/v2/caja/cierre` (admin, encargado): creates version 1 of TODAY's closing; a correction (version n+1) of today's by the encargado or admin with a reason; a closing/correction of a PAST day: admin only. `GET /api/v2/caja/cierre?fecha=` (current + versions, admin; encargado today only), `GET /api/v2/caja/cierres?desde&hasta` (admin: who closed, when, differences).
- Receipts: the A4 and 58 mm printouts are built from the saved closing returned by the API (a reprint of a past day = admin).

## Control screens
- Administración → new **Caja** section (admin only): fondo with its dated history, "Nuevo valor desde…" (date ≥ today), reason, confirmation on a big jump; the audit list.
- Cierre de caja tab: reads fondo/ajuste/figures from the server; the ajuste field saves to the server (reason); "Cerrar caja" saves the closing (confirm dialog with the figures); after saving it shows who/when/version and prints from the saved record. Admin: "Cierres anteriores" list (date, who closed, expected vs counted, difference, versions) with reprint. Encargado: today only, no edit of past closings (hidden in the UI AND refused by the API).
- Removed: `BASE_CAJA`/`BASE_MINIMA` constants, the 30000 fallback, the local `sfsf_base_caja_*`/`sfsf_ajuste_caja_*` as a source of truth (kept only as the labelled last-known-good copy).
- Server unreadable: the tab shows "valor guardado del dd/mm — sin conexión" in a visible banner; the figures are labelled provisional and **closing is not saved** until the server answers.

## Verification report (BEFORE any commit; billing-adjacent)
1. Fixture: several past days (sales by method, expenses, barber payments, ajuste cases: none / negative / positive). Compute the closing with the CURRENT code (the existing stage-2 snapshot harness: `caja`, `caja58`, WhatsApp text, A4) and with the NEW code at fondo = 50.000: **every figure identical**.
2. Mid-month change: fondo 50.000 from 2026-05-01, new value effective on day N. Days < N recomputed after the change still use 50.000; days ≥ N use the new value; closings already saved never change; a change with a past effective date is refused.
3. Persistence: a saved closing re-read equals what was printed; a correction is a new version and the old one is intact; the encargado cannot touch a past closing (403 with body); stale/magnitude/503 paths; append-only triggers.
4. Browser: Administración edit, ajuste saved server-side, close → receipts print from the saved record, admin list, encargado limits, server-unreadable banner (no silent default).

## Owner answers (2026-10-22) — plan approved
1. **Counted cash**: YES, a required input at closing; difference = counted − expected.
2. The encargado may correct **today's** closing, with a mandatory reason; never past days.
3. Closing a missed past day: **admin only**.
4. Server down at closing: **saving is blocked**; only a printout marked "PROVISIONAL — no guardado" is allowed.
5. Starting cash of the day = fondo of that day + ajuste. Confirmed from the code: `cambiarAjuste(v)` calls `cambiarBase(BASE_MINIMA + v)` and `cambiarBase(x)` sets `AJUSTE_CAJA = BASE_CAJA − BASE_MINIMA`, so today's behavior is exactly "fondo + ajuste".

## Deploy order
After the pending deploys: API first (migrations, routes), then control, each on the owner's word, plus a separate approval because it affects billing.

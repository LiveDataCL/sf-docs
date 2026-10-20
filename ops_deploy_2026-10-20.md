# OPS stage — deploy and verification record (2026-10-20)

**Status**: deployed 2026-10-20 evening (owner's daytime exception; the shop was closed for rain) and **verified by the owner in production**.

## What shipped

1. **Barber display order** — Administración → "Orden de barberos" (▲▼ list, like Servicios). Stored on the server (`barberos.orden`), every change audited (append-only `barberos_orden_audit`, Migration 049, editor from the verified login). Applied to cobro buttons, Sillas, Sala filters, KPI, the KPI dashboard and (automatically, it already reads the server order) the App. The "next turn" rotation never uses it: the last tie-break is now the barber's id, on the server and in the panel.
2. **Close from Sillas** — the same closing block and flow as Sala de Espera (price from the catalog, payment method from the server list, tip, attached products via ✏ Editar, client), implemented as ONE shared function used by both screens. The server computes the commission (stage 3b).
3. **Clientes → "Enviar a la cola"** — a real check-in from a client record through a new panel-login route, `POST /api/v2/cola/desde-cliente`. The browser sends only client id, service and barber ("cualquiera" uses the rotation); name and phone come from the client record on the server. A client already in today's queue is refused (409). The check-in logic of `POST /queue/control/checkin` was extracted into one shared function; the old route answers as before.

## Evidence

| Step | Result |
|---|---|
| Tests before merge | OPS API 54/54, OPS browser 32/32 (status and body); scoring equality 10/10, Stage 9 API 73/73, October regression 13/13, Stage 9 browser 39/39, 8b API 97/97, 8b browser 21/21 |
| barberpilot-api #51 (merge `3cc2671`) | Railway deploy SUCCESS; boot log: Migration 049 applied, reaches `Puerto`, no failure line; `GET`/`PATCH /api/v2/staff/orden` and `POST /api/v2/cola/desde-cliente` answer 401 without a login; `/health` 200; old `/queue/control/checkin` answers 400 with the same message; `GET /horarios/:fecha` hashes unchanged |
| barberpilot-control #46 (merge `aafef83`) | Pages deploy success; live `index.html`, `dashboard_kpis_barberia.html`, `conducta-diaria.js`, `texto-seguro.js`, `reportes-api.js` identical to main |
| Owner check in production | Barber order saved and applied (cobro, Sillas, after reload); "próximo turno" unchanged. Close from Sillas matches Sala (same ticket and amounts). "Enviar a la cola" works and refuses duplicates |

Rollback: revert the merge commits (API `3cc2671`, control `aafef83`); Migration 049 only adds an audit table.

## Known gaps (unchanged by this stage)

- `POST /queue/control/checkin` (and the other panel-used queue routes) is still unauthenticated; closing it belongs to the roles stage. The new route is authenticated.
- The "Enviar a la cola" button sits in the last column of the Clientes table, so on a narrow screen it needs a horizontal scroll (the WhatsApp buttons already behaved that way).

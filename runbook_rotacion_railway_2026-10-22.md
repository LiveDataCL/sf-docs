# Rotation runbook — Railway security disclosure (2026-10-21)

Prepared 2026-10-22. **No secret value appears in this file, in the chat, or in any log of this preparation.** Only variable NAMES.
Status: **APPROVED by the owner (2026-10-22)**. Window: **Friday 2026-10-23 after 20:00** (not tonight).

## 0. Owner decisions (2026-10-22)
- Runbook approved as written; window Friday 2026-10-23 after 20:00.
- `SOCIO_PIN`: rotate to a LONGER PIN, at least 8 digits; the owner tells the socio in person.
- `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY`: delete (not regenerate).
- The stale GitHub Actions secret `DASHBOARD_READ_TOKEN` in `barberpilot-control`: the owner deletes it himself.
- Local `C:\Users\PC\barberpilot-api\.env`: deleted AFTER the rotation (no secret copies on disk); a non-secret `.env.example` (names only) is provided if a local test needs one.
- P1 (variable names per service): the owner sends them, names only.
- Railway CLI: the owner runs `railway login` himself before the window; the assistant only runs read-only commands.
- **Rules during the window**: one step at a time; verify after each; stop and report on any surprise; never print, log or compare secret values.
- **Feature work continues in parallel** (build, test, commit, open PRs) but there are **no deploys and no merges until the rotation is done and verified**. Deploy order after the rotation: roles → A-3 → Sillas/durations/refresh/absence → ticket → check-in page → cash closing → session Part 2, each on the owner's word.

## 1. The incident and what we know
- Railway disclosed on 2026-10-21 that an unauthorized party may have accessed customer environment variables, some decrypted. Railway "strongly recommends that you revoke all environment variables stored in Railway" and review service logs. All Railway API/CLI tokens were invalidated (new ones must be created). Storage-bucket credentials and the GitHub tokens Railway held were reset by Railway. Source: Railway status page (https://status.railway.com/) and the guides under https://blog.railway.com/ ("Security Disclosure Recommendation: Rotate PostgreSQL Database Credentials", "…Redeploy Buckets and Reconnect GitHub After the Credential Reset").
- Railway status (read 2026-10-22 22:49 UTC): builds and deployments back at normal speed on all plans; Hobby builds returned at 21:59 UTC; "Ctrl/CMD+K → Deploy Latest Commit" is the documented way to deploy while Redeploy was limited.
- **Owner checks (2026-10-22)**: no email from Railway saying this account was affected; plan is HOBBY (builds available); no OpenAI/Anthropic keys in use; no unknown access in the GitHub account `LiveDataCL` (note: it is a personal account, not an organization — the API has no org by that name). **Decision: rotate everything as a precaution.**
- Probable explanation (UNVERIFIED) for the roles deploy (`bc6765d`) never starting: Railway reset its GitHub tokens, so pushes stopped triggering builds. Step W0 (reconnect GitHub) fixes it.

## 2. Inventory (names only)
Source: code (`process.env.*` in barberpilot-api at live main), the backup service repo, docs, GitHub (`gh secret list`: names only). **The real list in the Railway dashboard may have more names: step P1 compares.**

### 2.1 Railway service `barberpilot-api` (production)
| Name | Used by | Rotate? / how | Impact | Update also in | Verify |
|---|---|---|---|---|---|
| `DATABASE_URL` | API; should be a reference to the Postgres service | Follows the Postgres Regenerate (section 2.2); make sure it is `${{ Postgres.DATABASE_URL }}`, not a pasted string | API cannot connect until redeployed | backup service, owner's ad-hoc DB access, local `.env` | deploy log has no "password authentication failed"; `/health` 200 |
| `JWT_SECRET` | signs every login token (panel 8 h, socio, staff/App barber 12 h) | NEW random 48-byte hex | **everyone logs in again**: panel (admin, encargado), socios (sf-live), every barber in the App | — | login works; an old token answers 401 (the panel's new in-page login box opens) |
| `DASHBOARD_READ_TOKEN` | `x-dashboard-token` on the dashboard-token routes (incl. `/clientes/export/csv`, `/mensajes`, `/appointments/admin`, `POST /barber-schedule`), `requireAnyAuth`, `/events?token=`, `/admin/restore-status` | **ROTATE AGAIN** (the 2026-10-21 value was stored in Railway during the incident). NEW 32-byte hex. Read once at boot | the Administración token field and UptimeRobot stop working until updated | panel field (Administración → "Token de administrador"), **UptimeRobot** monitor, local `.env`, **delete the GitHub Actions secret of the same name in `barberpilot-control`** (stale: its workflow no longer reads it) | `/admin/restore-status` 200 with the new token, 401 without |
| `ADMIN_MASTER_PIN` | admin override login; creating panel users/socios (`/panel/setup`, `/auth/socio/setup`); PIN change. Plain text in the variable, hashed at boot | NEW PIN | only the owner uses it | password manager | override login with the new PIN; the old one fails |
| `SOCIO_PIN_HASH` | bcrypt hash of the socios' PIN (sf-live login) | choose a NEW (longer) PIN, generate its bcrypt hash locally (section 3, P2) | socios must use the new PIN: tell them | password manager | socio login in sf-live |
| `META_WHATSAPP_ACCESS_TOKEN` | sends WhatsApp messages | regenerate in Meta Business (system user token) | sends fail until updated | — | send a test message from the panel |
| `WHATSAPP_APP_SECRET` | verifies the webhook signature | reset the app secret in the Meta app settings | webhook calls rejected until updated | — | an incoming test message reaches the inbox |
| `WHATSAPP_WEBHOOK_VERIFY_TOKEN` | webhook subscription handshake | NEW random string, set in Railway AND in the Meta webhook configuration | a mismatch only breaks (re)subscribing | Meta console | Meta "verify and save" succeeds |
| `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY` | web push; subscriptions are kept in memory only; the push routes are removed in the roles deploy | after the roles deploy nothing uses them: **delete both** (or regenerate) | none (no persisted subscriptions) | — | boot log has no VAPID error |
| `R2_ENDPOINT`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME` | reads `restore-test/latest.json` for `/admin/restore-status`; the backup service uploads with the same | create a NEW R2 API token in Cloudflare, switch, verify, then delete the old one (the endpoint and bucket name are not secrets) | backups/restore status fail until updated | **also in `livedata-db-backup`** | manual backup run uploads; `/admin/restore-status` shows a fresh restore-test |
| `NEON_DATABASE_URL` (per the 2026-07-19 debt entry the API service holds it; no code reads it) | none in the API | reset the Neon role password; update; consider deleting it from the API service | none | `livedata-db-backup` | restore-test connects to Neon |
| `GOOGLE_REVIEW_URL`, `CONTACT_EMAIL`, `PORT`, `NODE_ENV`, `DISABLE_LOCAL_POLLERS` | configuration, not secrets | no rotation | — | — | — |
| `CLOUDFLARE_ZONE_ID`, `CLOUDFLARE_ACCOUNT_ID` (named in docs) | identifiers, not secrets | if a Cloudflare API TOKEN variable exists in the dashboard (name unknown to me), rotate it in Cloudflare | — | — | — |

### 2.2 Railway service `Postgres`
`POSTGRES_PASSWORD`, `PGPASSWORD`, `DATABASE_URL`, `DATABASE_PUBLIC_URL` (and the other template variables). Rotate ONLY with **Database tab → Config → Connection → Regenerate** (Railway's guide). Never edit `POSTGRES_PASSWORD`/`PGPASSWORD` by hand and never run `ALTER USER` yourself (the variable and the database would disagree). Regenerate restarts the database, drops all sessions, and does NOT redeploy the services: every service that references the variables must be redeployed. Anything outside Railway that uses `DATABASE_PUBLIC_URL` must be updated by hand. The guide also says to remove public access (Settings → Networking) if nothing outside the project needs it: decide after the window (the owner's ad-hoc queries use it today).

### 2.3 Railway cron service `livedata-db-backup` (daily `0 3 * * *`)
Names read from its code: `DATABASE_URL`, `R2_ENDPOINT`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME`, `NEON_DATABASE_URL`, `PROD_PUBLIC_URL`, `PROD_DATABASE_URL`, `BACKUP_FILE`. Make `DATABASE_URL` a reference to Postgres (or update it); `PROD_PUBLIC_URL`/`PROD_DATABASE_URL` carry a database credential if they are connection strings: update them from the new Postgres values.

### 2.4 GitHub (account `LiveDataCL`)
Actions secrets found by name: only `DASHBOARD_READ_TOKEN` in `barberpilot-control` (stale: the Pages workflow reads no secret since Stage L2a; before 2026-10-13 a step wrote that token into the published files, which is one more reason this token must not be reused). No other repository has secrets; `barberpilot-api`'s smoke test uses a throwaway CI database. Railway ↔ GitHub: see step W0.

### 2.5 Outside Railway (where values live or are typed)
Panel "Token de administrador" field (browser), **UptimeRobot** monitor of `/admin/restore-status`, local untracked `C:\Users\PC\barberpilot-api\.env` (holds a copy of several of the names above; overwrite or delete after rotating), the owner's password manager, Meta Business, Cloudflare R2, Neon. The Firebase admin service-account JSON in the App folder is git-ignored, never committed, and not a Railway variable: out of scope of this incident.

## 3. Before the window (no impact on the shop)
- **P1** In Railway, open the Variables tab of each service (`barberpilot-api`, `Postgres`, `livedata-db-backup`, any other) and send me the NAMES only (a screenshot with values hidden, or just the list). Never `railway variable list` in a shared place: it prints values.
- **P2** (socio PIN: at least 8 digits; VAPID: delete, do not generate) Generate the new values on your own PC, straight to the clipboard, never displayed or pasted in chat (PowerShell):
  - JWT: `node -e "process.stdout.write(require('crypto').randomBytes(48).toString('hex'))" | Set-Clipboard`
  - Dashboard token: same with `randomBytes(32)`. Paste each into the password manager right away, then generate the next.
  - Socio PIN hash: `$p=Read-Host "Nuevo PIN socio" -AsSecureString; $env:NEW_PIN=[Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p)); Set-Location C:\Users\PC\barberpilot-api-duracion; node -e "require('bcrypt').hash(process.env.NEW_PIN,10).then(h=>process.stdout.write(h))" | Set-Clipboard; Remove-Item Env:NEW_PIN` (the hash contains `$` characters: paste it as a plain value).
  - Master PIN: choose it yourself; VAPID: delete after the roles deploy.
- **P3** Third-party consoles, create-new-first (the old credential stays valid until step W9, which makes rollback trivial): Cloudflare R2 (new API token), Neon (role password reset), Meta (new system-user token, app secret reset). Consult each vendor's current guide: I could not verify their dashboard steps.
- **P4** GitHub: delete the stale `DASHBOARD_READ_TOKEN` secret in `barberpilot-control`; review the account's security log, SSH keys, authorized OAuth apps, personal access tokens and the Railway GitHub App installation (https://github.com/apps/railway-app).
- **P5** Confirm the last nightly backup and restore-test are OK (`/admin/restore-status`) so there is a fresh restore point before the window.

## 4. The window (after closing; the API restarts ONCE, together with the roles deploy `bc6765d`)
Order matters: each step has its check and its way back.
- **W0 — Reconnect GitHub (prerequisite for the deploy).** Railway Account Settings → reconnect GitHub; review https://github.com/apps/railway-app and accept pending permissions; for `barberpilot-api` (and the cron service) Settings → Source: confirm repository and branch, otherwise "Disconnect" then "Connect Repo"; Settings: confirm autodeploy is enabled. *Check:* the service shows the repo/branch connected. *Way back:* none needed.
- **W1 — Postgres Regenerate** (Database → Config → Connection → Regenerate). The database restarts; the shop is closed, so downtime is fine. *Check:* the Data view loads tables. *Way back:* not reversible (new password); never fix by editing the password by hand.
- **W2 — Stage the new `barberpilot-api` variables** (Variables tab, staged, not yet deployed): `DATABASE_URL` as the reference to Postgres, `JWT_SECRET`, `DASHBOARD_READ_TOKEN`, `ADMIN_MASTER_PIN`, `SOCIO_PIN_HASH`, new `R2_*`, `META_*`/`WHATSAPP_*` (if present), delete `VAPID_*` and the `NEON_DATABASE_URL` copy. *Way back:* discard the staged changes before deploying.
- **W3 — Stage `livedata-db-backup` variables** (`DATABASE_URL` reference, `PROD_*`, new `R2_*`, new Neon URL) and deploy it.
- **W4 — Deploy `barberpilot-api`**: apply the staged changes and Ctrl+K → **Deploy Latest Commit** (builds `bc6765d`). *Check in the deploy log:* "Migration 050", "051" and "052" lines with no failure line; no "password authentication failed"; the API answers. *Way back:* Deployments tab → previous deployment → Redeploy (the old code; whether it also restores the old variable values is UNVERIFIED — do not rely on it for secrets).
- **W5 — Verify the API.** Run `tools/post_deploy_check_roles.sh` (read-only); log in as the owner (the page shows its in-page login because the old token is now invalid: this also proves the old `JWT_SECRET` is dead); five-route admin console check as agreed for the roles deploy.
- **W6 — Dashboard token.** Paste the new token in Administración, update the UptimeRobot monitor. *Check:* `/admin/restore-status` 200 with the new token, 401 without; the monitor goes green.
- **W7 — Database sessions.** `SELECT usename, application_name, client_addr, state, backend_start FROM pg_stat_activity WHERE datname = current_database();` — terminate any session you do not recognize with `pg_terminate_backend(<pid>)` (Railway's guide).
- **W8 — Meta.** Update the webhook verify token in Meta (verify and save); send a test WhatsApp from the panel; receive one.
- **W9 — Backups.** Run the backup service once (or wait for 03:00 and check next morning); confirm a new object in R2 and a fresh `/admin/restore-status`; then **revoke the OLD R2 token, the OLD Neon password and the OLD Meta token** in their consoles.
- **W10 — Local PC.** DELETE `C:\Users\PC\barberpilot-api\.env` (owner decision: no secret copies on disk; a names-only `.env.example` replaces it); the Railway CLI session was re-authorized by the owner before the window (section 6).

## 5. Post-window checklist for the owner
1. Log in again on every screen: panel (admin), the encargado, the socios (new PIN) in sf-live.
2. Paste the new dashboard token in Administración; update UptimeRobot; confirm the monitor is green.
3. Each barber logs in again in the App with their PIN; test one on a real phone.
4. sf-live loads for a socio.
5. Cobro, Sala and Sillas work on the shop screen; one test sale is NOT needed (read-only checks suffice).
6. Tell me the results; I record them in sf-docs (no values).
7. Next morning: the 03:00 backup ran with the new credentials.

## 6. Log review since 2026-10-20 (read-only)
**Where**: Railway dashboard → each service → Logs (filter from 2026-10-20) and the workspace audit log (the guides say variable views/changes and the credential resets appear there; resets show under a Railway employee's name — expected). **What to look for in the `barberpilot-api` logs:**
1. Calls to the dashboard-token routes — above all `GET /clientes/export/csv` (all customers), `/mensajes`, `/appointments/admin`, `POST /barber-schedule` — at unusual hours or not made by you; if the HTTP logs show a client IP, note unknown ones.
2. Calls to `/api/v2/panel/setup` and `/api/v2/auth/socio/setup` (they create users and need the master PIN): none should exist you did not make; then `SELECT id, nombre, email, role, active FROM panel_users ORDER BY id;` for unknown users.
3. `[panel] login:` lines (who, when): logins outside business hours; bursts of 401 `invalid_credentials`.
4. Unusual volume on read routes (`/registros/rango`, `/clientes`).
5. Edits of money configuration: audit tables (`servicios_audit`, the prices table's `editado_por_*`, commission history): `SELECT table_name FROM information_schema.columns WHERE column_name = 'editado_por_nombre' GROUP BY 1;` lists them; look for entries you do not recognize since 2026-10-20.
6. Database (Railway's guide): unexpected roles (`SELECT rolname, rolsuper, rolcanlogin FROM pg_roles WHERE rolname NOT LIKE 'pg\_%';`), extensions (`SELECT extname FROM pg_extension;`), altered rows; **preserve evidence before restoring from a backup**.
7. Outside Railway: Cloudflare R2 bucket activity/audit log, Neon connection history, GitHub account security log, Meta security/WhatsApp message log for sends you did not make.
**Railway CLI re-authorization (I never see a token):** the old CLI session is invalid. The safe way is that YOU run `railway login` in your own terminal (browser flow; `railway whoami` confirms) — the session stays on your PC and I only run read-only commands such as `railway logs`. A narrower alternative: create a Project Token in the project's settings (https://railway.com/account/tokens is for account/workspace tokens), set it as `RAILWAY_TOKEN` only in that terminal session, and delete the token when we finish. Do not paste tokens in chat.

## 7. What I could not verify (so it is not stated as fact)
The real variable list in the dashboard; whether Railway keeps a history of variable values or restores them on rollback; the exact Cloudflare/Neon/Meta console steps; whether Railway's HTTP logs include client IPs; whether the cron service has a "run now" button; the cause of the missing roles deploy (hypothesis only).

## 8. After the rotation
The pending deploys in order, each on the owner's word: roles → A-3 → Sillas/durations/refresh → ticket → absence → check-in page.

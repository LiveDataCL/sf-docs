# Stage 9 — November scoring: verification evidence (2026-10-20)

**Status**: verification APPROVED by the owner on 2026-10-20 (mechanics and real-data run). Deploy pending: target Tue 2026-10-27 / Wed 2026-10-28, on the owner's word.

## What was verified

1. **Mechanics (local, production-shaped database).** The API's November scoring (`services/kpiV2.js`, computed in PostgreSQL) gives exactly the same points as the approved simulation `simulacion_nov_v2.sql` on all 10 barber-months of the fixture (Aug–Oct). The October model (the one live today) answers identically on the new and the live API (13/13 checks). API suite 73/73 and panel browser suite 39/39, all checking HTTP status and body.
2. **Real data (production, read-only, run by the owner on 2026-10-20).** `simulacion_nov_v2_real.sql` — the approved simulation with the real goals (Aug and Sep $8.014.600; October the current override $6.500.000), the per-month tips average and extra input columns. 11 rows. Nothing was written.

## Real-data result: current model vs November model

"Current model" is the October model computed with the same inputs by the live scoring code (`_puntajeBarbero`) and the rules seeded in `tenant_config 'kpi_reglas'` (version 2026-05). It was computed outside the panel; if the rules in production were edited after the seed, compare with the KPI tab. "November" uses the production barber count (`barberos_bd`: 3, 3 and 5), which is what the production code uses. October is month-to-date (run on 2026-10-20).

| Month | Barber | Services | Current model | November | Producción /40 | Conducta /30 | Puntualidad /15 | Venta adicional /10 | Propinas /5 |
|---|---|---|---|---|---|---|---|---|---|
| Aug | Didian | 167 | 69 · B | 66.7 · B | 33.3 | 20.8 | 7.7 | 0 | 4.93 |
| Aug | Steven | 98 | 58 · B | 49.4 · C | 24.1 | 19.0 | 6.3 | 0 | 0.00 |
| Aug | Winder | 97 | 61 · B | 55.0 · B | 23.8 | 21.3 | 5.2 | 0 | 4.68 |
| Sep | Didian | 147 | 59 · B | 48.8 · C | 30.7 | 11.0 | 5.3 | 0 | 1.83 |
| Sep | Steven | 100 | 55 · B | 49.4 · C | 24.8 | 14.8 | 4.8 | 0 | 5.00 |
| Sep | Winder | 105 | 59 · B | 48.4 · C | 24.3 | 17.8 | 3.6 | 0 | 2.74 |
| Oct | Didian | 90 | 64 · B | 54.3 · C | 36.1 | 13.0 | 5.2 | 0 | 0.00 |
| Oct | Steven | 55 | 60 · B | 56.3 · B | 25.2 | 21.3 | 4.8 | 0 | 5.00 |
| Oct | Winder | 24 | 26 · D | 25.4 · D | 17.0 | 0.0 | 4.2 | 0 | 4.22 |
| Oct | Angie | 30 | 64 · B | 59.2 · B | 19.0 | 26.5 | 8.8 | 0 | 4.85 |
| Oct | Benjamín | 12 | 54 · C | 49.5 · C | 13.3 | 24.0 | 12.2 | 0 | 0.00 |

Total group goal: Aug $4.865.000, Sep $4.742.000, Oct to date $2.822.000 of services billed, against $8.014.600, $8.014.600 and $6.500.000 — **not met in any month**, so under either model no bonus is payable (and no barber reaches A, the first tier with a bonus).

### October divisor

The SQL the owner ran used divisor 4 for October, but the database has 5 barbers with a work period in the month (Benjamín from 2026-10-16). The individual goal is the group goal divided by the number of barbers, so divisor 4 gives a higher goal ($1.625.000) than divisor 5 ($1.300.000) and the SQL's October Producción points were slightly **too low**. The production code reads the count from the database (`SELECT COUNT(*) FROM bar` in `services/kpiV2.js`, same count as the October model), so it uses 5. Effect on the November total, October only: Didian 49.0 → 54.3, Steven 53.2 → 56.3 (tier C → B), Winder 23.9 → 25.4, Angie 57.5 → 59.2, Benjamín 48.8 → 49.5. Recomputing the SQL's own rows with its own divisor reproduces its totals on 11/11 rows.

## Findings

- No barber reaches tier A in any month (highest: Didian, August, 66.7).
- Venta adicional is 0 for everyone: the highest share of attentions with a product is 4.2 % (Winder, October) against the 10 % threshold.
- Puntualidad is mostly 3.6–8.8 of 15 (Benjamín 12.2). Real marks exist for Aug–Oct, but many days have a missing entry or exit mark, which scores 0 for that half.
- The November model scores lower than the current one for nearly everyone — Producción is 40 (services 15 instead of 20) and conducta 30 instead of 50 — and moves five barber-months from tier B to C: Steven (Aug, Sep), Didian (Sep, Oct) and Winder (Sep). Steven in October stays at B.
- Tips: with the per-month local average (approved), most barbers score 0–5 of 5.

## Related decisions (all approved 2026-10-20)

Rules by evaluated month (October keeps its rules); daily conduct entered for today only; unchanged day carried forward and marked "copiado"; every barber starts November at 0 conduct until first evaluated (first working day Monday 2026-11-02); past-day corrections by the admin only with a mandatory reason, with full audit; tips average per evaluated month; barber count from the database; reminder before printing the A4.

## Not covered by this evidence

- The run is month-to-date for October; the final October figures differ.
- The current-model column is a recomputation, not a panel capture.
- Production behaviour of the new code is not verified until deploy; the deploy must land before 2026-11-01.

# Regla de rotación de turnos ("próximo turno" y "cualquiera")

**Definición del dueño, 2026-10-23.** Reemplaza la regla anterior ("quien no ha atendido hoy va primero").

## La regla

Entre los barberos **presentes** (marca de entrada hoy y sin marca de salida), **libres** (sin cliente en silla) y **no ausentes**, el próximo turno es de quien lleva **más tiempo disponible**:

- **disponible desde** = hora de término de su último servicio hoy (hora de su última venta confirmada); o, si aún no ha atendido, su **hora de llegada** (marca de entrada).
- Va primero el de **menor** "disponible desde".
- Empate exacto de horas → **id del barbero** (orden natural: b2 antes que b10). El orden de pantalla (`barberos.orden`) nunca decide el turno.
- Un barbero que **no ha llegado** no está en la rotación; al llegar entra con "disponible desde" = su llegada (detrás de los que ya estaban disponibles).
- Atender **no** manda a nadie detrás de un barbero que llegó **después** de que ese servicio terminó.

## Ejemplos del dueño (son pruebas)

1. Steven llega 10:00, atiende 10:05–10:35; Angie llega 10:50 → **Steven**.
2. Steven llega 10:00, atiende 10:05–10:35; Angie llega 10:20 → **Angie**.
3. Steven llega 10:00 y Angie 10:05, nadie ha atendido → **Steven**.

## Dónde vive (una sola regla, dos implementaciones probadas con los mismos casos)

| Dónde | Qué | Archivo |
|---|---|---|
| Control (panel) | `rotacionLibres()` — usada por Sillas (barra de rotación, ▶ siguiente, "Próximo turno") **y** por "Primer disponible" al hacer check-in | `barberpilot-control/index.html` |
| API | `services/rotacion.js` (`ordenarRotacion`) — usada por `resolveAnyBarber()` (check-in "cualquiera" del control y check-in público por QR) | `barberpilot-api/services/rotacion.js` |
| Casos compartidos | 15 casos (los 3 del dueño + empates, salidas, ausentes, ocupados, llegada tardía) | `barberpilot-tests/suites/rotacion/rotacion_casos.json` |

Pruebas: `rotacion_api_test.mjs` (regla pura, servidor real, check-in QR) y `sillas_rotacion_regla_test.mjs` (tarjeta ▶, "Primer disponible", "Próximo turno", primero de la barra). Verificado que ambas **fallan** con la regla vieja y pasan con la nueva.

## Qué hace el servidor cuando nadie cumple la regla (no se rechaza un check-in)

1. Hay presentes pero ocupados → el presente con menor tiempo de cola (luego id).
2. Nadie tiene marca de entrada hoy (marcas olvidadas) → comportamiento anterior: libres por "disponible desde" (sin registro al final), luego el menos ocupado.
3. Todos ausentes → se asigna igual (nunca se rechaza).

El control, en cambio, **no ofrece a nadie** en "Primer disponible" cuando no hay libres presentes (el operador elige).

## Cambio de comportamiento respecto de antes

- Antes, en el control, Sillas y "Primer disponible" tenían **dos copias** de la regla con desempates distintos (llegada vs id) y Sillas contaba barberos inactivos. Ahora es una sola función.
- Antes, el servidor podía asignar a un barbero que **no había llegado**. Ahora no (salvo el caso 2 de arriba).

## Despliegue

Control y API **juntos** (si el control mostrara este orden con la API vieja, el check-in QR "cualquiera" asignaría a otro barbero que el que Sillas muestra como próximo).

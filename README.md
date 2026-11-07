# App vecinal · Hackathon El Comercio (Shabat Shalom)

App de servicios, solidaridad y emergencias para vecinos, pensada para funcionar **con y sin
conexión**. Monorepo con el backend (NestJS), la app (Flutter), el contrato de la API, la
infraestructura local y las especificaciones (OpenSpec).

- **Arquitectura:** `docs/arquitectura/` · correcciones en `docs/adr/`
- **Estado de la Fase 0 y cómo contribuir (empieza aquí):** `docs/fase-0/README.md`
- **Hoja de ruta de las fases 0 a 3 y sus guías por lote:** `docs/hoja-de-ruta.md`
- [Avance del Lote A, tareas verificadas y evidencias](docs/fase-0/lote-a-nucleo-offline/README.md#estado-del-lote)
- **Plan de trabajo en 4 lotes (A–D):** `docs/fase-0/plan-de-lotes.md`
- **Cómo se entrega y revisa:** `docs/fase-0/revision-y-entregas.md`
- **Reglas, stack y comandos:** `CONTRIBUTING.md`

## Empezar

```bash
cd infra && docker compose up -d
cd ../backend && npm ci && npm run dev:keys && npm run db:migrate && npm run db:seed && npm run start:dev
cd ../app && flutter pub get && flutter gen-l10n && flutter run
```

Cada lote tiene su issue en GitHub y su change en `openspec/changes/`.

El arranque normal de la app usa el ingreso real por teléfono y código. En el entorno
local, `OTP_PROVIDER=fake` escribe el código en la consola del backend y no envía SMS.
Para recibir un SMS real se usa Firebase Authentication (`OTP_PROVIDER=firebase`); los pasos
están en `app/README.md`.
La sesión anterior de demostración sigue disponible con `--dart-define=DEV_SYNC=true`.
Los resultados y límites de la conexión con las pantallas están en
[la evidencia de integración de cuenta](docs/fase-0/evidencias/integracion-cuenta.md).

# App vecinal · Hackathon El Comercio (Shabat Shalom)

App de servicios, solidaridad y emergencias para vecinos, pensada para funcionar **con y sin
conexión**. Monorepo con el backend (NestJS), la app (Flutter), el contrato de la API, la
infraestructura local y las especificaciones (OpenSpec).

- **Arquitectura:** `docs/arquitectura/` · correcciones en `docs/adr/`
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

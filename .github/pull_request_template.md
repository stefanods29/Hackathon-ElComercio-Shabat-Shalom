## Entrega

- **Lote:** A / B / C / D
- **Parte:** N · tema (de `openspec/changes/lote-<letra>-…/tasks.md`)
- **Tareas de la parte:** 1.1, 1.2, …

## Qué cambia y por qué

<!-- Dos o tres líneas. Enlaza la sección de la arquitectura o el ADR si aplica. -->

## Cómo se verificó

- [ ] Backend: `npm run verify` y `npm run test:integration` en verde (si toca `backend/`)
- [ ] App: `tool/verify.cmd` (Windows) o `tool/verify.sh` en verde (si toca `app/`)
- [ ] Contrato: `npx @redocly/cli lint contracts/openapi.yaml` (si toca la API)
- [ ] Specs: `openspec validate --all --strict` y tareas marcadas en `tasks.md`
- [ ] Fronteras: `npm run boundaries` y grafo actualizado con `npm run graph` (si cambian dependencias)
- [ ] Evidencia en `docs/fase-0/evidencias/` (si la tarea la pide)

## Checklist de convenciones

- [ ] Código en inglés; textos de la app, contrato JSON, tablas y documentación en español
- [ ] Sin secretos, claves ni `.env` en el commit
- [ ] Toda escritura nueva desde el celular lleva `Idempotency-Key`
- [ ] Ningún dato sensible se replica de forma masiva ni va en el texto de un aviso

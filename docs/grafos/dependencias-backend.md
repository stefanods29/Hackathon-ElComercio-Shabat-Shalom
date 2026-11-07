# Grafo de dependencias del backend

Generado con `cd backend && npm run graph` (dependency-cruiser). No lo edites a mano.
Cada flecha es un `import`. Las raíces de composición son `app.module.ts` y `workers/`
y todos dependen de `shared`, nunca al revés (reglas en `backend/.dependency-cruiser.cjs`).

```mermaid
flowchart LR

subgraph src["src"]
  src_app_module_ts["app.module.ts"]
  src_main_ts["main.ts"]
  subgraph src_modules["modules"]
    src_modules_directorio["directorio"]
    src_modules_emergencias["emergencias"]
    src_modules_identidad["identidad"]
    src_modules_media["media"]
    src_modules_moderacion["moderacion"]
    src_modules_notificaciones["notificaciones"]
    src_modules_reputacion["reputacion"]
    src_modules_solidaridad["solidaridad"]
  end
  subgraph src_shared["shared"]
    src_shared_api["api"]
    src_shared_auth["auth"]
    src_shared_config["config"]
    src_shared_db["db"]
    src_shared_domain["domain"]
    src_shared_health["health"]
    src_shared_idempotency["idempotency"]
    src_shared_observability["observability"]
    src_shared_outbox["outbox"]
    src_shared_queues["queues"]
    src_shared_shared_module_ts["shared.module.ts"]
  end
  subgraph src_workers["workers"]
    src_workers_main_ts["main.ts"]
    src_workers_workers_module_ts["workers.module.ts"]
  end
end
src_app_module_ts-->src_modules_directorio
src_app_module_ts-->src_modules_emergencias
src_app_module_ts-->src_modules_identidad
src_app_module_ts-->src_modules_media
src_app_module_ts-->src_modules_moderacion
src_app_module_ts-->src_modules_notificaciones
src_app_module_ts-->src_modules_reputacion
src_app_module_ts-->src_modules_solidaridad
src_app_module_ts-->src_shared_config
src_app_module_ts-->src_shared_db
src_app_module_ts-->src_shared_shared_module_ts
src_main_ts-->src_app_module_ts
src_main_ts-->src_shared_config
src_modules_identidad-->src_shared_auth
src_modules_identidad-->src_shared_db
src_modules_identidad-->src_shared_config
src_modules_identidad-->src_shared_api
src_modules_identidad-->src_shared_domain
src_modules_identidad-->src_shared_idempotency
src_modules_solidaridad-->src_shared_domain
src_modules_solidaridad-->src_shared_api
src_modules_solidaridad-->src_shared_auth
src_modules_solidaridad-->src_shared_idempotency
src_modules_solidaridad-->src_shared_db
src_modules_solidaridad-->src_shared_outbox
src_modules_solidaridad-->src_shared_config
src_shared_api-->src_shared_observability
src_shared_api-->src_shared_domain
src_shared_auth-->src_shared_config
src_shared_auth-->src_shared_domain
src_shared_db-->src_shared_config
src_shared_health-->src_shared_api
src_shared_health-->src_shared_auth
src_shared_health-->src_shared_db
src_shared_health-->src_shared_domain
src_shared_idempotency-->src_shared_db
src_shared_idempotency-->src_shared_api
src_shared_idempotency-->src_shared_auth
src_shared_idempotency-->src_shared_domain
src_shared_idempotency-->src_shared_observability
src_shared_observability-->src_shared_domain
src_shared_observability-->src_shared_idempotency
src_shared_observability-->src_shared_api
src_shared_observability-->src_shared_auth
src_shared_observability-->src_shared_db
src_shared_observability-->src_shared_queues
src_shared_outbox-->src_shared_db
src_shared_outbox-->src_shared_domain
src_shared_outbox-->src_shared_queues
src_shared_queues-->src_shared_db
src_shared_queues-->src_shared_domain
src_shared_queues-->src_shared_config
src_shared_queues-->src_shared_idempotency
src_shared_shared_module_ts-->src_shared_api
src_shared_shared_module_ts-->src_shared_auth
src_shared_shared_module_ts-->src_shared_config
src_shared_shared_module_ts-->src_shared_db
src_shared_shared_module_ts-->src_shared_domain
src_shared_shared_module_ts-->src_shared_health
src_shared_shared_module_ts-->src_shared_idempotency
src_shared_shared_module_ts-->src_shared_observability
src_shared_shared_module_ts-->src_shared_outbox
src_shared_shared_module_ts-->src_shared_queues
src_workers_main_ts-->src_shared_config
src_workers_main_ts-->src_workers_workers_module_ts
src_workers_workers_module_ts-->src_modules_notificaciones
src_workers_workers_module_ts-->src_shared_config
src_workers_workers_module_ts-->src_shared_db
src_workers_workers_module_ts-->src_shared_outbox
src_workers_workers_module_ts-->src_shared_queues
src_workers_workers_module_ts-->src_shared_shared_module_ts
```

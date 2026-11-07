# Módulo `solidaridad` (implementación de referencia)

**Responsabilidad:** muro de favores: publicar, tomar un favor (el primero gana; el segundo
recibe un 409 explicable), y luego cancelar, resolver y buscar por cercanía (Lote B).

Copia este patrón en los demás módulos: `domain/` (TypeScript puro), `application/` (casos de
uso y puertos), `infrastructure/` (Kysely y `migrations/`), `api/` (controlador y esquemas Zod).
Esquema propio: `solidaridad.*`.

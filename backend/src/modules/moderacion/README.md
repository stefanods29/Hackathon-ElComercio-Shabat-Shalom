# Módulo `moderacion`

**Responsabilidad:** Denuncias, cola de revisión y sanciones (cadena: texto → imagen → reputación del autor → revisión humana).

**Entidades principales:** Denuncia, Caso.

**Cuándo y quién:** Fase 1 · el dueño se asigna al planificar la Fase 1.

## Estructura (igual en todos los módulos)

```text
moderacion/
├── domain/          # entidades y reglas; TypeScript puro, sin NestJS ni Kysely
├── application/     # casos de uso y puertos (interfaces)
├── infrastructure/  # adaptadores: repositorios Kysely, migrations/, clientes externos
├── api/             # controladores REST y esquemas Zod (alineados con contracts/openapi.yaml)
├── moderation.module.ts
└── index.ts         # interfaz pública: lo único que otros módulos pueden importar
```

Reglas: el módulo es dueño de su esquema de Postgres (`moderacion.*`); nadie más lee ni escribe sus
tablas. Las migraciones van en `infrastructure/migrations/AAAAMMDDHHmm_moderacion_<descripcion>.ts`.

## Antifraude de reseñas (Parte 3)

`ReviewPatternHandler` consume `reputacion.resena_creada` y usa el puerto público de Reputación
para recibir un conteo, sin consultar sus tablas ni recibir la señal de dispositivo. Si la reseña
sigue en revisión y hay cinco o más reseñas de la misma señal en la ventana de 24 horas, abre un
caso `pendiente` con motivo `patron_de_resenas`. La clave única por tipo e id de contenido evita
casos duplicados si el trabajo se reenvía.

`202611080220_moderacion_casos.ts` crea la cola privada que necesita este flujo. La Parte 5 añade
las denuncias, la cadena completa, las decisiones, las sanciones y sus rutas. No hay aprobación
automática ni publicación de reseñas en la Parte 3.

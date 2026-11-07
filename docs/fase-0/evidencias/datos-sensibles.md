# Datos sensibles solo para quien corresponde

- Fecha: 7 de noviembre de 2026.
- Criterio: «Los datos sensibles solo llegan a quien corresponde» (A · 4.1–4.4).
- Regla del repositorio: los datos sensibles (pedidos de ayuda, ubicación exacta, salud) nunca van
  en streams automáticos ni en el texto de una notificación.

## Pruebas automatizadas

| Prueba | Qué demuestra |
| --- | --- |
| `backend/src/modules/emergencias/sync-config-access.spec.ts` · «solo caso_asignado puede emitir datos de emergencias y exige suscripción explícita» | Ningún stream automático emite `emergencias.pedidos_ayuda` ni `emergencias.asignaciones`. La prueba falla si alguien agrega uno. |
| `backend/src/modules/emergencias/sync-config-access.spec.ts` · «solo entrega el caso solicitado al usuario asignado y lo revoca al finalizar» | Un vecino no asignado recibe 0 filas. El asignado recibe solo el caso que pidió, y al cerrar la asignación deja de recibirlo. |
| `npm run sync:validate` | `infra/powersync/sync-config.yaml` es válido con las mismas reglas que usa PowerSync. |
| `backend/src/modules/notificaciones/domain/templates.spec.ts` · «solo incluye texto genérico e identificadores» | Los avisos push no llevan contenido personal en el texto. |

Todas corren en `npm run verify`, en la CI de backend.

## Prueba en Android

`app/integration_test/assigned_case_revocation_test.dart` corrió en un Redmi Note 13 con un caso
sintético:
- El celular descargó el caso solo después de pedirlo por `caso_asignado`.
- Al reasignarlo, borró el detalle, la base del caso y su clave.

Los pasos y resultados están en [la prueba de purga](purga.md). El campo en iPhone se omitió con
autorización del usuario.

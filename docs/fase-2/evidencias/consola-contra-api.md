# Consola contra la API real de Emergencias

Fase 2, Lote C, tarea 2.5. Verificado el 8 de noviembre de 2026 en una Mac con Node 26, Flutter
3.47 y PostgreSQL con PostGIS, sobre la versión integrada de `main`.

## Cómo se prueba

```bash
cd backend
DATABASE_URL_ADMIN='postgres://…' npm run test:console-contract
```

`backend/test/contract/console.contract-spec.ts` crea una base temporal con todas las migraciones
y la siembra, levanta la API completa y prepara datos ficticios:

- dos coordinadores y una brigadista habilitados, con sus turnos;
- un evento activo;
- tres pedidos de agua en una celda.

Después ejecuta `consola/test/live/emergencias_api_test.dart` con la dirección, los ids y tokens de
corta duración en `VECINAL_API_FIXTURE`. Sin esa variable, las pruebas en vivo se saltan, así que la
CI de la consola no cambia.

## Qué cubre

| Caso | Resultado |
|---|---|
| Cola de la zona: los tres pedidos enviados, por prioridad, sin asignar y sin ubicación exacta | Pasa |
| Personas disponibles con su nombre y celdas: la de agua con 3 y sin total publicado | Pasa |
| Detalle con historial y 409 `conflicto_de_version` con una versión vieja | Pasa |
| La coordinadora asignada lo marca visto y asigna a la brigadista (el caso sigue visto) | Pasa |
| Otro coordinador toma el caso antes de cambiarlo y luego abre su detalle | Pasa |
| Derivar con motivo cierra el caso y lo saca de la cola | Pasa |
| Tablero de turnos con la cobertura, y crear y terminar un turno de la brigadista | Pasa |

Resultado: 7 de 7. No incluye el navegador ni la consola desplegada; eso queda para staging, que
todavía no está autorizado.

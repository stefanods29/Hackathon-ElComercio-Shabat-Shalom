# Pruebas de pantallas de la consola · C 1.7 y 2.6

Fecha: 8 de noviembre de 2026. Rama: `f2-lote-c/parte-1-2-pruebas-pantallas`.
Base: `origin/main` en `4fb7761`. Entorno: Windows, Flutter 3.47.9, Dart 3.13.7,
Node 26.13.0 y OpenTofu 1.13.9.

## Archivos y cobertura

- `consola/test/features/console_domain_test.dart`: 51 pruebas de `markFor`, `sortQueue`,
  `actionsFrom`, `showsExactLocation`, `CellCount`, `coverageOf`, `validateEntry`, `suggestId`,
  `normalizePhone` y `SessionTokens.fromJson`. Incluyen el límite del 25 %, exactamente cinco
  minutos y menos de cinco, plazo vencido, prioridad baja sin plazo, conteos 0/2/3, estados sin
  transiciones, turnos futuros/vencidos/terminados, todos los tipos de error del directorio,
  fechas inexistentes, coordenadas no finitas, roles maliciosos y tipos externos inválidos.
  `normalizePhone` se comprueba como normalizador, no como validador de teléfonos.
- `consola/test/features/console_screens_test.dart`: 23 pruebas de widgets y una de GeoJSON.
  Ingreso sin rol con OTP y cierre remoto; aviso/cierre por inactividad y reinicio por teclado;
  cola al 200 % abierta con Tab y Enter y borde de foco visible; los 15 códigos conocidos de
  `explainProblem`; conflicto 409 que conserva el motivo y cambia versión y clave al recargar;
  tabla sin totales ni conteos inferiores a tres; moderación con motivo e `Idempotency-Key`;
  confirmación de avisos por su ruta y nueva consulta de pendientes.
- `consola/lib/features/curaduria/domain/directory.dart`: corrección descrita debajo.
- `openspec/changes/fase-2-lote-c-consola-web-y-avisos-urgentes/tasks.md`: evidencia de C 1.7 y 2.6.

Todas las llamadas HTTP de las pruebas nuevas usan un adaptador en memoria. Una ruta inesperada
falla; nunca se abre una conexión real. Los datos son ficticios. Para comprobar la tabla se usa
la variante de escritorio de Flutter, que deja MapLibre como un marcador sin mapa nativo.
`cellsGeoJson` se compara completo: polígonos, anillo cerrado y solo nivel, sin conteos ni puntos
personales; con todas las necesidades usa el máximo publicado, no la suma.

## Error demostrado y corregido

`validateEntry` aceptaba `2026-02-30` porque `DateTime.tryParse` normaliza fechas fuera de rango.
También `NaN` eludía las comparaciones de latitud y longitud. La prueba
`rechaza días inexistentes y coordenadas no finitas` falló antes de la corrección y pasa después.
Ahora se exige una fecha de calendario que coincida con el texto original y coordenadas finitas.
Se reutilizan los errores existentes del ARB; no cambia el flujo de ninguna pantalla.

## Verificación

Desde `consola/`:

| Comando | Resultado |
|---|---|
| `flutter pub get` | Correcto |
| `flutter gen-l10n` | Correcto |
| `flutter analyze` | Sin observaciones |
| `flutter test --reporter expanded` | 82 pasan, 7 omitidas, 0 fallan |
| `dart format --output=none --set-exit-if-changed lib test` | 58 archivos, sin cambios |
| `tool/vendor_maplibre.sh` (Git Bash, Node 26.13.0) | MapLibre GL JS 5.6.0 preparado |
| `flutter build web --release --no-web-resources-cdn --dart-define=CONSOLE_DATA=demo` | Correcto; genera `build/web` |

La compilación emite una advertencia sobre la familia `CupertinoIcons` no incluida; termina con
código 0. No se cambió la configuración de fuentes, ajena a las pruebas de pantallas.

De las 82 pruebas, 75 son nuevas. Las siete omitidas son las de `test/live/`, que requieren
`VECINAL_API_FIXTURE` y quedan fuera de este encargo sin red real.

Desde la raíz:

| Comando | Resultado |
|---|---|
| `tofu -chdir=infra/cloud/modules/console-site init -backend=false` | Correcto; Cloudflare 5.28.1 |
| `tofu -chdir=infra/cloud/modules/console-site validate` | Configuración válida |
| `tofu -chdir=infra/cloud fmt -check -recursive` | Correcto, sin diferencias |

No fue necesario modificar el módulo OpenTofu. No se agregaron cuentas, secretos ni despliegues.
La CI de estas ramas se revisará al integrar, según el encargo; esta evidencia es local.
La validación en navegador con lector de pantalla y el despliegue con secretos siguen pendientes.
No se modifican las decisiones de `docs/fase-2/integracion.md`; no hay desacuerdos.
No se encontró `reglas-de-trabajo.md` ni un `AGENTS.md` aplicable en el checkout.

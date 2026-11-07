# 0006 · App sin generación de código y versiones fijadas

**Contexto.** Cuatro lotes tocan la app a la vez; la generación de código (riverpod_generator,
freezed) agrega pasos y conflictos en archivos generados.

**Decisión.** Riverpod 3 sin generador, clases inmutables escritas a mano, `sealed` y *records* de
Dart 3, y solo `flutter gen-l10n` (sus archivos no se suben). Flutter 3.47.9 fijado en CI. La infra
local usa PostgreSQL 18 + **PostGIS 3.6**; la 3.7 se evalúa cuando esté disponible en el proveedor
gestionado.

**Consecuencias.** Menos magia y menos conflictos; cada lote agrega solo sus paquetes en su PR.

# Pruebas de pantallas del tablero · D 1.3 y 2.3

Fecha: 8 de noviembre de 2026. Rama: `f2-lote-d/parte-1-2-pruebas-pantallas`.
Base: `origin/main` en `4fb7761`. Entorno: Windows, Flutter 3.47.9, Dart 3.13.7.

`app/test/features/emergencias/emergency_screens_test.dart` agrega 15 pruebas de widgets:

- Zona sin cobertura: alternativas 116, 105 y 106; pedir y ofrecer ayuda deshabilitados.
- Evento activo en el inicio real (`WallPage`) y activación manual desde `EmergencyPage`.
  En ambos casos las imágenes quedan apagadas; el interruptor no permite encenderlas.
- Tres toques contados hasta enviar; un segundo toque mientras guarda no hace otra escritura.
  El pedido conserva el id y la clave del borrador; reintentar después de un fallo los reutiliza.
- Los siete estados del pedido, sus textos del ARB y las alternativas oficiales.
  En camino se compara todo el texto privado contra una lista permitida, sin identidad de ayuda.
  Confirmar atención exige la capacidad explícita; derivación y cierre muestran motivo y siguiente paso.
- Sincronización desconectada y pedido sin acuse: mensaje local y aviso sin conexión.
- Repositorio de práctica real en memoria: pedido local aun después de avanzar el reloj,
  deduplicación y preparación de SMS sin invocar al compositor externo, aun con un contacto ficticio.

## Verificación

Desde `app/` se ejecutaron los pasos de `tool/verify.sh` directamente en PowerShell:

| Comando | Resultado |
|---|---|
| `flutter pub get` | Correcto |
| `flutter gen-l10n` | Correcto |
| `flutter analyze` | Sin observaciones |
| `flutter test --reporter expanded` | 293 pasan, 7 omitidas, 0 fallan |
| `dart format --output=none --set-exit-if-changed lib test` | 224 archivos, sin cambios |

El envoltorio `tool/verify.cmd` no resolvió la ruta del SDK en este equipo; se verificaron todos
sus pasos directamente. Las omisiones son las seis comparaciones de imágenes reservadas a macOS
y una prueba preexistente; no corresponden a las 15 pruebas nuevas.

No hubo cambios de comportamiento ni modificaciones de los archivos reservados a la rama de frescura.
El modo avión es **simulado a nivel de widget**. A 1.5, la prueba en dispositivos, permanece abierta.
No se modifican las decisiones de `docs/fase-2/integracion.md`; no hay desacuerdos.
No se encontró `reglas-de-trabajo.md` ni un `AGENTS.md` aplicable en el checkout.

# Encargo para Sol: capturas bloqueadas, vista difuminada y lector de pantalla en teléfonos

Responsable del encargo: `JDiazD33`. Tú preparas las compilaciones, las listas de pasos y el
registro de la evidencia. `JDiazD33` maneja los teléfonos y te pasa lo que observa.

La Fase 2 ya está integrada en `main` (commit `4fb7761` o posterior) y toda su CI está en verde.
Este encargo cierra dos pendientes que solo se pueden comprobar en teléfonos reales: uno Android y
un iPhone.

## Antes de empezar

Lee:

1. `reglas-de-trabajo.md` y los `AGENTS.md` aplicables.
2. `docs/fase-2/integracion.md`.
3. `docs/fase-2/lote-a-pedidos-offline-y-modo-operativo/README.md` (parte 3) y
   `docs/fase-2/evidencias/modo-operativo.md`.
4. `docs/fase-2/evidencias/accesibilidad-modo-emergencia.md`: lo que ya cubren las pruebas
   automáticas.
5. Los `tasks.md` de `fase-2-lote-a-pedidos-offline-y-modo-operativo` (tarea 3.2) y
   `fase-2-lote-d-tablero-de-emergencia` (tarea 4.5).

## Reglas de la entrega

1. Una rama nueva desde `main` actualizado: `f2-lote-a/parte-3-y-d-4-telefonos`.
2. Commit y push **solo de tu rama**. Nada de merge, rebase, cherry-pick ni PR. No toques `main` ni
   borres ramas.
3. En responsables, autores o revisores solo van usuarios de GitHub del equipo: `JDiazD33`,
   `stefanods29`, `Defartion`, `KQuirosA`. Nunca el nombre de un agente, modelo o herramienta.
   Ninguna mención de herramientas de IA en commits, código ni documentos, y ninguna línea
   `Co-Authored-By`.
4. Marca una tarea `[x]` solo con la observación registrada en el teléfono real. Lo que no se pudo
   ver se queda abierto, con el motivo.
5. Solo cuentas y datos ficticios: el modo de práctica o una API local con datos de prueba. Las
   capturas que guardes como evidencia no pueden mostrar descripciones, ubicaciones, teléfonos ni
   nombres, aunque sean de prueba. Si no hay forma de evitarlo, describe lo observado en texto.
6. No cambies el código nativo salvo que la prueba revele un error. Si lo cambias, explica el
   error, el arreglo y cómo lo volviste a probar.

## Encargo 1 · Capturas bloqueadas y vista difuminada (A 3.2)

Código:

- Android: `app/android/app/src/main/kotlin/pe/shabatshalom/vecinal/MainActivity.kt` activa
  `FLAG_SECURE` mediante el canal `pe.shabatshalom.vecinal/pantalla_sensible`.
- iOS: `app/ios/Runner/AppDelegate.swift` cubre la ventana con un difuminado al pasar al selector de
  apps (`UIScene.willDeactivateNotification`) y lo retira con `foregroundReady`.
- Dart: `app/lib/core/security/sensitive_screen_protection.dart`, que usan `operational_gate.dart`
  y `features/emergencias/presentation/operational_case_page.dart`.

### Pasos

1. Prepara una compilación de depuración para cada teléfono y explícale a `JDiazD33` cómo
   instalarla:
   - **Android:** `flutter run` con el teléfono conectado por USB y la depuración USB activada.
   - **iPhone:** `flutter run` con el equipo de firma de desarrollo de Xcode.
2. Prepara una lista de pasos con el resultado esperado de cada uno:
   - **Pantalla protegida abierta** (vista operativa del caso o modo operativo):
     - una captura de pantalla sale negra o la bloquea el sistema en Android;
     - una grabación de pantalla no muestra el contenido;
     - en el selector de apps se ve el difuminado y no el contenido.
   - **Pantalla normal** (muro o directorio): las capturas funcionan igual que antes.
   - **Al volver de la pantalla protegida a una normal:** la protección se retira.
   - **Al volver al primer plano:** el contenido aparece después del primer cuadro seguro, sin
     destello del contenido anterior.
3. Registra lo observado en `docs/fase-2/evidencias/modo-operativo.md`, en una sección nueva
   "Teléfonos reales":
   - modelo y versión de sistema de cada teléfono;
   - commit de la app y fecha;
   - cada paso con lo esperado, lo observado y si pasa.
4. Si todo pasa en los dos sistemas, marca A 3.2 en el `tasks.md` de A con el enlace a la
   evidencia. Si falla uno, déjala abierta y describe el fallo.

## Encargo 2 · TalkBack y VoiceOver en el modo emergencia (D 4.5)

Las pruebas automáticas ya comprueban texto grande, contraste, tamaño y nombre de botones y el
orden simulado del lector. Lo que falta es el recorrido con el lector real y con el alto contraste
del sistema.

### Pasos

1. Usa el modo de práctica de la app, que no necesita una cuenta real.
2. Prepara la lista de pasos para TalkBack (Android) y VoiceOver (iPhone), con el texto en 200 %
   del sistema y el alto contraste del sistema encendidos:
   - **Tablero de emergencia:**
     - el lector empieza por el título;
     - anuncia "Necesito ayuda", "Puedo ayudar", "Recursos" y el directorio como botones con
       nombre;
     - lee "Si hay riesgo para la vida, llama al 116, 105 o 106".
   - **"Necesito ayuda" en tres toques:** necesidad, formulario y "Enviar", con el lector
     anunciando cada paso, y el formulario se puede completar con dictado.
   - **Pedido propio:** el estado se anuncia, por ejemplo "Tu pedido todavía no fue enviado. Nadie
     lo ha recibido.", y un cambio de estado se anuncia sin tener que buscarlo.
   - **Recursos:** se oye "reportado hace…" y la marca de posiblemente desactualizado.
   - **Contactos de emergencia:** agregar y borrar un contacto solo con el lector.
   - **Modo sencillo:** las mismas pantallas siguen siendo usables.
3. Registra lo observado en `docs/fase-2/evidencias/accesibilidad-modo-emergencia.md`, en una
   sección nueva "Teléfonos reales", con el mismo formato que el encargo 1.
4. Si todo pasa en los dos sistemas, marca D 4.5. Un problema que se pueda arreglar en la app (una
   etiqueta que falta, un orden incorrecto) arréglalo, agrega la prueba automática que lo cubra en
   `app/test/features/emergencias/emergency_accessibility_test.dart` y vuelve a probar en el
   teléfono.

## Verificación

```bash
cd app
tool/verify.sh
openspec validate --all --strict
```

Más las observaciones en los teléfonos.

## Entrega

Devuelve:

- La rama y su SHA final.
- Los teléfonos usados.
- Cada paso con su resultado y los archivos cambiados.
- Las tareas marcadas y las que quedan abiertas, con el motivo.

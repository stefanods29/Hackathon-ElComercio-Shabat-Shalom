# Parte 3 · Modo operativo protegido

Rama `f2-lote-a/parte-3-modo-operativo`, con base en la entrega de la Parte 2 `c371b51`.

## Implementación

- La ruta `/emergencia/operacion/{id}` exige una sesión autenticada de la misma cuenta de la
  caché. El aviso urgente de C puede abrirla mediante un UUID válido, sin cambiar el texto del
  aviso. La práctica queda fuera de ese flujo. Para cargar un caso real sigue haciendo falta
  el permiso auditado de B de la Parte 2.
- La vista solo se construye después de activar la protección nativa, autenticar al operador
  con la credencial del teléfono y revisar el vencimiento en la caché. Se oculta al salir de
  primer plano y vuelve a revisar la caché antes de mostrarla. Salir de la vista cancela
  cualquier autenticación pendiente.
- El límite de laboratorio es de cinco minutos de inactividad. La caducidad de los datos
  toma el menor plazo entre 24 horas desde la creación del caso, el vencimiento del pedido y
  el del permiso. La ubicación exacta también respeta su propio permiso. El desbloqueo local
  permite consultar una copia vigente sin red y mantiene los permisos y sus vencimientos.
- Android usa `FlutterFragmentActivity`, `USE_BIOMETRIC` y un tema AppCompat para el diálogo
  de `local_auth`. Un `MethodChannel` aplica `FLAG_SECURE` solo a la vista protegida. En iOS,
  `AppDelegate` cubre la ventana con una vista difuminada al desactivarse la escena. Flutter
  avisa después de dibujar una vista segura para retirar la cubierta. El sistema requiere
  una descripción de uso de Face ID en `Info.plist`. Los textos de la app y del diálogo
  configurado salen de `app_es.arb`.
- Al cerrar o vencer un caso, la app retira los datos de memoria y borra los archivos y claves
  de la caché asignada. El autor conserva su resumen final cifrado con estado, versión, fecha y
  motivo apto. Esta parte usa el esquema local, el contrato API y las migraciones ya presentes.

## Verificación local

Las pruebas unitarias y de widgets simulan autenticación cancelada, inactividad, reapertura
sin red, fallo del canal nativo y regreso a primer plano con una revisión pendiente. Las
pruebas con una base PowerSync cifrada y reloj controlado comprueban el límite de 24 horas
con permisos todavía válidos y la purga al restaurar sin red. La prueba del pedido propio
comprueba las columnas de la copia final y el retiro del comando pendiente.

| Comprobación | Extracto del resultado |
| --- | --- |
| `app/tool/verify.sh` | `No issues found!` · `+242 ~1: All tests passed!` · `Formatted 206 files (0 changed)` · `✓ App verificada`. |
| Código nativo iOS | El chequeo de tipos de `AppDelegate.swift` pasó con el SDK de iOS y el framework Flutter. `Info.plist: OK`. |
| APK Android | `No Android SDK found`. El manifiesto y los temas pasaron la comprobación XML. |
| Compilación iOS sin firma | El intento se detuvo tras cinco minutos en la resolución de dependencias de Swift Package Manager. |
| `npm run verify` en backend | `245 passed (245)` pruebas · compilación NestJS. |
| `npm run test:integration` en backend | `191 passed (191)` pruebas con PostgreSQL y PostGIS. |
| CDN, OpenAPI y OpenSpec | `pass 10` en CDN · OpenAPI válido con tres advertencias previas · `27 passed, 0 failed` en OpenSpec. |

La prueba de Flutter omitida requiere PowerSync en vivo. OpenSpec marca 3.1 y 3.3 por la
evidencia de laboratorio. Las tareas 3.2 y 3.4 quedan pendientes de verificar.

## Pendiente de verificación en teléfonos

En la Parte 5, abrir un caso ficticio en un Android y un iPhone con credencial configurada.
En Android, capturar una pantalla pública, la pantalla operativa y otra pública al salir.
La captura operativa debe quedar oculta. En iOS, cambiar de aplicación desde la vista con
datos y confirmar que el selector solo muestra la cubierta. Volver antes y después del
límite de inactividad, y repetir con el caso vencido y el teléfono en modo avión. Registrar
dispositivo, versión, condiciones y resultado. El CI de esta rama queda pendiente.

## Teléfonos reales

Preparación del 8 de noviembre de 2026, America/Lima, en
`f2-lote-a/parte-3-y-d-4-telefonos`, desde `origin/main` en `4fb7761`.
Responsable de ejecutar y comunicar las observaciones: `JDiazD33`.
El código del caso operativo permanece en esa base; no se modificó el código nativo.

**Alcance acordado: Android por ahora. iPhone no se ejecutó por no disponer de una Mac con Xcode
ni de las herramientas de firma de iOS.** La tarea A 3.2 permanece abierta, pues exige ambos sistemas.

La [guía de instalación y ejecución](telefonos-android.md) contiene las condiciones del entorno,
el acceso al caso ficticio y los pasos completos. El resultado de la preparación local está en
el [reporte de la entrega](reporte-telefonos-android.md).

| Registro | Android | iPhone |
|---|---|---|
| Modelo y versión del sistema | POCO X6 Pro informado por el usuario; ADB confirma Xiaomi `2311DRK48G`, Android 16, API 36 | No ejecutado: faltan Mac, Xcode y firma |
| Fecha de ejecución en el teléfono | No ejecutado | No ejecutado |
| Commit de la app instalada | APK normal del código base `4fb7761`, instalado por USB; no se probó el caso operativo | No instalado |
| Observación física recibida | El usuario informa que el ingreso no envía el código; la API local no está disponible. Sin observaciones del contenido protegido | Ninguna |

Esta tabla registra el estado real de la evidencia, no una ejecución simulada:

| Paso | Esperado | Observado en Android | Resultado |
|---|---|---|---|
| A-01 · Captura normal | El sistema permite la captura del muro/directorio | No ejecutado; pendiente de observación por JDiazD33 | Pendiente |
| A-02 · Cancelar desbloqueo | El caso no aparece y se permite reintentar | No ejecutado; falta preparar API local, cuenta operativa ficticia y caso autorizado | Bloqueado por entorno |
| A-03 · Captura protegida | Rechazo del sistema o imagen vacía/negra, sin el contenido | No ejecutado | Pendiente |
| A-04 · Grabación | No se ve el caso al entrar a la protegida ni al iniciar allí la grabación | No ejecutado | Pendiente |
| A-05 · Selector | La miniatura no muestra el caso | No ejecutado | Pendiente |
| A-06 · Primer plano | Vista segura antes de revelar; sin destello de contenido previo | No ejecutado | Pendiente |
| A-07 · Salir a normal | La captura normal funciona otra vez | No ejecutado | Pendiente |
| A-08 · Reabrir protegida | Se vuelve a impedir capturar el contenido | No ejecutado | Pendiente |
| A-09 · Inactividad | Tras más de cinco minutos se exige credencial, sin revelar el caso anterior | No ejecutado | Pendiente |

En Android una superficie vacía/negra en el selector puede cumplir la ausencia de contenido;
el difuminado nativo descrito arriba corresponde a iOS. No se infiere ese resultado del código.
Las capturas de evidencia no incluirán descripciones, ubicaciones, teléfonos ni nombres, ni siquiera
ficticios. Un fallo que muestre datos se describirá en texto. No hay hallazgos observados en
teléfono ni una corrección nativa que declarar todavía.

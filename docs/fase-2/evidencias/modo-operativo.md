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

## Prueba de campo

Preparada el 8 de noviembre de 2026. Responsable: `JDiazD33`.
A 5.2 queda abierta hasta la ejecución en varios teléfonos. En laboratorio se reprodujo
CAM-01, una emisión inicial de cobertura sin esperar la lectura local. La [repetición y
corrección](https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom/blob/aa438ba5c8ab6f6f872280c94ec7b481f25e9302/docs/fase-2/evidencias/cobertura-local-sin-senal.md)
quedaron en una rama desde `main`.

1. Preparar una zona y un evento de laboratorio dedicados a la corrida, con dos coordinadores
   ficticios habilitados, un turno y cuentas separadas en al menos dos Android y dos iPhone.
   Verificar la cobertura en línea antes de cortar los datos. Anotar alias de equipo, modelo,
   SO, batería y SHA de app, API y consola. Usar solo el entorno local o el autorizado por escrito.
2. Asignar un código de caso por intento planificado. En la compilación de diagnóstico, registrar
   `draft.id` antes de entrar a `OperationalEmergencyRepository.saveRequest`. Mantener ese manifiesto
   separado de las colas, incluso si el guardado falla. No registrar el resto del borrador.
3. Crear pedidos sin señal, comprobar el mensaje de guardado local, reiniciar la app de un
   Android y un iPhone y comprobar que conservan el pedido. Mantener al menos un equipo de cada
   sistema con batería baja y anotar el porcentaje y el modo de ahorro.
4. Reconectar todos en una cuenta regresiva. Alternar un corte con señal débil en un subconjunto,
   con un limitador de red del sistema o un punto de acceso de prueba. Registrar la pérdida,
   latencia y duración configuradas. En un caso cortar el enlace después de persistir el pedido y
   antes del acuse, si el proxy del laboratorio permite reproducirlo.
5. Recuperar la red normal. Esperar la ventana pactada de reintentos y registrar su duración.
   Exportar el estado final de las colas y la base antes de cerrar o anonimizar el evento.
   Reconciliar también los pedidos que seguían pendientes tras recuperar la red.

### Exportación y recuento

Crear `plan.json` como un arreglo JSON de UUIDv7 de los casos planificados. Desde la sesión
de diagnóstico de cada teléfono, ejecutar una consulta de solo lectura mediante la conexión
que la app ya abrió a SQLCipher. Filtrar por la ventana de la corrida, con fechas UTC en el
formato ISO que guarda la app:

```sql
SELECT recurso_id, estado
FROM envios
WHERE tipo = 'helpRequest' AND creado_en >= ? AND creado_en < ?
ORDER BY recurso_id;
```

Exportar las filas como arreglo JSON, conservando un archivo por dispositivo. Un teléfono sin
filas aporta `[]`. Mantener la conexión y clave dentro del equipo de prueba. En PostgreSQL,
usar el ID del evento dedicado para detectar pedidos adicionales, incluidos los que tengan
otro identificador. El comando exporta solo los IDs desde una conexión local con acceso de lectura.

```sh
psql -XAt -v ON_ERROR_STOP=1 -v evento="$EVENTO_FICTICIO_ID" > servidor.json <<'SQL'
SELECT COALESCE(json_agg(json_build_object('id', id) ORDER BY id), '[]'::json)
FROM emergencias.pedidos_ayuda
WHERE evento_id = :'evento'::uuid;
SQL
```

Desde `backend/`, con los archivos en la carpeta de ejecución o indicando sus rutas:

```sh
npx tsx scripts/reconcile-field-requests.ts plan.json servidor.json android-a.json android-b.json ios-a.json ios-b.json
```

La salida contiene solo conteos. El código de salida es 0 si todos los casos están en la
cola y el servidor, con acuse y sin diferencias. Es 1 si hay diferencias y 2 si falta un
archivo o el formato es inválido. `perdidos` cuenta IDs planificados ausentes del servidor al
corte. `sinRegistroLocal` detecta los ausentes en todas las colas. Cada fila adicional del mismo
ID suma un duplicado. Los IDs inesperados se investigan como posibles reenvíos con ID nuevo.
Reintentos de un mismo registro no cuentan como duplicados. Un rechazo y una falta de acuse
se registran por separado. Conservar únicamente el resultado agregado en la evidencia.

| Fecha / SHAs | Equipos y condiciones | Pedidos | Perdidos | Duplicados | Sin acuse / rechazados |
|---|---|---|---|---|---|
| Pendiente | Pendiente | — | — | — | — |

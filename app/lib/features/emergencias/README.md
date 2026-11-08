# Funcionalidad `emergencias`

Pedidos de ayuda con estados, tablero, recursos y grupos de apoyo. En la Fase 0 el **Lote A** validó aquí los datos sensibles bajo demanda y su purga; en la Fase 1 agrega el directorio de emergencia sin conexión.

**Cuándo y quién:** Fase 0 (Lote A, validación) · Fase 1 (Lote A, directorio; Lote D, pantalla "Estoy en emergencia") · Fase 2 (completo).

```text
emergencias/
├── assigned_case_cache.dart   # caso asignado: base cifrada aparte, bajo demanda (Fase 0)
├── domain/                    # directorio: entidades, validador del contrato y umbrales de antigüedad
├── data/                      # copia local atómica, descarga desde la CDN y proveedores Riverpod
└── presentation/              # pantalla básica /emergencia
```

## Directorio de emergencia (Fase 1, Lote A, parte 2)

- Contrato: `contracts/directorio-emergencia.schema.json`. `EmergencyContract` repite sus campos y patrones, y una prueba los compara con el esquema.
- La app descarga `emergencia/indice.json` y el archivo de su distrito desde `CDN_BASE_URL`, **sin token ni identificadores** (`core/network/cdn_client.dart`).
- Antes de guardar comprueba el tamaño, el SHA-256 del índice y el contrato. Si algo falla, conserva la copia anterior y lo vuelve a intentar en la siguiente revisión (inicio de sesión o vuelta a la app).
- Revisa como máximo una vez al día por zona. Si el hash publicado es el de la copia guardada, no vuelve a descargar el archivo. No usa `If-None-Match`: el índice pesa alrededor de 1 KB.
- La copia vive en `<soporte>/emergencia/`, fuera de la base de la cuenta: se abre sin sesión y cerrar sesión no la borra. Borrar la cuenta solo olvida la zona de la última revisión.
- Sin descarga válida se muestra `assets/emergencia/respaldo.json` (116, 105 y 106 con fuente y fecha). Si la zona no tiene archivo, también.
- Cada dato muestra su fuente y su fecha de verificación. Pasado el umbral de su tipo (30 días; 180 para los números) se marca "Posiblemente desactualizado", sin ocultarse.

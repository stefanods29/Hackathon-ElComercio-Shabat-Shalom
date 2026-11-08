# Entrega de implementación · Fase 1 C

Fecha: 7 de noviembre de 2026. Rama: `lote-c/fase-1-media-infra`.
Estado: código y documentación preparados para revisión. La aceptación del equipo, las
integraciones externas y la verificación final continúan pendientes.

## Entregado

| Parte | Implementación |
| --- | --- |
| Media | Contrato de archivos, migración propia, autorización, cuotas, idempotencia, firmas privadas, confirmación y baja |
| Procesamiento | SHA-256 y bytes reales, WebP sin metadatos, principal/miniatura, blurhash, leases, reintentos y limpieza recuperable |
| App | Galería con estados y confirmación de baja, saneamiento, bóveda AES-GCM por cuenta, cola durable y transferencias nativas |
| Reutilización | Selector de referencias listas, vista previa cifrada y componente de foto pública para integrar con B/D |
| Compartir | Selector nativo, disponible para WhatsApp instalado, texto genérico y enlace de publicación confirmada |
| Monitoreo | OpenTelemetry y Sentry opcionales, eventos con información limitada y recolector local |
| Entornos | OpenTofu dev/staging/prod, API y Job, Cloud SQL privado, R2 privado, identidades y referencias a secretos |
| Revisión | Especificación OpenSpec, documentación de integración, pruebas automatizadas y comprobaciones de CI preparadas |

## Comprobaciones realizadas antes de la indicación de suspenderlas

Estos resultados corresponden a las revisiones ejecutadas antes de los últimos ajustes; no
certifican la versión final. Por indicación del usuario no se continuó compilando ni ejecutando pruebas.

| Comprobación | Resultado previo |
| --- | --- |
| Backend: tipos, lint, formato, fronteras y Sync Streams | Correctos |
| Backend: pruebas unitarias con dos workers | 45 correctas |
| Backend: integración PostgreSQL 18.6/PostGIS 3.6.2 | 31 correctas en cinco archivos |
| Backend: compilación | Correcta |
| Flutter: análisis | Sin observaciones |
| Flutter: pruebas completas | 90 correctas |
| OpenSpec: validación estricta | 11 elementos correctos |
| OpenAPI: Redocly | Válido; dos advertencias preexistentes en salud y JWKS por ausencia de respuesta 4xx |
| OpenTofu: validación y pruebas con proveedores sustituidos | Configuración válida; tres pruebas correctas |
| OpenTelemetry Collector oficial | Configuración válida, binario con SHA-256 comprobado |

Las pruebas del backend usan PostgreSQL real y Sharp real. El almacenamiento de la integración
es un doble; el firmado se comprueba adicionalmente con el SDK S3 real. No acreditan una
transferencia efectiva a R2. Las pruebas de la app cubren persistencia, cuentas, reconexión,
confirmación perdida, cifrado/alteración, selección, baja con confirmación y letra al 200 %.

Una ejecución paralela inicial del backend agotó el tiempo de inicialización de una prueba.
La repetición con dos workers pasó. No se modificaron los tiempos de espera para ocultarlo.

## Cambios finales sin nueva ejecución

- Protección adicional frente a operaciones de fotos que terminen después del cierre de sesión;
  se añadió una prueba de regresión, pendiente de ejecutar.
- Cancelación por generación en el adaptador de transferencias y limpieza de copias temporales.
- Liberación del búfer de selección también cuando la imagen no se puede decodificar.
- Sustitución de `sentry_flutter` por `sentry` Dart con manejadores explícitos. El intento de
  compilación Android había detectado que el plugin nativo nuevo exigía API 26; se conserva
  `minSdk = 24` y se evita ese plugin. Se actualizó el lockfile usando la caché local.

**No se entrega un APK nuevo verificado.** El APK que pueda existir de Fase 0 no representa
esta implementación. Android debe recompilarse cuando el equipo reanude la verificación.
iOS no se compiló desde este equipo Windows. No había un teléfono disponible.

## Integraciones y aceptación pendientes

- **A:** conectar `mediaCredentialsProvider` a su sesión real, esperar la purga antes de salir
  y acordar la sincronización/caché de referencias públicas. La identidad demo no sube fotos.
- **B:** asociar IDs a perfiles/reseñas/publicaciones, verificar dueño/estado y resolver
  moderación, visibilidad pública, bajas del padre y retención definitiva. `listo` sigue privado.
- **D:** incorporar el selector y los derivados autorizados en sus formularios definitivos.
- **Compartir:** disponer de un dominio y destino público autorizado para `PUBLIC_APP_URL`,
  asociaciones de enlaces y comprobación real de compartir/cancelar en Android/iOS.
- **Servicios:** configurar proyecto Firebase, R2, secretos, PowerSync y destinos de monitoreo;
  comprobar recepción, permisos mínimos, recuperación y cierre de sesión en dispositivos.
- **Infraestructura:** Docker no estaba disponible; no se construyeron/ejecutaron sus imágenes
  localmente. El workflow prepara esas comprobaciones; no se afirma que el CI remoto esté verde.
- **Cloud:** presupuesto, región, roles de base/migraciones, estado remoto y plan real con el equipo.
  No se ejecutaron `plan` contra cuentas reales, `apply` ni despliegues. No se crearon recursos cloud.

Firebase sigue en avisos; la autenticación por SMS pertenece a Identidad. Compartir por
WhatsApp se hace con el selector del teléfono, sin integración WhatsApp Business del servidor.

## Guías

- [Alcance e integración](../lote-c-media-infra/README.md)
- [Backend Media](../../../backend/src/modules/media/README.md)
- [Fotos en la app](../../../app/lib/features/media/README.md)
- [Compartir](../../../app/lib/features/compartir/README.md)
- [Almacenamiento local](../../../infra/media/README.md)
- [Monitoreo](../../../infra/observability/README.md)
- [Propuesta cloud](../../../infra/cloud/README.md)

La aprobación de Fase 0 y el visto bueno final del Lote C no se dan por cumplidos mediante
esta entrega de código. No se realizaron commits, publicación ni solicitudes de revisión remotas.

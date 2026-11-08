# Fase 1 · Lote C · Fotos, compartir e infraestructura

Alcance autorizado: sección 3.5, módulo Media y secciones 10–11 de la arquitectura; matriz del
plan de lotes. La aceptación de Fase 0 continúa pendiente y no se declara cumplida por este trabajo.

## Partes revisables

1. Contrato y backend Media: subida directa firmada, objetos privados, cuotas, validación real,
   procesamiento recuperable, miniatura, borrado EXIF/GPS y blurhash. Verificar API y PostgreSQL.
2. App: selección y saneamiento de fotos, borrador cifrado, cola recuperable, transferencias
   nativas, estados claros y componentes reutilizables. Verificar con dobles y compilar Android.
3. Compartir: selector del teléfono (incluido WhatsApp cuando esté disponible), solo contenido
   público confirmado; probar cancelación, privacidad y enlaces seguros.
4. Observabilidad: OpenTelemetry y Sentry opcionales, sin cuerpos, cabeceras, tokens, ubicaciones
   ni texto de vecinos. Verificar el filtrado y el arranque sin servicios externos.
5. Entornos: propuesta OpenTofu para dev/staging/prod, almacenamiento privado y ejecución en
   Google Cloud compatible con el ecosistema Firebase. Validar sin desplegar ni generar cargos.

## Integraciones

- A proporciona credenciales reales, limpia los borradores de la cuenta al cerrar sesión y conecta
  las referencias de archivos con su almacenamiento local. Ninguna sesión demo sube archivos.
- B vincula y modera fotos de perfiles/reseñas/publicaciones mediante la interfaz pública de Media.
  Un archivo procesado permanece privado; estar listo no lo publica ni lo aprueba automáticamente.
- D reutiliza el selector y la galería en sus pantallas. La selección de una foto no la publica.
- Firebase sigue siendo el canal de avisos. SMS pertenece a Identidad; compartir por WhatsApp se
  realiza desde el sistema del teléfono y no requiere enviar mensajes desde el servidor.

No se desplegarán recursos: proyecto cloud, dominios, credenciales y presupuesto deben quedar
acordados antes. iOS, recepción real y transferencias con suspensión requieren dispositivos.

## Entrega para revisión

Implementación y guías preparadas en `lote-c/fase-1-media-infra`. El detalle de lo entregado,
los resultados previos y las integraciones pendientes está en
[el informe de evidencias](../evidencias/lote-c.md).

Por indicación del usuario se suspendieron compilaciones y pruebas. Los últimos ajustes de
cierre de sesión y monitoreo no se volvieron a ejecutar; no se declara un APK nuevo verificado.
La galería está protegida por `ENABLE_PHOTOS`, que mantiene el valor predeterminado `false`.

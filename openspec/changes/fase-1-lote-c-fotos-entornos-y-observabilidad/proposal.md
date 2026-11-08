# Proposal

## Why

Las reseñas del piloto necesitan fotos que no filtren la ubicación de nadie, los vecinos tienen que
poder compartir un servicio por WhatsApp, y el piloto no puede correr en una laptop: hacen falta
entornos reproducibles, betas instalables y saber cuándo algo falla (secciones 3.4, 5.1, 6, 10 y 11
de la arquitectura). **Dueño: Lote C (por asignar) · Dificultad ★★ · El Lote A revisa e integra
cada entrega.**

## What Changes

- **Módulo Media en el backend:** `POST /v1/archivos` con URL firmada de subida, confirmación,
  trabajo que comprueba el tipo real, vuelve a borrar EXIF y GPS, genera variantes WebP y
  `blurhash`, y publica las variantes en la CDN solo cuando su contenido se publica.
- **Fotos en la app:** tomar o elegir, comprimir a unos 250 KB y borrar EXIF y GPS en el celular, y
  una cola persistente de subida con sus estados visibles, solo con Wi-Fi si el vecino lo elige.
- **Compartir y enlaces:** compartir servicios y publicaciones por WhatsApp con un enlace sin datos
  personales, enlaces profundos verificados (Android App Links e iOS Universal Links) y una página
  estática cuando la app no está instalada.
- **Entornos dev · staging · prod** con OpenTofu, despliegue continuo desde la CI, betas por
  TestFlight y las pruebas internas de Google Play, ingreso por SMS configurado para las betas,
  corrida de capacidad en staging y un simulacro de restauración.
- **Observabilidad:** OpenTelemetry en el backend, Sentry en el backend y en la app sin datos
  personales, y tableros de sincronización, operación y colas con alertas básicas.

Fuera de alcance: consola web y SMS de respaldo (Fase 2); WAF, más distritos y costos a escala
(Fase 3); moderación de contenido (Lote B de esta fase); pantallas de reseñas y del directorio
(Lote D de esta fase).

## Capabilities

### New Capabilities
- `media/archivos`: registro, subida firmada, procesamiento y publicación de imágenes.
- `app/fotos`: captura, limpieza y cola de subida de fotos en el celular.
- `app/compartir-y-enlaces`: compartir contenido público y abrir la app desde un enlace.
- `plataforma/entornos`: entornos reproducibles, despliegue continuo, betas y recuperación.
- `plataforma/observabilidad`: trazas, métricas, errores y alertas sin datos personales.

### Modified Capabilities

## Impact

- `backend/src/modules/media/` (hoy esqueleto), `contracts/openapi.yaml`, `backend/.env.example`.
- `app/lib/features/fotos/` y `app/lib/features/compartir/` (nuevos), `app/pubspec.yaml`
  (`image_picker`, `flutter_image_compress`, `background_downloader`, `share_plus`,
  `sentry_flutter`), configuración nativa de `app/android` y `app/ios`.
- `infra/tofu/` (nuevo), `infra/docker-compose.yml`, `infra/cdn/` y `.github/workflows/`.
- Secretos solo en el gestor de cada entorno y en GitHub Actions; nunca en el repositorio.
- Puntos de contacto: plantilla pública de fotos y `PendingPhotoPurger` del Lote A, `archivoId` y
  eventos de publicación del Lote B, componentes de foto y compartir para el Lote D.
- Decisiones que necesita el equipo antes de la parte 4: proveedor de la nube, presupuesto de la
  etapa micro (13.3.5), dominio, cuentas de Apple y Google Play, y Sentry.

# Proposal

## Why

Los vecinos del piloto, incluidas las personas mayores, tienen que poder buscar un servicio cercano,
ofrecer el suyo en 3 toques, reseñar con fotos, denunciar, abrir el directorio de emergencia sin
señal y controlar sus datos, todo con la misma accesibilidad de la Fase 0 (secciones 6, 7.4, 9.4 y
10 de la arquitectura). **Dueño: Lote D (por asignar) · Dificultad ★ · El Lote A revisa e integra
cada entrega.**

## What Changes

- **Directorio:** pantalla "Servicios cerca" con categorías grandes, búsqueda tolerante a tildes,
  lista con distancia, estrellas y "Visto Bueno de tu zona", filtro "Útil en emergencia" y acceso al
  mapa, también sin señal.
- **Perfil del proveedor y "Ofrezco un servicio"** en 3 toques desde el botón "+", con edición y
  retiro.
- **Reseñas con fotos, Visto Bueno y denuncias**, con mensajes claros para cada rechazo.
- **"Estoy en emergencia"** siempre visible, que abre el directorio de emergencia sin señal, con
  llamadas al 116, 105 y 106, y el tutorial actualizado.
- **Consentimiento, "Mis datos" y niveles:** consentimiento por finalidad al registrarse, ver y
  exportar mis datos, corregir mi nombre, borrar mi cuenta y "Cómo subir de nivel", con una prueba de
  usabilidad con 5 adultos mayores.

Fuera de alcance: tablero de emergencia, "Necesito ayuda" y contactos de emergencia (Fase 2);
quechua (Fase 3); repositorios reales, sincronización y limpieza del celular (Lote A); rutas del
backend (Lote B); componentes de fotos y compartir (Lote C).

## Capabilities

### New Capabilities
- `app/directorio`: buscar servicios cercanos, ver un proveedor y ofrecer un servicio.
- `app/resenas`: reseñar con fotos, dar Visto Bueno y denunciar contenido.
- `app/emergencia-basica`: botón "Estoy en emergencia" y directorio de emergencia sin señal.
- `app/privacidad`: consentimiento por finalidad, "Mis datos", borrado de la cuenta y niveles.

### Modified Capabilities

## Impact

- `app/lib/features/directorio/`, `reputacion/`, `emergencias/`, `onboarding/` y `cuenta/`
  (pantallas en `presentation/`), `app/lib/core/router/`, `app/lib/l10n/app_es.arb` y `app/test/`.
- `app/pubspec.yaml`: `url_launcher` para las llamadas.
- Usa los puertos y dobles del Lote A, el contrato y los códigos de error del Lote B, y
  `PhotoPicker` y el botón compartir del Lote C.
- `docs/fase-1/evidencias/usabilidad.md` (sin datos personales).

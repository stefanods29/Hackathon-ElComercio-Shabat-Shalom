# Funcionalidad `reputacion`

Reseñas con fotos, Visto Bueno Vecinal y denuncias.

**Cuándo y quién:** Fase 1. Datos y repositorios: Lote A (parte 1). Pantallas: Lote D (parte 3).

```text
reputacion/
├── domain/   # Review, ReviewPhoto, Endorsement, NewReview, NewReport, puerto
│             # ReputationRepository y casos de uso (WriteReview, ReportContent)
├── data/     # doble en memoria, repositorio sobre PowerSync y proveedores de Riverpod
└── presentation/  # pantallas del Lote D
```

- Las reseñas publicadas de otros vecinos no dicen quién las escribió; las propias llegan por
  `mis_resenas` en cualquier estado ("En revisión", publicada u oculta).
- La URL de una foto se arma con `ReviewPhoto.urlFor(cdnBaseUrl)`: `<CDN>/media/<archivoId>/<variante>.webp`
  (plantilla pública del Lote C). No viajan URLs firmadas.
- Nadie se reseña ni se da Visto Bueno a sí mismo, y una reseña por vecino y servicio: el celular
  lo comprueba antes de encolar y el servidor decide al final.

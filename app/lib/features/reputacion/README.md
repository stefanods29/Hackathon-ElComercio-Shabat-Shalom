# Funcionalidad `reputacion`

Visto Bueno Vecinal y reseñas con fotos.

**Cuándo y quién:** Fase 1.

Estructura (igual que `features/solidaridad`, la implementación de referencia):

```text
reputacion/
├── domain/        # entidades, casos de uso e interfaces de repositorio (Dart puro)
├── data/          # repositorios (base local, cliente de la API) y sus proveedores Riverpod
└── presentation/  # pantallas, widgets y ViewModels (sin lógica de negocio en los widgets)
```

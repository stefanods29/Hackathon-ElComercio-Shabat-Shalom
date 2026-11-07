# Funcionalidad `onboarding`

Tutorial interactivo sobre la pantalla real y "modo práctica".

**Cuándo y quién:** Fase 0 · **Lote D**.

Estructura (igual que `features/solidaridad`, la implementación de referencia):

```text
onboarding/
├── domain/        # entidades, casos de uso e interfaces de repositorio (Dart puro)
├── data/          # repositorios (base local, cliente de la API) y sus proveedores Riverpod
└── presentation/  # pantallas, widgets y ViewModels (sin lógica de negocio en los widgets)
```

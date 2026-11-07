# Funcionalidad `operacion`

Modo operativo para coordinadores y brigadistas (bloqueo con PIN o biometría).

**Cuándo y quién:** Fase 2.

Estructura (igual que `features/solidaridad`, la implementación de referencia):

```text
operacion/
├── domain/        # entidades, casos de uso e interfaces de repositorio (Dart puro)
├── data/          # repositorios (base local, cliente de la API) y sus proveedores Riverpod
└── presentation/  # pantallas, widgets y ViewModels (sin lógica de negocio en los widgets)
```

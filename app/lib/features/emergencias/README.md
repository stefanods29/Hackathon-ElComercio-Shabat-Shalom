# Funcionalidad `emergencias`

Pedidos de ayuda con estados, tablero, recursos y grupos de apoyo. En la Fase 0 el **Lote A** valida aquí los datos sensibles bajo demanda y su purga.

**Cuándo y quién:** Fase 0 (Lote A, validación) · Fase 2 (completo).

Estructura (igual que `features/solidaridad`, la implementación de referencia):

```text
emergencias/
├── domain/        # entidades, casos de uso e interfaces de repositorio (Dart puro)
├── data/          # repositorios (base local, cliente de la API) y sus proveedores Riverpod
└── presentation/  # pantallas, widgets y ViewModels (sin lógica de negocio en los widgets)
```

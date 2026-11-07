# Funcionalidad `mapa`

Mapa con MapLibre y descarga de la región del distrito para usar sin conexión.

**Cuándo y quién:** Fase 0 · **Lote C**.

Estructura (igual que `features/solidaridad`, la implementación de referencia):

```text
mapa/
├── domain/        # entidades, casos de uso e interfaces de repositorio (Dart puro)
├── data/          # repositorios (base local, cliente de la API) y sus proveedores Riverpod
└── presentation/  # pantallas, widgets y ViewModels (sin lógica de negocio en los widgets)
```

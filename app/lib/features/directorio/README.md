# Funcionalidad `directorio`

Oficios y profesiones de la zona: categorías, servicios y perfiles de proveedor.

**Cuándo y quién:** Fase 1. Datos y repositorios: Lote A (parte 1). Pantallas: Lote D (partes 1 y 2).

```text
directorio/
├── domain/   # Category, Service, ProviderProfile, ServiceDraft, ServiceQuery, búsqueda sin
│             # tildes (search.dart), puerto ServiceDirectoryRepository y casos de uso
├── data/     # doble en memoria, repositorio sobre PowerSync y proveedores de Riverpod
└── presentation/  # pantallas del Lote D
```

- Las pantallas leen `serviceDirectoryRepositoryProvider` o los proveedores derivados
  (`categoriesProvider`, `servicesProvider`, `serviceProvider`, `providerProfileProvider`).
  `AuthenticatedApp` sobreescribe `syncedServiceDirectoryRepositoryProvider` con la versión de
  PowerSync; en modo práctica siempre se usa el doble en memoria.
- La ubicación de un servicio en el celular es la copia pública (ADR 0010). La exacta solo viaja a
  la API dentro del comando que publica o edita el servicio.
- Publicar, editar y retirar son comandos de la cola (`publishService`, `updateService` y
  `withdrawService`) con su `Idempotency-Key`; su capa optimista vive en `envios.optimista` hasta
  la respuesta definitiva del servidor.

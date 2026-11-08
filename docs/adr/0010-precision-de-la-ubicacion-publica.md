# 0010 · Precisión de la ubicación en los datos públicos

**Estado:** propuesto el 7 de noviembre de 2026; se aprueba en la revisión de la parte 1 del Lote A
de la Fase 1.
**Dueño:** Lote A · Parte 1, con el Lote B (copia pública de los servicios).
**Alcance:** sección 8.1 de la arquitectura, `sincronizacion/datos-publicos` y
`solidaridad/muro-de-favores` de OpenSpec.

## Contexto

La sección 8.1 de la arquitectura prohíbe que un dato público lleve la ubicación exacta de una
persona. La revisión del 7 de noviembre (observación 5 del Lote B) dejó para la Fase 1 cómo
cumplirlo, porque el muro y el directorio necesitan ubicaciones para mostrar "cerca de ti" y el
mapa:

- El muro ya redondea la ubicación de cada publicación a 3 decimales en el dominio
  (`approximate()` en `backend/src/modules/solidaridad/domain/post.ts`) y nunca guarda la exacta.
- Un servicio del directorio necesita la ubicación exacta para buscar por radio con PostGIS, y a
  veces es la casa del proveedor.
- Un proveedor con local a la calle quiere que lo encuentren en su puerta.

## Opciones

1. **Redondear a 3 decimales** (unos 110 m en Lima) la copia pública y guardar la exacta solo
   donde haga falta buscar. Es simple, ya lo usa el muro y se prueba con un número.
2. **Celdas H3 o geohash** en los datos públicos. Exige funciones o tablas nuevas en PostgreSQL y en
   el celular para un resultado práctico parecido en un barrio.
3. **Desplazamiento aleatorio** de cada punto. Repetido en el tiempo, el promedio revela el punto
   real.

## Decisión

Se adopta la opción 1:

- La **copia pública** de una ubicación se redondea a 3 decimales. Es la única que viaja en los
  Sync Streams, en las respuestas públicas de la API y en los avisos.
- **Muro:** se mantiene el redondeo del dominio. No se guarda la ubicación exacta de una
  publicación.
- **Directorio:** `directorio.servicios` guarda la ubicación exacta en `ubicacion` (privada, solo
  para buscar por radio) y la copia pública en `lat_publica` y `lng_publica`.
- **Local a la calle:** si el proveedor acepta de forma explícita mostrar su local
  (`muestra_ubicacion_exacta`), la copia pública es la exacta. Es su decisión, se puede retirar y
  nunca se activa por defecto.
- La distancia que devuelve una búsqueda se redondea a múltiplos de 50 m y la API no guarda el
  punto desde el que se busca.

## Consecuencias

- Ningún stream automático selecciona `ubicacion`; las pruebas de acceso de los Sync Streams
  (`backend/test/sync/datos-publicos.spec.ts`) fallan si alguien lo intenta.
- El muro no necesita una migración de datos. Se comprobó que la semilla
  (`backend/scripts/seed-data.ts`) no crea publicaciones y que la única escritura en
  `solidaridad.publicaciones` es la del repositorio del dominio, que redondea desde los cimientos.
- En una zona con pocas viviendas, 110 m pueden seguir apuntando a una sola casa. Para el piloto
  en Lince se acepta; al sumar zonas rurales (Fase 3) se revisa con celdas más grandes.
- El consentimiento de `muestra_ubicacion_exacta` se registra con los demás consentimientos del
  Lote B (parte 4).

## Verificación

- Pruebas de dominio del redondeo en el muro (existentes) y en el directorio (Lote B, parte 1).
- Pruebas de acceso de los Sync Streams del Lote A (parte 1).

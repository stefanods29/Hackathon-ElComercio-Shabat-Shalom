# Tasks

## 1. Parte 1 · Directorio: categorías, proveedores y servicios

- [ ] 1.1 Contrato de `GET /v1/categorias`, `PUT /v1/yo/proveedor`, `POST`, `PUT` y `DELETE /v1/servicios` y `GET /v1/proveedores/{id}` en `contracts/openapi.yaml`, en un commit propio; verificar con `npx @redocly/cli lint contracts/openapi.yaml`
- [ ] 1.2 Migraciones del esquema `directorio` (categorías sembradas, proveedores y servicios con ubicación privada, copia pública, agregados, versión y borrado), agregadas a la publicación `powersync` con `SELECT` para `powersync_rol`; verificar con `npm run test:integration` (las migraciones aplican y revierten)
- [ ] 1.3 Dominio `Service` y `ProviderProfile` (dueño, versión, borrado, copia pública con el redondeo del ADR 0010) y casos de uso con puertos; verificar con pruebas unitarias
- [ ] 1.4 Adaptadores Kysely y en memoria, controladores y esquemas Zod con `@Idempotent()` y `@RequireTrustLevel(1)`; verificar con pruebas de integración (201/200, 401, 403, 409 `conflicto_de_version`, 409 `id_en_uso`, retiro idempotente, perfil sin datos de contacto)
- [ ] 1.5 Manejador de `identidad.zona_cambiada` que retira los servicios del proveedor en la zona anterior (cuando exista el evento de la parte 4) y semilla de servicios de demostración; verificar con una prueba con `InMemoryJobQueue`
- [ ] 1.6 Compilar y depurar: `npm run verify`, `npm run test:integration`, `npm run graph`, Redocly y CI en verde

## 2. Parte 2 · Búsqueda por cercanía y texto

- [ ] 2.1 Contrato de `GET /v1/servicios` con sus filtros, cursor y `distanciaMetros`; verificar con Redocly
- [ ] 2.2 Función `directorio.sin_tildes` (`unaccent` `IMMUTABLE`), columna `busqueda`, índice de trigramas y consulta con `ST_DWithin`, orden por Visto Bueno de la zona y puntaje, y cursor; verificar con pruebas de integración con datos sembrados (radio, categoría, emergencia, "gásfiter" con y sin tildes, cursor estable)
- [ ] 2.3 Redondeo de `distanciaMetros` a 50 m sin guardar el punto de búsqueda; verificar con una prueba
- [ ] 2.4 `EXPLAIN` de la consulta que muestra el uso de los índices; registrarlo en `docs/fase-1/evidencias/busqueda.md`
- [ ] 2.5 Compilar y depurar: `npm run verify`, `npm run test:integration` y CI en verde

## 3. Parte 3 · Reseñas, Visto Bueno y ranking

- [ ] 3.1 Contrato de `POST /v1/resenas` y de `POST` y `DELETE /v1/servicios/{id}/visto-bueno`, con sus códigos de error; verificar con Redocly
- [ ] 3.2 Migraciones del esquema `reputacion` (reseñas, fotos y Visto Bueno con `id`), agregadas a la publicación `powersync`; verificar con `npm run test:integration`
- [ ] 3.3 Dominio y casos de uso: reseña en revisión con su evento en la misma transacción, una por vecino y servicio, nadie se reseña a sí mismo, solo servicios de la zona, fotos del autor por `media/index.ts` (doble hasta C1), antigüedad mínima y límite diario; verificar con pruebas unitarias de cada regla
- [ ] 3.4 Visto Bueno idempotente que solo cuenta desde el nivel 2; verificar con pruebas de integración
- [ ] 3.5 Trabajo de recálculo desde los hechos (`reputacion.agregados_recalculados`) y manejador de `directorio` con el puntaje bayesiano; verificar con una prueba de reintento sin descuadre y una que compara el puntaje con el cálculo a mano
- [ ] 3.6 Detección de patrones dudosos (muchas reseñas desde el mismo dispositivo) que crea un caso de moderación; verificar con una prueba
- [ ] 3.7 Compilar y depurar: `npm run verify`, `npm run test:integration`, `npm run graph` y CI en verde

## 4. Parte 4 · Identidad del piloto: niveles, zona y privacidad

- [ ] 4.1 `docs/adr/0011-confirmacion-de-residencia.md` (presencia sin coordenadas, 3 días en 14, confirmación manual, avales) y su entrada en el índice; verificar con la revisión del equipo
- [ ] 4.2 Contrato de zona, presencia, confirmación manual, avales, consentimientos, `GET /v1/yo/datos`, `PATCH /v1/yo` y `DELETE /v1/yo`; verificar con Redocly
- [ ] 4.3 Migraciones de `identidad` (consentimientos, presencias, avales, confirmaciones, `zona_elegida_en`, `eliminado_en`); verificar con `npm run test:integration`
- [ ] 4.4 Cambio de zona cada 30 días con nivel 0 y evento `identidad.zona_cambiada`; verificar con pruebas de integración (cambio, 409 `cambio_de_zona_muy_pronto`, misma zona)
- [ ] 4.5 Nivel 1 por presencia (con consentimiento) o confirmación manual y nivel 2 por avales; verificar con pruebas de integración, incluida la que confirma que sin consentimiento no se trata la presencia
- [ ] 4.6 Consentimientos por finalidad y versión, exportación con `PersonalDataRegistry`, rectificación y oposición; verificar con pruebas de integración
- [ ] 4.7 `DELETE /v1/yo`: revoca sesiones, responde 202 y un trabajo borra o anonimiza los datos en cada módulo; verificar con una prueba que no encuentra el teléfono ni el nombre en ninguna tabla
- [ ] 4.8 Compilar y depurar: `npm run verify`, `npm run test:integration`, `npm run graph` y CI en verde

## 5. Parte 5 · Moderación

- [ ] 5.1 Contrato de `POST /v1/denuncias`, `GET /v1/moderacion/casos` y `POST /v1/moderacion/casos/{id}/decision`; verificar con Redocly
- [ ] 5.2 Migraciones del esquema `moderacion` y columna `solidaridad.publicaciones.oculta_en` (excluida de `GET /v1/publicaciones`); verificar con `npm run test:integration`
- [ ] 5.3 Denuncias idempotentes y cadena de filtros (texto, imagen con un puerto que implementa C, reputación del autor y revisión humana); verificar con pruebas unitarias
- [ ] 5.4 Cola de casos y decisiones con motivo y auditoría, eventos `moderacion.contenido_ocultado` y `contenido_restaurado`, manejadores en cada módulo dueño y publicación de reseñas en revisión con recálculo del ranking; verificar con una prueba de punta a punta (denuncia, caso, decisión, contenido oculto)
- [ ] 5.5 Sanciones con `isSuspended` y métrica del tiempo hasta la primera revisión (p90) para administradores; verificar con pruebas de integración y permisos del rol
- [ ] 5.6 Compilar y depurar: `npm run verify`, `npm run test:integration`, `npm run graph`, `openspec validate --all --strict` y CI en verde

## Workflow follow-up

- Entregar cada parte en su rama `f1-lote-b/parte-<n>-<tema>` y pedir la revisión del Lote A.
- Archivar el change cuando el Lote A integre la última parte y la CI esté en verde.

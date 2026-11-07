# 0007 · Código en inglés; contrato, datos y textos en español

**Contexto.** Las reglas del equipo piden nombres de variables y funciones en inglés y textos de
la interfaz en español; la arquitectura fija en español el esquema, la API y el contrato.

**Decisión.** En inglés: clases, funciones, variables, archivos, variables de entorno y scripts
(`npm run verify`). En español: rutas (`/v1/publicaciones`), campos JSON (`venceEn`), códigos de
error (`favor_no_disponible`), valores del dominio (`abierta`, `presto`), tablas y columnas,
carpetas de módulos (`identidad`, `solidaridad`), textos de la app y documentación.

**Consecuencias.** Los adaptadores traducen entre ambos mundos (por ejemplo, `toPostDto`).

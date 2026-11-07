# Lote D · Pantallas del piloto (Fase 1)

| Dato | Valor |
|---|---|
| Dificultad | ★ La más accesible para empezar |
| Área | `app/lib/features/directorio/`, `reputacion/`, `emergencias/`, `onboarding/`, `cuenta/`, `app/lib/l10n/app_es.arb`, `app/test/` |
| Change de OpenSpec | `fase-1-lote-d-pantallas-del-piloto` (se crea al abrir la fase) |
| Partes | 5. Todas pueden empezar con repositorios en memoria |
| Depende de | Contratos de B, repositorios de A, fotos y compartir de C |

## Estado del lote

| Parte | Qué entrega | Estado | Responsable | PR |
|---|---|---|---|---|
| 1 | Directorio: buscar servicios cerca | Pendiente | Por asignar | — |
| 2 | Perfil del proveedor y "Ofrezco un servicio" | Pendiente | Por asignar | — |
| 3 | Reseñas con fotos, Visto Bueno y denuncias | Pendiente | Por asignar | — |
| 4 | "Estoy en emergencia" y tutorial actualizado | Pendiente | Por asignar | — |
| 5 | Consentimiento, "Mis datos" y niveles | Pendiente | Por asignar | — |

Estados posibles: **Pendiente**, **En curso** o **Hecha** (integrada en `main`).

---

## 0. Antes de empezar

### 0.1 Reglas

Las de la Fase 0 ([`../../fase-0/lote-d-experiencia-accesible/README.md`](../../fase-0/lote-d-experiencia-accesible/README.md))
y las [reglas comunes de la fase](../README.md#reglas-para-todos-los-lotes). En resumen: meta
WCAG 2.2 AA, botones de al menos 48 dp, íconos siempre con texto, lenguaje simple, textos en
`app_es.arb` y cada acción con su estado ("Guardado en tu celular", "Enviado" o "No se pudo
completar").

### 0.2 Lo que ya existe

- Sistema de diseño accesible, modo sencillo, publicar en 3 toques, estados visibles, "acciones
  por revisar", tutorial con modo práctica, e inicio de sesión, zona y cuenta (Fase 0, Lote D).
- Patrón de pantalla: `app/lib/features/solidaridad/` (`domain/` en Dart puro, `data/` con
  repositorios y proveedores de Riverpod, `presentation/` sin lógica de negocio).
- Mapa sin conexión del Lote C de la Fase 0 para mostrar ubicaciones.

Cada pantalla nueva empieza con un repositorio en memoria (`data/in_memory_…`). El Lote A lo
reemplaza por el de PowerSync sobreescribiendo el proveedor, sin tocar la pantalla.

---

## Parte 1 · Directorio: buscar servicios cerca

- Pantalla "Servicios cerca": categorías grandes con ícono y texto, búsqueda que tolera tildes y
  errores, y una lista con distancia, estrellas y "Visto Bueno de tu zona".
- Filtro "Útil en emergencia" y acceso al mapa.
- Sin señal muestra lo descargado con "Actualizado hace X" y un estado vacío que explica qué hacer.

Pruebas: widgets con texto grande (golden tests al 200 %), lector de pantalla con etiquetas
completas y búsqueda con datos en memoria.

## Parte 2 · Perfil del proveedor y "Ofrezco un servicio"

- Perfil: servicios, resumen de reseñas, Visto Bueno y botón compartir (C, parte 3).
- "Ofrezco un servicio" desde el botón "+" en 3 toques: **(1)** "+" → **(2)** "Ofrezco" → **(3)**
  formulario mínimo prellenado (categoría y ubicación sugeridas) y "Publicar".
- Editar y retirar un servicio, mostrando el motivo si el servidor rechaza el cambio (por ejemplo,
  `version_desactualizada`).

Pruebas: el flujo de 3 toques con una prueba de widget que cuente los toques, y el estado
"Guardado en tu celular" sin señal.

## Parte 3 · Reseñas con fotos, Visto Bueno y denuncias

- Escribir una reseña: estrellas grandes, comentario opcional con dictado por voz y hasta 3 fotos
  (componente de C, parte 2). Quien la escribe ve "En revisión" hasta que se publica.
- Botón Visto Bueno con su estado y una explicación simple de para qué sirve.
- "Denunciar" en publicaciones, reseñas, servicios y fotos: motivo de una lista y confirmación
  "Gracias, lo revisaremos".
- Mensajes claros para `resena_duplicada`, `no_puedes_resenarte` y el límite diario.

Pruebas: widgets de cada estado y de cada error, y accesibilidad de las estrellas con el lector de
pantalla.

## Parte 4 · "Estoy en emergencia" y tutorial actualizado

- Botón "Estoy en emergencia" siempre visible en el inicio que funciona sin señal. Abre el
  directorio de emergencia del Lote A (parte 2): números con botón para llamar (`url_launcher`),
  puntos de encuentro en el mapa offline, centros de salud y albergues, cada uno con su fuente y su
  fecha.
- Mensajes de la sección 9.4: "Esta app conecta vecinos; no reemplaza a los servicios de
  emergencia" y "Si hay riesgo para la vida, llama al 116, 105 o 106".
- Tutorial y modo práctica actualizados para las pantallas nuevas. El contenido viene de un JSON
  en la CDN, con una copia dentro de la app (sección 6).

Pruebas: en modo avión, el botón abre el directorio con la copia de respaldo; prueba de widget del
botón de llamar.

## Parte 5 · Consentimiento, "Mis datos" y niveles

- Consentimiento al registrarse, con la finalidad en lenguaje simple. Cada finalidad se puede
  aceptar o rechazar por separado (por ejemplo, la confirmación de residencia por presencia).
- "Mis datos" en la cuenta: ver y exportar mis datos, corregir mi nombre visible y borrar mi cuenta
  con una confirmación clara de lo que se borra (rutas de B, parte 4).
- "Cómo subir de nivel": qué permite cada nivel y cómo se confirma la residencia.
- **Prueba de usabilidad** con al menos 5 adultos mayores: buscar un servicio, reseñarlo y abrir el
  directorio de emergencia. El resultado va en `evidencias/usabilidad.md`, sin datos personales.

Pruebas: widgets de cada pantalla y del flujo de borrado; revisión de contraste y de tamaños táctiles.

---

## Puntos de contacto con otros lotes

- **A:** repositorios sobre PowerSync que reemplazan a los de memoria, y directorio de emergencia.
- **B:** contrato y códigos de error de cada ruta.
- **C:** componentes de fotos y de compartir.

## Fuera de alcance

Tablero de emergencia, "Necesito ayuda" y contactos de emergencia (Fase 2); quechua (Fase 3).

## Definición de terminado del lote

Las 5 partes aprobadas e integradas, las pruebas de accesibilidad en verde y la evidencia de
usabilidad lista para los criterios de salida.

# Lote D · Tablero de emergencia (Fase 2)

| Dato | Valor |
|---|---|
| Dificultad | ★ La más accesible para empezar |
| Área | `app/lib/features/emergencias/`, `app/lib/core/router/`, `app/lib/l10n/app_es.arb`, `app/test/` |
| Change de OpenSpec | `fase-2-lote-d-tablero-de-emergencia` (se crea al abrir la fase) |
| Partes | 4. Todas pueden empezar con repositorios en memoria |
| Depende de | Repositorios de A y contrato de B |

## Estado del lote

| Parte | Qué entrega | Estado | Responsable | PR |
|---|---|---|---|---|
| 1 | Inicio en modo emergencia | En curso | stefanods29 | — |
| 2 | "Necesito ayuda" y el estado de mi pedido | En curso | stefanods29 | — |
| 3 | "Puedo ayudar" y recursos | En curso | stefanods29 | — |
| 4 | Contactos de emergencia y accesibilidad | En curso | stefanods29 | — |

Estados posibles: **Pendiente**, **En curso** o **Hecha** (integrada en `main`).

### Entrega de código · 7 de noviembre de 2026

Desarrollo en la rama `f2-lote-d/tablero-de-emergencia`, sobre las pantallas del piloto
de Fase 1. Los repositorios operativos de Fase 2 todavía requieren integración con los
Lotes A y B. La cuenta real debe mostrar esa falta de disponibilidad; los datos de
práctica permanecen separados y no representan pedidos recibidos ni ayuda asignada.

Por indicación del responsable, esta entrega se realiza sin crear ni ejecutar pruebas,
análisis, compilaciones, CI o simulacros. La accesibilidad se contempla en el código,
pero su validación y el ejercicio con vecinos quedan pendientes. Estos límites no
cambian los criterios de finalización descritos al final del documento.

Los puertos, las reglas de aislamiento y los pendientes externos se describen en
[Integración del tablero](integracion.md).

---

## 0. Antes de empezar

Valen las reglas de las fases anteriores y las [reglas comunes de esta fase](../README.md#reglas-para-todos-los-lotes).
Estas pantallas se usan con miedo, prisa o poca batería: textos muy cortos, botones grandes y nada
que dependa de la red para mostrarse.

---

## Parte 1 · Inicio en modo emergencia

- Si la zona tiene un evento activo, el inicio pasa a ser el tablero: **Necesito ayuda** ·
  **Puedo ayudar** · **Recursos** · **Directorio de emergencia** (sección 7.1).
- Ahorro de datos (imágenes desactivadas por defecto) y directorio de servicios filtrado por
  `disponible_en_emergencia`.
- En una zona sin cobertura operativa: directorio de emergencia, números oficiales y la explicación
  de que en esa zona todavía no hay coordinación vecinal.

## Parte 2 · "Necesito ayuda" y el estado de mi pedido

- En 3 toques: **(1)** "Necesito ayuda" → **(2)** tipo de necesidad → **(3)** formulario mínimo con
  la ubicación aproximada sugerida y dictado por voz opcional, y "Enviar".
- Estados de la sección 7.2 con sus mensajes: "Tu pedido todavía no fue enviado. Nadie lo ha
  recibido." mientras está en el celular; hora de envío y tiempo sin revisar; "En camino" sin datos
  de quien ayuda.
- Siempre visibles: "Si hay riesgo para la vida, llama al 116, 105 o 106", un SMS a mis contactos
  de emergencia con el texto y la ubicación aproximada ya escritos, y la ruta al punto de encuentro
  en el mapa offline (sección 7.4).

## Parte 3 · "Puedo ayudar" y recursos

- Ofrecer ayuda (habilidades o recursos) a la zona.
- Lista de recursos críticos con "reportado hace X" y la marca de posiblemente desactualizado;
  reportar un recurso con su estado (*sin verificar*, *confirmado por N vecinos* o *verificado*).
- Insignia en las fuentes oficiales.

## Parte 4 · Contactos de emergencia y accesibilidad

- Contactos de emergencia propios (clase personal): se guardan cifrados en el celular y nunca
  llegan a otros.
- Revisión de accesibilidad de todo el modo emergencia: orden del lector de pantalla, texto grande,
  modo sencillo y alto contraste.
- Prueba con vecinos durante el simulacro para el criterio "quien pide ayuda entiende qué pasa".

Pruebas de todo el lote: widgets de cada estado y de cada mensaje, flujo de 3 toques contado en una
prueba, golden tests al 200 % y pruebas en modo avión.

---

## Fuera de alcance

Consola web (Lote C) y quechua (Fase 3).

## Definición de terminado del lote

Las 4 partes aprobadas e integradas, las pruebas de accesibilidad en verde y la prueba con vecinos
registrada en `evidencias/simulacro.md`.

# Lote A · Sincronización a escala (Fase 3)

| Dato | Valor |
|---|---|
| Dificultad | ★★★★ Alta (integra cada etapa) |
| Área | `infra/powersync/`, `app/lib/core/sync/`, `backend/test/load/`, `infra/tofu/` |
| Change de OpenSpec | `fase-3-lote-a-sincronizacion-a-escala` (se crea al abrir la fase) |
| Partes | 4. Cada una se activa con su señal (ver el [plan](../plan-de-lotes.md#cuándo-se-activa-cada-parte)) |

## Estado del lote

| Parte | Qué entrega | Estado | Responsable | PR |
|---|---|---|---|---|
| 1 | Sincronización a escala | Pendiente | Stefano | — |
| 2 | Varias zonas por persona | Pendiente | Stefano | — |
| 3 | I+D: malla entre celulares | Pendiente | Stefano | — |
| 4 | Integración de cada etapa | Pendiente | Stefano | — |

Estados posibles: **Pendiente**, **En curso** o **Hecha** (integrada en `main`).

---

## Parte 1 · Sincronización a escala

- Prueba de carga del servicio de sync con miles de reconexiones simultáneas, además de las
  ~2 500 peticiones por segundo de la API (la prueba de k6 de la Fase 0 sumada a un simulador de
  clientes de PowerSync).
- Ajustes según lo medido: tamaño y prioridad de los streams, datos críticos primero en modo
  emergencia, límites por cliente y decisión entre PowerSync en la nube o auto-hospedado (ADR).
- Tablero de la sincronización a escala: clientes conectados, retraso de replicación y tiempo
  hasta "Enviado".

**Terminado cuando:** la meta "aguanta el pico de emergencia" tiene evidencia.

## Parte 2 · Varias zonas por persona

- Vecinos en el límite entre zonas y zonas que se dividen: qué streams recibe cada uno y cómo se
  migran los datos locales sin perder la cola de subida.
- En modo emergencia, los agregados públicos de las zonas vecinas, para el escalamiento a la zona
  vecina (Fase 2).

**Terminado cuando:** dividir una zona de prueba no pierde datos ni envíos, y está comprobado en
celulares reales.

## Parte 3 · I+D: malla entre celulares

- Prototipo de alertas sin internet con Nearby Connections (Android) y Multipeer Connectivity
  (iOS), según la sección 7.7. Solo información pública: nunca datos sensibles por la malla.
- Informe con el alcance medido, la batería consumida, los riesgos y una recomendación de seguir
  o no.

**Terminado cuando:** el informe está en `evidencias/malla.md` y el equipo decidió.

## Parte 4 · Integración de cada etapa

Integrar las partes aprobadas de B, C y D de la etapa, correr las metas de
[`criterios-de-salida.md`](../criterios-de-salida.md) y mantener el CI en verde.

## Fuera de alcance

Funciones nuevas del producto: esta fase escala lo que ya existe.

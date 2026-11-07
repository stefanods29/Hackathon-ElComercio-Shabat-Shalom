# Hoja de ruta · Las cuatro fases

El orden de construcción viene de la sección 12 de la arquitectura. Las fases no tienen fechas:
una fase empieza cuando la anterior cumple su condición de salida. Cada fase se divide en cuatro
lotes con la misma lógica:

- **Lote A:** offline, seguridad e integración. Es el más difícil, lo lleva Stefano e integra la
  fase.
- **Lote B:** backend.
- **Lote C:** mapas, medios, avisos e infraestructura.
- **Lote D:** experiencia, que es el más sencillo.

| Fase | Qué se construye | Condición para pasar a la siguiente | Estado | Carpeta |
|---|---|---|---|---|
| **0 · Prueba técnica** | Esqueleto con todo el stack, flujo offline completo, cifrado y purga, mapas offline, avisos | Los supuestos de la sección 13.1 tienen evidencia | **En curso** | [`fase-0/`](fase-0/README.md) |
| **1 · Piloto en un barrio** | Directorio con Visto Bueno, reseñas con fotos, moderación, directorio de emergencia offline, consentimiento y entornos reales | Uso real sostenido, moderación funcionando y métricas de sincronización sanas | Pendiente | [`fase-1/`](fase-1/README.md) |
| **2 · Emergencias con operación** | Pedidos de ayuda con estados, tablero humanitario, recursos críticos, roles operativos, consola web y alianzas | Cobertura operativa en la zona y un simulacro con los aliados | Pendiente | [`fase-2/`](fase-2/README.md) |
| **3 · Escala** | Más zonas y distritos, quechua, Valkey + BullMQ, réplicas de lectura y extracción de servicios según métricas | Por etapas (micro, ciudad, país), cada una con sus metas | Pendiente | [`fase-3/`](fase-3/README.md) |

## Cómo se abre una fase

1. La fase anterior cumple sus criterios de salida, o el equipo acepta por escrito los riesgos
   que quedan (se anotan en el `criterios-de-salida.md` de esa fase).
2. Se asignan responsables a los lotes en el README de la fase nueva.
3. El Lote A crea un change de OpenSpec por lote a partir de su guía (`/opsx:propose`, con el
   nombre que indica la guía) y comprueba `openspec validate --all --strict`.
4. Se abre un issue por lote en GitHub y la fase pasa a **En curso** en esta tabla.
5. Cada parte se entrega y se revisa como dice
   [`fase-0/revision-y-entregas.md`](fase-0/revision-y-entregas.md), que vale para todas las
   fases. Las ramas se llaman `f<fase>-lote-<letra>/parte-<n>-<tema>`, por ejemplo
   `f1-lote-b/parte-2-busqueda`.
6. Para cerrar la fase se archivan sus changes (`openspec archive <change>`) y se guarda cada
   evidencia en `fase-<n>/evidencias/`.

Hasta que una fase se abre, sus guías son el plan: dicen qué entrega cada parte, cómo se prueba y
cuándo está terminada. Si al abrirla algo cambió, la guía se actualiza en el mismo PR que crea los
changes.

## Decisiones abiertas (sección 13.3) y en qué fase se cierran

| Decisión | Se cierra en | Quién la impulsa |
|---|---|---|
| Fuente de los mapas offline | Fase 0 | Lote C (ADR de la parte 1) |
| Proveedor de OTP y SMS, y presupuesto de SMS de respaldo | Fase 0 (OTP) y Fase 2 (SMS) | Lote B (tarea 1.4) y Lote C de la Fase 2 |
| Flujos del piloto y barrio | Al abrir la Fase 1 | Todo el equipo |
| Precisión de la ubicación en los datos públicos | Fase 1 | Lote A (parte 1) |
| Mecanismo para confirmar la residencia (nivel 1) | Fase 1 | Lote B (parte 4) |
| Presupuesto de infraestructura por etapa | Fase 1 (micro) y Fase 3 (ciudad y país) | Todo el equipo, con el Lote C |
| Aliados y roles operativos | Al abrir la Fase 2 | Todo el equipo |
| Umbrales de caducidad y tiempos de respuesta definitivos | Fase 2, con los aliados | Todo el equipo, con la propuesta del Lote A |

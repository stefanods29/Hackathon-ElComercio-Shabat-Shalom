# Lote C · Consola web y avisos urgentes (Fase 2)

| Dato | Valor |
|---|---|
| Dificultad | ★★ Media |
| Área | `consola/` (nuevo, en la raíz del monorepo), `backend/src/modules/notificaciones/`, `backend/src/modules/curaduria/` (nuevo), `infra/cloud/modules/console-site/` (nuevo), `.github/workflows/` |
| Change de OpenSpec | [`fase-2-lote-c-consola-web-y-avisos-urgentes`](../../../openspec/changes/fase-2-lote-c-consola-web-y-avisos-urgentes/) |
| Integración | [`integracion.md`](integracion.md): qué falta de B y cómo compilar y probar |
| Partes | 4. La 1 va primero; la 4 puede avanzar en paralelo |
| Depende de | Contrato del módulo Emergencias (B, partes 1–3) |

## Estado del lote

| Parte | Qué entrega | Estado | Responsable | PR |
|---|---|---|---|---|
| 1 | Base de la consola web | En curso: integrada; analiza y compila; flujo de CI creado, falta verlo en verde | stefanods29 | — |
| 2 | Cola de casos y asignación | En curso: conectada a B y probada contra la API real; faltan las pruebas de widgets | stefanods29 | — |
| 3 | Mapa de celdas, turnos y curaduría | En curso: integrada; celdas y turnos conectados a B; falta el adaptador de la nube | stefanods29 | — |
| 4 | Avisos urgentes con SMS de respaldo | En curso: integrada; solo el SMS falso; falta el proveedor real | stefanods29 | — |

Estados posibles: **Pendiente**, **En curso** o **Hecha** (integrada en `main`).

---

## 0. Antes de empezar

Valen las reglas de las fases anteriores y las [reglas comunes de esta fase](../README.md#reglas-para-todos-los-lotes).
La consola funciona **solo en línea**, usa la misma API con roles operativos (sección 9.5) y
también cumple WCAG 2.2 AA. Nunca guarda datos sensibles en el navegador (ni en `localStorage` ni
en caché).

---

## Parte 1 · Base de la consola web

- ADR: Flutter web (reutiliza modelos y textos de la app) o React. El ADR compara mantenimiento,
  accesibilidad y tamaño.
- Ingreso con OTP y solo para roles operativos; cierre de sesión por inactividad.
- Despliegue estático en staging y producción con la CDN (OpenTofu de la Fase 1) y su propio flujo
  de CI.

## Parte 2 · Cola de casos y asignación

- Cola por prioridad con el tiempo que lleva cada pedido sin revisar, resaltando los que están por
  escalar.
- Detalle minimizado del caso, asignación a un brigadista o vecino, cambio de estado con motivo e
  historial auditado (rutas de B).
- Los errores de la API (Problem Details) se muestran con su motivo y lo que se puede hacer.

## Parte 3 · Mapa de celdas, turnos y curaduría

- Mapa con las celdas agregadas, sin ubicaciones exactas salvo la del caso abierto por quien está
  asignado.
- Gestión de turnos y de la regla de cobertura de la zona.
- Curaduría del directorio de emergencia: editar entradas con fuente y fecha y publicar una nueva
  versión del JSON en la CDN (esquema de la Fase 1). Reemplaza la edición por PR.
- Vista de la cola de moderación (Fase 1) para los moderadores.

## Parte 4 · Avisos urgentes con SMS de respaldo

- Aviso urgente a coordinadores por token y, si no se confirma en un tiempo, SMS de respaldo con un
  adaptador del proveedor elegido (decisión 13.3.4) y un tope de gasto.
- Aviso público de zona al activarse el modo emergencia (tópico de FCM).
- Plantillas siempre genéricas ("Tienes una actualización"). Se miden la entrega y el costo.

Pruebas: adaptador de SMS falso en local, prueba de que el respaldo se dispara cuando el token falla
y revisión de cada plantilla.

---

## Fuera de alcance

App móvil del modo emergencia (Lote D) y analítica avanzada de operación (Fase 3).

## Definición de terminado del lote

Las 4 partes aprobadas e integradas, la consola desplegada en staging y producción y la evidencia de
avisos urgentes lista para los criterios de salida.

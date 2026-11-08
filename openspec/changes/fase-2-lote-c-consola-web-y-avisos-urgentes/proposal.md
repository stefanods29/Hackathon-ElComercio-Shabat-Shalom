# Proposal

## Why

En una emergencia, la coordinación humana necesita su propia herramienta. Los coordinadores revisan
y asignan pedidos con tiempos acordados, los moderadores revisan la cola y los curadores mantienen
el directorio de emergencia. Además, un aviso urgente a un coordinador no puede depender de un
solo canal (secciones 7.5, 9.1 a 9.5 y 11 de la arquitectura). **Dueño: Lote C de la Fase 2 ·
Dificultad ★★ · El Lote A de la fase revisa e integra cada entrega.**

## What Changes

- **Consola web de operación** en `consola/`, con Flutter web (ADR 0014). Funciona solo en línea,
  con la misma API y con roles operativos.
  - Ingreso con OTP y solo para roles operativos, y cierre de sesión por inactividad.
  - Nada sensible se guarda en el navegador.
  - Despliegue estático con su propio flujo de CI.
- **Cola de casos y asignación:**
  - cola por prioridad con el tiempo que lleva cada pedido sin revisar, resaltando los que están
    por escalar;
  - detalle minimizado, asignación, cambio de estado con motivo e historial;
  - errores de la API explicados con su motivo y lo que se puede hacer.
- **Mapa de celdas, turnos y curaduría:**
  - mapa y tabla de celdas agregadas, sin ubicaciones exactas;
  - turnos y regla de cobertura;
  - edición del directorio de emergencia con fuente y fecha, y publicación de una versión nueva en
    la CDN desde la API;
  - vista de la cola de moderación de la Fase 1.
- **Avisos urgentes con SMS de respaldo:**
  - aviso urgente por token a un coordinador o brigadista. Si no se confirma a tiempo, SMS por un
    adaptador del proveedor, con tope de gasto diario y mensual. En esta entrega solo existe el
    adaptador falso (decisión 13.3.4 abierta);
  - aviso público de zona por tópico de FCM al activarse el modo emergencia;
  - plantillas siempre genéricas, y medición de entrega y costo.

Fuera de alcance:
- el módulo Emergencias y su contrato (Lote B de esta fase);
- la app en modo emergencia (Lote D) y el modo operativo en el celular (Lote A);
- el proveedor real de SMS (decisión 13.3.4);
- la analítica avanzada de operación (Fase 3).

## Capabilities

### New Capabilities
- `consola/operacion`: consola web de operación para coordinadores, brigadistas, moderadores y
  curadores.
- `notificaciones/avisos-urgentes`: avisos urgentes con confirmación, SMS de respaldo y tope de
  gasto, y aviso público de zona.
- `emergencias/directorio-curado`: edición y publicación versionada del directorio de emergencia
  desde la API.

### Modified Capabilities

## Impact

- `consola/` (nuevo proyecto Flutter web) e `infra/cloud/modules/console-site/` (nuevos). El
  flujo `.github/workflows/consola.yml` queda descrito para crearlo después.
- Backend:
  - `backend/src/modules/notificaciones/` (avisos urgentes, SMS y aviso de zona);
  - `backend/src/modules/curaduria/` (nuevo);
  - una interfaz pequeña de contactos en `backend/src/modules/identidad/`;
  - CORS y `Cache-Control: no-store` en `backend/src/main.ts`;
  - `backend/.env.example`.
- `contracts/openapi.yaml`: avisos urgentes y curaduría.
- `app/lib/features/avisos/`: rutas de los avisos nuevos y confirmación del aviso urgente al
  abrirlo.
- Puntos de contacto:
  - el contrato de Emergencias del Lote B (casos, celdas y turnos), que la consola usa detrás de
    puertos con dobles de demostración mientras no existe;
  - el trabajo `notificaciones.enviar_aviso_urgente` para el escalamiento de B;
  - el evento `emergencias.evento_activado` de B;
  - el esquema del directorio de emergencia del Lote A de la Fase 1;
  - las rutas de moderación del Lote B de la Fase 1.

# Spec Delta

## Purpose

Que coordinadores, brigadistas, moderadores y curadores trabajen desde una consola web accesible y
solo en línea, con la misma API y sus roles operativos (secciones 9.1 a 9.5 de la arquitectura).

## ADDED Requirements

### Requirement: Ingreso solo para roles operativos
La consola SHALL permitir el ingreso con el mismo OTP que la app. Solo MUST abrirse para sesiones
con al menos un rol operativo: `coordinador`, `brigadista`, `moderador`, `administrador` o, cuando
exista, `curador`.

#### Scenario: Vecino sin rol operativo
- **WHEN** un vecino sin rol operativo verifica su código en la consola
- **THEN** la consola cierra esa sesión y explica que es solo para roles operativos

### Requirement: Nada sensible en el navegador
La consola MUST NOT guardar tokens ni datos de casos en `localStorage`, `sessionStorage`,
IndexedDB ni en la caché. La API SHALL responder `Cache-Control: no-store` en las rutas que usa la
consola.

#### Scenario: Recargar la página
- **WHEN** un coordinador recarga la consola
- **THEN** debe volver a ingresar y no queda ningún dato del caso en el almacenamiento del navegador

### Requirement: Cierre por inactividad
La consola SHALL cerrar la sesión en la API y borrar su estado tras el tiempo de inactividad
configurado (10 minutos por defecto), avisando 60 segundos antes.

#### Scenario: Coordinador que se aleja
- **WHEN** pasan 10 minutos sin actividad
- **THEN** la sesión se cierra en el servidor y la consola vuelve a la pantalla de ingreso

### Requirement: Cola de casos por prioridad
La cola SHALL ordenar los pedidos por prioridad y por el tiempo que llevan sin revisar. Debe
resaltar los que están por escalar (25 % del tiempo restante o menos de 5 minutos) y los que ya
superaron su tiempo de primera revisión.

#### Scenario: Pedido de prioridad alta cerca del límite
- **WHEN** un pedido de prioridad alta lleva 12 de sus 15 minutos sin revisar
- **THEN** aparece primero entre los de su prioridad, marcado "Por escalar", con el tiempo en texto

### Requirement: Detalle minimizado y cambios auditados
El detalle SHALL mostrar solo lo necesario para decidir. La ubicación exacta MUST aparecer solo si
quien mira es la persona asignada y el caso está *en camino*. Asignar, derivar o cerrar sin atender
MUST pedir un motivo cuando la sección 7.2 lo exige, y el historial SHALL mostrar cada cambio con
su hora y su rol.

#### Scenario: Coordinador que no está asignado
- **WHEN** un coordinador abre un caso asignado a un brigadista
- **THEN** ve la celda pública y el historial, pero no la ubicación exacta

### Requirement: Errores explicados
Cada error de la API (Problem Details) SHALL mostrarse con su motivo y con lo que se puede hacer,
según su `codigo`.

#### Scenario: Otro coordinador cambió el caso
- **WHEN** la API responde 409 `conflicto_de_version` al asignar
- **THEN** la consola explica que el caso cambió y ofrece recargarlo, sin perder lo que se estaba
  escribiendo

### Requirement: Mapa de celdas sin ubicaciones exactas
El mapa SHALL mostrar solo agregados por celda, con una tabla equivalente para lectores de
pantalla. Una celda con menos de 3 pedidos MUST mostrarse como "menos de 3", sin cifra.

#### Scenario: Celda con dos pedidos
- **WHEN** una celda tiene 2 pedidos de agua
- **THEN** el mapa y la tabla dicen "menos de 3" y no muestran ningún punto

### Requirement: Turnos y cobertura
La consola SHALL listar, crear y terminar turnos de la zona, y mostrar si la zona cumple la regla
de cobertura (2 coordinadores activos y un turno vigente).

#### Scenario: Zona con un solo coordinador
- **WHEN** la zona tiene un coordinador activo
- **THEN** la consola indica que no hay cobertura operativa y por qué

### Requirement: Cola de moderación
Los moderadores SHALL ver la cola de moderación de la Fase 1 y registrar decisiones con motivo desde
la consola.

#### Scenario: Moderador oculta una reseña
- **WHEN** un moderador elige ocultar y escribe el motivo
- **THEN** la decisión se envía con `Idempotency-Key` y el caso sale de los pendientes

### Requirement: Accesibilidad de la consola
La consola SHALL cumplir WCAG 2.2 AA:
- se usa con teclado, con el foco visible;
- tiene etiquetas semánticas en español;
- respeta el contraste del tema;
- el texto al 200 % no se corta;
- el color nunca es la única señal.

#### Scenario: Navegar con teclado
- **WHEN** un coordinador recorre la cola solo con el teclado
- **THEN** llega a cada pedido y a sus acciones en un orden lógico y siempre ve dónde está el foco

### Requirement: Despliegue estático
La consola SHALL desplegarse como sitio estático en staging y en producción con su propio flujo de
CI. `index.html` MUST servirse sin caché y con una política de seguridad de contenido.

#### Scenario: Integración a main
- **WHEN** se integra un cambio de `consola/` a `main` con la CI en verde
- **THEN** staging publica la nueva versión sin pasos manuales

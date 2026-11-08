# Spec Delta

## Purpose

Proteger el acceso a las vistas operativas cuando se comparte el celular, se deja desatendido o se cambia de aplicación.

## ADDED Requirements

### Requirement: Desbloqueo e inactividad del modo operativo

La app SHALL exigir PIN o biometría para abrir las vistas sensibles del modo operativo y SHALL volver a bloquearlas al superar el tiempo de inactividad configurado. El desbloqueo local MUST NOT otorgar un rol operativo ni extender una autorización de caso.

#### Scenario: El operador vuelve tras una pausa sin conexión

- **WHEN** el coordinador vuelve a la app después del límite de inactividad
- **THEN** la app oculta los datos operativos antes de mostrar la pantalla y pide desbloquear el modo operativo

#### Scenario: El dispositivo no acepta la autenticación

- **WHEN** falla o se cancela el desbloqueo
- **THEN** la vista permanece bloqueada y no revela el detalle del caso

### Requirement: Protección de pantallas sensibles

En Android la app SHALL bloquear las capturas en las vistas sensibles. En iOS SHALL difuminar esas vistas en el selector de aplicaciones.

#### Scenario: El operador intenta capturar una vista en Android

- **WHEN** se toma una captura mientras está abierto el detalle de un caso en Android
- **THEN** la captura no revela su contenido

#### Scenario: El operador cambia de aplicación en iOS

- **WHEN** se abre el selector de aplicaciones desde el detalle de un caso en iOS
- **THEN** la vista previa aparece difuminada sin texto ni ubicación legibles

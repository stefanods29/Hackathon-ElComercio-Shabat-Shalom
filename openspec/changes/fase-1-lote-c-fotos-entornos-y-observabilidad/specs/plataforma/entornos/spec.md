# Spec Delta

## Purpose

Que el piloto corra en entornos reproducibles, con despliegue desde la CI, betas instalables y
respaldos que se pueden restaurar (sección 11 de la arquitectura).

## ADDED Requirements

### Requirement: Infraestructura como código
Los entornos staging y producción SHALL crearse con OpenTofu desde `infra/tofu/`: PostgreSQL
gestionado con PostGIS y replicación lógica, almacenamiento de objetos con CDN, PowerSync, API y
workers en contenedores con autoescalado, secretos, DNS y respaldos con recuperación a un punto en
el tiempo.

#### Scenario: Plan sin cambios
- **WHEN** se aplica la infraestructura y se vuelve a correr `tofu plan`
- **THEN** el plan no propone cambios

### Requirement: Secretos fuera del repositorio
Ninguna credencial de la nube, del almacenamiento, de Firebase ni de Sentry SHALL guardarse en el
repositorio; MUST vivir en el gestor de secretos de cada entorno y en los secretos de GitHub Actions.

#### Scenario: Revisión de un PR de infraestructura
- **WHEN** se revisa un cambio en `infra/tofu/`
- **THEN** no contiene claves, tokens ni archivos de cuentas de servicio

### Requirement: Despliegue continuo
Cada integración a `main` SHALL desplegar staging desde la CI, y producción MUST desplegarse solo
desde una etiqueta de versión.

#### Scenario: Integración a main
- **WHEN** se integra un cambio a `main` con la CI en verde
- **THEN** staging se actualiza sin pasos manuales

### Requirement: Betas para el piloto
Cada versión del piloto SHALL distribuirse por TestFlight y por las pruebas internas de Google Play,
firmada con las claves del equipo, con el ingreso por SMS de Firebase configurado para esas firmas.

#### Scenario: Instalación desde Google Play
- **WHEN** un vecino del piloto instala la beta desde Google Play e ingresa con su número
- **THEN** recibe el SMS sin ver la página de verificación de reCAPTCHA

### Requirement: Restauración probada
El equipo SHALL hacer y documentar un simulacro de restauración del respaldo de staging antes de
abrir el piloto.

#### Scenario: Simulacro
- **WHEN** se restaura el respaldo de staging a un punto en el tiempo
- **THEN** la API vuelve a responder y el resultado queda en la evidencia de entornos

### Requirement: Capacidad en staging
La prueba de capacidad de la Fase 0 SHALL correrse completa contra staging y su informe MUST
reemplazar al del humo local como evidencia del criterio.

#### Scenario: Corrida del pico de emergencia
- **WHEN** el equipo corre `npm run test:load` contra staging
- **THEN** obtiene la latencia p95, la tasa de error y la cola crítica del entorno real

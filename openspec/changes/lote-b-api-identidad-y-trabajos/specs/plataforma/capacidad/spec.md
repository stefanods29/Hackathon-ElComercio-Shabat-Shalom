# Spec Delta

## Purpose

Comprobar con una prueba de carga reproducible que la arquitectura soporta el pico de una emergencia (sección 5.6 y 13.1).

## ADDED Requirements

### Requirement: Escenario de pico de emergencia reproducible
El repositorio SHALL incluir un escenario k6 que simule unas 2 500 peticiones por segundo durante 10 minutos, con la mezcla de lecturas, escrituras idempotentes y reconexión simultánea de clientes de sincronización.

#### Scenario: Ejecución del escenario
- **WHEN** el equipo corre el escenario contra un entorno de staging
- **THEN** obtiene un informe con latencia p95, tasa de error y profundidad de la cola crítica

### Requirement: Umbrales de aceptación
La prueba SHALL fallar si la latencia p95 o la tasa de error superan los umbrales acordados, o si la cola crítica se degrada.

#### Scenario: Regresión de rendimiento
- **WHEN** un cambio sube la latencia p95 por encima del umbral
- **THEN** el escenario k6 termina con error y el informe lo señala

# Spec Delta

## Purpose

Que cada vecino entienda y decida qué datos suyos trata la app, pueda verlos, corregirlos y borrarlos
desde el celular, y sepa cómo subir de nivel de confianza (sección 10 de la arquitectura, Ley 29733).

## ADDED Requirements

### Requirement: Consentimiento al registrarse
Al registrarse, la app SHALL explicar en lenguaje simple cada finalidad y pedir su aceptación por
separado; rechazar una finalidad opcional MUST NOT impedir usar la app.

#### Scenario: Rechaza la confirmación por presencia
- **WHEN** el vecino acepta el uso del servicio y rechaza la confirmación de residencia por presencia
- **THEN** entra a la app y el celular no informa su presencia

### Requirement: Ver y exportar mis datos
"Mis datos" en la cuenta SHALL mostrar los datos que la app guarda del vecino y permitir exportarlos.

#### Scenario: Exportar
- **WHEN** el vecino toca "Exportar mis datos" con conexión
- **THEN** recibe un archivo con sus datos para guardarlo o compartirlo

### Requirement: Corregir mi nombre
"Mis datos" SHALL permitir corregir el nombre visible, con la validación del servidor explicada
junto al campo.

#### Scenario: Nombre muy corto
- **WHEN** el vecino escribe un nombre de una letra
- **THEN** ve el motivo junto al campo y el nombre no cambia

### Requirement: Borrar mi cuenta
"Borrar mi cuenta" SHALL explicar con claridad qué se borra y pedir una confirmación explícita antes
de hacerlo; necesita conexión.

#### Scenario: Confirmación
- **WHEN** el vecino toca "Borrar mi cuenta"
- **THEN** ve qué se borra y debe confirmar antes de que la app envíe la solicitud

### Requirement: Cómo subir de nivel
La pantalla "Cómo subir de nivel" SHALL explicar qué permite cada nivel y cómo se confirma la
residencia y el aval, con el nivel actual del vecino.

#### Scenario: Vecino de nivel 0
- **WHEN** un vecino de nivel 0 abre "Cómo subir de nivel"
- **THEN** ve que puede confirmar su residencia por presencia o con un moderador para publicar

### Requirement: Usable por adultos mayores
Las pantallas del piloto SHALL poder usarse sin ayuda por adultos mayores: 5 participantes MUST
completar buscar un servicio, reseñarlo y abrir el directorio de emergencia en la prueba de
usabilidad.

#### Scenario: Prueba de usabilidad
- **WHEN** 5 adultos mayores hacen las tres tareas con su letra del sistema
- **THEN** las completan sin ayuda y el resultado queda sin datos personales en la evidencia

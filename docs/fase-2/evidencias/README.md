# Evidencias de la Fase 2

Aquí va el resultado de cada criterio de [`../criterios-de-salida.md`](../criterios-de-salida.md),
un archivo por criterio (por ejemplo `simulacro.md` o `penetracion.md`).

Cada archivo dice qué se probó, con qué versión (commit), en qué dispositivos, cuándo y con qué
resultado. Los pedidos del simulacro son ficticios. Nunca se guardan aquí datos de salud,
ubicaciones exactas, nombres ni teléfonos, aunque sean de prueba.

## Pendiente 13

Responsable: `JDiazD33`. El 8 de noviembre de 2026 se revisaron las ramas locales y remotas
del monorepo. Las carpetas locales de entrega son worktrees del mismo repositorio. La base
de esta entrega es el `main` remoto en `4fb7761`.

| Pendiente | Evidencia y estado |
|---|---|
| 1 · Consola contra la API | Integrado en `main` en `0c6489d`. [Evidencia](consola-contra-api.md). |
| 2 · Escalamiento, reintentos y supresión | Pruebas locales en `f2-lote-b/parte-3-4-pruebas` (`dd0c878`). Pendiente de integración y verificación del candidato. |
| 3 · Frescura de recursos | Reloj controlado en `f2-lote-d/parte-3-frescura` (`cfb8836`). Falta verificar en modo avión. |
| 4 · Pantallas del tablero | Pruebas de widgets en `f2-lote-d/parte-1-2-pruebas-pantallas` (`b3651b2`). Modo avión simulado en widgets. |
| 5 · Pantallas de consola y OpenTofu | Pruebas locales y validación de OpenTofu en `f2-lote-c/parte-1-2-pruebas-pantallas` (`77d6192`). |
| 6 · Accesibilidad automática | Integrada en `main`. [Evidencia local](accesibilidad-modo-emergencia.md) y [CI App de `4fb7761` aprobada](https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom/actions/runs/42491614262). |
| 7 · Modo avión en pantallas reales | Pendiente de una corrida en dispositivo o simulador con evidencia versionada. |
| 8 · PowerSync en vivo | `f2-lote-a/parte-2-powersync-en-vivo` (`4c66021`) documenta dos ejecuciones locales con el servicio y clientes SQLite. |
| 9 · Referencias visuales en Linux | `f2-ci/referencias-linux` (`ddc0e59`) documenta generación reproducible y verificación local de Linux. |
| 10 y 11 · Capturas y lectores en teléfonos | `f2-lote-a/parte-3-y-d-4-telefonos` (`e658974`) documenta el acceso a práctica en Android. Faltan los recorridos de protección, TalkBack y VoiceOver. |
| 12 · Decisiones y revisión | No hay constancia de ruta de ofertas, revisión de migraciones por las dos personas, proveedor de SMS ni autorización de nube en la base revisada. |
| 13 · Penetración, campo y simulacro | [Pruebas de seguridad](penetracion.md), [prueba de campo](modo-operativo.md#prueba-de-campo), [libreto](simulacro.md), [revisión](revision-simulacro.md) y [criterios de salida](../criterios-de-salida.md). |

Las ramas de los pendientes 2, 3, 4, 5, 8, 9, 10 y 11 aportan evidencia aparte de `main`.
El simulacro requiere los acuerdos, tiempos y evaluación de privacidad, además de resolver
las dependencias restantes o registrar la aceptación de su riesgo.

### Comprobaciones de la preparación

| Comprobación | Resultado local |
|---|---|
| `npm run verify` | 249 pruebas, tipos, formato, fronteras, reglas de Sync Streams y build aprobados. Seis avisos de lint ya presentes. |
| `npm run test:integration` | 204 pruebas aprobadas con PostgreSQL 18.6 y PostGIS 3.7. |
| `npm run test:console-contract` | Una suite aprobada, con los siete casos de los adaptadores contra la API local. |
| `app/tool/verify.sh` | 284 aprobadas, una omitida, análisis y formato correctos en macOS. Una primera corrida falló en la prueba de cobertura sin señal. La prueba pasó aislada y en la repetición completa. La CI de Linux reprodujo el fallo. [Corrección de cobertura en `aa438ba`](https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom/blob/aa438ba5c8ab6f6f872280c94ec7b481f25e9302/docs/fase-2/evidencias/cobertura-local-sin-senal.md). |
| Consola | Análisis, siete pruebas y build web aprobados. Siete pruebas de API se omiten en la suite normal y se ejecutan con el contrato. El build conserva un aviso de fuente. |
| Contrato OpenAPI | Válido con seis avisos. |
| `openspec validate --all --strict` | 30 elementos válidos. |
| Script de conciliación | Tres casos automatizados. Ejecución por CLI con datos sintéticos devolvió códigos 0, 1 y 2 según entrada. |

OpenSpec `spec-driven`: A conserva 10 de 25 tareas y D, 9 de 15. Permanecen abiertas A
5.1–5.3, A 6.1–6.4 y D 4.3. La preparación y las comprobaciones locales cubren una parte de
esos requisitos. El cierre requiere los teléfonos, el ejercicio y la revisión con el equipo.

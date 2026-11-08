# Criterios de salida de la Fase 1

La condición de la sección 12 es "uso real sostenido, moderación funcionando y métricas de
sincronización sanas". Los números son un **ejemplo**: el equipo los fija al abrir la fase y los
anota aquí antes de empezar el piloto.

| Criterio | Aceptación (ejemplo) | Lote · parte | Evidencia | Estado |
|---|---|---|---|---|
| Uso real sostenido | 4 semanas seguidas con al menos 30 % de los vecinos registrados activos cada semana, y publicaciones o reseñas reales todas las semanas | A · 5 | `evidencias/piloto.md` | ☐ |
| La moderación funciona | Todas las denuncias revisadas; primera revisión en 24 h o menos (p90); lo ocultado sale de los celulares en la siguiente sincronización | B · 5 + A · 1 | `evidencias/moderacion.md` | ☐ |
| Métricas de sincronización sanas | p95 del tiempo hasta "Enviado" con conexión de 1 min o menos; menos de 1 % de rechazos permanentes; 0 pérdidas y 0 duplicados reportados | A · 3 y 5 | Tablero de C · 5 + `evidencias/sincronizacion.md` | ☐ |
| El directorio de emergencia funciona sin señal | Todos los celulares del piloto lo abren en modo avión, con fuente y fecha en cada dato | A · 2 + D · 4 | `evidencias/directorio-emergencia.md` | ☐ |
| Ningún dato público expone a una persona | Ningún stream automático lleva la ubicación exacta de una persona ni datos de contacto | A · 1 | Pruebas de los streams + `evidencias/datos-publicos.md` | ☐ |
| El consentimiento y los derechos ARCO funcionan | Consentimiento registrado de todos los usuarios; una solicitud de acceso, rectificación, cancelación y oposición atendida desde la app | B · 4 + D · 5 | `evidencias/privacidad.md` | ☐ |
| Las fotos no filtran ubicación | 0 fotos con EXIF o GPS en el almacenamiento (muestreo de todas las del piloto) | C · 1–2 | `evidencias/fotos.md` | ☐ |
| Los entornos son reproducibles | Staging y producción creados con OpenTofu y desplegados desde el CI; la capacidad de la Fase 0 corrida en staging | C · 4 + B (Fase 0, parte 6) | `evidencias/entornos.md` + `../fase-0/evidencias/capacidad.md` | ☐ |
| La app es estable | Al menos 99 % de sesiones sin fallos en Sentry durante el piloto | C · 5 | Tablero de Sentry | ☐ |
| La app es usable por adultos mayores | 5 adultos mayores completan buscar, reseñar y abrir el directorio de emergencia sin ayuda | D · 5 | `evidencias/usabilidad.md` | ☐ |

Si un criterio no se cumple, el equipo decide si se corrige antes de salir o si se acepta el riesgo
de forma explícita, y lo anota debajo de esta tabla con fecha.

El 7 de noviembre de 2026 el usuario indicó omitir la prueba presencial con adultos
mayores y validar localmente con perfiles y datos simulados. El resultado se registra en
`evidencias/usabilidad.md`: se mantiene separada la aceptación automática del recorrido
de la usabilidad humana, que queda omitida y no se marca aprobada.

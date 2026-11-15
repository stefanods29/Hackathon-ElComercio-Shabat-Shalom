# Pendiente 13 · Prueba de penetración, prueba de campo, simulacro y prueba con vecinos

**Agente recomendado: Opus 5.5.** Es el pendiente más difícil de la Fase 2: seguridad de datos
sensibles, pruebas con muchos celulares y un ejercicio con aliados. El agente prepara, automatiza
lo que se pueda y analiza. Las partes con personas y teléfonos las ejecuta el equipo. Responsable:
`JDiazD33`, con todo el equipo en el simulacro.

Cierra, cuando haya evidencia:

- A 5.1, 5.2 y 5.3
- A 6.1, 6.2, 6.3 y 6.4
- D 4.3
- los criterios de `docs/fase-2/criterios-de-salida.md`

## Antes de empezar

1. Lee:
   - `reglas-de-trabajo.md`
   - `docs/fase-2/README.md`, sobre todo "Antes de abrir la fase"
   - `criterios-de-salida.md`
   - `integracion.md`
   - las guías de los cuatro lotes
   - `docs/arquitectura/`: secciones 7 a 9 y 12, y la 8.4 por el riesgo del teléfono perdido
2. Comprueba que lo previo está listo, o pídelo:
   - alianzas firmadas;
   - tiempos de respuesta acordados (decisión 13.3.6);
   - evaluación de impacto en la privacidad;
   - los pendientes 2 a 12 hechos o con su riesgo aceptado por escrito.

   Sin las tres primeras no hay simulacro.
3. Reglas:
   - ramas nuevas desde `main`, commit y push solo de esa rama, sin merge ni PR;
   - solo usuarios de GitHub del equipo en responsables y autores;
   - ninguna mención de herramientas de IA ni `Co-Authored-By`;
   - **solo datos ficticios**: el simulacro usa pedidos inventados, y en las evidencias nunca hay
     datos de salud, ubicaciones exactas, nombres ni teléfonos;
   - no hay staging autorizado: todo corre en local o en el entorno que el equipo autorice por
     escrito.

## Parte 1 · Prueba de penetración (A 5.1)

Rama `f2-lote-a/parte-5-penetracion`.

1. **Plan** en `docs/fase-2/evidencias/penetracion.md`, con los casos de OWASP MASVS (almacenamiento,
   red, plataforma, resiliencia) y de OWASP API Security Top 10 (2023) aplicados a:
   - las rutas de Emergencias, Notificaciones y Curaduría;
   - los streams de PowerSync;
   - la base cifrada del celular;
   - el modo operativo protegido.
2. **Automatizar lo posible como pruebas del repo:**
   - autorización por objeto (BOLA) en cada ruta con id;
   - roles y nivel;
   - token de otra sesión o cuenta;
   - repetición de claves de idempotencia;
   - suscripciones directas a streams sin permiso;
   - filas sensibles en dispositivos no autorizados.

   Base: `backend/test/integration/emergencies.int-spec.ts`, `backend/test/sync/datos-publicos.spec.ts`
   y la prueba de PowerSync en vivo del pendiente 8.
3. **Manual con el equipo:**
   - inspeccionar la base local de un celular perdido sin la clave;
   - capturas;
   - tráfico con un proxy, verificando que nada sensible viaja fuera de lo autorizado.
4. Registrar versión, casos, hallazgos con severidad y la evidencia de "0 filas sensibles en
   dispositivos no autorizados".

## Parte 2 · Prueba de campo (A 5.2)

1. **Guion** en `docs/fase-2/evidencias/modo-operativo.md` (sección "Prueba de campo"):
   - varios celulares Android e iOS;
   - reconexiones simultáneas;
   - señal débil, con el limitador de red del sistema o un punto de acceso con pérdida;
   - batería baja;
   - pedidos ficticios creados sin señal.
2. Un script que cuente pedidos perdidos o duplicados comparando:
   - las colas de los celulares (`envios`);
   - `emergencias.pedidos_ayuda` en la base.
3. El equipo ejecuta y el agente analiza: dispositivos, condiciones, versión y conteo de pérdidas y
   duplicados.

## Parte 3 · Corrección de hallazgos (A 5.3)

Cada hallazgo de las partes 1 y 2 en una rama de corrección con su prueba que lo reproduce. Repetir
el caso y enlazar la evidencia de repetición. `npm run verify`, `tool/verify.sh` y la CI en verde.

## Parte 4 · Simulacro con los aliados (A 6.1 a 6.4 y D 4.3)

1. **Libreto** en `docs/fase-2/evidencias/simulacro.md`:
   - roles: aliados, coordinadores, brigadistas y vecinos, por función y nunca por nombre;
   - horario y zona;
   - pedidos ficticios de cada prioridad, incluidos los creados sin señal;
   - un escalamiento forzado por tiempo;
   - avisos urgentes con SMS de respaldo si 12.3 se decidió;
   - una derivación, un cierre sin atender y el cierre del evento con anonimización.
2. **Preparar el entorno:**
   - habilitaciones y turnos reales de prueba;
   - la versión exacta de app, API y consola (6.4: todas las verificaciones y la CI en verde para
     ese commit);
   - el tablero de seguimiento en la consola.
3. **Durante el simulacro, medir:**
   - primera revisión dentro del tiempo por prioridad;
   - escalamiento automático cuando no se cumple;
   - 0 pedidos perdidos o duplicados;
   - avisos que llegan;
   - que los vecinos identifiquen el estado y las alternativas oficiales sin ayuda (D 4.3).
4. **Revisión sin culpables** (6.3) en `docs/fase-2/evidencias/revision-simulacro.md`:
   - hallazgos, ajustes acordados y responsables;
   - casos cerrados y anonimizados.
5. Actualizar `criterios-de-salida.md`: cada criterio con su evidencia o el riesgo aceptado por
   escrito y con fecha, incluido el del teléfono perdido sin conexión (8.4).

## Cierre de la fase

Cuando todos los criterios tengan evidencia o riesgo aceptado:

- archivar los cuatro changes de OpenSpec con el procedimiento del skill de archivo;
- comprobar `openspec validate --all --strict`;
- dejar el estado de la Fase 2 en `docs/fase-2/README.md`.

## Entrega

Por cada parte:

- la rama y su SHA;
- los documentos de evidencia;
- las pruebas nuevas con su resultado;
- los hallazgos con su estado;
- las tareas marcadas y las abiertas, con el motivo.

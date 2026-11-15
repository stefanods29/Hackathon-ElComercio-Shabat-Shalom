# Pendiente 12 · Decisiones del equipo y encargos que se abren después

Estos cuatro pendientes no son de código hasta que alguien decida. Cada uno trae:

- qué hay que decidir y quién;
- qué opciones hay;
- el encargo listo para la persona o el agente que lo implemente.

Responsable de decidir: el equipo (`JDiazD33`, `stefanods29`, `Defartion`, `KQuirosA`). La
decisión se registra en el documento que indica cada punto, con fecha y quién la tomó, usando
solo usuarios de GitHub.

**Reglas comunes de cada encargo:**

- Rama nueva desde `main`. Commit y push solo de esa rama, sin merge, rebase, cherry-pick ni PR.
- Solo usuarios de GitHub del equipo en responsables y autores, y ninguna mención de herramientas
  de IA ni `Co-Authored-By`.
- Datos ficticios, nada de credenciales en el repo: las variables se documentan en
  `backend/.env.example` sin sus valores.
- Tareas `[x]` solo con evidencia.
- Antes de empezar, leer `reglas-de-trabajo.md`, `docs/fase-2/integracion.md` y la guía del lote.

---

## 12.1 · Ruta de las ofertas "Puedo ayudar" (D 3.3)

**Quién:** `Defartion`, porque el módulo Emergencias (B) es suyo, con `stefanods29` por el lado de
D y C.

**Situación:** la app guarda las ofertas solo en el celular y lo dice, porque B no tiene una ruta
para recibirlas. La guía de D pide "Ofrecer ayuda (habilidades o recursos) a la zona". La regla de
B: una oferta no se convierte en habilitación ni da acceso a pedidos.

**Qué decidir:**

1. **¿La coordinación ve las ofertas?** Opciones:
   - a) una lista en la consola por zona;
   - b) solo un conteo por tipo, como los agregados.
2. **Qué datos lleva una oferta.** Recomendado: tipo (`agua`, `alimentos`, `traslado`, `albergue`,
   `herramientas`, `otro`), una cantidad o disponibilidad y una franja horaria. Sin texto libre
   público. Si se acepta un texto, solo lo ve la coordinación y se anonimiza al cerrar el evento.
3. **Vigencia:** cuánto dura una oferta y si caduca con el evento.

**Encargo de implementación** (para `Defartion`; con agente, Sonnet 5.5 alcanza):

- Rama `f2-lote-b/ofertas-de-ayuda`.
- **Backend:**
  - migración `emergencias.ofertas_ayuda`, con zona, evento, autor, tipo, cantidad, franja,
    estado, creada y vence;
  - `POST /v1/zonas/{zonaId}/ofertas-ayuda` con `Idempotency-Key` y el id generado en el celular;
  - `GET /v1/operacion/zonas/{zonaId}/ofertas` para la coordinación, según lo decidido en el
    punto 1;
  - auditoría de cada lectura operativa, y borrado y anonimización en `EmergencyPersonalData`;
  - contrato en `contracts/emergencias.openapi.json` y `contracts/openapi.yaml`;
  - prueba de integración siguiendo `backend/test/integration/emergencies.int-spec.ts`.
- **App:** `OperationalEmergencyRepository.saveOffer`
  (`app/lib/features/emergencias/data/operational_emergency_repository.dart`) pasa a la cola de
  subida de A (nuevo `SubmissionKind` con su ruta en `command_routes.dart`), con estado real de
  envío.
- **Consola:** si se decidió la opción a), una pantalla de ofertas con su adaptador HTTP y la
  prueba en `consola/test/live/`.
- **Verificación:**
  - `npm run verify`, `npm run test:integration` y `npm run test:console-contract`;
  - `tool/verify.sh` en `app/` y la verificación de la consola;
  - `openspec validate --all --strict`.
- Marca D 3.3 con la evidencia de que la oferta llega a coordinación.

---

## 12.2 · Revisión de las migraciones y de la seguridad de B (B 5.3)

**Quién:** `Defartion`, que escribió B, junto con `JDiazD33`, que integró. Hace falta una
revisión de dos personas, no un agente solo.

**Qué revisar** (lista para la reunión):

- `backend/src/modules/identidad/infrastructure/migrations/202611090100_identidad_rol_curador.ts`
  (rol `curador`).
- `backend/src/modules/emergencias/infrastructure/migrations/202611090200_emergencias_operacion.ts`:
  - el relleno de `detalles_pedidos`;
  - que `detalle` pase a texto genérico;
  - los nuevos índices únicos;
  - la publicación de `recursos_publicos` y `agregados_celda`.
- `202611160100_emergencias_streams_operativos.ts`:
  - los tres disparadores, las tablas mínimas para los streams y la revocación;
  - comprobar que ningún camino deja una copia vieja.
- Que los `down()` que lanzan error son intencionales y que existe un plan de reversión escrito.
- Privilegios del rol `powersync_rol`: solo `SELECT` sobre lo publicado.
- **Seguridad de las rutas:**
  - cada ruta de `backend/src/modules/emergencias/api/` exige el rol y el nivel correctos;
  - los 404 no revelan si un pedido existe;
  - toda lectura sensible queda en `emergencias.auditoria`;
  - ningún texto de aviso lleva datos sensibles;
  - el guard intersecta los roles del token con los de la base.

**Dónde registrar:** `docs/fase-2/evidencias/revision-migraciones-b.md`, con hallazgos, decisiones
y responsables (usuarios de GitHub). Si hay correcciones, van en una rama
`f2-lote-b/correcciones-revision` con sus pruebas. Marca B 5.3 cuando la revisión esté registrada
y la CI siga en verde.

---

## 12.3 · Proveedor real de SMS de respaldo (C 4.5, decisión 13.3.4)

**Quién:** el equipo; ejecuta `stefanods29`, dueño de C.

**Situación:** los avisos urgentes llegan por push y, si nadie confirma, por SMS de respaldo. Hoy
`SMS_PROVIDER` solo admite `none` (apagado, por defecto) y `fake` (prohibido en producción). La
interfaz es `SmsProvider` en `backend/src/modules/notificaciones/application/ports.ts`. Ya hay topes
de gasto diario y mensual.

**Qué decidir:**

1. **Proveedor.** Opciones:
   - a) Twilio, ya integrado para OTP (`OTP_PROVIDER=twilio`): el mismo contrato y menos trabajo;
   - b) un proveedor peruano con mejor costo por SMS a Perú;
   - c) seguir sin respaldo en el piloto y aceptar el riesgo por escrito en
     `docs/fase-2/criterios-de-salida.md`.
2. **Costo por SMS y topes**: `SMS_COST_CENTS`, `SMS_DAILY_BUDGET_CENTS` y
   `SMS_MONTHLY_BUDGET_CENTS`.
3. **Remitente:** el número o nombre del que sale el SMS.

**Encargo de implementación** (para `stefanods29`; con agente, Sonnet 5.5 alcanza):

- Rama `f2-lote-c/proveedor-sms`.
- Adaptador nuevo de `SmsProvider` en `backend/src/modules/notificaciones/infrastructure/`.
- Valor nuevo de `SMS_PROVIDER` en `backend/src/shared/config/app-config.ts`, que exija sus
  credenciales en producción y nunca registre el número completo.
- Documentar las variables en `backend/.env.example` sin valores.
- Pruebas unitarias con el cliente simulado: éxito, error del proveedor, tope alcanzado y número
  inválido.
- Prueba manual registrada en `docs/fase-2/evidencias/avisos-urgentes.md`:
  - un SMS real a un teléfono del equipo, con fecha, proveedor y costo;
  - sin el número completo ni el texto del caso.
- Marca C 4.5.

---

## 12.4 · Publicación del directorio de emergencia en la nube (C 3.5)

**Quién:** el equipo decide si se autoriza staging; ejecuta `stefanods29`.

**Situación:** la consola publica el directorio con `PublicContentPublisher`
(`backend/src/modules/curaduria/application/ports.ts`). Hoy hay dos opciones:

- `filesystem`, solo para local;
- `disabled`, que responde 503.

Falta el adaptador sobre el almacenamiento de la CDN de la Fase 1 (Lote C). **Staging no está
autorizado** (reglas de trabajo): sin esa autorización solo se puede implementar y probar contra
un almacenamiento local compatible con S3.

**Qué decidir:**

1. Si se autoriza un staging, y con qué cuenta y presupuesto.
2. El bucket y la ruta pública (`emergencia/indice.json` y archivos de distrito), con caché corta
   para el índice.

**Encargo de implementación:**

- Rama `f2-lote-c/publicacion-en-la-nube`.
- Adaptador S3 compatible reutilizando la configuración de media de la Fase 1 (`MEDIA_*`) o
  variables propias `CURATION_*`.
- Valor `CURATION_PUBLISH_DRIVER=s3`.
- Prueba de integración contra MinIO en Docker.
- `npm test` en `infra/cdn` sobre lo publicado.
- Verificación en staging solo con autorización escrita. Marca C 3.5 cuando esté hecha.

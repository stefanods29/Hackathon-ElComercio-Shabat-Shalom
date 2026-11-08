# Consola web de operación (Flutter web)

Consola para coordinación, brigadas, moderación y curaduría (Fase 2, Lote C; sección 9.5). Funciona
**solo en línea**, con la misma API y sus roles operativos, y no guarda nada en el navegador: los
tokens viven en memoria y recargar la página obliga a ingresar de nuevo. La decisión de usar
Flutter web está en el [ADR 0014](../docs/adr/0014-consola-web-en-flutter.md).

Es un proyecto aparte de `app/`: no trae los plugins móviles (PowerSync, cifrado, cámara). Copia en
pequeño lo que comparte con la app: el tema accesible, `ProblemDetails` y la convención de
idempotencia.

> **Estado:** código escrito sin compilar ni probar. Los pasos para hacerlo están en
> [`docs/fase-2/lote-c-consola-web-y-avisos-urgentes/integracion.md`](../docs/fase-2/lote-c-consola-web-y-avisos-urgentes/integracion.md#cómo-compilar-y-probar).

## Correr en local

```bash
cd consola
flutter pub get && flutter gen-l10n
tool/vendor_maplibre.sh            # copia MapLibre GL JS a web/vendor/ (necesita npm)

# Solo pantallas, con datos ficticios y sin API:
flutter run -d chrome --dart-define=CONSOLE_DATA=demo

# Contra la API local (infra/docker-compose.yml y backend con OTP_PROVIDER=fake):
flutter run -d chrome --web-port=8081 \
  --dart-define=API_BASE_URL=http://localhost:3000 \
  --dart-define=MAP_STYLE_URL=http://localhost:8090/estilos/vecinal.json
```

La API solo acepta la consola si su origen está en `CONSOLE_ORIGINS` (en local,
`http://localhost:8081`; ver `backend/.env.example`). Para publicar el directorio de emergencia en
local, la API necesita `CURATION_PUBLISH_DRIVER=filesystem`.

### `--dart-define`

| Variable | Por defecto | Qué hace |
|---|---|---|
| `API_BASE_URL` | `http://localhost:3000` | API `/v1` del entorno |
| `MAP_STYLE_URL` | `http://localhost:8090/estilos/vecinal.json` | Estilo de MapLibre de la Fase 0 |
| `CONSOLE_ENV` | `local` | `local`, `staging` o `produccion` |
| `CONSOLE_DATA` | (vacío) | `demo`: todos los puertos usan dobles con datos sembrados y una franja lo dice. Nunca en `produccion` |
| `INACTIVITY_MINUTES` | `10` | Cierre de sesión por inactividad (entre 2 y 30), con aviso 60 s antes |
| `PHONE_AUTH` | `api` | `firebase`: Firebase envía el SMS en el navegador (reCAPTCHA invisible) |
| `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_SENDER_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_AUTH_DOMAIN` | (vacío) | Opciones de la app web de Firebase |

Con Firebase, conviene un archivo `consola/firebase.local.json` (no se sube: `*.local.json` está en
el `.gitignore`) y `flutter run -d chrome --dart-define-from-file=firebase.local.json`. El
dominio de la consola debe estar en los dominios autorizados de Firebase Authentication.

## Qué hay

```text
lib/
├── core/
│   ├── config/    # ConsoleEnvironment (--dart-define)
│   ├── network/   # cliente Dio, Problem Details, errores e idempotencia
│   ├── session/   # sesión en memoria, OTP (API o Firebase web), inactividad, roles
│   ├── router/    # rutas por rol y marco con navegación
│   ├── theme/     # tema accesible (misma semilla que la app) y foco visible
│   ├── time/      # reloj y formatos
│   └── ui/        # página, errores explicados, tarjetas, sondeo mientras la pestaña se ve
├── features/
│   ├── ingreso/          # OTP y entrada de demostración
│   ├── casos/            # cola por prioridad, detalle minimizado y acciones de la sección 7.2
│   ├── celdas/           # mapa de celdas (MapLibre) y tabla equivalente, umbral de 3
│   ├── turnos/           # turnos y regla de cobertura (sección 9.3)
│   ├── moderacion/       # cola de moderación de la Fase 1
│   ├── curaduria/        # editor del directorio de emergencia y publicación por versiones
│   └── avisos_urgentes/  # aviso en la consola, confirmación y medición
└── l10n/app_es.arb       # todos los textos (claves en inglés, textos en español)
```

| Sección | Roles | Fuente de datos |
|---|---|---|
| Cola de casos y detalle | coordinador, administrador; brigadista (sus casos) | Puerto `CasesRepository` → Lote B |
| Mapa de celdas | coordinador, administrador | Puerto `CellsRepository` → Lote B |
| Turnos y cobertura | coordinador, administrador | Puerto `ShiftsRepository` → Lote B |
| Moderación | moderador | `GET /v1/moderacion/casos`, `POST …/decision` (Fase 1) |
| Directorio de emergencia | coordinador, administrador (y `curador` cuando exista) | `/v1/operacion/directorio-emergencia` |
| Avisos urgentes | coordinador, administrador | `/v1/operacion/avisos-urgentes/resumen` |

Mientras el Lote B no publique su contrato, los tres puertos de Emergencias tienen una fábrica
operativa nula (`operationalCasesFactoryProvider`, `operationalCellsFactoryProvider`,
`operationalShiftsFactoryProvider`) y la pantalla explica que el módulo falta. Nunca inventa
datos fuera del modo demostración.

## Reglas de la consola

- **Nada sensible en el navegador:** sin `localStorage`, `sessionStorage`, IndexedDB ni service
  worker (`web/flutter_bootstrap.js` no lo registra). Firebase corre con `Persistence.NONE`.
- **Cada cambio lleva `Idempotency-Key`** y, cuando aplica, `versionVista`. Un 409
  `conflicto_de_version` se explica y deja recargar sin perder lo escrito.
- **Errores explicados** por su `codigo` en `core/ui/problem_notice.dart`.
- **Accesibilidad (WCAG 2.2 AA):** semántica siempre activa, orden de teclado por regiones, foco de
  3 px, insignias con ícono y texto, y diseño que no se corta con el texto al 200 %.
- **Sin ubicaciones de personas:** el mapa solo dibuja celdas; menos de 3 pedidos se muestra como
  «menos de 3».

## Despliegue

Sitio estático en Cloudflare Pages con el módulo
[`infra/cloud/modules/console-site`](../infra/cloud/modules/console-site/README.md). El build usa
`--no-web-resources-cdn` y `tool/write_headers.sh` escribe la CSP y el `index.html` sin caché.

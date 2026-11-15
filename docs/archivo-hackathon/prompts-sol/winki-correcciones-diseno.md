# Correcciones de diseño de Winki para Sol

Trabaja sobre la app Flutter de `app/`. Hoy hay entrega, así que prioriza en el orden de la lista y
sube lo que esté listo.

## Antes de empezar

1. Lee `reglas-de-trabajo.md` y `AGENTS.md`.
2. Crea la rama `f2-diseno/correcciones-winki` desde `origin/main` actualizado (`1cba6fc` o
   posterior).
3. Reglas:
   - Push solo de tu rama: sin merge, rebase, PR ni cambios en `main`.
   - En commits y documentos solo aparecen usuarios de GitHub del equipo (`JDiazD33`,
     `stefanods29`, `Defartion`, `KQuirosA`). Nada de herramientas de IA ni `Co-Authored-By`.
   - Todos los datos de ejemplo son ficticios: nombres inventados y teléfonos `+51 900 000 0xx`.
4. Contexto:
   - La app se llama **Winki**.
   - La demo (`app/tool/demo.dart`) abre siempre en modo práctica, sin servidor, con los
     repositorios en memoria.
   - El tema está en `app/lib/core/theme/accessible_theme.dart`: estilo suave con la paleta
     verde azulado `0xFF0F766E`, azul marino `0xFF1E3A5F` y ámbar `0xFFF4B942`.
   - `app/lib/core/ui/spaced.dart` separa los hijos de un `ListView`; en los `Column` usa
     `spacing:`.
   - Los textos van en `app/lib/l10n/app_es.arb`. Después de editarlo, corre `flutter gen-l10n`.

## Tareas

### 1. Modo oscuro que se vea bien y tenga sentido

Hoy el tema oscuro usa el `ColorScheme` generado y quedan colores claros fijos que desentonan.

- En `AccessibleTheme._build`, para `Brightness.dark`, define un esquema propio:
  - fondo `0xFF0F172A`;
  - superficies `0xFF1E293B` y `0xFF273449`;
  - primario verde azulado claro, `0xFF5EEAD4` o similar, con `onPrimary` oscuro;
  - textos `0xFFE2E8F0` y `0xFF94A3B8`;
  - contenedores tintados oscuros, nunca pasteles claros.
- Ajusta a ese esquema los colores fijos de estos archivos (usa los del esquema o variantes por
  brillo):
  - `features/solidaridad/presentation/widgets/post_card.dart` (`_TypePill`);
  - `features/solidaridad/presentation/wall_page.dart` (botones "Estoy en emergencia" y
    "Servicios cerca");
  - `features/directorio/presentation/directory_page.dart` (`_Fact`);
  - `features/cuenta/presentation/account_page.dart`.
- Contraste mínimo AA: 4.5:1 para texto y 3:1 para bordes e íconos.
- `test/core/theme/contrast_test.dart` y las pruebas de accesibilidad de emergencia deben seguir pasando.
- Se prueba en Cuenta → Ajustes → Apariencia → Oscuro.

### 2. Título completo en "Mis contactos de emergencia"

En el iPhone, con la flecha de volver, el título se corta.

- En `features/emergencias/presentation/emergency_contacts_page.dart`, usa un título más corto,
  "Contactos de emergencia", con una clave nueva en el `.arb`.
- Revisa los demás `AppBar(title: …)` largos y deja que pasen a dos líneas cuando haga falta
  (`maxLines: 2`, sin cortar palabras), en vez de recortarlos con "…".

### 3. Tutorial de Winki con espaciado

En `features/onboarding/tutorial_screen.dart` y `tutorial_content.dart`, cada paso es un bloque de
texto pegado. Debe quedar así:

- márgenes de 24;
- un ícono grande en un círculo tintado;
- título `headlineSmall`;
- 12 a 16 de espacio entre párrafos y viñetas;
- botones Anterior y Siguiente fijos abajo, con indicador de pasos.

### 4. Más servicios cerca, cada uno con su etiqueta

En `features/directorio/data/providers.dart` (`practiceServiceDirectoryRepositoryProvider`):

- Agrega categorías: Carpintería, Cerrajería, Costura, Cuidado de mayores, Mascotas y Delivery
  de mercado.
- Agrega de 8 a 10 servicios ficticios repartidos entre las categorías, con:
  - proveedores distintos;
  - ubicaciones dentro de `pilotMapBounds`;
  - calificaciones y número de reseñas variados;
  - algunos `availableInEmergency: true`.
- En `ServiceTile` (`directory_page.dart`), muestra la categoría como etiqueta en forma de
  píldora junto al título, con el ícono de su categoría.

### 5. Perfil del proveedor con más información

`ProviderProfilePage` está en `features/directorio/presentation/service_detail_page.dart`.

- Muestra una cabecera con avatar de la inicial, nombre y descripción.
- Agrega una fila de datos: número de servicios, promedio de estrellas (doradas) y total de
  Visto Bueno.
- Muestra "Vecino desde", tomado de `updatedAt` si no hay otra fecha.
- Lista sus servicios como tarjetas (reutiliza `ServiceTile`).
- Botones Compartir y Denunciar, con espacio entre ellos.
- Si el modelo `ProviderProfile` necesita campos nuevos, agrégalos como opcionales para no romper
  PowerSync.

### 6. Selectores de "Ofrezco un servicio" de extremo a extremo

En `features/directorio/presentation/service_form_page.dart`:

- Cada `DropdownButtonFormField` lleva `isExpanded: true`.
- El menú desplegado ocupa el ancho del campo, con `menuMaxHeight` razonable y esquinas
  redondeadas del tema.
- Cada opción muestra ícono y texto sin cortarse.

### 7. Ninguna pantalla sin forma de volver atrás

Las pantallas que no son pestañas se abren con `context.go(...)`, que borra el historial y deja la
pantalla sin flecha de volver ni barra inferior.

- Cambia a `context.push(...)` estas, que van a rutas fuera de la barra inferior:
  - `public_emergency_board_page.dart:123` (`Routes.emergency`);
  - `service_form_page.dart:61` y `:64` (al terminar, vuelve al detalle con `pushReplacement` o
    `pop` y `push`);
  - `post_detail_page.dart:40`;
  - `actions_to_review_page.dart:148`.
- Deja `go` solo para cambiar de pestaña (`/`, `/servicios`, `/emergencia/tablero`, `/cuenta`) y
  para el ingreso o el cierre de sesión.
- Revisa que toda pantalla abierta con `push` muestre la flecha de volver en su `AppBar`.

## Cómo verificar

Desde `app/`, todo debe pasar antes de subir:

- `flutter gen-l10n`
- `dart format --set-exit-if-changed lib test tool`
- `flutter analyze`
- `flutter test test/core test/features test/widget_test.dart`

Si cambian las pantallas de emergencia, regenera solo las referencias de macOS:

```bash
flutter test --update-goldens test/features/emergencias/emergency_accessibility_test.dart
```

Haz commit de las imágenes de `goldens/macos/`. Si una prueba busca un widget que con el nuevo
espaciado quedó fuera de la pantalla, agrégale `scrollUntilVisible` sin debilitar lo que verifica.

## Entrega

Sube la rama con `git push -u origin f2-diseno/correcciones-winki` y avisa a `JDiazD33` con:

- el SHA;
- qué tareas quedaron hechas y cuáles no;
- los comandos de verificación y su resultado.

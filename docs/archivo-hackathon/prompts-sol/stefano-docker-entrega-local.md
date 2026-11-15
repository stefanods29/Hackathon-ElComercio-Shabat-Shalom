# Encargo para stefanods29: probar la demo de Winki en Android (sin Docker)

La entrega es hoy a las 6:20 pm (hora de Perú). La app ahora se llama **Winki** y funciona completa
en modo práctica, sin servidor:

- muro;
- servicios;
- reseñas;
- emergencia con simulación;
- recursos;
- datos de la zona;
- avisos simulados;
- fotos locales;
- mapa.

No hace falta Docker ni Linux.

## Qué hacer (unos 30 minutos)

1. Cuando `JDiazD33` te avise que la CI de `main` terminó, descarga el artefacto `app-android-demo`
   e instala `vecinal-demo.apk` en tu Android.
2. Recorre cada pestaña y cada botón:
   - **Inicio:** publicar un favor, tomar un favor, abrir el detalle, compartir, el mapa, el menú ⋮
     (fotos, avisos, tutorial).
   - **Servicios:** buscar, filtros, abrir un servicio, escribir una reseña, dar Visto Bueno,
     publicar un servicio.
   - **Emergencia:**
     - "Simular una emergencia en la zona";
     - pedir ayuda;
     - "Simular el siguiente paso" hasta confirmar la atención;
     - recursos, contactos y datos de mi zona.
   - **Cuenta:** mis datos, niveles, cambiar zona, avisos ("Simular un aviso urgente"), fotos y modo
     sencillo.
3. Anota cada pantalla que falle, se vea cortada o se quede cargando, con una captura **sin datos
   reales**.

## Entrega

Envía la lista a `JDiazD33` antes de las 5:30 pm. No hace falta rama ni commit; si corriges algo
tú mismo, hazlo en una rama propia desde `origin/main` y avisa su SHA.

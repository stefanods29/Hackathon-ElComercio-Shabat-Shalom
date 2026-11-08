# Avisos · Lote C

`domain/` define los puertos y valida destinos. `data/` integra Firebase y mantiene el registro
durable de la API. `presentation/` ofrece ajustes, ayuda de permisos y un aviso genérico dentro
de la app. No lee publicaciones por HTTP: el detalle usa exclusivamente `wallProvider` local.

Los avisos están desactivados por defecto (`ENABLE_PUSH=false`). La app y sus pruebas pueden
compilar sin archivos de un proyecto Firebase. Activarlos no inicia una sesión de demostración:
`pushCredentialsProvider` devuelve `null` sin una sesión real.

## Integración con A (hecha)

1. `AuthenticatedApp` sobreescribe `pushCredentialsProvider` con el vecino de la sesión.
   `PushCredentials` contiene `userId`, `zoneId` y `accessToken`: una función que entrega un JWT
   vigente de ese mismo vecino, renovado si hace falta, o `null` si ya no tiene sesión.
2. Antes de cerrar la sesión, `AccountPage` llama a
   `ref.read(pushControllerProvider.notifier).signOut()`, con un límite de 5 segundos para que el
   cierre siga funcionando sin señal.
3. Conservar las claves `push.installation` y `push.pending.<usuarioId>` mientras haya una baja
   pendiente. Un `SecureStore.deleteAll()` indiscriminado elimina también esa recuperación.
   Una baja sin red queda pendiente; la app además intenta invalidar la instalación en Firebase.
4. El router recibe los destinos después de una sesión real. El Lote A aplica además su guardia
   general de autenticación al detalle y a las demás pantallas protegidas.

La cola de la API guarda tokens en almacenamiento seguro, separada por dueño. Mantiene la misma
`Idempotency-Key` en cada reintento, incluso tras reiniciar. Un JWT de otro usuario nunca se usa
para esas operaciones. El servicio reintenta al recuperar conexión y al volver a los ajustes.
Los eventos de cambio de instalación y sesión se procesan en orden. Se desuscribe el tópico
anterior al cambiar de zona; al salir da de baja e invalida el identificador de Firebase.

Firebase 17 devuelve un FID por `onRegistered`; el backend usa `fid` para enviarlo. Se mantiene
`token` como nombre del campo REST, sin exponerlo en la UI ni en logs.
El permiso se pide al tocar «Activar avisos». Denegarlo no bloquea la app. Si APNs aún no está
disponible, queda pendiente y puede reintentarse. En primer plano se muestra un texto genérico,
con enlace solo para tipos e identificadores válidos. En segundo plano no se procesa contenido
personal. Un destino recibido antes de autenticarse se conserva en almacenamiento seguro.

## Avisos urgentes y aviso de zona (Fase 2, Lote C)

- `aviso_urgente` y `modo_emergencia_activado` abren el tablero de emergencia
  (`/emergencia/tablero`), que no necesita sesión. Ninguno lleva datos del caso.
- Abrir un aviso urgente lo confirma con `POST /v1/avisos-urgentes/{id}/confirmar`
  (`data/urgent_notice_confirmation.dart`), lo que detiene su SMS de respaldo. Si la sesión todavía
  no está lista, la confirmación espera en memoria a la sesión de esa misma ejecución. Un error al
  confirmar nunca cambia el estado de los avisos: en el peor caso llega el SMS, que es su respaldo.

## Configuración local

Seguir `app/README.md`. No subir los archivos del proyecto Firebase. El equipo debe configurar
APNs, capacidades y firma de iOS antes de comprobar recepción en iPhone. Los tópicos solo llevan
información pública y el cliente puede suscribirse a ellos sin que esto conceda permisos privados.

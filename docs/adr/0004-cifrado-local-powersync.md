# 0004 · Cifrado local con `powersync` 2.x (corrige la sección 8.3)

**Contexto.** La arquitectura proponía `powersync_sqlcipher` (en beta). Al construir los cimientos
ese paquete ya no es el camino recomendado: el SDK `powersync` 2.x de Dart trae cifrado propio.

**Decisión.** Usar `powersync` 2.x con `EncryptionOptions` y SQLite3 Multiple Ciphers
(`hooks.user_defines.sqlite3.source: sqlite3mc` en `pubspec.yaml`). La clave se genera en el
dispositivo y se guarda en Keychain/Keystore (`SecureStore`).

**Consecuencias.** El Lote A (parte 2) valida que la base no abre con otra clave y que la purga
borra base y clave.

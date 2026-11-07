-- Se ejecuta una sola vez, al crear el volumen de datos de PostgreSQL en desarrollo.
-- En producción, estos roles los crea operaciones con contraseñas del gestor de secretos.

-- Almacén de buckets de PowerSync (separado de los datos de la app).
CREATE DATABASE powersync_almacen;

-- Rol de replicación de PowerSync: solo lectura de lo publicado. Las migraciones de cada
-- módulo le dan SELECT únicamente sobre las tablas que agregan a la publicación `powersync`.
CREATE ROLE powersync_rol WITH REPLICATION BYPASSRLS LOGIN PASSWORD 'powersync';

# Cola offline de 500 publicaciones en Android

- Fecha · 7 de noviembre de 2026.
- Dispositivo · Redmi Note 13, Android 15, con API y PowerSync locales por USB.
- App · Compilación de depuración, commit `b14c39a59efe67632825815409614d776313ddaf`.
- Datos · Una cuenta y una zona sintéticas, aisladas de la zona piloto.

## Procedimiento

1. Con PowerSync desconectado, se guardaron 500 publicaciones mediante el repositorio de la app.
2. Se cerró y volvió a abrir la base cifrada. La cola conservó las 500 operaciones.
3. Se conectó PowerSync. Se verificaron los estados locales, las publicaciones y los eventos
   guardados en PostgreSQL.
4. Se retiraron las publicaciones, los registros de idempotencia, los eventos, la cuenta y la zona de prueba.

## Resultados

| Medición | Resultado |
| --- | --- |
| Tiempo de guardado local | 3,092 s |
| Tiempo desde la conexión hasta vaciar la cola | 19,524 s |
| Publicaciones totales y únicas en PostgreSQL | 500 de 500 |
| Respuestas idempotentes completadas | 500 |
| Eventos de publicación | 500 |
| Pérdidas y duplicados observados | 0 y 0 |

La prueba se ejecutó con `integration_test/offline_queue_stress_test.dart`. Sigue pendiente
la matriz de campo de Android con señal débil, reinicio del dispositivo y batería baja.
La repetición de campo en iPhone se omitió por disponibilidad, con autorización del
usuario el 7 de noviembre de 2026; no se cuenta como una prueba aprobada.

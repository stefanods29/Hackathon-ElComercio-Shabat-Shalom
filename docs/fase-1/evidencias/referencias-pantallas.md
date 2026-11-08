# Referencias de las pantallas del piloto

Consulta: 7 de noviembre de 2026.

## Directorio de emergencia

- [Teléfonos de emergencia, PCM](https://www.gob.pe/547): central policial 105, bomberos 116 y SAMU 106, con el alcance territorial descrito en la fuente.
- [Contacto y números de emergencia del Ministerio de Salud](https://www.gob.pe/institucion/minsa/contacto-y-numeros-de-emergencias): confirma el número 106 de SAMU.

La copia de respaldo se limita a esos números institucionales. No se agregan puntos de
encuentro, albergues ni centros de salud ficticios como si fueran servicios operativos.
Los puntos de los escenarios automatizados son fixtures de prueba.

## Adaptadores de plataforma

- [url_launcher](https://pub.dev/packages/url_launcher): abrir el marcador con un URI `tel:`, sin efectuar una llamada de prueba.
- [speech_to_text](https://pub.dev/packages/speech_to_text): inicialización bajo acción del usuario, opciones de escucha y permisos de micrófono/reconocimiento. El dictado puede depender del servicio del sistema y no se promete funcionamiento sin red.
- [share_plus](https://pub.dev/packages/share_plus): hoja de compartir y archivos mediante `ShareParams`; no se confunde compartir con confirmar que otra persona recibió el archivo.

Las pruebas de widgets sustituyen esos adaptadores por dobles para no abrir llamadas,
micrófono ni aplicaciones externas durante las comprobaciones automáticas.

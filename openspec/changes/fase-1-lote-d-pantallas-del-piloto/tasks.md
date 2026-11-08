# Tasks

## 1. Parte 1 · Directorio: buscar servicios cerca

- [ ] 1.1 Rutas `/servicios` y `/servicios/:id` y pantalla "Servicios cerca" con categorías grandes, búsqueda sin tildes y lista con distancia, estrellas y "Visto Bueno de tu zona", sobre el doble del Lote A; verificar con pruebas de widgets (búsqueda "gasfiter", lista y detalle)
- [ ] 1.2 Filtro "Útil en emergencia" y acceso al mapa sin conexión con ubicaciones aproximadas; verificar con una prueba de widgets del filtro
- [ ] 1.3 "Actualizado hace X" y estado vacío sin señal; verificar con una prueba con `FakeSyncService` desconectado
- [ ] 1.4 Accesibilidad de las pantallas (texto al 200 %, 48 dp, etiquetas para TalkBack, contraste); verificar con las guías de `meetsGuideline` y una prueba al 200 %
- [ ] 1.5 Compilar y depurar: `dart format lib test`, `tool/verify.sh` y CI en verde

## 2. Parte 2 · Perfil del proveedor y "Ofrezco un servicio"

- [ ] 2.1 Ruta `/proveedores/:id` y perfil con servicios, resumen de reseñas, Visto Bueno y botón compartir (doble hasta C3), sin datos de contacto; verificar con pruebas de widgets
- [ ] 2.2 "Ofrezco un servicio" en la grilla del botón "+" con formulario mínimo prellenado (categoría y ubicación sugeridas); verificar con una prueba de widgets que cuenta exactamente 3 toques y el estado "Guardado en tu celular" sin señal
- [ ] 2.3 Editar y retirar un servicio con el motivo y la alternativa de cada rechazo (`conflicto_de_version`, `cuenta_suspendida`) en "Acciones por revisar"; verificar con pruebas de widgets
- [ ] 2.4 Compilar y depurar: `tool/verify.sh` y CI en verde

## 3. Parte 3 · Reseñas con fotos, Visto Bueno y denuncias

- [ ] 3.1 Pantalla de reseña con estrellas accesibles, comentario con dictado por voz (`speech_to_text`, con permisos y textos en español) y hasta 3 fotos con `PhotoPicker` (doble hasta C2); verificar con pruebas de widgets y del lector de pantalla
- [ ] 3.2 Estado "En revisión" de las reseñas propias y lista de reseñas publicadas del servicio; verificar con pruebas de widgets sobre el doble
- [ ] 3.3 Botón Visto Bueno con su estado y la explicación del nivel 2; verificar con pruebas de widgets
- [ ] 3.4 "Denunciar" en publicaciones, reseñas, servicios y fotos, con la lista de motivos y "Gracias, lo revisaremos"; verificar con pruebas de widgets
- [ ] 3.5 Mensajes y alternativas para `resena_duplicada`, `no_puedes_resenarte`, `cuenta_muy_nueva`, `fuera_de_tu_zona` y `limite_diario_alcanzado`; verificar con pruebas de cada código
- [ ] 3.6 Compilar y depurar: `tool/verify.sh` y CI en verde

## 4. Parte 4 · "Estoy en emergencia" y tutorial actualizado

- [ ] 4.1 Botón "Estoy en emergencia" siempre visible en el inicio, también en el modo sencillo; verificar con una prueba de widgets en ambos modos
- [ ] 4.2 Completar `/emergencia` con los mensajes de la sección 9.4, el botón de llamar (`url_launcher`, `tel:`) y los puntos de encuentro en el mapa sin conexión; verificar con una prueba de widgets del botón de llamar y otra sin red con la copia de respaldo
- [ ] 4.3 Tutorial y modo práctica para las pantallas nuevas, con contenido desde un JSON de la CDN y una copia incluida; verificar con pruebas de widgets sin conexión
- [ ] 4.4 Revisión de los textos con el equipo; dejar la lista en la evidencia de la parte
- [ ] 4.5 Compilar y depurar: `tool/verify.sh` y CI en verde

## 5. Parte 5 · Consentimiento, "Mis datos" y niveles

- [ ] 5.1 Puerto `PrivacyRepository` con su doble y pantallas de consentimiento por finalidad al registrarse; verificar con pruebas de widgets (aceptar, rechazar una finalidad opcional, seguir usando la app)
- [ ] 5.2 "Mis datos": ver, exportar como archivo y corregir el nombre visible; verificar con pruebas de widgets
- [ ] 5.3 "Borrar mi cuenta" con la explicación de lo que se borra, confirmación explícita y uso de `AuthRepository.deleteAccount`; verificar con una prueba de widgets del flujo de borrado y sin conexión
- [ ] 5.4 "Cómo subir de nivel" con el nivel actual y "Cambiar de zona" con el aviso de acciones pendientes del Lote A; verificar con pruebas de widgets, contraste y tamaños táctiles
- [ ] 5.5 Ejecutar localmente buscar, reseñar y abrir el directorio de emergencia con 5 perfiles y datos simulados; registrar el resultado en `docs/fase-1/evidencias/usabilidad.md`. La prueba presencial con adultos mayores se omite por instrucción expresa del usuario del 7 de noviembre de 2026 y no se cuenta como aprobada
- [ ] 5.6 Compilar y depurar: `tool/verify.sh` y CI en verde

## Workflow follow-up

- Entregar cada parte en su rama `f1-lote-d/parte-<n>-<tema>` y pedir la revisión del Lote A.
- Archivar el change cuando el Lote A integre la última parte y la CI esté en verde.

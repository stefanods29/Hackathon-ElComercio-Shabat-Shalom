Las casillas reflejan implementación, no validación ni aceptación. La rama se escribió sin compilar
ni probar. En la integración en `main` el módulo compiló, pasó `npm run verify` y la prueba de
integración del hito H2 por la API (`docs/fase-2/integracion.md`); las tareas de CI siguen abiertas
hasta verla en verde.

## 1. Parte 1 · Eventos
- [x] 1.1 Definir contrato, cobertura y puerto de alertas oficiales.
- [x] 1.2 Implementar persistencia, activación y outbox.
- [x] 1.3 Compilar, depurar y verificar en CI cuando se autorice la validación. Evidencia: [CI de la versión integrada](../../../docs/fase-2/evidencias/ci-integracion.md).

## 2. Parte 2 · Pedidos
- [x] 2.1 Implementar máquina de estados, idempotencia y concurrencia.
- [x] 2.2 Separar detalles privados y autorizar lecturas auditadas.
- [x] 2.3 Compilar, depurar y verificar transiciones y permisos en CI. Evidencia: [CI de la versión integrada](../../../docs/fase-2/evidencias/ci-integracion.md).

## 3. Parte 3 · Operación
- [x] 3.1 Implementar habilitaciones, grupos, turnos y asignaciones.
- [x] 3.2 Implementar escalamiento durable y recuperación de trabajos.
- [ ] 3.3 Compilar, depurar y verificar tiempos y reintentos en CI.

## 4. Parte 4 · Recursos
- [x] 4.1 Implementar reportes, confirmación única y verificación.
- [x] 4.2 Implementar frescura y agregados con umbral mínimo de tres.
- [ ] 4.3 Compilar, depurar y verificar concurrencia y supresión en CI.

## 5. Parte 5 · Privacidad y cierre
- [x] 5.1 Implementar requisitos operativos, auditoría y anonimización por lotes.
- [x] 5.2 Documentar integración con A/C/D, configuración y pendientes.
- [ ] 5.3 Compilar, depurar, revisar migraciones y verificar seguridad en CI.

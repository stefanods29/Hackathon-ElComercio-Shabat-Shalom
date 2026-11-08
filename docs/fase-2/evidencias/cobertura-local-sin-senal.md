# CAM-01 · Primer estado de cobertura al abrir sin señal

La prueba `sin señal conserva la última confirmación hasta que deja de ser reciente` falló de
forma intermitente en macOS y en la CI de Linux. Esperaba cobertura confirmada y recibió
`false` en el primer estado, aun con una confirmación reciente en la base cifrada.
[Primera ejecución en Linux](https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom/actions/runs/42503084673/attempts/1).

El tablero observa la cobertura y los pedidos mediante dos consultas locales. Si la primera
respuesta de pedidos llegaba antes de la de cobertura, el repositorio emitía con la cobertura
todavía sin leer. El formulario seguía comprobando la vigencia en la base antes de guardar.

El repositorio espera la primera respuesta de ambas consultas. La prueba exige que el primer
estado conserve la fecha de la confirmación local y comprueba que la cobertura deja de ser
válida al vencer. También verifica que un pedido se puede guardar mientras está vigente y
se rechaza después del vencimiento.

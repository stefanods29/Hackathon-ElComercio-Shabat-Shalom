# Contrato de la API

`openapi.yaml` (OpenAPI 3.1) es la fuente de verdad de la API `/v1`: primero se cambia el
contrato, luego el código. Rutas, campos y códigos de error van en español. Validación:
`npx @redocly/cli lint contracts/openapi.yaml` (también en CI).

/**
 * Fronteras del monolito modular (sección 4.1 de la arquitectura), verificadas en CI con
 * `npm run boundaries`. `npm run graph` dibuja el grafo de módulos en docs/grafos/.
 * @type {import('dependency-cruiser').IConfiguration}
 */
module.exports = {
  forbidden: [
    {
      name: 'no-cycles',
      severity: 'error',
      comment: 'Los ciclos entre archivos impiden separar módulos y confunden el orden de carga.',
      from: {},
      to: { circular: true },
    },
    {
      name: 'modules-only-through-public-interface',
      severity: 'error',
      comment:
        'Un módulo solo usa a otro a través de su index.ts (interfaz pública) o de eventos de dominio.',
      from: { path: '^src/modules/([^/]+)/' },
      to: {
        path: '^src/modules/',
        pathNot: ['^src/modules/$1/', '^src/modules/[^/]+/index\\.ts$'],
      },
    },
    {
      name: 'pure-domain',
      severity: 'error',
      comment: 'El dominio es TypeScript puro: sin NestJS, sin base de datos, sin HTTP.',
      from: { path: '^src/(modules/[^/]+|shared)/domain/' },
      to: {
        path: [
          '^src/(modules/[^/]+)/(application|infrastructure|api)/',
          '^src/shared/(api|auth|queues|config|db|idempotency|outbox|health)/',
          '(^|/)node_modules/(@nestjs|kysely|pg|express|jose|zod)/',
        ],
      },
    },
    {
      name: 'application-without-adapters',
      severity: 'error',
      comment: 'Los casos de uso dependen de puertos (interfaces), nunca de adaptadores concretos.',
      from: { path: '^src/modules/[^/]+/application/', pathNot: '\\.spec\\.ts$' },
      to: {
        path: [
          '^src/modules/[^/]+/(infrastructure|api)/',
          '^src/shared/.+\\.(kysely|postgres|memory)\\.ts$',
          '(^|/)node_modules/(kysely|pg|express)/',
        ],
      },
    },
    {
      name: 'shared-knows-no-modules',
      severity: 'error',
      comment: 'El núcleo compartido no depende de ningún módulo de negocio.',
      from: { path: '^src/shared/' },
      to: { path: '^src/modules/' },
    },
    {
      name: 'only-app-module-composes',
      severity: 'error',
      comment: 'Solo la raíz de composición importa los módulos de NestJS de todos.',
      from: { path: '^src/', pathNot: ['^src/app\\.module\\.ts$', '^src/modules/', '^src/workers/'] },
      to: { path: '^src/modules/' },
    },
    {
      name: 'no-test-doubles-in-production',
      severity: 'error',
      comment: 'Los adaptadores en memoria son para pruebas; el código de producción no los usa.',
      from: { path: '^src/', pathNot: ['\\.spec\\.ts$', '^src/shared/shared\\.module\\.ts$'] },
      to: { path: '\\.memory\\.ts$' },
    },
  ],
  options: {
    doNotFollow: { path: 'node_modules' },
    exclude: { path: '(^|/)(dist|coverage)/' },
    tsPreCompilationDeps: true,
    tsConfig: { fileName: 'tsconfig.json' },
    enhancedResolveOptions: {
      exportsFields: ['exports'],
      conditionNames: ['import', 'require', 'node', 'default', 'types'],
      extensions: ['.ts', '.js', '.json'],
    },
    reporterOptions: {
      mermaid: { minify: false },
    },
  },
};

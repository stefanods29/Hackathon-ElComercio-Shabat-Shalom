/**
 * `npm run graph`: draws the dependency graph between backend modules (Mermaid) into
 * docs/grafos/dependencias-backend.md, to review it in PRs that touch module boundaries.
 */
import { execFileSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import path from 'node:path';

const binary = path.join(
  'node_modules',
  'dependency-cruiser',
  'bin',
  'dependency-cruiser.mjs',
);
const mermaid = execFileSync(
  process.execPath,
  [
    binary,
    'src',
    '--config',
    '.dependency-cruiser.cjs',
    '--include-only',
    '^src',
    '--exclude',
    '\\.spec\\.ts$',
    '--output-type',
    'mermaid',
    '--collapse',
    '^src/(modules/[^/]+|shared/[^/]+)',
  ],
  { encoding: 'utf8' },
);

const target = path.join('..', 'docs', 'grafos', 'dependencias-backend.md');
writeFileSync(
  target,
  [
    '# Grafo de dependencias del backend',
    '',
    'Generado con `cd backend && npm run graph` (dependency-cruiser). No lo edites a mano.',
    'Cada flecha es un `import`. Los módulos de negocio solo se conocen desde `app.module.ts`',
    'y todos dependen de `shared`, nunca al revés (reglas en `backend/.dependency-cruiser.cjs`).',
    '',
    '```mermaid',
    mermaid.trim(),
    '```',
    '',
  ].join('\n'),
);
console.log(`Grafo actualizado en ${target}`);

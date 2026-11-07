/**
 * `npm run graph`: draws the dependency graph between backend modules (Mermaid) into
 * docs/grafos/dependencias-backend.md, to review it in PRs that touch module boundaries.
 */
import { execFileSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import path from 'node:path';

const binary = path.join(
  'node_modules',
  '.bin',
  process.platform === 'win32' ? 'depcruise.cmd' : 'depcruise',
);
const mermaid = execFileSync(
  binary,
  [
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
  { encoding: 'utf8', shell: process.platform === 'win32' },
);

const target = path.join('..', 'docs', 'grafos', 'dependencias-backend.md');
writeFileSync(
  target,
  [
    '# Grafo de dependencias del backend',
    '',
    'Generado con `cd backend && npm run graph` (dependency-cruiser). No lo edites a mano.',
    'Cada flecha es un `import`. Las raíces de composición son `app.module.ts` y `workers/`',
    'y todos dependen de `shared`, nunca al revés (reglas en `backend/.dependency-cruiser.cjs`).',
    '',
    '```mermaid',
    mermaid.trim(),
    '```',
    '',
  ].join('\n'),
);
console.log(`Grafo actualizado en ${target}`);

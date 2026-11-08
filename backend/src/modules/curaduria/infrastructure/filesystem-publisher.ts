import { randomUUID } from 'node:crypto';
import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import path from 'node:path';
import type { PublicContentPublisher } from '../application/ports.js';

/**
 * Development adapter: writes into the local CDN folder (`infra/cdn/publico`), which nginx serves
 * on http://localhost:8090. Writes are atomic (temporary file + rename) so nginx never serves a
 * half-written file. Forbidden in production by the configuration.
 */
export class FilesystemPublisher implements PublicContentPublisher {
  readonly enabled = true;
  private readonly root: string;

  constructor(root: string) {
    this.root = path.resolve(root);
  }

  async read(relativePath: string): Promise<Buffer | null> {
    try {
      return await readFile(this.resolve(relativePath));
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') return null;
      throw error;
    }
  }

  async write(relativePath: string, body: Buffer): Promise<void> {
    const target = this.resolve(relativePath);
    await mkdir(path.dirname(target), { recursive: true });
    const temporary = `${target}.${randomUUID()}.tmp`;
    await writeFile(temporary, body);
    await rename(temporary, target);
  }

  /** Only paths inside the public root: the file name is validated, this is a second barrier. */
  private resolve(relativePath: string): string {
    const target = path.resolve(this.root, relativePath);
    if (!target.startsWith(this.root + path.sep)) {
      throw new Error('La ruta queda fuera del contenido público');
    }
    return target;
  }
}

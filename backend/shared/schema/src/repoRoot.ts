import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

let cached: string | null = null;

/** Walk up from a module file until the monorepo root package.json is found. */
export function findRepoRoot(fromFile = import.meta.url): string {
  if (cached) return cached;

  let dir = dirname(fileURLToPath(fromFile));
  for (let i = 0; i < 8; i++) {
    const pkgPath = resolve(dir, 'package.json');
    if (existsSync(pkgPath)) {
      try {
        const pkg = JSON.parse(readFileSync(pkgPath, 'utf-8')) as {
          name?: string;
          workspaces?: unknown;
        };
        if (pkg.name === 'janavaani-backend' || pkg.name === 'peoples-priorities' || pkg.workspaces) {
          cached = dir;
          return dir;
        }
      } catch {
        /* try parent */
      }
    }
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }

  cached = process.cwd();
  return process.cwd();
}

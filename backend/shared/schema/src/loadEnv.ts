import { config } from 'dotenv';
import { resolve } from 'node:path';
import { findRepoRoot } from './repoRoot.js';

/** Load `.env` from the monorepo root (works when cwd is a workspace package). */
export function loadEnv(): void {
  config({ path: resolve(findRepoRoot(), '.env') });
}

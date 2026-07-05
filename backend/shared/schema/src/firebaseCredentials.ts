import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { findRepoRoot } from './repoRoot.js';

export interface FirebaseServiceAccount {
  projectId: string;
  clientEmail: string;
  privateKey: string;
}

/** Resolve a repo-relative path like `infra/serviceAccountKey.json`. */
export function resolveServiceAccountPath(configured: string): string {
  if (existsSync(configured)) return configured;
  const fromCwd = resolve(process.cwd(), configured);
  if (existsSync(fromCwd)) return fromCwd;
  const fromRepo = resolve(findRepoRoot(), configured);
  if (existsSync(fromRepo)) return fromRepo;
  return configured;
}

/** Resolve Admin SDK credentials from env vars or a service-account JSON file. */
export function resolveFirebaseCredentials(): FirebaseServiceAccount | null {
  const jsonPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH?.trim();
  if (jsonPath) {
    const resolved = resolveServiceAccountPath(jsonPath);
    if (existsSync(resolved)) {
      const raw = JSON.parse(readFileSync(resolved, 'utf-8')) as {
        project_id?: string;
        client_email?: string;
        private_key?: string;
      };
      if (raw.project_id && raw.client_email && raw.private_key) {
        return {
          projectId: raw.project_id,
          clientEmail: raw.client_email,
          privateKey: raw.private_key,
        };
      }
    }
  }

  const projectId = process.env.FIREBASE_PROJECT_ID?.trim();
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL?.trim();
  const privateKeyRaw = process.env.FIREBASE_PRIVATE_KEY?.trim();
  if (!projectId || !clientEmail || !privateKeyRaw) return null;

  let key = privateKeyRaw;
  if (
    (key.startsWith('"') && key.endsWith('"')) ||
    (key.startsWith("'") && key.endsWith("'"))
  ) {
    key = key.slice(1, -1);
  }
  return {
    projectId,
    clientEmail,
    privateKey: key.replace(/\\n/g, '\n'),
  };
}

export function hasFirebaseCredentials(): boolean {
  return resolveFirebaseCredentials() !== null;
}

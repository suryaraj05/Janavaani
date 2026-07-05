import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { findRepoRoot } from './repoRoot.js';

export interface FirebaseServiceAccount {
  projectId: string;
  clientEmail: string;
  privateKey: string;
}

/** Normalize PEM private key from env / copy-paste (Render, Railway, etc.). */
export function normalizeFirebasePrivateKey(raw: string): string {
  let key = raw.trim();

  for (let i = 0; i < 2; i++) {
    if (
      (key.startsWith('"') && key.endsWith('"')) ||
      (key.startsWith("'") && key.endsWith("'"))
    ) {
      key = key.slice(1, -1).trim();
    }
  }

  // Whole service-account JSON pasted into FIREBASE_PRIVATE_KEY by mistake.
  if (key.startsWith('{')) {
    try {
      const parsed = JSON.parse(key) as { private_key?: string };
      if (typeof parsed.private_key === 'string') {
        key = parsed.private_key;
      }
    } catch {
      /* not JSON */
    }
  }

  key = key.replace(/\\n/g, '\n').replace(/\r\n/g, '\n').replace(/\r/g, '\n');

  // PEM pasted as one line (common from env converters).
  if (!key.includes('\n') && key.includes('-----BEGIN PRIVATE KEY-----')) {
    key = key
      .replace('-----BEGIN PRIVATE KEY-----', '-----BEGIN PRIVATE KEY-----\n')
      .replace('-----END PRIVATE KEY-----', '\n-----END PRIVATE KEY-----');
    if (!key.endsWith('\n')) key += '\n';
  }

  return key;
}

export function isValidFirebasePrivateKey(key: string): boolean {
  return (
    key.includes('-----BEGIN PRIVATE KEY-----') &&
    key.includes('-----END PRIVATE KEY-----') &&
    key.length > 100
  );
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

  const privateKey = normalizeFirebasePrivateKey(privateKeyRaw);
  if (!isValidFirebasePrivateKey(privateKey)) {
    console.error(
      'FIREBASE_PRIVATE_KEY looks invalid — expected PEM with BEGIN/END PRIVATE KEY lines.\n' +
        'Run: npm run print:render-firebase-key --prefix backend',
    );
  }

  return {
    projectId,
    clientEmail,
    privateKey,
  };
}

export function hasFirebaseCredentials(): boolean {
  return resolveFirebaseCredentials() !== null;
}

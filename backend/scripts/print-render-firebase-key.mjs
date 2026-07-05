#!/usr/bin/env node
/**
 * Print Render-ready FIREBASE_PRIVATE_KEY (escaped newlines, no secrets in git).
 * Usage: node scripts/print-render-firebase-key.mjs [path-to-service-account.json]
 */
import { readFileSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const backendRoot = resolve(__dirname, '..');

const candidates = [
  process.argv[2],
  'infra/serviceAccountKey.json',
  'infra/servicekey.json',
].filter(Boolean);

let jsonPath = null;
for (const c of candidates) {
  const p = resolve(backendRoot, c);
  if (existsSync(p)) {
    jsonPath = p;
    break;
  }
}

if (!jsonPath) {
  console.error('No service account JSON found. Pass path:');
  console.error('  node scripts/print-render-firebase-key.mjs infra/serviceAccountKey.json');
  process.exit(1);
}

const sa = JSON.parse(readFileSync(jsonPath, 'utf-8'));
if (!sa.private_key || !sa.client_email || !sa.project_id) {
  console.error('Invalid service account file:', jsonPath);
  process.exit(1);
}

const forRender = sa.private_key.replace(/\n/g, '\\n');

console.log('');
console.log('Render Environment — paste these values (no extra quotes):');
console.log('');
console.log('FIREBASE_PROJECT_ID');
console.log(sa.project_id);
console.log('');
console.log('FIREBASE_CLIENT_EMAIL');
console.log(sa.client_email);
console.log('');
console.log('FIREBASE_PRIVATE_KEY');
console.log(forRender);
console.log('');
console.log('Set the same three vars on janavaani-enrich and janavaani-intake.');
console.log('Then: Manual Deploy on each service.');
console.log('');

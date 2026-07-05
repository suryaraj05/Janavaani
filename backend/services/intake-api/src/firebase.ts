import admin from 'firebase-admin';
import type { Firestore } from 'firebase-admin/firestore';
import { resolveFirebaseCredentials } from '@pp/schema';

let db: Firestore | null = null;
let credentialsWarned = false;

export function initFirebase(): Firestore {
  if (db) return db;

  const creds = resolveFirebaseCredentials();

  if (!admin.apps.length) {
    if (creds) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId: creds.projectId,
          clientEmail: creds.clientEmail,
          privateKey: creds.privateKey,
        }),
        storageBucket: `${creds.projectId}.appspot.com`,
      });
    } else {
      if (!credentialsWarned) {
        credentialsWarned = true;
        console.warn(
          'Firebase Admin credentials missing — Firestore reads/writes will fail.\n' +
            'Set FIREBASE_CLIENT_EMAIL + FIREBASE_PRIVATE_KEY in .env, or place your\n' +
            'service-account JSON at infra/serviceAccountKey.json and set FIREBASE_SERVICE_ACCOUNT_PATH.',
        );
      }
      admin.initializeApp({
        projectId: process.env.FIREBASE_PROJECT_ID?.trim() ?? 'peoples-priorities-dev',
      });
    }
  }

  db = admin.firestore();
  return db;
}

export function getDb(): Firestore {
  return db ?? initFirebase();
}

export { admin };

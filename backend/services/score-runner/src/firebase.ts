import admin from 'firebase-admin';
import type { Firestore } from 'firebase-admin/firestore';
import { resolveFirebaseCredentials } from '@pp/schema';

let db: Firestore | null = null;

export function getDb(): Firestore {
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
      });
    } else {
      admin.initializeApp({
        projectId: process.env.FIREBASE_PROJECT_ID?.trim() ?? 'peoples-priorities-dev',
      });
    }
  }

  db = admin.firestore();
  return db;
}

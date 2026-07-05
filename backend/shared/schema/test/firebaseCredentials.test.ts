import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  normalizeFirebasePrivateKey,
  isValidFirebasePrivateKey,
} from '../src/firebaseCredentials.js';

const fakeBody = 'MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC9';
const fakePem = `-----BEGIN PRIVATE KEY-----\n${fakeBody}\n-----END PRIVATE KEY-----\n`;
const fakePemOneLine = `-----BEGIN PRIVATE KEY-----${fakeBody}-----END PRIVATE KEY-----`;

describe('normalizeFirebasePrivateKey', () => {
  it('converts escaped newlines', () => {
    const raw = fakePem.replace(/\n/g, '\\n');
    assert.equal(normalizeFirebasePrivateKey(raw), fakePem);
  });

  it('strips wrapping quotes', () => {
    assert.equal(normalizeFirebasePrivateKey(`"${fakePemOneLine}"`), fakePem);
  });

  it('extracts private_key from pasted JSON', () => {
    const json = JSON.stringify({ private_key: fakePem });
    assert.equal(normalizeFirebasePrivateKey(json), fakePem);
  });

  it('splits one-line PEM', () => {
    const normalized = normalizeFirebasePrivateKey(fakePemOneLine);
    assert.ok(normalized.includes('\n'));
    assert.ok(isValidFirebasePrivateKey(normalized));
  });
});

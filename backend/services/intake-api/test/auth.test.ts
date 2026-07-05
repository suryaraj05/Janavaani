import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { roleForRegistration } from '../src/routes/auth.js';

describe('auth registration role enforcement', () => {
  it('always assigns citizen regardless of client-supplied role intent', () => {
    assert.equal(roleForRegistration(), 'citizen');
  });
});

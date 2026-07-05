import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { canReadSubmission } from '../src/lib/submissionAccess.js';

describe('submission ownership', () => {
  const citizen = { uid: 'u1', role: 'citizen' as const };
  const mp = { uid: 'u2', role: 'mp' as const };

  it('allows citizens to read only their own submission hash', () => {
    assert.equal(canReadSubmission(citizen, 'hash-a', 'hash-a'), true);
    assert.equal(canReadSubmission(citizen, 'hash-b', 'hash-a'), false);
    assert.equal(canReadSubmission(citizen, null, 'hash-a'), false);
  });

  it('allows mp to read any submission', () => {
    assert.equal(canReadSubmission(mp, 'hash-b', 'hash-a'), true);
    assert.equal(canReadSubmission(mp, null, 'hash-a'), true);
  });
});

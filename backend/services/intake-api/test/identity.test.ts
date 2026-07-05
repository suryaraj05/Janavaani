import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

/** Mirrors post-link unique_citizen recompute from member submission hashes. */
function uniqueCitizensFromMemberHashes(hashes: (string | undefined)[]): number {
  const set = new Set<string>();
  for (const h of hashes) {
    if (h) set.add(h);
  }
  return set.size;
}

describe('identity link de-duplication', () => {
  it('collapses app + WhatsApp hashes to one citizen after link', () => {
    const uidHash = 'hmac256:uid';
    const phoneHash = 'hmac256:phone';

    const beforeLink = uniqueCitizensFromMemberHashes([uidHash, phoneHash]);
    assert.equal(beforeLink, 2);

    const afterLink = uniqueCitizensFromMemberHashes([phoneHash, phoneHash]);
    assert.equal(afterLink, 1);
  });

  it('leaves unrelated citizens unchanged', () => {
    const a = 'hmac256:a';
    const b = 'hmac256:b';
    assert.equal(uniqueCitizensFromMemberHashes([a, b]), 2);
  });
});

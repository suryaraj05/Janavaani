import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { textSimilarity } from '../src/clustering.js';

describe('textSimilarity', () => {
  it('matches similar school upgrade summaries', () => {
    const a =
      'Upgrade village school beyond grade 7 / secondary school access; ~6 km travel to Ghatkesar';
    const b =
      'No high school in village; children travel to Ghatkesar — requests secondary school';
    const sim = textSimilarity(a, b);
    assert.ok(sim >= 0.3);
  });

  it('separates vocational from school demands', () => {
    const school =
      'Upgrade village school beyond grade 7 / secondary school access; ~6 km travel to Ghatkesar';
    const iti = 'Establish vocational training institute (ITI) in the area';
    const sim = textSimilarity(school, iti);
    assert.ok(sim < 0.5);
  });
});

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  compositeScore,
  demandTerm,
  confidenceTerm,
  recencyTerm,
  SCORE_WEIGHTS,
} from '../../shared/schema/src/config.js';

/**
 * Phase E acceptance test — composite ranking with evidence-backed vs demand-only clusters.
 */
describe('composite ranking (Phase E)', () => {
  it('ranks evidence-backed flagship school above vocational demand-only cluster', () => {
    const school = compositeScore({
      evidence: 0.85,
      demand: 0.88,
      confidence: 0.82,
      recency: 0.92,
    });
    const vocational = compositeScore({
      evidence: null,
      demand: 0.45,
      confidence: 0.55,
      recency: 0.85,
    });

    assert.ok(
      school.total > vocational.total,
      `school (${school.total.toFixed(1)}) should outrank vocational (${vocational.total.toFixed(1)})`,
    );
    assert.equal(school.evidence_available, true);
    assert.equal(vocational.evidence_available, false);
  });

  it('uses named tunable weights from config', () => {
    const sum =
      SCORE_WEIGHTS.evidence +
      SCORE_WEIGHTS.demand +
      SCORE_WEIGHTS.confidence +
      SCORE_WEIGHTS.recency;
    assert.ok(Math.abs(sum - 1) < 0.001);
    assert.equal(SCORE_WEIGHTS.evidence, 0.35);
  });

  it('renormalizes when evidence is unavailable — never silently zeroes demand', () => {
    const score = compositeScore({
      evidence: null,
      demand: 0.8,
      confidence: 0.7,
      recency: 0.9,
    });
    assert.ok(score.total > 50, 'demand-only cluster should still score meaningfully');
    assert.equal(score.evidence_available, false);
  });
});

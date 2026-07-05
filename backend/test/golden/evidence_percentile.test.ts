import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  computeSchoolUpgradeIndicators,
  evidenceScoreForMandal,
  type UdiseSchool,
} from '../../shared/schema/src/evidence.js';
import { findRepoRoot } from '../../shared/schema/src/repoRoot.js';

/**
 * Phase C acceptance test — percentile-ranked evidence scores across mandals.
 * Ghatkesar (TS-0417) has the worst seat gap in fixtures and must score highest.
 */
describe('evidence percentile ranking (Phase C)', () => {
  const schools = JSON.parse(
    readFileSync(join(findRepoRoot(), 'fixtures/udise_schools.json'), 'utf-8'),
  ) as UdiseSchool[];

  const centroids: Record<string, { lat: number; lng: number }> = {
    'TS-0417': { lat: 17.443, lng: 78.683 },
    'TS-0418': { lat: 17.49, lng: 78.56 },
    'TS-0419': { lat: 17.405, lng: 78.56 },
  };

  it('ranks Ghatkesar highest on school_upgrade evidence among loaded mandals', () => {
    const indicators = computeSchoolUpgradeIndicators(schools, centroids);
    assert.ok(indicators.length >= 3, 'expected at least 3 mandals with UDISE data');

    const scores = indicators
      .map((i) => ({
        mandal: i.mandal_code,
        result: evidenceScoreForMandal(indicators, i.mandal_code),
      }))
      .filter((s) => s.result !== null) as Array<{
      mandal: string;
      result: NonNullable<ReturnType<typeof evidenceScoreForMandal>>;
    }>;

    assert.ok(scores.length >= 3);

    scores.sort((a, b) => b.result.score - a.result.score);
    const top = scores[0];
    const ghatkesar = scores.find((s) => s.mandal === 'TS-0417');

    assert.ok(ghatkesar, 'TS-0417 Ghatkesar must have evidence scores');
    assert.equal(
      top.mandal,
      'TS-0417',
      `Ghatkesar should rank highest; got ${top.mandal} (${top.result.score.toFixed(3)})`,
    );
    assert.ok(
      ghatkesar.result.score > 0.5,
      `Ghatkesar evidence score should be high, got ${ghatkesar.result.score}`,
    );
  });

  it('uses percentile ranks so scores are comparable across indicators', () => {
    const indicators = computeSchoolUpgradeIndicators(schools, centroids);
    for (const row of indicators) {
      const result = evidenceScoreForMandal(indicators, row.mandal_code);
      assert.ok(result);
      assert.ok(result.score >= 0 && result.score <= 1);
      assert.ok(result.rows.length >= 2);
      assert.equal(result.rows[0].dataset, 'UDISE+');
    }
  });
});

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { SubmissionSchema } from '../src/submission.js';
import { TriageResponseSchema } from '../src/triage.js';
import { computeInterimScore } from '../src/config.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const fixturesDir = join(__dirname, '../../../fixtures');

describe('SubmissionSchema', () => {
  it('round-trips fixture submissions', () => {
    const raw = readFileSync(join(fixturesDir, 'submissions_seed.json'), 'utf-8');
    const fixtures = JSON.parse(raw) as unknown[];
    assert.ok(fixtures.length >= 1);
    for (const fixture of fixtures) {
      const parsed = SubmissionSchema.safeParse(fixture);
      assert.equal(parsed.success, true, JSON.stringify(parsed.success ? '' : parsed.error.issues));
    }
  });
});

describe('TriageResponseSchema', () => {
  it('accepts mock triage output', () => {
    const mock = {
      original_language: 'te',
      transcript_original: 'మా ఊరి బడి 7వ తరగతి వరకే ఉంది',
      text_en: 'Our village school only goes to grade 7',
      canonical_summary_en:
        'Upgrade village school beyond grade 7 / secondary school access; ~6 km travel to Ghatkesar',
      category: 'education',
      subcategory: 'school_upgrade',
      kind: 'development_request',
      urgency: 'medium',
      location_mentions: [{ original: 'Ghatkesar', latin: 'Ghatkesar' }],
      triage_confidence: 0.86,
    };
    assert.equal(TriageResponseSchema.safeParse(mock).success, true);
  });
});

describe('computeInterimScore', () => {
  it('ranks higher demand and recency higher', () => {
    const high = computeInterimScore(23, 40, 3);
    const low = computeInterimScore(5, 40, 30);
    assert.ok(high.total > low.total);
    assert.ok(high.demand > low.demand);
    assert.ok(high.recency > low.recency);
  });
});

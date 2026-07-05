import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { embedText, cosineSimilarity } from '../../services/enrich-worker/src/embedding.js';
import {
  AUTO_MERGE_THRESHOLD,
  PROVISIONAL_THRESHOLD,
} from '../../services/enrich-worker/src/clustering.js';

/**
 * Golden cross-language clustering test (§4.3). The four canonical
 * canonical_summary_en strings that triage would produce for a Telugu WhatsApp
 * voice note, a Hindi app text, an English meeting extract (all the same
 * school), and an English YouTube comment about an ITI.
 *
 * Assert the first three are mutually similar (would land in ONE cluster) and
 * the ITI comment is distinct (would seed a separate vocational cluster).
 *
 * Note: with real gemini-embedding-001 the margins are wide; the offline
 * deterministic embedding is coarser, so we assert ordering + separation
 * rather than the exact 0.80 band.
 */
describe('cross-language clustering (golden)', () => {
  const school = {
    te: 'Upgrade village school beyond grade 7 / secondary school access near Ghatkesar',
    hi: 'No high school in village children travel to Ghatkesar requests secondary school access',
    en: 'Upgrade local school to include secondary school access near Ghatkesar',
  };
  const iti = 'Establish vocational training institute ITI in the area';

  it('groups the three school summaries closer to each other than to the ITI', async () => {
    const [te, hi, en, vocational] = await Promise.all([
      embedText(school.te),
      embedText(school.hi),
      embedText(school.en),
      embedText(iti),
    ]);

    const schoolPairs = [
      cosineSimilarity(te, hi),
      cosineSimilarity(te, en),
      cosineSimilarity(hi, en),
    ];
    const itiPairs = [
      cosineSimilarity(vocational, te),
      cosineSimilarity(vocational, hi),
      cosineSimilarity(vocational, en),
    ];

    const minSchool = Math.min(...schoolPairs);
    const maxIti = Math.max(...itiPairs);

    // The weakest school-school similarity must beat the strongest school-ITI similarity.
    assert.ok(
      minSchool > maxIti,
      `school cohesion ${minSchool.toFixed(3)} should exceed ITI overlap ${maxIti.toFixed(3)}`,
    );
  });

  it('exposes sane threshold band constants', () => {
    assert.ok(AUTO_MERGE_THRESHOLD > PROVISIONAL_THRESHOLD);
    assert.equal(AUTO_MERGE_THRESHOLD, 0.8);
    assert.equal(PROVISIONAL_THRESHOLD, 0.65);
  });
});

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  compositeScore,
  demandTerm,
  confidenceTerm,
  recencyTerm,
  sourceWeight,
  percentRank,
  percentileIndex,
} from '../src/config.js';
import {
  computeSchoolUpgradeIndicators,
  evidenceScoreForMandal,
  haversineKm,
  type UdiseSchool,
} from '../src/evidence.js';
import { findHallucinatedNumbers } from '../src/justification.js';

describe('demandTerm', () => {
  it('log-damps and stays in [0,1]', () => {
    assert.ok(demandTerm(23, 40) > demandTerm(5, 40));
    assert.ok(demandTerm(1000, 40) <= 1);
    assert.equal(demandTerm(0, 40), 0);
  });
});

describe('sourceWeight + confidenceTerm', () => {
  it('weights app+GPS+photo highest, youtube lowest', () => {
    assert.equal(
      sourceWeight({ source: 'app', modality: 'photo_text', has_media: true, geocode_confidence: 'high' }),
      1.0,
    );
    assert.equal(
      sourceWeight({ source: 'youtube', modality: 'video_comment', has_media: false, geocode_confidence: 'none' }),
      0.3,
    );
  });

  it('averages w_src * g across submissions', () => {
    const v = confidenceTerm([
      { source: 'app', modality: 'photo_text', has_media: true, geocode_confidence: 'high' },
      { source: 'youtube', modality: 'video_comment', has_media: false, geocode_confidence: 'none' },
    ]);
    // (1.0*1.0 + 0.3*0.4)/2 = 0.56
    assert.ok(Math.abs(v - 0.56) < 1e-9);
  });
});

describe('recencyTerm', () => {
  it('halves every 90 days', () => {
    assert.ok(Math.abs(recencyTerm(90) - 0.5) < 1e-9);
    assert.ok(Math.abs(recencyTerm(0) - 1) < 1e-9);
  });
});

describe('compositeScore', () => {
  it('uses full formula when evidence present', () => {
    const r = compositeScore({ evidence: 0.88, demand: 0.86, confidence: 0.64, recency: 0.98 });
    // 100*(0.35*0.88 + 0.30*0.86 + 0.20*0.64 + 0.15*0.98) = 84.1
    assert.ok(Math.abs(r.total - 84.1) < 0.5);
    assert.equal(r.evidence_available, true);
  });

  it('renormalizes when evidence absent', () => {
    const r = compositeScore({ evidence: null, demand: 0.86, confidence: 0.64, recency: 0.98 });
    assert.equal(r.evidence_available, false);
    assert.ok(r.total > 0 && r.total <= 100);
  });

  it('ranks flagship school-upgrade above vocational', () => {
    const school = compositeScore({ evidence: 0.88, demand: 0.86, confidence: 0.64, recency: 0.98 });
    const vocational = compositeScore({ evidence: 0.62, demand: 0.62, confidence: 0.41, recency: 0.88 });
    assert.ok(school.total > vocational.total);
  });
});

describe('percentileIndex', () => {
  it('matches p95 index used across scoring paths', () => {
    const values = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    const idx = percentileIndex(values.length, 0.95);
    assert.equal(idx, 8);
    assert.equal(values[idx], 9);
  });

  it('returns 0 for empty length', () => {
    assert.equal(percentileIndex(0, 0.95), 0);
  });
});

describe('percentRank', () => {
  it('ranks the max at 1', () => {
    assert.equal(percentRank([1, 2, 3], 3), 1);
    assert.equal(percentRank([1, 2, 3], 1), 0);
  });
});

describe('evidence: UDISE school-upgrade', () => {
  const schools: UdiseSchool[] = [
    // Ghatkesar mandal — big feeder pipeline, no secondary school
    { udise_code: '1', school_name: 'A', mgmt_type: 'govt', highest_class: 8, lat: 17.44, lng: 78.68, mandal_code: 'TS-0417', enr_g6: 150, enr_g7: 140, enr_g8: 122 },
    // Neighboring mandal — has secondary capacity
    { udise_code: '2', school_name: 'B', mgmt_type: 'govt', highest_class: 10, lat: 17.50, lng: 78.60, mandal_code: 'TS-0418', enr_g9: 80, enr_g10: 70 },
    { udise_code: '3', school_name: 'C', mgmt_type: 'govt', highest_class: 8, lat: 17.50, lng: 78.60, mandal_code: 'TS-0418', enr_g6: 30, enr_g7: 25, enr_g8: 20 },
  ];

  it('gives Ghatkesar a higher evidence score than the served mandal', () => {
    const centroids = {
      'TS-0417': { lat: 17.44, lng: 78.68 },
      'TS-0418': { lat: 17.50, lng: 78.60 },
    };
    const indicators = computeSchoolUpgradeIndicators(schools, centroids);
    const ghatkesar = evidenceScoreForMandal(indicators, 'TS-0417');
    const served = evidenceScoreForMandal(indicators, 'TS-0418');
    assert.ok(ghatkesar);
    assert.ok(served);
    assert.ok(ghatkesar!.score >= served!.score);
    assert.equal(ghatkesar!.rows.length, 3);
  });
});

describe('haversineKm', () => {
  it('computes ~0 for identical points', () => {
    assert.ok(haversineKm({ lat: 17.44, lng: 78.68 }, { lat: 17.44, lng: 78.68 }) < 0.001);
  });
});

describe('findHallucinatedNumbers', () => {
  const input = {
    cluster_title: 'Secondary school access',
    category: 'education',
    admin_unit_names: ['Ghatkesar'],
    score: { total: 84.1, demand: 0.86, evidence: 0.88, confidence: 0.64, recency: 0.98, evidence_available: true },
    demand_stats: { unique_citizens: 23, sources: { app: 9 }, languages: ['te'], first_seen: '2026-06-12', last_activity: '2026-07-05', simulated_count: 0 },
    anomaly_flags: [],
    evidence_rows: [{ label: 'students', value: 412, dataset: 'UDISE+', ref_year: '2024-25' }],
  };

  it('passes when prose uses only payload numbers', () => {
    const out = { text_en: '23 citizens; 412 students per UDISE+ 2024-25.', evidence_bullets: ['412 students - UDISE+ 2024-25'], caveats: [] };
    assert.deepEqual(findHallucinatedNumbers(input, out), []);
  });

  it('flags an invented number', () => {
    const out = { text_en: '999 citizens asked.', evidence_bullets: [], caveats: [] };
    assert.ok(findHallucinatedNumbers(input, out).includes('999'));
  });
});

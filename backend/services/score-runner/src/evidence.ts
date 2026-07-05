import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import {
  computeSchoolUpgradeIndicators,
  evidenceScoreForMandal,
  findRepoRoot,
  type UdiseSchool,
  type MandalIndicators,
} from '@pp/schema';

const UDISE_PATH =
  process.env.UDISE_LOCAL_JSON ?? join(findRepoRoot(), 'fixtures/udise_schools.json');

let cache: UdiseSchool[] | null = null;

/**
 * Load UDISE+ schools. Local dev reads fixtures/udise_schools.json; production
 * would query BigQuery pp.evidence.udise_schools (see sql/evidence_*.sql).
 */
export function loadUdiseSchools(): UdiseSchool[] {
  if (cache) return cache;
  if (!existsSync(UDISE_PATH)) {
    cache = [];
    return cache;
  }
  cache = JSON.parse(readFileSync(UDISE_PATH, 'utf-8')) as UdiseSchool[];
  return cache;
}

export interface EvidenceResult {
  score: number;
  rows: { label: string; value: number; dataset: string; ref_year: string }[];
}

/**
 * Resolve the evidence term E for a cluster. Returns null when no spec covers
 * the subcategory (evidence_available=false → renormalized score, §6).
 */
export function resolveEvidence(
  subcategory: string,
  mandalCode: string | null,
  centroids: Record<string, { lat: number; lng: number }>,
  supportedSubcategories: Set<string>,
): EvidenceResult | null {
  if (!mandalCode) return null;
  if (!supportedSubcategories.has(subcategory)) return null;

  if (subcategory === 'school_upgrade') {
    const schools = loadUdiseSchools();
    if (schools.length === 0) return null;
    const indicators: MandalIndicators[] = computeSchoolUpgradeIndicators(schools, centroids);
    return evidenceScoreForMandal(indicators, mandalCode);
  }

  return null;
}

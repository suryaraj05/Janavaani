import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { findRepoRoot } from './repoRoot.js';

let cached: Record<string, string[]> | null = null;

/** Precomputed mandal adjacency (§4.2) — avoids live distance checks at cluster time. */
export function loadMandalAdjacency(): Record<string, string[]> {
  if (cached) return cached;
  const path = join(findRepoRoot(), 'fixtures/mandal_adjacency.json');
  cached = JSON.parse(readFileSync(path, 'utf-8')) as Record<string, string[]>;
  return cached;
}

/** True when mandals are the same or listed as adjacent in the adjacency table. */
export function isMandalAdjacentOrSame(
  a: string | null | undefined,
  b: string | null | undefined,
  adjacency: Record<string, string[]> = loadMandalAdjacency(),
): boolean {
  if (!a || !b) return true;
  if (a === b) return true;
  const neighbors = adjacency[a] ?? [];
  return neighbors.includes(b);
}

/** Mandal codes allowed as cluster candidates for a submission location. */
export function allowedMandalCodes(
  mandalCode: string | null,
  geocodeConfidence: 'high' | 'medium' | 'low' | 'none',
  adjacency: Record<string, string[]> = loadMandalAdjacency(),
): Set<string> | null {
  if (!mandalCode) return null;
  if (geocodeConfidence === 'high') return new Set([mandalCode]);
  const adjacent = adjacency[mandalCode] ?? [];
  return new Set([mandalCode, ...adjacent]);
}

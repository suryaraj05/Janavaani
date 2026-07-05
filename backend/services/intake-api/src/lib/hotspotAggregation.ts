import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import type { Firestore } from 'firebase-admin/firestore';
import { findRepoRoot } from '@pp/schema';

export interface MandalDemandZone {
  mandal_code: string;
  name: string;
  centroid: { lat: number; lng: number };
  radius_m: number;
}

export interface MandalHotspot {
  mandal_code: string;
  name: string;
  centroid: { lat: number; lng: number };
  radius_m: number;
  cluster_count: number;
  weighted_demand: number;
  max_score: number;
  intensity: number;
}

function loadZones(): MandalDemandZone[] {
  const path = join(findRepoRoot(), 'fixtures/mandal_demand_zones.json');
  return JSON.parse(readFileSync(path, 'utf-8')) as MandalDemandZone[];
}

/**
 * Aggregate cluster demand per mandal for hotspot choropleth (Phase B).
 * weighted_demand = sum(unique_citizens * score.total / 100) per cluster in mandal.
 */
export async function aggregateMandalHotspots(db: Firestore): Promise<MandalHotspot[]> {
  const zones = loadZones();
  const snap = await db.collection('clusters').get();

  const byMandal = new Map<
    string,
    { cluster_count: number; weighted_demand: number; max_score: number }
  >();

  for (const doc of snap.docs) {
    const data = doc.data();
    const history =
      (data.lifecycle as { history?: Array<{ action?: string }> })?.history ?? [];
    if (history.some((h) => h.action === 'seeded')) continue;

    const mandal =
      (data.admin_scope as { mandal_code?: string | null })?.mandal_code ?? null;
    if (!mandal) continue;

    const stats = data.stats as { unique_citizens?: number };
    const score = data.score as { total?: number };
    const citizens = stats.unique_citizens ?? 0;
    const total = score.total ?? 0;
    const weighted = citizens * (total / 100);

    const prev = byMandal.get(mandal) ?? { cluster_count: 0, weighted_demand: 0, max_score: 0 };
    byMandal.set(mandal, {
      cluster_count: prev.cluster_count + 1,
      weighted_demand: prev.weighted_demand + weighted,
      max_score: Math.max(prev.max_score, total),
    });
  }

  const maxDemand = Math.max(...[...byMandal.values()].map((v) => v.weighted_demand), 1);

  return zones.map((z) => {
    const agg = byMandal.get(z.mandal_code) ?? {
      cluster_count: 0,
      weighted_demand: 0,
      max_score: 0,
    };
    return {
      mandal_code: z.mandal_code,
      name: z.name,
      centroid: z.centroid,
      radius_m: z.radius_m,
      cluster_count: agg.cluster_count,
      weighted_demand: Number(agg.weighted_demand.toFixed(2)),
      max_score: agg.max_score,
      intensity: Number((agg.weighted_demand / maxDemand).toFixed(3)),
    };
  });
}

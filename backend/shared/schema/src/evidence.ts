import { z } from 'zod';
import { percentRank } from './config.js';

export const EvidenceIndicatorSchema = z.object({
  name: z.string(),
  weight: z.number(),
  sql_file: z.string().optional(),
});

export const EvidenceSpecSchema = z.object({
  subcategory: z.string(),
  indicators: z.array(EvidenceIndicatorSchema),
  dataset: z.object({
    name: z.string(),
    ref_year: z.string(),
    citation: z.string(),
  }),
});

export type EvidenceSpec = z.infer<typeof EvidenceSpecSchema>;

/** One UDISE+ school row (subset used for scoring, §5.2). */
export interface UdiseSchool {
  udise_code: string;
  school_name: string;
  mgmt_type: 'govt' | 'aided' | 'private';
  highest_class: number;
  lat: number;
  lng: number;
  mandal_code: string;
  enr_g6?: number;
  enr_g7?: number;
  enr_g8?: number;
  enr_g9?: number;
  enr_g10?: number;
}

/** Haversine straight-line distance in km. */
export function haversineKm(a: { lat: number; lng: number }, b: { lat: number; lng: number }): number {
  const R = 6371;
  const dLat = ((b.lat - a.lat) * Math.PI) / 180;
  const dLng = ((b.lng - a.lng) * Math.PI) / 180;
  const lat1 = (a.lat * Math.PI) / 180;
  const lat2 = (b.lat * Math.PI) / 180;
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

export interface MandalIndicators {
  mandal_code: string;
  seat_gap: number;
  road_km_est: number;
  pipeline_per_school: number;
}

/**
 * Compute education.school_upgrade indicators for every mandal (§5.3).
 * `centroids` maps mandal_code -> demand centroid; used for road_km_est.
 * The 1.4 factor converts straight-line to approximate road distance.
 */
export function computeSchoolUpgradeIndicators(
  schools: UdiseSchool[],
  centroids: Record<string, { lat: number; lng: number }>,
): MandalIndicators[] {
  const byMandal = new Map<string, UdiseSchool[]>();
  for (const s of schools) {
    if (s.mgmt_type === 'private') continue;
    const arr = byMandal.get(s.mandal_code) ?? [];
    arr.push(s);
    byMandal.set(s.mandal_code, arr);
  }

  const out: MandalIndicators[] = [];
  for (const [mandal, list] of byMandal) {
    const feeders = list.filter((s) => s.highest_class <= 8);
    const secondary = list.filter((s) => s.highest_class >= 10);

    const pipeline = feeders.reduce(
      (acc, s) => acc + (s.enr_g6 ?? 0) + (s.enr_g7 ?? 0) + (s.enr_g8 ?? 0),
      0,
    );
    const secondaryIntake = secondary.reduce(
      (acc, s) => acc + (s.enr_g9 ?? 0) + (s.enr_g10 ?? 0),
      0,
    );
    const seatGap = Math.max(pipeline / 3 - secondaryIntake / 2, 0);

    const centroid = centroids[mandal];
    let roadKm = 0;
    if (centroid && secondary.length > 0) {
      const nearest = Math.min(...secondary.map((s) => haversineKm(centroid, s)));
      roadKm = nearest * 1.4;
    } else if (secondary.length === 0) {
      roadKm = 999; // no secondary school at all -> maximal access gap
    }

    const pipelinePerSchool = secondary.length > 0 ? pipeline / secondary.length : pipeline;

    out.push({
      mandal_code: mandal,
      seat_gap: seatGap,
      road_km_est: roadKm,
      pipeline_per_school: pipelinePerSchool,
    });
  }
  return out;
}

/**
 * E = 0.5·pct(seat_gap) + 0.3·pct(road_km_est) + 0.2·pct(pipeline_per_school).
 * Percentile-normalized across all mandals so E is scale-free and comparable (§5.3).
 */
export function evidenceScoreForMandal(
  indicators: MandalIndicators[],
  mandalCode: string,
): { score: number; rows: { label: string; value: number; dataset: string; ref_year: string }[] } | null {
  const target = indicators.find((i) => i.mandal_code === mandalCode);
  if (!target) return null;

  const seatGaps = indicators.map((i) => i.seat_gap);
  const roadKms = indicators.map((i) => i.road_km_est);
  const perSchool = indicators.map((i) => i.pipeline_per_school);

  const e =
    0.5 * percentRank(seatGaps, target.seat_gap) +
    0.3 * percentRank(roadKms, target.road_km_est) +
    0.2 * percentRank(perSchool, target.pipeline_per_school);

  return {
    score: e,
    rows: [
      { label: 'Secondary seat gap (students/yr)', value: Math.round(target.seat_gap), dataset: 'UDISE+', ref_year: '2024-25' },
      { label: 'Distance to nearest secondary school (km)', value: Number(target.road_km_est.toFixed(1)), dataset: 'UDISE+ + boundaries', ref_year: '2024-25' },
      { label: 'Feeder pipeline per secondary school', value: Math.round(target.pipeline_per_school), dataset: 'UDISE+', ref_year: '2024-25' },
    ],
  };
}

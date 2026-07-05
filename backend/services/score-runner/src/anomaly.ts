import type { Firestore } from 'firebase-admin/firestore';

export interface AnomalyResult {
  flags: string[];
}

/**
 * Burst + near-duplicate detection over a cluster's submissions (§3.3).
 * - burst: >max(5, 7× trailing 14-day daily mean) submissions in last 24h.
 * - near_duplicate_texts: >30% of pairwise text_en token-similarities > 0.95.
 */
export async function detectAnomalies(
  db: Firestore,
  clusterId: string,
): Promise<AnomalyResult> {
  const snap = await db
    .collection('submissions')
    .where('cluster_id', '==', clusterId)
    .limit(200)
    .get();

  const subs = snap.docs.map((d) => d.data());
  const flags: string[] = [];
  const now = Date.now();
  const day = 24 * 60 * 60 * 1000;

  const times = subs
    .map((s) => new Date(s.created_at as string).getTime())
    .filter((t) => !Number.isNaN(t));

  const last24h = times.filter((t) => now - t <= day).length;
  const trailing14dCounts = new Array(14).fill(0) as number[];
  for (const t of times) {
    const daysAgo = Math.floor((now - t) / day);
    if (daysAgo >= 1 && daysAgo <= 14) trailing14dCounts[daysAgo - 1] += 1;
  }
  const mean14 = trailing14dCounts.reduce((a, b) => a + b, 0) / 14;
  if (last24h > Math.max(5, 7 * mean14)) {
    flags.push(`burst_${last24h}_last24h`);
  }

  const texts = subs
    .slice(-50)
    .map((s) => (s.content as { text_en?: string })?.text_en ?? '')
    .filter((t) => t.length > 0);

  if (texts.length >= 4) {
    let dupPairs = 0;
    let totalPairs = 0;
    for (let i = 0; i < texts.length; i++) {
      for (let j = i + 1; j < texts.length; j++) {
        totalPairs++;
        if (tokenSim(texts[i], texts[j]) > 0.95) dupPairs++;
      }
    }
    const ratio = totalPairs > 0 ? dupPairs / totalPairs : 0;
    if (ratio > 0.3) flags.push(`near_duplicate_texts_${Math.round(ratio * 100)}pct`);
  }

  return { flags };
}

function tokenSim(a: string, b: string): number {
  const ta = new Set(a.toLowerCase().split(/\s+/).filter(Boolean));
  const tb = new Set(b.toLowerCase().split(/\s+/).filter(Boolean));
  if (ta.size === 0 || tb.size === 0) return 0;
  let inter = 0;
  for (const t of ta) if (tb.has(t)) inter++;
  return inter / Math.sqrt(ta.size * tb.size);
}

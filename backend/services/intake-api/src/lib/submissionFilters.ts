import type { Firestore } from 'firebase-admin/firestore';

/** Demo / fixture rows that must never appear in citizen-facing UI. */
export function isDemoSubmission(data: Record<string, unknown>): boolean {
  const id = String(data.submission_id ?? '');
  if (id.startsWith('sub_seed_')) return true;
  if (data.is_simulated === true) return true;
  const source = String(data.source ?? '');
  if (source === 'portal_mock' || source === 'meta_mock') return true;
  const meta = data.channel_meta as Record<string, unknown> | undefined;
  if (meta?.seeded === true) return true;
  return false;
}

export function filterRealSubmissions(
  rows: Record<string, unknown>[],
): Record<string, unknown>[] {
  return rows.filter((r) => !isDemoSubmission(r));
}

export async function fetchRecentFeedSubmissions(
  db: Firestore,
  limit = 50,
): Promise<Record<string, unknown>[]> {
  let snapshot;
  try {
    snapshot = await db
      .collection('submissions')
      .orderBy('created_at', 'desc')
      .limit(Math.min(limit * 3, 150))
      .get();
  } catch {
    snapshot = await db.collection('submissions').limit(150).get();
  }

  const rows = snapshot.docs.map((d) => d.data() as Record<string, unknown>);
  return filterRealSubmissions(rows)
    .sort(
      (a, b) =>
        String(b.created_at ?? '').localeCompare(String(a.created_at ?? '')),
    )
    .slice(0, limit);
}

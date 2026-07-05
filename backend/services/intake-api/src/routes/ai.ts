import { Router } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { analyzeProblemImages, JANAVAANI_DEPARTMENTS } from '../services/analyze.js';

const router = Router();

function normalizeText(s: string): string {
  return s.toLowerCase().replace(/\s+/g, ' ').trim();
}

function titleSimilarity(a: string, b: string): number {
  const x = normalizeText(a);
  const y = normalizeText(b);
  if (!x || !y) return 0;
  if (x === y) return 1;
  const wordsA = new Set(x.split(' '));
  const wordsB = new Set(y.split(' '));
  let overlap = 0;
  for (const w of wordsA) {
    if (wordsB.has(w) && w.length > 2) overlap++;
  }
  return overlap / Math.max(wordsA.size, wordsB.size, 1);
}

router.post('/analyze', requireAuth, async (req, res) => {
  try {
    const { title, description, images } = req.body as {
      title?: string;
      description?: string;
      images?: string[];
    };

    if (!images?.length) {
      res.status(400).json({
        success: false,
        message: 'At least one image is required for AI analysis',
      });
      return;
    }

    const data = await analyzeProblemImages({
      title: title ?? '',
      description: description ?? '',
      images,
    });

    res.json({ success: true, data });
  } catch (err) {
    console.error('POST /ai/analyze error:', err);
    res.status(500).json({
      success: false,
      message: err instanceof Error ? err.message : 'AI analysis failed',
    });
  }
});

router.post('/check-duplicates', requireAuth, async (req, res) => {
  try {
    const { title, description, latitude, longitude, existingGrievances } = req.body as {
      title: string;
      description: string;
      latitude?: number;
      longitude?: number;
      existingGrievances?: Array<Record<string, unknown>>;
    };

    const existing = existingGrievances ?? [];
    const similarGrievances: Array<Record<string, unknown>> = [];

    for (const g of existing) {
      const gTitle = String(g.title ?? g['canonical_title_en'] ?? '');
      const score = titleSimilarity(title, gTitle);
      const descScore = titleSimilarity(description, String(g.description ?? ''));
      const combined = Math.max(score, descScore * 0.85);

      if (combined < 0.5) continue;

      let isSameLocation = false;
      let distance: number | null = null;
      const gLat = g.latitude as number | undefined;
      const gLng = g.longitude as number | undefined;
      if (
        latitude != null &&
        longitude != null &&
        gLat != null &&
        gLng != null
      ) {
        const dLat = latitude - gLat;
        const dLng = longitude - gLng;
        distance = Math.sqrt(dLat * dLat + dLng * dLng) * 111_000;
        isSameLocation = distance < 500;
      }

      similarGrievances.push({
        grievanceId: g.grievanceId ?? g.id ?? g.submission_id,
        submission_id: g.submission_id ?? g.grievanceId ?? g.id,
        cluster_id: g.cluster_id ?? null,
        title: gTitle,
        description: String(g.description ?? ''),
        priority: String(g.priority ?? 'medium'),
        status: String(g.status ?? 'submitted'),
        upvotes: (g.upvotes as number) ?? 0,
        similarityScore: combined,
        reason:
          combined > 0.9
            ? 'Very similar title or description'
            : 'Possibly related report',
        isSameLocation,
        distance,
        canRevive: false,
      });
    }

    similarGrievances.sort(
      (a, b) =>
        (b.similarityScore as number) - (a.similarityScore as number),
    );

    res.json({
      success: true,
      data: {
        hasDuplicates: similarGrievances.length > 0,
        similarGrievances: similarGrievances.slice(0, 5),
        allowedDepartments: JANAVAANI_DEPARTMENTS,
      },
    });
  } catch (err) {
    console.error('POST /ai/check-duplicates error:', err);
    res.status(500).json({
      success: false,
      message: err instanceof Error ? err.message : 'Duplicate check failed',
    });
  }
});

export default router;

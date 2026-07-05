const PRODUCTION_ENRICH_URL = 'https://janavaani-enrich.onrender.com';

/**
 * Resolve enrich-worker base URL. Render blueprints sometimes set a bare service
 * name (e.g. "janavaani-enrich") — normalize to a valid https URL.
 */
export function getEnrichWorkerUrl(): string {
  const raw = process.env.ENRICH_WORKER_URL?.trim();
  const fallback =
    process.env.RENDER === 'true' ? PRODUCTION_ENRICH_URL : 'http://localhost:8081';

  if (!raw) return fallback;

  let url = raw.replace(/\/+$/, '').replace(/\/enrich$/, '');

  // Bare Render service slug with no domain.
  if (!url.includes('://') && !url.includes('localhost') && !url.includes('.')) {
    url = `https://${url}.onrender.com`;
  }

  if (!/^https?:\/\//i.test(url)) {
    url = `https://${url}`;
  }

  try {
    const parsed = new URL(url);
    return `${parsed.protocol}//${parsed.host}`;
  } catch {
    console.warn(`Invalid ENRICH_WORKER_URL "${raw}" — using ${fallback}`);
    return fallback;
  }
}

export function getConstituencyCode(): string {
  return process.env.CONSTITUENCY_CODE?.trim() ?? 'PC-MALKAJGIRI';
}

export function getConstituencyName(): string {
  return process.env.CONSTITUENCY_NAME?.trim() ?? 'Malkajgiri';
}

export function getConstituencyBbox(): [number, number, number, number] {
  const raw = process.env.CONSTITUENCY_BBOX?.trim();
  if (raw) {
    const parts = raw.split(',').map(Number);
    if (parts.length === 4 && parts.every((n) => !Number.isNaN(n))) {
      return parts as [number, number, number, number];
    }
  }
  return [78.45, 17.35, 78.75, 17.55];
}

export function getEnrichWorkerUrl(): string {
  return process.env.ENRICH_WORKER_URL?.trim() ?? 'http://localhost:8081';
}

export function getConstituencyCode(): string {
  return process.env.CONSTITUENCY_CODE?.trim() ?? 'PC-MALKAJGIRI';
}

export function getConstituencyBbox(): [number, number, number, number] {
  const raw = process.env.CONSTITUENCY_BBOX?.trim();
  if (raw) {
    const parts = raw.split(',').map(Number);
    if (parts.length === 4 && parts.every((n) => !Number.isNaN(n))) {
      return parts as [number, number, number, number];
    }
  }
  // Malkajgiri constituency approximate bbox
  return [78.45, 17.35, 78.75, 17.55];
}

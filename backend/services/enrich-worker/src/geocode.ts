export interface GeocodeResult {
  lat: number;
  lng: number;
  method: 'device_gps' | 'nominatim_biased' | 'none';
  geocode_confidence: 'high' | 'medium' | 'low' | 'none';
}

const nominatimCache = new Map<string, GeocodeResult | null>();
let lastNominatimCall = 0;

async function rateLimitedFetch(url: string): Promise<Response> {
  const now = Date.now();
  const wait = Math.max(0, 1100 - (now - lastNominatimCall));
  if (wait > 0) await new Promise((r) => setTimeout(r, wait));
  lastNominatimCall = Date.now();
  return fetch(url, {
    headers: { 'User-Agent': 'PeoplesPriorities/1.0 (civic-tech)' },
  });
}

export async function geocodeMentions(
  mentions: Array<{ original: string; latin: string }>,
  bbox: [number, number, number, number],
  existingPoint?: { lat: number; lng: number } | null,
): Promise<GeocodeResult> {
  if (existingPoint) {
    return {
      lat: existingPoint.lat,
      lng: existingPoint.lng,
      method: 'device_gps',
      geocode_confidence: 'high',
    };
  }

  const [minLng, minLat, maxLng, maxLat] = bbox;
  const viewbox = `${minLng},${maxLat},${maxLng},${minLat}`;

  for (const mention of mentions) {
    const query = mention.latin || mention.original;
    if (!query) continue;

    const cacheKey = `${query}:${viewbox}`;
    if (nominatimCache.has(cacheKey)) {
      const cached = nominatimCache.get(cacheKey);
      if (cached) return cached;
      continue;
    }

    try {
      const url =
        `https://nominatim.openstreetmap.org/search?` +
        new URLSearchParams({
          q: query,
          format: 'json',
          limit: '3',
          viewbox,
          bounded: '1',
          countrycodes: 'in',
        });

      const response = await rateLimitedFetch(url);
      if (!response.ok) continue;

      const results = (await response.json()) as Array<{ lat: string; lon: string }>;
      if (results.length === 1) {
        const result: GeocodeResult = {
          lat: Number(results[0].lat),
          lng: Number(results[0].lon),
          method: 'nominatim_biased',
          geocode_confidence: 'medium',
        };
        nominatimCache.set(cacheKey, result);
        return result;
      }

      if (results.length > 1) {
        const result: GeocodeResult = {
          lat: Number(results[0].lat),
          lng: Number(results[0].lon),
          method: 'nominatim_biased',
          geocode_confidence: 'low',
        };
        nominatimCache.set(cacheKey, result);
        return result;
      }

      nominatimCache.set(cacheKey, null);
    } catch (err) {
      console.warn('Nominatim geocode failed:', err);
    }
  }

  return {
    lat: 0,
    lng: 0,
    method: 'none',
    geocode_confidence: 'none',
  };
}

export function getConstituencyBbox(): [number, number, number, number] {
  const raw = process.env.CONSTITUENCY_BBOX?.trim();
  if (raw) {
    const parts = raw.split(',').map(Number);
    if (parts.length === 4) return parts as [number, number, number, number];
  }
  return [78.45, 17.35, 78.75, 17.55];
}

export function getConstituencyCode(): string {
  return process.env.CONSTITUENCY_CODE?.trim() ?? 'PC-MALKAJGIRI';
}

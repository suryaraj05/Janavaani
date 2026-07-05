/** Fail-closed connector token check (§8 ingest). */
export function assertConnectorToken(
  expected: string | undefined,
  provided: unknown,
): { ok: true } | { ok: false; status: number; error: string } {
  const token = expected?.trim();
  if (!token) {
    return {
      ok: false,
      status: process.env.NODE_ENV === 'production' ? 503 : 503,
      error: 'Connector ingest is disabled: CONNECTOR_TOKEN is not configured',
    };
  }
  if (provided !== token) {
    return { ok: false, status: 401, error: 'Invalid connector token' };
  }
  return { ok: true };
}

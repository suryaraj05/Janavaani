import { describe, it, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { assertConnectorToken } from '../src/lib/connectorAuth.js';

describe('connector ingest auth (fail-closed)', () => {
  const prevToken = process.env.CONNECTOR_TOKEN;
  const prevEnv = process.env.NODE_ENV;

  afterEach(() => {
    if (prevToken === undefined) delete process.env.CONNECTOR_TOKEN;
    else process.env.CONNECTOR_TOKEN = prevToken;
    if (prevEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = prevEnv;
  });

  it('rejects when CONNECTOR_TOKEN is unset', () => {
    delete process.env.CONNECTOR_TOKEN;
    const result = assertConnectorToken(undefined, 'anything');
    assert.equal(result.ok, false);
    if (!result.ok) assert.equal(result.status, 503);
  });

  it('rejects wrong token', () => {
    const result = assertConnectorToken('secret-token', 'wrong');
    assert.equal(result.ok, false);
    if (!result.ok) assert.equal(result.status, 401);
  });

  it('accepts matching token', () => {
    const result = assertConnectorToken('secret-token', 'secret-token');
    assert.equal(result.ok, true);
  });
});

describe('POST /api/v1/ingest HTTP', () => {
  const prevToken = process.env.CONNECTOR_TOKEN;

  afterEach(() => {
    if (prevToken === undefined) delete process.env.CONNECTOR_TOKEN;
    else process.env.CONNECTOR_TOKEN = prevToken;
  });

  it('returns 503 when CONNECTOR_TOKEN is not configured', async () => {
    delete process.env.CONNECTOR_TOKEN;
    const { createApp } = await import('../src/app.js');
    const app = createApp();
    const server = app.listen(0);
    const port = (server.address() as { port: number }).port;

    try {
      const res = await fetch(`http://127.0.0.1:${port}/api/v1/ingest`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
      });
      assert.equal(res.status, 503);
    } finally {
      server.close();
    }
  });
});

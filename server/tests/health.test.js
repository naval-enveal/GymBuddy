'use strict';

const request = require('supertest');
const createApp = require('../src/app');

describe('GET /health', () => {
  const app = createApp();

  it('returns 200 with status ok and a db state, no DB required', async () => {
    const res = await request(app).get('/health');

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(typeof res.body.uptime).toBe('number');
    expect(typeof res.body.timestamp).toBe('string');
    // DB is not connected in tests; the probe still reports a state.
    expect(['disconnected', 'connected', 'connecting', 'disconnecting', 'unknown'])
      .toContain(res.body.db);
  });
});

describe('unknown routes', () => {
  const app = createApp();

  it('returns 404 with the shared error shape', async () => {
    const res = await request(app).get('/nope');

    expect(res.status).toBe(404);
    expect(res.body.error.message).toBe('Not found');
  });
});

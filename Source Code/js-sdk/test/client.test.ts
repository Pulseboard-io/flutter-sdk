import { describe, it, expect, vi, beforeEach } from 'vitest';
import { init, track, identify, setUserProperties, isInitialized, flushEvents } from '../src/index.js';

describe('client', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ status: 202 }));
    vi.stubGlobal('crypto', {
      randomUUID: () => 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx',
    });
  });

  it('init sets state and isInitialized returns true', () => {
    init({ dsn: 'https://wk_key@host.com/proj/env' });
    expect(isInitialized()).toBe(true);
  });

  it('track enqueues an event', async () => {
    init({ dsn: 'https://wk_key@host.com/proj/env' });
    track('page_view', { path: '/' });
    await flushEvents();
    expect(fetch).toHaveBeenCalledWith(
      'https://host.com/api/v1/ingest/batch',
      expect.objectContaining({
        method: 'POST',
        headers: expect.objectContaining({
          Authorization: 'Bearer wk_key',
          'Content-Type': 'application/json',
        }),
      })
    );
    const body = (fetch as ReturnType<typeof vi.fn>).mock.calls[0][1].body;
    const payload = JSON.parse(body);
    expect(payload.schema_version).toBe('1.0');
    expect(payload.events).toHaveLength(1);
    expect(payload.events[0].type).toBe('event');
    expect(payload.events[0].name).toBe('page_view');
    expect(payload.events[0].properties).toEqual({ path: '/' });
    expect(payload.device.platform).toBeDefined();
  });

  it('setUserProperties enqueues user_properties event', async () => {
    init({ dsn: 'https://wk_key@host.com/proj/env' });
    setUserProperties([{ op: 'set', key: 'plan', value: 'pro' }]);
    await flushEvents();
    const body = (fetch as ReturnType<typeof vi.fn>).mock.calls[0][1].body;
    const payload = JSON.parse(body);
    expect(payload.events[0].type).toBe('user_properties');
    expect(payload.events[0].operations).toEqual([{ op: 'set', key: 'plan', value: 'pro' }]);
  });

  it('identify sets user id in payload', async () => {
    init({ dsn: 'https://wk_key@host.com/proj/env' });
    identify('user_123');
    track('login');
    await flushEvents();
    const body = (fetch as ReturnType<typeof vi.fn>).mock.calls[0][1].body;
    const payload = JSON.parse(body);
    expect(payload.user.user_id).toBe('user_123');
  });
});

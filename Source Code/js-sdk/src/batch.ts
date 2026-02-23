import type { ParsedDsn } from './dsn.js';
import type { Config, IngestEvent, IngestPayload } from './types.js';
import { SCHEMA_VERSION } from './types.js';
import {
  getDefaultAppContext,
  getDefaultDeviceContext,
  getDefaultDeviceId,
  getDefaultPlatform,
} from './context.js';

const BATCH_SIZE = 50;
const FLUSH_MS = 5000;

export interface BatchState {
  dsn: ParsedDsn;
  config: Config;
  deviceId: string;
  anonymousId: string;
  userId: string | null;
  app: IngestPayload['app'];
  device: IngestPayload['device'];
  environment: string;
  platform: string;
  queue: IngestEvent[];
  flushTimer: ReturnType<typeof setTimeout> | null;
}

let state: BatchState | null = null;

export function getState(): BatchState | null {
  return state;
}

export function initState(parsedDsn: ParsedDsn, config: Config): BatchState {
  const platform = config.platform ?? getDefaultPlatform();
  const deviceId = getDefaultDeviceId();
  const app = getDefaultAppContext(platform, {
    appId: config.appId,
    appVersion: config.appVersion,
    buildNumber: config.buildNumber,
  });
  const device = getDefaultDeviceContext(platform, deviceId);
  let anonymousId: string;
  try {
    if (typeof crypto !== 'undefined' && crypto.randomUUID) {
      anonymousId = crypto.randomUUID();
    } else {
      anonymousId = `anon-${Math.random().toString(36).slice(2)}`;
    }
  } catch {
    anonymousId = `anon-${Math.random().toString(36).slice(2)}`;
  }
  state = {
    dsn: parsedDsn,
    config,
    deviceId,
    anonymousId,
    userId: null,
    app,
    device,
    environment: parsedDsn.environment,
    platform,
    queue: [],
    flushTimer: null,
  };
  return state;
}

function clearFlushTimer(s: BatchState): void {
  if (s.flushTimer) {
    clearTimeout(s.flushTimer);
    s.flushTimer = null;
  }
}

function scheduleFlush(s: BatchState): void {
  clearFlushTimer(s);
  s.flushTimer = setTimeout(() => {
    s.flushTimer = null;
    flush();
  }, FLUSH_MS);
}

function buildPayload(s: BatchState, events: IngestEvent[]): IngestPayload {
  return {
    schema_version: SCHEMA_VERSION,
    sent_at: new Date().toISOString(),
    environment: s.environment,
    app: s.app,
    device: s.device,
    user: {
      anonymous_id: s.anonymousId,
      user_id: s.userId ?? undefined,
    },
    events,
  };
}

export function enqueue(event: IngestEvent): void {
  const s = state;
  if (!s) return;
  s.queue.push(event);
  if (s.queue.length >= BATCH_SIZE) {
    flush();
  } else {
    scheduleFlush(s);
  }
}

export async function flush(): Promise<void> {
  const s = state;
  if (!s || s.queue.length === 0) return;
  clearFlushTimer(s);
  const events = s.queue.splice(0, BATCH_SIZE);
  const payload = buildPayload(s, events);
  const url = `${s.dsn.baseUrl}/api/v1/ingest/batch`;
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${s.dsn.publicKey}`,
    'Idempotency-Key': crypto.randomUUID?.() ?? `batch-${Date.now()}-${Math.random().toString(36).slice(2)}`,
  };
  if (s.config.sdkName) headers['X-SDK'] = s.config.sdkName;
  if (s.config.sdkVersion) headers['X-SDK-Version'] = s.config.sdkVersion;
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    });
    if (res.status !== 202) {
      const text = await res.text();
      console.warn('[Pulseboard] Ingest failed:', res.status, text);
    }
  } catch (err) {
    console.warn('[Pulseboard] Ingest error:', err);
    s.queue.unshift(...events);
  }
}

export function setUserId(id: string | null): void {
  if (state) state.userId = id;
}

export function getAnonymousId(): string {
  return state?.anonymousId ?? '';
}

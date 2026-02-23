import { parseDsn } from './dsn.js';
import { enqueue, flush, getState, initState, setUserId } from './batch.js';
import type { Config, IngestEvent, UserPropertiesOperation } from './types.js';

function uuid(): string {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

function now(): string {
  return new Date().toISOString();
}

/**
 * Initialize the Pulseboard SDK with your DSN.
 */
export function init(config: Config): void {
  const parsed = parseDsn(config.dsn);
  initState(parsed, {
    ...config,
    sdkName: config.sdkName ?? 'javascript',
    sdkVersion: config.sdkVersion ?? '1.0.0',
  });
}

/**
 * Track a named event with optional properties.
 */
export function track(name: string, properties?: Record<string, unknown>): void {
  const event: IngestEvent = {
    type: 'event',
    event_id: uuid(),
    timestamp: now(),
    name,
    properties: properties ?? undefined,
  };
  enqueue(event);
}

/**
 * Identify the current user (sets user_id for subsequent events).
 */
export function identify(userId: string | null): void {
  setUserId(userId);
}

/**
 * Set user properties via operations (set, set_once, increment, unset).
 */
export function setUserProperties(operations: UserPropertiesOperation[]): void {
  const event: IngestEvent = {
    type: 'user_properties',
    event_id: uuid(),
    timestamp: now(),
    operations,
  };
  enqueue(event);
}

/**
 * Capture an exception as a crash event.
 */
export function captureException(
  error: Error,
  options?: { fingerprint?: string; fatal?: boolean; breadcrumbs?: Array<{ ts: string; type: string; message: string }> }
): void {
  const event: IngestEvent = {
    type: 'crash',
    event_id: uuid(),
    timestamp: now(),
    fingerprint: options?.fingerprint ?? error.name ?? 'Error',
    fatal: options?.fatal ?? false,
    exception: {
      type: error.name ?? 'Error',
      message: error.message,
      stacktrace: error.stack,
    },
    breadcrumbs: options?.breadcrumbs,
  };
  enqueue(event);
}

/**
 * Record a performance trace.
 */
export function trace(
  name: string,
  durationMs: number,
  attributes?: Record<string, unknown>
): void {
  const event: IngestEvent = {
    type: 'trace',
    event_id: uuid(),
    timestamp: now(),
    trace: {
      trace_id: uuid(),
      name,
      duration_ms: durationMs,
      attributes,
    },
  };
  enqueue(event);
}

/**
 * Flush any queued events to the server.
 */
export function flushEvents(): Promise<void> {
  return flush();
}

/**
 * Check if the SDK has been initialized.
 */
export function isInitialized(): boolean {
  return getState() !== null;
}

export const SCHEMA_VERSION = '1.0';

export type EventType = 'event' | 'user_properties' | 'crash' | 'trace';

export type Platform = 'web' | 'node';

export interface Config {
  dsn: string;
  /** Application identifier (e.g. bundle_id or package name) */
  appId?: string;
  /** Application version */
  appVersion?: string;
  /** Build number or commit */
  buildNumber?: string;
  /** Override platform; default is 'web' in browser, 'node' in Node.js */
  platform?: Platform;
  /** SDK name for X-SDK header (e.g. 'javascript') */
  sdkName?: string;
  /** SDK version for X-SDK-Version header */
  sdkVersion?: string;
}

export interface UserPropertiesOperation {
  op: 'set' | 'set_once' | 'increment' | 'unset';
  key: string;
  value?: unknown;
}

export interface CrashBreadcrumb {
  ts: string;
  type: string;
  message: string;
}

export interface BaseEvent {
  type: EventType;
  event_id: string;
  timestamp: string;
}

export interface EventEvent extends BaseEvent {
  type: 'event';
  name: string;
  session_id?: string;
  properties?: Record<string, unknown>;
}

export interface UserPropertiesEvent extends BaseEvent {
  type: 'user_properties';
  operations: UserPropertiesOperation[];
}

export interface CrashEvent extends BaseEvent {
  type: 'crash';
  fingerprint: string;
  fatal?: boolean;
  exception: {
    type: string;
    message: string;
    stacktrace?: string;
  };
  breadcrumbs?: CrashBreadcrumb[];
}

export interface TraceEvent extends BaseEvent {
  type: 'trace';
  trace: {
    trace_id: string;
    name: string;
    duration_ms: number;
    attributes?: Record<string, unknown>;
  };
}

export type IngestEvent = EventEvent | UserPropertiesEvent | CrashEvent | TraceEvent;

export interface IngestPayload {
  schema_version: string;
  sent_at: string;
  environment: string;
  app: { bundle_id: string; version_name: string; build_number: string };
  device: { device_id: string; platform: string; os_version: string; model: string };
  user: { anonymous_id: string; user_id?: string };
  events: IngestEvent[];
}

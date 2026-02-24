export interface PulseboardOptions {
  /** DSN string: https://<key>@<host>/<project-id>/<environment> */
  dsn: string;
  /** Enable debug logging (default: false) */
  debug?: boolean;
  /** Event sampling rate 0.0-1.0 (default: 1.0) */
  sampleRate?: number;
  /** Max events before flushing (default: 20) */
  flushAt?: number;
  /** Flush interval in seconds (default: 30) */
  flushIntervalSeconds?: number;
  /** Session timeout in minutes (default: 30) */
  sessionTimeoutMinutes?: number;
  /** Max events to persist offline (default: 1000) */
  maxPersistedEvents?: number;
  /** Auto-capture page views (default: true) */
  capturePageViews?: boolean;
  /** Auto-capture crashes (default: true) */
  captureCrashes?: boolean;
  /** Auto-capture Web Vitals (default: true) */
  captureWebVitals?: boolean;
  /** Consent required before tracking (default: false) */
  consentRequired?: boolean;
}

export interface EventProperties {
  [key: string]: string | number | boolean | null | undefined;
}

export type ConsentType = 'analytics' | 'crash_reporting' | 'performance';

export interface DsnComponents {
  host: string;
  publicKey: string;
  projectId: string;
  environment: string;
}

export interface QueuedEvent {
  type: string;
  name?: string;
  timestamp: string;
  properties?: EventProperties;
  session_id?: string;
  anonymous_id?: string;
  user_id?: string;
  device?: DeviceInfo;
}

export interface DeviceInfo {
  platform: string;
  os_version: string;
  model: string;
  screen_width?: number;
  screen_height?: number;
  locale?: string;
  timezone?: string;
}

export interface BatchPayload {
  batch: QueuedEvent[];
  sent_at: string;
  sdk_name: string;
  sdk_version: string;
}

import type { DsnComponents, PulseboardOptions } from './types';

export class PulseboardConfig {
  readonly host: string;
  readonly publicKey: string;
  readonly projectId: string;
  readonly environment: string;
  readonly debug: boolean;
  readonly sampleRate: number;
  readonly flushAt: number;
  readonly flushIntervalSeconds: number;
  readonly sessionTimeoutMinutes: number;
  readonly maxPersistedEvents: number;
  readonly capturePageViews: boolean;
  readonly captureCrashes: boolean;
  readonly captureWebVitals: boolean;
  readonly consentRequired: boolean;

  constructor(options: PulseboardOptions) {
    const dsn = PulseboardConfig.parseDsn(options.dsn);
    this.host = dsn.host;
    this.publicKey = dsn.publicKey;
    this.projectId = dsn.projectId;
    this.environment = dsn.environment;
    this.debug = options.debug ?? false;
    this.sampleRate = options.sampleRate ?? 1.0;
    this.flushAt = options.flushAt ?? 20;
    this.flushIntervalSeconds = options.flushIntervalSeconds ?? 30;
    this.sessionTimeoutMinutes = options.sessionTimeoutMinutes ?? 30;
    this.maxPersistedEvents = options.maxPersistedEvents ?? 1000;
    this.capturePageViews = options.capturePageViews ?? true;
    this.captureCrashes = options.captureCrashes ?? true;
    this.captureWebVitals = options.captureWebVitals ?? true;
    this.consentRequired = options.consentRequired ?? false;
  }

  static parseDsn(dsn: string): DsnComponents {
    try {
      const url = new URL(dsn);
      const publicKey = url.username;
      const pathSegments = url.pathname.split('/').filter(Boolean);

      if (!publicKey || pathSegments.length < 2) {
        throw new Error('Invalid DSN format');
      }

      return {
        host: `${url.protocol}//${url.host}`,
        publicKey,
        projectId: pathSegments[0],
        environment: pathSegments[1],
      };
    } catch {
      throw new Error(`Invalid Pulseboard DSN: ${dsn}`);
    }
  }

  get ingestUrl(): string {
    return `${this.host}/api/v1/ingest/batch`;
  }
}

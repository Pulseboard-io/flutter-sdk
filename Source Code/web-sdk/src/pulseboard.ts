import { PulseboardConfig } from './config';
import { SessionManager } from './session';
import { Transport } from './transport';
import { OfflineQueue } from './offline-queue';
import type { PulseboardOptions, EventProperties, ConsentType, DeviceInfo, QueuedEvent } from './types';

export class Pulseboard {
  private static instance: Pulseboard | null = null;

  private config: PulseboardConfig;
  private session: SessionManager;
  private transport: Transport;
  private offlineQueue: OfflineQueue;
  private eventBuffer: QueuedEvent[] = [];
  private flushTimer: ReturnType<typeof setInterval> | null = null;
  private anonymousId: string;
  private userId: string | null = null;
  private consent: Set<ConsentType> = new Set();
  private initialized = false;

  private constructor(options: PulseboardOptions) {
    this.config = new PulseboardConfig(options);
    this.session = new SessionManager(this.config.sessionTimeoutMinutes);
    this.transport = new Transport(this.config.ingestUrl, this.config.publicKey, this.config.debug);
    this.offlineQueue = new OfflineQueue(this.config.maxPersistedEvents);
    this.anonymousId = this.getOrCreateAnonymousId();

    if (!this.config.consentRequired) {
      this.consent.add('analytics');
      this.consent.add('crash_reporting');
      this.consent.add('performance');
    }
  }

  static init(options: PulseboardOptions): Pulseboard {
    if (Pulseboard.instance) {
      return Pulseboard.instance;
    }

    const instance = new Pulseboard(options);
    Pulseboard.instance = instance;
    instance.start();
    return instance;
  }

  static getInstance(): Pulseboard | null {
    return Pulseboard.instance;
  }

  private start(): void {
    this.initialized = true;
    this.startFlushTimer();

    if (this.config.captureCrashes) {
      this.setupCrashReporting();
    }

    if (this.config.capturePageViews) {
      this.setupPageViewTracking();
    }

    if (this.config.captureWebVitals) {
      this.setupWebVitals();
    }

    // Flush on page unload
    if (typeof window !== 'undefined') {
      window.addEventListener('visibilitychange', () => {
        if (document.visibilityState === 'hidden') {
          this.transport.sendBeacon(this.eventBuffer);
          this.eventBuffer = [];
        }
      });
    }

    this.log('Pulseboard initialized');
  }

  // -- Public API --

  track(name: string, properties?: EventProperties): void {
    if (!this.hasConsent('analytics')) return;
    if (!this.shouldSample()) return;

    this.enqueue({
      type: 'event',
      name,
      timestamp: new Date().toISOString(),
      properties,
      session_id: this.session.getSessionId(),
      anonymous_id: this.anonymousId,
      user_id: this.userId ?? undefined,
      device: this.getDeviceInfo(),
    });
  }

  identify(userId: string, properties?: EventProperties): void {
    this.userId = userId;
    localStorage.setItem('pulseboard_user_id', userId);

    this.enqueue({
      type: 'user_properties',
      name: 'identify',
      timestamp: new Date().toISOString(),
      properties: { user_id: userId, ...properties },
      session_id: this.session.getSessionId(),
      anonymous_id: this.anonymousId,
      user_id: userId,
    });
  }

  grantConsent(...types: ConsentType[]): void {
    for (const t of types) {
      this.consent.add(t);
    }
    this.log('Consent granted:', types);
  }

  revokeConsent(...types: ConsentType[]): void {
    for (const t of types) {
      this.consent.delete(t);
    }
    this.log('Consent revoked:', types);
  }

  async flush(): Promise<void> {
    if (this.eventBuffer.length === 0) return;

    const events = [...this.eventBuffer];
    this.eventBuffer = [];

    const success = await this.transport.send(events);
    if (!success) {
      await this.offlineQueue.enqueue(events);
    }

    // Try to send any queued offline events
    const offlineEvents = await this.offlineQueue.dequeue(50);
    if (offlineEvents.length > 0) {
      const offlineSuccess = await this.transport.send(offlineEvents);
      if (!offlineSuccess) {
        await this.offlineQueue.enqueue(offlineEvents);
      }
    }
  }

  // -- Private --

  private enqueue(event: QueuedEvent): void {
    this.eventBuffer.push(event);
    if (this.eventBuffer.length >= this.config.flushAt) {
      this.flush();
    }
  }

  private startFlushTimer(): void {
    this.flushTimer = setInterval(() => {
      this.flush();
    }, this.config.flushIntervalSeconds * 1000);
  }

  private setupCrashReporting(): void {
    if (typeof window === 'undefined') return;

    window.addEventListener('error', (event) => {
      if (!this.hasConsent('crash_reporting')) return;

      this.enqueue({
        type: 'crash',
        name: event.error?.name ?? 'Error',
        timestamp: new Date().toISOString(),
        properties: {
          message: event.message,
          filename: event.filename,
          lineno: event.lineno,
          colno: event.colno,
          stack: event.error?.stack ?? null,
        },
        session_id: this.session.getSessionId(),
        anonymous_id: this.anonymousId,
        user_id: this.userId ?? undefined,
        device: this.getDeviceInfo(),
      });
    });

    window.addEventListener('unhandledrejection', (event) => {
      if (!this.hasConsent('crash_reporting')) return;

      this.enqueue({
        type: 'crash',
        name: 'UnhandledPromiseRejection',
        timestamp: new Date().toISOString(),
        properties: {
          message: event.reason?.message ?? String(event.reason),
          stack: event.reason?.stack ?? null,
        },
        session_id: this.session.getSessionId(),
        anonymous_id: this.anonymousId,
        user_id: this.userId ?? undefined,
        device: this.getDeviceInfo(),
      });
    });
  }

  private setupPageViewTracking(): void {
    if (typeof window === 'undefined') return;

    // Track initial page view
    this.track('$pageview', {
      url: window.location.href,
      path: window.location.pathname,
      title: document.title,
      referrer: document.referrer || null,
    });

    // Track SPA navigation via History API
    const originalPushState = history.pushState.bind(history);
    history.pushState = (...args) => {
      originalPushState(...args);
      setTimeout(() => {
        this.track('$pageview', {
          url: window.location.href,
          path: window.location.pathname,
          title: document.title,
        });
      }, 0);
    };

    window.addEventListener('popstate', () => {
      this.track('$pageview', {
        url: window.location.href,
        path: window.location.pathname,
        title: document.title,
      });
    });
  }

  private setupWebVitals(): void {
    if (typeof window === 'undefined' || typeof PerformanceObserver === 'undefined') return;
    if (!this.hasConsent('performance')) return;

    // LCP
    try {
      const lcpObserver = new PerformanceObserver((list) => {
        const entries = list.getEntries();
        const lastEntry = entries[entries.length - 1] as any;
        if (lastEntry) {
          this.track('$web_vital', {
            metric: 'LCP',
            value: lastEntry.startTime,
            url: window.location.href,
          });
        }
      });
      lcpObserver.observe({ type: 'largest-contentful-paint', buffered: true });
    } catch {}

    // CLS
    try {
      let clsValue = 0;
      const clsObserver = new PerformanceObserver((list) => {
        for (const entry of list.getEntries() as any[]) {
          if (!entry.hadRecentInput) {
            clsValue += entry.value;
          }
        }
      });
      clsObserver.observe({ type: 'layout-shift', buffered: true });

      // Report CLS on page hide
      document.addEventListener('visibilitychange', () => {
        if (document.visibilityState === 'hidden') {
          this.track('$web_vital', {
            metric: 'CLS',
            value: clsValue,
            url: window.location.href,
          });
        }
      }, { once: true });
    } catch {}

    // FID / INP
    try {
      const fidObserver = new PerformanceObserver((list) => {
        const entry = list.getEntries()[0] as any;
        if (entry) {
          this.track('$web_vital', {
            metric: 'FID',
            value: entry.processingStart - entry.startTime,
            url: window.location.href,
          });
        }
      });
      fidObserver.observe({ type: 'first-input', buffered: true });
    } catch {}

    // TTFB
    try {
      const nav = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
      if (nav) {
        this.track('$web_vital', {
          metric: 'TTFB',
          value: nav.responseStart - nav.requestStart,
          url: window.location.href,
        });
      }
    } catch {}
  }

  private hasConsent(type: ConsentType): boolean {
    return this.consent.has(type);
  }

  private shouldSample(): boolean {
    return Math.random() < this.config.sampleRate;
  }

  private getOrCreateAnonymousId(): string {
    const stored = localStorage.getItem('pulseboard_anonymous_id');
    if (stored) return stored;

    const id = crypto.randomUUID();
    localStorage.setItem('pulseboard_anonymous_id', id);
    return id;
  }

  private getDeviceInfo(): DeviceInfo {
    return {
      platform: 'web',
      os_version: navigator.userAgent,
      model: navigator.platform ?? 'unknown',
      screen_width: window.screen?.width,
      screen_height: window.screen?.height,
      locale: navigator.language,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    };
  }

  private log(...args: any[]): void {
    if (this.config.debug) {
      console.log('[Pulseboard]', ...args);
    }
  }
}

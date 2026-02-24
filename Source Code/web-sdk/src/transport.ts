import type { BatchPayload } from './types';

const SDK_NAME = '@pulseboard/web';
const SDK_VERSION = '0.1.0';

export class Transport {
  constructor(
    private ingestUrl: string,
    private publicKey: string,
    private debug: boolean,
  ) {}

  async send(events: any[]): Promise<boolean> {
    if (events.length === 0) return true;

    const payload: BatchPayload = {
      batch: events,
      sent_at: new Date().toISOString(),
      sdk_name: SDK_NAME,
      sdk_version: SDK_VERSION,
    };

    try {
      const response = await fetch(this.ingestUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${this.publicKey}`,
        },
        body: JSON.stringify(payload),
        keepalive: true,
      });

      if (this.debug) {
        console.log(`[Pulseboard] Sent ${events.length} events, status: ${response.status}`);
      }

      return response.ok;
    } catch (error) {
      if (this.debug) {
        console.warn('[Pulseboard] Failed to send events:', error);
      }
      return false;
    }
  }

  /**
   * Send events using sendBeacon (for page unload).
   */
  sendBeacon(events: any[]): boolean {
    if (events.length === 0) return true;

    const payload: BatchPayload = {
      batch: events,
      sent_at: new Date().toISOString(),
      sdk_name: SDK_NAME,
      sdk_version: SDK_VERSION,
    };

    return navigator.sendBeacon(
      this.ingestUrl,
      new Blob([JSON.stringify(payload)], { type: 'application/json' }),
    );
  }
}

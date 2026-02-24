const DB_NAME = 'pulseboard_events';
const STORE_NAME = 'events';

export class OfflineQueue {
  private db: IDBDatabase | null = null;
  private maxEvents: number;

  constructor(maxEvents: number) {
    this.maxEvents = maxEvents;
    this.initDb();
  }

  private initDb(): void {
    if (typeof indexedDB === 'undefined') return;

    const request = indexedDB.open(DB_NAME, 1);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        db.createObjectStore(STORE_NAME, { keyPath: 'id', autoIncrement: true });
      }
    };
    request.onsuccess = () => {
      this.db = request.result;
    };
  }

  async enqueue(events: any[]): Promise<void> {
    if (!this.db) return;

    const tx = this.db.transaction(STORE_NAME, 'readwrite');
    const store = tx.objectStore(STORE_NAME);

    for (const event of events) {
      store.add({ data: event, createdAt: Date.now() });
    }

    // Enforce max size
    const countRequest = store.count();
    countRequest.onsuccess = () => {
      const overflow = countRequest.result - this.maxEvents;
      if (overflow > 0) {
        const cursor = store.openCursor();
        let deleted = 0;
        cursor.onsuccess = () => {
          const c = cursor.result;
          if (c && deleted < overflow) {
            c.delete();
            deleted++;
            c.continue();
          }
        };
      }
    };
  }

  async dequeue(limit: number): Promise<any[]> {
    if (!this.db) return [];

    return new Promise((resolve) => {
      const tx = this.db!.transaction(STORE_NAME, 'readwrite');
      const store = tx.objectStore(STORE_NAME);
      const events: any[] = [];
      const cursor = store.openCursor();

      cursor.onsuccess = () => {
        const c = cursor.result;
        if (c && events.length < limit) {
          events.push(c.value.data);
          c.delete();
          c.continue();
        } else {
          resolve(events);
        }
      };

      cursor.onerror = () => resolve([]);
    });
  }
}

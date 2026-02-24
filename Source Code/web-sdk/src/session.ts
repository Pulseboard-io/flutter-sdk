const SESSION_KEY = 'pulseboard_session';
const SESSION_TIMEOUT_KEY = 'pulseboard_session_timeout';

export class SessionManager {
  private sessionId: string;
  private timeoutMinutes: number;

  constructor(timeoutMinutes: number) {
    this.timeoutMinutes = timeoutMinutes;
    this.sessionId = this.resolveSession();
  }

  getSessionId(): string {
    if (this.isExpired()) {
      this.sessionId = this.startNewSession();
    }
    this.touch();
    return this.sessionId;
  }

  private resolveSession(): string {
    const stored = sessionStorage.getItem(SESSION_KEY);
    if (stored && !this.isExpired()) {
      return stored;
    }
    return this.startNewSession();
  }

  private startNewSession(): string {
    const id = crypto.randomUUID();
    sessionStorage.setItem(SESSION_KEY, id);
    this.touch();
    return id;
  }

  private isExpired(): boolean {
    const timeout = sessionStorage.getItem(SESSION_TIMEOUT_KEY);
    if (!timeout) return true;
    return Date.now() > parseInt(timeout, 10);
  }

  private touch(): void {
    const expiresAt = Date.now() + this.timeoutMinutes * 60 * 1000;
    sessionStorage.setItem(SESSION_TIMEOUT_KEY, expiresAt.toString());
  }
}

import { describe, it, expect } from 'vitest';
import { parseDsn } from '../src/dsn.js';

describe('parseDsn', () => {
  it('parses a valid DSN', () => {
    const dsn = 'https://wk_abc123@api.example.com/proj_xyz/production';
    const parsed = parseDsn(dsn);
    expect(parsed.publicKey).toBe('wk_abc123');
    expect(parsed.host).toBe('api.example.com');
    expect(parsed.projectId).toBe('proj_xyz');
    expect(parsed.environment).toBe('production');
    expect(parsed.baseUrl).toBe('https://api.example.com');
  });

  it('accepts http for local dev', () => {
    const dsn = 'http://wk_key@localhost:8000/proj/env';
    const parsed = parseDsn(dsn);
    expect(parsed.publicKey).toBe('wk_key');
    expect(parsed.baseUrl).toBe('http://localhost:8000');
    expect(parsed.projectId).toBe('proj');
    expect(parsed.environment).toBe('env');
  });

  it('throws when public key is missing', () => {
    expect(() => parseDsn('https://api.example.com/proj/env')).toThrow('public key');
  });

  it('throws when path has fewer than two segments', () => {
    expect(() => parseDsn('https://wk_key@api.example.com/proj')).toThrow('path must be');
  });

  it('throws for invalid URL', () => {
    expect(() => parseDsn('not-a-url')).toThrow();
  });
});

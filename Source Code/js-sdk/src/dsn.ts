/**
 * Parsed DSN: https://<public_key>@<host>/<project_id>/<environment>
 */
export interface ParsedDsn {
  publicKey: string;
  host: string;
  projectId: string;
  environment: string;
  baseUrl: string;
}

/**
 * Parse a Pulseboard DSN string.
 * Format: https://<public_key>@<host>/<project_id>/<environment>
 */
export function parseDsn(dsn: string): ParsedDsn {
  try {
    const url = new URL(dsn);
    if (url.protocol !== 'https:' && url.protocol !== 'http:') {
      throw new Error('DSN must use https or http');
    }
    const publicKey = url.username;
    if (!publicKey) {
      throw new Error('DSN must contain a public key (userinfo before @)');
    }
    const pathParts = url.pathname.replace(/^\/+|\/+$/g, '').split('/');
    if (pathParts.length < 2) {
      throw new Error('DSN path must be /<project_id>/<environment>');
    }
    const [projectId, environment] = pathParts;
    const baseUrl = `${url.origin}`;
    return {
      publicKey,
      host: url.host,
      projectId,
      environment,
      baseUrl,
    };
  } catch (err) {
    if (err instanceof TypeError && (err as TypeError).message?.includes('Invalid URL')) {
      throw new Error('Invalid DSN: malformed URL');
    }
    throw err instanceof Error ? err : new Error('Invalid DSN');
  }
}

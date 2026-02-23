import type { Platform } from './types.js';

function isNode(): boolean {
  return typeof process !== 'undefined' && typeof process.versions?.node === 'string';
}

export function getDefaultPlatform(): Platform {
  return isNode() ? 'node' : 'web';
}

export function getDefaultDeviceId(): string {
  if (isNode()) {
    const hostname = typeof process !== 'undefined' && process.env?.HOSTNAME;
    return hostname || `node-${Math.random().toString(36).slice(2)}`;
  }
  try {
    let id = localStorage?.getItem('pulseboard_device_id');
    if (!id) {
      id = `web-${crypto.randomUUID?.() ?? Math.random().toString(36).slice(2)}`;
      localStorage?.setItem('pulseboard_device_id', id);
    }
    return id;
  } catch {
    return `web-${Math.random().toString(36).slice(2)}`;
  }
}

export function getDefaultAppContext(
  platform: Platform,
  overrides: { appId?: string; appVersion?: string; buildNumber?: string } = {}
): { bundle_id: string; version_name: string; build_number: string } {
  const appId = overrides.appId ?? (platform === 'web' ? typeof location !== 'undefined' ? location.origin : 'web' : 'node');
  const appVersion = overrides.appVersion ?? '1.0.0';
  const buildNumber = overrides.buildNumber ?? '1';
  return {
    bundle_id: appId,
    version_name: appVersion,
    build_number: buildNumber,
  };
}

export function getDefaultDeviceContext(
  platform: Platform,
  deviceId: string
): { device_id: string; platform: string; os_version: string; model: string } {
  if (platform === 'node') {
    const proc = typeof process !== 'undefined' ? process : undefined;
    const osVersion = proc?.env?.OS ?? proc?.version ?? 'unknown';
    const model = proc?.env?.HOSTNAME ?? 'server';
    return {
      device_id: deviceId,
      platform: 'node',
      os_version: osVersion,
      model,
    };
  }
  const ua = typeof navigator !== 'undefined' ? navigator.userAgent : '';
  return {
    device_id: deviceId,
    platform: 'web',
    os_version: ua || 'unknown',
    model: 'Browser',
  };
}

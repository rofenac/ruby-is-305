import type {
  Asset,
  InventoryResponse,
  AssetStatus,
  UpdatesResponse,
  ComparisonResponse,
  HealthResponse,
  AvailableUpdatesResponse,
  InstallUpdatesResponse,
  UpgradeResponse,
  RebootStatusResponse,
  RebootResponse,
} from '../types';

const API_BASE = '/api';

async function fetchJson<T>(url: string): Promise<T> {
  const response = await fetch(url);
  if (!response.ok) {
    const error = await response.json().catch(() => ({ error: 'Unknown error' }));
    throw new Error(error.error || `HTTP ${response.status}`);
  }
  return response.json();
}

export async function getHealth(): Promise<HealthResponse> {
  return fetchJson<HealthResponse>(`${API_BASE}/health`);
}

export async function getInventory(): Promise<InventoryResponse> {
  return fetchJson<InventoryResponse>(`${API_BASE}/inventory`);
}

export async function getAsset(name: string): Promise<Asset> {
  return fetchJson<Asset>(`${API_BASE}/assets/${encodeURIComponent(name)}`);
}

export async function getAssetStatus(name: string): Promise<AssetStatus> {
  return fetchJson<AssetStatus>(`${API_BASE}/assets/${encodeURIComponent(name)}/status`);
}

export async function getAssetUpdates(name: string): Promise<UpdatesResponse> {
  return fetchJson<UpdatesResponse>(`${API_BASE}/assets/${encodeURIComponent(name)}/updates`);
}

export async function compareAssets(asset1: string, asset2: string): Promise<ComparisonResponse> {
  const params = new URLSearchParams({ asset1, asset2 });
  return fetchJson<ComparisonResponse>(`${API_BASE}/compare?${params}`);
}

async function postJson<T>(url: string, body?: unknown): Promise<T> {
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!response.ok) {
    const error = await response.json().catch(() => ({ error: 'Unknown error' }));
    throw new Error(error.error || `HTTP ${response.status}`);
  }
  return response.json();
}

export async function getAvailableUpdates(name: string): Promise<AvailableUpdatesResponse> {
  return fetchJson<AvailableUpdatesResponse>(
    `${API_BASE}/assets/${encodeURIComponent(name)}/updates/available`
  );
}

export async function installUpdates(
  name: string,
  kbNumbers?: string[]
): Promise<InstallUpdatesResponse> {
  const body = kbNumbers?.length ? { kb_numbers: kbNumbers } : undefined;
  return postJson<InstallUpdatesResponse>(
    `${API_BASE}/assets/${encodeURIComponent(name)}/updates/install`,
    body
  );
}

export async function upgradePackages(
  name: string,
  packages?: string[]
): Promise<UpgradeResponse> {
  const body = packages?.length ? { packages } : undefined;
  return postJson<UpgradeResponse>(
    `${API_BASE}/assets/${encodeURIComponent(name)}/packages/upgrade`,
    body
  );
}

export async function getRebootStatus(name: string): Promise<RebootStatusResponse> {
  return fetchJson<RebootStatusResponse>(
    `${API_BASE}/assets/${encodeURIComponent(name)}/reboot-status`
  );
}

export async function rebootAsset(name: string): Promise<RebootResponse> {
  return postJson<RebootResponse>(
    `${API_BASE}/assets/${encodeURIComponent(name)}/reboot`
  );
}

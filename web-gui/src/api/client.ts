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
const AUTH_KEY = 'patchpilot_auth';

export function setCredentials(username: string, password: string): void {
  sessionStorage.setItem(AUTH_KEY, btoa(`${username}:${password}`));
}

export function clearCredentials(): void {
  sessionStorage.removeItem(AUTH_KEY);
}

export function hasCredentials(): boolean {
  return !!sessionStorage.getItem(AUTH_KEY);
}

function authHeaders(): Record<string, string> {
  const token = sessionStorage.getItem(AUTH_KEY);
  return token ? { Authorization: `Basic ${token}` } : {};
}

async function apiFetch<T>(url: string, init?: RequestInit): Promise<T> {
  const response = await fetch(url, {
    ...init,
    headers: { ...authHeaders(), ...(init?.headers ?? {}) },
  });
  if (response.status === 401) throw new Error('Unauthorized');
  if (!response.ok) {
    const error = await response.json().catch(() => ({ error: 'Unknown error' }));
    throw new Error(error.error || `HTTP ${response.status}`);
  }
  return response.json();
}

export async function verifyAuth(): Promise<boolean> {
  const response = await fetch(`${API_BASE}/auth/verify`, { headers: authHeaders() });
  return response.ok;
}

export async function getHealth(): Promise<HealthResponse> {
  return apiFetch<HealthResponse>(`${API_BASE}/health`);
}

export async function getInventory(): Promise<InventoryResponse> {
  return apiFetch<InventoryResponse>(`${API_BASE}/inventory`);
}

export async function getAsset(name: string): Promise<Asset> {
  return apiFetch<Asset>(`${API_BASE}/assets/${encodeURIComponent(name)}`);
}

export async function getAssetStatus(name: string): Promise<AssetStatus> {
  return apiFetch<AssetStatus>(`${API_BASE}/assets/${encodeURIComponent(name)}/status`);
}

export async function getAssetUpdates(name: string): Promise<UpdatesResponse> {
  return apiFetch<UpdatesResponse>(`${API_BASE}/assets/${encodeURIComponent(name)}/updates`);
}

export async function compareAssets(asset1: string, asset2: string): Promise<ComparisonResponse> {
  const params = new URLSearchParams({ asset1, asset2 });
  return apiFetch<ComparisonResponse>(`${API_BASE}/compare?${params}`);
}

export async function getAvailableUpdates(name: string): Promise<AvailableUpdatesResponse> {
  return apiFetch<AvailableUpdatesResponse>(
    `${API_BASE}/assets/${encodeURIComponent(name)}/updates/available`
  );
}

export async function installUpdates(
  name: string,
  kbNumbers?: string[]
): Promise<InstallUpdatesResponse> {
  const body = kbNumbers?.length ? { kb_numbers: kbNumbers } : undefined;
  return apiFetch<InstallUpdatesResponse>(
    `${API_BASE}/assets/${encodeURIComponent(name)}/updates/install`,
    { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined }
  );
}

export async function upgradePackages(
  name: string,
  packages?: string[]
): Promise<UpgradeResponse> {
  const body = packages?.length ? { packages } : undefined;
  return apiFetch<UpgradeResponse>(
    `${API_BASE}/assets/${encodeURIComponent(name)}/packages/upgrade`,
    { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined }
  );
}

export async function getRebootStatus(name: string): Promise<RebootStatusResponse> {
  return apiFetch<RebootStatusResponse>(
    `${API_BASE}/assets/${encodeURIComponent(name)}/reboot-status`
  );
}

export async function rebootAsset(name: string): Promise<RebootResponse> {
  return apiFetch<RebootResponse>(
    `${API_BASE}/assets/${encodeURIComponent(name)}/reboot`,
    { method: 'POST' }
  );
}

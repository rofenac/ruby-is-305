import type {
  Asset,
  InventoryResponse,
  AssetStatus,
  UpdatesResponse,
  ComparisonResponse,
  HealthResponse,
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

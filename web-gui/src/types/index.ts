export interface Asset {
  name: string;
  ip: string;
  os: string;
  credential_id: string;
  deep_freeze: boolean;
  package_manager?: string;
}

export interface InventoryResponse {
  assets: Asset[];
  count: number;
}

export interface AssetStatus {
  name: string;
  status: 'online' | 'offline';
  error?: string;
}

export interface WindowsUpdate {
  kb_number: string;
  description: string;
  installed_on: string | null;
  installed_by: string | null;
  security_update: boolean;
}

export interface WindowsUpdatesResponse {
  asset: string;
  os: string;
  updates: WindowsUpdate[];
  summary: {
    total: number;
    security: number;
  };
}

export interface LinuxPackage {
  name: string;
  version: string;
  architecture: string;
}

export interface LinuxPackagesResponse {
  asset: string;
  os: string;
  package_manager: string;
  packages: {
    installed_count: number;
    upgradable_count: number;
    upgradable: LinuxPackage[];
  };
}

export type UpdatesResponse = WindowsUpdatesResponse | LinuxPackagesResponse;

export interface ComparisonResponse {
  asset1: string;
  asset2: string;
  type: 'windows_updates' | 'linux_packages';
  comparison: {
    common: string[];
    only_in_first: string[];
    only_in_second: string[];
  };
  summary: {
    common_count: number;
    only_first_count: number;
    only_second_count: number;
  };
}

export interface HealthResponse {
  status: string;
  timestamp: string;
}

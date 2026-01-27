import { useRef } from 'react';
import { useGSAP } from '@gsap/react';
import gsap from 'gsap';
import type { Asset, InventoryResponse } from '../types';
import { AssetCard } from './AssetCard';

interface DashboardProps {
  inventory: InventoryResponse | null;
  loading: boolean;
  error: string | null;
  onSelectAsset: (asset: Asset) => void;
  onRefresh: () => void;
}

export function Dashboard({ inventory, loading, error, onSelectAsset, onRefresh }: DashboardProps) {
  const headerRef = useRef<HTMLDivElement>(null);
  const statsRef = useRef<HTMLDivElement>(null);

  useGSAP(() => {
    // Wait for next frame to ensure DOM is painted
    requestAnimationFrame(() => {
      if (headerRef.current) {
        gsap.fromTo(headerRef.current,
          { opacity: 0, x: -50 },
          {
            opacity: 1,
            x: 0,
            duration: 0.6,
            ease: 'power3.out',
          }
        );
      }

      if (statsRef.current && statsRef.current.children.length > 0) {
        gsap.fromTo(statsRef.current.children,
          { opacity: 0, y: 30 },
          {
            opacity: 1,
            y: 0,
            stagger: 0.1,
            duration: 0.5,
            delay: 0.3,
            ease: 'power3.out',
          }
        );
      }
    });
  }, { dependencies: [inventory] });

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4">
        <span className="loading loading-ring loading-lg text-primary"></span>
        <p className="text-base-content/60 animate-pulse">Loading inventory...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4">
        <div className="text-6xl">⚠️</div>
        <div className="alert alert-error max-w-md">
          <span>{error}</span>
        </div>
        <button className="btn btn-primary" onClick={onRefresh}>
          Retry
        </button>
      </div>
    );
  }

  if (!inventory) return null;

  const windowsAssets = inventory.assets.filter((a) =>
    a.os.toLowerCase().includes('windows')
  );
  const linuxAssets = inventory.assets.filter((a) =>
    !a.os.toLowerCase().includes('windows')
  );
  const deepFreezeAssets = inventory.assets.filter((a) => a.deep_freeze);

  return (
    <div className="container mx-auto px-6 py-8">
      {/* Header */}
      <div ref={headerRef} className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-3xl font-bold bg-gradient-to-r from-primary to-secondary bg-clip-text text-transparent">
            Asset Inventory
          </h1>
          <p className="text-base-content/60 mt-1">
            Manage and monitor your infrastructure
          </p>
        </div>
        <button className="btn btn-outline gap-2" onClick={onRefresh}>
          <span>🔄</span>
          Refresh
        </button>
      </div>

      {/* Stats */}
      <div ref={statsRef} className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
        <div className="stat bg-base-100/50 backdrop-blur-sm rounded-box border border-base-content/10">
          <div className="stat-figure text-primary">
            <span className="text-3xl">🖥️</span>
          </div>
          <div className="stat-title">Total Assets</div>
          <div className="stat-value text-primary">{inventory.count}</div>
        </div>

        <div className="stat bg-base-100/50 backdrop-blur-sm rounded-box border border-base-content/10">
          <div className="stat-figure text-info">
            <span className="text-3xl">🪟</span>
          </div>
          <div className="stat-title">Windows</div>
          <div className="stat-value text-info">{windowsAssets.length}</div>
        </div>

        <div className="stat bg-base-100/50 backdrop-blur-sm rounded-box border border-base-content/10">
          <div className="stat-figure text-warning">
            <span className="text-3xl">🐧</span>
          </div>
          <div className="stat-title">Linux</div>
          <div className="stat-value text-warning">{linuxAssets.length}</div>
        </div>

        <div className="stat bg-base-100/50 backdrop-blur-sm rounded-box border border-base-content/10">
          <div className="stat-figure text-accent">
            <span className="text-3xl">❄️</span>
          </div>
          <div className="stat-title">Deep Freeze</div>
          <div className="stat-value text-accent">{deepFreezeAssets.length}</div>
        </div>
      </div>

      {/* Windows Section */}
      {windowsAssets.length > 0 && (
        <section className="mb-10">
          <div className="flex items-center gap-3 mb-4">
            <span className="text-2xl">🪟</span>
            <h2 className="text-xl font-semibold">Windows Systems</h2>
            <div className="badge badge-info">{windowsAssets.length}</div>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {windowsAssets.map((asset, index) => (
              <AssetCard
                key={asset.name}
                asset={asset}
                index={index}
                onSelect={onSelectAsset}
              />
            ))}
          </div>
        </section>
      )}

      {/* Linux Section */}
      {linuxAssets.length > 0 && (
        <section>
          <div className="flex items-center gap-3 mb-4">
            <span className="text-2xl">🐧</span>
            <h2 className="text-xl font-semibold">Linux Systems</h2>
            <div className="badge badge-warning">{linuxAssets.length}</div>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {linuxAssets.map((asset, index) => (
              <AssetCard
                key={asset.name}
                asset={asset}
                index={index + windowsAssets.length}
                onSelect={onSelectAsset}
              />
            ))}
          </div>
        </section>
      )}
    </div>
  );
}

import { useRef } from 'react';
import { useGSAP } from '@gsap/react';
import gsap from 'gsap';
import type { Asset, InventoryResponse } from '../types';
import { AssetCard } from './AssetCard';
import { WindowsIcon, LinuxIcon } from '../utils/osIcon';

interface DashboardProps {
  inventory: InventoryResponse | null;
  loading: boolean;
  error: string | null;
  onSelectAsset: (asset: Asset) => void;
  onRefresh: () => void;
}

interface SubsectionProps {
  title: string;
  icon: string;
  badgeClass: string;
  assets: Asset[];
  indexOffset: number;
  onSelect: (asset: Asset) => void;
  accentClass: string;
}

function AssetSubsection({ title, icon, badgeClass, assets, indexOffset, onSelect, accentClass }: SubsectionProps) {
  if (assets.length === 0) return null;
  return (
    <div className={`mb-6 pl-4 border-l-2 ${accentClass}`}>
      <div className="flex items-center gap-2 mb-3">
        <span className="text-lg">{icon}</span>
        <h3 className="text-sm font-semibold uppercase tracking-wider text-base-content/60">{title}</h3>
        <div className={`badge badge-sm ${badgeClass}`}>{assets.length}</div>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {assets.map((asset, i) => (
          <AssetCard
            key={asset.name}
            asset={asset}
            index={indexOffset + i}
            onSelect={onSelect}
          />
        ))}
      </div>
    </div>
  );
}

export function Dashboard({ inventory, loading, error, onSelectAsset, onRefresh }: DashboardProps) {
  const headerRef = useRef<HTMLDivElement>(null);
  const statsRef = useRef<HTMLDivElement>(null);

  useGSAP(() => {
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

  // Top-level OS split
  const windowsServers      = inventory.assets.filter(a => a.os === 'windows_server');
  const windowsWorkstations = inventory.assets.filter(a => a.os === 'windows_desktop');
  const linuxAssets         = inventory.assets.filter(a => !a.os.toLowerCase().includes('windows'));
  const deepFreezeAssets    = inventory.assets.filter(a => a.deep_freeze);

  // Server subsections
  const domainControllers = windowsServers.filter(a => a.role === 'domain_controller');
  const memberServers     = windowsServers.filter(a => a.role === 'member_server');
  const otherServers      = windowsServers.filter(
    a => !['domain_controller', 'member_server'].includes(a.role ?? '')
  );

  // Workstation subsections
  const teacherWorkstations = windowsWorkstations.filter(a => a.role === 'teacher_workstation');
  const labWorkstations     = windowsWorkstations.filter(a => a.role === 'endpoint');
  const hotSpares           = windowsWorkstations.filter(a => a.role === 'hot_spare');
  const nmwsWorkstations    = windowsWorkstations.filter(a => a.role === 'monitoring_workstation');
  const otherWorkstations   = windowsWorkstations.filter(
    a => !['teacher_workstation', 'endpoint', 'hot_spare', 'monitoring_workstation'].includes(a.role ?? '')
  );

  // Pre-compute index offsets for GSAP stagger continuity across subsections
  const offsets = (() => {
    let i = 0;
    const next = (n: number) => { const o = i; i += n; return o; };
    return {
      domainControllers:  next(domainControllers.length),
      memberServers:      next(memberServers.length),
      otherServers:       next(otherServers.length),
      teacherWorkstations: next(teacherWorkstations.length),
      labWorkstations:    next(labWorkstations.length),
      hotSpares:          next(hotSpares.length),
      nmwsWorkstations:   next(nmwsWorkstations.length),
      otherWorkstations:  next(otherWorkstations.length),
      linux:              next(linuxAssets.length),
    };
  })();

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
            <WindowsIcon size={30} />
          </div>
          <div className="stat-title">Windows</div>
          <div className="stat-value text-info">{windowsServers.length + windowsWorkstations.length}</div>
        </div>

        <div className="stat bg-base-100/50 backdrop-blur-sm rounded-box border border-base-content/10">
          <div className="stat-figure text-warning">
            <LinuxIcon size={30} />
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

      {/* Windows Servers */}
      {windowsServers.length > 0 && (
        <section className="mb-10">
          <div className="flex items-center gap-3 mb-5">
            <WindowsIcon size={26} />
            <h2 className="text-xl font-semibold">Windows Servers</h2>
            <div className="badge badge-error">{windowsServers.length}</div>
          </div>
          <div className="flex flex-col gap-1">
            <AssetSubsection
              title="Domain Controllers"
              icon="👑"
              badgeClass="badge-error"
              accentClass="border-error/40"
              assets={domainControllers}
              indexOffset={offsets.domainControllers}
              onSelect={onSelectAsset}
            />
            <AssetSubsection
              title="Member Servers"
              icon="🗄️"
              badgeClass="badge-warning"
              accentClass="border-warning/40"
              assets={memberServers}
              indexOffset={offsets.memberServers}
              onSelect={onSelectAsset}
            />
            <AssetSubsection
              title="Other Servers"
              icon="🖥️"
              badgeClass="badge-neutral"
              accentClass="border-neutral/40"
              assets={otherServers}
              indexOffset={offsets.otherServers}
              onSelect={onSelectAsset}
            />
          </div>
        </section>
      )}

      {/* Windows Workstations */}
      {windowsWorkstations.length > 0 && (
        <section className="mb-10">
          <div className="flex items-center gap-3 mb-5">
            <WindowsIcon size={26} />
            <h2 className="text-xl font-semibold">Windows Workstations</h2>
            <div className="badge badge-info">{windowsWorkstations.length}</div>
          </div>
          <div className="flex flex-col gap-1">
            <AssetSubsection
              title="Teacher's Workstation"
              icon="🎓"
              badgeClass="badge-secondary"
              accentClass="border-secondary/40"
              assets={teacherWorkstations}
              indexOffset={offsets.teacherWorkstations}
              onSelect={onSelectAsset}
            />
            <AssetSubsection
              title="Lab Workstations"
              icon="💻"
              badgeClass="badge-info"
              accentClass="border-info/40"
              assets={labWorkstations}
              indexOffset={offsets.labWorkstations}
              onSelect={onSelectAsset}
            />
            <AssetSubsection
              title="Hot Spares"
              icon="🔥"
              badgeClass="badge-warning"
              accentClass="border-warning/40"
              assets={hotSpares}
              indexOffset={offsets.hotSpares}
              onSelect={onSelectAsset}
            />
            <AssetSubsection
              title="Network Monitoring Workstations"
              icon="📡"
              badgeClass="badge-accent"
              accentClass="border-accent/40"
              assets={nmwsWorkstations}
              indexOffset={offsets.nmwsWorkstations}
              onSelect={onSelectAsset}
            />
            <AssetSubsection
              title="Other Workstations"
              icon="🪟"
              badgeClass="badge-neutral"
              accentClass="border-neutral/40"
              assets={otherWorkstations}
              indexOffset={offsets.otherWorkstations}
              onSelect={onSelectAsset}
            />
          </div>
        </section>
      )}

      {/* Linux Section */}
      {linuxAssets.length > 0 && (
        <section>
          <div className="flex items-center gap-3 mb-4">
            <LinuxIcon size={26} />
            <h2 className="text-xl font-semibold">Linux Systems</h2>
            <div className="badge badge-warning">{linuxAssets.length}</div>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {linuxAssets.map((asset, i) => (
              <AssetCard
                key={asset.name}
                asset={asset}
                index={offsets.linux + i}
                onSelect={onSelectAsset}
              />
            ))}
          </div>
        </section>
      )}
    </div>
  );
}

import { useRef, useState } from 'react';
import { useGSAP } from '@gsap/react';
import gsap from 'gsap';
import type { Asset, AssetStatus } from '../types';
import { getAssetStatus } from '../api/client';

interface AssetCardProps {
  asset: Asset;
  index: number;
  onSelect: (asset: Asset) => void;
}

export function AssetCard({ asset, index, onSelect }: AssetCardProps) {
  const cardRef = useRef<HTMLDivElement>(null);
  const iconRef = useRef<HTMLSpanElement>(null);
  const [status, setStatus] = useState<AssetStatus | null>(null);
  const [checking, setChecking] = useState(false);

  useGSAP(() => {
    if (cardRef.current) {
      gsap.from(cardRef.current, {
        opacity: 0,
        y: 50,
        scale: 0.9,
        duration: 0.6,
        delay: index * 0.1,
        ease: 'power3.out',
      });
    }
  }, { scope: cardRef, dependencies: [index] });

  const handleMouseEnter = () => {
    if (cardRef.current) {
      gsap.to(cardRef.current, {
        scale: 1.02,
        duration: 0.3,
        ease: 'power2.out',
      });
    }
    if (iconRef.current) {
      gsap.to(iconRef.current, {
        rotation: 10,
        scale: 1.2,
        duration: 0.3,
        ease: 'back.out(1.7)',
      });
    }
  };

  const handleMouseLeave = () => {
    if (cardRef.current) {
      gsap.to(cardRef.current, {
        scale: 1,
        duration: 0.3,
        ease: 'power2.out',
      });
    }
    if (iconRef.current) {
      gsap.to(iconRef.current, {
        rotation: 0,
        scale: 1,
        duration: 0.3,
        ease: 'power2.out',
      });
    }
  };

  const checkStatus = async () => {
    setChecking(true);

    // Animate the button
    if (cardRef.current) {
      gsap.to(cardRef.current, {
        boxShadow: '0 0 30px oklch(var(--p) / 0.5)',
        duration: 0.3,
      });
    }

    try {
      const result = await getAssetStatus(asset.name);
      setStatus(result);

      // Success/error animation
      if (cardRef.current) {
        const color = result.status === 'online' ? '--su' : '--er';
        gsap.to(cardRef.current, {
          boxShadow: `0 0 30px oklch(var(${color}) / 0.5)`,
          duration: 0.3,
        });
        setTimeout(() => {
          if (cardRef.current) {
            gsap.to(cardRef.current, {
              boxShadow: 'none',
              duration: 0.5,
            });
          }
        }, 1000);
      }
    } catch {
      setStatus({ name: asset.name, status: 'offline', error: 'Check failed' });
    }
    setChecking(false);
  };

  const isWindows = asset.os.toLowerCase().includes('windows');
  const osIcon = isWindows ? '🪟' : '🐧';

  return (
    <div
      ref={cardRef}
      className="card bg-base-100/80 backdrop-blur-sm border border-base-content/10 hover:border-primary/50 transition-colors duration-300"
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
    >
      <div className="card-body">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-3">
            <span ref={iconRef} className="text-4xl">{osIcon}</span>
            <div>
              <h2 className="card-title text-lg">{asset.name}</h2>
              <p className="text-sm text-base-content/60">{asset.ip}</p>
            </div>
          </div>
          {asset.deep_freeze && (
            <div className="badge badge-accent gap-1 animate-pulse">
              <span>❄️</span>
              Deep Freeze
            </div>
          )}
        </div>

        {/* Tags */}
        <div className="flex flex-wrap gap-2 my-3">
          <span className={`badge ${isWindows ? 'badge-info' : 'badge-warning'} badge-outline`}>
            {asset.os}
          </span>
          {asset.package_manager && (
            <span className="badge badge-ghost">{asset.package_manager.toUpperCase()}</span>
          )}
        </div>

        {/* Status */}
        {status && (
          <div className="flex items-center gap-2 p-2 rounded-lg bg-base-200/50">
            <div className={`w-3 h-3 rounded-full ${
              status.status === 'online'
                ? 'bg-success glow-success'
                : 'bg-error glow-error'
            }`} />
            <span className={`text-sm font-medium ${
              status.status === 'online' ? 'text-success' : 'text-error'
            }`}>
              {status.status === 'online' ? 'Online' : 'Offline'}
            </span>
            {status.error && (
              <span className="text-xs text-error/70">({status.error})</span>
            )}
          </div>
        )}

        {/* Actions */}
        <div className="card-actions justify-end mt-4 pt-4 border-t border-base-content/10">
          <button
            className={`btn btn-sm btn-outline gap-2 ${checking ? 'btn-disabled' : ''}`}
            onClick={checkStatus}
            disabled={checking}
          >
            {checking ? (
              <>
                <span className="loading loading-spinner loading-xs"></span>
                Checking...
              </>
            ) : (
              <>
                <span>📡</span>
                Check Status
              </>
            )}
          </button>
          <button
            className="btn btn-sm btn-primary gap-2"
            onClick={() => onSelect(asset)}
          >
            <span>🔍</span>
            View Details
          </button>
        </div>
      </div>
    </div>
  );
}

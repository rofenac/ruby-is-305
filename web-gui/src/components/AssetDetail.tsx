import { useRef, useEffect, useState } from 'react';
import { useGSAP } from '@gsap/react';
import gsap from 'gsap';
import type { Asset, UpdatesResponse, WindowsUpdatesResponse, LinuxPackagesResponse } from '../types';
import { getAssetUpdates } from '../api/client';

interface AssetDetailProps {
  asset: Asset;
  onClose: () => void;
}

function isWindowsResponse(response: UpdatesResponse): response is WindowsUpdatesResponse {
  return 'updates' in response;
}

export function AssetDetail({ asset, onClose }: AssetDetailProps) {
  const modalRef = useRef<HTMLDivElement>(null);
  const contentRef = useRef<HTMLDivElement>(null);
  const [data, setData] = useState<UpdatesResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useGSAP(() => {
    requestAnimationFrame(() => {
      if (modalRef.current) {
        gsap.fromTo(modalRef.current,
          { opacity: 0 },
          {
            opacity: 1,
            duration: 0.3,
          }
        );
      }
      if (contentRef.current) {
        gsap.fromTo(contentRef.current,
          { scale: 0.9, opacity: 0, y: 50 },
          {
            scale: 1,
            opacity: 1,
            y: 0,
            duration: 0.4,
            ease: 'back.out(1.7)',
          }
        );
      }
    });
  }, { scope: modalRef });

  useEffect(() => {
    const fetchData = async () => {
      try {
        const result = await getAssetUpdates(asset.name);
        setData(result);
      } catch (e) {
        setError((e as Error).message);
      }
      setLoading(false);
    };
    fetchData();
  }, [asset.name]);

  const handleClose = () => {
    if (contentRef.current) {
      gsap.to(contentRef.current, {
        scale: 0.9,
        opacity: 0,
        y: 50,
        duration: 0.2,
      });
    }
    if (modalRef.current) {
      gsap.to(modalRef.current, {
        opacity: 0,
        duration: 0.2,
        onComplete: onClose,
      });
    } else {
      onClose();
    }
  };

  const isWindows = asset.os.toLowerCase().includes('windows');

  return (
    <div
      ref={modalRef}
      className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm"
      onClick={handleClose}
    >
      <div
        ref={contentRef}
        className="bg-base-100 rounded-2xl shadow-2xl w-full max-w-4xl max-h-[85vh] overflow-hidden border border-base-content/10"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-base-content/10 bg-base-200/50">
          <div className="flex items-center gap-4">
            <span className="text-4xl">{isWindows ? '🪟' : '🐧'}</span>
            <div>
              <h2 className="text-2xl font-bold">{asset.name}</h2>
              <p className="text-base-content/60">{asset.ip} • {asset.os}</p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            {asset.deep_freeze && (
              <div className="badge badge-accent gap-1">
                <span>❄️</span>
                Deep Freeze
              </div>
            )}
            <button className="btn btn-circle btn-ghost" onClick={handleClose}>
              ✕
            </button>
          </div>
        </div>

        {/* Content */}
        <div className="p-6 overflow-y-auto max-h-[calc(85vh-120px)]">
          {loading && (
            <div className="flex flex-col items-center justify-center py-12 gap-4">
              <span className="loading loading-dots loading-lg text-primary"></span>
              <p className="text-base-content/60">Querying {isWindows ? 'updates' : 'packages'}...</p>
            </div>
          )}

          {error && (
            <div className="alert alert-error">
              <span>⚠️</span>
              <span>{error}</span>
            </div>
          )}

          {data && isWindowsResponse(data) && (
            <WindowsUpdatesList data={data} />
          )}

          {data && !isWindowsResponse(data) && (
            <LinuxPackagesList data={data} />
          )}
        </div>
      </div>
    </div>
  );
}

function WindowsUpdatesList({ data }: { data: WindowsUpdatesResponse }) {
  const listRef = useRef<HTMLDivElement>(null);

  useGSAP(() => {
    requestAnimationFrame(() => {
      if (listRef.current) {
        const rows = listRef.current.querySelectorAll('tr');
        if (rows.length > 0) {
          gsap.fromTo(rows,
            { opacity: 0, x: -20 },
            {
              opacity: 1,
              x: 0,
              stagger: 0.03,
              duration: 0.3,
              ease: 'power2.out',
            }
          );
        }
      }
    });
  }, { scope: listRef, dependencies: [data] });

  return (
    <div ref={listRef}>
      {/* Summary Stats */}
      <div className="grid grid-cols-2 gap-4 mb-6">
        <div className="stat bg-base-200/50 rounded-box">
          <div className="stat-title">Total Updates</div>
          <div className="stat-value text-primary">{data.summary.total}</div>
        </div>
        <div className="stat bg-base-200/50 rounded-box">
          <div className="stat-title">Security Updates</div>
          <div className="stat-value text-error">{data.summary.security}</div>
        </div>
      </div>

      {/* Updates Table */}
      <div className="overflow-x-auto">
        <table className="table table-zebra">
          <thead>
            <tr>
              <th>KB Number</th>
              <th>Description</th>
              <th>Installed On</th>
              <th>Type</th>
            </tr>
          </thead>
          <tbody>
            {data.updates.map((update) => (
              <tr key={update.kb_number} className="hover">
                <td>
                  <code className="text-primary">{update.kb_number}</code>
                </td>
                <td>{update.description}</td>
                <td className="text-base-content/70">
                  {update.installed_on || 'Unknown'}
                </td>
                <td>
                  {update.security_update ? (
                    <span className="badge badge-error badge-sm">Security</span>
                  ) : (
                    <span className="badge badge-ghost badge-sm">Update</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function LinuxPackagesList({ data }: { data: LinuxPackagesResponse }) {
  const listRef = useRef<HTMLDivElement>(null);

  useGSAP(() => {
    requestAnimationFrame(() => {
      if (listRef.current) {
        const elements = listRef.current.querySelectorAll('.stat, tr');
        if (elements.length > 0) {
          gsap.fromTo(elements,
            { opacity: 0, x: -20 },
            {
              opacity: 1,
              x: 0,
              stagger: 0.03,
              duration: 0.3,
              ease: 'power2.out',
            }
          );
        }
      }
    });
  }, { scope: listRef, dependencies: [data] });

  return (
    <div ref={listRef}>
      {/* Summary Stats */}
      <div className="grid grid-cols-3 gap-4 mb-6">
        <div className="stat bg-base-200/50 rounded-box">
          <div className="stat-title">Package Manager</div>
          <div className="stat-value text-lg">{data.package_manager.toUpperCase()}</div>
        </div>
        <div className="stat bg-base-200/50 rounded-box">
          <div className="stat-title">Installed</div>
          <div className="stat-value text-primary">{data.packages.installed_count}</div>
        </div>
        <div className="stat bg-base-200/50 rounded-box">
          <div className="stat-title">Upgradable</div>
          <div className="stat-value text-warning">{data.packages.upgradable_count}</div>
        </div>
      </div>

      {/* Upgradable Packages */}
      {data.packages.upgradable.length > 0 ? (
        <>
          <h3 className="text-lg font-semibold mb-3 flex items-center gap-2">
            <span>⬆️</span>
            Packages with Available Updates
          </h3>
          <div className="overflow-x-auto">
            <table className="table table-zebra">
              <thead>
                <tr>
                  <th>Package</th>
                  <th>New Version</th>
                  <th>Architecture</th>
                </tr>
              </thead>
              <tbody>
                {data.packages.upgradable.map((pkg) => (
                  <tr key={pkg.name} className="hover">
                    <td>
                      <code className="text-warning">{pkg.name}</code>
                    </td>
                    <td className="text-base-content/70">{pkg.version}</td>
                    <td>
                      <span className="badge badge-ghost badge-sm">{pkg.architecture}</span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      ) : (
        <div className="alert alert-success">
          <span>✓</span>
          <span>All packages are up to date!</span>
        </div>
      )}
    </div>
  );
}

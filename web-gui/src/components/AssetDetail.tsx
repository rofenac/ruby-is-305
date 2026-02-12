import { useRef, useEffect, useState, useCallback } from 'react';
import { useGSAP } from '@gsap/react';
import gsap from 'gsap';
import type {
  Asset, UpdatesResponse, WindowsUpdatesResponse, LinuxPackagesResponse,
  AvailableUpdatesResponse, InstallUpdatesResponse, UpgradeResponse,
} from '../types';
import {
  getAssetUpdates, getAvailableUpdates, installUpdates,
  upgradePackages, getRebootStatus, rebootAsset,
} from '../api/client';

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
  const [rebootNeeded, setRebootNeeded] = useState(false);
  const [checkingReboot, setCheckingReboot] = useState(false);
  const [rebooting, setRebooting] = useState(false);
  const [rebootDone, setRebootDone] = useState(false);
  const [rebootError, setRebootError] = useState<string | null>(null);

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

  const handleRebootRequired = useCallback(() => {
    setRebootNeeded(true);
  }, []);

  const handleCheckReboot = async () => {
    setCheckingReboot(true);
    setRebootError(null);
    try {
      const result = await getRebootStatus(asset.name);
      setRebootNeeded(result.reboot_required);
    } catch (e) {
      setRebootError((e as Error).message);
    }
    setCheckingReboot(false);
  };

  const handleReboot = async () => {
    setRebooting(true);
    setRebootError(null);
    try {
      await rebootAsset(asset.name);
      setRebootDone(true);
      setRebootNeeded(false);
    } catch (e) {
      setRebootError((e as Error).message);
    }
    setRebooting(false);
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
            <WindowsUpdatesList
              data={data}
              assetName={asset.name}
              deepFreeze={asset.deep_freeze}
              onRebootRequired={handleRebootRequired}
            />
          )}

          {data && !isWindowsResponse(data) && (
            <LinuxPackagesList
              data={data}
              assetName={asset.name}
              onRebootRequired={handleRebootRequired}
            />
          )}

          {/* Reboot Section */}
          {!loading && !error && data && (
            <div className="mt-6 pt-6 border-t border-base-content/10">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-semibold">Reboot Status</h3>
                <button
                  className="btn btn-sm btn-outline"
                  onClick={handleCheckReboot}
                  disabled={checkingReboot}
                >
                  {checkingReboot ? (
                    <><span className="loading loading-spinner loading-xs"></span> Checking...</>
                  ) : 'Check Reboot Status'}
                </button>
              </div>

              {rebootError && (
                <div className="alert alert-error mb-4">
                  <span>⚠️</span>
                  <span>{rebootError}</span>
                </div>
              )}

              {rebootDone && (
                <div className="alert alert-success mb-4">
                  <span>✓</span>
                  <span>Reboot command sent to {asset.name}. The system is restarting.</span>
                </div>
              )}

              {rebootNeeded && !rebootDone && (
                <div className="space-y-3">
                  <div className="alert alert-warning">
                    <span>⚠️</span>
                    <span>A reboot is required to complete the update process.</span>
                  </div>

                  {asset.deep_freeze ? (
                    <div className="alert alert-info">
                      <span>❄️</span>
                      <span>Reboot is managed by Deep Freeze Enterprise.</span>
                    </div>
                  ) : (
                    <button
                      className="btn btn-warning"
                      onClick={handleReboot}
                      disabled={rebooting}
                    >
                      {rebooting ? (
                        <><span className="loading loading-spinner loading-xs"></span> Rebooting...</>
                      ) : 'Reboot Now'}
                    </button>
                  )}
                </div>
              )}

              {!rebootNeeded && !rebootDone && !checkingReboot && (
                <p className="text-base-content/50 text-sm">No reboot pending, or click above to check.</p>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

interface WindowsUpdatesListProps {
  data: WindowsUpdatesResponse;
  assetName: string;
  deepFreeze: boolean;
  onRebootRequired: () => void;
}

function WindowsUpdatesList({ data, assetName, deepFreeze, onRebootRequired }: WindowsUpdatesListProps) {
  const listRef = useRef<HTMLDivElement>(null);
  const [available, setAvailable] = useState<AvailableUpdatesResponse | null>(null);
  const [loadingAvailable, setLoadingAvailable] = useState(false);
  const [availableError, setAvailableError] = useState<string | null>(null);
  const [installing, setInstalling] = useState(false);
  const [installResult, setInstallResult] = useState<InstallUpdatesResponse | null>(null);
  const [showConfirm, setShowConfirm] = useState(false);

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

  const handleCheckAvailable = async () => {
    setLoadingAvailable(true);
    setAvailableError(null);
    try {
      const result = await getAvailableUpdates(assetName);
      setAvailable(result);
      if (result.reboot_pending) {
        onRebootRequired();
      }
    } catch (e) {
      setAvailableError((e as Error).message);
    }
    setLoadingAvailable(false);
  };

  const handleInstall = async () => {
    setShowConfirm(false);
    setInstalling(true);
    try {
      const result = await installUpdates(assetName);
      setInstallResult(result);
      if (result.reboot_required) {
        onRebootRequired();
      }
    } catch (e) {
      setInstallResult({
        asset: assetName,
        result: 'Failed',
        succeeded: false,
        reboot_required: false,
        update_count: 0,
        updates: [],
      });
      setAvailableError((e as Error).message);
    }
    setInstalling(false);
  };

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

      {/* Installed Updates Table */}
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

      {/* Available Updates Section */}
      <div className="divider mt-8">Available Updates</div>

      {!available && !loadingAvailable && !installResult && (
        <div className="flex justify-center">
          <button className="btn btn-primary" onClick={handleCheckAvailable}>
            Check for Available Updates
          </button>
        </div>
      )}

      {loadingAvailable && (
        <div className="flex flex-col items-center justify-center py-8 gap-4">
          <span className="loading loading-dots loading-lg text-primary"></span>
          <p className="text-base-content/60">Searching for available updates...</p>
        </div>
      )}

      {availableError && !installing && (
        <div className="alert alert-error mt-4">
          <span>⚠️</span>
          <span>{availableError}</span>
        </div>
      )}

      {available && !installing && !installResult && (
        <div className="mt-4">
          {available.available_updates.length === 0 ? (
            <div className="alert alert-success">
              <span>✓</span>
              <span>No available updates. This system is fully up to date!</span>
            </div>
          ) : (
            <>
              <div className="grid grid-cols-3 gap-4 mb-4">
                <div className="stat bg-base-200/50 rounded-box">
                  <div className="stat-title">Available</div>
                  <div className="stat-value text-warning">{available.summary.total}</div>
                </div>
                <div className="stat bg-base-200/50 rounded-box">
                  <div className="stat-title">Security</div>
                  <div className="stat-value text-error">{available.summary.security}</div>
                </div>
                <div className="stat bg-base-200/50 rounded-box">
                  <div className="stat-title">Downloaded</div>
                  <div className="stat-value text-info">{available.summary.downloaded}</div>
                </div>
              </div>

              <div className="overflow-x-auto mb-4">
                <table className="table table-zebra">
                  <thead>
                    <tr>
                      <th>KB Number</th>
                      <th>Title</th>
                      <th>Size</th>
                      <th>Severity</th>
                    </tr>
                  </thead>
                  <tbody>
                    {available.available_updates.map((update) => (
                      <tr key={update.kb_number} className="hover">
                        <td><code className="text-warning">{update.kb_number}</code></td>
                        <td className="max-w-xs truncate">{update.title}</td>
                        <td className="text-base-content/70">
                          {update.size_mb ? `${update.size_mb} MB` : 'Unknown'}
                        </td>
                        <td>
                          {update.severity !== 'Unspecified' ? (
                            <span className="badge badge-error badge-sm">{update.severity}</span>
                          ) : (
                            <span className="badge badge-ghost badge-sm">Unspecified</span>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {deepFreeze ? (
                <div className="alert alert-info mt-2">
                  <span>❄️</span>
                  <span>Updates managed by Deep Freeze Enterprise. Use the Compare view to verify installation.</span>
                </div>
              ) : available.reboot_pending ? (
                <div className="alert alert-warning mt-2">
                  <span>⚠️</span>
                  <span>A reboot is pending. Reboot to finalize installed updates before installing new ones.</span>
                </div>
              ) : !showConfirm ? (
                <div className="flex justify-center">
                  <button className="btn btn-warning" onClick={() => setShowConfirm(true)}>
                    Install All Updates ({available.summary.total})
                  </button>
                </div>
              ) : (
                <div className="alert alert-info">
                  <span>Install {available.summary.total} updates on {assetName}?</span>
                  <div className="flex gap-2">
                    <button className="btn btn-sm btn-primary" onClick={handleInstall}>Confirm</button>
                    <button className="btn btn-sm btn-ghost" onClick={() => setShowConfirm(false)}>Cancel</button>
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      )}

      {/* Installing Progress */}
      {installing && (
        <div className="flex flex-col items-center justify-center py-8 gap-4">
          <span className="loading loading-dots loading-lg text-warning"></span>
          <p className="text-base-content/60">Installing updates... This may take several minutes.</p>
          <p className="text-xs text-base-content/40">Do not close this window.</p>
        </div>
      )}

      {/* Installation Result */}
      {installResult && (
        <div className="mt-4 space-y-4">
          <div className={`alert ${installResult.succeeded ? 'alert-success' : 'alert-error'}`}>
            <span>{installResult.succeeded ? '✓' : '⚠️'}</span>
            <div>
              <p className="font-bold">
                {installResult.succeeded ? 'Installation Succeeded' : 'Installation Failed'}
              </p>
              <p>{installResult.update_count} update(s) processed — {installResult.result}</p>
            </div>
          </div>

          {installResult.updates.length > 0 && (
            <div className="overflow-x-auto">
              <table className="table table-zebra">
                <thead>
                  <tr>
                    <th>KB Number</th>
                    <th>Title</th>
                    <th>Result</th>
                  </tr>
                </thead>
                <tbody>
                  {installResult.updates.map((u) => (
                    <tr key={u.kb_number} className="hover">
                      <td><code className="text-primary">{u.kb_number}</code></td>
                      <td>{u.title}</td>
                      <td>
                        <span className={`badge badge-sm ${u.succeeded ? 'badge-success' : 'badge-error'}`}>
                          {u.result}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

interface LinuxPackagesListProps {
  data: LinuxPackagesResponse;
  assetName: string;
  onRebootRequired: () => void;
}

function LinuxPackagesList({ data, assetName, onRebootRequired }: LinuxPackagesListProps) {
  const listRef = useRef<HTMLDivElement>(null);
  const [upgrading, setUpgrading] = useState(false);
  const [upgradeResult, setUpgradeResult] = useState<UpgradeResponse | null>(null);
  const [upgradeError, setUpgradeError] = useState<string | null>(null);
  const [showConfirm, setShowConfirm] = useState(false);

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

  const handleUpgrade = async () => {
    setShowConfirm(false);
    setUpgrading(true);
    setUpgradeError(null);
    try {
      const result = await upgradePackages(assetName);
      setUpgradeResult(result);
      // After a successful upgrade, check if reboot is needed
      if (result.succeeded) {
        try {
          const rebootStatus = await getRebootStatus(assetName);
          if (rebootStatus.reboot_required) {
            onRebootRequired();
          }
        } catch {
          // Non-critical — reboot check failure shouldn't hide the upgrade result
        }
      }
    } catch (e) {
      setUpgradeError((e as Error).message);
    }
    setUpgrading(false);
  };

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

          {/* Upgrade Actions */}
          {!upgrading && !upgradeResult && (
            <div className="mt-4 flex justify-center">
              {!showConfirm ? (
                <button className="btn btn-warning" onClick={() => setShowConfirm(true)}>
                  Upgrade All Packages ({data.packages.upgradable_count})
                </button>
              ) : (
                <div className="alert alert-info w-full">
                  <span>Upgrade {data.packages.upgradable_count} packages on {assetName}?</span>
                  <div className="flex gap-2">
                    <button className="btn btn-sm btn-primary" onClick={handleUpgrade}>Confirm</button>
                    <button className="btn btn-sm btn-ghost" onClick={() => setShowConfirm(false)}>Cancel</button>
                  </div>
                </div>
              )}
            </div>
          )}
        </>
      ) : (
        <div className="alert alert-success">
          <span>✓</span>
          <span>All packages are up to date!</span>
        </div>
      )}

      {/* Upgrading Progress */}
      {upgrading && (
        <div className="flex flex-col items-center justify-center py-8 gap-4">
          <span className="loading loading-dots loading-lg text-warning"></span>
          <p className="text-base-content/60">Upgrading packages... This may take several minutes.</p>
          <p className="text-xs text-base-content/40">Do not close this window.</p>
        </div>
      )}

      {upgradeError && !upgrading && (
        <div className="alert alert-error mt-4">
          <span>⚠️</span>
          <span>{upgradeError}</span>
        </div>
      )}

      {/* Upgrade Result */}
      {upgradeResult && (
        <div className="mt-4 space-y-4">
          <div className={`alert ${upgradeResult.succeeded ? 'alert-success' : 'alert-error'}`}>
            <span>{upgradeResult.succeeded ? '✓' : '⚠️'}</span>
            <div>
              <p className="font-bold">
                {upgradeResult.succeeded ? 'Upgrade Succeeded' : 'Upgrade Failed'}
              </p>
              <p>{upgradeResult.upgraded_count} package(s) upgraded</p>
            </div>
          </div>

          {upgradeResult.error && (
            <div className="alert alert-error">
              <span>⚠️</span>
              <span>{upgradeResult.error}</span>
            </div>
          )}

          {upgradeResult.upgraded_packages.length > 0 && (
            <div className="flex flex-wrap gap-2">
              {upgradeResult.upgraded_packages.map((pkg) => (
                <span key={pkg} className="badge badge-success badge-outline">{pkg}</span>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

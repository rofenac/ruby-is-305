import { useRef, useState } from 'react';
import { useGSAP } from '@gsap/react';
import gsap from 'gsap';
import type { Asset, InventoryResponse, ComparisonResponse, SecurityUpdateEntry } from '../types';
import { OsIcon, WindowsIcon, LinuxIcon } from '../utils/osIcon';
import { compareAssets } from '../api/client';

interface CompareViewProps {
  inventory: InventoryResponse | null;
}

export function CompareView({ inventory }: CompareViewProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const resultsRef = useRef<HTMLDivElement>(null);
  const [asset1, setAsset1] = useState<string>('');
  const [asset2, setAsset2] = useState<string>('');
  const [comparison, setComparison] = useState<ComparisonResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useGSAP(() => {
    requestAnimationFrame(() => {
      if (containerRef.current) {
        gsap.fromTo(containerRef.current,
          { opacity: 0, y: 30 },
          {
            opacity: 1,
            y: 0,
            duration: 0.6,
            ease: 'power3.out',
          }
        );
      }
    });
  }, { scope: containerRef });

  const handleCompare = async () => {
    if (!asset1 || !asset2) return;

    setLoading(true);
    setError(null);
    setComparison(null);

    try {
      const result = await compareAssets(asset1, asset2);
      setComparison(result);

      // Animate results after state update
      requestAnimationFrame(() => {
        if (resultsRef.current) {
          gsap.fromTo(resultsRef.current,
            { opacity: 0, y: 30 },
            {
              opacity: 1,
              y: 0,
              duration: 0.5,
              ease: 'power3.out',
            }
          );
        }
      });
    } catch (e) {
      setError((e as Error).message);
    }
    setLoading(false);
  };

  const getAssetByName = (name: string): Asset | undefined =>
    inventory?.assets.find((a) => a.name === name);

  const groupAssets = () => {
    if (!inventory) return { windows: [], linux: [] };
    return {
      windows: inventory.assets.filter((a) =>
        a.os.toLowerCase().includes('windows')
      ),
      linux: inventory.assets.filter((a) =>
        !a.os.toLowerCase().includes('windows')
      ),
    };
  };

  const { windows, linux } = groupAssets();
  const selectedAsset1 = getAssetByName(asset1);
  const selectedAsset2 = getAssetByName(asset2);

  return (
    <div ref={containerRef} className="container mx-auto px-6 py-8">
      {/* Header */}
      <div className="text-center mb-8">
        <h1 className="text-3xl font-bold bg-gradient-to-r from-primary to-secondary bg-clip-text text-transparent">
          Compare Assets
        </h1>
        <p className="text-base-content/60 mt-2">
          Compare updates or packages between two systems
        </p>
      </div>

      {/* Selection Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-8 mb-8">
        {/* Asset 1 */}
        <div className="card bg-base-100/80 backdrop-blur-sm border border-base-content/10">
          <div className="card-body">
            <h3 className="card-title text-lg mb-4">
              <span className="text-primary">①</span> First Asset
            </h3>

            {windows.length > 0 && (
              <div className="mb-4">
                <label className="label">
                  <span className="label-text flex items-center gap-2">
                    <WindowsIcon size={16} /> Windows
                  </span>
                </label>
                <select
                  className="select select-bordered w-full"
                  value={selectedAsset1?.os.toLowerCase().includes('windows') ? asset1 : ''}
                  onChange={(e) => setAsset1(e.target.value)}
                >
                  <option value="">Select a Windows asset...</option>
                  {windows.map((a) => (
                    <option key={a.name} value={a.name}>
                      {a.name} ({a.ip}) {a.deep_freeze ? '❄️' : ''}
                    </option>
                  ))}
                </select>
              </div>
            )}

            {linux.length > 0 && (
              <div>
                <label className="label">
                  <span className="label-text flex items-center gap-2">
                    <LinuxIcon size={16} /> Linux
                  </span>
                </label>
                <select
                  className="select select-bordered w-full"
                  value={!selectedAsset1?.os.toLowerCase().includes('windows') ? asset1 : ''}
                  onChange={(e) => setAsset1(e.target.value)}
                >
                  <option value="">Select a Linux asset...</option>
                  {linux.map((a) => (
                    <option key={a.name} value={a.name}>
                      {a.name} ({a.ip})
                    </option>
                  ))}
                </select>
              </div>
            )}

            {selectedAsset1 && (
              <div className="mt-4 p-3 rounded-lg bg-base-200/50 flex items-center gap-3">
                <OsIcon asset={selectedAsset1} size={28} />
                <div>
                  <p className="font-medium">{selectedAsset1.name}</p>
                  <p className="text-sm text-base-content/60">{selectedAsset1.os}</p>
                </div>
                {selectedAsset1.deep_freeze && (
                  <span className="badge badge-accent ml-auto">❄️ Deep Freeze</span>
                )}
              </div>
            )}
          </div>
        </div>

        {/* Asset 2 */}
        <div className="card bg-base-100/80 backdrop-blur-sm border border-base-content/10">
          <div className="card-body">
            <h3 className="card-title text-lg mb-4">
              <span className="text-secondary">②</span> Second Asset
            </h3>

            {windows.length > 0 && (
              <div className="mb-4">
                <label className="label">
                  <span className="label-text flex items-center gap-2">
                    <WindowsIcon size={16} /> Windows
                  </span>
                </label>
                <select
                  className="select select-bordered w-full"
                  value={selectedAsset2?.os.toLowerCase().includes('windows') ? asset2 : ''}
                  onChange={(e) => setAsset2(e.target.value)}
                >
                  <option value="">Select a Windows asset...</option>
                  {windows.map((a) => (
                    <option key={a.name} value={a.name}>
                      {a.name} ({a.ip}) {a.deep_freeze ? '❄️' : ''}
                    </option>
                  ))}
                </select>
              </div>
            )}

            {linux.length > 0 && (
              <div>
                <label className="label">
                  <span className="label-text flex items-center gap-2">
                    <LinuxIcon size={16} /> Linux
                  </span>
                </label>
                <select
                  className="select select-bordered w-full"
                  value={!selectedAsset2?.os.toLowerCase().includes('windows') ? asset2 : ''}
                  onChange={(e) => setAsset2(e.target.value)}
                >
                  <option value="">Select a Linux asset...</option>
                  {linux.map((a) => (
                    <option key={a.name} value={a.name}>
                      {a.name} ({a.ip})
                    </option>
                  ))}
                </select>
              </div>
            )}

            {selectedAsset2 && (
              <div className="mt-4 p-3 rounded-lg bg-base-200/50 flex items-center gap-3">
                <OsIcon asset={selectedAsset2} size={28} />
                <div>
                  <p className="font-medium">{selectedAsset2.name}</p>
                  <p className="text-sm text-base-content/60">{selectedAsset2.os}</p>
                </div>
                {selectedAsset2.deep_freeze && (
                  <span className="badge badge-accent ml-auto">❄️ Deep Freeze</span>
                )}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Compare Button */}
      <div className="flex justify-center mb-8">
        <button
          className={`btn btn-primary btn-lg gap-2 ${loading ? 'loading' : ''}`}
          onClick={handleCompare}
          disabled={!asset1 || !asset2 || loading}
        >
          {loading ? (
            'Comparing...'
          ) : (
            <>
              <span>⚖️</span>
              Compare Assets
            </>
          )}
        </button>
      </div>

      {/* Error */}
      {error && (
        <div className="alert alert-error mb-8">
          <span>⚠️</span>
          <span>{error}</span>
        </div>
      )}

      {/* Results */}
      {comparison && (
        <div ref={resultsRef}>
          <ComparisonResults comparison={comparison} asset1={selectedAsset1!} asset2={selectedAsset2!} />
        </div>
      )}
    </div>
  );
}

interface ComparisonResultsProps {
  comparison: ComparisonResponse;
  asset1: Asset;
  asset2: Asset;
}

function ItemList({ items, isWindows }: { items: SecurityUpdateEntry[] | string[]; isWindows: boolean }) {
  if (items.length === 0) {
    return <p className="text-base-content/50 italic">None</p>;
  }
  if (isWindows) {
    return (
      <ul className="space-y-1">
        {(items as SecurityUpdateEntry[]).map((entry) => (
          <li key={entry.kb ?? entry.title} className="text-sm p-2 rounded bg-base-200/50 leading-snug">
            {entry.title}
          </li>
        ))}
      </ul>
    );
  }
  return (
    <ul className="space-y-1">
      {(items as string[]).map((item) => (
        <li key={item} className="text-sm p-2 rounded bg-base-200/50">
          <code>{item}</code>
        </li>
      ))}
    </ul>
  );
}

function ComparisonResults({ comparison, asset1, asset2 }: ComparisonResultsProps) {
  const cardsRef = useRef<HTMLDivElement>(null);

  useGSAP(() => {
    requestAnimationFrame(() => {
      if (cardsRef.current && cardsRef.current.children.length > 0) {
        gsap.fromTo(cardsRef.current.children,
          { opacity: 0, y: 30, scale: 0.95 },
          {
            opacity: 1,
            y: 0,
            scale: 1,
            stagger: 0.1,
            duration: 0.5,
            ease: 'power3.out',
          }
        );
      }
    });
  }, { scope: cardsRef, dependencies: [comparison] });

  const isWindows = comparison.type === 'windows_updates';
  const itemLabel = isWindows ? 'Security Updates' : 'Packages';

  const common     = comparison.comparison.common     as SecurityUpdateEntry[] | string[];
  const onlyFirst  = comparison.comparison.only_in_first  as SecurityUpdateEntry[] | string[];
  const onlySecond = comparison.comparison.only_in_second as SecurityUpdateEntry[] | string[];

  return (
    <div className="space-y-6">
      {/* Summary */}
      <div className="card bg-gradient-to-r from-primary/20 to-secondary/20 border border-primary/30">
        <div className="card-body">
          <h3 className="card-title justify-center text-xl mb-4">
            {isWindows ? 'Security Update Comparison' : 'Package Comparison'}
          </h3>
          <div ref={cardsRef} className="grid grid-cols-3 gap-4 text-center">
            <div className="stat">
              <div className="stat-title">Common {itemLabel}</div>
              <div className="stat-value text-success">{comparison.summary.common_count}</div>
            </div>
            <div className="stat">
              <div className="stat-title">Only in {asset1.name}</div>
              <div className="stat-value text-info">{comparison.summary.only_first_count}</div>
            </div>
            <div className="stat">
              <div className="stat-title">Only in {asset2.name}</div>
              <div className="stat-value text-warning">{comparison.summary.only_second_count}</div>
            </div>
          </div>
        </div>
      </div>

      {/* Detailed Lists */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Common */}
        <div className="card bg-base-100/80 border border-success/30">
          <div className="card-body">
            <h4 className="card-title text-success text-lg">
              <span>✓</span>
              Common ({common.length})
            </h4>
            <div className="max-h-64 overflow-y-auto">
              <ItemList items={common} isWindows={isWindows} />
            </div>
          </div>
        </div>

        {/* Only in Asset 1 */}
        <div className="card bg-base-100/80 border border-info/30">
          <div className="card-body">
            <h4 className="card-title text-info text-lg">
              <span>①</span>
              Only in {asset1.name} ({onlyFirst.length})
            </h4>
            <div className="max-h-64 overflow-y-auto">
              <ItemList items={onlyFirst} isWindows={isWindows} />
            </div>
          </div>
        </div>

        {/* Only in Asset 2 */}
        <div className="card bg-base-100/80 border border-warning/30">
          <div className="card-body">
            <h4 className="card-title text-warning text-lg">
              <span>②</span>
              Only in {asset2.name} ({onlySecond.length})
            </h4>
            <div className="max-h-64 overflow-y-auto">
              <ItemList items={onlySecond} isWindows={isWindows} />
            </div>
          </div>
        </div>
      </div>

      {/* Deep Freeze Analysis */}
      {isWindows && (asset1.deep_freeze || asset2.deep_freeze) && (
        <div className="card bg-gradient-to-r from-accent/20 to-primary/20 border border-accent/30">
          <div className="card-body">
            <h4 className="card-title">
              <span>❄️</span>
              Deep Freeze Security Patch Analysis
            </h4>
            <div className="prose prose-sm">
              {asset1.deep_freeze && !asset2.deep_freeze && (
                <p>
                  <strong>{asset1.name}</strong> is managed by Deep Freeze.
                  {comparison.summary.only_second_count > 0 ? (
                    <span className="text-warning">
                      {' '}{comparison.summary.only_second_count} security update(s) on {asset2.name} are
                      missing from the frozen endpoint — DFE may not have applied them yet.
                    </span>
                  ) : (
                    <span className="text-success">
                      {' '}Both endpoints have identical security updates — DFE is applying patches correctly.
                    </span>
                  )}
                </p>
              )}
              {asset2.deep_freeze && !asset1.deep_freeze && (
                <p>
                  <strong>{asset2.name}</strong> is managed by Deep Freeze.
                  {comparison.summary.only_first_count > 0 ? (
                    <span className="text-warning">
                      {' '}{comparison.summary.only_first_count} security update(s) on {asset1.name} are
                      missing from the frozen endpoint — DFE may not have applied them yet.
                    </span>
                  ) : (
                    <span className="text-success">
                      {' '}Both endpoints have identical security updates — DFE is applying patches correctly.
                    </span>
                  )}
                </p>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

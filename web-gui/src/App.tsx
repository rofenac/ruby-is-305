import { useState, useEffect, useCallback } from 'react';
import { gsap } from 'gsap';
import { useGSAP } from '@gsap/react';
import './index.css';
import { Navbar, Dashboard, AssetDetail, CompareView } from './components';
import { getHealth, getInventory } from './api/client';
import type { Asset, InventoryResponse } from './types';

// Register GSAP
gsap.registerPlugin(useGSAP);

type View = 'dashboard' | 'compare';
type ApiStatus = 'connected' | 'disconnected' | 'checking';

function App() {
  const [currentView, setCurrentView] = useState<View>('dashboard');
  const [apiStatus, setApiStatus] = useState<ApiStatus>('checking');
  const [inventory, setInventory] = useState<InventoryResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedAsset, setSelectedAsset] = useState<Asset | null>(null);

  const checkApiHealth = useCallback(async () => {
    setApiStatus('checking');
    try {
      await getHealth();
      setApiStatus('connected');
      return true;
    } catch {
      setApiStatus('disconnected');
      return false;
    }
  }, []);

  const loadInventory = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await getInventory();
      setInventory(data);
    } catch (e) {
      setError((e as Error).message);
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    const init = async () => {
      const healthy = await checkApiHealth();
      if (healthy) {
        await loadInventory();
      } else {
        setLoading(false);
        setError('Cannot connect to API server. Make sure the backend is running on port 4567.');
      }
    };
    init();

    // Periodic health check
    const interval = setInterval(checkApiHealth, 30000);
    return () => clearInterval(interval);
  }, [checkApiHealth, loadInventory]);

  const handleRefresh = async () => {
    await checkApiHealth();
    await loadInventory();
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-base-300 via-base-300 to-base-200">
      {/* Background decoration */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-40 -right-40 w-80 h-80 bg-primary/10 rounded-full blur-3xl" />
        <div className="absolute -bottom-40 -left-40 w-80 h-80 bg-secondary/10 rounded-full blur-3xl" />
      </div>

      {/* Content */}
      <div className="relative z-10">
        <Navbar
          onNavigate={setCurrentView}
          currentView={currentView}
          apiStatus={apiStatus}
        />

        <main>
          {currentView === 'dashboard' && (
            <Dashboard
              inventory={inventory}
              loading={loading}
              error={error}
              onSelectAsset={setSelectedAsset}
              onRefresh={handleRefresh}
            />
          )}

          {currentView === 'compare' && (
            <CompareView inventory={inventory} />
          )}
        </main>

        {/* Asset Detail Modal */}
        {selectedAsset && (
          <AssetDetail
            asset={selectedAsset}
            onClose={() => setSelectedAsset(null)}
          />
        )}
      </div>
    </div>
  );
}

export default App;

import { useRef } from 'react';
import { useGSAP } from '@gsap/react';
import gsap from 'gsap';

type View = 'dashboard' | 'compare';

interface NavbarProps {
  onNavigate: (view: View) => void;
  currentView: View;
  apiStatus: 'connected' | 'disconnected' | 'checking';
}

export function Navbar({ onNavigate, currentView, apiStatus }: NavbarProps) {
  const navRef = useRef<HTMLDivElement>(null);
  const logoRef = useRef<HTMLButtonElement>(null);

  useGSAP(() => {
    if (navRef.current) {
      gsap.from(navRef.current, {
        y: -100,
        opacity: 0,
        duration: 0.8,
        ease: 'power3.out',
      });
    }

    if (logoRef.current) {
      gsap.from(logoRef.current, {
        scale: 0,
        rotation: -180,
        duration: 0.6,
        delay: 0.3,
        ease: 'back.out(1.7)',
      });
    }
  }, { scope: navRef });

  const statusColor = {
    connected: 'bg-success',
    disconnected: 'bg-error',
    checking: 'bg-warning',
  }[apiStatus];

  const statusText = {
    connected: 'API Connected',
    disconnected: 'API Offline',
    checking: 'Connecting...',
  }[apiStatus];

  return (
    <div ref={navRef} className="navbar bg-base-200/80 backdrop-blur-lg shadow-xl sticky top-0 z-50 border-b border-base-content/10">
      <div className="navbar-start">
        <button
          ref={logoRef}
          className="btn btn-ghost text-xl gap-2 hover:bg-primary/20"
          onClick={() => onNavigate('dashboard')}
        >
          <span className="text-2xl">🚀</span>
          <span className="font-bold bg-gradient-to-r from-primary to-secondary bg-clip-text text-transparent">
            PatchPilot
          </span>
        </button>
      </div>

      <div className="navbar-center">
        <div className="tabs tabs-boxed bg-base-300/50">
          <button
            className={`tab tab-lg transition-all duration-300 ${
              currentView === 'dashboard'
                ? 'tab-active bg-primary text-primary-content'
                : 'hover:bg-base-content/10'
            }`}
            onClick={() => onNavigate('dashboard')}
          >
            <span className="mr-2">📊</span>
            Dashboard
          </button>
          <button
            className={`tab tab-lg transition-all duration-300 ${
              currentView === 'compare'
                ? 'tab-active bg-primary text-primary-content'
                : 'hover:bg-base-content/10'
            }`}
            onClick={() => onNavigate('compare')}
          >
            <span className="mr-2">⚖️</span>
            Compare
          </button>
        </div>
      </div>

      <div className="navbar-end">
        <div className="flex items-center gap-2 px-4 py-2 rounded-full bg-base-300/50">
          <div className={`w-2 h-2 rounded-full ${statusColor} ${apiStatus === 'checking' ? 'animate-pulse' : ''}`} />
          <span className="text-sm text-base-content/70">{statusText}</span>
        </div>
      </div>
    </div>
  );
}

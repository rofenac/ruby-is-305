import { useState, useRef } from 'react';
import { useGSAP } from '@gsap/react';
import gsap from 'gsap';
import { setCredentials, clearCredentials, verifyAuth } from '../api/client';

interface LoginPageProps {
  onLogin: () => void;
}

export function LoginPage({ onLogin }: LoginPageProps) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const cardRef = useRef<HTMLDivElement>(null);

  useGSAP(() => {
    if (cardRef.current) {
      gsap.from(cardRef.current, {
        y: 40,
        opacity: 0,
        duration: 0.6,
        ease: 'power3.out',
      });
    }
  }, { scope: cardRef });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    setCredentials(username, password);
    const ok = await verifyAuth();
    if (ok) {
      onLogin();
    } else {
      clearCredentials();
      setError('Invalid username or password.');
    }
    setLoading(false);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-base-300 via-base-300 to-base-200 flex items-center justify-center">
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-40 -right-40 w-80 h-80 bg-primary/10 rounded-full blur-3xl" />
        <div className="absolute -bottom-40 -left-40 w-80 h-80 bg-secondary/10 rounded-full blur-3xl" />
      </div>

      <div ref={cardRef} className="relative z-10 card bg-base-200 shadow-2xl w-full max-w-sm mx-4">
        <div className="card-body gap-4">
          <div className="flex flex-col items-center gap-2 mb-2">
            <span className="text-5xl">🚀</span>
            <h1 className="text-2xl font-bold bg-gradient-to-r from-primary to-secondary bg-clip-text text-transparent">
              PatchPilot
            </h1>
            <p className="text-sm text-base-content/60">Sign in to continue</p>
          </div>

          <form onSubmit={handleSubmit} className="flex flex-col gap-3">
            <label className="form-control">
              <div className="label pb-1">
                <span className="label-text font-medium">Username</span>
              </div>
              <input
                type="text"
                className="input input-bordered w-full"
                value={username}
                onChange={e => setUsername(e.target.value)}
                autoComplete="username"
                autoFocus
                required
              />
            </label>

            <label className="form-control">
              <div className="label pb-1">
                <span className="label-text font-medium">Password</span>
              </div>
              <input
                type="password"
                className="input input-bordered w-full"
                value={password}
                onChange={e => setPassword(e.target.value)}
                autoComplete="current-password"
                required
              />
            </label>

            {error && (
              <div className="alert alert-error py-2 text-sm">
                <span>{error}</span>
              </div>
            )}

            <button
              type="submit"
              className="btn btn-primary mt-1"
              disabled={loading}
            >
              {loading ? <span className="loading loading-spinner loading-sm" /> : null}
              {loading ? 'Signing in…' : 'Sign In'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}

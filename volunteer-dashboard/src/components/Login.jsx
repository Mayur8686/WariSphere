import React, { useState } from 'react';
import { Lock, Eye, EyeOff, Loader2, AlertCircle, User } from 'lucide-react';
import { loginWithPassword } from '../lib/session';

const TempleLogo = () => (
  <svg viewBox="0 0 24 24" fill="currentColor" className="w-10 h-10 text-white">
    <path d="M10 4h4v3h-4z" />
    <path d="M8 7h8v3H8z" />
    <path d="M4 10h16v8h-6v-3a2 2 0 0 0-4 0v3H4v-8z" />
  </svg>
);

export default function Login({ onLogin }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const submit = async (e) => {
    e.preventDefault();
    setBusy(true);
    setError('');
    try {
      const session = await loginWithPassword(email, password, 'volunteer');
      onLogin(session);
    } catch (err) {
      setError(err.message || 'Sign-in failed.');
    } finally {
      setBusy(false);
    }
  };

  const fillDemo = () => {
    setEmail('rahul.patil@warisphere.dev');
    setPassword('Volunteer@123');
    setError('');
  };

  return (
    <div className="min-h-screen bg-orange-50 flex flex-col justify-center items-center p-6 font-sans text-gray-800">
      <div className="w-full max-w-xl flex flex-col items-center">

        <div className="w-20 h-20 bg-orange-500 rounded-full flex items-center justify-center shadow-lg shadow-orange-300/50 mb-4">
          <TempleLogo />
        </div>

        <h1 className="text-3xl font-bold text-[#3d2514] tracking-tight">WariSphere</h1>
        <p className="text-sm text-[#8b3a2b] font-medium mt-0.5 mb-8">वारकरांचा सोबती</p>

        <div className="w-full text-left mb-6">
          <h2 className="text-2xl font-bold text-[#3d2514]">Volunteer Portal</h2>
          <p className="text-sm text-gray-500 mt-0.5">
            Sign in with the credentials your control room gave you
          </p>
        </div>

        <form onSubmit={submit} className="w-full space-y-5">
          <div>
            <label className="block text-xs font-bold uppercase tracking-wider text-gray-600 mb-2">Volunteer Email</label>
            <div className="relative">
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@warisphere.in"
                className="w-full px-4 py-3.5 rounded-xl bg-white border border-orange-200/60 focus:border-orange-500 focus:ring-2 focus:ring-orange-200 outline-none transition-all pl-10 shadow-sm"
                required
                autoComplete="username"
              />
              <User size={18} className="absolute left-3.5 top-4 text-gray-400" />
            </div>
          </div>

          <div>
            <label className="block text-xs font-bold uppercase tracking-wider text-gray-600 mb-2">Password</label>
            <div className="relative">
              <input
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className="w-full px-4 py-3.5 rounded-xl bg-white border border-orange-200/60 focus:border-orange-500 focus:ring-2 focus:ring-orange-200 outline-none transition-all pl-10 pr-10 shadow-sm"
                required
                autoComplete="current-password"
              />
              <Lock size={18} className="absolute left-3.5 top-4 text-gray-400" />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3.5 top-4 text-gray-400 hover:text-gray-600 cursor-pointer"
              >
                {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>
          </div>

          {error && (
            <p className="text-xs font-semibold text-red-600 flex items-start gap-1.5">
              <AlertCircle size={14} className="shrink-0 mt-0.5" /> {error}
            </p>
          )}

          <button
            type="submit"
            disabled={busy}
            className="w-full bg-orange-500 hover:bg-orange-600 text-white font-bold py-4 rounded-xl transition-all shadow-lg shadow-orange-300/50 mt-4 text-base cursor-pointer disabled:opacity-60 flex items-center justify-center gap-2"
          >
            {busy && <Loader2 size={18} className="animate-spin" />}
            Sign in
          </button>
        </form>

        <div className="w-full mt-8 bg-white border border-orange-200/60 rounded-2xl p-4 shadow-sm flex items-start gap-3">
          <span className="text-orange-500 font-bold text-lg">ℹ️</span>
          <div className="flex-1">
            <p className="text-xs font-bold text-gray-800">Demo mode</p>
            <p className="text-xs text-gray-500 mt-0.5">
              After seeding (<code className="bg-orange-50 px-1 rounded">python scripts/seed_demo_volunteers.py</code>),
              sign in as <b>rahul.patil@warisphere.dev</b> / <b>Volunteer@123</b>.
            </p>
            <button
              type="button"
              onClick={fillDemo}
              className="mt-2 text-xs font-bold text-orange-600 hover:text-orange-700 cursor-pointer underline underline-offset-2"
            >
              Autofill demo volunteer
            </button>
          </div>
        </div>

      </div>
    </div>
  );
}

import React, { useState } from 'react';
import { Lock, Eye, EyeOff } from 'lucide-react';

const TempleLogo = () => (
  <svg viewBox="0 0 24 24" fill="currentColor" className="w-10 h-10 text-white">
    <path d="M10 4h4v3h-4z" />
    <path d="M8 7h8v3H8z" />
    <path d="M4 10h16v8h-6v-3a2 2 0 0 0-4 0v3H4v-8z" />
  </svg>
);

export default function Login({ onLogin }) {
  const [showPassword, setShowPassword] = useState(false);

  return (
    <div className="min-h-screen bg-orange-50 flex flex-col justify-center items-center p-6 font-sans text-gray-800">
      <div className="w-full max-w-xl flex flex-col items-center">
        
        <div className="w-20 h-20 bg-orange-500 rounded-full flex items-center justify-center shadow-lg shadow-orange-300/50 mb-4">
          <TempleLogo />
        </div>

        <h1 className="text-3xl font-bold text-[#3d2514] tracking-tight">WariSphere</h1>
        <p className="text-sm text-[#8b3a2b] font-medium mt-0.5 mb-8">वारकरांचा सोबती</p>

        <div className="w-full text-left mb-6">
          <h2 className="text-2xl font-bold text-[#3d2514]">Authority Portal</h2>
          <p className="text-sm text-gray-500 mt-0.5">Control room sign in</p>
        </div>

        <form onSubmit={(e) => { e.preventDefault(); onLogin(); }} className="w-full space-y-5">
          <div>
            <label className="block text-xs font-bold uppercase tracking-wider text-gray-600 mb-2">Authority ID / Email</label>
            <input 
              type="text" 
              placeholder="Enter authority ID"
              className="w-full px-4 py-3.5 rounded-xl bg-white border border-orange-200/60 focus:border-orange-500 focus:ring-2 focus:ring-orange-200 outline-none transition-all shadow-sm"
              required
            />
          </div>
          
          <div>
            <label className="block text-xs font-bold uppercase tracking-wider text-gray-600 mb-2">Password</label>
            <div className="relative">
              <input 
                type={showPassword ? "text" : "password"} 
                placeholder="••••••••"
                className="w-full px-4 py-3.5 rounded-xl bg-white border border-orange-200/60 focus:border-orange-500 focus:ring-2 focus:ring-orange-200 outline-none transition-all pl-10 pr-10 shadow-sm"
                required
              />
              <Lock size={18} className="absolute left-3.5 top-4 text-gray-400" />
              <button 
                type="button" 
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3.5 top-4 text-gray-400 hover:text-gray-600"
              >
                {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>
          </div>

          <button 
            type="submit" 
            className="w-full bg-orange-500 hover:bg-orange-600 text-white font-bold py-4 rounded-xl transition-all shadow-lg shadow-orange-300/50 mt-4 text-base"
          >
            Sign in
          </button>
        </form>

        <div className="w-full mt-8 bg-white border border-orange-200/60 rounded-2xl p-4 shadow-sm flex items-start gap-3">
          <span className="text-orange-500 font-bold text-lg">ℹ️</span>
          <div>
            <p className="text-xs font-bold text-gray-800">Demo mode</p>
            <p className="text-xs text-gray-500 mt-0.5">Click sign in with any credentials to access the command center control room.</p>
          </div>
        </div>

      </div>
    </div>
  );
}
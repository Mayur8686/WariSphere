import React, { useEffect, useState } from 'react';
import Login from './components/Login';
import Dashboard from './components/Dashboard';
import { getSessionMeta, logout, restoreSession } from './lib/session';

export default function App() {
  // 'restoring' while the Firebase SDK rehydrates a previous session
  const [session, setSession] = useState(null);
  const [restoring, setRestoring] = useState(true);

  useEffect(() => {
    let mounted = true;
    restoreSession().then((meta) => {
      if (!mounted) return;
      setSession(meta);
      setRestoring(false);
    });

    // any API call that comes back 401 bounces the portal to login
    const onUnauthorized = () => {
      logout().then(() => setSession(null));
    };
    window.addEventListener('warisphere:unauthorized', onUnauthorized);
    return () => {
      mounted = false;
      window.removeEventListener('warisphere:unauthorized', onUnauthorized);
    };
  }, []);

  if (restoring) {
    return (
      <div className="min-h-screen bg-orange-50 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-orange-600"></div>
      </div>
    );
  }

  if (!session) {
    return <Login onLogin={(meta) => setSession(meta)} />;
  }

  // Hard portal boundary: this dashboard is for authority accounts only.
  if (session.role !== 'authority') {
    return <WrongPortal role={session.role} onSwitch={() => logout().then(() => setSession(null))} />;
  }

  return (
    <Dashboard
      session={session || getSessionMeta()}
      onLogout={() => logout().then(() => setSession(null))}
    />
  );
}

function WrongPortal({ role, onSwitch }) {
  return (
    <div className="min-h-screen bg-orange-50 flex flex-col justify-center items-center p-6 text-center">
      <h2 className="text-2xl font-bold text-[#3d2514]">Wrong portal</h2>
      <p className="text-sm text-gray-500 mt-2 max-w-sm">
        This account has the <b className="capitalize">{role}</b> role.
        Please sign in through the {role === 'volunteer' ? 'Volunteer Portal' : 'correct portal'} instead.
      </p>
      <button
        onClick={onSwitch}
        className="mt-6 bg-orange-500 hover:bg-orange-600 text-white font-bold px-6 py-3 rounded-xl cursor-pointer shadow-lg shadow-orange-300/50"
      >
        Switch account
      </button>
    </div>
  );
}

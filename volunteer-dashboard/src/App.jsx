import React, { useEffect, useState } from 'react';
import Login from './components/Login';
import Portal from './components/Portal';
import { logout, restoreSession } from './lib/session';

export default function App() {
  const [session, setSession] = useState(null);
  const [restoring, setRestoring] = useState(true);

  useEffect(() => {
    let mounted = true;
    restoreSession().then((meta) => {
      if (!mounted) return;
      setSession(meta);
      setRestoring(false);
    });

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

  // Volunteer Portal is strictly for volunteer accounts; authorities are
  // routed back (the backend independently rejects cross-role calls).
  if (session.role !== 'volunteer') {
    return (
      <div className="min-h-screen bg-orange-50 flex flex-col justify-center items-center p-6 text-center">
        <h2 className="text-2xl font-bold text-[#3d2514]">Wrong portal</h2>
        <p className="text-sm text-gray-500 mt-2 max-w-sm">
          This account has the <b className="capitalize">{session.role}</b> role.
          Please sign in through the {session.role === 'authority' ? 'Authority Dashboard' : 'correct portal'} instead.
        </p>
        <button
          onClick={() => logout().then(() => setSession(null))}
          className="mt-6 bg-orange-500 hover:bg-orange-600 text-white font-bold px-6 py-3 rounded-xl cursor-pointer shadow-lg shadow-orange-300/50"
        >
          Switch account
        </button>
      </div>
    );
  }

  return <Portal session={session} onLogout={() => logout().then(() => setSession(null))} />;
}

// Session handling for the WariSphere web portals.
//
// ONE authentication mechanism: Firebase Authentication (email/password).
// After Firebase sign-in the authoritative role is read from the backend
// (GET /auth/me → users/{uid}), which the backend enforces on every call.
//
// Dev mode (backend running without a service-account key): the same form
// falls back to POST /auth/dev-session, which only exists in that mode.
// No second auth system is ever active in production.
//
// Firebase ID tokens are fetched fresh per request (auth.currentUser), so
// only lightweight session metadata is persisted across page reloads.

import {
  getAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import { app } from '../firebase';

const KEY = 'warisphere.session';

export const auth = getAuth(app);

const API_BASE =
  (typeof import.meta !== 'undefined' && import.meta?.env?.VITE_API_BASE) || '';

// ---------------------------------------------------------------------------
// persisted session META (never the firebase token itself)
// ---------------------------------------------------------------------------

export function getSessionMeta() {
  try {
    const raw = localStorage.getItem(KEY);
    return raw ? JSON.parse(raw) : null;
  } catch (_) {
    return null;
  }
}

function saveSessionMeta(meta) {
  localStorage.setItem(KEY, JSON.stringify(meta));
}

export function clearSession() {
  localStorage.removeItem(KEY);
}

// ---------------------------------------------------------------------------
// bearer token plumbing for lib/api.js
// ---------------------------------------------------------------------------

let devToken = null; // dev-mode tokens are long-lived backend strings

export async function getBearerToken() {
  const meta = getSessionMeta();
  if (!meta) return null;
  if (meta.mode === 'dev') return devToken || meta.token || null;
  try {
    const user = auth.currentUser;
    return user ? await user.getIdToken() : null;
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------------------
// login / logout
// ---------------------------------------------------------------------------

async function fetchMe(token) {
  const res = await fetch(`${API_BASE}/auth/me`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) {
    let detail = 'Sign-in verification failed.';
    try {
      const body = await res.json();
      detail = body?.detail || detail;
    } catch (_) { /* keep default */ }
    const err = new Error(detail);
    err.status = res.status;
    throw err;
  }
  return res.json();
}

async function tryDevSession(email, password, expectedRole) {
  const res = await fetch(`${API_BASE}/auth/dev-session`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new Error(body?.detail || 'Invalid email or password.');
    err.status = res.status;
    throw err;
  }
  if (expectedRole && body.role !== expectedRole) {
    const err = new Error(
      `This account has the "${body.role}" role — please use the ${body.role} portal.`,
    );
    err.status = 403;
    throw err;
  }
  return body;
}

/**
 * Sign in and enforce the portal's role. Returns the session meta.
 *   expectedRole: 'authority' | 'volunteer'
 */
export async function loginWithPassword(email, password, expectedRole) {
  const normalizedEmail = (email || '').trim();
  let firebaseError = null;

  // 1) Primary path: Firebase Authentication.
  try {
    const cred = await signInWithEmailAndPassword(auth, normalizedEmail, password);
    const token = await cred.user.getIdToken();
    const me = await fetchMe(token);
    if (expectedRole && me.role !== expectedRole) {
      await signOut(auth);
      throw new Error(
        `This account has the "${me.role}" role — please use the ${me.role} portal.`,
      );
    }
    const meta = {
      mode: 'firebase',
      uid: me.uid,
      name: me.name,
      email: me.email || normalizedEmail,
      role: me.role,
    };
    saveSessionMeta(meta);
    return meta;
  } catch (err) {
    firebaseError = err;
  }

  // 2) Repo dev mode: only reachable when the backend has no Firebase key
  //    (the endpoint returns 403 "disabled" as soon as one is configured).
  try {
    const dev = await tryDevSession(normalizedEmail, password, expectedRole);
    devToken = dev.token;
    const meta = {
      mode: 'dev',
      token: dev.token,
      uid: dev.uid,
      name: dev.name,
      email: dev.email,
      role: dev.role,
    };
    saveSessionMeta(meta);
    return meta;
  } catch (devErr) {
    if (devErr.status === 401) {
      throw new Error('Invalid email or password.');
    }
    // dev auth disabled / unreachable → surface the Firebase-side reason
    throw mapFirebaseError(firebaseError);
  }
}

function mapFirebaseError(err) {
  const code = err?.code || '';
  const table = {
    'auth/invalid-credential': 'Invalid email or password.',
    'auth/user-not-found': 'No account found for this email.',
    'auth/wrong-password': 'Invalid email or password.',
    'auth/too-many-requests': 'Too many attempts — please wait and retry.',
    'auth/network-request-failed': 'Network error reaching Firebase Auth.',
    'auth/invalid-email': 'Please enter a valid email address.',
  };
  if (table[code]) return new Error(table[code]);
  return err instanceof Error ? err : new Error('Sign-in failed.');
}

export async function logout() {
  clearSession();
  devToken = null;
  try {
    await signOut(auth);
  } catch (_) { /* already signed out */ }
}

// ---------------------------------------------------------------------------
// session restore across reloads
// ---------------------------------------------------------------------------

/**
 * Resolve the persisted meta to a still-valid session.
 * Firebase mode waits for the SDK to restore the user; dev mode trusts the
 * stored backend token. Returns null when there is no usable session.
 */
export function restoreSession() {
  const meta = getSessionMeta();
  if (!meta) return Promise.resolve(null);
  if (meta.mode === 'dev') {
    devToken = meta.token;
    return Promise.resolve(meta);
  }
  return new Promise((resolve) => {
    const unsub = onAuthStateChanged(auth, async (user) => {
      unsub();
      if (!user) {
        clearSession();
        return resolve(null);
      }
      try {
        await user.getIdToken();
        resolve(meta);
      } catch (_) {
        clearSession();
        resolve(null);
      }
    });
  });
}

// Session handling for the WariSphere Volunteer Portal.
// Identical authentication mechanism to the Authority Dashboard:
// Firebase Authentication (email/password) + backend role check via
// GET /auth/me. Dev mode falls back to POST /auth/dev-session, which the
// backend disables automatically once a Firebase service-account key is
// configured.

import {
  getAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import { app } from '../firebase';

const KEY = 'warisphere.volunteer.session';

export const auth = getAuth(app);

const API_BASE =
  (typeof import.meta !== 'undefined' && import.meta?.env?.VITE_API_BASE) || '';

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

let devToken = null;

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

export async function loginWithPassword(email, password, expectedRole = 'volunteer') {
  const normalizedEmail = (email || '').trim();
  let firebaseError = null;

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

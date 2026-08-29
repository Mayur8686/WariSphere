// WariSphere Volunteer Portal API helpers — same backend, same conventions
// as the Authority Dashboard client. Every request carries the caller's
// bearer token; the backend re-checks role + ownership on each call.

import { getBearerToken } from './session';

export const API_BASE =
  (typeof import.meta !== 'undefined' &&
    import.meta?.env?.VITE_API_BASE) ||
  '';

// Photos uploaded in dev mode are served by the backend at /uploads/...
export function resolvePhotoUrl(url) {
  if (!url) return null;
  if (/^https?:\/\//i.test(url)) return url;
  return `${API_BASE}${url.startsWith('/') ? '' : '/'}${url}`;
}

function detailFromBody(body) {
  if (!body) return '';
  const detail = body.detail ?? body.message ?? '';
  if (Array.isArray(detail)) {
    return detail.map((d) => d.msg || JSON.stringify(d)).join('; ');
  }
  if (detail && typeof detail === 'object') {
    return detail.msg || JSON.stringify(detail);
  }
  return typeof detail === 'string' ? detail : '';
}

async function request(path, options = {}) {
  const headers = { ...(options.headers || {}) };
  const token = await getBearerToken();
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${API_BASE}${path}`, { ...options, headers });
  if (res.status === 401) {
    window.dispatchEvent(new CustomEvent('warisphere:unauthorized'));
  }
  if (!res.ok) {
    let detail = '';
    try {
      detail = detailFromBody(await res.json());
    } catch (_) { /* non-JSON error body */ }
    const err = new Error(detail || `Backend responded ${res.status} for ${path}`);
    err.status = res.status;
    throw err;
  }
  return res.json();
}

// ---- profile ---------------------------------------------------------------

export async function getMyVolunteerProfile() {
  return request('/volunteers/me');
}

export async function updateMyProfile(changes) {
  const me = await getMyVolunteerProfile();
  return request(`/volunteers/${me.uid}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(changes),
  });
}

export async function setMyAvailability(availability) {
  return request('/volunteers/me/availability', {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ availability }),
  });
}

// ---- tasks ------------------------------------------------------------------

export async function listMyTasks(view = 'active') {
  const data = await request(`/tasks/my?view=${view}`);
  const tasks = data.tasks ?? [];
  return { tasks, count: data.count ?? tasks.length };
}

// action: accept | start | reject | unable-to-complete
export async function taskAction(taskId, action, note = null) {
  return request(`/tasks/${taskId}/${action}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(note ? { note } : {}),
  });
}

export async function completeTask(taskId, note) {
  return request(`/tasks/${taskId}/complete`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ note: note || null }),
  });
}

// ---- formatting helpers -----------------------------------------------------

export function timeAgo(iso) {
  if (!iso) return '—';
  const then = new Date(iso).getTime();
  if (Number.isNaN(then)) return '—';
  const seconds = Math.max(1, Math.floor((Date.now() - then) / 1000));
  const units = [
    ['year', 31536000],
    ['month', 2592000],
    ['week', 604800],
    ['day', 86400],
    ['hour', 3600],
    ['min', 60],
  ];
  for (const [label, size] of units) {
    const value = Math.floor(seconds / size);
    if (value >= 1) return `${value} ${label}${value > 1 ? 's' : ''} ago`;
  }
  return `${seconds} secs ago`;
}

export function fmtTime(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleString(undefined, {
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function durationLabel(seconds) {
  if (seconds == null || Number.isNaN(Number(seconds))) return '—';
  const total = Math.max(0, Math.round(Number(seconds)));
  if (total < 60) return `${total} secs`;
  const minutes = Math.floor(total / 60);
  if (minutes < 60) return minutes === 1 ? '1 min' : `${minutes} mins`;
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  return rest ? `${hours} hr ${rest} mins` : `${hours} hr`;
}

export function taskTypeLabel(type) {
  const map = {
    sos: 'SOS Response',
    lost_person: 'Lost Person Assistance',
    medical_assistance: 'Medical Assistance',
    crowd_assistance: 'Crowd Assistance',
    route_assistance: 'Route Assistance',
    general: 'General Duty',
  };
  return map[type] || 'Task';
}

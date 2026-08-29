// WariSphere backend API helpers for the control-room dashboard.
//
// Configure the API base with an env variable (Vite or CRA):
//   VITE_API_BASE=http://192.168.1.23:8000     (Vite)
//   REACT_APP_API_BASE=http://192.168.1.23:8000 (Create React App)
// Defaults to same-origin (empty string) so the Vite dev-server proxy
// can forward /lost-person and /uploads to FastAPI. Override with
// VITE_API_BASE when the dashboard and API are hosted separately.

import { getBearerToken } from './session';

export const API_BASE =
  (typeof import.meta !== 'undefined' &&
    import.meta?.env?.VITE_API_BASE) ||
  (typeof process !== 'undefined' &&
    process?.env?.REACT_APP_API_BASE) ||
  '';

const AUTHORITY_TOKEN =
  (typeof import.meta !== 'undefined' &&
    import.meta?.env?.VITE_AUTHORITY_TOKEN) ||
  (typeof process !== 'undefined' &&
    process?.env?.REACT_APP_AUTHORITY_TOKEN) ||
  '';

// In production photos live on Firebase Storage (absolute https URL).
// In dev mode the backend serves them from /uploads/... (relative URL) —
// prefix those with the API base so <img src> works on the dashboard.
export function resolvePhotoUrl(url) {
  if (!url) return null;
  if (/^https?:\/\//i.test(url)) return url;
  const base = API_BASE || '';
  return `${base}${url.startsWith('/') ? '' : '/'}${url}`;
}

function authorityHeaders(headers) {
  const next = { ...(headers || {}) };
  if (AUTHORITY_TOKEN) next['X-Authority-Token'] = AUTHORITY_TOKEN;
  return next;
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
  const headers = authorityHeaders(options.headers);
  const token = await getBearerToken();
  if (token) headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(`${API_BASE}${path}`, { ...options, headers });
  if (res.status === 401) {
    // Session died (expired/revoked) — tell the app to bounce to login.
    window.dispatchEvent(new CustomEvent('warisphere:unauthorized'));
  }
  if (!res.ok) {
    let detail = '';
    try {
      detail = detailFromBody(await res.json());
    } catch (_) {
      /* non-JSON error body */
    }
    const err = new Error(
      detail || `Backend responded ${res.status} for ${path}`,
    );
    err.status = res.status;
    throw err;
  }
  return res.json();
}

// List lost/found person reports. filters: { reportType, status, limit }.
// Examples:
//   listReports({ reportType: 'found' })  -> Recent Found Persons
//   listReports({})                       -> everything (search)
export async function listReports({
  reportType = null,
  status = null,
  limit = 200,
} = {}) {
  const params = new URLSearchParams();
  if (reportType) params.set('report_type', reportType);
  if (status) params.set('status', status);
  params.set('limit', String(limit));
  const data = await request(`/lost-person?${params.toString()}`);
  return data.reports ?? [];
}

// Upload a photo (File) to the backend — same endpoint the Flutter app uses.
// Returns { photo_url, stored_in }. client_report_id keeps uploads idempotent.
export async function uploadPersonPhoto(file, clientReportId) {
  const form = new FormData();
  form.append('file', file);
  if (clientReportId) form.append('client_report_id', clientReportId);
  return request('/lost-person/photo', { method: 'POST', body: form });
}

// Create a lost/found report (JSON). Used after a photo upload to log the
// found person from the control-room dashboard.
export async function createPersonReport(report) {
  return request('/lost-person', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(report),
  });
}

export async function updatePersonStatus(lostPersonId, status) {
  return request(`/lost-person/${lostPersonId}/status`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ status }),
  });
}

// AI-assisted scan: upload a FOUND-person photo, receive ranked probable
// matches. Does not confirm identity.
export async function scanFaceMatch(file, { reporterName, clientReportId } = {}) {
  const form = new FormData();
  form.append('file', file);
  form.append('reporter_name', reporterName || 'Control Room');
  if (clientReportId) form.append('client_report_id', clientReportId);
  return request('/lost-person/scan-match', { method: 'POST', body: form });
}

export async function confirmFaceMatch(matchId, verifiedBy = 'control-room') {
  return request(`/lost-person/matches/${matchId}/confirm`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ verified_by: verifiedBy }),
  });
}

export async function rejectFaceMatch(matchId, verifiedBy = 'control-room') {
  return request(`/lost-person/matches/${matchId}/reject`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ verified_by: verifiedBy }),
  });
}

export async function faceMatchStatus() {
  return request('/lost-person/face-match/status');
}

// ---------------------------------------------------------------------------
// SOS alerts (REST fallback / actions — the live view subscribes directly)
// ---------------------------------------------------------------------------

export async function listSosAlerts({ status = null, limit = 500 } = {}) {
  const params = new URLSearchParams({ limit: String(limit) });
  if (status) params.set('status', status);
  const data = await request(`/sos?${params.toString()}`);
  const alerts = data.alerts ?? [];
  return { alerts, count: data.count ?? alerts.length };
}

export async function updateSosStatus(sosId, status) {
  return request(`/sos/${sosId}/status`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ status }),
  });
}

// ---------------------------------------------------------------------------
// Volunteers (authority) + own profile (volunteer)
// ---------------------------------------------------------------------------

export async function listVolunteers({ status = null, availability = null } = {}) {
  const params = new URLSearchParams();
  if (status) params.set('status', status);
  if (availability) params.set('availability', availability);
  const qs = params.toString();
  const data = await request(`/volunteers${qs ? `?${qs}` : ''}`);
  return {
    volunteers: data.volunteers ?? [],
    summary: data.summary ?? null,
    count: data.count ?? (data.volunteers?.length || 0),
  };
}

export async function createVolunteer(payload) {
  return request('/volunteers', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
}

export async function getVolunteer(volunteerId) {
  return request(`/volunteers/${volunteerId}`);
}

export async function getMyVolunteerProfile() {
  return request('/volunteers/me');
}

export async function updateVolunteer(volunteerId, changes) {
  return request(`/volunteers/${volunteerId}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(changes),
  });
}

export async function setVolunteerStatus(volunteerId, status) {
  return request(`/volunteers/${volunteerId}/status`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ status }),
  });
}

export async function setVolunteerAvailability(volunteerId, availability) {
  return request(`/volunteers/${volunteerId}/availability`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ availability }),
  });
}

export async function setMyAvailability(availability) {
  return request('/volunteers/me/availability', {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ availability }),
  });
}

// ---------------------------------------------------------------------------
// Tasks
// ---------------------------------------------------------------------------

export async function createTask(payload) {
  return request('/tasks', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
}

export async function listTasks({
  view = 'all',
  assignedTo = null,
  sourceKind = null,
  sourceId = null,
  status = null,
  limit = 200,
} = {}) {
  const params = new URLSearchParams({ view, limit: String(limit) });
  if (assignedTo) params.set('assigned_to', assignedTo);
  if (sourceKind) params.set('source_kind', sourceKind);
  if (sourceId) params.set('source_id', sourceId);
  if (status) params.set('status', status);
  const data = await request(`/tasks?${params.toString()}`);
  const tasks = data.tasks ?? [];
  return { tasks, count: data.count ?? tasks.length };
}

export async function listMyTasks(view = 'active') {
  const data = await request(`/tasks/my?view=${view}`);
  const tasks = data.tasks ?? [];
  return { tasks, count: data.count ?? tasks.length };
}

export async function getTask(taskId) {
  return request(`/tasks/${taskId}`);
}

// action: accept | start | reject | unable-to-complete (complete → completeTask)
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

export async function assignTask(taskId, volunteerId) {
  return request(`/tasks/${taskId}/assign`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ volunteer_id: volunteerId }),
  });
}

export async function cancelTask(taskId, note = null) {
  return request(`/tasks/${taskId}/cancel`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(note ? { note } : {}),
  });
}

// "12 mins" / "1 hr 5 mins" from a seconds count (SOS response time).
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

// "10 mins ago" / "1 hour ago" from an ISO-8601 timestamp.
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

// "8 hours" (no "ago") — used on the AI match card.
export function missingFor(iso) {
  if (!iso) return 'unknown';
  const then = new Date(iso).getTime();
  if (Number.isNaN(then)) return 'unknown';
  const seconds = Math.max(0, Math.floor((Date.now() - then) / 1000));
  if (seconds < 60) return `${seconds} seconds`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return minutes === 1 ? '1 min' : `${minutes} mins`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return hours === 1 ? '1 hour' : `${hours} hours`;
  const days = Math.floor(hours / 24);
  return days === 1 ? '1 day' : `${days} days`;
}

// Initials for the fallback avatar (matches the CH/EL tiles in the design).
export function initials(name) {
  const words = (name || '')
    .trim()
    .split(/\s+/)
    .filter(Boolean);
  if (words.length === 0) return '?';
  const first = words[0][0];
  const last = words.length > 1 ? words[words.length - 1][0] : '';
  return `${first}${last}`.toUpperCase();
}

// Active found cases = found reports not yet reunited.
export function activeCases(reports) {
  return reports.filter((r) => r.report_type === 'found' && r.status !== 'reunited');
}

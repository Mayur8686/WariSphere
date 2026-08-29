// WariSphere backend API helpers for the control-room dashboard.
//
// Configure the API base with an env variable (Vite or CRA):
//   VITE_API_BASE=http://192.168.1.23:8000     (Vite)
//   REACT_APP_API_BASE=http://192.168.1.23:8000 (Create React App)
// Defaults to http://localhost:8000 for local development.

export const API_BASE =
  (typeof import.meta !== 'undefined' &&
    import.meta?.env?.VITE_API_BASE) ||
  (typeof process !== 'undefined' &&
    process?.env?.REACT_APP_API_BASE) ||
  'http://localhost:8000';

// In production photos live on Firebase Storage (absolute https URL).
// In dev mode the backend serves them from /uploads/... (relative URL) —
// prefix those with the API base so <img src> works on the dashboard.
export function resolvePhotoUrl(url) {
  if (!url) return null;
  if (/^https?:\/\//i.test(url)) return url;
  return `${API_BASE}${url.startsWith('/') ? '' : '/'}${url}`;
}

async function request(path, options) {
  const res = await fetch(`${API_BASE}${path}`, options);
  if (!res.ok) {
    let detail = '';
    try {
      detail = (await res.json())?.detail ?? '';
    } catch (_) {
      /* non-JSON error body */
    }
    throw new Error(
      `Backend responded ${res.status}${detail ? `: ${detail}` : ''} for ${path}`
    );
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
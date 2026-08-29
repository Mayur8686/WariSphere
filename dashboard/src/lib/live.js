// Real-time data for the dashboards.
//
// Preferred path: Firebase client `onSnapshot` (the way the existing
// Authority Dashboard already reads `sos_alerts`) — zero polling.
//
// Fallback path: the backend REST API, polled gently. Used automatically
// when the backend is running in the repo's no-Firebase dev mode (the
// collections simply don't exist in the cloud then) or when a Firestore
// listener errors out (rules/network). The component API is identical
// either way, and Firestore `Timestamp` objects are normalised to ISO
// strings so both channels produce the same shape.

import { useCallback, useEffect, useRef, useState } from 'react';
import { collection, onSnapshot, query, where } from 'firebase/firestore';
import { db } from '../firebase';
import { getSessionMeta } from './session';

const DEFAULT_POLL_MS = 6000;

function normalize(value) {
  if (value == null) return value;
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(normalize);
  if (typeof value === 'object') {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = normalize(v);
    return out;
  }
  return value;
}

function snapshotDocs(snap) {
  return snap.docs.map((doc) => normalize({ id: doc.id, ...doc.data() }));
}

/**
 * useLiveCollection(name, restFetcher, options)
 *
 *   name        Firestore collection ('sos_alerts', 'volunteers', 'tasks')
 *   restFetcher async () => array  (REST fallback; also the dev-mode source)
 *   options     { pollMs, where: [field, '==', value] | null, enabled }
 *
 * Returns { data, loading, error, refresh, source } where
 * source ∈ 'firestore' | 'rest'.
 */
export function useLiveCollection(name, restFetcher, options = {}) {
  const { pollMs = DEFAULT_POLL_MS, where: filter = null, enabled = true } = options;
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [source, setSource] = useState('rest');
  const fetcherRef = useRef(restFetcher);
  fetcherRef.current = restFetcher;

  const refresh = useCallback(async () => {
    try {
      const rows = await fetcherRef.current();
      setData(Array.isArray(rows) ? rows : []);
      setError('');
      return rows;
    } catch (e) {
      setError(e.message || 'Could not load data.');
      return [];
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!enabled) return undefined;
    let cancelled = false;
    let unsub = null;
    let timer = null;
    setLoading(true);

    const startPolling = () => {
      setSource('rest');
      const tick = async () => {
        if (cancelled) return;
        await refresh();
        if (!cancelled) timer = setTimeout(tick, pollMs);
      };
      tick();
    };

    const mode = getSessionMeta()?.mode;
    if (mode === 'firebase') {
      try {
        const colRef = collection(db, name);
        const q = filter ? query(colRef, where(filter[0], filter[1], filter[2])) : colRef;
        unsub = onSnapshot(
          q,
          (snap) => {
            if (cancelled) return;
            setSource('firestore');
            setData(snapshotDocs(snap));
            setLoading(false);
            setError('');
          },
          (err) => {
            console.warn(`[live] ${name} listener failed, falling back to REST polling:`, err?.code || err);
            if (cancelled) return;
            try { unsub && unsub(); } catch (_) { /* noop */ }
            unsub = null;
            startPolling();
          },
        );
      } catch (e) {
        console.warn(`[live] ${name} listener unavailable:`, e);
        startPolling();
      }
    } else {
      startPolling();
    }

    return () => {
      cancelled = true;
      if (timer) clearTimeout(timer);
      if (unsub) { try { unsub(); } catch (_) { /* noop */ } }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [name, enabled, pollMs, filter ? filter.join('|') : '']);

  return { data, loading, error, refresh, source };
}

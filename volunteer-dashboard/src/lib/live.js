// Real-time task updates for the volunteer.
//
// Preferred: Firestore onSnapshot on the tasks assigned to this volunteer
// (same mechanism the Authority Dashboard already uses for sos_alerts).
// Fallback: gentle REST polling — used automatically in the backend's
// no-Firebase dev mode or when a listener errors. Firestore Timestamps
// are normalised to ISO strings so both paths return identical shapes.

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

export function useMyTasks(restFetcher, { pollMs = DEFAULT_POLL_MS } = {}) {
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
      setError(e.message || 'Could not load tasks.');
      return [];
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    let unsub = null;
    let timer = null;

    const startPolling = () => {
      setSource('rest');
      const tick = async () => {
        if (cancelled) return;
        await refresh();
        if (!cancelled) timer = setTimeout(tick, pollMs);
      };
      tick();
    };

    const meta = getSessionMeta();
    if (meta?.mode === 'firebase' && meta?.uid) {
      try {
        const q = query(collection(db, 'tasks'), where('assigned_to', '==', meta.uid));
        unsub = onSnapshot(
          q,
          (snap) => {
            if (cancelled) return;
            setSource('firestore');
            setData(snap.docs.map((doc) => normalize({ id: doc.id, ...doc.data() })));
            setLoading(false);
            setError('');
          },
          (err) => {
            console.warn('[live] tasks listener failed, falling back to REST polling:', err?.code || err);
            if (cancelled) return;
            try { unsub && unsub(); } catch (_) { /* noop */ }
            unsub = null;
            startPolling();
          },
        );
      } catch (e) {
        console.warn('[live] listener unavailable:', e);
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
  }, [pollMs]);

  return { data, loading, error, refresh, source };
}

import React, { useCallback, useMemo, useState } from 'react';
import {
  MapPin, UserCheck, CheckCircle2, Loader2, AlertCircle,
} from 'lucide-react';
import {
  durationLabel,
  listSosAlerts,
  timeAgo,
  updateSosStatus,
} from '../../lib/api';
import { useLiveCollection } from '../../lib/live';
import { nearestCamp } from '../../lib/medicalCamps';
import AssignVolunteerModal from '../tasks/AssignVolunteerModal';
import { SosStatusBadge, TaskFlowSteps } from '../tasks/badges';

const TABS = [
  { key: 'queue', label: 'Needs Response', statuses: ['active'] },
  { key: 'dispatched', label: 'Dispatched', statuses: ['assigned', 'accepted', 'in_progress'] },
  { key: 'resolved', label: 'Resolved', statuses: ['resolved', 'cancelled'] },
  { key: 'all', label: 'All', statuses: null },
];

function openMap(alert) {
  if (alert.latitude && alert.longitude) {
    window.open(
      `https://www.google.com/maps/search/?api=1&query=${alert.latitude},${alert.longitude}`,
      '_blank',
    );
  }
}

export default function ActiveSOS() {
  const [tab, setTab] = useState('queue');
  const [busyId, setBusyId] = useState('');
  const [actionError, setActionError] = useState('');
  const [assignTarget, setAssignTarget] = useState(null); // sos alert being assigned

  const fetcher = useCallback(async () => (await listSosAlerts({ limit: 500 })).alerts, []);
  const { data: alerts, loading, error, refresh } = useLiveCollection('sos_alerts', fetcher, {
    pollMs: 6000,
  });

  const counts = useMemo(() => {
    const c = { queue: 0, dispatched: 0, resolved: 0, all: alerts.length };
    for (const a of alerts) {
      if (a.status === 'active') c.queue += 1;
      else if (a.status === 'resolved' || a.status === 'cancelled') c.resolved += 1;
      else c.dispatched += 1;
    }
    return c;
  }, [alerts]);

  const visible = useMemo(() => {
    const def = TABS.find((t) => t.key === tab) || TABS[0];
    let rows = def.statuses ? alerts.filter((a) => def.statuses.includes(a.status)) : alerts;
    return [...rows].sort(
      (a, b) => String(b.created_at || '').localeCompare(String(a.created_at || '')),
    );
  }, [alerts, tab]);

  const resolve = async (alert) => {
    setBusyId(alert.sos_id || alert.id);
    setActionError('');
    try {
      await updateSosStatus(alert.sos_id || alert.id, 'resolved');
      await refresh();
    } catch (e) {
      setActionError(e.message || 'Could not mark resolved.');
    } finally {
      setBusyId('');
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-orange-600"></div>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-5">
      {assignTarget && (
        <AssignVolunteerModal
          draft={buildSosDraft(assignTarget)}
          taskId={assignTarget.task_id || null}
          onClose={() => setAssignTarget(null)}
          onAssigned={() => {
            setAssignTarget(null);
            refresh();
          }}
        />
      )}

      {/* filter tabs */}
      <div className="flex flex-wrap items-center gap-2">
        {TABS.map((t) => {
          const active = tab === t.key;
          const count = counts[t.key];
          return (
            <button
              key={t.key}
              onClick={() => setTab(t.key)}
              className={`px-4 py-1.5 rounded-full text-xs font-bold cursor-pointer transition-colors border ${
                active
                  ? t.key === 'queue'
                    ? 'bg-red-500 text-white border-red-500'
                    : 'bg-orange-500 text-white border-orange-500'
                  : 'bg-white text-gray-600 border-gray-200 hover:border-orange-300'
              }`}
            >
              {t.label}
              <span className={`ml-1.5 ${active ? 'text-orange-100' : 'text-gray-400'}`}>{count}</span>
            </button>
          );
        })}
      </div>

      {actionError && (
        <p className="text-xs font-semibold text-red-600 flex items-center gap-1.5">
          <AlertCircle size={14} /> {actionError}
        </p>
      )}

      {error && alerts.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-16 text-red-500 gap-2">
          <AlertCircle size={22} />
          <p className="text-sm font-semibold">{error}</p>
        </div>
      ) : visible.length === 0 ? (
        <div className="flex flex-col items-center justify-center h-full text-center p-8 border-2 border-dashed border-green-200 rounded-3xl bg-green-50/50">
          <h3 className="text-xl font-bold text-green-800 mb-2">
            {tab === 'queue' ? 'No Emergencies Waiting' : 'Nothing Here'}
          </h3>
          <p className="text-green-600 text-sm">
            {tab === 'queue'
              ? 'All incoming SOS alerts have been dispatched.'
              : 'Alerts will appear here as their status changes.'}
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6">
          {visible.map((alert) => {
            const id = alert.sos_id || alert.id;
            const resolved = alert.status === 'resolved';
            const activeQueue = alert.status === 'active';
            return (
              <div
                key={id}
                className={`bg-white p-6 rounded-2xl shadow-md flex flex-col gap-4 relative overflow-hidden border ${
                  activeQueue ? 'border-red-100 shadow-red-50/50' : 'border-orange-100 shadow-orange-50/50'
                }`}
              >
                <div
                  className={`absolute top-0 left-0 w-1.5 h-full ${
                    activeQueue ? 'bg-red-500' : resolved ? 'bg-green-500' : 'bg-orange-400'
                  }`}
                ></div>

                <div className="flex justify-between items-start pl-2 gap-2">
                  <div>
                    <h3 className="text-lg font-bold text-gray-900 capitalize">
                      {alert.sos_type ? `${alert.sos_type} Emergency` : 'Emergency SOS'}
                    </h3>
                    <p className="text-sm text-gray-500 mt-0.5">
                      Person:{' '}
                      <span className="font-semibold">
                        {alert.user_name || alert.user_id || 'Unknown User'}
                      </span>
                    </p>
                    <p className="text-[11px] text-gray-400 mt-0.5">{timeAgo(alert.created_at)}</p>
                  </div>
                  <SosStatusBadge status={alert.status} />
                </div>

                <p className="text-gray-700 bg-orange-50/50 p-4 rounded-xl border border-orange-100/50 ml-2 font-medium">
                  "{alert.message || 'No description provided.'}"
                </p>

                <div className="ml-2 flex flex-col gap-1">
                  <span className="text-xs text-gray-500 font-semibold uppercase tracking-wider">Location</span>
                  <span className="text-sm font-mono text-gray-800">
                    {alert.latitude && alert.longitude
                      ? `${Number(alert.latitude).toFixed(6)}, ${Number(alert.longitude).toFixed(6)}`
                      : 'Fetching coordinates...'}
                  </span>
                  {alert.user_phone && (
                    <span className="text-xs text-gray-500">☎ {alert.user_phone}</span>
                  )}
                </div>

                {/* dispatch state */}
                {alert.assigned_volunteer_name && !activeQueue && (
                  <div className="ml-2 bg-purple-50/60 border border-purple-100 rounded-xl p-3">
                    <p className="text-[10px] font-black uppercase tracking-wider text-purple-600">
                      Dispatched to
                    </p>
                    <p className="font-bold text-gray-900 text-sm mt-0.5">
                      {alert.assigned_volunteer_name}
                    </p>
                    <div className="mt-2">
                      <TaskFlowSteps status={alert.status} />
                    </div>
                    {resolved && alert.response_seconds != null && (
                      <p className="text-xs text-green-700 font-bold mt-2 flex items-center gap-1">
                        <CheckCircle2 size={13} /> Responded in {durationLabel(alert.response_seconds)}
                      </p>
                    )}
                  </div>
                )}

                <div className="flex flex-col sm:flex-row gap-2 mt-auto ml-2">
                  {activeQueue && (
                    <button
                      onClick={() => setAssignTarget(alert)}
                      className="flex-1 bg-red-600 hover:bg-red-700 text-white py-2.5 rounded-xl font-semibold cursor-pointer transition-colors shadow-sm shadow-red-200 flex items-center justify-center gap-1.5"
                    >
                      <UserCheck size={16} /> Assign Volunteer
                    </button>
                  )}
                  {!activeQueue && !resolved && (
                    <>
                      <button
                        onClick={() => setAssignTarget(alert)}
                        className="flex-1 bg-white border border-purple-200 text-purple-700 hover:bg-purple-50 py-2.5 rounded-xl font-semibold cursor-pointer transition-colors flex items-center justify-center gap-1.5"
                      >
                        <UserCheck size={15} /> Reassign
                      </button>
                      <button
                        onClick={() => resolve(alert)}
                        disabled={busyId === id}
                        className="flex-1 bg-green-600 hover:bg-green-700 text-white py-2.5 rounded-xl font-semibold cursor-pointer transition-colors flex items-center justify-center gap-1.5 disabled:opacity-60"
                      >
                        {busyId === id ? <Loader2 size={15} className="animate-spin" /> : <CheckCircle2 size={15} />}
                        Mark Resolved
                      </button>
                    </>
                  )}
                  <button
                    className="flex-1 bg-white border border-gray-200 hover:bg-gray-50 text-gray-700 py-2.5 rounded-xl font-semibold cursor-pointer transition-colors flex items-center justify-center gap-1.5"
                    onClick={() => openMap(alert)}
                  >
                    <MapPin size={15} /> View Map
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

// Build the task draft pre-filled from an existing SOS alert.
export function buildSosDraft(alert) {
  const isMedical = (alert.sos_type || '').toLowerCase() === 'medical';
  const camp = isMedical ? nearestCamp(alert.latitude, alert.longitude) : null;
  return {
    type: 'sos',
    title: `${(alert.sos_type || 'general').replace(/^\w/, (c) => c.toUpperCase())} Emergency — ${alert.user_name || alert.user_id || 'Warkari'}`,
    description: alert.message || '',
    priority: 'high',
    source_kind: 'sos',
    source_id: alert.sos_id || alert.id,
    location: {
      latitude: alert.latitude ?? null,
      longitude: alert.longitude ?? null,
      address: alert.latitude != null
        ? `${Number(alert.latitude).toFixed(5)}, ${Number(alert.longitude).toFixed(5)}`
        : null,
    },
    incident: {
      person_name: alert.user_name || null,
      person_phone: alert.user_phone || null,
      details: alert.message || null,
      medical_camp: camp,
    },
  };
}

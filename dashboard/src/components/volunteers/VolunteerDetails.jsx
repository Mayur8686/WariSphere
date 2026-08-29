import React, { useCallback, useEffect, useState } from 'react';
import {
  X, Phone, MapPin, Mail, ShieldAlert, Loader2, AlertCircle,
  CircleCheck, CircleOff, Clock, Activity,
} from 'lucide-react';
import {
  listTasks,
  setVolunteerAvailability,
  setVolunteerStatus,
  timeAgo,
  durationLabel,
} from '../../lib/api';
import {
  AvailabilityBadge,
  PriorityBadge,
  SkillChip,
  TaskStatusBadge,
  VolunteerStatusBadge,
} from '../tasks/badges';

function Row({ label, children }) {
  return (
    <div className="flex justify-between gap-4 text-sm">
      <dt className="text-gray-400">{label}</dt>
      <dd className="font-semibold text-gray-800 text-right">{children ?? '—'}</dd>
    </div>
  );
}

export default function VolunteerDetails({ volunteer, onClose, onChanged }) {
  const [tasks, setTasks] = useState([]);
  const [loadingTasks, setLoadingTasks] = useState(true);
  const [actionError, setActionError] = useState('');
  const [busy, setBusy] = useState('');

  const loadTasks = useCallback(async () => {
    setLoadingTasks(true);
    try {
      const data = await listTasks({ assignedTo: volunteer.uid, view: 'all', limit: 25 });
      setTasks(data.tasks);
    } catch (_) {
      setTasks([]);
    } finally {
      setLoadingTasks(false);
    }
  }, [volunteer.uid]);

  useEffect(() => {
    loadTasks();
  }, [loadTasks]);

  if (!volunteer) return null;

  const act = async (key, fn) => {
    setBusy(key);
    setActionError('');
    try {
      await fn();
      onChanged?.();
      await loadTasks();
    } catch (e) {
      setActionError(e.message || 'Action failed.');
    } finally {
      setBusy('');
    }
  };

  const isSuspended = volunteer.status !== 'active';
  const currentTask = tasks.find((t) => ['assigned', 'accepted', 'in_progress'].includes(t.status));

  return (
    <div className="fixed inset-0 z-50 flex justify-end bg-black/30" onClick={onClose}>
      <div
        className="w-full max-w-md h-full bg-orange-50 shadow-2xl overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        {/* header */}
        <div className="sticky top-0 z-10 bg-white border-b border-orange-100 p-5 flex items-start justify-between">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-orange-100 text-orange-600 rounded-full flex items-center justify-center font-black text-lg shrink-0">
              {(volunteer.name || '?').charAt(0)}
            </div>
            <div>
              <h3 className="text-lg font-bold text-gray-900 leading-tight">{volunteer.name}</h3>
              <div className="flex gap-1.5 mt-1">
                <VolunteerStatusBadge status={volunteer.status} />
                <AvailabilityBadge availability={volunteer.availability} />
              </div>
            </div>
          </div>
          <button onClick={onClose} className="p-1.5 rounded-lg text-gray-400 hover:bg-orange-50 hover:text-orange-600 cursor-pointer">
            <X size={18} />
          </button>
        </div>

        <div className="p-5 space-y-4">
          {/* profile */}
          <section className="bg-white rounded-2xl border border-orange-100 p-4">
            <h4 className="text-xs font-black uppercase tracking-wider text-gray-400 mb-3">Profile</h4>
            <dl className="space-y-2">
              <Row label="Email"><span className="flex items-center gap-1"><Mail size={12} /> {volunteer.email}</span></Row>
              <Row label="Phone"><span className="flex items-center gap-1"><Phone size={12} /> {volunteer.phone || '—'}</span></Row>
              <Row label="Emergency contact">{volunteer.emergency_contact || '—'}</Row>
              <Row label="Zone"><span className="flex items-center gap-1"><MapPin size={12} /> {volunteer.zone || '—'}</span></Row>
              <Row label="Joined">{timeAgo(volunteer.created_at)}</Row>
              <Row label="Last active">{volunteer.last_active_at ? timeAgo(volunteer.last_active_at) : 'Never'}</Row>
            </dl>
            <div className="flex flex-wrap gap-1.5 mt-3">
              {(volunteer.skills || []).map((s) => <SkillChip key={s} label={s} />)}
              {(!volunteer.skills || volunteer.skills.length === 0) && (
                <span className="text-xs text-gray-400">No skills listed</span>
              )}
            </div>
          </section>

          {/* counters */}
          <section className="grid grid-cols-2 gap-3">
            <div className="bg-white rounded-2xl border border-orange-100 p-4 text-center">
              <p className="text-2xl font-black text-green-600">{volunteer.tasks_completed ?? 0}</p>
              <p className="text-[10px] uppercase font-bold text-gray-400 mt-1">Tasks completed</p>
            </div>
            <div className="bg-white rounded-2xl border border-orange-100 p-4 text-center">
              <p className="text-2xl font-black text-orange-600">{volunteer.tasks_active ?? 0}</p>
              <p className="text-[10px] uppercase font-bold text-gray-400 mt-1">Tasks active</p>
            </div>
          </section>

          {/* current task */}
          <section className="bg-white rounded-2xl border border-orange-100 p-4">
            <h4 className="text-xs font-black uppercase tracking-wider text-gray-400 mb-3 flex items-center gap-1.5">
              <Activity size={13} /> Current task
            </h4>
            {currentTask ? (
              <div className="border border-orange-100 rounded-xl p-3 bg-orange-50/50">
                <div className="flex items-start justify-between gap-2">
                  <p className="font-bold text-gray-900 text-sm">{currentTask.title}</p>
                  <PriorityBadge priority={currentTask.priority} />
                </div>
                <p className="text-xs text-gray-500 mt-1 capitalize">{currentTask.type?.replace(/_/g, ' ')} · assigned {timeAgo(currentTask.assigned_at || currentTask.created_at)}</p>
                <div className="mt-2"><TaskStatusBadge status={currentTask.status} /></div>
              </div>
            ) : (
              <p className="text-sm text-gray-400">No active task — {(volunteer.availability || 'offline').toLowerCase()} for dispatch.</p>
            )}
          </section>

          {/* management actions */}
          <section className="bg-white rounded-2xl border border-orange-100 p-4 space-y-2">
            <h4 className="text-xs font-black uppercase tracking-wider text-gray-400 mb-1">Manage</h4>
            <div className="grid grid-cols-2 gap-2">
              {isSuspended ? (
                <button
                  type="button"
                  disabled={busy !== ''}
                  onClick={() => act('status', () => setVolunteerStatus(volunteer.uid, 'active'))}
                  className="py-2 rounded-xl text-xs font-bold bg-green-600 text-white hover:bg-green-700 cursor-pointer disabled:opacity-60 flex items-center justify-center gap-1.5"
                >
                  {busy === 'status' ? <Loader2 size={13} className="animate-spin" /> : <CircleCheck size={13} />}
                  Reactivate
                </button>
              ) : (
                <button
                  type="button"
                  disabled={busy !== ''}
                  onClick={() => act('status', () => setVolunteerStatus(volunteer.uid, 'suspended'))}
                  className="py-2 rounded-xl text-xs font-bold bg-white border border-red-200 text-red-600 hover:bg-red-50 cursor-pointer disabled:opacity-60 flex items-center justify-center gap-1.5"
                >
                  {busy === 'status' ? <Loader2 size={13} className="animate-spin" /> : <CircleOff size={13} />}
                  Suspend
                </button>
              )}
              <button
                type="button"
                disabled={busy !== '' || !!currentTask}
                title={currentTask ? 'Volunteer has an active task' : ''}
                onClick={() =>
                  act('availability', () =>
                    setVolunteerAvailability(
                      volunteer.uid,
                      volunteer.availability === 'offline' ? 'available' : 'offline',
                    ),
                  )
                }
                className="py-2 rounded-xl text-xs font-bold bg-gray-50 border border-gray-200 text-gray-700 hover:bg-gray-100 cursor-pointer disabled:opacity-60 flex items-center justify-center gap-1.5"
              >
                {busy === 'availability' ? <Loader2 size={13} className="animate-spin" /> : null}
                {volunteer.availability === 'offline' ? 'Mark available' : 'Mark offline'}
              </button>
            </div>
            <p className="text-[11px] text-gray-400 flex items-start gap-1.5 pt-1">
              <ShieldAlert size={12} className="mt-0.5 shrink-0" />
              Availability with an active task is system-managed; suspend blocks all sign-ins.
            </p>
            {actionError && (
              <p className="text-xs font-semibold text-red-600 flex items-start gap-1.5">
                <AlertCircle size={14} className="shrink-0 mt-0.5" /> {actionError}
              </p>
            )}
          </section>

          {/* history */}
          <section className="bg-white rounded-2xl border border-orange-100 p-4">
            <h4 className="text-xs font-black uppercase tracking-wider text-gray-400 mb-3 flex items-center gap-1.5">
              <Clock size={13} /> Task history
            </h4>
            {loadingTasks ? (
              <p className="text-sm text-gray-400 flex items-center gap-2"><Loader2 size={14} className="animate-spin" /> Loading…</p>
            ) : tasks.length === 0 ? (
              <p className="text-sm text-gray-400">No tasks assigned yet.</p>
            ) : (
              <ul className="space-y-2">
                {tasks.map((t) => (
                  <li key={t.task_id} className="border border-gray-100 rounded-xl p-3">
                    <div className="flex items-start justify-between gap-2">
                      <div className="min-w-0">
                        <p className="font-bold text-sm text-gray-900 truncate">{t.title}</p>
                        <p className="text-[11px] text-gray-400 capitalize mt-0.5">
                          {t.type?.replace(/_/g, ' ')} · {timeAgo(t.created_at)}
                          {t.status === 'completed' && t.response_seconds != null && (
                            <> · responded in {durationLabel(t.response_seconds)}</>
                          )}
                        </p>
                        {t.completion_note && (
                          <p className="text-[11px] text-gray-500 mt-1 italic">“{t.completion_note}”</p>
                        )}
                      </div>
                      <TaskStatusBadge status={t.status} />
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </section>
        </div>
      </div>
    </div>
  );
}

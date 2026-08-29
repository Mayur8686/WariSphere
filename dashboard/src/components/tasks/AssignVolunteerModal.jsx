import React, { useEffect, useMemo, useState } from 'react';
import { UserCheck, Loader2, X, MapPin, AlertCircle } from 'lucide-react';
import { assignTask, createTask, listVolunteers } from '../../lib/api';
import { AvailabilityBadge, SkillChip } from './badges';

/**
 * Assign (or re-assign) a volunteer to an incident.
 *
 * Props:
 *   draft    { type, title, description, priority, source_kind, source_id,
 *              location, incident }        → POST /tasks
 *   taskId   existing task id (re-assign) → POST /tasks/{id}/assign
 *   onClose  () => void
 *   onAssigned (task) => void
 */
export default function AssignVolunteerModal({ draft, taskId = null, onClose, onAssigned }) {
  const [loading, setLoading] = useState(true);
  const [volunteers, setVolunteers] = useState([]);
  const [loadError, setLoadError] = useState('');
  const [selected, setSelected] = useState(null);
  const [priority, setPriority] = useState(draft?.priority || 'high');
  const [title, setTitle] = useState(draft?.title || '');
  const [notes, setNotes] = useState(draft?.description || '');
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState('');

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      setLoadError('');
      try {
        // Show only dispatchable volunteers: active + available.
        const data = await listVolunteers({ availability: 'available' });
        if (cancelled) return;
        const eligible = (data.volunteers || []).filter((v) => v.status === 'active');
        eligible.sort((a, b) => (a.name || '').localeCompare(b.name || ''));
        setVolunteers(eligible);
        if (eligible.length > 0) setSelected(eligible[0].uid);
      } catch (e) {
        if (!cancelled) setLoadError(e.message || 'Could not load volunteers.');
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, []);

  const chosen = useMemo(
    () => volunteers.find((v) => v.uid === selected) || null,
    [volunteers, selected],
  );

  const submit = async () => {
    if (!chosen) {
      setSubmitError('Select a volunteer first.');
      return;
    }
    setSubmitting(true);
    setSubmitError('');
    try {
      let task;
      if (taskId) {
        task = await assignTask(taskId, chosen.uid);
      } else {
        task = await createTask({
          type: draft.type || 'general',
          title: title.trim() || draft.title,
          description: notes.trim() || null,
          priority,
          assigned_to: chosen.uid,
          source_kind: draft.source_kind || 'manual',
          source_id: draft.source_id || null,
          location: draft.location || null,
          incident: draft.incident || null,
        });
      }
      onAssigned?.(task);
    } catch (e) {
      setSubmitError(e.message || 'Assignment failed.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40" onClick={onClose}>
      <div
        className="bg-white rounded-2xl shadow-xl max-w-lg w-full p-6 border border-orange-100 max-h-[90vh] overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-3 mb-1">
          <div>
            <h3 className="text-xl font-bold text-gray-900 flex items-center gap-2">
              <UserCheck className="text-orange-500" size={22} />
              {taskId ? 'Re-assign Task' : 'Assign Volunteer'}
            </h3>
            <p className="text-sm text-gray-500 mt-0.5">
              {taskId
                ? 'Pick a replacement volunteer for this task.'
                : 'Create a volunteer task from this incident.'}
            </p>
          </div>
          <button onClick={onClose} className="p-1.5 rounded-lg text-gray-400 hover:bg-orange-50 hover:text-orange-600 cursor-pointer">
            <X size={18} />
          </button>
        </div>

        {/* incident summary */}
        {draft && (
          <div className="mt-3 bg-orange-50/70 border border-orange-100 rounded-xl p-3">
            <p className="text-[10px] font-black uppercase tracking-wider text-orange-600">
              {draft.source_kind === 'sos' ? 'SOS Alert' : draft.source_kind === 'lost_person' ? 'Lost Person' : 'Incident'}
            </p>
            <p className="font-bold text-gray-900 mt-0.5">{draft.title}</p>
            {draft.location?.address && (
              <p className="text-xs text-gray-500 mt-0.5 flex items-center gap-1">
                <MapPin size={12} /> {draft.location.address}
              </p>
            )}
            {draft.incident?.person_name && (
              <p className="text-xs text-gray-500 mt-0.5">Person: {draft.incident.person_name}</p>
            )}
          </div>
        )}

        {/* task fields (new assignments only) */}
        {!taskId && (
          <div className="mt-4 space-y-3">
            <div>
              <label className="block text-[11px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Task title</label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                className="w-full px-3 py-2.5 rounded-xl bg-gray-50 border border-gray-200 focus:border-orange-500 focus:ring-1 focus:ring-orange-500 outline-none text-sm"
              />
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className="block text-[11px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Priority</label>
                <select
                  value={priority}
                  onChange={(e) => setPriority(e.target.value)}
                  className="w-full px-3 py-2.5 rounded-xl bg-gray-50 border border-gray-200 focus:border-orange-500 outline-none text-sm cursor-pointer"
                >
                  <option value="critical">🚨 Critical</option>
                  <option value="high">High</option>
                  <option value="medium">Medium</option>
                  <option value="low">Low</option>
                </select>
              </div>
              <div>
                <label className="block text-[11px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Notes (optional)</label>
                <input
                  type="text"
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="Instructions for the volunteer"
                  className="w-full px-3 py-2.5 rounded-xl bg-gray-50 border border-gray-200 focus:border-orange-500 outline-none text-sm"
                />
              </div>
            </div>
          </div>
        )}

        {/* volunteer picker */}
        <div className="mt-4">
          <p className="text-[11px] font-bold uppercase tracking-wider text-gray-500 mb-2">
            Available volunteers
          </p>
          {loading ? (
            <div className="flex items-center gap-2 text-gray-400 text-sm py-6 justify-center">
              <Loader2 className="animate-spin" size={18} /> Loading volunteers…
            </div>
          ) : loadError ? (
            <p className="text-sm text-red-600 flex items-center gap-1.5 py-3">
              <AlertCircle size={14} /> {loadError}
            </p>
          ) : volunteers.length === 0 ? (
            <div className="text-sm text-gray-500 bg-gray-50 border border-gray-200 rounded-xl p-3">
              No volunteers are <b>available</b> right now. Mark volunteers available in the
              Volunteers section, or register a new one.
            </div>
          ) : (
            <div className="space-y-2 max-h-56 overflow-y-auto pr-1">
              {volunteers.map((v) => {
                const active = v.uid === selected;
                return (
                  <button
                    key={v.uid}
                    type="button"
                    onClick={() => setSelected(v.uid)}
                    className={`w-full text-left flex items-center gap-3 p-3 rounded-xl border transition-all cursor-pointer ${
                      active
                        ? 'border-orange-500 bg-orange-50 shadow-sm ring-1 ring-orange-300'
                        : 'border-gray-200 hover:border-orange-300 hover:bg-orange-50/40'
                    }`}
                  >
                    <div className="w-9 h-9 bg-orange-100 text-orange-600 rounded-full flex items-center justify-center font-bold text-xs shrink-0">
                      {(v.name || '?').charAt(0)}
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="font-bold text-gray-900 text-sm truncate">{v.name}</p>
                      <div className="flex flex-wrap items-center gap-1 mt-1">
                        {(v.skills || []).slice(0, 3).map((s) => (
                          <SkillChip key={s} label={s} />
                        ))}
                        {(!v.skills || v.skills.length === 0) && (
                          <span className="text-[10px] text-gray-400">No skills listed</span>
                        )}
                      </div>
                    </div>
                    <AvailabilityBadge availability={v.availability} />
                  </button>
                );
              })}
            </div>
          )}
        </div>

        {submitError && (
          <p className="mt-3 text-xs font-semibold text-red-600 flex items-start gap-1.5">
            <AlertCircle size={14} className="shrink-0 mt-0.5" /> {submitError}
          </p>
        )}

        <div className="mt-5 flex gap-2">
          <button
            type="button"
            onClick={onClose}
            className="flex-1 py-2.5 rounded-xl text-sm font-bold border border-gray-200 text-gray-600 hover:bg-gray-50 cursor-pointer"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={submit}
            disabled={submitting || loading || volunteers.length === 0}
            className="flex-1 py-2.5 rounded-xl text-sm font-bold bg-orange-500 hover:bg-orange-600 text-white cursor-pointer disabled:opacity-60 flex items-center justify-center gap-2 shadow-sm shadow-orange-200"
          >
            {submitting && <Loader2 size={15} className="animate-spin" />}
            {taskId ? 'Re-assign' : 'Assign Task'}
          </button>
        </div>
      </div>
    </div>
  );
}

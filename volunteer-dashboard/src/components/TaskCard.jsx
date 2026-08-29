import React, { useState } from 'react';
import {
  MapPin, Phone, Clock, Tent, CheckCircle2, Play, XCircle,
  AlertTriangle, Loader2, Navigation,
} from 'lucide-react';
import { completeTask, resolvePhotoUrl, taskAction, taskTypeLabel, timeAgo } from '../lib/api';
import { PriorityBadge, TaskStatusBadge } from './tasks/badges';
import TaskNoteModal from './TaskNoteModal';

const OPEN_STATUSES = ['assigned', 'accepted', 'in_progress'];

export default function TaskCard({ task, isNew = false, onChanged }) {
  const [modal, setModal] = useState(null); // 'reject' | 'issue' | 'complete'
  const [acting, setActing] = useState('');
  const [error, setError] = useState('');

  const incident = task.incident || {};
  const location = task.location || {};
  const camp = incident.medical_camp;
  const photo = resolvePhotoUrl(incident.photo_url);
  const isOpen = OPEN_STATUSES.includes(task.status);
  const emergency = task.priority === 'high' || task.priority === 'critical';

  const doAction = async (key, fn) => {
    setActing(key);
    setError('');
    try {
      await fn();
      onChanged?.();
    } catch (e) {
      setError(e.message || 'Action failed.');
    } finally {
      setActing('');
    }
  };

  const mapsUrl = location.latitude != null && location.longitude != null
    ? `https://www.google.com/maps/dir/?api=1&destination=${location.latitude},${location.longitude}`
    : null;

  return (
    <div
      className={`bg-white rounded-2xl border shadow-sm overflow-hidden ${
        emergency && isOpen ? 'border-red-200 shadow-red-100/60' : 'border-orange-100'
      }`}
    >
      {modal === 'complete' && (
        <TaskNoteModal
          variant="complete"
          onClose={() => setModal(null)}
          onSubmit={async (note) => {
            await completeTask(task.task_id, note);
            setModal(null);
            onChanged?.();
          }}
        />
      )}
      {modal === 'reject' && (
        <TaskNoteModal
          variant="reject"
          onClose={() => setModal(null)}
          onSubmit={async (note) => {
            await taskAction(task.task_id, 'reject', note);
            setModal(null);
            onChanged?.();
          }}
        />
      )}
      {modal === 'issue' && (
        <TaskNoteModal
          variant="issue"
          onClose={() => setModal(null)}
          onSubmit={async (note) => {
            await taskAction(task.task_id, 'unable-to-complete', note);
            setModal(null);
            onChanged?.();
          }}
        />
      )}

      {/* priority banner */}
      <div
        className={`px-5 py-2.5 flex items-center justify-between gap-2 ${
          emergency && isOpen ? 'bg-red-600 text-white' : 'bg-orange-500 text-white'
        }`}
      >
        <span className="text-xs font-black uppercase tracking-wider flex items-center gap-1.5">
          {emergency && isOpen ? '🚨 HIGH PRIORITY' : taskTypeLabel(task.type)}
        </span>
        <div className="flex items-center gap-2">
          {isNew && (
            <span className="text-[10px] font-black uppercase bg-white/25 px-2 py-0.5 rounded-full animate-pulse">
              New Task
            </span>
          )}
          <span className="text-[11px] font-semibold opacity-90 flex items-center gap-1">
            <Clock size={12} /> {timeAgo(task.assigned_at || task.created_at)}
          </span>
        </div>
      </div>

      <div className="p-5 flex flex-col gap-4">
        {/* heading */}
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <p className="text-[10px] font-black uppercase tracking-wider text-orange-600">
              {taskTypeLabel(task.type)}
            </p>
            <h3 className="text-lg font-bold text-gray-900 leading-snug mt-0.5">{task.title}</h3>
          </div>
          <div className="flex flex-col items-end gap-1.5 shrink-0">
            <PriorityBadge priority={task.priority} />
            <TaskStatusBadge status={task.status} />
          </div>
        </div>

        {/* location */}
        {(location.address || location.latitude != null) && (
          <div className="flex items-center justify-between gap-3 bg-orange-50/70 border border-orange-100 rounded-xl px-3.5 py-2.5">
            <span className="text-sm text-gray-700 flex items-center gap-1.5 min-w-0">
              <MapPin size={15} className="text-orange-500 shrink-0" />
              <span className="truncate font-semibold">
                {location.address || `${Number(location.latitude).toFixed(5)}, ${Number(location.longitude).toFixed(5)}`}
              </span>
            </span>
            {mapsUrl && (
              <a
                href={mapsUrl}
                target="_blank"
                rel="noreferrer"
                className="text-xs font-bold text-orange-600 hover:text-orange-700 flex items-center gap-1 shrink-0"
              >
                <Navigation size={12} /> Navigate
              </a>
            )}
          </div>
        )}

        {/* person */}
        {(incident.person_name || incident.person_phone || photo) && (
          <div className="flex items-start gap-3">
            {photo ? (
              <img src={photo} alt={incident.person_name || 'person'} className="w-14 h-14 rounded-xl object-cover bg-gray-100 shrink-0" />
            ) : (
              <div className="w-14 h-14 rounded-xl bg-orange-100 text-orange-600 flex items-center justify-center font-black text-lg shrink-0">
                {(incident.person_name || '?').charAt(0)}
              </div>
            )}
            <div className="min-w-0">
              <p className="text-[10px] font-black uppercase tracking-wider text-gray-400">Person</p>
              <p className="font-bold text-gray-900">{incident.person_name || 'Unknown'}</p>
              {incident.person_phone && (
                <a href={`tel:${incident.person_phone}`} className="text-xs font-bold text-green-700 flex items-center gap-1 mt-0.5">
                  <Phone size={11} /> {incident.person_phone}
                </a>
              )}
            </div>
          </div>
        )}

        {/* description */}
        {(task.description || incident.details) && (
          <p className="text-sm text-gray-600 bg-gray-50 border border-gray-100 rounded-xl p-3 leading-relaxed">
            {task.description || incident.details}
          </p>
        )}

        {/* medical camp context */}
        {camp && (
          <div className="flex items-start gap-3 bg-green-50/70 border border-green-100 rounded-xl p-3">
            <div className="w-9 h-9 bg-green-100 text-green-700 rounded-lg flex items-center justify-center shrink-0">
              <Tent size={16} />
            </div>
            <div className="min-w-0">
              <p className="text-[10px] font-black uppercase tracking-wider text-green-700">
                Nearest medical camp{camp.distance_km != null ? ` · ${camp.distance_km} km` : ''}
              </p>
              <p className="font-bold text-gray-900 text-sm">{camp.name}</p>
              <p className="text-xs text-gray-500">{camp.location}</p>
              {camp.contact && (
                <a href={`tel:${camp.contact}`} className="text-xs font-bold text-green-700 flex items-center gap-1 mt-0.5">
                  <Phone size={11} /> {camp.contact}
                </a>
              )}
            </div>
          </div>
        )}

        {/* resolution / completion notes */}
        {task.completion_note && (
          <p className="text-sm text-green-800 bg-green-50 border border-green-100 rounded-xl p-3 italic">
            “{task.completion_note}”
          </p>
        )}
        {task.resolution_note && !task.completion_note && (
          <p className="text-sm text-gray-600 bg-gray-50 border border-gray-200 rounded-xl p-3 italic">
            “{task.resolution_note}”
          </p>
        )}

        {error && (
          <p className="text-xs font-semibold text-red-600 flex items-center gap-1.5">
            <AlertTriangle size={13} /> {error}
          </p>
        )}

        {/* actions — strictly following the lifecycle */}
        {isOpen && (
          <div className="flex flex-col gap-2">
            {task.status === 'assigned' && (
              <div className="flex gap-2">
                <button
                  onClick={() => doAction('accept', () => taskAction(task.task_id, 'accept'))}
                  disabled={acting !== ''}
                  className="flex-1 bg-green-600 hover:bg-green-700 text-white py-3 rounded-xl font-bold cursor-pointer transition-colors flex items-center justify-center gap-2 disabled:opacity-60 shadow-sm shadow-green-200"
                >
                  {acting === 'accept' ? <Loader2 size={16} className="animate-spin" /> : <CheckCircle2 size={16} />}
                  ACCEPT TASK
                </button>
                <button
                  onClick={() => setModal('reject')}
                  disabled={acting !== ''}
                  className="px-4 bg-white border border-gray-200 hover:bg-gray-50 text-gray-600 py-3 rounded-xl font-bold cursor-pointer transition-colors disabled:opacity-60"
                >
                  <XCircle size={16} />
                </button>
              </div>
            )}

            {task.status === 'accepted' && (
              <div className="flex gap-2">
                <button
                  onClick={() => doAction('start', () => taskAction(task.task_id, 'start'))}
                  disabled={acting !== ''}
                  className="flex-1 bg-orange-500 hover:bg-orange-600 text-white py-3 rounded-xl font-bold cursor-pointer transition-colors flex items-center justify-center gap-2 disabled:opacity-60 shadow-sm shadow-orange-200"
                >
                  {acting === 'start' ? <Loader2 size={16} className="animate-spin" /> : <Play size={16} />}
                  START TASK
                </button>
                <button
                  onClick={() => setModal('issue')}
                  disabled={acting !== ''}
                  className="px-4 bg-white border border-red-200 text-red-600 hover:bg-red-50 py-3 rounded-xl font-bold cursor-pointer transition-colors disabled:opacity-60 text-xs"
                >
                  REPORT ISSUE
                </button>
              </div>
            )}

            {task.status === 'in_progress' && (
              <div className="flex gap-2">
                <button
                  onClick={() => setModal('complete')}
                  disabled={acting !== ''}
                  className="flex-1 bg-green-600 hover:bg-green-700 text-white py-3 rounded-xl font-bold cursor-pointer transition-colors flex items-center justify-center gap-2 disabled:opacity-60 shadow-sm shadow-green-200"
                >
                  <CheckCircle2 size={16} />
                  COMPLETE TASK
                </button>
                <button
                  onClick={() => setModal('issue')}
                  disabled={acting !== ''}
                  className="px-4 bg-white border border-red-200 text-red-600 hover:bg-red-50 py-3 rounded-xl font-bold cursor-pointer transition-colors disabled:opacity-60 text-xs"
                >
                  REPORT ISSUE
                </button>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

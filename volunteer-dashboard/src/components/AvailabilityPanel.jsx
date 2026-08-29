import React, { useState } from 'react';
import { CheckCircle2, Coffee, Moon, Loader2, AlertCircle } from 'lucide-react';
import { setMyAvailability } from '../lib/api';
import { AvailabilityBadge } from './tasks/badges';

const OPTIONS = [
  {
    key: 'available',
    icon: <CheckCircle2 size={22} />,
    title: 'Available',
    desc: 'Ready to be dispatched by the control room.',
    activeClass: 'border-green-500 bg-green-50 ring-1 ring-green-300',
    iconClass: 'text-green-600',
  },
  {
    key: 'busy',
    icon: <Coffee size={22} />,
    title: 'Busy',
    desc: 'On site but temporarily occupied — pause new assignments.',
    activeClass: 'border-amber-500 bg-amber-50 ring-1 ring-amber-300',
    iconClass: 'text-amber-600',
  },
  {
    key: 'offline',
    icon: <Moon size={22} />,
    title: 'Offline',
    desc: 'Off duty. Your account and tasks stay safe, no new dispatches.',
    activeClass: 'border-gray-400 bg-gray-100 ring-1 ring-gray-300',
    iconClass: 'text-gray-500',
  },
];

export default function AvailabilityPanel({ profile, tasks, onChanged }) {
  const [busy, setBusy] = useState('');
  const [error, setError] = useState('');
  const [note, setNote] = useState('');

  const availability = profile?.availability || 'offline';
  const hasActiveTask = (tasks || []).some((t) =>
    ['assigned', 'accepted', 'in_progress'].includes(t.status),
  );

  const change = async (value) => {
    if (value === availability) return;
    setBusy(value);
    setError('');
    setNote('');
    try {
      await setMyAvailability(value);
      setNote(
        value === 'available'
          ? 'You are now visible to the control room for dispatch.'
          : value === 'busy'
            ? 'Marked busy — no new tasks until you are available again.'
            : 'You are offline. Rest well 🙏',
      );
      onChanged?.();
    } catch (e) {
      setError(e.message || 'Could not update availability.');
    } finally {
      setBusy('');
    }
  };

  return (
    <div className="flex flex-col gap-5 max-w-2xl">
      <div className="bg-white rounded-2xl border border-orange-100 shadow-sm p-6">
        <p className="text-xs text-gray-400 font-bold uppercase tracking-wider">Current availability</p>
        <div className="mt-2">
          <AvailabilityBadge availability={availability} />
        </div>
        <p className="text-sm text-gray-500 mt-3">
          The control room sees this in real time and only assigns tasks to{' '}
          <b className="text-green-700">available</b> volunteers.
        </p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        {OPTIONS.map((opt) => {
          const isCurrent = availability === opt.key;
          return (
            <button
              key={opt.key}
              type="button"
              disabled={busy !== '' || isCurrent || (opt.key === 'available' && hasActiveTask)}
              onClick={() => change(opt.key)}
              title={opt.key === 'available' && hasActiveTask ? 'Complete your active task first' : ''}
              className={`text-left p-4 rounded-2xl border bg-white shadow-sm transition-all cursor-pointer disabled:cursor-not-allowed ${
                isCurrent ? opt.activeClass : 'border-orange-100 hover:border-orange-300'
              } ${busy !== '' || (opt.key === 'available' && hasActiveTask) ? 'opacity-60' : ''}`}
            >
              <div className={`${opt.iconClass} ${isCurrent ? '' : 'opacity-60'}`}>
                {busy === opt.key ? <Loader2 size={22} className="animate-spin" /> : opt.icon}
              </div>
              <p className="font-bold text-gray-900 mt-2 flex items-center gap-1.5">
                {opt.title}
                {isCurrent && <span className="text-[9px] font-black uppercase text-gray-400">current</span>}
              </p>
              <p className="text-xs text-gray-500 mt-1 leading-relaxed">{opt.desc}</p>
            </button>
          );
        })}
      </div>

      {hasActiveTask && (
        <p className="text-xs text-amber-700 bg-amber-50 border border-amber-200 rounded-xl p-3">
          ⚠️ You have an active task — availability returns to <b>available</b> automatically when
          you complete it.
        </p>
      )}
      {error && (
        <p className="text-sm font-semibold text-red-600 flex items-start gap-1.5">
          <AlertCircle size={15} className="shrink-0 mt-0.5" /> {error}
        </p>
      )}
      {note && !error && (
        <p className="text-sm font-semibold text-green-700 bg-green-50 border border-green-200 rounded-xl p-3">
          {note}
        </p>
      )}
    </div>
  );
}

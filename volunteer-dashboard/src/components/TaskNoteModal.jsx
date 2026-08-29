import React, { useState } from 'react';
import { Loader2, X } from 'lucide-react';

const VARIANTS = {
  complete: {
    title: 'Complete Task',
    label: 'Completion note (optional)',
    placeholder: 'e.g. Person assisted and handed over to medical team.',
    confirm: 'Complete Task',
    confirmClass: 'bg-green-600 hover:bg-green-700',
  },
  reject: {
    title: 'Reject Task',
    label: 'Why can’t you take this task?',
    placeholder: 'e.g. Too far from my zone, no transport.',
    confirm: 'Reject Task',
    confirmClass: 'bg-red-600 hover:bg-red-700',
  },
  issue: {
    title: 'Report Issue',
    label: 'What happened? The control room is notified immediately.',
    placeholder: 'e.g. Reached the spot, situation needs an ambulance crew.',
    confirm: 'Report & Hand Back',
    confirmClass: 'bg-red-600 hover:bg-red-700',
  },
};

export default function TaskNoteModal({ variant, onClose, onSubmit }) {
  const v = VARIANTS[variant] || VARIANTS.complete;
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const submit = async () => {
    if (variant !== 'complete' && !note.trim()) {
      setError('Please add a short reason so the control room can re-plan.');
      return;
    }
    setBusy(true);
    setError('');
    try {
      await onSubmit(note.trim() || null);
    } catch (e) {
      setError(e.message || 'Action failed.');
      setBusy(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40" onClick={busy ? undefined : onClose}>
      <div
        className="bg-white rounded-2xl shadow-xl max-w-md w-full p-6 border border-orange-100"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between mb-3">
          <h3 className="text-lg font-bold text-gray-900">{v.title}</h3>
          <button onClick={onClose} disabled={busy} className="p-1.5 rounded-lg text-gray-400 hover:bg-orange-50 cursor-pointer">
            <X size={18} />
          </button>
        </div>
        <label className="block text-xs font-bold uppercase tracking-wider text-gray-500 mb-2">
          {v.label}
        </label>
        <textarea
          rows={3}
          value={note}
          onChange={(e) => setNote(e.target.value)}
          placeholder={v.placeholder}
          className="w-full px-3 py-2.5 rounded-xl bg-gray-50 border border-gray-200 focus:border-orange-500 focus:ring-1 focus:ring-orange-500 outline-none text-sm resize-none"
        />
        {error && <p className="mt-2 text-xs font-semibold text-red-600">{error}</p>}
        <div className="flex gap-2 mt-4">
          <button
            type="button"
            onClick={onClose}
            disabled={busy}
            className="flex-1 py-2.5 rounded-xl text-sm font-bold border border-gray-200 text-gray-600 hover:bg-gray-50 cursor-pointer disabled:opacity-60"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={submit}
            disabled={busy}
            className={`flex-1 py-2.5 rounded-xl text-sm font-bold text-white cursor-pointer disabled:opacity-60 flex items-center justify-center gap-2 ${v.confirmClass}`}
          >
            {busy && <Loader2 size={15} className="animate-spin" />}
            {v.confirm}
          </button>
        </div>
      </div>
    </div>
  );
}

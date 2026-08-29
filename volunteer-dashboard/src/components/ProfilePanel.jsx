import React, { useState } from 'react';
import { Mail, MapPin, Phone, ShieldAlert, Loader2, Check, Pencil } from 'lucide-react';
import { updateMyProfile } from '../lib/api';
import { AvailabilityBadge, SkillChip, VolunteerStatusBadge } from './tasks/badges';

function Row({ label, children }) {
  return (
    <div className="flex justify-between gap-4 text-sm py-1.5">
      <dt className="text-gray-400">{label}</dt>
      <dd className="font-semibold text-gray-800 text-right">{children ?? '—'}</dd>
    </div>
  );
}

export default function ProfilePanel({ profile, onChanged }) {
  const [editing, setEditing] = useState(false);
  const [form, setForm] = useState({
    phone: profile?.phone || '',
    emergency_contact: profile?.emergency_contact || '',
    zone: profile?.zone || '',
  });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [saved, setSaved] = useState(false);

  if (!profile) return null;

  const save = async () => {
    setBusy(true);
    setError('');
    setSaved(false);
    try {
      await updateMyProfile({
        phone: form.phone.trim() || null,
        emergency_contact: form.emergency_contact.trim() || null,
        zone: form.zone.trim() || null,
      });
      setSaved(true);
      setEditing(false);
      onChanged?.();
      setTimeout(() => setSaved(false), 2500);
    } catch (e) {
      setError(e.message || 'Could not save changes.');
    } finally {
      setBusy(false);
    }
  };

  const set = (field) => (e) => setForm((f) => ({ ...f, [field]: e.target.value }));

  return (
    <div className="flex flex-col gap-5 max-w-2xl">
      <div className="bg-white rounded-2xl border border-orange-100 shadow-sm p-6">
        <div className="flex items-center gap-4">
          <div className="w-16 h-16 bg-orange-100 text-orange-600 rounded-full flex items-center justify-center font-black text-2xl shrink-0">
            {(profile.name || '?').charAt(0)}
          </div>
          <div className="min-w-0">
            <h3 className="text-xl font-bold text-gray-900 truncate">{profile.name}</h3>
            <div className="flex flex-wrap gap-1.5 mt-1.5">
              <VolunteerStatusBadge status={profile.status} />
              <AvailabilityBadge availability={profile.availability} />
            </div>
          </div>
        </div>
      </div>

      <div className="bg-white rounded-2xl border border-orange-100 shadow-sm p-6">
        <div className="flex items-center justify-between mb-2">
          <h4 className="text-xs font-black uppercase tracking-wider text-gray-400">Details</h4>
          {!editing ? (
            <button
              onClick={() => setEditing(true)}
              className="text-xs font-bold text-orange-600 hover:text-orange-700 flex items-center gap-1 cursor-pointer"
            >
              <Pencil size={12} /> Edit contact info
            </button>
          ) : null}
        </div>

        {editing ? (
          <div className="space-y-3 mt-2">
            <div>
              <label className="block text-[11px] font-bold uppercase tracking-wider text-gray-500 mb-1">Phone</label>
              <input value={form.phone} onChange={set('phone')} type="tel" placeholder="+91 98XXX XXXXX"
                className="w-full px-3 py-2.5 rounded-xl bg-gray-50 border border-gray-200 focus:border-orange-500 outline-none text-sm" />
            </div>
            <div>
              <label className="block text-[11px] font-bold uppercase tracking-wider text-gray-500 mb-1">Emergency contact</label>
              <input value={form.emergency_contact} onChange={set('emergency_contact')} type="tel" placeholder="+91 98XXX XXXXX"
                className="w-full px-3 py-2.5 rounded-xl bg-gray-50 border border-gray-200 focus:border-orange-500 outline-none text-sm" />
            </div>
            <div>
              <label className="block text-[11px] font-bold uppercase tracking-wider text-gray-500 mb-1">Zone</label>
              <input value={form.zone} onChange={set('zone')} type="text" placeholder="Sector A - Alandi"
                className="w-full px-3 py-2.5 rounded-xl bg-gray-50 border border-gray-200 focus:border-orange-500 outline-none text-sm" />
            </div>
            {error && <p className="text-xs font-semibold text-red-600">{error}</p>}
            <div className="flex gap-2">
              <button onClick={() => { setEditing(false); setError(''); }} disabled={busy}
                className="flex-1 py-2.5 rounded-xl text-sm font-bold border border-gray-200 text-gray-600 hover:bg-gray-50 cursor-pointer disabled:opacity-60">
                Cancel
              </button>
              <button onClick={save} disabled={busy}
                className="flex-1 py-2.5 rounded-xl text-sm font-bold bg-orange-500 hover:bg-orange-600 text-white cursor-pointer disabled:opacity-60 flex items-center justify-center gap-1.5">
                {busy && <Loader2 size={14} className="animate-spin" />} Save
              </button>
            </div>
          </div>
        ) : (
          <dl className="divide-y divide-gray-50">
            <Row label="Email"><span className="flex items-center gap-1"><Mail size={12} /> {profile.email}</span></Row>
            <Row label="Phone"><span className="flex items-center gap-1"><Phone size={12} /> {profile.phone || '—'}</span></Row>
            <Row label="Emergency contact">{profile.emergency_contact || '—'}</Row>
            <Row label="Zone"><span className="flex items-center gap-1"><MapPin size={12} /> {profile.zone || '—'}</span></Row>
          </dl>
        )}
        {saved && (
          <p className="text-xs font-bold text-green-600 mt-2 flex items-center gap-1">
            <Check size={13} /> Saved.
          </p>
        )}
      </div>

      <div className="bg-white rounded-2xl border border-orange-100 shadow-sm p-6">
        <h4 className="text-xs font-black uppercase tracking-wider text-gray-400 mb-3">Skills</h4>
        <div className="flex flex-wrap gap-1.5">
          {(profile.skills || []).map((s) => <SkillChip key={s} label={s} />)}
          {(!profile.skills || profile.skills.length === 0) && (
            <span className="text-xs text-gray-400">No skills listed — the control room manages these.</span>
          )}
        </div>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div className="bg-white rounded-2xl border border-orange-100 shadow-sm p-5 text-center">
          <p className="text-3xl font-black text-green-600">{profile.tasks_completed ?? 0}</p>
          <p className="text-[10px] uppercase font-bold text-gray-400 mt-1">Tasks completed</p>
        </div>
        <div className="bg-white rounded-2xl border border-orange-100 shadow-sm p-5 text-center">
          <p className="text-3xl font-black text-orange-600">{profile.tasks_active ?? 0}</p>
          <p className="text-[10px] uppercase font-bold text-gray-400 mt-1">Tasks active</p>
        </div>
      </div>

      <p className="text-[11px] text-gray-400 flex items-start gap-1.5">
        <ShieldAlert size={12} className="mt-0.5 shrink-0" />
        Your role, skills and assignments are managed by the control room. You can only update
        your own contact details and availability.
      </p>
    </div>
  );
}

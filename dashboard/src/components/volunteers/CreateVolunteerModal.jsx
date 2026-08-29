import React, { useState } from 'react';
import { UserPlus, Loader2, X, AlertCircle, Copy, Check } from 'lucide-react';
import { createVolunteer } from '../../lib/api';

const SUGGESTED_SKILLS = [
  'first_aid',
  'crowd_management',
  'lost_person_assistance',
  'medical_assistance',
  'route_assistance',
  'emergency_response',
];

const EMPTY = {
  name: '',
  email: '',
  password: '',
  phone: '',
  emergency_contact: '',
  zone: '',
  skills: [],
  availability: 'available',
};

function prettySkill(s) {
  return s.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
}

export default function CreateVolunteerModal({ onClose, onCreated }) {
  const [form, setForm] = useState(EMPTY);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [created, setCreated] = useState(null);
  const [copied, setCopied] = useState(false);

  const set = (field) => (e) => setForm((f) => ({ ...f, [field]: e.target.value }));

  const toggleSkill = (skill) =>
    setForm((f) => ({
      ...f,
      skills: f.skills.includes(skill)
        ? f.skills.filter((s) => s !== skill)
        : [...f.skills, skill],
    }));

  const submit = async (e) => {
    e.preventDefault();
    setError('');
    if (form.password.length < 6) {
      setError('Password must be at least 6 characters (Firebase Auth minimum).');
      return;
    }
    setSubmitting(true);
    try {
      const record = await createVolunteer({
        name: form.name.trim(),
        email: form.email.trim(),
        password: form.password,
        phone: form.phone.trim() || null,
        emergency_contact: form.emergency_contact.trim() || null,
        zone: form.zone.trim() || null,
        skills: form.skills,
        availability: form.availability,
      });
      setCreated(record);
      onCreated?.(record);
    } catch (err) {
      setError(err.message || 'Could not create the volunteer.');
    } finally {
      setSubmitting(false);
    }
  };

  const copyCredentials = async () => {
    try {
      await navigator.clipboard.writeText(
        `WariSphere Volunteer Portal\nEmail: ${created.email}\nPassword: ${form.password}`,
      );
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (_) { /* clipboard blocked */ }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40" onClick={onClose}>
      <div
        className="bg-white rounded-2xl shadow-xl max-w-lg w-full p-6 border border-orange-100 max-h-[92vh] overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-3 mb-4">
          <div>
            <h3 className="text-xl font-bold text-gray-900 flex items-center gap-2">
              <UserPlus className="text-orange-500" size={22} /> Create Volunteer
            </h3>
            <p className="text-sm text-gray-500 mt-0.5">
              The account is provisioned in Firebase Auth and Firestore by the backend.
            </p>
          </div>
          <button onClick={onClose} className="p-1.5 rounded-lg text-gray-400 hover:bg-orange-50 hover:text-orange-600 cursor-pointer">
            <X size={18} />
          </button>
        </div>

        {created ? (
          <div className="flex flex-col items-center text-center gap-3 py-4">
            <div className="w-14 h-14 bg-green-50 border border-green-200 text-green-600 rounded-full flex items-center justify-center">
              <Check size={28} />
            </div>
            <h4 className="text-lg font-bold text-gray-900">{created.name} is ready to deploy</h4>
            <p className="text-xs text-gray-400 font-mono">{created.uid}</p>

            <div className="w-full bg-gray-900 text-left rounded-xl p-4 font-mono text-sm text-green-300">
              <p>Email:&nbsp;&nbsp;&nbsp;&nbsp;{created.email}</p>
              <p>Password: {form.password}</p>
            </div>
            <p className="text-xs text-gray-500">
              Share these credentials with the volunteer — they sign in at the Volunteer Portal.
              The password is shown only now.
            </p>
            <div className="flex gap-2 w-full mt-1">
              <button
                type="button"
                onClick={copyCredentials}
                className="flex-1 py-2.5 rounded-xl text-sm font-bold border border-gray-200 text-gray-700 hover:bg-gray-50 cursor-pointer flex items-center justify-center gap-1.5"
              >
                {copied ? <Check size={15} className="text-green-600" /> : <Copy size={15} />}
                {copied ? 'Copied!' : 'Copy credentials'}
              </button>
              <button
                type="button"
                onClick={onClose}
                className="flex-1 py-2.5 rounded-xl text-sm font-bold bg-orange-500 hover:bg-orange-600 text-white cursor-pointer"
              >
                Done
              </button>
            </div>
          </div>
        ) : (
          <form onSubmit={submit} className="space-y-4">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="sm:col-span-2">
                <label className="block text-[11px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Full name *</label>
                <input required type="text" value={form.name} onChange={set('name')} placeholder="Rahul Patil"
                  className="w-full px-3 py-2.5 rounded-xl bg-gray-50 border border-gray-200 focus:border-orange-500 focus:ring-1 focus:ring-orange-500 outline-none text-sm" />
              </div>
              <div>
                <label className="block text-[11px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Email *</label>
                <input required type="email" value={form.email} onChange={set('email')} placeholder="rahul@warisphere.in"
                  className="w-full px-3 py-2.5 rounded-xl bg-gray-50 border border-gray-200 focus:border-orange-500 outline-none text-sm" />
              </div>
              <div>
                <label className="block text-[11px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Password *</label>
                <input required type="text" value={form.password} onChange={set('password')} placeholder="min. 6 chars" minLength={6}
                  className="w-full px-3 py-2.5 rounded-xl bg-gray-50 border border-gray-200 focus:border-orange-500 outline-none text-sm" />
              </div>
              <div>
                <label className="block text-[11px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Phone</label>
                <input type="tel" value={form.phone} onChange={set('phone')} placeholder="+91 98XXX XXXXX"
                  className="w-full px-3 py-2.5 rounded-xl bg-gray-50 border border-gray-200 focus:border-orange-500 outline-none text-sm" />
              </div>
              <div>
                <label className="block text-[11px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Emergency contact</label>
                <input type="tel" value={form.emergency_contact} onChange={set('emergency_contact')} placeholder="+91 98XXX XXXXX"
                  className="w-full px-3 py-2.5 rounded-xl bg-gray-50 border border-gray-200 focus:border-orange-500 outline-none text-sm" />
              </div>
              <div className="sm:col-span-2">
                <label className="block text-[11px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Area / zone</label>
                <input type="text" value={form.zone} onChange={set('zone')} placeholder="Sector A - Alandi"
                  className="w-full px-3 py-2.5 rounded-xl bg-gray-50 border border-gray-200 focus:border-orange-500 outline-none text-sm" />
              </div>
            </div>

            <div>
              <label className="block text-[11px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Skills</label>
              <div className="flex flex-wrap gap-1.5">
                {SUGGESTED_SKILLS.map((skill) => {
                  const active = form.skills.includes(skill);
                  return (
                    <button
                      key={skill}
                      type="button"
                      onClick={() => toggleSkill(skill)}
                      className={`px-3 py-1.5 rounded-full text-xs font-bold border cursor-pointer transition-colors ${
                        active
                          ? 'bg-orange-500 text-white border-orange-500'
                          : 'bg-white text-gray-600 border-gray-200 hover:border-orange-300'
                      }`}
                    >
                      {prettySkill(skill)}
                    </button>
                  );
                })}
              </div>
            </div>

            <div>
              <label className="block text-[11px] font-bold uppercase tracking-wider text-gray-500 mb-1.5">Initial availability</label>
              <select value={form.availability} onChange={set('availability')}
                className="w-full px-3 py-2.5 rounded-xl bg-gray-50 border border-gray-200 focus:border-orange-500 outline-none text-sm cursor-pointer">
                <option value="available">🟢 Available</option>
                <option value="busy">🟠 Busy</option>
                <option value="offline">⚫ Offline</option>
              </select>
            </div>

            {error && (
              <p className="text-xs font-semibold text-red-600 flex items-start gap-1.5">
                <AlertCircle size={14} className="shrink-0 mt-0.5" /> {error}
              </p>
            )}

            <div className="flex gap-2 pt-1">
              <button type="button" onClick={onClose}
                className="flex-1 py-2.5 rounded-xl text-sm font-bold border border-gray-200 text-gray-600 hover:bg-gray-50 cursor-pointer">
                Cancel
              </button>
              <button type="submit" disabled={submitting}
                className="flex-1 py-2.5 rounded-xl text-sm font-bold bg-orange-500 hover:bg-orange-600 text-white cursor-pointer disabled:opacity-60 flex items-center justify-center gap-2 shadow-sm shadow-orange-200">
                {submitting && <Loader2 size={15} className="animate-spin" />}
                Create Volunteer
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}

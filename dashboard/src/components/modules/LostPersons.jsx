import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  UploadCloud, Search, User, MapPin, Clock, AlertCircle, Loader2, Users,
  ScanSearch, Check, X, Eye, ShieldAlert, Sparkles,
} from 'lucide-react';

import {
  API_BASE,
  confirmFaceMatch,
  initials,
  listReports,
  listTasks,
  missingFor,
  rejectFaceMatch,
  resolvePhotoUrl,
  scanFaceMatch,
  timeAgo,
} from '../../lib/api';
import AssignVolunteerModal from '../tasks/AssignVolunteerModal';
import { TaskStatusBadge } from '../tasks/badges';

const SCAN_STEPS = [
  'Analyzing face…',
  'Detecting face…',
  'Scanning missing-person records…',
  'Calculating probable matches…',
];

// Photo tile with an orange initials fallback when no photo exists.
function PersonTile({ name, photoUrl, size = 'md' }) {
  const [broken, setBroken] = useState(false);
  const src = resolvePhotoUrl(photoUrl);
  const box = size === 'lg' ? 'w-24 h-24 text-3xl' : 'w-20 h-20 text-2xl';
  if (!src || broken) {
    return (
      <div className={`${box} rounded-lg bg-orange-500 text-white font-black flex items-center justify-center shrink-0`}>
        {initials(name)}
      </div>
    );
  }
  return (
    <img
      src={src}
      alt={name}
      onError={() => setBroken(true)}
      className={`${box} rounded-lg object-cover bg-gray-100 shrink-0`}
    />
  );
}

function StatusBadge({ person }) {
  if (person.status === 'reunited') {
    return (
      <span className="text-[10px] font-black uppercase px-2 py-0.5 rounded border text-blue-600 bg-blue-50 border-blue-200">
        Reunited
      </span>
    );
  }
  return person.report_type === 'found' || person.status === 'found' ? (
    <span className="text-[10px] font-black uppercase px-2 py-0.5 rounded border text-green-600 bg-green-50 border-green-200">
      Found
    </span>
  ) : (
    <span className="text-[10px] font-black uppercase px-2 py-0.5 rounded border text-orange-600 bg-orange-50 border-orange-200">
      Missing
    </span>
  );
}

function ConfidencePill({ label, score }) {
  const tone =
    label === 'High confidence'
      ? 'text-green-700 bg-green-50 border-green-200'
      : label === 'Possible match'
        ? 'text-orange-700 bg-orange-50 border-orange-200'
        : 'text-gray-600 bg-gray-50 border-gray-200';
  return (
    <span className={`text-[10px] font-black uppercase px-2 py-0.5 rounded border ${tone}`}>
      {label}
      {typeof score === 'number' ? ` · ${score}%` : ''}
    </span>
  );
}

function PersonCard({ person, highlight, assignedTask, onAssign }) {
  return (
    <div
      className={`border rounded-xl p-4 flex gap-4 hover:shadow-md transition-shadow ${
        highlight ? 'border-orange-400 ring-2 ring-orange-200' : 'border-gray-100'
      }`}
    >
      <PersonTile name={person.name} photoUrl={person.photo_url} />
      <div className="flex-1 min-w-0">
        <div className="flex justify-between items-start gap-2">
          <h4 className="font-bold text-gray-900 truncate">{person.name}</h4>
          <StatusBadge person={person} />
        </div>
        <div className="mt-2 space-y-1">
          {person.age != null && (
            <div className="flex items-center text-xs text-gray-500 gap-1.5">
              <User size={12} /> Approx. {person.age}
              {person.gender ? ` · ${person.gender}` : ''}
            </div>
          )}
          <div className="flex items-center text-xs text-gray-500 gap-1.5">
            <MapPin size={12} /> {person.last_seen_location || 'Location not recorded'}
          </div>
          <div className="flex items-center text-xs text-gray-500 gap-1.5">
            <Clock size={12} /> {timeAgo(person.last_seen_time || person.created_at)}
          </div>
        </div>
        {person.description && (
          <p className="mt-2 text-xs text-gray-400 line-clamp-2">{person.description}</p>
        )}
        {/* Volunteer dispatch state — the task links back to this report */}
        {assignedTask ? (
          <div className="mt-2 flex items-center justify-between gap-2 bg-purple-50/70 border border-purple-100 rounded-lg px-2.5 py-1.5">
            <p className="text-[11px] font-bold text-purple-700 truncate">
              🙋 {assignedTask.assigned_volunteer_name}
            </p>
            <TaskStatusBadge status={assignedTask.status} />
          </div>
        ) : (
          person.status !== 'reunited' && (
            <button
              type="button"
              onClick={() => onAssign?.(person)}
              className="mt-2 inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold bg-orange-100 text-orange-700 hover:bg-orange-200 cursor-pointer transition-colors"
            >
              <Users size={12} /> Assign Volunteer
            </button>
          )
        )}
      </div>
    </div>
  );
}

// Task draft pre-filled from an existing lost/found-person report.
function buildLostPersonDraft(person) {
  return {
    type: 'lost_person',
    title: `Locate ${person.name} — ${person.last_seen_location || 'last known area'}`,
    description: person.description || '',
    priority: 'high',
    source_kind: 'lost_person',
    source_id: person.lost_person_id,
    location: {
      latitude: person.last_seen_latitude ?? null,
      longitude: person.last_seen_longitude ?? null,
      address: person.last_seen_location || null,
    },
    incident: {
      person_name: person.name || null,
      person_phone: person.reporter_phone || null,
      details: [
        person.age ? `Age approx. ${person.age}.` : '',
        person.gender ? `${person.gender}.` : '',
        person.description || '',
      ].filter(Boolean).join(' '),
      photo_url: person.photo_url || null,
    },
  };
}

function DetailsModal({ person, onClose }) {
  if (!person) return null;
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40" onClick={onClose}>
      <div
        className="bg-white rounded-2xl shadow-xl max-w-md w-full p-6 border border-orange-100"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex gap-4">
          <PersonTile name={person.name} photoUrl={person.photo_url} size="lg" />
          <div className="min-w-0">
            <h3 className="text-xl font-bold text-gray-900">{person.name}</h3>
            <div className="mt-1">
              <StatusBadge person={person} />
            </div>
            <p className="text-xs text-gray-400 mt-2 font-mono truncate">
              {person.person_id || person.lost_person_id}
            </p>
          </div>
        </div>
        <dl className="mt-5 space-y-2 text-sm">
          {person.age != null && (
            <div className="flex justify-between gap-4">
              <dt className="text-gray-400">Age</dt>
              <dd className="font-semibold text-gray-800">
                {person.age}{person.gender ? ` · ${person.gender}` : ''}
              </dd>
            </div>
          )}
          <div className="flex justify-between gap-4">
            <dt className="text-gray-400">Location</dt>
            <dd className="font-semibold text-gray-800 text-right">
              {person.location || person.last_seen_location || '—'}
            </dd>
          </div>
          <div className="flex justify-between gap-4">
            <dt className="text-gray-400">Missing for</dt>
            <dd className="font-semibold text-gray-800">
              {person.missing_for || missingFor(person.last_seen_time || person.created_at)}
            </dd>
          </div>
          {typeof person.match_score === 'number' && (
            <div className="flex justify-between gap-4">
              <dt className="text-gray-400">Similarity</dt>
              <dd className="font-semibold text-gray-800">{person.match_score}%</dd>
            </div>
          )}
        </dl>
        {person.description && (
          <p className="mt-4 text-sm text-gray-600 bg-orange-50/60 border border-orange-100 rounded-xl p-3">
            {person.description}
          </p>
        )}
        <p className="mt-4 text-[11px] text-gray-400 flex items-start gap-1.5">
          <ShieldAlert size={12} className="mt-0.5 shrink-0" />
          Probable match only — not an identity confirmation.
        </p>
        <button
          type="button"
          onClick={onClose}
          className="mt-4 w-full py-2.5 bg-orange-500 hover:bg-orange-600 text-white rounded-xl text-sm font-bold cursor-pointer"
        >
          Close
        </button>
      </div>
    </div>
  );
}

const TABS = [
  { key: 'found', label: 'Found' },
  { key: 'lost', label: 'Missing' },
  { key: 'all', label: 'All Reports' },
];

export default function LostPersons() {
  const [dragActive, setDragActive] = useState(false);
  const fileInputRef = useRef(null);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [reports, setReports] = useState([]); // ALL reports from the backend

  const [tab, setTab] = useState('found');
  const [query, setQuery] = useState('');
  const [highlightId, setHighlightId] = useState('');

  const [selectedFile, setSelectedFile] = useState(null);
  const [previewUrl, setPreviewUrl] = useState('');
  const [scanPhase, setScanPhase] = useState('idle'); // idle | scanning | complete | error
  const [scanStep, setScanStep] = useState(0);
  const [scanError, setScanError] = useState('');
  const [scanResult, setScanResult] = useState(null);
  const [actingId, setActingId] = useState('');
  const [details, setDetails] = useState(null);

  const [assignPerson, setAssignPerson] = useState(null);   // report being dispatched
  const [personTasks, setPersonTasks] = useState({});       // lost_person_id -> active task

  // ---- load every report once (lost + found) ------------------------------
  const loadAll = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const all = await listReports({}); // no filter -> the whole database
      setReports(all);
      // active volunteer dispatches linked to lost-person reports (best effort)
      try {
        const { tasks } = await listTasks({ view: 'active', sourceKind: 'lost_person' });
        const map = {};
        for (const t of tasks) if (t.source_id) map[t.source_id] = t;
        setPersonTasks(map);
      } catch (_) {
        setPersonTasks({});
      }
    } catch (e) {
      setError(e.message || 'Could not load reports from the backend.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadAll();
  }, [loadAll]);

  useEffect(() => {
    return () => {
      if (previewUrl) URL.revokeObjectURL(previewUrl);
    };
  }, [previewUrl]);

  useEffect(() => {
    if (scanPhase !== 'scanning') return undefined;
    setScanStep(0);
    const id = setInterval(() => {
      setScanStep((s) => (s + 1) % SCAN_STEPS.length);
    }, 900);
    return () => clearInterval(id);
  }, [scanPhase]);

  // ---- counts --------------------------------------------------------------
  const counts = useMemo(() => {
    const found = reports.filter((r) => r.report_type === 'found' && r.status !== 'reunited');
    const lost = reports.filter((r) => r.report_type === 'lost' && r.status !== 'reunited');
    return { found: found.length, lost: lost.length, all: reports.length };
  }, [reports]);

  // ---- searching (across ALL fields & both types) --------------------------
  const searchResults = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return null; // null = not searching
    return reports.filter((p) =>
      [p.name, p.description, p.last_seen_location, p.client_report_id,
       p.lost_person_id, p.reporter_name, p.reporter_phone]
        .filter(Boolean)
        .some((field) => String(field).toLowerCase().includes(q))
    );
  }, [reports, query]);

  // ---- what the grid shows -------------------------------------------------
  const displayed = useMemo(() => {
    if (searchResults !== null) return searchResults;       // searching
    if (tab === 'all') return reports;
    return reports.filter((r) => r.report_type === tab);
  }, [searchResults, tab, reports]);

  const pickFile = (file) => {
    if (!file) return;
    if (!/^image\/(jpeg|png|webp)$/.test(file.type)) {
      setScanError('Only JPEG, PNG or WebP images are accepted.');
      setScanPhase('error');
      return;
    }
    if (file.size > 8 * 1024 * 1024) {
      setScanError('Photo must be 8 MB or smaller.');
      setScanPhase('error');
      return;
    }
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    setSelectedFile(file);
    setPreviewUrl(URL.createObjectURL(file));
    setScanError('');
    setScanResult(null);
    setScanPhase('idle');
  };

  const handleFiles = (files) => {
    pickFile(files?.[0]);
  };

  const resetScanner = () => {
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    setSelectedFile(null);
    setPreviewUrl('');
    setScanError('');
    setScanResult(null);
    setScanPhase('idle');
    if (fileInputRef.current) fileInputRef.current.value = '';
  };

  const runScan = async () => {
    if (!selectedFile) {
      setScanError('No image selected. Please upload a found-person photograph.');
      setScanPhase('error');
      return;
    }
    setScanPhase('scanning');
    setScanError('');
    setScanResult(null);
    const clientReportId = `ADM-SCAN-${Date.now().toString(36)}`;
    try {
      const result = await scanFaceMatch(selectedFile, {
        reporterName: 'Control Room',
        clientReportId,
      });
      setScanResult(result);
      setScanPhase('complete');
      await loadAll();
      setTab('lost');
    } catch (e) {
      setScanError(e.message || 'Face matching failed.');
      setScanPhase('error');
    } finally {
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  const patchMatchStatus = (matchId, status) => {
    setScanResult((prev) => {
      if (!prev) return prev;
      return {
        ...prev,
        matches: (prev.matches || []).map((m) =>
          m.match_id === matchId ? { ...m, match_status: status, status: status === 'confirmed' ? 'reunited' : m.status } : m
        ),
      };
    });
  };

  const onConfirm = async (match) => {
    if (!match?.match_id) return;
    setActingId(match.match_id);
    try {
      await confirmFaceMatch(match.match_id, 'control-room');
      patchMatchStatus(match.match_id, 'confirmed');
      await loadAll();
      setHighlightId(match.person_id);
      setTab('all');
    } catch (e) {
      setScanError(e.message || 'Could not confirm match.');
    } finally {
      setActingId('');
    }
  };

  const onReject = async (match) => {
    if (!match?.match_id) return;
    setActingId(match.match_id);
    try {
      await rejectFaceMatch(match.match_id, 'control-room');
      patchMatchStatus(match.match_id, 'rejected');
    } catch (e) {
      setScanError(e.message || 'Could not reject match.');
    } finally {
      setActingId('');
    }
  };

  const handleDrag = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === 'dragenter' || e.type === 'dragover') setDragActive(true);
    else if (e.type === 'dragleave' || e.type === 'drop') setDragActive(false);
  };

  const onDrop = (e) => {
    e.preventDefault();
    e.stopPropagation();
    handleFiles(e.dataTransfer.files);
  };

  const searching = searchResults !== null;
  const matches = scanResult?.matches || [];
  const primary = matches[0];
  const others = matches.slice(1);
  const scanning = scanPhase === 'scanning';

  return (
    <div className="flex flex-col xl:flex-row gap-6 h-full">
      {details && <DetailsModal person={details} onClose={() => setDetails(null)} />}
      {assignPerson && (
        <AssignVolunteerModal
          draft={buildLostPersonDraft(assignPerson)}
          onClose={() => setAssignPerson(null)}
          onAssigned={() => {
            setAssignPerson(null);
            loadAll();
          }}
        />
      )}

      {/* Left Column: Upload & Search */}
      <div className="w-full xl:w-1/3 flex flex-col gap-6">
        {/* Upload Card */}
        <div className="bg-white p-6 rounded-2xl border border-orange-100 shadow-sm">
          <div className="flex items-start justify-between gap-3 mb-1">
            <h3 className="text-lg font-bold text-gray-900 tracking-tight">AI LOST-PERSON SCANNER</h3>
            <Sparkles size={18} className="text-orange-500 shrink-0 mt-0.5" />
          </div>
          <p className="text-sm text-gray-500 mb-4">
            Upload a found-person photo. The backend compares the face against
            active missing-person records and returns probable matches — never
            an automatic identity confirmation.
          </p>

          <input
            ref={fileInputRef}
            type="file"
            accept="image/jpeg,image/png,image/webp"
            className="hidden"
            onChange={(e) => handleFiles(e.target.files)}
          />

          <div
            className={`border-2 border-dashed rounded-xl p-6 flex flex-col items-center justify-center text-center transition-all ${
              dragActive
                ? 'border-orange-500 bg-orange-50'
                : 'border-gray-200 bg-gray-50 hover:bg-orange-50/50 hover:border-orange-300'
            }`}
            onDragEnter={handleDrag}
            onDragLeave={handleDrag}
            onDragOver={handleDrag}
            onDrop={onDrop}
          >
            {previewUrl ? (
              <img
                src={previewUrl}
                alt="Found person preview"
                className="w-28 h-28 rounded-xl object-cover mb-3 border border-orange-100 shadow-sm"
              />
            ) : (
              <button
                type="button"
                onClick={() => fileInputRef.current?.click()}
                disabled={scanning}
                className="w-12 h-12 bg-white rounded-full shadow-sm flex items-center justify-center mb-3 cursor-pointer disabled:opacity-60"
                aria-label="Browse files"
              >
                {scanning ? (
                  <Loader2 className="text-orange-500 animate-spin" size={24} />
                ) : (
                  <UploadCloud className="text-orange-500" size={24} />
                )}
              </button>
            )}
            <p className="text-sm font-semibold text-gray-700">
              {selectedFile ? selectedFile.name : 'Upload a found-person photo'}
            </p>
            <p className="text-xs text-gray-400 mt-1">JPEG, PNG, WebP up to 8MB</p>
            <div className="mt-4 flex flex-wrap items-center justify-center gap-2">
              <button
                type="button"
                onClick={() => fileInputRef.current?.click()}
                disabled={scanning}
                className="px-4 py-2 bg-orange-100 text-orange-600 rounded-lg text-sm font-bold hover:bg-orange-200 cursor-pointer transition-colors disabled:opacity-60"
              >
                Browse Files
              </button>
              <button
                type="button"
                onClick={runScan}
                disabled={scanning || !selectedFile}
                className="px-4 py-2 bg-orange-500 text-white rounded-lg text-sm font-bold hover:bg-orange-600 cursor-pointer transition-colors disabled:opacity-60 flex items-center gap-1.5"
              >
                {scanning ? <Loader2 size={16} className="animate-spin" /> : <ScanSearch size={16} />}
                Scan
              </button>
            </div>
            {selectedFile && !scanning && (
              <button
                type="button"
                onClick={resetScanner}
                className="mt-2 text-[11px] text-gray-400 hover:text-gray-600 cursor-pointer"
              >
                Clear photo
              </button>
            )}
          </div>

          {scanning && (
            <div className="mt-4 rounded-xl border border-orange-100 bg-orange-50/70 p-3">
              <div className="flex items-center gap-2 text-sm font-semibold text-orange-700">
                <Loader2 size={16} className="animate-spin" />
                {SCAN_STEPS[scanStep]}
              </div>
              <div className="mt-2 h-1.5 rounded-full bg-orange-100 overflow-hidden">
                <div
                  className="h-full bg-orange-500 transition-all duration-700"
                  style={{ width: `${((scanStep + 1) / SCAN_STEPS.length) * 100}%` }}
                />
              </div>
            </div>
          )}

          {scanError && (
            <p className="mt-3 text-xs font-semibold text-red-600 flex items-start gap-1.5">
              <AlertCircle size={14} className="shrink-0 mt-0.5" />
              {scanError}
            </p>
          )}

          {scanPhase === 'complete' && scanResult && (
            <div className="mt-5 space-y-4">
              <div className="rounded-xl border border-green-200 bg-green-50 p-3">
                <p className="text-sm font-black uppercase tracking-wide text-green-800">
                  AI Analysis Complete
                </p>
                <p className="text-xs text-green-700 mt-1">
                  {scanResult.records_scanned} missing record{scanResult.records_scanned === 1 ? '' : 's'} scanned
                  {' · '}
                  {matches.length} potential match{matches.length === 1 ? '' : 'es'} found
                </p>
              </div>

              {matches.length === 0 && (
                <p className="text-xs font-semibold text-gray-500">
                  {scanResult.message || 'No probable matches found.'}
                </p>
              )}

              {primary && (
                <div className="rounded-xl border border-orange-200 bg-white p-4 shadow-sm">
                  <p className="text-[10px] font-black uppercase tracking-wider text-orange-600 mb-3">
                    Potential match
                  </p>
                  <div className="flex gap-3">
                    <PersonTile name={primary.name} photoUrl={primary.photo_url} />
                    <div className="min-w-0 flex-1">
                      <div className="flex items-start justify-between gap-2">
                        <h4 className="font-bold text-gray-900 truncate">{primary.name}</h4>
                        <StatusBadge person={primary} />
                      </div>
                      <p className="text-sm font-semibold text-gray-800 mt-1">
                        Similarity: {primary.match_score}%
                      </p>
                      <ConfidencePill label={primary.confidence} />
                      <div className="mt-2 space-y-1 text-xs text-gray-500">
                        <div className="flex items-center gap-1.5">
                          <MapPin size={12} /> {primary.location || 'Location not recorded'}
                        </div>
                        <div className="flex items-center gap-1.5">
                          <Clock size={12} /> Missing for:{' '}
                          {primary.missing_for || missingFor(primary.last_seen_time)}
                        </div>
                      </div>
                    </div>
                  </div>

                  {primary.match_status === 'confirmed' && (
                    <p className="mt-3 text-xs font-bold text-green-700">Match confirmed — record marked reunited.</p>
                  )}
                  {primary.match_status === 'rejected' && (
                    <p className="mt-3 text-xs font-bold text-gray-500">Match rejected. Person status unchanged.</p>
                  )}

                  <div className="mt-4 grid grid-cols-3 gap-2">
                    <button
                      type="button"
                      onClick={() => setDetails(primary)}
                      className="py-2 rounded-lg text-xs font-bold border border-gray-200 text-gray-700 hover:bg-gray-50 cursor-pointer flex items-center justify-center gap-1"
                    >
                      <Eye size={13} /> View Details
                    </button>
                    <button
                      type="button"
                      disabled={actingId === primary.match_id || primary.match_status !== 'pending'}
                      onClick={() => onConfirm(primary)}
                      className="py-2 rounded-lg text-xs font-bold bg-green-600 text-white hover:bg-green-700 cursor-pointer disabled:opacity-50 flex items-center justify-center gap-1"
                    >
                      {actingId === primary.match_id ? <Loader2 size={13} className="animate-spin" /> : <Check size={13} />}
                      Confirm Match
                    </button>
                    <button
                      type="button"
                      disabled={actingId === primary.match_id || primary.match_status !== 'pending'}
                      onClick={() => onReject(primary)}
                      className="py-2 rounded-lg text-xs font-bold bg-white border border-red-200 text-red-600 hover:bg-red-50 cursor-pointer disabled:opacity-50 flex items-center justify-center gap-1"
                    >
                      <X size={13} /> Reject
                    </button>
                  </div>
                </div>
              )}

              {others.length > 0 && (
                <div>
                  <p className="text-[10px] font-black uppercase tracking-wider text-gray-500 mb-2">
                    Other possible matches
                  </p>
                  <div className="space-y-2">
                    {others.map((m) => (
                      <div
                        key={m.match_id || m.person_id}
                        className="flex items-center gap-3 border border-gray-100 rounded-xl p-2.5"
                      >
                        <PersonTile name={m.name} photoUrl={m.photo_url} />
                        <div className="min-w-0 flex-1">
                          <p className="text-sm font-bold text-gray-900 truncate">{m.name}</p>
                          <p className="text-[11px] text-gray-500">
                            Similarity {m.match_score}% · {m.status} · {m.location || '—'}
                          </p>
                          {m.match_status && m.match_status !== 'pending' && (
                            <p className="text-[10px] font-bold uppercase text-gray-400">{m.match_status}</p>
                          )}
                        </div>
                        <button
                          type="button"
                          onClick={() => setDetails(m)}
                          className="px-2 py-1 text-[11px] font-bold text-orange-600 hover:bg-orange-50 rounded-lg cursor-pointer"
                        >
                          View
                        </button>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              <p className="text-[11px] text-gray-400 flex items-start gap-1.5">
                <ShieldAlert size={12} className="mt-0.5 shrink-0" />
                {scanResult.disclaimer ||
                  'Probable matches only. An authority must confirm identity before a record is updated.'}
              </p>
            </div>
          )}
        </div>

        {/* Manual Search Card */}
        <div className="bg-white p-6 rounded-2xl border border-orange-100 shadow-sm flex-1">
          <h3 className="text-lg font-bold text-gray-900 mb-4">Manual Search</h3>
          <div className="space-y-3">
            <div className="relative">
              <Search size={18} className="absolute left-3 top-3 text-gray-400" />
              <input
                type="text"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="Search name, ID, description, location, phone..."
                className="w-full pl-10 pr-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl text-sm focus:outline-none focus:border-orange-500 focus:ring-1 focus:ring-orange-500"
              />
            </div>
            <p className="text-[11px] text-gray-400">
              Searches across ALL reports (lost &amp; found). Results appear on the right.
            </p>
            {searching && (
              <button
                onClick={() => setQuery('')}
                className="w-full py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-xl text-sm font-bold cursor-pointer transition-colors"
              >
                Clear search ({searchResults.length} match{searchResults.length === 1 ? '' : 'es'})
              </button>
            )}
          </div>
          <p className="mt-4 text-[11px] text-gray-400">
            Backend: <code>{API_BASE || '(same origin / Vite proxy)'}</code>
          </p>
        </div>
      </div>

      {/* Right Column: reports / search results */}
      <div className="w-full xl:w-2/3 bg-white p-6 rounded-2xl border border-orange-100 shadow-sm flex flex-col">
        <div className="flex justify-between items-start mb-4 gap-3 flex-wrap">
          <div>
            <h3 className="text-lg font-bold text-gray-900">
              {searching ? 'Search Results' : 'Persons Database'}
            </h3>
            <p className="text-sm text-gray-500">
              {searching
                ? `Across all reports — ${displayed.length} match${displayed.length === 1 ? '' : 'es'}`
                : 'Live from the backend (app reports + control-room uploads)'}
            </p>
          </div>
          {!searching && (
            <span className="bg-orange-100 text-orange-700 text-xs font-bold px-3 py-1 rounded-full flex items-center gap-1">
              <Users size={13} /> {counts.all} total
            </span>
          )}
        </div>

        {/* Filter tabs (hidden while searching) */}
        {!searching && (
          <div className="flex gap-2 mb-5">
            {TABS.map((t) => {
              const active = tab === t.key;
              const count = t.key === 'found' ? counts.found : t.key === 'lost' ? counts.lost : counts.all;
              return (
                <button
                  key={t.key}
                  onClick={() => setTab(t.key)}
                  className={`px-4 py-1.5 rounded-full text-xs font-bold cursor-pointer transition-colors border ${
                    active
                      ? 'bg-orange-500 text-white border-orange-500'
                      : 'bg-white text-gray-600 border-gray-200 hover:border-orange-300'
                  }`}
                >
                  {t.label}
                  <span className={`ml-1.5 ${active ? 'text-orange-100' : 'text-gray-400'}`}>
                    {count}
                  </span>
                </button>
              );
            })}
          </div>
        )}

        {loading ? (
          <div className="flex flex-col items-center justify-center py-20 text-gray-400">
            <Loader2 className="animate-spin mb-3" size={28} />
            <p className="text-sm">Loading from the backend…</p>
          </div>
        ) : error ? (
          <div className="flex flex-col items-center justify-center py-20 text-red-500 text-center">
            <AlertCircle className="mb-3" size={28} />
            <p className="text-sm font-semibold">{error}</p>
            <button
              onClick={loadAll}
              className="mt-4 px-4 py-2 bg-orange-100 text-orange-600 rounded-lg text-sm font-bold hover:bg-orange-200 cursor-pointer"
            >
              Retry
            </button>
          </div>
        ) : displayed.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 text-gray-400 text-center">
            <User className="mb-3" size={28} />
            <p className="text-sm font-semibold">
              {searching ? 'No reports match your search.' : 'Nothing in this category yet.'}
            </p>
            <p className="text-xs mt-1">
              {searching
                ? 'Try a different name, ID, location or description.'
                : tab === 'lost'
                  ? 'Missing-person reports from the pilgrim app will appear here.'
                  : 'Found-person reports and uploads will appear here.'}
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {displayed.map((person) => (
              <PersonCard
                key={person.lost_person_id || person.client_report_id}
                person={person}
                highlight={highlightId && person.lost_person_id === highlightId}
                assignedTask={personTasks[person.lost_person_id]}
                onAssign={(p) => setAssignPerson(p)}
              />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

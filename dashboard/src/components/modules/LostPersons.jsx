import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  UploadCloud, Search, User, MapPin, Clock, AlertCircle, Loader2, Users,
} from 'lucide-react';

import {
  API_BASE,
  createPersonReport,
  initials,
  listReports,
  resolvePhotoUrl,
  timeAgo,
  uploadPersonPhoto,
} from '../../lib/api';

// Photo tile with an orange initials fallback when no photo exists.
function PersonTile({ name, photoUrl }) {
  const [broken, setBroken] = useState(false);
  const src = resolvePhotoUrl(photoUrl);
  if (!src || broken) {
    return (
      <div className="w-20 h-20 rounded-lg bg-orange-500 text-white text-2xl font-black flex items-center justify-center shrink-0">
        {initials(name)}
      </div>
    );
  }
  return (
    <img
      src={src}
      alt={name}
      onError={() => setBroken(true)}
      className="w-20 h-20 rounded-lg object-cover bg-gray-100 shrink-0"
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
  return person.report_type === 'found' ? (
    <span className="text-[10px] font-black uppercase px-2 py-0.5 rounded border text-green-600 bg-green-50 border-green-200">
      Found
    </span>
  ) : (
    <span className="text-[10px] font-black uppercase px-2 py-0.5 rounded border text-orange-600 bg-orange-50 border-orange-200">
      Missing
    </span>
  );
}

function PersonCard({ person }) {
  return (
    <div className="border border-gray-100 rounded-xl p-4 flex gap-4 hover:shadow-md transition-shadow">
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

  const [uploading, setUploading] = useState(false);
  const [uploadMsg, setUploadMsg] = useState('');
  const [uploadError, setUploadError] = useState('');

  const [tab, setTab] = useState('found');
  const [query, setQuery] = useState('');

  // ---- load every report once (lost + found) ------------------------------
  const loadAll = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const all = await listReports({}); // no filter -> the whole database
      setReports(all);
    } catch (e) {
      setError(e.message || 'Could not load reports from the backend.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadAll();
  }, [loadAll]);

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

  // ---- upload (logs a found person with the uploaded photo) ---------------
  const handleFiles = async (files) => {
    const file = files?.[0];
    if (!file) return;
    if (!/^image\/(jpeg|png|webp)$/.test(file.type)) {
      setUploadError('Only JPEG, PNG or WebP images are accepted.');
      return;
    }
    if (file.size > 8 * 1024 * 1024) {
      setUploadError('Photo must be 8 MB or smaller.');
      return;
    }

    setUploading(true);
    setUploadMsg('');
    setUploadError('');
    const clientReportId = `ADM-FOUND-${Date.now().toString(36)}`;
    try {
      const { photo_url: photoUrl } = await uploadPersonPhoto(file, clientReportId);
      await createPersonReport({
        client_report_id: clientReportId,
        report_type: 'found',
        name: 'Unidentified person',
        description: 'Logged by control room (pending AI face match).',
        last_seen_location: 'Control room upload',
        photo_url: photoUrl,
        reporter_name: 'Control Room',
      });
      setUploadMsg('Photo uploaded and logged as a found person.');
      await loadAll();
      setTab('found');
    } catch (e) {
      setUploadError(e.message || 'Upload failed.');
    } finally {
      setUploading(false);
      if (fileInputRef.current) fileInputRef.current.value = '';
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

  return (
    <div className="flex flex-col xl:flex-row gap-6 h-full">
      {/* Left Column: Upload & Search */}
      <div className="w-full xl:w-1/3 flex flex-col gap-6">
        {/* Upload Card */}
        <div className="bg-white p-6 rounded-2xl border border-orange-100 shadow-sm">
          <h3 className="text-lg font-bold text-gray-900 mb-1">AI Face Match</h3>
          <p className="text-sm text-gray-500 mb-4">
            Upload a found-person photo — it is stored with the same pipeline the
            pilgrim app uses and added to the found list.
          </p>

          <input
            ref={fileInputRef}
            type="file"
            accept="image/jpeg,image/png,image/webp"
            className="hidden"
            onChange={(e) => handleFiles(e.target.files)}
          />

          <div
            className={`border-2 border-dashed rounded-xl p-8 flex flex-col items-center justify-center text-center transition-all ${
              dragActive
                ? 'border-orange-500 bg-orange-50'
                : 'border-gray-200 bg-gray-50 hover:bg-orange-50/50 hover:border-orange-300'
            }`}
            onDragEnter={handleDrag}
            onDragLeave={handleDrag}
            onDragOver={handleDrag}
            onDrop={onDrop}
          >
            <button
              type="button"
              onClick={() => fileInputRef.current?.click()}
              disabled={uploading}
              className="w-12 h-12 bg-white rounded-full shadow-sm flex items-center justify-center mb-3 cursor-pointer disabled:opacity-60"
              aria-label="Browse files"
            >
              {uploading ? (
                <Loader2 className="text-orange-500 animate-spin" size={24} />
              ) : (
                <UploadCloud className="text-orange-500" size={24} />
              )}
            </button>
            <p className="text-sm font-semibold text-gray-700">
              {uploading ? 'Uploading…' : 'Click or drag photo here'}
            </p>
            <p className="text-xs text-gray-400 mt-1">JPEG, PNG, WebP up to 8MB</p>
            <button
              type="button"
              onClick={() => fileInputRef.current?.click()}
              disabled={uploading}
              className="mt-4 px-4 py-2 bg-orange-100 text-orange-600 rounded-lg text-sm font-bold hover:bg-orange-200 cursor-pointer transition-colors disabled:opacity-60"
            >
              Browse Files
            </button>
          </div>

          {uploadMsg && <p className="mt-3 text-xs font-semibold text-green-600">{uploadMsg}</p>}
          {uploadError && <p className="mt-3 text-xs font-semibold text-red-600">{uploadError}</p>}
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
            Backend: <code>{API_BASE}</code>
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
              />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

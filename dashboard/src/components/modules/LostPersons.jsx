import React, { useCallback, useEffect, useRef, useState } from 'react';
import { UploadCloud, Search, User, MapPin, Clock, AlertCircle, Loader2 } from 'lucide-react';

import {
  API_BASE,
  activeCases,
  createPersonReport,
  initials,
  listReports,
  resolvePhotoUrl,
  timeAgo,
  uploadPersonPhoto,
} from '../../lib/api';

// Tile shown when a report has no photo — orange initials block, matching
// the dashboard's CH/EL avatar style.
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

function PersonCard({ person, badge }) {
  const status = person.status;
  const badgeEl = badge ?? (
    <span
      className={`text-[10px] font-black uppercase px-2 py-0.5 rounded border ${
        status === 'reunited'
          ? 'text-blue-600 bg-blue-50 border-blue-200'
          : 'text-green-600 bg-green-50 border-green-200'
      }`}
    >
      {status === 'reunited' ? 'Reunited' : 'Found'}
    </span>
  );

  return (
    <div className="border border-gray-100 rounded-xl p-4 flex gap-4 hover:shadow-md transition-shadow">
      <PersonTile name={person.name} photoUrl={person.photo_url} />
      <div className="flex-1 min-w-0">
        <div className="flex justify-between items-start gap-2">
          <h4 className="font-bold text-gray-900 truncate">{person.name}</h4>
          {badgeEl}
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

export default function LostPersons() {
  const [dragActive, setDragActive] = useState(false);
  const fileInputRef = useRef(null);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [foundPersons, setFoundPersons] = useState([]);

  const [uploading, setUploading] = useState(false);
  const [uploadMsg, setUploadMsg] = useState('');
  const [uploadError, setUploadError] = useState('');

  const [query, setQuery] = useState('');
  const [searching, setSearching] = useState(false);
  const [results, setResults] = useState(null); // null = not searching yet

  // ---- data ---------------------------------------------------------------
  const loadFound = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const reports = await listReports({ reportType: 'found' });
      setFoundPersons(activeCases(reports));
    } catch (e) {
      setError(e.message || 'Could not load found persons.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadFound();
  }, [loadFound]);

  // ---- upload (logs a found person, with the uploaded photo) --------------
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
      // Same photo endpoint the Flutter app uses.
      const { photo_url: photoUrl } = await uploadPersonPhoto(file, clientReportId);
      // Log the found person so it appears in the database/feed.
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
      await loadFound();
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

  // ---- manual search ------------------------------------------------------
  const runSearch = async () => {
    const q = query.trim().toLowerCase();
    if (!q) {
      setResults(null);
      return;
    }
    setSearching(true);
    try {
      const all = await listReports({}); // lost + found, for reconciliation
      const matches = all.filter((p) =>
        [p.name, p.description, p.last_seen_location, p.client_report_id, p.lost_person_id]
          .filter(Boolean)
          .some((field) => String(field).toLowerCase().includes(q))
      );
      setResults(matches);
    } catch (e) {
      setError(e.message || 'Search failed.');
      setResults([]);
    } finally {
      setSearching(false);
    }
  };

  const clearSearch = () => {
    setQuery('');
    setResults(null);
  };

  const displayed = results ?? foundPersons;

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
          <div className="space-y-4">
            <div className="relative">
              <Search size={18} className="absolute left-3 top-3 text-gray-400" />
              <input
                type="text"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && runSearch()}
                placeholder="Search by name, ID, or description..."
                className="w-full pl-10 pr-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl text-sm focus:outline-none focus:border-orange-500 focus:ring-1 focus:ring-orange-500"
              />
            </div>
            <div className="flex gap-2">
              <button
                onClick={runSearch}
                disabled={searching}
                className="flex-1 py-2.5 bg-gray-900 hover:bg-gray-800 text-white rounded-xl text-sm font-bold cursor-pointer transition-colors disabled:opacity-60"
              >
                {searching ? 'Searching…' : 'Search Database'}
              </button>
              {results !== null && (
                <button
                  onClick={clearSearch}
                  className="px-4 py-2.5 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-xl text-sm font-bold cursor-pointer transition-colors"
                >
                  Clear
                </button>
              )}
            </div>
          </div>
          <p className="mt-3 text-[11px] text-gray-400">
            Backend: <code>{API_BASE}</code>
          </p>
        </div>
      </div>

      {/* Right Column: Found persons / search results */}
      <div className="w-full xl:w-2/3 bg-white p-6 rounded-2xl border border-orange-100 shadow-sm flex flex-col">
        <div className="flex justify-between items-center mb-6">
          <div>
            <h3 className="text-lg font-bold text-gray-900">
              {results !== null ? 'Search Results' : 'Recent Found Persons'}
            </h3>
            <p className="text-sm text-gray-500">
              {results !== null
                ? 'Matches across lost & found reports'
                : 'Awaiting family verification — pulled live from the backend'}
            </p>
          </div>
          {results === null && (
            <span className="bg-orange-100 text-orange-700 text-xs font-bold px-3 py-1 rounded-full">
              {foundPersons.length} Active Cases
            </span>
          )}
        </div>

        {loading ? (
          <div className="flex flex-col items-center justify-center py-20 text-gray-400">
            <Loader2 className="animate-spin mb-3" size={28} />
            <p className="text-sm">Loading from the backend…</p>
          </div>
        ) : error && results === null ? (
          <div className="flex flex-col items-center justify-center py-20 text-red-500 text-center">
            <AlertCircle className="mb-3" size={28} />
            <p className="text-sm font-semibold">{error}</p>
            <button
              onClick={loadFound}
              className="mt-4 px-4 py-2 bg-orange-100 text-orange-600 rounded-lg text-sm font-bold hover:bg-orange-200 cursor-pointer"
            >
              Retry
            </button>
          </div>
        ) : displayed.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 text-gray-400 text-center">
            <User className="mb-3" size={28} />
            <p className="text-sm font-semibold">
              {results !== null ? 'No reports match your search.' : 'No found persons yet.'}
            </p>
            <p className="text-xs mt-1">
              {results !== null
                ? 'Try a different name, ID or description.'
                : 'Reports created in the pilgrim app or uploaded above appear here.'}
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {displayed.map((person) => (
              <PersonCard
                key={person.lost_person_id || person.client_report_id}
                person={person}
                badge={
                  results !== null ? (
                    <span
                      className={`text-[10px] font-black uppercase px-2 py-0.5 rounded border ${
                        person.report_type === 'found'
                          ? 'text-green-600 bg-green-50 border-green-200'
                          : 'text-orange-600 bg-orange-50 border-orange-200'
                      }`}
                    >
                      {person.report_type === 'found' ? 'Found' : 'Missing'}
                    </span>
                  ) : undefined
                }
              />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
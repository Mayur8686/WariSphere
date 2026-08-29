import React, { useCallback, useMemo, useState } from 'react';
import {
  Users, UserCheck, UserX, WifiOff, ClipboardList, Loader2,
  AlertCircle, Plus, RefreshCw, Phone,
} from 'lucide-react';
import { listTasks, listVolunteers, timeAgo } from '../../lib/api';
import { useLiveCollection } from '../../lib/live';
import { AvailabilityBadge, SkillChip, VolunteerStatusBadge } from '../tasks/badges';
import CreateVolunteerModal from '../volunteers/CreateVolunteerModal';
import VolunteerDetails from '../volunteers/VolunteerDetails';

const EMPTY_SUMMARY = { total: 0, active: 0, available: 0, busy: 0, offline: 0, on_tasks: 0 };

function StatCard({ icon, label, value, tone }) {
  return (
    <div className="bg-white px-4 py-3 rounded-2xl border border-orange-100 shadow-sm flex items-center gap-3 min-w-[130px] flex-1">
      <div className={`w-9 h-9 rounded-xl flex items-center justify-center shrink-0 ${tone}`}>
        {icon}
      </div>
      <div>
        <p className="text-xl font-black text-gray-900 leading-none">{value}</p>
        <p className="text-[10px] text-gray-400 uppercase tracking-wider font-bold mt-1">{label}</p>
      </div>
    </div>
  );
}

export default function Volunteers() {
  const [creating, setCreating] = useState(false);
  const [selectedUid, setSelectedUid] = useState(null);

  const fetchVolunteers = useCallback(async () => (await listVolunteers({})).volunteers, []);
  const fetchActiveTasks = useCallback(async () => {
    const { tasks } = await listTasks({ view: 'active', limit: 500 });
    return tasks;
  }, []);

  const { data: volunteers, loading, error, refresh, source } = useLiveCollection(
    'volunteers',
    fetchVolunteers,
    { pollMs: 6000 },
  );
  const { data: activeTasks } = useLiveCollection('tasks', fetchActiveTasks, { pollMs: 6000 });

  const ACTIVE_STATUSES = ['assigned', 'accepted', 'in_progress'];
  const taskByVolunteer = useMemo(() => {
    const map = {};
    for (const t of activeTasks) {
      if (!t.assigned_to || map[t.assigned_to]) continue;
      if (!ACTIVE_STATUSES.includes(t.status)) continue;
      map[t.assigned_to] = t;
    }
    return map;
  }, [activeTasks]);

  const rows = useMemo(
    () => volunteers.map((v) => ({
      ...v,
      current_task: v.current_task || taskByVolunteer[v.uid] || null,
    })),
    [volunteers, taskByVolunteer],
  );

  const summary = useMemo(() => {
    const s = { ...EMPTY_SUMMARY, total: rows.length };
    for (const v of rows) {
      if (v.status === 'active') s.active += 1;
      if (v.availability === 'available') s.available += 1;
      if (v.availability === 'busy') s.busy += 1;
      if (v.availability === 'offline') s.offline += 1;
      if (v.current_task) s.on_tasks += 1;
    }
    return s;
  }, [rows]);

  const selected = useMemo(
    () => rows.find((v) => v.uid === selectedUid) || null,
    [rows, selectedUid],
  );

  return (
    <div className="flex flex-col gap-6 h-full">
      {creating && (
        <CreateVolunteerModal
          onClose={() => setCreating(false)}
          onCreated={() => refresh()}
        />
      )}
      {selected && (
        <VolunteerDetails
          volunteer={selected}
          onClose={() => setSelectedUid(null)}
          onChanged={() => refresh()}
        />
      )}

      {/* header + stats */}
      <div className="flex flex-col gap-4">
        <div className="flex flex-wrap justify-between items-center gap-3 bg-white p-6 rounded-2xl border border-orange-100 shadow-sm">
          <div>
            <h3 className="text-lg font-bold text-gray-900">Volunteer Management</h3>
            <p className="text-sm text-gray-500">
              Create accounts, track availability and monitor live task assignments
              {source === 'firestore' ? ' (real-time)' : ' (live sync)'}
            </p>
          </div>
          <div className="flex gap-2">
            <button
              onClick={() => refresh()}
              className="px-3 py-2.5 rounded-xl border border-gray-200 text-gray-500 hover:bg-gray-50 cursor-pointer transition-colors"
              title="Refresh"
            >
              <RefreshCw size={16} />
            </button>
            <button
              onClick={() => setCreating(true)}
              className="bg-orange-500 hover:bg-orange-600 text-white px-4 py-2.5 rounded-xl text-sm font-bold cursor-pointer transition-colors shadow-sm shadow-orange-200 flex items-center gap-1.5"
            >
              <Plus size={16} /> Create Volunteer
            </button>
          </div>
        </div>

        <div className="flex flex-wrap gap-3">
          <StatCard icon={<Users size={18} className="text-orange-600" />} label="Total" value={summary.total} tone="bg-orange-100" />
          <StatCard icon={<UserCheck size={18} className="text-green-600" />} label="Available" value={summary.available} tone="bg-green-100" />
          <StatCard icon={<ClipboardList size={18} className="text-amber-600" />} label="Busy" value={summary.busy} tone="bg-amber-100" />
          <StatCard icon={<WifiOff size={18} className="text-gray-500" />} label="Offline" value={summary.offline} tone="bg-gray-100" />
          <StatCard icon={<UserX size={18} className="text-red-500" />} label="On Tasks" value={summary.on_tasks} tone="bg-red-50" />
        </div>
      </div>

      {/* table */}
      <div className="bg-white rounded-2xl border border-orange-100 shadow-sm overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center gap-2 py-16 text-gray-400">
            <Loader2 className="animate-spin" size={20} /> Loading volunteers…
          </div>
        ) : error && rows.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 text-red-500 gap-2">
            <AlertCircle size={22} />
            <p className="text-sm font-semibold">{error}</p>
          </div>
        ) : rows.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 text-gray-400 gap-2 text-center">
            <Users size={24} />
            <p className="text-sm font-semibold">No volunteers yet</p>
            <p className="text-xs">Click “Create Volunteer” to provision the first account.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse min-w-[860px]">
              <thead>
                <tr className="bg-orange-50/50 border-b border-orange-100 text-xs uppercase font-bold text-gray-500">
                  <th className="p-4">Name</th>
                  <th className="p-4">Status</th>
                  <th className="p-4">Availability</th>
                  <th className="p-4">Skills</th>
                  <th className="p-4">Current Task</th>
                  <th className="p-4 text-center">Completed</th>
                  <th className="p-4">Last Active</th>
                  <th className="p-4 text-right">Contact</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100 text-sm">
                {rows.map((v) => (
                  <tr
                    key={v.uid}
                    onClick={() => setSelectedUid(v.uid)}
                    className="hover:bg-orange-50/40 transition-colors cursor-pointer"
                  >
                    <td className="p-4 font-bold text-gray-900">
                      <div className="flex items-center gap-3">
                        <div className="w-9 h-9 bg-orange-100 text-orange-600 rounded-full flex items-center justify-center font-bold text-xs shrink-0">
                          {(v.name || '?').charAt(0)}
                        </div>
                        <div>
                          <p>{v.name}</p>
                          <p className="text-[11px] text-gray-400 font-medium">{v.zone || '—'}</p>
                        </div>
                      </div>
                    </td>
                    <td className="p-4"><VolunteerStatusBadge status={v.status} /></td>
                    <td className="p-4"><AvailabilityBadge availability={v.availability} /></td>
                    <td className="p-4">
                      <div className="flex flex-wrap gap-1 max-w-[200px]">
                        {(v.skills || []).slice(0, 2).map((s) => <SkillChip key={s} label={s} />)}
                        {(v.skills || []).length > 2 && (
                          <span className="text-[10px] text-gray-400 font-bold">+{v.skills.length - 2}</span>
                        )}
                      </div>
                    </td>
                    <td className="p-4">
                      {v.current_task ? (
                        <span className="inline-flex items-center gap-1.5 text-xs font-bold text-purple-700 bg-purple-50 border border-purple-200 rounded-full px-2.5 py-1">
                          <ClipboardList size={11} /> {v.current_task.title}
                        </span>
                      ) : (
                        <span className="text-xs text-gray-400">No active task</span>
                      )}
                    </td>
                    <td className="p-4 text-center font-black text-green-700">{v.tasks_completed ?? 0}</td>
                    <td className="p-4 text-xs text-gray-500">{v.last_active_at ? timeAgo(v.last_active_at) : '—'}</td>
                    <td className="p-4 text-right">
                      {v.phone ? (
                        <a
                          href={`tel:${v.phone}`}
                          onClick={(e) => e.stopPropagation()}
                          className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-gray-50 hover:bg-orange-100 text-gray-700 hover:text-orange-600 rounded-lg text-xs font-bold cursor-pointer transition-colors border border-gray-200"
                        >
                          <Phone size={12} /> Call
                        </a>
                      ) : (
                        <span className="text-xs text-gray-300">—</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

import React, { useMemo, useState } from 'react';
import { MapPin } from 'lucide-react';
import { durationLabel, fmtTime, taskTypeLabel, timeAgo } from '../lib/api';
import { PriorityBadge, TaskStatusBadge } from './tasks/badges';
import TaskCard from './TaskCard';

const ACTIVE_STATUSES = ['assigned', 'accepted', 'in_progress'];

const TABS = [
  { key: 'active', label: 'Active' },
  { key: 'completed', label: 'Completed' },
  { key: 'all', label: 'All' },
];

function HistoryRow({ task }) {
  return (
    <div className="bg-white rounded-2xl border border-orange-100 shadow-sm p-4 flex flex-col sm:flex-row sm:items-center gap-3">
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2 flex-wrap">
          <span className="text-[10px] font-black uppercase tracking-wider text-orange-600">
            {taskTypeLabel(task.type)}
          </span>
          <PriorityBadge priority={task.priority} />
          <TaskStatusBadge status={task.status} />
        </div>
        <h4 className="font-bold text-gray-900 mt-1.5 truncate">{task.title}</h4>
        <p className="text-xs text-gray-500 mt-0.5 flex items-center gap-1">
          <MapPin size={11} className="text-orange-400" />
          {task.location?.address || 'No address recorded'}
        </p>
        {task.completion_note && (
          <p className="text-xs text-gray-500 italic mt-1">“{task.completion_note}”</p>
        )}
      </div>
      <div className="grid grid-cols-3 sm:grid-cols-1 gap-x-4 gap-y-1 text-[11px] text-gray-500 sm:text-right shrink-0">
        <p><span className="font-bold text-gray-400">Assigned</span><br />{fmtTime(task.assigned_at || task.created_at)}</p>
        <p><span className="font-bold text-gray-400">Started</span><br />{task.started_at ? fmtTime(task.started_at) : '—'}</p>
        <p>
          <span className="font-bold text-gray-400">Completed</span><br />
          {task.completed_at
            ? `${timeAgo(task.completed_at)}${task.response_seconds != null ? ` (${durationLabel(task.response_seconds)})` : ''}`
            : '—'}
        </p>
      </div>
    </div>
  );
}

export default function TaskHistory({ tasks, newTaskIds, onTasksChanged }) {
  const [tab, setTab] = useState('active');

  const counts = useMemo(
    () => ({
      active: tasks.filter((t) => ACTIVE_STATUSES.includes(t.status)).length,
      completed: tasks.filter((t) => t.status === 'completed').length,
      all: tasks.length,
    }),
    [tasks],
  );

  const visible = useMemo(() => {
    let rows = tasks;
    if (tab === 'active') rows = tasks.filter((t) => ACTIVE_STATUSES.includes(t.status));
    else if (tab === 'completed') rows = tasks.filter((t) => t.status === 'completed');
    return [...rows].sort((a, b) => String(b.created_at || '').localeCompare(String(a.created_at || '')));
  }, [tasks, tab]);

  const activeTasks = tab === 'active' ? visible : [];

  return (
    <div className="flex flex-col gap-4">
      <div className="flex gap-2">
        {TABS.map((t) => {
          const active = tab === t.key;
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
              <span className={`ml-1.5 ${active ? 'text-orange-100' : 'text-gray-400'}`}>{counts[t.key]}</span>
            </button>
          );
        })}
      </div>

      {visible.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-16 text-gray-400 text-center">
          <p className="text-sm font-semibold">Nothing in this view yet.</p>
          <p className="text-xs mt-1">
            {tab === 'active'
              ? 'Tasks assigned by the control room appear here instantly.'
              : 'Finished tasks land in your history.'}
          </p>
        </div>
      ) : tab === 'active' ? (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
          {activeTasks.map((task) => (
            <TaskCard
              key={task.task_id}
              task={task}
              isNew={newTaskIds.has(task.task_id)}
              onChanged={onTasksChanged}
            />
          ))}
        </div>
      ) : (
        <div className="flex flex-col gap-3">
          {visible.map((task) => (
            <HistoryRow key={task.task_id} task={task} />
          ))}
        </div>
      )}
    </div>
  );
}

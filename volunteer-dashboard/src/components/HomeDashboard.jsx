import React, { useMemo } from 'react';
import TaskCard from './TaskCard';
import { AvailabilityBadge } from './tasks/badges';

const ACTIVE_STATUSES = ['assigned', 'accepted', 'in_progress'];

function Stat({ label, value, tone = 'text-gray-900' }) {
  return (
    <div className="bg-white px-4 py-3.5 rounded-2xl border border-orange-100 shadow-sm flex flex-col items-center flex-1 min-w-[110px]">
      <span className="text-[10px] text-gray-400 uppercase tracking-wider font-bold mb-1 text-center">{label}</span>
      <span className={`text-2xl font-black ${tone}`}>{value}</span>
    </div>
  );
}

export default function HomeDashboard({ profile, tasks, newTaskIds, onTasksChanged, goToTasks }) {
  const active = useMemo(
    () => tasks.filter((t) => ACTIVE_STATUSES.includes(t.status)),
    [tasks],
  );
  const completedToday = useMemo(() => {
    const today = new Date().toDateString();
    return tasks.filter(
      (t) => t.status === 'completed' && t.completed_at && new Date(t.completed_at).toDateString() === today,
    ).length;
  }, [tasks]);
  const highPriority = active.filter((t) => t.priority === 'high' || t.priority === 'critical').length;

  const availability = profile?.availability || 'offline';

  return (
    <div className="flex flex-col gap-6">
      {/* welcome + status */}
      <div className="bg-white rounded-2xl border border-orange-100 shadow-sm p-6 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h3 className="text-2xl font-bold text-gray-900">
            Welcome, {(profile?.name || 'Volunteer').split(' ')[0]} 🙏
          </h3>
          <div className="flex items-center gap-2 mt-2">
            <span className="text-xs text-gray-400 font-bold uppercase tracking-wider">Status:</span>
            <AvailabilityBadge availability={availability} />
          </div>
        </div>
        <div className="flex flex-wrap gap-2 sm:gap-3">
          <Stat label="Active Tasks" value={active.length} tone={active.length ? 'text-orange-600' : 'text-gray-900'} />
          <Stat label="Completed Today" value={completedToday} tone="text-green-600" />
          <Stat label="High Priority" value={highPriority} tone={highPriority ? 'text-red-600' : 'text-gray-900'} />
        </div>
      </div>

      {/* active tasks */}
      <div>
        <div className="flex items-center justify-between mb-3">
          <h4 className="text-lg font-bold text-gray-900">Your Active Tasks</h4>
          {active.length > 0 && (
            <button onClick={goToTasks} className="text-xs font-bold text-orange-600 hover:text-orange-700 cursor-pointer">
              View all →
            </button>
          )}
        </div>
        {active.length === 0 ? (
          <div className="border-2 border-dashed border-green-200 rounded-3xl bg-green-50/50 p-10 text-center">
            <h3 className="text-xl font-bold text-green-800 mb-1">All Clear 🟢</h3>
            <p className="text-green-600 text-sm">
              No tasks assigned right now. The control room can dispatch you the moment something
              comes up — this page updates automatically.
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
            {active.map((task) => (
              <TaskCard
                key={task.task_id}
                task={task}
                isNew={newTaskIds.has(task.task_id)}
                onChanged={onTasksChanged}
              />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

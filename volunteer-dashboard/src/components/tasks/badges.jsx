import React from 'react';

// Consistent status language across both portals:
//   HIGH/CRITICAL → red alert · available → green · busy → amber
//   offline → neutral gray · completed/resolved → green success
//   in-flight dispatches → blue · stale/closed → gray

const PILL = 'inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[10px] font-black uppercase tracking-wider border';

export function PriorityBadge({ priority }) {
  const map = {
    critical: 'bg-red-600 text-white border-red-700 animate-pulse',
    high: 'bg-red-50 text-red-700 border-red-200',
    medium: 'bg-amber-50 text-amber-700 border-amber-200',
    low: 'bg-gray-50 text-gray-600 border-gray-200',
  };
  return (
    <span className={`${PILL} ${map[priority] || map.low}`}>
      {(priority === 'high' || priority === 'critical') && '🚨 '}
      {priority || 'low'} priority
    </span>
  );
}

export function TaskStatusBadge({ status }) {
  const map = {
    assigned: 'bg-purple-50 text-purple-700 border-purple-200',
    accepted: 'bg-blue-50 text-blue-700 border-blue-200',
    in_progress: 'bg-orange-50 text-orange-700 border-orange-200',
    completed: 'bg-green-50 text-green-700 border-green-200',
    rejected: 'bg-gray-100 text-gray-600 border-gray-200',
    cancelled: 'bg-gray-100 text-gray-500 border-gray-200',
    unable_to_complete: 'bg-red-50 text-red-700 border-red-200',
  };
  const labels = {
    in_progress: 'In Progress',
    unable_to_complete: 'Unable to Complete',
  };
  return (
    <span className={`${PILL} ${map[status] || 'bg-gray-50 text-gray-600 border-gray-200'}`}>
      {labels[status] || (status ? status.charAt(0).toUpperCase() + status.slice(1) : '—')}
    </span>
  );
}

export function AvailabilityBadge({ availability }) {
  const map = {
    available: ['bg-green-50 text-green-700 border-green-200', '🟢'],
    busy: ['bg-amber-50 text-amber-700 border-amber-200', '🟠'],
    offline: ['bg-gray-100 text-gray-500 border-gray-200', '⚫'],
  };
  const [cls, dot] = map[availability] || map.offline;
  return (
    <span className={`${PILL} ${cls}`}>
      {dot} {availability || 'offline'}
    </span>
  );
}

export function VolunteerStatusBadge({ status }) {
  const map = {
    active: 'bg-green-50 text-green-700 border-green-200',
    inactive: 'bg-gray-100 text-gray-500 border-gray-200',
    suspended: 'bg-red-50 text-red-700 border-red-200',
  };
  return <span className={`${PILL} ${map[status] || map.inactive}`}>{status || '—'}</span>;
}

// SOS lifecycle — 'active' is the unassigned queue.
export const SOS_STATUS_LABEL = {
  active: 'Unassigned',
  assigned: 'Volunteer Assigned',
  accepted: 'Volunteer Accepted',
  in_progress: 'Response In Progress',
  resolved: 'Resolved',
  cancelled: 'Cancelled',
};

export function SosStatusBadge({ status }) {
  const map = {
    active: 'bg-red-50 text-red-600 border-red-200 animate-pulse',
    assigned: 'bg-purple-50 text-purple-700 border-purple-200',
    accepted: 'bg-blue-50 text-blue-700 border-blue-200',
    in_progress: 'bg-orange-50 text-orange-700 border-orange-200',
    resolved: 'bg-green-50 text-green-700 border-green-200',
    cancelled: 'bg-gray-100 text-gray-500 border-gray-200',
  };
  return (
    <span className={`${PILL} ${map[status] || map.active}`}>
      {SOS_STATUS_LABEL[status] || status}
    </span>
  );
}

export function SkillChip({ label }) {
  const pretty = String(label || '')
    .replace(/_/g, ' ')
    .replace(/\b\w/g, (c) => c.toUpperCase());
  return (
    <span className="inline-flex items-center px-2 py-0.5 rounded-full bg-orange-50 text-orange-700 border border-orange-100 text-[10px] font-bold">
      {pretty}
    </span>
  );
}

// Stepper: assigned → accepted → in progress → resolved/completed
export function TaskFlowSteps({ status }) {
  const steps = ['assigned', 'accepted', 'in_progress', 'completed'];
  const order = { assigned: 0, accepted: 1, in_progress: 2, completed: 3, resolved: 3 };
  const current = order[status] ?? -1;
  const dead = ['rejected', 'cancelled', 'unable_to_complete'].includes(status);
  if (dead) return <TaskStatusBadge status={status} />;
  return (
    <div className="flex items-center gap-1">
      {steps.map((step, idx) => (
        <React.Fragment key={step}>
          <span
            className={`h-1.5 flex-1 rounded-full ${
              idx <= current ? 'bg-orange-500' : 'bg-gray-200'
            }`}
            title={step}
          />
        </React.Fragment>
      ))}
    </div>
  );
}

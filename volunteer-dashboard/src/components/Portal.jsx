import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  LayoutDashboard, ClipboardList, History, Radio, User, LogOut,
  PanelLeftClose, PanelLeft, BellRing, X,
} from 'lucide-react';
import { getMyVolunteerProfile, listMyTasks } from '../lib/api';
import { useMyTasks } from '../lib/live';
import { AvailabilityBadge } from './tasks/badges';
import HomeDashboard from './HomeDashboard';
import TaskHistory from './TaskHistory';
import TaskCard from './TaskCard';
import AvailabilityPanel from './AvailabilityPanel';
import ProfilePanel from './ProfilePanel';

function MyActiveTasks({ tasks, newTaskIds, onTasksChanged }) {
  const active = tasks.filter((t) => ['assigned', 'accepted', 'in_progress'].includes(t.status));
  if (active.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-20 text-center border-2 border-dashed border-green-200 rounded-3xl bg-green-50/50">
        <h3 className="text-xl font-bold text-green-800 mb-1">No Active Tasks 🟢</h3>
        <p className="text-green-600 text-sm max-w-sm">
          You have nothing assigned right now. New dispatches from the control room appear here
          automatically — no refresh needed.
        </p>
      </div>
    );
  }
  return (
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
  );
}

const TempleLogo = () => (
  <svg viewBox="0 0 24 24" fill="currentColor" className="w-6 h-6 text-white">
    <path d="M10 4h4v3h-4z" />
    <path d="M8 7h8v3H8z" />
    <path d="M4 10h16v8h-6v-3a2 2 0 0 0-4 0v3H4v-8z" />
  </svg>
);

const MENU = [
  { key: 'dashboard', label: 'Dashboard', icon: <LayoutDashboard size={20} /> },
  { key: 'tasks', label: 'My Active Tasks', icon: <ClipboardList size={20} /> },
  { key: 'history', label: 'Task History', icon: <History size={20} /> },
  { key: 'availability', label: 'Availability', icon: <Radio size={20} /> },
  { key: 'profile', label: 'Profile', icon: <User size={20} /> },
];

const PAGE_TITLES = {
  dashboard: 'Dashboard',
  tasks: 'My Active Tasks',
  history: 'Task History',
  availability: 'Availability',
  profile: 'My Profile',
};

export default function Portal({ session, onLogout }) {
  const [page, setPage] = useState('dashboard');
  const [expanded, setExpanded] = useState(true);
  const [profile, setProfile] = useState(null);
  const [toast, setToast] = useState(null);
  const [newTaskIds, setNewTaskIds] = useState(new Set());

  // ---- live tasks (firestore listener or gentle REST polling) -------------
  const fetchAllMyTasks = useCallback(async () => (await listMyTasks('all')).tasks, []);
  const { data: tasks, refresh: refreshTasks, source } = useMyTasks(fetchAllMyTasks);

  const activeCount = useMemo(
    () => tasks.filter((t) => ['assigned', 'accepted', 'in_progress'].includes(t.status)).length,
    [tasks],
  );

  // ---- profile --------------------------------------------------------------
  const loadProfile = useCallback(async () => {
    try {
      setProfile(await getMyVolunteerProfile());
    } catch (_) { /* session guard will fire if unauthorized */ }
  }, []);

  useEffect(() => {
    loadProfile();
    const id = setInterval(loadProfile, 15000); // availability/counters sync
    return () => clearInterval(id);
  }, [loadProfile]);

  // ---- "NEW EMERGENCY TASK" notification (in-app, real-time driven) --------
  const seenRef = useRef(null);
  useEffect(() => {
    const assigned = tasks.filter((t) => t.status === 'assigned');
    if (seenRef.current === null) {
      // first load: don't blast toasts for pre-existing tasks
      seenRef.current = new Set(tasks.map((t) => t.task_id));
      return;
    }
    const fresh = assigned.filter((t) => !seenRef.current.has(t.task_id));
    tasks.forEach((t) => seenRef.current.add(t.task_id));
    if (fresh.length > 0) {
      const task = fresh[0];
      setNewTaskIds((prev) => new Set([...prev, ...fresh.map((t) => t.task_id)]));
      setToast({
        title: (task.priority === 'high' || task.priority === 'critical')
          ? '🚨 NEW EMERGENCY TASK'
          : '📋 New Task Assigned',
        body: task.title,
        location: task.location?.address || '',
        priority: task.priority,
      });
      const timer = setTimeout(() => setToast(null), 9000);
      return () => clearTimeout(timer);
    }
    return undefined;
  }, [tasks]);

  const clearNewFlag = (ids) => {
    setNewTaskIds((prev) => {
      const next = new Set(prev);
      ids.forEach((id) => next.delete(id));
      return next;
    });
  };

  const onTasksChanged = useCallback(() => {
    refreshTasks();
    loadProfile();
  }, [refreshTasks, loadProfile]);

  return (
    <div className="flex h-screen bg-orange-50 font-sans text-gray-800 overflow-hidden">
      {/* toast */}
      {toast && (
        <div className="fixed top-4 right-4 z-50 w-80 bg-white border-2 border-red-500 rounded-2xl shadow-2xl p-4">
          <div className="flex items-start justify-between gap-2">
            <p className="font-black text-red-600 text-sm">{toast.title}</p>
            <button onClick={() => setToast(null)} className="text-gray-400 hover:text-gray-600 cursor-pointer">
              <X size={16} />
            </button>
          </div>
          <p className="font-bold text-gray-900 mt-1.5">{toast.body}</p>
          {toast.location && <p className="text-xs text-gray-500 mt-0.5">📍 {toast.location}</p>}
          <button
            onClick={() => { setToast(null); setPage('tasks'); }}
            className="mt-3 w-full py-2 rounded-xl bg-red-600 hover:bg-red-700 text-white text-xs font-bold cursor-pointer"
          >
            VIEW TASK
          </button>
        </div>
      )}

      {/* sidebar */}
      <aside className={`${expanded ? 'w-64' : 'w-20'} bg-white border-r border-orange-100 flex flex-col z-20 shadow-sm transition-all duration-300 shrink-0`}>
        <div className={`p-4 border-b border-orange-50 flex ${expanded ? 'items-center justify-between min-h-22' : 'flex-col items-center gap-4 py-5'}`}>
          <div className="flex items-center gap-3 overflow-hidden">
            <div className="min-w-11 h-11 bg-[#f97316] rounded-full shadow-sm shadow-orange-200 flex items-center justify-center shrink-0">
              <TempleLogo />
            </div>
            <div className={`flex flex-col whitespace-nowrap overflow-hidden transition-all duration-300 ${expanded ? 'opacity-100 w-[130px]' : 'opacity-0 w-0 hidden'}`}>
              <h1 className="text-[22px] font-bold text-[#3d2514] tracking-tight leading-none mt-1">WariSphere</h1>
              <p className="text-[12px] text-[#8b3a2b] font-medium mt-1">Volunteer Portal</p>
            </div>
          </div>
          <button
            onClick={() => setExpanded(!expanded)}
            className="p-1.5 rounded-lg text-gray-400 hover:bg-orange-50 hover:text-orange-600 cursor-pointer transition-colors shrink-0"
            title={expanded ? 'Collapse Sidebar' : 'Expand Sidebar'}
          >
            {expanded ? <PanelLeftClose size={20} /> : <PanelLeft size={20} />}
          </button>
        </div>

        <nav className="flex-1 px-3 py-6 space-y-2 overflow-y-auto overflow-x-hidden">
          {MENU.map((item) => (
            <button
              key={item.key}
              onClick={() => {
                setPage(item.key);
                if (item.key === 'tasks' || item.key === 'dashboard') {
                  clearNewFlag([...newTaskIds]);
                }
              }}
              className={`w-full flex items-center ${expanded ? 'px-4' : 'justify-center px-0'} py-3 rounded-xl text-left cursor-pointer transition-all duration-200 relative ${
                page === item.key
                  ? 'bg-orange-500 text-white font-medium shadow-md shadow-orange-200/50'
                  : 'text-gray-600 hover:bg-orange-50 hover:text-orange-600'
              }`}
              title={!expanded ? item.label : ''}
            >
              <div className="shrink-0 relative">
                {item.icon}
                {(item.key === 'tasks' || item.key === 'dashboard') && newTaskIds.size > 0 && (
                  <span className="absolute -top-1 -right-1 w-2.5 h-2.5 bg-red-500 rounded-full animate-pulse" />
                )}
              </div>
              <span className={`ml-3 whitespace-nowrap transition-all duration-300 ${expanded ? 'opacity-100 block' : 'opacity-0 hidden'}`}>
                {item.label}
                {item.key === 'tasks' && activeCount > 0 && (
                  <span className={`ml-2 text-[10px] font-black px-1.5 py-0.5 rounded-full ${page === item.key ? 'bg-white/25' : 'bg-orange-100 text-orange-700'}`}>
                    {activeCount}
                  </span>
                )}
              </span>
            </button>
          ))}
        </nav>

        <div className="p-3 border-t border-orange-100 bg-gray-50/50 flex flex-col gap-2">
          <div className={`flex items-center gap-3 p-2 rounded-xl ${!expanded && 'justify-center'}`}>
            <div className="min-w-9 h-9 rounded-full bg-orange-100 text-orange-600 flex items-center justify-center font-bold border border-orange-200 shrink-0">
              {(profile?.name || session?.name || 'V').charAt(0).toUpperCase()}
            </div>
            <div className={`whitespace-nowrap overflow-hidden transition-all duration-300 ${expanded ? 'opacity-100' : 'opacity-0 w-0 hidden'}`}>
              <p className="text-sm font-semibold text-gray-900 leading-tight">
                {profile?.name || session?.name || 'Volunteer'}
              </p>
              <div className="mt-0.5">
                <AvailabilityBadge availability={profile?.availability || 'offline'} />
              </div>
            </div>
          </div>

          <button
            onClick={onLogout}
            className={`w-full flex items-center ${expanded ? 'px-3 py-2.5 gap-3' : 'justify-center py-2.5'} rounded-xl bg-red-50 hover:bg-red-100 text-red-600 font-semibold cursor-pointer transition-colors shadow-sm`}
            title="Log Out"
          >
            <LogOut size={18} className="shrink-0" />
            <span className={`whitespace-nowrap text-xs uppercase tracking-wider transition-all duration-300 ${expanded ? 'opacity-100 block' : 'opacity-0 hidden'}`}>
              Log Out
            </span>
          </button>
        </div>
      </aside>

      {/* main */}
      <main className="flex-1 flex flex-col overflow-hidden min-w-0">
        <header className="bg-white/80 backdrop-blur-md shadow-sm border-b border-orange-100 p-6 flex justify-between items-center gap-4 z-10">
          <div>
            <h2 className="text-3xl font-bold text-gray-900">{PAGE_TITLES[page]}</h2>
            <p className="text-sm text-gray-500 mt-1">
              WariSphere Volunteer Portal — live sync {source === 'firestore' ? '(real-time)' : 'on'}
            </p>
          </div>
          {newTaskIds.size > 0 && (
            <div className="flex items-center gap-2 bg-red-50 border border-red-200 text-red-700 px-4 py-2.5 rounded-2xl">
              <BellRing size={18} className="animate-pulse" />
              <span className="text-sm font-bold">{newTaskIds.size} new task{newTaskIds.size > 1 ? 's' : ''}</span>
            </div>
          )}
        </header>

        <div className="flex-1 overflow-y-auto p-4 md:p-8">
          {page === 'dashboard' && (
            <HomeDashboard
              profile={profile}
              tasks={tasks}
              newTaskIds={newTaskIds}
              onTasksChanged={onTasksChanged}
              goToTasks={() => { setPage('tasks'); clearNewFlag([...newTaskIds]); }}
            />
          )}
          {page === 'tasks' && (
            <MyActiveTasks
              tasks={tasks}
              newTaskIds={newTaskIds}
              onTasksChanged={onTasksChanged}
            />
          )}
          {page === 'history' && (
            <TaskHistory tasks={tasks} newTaskIds={newTaskIds} onTasksChanged={onTasksChanged} />
          )}
          {page === 'availability' && (
            <AvailabilityPanel profile={profile} tasks={tasks} onChanged={onTasksChanged} />
          )}
          {page === 'profile' && (
            <ProfilePanel profile={profile} onChanged={loadProfile} />
          )}
        </div>
      </main>
    </div>
  );
}

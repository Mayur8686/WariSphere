import React, { useState } from 'react';
import { 
  Users, 
  AlertTriangle, 
  UserMinus, 
  Tent, 
  UserCheck, 
  Map, 
  Bell,
  PanelLeftClose,
  PanelLeft,
  LogOut
} from 'lucide-react';
import ActiveSOS from './modules/ActiveSOS'; // <-- ADDED THIS IMPORT
import LostPersons from './modules/LostPersons';
import LiveCrowd from './modules/LiveCrowd';
import MedicalCamps from './modules/MedicalCamps';
import Volunteers from './modules/Volunteers';
import RoutesModule from './modules/RoutesModule';
import Alerts from './modules/Alerts';

const TempleLogo = () => (
  <svg viewBox="0 0 24 24" fill="currentColor" className="w-6 h-6 text-white">
    <path d="M10 4h4v3h-4z" />
    <path d="M8 7h8v3H8z" />
    <path d="M4 10h16v8h-6v-3a2 2 0 0 0-4 0v3H4v-8z" />
  </svg>
);

export default function Dashboard({ onLogout }) {
  const [activeTab, setActiveTab] = useState('Active SOS');
  const [isSidebarExpanded, setIsSidebarExpanded] = useState(true);

  const menuItems = [
    { name: 'Live Crowd', icon: <Users size={20} /> },
    { name: 'Active SOS', icon: <AlertTriangle size={20} /> },
    { name: 'Lost Persons', icon: <UserMinus size={20} /> },
    { name: 'Medical Camps', icon: <Tent size={20} /> },
    { name: 'Volunteers', icon: <UserCheck size={20} /> },
    { name: 'Routes', icon: <Map size={20} /> },
    { name: 'Alerts', icon: <Bell size={20} /> },
  ];

  const stats = [
    { label: 'Active Alerts', value: '3', color: 'text-red-600' },
    { label: 'Crowd Density', value: 'High', color: 'text-orange-600' },
    { label: 'Active Volunteers', value: '124', color: 'text-green-600' },
  ];

  return (
    <div className="flex h-screen bg-orange-50 font-sans text-gray-800 overflow-hidden">
      
      {/* Sidebar */}
      <aside className={`${isSidebarExpanded ? 'w-64' : 'w-20'} bg-white border-r border-orange-100 flex flex-col z-20 shadow-sm transition-all duration-300 shrink-0`}>
        
        <div className={`p-4 border-b border-orange-50 flex ${isSidebarExpanded ? 'items-center justify-between min-h-22' : 'flex-col items-center gap-4 py-5'}`}>
          <div className="flex items-center gap-3 overflow-hidden">
            <div className="min-w-11 h-11 bg-[#f97316] rounded-full shadow-sm shadow-orange-200 flex items-center justify-center shrink-0">
              <TempleLogo />
            </div>
            <div className={`flex flex-col whitespace-nowrap overflow-hidden transition-all duration-300 ${isSidebarExpanded ? 'opacity-100 w-[130px]' : 'opacity-0 w-0 hidden'}`}>
              <h1 className="text-[22px] font-bold text-[#3d2514] tracking-tight leading-none mt-1">WariSphere</h1>
              <p className="text-[13px] text-[#8b3a2b] font-medium mt-1">वारकरांचा सोबती</p>
            </div>
          </div>
          <button 
            onClick={() => setIsSidebarExpanded(!isSidebarExpanded)}
            className="p-1.5 rounded-lg text-gray-400 hover:bg-orange-50 hover:text-orange-600 cursor-pointer transition-colors shrink-0"
            title={isSidebarExpanded ? "Collapse Sidebar" : "Expand Sidebar"}
          >
            {isSidebarExpanded ? <PanelLeftClose size={20} /> : <PanelLeft size={20} />}
          </button>
        </div>
        
        <nav className="flex-1 px-3 py-6 space-y-2 overflow-y-auto overflow-x-hidden">
          {menuItems.map((item) => (
            <button
              key={item.name}
              onClick={() => setActiveTab(item.name)}
              className={`w-full flex items-center ${isSidebarExpanded ? 'px-4' : 'justify-center px-0'} py-3 rounded-xl text-left cursor-pointer transition-all duration-200 ${
                activeTab === item.name 
                  ? 'bg-orange-500 text-white font-medium shadow-md shadow-orange-200/50' 
                  : 'text-gray-600 hover:bg-orange-50 hover:text-orange-600'
              }`}
              title={!isSidebarExpanded ? item.name : ""}
            >
              <div className="shrink-0">{item.icon}</div>
              <span className={`ml-3 whitespace-nowrap transition-all duration-300 ${isSidebarExpanded ? 'opacity-100 block' : 'opacity-0 hidden'}`}>
                {item.name}
              </span>
            </button>
          ))}
        </nav>

        <div className="p-3 border-t border-orange-100 bg-gray-50/50 flex flex-col gap-2">
          <div className={`flex items-center gap-3 p-2 rounded-xl ${!isSidebarExpanded && 'justify-center'}`}>
            <div className="min-w-9 h-9 rounded-full bg-orange-100 text-orange-600 flex items-center justify-center font-bold border border-orange-200 shrink-0">
              A
            </div>
            <div className={`whitespace-nowrap overflow-hidden transition-all duration-300 ${isSidebarExpanded ? 'opacity-100' : 'opacity-0 w-0 hidden'}`}>
              <p className="text-sm font-semibold text-gray-900 leading-tight">Authority</p>
              <p className="text-[11px] text-gray-500 font-medium">Control Room</p>
            </div>
          </div>

          <button
            onClick={onLogout}
            className={`w-full flex items-center ${isSidebarExpanded ? 'px-3 py-2.5 gap-3' : 'justify-center py-2.5'} rounded-xl bg-red-50 hover:bg-red-100 text-red-600 font-semibold cursor-pointer transition-colors shadow-sm`}
            title="Log Out"
          >
            <LogOut size={18} className="shrink-0" />
            <span className={`whitespace-nowrap text-xs uppercase tracking-wider transition-all duration-300 ${isSidebarExpanded ? 'opacity-100 block' : 'opacity-0 hidden'}`}>
              Log Out
            </span>
          </button>
        </div>
      </aside>

      {/* Main Content Area */}
      <main className="flex-1 flex flex-col overflow-hidden min-w-0">
        
        {/* FIXED HEADER STATS AREA */}
        <header className="bg-white/80 backdrop-blur-md shadow-sm border-b border-orange-100 p-6 flex flex-col xl:flex-row justify-between items-start xl:items-center gap-4 z-10">
          <div>
            <h2 className="text-3xl font-bold text-gray-900">{activeTab}</h2>
            <p className="text-sm text-gray-500 mt-1">Real-time monitoring and dispatch control room</p>
          </div>
          
          <div className="flex flex-wrap sm:flex-nowrap gap-3 w-full xl:w-auto mt-2 xl:mt-0">
            {stats.map((stat) => (
              <div key={stat.label} className="bg-white px-4 py-2.5 rounded-xl border border-orange-100 shadow-sm flex flex-col items-center min-w-[110px] flex-1 sm:flex-none">
                <span className="text-[10px] text-gray-400 uppercase tracking-wider font-bold mb-1 text-center">{stat.label}</span>
                <span className={`text-xl font-black ${stat.color}`}>{stat.value}</span>
              </div>
            ))}
          </div>
        </header>

        {/* Dynamic Content Switching */}
        <div className="flex-1 overflow-y-auto p-4 md:p-8">
          {activeTab === 'Active SOS' ? (
            <ActiveSOS />               // <-- REPLACED HARDCODED HTML WITH THIS
          ) : activeTab === 'Live Crowd' ? (
            <LiveCrowd />
          ) : activeTab === 'Lost Persons' ? (
            <LostPersons />
          ) : activeTab === 'Medical Camps' ? (
            <MedicalCamps />
          ) : activeTab === 'Volunteers' ? (
            <Volunteers />
          ) : activeTab === 'Routes' ? (
            <RoutesModule />
          ) : activeTab === 'Alerts' ? (
            <Alerts />
          ) : null}
        </div>
      </main>
    </div>
  );
}
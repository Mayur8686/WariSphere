import React from 'react';
import { Send, Megaphone, Clock } from 'lucide-react';

export default function Alerts() {
  const alertsList = [
    { id: 1, title: 'Heavy Congestion Advisory at Alandi Gate', time: '15 mins ago', target: 'All Warkaris', severity: 'High' },
    { id: 2, title: 'Temporary Medical Camp Relocation near Hadapsar', time: '1 hour ago', target: 'Sector B Volunteers', severity: 'Medium' },
  ];

  return (
    <div className="flex flex-col xl:flex-row gap-6 h-full">
      <div className="w-full xl:w-1/3 bg-white p-6 rounded-2xl border border-orange-100 shadow-sm flex flex-col">
        <h3 className="text-lg font-bold text-gray-900 mb-1">Broadcast Emergency Alert</h3>
        <p className="text-sm text-gray-500 mb-4">Send push notifications to thousands of pilgrims instantly.</p>
        
        <form onSubmit={(e) => { e.preventDefault(); alert("Broadcast sent successfully!"); }} className="space-y-4 flex-1 flex flex-col justify-between">
          <div className="space-y-4">
            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-gray-600 mb-2">Alert Title</label>
              <input type="text" placeholder="e.g. Route Diversion Notice" className="w-full px-4 py-3 rounded-xl bg-gray-50 border border-gray-200 text-sm focus:outline-none focus:border-orange-500" required />
            </div>
            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-gray-600 mb-2">Target Audience</label>
              <select className="w-full px-4 py-3 rounded-xl bg-gray-50 border border-gray-200 text-sm focus:outline-none focus:border-orange-500">
                <option>All Pilgrims (Warkaris)</option>
                <option>Field Volunteers Only</option>
                <option>Medical Staff Only</option>
              </select>
            </div>
            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-gray-600 mb-2">Message Body</label>
              <textarea rows="4" placeholder="Enter alert details..." className="w-full px-4 py-3 rounded-xl bg-gray-50 border border-gray-200 text-sm focus:outline-none focus:border-orange-500 resize-none" required></textarea>
            </div>
          </div>

          <button type="submit" className="w-full bg-orange-500 hover:bg-orange-600 text-white font-bold py-3.5 rounded-xl cursor-pointer transition-colors shadow-sm flex items-center justify-center gap-2">
            <Send size={16} /> Broadcast to App Users
          </button>
        </form>
      </div>

      <div className="w-full xl:w-2/3 bg-white p-6 rounded-2xl border border-orange-100 shadow-sm flex flex-col">
        <h3 className="text-lg font-bold text-gray-900 mb-1">Broadcast History</h3>
        <p className="text-sm text-gray-500 mb-6">Past notifications dispatched through Firebase Cloud Messaging</p>

        <div className="space-y-4">
          {alertsList.map((a) => (
            <div key={a.id} className="p-4 rounded-xl border border-orange-100 bg-orange-50/20 flex justify-between items-start">
              <div className="flex gap-3">
                <div className="w-10 h-10 bg-orange-100 text-orange-600 rounded-xl flex items-center justify-center shrink-0">
                  <Megaphone size={18} />
                </div>
                <div>
                  <h4 className="font-bold text-gray-900">{a.title}</h4>
                  <p className="text-xs text-gray-500 mt-1">Target: <span className="font-semibold text-gray-700">{a.target}</span></p>
                </div>
              </div>
              <div className="text-right">
                <span className="text-[10px] font-black uppercase bg-red-100 text-red-700 px-2.5 py-0.5 rounded-full">{a.severity}</span>
                <p className="text-xs text-gray-400 mt-2 flex items-center gap-1 justify-end"><Clock size={12} /> {a.time}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
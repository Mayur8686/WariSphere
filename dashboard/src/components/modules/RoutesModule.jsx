import React from 'react';
import { Navigation } from 'lucide-react';

export default function RoutesModule() {
  const routes = [
    { id: 1, name: 'Sant Tukaram Maharaj Palkhi Route (Hadapsar)', congestion: 'High Density', status: 'Active Diversion Recommended' },
    { id: 2, name: 'Sant Dnyaneshwar Maharaj Route (Alandi)', congestion: 'Moderate', status: 'Normal Flow' },
    { id: 3, name: 'Pune Station Bypass Link', congestion: 'Clear', status: 'Open for Emergency Vehicles' },
  ];

  return (
    <div className="flex flex-col gap-6 h-full">
      <div className="bg-white p-6 rounded-2xl border border-orange-100 shadow-sm flex justify-between items-center">
        <div>
          <h3 className="text-lg font-bold text-gray-900">Pilgrimage Route Monitoring</h3>
          <p className="text-sm text-gray-500">Live traffic congestion and alternate diversion paths for the Wari procession</p>
        </div>
        <button className="bg-orange-500 hover:bg-orange-600 text-white px-4 py-2.5 rounded-xl text-sm font-bold cursor-pointer transition-colors shadow-sm">
          Broadcast Route Update
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {routes.map((r) => (
          <div key={r.id} className="bg-white p-6 rounded-2xl border border-orange-100 shadow-sm flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between mb-3">
                <div className="w-10 h-10 bg-orange-100 text-orange-600 rounded-xl flex items-center justify-center">
                  <Navigation size={20} />
                </div>
                <span className="text-[10px] font-black uppercase px-2.5 py-1 rounded-full bg-orange-50 text-orange-700 border border-orange-200">
                  {r.congestion}
                </span>
              </div>
              <h4 className="font-bold text-gray-900 text-base">{r.name}</h4>
              <p className="text-xs text-gray-500 mt-2 font-medium">{r.status}</p>
            </div>
            <div className="mt-6 pt-4 border-t border-orange-50 flex justify-between items-center">
              <span className="text-xs font-bold text-orange-600 cursor-pointer hover:underline">View Map & Checkpoints →</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
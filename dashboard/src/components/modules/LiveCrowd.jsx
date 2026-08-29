import React from 'react';
import { Video, AlertTriangle, Activity, Users, MapPin, Maximize2 } from 'lucide-react';

export default function LiveCrowd() {
  // Mock data for CCTV cameras simulating YOLO AI feeds
  const cameras = [
    { id: 'CAM-01', location: 'Alandi Main Temple', status: 'Critical', count: 1245, density: '98%', color: 'border-red-500', bg: 'bg-red-500' },
    { id: 'CAM-02', location: 'Pune Station Entry', status: 'Moderate', count: 450, density: '65%', color: 'border-orange-500', bg: 'bg-orange-500' },
    { id: 'CAM-03', location: 'Hadapsar Highway', status: 'Normal', count: 120, density: '25%', color: 'border-green-500', bg: 'bg-green-500' },
    { id: 'CAM-04', location: 'Yavat Camp Base', status: 'High', count: 890, density: '82%', color: 'border-orange-500', bg: 'bg-orange-500' },
  ];

  return (
    <div className="flex flex-col gap-6 h-full">
      
      {/* Top Stats Row */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white p-5 rounded-2xl border border-orange-100 shadow-sm flex items-center gap-4">
          <div className="w-12 h-12 bg-blue-50 rounded-full flex items-center justify-center text-blue-600">
            <Users size={24} />
          </div>
          <div>
            <p className="text-sm text-gray-500 font-medium">Total Detected Crowd</p>
            <h3 className="text-2xl font-black text-gray-900">2,705 <span className="text-sm font-normal text-gray-400">persons/hr</span></h3>
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-orange-100 shadow-sm flex items-center gap-4">
          <div className="w-12 h-12 bg-red-50 rounded-full flex items-center justify-center text-red-600">
            <AlertTriangle size={24} />
          </div>
          <div>
            <p className="text-sm text-gray-500 font-medium">Congestion Alerts</p>
            <h3 className="text-2xl font-black text-gray-900">1 <span className="text-sm font-normal text-red-500 bg-red-50 px-2 py-0.5 rounded ml-2 text-[10px] uppercase">Action Req</span></h3>
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-orange-100 shadow-sm flex items-center gap-4">
          <div className="w-12 h-12 bg-green-50 rounded-full flex items-center justify-center text-green-600">
            <Activity size={24} />
          </div>
          <div>
            <p className="text-sm text-gray-500 font-medium">AI Model Status</p>
            <h3 className="text-xl font-bold text-gray-900 flex items-center gap-2">
              <span className="w-2.5 h-2.5 bg-green-500 rounded-full animate-pulse"></span>
              YOLOv8 Active
            </h3>
          </div>
        </div>
      </div>

      {/* Camera Grid */}
      <div className="bg-white p-6 rounded-2xl border border-orange-100 shadow-sm flex-1 flex flex-col">
        <div className="flex justify-between items-center mb-6">
          <div>
            <h3 className="text-lg font-bold text-gray-900">Live AI Crowd Feeds</h3>
            <p className="text-sm text-gray-500">Real-time object detection processing</p>
          </div>
          <button className="flex items-center gap-2 text-sm font-bold text-orange-600 bg-orange-50 px-4 py-2 rounded-xl hover:bg-orange-100 transition-colors">
            <Video size={16} /> Add Camera Stream
          </button>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 flex-1">
          {cameras.map((cam) => (
            <div key={cam.id} className={`relative rounded-xl overflow-hidden border-2 flex flex-col bg-gray-900 ${cam.color} group`}>
              
              {/* Fake AI Camera Feed Background */}
              <div className="absolute inset-0 opacity-20 bg-[radial-gradient(ellipse_at_center,var(--tw-gradient-stops))] from-gray-700 via-gray-900 to-black"></div>
              <div className="absolute inset-0 bg-[url('https://www.transparenttextures.com/patterns/stardust.png')] opacity-10"></div>
              
              {/* Fake AI Bounding Boxes (to look technical for the demo) */}
              <div className="absolute top-[30%] left-[20%] w-16 h-32 border-2 border-green-500 bg-green-500/10 hidden sm:block">
                <span className="absolute -top-4 left-0 bg-green-500 text-black text-[8px] font-bold px-1">Person 0.98</span>
              </div>
              <div className="absolute top-[40%] left-[50%] w-12 h-24 border-2 border-green-500 bg-green-500/10 hidden sm:block">
                <span className="absolute -top-4 left-0 bg-green-500 text-black text-[8px] font-bold px-1">Person 0.92</span>
              </div>
              
              {/* Feed Header overlay */}
              <div className="relative z-10 flex justify-between items-start p-3 bg-linear-to-b from-black/80 to-transparent">
                <div className="flex items-center gap-2 text-white">
                  <span className={`w-2 h-2 rounded-full animate-pulse ${cam.bg}`}></span>
                  <span className="font-mono text-xs font-bold">{cam.id}</span>
                  <span className="text-xs text-gray-300 flex items-center gap-1 bg-black/40 px-2 py-0.5 rounded">
                    <MapPin size={10} /> {cam.location}
                  </span>
                </div>
                <button className="text-white/50 hover:text-white transition-colors cursor-pointer">
                  <Maximize2 size={16} />
                </button>
              </div>

              {/* Central Spacer */}
              <div className="flex-1 min-h-40"></div>

              {/* AI Metrics Overlay */}
              <div className="relative z-10 p-3 bg-linear-to-t from-black to-transparent/10 mt-auto">
                <div className="flex justify-between items-end">
                  <div>
                    <p className="text-gray-400 text-[10px] uppercase font-bold tracking-wider mb-1">AI Estimated Count</p>
                    <p className="text-white text-2xl font-black font-mono leading-none">{cam.count}</p>
                  </div>
                  <div className="text-right">
                    <span className={`text-[10px] font-black uppercase px-2 py-1 rounded text-white ${cam.bg}`}>
                      {cam.status} DENSITY
                    </span>
                    <p className="text-white text-sm font-bold mt-1.5">{cam.density} Capacity</p>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

    </div>
  );
}
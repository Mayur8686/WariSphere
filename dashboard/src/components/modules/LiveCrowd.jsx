import React, { useState, useEffect } from 'react';
import { Users, AlertTriangle, Activity, MapPin, Video, Maximize2 } from 'lucide-react';

export default function LiveCrowd() {
  const [streamError, setStreamError] = useState(false);
  
  const [cameras, setCameras] = useState([
    {
      id: 'CAM-01',
      location: 'Alandi Main Temple (LIVE AI)',
      count: 0, 
      capacity: 0,
      isLiveStream: true, 
      image: ''
    },
    {
      id: 'CAM-02',
      location: 'Pune Station Entry',
      count: 450,
      capacity: 65,
      isLiveStream: false,
      image: 'https://images.unsplash.com/photo-1506869640319-a1a5606089ce?auto=format&fit=crop&q=80&w=800'
    }
  ]);

  return (
    <div className="flex flex-col gap-6 h-full relative">
      
      {/* Top Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white p-6 rounded-2xl border border-orange-100 shadow-sm flex items-center gap-5">
          <div className="w-14 h-14 bg-blue-50 text-blue-600 rounded-full flex items-center justify-center shrink-0">
            <Users size={28} />
          </div>
          <div>
            <p className="text-sm font-bold text-gray-500 mb-1">Total Detected Crowd</p>
            <div className="flex items-baseline gap-2">
              <h3 className="text-3xl font-black text-gray-900">Live Syncing</h3>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-2xl border border-orange-100 shadow-sm flex items-center gap-5">
          <div className="w-14 h-14 bg-green-50 text-green-600 rounded-full flex items-center justify-center shrink-0">
            <AlertTriangle size={28} />
          </div>
          <div>
            <p className="text-sm font-bold text-gray-500 mb-1">Congestion Alerts</p>
            <div className="flex items-center gap-3">
              <h3 className="text-3xl font-black text-gray-900">0</h3>
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-2xl border border-orange-100 shadow-sm flex items-center gap-5">
          <div className="w-14 h-14 bg-green-50 text-green-600 rounded-full flex items-center justify-center shrink-0">
            <Activity size={28} />
          </div>
          <div>
            <p className="text-sm font-bold text-gray-500 mb-1">AI Model Status</p>
            <div className="flex items-center gap-2">
              <span className="w-2.5 h-2.5 bg-green-500 rounded-full animate-ping absolute"></span>
              <span className="w-2.5 h-2.5 bg-green-500 rounded-full relative"></span>
              <h3 className="text-xl font-black text-gray-900">YOLOv8 Active</h3>
            </div>
          </div>
        </div>
      </div>

      {/* Main Feed View */}
      <div className="bg-white rounded-2xl border border-orange-100 shadow-sm flex-1 flex flex-col min-h-0">
        <div className="p-5 border-b border-orange-50 flex justify-between items-center bg-gray-50/50 rounded-t-2xl">
          <div>
            <h3 className="text-lg font-bold text-gray-900">Live AI Crowd Feeds</h3>
            <p className="text-sm text-gray-500">Real-time object detection processing</p>
          </div>
        </div>

        {/* Camera Feeds */}
        <div className="p-5 grid grid-cols-1 lg:grid-cols-2 gap-5 overflow-y-auto">
          {cameras.map((cam) => {
            const showLiveYOLO = cam.isLiveStream && !streamError;
            
            return (
              <div key={cam.id} className="relative h-87.5 rounded-xl overflow-hidden border-2 border-gray-800 flex flex-col justify-between group bg-black">
                
                {/* REAL LIVE STREAM */}
                {showLiveYOLO ? (
                  <img 
                    src="http://127.0.0.1:8000/api/cctv/stream/CAM-01" 
                    alt="Live YOLOv8 Feed" 
                    onError={() => setStreamError(true)}
                    className="absolute inset-0 w-full h-full object-contain z-0"
                  />
                ) : (
                  <div 
                    className="absolute inset-0 bg-cover bg-center opacity-50"
                    style={{ backgroundImage: `url(${cam.image})` }}
                  ></div>
                )}

                {/* Overlay Meta */}
                <div className="relative z-10 p-3 flex justify-between items-start">
                  <div className="flex items-center gap-3 bg-black/60 backdrop-blur-md px-3 py-1.5 rounded-lg border border-white/10">
                    <span className="w-2 h-2 bg-red-500 rounded-full animate-pulse"></span>
                    <span className="text-white font-bold text-xs">{cam.id}</span>
                    <span className="text-gray-300 text-xs flex items-center gap-1 border-l border-gray-600 pl-3">
                      <MapPin size={10} /> {cam.location}
                    </span>
                    {showLiveYOLO && (
                      <span className="bg-green-600 text-white text-[10px] font-bold px-2 py-0.5 rounded ml-2 animate-pulse">
                        LIVE YOLOv8
                      </span>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
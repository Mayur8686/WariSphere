import React, { useState, useEffect } from 'react';
import { collection, onSnapshot } from 'firebase/firestore';
import { db } from '../../firebase'; 

export default function ActiveSOS() {
  const [alerts, setAlerts] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const sosRef = collection(db, 'sos_alerts');
    
    const unsubscribe = onSnapshot(sosRef, (snapshot) => {
      const fetchedAlerts = [];
      snapshot.forEach((doc) => {
        fetchedAlerts.push({ id: doc.id, ...doc.data() });
      });
      
      setAlerts(fetchedAlerts);
      setLoading(false);
    }, (error) => {
      console.error("Error fetching SOS alerts:", error);
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-orange-600"></div>
      </div>
    );
  }

  if (alerts.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-full text-center p-8 border-2 border-dashed border-green-200 rounded-3xl bg-green-50/50">
        <h3 className="text-xl font-bold text-green-800 mb-2">No Active Emergencies</h3>
        <p className="text-green-600 text-sm">All zones are currently clear and secure.</p>
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6">
      {alerts.map((alert) => (
        <div key={alert.id} className="bg-white p-6 rounded-2xl border border-red-100 shadow-md shadow-red-50/50 flex flex-col gap-4 relative overflow-hidden">
          <div className="absolute top-0 left-0 w-1.5 h-full bg-red-500"></div>
          
          <div className="flex justify-between items-start pl-2">
            <div>
              {/* Mapped to 'sos_type' and capitalized */}
              <h3 className="text-lg font-bold text-gray-900 capitalize">
                {alert.sos_type ? `${alert.sos_type} Emergency` : 'Emergency SOS'}
              </h3>
              {/* Mapped to 'user_id' */}
              <p className="text-sm text-gray-500 mt-0.5">
                Reported by: <span className="font-semibold">{alert.user_id || 'Unknown User'}</span>
              </p>
            </div>
            {/* Mapped to 'status' */}
            <span className="px-3 py-1 bg-red-50 text-red-600 text-[10px] font-black uppercase tracking-wider rounded-full border border-red-100 animate-pulse">
              {alert.status || 'Urgent'}
            </span>
          </div>
          
          {/* Mapped to 'message' */}
          <p className="text-gray-700 bg-orange-50/50 p-4 rounded-xl border border-orange-100/50 ml-2 font-medium">
            "{alert.message || 'No description provided.'}"
          </p>
          
          <div className="ml-2 mt-1 flex flex-col">
            <span className="text-xs text-gray-500 font-semibold uppercase tracking-wider">Location Coordinates:</span>
            {/* Mapped to 'latitude' and 'longitude' */}
            <span className="text-sm font-mono text-gray-800 mt-0.5">
              {alert.latitude && alert.longitude 
                ? `${alert.latitude.toFixed(6)}, ${alert.longitude.toFixed(6)}` 
                : 'Fetching coordinates...'}
            </span>
          </div>

          <div className="flex flex-col sm:flex-row gap-3 mt-4 ml-2">
            <button className="flex-1 bg-red-600 hover:bg-red-700 text-white py-2.5 rounded-xl font-semibold cursor-pointer transition-colors shadow-sm shadow-red-200">
              Dispatch
            </button>
            <button 
              className="flex-1 bg-white border border-gray-200 hover:bg-gray-50 text-gray-700 py-2.5 rounded-xl font-semibold cursor-pointer transition-colors"
              onClick={() => {
                if(alert.latitude && alert.longitude) {
                  window.open(`https://www.google.com/maps/search/?api=1&query=${alert.latitude},${alert.longitude}`, '_blank');
                }
              }}
            >
              View Map
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}
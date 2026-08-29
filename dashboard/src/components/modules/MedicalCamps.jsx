import React from 'react';
import { Tent, Phone, MapPin } from 'lucide-react';
import { MEDICAL_CAMPS } from '../../lib/medicalCamps';

export default function MedicalCamps() {
  const camps = MEDICAL_CAMPS;

  return (
    <div className="flex flex-col gap-6 h-full">
      <div className="flex justify-between items-center bg-white p-6 rounded-2xl border border-orange-100 shadow-sm">
        <div>
          <h3 className="text-lg font-bold text-gray-900">Medical Camp Management</h3>
          <p className="text-sm text-gray-500">Monitor doctor availability, medicine stocks, and emergency bed capacities</p>
        </div>
        <button className="bg-orange-500 hover:bg-orange-600 text-white px-4 py-2.5 rounded-xl text-sm font-bold cursor-pointer transition-colors shadow-sm shadow-orange-200">
          + Deploy New Camp
        </button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {camps.map((camp) => (
          <div key={camp.id} className="bg-white p-6 rounded-2xl border border-orange-100 shadow-sm flex flex-col justify-between">
            <div>
              <div className="flex justify-between items-start mb-4">
                <div className="w-10 h-10 bg-orange-100 rounded-xl flex items-center justify-center text-orange-600">
                  <Tent size={20} />
                </div>
                <span className={`text-[10px] font-black uppercase px-2.5 py-1 rounded-full border ${
                  camp.status === 'Optimal' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'
                }`}>
                  {camp.status}
                </span>
              </div>
              <h4 className="font-bold text-gray-900 text-base">{camp.name}</h4>
              <p className="text-xs text-gray-500 flex items-center gap-1 mt-1">
                <MapPin size={12} /> {camp.location}
              </p>
              
              <div className="my-4 py-4 border-y border-orange-50 grid grid-cols-2 gap-4">
                <div>
                  <p className="text-[10px] uppercase font-bold text-gray-400">Active Doctors</p>
                  <p className="text-lg font-black text-gray-900">{camp.doctors} Specialists</p>
                </div>
                <div>
                  <p className="text-[10px] uppercase font-bold text-gray-400">Medicine Stock</p>
                  <p className="text-lg font-black text-orange-600">{camp.stock}</p>
                </div>
              </div>
            </div>

            <div className="flex gap-2">
              <button className="flex-1 bg-gray-50 hover:bg-gray-100 text-gray-700 py-2 rounded-xl text-xs font-bold cursor-pointer transition-colors border border-gray-200">
                Restock
              </button>
              <button className="flex-1 bg-orange-50 hover:bg-orange-100 text-orange-600 py-2 rounded-xl text-xs font-bold cursor-pointer transition-colors border border-orange-200 flex items-center justify-center gap-1.5">
                <Phone size={12} /> Call Lead
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
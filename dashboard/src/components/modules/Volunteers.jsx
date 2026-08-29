import React from 'react';
import { Phone, MapPin } from 'lucide-react';

export default function Volunteers() {
  const volunteers = [
    { id: 1, name: 'Om Deshmukh', role: 'Crowd Controller', zone: 'Sector A - Alandi', status: 'On Duty', phone: '+91 98111 22334' },
    { id: 2, name: 'Priya Kulkarni', role: 'Medical First Responder', zone: 'Sector B - Hadapsar', status: 'On Duty', phone: '+91 98222 33445' },
    { id: 3, name: 'Amit Shinde', role: 'Lost & Found Lead', zone: 'Sector C - Pune Station', status: 'Standby', phone: '+91 98333 44556' },
  ];

  return (
    <div className="flex flex-col gap-6 h-full">
      <div className="flex justify-between items-center bg-white p-6 rounded-2xl border border-orange-100 shadow-sm">
        <div>
          <h3 className="text-lg font-bold text-gray-900">Field Volunteers Directory</h3>
          <p className="text-sm text-gray-500">Coordinate and assign ground personnel across active pilgrimage zones</p>
        </div>
        <button className="bg-orange-500 hover:bg-orange-600 text-white px-4 py-2.5 rounded-xl text-sm font-bold cursor-pointer transition-colors shadow-sm shadow-orange-200">
          + Register Volunteer
        </button>
      </div>

      <div className="bg-white rounded-2xl border border-orange-100 shadow-sm overflow-hidden">
        <table className="w-full text-left border-collapse">
          <thead>
            <tr className="bg-orange-50/50 border-b border-orange-100 text-xs uppercase font-bold text-gray-500">
              <th className="p-4">Volunteer Name</th>
              <th className="p-4">Role</th>
              <th className="p-4">Assigned Zone</th>
              <th className="p-4">Status</th>
              <th className="p-4 text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100 text-sm">
            {volunteers.map((v) => (
              <tr key={v.id} className="hover:bg-orange-50/30 transition-colors">
                <td className="p-4 font-bold text-gray-900 flex items-center gap-3">
                  <div className="w-9 h-9 bg-orange-100 text-orange-600 rounded-full flex items-center justify-center font-bold text-xs shrink-0">
                    {v.name.charAt(0)}
                  </div>
                  {v.name}
                </td>
                <td className="p-4 text-gray-600 font-medium">{v.role}</td>
                <td className="p-4 text-gray-500 flex items-center gap-1 pt-5">
                  <MapPin size={14} className="text-orange-500" /> {v.zone}
                </td>
                <td className="p-4">
                  <span className={`text-[10px] font-black uppercase px-2.5 py-1 rounded-full ${
                    v.status === 'On Duty' ? 'bg-green-50 text-green-700 border border-green-200' : 'bg-amber-50 text-amber-700 border border-amber-200'
                  }`}>
                    {v.status}
                  </span>
                </td>
                <td className="p-4 text-right">
                  <a href={`tel:${v.phone}`} className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-gray-50 hover:bg-orange-100 text-gray-700 hover:text-orange-600 rounded-lg text-xs font-bold cursor-pointer transition-colors border border-gray-200">
                    <Phone size={12} /> Call
                  </a>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
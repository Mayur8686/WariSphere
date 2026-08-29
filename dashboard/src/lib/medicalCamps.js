// The existing WariSphere medical-camp directory (single source of truth —
// previously inlined inside the MedicalCamps module). Both the Medical
// Camps view and the task-assignment flow read from here, so camp records
// are never duplicated across the codebase.

export const MEDICAL_CAMPS = [
  {
    id: 'camp-alandi-01',
    name: 'Alandi Main Health Post',
    location: 'Near Vitthal Temple Gate 2',
    latitude: 18.6784,
    longitude: 73.8966,
    doctors: 4,
    status: 'Optimal',
    stock: '92%',
    contact: '9822011223',
  },
  {
    id: 'camp-pune-01',
    name: 'Hadapsar Emergency Camp',
    location: 'Pune-Solapur Highway Stop',
    latitude: 18.5089,
    longitude: 73.9260,
    doctors: 2,
    status: 'Low Stock',
    stock: '34%',
    contact: '9822044556',
  },
  {
    id: 'camp-yavat-01',
    name: 'Yavat Transit Medical Unit',
    location: 'Main Highway Checkpoint B',
    latitude: 18.3720,
    longitude: 74.2690,
    doctors: 3,
    status: 'Optimal',
    stock: '85%',
    contact: '9822077889',
  },
];

function haversineKm(lat1, lon1, lat2, lon2) {
  const toRad = (d) => (d * Math.PI) / 180;
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

/**
 * Nearest camp to a coordinate (Haversine). Returns
 *   { id, name, location, contact, doctors, distance_km } | null
 * Compact enough to embed into a task's incident snapshot.
 */
export function nearestCamp(latitude, longitude) {
  if (latitude == null || longitude == null) return null;
  let best = null;
  for (const camp of MEDICAL_CAMPS) {
    const distance = haversineKm(latitude, longitude, camp.latitude, camp.longitude);
    if (!best || distance < best.distance_km) {
      best = {
        id: camp.id,
        name: camp.name,
        location: camp.location,
        contact: camp.contact,
        doctors: camp.doctors,
        distance_km: Math.round(distance * 10) / 10,
      };
    }
  }
  return best;
}

import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";

// Same WariSphere Firebase project as the Authority Dashboard — one
// project, one auth system, two role-gated portals.
const firebaseConfig = {
  apiKey: "AIzaSyCHN9vvrb3FMLnIjFG-QPmrKg26gn9DYkA",
  authDomain: "warisathi-66fa1.firebaseapp.com",
  projectId: "warisathi-66fa1",
  storageBucket: "warisathi-66fa1.firebasestorage.app",
  messagingSenderId: "68504018176",
  appId: "1:68504018176:web:1538e7349671a61a9027e5"
};

const app = initializeApp(firebaseConfig);

export const db = getFirestore(app);
export { app };

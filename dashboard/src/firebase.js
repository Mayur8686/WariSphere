import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyCHN9vvrb3FMLnIjFG-QPmrKg26gn9DYkA",
  authDomain: "warisathi-66fa1.firebaseapp.com",
  projectId: "warisathi-66fa1",
  storageBucket: "warisathi-66fa1.firebasestorage.app",
  messagingSenderId: "68504018176",
  appId: "1:68504018176:web:1538e7349671a61a9027e5"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize Cloud Firestore and export it so your components can use it
export const db = getFirestore(app);
/* ─── Imperial & Metric Challenge · Shared Firebase Config ───
   Every page that talks to Firestore/Auth imports app/db/auth from
   here instead of duplicating firebaseConfig. One place to update
   if the project or SDK version ever changes.                     */

import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js';
import { getFirestore } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js';
import { getAuth } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js';

const firebaseConfig = {
  apiKey: "AIzaSyBiXcIHedwHbD7SVpTedQPH9UxJaVSD9Jo",
  authDomain: "osmembership-bc876.firebaseapp.com",
  projectId: "osmembership-bc876",
  storageBucket: "osmembership-bc876.firebasestorage.app",
  messagingSenderId: "265215395375",
  appId: "1:265215395375:web:51021ab5e1022134afe8da",
  measurementId: "G-7WZ5413X3B"
};

export const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const auth = getAuth(app);

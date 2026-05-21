import { initializeApp } from "firebase/app";
import {
  initializeFirestore,
  persistentLocalCache,
  persistentMultipleTabManager,
} from "firebase/firestore";
import {
  getAuth,
  GoogleAuthProvider,
  browserLocalPersistence,
  setPersistence,
} from "firebase/auth";

const firebaseConfig = {
  apiKey: "AIzaSyBT7oPDKTvevw3U9YONlSxh2JfOK7MADaY",
  authDomain: "einkaufsliste-e9d01.firebaseapp.com",
  projectId: "einkaufsliste-e9d01",
  storageBucket: "einkaufsliste-e9d01.firebasestorage.app",
  messagingSenderId: "793752247978",
  appId: "1:793752247978:web:320fda77972c41b9657ad3",
};

const app = initializeApp(firebaseConfig);

export const db = initializeFirestore(app, {
  localCache: persistentLocalCache({
    tabManager: persistentMultipleTabManager(),
  }),
});

export const auth = getAuth(app);
setPersistence(auth, browserLocalPersistence).catch(console.error);
export const googleProvider = new GoogleAuthProvider();

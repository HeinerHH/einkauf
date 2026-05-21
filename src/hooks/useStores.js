import { useState, useEffect } from "react";
import {
  collection,
  onSnapshot,
  addDoc,
  doc,
  updateDoc,
  deleteDoc,
  serverTimestamp,
} from "firebase/firestore";
import { db } from "../firebase";

// GPS-Erkennung ist jetzt in useActiveStore (nur on-demand).
// Dieser Hook liefert nur noch die Markt-Liste + CRUD.

export function useStores(householdId) {
  const [stores, setStores] = useState([]);

  useEffect(() => {
    if (!householdId) return;
    return onSnapshot(
      collection(db, "households", householdId, "stores"),
      (snap) => {
        setStores(snap.docs.map((d) => ({ id: d.id, ...d.data() })));
      },
    );
  }, [householdId]);

  const addStore = (name, pos) =>
    householdId &&
    addDoc(collection(db, "households", householdId, "stores"), {
      name,
      lat: pos?.lat ?? null,
      lng: pos?.lng ?? null,
      itemOrder: {},
      createdAt: serverTimestamp(),
    });

  const updateStore = (storeId, updates) =>
    householdId &&
    storeId &&
    updateDoc(doc(db, "households", householdId, "stores", storeId), updates);

  const saveStoreOrder = (storeId, newOrder) =>
    householdId &&
    storeId &&
    updateDoc(doc(db, "households", householdId, "stores", storeId), {
      itemOrder: newOrder,
    });

  const deleteStore = (storeId) =>
    householdId &&
    deleteDoc(doc(db, "households", householdId, "stores", storeId));

  return { stores, addStore, updateStore, saveStoreOrder, deleteStore };
}

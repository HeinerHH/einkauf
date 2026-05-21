import { useState, useEffect } from "react";
import { doc, onSnapshot, setDoc, getDoc } from "firebase/firestore";
import { db } from "../firebase";

export function useHistory(householdId) {
  const [history, setHistory] = useState({});

  useEffect(() => {
    if (!householdId) return;
    return onSnapshot(
      doc(db, "households", householdId, "meta", "history"),
      (snap) => {
        setHistory(snap.exists() ? snap.data() : {});
      },
    );
  }, [householdId]);

  const getSuggestions = (query, currentItems, limit = 6) => {
    if (!query) return [];
    const q = query.toLowerCase();
    const existing = new Set(
      currentItems.map((i) => i.name.toLowerCase().trim()),
    );
    return Object.entries(history)
      .filter(([k]) => k.includes(q) && !existing.has(k))
      .sort((a, b) => b[1].count - a[1].count)
      .slice(0, limit)
      .map(([, v]) => v.display);
  };

  const recordPurchase = async (items) => {
    if (!householdId || !items.length) return;
    const ref = doc(db, "households", householdId, "meta", "history");
    const snap = await getDoc(ref);
    const cur = snap.exists() ? snap.data() : {};
    const updated = { ...cur };
    for (const item of items) {
      const key = item.name.toLowerCase().trim();
      updated[key] = {
        display: item.name.trim(),
        count: (cur[key]?.count ?? 0) + 1,
        lastBought: new Date().toISOString(),
      };
    }
    await setDoc(ref, updated);
  };

  return { getSuggestions, recordPurchase };
}

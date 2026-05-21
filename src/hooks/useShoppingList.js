import { useState, useEffect } from "react";
import { doc, onSnapshot, setDoc, getDoc } from "firebase/firestore";
import { db } from "../firebase";
import { sortByStoreOrder } from "../services/orderingService";

export function useShoppingList(householdId) {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);

  const listRef = householdId
    ? doc(db, "households", householdId, "meta", "list")
    : null;

  useEffect(() => {
    if (!listRef) {
      setLoading(false);
      return;
    }
    return onSnapshot(listRef, (snap) => {
      setItems(snap.exists() ? (snap.data().items ?? []) : []);
      setLoading(false);
    });
  }, [householdId]);

  const save = async (newItems) => {
    if (!listRef) return;
    await setDoc(listRef, { items: newItems }, { merge: true });
  };

  const addItem = async (input) => {
    const name = typeof input === "string" ? input.trim() : input.name?.trim();
    const qty = typeof input === "string" ? "" : (input.qty?.trim() ?? "");
    if (!name) return;
    const snap = await getDoc(listRef);
    const current = snap.exists() ? (snap.data().items ?? []) : [];
    if (current.some((i) => i.name.toLowerCase() === name.toLowerCase()))
      return;
    await save([
      ...current,
      {
        id: crypto.randomUUID(),
        name,
        qty,
        checked: false,
        addedAt: new Date().toISOString(),
        checkedAt: null,
        checkOrder: null,
      },
    ]);
  };

  const editItem = async (id, newName) => {
    const trimmed = newName.trim();
    if (!trimmed) return false;
    if (
      items.some(
        (i) => i.id !== id && i.name.toLowerCase() === trimmed.toLowerCase(),
      )
    )
      return false;
    await save(items.map((i) => (i.id === id ? { ...i, name: trimmed } : i)));
    return true;
  };

  const editItemQty = async (id, newQty) => {
    await save(
      items.map((i) =>
        i.id === id ? { ...i, qty: String(newQty).trim() } : i,
      ),
    );
  };

  const toggleItem = async (id) => {
    const checkedCount = items.filter((i) => i.checked).length;
    await save(
      items.map((i) => {
        if (i.id !== id) return i;
        const nowChecked = !i.checked;
        return {
          ...i,
          checked: nowChecked,
          checkedAt: nowChecked ? new Date().toISOString() : null,
          checkOrder: nowChecked ? checkedCount : null,
        };
      }),
    );
  };

  const removeItem = async (id) => save(items.filter((i) => i.id !== id));

  const finishShopping = async () => {
    const checked = items
      .filter((i) => i.checked)
      .sort((a, b) => (a.checkOrder ?? 0) - (b.checkOrder ?? 0));
    const unchecked = items.filter((i) => !i.checked);
    await save(unchecked);
    return checked;
  };

  const getSortedItems = (storeOrder) => ({
    unchecked: sortByStoreOrder(
      items.filter((i) => !i.checked),
      storeOrder,
    ),
    checked: items
      .filter((i) => i.checked)
      .sort((a, b) => (a.checkOrder ?? 0) - (b.checkOrder ?? 0)),
  });

  return {
    items,
    loading,
    addItem,
    editItem,
    editItemQty,
    toggleItem,
    removeItem,
    finishShopping,
    getSortedItems,
  };
}

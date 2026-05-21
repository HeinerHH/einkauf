import { useState, useEffect } from "react";
import { onAuthStateChanged, signOut } from "firebase/auth";
import { auth } from "./firebase";
import { useShoppingList } from "./hooks/useShoppingList";
import { useStores } from "./hooks/useStores";
import { useHistory } from "./hooks/useHistory";
import { useHousehold } from "./hooks/useHousehold";
import { useActiveStore } from "./hooks/useActiveStore";
import { computeNewOrder } from "./services/orderingService";
import Login from "./components/Login";
import Onboarding from "./components/Onboarding";
import HouseholdInfo from "./components/HouseholdInfo";
import ShoppingList from "./components/ShoppingList";
import StoreBar from "./components/StoreBar";

const CART = "\u{1F6D2}";
const HOUSE = "\u{1F3E0}";
const SUN = "\u2600";
const MOON = "\u{1F319}";

const getTheme = () => {
  const s = localStorage.getItem("theme");
  if (s === "light" || s === "dark") return s;
  return window.matchMedia?.("(prefers-color-scheme: dark)").matches
    ? "dark"
    : "light";
};

export default function App() {
  const [user, setUser] = useState(undefined);
  const [theme, setTheme] = useState(getTheme);
  const [showHouseholdInfo, setShowHouseholdInfo] = useState(false);

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    localStorage.setItem("theme", theme);
  }, [theme]);

  const {
    householdId,
    household,
    loading: hLoading,
    createHousehold,
    joinHousehold,
    generateJoinCode,
    leaveHousehold,
  } = useHousehold(user);

  // Aktiver Markt – geteilt via Firestore, nicht localStorage
  const {
    activeStoreId,
    setActiveStoreId,
    detecting,
    detectMsg,
    detectNearestStore,
  } = useActiveStore(householdId);

  // Abgeleitetes Store-Objekt aus der Stores-Liste
  const { stores, addStore, updateStore, saveStoreOrder, deleteStore } =
    useStores(householdId);

  const activeStore = stores.find((s) => s.id === activeStoreId) ?? null;

  const {
    items,
    loading,
    addItem,
    editItem,
    editItemQty,
    toggleItem,
    removeItem,
    finishShopping,
    getSortedItems,
  } = useShoppingList(householdId);

  const { getSuggestions, recordPurchase } = useHistory(householdId);

  useEffect(() => onAuthStateChanged(auth, (u) => setUser(u ?? null)), []);

  // Markt wählen (manuell oder nach GPS-Erkennung)
  const handleSelectStore = (s) => setActiveStoreId(s?.id ?? null);

  // GPS-Erkennung: nur auf expliziten Wunsch
  const handleDetect = async () => {
    const result = await detectNearestStore(stores);
    if (!result) {
      alert(
        "Kein bekannter Markt in der Naehe gefunden.\nTipp: Adresse im Markt-Dropdown hinterlegen.",
      );
      return;
    }
    const { store, distance } = result;
    if (store.id === activeStoreId) {
      alert(`Du bist bereits bei \"${store.name}\" (${distance}m entfernt).`);
      return;
    }
    const ok = window.confirm(
      `\u{1F4CD} ${store.name} erkannt (${distance}m entfernt).\n\nMarkt wechseln und Liste neu sortieren?`,
    );
    if (ok) await setActiveStoreId(store.id);
  };

  const handleFinish = async () => {
    const checked = await finishShopping();
    if (activeStore && checked.length) {
      const newOrder = computeNewOrder(checked, activeStore.itemOrder ?? {});
      await saveStoreOrder(activeStore.id, newOrder);
    }
    await recordPurchase(checked);
  };

  if (user === undefined || (user && hLoading))
    return <div className="loading">{"\u{23F3}"}</div>;

  if (!user) return <Login />;

  if (!householdId)
    return (
      <Onboarding
        user={user}
        onCreate={createHousehold}
        onJoin={joinHousehold}
        onLogout={() => signOut(auth)}
      />
    );

  return (
    <div className="app">
      <header className="app-header">
        <h1>{CART} Einkaufsliste</h1>
        <div className="header-actions">
          <button
            className="btn-icon"
            onClick={() => setShowHouseholdInfo(true)}
            title="Haushalt"
          >
            {HOUSE}
          </button>
          <button
            className="btn-icon"
            onClick={() => setTheme((t) => (t === "dark" ? "light" : "dark"))}
            title="Hell/Dunkel"
          >
            {theme === "dark" ? SUN : MOON}
          </button>
        </div>
      </header>

      <StoreBar
        stores={stores}
        activeStore={activeStore}
        detecting={detecting}
        detectMsg={detectMsg}
        onSelectStore={handleSelectStore}
        onDetect={handleDetect}
        onAddStore={addStore}
        onUpdateStore={updateStore}
        onDeleteStore={deleteStore}
      />

      <ShoppingList
        items={items}
        loading={loading}
        activeStore={activeStore}
        onToggle={toggleItem}
        onRemove={removeItem}
        onEdit={editItem}
        onEditQty={editItemQty}
        onAdd={addItem}
        onFinish={handleFinish}
        getSuggestions={getSuggestions}
        getSortedItems={getSortedItems}
      />

      {showHouseholdInfo && household && (
        <HouseholdInfo
          user={user}
          household={household}
          onClose={() => setShowHouseholdInfo(false)}
          onGenerateCode={generateJoinCode}
          onLeave={leaveHousehold}
        />
      )}
    </div>
  );
}

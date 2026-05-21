import { useState, useRef } from "react";
import { geocodeAddress } from "../services/geocoding";

const PIN = "\u{1F4CD}";
const STORE = "\u{1F3EA}";
const PLUS = "\uFF0B";
const UP = "\u25B2";
const DOWN = "\u25BC";
const CHECK = "\u2713";
const PENCIL = "\u270F";
const TRASH = "\u{1F5D1}";
const X_MARK = "\u2715";
const SEARCH = "\u{1F50D}";
const SPIN = "\u29D7";
const RADAR = "\u{1F6F0}"; // GPS-Erkennung-Button

// ──────────────────────────────────────────────────────────────────────────
// Mini-Komponente: Adress-Suche
// ──────────────────────────────────────────────────────────────────────────
function AddressSearch({ onSelect, currentLat, currentLng }) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const debounceRef = useRef(null);

  const search = async (q) => {
    setError("");
    if (!q || q.trim().length < 3) {
      setResults(null);
      return;
    }
    setBusy(true);
    try {
      const res = await geocodeAddress(q);
      setResults(res?.length ? res : []);
      if (!res?.length) setError("Keine Ergebnisse – bitte genauer suchen.");
    } catch {
      setError("Suche fehlgeschlagen.");
    } finally {
      setBusy(false);
    }
  };

  const handleChange = (e) => {
    const q = e.target.value;
    setQuery(q);
    clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => search(q), 700);
  };

  return (
    <div className="addr-search">
      <div className="addr-row">
        <input
          className="addr-input"
          value={query}
          onChange={handleChange}
          placeholder='z.B. "Rewe Hanau Freiheitsplatz"'
        />
        {busy && <span className="addr-spin">{SPIN}</span>}
      </div>
      {error && <p className="addr-error">{error}</p>}
      {results?.length > 0 && (
        <ul className="addr-results">
          {results.map((r, i) => (
            <li key={i}>
              <button
                className="addr-result-btn"
                onClick={() => {
                  onSelect(r.lat, r.lng, r.label);
                  setResults(null);
                  setQuery("");
                }}
              >
                {PIN} {r.label}
              </button>
            </li>
          ))}
        </ul>
      )}
      {currentLat && currentLng && (
        <p className="addr-current">
          {CHECK} Koordinaten gesetzt ({currentLat.toFixed(4)},{" "}
          {currentLng.toFixed(4)})
        </p>
      )}
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// Haupt-Komponente: StoreBar
// ──────────────────────────────────────────────────────────────────────────
export default function StoreBar({
  stores,
  activeStore,
  detecting,
  detectMsg,
  onSelectStore,
  onDetect,
  onAddStore,
  onUpdateStore,
  onDeleteStore,
}) {
  const [open, setOpen] = useState(false);
  const [newName, setNewName] = useState("");
  const [newLat, setNewLat] = useState(null);
  const [newLng, setNewLng] = useState(null);
  const [showAddrNew, setShowAddrNew] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [editingValue, setEditingValue] = useState("");
  const [editLat, setEditLat] = useState(null);
  const [editLng, setEditLng] = useState(null);
  const [showAddrEdit, setShowAddrEdit] = useState(false);

  const handleAdd = () => {
    if (!newName.trim()) return;
    onAddStore(
      newName.trim(),
      newLat && newLng ? { lat: newLat, lng: newLng } : null,
    );
    setNewName("");
    setNewLat(null);
    setNewLng(null);
    setShowAddrNew(false);
  };

  const startEdit = (s) => {
    setEditingId(s.id);
    setEditingValue(s.name);
    setEditLat(s.lat ?? null);
    setEditLng(s.lng ?? null);
    setShowAddrEdit(false);
  };

  const saveEdit = async (e) => {
    if (e) e.stopPropagation();
    if (editingValue.trim() && editingId) {
      const u = { name: editingValue.trim() };
      if (editLat && editLng) {
        u.lat = editLat;
        u.lng = editLng;
      }
      await onUpdateStore(editingId, u);
    }
    setEditingId(null);
    setEditLat(null);
    setEditLng(null);
    setShowAddrEdit(false);
  };

  const del = async (e, s) => {
    e.stopPropagation();
    if (window.confirm('"' + s.name + '" loeschen?')) await onDeleteStore(s.id);
  };

  const label = activeStore
    ? STORE + " " + activeStore.name
    : STORE + " Markt waehlen";

  return (
    <div className="store-bar">
      {/* ── Kopfzeile: Markt-Label + GPS-Button ── */}
      <div className="store-bar-head">
        <button className="store-btn" onClick={() => setOpen((v) => !v)}>
          {label} <span className="store-chevron">{open ? UP : DOWN}</span>
        </button>
        <button
          className={"detect-btn" + (detecting ? " detecting" : "")}
          onClick={onDetect}
          disabled={detecting}
          title="Markt per GPS erkennen"
        >
          {detecting ? SPIN : RADAR}
        </button>
      </div>

      {detectMsg && <div className="detect-msg">{detectMsg}</div>}

      {open && (
        <div className="store-picker">
          {/* ── Markt-Liste ── */}
          {stores.map((s) =>
            editingId === s.id ? (
              <div key={s.id} className="store-edit-block">
                <div className="store-option editing">
                  <input
                    className="store-edit-input"
                    value={editingValue}
                    onChange={(e) => setEditingValue(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === "Enter") saveEdit();
                      if (e.key === "Escape") setEditingId(null);
                    }}
                    autoFocus
                    onClick={(e) => e.stopPropagation()}
                  />
                  <button className="store-action" onClick={saveEdit}>
                    {CHECK}
                  </button>
                  <button
                    className="store-action no"
                    onClick={(e) => {
                      e.stopPropagation();
                      setEditingId(null);
                    }}
                  >
                    {X_MARK}
                  </button>
                </div>
                <button
                  className="addr-toggle"
                  onClick={() => setShowAddrEdit((v) => !v)}
                >
                  {SEARCH} Adresse{" "}
                  {showAddrEdit ? "ausblenden" : "aktualisieren"}
                </button>
                {showAddrEdit && (
                  <AddressSearch
                    currentLat={editLat}
                    currentLng={editLng}
                    onSelect={(lat, lng) => {
                      setEditLat(lat);
                      setEditLng(lng);
                    }}
                  />
                )}
              </div>
            ) : (
              <div key={s.id} className="store-option-row">
                <button
                  className={
                    "store-option " + (activeStore?.id === s.id ? "active" : "")
                  }
                  onClick={() => {
                    onSelectStore(s);
                    setOpen(false);
                  }}
                >
                  {s.name}
                  {!s.lat && <span className="store-no-gps"> (kein GPS)</span>}
                </button>
                <button
                  className="store-mini-btn"
                  title="Bearbeiten"
                  onClick={(e) => {
                    e.stopPropagation();
                    startEdit(s);
                  }}
                >
                  {PENCIL}
                </button>
                <button
                  className="store-mini-btn"
                  title="Loeschen"
                  onClick={(e) => del(e, s)}
                >
                  {TRASH}
                </button>
              </div>
            ),
          )}

          <button
            className="store-option store-none"
            onClick={() => {
              onSelectStore(null);
              setOpen(false);
            }}
          >
            Kein Markt
          </button>

          {/* ── Neuen Markt anlegen ── */}
          <div className="store-add-block">
            <div className="store-add-row">
              <input
                value={newName}
                onChange={(e) => setNewName(e.target.value)}
                placeholder="Marktname (z.B. Rewe Hanau)"
                onKeyDown={(e) => e.key === "Enter" && handleAdd()}
                className="store-add-input"
              />
              <button
                className="store-add-btn"
                onClick={handleAdd}
                disabled={!newName.trim()}
              >
                {PLUS}
              </button>
            </div>
            <button
              className="addr-toggle"
              onClick={() => setShowAddrNew((v) => !v)}
            >
              {SEARCH} Adresse suchen {showAddrNew ? "ausblenden" : ""}
            </button>
            {showAddrNew && (
              <AddressSearch
                currentLat={newLat}
                currentLng={newLng}
                onSelect={(lat, lng, label) => {
                  setNewLat(lat);
                  setNewLng(lng);
                  if (!newName.trim()) setNewName(label.split(",")[0].trim());
                }}
              />
            )}
          </div>
        </div>
      )}
    </div>
  );
}

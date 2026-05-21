# ===========================================================================
# Feature-Update: Editieren von Artikel/Markt + Light/Dark-Mode + neue Farben
# ASCII-only, schreibt UTF-8 ohne BOM.
# ===========================================================================

$ErrorActionPreference = 'Stop'
Write-Host "Aktualisiere Features ..." -ForegroundColor Cyan

function Write-Utf8([string]$Path, [string]$Content) {
    $full = Join-Path (Get-Location) $Path
    $dir = Split-Path $full -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($full, $Content, $utf8NoBom)
    Write-Host "  geschrieben: $Path"
}

# --- src/hooks/useShoppingList.js (mit editItem) ---------------------------
Write-Utf8 'src\hooks\useShoppingList.js' @'
import { useState, useEffect } from "react"
import { doc, onSnapshot, setDoc, getDoc } from "firebase/firestore"
import { db } from "../firebase"
import { sortByStoreOrder } from "../services/orderingService"

export function useShoppingList(uid) {
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)

  const listRef = uid ? doc(db, "users", uid, "meta", "list") : null

  useEffect(() => {
    if (!listRef) return
    const unsub = onSnapshot(listRef, snap => {
      setItems(snap.exists() ? (snap.data().items ?? []) : [])
      setLoading(false)
    })
    return unsub
  }, [uid])

  const saveItems = async (newItems) => {
    if (!listRef) return
    await setDoc(listRef, { items: newItems }, { merge: true })
  }

  const addItem = async (name) => {
    const trimmed = name.trim()
    if (!trimmed) return
    const snap = await getDoc(listRef)
    const current = snap.exists() ? (snap.data().items ?? []) : []
    if (current.some(i => i.name.toLowerCase() === trimmed.toLowerCase())) return
    const newItems = [...current, {
      id: crypto.randomUUID(),
      name: trimmed,
      checked: false,
      addedAt: new Date().toISOString(),
      checkedAt: null,
      checkOrder: null
    }]
    await saveItems(newItems)
  }

  const editItem = async (id, newName) => {
    const trimmed = newName.trim()
    if (!trimmed) return false
    if (items.some(i => i.id !== id && i.name.toLowerCase() === trimmed.toLowerCase())) {
      return false
    }
    const newItems = items.map(i => i.id === id ? { ...i, name: trimmed } : i)
    await saveItems(newItems)
    return true
  }

  const toggleItem = async (id) => {
    const checkedCount = items.filter(i => i.checked).length
    const newItems = items.map(i => {
      if (i.id !== id) return i
      const nowChecked = !i.checked
      return {
        ...i,
        checked: nowChecked,
        checkedAt: nowChecked ? new Date().toISOString() : null,
        checkOrder: nowChecked ? checkedCount : null
      }
    })
    await saveItems(newItems)
  }

  const removeItem = async (id) => {
    await saveItems(items.filter(i => i.id !== id))
  }

  const finishShopping = async () => {
    const checked = items
      .filter(i => i.checked)
      .sort((a, b) => (a.checkOrder ?? 0) - (b.checkOrder ?? 0))
    const unchecked = items.filter(i => !i.checked)
    await saveItems(unchecked)
    return checked
  }

  const getSortedItems = (storeOrder) => {
    const unchecked = items.filter(i => !i.checked)
    const checked   = items.filter(i =>  i.checked)
      .sort((a, b) => (a.checkOrder ?? 0) - (b.checkOrder ?? 0))
    return {
      unchecked: sortByStoreOrder(unchecked, storeOrder),
      checked
    }
  }

  return { items, loading, addItem, editItem, toggleItem, removeItem, finishShopping, getSortedItems }
}
'@

# --- src/hooks/useStores.js (mit updateStore) ------------------------------
Write-Utf8 'src\hooks\useStores.js' @'
import { useState, useEffect } from "react"
import {
  collection, onSnapshot, addDoc, doc, updateDoc, deleteDoc, serverTimestamp
} from "firebase/firestore"
import { db } from "../firebase"
import { distanceMeters } from "../services/orderingService"

const DETECT_RADIUS = 150

export function useStores(uid, position) {
  const [stores, setStores] = useState([])
  const [detectedStore, setDetectedStore] = useState(null)

  useEffect(() => {
    if (!uid) return
    const ref = collection(db, "users", uid, "stores")
    const unsub = onSnapshot(ref, snap => {
      setStores(snap.docs.map(d => ({ id: d.id, ...d.data() })))
    })
    return unsub
  }, [uid])

  useEffect(() => {
    if (!position || stores.length === 0) return
    let nearest = null
    let nearestDist = Infinity
    for (const store of stores) {
      if (!store.lat) continue
      const dist = distanceMeters(position.lat, position.lng, store.lat, store.lng)
      if (dist < nearestDist) { nearestDist = dist; nearest = store }
    }
    setDetectedStore(nearestDist < DETECT_RADIUS ? nearest : null)
  }, [position, stores])

  const addStore = async (name, currentPosition) => {
    if (!uid) return
    const ref = collection(db, "users", uid, "stores")
    await addDoc(ref, {
      name,
      lat: currentPosition?.lat ?? null,
      lng: currentPosition?.lng ?? null,
      itemOrder: {},
      createdAt: serverTimestamp()
    })
  }

  const updateStore = async (storeId, updates) => {
    if (!uid || !storeId) return
    const ref = doc(db, "users", uid, "stores", storeId)
    await updateDoc(ref, updates)
  }

  const saveStoreOrder = async (storeId, newOrder) => {
    if (!uid || !storeId) return
    const ref = doc(db, "users", uid, "stores", storeId)
    await updateDoc(ref, { itemOrder: newOrder })
  }

  const deleteStore = async (storeId) => {
    if (!uid) return
    await deleteDoc(doc(db, "users", uid, "stores", storeId))
  }

  return { stores, detectedStore, addStore, updateStore, saveStoreOrder, deleteStore }
}
'@

# --- src/components/ItemRow.jsx (mit Edit-Modus) ---------------------------
Write-Utf8 'src\components\ItemRow.jsx' @'
import { useState } from "react"

const CHECK  = "\u2713"
const PENCIL = "\u270F"
const X_MARK = "\u2715"

export default function ItemRow({ item, onToggle, onRemove, onEdit }) {
  const [editing, setEditing] = useState(false)
  const [value, setValue] = useState(item.name)

  const startEdit = (e) => {
    e.stopPropagation()
    setValue(item.name)
    setEditing(true)
  }

  const save = async (e) => {
    if (e) e.stopPropagation()
    const trimmed = value.trim()
    if (!trimmed) { setEditing(false); return }
    if (trimmed === item.name) { setEditing(false); return }
    const ok = await onEdit(item.id, trimmed)
    if (ok === false) {
      alert("Es gibt schon einen Artikel mit diesem Namen.")
      return
    }
    setEditing(false)
  }

  const cancel = (e) => {
    if (e) e.stopPropagation()
    setEditing(false)
  }

  let pressTimer = null
  const handlePressStart = () => {
    if (editing) return
    pressTimer = setTimeout(() => {
      if (window.confirm("\"" + item.name + "\" loeschen?")) onRemove(item.id)
    }, 600)
  }
  const handlePressEnd = () => clearTimeout(pressTimer)

  if (editing) {
    return (
      <div className="item-row editing">
        <div className="item-check">{PENCIL}</div>
        <input
          className="item-edit-input"
          value={value}
          onChange={(e) => setValue(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") save()
            if (e.key === "Escape") cancel()
          }}
          autoFocus
          onClick={(e) => e.stopPropagation()}
        />
        <button className="item-action ok" onClick={save} aria-label="Speichern">{CHECK}</button>
        <button className="item-action no" onClick={cancel} aria-label="Abbrechen">{X_MARK}</button>
      </div>
    )
  }

  return (
    <div
      className={"item-row " + (item.checked ? "checked" : "")}
      onPointerDown={handlePressStart}
      onPointerUp={handlePressEnd}
      onPointerLeave={handlePressEnd}
      onClick={() => onToggle(item.id)}
    >
      <div className={"item-check " + (item.checked ? "done" : "")}>
        {item.checked ? CHECK : ""}
      </div>
      <span className="item-name">{item.name}</span>
      <button className="item-edit-btn" onClick={startEdit} aria-label="Bearbeiten">
        {PENCIL}
      </button>
    </div>
  )
}
'@

# --- src/components/StoreBar.jsx (mit Rename/Delete) ----------------------
Write-Utf8 'src\components\StoreBar.jsx' @'
import { useState } from "react"

const PIN    = "\u{1F4CD}"
const STORE  = "\u{1F3EA}"
const PLUS   = "\uFF0B"
const UP     = "\u25B2"
const DOWN   = "\u25BC"
const CHECK  = "\u2713"
const PENCIL = "\u270F"
const TRASH  = "\u{1F5D1}"
const X_MARK = "\u2715"

export default function StoreBar({
  stores, activeStore, detectedStore,
  onSelectStore, onAddStore, onUpdateStore, onDeleteStore, position
}) {
  const [showPicker, setShowPicker] = useState(false)
  const [newStoreName, setNewStoreName] = useState("")
  const [editingId, setEditingId] = useState(null)
  const [editingValue, setEditingValue] = useState("")

  const handleAdd = () => {
    if (!newStoreName.trim()) return
    onAddStore(newStoreName.trim(), position)
    setNewStoreName("")
  }

  const startRename = (e, store) => {
    e.stopPropagation()
    setEditingId(store.id)
    setEditingValue(store.name)
  }

  const saveRename = async (e) => {
    if (e) e.stopPropagation()
    const trimmed = editingValue.trim()
    if (trimmed && editingId) {
      await onUpdateStore(editingId, { name: trimmed })
    }
    setEditingId(null)
  }

  const cancelRename = (e) => {
    if (e) e.stopPropagation()
    setEditingId(null)
  }

  const updateGps = async (e, store) => {
    e.stopPropagation()
    if (!position) {
      alert("GPS-Position noch nicht verfuegbar.")
      return
    }
    if (window.confirm("GPS-Position fuer \"" + store.name + "\" jetzt aktualisieren?")) {
      await onUpdateStore(store.id, { lat: position.lat, lng: position.lng })
    }
  }

  const deleteStore = async (e, store) => {
    e.stopPropagation()
    if (window.confirm("\"" + store.name + "\" und die gelernte Reihenfolge wirklich loeschen?")) {
      await onDeleteStore(store.id)
    }
  }

  const label = activeStore
    ? (detectedStore?.id === activeStore.id ? PIN + " " : STORE + " ") + activeStore.name
    : STORE + " Markt waehlen"

  return (
    <div className="store-bar">
      <button className="store-btn" onClick={() => setShowPicker(v => !v)}>
        {label}
        <span className="store-chevron">{showPicker ? UP : DOWN}</span>
      </button>
      {showPicker && (
        <div className="store-picker">
          {detectedStore && (
            <div className="detected-hint">
              {PIN} {detectedStore.name} in der Naehe erkannt
            </div>
          )}
          {stores.map(s => {
            if (editingId === s.id) {
              return (
                <div key={s.id} className="store-option editing">
                  <input
                    className="store-edit-input"
                    value={editingValue}
                    onChange={(e) => setEditingValue(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === "Enter") saveRename()
                      if (e.key === "Escape") cancelRename()
                    }}
                    autoFocus
                    onClick={(e) => e.stopPropagation()}
                  />
                  <button className="store-action ok" onClick={saveRename}>{CHECK}</button>
                  <button className="store-action no" onClick={cancelRename}>{X_MARK}</button>
                </div>
              )
            }
            return (
              <div key={s.id} className="store-option-row">
                <button
                  className={"store-option " + (activeStore?.id === s.id ? "active" : "")}
                  onClick={() => { onSelectStore(s); setShowPicker(false) }}
                >
                  {s.name}{detectedStore?.id === s.id ? " " + PIN : ""}
                </button>
                <button
                  className="store-mini-btn"
                  title="Umbenennen"
                  onClick={(e) => startRename(e, s)}
                >
                  {PENCIL}
                </button>
                <button
                  className="store-mini-btn"
                  title="GPS-Position aktualisieren"
                  onClick={(e) => updateGps(e, s)}
                >
                  {PIN}
                </button>
                <button
                  className="store-mini-btn"
                  title="Loeschen"
                  onClick={(e) => deleteStore(e, s)}
                >
                  {TRASH}
                </button>
              </div>
            )
          })}
          <button
            className="store-option store-none"
            onClick={() => { onSelectStore(null); setShowPicker(false) }}
          >
            Kein Markt
          </button>
          <div className="store-add-row">
            <input
              value={newStoreName}
              onChange={e => setNewStoreName(e.target.value)}
              placeholder="Neuer Markt..."
              onKeyDown={e => e.key === "Enter" && handleAdd()}
              className="store-add-input"
            />
            <button className="store-add-btn" onClick={handleAdd}>{PLUS}</button>
          </div>
          {position && (
            <div className="store-gps-hint">
              {CHECK} GPS aktiv - Position wird beim Anlegen gespeichert
            </div>
          )}
        </div>
      )}
    </div>
  )
}
'@

# --- src/components/ShoppingList.jsx (onEdit durchreichen) ----------------
Write-Utf8 'src\components\ShoppingList.jsx' @'
import { useState } from "react"
import ItemRow from "./ItemRow"
import AddItem from "./AddItem"

const CART  = "\u{1F6D2}"
const FLAG  = "\u{1F3C1}"
const DOWN  = "\u25BC"
const RIGHT = "\u25B6"
const PLUS  = "\uFF0B"

export default function ShoppingList({
  items, loading, activeStore,
  onToggle, onRemove, onEdit, onAdd, onFinish,
  getSuggestions, getSortedItems
}) {
  const [showChecked, setShowChecked] = useState(true)
  if (loading) return <div className="loading">Lade...</div>
  const storeOrder = activeStore?.itemOrder ?? {}
  const { unchecked, checked } = getSortedItems(storeOrder)
  return (
    <div className="list-container">
      {unchecked.length === 0 && checked.length === 0 && (
        <div className="empty-hint">
          Tippe unten auf <strong>{PLUS}</strong> um loszulegen {CART}
        </div>
      )}
      {unchecked.map(item => (
        <ItemRow
          key={item.id} item={item}
          onToggle={onToggle} onRemove={onRemove} onEdit={onEdit}
        />
      ))}
      {checked.length > 0 && (
        <>
          <button className="section-toggle" onClick={() => setShowChecked(v => !v)}>
            {showChecked ? DOWN : RIGHT} Erledigt ({checked.length})
          </button>
          {showChecked && checked.map(item => (
            <ItemRow
              key={item.id} item={item}
              onToggle={onToggle} onRemove={onRemove} onEdit={onEdit}
            />
          ))}
          <button className="btn-finish" onClick={onFinish}>
            {FLAG} Einkauf abschliessen
          </button>
        </>
      )}
      <AddItem onAdd={onAdd} getSuggestions={getSuggestions} currentItems={items} />
    </div>
  )
}
'@

# --- src/App.jsx (Theme-Toggle, neue Props) -------------------------------
Write-Utf8 'src\App.jsx' @'
import { useState, useEffect } from "react"
import { onAuthStateChanged, signOut } from "firebase/auth"
import { auth } from "./firebase"
import { useShoppingList } from "./hooks/useShoppingList"
import { useStores }       from "./hooks/useStores"
import { useHistory }      from "./hooks/useHistory"
import { useGeolocation }  from "./hooks/useGeolocation"
import { computeNewOrder } from "./services/orderingService"
import Login         from "./components/Login"
import ShoppingList  from "./components/ShoppingList"
import StoreBar      from "./components/StoreBar"

const CART     = "\u{1F6D2}"
const ESC      = "\u238B"
const PIN      = "\u{1F4CD}"
const HOURGLAS = "\u{23F3}"
const SUN      = "\u2600"
const MOON     = "\u{1F319}"

function getInitialTheme() {
  const stored = localStorage.getItem("theme")
  if (stored === "light" || stored === "dark") return stored
  return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches
    ? "dark" : "light"
}

export default function App() {
  const [user, setUser] = useState(undefined)
  const [activeStore, setActiveStore] = useState(null)
  const [autoDetected, setAutoDetected] = useState(false)
  const [theme, setTheme] = useState(getInitialTheme)

  // Theme auf <html> setzen + persistieren
  useEffect(() => {
    document.documentElement.dataset.theme = theme
    localStorage.setItem("theme", theme)
  }, [theme])

  const { position } = useGeolocation()
  const {
    items, loading, addItem, editItem, toggleItem, removeItem,
    finishShopping, getSortedItems
  } = useShoppingList(user?.uid)
  const {
    stores, detectedStore, addStore, updateStore, saveStoreOrder, deleteStore
  } = useStores(user?.uid, position)
  const { getSuggestions, recordPurchase } = useHistory(user?.uid)

  useEffect(() => onAuthStateChanged(auth, u => setUser(u ?? null)), [])

  useEffect(() => {
    if (detectedStore && !autoDetected) {
      setActiveStore(detectedStore)
      setAutoDetected(true)
    }
    if (!detectedStore) setAutoDetected(false)
  }, [detectedStore])

  const handleFinish = async () => {
    const checkedItems = await finishShopping()
    if (activeStore && checkedItems.length > 0) {
      const newOrder = computeNewOrder(checkedItems, activeStore.itemOrder ?? {})
      await saveStoreOrder(activeStore.id, newOrder)
      setActiveStore(s => s ? { ...s, itemOrder: newOrder } : s)
    }
    await recordPurchase(checkedItems)
  }

  if (user === undefined) return <div className="loading">{HOURGLAS}</div>
  if (!user) return <Login />

  return (
    <div className="app">
      <header className="app-header">
        <h1>{CART} Einkaufsliste</h1>
        <div className="header-actions">
          <button
            className="btn-icon"
            onClick={() => setTheme(t => t === "dark" ? "light" : "dark")}
            title={theme === "dark" ? "Hell" : "Dunkel"}
          >
            {theme === "dark" ? SUN : MOON}
          </button>
          <button className="btn-icon" onClick={() => signOut(auth)} title="Abmelden">{ESC}</button>
        </div>
      </header>
      <StoreBar
        stores={stores}
        activeStore={activeStore}
        detectedStore={detectedStore}
        onSelectStore={setActiveStore}
        onAddStore={addStore}
        onUpdateStore={updateStore}
        onDeleteStore={deleteStore}
        position={position}
      />
      {detectedStore && activeStore?.id === detectedStore.id && (
        <div className="gps-banner">
          {PIN} {detectedStore.name} erkannt - Liste ist sortiert
        </div>
      )}
      <ShoppingList
        items={items}
        loading={loading}
        activeStore={activeStore}
        onToggle={toggleItem}
        onRemove={removeItem}
        onEdit={editItem}
        onAdd={addItem}
        onFinish={handleFinish}
        getSuggestions={getSuggestions}
        getSortedItems={getSortedItems}
      />
    </div>
  )
}
'@

# --- src/App.css (kompletter Theme-Umbau) ---------------------------------
Write-Utf8 'src\App.css' @'
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}

/* ========== Theme Tokens ========== */
:root[data-theme="light"], :root:not([data-theme]) {
  --bg:           #fafafa;
  --surface:      #ffffff;
  --surface-2:    #f3f4f6;
  --text:         #111827;
  --text-soft:    #6b7280;
  --border:       #e5e7eb;
  --accent:       #4f46e5;
  --accent-soft:  #eef2ff;
  --accent-text:  #ffffff;
  --danger:       #dc2626;
  --shadow:       0 1px 3px rgba(0,0,0,.08), 0 1px 2px rgba(0,0,0,.04);
  --shadow-lg:    0 10px 25px rgba(0,0,0,.10);
}
:root[data-theme="dark"] {
  --bg:           #0f172a;
  --surface:      #1e293b;
  --surface-2:    #334155;
  --text:         #f1f5f9;
  --text-soft:    #94a3b8;
  --border:       #334155;
  --accent:       #818cf8;
  --accent-soft:  #312e81;
  --accent-text:  #0f172a;
  --danger:       #f87171;
  --shadow:       0 1px 3px rgba(0,0,0,.4);
  --shadow-lg:    0 10px 25px rgba(0,0,0,.5);
}

html, body { background: var(--bg); color: var(--text); }
body { font-family: system-ui, -apple-system, sans-serif; transition: background .25s ease; }

/* ========== Login ========== */
.login-screen {
  min-height: 100dvh;
  display: flex; align-items: center; justify-content: center;
  padding: 24px;
}
.login-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 16px;
  padding: 40px 32px;
  text-align: center;
  box-shadow: var(--shadow-lg);
  max-width: 360px; width: 100%;
}
.login-icon { font-size: 64px; margin-bottom: 12px; }
.login-card h1 { font-size: 28px; color: var(--accent); margin-bottom: 6px; }
.login-card > p { color: var(--text-soft); margin-bottom: 32px; }
.btn-google {
  background: var(--accent); color: var(--accent-text);
  border: none; border-radius: 12px;
  padding: 14px 24px; font-size: 16px; font-weight: 600;
  cursor: pointer; width: 100%;
  transition: filter .2s, transform .05s;
}
.btn-google:hover { filter: brightness(1.05); }
.btn-google:active { transform: scale(.98); }
.login-hint { font-size: 13px; color: var(--text-soft); margin-top: 20px; line-height: 1.5; }

/* ========== App Shell ========== */
.app {
  max-width: 520px; margin: 0 auto;
  min-height: 100dvh;
  display: flex; flex-direction: column;
  padding-bottom: 120px;
  background: var(--bg);
}
.app-header {
  background: var(--surface);
  color: var(--text);
  padding: 14px 16px;
  display: flex; align-items: center; justify-content: space-between;
  position: sticky; top: 0; z-index: 100;
  border-bottom: 1px solid var(--border);
}
.app-header h1 { font-size: 19px; font-weight: 700; letter-spacing: -.01em; }
.header-actions { display: flex; gap: 4px; }
.btn-icon {
  background: none; border: none; color: var(--text);
  font-size: 18px; cursor: pointer; padding: 8px 10px;
  border-radius: 10px; line-height: 1;
  transition: background .15s;
}
.btn-icon:hover { background: var(--surface-2); }

/* ========== Store Bar ========== */
.store-bar {
  background: var(--surface);
  position: sticky; top: 54px; z-index: 90;
  border-bottom: 1px solid var(--border);
}
.store-btn {
  width: 100%; background: none; border: none;
  padding: 14px 16px; font-size: 16px; font-weight: 600;
  color: var(--text); text-align: left; cursor: pointer;
  display: flex; align-items: center; justify-content: space-between;
}
.store-chevron { font-size: 11px; color: var(--text-soft); }
.store-picker {
  border-top: 1px solid var(--border);
  background: var(--surface);
}
.detected-hint {
  padding: 10px 16px; font-size: 13px;
  color: var(--accent); background: var(--accent-soft);
}
.store-option-row {
  display: flex; align-items: stretch;
  border-bottom: 1px solid var(--border);
}
.store-option {
  flex: 1; background: none; border: none;
  padding: 14px 16px; font-size: 16px; text-align: left;
  cursor: pointer; color: var(--text);
}
.store-option-row .store-option { border: none; }
.store-option:hover, .store-option.active {
  background: var(--accent-soft); color: var(--accent); font-weight: 600;
}
.store-mini-btn {
  background: none; border: none; color: var(--text-soft);
  padding: 0 12px; cursor: pointer; font-size: 14px;
  transition: background .15s, color .15s;
}
.store-mini-btn:hover { background: var(--surface-2); color: var(--text); }
.store-option.store-none {
  color: var(--text-soft); border-top: 1px solid var(--border);
}
.store-option.editing {
  display: flex; gap: 6px; padding: 8px 12px;
  align-items: center; border-bottom: 1px solid var(--border);
}
.store-edit-input {
  flex: 1; padding: 10px 14px;
  border: 1.5px solid var(--accent); border-radius: 10px;
  background: var(--surface); color: var(--text);
  font-size: 15px; outline: none;
}
.store-action {
  background: var(--accent); color: var(--accent-text);
  border: none; width: 36px; height: 36px;
  border-radius: 10px; cursor: pointer; font-size: 16px;
}
.store-action.no { background: var(--surface-2); color: var(--text); }
.store-add-row { display: flex; padding: 10px 12px; gap: 8px; }
.store-add-input {
  flex: 1; padding: 10px 14px;
  border: 1.5px solid var(--border); border-radius: 10px;
  background: var(--surface); color: var(--text);
  font-size: 15px; outline: none;
}
.store-add-input:focus { border-color: var(--accent); }
.store-add-btn {
  background: var(--accent); color: var(--accent-text);
  border: none; width: 40px; height: 40px;
  border-radius: 10px; font-size: 20px; cursor: pointer;
}
.store-gps-hint {
  padding: 8px 16px 12px;
  font-size: 12px; color: var(--text-soft);
}

/* ========== GPS Banner ========== */
.gps-banner {
  background: var(--accent-soft); color: var(--accent);
  padding: 10px 16px; font-size: 13px; text-align: center;
  border-bottom: 1px solid var(--border);
}

/* ========== List ========== */
.list-container { flex: 1; padding: 8px 0; }
.loading { padding: 40px; text-align: center; color: var(--text-soft); font-size: 36px; }
.empty-hint {
  text-align: center; color: var(--text-soft);
  padding: 48px 24px; font-size: 16px; line-height: 1.6;
}

/* ========== Item Row ========== */
.item-row {
  display: flex; align-items: center; gap: 12px;
  padding: 14px 14px;
  background: var(--surface);
  margin: 6px 10px;
  border-radius: 12px;
  border: 1px solid var(--border);
  box-shadow: var(--shadow);
  cursor: pointer; user-select: none;
  transition: opacity .15s, background .15s, transform .05s;
  -webkit-tap-highlight-color: transparent;
  touch-action: manipulation;
}
.item-row:active { transform: scale(.99); background: var(--surface-2); }
.item-row.checked { opacity: .5; }
.item-row.editing { background: var(--accent-soft); cursor: default; }
.item-row.editing:active { transform: none; }

.item-check {
  width: 30px; height: 30px; border-radius: 50%;
  border: 2px solid var(--border);
  display: flex; align-items: center; justify-content: center;
  font-size: 16px; color: var(--accent-text); flex-shrink: 0;
  transition: background .15s, border-color .15s;
}
.item-check.done {
  background: var(--accent); border-color: var(--accent);
}

.item-name { font-size: 17px; flex: 1; color: var(--text); }
.item-row.checked .item-name {
  text-decoration: line-through; color: var(--text-soft);
}

.item-edit-btn {
  background: none; border: none; color: var(--text-soft);
  padding: 6px 10px; cursor: pointer; font-size: 14px;
  border-radius: 8px; opacity: .55;
  transition: background .15s, opacity .15s, color .15s;
}
.item-edit-btn:hover {
  background: var(--surface-2); color: var(--text); opacity: 1;
}

.item-edit-input {
  flex: 1; padding: 10px 14px;
  border: 1.5px solid var(--accent); border-radius: 10px;
  background: var(--surface); color: var(--text);
  font-size: 16px; outline: none;
}
.item-action {
  width: 36px; height: 36px; border: none; border-radius: 10px;
  cursor: pointer; font-size: 16px; flex-shrink: 0;
}
.item-action.ok { background: var(--accent); color: var(--accent-text); }
.item-action.no { background: var(--surface-2); color: var(--text); }

/* ========== Sections ========== */
.section-toggle {
  width: 100%; background: none; border: none;
  padding: 14px 16px; font-size: 13px; color: var(--text-soft);
  text-align: left; cursor: pointer; font-weight: 600;
  text-transform: uppercase; letter-spacing: .05em;
}

.btn-finish {
  margin: 14px 10px; width: calc(100% - 20px);
  background: var(--accent); color: var(--accent-text);
  border: none; border-radius: 14px;
  padding: 18px; font-size: 17px; font-weight: 700;
  cursor: pointer; letter-spacing: .01em;
  transition: filter .15s;
}
.btn-finish:hover { filter: brightness(1.05); }
.btn-finish:active { filter: brightness(.95); }

/* ========== Add Item ========== */
.add-item-container {
  position: fixed; bottom: 0; left: 50%; transform: translateX(-50%);
  width: 100%; max-width: 520px;
  background: var(--surface);
  padding: 10px 12px 20px;
  box-shadow: 0 -2px 20px rgba(0,0,0,.08);
  border-top: 1px solid var(--border);
  z-index: 200;
}
.suggestions {
  display: flex; flex-wrap: wrap; gap: 6px;
  padding: 0 4px 8px;
}
.suggestion-chip {
  background: var(--accent-soft); color: var(--accent);
  border: 1px solid var(--accent);
  border-radius: 50px; padding: 6px 14px;
  font-size: 14px; cursor: pointer;
}
.add-item-row { display: flex; gap: 8px; align-items: center; }
.add-item-input {
  flex: 1; padding: 14px 18px;
  border: 1.5px solid var(--border);
  border-radius: 50px;
  background: var(--surface); color: var(--text);
  font-size: 16px; outline: none;
  transition: border-color .15s;
}
.add-item-input:focus { border-color: var(--accent); }
.add-item-btn {
  background: var(--accent); color: var(--accent-text);
  border: none; width: 52px; height: 52px; border-radius: 50%;
  font-size: 26px; cursor: pointer; flex-shrink: 0;
  transition: filter .15s, transform .05s;
}
.add-item-btn:hover:not(:disabled) { filter: brightness(1.05); }
.add-item-btn:active:not(:disabled) { transform: scale(.95); }
.add-item-btn:disabled { background: var(--surface-2); color: var(--text-soft); cursor: not-allowed; }
'@

Write-Host ""
Write-Host "Fertig! Browser-Tab neu laden (Strg+F5)." -ForegroundColor Green

# ===========================================================================
# Setup-Script fuer Einkaufslisten-PWA
# Schreibt alle benoetigten Projektdateien und raeumt Vite-Defaults auf.
# ===========================================================================

$ErrorActionPreference = 'Stop'
Write-Host "Schreibe Projektdateien ..." -ForegroundColor Cyan

# Vite-Defaults entfernen
Remove-Item src\index.css   -ErrorAction SilentlyContinue
Remove-Item src\assets      -Recurse -Force -ErrorAction SilentlyContinue

# Ordner anlegen
New-Item -ItemType Directory -Force -Path `
  src\components, src\hooks, src\services, public | Out-Null

# --- vite.config.js -------------------------------------------------------
@'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      manifest: {
        name: 'Einkaufsliste',
        short_name: 'Einkauf',
        description: 'Gemeinsame Einkaufsliste mit Lernfunktion',
        theme_color: '#2e7d32',
        background_color: '#f1f8e9',
        display: 'standalone',
        orientation: 'portrait',
        start_url: '/',
        icons: [
          { src: '/icon-192.png', sizes: '192x192', type: 'image/png' },
          { src: '/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any maskable' }
        ]
      },
      workbox: {
        globPatterns: ['**/*.{js,css,html,png,svg,ico}'],
        runtimeCaching: [{
          urlPattern: /^https:\/\/firestore\.googleapis\.com\/.*/i,
          handler: 'NetworkFirst',
          options: { cacheName: 'firestore-cache' }
        }]
      }
    })
  ]
})
'@ | Set-Content -Encoding UTF8 vite.config.js

# --- index.html -----------------------------------------------------------
@'
<!DOCTYPE html>
<html lang="de">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/png" href="/icon-192.png" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
    <meta name="theme-color" content="#2e7d32" />
    <meta name="apple-mobile-web-app-capable" content="yes" />
    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
    <title>Einkaufsliste</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
'@ | Set-Content -Encoding UTF8 index.html

# --- src/firebase.js ------------------------------------------------------
@'
import { initializeApp } from "firebase/app"
import { getFirestore } from "firebase/firestore"
import { getAuth, GoogleAuthProvider } from "firebase/auth"

const firebaseConfig = {
  apiKey: "AIzaSyBT7oPDKTvevw3U9YONlSxh2JfOK7MADaY",
  authDomain: "einkaufsliste-e9d01.firebaseapp.com",
  projectId: "einkaufsliste-e9d01",
  storageBucket: "einkaufsliste-e9d01.firebasestorage.app",
  messagingSenderId: "793752247978",
  appId: "1:793752247978:web:320fda77972c41b9657ad3"
}

const app = initializeApp(firebaseConfig)
export const db   = getFirestore(app)
export const auth = getAuth(app)
export const googleProvider = new GoogleAuthProvider()
'@ | Set-Content -Encoding UTF8 src\firebase.js

# --- src/main.jsx ---------------------------------------------------------
@'
import React from "react"
import ReactDOM from "react-dom/client"
import App from "./App.jsx"
import "./App.css"

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
'@ | Set-Content -Encoding UTF8 src\main.jsx

# --- src/services/orderingService.js -------------------------------------
@'
export function distanceMeters(lat1, lng1, lat2, lng2) {
  const R = 6371000
  const dLat = (lat2 - lat1) * Math.PI / 180
  const dLng = (lng2 - lng1) * Math.PI / 180
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLng / 2) ** 2
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

export function sortByStoreOrder(items, storeOrder = {}) {
  return [...items].sort((a, b) => {
    const keyA = a.name.toLowerCase().trim()
    const keyB = b.name.toLowerCase().trim()
    const rankA = storeOrder[keyA] ?? 9999
    const rankB = storeOrder[keyB] ?? 9999
    return rankA - rankB
  })
}

export function computeNewOrder(checkedItems, oldOrder = {}) {
  const newOrder = { ...oldOrder }
  checkedItems.forEach((item, index) => {
    const key = item.name.toLowerCase().trim()
    const oldRank = oldOrder[key] ?? index
    newOrder[key] = Math.round(oldRank * 0.7 + index * 0.3)
  })
  return newOrder
}
'@ | Set-Content -Encoding UTF8 src\services\orderingService.js

# --- src/hooks/useGeolocation.js ------------------------------------------
@'
import { useState, useEffect } from "react"

export function useGeolocation() {
  const [position, setPosition] = useState(null)
  const [error, setError] = useState(null)

  useEffect(() => {
    if (!navigator.geolocation) {
      setError("GPS nicht verfuegbar")
      return
    }
    const watchId = navigator.geolocation.watchPosition(
      (pos) => setPosition({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
      (err) => setError(err.message),
      { enableHighAccuracy: true, maximumAge: 10000, timeout: 15000 }
    )
    return () => navigator.geolocation.clearWatch(watchId)
  }, [])

  return { position, error }
}
'@ | Set-Content -Encoding UTF8 src\hooks\useGeolocation.js

# --- src/hooks/useStores.js -----------------------------------------------
@'
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

  const saveStoreOrder = async (storeId, newOrder) => {
    if (!uid || !storeId) return
    const ref = doc(db, "users", uid, "stores", storeId)
    await updateDoc(ref, { itemOrder: newOrder })
  }

  const deleteStore = async (storeId) => {
    if (!uid) return
    await deleteDoc(doc(db, "users", uid, "stores", storeId))
  }

  return { stores, detectedStore, addStore, saveStoreOrder, deleteStore }
}
'@ | Set-Content -Encoding UTF8 src\hooks\useStores.js

# --- src/hooks/useHistory.js ----------------------------------------------
@'
import { useState, useEffect } from "react"
import { doc, onSnapshot, setDoc, getDoc } from "firebase/firestore"
import { db } from "../firebase"

export function useHistory(uid) {
  const [history, setHistory] = useState({})

  useEffect(() => {
    if (!uid) return
    const ref = doc(db, "users", uid, "meta", "history")
    const unsub = onSnapshot(ref, snap => {
      if (snap.exists()) setHistory(snap.data())
    })
    return unsub
  }, [uid])

  const getSuggestions = (query, currentItems, limit = 6) => {
    if (!query || query.length < 1) return []
    const q = query.toLowerCase()
    const existing = new Set(currentItems.map(i => i.name.toLowerCase().trim()))
    return Object.entries(history)
      .filter(([key]) => key.includes(q) && !existing.has(key))
      .sort((a, b) => b[1].count - a[1].count)
      .slice(0, limit)
      .map(([, v]) => v.display)
  }

  const recordPurchase = async (items) => {
    if (!uid || !items.length) return
    const ref = doc(db, "users", uid, "meta", "history")
    const snap = await getDoc(ref)
    const current = snap.exists() ? snap.data() : {}
    const updated = { ...current }
    for (const item of items) {
      const key = item.name.toLowerCase().trim()
      updated[key] = {
        display: item.name.trim(),
        count: (current[key]?.count ?? 0) + 1,
        lastBought: new Date().toISOString()
      }
    }
    await setDoc(ref, updated)
  }

  return { history, getSuggestions, recordPurchase }
}
'@ | Set-Content -Encoding UTF8 src\hooks\useHistory.js

# --- src/hooks/useShoppingList.js -----------------------------------------
@'
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

  return { items, loading, addItem, toggleItem, removeItem, finishShopping, getSortedItems }
}
'@ | Set-Content -Encoding UTF8 src\hooks\useShoppingList.js

# --- src/components/Login.jsx ---------------------------------------------
@'
import { signInWithPopup } from "firebase/auth"
import { auth, googleProvider } from "../firebase"

export default function Login() {
  const handleLogin = () => signInWithPopup(auth, googleProvider)
  return (
    <div className="login-screen">
      <div className="login-card">
        <div className="login-icon">🛒</div>
        <h1>Einkaufsliste</h1>
        <p>Einfach. Gemeinsam. Smart.</p>
        <button className="btn-google" onClick={handleLogin}>
          Mit Google anmelden
        </button>
        <p className="login-hint">
          Beide Handys muessen sich mit<br/>
          <strong>demselben Google-Konto</strong> anmelden.
        </p>
      </div>
    </div>
  )
}
'@ | Set-Content -Encoding UTF8 src\components\Login.jsx

# --- src/components/StoreBar.jsx ------------------------------------------
@'
import { useState } from "react"

export default function StoreBar({
  stores, activeStore, detectedStore, onSelectStore, onAddStore, position
}) {
  const [showPicker, setShowPicker] = useState(false)
  const [newStoreName, setNewStoreName] = useState("")

  const handleAdd = () => {
    if (!newStoreName.trim()) return
    onAddStore(newStoreName.trim(), position)
    setNewStoreName("")
    setShowPicker(false)
  }

  const label = activeStore
    ? (detectedStore?.id === activeStore.id ? "📍 " : "🏪 ") + activeStore.name
    : "🏪 Markt waehlen"

  return (
    <div className="store-bar">
      <button className="store-btn" onClick={() => setShowPicker(v => !v)}>
        {label}
        <span className="store-chevron">{showPicker ? "▲" : "▼"}</span>
      </button>
      {showPicker && (
        <div className="store-picker">
          {detectedStore && (
            <div className="detected-hint">
              📍 {detectedStore.name} in der Naehe erkannt
            </div>
          )}
          {stores.map(s => (
            <button
              key={s.id}
              className={`store-option ${activeStore?.id === s.id ? "active" : ""}`}
              onClick={() => { onSelectStore(s); setShowPicker(false) }}
            >
              {s.name}{detectedStore?.id === s.id ? " 📍" : ""}
            </button>
          ))}
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
              placeholder="Neuer Markt…"
              onKeyDown={e => e.key === "Enter" && handleAdd()}
              className="store-add-input"
            />
            <button className="store-add-btn" onClick={handleAdd}>＋</button>
          </div>
          {position && (
            <div className="store-gps-hint">
              ✓ GPS aktiv – Position wird beim Anlegen gespeichert
            </div>
          )}
        </div>
      )}
    </div>
  )
}
'@ | Set-Content -Encoding UTF8 src\components\StoreBar.jsx

# --- src/components/AddItem.jsx -------------------------------------------
@'
import { useState, useRef } from "react"

export default function AddItem({ onAdd, getSuggestions, currentItems }) {
  const [value, setValue] = useState("")
  const [suggestions, setSuggestions] = useState([])
  const inputRef = useRef(null)

  const handleChange = (e) => {
    const v = e.target.value
    setValue(v)
    setSuggestions(v.length >= 1 ? getSuggestions(v, currentItems) : [])
  }

  const submit = (name) => {
    const trimmed = (name ?? value).trim()
    if (!trimmed) return
    onAdd(trimmed)
    setValue("")
    setSuggestions([])
    inputRef.current?.focus()
  }

  return (
    <div className="add-item-container">
      {suggestions.length > 0 && (
        <div className="suggestions">
          {suggestions.map(s => (
            <button key={s} className="suggestion-chip" onClick={() => submit(s)}>
              {s}
            </button>
          ))}
        </div>
      )}
      <div className="add-item-row">
        <input
          ref={inputRef}
          className="add-item-input"
          value={value}
          onChange={handleChange}
          onKeyDown={e => e.key === "Enter" && submit()}
          placeholder="Artikel hinzufuegen…"
          autoComplete="off"
          autoCorrect="off"
        />
        <button
          className="add-item-btn"
          onClick={() => submit()}
          disabled={!value.trim()}
        >
          ＋
        </button>
      </div>
    </div>
  )
}
'@ | Set-Content -Encoding UTF8 src\components\AddItem.jsx

# --- src/components/ItemRow.jsx -------------------------------------------
@'
export default function ItemRow({ item, onToggle, onRemove }) {
  let pressTimer = null
  const handlePressStart = () => {
    pressTimer = setTimeout(() => {
      if (window.confirm(`"${item.name}" loeschen?`)) onRemove(item.id)
    }, 600)
  }
  const handlePressEnd = () => clearTimeout(pressTimer)

  return (
    <div
      className={`item-row ${item.checked ? "checked" : ""}`}
      onPointerDown={handlePressStart}
      onPointerUp={handlePressEnd}
      onPointerLeave={handlePressEnd}
      onClick={() => onToggle(item.id)}
    >
      <div className={`item-check ${item.checked ? "done" : ""}`}>
        {item.checked ? "✓" : ""}
      </div>
      <span className="item-name">{item.name}</span>
    </div>
  )
}
'@ | Set-Content -Encoding UTF8 src\components\ItemRow.jsx

# --- src/components/ShoppingList.jsx --------------------------------------
@'
import { useState } from "react"
import ItemRow from "./ItemRow"
import AddItem from "./AddItem"

export default function ShoppingList({
  items, loading, activeStore,
  onToggle, onRemove, onAdd, onFinish,
  getSuggestions, getSortedItems
}) {
  const [showChecked, setShowChecked] = useState(true)
  if (loading) return <div className="loading">Lade…</div>
  const storeOrder = activeStore?.itemOrder ?? {}
  const { unchecked, checked } = getSortedItems(storeOrder)
  return (
    <div className="list-container">
      {unchecked.length === 0 && checked.length === 0 && (
        <div className="empty-hint">
          Tippe unten auf <strong>＋</strong> um loszulegen 🛒
        </div>
      )}
      {unchecked.map(item => (
        <ItemRow key={item.id} item={item} onToggle={onToggle} onRemove={onRemove} />
      ))}
      {checked.length > 0 && (
        <>
          <button className="section-toggle" onClick={() => setShowChecked(v => !v)}>
            {showChecked ? "▼" : "▶"} Erledigt ({checked.length})
          </button>
          {showChecked && checked.map(item => (
            <ItemRow key={item.id} item={item} onToggle={onToggle} onRemove={onRemove} />
          ))}
          <button className="btn-finish" onClick={onFinish}>
            🏁 Einkauf abschliessen
          </button>
        </>
      )}
      <AddItem onAdd={onAdd} getSuggestions={getSuggestions} currentItems={items} />
    </div>
  )
}
'@ | Set-Content -Encoding UTF8 src\components\ShoppingList.jsx

# --- src/App.jsx ----------------------------------------------------------
@'
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

export default function App() {
  const [user, setUser] = useState(undefined)
  const [activeStore, setActiveStore] = useState(null)
  const [autoDetected, setAutoDetected] = useState(false)

  const { position } = useGeolocation()
  const { items, loading, addItem, toggleItem, removeItem, finishShopping, getSortedItems } =
    useShoppingList(user?.uid)
  const { stores, detectedStore, addStore, saveStoreOrder } =
    useStores(user?.uid, position)
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

  if (user === undefined) return <div className="loading">⏳</div>
  if (!user) return <Login />

  return (
    <div className="app">
      <header className="app-header">
        <h1>🛒 Einkaufsliste</h1>
        <button className="btn-logout" onClick={() => signOut(auth)} title="Abmelden">⎋</button>
      </header>
      <StoreBar
        stores={stores}
        activeStore={activeStore}
        detectedStore={detectedStore}
        onSelectStore={setActiveStore}
        onAddStore={addStore}
        position={position}
      />
      {detectedStore && activeStore?.id === detectedStore.id && (
        <div className="gps-banner">
          📍 {detectedStore.name} erkannt – Liste ist sortiert
        </div>
      )}
      <ShoppingList
        items={items}
        loading={loading}
        activeStore={activeStore}
        onToggle={toggleItem}
        onRemove={removeItem}
        onAdd={addItem}
        onFinish={handleFinish}
        getSuggestions={getSuggestions}
        getSortedItems={getSortedItems}
      />
    </div>
  )
}
'@ | Set-Content -Encoding UTF8 src\App.jsx

# --- src/App.css ----------------------------------------------------------
@'
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
:root{
  --green:#2e7d32; --green-light:#4caf50; --green-bg:#f1f8e9;
  --checked:#a5d6a7; --text:#1b5e20; --gray:#757575;
  --radius:14px; --shadow:0 2px 8px rgba(0,0,0,.12);
  --font: system-ui, -apple-system, sans-serif;
}
body{font-family:var(--font);background:var(--green-bg);color:#333}

.login-screen{min-height:100dvh;display:flex;align-items:center;justify-content:center;padding:24px}
.login-card{background:#fff;border-radius:var(--radius);padding:40px 32px;text-align:center;box-shadow:var(--shadow);max-width:360px;width:100%}
.login-icon{font-size:64px;margin-bottom:12px}
.login-card h1{font-size:28px;color:var(--green);margin-bottom:6px}
.login-card>p{color:var(--gray);margin-bottom:32px}
.btn-google{background:#fff;border:2px solid #ddd;border-radius:50px;padding:14px 24px;font-size:17px;cursor:pointer;width:100%;transition:box-shadow .2s}
.btn-google:hover{box-shadow:var(--shadow)}
.login-hint{font-size:13px;color:var(--gray);margin-top:20px;line-height:1.5}

.app{max-width:480px;margin:0 auto;min-height:100dvh;display:flex;flex-direction:column;padding-bottom:120px}
.app-header{background:var(--green);color:#fff;padding:14px 16px;display:flex;align-items:center;justify-content:space-between;position:sticky;top:0;z-index:100}
.app-header h1{font-size:20px;font-weight:700}
.btn-logout{background:none;border:none;color:#fff;font-size:22px;cursor:pointer;padding:4px 8px}

.store-bar{background:#fff;position:sticky;top:52px;z-index:90;box-shadow:0 1px 4px rgba(0,0,0,.1)}
.store-btn{width:100%;background:none;border:none;padding:12px 16px;font-size:16px;font-weight:600;color:var(--green);text-align:left;cursor:pointer;display:flex;align-items:center;justify-content:space-between}
.store-chevron{font-size:12px;color:var(--gray)}
.store-picker{border-top:1px solid #e0e0e0;background:#fff}
.detected-hint{padding:8px 16px;font-size:13px;color:var(--green);background:#e8f5e9}
.store-option{width:100%;background:none;border:none;padding:14px 16px;font-size:16px;text-align:left;cursor:pointer;border-bottom:1px solid #f5f5f5;color:#333}
.store-option:hover,.store-option.active{background:var(--green-bg);color:var(--green);font-weight:600}
.store-none{color:var(--gray)}
.store-add-row{display:flex;padding:8px 12px;gap:8px}
.store-add-input{flex:1;padding:10px 14px;border:1.5px solid #ddd;border-radius:50px;font-size:15px}
.store-add-btn{background:var(--green);color:#fff;border:none;width:40px;height:40px;border-radius:50%;font-size:22px;cursor:pointer}
.store-gps-hint{padding:6px 16px 10px;font-size:12px;color:var(--green)}

.gps-banner{background:#e8f5e9;color:var(--green);padding:8px 16px;font-size:14px;text-align:center;border-bottom:1px solid #c8e6c9}

.list-container{flex:1;padding:8px 0}
.loading{padding:40px;text-align:center;color:var(--gray);font-size:18px}
.empty-hint{text-align:center;color:var(--gray);padding:48px 24px;font-size:17px;line-height:1.6}

.item-row{display:flex;align-items:center;gap:14px;padding:16px;background:#fff;margin:4px 8px;border-radius:var(--radius);box-shadow:var(--shadow);cursor:pointer;user-select:none;transition:opacity .2s,background .2s;-webkit-tap-highlight-color:transparent;touch-action:manipulation}
.item-row.checked{opacity:.55;background:#f9f9f9}
.item-row:active{background:#f0f0f0}
.item-check{width:32px;height:32px;border-radius:50%;border:2.5px solid #ccc;display:flex;align-items:center;justify-content:center;font-size:18px;color:#fff;flex-shrink:0;transition:background .2s,border-color .2s}
.item-check.done{background:var(--green-light);border-color:var(--green-light)}
.item-name{font-size:18px;flex:1}
.item-row.checked .item-name{text-decoration:line-through;color:var(--gray)}

.section-toggle{width:100%;background:none;border:none;padding:12px 16px;font-size:14px;color:var(--gray);text-align:left;cursor:pointer}

.btn-finish{margin:12px 8px;width:calc(100% - 16px);background:var(--green);color:#fff;border:none;border-radius:var(--radius);padding:18px;font-size:18px;font-weight:700;cursor:pointer;letter-spacing:.5px}
.btn-finish:active{background:#1b5e20}

.add-item-container{position:fixed;bottom:0;left:50%;transform:translateX(-50%);width:100%;max-width:480px;background:#fff;padding:10px 12px 20px;box-shadow:0 -2px 12px rgba(0,0,0,.12);z-index:200}
.suggestions{display:flex;flex-wrap:wrap;gap:6px;padding:0 4px 8px}
.suggestion-chip{background:var(--green-bg);color:var(--green);border:1.5px solid var(--green-light);border-radius:50px;padding:6px 14px;font-size:14px;cursor:pointer}
.add-item-row{display:flex;gap:8px;align-items:center}
.add-item-input{flex:1;padding:14px 18px;border:2px solid #ddd;border-radius:50px;font-size:17px;outline:none;transition:border-color .2s}
.add-item-input:focus{border-color:var(--green)}
.add-item-btn{background:var(--green);color:#fff;border:none;width:52px;height:52px;border-radius:50%;font-size:26px;cursor:pointer;flex-shrink:0;transition:background .2s}
.add-item-btn:disabled{background:#ccc}
'@ | Set-Content -Encoding UTF8 src\App.css

# --- Icons herunterladen --------------------------------------------------
Write-Host "Lade Icon herunter ..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/twitter/twemoji/master/assets/72x72/1f6d2.png" `
        -OutFile "public\icon-192.png" -UseBasicParsing
    Copy-Item "public\icon-192.png" "public\icon-512.png"
} catch {
    Write-Warning "Icon-Download fehlgeschlagen: $($_.Exception.Message)"
    Write-Warning "Nicht kritisch - PWA laeuft trotzdem, nur ohne huebsches Icon."
}

Write-Host ""
Write-Host "Fertig! Jetzt:" -ForegroundColor Green
Write-Host "  npm run dev" -ForegroundColor Yellow
Write-Host ""

# ===========================================================================
# Fix-Script: ueberschreibt die JSX-Dateien mit ASCII-only Source.
# Emojis kommen als JS Unicode-Escapes rein, damit die PS1-Datei selbst
# keine UTF-8-Zeichen mehr enthaelt -> kein Encoding-Risiko.
# ===========================================================================

$ErrorActionPreference = 'Stop'
Write-Host "Schreibe Dateien mit explizitem UTF-8 (no BOM) ..." -ForegroundColor Cyan

# Hilfsfunktion: schreibt UTF-8 ohne BOM, garantiert
function Write-Utf8([string]$Path, [string]$Content) {
    $full = Join-Path (Get-Location) $Path
    $dir = Split-Path $full -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($full, $Content, $utf8NoBom)
    Write-Host "  geschrieben: $Path"
}

# --- src/components/Login.jsx ---------------------------------------------
Write-Utf8 'src\components\Login.jsx' @'
import { signInWithPopup } from "firebase/auth"
import { auth, googleProvider } from "../firebase"

const CART = "\u{1F6D2}"

export default function Login() {
  const handleLogin = () => signInWithPopup(auth, googleProvider)
  return (
    <div className="login-screen">
      <div className="login-card">
        <div className="login-icon">{CART}</div>
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
'@

# --- src/components/StoreBar.jsx ------------------------------------------
Write-Utf8 'src\components\StoreBar.jsx' @'
import { useState } from "react"

const PIN   = "\u{1F4CD}"
const STORE = "\u{1F3EA}"
const PLUS  = "\uFF0B"
const UP    = "\u25B2"
const DOWN  = "\u25BC"
const CHECK = "\u2713"

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
          {stores.map(s => (
            <button
              key={s.id}
              className={"store-option " + (activeStore?.id === s.id ? "active" : "")}
              onClick={() => { onSelectStore(s); setShowPicker(false) }}
            >
              {s.name}{detectedStore?.id === s.id ? " " + PIN : ""}
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

# --- src/components/AddItem.jsx -------------------------------------------
Write-Utf8 'src\components\AddItem.jsx' @'
import { useState, useRef } from "react"

const PLUS = "\uFF0B"

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
          placeholder="Artikel hinzufuegen..."
          autoComplete="off"
          autoCorrect="off"
        />
        <button
          className="add-item-btn"
          onClick={() => submit()}
          disabled={!value.trim()}
        >
          {PLUS}
        </button>
      </div>
    </div>
  )
}
'@

# --- src/components/ItemRow.jsx -------------------------------------------
Write-Utf8 'src\components\ItemRow.jsx' @'
const CHECK = "\u2713"

export default function ItemRow({ item, onToggle, onRemove }) {
  let pressTimer = null
  const handlePressStart = () => {
    pressTimer = setTimeout(() => {
      if (window.confirm("\"" + item.name + "\" loeschen?")) onRemove(item.id)
    }, 600)
  }
  const handlePressEnd = () => clearTimeout(pressTimer)

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
    </div>
  )
}
'@

# --- src/components/ShoppingList.jsx --------------------------------------
Write-Utf8 'src\components\ShoppingList.jsx' @'
import { useState } from "react"
import ItemRow from "./ItemRow"
import AddItem from "./AddItem"

const CART = "\u{1F6D2}"
const FLAG = "\u{1F3C1}"
const DOWN = "\u25BC"
const RIGHT = "\u25B6"
const PLUS = "\uFF0B"

export default function ShoppingList({
  items, loading, activeStore,
  onToggle, onRemove, onAdd, onFinish,
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
        <ItemRow key={item.id} item={item} onToggle={onToggle} onRemove={onRemove} />
      ))}
      {checked.length > 0 && (
        <>
          <button className="section-toggle" onClick={() => setShowChecked(v => !v)}>
            {showChecked ? DOWN : RIGHT} Erledigt ({checked.length})
          </button>
          {showChecked && checked.map(item => (
            <ItemRow key={item.id} item={item} onToggle={onToggle} onRemove={onRemove} />
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

# --- src/App.jsx ----------------------------------------------------------
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

  if (user === undefined) return <div className="loading">{HOURGLAS}</div>
  if (!user) return <Login />

  return (
    <div className="app">
      <header className="app-header">
        <h1>{CART} Einkaufsliste</h1>
        <button className="btn-logout" onClick={() => signOut(auth)} title="Abmelden">{ESC}</button>
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
          {PIN} {detectedStore.name} erkannt - Liste ist sortiert
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
'@

Write-Host ""
Write-Host "Fertig! Server neu starten:" -ForegroundColor Green
Write-Host "  Strg+C im npm-Fenster, dann: npm run dev" -ForegroundColor Yellow

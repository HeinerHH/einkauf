import { useState } from "react"

const HOUSE = "\u{1F3E0}"
const KEY   = "\u{1F511}"
const CART  = "\u{1F6D2}"
const COPY  = "\u{1F4CB}"

export default function Onboarding({ user, onCreate, onJoin, onLogout }) {
  const [mode,        setMode]        = useState(null)
  const [name,        setName]        = useState("Unser Haushalt")
  const [code,        setCode]        = useState("")
  const [error,       setError]       = useState("")
  const [busy,        setBusy]        = useState(false)
  const [createdCode, setCreatedCode] = useState(null)

  const handleCreate = async () => {
    setBusy(true); setError("")
    try   { setCreatedCode(await onCreate(name)) }
    catch (e) { setError(e.message); setBusy(false) }
  }

  const handleJoin = async () => {
    setBusy(true); setError("")
    try   { await onJoin(code) }
    catch (e) { setError(e.message); setBusy(false) }
  }

  if (createdCode) return (
    <div className="onboarding">
      <div className="onboarding-card">
        <div className="onboarding-icon">{HOUSE}</div>
        <h1>Haushalt erstellt!</h1>
        <p>Schick diesen Code an dein/e Partner/in. Er/sie gibt ihn nach dem Anmelden ein:</p>
        <div className="invite-code-big">{createdCode}</div>
        <button className="onboarding-btn primary"
          onClick={() => { try { navigator.clipboard.writeText(createdCode) } catch { } }}>
          {COPY} Code kopieren
        </button>
        <p className="hint-small">
          Einmalig gueltig. Weitere Codes jederzeit im {HOUSE}-Menu erzeugbar.
        </p>
      </div>
    </div>
  )

  if (mode === "create") return (
    <div className="onboarding">
      <div className="onboarding-card">
        <div className="onboarding-icon">{HOUSE}</div>
        <h1>Neuer Haushalt</h1>
        <p>Du legst einen gemeinsamen Haushalt an. Danach bekommst du einen Code zum Teilen.</p>
        <input value={name} onChange={e => setName(e.target.value)}
          placeholder="z.B. Familie Heckeroth"
          className="onboarding-input" autoFocus />
        {error && <p className="onboarding-error">{error}</p>}
        <button onClick={handleCreate} disabled={busy} className="onboarding-btn primary">
          {busy ? "Erstelle..." : "Erstellen"}
        </button>
        <button onClick={() => { setMode(null); setError("") }} className="onboarding-btn ghost">
          Zurueck
        </button>
      </div>
    </div>
  )

  if (mode === "join") return (
    <div className="onboarding">
      <div className="onboarding-card">
        <div className="onboarding-icon">{KEY}</div>
        <h1>Beitreten</h1>
        <p>Gib den 6-stelligen Code ein, den dein/e Partner/in dir geschickt hat.</p>
        <input value={code}
          onChange={e => setCode(e.target.value.toUpperCase().replace(/[^A-Z0-9]/g, ""))}
          placeholder="ABC123" maxLength={6}
          className="onboarding-input code-input" autoFocus />
        {error && <p className="onboarding-error">{error}</p>}
        <button onClick={handleJoin} disabled={busy || code.length < 4}
          className="onboarding-btn primary">
          {busy ? "Trete bei..." : "Beitreten"}
        </button>
        <button onClick={() => { setMode(null); setError("") }} className="onboarding-btn ghost">
          Zurueck
        </button>
      </div>
    </div>
  )

  return (
    <div className="onboarding">
      <div className="onboarding-card">
        <div className="onboarding-icon">{CART}</div>
        <h1>Hallo {(user.displayName || "").split(" ")[0]}!</h1>
        <p>Du brauchst einen gemeinsamen Haushalt um loszulegen.</p>
        <button onClick={() => setMode("create")} className="onboarding-btn primary">
          {HOUSE} Haushalt erstellen
        </button>
        <div className="onboarding-or">- oder -</div>
        <button onClick={() => setMode("join")} className="onboarding-btn primary">
          {KEY} Mit Einladungscode beitreten
        </button>
        <button onClick={onLogout} className="onboarding-btn ghost">
          Mit anderem Konto anmelden
        </button>
      </div>
    </div>
  )
}

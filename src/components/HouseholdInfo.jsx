import { useState } from "react"

const HOUSE = "\u{1F3E0}"
const X     = "\u2715"
const COPY  = "\u{1F4CB}"
const CHECK = "\u2713"

export default function HouseholdInfo({ user, household, onClose, onGenerateCode, onLeave }) {
  const [code,   setCode]   = useState(null)
  const [copied, setCopied] = useState(false)
  const [busy,   setBusy]   = useState(false)

  const handleGenerate = async () => {
    setBusy(true)
    try { setCode(await onGenerateCode()) }
    finally { setBusy(false) }
  }

  const handleCopy = async () => {
    if (!code) return
    try {
      await navigator.clipboard.writeText(code)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch { }
  }

  const handleLeave = async () => {
    if (window.confirm("Wirklich austreten? Du verlierst Zugriff auf die gemeinsame Liste.")) {
      await onLeave()
      onClose()
    }
  }

  const members = household?.memberInfo ? Object.entries(household.memberInfo) : []

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={e => e.stopPropagation()}>
        <button className="modal-close" onClick={onClose}>{X}</button>
        <div className="modal-icon">{HOUSE}</div>
        <h2 className="modal-title">{household?.name}</h2>

        <div className="modal-section">
          <h3 className="modal-section-title">Mitglieder ({members.length})</h3>
          <ul className="member-list">
            {members.map(([uid, info]) => (
              <li key={uid} className="member-item">
                <span>{info.displayName || info.email}</span>
                {uid === user.uid && <span className="badge">Du</span>}
              </li>
            ))}
          </ul>
        </div>

        <div className="modal-section">
          <h3 className="modal-section-title">Jemanden einladen</h3>
          {code ? (
            <>
              <div className="invite-code-big">{code}</div>
              <p className="hint-small">Einmalig gueltig – an Partner/in weitergeben.</p>
              <button onClick={handleCopy} className="onboarding-btn primary">
                {copied ? CHECK + " Kopiert!" : COPY + " Kopieren"}
              </button>
            </>
          ) : (
            <button onClick={handleGenerate} disabled={busy} className="onboarding-btn primary">
              {busy ? "..." : "Einladungscode erstellen"}
            </button>
          )}
        </div>

        <div className="modal-section">
          <button onClick={handleLeave} className="onboarding-btn danger">
            Haushalt verlassen
          </button>
        </div>
      </div>
    </div>
  )
}

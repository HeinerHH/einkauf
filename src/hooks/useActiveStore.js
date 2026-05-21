import { useState, useEffect } from "react"
import { doc, onSnapshot, setDoc } from "firebase/firestore"
import { db } from "../firebase"
import { distanceMeters } from "../services/orderingService"

const DETECT_RADIUS = 200  // Meter

/**
 * Verwaltet den aktiven Markt SHARED in Firestore.
 * Beide Handys sehen immer denselben aktiven Markt.
 * GPS-Erkennung nur auf explizite Anfrage (nicht dauerhaft im Hintergrund).
 */
export function useActiveStore(householdId) {
  const [activeStoreId, setLocalId] = useState(null)
  const [detecting,     setDetecting] = useState(false)
  const [detectMsg,     setDetectMsg] = useState("")

  const ref = householdId
    ? doc(db, "households", householdId, "meta", "state")
    : null

  // Firestore-Listener: Aenderungen sofort auf beiden Geraeten sichtbar
  useEffect(() => {
    if (!ref) return
    return onSnapshot(ref, snap => {
      if (snap.exists()) setLocalId(snap.data().activeStoreId ?? null)
      else               setLocalId(null)
    })
  }, [householdId])

  // Markt setzen – schreibt in Firestore, beide Handys merken es sofort
  const setActiveStoreId = async (id) => {
    if (!ref) return
    await setDoc(ref, { activeStoreId: id ?? null }, { merge: true })
  }

  /**
   * GPS einmalig abfragen und naechsten bekannten Markt suchen.
   * Gibt { store, distance } zurueck oder null wenn keiner in Reichweite.
   */
  const detectNearestStore = (stores) => new Promise((resolve) => {
    if (!navigator.geolocation) { resolve(null); return }
    setDetecting(true)
    setDetectMsg("GPS wird abgefragt...")
    navigator.geolocation.getCurrentPosition(
      pos => {
        setDetecting(false)
        setDetectMsg("")
        const { latitude: lat, longitude: lng } = pos.coords
        let nearest = null, nearestDist = Infinity
        for (const s of stores) {
          if (!s.lat) continue
          const d = distanceMeters(lat, lng, s.lat, s.lng)
          if (d < nearestDist) { nearestDist = d; nearest = s }
        }
        resolve(nearestDist < DETECT_RADIUS ? { store: nearest, distance: Math.round(nearestDist) } : null)
      },
      () => { setDetecting(false); setDetectMsg(""); resolve(null) },
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
    )
  })

  return { activeStoreId, setActiveStoreId, detecting, detectMsg, detectNearestStore }
}

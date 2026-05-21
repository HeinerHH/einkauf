import { useState, useEffect } from "react"
import {
  doc, getDoc, setDoc, updateDoc, onSnapshot,
  collection, addDoc, serverTimestamp, arrayUnion, deleteDoc
} from "firebase/firestore"
import { db } from "../firebase"

function generateCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
  let code = ""
  for (let i = 0; i < 6; i++) code += chars[Math.floor(Math.random() * chars.length)]
  return code
}

export function useHousehold(user) {
  const [householdId, setHouseholdId] = useState(undefined)
  const [household,   setHousehold]   = useState(null)

  useEffect(() => {
    if (!user) { setHouseholdId(undefined); setHousehold(null); return }
    const ref = doc(db, "users", user.uid)
    return onSnapshot(ref, async snap => {
      if (snap.exists()) {
        setHouseholdId(snap.data().householdId ?? null)
      } else {
        await setDoc(ref, {
          email: user.email, displayName: user.displayName,
          householdId: null, createdAt: serverTimestamp()
        })
        setHouseholdId(null)
      }
    })
  }, [user])

  useEffect(() => {
    if (!householdId) { setHousehold(null); return }
    return onSnapshot(doc(db, "households", householdId), snap => {
      setHousehold(snap.exists() ? { id: snap.id, ...snap.data() } : null)
    })
  }, [householdId])

  const createHousehold = async (name) => {
    if (!user) throw new Error("Nicht angemeldet")
    const ref = await addDoc(collection(db, "households"), {
      name: name?.trim() || "Mein Haushalt",
      members: [user.uid],
      memberInfo: { [user.uid]: { email: user.email, displayName: user.displayName || user.email } },
      createdBy: user.uid, createdAt: serverTimestamp()
    })
    const code = generateCode()
    await setDoc(doc(db, "joinCodes", code), {
      householdId: ref.id, createdBy: user.uid, createdAt: serverTimestamp()
    })
    await updateDoc(doc(db, "users", user.uid), { householdId: ref.id })
    return code
  }

  const generateJoinCode = async () => {
    if (!householdId || !user) return null
    const code = generateCode()
    await setDoc(doc(db, "joinCodes", code), {
      householdId, createdBy: user.uid, createdAt: serverTimestamp()
    })
    return code
  }

  const joinHousehold = async (rawCode) => {
    if (!user) throw new Error("Nicht angemeldet")
    const code = (rawCode || "").trim().toUpperCase()
    if (code.length < 4) throw new Error("Code zu kurz")
    const snap = await getDoc(doc(db, "joinCodes", code))
    if (!snap.exists()) throw new Error("Code unbekannt oder bereits benutzt.")
    const hid = snap.data().householdId
    await updateDoc(doc(db, "households", hid), {
      members: arrayUnion(user.uid),
      [`memberInfo.${user.uid}`]: { email: user.email, displayName: user.displayName || user.email }
    })
    await updateDoc(doc(db, "users", user.uid), { householdId: hid })
    try { await deleteDoc(doc(db, "joinCodes", code)) } catch { }
    return hid
  }

  const leaveHousehold = async () => {
    if (!user) return
    await updateDoc(doc(db, "users", user.uid), { householdId: null })
  }

  return {
    householdId, household,
    loading: householdId === undefined,
    createHousehold, joinHousehold, generateJoinCode, leaveHousehold
  }
}

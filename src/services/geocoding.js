/**
 * Geocoding via Nominatim (OpenStreetMap) – kostenlos, kein API-Key.
 * Sucht eine Adresse und gibt { lat, lng, label } zurueck oder null.
 *
 * Nominatim-Nutzungsbedingungen: max. 1 Request/Sekunde, User-Agent setzen.
 */
export async function geocodeAddress(query) {
  if (!query || query.trim().length < 3) return null
  const url =
    "https://nominatim.openstreetmap.org/search?" +
    new URLSearchParams({
      q:              query.trim(),
      format:         "json",
      limit:          "5",
      addressdetails: "1",
    })
  try {
    const res = await fetch(url, {
      headers: { "User-Agent": "Einkaufsliste-App/1.0 (privat)" }
    })
    if (!res.ok) return null
    const data = await res.json()
    if (!data.length) return null
    // Ergebnis aufbereiten: kurzer Label + Koordinaten
    return data.map(d => ({
      lat:   parseFloat(d.lat),
      lng:   parseFloat(d.lon),
      label: d.display_name
        .split(",")
        .slice(0, 3)
        .join(", ")
    }))
  } catch {
    return null
  }
}

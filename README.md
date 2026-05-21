# Einkaufsliste

Gemeinsame Einkaufsliste als Progressive Web App (PWA) für zwei Personen mit eigenem Google-Konto.

## Features

- **Echtzeit-Sync** zwischen beliebig vielen Geräten via Firebase Firestore
- **Haushalt-System** – eine Person erstellt einen Haushalt, die andere tritt per 6-stelligem Einladungscode bei
- **Smart-Sortierung** – die App lernt pro Supermarkt die typische Abhak-Reihenfolge und sortiert die Liste beim nächsten Einkauf automatisch passend
- **GPS-Markterkennung** – auf Knopfdruck erkennt die App welcher Supermarkt in der Nähe ist und sortiert die Liste um
- **Adress-Geocoding** – Markt-Standort per Adresseingabe (OpenStreetMap) setzen statt GPS-Punkt vor Ort
- **Mengenangaben** – Menge vorne oder hinten eingeben: `2 Milch`, `Mehl 500g`, `3 kg Käse`
- **Spracherkennung** – Artikel per Mikrofon hinzufügen, mehrere auf einmal: *„Milch, Butter und Brot"*
- **Artikel bearbeiten** – Bleistift-Icon oder Langes Drücken (löschen)
- **Light / Dark Mode** mit automatischer Systemerkennung
- **Offline-fähig** – funktioniert auch ohne Netz, synct beim nächsten Online-Gang
- **Installierbar** – als App-Icon auf dem Homescreen (Android + iOS)

## Tech Stack

| Baustein | Technologie |
|---|---|
| Frontend | React 18 + Vite |
| Styling | Reines CSS (CSS-Variablen für Theming) |
| Backend / Sync | Firebase Firestore |
| Auth | Firebase Auth (Google Sign-In) |
| Hosting | Firebase Hosting |
| Geocoding | Nominatim / OpenStreetMap (kostenlos, kein API-Key) |
| GPS | Web Geolocation API (on-demand, kein Dauerbetrieb) |
| Sprache | Web Speech API (Chrome) |
| PWA | vite-plugin-pwa |

## Setup

### Voraussetzungen
- Node.js 18+
- Firebase-Konto

### Installation

```bash
git clone https://github.com/HeinerHH/einkauf.git
cd einkauf
npm install
```

### Firebase einrichten

1. Neues Firebase-Projekt anlegen: [console.firebase.google.com](https://console.firebase.google.com)
2. Firestore Database aktivieren (Produktionsmodus, Region `europe-west3`)
3. Authentication → Google Sign-In aktivieren
4. Web-App hinzufügen → Config kopieren
5. `src/firebase.js` mit eigener Config befüllen

**Firestore-Sicherheitsregeln:**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    match /joinCodes/{code} {
      allow read, write: if request.auth != null;
    }
    match /households/{householdId} {
      function isMember() {
        return request.auth != null && request.auth.uid in resource.data.members;
      }
      function isJoining() {
        return request.auth != null
          && !(request.auth.uid in resource.data.members)
          && request.auth.uid in request.resource.data.members;
      }
      allow read:   if isMember() || isJoining();
      allow create: if request.auth != null && request.auth.uid in request.resource.data.members;
      allow update: if isMember() || isJoining();
      allow delete: if isMember();
      match /{collection}/{docId=**} {
        allow read, write: if request.auth != null
          && request.auth.uid in
             get(/databases/$(database)/documents/households/$(householdId)).data.members;
      }
    }
  }
}
```

### Entwickeln

```bash
npm run dev
```

### Deployen (Firebase Hosting)

```bash
npm install -g firebase-tools
firebase login
npm run build
firebase deploy --only hosting
```

## Datenmodell (Firestore)

```
/users/{uid}
  email, displayName, householdId

/joinCodes/{code}
  householdId, createdBy, createdAt

/households/{householdId}
  name, members[], memberInfo{}
  /meta/list      → { items: [...] }
  /meta/history   → { [itemName]: { count, display, lastBought } }
  /meta/state     → { activeStoreId }
  /stores/{id}    → { name, lat, lng, itemOrder{} }
```

## Benutzung

### Ersteinrichtung (zwei Handys)

1. Beide Handys öffnen `https://einkaufsliste-e9d01.web.app`
2. Jede Person meldet sich mit **ihrem eigenen** Google-Konto an
3. Person A: „Haushalt erstellen" → bekommt 6-stelligen Code
4. Person B: „Mit Code beitreten" → gibt Code ein
5. Beide sehen jetzt dieselbe Liste in Echtzeit

### Märkte einrichten

Im Markt-Dropdown: Name eingeben + „Adresse suchen" → OpenStreetMap-Treffer auswählen → GPS-Koordinaten werden automatisch gesetzt.

### Einkaufen gehen

1. Zu Hause: Markt aus Dropdown wählen (synct sofort auf beide Handys)
2. Im Markt: 🛰️-Button → GPS-Erkennung → Bestätigung
3. Artikel abhaken – erledigte verschieben sich nach unten
4. „Einkauf abschließen" → App speichert die Abhak-Reihenfolge für diesen Markt

### Mengenangaben

Menge vorne oder hinten eingeben, beides funktioniert:

```
2 Milch       → Milch ×2
Mehl 500g     → Mehl ×500g
3 kg Käse     → Käse ×3 kg
Cola 1.5L     → Cola ×1.5L
```

### Spracherkennung

🎤-Button tippen → sprechen → Artikel wird hinzugefügt.
Mehrere auf einmal: *„Milch, Butter und Brot"* → 3 Artikel.

## Lizenz

MIT

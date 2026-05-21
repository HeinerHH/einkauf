import { useState, useRef } from "react";

const PLUS = "\uFF0B";
const MIC = "\u{1F3A4}";
const STOP = "\u23F9";

/**
 * Parst Mengenangaben am ANFANG oder ENDE des Textes:
 *   Vorne:  "2 Milch", "3kg Kaese", "500 g Mehl"
 *   Hinten: "Milch 2", "Mehl 500g",  "Kaese 3 kg"
 * Alles ohne erkennbares Muster landet komplett im Namen.
 */
function parseInput(raw) {
  const text = raw.trim();
  if (!text) return { name: "", qty: "" };

  // Zahl (optional Dezimal)
  const NUM = /^\d+(?:[.,]\d+)?$/;
  // Einheit allein
  const UNIT = /^(?:g|kg|ml|l|L|cl|Stk|St\.|Stueck|Pkg|Pck|x|Bl\.?)$/i;
  // Zahl direkt mit Einheit: "3kg", "500g", "1.5L"
  const QTY =
    /^\d+(?:[.,]\d+)?\s*(?:g|kg|ml|l|L|cl|Stk|St\.|Stueck|Pkg|Pck|x|Bl\.?)?$/i;

  const words = text.split(/\s+/);
  const n = words.length;

  // ── Menge AM ANFANG ──────────────────────────────────────────
  // "500 g Mehl", "3 kg Kaese" (Zahl + Einheit als zwei Woerter)
  if (n >= 3 && NUM.test(words[0]) && UNIT.test(words[1])) {
    const name = words.slice(2).join(" ");
    if (name) return { name, qty: words[0] + " " + words[1] };
  }
  // "2 Milch", "3kg Kaese" (Zahl oder Zahl+Einheit als ein Wort)
  if (n >= 2 && QTY.test(words[0])) {
    const name = words.slice(1).join(" ");
    if (name) return { name, qty: words[0] };
  }

  // ── Menge AM ENDE ────────────────────────────────────────────
  // "Kaese 3 kg" (Zahl + Einheit als zwei Woerter am Ende)
  if (n >= 3 && UNIT.test(words[n - 1]) && NUM.test(words[n - 2])) {
    const name = words.slice(0, n - 2).join(" ");
    if (name) return { name, qty: words[n - 2] + " " + words[n - 1] };
  }
  // "Milch 2", "Mehl 500g" (Zahl oder Zahl+Einheit als ein Wort am Ende)
  if (n >= 2 && QTY.test(words[n - 1])) {
    const name = words.slice(0, n - 1).join(" ");
    if (name) return { name, qty: words[n - 1] };
  }

  // ── Kein Muster erkannt → alles ist Name ─────────────────────
  return { name: text, qty: "" };
}

export default function AddItem({ onAdd, getSuggestions, currentItems }) {
  const [value, setValue] = useState("");
  const [suggestions, setSuggestions] = useState([]);
  const [listening, setListening] = useState(false);
  const inputRef = useRef(null);
  const recognitionRef = useRef(null);

  const handleChange = (e) => {
    const v = e.target.value;
    setValue(v);
    // Vorschläge nur auf den Namen-Teil (ohne Menge am Ende)
    const { name } = parseInput(v);
    setSuggestions(name.length >= 1 ? getSuggestions(name, currentItems) : []);
  };

  const submit = (raw) => {
    const text = (raw ?? value).trim();
    if (!text) return;
    const { name, qty } = parseInput(text);
    if (!name) return;
    onAdd({ name, qty });
    setValue("");
    setSuggestions([]);
    inputRef.current?.focus();
  };

  // ── Spracherkennung ──────────────────────────────────────────────────────
  const startListening = () => {
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SR) {
      alert("Spracherkennung nicht verfuegbar – bitte Chrome verwenden.");
      return;
    }
    const r = new SR();
    recognitionRef.current = r;
    r.lang = "de-DE";
    r.continuous = false;
    r.interimResults = false;

    r.onstart = () => setListening(true);
    r.onend = () => setListening(false);
    r.onerror = () => setListening(false);

    r.onresult = (e) => {
      const text = e.results[0][0].transcript;
      // Mehrere Artikel auf einmal: "Milch, Butter und Brot" → 3 Items
      const parts = text
        .split(/[,;]|\s+und\s+|\s+sowie\s+/i)
        .map((s) => s.trim())
        .filter(Boolean);
      parts.forEach((raw) => {
        const { name, qty } = parseInput(raw);
        if (name) onAdd({ name, qty });
      });
    };
    r.start();
  };

  const stopListening = () => {
    recognitionRef.current?.stop();
    setListening(false);
  };
  // ────────────────────────────────────────────────────────────────────────

  return (
    <div className="add-item-container">
      {suggestions.length > 0 && (
        <div className="suggestions">
          {suggestions.map((s) => (
            <button
              key={s}
              className="suggestion-chip"
              onClick={() => submit(s)}
            >
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
          onKeyDown={(e) => e.key === "Enter" && submit()}
          placeholder='z.B. "2 Milch", "Mehl 500g", "3 kg Kaese"'
          autoComplete="off"
          autoCorrect="off"
        />
        <button
          className={"mic-btn" + (listening ? " listening" : "")}
          onClick={listening ? stopListening : startListening}
          title={listening ? "Stoppen" : "Sprechen"}
        >
          {listening ? STOP : MIC}
        </button>
        <button
          className="add-item-btn"
          onClick={() => submit()}
          disabled={!value.trim()}
        >
          {PLUS}
        </button>
      </div>

      <p className="add-item-hint">
        Menge vorne oder hinten: <em>2 Milch</em> · <em>Mehl 500g</em> ·{" "}
        <em>3 kg Käse</em>
      </p>
    </div>
  );
}

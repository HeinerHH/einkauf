// Gruppiert Artikel nach sinnvollen Lebensmittel-Kategorien (statt nach
// Markt-Reihenfolge). Reine Stichwort-Erkennung auf dem Artikelnamen – alles
// Unbekannte landet in "Sonstiges". Reihenfolge der CATEGORIES = Anzeige-
// Reihenfolge auf der Liste.

// Wichtig: spezifischere Kategorien (z.B. Getraenke) stehen VOR allgemeineren
// (z.B. Obst & Gemuese), damit "Apfelsaft" als Getraenk und nicht als Obst
// erkannt wird – die erste passende Kategorie gewinnt.
export const CATEGORIES = [
  {
    id: "getraenke",
    label: "\u{1F964} Getränke",
    keywords: [
      "wasser", "saft", "cola", "limo", "limonade", "schorle", "sprudel",
      "bier", "wein", "sekt", "prosecco", "kaffee", "tee", "kakao",
      "energy", "spezi", "fanta", "sprite", "eistee", "smoothie", "drink",
    ],
  },
  {
    id: "tiefkuehl",
    label: "❄️ Tiefkühl",
    keywords: [
      "tiefk", "tk ", "tk-", "pizza", "pommes", "fischst", "eis", "speiseeis",
      "gefrier", "rahmspinat", "blattspinat",
    ],
  },
  {
    id: "fleisch",
    label: "\u{1F356} Fleisch & Wurst",
    keywords: [
      "fleisch", "hack", "hackfleisch", "schnitzel", "steak", "gulasch",
      "haehnchen", "hahnchen", "huhn", "pute", "rind", "schwein", "kalb",
      "wurst", "salami", "schinken", "speck", "bacon", "aufschnitt",
      "leberkas", "frikadelle", "bratwurst", "wiener", "lyoner", "mortadella",
      "geflugel", "gefluegel", "doner", "haxe", "kotelett", "filet",
    ],
  },
  {
    id: "fisch",
    label: "\u{1F41F} Fisch",
    keywords: [
      "fisch", "lachs", "thunfisch", "forelle", "hering", "matjes", "garnele",
      "shrimp", "scampi", "kabeljau", "seelachs", "makrele", "sardine",
      "muschel", "krabbe", "tintenfisch",
    ],
  },
  {
    id: "milch",
    label: "\u{1F9C0} Milchprodukte & Käse",
    keywords: [
      "milch", "kase", "kaese", "joghurt", "jogurt", "quark", "butter",
      "sahne", "schmand", "creme fraiche", "frischkase", "frischkaese",
      "mozzarella", "gouda", "feta", "ei", "eier", "margarine", "pudding",
      "buttermilch", "kefir", "skyr", "mascarpone", "parmesan", "camembert",
    ],
  },
  {
    id: "obstgemuese",
    label: "\u{1F966} Obst & Gemüse",
    keywords: [
      "apfel", "banane", "birne", "orange", "zitrone", "limette", "traube",
      "beere", "erdbeer", "himbeer", "heidelbeer", "kirsche", "pfirsich",
      "melone", "ananas", "mango", "kiwi", "pflaume", "nektarine",
      "tomate", "gurke", "salat", "paprika", "zwiebel", "knoblauch",
      "kartoffel", "moehre", "mohre", "karotte", "zucchini", "aubergine",
      "brokkoli", "blumenkohl", "spinat", "lauch", "sellerie", "rettich",
      "radieschen", "kohl", "kurbis", "kuerbis", "pilz", "champignon",
      "ingwer", "avocado", "spargel", "bohne", "erbse", "mais", "kraut",
      "petersilie", "schnittlauch", "basilikum", "rucola", "feldsalat",
      "obst", "gemuse", "gemuese",
    ],
  },
  {
    id: "brot",
    label: "\u{1F35E} Brot & Backwaren",
    keywords: [
      "brot", "brotchen", "brotchen", "broetchen", "semmel", "baguette",
      "toast", "brezel", "croissant", "kuchen", "geback", "geback",
      "knackebrot", "knaeckebrot", "zwieback", "muffin", "donut", "stuten",
    ],
  },
  {
    id: "vorrat",
    label: "\u{1F96B} Konserven & Vorräte",
    keywords: [
      "konserve", "dose", "nudel", "spaghetti", "pasta", "reis", "mehl",
      "zucker", "salz", "pfeffer", "gewurz", "gewuerz", "ol", "oel", "essig",
      "soße", "sosse", "sauce", "ketchup", "senf", "mayo", "mayonnaise",
      "passierte", "tomatenmark", "bruhe", "bruehe", "suppe", "linsen",
      "kichererbse", "bohnen", "mais", "honig", "marmelade", "konfiture",
      "nutella", "muesli", "musli", "haferflocken", "cornflakes", "couscous",
      "polenta", "grieß", "griess", "backpulver", "hefe", "vanille",
    ],
  },
  {
    id: "suesses",
    label: "\u{1F36B} Süßes & Snacks",
    keywords: [
      "schokolade", "schoko", "keks", "bonbon", "gummi", "chips", "flips",
      "cracker", "riegel", "praline", "lakritz", "popcorn", "nuss", "nusse",
      "erdnuss", "studentenfutter", "salzstange", "waffel", "snack",
    ],
  },
  {
    id: "haushalt",
    label: "\u{1F9F4} Haushalt & Drogerie",
    keywords: [
      "klopapier", "toilettenpapier", "kuchentuch", "kuechentuch", "kuchenrolle",
      "spulmittel", "spuelmittel", "waschmittel", "weichspuler", "weichspueler",
      "putz", "reiniger", "schwamm", "mullbeutel", "muellbeutel", "muelltute",
      "alufolie", "frischhalte", "zahnpasta", "zahnburste", "zahnbuerste",
      "shampoo", "duschgel", "seife", "deo", "rasier", "windel", "taschentuch",
      "tampon", "binde", "creme", "lotion", "batterie", "kerze", "servietten",
      "tierfutter", "katzenfutter", "hundefutter", "streu",
    ],
  },
];

const FALLBACK = { id: "sonstiges", label: "\u{1F6D2} Sonstiges" };

// Umlaute/scharfes S normalisieren, damit "Käse" und "Kaese" gleich matchen.
function normalize(name) {
  return (name || "")
    .toLowerCase()
    .replace(/ä/g, "ae")
    .replace(/ö/g, "oe")
    .replace(/ü/g, "ue")
    .replace(/ß/g, "ss")
    .trim();
}

export function categorize(name) {
  const n = normalize(name);
  for (const cat of CATEGORIES) {
    for (const kw of cat.keywords) {
      if (n.includes(normalize(kw))) return cat.id;
    }
  }
  return FALLBACK.id;
}

// Nimmt eine flache Artikelliste, gibt Gruppen in CATEGORIES-Reihenfolge zurueck.
// Leere Gruppen werden weggelassen. Innerhalb einer Gruppe alphabetisch.
export function groupByCategory(items) {
  const buckets = new Map();
  for (const item of items) {
    const id = categorize(item.name);
    if (!buckets.has(id)) buckets.set(id, []);
    buckets.get(id).push(item);
  }

  const order = [...CATEGORIES, FALLBACK];
  const groups = [];
  for (const cat of order) {
    const bucket = buckets.get(cat.id);
    if (!bucket || !bucket.length) continue;
    bucket.sort((a, b) =>
      a.name.localeCompare(b.name, "de", { sensitivity: "base" }),
    );
    groups.push({ id: cat.id, label: cat.label, items: bucket });
  }
  return groups;
}

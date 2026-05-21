import { useState } from "react";

const CHECK = "\u2713";
const PENCIL = "\u270F";
const X_MARK = "\u2715";

export default function ItemRow({
  item,
  onToggle,
  onRemove,
  onEdit,
  onEditQty,
}) {
  const [editing, setEditing] = useState(false);
  const [value, setValue] = useState(item.name);
  const [qtyValue, setQtyValue] = useState(item.qty ?? "");

  const startEdit = (e) => {
    e.stopPropagation();
    setValue(item.name);
    setQtyValue(item.qty ?? "");
    setEditing(true);
  };

  const save = async (e) => {
    if (e) e.stopPropagation();
    const t = value.trim();
    if (!t || t === item.name) {
      // Name unchanged – still save qty if it changed
      if (qtyValue.trim() !== (item.qty ?? "")) {
        await onEditQty(item.id, qtyValue.trim());
      }
      setEditing(false);
      return;
    }
    const ok = await onEdit(item.id, t);
    if (ok === false) {
      alert("Artikel mit diesem Namen existiert schon.");
      return;
    }
    // Save qty separately if changed
    if (qtyValue.trim() !== (item.qty ?? "")) {
      await onEditQty(item.id, qtyValue.trim());
    }
    setEditing(false);
  };

  const cancel = (e) => {
    if (e) e.stopPropagation();
    setEditing(false);
  };

  let pressTimer;
  const onPressStart = () => {
    if (editing) return;
    pressTimer = setTimeout(() => {
      if (window.confirm('"' + item.name + '" loeschen?')) onRemove(item.id);
    }, 600);
  };
  const onPressEnd = () => clearTimeout(pressTimer);

  if (editing)
    return (
      <div className="item-row editing">
        <div className="item-check">{PENCIL}</div>
        <input
          className="item-edit-input"
          value={value}
          autoFocus
          onChange={(e) => setValue(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") save();
            if (e.key === "Escape") cancel();
          }}
          onClick={(e) => e.stopPropagation()}
        />
        <input
          className="item-qty-input"
          value={qtyValue}
          placeholder="Menge"
          onChange={(e) => setQtyValue(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") save();
            if (e.key === "Escape") cancel();
          }}
          onClick={(e) => e.stopPropagation()}
        />
        <button className="item-action ok" onClick={save}>
          {CHECK}
        </button>
        <button className="item-action no" onClick={cancel}>
          {X_MARK}
        </button>
      </div>
    );

  return (
    <div
      className={"item-row " + (item.checked ? "checked" : "")}
      onPointerDown={onPressStart}
      onPointerUp={onPressEnd}
      onPointerLeave={onPressEnd}
      onClick={() => onToggle(item.id)}
    >
      <div className={"item-check " + (item.checked ? "done" : "")}>
        {item.checked ? CHECK : ""}
      </div>
      {item.qty ? <span className="item-qty">{item.qty}</span> : null}
      <span className="item-name">{item.name}</span>
      <button className="item-edit-btn" onClick={startEdit}>
        {PENCIL}
      </button>
    </div>
  );
}

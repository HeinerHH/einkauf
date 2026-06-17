import { useState } from "react";
import ItemRow from "./ItemRow";
import AddItem from "./AddItem";

const CART = "\u{1F6D2}";
const FLAG = "\u{1F3C1}";
const DOWN = "\u25BC";
const RIGHT = "\u25B6";
const PLUS = "\uFF0B";

export default function ShoppingList({
  items,
  loading,
  activeStore,
  onToggle,
  onRemove,
  onEdit,
  onEditQty,
  onAdd,
  onFinish,
  getSuggestions,
  getSortedItems,
}) {
  const [showChecked, setShowChecked] = useState(true);

  if (loading) return <div className="loading">{"\u{23F3}"}</div>;

  const { groups, checked } = getSortedItems();

  return (
    <div className="list-container">
      {!groups.length && !checked.length && (
        <div className="empty-hint">
          Tippe auf <strong>{PLUS}</strong> um loszulegen {CART}
        </div>
      )}

      {groups.map((group) => (
        <div key={group.id} className="category-group">
          <div className="category-header">{group.label}</div>
          {group.items.map((item) => (
            <ItemRow
              key={item.id}
              item={item}
              onToggle={onToggle}
              onRemove={onRemove}
              onEdit={onEdit}
              onEditQty={onEditQty}
            />
          ))}
        </div>
      ))}

      {checked.length > 0 && (
        <>
          <button
            className="section-toggle"
            onClick={() => setShowChecked((v) => !v)}
          >
            {showChecked ? DOWN : RIGHT} Erledigt ({checked.length})
          </button>
          {showChecked &&
            checked.map((item) => (
              <ItemRow
                key={item.id}
                item={item}
                onToggle={onToggle}
                onRemove={onRemove}
                onEdit={onEdit}
                onEditQty={onEditQty}
              />
            ))}
          <button className="btn-finish" onClick={onFinish}>
            {FLAG} Einkauf abschliessen
          </button>
        </>
      )}

      <AddItem
        onAdd={onAdd}
        getSuggestions={getSuggestions}
        currentItems={items}
      />
    </div>
  );
}

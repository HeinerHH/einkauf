export function distanceMeters(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function sortByStoreOrder(items, storeOrder = {}) {
  return [...items].sort((a, b) => {
    const rankA = storeOrder[a.name.toLowerCase().trim()] ?? 9999;
    const rankB = storeOrder[b.name.toLowerCase().trim()] ?? 9999;
    return rankA - rankB;
  });
}

export function computeNewOrder(checkedItems, oldOrder = {}) {
  const newOrder = { ...oldOrder };
  checkedItems.forEach((item, index) => {
    const key = item.name.toLowerCase().trim();
    newOrder[key] = Math.round((oldOrder[key] ?? index) * 0.7 + index * 0.3);
  });
  return newOrder;
}

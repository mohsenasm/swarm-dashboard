export const complement = (fn) => (x) => !fn(x);

export const isJust = (x) => x !== null && x !== undefined;

export const iff = (condition, trueValue, falseValue) => (condition ? trueValue : falseValue);

export const groupBy = (key, list) => {
  return list.reduce((acc, item) => {
    const k = key(item);
    if (!acc[k]) acc[k] = [];
    acc[k].push(item);
    return acc;
  }, {});
};

export const indexBy = (key, list) => {
  return list.reduce((acc, item) => {
    acc[key(item)] = item;
    return acc;
  }, {});
};

export const unique = (list) => [...new Set(list)];

export const indexedFoldl = (indexedReducer, init, list) => {
  return list.reduce((acc, item, idx) => {
    return indexedReducer(idx, item, acc);
  }, init);
};

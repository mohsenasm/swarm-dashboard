export const complement = (fn) => (x) => !fn(x);

export const isJust = (x) => x !== null && x !== undefined;

export const iff = (condition, trueValue, falseValue) => (condition ? trueValue : falseValue);

export const groupBy = (key, list) => {
  return list.reduce((acc, item) => {
    const k = key(item);
    if (!acc.has(k)) acc.set(k, []);
    acc.get(k).push(item);
    return acc;
  }, new CustomMap());
};

export const indexBy = (key, list) => {
  return list.reduce((acc, item) => {
    acc.set(key(item), item);
    return acc;
  }, new CustomMap());
};

export const unique = (list) => [...new Set(list)];

export const indexedFoldl = (indexedReducer, init, list) => {
  return list.reduce((acc, item, idx) => {
    return indexedReducer(idx, item, acc);
  }, init);
};

class CustomMap {
  constructor() {
    this.map = new Map();
  }

  // Helper function to check if two arrays are equal
  static arraysEqual(arr1, arr2) {
    if (arr1.length !== arr2.length) return false;
    for (let i = 0; i < arr1.length; i++) {
      if (arr1[i] !== arr2[i]) return false;
    }
    return true;
  }

  set(key, value) {
    this.map.set(key, value);
  }

  get(key) {
    if (Array.isArray(key)) {
      for (const [mapKey, value] of this.map.entries()) {
        if (Array.isArray(mapKey) && CustomMap.arraysEqual(mapKey, key)) {
          return value;
        }
      }
      return undefined; // No matching key found
    }
    return this.map.get(key); // For non-array keys
  }

  has(key) {
    if (Array.isArray(key)) {
      for (const mapKey of this.map.keys()) {
        if (Array.isArray(mapKey) && CustomMap.arraysEqual(mapKey, key)) {
          return true;
        }
      }
      return false; // No matching key found
    }
    return this.map.has(key); // For non-array keys
  }

  size() {
    return this.map.size;
  }

  entries() {
    return this.map.entries();
  }

  keys() {
    return this.map.keys();
  }
}
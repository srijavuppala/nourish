// Validation for whatever the model hands back. A language model will
// occasionally return a string where a number belongs, a negative quantity, or
// an item with no name — none of that may reach Firestore.

export const LIMITS = {
  maxItems: 20,
  maxNameLength: 80,
  maxUnitLength: 24,
  maxQty: 10000,
  maxKcal: 10000,
  maxMacroG: 2000,
};

/** Coerce to a finite, non-negative number, or null when that is impossible. */
export function toNumber(value) {
  const parsed = typeof value === 'string' ? Number(value.trim()) : value;
  if (typeof parsed !== 'number' || !Number.isFinite(parsed) || parsed < 0) {
    return null;
  }
  return parsed;
}

function clean(value, maxLength) {
  if (typeof value !== 'string') return '';
  return value.trim().replace(/\s+/g, ' ').slice(0, maxLength);
}

/**
 * Calories implied by the macros, using 4/4/9. Used to catch the common
 * failure where the model invents a calorie figure unrelated to its own macros.
 */
export function kcalFromMacros({ proteinG = 0, carbsG = 0, fatG = 0 }) {
  return proteinG * 4 + carbsG * 4 + fatG * 9;
}

/**
 * Validate and repair a single item.
 * Returns `{ item }` or `{ error }` — never throws.
 */
export function validateItem(raw) {
  if (!raw || typeof raw !== 'object') return { error: 'not an object' };

  const name = clean(raw.name, LIMITS.maxNameLength);
  if (!name) return { error: 'missing name' };

  const qty = toNumber(raw.qty);
  if (qty === null || qty === 0) return { error: `missing quantity for ${name}` };
  if (qty > LIMITS.maxQty) return { error: `implausible quantity for ${name}` };

  const proteinG = toNumber(raw.proteinG) ?? 0;
  const carbsG = toNumber(raw.carbsG) ?? 0;
  const fatG = toNumber(raw.fatG) ?? 0;
  for (const [label, value] of [
    ['protein', proteinG],
    ['carbs', carbsG],
    ['fat', fatG],
  ]) {
    if (value > LIMITS.maxMacroG) {
      return { error: `implausible ${label} for ${name}` };
    }
  }

  const derived = kcalFromMacros({ proteinG, carbsG, fatG });
  let kcal = toNumber(raw.kcal);

  // Trust the macros over the stated calories: macros are what the rings and
  // the protein target are built from, so they must agree.
  if (kcal === null || kcal > LIMITS.maxKcal) {
    kcal = derived;
  } else if (derived > 0 && Math.abs(kcal - derived) / derived > 0.35) {
    kcal = derived;
  }

  if (kcal > LIMITS.maxKcal) return { error: `implausible calories for ${name}` };

  return {
    item: {
      name,
      qty: round(qty, 2),
      unit: clean(raw.unit, LIMITS.maxUnitLength),
      kcal: round(kcal, 1),
      proteinG: round(proteinG, 1),
      carbsG: round(carbsG, 1),
      fatG: round(fatG, 1),
    },
  };
}

function round(value, places) {
  const factor = 10 ** places;
  return Math.round(value * factor) / factor;
}

/**
 * Validate a whole model response.
 *
 * Returns `{ items, needsClarification, question }`. When the model could not
 * make sense of the input it sets a question instead of failing, which is what
 * the chat screen shows the user.
 */
export function validateResponse(raw) {
  if (!raw || typeof raw !== 'object') {
    return {
      items: [],
      needsClarification: true,
      question: "I didn't catch that. What did you eat, and how much?",
    };
  }

  const question = clean(raw.question, 200);
  const rawItems = Array.isArray(raw.items) ? raw.items : [];

  const items = [];
  const rejected = [];
  for (const candidate of rawItems.slice(0, LIMITS.maxItems)) {
    const result = validateItem(candidate);
    if (result.item) items.push(result.item);
    else rejected.push(result.error);
  }

  // Nothing usable came back, so ask rather than save an empty meal.
  if (items.length === 0) {
    return {
      items: [],
      needsClarification: true,
      question:
        question ||
        "I couldn't work that out. Could you tell me the foods and roughly how much of each?",
      rejected,
    };
  }

  // The model itself flagged a gap, e.g. it got the eggs but not "a bit of toast".
  if (raw.needsClarification === true && question) {
    return { items, needsClarification: true, question, rejected };
  }

  return { items, needsClarification: false, question: '', rejected };
}

// USDA FoodData Central lookup, used only to fill gaps the model left behind.
//
// Scope note: FDC reports nutrition per 100g. Converting "2 medium bananas" to
// grams needs a portion weight the search endpoint does not reliably provide,
// so enrichment is limited to items the user gave in a mass or volume unit.
// Anything in household units keeps the model's estimate, which is what the
// user confirms on screen anyway.

const SEARCH_ENDPOINT = 'https://api.nal.usda.gov/fdc/v1/foods/search';

// FDC nutrient ids.
const NUTRIENT_IDS = {
  kcal: 1008,
  proteinG: 1003,
  carbsG: 1005,
  fatG: 1004,
};

/** Grams per unit, for the units we can convert without a portion table. */
const GRAMS_PER_UNIT = {
  g: 1,
  gram: 1,
  grams: 1,
  kg: 1000,
  oz: 28.3495,
  ounce: 28.3495,
  ounces: 28.3495,
  lb: 453.592,
  // Water-equivalent, good enough for drinks and the sauces people describe.
  ml: 1,
  millilitre: 1,
  milliliter: 1,
  l: 1000,
  cup: 240,
  cups: 240,
  tbsp: 15,
  tsp: 5,
};

export function gramsFor(qty, unit) {
  const key = String(unit ?? '').trim().toLowerCase();
  const perUnit = GRAMS_PER_UNIT[key];
  if (!perUnit) return null;
  const grams = qty * perUnit;
  return Number.isFinite(grams) && grams > 0 ? grams : null;
}

/** Per-100g nutrition from an FDC search hit. */
export function nutritionPer100g(food) {
  const nutrients = Array.isArray(food?.foodNutrients) ? food.foodNutrients : [];
  const read = (id) => {
    const match = nutrients.find(
      (nutrient) => (nutrient?.nutrientId ?? nutrient?.nutrient?.id) === id,
    );
    const value = match?.value ?? match?.amount;
    return typeof value === 'number' && Number.isFinite(value) && value >= 0
      ? value
      : null;
  };

  const kcal = read(NUTRIENT_IDS.kcal);
  if (kcal === null) return null;

  return {
    kcal,
    proteinG: read(NUTRIENT_IDS.proteinG) ?? 0,
    carbsG: read(NUTRIENT_IDS.carbsG) ?? 0,
    fatG: read(NUTRIENT_IDS.fatG) ?? 0,
  };
}

export async function lookupFood(name, options = {}) {
  const apiKey = options.apiKey ?? process.env.USDA_API_KEY;
  if (!apiKey) return null;

  const fetchImpl = options.fetch ?? globalThis.fetch;
  const url = new URL(SEARCH_ENDPOINT);
  url.searchParams.set('query', name);
  url.searchParams.set('pageSize', '1');
  url.searchParams.set('dataType', 'Foundation,SR Legacy');

  try {
    const response = await fetchImpl(url, {
      headers: { 'x-api-key': apiKey },
      signal: AbortSignal.timeout(options.timeoutMs ?? 8000),
    });
    if (!response.ok) return null;
    const payload = await response.json();
    return nutritionPer100g(payload?.foods?.[0]);
  } catch {
    // Enrichment is best-effort: a USDA outage must not fail a check-in.
    return null;
  }
}

/** True when the model gave us nothing usable for this item. */
export function needsEnrichment(item) {
  return !(item.kcal > 0) && !(item.proteinG > 0);
}

/**
 * Fill in items the model left blank, where the unit converts to grams.
 * Items it cannot improve are returned untouched.
 */
export async function enrichItems(items, options = {}) {
  const lookup = options.lookup ?? lookupFood;

  return Promise.all(
    items.map(async (item) => {
      if (!needsEnrichment(item)) return item;

      const grams = gramsFor(item.qty, item.unit);
      if (grams === null) return item;

      const per100g = await lookup(item.name, options);
      if (!per100g) return item;

      const factor = grams / 100;
      return {
        ...item,
        kcal: round(per100g.kcal * factor),
        proteinG: round(per100g.proteinG * factor),
        carbsG: round(per100g.carbsG * factor),
        fatG: round(per100g.fatG * factor),
        source: 'usda',
      };
    }),
  );
}

function round(value) {
  return Math.round(value * 10) / 10;
}

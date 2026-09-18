import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { enrichItems, gramsFor, needsEnrichment, nutritionPer100g } from '../src/usda.js';

describe('gramsFor', () => {
  it('converts mass and volume units', () => {
    assert.equal(gramsFor(100, 'g'), 100);
    assert.equal(gramsFor(1, 'kg'), 1000);
    assert.equal(gramsFor(1, 'cup'), 240);
    assert.ok(Math.abs(gramsFor(1, 'oz') - 28.3495) < 0.001);
  });

  it('is case and spacing insensitive', () => {
    assert.equal(gramsFor(100, ' G '), 100);
  });

  it('returns null for household units it cannot weigh', () => {
    assert.equal(gramsFor(6, 'large'), null);
    assert.equal(gramsFor(2, 'medium'), null);
    assert.equal(gramsFor(1, ''), null);
  });
});

describe('nutritionPer100g', () => {
  it('reads the four nutrients we care about', () => {
    const result = nutritionPer100g({
      foodNutrients: [
        { nutrientId: 1008, value: 389 },
        { nutrientId: 1003, value: 16.9 },
        { nutrientId: 1005, value: 66.3 },
        { nutrientId: 1004, value: 6.9 },
      ],
    });
    assert.equal(result.kcal, 389);
    assert.equal(result.proteinG, 16.9);
  });

  it('returns null when energy is missing', () => {
    assert.equal(nutritionPer100g({ foodNutrients: [{ nutrientId: 1003, value: 5 }] }), null);
  });

  it('returns null for a missing food', () => {
    assert.equal(nutritionPer100g(undefined), null);
  });
});

describe('enrichItems', () => {
  const blankOats = { name: 'Oats', qty: 100, unit: 'g', kcal: 0, proteinG: 0, carbsG: 0, fatG: 0 };

  it('fills a blank item from USDA data', async () => {
    const [item] = await enrichItems([blankOats], {
      lookup: async () => ({ kcal: 389, proteinG: 16.9, carbsG: 66.3, fatG: 6.9 }),
    });
    assert.equal(item.kcal, 389);
    assert.equal(item.source, 'usda');
  });

  it('scales USDA per-100g data to the quantity eaten', async () => {
    const [item] = await enrichItems([{ ...blankOats, qty: 50 }], {
      lookup: async () => ({ kcal: 389, proteinG: 16.9, carbsG: 66.3, fatG: 6.9 }),
    });
    assert.equal(item.kcal, 194.5);
    assert.equal(item.proteinG, 8.5);
  });

  it('leaves items the model already filled in', async () => {
    const good = { name: 'Egg', qty: 6, unit: 'large', kcal: 432, proteinG: 36, carbsG: 2, fatG: 30 };
    const [item] = await enrichItems([good], {
      lookup: async () => { throw new Error('should not be called'); },
    });
    assert.equal(item.kcal, 432);
    assert.equal(item.source, undefined);
  });

  it('leaves blank items in household units alone', async () => {
    const [item] = await enrichItems(
      [{ name: 'Egg', qty: 6, unit: 'large', kcal: 0, proteinG: 0, carbsG: 0, fatG: 0 }],
      { lookup: async () => ({ kcal: 143, proteinG: 12.6, carbsG: 0.7, fatG: 9.5 }) },
    );
    assert.equal(item.kcal, 0);
  });

  it('keeps the item when USDA has no match', async () => {
    const [item] = await enrichItems([blankOats], { lookup: async () => null });
    assert.equal(item.kcal, 0);
  });
});

describe('needsEnrichment', () => {
  it('is true only when both calories and protein are absent', () => {
    assert.equal(needsEnrichment({ kcal: 0, proteinG: 0 }), true);
    assert.equal(needsEnrichment({ kcal: 100, proteinG: 0 }), false);
    assert.equal(needsEnrichment({ kcal: 0, proteinG: 5 }), false);
  });
});

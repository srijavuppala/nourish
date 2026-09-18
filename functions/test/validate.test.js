import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { kcalFromMacros, validateItem, validateResponse } from '../src/validate.js';

describe('validateItem', () => {
  it('accepts a well-formed item', () => {
    const { item } = validateItem({
      name: 'Egg',
      qty: 6,
      unit: 'large',
      kcal: 432,
      proteinG: 36,
      carbsG: 2.4,
      fatG: 30,
    });
    assert.equal(item.name, 'Egg');
    assert.equal(item.qty, 6);
    assert.equal(item.proteinG, 36);
  });

  it('coerces numbers the model returned as strings', () => {
    const { item } = validateItem({
      name: 'Banana',
      qty: '2',
      unit: 'medium',
      kcal: '210',
      proteinG: '2.6',
      carbsG: '54',
      fatG: '0.8',
    });
    assert.equal(item.qty, 2);
    assert.equal(item.kcal, 210);
  });

  it('rejects an item with no name', () => {
    assert.ok(validateItem({ name: '   ', qty: 1 }).error);
  });

  it('rejects a zero or missing quantity', () => {
    assert.ok(validateItem({ name: 'Rice', qty: 0 }).error);
    assert.ok(validateItem({ name: 'Rice' }).error);
  });

  it('rejects negative nutrition', () => {
    const { item } = validateItem({
      name: 'Rice',
      qty: 1,
      unit: 'cup',
      kcal: -50,
      proteinG: 4,
      carbsG: 45,
      fatG: 0.4,
    });
    // Negative calories fall back to the macro-derived figure.
    assert.equal(item.kcal, kcalFromMacros({ proteinG: 4, carbsG: 45, fatG: 0.4 }));
  });

  it('rejects implausible quantities', () => {
    assert.ok(validateItem({ name: 'Egg', qty: 99999, kcal: 10 }).error);
  });

  it('recomputes calories when they contradict the macros', () => {
    // 36g protein + 2g carbs + 30g fat is ~422 kcal, not 72.
    const { item } = validateItem({
      name: 'Egg',
      qty: 6,
      unit: 'large',
      kcal: 72,
      proteinG: 36,
      carbsG: 2,
      fatG: 30,
    });
    assert.equal(item.kcal, 422);
  });

  it('keeps stated calories when they roughly agree with the macros', () => {
    const { item } = validateItem({
      name: 'Oats',
      qty: 100,
      unit: 'g',
      kcal: 380,
      proteinG: 13,
      carbsG: 67,
      fatG: 7,
    });
    assert.equal(item.kcal, 380);
  });
});

describe('validateResponse', () => {
  it('asks a question when nothing could be parsed', () => {
    const result = validateResponse({ items: [], needsClarification: false });
    assert.equal(result.needsClarification, true);
    assert.ok(result.question.length > 0);
  });

  it('handles a null response without throwing', () => {
    const result = validateResponse(null);
    assert.equal(result.items.length, 0);
    assert.equal(result.needsClarification, true);
  });

  it('keeps good items and drops bad ones', () => {
    const result = validateResponse({
      items: [
        { name: 'Egg', qty: 6, unit: 'large', kcal: 432, proteinG: 36, carbsG: 2, fatG: 30 },
        { name: '', qty: 1 },
      ],
      needsClarification: false,
      question: '',
    });
    assert.equal(result.items.length, 1);
    assert.equal(result.rejected.length, 1);
  });

  it('passes through a clarifying question alongside parsed items', () => {
    const result = validateResponse({
      items: [
        { name: 'Egg', qty: 6, unit: 'large', kcal: 432, proteinG: 36, carbsG: 2, fatG: 30 },
      ],
      needsClarification: true,
      question: 'How much toast did you have?',
    });
    assert.equal(result.items.length, 1);
    assert.equal(result.needsClarification, true);
    assert.equal(result.question, 'How much toast did you have?');
  });

  it('caps the number of items', () => {
    const many = Array.from({ length: 50 }, (_, index) => ({
      name: `Food ${index}`,
      qty: 1,
      unit: 'g',
      kcal: 10,
      proteinG: 1,
      carbsG: 1,
      fatG: 0.2,
    }));
    assert.equal(validateResponse({ items: many }).items.length, 20);
  });
});

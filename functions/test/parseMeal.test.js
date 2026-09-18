import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { InvalidInput, MAX_TEXT_LENGTH, parseMeal } from '../src/parseMeal.js';

/** A stub model that always returns the same structured answer. */
function stubModel(response, calls = []) {
  return async (input) => {
    calls.push(input);
    return response;
  };
}

const sixEggsTwoBananas = {
  items: [
    { name: 'Egg', qty: 6, unit: 'large', kcal: 432, proteinG: 36, carbsG: 2.4, fatG: 30 },
    { name: 'Banana', qty: 2, unit: 'medium', kcal: 210, proteinG: 2.6, carbsG: 54, fatG: 0.8 },
  ],
  needsClarification: false,
  question: '',
};

describe('parseMeal', () => {
  it('parses the PRD example into two items', async () => {
    const result = await parseMeal(
      { text: 'six eggs and two bananas', slot: 'breakfast' },
      { parseWithGemini: stubModel(sixEggsTwoBananas), enrichItems: async (i) => i },
    );

    assert.equal(result.items.length, 2);
    assert.equal(result.items[0].name, 'Egg');
    assert.equal(result.items[0].qty, 6);
    assert.equal(result.items[1].name, 'Banana');
    assert.equal(result.needsClarification, false);
  });

  it('passes the meal slot through to the model', async () => {
    const calls = [];
    await parseMeal(
      { text: 'oats', slot: 'breakfast' },
      { parseWithGemini: stubModel(sixEggsTwoBananas, calls), enrichItems: async (i) => i },
    );
    assert.equal(calls[0].slot, 'breakfast');
  });

  it('ignores a slot that is not a real meal slot', async () => {
    const calls = [];
    await parseMeal(
      { text: 'oats', slot: 'brunch' },
      { parseWithGemini: stubModel(sixEggsTwoBananas, calls), enrichItems: async (i) => i },
    );
    assert.equal(calls[0].slot, null);
  });

  it('rejects empty input', async () => {
    await assert.rejects(
      () => parseMeal({ text: '   ' }, { parseWithGemini: stubModel(sixEggsTwoBananas) }),
      InvalidInput,
    );
  });

  it('rejects input that is too long', async () => {
    await assert.rejects(
      () => parseMeal(
        { text: 'a'.repeat(MAX_TEXT_LENGTH + 1) },
        { parseWithGemini: stubModel(sixEggsTwoBananas) },
      ),
      InvalidInput,
    );
  });

  it('asks a clarifying question instead of failing when nothing parses', async () => {
    const result = await parseMeal(
      { text: 'the usual' },
      {
        parseWithGemini: stubModel({ items: [], needsClarification: true, question: 'What do you usually have?' }),
        enrichItems: async (i) => i,
      },
    );

    assert.equal(result.items.length, 0);
    assert.equal(result.needsClarification, true);
    assert.equal(result.question, 'What do you usually have?');
  });

  it('returns the items it understood alongside a clarifying question', async () => {
    const result = await parseMeal(
      { text: 'six eggs and some toast' },
      {
        parseWithGemini: stubModel({
          items: sixEggsTwoBananas.items.slice(0, 1),
          needsClarification: true,
          question: 'How many slices of toast?',
        }),
        enrichItems: async (i) => i,
      },
    );

    assert.equal(result.items.length, 1);
    assert.equal(result.needsClarification, true);
    assert.equal(result.question, 'How many slices of toast?');
  });

  it('survives a model that returns nonsense', async () => {
    const result = await parseMeal(
      { text: 'six eggs' },
      { parseWithGemini: stubModel('not json at all'), enrichItems: async (i) => i },
    );
    assert.equal(result.needsClarification, true);
    assert.ok(result.question.length > 0);
  });

  it('propagates a model outage as a thrown error, not a bad meal', async () => {
    await assert.rejects(
      () => parseMeal(
        { text: 'six eggs' },
        { parseWithGemini: async () => { throw new Error('Gemini request failed with status 503'); } },
      ),
      /503/,
    );
  });
});

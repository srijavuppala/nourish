import { parseWithGemini } from './gemini.js';
import { enrichItems } from './usda.js';
import { validateResponse } from './validate.js';

export const MAX_TEXT_LENGTH = 500;

/** Thrown for input the caller got wrong, so the wiring can map it to a code. */
export class InvalidInput extends Error {}

/**
 * The whole parse pipeline, with its collaborators injectable so it can be
 * tested without a network.
 *
 * @returns `{ items, needsClarification, question }`
 */
export async function parseMeal(input, deps = {}) {
  const text = typeof input?.text === 'string' ? input.text.trim() : '';
  if (!text) throw new InvalidInput('Tell me what you ate.');
  if (text.length > MAX_TEXT_LENGTH) {
    throw new InvalidInput('That is a bit long — try one meal at a time.');
  }

  const slot = ['breakfast', 'lunch', 'dinner', 'snack'].includes(input?.slot)
    ? input.slot
    : null;

  const callModel = deps.parseWithGemini ?? parseWithGemini;
  const enrich = deps.enrichItems ?? enrichItems;

  const raw = await callModel({ text, slot }, deps);
  const validated = validateResponse(raw);

  if (validated.items.length === 0) {
    return {
      items: [],
      needsClarification: true,
      question: validated.question,
    };
  }

  const items = await enrich(validated.items, deps);

  return {
    items,
    needsClarification: validated.needsClarification,
    question: validated.question,
  };
}

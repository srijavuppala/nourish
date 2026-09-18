// Prompt and response schema for meal parsing.

/**
 * Gemini structured-output schema. Constraining the shape here removes most of
 * the malformed-JSON failure modes before validation ever runs.
 */
export const RESPONSE_SCHEMA = {
  type: 'object',
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          qty: { type: 'number' },
          unit: { type: 'string' },
          kcal: { type: 'number' },
          proteinG: { type: 'number' },
          carbsG: { type: 'number' },
          fatG: { type: 'number' },
        },
        required: ['name', 'qty', 'unit', 'kcal', 'proteinG', 'carbsG', 'fatG'],
      },
    },
    needsClarification: { type: 'boolean' },
    question: { type: 'string' },
  },
  required: ['items', 'needsClarification', 'question'],
};

const SYSTEM_PROMPT = `You convert a person's plain description of a meal into structured nutrition data.

Rules:
- Return one entry per distinct food. "Six eggs and two bananas" is two entries.
- qty is the number the person ate. unit is the household measure they used
  ("large", "medium", "cup", "slice", "g", "ml"). Use "" when a food has no
  natural unit.
- kcal, proteinG, carbsG and fatG are totals for the whole qty, NOT per unit.
  Six large eggs is about 432 kcal in total, not 72.
- Calories must agree with the macros at 4 kcal/g protein, 4 kcal/g carbs and
  9 kcal/g fat.
- Use typical values for a normal portion when the person is vague. Do not
  refuse over uncertainty; approximate and move on.
- Set needsClarification to true ONLY when a food is genuinely ambiguous about
  how much was eaten, or you cannot tell what a food is. Put exactly one short
  question in "question" and still return whatever items you did understand.
- Never invent foods the person did not mention.`;

/** The user-facing turn, with the meal slot as context when we know it. */
export function buildUserPrompt({ text, slot }) {
  const context = slot ? `The person is describing their usual ${slot}.` : '';
  return [context, `They said: "${String(text).trim()}"`]
    .filter(Boolean)
    .join('\n');
}

export function buildRequestBody({ text, slot }) {
  return {
    systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
    contents: [{ role: 'user', parts: [{ text: buildUserPrompt({ text, slot }) }] }],
    generationConfig: {
      temperature: 0.2,
      responseMimeType: 'application/json',
      responseSchema: RESPONSE_SCHEMA,
    },
  };
}

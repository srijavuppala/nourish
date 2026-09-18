import { buildRequestBody } from './prompt.js';

const DEFAULT_MODEL = 'gemini-2.5-flash';
const ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/models';

/**
 * Call Gemini and return the parsed JSON object it produced.
 *
 * The key is read from the environment, which on deploy is bound to a Secret
 * Manager secret — it must never be compiled into the app.
 */
export async function parseWithGemini({ text, slot }, options = {}) {
  const apiKey = options.apiKey ?? process.env.GEMINI_API_KEY;
  if (!apiKey) throw new Error('GEMINI_API_KEY is not configured');

  const model = options.model ?? process.env.GEMINI_MODEL ?? DEFAULT_MODEL;
  const fetchImpl = options.fetch ?? globalThis.fetch;

  const response = await fetchImpl(
    `${ENDPOINT}/${model}:generateContent`,
    {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: JSON.stringify(buildRequestBody({ text, slot })),
      signal: AbortSignal.timeout(options.timeoutMs ?? 20000),
    },
  );

  if (!response.ok) {
    // Deliberately does not include the body: it can echo the request and we
    // do not want a user's meal text in the logs.
    throw new Error(`Gemini request failed with status ${response.status}`);
  }

  const payload = await response.json();
  return extractJson(payload);
}

/** Pull the JSON object out of a Gemini `generateContent` response. */
export function extractJson(payload) {
  const parts = payload?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) return null;

  const text = parts.map((part) => part?.text ?? '').join('').trim();
  if (!text) return null;

  try {
    return JSON.parse(text);
  } catch {
    // Structured output should make this unreachable, but a stray code fence
    // is cheap to recover from.
    const start = text.indexOf('{');
    const end = text.lastIndexOf('}');
    if (start === -1 || end <= start) return null;
    try {
      return JSON.parse(text.slice(start, end + 1));
    } catch {
      return null;
    }
  }
}

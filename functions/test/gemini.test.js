import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { extractJson, parseWithGemini } from '../src/gemini.js';
import { buildRequestBody, buildUserPrompt } from '../src/prompt.js';

describe('extractJson', () => {
  it('reads the JSON body out of a generateContent response', () => {
    const payload = {
      candidates: [{ content: { parts: [{ text: '{"items":[],"needsClarification":false,"question":""}' }] } }],
    };
    assert.deepEqual(extractJson(payload), { items: [], needsClarification: false, question: '' });
  });

  it('joins parts that arrived split', () => {
    const payload = {
      candidates: [{ content: { parts: [{ text: '{"items":' }, { text: '[]}' }] } }],
    };
    assert.deepEqual(extractJson(payload), { items: [] });
  });

  it('recovers JSON wrapped in a code fence', () => {
    const payload = {
      candidates: [{ content: { parts: [{ text: '```json\n{"items":[]}\n```' }] } }],
    };
    assert.deepEqual(extractJson(payload), { items: [] });
  });

  it('returns null for an empty or blocked response', () => {
    assert.equal(extractJson({}), null);
    assert.equal(extractJson({ candidates: [] }), null);
    assert.equal(extractJson({ candidates: [{ content: { parts: [{ text: '' }] } }] }), null);
  });

  it('returns null for text that is not JSON at all', () => {
    const payload = {
      candidates: [{ content: { parts: [{ text: 'I cannot help with that.' }] } }],
    };
    assert.equal(extractJson(payload), null);
  });
});

describe('buildRequestBody', () => {
  it('asks for JSON output against the schema', () => {
    const body = buildRequestBody({ text: 'six eggs', slot: 'breakfast' });
    assert.equal(body.generationConfig.responseMimeType, 'application/json');
    assert.ok(body.generationConfig.responseSchema.properties.items);
  });

  it('includes the meal slot as context', () => {
    assert.match(buildUserPrompt({ text: 'six eggs', slot: 'breakfast' }), /breakfast/);
  });

  it('omits slot context when there is none', () => {
    const prompt = buildUserPrompt({ text: 'six eggs', slot: null });
    assert.match(prompt, /six eggs/);
    assert.doesNotMatch(prompt, /usual null/);
  });
});

describe('parseWithGemini', () => {
  it('sends the key as a header, never in the URL', async () => {
    let seenUrl;
    let seenHeaders;
    await parseWithGemini(
      { text: 'six eggs', slot: 'breakfast' },
      {
        apiKey: 'test-key',
        fetch: async (url, init) => {
          seenUrl = String(url);
          seenHeaders = init.headers;
          return {
            ok: true,
            json: async () => ({ candidates: [{ content: { parts: [{ text: '{"items":[]}' }] } }] }),
          };
        },
      },
    );

    assert.doesNotMatch(seenUrl, /test-key/);
    assert.equal(seenHeaders['x-goog-api-key'], 'test-key');
  });

  it('throws when the key is missing rather than calling out', async () => {
    const original = process.env.GEMINI_API_KEY;
    delete process.env.GEMINI_API_KEY;
    try {
      await assert.rejects(
        () => parseWithGemini({ text: 'six eggs' }, { fetch: async () => { throw new Error('should not be called'); } }),
        /GEMINI_API_KEY/,
      );
    } finally {
      if (original !== undefined) process.env.GEMINI_API_KEY = original;
    }
  });

  it('throws on a non-OK response without leaking the body into the message', async () => {
    await assert.rejects(
      () => parseWithGemini(
        { text: 'six eggs' },
        {
          apiKey: 'test-key',
          fetch: async () => ({ ok: false, status: 429, json: async () => ({ error: 'six eggs' }) }),
        },
      ),
      (error) => error.message.includes('429') && !error.message.includes('six eggs'),
    );
  });
});

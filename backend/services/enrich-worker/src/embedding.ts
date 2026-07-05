import { GoogleGenerativeAI } from '@google/generative-ai';
import { createHash } from 'node:crypto';
import { EMBEDDING_MODEL, EMBEDDING_DIM } from '@pp/schema';

/**
 * Embed the canonical English summary (§4.1). Uses gemini-embedding-001 at 768
 * dims when a key is present; otherwise a deterministic hashed bag-of-words
 * vector so clustering stays testable and the demo runs offline.
 */
export async function embedText(text: string): Promise<number[]> {
  const apiKey = process.env.GEMINI_API_KEY?.trim();
  if (apiKey) {
    try {
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({ model: EMBEDDING_MODEL });
      const result = await model.embedContent({
        content: { role: 'user', parts: [{ text }] },
        taskType: 'SEMANTIC_SIMILARITY',
        outputDimensionality: EMBEDDING_DIM,
      } as Parameters<typeof model.embedContent>[0]);
      const values = result.embedding?.values;
      if (values?.length) return l2normalize(values);
    } catch (err) {
      console.warn('Embedding via Gemini failed, falling back:', err);
    }
  }
  return deterministicEmbedding(text);
}

/** Stable per-token hashed embedding — same dimension as Gemini path (EMBEDDING_DIM). */
function deterministicEmbedding(text: string): number[] {
  const dim = EMBEDDING_DIM;
  const vec = new Array(dim).fill(0) as number[];
  const tokens = text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter((t) => t.length > 2);
  for (const token of tokens) {
    const hash = createHash('md5').update(token).digest();
    const idx = hash.readUInt32BE(0) % dim;
    vec[idx] += 1;
  }
  return l2normalize(vec);
}

export function l2normalize(vec: number[]): number[] {
  const norm = Math.sqrt(vec.reduce((acc, v) => acc + v * v, 0));
  if (norm === 0) return vec;
  return vec.map((v) => v / norm);
}

export function cosineSimilarity(a: number[], b: number[]): number {
  if (a.length !== b.length) {
    throw new Error(`Embedding dimension mismatch: ${a.length} vs ${b.length}`);
  }
  let dot = 0;
  for (let i = 0; i < a.length; i++) dot += a[i] * b[i];
  return dot; // both already L2-normalized
}

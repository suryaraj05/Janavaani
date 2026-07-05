/**
 * eval_clustering.ts — clustering precision/recall harness (§4.2).
 * Reads a labeled-pairs CSV (summary_a,summary_b,same) and reports how well
 * cosine similarity at each threshold band separates same-demand pairs from
 * distinct ones. Use it to tune the 0.80 / 0.65 bands against real seed data.
 *
 * Usage: tsx scripts/eval_clustering.ts <labeled_pairs.csv>
 * CSV columns: summary_a,summary_b,same  (same in {0,1})
 */
import { readFileSync, existsSync } from 'node:fs';
import { embedText, cosineSimilarity } from '../services/enrich-worker/src/embedding.js';

async function main(): Promise<void> {
  const path = process.argv[2];
  if (!path || !existsSync(path)) {
    console.error('Provide a labeled-pairs CSV: tsx scripts/eval_clustering.ts <csv>');
    process.exit(1);
  }

  const lines = readFileSync(path, 'utf-8').trim().split(/\r?\n/).slice(1);
  const thresholds = [0.6, 0.65, 0.7, 0.75, 0.8, 0.85];

  const rows = await Promise.all(
    lines.map(async (line) => {
      const [a, b, same] = splitCsv(line);
      const sim = cosineSimilarity(await embedText(a), await embedText(b));
      return { same: same === '1', sim };
    }),
  );

  console.log('threshold\tprecision\trecall\tf1');
  for (const t of thresholds) {
    let tp = 0;
    let fp = 0;
    let fn = 0;
    for (const r of rows) {
      const predicted = r.sim >= t;
      if (predicted && r.same) tp++;
      else if (predicted && !r.same) fp++;
      else if (!predicted && r.same) fn++;
    }
    const precision = tp + fp > 0 ? tp / (tp + fp) : 0;
    const recall = tp + fn > 0 ? tp / (tp + fn) : 0;
    const f1 = precision + recall > 0 ? (2 * precision * recall) / (precision + recall) : 0;
    console.log(`${t}\t\t${precision.toFixed(2)}\t\t${recall.toFixed(2)}\t${f1.toFixed(2)}`);
  }
}

function splitCsv(line: string): [string, string, string] {
  const parts = line.split(',');
  const same = parts.pop() ?? '0';
  const b = parts.pop() ?? '';
  const a = parts.join(',');
  return [a.replace(/^"|"$/g, ''), b.replace(/^"|"$/g, ''), same.trim()];
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

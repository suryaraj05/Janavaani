import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { parse as parseYaml } from 'yaml';
import { EvidenceSpecSchema, findRepoRoot, type EvidenceSpec } from '@pp/schema';

const SPEC_DIR = process.env.EVIDENCE_SPEC_DIR ?? join(findRepoRoot(), 'evidence_specs');

/** Load per-subcategory evidence specs from evidence_specs/*.yaml (§5.3). */
export function loadEvidenceSpecs(): Map<string, EvidenceSpec> {
  const specs = new Map<string, EvidenceSpec>();
  if (!existsSync(SPEC_DIR)) return specs;

  for (const file of readdirSync(SPEC_DIR)) {
    if (!file.endsWith('.yaml') && !file.endsWith('.yml')) continue;
    const subcategory = file.replace(/^[a-z]+\./, '').replace(/\.ya?ml$/, '');
    try {
      const raw = parseYaml(readFileSync(join(SPEC_DIR, file), 'utf-8')) as Record<string, unknown>;
      const parsed = EvidenceSpecSchema.parse({ subcategory, ...raw });
      specs.set(subcategory, parsed);
    } catch (err) {
      console.warn(`Skipping invalid evidence spec ${file}:`, err);
    }
  }
  return specs;
}

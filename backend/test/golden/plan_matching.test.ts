import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { embedText, cosineSimilarity } from '../../services/enrich-worker/src/embedding.js';
import { textSimilarity } from '../../services/enrich-worker/src/clustering.js';
import { PLAN_CLUSTER_LINK_THRESHOLD } from '../../shared/schema/src/developmentPlan.js';
import { allowedMandalCodes } from '../../shared/schema/src/adjacency.js';

/**
 * Phase D acceptance test — development plan ↔ cluster matching (offline).
 */
describe('development plan matching (Phase D)', () => {
  const schoolPlanTitle =
    'Upgrade village school beyond grade 7 to secondary school access near Ghatkesar';
  const schoolPlanText =
    'District plan to upgrade feeder schools in Ghatkesar so children do not travel 6 km to high school.';
  const schoolClusterSummary =
    'Upgrade village school beyond grade 7 / secondary school access near Ghatkesar';

  const roadPlanTitle = 'Resurface Uppal main road junction';

  it('links school development plan to school-upgrade cluster above threshold', async () => {
    const planEmb = await embedText(`${schoolPlanTitle}. ${schoolPlanText}`);
    const clusterEmb = await embedText(schoolClusterSummary);
    const embedSim = cosineSimilarity(planEmb, clusterEmb);
    const textSim = Math.max(
      textSimilarity(schoolPlanTitle, schoolClusterSummary),
      textSimilarity(schoolPlanText, schoolClusterSummary),
    );
    const sim = Math.max(embedSim, textSim);
    assert.ok(
      sim >= PLAN_CLUSTER_LINK_THRESHOLD,
      `school plan should match school cluster (${sim.toFixed(3)} >= ${PLAN_CLUSTER_LINK_THRESHOLD})`,
    );
  });

  it('does not link road plan to school cluster', async () => {
    const roadPlanText =
      'Municipal resurfacing of Uppal junction approach road.';
    const planEmb = await embedText(`${roadPlanTitle}. ${roadPlanText}`);
    const clusterEmb = await embedText(schoolClusterSummary);
    const embedSim = cosineSimilarity(planEmb, clusterEmb);
    const textSim = Math.max(
      textSimilarity(roadPlanTitle, schoolClusterSummary),
      textSimilarity(roadPlanText, schoolClusterSummary),
    );
    const sim = Math.max(embedSim, textSim);
    assert.ok(
      sim < PLAN_CLUSTER_LINK_THRESHOLD,
      `road plan must not spuriously link to school cluster (${sim.toFixed(3)})`,
    );
  });

  it('respects mandal adjacency pre-filter for plan matching', () => {
    const allowed = allowedMandalCodes('TS-0417', 'medium')!;
    assert.ok(allowed.has('TS-0417'));
    assert.ok(allowed.has('TS-0418'));
    assert.ok(!allowed.has('TS-9999'));
  });
});

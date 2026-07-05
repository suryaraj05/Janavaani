# People's Priorities — Feature Validation, Value-Add Review & Cursor Build Prompt

**Companion to:** `peoples-priorities-architecture.md` (v1.0 → amended to v1.1 by §2 below)
**Scope of this pass:** validate model choices against May–July 2026 releases, identify genuinely load-bearing gaps, consolidate the feature list and plan, and produce a standalone Cursor build prompt (§5).
**Prior decisions are treated as settled** except where this document states a concrete reason to amend one. Exactly one amendment is made (triage model ID, §2.1).

---

## 1. The brief — what this is and why it's built this way

**The problem.** An MP's office is a funnel for requests: people speak up at public meetings, send letters, post on social media, file grievances on portals, and stop the MP at events. Nothing joins these up. Nobody can say "437 distinct people across four channels are asking for the same school upgrade" — let alone "and the enrollment data says they're right." So decisions get made on whoever shouted loudest, most recently, closest to the office. The organizers' own example is the sharp version: a community asks for a school upgrade, another group wants a vocational centre, and there is currently no objective way to weigh one against the other. Both feel urgent. Only one can go in this year's works list.

**What the system does, in practice.** A citizen sends a voice note in Telugu to a WhatsApp number, or taps a mic button in an app, or speaks at a public meeting whose recording gets uploaded, or comments under the MP's YouTube video. Whatever the language or format, Gemini converts each of these into the same structured record: what is being asked for, in which category, where. The system then notices when different records are asking for the same underlying thing — a Telugu voice note, a Hindi text, and an English meeting remark about the same school become *one tracked demand with three supporters*, not three rows. That demand gets pinned to a real administrative area and checked against real public data — for schools, the government's own UDISE+ records: how many children are in the feeder grades, how many secondary seats exist nearby, how far children travel. Demand, data-backed need, evidence quality, and freshness combine into one score, and the MP's dashboard shows a ranked list where every rank has a plain-English explanation with the actual figures and their sources. Staff can play the original voice notes behind any number.

**Why it's built this way — each major choice, in one honest sentence each:**

- **Many channels, because citizens won't change their behavior for us.** A platform that only counts app users measures smartphone ownership, not need. Meeting the farmer on WhatsApp, the elder at the janasabha, and the student in the comments is the difference between a demand map and a connectivity map.
- **Language is handled once, at intake, then never again.** Every submission is translated and restated as one neutral English sentence describing the request. Everything downstream — matching, counting, scoring — works on that sentence, so Telugu and Hindi speakers are counted in exactly the same system as English speakers, with their original words always preserved and shown.
- **Clustering, because raw counts lie twice.** Without merging, one organized group sending fifty messages looks like fifty demands, and fifty genuine citizens using three different channels look like three separate small issues. Merging by meaning — and counting *unique people*, not messages — is what makes the volume number honest.
- **Evidence sits beside demand, because complaint volume measures who is loudest, not who needs most.** The best-connected neighborhoods complain most effectively. Weighing citizen demand against public data (35% evidence vs 30% demand in the score) means a quieter mandal with 412 children and no secondary school within five kilometres can outrank a louder one that already has three. That single design choice *is* the product.
- **Not all evidence is equal, and the system says so.** A GPS-tagged photo from a signed-in app user and an anonymous pseudonymous YouTube comment both count — but at 1.0 and 0.3 weight respectively, in a table anyone can inspect. This is an editorial policy made explicit, not hidden in code.
- **Every rank comes with its "why," because an MP has to defend the list in public.** The explanation panel shows the exact figures, their dataset and year, and any caveats (weak location data, no dataset coverage, simulated sources). The AI writes the prose but is forbidden from computing or adding numbers — arithmetic and language generation are strictly separated, so the numbers are always auditable.
- **What we can't integrate live, we mock loudly.** Government grievance portals have no public API, and scraping them is legally dubious; Meta platforms gate access behind lengthy review. Those connectors run on clearly-labeled fixture data behind the same interface a real integration would use — every simulated record carries a visible badge. The honest version demos better than the faked one, and a real integration drops in later without redesign.

If Surya needs to explain the system in one line: *it turns thousands of scattered voices in three languages into a short, ranked, evidence-backed works list the MP can defend — and it shows its work.*

---

## 2. Model/tool verification (July 2026)

### 2.1 Triage model: **switch `gemini-3-flash` → `gemini-3.5-flash`** — amendment adopted

Verified: Gemini 3.5 Flash went **GA at Google I/O on 19–20 May 2026**, stable model ID `gemini-3.5-flash`, and — the detail that decides this — the stable ID **replaces the `gemini-3-flash-preview` identifier** ([Google announcement](https://blog.google/innovation-and-ai/models-and-research/gemini-models/gemini-3-5/), [MarkTechPost](https://www.marktechpost.com/2026/05/20/google-introduces-gemini-3-5-flash-at-i-o-2026-a-faster-and-cheaper-model-for-ai-agents-and-coding/)). So this is not "newer is shinier": v1.0's model string points at a preview lineage with a deprecation clock on it. Building a pilot-bound system on a preview ID when the GA replacement exists is the wrong risk.

- **What changes:** the `TRIAGE_MODEL` config value, the §2/§3/§7 model-string mentions in v1.0 (now patched in place — v1.0 is bumped to v1.1), and nothing else. Prompts, response schemas, and pipeline shape are untouched; the architecture was deliberately model-agnostic behind config.
- **Verify before demo (flagged, not asserted):** 3.5 Flash appears free-tier eligible per [Google's pricing page](https://ai.google.dev/gemini-api/docs/pricing) as of late June 2026, but I could not confirm its exact free RPD/RPM — check the project's live limits in AI Studio during Phase 1 and keep `gemini-3.1-flash-lite` as the configured fallback if 3.5 Flash's free quota is tighter than the ~1,500 RPD the design assumes.
- **Paid-path note:** 3.5 Flash paid pricing is reported at $1.50/M input, $9.00/M output ([codersera](https://codersera.com/blog/gemini-3-5-flash-gemini-spark-guide-2026/)) — materially pricier than the old Flash paid tier. This does **not** change v1.0 §7's scale-up plan, which already routed paid-tier volume to Flash-Lite + Batch API; it reinforces it.

### 2.2 Embedding model: **keep `gemini-embedding-001` @ 768** — no change

`gemini-embedding-2-preview` is real and impressive — Google's first natively multimodal embedding model (text/image/video/audio in one space, 100+ languages, MRL dims incl. 768), launched **10 March 2026, public preview** ([Google](https://blog.google/innovation-and-ai/models-and-research/gemini-models/gemini-embedding-2/), [model docs](https://ai.google.dev/gemini-api/docs/models/gemini-embedding-2-preview)). It is still the wrong choice here, for three reasons in order of weight:

1. **It wouldn't simplify our pipeline, because the pipeline's "extra" step isn't extra.** The tempting pitch is "embed the raw voice note directly, skip transcription." But triage exists to produce the category, translation, location mentions, PII scrubbing, and canonical summary — all required outputs regardless of how embedding happens. The transcript is a byproduct of work we must do anyway. Embedding raw audio would *remove nothing* and would *reintroduce* the modality variance (voice verbosity vs. comment slang) that embedding the canonical English sentence deliberately normalizes away. Our normalization is a feature, not a workaround.
2. **Preview status is a live risk, GA is not.** Preview models carry no stability guarantee and can be revised or withdrawn between hackathon and pilot. `gemini-embedding-001` is GA and [top-ranked multilingual on MTEB](https://developers.googleblog.com/gemini-embedding-available-gemini-api/) — there is no quality deficit being tolerated.
3. **Switching embedding spaces invalidates calibration.** The 0.80/0.65 threshold bands are tuned against a labeled-pairs set *in a specific embedding space*. A swap re-opens that tuning for zero pipeline benefit.

**When to revisit:** at embedding-2 GA, and only if the §4.1 fallback trigger fires (canonical-summary embedding proving lossy on real data) or a true cross-modal need emerges (e.g., clustering photos *as photos*). Neither is in this brief.

### 2.3 Everything else — spot-checked, holds

Meeting extraction escalation path (3.5 Pro exists as the successor tier if Flash extraction quality disappoints), BigQuery `VECTOR_SEARCH` + `gemini-embedding-001` availability, and the free-tier posture from v1.0 §7 all remain valid as written. No other amendments.

---

## 3. What genuinely adds value — and what I'm rejecting

Verdict first: **the v1.0 architecture is complete for the stated brief.** Nothing below changes the system's shape. But three gaps are real and load-bearing — all three share one theme: *v1.0 designed the automated pipeline thoroughly and under-designed what happens when the automation is wrong.* That's the difference between a demo and a system an MP's staff will trust.

### 3.1 Staff cluster-repair actions: split, merge, reassign — with centroid recompute

- **The gap.** Auto-merge at ≥0.80 similarity *will* make mistakes — two distinct demands fused, one demand split in two. v1.0's review queue only covers the 0.65–0.80 borderline band; a confident wrong merge at 0.83 is silent and **permanent**. There is currently no way to fix it, and every downstream number (unique citizens, demand term, rank, justification) inherits the error.
- **Why core, not optional.** The product's entire claim is "defensible numbers." The first time a staffer sees an obviously wrong cluster and cannot correct it, trust in every other number dies — and Problem–Solution Fit dies with it. Correction tooling is also the honest answer to the judge question "what happens when the clustering is wrong?" — far stronger than "we tuned the threshold."
- **Cost, honestly.** Low-moderate; no new infrastructure. Three dashboard actions (split cluster / merge two clusters / reassign one submission), one worker endpoint that recomputes affected centroids (the incremental-mean math from v1.0 §4.2 run in reverse is trivial; recompute-from-members is simpler still and fine at cluster sizes ≤ a few hundred), an entry in the cluster's `lifecycle.history` audit trail, and a rule that staff-repaired assignments are pinned (excluded from future auto-merge). Roughly: 1 dashboard screen section (P1), 1 worker route + tests (P3). Fits Phase 2–3.

### 3.2 Cross-channel identity linking (cheap possession-proof version)

- **The gap.** `citizen_hash` is keyed on Firebase UID for app users and phone number for WhatsApp users — so the same engaged citizen using both channels counts **twice** in `unique_citizens`, the score's second-largest term (0.30 weight). The most engaged citizens are exactly the ones most likely to use multiple channels, so the demand term is systematically inflated in a non-random direction, and deliberately using both channels is a free demand-doubling exploit.
- **Why core, not optional.** v1.0 §12 promises flood-resistant unique-person counting; this is a hole in that promise, on the same axis judges will probe (gaming). It also fits the zero-cost constraint precisely *because* of the design already in place: verification happens by the citizen sending a one-time code **to** the WhatsApp number via a `wa.me` deep link from the app — inbound WhatsApp messages are free, no SMS cost, and possession of the phone is proven. Linked accounts unify `citizen_hash` on the phone HMAC.
- **Cost, honestly.** Small: one app screen + deep link (P1), one code-issue/redeem route in `intake-api` + a hash-migration function for the citizen's existing submissions (P2 role). No new infrastructure. **Residual honesty:** unlinked users still double-count; that's disclosed rather than solved — the per-channel composition display from v1.0 §12 stays, and the limitation moves from "unnoticed" to "stated and mitigated."

### 3.3 Burst/anomaly detection — promoted from v1.0's "Phase-3+ maybe" to required

- **The gap.** v1.0 §12 lists coordinated-flooding defenses that are all *passive* (log damping, unique counting, source weights) and mentions burst detection as a future query. But the dashboard has no surface that says "this cluster's demand pattern looks organized" — staff would have to notice it themselves.
- **Why core, not optional.** Astroturfing is the most predictable adversarial behavior for exactly this system (it ranks public spending), and "what stops a WhatsApp forward-chain from buying rank #1?" needs a *visible* answer in the demo, not a verbal one. This is the cheapest possible insurance on the criterion (AI/Technical Execution + Impact credibility) where the design is otherwise strongest.
- **Cost, honestly.** Trivial — it was already sketched. One scheduled BigQuery query in `score-runner`'s existing run (submissions/day vs. the cluster's trailing 14-day baseline; share of near-duplicate texts via pairwise embedding similarity > 0.95 within the cluster), one `anomaly_flags` array on the cluster doc, one amber chip + tooltip in the dashboard, one caveat value (`suspected_coordination`) added to the §3c justification prompt's fixed caveat set. No new infrastructure, no new service.

**One non-feature note:** Firestore offline persistence should simply be enabled in the Flutter app (one SDK flag) with a small pending-upload queue for media — rural connectivity makes this table stakes for the inclusivity claim, but it's configuration hygiene, not a feature, and it's folded into Phase 1 below rather than padded into this list.

### 3.4 Considered and rejected — so nobody re-litigates them later

- **Public citizen-facing ranking portal** — real democratic value, but a new user surface with moderation/political-sensitivity burden the brief doesn't ask for; the WhatsApp "status" query already closes the citizen loop. Post-pilot.
- **"Ask your constituency" RAG chatbot over submissions** — the classic impressive-sounding add-on that changes nothing about how well the system ranks; the why-panel already answers the questions that matter. Bloat.
- **Multimodal embedding swap** — rejected with reasons in §2.2.
- **Earth Engine / satellite validation** — no requirement in the brief maps to it (v1.0 §7 already called this résumé-driven design; still true).
- **What-if weight sliders on the dashboard** — weights are already config (`evidence_specs` + scoring YAML); a live slider is demo candy that invites judges to ask why the weights aren't evidence-derived. Show the weight table; skip the toy.
- **Works/CRM integration (MPLADS tracking)** — real for a deployed office, out of scope for this brief and team size.

---

## 4. Consolidated required features & implementation plan

**Role structure: unchanged.** The three additions slot into existing phases and owners without restructuring — stated per item below. Flagship scenario (school-upgrade vs vocational-centre, one named mandal, built completely and polished) is unchanged from v1.0 §10.

### 4.1 Required features (current, complete list)

**Intake & channels**
1. Flutter citizen app: voice-first submission (mic primary, 60 s cap), photo, text, GPS auto-attach, 3-language UI (te/hi/en), TTS "what we understood" confirm loop; **offline persistence + media upload queue enabled** *(new — config hygiene)*.
2. WhatsApp Cloud API channel (live, dev mode, 5 test numbers): voice/text/media intake, instant ack, confirm buttons, "status" query.
3. Meeting audio upload console (staff) → chunked Gemini extraction of atomic complaints.
4. YouTube comment poller (live, Data API v3).
5. Mock connectors behind the shared `SourceConnector` interface: `pgrs_portal`, `meta_social` fixtures; replay scheduler; `is_simulated` badging end-to-end.

**Understanding & clustering**
6. Gemini triage (multimodal, structured output): language ID, transcript, translation, canonical English summary, taxonomy classification, urgency, location mentions, PII scrub, self-reported confidence (model: `gemini-3.5-flash`, fallback `gemini-3.1-flash-lite`).
7. Embedding (`gemini-embedding-001`, 768-dim, SEMANTIC_SIMILARITY) of canonical summary; BigQuery `VECTOR_SEARCH` incremental cluster assignment with category+geo hard filters and 0.80 / 0.65 threshold bands; provisional members at half demand weight; centroid freeze at n>50.
8. Staff review queue for borderline attachments **plus cluster-repair actions: split / merge / reassign with centroid recompute, audit history, and pinning of staff decisions** *(new — §3.1)*.
9. **Cross-channel identity linking via WhatsApp possession proof; unified citizen_hash migration** *(new — §3.2)*.

**Evidence & ranking**
10. Geocoding tiers (GPS/EXIF → Nominatim bounded → Google fallback → staff pin) + BigQuery `ST_CONTAINS` admin-unit assignment; mandal as guaranteed floor.
11. UDISE+ evidence plane: ETL to `pp.evidence.udise_schools`, boundary + LGD tables, per-subcategory evidence specs (YAML + SQL), percentile-normalized indicator scoring.
12. Composite score `100·(0.35E + 0.30D + 0.20V + 0.15R)` with unique-citizen log-damped demand, source-confidence table, 90-day recency half-life, weight renormalization + badge when `evidence_available=false`; `safety_critical` bypass strip.
13. **Burst/anomaly detection in score-runner; `anomaly_flags` + dashboard chip + `suspected_coordination` caveat** *(new — §3.3)*.
14. Gemini justification generation (numbers-in, prose-out, no-new-facts rules) with fixed caveat vocabulary.

**Dashboard & lifecycle**
15. MP/staff dashboard (Flutter Web, role-gated): ranked list with score-component bars, why-panel with evidence bullets + sources + caveats, hotspot map (flutter_map choropleth + cluster pins), per-channel composition display, review queue, repair actions, safety-critical strip, SIMULATED badges.
16. Cluster lifecycle (acknowledged → under-review → recommended → taken-up → completed) with citizen-facing status via app/WhatsApp/FCM.

**Cross-cutting**
17. Unified Submission schema (v1.0 §2) as the single contract; zod-validated at every boundary; `channel_meta` opaque to the common pipeline.
18. Demo assets: fixture batches (3 languages, planted overlaps, spam), seeding + replay scripts, cross-language clustering golden test, flagship-scenario data curation.

### 4.2 Phased plan (no dates)

**Phase 1 — the spine** *(unchanged from v1.0 + item 1's offline flag, identity-linking UI stub)*
Fork campus-connect → monorepo; schema + Firestore rules; app intake (voice/photo/GPS/language picker, offline enabled); triage v1 synchronous; interim demand+recency ranked list; Cloud Run deploy. *Exit: Telugu voice note in app → enriched record on dashboard.*

**Phase 2 — the intelligence** *(v1.0 scope + cluster-repair worker logic + identity-linking backend)*
Pub/Sub decoupling; WhatsApp E2E; BigQuery boundaries/LGD/UDISE+ ETL; embeddings + clustering + threshold labeling; evidence SQL + composite scoring; score-runner + Scheduler; dashboard v2 (score bars, map, review queue, **repair actions**); **identity link + hash migration**. *Exit: v1.0 §4.3 cross-language test passes; flagship comparison ranks correctly on real UDISE+ numbers; a staff split/merge visibly corrects counts and rank.*

**Phase 3 — breadth, honesty, polish** *(v1.0 scope + anomaly detection)*
Meeting console + chunked extraction; YouTube poller; mock connectors + replay; justification + why-panel; WhatsApp confirm loop + status; TTS readback; **anomaly query + chip + caveat**; SIMULATED badging sweep; demo seeding, rehearsal, deck. *Exit: full v1.0 §1.4 walk-through live twice; anomaly chip fires on a seeded flood fixture.*

**Role deltas:** P1 (+repair UI, +link screen), P2 (+link/migration routes), P3 (+repair recompute, +anomaly SQL), P4 unchanged. No restructuring.

---

## 5. Cursor build prompt

Everything between the START/END markers is self-contained — paste it into Cursor as-is. It restates all contracts, prompts, formulas, and phase gates it needs; it does not reference this document.

<!-- ==================== CURSOR PROMPT START ==================== -->

# BUILD: People's Priorities — evidence-grounded citizen-demand ranking for an MP's constituency

## Your role and the goal

You are building a production-quality hackathon system (Google Cloud "Build with AI", civic-tech) as a senior full-stack engineer. Citizens submit development requests via a Flutter app (voice/text/photo), WhatsApp, uploaded public-meeting audio, and YouTube comments — in Telugu, Hindi, or English. The system normalizes every submission into one structured record, clusters records that ask for the same underlying thing across languages/channels, grounds each clustered demand against public data (UDISE+ school records), computes an explainable composite priority score, and shows MP staff a ranked dashboard where every rank has a "why" panel with real figures and sources.

Work in three phases, strictly in order. Do not start a phase until the previous phase's acceptance criteria all pass. Ask before deviating from any contract in this prompt.

## Starting point

You are working in a fork of `campus-connect`: Flutter app + Node.js/Express + Firebase (Auth, Firestore) + Gemini, previously a campus grievance system. Reuse aggressively: the submission form flow, Firebase Auth wiring, role-based access, the Gemini call pattern, the Nominatim geocoding module, and the status-lifecycle UI pattern all carry over with modifications described below. Do not rebuild what can be adapted.

## Tech stack (pinned — do not substitute)

- **App + dashboard:** one Flutter codebase, role-gated (`citizen` | `mp_staff` | `mp`). Dashboard = Flutter Web. Maps: `flutter_map` + OSM tiles (NOT google_maps_flutter). TTS: `flutter_tts`. Enable Firestore offline persistence; queue media uploads when offline.
- **Backend:** Node 20 + TypeScript (strict) + Express, deployed as four Cloud Run services: `intake-api`, `enrich-worker`, `connectors`, `score-runner`.
- **Data:** Firestore (operational: submissions, clusters, users). BigQuery (analytics: enriched submissions + embeddings, cluster centroids, evidence tables, GIS). Cloud Storage (media). Pub/Sub topic `submission.created`. Cloud Scheduler (3 jobs max: score-runner 30 min, youtube poller, fixture replayer).
- **AI:** Gemini API (AI Studio key). Triage/extraction/justification model: `gemini-3.5-flash` (config `TRIAGE_MODEL`; fallback value `gemini-3.1-flash-lite` — verify free-tier RPD in AI Studio and switch config if needed). Embeddings: `gemini-embedding-001`, `output_dimensionality: 768`, `task_type: SEMANTIC_SIMILARITY`. ALL Gemini calls use structured output (`responseMimeType: application/json` + `responseSchema`). Never parse prose.
- **Never use:** Vertex AI Vector Search, Cloud SQL/PostGIS, paid Routes API, any scraping of government portals, X/Twitter API, localStorage in web code beyond Firebase SDK internals.

## Repo layout (create exactly this)

```
/app                      # Flutter: citizen app + staff dashboard (role-gated views)
/services/intake-api      # Express: REST for app, WhatsApp webhook, connector ingest, identity linking
/services/enrich-worker   # Pub/Sub push handler: triage → embed → geocode → cluster-assign
/services/connectors      # YouTube poller (live), pgrs_portal + meta_social (fixtures), replay
/services/score-runner    # Scheduled: scoring SQL, anomaly query, justification generation
/shared/schema            # zod schemas + generated TS types — THE source of truth for all services
/evidence_specs           # per-subcategory YAML: indicators, weights, SQL file ref, dataset citation
/sql                      # BigQuery DDL, clustering query, evidence queries, scoring query, anomaly query
/fixtures                 # pgrs_batch_*.json, meta_batch_*.json, meeting audio samples
/scripts                  # seed.ts, replay.ts, load_udise.ts, load_boundaries.ts, eval_clustering.ts
/test                     # unit + golden tests
```

## Non-negotiable invariants (enforce in code review of your own work)

1. Raw phone numbers exist ONLY in webhook payloads and WhatsApp reply routing. Everywhere else: `citizen_hash = HMAC-SHA256(phone_or_uid, PEPPER)` (PEPPER from env/Secret Manager). BigQuery never sees a raw phone.
2. Embedding vectors live ONLY in BigQuery, never in Firestore documents.
3. LLMs never compute, rank, or aggregate numbers. Scores come from SQL/TypeScript; the justification model converts provided numbers to prose and is forbidden (by prompt AND by output validation) from introducing numbers absent from its input payload.
4. `is_simulated: true` on every fixture-origin record, propagated to cluster stats and rendered as a grey "SIMULATED" chip wherever that data appears.
5. `channel_meta` is opaque to the shared pipeline — no code outside a connector reads it.
6. Every service boundary validates with the zod schemas in `/shared/schema`. No `any`.
7. Staff repair decisions are pinned: a submission moved by staff is excluded from future auto-reassignment; all repair actions append to the cluster's `lifecycle.history`.

## Data contracts

### Unified Submission (Firestore `submissions/{id}`; mirrored to BQ `pp.core.submissions_enriched` + `embedding ARRAY<FLOAT64>`)

```jsonc
{
  "submission_id": "sub_<ULID>", "schema_version": 1,
  "source": "app|whatsapp|meeting|youtube|portal_mock|meta_mock",
  "is_simulated": false,
  "created_at": "<server ts>", "occurred_at": "<ts citizen spoke/posted>",
  "citizen": { "citizen_hash": "hmac256:<hex>|null", "auth_kind": "firebase_uid|whatsapp_phone|youtube_channel|anonymous", "display_locale": "te|hi|en" },
  "content": {
    "modality": "text|voice|photo_text|video_comment",
    "original_text": "string|null", "original_language": "<BCP-47>",
    "media": [{ "kind": "audio|image", "gcs_uri": "gs://...", "mime": "...", "duration_s": 0 }],
    "transcript_original": "string|null",     // original script, filled by enrichment
    "text_en": "string"                        // faithful translation
  },
  "ai": {                                      // null until enriched
    "canonical_summary_en": "string ≤220 chars",   // THE clustering key — one neutral sentence: what is asked, where
    "category": "roads|water|education|health|electricity|sanitation|transport|agriculture|welfare|other",
    "subcategory": "string", "kind": "development_request|grievance|question|other",
    "urgency": "safety_critical|high|medium|low",
    "entities": ["string"], "triage_confidence": 0.0,
    "model_versions": { "triage": "<model id>", "embedding": "gemini-embedding-001@768" }
  },
  "location": {
    "raw_mentions": ["string"], "point": { "lat": 0, "lng": 0 },
    "method": "device_gps|exif|nominatim_biased|google_geocode_fallback|staff_pin|none",
    "geocode_confidence": "high|medium|low|none",
    "admin": { "constituency_code": "s", "mandal_code": "s", "lgd_village_code": "s|null", "ulb_ward_code": "s|null" }
  },
  "cluster_id": "clu_...|null",
  "cluster_assignment": { "similarity": 0.0, "decided_by": "auto|staff_review|staff_repair", "pinned": false, "at": "<ts>" },
  "consent": { "basis": "direct_submission|public_meeting_notice|public_platform", "pii_scrubbed": true },
  "channel_meta": { /* free-form per source; opaque */ }
}
```

`channel_meta` reference shapes — whatsapp: `{wa_message_id, wa_phone_hash, profile_name, in_service_window}`; meeting: `{meeting_id, recording_gcs, chunk_index, segment_start_s, segment_end_s, speaker_label, diarization_confidence, verbatim_quote_original}`; youtube: `{video_id, comment_id, thread_id, like_count, author_channel_hash, published_at}`; portal_mock: `{fixture_file, mock_registration_no, portal_department}`.

### Cluster (Firestore `clusters/{id}`; centroid in BQ `pp.core.cluster_centroids(cluster_id, category, mandal_code, centroid_embedding, n)`)

```jsonc
{
  "cluster_id": "clu_<cat>_<seq>", "canonical_title_en": "s",
  "category": "s", "subcategory": "s",
  "admin_scope": { "constituency_code": "s", "mandal_code": "s" },
  "centroid_point": { "lat": 0, "lng": 0 },
  "stats": { "submission_count": 0, "unique_citizens": 0, "unique_provisional": 0,
             "sources": {"app":0,"whatsapp":0,"meeting":0,"youtube":0,"portal_mock":0,"meta_mock":0},
             "simulated_count": 0, "first_seen": "<ts>", "last_activity": "<ts>", "languages": ["te"] },
  "score": { "total": 0, "demand": 0, "evidence": 0, "confidence": 0, "recency": 0,
             "evidence_available": true, "computed_at": "<ts>" },
  "anomaly_flags": [],                         // e.g. ["burst_7x_baseline","near_duplicate_texts_41pct"]
  "justification": { "text_en": "s", "evidence_bullets": ["s"], "caveats": ["s"], "model": "s", "generated_at": "<ts>" },
  "lifecycle": { "status": "acknowledged|under_review|recommended|taken_up|completed",
                 "history": [{ "action": "s", "by": "s", "at": "<ts>" }] },
  "review_queue": ["submission_id"]
}
```

### BigQuery evidence tables

`pp.evidence.udise_schools(udise_code, school_name, mgmt_type, school_category INT64, highest_class INT64, lat, lng, geopoint GEOGRAPHY, lgd_village_code, block_code, enr_g1..enr_g12 INT64, classrooms_good INT64, has_electricity BOOL, has_drinking_water BOOL, toilets_girls INT64, teachers_total INT64, ref_year STRING)` · `pp.geo.mandal_boundaries(mandal_code, constituency_code, name, geom GEOGRAPHY)` · `pp.geo.village_boundaries(lgd_code, mandal_code, geom)` · `pp.geo.mandal_adjacency(mandal_code, adjacent_mandal_code)` (precompute once via `ST_TOUCHES`).

## AI prompts (use verbatim; wire with responseSchema)

### Prompt A — triage (every submission; input: text and/or audio and/or ≤3 photos)

```text
You are the intake triage system for "People's Priorities", a platform where citizens of an
Indian parliamentary constituency submit local development requests in any language, by text,
voice, or photo. You will receive one citizen submission. Do ALL of the following and return
ONLY the JSON object described by the response schema:

1. LANGUAGE: Identify the primary language (BCP-47, e.g. "te", "hi", "en", "ur"). Code-switched
   speech (Telugu-English) → the dominant language.
2. TRANSCRIPT: If audio is present, transcribe it faithfully in the original script into
   `transcript_original`. Do not translate inside the transcript.
3. TRANSLATION: Produce `text_en`, a faithful English translation. Preserve place names as
   proper nouns (transliterate, do not translate them).
4. CANONICAL SUMMARY: Write `canonical_summary_en` — one neutral English sentence stating the
   underlying REQUEST (not the complaint narrative): what is being asked for, and where.
   Normalize aggressively: "our school has no 10th class" and "we need a high school" both
   become a request for secondary school access. This field is used to detect that two
   submissions ask for the same thing, so identical demands must produce near-identical
   summaries. Do NOT include the citizen's name, emotion, or channel.
5. CLASSIFY into exactly one category/subcategory:
   roads(new_road, repair, bridge_culvert, streetlights), water(drinking_water, irrigation,
   drainage), education(school_upgrade, new_school, school_infrastructure, vocational_training),
   health(phc_upgrade, new_facility, staffing_equipment), electricity(new_connection,
   reliability), sanitation(toilets, waste_management), transport(bus_service, rail),
   agriculture(market_access, storage, subsidy_access), welfare(pension_schemes, housing,
   ration), other(other).
   Use photos as classification evidence; describe each briefly in `photo_observations`.
6. KIND: development_request | grievance | question | other (spam, politics-only, abuse).
7. URGENCY: safety_critical (immediate danger to life) | high | medium | low.
8. LOCATIONS: Extract every location mention verbatim into `location_mentions` (village,
   colony, landmark, road names), original script AND transliterated Latin.
9. PII: In text_en and canonical_summary_en, replace private individuals' names with "[name]"
   and phone numbers with "[phone]". Keep public place names and officials' role titles.
10. CONFIDENCE: `triage_confidence` 0.0–1.0 for category + summary combined. Below 0.5 the
    item goes to human review; be honest.

Never invent locations or facts not present in the submission. If the submission is empty,
unintelligible, or pure abuse, set kind="other" and explain in `triage_notes`.
```

Response schema: object with required `[original_language, text_en, canonical_summary_en (maxLength 220), category (enum above), subcategory, kind (enum), urgency (enum), location_mentions (array of {original, latin}), triage_confidence (number)]`, optional `[transcript_original, photo_observations (string[]), entities (string[]), triage_notes]`.

### Prompt B — meeting extraction (per ≤15-min audio chunk, 30 s overlap; context vars: constituency, venue+mandal, chunk offset)

```text
You are processing a recording of a public constituency meeting (janasabha / praja darbar) in
an Indian parliamentary constituency. Audio may contain Telugu, Hindi, and English, often
code-switched, with background noise and overlapping speakers.

TASK: Extract every DISCRETE, ACTIONABLE citizen request or complaint as a separate item.
Rules:
- One item = one underlying ask. A speaker raising road repair AND water supply = two items.
- Ignore: officials' speeches, procedural talk, applause, pure political commentary, and
  repeats of an item already emitted in THIS chunk (increment its `also_raised_count` instead).
- Label speakers SPK_01, SPK_02... consistently within this chunk only. Labels are positional,
  NOT identities. Never name a speaker; put "[name]" where a name was spoken.
- Per item: verbatim quote (original language and script), start/end offset seconds within
  this chunk, plus the same canonical_summary_en / category / subcategory / urgency /
  location_mentions fields and taxonomy as the standard triage prompt.
- `audio_quality`: clean | noisy | partially_unintelligible. Do NOT guess unintelligible
  segments' content; skip them and list them in `skipped_segments` with reasons.
- `speaker_separation_confidence`: high | medium | low. In noisy Indian public meetings this
  is often low — say so; downstream weighting depends on your honesty.
Return ONLY JSON per the response schema.
```

Response schema: `{audio_quality, speaker_separation_confidence, skipped_segments[{start_s,end_s,reason}], items[{speaker_label, start_s, end_s, verbatim_quote_original, original_language, text_en, canonical_summary_en, category, subcategory, urgency, location_mentions[], also_raised_count, extraction_confidence}]}`. Each item becomes a standalone Unified Submission (`source: meeting`, V-weight handled by scoring, cross-chunk dedup handled by clustering — NOT by this prompt).

### Prompt C — ranking justification (per cluster whose score components changed)

```text
You write the "Why is this ranked here?" explanation shown to an MP and their staff on a
development-priorities dashboard.

You will receive one JSON payload: cluster title, category, admin unit names, the four score
components (demand, evidence, confidence, recency, each 0–1) and total, demand statistics
(unique citizens, sources, languages, first/last activity, simulated_count), anomaly_flags,
and evidence_rows — the exact public-dataset figures used, each with dataset name and
reference year.

Write:
1. `text_en`: 2–4 sentences, plain language. Sentence 1: what is asked and by how many
   citizens through which channels. Sentences 2–3: the strongest evidence figures, citing
   dataset name and year inline. Final sentence: any material caveat.
2. `evidence_bullets`: ≤4 bullets, each ONE figure with its source, verbatim from evidence_rows.
3. `caveats`: from the fixed set [low_geocode_confidence, no_dataset_coverage, single_channel,
   mostly_simulated_sources, low_speaker_confidence, small_sample, suspected_coordination].

HARD RULES:
- Use ONLY numbers present in the payload. Never estimate, extrapolate, round beyond one
  decimal, or add outside context.
- If evidence_available=false: say plainly that no public-dataset evidence is loaded for this
  category yet and the rank reflects demand, source quality and recency only.
- If anomaly_flags is non-empty, include suspected_coordination and mention it neutrally.
- Neutral tone. No advocacy — the score speaks; you explain it.
Return ONLY JSON: {"text_en": str, "evidence_bullets": [str], "caveats": [str]}.
```

Post-validate: reject and retry once if the output contains any digit-sequence not present in the input payload.

## Algorithms (implement exactly)

### Clustering (in enrich-worker, async, per enriched submission)

1. Embed `canonical_summary_en` → 768-dim vector, L2-normalized.
2. Candidate clusters: same `category` AND `mandal_code` equal OR adjacent (use `pp.geo.mandal_adjacency`) when `geocode_confidence` ≤ medium; equal-only when high.
3. BigQuery `VECTOR_SEARCH` (brute force, COSINE, top_k=5) against `cluster_centroids` filtered per step 2.
4. Bands: `sim ≥ 0.80` → auto-merge. `0.65 ≤ sim < 0.80` → attach provisionally to best cluster AND push to `review_queue` (provisional members count 0.5 in demand). `sim < 0.65` → create new cluster seeded by this submission.
5. Centroid update: `centroid ← normalize((n·centroid + e)/(n+1))`; freeze when n > 50.
6. If `citizen_hash` already in cluster: `submission_count++` only, NOT `unique_citizens`.
7. Staff repair (Phase 2): endpoints for split (move a set of submissions to a new cluster), merge (two clusters → one), reassign (one submission → another cluster). Recompute affected centroids from members (full recompute, not incremental). Set `decided_by: staff_repair, pinned: true` on moved submissions; append to `lifecycle.history`; trigger immediate rescore of affected clusters.

### Scoring (score-runner, every 30 min, SQL + TS)

```
PriorityScore = 100 · (0.35·E + 0.30·D + 0.20·V + 0.15·R)      // weights in config
D = ln(1 + U_eff) / ln(1 + P95_of_cluster_U)   clamped to [0,1];  U_eff = unique_confirmed + 0.5·unique_provisional
V = mean over submissions of (w_src · g)
    w_src: app+GPS+photo 1.00 · app text 0.85 · whatsapp+media 0.80 · whatsapp text/voice 0.65
           · meeting 0.50 · portal_mock 0.50 · youtube 0.30
    g (geocode): high 1.0 · medium 0.85 · low 0.6 · none 0.4
R = 2^(−days_since_last_activity / 90)
E = per-subcategory evidence spec (below); if none exists for the subcategory:
    evidence_available=false and total = 100·(0.30·D + 0.20·V + 0.15·R)/0.65
safety_critical urgency → cluster additionally listed in a separate always-on-top strip (not score-ranked).
```

Evidence spec for the flagship `education.school_upgrade` (file `evidence_specs/education.school_upgrade.yaml` + `sql/evidence_education_school_upgrade.sql`): compute per mandal — `seat_gap = GREATEST(SUM(enr_g6..g8 of govt/aided schools with highest_class ≤ 8)/3 − SUM(enr_g9+enr_g10 of govt/aided schools with highest_class ≥ 10)/2, 0)`; `road_km_est = MIN(ST_DISTANCE(cluster centroid, secondary school geopoint))/1000 × 1.4`; `pipeline_per_school = pipeline / NULLIF(secondary_school_count,0)`. Convert each indicator to `PERCENT_RANK()` across all mandals in the constituency, then `E = 0.5·pct(seat_gap) + 0.3·pct(road_km_est) + 0.2·pct(pipeline_per_school)`. Store the raw figures + dataset + ref_year as `evidence_rows` for Prompt C.

### Anomaly query (same score-runner run)

Flag `burst`: cluster's submissions in last 24 h > max(5, 7× its trailing 14-day daily mean). Flag `near_duplicate_texts`: >30% of cluster's pairwise `text_en` embedding similarities > 0.95 (compute on ≤ latest 50 members). Write `anomaly_flags`; dashboard renders an amber chip with tooltip; feeds Prompt C.

### Identity linking (intake-api + app)

App screen "Link WhatsApp": generate 6-char one-time code (Firestore `link_codes`, TTL 10 min) → open `wa.me/<bot number>?text=LINK <code>` → inbound webhook redeems code → set user's canonical `citizen_hash = HMAC(phone)` → migration function rewrites `citizen_hash` on the citizen's prior submissions and decrements/increments affected clusters' `unique_citizens` → rescore affected clusters. Inbound WhatsApp is free; never send SMS.

## Geocoding tiers (enrich-worker)

1. `device_gps`/EXIF → confidence high. 2. Nominatim with `viewbox=<constituency bbox>&bounded=1` on triage `location_mentions` (respect 1 req/s; cache results) → single hit = medium, ambiguous = low. 3. Google Geocoding API fallback (env-gated; stay within free 10K/mo). 4. Unresolvable → `none`, route to staff map-pin UI (sets `staff_pin`, high). Then assign admin codes via `ST_CONTAINS` against `mandal_boundaries` (+ `village_boundaries` when available). Mandal is the guaranteed floor — never fail a submission for lacking village/ward.

## Phases — scope, files, acceptance criteria

### Phase 1 — spine (one submission flows end-to-end)

Build: `/shared/schema` (zod, all contracts above); Firestore rules (citizens write own submissions, staff read all, only workers write `ai`/`cluster_id`); Flutter citizen intake — 3-language picker (voice-prompted once), mic-primary record (60 s), photo, GPS auto-attach, offline persistence + upload queue; `intake-api` POST /submissions; `enrich-worker` called synchronously for now (Prompt A wired with responseSchema, Nominatim tier only); interim ranked list on dashboard (demand+recency, no BQ); deploy both services to Cloud Run; seed script with 20 mixed-language text fixtures.
**Done when:** (1) a Telugu voice note recorded in the app appears on the dashboard within 60 s with original-script transcript, English translation, correct category, and canonical summary; (2) all zod schemas round-trip the 20 fixtures; (3) `npm test` green incl. schema and triage-parsing tests (mock Gemini); (4) offline: airplane-mode submission uploads on reconnect.

### Phase 2 — intelligence (clustering, evidence, scoring, repair)

Build: Pub/Sub decoupling (`submission.created` → enrich-worker push endpoint); BigQuery DDL + `load_boundaries.ts` + `load_udise.ts` (CSV → `udise_schools`) + `mandal_adjacency`; embedding + clustering per algorithm above (incl. `eval_clustering.ts` harness: takes labeled pairs CSV, reports precision/recall at thresholds); evidence SQL + scoring SQL + `score-runner` on Scheduler; WhatsApp Cloud API webhook E2E (dev mode: intake, media fetch → GCS, auto-ack in citizen's language, LINK code redemption, "status" reply); identity-link app screen + migration; dashboard v2 — ranked clusters with 4-component score bars, flutter_map hotspot view (mandal choropleth + cluster pins), review queue (approve/detach provisional members), repair actions (split/merge/reassign) wired to worker endpoints with centroid recompute + history + pinning.
**Done when:** (1) golden test `test/cross_language_clustering.test.ts` passes — seed the four canonical fixtures (Telugu WhatsApp voice-note transcript, Hindi app text, English meeting extract about the same school; English YouTube comment about an ITI) and assert the first three land in ONE cluster and the ITI comment creates a separate `education.vocational_training` cluster; (2) flagship scenario ranks school-upgrade above vocational-centre using real loaded UDISE+ numbers, with score components inspectable; (3) sending a WhatsApp voice note from a test phone moves a cluster's score within one score-runner cycle; (4) a staff split action visibly corrects `unique_citizens` and rank, appears in history, and split members never auto-remerge; (5) identity-link flow migrates a dual-channel test citizen from 2 unique_citizens to 1 across their clusters.

### Phase 3 — breadth, honesty, polish

Build: meeting upload console (staff) → GCS → chunked Prompt B extraction → submissions; YouTube poller (`commentThreads.list`, videos configurable); `SourceConnector` interface + `pgrs_portal` and `meta_social` fixture connectors + `replay.ts` (Scheduler-driven drip through the LIVE pipeline); Prompt C justification in score-runner with digit-validation retry; why-panel (text, evidence bullets with dataset+year, caveat chips, per-channel composition bar, playable voice notes); anomaly query + amber chip; WhatsApp "what we understood" confirm buttons + TTS readback in-app; SIMULATED badge sweep (list rows, why-panel counts, map pins); safety-critical strip; demo seeding for the flagship mandal.
**Done when:** (1) an uploaded 30-min meeting sample yields ≥1 extracted item that clusters with existing app/WhatsApp demands; (2) fixture replay visibly adds a SIMULATED-badged portal record to a live cluster and moves its score; (3) justification for the flagship cluster contains only payload numbers (validator test) and correct dataset citations; (4) seeded flood fixture trips the anomaly chip and `suspected_coordination` caveat; (5) the full demo path — live WhatsApp voice note → rank change → why-panel — runs twice consecutively without manual intervention.

## Out of scope — do not build

X/Twitter connector, live scraping of any government portal, live Meta integration, public citizen-facing ranking portal, RAG/chat interface over submissions, Earth Engine anything, paid Routes API distances, dashboard weight-slider UI, speaker identification of any kind, per-user analytics beyond citizen_hash counting.

## Working rules

TypeScript strict everywhere; zod-validate every boundary; unit tests for scoring math and clustering bands (deterministic — mock embeddings with fixed vectors); Firebase Emulator Suite + BigQuery emulator-or-test-dataset for integration tests; conventional commits; one PR per phase with a checklist mapping to that phase's acceptance criteria; secrets only via env/Secret Manager (`GEMINI_API_KEY`, `WA_TOKEN`, `WA_VERIFY_TOKEN`, `PEPPER`, `GCP_PROJECT`, `CONSTITUENCY_BBOX`, `CONSTITUENCY_CODE`); when a contract in this prompt conflicts with something you infer from the codebase, the contract wins — flag the conflict instead of silently resolving it.

<!-- ==================== CURSOR PROMPT END ==================== -->


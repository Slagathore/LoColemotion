# LLM Director Model Bake-off

> **Note (2026-07-11):** Ollama retired `gemini-3-flash-preview` and `qwen3-coder:480b` from its
> cloud on 2026-07-15; results below that involve them are historical and no longer reproducible.
> The `qwen3-coder-next` used here is a different model and is unaffected.

Which cloud model should drive gait training? We answered it empirically, not by reputation.
**Conclusion: `qwen3-coder-next:cloud` is the default training director** (`LlmDirector.DEFAULT_MODEL`).
It led credibility in two independent, fair head-to-head bake-offs.

## How the bake-off works (fair by construction)

`scripts/sim/run_train_batch.gd` runs N trainings, cycling `model = models[i % M]` and
`build = builds[(i / M) % BUILD_COUNT]`. Because the build index is `i / M`, **every model trains the
exact same sequence of builds** — a true head-to-head, not a lucky-draw of easy vs hard bodies. Each
training is an LLM-directed `Trainer.train` session (the director proposes gait + drive scales each round;
the trainer keeps the best); success = the `SimRollout` credibility gate (a real measured walk ≥ 3m,
upright, articulating, not skating/spinning/assist-carried). Rollouts are hermetic (per-rollout World3D),
so a model's score is a pure function of its proposals, not of what ran before it.

`mean_forward` = mean best measured forward distance (m). `credible` = fraction of that model's builds that
reached a credible walk. Credibility is the headline metric — a long *non-credible* run is a fall or a
skate, not locomotion.

## Bake-off 1 — 4 models × 25 builds each (2026-06-28)

| Model | Credible | Mean forward |
|---|---|---|
| **qwen3-coder-next** | **88%** (22/25) | 8.63 |
| glm-5.2 | 84% (21/25) | 9.12 |
| deepseek-v4-pro | 80% (20/25) | 8.51 |
| gemini-3-flash-preview | 72% (18/25) | 8.54 |

## Bake-off 2 — 6 models × 12 builds each (2026-06-28)

| Model | Credible | Mean forward |
|---|---|---|
| **qwen3-coder-next** | **92%** (11/12) | 9.01 |
| kimi-k2.7-code | 75% (9/12) | 9.85 |
| glm-5.2 | 83% (10/12) | 7.20 |
| qwen3.5-397b | 83% (10/12) | 8.20 |
| minimax-m3 | 83% (10/12) | 7.70 |
| nemotron-3-ultra | 75% (9/12) | 7.67 |

## Findings

- **`qwen3-coder-next` wins on the metric that matters (credibility): 88% then 92% — first in both runs.**
  It is the most reliable at proposing gaits that produce *real* walks, across diverse morphologies.
- **`glm-5.2` is the steady runner-up** (84%, 83%) — a fine fallback / second opinion.
- **`kimi-k2.7-code` posts the longest distances (9.85m) but a worse credibility rate (75%)** — it pushes
  for distance and falls/cheats more often. Higher variance, not a better director.
- **None of the four newer models (kimi, qwen3.5-397b, minimax-m3, nemotron-3-ultra) beat qwen3-coder.**
  `nemotron-3-ultra` was also the slowest by a wide margin and bottom-tier on credibility.
- **Parser fix mattered for fairness.** `OllamaClient.extract_content` strips ```` ```json ```` code fences
  and surrounding prose before parsing. Coder/chatty models (qwen3-coder, kimi, minimax) wrap their JSON in
  fences; without this they would silently fall back to hill-climb and look artificially bad. The fix is why
  fenced models could compete on equal footing — and qwen3-coder still won.

## Caveats (honest power)

- Per-model N is small (25, then 12). These are **directional** results, not a publication-grade benchmark.
  The signal we trust is **consistency**: qwen3-coder led both independent runs.
- Easy builds (e.g. the quadruped) converge to identical results for every model, so the ranking is really
  driven by the *hard* builds (frog, knee-biped, serpent, mantis, …) — which is the point.

## Reproduce

```
# default (qwen3-coder-next):
godot --headless --path . --script res://scripts/sim/run_train_batch.gd
# new head-to-head:
SPORE_LLM_MODELS=qwen3-coder-next:cloud,glm-5.2:cloud SPORE_TRAIN_COUNT=72 SPORE_TRAIN_ROUNDS=5 \
  godot --headless --path . --script res://scripts/sim/run_train_batch.gd
```

Training runs (per-row genome snapshots since M30) accumulate in `user://training/runs.jsonl`.

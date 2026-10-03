# BR3A development observation drafts

These files are development-only drafts of the L1.1-L1.8 experimental
findings, written in `sporespore.lab.br3a_development_observation.v1` form.
They are not knowledge entries and they cannot become knowledge entries in
their current state.

What they are for:

- keeping each finding, its exact measured scope, and its non-claims in one
  structured place instead of only inside test scripts and the bootstrap doc;
- surfacing schema problems now, before the promotion-grade BR3A trust family
  exists; and
- making the eventual promotion pass cheaper: attach promotion-grade evidence
  and re-author as `knowledge_entry.v1`, do not relabel these files.

Hard limits, enforced by
`tests/test_experimental_br3a_knowledge_draft_guard.gd`:

- every draft pins `admissible_now: false`, the five open BR3A promotion
  blockers, and `promotion_grade_bundle_exists: false`;
- every `minimal_repair_rules` entry is `advisory_only` with automatic
  application forbidden;
- `LabKnowledgeBase.verify_entry` rejects these drafts, and
  `LabKnowledgeQuery.load_entries` over this directory fails closed, so no
  consumer can read them as accepted or development knowledge entries; and
- admission without a valid promotion-grade bundle is refused by the existing
  knowledge boundary, which these drafts do not and cannot bypass.

The evidence behind these drafts is experimental commissioning test reports
only. Nothing here is accepted, and nothing here proves standing, bracing,
fall arrest, getting up, or walking.

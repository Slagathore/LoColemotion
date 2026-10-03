# Milestone decisions

This directory is an append-only record of the human decisions that interpret
machine evidence at the BR milestone boundaries.

A certification report proves only its own declared claim. A milestone decision
may accept a narrower engineering capability after reviewing that evidence, but
it cannot rewrite or broaden the report itself. Every decision therefore stores:

- the exact report, receipt, inventory, and source-commit identities reviewed;
- the contracts and capabilities accepted;
- an explicit claim boundary;
- explicit exclusions and still-open downstream work; and
- the named project decider and decision channel.

Never edit an accepted record in place. A correction creates a new decision ID
and names the previous ID in `supersedes`. The allowlisted registry rejects
unknown files, changed bytes, schema drift, weakened exclusions, and evidence
identity drift.

The registry currently dispatches four strict evidence-family contracts:

- `sporespore.lab.milestone_decision.v1` remains the byte-pinned BR1-shaped
  contract used by the bounded BR2.1 articulated-observer decision.
- `sporespore.lab.br3a_milestone_decision.v1` binds the BR3A certification
  report family, exact L1.0-L1.7 scope, supplementary L1.8/knowledge-guard
  constraints, and structurally zero knowledge-admission and creature-guidance
  side effects.
- `sporespore.lab.br4_milestone_decision.v1` binds the BR4 certification
  report family and exact L2.0-L2.7 joint-actuator scope while excluding any
  contact-bearing, standing, bracing, recovery, gait, or walking claim.
- `sporespore.lab.br3b_milestone_decision.v1` binds the BR3B certification
  report family, exact L3.0-L3.2 free unary loaded-pad scope, and the explicit
  force-controlled carriage boundary while excluding general contact-wrench,
  per-foot allocation, articulated-support, knowledge-admission, and guidance
  claims.

A milestone acceptance can make separately reviewed evidence eligible for a
later knowledge-admission operation. It does not itself create an encyclopedia
entry or authorize a consumer.

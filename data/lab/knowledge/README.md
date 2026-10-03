# Locomotion knowledge base

This directory is an append-only evidence index, not a hand-written list of
locomotion folklore.

- `drafts/` contains authoring inputs. Copy
  `knowledge_draft.template.json`, replace every placeholder, and keep each
  claim narrower than the experiment that supports it.
- `drafts/L0_0_stationary_gravity_off.development.json` is the first
  preregistered claim. It is an authoring input only; its presence is not an
  admitted result.
- `entries/` contains admitted `sporespore.lab.knowledge_entry.v1` records.
  Never edit an admitted entry in place. A correction creates a new entry and
  names the old ID in `supersedes`.

A structurally complete dirty-source bundle may create only a
`development_observation`. An `accepted` entry requires
`RunBundleValidator.can_promote == true`; the admission command refuses to
silently downgrade or upgrade that result. `refuted` and `retired` are also
promotion-grade terminal statuses because they can suppress older accepted
guidance. A dirty or development run may report a possible contradiction, but
it cannot retire advice used by automatic repair.

From PowerShell in the repository root:

```powershell
$godot = "<godot-dir>\Godot_v4.7-stable_mono_win64_console.exe"
& $godot --headless --path . `
  --script "res://scripts/lab/admit_knowledge.gd" -- `
  --bundle "C:\tmp\sporespore_lab\runs\<run_id>" `
  --draft "res://data/lab/knowledge/drafts/my_finding.json" `
  --output "res://data/lab/knowledge/entries/my_finding.json" `
  --status "development_observation"
```

The admitted record pins the run ID, experiment ID, expanded-spec hash, and
the exact manifest, summary, and checksum artifact hashes. Its
`admission.payload_sha256` also binds the complete authored claim, boundaries,
tags, parameter effects, and repair rules to the admitted payload. Deleting or
moving the original bundle does not erase which bytes supported the entry,
although the bundle must remain available for full replay, trusted queries,
and automatic repair.

Admission revalidates this provenance immediately before writing. The writer
uses a per-entry reservation and refuses an existing destination; an update is
always a new entry whose `supersedes` list names the prior entry. Queries fail
closed if an entry is malformed, its bundle bytes no longer match, duplicate
IDs exist, or the supersession graph is missing a referenced entry, ambiguous,
or cyclic.

`repair_candidates(...)` independently verifies provenance even when a caller
passes dictionaries without using `load_entries(...)`. Development
observations remain inspectable with explicit opt-in, but they never receive
`automatic_application_allowed = true`.

## Certification-family observations

BR3A, BR3B, BR4, BR6A, BR7, and BR8 use dedicated append-only schemas because a complete
multi-program certification cannot be represented honestly as one ordinary
summary-bundle entry.

- BR3A contributes eight L1 milestone observations plus the supplementary
  L1.8 contact-discretization constraint.
- BR3B contributes three L3 basic loaded-foot milestone observations.
- BR4 contributes eight L2 milestone observations.
- BR6A contributes three rail-constrained L4 articulated-support observations.
- BR7 contributes four scaffold-constrained planar stance and support-loss
  observations.
- BR8 contributes four observation-only early loss-of-viability detector
  observations.

Each family-specific entry rechecks its fixed decision, exact certification
report and detached receipt, cited program scope, and production-attested
replicates. The generic verifier dispatches these schemas to their owning
contracts, and the generic writer routes them through the owning flat-catalog
append-only writer.

All family-specific entries currently have empty `minimal_repair_rules` arrays
and deny both automatic application and automatic creature guidance. Each
family retains its own downstream capability and guidance fence. In
particular, BR8 detector state `BRACE` is an observation, not an actuating
command or proof of a physical brace. Accepted observation does not mean
authorized action.

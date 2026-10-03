# Retained Trace Lineage Analysis

This directory contains the SDK's read-only mechanism-analysis layer. It turns
immutable content-addressed locomotion traces into deterministic projections
for convergence, contacts, controller authority, dynamic support, stability,
and actuator observability. It never imports a physics adapter, constructs a
model, opens a world, selects a controller, or changes a closed campaign.

The normative boundary is
[`retained_trace_lineage_contract_v1.json`](retained_trace_lineage_contract_v1.json).
An analysis manifest binds exact trace digests, byte lengths, row schemas,
phase order, command signs, comparison groups, and any replayed threshold.
The analyzer reads only `SporeSpore_Evidence/artifacts/sha256/<digest>/payload.bin`.
Live attempt paths are intentionally not an input mode.

The first concrete manifest,
[`r23d26_lineage_analysis_manifest_v1.json`](r23d26_lineage_analysis_manifest_v1.json),
replays all nine immutable R23D26 Rapier traces. Its `0.01 rad` conditioned
response threshold is inherited as a read-only diagnostic reference from the
already-closed campaign. The analyzer cannot weaken it, select an interpolated
cap, or authorize a new physical series.

From PowerShell at the repository root, a clean pushed source can retain the
production report with:

```powershell
pwsh -NoLogo -NoProfile -File sdk\run_retained_trace_lineage_analysis.ps1 `
  -OutputDirectory <evidence-root>\trace-lineage-r23d26-<source>
```

The runner refuses a dirty or unpushed source, creates `report.json` exactly
once, publishes it to the content-addressed artifact store, and creates a
receipt beside it. The report remains development diagnosis only.

## R23D27 predictive-tilt precursor diagnosis

[`r23d27_predictive_tilt_analysis_manifest_v1.json`](r23d27_predictive_tilt_analysis_manifest_v1.json)
binds the three closed R23D27 CAS traces and replays seven finite-difference
windows simultaneously. Each projects torso tilt one inherited `72`-step
swing interval ahead at `120 Hz`, using the unchanged R23D27 `0.10/0.20 rad`
guard thresholds. This is explicitly post-outcome descriptive analysis: it
does not select a window, fit a controller, or claim that the body would have
recovered.

The focused zero-world gate and retained production report find a precursor in
both commanded falls. Across
the `8`, `12`, `24`, and `36`-step windows, projected tilt reaches the existing
minimum-authority threshold `9` to `24` steps before the observed tilt-only
guard begins reducing authority. The zero-command reference never reaches the
projected minimum-authority threshold in any declared window. This supports
developing a direction-neutral state-frame tilt-rate successor whose horizon
is derived from the scheduler, but it grants no physical launch or turning
authority. Clean-pushed source `f0f9084` produced the CAS-retained report
`sha256:708add0dd57c8b36e0630660dbde5d68672ac8b34ca3fced08f0a796c766fcea`.
[`r23d27_predictive_tilt_diagnosis_closure_v1.json`](r23d27_predictive_tilt_diagnosis_closure_v1.json)
binds that report, its receipt, all three input traces, five source Git blobs,
the immutable R23D27 closure, exact findings, and claim limits. The diagnostic
prerequisite is closed; any physics still requires a fresh successor identity,
portable state-frame rate implementation, its own zero-world gate, and clean-
pushed scoped attestation/adoption.

## R23D28 steering-floor persistence diagnosis

[`r23d28_authority_persistence_analysis_manifest_v1.json`](r23d28_authority_persistence_analysis_manifest_v1.json)
binds the three closed R23D28 CAS traces and replays every whole-swing hold
duration from one `72`-step swing through the complete `360`-step scheduler
cycle. The replay masks recorded authority only; it neither recomputes a
controller command nor advances physics.

The zero-command reference has no recorded predictive-floor row. In the two
failed commanded arms, a one-swing hold still leaves `25` and `32` recorded
returns to expanded authority before actual controller-time tilt first exceeds
the inherited `0.10 rad` boundary. Two swings (`144` steps) is the smallest
simultaneously declared duration with zero such reopenings in both arms; every
longer declared duration has the same descriptive property. This is
post-outcome parameter-development information, not controller selection,
counterfactual recovery, physical launch authority, or turning validation.

Clean-pushed source `1ccd13f` produced the retained report
`sha256:6ed95b4d2095427d13eaea17d84f3749a79b37f6c2d178224d25d2f6ddda1d6d`.
[`r23d28_authority_persistence_diagnosis_closure_v1.json`](r23d28_authority_persistence_diagnosis_closure_v1.json)
binds its five source blobs, three CAS inputs, report, receipt, exact findings,
and zero-authority claim boundary. The diagnostic prerequisite is closed; a
stateful controller still requires its own fresh prospective freeze and
physical identity.

## R23D29 directional-response measurement diagnosis

[`r23d29_directional_response_analysis_manifest_v1.json`](r23d29_directional_response_analysis_manifest_v1.json)
binds the three closed R23D29 CAS traces. It preserves the immutable one-step
endpoint result, then simultaneously reports terminal means over every whole
`72`-step swing multiple through the complete `360`-step scheduler cycle. A
separate synchronized trajectory projection uses the complete pre-command
cycle as its baseline and verifies requested steering direction, held steering
direction, saturation, and persistent-guard activity from recorded receipts.

The focused zero-world gate establishes that both commanded arms received
directionally correct requested steering on all `1,200` turn rows and both
developed conditioned response peaks near `0.04 rad`. The negative arm first
crossed the unchanged `0.01 rad` threshold at step `1,070`, peaked at
`0.039542539075027736 rad` at step `1,555`, and regressed to the frozen
`0.00029444164763040275 rad` endpoint. The `288`- and `360`-step terminal means
exceed the replayed threshold in both arms, while the frozen endpoint remains
a valid bilateral failure. These facts reject a no-onset or missing-requested-
authority account and expose terminal phase sensitivity as a successor-design
hypothesis. They do not change R23D29, select a replacement estimator or
controller, authorize physics, or establish turning.

Clean-pushed source `3100b26` retained the deterministic production report as
`sha256:bb516e8b674842d306009cd350c8bcc8db3a152e417f60a02afbf2b33418b60a`.
[`r23d29_directional_response_diagnosis_closure_v1.json`](r23d29_directional_response_diagnosis_closure_v1.json)
binds the exact source Git blobs, immutable parent closure, three CAS traces,
report, receipt, six-window findings, and zero-authority claim boundary. No
successor terminal window, controller change, or physical series is selected.

## R23D43 cross-seed startup-transform diagnosis

[`r23d43_rapier_startup_transform_analysis_manifest_v1.json`](r23d43_rapier_startup_transform_analysis_manifest_v1.json)
binds all `18` CAS traces from the complete R23D30-R23D32 no-ramp Rapier
triplets and the complete R23D41-R23D43 startup-ramped Rapier triplets. The
dedicated analyzer independently validates all `53,856` rows, both trace
encodings, the complete smoothstep ramp receipt, absence of ramp fields in the
older traces, the frozen cycle windows, command delivery, and all closure
bindings. It retains the existing `0.01 rad` mechanism-detection floor exactly
and explicitly records that this is not a calibrated release, population, or
cross-engine margin.

The two groups use different already-exposed seeds, so any group contrast is
descriptive and cannot identify a causal ramp effect. This analysis may decide
whether a path-verifier-only successor is sufficient and whether a paired
same-seed development screen is the next testable question. It cannot change a
closed verdict, select a controller, consume a held-out validation seed,
satisfy QSDK-R23, authorize physics, or establish turning.

After the analysis source is clean and pushed, retain its production report
from PowerShell at the repository root with:

```powershell
pwsh -NoLogo -NoProfile -File sdk\trace_analysis\run_r23d43_rapier_startup_transform_analysis.ps1 `
  -OutputDirectory <evidence-root>\trace-lineage-r23d43-startup-transform-<source>
```

The focused zero-world regression and five mutation controls are in
[`test_r23d43_rapier_startup_transform.ps1`](test_r23d43_rapier_startup_transform.ps1).

Clean-pushed source `dca648a` reproduced the frozen pattern over all `18`
traces and retained report
`sha256:a9fed5d706c10437362cbc0b794792b476621b60c780a2f1216df1f0e4bd339e`.
The three no-ramp triplets passed the raw and conditioned cycle gates `3/3`;
the three ramped triplets passed the raw gate `3/3` and the conditioned gate
`0/3`, each missing only the positive conditioned floor. Their positive
conditioned ranges were `0.0100305-0.0128828 rad` and
`0.00540115-0.00597800 rad`, respectively. The diagnosis is closed by
[`r23d43_rapier_startup_transform_diagnosis_closure_v1.json`](r23d43_rapier_startup_transform_diagnosis_closure_v1.json).
The split remains seed-confounded and grants no physical or turning authority.
The independent retained-evidence closure audit is
[`test_r23d43_startup_transform_diagnosis_closure.ps1`](test_r23d43_startup_transform_diagnosis_closure.ps1).

## R23D52 Godot origin-timing diagnosis

[`r23d52_godot_origin_timing_analysis_manifest_v1.json`](r23d52_godot_origin_timing_analysis_manifest_v1.json)
binds the six same-seed R48/R52 Godot/Jolt CAS traces (`17,952` rows).
[`analyze_r23d52_godot_origin_timing.py`](analyze_r23d52_godot_origin_timing.py)
compares the frozen command schedule, step-zero physical observations,
controller projections, first physical divergence, reanchor receipts, and
complete-cycle response signs without importing an adapter or opening a world.

Clean-pushed source `0e0551741187e8b4d629e0369e9dbfc8ce22e096`
retained report
`sha256:2ef06418f3a15c206a456f2e8abf13407ff820d58100ccf29822e8e0b203dbdc`.
R52 changes its controller projection at step `0`, torso position at step `5`,
and measured yaw at step `14`, so the nominal warm-up was not isolated. Both
turn arms respond correctly during cycle one and reverse in cycles two and
three; the negative arm retains correctly signed requested and held steering
for all `1,200` command rows.

The diagnosis permits only a warm-up-preserving command-onset reanchor as a
distinct development question: fixed origin through step `599`, first latch at
step `600`, then fresh held-out validation if selected. It grants no physics or
turning authority. Recompute and retain it with
[`run_r23d52_godot_origin_timing_analysis.ps1`](run_r23d52_godot_origin_timing_analysis.ps1);
the closure and independent audit are
[`r23d52_godot_origin_timing_diagnosis_closure_v1.json`](r23d52_godot_origin_timing_diagnosis_closure_v1.json)
and
[`test_r23d52_godot_origin_timing_diagnosis_closure.ps1`](test_r23d52_godot_origin_timing_diagnosis_closure.ps1).

## R23D53 Godot command-contrast diagnosis

[`r23d53_godot_command_contrast_analysis_manifest_v1.json`](r23d53_godot_command_contrast_analysis_manifest_v1.json)
binds all three immutable R53 Godot/Jolt CAS traces (`8,976` rows) and the
closed negative parent without reopening or reinterpreting it. The focused
analyzer requires the three arms to be byte-semantically identical across all
`600` warmup observations, verifies the command schedule and origin transitions,
then measures desired-heading, requested-steering, held-steering, and physical
yaw contrasts against the synchronized zero-command reference.

Clean-pushed source `d44a603` retained the deterministic report as
`sha256:550a7750d529abcdd19c12a0d00d9fa069b808a20d4c69d3532ba6535199db67`.
Both desired-heading contrasts retain their declared direction for all `1,200`
turn rows and all three arms report zero saturated steering rows. The negative arm's held-
steering contrast has the commanded sign for `974/1,200` rows, while its yaw
effect relative to reference has the commanded sign for only `556/1,200` rows.
This rejects an origin-timing-only, missing-command, or reported-saturation
explanation; it does not identify an actuator or contact-phase cause.

The retained trace schema does not expose final per-actuator commands, applied
commands, declared effort limits, or command-to-contact-phase alignment. The
diagnosis therefore selects no physical successor. The next zero-world boundary
must first add those observables and mutation-test their evaluator route before
another world can be justified. Run the focused gate with
[`test_r23d53_godot_command_contrast.ps1`](test_r23d53_godot_command_contrast.ps1).
The retained production route is
[`run_r23d53_godot_command_contrast_analysis.ps1`](run_r23d53_godot_command_contrast_analysis.ps1).
The result is bound by
[`r23d53_godot_command_contrast_diagnosis_closure_v1.json`](r23d53_godot_command_contrast_diagnosis_closure_v1.json)
and independently reconstructed by
[`test_r23d53_godot_command_contrast_diagnosis_closure.ps1`](test_r23d53_godot_command_contrast_diagnosis_closure.ps1).

## Prospective Godot actuator/phase observation

[`godot_actuator_phase_observation_contract_v1.json`](godot_actuator_phase_observation_contract_v1.json)
defines the next zero-world instrumentation boundary required by the closed R53
diagnosis. The production Godot adapter now emits an ordered application receipt
for all eight actuators. Each row separates the portable joint identity from the
Godot host joint identity and retains the controller target, host-applied target,
configured target readback, compiled maximum impulse, configured impulse-limit
readback, saturation/slew flags, limb identity, controller phase, and the limb's
before/after contact observations.

This is configured-parameter observability, not measured torque or measured
impulse. Its only numeric tolerance is the existing commissioned adapter
comparison tolerance (`2.5e-7` in each field's native units); no R53 outcome was
used to derive a new threshold. The dedicated Godot 4.7 preflight
[`../../tests/test_sdk_godot_actuator_phase_observation.gd`](../../tests/test_sdk_godot_actuator_phase_observation.gd)
runs one real native-controller step through the production application route,
uses eight unparented `HingeJoint3D` objects, inserts zero nodes into a scene,
and opens zero models or worlds. It rejects wrong schema, application order,
target readback, impulse readback, retained actuator order, phase, contact, and
limb-identity mutations. The gate is part of
[`../run_conformance.ps1`](../run_conformance.ps1). It does not identify an R53
cause, select a successor, or authorize physical work.

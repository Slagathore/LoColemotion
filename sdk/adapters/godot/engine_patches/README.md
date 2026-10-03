# Pinned Godot/Jolt instrumentation profile

This directory contains the source patch for the optional
`godot_4_7_jolt_sporespore_motor_telemetry_v1` runtime profile. It does not
modify, replace, or promote stock Godot 4.7. Stock Godot remains the supported
`8/10` recovery-observation profile recorded by QSDK-R24D2; the instrumented
profile is a distinct candidate until native characterization and later
adoption pass.

The patch exposes Jolt's signed solved hinge-motor impulse and accumulates
positive and absorbed motor work at every warm-start and iterative motor
impulse application. It leaves the existing Godot hinge velocity motor, target,
limits, bodies, contacts, and solver ordering unchanged.

## Exact source and build

Use PowerShell from a dedicated dependency directory outside the SporeSpore
repository. The required upstream source is Godot `4.7-stable` at exact commit
`5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88` from
`https://github.com/godotengine/godot.git`.

```powershell
git clone --filter=blob:none https://github.com/godotengine/godot.git godot-sporespore-4.7
git -C godot-sporespore-4.7 checkout --detach 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88
git -C godot-sporespore-4.7 apply --check C:\Users\Cole\CodeStuff\games\SporeSpore\sdk\adapters\godot\engine_patches\godot_4_7_jolt_motor_telemetry.patch
git -C godot-sporespore-4.7 apply C:\Users\Cole\CodeStuff\games\SporeSpore\sdk\adapters\godot\engine_patches\godot_4_7_jolt_motor_telemetry.patch
python -m SCons platform=windows target=editor dev_build=yes debug_symbols=no module_mono_enabled=no tests=no accesskit=no d3d12=no angle=no -j12
```

`accesskit`, D3D12, and ANGLE are disabled only to keep this local development
build independent of those optional SDKs. The built-in Jolt module remains
enabled. A different Godot commit, build option set, patch digest, compiler,
binary, or host is a different toolchain/evidence key and cannot reuse a prior
qualification receipt.

## Executable zero-world qualification

From the SporeSpore repository root, run:

```powershell
pwsh -NoLogo -NoProfile -File sdk/run_qsdk_r24d3_instrumented_zero_world_gate.ps1
```

Add `-ColdBuild -RequireCleanPushedSource` only at a clean, pushed qualification
boundary. The runner verifies both repositories, requires the seven-file Godot
diff to equal the durable patch byte-for-byte, serializes under the locomotion
operation lock, builds the native editor, runs the source mutation audit, runs
the binding probe with zero physics objects and zero solver steps, and stores
the transcript and receipt under the durable `SporeSpore_Evidence` root. Receipt
v2 also copies the console launcher and its sibling engine executable into that
run, verifies both copies against their build outputs, executes the retained
pair, and verifies that both retained hashes remain unchanged after the probe.

The first clean-pushed cold run from commit `5f01d8ef3babb1132d341ee92f3773e653046d33`
passed compilation and `6/6` binding assertions, but its v1 receipt bound only
the console launcher and retained neither executable. It remains an immutable
positive development result, not qualification authority. The prospective
artifact-complete successor is declared by
[`../../../recovery/r24d3_godot_jolt_motor_telemetry_artifact_complete_successor_v2.json`](../../../recovery/r24d3_godot_jolt_motor_telemetry_artifact_complete_successor_v2.json).

That successor passed from clean-pushed source
`2ca77925147db4ef381737b17aedc4af723130b4`. Its artifact-complete receipt is
`sha256:a72e1c6c5b51799bec46fe76737ea23f9998c0af6778bb52dc0b7ed2cd9f36d9`;
the finite adoption authority is
[`../../../recovery/r24d3_godot_jolt_motor_telemetry_cold_qualification_adoption_v2.json`](../../../recovery/r24d3_godot_jolt_motor_telemetry_cold_qualification_adoption_v2.json).
This qualifies only the exact retained compile/binding key. It grants no
reproducible-build, result-reuse, native-characterization, recovery, or release
claim.

The exact adoption source later passed all eight uncached canonical full-cold
stages. Its finite qualification is
[`../../../recovery/r24d3_godot_jolt_motor_telemetry_post_adoption_full_cold_conformance_qualification_v1.json`](../../../recovery/r24d3_godot_jolt_motor_telemetry_post_adoption_full_cold_conformance_qualification_v1.json).
That suite ran the standard Godot executable and audited this retained custom
build; it did not rebuild or execute this instrumented profile. Native telemetry
characterization and profile promotion therefore remain false.

The first prospective consumer, QSDK-R24D4, closed as an immutable zero-world
negative before fixture construction because its realized `Vector3.BACK` axis
was `+Z` while the frozen worker/evaluator oracle expected `-Z`. That source
cannot be repaired or opened physically. The separately versioned successor is
QSDK-R24D5:
[`../../../recovery/r24d5_godot_jolt_one_hinge_telemetry_characterization_preregistration_v1.json`](../../../recovery/r24d5_godot_jolt_one_hinge_telemetry_characterization_preregistration_v1.json).
It binds this exact retained executable pair, makes the `+Z` axis and Godot
single-precision inertia serialization exact fixture identities, and measures
sign, independent momentum/energy residuals, cap, limit separation, disabled
motor, refusal, and freshness without an empirical acceptance threshold. Its
physical route remains closed until the ten-source freeze is clean-pushed and
its complete zero-world qualification is retained.

The binding returns `null` for invalid, unsafe, stale-before-first-step, fixed,
or otherwise unsupported reads. A successful dictionary uses schema
`sporespore.godot_jolt_hinge_motor_telemetry.v1` and contains sequence, solver
step, motor state/target/limits, signed impulse, positive work, absorbed work,
and derived net work.

## Prospective R24D8 active-step snapshot v2 profile

R24D7 proved that Godot dispatches `_integrate_forces` after
`JoltSpace3D::step` clears its `stepping` flag, so that callback cannot test an
active-step refusal or safely capture mutable solver state. The immutable R24D7
failure remains unchanged. R24D8 introduces a distinct combined patch:

`godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch`

Its raw SHA-256 is
`9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c`
and it modifies ten files. The patch includes the complete v1 measurement
changes; apply it by itself to a clean checkout of the pinned Godot commit. Do
not stack it on top of the v1 patch.

```powershell
git -C godot-sporespore-4.7 checkout --detach 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88
git -C godot-sporespore-4.7 apply --check C:\Users\Cole\CodeStuff\games\SporeSpore\sdk\adapters\godot\engine_patches\godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch
git -C godot-sporespore-4.7 apply C:\Users\Cole\CodeStuff\games\SporeSpore\sdk\adapters\godot\engine_patches\godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch
python -m SCons platform=windows target=editor dev_build=yes debug_symbols=no module_mono_enabled=no tests=no accesskit=no d3d12=no angle=no -j12
```

The v2 profile copies each newly advanced hinge receipt after
`PhysicsSystem::Update`, while the owning space still reports active stepping,
and before `_post_step` or `stepping = false`. The scripting binding continues
to return `null` during active stepping. A later safe read returns schema
`sporespore.godot_jolt_hinge_motor_telemetry.v2`, the original eleven fields,
and four timing fields:

- `capture_space_step_sequence`
- `read_space_step_sequence`
- `captured_during_active_step`
- `snapshot_is_current_space_step`

The snapshot is replaced only when Jolt's native telemetry sequence advances.
Thus a sleeping inactive hinge retains its earlier capture token while the
space's read token advances. This behavior is prospectively declared by
[`../../../recovery/r24d8_godot_jolt_active_step_snapshot_timing_preregistration_v1.json`](../../../recovery/r24d8_godot_jolt_active_step_snapshot_timing_preregistration_v1.json).
At the prospective declaration boundary, the local compile and freeze checks
did not qualify the profile. The official cold zero-world gate and one-world
timing question were still pending, and no numerical telemetry, recovery,
prone-to-standing, equivalence, or release claim was granted. The later finite
timing closure is recorded below without rewriting that declaration.

The first official R24D8 zero-world source was consumed before its own source
audit or build because the supervisor supplied this live v2 tree to the
unchanged R24D7 closure audit, whose retained live-source identity is the v1
tree. The distinct maintenance supervisor never reverses or stacks patches in
this working tree. It creates a sparse disposable v1 source view from the exact
upstream commit, applies only `godot_4_7_jolt_motor_telemetry.patch`, restores
the historical raw-LF byte representation, runs the unchanged R24D7 audit, and
removes the view. This live v2 tree remains exclusively checked against the
combined v2 patch by the R24D8 freeze. That repair is zero-world process
conformance and grants no runtime or locomotion claim.

## Claim and license boundary

Compilation and zero-world binding reachability do not establish telemetry
sign, numerical accuracy, energy closure, recovery, prone-to-standing, engine
equivalence, or release authority. Those require the separately frozen native
characterization and recovery programs named by the R24D3 contract.

Godot Engine source is MIT-licensed, and its bundled Jolt Physics source is
MIT-licensed. Preserve both projects' copyright and license notices when
building or redistributing a patched runtime. This repository does not yet
declare a redistribution license for the SporeSpore patch, so public binary or
source redistribution remains blocked until the release packaging boundary
adds one. This is not an official Godot or Jolt release.

## Prospective R71 solved-contact telemetry v3 profile

R71 adds one cumulative successor patch:

`godot_4_7_jolt_solved_contact_telemetry_v3.patch`

Its raw SHA-256 is
`5b28388449abe973f5b38c8aeb7a425ee116485618a783f8d7746256ee8e7ced`,
its byte length is `32896`, and it modifies `15` files. The patch includes all
v2 motor telemetry changes; apply it by itself to a clean checkout of the
pinned Godot commit. Do not stack it on either earlier patch.

```powershell
git -C godot-sporespore-4.7 checkout --detach 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88
git -C godot-sporespore-4.7 apply --check C:\Users\Cole\CodeStuff\games\SporeSpore\sdk\adapters\godot\engine_patches\godot_4_7_jolt_solved_contact_telemetry_v3.patch
git -C godot-sporespore-4.7 apply C:\Users\Cole\CodeStuff\games\SporeSpore\sdk\adapters\godot\engine_patches\godot_4_7_jolt_solved_contact_telemetry_v3.patch
python -m SCons platform=windows target=editor dev_build=yes debug_symbols=no module_mono_enabled=no tests=no accesskit=no d3d12=no angle=no -j12
```

After `PhysicsSystem::Update` completes and before Godot flushes contact
reports, the v3 profile reads Jolt's finalized normal and two friction solver
lambdas from the contact-constraint cache. It replaces the generic contact
report vectors only for manifolds whose complete point population is present,
ordered, and finite. The space-level binding
`JoltPhysicsServer3D.space_get_solved_contact_telemetry(space)` publishes the
capture/read sequence, reported and exact populations, four explicit failure
counts, and a conjunctive `complete` flag. Invalid, unsafe, or
stale-before-first-step reads return `null`.

The Godot adapter requires the exact v3 binary pair, both native APIs, a current
active-step snapshot, equal reported/exact populations, zero missing/CCD/count
mismatch/nonfinite failures, and `complete == true` before consuming any
contact impulse. An incomplete native snapshot is therefore an invalid
observation, never a synthesized zero or a fallback to the earlier pre-solve
estimate.

The retained development pair is content-addressed by console SHA-256
`19dc32b39400d200b5e5273f541ac41aa72a82110bb2fd338726a7fd465e0fa8`
and engine SHA-256
`b20323fd08a7b483e0dc59890ad381fe9d623c26ce1bcf63a5f7eb1f97ec9125`.
Compilation and the compact zero-world checks passed, but that development
receipt is not an official clean-pushed qualification and grants no numerical
contact, recovery, prone-to-standing, physical acceptance, or release claim.

## Prospective R136 solver-energy telemetry v4 profile

R136 adds one cumulative successor patch:

`godot_4_7_jolt_solver_energy_exchange_telemetry_v4.patch`

Its raw SHA-256 is
`e86f5b0516d513bd3de1f50f49e620e24b74690e3103244d52f42fd0ecf58211`,
its byte length is `59240`, and it modifies `16` files. The patch includes all
v3 motor and solved-contact telemetry changes; apply it by itself to a clean
checkout of the pinned Godot commit. Do not stack it on an earlier patch.

```powershell
git -C godot-sporespore-4.7 checkout --detach 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88
git -C godot-sporespore-4.7 apply --check C:\Users\Cole\CodeStuff\games\SporeSpore\sdk\adapters\godot\engine_patches\godot_4_7_jolt_solver_energy_exchange_telemetry_v4.patch
git -C godot-sporespore-4.7 apply C:\Users\Cole\CodeStuff\games\SporeSpore\sdk\adapters\godot\engine_patches\godot_4_7_jolt_solver_energy_exchange_telemetry_v4.patch
python -m SCons platform=windows target=editor dev_build=yes debug_symbols=no module_mono_enabled=no tests=no accesskit=no d3d12=no angle=no -j12
```

The v4 profile source-measures kinetic-energy exchange immediately around each
small-island joint and contact velocity-solver phase. It separately measures
the kinetic change and mass-weighted body-origin displacement caused by the
position solver, allowing a consumer with proven uniform gravity to derive the
matching potential-energy exchange without treating the whole-step mechanical
residual as work.

`JoltPhysicsServer3D.space_get_solver_energy_exchange_telemetry(space)` exposes
the finalized current-step snapshot. Its `complete` flag requires one collision
step, matching velocity/position coverage for every constrained island, finite
body and exchange measurements, no large-island split path, no CCD-active body,
no active soft body, and no Jolt update error. Missing, stale, or incomplete
telemetry is an invalid observation rather than zero work.

This source profile does not by itself prove a disjoint complete recovery
energy partition. The R136 adapter route must additionally prove that native
joint motors are disabled when actuator work is measured through the selected
force-based application path, body damping and other passive channels are
structurally absent, gravity is uniform, and every telemetry field is exact and
current. Compilation alone grants no energy closure, recovery,
prone-to-standing, physical acceptance, or release claim.

## Prospective R138 position-energy velocity-read access v5 delta

R138 adds one narrow delta on top of the exact v4 source:

`godot_4_7_jolt_solver_energy_position_velocity_read_access_v5.patch`

Its raw SHA-256 is
`75a10628d2202a3bcea4ac671e0321bc9cb866b4ecbd424c74026dbcb5a476d9`
and its byte length is `981`. Unlike the cumulative v4 patch, this file is an
additive delta: first apply the exact v4 patch to pinned Godot commit
`5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`, then apply the v5 delta.

```powershell
git -C godot-sporespore-4.7 checkout --detach 5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88
git -C godot-sporespore-4.7 apply --check C:\Users\Cole\CodeStuff\games\SporeSpore\sdk\adapters\godot\engine_patches\godot_4_7_jolt_solver_energy_exchange_telemetry_v4.patch
git -C godot-sporespore-4.7 apply C:\Users\Cole\CodeStuff\games\SporeSpore\sdk\adapters\godot\engine_patches\godot_4_7_jolt_solver_energy_exchange_telemetry_v4.patch
git -C godot-sporespore-4.7 apply --check C:\Users\Cole\CodeStuff\games\SporeSpore\sdk\adapters\godot\engine_patches\godot_4_7_jolt_solver_energy_position_velocity_read_access_v5.patch
git -C godot-sporespore-4.7 apply C:\Users\Cole\CodeStuff\games\SporeSpore\sdk\adapters\godot\engine_patches\godot_4_7_jolt_solver_energy_position_velocity_read_access_v5.patch
python -m SCons platform=windows target=editor dev_build=yes debug_symbols=no module_mono_enabled=no tests=no accesskit=no d3d12=no angle=no -j12
```

The v4 position-energy snapshots call Jolt's checked linear- and angular-
velocity getters immediately before and after each position correction. The
upstream position job grants velocity access `None`, which caused R137's debug
runtime to emit access-right assertions. The v5 delta changes only that job's
velocity grant to `Read`; position access remains `ReadWrite`. It does not
grant velocity writes, disable assertions, substitute unchecked accessors, or
change energy equations, controller behavior, thresholds, or evaluation.

Compilation and source qualification cannot prove that a live native step is
free of the former diagnostic. After R138 closes, a distinct minimal native
route ghost must enter the position solver and retain an empty fatal-diagnostic
screen before another full recovery pair is considered.

## Prospective R156 rotation-integration energy telemetry v6 delta

R156 adds one additive delta after the exact v4 plus v5 source:

`godot_4_7_jolt_rotation_integration_energy_telemetry_v6.patch`

Its raw SHA-256 is
`6f74357a1520ffb7691e92163228718c98509c5c40ab11fd381082b15635df72`
and its byte length is `11726`. It modifies only the Godot binding and Jolt's
`PhysicsSystem.cpp/.h`. Apply v4, then v5, then v6 to pinned Godot commit
`5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`.

The v6 patch measures the existing native kinetic-energy function immediately
before and after `Body::AddRotationStep`, before translation and all later CCD
or position-constraint work. It adds signed rotation-integration kinetic
exchange and exact expected/observed/dynamic/invalid body counts to telemetry
schema v2. Each integration job accumulates locally and enters the existing
mutex only once. Completeness rejects partial populations, zero dynamic bodies,
invalid measurements, and nonfinite exchange.

The patch adds no physics-state write and does not accept a whole-step residual.
R156 source qualification proves ideal rotation-energy invariance and the
measurement/refusal design only.

R157 subsequently completed a full clean build of the exact v4-plus-v5-plus-v6
tree in `00:11:42.81`. The retained console SHA-256 is
`2027bcd4adfce5cdecafa5b02392f859b1c61b0895d4f4588b4edf6eb91e2f9c`;
the sibling engine SHA-256 is
`1b365fe5a054e2614e2c063273d6e686593eafac81836475385df14b65177e4b`.
Clean-pushed zero-world qualification at `4f7744af` proved method registration,
invalid-RID refusal, and strict v2 consumer semantics. It did not execute a
native step, so field population, float32 magnitude, portable-ledger use,
recovery, prone-to-standing, and release authority remain false.

## R24D8 qualified timing boundary

The v2 profile has now passed its complete cold zero-world gate from exact
clean-pushed SporeSpore source
`b17a6677e711625061726279a1b0287c57fa82ec`, followed by the single declared
finite timing world. The physical run consumed `1` world attempt, `1` world
build, `8` solver steps, and `8` retained samples. Active snapshots advanced
telemetry/capture/read sequences as `2,3,4,5` and were current. Sleeping
observations retained telemetry/capture at `5` while reads advanced `6,7,8,9`
and were explicitly stale.

This qualifies only the capture/read timing semantics of the exact fixture.
It does not qualify the numerical motor impulse, derived work values, general
hinge behavior, stock Godot, recovery, prone-to-standing, cross-engine
equivalence, or redistribution. The instrumented profile remains unpromoted.
The source is consumed and cannot rerun; a distinct full one-hinge numerical
telemetry characterization with its own prospective freeze and zero-world gate
is required next.

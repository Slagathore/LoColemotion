# SporeSpore public adapter kit

This directory defines the public boundary for adding a physics engine or
other host to the SporeSpore locomotion SDK. An adapter observes and actuates a
host. It does not own locomotion policy, semantic scheduling, scientific
acceptance, or root-motion shortcuts.

The machine-readable authority is
[`adapter_contract_v1.json`](adapter_contract_v1.json). The independent
reference manifest is
[`reference_adapter_manifest_v1.json`](reference_adapter_manifest_v1.json).
The clean pushed-source A0-A6 evidence is indexed by
[`adapter_authoring_validation_manifest.json`](adapter_authoring_validation_manifest.json).
The Python fixture uses only those files, the public Python binding, and the
real C ABI. It imports no SporeSpore game, laboratory, Godot, Rapier, or MuJoCo
module.

## Required adapter loop

Every adapter performs the same ordered lifecycle:

1. Load a strict capability manifest and compute its canonical SHA-256.
2. Compile a morphology without constructing a physics world.
3. Build host bodies, joints, actuators, contacts, and materials from the
   compiled morphology.
4. Map one host sample into the canonical right-handed `+X` forward, `+Y` up,
   `+Z` right SI frame.
5. Emit joint and contact observations in the compiled semantic order.
6. Call an explicit named policy entrypoint. New adapters must request
   `sporespore_balanced_wave_bw5r_b_v1`; the unnamed compatibility entrypoints
   are not an acceptable selected-policy binding.
7. Validate actuator identity, order, bounds, and expiration.
8. Apply each command at most once, or preserve safe zero.
9. Retain host clamping and the actual applied command in an adapter receipt.
10. Feed that receipt back as `previous_applied_actuation` on the next
    semantic step.

Capability manifests and applied-actuation receipts are digested through the
public `ss_canonicalize_json` C ABI (or
`LocomotionCore.canonicalize_json` convenience wrapper). Adapters must not use
their language runtime's default float-to-JSON spelling as digest authority.

Unknown contact state stays unknown. In particular, raw impulses from several
engine contact shapes are not automatically an additive semantic foot load.
An adapter may advertise `qualified_load` only after its engine-specific
aggregation and measurement contract is separately characterized.

## Authority boundary

Adapter-authoring conformance proves only that a third party can integrate the
public schemas and selected policy safely. It does not prove that the host
engine walks. Engine-specific C2-C5 fixtures are still required for coordinate,
dynamics, actuator, contact, and material semantics. Same-policy physical C6
evidence is required before an engine can advertise quadruped locomotion.

The adapter must never:

- substitute a controller policy;
- reorder canonical identities;
- invent false/zero observations when a value is unavailable;
- write base pose or velocity to create locomotion;
- apply an expired command;
- apply a command more than once;
- hide host clamping; or
- grant itself walking or physical-acceptance authority.

## Run the source conformance fixture

From PowerShell at the repository root:

```powershell
.\sdk\run_adapter_authoring_conformance.ps1
```

The command builds the real release C ABI, executes the independent unit
suite, and compiles an A0-A6 report. It constructs no physics world and grants
no C6 authority.

To retain a clean pushed-source report, provide a new durable path whose
filename is exactly `report.json`:

```powershell
.\sdk\run_adapter_authoring_conformance.ps1 `
  -Output C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\adapter-authoring-<commit>\report.json
```

The runner refuses to overwrite an existing report.

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [switch]$SkipGodot,
    [string]$DurableAttestationOutput = ""
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
$attestationPath = Join-Path $sdkRoot "locomotion_full_conformance_attestation.ps1"
$observabilityPath = Join-Path $sdkRoot "conformance_observability.ps1"
. $operationLockPath
. $attestationPath
. $observabilityPath

if ($SkipGodot -and -not [string]::IsNullOrWhiteSpace($DurableAttestationOutput)) {
    throw "A durable full-conformance attestation cannot be written with -SkipGodot."
}
$conformanceStartedUtc = [DateTime]::UtcNow
$attestationSourceAtStart = $null
if (-not [string]::IsNullOrWhiteSpace($DurableAttestationOutput)) {
    [void](Assert-SporeSporeDurableAttestationOutputPath `
        -RepoRoot $repoRoot `
        -OutputPath $DurableAttestationOutput)
    $attestationSourceAtStart = Get-SporeSporeAttestationSourceIdentity `
        -RepoRoot $repoRoot `
        -RequireCleanPushedLive
}
$conformanceOperationLock = Enter-SporeSporeLocomotionOperationLock `
    -Role conformance
if (-not [bool]$conformanceOperationLock.acquired) {
    throw (
        "Another conformance or physical process owns the locomotion operation " +
        "lock '$($conformanceOperationLock.mutex_name)'."
    )
}

$conformanceObservation = $null
$conformanceTranscriptStarted = $false
$conformanceFailure = $null
$conformanceObservationFailure = $null
try {
$conformanceObservation = New-SporeSporeConformanceObservationSession `
    -RepoRoot $repoRoot `
    -RunnerPath $PSCommandPath `
    -SkipGodot ([bool]$SkipGodot) `
    -Godot $Godot
Start-Transcript `
    -LiteralPath $conformanceObservation.log_path `
    -UseMinimalHeader | Out-Null
$conformanceTranscriptStarted = $true

function Wait-ForSporeSporeHeadlessGodotDrain {
    [CmdletBinding()]
    param(
        [ValidateRange(1, 60)]
        [int]$TimeoutSeconds = 30
    )
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ($true) {
        $active = @(
            Get-CimInstance Win32_Process |
                Where-Object {
                    $_.Name -like "Godot_v4.7-stable_mono_win64*" -and
                    $_.CommandLine -match "--headless" -and
                    $_.CommandLine -match "SporeSpore|sporespore_" -and
                    $_.CommandLine -notmatch "--lsp-port"
                }
        )
        if ($active.Count -eq 0) { return }
        if ([DateTime]::UtcNow -ge $deadline) {
            $identities = @(
                $active | ForEach-Object {
                    "pid=$($_.ProcessId) command=$($_.CommandLine)"
                }
            ) -join [Environment]::NewLine
            throw (
                "Transient SporeSpore headless Godot processes did not " +
                "drain before an adapter rebuild:" +
                [Environment]::NewLine + $identities
            )
        }
        Start-Sleep -Milliseconds 250
    }
}

Start-SporeSporeConformanceStage `
    -Session $conformanceObservation `
    -StageId "authority_and_historical_closures"

# Fail early if an ambient editor/thread working directory or cross-project
# fleet pointer has displaced the repository-owned SporeSpore agent boundary.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_repository_agent_boundary.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Repository agent-boundary audit failed with exit code $LASTEXITCODE"
}

# The process-observability contract must prove all eight stage identities,
# create-only JSON receipts, CAS retention, failure excerpts, and disabled cache
# boundary before the measured canonical run can continue.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_conformance_observability.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Conformance observability audit failed with exit code $LASTEXITCODE"
}

# CDK1 constructs the conservative source/environment candidate key and proves
# its root/order invariance plus content, omission, path, environment, and
# runtime mutation controls. The contract still forbids lookup and reuse.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_conformance_dependency_key.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Conformance dependency-key audit failed with exit code $LASTEXITCODE"
}

# CAD1 reconciles the per-audit external-dependency registry against all CEP1
# closure audits and proves tree/file/query/Git-object invalidation. R23D13 is
# the first complete entry; the other 94 keep aggregate lookup/reuse disabled.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_conformance_audit_dependency.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Conformance audit-dependency gate failed with exit code $LASTEXITCODE"
}

# CRP2 binds the exact R23D13 parent/closed-child PowerShell, Git, Windows,
# Defender, measured-source, and host-semantic profile. It is complete only for
# that audit; aggregate runtime closure and reuse remain unreachable.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_conformance_runtime_profile.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Conformance runtime-profile gate failed with exit code $LASTEXITCODE"
}

# CER1 constructs a content-addressed execution candidate for the one complete
# R23D13 audit and proves exact read-back plus corruption and invalidation
# refusal. Its prospective contract forbids production lookup or reuse until a
# clean two-process cold-equivalence result is frozen under successor authority.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_conformance_execution_receipt.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Conformance execution-receipt gate failed with exit code $LASTEXITCODE"
}

# CER1-C1 freezes the first clean two-process observation: one execution and a
# zero-invocation read-back had identical input, retained record, terminal
# marker, and semantic result digests. CER1 itself still forbids production
# lookup/reuse; only a distinct successor may connect that execution edge.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_conformance_execution_receipt_commissioning.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Conformance execution-receipt commissioning closure failed with exit code $LASTEXITCODE"
}

# CER1-D1 prevents a correctness result from being mistaken for a speed result.
# Direct R23D13 execution is faster than per-audit read-back after key cost, so
# the canonical route must remain executed until a higher-leverage successor is
# separately commissioned.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_conformance_execution_receipt_adoption_decision.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Conformance execution-receipt adoption decision failed with exit code $LASTEXITCODE"
}

# CAP1 is a development-only serialized profiler over the exact CEP1 inventory.
# Its focused gate proves create-only per-audit timing/output retention and
# source-mutation refusal; the full 95-audit measurement is deliberately not
# replayed inside ordinary conformance and grants no cache authority.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_conformance_audit_profiler.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Conformance audit-profiler gate failed with exit code $LASTEXITCODE"
}

# CAP1-C1 verifies the retained clean 95-audit profile, all 190 stream CAS
# objects, ranked concentration, and the outer-timeout incident. It also keeps
# cache authority false and requires a crash-resilient successor before another
# full profiling sweep.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_conformance_audit_profiler_commissioning.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Conformance audit-profiler commissioning closure failed with exit code $LASTEXITCODE"
}

# CAP2 prospectively hardens the development profiler against host or process
# interruption. Its focused gate proves create-only per-audit receipts, exact
# contiguous resume, CAS validation, drift/corruption refusal, and zero
# production-reuse or physical authority.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_conformance_audit_profiler_resume.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Conformance crash-resilient audit-profiler gate failed with exit code $LASTEXITCODE"
}

# CAP2-C1 freezes the clean two-child-process controlled-interruption recovery
# run and independently rehashes its manifest, receipt prefix, streams, final
# profile, source Git objects, and bounded claim surface.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_conformance_audit_profiler_resume_commissioning.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Conformance crash-resilient audit-profiler closure failed with exit code $LASTEXITCODE"
}

# THA2 preserves the complete frozen material-publication lineage through the
# canonical BW27P root while remaining compatible with legacy closure audits
# that require their path to be visibly registered by normal conformance. This
# exact registry is declaration-only: THA2 proves the variable has no second
# source occurrence and that none of these descendants is directly launched.
$transitiveHistoricalAuditCoverageRegistry = @(
    "tests\test_bw24m_material_characterization_closure.ps1",
    "tests\test_bw27m_material_characterization_closure.ps1",
    "tests\test_bw20f_material_profile_publication_closure.ps1",
    "tests\test_bw22m_material_characterization_closure.ps1",
    "tests\test_bw22m_material_profile_publication_closure.ps1",
    "tests\test_bw24m_material_profile_publication_closure.ps1",
    "tests\test_bw24p_material_profile_publication_closure.ps1"
)
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "sdk\conformance_transitive_historical_audit_gate_v2.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Conformance transitive historical-audit v2 gate failed with exit code $LASTEXITCODE"
}
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "sdk\conformance_transitive_historical_audit_tha2_closure_gate_v1.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Conformance transitive historical-audit v2 closure failed with exit code $LASTEXITCODE"
}

# CAK1 declares the permanent global physical-authorization safeguards and the
# required worker/evaluator/supervisor campaign-role interface. It validates
# exact tracked sources and runner bindings but remains deliberately
# unexecuted, uncommissioned, and disconnected from physical launch.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_conformance_authorization_kernel.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Conformance authorization-kernel gate failed with exit code $LASTEXITCODE"
}

# LCA1 turns the declared safety kernel into a measured, create-only,
# Godot-inclusive campaign-local attestation route. Its focused gate executes
# only synthetic zero-world commands while proving exact lineage/role binding,
# per-gate stream and receipt CAS retention, create-only publication, and
# physical-authority refusal. Production adoption remains disabled until a
# clean same-source full-V2/scoped cold commissioning closure exists.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_locomotion_campaign_attestation.ps1") `
    -Godot $Godot
if ($LASTEXITCODE -ne 0) {
    throw "Locomotion campaign-local attestation gate failed with exit code $LASTEXITCODE"
}

# The full cold runner must execute the exact campaign-role refusal surfaces
# that LCA1 executes. The first cold comparison proved these edges were absent:
# the scoped path produced all three markers while the full transcript produced
# none. Keep the three roles explicit so source review and the focused LCA1 gate
# can prove the full runner's subset relationship before recommissioning.
foreach ($commissioningRole in @("worker", "evaluator", "supervisor")) {
    $commissioningRoleOutput = @(& pwsh `
        -NoLogo `
        -NoProfile `
        -File (Join-Path $repoRoot `
            "tests\test_locomotion_campaign_attestation_commissioning_roles.ps1") `
        -Role $commissioningRole 2>&1)
    $commissioningRoleExitCode = $LASTEXITCODE
    foreach ($line in $commissioningRoleOutput) {
        # Start-Transcript does not reliably retain a native child's direct
        # stdout. Re-emitting the captured line through this host makes the
        # exact marker part of the create-only canonical transcript.
        Write-Host ([string]$line)
    }
    if ($commissioningRoleExitCode -ne 0) {
        throw (
            "LCA1 $commissioningRole commissioning-role gate failed with " +
            "exit code $commissioningRoleExitCode"
        )
    }
}

& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot `
        "tests\test_locomotion_campaign_attestation_v1_first_cold_comparison_incident.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "LCA1 first cold-comparison incident audit failed with exit code $LASTEXITCODE"
}

& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot `
        "tests\test_locomotion_campaign_attestation_v1_second_cold_comparison_incident.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "LCA1 second cold-comparison incident audit failed with exit code $LASTEXITCODE"
}

# GJTP1 is the active Godot/Jolt native transport route. Its source audit
# proves that the normal JSON path executes the pure native operation once,
# permits only one exact-size overflow retry, reports a versioned contract,
# and is checked by both physical runner variants before world construction.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_godot_jolt_transport_execution_contract.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Godot/Jolt transport execution source contract failed with exit code $LASTEXITCODE"
}

# GJPS1 is a distinct additive controller-session route. It compiles immutable
# morphology and policy state once, keeps controller memory explicit, requires
# exact byte equivalence to the stateless operation, and fails stale adapters
# before any descriptor compile or physics world.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_godot_jolt_persistent_session_contract.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Godot/Jolt persistent-session source contract failed with exit code $LASTEXITCODE"
}

# WRB1 is a prospective Windows Rust build contract, not a rewrite of MV6.
# Its zero-world audit binds the two-clean-root byte gate, the exact PE fields
# that exposed the old timestamp/GUID nondeterminism, the verified /Brepro and
# path-remapping recipe, and content-addressed retention before first use.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_windows_rust_reproducible_build_contract.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Windows Rust reproducible-build contract failed with exit code $LASTEXITCODE"
}

# CEP1 names and enforces the historical-evidence modes exposed by MV5/MV6:
# retained CAS bytes, pinned Git blobs, filter-receipted checkout
# reconstruction, and prohibited historical live paths. It also verifies the
# complete 65-audit static inventory and blocks an ambient .gitattributes flip
# until a distinct byte-mapped provenance migration is frozen.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_closure_evidence_provenance_contract.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Closure evidence provenance contract failed with exit code $LASTEXITCODE"
}

# GJPT1 and GJPT2 have both consumed their physical identities. Normal
# conformance must not regenerate their prospective derived runner from today's
# evolving adapter/base paths. The GJPT2 closure audit cold-verifies both
# immutable closures, both retained evidence trees and CAS inputs, the frozen
# source contract, bounded post-optimization estimate, and consumed identities.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_godot_jolt_phase_timing_gjpt2_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Godot/Jolt GJPT2 phase-timing closure failed with exit code $LASTEXITCODE"
}

# The operator workbench must remain a zero-world explanatory interface during
# self-test. Its catalog audit also proves that only the explicitly confirmed
# BW22L row can expose -RunPhysical and that proof digests still match.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_locomotion_experiment_workbench.ps1") `
    -Godot $Godot `
    -SkipGodot:$SkipGodot
if ($LASTEXITCODE -ne 0) {
    throw "Locomotion experiment workbench audit failed with exit code $LASTEXITCODE"
}

# C6-MJC-HC-VH1 consumed its only physical identity and closed as a complete
# valid negative: all eight loaded affine-response cells passed, while all four
# unloaded cells failed the frozen velocity-response gate. Normal conformance
# now verifies its immutable source/evidence/attestation boundary and must not
# re-enter the prospective freeze route.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot `
        "tests\test_mujoco_c6_velocity_only_host_characterization_vh1_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "MuJoCo C6-MJC-HC-VH1 negative closure audit failed with exit code " +
        $LASTEXITCODE
    )
}

# VH2 consumed its only physical process and closed infrastructure-invalid
# after the first MjModel exposed the pinned Python binding's M field while the
# implementation requested qM. Its closure proves the exact retained failure,
# zero completed cells, absent report, source/evidence/attestation hashes,
# zero-world binding-surface reproduction, bounded claims, and rerun refusal.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot `
        "tests\test_mujoco_c6_velocity_only_stability_host_characterization_vh2_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "MuJoCo C6-MJC-HC-VH2 infrastructure-invalid closure audit failed " +
        "with exit code " +
        $LASTEXITCODE
    )
}

# VH3 completed all 24 cells, but its force/impulse trace was recomputed on the
# copied post-step state rather than measured during the completed implicit
# step. Its closure pins the complete physical trace, the zero-world momentum
# diagnostic, the no-result boundary, and immediate same-identity refusal.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot `
        "tests\test_mujoco_c6_velocity_only_stability_host_characterization_vh3_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "MuJoCo C6-MJC-HC-VH3 measurement-invalid closure audit failed with exit code " +
        $LASTEXITCODE
    )
}

# VH4 passed all 24 exact finite host cells with corrected temporal
# instrumentation. Its closure pins all six physical artifacts, independently
# replays the production evaluator over 43,200 traces, bounds the positive
# claim, and proves immediate same-identity physical refusal.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot `
        "tests\test_mujoco_c6_velocity_only_stability_host_characterization_vh4_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "MuJoCo C6-MJC-HC-VH4 positive closure audit failed with exit code " +
        $LASTEXITCODE
    )
}

# VH5 consumed its sole physical identity and closed positive for the exact
# finite four-class s169 host profile. Normal conformance verifies the frozen
# source blobs, exact attestation and six-file evidence tree, all 96 cells and
# 172,800 traces, production-evaluator replay, narrow claims, and rerun refusal.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot `
        "tests\test_mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "MuJoCo C6-MJC-HC-VH5 positive closure audit failed with exit code " +
        $LASTEXITCODE
    )
}

# MV1 consumed its sole process identity and closed implementation-invalid
# before native actuation or one complete physics step. Normal conformance now
# audits the immutable attempt, exact frozen Git blobs, absent report, strict
# non-claims, and executable rerun refusal.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot `
        "tests\test_mujoco_c6_bw19v_selected_policy_walking_mv1_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "MuJoCo C6-MJC-BW19V-MV1 closure audit failed with exit code " +
        $LASTEXITCODE
    )
}

# MV2 consumed its sole process after passing the real-DLL and full-Godot
# gates. The process completed the frozen control-flow horizon, then failed in
# report assembly before a report could be evaluated or retained. Normal
# conformance audits that no-result closure and executable rerun refusal.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot `
        "tests\test_mujoco_c6_bw19v_selected_policy_walking_mv2_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "MuJoCo C6-MJC-BW19V-MV2 closure audit failed with exit code " +
        $LASTEXITCODE
    )
}

# MV3 consumed its sole process and retained a complete report. The frozen
# combined walking-and-integrity contract is a valid negative: receipt
# projection and limb-memory order fail on every trace row, and the terminal
# snapshot has only three contacts. Normal conformance audits the immutable
# evidence, deterministic evaluator/post-hoc replay, strict development-only
# locomotion boundary, and executable same-identity rerun refusal.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot `
        "tests\test_mujoco_c6_bw19v_selected_policy_walking_mv3_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "MuJoCo C6-MJC-BW19V-MV3 valid-negative closure audit failed with exit code " +
        $LASTEXITCODE
    )
}

# MV4 consumed its sole process after the walking-phase controller reached its
# evidence-limit transition. The first terminal-restoration composition then
# failed because production kinematic vectors are x/y/z objects while the new
# restorer and its synthetic canary assumed lists. No report or scientific
# result survived. Normal conformance audits the immutable no-result closure,
# exact evidence tree, strict non-claims, and executable rerun refusal.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot `
        "tests\test_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv4_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "MuJoCo C6-MJC-BW19V-MV4 closure audit failed with exit code " +
        $LASTEXITCODE
    )
}

# MV5 consumed its sole process after the frozen 2,992-step loop reached
# post-loop report assembly. A PH1 closure field-name mismatch then prevented
# report completion, evaluation, and serialization. Normal conformance audits
# the immutable five-file evidence tree, exact traceback, absent-report
# non-result boundary, and executable same-identity refusal.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot `
        "tests\test_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv5_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "MuJoCo C6-MJC-BW19V-MV5 closure audit failed with exit code " +
        $LASTEXITCODE
    )
}

# MV6 consumed its sole exact-source process and closed as a complete valid
# positive for its exact-s169 pose-hold-restoration and finite walking
# contract. Normal conformance now verifies the six-file retained evidence
# tree, replays the unchanged frozen evaluator, independently reconstructs the
# metrics and contact schedule, preserves the non-claims, and proves the
# supervisor refuses another world before evidence mutation.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot `
        "tests\test_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "MuJoCo C6-MJC-BW19V-MV6 closure audit failed with exit code " +
        $LASTEXITCODE
    )
}

# TR1 consumed its sole physical identity and closed as a complete valid
# negative: the frozen restorer achieved the contact hold, but the unchanged
# walking-safety conjunction failed. Normal conformance now audits the exact
# evidence tree, recomputes the frozen evaluator, preserves the mechanism-only
# observation, and proves the supervisor refuses another world.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot `
        "tests\test_rapier_c6_bw19v_velocity_only_contact_restoration_tr1_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier C6-RAP-BW19V-V4-TR1 negative closure audit failed with exit code " +
        $LASTEXITCODE
    )
}

# PH1 consumed its sole physical identity and closed as a complete valid
# positive for exact s169 pose-hold-restoration technical commissioning and
# its declared finite single-body walking contract. Normal conformance audits
# the exact seven-file evidence tree, replays the frozen evaluator, preserves
# the preregistered nonclaims, and proves the supervisor refuses another world.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot `
        "tests\test_rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier C6-RAP-BW19V-V4-PH1 positive closure audit failed with exit code " +
        $LASTEXITCODE
    )
}

# XV1 consumed its sole six-cell supervisor identity but closed
# implementation-invalid and incomplete after four reports. Each retained
# report passes its frozen cell evaluator, but two declared cells were never
# opened and no aggregate result exists. Normal conformance audits the exact
# nineteen-file evidence tree, replays all four cold evaluators, preserves the
# four observations as non-promotable, and proves same-identity refusal.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot `
        "tests\test_cross_engine_c6_bw19v_discrete_material_validation_xv1_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "Cross-engine C6-XE-BW19V-XV1 closure audit failed with exit code " +
        $LASTEXITCODE
    )
}

# XV2 consumed its sole six-process physical identity and retained all six
# individually passing worker reports. Its original aggregate construction was
# implementation-invalid, but the prospectively frozen zero-world recovery
# reconstructed only the declared count scalars and passed the unchanged 12/12
# gate. Normal conformance now audits the exact 31-file closed evidence tree,
# freshly replays all six cold evaluators, and proves recovery rerun refusal.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot `
        "tests\test_cross_engine_c6_bw19v_discrete_material_validation_xv2_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "Cross-engine C6-XE-BW19V-XV2 closure audit failed with exit code " +
        $LASTEXITCODE
    )
}

# THA2 executes the BW24M and BW27M immutable characterization closures later
# through the BW27P material-publication root. Their terminal markers and exact
# child graph are independently pinned by the transitive-execution gate; do not
# re-add duplicate top-level launches here.

[void](Complete-SporeSporeConformanceStage -Session $conformanceObservation)
Start-SporeSporeConformanceStage `
    -Session $conformanceObservation `
    -StageId "source_inventory_and_zero_world_preflights"

foreach ($scriptName in @(
    "run_adapter_authoring_conformance.ps1",
    "run_adaptation_provider_conformance.ps1",
    "run_adaptation_experience_encyclopedia_conformance.ps1",
    "run_heading_command_turning_conformance.ps1",
    "run_qsdk_r23d1_physical_development_preflight.ps1",
    "run_qsdk_r23d1_godot_jolt_worker_preflight.ps1",
    "run_qsdk_r23d1_rapier_worker_preflight.ps1",
    "run_qsdk_r23d1_mujoco_worker_preflight.ps1",
    "run_qsdk_r23d1_supervisor.ps1",
    "run_qsdk_r23d3_phase_balanced_preflight.ps1",
    "run_qsdk_r23d3_mujoco_worker_preflight.ps1",
    "run_qsdk_r23d3_rapier_worker_preflight.ps1",
    "run_qsdk_r23d3_godot_jolt_worker_preflight.ps1",
    "run_qsdk_r23d3_supervisor.ps1",
    "run_qsdk_r23d3_zero_world_gate.ps1",
    "run_qsdk_r23d4_terminal_stabilization_preflight.ps1",
    "run_qsdk_r23d4_mujoco_worker_preflight.ps1",
    "run_qsdk_r23d4_rapier_worker_preflight.ps1",
    "run_qsdk_r23d4_godot_jolt_worker_preflight.ps1",
    "run_qsdk_r23d4_supervisor.ps1",
    "run_qsdk_r23d4_zero_world_gate.ps1",
    "publish_qsdk_r23d4_trace.ps1",
    "run_qsdk_r23d7_mujoco_worker_preflight.ps1",
    "run_qsdk_r23d7_rapier_worker_preflight.ps1",
    "run_qsdk_r23d7_godot_jolt_worker_preflight.ps1",
    "run_qsdk_r23d7_supervisor.ps1",
    "run_qsdk_r23d7_zero_world_gate.ps1",
    "publish_qsdk_r23d7_trace.ps1",
    "run_qsdk_r23d8_mujoco_worker_preflight.ps1",
    "run_qsdk_r23d8_rapier_worker_preflight.ps1",
    "run_qsdk_r23d8_godot_jolt_worker_preflight.ps1",
    "run_qsdk_r23d8_supervisor.ps1",
    "run_qsdk_r23d8_zero_world_gate.ps1",
    "run_qsdk_r23d8_authorization_canaries.ps1",
    "publish_qsdk_r23d8_trace.ps1",
    "run_qsdk_r23d61_zero_world_gate.ps1",
    "run_qsdk_r24d1_zero_world_gate.ps1",
    "run_qsdk_r24d2_zero_world_gate.ps1",
    "run_qsdk_r24d3_instrumented_zero_world_gate.ps1",
    "run_qsdk_r24d4_one_hinge_telemetry_characterization.ps1",
    "run_tier2_adaptation_architecture_conformance.ps1",
    "run_developer_experience_conformance.ps1",
    "run_portable_api_conformance.ps1",
    "run_versioning_conformance.ps1",
    "compile_balanced_wave_bw4r_selection.ps1",
    "run_balanced_wave_bw4r_development.ps1",
    "compile_balanced_wave_bw5r_selection.ps1",
    "run_balanced_wave_bw5r_development.ps1",
    "run_balanced_wave_bw5v_material_characterization.ps1",
    "run_balanced_wave_bw20f_material_characterization.ps1",
    "run_balanced_wave_bw20f_material_profile_publication.ps1",
    "run_balanced_wave_bw20f_material_locomotion.ps1",
    "run_balanced_wave_bw21l_lateral_development.ps1",
    "run_policy_aware_physical_receipt_composition_preflight.ps1",
    "run_balanced_wave_bw22m_material_declaration_preflight.ps1",
    "run_balanced_wave_bw22m_material_characterization.ps1",
    "run_balanced_wave_bw22m_material_profile_publication.ps1",
    "run_godot_jolt_bw22m_material_profile_conformance.ps1",
    "run_balanced_wave_bw22l_lateral_declaration_preflight.ps1",
    "run_balanced_wave_bw22l_lateral_development.ps1",
    "run_balanced_wave_bw23y_yaw_gain_development_preflight.ps1",
    "run_balanced_wave_bw25y_yaw_development_declaration_preflight.ps1",
    "run_balanced_wave_bw25y_yaw_development.ps1",
    "run_balanced_wave_bw26i_actual_worker_receipt_route_commissioning.ps1",
    "run_balanced_wave_bw26j_actual_worker_receipt_authority_commissioning.ps1",
    "run_balanced_wave_bw28y_yaw_development.ps1",
    "run_balanced_wave_bw28y_yaw_development_zero_world_gate.ps1",
    "locomotion_operation_lock.ps1",
    "locomotion_full_conformance_attestation.ps1",
    "run_balanced_wave_bw24m_material_declaration_preflight.ps1",
    "run_balanced_wave_bw24m_material_characterization.ps1",
    "run_balanced_wave_bw27m_material_declaration_preflight.ps1",
    "run_balanced_wave_bw27m_material_characterization.ps1",
    "run_balanced_wave_bw24m_material_profile_publication.ps1",
    "run_balanced_wave_bw24p_material_profile_publication.ps1",
    "run_balanced_wave_bw27p_material_profile_publication.ps1",
    "run_godot_jolt_bw24m_material_profile_conformance.ps1",
    "run_godot_jolt_bw24p_material_profile_conformance.ps1",
    "run_godot_jolt_bw27p_material_profile_conformance.ps1",
    "run_godot_jolt_friction_ladder_characterization.ps1",
    "balanced_wave_bw20f_material_characterization_gate.ps1",
    "balanced_wave_bw20f_material_locomotion_gate.ps1",
    "balanced_wave_bw21l_lateral_development_gate.ps1",
    "balanced_wave_bw22m_material_characterization_gate.ps1",
    "balanced_wave_bw22l_lateral_development_gate.ps1",
    "balanced_wave_bw24m_material_characterization_gate.ps1",
    "balanced_wave_bw25y_yaw_development_gate.ps1",
    "balanced_wave_bw26i_actual_worker_receipt_route_gate.ps1",
    "balanced_wave_bw26j_actual_worker_receipt_authority_gate.ps1",
    "balanced_wave_bw27m_material_characterization_gate.ps1",
    "balanced_wave_bw28y_actual_path_gate.ps1",
    "balanced_wave_bw28y_yaw_development_gate.ps1",
    "compile_balanced_wave_bw13p_r1_selection.ps1",
    "run_balanced_wave_bw13p_r1_morphology_development.ps1",
    "compile_balanced_wave_bw13p_r2_selection.ps1",
    "run_balanced_wave_bw13p_r2_morphology_development.ps1",
    "compile_balanced_wave_bw13p_r3_selection.ps1",
    "run_balanced_wave_bw13p_r3_morphology_development.ps1",
    "compile_balanced_wave_bw14v_selection.ps1",
    "run_balanced_wave_bw14v_morphology_development.ps1",
    "compile_balanced_wave_bw15f_selection.ps1",
    "run_balanced_wave_bw15f_morphology_development.ps1",
    "compile_balanced_wave_bw16s_selection.ps1",
    "run_balanced_wave_bw16s_morphology_development.ps1",
    "compile_balanced_wave_bw17p_selection.ps1",
    "run_balanced_wave_bw17p_morphology_development.ps1",
    "compile_balanced_wave_bw18g_selection.ps1",
    "run_balanced_wave_bw18g_morphology_development.ps1",
    "compile_balanced_wave_bw19v_selection.ps1",
    "run_balanced_wave_bw19v_independent_validation.ps1",
    "run_rapier_c6_force_based_host_characterization.ps1",
    "run_rapier_c6_force_based_load_response_lr1.ps1",
    "run_rapier_c6_force_based_convergence_window_cw1.ps1",
    "run_rapier_c6_force_based_solver_phase_development_spd1.ps1",
    "run_rapier_c6_force_based_selected_configuration_validation_spv1.ps1",
    "run_rapier_c6_force_based_velocity_only_host_characterization_vh1.ps1",
    "run_mujoco_c6_velocity_only_host_characterization_vh1.ps1",
    "run_mujoco_c6_velocity_only_stability_host_characterization_vh2.ps1",
    "run_mujoco_c6_velocity_only_stability_host_characterization_vh3.ps1",
    "run_mujoco_c6_velocity_only_stability_host_characterization_vh4.ps1",
    "run_mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5.ps1",
    "run_mujoco_c6_bw19v_selected_policy_walking_mv1.ps1",
    "run_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv4.ps1",
    "run_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv5.ps1",
    "run_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6.ps1",
    "run_cross_engine_c6_bw19v_discrete_material_validation_xv1.ps1",
    "run_cross_engine_c6_bw19v_discrete_material_validation_xv2.ps1",
    "cross_engine_c6_bw19v_discrete_material_validation_xv2_supervisor_projection.ps1",
    "run_rapier_c6_velocity_only_live_integration_preflight.ps1",
    "run_rapier_c6_bw19v_velocity_only_early_horizon_eh1.ps1",
    "run_rapier_c6_bw19v_velocity_only_long_horizon_lc1.ps1",
    "run_rapier_c6_bw19v_velocity_only_terminal_stance_ts1.ps1",
    "run_rapier_c6_bw19v_velocity_only_contact_restoration_tr1.ps1",
    "run_rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1.ps1",
    "run_rapier_c6_bw19v_selected_policy_commissioning_c1.ps1",
    "run_rapier_c6_bw19v_selected_policy_commissioning_c2.ps1",
    "run_rapier_c6_bw19v_early_horizon_mechanism_development_ed1.ps1",
    "run_qsdk_r05_independent_morphology.ps1",
    "run_qsdk_independent_morphology_v2.ps1",
    "run_qsdk_r05c_independent_morphology.ps1",
    "experiment_result_integrity.ps1"
)) {
    $scriptPath = Join-Path $sdkRoot $scriptName
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "Balanced-wave pipeline script is missing: $scriptPath"
    }
    [void][scriptblock]::Create(
        (Get-Content -LiteralPath $scriptPath -Raw)
    )
}

& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_locomotion_operation_lock.ps1") `
    -ExpectProductionConformanceLockHeld
if ($LASTEXITCODE -ne 0) {
    throw "Locomotion operation-lock audit failed with exit code $LASTEXITCODE"
}
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot `
        "tests\test_locomotion_full_conformance_attestation_v1_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "Full-conformance attestation V1 closure audit failed with exit code " +
        $LASTEXITCODE
    )
}
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot `
        "tests\test_locomotion_full_conformance_attestation_v2_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "Full-conformance attestation V2 closure audit failed with exit code " +
        $LASTEXITCODE
    )
}
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_locomotion_full_conformance_attestation.ps1") `
    -Godot $Godot
if ($LASTEXITCODE -ne 0) {
    throw "Full-conformance attestation preflight failed with exit code $LASTEXITCODE"
}
# VH1 is closed and outcome-exposed. Its historical runner intentionally pins
# the exact experiment checkout, so replaying that prospective wrapper against
# a legitimately extended canonical-actuation source would make old evidence
# block current SDK evolution. The immutable closure audit below reconstructs
# the original source, report, and gate. Current core tests plus the live-v4
# adapter preflight immediately below exercise the maintained implementation.

# The live-v4 adapter gate binds the positive VH1 closure to the exact BW15F-B
# policy and BW19V scale-0.5 support composition, proves canonical-space
# ordering, configures zero-stiffness ForceBased velocity-only builder and
# mutable paths, and rejects the retained mixed-space formula. It must remain
# the first current integration gate and opens no physics world.
& (
    Join-Path $sdkRoot `
        "run_rapier_c6_velocity_only_live_integration_preflight.ps1"
)
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier v4 velocity-only live-integration preflight failed with " +
        "exit code $LASTEXITCODE"
    )
}

# EH1 is the first physical-development declaration that can exercise the exact
# live-v4 path. Normal conformance invokes only its full 944-step synthetic
# report and all declared canaries. The two physical worlds remain behind the
# supervisor's separate -RunPhysical switch and clean-pushed-source interlock.
& (
    Join-Path $sdkRoot `
        "run_rapier_c6_bw19v_velocity_only_early_horizon_eh1.ps1"
) -PreflightOnly
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier BW19V v4 EH1 complete zero-world preflight failed with " +
        "exit code $LASTEXITCODE"
    )
}

# ED1 is closed, so its prospective launcher must continue to reject any
# working tree whose pinned inputs differ from the frozen campaign. Active
# conformance exercises the current zero-world gate directly; the immutable
# preregistration, original preflight receipt, source, and physical artifacts
# are independently reconstructed by the closure audit below.
Push-Location -LiteralPath $sdkRoot
try {
    $ed1PreflightLines = @(
        & cargo run `
            --quiet `
            --package sporespore-rapier-adapter `
            --bin bw19v_early_horizon_development `
            --offline `
            -- `
            --preflight-only
    )
    if ($LASTEXITCODE -ne 0) {
        throw (
            "Rapier BW19V-ED1 current zero-world gate failed with exit code " +
            "$LASTEXITCODE"
        )
    }
} finally {
    Pop-Location
}
$ed1Preflight = (($ed1PreflightLines -join [Environment]::NewLine) |
    ConvertFrom-Json)
if (
    -not [bool]$ed1Preflight.ok -or
    -not [bool]$ed1Preflight.perfect_synthetic_two_arm_report_passed_complete_integrity_gate -or
    -not [bool]$ed1Preflight.synthetic_outcome_variants_all_integrity_valid -or
    [int]$ed1Preflight.synthetic_arm_count -ne 2 -or
    [int]$ed1Preflight.synthetic_trace_step_count -ne 944 -or
    [int]$ed1Preflight.synthetic_command_count_per_layer -ne 7552 -or
    -not [bool]$ed1Preflight.missing_trace_step_canary_rejected -or
    -not [bool]$ed1Preflight.reordered_semantic_step_canary_rejected -or
    -not [bool]$ed1Preflight.arm_a_nonzero_applied_residual_canary_rejected -or
    -not [bool]$ed1Preflight.arm_b_missing_nonzero_shadow_residual_canary_rejected -or
    -not [bool]$ed1Preflight.final_command_count_canary_rejected -or
    -not [bool]$ed1Preflight.claim_inflation_canary_rejected -or
    -not [bool]$ed1Preflight.serialization_round_trip_passed -or
    [int]$ed1Preflight.world_build_count -ne 0 -or
    [int]$ed1Preflight.scene_insertion_count -ne 0 -or
    [int]$ed1Preflight.physics_state_mutation_count -ne 0 -or
    [bool]$ed1Preflight.physical_acceptance_authority
) {
    throw "Rapier BW19V-ED1 current zero-world receipt is incomplete"
}

# C2 is closed and outcome-exposed. Its immutable closure audit below verifies
# the retained result, the frozen source snapshot, and immediate physical-rerun
# refusal. Do not re-run its prospective preflight against mutable checkout
# research documents; that would incorrectly make new research block an old,
# already-closed result without adding physical evidence.

# C1 is also closed and outcome-exposed. Its immutable closure audit below
# verifies the retained result, frozen source snapshot, and immediate physical
# rerun refusal. Keeping its prospective preflight in current conformance would
# make a historical result depend on mutable research-document bytes.

# The complete host-validation gate for the closed Rapier SPV1 identity then
# remains a zero-world regression check. This hashes the selected predecessor
# and all eight pinned host sources.
& (
    Join-Path $sdkRoot `
        "run_rapier_c6_force_based_selected_configuration_validation_spv1.ps1"
) -PreflightOnly
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier ForceBased SPV1 selected-configuration preflight failed " +
        "with exit code $LASTEXITCODE"
    )
}

# The complete trace, candidate, and selector gate for the closed Rapier SPD1
# development identity remains a zero-world regression check.
& (
    Join-Path $sdkRoot `
        "run_rapier_c6_force_based_solver_phase_development_spd1.ps1"
) -PreflightOnly
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier ForceBased SPD1 solver-phase preflight failed with " +
        "exit code $LASTEXITCODE"
    )
}

# The complete trace/window integrity gate for the closed Rapier CW1 identity
# remains a zero-world regression check.
& (Join-Path $sdkRoot "run_rapier_c6_force_based_convergence_window_cw1.ps1") `
    -PreflightOnly
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier ForceBased CW1 convergence-window preflight failed with " +
        "exit code $LASTEXITCODE"
    )
}

# LR1 remains closed negative. Its zero-world preflight is retained as a
# regression check only and cannot reopen that identity.
& (Join-Path $sdkRoot "run_rapier_c6_force_based_load_response_lr1.ps1") `
    -PreflightOnly
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier ForceBased LR1 load-response preflight failed with " +
        "exit code $LASTEXITCODE"
    )
}

# FB1 remains closed negative. Its zero-world preflight is retained as a
# regression check only and cannot reopen that identity.
& (Join-Path $sdkRoot "run_rapier_c6_force_based_host_characterization.ps1") `
    -PreflightOnly
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier ForceBased host-characterization preflight failed with " +
        "exit code $LASTEXITCODE"
    )
}

[void](Complete-SporeSporeConformanceStage -Session $conformanceObservation)
Start-SporeSporeConformanceStage `
    -Session $conformanceObservation `
    -StageId "portable_core_and_release_source"

Push-Location -LiteralPath $sdkRoot
try {
    & cargo fmt --all -- --check
    if ($LASTEXITCODE -ne 0) {
        throw "Rust SDK formatting check failed with exit code $LASTEXITCODE"
    }
    & cargo clippy --workspace --all-targets --offline -- -D warnings
    if ($LASTEXITCODE -ne 0) {
        throw "Rust SDK Clippy failed with exit code $LASTEXITCODE"
    }
    # Any earlier zero-world Godot launcher in this process tree can return a
    # moment before its runtime child releases the adapter DLL. Apply the same
    # bounded, non-destructive drain used around QSDK-R05 before the pipeline's
    # first adapter rebuild as well.
    Wait-ForSporeSporeHeadlessGodotDrain
    # Build the Godot cdylib before test and release artifacts. On Windows,
    # relinking this DLL immediately after Cargo test processes exit can race
    # a transient loader handle even when no Godot process remains.
    & cargo build -p sporespore-godot-adapter --offline
    if ($LASTEXITCODE -ne 0) {
        throw "Godot adapter debug build failed with exit code $LASTEXITCODE"
    }
    & cargo test --workspace --offline
    if ($LASTEXITCODE -ne 0) {
        throw "Rust SDK conformance failed with exit code $LASTEXITCODE"
    }
    & cargo build --workspace --release --offline
    if ($LASTEXITCODE -ne 0) {
        throw "Rust SDK release build failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

& (Join-Path $sdkRoot "run_adapter_authoring_conformance.ps1") -SkipBuild
if ($LASTEXITCODE -ne 0) {
    throw "Adapter-authoring conformance failed with exit code $LASTEXITCODE"
}

& (Join-Path $sdkRoot "run_versioning_conformance.ps1") -SkipBuild
if ($LASTEXITCODE -ne 0) {
    throw "Versioning conformance failed with exit code $LASTEXITCODE"
}

& (Join-Path $sdkRoot "run_adaptation_provider_conformance.ps1") -SkipBuild
if ($LASTEXITCODE -ne 0) {
    throw "Adaptation-provider conformance failed with exit code $LASTEXITCODE"
}

& (Join-Path $sdkRoot `
    "run_adaptation_experience_encyclopedia_conformance.ps1") -SkipBuild
if ($LASTEXITCODE -ne 0) {
    throw (
        "Adaptation-experience encyclopedia conformance failed with exit code " +
        $LASTEXITCODE
    )
}

& (Join-Path $repoRoot `
    "tests\test_adaptation_experience_encyclopedia_validation.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "Adaptation-experience retained evidence audit failed with exit code " +
        $LASTEXITCODE
    )
}

& (Join-Path $sdkRoot `
    "adaptation_provider\run_mujoco_warp_supported_subset_preflight.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "MuJoCo Warp supported-subset source preflight failed with exit code $LASTEXITCODE"
}
& (Join-Path $repoRoot "tests\test_mujoco_warp_supported_subset_validation.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "MuJoCo Warp supported-subset evidence audit failed with exit code $LASTEXITCODE"
}

& (Join-Path $sdkRoot `
    "run_mujoco_warp_equivalence_calibration_conformance.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "MuJoCo Warp equivalence-calibration protocol conformance failed " +
        "with exit code $LASTEXITCODE"
    )
}

& (Join-Path $repoRoot `
    "tests\test_mujoco_warp_equivalence_calibration_validation.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "MuJoCo Warp equivalence-calibration retained-evidence audit failed " +
        "with exit code $LASTEXITCODE"
    )
}

& (Join-Path $sdkRoot `
    "run_mujoco_warp_semantic_ceiling_readiness_conformance.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "MuJoCo Warp semantic-ceiling readiness conformance failed " +
        "with exit code $LASTEXITCODE"
    )
}

& (Join-Path $repoRoot `
    "tests\test_mujoco_warp_semantic_ceiling_readiness_validation.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "MuJoCo Warp semantic-ceiling retained-evidence audit failed " +
        "with exit code $LASTEXITCODE"
    )
}

& (Join-Path $sdkRoot "run_mujoco_warp_metric_semantics_conformance.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "MuJoCo Warp metric-semantics conformance failed with exit code " +
        $LASTEXITCODE
    )
}

& (Join-Path $repoRoot `
    "tests\test_mujoco_warp_metric_semantics_validation.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "MuJoCo Warp metric-semantics retained-evidence audit failed " +
        "with exit code $LASTEXITCODE"
    )
}

& (Join-Path $sdkRoot `
    "run_mujoco_warp_observable_projection_conformance.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "MuJoCo Warp observable-projection conformance failed with exit code " +
        $LASTEXITCODE
    )
}

& (Join-Path $repoRoot `
    "tests\test_mujoco_warp_observable_projection_validation.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "MuJoCo Warp observable-projection retained-evidence audit failed " +
        "with exit code $LASTEXITCODE"
    )
}

& (Join-Path $sdkRoot "run_heading_command_turning_conformance.ps1") -SkipBuild
if ($LASTEXITCODE -ne 0) {
    throw "Heading-command conformance failed with exit code $LASTEXITCODE"
}

& (Join-Path $repoRoot "tests\test_qsdk_r23d1_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D1 closure audit failed with exit code $LASTEXITCODE"
}

# R23D2 consumed its sole physical identity. Normal conformance must never
# rematerialize or rerun its prospective supervisor and workers. This closure
# audit instead rehashes all retained bytes/CAS objects, independently replays
# every terminal entry and aggregate, exercises negative controls, and proves
# the current supervisor refuses the old identity before reading attestation.
& (Join-Path $repoRoot "tests\test_qsdk_r23d2_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D2 closure audit failed with exit code $LASTEXITCODE"
}

# R23D3 consumed its one-shot identity after eight complete Stage A MuJoCo
# worlds. The retained Stage A evaluator validly selected NONE, then the
# supervisor failed while serializing an empty Stage B manifest. Canonical
# conformance now audits the immutable retained tree, independently recomputes
# all eight outcomes, and proves the supervisor and workers refuse the closed
# identity. It must not replay the prospective implementation/preflight route.
& (Join-Path $repoRoot "tests\test_qsdk_r23d3_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D3 closure audit failed with exit code $LASTEXITCODE"
}

# QSDK-R23D4 consumed its one-shot identity without opening a world. Canonical
# conformance now audits the immutable retained closure; it must never rerun or
# requalify the prospective R23D4 gates.
& (Join-Path $repoRoot "tests\test_qsdk_r23d4_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D4 closure audit failed with exit code $LASTEXITCODE"
}

# R23D5 consumed its one-shot identity after both Stage A MuJoCo worlds. Both
# workers completed the 2,992-step turning-controller horizon, then failed on
# restoration step zero because the imported BW15F-B restorer unconditionally
# required a policy-specific receipt member that BW5R-B does not emit. Stage B
# remained unopened. Canonical conformance now audits only the immutable
# retained closure and must never replay the prospective implementation route.
& (Join-Path $repoRoot "tests\test_qsdk_r23d5_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D5 closure audit failed with exit code $LASTEXITCODE"
}

# R23D6 consumed its one-shot identity after both MuJoCo Stage A cells. Both
# produced correctly signed yaw, but neither passed the frozen terminal-
# restoration gate: the front-left foot remained airborne through the complete
# acquisition window and passive stability was not retained. The valid NONE
# selection correctly kept Stage B closed. Canonical conformance must now audit
# only the immutable retained evidence and must never replay a prospective
# R23D6 implementation or worker route.
& (Join-Path $repoRoot "tests\test_qsdk_r23d6_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D6 closure audit failed with exit code $LASTEXITCODE"
}

# R23D7 consumed its sole identity before either MuJoCo world opened. Both
# workers correctly refused a stale internal dependency tuple, so canonical
# conformance must now audit only the immutable zero-world closure and must
# never replay a prospective R23D7 declaration, worker, or evaluator route.
& (Join-Path $repoRoot "tests\test_qsdk_r23d7_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D7 closure audit failed with exit code $LASTEXITCODE"
}

# R23D8 consumed its one-shot identity in two serialized MuJoCo Stage A
# worlds. Both reports were execution-valid but the frozen selector returned
# NONE because neither active neutral-stance hold met the complete contact
# contract. Canonical conformance must now audit only the immutable closure;
# replaying any prospective worker, evaluator, or authorization route is
# forbidden.
& (Join-Path $repoRoot "tests\test_qsdk_r23d8_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D8 closure audit failed with exit code $LASTEXITCODE"
}

# R23D9 stage zero and stage one are immutable at their clean pushed commits.
# Stage one qualified independent Python, Rust, and GDScript temporal mirrors
# with explicit before-model physical refusals. Once a later implementation
# layer exists, it must be exercised by its own live complete gate below this
# closure; the consumed live native-route audit must not be replayed.
& (Join-Path $repoRoot "tests\test_qsdk_r23d9_stage_one_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D9 stage-one closure audit failed with exit code $LASTEXITCODE"
}

# The production trace/evaluator layer is now immutable at its clean pushed
# stage-two commit. Canonical conformance audits that Git tree; a later live
# physical implementation must have its own complete gate below this closure.
& (Join-Path $repoRoot "tests\test_qsdk_r23d9_stage_two_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D9 stage-two closure failed with exit code $LASTEXITCODE"
}

# The first R23D9 exact-source attestation failed closed at Clippy before any
# R23D9 model, world, or identity, and its first production canary then exposed
# a zero-model receipt mismatch. Keep both incident boundaries executable.
& (Join-Path $repoRoot "tests\test_qsdk_r23d9_pre_attestation_clippy_incident.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D9 pre-attestation Clippy incident audit failed with exit code $LASTEXITCODE"
}
& (Join-Path $repoRoot "tests\test_qsdk_r23d9_authorization_canary_receipt_incident.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "QSDK-R23D9 authorization-canary receipt incident audit failed with " +
        "exit code $LASTEXITCODE"
    )
}
# R23D9 later consumed its one-shot identity in two execution-valid MuJoCo
# Stage A worlds. The cold evaluator retained a valid-none diagnostic payload
# but emitted a generic success marker while the supervisor required a stage-
# specific marker, so the immutable completion is infrastructure-invalid and
# Stage B remained unopened. Canonical conformance must audit the closure and
# must never replay its prospective implementation, worker, or evaluator gate.
& (Join-Path $repoRoot "tests\test_qsdk_r23d9_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D9 closure audit failed with exit code $LASTEXITCODE"
}

# R23D10 is the distinct quiescent-taper successor required by the consumed
# R23D9 closure. Preserve each already-pushed zero-world layer from its exact
# Git tree. Do not invoke the historical live stage-one or stage-two audits:
# each correctly rejects the later-stage paths that now exist.
& (Join-Path $repoRoot "tests\test_qsdk_r23d10_stage_zero_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D10 stage-zero closure audit failed with exit code $LASTEXITCODE"
}
& (Join-Path $repoRoot "tests\test_qsdk_r23d10_stage_one_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D10 stage-one closure audit failed with exit code $LASTEXITCODE"
}
& (Join-Path $repoRoot "tests\test_qsdk_r23d10_stage_two_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D10 stage-two closure audit failed with exit code $LASTEXITCODE"
}

# R23D10 later passed source-exact full-Godot attestation and all six
# production authorization canaries, then consumed its one-shot identity in
# two serialized MuJoCo Stage A worlds. Both execution-valid traces produced
# the required signed yaw. The positive arm passed the complete frozen outcome;
# the negative arm reached the 540-step active deadline without quiescence and
# lost contact during 97 passive steps. The authoritative selector returned
# NONE and correctly left all nine Stage B worlds unopened. Canonical
# conformance must now audit only this immutable valid finite negative and must
# never replay its prospective implementation, authorization, or worker route.
& (Join-Path $repoRoot "tests\test_qsdk_r23d10_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D10 closure audit failed with exit code $LASTEXITCODE"
}

# R23D11 was the prospective stability-assisted successor. Preserve all three
# already-pushed zero-world layers from their exact Git trees. Do not invoke
# the historical live native-route audit: it correctly rejects the later-stage
# worker paths and extended entrypoints that now exist.
& (Join-Path $repoRoot "tests\test_qsdk_r23d11_stage_zero_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D11 stage-zero closure audit failed with exit code $LASTEXITCODE"
}
& (Join-Path $repoRoot "tests\test_qsdk_r23d11_stage_one_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D11 stage-one closure audit failed with exit code $LASTEXITCODE"
}
& (Join-Path $repoRoot "tests\test_qsdk_r23d11_stage_two_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D11 stage-two closure audit failed with exit code $LASTEXITCODE"
}

# R23D11 passed source-exact full-Godot attestation, all six production
# authorization canaries, and its complete zero-world gate. Its one-shot
# supervisor then consumed both serialized MuJoCo Stage A worlds, but both
# complete 3,892-row traces were rejected by a frozen producer/validator
# diagnostic-semantics mismatch. The completion is infrastructure-invalid,
# Stage B remained unopened, and no scientific result exists. Canonical
# conformance must now audit only the immutable closure and must never replay
# the prospective implementation, authorization, or worker route.
& (Join-Path $repoRoot "tests\test_qsdk_r23d11_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D11 closure audit failed with exit code $LASTEXITCODE"
}

# R23D12 is a new implementation-recovery identity, not a replay or salvage of
# R23D11. Its stage-zero tree only separates planner availability from support-
# margin measurement availability. Audit the exact frozen Git blobs; do not run
# a live successor worker, evaluator, supervisor, model, or world.
& (Join-Path $repoRoot "tests\test_qsdk_r23d12_stage_zero_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D12 stage-zero closure audit failed with exit code $LASTEXITCODE"
}

# R23D12 stage one implements the frozen diagnostic semantics independently in
# MuJoCo/Python, Rapier/Rust, and Godot/Jolt/GDScript. Audit only the immutable
# Git tree: the later live gate is intentionally absent from canonical
# conformance once future evidence or physical layers extend the source family.
& (Join-Path $repoRoot "tests\test_qsdk_r23d12_stage_one_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D12 stage-one closure audit failed with exit code $LASTEXITCODE"
}

# R23D12 stage two freezes the production-shaped trace, independent diagnostic
# validation, CAS publication, and cold evaluator at exact commit 7d71a4d.
# Audit only that immutable Git tree. Later workers and supervisors must not
# cause canonical conformance to replay or reinterpret this evidence layer.
& (Join-Path $repoRoot "tests\test_qsdk_r23d12_stage_two_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D12 stage-two closure audit failed with exit code $LASTEXITCODE"
}

# R23D12 passed exact-source full-Godot attestation and all production
# authorization canaries, then consumed both serialized MuJoCo Stage A worlds.
# Both execution-valid traces walked forward and produced correctly signed yaw.
# The positive arm passed the full outcome; the negative arm never reached the
# frozen tight pose, entered the mandatory deadline handoff, and lost contact
# during 50 passive steps. The authoritative valid-NONE selector therefore kept
# all nine Stage B worlds closed. Canonical conformance must audit the retained
# immutable closure and must not replay the prospective workers, evaluator,
# authorization canaries, aggregate zero-world gate, or supervisor.
& (Join-Path $repoRoot "tests\test_qsdk_r23d12_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D12 closure audit failed with exit code $LASTEXITCODE"
}

# R23D13 passed source-exact full-Godot conformance and all six production
# authorization canaries, then consumed both serialized MuJoCo Stage A worlds.
# Both execution-valid traces walked forward and produced correctly signed yaw.
# The positive arm passed the full outcome. The negative residual-pose authority
# floor engaged on 133 rows but still missed the frozen tight pose, exhausted
# all 540 active steps, entered the mandatory deadline handoff, and lost contact
# during 43 passive steps. The valid-NONE selector kept all nine Stage B worlds
# closed. Canonical conformance must audit the retained immutable closure and
# must not replay the prospective workers, evaluator, authorization canaries,
# aggregate zero-world gate, or supervisor.
& (Join-Path $repoRoot "tests\test_qsdk_r23d13_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D13 closure audit failed with exit code $LASTEXITCODE"
}

# R23D14 consumed its direct nine-cell identity. All three MuJoCo reports are
# execution-valid outcome positives, while all three Godot/Jolt cells failed
# during terminal-summary construction and all three Rapier cells refused at
# the inherited stage-identity seam before world construction. The complete
# matrix is therefore execution-invalid: it is neither a scientific positive
# nor a scientific negative. Canonical conformance audits retained bytes and
# same-identity refusal; it must not replay the prospective gate or supervisor.
& (Join-Path $repoRoot "tests\test_qsdk_r23d14_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D14 closure audit failed with exit code $LASTEXITCODE"
}

# R23D15 preserves R23D14's scientific question, repairs only the two observed
# production-composition seams, and gives the successor a distinct trace,
# evaluator, and CAS identity. The stage-one closure verifies the clean-pushed
# source through pinned Git blobs and retains the zero-world claim boundary.
& (Join-Path $repoRoot "tests\test_qsdk_r23d15_stage_one_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D15 stage-one closure audit failed with exit code $LASTEXITCODE"
}

# The stage-two closure pins the clean-pushed dormant three-engine workers,
# serialized supervisor, dependency/marker contracts, and exact post-push
# zero-world gate. It grants no physical or turning result authority.
& (Join-Path $repoRoot "tests\test_qsdk_r23d15_stage_two_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D15 stage-two closure audit failed with exit code $LASTEXITCODE"
}

# R23D15 consumed its direct nine-cell identity. All three MuJoCo cells are
# execution-valid outcome positives and repeat R23D14's retained scalar
# displacement/yaw results. All three Godot/Jolt cells completed a world but
# returned incomplete traces; all three Rapier cells completed a world and a
# 3,952-row trace but failed at the child PowerShell CAS-publication boundary.
# The complete matrix is execution-invalid, neither a scientific positive nor
# a scientific negative. Canonical conformance audits the retained closure and
# same-identity refusal; it must not replay the prospective physical gate.
& (Join-Path $repoRoot "tests\test_qsdk_r23d15_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D15 closure audit failed with exit code $LASTEXITCODE"
}

# R23D16 consumed its direct nine-cell identity. Its three MuJoCo cells are
# execution-valid repeated positives. Godot/Jolt exposed the live terminal
# authority-input rejection; Rapier exposed extended-path root normalization
# drift in its child publisher. The complete matrix is execution-invalid.
# Canonical conformance audits the immutable closure and same-identity refusal.
& (Join-Path $repoRoot "tests\test_qsdk_r23d16_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D16 closure audit failed with exit code $LASTEXITCODE"
}

# R23D17 consumed its direct nine-cell identity. All workers completed and
# retained 3,952-row traces. Three Godot/Jolt entries are evaluator-invalid
# because their valid receipt byte lengths crossed the GDScript JSON boundary
# as reals. The three Rapier entries are valid outcome negatives; the three
# MuJoCo entries are repeated positives. The complete matrix remains invalid.
# Canonical conformance audits the immutable closure and same-identity refusal.
& (Join-Path $repoRoot "tests\test_qsdk_r23d17_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R23D17 closure audit failed with exit code $LASTEXITCODE"
}

& (Join-Path $sdkRoot "run_tier2_adaptation_architecture_conformance.ps1") -SkipBuild
if ($LASTEXITCODE -ne 0) {
    throw "Tier 2 adaptation architecture conformance failed with exit code $LASTEXITCODE"
}

& (Join-Path $repoRoot "tests\test_bw13p_r1_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "BW13P-R1 closure conformance failed with exit code $LASTEXITCODE"
}

& (Join-Path $repoRoot "tests\test_bw13p_r2_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "BW13P-R2 closure conformance failed with exit code $LASTEXITCODE"
}

& (Join-Path $repoRoot "tests\test_bw13p_r3_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "BW13P-R3 closure conformance failed with exit code $LASTEXITCODE"
}

& (Join-Path $repoRoot "tests\test_bw14v_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "BW14V closure conformance failed with exit code $LASTEXITCODE"
}

& (Join-Path $repoRoot "tests\test_bw14v_posthoc_diagnostic.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "BW14V post-hoc diagnostic conformance failed with exit code $LASTEXITCODE"
}

& (Join-Path $repoRoot "tests\test_bw15f_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "BW15F closure conformance failed with exit code $LASTEXITCODE"
}

& (Join-Path $repoRoot "tests\test_qsdk_r05c_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R05C closure conformance failed with exit code $LASTEXITCODE"
}

& (Join-Path $repoRoot "tests\test_qsdk_r05e_physical_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R05E physical closure conformance failed with exit code $LASTEXITCODE"
}

& (Join-Path $repoRoot "tests\test_bw16s_selector.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "BW16S selector conformance failed with exit code $LASTEXITCODE"
}

& (Join-Path $repoRoot "tests\test_bw16s_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "BW16S closure conformance failed with exit code $LASTEXITCODE"
}

& (Join-Path $repoRoot "tests\test_bw17p_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "BW17P closure conformance failed with exit code $LASTEXITCODE"
}

& (Join-Path $repoRoot "tests\test_bw18g_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "BW18G closure conformance failed with exit code $LASTEXITCODE"
}

& (Join-Path $repoRoot "tests\test_bw19v_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "BW19V closure conformance failed with exit code $LASTEXITCODE"
}

& (Join-Path $repoRoot "tests\test_bw19v_inferential_boundary.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "BW19V inferential-boundary conformance failed with exit code $LASTEXITCODE"
}

[void](Complete-SporeSporeConformanceStage -Session $conformanceObservation)
Start-SporeSporeConformanceStage `
    -Session $conformanceObservation `
    -StageId "campaign_closures_and_zero_world_gates"

# R23D61 is closed as a complete valid positive non-physical source-
# conformance publication. Its closure audit verifies the exact clean-pushed
# source tree, all four retained qualification observations, the integrated
# zero-world receipt, frozen Git-bound publication sources, and every nonclaim.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_qsdk_r23d61_publication_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "R23D61 publication closure audit failed with exit code $LASTEXITCODE"
}

# R23D62 is the active prospective finite turning decision. Its declaration
# and retained-evidence evaluator-v2 are zero-world only: the first audit
# freezes the fresh 3-engine x 3-arm question. The second preserves the
# synthetic-only v1 evaluator rejection, replays nine complete public-ID trace
# canaries and all evaluator/profile/transport/decision mutations, and checks
# the retained genuine-Godot trace cold-baseline record. Neither audit
# implements a native worker or authorizes a physical world.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_qsdk_r23d62_preregistration.ps1") `
    -SkipGodot
if ($LASTEXITCODE -ne 0) {
    throw "R23D62 preregistration audit failed with exit code $LASTEXITCODE"
}

& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_qsdk_r23d62_evaluator_v2.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "R23D62 evaluator-v2 audit failed with exit code $LASTEXITCODE"
}

# The Rapier/Parry dependency route resolves the same public profile into the
# real ForceBased motor mapping and compiles the exact force plan consumed by
# the production HostRobot constructor before its first native object. Fifteen
# route mutations and two support/refusal controls are rejected with zero
# models and worlds. This is a dependency route, not a worker or physical
# result.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_qsdk_r23d62_rapier_public_profile_physical_route.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "R23D62 Rapier public-profile production-route audit failed " +
        "with exit code $LASTEXITCODE"
    )
}

# The Godot/Jolt native dependency crosses its production
# route without constructing a world. The real GDExtension resolves the exact
# public profile, the eight unparented fixture hinges receive and read back the
# declared caps, one command reaches those same objects, five route and two
# normalization mutations fail before their first write, and evaluator-v2
# accepts the emitted resolution/mapping/physical-binding receipts. This is a
# dependency route only: it is not yet a native worker or physical authority.
if (-not $SkipGodot) {
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File (Join-Path $repoRoot "tests\test_qsdk_r23d62_godot_public_profile_physical_route.ps1") `
        -Godot $Godot
    if ($LASTEXITCODE -ne 0) {
        throw (
            "R23D62 Godot public-profile production-route audit failed " +
            "with exit code $LASTEXITCODE"
        )
    }

    # The first complete R23D62 native worker is now the Godot/Jolt worker.
    # Its receipt-bound supervisor preflights all three declared cells, rejects
    # eleven malformed or unauthorized invocations, and re-runs the production
    # public-profile route while proving zero models and worlds. Rapier/Parry,
    # MuJoCo, campaign supervision, and the complete zero-world gate remain
    # absent, so this grants no physical or turning authority.
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File (Join-Path $repoRoot "tests\test_qsdk_r23d62_godot_jolt_physical_worker.ps1") `
        -Godot $Godot
    if ($LASTEXITCODE -ne 0) {
        throw (
            "R23D62 Godot/Jolt native-worker zero-world audit failed " +
            "with exit code $LASTEXITCODE"
        )
    }
}

# R24D1 is the non-physical canonical prone-to-standing design gate. It binds
# the seven release-required gate families, BR13 reuse prohibitions, unset
# threshold/cohort blockers, future development and finite-decision question
# classes, and 38 claim-changing negative controls without building a world.
& (Join-Path $sdkRoot "run_qsdk_r24d1_zero_world_gate.ps1") `
    -CallerHoldsOperationLock
if ($LASTEXITCODE -ne 0) {
    throw "R24D1 canonical prone-to-standing design gate failed with exit code $LASTEXITCODE"
}

# BW20F consumed exactly one 13-world material-characterization attempt from
# clean pushed source. The closed-state audit hash-verifies the complete
# positive report and all retained artifacts, re-evaluates the receipt through
# the frozen 23-gate evaluator, preserves every non-claim, and proves that the
# physical supervisor refuses another world at the closure interlock.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_bw20f_material_characterization_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "BW20F material-characterization closure audit failed with exit code $LASTEXITCODE"
}

# THA2 executes the BW20F material-profile publication closure through the
# later BW27P root. BW20F characterization above remains direct because it is
# not a child of that publication closure.

# BW20F stage 3 consumed one complete 17-world attempt. The closed-state audit
# hash-verifies every retained artifact and cell log, reconstructs the 19/28
# rejection, preserves the two treatment lateral failures and the independent
# zero-scale control-contract defect, keeps every broader claim false, and
# proves the supervisor refuses a repeat launch before physics.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_bw20f_material_locomotion_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "BW20F material-locomotion closure audit failed with exit code $LASTEXITCODE"
}

# BW21L is closed invalid after one complete 53-world attempt. Its closure
# audit verifies every retained artifact, reconstructs the historical 73-gate
# evaluation, pins the inherited BW15F-only policy-identity defect, preserves
# the descriptive observations without selection authority, and proves the
# physical supervisor refuses a second invocation before opening a world.
& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_bw21l_lateral_development_closure.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "BW21L invalid closure audit failed with exit code $LASTEXITCODE"
}

# THA2 executes BW22M characterization/publication and BW24M/BW24P
# publication closures through the BW27P root below. That root fails if any
# child fails. The executable transitive-execution contract pins the ordered
# graph and retained terminal markers, so these are executions moved—not
# waived, cached, or inferred.

# THA2 canonical transitive root. This single invocation executes the exact
# BW27M -> BW24P -> BW24M -> BW22M -> BW20F closure lineage and preserves every
# child failure as a non-zero root failure.
# BW27P deterministically publishes the three exact BW27M adapter profiles
# without opening a world. Before its one-shot zero-world receipt exists,
# normal conformance proves the 38-profile/49-gate table, exact attempt parser,
# ten defect canaries, matching-attestation requirement, and shared-lock route.
# A complete closure permanently replaces this prospective audit.
$bw27pProfileClosure = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw27p_material_profile_publication_closure.json"
$bw27pProfileClosureAudit = Join-Path (
    $repoRoot
) "tests\test_bw27p_material_profile_publication_closure.ps1"
$bw27pProfileFreezeAudit = Join-Path (
    $repoRoot
) "tests\test_bw27p_material_profile_publication_freeze.ps1"
$bw27pProfileClosureExists = Test-Path `
    -LiteralPath $bw27pProfileClosure `
    -PathType Leaf
$bw27pProfileClosureAuditExists = Test-Path `
    -LiteralPath $bw27pProfileClosureAudit `
    -PathType Leaf
if ($bw27pProfileClosureExists -xor $bw27pProfileClosureAuditExists) {
    throw "BW27P material-profile closure manifest/audit pairing is incomplete"
}
if ($bw27pProfileClosureExists) {
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File $bw27pProfileClosureAudit `
        -Godot $Godot
    if ($LASTEXITCODE -ne 0) {
        throw (
            "BW27P material-profile closure audit failed with exit code " +
            "$LASTEXITCODE"
        )
    }
} else {
    if ($SkipGodot) {
        & pwsh `
            -NoLogo `
            -NoProfile `
            -File $bw27pProfileFreezeAudit `
            -SkipGodotExecution `
            -SkipSupervisorPreflight
    } else {
        & pwsh `
            -NoLogo `
            -NoProfile `
            -File $bw27pProfileFreezeAudit
    }
    if ($LASTEXITCODE -ne 0) {
        throw (
            "BW27P material-profile prospective freeze audit failed with " +
            "exit code $LASTEXITCODE"
        )
    }
}

# BW22L consumed its one permitted 28-world identity and closed infrastructure-
# invalid because the real final receipt composition did not match the synthetic
# surface. Closed conformance verifies the retained evidence, the post-hoc
# receipt-shape diagnostic, every negative claim, and same-identity rerun
# refusal. Before a closure exists, the older prospective declaration/freeze
# routes remain available for historical source checkouts only. No conformance
# route may invoke -RunPhysical.
$bw22lClosure = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw22l_lateral_development_closure.json"
$bw22lClosureAudit = Join-Path (
    $repoRoot
) "tests\test_bw22l_lateral_development_closure.ps1"
$bw22lFreezeAudit = Join-Path (
    $repoRoot
) "tests\test_bw22l_lateral_development_freeze.ps1"
$bw22lClosureExists = Test-Path -LiteralPath $bw22lClosure -PathType Leaf
$bw22lClosureAuditExists = Test-Path -LiteralPath $bw22lClosureAudit -PathType Leaf
if ($bw22lClosureExists -xor $bw22lClosureAuditExists) {
    throw "BW22L closure manifest/audit pairing is incomplete"
}
if ($bw22lClosureExists) {
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File $bw22lClosureAudit
    if ($LASTEXITCODE -ne 0) {
        throw (
            "BW22L immutable closure audit failed with exit code " +
            "$LASTEXITCODE"
        )
    }
} elseif (Test-Path -LiteralPath $bw22lFreezeAudit -PathType Leaf) {
    if ($SkipGodot) {
        & pwsh `
            -NoLogo `
            -NoProfile `
            -File $bw22lFreezeAudit `
            -SkipSupervisorPreflight
    } else {
        & pwsh `
            -NoLogo `
            -NoProfile `
            -File $bw22lFreezeAudit `
            -Godot $Godot
    }
    if ($LASTEXITCODE -ne 0) {
        throw (
            "BW22L stage-one freeze audit failed with exit code " +
            "$LASTEXITCODE"
        )
    }
} else {
    $bw22lDeclarationAudit = Join-Path (
        $repoRoot
    ) "tests\test_bw22l_lateral_development_declaration.ps1"
    if ($SkipGodot) {
        & pwsh `
            -NoLogo `
            -NoProfile `
            -File $bw22lDeclarationAudit `
            -SkipGodotPreflight
    } else {
        & pwsh `
            -NoLogo `
            -NoProfile `
            -File $bw22lDeclarationAudit
    }
    if ($LASTEXITCODE -ne 0) {
        throw (
            "BW22L stage-zero declaration audit failed with exit code " +
            "$LASTEXITCODE"
        )
    }
}

# Before physical execution, BW25Y's prospective audits bind its declaration,
# worker, evaluator, and recovery policy. After the identity is consumed, only
# the immutable closure audit is authoritative; rerunning prospective audits
# would incorrectly require the retained attempt to be absent.
$bw25yClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw25y_yaw_development_closure.json"
if (Test-Path -LiteralPath $bw25yClosurePath -PathType Leaf) {
    $bw25yClosureAudit = Join-Path (
        $repoRoot
    ) "tests\test_bw25y_yaw_development_closure.ps1"
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File $bw25yClosureAudit
    if ($LASTEXITCODE -ne 0) {
        throw (
            "BW25Y closure audit failed with exit code $LASTEXITCODE"
        )
    }
} else {
    $bw25yDeclarationAudit = Join-Path (
        $repoRoot
    ) "tests\test_bw25y_yaw_development_declaration.ps1"
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File $bw25yDeclarationAudit `
        -SkipPrerequisiteAudits `
        -SkipGodotPreflight
    if ($LASTEXITCODE -ne 0) {
        throw (
            "BW25Y stage-zero declaration audit failed with exit code " +
            "$LASTEXITCODE"
        )
    }

    $bw25yFreezeAudit = Join-Path (
        $repoRoot
    ) "tests\test_bw25y_yaw_development_freeze.ps1"
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File $bw25yFreezeAudit
    if ($LASTEXITCODE -ne 0) {
        throw (
            "BW25Y stage-one freeze audit failed with exit code " +
            "$LASTEXITCODE"
        )
    }
}

# BW28Y consumed its only physical identity with a complete, infrastructure-
# valid NONE selection. Once its closure exists, normal conformance verifies
# the immutable evidence and rerun interlock rather than re-entering the
# prospective authorization path or treating the opened seeds as fresh.
$bw28yClosure = Join-Path (
    $sdkRoot
) "balanced_wave_bw28y_yaw_development_closure.json"
$bw28yClosureAudit = Join-Path (
    $repoRoot
) "tests\test_bw28y_yaw_development_closure.ps1"
if (Test-Path -LiteralPath $bw28yClosure -PathType Leaf) {
    if (-not (Test-Path -LiteralPath $bw28yClosureAudit -PathType Leaf)) {
        throw "BW28Y yaw-development closure manifest/audit pairing is incomplete"
    }
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File $bw28yClosureAudit
    if ($LASTEXITCODE -ne 0) {
        throw (
            "BW28Y yaw-development closure audit failed with exit code " +
            "$LASTEXITCODE"
        )
    }
} else {
    # Before closure, BW28Y is the distinct fresh-material turning-development
    # successor to infrastructure-invalid BW25Y. It has no physical authority
    # until the declaration, actual-path gate, stage-one freeze, clean push,
    # and exact full-Godot V2 attestation all pass.
    $bw28yDeclarationAudit = Join-Path (
        $repoRoot
    ) "tests\test_bw28y_yaw_development_declaration.ps1"
    if (Test-Path -LiteralPath $bw28yDeclarationAudit -PathType Leaf) {
        & pwsh `
            -NoLogo `
            -NoProfile `
            -File $bw28yDeclarationAudit
        if ($LASTEXITCODE -ne 0) {
            throw (
                "BW28Y stage-zero declaration audit failed with exit code " +
                "$LASTEXITCODE"
            )
        }

        $bw28yZeroWorldGate = Join-Path (
            $sdkRoot
        ) "run_balanced_wave_bw28y_yaw_development_zero_world_gate.ps1"
        if ($SkipGodot) {
            & pwsh `
                -NoLogo `
                -NoProfile `
                -File $bw28yZeroWorldGate `
                -SkipGodotActualPath
        } else {
            & pwsh `
                -NoLogo `
                -NoProfile `
                -File $bw28yZeroWorldGate `
                -Godot $Godot
        }
        if ($LASTEXITCODE -ne 0) {
            throw (
                "BW28Y actual constructor/composer/evaluator preflight " +
                "failed with exit code $LASTEXITCODE"
            )
        }

        $bw28yFreeze = Join-Path (
            $sdkRoot
        ) "balanced_wave_bw28y_yaw_development_freeze.json"
        if (Test-Path -LiteralPath $bw28yFreeze -PathType Leaf) {
            & pwsh `
                -NoLogo `
                -NoProfile `
                -File (Join-Path $repoRoot "tests\test_bw28y_yaw_development_freeze.ps1")
            if ($LASTEXITCODE -ne 0) {
                throw (
                    "BW28Y stage-one freeze audit failed with exit code " +
                    "$LASTEXITCODE"
                )
            }
            if (-not $SkipGodot) {
                & pwsh `
                    -NoLogo `
                    -NoProfile `
                    -File (Join-Path $sdkRoot "run_balanced_wave_bw28y_yaw_development.ps1") `
                    -PreflightOnly `
                    -Godot $Godot
                if ($LASTEXITCODE -ne 0) {
                    throw (
                        "BW28Y complete stage-one zero-world authorization " +
                        "preflight failed with exit code $LASTEXITCODE"
                    )
                }
            }
        }
    }
}

# BW29N consumed its sole physical identity and closed implementation-invalid.
# Once the closure exists, conformance verifies the immutable retained result
# instead of exercising prospective authorization for a campaign that may not
# rerun.
$bw29nClosure = Join-Path (
    $sdkRoot
) "balanced_wave_bw29n_nuisance_transfer_closure.json"
if (Test-Path -LiteralPath $bw29nClosure -PathType Leaf) {
    $bw29nClosureAudit = Join-Path (
        $repoRoot
    ) "tests\test_bw29n_nuisance_transfer_closure.ps1"
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File $bw29nClosureAudit
    if ($LASTEXITCODE -ne 0) {
        throw (
            "BW29N immutable closure audit failed with exit code " +
            "$LASTEXITCODE"
        )
    }
} else {
    $bw29nDeclarationAudit = Join-Path (
        $repoRoot
    ) "tests\test_bw29n_nuisance_transfer_declaration.ps1"
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File $bw29nDeclarationAudit
    if ($LASTEXITCODE -ne 0) {
        throw (
            "BW29N stage-zero declaration audit failed with exit code " +
            "$LASTEXITCODE"
        )
    }

    $bw29nZeroWorldGate = Join-Path (
        $sdkRoot
    ) "run_balanced_wave_bw29n_nuisance_transfer_zero_world_gate.ps1"
    if ($SkipGodot) {
        & pwsh `
            -NoLogo `
            -NoProfile `
            -File $bw29nZeroWorldGate `
            -SkipGodotActualPath
    } else {
        & pwsh `
            -NoLogo `
            -NoProfile `
            -File $bw29nZeroWorldGate `
            -Godot $Godot
    }
    if ($LASTEXITCODE -ne 0) {
        throw (
            "BW29N complete zero-world authorization gate failed with exit code " +
            "$LASTEXITCODE"
        )
    }

    $bw29nFreezeAudit = Join-Path (
        $repoRoot
    ) "tests\test_bw29n_nuisance_transfer_freeze.ps1"
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File $bw29nFreezeAudit `
        -SkipSupervisorPreflight
    if ($LASTEXITCODE -ne 0) {
        throw (
            "BW29N stage-one freeze audit failed with exit code $LASTEXITCODE"
        )
    }
}

# BW30N also consumed its sole physical identity and closed
# implementation-invalid. Verify the immutable retained result once its
# closure exists; do not keep exercising a prospective physical entrypoint
# for a campaign that is forbidden to rerun.
$bw30nClosure = Join-Path $sdkRoot "balanced_wave_bw30n_recovery_closure.json"
if (Test-Path -LiteralPath $bw30nClosure -PathType Leaf) {
    $bw30nClosureAudit = Join-Path $repoRoot "tests\test_bw30n_recovery_closure.ps1"
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File $bw30nClosureAudit
    if ($LASTEXITCODE -ne 0) {
        throw "BW30N immutable closure audit failed with exit code $LASTEXITCODE"
    }
} else {
    $bw30nDeclarationAudit = Join-Path (
        $repoRoot
    ) "tests\test_bw30n_recovery_declaration.ps1"
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File $bw30nDeclarationAudit
    if ($LASTEXITCODE -ne 0) {
        throw (
            "BW30N stage-zero recovery declaration audit failed with exit code " +
            "$LASTEXITCODE"
        )
    }

    $bw30nZeroWorldGate = Join-Path (
        $sdkRoot
    ) "run_balanced_wave_bw30n_recovery_zero_world_gate.ps1"
    if ($SkipGodot) {
        & pwsh `
            -NoLogo `
            -NoProfile `
            -File $bw30nZeroWorldGate `
            -SkipGodotActualPath
    } else {
        & pwsh `
            -NoLogo `
            -NoProfile `
            -File $bw30nZeroWorldGate `
            -Godot $Godot
    }
    if ($LASTEXITCODE -ne 0) {
        throw (
            "BW30N complete zero-world implementation gate failed with exit code " +
            "$LASTEXITCODE"
        )
    }

    $bw30nFreezeAudit = Join-Path $repoRoot "tests\test_bw30n_recovery_freeze.ps1"
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File $bw30nFreezeAudit `
        -SkipSupervisorPreflight
    if ($LASTEXITCODE -ne 0) {
        throw "BW30N stage-one freeze audit failed with exit code $LASTEXITCODE"
    }
}

# Once BW31N has a closure, conformance cold-verifies the immutable retained
# physical result and its historical source bindings. It must not invoke the
# prospective declaration, zero-world, freeze, or one-shot paths as though the
# consumed identity were still open. Before closure, retain the complete
# prospective behavior.
$bw31nClosure = Join-Path $repoRoot `
    "sdk\balanced_wave_bw31n_authority_horizon_closure.json"
if (Test-Path -LiteralPath $bw31nClosure -PathType Leaf) {
    $bw31nClosureAudit = Join-Path $repoRoot `
        "tests\test_bw31n_authority_horizon_closure.ps1"
    & pwsh -NoLogo -NoProfile -File $bw31nClosureAudit
    if ($LASTEXITCODE -ne 0) {
        throw "BW31N immutable authority-horizon closure audit failed with exit code $LASTEXITCODE"
    }
} else {
    $bw31nDeclarationAudit = Join-Path (
        $repoRoot
    ) "tests\test_bw31n_authority_horizon_declaration.ps1"
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File $bw31nDeclarationAudit
    if ($LASTEXITCODE -ne 0) {
        throw (
            "BW31N stage-zero authority-horizon declaration audit failed with exit code " +
            "$LASTEXITCODE"
        )
    }

    $bw31nFreeze = Join-Path $repoRoot `
        "sdk\balanced_wave_bw31n_authority_horizon_freeze.json"
    if (Test-Path -LiteralPath $bw31nFreeze -PathType Leaf) {
        $bw31nZeroWorldGate = Join-Path $repoRoot `
            "sdk\run_balanced_wave_bw31n_authority_horizon_zero_world_gate.ps1"
        if ($SkipGodot) {
            & pwsh -NoLogo -NoProfile -File $bw31nZeroWorldGate -SkipGodotActualPath
        } else {
            & pwsh -NoLogo -NoProfile -File $bw31nZeroWorldGate -Godot $Godot
        }
        if ($LASTEXITCODE -ne 0) {
            throw "BW31N complete zero-world implementation gate failed with exit code $LASTEXITCODE"
        }

        $bw31nFreezeAudit = Join-Path $repoRoot `
            "tests\test_bw31n_authority_horizon_freeze.ps1"
        & pwsh -NoLogo -NoProfile -File $bw31nFreezeAudit -SkipSupervisorPreflight
        if ($LASTEXITCODE -ne 0) {
            throw "BW31N stage-one freeze audit failed with exit code $LASTEXITCODE"
        }
    }
}

# DRP1 is a distinct, repeatable noncampaign regression declaration. At this
# stage it opens no world. Its future physical route may run only inside full
# Godot conformance after a separate implementation freeze; it can never
# select a policy or grant a scientific/release claim.
$drp1DeclarationAudit = Join-Path $repoRoot `
    "tests\test_drp1_dynamic_receipt_projection_declaration.ps1"
& pwsh -NoLogo -NoProfile -File $drp1DeclarationAudit
if ($LASTEXITCODE -ne 0) {
    throw "DRP1 dynamic-receipt regression declaration audit failed with exit code $LASTEXITCODE"
}

$drp1Closure = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_closure.json"
if (Test-Path -LiteralPath $drp1Closure -PathType Leaf) {
    $drp1ClosureAudit = Join-Path $repoRoot `
        "tests\test_drp1_dynamic_receipt_projection_closure.ps1"
    & pwsh -NoLogo -NoProfile -File $drp1ClosureAudit
    if ($LASTEXITCODE -ne 0) {
        throw "DRP1 positive closure audit failed with exit code $LASTEXITCODE"
    }
} else {
$drp1Run1Result = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_run1_result.json"
if (Test-Path -LiteralPath $drp1Run1Result -PathType Leaf) {
    $drp1Run1Audit = Join-Path $repoRoot `
        "tests\test_drp1_dynamic_receipt_projection_run1_result.ps1"
    & pwsh -NoLogo -NoProfile -File $drp1Run1Audit
    if ($LASTEXITCODE -ne 0) {
        throw "DRP1 run-one invalid-result audit failed with exit code $LASTEXITCODE"
    }
}

$drp1Run2Result = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_run2_result.json"
if (Test-Path -LiteralPath $drp1Run2Result -PathType Leaf) {
    $drp1Run2Audit = Join-Path $repoRoot `
        "tests\test_drp1_dynamic_receipt_projection_run2_result.ps1"
    & pwsh -NoLogo -NoProfile -File $drp1Run2Audit
    if ($LASTEXITCODE -ne 0) {
        throw "DRP1 run-two invalid-result audit failed with exit code $LASTEXITCODE"
    }
}

$drp1FreezeV3 = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_freeze_v3.json"
$drp1FreezeV2 = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_freeze_v2.json"
$drp1FreezeV1 = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_freeze.json"
$drp1Freeze = if (Test-Path -LiteralPath $drp1FreezeV3 -PathType Leaf) {
    $drp1FreezeV3
} elseif (Test-Path -LiteralPath $drp1FreezeV2 -PathType Leaf) {
    $drp1FreezeV2
} elseif (Test-Path -LiteralPath $drp1FreezeV1 -PathType Leaf) {
    $drp1FreezeV1
} else {
    ""
}
if (-not [string]::IsNullOrWhiteSpace($drp1Freeze)) {
    $drp1ZeroWorldGate = Join-Path $repoRoot `
        "sdk\run_balanced_wave_dynamic_receipt_projection_drp1_zero_world_gate.ps1"
    if ($SkipGodot) {
        & pwsh -NoLogo -NoProfile -File $drp1ZeroWorldGate -SkipGodotActualPath
    } else {
        & pwsh -NoLogo -NoProfile -File $drp1ZeroWorldGate -Godot $Godot
    }
    if ($LASTEXITCODE -ne 0) {
        throw "DRP1 complete zero-world implementation gate failed with exit code $LASTEXITCODE"
    }

    $drp1FreezeAudit = if ($drp1Freeze -ceq $drp1FreezeV3) {
        Join-Path $repoRoot `
            "tests\test_drp1_dynamic_receipt_projection_freeze_v3.ps1"
    } elseif ($drp1Freeze -ceq $drp1FreezeV2) {
        Join-Path $repoRoot `
            "tests\test_drp1_dynamic_receipt_projection_freeze_v2.ps1"
    } else {
        Join-Path $repoRoot `
            "tests\test_drp1_dynamic_receipt_projection_freeze.ps1"
    }
    & pwsh -NoLogo -NoProfile -File $drp1FreezeAudit
    if ($LASTEXITCODE -ne 0) {
        throw "DRP1 stage-one freeze audit failed with exit code $LASTEXITCODE"
    }

    if (-not $SkipGodot) {
        $drp1Runner = Join-Path $repoRoot `
            "sdk\run_balanced_wave_dynamic_receipt_projection_drp1.ps1"
        $drp1Token = [Convert]::ToHexString(
            [Security.Cryptography.RandomNumberGenerator]::GetBytes(32)
        ).ToLowerInvariant()
        $priorDrp1Token = $env:SPORESPORE_DRP1_CONFORMANCE_TOKEN
        $priorDrp1FullConformance = $env:SPORESPORE_DRP1_FULL_GODOT_CONFORMANCE
        try {
            $env:SPORESPORE_DRP1_CONFORMANCE_TOKEN = $drp1Token
            $env:SPORESPORE_DRP1_FULL_GODOT_CONFORMANCE = "1"
            & pwsh `
                -NoLogo `
                -NoProfile `
                -File $drp1Runner `
                -RunRegression `
                -ConformanceToken $drp1Token `
                -Godot $Godot
            $drp1ExitCode = $LASTEXITCODE
            if ($drp1ExitCode -ne 0) {
                throw "DRP1 complete 24-world regression failed with exit code $drp1ExitCode"
            }
        } finally {
            if ($null -eq $priorDrp1Token) {
                Remove-Item Env:SPORESPORE_DRP1_CONFORMANCE_TOKEN -ErrorAction SilentlyContinue
            } else {
                $env:SPORESPORE_DRP1_CONFORMANCE_TOKEN = $priorDrp1Token
            }
            if ($null -eq $priorDrp1FullConformance) {
                Remove-Item Env:SPORESPORE_DRP1_FULL_GODOT_CONFORMANCE `
                    -ErrorAction SilentlyContinue
            } else {
                $env:SPORESPORE_DRP1_FULL_GODOT_CONFORMANCE = $priorDrp1FullConformance
            }
        }
    }
}
}

# BW32N is immutable after its one-shot identity is consumed. Before closure,
# conformance retains the prospective declaration and zero-world freeze gates.
# After closure, it cold-verifies the retained 24-world evidence, historical
# source, exact frozen evaluation, development-only selection, and sealed fresh
# seeds without reopening any BW32N preflight or execution path.
$bw32nClosure = Join-Path $repoRoot `
    "sdk\balanced_wave_bw32n_dynamic_receipt_recovery_closure.json"
if (Test-Path -LiteralPath $bw32nClosure -PathType Leaf) {
    $bw32nClosureAudit = Join-Path $repoRoot `
        "tests\test_bw32n_dynamic_receipt_recovery_closure.ps1"
    & pwsh -NoLogo -NoProfile -File $bw32nClosureAudit
    if ($LASTEXITCODE -ne 0) {
        throw "BW32N immutable dynamic-receipt closure audit failed with exit code $LASTEXITCODE"
    }
} else {
    $bw32nDeclarationAudit = Join-Path $repoRoot `
        "tests\test_bw32n_dynamic_receipt_recovery_declaration.ps1"
    & pwsh -NoLogo -NoProfile -File $bw32nDeclarationAudit
    if ($LASTEXITCODE -ne 0) {
        throw (
            "BW32N stage-zero dynamic-receipt recovery declaration audit failed " +
            "with exit code $LASTEXITCODE"
        )
    }
    $bw32nFreeze = Join-Path $repoRoot `
        "sdk\balanced_wave_bw32n_dynamic_receipt_recovery_freeze.json"
    if (Test-Path -LiteralPath $bw32nFreeze -PathType Leaf) {
        $bw32nZeroWorldGate = Join-Path $repoRoot `
            "sdk\run_balanced_wave_bw32n_dynamic_receipt_recovery_zero_world_gate.ps1"
        if ($SkipGodot) {
            & pwsh -NoLogo -NoProfile -File $bw32nZeroWorldGate -SkipGodotActualPath
        } else {
            & pwsh -NoLogo -NoProfile -File $bw32nZeroWorldGate -Godot $Godot
        }
        if ($LASTEXITCODE -ne 0) {
            throw (
                "BW32N complete zero-world dynamic-receipt recovery gate failed " +
                "with exit code $LASTEXITCODE"
            )
        }

        $bw32nFreezeAudit = Join-Path $repoRoot `
            "tests\test_bw32n_dynamic_receipt_recovery_freeze.ps1"
        & pwsh -NoLogo -NoProfile -File $bw32nFreezeAudit -SkipSupervisorPreflight
        if ($LASTEXITCODE -ne 0) {
            throw "BW32N stage-one freeze audit failed with exit code $LASTEXITCODE"
        }
    }
}

# BW33N consumed its one-shot identity with a complete, valid NONE selection.
# Once closure exists, ordinary conformance cold-verifies the retained physical
# matrix, CAS chain, historical source, frozen evaluator, sealed fresh seeds,
# and current rerun refusal. It must not reopen declaration or zero-world paths
# whose attempt-count premise is now permanently false.
$bw33nClosure = Join-Path $repoRoot `
    "sdk\balanced_wave_bw33n_rough_factorial_closure.json"
$bw33nClosureAudit = Join-Path $repoRoot `
    "tests\test_bw33n_rough_factorial_closure.ps1"
$bw33nClosureExists = Test-Path -LiteralPath $bw33nClosure -PathType Leaf
$bw33nClosureAuditExists = Test-Path -LiteralPath $bw33nClosureAudit -PathType Leaf
if ($bw33nClosureExists -ne $bw33nClosureAuditExists) {
    throw "BW33N closure manifest/audit pairing is incomplete"
}
if ($bw33nClosureExists) {
    & pwsh -NoLogo -NoProfile -File $bw33nClosureAudit
    if ($LASTEXITCODE -ne 0) {
        throw "BW33N immutable rough-factorial closure audit failed with exit code $LASTEXITCODE"
    }
} else {
    $bw33nDeclarationAudit = Join-Path $repoRoot `
        "tests\test_bw33n_rough_factorial_declaration.ps1"
    & pwsh -NoLogo -NoProfile -File $bw33nDeclarationAudit
    if ($LASTEXITCODE -ne 0) {
        throw "BW33N stage-zero rough-factorial declaration audit failed with exit code $LASTEXITCODE"
    }
    $bw33nFreeze = Join-Path $repoRoot `
        "sdk\balanced_wave_bw33n_rough_factorial_freeze.json"
    if (Test-Path -LiteralPath $bw33nFreeze -PathType Leaf) {
        $bw33nZeroWorldGate = Join-Path $repoRoot `
            "sdk\run_balanced_wave_bw33n_rough_factorial_zero_world_gate.ps1"
        if ($SkipGodot) {
            & pwsh -NoLogo -NoProfile -File $bw33nZeroWorldGate -SkipGodotActualPath
        } else {
            & pwsh -NoLogo -NoProfile -File $bw33nZeroWorldGate -Godot $Godot
        }
        if ($LASTEXITCODE -ne 0) {
            throw "BW33N complete zero-world gate failed with exit code $LASTEXITCODE"
        }
        $bw33nFreezeAudit = Join-Path $repoRoot `
            "tests\test_bw33n_rough_factorial_freeze.ps1"
        & pwsh -NoLogo -NoProfile -File $bw33nFreezeAudit -SkipSupervisorPreflight
        if ($LASTEXITCODE -ne 0) {
            throw "BW33N stage-one freeze audit failed with exit code $LASTEXITCODE"
        }
    }
}

# BW34Y consumed its one-shot identity with a complete, valid NONE selection.
# Closed-state conformance must verify retained bytes, historical source and
# attestation, the frozen evaluator, sealed fresh seeds, and rerun refusal. It
# must not invoke prospective gates whose zero-attempt premise is now false.
$bw34yClosure = Join-Path $repoRoot `
    "sdk\balanced_wave_bw34y_rough_yaw_rescue_closure.json"
$bw34yClosureAudit = Join-Path $repoRoot `
    "tests\test_bw34y_rough_yaw_rescue_closure.ps1"
$bw34yClosureExists = Test-Path -LiteralPath $bw34yClosure -PathType Leaf
$bw34yClosureAuditExists = Test-Path -LiteralPath $bw34yClosureAudit -PathType Leaf
if ($bw34yClosureExists -ne $bw34yClosureAuditExists) {
    throw "BW34Y closure manifest/audit pairing is incomplete"
}
if ($bw34yClosureExists) {
    & pwsh -NoLogo -NoProfile -File $bw34yClosureAudit
    if ($LASTEXITCODE -ne 0) {
        throw "BW34Y immutable rough yaw-rescue closure audit failed with exit code $LASTEXITCODE"
    }
} else {
    $bw34yDeclarationAudit = Join-Path $repoRoot `
        "tests\test_bw34y_rough_yaw_rescue_declaration.ps1"
    & pwsh -NoLogo -NoProfile -File $bw34yDeclarationAudit
    if ($LASTEXITCODE -ne 0) {
        throw "BW34Y stage-zero rough yaw-rescue declaration audit failed with exit code $LASTEXITCODE"
    }
    $bw34yFreeze = Join-Path $repoRoot `
        "sdk\balanced_wave_bw34y_rough_yaw_rescue_freeze.json"
    if (Test-Path -LiteralPath $bw34yFreeze -PathType Leaf) {
        $bw34yZeroWorldGate = Join-Path $repoRoot `
            "sdk\run_balanced_wave_bw34y_rough_yaw_rescue_zero_world_gate.ps1"
        if ($SkipGodot) {
            & pwsh -NoLogo -NoProfile -File $bw34yZeroWorldGate -SkipGodotActualPath
        } else {
            & pwsh -NoLogo -NoProfile -File $bw34yZeroWorldGate -Godot $Godot
        }
        if ($LASTEXITCODE -ne 0) {
            throw "BW34Y complete zero-world gate failed with exit code $LASTEXITCODE"
        }
        $bw34yFreezeAudit = Join-Path $repoRoot `
            "tests\test_bw34y_rough_yaw_rescue_freeze.ps1"
        & pwsh -NoLogo -NoProfile -File $bw34yFreezeAudit -SkipSupervisorPreflight
        if ($LASTEXITCODE -ne 0) {
            throw "BW34Y stage-one freeze audit failed with exit code $LASTEXITCODE"
        }
    }
}

& (
    Join-Path $repoRoot `
        "tests\test_rapier_c6_force_based_host_characterization_closure.ps1"
)
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier ForceBased host-characterization closure conformance failed " +
        "with exit code $LASTEXITCODE"
    )
}

& (
    Join-Path $repoRoot `
        "tests\test_rapier_c6_force_based_load_response_lr1_closure.ps1"
)
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier ForceBased LR1 load-response closure conformance failed " +
        "with exit code $LASTEXITCODE"
    )
}

& (
    Join-Path $repoRoot `
        "tests\test_rapier_c6_force_based_load_response_lr1_posthoc_diagnostic.ps1"
)
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier ForceBased LR1 post-hoc diagnostic conformance failed " +
        "with exit code $LASTEXITCODE"
    )
}

& (
    Join-Path $repoRoot `
        "tests\test_rapier_c6_force_based_convergence_window_cw1_closure.ps1"
)
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier ForceBased CW1 convergence-window closure failed " +
        "with exit code $LASTEXITCODE"
    )
}

& (
    Join-Path $repoRoot `
        "tests\test_rapier_c6_force_based_cw1_solver_phase_diagnostic.ps1"
)
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier ForceBased CW1 solver-phase diagnostic failed " +
        "with exit code $LASTEXITCODE"
    )
}

& (
    Join-Path $repoRoot `
        "tests\test_rapier_c6_force_based_solver_phase_development_spd1_closure.ps1"
)
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier ForceBased SPD1 solver-phase development closure failed " +
        "with exit code $LASTEXITCODE"
    )
}

& (
    Join-Path $repoRoot `
        "tests\test_rapier_c6_force_based_selected_configuration_validation_spv1_closure.ps1"
)
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier ForceBased SPV1 selected-configuration validation closure " +
        "failed with exit code $LASTEXITCODE"
    )
}

& (
    Join-Path $repoRoot `
        "tests\test_rapier_c6_force_based_velocity_only_host_characterization_vh1_closure.ps1"
)
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier ForceBased VH1 velocity-only host-characterization closure " +
        "failed with exit code $LASTEXITCODE"
    )
}

& (
    Join-Path $repoRoot `
        "tests\test_rapier_c6_force_based_active_configuration.ps1"
)
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier ForceBased active-configuration audit failed with exit code " +
        "$LASTEXITCODE"
    )
}

& (
    Join-Path $repoRoot `
        "tests\test_rapier_c6_velocity_only_active_configuration_v2.ps1"
)
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier v4 velocity-only active-configuration audit failed with " +
        "exit code $LASTEXITCODE"
    )
}

& (
    Join-Path $repoRoot `
        "tests\test_rapier_c6_bw19v_velocity_only_early_horizon_eh1_closure.ps1"
)
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier BW19V v4 EH1 immutable closure audit failed with exit code " +
        "$LASTEXITCODE"
    )
}

# LC1 is now closed after its one permitted physical world. Its closure audit
# hash-verifies the immutable 2,992-step report and receipts, checks the exact
# physical Git blobs, reruns the corrected post-hoc evaluator, and preserves
# both the invalid primary result and the remaining terminal-stance failure.
# It also proves the supervisor rejects another world before mutable inputs.
& (
    Join-Path $repoRoot `
        "tests\test_rapier_c6_bw19v_velocity_only_long_horizon_lc1_closure.ps1"
)
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier BW19V v4 LC1 immutable closure audit failed with exit code " +
        "$LASTEXITCODE"
    )
}

# TS1 consumed its one permitted world from clean pushed freeze source. Its
# closure audit hash-verifies the complete valid-negative report and receipts,
# reruns the frozen evaluator and deterministic post-hoc mechanism diagnostic,
# and proves the physical supervisor rejects another world before mutable
# checkout inputs. The sole retained failure is terminal four-contact stance.
& (
    Join-Path $repoRoot `
        "tests\test_rapier_c6_bw19v_velocity_only_terminal_stance_ts1_closure.ps1"
)
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier BW19V v4 TS1 immutable closure audit failed with exit code " +
        "$LASTEXITCODE"
    )
}

& (
    Join-Path $repoRoot `
        "tests\test_rapier_c6_bw19v_selected_policy_commissioning_c1_closure.ps1"
)
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier BW19V-C1 retained negative closure audit failed with exit code " +
        "$LASTEXITCODE"
    )
}

& (
    Join-Path $repoRoot `
        "tests\test_rapier_c6_bw19v_selected_policy_commissioning_c2_closure.ps1"
)
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier BW19V-C2 closure audit failed with exit code " +
        "$LASTEXITCODE"
    )
}

& (
    Join-Path $repoRoot `
        "tests\test_rapier_c6_bw19v_early_horizon_mechanism_development_ed1_closure.ps1"
)
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier BW19V-ED1 closure audit failed with exit code " +
        "$LASTEXITCODE"
    )
}

# ASD1 opens no world. It must continue to reconstruct the cross-host
# actuation-semantics defect from the frozen source, installed Rapier source,
# and retained ED1 trace without inflating that diagnosis into causation or C6.
& (
    Join-Path $repoRoot `
        "tests\test_rapier_c6_bw19v_actuation_semantics_diagnostic.ps1"
)
if ($LASTEXITCODE -ne 0) {
    throw (
        "Rapier BW19V actuation-semantics diagnostic audit failed with exit " +
        "code $LASTEXITCODE"
    )
}

[void](Complete-SporeSporeConformanceStage -Session $conformanceObservation)
Start-SporeSporeConformanceStage `
    -Session $conformanceObservation `
    -StageId "selectors_and_integrity"

# Semantics v4 is a zero-world successor layered over the immutable legacy
# actuation frame. It must retain bit-exact Godot host commands, compose the
# Rapier base and residual in canonical space, forbid a second native position
# loop, and reject live/physical authority inflation before any new world.
& (Join-Path $repoRoot "tests\test_actuation_semantics_v4.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "Canonical-velocity actuation semantics v4 audit failed with exit " +
        "code $LASTEXITCODE"
    )
}

& (Join-Path $repoRoot "tests\test_experiment_result_integrity_preflight.ps1")
if ($LASTEXITCODE -ne 0) {
    throw (
        "Experiment result integrity preflight failed with exit code " +
        "$LASTEXITCODE"
    )
}

& (Join-Path $repoRoot "tests\test_bw13p_r2_selector.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "BW13P-R2 selector conformance failed with exit code $LASTEXITCODE"
}

& (Join-Path $repoRoot "tests\test_bw13p_r3_selector.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "BW13P-R3 selector conformance failed with exit code $LASTEXITCODE"
}

& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_bw14v_selector.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "BW14V selector conformance failed with exit code $LASTEXITCODE"
}

& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_bw15f_selector.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "BW15F selector conformance failed with exit code $LASTEXITCODE"
}

& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_bw17p_selector.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "BW17P selector conformance failed with exit code $LASTEXITCODE"
}

& pwsh `
    -NoLogo `
    -NoProfile `
    -File (Join-Path $repoRoot "tests\test_bw19v_selector.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "BW19V selector conformance failed with exit code $LASTEXITCODE"
}

[void](Complete-SporeSporeConformanceStage -Session $conformanceObservation)
Start-SporeSporeConformanceStage `
    -Session $conformanceObservation `
    -StageId "godot_runtime_regression"

& (Join-Path $repoRoot "tests\test_qsdk_r24d4_one_hinge_telemetry_freeze.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "R24D4 one-hinge telemetry freeze audit failed with exit code $LASTEXITCODE"
}
& (Join-Path $repoRoot (
    "tests\test_qsdk_r24d4_one_hinge_telemetry_" +
    "zero_world_failure_closure.ps1"
))
if ($LASTEXITCODE -ne 0) {
    throw (
        "R24D4 zero-world failure closure audit failed with exit code " +
        "$LASTEXITCODE"
    )
}
& (Join-Path $repoRoot "tests\test_qsdk_r24d5_one_hinge_telemetry_freeze.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "R24D5 one-hinge telemetry freeze audit failed with exit code $LASTEXITCODE"
}
& (Join-Path $repoRoot (
    "tests\test_qsdk_r24d5_one_hinge_telemetry_" +
    "physical_failure_closure.ps1"
))
if ($LASTEXITCODE -ne 0) {
    throw (
        "R24D5 physical failure closure audit failed with exit code " +
        "$LASTEXITCODE"
    )
}
& (Join-Path $repoRoot "tests\test_qsdk_r24d6_one_hinge_telemetry_freeze.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "R24D6 one-hinge telemetry freeze audit failed with exit code $LASTEXITCODE"
}
& (Join-Path $repoRoot "tests\test_qsdk_r24d3_godot_jolt_motor_telemetry_source.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "R24D3 Godot/Jolt motor-telemetry source audit failed with exit code $LASTEXITCODE"
}
& (Join-Path $repoRoot (
    "tests\" +
    "test_qsdk_r24d3_godot_jolt_motor_telemetry_cold_qualification_adoption.ps1"
))
if ($LASTEXITCODE -ne 0) {
    throw "R24D3 artifact-complete cold-qualification adoption audit failed with exit code $LASTEXITCODE"
}
& (Join-Path $repoRoot (
    "tests\" +
    "test_qsdk_r24d3_godot_jolt_motor_telemetry_post_adoption_" +
    "full_cold_conformance_qualification.ps1"
))
if ($LASTEXITCODE -ne 0) {
    throw (
        "R24D3 post-adoption full-cold conformance qualification audit " +
        "failed with exit code $LASTEXITCODE"
    )
}

if (-not $SkipGodot) {
    $godotPath = [System.IO.Path]::GetFullPath($Godot)
    if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
        throw "Godot executable not found: $godotPath"
    }
    & (Join-Path $sdkRoot "run_qsdk_r23d61_zero_world_gate.ps1") `
        -SkipBuild `
        -Godot $godotPath `
        -CallerHoldsOperationLock
    if ($LASTEXITCODE -ne 0) {
        throw (
            "R23D61 selected actuator-profile publication gate failed " +
            "with exit code $LASTEXITCODE"
        )
    }
    & (Join-Path $sdkRoot "run_qsdk_r24d2_zero_world_gate.ps1") `
        -Godot $godotPath `
        -CallerHoldsOperationLock
    if ($LASTEXITCODE -ne 0) {
        throw (
            "R24D2 portable recovery semantics gate failed " +
            "with exit code $LASTEXITCODE"
        )
    }
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_godot_jolt_transport_execution_contract.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "Godot/Jolt transport execution runtime contract failed with exit code $LASTEXITCODE"
    }
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_godot_jolt_persistent_session_contract.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "Godot/Jolt persistent-session runtime contract failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $repoRoot "tests\test_godot_actuator_phase_observation_contract.ps1")
    if ($LASTEXITCODE -ne 0) {
        throw "Godot/Jolt actuator-phase source contract failed with exit code $LASTEXITCODE"
    }
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_godot_actuator_phase_observation.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "Godot/Jolt actuator-phase observation contract failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $repoRoot "tests\test_qsdk_r23d55_live_fixture_actuator_cap_contract.ps1")
    if ($LASTEXITCODE -ne 0) {
        throw "R23D55 live-fixture actuator-cap source contract failed with exit code $LASTEXITCODE"
    }
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_qsdk_r23d55_godot_live_fixture_actuator_cap_conformance.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "R23D55 live-fixture actuator-cap runtime contract failed with exit code $LASTEXITCODE"
    }
    # BW26I is closed infrastructure-invalid. Its published test crossed the
    # actual constructor route but accidentally manufactured BW25Y-B selection
    # authority inside an outward no-selection result. Normal conformance must
    # reproduce that contradiction through the immutable closure, not repeat
    # the former pass marker as current commissioning authority.
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File (Join-Path $repoRoot "tests\test_bw26i_actual_worker_receipt_route_closure.ps1") `
        -Godot $godotPath
    if ($LASTEXITCODE -ne 0) {
        throw "BW26I actual worker-receipt route closure failed with exit code $LASTEXITCODE"
    }
    # BW26J is the distinct correction, not a mutation of closed BW26I. Its
    # neutral fixtures must make the exact production evaluator select NONE;
    # a canary that makes BW25Y-B selectable must be rejected by the outer
    # authority firewall. This path constructs zero physics worlds.
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File (Join-Path $repoRoot "tests\test_bw26j_actual_worker_receipt_authority.ps1") `
        -Godot $godotPath
    if ($LASTEXITCODE -ne 0) {
        throw "BW26J actual worker-receipt authority commissioning failed with exit code $LASTEXITCODE"
    }
    if (-not (Test-Path -LiteralPath $bw25yClosurePath -PathType Leaf)) {
        & pwsh `
            -NoLogo `
            -NoProfile `
            -File (Join-Path $sdkRoot "run_balanced_wave_bw25y_yaw_development_declaration_preflight.ps1") `
            -Godot $godotPath
        if ($LASTEXITCODE -ne 0) {
            throw "BW25Y zero-world declaration preflight failed with exit code $LASTEXITCODE"
        }
        & pwsh `
            -NoLogo `
            -NoProfile `
            -File (Join-Path $sdkRoot "run_balanced_wave_bw25y_yaw_development.ps1") `
            -PreflightOnly `
            -Godot $godotPath
        if ($LASTEXITCODE -ne 0) {
            throw "BW25Y complete stage-one zero-world preflight failed with exit code $LASTEXITCODE"
        }
    }
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_candidate35_golden_vectors.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "GDScript SDK oracle failed with exit code $LASTEXITCODE"
    }
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_balanced_wave_profile_oracle.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "GDScript balanced-wave profile oracle failed with exit code $LASTEXITCODE"
    }
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_stability_v2_golden_vectors.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "GDScript stability v2 oracle failed with exit code $LASTEXITCODE"
    }
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_stability_v3_subset_map.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "GDScript stability v3 subset-map oracle failed with exit code $LASTEXITCODE"
    }
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_scheduled_load_transfer_v3_authority_contract.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "Scheduled-load-transfer v3 authority contract failed with exit code $LASTEXITCODE"
    }
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_full_integrity_gate_satisfiability.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "Policy-semantic full-integrity preflight failed with exit code $LASTEXITCODE"
    }
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_policy_relative_execution_integrity.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "Policy-relative physical-receipt parity failed with exit code $LASTEXITCODE"
    }
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File (
            Join-Path $sdkRoot `
                "run_policy_aware_physical_receipt_composition_preflight.ps1"
        ) `
        -Godot $godotPath
    if ($LASTEXITCODE -ne 0) {
        throw "Composed physical-receipt parity failed with exit code $LASTEXITCODE"
    }
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_qsdk_r05_independent_morphology.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "QSDK-R05 frozen morphology contract failed with exit code $LASTEXITCODE"
    }
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_balanced_wave_bw14v_authority_contract.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "BW14V no-world authority contract failed with exit code $LASTEXITCODE"
    }
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_balanced_wave_bw15f_authority_contract.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "BW15F no-world authority contract failed with exit code $LASTEXITCODE"
    }
    # BW14V and BW15F are closed physical families. Their immutable reports,
    # source commits, and closure receipts are audited above. Keep only these
    # lightweight no-world authority contracts in active conformance.
    # The Windows console launcher can return a moment before its runtime child
    # releases the Godot adapter DLL. Drain only transient SporeSpore headless
    # processes before the QSDK runners rebuild that shared target; never kill
    # a process or include the persistent editor/LSP instance.
    Wait-ForSporeSporeHeadlessGodotDrain
    & (Join-Path $repoRoot "sdk\run_qsdk_r05a_selected_policy_authority.ps1") `
        -Godot $godotPath `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "QSDK-R05A selected-policy authority preflight failed with exit code $LASTEXITCODE"
    }
    Wait-ForSporeSporeHeadlessGodotDrain
    & (Join-Path $repoRoot "sdk\run_qsdk_r05b_independent_morphology.ps1") `
        -Godot $godotPath `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "QSDK-R05B fresh-morphology preflight failed with exit code $LASTEXITCODE"
    }
    Wait-ForSporeSporeHeadlessGodotDrain
    # R05C, BW16S, and BW17P are likewise closed physical families. Their
    # immutable reports, source commits, and closure receipts are audited
    # above; active conformance must not invoke a historical launcher as if
    # its old source were still a current launch target.
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_balanced_wave_bw17p_authority_contract.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "BW17P no-world authority contract failed with exit code $LASTEXITCODE"
    }
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_balanced_wave_bw18g_scale_contract.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "BW18G no-world scale contract failed with exit code $LASTEXITCODE"
    }
    # BW18G is also closed. Its four physical reports and its intentionally
    # failed selector are audited above. Keep only the portable v3 scale
    # contract active; do not present the historical launcher or its generic
    # synthetic selector as a current launch target.
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_balanced_wave_bw19v_generator_contract.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "BW19V zero-world generator contract failed with exit code $LASTEXITCODE"
    }
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_balanced_wave_bw19v_scale_contract.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "BW19V no-world scale contract failed with exit code $LASTEXITCODE"
    }
    # BW19V is a closed physical family. Its exact preregistration, retained
    # preflights, 72 physical reports, one-shot selector, source commit, and
    # research sources are audited by test_bw19v_closure.ps1 above. Keep the
    # generator and portable scale contracts active, but do not invoke the
    # historical physical launcher as if its frozen source receipt (including
    # the then-current living research ledger) were a present launch target.
    # BW13P-R1, R2, and R3 are closed physical families. Their source and
    # retained receipts are audited above; active conformance must not invoke
    # any historical launcher or present one as a current launch target.
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_godot_adapter_c0_c1.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "Godot native-adapter conformance failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $sdkRoot "run_balanced_wave_bw3_material_characterization.ps1") `
        -Godot $godotPath `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW3 material preflight failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $sdkRoot "run_balanced_wave_bw3r_material_characterization.ps1") `
        -Godot $godotPath `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW3R material preflight failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $sdkRoot "run_balanced_wave_bw4_material_characterization.ps1") `
        -Godot $godotPath `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW4 material preflight failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $sdkRoot "run_balanced_wave_bw5v_material_characterization.ps1") `
        -Godot $godotPath `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW5V material preflight failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $sdkRoot "run_balanced_wave_bw5c_material_characterization.ps1") `
        -Godot $godotPath `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW5C material preflight failed with exit code $LASTEXITCODE"
    }
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File (
            Join-Path $sdkRoot `
                "run_balanced_wave_bw20f_material_characterization.ps1"
        ) `
        -Godot $godotPath `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW20F zero-world material preflight failed with exit code $LASTEXITCODE"
    }
    # BW20F profile publication is closed. Its closed-state audit above checks
    # the immutable source-commit blobs, retained zero-world receipt, and
    # rerun interlock. Do not invoke the prospective publication supervisor as
    # a rolling current-source preflight: that supervisor intentionally pins
    # the publication-era working-tree bytes and must reject later successor
    # edits rather than reinterpret the closed campaign.
    & (Join-Path $sdkRoot "run_balanced_wave_bw3_validation.ps1") `
        -Godot $godotPath `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW3 validation preflight failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $sdkRoot "run_balanced_wave_bw3r_validation.ps1") `
        -Godot $godotPath `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW3R validation preflight failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $sdkRoot "run_balanced_wave_bw5v_validation.ps1") `
        -Godot $godotPath `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW5V validation preflight failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $sdkRoot "run_balanced_wave_bw4_validation.ps1") `
        -Godot $godotPath `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW4 validation preflight failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $sdkRoot "run_balanced_wave_bw5c_validation.ps1") `
        -Godot $godotPath `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW5C validation preflight failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $sdkRoot "run_balanced_wave_bw6n_validation.ps1") `
        -Godot $godotPath `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW6N validation preflight failed with exit code $LASTEXITCODE"
    }
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_environment_challenge_contract.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "Environment challenge contract failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $sdkRoot "run_balanced_wave_bw4_validation.ps1") `
        -Godot $godotPath `
        -Candidate BW4R-A `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW4R opened-BW4 replay preflight failed with exit code $LASTEXITCODE"
    }
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_balanced_wave_bw2r_authority_contract.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "BW2R no-world authority contract failed with exit code $LASTEXITCODE"
    }
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_balanced_wave_bw4r_authority_contract.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "BW4R no-world authority contract failed with exit code $LASTEXITCODE"
    }
    & $godotPath `
        --headless `
        --path $repoRoot `
        --script "res://tests/test_sdk_balanced_wave_bw5r_authority_contract.gd"
    if ($LASTEXITCODE -ne 0) {
        throw "BW5R no-world authority contract failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $sdkRoot "run_balanced_wave_bw2_material_matrix.ps1") `
        -Godot $godotPath `
        -Candidate BW2R-A `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW2R material preflight failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $sdkRoot "run_balanced_wave_bw2_counterexamples.ps1") `
        -Godot $godotPath `
        -Candidate BW2R-A `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW2R counterexample preflight failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $sdkRoot "run_balanced_wave_bw3_validation.ps1") `
        -Godot $godotPath `
        -Candidate BW2R-A `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW2R opened-BW3 replay preflight failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $sdkRoot "run_balanced_wave_bw2_material_matrix.ps1") `
        -Godot $godotPath `
        -Candidate BW4R-A `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW4R opened-BW2 material preflight failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $sdkRoot "run_balanced_wave_bw2_counterexamples.ps1") `
        -Godot $godotPath `
        -Candidate BW4R-A `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW4R opened-counterexample preflight failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $sdkRoot "run_balanced_wave_bw3_validation.ps1") `
        -Godot $godotPath `
        -Campaign BW3R `
        -Candidate BW4R-A `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW4R opened-BW3R replay preflight failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $sdkRoot "run_balanced_wave_bw2_material_matrix.ps1") `
        -Godot $godotPath `
        -Candidate BW5R-A `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW5R opened-BW2 material preflight failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $sdkRoot "run_balanced_wave_bw2_counterexamples.ps1") `
        -Godot $godotPath `
        -Candidate BW5R-A `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW5R opened-counterexample preflight failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $sdkRoot "run_balanced_wave_bw3_validation.ps1") `
        -Godot $godotPath `
        -Campaign BW3R `
        -Candidate BW5R-A `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW5R opened-BW3R replay preflight failed with exit code $LASTEXITCODE"
    }
    & (Join-Path $sdkRoot "run_balanced_wave_bw4_validation.ps1") `
        -Godot $godotPath `
        -Candidate BW5R-A `
        -PreflightOnly
    if ($LASTEXITCODE -ne 0) {
        throw "BW5R opened-BW4 replay preflight failed with exit code $LASTEXITCODE"
    }
} else {
    & (Join-Path $sdkRoot "run_qsdk_r23d61_zero_world_gate.ps1") `
        -SkipBuild `
        -SkipGodot `
        -CallerHoldsOperationLock
    if ($LASTEXITCODE -ne 0) {
        throw (
            "R23D61 selected actuator-profile non-Godot gate failed " +
            "with exit code $LASTEXITCODE"
        )
    }
}

if ($SkipGodot) {
    [void](Complete-SporeSporeConformanceStage `
        -Session $conformanceObservation `
        -Status skipped)
} else {
    [void](Complete-SporeSporeConformanceStage -Session $conformanceObservation)
}
Start-SporeSporeConformanceStage `
    -Session $conformanceObservation `
    -StageId "language_bindings_and_developer_experience"

$pythonTest = Join-Path $sdkRoot "python\test_ctypes_smoke.py"
Push-Location -LiteralPath (Split-Path -Parent $pythonTest)
try {
    & python -m unittest -v (Split-Path -Leaf $pythonTest)
    if ($LASTEXITCODE -ne 0) {
        throw "Python C-ABI smoke tests failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

& (Join-Path $sdkRoot "run_portable_api_conformance.ps1") -SkipBuild
if ($LASTEXITCODE -ne 0) {
    throw "Portable API conformance failed with exit code $LASTEXITCODE"
}

# The Godot/Jolt SDK1 envelope is a zero-world composition of immutable finite
# evidence. Audit its exact source bindings, narrow union rule, preserved C6
# negatives, mutation refusals, and live ledger adoption before release checks.
& python (Join-Path $sdkRoot `
    "conformance\qsdk_r13_godot_jolt_sdk1_envelope_decision.py")
if ($LASTEXITCODE -ne 0) {
    throw "QSDK-R13 Godot/Jolt SDK1 envelope audit failed with exit code $LASTEXITCODE"
}

# Release claims remain fail closed even when source, ABI, and language-binding
# tests pass. This gate compiles the current support evidence, exercises forged
# authorization canaries, and proves packaging/publication remain blocked.
& (Join-Path $sdkRoot "test_quadruped_sdk_release_readiness.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Quadruped SDK release-readiness gate failed with exit code $LASTEXITCODE"
}

& (Join-Path $sdkRoot "run_developer_experience_conformance.ps1") -SkipBuild
if ($LASTEXITCODE -ne 0) {
    throw "Developer-experience conformance failed with exit code $LASTEXITCODE"
}

[void](Complete-SporeSporeConformanceStage -Session $conformanceObservation)
Start-SporeSporeConformanceStage `
    -Session $conformanceObservation `
    -StageId "attestation_and_terminal_receipt"

if (-not [string]::IsNullOrWhiteSpace($DurableAttestationOutput)) {
    $publishedAttestation = Publish-SporeSporeFullConformanceAttestation `
        -RepoRoot $repoRoot `
        -Godot $Godot `
        -OutputPath $DurableAttestationOutput `
        -OperationLockReceipt $conformanceOperationLock `
        -StartedUtc $conformanceStartedUtc `
        -SourceAtStart $attestationSourceAtStart
    Write-Host (
        "FULL_CONFORMANCE_ATTESTATION_PUBLISHED path=$($publishedAttestation.path) " +
        "sha256=$($publishedAttestation.sha256) " +
        "source=$($publishedAttestation.source_commit) physical_authority=False"
    )
}
Write-Host "SDK C0/C1 conformance passed."
[void](Complete-SporeSporeConformanceStage -Session $conformanceObservation)
} catch {
    $conformanceFailure = $_
    if ($null -ne $conformanceObservation) {
        try {
            $observedExitCode = if ($LASTEXITCODE -is [int] -and $LASTEXITCODE -ne 0) {
                [int]$LASTEXITCODE
            } else { 1 }
            [void](Fail-SporeSporeConformanceStage `
                -Session $conformanceObservation `
                -ErrorRecord $_ `
                -ExitCode $observedExitCode)
        } catch {
            $conformanceObservationFailure = $_
        }
    }
} finally {
    if ($conformanceTranscriptStarted) {
        try {
            Stop-Transcript | Out-Null
        } catch {
            if ($null -eq $conformanceObservationFailure) {
                $conformanceObservationFailure = $_
            }
        }
    }
    if ($null -ne $conformanceObservation) {
        try {
            $observationStatus = if ($null -eq $conformanceFailure) {
                "passed"
            } else { "failed" }
            [void](Complete-SporeSporeConformanceObservation `
                -Session $conformanceObservation `
                -Status $observationStatus)
        } catch {
            if ($null -eq $conformanceObservationFailure) {
                $conformanceObservationFailure = $_
            }
        }
    }
    Exit-SporeSporeLocomotionOperationLock $conformanceOperationLock
}
if ($null -ne $conformanceObservationFailure) {
    if ($null -ne $conformanceFailure) {
        Write-Warning (
            "Conformance observation also failed: " +
            $conformanceObservationFailure.Exception.Message
        )
    } else {
        throw $conformanceObservationFailure
    }
}
if ($null -ne $conformanceFailure) {
    throw $conformanceFailure
}

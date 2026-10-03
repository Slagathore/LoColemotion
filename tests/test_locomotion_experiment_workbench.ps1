#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [switch]$SkipGodot
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$catalogPath = Join-Path $repoRoot "sdk\workbench\experiment_catalog.json"
$scenePath = Join-Path (
    $repoRoot
) "scenes\tools\locomotion_experiment_workbench.tscn"
$workbenchPath = Join-Path (
    $repoRoot
) "scripts\tools\locomotion_experiment_workbench.gd"
$previewPath = Join-Path (
    $repoRoot
) "scripts\tools\locomotion_experiment_preview.gd"
$livePhysicsPath = Join-Path (
    $repoRoot
) "scripts\tools\locomotion_live_physics_demo.gd"
$liveCameraPath = Join-Path (
    $repoRoot
) "scripts\tools\locomotion_live_physics_camera.gd"
$nativeViewerPath = Join-Path (
    $repoRoot
) "scripts\tools\locomotion_native_stream_viewer.gd"
$launcherPath = Join-Path (
    $repoRoot
) "scripts\open_locomotion_experiment_workbench.ps1"
$guidePath = Join-Path (
    $repoRoot
) "docs\LOCOMOTION_EXPERIMENT_WORKBENCH_GUIDE.md"
$evidenceRoot = Join-Path (
    (Split-Path -Parent $repoRoot)
) "SporeSpore_Evidence"
$expectedSchema = "sporespore_locomotion_experiment_workbench_catalog_v1"
$expectedSelfTest = (
    "LOCOMOTION_EXPERIMENT_WORKBENCH_PASS engines=4 presets=4 " +
    "parameters=29 runs=122 worlds=0 physical_identity_consumed=False"
)
$expectedSafeProcessSelfTest = (
    "LOCOMOTION_EXPERIMENT_WORKBENCH_SAFE_PROCESS_PASS " +
    "audit=repository_boundary exit=0 worlds=0 " +
    "physical_identity_consumed=False"
)
$expectedLiveProcessSelfTest = (
    "LOCOMOTION_EXPERIMENT_WORKBENCH_LIVE_PROCESS_PASS " +
    "exit=0 worlds=0 physical_identity_consumed=False"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Test-ProofReference {
    param([string]$Role, [string]$Path, [string]$Expected, [string]$Actual)
    if ($Expected -cnotmatch "^[0-9a-f]{64}$") { return $false }
    if ($Role -ceq "historical_source_reference") {
        return [IO.Path]::GetExtension($Path) -cin @(".gd", ".rs", ".ps1", ".md")
    }
    return ($Role -cin @("pinned_artifact", "current_authority") -and $Actual -ceq $Expected)
}

# An old source reference may remain visibly mismatched, but immutable result
# JSON and current authorities must never gain that exception.
$pinFixture = "a" * 64
$changedFixture = "b" * 64
foreach ($case in @(
    @("pinned_artifact", "result.json", $pinFixture, $pinFixture, $true),
    @("pinned_artifact", "result.json", $pinFixture, $changedFixture, $false),
    @("current_authority", "release.json", $pinFixture, $changedFixture, $false),
    @("historical_source_reference", "old.gd", $pinFixture, $changedFixture, $true),
    @("historical_source_reference", "result.json", $pinFixture, $changedFixture, $false),
    @("historical_source_reference", "old.gd", "not-a-digest", $changedFixture, $false),
    @("unknown", "old.gd", $pinFixture, $pinFixture, $false)
)) {
    Assert-Exact ((Test-ProofReference $case[0] $case[1] $case[2] $case[3]) -eq $case[4]) (
        "LOCOMOTION_EXPERIMENT_WORKBENCH proof reference control failed: $($case[0])/$($case[1])"
    )
}

function Get-Bw22lAttemptCount {
    if (-not (Test-Path -LiteralPath $evidenceRoot -PathType Container)) {
        return 0
    }
    return @(
        Get-ChildItem `
            -LiteralPath $evidenceRoot `
            -Directory `
            -Filter "balanced-wave-bw22l-lateral-development-*" `
            -ErrorAction SilentlyContinue |
            ForEach-Object {
                $attemptPath = Join-Path $_.FullName "attempt.json"
                if (Test-Path -LiteralPath $attemptPath -PathType Leaf) {
                    try {
                        $attempt = Get-Content -Raw -LiteralPath $attemptPath |
                            ConvertFrom-Json -Depth 64
                        if ([string]$attempt.campaign_id -ceq (
                            "BW22L-FRESH-MATERIAL-LATERAL-DEVELOPMENT"
                        )) {
                            $attemptPath
                        }
                    }
                    catch { }
                }
            }
    ).Count
}

foreach ($requiredPath in @(
    $catalogPath,
    $scenePath,
    $workbenchPath,
    $previewPath,
    $livePhysicsPath,
    $liveCameraPath,
    $nativeViewerPath,
    $launcherPath,
    $guidePath
)) {
    Assert-Exact (
        Test-Path -LiteralPath $requiredPath -PathType Leaf
    ) "LOCOMOTION_EXPERIMENT_WORKBENCH missing $requiredPath"
}

$catalog = Get-Content -Raw -LiteralPath $catalogPath |
    ConvertFrom-Json -Depth 100
Assert-Exact (
    [string]$catalog.schema_version -ceq $expectedSchema -and
    [string]$catalog.catalog_role -ceq (
        "operator_interface_not_scientific_evidence"
    ) -and
    [bool]$catalog.safety_model.editable_values_are_exploration_drafts -and
    [bool]$catalog.safety_model.editing_a_frozen_value_requires_a_new_campaign -and
    [bool]$catalog.safety_model.physical_runs_require_existing_runner_interlocks
) "LOCOMOTION_EXPERIMENT_WORKBENCH catalog safety identity changed"

Assert-Exact (
    @($catalog.engines).Count -eq 4 -and
    @($catalog.presets).Count -eq 4 -and
    @($catalog.parameters).Count -eq 29 -and
    @($catalog.runs).Count -eq 122
) "LOCOMOTION_EXPERIMENT_WORKBENCH catalog counts changed"

$engineIds = @($catalog.engines | ForEach-Object { [string]$_.id })
$parameterIds = @($catalog.parameters | ForEach-Object { [string]$_.id })
$presetIds = @($catalog.presets | ForEach-Object { [string]$_.id })
$runIds = @($catalog.runs | ForEach-Object { [string]$_.id })
foreach ($identitySet in @($engineIds, $parameterIds, $presetIds, $runIds)) {
    Assert-Exact (
        @($identitySet | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -eq 0 -and
        @($identitySet | Select-Object -Unique).Count -eq $identitySet.Count
    ) "LOCOMOTION_EXPERIMENT_WORKBENCH missing or duplicate catalog id"
}

foreach ($preset in $catalog.presets) {
    $valueNames = @($preset.values.PSObject.Properties.Name)
    Assert-Exact (
        @($parameterIds | Where-Object { $_ -notin $valueNames }).Count -eq 0 -and
        @($valueNames | Where-Object { $_ -notin $parameterIds }).Count -eq 0
    ) "LOCOMOTION_EXPERIMENT_WORKBENCH preset $($preset.id) is not parameter-complete"
}

$physicalRuns = @(
    $catalog.runs | Where-Object { [string]$_.kind -ceq "physical_one_shot" }
)
Assert-Exact (
    $physicalRuns.Count -eq 0
) "LOCOMOTION_EXPERIMENT_WORKBENCH closed campaign exposes a physical one-shot"

$r23d57PreflightRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d57_physical_campaign_preflight"
    }
)
Assert-Exact (
    $r23d57PreflightRun.Count -eq 1 -and
    [string]$r23d57PreflightRun[0].kind -ceq
        "zero_world_physical_campaign_preflight" -and
    [string]$r23d57PreflightRun[0].status -ceq
        "closed_consumed_invalid_complete_preflight_source_retained" -and
    [string]$r23d57PreflightRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d57PreflightRun[0].risk -ceq "safe" -and
    [string]$r23d57PreflightRun[0].runner_path -ceq
        "sdk/run_qsdk_r23d57_supervisor.ps1" -and
    (@($r23d57PreflightRun[0].arguments) -join ",") -ceq "-PreflightOnly" -and
    @($r23d57PreflightRun[0].proofs).Count -eq 9
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D57 preflight exposure changed"

$r23d57ClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d57_physical_closure"
    }
)
Assert-Exact (
    $r23d57ClosureRun.Count -eq 1 -and
    [string]$r23d57ClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d57ClosureRun[0].status -ceq
        "closed_consumed_invalid_complete" -and
    [string]$r23d57ClosureRun[0].world_policy -ceq
        "retained_evidence_only" -and
    [string]$r23d57ClosureRun[0].risk -ceq "safe" -and
    [string]$r23d57ClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d57_physical_closure.ps1" -and
    @($r23d57ClosureRun[0].arguments).Count -eq 0 -and
    @($r23d57ClosureRun[0].proofs).Count -eq 2
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D57 physical closure exposure changed"

$r23d58ZeroWorldRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d58_zero_world"
    }
)
Assert-Exact (
    $r23d58ZeroWorldRun.Count -eq 1 -and
    [string]$r23d58ZeroWorldRun[0].kind -ceq
        "zero_world_conformance_gate" -and
    [string]$r23d58ZeroWorldRun[0].status -ceq
        "prospective_campaign_machinery_implemented_complete_zero_world_gates_passed_physical_campaign_not_opened" -and
    [string]$r23d58ZeroWorldRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d58ZeroWorldRun[0].risk -ceq "safe" -and
    [string]$r23d58ZeroWorldRun[0].runner_path -ceq
        "tests/test_qsdk_r23d58_terminal_trace_cap_factorial_zero_world.ps1" -and
    (@($r23d58ZeroWorldRun[0].arguments) -join ",") -ceq "-SkipGodot" -and
    @($r23d58ZeroWorldRun[0].proofs).Count -eq 17
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D58 zero-world exposure changed"

$r23d58ClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d58_physical_closure"
    }
)
Assert-Exact (
    $r23d58ClosureRun.Count -eq 1 -and
    [string]$r23d58ClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d58ClosureRun[0].status -ceq
        "closed_consumed_valid_complete_descriptive_development" -and
    [string]$r23d58ClosureRun[0].world_policy -ceq
        "retained_evidence_only" -and
    [string]$r23d58ClosureRun[0].risk -ceq "safe" -and
    [string]$r23d58ClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d58_physical_closure.ps1" -and
    @($r23d58ClosureRun[0].arguments).Count -eq 0 -and
    @($r23d58ClosureRun[0].proofs).Count -eq 2
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D58 physical closure exposure changed"

$r23d59PreregistrationRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d59_preregistration"
    }
)
Assert-Exact (
    $r23d59PreregistrationRun.Count -eq 1 -and
    [string]$r23d59PreregistrationRun[0].kind -ceq
        "zero_world_declaration_gate" -and
    [string]$r23d59PreregistrationRun[0].status -ceq
        "historical_closed_consumed_declaration_gate_passed" -and
    [string]$r23d59PreregistrationRun[0].world_policy -ceq
        "retained_zero_world_declaration_only" -and
    [string]$r23d59PreregistrationRun[0].risk -ceq "safe" -and
    [string]$r23d59PreregistrationRun[0].runner_path -ceq
        "tests/test_qsdk_r23d59_preregistration.ps1" -and
    (@($r23d59PreregistrationRun[0].arguments) -join ",") -ceq "-SkipGodot" -and
    @($r23d59PreregistrationRun[0].proofs).Count -eq 4
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D59 preregistration exposure changed"

$r23d59ZeroWorldRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d59_complete_zero_world"
    }
)
Assert-Exact (
    $r23d59ZeroWorldRun.Count -eq 1 -and
    [string]$r23d59ZeroWorldRun[0].kind -ceq
        "zero_world_physical_campaign_preflight" -and
    [string]$r23d59ZeroWorldRun[0].status -ceq
        "historical_closed_consumed_complete_zero_world_gate_passed" -and
    [string]$r23d59ZeroWorldRun[0].world_policy -ceq
        "retained_zero_world_preflight_only" -and
    [string]$r23d59ZeroWorldRun[0].risk -ceq "safe" -and
    [string]$r23d59ZeroWorldRun[0].runner_path -ceq
        "sdk/run_qsdk_r23d59_supervisor.ps1" -and
    (@($r23d59ZeroWorldRun[0].arguments) -join ",") -ceq "-PreflightOnly" -and
    @($r23d59ZeroWorldRun[0].proofs).Count -eq 9
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D59 zero-world exposure changed"

$r23d59ClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d59_physical_closure"
    }
)
Assert-Exact (
    $r23d59ClosureRun.Count -eq 1 -and
    [string]$r23d59ClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d59ClosureRun[0].status -ceq
        "closed_consumed_valid_complete_fixture_knee_selected" -and
    [string]$r23d59ClosureRun[0].world_policy -ceq
        "retained_evidence_only" -and
    [string]$r23d59ClosureRun[0].risk -ceq "safe" -and
    [string]$r23d59ClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d59_physical_closure.ps1" -and
    @($r23d59ClosureRun[0].arguments).Count -eq 0 -and
    @($r23d59ClosureRun[0].proofs).Count -eq 2
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D59 physical closure exposure changed"

$r23d60PreregistrationRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d60_preregistration"
    }
)
Assert-Exact (
    $r23d60PreregistrationRun.Count -eq 1 -and
    [string]$r23d60PreregistrationRun[0].kind -ceq
        "zero_world_declaration_gate" -and
    [string]$r23d60PreregistrationRun[0].status -ceq
        "prospective_local_declaration_gate_passed" -and
    [string]$r23d60PreregistrationRun[0].world_policy -ceq
        "zero_world_declaration_only" -and
    [string]$r23d60PreregistrationRun[0].risk -ceq "safe" -and
    [string]$r23d60PreregistrationRun[0].runner_path -ceq
        "tests/test_qsdk_r23d60_preregistration.ps1" -and
    (@($r23d60PreregistrationRun[0].arguments) -join ",") -ceq "-SkipGodot" -and
    @($r23d60PreregistrationRun[0].proofs).Count -eq 5
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D60 preregistration exposure changed"

$r23d60ZeroWorldRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d60_complete_zero_world"
    }
)
Assert-Exact (
    $r23d60ZeroWorldRun.Count -eq 1 -and
    [string]$r23d60ZeroWorldRun[0].kind -ceq
        "zero_world_campaign_gate" -and
    [string]$r23d60ZeroWorldRun[0].status -ceq
        "closed_zero_world_lineage_consumed_by_positive_physical_closure" -and
    [string]$r23d60ZeroWorldRun[0].world_policy -ceq
        "zero_world_preflight_only" -and
    [string]$r23d60ZeroWorldRun[0].risk -ceq "safe" -and
    [string]$r23d60ZeroWorldRun[0].runner_path -ceq
        "sdk/run_qsdk_r23d60_supervisor.ps1" -and
    (@($r23d60ZeroWorldRun[0].arguments) -join ",") -ceq "-PreflightOnly" -and
    @($r23d60ZeroWorldRun[0].proofs).Count -eq 8
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D60 zero-world exposure changed"

$r23d60ClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d60_physical_closure"
    }
)
Assert-Exact (
    $r23d60ClosureRun.Count -eq 1 -and
    [string]$r23d60ClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d60ClosureRun[0].status -ceq
        "closed_consumed_valid_complete_positive_exact_held_out_godot_jolt_turning" -and
    [string]$r23d60ClosureRun[0].world_policy -ceq
        "retained_evidence_only" -and
    [string]$r23d60ClosureRun[0].risk -ceq "safe" -and
    [string]$r23d60ClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d60_physical_closure.ps1" -and
    @($r23d60ClosureRun[0].arguments).Count -eq 0 -and
    @($r23d60ClosureRun[0].proofs).Count -eq 2
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D60 physical closure exposure changed"

$r23d62PreregistrationRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d62_preregistration"
    }
)
Assert-Exact (
    $r23d62PreregistrationRun.Count -eq 1 -and
    (@($r23d62PreregistrationRun[0].engine_ids) -join "|") -ceq
        "godot_jolt|rapier_parry|mujoco" -and
    [string]$r23d62PreregistrationRun[0].kind -ceq
        "zero_world_declaration_gate" -and
    [string]$r23d62PreregistrationRun[0].status -ceq
        "closed_consumed_invalid_incomplete_before_first_world_authorization_receipt_schema_projection_failure" -and
    [string]$r23d62PreregistrationRun[0].world_policy -ceq
        "zero_world_declaration_only" -and
    [string]$r23d62PreregistrationRun[0].risk -ceq "safe" -and
    [string]$r23d62PreregistrationRun[0].runner_path -ceq
        "tests/test_qsdk_r23d62_preregistration.ps1" -and
    (@($r23d62PreregistrationRun[0].arguments) -join "|") -ceq
        "-SkipGodot" -and
    @($r23d62PreregistrationRun[0].proofs).Count -eq 6 -and
    (
        @(
            $r23d62PreregistrationRun[0].proofs |
                ForEach-Object { [string]$_.path }
        ) -join "|"
    ) -ceq (
        "sdk/turning/r23d62_selected_profile_three_engine_turning_validation_preregistration_v1.json|" +
        "sdk/turning/r23d62_selected_profile_three_engine_turning_validation.py|" +
        "tests/test_qsdk_r23d62_preregistration.ps1|" +
        "sdk/turning/r23d62_seed_fixture_compiler.gd|" +
        "sdk/turning/r23d60_godot_fixture_knee_held_out_turning_validation_closure_v1.json|" +
        "sdk/turning/r23d61_selected_actuator_profile_publication_closure_v1.json"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D62 preregistration exposure changed"

$r23d62ClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d62_physical_closure"
    }
)
Assert-Exact (
    $r23d62ClosureRun.Count -eq 1 -and
    (@($r23d62ClosureRun[0].engine_ids) -join "|") -ceq
        "godot_jolt|rapier_parry|mujoco" -and
    [string]$r23d62ClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d62ClosureRun[0].status -ceq
        "closed_consumed_invalid_incomplete_before_first_world_authorization_receipt_schema_projection_failure" -and
    [string]$r23d62ClosureRun[0].world_policy -ceq
        "retained_evidence_only" -and
    [string]$r23d62ClosureRun[0].risk -ceq "safe" -and
    [string]$r23d62ClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d62_physical_closure.ps1" -and
    @($r23d62ClosureRun[0].arguments).Count -eq 0 -and
    @($r23d62ClosureRun[0].proofs).Count -eq 2 -and
    (@($r23d62ClosureRun[0].proofs.path) -join "|") -ceq (
        "sdk/turning/r23d62_selected_profile_three_engine_turning_validation_closure_v1.json|" +
        "tests/test_qsdk_r23d62_physical_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D62 physical closure exposure changed"

$r23d63ClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d63_physical_closure"
    }
)
Assert-Exact (
    $r23d63ClosureRun.Count -eq 1 -and
    (@($r23d63ClosureRun[0].engine_ids) -join "|") -ceq
        "godot_jolt|rapier_parry|mujoco" -and
    [string]$r23d63ClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d63ClosureRun[0].status -ceq
        "closed_consumed_invalid_incomplete_before_first_world_rapier_cli_argument_contract_failure" -and
    [string]$r23d63ClosureRun[0].world_policy -ceq
        "retained_evidence_only" -and
    [string]$r23d63ClosureRun[0].risk -ceq "safe" -and
    [string]$r23d63ClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d63_physical_closure.ps1" -and
    @($r23d63ClosureRun[0].arguments).Count -eq 0 -and
    @($r23d63ClosureRun[0].proofs).Count -eq 4 -and
    (@($r23d63ClosureRun[0].proofs.path) -join "|") -ceq (
        "sdk/turning/r23d63_selected_profile_three_engine_turning_validation_closure_v1.json|" +
        "tests/test_qsdk_r23d63_physical_closure.ps1|" +
        "sdk/closure_evidence_mode_inventory.json|" +
        "sdk/closure_evidence_provenance_contract.json"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D63 physical closure exposure changed"

$r23d64ZeroWorldRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d64_complete_zero_world"
    }
)
Assert-Exact (
    $r23d64ZeroWorldRun.Count -eq 1 -and
    (@($r23d64ZeroWorldRun[0].engine_ids) -join "|") -ceq
        "godot_jolt|rapier_parry|mujoco" -and
    [string]$r23d64ZeroWorldRun[0].kind -ceq
        "zero_world_campaign_gate" -and
    [string]$r23d64ZeroWorldRun[0].status -ceq
        "closed_consumed_invalid_incomplete_after_six_worlds_three_engine_integration_failures" -and
    [string]$r23d64ZeroWorldRun[0].world_policy -ceq
        "zero_world_preflight_only" -and
    [string]$r23d64ZeroWorldRun[0].risk -ceq "safe" -and
    [string]$r23d64ZeroWorldRun[0].runner_path -ceq
        "sdk/run_qsdk_r23d64_supervisor.ps1" -and
    (@($r23d64ZeroWorldRun[0].arguments) -join "|") -ceq
        "-PreflightOnly" -and
    @($r23d64ZeroWorldRun[0].proofs).Count -eq 12 -and
    (@($r23d64ZeroWorldRun[0].proofs.path) -join "|") -ceq (
        "sdk/turning/r23d63_selected_profile_three_engine_turning_" +
        "validation_closure_v1.json|" +
        "tests/test_qsdk_r23d63_physical_closure.ps1|" +
        "sdk/turning/r23d64_selected_profile_three_engine_turning_" +
        "validation_preregistration_v1.json|" +
        "sdk/turning/r23d64_rapier_launcher_contract.ps1|" +
        "tests/test_qsdk_r23d64_rapier_launcher_contract.ps1|" +
        "sdk/turning/r23d64_selected_profile_three_engine_turning_" +
        "validation_implementation_v1.json|" +
        "sdk/turning/r23d64_dependency_closure.py|" +
        "tests/test_qsdk_r23d64_dependency_closure.ps1|" +
        "sdk/run_qsdk_r23d64_supervisor.ps1|" +
        "tests/test_qsdk_r23d64_campaign_roles.ps1|" +
        "sdk/release/quadruped_release_contract.json|" +
        "sdk/release/quadruped_support_matrix.json"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D64 zero-world exposure changed"

$r23d64PhysicalClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d64_physical_closure"
    }
)
Assert-Exact (
    $r23d64PhysicalClosureRun.Count -eq 1 -and
    (@($r23d64PhysicalClosureRun[0].engine_ids) -join "|") -ceq
        "godot_jolt|rapier_parry|mujoco" -and
    [string]$r23d64PhysicalClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d64PhysicalClosureRun[0].status -ceq
        "closed_consumed_invalid_incomplete_after_six_worlds_three_engine_integration_failures" -and
    [string]$r23d64PhysicalClosureRun[0].world_policy -ceq
        "retained_evidence_only" -and
    [string]$r23d64PhysicalClosureRun[0].risk -ceq "safe" -and
    [string]$r23d64PhysicalClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d64_physical_closure.ps1" -and
    @($r23d64PhysicalClosureRun[0].arguments).Count -eq 0 -and
    @($r23d64PhysicalClosureRun[0].proofs).Count -eq 7 -and
    (@($r23d64PhysicalClosureRun[0].proofs.path) -join "|") -ceq (
        "sdk/turning/r23d64_selected_profile_three_engine_turning_" +
        "validation_closure_v1.json|" +
        "tests/test_qsdk_r23d64_physical_closure.ps1|" +
        "sdk/closure_evidence_mode_inventory.json|" +
        "sdk/closure_evidence_provenance_contract.json|" +
        "tests/test_closure_evidence_provenance_contract.ps1|" +
        "sdk/release/quadruped_release_contract.json|" +
        "sdk/release/quadruped_support_matrix.json"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D64 physical closure exposure changed"

$r23d65ZeroWorldRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d65_complete_zero_world"
    }
)
Assert-Exact (
    $r23d65ZeroWorldRun.Count -eq 1 -and
    (@($r23d65ZeroWorldRun[0].engine_ids) -join "|") -ceq
        "godot_jolt|rapier_parry|mujoco" -and
    [string]$r23d65ZeroWorldRun[0].kind -ceq
        "zero_world_campaign_gate" -and
    [string]$r23d65ZeroWorldRun[0].status -ceq
        "closed_consumed_invalid_incomplete_after_four_worlds_runtime_terminal_and_trace_retention_failures" -and
    [string]$r23d65ZeroWorldRun[0].world_policy -ceq
        "zero_world_preflight_only" -and
    [string]$r23d65ZeroWorldRun[0].risk -ceq "safe" -and
    [string]$r23d65ZeroWorldRun[0].runner_path -ceq
        "sdk/run_qsdk_r23d65_supervisor.ps1" -and
    (@($r23d65ZeroWorldRun[0].arguments) -join "|") -ceq
        "-PreflightOnly" -and
    @($r23d65ZeroWorldRun[0].proofs).Count -eq 21 -and
    (@($r23d65ZeroWorldRun[0].proofs.path) -join "|") -ceq (
        "sdk/turning/r23d64_selected_profile_three_engine_turning_" +
        "validation_closure_v1.json|" +
        "tests/test_qsdk_r23d64_physical_closure.ps1|" +
        "sdk/turning/r23d65_selected_profile_three_engine_turning_" +
        "validation_preregistration_v1.json|" +
        "sdk/turning/r23d65_selected_profile_three_engine_turning_" +
        "validation.py|" +
        "sdk/turning/r23d65_selected_profile_three_engine_turning_" +
        "validation_evaluator.py|" +
        "tests/test_qsdk_r23d65_evaluator.ps1|" +
        "sdk/turning/r23d65_selected_profile_three_engine_turning_" +
        "validation_implementation_v1.json|" +
        "sdk/turning/r23d65_runtime_integration_conformance.py|" +
        "tests/test_sdk_qsdk_r23d65_godot_failure_terminal_projection_" +
        "zero_world.gd|" +
        "tests/test_qsdk_r23d65_runtime_integration.ps1|" +
        "sdk/turning/r23d65_dependency_closure.py|" +
        "tests/test_qsdk_r23d65_dependency_closure.ps1|" +
        "tests/test_qsdk_r23d65_authorization_receipt_schema.ps1|" +
        "tests/test_qsdk_r23d65_rapier_launcher_contract.ps1|" +
        "sdk/run_qsdk_r23d65_supervisor.ps1|" +
        "tests/test_qsdk_r23d65_campaign_roles.ps1|" +
        "sdk/closure_evidence_mode_inventory.json|" +
        "sdk/closure_evidence_provenance_contract.json|" +
        "tests/test_closure_evidence_provenance_contract.ps1|" +
        "sdk/release/quadruped_release_contract.json|" +
        "sdk/release/quadruped_support_matrix.json"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D65 zero-world exposure changed"

$r23d65PhysicalClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d65_physical_closure"
    }
)
Assert-Exact (
    $r23d65PhysicalClosureRun.Count -eq 1 -and
    (@($r23d65PhysicalClosureRun[0].engine_ids) -join "|") -ceq
        "godot_jolt|rapier_parry|mujoco" -and
    [string]$r23d65PhysicalClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d65PhysicalClosureRun[0].status -ceq
        "closed_consumed_invalid_incomplete_after_four_worlds_runtime_terminal_and_trace_retention_failures" -and
    [string]$r23d65PhysicalClosureRun[0].world_policy -ceq
        "retained_evidence_only" -and
    [string]$r23d65PhysicalClosureRun[0].risk -ceq "safe" -and
    [string]$r23d65PhysicalClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d65_physical_closure.ps1" -and
    @($r23d65PhysicalClosureRun[0].arguments).Count -eq 0 -and
    @($r23d65PhysicalClosureRun[0].proofs).Count -eq 7 -and
    (@($r23d65PhysicalClosureRun[0].proofs.path) -join "|") -ceq (
        "sdk/turning/r23d65_selected_profile_three_engine_turning_" +
        "validation_closure_v1.json|" +
        "tests/test_qsdk_r23d65_physical_closure.ps1|" +
        "sdk/closure_evidence_mode_inventory.json|" +
        "sdk/closure_evidence_provenance_contract.json|" +
        "tests/test_closure_evidence_provenance_contract.ps1|" +
        "sdk/release/quadruped_release_contract.json|" +
        "sdk/release/quadruped_support_matrix.json"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D65 physical closure exposure changed"

$r23d62EvaluatorRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d62_evaluator"
    }
)
Assert-Exact (
    $r23d62EvaluatorRun.Count -eq 1 -and
    (@($r23d62EvaluatorRun[0].engine_ids) -join "|") -ceq
        "godot_jolt|rapier_parry|mujoco" -and
    [string]$r23d62EvaluatorRun[0].kind -ceq
        "zero_world_evaluator_gate" -and
    [string]$r23d62EvaluatorRun[0].status -ceq
        "prospective_corrected_evaluator_v2_gate_passed_native_implementation_pending" -and
    [string]$r23d62EvaluatorRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d62EvaluatorRun[0].risk -ceq "safe" -and
    [string]$r23d62EvaluatorRun[0].runner_path -ceq
        "tests/test_qsdk_r23d62_evaluator_v2.ps1" -and
    @($r23d62EvaluatorRun[0].arguments).Count -eq 0 -and
    @($r23d62EvaluatorRun[0].proofs).Count -eq 7 -and
    (
        @(
            $r23d62EvaluatorRun[0].proofs |
                ForEach-Object { [string]$_.path }
        ) -join "|"
    ) -ceq (
        "sdk/turning/r23d62_selected_profile_three_engine_turning_validation_preregistration_v1.json|" +
        "sdk/turning/r23d62_selected_profile_three_engine_turning_validation_evaluator.py|" +
        "tests/test_qsdk_r23d62_evaluator.ps1|" +
        "sdk/turning/r23d62_evaluator_v1_zero_world_rejection_v1.json|" +
        "sdk/turning/r23d62_selected_profile_three_engine_turning_validation_evaluator_v2.py|" +
        "tests/test_qsdk_r23d62_evaluator_v2.ps1|" +
        "sdk/turning/r23d61_selected_actuator_profile_publication_closure_v1.json"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D62 evaluator exposure changed"

$r23d62GodotRouteRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d62_godot_public_profile_route"
    }
)
Assert-Exact (
    $r23d62GodotRouteRun.Count -eq 1 -and
    (@($r23d62GodotRouteRun[0].engine_ids) -join "|") -ceq
        "godot_jolt" -and
    [string]$r23d62GodotRouteRun[0].kind -ceq
        "zero_world_native_dependency_route_gate" -and
    [string]$r23d62GodotRouteRun[0].status -ceq
        "implemented_zero_world_dependency_route_passed_native_worker_also_passed" -and
    [string]$r23d62GodotRouteRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d62GodotRouteRun[0].risk -ceq "safe" -and
    [string]$r23d62GodotRouteRun[0].runner_path -ceq
        "tests/test_qsdk_r23d62_godot_public_profile_physical_route.ps1" -and
    @($r23d62GodotRouteRun[0].arguments).Count -eq 0 -and
    @($r23d62GodotRouteRun[0].proofs).Count -eq 6 -and
    (
        @(
            $r23d62GodotRouteRun[0].proofs |
                ForEach-Object { [string]$_.path }
        ) -join "|"
    ) -ceq (
        "scripts/lab/gait/sdk_godot_jolt_public_actuator_cap_profile_binding.gd|" +
        "scripts/lab/gait/physical_wave_gait_quadruped.gd|" +
        "tests/test_sdk_qsdk_r23d62_godot_public_profile_physical_route_zero_world.gd|" +
        "tests/test_qsdk_r23d62_godot_public_profile_physical_route.py|" +
        "tests/test_qsdk_r23d62_godot_public_profile_physical_route.ps1|" +
        "sdk/turning/r23d62_selected_profile_three_engine_turning_validation_evaluator_v2.py"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D62 Godot route exposure changed"

$r23d62RapierRouteRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d62_rapier_public_profile_route"
    }
)
Assert-Exact (
    $r23d62RapierRouteRun.Count -eq 1 -and
    (@($r23d62RapierRouteRun[0].engine_ids) -join "|") -ceq
        "rapier_parry" -and
    [string]$r23d62RapierRouteRun[0].kind -ceq
        "zero_world_native_dependency_route_gate" -and
    [string]$r23d62RapierRouteRun[0].status -ceq
        "implemented_zero_world_dependency_route_passed_native_worker_also_passed" -and
    [string]$r23d62RapierRouteRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d62RapierRouteRun[0].risk -ceq "safe" -and
    [string]$r23d62RapierRouteRun[0].runner_path -ceq
        "tests/test_qsdk_r23d62_rapier_public_profile_physical_route.ps1" -and
    @($r23d62RapierRouteRun[0].arguments).Count -eq 0 -and
    @($r23d62RapierRouteRun[0].proofs).Count -eq 7 -and
    (
        @(
            $r23d62RapierRouteRun[0].proofs |
                ForEach-Object { [string]$_.path }
        ) -join "|"
    ) -ceq (
        "sdk/adapters/rapier/src/actuator_cap_profile.rs|" +
        "sdk/adapters/rapier/src/locomotion.rs|" +
        "sdk/adapters/rapier/src/qsdk_r23d62_public_profile_route.rs|" +
        "sdk/adapters/rapier/src/bin/qsdk_r23d62_public_profile_route.rs|" +
        "tests/test_qsdk_r23d62_rapier_public_profile_physical_route.py|" +
        "tests/test_qsdk_r23d62_rapier_public_profile_physical_route.ps1|" +
        "sdk/turning/r23d62_selected_profile_three_engine_turning_validation_evaluator_v2.py"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D62 Rapier route exposure changed"

$r23d62GodotWorkerRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d62_godot_worker"
    }
)
Assert-Exact (
    $r23d62GodotWorkerRun.Count -eq 1 -and
    (@($r23d62GodotWorkerRun[0].engine_ids) -join "|") -ceq
        "godot_jolt" -and
    [string]$r23d62GodotWorkerRun[0].kind -ceq
        "zero_world_native_worker_gate" -and
    [string]$r23d62GodotWorkerRun[0].status -ceq
        "implemented_zero_world_worker_gate_passed_all_three_workers_passed" -and
    [string]$r23d62GodotWorkerRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d62GodotWorkerRun[0].risk -ceq "safe" -and
    [string]$r23d62GodotWorkerRun[0].runner_path -ceq
        "tests/test_qsdk_r23d62_godot_jolt_physical_worker.ps1" -and
    @($r23d62GodotWorkerRun[0].arguments).Count -eq 0 -and
    @($r23d62GodotWorkerRun[0].proofs).Count -eq 6 -and
    (
        @(
            $r23d62GodotWorkerRun[0].proofs |
                ForEach-Object { [string]$_.path }
        ) -join "|"
    ) -ceq (
        "sdk/turning/r23d62_selected_profile_three_engine_turning_validation_implementation_v1.json|" +
        "tests/test_sdk_qsdk_r23d62_godot_jolt_physical_worker.gd|" +
        "tests/test_qsdk_r23d62_godot_jolt_physical_worker.ps1|" +
        "sdk/godot_receipt_terminated_process.ps1|" +
        "scripts/lab/gait/sdk_godot_jolt_public_actuator_cap_profile_binding.gd|" +
        "scripts/lab/gait/physical_wave_gait_quadruped.gd"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D62 Godot worker exposure changed"

$r23d62RapierWorkerRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d62_rapier_worker"
    }
)
Assert-Exact (
    $r23d62RapierWorkerRun.Count -eq 1 -and
    (@($r23d62RapierWorkerRun[0].engine_ids) -join "|") -ceq
        "rapier_parry" -and
    [string]$r23d62RapierWorkerRun[0].kind -ceq
        "zero_world_native_worker_gate" -and
    [string]$r23d62RapierWorkerRun[0].status -ceq
        "implemented_zero_world_worker_gate_passed_all_three_workers_passed" -and
    [string]$r23d62RapierWorkerRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d62RapierWorkerRun[0].risk -ceq "safe" -and
    [string]$r23d62RapierWorkerRun[0].runner_path -ceq
        "tests/test_qsdk_r23d62_rapier_physical_worker.ps1" -and
    @($r23d62RapierWorkerRun[0].arguments).Count -eq 0 -and
    @($r23d62RapierWorkerRun[0].proofs).Count -eq 6 -and
    (
        @(
            $r23d62RapierWorkerRun[0].proofs |
                ForEach-Object { [string]$_.path }
        ) -join "|"
    ) -ceq (
        "sdk/turning/r23d62_selected_profile_three_engine_turning_validation_implementation_v1.json|" +
        "sdk/adapters/rapier/src/qsdk_r23d62_rapier_worker.rs|" +
        "sdk/adapters/rapier/src/locomotion.rs|" +
        "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs|" +
        "sdk/adapters/rapier/src/bin/qsdk_r23d62_physical.rs|" +
        "tests/test_qsdk_r23d62_rapier_physical_worker.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D62 Rapier worker exposure changed"

$r23d62MujocoRouteRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d62_mujoco_public_profile_route"
    }
)
Assert-Exact (
    $r23d62MujocoRouteRun.Count -eq 1 -and
    (@($r23d62MujocoRouteRun[0].engine_ids) -join "|") -ceq "mujoco" -and
    [string]$r23d62MujocoRouteRun[0].kind -ceq
        "zero_world_native_dependency_route_gate" -and
    [string]$r23d62MujocoRouteRun[0].status -ceq
        "implemented_zero_world_dependency_route_passed_native_worker_also_passed" -and
    [string]$r23d62MujocoRouteRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d62MujocoRouteRun[0].risk -ceq "safe" -and
    [string]$r23d62MujocoRouteRun[0].runner_path -ceq
        "tests/test_qsdk_r23d62_mujoco_public_profile_physical_route.ps1" -and
    @($r23d62MujocoRouteRun[0].arguments).Count -eq 0 -and
    @($r23d62MujocoRouteRun[0].proofs).Count -eq 6 -and
    (
        @(
            $r23d62MujocoRouteRun[0].proofs |
                ForEach-Object { [string]$_.path }
        ) -join "|"
    ) -ceq (
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/actuator_cap_profile.py|" +
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_development.py|" +
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d62_public_profile_route.py|" +
        "tests/test_qsdk_r23d62_mujoco_public_profile_physical_route.py|" +
        "tests/test_qsdk_r23d62_mujoco_public_profile_physical_route.ps1|" +
        "sdk/turning/r23d62_selected_profile_three_engine_turning_validation_evaluator_v2.py"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D62 MuJoCo route exposure changed"

$r23d62MujocoWorkerRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d62_mujoco_worker"
    }
)
Assert-Exact (
    $r23d62MujocoWorkerRun.Count -eq 1 -and
    (@($r23d62MujocoWorkerRun[0].engine_ids) -join "|") -ceq "mujoco" -and
    [string]$r23d62MujocoWorkerRun[0].kind -ceq
        "zero_world_native_worker_gate" -and
    [string]$r23d62MujocoWorkerRun[0].status -ceq
        "implemented_zero_world_worker_gate_passed_all_three_workers_passed" -and
    [string]$r23d62MujocoWorkerRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d62MujocoWorkerRun[0].risk -ceq "safe" -and
    [string]$r23d62MujocoWorkerRun[0].runner_path -ceq
        "tests/test_qsdk_r23d62_mujoco_physical_worker.ps1" -and
    @($r23d62MujocoWorkerRun[0].arguments).Count -eq 0 -and
    @($r23d62MujocoWorkerRun[0].proofs).Count -eq 7 -and
    (
        @(
            $r23d62MujocoWorkerRun[0].proofs |
                ForEach-Object { [string]$_.path }
        ) -join "|"
    ) -ceq (
        "sdk/turning/r23d62_selected_profile_three_engine_turning_validation_implementation_v1.json|" +
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d62_selected_profile_turning.py|" +
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d62_public_profile_route.py|" +
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/actuator_cap_profile.py|" +
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_development.py|" +
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d62_selected_profile_turning_test.py|" +
        "tests/test_qsdk_r23d62_mujoco_physical_worker.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D62 MuJoCo worker exposure changed"

$r23d62AdoptionDriftRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r23d62_adoption_executor_drift_incident"
    }
)
Assert-Exact (
    $r23d62AdoptionDriftRun.Count -eq 1 -and
    (@($r23d62AdoptionDriftRun[0].engine_ids) -join "|") -ceq
        "godot_jolt|rapier_parry|mujoco" -and
    [string]$r23d62AdoptionDriftRun[0].kind -ceq
        "zero_world_process_incident_audit" -and
    [string]$r23d62AdoptionDriftRun[0].status -ceq
        "qualification_passed_adoption_refused_current_executor_recommissioning_required" -and
    [string]$r23d62AdoptionDriftRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r23d62AdoptionDriftRun[0].risk -ceq "safe" -and
    [string]$r23d62AdoptionDriftRun[0].runner_path -ceq
        "tests/test_qsdk_r23d62_campaign_attestation_adoption_executor_drift_incident.ps1" -and
    @($r23d62AdoptionDriftRun[0].arguments).Count -eq 0 -and
    @($r23d62AdoptionDriftRun[0].proofs).Count -eq 2 -and
    (
        @($r23d62AdoptionDriftRun[0].proofs | ForEach-Object {
            [string]$_.path
        }) -join "|"
    ) -ceq (
        "sdk/turning/r23d62_campaign_attestation_adoption_executor_drift_incident_v1.json|" +
        "tests/test_qsdk_r23d62_campaign_attestation_adoption_executor_drift_incident.ps1"
    ) -and
    $r23d62AdoptionDriftRun[0].summary.Contains(
        "66 CAS references across 46 unique objects"
    ) -and
    $r23d62AdoptionDriftRun[0].summary.Contains(
        "rejects 30 incident mutations"
    ) -and
    $r23d62AdoptionDriftRun[0].claim_boundary.Contains(
        "cannot be reused after recommissioning changes source"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D62 adoption drift exposure changed"

$lca1Rc8IncidentRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "lca1_rc8_r23d62_preregistration_live_authority_incident"
    }
)
Assert-Exact (
    $lca1Rc8IncidentRun.Count -eq 1 -and
    (@($lca1Rc8IncidentRun[0].engine_ids) -join "|") -ceq
        "all|godot_jolt|rapier_parry|mujoco" -and
    [string]$lca1Rc8IncidentRun[0].kind -ceq
        "zero_world_process_incident_audit" -and
    [string]$lca1Rc8IncidentRun[0].status -ceq
        "closed_negative_full_stage_4_stale_live_authority_expectation_scoped_not_started" -and
    [string]$lca1Rc8IncidentRun[0].world_policy -ceq
        "retained_evidence_only" -and
    [string]$lca1Rc8IncidentRun[0].risk -ceq "safe" -and
    [string]$lca1Rc8IncidentRun[0].runner_path -ceq
        "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc8_incident.ps1" -and
    @($lca1Rc8IncidentRun[0].arguments).Count -eq 0 -and
    @($lca1Rc8IncidentRun[0].proofs).Count -eq 2 -and
    (
        @($lca1Rc8IncidentRun[0].proofs | ForEach-Object {
            [string]$_.path
        }) -join "|"
    ) -ceq (
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc8_incident.json|" +
        "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc8_incident.ps1"
    ) -and
    $lca1Rc8IncidentRun[0].summary.Contains(
        "three passing stages"
    ) -and
    $lca1Rc8IncidentRun[0].summary.Contains(
        "seven CAS-retained artifacts"
    ) -and
    $lca1Rc8IncidentRun[0].claim_boundary.Contains(
        "RC8 is consumed and cannot rerun"
    ) -and
    $lca1Rc8IncidentRun[0].claim_boundary.Contains(
        "distinct RC9"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH LCA1-RC8 incident exposure changed"

$lca1Rc9IncidentRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "lca1_rc9_r23d62_route_live_authority_incident"
    }
)
Assert-Exact (
    $lca1Rc9IncidentRun.Count -eq 1 -and
    (@($lca1Rc9IncidentRun[0].engine_ids) -join "|") -ceq
        "all|godot_jolt|rapier_parry|mujoco" -and
    [string]$lca1Rc9IncidentRun[0].kind -ceq
        "zero_world_process_incident_audit" -and
    [string]$lca1Rc9IncidentRun[0].status -ceq
        "closed_negative_full_stage_4_rapier_route_stale_live_authority_expectation_scoped_not_started" -and
    [string]$lca1Rc9IncidentRun[0].world_policy -ceq
        "retained_evidence_only" -and
    [string]$lca1Rc9IncidentRun[0].risk -ceq "safe" -and
    [string]$lca1Rc9IncidentRun[0].runner_path -ceq
        "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc9_incident.ps1" -and
    @($lca1Rc9IncidentRun[0].arguments).Count -eq 0 -and
    @($lca1Rc9IncidentRun[0].proofs).Count -eq 2 -and
    (
        @($lca1Rc9IncidentRun[0].proofs | ForEach-Object {
            [string]$_.path
        }) -join "|"
    ) -ceq (
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc9_incident.json|" +
        "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc9_incident.ps1"
    ) -and
    $lca1Rc9IncidentRun[0].summary.Contains(
        "three passing stages"
    ) -and
    $lca1Rc9IncidentRun[0].summary.Contains(
        "seven CAS-retained artifacts"
    ) -and
    $lca1Rc9IncidentRun[0].summary.Contains(
        "three later unreached consumers"
    ) -and
    $lca1Rc9IncidentRun[0].claim_boundary.Contains(
        "RC9 is consumed and cannot rerun"
    ) -and
    $lca1Rc9IncidentRun[0].claim_boundary.Contains(
        "distinct RC10"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH LCA1-RC9 incident exposure changed"

$lca1Rc10IncidentRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "lca1_rc10_r24d3_live_source_manifest_incident"
    }
)
Assert-Exact (
    $lca1Rc10IncidentRun.Count -eq 1 -and
    (@($lca1Rc10IncidentRun[0].engine_ids) -join "|") -ceq
        "all|godot_jolt|rapier_parry|mujoco" -and
    [string]$lca1Rc10IncidentRun[0].kind -ceq
        "zero_world_process_incident_audit" -and
    [string]$lca1Rc10IncidentRun[0].status -ceq
        "closed_negative_full_stage_6_r24d3_live_source_manifest_binding_drift_scoped_not_started" -and
    [string]$lca1Rc10IncidentRun[0].world_policy -ceq
        "retained_evidence_only" -and
    [string]$lca1Rc10IncidentRun[0].risk -ceq "safe" -and
    [string]$lca1Rc10IncidentRun[0].runner_path -ceq
        "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc10_incident.ps1" -and
    @($lca1Rc10IncidentRun[0].arguments).Count -eq 0 -and
    @($lca1Rc10IncidentRun[0].proofs).Count -eq 2 -and
    (
        @($lca1Rc10IncidentRun[0].proofs | ForEach-Object {
            [string]$_.path
        }) -join "|"
    ) -ceq (
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc10_incident.json|" +
        "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc10_incident.ps1"
    ) -and
    $lca1Rc10IncidentRun[0].summary.Contains(
        "five passing stages"
    ) -and
    $lca1Rc10IncidentRun[0].summary.Contains(
        "nine CAS-retained artifacts"
    ) -and
    $lca1Rc10IncidentRun[0].summary.Contains(
        "exactly four stale infrastructure bindings"
    ) -and
    $lca1Rc10IncidentRun[0].claim_boundary.Contains(
        "RC10 is consumed and cannot rerun"
    ) -and
    $lca1Rc10IncidentRun[0].claim_boundary.Contains(
        "distinct RC11"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH LCA1-RC10 incident exposure changed"

$lca1Rc11IncidentRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "lca1_rc11_r24d2_live_source_manifest_incident"
    }
)
Assert-Exact (
    $lca1Rc11IncidentRun.Count -eq 1 -and
    (@($lca1Rc11IncidentRun[0].engine_ids) -join "|") -ceq
        "all|godot_jolt|rapier_parry|mujoco" -and
    [string]$lca1Rc11IncidentRun[0].kind -ceq
        "zero_world_process_incident_audit" -and
    [string]$lca1Rc11IncidentRun[0].status -ceq
        "closed_negative_full_stage_6_r24d2_live_source_manifest_binding_drift_scoped_not_started" -and
    [string]$lca1Rc11IncidentRun[0].world_policy -ceq
        "retained_evidence_only" -and
    [string]$lca1Rc11IncidentRun[0].risk -ceq "safe" -and
    [string]$lca1Rc11IncidentRun[0].runner_path -ceq
        "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc11_incident.ps1" -and
    @($lca1Rc11IncidentRun[0].arguments).Count -eq 0 -and
    @($lca1Rc11IncidentRun[0].proofs).Count -eq 2 -and
    (
        @($lca1Rc11IncidentRun[0].proofs | ForEach-Object {
            [string]$_.path
        }) -join "|"
    ) -ceq (
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc11_incident.json|" +
        "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc11_incident.ps1"
    ) -and
    $lca1Rc11IncidentRun[0].summary.Contains(
        "five passing stages"
    ) -and
    $lca1Rc11IncidentRun[0].summary.Contains(
        "nine CAS-retained artifacts"
    ) -and
    $lca1Rc11IncidentRun[0].summary.Contains(
        "exactly fifteen stale infrastructure and authority bindings"
    ) -and
    $lca1Rc11IncidentRun[0].claim_boundary.Contains(
        "RC11 is consumed and cannot rerun"
    ) -and
    $lca1Rc11IncidentRun[0].claim_boundary.Contains(
        "distinct RC12"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH LCA1-RC11 incident exposure changed"

$lca1Rc12ClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "lca1_rc12_exact_source_recommissioning_closure"
    }
)
Assert-Exact (
    $lca1Rc12ClosureRun.Count -eq 1 -and
    (@($lca1Rc12ClosureRun[0].engine_ids) -join "|") -ceq
        "all|godot_jolt|rapier_parry|mujoco" -and
    [string]$lca1Rc12ClosureRun[0].kind -ceq
        "zero_world_process_commissioning_closure_audit" -and
    [string]$lca1Rc12ClosureRun[0].status -ceq
        "closed_positive_exact_same_source_full_scoped_pair_cas_claim_vector_and_serialization_verified" -and
    [string]$lca1Rc12ClosureRun[0].world_policy -ceq
        "retained_evidence_only" -and
    [string]$lca1Rc12ClosureRun[0].risk -ceq "safe" -and
    [string]$lca1Rc12ClosureRun[0].runner_path -ceq
        "tests/test_locomotion_campaign_attestation_recommissioning_closure.ps1" -and
    @($lca1Rc12ClosureRun[0].arguments).Count -eq 0 -and
    @($lca1Rc12ClosureRun[0].proofs).Count -eq 2 -and
    (
        @($lca1Rc12ClosureRun[0].proofs | ForEach-Object {
            [string]$_.path
        }) -join "|"
    ) -ceq (
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc12_closure.json|" +
        "tests/test_locomotion_campaign_attestation_recommissioning_closure.ps1"
    ) -and
    $lca1Rc12ClosureRun[0].summary.Contains(
        "all eight passing full-cold stages"
    ) -and
    $lca1Rc12ClosureRun[0].summary.Contains(
        "forty-eight scoped CAS references across thirty-five unique objects"
    ) -and
    $lca1Rc12ClosureRun[0].claim_boundary.Contains(
        "closes positive only for process commissioning"
    ) -and
    $lca1Rc12ClosureRun[0].claim_boundary.Contains(
        "the score remains 10/25"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH LCA1-RC12 closure exposure changed"

$r24d1DesignRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r24d1_prone_to_standing_design"
    }
)
Assert-Exact (
    $r24d1DesignRun.Count -eq 1 -and
    (@($r24d1DesignRun[0].engine_ids) -join "|") -ceq
        "all|godot_jolt|rapier_parry|mujoco" -and
    [string]$r24d1DesignRun[0].kind -ceq
        "zero_world_design_conformance_gate" -and
    [string]$r24d1DesignRun[0].status -ceq
        "implemented_zero_world_design_gate_passed_physical_execution_blocked" -and
    [string]$r24d1DesignRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r24d1DesignRun[0].risk -ceq "safe" -and
    [string]$r24d1DesignRun[0].runner_path -ceq
        "sdk/run_qsdk_r24d1_zero_world_gate.ps1" -and
    @($r24d1DesignRun[0].arguments).Count -eq 0 -and
    @($r24d1DesignRun[0].proofs).Count -eq 6 -and
    (
        @($r24d1DesignRun[0].proofs | ForEach-Object { [string]$_.path }) -join
        "|"
    ) -ceq (
        "sdk/recovery/r24d1_canonical_prone_to_standing_design_v1.json|" +
        "sdk/recovery/r24d1_canonical_prone_to_standing_design_audit.py|" +
        "tests/test_qsdk_r24d1_declaration.py|" +
        "sdk/run_qsdk_r24d1_zero_world_gate.ps1|" +
        "sdk/release/quadruped_release_contract.json|" +
        "sdk/release/quadruped_support_matrix.json"
    ) -and
    $r24d1DesignRun[0].claim_boundary.Contains(
        "opens no physical question, model, attempt, world, or solver step"
    ) -and
    $r24d1DesignRun[0].claim_boundary.Contains(
        "establishes no prone-to-standing"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D1 design exposure changed"

$r24d2SemanticsRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r24d2_portable_recovery_semantics"
    }
)
Assert-Exact (
    $r24d2SemanticsRun.Count -eq 1 -and
    (@($r24d2SemanticsRun[0].engine_ids) -join "|") -ceq
        "all|godot_jolt|rapier_parry|mujoco" -and
    [string]$r24d2SemanticsRun[0].kind -ceq
        "zero_world_source_conformance_gate" -and
    [string]$r24d2SemanticsRun[0].status -ceq
        "implemented_partial_native_capability_conjunction_failed_physical_execution_blocked" -and
    [string]$r24d2SemanticsRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r24d2SemanticsRun[0].risk -ceq "safe" -and
    [string]$r24d2SemanticsRun[0].runner_path -ceq
        "sdk/run_qsdk_r24d2_zero_world_gate.ps1" -and
    @($r24d2SemanticsRun[0].arguments).Count -eq 0 -and
    @($r24d2SemanticsRun[0].proofs).Count -eq 6 -and
    (
        @($r24d2SemanticsRun[0].proofs | ForEach-Object { [string]$_.path }) -join
        "|"
    ) -ceq (
        "sdk/recovery/r24d2_portable_recovery_semantics_v1.json|" +
        "sdk/recovery/r24d2_portable_recovery_semantics_validation_manifest.json|" +
        "tests/test_qsdk_r24d2_portable_recovery_semantics.ps1|" +
        "sdk/run_qsdk_r24d2_zero_world_gate.ps1|" +
        "sdk/release/quadruped_release_contract.json|" +
        "sdk/release/quadruped_support_matrix.json"
    ) -and
    $r24d2SemanticsRun[0].summary.Contains(
        "Godot 8/10 typed refusal"
    ) -and
    $r24d2SemanticsRun[0].claim_boundary.Contains(
        "opens no physical question, model, attempt, world, or solver step"
    ) -and
    $r24d2SemanticsRun[0].claim_boundary.Contains(
        "establishes no prone-to-standing"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D2 semantics exposure changed"

$r24d3TelemetryRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r24d3_godot_jolt_motor_telemetry_source"
    }
)
Assert-Exact (
    $r24d3TelemetryRun.Count -eq 1 -and
    (@($r24d3TelemetryRun[0].engine_ids) -join "|") -ceq
        "all|godot_jolt" -and
    [string]$r24d3TelemetryRun[0].kind -ceq
        "instrumented_engine_zero_world_source_conformance_gate" -and
    [string]$r24d3TelemetryRun[0].status -ceq
        "artifact_complete_cold_build_and_post_adoption_full_conformance_qualified_characterization_withheld" -and
    [string]$r24d3TelemetryRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r24d3TelemetryRun[0].risk -ceq "long_running_safe" -and
    [string]$r24d3TelemetryRun[0].runner_path -ceq
        "sdk/run_qsdk_r24d3_instrumented_zero_world_gate.ps1" -and
    @($r24d3TelemetryRun[0].arguments).Count -eq 0 -and
    @($r24d3TelemetryRun[0].proofs).Count -eq 11 -and
    (
        @($r24d3TelemetryRun[0].proofs | ForEach-Object { [string]$_.path }) -join
        "|"
    ) -ceq (
        "sdk/recovery/r24d3_godot_jolt_motor_telemetry_source_v1.json|" +
        "sdk/recovery/r24d3_godot_jolt_motor_telemetry_source_validation_manifest.json|" +
        "sdk/recovery/r24d3_godot_jolt_motor_telemetry_artifact_complete_successor_v2.json|" +
        "sdk/recovery/r24d3_godot_jolt_motor_telemetry_cold_qualification_adoption_v2.json|" +
        "tests/test_qsdk_r24d3_godot_jolt_motor_telemetry_cold_qualification_adoption.ps1|" +
        "sdk/recovery/r24d3_godot_jolt_motor_telemetry_post_adoption_full_cold_conformance_qualification_v1.json|" +
        "tests/test_qsdk_r24d3_godot_jolt_motor_telemetry_post_adoption_full_cold_conformance_qualification.ps1|" +
        "tests/test_qsdk_r24d3_godot_jolt_motor_telemetry_source.ps1|" +
        "sdk/run_qsdk_r24d3_instrumented_zero_world_gate.ps1|" +
        "sdk/adapters/godot/engine_patches/godot_4_7_jolt_motor_telemetry.patch|" +
        "sdk/adapters/godot/engine_patches/README.md"
    ) -and
    $r24d3TelemetryRun[0].summary.Contains(
        "zero physics objects or solver steps"
    ) -and
    $r24d3TelemetryRun[0].summary.Contains(
        "positive but artifact-incomplete"
    ) -and
    $r24d3TelemetryRun[0].summary.Contains(
        "cold v2 successor is adopted"
    ) -and
    $r24d3TelemetryRun[0].summary.Contains(
        "all eight uncached canonical full-cold conformance stages"
    ) -and
    $r24d3TelemetryRun[0].claim_boundary.Contains(
        "Stock Godot remains 8/10"
    ) -and
    $r24d3TelemetryRun[0].claim_boundary.Contains(
        "exercised stock Godot, not the instrumented runtime"
    ) -and
    $r24d3TelemetryRun[0].claim_boundary.Contains(
        "establishes no recovery, prone-to-standing"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D3 telemetry exposure changed"

$r24d4TelemetryRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d4_godot_jolt_one_hinge_telemetry_freeze"
    }
)
Assert-Exact (
    $r24d4TelemetryRun.Count -eq 1 -and
    (@($r24d4TelemetryRun[0].engine_ids) -join "|") -ceq
        "all|godot_jolt" -and
    [string]$r24d4TelemetryRun[0].kind -ceq
        "instrumented_engine_zero_world_characterization_freeze_gate" -and
    [string]$r24d4TelemetryRun[0].status -ceq
        "prospective_source_and_oracle_freeze_zero_world_qualification_pending" -and
    [string]$r24d4TelemetryRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r24d4TelemetryRun[0].risk -ceq "long_running_safe" -and
    [string]$r24d4TelemetryRun[0].runner_path -ceq
        "sdk/run_qsdk_r24d4_one_hinge_telemetry_characterization.ps1" -and
    (@($r24d4TelemetryRun[0].arguments) -join "|") -ceq
        "-Mode|ZeroWorld" -and
    @($r24d4TelemetryRun[0].proofs).Count -eq 8 -and
    (
        @($r24d4TelemetryRun[0].proofs | ForEach-Object {
            [string]$_.path
        }) -join "|"
    ) -ceq (
        "sdk/recovery/r24d4_godot_jolt_one_hinge_telemetry_characterization_preregistration_v1.json|" +
        "sdk/recovery/r24d4_godot_jolt_one_hinge_telemetry_characterization_evaluator.py|" +
        "sdk/recovery/r24d4_godot_jolt_one_hinge_telemetry_validation_manifest.json|" +
        "scripts/lab/rigs/r24d4_godot_jolt_one_hinge_telemetry_rig.gd|" +
        "scripts/lab/rigs/r24d4_godot_jolt_telemetry_stepping_probe_body.gd|" +
        "tests/test_sdk_qsdk_r24d4_godot_jolt_one_hinge_telemetry_physical_worker.gd|" +
        "sdk/run_qsdk_r24d4_one_hinge_telemetry_characterization.ps1|" +
        "tests/test_qsdk_r24d4_one_hinge_telemetry_freeze.ps1"
    ) -and
    $r24d4TelemetryRun[0].summary.Contains(
        "twenty-two rejected structural mutations"
    ) -and
    $r24d4TelemetryRun[0].summary.Contains(
        "two accepted surprising finite outcomes"
    ) -and
    $r24d4TelemetryRun[0].claim_boundary.Contains(
        "opens no model, attempt, world, or solver step"
    ) -and
    $r24d4TelemetryRun[0].claim_boundary.Contains(
        "establishes no native characterization"
    ) -and
    $r24d4TelemetryRun[0].claim_boundary.Contains(
        "prone-to-standing"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D4 telemetry freeze exposure changed"

$r23d1ClosureRun = @(
    $catalog.runs | Where-Object { [string]$_.id -ceq "qsdk_r23d1_closure_audit" }
)
Assert-Exact (
    $r23d1ClosureRun.Count -eq 1 -and
    [string]$r23d1ClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d1ClosureRun[0].status -ceq
        "closed_consumed_implementation_invalid_incomplete_no_three_engine_result" -and
    [string]$r23d1ClosureRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d1ClosureRun[0].risk -ceq "safe" -and
    [string]$r23d1ClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d1_closure.ps1" -and
    @($r23d1ClosureRun[0].arguments).Count -eq 0
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D1 closure exposure changed"

$r23d2ClosureRun = @(
    $catalog.runs | Where-Object { [string]$_.id -ceq "qsdk_r23d2_closure_audit" }
)
$retiredR23D2Runs = @(
    $catalog.runs | Where-Object { [string]$_.id -cin @(
        "qsdk_r23d2_oracle_preflight",
        "qsdk_r23d2_rapier_worker_preflight",
        "qsdk_r23d2_mujoco_worker_preflight",
        "qsdk_r23d2_godot_jolt_worker_preflight",
        "qsdk_r23d2_supervisor_preflight"
    ) }
)
Assert-Exact (
    $r23d2ClosureRun.Count -eq 1 -and
    [string]$r23d2ClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d2ClosureRun[0].status -ceq
        "closed_consumed_invalid_incomplete_three_engine_aggregate_with_six_bounded_cell_results" -and
    [string]$r23d2ClosureRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d2ClosureRun[0].risk -ceq "safe" -and
    [string]$r23d2ClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d2_closure.ps1" -and
    @($r23d2ClosureRun[0].arguments).Count -eq 0 -and
    $retiredR23D2Runs.Count -eq 0
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D2 closure exposure changed"

$r23d5ClosureRun = @(
    $catalog.runs | Where-Object { [string]$_.id -ceq "qsdk_r23d5_closure_audit" }
)
Assert-Exact (
    $r23d5ClosureRun.Count -eq 1 -and
    [string]$r23d5ClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d5ClosureRun[0].status -ceq
        "closed_consumed_implementation_invalid_after_stage_a_worlds" -and
    [string]$r23d5ClosureRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d5ClosureRun[0].risk -ceq "safe" -and
    [string]$r23d5ClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d5_closure.ps1" -and
    @($r23d5ClosureRun[0].arguments).Count -eq 0 -and
    (@($r23d5ClosureRun[0].proofs | ForEach-Object { [string]$_.path }) -join "|") -ceq (
        "sdk/turning/r23d5_physical_closure_v1.json|" +
        "tests/test_qsdk_r23d5_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D5 closure exposure changed"

$r23d6ClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d6_closure_audit"
    }
)
Assert-Exact (
    $r23d6ClosureRun.Count -eq 1 -and
    [string]$r23d6ClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d6ClosureRun[0].status -ceq
        "closed_consumed_valid_none_stage_a_terminal_restoration_negative" -and
    [string]$r23d6ClosureRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d6ClosureRun[0].risk -ceq "safe" -and
    [string]$r23d6ClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d6_closure.ps1" -and
    @($r23d6ClosureRun[0].arguments).Count -eq 0 -and
    (@($r23d6ClosureRun[0].proofs | ForEach-Object { [string]$_.path }) -join "|") -ceq (
        "sdk/turning/r23d6_physical_closure_v1.json|" +
        "tests/test_qsdk_r23d6_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D6 closure exposure changed"

$r23d7ClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d7_closure_audit"
    }
)
Assert-Exact (
    $r23d7ClosureRun.Count -eq 1 -and
    [string]$r23d7ClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d7ClosureRun[0].status -ceq
        "closed_consumed_implementation_invalid_zero_world_dependency_authority_mismatch" -and
    [string]$r23d7ClosureRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d7ClosureRun[0].risk -ceq "safe" -and
    [string]$r23d7ClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d7_closure.ps1" -and
    @($r23d7ClosureRun[0].arguments).Count -eq 0 -and
    (@($r23d7ClosureRun[0].proofs | ForEach-Object { [string]$_.path }) -join "|") -ceq (
        "sdk/turning/r23d7_physical_closure_v1.json|" +
        "tests/test_qsdk_r23d7_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D7 closure exposure changed"

$r23d8ClosureRun = @(
    $catalog.runs | Where-Object { [string]$_.id -ceq "qsdk_r23d8_closure_audit" }
)
Assert-Exact (
    $r23d8ClosureRun.Count -eq 1 -and
    [string]$r23d8ClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d8ClosureRun[0].status -ceq
        "closed_consumed_valid_none_stage_a_neutral_stance_active_hold_negative" -and
    [string]$r23d8ClosureRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d8ClosureRun[0].risk -ceq "safe" -and
    [string]$r23d8ClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d8_closure.ps1" -and
    @($r23d8ClosureRun[0].arguments).Count -eq 0 -and
    (@($r23d8ClosureRun[0].proofs | ForEach-Object { [string]$_.path }) -join "|") -ceq (
        "sdk/turning/r23d8_physical_closure_v1.json|" +
        "tests/test_qsdk_r23d8_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D8 closure exposure changed"

$r23d9StageZeroRun = @(
    $catalog.runs | Where-Object { [string]$_.id -ceq "qsdk_r23d9_stage_zero" }
)
Assert-Exact (
    $r23d9StageZeroRun.Count -eq 1 -and
    [string]$r23d9StageZeroRun[0].kind -ceq "closure_audit" -and
    [string]$r23d9StageZeroRun[0].status -ceq
        "stage_zero_closed_at_clean_pushed_commit_53df1481_no_workers_no_physical_authorization" -and
    [string]$r23d9StageZeroRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d9StageZeroRun[0].risk -ceq "safe" -and
    [string]$r23d9StageZeroRun[0].runner_path -ceq
        "tests/test_qsdk_r23d9_stage_zero_closure.ps1" -and
    @($r23d9StageZeroRun[0].arguments).Count -eq 0 -and
    (@($r23d9StageZeroRun[0].proofs | ForEach-Object { [string]$_.path }) -join "|") -ceq (
        "sdk/turning/r23d9_support_handoff_preregistration_v1.json|" +
        "sdk/turning/test_r23d9_support_handoff.py|" +
        "tests/test_qsdk_r23d9_declaration.ps1|" +
        "tests/test_qsdk_r23d9_stage_zero_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D9 stage-zero exposure changed"

$r23d9NativeRoutesRun = @(
    $catalog.runs | Where-Object { [string]$_.id -ceq "qsdk_r23d9_native_routes" }
)
Assert-Exact (
    $r23d9NativeRoutesRun.Count -eq 1 -and
    [string]$r23d9NativeRoutesRun[0].kind -ceq "zero_world_preflight" -and
    [string]$r23d9NativeRoutesRun[0].status -ceq
        "stage_one_three_engine_zero_world_temporal_mirrors_physical_workers_not_implemented_no_physical_authorization" -and
    [string]$r23d9NativeRoutesRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d9NativeRoutesRun[0].risk -ceq "safe" -and
    [string]$r23d9NativeRoutesRun[0].runner_path -ceq
        "tests/test_qsdk_r23d9_native_routes.ps1" -and
    @($r23d9NativeRoutesRun[0].arguments).Count -eq 0 -and
    (@($r23d9NativeRoutesRun[0].proofs | ForEach-Object { [string]$_.path }) -join "|") -ceq (
        "sdk/turning/r23d9_native_route_contract_v1.json|" +
        "tests/test_qsdk_r23d9_native_routes.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D9 native-route exposure changed"

$r23d9StageTwoRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d9_stage_two_evidence"
    }
)
Assert-Exact (
    $r23d9StageTwoRun.Count -eq 1 -and
    [string]$r23d9StageTwoRun[0].kind -ceq "closure_audit" -and
    [string]$r23d9StageTwoRun[0].status -ceq
        "stage_two_closed_at_clean_pushed_commit_d2e36a1_no_physical_workers_or_authorization" -and
    [string]$r23d9StageTwoRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d9StageTwoRun[0].risk -ceq "safe" -and
    [string]$r23d9StageTwoRun[0].runner_path -ceq
        "tests/test_qsdk_r23d9_stage_two_closure.ps1" -and
    @($r23d9StageTwoRun[0].arguments).Count -eq 0 -and
    (@($r23d9StageTwoRun[0].proofs | ForEach-Object { [string]$_.path }) -join "|") -ceq (
        "tests/test_qsdk_r23d9_stage_two_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D9 stage-two exposure changed"

$r23d9ClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d9_physical_implementation_zero_world"
    }
)
Assert-Exact (
    $r23d9ClosureRun.Count -eq 1 -and
    [string]$r23d9ClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d9ClosureRun[0].status -ceq
        "closed_consumed_infrastructure_invalid_after_two_stage_a_worlds_evaluator_marker_mismatch" -and
    [string]$r23d9ClosureRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d9ClosureRun[0].risk -ceq "safe" -and
    [string]$r23d9ClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d9_closure.ps1" -and
    @($r23d9ClosureRun[0].arguments).Count -eq 0 -and
    (@($r23d9ClosureRun[0].proofs | ForEach-Object { [string]$_.path }) -join "|") -ceq (
        "sdk/turning/r23d9_physical_closure_v1.json|" +
        "tests/test_qsdk_r23d9_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D9 closure exposure changed"

$r23d10StageZeroRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d10_stage_zero"
    }
)
Assert-Exact (
    $r23d10StageZeroRun.Count -eq 1 -and
    [string]$r23d10StageZeroRun[0].kind -ceq "closure_audit" -and
    [string]$r23d10StageZeroRun[0].status -ceq
        "stage_zero_closed_at_clean_pushed_commit_6b39e1d_no_native_routes_or_physical_authorization" -and
    [string]$r23d10StageZeroRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d10StageZeroRun[0].risk -ceq "safe" -and
    [string]$r23d10StageZeroRun[0].runner_path -ceq
        "tests/test_qsdk_r23d10_stage_zero_closure.ps1" -and
    @($r23d10StageZeroRun[0].arguments).Count -eq 0 -and
    (@($r23d10StageZeroRun[0].proofs | ForEach-Object { [string]$_.path }) -join "|") -ceq (
        "sdk/turning/r23d10_quiescent_taper_preregistration_v1.json|" +
        "sdk/turning/r23d10_quiescent_taper.py|" +
        "sdk/turning/test_r23d10_quiescent_taper.py|" +
        "tests/test_qsdk_r23d10_stage_zero_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D10 stage-zero exposure changed"

$r23d10StageOneClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d10_stage_one_closure"
    }
)
Assert-Exact (
    $r23d10StageOneClosureRun.Count -eq 1 -and
    [string]$r23d10StageOneClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d10StageOneClosureRun[0].status -ceq
        "stage_one_closed_at_clean_pushed_commit_60f4753_no_physical_workers_or_authorization" -and
    [string]$r23d10StageOneClosureRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d10StageOneClosureRun[0].risk -ceq "safe" -and
    [string]$r23d10StageOneClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d10_stage_one_closure.ps1" -and
    @($r23d10StageOneClosureRun[0].arguments).Count -eq 0 -and
    (@($r23d10StageOneClosureRun[0].proofs | ForEach-Object { [string]$_.path }) -join "|") -ceq (
        "sdk/turning/r23d10_native_route_contract_v1.json|" +
        "tests/test_qsdk_r23d10_native_routes.ps1|" +
        "tests/test_qsdk_r23d10_stage_one_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D10 stage-one closure exposure changed"

$r23d10StageTwoClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d10_stage_two_closure"
    }
)
Assert-Exact (
    $r23d10StageTwoClosureRun.Count -eq 1 -and
    [string]$r23d10StageTwoClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d10StageTwoClosureRun[0].status -ceq
        "stage_two_closed_at_clean_pushed_commit_94f724a_no_physical_workers_or_authorization" -and
    [string]$r23d10StageTwoClosureRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d10StageTwoClosureRun[0].risk -ceq "safe" -and
    [string]$r23d10StageTwoClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d10_stage_two_closure.ps1" -and
    @($r23d10StageTwoClosureRun[0].arguments).Count -eq 0 -and
    (@($r23d10StageTwoClosureRun[0].proofs | ForEach-Object { [string]$_.path }) -join "|") -ceq (
        "sdk/turning/r23d10_stage_two_evidence_contract_v1.json|" +
        "tests/test_qsdk_r23d10_stage_two_evidence.ps1|" +
        "tests/test_qsdk_r23d10_stage_two_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D10 stage-two closure exposure changed"

$r23d10PhysicalClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d10_physical_closure"
    }
)
Assert-Exact (
    $r23d10PhysicalClosureRun.Count -eq 1 -and
    [string]$r23d10PhysicalClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d10PhysicalClosureRun[0].status -ceq
        "closed_consumed_valid_none_stage_a_negative_heading_quiescent_taper_failure_stage_b_unopened" -and
    [string]$r23d10PhysicalClosureRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d10PhysicalClosureRun[0].risk -ceq "safe" -and
    [string]$r23d10PhysicalClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d10_closure.ps1" -and
    @($r23d10PhysicalClosureRun[0].arguments).Count -eq 0 -and
    (@($r23d10PhysicalClosureRun[0].proofs | ForEach-Object { [string]$_.path }) -join "|") -ceq (
        "sdk/turning/r23d10_physical_closure_v1.json|" +
        "tests/test_qsdk_r23d10_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D10 physical closure exposure changed"

$r23d11StageOneClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d11_stage_one_closure"
    }
)
Assert-Exact (
    $r23d11StageOneClosureRun.Count -eq 1 -and
    [string]$r23d11StageOneClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d11StageOneClosureRun[0].status -ceq
        "immutable_stage_one_three_engine_zero_world_composition_mirrors" -and
    [string]$r23d11StageOneClosureRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d11StageOneClosureRun[0].risk -ceq "safe" -and
    [string]$r23d11StageOneClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d11_stage_one_closure.ps1" -and
    @($r23d11StageOneClosureRun[0].arguments).Count -eq 0 -and
    (@($r23d11StageOneClosureRun[0].proofs | ForEach-Object { [string]$_.path }) -join "|") -ceq (
        "sdk/turning/r23d11_stability_assisted_taper_preregistration_v1.json|" +
        "sdk/turning/r23d11_stability_assisted_taper.py|" +
        "tests/test_qsdk_r23d11_stage_zero_closure.ps1|" +
        "sdk/turning/r23d11_native_route_contract_v1.json|" +
        "tests/test_qsdk_r23d11_stage_one_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D11 stage-one closure exposure changed"

$r23d11PhysicalClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d11_physical_closure"
    }
)
Assert-Exact (
    $r23d11PhysicalClosureRun.Count -eq 1 -and
    [string]$r23d11PhysicalClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d11PhysicalClosureRun[0].status -ceq
        "closed_consumed_infrastructure_invalid_trace_diagnostic_semantics_mismatch_stage_b_unopened" -and
    [string]$r23d11PhysicalClosureRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d11PhysicalClosureRun[0].risk -ceq "safe" -and
    [string]$r23d11PhysicalClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d11_closure.ps1" -and
    @($r23d11PhysicalClosureRun[0].arguments).Count -eq 0 -and
    (@($r23d11PhysicalClosureRun[0].proofs | ForEach-Object { [string]$_.path }) -join "|") -ceq (
        "sdk/turning/r23d11_physical_closure_v1.json|" +
        "tests/test_qsdk_r23d11_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D11 physical closure exposure changed"

$r23d12StageZeroClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d12_stage_zero_closure"
    }
)
Assert-Exact (
    $r23d12StageZeroClosureRun.Count -eq 1 -and
    [string]$r23d12StageZeroClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d12StageZeroClosureRun[0].status -ceq
        "stage_zero_closed_at_commit_6116fce_no_native_routes_or_physical_authorization" -and
    [string]$r23d12StageZeroClosureRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d12StageZeroClosureRun[0].risk -ceq "safe" -and
    [string]$r23d12StageZeroClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d12_stage_zero_closure.ps1" -and
    @($r23d12StageZeroClosureRun[0].arguments).Count -eq 0 -and
    (@($r23d12StageZeroClosureRun[0].proofs | ForEach-Object { [string]$_.path }) -join "|") -ceq (
        "sdk/turning/r23d12_measurement_semantics_preregistration_v1.json|" +
        "sdk/turning/r23d12_measurement_semantics.py|" +
        "sdk/turning/test_r23d12_measurement_semantics.py|" +
        "tests/test_qsdk_r23d12_declaration.ps1|" +
        "sdk/run_qsdk_r23d12_stage_zero_gate.ps1|" +
        "tests/test_qsdk_r23d12_stage_zero_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D12 stage-zero closure exposure changed"

$r23d12StageOneClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d12_stage_one_closure"
    }
)
Assert-Exact (
    $r23d12StageOneClosureRun.Count -eq 1 -and
    [string]$r23d12StageOneClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d12StageOneClosureRun[0].status -ceq
        "stage_one_closed_three_native_semantics_vectors_exact_no_workers_or_physical_authorization" -and
    [string]$r23d12StageOneClosureRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d12StageOneClosureRun[0].risk -ceq "safe" -and
    [string]$r23d12StageOneClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d12_stage_one_closure.ps1" -and
    @($r23d12StageOneClosureRun[0].arguments).Count -eq 0 -and
    (@($r23d12StageOneClosureRun[0].proofs | ForEach-Object { [string]$_.path }) -join "|") -ceq (
        "sdk/turning/r23d12_native_semantics_contract_v1.json|" +
        "tests/test_qsdk_r23d12_native_semantics.ps1|" +
        "sdk/run_qsdk_r23d12_stage_one_gate.ps1|" +
        "tests/test_qsdk_r23d12_stage_one_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D12 stage-one closure exposure changed"

$r23d12StageTwoClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d12_stage_two_closure"
    }
)
Assert-Exact (
    $r23d12StageTwoClosureRun.Count -eq 1 -and
    [string]$r23d12StageTwoClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d12StageTwoClosureRun[0].status -ceq
        "stage_two_closed_production_trace_cas_and_evaluator_no_workers_or_physical_authorization" -and
    [string]$r23d12StageTwoClosureRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r23d12StageTwoClosureRun[0].risk -ceq "safe" -and
    [string]$r23d12StageTwoClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d12_stage_two_closure.ps1" -and
    @($r23d12StageTwoClosureRun[0].arguments).Count -eq 0 -and
    (@($r23d12StageTwoClosureRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "sdk/turning/r23d12_stage_two_evidence_contract_v1.json|" +
        "tests/test_qsdk_r23d12_stage_two_evidence.ps1|" +
        "tests/test_qsdk_r23d12_stage_two_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D12 stage-two closure exposure changed"

$r23d12PhysicalClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d12_physical_closure"
    }
)
Assert-Exact (
    $r23d12PhysicalClosureRun.Count -eq 1 -and
    [string]$r23d12PhysicalClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r23d12PhysicalClosureRun[0].status -ceq
        "closed_consumed_valid_none_stage_a_negative_heading_quiescent_taper_failure_stage_b_unopened" -and
    [string]$r23d12PhysicalClosureRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d12PhysicalClosureRun[0].risk -ceq "safe" -and
    [string]$r23d12PhysicalClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r23d12_closure.ps1" -and
    @($r23d12PhysicalClosureRun[0].arguments).Count -eq 0 -and
    (@($r23d12PhysicalClosureRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "sdk/turning/r23d12_physical_closure_v1.json|" +
        "tests/test_qsdk_r23d12_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D12 physical closure exposure changed"

$r23d13StageZeroRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d13_stage_zero"
    }
)
Assert-Exact (
    $r23d13StageZeroRun.Count -eq 1 -and
    [string]$r23d13StageZeroRun[0].kind -ceq
        "closure_audit" -and
    [string]$r23d13StageZeroRun[0].status -ceq
        "closed_immutable_stage_zero_zero_world_only" -and
    [string]$r23d13StageZeroRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d13StageZeroRun[0].risk -ceq "safe" -and
    [string]$r23d13StageZeroRun[0].runner_path -ceq
        "tests/test_qsdk_r23d13_stage_zero_closure.ps1" -and
    @($r23d13StageZeroRun[0].arguments).Count -eq 0 -and
    (@($r23d13StageZeroRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "sdk/turning/r23d13_residual_pose_authority_preregistration_v1.json|" +
        "sdk/turning/r23d13_residual_pose_authority.py|" +
        "sdk/turning/test_r23d13_residual_pose_authority.py|" +
        "tests/test_qsdk_r23d13_declaration.ps1|" +
        "sdk/run_qsdk_r23d13_stage_zero_gate.ps1|" +
        "tests/test_qsdk_r23d13_stage_zero_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D13 stage-zero exposure changed"

$r23d13StageOneRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d13_stage_one"
    }
)
Assert-Exact (
    $r23d13StageOneRun.Count -eq 1 -and
    [string]$r23d13StageOneRun[0].kind -ceq
        "closure_audit" -and
    [string]$r23d13StageOneRun[0].status -ceq
        "closed_immutable_stage_one_three_engine_zero_world_native_authority_mirrors" -and
    [string]$r23d13StageOneRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d13StageOneRun[0].risk -ceq "safe" -and
    [string]$r23d13StageOneRun[0].runner_path -ceq
        "tests/test_qsdk_r23d13_stage_one_closure.ps1" -and
    @($r23d13StageOneRun[0].arguments).Count -eq 0 -and
    (@($r23d13StageOneRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "sdk/turning/r23d13_native_route_contract_v1.json|" +
        "tests/test_qsdk_r23d13_native_routes.ps1|" +
        "sdk/run_qsdk_r23d13_stage_one_gate.ps1|" +
        "tests/test_qsdk_r23d13_stage_one_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D13 stage-one exposure changed"

$r23d13StageTwoRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r23d13_stage_two"
    }
)
Assert-Exact (
    $r23d13StageTwoRun.Count -eq 1 -and
    [string]$r23d13StageTwoRun[0].kind -ceq
        "zero_world_evidence_conformance_gate" -and
    [string]$r23d13StageTwoRun[0].status -ceq
        "stage_two_trace_authority_diagnostics_cas_and_evaluator_qualified_no_workers_no_physical_authorization" -and
    [string]$r23d13StageTwoRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r23d13StageTwoRun[0].risk -ceq "safe" -and
    [string]$r23d13StageTwoRun[0].runner_path -ceq
        "sdk/run_qsdk_r23d13_stage_two_gate.ps1" -and
    @($r23d13StageTwoRun[0].arguments).Count -eq 0 -and
    (@($r23d13StageTwoRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "sdk/turning/r23d13_stage_two_evidence_contract_v1.json|" +
        "tests/test_qsdk_r23d13_stage_two_evidence.ps1|" +
        "sdk/run_qsdk_r23d13_stage_two_gate.ps1|" +
        "tests/test_qsdk_r23d13_stage_one_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R23D13 stage-two exposure changed"

$bw22lClosureRun = @(
    $catalog.runs | Where-Object { [string]$_.id -ceq "bw22l_closure" }
)
Assert-Exact (
    $bw22lClosureRun.Count -eq 1 -and
    [string]$bw22lClosureRun[0].kind -ceq "closure_audit" -and
    [string]$bw22lClosureRun[0].status -ceq
        "closed_invalid_final_receipt_composition_mismatch" -and
    [string]$bw22lClosureRun[0].runner_path -ceq
        "tests/test_bw22l_lateral_development_closure.ps1" -and
    @($bw22lClosureRun[0].arguments).Count -eq 0
) "LOCOMOTION_EXPERIMENT_WORKBENCH BW22L closure exposure changed"

$rapierPh1ClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "rapier_bw19v_ph1_closure_audit"
    }
)
Assert-Exact (
    $rapierPh1ClosureRun.Count -eq 1 -and
    [string]$rapierPh1ClosureRun[0].kind -ceq
        "selected_policy_consumed_attempt_closure_audit" -and
    [string]$rapierPh1ClosureRun[0].status -ceq
        "closed_complete_valid_positive_exact_s169_pose_hold_restoration_and_finite_walking_contract" -and
    [string]$rapierPh1ClosureRun[0].world_policy -ceq "zero_world_only" -and
    [string]$rapierPh1ClosureRun[0].risk -ceq "safe" -and
    [string]$rapierPh1ClosureRun[0].runner_path -ceq
        "tests/test_rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.ps1" -and
    @($rapierPh1ClosureRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($rapierPh1ClosureRun[0].arguments)
) "LOCOMOTION_EXPERIMENT_WORKBENCH Rapier PH1 safe closure exposure changed"

$mujocoMv4ClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "mujoco_bw19v_mv4_closure_audit"
    }
)
Assert-Exact (
    $mujocoMv4ClosureRun.Count -eq 1 -and
    [string]$mujocoMv4ClosureRun[0].kind -ceq
        "selected_policy_consumed_attempt_closure_audit" -and
    [string]$mujocoMv4ClosureRun[0].status -ceq
        "closed_consumed_implementation_invalid_no_physical_report" -and
    [string]$mujocoMv4ClosureRun[0].world_policy -ceq "zero_world_only" -and
    [string]$mujocoMv4ClosureRun[0].risk -ceq "safe" -and
    [string]$mujocoMv4ClosureRun[0].runner_path -ceq
        "tests/test_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv4_closure.ps1" -and
    @($mujocoMv4ClosureRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($mujocoMv4ClosureRun[0].arguments)
) "LOCOMOTION_EXPERIMENT_WORKBENCH MuJoCo MV4 safe closure exposure changed"

$mujocoMv5ClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "mujoco_bw19v_mv5_closure_audit"
    }
)
Assert-Exact (
    $mujocoMv5ClosureRun.Count -eq 1 -and
    [string]$mujocoMv5ClosureRun[0].kind -ceq
        "selected_policy_consumed_attempt_closure_audit" -and
    [string]$mujocoMv5ClosureRun[0].status -ceq
        "closed_consumed_implementation_invalid_no_physical_report" -and
    [string]$mujocoMv5ClosureRun[0].world_policy -ceq "zero_world_only" -and
    [string]$mujocoMv5ClosureRun[0].risk -ceq "safe" -and
    [string]$mujocoMv5ClosureRun[0].runner_path -ceq
        "tests/test_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv5_closure.ps1" -and
    @($mujocoMv5ClosureRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($mujocoMv5ClosureRun[0].arguments)
) "LOCOMOTION_EXPERIMENT_WORKBENCH MuJoCo MV5 safe closure exposure changed"

$mujocoMv6ClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "mujoco_bw19v_mv6_closure_audit"
    }
)
Assert-Exact (
    $mujocoMv6ClosureRun.Count -eq 1 -and
    [string]$mujocoMv6ClosureRun[0].kind -ceq
        "selected_policy_consumed_attempt_closure_audit" -and
    [string]$mujocoMv6ClosureRun[0].status -ceq
        "closed_complete_valid_positive_exact_s169_pose_hold_restoration_and_finite_walking_contract" -and
    [string]$mujocoMv6ClosureRun[0].world_policy -ceq "zero_world_only" -and
    [string]$mujocoMv6ClosureRun[0].risk -ceq "safe" -and
    [string]$mujocoMv6ClosureRun[0].runner_path -ceq
        "tests/test_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_closure.ps1" -and
    @($mujocoMv6ClosureRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($mujocoMv6ClosureRun[0].arguments)
) "LOCOMOTION_EXPERIMENT_WORKBENCH MuJoCo MV6 safe closure exposure changed"

$crossEngineXv1ClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "cross_engine_bw19v_xv1_closure_audit"
    }
)
Assert-Exact (
    $crossEngineXv1ClosureRun.Count -eq 1 -and
    [string]$crossEngineXv1ClosureRun[0].kind -ceq
        "selected_policy_consumed_attempt_closure_audit" -and
    [string]$crossEngineXv1ClosureRun[0].status -ceq
        "closed_consumed_implementation_invalid_incomplete_no_aggregate_result" -and
    [string]$crossEngineXv1ClosureRun[0].world_policy -ceq "zero_world_only" -and
    [string]$crossEngineXv1ClosureRun[0].risk -ceq "safe" -and
    [string]$crossEngineXv1ClosureRun[0].runner_path -ceq
        "tests/test_cross_engine_c6_bw19v_discrete_material_validation_xv1_closure.ps1" -and
    @($crossEngineXv1ClosureRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($crossEngineXv1ClosureRun[0].arguments)
) "LOCOMOTION_EXPERIMENT_WORKBENCH XV1 closure exposure changed"

$crossEngineXv2ClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "cross_engine_bw19v_xv2_closure_audit"
    }
)
Assert-Exact (
    $crossEngineXv2ClosureRun.Count -eq 1 -and
    [string]$crossEngineXv2ClosureRun[0].kind -ceq
        "selected_policy_consumed_attempt_closure_audit" -and
    [string]$crossEngineXv2ClosureRun[0].status -ceq
        "closed_complete_valid_positive_via_frozen_zero_world_aggregate_reconstruction_after_original_post_worker_implementation_failure" -and
    [string]$crossEngineXv2ClosureRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$crossEngineXv2ClosureRun[0].risk -ceq "safe" -and
    [string]$crossEngineXv2ClosureRun[0].runner_path -ceq
        "tests/test_cross_engine_c6_bw19v_discrete_material_validation_xv2_closure.ps1" -and
    @($crossEngineXv2ClosureRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($crossEngineXv2ClosureRun[0].arguments)
) "LOCOMOTION_EXPERIMENT_WORKBENCH XV2 closure exposure changed"

$r24d4ZeroWorldClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r24d4_zero_world_failure_closure"
    }
)
Assert-Exact (
    $r24d4ZeroWorldClosureRun.Count -eq 1 -and
    [string]$r24d4ZeroWorldClosureRun[0].kind -ceq "closure_audit" -and
    [string]$r24d4ZeroWorldClosureRun[0].status -ceq
        "valid_zero_world_negative_source_oracle_axis_mismatch_physical_world_never_opened" -and
    [string]$r24d4ZeroWorldClosureRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d4ZeroWorldClosureRun[0].risk -ceq "safe" -and
    [string]$r24d4ZeroWorldClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r24d4_one_hinge_telemetry_zero_world_failure_closure.ps1" -and
    @($r24d4ZeroWorldClosureRun[0].arguments).Count -eq 0
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D4 closure exposure changed"

$r24d5PhysicalFailureClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r24d5_physical_failure_closure"
    }
)
Assert-Exact (
    $r24d5PhysicalFailureClosureRun.Count -eq 1 -and
    [string]$r24d5PhysicalFailureClosureRun[0].kind -ceq
        "physical_failure_closure_audit" -and
    [string]$r24d5PhysicalFailureClosureRun[0].status -ceq
        "closed_consumed_invalid_fixture_json_identity_mismatch_distinct_successor_required" -and
    [string]$r24d5PhysicalFailureClosureRun[0].world_policy -ceq "zero_world_only" -and
    [string]$r24d5PhysicalFailureClosureRun[0].risk -ceq "safe" -and
    [string]$r24d5PhysicalFailureClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r24d5_one_hinge_telemetry_physical_failure_closure.ps1" -and
    @($r24d5PhysicalFailureClosureRun[0].arguments).Count -eq 0
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D5 physical failure closure exposure changed"

$r24d6ProspectiveFreezeRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r24d6_prospective_freeze"
    }
)
Assert-Exact (
    $r24d6ProspectiveFreezeRun.Count -eq 1 -and
    [string]$r24d6ProspectiveFreezeRun[0].kind -ceq
        "zero_world_conformance_gate" -and
    [string]$r24d6ProspectiveFreezeRun[0].status -ceq
        "closed_consumed_valid_zero_world_negative_integral_variant_type_loss_distinct_successor_required" -and
    [string]$r24d6ProspectiveFreezeRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d6ProspectiveFreezeRun[0].risk -ceq "safe" -and
    [string]$r24d6ProspectiveFreezeRun[0].runner_path -ceq
        "tests/test_qsdk_r24d6_one_hinge_telemetry_freeze.ps1" -and
    @($r24d6ProspectiveFreezeRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d6ProspectiveFreezeRun[0].arguments) -and
    "Physical" -cnotin @($r24d6ProspectiveFreezeRun[0].arguments)
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D6 prospective freeze exposure changed"

$r24d6ZeroWorldFailureClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r24d6_zero_world_failure_closure"
    }
)
Assert-Exact (
    $r24d6ZeroWorldFailureClosureRun.Count -eq 1 -and
    [string]$r24d6ZeroWorldFailureClosureRun[0].kind -ceq
        "zero_world_failure_closure_audit" -and
    [string]$r24d6ZeroWorldFailureClosureRun[0].status -ceq
        "valid_zero_world_negative_full_precision_integral_variant_type_loss_distinct_successor_required" -and
    [string]$r24d6ZeroWorldFailureClosureRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d6ZeroWorldFailureClosureRun[0].risk -ceq "safe" -and
    [string]$r24d6ZeroWorldFailureClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r24d6_one_hinge_telemetry_zero_world_failure_closure.ps1" -and
    @($r24d6ZeroWorldFailureClosureRun[0].arguments).Count -eq 0 -and
    (@($r24d6ZeroWorldFailureClosureRun[0].proofs | ForEach-Object { [string]$_.path }) -join "|") -ceq (
        "sdk/recovery/r24d6_godot_jolt_one_hinge_telemetry_zero_world_failure_closure_v1.json|" +
        "tests/test_qsdk_r24d6_one_hinge_telemetry_zero_world_failure_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D6 zero-world failure closure exposure changed"

$r24d7ProspectiveFreezeRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r24d7_prospective_freeze"
    }
)
Assert-Exact (
    $r24d7ProspectiveFreezeRun.Count -eq 1 -and
    [string]$r24d7ProspectiveFreezeRun[0].kind -ceq
        "zero_world_conformance_gate" -and
    [string]$r24d7ProspectiveFreezeRun[0].status -ceq
        "closed_consumed_zero_world_qualified_physical_attempt_implementation_invalid_distinct_successor_required" -and
    [string]$r24d7ProspectiveFreezeRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d7ProspectiveFreezeRun[0].risk -ceq "safe" -and
    [string]$r24d7ProspectiveFreezeRun[0].runner_path -ceq
        "tests/test_qsdk_r24d7_one_hinge_telemetry_freeze.ps1" -and
    @($r24d7ProspectiveFreezeRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d7ProspectiveFreezeRun[0].arguments) -and
    "Physical" -cnotin @($r24d7ProspectiveFreezeRun[0].arguments) -and
    (@($r24d7ProspectiveFreezeRun[0].proofs | ForEach-Object { [string]$_.path }) -join "|") -ceq (
        "sdk/recovery/r24d7_godot_jolt_one_hinge_telemetry_characterization_preregistration_v1.json|" +
        "sdk/recovery/r24d7_integral_variant_schema_v1.json|" +
        "sdk/recovery/r24d7_godot_jolt_one_hinge_telemetry_validation_manifest.json|" +
        "sdk/recovery/r24d7_precommit_godot_parser_diagnostics_v1.json|" +
        "tests/test_qsdk_r24d7_one_hinge_telemetry_freeze.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D7 prospective freeze exposure changed"

$r24d7PhysicalFailureClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r24d7_physical_failure_closure"
    }
)
Assert-Exact (
    $r24d7PhysicalFailureClosureRun.Count -eq 1 -and
    [string]$r24d7PhysicalFailureClosureRun[0].kind -ceq
        "physical_failure_closure_audit" -and
    [string]$r24d7PhysicalFailureClosureRun[0].status -ceq
        "closed_zero_world_qualified_physical_attempt_implementation_invalid_callback_outside_stepping_window_distinct_successor_required" -and
    [string]$r24d7PhysicalFailureClosureRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d7PhysicalFailureClosureRun[0].risk -ceq "safe" -and
    [string]$r24d7PhysicalFailureClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r24d7_one_hinge_telemetry_physical_failure_closure.ps1" -and
    @($r24d7PhysicalFailureClosureRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d7PhysicalFailureClosureRun[0].arguments) -and
    "Physical" -cnotin @($r24d7PhysicalFailureClosureRun[0].arguments) -and
    (@($r24d7PhysicalFailureClosureRun[0].proofs | ForEach-Object { [string]$_.path }) -join "|") -ceq (
        "sdk/recovery/r24d7_godot_jolt_one_hinge_telemetry_physical_failure_closure_v1.json|" +
        "tests/test_qsdk_r24d7_one_hinge_telemetry_physical_failure_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D7 physical failure closure exposure changed"

$r24d8ProspectiveFreezeRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r24d8_prospective_freeze"
    }
)
Assert-Exact (
    $r24d8ProspectiveFreezeRun.Count -eq 1 -and
    [string]$r24d8ProspectiveFreezeRun[0].kind -ceq
        "zero_world_conformance_gate" -and
    [string]$r24d8ProspectiveFreezeRun[0].status -ceq
        "historical_positive_closure_preserved_later_r24d9_step_token_audit_disqualified_valid_campaign_authority" -and
    [string]$r24d8ProspectiveFreezeRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d8ProspectiveFreezeRun[0].risk -ceq "safe" -and
    [string]$r24d8ProspectiveFreezeRun[0].runner_path -ceq
        "tests/test_qsdk_r24d8_active_step_snapshot_timing_positive_closure.ps1" -and
    @($r24d8ProspectiveFreezeRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d8ProspectiveFreezeRun[0].arguments) -and
    "Physical" -cnotin @($r24d8ProspectiveFreezeRun[0].arguments) -and
    (@($r24d8ProspectiveFreezeRun[0].proofs | ForEach-Object { [string]$_.path }) -join "|") -ceq (
        "sdk/recovery/r24d8_godot_jolt_active_step_snapshot_timing_preregistration_v1.json|" +
        "sdk/recovery/r24d8_precommit_zero_world_diagnostics_v1.json|" +
        "sdk/recovery/r24d8_first_official_zero_world_qualification_failure_v1.json|" +
        "sdk/recovery/r24d8_maintenance_precommit_diagnostics_v1.json|" +
        "sdk/recovery/r24d8_godot_jolt_active_step_snapshot_timing_validation_manifest.json|" +
        "sdk/adapters/godot/engine_patches/godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch|" +
        "tests/test_qsdk_r24d8_predecessor_evidence_compatibility.ps1|" +
        "tests/test_qsdk_r24d8_godot_jolt_active_step_snapshot_timing_freeze.ps1|" +
        "sdk/recovery/r24d8_godot_jolt_active_step_snapshot_timing_positive_closure_v1.json|" +
        "sdk/recovery/r24d8_positive_closure_precommit_diagnostics_v1.json|" +
        "tests/test_qsdk_r24d8_active_step_snapshot_timing_positive_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D8 timing-positive closure exposure changed"

$r24d9PreregistrationRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq "qsdk_r24d9_numerical_telemetry_preregistration"
    }
)
Assert-Exact (
    $r24d9PreregistrationRun.Count -eq 1 -and
    [string]$r24d9PreregistrationRun[0].kind -ceq
        "zero_world_conformance_gate" -and
    [string]$r24d9PreregistrationRun[0].status -ceq
        "historical_declaration_audit_parent_authorization_later_found_inadequate_r24d9_consumed_invalid" -and
    [string]$r24d9PreregistrationRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d9PreregistrationRun[0].risk -ceq "safe" -and
    [string]$r24d9PreregistrationRun[0].runner_path -ceq
        "tests/test_qsdk_r24d9_numerical_telemetry_preregistration.ps1" -and
    @($r24d9PreregistrationRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d9PreregistrationRun[0].arguments) -and
    "Physical" -cnotin @($r24d9PreregistrationRun[0].arguments) -and
    (@($r24d9PreregistrationRun[0].proofs | ForEach-Object { [string]$_.path }) -join "|") -ceq (
        "sdk/recovery/r24d8_godot_jolt_active_step_snapshot_timing_positive_closure_v1.json|" +
        "sdk/adapters/godot/engine_patches/godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch|" +
        "sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_characterization_preregistration_v1.json|" +
        "tests/test_qsdk_r24d9_numerical_telemetry_preregistration.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D9 declaration exposure changed"

$r24d9ImplementationRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d9_numerical_telemetry_implementation_freeze"
    }
)
Assert-Exact (
    $r24d9ImplementationRun.Count -eq 1 -and
    [string]$r24d9ImplementationRun[0].kind -ceq
        "zero_world_conformance_gate" -and
    [string]$r24d9ImplementationRun[0].status -ceq
        "historical_implementation_freeze_zero_world_later_passed_physical_attempt_consumed_and_closed_invalid" -and
    [string]$r24d9ImplementationRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d9ImplementationRun[0].risk -ceq "safe" -and
    [string]$r24d9ImplementationRun[0].runner_path -ceq
        "tests/test_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_freeze.ps1" -and
    @($r24d9ImplementationRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d9ImplementationRun[0].arguments) -and
    "Physical" -cnotin @($r24d9ImplementationRun[0].arguments) -and
    (@($r24d9ImplementationRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_characterization_preregistration_v1.json|" +
        "tests/test_qsdk_r24d9_numerical_telemetry_preregistration.ps1|" +
        "sdk/recovery/r24d9_precommit_zero_world_diagnostics_v1.json|" +
        "scripts/lab/rigs/r24d9_godot_jolt_one_hinge_numerical_telemetry_rig.gd|" +
        "tests/test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_worker.gd|" +
        "sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_characterization_evaluator.py|" +
        "sdk/run_qsdk_r24d9_one_hinge_numerical_telemetry_characterization.ps1|" +
        "tests/test_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_freeze.ps1|" +
        "sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_validation_manifest.json"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D9 implementation exposure changed"

$r24d9PhysicalFailureClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d9_numerical_telemetry_physical_failure_closure"
    }
)
Assert-Exact (
    $r24d9PhysicalFailureClosureRun.Count -eq 1 -and
    [string]$r24d9PhysicalFailureClosureRun[0].kind -ceq
        "physical_failure_closure_audit" -and
    [string]$r24d9PhysicalFailureClosureRun[0].status -ceq
        "closed_zero_world_qualified_physical_attempt_implementation_invalid_extra_unretained_step_and_initial_state_loss_distinct_successor_required" -and
    [string]$r24d9PhysicalFailureClosureRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d9PhysicalFailureClosureRun[0].risk -ceq "safe" -and
    [string]$r24d9PhysicalFailureClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r24d9_one_hinge_numerical_telemetry_physical_failure_closure.ps1" -and
    @($r24d9PhysicalFailureClosureRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d9PhysicalFailureClosureRun[0].arguments) -and
    "Physical" -cnotin @($r24d9PhysicalFailureClosureRun[0].arguments) -and
    (@($r24d9PhysicalFailureClosureRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_physical_failure_closure_v1.json|" +
        "tests/test_qsdk_r24d9_one_hinge_numerical_telemetry_physical_failure_closure.ps1"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D9 physical failure closure exposure changed"

$r24d10ImplementationRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d10_exact_step_numerical_telemetry_implementation_freeze"
    }
)
Assert-Exact (
    $r24d10ImplementationRun.Count -eq 1 -and
    [string]$r24d10ImplementationRun[0].kind -ceq
        "zero_world_conformance_gate" -and
    [string]$r24d10ImplementationRun[0].status -ceq
        "complete_zero_world_gate_passed_physical_execution_still_forbidden_pending_explicit_separate_authorization" -and
    [string]$r24d10ImplementationRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d10ImplementationRun[0].risk -ceq "safe" -and
    [string]$r24d10ImplementationRun[0].runner_path -ceq
        "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_freeze.ps1" -and
    @($r24d10ImplementationRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d10ImplementationRun[0].arguments) -and
    "Physical" -cnotin @($r24d10ImplementationRun[0].arguments) -and
    (@($r24d10ImplementationRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_physical_failure_closure_v1.json|" +
        "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_characterization_preregistration_v1.json|" +
        "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_preregistration.py|" +
        "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_characterization_evaluator.py|" +
        "scripts/lab/rigs/r24d10_godot_jolt_exact_step_numerical_telemetry_rig.gd|" +
        "tests/test_sdk_qsdk_r24d10_godot_jolt_exact_step_numerical_telemetry_worker.gd|" +
        "tests/test_qsdk_r24d10_exact_step_source.py|" +
        "sdk/run_qsdk_r24d10_exact_step_numerical_telemetry_zero_world_gate.ps1|" +
        "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_freeze.ps1|" +
        "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_validation_manifest.json|" +
        "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_zero_world_positive_closure_v1.json|" +
        "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_zero_world_positive_closure.ps1|" +
        "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_zero_world_positive_closure.py"
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D10 implementation exposure changed"

$r24d10FirstSupervisorRefusalRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d10_first_physical_supervisor_qualification_adoption_refusal"
    }
)
Assert-Exact (
    $r24d10FirstSupervisorRefusalRun.Count -eq 1 -and
    [string]$r24d10FirstSupervisorRefusalRun[0].kind -ceq
        "zero_world_qualification_adoption_refusal_audit" -and
    [string]$r24d10FirstSupervisorRefusalRun[0].status -ceq
        "v1_preflight_passed_zero_world_only_adoption_refused_v2_successor_required" -and
    [string]$r24d10FirstSupervisorRefusalRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d10FirstSupervisorRefusalRun[0].risk -ceq "safe" -and
    [string]$r24d10FirstSupervisorRefusalRun[0].runner_path -ceq
        "tests/test_qsdk_r24d10_first_physical_supervisor_qualification_adoption_refusal.py" -and
    @($r24d10FirstSupervisorRefusalRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d10FirstSupervisorRefusalRun[0].arguments) -and
    "Physical" -cnotin @($r24d10FirstSupervisorRefusalRun[0].arguments) -and
    (@($r24d10FirstSupervisorRefusalRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "sdk/recovery/r24d10_first_physical_supervisor_qualification_adoption_refusal_v1.json|" +
        "tests/test_qsdk_r24d10_first_physical_supervisor_qualification_adoption_refusal.py"
    ) -and
    $r24d10FirstSupervisorRefusalRun[0].summary.Contains(
        "actual 0/0/0 execution",
        [StringComparison]::Ordinal
    ) -and
    $r24d10FirstSupervisorRefusalRun[0].claim_boundary.Contains(
        "grants no physical authority",
        [StringComparison]::Ordinal
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D10 first supervisor refusal exposure changed"

$r24d10V2SupervisorSourceRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d10_v2_parent_bound_physical_supervisor_source"
    }
)
Assert-Exact (
    $r24d10V2SupervisorSourceRun.Count -eq 1 -and
    [string]$r24d10V2SupervisorSourceRun[0].kind -ceq
        "zero_world_conformance_gate" -and
    [string]$r24d10V2SupervisorSourceRun[0].status -ceq
        "v2_parent_bound_source_implemented_preflight_pending_physics_forbidden" -and
    [string]$r24d10V2SupervisorSourceRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d10V2SupervisorSourceRun[0].risk -ceq "safe" -and
    [string]$r24d10V2SupervisorSourceRun[0].runner_path -ceq
        "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_physical_supervisor_source_v2.py" -and
    @($r24d10V2SupervisorSourceRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d10V2SupervisorSourceRun[0].arguments) -and
    "Physical" -cnotin @($r24d10V2SupervisorSourceRun[0].arguments) -and
    (@($r24d10V2SupervisorSourceRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "sdk/recovery/r24d10_first_physical_supervisor_qualification_adoption_refusal_v1.json|" +
        "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_physical_supervisor_contract_v2.json|" +
        "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_physical_supervisor_manifest_v2.json|" +
        "sdk/run_qsdk_r24d10_exact_step_numerical_telemetry_characterization.ps1|" +
        "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_physical_supervisor_source_v2.py"
    ) -and
    $r24d10V2SupervisorSourceRun[0].summary.Contains(
        "production authorization-only check",
        [StringComparison]::Ordinal
    ) -and
    $r24d10V2SupervisorSourceRun[0].claim_boundary.Contains(
        "fresh complete seven-stage zero-world preflight",
        [StringComparison]::Ordinal
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D10 v2 source exposure changed"

$r24d10V2QualificationAuthorizationRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d10_v2_physical_supervisor_qualification_and_authorization"
    }
)
Assert-Exact (
    $r24d10V2QualificationAuthorizationRun.Count -eq 1 -and
    [string]$r24d10V2QualificationAuthorizationRun[0].kind -ceq
        "zero_world_qualification_authorization_audit" -and
    [string]$r24d10V2QualificationAuthorizationRun[0].status -ceq
        "v2_preflight_passed_parent_bound_authorization_declared_authorization_check_pending_physics_unopened" -and
    [string]$r24d10V2QualificationAuthorizationRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d10V2QualificationAuthorizationRun[0].risk -ceq "safe" -and
    [string]$r24d10V2QualificationAuthorizationRun[0].runner_path -ceq
        "tests/test_qsdk_r24d10_physical_supervisor_qualification_positive_closure_v2.py" -and
    @($r24d10V2QualificationAuthorizationRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d10V2QualificationAuthorizationRun[0].arguments) -and
    "Physical" -cnotin @($r24d10V2QualificationAuthorizationRun[0].arguments) -and
    (@($r24d10V2QualificationAuthorizationRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d10-exact-step-numerical-telemetry/physical-supervisor-qualification/20260826T203447143Z-b2bccdb7-a2955f32da4a/receipt.json|" +
        "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_physical_supervisor_qualification_positive_closure_v2.json|" +
        "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_physical_authorization_v2.json|" +
        "tests/test_qsdk_r24d10_physical_supervisor_qualification_positive_closure_v2.py"
    ) -and
    $r24d10V2QualificationAuthorizationRun[0].summary.Contains(
        "actual 0/0/0 execution",
        [StringComparison]::Ordinal
    ) -and
    $r24d10V2QualificationAuthorizationRun[0].claim_boundary.Contains(
        "cannot invoke the production supervisor",
        [StringComparison]::Ordinal
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D10 v2 qualification exposure changed"

$r24d10PhysicalCharacterizationClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d10_exact_step_numerical_telemetry_physical_characterization_closure"
    }
)
Assert-Exact (
    $r24d10PhysicalCharacterizationClosureRun.Count -eq 1 -and
    [string]$r24d10PhysicalCharacterizationClosureRun[0].kind -ceq
        "physical_characterization_closure_audit" -and
    [string]$r24d10PhysicalCharacterizationClosureRun[0].status -ceq
        "complete_valid_finite_descriptive_native_exact_step_characterization_profile_promotion_decision_next" -and
    [string]$r24d10PhysicalCharacterizationClosureRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d10PhysicalCharacterizationClosureRun[0].risk -ceq "safe" -and
    [string]$r24d10PhysicalCharacterizationClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_physical_characterization_closure.py" -and
    @($r24d10PhysicalCharacterizationClosureRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d10PhysicalCharacterizationClosureRun[0].arguments) -and
    "Physical" -cnotin @($r24d10PhysicalCharacterizationClosureRun[0].arguments) -and
    (@($r24d10PhysicalCharacterizationClosureRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d10-exact-step-numerical-telemetry/physical/20260826T204714579Z-9d2f8d59-6ccc8d1496a5/receipt.json|" +
        "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_physical_characterization_closure_v1.json|" +
        "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_physical_characterization_closure.py"
    ) -and
    $r24d10PhysicalCharacterizationClosureRun[0].summary.Contains(
        "one world and build, native step tokens 1 through 20",
        [StringComparison]::Ordinal
    ) -and
    $r24d10PhysicalCharacterizationClosureRun[0].claim_boundary.Contains(
        "zero selected empirical thresholds",
        [StringComparison]::Ordinal
    ) -and
    $r24d10PhysicalCharacterizationClosureRun[0].claim_boundary.Contains(
        "distinct prospective finite profile-promotion decision",
        [StringComparison]::Ordinal
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D10 physical closure exposure changed"

$r24d11ProfilePromotionDecisionRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d11_godot_jolt_instrumented_profile_promotion_decision"
    }
)
Assert-Exact (
    $r24d11ProfilePromotionDecisionRun.Count -eq 1 -and
    [string]$r24d11ProfilePromotionDecisionRun[0].kind -ceq
        "finite_evidence_decision_audit" -and
    [string]$r24d11ProfilePromotionDecisionRun[0].status -ceq
        "complete_profile_promotion_refused_missing_absorbed_motor_work_witness" -and
    [string]$r24d11ProfilePromotionDecisionRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d11ProfilePromotionDecisionRun[0].risk -ceq "safe" -and
    [string]$r24d11ProfilePromotionDecisionRun[0].runner_path -ceq
        "tests/test_qsdk_r24d11_godot_jolt_instrumented_profile_promotion_decision.py" -and
    @($r24d11ProfilePromotionDecisionRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d11ProfilePromotionDecisionRun[0].arguments) -and
    "Physical" -cnotin @($r24d11ProfilePromotionDecisionRun[0].arguments) -and
    (@($r24d11ProfilePromotionDecisionRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_physical_characterization_closure_v1.json|" +
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d10-exact-step-numerical-telemetry/physical/20260826T204714579Z-9d2f8d59-6ccc8d1496a5/evaluation.json|" +
        "sdk/recovery/r24d11_godot_jolt_instrumented_profile_promotion_decision_v1.json|" +
        "tests/test_qsdk_r24d11_godot_jolt_instrumented_profile_promotion_decision.py"
    ) -and
    $r24d11ProfilePromotionDecisionRun[0].summary.Contains(
        "both braking cells have zero opposing impulse and zero absorbed work",
        [StringComparison]::Ordinal
    ) -and
    $r24d11ProfilePromotionDecisionRun[0].claim_boundary.Contains(
        "refusing promotion of both the instrumented and stock Godot profiles",
        [StringComparison]::Ordinal
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D11 decision exposure changed"

$r24d12BrakingMechanismFreezeRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d12_godot_jolt_braking_mechanism_activation_freeze"
    }
)
Assert-Exact (
    $r24d12BrakingMechanismFreezeRun.Count -eq 1 -and
    [string]$r24d12BrakingMechanismFreezeRun[0].kind -ceq
        "development_source_freeze_audit" -and
    [string]$r24d12BrakingMechanismFreezeRun[0].status -ceq
        "prospective_source_implemented_zero_world_qualification_pending" -and
    [string]$r24d12BrakingMechanismFreezeRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d12BrakingMechanismFreezeRun[0].risk -ceq "safe" -and
    [string]$r24d12BrakingMechanismFreezeRun[0].runner_path -ceq
        "tests/test_qsdk_r24d12_godot_jolt_braking_mechanism_activation_freeze.py" -and
    @($r24d12BrakingMechanismFreezeRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d12BrakingMechanismFreezeRun[0].arguments) -and
    "Physical" -cnotin @($r24d12BrakingMechanismFreezeRun[0].arguments) -and
    (@($r24d12BrakingMechanismFreezeRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "sdk/recovery/r24d11_godot_jolt_instrumented_profile_promotion_decision_v1.json|" +
        "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_preregistration_v1.json|" +
        "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_validation_manifest.json|" +
        "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_evaluator.py|" +
        "scripts/lab/rigs/r24d12_godot_jolt_braking_mechanism_activation_rig.gd|" +
        "tests/test_sdk_qsdk_r24d12_godot_jolt_braking_mechanism_activation_worker.gd|" +
        "sdk/run_qsdk_r24d12_braking_mechanism_activation_zero_world_gate.ps1|" +
        "tests/test_qsdk_r24d12_godot_jolt_braking_mechanism_activation_freeze.py"
    ) -and
    $r24d12BrakingMechanismFreezeRun[0].summary.Contains(
        "corrected unfreeze-before-angular-velocity-write route",
        [StringComparison]::Ordinal
    ) -and
    $r24d12BrakingMechanismFreezeRun[0].claim_boundary.Contains(
        "clean-pushed complete zero-world qualification is next",
        [StringComparison]::OrdinalIgnoreCase
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D12 source-freeze exposure changed"

$r24d12BrakingMechanismZeroWorldClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d12_godot_jolt_braking_mechanism_activation_zero_world_closure"
    }
)
Assert-Exact (
    $r24d12BrakingMechanismZeroWorldClosureRun.Count -eq 1 -and
    [string]$r24d12BrakingMechanismZeroWorldClosureRun[0].kind -ceq
        "zero_world_positive_closure_audit" -and
    [string]$r24d12BrakingMechanismZeroWorldClosureRun[0].status -ceq
        "complete_zero_world_gate_passed_physical_execution_still_forbidden" -and
    [string]$r24d12BrakingMechanismZeroWorldClosureRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d12BrakingMechanismZeroWorldClosureRun[0].risk -ceq "safe" -and
    [string]$r24d12BrakingMechanismZeroWorldClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r24d12_braking_mechanism_activation_zero_world_positive_closure.py" -and
    @($r24d12BrakingMechanismZeroWorldClosureRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d12BrakingMechanismZeroWorldClosureRun[0].arguments) -and
    "Physical" -cnotin @($r24d12BrakingMechanismZeroWorldClosureRun[0].arguments) -and
    (@($r24d12BrakingMechanismZeroWorldClosureRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d12-braking-mechanism-activation/zero-world/20260826T220001659Z-7b807819-1c77888f5b1c/receipt.json|" +
        "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_zero_world_positive_closure_v1.json|" +
        "tests/test_qsdk_r24d12_braking_mechanism_activation_zero_world_positive_closure.py"
    ) -and
    $r24d12BrakingMechanismZeroWorldClosureRun[0].summary.Contains(
        "actual zero worlds, builds, and solver steps",
        [StringComparison]::Ordinal
    ) -and
    $r24d12BrakingMechanismZeroWorldClosureRun[0].claim_boundary.Contains(
        "synthetic signed-braking witnesses are not native observations",
        [StringComparison]::Ordinal
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D12 zero-world closure exposure changed"

$r24d12PhysicalSupervisorSourceRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d12_braking_mechanism_physical_supervisor_source"
    }
)
Assert-Exact (
    $r24d12PhysicalSupervisorSourceRun.Count -eq 1 -and
    [string]$r24d12PhysicalSupervisorSourceRun[0].kind -ceq
        "zero_world_conformance_gate" -and
    [string]$r24d12PhysicalSupervisorSourceRun[0].status -ceq
        "parent_bound_source_implemented_preflight_pending_physics_forbidden" -and
    [string]$r24d12PhysicalSupervisorSourceRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d12PhysicalSupervisorSourceRun[0].risk -ceq "safe" -and
    [string]$r24d12PhysicalSupervisorSourceRun[0].runner_path -ceq
        "tests/test_qsdk_r24d12_braking_mechanism_activation_physical_supervisor_source.py" -and
    @($r24d12PhysicalSupervisorSourceRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d12PhysicalSupervisorSourceRun[0].arguments) -and
    "Physical" -cnotin @($r24d12PhysicalSupervisorSourceRun[0].arguments) -and
    (@($r24d12PhysicalSupervisorSourceRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_physical_supervisor_contract_v1.json|" +
        "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_physical_supervisor_manifest_v1.json|" +
        "sdk/run_qsdk_r24d12_braking_mechanism_activation_characterization.ps1|" +
        "tests/test_qsdk_r24d12_braking_mechanism_activation_physical_supervisor_source.py"
    ) -and
    $r24d12PhysicalSupervisorSourceRun[0].summary.Contains(
        "both valid finite development outcomes",
        [StringComparison]::Ordinal
    ) -and
    $r24d12PhysicalSupervisorSourceRun[0].claim_boundary.Contains(
        "no separate physics ghost is adequate",
        [StringComparison]::OrdinalIgnoreCase
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D12 supervisor source exposure changed"

$r24d12PhysicalSupervisorQualificationRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d12_braking_mechanism_physical_supervisor_qualification"
    }
)
Assert-Exact (
    $r24d12PhysicalSupervisorQualificationRun.Count -eq 1 -and
    [string]$r24d12PhysicalSupervisorQualificationRun[0].kind -ceq
        "zero_world_qualification_authorization_audit" -and
    [string]$r24d12PhysicalSupervisorQualificationRun[0].status -ceq
        "preflight_passed_parent_bound_authorization_declared_authorization_check_pending_physics_unopened" -and
    [string]$r24d12PhysicalSupervisorQualificationRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d12PhysicalSupervisorQualificationRun[0].risk -ceq "safe" -and
    [string]$r24d12PhysicalSupervisorQualificationRun[0].runner_path -ceq
        "tests/test_qsdk_r24d12_braking_mechanism_activation_physical_supervisor_qualification.py" -and
    @($r24d12PhysicalSupervisorQualificationRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d12PhysicalSupervisorQualificationRun[0].arguments) -and
    "Physical" -cnotin @($r24d12PhysicalSupervisorQualificationRun[0].arguments) -and
    (@($r24d12PhysicalSupervisorQualificationRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d12-braking-mechanism-activation/physical-supervisor-qualification/20260826T222820198Z-a9f6eaad-fa6080b18d73/receipt.json|" +
        "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_physical_supervisor_qualification_positive_closure_v1.json|" +
        "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_physical_authorization_v1.json|" +
        "tests/test_qsdk_r24d12_braking_mechanism_activation_physical_supervisor_qualification.py"
    ) -and
    $r24d12PhysicalSupervisorQualificationRun[0].summary.Contains(
        "actual 0/0/0 execution",
        [StringComparison]::Ordinal
    ) -and
    $r24d12PhysicalSupervisorQualificationRun[0].claim_boundary.Contains(
        "production authorization-only check",
        [StringComparison]::OrdinalIgnoreCase
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D12 supervisor qualification exposure changed"

$r24d12PhysicalAttemptClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d12_braking_mechanism_physical_attempt_closure"
    }
)
Assert-Exact (
    $r24d12PhysicalAttemptClosureRun.Count -eq 1 -and
    [string]$r24d12PhysicalAttemptClosureRun[0].kind -ceq
        "physical_attempt_closure_audit" -and
    [string]$r24d12PhysicalAttemptClosureRun[0].status -ceq
        "closed_consumed_invalid_incomplete_after_one_world_float32_readback_exactness_rejection" -and
    [string]$r24d12PhysicalAttemptClosureRun[0].world_policy -ceq
        "retained_evidence_only" -and
    [string]$r24d12PhysicalAttemptClosureRun[0].risk -ceq "safe" -and
    [string]$r24d12PhysicalAttemptClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r24d12_braking_mechanism_activation_physical_attempt_closure.py" -and
    @($r24d12PhysicalAttemptClosureRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d12PhysicalAttemptClosureRun[0].arguments) -and
    "Physical" -cnotin @($r24d12PhysicalAttemptClosureRun[0].arguments) -and
    (@($r24d12PhysicalAttemptClosureRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_physical_attempt_closure_v1.json|" +
        "tests/test_qsdk_r24d12_braking_mechanism_activation_physical_attempt_closure.py|" +
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d12-braking-mechanism-activation/physical/20260826T223912889Z-0a15d68a-f58e60297ec4/attempt.json|" +
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d12-braking-mechanism-activation/physical/20260826T223912889Z-0a15d68a-f58e60297ec4/raw-report.json"
    ) -and
    $r24d12PhysicalAttemptClosureRun[0].summary.Contains(
        "one world, one build, one native solver step",
        [StringComparison]::Ordinal
    ) -and
    $r24d12PhysicalAttemptClosureRun[0].claim_boundary.Contains(
        "cannot rerun",
        [StringComparison]::OrdinalIgnoreCase
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D12 physical closure exposure changed"

$r24d13NativeSerializerSourceRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d13_braking_mechanism_native_serializer_source"
    }
)
Assert-Exact (
    $r24d13NativeSerializerSourceRun.Count -eq 1 -and
    [string]$r24d13NativeSerializerSourceRun[0].kind -ceq
        "zero_world_conformance_gate" -and
    [string]$r24d13NativeSerializerSourceRun[0].status -ceq
        "historical_source_and_development_calibration_passed_physical_attempt_consumed_invalid" -and
    [string]$r24d13NativeSerializerSourceRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d13NativeSerializerSourceRun[0].risk -ceq "safe" -and
    [string]$r24d13NativeSerializerSourceRun[0].runner_path -ceq
        "tests/test_qsdk_r24d13_braking_mechanism_activation_physical_supervisor_source.py" -and
    @($r24d13NativeSerializerSourceRun[0].arguments).Count -eq 0 -and
    @($r24d13NativeSerializerSourceRun[0].proofs).Count -eq 12 -and
    (@($r24d13NativeSerializerSourceRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -contains
        "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_physical_attempt_closure_v1.json") -and
    (@($r24d13NativeSerializerSourceRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -contains
        "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_validation_manifest.json") -and
    $r24d13NativeSerializerSourceRun[0].summary.Contains(
        "not equivalent to native property readback",
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    $r24d13NativeSerializerSourceRun[0].claim_boundary.Contains(
        "cannot rerun",
        [StringComparison]::OrdinalIgnoreCase
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D13 source exposure changed"

$r24d13PhysicalSupervisorQualificationRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d13_braking_mechanism_physical_supervisor_qualification"
    }
)
Assert-Exact (
    $r24d13PhysicalSupervisorQualificationRun.Count -eq 1 -and
    [string]$r24d13PhysicalSupervisorQualificationRun[0].kind -ceq
        "zero_world_qualification_authorization_audit" -and
    [string]$r24d13PhysicalSupervisorQualificationRun[0].status -ceq
        "preflight_passed_parent_bound_authorization_consumed_invalid_attempt_closed" -and
    [string]$r24d13PhysicalSupervisorQualificationRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d13PhysicalSupervisorQualificationRun[0].risk -ceq "safe" -and
    [string]$r24d13PhysicalSupervisorQualificationRun[0].runner_path -ceq
        "tests/test_qsdk_r24d13_braking_mechanism_activation_physical_supervisor_qualification.py" -and
    @($r24d13PhysicalSupervisorQualificationRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d13PhysicalSupervisorQualificationRun[0].arguments) -and
    "Physical" -cnotin @($r24d13PhysicalSupervisorQualificationRun[0].arguments) -and
    (@($r24d13PhysicalSupervisorQualificationRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d13-braking-mechanism-activation/physical-supervisor-qualification/20260826T232142657Z-12317012-c29272f7b41c/receipt.json|" +
        "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_physical_supervisor_qualification_positive_closure_v1.json|" +
        "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_physical_authorization_v1.json|" +
        "tests/test_qsdk_r24d13_braking_mechanism_activation_physical_supervisor_qualification.py"
    ) -and
    $r24d13PhysicalSupervisorQualificationRun[0].summary.Contains(
        "actual 0/0/0 qualification execution",
        [StringComparison]::Ordinal
    ) -and
    $r24d13PhysicalSupervisorQualificationRun[0].claim_boundary.Contains(
        "authorization is consumed",
        [StringComparison]::OrdinalIgnoreCase
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D13 supervisor qualification exposure changed"

$r24d13PhysicalAttemptClosureRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d13_braking_mechanism_physical_attempt_closure"
    }
)
Assert-Exact (
    $r24d13PhysicalAttemptClosureRun.Count -eq 1 -and
    [string]$r24d13PhysicalAttemptClosureRun[0].kind -ceq
        "physical_attempt_closure_audit" -and
    [string]$r24d13PhysicalAttemptClosureRun[0].status -ceq
        "closed_consumed_invalid_incomplete_after_one_world_native_float32_projection_exactness_rejection" -and
    [string]$r24d13PhysicalAttemptClosureRun[0].world_policy -ceq
        "retained_evidence_only" -and
    [string]$r24d13PhysicalAttemptClosureRun[0].risk -ceq "safe" -and
    [string]$r24d13PhysicalAttemptClosureRun[0].runner_path -ceq
        "tests/test_qsdk_r24d13_braking_mechanism_activation_physical_attempt_closure.py" -and
    @($r24d13PhysicalAttemptClosureRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d13PhysicalAttemptClosureRun[0].arguments) -and
    "Physical" -cnotin @($r24d13PhysicalAttemptClosureRun[0].arguments) -and
    (@($r24d13PhysicalAttemptClosureRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_physical_attempt_closure_v1.json|" +
        "tests/test_qsdk_r24d13_braking_mechanism_activation_physical_attempt_closure.py|" +
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d13-braking-mechanism-activation/physical/20260826T233359861Z-b2b63ab4-1a34fab456d7/attempt.json|" +
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d13-braking-mechanism-activation/physical/20260826T233359861Z-b2b63ab4-1a34fab456d7/raw-report.json"
    ) -and
    $r24d13PhysicalAttemptClosureRun[0].summary.Contains(
        "PARAMETER_brake_positive_public_maximum_motor_impulse_nms",
        [StringComparison]::Ordinal
    ) -and
    $r24d13PhysicalAttemptClosureRun[0].claim_boundary.Contains(
        "cannot rerun",
        [StringComparison]::OrdinalIgnoreCase
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D13 physical closure exposure changed"

$r24d14NativeProjectionQualificationRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d14_native_projection_qualification_closure"
    }
)
Assert-Exact (
    $r24d14NativeProjectionQualificationRun.Count -eq 1 -and
    [string]$r24d14NativeProjectionQualificationRun[0].label -ceq
        "[recovery/godot] R24D14 zero-step native-projection qualification closure" -and
    [string]$r24d14NativeProjectionQualificationRun[0].kind -ceq
        "zero_world_qualification_closure_audit" -and
    [string]$r24d14NativeProjectionQualificationRun[0].status -ceq
        "complete_clean_pushed_zero_step_native_property_and_telemetry_projection_qualified_physical_supervisor_pending" -and
    [string]$r24d14NativeProjectionQualificationRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d14NativeProjectionQualificationRun[0].risk -ceq "safe" -and
    [string]$r24d14NativeProjectionQualificationRun[0].runner_path -ceq
        "tests/test_qsdk_r24d14_godot_native_float_projection_qualification_closure.py" -and
    @($r24d14NativeProjectionQualificationRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d14NativeProjectionQualificationRun[0].arguments) -and
    "Physical" -cnotin @($r24d14NativeProjectionQualificationRun[0].arguments) -and
    (@($r24d14NativeProjectionQualificationRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "sdk/recovery/r24d14_godot_native_float_projection_preregistration_v1.json|" +
        "sdk/recovery/r24d14_godot_native_float_projection_validation_manifest.json|" +
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d14-native-float-projection/qualification/20260827T000809847Z-4f4d9f49-5da8edfa32af/receipt.json|" +
        "sdk/recovery/r24d14_godot_native_float_projection_qualification_positive_closure_v1.json|" +
        "tests/test_qsdk_r24d14_godot_native_float_projection_qualification_closure.py"
    ) -and
    $r24d14NativeProjectionQualificationRun[0].summary.Contains(
        "actual 0/0/0 worlds, builds, and solver steps",
        [StringComparison]::Ordinal
    ) -and
    $r24d14NativeProjectionQualificationRun[0].claim_boundary.Contains(
        "cannot rerun",
        [StringComparison]::OrdinalIgnoreCase
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D14 qualification closure exposure changed"

$r24d14PhysicalSupervisorSourceRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d14_braking_mechanism_physical_supervisor_source"
    }
)
Assert-Exact (
    $r24d14PhysicalSupervisorSourceRun.Count -eq 1 -and
    [string]$r24d14PhysicalSupervisorSourceRun[0].label -ceq
        "[recovery/godot] R24D14 one-step physical-supervisor source audit" -and
    [string]$r24d14PhysicalSupervisorSourceRun[0].kind -ceq
        "zero_world_conformance_gate" -and
    [string]$r24d14PhysicalSupervisorSourceRun[0].status -ceq
        "source_frozen_official_preflight_passed_parent_bound_authorization_declared_physics_unopened" -and
    [string]$r24d14PhysicalSupervisorSourceRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d14PhysicalSupervisorSourceRun[0].risk -ceq "safe" -and
    [string]$r24d14PhysicalSupervisorSourceRun[0].runner_path -ceq
        "tests/test_qsdk_r24d14_braking_mechanism_activation_physical_supervisor_source.py" -and
    @($r24d14PhysicalSupervisorSourceRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d14PhysicalSupervisorSourceRun[0].arguments) -and
    "Physical" -cnotin @($r24d14PhysicalSupervisorSourceRun[0].arguments) -and
    (@($r24d14PhysicalSupervisorSourceRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "sdk/recovery/r24d14_godot_native_float_projection_qualification_positive_closure_v1.json|" +
        "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_physical_supervisor_contract_v1.json|" +
        "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_physical_supervisor_manifest_v1.json|" +
        "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_physical_evaluator.py|" +
        "tests/test_sdk_qsdk_r24d14_godot_jolt_braking_mechanism_activation_worker.gd|" +
        "sdk/run_qsdk_r24d14_braking_mechanism_activation_characterization.ps1|" +
        "tests/test_qsdk_r24d14_braking_mechanism_activation_physical_supervisor_source.py|" +
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d14-braking-mechanism-activation/development/20260827T003517328Z-d939af3a-0ff24f51ca84/attempt.json|" +
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d14-braking-mechanism-activation/development/20260827T003554775Z-d939af3a-7b873c8ea594/receipt.json"
    ) -and
    $r24d14PhysicalSupervisorSourceRun[0].summary.Contains(
        "actual 0 worlds / 0 builds / 0 solver steps",
        [StringComparison]::Ordinal
    ) -and
    $r24d14PhysicalSupervisorSourceRun[0].claim_boundary.Contains(
        "not official qualification",
        [StringComparison]::OrdinalIgnoreCase
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D14 physical-supervisor source exposure changed"

$r24d14PhysicalSupervisorQualificationRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d14_braking_mechanism_physical_supervisor_qualification"
    }
)
Assert-Exact (
    $r24d14PhysicalSupervisorQualificationRun.Count -eq 1 -and
    [string]$r24d14PhysicalSupervisorQualificationRun[0].label -ceq
        "[recovery/godot] R24D14 physical-supervisor qualification and authorization audit" -and
    [string]$r24d14PhysicalSupervisorQualificationRun[0].kind -ceq
        "zero_world_qualification_authorization_audit" -and
    [string]$r24d14PhysicalSupervisorQualificationRun[0].status -ceq
        "preflight_passed_parent_bound_authorization_declared_authorization_check_pending_physics_unopened" -and
    [string]$r24d14PhysicalSupervisorQualificationRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d14PhysicalSupervisorQualificationRun[0].risk -ceq "safe" -and
    [string]$r24d14PhysicalSupervisorQualificationRun[0].runner_path -ceq
        "tests/test_qsdk_r24d14_braking_mechanism_activation_physical_supervisor_qualification.py" -and
    @($r24d14PhysicalSupervisorQualificationRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d14PhysicalSupervisorQualificationRun[0].arguments) -and
    "Physical" -cnotin @($r24d14PhysicalSupervisorQualificationRun[0].arguments) -and
    (@($r24d14PhysicalSupervisorQualificationRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d14-braking-mechanism-activation/physical-supervisor-qualification/20260827T004357759Z-f0f250b9-ec92f7a9f79f/receipt.json|" +
        "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_physical_supervisor_qualification_positive_closure_v1.json|" +
        "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_physical_authorization_v1.json|" +
        "tests/test_qsdk_r24d14_braking_mechanism_activation_physical_supervisor_qualification.py"
    ) -and
    $r24d14PhysicalSupervisorQualificationRun[0].summary.Contains(
        "actual 0/0/0 physical execution",
        [StringComparison]::Ordinal
    ) -and
    $r24d14PhysicalSupervisorQualificationRun[0].claim_boundary.Contains(
        "exactly one separately guarded",
        [StringComparison]::OrdinalIgnoreCase
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D14 qualification exposure changed"

$r24d14PhysicalCharacterizationRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d14_braking_mechanism_physical_characterization_closure"
    }
)
Assert-Exact (
    $r24d14PhysicalCharacterizationRun.Count -eq 1 -and
    [string]$r24d14PhysicalCharacterizationRun[0].label -ceq
        "[recovery/godot] R24D14 native braking-mechanism characterization closure" -and
    [string]$r24d14PhysicalCharacterizationRun[0].kind -ceq
        "physical_characterization_closure_audit" -and
    [string]$r24d14PhysicalCharacterizationRun[0].status -ceq
        "closed_complete_valid_finite_native_braking_mechanism_activation_positive_profile_promotion_decision_next" -and
    [string]$r24d14PhysicalCharacterizationRun[0].world_policy -ceq
        "retained_evidence_only" -and
    [string]$r24d14PhysicalCharacterizationRun[0].risk -ceq "safe" -and
    [string]$r24d14PhysicalCharacterizationRun[0].runner_path -ceq
        "tests/test_qsdk_r24d14_braking_mechanism_activation_physical_characterization_closure.py" -and
    @($r24d14PhysicalCharacterizationRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d14PhysicalCharacterizationRun[0].arguments) -and
    "Physical" -cnotin @($r24d14PhysicalCharacterizationRun[0].arguments) -and
    (@($r24d14PhysicalCharacterizationRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_physical_characterization_closure_v1.json|" +
        "tests/test_qsdk_r24d14_braking_mechanism_activation_physical_characterization_closure.py|" +
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d14-braking-mechanism-activation/physical/20260827T005329324Z-a6be6727-bd015eb4a2ea/receipt.json|" +
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d14-braking-mechanism-activation/physical/20260827T005329324Z-a6be6727-bd015eb4a2ea/raw-report.json|" +
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d14-braking-mechanism-activation/physical/20260827T005329324Z-a6be6727-bd015eb4a2ea/evaluation.json"
    ) -and
    $r24d14PhysicalCharacterizationRun[0].summary.Contains(
        "one world, one build, one solver step, four retained samples",
        [StringComparison]::Ordinal
    ) -and
    $r24d14PhysicalCharacterizationRun[0].claim_boundary.Contains(
        "cannot rerun",
        [StringComparison]::OrdinalIgnoreCase
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D14 physical characterization exposure changed"

$r24d15ProfilePromotionDecisionRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d15_instrumented_profile_promotion_decision"
    }
)
Assert-Exact (
    $r24d15ProfilePromotionDecisionRun.Count -eq 1 -and
    [string]$r24d15ProfilePromotionDecisionRun[0].label -ceq
        "[recovery/godot] R24D15 instrumented-profile promotion decision" -and
    [string]$r24d15ProfilePromotionDecisionRun[0].kind -ceq
        "finite_decision_audit" -and
    [string]$r24d15ProfilePromotionDecisionRun[0].status -ceq
        "complete_finite_decision_exact_instrumented_profile_promoted_mapping_implementation_next" -and
    [string]$r24d15ProfilePromotionDecisionRun[0].world_policy -ceq
        "zero_world_only" -and
    [string]$r24d15ProfilePromotionDecisionRun[0].risk -ceq "safe" -and
    [string]$r24d15ProfilePromotionDecisionRun[0].runner_path -ceq
        "tests/test_qsdk_r24d15_godot_jolt_instrumented_profile_promotion_decision.py" -and
    @($r24d15ProfilePromotionDecisionRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d15ProfilePromotionDecisionRun[0].arguments) -and
    "Physical" -cnotin @($r24d15ProfilePromotionDecisionRun[0].arguments) -and
    (@($r24d15ProfilePromotionDecisionRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "sdk/recovery/r24d15_godot_jolt_instrumented_profile_promotion_decision_v1.json|" +
        "tests/test_qsdk_r24d15_godot_jolt_instrumented_profile_promotion_decision.py"
    ) -and
    $r24d15ProfilePromotionDecisionRun[0].summary.Contains(
        "8/8 predeclared families",
        [StringComparison]::Ordinal
    ) -and
    $r24d15ProfilePromotionDecisionRun[0].claim_boundary.Contains(
        "does not promote stock Godot",
        [StringComparison]::OrdinalIgnoreCase
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D15 profile-promotion decision exposure changed"

$r24d16CapabilityQualificationRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d16_profile_scoped_recovery_capability_qualification_closure"
    }
)
Assert-Exact (
    $r24d16CapabilityQualificationRun.Count -eq 1 -and
    [string]$r24d16CapabilityQualificationRun[0].label -ceq
        "[recovery/godot] R24D16 profile-scoped capability qualification closure" -and
    [string]$r24d16CapabilityQualificationRun[0].kind -ceq
        "zero_world_qualification_closure_audit" -and
    [string]$r24d16CapabilityQualificationRun[0].status -ceq
        "qualified_exact_profile_mapping_positive_stock_refusal_preserved_collectors_controller_next" -and
    [string]$r24d16CapabilityQualificationRun[0].world_policy -ceq
        "retained_evidence_only" -and
    [string]$r24d16CapabilityQualificationRun[0].risk -ceq "safe" -and
    [string]$r24d16CapabilityQualificationRun[0].runner_path -ceq
        "tests/test_qsdk_r24d16_godot_jolt_profile_scoped_recovery_capability_qualification_closure.py" -and
    @($r24d16CapabilityQualificationRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d16CapabilityQualificationRun[0].arguments) -and
    "Physical" -cnotin @($r24d16CapabilityQualificationRun[0].arguments) -and
    (@($r24d16CapabilityQualificationRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "sdk/recovery/r24d16_godot_jolt_profile_scoped_recovery_capability_contract_v1.json|" +
        "sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd|" +
        "tests/test_qsdk_r24d16_godot_jolt_profile_scoped_recovery_capability_source.py|" +
        "sdk/run_qsdk_r24d16_profile_scoped_recovery_capability_zero_world.ps1|" +
        "tests/test_sdk_qsdk_r24d16_godot_profile_scoped_recovery_capability_zero_world.gd|" +
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/" +
        "qsdk-r24d16-profile-scoped-recovery-capability/qualification/" +
        "20260827T014757688Z-4ed7ad93-1405c8b1cd40/receipt.json|" +
        "sdk/recovery/r24d16_godot_jolt_profile_scoped_recovery_capability_" +
        "qualification_closure_v1.json|" +
        "tests/test_qsdk_r24d16_godot_jolt_profile_scoped_recovery_" +
        "capability_qualification_closure.py"
    ) -and
    $r24d16CapabilityQualificationRun[0].summary.Contains(
        "10/10 required channels",
        [StringComparison]::Ordinal
    ) -and
    $r24d16CapabilityQualificationRun[0].summary.Contains(
        "8/10 map",
        [StringComparison]::Ordinal
    ) -and
    $r24d16CapabilityQualificationRun[0].claim_boundary.Contains(
        "does not promote stock Godot",
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    $r24d16CapabilityQualificationRun[0].claim_boundary.Contains(
        "does not",
        [StringComparison]::OrdinalIgnoreCase
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D16 capability qualification exposure changed"

$r24d17RuntimeQualificationRun = @(
    $catalog.runs | Where-Object {
        [string]$_.id -ceq
            "qsdk_r24d17_native_recovery_runtime_qualification_closure"
    }
)
Assert-Exact (
    $r24d17RuntimeQualificationRun.Count -eq 1 -and
    [string]$r24d17RuntimeQualificationRun[0].label -ceq
        "[recovery/3e] R24D17 recovery runtime qualification closure" -and
    [string]$r24d17RuntimeQualificationRun[0].kind -ceq
        "zero_world_qualification_closure_audit" -and
    [string]$r24d17RuntimeQualificationRun[0].status -ceq
        "qualified_native_validation_surfaces_controller_and_prospective_physical_profile_physics_not_opened" -and
    [string]$r24d17RuntimeQualificationRun[0].world_policy -ceq
        "retained_evidence_only" -and
    [string]$r24d17RuntimeQualificationRun[0].risk -ceq "safe" -and
    [string]$r24d17RuntimeQualificationRun[0].runner_path -ceq
        "tests/test_qsdk_r24d17_native_recovery_runtime_qualification_closure.py" -and
    (@($r24d17RuntimeQualificationRun[0].engine_ids) -join "|") -ceq
        "godot_jolt|rapier_parry|mujoco" -and
    @($r24d17RuntimeQualificationRun[0].arguments).Count -eq 0 -and
    "-RunPhysical" -cnotin @($r24d17RuntimeQualificationRun[0].arguments) -and
    "Physical" -cnotin @($r24d17RuntimeQualificationRun[0].arguments) -and
    (@($r24d17RuntimeQualificationRun[0].proofs | ForEach-Object {
        [string]$_.path
    }) -join "|") -ceq (
        "sdk/recovery/r24d17_native_recovery_runtime_and_physical_profile_contract_v1.json|" +
        "tests/test_qsdk_r24d17_native_recovery_runtime_source.py|" +
        "sdk/run_qsdk_r24d17_native_recovery_runtime_zero_world.ps1|" +
        "tests/test_sdk_qsdk_r24d17_godot_recovery_runtime_zero_world.gd|" +
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/" +
        "qsdk-r24d17-qualification-20260827T024026086Z-576e7086/receipt.json|" +
        "sdk/recovery/r24d17_native_recovery_runtime_qualification_closure_v1.json|" +
        "tests/test_qsdk_r24d17_native_recovery_runtime_qualification_closure.py"
    ) -and
    $r24d17RuntimeQualificationRun[0].summary.Contains(
        "16/16 threshold provenance and adequacy bindings",
        [StringComparison]::Ordinal
    ) -and
    $r24d17RuntimeQualificationRun[0].summary.Contains(
        "zero of nine held-out cells executed",
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    $r24d17RuntimeQualificationRun[0].claim_boundary.Contains(
        "did not sample a live native recovery observation",
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    $r24d17RuntimeQualificationRun[0].claim_boundary.Contains(
        "distinct R24D18 development declaration",
        [StringComparison]::OrdinalIgnoreCase
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH R24D17 runtime qualification exposure changed"

foreach ($run in $catalog.runs) {
    $runner = [string]$run.runner_path
    if (-not [string]::IsNullOrWhiteSpace($runner)) {
        Assert-Exact (
            Test-Path -LiteralPath (Join-Path $repoRoot $runner) -PathType Leaf
        ) "LOCOMOTION_EXPERIMENT_WORKBENCH missing runner for $($run.id)"
    }
    if ([string]$run.kind -cne "physical_one_shot") {
        Assert-Exact (
            "-RunPhysical" -cnotin @($run.arguments)
        ) "LOCOMOTION_EXPERIMENT_WORKBENCH safe run exposes RunPhysical: $($run.id)"
        Assert-Exact (
            "Physical" -cnotin @($run.arguments)
        ) "LOCOMOTION_EXPERIMENT_WORKBENCH safe run exposes Physical mode: $($run.id)"
    }
    foreach ($proof in @($run.proofs)) {
        $proofPath = [string]$proof.path
        $absoluteProof = if ([System.IO.Path]::IsPathFullyQualified($proofPath)) {
            [System.IO.Path]::GetFullPath($proofPath)
        }
        else {
            Join-Path $repoRoot $proofPath
        }
        Assert-Exact (
            Test-Path -LiteralPath $absoluteProof -PathType Leaf
        ) "LOCOMOTION_EXPERIMENT_WORKBENCH missing proof: $proofPath"
        $expected = [string]$proof.expected_sha256
        if (-not [string]::IsNullOrWhiteSpace($expected)) {
            $expected = $expected.Replace("sha256:", "")
            $role = if ($null -ne $proof.PSObject.Properties["binding_role"]) {
                [string]$proof.binding_role
            } else { "pinned_artifact" }
            Assert-Exact (
                Test-ProofReference $role $proofPath $expected (Get-RawSha256 -Path $absoluteProof)
            ) "LOCOMOTION_EXPERIMENT_WORKBENCH proof reference invalid: $role/$proofPath"
        }
    }
}

$workbenchSource = Get-Content -Raw -LiteralPath $workbenchPath
$previewSource = Get-Content -Raw -LiteralPath $previewPath
$livePhysicsSource = Get-Content -Raw -LiteralPath $livePhysicsPath
$liveCameraSource = Get-Content -Raw -LiteralPath $liveCameraPath
$nativeViewerSource = Get-Content -Raw -LiteralPath $nativeViewerPath
Assert-Exact (
    $workbenchSource.Contains(
        "OS.execute_with_pipe",
        [StringComparison]::Ordinal
    ) -and
    $workbenchSource.Contains(
        "Explorer values are never injected into frozen runners",
        [StringComparison]::Ordinal
    ) -and
    $workbenchSource.Contains(
        "physical_identity_consumed=False",
        [StringComparison]::Ordinal
    ) -and
    $workbenchSource.Contains(
        "LOCOMOTION_EXPERIMENT_WORKBENCH_GUIDE.md",
        [StringComparison]::Ordinal
    ) -and
    $workbenchSource.Contains(
        "--workbench-safe-process-self-test",
        [StringComparison]::Ordinal
    ) -and
    $workbenchSource.Contains(
        "--workbench-live-physics-process-self-test",
        [StringComparison]::Ordinal
    ) -and
    $workbenchSource.Contains(
        "OS.create_process",
        [StringComparison]::Ordinal
    ) -and
    $workbenchSource.Contains(
        "Launch real Jolt physics",
        [StringComparison]::Ordinal
    ) -and
    $workbenchSource.Contains(
        "Launch all 3 real engines",
        [StringComparison]::Ordinal
    ) -and
    $workbenchSource.Contains(
        "_native_start_gate_path",
        [StringComparison]::Ordinal
    ) -and
    $previewSource.Contains(
        "3D SETUP INSPECTOR  •  RENDER ONLY",
        [StringComparison]::Ordinal
    ) -and
    $previewSource.Contains(
        "SubViewport",
        [StringComparison]::Ordinal
    ) -and
    -not $previewSource.Contains(
        "RigidBody3D",
        [StringComparison]::Ordinal
    ) -and
    $livePhysicsSource.Contains(
        'preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")',
        [StringComparison]::Ordinal
    ) -and
    $livePhysicsSource.Contains(
        "func _execute_walker",
        [StringComparison]::Ordinal
    ) -and
    $livePhysicsSource.Contains(
        'const SOLVER_POLICY_ID := "jolt_120hz_20v_7p_v1"',
        [StringComparison]::Ordinal
    ) -and
    $livePhysicsSource.Contains(
        "not the closed BW22L A/B",
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    -not $livePhysicsSource.Contains(
        "-RunPhysical",
        [StringComparison]::Ordinal
    ) -and
    $liveCameraSource.Contains(
        "var _torso: RigidBody3D",
        [StringComparison]::Ordinal
    ) -and
    $liveCameraSource.Contains(
        "Torso authority: none after release",
        [StringComparison]::Ordinal
    ) -and
    $liveCameraSource.Contains(
        "apply_central_impulse",
        [StringComparison]::Ordinal
    ) -and
    $nativeViewerSource.Contains(
        "LIVE NATIVE PHYSICS",
        [StringComparison]::Ordinal
    ) -and
    $nativeViewerSource.Contains(
        '"message_type": "apply_impulse"',
        [StringComparison]::Ordinal
    ) -and
    $nativeViewerSource.Contains(
        '"message_type": "start"',
        [StringComparison]::Ordinal
    )
) "LOCOMOTION_EXPERIMENT_WORKBENCH UI safety source changed"

$attemptsBefore = Get-Bw22lAttemptCount
if (-not $SkipGodot) {
    Assert-Exact (
        Test-Path -LiteralPath $Godot -PathType Leaf
    ) "LOCOMOTION_EXPERIMENT_WORKBENCH Godot executable missing: $Godot"
    $output = @(
        & $Godot `
            --headless `
            --path $repoRoot `
            --scene "res://scenes/tools/locomotion_experiment_workbench.tscn" `
            --quit-after 10 `
            -- `
            --workbench-self-test 2>&1
    )
    $godotExit = $LASTEXITCODE
    $outputText = $output -join [Environment]::NewLine
    Assert-Exact (
        $godotExit -eq 0 -and
        $outputText.Contains($expectedSelfTest, [StringComparison]::Ordinal) -and
        -not $outputText.Contains("SCRIPT ERROR", [StringComparison]::Ordinal) -and
        -not $outputText.Contains("ERROR:", [StringComparison]::Ordinal)
    ) "LOCOMOTION_EXPERIMENT_WORKBENCH Godot self-test failed`n$outputText"

    $safeProcessOutput = @(
        & $Godot `
            --headless `
            --path $repoRoot `
            --scene "res://scenes/tools/locomotion_experiment_workbench.tscn" `
            --quit-after 3600 `
            -- `
            --workbench-safe-process-self-test 2>&1
    )
    $safeProcessExit = $LASTEXITCODE
    $safeProcessText = $safeProcessOutput -join [Environment]::NewLine
    Assert-Exact (
        $safeProcessExit -eq 0 -and
        $safeProcessText.Contains(
            $expectedSafeProcessSelfTest,
            [StringComparison]::Ordinal
        ) -and
        -not $safeProcessText.Contains("SCRIPT ERROR", [StringComparison]::Ordinal) -and
        -not $safeProcessText.Contains("ERROR:", [StringComparison]::Ordinal)
    ) "LOCOMOTION_EXPERIMENT_WORKBENCH safe process self-test failed`n$safeProcessText"

    $liveProcessOutput = @(
        & $Godot `
            --headless `
            --path $repoRoot `
            --scene "res://scenes/tools/locomotion_experiment_workbench.tscn" `
            --quit-after 3600 `
            -- `
            --workbench-live-physics-process-self-test 2>&1
    )
    $liveProcessExit = $LASTEXITCODE
    $liveProcessText = $liveProcessOutput -join [Environment]::NewLine
    Assert-Exact (
        $liveProcessExit -eq 0 -and
        $liveProcessText.Contains(
            $expectedLiveProcessSelfTest,
            [StringComparison]::Ordinal
        ) -and
        -not $liveProcessText.Contains("SCRIPT ERROR", [StringComparison]::Ordinal) -and
        -not $liveProcessText.Contains("ERROR:", [StringComparison]::Ordinal)
    ) "LOCOMOTION_EXPERIMENT_WORKBENCH live process self-test failed`n$liveProcessText"

    $liveConfigRoot = Join-Path $repoRoot ".tmp\workbench-test"
    [void][System.IO.Directory]::CreateDirectory($liveConfigRoot)
    $liveConfigPath = Join-Path $liveConfigRoot "live-physics-preflight.json"
    $liveEnvelope = [ordered]@{
        schema_version = "sporespore_workbench_live_physics_configuration_v1"
        role = "zero_world_workbench_audit"
        values = $catalog.presets[0].values
    }
    try {
        [System.IO.File]::WriteAllText(
            $liveConfigPath,
            ($liveEnvelope | ConvertTo-Json -Depth 100),
            [System.Text.UTF8Encoding]::new($false)
        )
        $liveOutput = @(
            & $Godot `
                --headless `
                --path $repoRoot `
                --script "res://scripts/tools/locomotion_live_physics_demo.gd" `
                -- `
                --validate-only `
                $liveConfigPath 2>&1
        )
        $liveExit = $LASTEXITCODE
        $liveText = $liveOutput -join [Environment]::NewLine
        Assert-Exact (
            $liveExit -eq 0 -and
            $liveText.Contains(
                "LOCOMOTION_LIVE_PHYSICS_PREFLIGHT_PASS worlds=0",
                [StringComparison]::Ordinal
            ) -and
            -not $liveText.Contains("SCRIPT ERROR", [StringComparison]::Ordinal) -and
            -not $liveText.Contains("ERROR:", [StringComparison]::Ordinal)
        ) "LOCOMOTION_EXPERIMENT_WORKBENCH live physics preflight failed`n$liveText"
    }
    finally {
        if (Test-Path -LiteralPath $liveConfigPath -PathType Leaf) {
            Remove-Item -LiteralPath $liveConfigPath -Force
        }
    }
}
$attemptsAfter = Get-Bw22lAttemptCount
Assert-Exact (
    $attemptsAfter -eq $attemptsBefore
) "LOCOMOTION_EXPERIMENT_WORKBENCH self-test consumed or created a BW22L attempt"

Write-Host (
    "LOCOMOTION_EXPERIMENT_WORKBENCH_AUDIT_PASS " +
    "engines=4 presets=4 parameters=29 runs=122 physical_runs=0 " +
    "safe_runphysical_exposures=0 current_proof_hashes=True historical_source_pins_retained=True worlds=0 " +
    "attempts_unchanged=True godot_self_test=$(-not $SkipGodot) " +
    "safe_process_self_test=$(-not $SkipGodot) " +
    "live_physics_preflight=$(-not $SkipGodot) " +
    "live_process_self_test=$(-not $SkipGodot)"
)

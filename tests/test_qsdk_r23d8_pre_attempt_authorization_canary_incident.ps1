#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$incidentPath = Join-Path $repoRoot (
    "sdk\turning\r23d8_pre_attempt_authorization_canary_incident_v1.json"
)
$runnerPath = Join-Path $repoRoot "sdk\run_qsdk_r23d8_authorization_canaries.ps1"
$failedCommit = "56af8ecbccbdf656b80fddb0c5a868056605d0ca"
$failedTree = "7e218a5dc9770457027e7268710cf3ac392f05e8"
$attestationPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "full-godot-conformance-v2-56af8ecb-20260809T031440Z\attestation.json"
)
$attestationSha256 = (
    "db9cd5275a3a36e38fd8248ebcc8b717ad48e03792d41cecb31f5ac126e56670"
)

function Assert-R23D8Incident {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

Assert-R23D8Incident (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (Test-Path -LiteralPath $incidentPath -PathType Leaf) -and
    (Test-Path -LiteralPath $runnerPath -PathType Leaf) -and
    (Test-Path -LiteralPath $attestationPath -PathType Leaf)
) "QSDK-R23D8 incident repository or retained input changed"

$incident = Get-Content -Raw -LiteralPath $incidentPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$sideEffects = $incident.side_effect_boundary
$repair = $incident.repair_boundary
$claims = $incident.claims
Assert-R23D8Incident (
    [string]$incident.schema_version -ceq
        "sporespore_qsdk_r23d8_pre_attempt_authorization_canary_incident_v1" -and
    [string]$incident.status -ceq
        "retained_pre_attempt_zero_world_implementation_incident" -and
    [string]$incident.campaign_id -ceq
        "QSDK-R23D8-AUTHORIZATION-CLOSED-NEUTRAL-STANCE-BILATERAL-TURN-DEVELOPMENT" -and
    [string]$incident.gate_id -ceq "QSDK-R23D8" -and
    [string]$incident.failed_source_commit -ceq $failedCommit -and
    [string]$incident.failed_source_tree_git_oid -ceq $failedTree -and
    [bool]$incident.failed_source_remains_immutable -and
    [string]$incident.failure_mechanism.classification -ceq
        "authorization_canary_runner_manifest_api_field_mismatch" -and
    [string]$incident.failure_mechanism.runner_read_field -ceq "worker_count" -and
    [string]$incident.failure_mechanism.actual_worker_count_derivation -ceq
        "ordered_worker_ids.Count" -and
    -not [bool]$incident.failure_mechanism.scientific_policy_failure -and
    -not [bool]$incident.failure_mechanism.engine_adapter_failure -and
    -not [bool]$incident.failure_mechanism.physics_failure
) "QSDK-R23D8 incident identity or mechanism changed"

Assert-R23D8Incident (
    [bool]$sideEffects.failed_before_global_operation_lock -and
    [bool]$sideEffects.failed_before_test_only_evidence_root_creation -and
    [int]$sideEffects.authorization_canary_process_launch_count -eq 0 -and
    [int]$sideEffects.physical_process_launch_count -eq 0 -and
    [int]$sideEffects.model_construction_count -eq 0 -and
    [int]$sideEffects.world_attempt_count -eq 0 -and
    [int]$sideEffects.world_build_count -eq 0 -and
    -not [bool]$sideEffects.attempt_authorization_created -and
    -not [bool]$sideEffects.one_shot_physical_identity_consumed -and
    -not [bool]$sideEffects.stage_a_launched -and
    -not [bool]$sideEffects.stage_b_launched -and
    -not [bool]$sideEffects.physical_acceptance_authority -and
    [bool]$repair.same_campaign_pre_attempt_implementation_repair_permitted -and
    [bool]$repair.required_zero_world_runner_preflight -and
    [bool]$repair.required_new_clean_pushed_source_commit -and
    [bool]$repair.required_fresh_source_exact_full_godot_attestation -and
    -not [bool]$repair.failed_attestation_may_authorize_repaired_source -and
    -not [bool]$repair.scientific_estimand_changed -and
    -not [bool]$repair.fixture_changed -and
    -not [bool]$repair.controller_or_terminal_stance_policy_changed -and
    -not [bool]$repair.schedule_selector_or_threshold_changed
) "QSDK-R23D8 incident side-effect or repair boundary changed"

Assert-R23D8Incident (
    (git -C $repoRoot rev-parse "${failedCommit}^{tree}").Trim() -ceq $failedTree -and
    (Get-FileHash -Algorithm SHA256 -LiteralPath $attestationPath).Hash.ToLowerInvariant() `
        -ceq $attestationSha256
) "QSDK-R23D8 failed source or attestation bytes changed"

$failedRunner = (& git -C $repoRoot show (
    "${failedCommit}:sdk/run_qsdk_r23d8_authorization_canaries.ps1"
)) -join "`n"
Assert-R23D8Incident ($LASTEXITCODE -eq 0) (
    "QSDK-R23D8 failed canary runner blob is unavailable"
)
$failedManifestModule = (& git -C $repoRoot show (
    "${failedCommit}:sdk/turning/r23d8_dependency_closure.ps1"
)) -join "`n"
Assert-R23D8Incident ($LASTEXITCODE -eq 0) (
    "QSDK-R23D8 failed dependency module blob is unavailable"
)
$currentRunner = [IO.File]::ReadAllText($runnerPath)
Assert-R23D8Incident (
    $failedRunner.Contains('[int]$manifest.worker_count -eq 3') -and
    $failedManifestModule.Contains('ordered_worker_ids = @($workerIds)') -and
    -not $failedManifestModule.Contains('worker_count =') -and
    $currentRunner.Contains('@($manifest.ordered_worker_ids).Count -eq 3') -and
    $currentRunner.Contains('QSDK_R23D8_AUTHORIZATION_CANARY_PREFLIGHT_PASS ') -and
    -not $currentRunner.Contains('[int]$manifest.worker_count -eq 3')
) "QSDK-R23D8 failed mechanism is not reproduced or repaired exactly"

$evidenceRoot = [IO.Path]::GetFullPath("${repoRoot}_Evidence")
$canaryRoots = @(
    Get-ChildItem -LiteralPath $evidenceRoot -Directory `
        -Filter "qsdk-r23d8-authorization-canary-*"
)
Assert-R23D8Incident ($canaryRoots.Count -eq 0) (
    "QSDK-R23D8 test-only authorization-canary root was not removed"
)
Assert-R23D8Incident (
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.bilateral_signed_turning -and
    -not [bool]$claims.portable_basic_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.q_sdk_r23_satisfied -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority
) "QSDK-R23D8 incident claim boundary changed"

Write-Host (
    "QSDK_R23D8_PRE_ATTEMPT_CANARY_INCIDENT_PASS failed_source=56af8ecb " +
    "canary_processes=0 models=0 worlds=0 identity_consumed=False " +
    "turning=False physical_authority=False"
)

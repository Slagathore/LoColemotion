#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$incidentPath = Join-Path $repoRoot (
    "sdk\turning\r23d9_authorization_canary_receipt_incident_v1.json"
)
$mujocoPath = Join-Path $repoRoot (
    "sdk\adapters\mujoco\sporespore_mujoco_adapter\" +
    "qsdk_r23d9_support_handoff_physical.py"
)
$rapierPath = Join-Path $repoRoot (
    "sdk\adapters\rapier\src\qsdk_r23d3_phase_balanced.rs"
)
$godotPath = Join-Path $repoRoot (
    "tests\test_sdk_qsdk_r23d9_support_handoff_godot_jolt_worker.gd"
)
$runnerPath = Join-Path $repoRoot "sdk\run_qsdk_r23d9_authorization_canaries.ps1"
$failedCommit = "ab729fab05fb63963448da85c1ea122fe3dd543a"
$failedTree = "8beb7dfadb373f546a648fe3314067f6d134151c"
$attestationPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "full-godot-conformance-v2-ab729fab-20260809T090941Z\attestation.json"
)
$attestationSha256 = "75fa0e5a07cd55bdd069cf29d41fa04196c76a0e218442b82e165c1e763f9571"
$logPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "r23d9-authorization-canary-incident-ab729fab-20260809T093751Z\canary.log"
)
$logSha256 = "a7af42b7d3b9f691382406b49fb15312498742530648454ccac6729b42145433"

function Assert-R23D9CanaryIncident {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

Assert-R23D9CanaryIncident (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (Test-Path -LiteralPath $incidentPath -PathType Leaf) -and
    (Test-Path -LiteralPath $mujocoPath -PathType Leaf) -and
    (Test-Path -LiteralPath $rapierPath -PathType Leaf) -and
    (Test-Path -LiteralPath $godotPath -PathType Leaf) -and
    (Test-Path -LiteralPath $runnerPath -PathType Leaf) -and
    (Test-Path -LiteralPath $attestationPath -PathType Leaf) -and
    (Test-Path -LiteralPath $logPath -PathType Leaf)
) "QSDK-R23D9 authorization-canary incident boundary is unavailable"

$incident = Get-Content -Raw -LiteralPath $incidentPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$mechanism = $incident.failure_mechanism
$sideEffects = $incident.side_effect_boundary
$repair = $incident.repair_boundary
$claims = $incident.claims

Assert-R23D9CanaryIncident (
    [string]$incident.schema_version -ceq
        "sporespore_qsdk_r23d9_authorization_canary_receipt_incident_v1" -and
    [string]$incident.status -ceq
        "retained_pre_physical_production_canary_receipt_schema_incident" -and
    [string]$incident.gate_id -ceq "QSDK-R23D9" -and
    [string]$incident.failed_source_commit -ceq $failedCommit -and
    [string]$incident.failed_source_tree_git_oid -ceq $failedTree -and
    [bool]$incident.failed_source_remains_immutable
) "QSDK-R23D9 authorization-canary incident identity changed"

Assert-R23D9CanaryIncident (
    (git -C $repoRoot rev-parse "${failedCommit}^{tree}").Trim() -ceq $failedTree -and
    (Get-FileHash -LiteralPath $attestationPath -Algorithm SHA256).Hash.ToLowerInvariant() `
        -ceq $attestationSha256 -and
    [string]$attestation.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$attestation.status -ceq "full_godot_conformance_passed" -and
    [bool]$attestation.conformance.passed -and
    -not [bool]$attestation.conformance.one_shot_physical_campaign_executed -and
    [string]$attestation.source.commit -ceq $failedCommit -and
    [string]$attestation.source.tree_git_oid -ceq $failedTree -and
    [bool]$attestation.source.clean_pushed_live -and
    -not [bool]$incident.full_godot_v2_attestation.may_authorize_repaired_source
) "QSDK-R23D9 successful failed-source attestation boundary changed"

$log = [IO.File]::ReadAllText($logPath)
Assert-R23D9CanaryIncident (
    (Get-FileHash -LiteralPath $logPath -Algorithm SHA256).Hash.ToLowerInvariant() `
        -ceq $logSha256 -and
    (Get-Item -LiteralPath $logPath).Length -eq 351 -and
    $log.Contains("source=$failedCommit") -and
    $log.Contains("attestation_sha256=$attestationSha256") -and
    $log.Contains("The property 'returned_before_model' cannot be found") -and
    $log.Contains("R23D9_AUTHORIZATION_CANARY_INCIDENT_REPRO_FAILED_AS_EXPECTED")
) "QSDK-R23D9 authorization-canary retained reproduction changed"

$failedMujoco = (& git -C $repoRoot show (
    "${failedCommit}:sdk/adapters/mujoco/sporespore_mujoco_adapter/" +
    "qsdk_r23d9_support_handoff_physical.py"
)) -join "`n"
Assert-R23D9CanaryIncident ($LASTEXITCODE -eq 0) (
    "QSDK-R23D9 failed MuJoCo source blob is unavailable"
)
$currentMujoco = [IO.File]::ReadAllText($mujocoPath)
$currentRapier = [IO.File]::ReadAllText($rapierPath)
$currentGodot = [IO.File]::ReadAllText($godotPath)
$currentRunner = [IO.File]::ReadAllText($runnerPath)
Assert-R23D9CanaryIncident (
    [string]$mechanism.classification -ceq
        "mujoco_authorization_preflight_receipt_missing_uniform_before_model_field" -and
    [string]$mechanism.missing_field -ceq "returned_before_model" -and
    -not $failedMujoco.Contains('"returned_before_model": True,') -and
    $failedMujoco.Contains('"physics_adapter_start_count": 0,') -and
    $failedMujoco.Contains('"model_construction_count": 0,') -and
    $failedMujoco.Contains('"world_build_count": 0,') -and
    $currentMujoco.Contains('"returned_before_model": True,') -and
    $currentMujoco.Contains('"physics_adapter_start_count": 0,') -and
    $currentRapier.Contains('"returned_before_model": true,') -and
    $currentGodot.Contains('"returned_before_model": true,') -and
    $currentRunner.Contains('[bool]$receipt.returned_before_model') -and
    -not [bool]$mechanism.scientific_policy_failure -and
    -not [bool]$mechanism.engine_adapter_semantics_failure -and
    -not [bool]$mechanism.physics_failure -and
    -not [bool]$mechanism.physical_outcome_observed
) "QSDK-R23D9 authorization receipt mismatch is not retained and repaired exactly"

Assert-R23D9CanaryIncident (
    [int]$sideEffects.production_canary_runner_invocation_count -eq 2 -and
    [int]$sideEffects.mujoco_authorization_preflight_process_launch_count -eq 2 -and
    [int]$sideEffects.actual_production_authorization_function_execution_count -eq 2 -and
    [int]$sideEffects.completed_positive_canary_count -eq 0 -and
    [int]$sideEffects.mutated_binding_refusal_canary_count -eq 0 -and
    [int]$sideEffects.physical_process_launch_count -eq 0 -and
    [int]$sideEffects.model_construction_count -eq 0 -and
    [int]$sideEffects.world_attempt_count -eq 0 -and
    [int]$sideEffects.world_build_count -eq 0 -and
    -not [bool]$sideEffects.attempt_authorization_created -and
    -not [bool]$sideEffects.one_shot_physical_identity_consumed -and
    -not [bool]$sideEffects.stage_a_launched -and
    -not [bool]$sideEffects.stage_b_launched -and
    [bool]$sideEffects.test_only_canary_roots_deleted -and
    -not [bool]$sideEffects.physical_acceptance_authority
) "QSDK-R23D9 authorization-canary incident side-effect boundary changed"

Assert-R23D9CanaryIncident (
    [bool]$repair.same_campaign_pre_physical_implementation_repair_permitted -and
    [bool]$repair.required_new_clean_pushed_source_commit -and
    [bool]$repair.required_fresh_source_exact_full_godot_attestation -and
    [bool]$repair.required_all_six_production_authorization_canaries -and
    -not [bool]$repair.failed_source_attestation_may_authorize_repaired_source -and
    -not [bool]$repair.scientific_estimand_changed -and
    -not [bool]$repair.fixture_changed -and
    -not [bool]$repair.controller_or_terminal_handoff_policy_changed -and
    -not [bool]$repair.schedule_selector_or_threshold_changed -and
    -not [bool]$repair.physics_equations_changed -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.q_sdk_r23_satisfied -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority
) "QSDK-R23D9 authorization-canary repair or claim boundary changed"

Write-Host (
    "QSDK_R23D9_AUTHORIZATION_CANARY_RECEIPT_INCIDENT_PASS " +
    "failed_source=ab729fab attestation=True runner_invocations=2 " +
    "worker_processes=2 completed_canaries=0 models=0 worlds=0 " +
    "identity_consumed=False turning=False physical_authority=False"
)

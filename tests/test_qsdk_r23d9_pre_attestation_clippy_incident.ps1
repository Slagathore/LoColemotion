#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$incidentPath = Join-Path $repoRoot (
    "sdk\turning\r23d9_pre_attestation_clippy_incident_v1.json"
)
$rapierPath = Join-Path $repoRoot (
    "sdk\adapters\rapier\src\qsdk_r23d3_phase_balanced.rs"
)
$failedCommit = "c2a49b1c2cb513122c8ab74e77542cfb4151b8aa"
$failedTree = "bf22a3640c1512b6a96977215584b5457a47c9b5"
$logPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "full-godot-conformance-v2-c2a49b1-20260809T084524Z\conformance.log"
)
$attestationPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "full-godot-conformance-v2-c2a49b1-20260809T084524Z\attestation.json"
)
$logSha256 = "aab25a7ba4ac1363b4a5667cc59159e00529e34449b769003983cae56f7e7814"

function Assert-R23D9Incident {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

Assert-R23D9Incident (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (Test-Path -LiteralPath $incidentPath -PathType Leaf) -and
    (Test-Path -LiteralPath $rapierPath -PathType Leaf) -and
    (Test-Path -LiteralPath $logPath -PathType Leaf) -and
    -not (Test-Path -LiteralPath $attestationPath)
) "QSDK-R23D9 Clippy incident repository or retained boundary changed"

$incident = Get-Content -Raw -LiteralPath $incidentPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$conformance = $incident.full_godot_v2_conformance
$mechanism = $incident.failure_mechanism
$sideEffects = $incident.side_effect_boundary
$repair = $incident.repair_boundary
$claims = $incident.claims
Assert-R23D9Incident (
    [string]$incident.schema_version -ceq
        "sporespore_qsdk_r23d9_pre_attestation_clippy_incident_v1" -and
    [string]$incident.status -ceq
        "retained_pre_physical_full_conformance_implementation_incident" -and
    [string]$incident.gate_id -ceq "QSDK-R23D9" -and
    [string]$incident.failed_source_commit -ceq $failedCommit -and
    [string]$incident.failed_source_tree_git_oid -ceq $failedTree -and
    [bool]$incident.failed_source_remains_immutable -and
    [string]$mechanism.classification -ceq
        "rapier_r23d9_observation_helper_return_type_clippy_failure" -and
    [string]$mechanism.failed_function -ceq "r23d9_observation_fields" -and
    -not [bool]$mechanism.scientific_policy_failure -and
    -not [bool]$mechanism.engine_adapter_semantics_failure -and
    -not [bool]$mechanism.physics_failure -and
    -not [bool]$mechanism.physical_outcome_observed
) "QSDK-R23D9 Clippy incident identity or mechanism changed"

Assert-R23D9Incident (
    (git -C $repoRoot rev-parse "${failedCommit}^{tree}").Trim() -ceq $failedTree -and
    (Get-FileHash -LiteralPath $logPath -Algorithm SHA256).Hash.ToLowerInvariant() `
        -ceq $logSha256 -and
    (Get-Item -LiteralPath $logPath).Length -eq 35253 -and
    [string]$conformance.log_raw_sha256 -ceq "sha256:$logSha256" -and
    [long]$conformance.log_byte_length -eq 35253 -and
    -not [bool]$conformance.attestation_published -and
    [int]$conformance.conformance_exit_code -eq 1 -and
    [bool]$conformance.failed_before_full_godot_attestation_publication -and
    -not [bool]$conformance.may_authorize_repaired_source
) "QSDK-R23D9 failed source, log, or attestation boundary changed"

$log = [IO.File]::ReadAllText($logPath)
$failedRapier = (& git -C $repoRoot show (
    "${failedCommit}:sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced.rs"
)) -join "`n"
Assert-R23D9Incident ($LASTEXITCODE -eq 0) (
    "QSDK-R23D9 failed Rapier source blob is unavailable"
)
$currentRapier = [IO.File]::ReadAllText($rapierPath)
Assert-R23D9Incident (
    $log.Contains("clippy::type-complexity") -and
    $log.Contains("Rust SDK Clippy failed with exit code 101") -and
    $failedRapier.Contains(
        "Result<(f64, f64, f64, bool, BTreeMap<String, bool>), String>"
    ) -and
    $currentRapier.Contains("struct R23D9ObservationFields {") -and
    $currentRapier.Contains(") -> Result<R23D9ObservationFields, String> {") -and
    -not $currentRapier.Contains(
        "Result<(f64, f64, f64, bool, BTreeMap<String, bool>), String>"
    )
) "QSDK-R23D9 failed Clippy mechanism is not reproduced or repaired exactly"

Assert-R23D9Incident (
    [bool]$sideEffects.conformance_operation_lock_acquired -and
    [bool]$sideEffects.durable_failed_log_retained -and
    [int]$sideEffects.r23d9_authorization_canary_process_launch_count -eq 0 -and
    [int]$sideEffects.r23d9_physical_process_launch_count -eq 0 -and
    [int]$sideEffects.r23d9_model_construction_count -eq 0 -and
    [int]$sideEffects.r23d9_world_attempt_count -eq 0 -and
    [int]$sideEffects.r23d9_world_build_count -eq 0 -and
    -not [bool]$sideEffects.r23d9_attempt_authorization_created -and
    -not [bool]$sideEffects.one_shot_physical_identity_consumed -and
    -not [bool]$sideEffects.stage_a_launched -and
    -not [bool]$sideEffects.stage_b_launched -and
    -not [bool]$sideEffects.physical_acceptance_authority -and
    [bool]$repair.same_campaign_pre_physical_implementation_repair_permitted -and
    [bool]$repair.required_new_clean_pushed_source_commit -and
    [bool]$repair.required_fresh_source_exact_full_godot_attestation -and
    -not [bool]$repair.failed_source_attestation_may_authorize_repaired_source -and
    -not [bool]$repair.scientific_estimand_changed -and
    -not [bool]$repair.fixture_changed -and
    -not [bool]$repair.controller_or_terminal_handoff_policy_changed -and
    -not [bool]$repair.schedule_selector_or_threshold_changed -and
    -not [bool]$repair.physics_equations_changed
) "QSDK-R23D9 Clippy incident side-effect or repair boundary changed"

Assert-R23D9Incident (
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.bilateral_signed_turning -and
    -not [bool]$claims.portable_basic_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.q_sdk_r23_satisfied -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority
) "QSDK-R23D9 Clippy incident claim boundary changed"

Write-Host (
    "QSDK_R23D9_PRE_ATTESTATION_CLIPPY_INCIDENT_PASS failed_source=c2a49b1 " +
    "attestation=False processes=0 models=0 worlds=0 identity_consumed=False " +
    "turning=False physical_authority=False"
)

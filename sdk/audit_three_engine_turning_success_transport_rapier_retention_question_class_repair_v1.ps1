#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$implementationPath = Join-Path $repoRoot (
    "sdk\turning\three_engine_turning_success_transport_rapier_retention_question_class_repair_implementation_v1.json"
)
$closureAuditPath = Join-Path $repoRoot (
    "sdk\audit_three_engine_turning_success_transport_v2_attempt2_closure.ps1"
)
$zeroWorldRunnerPath = Join-Path $repoRoot (
    "sdk\run_three_engine_turning_success_transport_v2_zero_world.ps1"
)
$supportMatrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$releaseContractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$evidenceParent = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\turning\success-transport-ghost-v2"
)
$expectedAttemptDirectories = @(
    "20260826T065559127336Z__f8a1110971384270a79c673da6310240",
    "20260826T070915871967Z__d11584853848406e81c5ac7ae816128c"
)
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$sourceCommit = "b0cac1bdd31439de46e5a55b170ebcfcd21c8e54"
$sourceTree = "e792e80703d16d4060e77aa1053a9e9d55424a80"

function Assert-RapierRetentionRepair([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "[turning/transport] Rapier retention-identity repair audit: $Message"
    }
}

function Invoke-RapierRetentionRepairGit([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-RapierRetentionRepair ($LASTEXITCODE -eq 0) (
        "git $($Arguments -join ' ') failed: $($lines -join ' ')"
    )
    return ($lines -join "`n").Trim()
}

function Get-RapierRetentionRepairJson([string]$Path) {
    return Get-Content -LiteralPath $Path -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-RapierRetentionRepairSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Invoke-RapierRetentionRepairAudit([string]$Path) {
    & pwsh -NoProfile -File $Path
    Assert-RapierRetentionRepair ($LASTEXITCODE -eq 0) "audit failed: $Path"
}

Assert-RapierRetentionRepair (
    (Invoke-RapierRetentionRepairGit @("rev-parse", "--show-toplevel")) -ceq
        $repoRoot.Replace("\", "/")
) "repository root changed"
Assert-RapierRetentionRepair (
    (Invoke-RapierRetentionRepairGit @("remote", "get-url", "origin")) -ceq $expectedRemote
) "repository remote changed"
Assert-RapierRetentionRepair (
    (Invoke-RapierRetentionRepairGit @("rev-parse", "$sourceCommit^{tree}")) -ceq $sourceTree
) "source tree changed"

$implementation = Get-RapierRetentionRepairJson $implementationPath
Assert-RapierRetentionRepair (
    [string]$implementation.schema_version -ceq
        "sporespore_three_engine_turning_success_transport_rapier_retention_question_class_repair_implementation_v1" -and
    [string]$implementation.status -ceq
        "repair_complete_complete_clean_pushed_zero_world_gate_passed_physical_not_opened" -and
    [string]$implementation.route_id -ceq
        "sporespore_three_engine_turning_success_transport_route_v2" -and
    [string]$implementation.ledger_scope.question_class -ceq "development" -and
    [string]$implementation.source_authority.source_commit -ceq $sourceCommit -and
    [string]$implementation.source_authority.source_tree_git_oid -ceq $sourceTree -and
    [bool]$implementation.source_authority.source_was_clean_pushed_and_live_equal
) "implementation identity changed"

$bindings = @($implementation.source_bindings)
Assert-RapierRetentionRepair ($bindings.Count -eq 8) "source binding count changed"
foreach ($binding in $bindings) {
    $relative = [string]$binding.path
    $absolute = Join-Path $repoRoot ($relative.Replace("/", "\"))
    Assert-RapierRetentionRepair (
        (Get-RapierRetentionRepairSha256 $absolute) -ceq [string]$binding.raw_sha256 -and
        (Invoke-RapierRetentionRepairGit @("rev-parse", "${sourceCommit}:$relative")) -ceq
            [string]$binding.git_blob_oid -and
        (Invoke-RapierRetentionRepairGit @("rev-parse", "HEAD:$relative")) -ceq
            [string]$binding.git_blob_oid
    ) "source binding changed: $relative"
}

$predecessor = $implementation.predecessor
$repair = $implementation.repair_contract
Assert-RapierRetentionRepair (
    [string]$predecessor.attempt_id -ceq "d11584853848406e81c5ac7ae816128c" -and
    -not [bool]$predecessor.same_source_rerun_allowed -and
    -not [bool]$predecessor.result_reinterpreted -and
    [string]$repair.repair_id -ceq
        "rapier_trace_retention_question_class_projection_v1" -and
    (@($repair.changed_producer_population) -join "|") -ceq "rapier_parry" -and
    -not [bool]$repair.negative_control_count_changed -and
    -not [bool]$repair.behavior_threshold_selector_evaluator_or_interpretation_changed -and
    -not [bool]$repair.godot_or_mujoco_producer_changed
) "predecessor or repair scope changed"

$zeroWorld = $implementation.complete_zero_world_gate
Assert-RapierRetentionRepair (
    [bool]$zeroWorld.passed_from_exact_clean_pushed_source -and
    [int]$zeroWorld.process_count -eq 8 -and
    [int]$zeroWorld.native_engine_preflight_count -eq 3 -and
    [int]$zeroWorld.evaluator_negative_control_count -eq 14 -and
    [int]$zeroWorld.native_worker_negative_control_count -eq 7 -and
    [int]$zeroWorld.authorization_negative_control_count -eq 3 -and
    [int]$zeroWorld.total_negative_control_count -eq 24 -and
    [int]$zeroWorld.rapier_retention_question_class_projection_positive_count -eq 1 -and
    [int]$zeroWorld.model_construction_count -eq 0 -and
    [int]$zeroWorld.world_attempt_count -eq 0 -and
    [int]$zeroWorld.world_build_count -eq 0 -and
    -not [bool]$zeroWorld.physical_execution_authorized
) "zero-world authority changed"
Assert-RapierRetentionRepair (
    [int]$implementation.next_physical.retained_attempt_count_before_open -eq 2 -and
    [int]$implementation.next_physical.declared_world_count -eq 3 -and
    [int]$implementation.next_physical.controller_step_count_per_world -eq 2 -and
    [bool]$implementation.next_physical.serial_execution_required -and
    [bool]$implementation.next_physical.complete_zero_world_gate_repeated_inside_supervisor -and
    [bool]$implementation.next_physical.append_only_distinct_attempt_required -and
    -not [bool]$implementation.next_physical.behavioral_success_question_asked -and
    @($implementation.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "next physical or claim boundary changed"

$attemptDirectories = @(
    Get-ChildItem -LiteralPath $evidenceParent -Directory |
        Sort-Object -Property Name | ForEach-Object { $_.Name }
)
Assert-RapierRetentionRepair (
    ($attemptDirectories -join "|") -ceq ($expectedAttemptDirectories -join "|") -and
    (@($implementation.next_physical.retained_attempt_directories_before_open) -join "|") -ceq
        ($expectedAttemptDirectories -join "|")
) "development evidence population changed before the repaired attempt"

$support = Get-RapierRetentionRepairJson $supportMatrixPath
$supportRoute = $support.locomotion_modes.three_engine_turning_success_transport_route_v2
$release = Get-RapierRetentionRepairJson $releaseContractPath
$turningGate = @($release.gates | Where-Object { $_.gate_id -ceq "QSDK-R23" })
$releaseRoute = $turningGate[0].proof.current_transport_development_successor
$implementationSha = Get-RapierRetentionRepairSha256 $implementationPath
$auditSha = Get-RapierRetentionRepairSha256 $PSCommandPath
Assert-RapierRetentionRepair (
    [string]$supportRoute.rapier_retention_question_class_repair_implementation_path -ceq
        "sdk/turning/three_engine_turning_success_transport_rapier_retention_question_class_repair_implementation_v1.json" -and
    [string]$supportRoute.rapier_retention_question_class_repair_implementation_raw_sha256 -ceq
        $implementationSha -and
    [string]$supportRoute.rapier_retention_question_class_repair_audit_raw_sha256 -ceq
        $auditSha -and
    [string]$supportRoute.rapier_retention_question_class_repair_source_commit -ceq
        $sourceCommit -and
    [bool]$supportRoute.rapier_retention_question_class_repair_complete_zero_world_gate_passed -and
    -not [bool]$supportRoute.rapier_retention_question_class_repair_physical_smoke_opened -and
    [string]$releaseRoute.rapier_retention_question_class_repair_implementation_raw_sha256 -ceq
        $implementationSha -and
    [string]$releaseRoute.rapier_retention_question_class_repair_audit_raw_sha256 -ceq
        $auditSha -and
    [bool]$releaseRoute.rapier_retention_question_class_repair_complete_zero_world_gate_passed -and
    -not [bool]$releaseRoute.rapier_retention_question_class_repair_physical_smoke_opened -and
    [string]$turningGate[0].proof.kind -ceq "missing"
) "live release projection changed"

Invoke-RapierRetentionRepairAudit $closureAuditPath
Invoke-RapierRetentionRepairAudit $zeroWorldRunnerPath

Write-Host (
    "[turning/transport] PASS Rapier retention-identity repair freeze: " +
    "source=b0cac1bd bindings=8 negatives=24 models=0 worlds=0 " +
    "retained_predecessor_attempts=2"
)

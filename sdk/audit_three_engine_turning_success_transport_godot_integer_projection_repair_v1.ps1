#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$implementationPath = Join-Path $repoRoot (
    "sdk\turning\three_engine_turning_success_transport_godot_integer_projection_repair_implementation_v1.json"
)
$closureAuditPath = Join-Path $repoRoot (
    "sdk\audit_three_engine_turning_success_transport_v2_attempt1_closure.ps1"
)
$zeroWorldRunnerPath = Join-Path $repoRoot (
    "sdk\run_three_engine_turning_success_transport_v2_zero_world.ps1"
)
$supportMatrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$releaseContractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$evidenceParent = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\turning\" +
    "success-transport-ghost-v2"
)
$expectedAttemptDirectory = (
    "20260826T065559127336Z__f8a1110971384270a79c673da6310240"
)
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$sourceCommit = "c50eac344fc0c0b78299cb203c11f546e680ad23"
$sourceTree = "60b2a5d6ccad8b19457241a3b1970740de0b7665"

function Assert-ProjectionRepair([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "[turning/transport] Godot integer-projection repair audit: $Message"
    }
}

function Invoke-ProjectionRepairGit([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-ProjectionRepair ($LASTEXITCODE -eq 0) (
        "git $($Arguments -join ' ') failed: $($lines -join ' ')"
    )
    return ($lines -join "`n").Trim()
}

function Get-ProjectionRepairJson([string]$Path) {
    return Get-Content -LiteralPath $Path -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-ProjectionRepairSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Invoke-ProjectionRepairAudit([string]$Path) {
    $output = @(& pwsh -NoProfile -File $Path 2>&1)
    Assert-ProjectionRepair ($LASTEXITCODE -eq 0) (
        "required audit failed: $Path :: $($output -join ' ')"
    )
    foreach ($line in $output) {
        Write-Host $line
    }
}

Assert-ProjectionRepair (
    (Invoke-ProjectionRepairGit @("rev-parse", "--show-toplevel")) -ceq
        $repoRoot.Replace("\", "/")
) "repository root changed"
Assert-ProjectionRepair (
    (Invoke-ProjectionRepairGit @("remote", "get-url", "origin")) -ceq $expectedRemote
) "repository remote changed"
Assert-ProjectionRepair (
    (Invoke-ProjectionRepairGit @("rev-parse", "$sourceCommit^{tree}")) -ceq $sourceTree
) "source tree changed"

$implementation = Get-ProjectionRepairJson $implementationPath
Assert-ProjectionRepair (
    [string]$implementation.schema_version -ceq
        "sporespore_three_engine_turning_success_transport_godot_integer_projection_repair_implementation_v1" -and
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
Assert-ProjectionRepair ($bindings.Count -eq 8) "source binding count changed"
foreach ($binding in $bindings) {
    $relative = [string]$binding.path
    $absolute = Join-Path $repoRoot ($relative.Replace("/", "\"))
    Assert-ProjectionRepair (
        (Get-ProjectionRepairSha256 $absolute) -ceq [string]$binding.raw_sha256 -and
        (Invoke-ProjectionRepairGit @("rev-parse", "${sourceCommit}:$relative")) -ceq
            [string]$binding.git_blob_oid -and
        (Invoke-ProjectionRepairGit @("rev-parse", "HEAD:$relative")) -ceq
            [string]$binding.git_blob_oid
    ) "source binding changed: $relative"
}

$repair = $implementation.repair_contract
Assert-ProjectionRepair (
    [string]$repair.repair_id -ceq
        "godot_integral_json_artifact_length_projection_v1" -and
    (@($repair.changed_producer_population) -join "|") -ceq "godot_jolt" -and
    -not [bool]$repair.behavior_threshold_selector_evaluator_or_interpretation_changed -and
    -not [bool]$repair.rapier_or_mujoco_producer_changed
) "repair scope changed"
$zeroWorld = $implementation.complete_zero_world_gate
Assert-ProjectionRepair (
    [bool]$zeroWorld.passed_from_exact_clean_pushed_source -and
    [int]$zeroWorld.process_count -eq 8 -and
    [int]$zeroWorld.native_engine_preflight_count -eq 3 -and
    [int]$zeroWorld.evaluator_negative_control_count -eq 14 -and
    [int]$zeroWorld.native_worker_negative_control_count -eq 7 -and
    [int]$zeroWorld.authorization_negative_control_count -eq 3 -and
    [int]$zeroWorld.total_negative_control_count -eq 24 -and
    [int]$zeroWorld.godot_integral_projection_positive_count -eq 1 -and
    [int]$zeroWorld.godot_fractional_projection_rejection_count -eq 1 -and
    [int]$zeroWorld.model_construction_count -eq 0 -and
    [int]$zeroWorld.world_attempt_count -eq 0 -and
    [int]$zeroWorld.world_build_count -eq 0 -and
    -not [bool]$zeroWorld.physical_execution_authorized
) "zero-world authority changed"
Assert-ProjectionRepair (
    [int]$implementation.next_physical.retained_attempt_count_before_open -eq 1 -and
    [int]$implementation.next_physical.declared_world_count -eq 3 -and
    [int]$implementation.next_physical.controller_step_count_per_world -eq 2 -and
    [bool]$implementation.next_physical.serial_execution_required -and
    [bool]$implementation.next_physical.complete_zero_world_gate_repeated_inside_supervisor -and
    [bool]$implementation.next_physical.append_only_distinct_attempt_required -and
    -not [bool]$implementation.next_physical.behavioral_success_question_asked -and
    @($implementation.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "next physical or claim boundary changed"

$attemptDirectories = @(
    Get-ChildItem -LiteralPath $evidenceParent -Directory | Sort-Object -Property Name
)
Assert-ProjectionRepair (
    $attemptDirectories.Count -eq 1 -and
    $attemptDirectories[0].Name -ceq $expectedAttemptDirectory
) "development evidence population changed before the repaired attempt"

$support = Get-ProjectionRepairJson $supportMatrixPath
$supportRoute = $support.locomotion_modes.three_engine_turning_success_transport_route_v2
$release = Get-ProjectionRepairJson $releaseContractPath
$turningGate = @($release.gates | Where-Object { $_.gate_id -ceq "QSDK-R23" })
$releaseRoute = $turningGate[0].proof.current_transport_development_successor
$implementationSha = Get-ProjectionRepairSha256 $implementationPath
Assert-ProjectionRepair (
    [string]$supportRoute.current_repair_implementation_path -ceq
        "sdk/turning/three_engine_turning_success_transport_godot_integer_projection_repair_implementation_v1.json" -and
    [string]$supportRoute.current_repair_implementation_raw_sha256 -ceq $implementationSha -and
    [string]$supportRoute.current_repair_source_commit -ceq $sourceCommit -and
    [bool]$supportRoute.current_repair_complete_zero_world_gate_passed -and
    -not [bool]$supportRoute.current_repair_physical_smoke_opened -and
    [string]$releaseRoute.current_repair_implementation_raw_sha256 -ceq $implementationSha -and
    [bool]$releaseRoute.current_repair_complete_zero_world_gate_passed -and
    -not [bool]$releaseRoute.current_repair_physical_smoke_opened -and
    [string]$turningGate[0].proof.kind -ceq "missing"
) "live release projection changed"

Invoke-ProjectionRepairAudit $closureAuditPath
Invoke-ProjectionRepairAudit $zeroWorldRunnerPath

Write-Host (
    "[turning/transport] PASS Godot integer-projection repair freeze: " +
    "source=c50eac34 bindings=8 negatives=24 models=0 worlds=0 " +
    "retained_predecessor_attempts=1"
)

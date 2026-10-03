#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$contractPath = Join-Path $sdkRoot (
    "turning\r23d9_physical_implementation_contract_v1.json"
)
$preregistrationPath = Join-Path $sdkRoot (
    "turning\r23d9_support_handoff_preregistration_v1.json"
)
$dependencyPath = Join-Path $sdkRoot "turning\r23d9_dependency_closure.ps1"
$campaignId = (
    "QSDK-R23D9-SUPPORT-CONFIRMED-ACTIVE-TO-PASSIVE-HANDOFF-" +
    "BILATERAL-TURN-DEVELOPMENT"
)

function Assert-R23D9Implementation {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D9ImplementationRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D9ImplementationSource {
    param([Parameter(Mandatory)][string]$RelativePath)
    $path = Join-Path $repoRoot $RelativePath
    Assert-R23D9Implementation (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D9 implementation source is missing: $RelativePath"
    )
    return [IO.File]::ReadAllText($path)
}

function Assert-R23D9ImplementationSourceContains {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string[]]$Needles
    )
    $source = Get-R23D9ImplementationSource $RelativePath
    foreach ($needle in $Needles) {
        Assert-R23D9Implementation (
            $source.Contains($needle, [StringComparison]::Ordinal)
        ) "QSDK-R23D9 source seam is missing: $RelativePath :: $needle"
    }
}

Assert-R23D9Implementation (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D9 implementation repository identity changed"
foreach ($path in @($contractPath, $preregistrationPath, $dependencyPath)) {
    Assert-R23D9Implementation (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D9 implementation authority is missing: $path"
    )
}

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D9Implementation (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d9_physical_implementation_contract_v1" -and
    [string]$contract.campaign_id -ceq $campaignId -and
    [string]$contract.gate_id -ceq "QSDK-R23D9" -and
    [string]$contract.release_gate_id -ceq "QSDK-R23" -and
    [string]$contract.preregistration_raw_sha256 -ceq
        (Get-R23D9ImplementationRawSha256 $preregistrationPath) -and
    [string]$contract.scientifically_distinct_policy_id -ceq
        "sporespore_support_confirmed_irreversible_passive_handoff_v1" -and
    @($contract.workers).Count -eq 3 -and
    @($contract.workers.engine_id) -join "|" -ceq
        "mujoco|rapier_parry|godot_jolt" -and
    @($contract.workers | Where-Object {
        -not [bool]$_.physical_worker_implemented -or
        [int]$_.physical_world_count_before_freeze -ne 0
    }).Count -eq 0 -and
    [int]$contract.fixed_schedule.turning_controller_step_count -eq 2992 -and
    [int]$contract.fixed_schedule.terminal_support_handoff_step_count -eq 780 -and
    [int]$contract.fixed_schedule.total_trace_row_count_per_cell -eq 3772 -and
    [int]$contract.fixed_schedule.maximum_active_neutral_acquisition_step_count -eq 420 -and
    [int]$contract.fixed_schedule.support_confirmation_step_count -eq 30 -and
    [int]$contract.fixed_schedule.minimum_post_handoff_zero_actuation_step_count -eq 360 -and
    [int]$contract.fixed_schedule.exact_post_handoff_native_application_count -eq 0 -and
    [bool]$contract.support_handoff_implementation.transition_applies_to_following_step -and
    [bool]$contract.support_handoff_implementation.handoff_is_irreversible -and
    -not [bool]$contract.support_handoff_implementation.post_handoff_reactivation_permitted -and
    -not [bool]$contract.support_handoff_implementation.post_handoff_native_actuation_permitted -and
    -not [bool]$contract.support_handoff_implementation.deadline_forced_handoff_can_pass -and
    [int]$contract.support_handoff_implementation.oracle_canary_count_per_worker_route -eq 5 -and
    [int]$contract.support_handoff_implementation.mutation_control_count_per_worker_route -eq 12
) "QSDK-R23D9 physical implementation contract changed"
Assert-R23D9Implementation (
    [string]$preregistration.schema_version -ceq
        "sporespore_qsdk_r23d9_support_handoff_preregistration_v1" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [int]$preregistration.stage_a_mujoco_support_handoff_screen.declared_cell_count -eq 2 -and
    [int]$preregistration.stage_b_three_engine_confirmation.declared_cell_count_if_launched -eq 9 -and
    -not [bool]$preregistration.authorization.physical_execution_authorized -and
    -not [bool]$preregistration.claim_boundary.physical_acceptance_authority
) "QSDK-R23D9 preregistration identity changed"

$exactPaths = @($contract.source_binding_policy.exact_paths)
Assert-R23D9Implementation (
    $exactPaths.Count -gt 0 -and
    @($exactPaths | Group-Object -CaseSensitive | Where-Object Count -gt 1).Count -eq 0 -and
    @($exactPaths | Where-Object {
        [IO.Path]::IsPathRooted([string]$_) -or
        ([string]$_).Contains("\") -or
        ([string]$_).Contains("*") -or
        ([string]$_).Contains("?") -or
        -not (Test-Path -LiteralPath (Join-Path $repoRoot ([string]$_)) -PathType Leaf)
    }).Count -eq 0
) "QSDK-R23D9 source-binding policy is not exact and complete"

. $dependencyPath
$manifest = Get-R23D9DependencyManifest -RepoRoot $repoRoot
$pathSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($path in $exactPaths) { [void]$pathSet.Add([string]$path) }
Assert-R23D9Implementation (
    [string]$manifest.schema_version -ceq
        "sporespore_qsdk_r23d9_worker_dependency_manifest_v1" -and
    @($manifest.ordered_worker_ids).Count -eq 3 -and
    [int]$manifest.unique_dependency_count -eq 41 -and
    @($manifest.union_paths | Where-Object {
        -not $pathSet.Contains([string]$_)
    }).Count -eq 0
) "QSDK-R23D9 dependency closure changed or escaped the source binding set"

Assert-R23D9ImplementationSourceContains `
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d9_support_handoff_physical.py" `
    @(
        "def physical_authorization(",
        "def authorization_preflight(",
        "def run_physical(",
        "MujocoBw19vRobot(",
        "evaluator.retain_trace("
    )
$mujocoSource = Get-R23D9ImplementationSource (
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d9_support_handoff_physical.py"
)
Assert-R23D9Implementation (
    $mujocoSource.IndexOf("physical_authorization(cell, source_commit)") -lt
        $mujocoSource.IndexOf("MujocoBw19vRobot(")
) "QSDK-R23D9 MuJoCo model construction precedes authorization"

Assert-R23D9ImplementationSourceContains `
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced.rs" `
    @(
        "fn r23d9_physical_authorization(",
        "run_qsdk_r23d9_rapier_authorization_preflight_impl(",
        "run_qsdk_r23d9_rapier_physical_impl(",
        "QSDK_R23D9_RAP_PHYSICAL_AUTHORIZATION_REQUIRED"
    )
Assert-R23D9ImplementationSourceContains `
    "sdk/adapters/rapier/src/qsdk_r23d9_support_handoff.rs" `
    @(
        "run_qsdk_r23d9_rapier_authorization_preflight(",
        "run_qsdk_r23d9_rapier_physical("
    )

Assert-R23D9ImplementationSourceContains `
    "tests/test_sdk_qsdk_r23d9_support_handoff_godot_jolt_worker.gd" `
    @(
        "func _r9_run_physical(",
        "_r9_physical_authorization(cell, source_commit)",
        "_r9_retain_trace(",
        "_r9_source_bindings_exact(",
        "production_trace_constructor_canary_count"
    )
$godotSource = Get-R23D9ImplementationSource (
    "tests/test_sdk_qsdk_r23d9_support_handoff_godot_jolt_worker.gd"
)
Assert-R23D9Implementation (
    $godotSource.IndexOf("_r9_physical_authorization(cell, source_commit)") -lt
        $godotSource.IndexOf("var summary: Dictionary = await _r8_run_wave(prepared, false)")
) "QSDK-R23D9 Godot/Jolt world route precedes authorization"

Assert-R23D9ImplementationSourceContains "sdk/run_qsdk_r23d9_supervisor.ps1" @(
    '$stageAId = "mujoco_support_handoff_screen"',
    '"mujoco__support_handoff__$armId"',
    '"$engineId`__support_handoff__$armId"',
    '"physical",',
    '"sporespore_mujoco_adapter.qsdk_r23d9_support_handoff"',
    'Get-R23D9TerminalMarkerClassification',
    'Publish-SporeSporeContentAddressedArtifact',
    'stage_a_reports_may_substitute_for_stage_b = $false'
)

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d9_physical_implementation_audit_v1"
    campaign_id = $campaignId
    gate_id = "QSDK-R23D9"
    implementation_contract_raw_sha256 = Get-R23D9ImplementationRawSha256 $contractPath
    worker_implementation_count = 3
    native_support_handoff_route_count = 3
    complete_trace_retention_path_count = 3
    declared_worker_dependency_count = 41
    single_supervisor_count = 1
    physical_process_launch_count = 0
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    physical_execution_authorized = $false
    physical_acceptance_authority = $false
}
Write-Host (
    "QSDK_R23D9_IMPLEMENTATION_AUDIT " +
    ($receipt | ConvertTo-Json -Depth 40 -Compress)
)
Write-Host (
    "QSDK_R23D9_IMPLEMENTATION_PASS workers=3 native_routes=3 " +
    "trace_retention_paths=3 dependencies=41 supervisor=1 models=0 worlds=0 " +
    "physical_authority=False"
)

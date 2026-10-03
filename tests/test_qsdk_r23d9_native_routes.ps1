#requires -Version 7.0

param([switch]$SkipGodot)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$contractPath = Join-Path $repoRoot (
    "sdk\turning\r23d9_native_route_contract_v1.json"
)
$stageZeroAudit = Join-Path $repoRoot (
    "tests\test_qsdk_r23d9_stage_zero_closure.ps1"
)

function Assert-R23D9Routes([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

Assert-R23D9Routes (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D9 native-route repository identity changed"
foreach ($path in @($contractPath, $stageZeroAudit)) {
    Assert-R23D9Routes (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D9 native-route authority missing: $path"
    )
}

$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$temporal = $contract.frozen_native_temporal_contract
$next = $contract.next_implementation_boundary
$authorization = $contract.authorization
$claims = $contract.claim_boundary
Assert-R23D9Routes (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d9_native_route_contract_v1" -and
    [string]$contract.status -ceq
        "stage_one_three_engine_zero_world_temporal_mirrors_physical_workers_not_implemented_no_physical_authorization" -and
    [string]$contract.stage_zero_boundary.commit -ceq
        "53df1481aa03e1d638a46222c51f0d40fdb457ed" -and
    [int]$temporal.controller_step_count -eq 2992 -and
    [int]$temporal.terminal_step_count -eq 780 -and
    [int]$temporal.total_trace_step_count -eq 3772 -and
    [int]$temporal.maximum_active_neutral_acquisition_step_count -eq 420 -and
    [int]$temporal.support_confirmation_step_count -eq 30 -and
    [int]$temporal.minimum_post_handoff_zero_actuation_step_count -eq 360 -and
    [bool]$temporal.transition_applies_to_following_step -and
    [bool]$temporal.handoff_is_irreversible -and
    -not [bool]$temporal.post_handoff_native_actuation_permitted -and
    -not [bool]$temporal.deadline_forced_handoff_can_pass -and
    [int]$temporal.oracle_canary_count_per_native_route -eq 5 -and
    [int]$temporal.mutation_control_count_per_native_route -eq 12 -and
    [int]$temporal.native_route_count -eq 3 -and
    [int]$temporal.native_identity_preflight_count -eq 11 -and
    [int]$temporal.physical_route_refusal_count -eq 3 -and
    [int]$next.production_physical_worker_count -eq 0 -and
    -not [bool]$next.production_evaluator_implemented -and
    -not [bool]$next.serialized_supervisor_implemented -and
    -not [bool]$authorization.physical_execution_authorized -and
    [int]$authorization.physical_process_launch_count -eq 0 -and
    [int]$authorization.model_construction_count -eq 0 -and
    [int]$authorization.world_attempt_count -eq 0 -and
    [int]$authorization.world_build_count -eq 0 -and
    [bool]$claims.three_engine_native_temporal_mirrors -and
    -not [bool]$claims.three_engine_physical_workers -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.physical_acceptance_authority
) "QSDK-R23D9 native-route contract identity changed"

$hashBindings = [Collections.Generic.List[object]]::new()
foreach ($binding in $contract.unchanged_neutral_acquisition_authorities) {
    $hashBindings.Add([pscustomobject]@{
        path = [string]$binding.path
        hash = ([string]$binding.raw_sha256).Substring(7)
    })
}
foreach ($route in $contract.native_routes) {
    foreach ($pair in @(
        @("implementation_path", "implementation_raw_sha256"),
        @("test_path", "test_raw_sha256"),
        @("binary_entrypoint_path", "binary_entrypoint_raw_sha256"),
        @("library_export_path", "library_export_raw_sha256"),
        @("worker_entrypoint_path", "worker_entrypoint_raw_sha256"),
        @("runner_path", "runner_raw_sha256")
    )) {
        if ($route.Contains($pair[0])) {
            $hashBindings.Add([pscustomobject]@{
                path = [string]$route[$pair[0]]
                hash = ([string]$route[$pair[1]]).Substring(7)
            })
        }
    }
}
Assert-R23D9Routes ($hashBindings.Count -eq 14) (
    "QSDK-R23D9 native-route source-binding count changed"
)
foreach ($binding in $hashBindings) {
    $absolute = Join-Path $repoRoot $binding.path
    Assert-R23D9Routes (
        (Test-Path -LiteralPath $absolute -PathType Leaf) -and
        (Get-RawSha256 $absolute) -ceq $binding.hash
    ) "QSDK-R23D9 native-route source binding changed: $($binding.path)"
}

foreach ($futurePath in @(
    "sdk\turning\r23d9_physical_evaluator.py",
    "sdk\turning\r23d9_dependency_closure.ps1",
    "sdk\turning\r23d9_terminal_marker_classifier.ps1",
    "sdk\publish_qsdk_r23d9_trace.ps1",
    "sdk\run_qsdk_r23d9_authorization_canaries.ps1",
    "sdk\run_qsdk_r23d9_supervisor.ps1",
    "sdk\run_qsdk_r23d9_zero_world_gate.ps1"
)) {
    Assert-R23D9Routes (
        -not (Test-Path -LiteralPath (Join-Path $repoRoot $futurePath))
    ) "QSDK-R23D9 stage one already contains future route: $futurePath"
}

$stageZeroOutput = & pwsh -NoLogo -NoProfile -File $stageZeroAudit 2>&1 |
    Out-String
Assert-R23D9Routes (
    $LASTEXITCODE -eq 0 -and
    $stageZeroOutput.Contains("QSDK_R23D9_STAGE_ZERO_CLOSURE_PASS")
) "QSDK-R23D9 stage-zero closure audit failed: $stageZeroOutput"

$expectedMarkers = [ordered]@{
    "sdk\run_qsdk_r23d9_mujoco_worker_preflight.ps1" =
        "QSDK_R23D9_MUJOCO_NATIVE_ROUTE_PASS"
    "sdk\run_qsdk_r23d9_rapier_worker_preflight.ps1" =
        "QSDK_R23D9_RAPIER_NATIVE_ROUTE_PASS"
}
if (-not $SkipGodot) {
    $expectedMarkers[
        "sdk\run_qsdk_r23d9_godot_jolt_worker_preflight.ps1"
    ] = "QSDK_R23D9_GODOT_JOLT_NATIVE_ROUTE_PASS"
}
foreach ($entry in $expectedMarkers.GetEnumerator()) {
    $runner = Join-Path $repoRoot $entry.Key
    $output = & pwsh -NoLogo -NoProfile -File $runner 2>&1 | Out-String
    Assert-R23D9Routes (
        $LASTEXITCODE -eq 0 -and $output.Contains([string]$entry.Value)
    ) "QSDK-R23D9 native route failed: $($entry.Key); $output"
}

Write-Host (
    "QSDK_R23D9_NATIVE_ROUTES_PASS engines=$($expectedMarkers.Count) " +
    "godot=$(-not $SkipGodot) identities=$((5 + 3 + (3 * [int](-not $SkipGodot)))) " +
    "canaries=$((10 + (5 * [int](-not $SkipGodot)))) " +
    "mutations=$((24 + (12 * [int](-not $SkipGodot)))) " +
    "physical_refusals=$($expectedMarkers.Count) workers=0 models=0 worlds=0 " +
    "physical_authority=False"
)

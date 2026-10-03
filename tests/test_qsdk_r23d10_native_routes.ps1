#requires -Version 7.0

param([switch]$SkipGodot)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$contractPath = Join-Path $repoRoot "sdk\turning\r23d10_native_route_contract_v1.json"

function Assert-R23D10Routes([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

Assert-R23D10Routes (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D10 native-route repository identity changed"
Assert-R23D10Routes (Test-Path -LiteralPath $contractPath -PathType Leaf) (
    "QSDK-R23D10 native-route contract missing"
)

$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$temporal = $contract.frozen_native_temporal_contract
$next = $contract.next_implementation_boundary
$authorization = $contract.authorization
$claims = $contract.claim_boundary
Assert-R23D10Routes (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d10_native_route_contract_v1" -and
    [string]$contract.status -ceq
        "stage_one_three_engine_zero_world_temporal_mirrors_and_evaluator_cli_canary_no_workers_no_physical_authorization" -and
    [string]$contract.stage_zero_boundary.commit -ceq
        "6b39e1df77a403d474924d203ab706f8fa495687" -and
    [int]$temporal.terminal_step_count -eq 900 -and
    [int]$temporal.maximum_active_step_count -eq 540 -and
    [int]$temporal.minimum_quiescent_taper_step_count -eq 120 -and
    [int]$temporal.minimum_passive_zero_actuation_step_count -eq 360 -and
    [int]$temporal.native_route_count -eq 3 -and
    [int]$temporal.native_identity_preflight_count -eq 11 -and
    [int]$temporal.canary_execution_count -eq 15 -and
    [int]$temporal.mutation_refusal_count -eq 48 -and
    [int]$temporal.physical_refusal_count -eq 3 -and
    [int]$temporal.evaluator_cli_command_count -eq 2 -and
    [int]$next.production_physical_worker_count -eq 0 -and
    -not [bool]$next.production_evaluator_implemented -and
    -not [bool]$next.serialized_supervisor_implemented -and
    -not [bool]$authorization.physical_execution_authorized -and
    [int]$authorization.physical_process_launch_count -eq 0 -and
    [int]$authorization.model_construction_count -eq 0 -and
    [int]$authorization.world_attempt_count -eq 0 -and
    [int]$authorization.world_build_count -eq 0 -and
    [bool]$claims.three_engine_native_temporal_mirrors -and
    [bool]$claims.exact_evaluator_cli_integration_canary -and
    -not [bool]$claims.three_engine_physical_workers -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.physical_acceptance_authority
) "QSDK-R23D10 native-route contract identity or authority changed"

$bindings = [Collections.Generic.List[object]]::new()
foreach ($pair in @(
    @("declaration_path", "declaration_raw_sha256"),
    @("pure_oracle_path", "pure_oracle_raw_sha256"),
    @("pure_oracle_test_path", "pure_oracle_test_raw_sha256"),
    @("historical_closure_audit_path", "historical_closure_audit_raw_sha256")
)) {
    $bindings.Add([pscustomobject]@{
        path = [string]$contract.stage_zero_boundary[$pair[0]]
        hash = ([string]$contract.stage_zero_boundary[$pair[1]]).Substring(7)
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
            $bindings.Add([pscustomobject]@{
                path = [string]$route[$pair[0]]
                hash = ([string]$route[$pair[1]]).Substring(7)
            })
        }
    }
}
$cli = $contract.evaluator_cli_integration_canary
foreach ($pair in @(
    @("implementation_path", "implementation_raw_sha256"),
    @("test_path", "test_raw_sha256"),
    @("runner_path", "runner_raw_sha256")
)) {
    $bindings.Add([pscustomobject]@{
        path = [string]$cli[$pair[0]]
        hash = ([string]$cli[$pair[1]]).Substring(7)
    })
}
Assert-R23D10Routes ($bindings.Count -eq 17) (
    "QSDK-R23D10 native-route source binding count changed"
)
foreach ($binding in $bindings) {
    $absolute = Join-Path $repoRoot $binding.path
    Assert-R23D10Routes (
        (Test-Path -LiteralPath $absolute -PathType Leaf) -and
        (Get-RawSha256 $absolute) -ceq [string]$binding.hash
    ) "QSDK-R23D10 native-route source changed: $($binding.path)"
}

Assert-R23D10Routes (
    [string]$cli.stage_a_command -ceq "evaluate-stage-a" -and
    [string]$cli.stage_a_success_marker -ceq
        "QSDK_R23D10_STAGE_A_EVALUATION " -and
    [string]$cli.complete_command -ceq "evaluate-complete" -and
    [string]$cli.complete_success_marker -ceq
        "QSDK_R23D10_COMPLETE_EVALUATION " -and
    [string]$cli.forbidden_generic_marker -ceq "QSDK_R23D10_EVALUATION " -and
    [bool]$cli.producer_consumer_prefixes_compared_exactly -and
    -not [bool]$cli.production_evaluator_implemented
) "QSDK-R23D10 evaluator CLI wire contract changed"

foreach ($futurePath in @(
    "sdk\turning\r23d10_physical_implementation_contract_v1.json",
    "sdk\turning\r23d10_physical_evaluator.py",
    "sdk\run_qsdk_r23d10_supervisor.ps1",
    "sdk\adapters\mujoco\sporespore_mujoco_adapter\qsdk_r23d10_quiescent_taper_physical.py",
    "sdk\adapters\rapier\src\qsdk_r23d10_quiescent_taper_physical.rs"
)) {
    Assert-R23D10Routes (-not (Test-Path -LiteralPath (Join-Path $repoRoot $futurePath))) (
        "QSDK-R23D10 undeclared later-stage path exists: $futurePath"
    )
}

$expectedRunners = [ordered]@{
    "tests\test_qsdk_r23d10_stage_zero_closure.ps1" =
        "QSDK_R23D10_STAGE_ZERO_CLOSURE_PASS"
    "sdk\run_qsdk_r23d10_mujoco_temporal_preflight.ps1" =
        "QSDK_R23D10_MUJOCO_TEMPORAL_PASS"
    "sdk\run_qsdk_r23d10_rapier_temporal_preflight.ps1" =
        "QSDK_R23D10_RAPIER_TEMPORAL_PASS"
    "sdk\run_qsdk_r23d10_evaluator_cli_canary.ps1" =
        "QSDK_R23D10_EVALUATOR_CLI_CANARY_PASS"
}
if (-not $SkipGodot) {
    $expectedRunners["sdk\run_qsdk_r23d10_godot_jolt_temporal_preflight.ps1"] =
        "QSDK_R23D10_GODOT_JOLT_TEMPORAL_PASS"
}
foreach ($entry in $expectedRunners.GetEnumerator()) {
    $output = & pwsh -NoLogo -NoProfile -File (Join-Path $repoRoot $entry.Key) 2>&1 |
        Out-String
    Assert-R23D10Routes (
        $LASTEXITCODE -eq 0 -and $output.Contains([string]$entry.Value)
    ) "QSDK-R23D10 native route failed: $($entry.Key); $output"
}

$engineCount = 2 + [int](-not $SkipGodot)
$identityCount = 8 + (3 * [int](-not $SkipGodot))
$canaryCount = 10 + (5 * [int](-not $SkipGodot))
$mutationCount = 32 + (16 * [int](-not $SkipGodot))
Write-Host (
    "QSDK_R23D10_NATIVE_ROUTES_PASS engines=$engineCount godot=$(-not $SkipGodot) " +
    "identities=$identityCount canaries=$canaryCount mutations=$mutationCount " +
    "cli_commands=2 physical_refusals=$engineCount workers=0 models=0 worlds=0 " +
    "physical_authority=False turning=False"
)

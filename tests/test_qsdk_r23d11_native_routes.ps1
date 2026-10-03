#requires -Version 7.0

param([switch]$SkipGodot)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$contractPath = Join-Path $repoRoot "sdk\turning\r23d11_native_route_contract_v1.json"

function Assert-R23D11Routes([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

Assert-R23D11Routes (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D11 native-route repository identity changed"
Assert-R23D11Routes (Test-Path -LiteralPath $contractPath -PathType Leaf) (
    "QSDK-R23D11 native-route contract missing"
)

$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$composition = $contract.frozen_native_composition_contract
$next = $contract.next_implementation_boundary
$authorization = $contract.authorization
$claims = $contract.claim_boundary
Assert-R23D11Routes (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d11_native_route_contract_v1" -and
    [string]$contract.status -ceq
        "stage_one_three_engine_zero_world_composition_mirrors_no_workers_no_physical_authorization" -and
    [string]$contract.stage_zero_boundary.commit -ceq
        "40ebd67d3a1936be23a9ee6d1a6761e931dfb5d8" -and
    [int]$composition.ordered_actuator_count -eq 8 -and
    [double]$composition.global_requested_correction_scale -eq 0.5 -and
    [double]$composition.maximum_absolute_stability_velocity_delta_rad_s -eq 0.075 -and
    [double]$composition.maximum_stability_velocity_delta_slew_per_step_rad_s -eq 0.01 -and
    [double]$composition.maximum_absolute_neutral_velocity_rad_s -eq 0.35 -and
    [double]$composition.maximum_pre_taper_combined_velocity_magnitude_rad_s -eq 0.425 -and
    [int]$composition.taper_denominator -eq 120 -and
    [int]$composition.native_route_count -eq 3 -and
    [int]$composition.native_identity_preflight_count -eq 11 -and
    [int]$composition.composition_canary_count -eq 21 -and
    [int]$composition.mutation_refusal_count -eq 54 -and
    [int]$composition.inherited_temporal_canary_count -eq 15 -and
    [int]$composition.physical_refusal_count -eq 3 -and
    [int]$next.production_physical_worker_count -eq 0 -and
    -not [bool]$next.production_evaluator_implemented -and
    -not [bool]$next.serialized_supervisor_implemented -and
    -not [bool]$authorization.physical_execution_authorized -and
    [int]$authorization.physical_process_launch_count -eq 0 -and
    [int]$authorization.model_construction_count -eq 0 -and
    [int]$authorization.world_attempt_count -eq 0 -and
    [int]$authorization.world_build_count -eq 0 -and
    [bool]$claims.three_engine_native_composition_mirrors -and
    -not [bool]$claims.three_engine_physical_workers -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.physical_acceptance_authority
) "QSDK-R23D11 native-route contract identity or authority changed"

$bindings = [Collections.Generic.List[object]]::new()
foreach ($pair in @(
    @("declaration_path", "declaration_raw_sha256"),
    @("pure_oracle_path", "pure_oracle_raw_sha256"),
    @("pure_oracle_test_path", "pure_oracle_test_raw_sha256"),
    @("declaration_audit_path", "declaration_audit_raw_sha256"),
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
Assert-R23D11Routes ($bindings.Count -eq 15) (
    "QSDK-R23D11 native-route source binding count changed"
)
foreach ($binding in $bindings) {
    $absolute = Join-Path $repoRoot $binding.path
    Assert-R23D11Routes (
        (Test-Path -LiteralPath $absolute -PathType Leaf) -and
        (Get-RawSha256 $absolute) -ceq [string]$binding.hash
    ) "QSDK-R23D11 native-route source changed: $($binding.path)"
}

foreach ($futurePath in @(
    "sdk\turning\r23d11_physical_implementation_contract_v1.json",
    "sdk\turning\r23d11_physical_evaluator.py",
    "sdk\run_qsdk_r23d11_supervisor.ps1",
    "sdk\adapters\mujoco\sporespore_mujoco_adapter\qsdk_r23d11_stability_assisted_taper_physical.py",
    "sdk\adapters\rapier\src\qsdk_r23d11_stability_assisted_taper_physical.rs"
)) {
    Assert-R23D11Routes (-not (Test-Path -LiteralPath (Join-Path $repoRoot $futurePath))) (
        "QSDK-R23D11 undeclared later-stage path exists: $futurePath"
    )
}

$expectedRunners = [ordered]@{
    "tests\test_qsdk_r23d11_stage_zero_closure.ps1" =
        "QSDK_R23D11_STAGE_ZERO_CLOSURE_PASS"
    "sdk\run_qsdk_r23d11_mujoco_composition_preflight.ps1" =
        "QSDK_R23D11_MUJOCO_COMPOSITION_PASS"
    "sdk\run_qsdk_r23d11_rapier_composition_preflight.ps1" =
        "QSDK_R23D11_RAPIER_COMPOSITION_PASS"
}
if (-not $SkipGodot) {
    $expectedRunners["sdk\run_qsdk_r23d11_godot_jolt_composition_preflight.ps1"] =
        "QSDK_R23D11_GODOT_JOLT_COMPOSITION_PASS"
}
foreach ($entry in $expectedRunners.GetEnumerator()) {
    $output = & pwsh -NoLogo -NoProfile -File (Join-Path $repoRoot $entry.Key) 2>&1 |
        Out-String
    Assert-R23D11Routes (
        $LASTEXITCODE -eq 0 -and $output.Contains([string]$entry.Value)
    ) "QSDK-R23D11 native route failed: $($entry.Key); $output"
}

$engineCount = 2 + [int](-not $SkipGodot)
$identityCount = 8 + (3 * [int](-not $SkipGodot))
$canaryCount = 14 + (7 * [int](-not $SkipGodot))
$mutationCount = 36 + (18 * [int](-not $SkipGodot))
$temporalCanaryCount = 10 + (5 * [int](-not $SkipGodot))
Write-Host (
    "QSDK_R23D11_NATIVE_ROUTES_PASS engines=$engineCount godot=$(-not $SkipGodot) " +
    "identities=$identityCount canaries=$canaryCount mutations=$mutationCount " +
    "temporal_canaries=$temporalCanaryCount physical_refusals=$engineCount " +
    "workers=0 models=0 worlds=0 physical_authority=False turning=False"
)

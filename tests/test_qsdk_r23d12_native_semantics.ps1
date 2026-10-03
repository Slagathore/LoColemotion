#requires -Version 7.0

param([switch]$SkipGodot)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$contractPath = Join-Path (
    $repoRoot
) "sdk\turning\r23d12_native_semantics_contract_v1.json"

function Assert-R23D12Native([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

Assert-R23D12Native (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D12 native-semantics repository identity changed"
Assert-R23D12Native (Test-Path -LiteralPath $contractPath -PathType Leaf) (
    "QSDK-R23D12 native-semantics contract missing"
)

$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$cross = $contract.cross_language_conformance
$next = $contract.next_implementation_boundary
$authorization = $contract.authorization
$claims = $contract.claim_boundary
Assert-R23D12Native (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d12_native_semantics_contract_v1" -and
    [string]$contract.status -ceq
        "stage_one_three_engine_zero_world_native_semantics_mirrors_no_workers_no_physical_authorization" -and
    [string]$contract.stage_zero_boundary.stage_zero_commit -ceq
        "6116fcef7c28c3bc91d2ad115dca61b9a97bfb0a" -and
    [string]$contract.stage_zero_boundary.stage_zero_closure_commit -ceq
        "9abbce04541a7f4a5f97e041a05a05a5f81a0dc5" -and
    [string]$contract.stage_one_source_boundary.parent_commit -ceq
        "9abbce04541a7f4a5f97e041a05a05a5f81a0dc5" -and
    @($contract.native_routes).Count -eq 3 -and
    [int]$cross.independent_native_schema_implementation_count -eq 3 -and
    [int]$cross.reference_oracle_import_count -eq 0 -and
    [int]$cross.total_valid_canary_count -eq 21 -and
    [int]$cross.total_active_cross_product_count -eq 18 -and
    [int]$cross.total_mutation_control_count -eq 42 -and
    [int]$cross.total_critical_failure_shape_count -eq 3 -and
    [int]$cross.total_physical_refusal_count -eq 3 -and
    [bool]$cross.all_three_valid_canary_vectors_exact -and
    [bool]$cross.all_three_active_cross_product_vectors_exact -and
    [bool]$cross.all_three_mutation_code_sequences_exact -and
    -not [bool]$next.production_trace_schema_implemented -and
    [int]$next.physical_worker_count -eq 0 -and
    -not [bool]$authorization.physical_worker_implementation_authorized -and
    -not [bool]$authorization.physical_execution_authorized -and
    [int]$authorization.physical_process_launch_count -eq 0 -and
    [int]$authorization.model_construction_count -eq 0 -and
    [int]$authorization.world_attempt_count -eq 0 -and
    [int]$authorization.world_build_count -eq 0 -and
    [bool]$claims.three_engine_native_semantics_mirrors -and
    -not [bool]$claims.three_engine_physical_workers -and
    -not [bool]$claims.measurement_semantics_physically_tested -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority
) "QSDK-R23D12 native-semantics identity or authority changed"

$bindings = [Collections.Generic.List[object]]::new()
foreach ($pair in @(
    @("declaration_path", "declaration_raw_sha256"),
    @("pure_oracle_path", "pure_oracle_raw_sha256"),
    @("pure_oracle_test_path", "pure_oracle_test_raw_sha256"),
    @("declaration_audit_path", "declaration_audit_raw_sha256"),
    @("stage_zero_gate_path", "stage_zero_gate_raw_sha256"),
    @("stage_zero_closure_audit_path", "stage_zero_closure_audit_raw_sha256")
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
Assert-R23D12Native ($bindings.Count -eq 16) (
    "QSDK-R23D12 native-semantics source binding count changed"
)
foreach ($binding in $bindings) {
    $absolute = Join-Path $repoRoot $binding.path
    Assert-R23D12Native (
        (Test-Path -LiteralPath $absolute -PathType Leaf) -and
        (Get-RawSha256 $absolute) -ceq [string]$binding.hash
    ) "QSDK-R23D12 native-semantics source changed: $($binding.path)"
}

foreach ($futurePath in @(
    "sdk\turning\r23d12_physical_trace.py",
    "sdk\turning\test_r23d12_physical_trace.py",
    "sdk\turning\r23d12_physical_evaluator.py",
    "sdk\turning\test_r23d12_physical_evaluator.py",
    "sdk\publish_qsdk_r23d12_trace.ps1",
    "sdk\turning\r23d12_stage_two_evidence_contract_v1.json",
    "sdk\turning\r23d12_physical_implementation_contract_v1.json",
    "sdk\run_qsdk_r23d12_authorization_canaries.ps1",
    "sdk\run_qsdk_r23d12_supervisor.ps1",
    "sdk\run_qsdk_r23d12_zero_world_gate.ps1",
    "sdk\adapters\mujoco\sporespore_mujoco_adapter\qsdk_r23d12_physical.py",
    "sdk\adapters\rapier\src\qsdk_r23d12_physical.rs"
)) {
    Assert-R23D12Native (
        -not (Test-Path -LiteralPath (Join-Path $repoRoot $futurePath))
    ) "QSDK-R23D12 undeclared later-stage path exists: $futurePath"
}

$stageZeroOutput = & pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File (
    Join-Path $repoRoot "tests\test_qsdk_r23d12_stage_zero_closure.ps1"
) 2>&1 | Out-String
Assert-R23D12Native (
    $LASTEXITCODE -eq 0 -and
    $stageZeroOutput.Contains("QSDK_R23D12_STAGE_ZERO_CLOSURE_PASS")
) "QSDK-R23D12 immutable stage-zero closure did not pass: $stageZeroOutput"

$runnerSpecs = [ordered]@{
    "sdk\run_qsdk_r23d12_mujoco_semantics_preflight.ps1" =
        "QSDK_R23D12_MUJOCO_SEMANTICS_PASS"
    "sdk\run_qsdk_r23d12_rapier_semantics_preflight.ps1" =
        "QSDK_R23D12_RAPIER_SEMANTICS_PASS"
}
if (-not $SkipGodot) {
    $runnerSpecs["sdk\run_qsdk_r23d12_godot_jolt_semantics_preflight.ps1"] =
        "QSDK_R23D12_GODOT_JOLT_SEMANTICS_PASS"
}
$validHashes = [Collections.Generic.List[string]]::new()
$crossHashes = [Collections.Generic.List[string]]::new()
foreach ($entry in $runnerSpecs.GetEnumerator()) {
    $output = & pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File (
        Join-Path $repoRoot $entry.Key
    ) 2>&1 | Out-String
    Assert-R23D12Native (
        $LASTEXITCODE -eq 0 -and
        $output.Contains([string]$entry.Value) -and
        $output.Contains("valid=7 cross_product=6 mutations=14 critical=True") -and
        $output.Contains("workers=0 models=0 worlds=0 physical_authority=False")
    ) "QSDK-R23D12 native route failed: $($entry.Key); $output"
    $match = [regex]::Match(
        $output,
        "valid_vector_sha256=([0-9a-f]{64}) cross_vector_sha256=([0-9a-f]{64})"
    )
    Assert-R23D12Native $match.Success (
        "QSDK-R23D12 native route omitted semantic hashes: $($entry.Key)"
    )
    $validHashes.Add($match.Groups[1].Value)
    $crossHashes.Add($match.Groups[2].Value)
}

$expectedValidHash = ([string]$cross.valid_canary_vector_sha256).Substring(7)
$expectedCrossHash = ([string]$cross.active_cross_product_vector_sha256).Substring(7)
Assert-R23D12Native (
    @($validHashes | Select-Object -Unique).Count -eq 1 -and
    @($crossHashes | Select-Object -Unique).Count -eq 1 -and
    $validHashes[0] -ceq $expectedValidHash -and
    $crossHashes[0] -ceq $expectedCrossHash
) "QSDK-R23D12 native-language semantic vectors diverged"

$engineCount = 2 + [int](-not $SkipGodot)
Write-Host (
    "QSDK_R23D12_NATIVE_SEMANTICS_PASS engines=$engineCount " +
    "godot=$(-not $SkipGodot) bindings=$($bindings.Count) " +
    "valid=$($engineCount * 7) cross_product=$($engineCount * 6) " +
    "mutations=$($engineCount * 14) critical=$engineCount " +
    "physical_refusals=$engineCount vectors_exact=True workers=0 models=0 " +
    "worlds=0 physical_authority=False turning=False equivalence=False"
)

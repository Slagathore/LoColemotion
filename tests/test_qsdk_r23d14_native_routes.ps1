#requires -Version 7.0

param([switch]$SkipGodot)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$contractPath = Join-Path (
    $repoRoot
) "sdk\turning\r23d14_native_route_contract_v1.json"
$stageOneCommit = "d91ca5cf860da229e01d3102f715d06948d8281d"

function Assert-R23D14Native([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256([string]$Path) {
    return (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-GitBlobRawSha256([string]$Commit, [string]$Path) {
    $blobOid = (git -C $repoRoot rev-parse ("$Commit`:$Path")).Trim()
    Assert-R23D14Native ($LASTEXITCODE -eq 0) (
        "QSDK-R23D14 pinned native-route blob unavailable: $Path"
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    [void]$start.ArgumentList.Add("cat-file")
    [void]$start.ArgumentList.Add("blob")
    [void]$start.ArgumentList.Add($blobOid)
    $process = [Diagnostics.Process]::Start($start)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($process.StandardOutput.BaseStream)
        $process.WaitForExit()
        Assert-R23D14Native ($process.ExitCode -eq 0) (
            "QSDK-R23D14 pinned native-route blob read failed: $Path"
        )
        return [Convert]::ToHexString($hash).ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
        $process.Dispose()
    }
}

Assert-R23D14Native (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D14 native-route repository identity changed"
Assert-R23D14Native (Test-Path -LiteralPath $contractPath -PathType Leaf) (
    "QSDK-R23D14 native-route contract missing"
)

$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$stageZero = $contract.stage_zero_boundary
$cross = $contract.cross_language_conformance
$next = $contract.next_implementation_boundary
$authorization = $contract.authorization
$claims = $contract.claim_boundary
Assert-R23D14Native (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d14_native_route_contract_v1" -and
    [string]$contract.status -ceq
        "stage_one_three_engine_zero_world_native_temporal_mirrors_no_workers_no_physical_authorization" -and
    [string]$stageZero.stage_zero_commit -ceq
        "ad34a258c101361a67f50becb2e3d3ed02c3e3b8" -and
    [string]$stageZero.stage_zero_tree_git_oid -ceq
        "b4379a5604138ba7400fe55247cd620a51453386" -and
    [string]$stageZero.attribute_family_commit -ceq
        "5cf482638e3c15c5ec051e3a4687e740ccd99dad" -and
    [int]$stageZero.attribute_family_rule_count -eq 17 -and
    [string]$stageZero.stage_zero_publication_and_provenance_commit -ceq
        "7c9046cd6197f6ca7111cc104a8dc512dcbcf07d" -and
    [string]$contract.stage_one_source_boundary.parent_commit -ceq
        "7c9046cd6197f6ca7111cc104a8dc512dcbcf07d" -and
    @($contract.native_routes).Count -eq 3 -and
    @($contract.native_routes.engine_id) -join "|" -ceq
        "mujoco|rapier_parry|godot_jolt" -and
    [int]$cross.independent_native_implementation_count -eq 3 -and
    [int]$cross.reference_oracle_import_count -eq 0 -and
    [int]$cross.total_valid_canary_count -eq 36 -and
    [int]$cross.total_mutation_control_count -eq 42 -and
    [int]$cross.total_retained_positive_timing_shape_count -eq 3 -and
    [int]$cross.total_retained_negative_timing_shape_count -eq 3 -and
    [int]$cross.total_passive_exact_zero_shape_count -eq 3 -and
    [int]$cross.total_physical_refusal_count -eq 3 -and
    [bool]$cross.all_three_valid_canary_vectors_exact -and
    [bool]$cross.all_three_mutation_code_sequences_exact -and
    [bool]$cross.all_three_retained_positive_timing_shapes_pass -and
    [bool]$cross.all_three_retained_negative_timing_shapes_pass -and
    [bool]$cross.all_three_passive_routes_are_exact_zero -and
    [int]$cross.arm_identity_heading_sign_and_outcome_input_count -eq 0 -and
    -not [bool]$next.production_trace_schema_implemented -and
    [int]$next.physical_worker_count -eq 0 -and
    -not [bool]$authorization.physical_worker_implementation_authorized -and
    -not [bool]$authorization.physical_execution_authorized -and
    [int]$authorization.physical_process_launch_count -eq 0 -and
    [int]$authorization.model_construction_count -eq 0 -and
    [int]$authorization.world_attempt_count -eq 0 -and
    [int]$authorization.world_build_count -eq 0 -and
    [bool]$claims.three_engine_native_temporal_mirrors -and
    -not [bool]$claims.three_engine_physical_workers -and
    -not [bool]$claims.selected_policy_physically_confirmed_under_r23d14 -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority
) "QSDK-R23D14 native-route identity or authority changed"

$bindings = [Collections.Generic.List[object]]::new()
foreach ($pair in @(
    @("declaration_path", "declaration_raw_sha256"),
    @("pure_oracle_path", "pure_oracle_raw_sha256"),
    @("pure_oracle_test_path", "pure_oracle_test_raw_sha256"),
    @("declaration_audit_path", "declaration_audit_raw_sha256"),
    @("stage_zero_gate_path", "stage_zero_gate_raw_sha256"),
    @("stage_zero_closure_audit_path", "stage_zero_closure_audit_raw_sha256"),
    @("checkout_provenance_audit_path", "checkout_provenance_audit_raw_sha256")
)) {
    $bindings.Add([pscustomobject]@{
        path = [string]$stageZero[$pair[0]]
        hash = ([string]$stageZero[$pair[1]]).Substring(7)
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
Assert-R23D14Native (
    $bindings.Count -eq 17 -and
    @($bindings.path | Group-Object -CaseSensitive | Where-Object Count -gt 1).Count -eq 0
) "QSDK-R23D14 native-route source binding set changed"
foreach ($binding in $bindings) {
    $absolute = Join-Path $repoRoot $binding.path
    Assert-R23D14Native (
        (Test-Path -LiteralPath $absolute -PathType Leaf) -and
        (Get-GitBlobRawSha256 $stageOneCommit $binding.path) -ceq
            [string]$binding.hash
    ) "QSDK-R23D14 pinned native-route source changed: $($binding.path)"
    if (
        [string]$binding.path -cne
            [string]$stageZero.checkout_provenance_audit_path
    ) {
        Assert-R23D14Native (
            (Get-RawSha256 $absolute) -ceq [string]$binding.hash
        ) "QSDK-R23D14 live native-route source changed: $($binding.path)"
    }
    $attribute = git -C $repoRoot check-attr eol -- ([string]$binding.path)
    Assert-R23D14Native (
        $LASTEXITCODE -eq 0 -and
        ($attribute -join "`n").EndsWith("eol: lf", [StringComparison]::Ordinal)
    ) "QSDK-R23D14 bound source is not LF-stable: $($binding.path)"
}

foreach ($futurePath in @(
    "sdk\turning\r23d14_physical_trace.py",
    "sdk\turning\test_r23d14_physical_trace.py",
    "sdk\turning\r23d14_physical_evaluator.py",
    "sdk\turning\test_r23d14_physical_evaluator.py",
    "sdk\publish_qsdk_r23d14_trace.ps1",
    "sdk\turning\r23d14_physical_implementation_contract_v1.json",
    "sdk\run_qsdk_r23d14_supervisor.ps1",
    "sdk\run_qsdk_r23d14_zero_world_gate.ps1",
    "sdk\adapters\mujoco\sporespore_mujoco_adapter\qsdk_r23d14_physical.py",
    "sdk\adapters\rapier\src\qsdk_r23d14_physical.rs",
    "tests\test_sdk_qsdk_r23d14_godot_jolt_physical_worker.gd"
)) {
    Assert-R23D14Native (
        -not (Test-Path -LiteralPath (Join-Path $repoRoot $futurePath))
    ) "QSDK-R23D14 undeclared later-stage path exists: $futurePath"
}

$stageZeroOutput = & pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File (
    Join-Path $repoRoot "tests\test_qsdk_r23d14_stage_zero_closure.ps1"
) 2>&1 | Out-String
Assert-R23D14Native (
    $LASTEXITCODE -eq 0 -and
    $stageZeroOutput.Contains("QSDK_R23D14_STAGE_ZERO_CLOSURE_PASS")
) "QSDK-R23D14 immutable stage-zero closure did not pass: $stageZeroOutput"

$provenanceOutput = & pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File (
    Join-Path $repoRoot "tests\test_closure_evidence_provenance_contract.ps1"
) 2>&1 | Out-String
Assert-R23D14Native (
    $LASTEXITCODE -eq 0 -and
    $provenanceOutput.Contains("CLOSURE_EVIDENCE_PROVENANCE_CONTRACT_PASS")
) "QSDK-R23D14 checkout provenance contract did not pass: $provenanceOutput"

$runnerSpecs = [ordered]@{
    "sdk\run_qsdk_r23d14_mujoco_temporal_preflight.ps1" =
        "QSDK_R23D14_MUJOCO_TEMPORAL_PASS"
    "sdk\run_qsdk_r23d14_rapier_temporal_preflight.ps1" =
        "QSDK_R23D14_RAPIER_TEMPORAL_PASS"
}
if (-not $SkipGodot) {
    $runnerSpecs["sdk\run_qsdk_r23d14_godot_jolt_temporal_preflight.ps1"] =
        "QSDK_R23D14_GODOT_JOLT_TEMPORAL_PASS"
}
$validHashes = [Collections.Generic.List[string]]::new()
$mutationHashes = [Collections.Generic.List[string]]::new()
foreach ($entry in $runnerSpecs.GetEnumerator()) {
    $output = & pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File (
        Join-Path $repoRoot $entry.Key
    ) 2>&1 | Out-String
    Assert-R23D14Native (
        $LASTEXITCODE -eq 0 -and
        $output.Contains([string]$entry.Value) -and
        $output.Contains("valid=12 mutations=14 positive=True negative=True") -and
        $output.Contains("passive_zero=True") -and
        $output.Contains("physical_refusals=1") -and
        $output.Contains("workers=0 models=0 worlds=0") -and
        $output.Contains("physical_authority=False")
    ) "QSDK-R23D14 native route failed: $($entry.Key); $output"
    $match = [regex]::Match(
        $output,
        "valid_vector_sha256=([0-9a-f]{64}) mutation_vector_sha256=([0-9a-f]{64})"
    )
    Assert-R23D14Native $match.Success (
        "QSDK-R23D14 native route omitted semantic hashes: $($entry.Key)"
    )
    $validHashes.Add($match.Groups[1].Value)
    $mutationHashes.Add($match.Groups[2].Value)
}

$expectedValidHash = ([string]$cross.valid_canary_vector_sha256).Substring(7)
$expectedMutationHash = (
    [string]$cross.mutation_failure_code_vector_sha256
).Substring(7)
Assert-R23D14Native (
    @($validHashes | Select-Object -Unique).Count -eq 1 -and
    @($mutationHashes | Select-Object -Unique).Count -eq 1 -and
    $validHashes[0] -ceq $expectedValidHash -and
    $mutationHashes[0] -ceq $expectedMutationHash
) "QSDK-R23D14 native-language semantic vectors diverged"

$engineCount = 2 + [int](-not $SkipGodot)
Write-Host (
    "QSDK_R23D14_NATIVE_ROUTES_PASS engines=$engineCount " +
    "godot=$(-not $SkipGodot) bindings=$($bindings.Count) " +
    "valid=$($engineCount * 12) mutations=$($engineCount * 14) " +
    "positive=$engineCount negative=$engineCount passive_zero=$engineCount " +
    "physical_refusals=$engineCount vectors_exact=True " +
    "workers=0 models=0 worlds=0 physical_authority=False turning=False " +
    "equivalence=False"
)

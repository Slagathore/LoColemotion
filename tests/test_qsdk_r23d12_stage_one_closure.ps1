#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$stageOneCommit = "f5c686e94c4702cac9a8aadcbcc3e42e2bb83bbb"
$stageOneParent = "9abbce04541a7f4a5f97e041a05a05a5f81a0dc5"
$stageOneTree = "0a6a540a8faca16813a5225596d95fbfe4593fdb"
$fixedBlobs = [ordered]@{
    ".gitattributes" =
        "0f2b3e6b2a658e06f3bb8d724d3f5d0ff36853d8ce1d35ff5fac295a0095286b"
    "sdk/turning/r23d12_native_semantics_contract_v1.json" =
        "b7e908964d9aba4233268a9167cbff987defcea4952bb27e08a9faa5ee588042"
    "tests/test_qsdk_r23d12_native_semantics.ps1" =
        "86e9426ffe11bd33431c56a5f000519d470ecab5518cbbafa1b690cbc3ee20db"
    "sdk/run_qsdk_r23d12_stage_one_gate.ps1" =
        "53546ae78a973397d56ee22f7717153564b105e59f9af3cf08cdaf07692be701"
    "tests/test_qsdk_r23d12_stage_zero_closure.ps1" =
        "ae43174ff6f211fa572d23501545f15fba6e3c5db0e376ce62439ac8756b3c52"
}
$futurePaths = @(
    "sdk/turning/r23d12_physical_trace.py",
    "sdk/turning/test_r23d12_physical_trace.py",
    "sdk/turning/r23d12_physical_evaluator.py",
    "sdk/turning/test_r23d12_physical_evaluator.py",
    "sdk/publish_qsdk_r23d12_trace.ps1",
    "sdk/turning/r23d12_stage_two_evidence_contract_v1.json",
    "sdk/turning/r23d12_physical_implementation_contract_v1.json",
    "sdk/run_qsdk_r23d12_authorization_canaries.ps1",
    "sdk/run_qsdk_r23d12_supervisor.ps1",
    "sdk/run_qsdk_r23d12_zero_world_gate.ps1",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d12_physical.py",
    "sdk/adapters/rapier/src/qsdk_r23d12_physical.rs"
)

function Assert-R23D12StageOne([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D12StageOneBlobHash([string]$Commit, [string]$Path) {
    $blobOid = (git -C $repoRoot rev-parse ("$Commit`:$Path")).Trim()
    Assert-R23D12StageOne ($LASTEXITCODE -eq 0) (
        "QSDK-R23D12 stage-one blob unavailable: $Path"
    )
    $temporary = [IO.Path]::GetTempFileName()
    try {
        $start = [Diagnostics.ProcessStartInfo]::new()
        $start.FileName = "git"
        $start.WorkingDirectory = $repoRoot
        $start.UseShellExecute = $false
        $start.RedirectStandardOutput = $true
        [void]$start.ArgumentList.Add("cat-file")
        [void]$start.ArgumentList.Add("blob")
        [void]$start.ArgumentList.Add($blobOid)
        $process = [Diagnostics.Process]::Start($start)
        $stream = [IO.File]::Open(
            $temporary,
            [IO.FileMode]::Create,
            [IO.FileAccess]::Write,
            [IO.FileShare]::None
        )
        try { $process.StandardOutput.BaseStream.CopyTo($stream) }
        finally { $stream.Dispose() }
        $process.WaitForExit()
        Assert-R23D12StageOne ($process.ExitCode -eq 0) (
            "QSDK-R23D12 stage-one blob read failed: $Path"
        )
        return (
            Get-FileHash -LiteralPath $temporary -Algorithm SHA256
        ).Hash.ToLowerInvariant()
    }
    finally {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
}

Assert-R23D12StageOne (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D12 stage-one repository identity changed"

$resolvedCommit = (git -C $repoRoot rev-parse "$stageOneCommit^{commit}").Trim()
$resolvedParent = (git -C $repoRoot rev-parse "$stageOneCommit^").Trim()
$resolvedTree = (git -C $repoRoot rev-parse "$stageOneCommit^{tree}").Trim()
Assert-R23D12StageOne (
    $resolvedCommit -ceq $stageOneCommit -and
    $resolvedParent -ceq $stageOneParent -and
    $resolvedTree -ceq $stageOneTree
) "QSDK-R23D12 stage-one commit boundary changed"

$treePaths = @(git -C $repoRoot ls-tree -r --name-only $stageOneCommit)
foreach ($futurePath in $futurePaths) {
    Assert-R23D12StageOne ($treePaths -cnotcontains $futurePath) (
        "QSDK-R23D12 stage-one tree already contained future route: $futurePath"
    )
}
foreach ($entry in $fixedBlobs.GetEnumerator()) {
    Assert-R23D12StageOne (
        (Get-R23D12StageOneBlobHash $stageOneCommit $entry.Key) -ceq
            [string]$entry.Value
    ) "QSDK-R23D12 stage-one fixed blob changed: $($entry.Key)"
}

$contractSpec = (
    $stageOneCommit + ":sdk/turning/r23d12_native_semantics_contract_v1.json"
)
$contract = (git -C $repoRoot show $contractSpec | Out-String) |
    ConvertFrom-Json -AsHashtable -Depth 100
$cross = $contract.cross_language_conformance
$authorization = $contract.authorization
$claims = $contract.claim_boundary
Assert-R23D12StageOne (
    [string]$contract.status -ceq
        "stage_one_three_engine_zero_world_native_semantics_mirrors_no_workers_no_physical_authorization" -and
    @($contract.native_routes).Count -eq 3 -and
    [int]$cross.independent_native_schema_implementation_count -eq 3 -and
    [int]$cross.total_valid_canary_count -eq 21 -and
    [int]$cross.total_active_cross_product_count -eq 18 -and
    [int]$cross.total_mutation_control_count -eq 42 -and
    [int]$cross.total_critical_failure_shape_count -eq 3 -and
    [int]$cross.total_physical_refusal_count -eq 3 -and
    [string]$cross.valid_canary_vector_sha256 -ceq
        "sha256:5611bfa4acfba050b2e911b159148964dfb4d3cd9e04bdd22f09b6ddff7fc4a7" -and
    [string]$cross.active_cross_product_vector_sha256 -ceq
        "sha256:2075b785b8247e1c72cd827cbc38aab378b8d596dd02b839d4ceb77a791d6f4f" -and
    [int]$authorization.physical_process_launch_count -eq 0 -and
    [int]$authorization.model_construction_count -eq 0 -and
    [int]$authorization.world_attempt_count -eq 0 -and
    [int]$authorization.world_build_count -eq 0 -and
    -not [bool]$authorization.physical_execution_authorized -and
    [bool]$claims.three_engine_native_semantics_mirrors -and
    -not [bool]$claims.three_engine_physical_workers -and
    -not [bool]$claims.measurement_semantics_physically_tested -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority
) "QSDK-R23D12 stage-one authority changed"

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
Assert-R23D12StageOne ($bindings.Count -eq 16) (
    "QSDK-R23D12 stage-one source binding count changed"
)
foreach ($binding in $bindings) {
    Assert-R23D12StageOne (
        (Get-R23D12StageOneBlobHash $stageOneCommit $binding.path) -ceq
            [string]$binding.hash
    ) "QSDK-R23D12 stage-one source binding changed: $($binding.path)"
}

Write-Host (
    "QSDK_R23D12_STAGE_ONE_CLOSURE_PASS commit=$stageOneCommit " +
    "tree=$stageOneTree fixed_blobs=$($fixedBlobs.Count) " +
    "source_bindings=$($bindings.Count) routes=3 valid=21 cross_product=18 " +
    "mutations=42 critical=3 physical_refusals=3 vectors_exact=True " +
    "workers=0 models=0 worlds=0 physical_authority=False turning=False " +
    "equivalence=False"
)

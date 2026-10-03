#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$stageOneCommit = "8d2998c4d8d7a4b4e78232bfd34799945bec656a"
$stageOneParent = "7ba47f7df2fe0965235f2ecc0e4a522278bd6b92"
$stageOneTree = "02ad589f03aece450ca6fec371752944ad453ef0"
$fixedBlobs = [ordered]@{
    ".gitattributes" =
        "7c2d28406c8c2c46a8533c0aca19391e3a9652b754d7e19cbdbdfc2f1411e571"
    "sdk/turning/r23d13_native_route_contract_v1.json" =
        "c530e04c96d41e6af2f558c46ced62285e924f27d47bea8dfa2fc623253e75cc"
    "tests/test_qsdk_r23d13_native_routes.ps1" =
        "b0502d549ca3cbf718c18c936ce681c63a4194da4dfca9b1bde0f37b6d328c1b"
    "sdk/run_qsdk_r23d13_stage_one_gate.ps1" =
        "a8f2b54ac92209d7cd43340c5bfd391eb53afece49f8d15962a82048411279c5"
    "tests/test_qsdk_r23d13_stage_zero_closure.ps1" =
        "7d6d5d7504e078eebdc2ed904d987904bf5a7f27ca66a8cb25592eb9666cfb13"
}
$futurePaths = @(
    "sdk/turning/r23d13_physical_trace.py",
    "sdk/turning/test_r23d13_physical_trace.py",
    "sdk/turning/r23d13_physical_evaluator.py",
    "sdk/turning/test_r23d13_physical_evaluator.py",
    "sdk/publish_qsdk_r23d13_trace.ps1",
    "sdk/turning/r23d13_stage_two_evidence_contract_v1.json",
    "tests/test_qsdk_r23d13_stage_two_evidence.ps1",
    "sdk/turning/r23d13_physical_implementation_contract_v1.json",
    "sdk/run_qsdk_r23d13_authorization_canaries.ps1",
    "sdk/run_qsdk_r23d13_supervisor.ps1",
    "sdk/run_qsdk_r23d13_zero_world_gate.ps1",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d13_physical.py",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d13_physical.rs"
)

function Assert-R23D13StageOne([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D13StageOneBlobHash([string]$Commit, [string]$Path) {
    $blobOid = (git -C $repoRoot rev-parse ("$Commit`:$Path")).Trim()
    Assert-R23D13StageOne ($LASTEXITCODE -eq 0) (
        "QSDK-R23D13 stage-one blob unavailable: $Path"
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
        Assert-R23D13StageOne ($process.ExitCode -eq 0) (
            "QSDK-R23D13 stage-one blob read failed: $Path"
        )
        return (
            Get-FileHash -LiteralPath $temporary -Algorithm SHA256
        ).Hash.ToLowerInvariant()
    }
    finally {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
}

Assert-R23D13StageOne (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D13 stage-one repository identity changed"

$resolvedCommit = (git -C $repoRoot rev-parse "$stageOneCommit^{commit}").Trim()
$resolvedParent = (git -C $repoRoot rev-parse "$stageOneCommit^").Trim()
$resolvedTree = (git -C $repoRoot rev-parse "$stageOneCommit^{tree}").Trim()
Assert-R23D13StageOne (
    $resolvedCommit -ceq $stageOneCommit -and
    $resolvedParent -ceq $stageOneParent -and
    $resolvedTree -ceq $stageOneTree
) "QSDK-R23D13 stage-one commit boundary changed"

$treePaths = @(git -C $repoRoot ls-tree -r --name-only $stageOneCommit)
foreach ($futurePath in $futurePaths) {
    Assert-R23D13StageOne ($treePaths -cnotcontains $futurePath) (
        "QSDK-R23D13 stage-one tree already contained future route: $futurePath"
    )
}
foreach ($entry in $fixedBlobs.GetEnumerator()) {
    Assert-R23D13StageOne (
        (Get-R23D13StageOneBlobHash $stageOneCommit $entry.Key) -ceq
            [string]$entry.Value
    ) "QSDK-R23D13 stage-one fixed blob changed: $($entry.Key)"
}

$contractSpec = (
    $stageOneCommit + ":sdk/turning/r23d13_native_route_contract_v1.json"
)
$contract = (git -C $repoRoot show $contractSpec | Out-String) |
    ConvertFrom-Json -AsHashtable -Depth 100
$cross = $contract.cross_language_conformance
$authorization = $contract.authorization
$claims = $contract.claim_boundary
Assert-R23D13StageOne (
    [string]$contract.status -ceq
        "stage_one_three_engine_zero_world_native_authority_mirrors_no_workers_no_physical_authorization" -and
    @($contract.native_routes).Count -eq 3 -and
    [int]$cross.independent_native_implementation_count -eq 3 -and
    [int]$cross.total_valid_canary_count -eq 30 -and
    [int]$cross.total_mutation_control_count -eq 60 -and
    [int]$cross.total_critical_predecessor_shape_count -eq 3 -and
    [int]$cross.total_positive_no_regression_shape_count -eq 3 -and
    [int]$cross.total_passive_exact_zero_shape_count -eq 3 -and
    [int]$cross.total_physical_refusal_count -eq 3 -and
    [string]$cross.valid_canary_vector_sha256 -ceq
        "sha256:b682eaf89a76829d0e9728d5e988b067af2df76638ab1813e29d442a483b0cbd" -and
    [string]$cross.mutation_failure_code_vector_sha256 -ceq
        "sha256:8106abb4da4aaec1d41e09b1ab185dea7d415fd514055ebc6a53f5fddbe00915" -and
    [int]$authorization.physical_process_launch_count -eq 0 -and
    [int]$authorization.model_construction_count -eq 0 -and
    [int]$authorization.world_attempt_count -eq 0 -and
    [int]$authorization.world_build_count -eq 0 -and
    -not [bool]$authorization.physical_execution_authorized -and
    [bool]$claims.three_engine_native_authority_mirrors -and
    -not [bool]$claims.three_engine_physical_workers -and
    -not [bool]$claims.residual_pose_authority_hypothesis_physically_tested -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority
) "QSDK-R23D13 stage-one authority changed"

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
Assert-R23D13StageOne ($bindings.Count -eq 16) (
    "QSDK-R23D13 stage-one source binding count changed"
)
foreach ($binding in $bindings) {
    Assert-R23D13StageOne (
        (Get-R23D13StageOneBlobHash $stageOneCommit $binding.path) -ceq
            [string]$binding.hash
    ) "QSDK-R23D13 stage-one source binding changed: $($binding.path)"
}

Write-Host (
    "QSDK_R23D13_STAGE_ONE_CLOSURE_PASS commit=$stageOneCommit " +
    "tree=$stageOneTree fixed_blobs=$($fixedBlobs.Count) " +
    "source_bindings=$($bindings.Count) routes=3 valid=30 mutations=60 " +
    "critical=3 positive_no_regression=3 passive_zero=3 " +
    "physical_refusals=3 vectors_exact=True workers=0 models=0 worlds=0 " +
    "physical_authority=False turning=False equivalence=False"
)

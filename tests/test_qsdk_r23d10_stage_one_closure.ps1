#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$stageOneCommit = "60f475352fde6958798b4a0d7c21fb0dc354f87b"
$stageOneParent = "6b39e1df77a403d474924d203ab706f8fa495687"
$fixedBlobs = [ordered]@{
    "sdk/turning/r23d10_native_route_contract_v1.json" =
        "232eb24838c2a12ea4cbf6d88954c999415319b154891841f472cbe90aa9881c"
    "tests/test_qsdk_r23d10_native_routes.ps1" =
        "0f3231225e5ba258034cb702d1ae483fc14f6a93c5eeb6092335f5dd7a629522"
    "tests/test_qsdk_r23d10_stage_zero_closure.ps1" =
        "9d3ffa6e69d030fde2dfdde31b5d5a80143f0dbb83344fa95fd50f46f3545e03"
}
$futurePaths = @(
    "sdk/turning/r23d10_physical_trace.py",
    "sdk/turning/test_r23d10_physical_trace.py",
    "sdk/turning/r23d10_physical_evaluator.py",
    "sdk/turning/test_r23d10_physical_evaluator.py",
    "sdk/publish_qsdk_r23d10_trace.ps1",
    "sdk/turning/r23d10_stage_two_evidence_contract_v1.json",
    "tests/test_qsdk_r23d10_stage_two_evidence.ps1",
    "sdk/turning/r23d10_physical_implementation_contract_v1.json",
    "sdk/run_qsdk_r23d10_authorization_canaries.ps1",
    "sdk/run_qsdk_r23d10_supervisor.ps1",
    "sdk/run_qsdk_r23d10_zero_world_gate.ps1"
)

function Assert-R23D10StageOne([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D10StageOneBlobHash([string]$Commit, [string]$Path) {
    $blobOid = (git -C $repoRoot rev-parse ("$Commit`:$Path")).Trim()
    Assert-R23D10StageOne ($LASTEXITCODE -eq 0) (
        "QSDK-R23D10 stage-one blob unavailable: $Path"
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
        Assert-R23D10StageOne ($process.ExitCode -eq 0) (
            "QSDK-R23D10 stage-one blob read failed: $Path"
        )
        return (
            Get-FileHash -LiteralPath $temporary -Algorithm SHA256
        ).Hash.ToLowerInvariant()
    }
    finally {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
}

Assert-R23D10StageOne (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D10 stage-one repository identity changed"

$resolvedCommit = (git -C $repoRoot rev-parse "$stageOneCommit^{commit}").Trim()
$resolvedParent = (git -C $repoRoot rev-parse "$stageOneCommit^").Trim()
Assert-R23D10StageOne (
    $resolvedCommit -ceq $stageOneCommit -and
    $resolvedParent -ceq $stageOneParent
) "QSDK-R23D10 stage-one commit boundary changed"

$treePaths = @(git -C $repoRoot ls-tree -r --name-only $stageOneCommit)
foreach ($futurePath in $futurePaths) {
    Assert-R23D10StageOne ($treePaths -cnotcontains $futurePath) (
        "QSDK-R23D10 stage-one tree already contained future route: $futurePath"
    )
}
foreach ($entry in $fixedBlobs.GetEnumerator()) {
    Assert-R23D10StageOne (
        (Get-R23D10StageOneBlobHash $stageOneCommit $entry.Key) -ceq
            [string]$entry.Value
    ) "QSDK-R23D10 stage-one fixed blob changed: $($entry.Key)"
}

$contractSpec = (
    $stageOneCommit + ":sdk/turning/r23d10_native_route_contract_v1.json"
)
$contract = (git -C $repoRoot show $contractSpec | Out-String) |
    ConvertFrom-Json -AsHashtable -Depth 100
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
foreach ($pair in @(
    @("implementation_path", "implementation_raw_sha256"),
    @("test_path", "test_raw_sha256"),
    @("runner_path", "runner_raw_sha256")
)) {
    $bindings.Add([pscustomobject]@{
        path = [string]$contract.evaluator_cli_integration_canary[$pair[0]]
        hash = ([string]$contract.evaluator_cli_integration_canary[$pair[1]]).Substring(7)
    })
}
Assert-R23D10StageOne (
    [string]$contract.status -ceq
        "stage_one_three_engine_zero_world_temporal_mirrors_and_evaluator_cli_canary_no_workers_no_physical_authorization" -and
    [int]$contract.frozen_native_temporal_contract.native_route_count -eq 3 -and
    [int]$contract.frozen_native_temporal_contract.native_identity_preflight_count -eq 11 -and
    [int]$contract.frozen_native_temporal_contract.evaluator_cli_command_count -eq 2 -and
    [int]$contract.next_implementation_boundary.production_physical_worker_count -eq 0 -and
    -not [bool]$contract.next_implementation_boundary.production_evaluator_implemented -and
    -not [bool]$contract.next_implementation_boundary.serialized_supervisor_implemented -and
    -not [bool]$contract.authorization.physical_execution_authorized -and
    -not [bool]$contract.claim_boundary.three_engine_physical_workers -and
    -not [bool]$contract.claim_boundary.command_conditioned_turning -and
    $bindings.Count -eq 17
) "QSDK-R23D10 stage-one claim boundary changed"
foreach ($binding in $bindings) {
    Assert-R23D10StageOne (
        (Get-R23D10StageOneBlobHash $stageOneCommit $binding.path) -ceq
            $binding.hash
    ) "QSDK-R23D10 stage-one source binding changed: $($binding.path)"
}

Write-Host (
    "QSDK_R23D10_STAGE_ONE_CLOSURE_PASS commit=$stageOneCommit " +
    "fixed_blobs=$($fixedBlobs.Count) source_bindings=$($bindings.Count) " +
    "future_routes=0 workers=0 models=0 worlds=0 physical_authority=False"
)

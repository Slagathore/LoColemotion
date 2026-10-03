#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$stageOneCommit = "ddb8f962a93daa65f812204e56c2e1bdd78233d7"
$stageOneParent = "53df1481aa03e1d638a46222c51f0d40fdb457ed"
$fixedBlobs = [ordered]@{
    "sdk/turning/r23d9_native_route_contract_v1.json" =
        "036fc79699ab1b3bbf3c20f23b830e528d0a192dc463111da8a0e681e9407579"
    "tests/test_qsdk_r23d9_native_routes.ps1" =
        "fb571a447438ad3837050d0116ca2b01a7f31eeb57c424888933c08c8faa6fa6"
    "tests/test_qsdk_r23d9_stage_zero_closure.ps1" =
        "aadb9558483532a5296a036c9637064967cbe00705ea2a79551be5c32fa80eea"
}
$futurePaths = @(
    "sdk/turning/r23d9_physical_implementation_contract_v1.json",
    "sdk/turning/r23d9_physical_evaluator.py",
    "sdk/turning/r23d9_dependency_closure.ps1",
    "sdk/turning/r23d9_terminal_marker_classifier.ps1",
    "sdk/publish_qsdk_r23d9_trace.ps1",
    "sdk/run_qsdk_r23d9_authorization_canaries.ps1",
    "sdk/run_qsdk_r23d9_supervisor.ps1",
    "sdk/run_qsdk_r23d9_zero_world_gate.ps1"
)

function Assert-R23D9StageOne([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D9StageOneBlobHash([string]$Commit, [string]$Path) {
    $blobOid = (git -C $repoRoot rev-parse ("$Commit`:$Path")).Trim()
    Assert-R23D9StageOne ($LASTEXITCODE -eq 0) (
        "QSDK-R23D9 stage-one blob unavailable: $Path"
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
        try {
            $process.StandardOutput.BaseStream.CopyTo($stream)
        }
        finally {
            $stream.Dispose()
        }
        $process.WaitForExit()
        Assert-R23D9StageOne ($process.ExitCode -eq 0) (
            "QSDK-R23D9 stage-one blob read failed: $Path"
        )
        return (
            Get-FileHash -LiteralPath $temporary -Algorithm SHA256
        ).Hash.ToLowerInvariant()
    }
    finally {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
}

Assert-R23D9StageOne (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D9 stage-one repository identity changed"

$resolvedCommit = (git -C $repoRoot rev-parse "$stageOneCommit^{commit}").Trim()
$resolvedParent = (git -C $repoRoot rev-parse "$stageOneCommit^").Trim()
Assert-R23D9StageOne (
    $resolvedCommit -ceq $stageOneCommit -and
    $resolvedParent -ceq $stageOneParent
) "QSDK-R23D9 stage-one commit boundary changed"

$treePaths = @(git -C $repoRoot ls-tree -r --name-only $stageOneCommit)
foreach ($futurePath in $futurePaths) {
    Assert-R23D9StageOne ($treePaths -cnotcontains $futurePath) (
        "QSDK-R23D9 stage-one tree already contained future route: $futurePath"
    )
}
foreach ($entry in $fixedBlobs.GetEnumerator()) {
    Assert-R23D9StageOne (
        (Get-R23D9StageOneBlobHash $stageOneCommit $entry.Key) -ceq
            [string]$entry.Value
    ) "QSDK-R23D9 stage-one fixed blob changed: $($entry.Key)"
}

$contractSpec = (
    $stageOneCommit + ":sdk/turning/r23d9_native_route_contract_v1.json"
)
$contract = (git -C $repoRoot show $contractSpec | Out-String) |
    ConvertFrom-Json -AsHashtable -Depth 100
$bindings = [Collections.Generic.List[object]]::new()
foreach ($binding in $contract.unchanged_neutral_acquisition_authorities) {
    $bindings.Add([pscustomobject]@{
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
            $bindings.Add([pscustomobject]@{
                path = [string]$route[$pair[0]]
                hash = ([string]$route[$pair[1]]).Substring(7)
            })
        }
    }
}
Assert-R23D9StageOne (
    [string]$contract.status -ceq
        "stage_one_three_engine_zero_world_temporal_mirrors_physical_workers_not_implemented_no_physical_authorization" -and
    [int]$contract.frozen_native_temporal_contract.native_route_count -eq 3 -and
    [int]$contract.frozen_native_temporal_contract.native_identity_preflight_count -eq 11 -and
    [int]$contract.next_implementation_boundary.production_physical_worker_count -eq 0 -and
    -not [bool]$contract.authorization.physical_execution_authorized -and
    -not [bool]$contract.claim_boundary.three_engine_physical_workers -and
    -not [bool]$contract.claim_boundary.command_conditioned_turning -and
    $bindings.Count -eq 14
) "QSDK-R23D9 stage-one claim boundary changed"
foreach ($binding in $bindings) {
    Assert-R23D9StageOne (
        (Get-R23D9StageOneBlobHash $stageOneCommit $binding.path) -ceq
            $binding.hash
    ) "QSDK-R23D9 stage-one source binding changed: $($binding.path)"
}

Write-Host (
    "QSDK_R23D9_STAGE_ONE_CLOSURE_PASS commit=$stageOneCommit " +
    "fixed_blobs=$($fixedBlobs.Count) source_bindings=$($bindings.Count) " +
    "future_routes=0 workers=0 models=0 worlds=0 physical_authority=False"
)

#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$stageOneCommit = "9686045903c3e6ccaf237276526c52c7862e67d2"
$stageOneParent = "40ebd67d3a1936be23a9ee6d1a6761e931dfb5d8"
$fixedBlobs = [ordered]@{
    ".gitattributes" =
        "ce6fb58aeb56999efeb035d8ae3265d07641499e3342f5fab44e5103e2d4d334"
    "sdk/turning/r23d11_native_route_contract_v1.json" =
        "070323b7ee0063070e85c4a9585948182e02bf733790b81dd6daa914c8e90afa"
    "tests/test_qsdk_r23d11_native_routes.ps1" =
        "b8059b1d63d81972a64398f9c020a8535b37734cde33134a3bc75a9d758cdfb9"
    "tests/test_qsdk_r23d11_stage_zero_closure.ps1" =
        "cd5850b3c87933f25820f2023716bc85c43c830066ad6caa6e3af8595447eb2f"
}
$futurePaths = @(
    "sdk/turning/r23d11_physical_trace.py",
    "sdk/turning/test_r23d11_physical_trace.py",
    "sdk/turning/r23d11_physical_evaluator.py",
    "sdk/turning/test_r23d11_physical_evaluator.py",
    "sdk/publish_qsdk_r23d11_trace.ps1",
    "sdk/turning/r23d11_stage_two_evidence_contract_v1.json",
    "tests/test_qsdk_r23d11_stage_two_evidence.ps1",
    "sdk/turning/r23d11_physical_implementation_contract_v1.json",
    "sdk/run_qsdk_r23d11_authorization_canaries.ps1",
    "sdk/run_qsdk_r23d11_supervisor.ps1",
    "sdk/run_qsdk_r23d11_zero_world_gate.ps1"
)

function Assert-R23D11StageOne([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D11StageOneBlobHash([string]$Commit, [string]$Path) {
    $blobOid = (git -C $repoRoot rev-parse ("$Commit`:$Path")).Trim()
    Assert-R23D11StageOne ($LASTEXITCODE -eq 0) (
        "QSDK-R23D11 stage-one blob unavailable: $Path"
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
        Assert-R23D11StageOne ($process.ExitCode -eq 0) (
            "QSDK-R23D11 stage-one blob read failed: $Path"
        )
        return (
            Get-FileHash -LiteralPath $temporary -Algorithm SHA256
        ).Hash.ToLowerInvariant()
    }
    finally {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
}

Assert-R23D11StageOne (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D11 stage-one repository identity changed"

$resolvedCommit = (git -C $repoRoot rev-parse "$stageOneCommit^{commit}").Trim()
$resolvedParent = (git -C $repoRoot rev-parse "$stageOneCommit^").Trim()
Assert-R23D11StageOne (
    $resolvedCommit -ceq $stageOneCommit -and
    $resolvedParent -ceq $stageOneParent
) "QSDK-R23D11 stage-one commit boundary changed"

$treePaths = @(git -C $repoRoot ls-tree -r --name-only $stageOneCommit)
foreach ($futurePath in $futurePaths) {
    Assert-R23D11StageOne ($treePaths -cnotcontains $futurePath) (
        "QSDK-R23D11 stage-one tree already contained future route: $futurePath"
    )
}
foreach ($entry in $fixedBlobs.GetEnumerator()) {
    Assert-R23D11StageOne (
        (Get-R23D11StageOneBlobHash $stageOneCommit $entry.Key) -ceq
            [string]$entry.Value
    ) "QSDK-R23D11 stage-one fixed blob changed: $($entry.Key)"
}

$contractSpec = (
    $stageOneCommit + ":sdk/turning/r23d11_native_route_contract_v1.json"
)
$contract = (git -C $repoRoot show $contractSpec | Out-String) |
    ConvertFrom-Json -AsHashtable -Depth 100
$composition = $contract.frozen_native_composition_contract
$authorization = $contract.authorization
$claims = $contract.claim_boundary
Assert-R23D11StageOne (
    [string]$contract.status -ceq
        "stage_one_three_engine_zero_world_composition_mirrors_no_workers_no_physical_authorization" -and
    [int]$composition.native_route_count -eq 3 -and
    [int]$composition.native_identity_preflight_count -eq 11 -and
    [int]$composition.composition_canary_count -eq 21 -and
    [int]$composition.mutation_refusal_count -eq 54 -and
    [int]$composition.inherited_temporal_canary_count -eq 15 -and
    [int]$composition.physical_refusal_count -eq 3 -and
    [int]$authorization.physical_process_launch_count -eq 0 -and
    [int]$authorization.model_construction_count -eq 0 -and
    [int]$authorization.world_attempt_count -eq 0 -and
    [int]$authorization.world_build_count -eq 0 -and
    -not [bool]$authorization.physical_execution_authorized -and
    [bool]$claims.three_engine_native_composition_mirrors -and
    -not [bool]$claims.three_engine_physical_workers -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.physical_acceptance_authority
) "QSDK-R23D11 stage-one authority changed"

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
Assert-R23D11StageOne ($bindings.Count -eq 15) (
    "QSDK-R23D11 stage-one source binding count changed"
)
foreach ($binding in $bindings) {
    Assert-R23D11StageOne (
        (Get-R23D11StageOneBlobHash $stageOneCommit $binding.path) -ceq
            [string]$binding.hash
    ) "QSDK-R23D11 stage-one source binding changed: $($binding.path)"
}

Write-Host (
    "QSDK_R23D11_STAGE_ONE_CLOSURE_PASS commit=$stageOneCommit " +
    "fixed_blobs=$($fixedBlobs.Count) source_bindings=$($bindings.Count) " +
    "routes=3 identities=11 canaries=21 mutations=54 workers=0 models=0 " +
    "worlds=0 physical_authority=False turning=False"
)

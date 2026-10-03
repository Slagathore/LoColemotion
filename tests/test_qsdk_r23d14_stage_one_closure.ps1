#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$stageOneCommit = "d91ca5cf860da229e01d3102f715d06948d8281d"
$stageOneParent = "7c9046cd6197f6ca7111cc104a8dc512dcbcf07d"
$stageOneTree = "cd363a264efa7073af7cf49e427d655ffe8ba51e"
$fixedBlobs = [ordered]@{
    ".gitattributes" =
        "45169c80cd4ff46a706eb654814795242c6b55121d2bb2bda117515ff7f22518"
    "sdk/turning/r23d14_native_route_contract_v1.json" =
        "31dc032deeb7c5fc37de78aae434ea6da608b34e0a2dff07bdea905f4939e91e"
    "tests/test_qsdk_r23d14_native_routes.ps1" =
        "53323d001563ccc7bb669012453cf87b4bebe919a3465348f3ecd3135d1a593e"
    "sdk/run_qsdk_r23d14_stage_one_gate.ps1" =
        "3c2b382be375ea6c4860637615cc943d6cff83c08d84ddad62c489e1e965755d"
    "tests/test_qsdk_r23d14_stage_zero_closure.ps1" =
        "0e9ca6db27a4fe956ebe49ef8f14550997a88a94a4844fce0d9cec9b8d54df8b"
}
$futurePaths = @(
    "sdk/turning/r23d14_physical_trace.py",
    "sdk/turning/test_r23d14_physical_trace.py",
    "sdk/turning/r23d14_physical_evaluator.py",
    "sdk/turning/test_r23d14_physical_evaluator.py",
    "sdk/publish_qsdk_r23d14_trace.ps1",
    "sdk/turning/r23d14_physical_implementation_contract_v1.json",
    "sdk/run_qsdk_r23d14_supervisor.ps1",
    "sdk/run_qsdk_r23d14_zero_world_gate.ps1",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d14_physical.py",
    "sdk/adapters/rapier/src/qsdk_r23d14_physical.rs",
    "tests/test_sdk_qsdk_r23d14_godot_jolt_physical_worker.gd"
)

function Assert-R23D14StageOne([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D14StageOneBlobHash([string]$Commit, [string]$Path) {
    $blobOid = (git -C $repoRoot rev-parse ("$Commit`:$Path")).Trim()
    Assert-R23D14StageOne ($LASTEXITCODE -eq 0) (
        "QSDK-R23D14 stage-one blob unavailable: $Path"
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
        Assert-R23D14StageOne ($process.ExitCode -eq 0) (
            "QSDK-R23D14 stage-one blob read failed: $Path"
        )
        return [Convert]::ToHexString($hash).ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
        $process.Dispose()
    }
}

Assert-R23D14StageOne (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D14 stage-one repository identity changed"

$resolvedCommit = (git -C $repoRoot rev-parse "$stageOneCommit^{commit}").Trim()
$resolvedParent = (git -C $repoRoot rev-parse "$stageOneCommit^").Trim()
$resolvedTree = (git -C $repoRoot rev-parse "$stageOneCommit^{tree}").Trim()
$originMain = (git -C $repoRoot rev-parse origin/main).Trim()
$liveMain = @(
    git -C $repoRoot ls-remote origin refs/heads/main
)[0].Split("`t")[0].Trim()
git -C $repoRoot merge-base --is-ancestor $stageOneCommit $originMain
$stageOneIsPublishedAncestor = $LASTEXITCODE -eq 0
Assert-R23D14StageOne (
    $resolvedCommit -ceq $stageOneCommit -and
    $resolvedParent -ceq $stageOneParent -and
    $resolvedTree -ceq $stageOneTree -and
    $stageOneIsPublishedAncestor -and
    $originMain -ceq $liveMain
) "QSDK-R23D14 stage-one commit publication boundary changed"

$treePaths = @(git -C $repoRoot ls-tree -r --name-only $stageOneCommit)
foreach ($futurePath in $futurePaths) {
    Assert-R23D14StageOne ($treePaths -cnotcontains $futurePath) (
        "QSDK-R23D14 stage-one tree already contained future route: $futurePath"
    )
}
foreach ($entry in $fixedBlobs.GetEnumerator()) {
    Assert-R23D14StageOne (
        (Get-R23D14StageOneBlobHash $stageOneCommit $entry.Key) -ceq
            [string]$entry.Value
    ) "QSDK-R23D14 stage-one fixed blob changed: $($entry.Key)"
}

$contractSpec = (
    $stageOneCommit + ":sdk/turning/r23d14_native_route_contract_v1.json"
)
$contract = (git -C $repoRoot show $contractSpec | Out-String) |
    ConvertFrom-Json -AsHashtable -Depth 100
$cross = $contract.cross_language_conformance
$authorization = $contract.authorization
$claims = $contract.claim_boundary
Assert-R23D14StageOne (
    [string]$contract.status -ceq
        "stage_one_three_engine_zero_world_native_temporal_mirrors_no_workers_no_physical_authorization" -and
    @($contract.native_routes).Count -eq 3 -and
    @($contract.native_routes.engine_id) -join "|" -ceq
        "mujoco|rapier_parry|godot_jolt" -and
    [int]$cross.independent_native_implementation_count -eq 3 -and
    [int]$cross.total_valid_canary_count -eq 36 -and
    [int]$cross.total_mutation_control_count -eq 42 -and
    [int]$cross.total_retained_positive_timing_shape_count -eq 3 -and
    [int]$cross.total_retained_negative_timing_shape_count -eq 3 -and
    [int]$cross.total_passive_exact_zero_shape_count -eq 3 -and
    [int]$cross.total_physical_refusal_count -eq 3 -and
    [string]$cross.valid_canary_vector_sha256 -ceq
        "sha256:9cb7d5148b4a00dd6a4099fb73783de0ce496cdecd792304b3880031cd17b8a9" -and
    [string]$cross.mutation_failure_code_vector_sha256 -ceq
        "sha256:e12ef85ecc25c2f0eeaaa237e71e7c48f801ec882b683e5adf7d696af6082e0d" -and
    [int]$authorization.physical_process_launch_count -eq 0 -and
    [int]$authorization.model_construction_count -eq 0 -and
    [int]$authorization.world_attempt_count -eq 0 -and
    [int]$authorization.world_build_count -eq 0 -and
    -not [bool]$authorization.physical_execution_authorized -and
    [bool]$claims.three_engine_native_temporal_mirrors -and
    -not [bool]$claims.three_engine_physical_workers -and
    -not [bool]$claims.selected_policy_physically_confirmed_under_r23d14 -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority
) "QSDK-R23D14 stage-one authority changed"

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
Assert-R23D14StageOne ($bindings.Count -eq 17) (
    "QSDK-R23D14 stage-one source binding count changed"
)
foreach ($binding in $bindings) {
    Assert-R23D14StageOne (
        (Get-R23D14StageOneBlobHash $stageOneCommit $binding.path) -ceq
            [string]$binding.hash
    ) "QSDK-R23D14 stage-one source binding changed: $($binding.path)"
}

Write-Host (
    "QSDK_R23D14_STAGE_ONE_CLOSURE_PASS commit=$stageOneCommit " +
    "tree=$stageOneTree fixed_blobs=$($fixedBlobs.Count) " +
    "source_bindings=$($bindings.Count) routes=3 valid=36 mutations=42 " +
    "positive=3 negative=3 passive_zero=3 physical_refusals=3 " +
    "vectors_exact=True workers=0 models=0 worlds=0 " +
    "physical_authority=False turning=False equivalence=False"
)

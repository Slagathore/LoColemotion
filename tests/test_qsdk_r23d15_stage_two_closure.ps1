#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$closurePath = Join-Path $repoRoot "sdk\turning\r23d15_stage_two_closure_v1.json"
$sourceCommit = "784099a591f51acdf336bd6b3a6580d05ee488e1"
$sourceParent = "b875c8e685b31fde6a1578e4fdc1ff2e883c33e6"
$sourceTree = "b0e622f9edac65de7ee88cdeff827e260e36e574"

function Assert-R23D15StageTwoClosure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D15StageTwoBlobMetadata([string]$BlobOid) {
    $temporary = [IO.Path]::GetTempFileName()
    try {
        $start = [Diagnostics.ProcessStartInfo]::new()
        $start.FileName = "git"
        $start.WorkingDirectory = $repoRoot
        $start.UseShellExecute = $false
        $start.RedirectStandardOutput = $true
        $start.RedirectStandardError = $true
        [void]$start.ArgumentList.Add("cat-file")
        [void]$start.ArgumentList.Add("blob")
        [void]$start.ArgumentList.Add($BlobOid)
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $start
        Assert-R23D15StageTwoClosure $process.Start() "Git blob process did not start"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $stream = [IO.File]::Open(
            $temporary,
            [IO.FileMode]::Create,
            [IO.FileAccess]::Write,
            [IO.FileShare]::None
        )
        try { $process.StandardOutput.BaseStream.CopyTo($stream) }
        finally { $stream.Dispose() }
        $process.WaitForExit()
        Assert-R23D15StageTwoClosure ($process.ExitCode -eq 0) (
            "Git blob read failed: " + $stderrTask.GetAwaiter().GetResult()
        )
        return [ordered]@{
            raw_sha256 = "sha256:" + (
                Get-FileHash -Algorithm SHA256 -LiteralPath $temporary
            ).Hash.ToLowerInvariant()
            byte_length = (Get-Item -LiteralPath $temporary).Length
            text = [IO.File]::ReadAllText($temporary)
        }
    }
    finally {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
}

Assert-R23D15StageTwoClosure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D15 stage-two closure repository identity changed"
Assert-R23D15StageTwoClosure (
    Test-Path -LiteralPath $closurePath -PathType Leaf
) "QSDK-R23D15 stage-two closure is missing"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D15StageTwoClosure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d15_stage_two_closure_v1" -and
    [string]$closure.status -ceq
        "closed_immutable_clean_pushed_physical_implementation_zero_world_only" -and
    [string]$closure.campaign_id -ceq (
        "QSDK-R23D15-PRODUCTION-COMPOSITION-RECOVERY-" +
        "THREE-ENGINE-TURN-CONFIRMATION"
    ) -and
    [string]$closure.gate_id -ceq "QSDK-R23D15" -and
    [string]$closure.release_gate_id -ceq "QSDK-R23"
) "QSDK-R23D15 stage-two closure identity changed"

$identity = $closure.source_identity
Assert-R23D15StageTwoClosure (
    [string]$identity.commit -ceq $sourceCommit -and
    [string]$identity.parent_commit -ceq $sourceParent -and
    [string]$identity.tree_git_oid -ceq $sourceTree -and
    [bool]$identity.clean_at_post_push_gate -and
    [bool]$identity.local_origin_live_main_equal_after_push -and
    [bool]$identity.published_on_main -and
    (git -C $repoRoot rev-parse "$sourceCommit^{commit}").Trim() -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "$sourceCommit^{tree}").Trim() -ceq $sourceTree -and
    (git -C $repoRoot rev-parse "$sourceCommit^").Trim() -ceq $sourceParent
) "QSDK-R23D15 stage-two source identity changed"

$originMain = (git -C $repoRoot rev-parse origin/main).Trim()
$liveMain = ((git -C $repoRoot ls-remote origin refs/heads/main) -split "\s+")[0]
& git -C $repoRoot merge-base --is-ancestor $sourceCommit $originMain
$originContains = $LASTEXITCODE -eq 0
& git -C $repoRoot merge-base --is-ancestor $sourceCommit $liveMain
$liveContains = $LASTEXITCODE -eq 0
Assert-R23D15StageTwoClosure ($originContains -and $liveContains) (
    "QSDK-R23D15 stage-two source is not published on origin/live main"
)

$bindings = @($closure.fixed_source_bindings)
Assert-R23D15StageTwoClosure (
    $bindings.Count -eq 19 -and
    [int]$closure.fixed_source_binding_count -eq 19 -and
    @($bindings.path | Select-Object -Unique).Count -eq 19 -and
    @($bindings.git_blob_oid | Select-Object -Unique).Count -eq 19
) "QSDK-R23D15 stage-two source-binding inventory changed"

$pinnedText = @{}
foreach ($binding in $bindings) {
    $path = [string]$binding.path
    $blob = (git -C $repoRoot rev-parse "$sourceCommit`:$path").Trim()
    Assert-R23D15StageTwoClosure (
        $LASTEXITCODE -eq 0 -and $blob -ceq [string]$binding.git_blob_oid
    ) "QSDK-R23D15 stage-two blob identity changed: $path"
    $metadata = Get-R23D15StageTwoBlobMetadata $blob
    Assert-R23D15StageTwoClosure (
        [string]$metadata.raw_sha256 -ceq [string]$binding.raw_sha256 -and
        [long]$metadata.byte_length -eq [long]$binding.byte_length
    ) "QSDK-R23D15 stage-two blob bytes changed: $path"
    $pinnedText[$path] = [string]$metadata.text
}

$implementationPath = [string]$closure.implementation_contract_path
$implementationBinding = @($bindings | Where-Object {
    [string]$_.path -ceq $implementationPath
})
Assert-R23D15StageTwoClosure (
    $implementationBinding.Count -eq 1 -and
    [string]$closure.implementation_contract_raw_sha256 -ceq
        [string]$implementationBinding[0].raw_sha256
) "QSDK-R23D15 stage-two implementation binding changed"
$implementation = [string]$pinnedText[$implementationPath] |
    ConvertFrom-Json -AsHashtable -Depth 100
$workerDependencies = @(
    foreach ($workerId in @($implementation.dependency_closure.declared_worker_ids)) {
        @($implementation.dependency_closure.required_dependency_paths_by_worker[$workerId])
    }
) | Sort-Object -Unique -CaseSensitive
Assert-R23D15StageTwoClosure (
    [string]$implementation.schema_version -ceq
        "sporespore_qsdk_r23d15_physical_implementation_contract_v1" -and
    [string]$implementation.status -ceq
        "dormant_physical_implementation_zero_world_only_pending_clean_push_freeze" -and
    @($implementation.workers).Count -eq 3 -and
    @($implementation.workers | Where-Object {
        [int]$_.physical_world_count_before_freeze -ne 0
    }).Count -eq 0 -and
    [int]$implementation.dependency_closure.declared_unique_dependency_count -eq 75 -and
    $workerDependencies.Count -eq 75 -and
    @($implementation.source_binding_policy.exact_paths).Count -eq 102 -and
    [bool]$implementation.lineage.r23d14_tight_gated_horizon_inherited_unchanged -and
    -not [bool]$implementation.lineage.new_temporal_controller_created -and
    -not [bool]$implementation.authorization.physical_execution_authorized -and
    -not [bool]$implementation.authorization.physical_acceptance_authority -and
    [int]$implementation.authorization.world_attempt_count -eq 0 -and
    [int]$implementation.authorization.world_build_count -eq 0
) "QSDK-R23D15 pinned physical implementation contract changed"

$gate = $closure.post_push_complete_zero_world_gate
$behavior = $closure.implementation_behavior
Assert-R23D15StageTwoClosure (
    [string]$gate.executed_from_exact_source_commit -ceq $sourceCommit -and
    [int]$gate.exit_code -eq 0 -and
    [double]$gate.elapsed_seconds -gt 0.0 -and
    [string]$gate.terminal_marker -ceq "QSDK_R23D15_ZERO_WORLD_PASS" -and
    [int]$gate.physical_implementation_gate_pass_count -eq 1 -and
    [int]$gate.runtime_materialization_pass_count -eq 1 -and
    [int]$gate.external_runtime_binding_pass_count -eq 4 -and
    [int]$gate.immutable_lineage_closure_pass_count -eq 2 -and
    [int]$gate.dependency_and_marker_gate_pass_count -eq 1 -and
    [int]$gate.closure_evidence_provenance_gate_pass_count -eq 1 -and
    [int]$gate.authorization_canary_runner_preflight_pass_count -eq 1 -and
    [int]$gate.declared_worker_dependency_count -eq 75 -and
    [int]$gate.dependency_removal_canary_count -eq 75 -and
    [int]$gate.terminal_marker_family_count -eq 3 -and
    [int]$gate.terminal_marker_case_count -eq 15 -and
    [int]$gate.physical_worker_gate_pass_count -eq 3 -and
    [int]$gate.production_evaluator_test_count -eq 7 -and
    [int]$gate.physical_authorization_refusal_count -eq 1 -and
    [int]$gate.matrix_declared_cell_count -eq 9 -and
    [int]$gate.trace_rows_per_cell -eq 3952 -and
    [int]$gate.physical_process_launch_count -eq 0 -and
    [int]$gate.model_construction_count -eq 0 -and
    [int]$gate.world_attempt_count -eq 0 -and
    [int]$gate.world_build_count -eq 0 -and
    -not [bool]$gate.physical_execution_authorized -and
    -not [bool]$gate.physical_acceptance_authority -and
    [int]$behavior.worker_implementation_count -eq 3 -and
    [int]$behavior.declared_worker_identity_count -eq 9 -and
    [int]$behavior.declared_unique_dependency_count -eq 75 -and
    [int]$behavior.dependency_removal_canary_count -eq 75 -and
    [int]$behavior.source_exact_path_count -eq 102 -and
    [int]$behavior.resolved_source_binding_count -eq 115 -and
    [bool]$behavior.r23d14_tight_gated_horizon_inherited_unchanged -and
    [bool]$behavior.r23d15_composition_recovery_identity_enabled -and
    [bool]$behavior.serialized_supervisor_implemented -and
    [bool]$behavior.content_addressed_retention_before_marker_interpretation -and
    [bool]$behavior.physical_bypass_refused_before_attempt_or_world
) "QSDK-R23D15 post-push stage-two result changed"

$treePaths = @(git -C $repoRoot ls-tree -r --name-only $sourceCommit)
Assert-R23D15StageTwoClosure (
    $treePaths -cnotcontains "sdk/turning/r23d15_physical_closure_v1.json"
) "QSDK-R23D15 stage-two tree already contained a physical-result closure"

$claims = $closure.claims
Assert-R23D15StageTwoClosure (
    [bool]$claims.physical_implementation_zero_world_qualified -and
    -not [bool]$claims.finite_three_engine_result_exists -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.bilateral_signed_turning -and
    -not [bool]$claims.portable_basic_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.q_sdk_r23_satisfied -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority -and
    -not [bool]$closure.next_boundary.physical_execution_authorized
) "QSDK-R23D15 stage-two claim boundary changed"

Write-Host (
    "QSDK_R23D15_STAGE_TWO_CLOSURE_PASS commit=$sourceCommit tree=$sourceTree " +
    "fixed_blobs=19 workers=3 identities=9 dependencies=75 " +
    "removal_canaries=75 source_paths=102 resolved_bindings=115 " +
    "evaluator_tests=7 marker_cases=15 models=0 worlds=0 " +
    "physical_authority=False turning=False equivalence=False"
)

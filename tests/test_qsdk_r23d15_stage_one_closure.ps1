#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$closurePath = Join-Path $repoRoot "sdk\turning\r23d15_stage_one_closure_v1.json"
$sourceCommit = "7217faa19ab08e145ce4262b89c53fcb201f4416"
$sourceParent = "cdadf9d467c310cfa83eeb7becd063fdd064fd2d"
$sourceTree = "187a540f6b54e768d833337d0ba946877653d94a"

function Assert-R23D15StageOneClosure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-R23D15StageOneBlobMetadata([string]$BlobOid) {
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
        Assert-R23D15StageOneClosure $process.Start() "Git blob process did not start"
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
        Assert-R23D15StageOneClosure ($process.ExitCode -eq 0) (
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

Assert-R23D15StageOneClosure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D15 stage-one closure repository identity changed"
Assert-R23D15StageOneClosure (
    Test-Path -LiteralPath $closurePath -PathType Leaf
) "QSDK-R23D15 stage-one closure is missing"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D15StageOneClosure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d15_stage_one_closure_v1" -and
    [string]$closure.status -ceq
        "closed_immutable_clean_pushed_stage_one_evidence_zero_world_only" -and
    [string]$closure.campaign_id -ceq (
        "QSDK-R23D15-PRODUCTION-COMPOSITION-RECOVERY-" +
        "THREE-ENGINE-TURN-CONFIRMATION"
    ) -and
    [string]$closure.gate_id -ceq "QSDK-R23D15" -and
    [string]$closure.release_gate_id -ceq "QSDK-R23"
) "QSDK-R23D15 stage-one closure identity changed"

$identity = $closure.source_identity
Assert-R23D15StageOneClosure (
    [string]$identity.commit -ceq $sourceCommit -and
    [string]$identity.parent_commit -ceq $sourceParent -and
    [string]$identity.tree_git_oid -ceq $sourceTree -and
    [bool]$identity.clean_at_post_push_gate -and
    [bool]$identity.local_origin_live_main_equal_after_push -and
    [bool]$identity.published_on_main -and
    (git -C $repoRoot rev-parse "$sourceCommit^{commit}").Trim() -ceq $sourceCommit -and
    (git -C $repoRoot rev-parse "$sourceCommit^{tree}").Trim() -ceq $sourceTree -and
    (git -C $repoRoot rev-parse "$sourceCommit^").Trim() -ceq $sourceParent
) "QSDK-R23D15 stage-one source identity changed"

$originMain = (git -C $repoRoot rev-parse origin/main).Trim()
$liveMain = ((git -C $repoRoot ls-remote origin refs/heads/main) -split "\s+")[0]
& git -C $repoRoot merge-base --is-ancestor $sourceCommit $originMain
$originContains = $LASTEXITCODE -eq 0
& git -C $repoRoot merge-base --is-ancestor $sourceCommit $liveMain
$liveContains = $LASTEXITCODE -eq 0
Assert-R23D15StageOneClosure ($originContains -and $liveContains) (
    "QSDK-R23D15 stage-one source is not published on origin/live main"
)

$fixedBindings = @($closure.fixed_source_bindings)
Assert-R23D15StageOneClosure (
    $fixedBindings.Count -eq 2 -and
    [int]$closure.fixed_source_binding_count -eq 2 -and
    @($fixedBindings.path | Select-Object -Unique).Count -eq 2 -and
    @($fixedBindings.git_blob_oid | Select-Object -Unique).Count -eq 2
) "QSDK-R23D15 stage-one fixed source-binding inventory changed"

$fixedText = @{}
foreach ($binding in $fixedBindings) {
    $path = [string]$binding.path
    $blob = (git -C $repoRoot rev-parse "$sourceCommit`:$path").Trim()
    Assert-R23D15StageOneClosure (
        $LASTEXITCODE -eq 0 -and $blob -ceq [string]$binding.git_blob_oid
    ) "QSDK-R23D15 stage-one fixed blob identity changed: $path"
    $metadata = Get-R23D15StageOneBlobMetadata $blob
    Assert-R23D15StageOneClosure (
        [string]$metadata.raw_sha256 -ceq [string]$binding.raw_sha256 -and
        [long]$metadata.byte_length -eq [long]$binding.byte_length
    ) "QSDK-R23D15 stage-one fixed blob bytes changed: $path"
    $fixedText[$path] = [string]$metadata.text
}

$contract = [string]$fixedText[
    "sdk/turning/r23d15_stage_one_evidence_contract_v1.json"
] | ConvertFrom-Json -AsHashtable -Depth 100
$sourceBindings = @($contract.source_bindings)
Assert-R23D15StageOneClosure (
    $sourceBindings.Count -eq 14 -and
    [int]$contract.source_binding_count -eq 14 -and
    [int]$closure.contract_declared_source_binding_count -eq 14 -and
    [int]$closure.effective_source_binding_count -eq 16 -and
    @($sourceBindings.path | Select-Object -Unique).Count -eq 14
) "QSDK-R23D15 stage-one inherited source-binding inventory changed"
foreach ($binding in $sourceBindings) {
    $path = [string]$binding.path
    $blob = (git -C $repoRoot rev-parse "$sourceCommit`:$path").Trim()
    Assert-R23D15StageOneClosure ($LASTEXITCODE -eq 0) (
        "QSDK-R23D15 stage-one inherited blob is missing: $path"
    )
    $metadata = Get-R23D15StageOneBlobMetadata $blob
    Assert-R23D15StageOneClosure (
        [string]$metadata.raw_sha256 -ceq [string]$binding.raw_sha256
    ) "QSDK-R23D15 stage-one inherited blob bytes changed: $path"
}

$science = $contract.frozen_scientific_question
$trace = $contract.production_trace_contract
$retention = $contract.content_addressed_retention
$evaluator = $contract.production_evaluator_contract
Assert-R23D15StageOneClosure (
    [string]$contract.status -ceq
        "stage_one_zero_world_trace_retention_and_direct_matrix_evaluator_complete_no_physical_workers" -and
    [string]$contract.matrix_stage_id -ceq
        "finite_three_engine_confirmation_recovery" -and
    -not [bool]$science.changed_from_r23d14 -and
    [int]$science.total_trace_row_count_per_cell -eq 3952 -and
    [int]$science.new_tunable_gain_count -eq 0 -and
    [int]$science.new_decision_threshold_count -eq 0 -and
    [int]$trace.declared_trace_identity_count -eq 9 -and
    [int]$trace.trace_test_count -eq 6 -and
    [bool]$trace.inherited_r23d14_temporal_oracle_unchanged -and
    [bool]$retention.content_addressed_before_terminal_entry -and
    [bool]$retention.production_evidence_override_forbidden -and
    [int]$evaluator.evaluator_test_count -eq 7 -and
    [int]$evaluator.retained_test_trace_identity_count -eq 10 -and
    [bool]$evaluator.valid_positive_negative_and_invalid_preserved -and
    -not [bool]$evaluator.formal_equivalence_inference_performed -and
    [int]$contract.physical_worker_count -eq 0 -and
    [int]$contract.world_build_count -eq 0 -and
    -not [bool]$contract.physical_execution_authorized
) "QSDK-R23D15 pinned stage-one evidence contract changed"

$gate = $closure.post_push_zero_world_gate
$behavior = $closure.evidence_behavior
Assert-R23D15StageOneClosure (
    [string]$gate.executed_from_exact_source_commit -ceq $sourceCommit -and
    [int]$gate.exit_code -eq 0 -and
    [double]$gate.elapsed_seconds -gt 0.0 -and
    [string]$gate.terminal_marker -ceq
        "QSDK_R23D15_STAGE_ONE_EVIDENCE_PASS" -and
    [int]$gate.source_binding_count -eq 14 -and
    [int]$gate.trace_test_count -eq 6 -and
    [int]$gate.evaluator_test_count -eq 7 -and
    [int]$gate.complete_test_count -eq 13 -and
    [int]$gate.declared_trace_identity_count -eq 9 -and
    [int]$gate.trace_rows_per_identity -eq 3952 -and
    [int]$gate.retained_test_trace_identity_count -eq 10 -and
    [int]$gate.physical_worker_count -eq 0 -and
    [int]$gate.physical_process_launch_count -eq 0 -and
    [int]$gate.model_construction_count -eq 0 -and
    [int]$gate.world_attempt_count -eq 0 -and
    [int]$gate.world_build_count -eq 0 -and
    -not [bool]$gate.physical_execution_authorized -and
    -not [bool]$gate.physical_acceptance_authority -and
    [bool]$behavior.all_nine_synthetic_traces_replayed -and
    [bool]$behavior.positive_complete_matrix_preserved -and
    [bool]$behavior.valid_negative_complete_matrix_preserved -and
    [bool]$behavior.execution_invalid_complete_matrix_preserved -and
    [bool]$behavior.content_addressed_trace_retention_replayed -and
    -not [bool]$behavior.worker_authored_outcome_bits_authoritative -and
    -not [bool]$behavior.formal_equivalence_inference_performed
) "QSDK-R23D15 post-push stage-one result changed"

$treePaths = @(git -C $repoRoot ls-tree -r --name-only $sourceCommit)
foreach ($futurePath in @($closure.future_paths_absent_from_stage_one_tree)) {
    Assert-R23D15StageOneClosure ($treePaths -cnotcontains [string]$futurePath) (
        "QSDK-R23D15 stage-one tree contained future path: $futurePath"
    )
}

$claims = $closure.claims
Assert-R23D15StageOneClosure (
    [bool]$claims.production_trace_and_direct_matrix_evaluator_zero_world_qualified -and
    -not [bool]$claims.finite_three_engine_result_exists -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.bilateral_signed_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.q_sdk_r23_satisfied -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority -and
    -not [bool]$closure.next_boundary.physical_execution_authorized
) "QSDK-R23D15 stage-one claim boundary changed"

Write-Host (
    "QSDK_R23D15_STAGE_ONE_CLOSURE_PASS commit=$sourceCommit " +
    "tree=$sourceTree fixed_blobs=2 source_bindings=14 effective=16 " +
    "trace_tests=6 evaluator_tests=7 complete_tests=13 identities=9 " +
    "rows=3952 retained_traces=10 workers=0 models=0 worlds=0 " +
    "physical_authority=False turning=False equivalence=False"
)

#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$closurePath = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_closure.json"
$freezePath = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_freeze_v3.json"
$run1Path = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_run1_result.json"
$run2Path = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_run2_result.json"
$sourceCommit = "8546e55a9ec9ed9d9cf3b2135a06ebbebb7bd90c"
$sourceTree = "9cf22f1c3f4bff2be7328a8916c4ed86ae5ac0dc"
$freezeSha256 = "f3af908ec8b8288a5c712152e3146e94f3f290c0f5c9262d846032355f4813f7"
$run1Sha256 = "790647a8a2be5894ea782b8c46884243bf287c99a533a915dd13bfac5d448b26"
$run2Sha256 = "c40fd2bceeddbb048fad9e73c748c6ce074db65eb504a3a183e8f5e4d8c10355"
$failedRun3Attestation = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "full-godot-conformance-v2-8546e55a-20260805T004634Z\attestation.json"
)

function Assert-Drp1Closure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Drp1ClosureRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

Assert-Drp1Closure (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Test-Path -LiteralPath $freezePath -PathType Leaf) -and
    (Test-Path -LiteralPath $run1Path -PathType Leaf) -and
    (Test-Path -LiteralPath $run2Path -PathType Leaf) -and
    (Get-Drp1ClosureRawSha256 $freezePath) -ceq $freezeSha256 -and
    (Get-Drp1ClosureRawSha256 $run1Path) -ceq $run1Sha256 -and
    (Get-Drp1ClosureRawSha256 $run2Path) -ceq $run2Sha256
) "DRP1 closure or immutable predecessor record is missing or changed"

& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-Drp1Closure ($LASTEXITCODE -eq 0) "DRP1 closed source commit is unavailable"
$historicalTree = (& git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim()
Assert-Drp1Closure ($historicalTree -ceq $sourceTree) (
    "DRP1 closed source tree changed"
)

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$ledger = [System.Collections.IDictionary]$closure.invocation_ledger
$run1 = [System.Collections.IDictionary]$ledger.run_one
$run2 = [System.Collections.IDictionary]$ledger.run_two
$run3 = [System.Collections.IDictionary]$ledger.run_three
$run4 = [System.Collections.IDictionary]$ledger.run_four
$evidence = [System.Collections.IDictionary]$closure.retained_operational_evidence
$conclusion = [System.Collections.IDictionary]$closure.regression_conclusion
$next = [System.Collections.IDictionary]$closure.next_work_authority

Assert-Drp1Closure (
    [string]$closure.schema_version -ceq
        "sporespore_balanced_wave_dynamic_receipt_projection_drp1_closure_v1" -and
    [string]$closure.status -ceq
        "complete_repeatable_dynamic_receipt_regression_passed" -and
    [string]$closure.regression_id -ceq
        "BW31N-DYNAMIC-RECEIPT-PROJECTION-REGRESSION-DRP1" -and
    [string]$closure.gate_id -ceq "DRP1" -and
    [string]$closure.closed_source_commit -ceq $sourceCommit -and
    [string]$closure.closed_source_tree_git_oid -ceq $sourceTree -and
    [string]$closure.revision_three_freeze.raw_sha256 -ceq $freezeSha256 -and
    [int]$closure.revision_three_freeze.source_binding_count -eq 36 -and
    [bool]$closure.revision_three_freeze.selected_freeze_schema_matches_required_schema
) "DRP1 closure identity or v3 freeze boundary changed"

Assert-Drp1Closure (
    [int]$ledger.full_conformance_regression_invocation_count -eq 4 -and
    [int]$ledger.complete_24_world_regression_run_count -eq 3 -and
    [int]$ledger.cumulative_regression_world_build_count -eq 72 -and
    [int]$ledger.cumulative_dynamic_receipt_count -eq 72 -and
    [int]$ledger.successful_dynamic_receipt_regression_run_count -eq 2 -and
    [int]$ledger.directly_retained_successful_run_count -eq 1 -and
    [int]$ledger.serial_continuation_proven_successful_run_count -eq 1 -and
    [int]$ledger.complete_invalid_nested_schema_run_count -eq 1 -and
    [int]$ledger.zero_world_launcher_invalid_invocation_count -eq 1
) "DRP1 invocation ledger counts changed"

Assert-Drp1Closure (
    [string]$run1.result_raw_sha256 -ceq $run1Sha256 -and
    [int]$run1.world_build_count -eq 24 -and
    [int]$run1.dynamic_receipt_count -eq 24 -and
    [int]$run1.passed_gate_count -eq 9 -and
    [int]$run1.expected_gate_count -eq 12 -and
    [string]$run1.disposition -ceq "implementation_invalid_nested_route_schema" -and
    -not [bool]$run1.locomotion_negative -and
    [string]$run2.result_raw_sha256 -ceq $run2Sha256 -and
    [int]$run2.world_build_count -eq 0 -and
    [int]$run2.physical_process_launch_count -eq 0 -and
    [int]$run2.source_binding_match_count -eq 32 -and
    [int]$run2.source_binding_mismatch_count -eq 0 -and
    [string]$run2.disposition -ceq
        "infrastructure_invalid_pre_world_schema_contradiction" -and
    -not [bool]$run2.locomotion_negative
) "DRP1 run-one or run-two immutable disposition changed"

Assert-Drp1Closure (
    [string]$run3.source_commit -ceq $sourceCommit -and
    [int]$run3.outer_wrapper_exit_code -eq 124 -and
    [int]$run3.outer_wrapper_timeout_seconds -eq 3604 -and
    [bool]$run3.conformance_child_survived_wrapper_timeout -and
    [int]$run3.world_build_count -eq 24 -and
    [int]$run3.dynamic_receipt_count -eq 24 -and
    [int]$run3.passed_gate_count -eq 12 -and
    [int]$run3.expected_gate_count -eq 12 -and
    [bool]$run3.regression_pass_proven_by_fail_closed_serial_continuation -and
    (@($run3.later_observed_conformance_children) -join "|") -ceq
        "bw19v_velocity_only_long_horizon_lc1_posthoc|bw19v_velocity_only_terminal_stance_ts1_posthoc" -and
    -not [bool]$run3.direct_aggregate_marker_retained -and
    $null -eq $run3.walking_observed_count_descriptive_only -and
    -not [bool]$run3.attestation_published -and
    -not [bool]$run3.attestation_parent_directory_created -and
    -not (Test-Path -LiteralPath $failedRun3Attestation) -and
    [string]$run3.full_conformance_disposition -ceq
        "infrastructure_incomplete_after_wrapper_timeout" -and
    -not [bool]$run3.locomotion_negative
) "DRP1 run-three wrapper-timeout boundary changed"

Assert-Drp1Closure (
    [string]$run4.source_commit -ceq $sourceCommit -and
    [int]$run4.world_build_count -eq 24 -and
    [int]$run4.dynamic_receipt_count -eq 24 -and
    [int]$run4.worker_exit_code_count -eq 24 -and
    [bool]$run4.all_worker_exit_codes_zero -and
    [bool]$run4.all_cells_present_in_exact_declared_order -and
    [int]$run4.cell_timeout_count -eq 0 -and
    [int]$run4.cell_retry_or_replacement_count -eq 0 -and
    [int]$run4.passed_gate_count -eq 12 -and
    [int]$run4.expected_gate_count -eq 12 -and
    [bool]$run4.complete_regression_passed -and
    [int]$run4.walking_observed_count_descriptive_only -eq 0 -and
    -not [bool]$run4.walking_count_used_by_evaluator -and
    -not [bool]$run4.candidate_or_policy_selected -and
    [bool]$run4.full_godot_conformance_passed -and
    [double]$run4.conformance_duration_seconds -eq 3387.0843122
) "DRP1 retained successful run result changed"

$attestationPath = [IO.Path]::GetFullPath([string]$evidence.attestation.path)
$stdoutPath = [IO.Path]::GetFullPath([string]$evidence.stdout.path)
$stderrPath = [IO.Path]::GetFullPath([string]$evidence.stderr.path)
foreach ($record in @(
    @{ object = $evidence.attestation; path = $attestationPath },
    @{ object = $evidence.stdout; path = $stdoutPath },
    @{ object = $evidence.stderr; path = $stderrPath }
)) {
    Assert-Drp1Closure (
        (Test-Path -LiteralPath $record.path -PathType Leaf) -and
        (Get-Drp1ClosureRawSha256 $record.path) -ceq
            [string]$record.object.raw_sha256 -and
        (Get-Item -LiteralPath $record.path).Length -eq
            [long]$record.object.byte_length
    ) "DRP1 retained operational evidence changed: $($record.path)"
}
Assert-Drp1Closure (
    [bool]$evidence.attestation.production_verifier_ok_before_closure -and
    @($evidence.attestation.production_verifier_failure_codes).Count -eq 0 -and
    -not [bool]$evidence.scientific_cell_evidence_retained -and
    -not [bool]$evidence.per_cell_dynamic_receipt_bodies_retained -and
    [bool]$evidence.ephemeral_authorization_and_evaluation_deleted -and
    [bool]$evidence.operational_log_retention_does_not_create_scientific_authority
) "DRP1 operational-evidence boundary changed"

$profilePrefixes = @("baseline", "rough", "push", "sensor_noise")
$seeds = @(22001, 22002, 22003)
$routes = @(
    @{ suffix = "reference"; id = "DRP1-REFERENCE-ROUTE" },
    @{ suffix = "successor"; id = "DRP1-SUCCESSOR-ROUTE" }
)
$expectedCells = [System.Collections.Generic.List[object]]::new()
foreach ($profile in $profilePrefixes) {
    foreach ($seed in $seeds) {
        foreach ($route in $routes) {
            $expectedCells.Add([ordered]@{
                cell = "${profile}_s${seed}_drp1_$($route.suffix)"
                route = [string]$route.id
            })
        }
    }
}
$startLines = @(Select-String -LiteralPath $stdoutPath -Pattern `
    '^DRP1_REGRESSION_CELL_START ' | ForEach-Object { $_.Line })
$completeLines = @(Select-String -LiteralPath $stdoutPath -Pattern `
    '^DRP1_REGRESSION_CELL_COMPLETE ' | ForEach-Object { $_.Line })
Assert-Drp1Closure (
    $startLines.Count -eq 24 -and $completeLines.Count -eq 24
) "DRP1 retained log does not contain exactly 24 cell starts and completions"
for ($i = 0; $i -lt 24; $i++) {
    $index = $i + 1
    $expectedStart = (
        "DRP1_REGRESSION_CELL_START index=$index/24 " +
        "cell=$($expectedCells[$i].cell) route=$($expectedCells[$i].route)"
    )
    $expectedComplete = (
        "DRP1_REGRESSION_CELL_COMPLETE index=$index/24 " +
        "cell=$($expectedCells[$i].cell) exit=0 receipt=True timeout=False"
    )
    Assert-Drp1Closure (
        $startLines[$i] -ceq $expectedStart -and
        $completeLines[$i] -ceq $expectedComplete
    ) "DRP1 retained cell order or outcome changed at index $index"
}

$passMarker = (
    "DRP1_FULL_GODOT_REGRESSION_PASS worlds=24 receipts=24 gates=12/12 " +
    "walking_descriptive=0/24 walking_used_by_evaluator=False " +
    "retained_evidence=False one_shot=False selection_authority=False " +
    "walking_authority=False physical_authority=False"
)
$passLines = @(Select-String -LiteralPath $stdoutPath -SimpleMatch $passMarker |
    ForEach-Object { $_.Line })
$publishMarker = (
    "FULL_CONFORMANCE_ATTESTATION_PUBLISHED path=" +
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "full-godot-conformance-v2-8546e55a-20260805T014942Z\attestation.json " +
    "sha256=sha256:490d5f0816141cb717d504f812736fdaba0c318a91553c2bbbdc03669ec6383f " +
    "source=$sourceCommit physical_authority=False"
)
Assert-Drp1Closure (
    $passLines.Count -eq 1 -and
    $passLines[0] -ceq $passMarker -and
    @(Select-String -LiteralPath $stdoutPath -SimpleMatch $publishMarker).Count -eq 1 -and
    @(Select-String -LiteralPath $stdoutPath -SimpleMatch `
        "SDK C0/C1 conformance passed.").Count -eq 1 -and
    @(Select-String -LiteralPath $stdoutPath -SimpleMatch `
        "DRP1_DYNAMIC_RECEIPT_RAW_CELL ").Count -eq 0
) "DRP1 retained aggregate, attestation, or nonretention marker changed"

$document = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Drp1Closure (
    [string]$document.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$document.status -ceq "full_godot_conformance_passed" -and
    [bool]$document.conformance.passed -and
    [string]$document.conformance.canonical_terminal_marker -ceq
        "SDK C0/C1 conformance passed." -and
    [string]$document.source.commit -ceq $sourceCommit -and
    [string]$document.source.tree_git_oid -ceq $sourceTree -and
    [string]$document.source.origin_main -ceq $sourceCommit -and
    [string]$document.source.live_github_main -ceq $sourceCommit -and
    [bool]$document.source.worktree_clean -and
    [bool]$document.source.clean_pushed_live -and
    [double]$document.conformance.duration_seconds -eq 3387.0843122
) "DRP1 retained attestation content changed"

foreach ($binding in @($document.source_bindings)) {
    $historicalOid = (& git -C $repoRoot rev-parse (
        "$sourceCommit`:$([string]$binding.path)"
    )).Trim()
    Assert-Drp1Closure (
        $LASTEXITCODE -eq 0 -and
        $historicalOid -ceq [string]$binding.git_blob_oid
    ) "DRP1 historical attestation binding changed: $([string]$binding.path)"
}

$lockSource = ((& git -C $repoRoot show (
    "$sourceCommit`:sdk/locomotion_operation_lock.ps1"
)) -join "`n") -replace '^#requires[^\r\n]*\r?\n', ''
$validatorSource = ((& git -C $repoRoot show (
    "$sourceCommit`:sdk/locomotion_full_conformance_attestation.ps1"
)) -join "`n") -replace '^#requires[^\r\n]*\r?\n', ''
Assert-Drp1Closure (
    $LASTEXITCODE -eq 0 -and
    $validatorSource -match 'Test-SporeSporeFullConformanceAttestationDocument'
) "DRP1 historical attestation verifier source changed"
Invoke-Expression $lockSource
Invoke-Expression $validatorSource
$historicalVerification = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $document `
    -ExpectedSource $document.source `
    -ExpectedGodotIdentity $document.godot `
    -ExpectedPowerShellIdentity $document.powershell `
    -ExpectedSourceBindings @($document.source_bindings)
Assert-Drp1Closure (
    [bool]$historicalVerification.ok -and
    @($historicalVerification.failure_codes).Count -eq 0 -and
    -not [bool]$historicalVerification.physical_acceptance_authority
) "DRP1 historical full-Godot attestation no longer verifies"

foreach ($entry in $document.claims.GetEnumerator()) {
    Assert-Drp1Closure (-not [bool]$entry.Value) (
        "DRP1 retained attestation claim inflated: $($entry.Key)"
    )
}
foreach ($entry in $closure.claim_boundary.GetEnumerator()) {
    Assert-Drp1Closure (-not [bool]$entry.Value) (
        "DRP1 closure claim inflated: $($entry.Key)"
    )
}

Assert-Drp1Closure (
    [bool]$conclusion.dynamic_reference_receipt_projection_passed -and
    [bool]$conclusion.dynamic_successor_receipt_projection_passed -and
    [bool]$conclusion.shared_outer_schema_passed -and
    [bool]$conclusion.route_specific_nested_schema_passed -and
    [bool]$conclusion.exact_matrix_passed -and
    [bool]$conclusion.candidate_authority_horizon_passed -and
    [bool]$conclusion.pre_authority_exclusion_passed -and
    [bool]$conclusion.challenge_realization_passed -and
    [bool]$conclusion.measurement_acquisition_passed -and
    [bool]$conclusion.candidate_application_passed -and
    [bool]$conclusion.outcome_complete_passed -and
    [bool]$conclusion.common_execution_integrity_passed -and
    [bool]$conclusion.all_scientific_and_release_claims_false_passed -and
    [bool]$conclusion.implementation_regression_positive -and
    -not [bool]$conclusion.locomotion_positive -and
    -not [bool]$conclusion.locomotion_negative -and
    [bool]$conclusion.zero_of_twenty_four_descriptive_walking_does_not_select_or_reject_a_route -and
    [bool]$next.drp1_regression_requirement_satisfied -and
    -not [bool]$next.same_source_regression_rerun_required -and
    [bool]$next.separately_preregistered_development_campaign_declaration_permitted -and
    -not [bool]$next.development_campaign_execution_authorized_by_this_closure -and
    -not [bool]$next.fresh_validation_seed_use_authorized -and
    (@($next.reserved_fresh_independent_validation_seed_ids) -join "|") -ceq
        "49101|49102|49103" -and
    [bool]$next.reserved_fresh_seeds_remain_unopened
) "DRP1 conclusion or next-work authority changed"

Write-Host (
    "DRP1_CLOSURE_PASS status=positive invocations=4 physical_runs=3 " +
    "successful_runs=2 directly_retained_successes=1 worlds=72 " +
    "latest_worlds=24 latest_receipts=24 gates=12/12 walking_descriptive=0/24 " +
    "walking_used_by_evaluator=False attestation=True " +
    "attestation_sha256=490d5f0816141cb717d504f812736fdaba0c318a91553c2bbbdc03669ec6383f " +
    "next_development_declaration_permitted=True fresh_validation_opened=False " +
    "selection_authority=False walking_authority=False physical_authority=False"
)

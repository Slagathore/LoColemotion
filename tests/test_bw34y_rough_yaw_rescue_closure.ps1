#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot `
    "balanced_wave_bw34y_rough_yaw_rescue_closure.json"
$runnerPath = Join-Path $sdkRoot `
    "run_balanced_wave_bw34y_rough_yaw_rescue.ps1"
$expectedClosureSha256 = `
    "7e8120d16ab8d2686e730b45ce2b51ac1c1912a8083ab7f0393f178504de7551"
$campaignId = "BW34Y-BW33N-ROUGH-YAW-RESCUE-DEVELOPMENT"
$gateId = "BW34Y"
$sourceCommit = "284c3a7fb7267fa1550490d9a9133042b26d8505"
$sourceTree = "33e115d3a702c49ecc303449e533e770b61b4f0d"
$attemptId = "cc27d3493c854ef584ada8dac3b56c6f"

function Assert-Bw34yClosure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Bw34yClosureRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-Bw34yClosureSequenceEqual {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Actual,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Expected
    )
    if ($Actual.Count -ne $Expected.Count) { return $false }
    for ($index = 0; $index -lt $Expected.Count; $index += 1) {
        if ([string]$Actual[$index] -cne [string]$Expected[$index]) {
            return $false
        }
    }
    return $true
}

function Assert-Bw34yHashedArtifact {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)]$Artifact,
        [Parameter(Mandatory)][string]$Label
    )
    $path = Join-Path $Root ([string]$Artifact.path)
    Assert-Bw34yClosure (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$Artifact.byte_length -and
        (Get-Bw34yClosureRawSha256 $path) -ceq [string]$Artifact.raw_sha256
    ) "$gateId retained $Label is missing or changed"
}

function Get-Bw34yEvidenceTreeDigest {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse)
    $rows = @(
        $files |
            ForEach-Object {
                $relative = [IO.Path]::GetRelativePath(
                    $Root,
                    $_.FullName
                ).Replace("\", "/")
                "{0}`t{1}`t{2}" -f (
                    $relative,
                    $_.Length,
                    (Get-Bw34yClosureRawSha256 $_.FullName)
                )
            } |
            Sort-Object
    )
    $text = ($rows -join "`n") + "`n"
    return [ordered]@{
        file_count = $files.Count
        total_byte_length = [long]($files | Measure-Object Length -Sum).Sum
        tree_sha256 = [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData(
                [Text.Encoding]::UTF8.GetBytes($text)
            )
        ).ToLowerInvariant()
    }
}

function Assert-Bw34yCasReceipt {
    param(
        [Parameter(Mandatory)]$Receipt,
        [Parameter(Mandatory)][string]$Label
    )
    $digest = [string]$Receipt.sha256
    Assert-Bw34yClosure (
        [string]$Receipt.schema_version -ceq
            "sporespore_content_addressed_artifact_receipt_v1" -and
        $digest -cmatch '^sha256:[0-9a-f]{64}$' -and
        -not [bool]$Receipt.test_only -and
        -not [bool]$Receipt.physical_acceptance_authority
    ) "$gateId $Label CAS receipt contract changed"
    $rawDigest = $digest.Substring("sha256:".Length)
    $payloadPath = [IO.Path]::GetFullPath([string]$Receipt.payload_path)
    $manifestPath = [IO.Path]::GetFullPath([string]$Receipt.manifest_path)
    $expectedDirectory = [IO.Path]::GetFullPath(
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\artifacts\sha256\$rawDigest"
    )
    Assert-Bw34yClosure (
        (Split-Path -Parent $payloadPath) -ceq $expectedDirectory -and
        (Split-Path -Parent $manifestPath) -ceq $expectedDirectory -and
        (Test-Path -LiteralPath $payloadPath -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payloadPath).Length -eq [long]$Receipt.byte_length -and
        (Get-Bw34yClosureRawSha256 $payloadPath) -ceq $rawDigest
    ) "$gateId $Label CAS payload is missing or changed"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable -Depth 32
    Assert-Bw34yClosure (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.algorithm -ceq "sha256" -and
        [string]$manifest.sha256 -ceq $digest -and
        [long]$manifest.byte_length -eq [long]$Receipt.byte_length -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "$gateId $Label CAS manifest changed"
}

function Assert-Bw34yCasDigest {
    param(
        [Parameter(Mandatory)][string]$RawSha256,
        [Parameter(Mandatory)][long]$ByteLength,
        [Parameter(Mandatory)][string]$Label
    )
    $directory = [IO.Path]::GetFullPath(
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\artifacts\sha256\$RawSha256"
    )
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-Bw34yClosure (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        (Get-Bw34yClosureRawSha256 $payload) -ceq $RawSha256
    ) "$gateId $Label CAS payload is missing or changed"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable -Depth 32
    Assert-Bw34yClosure (
        [string]$manifest.sha256 -ceq "sha256:$RawSha256" -and
        [long]$manifest.byte_length -eq $ByteLength -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "$gateId $Label CAS manifest changed"
}

Assert-Bw34yClosure (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-Bw34yClosureRawSha256 $closurePath) -ceq $expectedClosureSha256
) "$gateId closure is missing or changed"

& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-Bw34yClosure ($LASTEXITCODE -eq 0) "$gateId source commit is unavailable"
Assert-Bw34yClosure (
    (& git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim() -ceq $sourceTree
) "$gateId source tree changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 128
$disposition = [Collections.IDictionary]$closure.disposition
$evidence = [Collections.IDictionary]$closure.retained_evidence
$selection = [Collections.IDictionary]$closure.selection
$evidenceRoot = [IO.Path]::GetFullPath([string]$evidence.root)

Assert-Bw34yClosure (
    [string]$closure.schema_version -ceq
        "sporespore_balanced_wave_bw34y_rough_yaw_rescue_closure_v1" -and
    [string]$closure.status -ceq
        "closed_complete_valid_development_no_selection" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.experiment_source_commit -ceq $sourceCommit -and
    [string]$closure.experiment_source_tree -ceq $sourceTree -and
    [bool]$closure.source_was_clean_and_equal_to_origin_and_live_github_main -and
    [string]$closure.attempt_id -ceq $attemptId
) "$gateId closure identity changed"
Assert-Bw34yClosure (
    [bool]$disposition.complete_declared_physical_matrix_attempted -and
    [int]$disposition.expected_world_count -eq 3 -and
    [int]$disposition.attempted_world_count -eq 3 -and
    [int]$disposition.parsed_receipt_count -eq 3 -and
    [int]$disposition.unique_receipt_count -eq 3 -and
    [int]$disposition.invalid_cell_count -eq 0 -and
    [int]$disposition.process_exit_zero_count -eq 3 -and
    [int]$disposition.process_timeout_count -eq 0 -and
    [int]$disposition.process_tree_kill_count -eq 0 -and
    [bool]$disposition.frozen_evaluator_completed -and
    [bool]$disposition.frozen_evaluator_valid -and
    [bool]$disposition.development_result_valid -and
    [string]$disposition.classification -ceq
        "complete_valid_negative_development_selection_none" -and
    [bool]$disposition.valid_none_selection -and
    -not [bool]$disposition.development_candidate_selected -and
    [string]$disposition.selected_candidate_id -ceq "NONE" -and
    [int]$disposition.valid_walking_positive_count -eq 1 -and
    [int]$disposition.valid_walking_negative_count -eq 2 -and
    -not [bool]$disposition.fresh_validation_ready -and
    -not [bool]$disposition.rough_terrain_acceptance -and
    -not [bool]$disposition.release_authorized -and
    -not [bool]$disposition.physical_acceptance_authority
) "$gateId closure disposition changed"

Assert-Bw34yClosure (Test-Path -LiteralPath $evidenceRoot -PathType Container) (
    "$gateId retained evidence root is missing"
)
foreach ($artifactName in @(
    "attempt", "evaluation_input", "evaluation", "report", "completion"
)) {
    Assert-Bw34yHashedArtifact $evidenceRoot $evidence[$artifactName] $artifactName
}
$tree = Get-Bw34yEvidenceTreeDigest $evidenceRoot
Assert-Bw34yClosure (
    [string]$evidence.tree.algorithm -ceq
        "sha256_utf8_sorted_relative_path_tab_bytes_tab_raw_sha256_lf_v1" -and
    [int]$tree.file_count -eq 17 -and
    [int]$tree.file_count -eq [int]$evidence.tree.file_count -and
    [long]$tree.total_byte_length -eq 237272 -and
    [long]$tree.total_byte_length -eq [long]$evidence.tree.total_byte_length -and
    [string]$tree.tree_sha256 -ceq
        "b0e3f2fd70f81720c20412d9229a73b4becb6c4914d849fdd5fb072140e42327" -and
    [string]$tree.tree_sha256 -ceq [string]$evidence.tree.tree_sha256 -and
    @(Get-ChildItem -LiteralPath $evidenceRoot -Directory).Count -eq 3 -and
    @(Get-ChildItem -LiteralPath $evidenceRoot -Filter "raw-receipt.json" -File -Recurse).Count -eq 3 -and
    @(Get-ChildItem -LiteralPath $evidenceRoot -Filter "engine.log" -File -Recurse).Count -eq 3 -and
    @(Get-ChildItem -LiteralPath $evidenceRoot -Filter "transcript.log" -File -Recurse).Count -eq 3 -and
    @(Get-ChildItem -LiteralPath $evidenceRoot -Filter "stderr.log" -File -Recurse).Count -eq 3
) "$gateId retained evidence tree changed"

$attempt = Get-Content -Raw -LiteralPath (Join-Path $evidenceRoot "attempt.json") |
    ConvertFrom-Json -AsHashtable -Depth 128
$evaluationInput = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "evaluation-input.json"
) | ConvertFrom-Json -AsHashtable -Depth 128
$evaluation = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "evaluation.json"
) | ConvertFrom-Json -AsHashtable -Depth 128
$report = Get-Content -Raw -LiteralPath (Join-Path $evidenceRoot "report.json") |
    ConvertFrom-Json -AsHashtable -Depth 128
$completion = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "completion.json"
) | ConvertFrom-Json -AsHashtable -Depth 128

Assert-Bw34yClosure (
    [string]$attempt.schema_version -ceq
        "sporespore_balanced_wave_bw34y_rough_yaw_rescue_attempt_v1" -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    -not [bool]$attempt.synthetic_contract_preflight -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.origin_main_commit -ceq $sourceCommit -and
    [string]$attempt.remote_main_commit -ceq $sourceCommit -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [string]$attempt.attempt_id -ceq $attemptId -and
    [bool]$attempt.complete_zero_world_gate_passed -and
    [bool]$attempt.stage_one_freeze_verified -and
    [bool]$attempt.physical_identity_consumed -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    -not [bool]$attempt.locomotion_outcome_exposed_at_attempt -and
    [bool]$attempt.retained_physical_execution_serialized -and
    [int]$attempt.expected_world_count -eq 3 -and
    (Test-Bw34yClosureSequenceEqual @($attempt.ordered_cell_ids) @(
        "rough_s21001_bw34y_a",
        "rough_s21002_bw34y_a",
        "rough_s21003_bw34y_a"
    )) -and
    (Test-Bw34yClosureSequenceEqual @($attempt.primary_world_attempt_ids) @(
        "BW34Y-P1::rough_s21001_bw34y_a",
        "BW34Y-P1::rough_s21002_bw34y_a",
        "BW34Y-P1::rough_s21003_bw34y_a"
    )) -and
    -not [bool]$attempt.physical_acceptance_authority
) "$gateId retained attempt changed"
Assert-Bw34yClosure (
    [bool]$report.attempt_immutable -and
    [string]$report.attempt_raw_sha256 -ceq [string]$evidence.attempt.raw_sha256 -and
    [string]$attempt.full_godot_v2_attestation_sha256 -ceq
        [string]$closure.full_godot_v2_attestation.raw_sha256 -and
    [string]$attempt.content_addressed_inputs.stage_one_freeze.sha256 -ceq
        "sha256:$([string]$closure.frozen_source.stage_one_freeze_raw_sha256)"
) "$gateId attempt immutability or freeze binding changed"

$casInputs = [Collections.IDictionary]$attempt.content_addressed_inputs
Assert-Bw34yClosure (
    $casInputs.Count -eq 28 -and
    ([Collections.IDictionary]$attempt.source_bindings).Count -eq 23 -and
    [int]$closure.evidence_integrity.input_content_addressed_receipt_count -eq 28 -and
    [int]$closure.evidence_integrity.source_content_addressed_receipt_count -eq 23
) "$gateId retained input CAS inventory changed"
foreach ($entry in $casInputs.GetEnumerator()) {
    Assert-Bw34yCasReceipt $entry.Value "input $($entry.Key)"
}
$sourceCasNames = [ordered]@{
    candidate_declarations = "source_candidate_declarations"
    preregistration = "source_preregistration"
    manifest = "source_manifest"
    native_candidate_bindings = "source_native_candidate_bindings"
    authority_horizon = "source_authority_horizon"
    rough_challenge_manifest = "source_rough_challenge_manifest"
    retained_bw33n_closure = "source_retained_bw33n_closure"
    declaration_audit = "source_declaration_audit"
    freeze_audit = "source_freeze_audit"
    common_worker = "source_common_worker"
    native_worker = "source_native_worker"
    cold_evaluator = "source_cold_evaluator"
    one_shot_supervisor = "source_one_shot_supervisor"
    complete_zero_world_gate = "source_complete_zero_world_gate"
    fixed_horizon_physics_runner = "source_fixed_horizon_physics_runner"
    bw32n_successor_parent_worker = "source_bw32n_successor_parent_worker"
    bw20f_material_parent_worker = "source_bw20f_material_parent_worker"
    bw19v_authority_parent_worker = "source_bw19v_authority_parent_worker"
    godot_jolt_adapter_source = "source_godot_jolt_adapter_source"
    content_addressed_artifact_store = "source_content_addressed_artifact_store"
    operation_lock = "source_operation_lock"
    full_godot_attestation_verifier = "source_full_godot_attestation_verifier"
    conformance_runner = "source_conformance_runner"
}
Assert-Bw34yClosure ($sourceCasNames.Count -eq 23) (
    "$gateId source CAS map changed"
)
foreach ($entry in $sourceCasNames.GetEnumerator()) {
    $binding = $attempt.source_bindings[$entry.Key]
    $receipt = $casInputs[$entry.Value]
    $historicalOid = (& git -C $repoRoot rev-parse (
        "$sourceCommit`:$([string]$binding.path)"
    )).Trim()
    Assert-Bw34yClosure (
        $LASTEXITCODE -eq 0 -and
        $historicalOid -cmatch '^[0-9a-f]{40}$' -and
        [string]$receipt.sha256 -ceq "sha256:$([string]$binding.raw_sha256)"
    ) "$gateId historical source or CAS binding changed: $($entry.Key)"
    & git -C $repoRoot cat-file -e "$historicalOid`^{blob}"
    Assert-Bw34yClosure ($LASTEXITCODE -eq 0) (
        "$gateId historical source blob is unavailable: $($entry.Key)"
    )
}

Assert-Bw34yClosure (
    [string]$evaluation.schema_version -ceq
        "sporespore_balanced_wave_bw34y_rough_yaw_rescue_evaluation_v1" -and
    [bool]$evaluation.ok -and
    [string]$evaluation.attempt_id -ceq $attemptId -and
    [string]$evaluation.source.commit -ceq $sourceCommit -and
    [bool]$evaluation.source.worktree_clean -and
    [bool]$evaluation.source.matches_live_github_main -and
    [int]$evaluation.expected_world_count -eq 3 -and
    [int]$evaluation.observed_receipt_count -eq 3 -and
    [int]$evaluation.unique_receipt_count -eq 3 -and
    @($evaluation.duplicate_cell_ids).Count -eq 0 -and
    [int]$evaluation.invalid_cell_count -eq 0 -and
    [int]$evaluation.valid_walking_negative_count -eq 2 -and
    [string]$evaluation.selected_candidate_id -ceq "NONE" -and
    [bool]$evaluation.selection_valid -and
    -not [bool]$evaluation.walking_claim_authorized -and
    -not [bool]$evaluation.nuisance_acceptance_claim_authorized -and
    -not [bool]$evaluation.rough_terrain_acceptance -and
    -not [bool]$evaluation.independent_validation_authority -and
    -not [bool]$evaluation.release_authorized -and
    -not [bool]$evaluation.physical_acceptance_authority
) "$gateId frozen evaluation changed"
$expectedCellResults = [ordered]@{
    rough_s21001_bw34y_a = @{ seed = 21001; walking = $false; failed = 11; negative = $true }
    rough_s21002_bw34y_a = @{ seed = 21002; walking = $false; failed = 1; negative = $true }
    rough_s21003_bw34y_a = @{ seed = 21003; walking = $true; failed = 0; negative = $false }
}
foreach ($cell in @($evaluation.cell_results)) {
    $expected = $expectedCellResults[[string]$cell.cell_id]
    Assert-Bw34yClosure (
        $null -ne $expected -and
        [string]$cell.candidate_id -ceq "BW34Y-A" -and
        [int]$cell.campaign_seed -eq [int]$expected.seed -and
        [bool]$cell.passed -and
        [bool]$cell.identity_exact -and
        [bool]$cell.runtime_integrity_exact -and
        [bool]$cell.walking_observed -eq [bool]$expected.walking -and
        [int]$cell.failed_walking_gate_count -eq [int]$expected.failed -and
        [bool]$cell.valid_walking_negative -eq [bool]$expected.negative
    ) "$gateId cell evaluation changed: $($cell.cell_id)"
}
$candidate = $evaluation.candidate_summaries["BW34Y-A"]
Assert-Bw34yClosure (
    [int]$candidate.expected_cell_count -eq 3 -and
    [int]$candidate.integrity_pass_count -eq 3 -and
    [int]$candidate.walking_pass_count -eq 1 -and
    [int]$candidate.failed_walking_gate_count -eq 12 -and
    (Test-Bw34yClosureSequenceEqual @($candidate.walking_passing_seed_ids) @(21003)) -and
    -not [bool]$candidate.retained_comparator_passing_seed_21001_preserved -and
    -not [bool]$candidate.eligible_for_selection
) "$gateId candidate summary changed"

$expectedFailures = [Collections.IDictionary]$closure.walking_failure_receipts
$observedFailures = [ordered]@{}
foreach ($receipt in @($evaluationInput.cell_receipts)) {
    Assert-Bw34yClosure (
        [string]$receipt.candidate_id -ceq "BW34Y-A" -and
        [string]$receipt.controller_policy_id -ceq
            "sporespore_balanced_wave_bw34y_a_v1" -and
        [double]$receipt.yaw_error_stride_gain_per_rad -eq 0.7 -and
        [double]$receipt.global_requested_correction_scale -eq 0.5 -and
        [int]$receipt.policy_branch_surface_count -eq 0 -and
        [int]$receipt.candidate_authority_observation_count -eq 3232 -and
        [int]$receipt.candidate_specific_horizon_extension_count -eq 0 -and
        [int]$receipt.world_build_count -eq 1 -and
        [int]$receipt.world_reset_count -eq 0 -and
        [bool]$receipt.dynamic_parent_summary_gate_passed -and
        [bool]$receipt.common_execution_integrity -and
        [bool]$receipt.role_gate_passed -and
        [bool]$receipt.challenge_gate_passed -and
        [bool]$receipt.measurement_gate_passed -and
        [bool]$receipt.application_gate_passed -and
        [bool]$receipt.outcome_complete -and
        -not [bool]$receipt.walking_claim_authorized -and
        -not [bool]$receipt.nuisance_acceptance_claim_authorized -and
        -not [bool]$receipt.rough_terrain_acceptance -and
        -not [bool]$receipt.release_authorized -and
        -not [bool]$receipt.physical_acceptance_authority
    ) "$gateId receipt integrity or claim boundary changed: $($receipt.cell_id)"
    if (-not [bool]$receipt.walking_observed) {
        $observedFailures[[string]$receipt.cell_id] = @(
            $receipt.walking_gate_receipts.GetEnumerator() |
                Where-Object { -not [bool]$_.Value } |
                ForEach-Object { [string]$_.Key } |
                Sort-Object
        )
    }
}
Assert-Bw34yClosure (
    @($evaluationInput.cell_receipts).Count -eq 3 -and
    $observedFailures.Count -eq 2 -and
    (Test-Bw34yClosureSequenceEqual @($observedFailures.Keys) @($expectedFailures.Keys))
) "$gateId walking-failure cell set changed"
foreach ($cellId in $expectedFailures.Keys) {
    Assert-Bw34yClosure (
        Test-Bw34yClosureSequenceEqual `
            @($observedFailures[$cellId]) `
            @($expectedFailures[$cellId])
    ) "$gateId walking-failure receipts changed: $cellId"
}

$cellAttempts = @($report.cell_attempts)
Assert-Bw34yClosure (
    $cellAttempts.Count -eq 3 -and
    @($cellAttempts | Where-Object { [int]$_.process_exit_code -eq 0 }).Count -eq 3 -and
    @($cellAttempts | Where-Object { [bool]$_.timed_out }).Count -eq 0 -and
    @($cellAttempts | Where-Object { [bool]$_.killed_process_tree }).Count -eq 0 -and
    @($cellAttempts | Where-Object { [bool]$_.receipt_parsed }).Count -eq 3 -and
    @($cellAttempts | Where-Object {
        [double]$_.duration_seconds -le 0 -or [double]$_.duration_seconds -gt 360
    }).Count -eq 0 -and
    [string]$report.selected_candidate_id -ceq "NONE" -and
    -not [bool]$report.full_nuisance_development_successor_may_be_declared -and
    -not [bool]$report.fresh_validation_authority -and
    -not [bool]$report.rough_terrain_acceptance -and
    -not [bool]$report.release_authorized -and
    -not [bool]$report.physical_acceptance_authority
) "$gateId retained report changed"
$artifactFields = [ordered]@{
    receipt_content_addressed = "raw-receipt.json"
    transcript_content_addressed = "transcript.log"
    stderr_content_addressed = "stderr.log"
    engine_log_content_addressed = "engine.log"
}
foreach ($cell in $cellAttempts) {
    $directory = Get-ChildItem -LiteralPath $evidenceRoot -Directory |
        Where-Object { $_.Name -like "cell-*-$([string]$cell.cell_id)" } |
        Select-Object -First 1
    Assert-Bw34yClosure ($null -ne $directory) (
        "$gateId retained cell directory is missing: $($cell.cell_id)"
    )
    foreach ($artifact in $artifactFields.GetEnumerator()) {
        $casReceipt = $cell[$artifact.Key]
        Assert-Bw34yCasReceipt $casReceipt "$($cell.cell_id) $($artifact.Key)"
        $localPath = Join-Path $directory.FullName $artifact.Value
        Assert-Bw34yClosure (
            (Test-Path -LiteralPath $localPath -PathType Leaf) -and
            (Get-Bw34yClosureRawSha256 $localPath) -ceq
                ([string]$casReceipt.sha256).Substring("sha256:".Length)
        ) "$gateId retained cell artifact changed: $($cell.cell_id) $($artifact.Value)"
    }
}
Assert-Bw34yCasReceipt $report.evaluation_input_content_addressed "evaluation input"
Assert-Bw34yCasReceipt $report.evaluation_content_addressed "evaluation"
Assert-Bw34yCasReceipt $completion.report_content_addressed "report"
Assert-Bw34yClosure (
    [string]$report.evaluation_input_content_addressed.sha256 -ceq
        "sha256:$([string]$evidence.evaluation_input.raw_sha256)" -and
    [string]$report.evaluation_content_addressed.sha256 -ceq
        "sha256:$([string]$evidence.evaluation.raw_sha256)" -and
    [string]$completion.report_content_addressed.sha256 -ceq
        "sha256:$([string]$evidence.report.raw_sha256)"
) "$gateId aggregate CAS chain changed"
Assert-Bw34yCasDigest `
    -RawSha256 ([string]$evidence.completion.raw_sha256) `
    -ByteLength ([long]$evidence.completion.byte_length) `
    -Label "completion"
Assert-Bw34yClosure (
    [string]$completion.schema_version -ceq
        "sporespore_balanced_wave_bw34y_rough_yaw_rescue_completion_v1" -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [bool]$completion.valid_complete_result -and
    [string]$completion.selected_candidate_id -ceq "NONE" -and
    [int]$completion.expected_world_count -eq 3 -and
    [int]$completion.attempted_world_count -eq 3 -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.fresh_validation_authority -and
    -not [bool]$completion.rough_terrain_acceptance -and
    -not [bool]$completion.release_authorized -and
    -not [bool]$completion.physical_acceptance_authority
) "$gateId completion changed"

$attestationRecord = $closure.full_godot_v2_attestation
$attestationPath = [IO.Path]::GetFullPath([string]$attestationRecord.path)
Assert-Bw34yClosure (
    (Test-Path -LiteralPath $attestationPath -PathType Leaf) -and
    (Get-Item -LiteralPath $attestationPath).Length -eq [long]$attestationRecord.byte_length -and
    (Get-Bw34yClosureRawSha256 $attestationPath) -ceq
        [string]$attestationRecord.raw_sha256 -and
    [bool]$attestationRecord.production_verifier_ok_before_physical_attempt -and
    @($attestationRecord.production_verifier_failure_codes).Count -eq 0
) "$gateId full-Godot attestation changed"
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 128
Assert-Bw34yClosure (
    [string]$attestation.status -ceq "full_godot_conformance_passed" -and
    [bool]$attestation.conformance.passed -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [string]$attestation.source.origin_main -ceq $sourceCommit -and
    [string]$attestation.source.live_github_main -ceq $sourceCommit -and
    [bool]$attestation.source.worktree_clean -and
    [bool]$attestation.source.clean_pushed_live -and
    [double]$attestation.conformance.duration_seconds -eq 1680.2259587
) "$gateId attested source changed"
$lockSource = Get-Content -Raw -LiteralPath (
    [string]$casInputs.source_operation_lock.payload_path
)
$validatorSource = Get-Content -Raw -LiteralPath (
    [string]$casInputs.source_full_godot_attestation_verifier.payload_path
)
$lockSource = $lockSource -replace '^#requires[^\r\n]*\r?\n', ''
$validatorSource = $validatorSource -replace '^#requires[^\r\n]*\r?\n', ''
Invoke-Expression $lockSource
Invoke-Expression $validatorSource
$historicalVerification = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $attestation `
    -ExpectedSource $attestation.source `
    -ExpectedGodotIdentity $attestation.godot `
    -ExpectedPowerShellIdentity $attestation.powershell `
    -ExpectedSourceBindings @($attestation.source_bindings)
Assert-Bw34yClosure (
    [bool]$historicalVerification.ok -and
    @($historicalVerification.failure_codes).Count -eq 0 -and
    -not [bool]$historicalVerification.physical_acceptance_authority
) "$gateId retained historical attestation no longer verifies"
foreach ($claim in $attestation.claims.GetEnumerator()) {
    Assert-Bw34yClosure (-not [bool]$claim.Value) (
        "$gateId attestation claim inflated: $($claim.Key)"
    )
}

Assert-Bw34yClosure (
    [string]$selection.retained_comparator_candidate_id -ceq "BW33N-C" -and
    (Test-Bw34yClosureSequenceEqual @($selection.prospective_selector_order) @("BW34Y-A")) -and
    [int]$selection.required_walking_pass_count -eq 3 -and
    [int]$selection.required_integrity_pass_count -eq 3 -and
    [int]$selection.required_failed_walking_gate_count -eq 0 -and
    (Test-Bw34yClosureSequenceEqual @($selection.required_preserved_seed_ids) @(21001)) -and
    @($selection.eligible_candidate_ids).Count -eq 0 -and
    [string]$selection.selected_candidate_id -ceq "NONE" -and
    [bool]$selection.selection_valid -and
    -not [bool]$selection.full_nuisance_development_successor_may_be_declared -and
    -not [bool]$selection.fresh_validation_authority -and
    (Test-Bw34yClosureSequenceEqual `
        @($selection.reserved_fresh_independent_validation_seed_ids) `
        @(49101, 49102, 49103)) -and
    [bool]$selection.reserved_fresh_seeds_remain_unopened
) "$gateId selection or sealed-seed boundary changed"
Assert-Bw34yClosure (
    -not [bool]$closure.prospective_mechanism_result.seed_21001_retained_comparator_walking_preserved -and
    [bool]$closure.prospective_mechanism_result.seed_21001_failed_gate_count_changed_from_0_to_11 -and
    [bool]$closure.prospective_mechanism_result.seed_21002_failed_gate_count_changed_from_1_to_1 -and
    [string]$closure.prospective_mechanism_result.seed_21002_retained_comparator_failure_gate -ceq
        "bounded_lateral_drift" -and
    [string]$closure.prospective_mechanism_result.seed_21002_bw34y_failure_gate -ceq
        "contact_gating_completed_without_timeout" -and
    -not [bool]$closure.prospective_mechanism_result.seed_21002_walking_rescue_observed -and
    [bool]$closure.prospective_mechanism_result.seed_21003_failed_gate_count_changed_from_1_to_0 -and
    [bool]$closure.prospective_mechanism_result.seed_21003_lateral_drift_rescue_observed -and
    [bool]$closure.prospective_mechanism_result.seed_21003_walking_rescue_observed -and
    -not [bool]$closure.prospective_mechanism_result.all_seed_rescue_observed -and
    -not [bool]$closure.prospective_mechanism_result.required_preservation_observed -and
    -not [bool]$closure.prospective_mechanism_result.monotonic_lower_yaw_rescue_observed
) "$gateId prospective mechanism result changed"

Assert-Bw34yClosure (
    [bool]$closure.claim_boundary.exact_finite_development_result_complete -and
    @($closure.claim_boundary.GetEnumerator() | Where-Object {
        [string]$_.Key -cne "exact_finite_development_result_complete" -and
        [bool]$_.Value
    }).Count -eq 0 -and
    [bool]$closure.immutability.first_complete_result_is_final_for_source_identity -and
    [bool]$closure.immutability.same_identity_rerun_forbidden -and
    [bool]$closure.immutability.posthoc_selection_change_forbidden -and
    [bool]$closure.next_work_authority.same_bw34y_identity_may_not_be_rerun_repaired_or_rethresholded -and
    [bool]$closure.next_work_authority.negative_and_none_result_may_inform_distinct_successor_design -and
    [bool]$closure.next_work_authority.distinct_successor_requires_new_hypothesis_campaign_gate_source_preregistration_and_evidence_root -and
    -not [bool]$closure.next_work_authority.full_nuisance_development_declaration_authorized -and
    -not [bool]$closure.next_work_authority.independent_validation_declaration_authorized -and
    -not [bool]$closure.next_work_authority.fresh_validation_seed_use_authorized -and
    [bool]$closure.next_work_authority.product_and_adaptation_roadmap_work_remains_separate_and_open
) "$gateId claim, immutability, or next-work boundary changed"

$campaignAttemptFiles = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $evidenceRoot) `
        -Filter "attempt.json" -File -Recurse |
        Where-Object {
            try {
                $candidateAttempt = Get-Content -Raw -LiteralPath $_.FullName |
                    ConvertFrom-Json
                [string]$candidateAttempt.campaign_id -ceq $campaignId
            } catch { $false }
        }
)
Assert-Bw34yClosure (
    $campaignAttemptFiles.Count -eq 1 -and
    [IO.Path]::GetFullPath($campaignAttemptFiles[0].FullName) -ceq
        (Join-Path $evidenceRoot "attempt.json")
) "$gateId retained physical-attempt cardinality changed"

# Current runtime safety only. Historical identity above comes from retained
# CAS payloads and source-commit Git blobs.
$rerunOutput = (& pwsh -NoLogo -NoProfile -File $runnerPath -RunPhysical 2>&1 |
    Out-String)
Assert-Bw34yClosure (
    $LASTEXITCODE -ne 0 -and
    $rerunOutput.Contains(
        "$gateId campaign is closed and may not rerun",
        [StringComparison]::Ordinal
    )
) "$gateId current closed-state rerun interlock changed"

Write-Host (
    "BW34Y_ROUGH_YAW_RESCUE_CLOSURE_PASS status=valid-none worlds=3 " +
    "receipts=3 integrity=3/3 walking=1/3 walking_negatives=2 " +
    "failed_gates=11,1,0 passing_seed=21003 preserved_seed_21001=False " +
    "selected=NONE fresh_seeds_opened=0 rough_acceptance=False " +
    "release=False physical_authority=False rerun_refused=True"
)

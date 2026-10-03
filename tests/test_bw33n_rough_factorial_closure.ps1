#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot `
    "balanced_wave_bw33n_rough_factorial_closure.json"
$runnerPath = Join-Path $sdkRoot `
    "run_balanced_wave_bw33n_rough_factorial.ps1"
$expectedClosureSha256 = `
    "e0853f5136524cd76541a404fd09d10c5c9c5163dc34f4af9073562ca5126279"
$campaignId = "BW33N-BW32N-ROUGH-FACTORIAL-DEVELOPMENT"
$gateId = "BW33N"
$sourceCommit = "db0da434c3cd9dde9a6e5c93f6f38578cb096ba7"
$sourceTree = "964165cefcf709691beabc367ab8aebae5989be6"
$attemptId = "5ae639a9631f4f7191c9bbbfe5f58154"

function Assert-Bw33nClosure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Bw33nClosureRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-Bw33nClosureSequenceEqual {
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

function Assert-Bw33nHashedArtifact {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)]$Artifact,
        [Parameter(Mandatory)][string]$Label
    )
    $path = Join-Path $Root ([string]$Artifact.path)
    Assert-Bw33nClosure (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$Artifact.byte_length -and
        (Get-Bw33nClosureRawSha256 $path) -ceq [string]$Artifact.raw_sha256
    ) "$gateId retained $Label is missing or changed"
}

function Get-Bw33nEvidenceTreeDigest {
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
                    (Get-Bw33nClosureRawSha256 $_.FullName)
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

function Assert-Bw33nCasReceipt {
    param(
        [Parameter(Mandatory)]$Receipt,
        [Parameter(Mandatory)][string]$Label
    )
    $digest = [string]$Receipt.sha256
    Assert-Bw33nClosure (
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
    Assert-Bw33nClosure (
        (Split-Path -Parent $payloadPath) -ceq $expectedDirectory -and
        (Split-Path -Parent $manifestPath) -ceq $expectedDirectory -and
        (Test-Path -LiteralPath $payloadPath -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payloadPath).Length -eq [long]$Receipt.byte_length -and
        (Get-Bw33nClosureRawSha256 $payloadPath) -ceq $rawDigest
    ) "$gateId $Label CAS payload is missing or changed"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable -Depth 32
    Assert-Bw33nClosure (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.algorithm -ceq "sha256" -and
        [string]$manifest.sha256 -ceq $digest -and
        [long]$manifest.byte_length -eq [long]$Receipt.byte_length -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "$gateId $Label CAS manifest changed"
}

Assert-Bw33nClosure (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-Bw33nClosureRawSha256 $closurePath) -ceq $expectedClosureSha256
) "$gateId closure is missing or changed"

& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-Bw33nClosure ($LASTEXITCODE -eq 0) "$gateId source commit is unavailable"
Assert-Bw33nClosure (
    (& git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim() -ceq $sourceTree
) "$gateId source tree changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 128
$disposition = [Collections.IDictionary]$closure.disposition
$evidence = [Collections.IDictionary]$closure.retained_evidence
$selection = [Collections.IDictionary]$closure.selection

Assert-Bw33nClosure (
    [string]$closure.schema_version -ceq
        "sporespore_balanced_wave_bw33n_rough_factorial_closure_v1" -and
    [string]$closure.status -ceq
        "closed_complete_valid_development_no_selection" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.experiment_source_commit -ceq $sourceCommit -and
    [string]$closure.experiment_source_tree -ceq $sourceTree -and
    [bool]$closure.source_was_clean_and_equal_to_origin_and_live_github_main -and
    [string]$closure.attempt_id -ceq $attemptId
) "$gateId closure identity changed"
Assert-Bw33nClosure (
    [bool]$disposition.complete_declared_physical_matrix_attempted -and
    [int]$disposition.expected_world_count -eq 12 -and
    [int]$disposition.attempted_world_count -eq 12 -and
    [int]$disposition.parsed_receipt_count -eq 12 -and
    [int]$disposition.unique_receipt_count -eq 12 -and
    [int]$disposition.invalid_cell_count -eq 0 -and
    [int]$disposition.process_exit_zero_count -eq 12 -and
    [int]$disposition.process_timeout_count -eq 0 -and
    [int]$disposition.process_tree_kill_count -eq 0 -and
    [bool]$disposition.frozen_evaluator_valid -and
    [bool]$disposition.development_result_valid -and
    [bool]$disposition.valid_none_selection -and
    -not [bool]$disposition.development_candidate_selected -and
    [string]$disposition.selected_candidate_id -ceq "NONE" -and
    [int]$disposition.valid_walking_positive_count -eq 3 -and
    [int]$disposition.valid_walking_negative_count -eq 9 -and
    -not [bool]$disposition.fresh_validation_ready -and
    -not [bool]$disposition.rough_terrain_acceptance -and
    -not [bool]$disposition.release_authorized -and
    -not [bool]$disposition.physical_acceptance_authority
) "$gateId disposition changed"

$evidenceRoot = [IO.Path]::GetFullPath([string]$evidence.root)
foreach ($record in @(
    @{ value = $evidence.attempt; label = "attempt" },
    @{ value = $evidence.evaluation_input; label = "evaluation input" },
    @{ value = $evidence.evaluation; label = "evaluation" },
    @{ value = $evidence.report; label = "report" },
    @{ value = $evidence.completion; label = "completion" }
)) {
    Assert-Bw33nHashedArtifact `
        -Root $evidenceRoot `
        -Artifact $record.value `
        -Label $record.label
}
$tree = Get-Bw33nEvidenceTreeDigest $evidenceRoot
Assert-Bw33nClosure (
    [int]$evidence.cell_directories -eq 12 -and
    [int]$evidence.raw_receipts -eq 12 -and
    [int]$evidence.engine_logs -eq 12 -and
    [int]$evidence.transcripts -eq 12 -and
    [int]$evidence.stderr_logs -eq 12 -and
    [int]$tree.file_count -eq [int]$evidence.tree.file_count -and
    [long]$tree.total_byte_length -eq [long]$evidence.tree.total_byte_length -and
    [string]$tree.tree_sha256 -ceq [string]$evidence.tree.tree_sha256
) "$gateId retained evidence tree changed"

$attempt = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot ([string]$evidence.attempt.path)
) | ConvertFrom-Json -AsHashtable -Depth 128
$evaluationInput = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot ([string]$evidence.evaluation_input.path)
) | ConvertFrom-Json -AsHashtable -Depth 128
$evaluation = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot ([string]$evidence.evaluation.path)
) | ConvertFrom-Json -AsHashtable -Depth 128
$report = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot ([string]$evidence.report.path)
) | ConvertFrom-Json -AsHashtable -Depth 128
$completion = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot ([string]$evidence.completion.path)
) | ConvertFrom-Json -AsHashtable -Depth 128

$expectedCells = [Collections.Generic.List[string]]::new()
foreach ($seed in @(21001, 21002, 21003)) {
    foreach ($suffix in @("a", "b", "c", "d")) {
        $expectedCells.Add("rough_s${seed}_bw33n_${suffix}")
    }
}
Assert-Bw33nClosure (
    [string]$attempt.schema_version -ceq
        "sporespore_balanced_wave_bw33n_rough_factorial_attempt_v1" -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
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
    [int]$attempt.expected_world_count -eq 12 -and
    (Test-Bw33nClosureSequenceEqual @($attempt.ordered_cell_ids) @($expectedCells)) -and
    -not [bool]$attempt.physical_acceptance_authority
) "$gateId retained attempt changed"
Assert-Bw33nClosure (
    -not ((@($attempt.ordered_cell_ids) -join "|") -match "49101|49102|49103") -and
    [string]$attempt.full_godot_v2_attestation_sha256 -ceq
        [string]$closure.full_godot_v2_attestation.raw_sha256
) "$gateId fresh-seed or attestation boundary changed"

$casInputs = [Collections.IDictionary]$attempt.content_addressed_inputs
Assert-Bw33nClosure (
    $casInputs.Count -eq 27 -and
    [int]$closure.evidence_integrity.input_content_addressed_receipt_count -eq 27 -and
    [int]$closure.evidence_integrity.source_content_addressed_receipt_count -eq 22
) "$gateId input CAS inventory changed"
foreach ($entry in $casInputs.GetEnumerator()) {
    Assert-Bw33nCasReceipt $entry.Value "input $($entry.Key)"
}
Assert-Bw33nClosure (
    [string]$casInputs.stage_one_freeze.sha256 -ceq
        "sha256:$([string]$closure.frozen_source.stage_one_freeze_raw_sha256)" -and
    [string]$casInputs.full_godot_v2_attestation.sha256 -ceq
        "sha256:$([string]$closure.full_godot_v2_attestation.raw_sha256)"
) "$gateId frozen source or attestation CAS binding changed"

$sourceCasNames = [ordered]@{
    candidate_declarations = "source_candidate_declarations"
    preregistration = "source_preregistration"
    manifest = "source_manifest"
    native_candidate_bindings = "source_native_candidate_bindings"
    authority_horizon = "source_authority_horizon"
    rough_challenge_manifest = "source_rough_challenge_manifest"
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
Assert-Bw33nClosure (
    ([Collections.IDictionary]$attempt.source_bindings).Count -eq 22 -and
    $sourceCasNames.Count -eq 22
) "$gateId source-binding inventory changed"
foreach ($entry in $sourceCasNames.GetEnumerator()) {
    $binding = $attempt.source_bindings[$entry.Key]
    $receipt = $casInputs[$entry.Value]
    $historicalOid = (& git -C $repoRoot rev-parse (
        "$sourceCommit`:$([string]$binding.path)"
    )).Trim()
    Assert-Bw33nClosure (
        $LASTEXITCODE -eq 0 -and
        $historicalOid -cmatch '^[0-9a-f]{40}$' -and
        [string]$receipt.sha256 -ceq "sha256:$([string]$binding.raw_sha256)"
    ) "$gateId historical source or CAS binding changed: $($entry.Key)"
    & git -C $repoRoot cat-file -e "$historicalOid`^{blob}"
    Assert-Bw33nClosure ($LASTEXITCODE -eq 0) (
        "$gateId historical source blob is unavailable: $($entry.Key)"
    )
}

Assert-Bw33nClosure (
    [string]$evaluation.schema_version -ceq
        "sporespore_balanced_wave_bw33n_rough_factorial_evaluation_v1" -and
    [bool]$evaluation.ok -and
    [int]$evaluation.expected_world_count -eq 12 -and
    [int]$evaluation.observed_receipt_count -eq 12 -and
    [int]$evaluation.unique_receipt_count -eq 12 -and
    @($evaluation.duplicate_cell_ids).Count -eq 0 -and
    [int]$evaluation.invalid_cell_count -eq 0 -and
    [int]$evaluation.valid_walking_negative_count -eq 9 -and
    [string]$evaluation.selected_candidate_id -ceq "NONE" -and
    [bool]$evaluation.selection_valid -and
    -not [bool]$evaluation.walking_claim_authorized -and
    -not [bool]$evaluation.rough_terrain_acceptance -and
    -not [bool]$evaluation.independent_validation_authority -and
    -not [bool]$evaluation.release_authorized -and
    -not [bool]$evaluation.physical_acceptance_authority
) "$gateId frozen evaluation changed"

$expectedCandidateResults = [ordered]@{
    "BW33N-A" = @{ walking = 1; failed = 10; seeds = @(21001) }
    "BW33N-B" = @{ walking = 1; failed = 12; seeds = @(21001) }
    "BW33N-C" = @{ walking = 1; failed = 2; seeds = @(21001) }
    "BW33N-D" = @{ walking = 0; failed = 20; seeds = @() }
}
foreach ($candidateId in $expectedCandidateResults.Keys) {
    $expected = $expectedCandidateResults[$candidateId]
    $summary = $evaluation.candidate_summaries[$candidateId]
    $closed = $closure.candidate_results[$candidateId]
    Assert-Bw33nClosure (
        [int]$summary.expected_cell_count -eq 3 -and
        [int]$summary.integrity_pass_count -eq 3 -and
        [int]$summary.walking_pass_count -eq [int]$expected.walking -and
        [double]$summary.failed_walking_gate_count -eq [double]$expected.failed -and
        (Test-Bw33nClosureSequenceEqual `
            @($summary.walking_passing_seed_ids) @($expected.seeds)) -and
        -not [bool]$summary.eligible_for_selection -and
        [int]$closed.walking_pass_count -eq [int]$expected.walking -and
        [int]$closed.failed_walking_gate_count -eq [int]$expected.failed -and
        -not [bool]$closed.eligible_for_selection
    ) "$gateId candidate result changed: $candidateId"
}

$expectedFailures = [Collections.IDictionary]$closure.walking_failure_receipts
$observedFailures = [ordered]@{}
foreach ($receipt in @($evaluationInput.cell_receipts)) {
    Assert-Bw33nClosure (
        [int]$receipt.candidate_authority_observation_count -eq 3232 -and
        [int]$receipt.candidate_specific_horizon_extension_count -eq 0 -and
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
Assert-Bw33nClosure (
    @($evaluationInput.cell_receipts).Count -eq 12 -and
    $observedFailures.Count -eq 9 -and
    (Test-Bw33nClosureSequenceEqual @($observedFailures.Keys) @($expectedFailures.Keys))
) "$gateId walking-failure cell set changed"
foreach ($cellId in $expectedFailures.Keys) {
    Assert-Bw33nClosure (
        Test-Bw33nClosureSequenceEqual `
            @($observedFailures[$cellId]) `
            @($expectedFailures[$cellId])
    ) "$gateId walking-failure receipts changed: $cellId"
}

$cellAttempts = @($report.cell_attempts)
Assert-Bw33nClosure (
    $cellAttempts.Count -eq 12 -and
    @($cellAttempts | Where-Object { [int]$_.process_exit_code -eq 0 }).Count -eq 12 -and
    @($cellAttempts | Where-Object { [bool]$_.timed_out }).Count -eq 0 -and
    @($cellAttempts | Where-Object { [bool]$_.killed_process_tree }).Count -eq 0 -and
    @($cellAttempts | Where-Object { [bool]$_.receipt_parsed }).Count -eq 12 -and
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
    Assert-Bw33nClosure ($null -ne $directory) (
        "$gateId retained cell directory is missing: $($cell.cell_id)"
    )
    foreach ($artifact in $artifactFields.GetEnumerator()) {
        $casReceipt = $cell[$artifact.Key]
        Assert-Bw33nCasReceipt $casReceipt "$($cell.cell_id) $($artifact.Key)"
        $localPath = Join-Path $directory.FullName $artifact.Value
        Assert-Bw33nClosure (
            (Test-Path -LiteralPath $localPath -PathType Leaf) -and
            (Get-Bw33nClosureRawSha256 $localPath) -ceq
                ([string]$casReceipt.sha256).Substring("sha256:".Length)
        ) "$gateId retained cell artifact changed: $($cell.cell_id) $($artifact.Value)"
    }
}
Assert-Bw33nCasReceipt $report.evaluation_input_content_addressed "evaluation input"
Assert-Bw33nCasReceipt $report.evaluation_content_addressed "evaluation"
Assert-Bw33nCasReceipt $completion.report_content_addressed "report"
Assert-Bw33nClosure (
    [string]$report.evaluation_input_content_addressed.sha256 -ceq
        "sha256:$([string]$evidence.evaluation_input.raw_sha256)" -and
    [string]$report.evaluation_content_addressed.sha256 -ceq
        "sha256:$([string]$evidence.evaluation.raw_sha256)" -and
    [string]$completion.report_content_addressed.sha256 -ceq
        "sha256:$([string]$evidence.report.raw_sha256)"
) "$gateId aggregate CAS chain changed"
Assert-Bw33nClosure (
    [string]$completion.schema_version -ceq
        "sporespore_balanced_wave_bw33n_rough_factorial_completion_v1" -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [bool]$completion.valid_complete_result -and
    [string]$completion.selected_candidate_id -ceq "NONE" -and
    [int]$completion.expected_world_count -eq 12 -and
    [int]$completion.attempted_world_count -eq 12 -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.fresh_validation_authority -and
    -not [bool]$completion.rough_terrain_acceptance -and
    -not [bool]$completion.release_authorized -and
    -not [bool]$completion.physical_acceptance_authority
) "$gateId completion changed"

$attestationRecord = $closure.full_godot_v2_attestation
$attestationPath = [IO.Path]::GetFullPath([string]$attestationRecord.path)
Assert-Bw33nClosure (
    (Test-Path -LiteralPath $attestationPath -PathType Leaf) -and
    (Get-Item -LiteralPath $attestationPath).Length -eq [long]$attestationRecord.byte_length -and
    (Get-Bw33nClosureRawSha256 $attestationPath) -ceq
        [string]$attestationRecord.raw_sha256 -and
    [bool]$attestationRecord.production_verifier_ok_before_physical_attempt -and
    @($attestationRecord.production_verifier_failure_codes).Count -eq 0
) "$gateId full-Godot attestation changed"
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 128
Assert-Bw33nClosure (
    [string]$attestation.status -ceq "full_godot_conformance_passed" -and
    [bool]$attestation.conformance.passed -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [string]$attestation.source.origin_main -ceq $sourceCommit -and
    [string]$attestation.source.live_github_main -ceq $sourceCommit -and
    [bool]$attestation.source.worktree_clean -and
    [bool]$attestation.source.clean_pushed_live -and
    [double]$attestation.conformance.duration_seconds -eq 1934.1678955
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
Assert-Bw33nClosure (
    [bool]$historicalVerification.ok -and
    @($historicalVerification.failure_codes).Count -eq 0 -and
    -not [bool]$historicalVerification.physical_acceptance_authority
) "$gateId retained historical attestation no longer verifies"
foreach ($claim in $attestation.claims.GetEnumerator()) {
    Assert-Bw33nClosure (-not [bool]$claim.Value) (
        "$gateId attestation claim inflated: $($claim.Key)"
    )
}

Assert-Bw33nClosure (
    [string]$selection.reference_candidate_id -ceq "BW33N-A" -and
    (Test-Bw33nClosureSequenceEqual `
        @($selection.prospective_parsimony_order) @("BW33N-B", "BW33N-C", "BW33N-D")) -and
    [int]$selection.required_walking_pass_count -eq 3 -and
    [int]$selection.required_integrity_pass_count -eq 3 -and
    [int]$selection.required_failed_walking_gate_count -eq 0 -and
    @($selection.eligible_candidate_ids).Count -eq 0 -and
    [string]$selection.selected_candidate_id -ceq "NONE" -and
    [bool]$selection.selection_valid -and
    -not [bool]$selection.full_nuisance_development_successor_may_be_declared -and
    -not [bool]$selection.fresh_validation_authority -and
    (Test-Bw33nClosureSequenceEqual `
        @($selection.reserved_fresh_independent_validation_seed_ids) `
        @(49101, 49102, 49103)) -and
    [bool]$selection.reserved_fresh_seeds_remain_unopened
) "$gateId selection or sealed-seed boundary changed"
Assert-Bw33nClosure (
    [bool]$closure.prospective_mechanism_result.reference_seed_21001_preserved_by_b_and_c -and
    -not [bool]$closure.prospective_mechanism_result.reference_seed_21001_preserved_by_d -and
    [bool]$closure.prospective_mechanism_result.scale_only_seed_21002_failure_count_changed_from_8_to_1 -and
    -not [bool]$closure.prospective_mechanism_result.scale_only_seed_21002_walking_rescue_observed -and
    [bool]$closure.prospective_mechanism_result.scale_only_seed_21003_failure_count_changed_from_2_to_11 -and
    [bool]$closure.prospective_mechanism_result.lower_yaw_seed_21002_failure_count_changed_from_8_to_1 -and
    [bool]$closure.prospective_mechanism_result.lower_yaw_seed_21003_failure_count_changed_from_2_to_1 -and
    [string]$closure.prospective_mechanism_result.lower_yaw_remaining_gate_on_both_failing_seeds -ceq
        "bounded_lateral_drift" -and
    -not [bool]$closure.prospective_mechanism_result.lower_yaw_walking_rescue_observed -and
    [int]$closure.prospective_mechanism_result.combined_arm_walking_pass_count -eq 0 -and
    -not [bool]$closure.prospective_mechanism_result.clean_double_dissociation_observed -and
    -not [bool]$closure.prospective_mechanism_result.interaction_worth_pursuing_pattern_observed -and
    [bool]$closure.prospective_mechanism_result.no_posthoc_interaction_story
) "$gateId prospective mechanism result changed"

Assert-Bw33nClosure (
    [bool]$closure.claim_boundary.exact_finite_development_result_complete -and
    @($closure.claim_boundary.GetEnumerator() | Where-Object {
        [string]$_.Key -cne "exact_finite_development_result_complete" -and
        [bool]$_.Value
    }).Count -eq 0 -and
    [bool]$closure.immutability.first_complete_result_is_final_for_source_identity -and
    [bool]$closure.immutability.same_identity_rerun_forbidden -and
    [bool]$closure.immutability.posthoc_selection_change_forbidden -and
    [bool]$closure.next_work_authority.same_bw33n_identity_may_not_be_rerun_repaired_or_rethresholded -and
    [bool]$closure.next_work_authority.negative_and_none_result_may_inform_distinct_successor_design -and
    [bool]$closure.next_work_authority.distinct_successor_requires_new_hypothesis_campaign_gate_source_preregistration_and_evidence_root -and
    -not [bool]$closure.next_work_authority.full_nuisance_development_declaration_authorized -and
    -not [bool]$closure.next_work_authority.independent_validation_declaration_authorized -and
    -not [bool]$closure.next_work_authority.fresh_validation_seed_use_authorized
) "$gateId claim, immutability, or next-work boundary changed"

$campaignAttemptFiles = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $evidenceRoot) `
        -Filter attempt.json -File -Recurse |
        Where-Object {
            try {
                $candidate = Get-Content -Raw -LiteralPath $_.FullName |
                    ConvertFrom-Json
                [string]$candidate.campaign_id -ceq $campaignId
            } catch { $false }
        }
)
Assert-Bw33nClosure (
    $campaignAttemptFiles.Count -eq 1 -and
    [IO.Path]::GetFullPath($campaignAttemptFiles[0].FullName) -ceq
        (Join-Path $evidenceRoot "attempt.json")
) "$gateId retained physical-attempt cardinality changed"

# This is a current runtime-safety check, not historical proof. Historical
# identity above comes only from retained CAS payloads and pinned Git blobs.
$rerunOutput = (& pwsh -NoLogo -NoProfile -File $runnerPath -RunPhysical 2>&1 |
    Out-String)
Assert-Bw33nClosure (
    $LASTEXITCODE -ne 0 -and
    $rerunOutput.Contains(
        "$gateId campaign is closed and may not rerun",
        [StringComparison]::Ordinal
    )
) "$gateId current closed-state rerun interlock changed"

Write-Host (
    "BW33N_ROUGH_FACTORIAL_CLOSURE_PASS status=valid-none worlds=12 " +
    "receipts=12 integrity=12/12 walking=3/12 walking_negatives=9 " +
    "candidate_a=1/3 candidate_b=1/3 candidate_c=1/3 candidate_d=0/3 " +
    "selected=NONE fresh_seeds_opened=0 rough_acceptance=False " +
    "release=False physical_authority=False rerun_refused=True"
)

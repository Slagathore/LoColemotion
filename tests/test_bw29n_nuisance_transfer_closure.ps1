#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$sdkRoot = Join-Path $repoRoot "sdk"
$campaignId = "BW29N-BW19V-NUISANCE-TRANSFER-DEVELOPMENT"
$gateId = "BW29N"
$sourceCommit = "61f4c1e8d275d3553443fbe48755c11dbf7ce9a5"
$sourceTree = "0dca9443b47fb411985d811efe769ddd7b698416"
$attemptId = "b65fd5a35f0a49e79a89986ea897fe6a"
$closurePath = Join-Path $sdkRoot (
    "balanced_wave_bw29n_nuisance_transfer_closure.json"
)
$expectedClosureSha256 = (
    "e36d38909ecde22283336d0458851cb18ee3e562053c95524ff2229b1fd4b61a"
)
$compilerPath = Join-Path $sdkRoot (
    "balanced_wave_bw29n_nuisance_transfer_posthoc_diagnostic.ps1"
)
$evaluatorPath = Join-Path $sdkRoot (
    "balanced_wave_bw29n_nuisance_transfer_gate.ps1"
)
$supervisorPath = Join-Path $sdkRoot (
    "run_balanced_wave_bw29n_nuisance_transfer.ps1"
)
$evidenceBase = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$rawPrefix = "BW29N_NUISANCE_TRANSFER_RAW_CELL "
$materialProfileDigest = (
    "sha256:e62b97398497f32243bae4fb6eaca258f90cbd233fc8c913c456b01a287bf993"
)
$expectedInvalidCounts = [ordered]@{
    sensor_noise_s21001_bw29n_b = 2778
    sensor_noise_s21002_bw29n_b = 2762
    sensor_noise_s21003_bw29n_b = 2748
}

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Bw29nClosureRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Assert-HashedArtifact {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)]$Artifact,
        [Parameter(Mandatory)][string]$Label
    )
    $path = Join-Path $Root ([string]$Artifact.path)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq
            [long]$Artifact.byte_length -and
        (Get-Bw29nClosureRawSha256 -Path $path) -ceq
            [string]$Artifact.raw_sha256
    ) "$gateId retained $Label is missing or changed"
}

function Get-EvidenceTreeDigest {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse)
    $rows = @(
        $files |
            ForEach-Object {
                $relative = [System.IO.Path]::GetRelativePath(
                    $Root,
                    $_.FullName
                ).Replace("\", "/")
                "{0}`t{1}`t{2}" -f (
                    $relative,
                    $_.Length,
                    (Get-Bw29nClosureRawSha256 -Path $_.FullName)
                )
            } |
            Sort-Object
    )
    $text = ($rows -join "`n") + "`n"
    return [ordered]@{
        file_count = $files.Count
        total_byte_length = [long](
            $files | Measure-Object -Property Length -Sum
        ).Sum
        tree_sha256 = [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData(
                [Text.Encoding]::UTF8.GetBytes($text)
            )
        ).ToLowerInvariant()
    }
}

function Test-SequenceEqual {
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

Assert-Exact (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-Bw29nClosureRawSha256 -Path $closurePath) -ceq
        $expectedClosureSha256
) "$gateId closure is missing or changed"
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100

Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_balanced_wave_bw29n_nuisance_transfer_closure_v1" -and
    [string]$closure.status -ceq
        "closed_implementation_invalid_after_complete_physical_matrix_and_pre_evaluation_receipt_contract_failure" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.experiment_source_commit -ceq $sourceCommit -and
    [string]$closure.experiment_source_tree -ceq $sourceTree -and
    [bool]$closure.source_was_clean_and_equal_to_origin_and_live_github_main -and
    [string]$closure.attempt_id -ceq $attemptId -and
    [bool]$closure.disposition.complete_declared_physical_matrix_attempted -and
    [int]$closure.disposition.expected_world_count -eq 24 -and
    [int]$closure.disposition.parsed_receipt_count -eq 24 -and
    -not [bool]$closure.disposition.original_frozen_evaluator_completed -and
    -not [bool]$closure.disposition.development_result_valid -and
    -not [bool]$closure.disposition.development_candidate_selected -and
    [string]$closure.disposition.selected_candidate_id -ceq "NONE" -and
    -not [bool]$closure.disposition.valid_none_selection -and
    [bool]$closure.disposition.not_a_locomotion_negative -and
    [bool]$closure.disposition.not_a_nuisance_acceptance_result -and
    [bool]$closure.disposition.implementation_invalid
) "$gateId closure identity or disposition changed"

Assert-Exact (
    (git -C $repoRoot rev-parse "${sourceCommit}^{tree}").Trim() -ceq
        $sourceTree
) "$gateId experiment source tree changed"
foreach ($binding in $closure.exact_source_bindings.GetEnumerator()) {
    $relativePath = [string]$binding.Value.path
    $currentPath = Join-Path $repoRoot $relativePath
    $treeLine = (& git -C $repoRoot ls-tree $sourceCommit -- $relativePath).Trim()
    $treeParts = @($treeLine -split "\s+")
    Assert-Exact (
        (Test-Path -LiteralPath $currentPath -PathType Leaf) -and
        (Get-Bw29nClosureRawSha256 -Path $currentPath) -ceq
            [string]$binding.Value.raw_sha256 -and
        $treeParts.Count -ge 3 -and
        [string]$treeParts[2] -ceq [string]$binding.Value.git_blob_oid
    ) "$gateId frozen source binding changed: $($binding.Key)"
}

$compilerCommit = [string]$closure.posthoc_diagnostic.compiler_commit
$compilerTree = [string]$closure.posthoc_diagnostic.compiler_tree
$compilerRelativePath = [string]$closure.posthoc_diagnostic.compiler_path
$compilerTreeLine = (& git -C $repoRoot ls-tree (
    $compilerCommit
) -- $compilerRelativePath).Trim()
$compilerTreeParts = @($compilerTreeLine -split "\s+")
Assert-Exact (
    (git -C $repoRoot rev-parse "${compilerCommit}^{tree}").Trim() -ceq
        $compilerTree -and
    (Get-Bw29nClosureRawSha256 -Path $compilerPath) -ceq
        [string]$closure.posthoc_diagnostic.compiler_raw_sha256 -and
    $compilerTreeParts.Count -ge 3 -and
    [string]$compilerTreeParts[2] -ceq
        [string]$closure.posthoc_diagnostic.compiler_git_blob_oid
) "$gateId posthoc compiler source binding changed"

$evidenceRoot = [System.IO.Path]::GetFullPath(
    [string]$closure.retained_evidence.root
)
Assert-Exact (
    $evidenceRoot.StartsWith(
        $evidenceBase + [System.IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    (Test-Path -LiteralPath $evidenceRoot -PathType Container)
) "$gateId retained evidence root is missing or outside the evidence boundary"
foreach ($entry in @(
    @($closure.retained_evidence.attempt, "attempt"),
    @($closure.retained_evidence.evaluation_input, "evaluation input"),
    @(
        $closure.retained_evidence.posthoc_receipt_alias_diagnostic,
        "posthoc receipt-alias diagnostic"
    )
)) {
    Assert-HashedArtifact `
        -Root $evidenceRoot `
        -Artifact $entry[0] `
        -Label $entry[1]
}
foreach ($forbidden in @(
    $closure.retained_evidence.original_evaluation,
    $closure.retained_evidence.original_report,
    $closure.retained_evidence.original_completion
)) {
    Assert-Exact (
        -not [bool]$forbidden.exists -and
        -not (Test-Path -LiteralPath (
            Join-Path $evidenceRoot ([string]$forbidden.path)
        ))
    ) "$gateId unexpected original aggregate artifact exists"
}

$tree = Get-EvidenceTreeDigest -Root $evidenceRoot
Assert-Exact (
    [int]$tree.file_count -eq
        [int]$closure.retained_evidence.tree.file_count -and
    [long]$tree.total_byte_length -eq
        [long]$closure.retained_evidence.tree.total_byte_length -and
    [string]$tree.tree_sha256 -ceq
        [string]$closure.retained_evidence.tree.tree_sha256
) "$gateId retained evidence tree changed"

$attestationPath = [System.IO.Path]::GetFullPath(
    [string]$closure.full_godot_v2_attestation.path
)
Assert-Exact (
    (Test-Path -LiteralPath $attestationPath -PathType Leaf) -and
    (Get-Bw29nClosureRawSha256 -Path $attestationPath) -ceq
        [string]$closure.full_godot_v2_attestation.raw_sha256
) "$gateId exact-source full-Godot V2 attestation changed"
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Exact (
    [string]$attestation.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$attestation.status -ceq "full_godot_conformance_passed" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    -not [bool]$attestation.claims.walking_acceptance -and
    -not [bool]$attestation.claims.release_authorized -and
    -not [bool]$attestation.claims.completed_engine_neutral_sdk -and
    -not [bool]$attestation.claims.physical_acceptance_authority
) "$gateId exact-source attestation identity or claim boundary changed"

$retainedAttemptPath = Join-Path $evidenceRoot "attempt.json"
$retainedEvaluationInputPath = Join-Path $evidenceRoot "evaluation-input.json"
$retainedDiagnosticPath = Join-Path $evidenceRoot (
    "posthoc-receipt-alias-diagnostic.json"
)
$attempt = Get-Content -Raw -LiteralPath $retainedAttemptPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$input = Get-Content -Raw -LiteralPath $retainedEvaluationInputPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$diagnostic = Get-Content -Raw -LiteralPath $retainedDiagnosticPath |
    ConvertFrom-Json -AsHashtable -Depth 100

Assert-Exact (
    [string]$attempt.schema_version -ceq
        "sporespore_balanced_wave_bw29n_nuisance_transfer_attempt_v1" -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.origin_main_commit -ceq $sourceCommit -and
    [string]$attempt.remote_main_commit -ceq $sourceCommit -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [string]$attempt.attempt_id -ceq $attemptId -and
    [bool]$attempt.physical_identity_consumed -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    [bool]$attempt.locomotion_outcome_exposed_at_attempt -and
    -not [bool]$attempt.physical_acceptance_authority -and
    [int]$attempt.expected_world_count -eq 24 -and
    @($attempt.ordered_cell_ids).Count -eq 24
) "$gateId retained attempt changed"

. $evaluatorPath
$expectedCellIds = @(Get-Bw29nExpectedCells | ForEach-Object {
    [string]$_.cell_id
})
Assert-Exact (
    Test-SequenceEqual `
        -Actual @($attempt.ordered_cell_ids) `
        -Expected $expectedCellIds
) "$gateId retained attempt cell order changed"

$receipts = @($input.cell_receipts)
Assert-Exact (
    [string]$input.schema_version -ceq
        "sporespore_balanced_wave_bw29n_nuisance_transfer_evaluation_input_v1" -and
    [string]$input.attempt_id -ceq $attemptId -and
    [string]$input.source.commit -ceq $sourceCommit -and
    [bool]$input.source.worktree_clean -and
    [bool]$input.source.matches_live_github_main -and
    $receipts.Count -eq 24 -and
    (Test-SequenceEqual `
        -Actual @($receipts | ForEach-Object { [string]$_.cell_id }) `
        -Expected $expectedCellIds)
) "$gateId retained evaluation input changed"

$originalExceptionType = ""
$originalExceptionMessage = ""
try {
    Invoke-Bw29nNuisanceTransferEvaluation `
        -CellReceipts $receipts `
        -Source ([System.Collections.IDictionary]$input.source) `
        -AttemptId ([string]$input.attempt_id) | Out-Null
} catch {
    $originalExceptionType = $_.Exception.GetType().FullName
    $originalExceptionMessage = $_.Exception.Message
}
Assert-Exact (
    $originalExceptionType -ceq
        [string]$closure.original_aggregation_failure.exception_type -and
    $originalExceptionMessage -ceq
        [string]$closure.original_aggregation_failure.exception_message
) "$gateId original frozen evaluator failure did not reproduce exactly"

$candidateA = @($receipts | Where-Object {
    [string]$_.candidate_id -ceq "BW29N-A"
})
$candidateB = @($receipts | Where-Object {
    [string]$_.candidate_id -ceq "BW29N-B"
})
Assert-Exact (
    $candidateA.Count -eq 12 -and
    $candidateB.Count -eq 12 -and
    @($candidateA | Where-Object {
        $_.Contains("material_profile_digest") -and
        [string]$_.material_profile_digest -ceq $materialProfileDigest
    }).Count -eq 12 -and
    @($candidateA | Where-Object {
        $_.Contains("material_profile_sha256")
    }).Count -eq 0 -and
    @($candidateB | Where-Object {
        $_.Contains("material_profile_digest")
    }).Count -eq 0 -and
    @($candidateB | Where-Object {
        $_.Contains("material_profile_sha256") -and
        [string]$_.material_profile_sha256 -ceq $materialProfileDigest
    }).Count -eq 12
) "$gateId retained receipt-contract split changed"

$candidateANoise = @($candidateA | Where-Object {
    [string]$_.challenge_profile_id -ceq "bw6n_sensor_noise_v1"
} | Sort-Object { [int]$_.campaign_seed })
$candidateBNoise = @($candidateB | Where-Object {
    [string]$_.challenge_profile_id -ceq "bw6n_sensor_noise_v1"
} | Sort-Object { [int]$_.campaign_seed })
Assert-Exact (
    $candidateANoise.Count -eq 3 -and
    @($candidateANoise | Where-Object {
        [int]$_.observation_fault_application_count -ne 1514 -or
        [int]$_.observation_fault_base_and_stability_count -ne 1514 -or
        -not [bool]$_.challenge_gate_passed -or
        -not [bool]$_.role_gate_passed -or
        -not [bool]$_.common_execution_integrity
    }).Count -eq 0 -and
    $candidateBNoise.Count -eq 3 -and
    (Test-SequenceEqual `
        -Actual @($candidateBNoise | ForEach-Object { [string]$_.cell_id }) `
        -Expected @($expectedInvalidCounts.Keys))
) "$gateId retained sensor-noise challenge identities changed"
foreach ($cell in $candidateBNoise) {
    $cellId = [string]$cell.cell_id
    $expectedCount = [int]$expectedInvalidCounts[$cellId]
    Assert-Exact (
        [int]$cell.observation_fault_application_count -eq $expectedCount -and
        [int]$cell.observation_fault_base_and_stability_count -eq
            $expectedCount -and
        [double]$cell.maximum_observation_fault_component -eq 0.02 -and
        -not [bool]$cell.challenge_gate_passed -and
        -not [bool]$cell.role_gate_passed -and
        -not [bool]$cell.common_execution_integrity -and
        [bool]$cell.measurement_gate_passed -and
        [bool]$cell.application_gate_passed -and
        [bool]$cell.outcome_complete -and
        [bool]$cell.walking_observed
    ) "$gateId retained invalid sensor-noise cell changed: $cellId"
}
Assert-Exact (
    @($receipts | Where-Object { [bool]$_.measurement_gate_passed }).Count -eq 24 -and
    @($receipts | Where-Object { [bool]$_.application_gate_passed }).Count -eq 24 -and
    @($receipts | Where-Object { [bool]$_.outcome_complete }).Count -eq 24 -and
    @($receipts | Where-Object { [bool]$_.role_gate_passed }).Count -eq 21 -and
    @($receipts | Where-Object { [bool]$_.challenge_gate_passed }).Count -eq 21 -and
    @($receipts | Where-Object { [bool]$_.common_execution_integrity }).Count -eq 21
) "$gateId retained execution-integrity counts changed"

$cellDirectories = @(Get-ChildItem -LiteralPath $evidenceRoot -Directory)
Assert-Exact ($cellDirectories.Count -eq 24) (
    "$gateId retained cell-directory count changed"
)
for ($index = 0; $index -lt 24; $index += 1) {
    $ordinal = $index + 1
    $cellId = $expectedCellIds[$index]
    $directoryName = "cell-{0:D2}-{1}" -f $ordinal, $cellId
    $directoryPath = Join-Path $evidenceRoot $directoryName
    Assert-Exact (
        Test-Path -LiteralPath $directoryPath -PathType Container
    ) "$gateId retained cell directory is missing: $directoryName"
    $files = @(Get-ChildItem -LiteralPath $directoryPath -File |
        Sort-Object Name)
    Assert-Exact (
        (Test-SequenceEqual `
            -Actual @($files.Name) `
            -Expected @("engine.log", "stderr.log", "transcript.log"))
    ) "$gateId retained cell log set changed: $directoryName"
    $engineLogPath = Join-Path $directoryPath "engine.log"
    $rawLines = @(Get-Content -LiteralPath $engineLogPath | Where-Object {
        $_.StartsWith($rawPrefix, [StringComparison]::Ordinal)
    })
    Assert-Exact ($rawLines.Count -eq 1) (
        "$gateId expected one raw receipt marker: $directoryName"
    )
    $logReceipt = $rawLines[0].Substring($rawPrefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-Exact (
        ($logReceipt | ConvertTo-Json -Compress -Depth 100) -ceq
            ($receipts[$index] | ConvertTo-Json -Compress -Depth 100)
    ) "$gateId retained engine-log receipt differs from evaluation input: $cellId"
    foreach ($logPath in @(
        $engineLogPath,
        (Join-Path $directoryPath "stderr.log"),
        (Join-Path $directoryPath "transcript.log")
    )) {
        Assert-Exact (
            -not (Select-String `
                -LiteralPath $logPath `
                -SimpleMatch `
                -Quiet `
                -Pattern "SCRIPT ERROR:", "ERROR:")
        ) "$gateId retained process log contains an engine/script error: $logPath"
    }
}

Assert-Exact (
    [string]$diagnostic.schema_version -ceq
        "sporespore_balanced_wave_bw29n_nuisance_transfer_posthoc_receipt_alias_diagnostic_v1" -and
    [string]$diagnostic.classification -ceq
        "posthoc_diagnostic_only_not_a_reclassification_or_selection" -and
    [int]$diagnostic.retained_physical_evidence.parsed_receipt_count -eq 24 -and
    [int]$diagnostic.observed_challenge_realization_defect.invalid_cell_count -eq 3 -and
    [string]$diagnostic.in_memory_alias_projection.classification -ceq
        "non_authoritative_in_memory_posthoc" -and
    [int]$diagnostic.in_memory_alias_projection.projected_receipt_count -eq 12 -and
    -not [bool]$diagnostic.in_memory_alias_projection.any_measured_value_changed -and
    -not [bool]$diagnostic.in_memory_alias_projection.any_walking_outcome_changed -and
    -not [bool]$diagnostic.projected_frozen_evaluator_diagnostic.ok -and
    [int]$diagnostic.projected_frozen_evaluator_diagnostic.passed_gate_count -eq 10 -and
    [int]$diagnostic.projected_frozen_evaluator_diagnostic.failed_gate_count -eq 2 -and
    [string]$diagnostic.projected_frozen_evaluator_diagnostic.selected_candidate_id -ceq "NONE" -and
    -not [bool]$diagnostic.projected_frozen_evaluator_diagnostic.development_selection_authority -and
    -not [bool]$diagnostic.projected_frozen_evaluator_diagnostic.fresh_validation_authority -and
    -not [bool]$diagnostic.projected_frozen_evaluator_diagnostic.physical_acceptance_authority -and
    [bool]$diagnostic.immutability.status_remains_implementation_invalid -and
    -not [bool]$diagnostic.immutability.campaign_reclassified
) "$gateId retained posthoc diagnostic changed"

$temporaryRoot = Join-Path (
    [System.IO.Path]::GetTempPath()
) ("sporespore-bw29n-closure-" + [Guid]::NewGuid().ToString("N"))
$temporaryDiagnostic = Join-Path $temporaryRoot "diagnostic.json"
try {
    [void](New-Item -ItemType Directory -Path $temporaryRoot)
    $compilerOutput = (& pwsh `
        -NoLogo `
        -NoProfile `
        -File $compilerPath `
        -EvaluationInputPath $retainedEvaluationInputPath `
        -AttemptPath $retainedAttemptPath `
        -OutputPath $temporaryDiagnostic 2>&1 | Out-String)
    $compilerExitCode = $LASTEXITCODE
    $compilerMarkerPresent = $compilerOutput.Contains(
        "BW29N_POSTHOC_RECEIPT_DIAGNOSTIC_PASS",
        [StringComparison]::Ordinal
    )
    Assert-Exact (
        Test-Path -LiteralPath $temporaryDiagnostic -PathType Leaf
    ) (
        "$gateId posthoc compiler did not create its diagnostic: " +
        "exit=$compilerExitCode output=$compilerOutput"
    )
    $temporaryDiagnosticSha256 = Get-Bw29nClosureRawSha256 `
        -Path $temporaryDiagnostic
    $expectedDiagnosticSha256 = [string](
        $closure.retained_evidence.posthoc_receipt_alias_diagnostic.raw_sha256
    )
    Assert-Exact (
        $compilerExitCode -eq 0 -and
        $compilerMarkerPresent -and
        $temporaryDiagnosticSha256 -ceq $expectedDiagnosticSha256
    ) (
        "$gateId posthoc diagnostic is not byte reproducible: " +
        "exit=$compilerExitCode marker=$compilerMarkerPresent " +
        "actual=$temporaryDiagnosticSha256 expected=$expectedDiagnosticSha256"
    )
} finally {
    if (Test-Path -LiteralPath $temporaryRoot -PathType Container) {
        $resolvedTemporaryRoot = [System.IO.Path]::GetFullPath($temporaryRoot)
        $resolvedSystemTemp = [System.IO.Path]::GetFullPath(
            [System.IO.Path]::GetTempPath()
        )
        Assert-Exact (
            $resolvedTemporaryRoot.StartsWith(
                $resolvedSystemTemp,
                [StringComparison]::OrdinalIgnoreCase
            )
        ) "$gateId refusing to remove an unexpected test directory"
        Remove-Item -LiteralPath $resolvedTemporaryRoot -Recurse -Force
    }
}

$priorAttempts = @(Get-ChildItem `
    -LiteralPath $evidenceBase `
    -Filter "attempt.json" `
    -File `
    -Recurse | Where-Object {
        try {
            $candidateAttempt = Get-Content -Raw -LiteralPath $_.FullName |
                ConvertFrom-Json -AsHashtable -Depth 100
            [string]$candidateAttempt.campaign_id -ceq $campaignId
        } catch { $false }
    })
$supervisorText = Get-Content -Raw -LiteralPath $supervisorPath
Assert-Exact (
    $priorAttempts.Count -eq 1 -and
    [System.IO.Path]::GetFullPath($priorAttempts[0].FullName) -ceq
        [System.IO.Path]::GetFullPath($retainedAttemptPath) -and
    $supervisorText.Contains(
        'Assert-Bw29nExact ($priorAttempts.Count -eq 0)',
        [StringComparison]::Ordinal
    ) -and
    $supervisorText.Contains(
        '$gateId already has a retained attempt and may not rerun',
        [StringComparison]::Ordinal
    )
) "$gateId one-shot retained-attempt rerun interlock changed"

foreach ($claim in $closure.claim_boundary.Keys) {
    Assert-Exact (
        -not [bool]$closure.claim_boundary[$claim]
    ) "$gateId unsupported closure claim became true: $claim"
}
Assert-Exact (
    [bool]$closure.immutability.first_attempt_is_final_for_source_identity -and
    [bool]$closure.immutability.physical_identity_consumed -and
    [bool]$closure.immutability.same_identity_rerun_forbidden -and
    [bool]$closure.immutability.posthoc_selection_forbidden -and
    [bool]$closure.immutability.posthoc_reclassification_forbidden -and
    [bool]$closure.successor_requirements.new_campaign_id_gate_id_source_identity_preregistration_and_evidence_root -and
    [bool]$closure.successor_requirements.material_profile_field_name_and_schema_must_be_identical_across_both_real_workers -and
    [bool]$closure.successor_requirements.challenge_application_horizon_must_be_candidate_independent -and
    [bool]$closure.successor_requirements.real_worker_canary_must_assert_exact_sensor_noise_count_for_each_execution_route -and
    (Test-SequenceEqual `
        -Actual @($closure.successor_requirements.fresh_reserved_seeds) `
        -Expected @(49101, 49102, 49103)) -and
    [bool]$closure.successor_requirements.fresh_reserved_seeds_remain_unopened_by_bw29n -and
    [bool]$closure.successor_requirements.bw29n_descriptive_observations_may_inform_successor_design_only -and
    [bool]$closure.successor_requirements.bw29n_b_may_not_be_promoted_from_this_result
) "$gateId immutability or successor boundary changed"

Write-Host (
    "BW29N_NUISANCE_TRANSFER_CLOSURE_PASS status=implementation-invalid " +
    "worlds=24 parsed=24 logs=24 original_evaluation=False " +
    "receipt_contract_split=12/12 invalid_challenge_cells=3 " +
    "posthoc=10/12 selector=NONE valid_none=False selection_authority=False " +
    "nuisance_authority=False physical_authority=False rerun_refused=True"
)

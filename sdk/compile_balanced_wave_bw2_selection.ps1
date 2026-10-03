#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    ),
    [Parameter(Mandatory = $true)]
    [string]$Output
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$preregistrationPath = Join-Path $sdkRoot "balanced_wave_bw2_preregistration.json"
$evidenceRootPath = [System.IO.Path]::GetFullPath($EvidenceRoot)
$outputPath = [System.IO.Path]::GetFullPath($Output)

function Assert-Exact {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Get-Sha256 {
    param([string]$Path)
    return (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-FalseGateCount {
    param([System.Collections.IDictionary]$Gates)
    Assert-Exact ($null -ne $Gates) "Walking-gate receipt is missing"
    return @(
        $Gates.GetEnumerator() |
            Where-Object { -not [bool]$_.Value }
    ).Count
}

function Get-SourceState {
    $status = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    )
    Assert-Exact ($LASTEXITCODE -eq 0) "Unable to read the source worktree"
    $head = (& git -C $repoRoot rev-parse HEAD).Trim()
    Assert-Exact ($LASTEXITCODE -eq 0) "Unable to resolve HEAD"
    $originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
    Assert-Exact ($LASTEXITCODE -eq 0) "Unable to resolve origin/main"
    return [ordered]@{
        commit = $head
        clean = $status.Count -eq 0
        matches_origin_main = $head -ceq $originMain
    }
}

Assert-Exact (
    Test-Path -LiteralPath $preregistrationPath -PathType Leaf
) "BW2 preregistration is missing"
Assert-Exact (
    Test-Path -LiteralPath $evidenceRootPath -PathType Container
) "Durable BW2 evidence root is missing: $evidenceRootPath"
Assert-Exact (
    [System.IO.Path]::GetFileName($outputPath) -ceq "report.json"
) "The retained BW2 selection filename must be report.json"
Assert-Exact (
    -not (Test-Path -LiteralPath $outputPath)
) "Refusing to overwrite a BW2 selection report: $outputPath"

$outputDirectory = Split-Path -Parent $outputPath
if (Test-Path -LiteralPath $outputDirectory) {
    Assert-Exact (
        @(Get-ChildItem -LiteralPath $outputDirectory -Force).Count -eq 0
    ) "Refusing a nonempty BW2 selection directory: $outputDirectory"
}

$sourceBefore = Get-SourceState
Assert-Exact ([bool]$sourceBefore.clean) (
    "Refusing to compile BW2 selection from dirty source"
)
Assert-Exact ([bool]$sourceBefore.matches_origin_main) (
    "Refusing BW2 selection because HEAD does not match origin/main"
)

$preregistration = Get-Content -LiteralPath $preregistrationPath -Raw |
    ConvertFrom-Json -AsHashtable
$expectedMetricOrder = @(
    "infrastructure_and_integrity_failure_count:ascending",
    "eligible_nonzero_material_treatment_nonwalk_count:ascending",
    "opened_counterexample_nonwalk_count:ascending",
    "reference_treatment_nonwalk_count:ascending",
    "aggregate_walking_gate_failure_count:ascending",
    "worst_normalized_positive_safety_margin:descending"
)
$observedMetricOrder = @(
    $preregistration.selection.lexicographic_metrics |
        ForEach-Object {
            "$([string]$_['metric']):$([string]$_['direction'])"
        }
)
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw2_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw2_physics_world" -and
    [string]::Join(",", @($preregistration.candidate_order)) -ceq
        "BW2-A,BW2-B,BW2-C" -and
    [string]::Join(",", $observedMetricOrder) -ceq
        [string]::Join(",", $expectedMetricOrder) -and
    [string]$preregistration.selection.tie_rule -ceq
        "candidate_order_ascending" -and
    [bool]$preregistration.selection.if_no_early_stop_select_best_eligible_candidate_after_bw2_c -and
    [bool]$preregistration.selection.selected_implementation_must_be_committed_before_bw3 -and
    [int]$preregistration.physics_matrix.total_world_count_per_opened_candidate -eq 29
) "Frozen BW2 preregistration or selection order is invalid"

$inputSpecs = [ordered]@{
    "BW2-A" = [ordered]@{
        policy_id = "sporespore_balanced_wave_v1"
        policy_digest =
            "sha256:d1ce56ba1a74f843700559e1b240c3a5a4ea33c31d7a14d874fdd2c6ebfb2fd9"
        reference = [ordered]@{
            relative_path =
                "balanced-wave-bw2-a-reference-r2-56c2652\report.json"
            sha256 =
                "763abad78999373e4e3e82e68fcde1d29b286e89d8e473315ff9b4b6b4c8bcbb"
            source_commit = "56c265230415e33388baf35cb2e2cd7ab46494f3"
        }
        material = [ordered]@{
            relative_path =
                "balanced-wave-bw2-a-material-63774e0\report.json"
            sha256 =
                "d3e03d7325e884bcf878f50fdcdf0a7af0d5d5134c44f1da1e766cee6e069ea3"
            source_commit = "63774e0adf8ab6051193c863a7e072eb349af7a8"
        }
        counterexamples = [ordered]@{
            relative_path =
                "balanced-wave-bw2-a-counterexamples-580e9ca\report.json"
            sha256 =
                "51aeb7bea6d001bc84c2eb2ec612691f73dd4476c22bef03fd34db2d7519ecbc"
            source_commit = "580e9ca84af4c4d51149eaa2dc68953d80eda6cf"
        }
    }
    "BW2-B" = [ordered]@{
        policy_id = "sporespore_balanced_wave_bw2_b_v1"
        policy_digest =
            "sha256:0ab4fa4c4e37441b26bdd00d23926e4511892201150bf61554c5b1362edf7913"
        reference = [ordered]@{
            relative_path =
                "balanced-wave-bw2-b-reference-7d3000a\report.json"
            sha256 =
                "eef76ab8671fbabc7f07f866fe2336b570231d62524d0c07e00a3cbba805ec06"
            source_commit = "7d3000af16d686d2d36c640dd1c77daf84c58291"
        }
        material = [ordered]@{
            relative_path =
                "balanced-wave-bw2-b-material-24624bd\report.json"
            sha256 =
                "430af89d4efba0e7f4ca76d3321e579a7372fe8d95e70e443c79c0a569154422"
            source_commit = "24624bd68b401cec03fd1541ab1e890e6c471241"
        }
        counterexamples = [ordered]@{
            relative_path =
                "balanced-wave-bw2-b-counterexamples-cc5c7f6\report.json"
            sha256 =
                "0dd9ab445481aa541435eeea6a11b0e81d81aa0b9cf466d24621e1c19324f995"
            source_commit = "cc5c7f659a7e7b0cb8b32f55c540716f582ada6b"
        }
    }
    "BW2-C" = [ordered]@{
        policy_id = "sporespore_balanced_wave_bw2_c_v1"
        policy_digest =
            "sha256:367e944b33384d8685d746dca0a864cfa33ca013846636236512641456d51ad3"
        reference = [ordered]@{
            relative_path =
                "balanced-wave-bw2-c-reference-d0bdf36\report.json"
            sha256 =
                "f89e050a159cfa12d1dd61fc1ce61e65c6ae63994c35f606b53aaac1acd317f9"
            source_commit = "d0bdf36edfe0c8b323506b712ac51e74a720fbfc"
        }
        material = [ordered]@{
            relative_path =
                "balanced-wave-bw2-c-material-45aae3e\report.json"
            sha256 =
                "a181b5f05fedb18b30458af718f93924ef26d02cf4e2f327c75ed2df6b06467b"
            source_commit = "45aae3e9538d81e65b7d74246ab1755b5768d863"
        }
        counterexamples = [ordered]@{
            relative_path =
                "balanced-wave-bw2-c-counterexamples-208cec2\report.json"
            sha256 =
                "2cc8d9442d02e6f713fe86a54e641afba22cb0c030f6e9f685cfa0a4e0546a13"
            source_commit = "208cec232a5e52e52571703829cfc687439ac5e6"
        }
    }
}

$candidateScores = @()
$retainedInputs = @()
foreach ($candidateId in @($preregistration.candidate_order)) {
    $candidateId = [string]$candidateId
    $spec = $inputSpecs[$candidateId]
    Assert-Exact ($null -ne $spec) "Missing input specification for $candidateId"
    Assert-Exact (
        [string]$preregistration.candidate_policy_digests[$candidateId] -ceq
            [string]$spec.policy_digest
    ) "Policy digest mismatch for $candidateId"

    $reports = [ordered]@{}
    foreach ($role in @("reference", "material", "counterexamples")) {
        $roleSpec = $spec[$role]
        $path = [System.IO.Path]::GetFullPath(
            (Join-Path $evidenceRootPath $roleSpec.relative_path)
        )
        Assert-Exact (
            Test-Path -LiteralPath $path -PathType Leaf
        ) "Missing $candidateId $role report: $path"
        $actualHash = Get-Sha256 $path
        Assert-Exact (
            $actualHash -ceq [string]$roleSpec.sha256
        ) "$candidateId $role report SHA-256 mismatch"
        $report = Get-Content -LiteralPath $path -Raw |
            ConvertFrom-Json -AsHashtable
        Assert-Exact (
            [string]$report.candidate_id -ceq $candidateId -and
            [string]$report.candidate_policy_digest -ceq
                [string]$spec.policy_digest -and
            [string]$report.source_commit -ceq
                [string]$roleSpec.source_commit -and
            [bool]$report.source_worktree_clean -and
            [bool]$report.source_matches_origin_main -and
            [bool]$report.accepted -and
            [string]$report.result_status -ceq "integrity_accepted" -and
            [bool]$report.development_data_only
        ) "$candidateId $role report identity or integrity is invalid"
        $reports[$role] = $report
        $retainedInputs += [ordered]@{
            candidate_id = $candidateId
            role = $role
            path = $path
            sha256 = $actualHash
            schema_version = [string]$report.schema_version
            source_commit = [string]$report.source_commit
        }
    }

    $reference = $reports.reference
    $material = $reports.material
    $counterexamples = $reports.counterexamples
    Assert-Exact (
        [string]$reference.schema_version -ceq
            "sporespore_balanced_wave_bw2_reference_report_v2" -and
        [string]$reference.receipt.policy_id -ceq [string]$spec.policy_id -and
        [int]$reference.receipt.world_count -eq 2 -and
        [int]$reference.receipt.passed_gate_count -eq 20 -and
        [int]$reference.receipt.failed_gate_count -eq 0 -and
        [int]$reference.receipt.treatment.step_count -eq 1514 -and
        [int]$reference.receipt.treatment.validated_balanced_wave_command_count -eq
            12112 -and
        [int]$reference.receipt.treatment.native_motor_write_count -eq 12112 -and
        [int]$reference.receipt.treatment.portable_controller_base_application_count -eq
            12112 -and
        [int]$reference.receipt.treatment.direct_body_write_count -eq 0 -and
        [int]$reference.receipt.treatment.nonzero_stability_application_count -gt 0
    ) "$candidateId reference report contract is invalid"
    Assert-Exact (
        [string]$material.schema_version -ceq
            "sporespore_balanced_wave_bw2_material_report_v1" -and
        [string]$material.receipt.policy_id -ceq [string]$spec.policy_id -and
        [int]$material.receipt.expected_world_count -eq 23 -and
        [int]$material.receipt.observed_world_count -eq 23 -and
        [int]$material.receipt.passed_gate_count -eq 30 -and
        [int]$material.receipt.failed_gate_count -eq 0 -and
        [int]$material.receipt.integrity_failure_count -eq 0 -and
        [int]$material.receipt.eligible_nonzero_treatment_count -eq 18 -and
        [int]$material.receipt.eligible_nonzero_treatment_with_nonzero_stability_count -eq
            18 -and
        [int]$material.receipt.zero_friction_exact_fallback_count -eq 1 -and
        @($material.receipt.cells).Count -eq 23
    ) "$candidateId material report contract is invalid"
    Assert-Exact (
        [string]$counterexamples.schema_version -ceq
            "sporespore_balanced_wave_bw2_counterexample_report_v1" -and
        (
            -not $counterexamples.Contains("policy_id") -or
            [string]$counterexamples.policy_id -ceq [string]$spec.policy_id
        ) -and
        [int]$counterexamples.expected_world_count -eq 4 -and
        [int]$counterexamples.observed_world_count -eq 4 -and
        [int]$counterexamples.integrity_failure_count -eq 0 -and
        @($counterexamples.cells).Count -eq 4
    ) "$candidateId counterexample report contract is invalid"

    $eligibleMaterialCells = @(
        $material.receipt.cells |
            Where-Object {
                [string]$_['mode'] -ceq "treatment" -and
                [double]$_['authored_friction'] -gt 0.0
            }
    )
    $recomputedMaterialNonwalkCount = @(
        $eligibleMaterialCells |
            Where-Object { -not [bool]$_['walking_observed'] }
    ).Count
    $recomputedMaterialWalkingGateFailureCount = 0
    foreach ($cell in $eligibleMaterialCells) {
        Assert-Exact (
            [bool]$cell.campaign_execution_gate_passed -and
            [int]$cell.direct_body_write_count -eq 0
        ) "$candidateId material cell execution integrity is invalid"
        $recomputedMaterialWalkingGateFailureCount += Get-FalseGateCount (
            $cell.walking_gate_receipts
        )
    }
    Assert-Exact (
        $recomputedMaterialNonwalkCount -eq
            [int]$material.eligible_nonzero_treatment_nonwalk_count -and
        $recomputedMaterialNonwalkCount -eq
            [int]$material.receipt.eligible_nonzero_treatment_nonwalk_count -and
        $recomputedMaterialWalkingGateFailureCount -eq
            [int]$material.receipt.aggregate_walking_gate_failure_count
    ) "$candidateId material score does not recompute exactly"

    $counterexampleNonwalkCount = 0
    $counterexampleWalkingGateFailureCount = 0
    foreach ($cellResult in @($counterexamples.cells)) {
        $receipt = $cellResult.receipt
        Assert-Exact (
            [bool]$receipt.ok -and
            [string]$receipt.candidate_id -ceq $candidateId -and
            [string]$receipt.policy_id -ceq [string]$spec.policy_id -and
            [string]$receipt.candidate_policy_digest -ceq
                [string]$spec.policy_digest -and
            [int]$receipt.world_build_count -eq 1 -and
            [int]$receipt.step_count -eq 1514 -and
            [int]$receipt.validated_balanced_wave_command_count -eq 12112 -and
            [int]$receipt.native_motor_write_count -eq 12112 -and
            [int]$receipt.portable_controller_base_application_count -eq 12112 -and
            [int]$receipt.direct_body_write_count -eq 0 -and
            [int]$receipt.nonzero_stability_application_count -gt 0
        ) "$candidateId counterexample cell integrity is invalid"
        if (-not [bool]$receipt.walking_observed) {
            $counterexampleNonwalkCount += 1
        }
        $counterexampleWalkingGateFailureCount += Get-FalseGateCount (
            $receipt.walking_gate_receipts
        )
    }
    Assert-Exact (
        $counterexampleNonwalkCount -eq
            [int]$counterexamples.counterexample_nonwalk_count
    ) "$candidateId counterexample nonwalk count does not recompute"

    $referenceTreatmentWalking = [bool]$reference.reference_treatment_walking_observed
    Assert-Exact (
        $referenceTreatmentWalking -eq
            [bool]$reference.receipt.treatment.walking_observed
    ) "$candidateId reference walking result is inconsistent"
    $referenceTreatmentNonwalkCount = if ($referenceTreatmentWalking) { 0 } else { 1 }
    $referenceWalkingGateFailureCount = Get-FalseGateCount (
        $reference.receipt.treatment.walking_gate_receipts
    )
    $integrityFailureCount = (
        [int]$reference.receipt.failed_gate_count +
        [int]$material.receipt.integrity_failure_count +
        [int]$counterexamples.integrity_failure_count
    )
    $aggregateWalkingGateFailureCount = (
        $referenceWalkingGateFailureCount +
        $recomputedMaterialWalkingGateFailureCount +
        $counterexampleWalkingGateFailureCount
    )
    $candidateScores += [PSCustomObject][ordered]@{
        candidate_id = $candidateId
        policy_id = [string]$spec.policy_id
        candidate_policy_digest = [string]$spec.policy_digest
        eligible = $true
        observed_world_count = 29
        infrastructure_and_integrity_failure_count = $integrityFailureCount
        eligible_nonzero_material_treatment_nonwalk_count =
            $recomputedMaterialNonwalkCount
        opened_counterexample_nonwalk_count = $counterexampleNonwalkCount
        reference_treatment_nonwalk_count = $referenceTreatmentNonwalkCount
        aggregate_walking_gate_failure_count = $aggregateWalkingGateFailureCount
        worst_normalized_positive_safety_margin = $null
        worst_normalized_positive_safety_margin_status =
            "undefined_by_preregistration_not_required_for_selection"
        early_stop_eligible = (
            $recomputedMaterialNonwalkCount -eq 0 -and
            $counterexampleNonwalkCount -eq 0 -and
            $referenceTreatmentNonwalkCount -eq 0
        )
    }
}

Assert-Exact ($candidateScores.Count -eq 3) "Exactly three BW2 scores are required"
$earlyStopCandidate = @(
    $candidateScores |
        Where-Object { [bool]$_.early_stop_eligible } |
        Select-Object -First 1
)
$selectedCandidate = $null
$decidingMetric = ""
$selectionMode = ""
$undefinedTiebreakRequired = $false
if ($earlyStopCandidate.Count -eq 1) {
    $selectedCandidate = $earlyStopCandidate[0]
    $selectionMode = "early_stop"
    $decidingMetric = "early_stop_rule"
} else {
    $contenders = @($candidateScores)
    foreach ($metric in @(
        "infrastructure_and_integrity_failure_count",
        "eligible_nonzero_material_treatment_nonwalk_count",
        "opened_counterexample_nonwalk_count",
        "reference_treatment_nonwalk_count",
        "aggregate_walking_gate_failure_count"
    )) {
        $minimum = (
            $contenders |
                Measure-Object -Property $metric -Minimum
        ).Minimum
        $next = @(
            $contenders |
                Where-Object { [int]($_.$metric) -eq [int]$minimum }
        )
        if ($next.Count -lt $contenders.Count) {
            $decidingMetric = $metric
        }
        $contenders = $next
        if ($contenders.Count -eq 1) {
            break
        }
    }
    if ($contenders.Count -ne 1) {
        $undefinedTiebreakRequired = $true
        throw (
            "BW2 selection requires worst_normalized_positive_safety_margin, " +
            "but the preregistration names no normalization formula; failing closed"
        )
    }
    $selectedCandidate = $contenders[0]
    $selectionMode = "best_eligible_after_bw2_c"
}

Assert-Exact (
    -not $undefinedTiebreakRequired -and
    $null -ne $selectedCandidate -and
    [string]$selectedCandidate.candidate_id -ceq "BW2-C" -and
    [string]$decidingMetric -ceq
        "eligible_nonzero_material_treatment_nonwalk_count"
) "Observed BW2 selection does not match the uniquely recomputed score"

$sourceAfter = Get-SourceState
Assert-Exact (
    [bool]$sourceAfter.clean -and
    [bool]$sourceAfter.matches_origin_main -and
    [string]$sourceAfter.commit -ceq [string]$sourceBefore.commit
) "Source changed while compiling BW2 selection"

[void][System.IO.Directory]::CreateDirectory($outputDirectory)
$sourcePaths = [ordered]@{
    preregistration = "sdk/balanced_wave_bw2_preregistration.json"
    compiler = "sdk/compile_balanced_wave_bw2_selection.ps1"
}
$sources = [ordered]@{}
foreach ($entry in $sourcePaths.GetEnumerator()) {
    $absolutePath = Join-Path $repoRoot $entry.Value
    $sources[$entry.Key] = [ordered]@{
        path = $entry.Value
        sha256 = Get-Sha256 $absolutePath
    }
}
$report = [ordered]@{
    schema_version = "sporespore_balanced_wave_bw2_selection_report_v1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = [string]$sourceBefore.commit
    source_worktree_clean = $true
    source_matches_origin_main = $true
    accepted = $true
    result_status = "selection_integrity_accepted"
    development_data_only = $true
    preregistration_sha256 = Get-Sha256 $preregistrationPath
    input_report_count = $retainedInputs.Count
    expected_world_count = 87
    observed_world_count = (
        $candidateScores |
            Measure-Object -Property observed_world_count -Sum
    ).Sum
    candidate_order = @($preregistration.candidate_order)
    candidate_scores = $candidateScores
    early_stop_triggered = $selectionMode -ceq "early_stop"
    selection_mode = $selectionMode
    deciding_metric = $decidingMetric
    undefined_safety_margin_tiebreak_required = $false
    undefined_safety_margin_tiebreak_handling =
        "fail_closed_if_first_five_metrics_tie"
    selected_candidate_id = [string]$selectedCandidate.candidate_id
    selected_policy_id = [string]$selectedCandidate.policy_id
    selected_candidate_policy_digest =
        [string]$selectedCandidate.candidate_policy_digest
    selected_implementation_must_be_committed_before_bw3 = $true
    development_selection_authority = $true
    walking_acceptance = $false
    material_robustness = $false
    arbitrary_quadruped_coverage = $false
    continuous_full_volume_coverage = $false
    cross_engine_c6 = $false
    completed_engine_neutral_sdk = $false
    physical_acceptance_authority = $false
    inputs = $retainedInputs
    sources = $sources
}
$temporaryPath = "$outputPath.tmp"
$json = $report | ConvertTo-Json -Depth 64
[System.IO.File]::WriteAllText(
    $temporaryPath,
    "$json`n",
    [System.Text.UTF8Encoding]::new($false)
)
[System.IO.File]::Move($temporaryPath, $outputPath, $false)

Write-Host "Retained BW2 selection report: $outputPath"
Write-Host (
    "BALANCED_WAVE_BW2_SELECTION_INTEGRITY=true " +
    "WORLDS=$($report.observed_world_count) " +
    "SELECTED=$($report.selected_candidate_id) " +
    "DECIDING_METRIC=$($report.deciding_metric)"
)

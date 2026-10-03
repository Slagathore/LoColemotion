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
$campaignId = "BW20F-BW19V-COLD-MATERIAL-LOCOMOTION"
$gateId = "BW20F-LOCOMOTION"
$sourceCommit = "452c11d3ca5262670615f9fb4804a956c0e0977b"
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_locomotion_closure.json"
$expectedClosureSha256 =
    "bd18cd9a4905182673459b7b203ff7b7ae4cd5f954f00175f14fc721980bc1ef"
$runnerPath = Join-Path (
    $sdkRoot
) "run_balanced_wave_bw20f_material_locomotion.ps1"
$falseClaims = @(
    "exact_finite_godot_jolt_bw19v_b_material_acceptance",
    "walking_acceptance_for_all_twelve_declared_treatment_cells",
    "bounded_discrete_material_robustness",
    "material_robustness",
    "continuous_friction_coverage",
    "arbitrary_material_robustness",
    "population_inference",
    "superiority",
    "noninferiority_or_equivalence",
    "rough_terrain_robustness",
    "external_push_recovery",
    "sensor_noise_or_latency_robustness",
    "cross_engine_equivalence",
    "arbitrary_quadruped_coverage",
    "continuous_full_volume_coverage",
    "release_authorized",
    "completed_engine_neutral_sdk",
    "physical_acceptance_authority"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Get-RawSha256 {
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
        (Get-RawSha256 -Path $path) -ceq
            [string]$Artifact.raw_sha256
    ) "$gateId retained $Label is missing or changed"
}

function Get-LastLoggedTorsoZ {
    param([Parameter(Mandatory)][string]$Path)
    $line = Select-String `
        -LiteralPath $Path `
        -Pattern "wave_tick=\d+ torso=" |
        Select-Object -Last 1
    Assert-Exact ($null -ne $line) "$gateId retained trace has no torso sample: $Path"
    Assert-Exact (
        $line.Line -cmatch
            "torso=\(([-0-9.]+), ([-0-9.]+), ([-0-9.]+)\)"
    ) "$gateId retained terminal torso sample cannot be parsed: $Path"
    return [double]$Matches[3]
}

Assert-Exact (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-RawSha256 -Path $closurePath) -ceq $expectedClosureSha256
) "$gateId closure is missing or changed"
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable

Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_balanced_wave_bw20f_material_locomotion_closure_v1" -and
    [string]$closure.status -ceq
        "closed_rejected_with_treatment_lateral_failures_and_control_contract_defect" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.study_classification -ceq
        "exact_finite_cell_material_acceptance_decision" -and
    [string]$closure.experiment_source_commit -ceq $sourceCommit -and
    [bool]$closure.source_was_clean_and_equal_to_origin_and_live_github_main -and
    [bool]$closure.immutability.same_identity_rerun_forbidden -and
    [bool]$closure.immutability.posthoc_pass_reclassification_forbidden -and
    [bool]$closure.control_contract_defect.present -and
    -not [bool]$closure.control_contract_defect.impact.intended_control_conformance_valid -and
    [bool]$closure.control_contract_defect.impact.treatment_negative_sufficient_for_finite_rejection
) "$gateId closure identity, disposition, or immutability changed"

& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId source commit is not retained"
& git -C $repoRoot merge-base --is-ancestor $sourceCommit HEAD
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId source is not an ancestor of HEAD"
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId origin/main could not be resolved"
& git -C $repoRoot merge-base --is-ancestor $sourceCommit $originMain
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId source is not retained on origin/main"

foreach ($binding in @($closure.frozen_source_blobs.Values)) {
    $relativePath = [string]$binding.path
    $blobOid = (& git -C $repoRoot rev-parse (
        "$sourceCommit`:$relativePath"
    )).Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        $blobOid -ceq [string]$binding.git_blob_oid -and
        [string]$binding.raw_sha256 -cmatch "^[0-9a-f]{64}$"
    ) "$gateId frozen Git blob changed: $relativePath"
    # raw_sha256 is the immutable historical checkout receipt. The retained
    # Git object above is source authority; today's checkout/filter state is
    # not evidence of bytes that existed when this campaign was frozen.
}

$semanticReference = $closure.control_contract_defect.preexisting_zero_scale_semantics_reference
$semanticReferenceRelativePath = [string]$semanticReference.path
$semanticBlobSpec = "$sourceCommit`:$semanticReferenceRelativePath"
$semanticReferenceSource = (& git -C $repoRoot show $semanticBlobSpec | Out-String)
Assert-Exact (
    $semanticReferenceSource.Contains(
        "-not [bool]`$result.combined_application_gate_passed",
        [StringComparison]::Ordinal
    )
) "$gateId pre-existing zero-scale control semantics changed"
$semanticBlobOid = (& git -C $repoRoot rev-parse (
    $semanticBlobSpec
)).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $semanticBlobOid -ceq
        [string]$semanticReference.git_blob_oid_at_experiment_source
) "$gateId zero-scale semantic reference blob changed"

$evidenceRoot = [System.IO.Path]::GetFullPath(
    [string]$closure.retained_evidence.root
)
Assert-Exact (
    $evidenceRoot -ceq
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "balanced-wave-bw20f-material-locomotion-452c11d"
) "$gateId retained evidence root changed"
foreach ($entry in $closure.retained_evidence.GetEnumerator()) {
    if ($entry.Key -ceq "root") {
        continue
    }
    Assert-HashedArtifact `
        -Root $evidenceRoot `
        -Artifact $entry.Value `
        -Label ([string]$entry.Key)
}

$attemptPath = Join-Path $evidenceRoot "attempt.json"
$completionPath = Join-Path $evidenceRoot "completion.json"
$evaluationPath = Join-Path $evidenceRoot "evaluation.json"
$rawResultPath = Join-Path $evidenceRoot "raw-result.json"
$reportPath = Join-Path $evidenceRoot "report.json"
$attempt = Get-Content -Raw -LiteralPath $attemptPath |
    ConvertFrom-Json -AsHashtable
$completion = Get-Content -Raw -LiteralPath $completionPath |
    ConvertFrom-Json -AsHashtable
$evaluation = Get-Content -Raw -LiteralPath $evaluationPath |
    ConvertFrom-Json -AsHashtable
$rawResult = Get-Content -Raw -LiteralPath $rawResultPath |
    ConvertFrom-Json -AsHashtable
$report = Get-Content -Raw -LiteralPath $reportPath |
    ConvertFrom-Json -AsHashtable

Assert-Exact (
    [string]$attempt.schema_version -ceq
        "sporespore_balanced_wave_bw20f_material_locomotion_attempt_v1" -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.origin_main_commit -ceq $sourceCommit -and
    [string]$attempt.remote_main_commit -ceq $sourceCommit -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [bool]$attempt.complete_zero_world_gate_passed -and
    [bool]$attempt.entrypoint_preflight_passed -and
    [int]$attempt.expected_gate_count -eq 28 -and
    [int]$attempt.expected_world_count -eq 17 -and
    @($attempt.ordered_cell_ids).Count -eq 17 -and
    [bool]$attempt.physical_identity_consumed -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    -not [bool]$attempt.physical_acceptance_authority
) "$gateId retained attempt changed"

Assert-Exact (
    [string]$completion.schema_version -ceq
        "sporespore_balanced_wave_bw20f_material_locomotion_completion_v1" -and
    [string]$completion.campaign_id -ceq $campaignId -and
    [string]$completion.gate_id -ceq $gateId -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [string]$completion.report_path -ceq "report.json" -and
    [string]$completion.report_raw_sha256 -ceq
        [string]$closure.retained_evidence.primary_report.raw_sha256 -and
    -not [bool]$completion.accepted -and
    [int]$completion.expected_world_count -eq 17 -and
    [int]$completion.attempted_world_count -eq 17 -and
    [int]$completion.passed_gate_count -eq 19 -and
    [int]$completion.failed_gate_count -eq 9 -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.physical_acceptance_authority
) "$gateId retained completion changed"

Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_balanced_wave_bw20f_material_locomotion_report_v1" -and
    [string]$report.campaign_id -ceq $campaignId -and
    [string]$report.gate_id -ceq $gateId -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [bool]$report.source_worktree_clean -and
    [bool]$report.source_matches_live_github_main -and
    [bool]$report.first_complete_result_final_for_source_identity -and
    -not [bool]$report.accepted -and
    [string]$report.result_status -ceq
        "rejected_exact_finite_material_locomotion" -and
    [string]$report.attempt_raw_sha256 -ceq
        [string]$closure.retained_evidence.attempt.raw_sha256 -and
    [string]$report.raw_result_raw_sha256 -ceq
        [string]$closure.retained_evidence.raw_result.raw_sha256 -and
    [string]$report.evaluation_raw_sha256 -ceq
        [string]$closure.retained_evidence.evaluation.raw_sha256 -and
    [string]$report.preflight_transcript_raw_sha256 -ceq
        [string]$closure.retained_evidence.preflight_transcript.raw_sha256 -and
    -not [bool]$report.physical_acceptance_authority
) "$gateId retained report identity or artifact binding changed"

$cellAttempts = @($report.cell_attempts)
Assert-Exact ($cellAttempts.Count -eq 17) "$gateId must retain 17 cell attempts"
$zeroExitCount = 0
$oneExitCount = 0
foreach ($cellAttempt in $cellAttempts) {
    Assert-Exact (
        [int]$cellAttempt.ordinal -ge 1 -and
        [int]$cellAttempt.ordinal -le 17 -and
        -not [bool]$cellAttempt.timed_out -and
        -not [bool]$cellAttempt.killed_process_tree -and
        [bool]$cellAttempt.receipt_parsed -and
        [string]$cellAttempt.receipt_parse_error -ceq ""
    ) "$gateId retained cell attempt integrity changed"
    if ([int]$cellAttempt.process_exit_code -eq 0) {
        $zeroExitCount += 1
    } elseif ([int]$cellAttempt.process_exit_code -eq 1) {
        $oneExitCount += 1
    } else {
        throw "$gateId retained an unexpected cell exit code"
    }
    foreach ($artifactName in @("transcript", "stderr", "engine_log")) {
        $relativePath = [string]$cellAttempt["${artifactName}_path"]
        $expectedHash = [string]$cellAttempt["${artifactName}_raw_sha256"]
        Assert-Exact (
            (Get-RawSha256 -Path (Join-Path $evidenceRoot $relativePath)) -ceq
                $expectedHash
        ) "$gateId retained cell $artifactName changed: $($cellAttempt.cell_id)"
    }
}
Assert-Exact (
    $zeroExitCount -eq 11 -and $oneExitCount -eq 6
) "$gateId retained cell exit partition changed"

Assert-Exact (
    [string]$rawResult.schema_version -ceq
        "sporespore_balanced_wave_bw20f_material_locomotion_result_v1" -and
    [string]$rawResult.campaign_id -ceq $campaignId -and
    [string]$rawResult.gate_id -ceq $gateId -and
    [int]$rawResult.expected_gate_count -eq 28 -and
    [int]$rawResult.expected_world_count -eq 17 -and
    [int]$rawResult.observed_world_count -eq 17 -and
    [int]$rawResult.integrity_failure_count -eq 0 -and
    [string]$rawResult.source.commit -ceq $sourceCommit -and
    [bool]$rawResult.source.worktree_clean -and
    [bool]$rawResult.source.matches_live_github_main -and
    [string]$rawResult.engine.physics_engine -ceq "Jolt Physics" -and
    [int]$rawResult.engine.physics_hz -eq 120
) "$gateId retained raw result identity or integrity changed"

. (Join-Path $sdkRoot "balanced_wave_bw20f_material_locomotion_gate.ps1")
$reconstructed = Test-Bw20fMaterialLocomotionResult -Result $rawResult
$failedGateIds = @(
    $reconstructed.gates |
        Where-Object { -not [bool]$_.passed } |
        ForEach-Object { [string]$_.gate_id }
)
$expectedFailedGateIds = @(
    "cell_validation_mu009_s23001_control",
    "cell_validation_mu037_s23001_control",
    "cell_validation_mu076_s23001_treatment",
    "cell_validation_mu076_s23001_control",
    "cell_validation_mu076_s23003_treatment",
    "cell_validation_mu118_s23001_control",
    "matrix_cardinality",
    "treatment_walking",
    "control_mechanism"
)
Assert-Exact (
    -not [bool]$reconstructed.ok -and
    [int]$reconstructed.reconstructed_passed_gate_count -eq 19 -and
    [int]$reconstructed.reconstructed_failed_gate_count -eq 9 -and
    [int]$reconstructed.observed_world_count -eq 17 -and
    [int]$reconstructed.cell_pass_count -eq 11 -and
    [int]$reconstructed.pair_identity_pass_count -eq 4 -and
    ($failedGateIds -join "|") -ceq ($expectedFailedGateIds -join "|") -and
    -not [bool]$reconstructed.physical_acceptance_authority
) "$gateId frozen evaluation changed"
Assert-Exact (
    (Get-RawSha256 -Path $evaluationPath) -ceq
        [string]$closure.retained_evidence.evaluation.raw_sha256 -and
    [int]$evaluation.reconstructed_passed_gate_count -eq 19 -and
    [int]$evaluation.reconstructed_failed_gate_count -eq 9 -and
    ($failedGateIds -join "|") -ceq (
        @(
            $evaluation.gates |
                Where-Object { -not [bool]$_.passed } |
                ForEach-Object { [string]$_.gate_id }
        ) -join "|"
    )
) "$gateId retained and reconstructed evaluations diverged"

$cells = @($rawResult.cells)
$treatments = @($cells | Where-Object { [string]$_.role -ceq "treatment" })
$controls = @($cells | Where-Object { [string]$_.role -ceq "control" })
$safety = @($cells | Where-Object { [string]$_.role -ceq "safety" })
Assert-Exact (
    $cells.Count -eq 17 -and
    $treatments.Count -eq 12 -and
    $controls.Count -eq 4 -and
    $safety.Count -eq 1
) "$gateId retained role cardinality changed"

foreach ($cell in $treatments) {
    Assert-Exact (
        [bool]$cell.common_execution_integrity -and
        [bool]$cell.mechanism_gate_passed -and
        [bool]$cell.combined_application_gate_passed -and
        [double]$cell.global_requested_correction_scale -eq 0.5 -and
        [int]$cell.sdk_effective_application_count -gt 0 -and
        [bool]$cell.physical_influence -and
        [int]$cell.sdk_mismatch_count -eq 0 -and
        [int]$cell.sdk_failure_count -eq 0
    ) "$gateId retained treatment mechanism changed: $($cell.cell_id)"
}
$walkingTreatments = @($treatments | Where-Object { [bool]$_.walking_observed })
$failedTreatments = @($treatments | Where-Object { -not [bool]$_.walking_observed })
Assert-Exact (
    $walkingTreatments.Count -eq 10 -and
    $failedTreatments.Count -eq 2 -and
    (@($failedTreatments | ForEach-Object { [string]$_.cell_id }) -join "|") -ceq
        "validation_mu076_s23001_treatment|validation_mu076_s23003_treatment"
) "$gateId retained treatment walking vector changed"
foreach ($cell in $failedTreatments) {
    $failedWalkingGates = @(
        $cell.walking_gate_receipts.GetEnumerator() |
            Where-Object { -not [bool]$_.Value } |
            ForEach-Object { [string]$_.Key }
    )
    Assert-Exact (
        ($failedWalkingGates -join "|") -ceq "bounded_lateral_drift"
    ) "$gateId treatment failure mechanism changed: $($cell.cell_id)"
}
$profilePassVector = @()
foreach ($friction in @(0.09, 0.37, 0.76, 1.18)) {
    $profile = @($treatments | Where-Object {
        [double]$_.authored_friction -eq $friction
    })
    $profilePassVector += @($profile | Where-Object {
        [bool]$_.walking_observed
    }).Count
}
Assert-Exact (
    ($profilePassVector -join "|") -ceq "3|3|1|3"
) "$gateId retained per-profile treatment vector changed"

foreach ($cell in $controls) {
    Assert-Exact (
        [bool]$cell.common_execution_integrity -and
        [bool]$cell.mechanism_gate_passed -and
        [double]$cell.global_requested_correction_scale -eq 0.0 -and
        [int]$cell.sdk_effective_application_count -eq 0 -and
        [double]$cell.maximum_absolute_applied_velocity_rad_s -eq 0.0 -and
        -not [bool]$cell.combined_application_gate_passed -and
        [bool]$cell.physical_influence -and
        [int]$cell.sdk_native_motor_write_count -gt 0 -and
        [int]$cell.sdk_mismatch_count -eq 0 -and
        [int]$cell.sdk_failure_count -eq 0
    ) "$gateId retained zero-scale control semantics changed: $($cell.cell_id)"
}
Assert-Exact (
    @($controls | Where-Object { [bool]$_.walking_observed }).Count -eq 3 -and
    @($controls | Where-Object { -not [bool]$_.walking_observed }).Count -eq 1
) "$gateId retained descriptive control walking vector changed"

$safetyCell = $safety[0]
Assert-Exact (
    [string]$safetyCell.cell_id -ceq "negative_mu000_s23001_safety" -and
    [bool]$safetyCell.common_execution_integrity -and
    [bool]$safetyCell.role_gate_passed -and
    [int]$safetyCell.world_build_count -eq 1 -and
    [int]$safetyCell.sdk_native_motor_write_count -eq 0 -and
    [int]$safetyCell.sdk_effective_application_count -eq 0 -and
    -not [bool]$safetyCell.physical_influence -and
    -not [bool]$safetyCell.walking_claim_authorized
) "$gateId retained zero-friction safety result changed"

$traceZByCell = @{
    "validation_mu076_s23001_treatment" = 0.176977
    "validation_mu076_s23003_treatment" = 0.152509
    "validation_mu076_s23001_control" = 0.124391
}
foreach ($cellId in $traceZByCell.Keys) {
    $cellAttempt = $cellAttempts | Where-Object {
        [string]$_.cell_id -ceq $cellId
    } | Select-Object -First 1
    $observedZ = Get-LastLoggedTorsoZ -Path (
        Join-Path $evidenceRoot ([string]$cellAttempt.transcript_path)
    )
    Assert-Exact (
        [math]::Abs($observedZ - [double]$traceZByCell[$cellId]) -le 0.0000005 -and
        [math]::Abs($observedZ) -gt 0.1
    ) "$gateId retained lateral-failure trace changed: $cellId"
}

foreach ($claim in $falseClaims) {
    Assert-Exact (
        $closure.claims.Contains($claim) -and
        -not [bool]$closure.claims[$claim] -and
        $evaluation.claims_if_accepted.Contains($claim) -and
        -not [bool]$evaluation.claims_if_accepted[$claim]
    ) "$gateId unsupported claim became true: $claim"
}

$rerunOutputRoot = Join-Path (
    Split-Path -Parent $evidenceRoot
) "balanced-wave-bw20f-material-locomotion-closure-rerun-canary"
Assert-Exact (
    -not (Test-Path -LiteralPath $rerunOutputRoot)
) "$gateId closure rerun canary path already exists"
$rerunOutput = (& pwsh `
    -NoLogo `
    -NoProfile `
    -File $runnerPath `
    -RunPhysical `
    -OutputRoot $rerunOutputRoot 2>&1 | Out-String)
$rerunExitCode = $LASTEXITCODE
Assert-Exact (
    $rerunExitCode -ne 0 -and
    $rerunOutput.Contains(
        "$gateId campaign is already closed and may not rerun",
        [StringComparison]::Ordinal
    ) -and
    -not (Test-Path -LiteralPath $rerunOutputRoot)
) "$gateId closed-state rerun interlock failed"

Write-Host (
    "BW20F-LOCOMOTION CLOSURE_PASS status=rejected gates=19/28 " +
    "worlds=17 treatments_walking=10/12 controls_walking=3/4 " +
    "integrity_failures=0 treatment_lateral_failures=2 " +
    "control_contract_valid=False safety=True rerun_refused=True " +
    "material_robustness=False physical_authority=False"
)

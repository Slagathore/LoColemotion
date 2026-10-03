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
$evidenceRootPath = [System.IO.Path]::GetFullPath($EvidenceRoot)
$outputPath = [System.IO.Path]::GetFullPath($Output)
$experimentSourceCommit = "40021c84f3d5a3aa8116c8711e83545810031624"
$baseControllerPolicyId = "sporespore_balanced_wave_bw5r_b_v1"
$preregistrationPath = Join-Path $sdkRoot "balanced_wave_bw11r_preregistration.json"
$physicalRigPath = Join-Path (
    $repoRoot
) "scripts\lab\gait\physical_wave_gait_quadruped.gd"
$preregistrationSha256 =
    "b52ac012e67668b050342746fc2415f0c81eff19f027deb6b1d09e476023ec5d"
$physicalRigSha256 =
    "d9ea2f0396f6adb8a2c8bee6de301d4f6695cbe7a010b5ac8dfb0bd4f0d3fe89"
$familyLogRelativePath = "balanced-wave-bw11r-family-run-40021c8.log"
$familyLogSha256 =
    "4e877eb3f829d1e9a8ef83273d818c631b93aa62371deed6d40f15c3156f98a5"
$selectorLogRelativePath =
    "balanced-wave-bw11r-selector-contract-refusal-40021c8.log"
$selectorLogSha256 =
    "3b3eee15c4bd4295473c86997039a1a5ef0ed8bc6a70227fb809f5d424468033"
$selectorError =
    "BW11R-A report is incomplete or source/identity mismatched"
$expectedCellIds = @(
    "fresh_baseline_s26001",
    "fresh_baseline_s26002",
    "fresh_baseline_s26003",
    "fresh_baseline_s26004",
    "fresh_baseline_s26005",
    "fresh_baseline_s26006",
    "fresh_rough_s26001",
    "fresh_rough_s26002",
    "fresh_rough_s26003",
    "fresh_rough_s26004",
    "fresh_rough_s26005",
    "fresh_rough_s26006"
)
$expected = [ordered]@{
    "BW11R-A" = [ordered]@{
        relative_path = "balanced-wave-bw11r-a-40021c8\report.json"
        report_sha256 =
            "920b3ee724f1f69fef4064600ede0d44fdf1d99474471a0257864aea8ff17adf"
        policy_id = "sporespore_scheduled_load_transfer_bw11r_a_v3"
        policy_digest =
            "sha256:673814d0d90499bac22c05b98af99097dfcc121cb0fcce896b9a9d0b419fcc58"
        development_selectable = $false
        passed_gate_count = 7
        failed_gate_count = 16
    }
    "BW11R-B" = [ordered]@{
        relative_path = "balanced-wave-bw11r-b-40021c8\report.json"
        report_sha256 =
            "528a83719b9a6418ee4a2ca75218730204aeee3f17a71089261d6b2fa5561c63"
        policy_id = "sporespore_scheduled_load_transfer_bw11r_b_v3"
        policy_digest =
            "sha256:38301e919b9a81cac8e75ba571b6941440539f25be3d3964f45236e47448c0d2"
        development_selectable = $false
        passed_gate_count = 6
        failed_gate_count = 17
    }
    "BW11R-C" = [ordered]@{
        relative_path = "balanced-wave-bw11r-c-40021c8\report.json"
        report_sha256 =
            "c6ffe2b8b462c3e498e985a8fe66eb06766bbe9290884bad35d8cb2fa9bc2567"
        policy_id = "sporespore_scheduled_load_transfer_bw11r_c_v3"
        policy_digest =
            "sha256:7ed6d5a0a15dc6547655760878a5f5e3d0cc7b4b1a04946db77c0694394f9d85"
        development_selectable = $false
        passed_gate_count = 6
        failed_gate_count = 17
    }
    "BW11R-D" = [ordered]@{
        relative_path = "balanced-wave-bw11r-d-40021c8\report.json"
        report_sha256 =
            "cbfd525f55fb1d4508d7f932a9f4df65a6682a78e0a7f98ee1389bb57b45746b"
        policy_id = "sporespore_scheduled_load_transfer_bw11r_d_v3"
        policy_digest =
            "sha256:edb4469fcd961c86374fb987a6fd7046acc14fd2d575a9c8d9a18d85dcb9c533"
        development_selectable = $false
        passed_gate_count = 6
        failed_gate_count = 17
    }
}

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
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

Assert-Exact (
    [System.IO.Path]::GetFileName($outputPath) -ceq "report.json"
) "The retained BW11R closure filename must be exactly report.json"
Assert-Exact (
    -not (Test-Path -LiteralPath $outputPath)
) "Refusing to overwrite a BW11R closure report: $outputPath"
$outputDirectory = Split-Path -Parent $outputPath
if (Test-Path -LiteralPath $outputDirectory) {
    Assert-Exact (
        @(Get-ChildItem -LiteralPath $outputDirectory -Force).Count -eq 0
    ) "Refusing a nonempty BW11R closure directory: $outputDirectory"
}

$sourceStatus = @(
    & git -C $repoRoot status --porcelain=v1 --untracked-files=all
)
Assert-Exact (
    $LASTEXITCODE -eq 0 -and $sourceStatus.Count -eq 0
) "BW11R zero-world closure requires a clean worktree"
$compilerCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0 -and $compilerCommit -ceq $originMain
) "BW11R zero-world closure requires HEAD exactly matching origin/main"
& git -C $repoRoot merge-base --is-ancestor `
    $experimentSourceCommit $compilerCommit
Assert-Exact (
    $LASTEXITCODE -eq 0
) "The closure compiler must descend from the BW11R experiment source"

Assert-Exact (
    (Get-Sha256 $preregistrationPath) -ceq $preregistrationSha256
) "The BW11R preregistration bytes changed after execution"
Assert-Exact (
    (Get-Sha256 $physicalRigPath) -ceq $physicalRigSha256
) "The BW11R physical-entrypoint source changed before closure"
$physicalRigSource = Get-Content -LiteralPath $physicalRigPath -Raw
foreach ($candidateId in $expected.Keys) {
    Assert-Exact (
        -not $physicalRigSource.Contains([string]$expected[$candidateId].policy_id)
    ) "The frozen BW11R rig unexpectedly contains $candidateId"
}
Assert-Exact (
    $physicalRigSource.Contains(
        "const SDK_STABILITY_FEEDBACK_AUTHORITY_POLICY_IDS := ["
    ) -and
    $physicalRigSource.Contains(
        "and not SDK_STABILITY_FEEDBACK_AUTHORITY_POLICY_IDS.has("
    ) -and
    $physicalRigSource.Contains(
        '"failure_code": "INVALID_SDK_AUTHORITY_OPTION_VALUE"'
    )
) "The source-audited physical-entrypoint failure boundary is not exact"

$familyLogPath = Join-Path $evidenceRootPath $familyLogRelativePath
$selectorLogPath = Join-Path $evidenceRootPath $selectorLogRelativePath
Assert-Exact (
    (Test-Path -LiteralPath $familyLogPath -PathType Leaf) -and
    (Get-Sha256 $familyLogPath) -ceq $familyLogSha256
) "The retained BW11R family log is missing or byte-mismatched"
Assert-Exact (
    (Test-Path -LiteralPath $selectorLogPath -PathType Leaf) -and
    (Get-Sha256 $selectorLogPath) -ceq $selectorLogSha256
) "The retained BW11R selector-refusal log is missing or byte-mismatched"
$selectorLogText = Get-Content -LiteralPath $selectorLogPath -Raw
Assert-Exact (
    $selectorLogText.Contains($selectorError)
) "The retained selector log does not contain the exact refusal"

$candidateReceipts = @()
$inputs = @()
$reportedCellReceiptCount = 0
$actualWorldBuildCount = 0
$physicalOutcomeCount = 0
$integrityFailureCount = 0
$acquisitionFailureCount = 0
$mechanismFailureCount = 0
$sdkStepReceiptCount = 0
foreach ($candidateId in $expected.Keys) {
    $identity = $expected[$candidateId]
    $path = Join-Path $evidenceRootPath ([string]$identity.relative_path)
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "Missing retained $candidateId report: $path"
    Assert-Exact (
        (Get-Sha256 $path) -ceq [string]$identity.report_sha256
    ) "$candidateId report bytes do not match the frozen result"
    $report = Get-Content -LiteralPath $path -Raw |
        ConvertFrom-Json -AsHashtable
    $cells = @($report.receipt.cells)
    $candidateActualWorlds = 0
    $candidatePhysicalOutcomes = 0
    $candidateSdkSteps = 0
    $observedCellIds = @()
    foreach ($cell in $cells) {
        $observedCellIds += [string]$cell.cell_id
        $candidateActualWorlds += [int]$cell.world_build_count
        if (
            [int]$cell.world_build_count -gt 0 -or
            [int]$cell.step_count -ge 0 -or
            [bool]$cell.diagnostic_execution_complete -or
            [bool]$cell.walking_observed
        ) {
            $candidatePhysicalOutcomes += 1
        }
        if ([int]$cell.balanced_wave_step_receipt_count -gt 0) {
            $candidateSdkSteps += [int]$cell.balanced_wave_step_receipt_count
        }
        Assert-Exact (
            [int]$cell.world_build_count -eq 0 -and
            [int]$cell.step_count -eq -1 -and
            [int]$cell.balanced_wave_step_receipt_count -eq -1 -and
            -not [bool]$cell.diagnostic_execution_complete -and
            -not [bool]$cell.challenge_options_exact -and
            -not [bool]$cell.evidence_acquisition_gate_passed -and
            -not [bool]$cell.scheduled_load_transfer_gate_passed -and
            -not [bool]$cell.campaign_execution_gate_passed -and
            -not [bool]$cell.common_execution_integrity -and
            -not [bool]$cell.walking_observed -and
            @($cell.scheduled_load_transfer_summary.Keys).Count -eq 0 -and
            [string]$cell.sdk_failure_code -ceq ""
        ) "$candidateId $([string]$cell.cell_id) is not the exact zero-world receipt"
    }
    Assert-Exact (
        [string]$report.schema_version -ceq
            "sporespore_balanced_wave_bw11r_development_report_v1" -and
        [string]$report.source_commit -ceq $experimentSourceCommit -and
        [bool]$report.source_worktree_clean -and
        [bool]$report.source_matches_origin_main -and
        [bool]$report.development_data_only -and
        -not [bool]$report.complete -and
        [string]$report.result_status -ceq "incomplete" -and
        [string]$report.candidate_id -ceq $candidateId -and
        [string]$report.policy_id -ceq [string]$identity.policy_id -and
        [string]$report.base_controller_policy_id -ceq
            $baseControllerPolicyId -and
        [string]$report.candidate_policy_digest -ceq
            [string]$identity.policy_digest -and
        [bool]$report.development_selectable -eq
            [bool]$identity.development_selectable -and
        [int]$report.godot_exit_code -eq 1 -and
        [bool]$report.all_preflight_processes_passed -and
        [int]$report.preflight_actual_world_count -eq 0 -and
        [string]$report.receipt.schema_version -ceq
            "sporespore_balanced_wave_bw11r_development_receipt_v1" -and
        -not [bool]$report.receipt.ok -and
        [bool]$report.receipt.full_gate_satisfiability_ok -and
        [int]$report.receipt.expected_gate_count -eq 23 -and
        [int]$report.receipt.expected_world_count -eq 12 -and
        [int]$report.receipt.observed_world_count -eq 12 -and
        $cells.Count -eq 12 -and
        ($observedCellIds -join ",") -ceq ($expectedCellIds -join ",") -and
        [int]$report.receipt.passed_gate_count -eq
            [int]$identity.passed_gate_count -and
        [int]$report.receipt.failed_gate_count -eq
            [int]$identity.failed_gate_count -and
        [int]$report.receipt.integrity_failure_count -eq 12 -and
        [int]$report.receipt.acquisition_failure_count -eq 12 -and
        [int]$report.receipt.mechanism_receipt_failure_count -eq 12 -and
        [int]$report.receipt.ordinary_nonwalk_count -eq 12 -and
        [int]$report.receipt.release_timeout_count -eq 0 -and
        $candidateActualWorlds -eq 0 -and
        $candidatePhysicalOutcomes -eq 0 -and
        $candidateSdkSteps -eq 0 -and
        [string]$report.sources.preregistration.sha256 -ceq
            $preregistrationSha256 -and
        [string]$report.sources.physical_rig.sha256 -ceq
            $physicalRigSha256 -and
        -not [bool]$report.walking_acceptance -and
        -not [bool]$report.material_robustness -and
        -not [bool]$report.rough_terrain_robustness -and
        -not [bool]$report.physical_balance_recovery -and
        -not [bool]$report.fresh_morphology_validation -and
        -not [bool]$report.cross_engine_c6 -and
        -not [bool]$report.completed_engine_neutral_sdk -and
        -not [bool]$report.physical_acceptance_authority
    ) "$candidateId does not match the exact retained zero-world result"
    $candidateReceipts += [ordered]@{
        candidate_id = $candidateId
        policy_id = [string]$identity.policy_id
        candidate_policy_digest = [string]$identity.policy_digest
        reported_cell_receipt_count = 12
        actual_world_build_count = $candidateActualWorlds
        physical_outcome_count = $candidatePhysicalOutcomes
        sdk_step_receipt_count = $candidateSdkSteps
        complete = $false
        passed_gate_count = [int]$identity.passed_gate_count
        failed_gate_count = [int]$identity.failed_gate_count
        integrity_failure_count = 12
        acquisition_failure_count = 12
        mechanism_receipt_failure_count = 12
    }
    $inputs += [ordered]@{
        candidate_id = $candidateId
        path = $path
        sha256 = [string]$identity.report_sha256
    }
    $reportedCellReceiptCount += 12
    $actualWorldBuildCount += $candidateActualWorlds
    $physicalOutcomeCount += $candidatePhysicalOutcomes
    $integrityFailureCount += 12
    $acquisitionFailureCount += 12
    $mechanismFailureCount += 12
    $sdkStepReceiptCount += $candidateSdkSteps
}

Assert-Exact (
    $reportedCellReceiptCount -eq 48 -and
    $actualWorldBuildCount -eq 0 -and
    $physicalOutcomeCount -eq 0 -and
    $integrityFailureCount -eq 48 -and
    $acquisitionFailureCount -eq 48 -and
    $mechanismFailureCount -eq 48 -and
    $sdkStepReceiptCount -eq 0
) "BW11R aggregate zero-world closure counts are not exact"

$reportObject = [ordered]@{
    schema_version =
        "sporespore_balanced_wave_bw11r_zero_world_negative_closure_report_v1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    experiment_source_commit = $experimentSourceCommit
    compiler_commit = $compilerCommit
    source_worktree_clean = $true
    source_matches_origin_main = $true
    development_data_only = $true
    result_status =
        "candidate_family_invalidated_before_physics_by_entrypoint_policy_allowlist"
    attempted_candidate_count = 4
    attempted_cell_count = 48
    reported_cell_receipt_count = $reportedCellReceiptCount
    actual_world_build_count = $actualWorldBuildCount
    physical_outcome_count = $physicalOutcomeCount
    sdk_step_receipt_count = $sdkStepReceiptCount
    complete_candidate_count = 0
    integrity_failure_count = $integrityFailureCount
    acquisition_failure_count = $acquisitionFailureCount
    mechanism_receipt_failure_count = $mechanismFailureCount
    misleading_legacy_field_notice =
        "The candidate reports' observed_world_count counts retained attempted-cell receipts, not constructed physics worlds."
    root_cause = [ordered]@{
        classification =
            "source_audited_upstream_physical_entrypoint_policy_rejection"
        failure =
            "The physical entrypoint's frozen stability-policy allowlist omitted every BW11R v3 policy, so _normalize_sdk_authority_options returned INVALID_SDK_AUTHORITY_OPTION_VALUE before world construction."
        missing_cell_failure_code =
            "The early physical-entrypoint failure_code was not propagated into the retained per-cell sdk_failure_code field; the exact source bytes, zero-world receipts, and process failure establish the boundary."
        required_successor_boundary =
            "Before an evidence directory or physics world can be created, every declared policy must pass the real physical-entrypoint normalization/start path and the entire production integrity gate against a policy-derived perfect synthetic receipt."
    }
    frozen_selector_invoked = $true
    frozen_selector_refused_input = $true
    frozen_selector_error = $selectorError
    selection_performed = $false
    family_selected = $false
    selected_candidate_id = $null
    physical_observations_ranked = $false
    candidate_receipts = $candidateReceipts
    inputs = $inputs
    retained_logs = @(
        [ordered]@{
            role = "family_run"
            path = $familyLogPath
            sha256 = $familyLogSha256
        },
        [ordered]@{
            role = "selector_contract_refusal"
            path = $selectorLogPath
            sha256 = $selectorLogSha256
            exact_error = $selectorError
        }
    )
    frozen_sources = @(
        [ordered]@{
            role = "preregistration"
            path = "sdk/balanced_wave_bw11r_preregistration.json"
            sha256 = $preregistrationSha256
        },
        [ordered]@{
            role = "physical_entrypoint"
            path = "scripts/lab/gait/physical_wave_gait_quadruped.gd"
            sha256 = $physicalRigSha256
        }
    )
    immutability = [ordered]@{
        bw11r_repair_or_rerun_forbidden = $true
        attempted_cell_deletion_replacement_or_averaging_forbidden = $true
        threshold_relaxation_or_gate_deletion_forbidden = $true
        new_successor_identity_required = $true
    }
    independent_validation_reservation_opened = $false
    cold_unbiased_friction_reservation_opened = $false
    development_selection_authority = $false
    walking_acceptance = $false
    balance_improvement = $false
    material_robustness = $false
    rough_terrain_robustness = $false
    physical_balance_recovery = $false
    fresh_morphology_validation = $false
    cross_engine_c6 = $false
    completed_engine_neutral_sdk = $false
    physical_acceptance_authority = $false
}
[void][System.IO.Directory]::CreateDirectory($outputDirectory)
$temporaryPath = "$outputPath.tmp"
$json = $reportObject | ConvertTo-Json -Depth 64
[System.IO.File]::WriteAllText(
    $temporaryPath,
    "$json`n",
    [System.Text.UTF8Encoding]::new($false)
)
[System.IO.File]::Move($temporaryPath, $outputPath, $false)
Write-Host "Retained BW11R zero-world negative closure: $outputPath"
Write-Host (
    "BALANCED_WAVE_BW11R_SELECTION_PERFORMED=false " +
    "FAMILY_INVALIDATED_BEFORE_PHYSICS=true " +
    "ATTEMPTED_CELLS=$reportedCellReceiptCount/48 " +
    "ACTUAL_WORLDS=$actualWorldBuildCount"
)

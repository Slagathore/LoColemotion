#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$authorityPath = Join-Path $repoRoot (
    "sdk\turning\r23d71_forward_displacement_measurement_origin_diagnosis_v1.json"
)
$diagnosticPath = Join-Path $repoRoot (
    "sdk\turning\r23d71_forward_displacement_measurement_origin_diagnostic.py"
)
$r23d71ClosureAuditPath = Join-Path $repoRoot (
    "tests\test_qsdk_r23d71_physical_closure.ps1"
)
$releaseContractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportMatrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$evidenceRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\qsdk-r23d71-physical-20260826T055614Z-f82e3454-lca1-python"
)
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$expectedDiagnosticCanonicalLfSha256 = (
    "sha256:6fb8be54586519c9bbddf9d69c9011f407f5cbd38f801b830acff6fa660739d3"
)
$expectedReceiptSha256 = (
    "sha256:ed2b6c7fb69f679feb0094ee70415ef10195625fe6eed465da0381b6fb699bd1"
)

function Assert-OriginDiagnosis([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "[turning/measurement] R23D71 origin diagnosis audit: $Message"
    }
}

function Invoke-OriginDiagnosisGit([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-OriginDiagnosis ($LASTEXITCODE -eq 0) (
        "git $($Arguments -join ' ') failed: $($lines -join ' ')"
    )
    return ($lines -join "`n").Trim()
}

function Get-OriginDiagnosisJson([string]$Path) {
    return Get-Content -LiteralPath $Path -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-OriginDiagnosisCanonicalLfIdentity([string]$Path) {
    $text = [IO.File]::ReadAllText(
        $Path,
        [Text.UTF8Encoding]::new($false, $true)
    ).Replace("`r`n", "`n").Replace("`r", "`n")
    $bytes = [Text.Encoding]::UTF8.GetBytes($text)
    return [ordered]@{
        sha256 = "sha256:" + [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($bytes)
        ).ToLowerInvariant()
        byte_length = [long]$bytes.Length
    }
}

function Copy-OriginDiagnosisObject([hashtable]$Value) {
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Assert-OriginDiagnosisShape(
    [hashtable]$Authority,
    [hashtable]$Receipt
) {
    Assert-OriginDiagnosis (
        [string]$Authority.schema_version -ceq
            "sporespore_r23d71_forward_displacement_measurement_origin_diagnosis_v1" -and
        [string]$Authority.status -ceq
            "closed_read_only_development_diagnosis_measurement_origin_mismatch_proved_physical_not_opened" -and
        [string]$Authority.ledger_scope.subsystem -ceq "turning" -and
        [string]$Authority.ledger_scope.engine_scope -ceq "3e" -and
        [string]$Authority.ledger_scope.question_class -ceq "development"
    ) "authority identity changed"

    Assert-OriginDiagnosis (
        [string]$Receipt.schema_version -ceq
            "sporespore_r23d71_forward_displacement_measurement_origin_diagnostic_v1" -and
        [string]$Receipt.status -ceq [string]$Authority.status -and
        [string]$Receipt.question_class -ceq "development" -and
        [string]$Receipt.receipt_canonical_sha256 -ceq $expectedReceiptSha256 -and
        [string]$Authority.source_authority.diagnostic_receipt_canonical_sha256 -ceq
            $expectedReceiptSha256
    ) "diagnostic receipt identity changed"

    $authorityBoundary = $Authority.immutable_r23d71_boundary
    $receiptBoundary = $Receipt.immutable_r23d71_boundary
    Assert-OriginDiagnosis (
        [string]$authorityBoundary.official_status -ceq
            "closed_consumed_invalid_complete_after_nine_native_worlds_transport_contract_and_rapier_forward_gate_failures" -and
        [string]$receiptBoundary.official_status -ceq
            [string]$authorityBoundary.official_status -and
        [string]$receiptBoundary.closure_git_blob_oid -ceq
            [string]$authorityBoundary.closure_git_blob_oid_at_diagnosed_source -and
        [string]$receiptBoundary.closure_blob_raw_sha256 -ceq
            [string]$authorityBoundary.closure_blob_raw_sha256 -and
        [string]$receiptBoundary.canonical_population_manifest_sha256 -ceq
            [string]$authorityBoundary.canonical_population_manifest_sha256 -and
        [int]$receiptBoundary.complete_file_population_count -eq 72 -and
        [long]$receiptBoundary.complete_file_population_byte_count -eq 677221819 -and
        -not [bool]$receiptBoundary.official_result_or_interpretation_changed -and
        -not [bool]$receiptBoundary.same_identity_rerun_performed
    ) "immutable R23D71 boundary changed"

    $authorityOrigin = $Authority.measurement_origin_provenance
    $receiptOrigin = $Receipt.inherited_threshold_and_origin_provenance
    Assert-OriginDiagnosis (
        [double]$authorityOrigin.minimum_final_forward_displacement_m -eq
            0.030123046875 -and
        [double]$receiptOrigin.minimum_final_forward_displacement_m -eq
            [double]$authorityOrigin.minimum_final_forward_displacement_m -and
        [int]$receiptOrigin.evidence_start_controller_semantic_step -eq 472 -and
        [int]$receiptOrigin.turn_command_start_semantic_step -eq 600 -and
        [string]$receiptOrigin.prospective_common_measurement_origin_policy_id -ceq
            "evidence_window_start_semantic_step_v1" -and
        -not [bool]$receiptOrigin.threshold_changed -and
        [bool]$receiptOrigin.task_frame_reanchors_remain_controller_path_state_only
    ) "threshold or measurement-origin provenance changed"

    $authorityRapier = $Authority.observations.rapier_parry
    $receiptRapier = $Receipt.engine_diagnostics.rapier_parry
    Assert-OriginDiagnosis (
        [double]$receiptRapier.arms.reference_zero.historical_terminal_final_forward_displacement_m -eq
            [double]$authorityRapier.historical_final_forward_displacement_m.reference_zero -and
        [double]$receiptRapier.arms.positive_heading.historical_terminal_final_forward_displacement_m -eq
            [double]$authorityRapier.historical_final_forward_displacement_m.positive_heading -and
        [double]$receiptRapier.arms.negative_heading.historical_terminal_final_forward_displacement_m -eq
            [double]$authorityRapier.historical_final_forward_displacement_m.negative_heading -and
        [double]$receiptRapier.arms.reference_zero.prospective_evidence_origin_reconstruction_m -eq
            [double]$authorityRapier.prospective_evidence_window_origin_reconstruction_m.reference_zero -and
        [double]$receiptRapier.arms.positive_heading.prospective_evidence_origin_reconstruction_m -eq
            [double]$authorityRapier.prospective_evidence_window_origin_reconstruction_m.positive_heading -and
        [double]$receiptRapier.arms.negative_heading.prospective_evidence_origin_reconstruction_m -eq
            [double]$authorityRapier.prospective_evidence_window_origin_reconstruction_m.negative_heading -and
        [bool]$receiptRapier.posthoc_cycle_integrated_directional_response_passed -and
        [bool]$Receipt.diagnosis.rapier_all_other_common_physical_gates_pass_posthoc
    ) "Rapier retained observation changed"

    $authorityRapierCycle = $authorityRapier.posthoc_unchanged_cycle_measurement
    $receiptRapierCycle = $receiptRapier.posthoc_cycle_integrated_measurement
    Assert-OriginDiagnosis (
        [double]$receiptRapierCycle.positive_reference_conditioned_cycle_shift_rad -eq
            [double]$authorityRapierCycle.positive_reference_conditioned_cycle_shift_rad -and
        [double]$receiptRapierCycle.negative_reference_conditioned_cycle_shift_rad -eq
            [double]$authorityRapierCycle.negative_reference_conditioned_cycle_shift_rad -and
        [double]$receiptRapierCycle.bilateral_reference_conditioned_cycle_separation_rad -eq
            [double]$authorityRapierCycle.bilateral_reference_conditioned_cycle_separation_rad -and
        [bool]$receiptRapierCycle.passed
    ) "Rapier cycle-integrated measurement changed"

    $authorityGodot = $Authority.observations.godot_jolt
    $receiptGodot = $Receipt.engine_diagnostics.godot_jolt
    Assert-OriginDiagnosis (
        [bool]$receiptGodot.posthoc_cycle_integrated_directional_response_passed -and
        [double]$receiptGodot.posthoc_cycle_integrated_measurement.positive_reference_conditioned_cycle_shift_rad -eq
            [double]$authorityGodot.posthoc_unchanged_cycle_measurement.positive_reference_conditioned_cycle_shift_rad -and
        [double]$receiptGodot.posthoc_cycle_integrated_measurement.negative_reference_conditioned_cycle_shift_rad -eq
            [double]$authorityGodot.posthoc_unchanged_cycle_measurement.negative_reference_conditioned_cycle_shift_rad
    ) "Godot cycle-integrated observation changed"

    $authorityMujoco = $Authority.observations.mujoco
    $receiptMujoco = $Receipt.engine_diagnostics.mujoco
    Assert-OriginDiagnosis (
        -not [bool]$receiptMujoco.posthoc_cycle_integrated_directional_response_passed -and
        [int]$receiptMujoco.arms.reference_zero.first_torso_ground_contact_semantic_step -eq 146 -and
        [int]$receiptMujoco.arms.positive_heading.first_torso_ground_contact_semantic_step -eq 146 -and
        [int]$receiptMujoco.arms.negative_heading.first_torso_ground_contact_semantic_step -eq 146 -and
        [bool]$Receipt.diagnosis.mujoco_fall_precedes_turn_window_in_all_three_arms -and
        [double]$receiptMujoco.posthoc_cycle_integrated_measurement.positive_reference_conditioned_cycle_shift_rad -eq
            [double]$authorityMujoco.posthoc_unchanged_cycle_measurement.positive_reference_conditioned_cycle_shift_rad -and
        [double]$receiptMujoco.posthoc_cycle_integrated_measurement.negative_reference_conditioned_cycle_shift_rad -eq
            [double]$authorityMujoco.posthoc_unchanged_cycle_measurement.negative_reference_conditioned_cycle_shift_rad
    ) "MuJoCo retained observation changed"

    Assert-OriginDiagnosis (
        [bool]$Receipt.diagnosis.producer_measurement_origins_differ -and
        [bool]$Receipt.diagnosis.rapier_directional_response_passes_unchanged_cycle_measurement_posthoc -and
        -not [bool]$Receipt.diagnosis.rapier_locomotion_deficiency_established_by_r23d71_forward_gate -and
        -not [bool]$Receipt.diagnosis.mujoco_directional_response_passes_unchanged_cycle_measurement_posthoc -and
        [bool]$Authority.diagnosis.rapier_forward_gate_failure_is_explained_by_measurement_origin_mismatch -and
        [bool]$Authority.diagnosis.mujoco_falls_before_the_turn_window_and_fails_directional_measurement
    ) "diagnosis changed"

    foreach ($claims in @($Authority.claims, $Receipt.claims)) {
        Assert-OriginDiagnosis (
            [bool]$claims.development_diagnosis_complete -and
            -not [bool]$claims.historical_result_reinterpreted -and
            -not [bool]$claims.finite_three_engine_turning -and
            -not [bool]$claims.portable_basic_turning -and
            -not [bool]$claims.q_sdk_r23_satisfied -and
            -not [bool]$claims.cross_engine_equivalence -and
            -not [bool]$claims.population_robustness -and
            -not [bool]$claims.arbitrary_quadruped_coverage -and
            -not [bool]$claims.prone_to_standing -and
            -not [bool]$claims.physical_acceptance_authority -and
            -not [bool]$claims.release_authorized
        ) "claim boundary changed"
    }
    Assert-OriginDiagnosis (
        -not [bool]$Authority.adequacy.adequate_for_new_finite_turning_claim -and
        -not [bool]$Authority.adequacy.physical_world_opened_by_diagnosis -and
        -not [bool]$Receipt.adequacy.physical_world_opened_by_diagnostic -and
        [string]$Authority.next_work.release_score_before -ceq "10/25" -and
        [string]$Authority.next_work.release_score_after -ceq "10/25" -and
        -not [bool]$Authority.next_work.new_finite_turning_decision_authorized
    ) "adequacy, world-count, or score boundary changed"
}

Assert-OriginDiagnosis (
    (Invoke-OriginDiagnosisGit @("rev-parse", "--show-toplevel")) -ceq
        $repoRoot.Replace("\", "/")
) "repository root changed"
Assert-OriginDiagnosis (
    (Invoke-OriginDiagnosisGit @("remote", "get-url", "origin")) -ceq $expectedRemote
) "repository remote changed"
$diagnosticIdentity = Get-OriginDiagnosisCanonicalLfIdentity $diagnosticPath
Assert-OriginDiagnosis (
    [string]$diagnosticIdentity.sha256 -ceq $expectedDiagnosticCanonicalLfSha256 -and
    [long]$diagnosticIdentity.byte_length -eq 31229
) "diagnostic canonical-LF implementation identity changed"

& pwsh -NoProfile -File $r23d71ClosureAuditPath
Assert-OriginDiagnosis ($LASTEXITCODE -eq 0) "immutable R23D71 closure audit failed"

$diagnosticLines = @(
    & python -B $diagnosticPath --evidence-root $evidenceRoot 2>&1
)
Assert-OriginDiagnosis ($LASTEXITCODE -eq 0) (
    "read-only diagnostic failed: $($diagnosticLines -join ' ')"
)
$diagnosticReceipt = ($diagnosticLines -join "`n") |
    ConvertFrom-Json -AsHashtable -Depth 100
$authority = Get-OriginDiagnosisJson $authorityPath
Assert-OriginDiagnosisShape $authority $diagnosticReceipt

$authorityIdentity = Get-OriginDiagnosisCanonicalLfIdentity $authorityPath
$releaseContract = Get-OriginDiagnosisJson $releaseContractPath
$supportMatrix = Get-OriginDiagnosisJson $supportMatrixPath
$turningGates = @(
    $releaseContract.gates | Where-Object { $_.gate_id -ceq "QSDK-R23" }
)
Assert-OriginDiagnosis ($turningGates.Count -eq 1) "QSDK-R23 release gate changed"
$releaseDiagnosis = $turningGates[0].proof.current_r23d71_measurement_origin_diagnosis
$supportDiagnosis = $supportMatrix.locomotion_modes.r23d71_measurement_origin_diagnosis_v1
foreach ($projection in @($releaseDiagnosis, $supportDiagnosis)) {
    Assert-OriginDiagnosis (
        [string]$projection.diagnosis_id -ceq [string]$authority.diagnosis_id -and
        [string]$projection.status -ceq [string]$authority.status -and
        [string]$projection.question_class -ceq "development" -and
        [string]$projection.diagnosis_path -ceq
            "sdk/turning/r23d71_forward_displacement_measurement_origin_diagnosis_v1.json" -and
        [string]$projection.diagnosis_canonical_lf_sha256 -ceq
            [string]$authorityIdentity.sha256 -and
        [string]$projection.diagnostic_script_canonical_lf_sha256 -ceq
            $expectedDiagnosticCanonicalLfSha256 -and
        [string]$projection.diagnostic_receipt_canonical_sha256 -ceq
            $expectedReceiptSha256 -and
        [int]$projection.retained_trace_count -eq 9 -and
        [int]$projection.retained_trace_row_count -eq 26928 -and
        [bool]$projection.rapier_directional_cycle_measurement_passed_posthoc -and
        -not [bool]$projection.mujoco_directional_cycle_measurement_passed_posthoc -and
        -not [bool]$projection.historical_r23d71_result_changed -and
        -not [bool]$projection.physical_world_opened_by_diagnosis -and
        [string]$projection.next_work_class -ceq
            "prospective_measurement_origin_repair_then_mujoco_pre_turn_stability_development" -and
        -not [bool]$projection.new_finite_turning_decision_authorized -and
        -not [bool]$projection.q_sdk_r23_satisfied -and
        [string]$projection.release_score_after -ceq "10/25" -and
        -not [bool]$projection.release_authorized
    ) "release projection changed"
}

$mutationCount = 0
foreach ($mutation in @(
    "closure_sha",
    "evidence_origin_step",
    "threshold",
    "rapier_reconstruction",
    "rapier_cycle",
    "mujoco_contact_step",
    "finite_claim",
    "receipt_sha"
)) {
    $mutatedAuthority = Copy-OriginDiagnosisObject $authority
    $mutatedReceipt = Copy-OriginDiagnosisObject $diagnosticReceipt
    switch ($mutation) {
        "closure_sha" {
            $mutatedReceipt.immutable_r23d71_boundary.closure_blob_raw_sha256 =
                "sha256:" + "0" * 64
        }
        "evidence_origin_step" {
            $mutatedReceipt.inherited_threshold_and_origin_provenance.evidence_start_controller_semantic_step = 471
        }
        "threshold" {
            $mutatedAuthority.measurement_origin_provenance.minimum_final_forward_displacement_m = 0.0
        }
        "rapier_reconstruction" {
            $mutatedReceipt.engine_diagnostics.rapier_parry.arms.reference_zero.prospective_evidence_origin_reconstruction_m = 0.0
        }
        "rapier_cycle" {
            $mutatedReceipt.engine_diagnostics.rapier_parry.posthoc_cycle_integrated_measurement.passed = $false
        }
        "mujoco_contact_step" {
            $mutatedReceipt.engine_diagnostics.mujoco.arms.positive_heading.first_torso_ground_contact_semantic_step = 600
        }
        "finite_claim" {
            $mutatedAuthority.claims.finite_three_engine_turning = $true
        }
        "receipt_sha" {
            $mutatedReceipt.receipt_canonical_sha256 = "sha256:" + "f" * 64
        }
    }
    $rejected = $false
    try {
        Assert-OriginDiagnosisShape $mutatedAuthority $mutatedReceipt
    } catch {
        $rejected = $true
    }
    Assert-OriginDiagnosis $rejected "mutation was not rejected: $mutation"
    $mutationCount += 1
}

Assert-OriginDiagnosis ($mutationCount -eq 8) "mutation-control count changed"
Write-Host (
    "[turning/measurement] R23D71 origin diagnosis audit passed; " +
    "9/9 retained traces, pinned measurement code, 8/8 mutations rejected, " +
    "0 worlds opened, score 10/25."
)

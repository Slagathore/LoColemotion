#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$protocolPath = Join-Path $sdkRoot (
    "cross_engine_c6_bw19v_discrete_material_validation_xv2_" +
    "aggregate_recovery_protocol.json"
)
$reconstructionPath = Join-Path $sdkRoot (
    "cross_engine_c6_bw19v_discrete_material_validation_xv2_" +
    "aggregate_reconstruction.ps1"
)
$recoveryRunnerPath = Join-Path $sdkRoot (
    "run_cross_engine_c6_bw19v_discrete_material_validation_xv2_" +
    "aggregate_recovery.ps1"
)
$physicalRunnerPath = Join-Path $sdkRoot (
    "run_cross_engine_c6_bw19v_discrete_material_validation_xv2.ps1"
)
$attemptRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "c6-cross-engine-bw19v-xv2-e00ec7a"
)
$campaignId = "C6-CROSS-ENGINE-BW19V-DISCRETE-MATERIAL-VALIDATION-XV2"
$gateId = "C6-XE-BW19V-XV2"
$recoveryId = "C6-XE-BW19V-XV2-AGGREGATE-RECOVERY-R1"
$expectedProtocolSha256 = (
    "3e1bddc00f8b66ebcdd5ef2058f248db5fb0b6e186e5d3b73e8acd78a6a0f24a"
)
$expectedReconstructionSha256 = (
    "553be263687b4e7dbe3a0c791fd65c99a3410809124f40b9339ba424c70f4d60"
)
$expectedRecoveryRunnerSha256 = (
    "3f35292d74a3b07b5411c2b964c794f83c3112abe3bc3229561132b293ea5493"
)
$recoveryArtifactNames = @(
    "aggregate_recovery_attempt_v1.json",
    "aggregate_reconstruction_v1.json",
    "aggregate_reconstruction_evaluation_v1.json",
    "aggregate_recovery_completion_v1.json"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Get-EvidenceTreeSnapshot {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse)
    $entries = [ordered]@{}
    $lines = foreach ($file in @(
        $files | Sort-Object {
            $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
        }
    )) {
        $relativePath = $file.FullName.Substring(
            $Root.Length + 1
        ).Replace("\", "/")
        $digest = Get-RawSha256 $file.FullName
        $entries[$relativePath] = [ordered]@{
            size_bytes = [long]$file.Length
            raw_sha256 = $digest
        }
        "$relativePath`t$($file.Length)`t$digest"
    }
    $text = ($lines -join "`n") + "`n"
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
        entries = $entries
    }
}

function Get-LightweightEvidenceManifest {
    param([Parameter(Mandatory)][string]$Root)
    return @(
        Get-ChildItem -LiteralPath $Root -File -Recurse |
        Sort-Object FullName |
        ForEach-Object {
            $relativePath = $_.FullName.Substring(
                $Root.Length + 1
            ).Replace("\", "/")
            "$relativePath`t$($_.Length)`t$($_.LastWriteTimeUtc.Ticks)"
        }
    )
}

Assert-Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "$recoveryId repository identity changed"

foreach ($path in @(
    $protocolPath,
    $reconstructionPath,
    $recoveryRunnerPath,
    $physicalRunnerPath
)) {
    Assert-Exact (Test-Path -LiteralPath $path -PathType Leaf) (
        "$recoveryId required freeze surface is missing: $path"
    )
}
Assert-Exact (
    (Get-RawSha256 $protocolPath) -ceq $expectedProtocolSha256 -and
    (Get-RawSha256 $reconstructionPath) -ceq
        $expectedReconstructionSha256 -and
    (Get-RawSha256 $recoveryRunnerPath) -ceq
        $expectedRecoveryRunnerSha256
) "$recoveryId prospective recovery source changed"

foreach ($scriptPath in @($reconstructionPath, $recoveryRunnerPath)) {
    $tokens = $null
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile(
        $scriptPath,
        [ref]$tokens,
        [ref]$parseErrors
    ) | Out-Null
    Assert-Exact (@($parseErrors).Count -eq 0) (
        "$recoveryId PowerShell parse failure: $scriptPath"
    )
}

$protocol = Get-Content -Raw -LiteralPath $protocolPath |
    ConvertFrom-Json -AsHashtable -Depth 128
Assert-Exact (
    [string]$protocol.schema_version -ceq
        "sporespore_cross_engine_c6_bw19v_discrete_material_validation_xv2_aggregate_recovery_protocol_v1" -and
    [string]$protocol.status -ceq
        "frozen_after_physical_workers_before_zero_world_aggregate_recovery" -and
    [string]$protocol.campaign_id -ceq $campaignId -and
    [string]$protocol.gate_id -ceq $gateId -and
    [string]$protocol.recovery_id -ceq $recoveryId -and
    [bool]$protocol.not_a_new_physical_campaign -and
    [string]$protocol.pre_reservation_qualification_refusal.status -ceq
        "refused_before_operation_lock_or_create_new_reservation" -and
    [int]$protocol.pre_reservation_qualification_refusal.retained_reports_evaluated -eq 0 -and
    [int]$protocol.pre_reservation_qualification_refusal.recovery_artifacts_written -eq 0 -and
    [int]$protocol.pre_reservation_qualification_refusal.physics_worlds_opened -eq 0 -and
    -not [bool]$protocol.pre_reservation_qualification_refusal.recovery_identity_consumed -and
    -not [bool]$protocol.pre_reservation_qualification_refusal.physical_identity_consumed -and
    -not [bool]$protocol.pre_reservation_qualification_refusal.scientific_result_exists -and
    [int]$protocol.consumed_attempt.physical_process_launch_count -eq 6 -and
    [int]$protocol.consumed_attempt.retained_full_report_count -eq 6 -and
    [int]$protocol.consumed_attempt.retained_cold_evaluation_count -eq 6 -and
    -not [bool]$protocol.consumed_attempt.original_aggregate_report_present -and
    -not [bool]$protocol.consumed_attempt.original_aggregate_evaluation_present -and
    -not [bool]$protocol.consumed_attempt.same_identity_rerun_allowed -and
    [bool]$protocol.implementation_failure.failure_occurred_after_all_six_worker_reports_and_cold_evaluations_were_retained -and
    -not [bool]$protocol.implementation_failure.physical_worker_behavior_affected -and
    @($protocol.retained_cells).Count -eq 6 -and
    (@($protocol.recovery_contract.recovery_artifact_names) -join "|") -ceq
        ($recoveryArtifactNames -join "|") -and
    [bool]$protocol.recovery_contract.historical_full_godot_attestation_must_be_verified_against_its_frozen_physical_source_not_the_descendant_recovery_head -and
    [bool]$protocol.immutability.original_supervisor_failure_is_preserved -and
    [bool]$protocol.immutability.recovery_is_zero_world_analysis_only -and
    [bool]$protocol.immutability.recovery_may_execute_once -and
    [bool]$protocol.immutability.recovery_failure_cannot_authorize_a_second_recovery_or_physical_rerun
) "$recoveryId protocol identity or immutable recovery boundary changed"

foreach ($claimName in @(
    "scientific_result_exists",
    "exact_s169_rapier_three_material_validation",
    "exact_s169_mujoco_three_material_validation",
    "qsdk_r14_declared_exact_finite_grid",
    "qsdk_r15_declared_exact_finite_grid",
    "different_physics_engines_same_policy_exact_finite_validation",
    "bounded_discrete_material_validation",
    "formal_cross_engine_equivalence",
    "continuous_friction_coverage",
    "arbitrary_material_robustness",
    "population_inference",
    "release_authorized",
    "completed_engine_neutral_sdk",
    "physical_acceptance_authority"
)) {
    Assert-Exact (-not [bool]$protocol.claims_before_recovery[$claimName]) (
        "$recoveryId pre-recovery claim was inflated: $claimName"
    )
}
foreach ($claimName in @(
    "formal_cross_engine_equivalence",
    "trajectory_equivalence",
    "continuous_friction_coverage",
    "arbitrary_material_robustness",
    "population_inference",
    "arbitrary_quadruped_coverage",
    "continuous_morphology_coverage",
    "rough_terrain_robustness",
    "external_push_recovery",
    "sensor_noise_or_latency_robustness",
    "release_authorized",
    "completed_engine_neutral_sdk",
    "physical_acceptance_authority"
)) {
    Assert-Exact (-not [bool]$protocol.claims_if_recovery_passes[$claimName]) (
        "$recoveryId conditional claim was inflated: $claimName"
    )
}

$reconstructionSource = Get-Content -Raw -LiteralPath $reconstructionPath
$recoveryRunnerSource = Get-Content -Raw -LiteralPath $recoveryRunnerPath
$physicalRunnerSource = Get-Content -Raw -LiteralPath $physicalRunnerPath
Assert-Exact (
    ([regex]::Matches(
        $reconstructionSource,
        'ForEach-Object\s*\{\s*\[int\]\$_\.world_(attempt|build|reset)_count\s*\}\s*\|\s*Measure-Object\s+-Sum'
    )).Count -eq 3 -and
    ([regex]::Matches(
        $physicalRunnerSource,
        "Measure-Object\s+world_(attempt|build|reset)_count\s+-Sum"
    )).Count -eq 3 -and
    -not $recoveryRunnerSource.Contains(
        "--run-physical",
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    -not $recoveryRunnerSource.Contains(
        "Start-Process",
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    $recoveryRunnerSource.Contains(
        "--evaluate-report",
        [StringComparison]::Ordinal
    ) -and
    $recoveryRunnerSource.Contains(
        "[IO.FileMode]::CreateNew",
        [StringComparison]::Ordinal
    )
) "$recoveryId count repair or zero-world-only execution surface changed"

Assert-Exact (
    (Test-Path -LiteralPath $attemptRoot -PathType Container) -and
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "report.json")) -and
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "evaluation.json")) -and
    @($recoveryArtifactNames | Where-Object {
        Test-Path -LiteralPath (Join-Path $attemptRoot $_)
    }).Count -eq 0
) "$recoveryId original aggregate or recovery artifact unexpectedly exists"

$snapshot = Get-EvidenceTreeSnapshot -Root $attemptRoot
Assert-Exact (
    [int]$snapshot.file_count -eq
        [int]$protocol.consumed_attempt.original_evidence_tree.file_count -and
    [long]$snapshot.total_byte_length -eq
        [long]$protocol.consumed_attempt.original_evidence_tree.total_byte_length -and
    [string]$snapshot.tree_sha256 -ceq
        [string]$protocol.consumed_attempt.original_evidence_tree.tree_sha256 -and
    [string]$snapshot.entries["attempt.json"].raw_sha256 -ceq
        [string]$protocol.consumed_attempt.attempt_raw_sha256 -and
    [string]$snapshot.entries["preflight.json"].raw_sha256 -ceq
        [string]$protocol.consumed_attempt.preflight_raw_sha256 -and
    [string]$snapshot.entries["completion.json"].raw_sha256 -ceq
        [string]$protocol.consumed_attempt.completion_raw_sha256
) "$recoveryId retained original evidence tree changed"

foreach ($cell in @($protocol.retained_cells)) {
    $cellPrefix = "cells/$([string]$cell.cell_id)"
    Assert-Exact (
        [long]$snapshot.entries["$cellPrefix/report.json"].size_bytes -eq
            [long]$cell.report_size_bytes -and
        [string]$snapshot.entries["$cellPrefix/report.json"].raw_sha256 -ceq
            [string]$cell.report_raw_sha256 -and
        [long]$snapshot.entries["$cellPrefix/stdout.log"].size_bytes -eq
            [long]$cell.stdout_size_bytes -and
        [string]$snapshot.entries["$cellPrefix/stdout.log"].raw_sha256 -ceq
            [string]$cell.stdout_raw_sha256 -and
        [string]$snapshot.entries["$cellPrefix/cold_evaluation.json"].raw_sha256 -ceq
            [string]$cell.cold_evaluation_raw_sha256 -and
        [long]$snapshot.entries["$cellPrefix/stderr.log"].size_bytes -eq 0
    ) "$recoveryId retained cell bytes changed: $([string]$cell.cell_id)"
}

$completion = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "completion.json"
) | ConvertFrom-Json -AsHashtable -Depth 128
Assert-Exact (
    [string]$completion.status -ceq
        "supervisor_failed_after_identity_consumption" -and
    [int]$completion.physical_process_launch_count -eq 6 -and
    [int]$completion.retained_cell_summary_count -eq 6 -and
    -not [bool]$completion.same_identity_rerun_allowed
) "$recoveryId original failed completion boundary changed"

$preflightArgs = @(
    "-NoLogo",
    "-NoProfile",
    "-File",
    $recoveryRunnerPath,
    "-PreflightOnly"
)
$before = @(Get-LightweightEvidenceManifest -Root $attemptRoot)
$preflightOutput = & pwsh @preflightArgs 2>&1 | Out-String
$preflightExitCode = $LASTEXITCODE
$after = @(Get-LightweightEvidenceManifest -Root $attemptRoot)
Assert-Exact (
    $preflightExitCode -eq 0 -and
    $preflightOutput.Contains(
        "C6_XE_BW19V_XV2_AGGREGATE_RECOVERY_FREEZE_PASS " +
        "worlds=0 cells=6 count_projection=3 synthetic_gate=12 " +
        "recovery_artifacts=0 physical_authority=False",
        [StringComparison]::Ordinal
    ) -and
    ($after -join "`n") -ceq ($before -join "`n")
) "$recoveryId zero-world preflight failed or changed retained evidence"

Write-Host (
    "C6_XE_BW19V_XV2_AGGREGATE_RECOVERY_FREEZE_AUDIT_PASS " +
    "worlds=0 reports=6 retained_cold=6 count_projection=3 " +
    "synthetic_gate=12 recovery_artifacts=0 physical_authority=False"
)

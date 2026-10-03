#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$python = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$rapierBinary = Join-Path $sdkRoot (
    "target\release\cross_engine_discrete_material_validation_xv2_rapier.exe"
)
$closurePath = Join-Path $sdkRoot (
    "cross_engine_c6_bw19v_discrete_material_validation_xv2_closure.json"
)
$gatePath = Join-Path $sdkRoot (
    "cross_engine_c6_bw19v_discrete_material_validation_xv2_gate.ps1"
)
$recoveryRunnerPath = Join-Path $sdkRoot (
    "run_cross_engine_c6_bw19v_discrete_material_validation_xv2_" +
    "aggregate_recovery.ps1"
)
$attemptRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "c6-cross-engine-bw19v-xv2-e00ec7a"
)
$campaignId = "C6-CROSS-ENGINE-BW19V-DISCRETE-MATERIAL-VALIDATION-XV2"
$gateId = "C6-XE-BW19V-XV2"
$recoveryId = "C6-XE-BW19V-XV2-AGGREGATE-RECOVERY-R1"
$expectedClosureSha256 = (
    "8de4b7606486f672b467f087a7333b2f0555418749f62c5c0cf044f37ab6ee2c"
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

function Get-EvidenceEntries {
    param([Parameter(Mandatory)][string]$Root)
    return @(
        Get-ChildItem -LiteralPath $Root -File -Recurse |
        ForEach-Object {
            [ordered]@{
                relative_path = $_.FullName.Substring(
                    $Root.Length + 1
                ).Replace("\", "/")
                size_bytes = [long]$_.Length
                raw_sha256 = Get-RawSha256 $_.FullName
            }
        } |
        Sort-Object { [string]$_.relative_path }
    )
}

function Get-EvidenceDigest {
    param([Parameter(Mandatory)][object[]]$Entries)
    $lines = @(
        $Entries | ForEach-Object {
            "$($_.relative_path)`t$($_.size_bytes)`t$($_.raw_sha256)"
        }
    )
    $text = ($lines -join "`n") + "`n"
    return [ordered]@{
        file_count = $Entries.Count
        total_byte_length = [long](
            $Entries |
                ForEach-Object { [long]$_.size_bytes } |
                Measure-Object -Sum
        ).Sum
        tree_sha256 = [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData(
                [Text.Encoding]::UTF8.GetBytes($text)
            )
        ).ToLowerInvariant()
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
        "https://github.com/Slagathore/sporespore.git" -and
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-RawSha256 $closurePath) -ceq $expectedClosureSha256
) "$gateId closure or repository identity changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 128
Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_cross_engine_c6_bw19v_discrete_material_validation_xv2_closure_v1" -and
    [string]$closure.status -ceq
        "closed_complete_valid_positive_via_frozen_zero_world_aggregate_reconstruction_after_original_post_worker_implementation_failure" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.recovery_id -ceq $recoveryId -and
    [bool]$closure.scientific_disposition.original_supervisor_completion_implementation_invalid -and
    -not [bool]$closure.scientific_disposition.original_aggregate_report_present -and
    -not [bool]$closure.scientific_disposition.original_aggregate_evaluation_present -and
    [bool]$closure.scientific_disposition.all_six_physical_workers_complete -and
    [bool]$closure.scientific_disposition.all_six_original_cold_evaluations_passed -and
    [bool]$closure.scientific_disposition.frozen_zero_world_reconstruction_accepted -and
    [int]$closure.scientific_disposition.frozen_aggregate_gate_pass_count -eq 12 -and
    [bool]$closure.scientific_disposition.valid_positive_for_preregistered_exact_finite_conjunction -and
    -not [bool]$closure.scientific_disposition.valid_negative -and
    [int]$closure.scientific_disposition.recovery_world_build_count -eq 0 -and
    [int]$closure.scientific_disposition.recovery_physical_process_launch_count -eq 0 -and
    -not [bool]$closure.scientific_disposition.physical_acceptance_authority
) "$gateId closure disposition changed"

foreach ($sourceBinding in @(
    @(
        [string]$closure.frozen_sources.preregistration_path,
        [string]$closure.frozen_sources.preregistration_raw_sha256
    ),
    @(
        [string]$closure.frozen_sources.aggregate_gate_path,
        [string]$closure.frozen_sources.aggregate_gate_raw_sha256
    ),
    @(
        [string]$closure.frozen_sources.original_supervisor_path,
        [string]$closure.frozen_sources.original_supervisor_raw_sha256
    ),
    @(
        [string]$closure.frozen_sources.recovery_protocol_path,
        [string]$closure.frozen_sources.recovery_protocol_raw_sha256
    ),
    @(
        [string]$closure.frozen_sources.aggregate_reconstruction_path,
        [string]$closure.frozen_sources.aggregate_reconstruction_raw_sha256
    ),
    @(
        [string]$closure.frozen_sources.recovery_runner_path,
        [string]$closure.frozen_sources.recovery_runner_raw_sha256
    )
)) {
    $boundPath = Join-Path $repoRoot ([string]$sourceBinding[0])
    Assert-Exact (
        (Test-Path -LiteralPath $boundPath -PathType Leaf) -and
        (Get-RawSha256 $boundPath) -ceq [string]$sourceBinding[1]
    ) "$gateId frozen source changed: $boundPath"
}

$physicalSource = [string]$closure.lineage.physical_source_commit
$physicalTree = [string]$closure.lineage.physical_source_tree_git_oid
$recoverySource = [string]$closure.lineage.recovery_source_commit
$recoveryTree = [string]$closure.lineage.recovery_source_tree_git_oid
& git -C $repoRoot merge-base --is-ancestor $physicalSource HEAD
$physicalAncestor = $LASTEXITCODE -eq 0
& git -C $repoRoot merge-base --is-ancestor $recoverySource HEAD
$recoveryAncestor = $LASTEXITCODE -eq 0
Assert-Exact (
    $physicalAncestor -and
    $recoveryAncestor -and
    (git -C $repoRoot rev-parse ($physicalSource + '^{tree}')).Trim() -ceq
        $physicalTree -and
    (git -C $repoRoot rev-parse ($recoverySource + '^{tree}')).Trim() -ceq
        $recoveryTree -and
    (git -C $repoRoot merge-base $physicalSource origin/main).Trim() -ceq
        $physicalSource -and
    (git -C $repoRoot merge-base $recoverySource origin/main).Trim() -ceq
        $recoverySource
) "$gateId physical or recovery source lineage changed"

$attestationPath = [IO.Path]::GetFullPath(
    ([string]$closure.full_godot_v2_attestation.path).Replace("/", "\")
)
Assert-Exact (
    (Get-Item -LiteralPath $attestationPath).Length -eq
        [long]$closure.full_godot_v2_attestation.size_bytes -and
    (Get-RawSha256 $attestationPath) -ceq
        [string]$closure.full_godot_v2_attestation.raw_sha256
) "$gateId full-Godot V2 attestation changed"

$entries = @(Get-EvidenceEntries -Root $attemptRoot)
$closedDigest = Get-EvidenceDigest -Entries $entries
$originalEntries = @($entries | Where-Object {
    [string]$_.relative_path -cnotin $recoveryArtifactNames
})
$originalDigest = Get-EvidenceDigest -Entries $originalEntries
Assert-Exact (
    [int]$closedDigest.file_count -eq
        [int]$closure.retained_evidence.closed_evidence_tree.file_count -and
    [long]$closedDigest.total_byte_length -eq
        [long]$closure.retained_evidence.closed_evidence_tree.total_byte_length -and
    [string]$closedDigest.tree_sha256 -ceq
        [string]$closure.retained_evidence.closed_evidence_tree.tree_sha256 -and
    [int]$originalDigest.file_count -eq
        [int]$closure.retained_evidence.original_evidence_tree.file_count -and
    [long]$originalDigest.total_byte_length -eq
        [long]$closure.retained_evidence.original_evidence_tree.total_byte_length -and
    [string]$originalDigest.tree_sha256 -ceq
        [string]$closure.retained_evidence.original_evidence_tree.tree_sha256 -and
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "report.json")) -and
    -not (Test-Path -LiteralPath (Join-Path $attemptRoot "evaluation.json"))
) "$gateId closed or original evidence tree changed"

$entryByPath = @{}
foreach ($entry in $entries) {
    $entryByPath[[string]$entry.relative_path] = $entry
}
foreach ($artifactName in $recoveryArtifactNames) {
    $prefix = switch ($artifactName) {
        "aggregate_recovery_attempt_v1.json" { "recovery_attempt" }
        "aggregate_reconstruction_v1.json" { "reconstruction" }
        "aggregate_reconstruction_evaluation_v1.json" {
            "reconstruction_evaluation"
        }
        "aggregate_recovery_completion_v1.json" { "recovery_completion" }
    }
    Assert-Exact (
        [long]$entryByPath[$artifactName].size_bytes -eq
            [long]$closure.retained_evidence[$prefix + "_size_bytes"] -and
        [string]$entryByPath[$artifactName].raw_sha256 -ceq
            [string]$closure.retained_evidence[$prefix + "_raw_sha256"]
    ) "$gateId recovery artifact changed: $artifactName"
}

$originalAttempt = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "attempt.json"
) | ConvertFrom-Json -AsHashtable -Depth 128
$originalCompletion = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "completion.json"
) | ConvertFrom-Json -AsHashtable -Depth 128
$recoveryAttempt = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "aggregate_recovery_attempt_v1.json"
) | ConvertFrom-Json -AsHashtable -Depth 128
$reconstruction = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "aggregate_reconstruction_v1.json"
) | ConvertFrom-Json -AsHashtable -Depth 128
$storedEvaluation = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "aggregate_reconstruction_evaluation_v1.json"
) | ConvertFrom-Json -AsHashtable -Depth 128
$recoveryCompletion = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "aggregate_recovery_completion_v1.json"
) | ConvertFrom-Json -AsHashtable -Depth 128
Assert-Exact (
    [string]$originalAttempt.attempt_id -ceq
        [string]$closure.lineage.physical_attempt_id -and
    [string]$originalCompletion.status -ceq
        "supervisor_failed_after_identity_consumption" -and
    [int]$originalCompletion.physical_process_launch_count -eq 6 -and
    [int]$originalCompletion.retained_cell_summary_count -eq 6 -and
    -not [bool]$originalCompletion.same_identity_rerun_allowed -and
    [string]$recoveryAttempt.status -ceq
        "zero_world_aggregate_recovery_reserved" -and
    [string]$recoveryAttempt.recovery_source_commit -ceq $recoverySource -and
    [string]$recoveryAttempt.physical_source_commit -ceq $physicalSource -and
    [int]$recoveryAttempt.world_build_count -eq 0 -and
    [int]$recoveryAttempt.physical_worker_process_launch_count -eq 0 -and
    [string]$recoveryCompletion.status -ceq
        "complete_frozen_aggregate_reconstruction_accepted" -and
    [bool]$recoveryCompletion.accepted -and
    [int]$recoveryCompletion.passed_gate_count -eq 12 -and
    [int]$recoveryCompletion.failed_gate_count -eq 0 -and
    @($recoveryCompletion.failure_codes).Count -eq 0 -and
    [int]$recoveryCompletion.world_build_count -eq 0 -and
    [int]$recoveryCompletion.physical_worker_process_launch_count -eq 0 -and
    -not [bool]$recoveryCompletion.same_recovery_identity_rerun_allowed -and
    -not [bool]$recoveryCompletion.same_physical_identity_rerun_allowed
) "$gateId original or recovered completion boundary changed"

. $gatePath
$freshEvaluation = Test-CrossEngineC6Bw19vDiscreteMaterialValidationXv2Result (
    $reconstruction
)
Assert-Exact (
    [bool]$storedEvaluation.accepted -and
    @($storedEvaluation.gates).Count -eq 12 -and
    @($storedEvaluation.gates | Where-Object passed).Count -eq 12 -and
    @($storedEvaluation.failure_codes).Count -eq 0 -and
    [bool]$freshEvaluation.accepted -and
    @($freshEvaluation.gates | Where-Object passed).Count -eq 12 -and
    @($freshEvaluation.failure_codes).Count -eq 0 -and
    [string]$reconstruction.source.commit -ceq $physicalSource -and
    [string]$reconstruction.reconstruction.recovery_source_commit -ceq
        $recoverySource -and
    @($reconstruction.ordered_cells).Count -eq 6 -and
    [int]$reconstruction.world_attempt_count -eq 6 -and
    [int]$reconstruction.world_build_count -eq 6 -and
    [int]$reconstruction.world_reset_count -eq 0 -and
    [int]$reconstruction.physical_process_launch_count -eq 6 -and
    [bool]$reconstruction.claims.accepted -and
    [bool]$reconstruction.claims.qsdk_r14_declared_exact_finite_grid -and
    [bool]$reconstruction.claims.qsdk_r15_declared_exact_finite_grid
) "$gateId stored or fresh aggregate decision changed"

$closureCells = @($closure.cells)
$reconstructedCells = @($reconstruction.ordered_cells)
Assert-Exact (
    $closureCells.Count -eq 6 -and
    $reconstructedCells.Count -eq 6
) "$gateId six-cell closure cardinality changed"
$freshColdReplayCount = 0
foreach ($closureCell in $closureCells) {
    $cellId = [string]$closureCell.cell_id
    $reconstructedCell = @($reconstructedCells | Where-Object {
        [string]$_.cell_id -ceq $cellId
    })
    Assert-Exact ($reconstructedCell.Count -eq 1) (
        "$gateId reconstructed cell missing: $cellId"
    )
    $reportPath = Join-Path $attemptRoot "cells\$cellId\report.json"
    $coldPath = Join-Path $attemptRoot "cells\$cellId\cold_evaluation.json"
    Assert-Exact (
        (Get-RawSha256 $reportPath) -ceq
            [string]$closureCell.report_raw_sha256 -and
        (Get-RawSha256 $coldPath) -ceq
            [string]$closureCell.original_cold_evaluation_raw_sha256
    ) "$gateId cell report or original cold evaluation changed: $cellId"
    $report = Get-Content -Raw -LiteralPath $reportPath |
        ConvertFrom-Json -AsHashtable -Depth 128
    $metrics = $report.metrics
    Assert-Exact (
        [string]$report.cell_id -ceq $cellId -and
        [int]$report.trace_step_count -eq [int]$closureCell.trace_step_count -and
        [double]$metrics.evidence_forward_displacement_m -eq
            [double]$closureCell.evidence_forward_displacement_m -and
        [double]$metrics.final_forward_displacement_m -eq
            [double]$closureCell.final_forward_displacement_m -and
        [double]$metrics.final_lateral_displacement_m -eq
            [double]$closureCell.final_lateral_displacement_m -and
        [double]$metrics.final_yaw_drift_rad -eq
            [double]$closureCell.final_yaw_drift_rad -and
        [double]$metrics.maximum_tilt_rad -eq
            [double]$closureCell.maximum_tilt_rad -and
        [double]$metrics.minimum_torso_height_m -eq
            [double]$closureCell.minimum_torso_height_m -and
        [bool]$report.terminal_four_contact_stance -and
        [bool]$report.schedule.terminal_restoration_phase.required_consecutive_hold_completed -and
        [int]$reconstructedCell[0].process_exit_code -eq 0 -and
        [bool]$reconstructedCell[0].worker_report_ok -and
        [bool]$reconstructedCell[0].cold_evaluator_replay_passed -and
        [int]$reconstructedCell[0].gate_failure_count -eq 0 -and
        [int]$reconstructedCell[0].integrity_failure_count -eq 0
    ) "$gateId reconstructed cell result changed: $cellId"

    $freshLines = @()
    $freshExit = -1
    if ([string]$closureCell.engine -ceq "rapier") {
        $freshLines = @(& $rapierBinary --evaluate-report $reportPath)
        $freshExit = $LASTEXITCODE
    }
    else {
        Push-Location -LiteralPath $mujocoRoot
        try {
            $freshArgs = @(
                "-m",
                "sporespore_mujoco_adapter.cross_engine_discrete_material_validation_xv2_mujoco",
                "--evaluate-report",
                $reportPath
            )
            $freshLines = @(& $python @freshArgs)
            $freshExit = $LASTEXITCODE
        }
        finally {
            Pop-Location
        }
    }
    $freshCold = ($freshLines -join [Environment]::NewLine) |
        ConvertFrom-Json -AsHashtable -Depth 128
    Assert-Exact (
        $freshExit -eq 0 -and
        [bool]$freshCold.ok -and
        @($freshCold.failure_codes).Count -eq 0 -and
        [string]$freshCold.cell_id -ceq $cellId -and
        [int]$freshCold.world_build_count -eq 0
    ) "$gateId fresh closure cold replay failed: $cellId"
    $freshColdReplayCount += 1
    $report = $null
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
    Assert-Exact (
        -not [bool]$closure.claims[$claimName] -and
        -not [bool]$reconstruction.claims[$claimName]
    ) "$gateId unlawfully gained claim authority: $claimName"
}

$beforeRefusal = @(Get-LightweightEvidenceManifest -Root $attemptRoot)
$refusalArgs = @(
    "-NoLogo",
    "-NoProfile",
    "-File",
    $recoveryRunnerPath,
    "-RunRecovery"
)
$refusalOutput = & pwsh @refusalArgs 2>&1 | Out-String
$refusalExit = $LASTEXITCODE
$afterRefusal = @(Get-LightweightEvidenceManifest -Root $attemptRoot)
Assert-Exact (
    $refusalExit -ne 0 -and
    $refusalOutput.Contains(
        "$recoveryId is one-shot and has already been reserved or executed",
        [StringComparison]::Ordinal
    ) -and
    ($afterRefusal -join "`n") -ceq ($beforeRefusal -join "`n") -and
    [bool]$closure.immutability.physical_attempt_final -and
    [bool]$closure.immutability.original_supervisor_failure_preserved -and
    [bool]$closure.immutability.original_aggregate_filenames_remain_absent -and
    [bool]$closure.immutability.recovery_attempt_final -and
    -not [bool]$closure.immutability.same_recovery_identity_rerun_allowed -and
    -not [bool]$closure.immutability.same_physical_identity_rerun_allowed
) "$gateId same-identity recovery refusal or immutability changed"

Write-Host (
    "C6_XE_BW19V_XV2_CLOSURE_PASS status=positive " +
    "physical_workers=6 original_aggregate=False reconstruction=True " +
    "gates=12/12 cold_replays=$freshColdReplayCount worlds=6 " +
    "recovery_worlds=0 r14=True r15=True equivalence=False " +
    "physical_authority=False rerun_refused=True"
)

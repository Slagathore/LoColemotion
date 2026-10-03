#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r23d14-3ead7ec5-20260811T091644Z"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot "turning\r23d14_physical_closure_v1.json"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$campaignId = "QSDK-R23D14-TIGHT-GATED-HORIZON-THREE-ENGINE-TURN-CONFIRMATION"
$gateId = "QSDK-R23D14"
$sourceCommit = "3ead7ec5220e50097a5a0c5ac89ba45db594431a"
$sourceTree = "11da51624e72cc2d6045623f074a3fe0db82d128"
$attemptId = "e96111f0eec44dab9626c23810bee5ec"

. $artifactStorePath

function Assert-R23D14Closure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D14ClosureRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D14ClosureBytesSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D14ClosureEvidenceTree {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse | Sort-Object {
        $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
    })
    $lines = @($files | ForEach-Object {
        $relative = $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
        "{0}`t{1}`t{2}" -f $relative, $_.Length, (
            Get-R23D14ClosureRawSha256 $_.FullName
        ).Substring(7)
    })
    $projection = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n") + "`n")
    return [ordered]@{
        files = $files
        file_count = $files.Count
        total_byte_length = [int64](($files | Measure-Object Length -Sum).Sum)
        raw_sha256 = Get-R23D14ClosureBytesSha256 $projection
    }
}

function Test-R23D14ClosureCasArtifact {
    param(
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][long]$ExpectedByteLength
    )
    $artifactRoot = Join-Path (
        Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
    ) "artifacts\sha256"
    $digest = $ExpectedSha256.Substring(7)
    return Test-SporeSporeStoredArtifact `
        -Directory (Join-Path $artifactRoot $digest) `
        -ExpectedSha256 $digest `
        -ExpectedByteLength $ExpectedByteLength
}

function Assert-R23D14ClosureFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][string]$Label
    )
    Assert-R23D14Closure (Test-Path -LiteralPath $Path -PathType Leaf) (
        "QSDK-R23D14 retained file is missing: $Label"
    )
    $item = Get-Item -LiteralPath $Path
    Assert-R23D14Closure (
        (Get-R23D14ClosureRawSha256 $Path) -ceq $ExpectedSha256 -and
        (Test-R23D14ClosureCasArtifact `
            -ExpectedSha256 $ExpectedSha256 `
            -ExpectedByteLength ([long]$item.Length))
    ) "QSDK-R23D14 retained file or CAS object changed: $Label"
}

Assert-R23D14Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D14 closure repository identity mismatch"
Assert-R23D14Closure (
    (git -C $repoRoot rev-parse ($sourceCommit + "^{tree}")) -ceq $sourceTree
) "QSDK-R23D14 frozen source tree is unavailable"
Assert-R23D14Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "QSDK-R23D14 closure is missing"
)
Assert-R23D14Closure (Test-Path -LiteralPath $EvidenceRoot -PathType Container) (
    "QSDK-R23D14 retained attempt root is missing"
)

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D14Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d14_physical_confirmation_closure_v1" -and
    [string]$closure.status -ceq (
        "closed_consumed_invalid_complete_matrix_six_worker_failures_" +
        "three_valid_mujoco_cells"
    ) -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.source_identity.commit -ceq $sourceCommit -and
    [string]$closure.source_identity.tree_git_oid -ceq $sourceTree -and
    [int]$closure.source_identity.declared_source_binding_count -eq 112 -and
    [int]$closure.source_identity.runtime_artifact_count -eq 3 -and
    [int]$closure.source_identity.external_runtime_binding_count -eq 4 -and
    [int]$closure.source_identity.declared_worker_dependency_count -eq 70
) "QSDK-R23D14 closure identity changed"

$tree = Get-R23D14ClosureEvidenceTree -Root $EvidenceRoot
Assert-R23D14Closure (
    $tree.file_count -eq [int]$closure.attempt.evidence_file_count -and
    $tree.total_byte_length -eq [int64]$closure.attempt.evidence_total_byte_length -and
    [string]$tree.raw_sha256 -ceq [string]$closure.attempt.evidence_tree_raw_sha256
) "QSDK-R23D14 retained evidence tree changed"
foreach ($file in @($tree.files)) {
    $sha256 = Get-R23D14ClosureRawSha256 $file.FullName
    Assert-R23D14Closure (
        Test-R23D14ClosureCasArtifact `
            -ExpectedSha256 $sha256 `
            -ExpectedByteLength ([long]$file.Length)
    ) "QSDK-R23D14 attempt file is not retained in CAS: $($file.FullName)"
}

$attestationPath = [string]$closure.full_godot_attestation.path
$canaryLogPath = [string]$closure.production_authorization_canaries.log_path
$supervisorLogPath = [string]$closure.attempt.supervisor_log_path
Assert-R23D14ClosureFile $attestationPath `
    ([string]$closure.full_godot_attestation.raw_sha256) "full Godot attestation"
Assert-R23D14ClosureFile $canaryLogPath `
    ([string]$closure.production_authorization_canaries.log_raw_sha256) `
    "production authorization canaries"
Assert-R23D14ClosureFile $supervisorLogPath `
    ([string]$closure.attempt.supervisor_log_raw_sha256) "continuous supervisor log"

$expectedAttemptFiles = [ordered]@{
    "physical-freeze.json" = [string]$closure.attempt.physical_freeze_raw_sha256
    "matrix-authorization.json" = [string]$closure.attempt.matrix_authorization_raw_sha256
    "matrix-terminal-paths.json" = [string]$closure.attempt.matrix_terminal_paths_raw_sha256
    "report.json" = [string]$closure.attempt.report_raw_sha256
    "completion.json" = [string]$closure.attempt.completion_raw_sha256
    "complete-evaluator/evaluation.json" = [string]$closure.attempt.complete_evaluation_raw_sha256
}
foreach ($relative in $expectedAttemptFiles.Keys) {
    Assert-R23D14ClosureFile `
        (Join-Path $EvidenceRoot $relative) `
        ([string]$expectedAttemptFiles[$relative]) `
        $relative
}

$completion = Get-Content -Raw -LiteralPath (Join-Path $EvidenceRoot "completion.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$report = Get-Content -Raw -LiteralPath (Join-Path $EvidenceRoot "report.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$evaluation = Get-Content -Raw -LiteralPath (
    Join-Path $EvidenceRoot "complete-evaluator\evaluation.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D14Closure (
    [string]$completion.status -ceq "invalid_or_incomplete_first_attempt" -and
    [string]$completion.attempt_id -ceq $attemptId -and
    [int]$completion.matrix_terminal_entry_count -eq 9 -and
    [string]$completion.result_classification -ceq
        "invalid_or_incomplete_complete_matrix" -and
    [bool]$completion.one_shot_identity_consumed -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    [string]$report.attempt_id -ceq $attemptId -and
    [string]$report.result_classification -ceq
        "invalid_or_incomplete_complete_matrix" -and
    -not [bool]$report.finite_matrix_result_valid -and
    [int]$report.matrix_world_count -eq 9 -and
    [string]$evaluation.classification -ceq
        "invalid_or_incomplete_complete_matrix" -and
    -not [bool]$evaluation.matrix_valid -and
    [int]$evaluation.world_attempt_count -eq 6 -and
    [int]$evaluation.world_build_count -eq 3 -and
    [int]$evaluation.outcome_failure_count -eq 0
) "QSDK-R23D14 immutable completion changed"

$cellEvaluations = @($evaluation.cell_evaluations)
$godotFailures = @($cellEvaluations | Where-Object {
    [string]$_.engine_id -ceq "godot_jolt" -and
    [string]$_.entry_kind -ceq "worker_failure" -and
    @($_.failure_codes).Count -eq 1 -and
    [string]$_.failure_codes[0] -ceq "QSDK_R23D14_GJT_WORLD_BUILD_COUNT_INVALID" -and
    [int]$_.world_attempt_count -eq 1 -and
    [int]$_.world_build_count -eq 0
})
$rapierFailures = @($cellEvaluations | Where-Object {
    [string]$_.engine_id -ceq "rapier_parry" -and
    [string]$_.entry_kind -ceq "worker_failure" -and
    @($_.failure_codes).Count -eq 1 -and
    [string]$_.failure_codes[0] -ceq "R23D11_RAP_CELL_IDENTITY_INVALID" -and
    [int]$_.world_attempt_count -eq 0 -and
    [int]$_.world_build_count -eq 0
})
$mujocoPasses = @($cellEvaluations | Where-Object {
    [string]$_.engine_id -ceq "mujoco" -and
    [string]$_.entry_kind -ceq "cell_report" -and
    [bool]$_.entry_valid -and
    [bool]$_.execution_integrity_passed -and
    [bool]$_.outcome.walking_and_taper_gate_passed -and
    [bool]$_.outcome.signed_yaw_response_passed -and
    [bool]$_.outcome.outcome_gate_passed -and
    @($_.outcome.failed_gate_ids).Count -eq 0 -and
    [int]$_.world_attempt_count -eq 1 -and
    [int]$_.world_build_count -eq 1
})
Assert-R23D14Closure (
    $cellEvaluations.Count -eq 9 -and
    $godotFailures.Count -eq 3 -and
    $rapierFailures.Count -eq 3 -and
    $mujocoPasses.Count -eq 3
) "QSDK-R23D14 engine-cell classification changed"

$mujocoExpected = [ordered]@{
    "mujoco__tight_gated_horizon__reference_zero" = @(-0.023413046951688887, 1.8258584631527954)
    "mujoco__tight_gated_horizon__positive_heading" = @(0.0842283890494393, 1.8947454902875067)
    "mujoco__tight_gated_horizon__negative_heading" = @(-0.15257912436083565, 1.861559698005158)
}
foreach ($cell in @($closure.engine_observations.mujoco.cell_results)) {
    $expected = $mujocoExpected[[string]$cell.cell_id]
    Assert-R23D14Closure (
        $null -ne $expected -and
        [Math]::Abs([double]$cell.turn_phase_yaw_delta_rad - [double]$expected[0]) -le 1e-15 -and
        [Math]::Abs([double]$cell.final_forward_displacement_m - [double]$expected[1]) -le 1e-15 -and
        [bool]$cell.walking_and_taper_gate_passed -and
        [bool]$cell.signed_yaw_response_passed -and
        [bool]$cell.outcome_gate_passed
    ) "QSDK-R23D14 retained MuJoCo cell observation changed: $($cell.cell_id)"
}

$godotReferenceLog = Join-Path $EvidenceRoot (
    "matrix\godot_jolt__tight_gated_horizon__reference_zero\godot.log"
)
$godotText = Get-Content -Raw -LiteralPath $godotReferenceLog
$frozenWaveSource = @(git -C $repoRoot show (
    $sourceCommit + ":scripts/lab/gait/physical_wave_gait_quadruped.gd"
)) -join "`n"
$frozenRapierSource = @(git -C $repoRoot show (
    $sourceCommit + ":sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d14_physical.rs"
)) -join "`n"
$frozenR23D11Source = @(git -C $repoRoot show (
    $sourceCommit + ":sdk/adapters/rapier/src/qsdk_r23d11_stability_assisted_taper.rs"
)) -join "`n"
Assert-R23D14Closure (
    $godotText.Contains("wave_tick=3120") -and
    $godotText.Contains("Invalid call 'String' constructor: reference_continuation") -and
    $godotText.Contains("physical_wave_gait_quadruped.gd:2571") -and
    $frozenWaveSource.Contains("sdk_terminal_handoff_reason = String(") -and
    $frozenRapierSource.Contains("run_qsdk_r23d11_rapier_preflight(") -and
    $frozenRapierSource.Contains("stage_id, arm_id") -and
    $frozenR23D11Source.Contains('stage_id == "three_engine_confirmation"') -and
    $frozenR23D11Source.Contains("R23D11_RAP_CELL_IDENTITY_INVALID")
) "QSDK-R23D14 retained failure mechanisms changed"

$supervisorText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "run_qsdk_r23d14_supervisor.ps1"
)
$mujocoWorkerText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot (
        "adapters\mujoco\sporespore_mujoco_adapter\qsdk_r23d14_physical.py"
    )
)
$rapierWorkerText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d3_phase_balanced\r23d14_physical.rs"
)
$godotWorkerText = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot (
        "tests\test_sdk_qsdk_r23d14_tight_gated_horizon_" +
        "godot_jolt_physical_worker.gd"
    )
)
$conformanceText = Get-Content -Raw -LiteralPath (Join-Path $sdkRoot "run_conformance.ps1")
Assert-R23D14Closure (
    $supervisorText.Contains("r23d14_physical_closure_v1.json") -and
    $supervisorText.Contains("QSDK-R23D14 CLOSED") -and
    $mujocoWorkerText.Contains("r23d14_physical_closure_v1.json") -and
    $mujocoWorkerText.Contains("QSDK_R23D14_MJC_CLOSED") -and
    $rapierWorkerText.Contains("r23d14_physical_closure_v1.json") -and
    $rapierWorkerText.Contains("QSDK_R23D14_RAP_CLOSED") -and
    $godotWorkerText.Contains("r23d14_physical_closure_v1.json") -and
    $godotWorkerText.Contains("QSDK_R23D14_GJT_CLOSED") -and
    $conformanceText.Contains("tests\test_qsdk_r23d14_closure.ps1") -and
    -not $conformanceText.Contains("run_qsdk_r23d14_zero_world_gate.ps1")
) "QSDK-R23D14 closure routing changed"

$priorAttemptRoots = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $EvidenceRoot) -Directory |
        Where-Object {
            $_.Name.StartsWith("qsdk-r23d14-", [StringComparison]::Ordinal) -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json"))
        }
)
$sameIdentityRefusal = @(
    & pwsh -NoLogo -NoProfile -File (
        Join-Path $sdkRoot "run_qsdk_r23d14_supervisor.ps1"
    ) -RunPhysical -FullConformanceAttestation $attestationPath 2>&1
)
$sameIdentityExitCode = $LASTEXITCODE
$sameIdentityText = @($sameIdentityRefusal | ForEach-Object { [string]$_ }) -join "`n"
$afterAttemptRoots = @(
    Get-ChildItem -LiteralPath (Split-Path -Parent $EvidenceRoot) -Directory |
        Where-Object {
            $_.Name.StartsWith("qsdk-r23d14-", [StringComparison]::Ordinal) -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json"))
        }
)
Assert-R23D14Closure (
    $sameIdentityExitCode -ne 0 -and
    $sameIdentityText.Contains("QSDK_R23D14_PHYSICAL_REFUSAL") -and
    $sameIdentityText.Contains('"reason":"r23d14_identity_closed"') -and
    $sameIdentityText.Contains("QSDK-R23D14 CLOSED") -and
    $priorAttemptRoots.Count -eq 1 -and
    $afterAttemptRoots.Count -eq 1 -and
    $afterAttemptRoots[0].FullName -ceq $priorAttemptRoots[0].FullName
) "QSDK-R23D14 same-identity refusal changed"

Assert-R23D14Closure (
    -not [bool]$closure.immutable_completion_record.scientific_positive -and
    -not [bool]$closure.immutable_completion_record.scientific_negative -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    [bool]$closure.claims.finite_mujoco_reference_walking_and_taper -and
    [bool]$closure.claims.finite_mujoco_bilateral_signed_turning_cells -and
    -not [bool]$closure.claims.command_conditioned_turning -and
    -not [bool]$closure.claims.bilateral_signed_turning -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "QSDK-R23D14 claim boundary changed"

# The same-identity negative control intentionally exits nonzero. Preserve its
# observed refusal, then clear native command status for dot-invoking callers.
$global:LASTEXITCODE = 0

Write-Host (
    "QSDK_R23D14_CLOSURE_PASS status=invalid matrix=3/9-valid " +
    "godot_worker_failures=3 rapier_worker_failures=3 mujoco_passes=3 " +
    "mujoco_rows=11856 evaluator_world_attempts=6 evaluator_world_builds=3 " +
    "evidence_files=$($tree.file_count) evidence_bytes=$($tree.total_byte_length) " +
    "same_identity_refusal=1 same_identity_rerun=False turning=False " +
    "equivalence=False physical_authority=False"
)

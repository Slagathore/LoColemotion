#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r23d16-20260811T191159Z"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot "turning\r23d16_physical_closure_v1.json"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$campaignId = (
    "QSDK-R23D16-EVIDENCE-PIPELINE-RECOVERY-" +
    "THREE-ENGINE-TURN-CONFIRMATION"
)
$gateId = "QSDK-R23D16"
$sourceCommit = "c645a18917a75e806284080ff7f3936181946f37"
$sourceTree = "6b85115a85645f6278b8eb02f99ca6a180f977d5"
$attemptId = "944c763861054f4cadd184bc2552e95c"

. $artifactStorePath

function Assert-R23D16Closure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D16ClosureRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D16ClosureBytesSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D16ClosureEvidenceTree {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse | Sort-Object {
        $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
    })
    $lines = @($files | ForEach-Object {
        $relative = $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
        "{0}`t{1}`t{2}" -f $relative, $_.Length, (
            Get-R23D16ClosureRawSha256 $_.FullName
        ).Substring(7)
    })
    $projection = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n") + "`n")
    return [ordered]@{
        files = $files
        file_count = $files.Count
        total_byte_length = [int64](($files | Measure-Object Length -Sum).Sum)
        raw_sha256 = Get-R23D16ClosureBytesSha256 $projection
    }
}

function Test-R23D16ClosureCasArtifact {
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

function Assert-R23D16ClosureFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][string]$Label
    )
    Assert-R23D16Closure (Test-Path -LiteralPath $Path -PathType Leaf) (
        "QSDK-R23D16 retained file is missing: $Label"
    )
    $item = Get-Item -LiteralPath $Path
    Assert-R23D16Closure (
        (Get-R23D16ClosureRawSha256 $Path) -ceq $ExpectedSha256 -and
        (Test-R23D16ClosureCasArtifact `
            -ExpectedSha256 $ExpectedSha256 `
            -ExpectedByteLength ([long]$item.Length))
    ) "QSDK-R23D16 retained file or CAS object changed: $Label"
}

Assert-R23D16Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D16 closure repository identity mismatch"
Assert-R23D16Closure (
    (git -C $repoRoot rev-parse ($sourceCommit + "^{tree}")) -ceq $sourceTree
) "QSDK-R23D16 frozen source tree is unavailable"
Assert-R23D16Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "QSDK-R23D16 closure is missing"
)
Assert-R23D16Closure (Test-Path -LiteralPath $EvidenceRoot -PathType Container) (
    "QSDK-R23D16 retained attempt root is missing"
)

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D16Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d16_physical_confirmation_closure_v1" -and
    [string]$closure.status -ceq (
        "closed_consumed_invalid_complete_matrix_six_worker_failures_" +
        "three_valid_mujoco_cells"
    ) -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.source_identity.commit -ceq $sourceCommit -and
    [string]$closure.source_identity.tree_git_oid -ceq $sourceTree -and
    [int]$closure.source_identity.declared_source_binding_count -eq 113 -and
    [int]$closure.source_identity.declared_worker_dependency_count -eq 76 -and
    -not [bool]$closure.source_identity.controller_or_physics_changed_by_closure
) "QSDK-R23D16 closure identity changed"

$tree = Get-R23D16ClosureEvidenceTree -Root $EvidenceRoot
Assert-R23D16Closure (
    $tree.file_count -eq 60 -and
    $tree.file_count -eq [int]$closure.attempt.evidence_file_count -and
    $tree.total_byte_length -eq 108402271 -and
    $tree.total_byte_length -eq [int64]$closure.attempt.evidence_total_byte_length -and
    [string]$tree.raw_sha256 -ceq [string]$closure.attempt.evidence_tree_raw_sha256
) "QSDK-R23D16 retained evidence tree changed"
foreach ($file in @($tree.files)) {
    $sha256 = Get-R23D16ClosureRawSha256 $file.FullName
    Assert-R23D16Closure (
        Test-R23D16ClosureCasArtifact `
            -ExpectedSha256 $sha256 `
            -ExpectedByteLength ([long]$file.Length)
    ) "QSDK-R23D16 attempt file is not retained in CAS: $($file.FullName)"
}

$attestationPath = [string]$closure.full_godot_attestation.path
Assert-R23D16ClosureFile $attestationPath `
    ([string]$closure.full_godot_attestation.raw_sha256) "full Godot attestation"
$expectedAttemptFiles = [ordered]@{
    "physical-freeze.json" = [string]$closure.attempt.physical_freeze_raw_sha256
    "matrix-authorization.json" = [string]$closure.attempt.matrix_authorization_raw_sha256
    "matrix-terminal-paths.json" = [string]$closure.attempt.matrix_terminal_paths_raw_sha256
    "report.json" = [string]$closure.attempt.report_raw_sha256
    "completion.json" = [string]$closure.attempt.completion_raw_sha256
    "complete-evaluator/evaluation.json" = [string]$closure.attempt.complete_evaluation_raw_sha256
}
foreach ($relative in $expectedAttemptFiles.Keys) {
    Assert-R23D16ClosureFile `
        (Join-Path $EvidenceRoot $relative) `
        ([string]$expectedAttemptFiles[$relative]) `
        $relative
}

$freeze = Get-Content -Raw -LiteralPath (Join-Path $EvidenceRoot "physical-freeze.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$completion = Get-Content -Raw -LiteralPath (Join-Path $EvidenceRoot "completion.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$report = Get-Content -Raw -LiteralPath (Join-Path $EvidenceRoot "report.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$evaluation = Get-Content -Raw -LiteralPath (
    Join-Path $EvidenceRoot "complete-evaluator\evaluation.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
$canaries = $freeze.production_authorization_canaries
Assert-R23D16Closure (
    [bool]$freeze.production_authorization_canaries_valid -and
    [int]$canaries.engine_count -eq 3 -and
    [int]$canaries.worker_process_launch_count -eq 6 -and
    [int]$canaries.actual_production_authorization_function_execution_count -eq 6 -and
    [int]$canaries.positive_authorization_canary_count -eq 3 -and
    [int]$canaries.mutated_binding_refusal_canary_count -eq 3 -and
    [int]$canaries.content_addressed_input_count -eq 76 -and
    [int]$canaries.physical_process_launch_count -eq 0 -and
    [int]$canaries.world_attempt_count -eq 0 -and
    [int]$canaries.world_build_count -eq 0
) "QSDK-R23D16 authorization canary receipt changed"
Assert-R23D16Closure (
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
    [int]$evaluation.world_attempt_count -eq 9 -and
    [int]$evaluation.world_build_count -eq 9 -and
    [int]$evaluation.outcome_failure_count -eq 0
) "QSDK-R23D16 immutable completion changed"

$cellEvaluations = @($evaluation.cell_evaluations)
$godotFailures = @($cellEvaluations | Where-Object {
    [string]$_.engine_id -ceq "godot_jolt" -and
    [string]$_.entry_kind -ceq "worker_failure" -and
    @($_.failure_codes).Count -eq 1 -and
    [string]$_.failure_codes[0] -ceq "QSDK_R23D16_GJT_TRACE_INCOMPLETE" -and
    [int]$_.world_attempt_count -eq 1 -and
    [int]$_.world_build_count -eq 1
})
$rapierFailures = @($cellEvaluations | Where-Object {
    [string]$_.engine_id -ceq "rapier_parry" -and
    [string]$_.entry_kind -ceq "worker_failure" -and
    @($_.failure_codes).Count -eq 1 -and
    ([string]$_.failure_codes[0]).Contains("R23D16_TRACE_CAS_PUBLICATION_FAILED") -and
    ([string]$_.failure_codes[0]).Contains("trace publisher repository root mismatch") -and
    ([string]$_.failure_codes[0]).Contains('\\?\C:\') -and
    [int]$_.world_attempt_count -eq 1 -and
    [int]$_.world_build_count -eq 1
})
$mujocoPasses = @($cellEvaluations | Where-Object {
    [string]$_.engine_id -ceq "mujoco" -and
    [string]$_.entry_kind -ceq "cell_report" -and
    [bool]$_.entry_valid -and
    [bool]$_.execution_integrity_passed -and
    [bool]$_.outcome.walking_and_taper_gate_passed -and
    [bool]$_.outcome.signed_yaw_response_passed -and
    [bool]$_.outcome.outcome_gate_passed -and
    @($_.outcome.failed_gate_ids).Count -eq 0
})
Assert-R23D16Closure (
    $cellEvaluations.Count -eq 9 -and
    $godotFailures.Count -eq 3 -and
    $rapierFailures.Count -eq 3 -and
    $mujocoPasses.Count -eq 3
) "QSDK-R23D16 engine-cell classification changed"

foreach ($cell in @($closure.engine_observations.godot_jolt.cell_results)) {
    $cellRoot = Join-Path $EvidenceRoot ("matrix\" + [string]$cell.cell_id)
    $terminal = Get-Content -Raw -LiteralPath (Join-Path $cellRoot "terminal-entry.json") |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R23D16Closure (
        (Get-R23D16ClosureRawSha256 (Join-Path $cellRoot "terminal-entry.json")) -ceq
            [string]$cell.terminal_entry_raw_sha256 -and
        [string]$terminal.failure_code -ceq "QSDK_R23D16_GJT_TRACE_INCOMPLETE" -and
        [int]$terminal.trace_artifact.observed_trace_row_count -eq 2992 -and
        [string]$terminal.trace_artifact.observed_trace_value_type -ceq "Array" -and
        @($terminal.trace_artifact.trace_failure_codes).Count -eq 1 -and
        [string]$terminal.trace_artifact.trace_failure_codes[0] -ceq
            "R23D13_GJT_TRACE_AUTHORITY_INPUT_INVALID"
    ) "QSDK-R23D16 retained Godot diagnostic changed: $($cell.cell_id)"
}

foreach ($engine in @("rapier_parry", "mujoco")) {
    foreach ($cell in @($closure.engine_observations[$engine].cell_results)) {
        $cellId = [string]$cell.cell_id
        $cellRoot = Join-Path $EvidenceRoot ("matrix\" + $cellId)
        $terminalPath = Join-Path $cellRoot "terminal-entry.json"
        $traceName = "finite_three_engine_confirmation_recovery__${cellId}.ndjson"
        $tracePath = Join-Path $EvidenceRoot ("traces\" + $traceName)
        $traceLines = @(Get-Content -LiteralPath $tracePath)
        $firstRow = $traceLines[0] | ConvertFrom-Json -AsHashtable -Depth 64
        $lastRow = $traceLines[-1] | ConvertFrom-Json -AsHashtable -Depth 64
        Assert-R23D16Closure (
            (Get-R23D16ClosureRawSha256 $terminalPath) -ceq
                [string]$cell.terminal_entry_raw_sha256 -and
            (Get-R23D16ClosureRawSha256 $tracePath) -ceq
                [string]$cell.trace_raw_sha256 -and
            $traceLines.Count -eq 3952 -and
            [string]$firstRow.schema_version -ceq
                "sporespore_qsdk_r23d16_physical_trace_row_v1" -and
            [int]$firstRow.trace_step -eq 0 -and
            [int]$lastRow.trace_step -eq 3951
        ) "QSDK-R23D16 retained trace changed: $cellId"
        if ($engine -ceq "rapier_parry") {
            $pendingName = "finite_three_engine_confirmation_recovery__${cellId}.rows.json"
            Assert-R23D16Closure (
                (Get-R23D16ClosureRawSha256 (
                    Join-Path $EvidenceRoot ("pending-traces\" + $pendingName)
                )) -ceq [string]$cell.pending_rows_raw_sha256
            ) "QSDK-R23D16 retained Rapier row array changed: $cellId"
        }
    }
}

$mujocoExpected = [ordered]@{
    "mujoco__tight_gated_horizon__reference_zero" = @(-0.023413046951688887, 1.8258584631527954)
    "mujoco__tight_gated_horizon__positive_heading" = @(0.0842283890494393, 1.8947454902875067)
    "mujoco__tight_gated_horizon__negative_heading" = @(-0.15257912436083565, 1.861559698005158)
}
foreach ($cell in @($closure.engine_observations.mujoco.cell_results)) {
    $expected = $mujocoExpected[[string]$cell.cell_id]
    Assert-R23D16Closure (
        $null -ne $expected -and
        [double]$cell.turn_phase_yaw_delta_rad -eq [double]$expected[0] -and
        [double]$cell.final_forward_displacement_m -eq [double]$expected[1]
    ) "QSDK-R23D16 retained MuJoCo scalar changed: $($cell.cell_id)"
}

$supervisorText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "run_qsdk_r23d16_supervisor.ps1"
)
$mujocoWorkerText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot (
        "adapters\mujoco\sporespore_mujoco_adapter\qsdk_r23d16_physical.py"
    )
)
$rapierWorkerText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d3_phase_balanced\r23d16_physical.rs"
)
$godotWorkerText = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "tests\test_sdk_qsdk_r23d16_godot_jolt_physical_worker.gd"
)
$conformanceText = Get-Content -Raw -LiteralPath (Join-Path $sdkRoot "run_conformance.ps1")
Assert-R23D16Closure (
    $supervisorText.Contains("r23d16_physical_closure_v1.json") -and
    $supervisorText.Contains("QSDK-R23D16 CLOSED") -and
    $mujocoWorkerText.Contains("QSDK_R23D16_MJC_CLOSED") -and
    $rapierWorkerText.Contains("QSDK_R23D16_RAP_CLOSED") -and
    $godotWorkerText.Contains("QSDK_R23D16_GJT_CLOSED") -and
    $conformanceText.Contains("tests\test_qsdk_r23d16_closure.ps1") -and
    -not $conformanceText.Contains("run_qsdk_r23d16_zero_world_gate.ps1")
) "QSDK-R23D16 closure routing changed"

$evidenceParent = Split-Path -Parent $EvidenceRoot
$priorRoots = @(Get-ChildItem -LiteralPath $evidenceParent -Directory | Where-Object {
    $_.Name.StartsWith("qsdk-r23d16-", [StringComparison]::Ordinal) -and
    (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json"))
})
$refusalOutput = @(& pwsh -NoLogo -NoProfile -File (
    Join-Path $sdkRoot "run_qsdk_r23d16_supervisor.ps1"
) -RunPhysical -FullConformanceAttestation $attestationPath 2>&1)
$refusalExit = $LASTEXITCODE
$refusalText = @($refusalOutput | ForEach-Object { [string]$_ }) -join "`n"
$afterRoots = @(Get-ChildItem -LiteralPath $evidenceParent -Directory | Where-Object {
    $_.Name.StartsWith("qsdk-r23d16-", [StringComparison]::Ordinal) -and
    (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json"))
})
Assert-R23D16Closure (
    $refusalExit -ne 0 -and
    $refusalText.Contains("QSDK_R23D16_PHYSICAL_REFUSAL") -and
    $refusalText.Contains('"reason":"r23d16_identity_closed"') -and
    $refusalText.Contains("QSDK-R23D16 CLOSED") -and
    $priorRoots.Count -eq 1 -and
    $afterRoots.Count -eq 1 -and
    $afterRoots[0].FullName -ceq $priorRoots[0].FullName
) "QSDK-R23D16 same-identity refusal changed"

Assert-R23D16Closure (
    -not [bool]$closure.immutable_completion_record.scientific_positive -and
    -not [bool]$closure.immutable_completion_record.scientific_negative -and
    [bool]$closure.claims.finite_mujoco_reference_walking_and_taper -and
    [bool]$closure.claims.finite_mujoco_bilateral_signed_turning_cells -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    -not [bool]$closure.claims.command_conditioned_turning -and
    -not [bool]$closure.claims.bilateral_signed_turning -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "QSDK-R23D16 claim boundary changed"

$global:LASTEXITCODE = 0
Write-Host (
    "QSDK_R23D16_CLOSURE_PASS status=invalid matrix=3/9-valid " +
    "godot_worker_failures=3 rapier_worker_failures=3 mujoco_passes=3 " +
    "mujoco_rows=11856 rapier_retained_rows=11856 evaluator_worlds=9 " +
    "evidence_files=$($tree.file_count) evidence_bytes=$($tree.total_byte_length) " +
    "cas_files=60 same_identity_refusal=1 same_identity_rerun=False " +
    "turning=False equivalence=False physical_authority=False"
)

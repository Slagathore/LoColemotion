#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r23d17-20260811T212712Z"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot "turning\r23d17_physical_closure_v1.json"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$campaignId = (
    "QSDK-R23D17-LIVE-COMPOSITION-RECOVERY-" +
    "THREE-ENGINE-TURN-CONFIRMATION"
)
$gateId = "QSDK-R23D17"
$sourceCommit = "d1f247b6147dabfd05123b1242bc650de3905f9a"
$sourceTree = "34b10c3ada46b99181aa90e41eac630047b0239a"
$attemptId = "b976ca419b4c47d0a3aa2d8dc5c21453"
$traceStem = "finite_three_engine_confirmation_live_composition_recovery"

. $artifactStorePath

function Assert-R23D17Closure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D17ClosureRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D17ClosureBytesSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D17GitBlobRawSha256 {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$RelativePath
    )
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = "git"
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $RepoRoot, "cat-file", "blob", "${Commit}:$RelativePath"
    )) {
        [void]$startInfo.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        Assert-R23D17Closure $process.Start() (
            "QSDK-R23D17 could not start Git blob reader: $RelativePath"
        )
        $standardErrorTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try {
            $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream)
        } finally {
            $hasher.Dispose()
        }
        $process.WaitForExit()
        $standardError = $standardErrorTask.GetAwaiter().GetResult()
        Assert-R23D17Closure ($process.ExitCode -eq 0) (
            "QSDK-R23D17 could not read Git blob $RelativePath`: " +
            $standardError.Trim()
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally {
        $process.Dispose()
    }
}

function Get-R23D17ClosureEvidenceTree {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse | Sort-Object {
        $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
    })
    $lines = @($files | ForEach-Object {
        $relative = $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
        "{0}`t{1}`t{2}" -f $relative, $_.Length, (
            Get-R23D17ClosureRawSha256 $_.FullName
        ).Substring(7)
    })
    $projection = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n") + "`n")
    return [ordered]@{
        files = $files
        file_count = $files.Count
        total_byte_length = [int64](($files | Measure-Object Length -Sum).Sum)
        raw_sha256 = Get-R23D17ClosureBytesSha256 $projection
    }
}

function Test-R23D17ClosureCasArtifact {
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

function Assert-R23D17ClosureFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][string]$Label
    )
    Assert-R23D17Closure (Test-Path -LiteralPath $Path -PathType Leaf) (
        "QSDK-R23D17 retained file is missing: $Label"
    )
    $item = Get-Item -LiteralPath $Path
    Assert-R23D17Closure (
        (Get-R23D17ClosureRawSha256 $Path) -ceq $ExpectedSha256 -and
        (Test-R23D17ClosureCasArtifact `
            -ExpectedSha256 $ExpectedSha256 `
            -ExpectedByteLength ([long]$item.Length))
    ) "QSDK-R23D17 retained file or CAS object changed: $Label"
}

Assert-R23D17Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D17 closure repository identity mismatch"
Assert-R23D17Closure (
    (git -C $repoRoot rev-parse ($sourceCommit + "^{tree}")) -ceq $sourceTree
) "QSDK-R23D17 frozen source tree is unavailable"
Assert-R23D17Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "QSDK-R23D17 closure is missing"
)
Assert-R23D17Closure (Test-Path -LiteralPath $EvidenceRoot -PathType Container) (
    "QSDK-R23D17 retained attempt root is missing"
)

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D17Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d17_physical_confirmation_closure_v1" -and
    [string]$closure.status -ceq (
        "closed_consumed_invalid_complete_matrix_three_godot_evaluator_" +
        "receipt_failures_three_valid_rapier_negatives_three_valid_" +
        "mujoco_positives"
    ) -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.source_identity.commit -ceq $sourceCommit -and
    [string]$closure.source_identity.tree_git_oid -ceq $sourceTree -and
    [int]$closure.source_identity.declared_source_binding_count -eq 115 -and
    [int]$closure.source_identity.declared_worker_dependency_count -eq 77 -and
    -not [bool]$closure.source_identity.controller_or_physics_changed_by_closure
) "QSDK-R23D17 closure identity changed"

$tree = Get-R23D17ClosureEvidenceTree -Root $EvidenceRoot
Assert-R23D17Closure (
    $tree.file_count -eq 66 -and
    $tree.file_count -eq [int]$closure.attempt.evidence_file_count -and
    $tree.total_byte_length -eq 161044650 -and
    $tree.total_byte_length -eq [int64]$closure.attempt.evidence_total_byte_length -and
    [string]$tree.raw_sha256 -ceq
        [string]$closure.attempt.evidence_tree_raw_sha256
) "QSDK-R23D17 retained evidence tree changed"
foreach ($file in @($tree.files)) {
    $sha256 = Get-R23D17ClosureRawSha256 $file.FullName
    Assert-R23D17Closure (
        Test-R23D17ClosureCasArtifact `
            -ExpectedSha256 $sha256 `
            -ExpectedByteLength ([long]$file.Length)
    ) "QSDK-R23D17 attempt file is not retained in CAS: $($file.FullName)"
}

$attestationPath = [string]$closure.full_godot_attestation.path
Assert-R23D17ClosureFile $attestationPath `
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
    Assert-R23D17ClosureFile `
        (Join-Path $EvidenceRoot $relative) `
        ([string]$expectedAttemptFiles[$relative]) `
        $relative
}

$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
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
$sourceBindings = @($freeze.source_bindings)
$sourceReceipts = @($freeze.content_addressed_inputs.source_bindings)
Assert-R23D17Closure (
    $sourceBindings.Count -eq 115 -and
    $sourceReceipts.Count -eq 115 -and
    @($sourceBindings.path | Sort-Object -Unique).Count -eq 115
) "QSDK-R23D17 frozen source-binding inventory changed"
for ($index = 0; $index -lt $sourceBindings.Count; $index++) {
    $binding = $sourceBindings[$index]
    $receipt = $sourceReceipts[$index]
    $relativePath = [string]$binding.path
    $blobOid = (& git -C $repoRoot rev-parse (
        "${sourceCommit}:$relativePath"
    )).Trim()
    Assert-R23D17Closure (
        $LASTEXITCODE -eq 0 -and
        $blobOid -ceq [string]$binding.git_blob_oid -and
        (Get-R23D17GitBlobRawSha256 `
            -RepoRoot $repoRoot `
            -Commit $sourceCommit `
            -RelativePath $relativePath) -ceq [string]$binding.raw_sha256 -and
        [bool]$binding.raw_checkout_equals_git_blob -and
        [string]$receipt.sha256 -ceq [string]$binding.raw_sha256 -and
        (Test-R23D17ClosureCasArtifact `
            -ExpectedSha256 ([string]$receipt.sha256) `
            -ExpectedByteLength ([long]$receipt.byte_length))
    ) "QSDK-R23D17 frozen source binding changed: $relativePath"
}
Assert-R23D17Closure (
    [bool]$attestation.conformance.passed -and
    [bool]$attestation.conformance.godot_including -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [bool]$attestation.source.clean_pushed_live -and
    -not [bool]$attestation.conformance.one_shot_physical_campaign_executed
) "QSDK-R23D17 full Godot attestation changed"
Assert-R23D17Closure (
    [bool]$freeze.production_authorization_canaries_valid -and
    [int]$canaries.engine_count -eq 3 -and
    [int]$canaries.worker_process_launch_count -eq 6 -and
    [int]$canaries.actual_production_authorization_function_execution_count -eq 6 -and
    [int]$canaries.positive_authorization_canary_count -eq 3 -and
    [int]$canaries.mutated_binding_refusal_canary_count -eq 3 -and
    [int]$canaries.content_addressed_input_count -eq 77 -and
    [int]$canaries.physical_process_launch_count -eq 0 -and
    [int]$canaries.world_attempt_count -eq 0 -and
    [int]$canaries.world_build_count -eq 0
) "QSDK-R23D17 authorization canary receipt changed"
Assert-R23D17Closure (
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
    [int]$evaluation.outcome_failure_count -eq 3
) "QSDK-R23D17 immutable completion changed"

$cellEvaluations = @($evaluation.cell_evaluations)
$godotInvalid = @($cellEvaluations | Where-Object {
    [string]$_.engine_id -ceq "godot_jolt" -and
    [string]$_.entry_kind -ceq "cell_report" -and
    -not [bool]$_.entry_valid -and
    -not [bool]$_.execution_integrity_passed -and
    @($_.failure_codes).Count -eq 1 -and
    [string]$_.failure_codes[0] -ceq "R23D17_TRACE_ARTIFACT_RECEIPT"
})
$rapierNegative = @($cellEvaluations | Where-Object {
    [string]$_.engine_id -ceq "rapier_parry" -and
    [string]$_.entry_kind -ceq "cell_report" -and
    [bool]$_.entry_valid -and
    [bool]$_.execution_integrity_passed -and
    [bool]$_.outcome.signed_yaw_response_passed -and
    -not [bool]$_.outcome.outcome_gate_passed
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
Assert-R23D17Closure (
    $cellEvaluations.Count -eq 9 -and
    $godotInvalid.Count -eq 3 -and
    $rapierNegative.Count -eq 3 -and
    $mujocoPasses.Count -eq 3
) "QSDK-R23D17 engine-cell classification changed"

$rapierExpectedFailures = [ordered]@{
    "rapier_parry__tight_gated_horizon__reference_zero" = @(
        "R23D17_QUIESCENT_TAPER"
    )
    "rapier_parry__tight_gated_horizon__positive_heading" = @(
        "R23D17_QUIESCENT_TAPER"
    )
    "rapier_parry__tight_gated_horizon__negative_heading" = @(
        "R23D17_MAXIMUM_TILT",
        "R23D17_MINIMUM_TORSO_HEIGHT",
        "R23D17_CONTACT_CYCLES:front_left",
        "R23D17_CONTACT_CYCLES:front_right",
        "R23D17_TORSO_GROUND_CONTACT",
        "R23D17_QUIESCENT_TAPER"
    )
}
foreach ($cell in $rapierNegative) {
    $expected = @($rapierExpectedFailures[[string]$cell.cell_id])
    $actual = @($cell.outcome.failed_gate_ids)
    Assert-R23D17Closure (
        $null -ne $expected -and
        $actual.Count -eq $expected.Count -and
        @(Compare-Object $expected $actual -SyncWindow 0).Count -eq 0
    ) "QSDK-R23D17 Rapier negative changed: $($cell.cell_id)"
}

foreach ($engine in @("godot_jolt", "rapier_parry", "mujoco")) {
    foreach ($cell in @($closure.engine_observations[$engine].cell_results)) {
        $cellId = [string]$cell.cell_id
        $cellRoot = Join-Path $EvidenceRoot ("matrix\" + $cellId)
        $terminalPath = Join-Path $cellRoot "terminal-entry.json"
        $tracePath = Join-Path $EvidenceRoot (
            "traces\${traceStem}__${cellId}.ndjson"
        )
        $pendingPath = Join-Path $EvidenceRoot (
            "pending-traces\${traceStem}__${cellId}.rows.json"
        )
        $terminal = Get-Content -Raw -LiteralPath $terminalPath |
            ConvertFrom-Json -AsHashtable -Depth 100
        Assert-R23D17Closure (
            (Get-R23D17ClosureRawSha256 $terminalPath) -ceq
                [string]$cell.terminal_entry_raw_sha256 -and
            (Get-R23D17ClosureRawSha256 $tracePath) -ceq
                [string]$cell.trace_raw_sha256 -and
            (Get-R23D17ClosureRawSha256 $pendingPath) -ceq
                [string]$cell.pending_rows_raw_sha256 -and
            [int]$terminal.trace_summary.row_count -eq 3952 -and
            [int]$terminal.execution.world_attempt_count -eq 1 -and
            [int]$terminal.execution.world_build_count -eq 1 -and
            [bool]$terminal.execution.integrity_passed
        ) "QSDK-R23D17 retained cell evidence changed: $cellId"
        if ($engine -ceq "godot_jolt") {
            Assert-R23D17Closure (
                $terminal.trace_artifact.byte_length.GetType() -eq [double] -and
                [long]$terminal.trace_artifact.byte_length -eq
                    [long]$cell.trace_byte_length -and
                [string]$terminal.trace_artifact.sha256 -ceq
                    [string]$cell.trace_raw_sha256
            ) "QSDK-R23D17 Godot receipt type mechanism changed: $cellId"
        }
    }
}

$mujocoExpected = [ordered]@{
    "mujoco__tight_gated_horizon__reference_zero" = @(
        -0.023413046951688887, 1.8258584631527954
    )
    "mujoco__tight_gated_horizon__positive_heading" = @(
        0.0842283890494393, 1.8947454902875067
    )
    "mujoco__tight_gated_horizon__negative_heading" = @(
        -0.15257912436083565, 1.861559698005158
    )
}
foreach ($cell in @($closure.engine_observations.mujoco.cell_results)) {
    $expected = $mujocoExpected[[string]$cell.cell_id]
    Assert-R23D17Closure (
        $null -ne $expected -and
        [double]$cell.turn_phase_yaw_delta_rad -eq [double]$expected[0] -and
        [double]$cell.final_forward_displacement_m -eq [double]$expected[1]
    ) "QSDK-R23D17 retained MuJoCo scalar changed: $($cell.cell_id)"
}

$supervisorText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "run_qsdk_r23d17_supervisor.ps1"
)
$mujocoWorkerText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot (
        "adapters\mujoco\sporespore_mujoco_adapter\qsdk_r23d17_physical.py"
    )
)
$rapierWorkerText = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d3_phase_balanced\r23d17_physical.rs"
)
$godotWorkerText = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "tests\test_sdk_qsdk_r23d17_godot_jolt_physical_worker.gd"
)
$conformanceText = Get-Content -Raw -LiteralPath (Join-Path $sdkRoot "run_conformance.ps1")
Assert-R23D17Closure (
    $supervisorText.Contains("r23d17_physical_closure_v1.json") -and
    $supervisorText.Contains("QSDK-R23D17 CLOSED") -and
    $mujocoWorkerText.Contains("QSDK_R23D17_MJC_CLOSED") -and
    $rapierWorkerText.Contains("QSDK_R23D17_RAP_CLOSED") -and
    $godotWorkerText.Contains("QSDK_R23D17_GJT_CLOSED") -and
    $conformanceText.Contains("tests\test_qsdk_r23d17_closure.ps1") -and
    -not $conformanceText.Contains("run_qsdk_r23d17_zero_world_gate.ps1")
) "QSDK-R23D17 closure routing changed"

$evidenceParent = Split-Path -Parent $EvidenceRoot
$priorRoots = @(Get-ChildItem -LiteralPath $evidenceParent -Directory | Where-Object {
    $_.Name.StartsWith("qsdk-r23d17-", [StringComparison]::Ordinal) -and
    (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json"))
})
$refusalOutput = @(& pwsh -NoLogo -NoProfile -File (
    Join-Path $sdkRoot "run_qsdk_r23d17_supervisor.ps1"
) -RunPhysical -FullConformanceAttestation $attestationPath 2>&1)
$refusalExit = $LASTEXITCODE
$refusalText = @($refusalOutput | ForEach-Object { [string]$_ }) -join "`n"
$afterRoots = @(Get-ChildItem -LiteralPath $evidenceParent -Directory | Where-Object {
    $_.Name.StartsWith("qsdk-r23d17-", [StringComparison]::Ordinal) -and
    (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json"))
})
Assert-R23D17Closure (
    $refusalExit -ne 0 -and
    $refusalText.Contains("QSDK_R23D17_PHYSICAL_REFUSAL") -and
    $refusalText.Contains('"reason":"r23d17_identity_closed"') -and
    $refusalText.Contains("QSDK-R23D17 CLOSED") -and
    $priorRoots.Count -eq 1 -and
    $afterRoots.Count -eq 1 -and
    $afterRoots[0].FullName -ceq $priorRoots[0].FullName
) "QSDK-R23D17 same-identity refusal changed"

Assert-R23D17Closure (
    -not [bool]$closure.immutable_completion_record.scientific_positive -and
    -not [bool]$closure.immutable_completion_record.scientific_negative -and
    [bool]$closure.claims.r23d16_godot_live_terminal_authority_defect_fixed -and
    [bool]$closure.claims.r23d16_rapier_extended_path_publication_defect_fixed -and
    [bool]$closure.claims.finite_rapier_execution_valid_signed_yaw_cells -and
    -not [bool]$closure.claims.finite_rapier_outcome_positive -and
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
) "QSDK-R23D17 claim boundary changed"

$global:LASTEXITCODE = 0
Write-Host (
    "QSDK_R23D17_CLOSURE_PASS status=invalid matrix=6/9-valid " +
    "godot_evaluator_invalid=3 rapier_valid_negatives=3 mujoco_passes=3 " +
    "godot_rows=11856 rapier_rows=11856 mujoco_rows=11856 evaluator_worlds=9 " +
    "evidence_files=$($tree.file_count) evidence_bytes=$($tree.total_byte_length) " +
    "cas_files=66 same_identity_refusal=1 same_identity_rerun=False " +
    "turning=False equivalence=False physical_authority=False"
)

#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunRecovery
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Write-NewUtf8TextFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    $stream = [IO.File]::Open(
        $Path,
        [IO.FileMode]::CreateNew,
        [IO.FileAccess]::Write,
        [IO.FileShare]::None
    )
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    }
    finally {
        $stream.Dispose()
    }
}

function Write-NewJsonFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Value
    )
    Write-NewUtf8TextFile -Path $Path -Text (
        ($Value | ConvertTo-Json -Depth 100) + [Environment]::NewLine
    )
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Get-EvidenceTreeDigest {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse)
    $lines = foreach ($file in @(
        $files | Sort-Object {
            $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
        }
    )) {
        $relativePath = $file.FullName.Substring(
            $Root.Length + 1
        ).Replace("\", "/")
        "$relativePath`t$($file.Length)`t$(Get-RawSha256 $file.FullName)"
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
    }
}

function Get-ValidatedHistoricalFullGodotAttestation {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][object]$Protocol,
        [Parameter(Mandatory)][string]$PhysicalSource,
        [Parameter(Mandatory)][string]$PhysicalTree,
        [Parameter(Mandatory)][string]$AttestationPath,
        [Parameter(Mandatory)][string]$RecoveryId
    )
    $attestation = Get-Content -Raw -LiteralPath $AttestationPath |
        ConvertFrom-Json -AsHashtable -Depth 128
    $godotPath = [IO.Path]::GetFullPath(
        [string]$attestation.godot.executable_path
    )
    Assert-Exact (
        (Get-Item -LiteralPath $AttestationPath).Length -eq
            [long]$Protocol.full_godot_v2_attestation.size_bytes -and
        (Get-RawSha256 $AttestationPath) -ceq
            [string]$Protocol.full_godot_v2_attestation.raw_sha256 -and
        [string]$attestation.schema_version -ceq
            "sporespore_full_godot_conformance_attestation_v2" -and
        [string]$attestation.status -ceq "full_godot_conformance_passed" -and
        -not [bool]$attestation.test_only -and
        [string]$attestation.conformance.runner -ceq
            "sdk/run_conformance.ps1" -and
        -not [bool]$attestation.conformance.skip_godot -and
        [bool]$attestation.conformance.godot_including -and
        [bool]$attestation.conformance.passed -and
        -not [bool]$attestation.conformance.one_shot_physical_campaign_executed -and
        [double]$attestation.conformance.duration_seconds -eq
            [double]$Protocol.full_godot_v2_attestation.duration_seconds -and
        [string]$attestation.source.repository_root -ceq $RepoRoot -and
        [string]$attestation.source.remote_url -ceq
            "https://github.com/Slagathore/sporespore.git" -and
        [string]$attestation.source.commit -ceq $PhysicalSource -and
        [string]$attestation.source.tree_git_oid -ceq $PhysicalTree -and
        [string]$attestation.source.origin_main -ceq $PhysicalSource -and
        [string]$attestation.source.live_github_main -ceq $PhysicalSource -and
        [bool]$attestation.source.worktree_clean -and
        [bool]$attestation.source.clean_pushed_live -and
        $null -eq $attestation.source.status_entries -and
        [bool]$attestation.operation_lock.acquired -and
        [string]$attestation.operation_lock.role -ceq "conformance" -and
        -not [bool]$attestation.claims.new_physical_campaign_executed -and
        -not [bool]$attestation.claims.new_scientific_outcome_exposed -and
        -not [bool]$attestation.claims.physical_acceptance_authority -and
        -not [bool]$attestation.claims.release_authorized -and
        -not [bool]$attestation.claims.completed_engine_neutral_sdk -and
        (Test-Path -LiteralPath $godotPath -PathType Leaf) -and
        ("sha256:" + (Get-RawSha256 $godotPath)) -ceq
            [string]$attestation.godot.executable_sha256
    ) "$RecoveryId frozen historical full-Godot V2 attestation changed"
    $attestationBindings = @($attestation.source_bindings)
    Assert-Exact ($attestationBindings.Count -eq 4) (
        "$RecoveryId historical full-Godot source-binding count changed"
    )
    foreach ($binding in $attestationBindings) {
        $bindingPath = [string]$binding.path
        $historicalBlob = (
            git -C $RepoRoot rev-parse ($PhysicalSource + ":" + $bindingPath)
        ).Trim()
        Assert-Exact (
            $LASTEXITCODE -eq 0 -and
            $historicalBlob -ceq [string]$binding.git_blob_oid
        ) "$RecoveryId historical attestation source binding changed: $bindingPath"
    }
    return $attestation
}

Assert-Exact (
    $PreflightOnly.IsPresent -xor $RunRecovery.IsPresent
) "Specify exactly one of -PreflightOnly or -RunRecovery"

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$python = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$rapierBinary = Join-Path $sdkRoot (
    "target\release\cross_engine_discrete_material_validation_xv2_rapier.exe"
)
$protocolPath = Join-Path $sdkRoot (
    "cross_engine_c6_bw19v_discrete_material_validation_xv2_" +
    "aggregate_recovery_protocol.json"
)
$preregistrationPath = Join-Path $sdkRoot (
    "cross_engine_c6_bw19v_discrete_material_validation_xv2_preregistration.json"
)
$gatePath = Join-Path $sdkRoot (
    "cross_engine_c6_bw19v_discrete_material_validation_xv2_gate.ps1"
)
$projectionPath = Join-Path $sdkRoot (
    "cross_engine_c6_bw19v_discrete_material_validation_xv2_" +
    "supervisor_projection.ps1"
)
$reconstructionPath = Join-Path $sdkRoot (
    "cross_engine_c6_bw19v_discrete_material_validation_xv2_" +
    "aggregate_reconstruction.ps1"
)
$physicalRunnerPath = Join-Path $sdkRoot (
    "run_cross_engine_c6_bw19v_discrete_material_validation_xv2.ps1"
)
$rapierWorkerSourcePath = Join-Path $sdkRoot (
    "adapters\rapier\src\cross_engine_discrete_material_validation_xv2_rapier.rs"
)
$rapierEntrypointSourcePath = Join-Path $sdkRoot (
    "adapters\rapier\src\bin\cross_engine_discrete_material_validation_xv2_rapier.rs"
)
$mujocoWorkerSourcePath = Join-Path $sdkRoot (
    "adapters\mujoco\sporespore_mujoco_adapter\" +
    "cross_engine_discrete_material_validation_xv2_mujoco.py"
)
$attemptRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "c6-cross-engine-bw19v-xv2-e00ec7a"
)
$campaignId = "C6-CROSS-ENGINE-BW19V-DISCRETE-MATERIAL-VALIDATION-XV2"
$gateId = "C6-XE-BW19V-XV2"
$recoveryId = "C6-XE-BW19V-XV2-AGGREGATE-RECOVERY-R1"
$recoveryAttemptPath = Join-Path $attemptRoot "aggregate_recovery_attempt_v1.json"
$reconstructionOutputPath = Join-Path $attemptRoot "aggregate_reconstruction_v1.json"
$evaluationOutputPath = Join-Path $attemptRoot (
    "aggregate_reconstruction_evaluation_v1.json"
)
$recoveryCompletionPath = Join-Path $attemptRoot (
    "aggregate_recovery_completion_v1.json"
)
$originalAggregateReportPath = Join-Path $attemptRoot "report.json"
$originalAggregateEvaluationPath = Join-Path $attemptRoot "evaluation.json"

. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")
. $gatePath
. $projectionPath
. $reconstructionPath

Assert-Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (Test-Path -LiteralPath $protocolPath -PathType Leaf) -and
    (Test-Path -LiteralPath $attemptRoot -PathType Container)
) "$recoveryId repository or retained-evidence identity changed"

$protocol = Get-Content -Raw -LiteralPath $protocolPath |
    ConvertFrom-Json -AsHashtable -Depth 128
$declaration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 128
Assert-Exact (
    [string]$protocol.schema_version -ceq
        "sporespore_cross_engine_c6_bw19v_discrete_material_validation_xv2_aggregate_recovery_protocol_v1" -and
    [string]$protocol.status -ceq
        "frozen_after_physical_workers_before_zero_world_aggregate_recovery" -and
    [string]$protocol.campaign_id -ceq $campaignId -and
    [string]$protocol.gate_id -ceq $gateId -and
    [string]$protocol.recovery_id -ceq $recoveryId -and
    [string]$declaration.campaign_id -ceq $campaignId -and
    [string]$declaration.gate_id -ceq $gateId
) "$recoveryId protocol or preregistration identity changed"

foreach ($binding in @(
    @($preregistrationPath, [string]$protocol.physical_source.preregistration_raw_sha256),
    @($gatePath, [string]$protocol.physical_source.aggregate_gate_raw_sha256),
    @($projectionPath, [string]$protocol.physical_source.supervisor_projection_raw_sha256),
    @($physicalRunnerPath, [string]$protocol.physical_source.supervisor_raw_sha256),
    @($rapierWorkerSourcePath, [string]$protocol.physical_source.rapier_worker_source_raw_sha256),
    @($rapierEntrypointSourcePath, [string]$protocol.physical_source.rapier_entrypoint_source_raw_sha256),
    @($mujocoWorkerSourcePath, [string]$protocol.physical_source.mujoco_worker_source_raw_sha256)
)) {
    Assert-Exact (
        (Get-RawSha256 -Path ([string]$binding[0])) -ceq
            [string]$binding[1]
    ) "$recoveryId frozen physical source changed: $($binding[0])"
}
$physicalSource = [string]$protocol.physical_source.commit
$physicalTree = [string]$protocol.physical_source.tree_git_oid
$attestationPath = [IO.Path]::GetFullPath(
    ([string]$protocol.full_godot_v2_attestation.path).Replace("/", "\")
)
$attestation = Get-ValidatedHistoricalFullGodotAttestation `
    -RepoRoot $repoRoot `
    -Protocol $protocol `
    -PhysicalSource $physicalSource `
    -PhysicalTree $physicalTree `
    -AttestationPath $attestationPath `
    -RecoveryId $recoveryId

$historicalRunner = Get-Content -Raw -LiteralPath $physicalRunnerPath
Assert-Exact (
    $historicalRunner.Contains(
        "Measure-Object world_attempt_count -Sum",
        [StringComparison]::Ordinal
    ) -and
    $historicalRunner.Contains(
        "Measure-Object world_build_count -Sum",
        [StringComparison]::Ordinal
    ) -and
    $historicalRunner.Contains(
        "Measure-Object world_reset_count -Sum",
        [StringComparison]::Ordinal
    )
) "$recoveryId historical aggregate count failure is no longer reproducible"

$syntheticCells = @(
    1..6 | ForEach-Object {
        [ordered]@{
            world_attempt_count = 1
            world_build_count = 1
            world_reset_count = 0
        }
    }
)
$syntheticCounts = Get-Xv2RecoveredAggregateCounts -CellSummaries $syntheticCells
$syntheticResult = New-Xv2PerfectSyntheticResult
$syntheticEvaluation = Test-CrossEngineC6Bw19vDiscreteMaterialValidationXv2Result $syntheticResult
$countCanary = @($syntheticCells)
$countCanary[5] = [ordered]@{
    world_attempt_count = 2
    world_build_count = 3
    world_reset_count = 1
}
$canaryCounts = Get-Xv2RecoveredAggregateCounts -CellSummaries $countCanary
Assert-Exact (
    [int]$syntheticCounts.world_attempt_count -eq 6 -and
    [int]$syntheticCounts.world_build_count -eq 6 -and
    [int]$syntheticCounts.world_reset_count -eq 0 -and
    [int]$canaryCounts.world_attempt_count -eq 7 -and
    [int]$canaryCounts.world_build_count -eq 8 -and
    [int]$canaryCounts.world_reset_count -eq 1 -and
    [bool]$syntheticEvaluation.accepted
) "$recoveryId explicit aggregate count projection failed"

$recoveryArtifacts = @(
    $recoveryAttemptPath,
    $reconstructionOutputPath,
    $evaluationOutputPath,
    $recoveryCompletionPath
)
if ($PreflightOnly.IsPresent) {
    Assert-Exact (
        @($recoveryArtifacts | Where-Object {
            Test-Path -LiteralPath $_
        }).Count -eq 0 -and
        -not (Test-Path -LiteralPath $originalAggregateReportPath) -and
        -not (Test-Path -LiteralPath $originalAggregateEvaluationPath)
    ) "$recoveryId recovery or original aggregate artifact already exists"
    Write-Host (
        "C6_XE_BW19V_XV2_AGGREGATE_RECOVERY_FREEZE_PASS " +
        "worlds=0 cells=6 count_projection=3 synthetic_gate=12 " +
        "recovery_artifacts=0 physical_authority=False"
    )
    return
}

Assert-Exact (
    @($recoveryArtifacts | Where-Object {
        Test-Path -LiteralPath $_
    }).Count -eq 0
) "$recoveryId is one-shot and has already been reserved or executed"
Assert-Exact (
    -not (Test-Path -LiteralPath $originalAggregateReportPath) -and
    -not (Test-Path -LiteralPath $originalAggregateEvaluationPath)
) "$recoveryId refuses to overwrite or reinterpret an original aggregate"

$head = (git -C $repoRoot rev-parse HEAD).Trim()
$headTree = (git -C $repoRoot rev-parse 'HEAD^{tree}').Trim()
$originMain = (git -C $repoRoot rev-parse origin/main).Trim()
$status = @(git -C $repoRoot status --porcelain=v1 --untracked-files=all)
$remoteLine = @(git -C $repoRoot ls-remote origin refs/heads/main)
$liveMain = if ($remoteLine.Count -eq 1) {
    ($remoteLine[0] -split "\s+")[0]
} else { "" }
& git -C $repoRoot merge-base --is-ancestor $physicalSource $head
$physicalAncestor = $LASTEXITCODE -eq 0
Assert-Exact (
    $head -cmatch '^[0-9a-f]{40}$' -and
    $headTree -cmatch '^[0-9a-f]{40}$' -and
    $head -ceq $originMain -and
    $head -ceq $liveMain -and
    $status.Count -eq 0 -and
    $physicalAncestor -and
    (git -C $repoRoot rev-parse ($physicalSource + '^{tree}')).Trim() -ceq
        $physicalTree
) "$recoveryId requires clean pushed live recovery source and retained physical source"

$tree = Get-EvidenceTreeDigest -Root $attemptRoot
Assert-Exact (
    [int]$tree.file_count -eq
        [int]$protocol.consumed_attempt.original_evidence_tree.file_count -and
    [long]$tree.total_byte_length -eq
        [long]$protocol.consumed_attempt.original_evidence_tree.total_byte_length -and
    [string]$tree.tree_sha256 -ceq
        [string]$protocol.consumed_attempt.original_evidence_tree.tree_sha256
) "$recoveryId original twenty-seven-file evidence tree changed"

$attemptPath = Join-Path $attemptRoot "attempt.json"
$preflightPath = Join-Path $attemptRoot "preflight.json"
$completionPath = Join-Path $attemptRoot "completion.json"
Assert-Exact (
    (Get-RawSha256 $attemptPath) -ceq
        [string]$protocol.consumed_attempt.attempt_raw_sha256 -and
    (Get-RawSha256 $preflightPath) -ceq
        [string]$protocol.consumed_attempt.preflight_raw_sha256 -and
    (Get-RawSha256 $completionPath) -ceq
        [string]$protocol.consumed_attempt.completion_raw_sha256
) "$recoveryId attempt, preflight, or failed completion changed"

$attempt = Get-Content -Raw -LiteralPath $attemptPath |
    ConvertFrom-Json -AsHashtable -Depth 128
$preflight = Get-Content -Raw -LiteralPath $preflightPath |
    ConvertFrom-Json -AsHashtable -Depth 128
$completion = Get-Content -Raw -LiteralPath $completionPath |
    ConvertFrom-Json -AsHashtable -Depth 128
Assert-Exact (
    [string]$attempt.attempt_id -ceq
        [string]$protocol.consumed_attempt.attempt_id -and
    [string]$attempt.source_commit -ceq $physicalSource -and
    [string]$attempt.source_tree_git_oid -ceq $physicalTree -and
    [string]$attempt.source_origin_main -ceq $physicalSource -and
    [string]$attempt.source_live_github_main -ceq $physicalSource -and
    [int]$attempt.declared_world_count -eq 6 -and
    @($attempt.declared_ordered_cells).Count -eq 6 -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    [bool]$attempt.operation_lock.acquired -and
    [string]$attempt.operation_lock.role -ceq "physical" -and
    [bool]$preflight.ok -and
    [int]$preflight.total_negative_control_count -eq 121 -and
    [int]$preflight.model_or_world_build_count -eq 0 -and
    [string]$completion.status -ceq
        "supervisor_failed_after_identity_consumption" -and
    [int]$completion.physical_process_launch_count -eq 6 -and
    [int]$completion.retained_cell_summary_count -eq 6 -and
    [string]$completion.supervisor_failure -ceq
        [string]$protocol.implementation_failure.exception_message -and
    -not [bool]$completion.same_identity_rerun_allowed
) "$recoveryId physical reservation or failed completion boundary changed"

Assert-Exact (
    (Test-Path -LiteralPath $python -PathType Leaf) -and
    (Test-Path -LiteralPath $rapierBinary -PathType Leaf) -and
    (Get-RawSha256 $rapierBinary) -ceq
        ([string]$attempt.rapier_release_worker_raw_sha256).Replace(
            "sha256:", ""
        )
) "$recoveryId exact frozen evaluator dependencies changed"

$operationLockReceipt = Enter-SporeSporeLocomotionOperationLock -Role conformance
Assert-Exact (
    [bool]$operationLockReceipt.acquired -and
    [string]$operationLockReceipt.role -ceq "conformance"
) "$recoveryId could not acquire the serialized zero-world recovery lock"
$recoveryAttemptWritten = $false
try {
    $recoveryAttempt = [ordered]@{
        schema_version = "sporespore_cross_engine_c6_bw19v_xv2_aggregate_recovery_attempt_v1"
        recovery_id = $recoveryId
        campaign_id = $campaignId
        gate_id = $gateId
        status = "zero_world_aggregate_recovery_reserved"
        reserved_utc = [DateTime]::UtcNow.ToString("o")
        recovery_source_commit = $head
        recovery_source_tree_git_oid = $headTree
        physical_source_commit = $physicalSource
        physical_source_tree_git_oid = $physicalTree
        physical_attempt_id = [string]$attempt.attempt_id
        protocol_path = $protocolPath.Replace("\", "/")
        protocol_raw_sha256 = "sha256:" + (Get-RawSha256 $protocolPath)
        original_evidence_tree = $tree
        world_build_count = 0
        physical_worker_process_launch_count = 0
        physical_acceptance_authority = $false
    }
    Write-NewJsonFile -Path $recoveryAttemptPath -Value $recoveryAttempt
    $recoveryAttemptWritten = $true

    $cellSummaries = [System.Collections.Generic.List[object]]::new()
    foreach ($cell in @($declaration.matrix.ordered_cells)) {
        $cellId = [string]$cell.cell_id
        $binding = @($protocol.retained_cells | Where-Object {
            [string]$_.cell_id -ceq $cellId
        })
        Assert-Exact ($binding.Count -eq 1) (
            "$recoveryId retained cell binding changed: $cellId"
        )
        $cellRoot = Join-Path $attemptRoot "cells\$cellId"
        $reportPath = Join-Path $cellRoot "report.json"
        $stdoutPath = Join-Path $cellRoot "stdout.log"
        $stderrPath = Join-Path $cellRoot "stderr.log"
        $coldPath = Join-Path $cellRoot "cold_evaluation.json"
        Assert-Exact (
            (Get-Item -LiteralPath $reportPath).Length -eq
                [long]$binding[0].report_size_bytes -and
            (Get-RawSha256 $reportPath) -ceq
                [string]$binding[0].report_raw_sha256 -and
            (Get-Item -LiteralPath $stdoutPath).Length -eq
                [long]$binding[0].stdout_size_bytes -and
            (Get-RawSha256 $stdoutPath) -ceq
                [string]$binding[0].stdout_raw_sha256 -and
            (Get-RawSha256 $coldPath) -ceq
                [string]$binding[0].cold_evaluation_raw_sha256 -and
            (Get-Item -LiteralPath $stderrPath).Length -eq 0
        ) "$recoveryId retained cell artifacts changed: $cellId"

        $report = Get-Content -Raw -LiteralPath $reportPath |
            ConvertFrom-Json -AsHashtable -Depth 128
        $retainedCold = Get-Content -Raw -LiteralPath $coldPath |
            ConvertFrom-Json -AsHashtable -Depth 128
        $freshLines = @()
        $freshExit = -1
        if ([string]$cell.engine -ceq "rapier") {
            $freshLines = @(& $rapierBinary --evaluate-report $reportPath)
            $freshExit = $LASTEXITCODE
        }
        else {
            Push-Location -LiteralPath $mujocoRoot
            try {
                $freshLines = @(
                    & $python `
                        -m sporespore_mujoco_adapter.cross_engine_discrete_material_validation_xv2_mujoco `
                        --evaluate-report $reportPath
                )
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
        ) "$recoveryId fresh frozen cold replay failed: $cellId"
        $summaryArgs = @{
            Cell = $cell
            WorkerReport = $report
            RetainedColdEvaluation = $retainedCold
            FreshColdEvaluation = $freshCold
            ReportPath = $reportPath
            StdoutPath = $stdoutPath
            StderrPath = $stderrPath
        }
        $cellSummaries.Add(
            (New-Xv2RecoveredCellSummary @summaryArgs)
        )
    }

    $provenance = [ordered]@{
        schema_version = "sporespore_cross_engine_c6_bw19v_xv2_aggregate_reconstruction_provenance_v1"
        recovery_id = $recoveryId
        recovery_source_commit = $head
        recovery_source_tree_git_oid = $headTree
        protocol_raw_sha256 = "sha256:" + (Get-RawSha256 $protocolPath)
        reconstruction_source_raw_sha256 = Get-Xv2RecoveryRawSha256 $reconstructionPath
        original_completion_status = [string]$completion.status
        original_supervisor_failure = [string]$completion.supervisor_failure
        original_aggregate_report_present = $false
        original_aggregate_evaluation_present = $false
        count_repair = (
            "ForEach-Object { [int]`$_.<declared_count_field> } | " +
            "Measure-Object -Sum"
        )
        fresh_cold_replay_count = 6
        world_build_count = 0
        physical_worker_process_launch_count = 0
        threshold_policy_schedule_material_or_claim_change = $false
        physical_acceptance_authority = $false
    }
    $aggregateArgs = @{
        Declaration = $declaration
        Attempt = $attempt
        Attestation = $attestation
        CellSummaries = @($cellSummaries)
        EvidenceRoot = $attemptRoot
        PreregistrationPath = $preregistrationPath
        RecoveryProvenance = $provenance
    }
    $result = New-Xv2RecoveredAggregateResult @aggregateArgs
    $evaluation = Test-CrossEngineC6Bw19vDiscreteMaterialValidationXv2Result $result
    Write-NewJsonFile -Path $reconstructionOutputPath -Value $result
    Write-NewJsonFile -Path $evaluationOutputPath -Value $evaluation

    $recoveryCompletion = [ordered]@{
        schema_version = "sporespore_cross_engine_c6_bw19v_xv2_aggregate_recovery_completion_v1"
        recovery_id = $recoveryId
        campaign_id = $campaignId
        gate_id = $gateId
        physical_attempt_id = [string]$attempt.attempt_id
        recovery_source_commit = $head
        recovery_source_tree_git_oid = $headTree
        completed_utc = [DateTime]::UtcNow.ToString("o")
        status = $(if ([bool]$evaluation.accepted) {
            "complete_frozen_aggregate_reconstruction_accepted"
        } else { "complete_frozen_aggregate_reconstruction_rejected" })
        reconstruction_path = $reconstructionOutputPath.Replace("\", "/")
        reconstruction_raw_sha256 = Get-Xv2RecoveryRawSha256 $reconstructionOutputPath
        evaluation_path = $evaluationOutputPath.Replace("\", "/")
        evaluation_raw_sha256 = Get-Xv2RecoveryRawSha256 $evaluationOutputPath
        accepted = [bool]$evaluation.accepted
        passed_gate_count = @($evaluation.gates | Where-Object passed).Count
        failed_gate_count = @(
            $evaluation.gates | Where-Object { -not $_.passed }
        ).Count
        failure_codes = @($evaluation.failure_codes)
        retained_report_count = 6
        fresh_cold_replay_count = 6
        world_build_count = 0
        physical_worker_process_launch_count = 0
        same_recovery_identity_rerun_allowed = $false
        same_physical_identity_rerun_allowed = $false
        physical_acceptance_authority = $false
    }
    Write-NewJsonFile -Path $recoveryCompletionPath -Value $recoveryCompletion
    Write-Host (
        "C6_XE_BW19V_XV2_AGGREGATE_RECOVERY_COMPLETE " +
        "accepted=$($evaluation.accepted) gates=" +
        "$(@($evaluation.gates | Where-Object passed).Count)/12 " +
        "reports=6 cold_replays=6 worlds=0 physical_authority=False"
    )
    if (-not [bool]$evaluation.accepted) {
        throw (
            "$recoveryId frozen aggregate reconstruction was rejected: " +
            (@($evaluation.failure_codes) -join ",")
        )
    }
}
catch {
    if (
        $recoveryAttemptWritten -and
        -not (Test-Path -LiteralPath $recoveryCompletionPath)
    ) {
        try {
            Write-NewJsonFile -Path $recoveryCompletionPath -Value ([ordered]@{
                schema_version = "sporespore_cross_engine_c6_bw19v_xv2_aggregate_recovery_completion_v1"
                recovery_id = $recoveryId
                campaign_id = $campaignId
                gate_id = $gateId
                recovery_source_commit = $head
                completed_utc = [DateTime]::UtcNow.ToString("o")
                status = "recovery_failed_after_identity_consumption"
                failure = $_.Exception.Message
                world_build_count = 0
                physical_worker_process_launch_count = 0
                same_recovery_identity_rerun_allowed = $false
                same_physical_identity_rerun_allowed = $false
                physical_acceptance_authority = $false
            })
        }
        catch {
            Write-Warning (
                "$recoveryId could not retain its failure completion: " +
                $_.Exception.Message
            )
        }
    }
    throw
}
finally {
    Exit-SporeSporeLocomotionOperationLock -Receipt $operationLockReceipt
}

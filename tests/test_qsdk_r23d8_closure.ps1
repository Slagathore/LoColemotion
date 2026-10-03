#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r23d8-20260809T045356Z"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot "turning\r23d8_physical_closure_v1.json"
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d8_supervisor.ps1"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$campaignId = (
    "QSDK-R23D8-AUTHORIZATION-CLOSED-NEUTRAL-STANCE-" +
    "BILATERAL-TURN-DEVELOPMENT"
)
$gateId = "QSDK-R23D8"
$sourceCommit = "841a4382cefa27ab2d679b4faae966c6dd29d40a"
$sourceTree = "6133e3313fc21ae289e284edb196a2b4f73811fc"

. $artifactStorePath

function Assert-R23D8Closure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D8ClosureRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D8ClosureBytesSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D8ClosureEvidenceTree {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse | Sort-Object {
        $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
    })
    $lines = @($files | ForEach-Object {
        $relative = $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
        "{0}`t{1}`t{2}" -f $relative, $_.Length, (
            Get-R23D8ClosureRawSha256 $_.FullName
        ).Substring(7)
    })
    $projection = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n") + "`n")
    return [ordered]@{
        files = $files
        file_count = $files.Count
        total_byte_length = [int64](($files | Measure-Object Length -Sum).Sum)
        raw_sha256 = Get-R23D8ClosureBytesSha256 $projection
    }
}

function Get-R23D8ClosureGitBlob {
    param(
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$Path
    )
    $spec = "$Commit`:$Path"
    $oid = (& git -C $repoRoot rev-parse $spec 2>$null).Trim()
    Assert-R23D8Closure (
        $LASTEXITCODE -eq 0 -and $oid -match '^[0-9a-f]{40}$'
    ) "QSDK-R23D8 historical Git blob is unavailable: $spec"
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    [void]$start.ArgumentList.Add("cat-file")
    [void]$start.ArgumentList.Add("blob")
    [void]$start.ArgumentList.Add($spec)
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-R23D8Closure $process.Start() "QSDK-R23D8 could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D8Closure ($process.ExitCode -eq 0) (
            "QSDK-R23D8 git cat-file failed for $spec`: $stderr"
        )
        $bytes = $memory.ToArray()
        return [ordered]@{
            oid = $oid
            byte_length = $bytes.Length
            raw_sha256 = Get-R23D8ClosureBytesSha256 $bytes
            text = [Text.Encoding]::UTF8.GetString($bytes)
        }
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Get-R23D8ClosureTraceFacts {
    param([Parameter(Mandatory)][string]$Path)
    $limbIds = @("front_left", "front_right", "rear_left", "rear_right")
    $phaseCounts = [ordered]@{}
    $maskCounts = [ordered]@{}
    $rowCount = 0
    $terminalStep = 0
    $firstAllFourTerminalStep = -1
    $longestAllFourTerminalRun = 0
    $currentAllFourTerminalRun = 0
    $passiveAllFourCount = 0
    $maximumTilt = -1.0
    $minimumHeight = [double]::PositiveInfinity
    Get-Content -LiteralPath $Path | ForEach-Object {
        $row = $_ | ConvertFrom-Json -AsHashtable -Depth 30
        $rowCount++
        $phase = [string]$row.phase_id
        if (-not $phaseCounts.Contains($phase)) {
            $phaseCounts[$phase] = 0
            $maskCounts[$phase] = [ordered]@{}
        }
        $phaseCounts[$phase] = [int]$phaseCounts[$phase] + 1
        $mask = (@($limbIds | ForEach-Object {
            if ([bool]$row.ordered_foot_contacts[$_]) { "1" } else { "0" }
        }) -join "")
        if (-not $maskCounts[$phase].Contains($mask)) {
            $maskCounts[$phase][$mask] = 0
        }
        $maskCounts[$phase][$mask] = [int]$maskCounts[$phase][$mask] + 1
        $allFour = $mask -ceq "1111"
        if ($phase -in @(
            "terminal_neutral_stance_acquisition",
            "terminal_neutral_stance_hold"
        )) {
            if ($allFour) {
                if ($firstAllFourTerminalStep -lt 0) {
                    $firstAllFourTerminalStep = $terminalStep
                }
                $currentAllFourTerminalRun++
                if ($currentAllFourTerminalRun -gt $longestAllFourTerminalRun) {
                    $longestAllFourTerminalRun = $currentAllFourTerminalRun
                }
            } else {
                $currentAllFourTerminalRun = 0
            }
            $terminalStep++
        }
        if ($phase -ceq "passive_zero_actuation_settle" -and $allFour) {
            $passiveAllFourCount++
        }
        $maximumTilt = [Math]::Max($maximumTilt, [double]$row.torso_tilt_rad)
        $minimumHeight = [Math]::Min($minimumHeight, [double]$row.torso_height_m)
    }
    return [ordered]@{
        row_count = $rowCount
        phase_counts = $phaseCounts
        mask_counts = $maskCounts
        first_all_four_terminal_step = $firstAllFourTerminalStep
        longest_all_four_terminal_run = $longestAllFourTerminalRun
        passive_all_four_count = $passiveAllFourCount
        maximum_tilt_rad = $maximumTilt
        minimum_torso_height_m = $minimumHeight
    }
}

Assert-R23D8Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D8 closure repository identity mismatch"
foreach ($path in @($closurePath, $EvidenceRoot)) {
    Assert-R23D8Closure (Test-Path -LiteralPath $path) (
        "QSDK-R23D8 closure input is missing: $path"
    )
}

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$tree = Get-R23D8ClosureEvidenceTree $EvidenceRoot
Assert-R23D8Closure (
    [int]$tree.file_count -eq [int]$closure.attempt.evidence_file_count -and
    [int64]$tree.total_byte_length -eq
        [int64]$closure.attempt.evidence_total_byte_length -and
    [string]$tree.raw_sha256 -ceq [string]$closure.attempt.evidence_tree_raw_sha256
) "QSDK-R23D8 retained evidence tree changed"

$productionEvidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
foreach ($file in @($tree.files)) {
    $digest = (Get-R23D8ClosureRawSha256 $file.FullName).Substring(7)
    $casDirectory = Join-Path $productionEvidenceRoot "artifacts\sha256\$digest"
    Assert-R23D8Closure (Test-SporeSporeStoredArtifact `
        -Directory $casDirectory `
        -ExpectedSha256 $digest `
        -ExpectedByteLength $file.Length) (
        "QSDK-R23D8 retained file lacks CAS bytes: $($file.FullName)"
    )
}
Assert-R23D8Closure (
    [bool]$closure.post_attempt_retention_repair.required -and
    -not [bool]$closure.post_attempt_retention_repair.attempt_tree_bytes_changed -and
    -not [bool]$closure.post_attempt_retention_repair.physics_or_evaluation_reexecuted -and
    @($closure.post_attempt_retention_repair.retained_artifacts).Count -eq 2 -and
    [string]$closure.post_attempt_retention_repair.retained_artifacts[0].raw_sha256 -ceq
        "sha256:64d4fdfd70c4b0d96ce43ce191b9990481e79e734a2fe51e248edc7ffb4ed4ab" -and
    [string]$closure.post_attempt_retention_repair.retained_artifacts[1].raw_sha256 -ceq
        "sha256:990fd5cdafbfd2e80780e55c65b4a0c6ebdd42acfa9f477055732f39524579b0"
) "QSDK-R23D8 post-attempt retention record changed"

$keyDigests = [ordered]@{
    "physical-freeze.json" = $closure.attempt.physical_freeze_raw_sha256
    "stage-a-authorization.json" = $closure.attempt.stage_a_authorization_raw_sha256
    "completion.json" = $closure.attempt.completion_raw_sha256
    "report.json" = $closure.attempt.report_raw_sha256
    "stage-a-evaluator/evaluation.json" = $closure.attempt.stage_a_evaluation_raw_sha256
    "complete-evaluator/evaluation.json" = $closure.attempt.complete_evaluation_raw_sha256
    "stage-a-terminal-paths.json" = $closure.attempt.stage_a_manifest_raw_sha256
    "stage-b-terminal-paths.json" = $closure.attempt.stage_b_empty_manifest_raw_sha256
}
foreach ($item in $keyDigests.GetEnumerator()) {
    Assert-R23D8Closure (
        (Get-R23D8ClosureRawSha256 (Join-Path $EvidenceRoot $item.Key)) -ceq
            [string]$item.Value
    ) "QSDK-R23D8 retained key file changed: $($item.Key)"
}

$freeze = Get-Content -Raw -LiteralPath (Join-Path $EvidenceRoot "physical-freeze.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$authorization = Get-Content -Raw -LiteralPath (
    Join-Path $EvidenceRoot "stage-a-authorization.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
$completion = Get-Content -Raw -LiteralPath (Join-Path $EvidenceRoot "completion.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$report = Get-Content -Raw -LiteralPath (Join-Path $EvidenceRoot "report.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$stageAEvaluation = Get-Content -Raw -LiteralPath (
    Join-Path $EvidenceRoot "stage-a-evaluator\evaluation.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
$completeEvaluation = Get-Content -Raw -LiteralPath (
    Join-Path $EvidenceRoot "complete-evaluator\evaluation.json"
) | ConvertFrom-Json -AsHashtable -Depth 100

Assert-R23D8Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d8_physical_development_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_valid_none_stage_a_neutral_stance_active_hold_negative" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.source_identity.commit -ceq $sourceCommit -and
    [string]$closure.source_identity.tree_git_oid -ceq $sourceTree -and
    [int]$closure.source_identity.declared_source_binding_count -eq 80 -and
    [int]$closure.attempt.world_attempt_count -eq 2 -and
    [int]$closure.attempt.world_build_count -eq 2 -and
    [bool]$closure.attempt.one_shot_identity_consumed -and
    -not [bool]$closure.attempt.same_identity_rerun_allowed
) "QSDK-R23D8 closure identity changed"

Assert-R23D8Closure (
    [string]$freeze.schema_version -ceq
        "sporespore_qsdk_r23d8_physical_freeze_v1" -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq $sourceTree -and
    @($freeze.source_bindings).Count -eq 80 -and
    @($freeze.runtime_artifacts).Count -eq 3 -and
    @($freeze.external_runtime_bindings).Count -eq 4 -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [bool]$freeze.production_authorization_canaries_valid -and
    [bool]$freeze.source_checkout_bytes_equal_git_blobs -and
    [bool]$freeze.reproducible_runtime_materialization_passed -and
    [bool]$freeze.physical_execution_authorized -and
    -not [bool]$freeze.physical_acceptance_authority
) "QSDK-R23D8 physical freeze changed"
Assert-R23D8Closure (
    [string]$authorization.schema_version -ceq
        "sporespore_qsdk_r23d8_attempt_v1" -and
    [string]$authorization.attempt_id -ceq [string]$closure.attempt.attempt_id -and
    [string]$authorization.source_commit -ceq $sourceCommit -and
    [bool]$authorization.physical_execution_authorized -and
    [bool]$authorization.one_shot_attempt_unconsumed -and
    @($authorization.ordered_stage_a_cell_ids).Count -eq 2 -and
    @($authorization.ordered_stage_b_cell_ids).Count -eq 0 -and
    [bool]$authorization.production_authorization_canaries_valid -and
    [int]$authorization.production_authorization_canaries.positive_authorization_canary_count -eq 3 -and
    [int]$authorization.production_authorization_canaries.mutated_binding_refusal_canary_count -eq 3 -and
    [string]$authorization.full_godot_attestation_sha256 -ceq
        [string]$closure.full_godot_attestation.raw_sha256
) "QSDK-R23D8 Stage A authorization changed"

Assert-R23D8Closure (
    [string]$completion.status -ceq "valid_none_stage_a_first_attempt" -and
    [string]$completion.result_classification -ceq "valid_none_stage_a" -and
    [string]$completion.selected_terminal_restoration_policy_id -ceq "NONE" -and
    [int]$completion.stage_a_terminal_entry_count -eq 2 -and
    [int]$completion.stage_b_terminal_entry_count -eq 0 -and
    [bool]$completion.one_shot_identity_consumed -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.command_conditioned_turning -and
    -not [bool]$completion.cross_engine_equivalence -and
    -not [bool]$completion.physical_acceptance_authority
) "QSDK-R23D8 immutable completion changed"
Assert-R23D8Closure (
    [bool]$stageAEvaluation.valid -and
    [string]$stageAEvaluation.classification -ceq "valid_none_stage_a" -and
    [string]$stageAEvaluation.selected_terminal_restoration_policy_id -ceq "NONE" -and
    -not [bool]$stageAEvaluation.stage_b_launch_authorized -and
    @($stageAEvaluation.cell_evaluations).Count -eq 2 -and
    [string]$completeEvaluation.classification -ceq "valid_none_stage_a" -and
    $null -eq $completeEvaluation.stage_b -and
    [int]$completeEvaluation.world_attempt_count -eq 2 -and
    [int]$completeEvaluation.world_build_count -eq 2 -and
    [string]$report.result_classification -ceq "valid_none_stage_a" -and
    -not [bool]$report.stage_b_launched -and
    [int]$report.stage_a_world_count -eq 2 -and
    [int]$report.stage_b_world_count -eq 0
) "QSDK-R23D8 evaluator or report classification changed"

foreach ($binding in @($freeze.source_bindings)) {
    $blob = Get-R23D8ClosureGitBlob `
        -Commit $sourceCommit `
        -Path ([string]$binding.path)
    Assert-R23D8Closure (
        [string]$blob.oid -ceq [string]$binding.git_blob_oid -and
        [string]$blob.raw_sha256 -ceq [string]$binding.raw_sha256 -and
        [bool]$binding.raw_checkout_equals_git_blob
    ) "QSDK-R23D8 frozen source binding changed: $($binding.path)"
}
Assert-R23D8Closure (
    (git -C $repoRoot rev-parse "$sourceCommit^{tree}").Trim() -ceq $sourceTree
) "QSDK-R23D8 frozen source tree changed"

$attestationPath = [string]$closure.full_godot_attestation.path
Assert-R23D8Closure (
    (Get-R23D8ClosureRawSha256 $attestationPath) -ceq
        [string]$closure.full_godot_attestation.raw_sha256
) "QSDK-R23D8 full-Godot attestation bytes changed"
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D8Closure (
    [string]$attestation.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$attestation.status -ceq "full_godot_conformance_passed" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [bool]$attestation.conformance.godot_including -and
    [bool]$attestation.conformance.passed -and
    [double]$attestation.conformance.duration_seconds -eq
        [double]$closure.full_godot_attestation.duration_seconds -and
    -not [bool]$attestation.claims.physical_acceptance_authority
) "QSDK-R23D8 full-Godot attestation semantics changed"

foreach ($cell in @($closure.retained_stage_a_cells)) {
    $cellId = [string]$cell.cell_id
    $cellRoot = Join-Path $EvidenceRoot "stage-a\$cellId"
    $tracePath = Join-Path $EvidenceRoot (
        "traces\mujoco_neutral_stance_screen__${cellId}.ndjson"
    )
    $terminal = Get-Content -Raw -LiteralPath (Join-Path $cellRoot "terminal-entry.json") |
        ConvertFrom-Json -AsHashtable -Depth 100
    $evaluation = @($stageAEvaluation.cell_evaluations | Where-Object {
        [string]$_.cell_id -ceq $cellId
    })
    $facts = Get-R23D8ClosureTraceFacts $tracePath
    Assert-R23D8Closure (
        $evaluation.Count -eq 1 -and
        [bool]$evaluation[0].entry_valid -and
        [bool]$evaluation[0].execution_integrity_passed -and
        -not [bool]$evaluation[0].outcome.outcome_gate_passed -and
        [bool]$evaluation[0].outcome.signed_yaw_response_passed -and
        (Get-R23D8ClosureRawSha256 (Join-Path $cellRoot "process.json")) -ceq
            [string]$cell.process_raw_sha256 -and
        (Get-R23D8ClosureRawSha256 (Join-Path $cellRoot "stdout.txt")) -ceq
            [string]$cell.stdout_raw_sha256 -and
        (Get-R23D8ClosureRawSha256 (Join-Path $cellRoot "stderr.txt")) -ceq
            [string]$cell.stderr_raw_sha256 -and
        (Get-R23D8ClosureRawSha256 (Join-Path $cellRoot "terminal-entry.json")) -ceq
            [string]$cell.terminal_entry_raw_sha256 -and
        (Get-R23D8ClosureRawSha256 $tracePath) -ceq [string]$cell.trace_raw_sha256 -and
        [int]$facts.row_count -eq 3772 -and
        [int]$facts.phase_counts.terminal_neutral_stance_acquisition -eq 180 -and
        [int]$facts.phase_counts.terminal_neutral_stance_hold -eq 360 -and
        [int]$facts.phase_counts.passive_zero_actuation_settle -eq 240 -and
        [int]$facts.first_all_four_terminal_step -eq
            [int]$cell.first_all_four_contact_terminal_stance_step -and
        [int]$facts.longest_all_four_terminal_run -eq
            [int]$cell.consecutive_all_four_contact_hold_step_count -and
        [int]$facts.passive_all_four_count -eq 240 -and
        [double]$facts.maximum_tilt_rad -eq [double]$cell.maximum_tilt_rad -and
        [double]$facts.minimum_torso_height_m -eq [double]$cell.minimum_torso_height_m -and
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d8_engine_cell_report_v1" -and
        [bool]$terminal.execution.integrity_passed -and
        [bool]$terminal.trace_summary.ok -and
        [int]$terminal.trace_summary.row_count -eq 3772
    ) "QSDK-R23D8 retained cell changed: $cellId"

    if ([string]$cell.arm_id -ceq "positive_heading") {
        Assert-R23D8Closure (
            [int]$facts.mask_counts.terminal_neutral_stance_acquisition["0110"] -eq 37 -and
            [int]$facts.mask_counts.terminal_neutral_stance_acquisition["0111"] -eq 143 -and
            [int]$facts.mask_counts.terminal_neutral_stance_hold["0110"] -eq 47 -and
            [int]$facts.mask_counts.terminal_neutral_stance_hold["0111"] -eq 86 -and
            [int]$facts.mask_counts.terminal_neutral_stance_hold["1111"] -eq 227
        ) "QSDK-R23D8 positive contact-mask mechanism changed"
    } else {
        Assert-R23D8Closure (
            [int]$facts.mask_counts.terminal_neutral_stance_acquisition["0110"] -eq 5 -and
            [int]$facts.mask_counts.terminal_neutral_stance_acquisition["0111"] -eq 158 -and
            [int]$facts.mask_counts.terminal_neutral_stance_acquisition["1111"] -eq 17 -and
            [int]$facts.mask_counts.terminal_neutral_stance_hold["1001"] -eq 1 -and
            [int]$facts.mask_counts.terminal_neutral_stance_hold["1011"] -eq 179 -and
            [int]$facts.mask_counts.terminal_neutral_stance_hold["1111"] -eq 180
        ) "QSDK-R23D8 negative contact-mask mechanism changed"
    }
}

$supervisorSource = Get-Content -Raw -LiteralPath $supervisorPath
$mujocoSource = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot (
        "adapters\mujoco\sporespore_mujoco_adapter\" +
        "qsdk_r23d8_neutral_stance.py"
    )
)
$rapierSource = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d3_phase_balanced.rs"
)
$godotSource = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "tests\test_sdk_qsdk_r23d8_neutral_stance_godot_jolt_worker.gd"
)
Assert-R23D8Closure (
    $supervisorSource.Contains("r23d8_physical_closure_v1.json") -and
    $supervisorSource.Contains("QSDK-R23D8 CLOSED") -and
    $mujocoSource.Contains("QSDK_R23D8_MJC_CLOSED") -and
    $rapierSource.Contains("QSDK_R23D8_RAP_CLOSED") -and
    $godotSource.Contains("QSDK_R23D8_GJT_CLOSED")
) "QSDK-R23D8 closure interlocks changed"

$refusalOutput = (& pwsh `
    -NoLogo `
    -NoProfile `
    -File $supervisorPath `
    -RunPhysical `
    -FullConformanceAttestation "R23D8_CLOSED_CANARY_MUST_NOT_BE_READ" 2>&1 |
    Out-String)
Assert-R23D8Closure (
    $LASTEXITCODE -ne 0 -and
    $refusalOutput.Contains("QSDK-R23D8 CLOSED") -and
    $refusalOutput.Contains("rerun is forbidden") -and
    $refusalOutput.Contains('"world_attempt_count":0')
) "QSDK-R23D8 supervisor did not refuse the closed identity"
$global:LASTEXITCODE = 0

$conformanceSource = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "run_conformance.ps1"
)
Assert-R23D8Closure (
    $conformanceSource.Contains("tests\test_qsdk_r23d8_closure.ps1") -and
    -not $conformanceSource.Contains(
        '& (Join-Path $repoRoot "tests\test_qsdk_r23d8_declaration.ps1")'
    ) -and
    -not $conformanceSource.Contains(
        '& (Join-Path $sdkRoot "run_qsdk_r23d8_mujoco_worker_preflight.ps1")'
    )
) "QSDK-R23D8 canonical conformance still exposes a consumed prospective route"

Assert-R23D8Closure (
    [bool]$closure.claims.development_screen_only -and
    [bool]$closure.claims.exact_finite_policy_scientific_negative -and
    -not [bool]$closure.claims.command_conditioned_turning -and
    -not [bool]$closure.claims.bilateral_signed_turning -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "QSDK-R23D8 closure claims changed"

Write-Host (
    "QSDK_R23D8_CLOSURE_PASS status=valid-none-stage-a worlds=2 stage_a=2/2 " +
    "signed_yaw=2/2 selected=NONE stage_b=0 mechanism=active-neutral-hold " +
    "passive_four_contact=2/2 turning=False equivalence=False " +
    "rerun_refused=True physical_authority=False"
)

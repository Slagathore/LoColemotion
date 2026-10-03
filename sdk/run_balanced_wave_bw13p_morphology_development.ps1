#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("BW13P-A", "BW13P-B", "BW13P-C", "BW13P-D")]
    [string]$Candidate,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_balanced_wave_bw13p_development"
    ),
    [string]$Output = "",
    [switch]$PreflightOnly,
    [ValidateRange(30, 600)]
    [int]$CellTimeoutSeconds = 240
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$godotPath = [System.IO.Path]::GetFullPath($Godot)
$preregistrationPath = Join-Path $sdkRoot (
    "balanced_wave_bw13p_morphology_development_preregistration.json"
)
$expectedRawPreregistrationHash = (
    "3d3433f6e9fa05790bb493eb3190fd174a543311bf143972b7ae0ed18b3207b7"
)
$v3AuthorityTest = "tests/test_sdk_scheduled_load_transfer_v3_authority_contract.gd"
$fullGateTest = "tests/test_sdk_full_integrity_gate_satisfiability.gd"
$campaignTest = "tests/test_sdk_balanced_wave_bw13p_morphology_development.gd"
$candidateEnvironmentVariable = "SPORESPORE_BW13P_CANDIDATE"
$candidateIndex = [ordered]@{
    "BW13P-A" = [ordered]@{
        policy_id = "sporespore_scheduled_load_transfer_bw13p_a_v3"
        policy_digest = (
            "sha256:" +
            "5843bcb182dbf68072246a3c730e53033fc705818186fcb3f0fd8ad4e0120a47"
        )
        mode = "control"
    }
    "BW13P-B" = [ordered]@{
        policy_id = "sporespore_scheduled_load_transfer_bw13p_b_v3"
        policy_digest = (
            "sha256:" +
            "4d5a0ebaf6a6dfdbc20ce1a538ef84b1a1c2a85c559d67c84bbeac586d6c3887"
        )
        mode = "preferred_normal_force"
    }
    "BW13P-C" = [ordered]@{
        policy_id = "sporespore_scheduled_load_transfer_bw13p_c_v3"
        policy_digest = (
            "sha256:" +
            "522947d355d39543bfc5cc8af4b930aba1db8409c10ad5d7e9f8c81deac1f0f4"
        )
        mode = "remaining_support_centroid"
    }
    "BW13P-D" = [ordered]@{
        policy_id = "sporespore_scheduled_load_transfer_bw13p_d_v3"
        policy_digest = (
            "sha256:" +
            "05d0460c3cccec4e25bc5cf9040a8fa82c681264bd1efaaec4f8601efb27e05e"
        )
        mode = "combined"
    }
}
$selected = $candidateIndex[$Candidate]

function Assert-Exact {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )
    [System.IO.File]::WriteAllText(
        $Path,
        $Text,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Get-PrefixedSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:$(Get-Sha256 -Path $Path)"
}

function Get-ReceiptFromOutput {
    param(
        [Parameter(Mandatory)]
        [string]$OutputText,
        [Parameter(Mandatory)]
        [string]$Prefix
    )
    $lines = @(
        $OutputText -split "\r?\n" |
            Where-Object { $_.StartsWith($Prefix) }
    )
    Assert-Exact (
        $lines.Count -eq 1
    ) "Expected one '$Prefix' receipt, found $($lines.Count)"
    return (
        $lines[0].Substring($Prefix.Length) |
            ConvertFrom-Json -AsHashtable
    )
}

function Invoke-GodotCaptured {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        [Parameter(Mandatory)]
        [string]$WorkerRoot,
        [Parameter(Mandatory)]
        [int]$TimeoutSeconds
    )
    $appData = Join-Path $WorkerRoot "appdata"
    $localAppData = Join-Path $WorkerRoot "localappdata"
    [void][System.IO.Directory]::CreateDirectory($appData)
    [void][System.IO.Directory]::CreateDirectory($localAppData)
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $godotPath
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment["APPDATA"] = $appData
    $start.Environment["LOCALAPPDATA"] = $localAppData
    $start.Environment[$candidateEnvironmentVariable] = $Candidate
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    $startedUtc = [DateTime]::UtcNow
    Assert-Exact ($process.Start()) "Failed to start Godot"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    $killedTree = $false
    if ($timedOut) {
        try {
            $process.Kill($true)
            $killedTree = $true
        } catch {
            $killedTree = $false
        }
        [void]$process.WaitForExit(10000)
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($process.HasExited) { $process.ExitCode } else { -1 }
    $durationSeconds = ([DateTime]::UtcNow - $startedUtc).TotalSeconds
    $process.Dispose()
    return [ordered]@{
        exit_code = $exitCode
        timed_out = $timedOut
        killed_process_tree = $killedTree
        duration_seconds = $durationSeconds
        stdout = $stdout
        stderr = $stderr
    }
}

function New-CellResult {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Cell,
        [Parameter(Mandatory)]
        [int]$Seed,
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Execution,
        [AllowNull()]
        [object]$Receipt,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$ReceiptError,
        [Parameter(Mandatory)]
        [string]$TranscriptPath,
        [Parameter(Mandatory)]
        [string]$StderrPath,
        [Parameter(Mandatory)]
        [string]$EngineLogPath
    )
    $parsed = $null -ne $Receipt
    $harnessPassed = (
        $parsed -and
        [int]$Execution.exit_code -eq 0 -and
        -not [bool]$Execution.timed_out -and
        [bool]$Receipt.harness_passed -and
        [int]$Receipt.assertions_failed -eq 0
    )
    return [ordered]@{
        morphology_id = [string]$Cell.morphology_id
        generator_index = [int]$Cell.generator_index
        campaign_seed = $Seed
        process_exit_code = [int]$Execution.exit_code
        timed_out = [bool]$Execution.timed_out
        killed_process_tree = [bool]$Execution.killed_process_tree
        duration_seconds = [double]$Execution.duration_seconds
        receipt_parsed = $parsed
        receipt_parse_error = $ReceiptError
        harness_passed = $harnessPassed
        common_execution_integrity = (
            $parsed -and [bool]$Receipt.common_execution_integrity
        )
        mechanism_gate_passed = (
            $parsed -and [bool]$Receipt.scheduled_load_transfer_gate_passed
        )
        combined_application_gate_passed = (
            $parsed -and
            [bool]$Receipt.combined_full_authority_application_gate_passed
        )
        walking_observed = (
            $parsed -and [bool]$Receipt.walking_observed
        )
        failed_production_walking_gate_count = $(
            if ($parsed) {
                [int]$Receipt.failed_production_walking_gate_count
            } else {
                1
            }
        )
        release_timeout_count = $(
            if ($parsed) { [int]$Receipt.release_timeout_count } else { 1 }
        )
        normalized_absolute_task_frame_lateral_displacement = $(
            if ($parsed) {
                $Receipt.normalized_absolute_task_frame_lateral_displacement
            } else {
                $null
            }
        )
        cumulative_absolute_cross_track_error_m_s = $(
            if ($parsed) {
                $Receipt.cumulative_absolute_cross_track_error_m_s
            } else {
                $null
            }
        )
        receipt = $Receipt
        transcript_path = $TranscriptPath
        transcript_sha256 = Get-PrefixedSha256 $TranscriptPath
        stderr_path = $StderrPath
        stderr_sha256 = Get-PrefixedSha256 $StderrPath
        engine_log_path = $EngineLogPath
        engine_log_sha256 = $(
            if (Test-Path -LiteralPath $EngineLogPath) {
                Get-PrefixedSha256 $EngineLogPath
            } else {
                ""
            }
        )
    }
}

function Measure-Results {
    param(
        [Parameter(Mandatory)]
        [object[]]$Results
    )
    $completeCount = @(
        $Results |
            Where-Object {
                -not [bool]$_.timed_out -and [bool]$_.receipt_parsed
            }
    ).Count
    $harnessPassCount = @(
        $Results | Where-Object { [bool]$_.harness_passed }
    ).Count
    $integrityPassCount = @(
        $Results | Where-Object { [bool]$_.common_execution_integrity }
    ).Count
    $mechanismPassCount = @(
        $Results | Where-Object { [bool]$_.mechanism_gate_passed }
    ).Count
    $applicationPassCount = @(
        $Results | Where-Object { [bool]$_.combined_application_gate_passed }
    ).Count
    $walkingPassCount = @(
        $Results | Where-Object { [bool]$_.walking_observed }
    ).Count
    $numericLateral = @(
        $Results |
            ForEach-Object {
                $_.normalized_absolute_task_frame_lateral_displacement
            } |
            Where-Object { $null -ne $_ }
    )
    $numericCrossTrack = @(
        $Results |
            ForEach-Object {
                $_.cumulative_absolute_cross_track_error_m_s
            } |
            Where-Object { $null -ne $_ }
    )
    $failedWalkingGateTotal = (
        $Results |
            Measure-Object -Property failed_production_walking_gate_count -Sum
    ).Sum
    $releaseTimeoutTotal = (
        $Results |
            Measure-Object -Property release_timeout_count -Sum
    ).Sum
    return [ordered]@{
        observed_world_count = $Results.Count
        complete_receipt_count = $completeCount
        harness_pass_count = $harnessPassCount
        integrity_pass_count = $integrityPassCount
        mechanism_pass_count = $mechanismPassCount
        combined_application_pass_count = $applicationPassCount
        walking_conjunction_pass_count = $walkingPassCount
        walking_conjunction_failure_count = $Results.Count - $walkingPassCount
        aggregate_failed_production_walking_gate_count = (
            [int]$failedWalkingGateTotal
        )
        aggregate_release_timeout_count = [int]$releaseTimeoutTotal
        maximum_normalized_absolute_task_frame_lateral_displacement = $(
            if ($numericLateral.Count -eq $Results.Count) {
                [double]($numericLateral | Measure-Object -Maximum).Maximum
            } else {
                $null
            }
        )
        aggregate_normalized_absolute_task_frame_lateral_displacement = $(
            if ($numericLateral.Count -eq $Results.Count) {
                [double]($numericLateral | Measure-Object -Sum).Sum
            } else {
                $null
            }
        )
        aggregate_cumulative_absolute_cross_track_error_m_s = $(
            if ($numericCrossTrack.Count -eq $Results.Count) {
                [double]($numericCrossTrack | Measure-Object -Sum).Sum
            } else {
                $null
            }
        )
        integrity_and_mechanism_complete = (
            $Results.Count -eq 36 -and
            $completeCount -eq 36 -and
            $harnessPassCount -eq 36 -and
            $integrityPassCount -eq 36 -and
            $mechanismPassCount -eq 36 -and
            $applicationPassCount -eq 36 -and
            $numericLateral.Count -eq 36 -and
            $numericCrossTrack.Count -eq 36
        )
    }
}

Assert-Exact (
    Test-Path -LiteralPath $godotPath -PathType Leaf
) "Godot executable not found: $godotPath"
Assert-Exact (
    Test-Path -LiteralPath $preregistrationPath -PathType Leaf
) "BW13P preregistration is missing"
Assert-Exact (
    (Get-Sha256 $preregistrationPath) -ceq $expectedRawPreregistrationHash
) "BW13P preregistration raw bytes do not match the frozen runner identity"
Assert-Exact (
    -not ($PreflightOnly -and -not [string]::IsNullOrWhiteSpace($Output))
) "Preflight-only mode cannot retain a physics report"
Assert-Exact (
    $PreflightOnly -or -not [string]::IsNullOrWhiteSpace($Output)
) "A physical BW13P candidate run requires a durable -Output report.json path"

$preregistration = (
    Get-Content -Raw -LiteralPath $preregistrationPath |
        ConvertFrom-Json -AsHashtable
)
$candidatePosition = @($preregistration.candidate_order).IndexOf($Candidate)
$candidateDeclaration = @($preregistration.candidates)[$candidatePosition]
$cells = @($preregistration.morphology_generator.cells)
$seeds = @(
    $preregistration.repetitions.campaign_seeds |
        ForEach-Object { [int]$_ }
)
Assert-Exact ($candidatePosition -ge 0) "Candidate is absent from the preregistration"
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw13p_morphology_development_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw13p_physics_world" -and
    [string]$preregistration.campaign_id -ceq
        "BW13P-MORPHOLOGY-DEVELOPMENT" -and
    [bool]$preregistration.development_data_only -and
    -not [bool]$preregistration.development_candidate_selected -and
    $cells.Count -eq 12 -and
    ($seeds -join ",") -ceq "21601,21602,21603" -and
    [int]$preregistration.repetitions.expected_world_count_per_candidate -eq 36 -and
    [int]$preregistration.repetitions.expected_complete_world_count -eq 144 -and
    [bool]$preregistration.repetitions.early_stop_for_outcome_forbidden -and
    [bool]$preregistration.mechanism_receipt_eligibility.all_candidates_require_one_combined_full_authority_application_per_sdk_step -and
    [bool]$preregistration.mechanism_receipt_eligibility.all_candidates_require_eight_combined_motor_writes_per_sdk_step -and
    [bool]$preregistration.mechanism_receipt_eligibility.all_candidates_require_nonzero_effective_stability_influence -and
    [string]$candidateDeclaration.candidate_id -ceq $Candidate -and
    [string]$candidateDeclaration.stability_policy_id -ceq
        [string]$selected.policy_id -and
    [string]$candidateDeclaration.mode -ceq [string]$selected.mode -and
    @($candidateDeclaration.branch_surfaces).Count -eq 0 -and
    [string]$preregistration.candidate_policy_digests[$Candidate] -ceq
        [string]$selected.policy_digest -and
    -not [bool]$preregistration.claim_boundary.walking_acceptance -and
    -not [bool]$preregistration.claim_boundary.independent_morphology_validation -and
    -not [bool]$preregistration.claim_boundary.completed_engine_neutral_sdk -and
    -not [bool]$preregistration.claim_boundary.release_authorized
) "BW13P preregistration failed strict candidate reconciliation"

$outputPath = ""
$outputDirectory = ""
$sourceCommit = ""
$originMain = ""
if (-not $PreflightOnly) {
    $sourceStatus = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    )
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and $sourceStatus.Count -eq 0
    ) "Refusing to open BW13P worlds from dirty source"
    $sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    $originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        -not [string]::IsNullOrWhiteSpace($sourceCommit) -and
        $sourceCommit -ceq $originMain
    ) "Refusing BW13P because HEAD does not exactly match origin/main"
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    Assert-Exact (
        [System.IO.Path]::GetFileName($outputPath) -ceq "report.json"
    ) "The retained BW13P report filename must be exactly report.json"
    Assert-Exact (
        -not (Test-Path -LiteralPath $outputPath)
    ) "Refusing to overwrite an existing BW13P report: $outputPath"
    $outputDirectory = Split-Path -Parent $outputPath
    if (Test-Path -LiteralPath $outputDirectory) {
        Assert-Exact (
            @(Get-ChildItem -LiteralPath $outputDirectory -Force).Count -eq 0
        ) "Refusing a nonempty BW13P evidence directory: $outputDirectory"
    }
}

Push-Location -LiteralPath $sdkRoot
try {
    & cargo build -p sporespore-godot-adapter --offline
    Assert-Exact ($LASTEXITCODE -eq 0) "Godot adapter build failed"
} finally {
    Pop-Location
}

$tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$tempRoot = Join-Path ([System.IO.Path]::GetFullPath($LogRoot)) (
    "$($Candidate.ToLowerInvariant())-$([Guid]::NewGuid().ToString('N'))"
)
$projectRoot = Join-Path $tempRoot "project"
[void][System.IO.Directory]::CreateDirectory($projectRoot)
foreach ($directory in @("scripts", "tests", "sdk")) {
    [void](New-Item `
        -ItemType Junction `
        -Path (Join-Path $projectRoot $directory) `
        -Target (Join-Path $repoRoot $directory))
}
$projectText = @"
; Isolated SporeSpore BW13P morphology development candidate.

config_version=5

[application]

config/name="sporespore-bw13p-morphology-development"
config/features=PackedStringArray("4.7", "Forward Plus")

[debug]

gdscript/warnings/shadowed_global_identifier=0

[physics]

3d/physics_engine="Jolt Physics"
jolt_physics_3d/simulation/velocity_steps=20
jolt_physics_3d/simulation/position_steps=7
"@
Write-Utf8NoBom -Path (Join-Path $projectRoot "project.godot") -Text $projectText

try {
    # Every preflight below is zero-world and runs before any durable evidence
    # directory or physical process can be created.
    $v3Preflight = Invoke-GodotCaptured `
        -Arguments @(
            "--headless", "--path", $projectRoot,
            "--script", "res://$v3AuthorityTest"
        ) `
        -WorkerRoot (Join-Path $tempRoot "preflight-v3") `
        -TimeoutSeconds 120
    Assert-Exact (
        $v3Preflight.exit_code -eq 0 -and -not $v3Preflight.timed_out
    ) "BW13P portable v3 authority preflight failed"
    $v3Receipt = Get-ReceiptFromOutput `
        -OutputText $v3Preflight.stdout `
        -Prefix "SCHEDULED_LOAD_TRANSFER_V3_AUTHORITY_CONTRACT "
    Assert-Exact (
        [bool]$v3Receipt.passed -and
        [int]$v3Receipt.world_build_count -eq 0 -and
        -not [bool]$v3Receipt.physics_state_modified -and
        -not [bool]$v3Receipt.physical_acceptance_authority
    ) "BW13P portable v3 authority receipt failed"

    $fullPreflight = Invoke-GodotCaptured `
        -Arguments @(
            "--headless", "--path", $projectRoot,
            "--script", "res://$fullGateTest"
        ) `
        -WorkerRoot (Join-Path $tempRoot "preflight-full") `
        -TimeoutSeconds 120
    Assert-Exact (
        $fullPreflight.exit_code -eq 0 -and -not $fullPreflight.timed_out
    ) "BW13P full synthetic integrity process failed"
    $fullReceipt = Get-ReceiptFromOutput `
        -OutputText $fullPreflight.stdout `
        -Prefix "FULL_INTEGRITY_GATE_SATISFIABILITY "
    $runtimeBoundaryWitnesses = @(
        $fullReceipt.policy_runtime_boundary_witnesses
    )
    $runtimeBoundaryFailures = @(
        $runtimeBoundaryWitnesses |
            Where-Object {
                -not [bool]$_.ok -or
                [string]$_.schema_version -cne
                    "sporespore_declared_policy_runtime_boundary_preflight_v1" -or
                [int]$_.native_controller_command_count -ne 8 -or
                -not [bool]$_.native_controller_command_order_exact -or
                -not [bool]$_.gait_memory_nonnegative -or
                -not [bool]$_.native_next_memory_nonnegative -or
                [int]$_.actual_world_build_count -ne 0 -or
                [int]$_.scene_tree_insertion_count -ne 0 -or
                [bool]$_.physics_state_modified -or
                [bool]$_.locomotion_outcome_exposed -or
                [bool]$_.physical_acceptance_authority
            }
    )
    $runtimeBoundaryKeys = @(
        $runtimeBoundaryWitnesses |
            ForEach-Object {
                "{0}|{1}" -f @(
                    [string]$_.stability_policy_id,
                    [int]$_.requested_phase_offset_ticks
                )
            } |
            Sort-Object -Unique
    )
    $declaredSignedOffsetsExact = (
        (
            @(
                $fullReceipt.declared_signed_phase_offsets |
                    ForEach-Object { [int]$_ }
            ) -join ","
        ) -ceq "-3,-2"
    )
    $selectedSemanticWitness = @(
        $fullReceipt.policy_semantic_witnesses |
            Where-Object {
                [string]$_.declared_stability_policy_id -ceq
                    [string]$selected.policy_id
            }
    )
    Assert-Exact (
        [bool]$fullReceipt.passed -and
        [string]$fullReceipt.schema_version -ceq
            "sporespore_full_integrity_gate_satisfiability_receipt_v4" -and
        [bool]$fullReceipt.exact_declared_policy_runtime_boundaries_called -and
        [int]$fullReceipt.declared_policy_runtime_boundary_count -eq 8 -and
        [bool]$fullReceipt.declared_policy_runtime_boundaries_passed -and
        $declaredSignedOffsetsExact -and
        $runtimeBoundaryWitnesses.Count -eq 8 -and
        $runtimeBoundaryFailures.Count -eq 0 -and
        $runtimeBoundaryKeys.Count -eq 8 -and
        [bool]$fullReceipt.exact_pre_world_entrypoint_called -and
        [bool]$fullReceipt.real_portable_policy_semantics_called -and
        [bool]$fullReceipt.exact_post_physics_gate_called -and
        [bool]$fullReceipt.perfect_zero_error_mismatch_failure_and_violation_counts -and
        [bool]$fullReceipt.mechanism_activity_counts_derived_from_real_policy_receipts -and
        [bool]$fullReceipt.bw12e_exact_zero_control_mismatch_detected -and
        [bool]$fullReceipt.missing_policy_semantic_witness_rejected -and
        [int]$fullReceipt.actual_world_build_count -eq 0 -and
        [int]$fullReceipt.scene_tree_insertion_count -eq 0 -and
        -not [bool]$fullReceipt.physics_state_modified -and
        $selectedSemanticWitness.Count -eq 1 -and
        [bool]$selectedSemanticWitness[0].full_authority_combined_application_called -and
        [bool]$selectedSemanticWitness[0].full_authority_combined_application_passed -and
        [bool]$selectedSemanticWitness[0].full_authority_combined_application_receipt.ok -and
        [int]$selectedSemanticWitness[0].full_authority_combined_application_receipt.applied_command_count -eq 8 -and
        [string]$selectedSemanticWitness[0].full_authority_combined_application_receipt.base_command_source -ceq
            "portable_controller_ordered_commands" -and
        [int]$selectedSemanticWitness[0].full_authority_combined_application_receipt.direct_body_write_count -eq 0 -and
        -not [bool]$fullReceipt.physical_acceptance_authority
    ) "BW13P full synthetic integrity receipt failed strict reconciliation"

    $generatedPreflight = Invoke-GodotCaptured `
        -Arguments @(
            "--headless", "--path", $projectRoot,
            "--script", "res://$campaignTest",
            "--", "emit-cells"
        ) `
        -WorkerRoot (Join-Path $tempRoot "preflight-generated") `
        -TimeoutSeconds 120
    Assert-Exact (
        $generatedPreflight.exit_code -eq 0 -and
        -not $generatedPreflight.timed_out
    ) "BW13P generated-cell preflight failed"
    $generatedReceipt = Get-ReceiptFromOutput `
        -OutputText $generatedPreflight.stdout `
        -Prefix "BW13P_DEVELOPMENT_GENERATED_CELLS "
    Assert-Exact (
        [string]$generatedReceipt.schema_version -ceq
            "sporespore_bw13p_development_generated_cells_receipt_v1" -and
        @($generatedReceipt.cells).Count -eq 12 -and
        [int]$generatedReceipt.world_build_count -eq 0 -and
        -not [bool]$generatedReceipt.physical_acceptance_authority
    ) "BW13P generated-cell receipt failed strict reconciliation"

    $entrypointPreflight = Invoke-GodotCaptured `
        -Arguments @(
            "--headless", "--path", $projectRoot,
            "--script", "res://$campaignTest",
            "--", "preflight"
        ) `
        -WorkerRoot (Join-Path $tempRoot "preflight-entrypoints") `
        -TimeoutSeconds 120
    Assert-Exact (
        $entrypointPreflight.exit_code -eq 0 -and
        -not $entrypointPreflight.timed_out
    ) "BW13P 36-cell entrypoint preflight failed"
    $entrypointReceipt = Get-ReceiptFromOutput `
        -OutputText $entrypointPreflight.stdout `
        -Prefix "BW13P_DEVELOPMENT_ENTRYPOINT_PREFLIGHT "
    Assert-Exact (
        [bool]$entrypointReceipt.ok -and
        [string]$entrypointReceipt.schema_version -ceq
            "sporespore_bw13p_development_entrypoint_preflight_v1" -and
        [string]$entrypointReceipt.campaign_id -ceq
            "BW13P-MORPHOLOGY-DEVELOPMENT" -and
        [string]$entrypointReceipt.stability_policy_id -ceq
            [string]$selected.policy_id -and
        [int]$entrypointReceipt.cell_count -eq 36 -and
        [int]$entrypointReceipt.actual_world_build_count -eq 0 -and
        [int]$entrypointReceipt.scene_tree_insertion_count -eq 0 -and
        [int]$entrypointReceipt.exact_selected_policy_full_authority_start_count -eq 36 -and
        [bool]$entrypointReceipt.selected_policy_full_authority_start_passed -and
        -not [bool]$entrypointReceipt.physics_state_modified -and
        -not [bool]$entrypointReceipt.locomotion_outcome_exposed -and
        -not [bool]$entrypointReceipt.physical_acceptance_authority
    ) "BW13P entrypoint receipt failed strict reconciliation"

    $sourcePaths = @(
        "sdk/balanced_wave_bw13p_morphology_development_preregistration.json",
        "sdk/run_balanced_wave_bw13p_morphology_development.ps1",
        "sdk/compile_balanced_wave_bw13p_selection.ps1",
        "sdk/balanced_wave_selected_policy.json",
        $v3AuthorityTest,
        $fullGateTest,
        $campaignTest,
        "tests/test_sdk_qsdk_r05_independent_morphology.gd",
        "tests/test_bw13p_selector.ps1",
        "scripts/lab/gait/physical_quadruped_proportion_spec.gd",
        "scripts/lab/gait/physical_wave_gait_quadruped.gd",
        "scripts/lab/gait/sdk_godot_jolt_adapter.gd",
        "sdk/core/src/stability.rs",
        "sdk/core/src/ffi.rs",
        "sdk/README.md",
        "sdk/release/README.md",
        "docs/ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md",
        "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md",
        "docs/research/LOCOMOTION_RESEARCH_SOURCES.md",
        "DReCon.pdf",
        "2604.08780v1.pdf",
        "2507.22653v2.pdf"
    )
    $sourceFileReceipts = @(
        foreach ($relativePath in $sourcePaths) {
            $absolutePath = Join-Path $repoRoot $relativePath
            Assert-Exact (
                Test-Path -LiteralPath $absolutePath -PathType Leaf
            ) "Missing BW13P retained source: $relativePath"
            [ordered]@{
                path = $relativePath
                sha256 = Get-PrefixedSha256 $absolutePath
            }
        }
    )

    # Run the final aggregate/report gate against a complete perfect synthetic
    # result from this exact declared candidate. This catches impossible
    # integrity predicates, dynamic-field mistakes, missing retained sources,
    # serialization errors, and hash/readback defects before world 1.
    $syntheticResults = @(
        foreach ($cell in $cells) {
            foreach ($seed in $seeds) {
                [ordered]@{
                    morphology_id = [string]$cell.morphology_id
                    generator_index = [int]$cell.generator_index
                    campaign_seed = [int]$seed
                    process_exit_code = 0
                    timed_out = $false
                    killed_process_tree = $false
                    duration_seconds = 0.0
                    receipt_parsed = $true
                    receipt_parse_error = ""
                    harness_passed = $true
                    common_execution_integrity = $true
                    mechanism_gate_passed = $true
                    combined_application_gate_passed = $true
                    walking_observed = $true
                    failed_production_walking_gate_count = 0
                    release_timeout_count = 0
                    normalized_absolute_task_frame_lateral_displacement = 0.0
                    cumulative_absolute_cross_track_error_m_s = 0.0
                    receipt = [ordered]@{
                        synthetic_perfect_declared_policy_input = $true
                        candidate_id = $Candidate
                        stability_policy_id = [string]$selected.policy_id
                    }
                    transcript_path = "synthetic"
                    transcript_sha256 = "sha256:synthetic"
                    stderr_path = "synthetic"
                    stderr_sha256 = "sha256:synthetic"
                    engine_log_path = "synthetic"
                    engine_log_sha256 = "sha256:synthetic"
                }
            }
        }
    )
    $syntheticMetrics = Measure-Results -Results $syntheticResults
    $syntheticReport = [ordered]@{
        schema_version = "sporespore_bw13p_morphology_development_report_v1"
        synthetic_preflight_schema = (
            "sporespore_bw13p_runner_full_integrity_preflight_v1"
        )
        perfect_zero_error_input = $true
        candidate_id = $Candidate
        stability_policy_id = [string]$selected.policy_id
        candidate_policy_digest = [string]$selected.policy_digest
        source_files = $sourceFileReceipts
        full_integrity_preflight_passed = $true
        entrypoint_preflight_passed = $true
        metrics = $syntheticMetrics
        results = $syntheticResults
        complete = [bool]$syntheticMetrics.integrity_and_mechanism_complete
        development_data_only = $true
        walking_acceptance = $false
        independent_morphology_validation = $false
        physical_world_build_count = 0
        physical_acceptance_authority = $false
    }
    $syntheticRoot = Join-Path $tempRoot "preflight-runner-report"
    [void][System.IO.Directory]::CreateDirectory($syntheticRoot)
    $syntheticReportPath = Join-Path $syntheticRoot "report.json"
    Write-Utf8NoBom `
        -Path $syntheticReportPath `
        -Text (
            ($syntheticReport | ConvertTo-Json -Depth 100) +
            [Environment]::NewLine
        )
    $syntheticReportHash = Get-PrefixedSha256 $syntheticReportPath
    $syntheticRoundTrip = (
        Get-Content -Raw -LiteralPath $syntheticReportPath |
            ConvertFrom-Json -AsHashtable
    )
    Assert-Exact (
        $syntheticReportHash.StartsWith("sha256:") -and
        [string]$syntheticRoundTrip.schema_version -ceq
            "sporespore_bw13p_morphology_development_report_v1" -and
        [string]$syntheticRoundTrip.synthetic_preflight_schema -ceq
            "sporespore_bw13p_runner_full_integrity_preflight_v1" -and
        [bool]$syntheticRoundTrip.perfect_zero_error_input -and
        [string]$syntheticRoundTrip.candidate_id -ceq $Candidate -and
        [string]$syntheticRoundTrip.stability_policy_id -ceq
            [string]$selected.policy_id -and
        [int]$syntheticRoundTrip.source_files.Count -eq
            $sourceFileReceipts.Count -and
        [int]$syntheticRoundTrip.results.Count -eq 36 -and
        [int]$syntheticRoundTrip.metrics.observed_world_count -eq 36 -and
        [int]$syntheticRoundTrip.metrics.walking_conjunction_failure_count -eq 0 -and
        [int]$syntheticRoundTrip.metrics.aggregate_failed_production_walking_gate_count -eq 0 -and
        [int]$syntheticRoundTrip.metrics.aggregate_release_timeout_count -eq 0 -and
        [double]$syntheticRoundTrip.metrics.maximum_normalized_absolute_task_frame_lateral_displacement -eq 0.0 -and
        [double]$syntheticRoundTrip.metrics.aggregate_normalized_absolute_task_frame_lateral_displacement -eq 0.0 -and
        [double]$syntheticRoundTrip.metrics.aggregate_cumulative_absolute_cross_track_error_m_s -eq 0.0 -and
        [bool]$syntheticRoundTrip.metrics.integrity_and_mechanism_complete -and
        [bool]$syntheticRoundTrip.complete -and
        [int]$syntheticRoundTrip.physical_world_build_count -eq 0 -and
        -not [bool]$syntheticRoundTrip.physical_acceptance_authority
    ) "BW13P runner/report full-integrity synthetic preflight failed"

    if ($PreflightOnly) {
        $preflightBundle = [ordered]@{
            schema_version = "sporespore_bw13p_preflight_bundle_v1"
            candidate_id = $Candidate
            stability_policy_id = [string]$selected.policy_id
            v3_authority_passed = $true
            full_integrity_gate_passed = $true
            selected_real_combined_application_passed = $true
            generated_cell_count = @($generatedReceipt.cells).Count
            entrypoint_cell_count = [int]$entrypointReceipt.cell_count
            runner_report_serialization_hash_readback_passed = $true
            runner_report_sha256 = $syntheticReportHash
            runner_report_synthetic_cell_count = (
                [int]$syntheticRoundTrip.results.Count
            )
            retained_source_file_count = $sourceFileReceipts.Count
            actual_world_build_count = 0
            scene_tree_insertion_count = 0
            physics_state_modified = $false
            locomotion_outcome_exposed = $false
            physical_acceptance_authority = $false
        }
        Write-Host (
            "BW13P_PREFLIGHT_BUNDLE " +
            ($preflightBundle | ConvertTo-Json -Compress -Depth 30)
        )
        Write-Host (
            "BW13P $Candidate preflight passed: complete declared-policy " +
            "integrity gate, real combined authority write, 36/36 exact " +
            "entrypoints, and aggregate report hash/readback; zero worlds."
        )
        return
    }

    # Durable campaign state and physical processes are permitted only here.
    [void][System.IO.Directory]::CreateDirectory($outputDirectory)
    $syntheticRetainedName = "synthetic-runner-report-preflight.json"
    $syntheticRetainedPath = Join-Path $outputDirectory $syntheticRetainedName
    [System.IO.File]::Copy(
        $syntheticReportPath,
        $syntheticRetainedPath,
        $false
    )
    foreach ($preflightItem in @(
        [ordered]@{ name = "v3-authority-preflight.log"; value = $v3Preflight },
        [ordered]@{ name = "full-integrity-preflight.log"; value = $fullPreflight },
        [ordered]@{ name = "generated-cells-preflight.log"; value = $generatedPreflight },
        [ordered]@{ name = "entrypoint-preflight.log"; value = $entrypointPreflight }
    )) {
        Write-Utf8NoBom `
            -Path (Join-Path $outputDirectory $preflightItem.name) `
            -Text (
                [string]$preflightItem.value.stdout +
                [string]$preflightItem.value.stderr
            )
    }
    $preflightArtifacts = @(
        foreach ($name in @(
            "v3-authority-preflight.log",
            "full-integrity-preflight.log",
            "generated-cells-preflight.log",
            "entrypoint-preflight.log",
            $syntheticRetainedName
        )) {
            $path = Join-Path $outputDirectory $name
            [ordered]@{
                path = $name
                sha256 = Get-PrefixedSha256 $path
            }
        }
    )

    $results = [System.Collections.Generic.List[object]]::new()
    $worldOrdinal = 0
    foreach ($cell in $cells) {
        foreach ($seed in $seeds) {
            $worldOrdinal += 1
            $morphologyId = [string]$cell.morphology_id
            Write-Host (
                "BW13P $Candidate world $worldOrdinal/36: " +
                "$morphologyId seed=$seed"
            )
            $cellRoot = Join-Path $outputDirectory (
                "{0}-s{1}" -f $morphologyId, $seed
            )
            [void][System.IO.Directory]::CreateDirectory($cellRoot)
            $engineLogPath = Join-Path $cellRoot "engine.log"
            $execution = Invoke-GodotCaptured `
                -Arguments @(
                    "--headless", "--path", $projectRoot,
                    "--log-file", $engineLogPath,
                    "--script", "res://$campaignTest",
                    "--", "physical", $morphologyId, ([string]$seed)
                ) `
                -WorkerRoot (Join-Path $tempRoot "worker-$worldOrdinal") `
                -TimeoutSeconds $CellTimeoutSeconds
            $transcriptPath = Join-Path $cellRoot "transcript.log"
            $stderrPath = Join-Path $cellRoot "stderr.log"
            Write-Utf8NoBom -Path $transcriptPath -Text $execution.stdout
            Write-Utf8NoBom -Path $stderrPath -Text $execution.stderr
            $receipt = $null
            $receiptError = ""
            try {
                $receipt = Get-ReceiptFromOutput `
                    -OutputText $execution.stdout `
                    -Prefix "BW13P_DEVELOPMENT_CELL "
            } catch {
                $receiptError = $_.Exception.Message
            }
            $results.Add(
                (
                    New-CellResult `
                        -Cell $cell `
                        -Seed ([int]$seed) `
                        -Execution $execution `
                        -Receipt $receipt `
                        -ReceiptError $receiptError `
                        -TranscriptPath $transcriptPath `
                        -StderrPath $stderrPath `
                        -EngineLogPath $engineLogPath
                )
            )
        }
    }

    $metrics = Measure-Results -Results @($results)
    $complete = [bool]$metrics.integrity_and_mechanism_complete
    $report = [ordered]@{
        schema_version = "sporespore_bw13p_morphology_development_report_v1"
        generated_utc = [DateTime]::UtcNow.ToString("o")
        source = [ordered]@{
            commit = $sourceCommit
            remote = "origin/main"
            origin_main_commit = $originMain
            clean = $true
            matches_origin_main = $true
            source_files = $sourceFileReceipts
        }
        preregistration = [ordered]@{
            path = (
                "sdk/" +
                "balanced_wave_bw13p_morphology_development_preregistration.json"
            )
            raw_sha256 = "sha256:$expectedRawPreregistrationHash"
            status = [string]$preregistration.status
            implementation_parent_commit = (
                [string]$preregistration.implementation_parent_commit
            )
        }
        campaign_id = "BW13P-MORPHOLOGY-DEVELOPMENT"
        campaign_role = (
            "paired_outcome_exposed_morphology_hypothesis_selection"
        )
        candidate_id = $Candidate
        stability_policy_id = [string]$selected.policy_id
        candidate_policy_digest = [string]$selected.policy_digest
        candidate_mode = [string]$selected.mode
        generator_indices = @(
            $cells | ForEach-Object { [int]$_.generator_index }
        )
        campaign_seeds = $seeds
        expected_world_count = 36
        preflight = [ordered]@{
            v3_authority_passed = $true
            full_integrity_gate_passed = $true
            selected_real_combined_application_passed = $true
            selected_real_combined_application_receipt = (
                $selectedSemanticWitness[0].full_authority_combined_application_receipt
            )
            generated_cell_count = @($generatedReceipt.cells).Count
            entrypoint_cell_count = [int]$entrypointReceipt.cell_count
            runner_report_serialization_hash_readback_passed = $true
            synthetic_report_sha256 = $syntheticReportHash
            retained_artifacts = $preflightArtifacts
            actual_world_build_count = 0
        }
        metrics = $metrics
        results = @($results)
        complete = $complete
        candidate_mechanism_eligible = $complete
        development_selection_authority = $true
        walking_acceptance = $false
        balance_improvement = $false
        independent_morphology_validation = $false
        arbitrary_quadruped_coverage = $false
        continuous_full_volume_coverage = $false
        material_or_friction_robustness = $false
        rough_terrain_robustness = $false
        external_push_recovery = $false
        sensor_noise_or_latency_robustness = $false
        running = $false
        cross_engine_c6 = $false
        completed_engine_neutral_sdk = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
    $temporaryReportPath = "$outputPath.tmp"
    Write-Utf8NoBom `
        -Path $temporaryReportPath `
        -Text (($report | ConvertTo-Json -Depth 100) + [Environment]::NewLine)
    $reportRoundTrip = (
        Get-Content -Raw -LiteralPath $temporaryReportPath |
            ConvertFrom-Json -AsHashtable
    )
    Assert-Exact (
        [string]$reportRoundTrip.schema_version -ceq
            "sporespore_bw13p_morphology_development_report_v1" -and
        [string]$reportRoundTrip.candidate_id -ceq $Candidate -and
        [int]$reportRoundTrip.results.Count -eq 36 -and
        [bool]$reportRoundTrip.complete -eq $complete -and
        [int]$reportRoundTrip.preflight.retained_artifacts.Count -eq 5 -and
        -not [bool]$reportRoundTrip.walking_acceptance -and
        -not [bool]$reportRoundTrip.physical_acceptance_authority
    ) "BW13P retained report serialization/readback failed"
    [System.IO.File]::Move($temporaryReportPath, $outputPath, $false)
    $reportHash = Get-PrefixedSha256 $outputPath
    Write-Host "REPORT=$outputPath"
    Write-Host "REPORT_SHA256=$reportHash"
    Write-Host (
        "BW13P_COMPLETE=$complete CANDIDATE=$Candidate " +
        "WALKING=$([int]$metrics.walking_conjunction_pass_count)/36 " +
        "INTEGRITY=$([int]$metrics.integrity_pass_count)/36"
    )
    Assert-Exact (
        $complete
    ) "BW13P $Candidate retained a complete result with integrity failures"
} finally {
    if (
        (Test-Path -LiteralPath $tempRoot) -and
        $tempRoot.StartsWith(
            [System.IO.Path]::GetFullPath($LogRoot),
            [System.StringComparison]::OrdinalIgnoreCase
        ) -and
        $tempRoot.Length -gt (
            [System.IO.Path]::GetFullPath($LogRoot).Length + 20
        )
    ) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

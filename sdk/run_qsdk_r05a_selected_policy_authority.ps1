#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
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
    "qsdk_r05a_selected_policy_authority_preregistration.json"
)
$r05PreflightRunner = Join-Path $sdkRoot (
    "run_qsdk_r05_independent_morphology.ps1"
)
$physicalTest = "tests/test_sdk_qsdk_r05_independent_morphology.gd"
$expectedPolicyId = "sporespore_balanced_wave_bw5r_b_v1"
$expectedPolicyDigest = (
    "sha256:" +
    "9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
)
$expectedMorphologyId = "qsdk_r05_generated_s169"
$expectedSeed = 21501

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

function Get-PrefixedSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        "sha256:" +
        (
            Get-FileHash -Algorithm SHA256 -LiteralPath $Path
        ).Hash.ToLowerInvariant()
    )
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
    if ($lines.Count -ne 1) {
        throw "Expected one '$Prefix' receipt, found $($lines.Count)"
    }
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
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    $startedUtc = [DateTime]::UtcNow
    if (-not $process.Start()) {
        throw "Failed to start Godot"
    }
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
    $durationSeconds = (
        [DateTime]::UtcNow - $startedUtc
    ).TotalSeconds
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

if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable not found: $godotPath"
}
foreach ($requiredPath in @($preregistrationPath, $r05PreflightRunner)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "QSDK-R05A input not found: $requiredPath"
    }
}

$preregistration = (
    Get-Content -Raw -LiteralPath $preregistrationPath |
        ConvertFrom-Json -AsHashtable
)
$probe = $preregistration.physical_probe
$contractExact = (
    [string]$preregistration.schema_version -ceq
        "sporespore_qsdk_r05a_selected_policy_authority_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_qsdk_r05a_physics_world" -and
    [string]$preregistration.gate_id -ceq "QSDK-R05A" -and
    [string]$preregistration.campaign_role -ceq
        "technical_capability_closure" -and
    [string]$preregistration.selected_policy_id -ceq $expectedPolicyId -and
    [string]$preregistration.selected_policy_digest -ceq
        $expectedPolicyDigest -and
    [string]$probe.morphology_id -ceq $expectedMorphologyId -and
    [int]$probe.campaign_seed -eq $expectedSeed -and
    [int]$probe.world_count -eq 1 -and
    -not [bool]$probe.independent_validation_authority -and
    [bool]$preregistration.claim_boundary.technical_capability_only -and
    -not [bool]$preregistration.claim_boundary.same_selected_policy_independent_morphology_evidence -and
    -not [bool]$preregistration.claim_boundary.release_authorized
)
if (-not $contractExact) {
    throw "QSDK-R05A preregistration failed strict reconciliation"
}

if ($PreflightOnly -and -not [string]::IsNullOrWhiteSpace($Output)) {
    throw "QSDK-R05A preflight-only mode cannot retain a physics report"
}
if (-not $PreflightOnly -and [string]::IsNullOrWhiteSpace($Output)) {
    throw "QSDK-R05A physical mode requires a durable -Output report.json path"
}

$sourceCommit = ""
$originMain = ""
$outputPath = ""
$outputDirectory = ""
if (-not $PreflightOnly) {
    $sourceStatus = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    )
    if ($LASTEXITCODE -ne 0 -or $sourceStatus.Count -ne 0) {
        throw "Refusing to open QSDK-R05A world from dirty source"
    }
    $sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    $originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
    if (
        $LASTEXITCODE -ne 0 -or
        [string]::IsNullOrWhiteSpace($sourceCommit) -or
        $sourceCommit -cne $originMain
    ) {
        throw "Refusing QSDK-R05A because HEAD does not match origin/main"
    }

    $outputPath = [System.IO.Path]::GetFullPath($Output)
    if ([System.IO.Path]::GetFileName($outputPath) -cne "report.json") {
        throw "The retained QSDK-R05A report filename must be exactly report.json"
    }
    if (Test-Path -LiteralPath $outputPath) {
        throw "Refusing to overwrite QSDK-R05A report: $outputPath"
    }
    $outputDirectory = Split-Path -Parent $outputPath
    if (Test-Path -LiteralPath $outputDirectory) {
        $existing = @(Get-ChildItem -LiteralPath $outputDirectory -Force)
        if ($existing.Count -ne 0) {
            throw "Refusing nonempty QSDK-R05A directory: $outputDirectory"
        }
    }
}

$tempBase = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::GetTempPath()
)
$tempRoot = Join-Path $tempBase (
    "sporespore_qsdk_r05a_" + [Guid]::NewGuid().ToString("N")
)
$projectRoot = Join-Path $tempRoot "project"
[void][System.IO.Directory]::CreateDirectory($projectRoot)
foreach ($directory in @("scripts", "tests", "sdk")) {
    [void](New-Item `
        -ItemType Junction `
        -Path (Join-Path $projectRoot $directory) `
        -Target (Join-Path $repoRoot $directory))
}
$projectText = @'
; Isolated SporeSpore QSDK-R05A selected-policy authority probe.

config_version=5

[application]

config/name="sporespore-qsdk-r05a-selected-policy-authority"
config/features=PackedStringArray("4.7", "Forward Plus")

[debug]

gdscript/warnings/shadowed_global_identifier=0

[physics]

3d/physics_engine="Jolt Physics"
jolt_physics_3d/simulation/velocity_steps=20
jolt_physics_3d/simulation/position_steps=7
'@
Write-Utf8NoBom -Path (Join-Path $projectRoot "project.godot") -Text $projectText

try {
    # The inherited R05 preflight now includes the v5 full gate, exact declared
    # policy runtime execution, selected-policy adapter start for all 36
    # entries, and runner/report round-trip.
    $preflightOutput = (
        & $r05PreflightRunner -Godot $godotPath -PreflightOnly *>&1 |
            Out-String
    )
    $preflightExitCode = $LASTEXITCODE
    $preflightReceipt = Get-ReceiptFromOutput `
        -OutputText $preflightOutput `
        -Prefix "QSDK_R05_PREFLIGHT_BUNDLE "
    $preflightReceiptExact = (
        [string]$preflightReceipt.schema_version -ceq
            "sporespore_qsdk_r05_preflight_bundle_v1" -and
        [string]$preflightReceipt.full_integrity_receipt_schema -ceq
            "sporespore_full_integrity_gate_satisfiability_receipt_v5" -and
        [bool]$preflightReceipt.full_integrity_passed -and
        [bool]$preflightReceipt.exact_declared_policy_runtime_boundaries_called -and
        [int]$preflightReceipt.declared_policy_runtime_boundary_count -eq 8 -and
        [bool]$preflightReceipt.declared_policy_runtime_boundaries_passed -and
        [bool]$preflightReceipt.exact_worst_case_declared_policy_runtime_horizon_called -and
        [bool]$preflightReceipt.worst_case_declared_policy_runtime_horizon_passed -and
        [int]$preflightReceipt.worst_case_declared_policy_runtime_horizon_step_count -eq 3232 -and
        [int]$preflightReceipt.worst_case_declared_policy_runtime_horizon_command_count -eq 25856 -and
        [bool]$preflightReceipt.production_execution_mode_resolver_called -and
        [bool]$preflightReceipt.perfect_zero_error_runtime_boundary_on_every_declared_policy -and
        [bool]$preflightReceipt.perfect_zero_error_full_runtime_horizon_on_worst_signed_offset -and
        [bool]$preflightReceipt.perfect_synthetic_full_integrity_gate_passed -and
        [bool]$preflightReceipt.r1_misroute_detected_before_world -and
        [bool]$preflightReceipt.exact_selected_policy_full_authority_start_called -and
        [bool]$preflightReceipt.selected_policy_full_authority_start_passed -and
        [string]$preflightReceipt.selected_policy_full_authority_start.controller_policy_id -ceq
            $expectedPolicyId -and
        [string]$preflightReceipt.selected_policy_full_authority_start.authority_scope -ceq
            "post_settle_full" -and
        [bool]$preflightReceipt.selected_policy_full_authority_start.actuation_authority -and
        [int]$preflightReceipt.entrypoint_cell_count -eq 36 -and
        [int]$preflightReceipt.exact_selected_policy_full_authority_start_count -eq 36 -and
        [bool]$preflightReceipt.entrypoint_full_authority_start_passed -and
        [int]$preflightReceipt.exact_entrypoint_declared_policy_runtime_boundary_count -eq 36 -and
        [bool]$preflightReceipt.entrypoint_declared_policy_runtime_boundary_preflight_passed -and
        [bool]$preflightReceipt.runner_report_serialization_passed -and
        [int]$preflightReceipt.actual_world_build_count -eq 0 -and
        -not [bool]$preflightReceipt.physics_state_modified -and
        -not [bool]$preflightReceipt.locomotion_outcome_exposed -and
        -not [bool]$preflightReceipt.physical_acceptance_authority
    )
    if (
        $preflightExitCode -ne 0 -or
        -not $preflightReceiptExact -or
        -not $preflightOutput.Contains(
            "36/36 real entrypoint cells plus runner/report serialization, zero worlds."
        )
    ) {
        throw "QSDK-R05A inherited zero-world preflight failed"
    }

    # Exercise this launcher's own report serialization before the world.
    $syntheticReportPath = Join-Path $tempRoot "synthetic-report.json"
    $synthetic = [ordered]@{
        schema_version = "sporespore_qsdk_r05a_runner_preflight_v1"
        perfect_synthetic_input = $true
        controller_policy_id = $expectedPolicyId
        authority_scope = "post_settle_full"
        actuation_authority = $true
        sdk_error_mismatch_failure_and_violation_count = 0
        world_build_count = 0
        physical_acceptance_authority = $false
    }
    Write-Utf8NoBom `
        -Path $syntheticReportPath `
        -Text (
            $synthetic |
                ConvertTo-Json -Depth 20 |
                ForEach-Object { $_ + [Environment]::NewLine }
        )
    $syntheticRoundTrip = (
        Get-Content -Raw -LiteralPath $syntheticReportPath |
            ConvertFrom-Json -AsHashtable
    )
    $syntheticExact = (
        [string]$syntheticRoundTrip.schema_version -ceq
            "sporespore_qsdk_r05a_runner_preflight_v1" -and
        [bool]$syntheticRoundTrip.perfect_synthetic_input -and
        [string]$syntheticRoundTrip.controller_policy_id -ceq
            $expectedPolicyId -and
        [string]$syntheticRoundTrip.authority_scope -ceq
            "post_settle_full" -and
        [bool]$syntheticRoundTrip.actuation_authority -and
        [int]$syntheticRoundTrip.sdk_error_mismatch_failure_and_violation_count -eq 0 -and
        [int]$syntheticRoundTrip.world_build_count -eq 0 -and
        -not [bool]$syntheticRoundTrip.physical_acceptance_authority
    )
    if (-not $syntheticExact) {
        throw "QSDK-R05A launcher/report synthetic preflight failed"
    }

    if ($PreflightOnly) {
        Write-Host (
            "QSDK-R05A preflight passed: v5 full integrity with 8/8 " +
            "declared-policy runtime boundaries, one complete 3,232-step " +
            "native/portable horizon, R1 step-zero negative control, 36/36 " +
            "exact full-authority starts, and runner/report serialization, " +
            "zero worlds."
        )
        return
    }

    # Durable campaign state may exist only after every zero-world check.
    [void][System.IO.Directory]::CreateDirectory($outputDirectory)
    $preflightPath = Join-Path $outputDirectory "preflight.log"
    Write-Utf8NoBom -Path $preflightPath -Text $preflightOutput
    $engineLogPath = Join-Path $outputDirectory "engine.log"
    $execution = Invoke-GodotCaptured `
        -Arguments @(
            "--headless",
            "--path", $projectRoot,
            "--log-file", $engineLogPath,
            "--script", "res://$physicalTest",
            "--", "physical", $expectedMorphologyId, ([string]$expectedSeed)
        ) `
        -WorkerRoot (Join-Path $tempRoot "physical") `
        -TimeoutSeconds $CellTimeoutSeconds
    $transcriptPath = Join-Path $outputDirectory "transcript.log"
    $stderrPath = Join-Path $outputDirectory "stderr.log"
    Write-Utf8NoBom -Path $transcriptPath -Text $execution.stdout
    Write-Utf8NoBom -Path $stderrPath -Text $execution.stderr

    $receipt = $null
    $receiptParseError = ""
    try {
        $receipt = Get-ReceiptFromOutput `
            -OutputText $execution.stdout `
            -Prefix "QSDK_R05_CELL "
    } catch {
        $receiptParseError = $_.Exception.Message
    }
    $receiptParsed = $null -ne $receipt
    $sdkStepCount = if ($receiptParsed) {
        [int]$receipt.sdk_step_count
    } else {
        -1
    }
    $technicalCapabilityPassed = (
        $receiptParsed -and
        [int]$execution.exit_code -eq 0 -and
        -not [bool]$execution.timed_out -and
        [bool]$receipt.harness_passed -and
        [int]$receipt.assertions_failed -eq 0 -and
        [bool]$receipt.common_execution_integrity -and
        [bool]$receipt.walking_observed -and
        [bool]$receipt.sdk_authority_enabled -and
        [string]$receipt.sdk_authority_scope -ceq "post_settle_full" -and
        [string]$receipt.sdk_authority_failure_code -ceq "" -and
        [string]$receipt.controller_policy_id -ceq $expectedPolicyId -and
        $sdkStepCount -gt 0 -and
        [int]$receipt.validated_balanced_wave_command_count -eq
            $sdkStepCount * 8 -and
        [int]$receipt.native_motor_write_count -eq $sdkStepCount * 8 -and
        [int]$receipt.legacy_post_settle_motor_write_count -eq 0 -and
        [int]$receipt.legacy_evidence_motor_write_count -eq 0 -and
        [int]$receipt.sdk_mismatch_count -eq 0 -and
        [int]$receipt.sdk_safe_no_actuation_count -eq 0 -and
        [int]$receipt.sdk_safe_disable_count -eq 0 -and
        [int]$receipt.world_build_count -eq 1 -and
        -not [bool]$receipt.physical_acceptance_authority
    )

    $sourceFiles = @(
        "sdk/qsdk_r05a_selected_policy_authority_preregistration.json",
        "sdk/run_qsdk_r05a_selected_policy_authority.ps1",
        "sdk/run_qsdk_r05_independent_morphology.ps1",
        "tests/test_sdk_balanced_wave_bw5r_authority_contract.gd",
        "tests/test_sdk_full_integrity_gate_satisfiability.gd",
        "tests/test_sdk_qsdk_r05_independent_morphology.gd",
        "scripts/lab/gait/sdk_godot_jolt_adapter.gd",
        "scripts/lab/gait/physical_wave_gait_quadruped.gd",
        "sdk/balanced_wave_selected_policy.json"
    )
    $sourceFileReceipts = @(
        foreach ($relativePath in $sourceFiles) {
            [ordered]@{
                path = $relativePath
                sha256 = Get-PrefixedSha256 (
                    Join-Path $repoRoot $relativePath
                )
            }
        }
    )
    $observedWorldCount = 0
    if ($receiptParsed) {
        $observedWorldCount = [int]$receipt.world_build_count
    }
    $engineLogSha256 = ""
    if (Test-Path -LiteralPath $engineLogPath) {
        $engineLogSha256 = Get-PrefixedSha256 $engineLogPath
    }
    $report = [ordered]@{
        schema_version = (
            "sporespore_qsdk_r05a_selected_policy_authority_report_v1"
        )
        generated_utc = [DateTime]::UtcNow.ToString("o")
        source = [ordered]@{
            commit = $sourceCommit
            origin_main_commit = $originMain
            clean = $true
            matches_origin_main = $true
            source_files = $sourceFileReceipts
        }
        preregistration = [ordered]@{
            path = $preregistrationPath
            sha256 = Get-PrefixedSha256 $preregistrationPath
        }
        campaign_id = "QSDK-R05A"
        gate_id = "QSDK-R05A"
        campaign_role = "technical_capability_closure"
        selected_candidate_id = "BW5R-B"
        selected_policy_id = $expectedPolicyId
        selected_policy_digest = $expectedPolicyDigest
        morphology_id = $expectedMorphologyId
        campaign_seed = $expectedSeed
        expected_world_count = 1
        observed_world_count = $observedWorldCount
        process = [ordered]@{
            exit_code = [int]$execution.exit_code
            timed_out = [bool]$execution.timed_out
            killed_process_tree = [bool]$execution.killed_process_tree
            duration_seconds = [double]$execution.duration_seconds
        }
        receipt_parsed = $receiptParsed
        receipt_parse_error = $receiptParseError
        receipt = $receipt
        artifacts = [ordered]@{
            preflight_path = $preflightPath
            preflight_sha256 = Get-PrefixedSha256 $preflightPath
            transcript_path = $transcriptPath
            transcript_sha256 = Get-PrefixedSha256 $transcriptPath
            stderr_path = $stderrPath
            stderr_sha256 = Get-PrefixedSha256 $stderrPath
            engine_log_path = $engineLogPath
            engine_log_sha256 = $engineLogSha256
        }
        inherited_full_integrity_preflight_passed = $true
        inherited_preflight_receipt = $preflightReceipt
        runner_report_synthetic_preflight_passed = $syntheticExact
        technical_capability_passed = $technicalCapabilityPassed
        independent_validation_authority = $false
        same_selected_policy_independent_morphology_evidence = $false
        arbitrary_quadruped_coverage = $false
        continuous_full_volume_coverage = $false
        cross_engine_c6 = $false
        completed_engine_neutral_sdk = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
    Write-Utf8NoBom `
        -Path $outputPath `
        -Text (
            $report |
                ConvertTo-Json -Depth 100 |
                ForEach-Object { $_ + [Environment]::NewLine }
        )
    $reportHash = Get-PrefixedSha256 $outputPath
    Write-Host "REPORT=$outputPath"
    Write-Host "REPORT_SHA256=$reportHash"
    Write-Host "QSDK_R05A=$technicalCapabilityPassed"
    if (-not $technicalCapabilityPassed) {
        throw (
            "QSDK-R05A technical capability did not pass. " +
            "The retained result is final for source $sourceCommit."
        )
    }
} finally {
    if (
        (Test-Path -LiteralPath $tempRoot) -and
        $tempRoot.StartsWith(
            $tempBase,
            [System.StringComparison]::OrdinalIgnoreCase
        ) -and
        $tempRoot.Length -gt ($tempBase.Length + 20)
    ) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

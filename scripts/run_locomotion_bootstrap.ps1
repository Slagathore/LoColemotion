#requires -Version 7.0

<#
.SYNOPSIS
Runs the BR1/L0 development diagnostic in its required sequential order.

.DESCRIPTION
This is a development diagnostic for evidence infrastructure, not the pinned
BR1 certification campaign, not a locomotion demo, and not proof of standing,
bracing, recovery, or walking. Formal certification uses
scripts/run_br1_certification.ps1.

Run this script with PowerShell 7 (`pwsh`), not legacy Windows PowerShell 5.1.
The bounded native-process runner depends on the modern
ProcessStartInfo.ArgumentList API so paths and arguments remain unambiguous.

The script:

1. Runs the hardened lab-test harness in a separate PowerShell process.
2. Launches L0.0 through the canonical parent-owned fresh-process launcher.
3. independently checks the finalized bundle's completion witnesses,
   checksums, and detached publication receipt.
4. Replays that bundle from sealed traces with simulation_steps=0.
5. Optionally admits one supplied draft as a development_observation in the
   flat append-only knowledge catalog.

Godot exit code 2 is accepted only for the narrow dirty-source case where the
bundle is final, internally consistent, physically supported, and blocked from
promotion solely at the source-state boundary. All parse, engine, test,
configuration, physical-gate, checksum, replay, and admission failures stop the
pipeline.

.EXAMPLE
.\scripts\run_locomotion_bootstrap.ps1

.EXAMPLE
.\scripts\run_locomotion_bootstrap.ps1 `
  -Seed 4242 `
  -KnowledgeDraft "res://data/lab/knowledge/drafts/L0_0_stationary_gravity_off.development.json" `
  -KnowledgeOutputName "l0_stationary.seed-4242.json"
#>

[CmdletBinding()]
param(
    [string]$Godot = "C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe",
    [long]$Seed = 42,
    [string]$Observer = "full_contacts_v1",
    [string]$TestPattern = "test_lab_*.gd",
    [string]$OutputRoot = (
        Join-Path $env:TEMP "sporespore_locomotion_bootstrap"
    ),
    [string]$KnowledgeDraft = "",
    [string]$KnowledgeOutputName = "",
    [ValidateRange(1, 3600)]
    [int]$TestTimeoutSeconds = 120,
    [ValidateRange(1, 86400)]
    [int]$LabSuiteTimeoutSeconds = 7200,
    [ValidateRange(1, 86400)]
    [int]$StepTimeoutSeconds = 600
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
# PowerShell 7 can turn an expected native exit 2 into a PowerShell error
# record. Native status is evaluated explicitly below instead.
$PSNativeCommandUseErrorActionPreference = $false

$script:RepoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$processRunner = Join-Path $PSScriptRoot "process_runner.ps1"
if (-not (Test-Path -LiteralPath $processRunner -PathType Leaf)) {
    throw "Process runner not found: $processRunner"
}
. $processRunner
$script:SessionRoot = $null
$script:BootstrapReportPath = $null

$l00ExperimentSpec = "res://data/lab/experiments/L0_0_stationary_gravity_off_v1.tres"
$l04ReplaySpec = "res://data/lab/experiments/L0_4_trace_playback_v1.tres"
$expectedExperimentId = "L0_0_STATIONARY_GRAVITY_OFF"


function Stop-Bootstrap {
    param([Parameter(Mandatory = $true)][string]$Message)

    throw [System.InvalidOperationException]::new($Message)
}


function Get-NormalizedFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return [System.IO.Path]::GetFullPath($Path).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
}


function Test-PathAtOrBelow {
    param(
        [Parameter(Mandatory = $true)][string]$Candidate,
        [Parameter(Mandatory = $true)][string]$Parent
    )

    $candidatePath = Get-NormalizedFullPath -Path $Candidate
    $parentPath = Get-NormalizedFullPath -Path $Parent
    if ($candidatePath.Equals(
        $parentPath,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        return $true
    }
    $prefix = $parentPath + [System.IO.Path]::DirectorySeparatorChar
    return $candidatePath.StartsWith(
        $prefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )
}


function Read-JsonObject {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Stop-Bootstrap "$Label is missing: $Path"
    }
    try {
        $value = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop |
            ConvertFrom-Json -ErrorAction Stop
    } catch {
        Stop-Bootstrap "$Label is not valid JSON: $Path ($($_.Exception.Message))"
    }
    if (
        $null -eq $value -or
        $value -is [System.Array] -or
        $value -is [string] -or
        $value -is [ValueType]
    ) {
        Stop-Bootstrap "$Label must contain exactly one JSON object: $Path"
    }
    return $value
}


function Invoke-CapturedProcess {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$ArgumentList,
        [Parameter(Mandatory = $true)][string]$TranscriptPath,
        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 86400)]
        [int]$TimeoutSeconds
    )

    Write-Host "=== BOOTSTRAP STEP $Label ==="
    $processResult = Invoke-ProcessWithTimeout `
        -FilePath $FilePath `
        -ArgumentList $ArgumentList `
        -TimeoutSeconds $TimeoutSeconds `
        -TranscriptPath $TranscriptPath
    $outputLines = @($processResult.Lines)
    $outputLines | ForEach-Object { Write-Host $_ }
    Write-Host (
        "BOOTSTRAP step=$Label " +
        "native_exit=$($processResult.ExitCode) " +
        "timed_out=$($processResult.TimedOut) " +
        "duration_ms=$($processResult.DurationMs)"
    )

    if ($processResult.TimedOut) {
        Stop-Bootstrap (
            "$Label exceeded its ${TimeoutSeconds}-second timeout; " +
            "the child process tree was terminated."
        )
    }
    if (-not [string]::IsNullOrWhiteSpace($processResult.StartError)) {
        Stop-Bootstrap "$Label failed to start or wait: $($processResult.StartError)"
    }
    if (-not [string]::IsNullOrWhiteSpace($processResult.TerminationError)) {
        Stop-Bootstrap (
            "$Label process-tree termination failed: " +
            $processResult.TerminationError
        )
    }

    return [pscustomobject]@{
        Label = $Label
        ExitCode = [int]$processResult.ExitCode
        TimedOut = [bool]$processResult.TimedOut
        TimeoutSeconds = [int]$processResult.TimeoutSeconds
        DurationMs = [int64]$processResult.DurationMs
        Lines = $outputLines
        Text = $outputLines -join [Environment]::NewLine
        TranscriptPath = $TranscriptPath
    }
}


function Assert-NoGodotErrors {
    param(
        [Parameter(Mandatory = $true)]$Invocation,
        [Parameter(Mandatory = $true)][string]$EngineLogPath
    )

    if (-not (Test-Path -LiteralPath $EngineLogPath -PathType Leaf)) {
        Stop-Bootstrap (
            "$($Invocation.Label) did not create its required Godot engine log: " +
            $EngineLogPath
        )
    }
    $engineLogText = Get-Content -LiteralPath $EngineLogPath -Raw
    $combined = (
        $Invocation.Text +
        [Environment]::NewLine +
        $engineLogText
    )
    $engineErrors = @(
        [regex]::Matches(
            $combined,
            '(?im)^\s*(?:SCRIPT ERROR:|ERROR:).*$'
        ) |
            ForEach-Object { $_.Value.Trim() } |
            Sort-Object -Unique
    )
    if ($engineErrors.Count -gt 0) {
        $sample = (@($engineErrors | Select-Object -First 3)) -join " | "
        Stop-Bootstrap (
            "$($Invocation.Label) emitted $($engineErrors.Count) Godot " +
            "engine/script error line(s): $sample"
        )
    }

    $failureMarkers = @(
        [regex]::Matches(
            $Invocation.Text,
            '(?im)^\s*(?:LAB|KNOWLEDGE)\s+[^\r\n]*' +
            '(?:_error=|=failed\b|=blocked\b|controlled_abort\b|' +
            'run_failed\b|publication_blocked\b).*$'
        ) |
            ForEach-Object { $_.Value.Trim() } |
            Sort-Object -Unique
    )
    if ($failureMarkers.Count -gt 0) {
        Stop-Bootstrap (
            "$($Invocation.Label) printed an explicit failure marker: " +
            ((@($failureMarkers | Select-Object -First 3)) -join " | ")
        )
    }
}


function Get-SingleMarkerValue {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $matcher = [regex]::new($Pattern)
    $values = @(
        foreach ($line in $Lines) {
            $match = $matcher.Match($line)
            if ($match.Success) {
                $match.Groups[1].Value.Trim()
            }
        }
    )
    if ($values.Count -ne 1) {
        Stop-Bootstrap (
            "$Label must appear exactly once; observed $($values.Count) marker(s)."
        )
    }
    return $values[0]
}


function Assert-LabTestReport {
    param(
        [Parameter(Mandatory = $true)]$Report,
        [Parameter(Mandatory = $true)][string]$ExpectedPattern,
        [Parameter(Mandatory = $true)][string]$ExpectedRepository,
        [Parameter(Mandatory = $true)][string]$ExpectedGodot
    )

    if ($Report.schema -ne "sporespore.lab.test_report.v1") {
        Stop-Bootstrap "The hardened lab-test report has an unknown schema."
    }
    if ($Report.pattern -ne $ExpectedPattern) {
        Stop-Bootstrap "The lab-test report pattern differs from the requested pattern."
    }
    if (
        -not (Get-NormalizedFullPath -Path ([string]$Report.repository)).Equals(
            (Get-NormalizedFullPath -Path $ExpectedRepository),
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        -not (Get-NormalizedFullPath -Path ([string]$Report.godot)).Equals(
            (Get-NormalizedFullPath -Path $ExpectedGodot),
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {
        Stop-Bootstrap "The lab-test report names an unexpected repository or engine."
    }
    $total = [int]$Report.total
    $passed = [int]$Report.passed
    $failed = [int]$Report.failed
    $rows = @($Report.results)
    if (
        $total -le 0 -or
        $rows.Count -ne $total -or
        $failed -ne 0 -or
        $passed -ne $total
    ) {
        Stop-Bootstrap (
            "The hardened lab-test report is not a complete pass " +
            "(total=$total passed=$passed failed=$failed rows=$($rows.Count))."
        )
    }
    foreach ($row in $rows) {
        if (
            $row.status -ne "pass" -or
            [int]$row.process_exit_code -ne 0 -or
            $row.footer_found -ne $true -or
            $null -eq $row.assertions_passed -or
            [int]$row.assertions_passed -le 0 -or
            $null -eq $row.assertions_failed -or
            [int]$row.assertions_failed -ne 0 -or
            @($row.unexpected_engine_errors).Count -ne 0 -or
            @($row.missing_expected_engine_error_codes).Count -ne 0 -or
            @($row.unknown_expected_engine_error_codes).Count -ne 0
        ) {
            Stop-Bootstrap (
                "The hardened lab-test report contains a non-passing or " +
                "incompletely witnessed row: $($row.test)"
            )
        }
    }
}


function Assert-BundleChecksums {
    param(
        [Parameter(Mandatory = $true)][string]$BundlePath,
        [Parameter(Mandatory = $true)]$Checksums
    )

    if (
        $Checksums.schema -ne "sporespore.lab.checksums.v1" -or
        $Checksums.algorithm -ne "sha256"
    ) {
        Stop-Bootstrap "The bundle checksum index has an unknown contract."
    }
    $entries = @($Checksums.artifacts.PSObject.Properties)
    if (
        $entries.Count -le 0 -or
        [int]$Checksums.artifact_count -ne $entries.Count
    ) {
        Stop-Bootstrap "The checksum artifact count is absent or inconsistent."
    }
    foreach ($property in $entries) {
        $artifactName = [string]$property.Name
        if (
            [string]::IsNullOrWhiteSpace($artifactName) -or
            $artifactName.Contains("..") -or
            $artifactName.Contains("/") -or
            $artifactName.Contains("\")
        ) {
            Stop-Bootstrap "Unsafe artifact name in checksums.json: $artifactName"
        }
        $artifactPath = Join-Path $BundlePath $artifactName
        if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
            Stop-Bootstrap "Checksummed artifact is missing: $artifactPath"
        }
        $entry = $property.Value
        $actualHash = "sha256:$(
            (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
        )"
        if ($entry.sha256 -ne $actualHash) {
            Stop-Bootstrap "Checksum mismatch for bundle artifact: $artifactName"
        }
        $actualBytes = [long](Get-Item -LiteralPath $artifactPath).Length
        if ([long]$entry.bytes -ne $actualBytes) {
            Stop-Bootstrap "Byte-count mismatch for bundle artifact: $artifactName"
        }
    }
}


function Assert-L00FinalBundle {
    param(
        [Parameter(Mandatory = $true)][string]$BundlePath,
        [Parameter(Mandatory = $true)][int]$LauncherExitCode,
        [Parameter(Mandatory = $true)][long]$ExpectedSeed,
        [Parameter(Mandatory = $true)][string]$ExpectedObserver
    )

    $requiredFiles = @(
        "manifest.json",
        "summary.json",
        "checksums.json",
        "process_metadata.json",
        "configuration.json",
        "launch_plan.json",
        "engine.log",
        "frames.jsonl",
        "runtime_notes.jsonl"
    )
    foreach ($name in $requiredFiles) {
        $requiredPath = Join-Path $BundlePath $name
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            Stop-Bootstrap "Final L0.0 bundle is missing required artifact: $name"
        }
    }
    if (Test-Path -LiteralPath (Join-Path $BundlePath ".adoption_token")) {
        Stop-Bootstrap "Final L0.0 bundle leaked its one-shot adoption token."
    }

    $manifest = Read-JsonObject `
        -Path (Join-Path $BundlePath "manifest.json") `
        -Label "L0.0 manifest"
    $summary = Read-JsonObject `
        -Path (Join-Path $BundlePath "summary.json") `
        -Label "L0.0 summary"
    $checksums = Read-JsonObject `
        -Path (Join-Path $BundlePath "checksums.json") `
        -Label "L0.0 checksums"
    $process = Read-JsonObject `
        -Path (Join-Path $BundlePath "process_metadata.json") `
        -Label "L0.0 process metadata"
    $configuration = Read-JsonObject `
        -Path (Join-Path $BundlePath "configuration.json") `
        -Label "L0.0 configuration evidence"

    Assert-BundleChecksums -BundlePath $BundlePath -Checksums $checksums
    $checksumNames = @(
        $checksums.artifacts.PSObject.Properties |
            ForEach-Object { [string]$_.Name }
    )
    foreach ($sealedRequiredName in ($requiredFiles | Where-Object {
        $_ -ne "checksums.json"
    })) {
        if ($sealedRequiredName -notin $checksumNames) {
            Stop-Bootstrap (
                "Required L0.0 artifact is present but not checksum-sealed: " +
                $sealedRequiredName
            )
        }
    }
    $currentL00RequiredArtifacts = @(
        "manifest.json",
        "process_metadata.json",
        "configuration.json",
        "pre_event_snapshot.jsonl",
        "frames.jsonl",
        "commands.jsonl",
        "applications.jsonl",
        "decisions.jsonl",
        "interventions.jsonl",
        "mechanics.jsonl",
        "events.jsonl",
        "runtime_notes.jsonl",
        "summary.json",
        "launch_plan.json"
    )
    foreach ($declaredRequiredName in $currentL00RequiredArtifacts) {
        if ($declaredRequiredName -notin @($manifest.required_artifacts)) {
            Stop-Bootstrap (
                "Manifest does not declare required L0.0 artifact: " +
                $declaredRequiredName
            )
        }
        if ($declaredRequiredName -notin $checksumNames) {
            Stop-Bootstrap (
                "Manifest-required L0.0 artifact is not checksum-sealed: " +
                $declaredRequiredName
            )
        }
    }
    foreach ($manifestRequiredName in @($manifest.required_artifacts)) {
        if ([string]$manifestRequiredName -notin $checksumNames) {
            Stop-Bootstrap (
                "A manifest-required artifact is absent from checksums.json: " +
                [string]$manifestRequiredName
            )
        }
    }
    $actualImmutableNames = @(
        Get-ChildItem -LiteralPath $BundlePath -File -Force |
            Where-Object {
                $_.Name -ne "checksums.json" -and
                -not $_.Name.EndsWith(".tmp") -and
                -not $_.Name.EndsWith(".previous")
            } |
            ForEach-Object { $_.Name }
    )
    foreach ($actualImmutableName in $actualImmutableNames) {
        if ($actualImmutableName -notin $checksumNames) {
            Stop-Bootstrap (
                "Final bundle contains an immutable file outside the checksum " +
                "domain: $actualImmutableName"
            )
        }
    }

    $bundleLeaf = Split-Path -Leaf $BundlePath
    if (
        $bundleLeaf.EndsWith(
            ".partial",
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        $manifest.status -ne "COMPLETE" -or
        $summary.termination -ne "completed" -or
        $summary.evidence_validity -ne "valid"
    ) {
        Stop-Bootstrap "L0.0 did not produce a completed, valid, final bundle."
    }
    if (
        $manifest.schema -ne "sporespore.lab.manifest.v1" -or
        $summary.schema -ne "sporespore.lab.summary.v1" -or
        $configuration.schema -ne "sporespore.lab.configuration.v1"
    ) {
        Stop-Bootstrap "L0.0 bundle contains an unknown core artifact schema."
    }
    if (
        $manifest.run_id -ne $summary.run_id -or
        $manifest.run_id -ne $checksums.run_id -or
        $manifest.run_id -ne $process.run_id -or
        $manifest.run_id -ne $configuration.run_id -or
        $manifest.run_id -ne $bundleLeaf
    ) {
        Stop-Bootstrap "L0.0 bundle run identity is inconsistent."
    }
    if (
        $manifest.experiment_id -ne $expectedExperimentId -or
        [long]$manifest.seed_root -ne $ExpectedSeed -or
        $manifest.observer_profile -ne $ExpectedObserver
    ) {
        Stop-Bootstrap "L0.0 bundle identity differs from the requested experiment."
    }
    if ($manifest.process_isolation -ne "outer_parent_reserved_fresh_godot_v1") {
        Stop-Bootstrap "L0.0 was not executed by the canonical fresh-process launcher."
    }
    if (
        $process.status -ne "COMPLETE" -or
        [int]$process.exit_code -ne 0 -or
        $process.exit_disposition -ne "candidate_ready_parent_observed" -or
        $process.argument_capture_quality -ne "launcher_exact" -or
        [long]$process.child_process_id -le 0 -or
        [long]$process.parent_process_id -le 0 -or
        [long]$process.child_process_id -eq [long]$process.parent_process_id -or
        [long]$process.termination_observer_process_id -ne
            [long]$process.parent_process_id
    ) {
        Stop-Bootstrap "L0.0 fresh-process provenance is incomplete or inconsistent."
    }
    if (
        $process.log_paths.engine_log.status -ne "captured" -or
        [string]::IsNullOrWhiteSpace(
            [string]$process.log_paths.engine_log.path
        ) -or
        $process.log_paths.stdout.status -ne "unavailable" -or
        $null -ne $process.log_paths.stdout.path -or
        [string]::IsNullOrWhiteSpace(
            [string]$process.log_paths.stdout.reason
        ) -or
        $process.log_paths.stderr.status -ne "unavailable" -or
        $null -ne $process.log_paths.stderr.path -or
        [string]::IsNullOrWhiteSpace(
            [string]$process.log_paths.stderr.reason
        )
    ) {
        Stop-Bootstrap (
            "L0.0 process logs do not truthfully distinguish captured " +
            "engine output from unavailable stdout/stderr capture."
        )
    }
    $recordedFinalPath = Get-NormalizedFullPath -Path ([string]$process.final_path)
    if (-not $recordedFinalPath.Equals(
        (Get-NormalizedFullPath -Path $BundlePath),
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        Stop-Bootstrap "Parent-recorded final path does not match the observed bundle."
    }
    if (
        $configuration.configuration_valid -ne $true -or
        $configuration.match -ne $true -or
        @($configuration.errors).Count -ne 0 -or
        $configuration.resolved_configuration_sha256 -ne
            $manifest.resolved_configuration_sha256 -or
        $configuration.applied_configuration_sha256 -ne
            $manifest.applied_configuration_sha256
    ) {
        Stop-Bootstrap "Resolved/applied/observed L0.0 configuration did not agree."
    }
    if (
        $summary.gate_results.configuration.pass -ne $true -or
        $summary.gate_results.physical.pass -ne $true -or
        $summary.hypothesis_result -ne "supported" -or
        @($summary.failure_codes).Count -ne 0 -or
        [int]$summary.frame_count -le 0
    ) {
        Stop-Bootstrap "L0.0 physical or configuration evidence gate did not pass."
    }

    if ($LauncherExitCode -eq 2) {
        if (
            $manifest.dirty_worktree -ne $true -or
            $manifest.execution_mode -ne "development" -or
            $manifest.reproducibility -ne "partial_dirty_source" -or
            $summary.promotion -ne "not_evaluated" -or
            $summary.gate_results.source_state.pass -ne $false -or
            "DIRTY_WORKTREE" -notin @($summary.gate_results.source_state.reasons)
        ) {
            Stop-Bootstrap (
                "Godot exit 2 was not the narrow completed dirty-source " +
                "development outcome."
            )
        }
    } elseif ($LauncherExitCode -eq 0) {
        if (
            $manifest.dirty_worktree -ne $false -or
            $manifest.execution_mode -ne "promotion" -or
            $manifest.reproducibility -ne "clean_committed_source" -or
            $summary.promotion -ne "pass" -or
            $summary.gate_results.source_state.pass -ne $true
        ) {
            Stop-Bootstrap "Godot exit 0 did not correspond to promotion-grade L0.0 evidence."
        }
    } else {
        Stop-Bootstrap "Canonical L0.0 returned disallowed exit code $LauncherExitCode."
    }

    return [pscustomobject]@{
        Manifest = $manifest
        Summary = $summary
        Process = $process
        Configuration = $configuration
        Checksums = $checksums
    }
}


function Resolve-KnowledgeDraft {
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [Parameter(Mandatory = $true)][string]$RepositoryRoot
    )

    if ($InputPath.StartsWith(
        "res://",
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        $relative = $InputPath.Substring(6).Replace(
            "/",
            [System.IO.Path]::DirectorySeparatorChar
        )
        $candidate = [System.IO.Path]::GetFullPath(
            (Join-Path $RepositoryRoot $relative)
        )
        if (-not (Test-PathAtOrBelow -Candidate $candidate -Parent $RepositoryRoot)) {
            Stop-Bootstrap "Knowledge draft escapes the repository root."
        }
        $godotPath = "res://" + $relative.Replace("\", "/")
    } else {
        $candidateInput = $InputPath
        if (-not [System.IO.Path]::IsPathRooted($candidateInput)) {
            $candidateInput = Join-Path $RepositoryRoot $candidateInput
        }
        try {
            $candidate = (Resolve-Path -LiteralPath $candidateInput -ErrorAction Stop).Path
        } catch {
            Stop-Bootstrap "Knowledge draft does not exist: $InputPath"
        }
        if (Test-PathAtOrBelow -Candidate $candidate -Parent $RepositoryRoot) {
            $relative = [System.IO.Path]::GetRelativePath(
                $RepositoryRoot,
                $candidate
            )
            $godotPath = "res://" + $relative.Replace("\", "/")
        } else {
            $godotPath = $candidate.Replace("\", "/")
        }
    }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        Stop-Bootstrap "Knowledge draft is not one file: $InputPath"
    }
    if (
        [System.IO.Path]::GetFileName($candidate).Equals(
            "knowledge_draft.template.json",
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {
        Stop-Bootstrap "Refusing to admit the unedited knowledge-draft template."
    }
    $null = Read-JsonObject -Path $candidate -Label "Knowledge draft"
    return [pscustomobject]@{
        AbsolutePath = Get-NormalizedFullPath -Path $candidate
        GodotPath = $godotPath
    }
}


function Assert-FlatKnowledgeOutputName {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (
        $Name.Length -gt 240 -or
        $Name.Contains("..") -or
        $Name -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*\.json$'
    ) {
        Stop-Bootstrap (
            "Knowledge output must be one new flat .json filename containing " +
            "only letters, digits, dot, underscore, and hyphen."
        )
    }
}


try {
    if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
        Stop-Bootstrap "Godot executable not found: $Godot"
    }
    $godotPath = (Resolve-Path -LiteralPath $Godot).Path
    if (
        [string]::IsNullOrWhiteSpace($Observer) -or
        $Observer -notmatch '^[A-Za-z][A-Za-z0-9._-]{0,159}$'
    ) {
        Stop-Bootstrap "Observer must be one stable observer-profile ID."
    }
    if (
        [string]::IsNullOrWhiteSpace($TestPattern) -or
        $TestPattern.Contains("/") -or
        $TestPattern.Contains("\")
    ) {
        Stop-Bootstrap "TestPattern must be one filename filter, not a path."
    }
    if (
        -not [string]::IsNullOrWhiteSpace($KnowledgeOutputName) -and
        [string]::IsNullOrWhiteSpace($KnowledgeDraft)
    ) {
        Stop-Bootstrap "KnowledgeOutputName requires KnowledgeDraft."
    }
    if (-not [string]::IsNullOrWhiteSpace($KnowledgeOutputName)) {
        Assert-FlatKnowledgeOutputName -Name $KnowledgeOutputName
    }

    $outputRootPath = [System.IO.Path]::GetFullPath($OutputRoot)
    if (Test-PathAtOrBelow -Candidate $outputRootPath -Parent $script:RepoRoot) {
        Stop-Bootstrap (
            "OutputRoot must be outside the repository so operator logs and " +
            "run artifacts cannot change the source snapshot under test."
        )
    }
    $runStamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssfffZ")
    $script:SessionRoot = Join-Path $outputRootPath "$runStamp-pid-$PID"
    if (Test-Path -LiteralPath $script:SessionRoot) {
        Stop-Bootstrap "Bootstrap session path already exists: $script:SessionRoot"
    }
    New-Item -ItemType Directory -Path $script:SessionRoot | Out-Null
    $script:BootstrapReportPath = Join-Path $script:SessionRoot "bootstrap_report.json"
    $runOutputRoot = Join-Path $script:SessionRoot "runs"
    New-Item -ItemType Directory -Path $runOutputRoot | Out-Null

    $l00SpecOnDisk = Join-Path $script:RepoRoot $l00ExperimentSpec.Substring(6)
    $l04SpecOnDisk = Join-Path $script:RepoRoot $l04ReplaySpec.Substring(6)
    $labTestScript = Join-Path $PSScriptRoot "run_lab_tests.ps1"
    $processSelfTestScript = Join-Path $PSScriptRoot "test_process_runner.ps1"
    $attestationInitializer = Join-Path `
        $PSScriptRoot `
        "initialize_lab_attestation.ps1"
    foreach (
        $requiredInput in @(
            $l00SpecOnDisk,
            $l04SpecOnDisk,
            $labTestScript,
            $processSelfTestScript,
            $attestationInitializer
        )
    ) {
        if (-not (Test-Path -LiteralPath $requiredInput -PathType Leaf)) {
            Stop-Bootstrap "Required bootstrap input is missing: $requiredInput"
        }
    }

    $draft = $null
    if (-not [string]::IsNullOrWhiteSpace($KnowledgeDraft)) {
        $draft = Resolve-KnowledgeDraft `
            -InputPath $KnowledgeDraft `
            -RepositoryRoot $script:RepoRoot
    }

    # The test harness intentionally calls exit, so isolate it in a child
    # PowerShell process. This also gives the operator an unambiguous native
    # exit status and preserves the harness's own JSON report.
    $powerShellExecutable = if ($PSVersionTable.PSEdition -eq "Core") {
        Join-Path $PSHOME "pwsh.exe"
    } else {
        Join-Path $PSHOME "powershell.exe"
    }
    if (-not (Test-Path -LiteralPath $powerShellExecutable -PathType Leaf)) {
        Stop-Bootstrap "Cannot locate the current PowerShell executable."
    }

    $processSelfTestTranscript = Join-Path `
        $script:SessionRoot `
        "process_runner_self_test.transcript.log"
    $processSelfTestScratch = Join-Path `
        $script:SessionRoot `
        "process_runner_self_test"
    $processSelfTest = Invoke-CapturedProcess `
        -Label "PROCESS_RUNNER_SELF_TEST" `
        -FilePath $powerShellExecutable `
        -ArgumentList @(
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            $processSelfTestScript,
            "-ScratchRoot",
            $processSelfTestScratch
        ) `
        -TranscriptPath $processSelfTestTranscript `
        -TimeoutSeconds 30
    if ($processSelfTest.ExitCode -ne 0) {
        Stop-Bootstrap (
            "The process-runner self-test returned exit " +
            "$($processSelfTest.ExitCode)."
        )
    }
    $selfTestPassLines = @(
        $processSelfTest.Lines |
            Where-Object {
                $_ -match (
                    '^PROCESS_RUNNER_SELF_TEST pass=true ' +
                    'success_exit=0 timeout_detected=True ' +
                    'process_tree_killed=True\s*$'
                )
            }
    )
    if ($selfTestPassLines.Count -ne 1) {
        Stop-Bootstrap (
            "The process-runner self-test did not emit exactly one complete " +
            "success witness."
        )
    }

    $attestationInitializeTranscript = Join-Path `
        $script:SessionRoot `
        "attestation_initializer.transcript.log"
    $attestationInitialize = Invoke-CapturedProcess `
        -Label "PUBLICATION_TRUST_INITIALIZATION" `
        -FilePath $powerShellExecutable `
        -ArgumentList @(
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            $attestationInitializer
        ) `
        -TranscriptPath $attestationInitializeTranscript `
        -TimeoutSeconds 30
    if ($attestationInitialize.ExitCode -ne 0) {
        Stop-Bootstrap (
            "The production publication-trust initializer returned exit " +
            "$($attestationInitialize.ExitCode)."
        )
    }
    $attestationJsonLines = @(
        $attestationInitialize.Lines |
            Where-Object { $_ -match '^\s*\{.+\}\s*$' }
    )
    if ($attestationJsonLines.Count -ne 1) {
        Stop-Bootstrap (
            "The publication-trust initializer did not emit exactly one " +
            "machine-readable result."
        )
    }
    try {
        $attestationState = $attestationJsonLines[0] |
            ConvertFrom-Json -ErrorAction Stop
    } catch {
        Stop-Bootstrap "The publication-trust initializer result is invalid JSON."
    }
    $expectedTrustRoot = [System.IO.Path]::GetFullPath(
        (Join-Path $env:LOCALAPPDATA "SporeSpore\LabTrust\v1")
    )
    if (
        [string]$attestationState.key_id -notmatch '^sha256:[a-f0-9]{64}$' -or
        -not (Get-NormalizedFullPath -Path (
            [string]$attestationState.trust_root
        )).Equals(
            (Get-NormalizedFullPath -Path $expectedTrustRoot),
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        -not (Test-Path -LiteralPath (
            [string]$attestationState.active_key_pointer
        ) -PathType Leaf) -or
        -not (Test-Path -LiteralPath (
            [string]$attestationState.receipts_directory
        ) -PathType Container)
    ) {
        Stop-Bootstrap (
            "The publication-trust initializer returned an unexpected or " +
            "incomplete production state."
        )
    }

    $testLogRoot = Join-Path $script:SessionRoot "lab_tests"
    $testTranscript = Join-Path $script:SessionRoot "lab_tests.transcript.log"
    $testInvocation = Invoke-CapturedProcess `
        -Label "LAB_TESTS" `
        -FilePath $powerShellExecutable `
        -ArgumentList @(
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            $labTestScript,
            "-Godot",
            $godotPath,
            "-Pattern",
            $TestPattern,
            "-LogRoot",
            $testLogRoot,
            "-TestTimeoutSeconds",
            $TestTimeoutSeconds.ToString(
                [System.Globalization.CultureInfo]::InvariantCulture)
        ) `
        -TranscriptPath $testTranscript `
        -TimeoutSeconds $LabSuiteTimeoutSeconds
    if ($testInvocation.ExitCode -ne 0) {
        Stop-Bootstrap "The hardened lab-test harness returned exit $($testInvocation.ExitCode)."
    }
    $testReportMarker = Get-SingleMarkerValue `
        -Lines $testInvocation.Lines `
        -Pattern '^REPORT\s+(.+?)\s*$' `
        -Label "Hardened test REPORT"
    try {
        $testReportPath = (Resolve-Path -LiteralPath $testReportMarker -ErrorAction Stop).Path
    } catch {
        Stop-Bootstrap "The hardened test report marker names a missing file."
    }
    if (-not (Test-PathAtOrBelow -Candidate $testReportPath -Parent $testLogRoot)) {
        Stop-Bootstrap "The hardened test report was written outside its assigned log root."
    }
    $testReport = Read-JsonObject `
        -Path $testReportPath `
        -Label "Hardened lab-test report"
    Assert-LabTestReport `
        -Report $testReport `
        -ExpectedPattern $TestPattern `
        -ExpectedRepository $script:RepoRoot `
        -ExpectedGodot $godotPath

    $launchEngineLog = Join-Path $script:SessionRoot "l0_0_parent.engine.log"
    $launchTranscript = Join-Path $script:SessionRoot "l0_0_parent.transcript.log"
    $launchInvocation = Invoke-CapturedProcess `
        -Label "CANONICAL_L0_0" `
        -FilePath $godotPath `
        -ArgumentList @(
            "--headless",
            "--path",
            $script:RepoRoot,
            "--log-file",
            $launchEngineLog,
            "--script",
            "res://scripts/lab/launch_lab.gd",
            "--",
            "--experiment-spec",
            $l00ExperimentSpec,
            "--seed",
            $Seed.ToString([System.Globalization.CultureInfo]::InvariantCulture),
            "--observer",
            $Observer,
            "--output-root",
            $runOutputRoot
        ) `
        -TranscriptPath $launchTranscript `
        -TimeoutSeconds $StepTimeoutSeconds
    Assert-NoGodotErrors `
        -Invocation $launchInvocation `
        -EngineLogPath $launchEngineLog
    if ($launchInvocation.ExitCode -notin @(0, 2)) {
        Stop-Bootstrap (
            "Canonical L0.0 returned disallowed exit " +
            "$($launchInvocation.ExitCode)."
        )
    }
    $attestationMarker = [regex]::new(
        '^LAB attestation=valid algorithm=(hmac-sha256) ' +
        'key_id=(sha256:[a-f0-9]{64}) receipt=(.+?)\s*$'
    )
    $attestationMatches = @(
        foreach ($line in $launchInvocation.Lines) {
            $match = $attestationMarker.Match($line)
            if ($match.Success) {
                $match
            }
        }
    )
    if ($attestationMatches.Count -ne 1) {
        Stop-Bootstrap (
            "Canonical L0.0 did not emit exactly one detached publication " +
            "attestation marker."
        )
    }
    $publicationKeyId = $attestationMatches[0].Groups[2].Value
    $publicationReceiptPath = Get-NormalizedFullPath `
        -Path $attestationMatches[0].Groups[3].Value
    if (
        $publicationKeyId -ne [string]$attestationState.key_id -or
        -not (Test-Path -LiteralPath $publicationReceiptPath -PathType Leaf) -or
        -not (Get-NormalizedFullPath -Path (
            Split-Path -Parent $publicationReceiptPath
        )).Equals(
            (Get-NormalizedFullPath -Path (
                [string]$attestationState.receipts_directory
            )),
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        (Test-PathAtOrBelow `
            -Candidate $publicationReceiptPath `
            -Parent $runOutputRoot) -or
        (Test-PathAtOrBelow `
            -Candidate $publicationReceiptPath `
            -Parent $script:RepoRoot)
    ) {
        Stop-Bootstrap (
            "Canonical L0.0 named an absent, misplaced, or unexpected " +
            "publication receipt."
        )
    }
    $artifactMarker = Get-SingleMarkerValue `
        -Lines $launchInvocation.Lines `
        -Pattern '^LAB artifacts=(.+?)\s*$' `
        -Label "Canonical L0.0 artifact path"
    try {
        $bundlePath = (Resolve-Path -LiteralPath $artifactMarker -ErrorAction Stop).Path
    } catch {
        Stop-Bootstrap "Canonical L0.0 artifact marker names a missing path."
    }
    if (-not (Test-Path -LiteralPath $bundlePath -PathType Container)) {
        Stop-Bootstrap "Canonical L0.0 artifact path is not a directory."
    }
    if (
        -not (Test-PathAtOrBelow -Candidate $bundlePath -Parent $runOutputRoot) -or
        -not (Get-NormalizedFullPath -Path (Split-Path -Parent $bundlePath)).Equals(
            (Get-NormalizedFullPath -Path $runOutputRoot),
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {
        Stop-Bootstrap "Canonical L0.0 artifact is not one direct child of its run root."
    }
    $finalRunDirectories = @(
        Get-ChildItem -LiteralPath $runOutputRoot -Directory |
            Where-Object {
                -not $_.Name.EndsWith(
                    ".partial",
                    [System.StringComparison]::OrdinalIgnoreCase
                )
            }
    )
    $partialRunDirectories = @(
        Get-ChildItem -LiteralPath $runOutputRoot -Directory |
            Where-Object {
                $_.Name.EndsWith(
                    ".partial",
                    [System.StringComparison]::OrdinalIgnoreCase
                )
            }
    )
    if (
        $finalRunDirectories.Count -ne 1 -or
        $partialRunDirectories.Count -ne 0 -or
        -not $finalRunDirectories[0].FullName.Equals(
            $bundlePath,
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {
        Stop-Bootstrap (
            "Canonical L0.0 must leave exactly one final bundle and no partial bundle."
        )
    }
    $bundle = Assert-L00FinalBundle `
        -BundlePath $bundlePath `
        -LauncherExitCode $launchInvocation.ExitCode `
        -ExpectedSeed $Seed `
        -ExpectedObserver $Observer
    $bundleEngineLog = Join-Path $bundlePath "engine.log"
    $bundleEngineText = Get-Content -LiteralPath $bundleEngineLog -Raw
    if ($bundleEngineText -match '(?im)^\s*(?:SCRIPT ERROR:|ERROR:).*$') {
        Stop-Bootstrap "The finalized child engine log contains an engine/script error."
    }

    $validationEngineLog = Join-Path `
        $script:SessionRoot `
        "bundle_validation.engine.log"
    $validationTranscript = Join-Path `
        $script:SessionRoot `
        "bundle_validation.transcript.log"
    $validationInvocation = Invoke-CapturedProcess `
        -Label "REQUIRED_PUBLICATION_VALIDATION" `
        -FilePath $godotPath `
        -ArgumentList @(
            "--headless",
            "--path",
            $script:RepoRoot,
            "--log-file",
            $validationEngineLog,
            "--script",
            "res://scripts/lab/validate_bundle_cli.gd",
            "--",
            "--bundle",
            $bundlePath,
            "--require-attestation"
        ) `
        -TranscriptPath $validationTranscript `
        -TimeoutSeconds $StepTimeoutSeconds
    Assert-NoGodotErrors `
        -Invocation $validationInvocation `
        -EngineLogPath $validationEngineLog
    if ($validationInvocation.ExitCode -ne 0) {
        Stop-Bootstrap (
            "Required detached publication validation returned exit " +
            "$($validationInvocation.ExitCode)."
        )
    }
    $validationResultJson = Get-SingleMarkerValue `
        -Lines $validationInvocation.Lines `
        -Pattern '^BUNDLE_VALIDATION result=(\{.+\})\s*$' `
        -Label "Required bundle-validation result"
    try {
        $validationResult = $validationResultJson |
            ConvertFrom-Json -ErrorAction Stop
    } catch {
        Stop-Bootstrap "Required bundle-validation result is invalid JSON."
    }
    if (
        $validationResult.ok -ne $true -or
        $validationResult.can_finalize -ne $true -or
        $validationResult.stats.publication_attestation.ok -ne $true -or
        $validationResult.stats.publication_attestation.trust_mode -ne
            "production" -or
        $validationResult.stats.publication_attestation.key_id -ne
            $publicationKeyId -or
        -not (Get-NormalizedFullPath -Path (
            [string]$validationResult.stats.publication_attestation.receipt_path
        )).Equals(
            $publicationReceiptPath,
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {
        Stop-Bootstrap (
            "Independent bundle validation did not confirm the exact " +
            "production publication receipt."
        )
    }

    $replayEngineLog = Join-Path $script:SessionRoot "l0_4_replay.engine.log"
    $replayTranscript = Join-Path $script:SessionRoot "l0_4_replay.transcript.log"
    $replayInvocation = Invoke-CapturedProcess `
        -Label "TRACE_ONLY_REPLAY" `
        -FilePath $godotPath `
        -ArgumentList @(
            "--headless",
            "--path",
            $script:RepoRoot,
            "--log-file",
            $replayEngineLog,
            "--script",
            "res://scripts/lab/run_lab.gd",
            "--",
            "--experiment-spec",
            $l04ReplaySpec,
            "--replay-bundle",
            $bundlePath
        ) `
        -TranscriptPath $replayTranscript `
        -TimeoutSeconds $StepTimeoutSeconds
    Assert-NoGodotErrors `
        -Invocation $replayInvocation `
        -EngineLogPath $replayEngineLog
    if ($replayInvocation.ExitCode -ne 0) {
        Stop-Bootstrap "Trace-only replay returned exit $($replayInvocation.ExitCode)."
    }
    $replayPattern = (
        '^LAB replay=pass simulation_steps=0 run_id=' +
        [regex]::Escape([string]$bundle.Manifest.run_id) +
        ' frames=(\d+) events=(\d+)\s*$'
    )
    $replayMatcher = [regex]::new($replayPattern)
    $replayMatches = @(
        foreach ($line in $replayInvocation.Lines) {
            $match = $replayMatcher.Match($line)
            if ($match.Success) {
                $match
            }
        }
    )
    if ($replayMatches.Count -ne 1) {
        Stop-Bootstrap (
            "Trace replay did not emit exactly one matching " +
            "simulation_steps=0 completion marker."
        )
    }
    $replayFrames = [int]$replayMatches[0].Groups[1].Value
    $replayEvents = [int]$replayMatches[0].Groups[2].Value
    if ($replayFrames -ne [int]$bundle.Summary.frame_count) {
        Stop-Bootstrap "Replay frame count differs from the sealed run summary."
    }

    $knowledgeRecorded = $false
    $knowledgeEntryPath = $null
    $knowledgeEntryId = $null
    if ($null -ne $draft) {
        if (
            $bundle.Manifest.dirty_worktree -ne $true -or
            $bundle.Summary.promotion -ne "not_evaluated"
        ) {
            Stop-Bootstrap (
                "This operator only admits development_observation drafts; " +
                "it will not downgrade promotion-grade evidence."
            )
        }
        $outputName = $KnowledgeOutputName
        if ([string]::IsNullOrWhiteSpace($outputName)) {
            $draftStem = [System.IO.Path]::GetFileNameWithoutExtension(
                $draft.AbsolutePath
            )
            $safeStem = [regex]::Replace(
                $draftStem,
                '[^A-Za-z0-9._-]',
                '_'
            ).Trim(".", "-", "_")
            if ([string]::IsNullOrWhiteSpace($safeStem)) {
                $safeStem = "l0_development_observation"
            }
            $outputName = "$safeStem.$($bundle.Manifest.run_id).json"
        }
        Assert-FlatKnowledgeOutputName -Name $outputName
        $knowledgeCatalogPath = Join-Path `
            $script:RepoRoot `
            "data\lab\knowledge\entries"
        $knowledgeEntryPath = Join-Path $knowledgeCatalogPath $outputName
        if (Test-Path -LiteralPath $knowledgeEntryPath) {
            Stop-Bootstrap (
                "Knowledge output already exists; append-only admission will " +
                "not overwrite it: $knowledgeEntryPath"
            )
        }
        $knowledgeOutputGodot = (
            "res://data/lab/knowledge/entries/" + $outputName
        )
        $admissionEngineLog = Join-Path `
            $script:SessionRoot `
            "knowledge_admission.engine.log"
        $admissionTranscript = Join-Path `
            $script:SessionRoot `
            "knowledge_admission.transcript.log"
        $admissionInvocation = Invoke-CapturedProcess `
            -Label "DEVELOPMENT_KNOWLEDGE_ADMISSION" `
            -FilePath $godotPath `
            -ArgumentList @(
                "--headless",
                "--path",
                $script:RepoRoot,
                "--log-file",
                $admissionEngineLog,
                "--script",
                "res://scripts/lab/admit_knowledge.gd",
                "--",
                "--bundle",
                $bundlePath,
                "--draft",
                $draft.GodotPath,
                "--output",
                $knowledgeOutputGodot,
                "--status",
                "development_observation"
            ) `
            -TranscriptPath $admissionTranscript `
            -TimeoutSeconds $StepTimeoutSeconds
        Assert-NoGodotErrors `
            -Invocation $admissionInvocation `
            -EngineLogPath $admissionEngineLog
        if ($admissionInvocation.ExitCode -ne 0) {
            Stop-Bootstrap (
                "Development knowledge admission returned exit " +
                "$($admissionInvocation.ExitCode)."
            )
        }
        $admissionMatcher = [regex]::new(
            '^KNOWLEDGE admission=recorded status=development_observation ' +
            'entry_id=([A-Za-z][A-Za-z0-9._-]{0,159})\s*$'
        )
        $admissionMatches = @(
            foreach ($line in $admissionInvocation.Lines) {
                $match = $admissionMatcher.Match($line)
                if ($match.Success) {
                    $match
                }
            }
        )
        if ($admissionMatches.Count -ne 1) {
            Stop-Bootstrap "Knowledge CLI did not confirm one development admission."
        }
        $knowledgeEntryId = $admissionMatches[0].Groups[1].Value
        if (-not (Test-Path -LiteralPath $knowledgeEntryPath -PathType Leaf)) {
            Stop-Bootstrap "Knowledge CLI reported success but created no entry."
        }
        $pathMatcher = [regex]::new(
            '^KNOWLEDGE path=(.+) sha256=(sha256:[a-f0-9]{64})\s*$'
        )
        $pathMatches = @(
            foreach ($line in $admissionInvocation.Lines) {
                $match = $pathMatcher.Match($line)
                if ($match.Success) {
                    $match
                }
            }
        )
        if ($pathMatches.Count -ne 1) {
            Stop-Bootstrap "Knowledge CLI did not emit one sealed output-path marker."
        }
        $receiptPath = Get-NormalizedFullPath `
            -Path $pathMatches[0].Groups[1].Value
        if (-not $receiptPath.Equals(
            (Get-NormalizedFullPath -Path $knowledgeEntryPath),
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            Stop-Bootstrap "Knowledge CLI receipt names an unexpected output path."
        }
        $actualEntryHash = "sha256:$(
            (Get-FileHash -LiteralPath $knowledgeEntryPath -Algorithm SHA256).Hash.ToLowerInvariant()
        )"
        if ($pathMatches[0].Groups[2].Value -ne $actualEntryHash) {
            Stop-Bootstrap "Knowledge entry hash differs from the CLI receipt."
        }
        $entry = Read-JsonObject `
            -Path $knowledgeEntryPath `
            -Label "Admitted knowledge entry"
        if (
            $entry.schema -ne "sporespore.lab.knowledge_entry.v1" -or
            $entry.entry_id -ne $knowledgeEntryId -or
            $entry.claim_status -ne "development_observation" -or
            $entry.evidence.bundle_can_promote -ne $false -or
            $entry.evidence.run_id -ne $bundle.Manifest.run_id -or
            $entry.evidence.experiment_id -ne $expectedExperimentId -or
            $entry.evidence.promotion -ne "not_evaluated"
        ) {
            Stop-Bootstrap "Admitted knowledge entry does not match the development bundle."
        }
        $knowledgeRecorded = $true
    }

    $bootstrapReport = [ordered]@{
        schema = "sporespore.lab.operator_bootstrap.v1"
        status = "pass"
        mode = "development_diagnostic"
        certification = $false
        scope = "BR1_L0_DEVELOPMENT_CHECKPOINT"
        claim_boundary = "No standing, bracing, recovery, or walking capability is established by this bootstrap."
        generated_utc = (Get-Date).ToUniversalTime().ToString("o")
        repository = $script:RepoRoot
        godot = $godotPath
        session_root = $script:SessionRoot
        timeout_policy = [ordered]@{
            per_test_seconds = $TestTimeoutSeconds
            lab_suite_seconds = $LabSuiteTimeoutSeconds
            canonical_step_seconds = $StepTimeoutSeconds
            process_tree_kill_on_timeout = $true
        }
        process_runner_self_test = [ordered]@{
            pass = $true
            transcript_path = $processSelfTestTranscript
            scratch_root = $processSelfTestScratch
        }
        publication_trust = [ordered]@{
            initialized = $true
            algorithm = "hmac-sha256"
            key_id = $publicationKeyId
            trust_root = [string]$attestationState.trust_root
            active_key_pointer =
                [string]$attestationState.active_key_pointer
            receipts_directory =
                [string]$attestationState.receipts_directory
            initializer_transcript = $attestationInitializeTranscript
        }
        tests = [ordered]@{
            report_path = $testReportPath
            total = [int]$testReport.total
            passed = [int]$testReport.passed
            failed = [int]$testReport.failed
            transcript_path = $testTranscript
        }
        canonical_l0_0 = [ordered]@{
            launcher_exit_code = $launchInvocation.ExitCode
            run_id = $bundle.Manifest.run_id
            bundle_path = $bundlePath
            manifest_status = $bundle.Manifest.status
            evidence_validity = $bundle.Summary.evidence_validity
            hypothesis_result = $bundle.Summary.hypothesis_result
            physical_gate_pass = $bundle.Summary.gate_results.physical.pass
            configuration_gate_pass =
                $bundle.Summary.gate_results.configuration.pass
            source_state_gate_pass =
                $bundle.Summary.gate_results.source_state.pass
            promotion = $bundle.Summary.promotion
            dirty_worktree = $bundle.Manifest.dirty_worktree
            parent_engine_log = $launchEngineLog
            parent_transcript = $launchTranscript
            child_engine_log = $bundleEngineLog
            publication_receipt_path = $publicationReceiptPath
            publication_receipt_sha256 =
                [string]$validationResult.stats.publication_attestation.receipt_sha256
        }
        required_bundle_validation = [ordered]@{
            pass = $true
            can_finalize = [bool]$validationResult.can_finalize
            can_promote = [bool]$validationResult.can_promote
            attestation_trust_mode =
                [string]$validationResult.stats.publication_attestation.trust_mode
            engine_log = $validationEngineLog
            transcript = $validationTranscript
        }
        replay = [ordered]@{
            pass = $true
            simulation_steps = 0
            frames = $replayFrames
            events = $replayEvents
            engine_log = $replayEngineLog
            transcript = $replayTranscript
        }
        knowledge_admission = [ordered]@{
            requested = ($null -ne $draft)
            recorded = $knowledgeRecorded
            claim_status = if ($knowledgeRecorded) {
                "development_observation"
            } else {
                $null
            }
            entry_id = $knowledgeEntryId
            entry_path = $knowledgeEntryPath
        }
    }
    $bootstrapReport |
        ConvertTo-Json -Depth 10 |
        Set-Content -LiteralPath $script:BootstrapReportPath -Encoding utf8

    Write-Host (
        "BOOTSTRAP diagnostic=pass certification=false " +
        "scope=BR1_L0_DEVELOPMENT_CHECKPOINT"
    )
    Write-Host (
        "BOOTSTRAP claim_boundary=" +
        "no_standing_bracing_recovery_or_walking_capability_established"
    )
    Write-Host "BOOTSTRAP tests=$($testReport.passed)/$($testReport.total)"
    Write-Host "BOOTSTRAP bundle=$bundlePath"
    Write-Host (
        "BOOTSTRAP replay=pass simulation_steps=0 " +
        "frames=$replayFrames events=$replayEvents"
    )
    if ($knowledgeRecorded) {
        Write-Host (
            "BOOTSTRAP knowledge=development_observation " +
            "entry=$knowledgeEntryPath"
        )
    } else {
        Write-Host "BOOTSTRAP knowledge=not_requested"
    }
    Write-Host "BOOTSTRAP report=$script:BootstrapReportPath"
    exit 0
} catch {
    $failureMessage = $_.Exception.Message
    $failureReportPath = $null
    if (
        $null -ne $script:SessionRoot -and
        (Test-Path -LiteralPath $script:SessionRoot -PathType Container)
    ) {
        $failureReportPath = Join-Path `
            $script:SessionRoot `
            "bootstrap_failure.json"
        try {
            [ordered]@{
                schema = "sporespore.lab.operator_bootstrap_failure.v1"
                status = "failed"
                mode = "development_diagnostic"
                certification = $false
                scope = "BR1_L0_DEVELOPMENT_CHECKPOINT"
                claim_boundary = "No standing, bracing, recovery, or walking capability is established."
                generated_utc = (Get-Date).ToUniversalTime().ToString("o")
                message = $failureMessage
                session_root = $script:SessionRoot
            } |
                ConvertTo-Json -Depth 5 |
                Set-Content -LiteralPath $failureReportPath -Encoding utf8
        } catch {
            $failureReportPath = $null
        }
    }
    [Console]::Error.WriteLine(
        "BOOTSTRAP diagnostic=failed certification=false message=$failureMessage"
    )
    [Console]::Error.WriteLine(
        "BOOTSTRAP claim_boundary=" +
        "no_standing_bracing_recovery_or_walking_capability_established"
    )
    if ($null -ne $failureReportPath) {
        [Console]::Error.WriteLine("BOOTSTRAP failure_report=$failureReportPath")
    }
    exit 1
}

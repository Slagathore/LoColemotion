#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [ValidateSet("G2-GS1", "G2-GS2", "G2-GS3")]
    [string]$Campaign = "G2-GS1",
    [switch]$HeldOutValidation,
    [ValidateRange(1, 3)]
    [int]$HeldOutRepetition = 1,
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_br14a_uniform_scale_probe"
    ),
    [ValidateRange(1, 1800)]
    [int]$TestTimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"
$selectionScales = switch ($Campaign) {
    "G2-GS2" { @(0.900, 0.950, 1.000, 1.050, 1.075) }
    "G2-GS3" { @(1.000, 1.100, 1.150) }
    default { @(0.900, 0.950, 1.000, 1.050, 1.100) }
}
$heldOutScales = switch ($Campaign) {
    "G2-GS2" { @(0.925, 0.975, 1.025) }
    "G2-GS3" { @(1.050, 1.125) }
    default { @(0.925, 0.975, 1.025, 1.075) }
}
$expectedAssertionsPerCell = 22
$campaignRole = if ($HeldOutValidation) { "heldout" } else { "selection" }
$repetition = if ($HeldOutValidation) { $HeldOutRepetition } else { 0 }
$campaignId = if ($HeldOutValidation) {
    "$Campaign-HELDOUT-R$HeldOutRepetition"
} else {
    "$Campaign-SELECTION"
}
$scales = if ($HeldOutValidation) {
    $heldOutScales
} else {
    $selectionScales
}

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$godotPath = [System.IO.Path]::GetFullPath($Godot)
$processRunner = Join-Path $PSScriptRoot "process_runner.ps1"
$testRelativePath = (
    "tests\" +
    "test_experimental_br14a_8_physical_wave_gait_uniform_scale_probe.gd"
)
$testUidRelativePath = "$testRelativePath.uid"
$runnerRelativePath = "scripts\run_br14a_uniform_scale_probe.ps1"
$preregistrationRelativePath = (
    "docs\BR14A_QUADRUPED_GENERALIZATION_BOOTSTRAP.md"
)
$sourceRelativePaths = @(
    $preregistrationRelativePath,
    "scripts\lab\gait\physical_wave_gait_quadruped.gd",
    "scripts\lab\gait\physical_quadruped_fixture_spec.gd",
    "scripts\lab\gait\physical_gait_clock_spec.gd",
    "scripts\lab\mechanics\semantic_contact_rigid_body.gd",
    "scripts\lab\canonical_json.gd",
    "scripts\lab\finite_sanitizer.gd",
    "scripts\process_runner.ps1",
    "scripts\process_runner_containment_host.ps1",
    $testRelativePath,
    $testUidRelativePath,
    $runnerRelativePath
)

if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable not found: $godotPath"
}
if (-not (Test-Path -LiteralPath $processRunner -PathType Leaf)) {
    throw "Process runner not found: $processRunner"
}
. $processRunner
foreach ($relativePath in $sourceRelativePaths) {
    $sourcePath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Required source file not found: $sourcePath"
    }
}

$suiteMutexName = "Local\SporeSpore.RunLabTests.Serial.v1"
$suiteMutex = [System.Threading.Mutex]::new($false, $suiteMutexName)
$suiteMutexAcquired = $false
$suiteMutexWasAbandoned = $false

try {
    try {
        $suiteMutexAcquired = $suiteMutex.WaitOne(0)
    } catch [System.Threading.AbandonedMutexException] {
        $suiteMutexAcquired = $true
        $suiteMutexWasAbandoned = $true
    }
    if (-not $suiteMutexAcquired) {
        throw (
            "Another SporeSpore lab-test harness owns the suite mutex " +
            "'$suiteMutexName'. Refusing overlapping physics execution."
        )
    }

    $runStamp = Get-Date -Format "yyyyMMddTHHmmssfff"
    $campaignRoot = Join-Path (
        [System.IO.Path]::GetFullPath($LogRoot)
    ) $runStamp
    [void][System.IO.Directory]::CreateDirectory($campaignRoot)
    $sourceSnapshotRoot = Join-Path $campaignRoot "_source_snapshot"
    [void][System.IO.Directory]::CreateDirectory($sourceSnapshotRoot)

    Push-Location $repoRoot
    try {
        $sourceCommit = (& git rev-parse HEAD).Trim()
        if (
            $LASTEXITCODE -ne 0 -or
            [string]::IsNullOrWhiteSpace($sourceCommit)
        ) {
            throw "Unable to resolve the source commit."
        }
        $scopedStatus = @(
            & git status --porcelain=v1 -- @sourceRelativePaths
        )
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to inspect scoped source status."
        }
    } finally {
        Pop-Location
    }

    $sourceHashes = [ordered]@{}
    foreach ($relativePath in $sourceRelativePaths) {
        $sourcePath = Join-Path $repoRoot $relativePath
        $normalizedRelativePath = $relativePath.Replace("\", "/")
        $sourceHash = Get-FileHash `
            -LiteralPath $sourcePath `
            -Algorithm SHA256
        $sourceDigest = (
            "sha256:" + $sourceHash.Hash.ToLowerInvariant()
        )
        $sourceHashes[$normalizedRelativePath] = $sourceDigest
        $snapshotPath = Join-Path $sourceSnapshotRoot $relativePath
        [void][System.IO.Directory]::CreateDirectory(
            (Split-Path -Parent $snapshotPath)
        )
        Copy-Item `
            -LiteralPath $sourcePath `
            -Destination $snapshotPath `
            -Force
        $snapshotHash = Get-FileHash `
            -LiteralPath $snapshotPath `
            -Algorithm SHA256
        $snapshotDigest = (
            "sha256:" + $snapshotHash.Hash.ToLowerInvariant()
        )
        if ($snapshotDigest -ne $sourceDigest) {
            throw (
                "Source changed while creating immutable snapshot: " +
                $relativePath
            )
        }
    }
    $godotHash = Get-FileHash `
        -LiteralPath $godotPath `
        -Algorithm SHA256

    $projectText = @'
; Isolated SporeSpore BR14A.8 G2 uniform-scale probe.

config_version=5

[application]

config/name="sporespore-br14a-uniform-scale-probe"
config/features=PackedStringArray("4.7", "Forward Plus")

[debug]

gdscript/warnings/shadowed_global_identifier=0

[physics]

3d/physics_engine="Jolt Physics"
jolt_physics_3d/simulation/velocity_steps=20
jolt_physics_3d/simulation/position_steps=6
'@

    $results = @()
    foreach ($scale in $scales) {
        $scaleText = $scale.ToString(
            "0.000",
            [System.Globalization.CultureInfo]::InvariantCulture
        )
        $cellId = "scale-" + $scaleText.Replace(".", "p")
        $runRoot = Join-Path $campaignRoot $cellId
        [void][System.IO.Directory]::CreateDirectory($runRoot)
        [System.IO.File]::WriteAllText(
            (Join-Path $runRoot "project.godot"),
            $projectText,
            [System.Text.UTF8Encoding]::new($false)
        )
        foreach ($relativePath in $sourceRelativePaths) {
            $destination = Join-Path $runRoot $relativePath
            [void][System.IO.Directory]::CreateDirectory(
                (Split-Path -Parent $destination)
            )
            Copy-Item `
                -LiteralPath (Join-Path $sourceSnapshotRoot $relativePath) `
                -Destination $destination `
                -Force
        }
        $appData = Join-Path $runRoot "worker\appdata"
        $localAppData = Join-Path $runRoot "worker\localappdata"
        [void][System.IO.Directory]::CreateDirectory($appData)
        [void][System.IO.Directory]::CreateDirectory($localAppData)
        $transcriptPath = Join-Path $runRoot "transcript.log"
        $engineLogPath = Join-Path $runRoot "godot.log"
        $previousAppData = $env:APPDATA
        $previousLocalAppData = $env:LOCALAPPDATA
        try {
            $env:APPDATA = $appData
            $env:LOCALAPPDATA = $localAppData
            $invocation = Invoke-ProcessWithTimeout `
                -FilePath $godotPath `
                -ArgumentList @(
                    "--headless",
                    "--path",
                    $runRoot,
                    "--script",
                    "res://$($testRelativePath.Replace('\', '/'))",
                    "--log-file",
                    $engineLogPath,
                    "--",
                    $scaleText,
                    $Campaign,
                    $campaignRole,
                    $repetition.ToString(
                        [System.Globalization.CultureInfo]::InvariantCulture
                    )
                ) `
                -TimeoutSeconds $TestTimeoutSeconds `
                -TranscriptPath $transcriptPath
        } finally {
            $env:APPDATA = $previousAppData
            $env:LOCALAPPDATA = $previousLocalAppData
        }

        $outputText = @($invocation.Lines) -join [Environment]::NewLine
        $engineLogExists = Test-Path `
            -LiteralPath $engineLogPath `
            -PathType Leaf
        $engineLogText = if ($engineLogExists) {
            Get-Content -LiteralPath $engineLogPath -Raw
        } else {
            ""
        }
        $footerMatches = [regex]::Matches(
            $outputText,
            '(?m)^===\s+(\d+)\s+passed,\s+(\d+)\s+failed\s+===\s*$'
        )
        $assertionsPassed = if ($footerMatches.Count -eq 1) {
            [int]$footerMatches[0].Groups[1].Value
        } else {
            $null
        }
        $assertionsFailed = if ($footerMatches.Count -eq 1) {
            [int]$footerMatches[0].Groups[2].Value
        } else {
            $null
        }
        $engineErrors = @(
            [regex]::Matches(
                $outputText + [Environment]::NewLine + $engineLogText,
                '(?im)^\s*(?:SCRIPT ERROR:|ERROR:).*$'
            ) |
                ForEach-Object { $_.Value.Trim() } |
                Sort-Object -Unique
        )
        $resultMatches = [regex]::Matches(
            $outputText,
            '(?m)^UNIFORM_SCALE_RESULT .*$'
        )
        $resultLine = if ($resultMatches.Count -eq 1) {
            $resultMatches[0].Value
        } else {
            ""
        }
        $scaleMatch = [regex]::Match(
            $resultLine,
            '\bscale=([-+0-9.eE]+)\b'
        )
        $campaignMatch = [regex]::Match(
            $resultLine,
            '\bcampaign=(G2-GS[123])\b'
        )
        $roleMatch = [regex]::Match(
            $resultLine,
            '\brole=([a-z0-9_]+)\b'
        )
        $repetitionMatch = [regex]::Match(
            $resultLine,
            '\brepetition=(\d+)\b'
        )
        $walkingMatch = [regex]::Match(
            $resultLine,
            '\bwalking=(true|false)\b'
        )
        $policyMatch = [regex]::Match(
            $resultLine,
            '\bpolicy_digest=(sha256:[0-9a-f]{64})\b'
        )
        $clockMatch = [regex]::Match(
            $resultLine,
            '\bclock_digest=(sha256:[0-9a-f]{64})\b'
        )
        $fixtureMatch = [regex]::Match(
            $resultLine,
            '\bfixture_digest=(sha256:[0-9a-f]{64})\b'
        )
        $controllerMatch = [regex]::Match(
            $resultLine,
            '\bcontroller_digest=(sha256:[0-9a-f]{64})\b'
        )
        $thresholdMatch = [regex]::Match(
            $resultLine,
            '\bthreshold_digest=(sha256:[0-9a-f]{64})\b'
        )
        $evidenceMatch = [regex]::Match(
            $resultLine,
            '\bevidence=\(([-+0-9.eE]+),([-+0-9.eE]+),([-+0-9.eE]+)\)'
        )
        $finalMatch = [regex]::Match(
            $resultLine,
            '\bfinal=\(([-+0-9.eE]+),([-+0-9.eE]+),([-+0-9.eE]+)\)'
        )
        $anchorMatch = [regex]::Match(
            $resultLine,
            '\banchor=([-+0-9.eE]+)\b'
        )
        $hingeMatch = [regex]::Match(
            $resultLine,
            '\bhinge=([-+0-9.eE]+)\b'
        )
        $heightMatch = [regex]::Match(
            $resultLine,
            '\bheight=([-+0-9.eE]+)\b'
        )

        $receiptComplete = (
            $scaleMatch.Success -and
            $campaignMatch.Success -and
            $roleMatch.Success -and
            $repetitionMatch.Success -and
            $walkingMatch.Success -and
            $policyMatch.Success -and
            $clockMatch.Success -and
            $fixtureMatch.Success -and
            $controllerMatch.Success -and
            $thresholdMatch.Success -and
            $evidenceMatch.Success -and
            $finalMatch.Success -and
            $anchorMatch.Success -and
            $hingeMatch.Success -and
            $heightMatch.Success
        )
        $realizedScale = if ($scaleMatch.Success) {
            [double]::Parse(
                $scaleMatch.Groups[1].Value,
                [System.Globalization.CultureInfo]::InvariantCulture
            )
        } else {
            [double]::NaN
        }
        $walking = (
            $walkingMatch.Success -and
            $walkingMatch.Groups[1].Value -eq "true"
        )
        $harnessPassed = (
            -not $invocation.TimedOut -and
            $invocation.ExitCode -eq 0 -and
            $invocation.ContainmentTreeClosed -and
            -not $invocation.KilledProcessTree -and
            $footerMatches.Count -eq 1 -and
            $assertionsPassed -eq $expectedAssertionsPerCell -and
            $assertionsFailed -eq 0 -and
            $engineErrors.Count -eq 0 -and
            $resultMatches.Count -eq 1 -and
            $receiptComplete -and
            [Math]::Abs($realizedScale - $scale) -le 1.0e-12 -and
            $campaignMatch.Groups[1].Value -eq $Campaign -and
            $roleMatch.Groups[1].Value -eq $campaignRole -and
            [int]$repetitionMatch.Groups[1].Value -eq $repetition
        )

        $transcriptSha256 = if (
            Test-Path -LiteralPath $transcriptPath -PathType Leaf
        ) {
            "sha256:" + (
                Get-FileHash `
                    -LiteralPath $transcriptPath `
                    -Algorithm SHA256
            ).Hash.ToLowerInvariant()
        } else {
            ""
        }
        $engineLogSha256 = if ($engineLogExists) {
            "sha256:" + (
                Get-FileHash `
                    -LiteralPath $engineLogPath `
                    -Algorithm SHA256
            ).Hash.ToLowerInvariant()
        } else {
            ""
        }
        $resultRecord = [ordered]@{
            uniform_scale = $scale
            campaign_generation = $Campaign
            campaign_role = $campaignRole
            held_out_repetition = $repetition
            harness_passed = $harnessPassed
            walking_observed = $walking
            timed_out = $invocation.TimedOut
            process_exit_code = $invocation.ExitCode
            killed_process_tree = $invocation.KilledProcessTree
            containment_tree_closed = $invocation.ContainmentTreeClosed
            assertions_passed = $assertionsPassed
            assertions_failed = $assertionsFailed
            engine_errors = $engineErrors
            policy_sha256 = if ($policyMatch.Success) {
                $policyMatch.Groups[1].Value
            } else { "" }
            fixture_spec_sha256 = if ($fixtureMatch.Success) {
                $fixtureMatch.Groups[1].Value
            } else { "" }
            controller_configuration_sha256 = if (
                $controllerMatch.Success
            ) {
                $controllerMatch.Groups[1].Value
            } else { "" }
            evidence_threshold_sha256 = if ($thresholdMatch.Success) {
                $thresholdMatch.Groups[1].Value
            } else { "" }
            evidence_forward_m = if ($evidenceMatch.Success) {
                [double]::Parse(
                    $evidenceMatch.Groups[1].Value,
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
            } else { [double]::NaN }
            final_forward_m = if ($finalMatch.Success) {
                [double]::Parse(
                    $finalMatch.Groups[1].Value,
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
            } else { [double]::NaN }
            final_lateral_m = if ($finalMatch.Success) {
                [double]::Parse(
                    $finalMatch.Groups[3].Value,
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
            } else { [double]::NaN }
            maximum_anchor_error_m = if ($anchorMatch.Success) {
                [double]::Parse(
                    $anchorMatch.Groups[1].Value,
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
            } else { [double]::NaN }
            maximum_hinge_axis_error_rad = if ($hingeMatch.Success) {
                [double]::Parse(
                    $hingeMatch.Groups[1].Value,
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
            } else { [double]::NaN }
            minimum_torso_height_m = if ($heightMatch.Success) {
                [double]::Parse(
                    $heightMatch.Groups[1].Value,
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
            } else { [double]::NaN }
            result_receipt = $resultLine
            transcript_sha256 = $transcriptSha256
            engine_log_sha256 = $engineLogSha256
            run_root = $runRoot
        }
        if ($Campaign -eq "G2-GS3") {
            $resultRecord.gait_clock_sha256 = $clockMatch.Groups[1].Value
        }
        $results += $resultRecord
        Write-Output (
            "scale=$scaleText harness=$harnessPassed " +
            "walking=$walking assertions=$assertionsPassed/" +
            "$assertionsFailed errors=$($engineErrors.Count)"
        )
    }

    $policyDigests = @(
        $results |
            ForEach-Object { [string]$_.policy_sha256 } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
    $fixtureDigests = @(
        $results |
            ForEach-Object { [string]$_.fixture_spec_sha256 } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
    $clockDigests = @(
        $results |
            ForEach-Object { [string]$_.gait_clock_sha256 } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
    $clockReceiptSetValid = (
        $Campaign -ne "G2-GS3" -or
        $clockDigests.Count -eq $scales.Count
    )
    $allCellsPassed = (
        $scopedStatus.Count -eq 0 -and
        $results.Count -eq $scales.Count -and
        @(
            $results |
                Where-Object {
                    -not $_.harness_passed -or
                    -not $_.walking_observed
                }
        ).Count -eq 0 -and
        $policyDigests.Count -eq 1 -and
        $fixtureDigests.Count -eq $scales.Count -and
        $clockReceiptSetValid
    )
    $totalAssertionsPassed = (
        $results |
            ForEach-Object { [int]$_.assertions_passed } |
            Measure-Object -Sum
    ).Sum
    $totalAssertionsFailed = (
        $results |
            ForEach-Object { [int]$_.assertions_failed } |
            Measure-Object -Sum
    ).Sum
    $report = [ordered]@{
        schema_version = if ($Campaign -eq "G2-GS3") {
            "sporespore_br14a_uniform_scale_probe_report_v3"
        } else {
            "sporespore_br14a_uniform_scale_probe_report_v2"
        }
        generated_utc = (Get-Date).ToUniversalTime().ToString("o")
        source_commit = $sourceCommit
        source_scope_clean = $scopedStatus.Count -eq 0
        scoped_source_tree_dirty = $scopedStatus.Count -gt 0
        scoped_source_status = $scopedStatus
        source_sha256 = $sourceHashes
        immutable_source_snapshot = $true
        source_snapshot_root = $sourceSnapshotRoot
        godot_path = $godotPath
        godot_sha256 = (
            "sha256:" + $godotHash.Hash.ToLowerInvariant()
        )
        physics_project_settings = [ordered]@{
            engine = "Jolt Physics"
            physics_hz = 120
            velocity_steps = 20
            position_steps = 6
        }
        suite_mutex_name = $suiteMutexName
        suite_mutex_acquired = $suiteMutexAcquired
        suite_mutex_was_abandoned = $suiteMutexWasAbandoned
        test_program = $testRelativePath.Replace("\", "/")
        campaign_id = $campaignId
        campaign_generation = $Campaign
        campaign_role = $campaignRole
        held_out_repetition = $repetition
        preregistered_selection_scales = $selectionScales
        preregistered_held_out_scales = $heldOutScales
        expected_assertions_per_cell = $expectedAssertionsPerCell
        total_assertions_passed = $totalAssertionsPassed
        total_assertions_failed = $totalAssertionsFailed
        all_harnesses_passed = (
            @($results | Where-Object { -not $_.harness_passed }).Count -eq 0
        )
        all_cells_walked = (
            @($results | Where-Object { -not $_.walking_observed }).Count -eq 0
        )
        formula_policy_sha256 = if ($policyDigests.Count -eq 1) {
            $policyDigests[0]
        } else { "" }
        formula_policy_digest_consistent = $policyDigests.Count -eq 1
        fixture_digest_distinct_by_scale = (
            $fixtureDigests.Count -eq $scales.Count
        )
        selection_eligible = (
            -not $HeldOutValidation -and $allCellsPassed
        )
        held_out_repetition_passed = (
            $HeldOutValidation -and $allCellsPassed
        )
        g2_complete = $false
        morphology_generalization_established = $false
        formal_milestone_acceptance_authorized = $false
        encyclopedia_admission_authorized = $false
        automatic_creature_guidance_allowed = $false
        results = $results
    }
    if ($Campaign -eq "G2-GS3") {
        $report.dynamic_similarity_clock_digest_distinct_by_scale = (
            $clockReceiptSetValid
        )
        $report.dynamic_similarity_clock_receipts = @(
            $results |
                ForEach-Object {
                    [ordered]@{
                        uniform_scale = [double]$_.uniform_scale
                        gait_clock_sha256 = [string]$_.gait_clock_sha256
                    }
                }
        )
    }
    $reportPath = Join-Path $campaignRoot "report.json"
    $reportJson = $report | ConvertTo-Json -Depth 30
    [System.IO.File]::WriteAllText(
        $reportPath,
        $reportJson + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
    $reportHash = Get-FileHash `
        -LiteralPath $reportPath `
        -Algorithm SHA256
    Write-Output "REPORT=$reportPath"
    Write-Output (
        "REPORT_SHA256=sha256:" +
        $reportHash.Hash.ToLowerInvariant()
    )
    Write-Output (
        "CAMPAIGN=$campaignId PASSED=$allCellsPassed " +
        "ASSERTIONS=$($report.total_assertions_passed)/" +
        "$($report.total_assertions_failed)"
    )
    if (-not $allCellsPassed) {
        exit 1
    }
    exit 0
} finally {
    if ($suiteMutexAcquired) {
        $suiteMutex.ReleaseMutex()
    }
    $suiteMutex.Dispose()
}

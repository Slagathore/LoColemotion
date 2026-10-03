#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        "C:\Users\Cole\CodeStuff\games\" +
        "SporeSpore_Evidence\formal-sdk-c6"
    ),
    [string]$PredecessorSelectionReport = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "formal-sdk-c6-55a7598\campaign\20260728T040930002\" +
        "selection\20260728T040931467\report.json"
    ),
    [switch]$ValidatePredecessorOnly,
    [ValidateRange(1, 1800)]
    [int]$TestTimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$phaseRunner = Join-Path $repoRoot "scripts\run_br14a_nonuniform_proportion_probe.ps1"
if (-not (Test-Path -LiteralPath $phaseRunner -PathType Leaf)) {
    throw "C6 phase runner not found: $phaseRunner"
}
$expectedPredecessorHash = (
    "sha256:" +
    "3087d75946e37730847809175c09147acddd78cff4a45fd4d47b3121a53315b3"
)
if (-not (
    Test-Path -LiteralPath $PredecessorSelectionReport -PathType Leaf
)) {
    throw "C6R predecessor report not found: $PredecessorSelectionReport"
}
$predecessorReportPath = [System.IO.Path]::GetFullPath(
    $PredecessorSelectionReport
)
$predecessorReportHash = Get-FileHash `
    -LiteralPath $predecessorReportPath `
    -Algorithm SHA256
$predecessorReportHashText = (
    "sha256:" + $predecessorReportHash.Hash.ToLowerInvariant()
)
$predecessorReport = (
    Get-Content -LiteralPath $predecessorReportPath -Raw |
        ConvertFrom-Json
)
$predecessorFailedIds = @(
    $predecessorReport.results |
        Where-Object {
            -not [bool]$_.harness_passed -or
            -not [bool]$_.walking_observed -or
            -not [bool]$_.sdk_c6_confirmed
        } |
        ForEach-Object { [string]$_.morphology_id } |
        Sort-Object
)
$predecessorSelectionRunRoot = Split-Path -Parent $predecessorReportPath
$predecessorSelectionPhaseRoot = Split-Path -Parent $predecessorSelectionRunRoot
$predecessorCampaignRoot = Split-Path -Parent $predecessorSelectionPhaseRoot
$predecessorHeldOutDirectories = @(
    Get-ChildItem -LiteralPath $predecessorCampaignRoot -Directory |
        Where-Object { $_.Name -like "heldout-*" }
)
$predecessorExact = (
    $predecessorReportHashText -eq $expectedPredecessorHash -and
    $predecessorReport.schema_version -eq
        "sporespore_sdk_godot_jolt_c6_phase_report_v1" -and
    $predecessorReport.source_commit -eq
        "55a7598d9fe0b7f9d315f19ae081f7cfc858e4bd" -and
    [bool]$predecessorReport.source_scope_clean -and
    $predecessorReport.campaign_generation -eq "G4-GQ15" -and
    $predecessorReport.campaign_role -eq "selection" -and
    [int]$predecessorReport.held_out_repetition -eq 0 -and
    @($predecessorReport.results).Count -eq 12 -and
    [int]$predecessorReport.total_assertions_passed -eq 382 -and
    [int]$predecessorReport.total_assertions_failed -eq 14 -and
    -not [bool]$predecessorReport.all_harnesses_passed -and
    -not [bool]$predecessorReport.all_cells_walked -and
    -not [bool]$predecessorReport.sdk_c6_selection_eligible -and
    -not [bool]$predecessorReport.finite_gq15_godot_jolt_sdk_c6_confirmed -and
    ($predecessorFailedIds -join "|") -eq
        "gq15_generated_s160|gq15_generated_s167" -and
    $predecessorHeldOutDirectories.Count -eq 0
)
if (-not $predecessorExact) {
    throw "C6R predecessor rejection provenance failed strict reconciliation."
}
$predecessorReceipt = [ordered]@{
    campaign_id = "SDK-GODOT-JOLT-C6-GQ15"
    source_commit = $predecessorReport.source_commit
    report_path = $predecessorReportPath
    report_sha256 = $predecessorReportHashText
    selection_rejected = $true
    assertions_passed = [int]$predecessorReport.total_assertions_passed
    assertions_failed = [int]$predecessorReport.total_assertions_failed
    failed_morphologies = $predecessorFailedIds
    held_out_directories_observed = $predecessorHeldOutDirectories.Count
    held_out_unopened = $true
}
if ($ValidatePredecessorOnly) {
    Write-Output (
        $predecessorReceipt |
            ConvertTo-Json -Depth 10 -Compress
    )
    exit 0
}
$pwsh = (Get-Command pwsh -ErrorAction Stop).Source
$campaignStamp = Get-Date -Format "yyyyMMddTHHmmssfff"
$campaignRoot = Join-Path (
    [System.IO.Path]::GetFullPath($LogRoot)
) $campaignStamp
[void][System.IO.Directory]::CreateDirectory($campaignRoot)

function Invoke-C6Phase {
    param(
        [Parameter(Mandatory)]
        [string]$PhaseName,
        [Parameter(Mandatory)]
        [string]$ExpectedRole,
        [Parameter(Mandatory)]
        [int]$ExpectedRepetition,
        [Parameter(Mandatory)]
        [int]$ExpectedWorlds,
        [Parameter(Mandatory)]
        [int]$ExpectedAssertions
    )

    $phaseLogRoot = Join-Path $campaignRoot $PhaseName
    $arguments = @(
        "-NoProfile",
        "-File",
        $phaseRunner,
        "-Godot",
        $Godot,
        "-Campaign",
        "G4-GQ15",
        "-SdkNativeAuthority",
        "-LogRoot",
        $phaseLogRoot,
        "-TestTimeoutSeconds",
        $TestTimeoutSeconds.ToString(
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    )
    if ($ExpectedRole -eq "heldout") {
        $arguments += @(
            "-HeldOutValidation",
            "-HeldOutRepetition",
            $ExpectedRepetition.ToString(
                [System.Globalization.CultureInfo]::InvariantCulture
            )
        )
    }
    $phaseOutput = @(& $pwsh @arguments 2>&1)
    $phaseExitCode = $LASTEXITCODE
    foreach ($line in $phaseOutput) {
        Write-Output $line
    }
    $reportMatches = @(
        $phaseOutput |
            ForEach-Object { [string]$_ } |
            Where-Object { $_ -match '^REPORT=(.+)$' }
    )
    if ($phaseExitCode -ne 0 -or $reportMatches.Count -ne 1) {
        throw (
            "C6 phase '$PhaseName' failed before aggregate admission: " +
            "exit=$phaseExitCode report_lines=$($reportMatches.Count)"
        )
    }
    $reportPath = (
        [regex]::Match($reportMatches[0], '^REPORT=(.+)$').Groups[1].Value
    )
    if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
        throw "C6 phase report does not exist: $reportPath"
    }
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    $phaseValid = (
        $report.schema_version -eq "sporespore_sdk_godot_jolt_c6_phase_report_v1" -and
        [bool]$report.sdk_native_authority -and
        [bool]$report.source_scope_clean -and
        [bool]$report.immutable_source_snapshot -and
        $report.campaign_generation -eq "G4-GQ15" -and
        $report.campaign_role -eq $ExpectedRole -and
        [int]$report.held_out_repetition -eq $ExpectedRepetition -and
        @($report.executed_morphologies).Count -eq $ExpectedWorlds -and
        [int]$report.expected_assertions_per_cell -eq 33 -and
        [int]$report.total_assertions_passed -eq $ExpectedAssertions -and
        [int]$report.total_assertions_failed -eq 0 -and
        [bool]$report.all_harnesses_passed -and
        [bool]$report.all_cells_walked -and
        [bool]$report.sdk_receipts_complete_and_consistent -and
        @($report.results).Count -eq $ExpectedWorlds -and
        @(
            $report.results |
                Where-Object {
                    -not [bool]$_.sdk_c6_confirmed -or
                    -not [bool]$_.harness_passed -or
                    -not [bool]$_.walking_observed
                }
        ).Count -eq 0
    )
    if ($ExpectedRole -eq "selection") {
        $phaseValid = $phaseValid -and [bool]$report.sdk_c6_selection_eligible
    } else {
        $phaseValid = (
            $phaseValid -and
            [bool]$report.sdk_c6_held_out_repetition_passed
        )
    }
    if (-not $phaseValid) {
        throw "C6 phase '$PhaseName' report failed strict reconciliation."
    }
    $reportHash = Get-FileHash -LiteralPath $reportPath -Algorithm SHA256
    return [ordered]@{
        phase_name = $PhaseName
        report_path = $reportPath
        report_sha256 = "sha256:" + $reportHash.Hash.ToLowerInvariant()
        report = $report
    }
}

# The selection phase is deliberately completed and admitted before any
# held-out process is launched.
$phases = @()
$phases += Invoke-C6Phase `
    -PhaseName "selection" `
    -ExpectedRole "selection" `
    -ExpectedRepetition 0 `
    -ExpectedWorlds 12 `
    -ExpectedAssertions 396
$phases += Invoke-C6Phase `
    -PhaseName "heldout-r1" `
    -ExpectedRole "heldout" `
    -ExpectedRepetition 1 `
    -ExpectedWorlds 8 `
    -ExpectedAssertions 264
$phases += Invoke-C6Phase `
    -PhaseName "heldout-r2" `
    -ExpectedRole "heldout" `
    -ExpectedRepetition 2 `
    -ExpectedWorlds 8 `
    -ExpectedAssertions 264
$phases += Invoke-C6Phase `
    -PhaseName "heldout-r3" `
    -ExpectedRole "heldout" `
    -ExpectedRepetition 3 `
    -ExpectedWorlds 8 `
    -ExpectedAssertions 264

$sourceCommits = @(
    $phases.report.source_commit | Sort-Object -Unique
)
$sourceHashFamilies = @(
    $phases |
        ForEach-Object {
            $_.report.source_sha256 | ConvertTo-Json -Depth 10 -Compress
        } |
        Sort-Object -Unique
)
$godotHashes = @(
    $phases.report.godot_sha256 | Sort-Object -Unique
)
$nativeBinaryHashes = @(
    $phases.report.sdk_native_binary_sha256 | Sort-Object -Unique
)
$capabilityHashes = @(
    $phases.report.sdk_adapter_capability_sha256 | Sort-Object -Unique
)
$allResults = @(
    $phases |
        ForEach-Object { $_.report.results }
)
$expectedSelectionMorphologies = @(
    157..168 | ForEach-Object { "gq15_generated_s$_" }
)
$expectedHeldOutMorphologies = @(
    1401..1408 | ForEach-Object { "gq15_generated_s$_" }
)
$cohortsExact = (
    (@($phases[0].report.executed_morphologies) -join "|") -eq (
        $expectedSelectionMorphologies -join "|"
    ) -and
    (@($phases[1].report.executed_morphologies) -join "|") -eq (
        $expectedHeldOutMorphologies -join "|"
    ) -and
    (@($phases[2].report.executed_morphologies) -join "|") -eq (
        $expectedHeldOutMorphologies -join "|"
    ) -and
    (@($phases[3].report.executed_morphologies) -join "|") -eq (
        $expectedHeldOutMorphologies -join "|"
    )
)
$executionKeys = @(
    $allResults |
        ForEach-Object {
            "$($_.campaign_role):$($_.held_out_repetition):$($_.morphology_id)"
        } |
        Sort-Object -Unique
)
$totalAssertionsPassed = (
    $phases.report |
        ForEach-Object { [int]$_.total_assertions_passed } |
        Measure-Object -Sum
).Sum
$totalAssertionsFailed = (
    $phases.report |
        ForEach-Object { [int]$_.total_assertions_failed } |
        Measure-Object -Sum
).Sum
$aggregateExact = (
    $predecessorExact -and
    $phases.Count -eq 4 -and
    $sourceCommits.Count -eq 1 -and
    $sourceHashFamilies.Count -eq 1 -and
    $godotHashes.Count -eq 1 -and
    $nativeBinaryHashes.Count -eq 1 -and
    $capabilityHashes.Count -eq 1 -and
    $cohortsExact -and
    $allResults.Count -eq 36 -and
    $executionKeys.Count -eq 36 -and
    $totalAssertionsPassed -eq 1188 -and
    $totalAssertionsFailed -eq 0
)
if (-not $aggregateExact) {
    throw "C6R aggregate reconciliation failed."
}

$aggregate = [ordered]@{
    schema_version = "sporespore_sdk_godot_jolt_c6_cohort_report_v2"
    generated_utc = (Get-Date).ToUniversalTime().ToString("o")
    source_commit = $sourceCommits[0]
    source_sha256 = $phases[0].report.source_sha256
    godot_sha256 = $godotHashes[0]
    sdk_native_binary_sha256 = $nativeBinaryHashes[0]
    sdk_adapter_capability_sha256 = $capabilityHashes[0]
    campaign_id = "SDK-GODOT-JOLT-C6R-GQ15"
    campaign_root = $campaignRoot
    predecessor_selection_report_receipt = $predecessorReceipt
    predecessor_selection_rejected = $true
    selection_reused_for_remediation = $true
    held_out_unopened_at_successor_freeze = $true
    selection_completed_before_held_out = $true
    preregistered_selection_morphologies = $expectedSelectionMorphologies
    preregistered_held_out_morphologies = $expectedHeldOutMorphologies
    exact_cohorts_reconciled = $cohortsExact
    phase_reports = @(
        $phases |
            ForEach-Object {
                [ordered]@{
                    phase_name = $_.phase_name
                    campaign_role = $_.report.campaign_role
                    held_out_repetition = $_.report.held_out_repetition
                    report_path = $_.report_path
                    report_sha256 = $_.report_sha256
                    source_snapshot_root = $_.report.source_snapshot_root
                    executed_morphologies = $_.report.executed_morphologies
                    assertions_passed = $_.report.total_assertions_passed
                    assertions_failed = $_.report.total_assertions_failed
                }
            }
    )
    total_worlds = $allResults.Count
    distinct_execution_keys = $executionKeys.Count
    total_assertions_passed = $totalAssertionsPassed
    total_assertions_failed = $totalAssertionsFailed
    finite_gq15_godot_jolt_sdk_c6_confirmed = $true
    cold_held_out_godot_jolt_sdk_c6_confirmed = $true
    engine_neutrality_established = $false
    arbitrary_quadruped_coverage_established = $false
    continuous_physical_morphology_coverage_established = $false
    environmental_robustness_established = $false
    product_sdk_complete = $false
    formal_milestone_acceptance_authorized = $false
    encyclopedia_admission_authorized = $false
    automatic_creature_guidance_allowed = $false
}
$aggregatePath = Join-Path $campaignRoot "report.json"
$aggregateJson = $aggregate | ConvertTo-Json -Depth 30
[System.IO.File]::WriteAllText(
    $aggregatePath,
    $aggregateJson + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)
$aggregateHash = Get-FileHash -LiteralPath $aggregatePath -Algorithm SHA256
Write-Output "REPORT=$aggregatePath"
Write-Output (
    "REPORT_SHA256=sha256:" +
    $aggregateHash.Hash.ToLowerInvariant()
)
Write-Output (
    "SDK_C6R_GODOT_JOLT_GQ15=true WORLDS=$($aggregate.total_worlds) " +
    "ASSERTIONS=$($aggregate.total_assertions_passed)/" +
    "$($aggregate.total_assertions_failed)"
)
exit 0

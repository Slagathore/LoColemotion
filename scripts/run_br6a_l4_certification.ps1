#requires -Version 7.5

<#
.SYNOPSIS
Runs the clean-source, promotion-grade BR6A L4 evidence campaign.

.DESCRIPTION
Executes all 3 declared programs twice in fresh Godot target processes,
retains every result, builds and signs 6 evidence capsules, reconciles each
pair, performs a complete readback, and signs the final BR6A report. This
operator never creates a milestone decision or admits knowledge.
#>

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64.exe"
    ),
    [switch]$PreflightOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$script:RepoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$script:CampaignPath = Join-Path $script:RepoRoot (
    "data\lab\campaigns\BR6A_L4_promotion_campaign_v1.json"
)
$script:CampaignSchemaPath = Join-Path $script:RepoRoot (
    "data\lab\schemas\br6a_l4_promotion_campaign_v1.schema.json"
)
$script:Br1InventoryPath = Join-Path $script:RepoRoot (
    "data\lab\campaigns\BR1_required_lab_tests_v2.json"
)
$script:RunLabTestsPath = Join-Path $PSScriptRoot "run_lab_tests.ps1"
$script:ProcessRunnerPath = Join-Path $PSScriptRoot "process_runner.ps1"
$script:BundleAttestationCli = (
    "res://scripts/lab/br6a_bundle_attestation_cli.gd"
)
$script:ReportAttestationCli = (
    "res://scripts/lab/br6a_certification_report_attestation_cli.gd"
)
$script:ExpectedGodotVersion = "4.7.stable.mono.official.5b4e0cb0f"
$script:ExpectedGodotSha256 = (
    "sha256:baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4"
)
$script:ExpectedBr1InventorySha256 = (
    "sha256:f22a43c3125d2a87c3f4b154af40d5e99a2a9dd1da35e159825e79635357605e"
)
$script:SessionRoot = $null
$script:ReportPath = $null

if (-not (Test-Path -LiteralPath $script:ProcessRunnerPath -PathType Leaf)) {
    throw "Process runner not found: $script:ProcessRunnerPath"
}
. $script:ProcessRunnerPath

function Stop-Certification {
    param([Parameter(Mandatory = $true)][string]$Message)
    throw $Message
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
    return $candidatePath.StartsWith(
        $parentPath + [System.IO.Path]::DirectorySeparatorChar,
        [System.StringComparison]::OrdinalIgnoreCase
    )
}

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Stop-Certification "Required file is missing: $Path"
    }
    $hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
    return "sha256:$($hash.Hash.ToLowerInvariant())"
}

function Get-BytesSha256 {
    param([Parameter(Mandatory = $true)][byte[]]$Bytes)
    $hash = [System.Security.Cryptography.SHA256]::HashData($Bytes)
    return "sha256:$([System.Convert]::ToHexString($hash).ToLowerInvariant())"
}

function Get-TextSha256 {
    param([Parameter(Mandatory = $true)][string]$Text)
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Text)
    return Get-BytesSha256 -Bytes $bytes
}

function Read-JsonObject {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Stop-Certification "JSON file is missing: $Path"
    }
    try {
        $value = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop |
            ConvertFrom-Json -Depth 100 -DateKind String -ErrorAction Stop
    } catch {
        Stop-Certification (
            "JSON file is invalid: $Path :: $($_.Exception.Message)"
        )
    }
    if ($null -eq $value -or $value -is [System.Array]) {
        Stop-Certification "Expected a JSON object: $Path"
    }
    return $value
}

function Write-CompactJson {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        [void][System.IO.Directory]::CreateDirectory($parent)
    }
    $json = $Value | ConvertTo-Json -Depth 100 -Compress
    [System.IO.File]::WriteAllText(
        $Path,
        $json,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Invoke-Contained {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$ArgumentList,
        [Parameter(Mandatory = $true)][string]$TranscriptPath,
        [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $invokeArguments = @{
        FilePath = $FilePath
        ArgumentList = $ArgumentList
        TimeoutSeconds = $TimeoutSeconds
        TranscriptPath = $TranscriptPath
    }
    $result = Invoke-ProcessWithTimeout @invokeArguments
    if (
        $result.TimedOut -or
        -not [string]::IsNullOrWhiteSpace($result.StartError) -or
        -not [string]::IsNullOrWhiteSpace($result.TerminationError) -or
        -not $result.ContainmentTreeClosed -or
        -not $result.ExitMarkerObserved -or
        [int]$result.ExitCode -ne 0
    ) {
        Stop-Certification (
            "$Label failed: exit=$($result.ExitCode) " +
            "timed_out=$($result.TimedOut) start=$($result.StartError) " +
            "termination=$($result.TerminationError)"
        )
    }
    return $result
}

function Invoke-GitText {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $output = & git -C $script:RepoRoot @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        Stop-Certification (
            "git $($Arguments -join ' ') failed: " +
            ($output -join [Environment]::NewLine)
        )
    }
    return (($output -join [Environment]::NewLine).Trim())
}

function Get-CleanSourceState {
    param([Parameter(Mandatory = $true)][string]$Stage)
    $dirty = Invoke-GitText -Arguments @(
        "status", "--porcelain=v1", "--untracked-files=all"
    )
    if (-not [string]::IsNullOrWhiteSpace($dirty)) {
        Stop-Certification (
            "Source is dirty at $Stage. Commit all campaign inputs first."
        )
    }
    $commit = Invoke-GitText -Arguments @("rev-parse", "HEAD")
    if ($commit -notmatch '^[a-f0-9]{40}$') {
        Stop-Certification "Git returned an invalid commit at $Stage."
    }
    return [ordered]@{commit_sha = $commit; clean = $true; stage = $Stage}
}

function Assert-SameCleanSource {
    param(
        [Parameter(Mandatory = $true)][string]$ExpectedCommit,
        [Parameter(Mandatory = $true)][string]$Stage
    )
    $state = Get-CleanSourceState -Stage $Stage
    if ([string]$state.commit_sha -cne $ExpectedCommit) {
        Stop-Certification "Source commit changed at $Stage."
    }
}

function Get-ExpectedPrograms {
    return @(
        @("BR6A_L4_0_RIGID_STRUT_RAIL_V1", "L4.0", "milestone", "test_experimental_l4_0_rigid_strut_rail.gd", 12),
        @("BR6A_L4_1_HINGED_STRUT_RAIL_V1", "L4.1", "milestone", "test_experimental_l4_1_hinged_strut_rail.gd", 12),
        @("BR6A_L4_3_RAIL_LEG_SUPPORT_V1", "L4.3", "milestone", "test_experimental_l4_3_rail_leg_support.gd", 16)
    )
}

function Assert-CampaignContract {
    param([Parameter(Mandatory = $true)]$Campaign)
    $campaignSchema = Read-JsonObject -Path $script:CampaignSchemaPath
    if (
        $Campaign.schema -cne "sporespore.lab.br6a_l4_promotion_campaign.v1" -or
        $Campaign.campaign_id -cne "BR6A_L4_PROMOTION_CAMPAIGN_V1" -or
        [int]$Campaign.campaign_version -ne 1 -or
        $Campaign.milestone_id -cne "BR6A_L4_VERTICAL_RAIL_LEG_SUPPORT" -or
        $Campaign.claim_boundary -cne (
            $campaignSchema.properties.claim_boundary.const
        ) -or
        $Campaign.process_policy.clean_committed_source -ne $true -or
        $Campaign.process_policy.fresh_godot_process_per_replicate -ne $true -or
        [int]$Campaign.process_policy.required_replicates_per_program -ne 2 -or
        $Campaign.process_policy.pid_recycle_policy -cne (
            "allowed_only_for_nonoverlapping_completed_invocations_and_recorded"
        ) -or
        [int]$Campaign.process_policy.test_timeout_seconds -ne 300 -or
        $Campaign.process_policy.complete_campaign_required -ne $true -or
        $Campaign.process_policy.cherry_pick_policy -cne (
            "forbidden_all_declared_runs_retained"
        )
    ) {
        Stop-Certification "BR6A campaign header or process policy is weakened."
    }
    if (
        $Campaign.br1_inventory_guard.sha256 -cne (
            $script:ExpectedBr1InventorySha256
        ) -or
        [int]$Campaign.br1_inventory_guard.test_count -ne 62 -or
        $Campaign.br1_inventory_guard.mutation_forbidden -ne $true
    ) {
        Stop-Certification "The BR1 inventory guard is missing or weakened."
    }
    $expected = @(Get-ExpectedPrograms)
    $programs = @($Campaign.programs)
    if ($programs.Count -ne 3) {
        Stop-Certification "BR6A campaign must contain 3 ordered programs."
    }
    $seenPrograms = @{}
    $seenTests = @{}
    for ($index = 0; $index -lt $expected.Count; $index++) {
        $row = $expected[$index]
        $program = $programs[$index]
        $testName = [System.IO.Path]::GetFileName(
            [string]$program.test_resource_path
        )
        if (
            [string]$program.program_id -cne [string]$row[0] -or
            [string]$program.cell_id -cne [string]$row[1] -or
            [string]$program.evidence_role -cne [string]$row[2] -or
            $testName -cne [string]$row[3] -or
            [int]$program.expected_assertions -ne [int]$row[4] -or
            [string]::IsNullOrWhiteSpace([string]$program.claim_scope) -or
            $seenPrograms.ContainsKey([string]$program.program_id) -or
            $seenTests.ContainsKey($testName)
        ) {
            Stop-Certification (
                "BR6A program at index $index differs from the operator."
            )
        }
        $seenPrograms[[string]$program.program_id] = $true
        $seenTests[$testName] = $true
        if (-not (Test-Path -LiteralPath (
            Join-Path $script:RepoRoot "tests\$testName"
        ) -PathType Leaf)) {
            Stop-Certification "Declared BR6A test is missing: $testName"
        }
    }
    $role = $Campaign.role_accounting
    if (
        [int]$role.milestone.programs -ne 3 -or
        [int]$role.milestone.assertions_per_replicate -ne 40 -or
        [int]$role.supplementary.programs -ne 0 -or
        [int]$role.supplementary.assertions_per_replicate -ne 0 -or
        [int]$role.integrity.programs -ne 0 -or
        [int]$role.integrity.assertions_per_replicate -ne 0 -or
        [int]$role.total.programs -ne 3 -or
        [int]$role.total.assertions_per_replicate -ne 40
    ) {
        Stop-Certification "BR6A role accounting differs from the fixed contract."
    }
}

function Get-SourceInventory {
    param(
        [Parameter(Mandatory = $true)]$Campaign,
        [Parameter(Mandatory = $true)][string]$CommitSha
    )
    $relativePaths = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    foreach ($root in @($Campaign.source_policy.inventory_roots)) {
        $relative = ([string]$root.path).Replace("/", "\")
        $absolute = Get-NormalizedFullPath -Path (
            Join-Path $script:RepoRoot $relative
        )
        if (-not (Test-PathAtOrBelow $absolute $script:RepoRoot)) {
            Stop-Certification "Source inventory root escapes repo: $relative"
        }
        if ([string]$root.kind -ceq "file") {
            if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) {
                Stop-Certification "Source inventory file missing: $relative"
            }
            [void]$relativePaths.Add(([string]$root.path).Replace("\", "/"))
            continue
        }
        if (
            [string]$root.kind -cne "tree" -or
            -not (Test-Path -LiteralPath $absolute -PathType Container)
        ) {
            Stop-Certification "Source inventory tree is invalid: $relative"
        }
        $extensions = @($root.extensions | ForEach-Object {
            ([string]$_).ToLowerInvariant()
        })
        foreach ($file in Get-ChildItem -LiteralPath $absolute -Recurse -File) {
            if ($file.Extension.ToLowerInvariant() -notin $extensions) {
                continue
            }
            $itemRelative = [System.IO.Path]::GetRelativePath(
                $script:RepoRoot,
                $file.FullName
            ).Replace("\", "/")
            [void]$relativePaths.Add($itemRelative)
        }
    }
    foreach ($program in @($Campaign.programs)) {
        [void]$relativePaths.Add(
            ([string]$program.test_resource_path).Substring(6)
        )
    }
    [string[]]$ordered = @($relativePaths)
    [Array]::Sort($ordered, [StringComparer]::Ordinal)
    $files = @()
    foreach ($relative in $ordered) {
        $absolute = Join-Path $script:RepoRoot $relative.Replace("/", "\")
        if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) {
            Stop-Certification "Source member disappeared: $relative"
        }
        $files += [ordered]@{
            path = $relative
            sha256 = Get-Sha256 -Path $absolute
            bytes = [int64](Get-Item -LiteralPath $absolute).Length
        }
    }
    return [ordered]@{
        schema = "sporespore.lab.br6a_l4_source_inventory.v1"
        commit_sha = $CommitSha
        algorithm = "sha256"
        file_count = $files.Count
        files = $files
    }
}

function Assert-SourceInventoryCurrent {
    param([Parameter(Mandatory = $true)]$Inventory)
    foreach ($entry in @($Inventory.files)) {
        $path = Join-Path $script:RepoRoot (
            ([string]$entry.path).Replace("/", "\")
        )
        if (
            -not (Test-Path -LiteralPath $path -PathType Leaf) -or
            (Get-Sha256 -Path $path) -cne [string]$entry.sha256 -or
            [int64](Get-Item -LiteralPath $path).Length -ne [int64]$entry.bytes
        ) {
            Stop-Certification "Source inventory changed: $($entry.path)"
        }
    }
}

function Assert-GodotIdentity {
    param([Parameter(Mandatory = $true)][string]$GodotPath)
    if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
        Stop-Certification "Godot executable not found: $GodotPath"
    }
    $observed = Get-Sha256 -Path $GodotPath
    if ($observed -cne $script:ExpectedGodotSha256) {
        Stop-Certification "Godot hash differs from BR6A contract: $observed"
    }
    return [ordered]@{
        executable = Get-NormalizedFullPath -Path $GodotPath
        sha256 = $observed
        version = $script:ExpectedGodotVersion
    }
}

function Get-OnlyRegexMatch {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $matches = [regex]::Matches($Text, $Pattern)
    if ($matches.Count -ne 1) {
        Stop-Certification (
            "$Label expected one marker and saw $($matches.Count)."
        )
    }
    return $matches[0]
}

function Invoke-HarnessReplicate {
    param(
        [Parameter(Mandatory = $true)]$Program,
        [Parameter(Mandatory = $true)][int]$Replicate,
        [Parameter(Mandatory = $true)][string]$GodotPath,
        [Parameter(Mandatory = $true)][string]$RawRoot
    )
    $testName = [System.IO.Path]::GetFileName(
        [string]$Program.test_resource_path
    )
    $programRoot = Join-Path $RawRoot (
        "$([string]$Program.program_id).r$Replicate"
    )
    [void][System.IO.Directory]::CreateDirectory($programRoot)
    $operatorTranscript = Join-Path (
        $programRoot
    ) "harness_operator.transcript.log"
    $pwsh = Join-Path $PSHOME "pwsh.exe"
    $arguments = @(
        "-NoLogo", "-NoProfile", "-NonInteractive",
        "-ExecutionPolicy", "Bypass",
        "-File", $script:RunLabTestsPath,
        "-Godot", $GodotPath,
        "-Pattern", $testName,
        "-LogRoot", $programRoot,
        "-TestTimeoutSeconds", "300"
    )
    $invocation = Invoke-Contained (
        $pwsh
    ) $arguments $operatorTranscript 360 (
        "$($Program.program_id) replicate $Replicate harness"
    )
    $marker = Get-OnlyRegexMatch (
        [string]$invocation.Text
    ) '(?m)^REPORT\s+(.+?)\s*$' (
        "$($Program.program_id) replicate $Replicate report"
    )
    $reportPath = Get-NormalizedFullPath -Path $marker.Groups[1].Value
    if (-not (Test-PathAtOrBelow $reportPath $programRoot)) {
        Stop-Certification "Harness report escaped its replicate root."
    }
    $report = Read-JsonObject -Path $reportPath
    $rows = @($report.results)
    if (
        $report.schema -cne "sporespore.lab.test_report.v1" -or
        $report.pattern -cne $testName -or
        [int]$report.total -ne 1 -or
        [int]$report.passed -ne 1 -or
        [int]$report.failed -ne 0 -or
        $rows.Count -ne 1
    ) {
        Stop-Certification (
            "$testName did not produce one complete passing report."
        )
    }
    $row = $rows[0]
    if (
        $row.test -cne $testName -or
        $row.status -cne "pass" -or
        [int]$row.process_exit_code -ne 0 -or
        $row.timed_out -ne $false -or
        $row.containment_tree_closed -ne $true -or
        $row.exit_marker_observed -ne $true -or
        [int64]$row.containment_host_process_id -lt 1 -or
        [int64]$row.target_process_id -lt 1 -or
        [string]::IsNullOrWhiteSpace([string]$row.target_started_utc) -or
        [string]::IsNullOrWhiteSpace([string]$row.target_ended_utc) -or
        [string]::CompareOrdinal(
            [string]$row.target_started_utc,
            [string]$row.target_ended_utc
        ) -gt 0 -or
        $row.target_time_window_valid -ne $true -or
        $row.footer_found -ne $true -or
        [int]$row.footer_count -ne 1 -or
        [int]$row.assertions_passed -ne [int]$Program.expected_assertions -or
        [int]$row.assertions_failed -ne 0 -or
        @($row.unexpected_engine_errors).Count -ne 0 -or
        @($row.missing_expected_engine_error_codes).Count -ne 0 -or
        @($row.unknown_expected_engine_error_codes).Count -ne 0
    ) {
        Stop-Certification (
            "$testName replicate $Replicate has an incomplete witness."
        )
    }
    foreach ($property in @("engine_log", "transcript_log")) {
        $artifactPath = Get-NormalizedFullPath -Path (
            [string]$row.$property
        )
        if (
            -not (Test-PathAtOrBelow $artifactPath $programRoot) -or
            -not (Test-Path -LiteralPath $artifactPath -PathType Leaf)
        ) {
            Stop-Certification (
                "$testName $property is missing or outside its raw root."
            )
        }
    }
    return [ordered]@{
        report_path = $reportPath
        report = $report
        row = $row
        operator_transcript = $operatorTranscript
    }
}

function Get-TranscriptEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int]$ExpectedAssertions
    )
    $lines = @([System.IO.File]::ReadAllLines($Path))
    $labels = @()
    $observations = @()
    foreach ($line in $lines) {
        $pass = [regex]::Match($line, '^\s+PASS\s{2}(.+?)\s*$')
        if ($pass.Success) {
            $labels += $pass.Groups[1].Value.Trim()
            continue
        }
        if ($line -match '^\s+FAIL\s{2}') {
            Stop-Certification (
                "Passing transcript contains a FAIL assertion line."
            )
        }
        if (
            [string]::IsNullOrWhiteSpace($line) -or
            $line -match '^Godot Engine v' -or
            $line -match '^===.+===$'
        ) {
            continue
        }
        $observations += $line.TrimEnd()
    }
    if ($labels.Count -ne $ExpectedAssertions) {
        Stop-Certification (
            "Transcript label count=$($labels.Count), " +
            "expected=$ExpectedAssertions."
        )
    }
    $labelsJson = ConvertTo-Json -InputObject ([object[]]$labels) -Compress
    return [ordered]@{
        assertion_labels = $labels
        assertion_labels_sha256 = Get-TextSha256 -Text $labelsJson
        observation_lines = $observations
        transcript_line_count = $lines.Count
    }
}

function New-ChecksumEntry {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]
        [ValidateSet("json", "opaque")]
        [string]$Kind
    )
    return [ordered]@{
        sha256 = Get-Sha256 -Path $Path
        bytes = [int64](Get-Item -LiteralPath $Path).Length
        kind = $Kind
        records = $null
    }
}

function Invoke-AttestationCli {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("bundle", "report")]
        [string]$Kind,
        [Parameter(Mandatory = $true)]
        [ValidateSet("attest", "verify")]
        [string]$Mode,
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [Parameter(Mandatory = $true)][string]$GodotPath,
        [Parameter(Mandatory = $true)][string]$Label,
        [string]$CertificationId = ""
    )
    $logRoot = Join-Path $script:SessionRoot "attestation_logs"
    [void][System.IO.Directory]::CreateDirectory($logRoot)
    $safe = $Label -replace '[^A-Za-z0-9_.-]', '_'
    $engineLog = Join-Path $logRoot "$safe.engine.log"
    $transcript = Join-Path $logRoot "$safe.transcript.log"
    $cli = if ($Kind -ceq "bundle") {
        $script:BundleAttestationCli
    } else {
        $script:ReportAttestationCli
    }
    $arguments = @(
        "--headless", "--path", $script:RepoRoot,
        "--log-file", $engineLog,
        "--script", $cli,
        "--",
        "--mode", $Mode
    )
    if ($Kind -ceq "bundle") {
        $arguments += @("--bundle", $TargetPath)
    } else {
        $arguments += @(
            "--report", $TargetPath,
            "--certification-id", $CertificationId
        )
    }
    $arguments += "--require-promotion"
    $invocation = Invoke-Contained (
        $GodotPath
    ) $arguments $transcript 300 $Label
    $prefix = if ($Kind -ceq "bundle") {
        "BR6A_BUNDLE_ATTESTATION"
    } else {
        "BR6A_REPORT_ATTESTATION"
    }
    $match = Get-OnlyRegexMatch (
        [string]$invocation.Text
    ) ("(?m)^" + $prefix + " result=(\{.+\})\s*$") (
        "$Label result"
    )
    try {
        $result = $match.Groups[1].Value |
            ConvertFrom-Json -Depth 100 -DateKind String
    } catch {
        Stop-Certification "$Label emitted invalid result JSON."
    }
    if ($result.ok -ne $true -or $result.trust_mode -cne "production") {
        Stop-Certification (
            "$Label did not return a production-trusted result."
        )
    }
    return $result
}

function New-EvidenceCapsule {
    param(
        [Parameter(Mandatory = $true)]$Program,
        [Parameter(Mandatory = $true)][int]$Replicate,
        [Parameter(Mandatory = $true)]$Harness,
        [Parameter(Mandatory = $true)][string]$SourceInventoryPath,
        [Parameter(Mandatory = $true)][string]$SourceInventorySha256,
        [Parameter(Mandatory = $true)][string]$CommitSha,
        [Parameter(Mandatory = $true)][string]$CampaignSha256,
        [Parameter(Mandatory = $true)][string]$CertificationId,
        [Parameter(Mandatory = $true)][string]$GodotPath,
        [Parameter(Mandatory = $true)][string]$ClaimBoundary
    )
    $bundleId = (
        "$CertificationId.$([string]$Program.program_id).r$Replicate"
    )
    $bundlePath = Join-Path (
        (Join-Path $script:SessionRoot "bundles")
    ) "$([string]$Program.program_id)\r$Replicate"
    if (Test-Path -LiteralPath $bundlePath) {
        Stop-Certification "Bundle path already exists: $bundlePath"
    }
    [void][System.IO.Directory]::CreateDirectory($bundlePath)
    $harnessReportPath = Join-Path $bundlePath "harness_report.json"
    $engineLogPath = Join-Path $bundlePath "engine.log"
    $transcriptPath = Join-Path $bundlePath "transcript.log"
    $inventoryPath = Join-Path $bundlePath "source_inventory.json"
    [System.IO.File]::Copy(
        [string]$Harness.report_path,
        $harnessReportPath
    )
    [System.IO.File]::Copy(
        [string]$Harness.row.engine_log,
        $engineLogPath
    )
    [System.IO.File]::Copy(
        [string]$Harness.row.transcript_log,
        $transcriptPath
    )
    [System.IO.File]::Copy($SourceInventoryPath, $inventoryPath)
    if ((Get-Sha256 $inventoryPath) -cne $SourceInventorySha256) {
        Stop-Certification (
            "Source inventory copy changed while building $bundleId."
        )
    }
    $transcriptEvidence = Get-TranscriptEvidence (
        $transcriptPath
    ) ([int]$Program.expected_assertions)
    $doesNotEstablish = @(
        "general_per_contact_or_per_foot_load_allocation",
        "free_root_standing_or_balance",
        "negligible_or_absent_scaffold_reaction",
        "bracing",
        "fall_arrest_or_getting_up",
        "gait_or_walking",
        "morphology_terrain_complex_foot_or_endurance_claim",
        "accepted_knowledge_or_automatic_guidance"
    )
    $metrics = [ordered]@{
        schema = "sporespore.lab.br6a_l4_evidence_metrics.v1"
        program_id = [string]$Program.program_id
        cell_id = [string]$Program.cell_id
        evidence_role = [string]$Program.evidence_role
        replicate = $Replicate
        test = [string]$Harness.row.test
        source_commit_sha = $CommitSha
        process = [ordered]@{
            containment_host_process_id = (
                [int64]$Harness.row.containment_host_process_id
            )
            target_process_id = [int64]$Harness.row.target_process_id
            started_utc = [string]$Harness.row.target_started_utc
            ended_utc = [string]$Harness.row.target_ended_utc
            fresh_process = $true
        }
        harness = [ordered]@{
            status = "pass"
            process_exit_code = 0
            timed_out = $false
            containment_tree_closed = $true
            exit_marker_observed = $true
            footer_count = 1
            assertions_passed = [int]$Harness.row.assertions_passed
            assertions_failed = 0
            unexpected_engine_error_count = 0
        }
        assertion_labels = @($transcriptEvidence.assertion_labels)
        observation_lines = @($transcriptEvidence.observation_lines)
        transcript_line_count = (
            [int]$transcriptEvidence.transcript_line_count
        )
        artifact_hashes = [ordered]@{
            harness_report = Get-Sha256 $harnessReportPath
            engine_log = Get-Sha256 $engineLogPath
            transcript_log = Get-Sha256 $transcriptPath
            source_inventory = $SourceInventorySha256
        }
        claim_scope = [string]$Program.claim_scope
        does_not_establish = $doesNotEstablish
    }
    $metricsPath = Join-Path $bundlePath "metrics.json"
    Write-CompactJson $metrics $metricsPath
    $capsule = [ordered]@{
        schema = "sporespore.lab.br6a_l4_evidence_capsule.v1"
        bundle_id = $bundleId
        campaign_id = "BR6A_L4_PROMOTION_CAMPAIGN_V1"
        certification_id = $CertificationId
        program_id = [string]$Program.program_id
        cell_id = [string]$Program.cell_id
        evidence_role = [string]$Program.evidence_role
        replicate = $Replicate
        status = "COMPLETE"
        source_commit_sha = $CommitSha
        campaign_sha256 = $CampaignSha256
        source_inventory_sha256 = $SourceInventorySha256
        metrics_sha256 = Get-Sha256 $metricsPath
        harness_report_sha256 = Get-Sha256 $harnessReportPath
        engine_log_sha256 = Get-Sha256 $engineLogPath
        transcript_log_sha256 = Get-Sha256 $transcriptPath
        process = [ordered]@{
            containment_host_process_id = (
                [int64]$Harness.row.containment_host_process_id
            )
            target_process_id = [int64]$Harness.row.target_process_id
            started_utc = [string]$Harness.row.target_started_utc
            ended_utc = [string]$Harness.row.target_ended_utc
        }
        created_utc = (Get-Date).ToUniversalTime().ToString("o")
        claim_boundary = $ClaimBoundary
    }
    $capsulePath = Join-Path $bundlePath "capsule.json"
    Write-CompactJson $capsule $capsulePath
    $programConfigJson = $Program |
        ConvertTo-Json -Depth 20 -Compress
    $programConfigSha = Get-TextSha256 $programConfigJson
    $testRelative = (
        ([string]$Program.test_resource_path).Substring(6).Replace("/", "\")
    )
    $loaded = [ordered]@{
        "res://data/lab/campaigns/BR6A_L4_promotion_campaign_v1.json" = (
            $CampaignSha256
        )
        ([string]$Program.test_resource_path) = Get-Sha256 (
            Join-Path $script:RepoRoot $testRelative
        )
    }
    $manifest = [ordered]@{
        schema = "sporespore.lab.manifest.v1"
        run_id = $bundleId
        status = "COMPLETE"
        experiment_id = [string]$Program.program_id
        schema_set = "sporespore.lab.schemas.v1"
        recorder_version = "br6a_l4_evidence_capsule_v1"
        expanded_spec_sha256 = $CampaignSha256
        resolved_configuration_sha256 = $programConfigSha
        applied_configuration_sha256 = $programConfigSha
        loaded_resource_hashes = $loaded
        git_commit = $CommitSha
        dirty_worktree = $false
        execution_mode = "promotion"
        reproducibility = "clean_committed_source"
        godot_version = $script:ExpectedGodotVersion
        physics_backend = (
            "Godot/Jolt as configured by project and exact program"
        )
        platform = [System.Environment]::OSVersion.VersionString
        process_isolation = "outer_parent_reserved_fresh_godot_v1"
        units = "SI"
        started_utc = [string]$Harness.report.started_utc
        finalized_utc = (Get-Date).ToUniversalTime().ToString("o")
        required_artifacts = @(
            "manifest.json", "capsule.json", "metrics.json",
            "harness_report.json", "engine.log", "transcript.log",
            "source_inventory.json"
        )
    }
    $manifestPath = Join-Path $bundlePath "manifest.json"
    Write-CompactJson $manifest $manifestPath
    $artifacts = [ordered]@{}
    foreach ($name in @(
        "manifest.json", "capsule.json", "metrics.json",
        "harness_report.json", "engine.log", "transcript.log",
        "source_inventory.json"
    )) {
        $kind = if ($name.EndsWith(".json")) {
            "json"
        } else {
            "opaque"
        }
        $artifacts[$name] = New-ChecksumEntry (
            Join-Path $bundlePath $name
        ) $kind
    }
    $checksums = [ordered]@{
        schema = "sporespore.lab.checksums.v1"
        run_id = $bundleId
        algorithm = "sha256"
        artifact_count = $artifacts.Count
        artifacts = $artifacts
    }
    $checksumsPath = Join-Path $bundlePath "checksums.json"
    Write-CompactJson $checksums $checksumsPath
    $attested = Invoke-AttestationCli (
        "bundle"
    ) "attest" $bundlePath $GodotPath (
        "$([string]$Program.program_id).r$Replicate.attest"
    )
    $verified = Invoke-AttestationCli (
        "bundle"
    ) "verify" $bundlePath $GodotPath (
        "$([string]$Program.program_id).r$Replicate.verify"
    )
    if (
        [string]$attested.receipt_path -cne [string]$verified.receipt_path -or
        [string]$attested.receipt_sha256 -cne (
            [string]$verified.receipt_sha256
        ) -or
        [string]$attested.key_id -cne [string]$verified.key_id
    ) {
        Stop-Certification "$bundleId attestation readback disagreed."
    }
    return [ordered]@{
        replicate = $Replicate
        bundle_id = $bundleId
        bundle_path = Get-NormalizedFullPath $bundlePath
        manifest_sha256 = Get-Sha256 $manifestPath
        checksums_sha256 = Get-Sha256 $checksumsPath
        capsule_sha256 = Get-Sha256 $capsulePath
        metrics_sha256 = Get-Sha256 $metricsPath
        source_inventory_sha256 = $SourceInventorySha256
        containment_host_process_id = (
            [int64]$Harness.row.containment_host_process_id
        )
        target_process_id = [int64]$Harness.row.target_process_id
        started_utc = [string]$Harness.row.target_started_utc
        ended_utc = [string]$Harness.row.target_ended_utc
        assertions_passed = [int]$Harness.row.assertions_passed
        assertion_labels_sha256 = (
            [string]$transcriptEvidence.assertion_labels_sha256
        )
        transcript_sha256 = Get-Sha256 $transcriptPath
        attestation = [ordered]@{
            valid = $true
            trust_mode = "production"
            key_id = [string]$verified.key_id
            receipt_path = [string]$verified.receipt_path
            receipt_sha256 = [string]$verified.receipt_sha256
        }
        assertion_labels = @($transcriptEvidence.assertion_labels)
    }
}

function Assert-OrdinalStringArraysEqual {
    param(
        [Parameter(Mandatory = $true)][object[]]$Left,
        [Parameter(Mandatory = $true)][object[]]$Right,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if ($Left.Count -ne $Right.Count) {
        Stop-Certification "$Label count differs across replicates."
    }
    for ($index = 0; $index -lt $Left.Count; $index++) {
        if ([string]$Left[$index] -cne [string]$Right[$index]) {
            Stop-Certification "$Label differs at index $index."
        }
    }
}

function Invoke-FinalBundleReadback {
    param(
        [Parameter(Mandatory = $true)]$ProgramReports,
        [Parameter(Mandatory = $true)][string]$GodotPath
    )
    $count = 0
    foreach ($program in @($ProgramReports)) {
        foreach ($replicate in @($program.replicates)) {
            $verified = Invoke-AttestationCli (
                "bundle"
            ) "verify" ([string]$replicate.bundle_path) $GodotPath (
                "$([string]$program.program_id)." +
                "r$([int]$replicate.replicate).final"
            )
            $bundlePath = [string]$replicate.bundle_path
            if (
                [string]$verified.receipt_sha256 -cne (
                    [string]$replicate.attestation.receipt_sha256
                ) -or
                (Get-Sha256 (
                    Join-Path $bundlePath "manifest.json"
                )) -cne [string]$replicate.manifest_sha256 -or
                (Get-Sha256 (
                    Join-Path $bundlePath "checksums.json"
                )) -cne [string]$replicate.checksums_sha256 -or
                (Get-Sha256 (
                    Join-Path $bundlePath "capsule.json"
                )) -cne [string]$replicate.capsule_sha256 -or
                (Get-Sha256 (
                    Join-Path $bundlePath "metrics.json"
                )) -cne [string]$replicate.metrics_sha256
            ) {
                Stop-Certification (
                    "Final readback changed: $($replicate.bundle_id)"
                )
            }
            $count += 1
        }
    }
    if ($count -ne 6) {
        Stop-Certification "Final readback saw $count bundles, expected 6."
    }
    return $count
}

function New-CellReports {
    param([Parameter(Mandatory = $true)]$Campaign)
    $cells = @()
    foreach ($cellId in @("L4.0", "L4.1", "L4.3")) {
        $programs = @($Campaign.programs | Where-Object {
            $_.cell_id -ceq $cellId -and
            $_.evidence_role -ceq "milestone"
        })
        $assertions = (
            $programs |
                Measure-Object expected_assertions -Sum
        ).Sum
        $cells += [ordered]@{
            cell_id = $cellId
            programs_required = $programs.Count
            programs_passed = $programs.Count
            assertions_per_replicate = [int]$assertions
            status = "pass"
        }
    }
    return $cells
}

try {
    if ($PSVersionTable.PSVersion -lt [Version]"7.5") {
        Stop-Certification (
            "BR6A certification requires PowerShell 7.5 or newer."
        )
    }
    if ($PreflightOnly) {
        $preflightCommit = Invoke-GitText -Arguments @("rev-parse", "HEAD")
        $preflightEngine = Assert-GodotIdentity -GodotPath $Godot
        if (
            (Get-Sha256 $script:Br1InventoryPath) -cne (
                $script:ExpectedBr1InventorySha256
            )
        ) {
            Stop-Certification "The frozen BR1 report-v2 inventory changed."
        }
        $preflightCampaign = Read-JsonObject -Path $script:CampaignPath
        Assert-CampaignContract -Campaign $preflightCampaign
        $preflightInventory = Get-SourceInventory (
            $preflightCampaign
        ) $preflightCommit
        Write-Host (
            "BR6A preflight=pass non_promotable=true programs=3 " +
            "source_files=$($preflightInventory.file_count) " +
            "godot_sha256=$($preflightEngine.sha256)"
        )
        Write-Host (
            "BR6A preflight note=No physics ran, no bundle/report was " +
            "written, and no milestone decision was created."
        )
        exit 0
    }
    $sourceStart = Get-CleanSourceState -Stage "campaign_start"
    $commitSha = [string]$sourceStart.commit_sha
    $engine = Assert-GodotIdentity -GodotPath $Godot
    if (
        (Get-Sha256 $script:Br1InventoryPath) -cne (
            $script:ExpectedBr1InventorySha256
        )
    ) {
        Stop-Certification "The frozen BR1 report-v2 inventory changed."
    }
    $campaign = Read-JsonObject -Path $script:CampaignPath
    Assert-CampaignContract -Campaign $campaign
    $campaignSha256 = Get-Sha256 $script:CampaignPath
    $sourceInventory = Get-SourceInventory $campaign $commitSha
    $localAppData = [Environment]::GetFolderPath(
        [Environment+SpecialFolder]::LocalApplicationData
    )
    if ([string]::IsNullOrWhiteSpace($localAppData)) {
        Stop-Certification "LOCALAPPDATA cannot be resolved."
    }
    $stamp = (Get-Date).ToUniversalTime().ToString(
        "yyyyMMdd'T'HHmmss'Z'"
    )
    $certificationId = (
        "br6a_" + $stamp + "_" + $commitSha.Substring(0, 8)
    )
    $script:SessionRoot = Join-Path (
        (Join-Path $localAppData "SporeSpore\LabEvidence\BR6A")
    ) $certificationId
    if (Test-Path -LiteralPath $script:SessionRoot) {
        Stop-Certification (
            "Certification output already exists: $script:SessionRoot"
        )
    }
    [void][System.IO.Directory]::CreateDirectory($script:SessionRoot)
    $sourceInventoryPath = Join-Path (
        $script:SessionRoot
    ) "source_inventory.json"
    Write-CompactJson $sourceInventory $sourceInventoryPath
    $sourceInventorySha256 = Get-Sha256 $sourceInventoryPath
    $rawRoot = Join-Path $script:SessionRoot "raw"
    [void][System.IO.Directory]::CreateDirectory($rawRoot)
    $targetPidWindows = @{}
    $targetProcessInvocations = 0
    $pidRecycleEvents = 0
    $programReports = @()
    $assertionsPassed = 0
    $programIndex = 0
    foreach ($program in @($campaign.programs)) {
        $programIndex += 1
        Write-Host (
            "BR6A program=$programIndex/3 id=$($program.program_id)"
        )
        $replicates = @()
        for ($replicate = 1; $replicate -le 2; $replicate++) {
            Assert-SameCleanSource $commitSha (
                "$($program.program_id)_r$($replicate)_before"
            )
            Assert-SourceInventoryCurrent -Inventory $sourceInventory
            $harness = Invoke-HarnessReplicate (
                $program
            ) $replicate $Godot $rawRoot
            $capsule = New-EvidenceCapsule (
                $program
            ) $replicate $harness $sourceInventoryPath (
                $sourceInventorySha256
            ) $commitSha $campaignSha256 $certificationId $Godot (
                [string]$campaign.claim_boundary
            )
            $pidKey = ([int64]$capsule.target_process_id).ToString()
            if ($targetPidWindows.ContainsKey($pidKey)) {
                $priorWindow = $targetPidWindows[$pidKey]
                if ([string]::CompareOrdinal(
                    [string]$priorWindow.ended_utc,
                    [string]$capsule.started_utc
                ) -gt 0) {
                    Stop-Certification (
                        "A recycled Godot PID has overlapping run windows."
                    )
                }
                $pidRecycleEvents += 1
            }
            $targetPidWindows[$pidKey] = [ordered]@{
                started_utc = [string]$capsule.started_utc
                ended_utc = [string]$capsule.ended_utc
            }
            $targetProcessInvocations += 1
            $assertionsPassed += [int]$capsule.assertions_passed
            $replicates += $capsule
        }
        Assert-OrdinalStringArraysEqual (
            @($replicates[0].assertion_labels)
        ) (
            @($replicates[1].assertion_labels)
        ) "$($program.program_id) ordered assertion labels"
        $reportReplicates = @()
        foreach ($replicateResult in $replicates) {
            $copy = [ordered]@{}
            foreach ($property in $replicateResult.Keys) {
                if ($property -cne "assertion_labels") {
                    $copy[$property] = $replicateResult[$property]
                }
            }
            $reportReplicates += $copy
        }
        $programReports += [ordered]@{
            program_id = [string]$program.program_id
            cell_id = [string]$program.cell_id
            evidence_role = [string]$program.evidence_role
            test = [System.IO.Path]::GetFileName(
                [string]$program.test_resource_path
            )
            expected_assertions = [int]$program.expected_assertions
            claim_scope = [string]$program.claim_scope
            replicates = $reportReplicates
            reconciliation = [ordered]@{
                pass = $true
                source_identity_match = $true
                assertion_count_match = $true
                ordered_assertion_labels_match = $true
                both_raw_transcripts_retained = $true
                raw_transcript_identity_required = $false
            }
        }
    }
    if ($targetProcessInvocations -ne 6 -or $assertionsPassed -ne 80) {
        Stop-Certification (
            "Campaign accounting is incomplete before readback."
        )
    }
    $finalBundles = Invoke-FinalBundleReadback $programReports $Godot
    Assert-SameCleanSource $commitSha "final_report"
    Assert-SourceInventoryCurrent -Inventory $sourceInventory
    $script:ReportPath = Join-Path (
        $script:SessionRoot
    ) "br6a_certification_report.json"
    $report = [ordered]@{
        schema = "sporespore.lab.br6a_certification_report.v1"
        status = "pass"
        certification = "BR6A_L4_VERTICAL_RAIL_LEG_SUPPORT"
        certification_id = $certificationId
        milestone_id = "BR6A_L4_VERTICAL_RAIL_LEG_SUPPORT"
        claim_boundary = [string]$campaign.claim_boundary
        generated_utc = (Get-Date).ToUniversalTime().ToString("o")
        source = [ordered]@{
            repository_root = $script:RepoRoot
            commit_sha = $commitSha
            clean_at_start = $true
            clean_at_end = $true
            campaign_path = Get-NormalizedFullPath $script:CampaignPath
            campaign_sha256 = $campaignSha256
            source_inventory_sha256 = $sourceInventorySha256
            source_file_count = [int]$sourceInventory.file_count
            br1_inventory_path = (
                Get-NormalizedFullPath $script:Br1InventoryPath
            )
            br1_inventory_sha256 = $script:ExpectedBr1InventorySha256
            br1_inventory_unchanged = $true
        }
        engine = [ordered]@{
            executable = [string]$engine.executable
            sha256 = [string]$engine.sha256
            version = [string]$engine.version
            fresh_target_process_invocations = 6
            pid_recycle_events_recorded = $true
        }
        bundle_policy = [ordered]@{
            manifest_schema = "sporespore.lab.manifest.v1"
            capsule_schema = (
                "sporespore.lab.br6a_l4_evidence_capsule.v1"
            )
            metrics_schema = (
                "sporespore.lab.br6a_l4_evidence_metrics.v1"
            )
            receipt_schema = (
                "sporespore.lab.publication_attestation.v1"
            )
            receipt_domain = (
                "sporespore.lab.publication_attestation.v1"
            )
            trust_mode = "production"
        }
        report_attestation_policy = [ordered]@{
            receipt_schema = (
                "sporespore.lab.br6a_certification_report_attestation.v1"
            )
            receipt_domain = (
                "sporespore.lab.br6a_certification_report_attestation.v1"
            )
            trust_mode = "production"
            detached = $true
            report_rewrite_after_attestation_forbidden = $true
        }
        accounting = [ordered]@{
            programs_required = 3
            programs_passed = 3
            replicates_per_program = 2
            bundles_required = 6
            bundles_passed = 6
            assertions_required = 80
            assertions_passed = 80
            milestone_programs = 3
            milestone_assertions = 80
            supplementary_programs = 0
            supplementary_assertions = 0
            integrity_programs = 0
            integrity_assertions = 0
        }
        cells = @(New-CellReports -Campaign $campaign)
        programs = $programReports
        final_readback = [ordered]@{
            bundles_required = 6
            bundles_verified = $finalBundles
            receipts_required = 6
            receipts_verified = $finalBundles
            source_inventories_verified = $finalBundles
            metrics_verified = $finalBundles
            target_process_invocations = $targetProcessInvocations
            unique_target_processes = $targetPidWindows.Count
            pid_recycle_events = $pidRecycleEvents
            complete_campaign = $true
        }
        rail_support_constraints = [ordered]@{
            rail_type = "Generic6DOFJoint3D_vertical_translation_only"
            vertical_translation_unlocked = $true
            x_z_translation_locked = $true
            all_rotation_locked = $true
            rail_motors_or_springs_enabled = $false
            built_in_joint_motors_enabled = $false
            passive_tissues_enabled = $false
            foot_pin_enabled = $false
            controller_root_rescue_enabled = $false
            ordinary_distal_contact = $true
            aggregate_external_load_reconstruction = $true
            per_foot_allocation_available = $false
            material_rail_reaction_retained = $true
            articulated_rail_support_established = $true
        }
        capabilities = [ordered]@{
            accepted_knowledge_entries = 0
            automatic_creature_guidance_allowed = $false
            general_per_foot_load_allocation = $false
            articulated_rail_constrained_vertical_support = $true
            free_root_standing = $false
            balance = $false
            bracing = $false
            fall_arrest = $false
            getting_up = $false
            walking = $false
        }
        does_not_establish = @($campaign.does_not_establish)
    }
    Write-CompactJson $report $script:ReportPath
    $reportSha256 = Get-Sha256 $script:ReportPath
    $attestedReport = Invoke-AttestationCli (
        "report"
    ) "attest" $script:ReportPath $Godot "final_report.attest" (
        $certificationId
    )
    $verifiedReport = Invoke-AttestationCli (
        "report"
    ) "verify" $script:ReportPath $Godot "final_report.verify" (
        $certificationId
    )
    if (
        (Get-Sha256 $script:ReportPath) -cne $reportSha256 -or
        [string]$attestedReport.report_sha256 -cne $reportSha256 -or
        [string]$verifiedReport.report_sha256 -cne $reportSha256 -or
        [string]$attestedReport.receipt_sha256 -cne (
            [string]$verifiedReport.receipt_sha256
        )
    ) {
        Stop-Certification (
            "Final report or receipt changed after attestation."
        )
    }
    Write-Host "BR6A certification=pass"
    Write-Host (
        "BR6A programs=3/3 bundles=6/6 assertions=80/80 " +
        "target_process_invocations=6 unique_target_pids=$($targetPidWindows.Count) " +
        "pid_recycle_events=$pidRecycleEvents"
    )
    Write-Host (
        "BR6A milestone=L4.0,L4.1,L4.3 assertions=80/80 " +
        "supplementary=0/0 integrity=0/0"
    )
    Write-Host (
        "BR6A report=$script:ReportPath sha256=$reportSha256"
    )
    Write-Host (
        "BR6A report_receipt=$($verifiedReport.receipt_path) " +
        "receipt_sha256=$($verifiedReport.receipt_sha256)"
    )
    Write-Host (
        "BR6A milestone_decision=required accepted_knowledge=0 " +
        "automatic_guidance=false"
    )
    exit 0
} catch {
    $message = $_.Exception.Message
    Write-Error "BR6A certification failed: $message" -ErrorAction Continue
    if (
        $null -ne $script:SessionRoot -and
        (Test-Path -LiteralPath $script:SessionRoot)
    ) {
        $failurePath = Join-Path (
            $script:SessionRoot
        ) "br6a_certification_failure.json"
        try {
            Write-CompactJson ([ordered]@{
                schema = "sporespore.lab.br6a_certification_failure.v1"
                status = "fail"
                generated_utc = (
                    Get-Date
                ).ToUniversalTime().ToString("o")
                message = $message
                report_path = $script:ReportPath
            }) $failurePath
            Write-Host "BR6A failure_report=$failurePath"
        } catch {
            Write-Warning (
                "Could not write failure report: $($_.Exception.Message)"
            )
        }
    }
    exit 1
}

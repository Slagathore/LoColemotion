#requires -Version 7.0

<#
.SYNOPSIS
Runs the clean-source, promotion-grade BR1/L0 certification campaign.

.DESCRIPTION
This operator certifies the BR1 evidence pipeline. It does not certify a
creature's ability to stand, brace, recover, or walk.

The campaign is deliberately fixed:

- data/lab/campaigns/BR1_L0_certification_v1.json defines seven cells;
- each cell runs twice in a fresh outer launch_lab Godot process;
- every finalized bundle must carry a valid production HMAC receipt;
- every bundle must pass independent promotion validation and physics-free
  L0.4 replay;
- each same-seed replicate pair must match under the pinned BR1 comparator;
- the exact lab-test inventory is pinned and no missing or extra test is
  accepted;
- the repository must be clean and resolve to the same commit at each recorded
  source-state gate.

Evidence is written outside the repository. The default durable location is:

    %LOCALAPPDATA%\SporeSpore\LabEvidence\BR1

Run from PowerShell 7:

    pwsh -File .\scripts\run_br1_certification.ps1

The only positive certification marker is the final line:

    BR1 certification=pass

Any failure ends with:

    BR1 certification=failed
#>

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$OutputRoot = $(
        if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
            ""
        } else {
            Join-Path $env:LOCALAPPDATA "SporeSpore\LabEvidence\BR1"
        }
    ),
    [ValidateRange(1, 3600)]
    [int]$TestTimeoutSeconds = 180,
    [ValidateRange(1, 86400)]
    [int]$LabSuiteTimeoutSeconds = 10800,
    [ValidateRange(1, 86400)]
    [int]$StepTimeoutSeconds = 900
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$script:RepoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$script:SessionRoot = $null
$script:ReportPath = $null
$script:FailureReportPath = $null
$script:ClaimBoundary = (
    "BR1 certifies only the L0 evidence pipeline. It establishes no " +
    "standing, bracing, recovery, or walking capability."
)
$script:ExpectedGodotVersion = (
    "4.7.stable.mono.official.5b4e0cb0f"
)
$script:ExpectedGodotExecutableSha256 = (
    "sha256:c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
)
$script:ExpectedGodotProductVersion = "4.7.stable.mono.official"
$script:ExpectedGodotFileDescription = "Godot Engine (Console)"
$script:ExpectedPhysicsChildExecutableName = (
    "Godot_v4.7-stable_mono_win64.exe"
)
$script:ExpectedPhysicsChildExecutableSha256 = (
    "sha256:baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4"
)
$script:ExpectedPhysicsChildProductVersion = (
    "4.7.stable.mono.official"
)
$script:ExpectedPhysicsChildFileDescription = "Godot Engine"
# Report-v1 is frozen behind two verify-only qualification profiles (45 and
# 51 tests). New authoring uses report/inventory/receipt v2. This exact current
# inventory includes the BR2.1 integrity oracles and BR3A contact pipeline.
$script:ExpectedTestCount = 62
$script:ExpectedTestInventorySha256 = (
    "sha256:f22a43c3125d2a87c3f4b154af40d5e99a2a9dd1da35e159825e79635357605e"
)
# Report attestation intentionally remains a detached post-serialization
# boundary: a report cannot embed its own receipt without creating a circular
# digest. These values pin the complete CLI boundary as one contract.
$script:ReportAttestationContract = [ordered]@{
    cli_resource = (
        "res://scripts/lab/certification_report_attestation_cli.gd"
    )
    receipt_schema = (
        "sporespore.lab.br1_certification_report_attestation.v2"
    )
    algorithm = "hmac-sha256"
    trust_mode = "production"
    result_marker = "BR1_REPORT_ATTESTATION result="
    verdict_marker = "BR1_REPORT_ATTESTATION verdict="
    exit_pass = 0
    exit_not_promotable = 2
    exit_invalid = 3
    exit_configuration = 4
}

$campaignRelativePath = "data\lab\campaigns\BR1_L0_certification_v1.json"
$inventoryRelativePath = (
    "data\lab\campaigns\BR1_required_lab_tests_v2.json"
)
$campaignPath = Join-Path $script:RepoRoot $campaignRelativePath
$inventoryPath = Join-Path $script:RepoRoot $inventoryRelativePath
$processRunnerPath = Join-Path $PSScriptRoot "process_runner.ps1"
$processRunnerContainmentHostPath = Join-Path (
    $PSScriptRoot
) "process_runner_containment_host.ps1"
$processRunnerTestPath = Join-Path $PSScriptRoot "test_process_runner.ps1"
$testHarnessPath = Join-Path $PSScriptRoot "run_lab_tests.ps1"
$attestationInitializerPath = Join-Path (
    $PSScriptRoot
) "initialize_lab_attestation.ps1"
$attestationInitializerTestPath = Join-Path (
    $PSScriptRoot
) "test_initialize_lab_attestation.ps1"
$comparatorCliRelativePath = "scripts\lab\l0_replicate_comparator_cli.gd"
$comparatorCliPath = Join-Path $script:RepoRoot $comparatorCliRelativePath
$reportAttestationCliPath = Join-Path (
    $script:RepoRoot
) "scripts\lab\certification_report_attestation_cli.gd"
$replaySpec = (
    "res://data/lab/experiments/L0_4_trace_playback_v1.tres"
)


function Stop-Certification {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message
    )

    throw [System.InvalidOperationException]::new($Message)
}


function ConvertFrom-JsonPreservingStrings {
    <#
    PowerShell 7.5 added automatic JSON date recognition. Without an explicit
    DateKind, an RFC 3339 string can become a DateTime and later serialize as
    locale-dependent text. Older PowerShell versions do not expose DateKind
    and already retain JSON strings, so select the option only when available.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Json,
        [ValidateRange(1, 1024)]
        [int]$Depth = 100
    )

    $arguments = @{
        InputObject = $Json
        Depth = $Depth
        ErrorAction = "Stop"
    }
    if (
        (Get-Command ConvertFrom-Json).Parameters.ContainsKey("DateKind")
    ) {
        $arguments["DateKind"] = "String"
    }
    $value = ConvertFrom-Json @arguments
    return $value
}


function Assert-JsonScalarPreservation {
    $expectedUtc = "2026-07-20T02:20:17Z"
    $expectedOffset = "2026-07-19T21:20:17-05:00"
    $probe = ConvertFrom-JsonPreservingStrings -Json (
        '{"utc":"' + $expectedUtc + '","offset":"' +
        $expectedOffset + '"}'
    )
    if (
        $probe.utc -isnot [string] -or
        $probe.offset -isnot [string] -or
        $probe.utc -cne $expectedUtc -or
        $probe.offset -cne $expectedOffset
    ) {
        Stop-Certification (
            "JSON parser changed an RFC 3339 string into a typed or " +
            "locale-dependent value."
        )
    }
}


function ConvertTo-UtcInstant {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $formats = @(
        "yyyy-MM-dd'T'HH:mm:ss'Z'",
        "yyyy-MM-dd'T'HH:mm:ss'.'FFFFFFF'Z'"
    )
    foreach ($format in $formats) {
        $parsed = [System.DateTimeOffset]::MinValue
        if ([System.DateTimeOffset]::TryParseExact(
            $Value,
            $format,
            [System.Globalization.CultureInfo]::InvariantCulture,
            (
                [System.Globalization.DateTimeStyles]::AssumeUniversal -bor
                [System.Globalization.DateTimeStyles]::AdjustToUniversal
            ),
            [ref]$parsed
        )) {
            return $parsed
        }
    }
    Stop-Certification (
        "$Label is not a UTC RFC 3339 instant: '$Value'"
    )
}


function Register-CampaignProcessInvocation {
    <#
    Windows recycles PIDs across non-overlapping process lifetimes, so PID
    equality alone is not process identity. Each launch step independently
    proves that its own fresh process tree terminated before the step
    finished (authenticated exit marker plus closed Job Object containment),
    which forbids one launcher or physics child from serving two steps.
    What raw PID equality could still hide is two CONCURRENT runs sharing one
    live process, so a recycled PID is accepted only when the sealed run
    windows are provably disjoint, and every acceptance is recorded as a
    pid_recycle_events witness in the certification report.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("outer_parent", "physics_child")]
        [string]$Role,
        [Parameter(Mandatory = $true)][long]$ProcessId,
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$StartedUtc,
        [Parameter(Mandatory = $true)][string]$EndedUtc,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if ($ProcessId -le 0) {
        Stop-Certification (
            "$Label reported a non-positive $Role process id."
        )
    }
    $started = ConvertTo-UtcInstant `
        -Value $StartedUtc `
        -Label "$Label $Role started_utc"
    $ended = ConvertTo-UtcInstant `
        -Value $EndedUtc `
        -Label "$Label $Role ended_utc"
    if ($ended -lt $started) {
        Stop-Certification (
            "$Label $Role sealed run window ends before it starts."
        )
    }
    $ledger = $script:CampaignProcessLedger[$Role]
    if ($ledger.ContainsKey($ProcessId)) {
        foreach ($prior in @($ledger[$ProcessId])) {
            if ([string]$prior.run_id -ceq $RunId) {
                Stop-Certification (
                    "$Label $Role run identity was registered twice."
                )
            }
            if (
                $started -lt $prior.ended -and
                $prior.started -lt $ended
            ) {
                Stop-Certification (
                    "$Label $Role PID $ProcessId run window overlaps the " +
                    "sealed window of $($prior.run_id); two live runs " +
                    "cannot share one process."
                )
            }
            $priorIsEarlier = $prior.ended -le $started
            [void]$script:PidRecycleEvents.Add([ordered]@{
                role = $Role
                process_id = [long]$ProcessId
                earlier_run_id = [string]$(
                    if ($priorIsEarlier) { $prior.run_id } else { $RunId }
                )
                earlier_ended_utc = [string]$(
                    if ($priorIsEarlier) {
                        $prior.ended_utc
                    } else {
                        $EndedUtc
                    }
                )
                later_run_id = [string]$(
                    if ($priorIsEarlier) { $RunId } else { $prior.run_id }
                )
                later_started_utc = [string]$(
                    if ($priorIsEarlier) {
                        $StartedUtc
                    } else {
                        $prior.started_utc
                    }
                )
            })
        }
    } else {
        $ledger[$ProcessId] = (
            [System.Collections.Generic.List[object]]::new()
        )
    }
    [void]$ledger[$ProcessId].Add([pscustomobject]@{
        run_id = $RunId
        started = $started
        ended = $ended
        started_utc = $StartedUtc
        ended_utc = $EndedUtc
    })
    $script:CampaignProcessInvocationCounts[$Role] += 1
}


function Get-NormalizedFullPath {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

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


function Assert-NoReparseAncestor {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $probe = [System.IO.DirectoryInfo]::new(
        (Get-NormalizedFullPath -Path $Path)
    )
    while ($null -ne $probe) {
        if (
            $probe.Exists -and
            (
                $probe.Attributes -band
                [System.IO.FileAttributes]::ReparsePoint
            ) -ne 0
        ) {
            Stop-Certification (
                "$Label cannot traverse a filesystem reparse point: " +
                $probe.FullName
            )
        }
        $probe = $probe.Parent
    }
}


function Get-Sha256 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Stop-Certification "Cannot hash missing file: $Path"
    }
    return "sha256:$(
        (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    )"
}


function Get-BytesSha256 {
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$Bytes
    )

    return "sha256:$(
        [System.Convert]::ToHexString(
            [System.Security.Cryptography.SHA256]::HashData($Bytes)
        ).ToLowerInvariant()
    )"
}


function Assert-GodotBinaryIdentity {
    param(
        [Parameter(Mandatory = $true)][string]$GodotPath,
        [Parameter(Mandatory = $true)][string]$Stage
    )

    $observedSha256 = Get-Sha256 -Path $GodotPath
    $versionInfo = (Get-Item -LiteralPath $GodotPath).VersionInfo
    $productVersion = [string]$versionInfo.ProductVersion
    $fileDescription = [string]$versionInfo.FileDescription
    if (
        $observedSha256 -cne
            $script:ExpectedGodotExecutableSha256 -or
        $productVersion -cne $script:ExpectedGodotProductVersion -or
        $fileDescription -cne $script:ExpectedGodotFileDescription
    ) {
        Stop-Certification (
            "Godot executable identity changed or is not the pinned BR1 " +
            "build at ${Stage}: expected " +
            "$script:ExpectedGodotExecutableSha256, observed " +
            "$observedSha256; expected ProductVersion " +
            "'$script:ExpectedGodotProductVersion', observed " +
            "'$productVersion'; expected FileDescription " +
            "'$script:ExpectedGodotFileDescription', observed " +
            "'$fileDescription'."
        )
    }
    return [ordered]@{
        stage = $Stage
        executable_sha256 = $observedSha256
        product_version = $productVersion
        file_description = $fileDescription
        matches_pinned_build = $true
    }
}


function Assert-PhysicsChildBinaryIdentity {
    param(
        [Parameter(Mandatory = $true)][string]$GodotPath,
        [Parameter(Mandatory = $true)][string]$Stage
    )

    if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
        Stop-Certification (
            "The pinned physics-child Godot executable is missing at " +
            "${Stage}: $GodotPath"
        )
    }
    $observedSha256 = Get-Sha256 -Path $GodotPath
    $item = Get-Item -LiteralPath $GodotPath
    $productVersion = [string]$item.VersionInfo.ProductVersion
    $fileDescription = [string]$item.VersionInfo.FileDescription
    if (
        $item.Name -cne $script:ExpectedPhysicsChildExecutableName -or
        $observedSha256 -cne
            $script:ExpectedPhysicsChildExecutableSha256 -or
        $productVersion -cne
            $script:ExpectedPhysicsChildProductVersion -or
        $fileDescription -cne
            $script:ExpectedPhysicsChildFileDescription
    ) {
        Stop-Certification (
            "Physics-child Godot executable identity changed at ${Stage}: " +
            "expected name '$script:ExpectedPhysicsChildExecutableName', " +
            "observed '$($item.Name)'; expected " +
            "$script:ExpectedPhysicsChildExecutableSha256, observed " +
            "$observedSha256; expected ProductVersion " +
            "'$script:ExpectedPhysicsChildProductVersion', observed " +
            "'$productVersion'; expected FileDescription " +
            "'$script:ExpectedPhysicsChildFileDescription', observed " +
            "'$fileDescription'."
        )
    }
    return [ordered]@{
        stage = $Stage
        executable_sha256 = $observedSha256
        product_version = $productVersion
        file_description = $fileDescription
        matches_pinned_build = $true
    }
}


function Read-JsonObject {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Stop-Certification "$Label is missing: $Path"
    }
    try {
        $json = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        $value = ConvertFrom-JsonPreservingStrings -Json $json -Depth 100
    } catch {
        Stop-Certification (
            "$Label is not valid JSON: $Path " +
            "($($_.Exception.Message))"
        )
    }
    if (
        $null -eq $value -or
        $value -is [System.Array] -or
        $value -is [string] -or
        $value -is [ValueType]
    ) {
        Stop-Certification "$Label must contain exactly one JSON object."
    }
    return $value
}


function Write-CompactJson {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        [void][System.IO.Directory]::CreateDirectory($directory)
    }
    $temporaryPath = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    $json = $Value | ConvertTo-Json -Depth 30 -Compress
    $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
    try {
        [System.IO.File]::WriteAllText(
            $temporaryPath,
            $json,
            $utf8WithoutBom
        )
        [System.IO.File]::Move($temporaryPath, $Path, $false)
    } finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}


function Invoke-CertificationProcess {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$ArgumentList,
        [Parameter(Mandatory = $true)][string]$TranscriptPath,
        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 86400)]
        [int]$TimeoutSeconds
    )

    Write-Host "BR1 step=$Label state=started"
    $result = Invoke-ProcessWithTimeout `
        -FilePath $FilePath `
        -ArgumentList $ArgumentList `
        -TimeoutSeconds $TimeoutSeconds `
        -TranscriptPath $TranscriptPath
    @($result.Lines) | ForEach-Object { Write-Host $_ }
    Write-Host (
        "BR1 step=$Label state=finished " +
        "native_exit=$($result.ExitCode) " +
        "timed_out=$($result.TimedOut) " +
        "duration_ms=$($result.DurationMs)"
    )
    if ($result.TimedOut) {
        Stop-Certification (
            "$Label exceeded its ${TimeoutSeconds}-second timeout; " +
            "the complete child process tree was terminated."
        )
    }
    if (-not [string]::IsNullOrWhiteSpace($result.StartError)) {
        Stop-Certification (
            "$Label could not start or wait: $($result.StartError)"
        )
    }
    if (-not [string]::IsNullOrWhiteSpace($result.TerminationError)) {
        Stop-Certification (
            "$Label process-tree termination failed: " +
            $result.TerminationError
        )
    }
    if (
        $result.ExitMarkerObserved -ne $true -or
        $result.ContainmentTreeClosed -ne $true
    ) {
        Stop-Certification (
            "$Label did not cross the authenticated exit-marker and " +
            "Windows Job Object containment boundary."
        )
    }
    return $result
}


function Assert-GodotInvocationClean {
    param(
        [Parameter(Mandatory = $true)]$Invocation,
        [Parameter(Mandatory = $true)][string]$EngineLogPath,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not (Test-Path -LiteralPath $EngineLogPath -PathType Leaf)) {
        Stop-Certification (
            "$Label did not create its required Godot engine log: " +
            $EngineLogPath
        )
    }
    $engineText = Get-Content -LiteralPath $EngineLogPath -Raw
    $combined = (
        [string]$Invocation.Text +
        [Environment]::NewLine +
        $engineText
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
        Stop-Certification (
            "$Label emitted $($engineErrors.Count) Godot engine/script " +
            "error line(s): " +
            ((@($engineErrors | Select-Object -First 4)) -join " | ")
        )
    }
}


function Get-SingleMatch {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $matcher = [regex]::new($Pattern)
    $matches = @(
        foreach ($line in $Lines) {
            $match = $matcher.Match([string]$line)
            if ($match.Success) {
                $match
            }
        }
    )
    if ($matches.Count -ne 1) {
        Stop-Certification (
            "$Label must appear exactly once; observed " +
            "$($matches.Count) matching line(s)."
        )
    }
    return $matches[0]
}


function Assert-ExactStringList {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$Expected,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$Actual,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $expectedDuplicates = @(
        $Expected |
            Group-Object -CaseSensitive |
            Where-Object { $_.Count -ne 1 }
    )
    $actualDuplicates = @(
        $Actual |
            Group-Object -CaseSensitive |
            Where-Object { $_.Count -ne 1 }
    )
    if (
        $expectedDuplicates.Count -gt 0 -or
        $actualDuplicates.Count -gt 0
    ) {
        Stop-Certification "$Label contains duplicate names."
    }
    $difference = @(
        Compare-Object `
            -ReferenceObject $Expected `
            -DifferenceObject $Actual `
            -CaseSensitive
    )
    if ($difference.Count -gt 0) {
        $detail = @(
            $difference |
                ForEach-Object {
                    "$($_.SideIndicator)$($_.InputObject)"
                }
        ) -join ", "
        Stop-Certification "$Label differs from its pin: $detail"
    }
    if ($Expected.Count -ne $Actual.Count) {
        Stop-Certification (
            "$Label count differs from its pin: expected " +
            "$($Expected.Count), observed $($Actual.Count)."
        )
    }
    for ($index = 0; $index -lt $Expected.Count; $index += 1) {
        if ($Expected[$index] -cne $Actual[$index]) {
            Stop-Certification (
                "$Label order differs at index ${index}: expected " +
                "'$($Expected[$index])', observed '$($Actual[$index])'."
            )
        }
    }
}


function Assert-ExactOrderedValues {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$Expected,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$Actual,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if ($Expected.Count -ne $Actual.Count) {
        Stop-Certification (
            "$Label count differs: expected $($Expected.Count), " +
            "observed $($Actual.Count)."
        )
    }
    for ($index = 0; $index -lt $Expected.Count; $index += 1) {
        if ($Expected[$index] -cne $Actual[$index]) {
            Stop-Certification (
                "$Label differs at index ${index}: expected " +
                "'$($Expected[$index])', observed '$($Actual[$index])'."
            )
        }
    }
}


function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$TranscriptName
    )

    $invocation = Invoke-CertificationProcess `
        -Label $Label `
        -FilePath "git" `
        -ArgumentList (@("-C", $script:RepoRoot) + $Arguments) `
        -TranscriptPath (Join-Path $script:SessionRoot $TranscriptName) `
        -TimeoutSeconds 60
    if ($invocation.ExitCode -ne 0) {
        Stop-Certification (
            "$Label returned git exit $($invocation.ExitCode)."
        )
    }
    return $invocation
}


function Get-CleanSourceState {
    param(
        [Parameter(Mandatory = $true)][string]$Stage
    )

    $status = Invoke-Git `
        -Label "SOURCE_${Stage}_STATUS" `
        -Arguments @(
            "status",
            "--porcelain=v1",
            "--untracked-files=all"
        ) `
        -TranscriptName "source_$($Stage.ToLowerInvariant())_status.log"
    $dirtyText = ([string]$status.Stdout).Trim()
    if (-not [string]::IsNullOrWhiteSpace($dirtyText)) {
        $sample = @(
            [regex]::Split($dirtyText, "\r?\n") |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -First 12
        ) -join " | "
        Stop-Certification (
            "BR1 certification requires a clean worktree at $Stage. " +
            "Observed: $sample"
        )
    }

    $revision = Invoke-Git `
        -Label "SOURCE_${Stage}_REVISION" `
        -Arguments @("rev-parse", "--verify", "HEAD") `
        -TranscriptName "source_$($Stage.ToLowerInvariant())_revision.log"
    $commit = ([string]$revision.Stdout).Trim()
    if ($commit -notmatch '^[0-9a-f]{40}$') {
        Stop-Certification (
            "Git returned an invalid commit identity at ${Stage}: $commit"
        )
    }

    $topLevel = Invoke-Git `
        -Label "SOURCE_${Stage}_ROOT" `
        -Arguments @("rev-parse", "--show-toplevel") `
        -TranscriptName "source_$($Stage.ToLowerInvariant())_root.log"
    $reportedRoot = ([string]$topLevel.Stdout).Trim()
    if (-not (Get-NormalizedFullPath -Path $reportedRoot).Equals(
        (Get-NormalizedFullPath -Path $script:RepoRoot),
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        Stop-Certification (
            "Git resolved a different repository root at ${Stage}: " +
            $reportedRoot
        )
    }

    return [ordered]@{
        clean = $true
        commit_sha = $commit
        repository_root = $reportedRoot
        checked_stage = $Stage
    }
}


function Assert-SameCleanSource {
    param(
        [Parameter(Mandatory = $true)][string]$ExpectedCommit,
        [Parameter(Mandatory = $true)][string]$Stage
    )

    $state = Get-CleanSourceState -Stage $Stage
    if ([string]$state.commit_sha -cne $ExpectedCommit) {
        Stop-Certification (
            "Repository commit changed during certification: expected " +
            "$ExpectedCommit, observed $($state.commit_sha) at $Stage."
        )
    }
    return $state
}


function Assert-PinnedInventory {
    param(
        [Parameter(Mandatory = $true)]$Inventory
    )

    $observedInventorySha256 = Get-Sha256 -Path $inventoryPath
    if (
        $Inventory.schema -cne
            "sporespore.lab.br1_required_test_inventory.v2" -or
        $Inventory.inventory_id -cne "BR1_REQUIRED_LAB_TESTS_V2" -or
        [int]$Inventory.inventory_version -ne 2 -or
        $Inventory.pattern -cne "test_lab_*.gd" -or
        $observedInventorySha256 -cne
            $script:ExpectedTestInventorySha256
    ) {
        Stop-Certification (
            "The BR1 test inventory contract or exact pinned bytes changed."
        )
    }
    $expectedTests = @($Inventory.tests | ForEach-Object { [string]$_ })
    if (
        $expectedTests.Count -ne $script:ExpectedTestCount -or
        [int]$Inventory.test_count -ne
            $script:ExpectedTestCount
    ) {
        Stop-Certification (
            "The BR1 test inventory must remain the exact pinned " +
            "$script:ExpectedTestCount-test contract."
        )
    }
    foreach ($name in $expectedTests) {
        if ($name -notmatch '^test_lab_[A-Za-z0-9_]+\.gd$') {
            Stop-Certification (
                "The BR1 test inventory contains an unsafe name: $name"
            )
        }
    }
    # Test order is signed evidence, not presentation. Sort-Object uses the
    # current culture and orders `observer_ab_bundle.gd` before
    # `observer_ab.gd` on this machine, while Godot and the inventory use
    # ordinal code-unit order. Make the comparer explicit and portable.
    [string[]]$actualTests = @(
        Get-ChildItem `
            -LiteralPath (Join-Path $script:RepoRoot "tests") `
            -Filter "test_lab_*.gd" `
            -File |
            ForEach-Object { [string]$_.Name }
    )
    [Array]::Sort($actualTests, [StringComparer]::Ordinal)
    Assert-ExactStringList `
        -Expected $expectedTests `
        -Actual $actualTests `
        -Label "On-disk lab-test inventory"
    return $expectedTests
}


function Assert-TestReport {
    param(
        [Parameter(Mandatory = $true)]$Report,
        [Parameter(Mandatory = $true)][string[]]$ExpectedTests,
        [Parameter(Mandatory = $true)][string]$ExpectedGodot,
        [Parameter(Mandatory = $true)][string]$ExpectedLogRoot,
        [Parameter(Mandatory = $true)][int]$ExpectedTimeoutSeconds
    )

    if (
        $Report.schema -cne "sporespore.lab.test_report.v1" -or
        $Report.pattern -cne "test_lab_*.gd" -or
        [int]$Report.test_timeout_seconds -ne $ExpectedTimeoutSeconds
    ) {
        Stop-Certification "The lab-test report contract is unknown."
    }
    if (-not (Get-NormalizedFullPath -Path ([string]$Report.repository)).Equals(
        (Get-NormalizedFullPath -Path $script:RepoRoot),
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        Stop-Certification "The lab-test report names a different repository."
    }
    if (-not (Get-NormalizedFullPath -Path ([string]$Report.godot)).Equals(
        (Get-NormalizedFullPath -Path $ExpectedGodot),
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        Stop-Certification "The lab-test report names a different Godot binary."
    }

    $rows = @($Report.results)
    $reportedTests = @($rows | ForEach-Object { [string]$_.test })
    Assert-ExactStringList `
        -Expected $ExpectedTests `
        -Actual $reportedTests `
        -Label "Executed lab-test report"
    if (
        [int]$Report.total -ne $ExpectedTests.Count -or
        [int]$Report.passed -ne $ExpectedTests.Count -or
        [int]$Report.failed -ne 0
    ) {
        Stop-Certification (
            "The exact pinned lab-test suite was not a complete pass " +
            "(expected=$($ExpectedTests.Count) total=$($Report.total) " +
            "passed=$($Report.passed) failed=$($Report.failed))."
        )
    }
    foreach ($row in $rows) {
        $testName = [string]$row.test
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($testName)
        $engineLogPath = Get-NormalizedFullPath -Path (
            [string]$row.engine_log
        )
        $transcriptLogPath = Get-NormalizedFullPath -Path (
            [string]$row.transcript_log
        )
        if (
            $row.status -cne "pass" -or
            [int]$row.process_exit_code -ne 0 -or
            $row.timed_out -ne $false -or
            $row.containment_tree_closed -ne $true -or
            $row.exit_marker_observed -ne $true -or
            $row.footer_found -ne $true -or
            [int]$row.footer_count -ne 1 -or
            $null -eq $row.assertions_passed -or
            [int]$row.assertions_passed -le 0 -or
            $null -eq $row.assertions_failed -or
            [int]$row.assertions_failed -ne 0 -or
            @($row.unexpected_engine_errors).Count -ne 0 -or
            @($row.missing_expected_engine_error_codes).Count -ne 0 -or
            @($row.unknown_expected_engine_error_codes).Count -ne 0 -or
            -not [string]::IsNullOrWhiteSpace(
                [string]$row.process_start_error
            ) -or
            -not [string]::IsNullOrWhiteSpace(
                [string]$row.process_termination_error
            ) -or
            $row.engine_log_exists -ne $true -or
            $row.engine_log_readable -ne $true -or
            $row.transcript_log_exists -ne $true -or
            $row.transcript_log_readable -ne $true -or
            [string]$row.engine_log_sha256 -notmatch
                '^sha256:[a-f0-9]{64}$' -or
            [string]$row.transcript_log_sha256 -notmatch
                '^sha256:[a-f0-9]{64}$' -or
            [long]$row.engine_log_bytes -lt 0 -or
            [long]$row.transcript_log_bytes -lt 0 -or
            -not (Test-PathAtOrBelow `
                -Candidate $engineLogPath `
                -Parent $ExpectedLogRoot) -or
            -not (Test-PathAtOrBelow `
                -Candidate $transcriptLogPath `
                -Parent $ExpectedLogRoot) -or
            [System.IO.Path]::GetFileName($engineLogPath) -cne
                "$stem.engine.log" -or
            [System.IO.Path]::GetFileName($transcriptLogPath) -cne
                "$stem.transcript.log" -or
            -not (Test-Path -LiteralPath $engineLogPath -PathType Leaf) -or
            -not (Test-Path `
                -LiteralPath $transcriptLogPath `
                -PathType Leaf) -or
            (Get-Sha256 -Path $engineLogPath) -cne
                [string]$row.engine_log_sha256 -or
            (Get-Sha256 -Path $transcriptLogPath) -cne
                [string]$row.transcript_log_sha256 -or
            [long](Get-Item -LiteralPath $engineLogPath).Length -ne
                [long]$row.engine_log_bytes -or
            [long](Get-Item -LiteralPath $transcriptLogPath).Length -ne
                [long]$row.transcript_log_bytes
        ) {
            Stop-Certification (
                "Pinned test lacks a complete passing witness: $($row.test)"
            )
        }
    }
}


function Read-TestEvidenceWitness {
    param(
        [Parameter(Mandatory = $true)][string]$ReportPath,
        [Parameter(Mandatory = $true)][string[]]$ExpectedTests,
        [Parameter(Mandatory = $true)][string]$ExpectedGodot,
        [Parameter(Mandatory = $true)][string]$ExpectedLogRoot,
        [Parameter(Mandatory = $true)][int]$ExpectedTimeoutSeconds
    )

    if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
        Stop-Certification "Pinned test report disappeared before capture."
    }
    $reportBytes = [System.IO.File]::ReadAllBytes($ReportPath)
    if ($reportBytes.Length -le 0) {
        Stop-Certification "Pinned test report is empty."
    }
    try {
        $strictUtf8 = [System.Text.UTF8Encoding]::new(
            $false,
            $true
        )
        $reportText = $strictUtf8.GetString($reportBytes)
        $report = ConvertFrom-JsonPreservingStrings `
            -Json $reportText `
            -Depth 100
    } catch {
        Stop-Certification (
            "Pinned test report is not strict UTF-8 JSON: " +
            $_.Exception.Message
        )
    }
    Assert-TestReport `
        -Report $report `
        -ExpectedTests $ExpectedTests `
        -ExpectedGodot $ExpectedGodot `
        -ExpectedLogRoot $ExpectedLogRoot `
        -ExpectedTimeoutSeconds $ExpectedTimeoutSeconds

    $artifactPaths = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $artifacts = @()
    foreach ($row in @($report.results)) {
        foreach ($kind in @("engine_log", "transcript_log")) {
            $path = Get-NormalizedFullPath -Path ([string]$row.$kind)
            if (-not $artifactPaths.Add($path)) {
                Stop-Certification (
                    "Pinned test artifacts reuse one path: $path"
                )
            }
            $artifacts += [ordered]@{
                test = [string]$row.test
                kind = $kind
                path = $path
                sha256 = Get-Sha256 -Path $path
                bytes = [long](Get-Item -LiteralPath $path).Length
            }
        }
    }
    if ($artifacts.Count -ne ($script:ExpectedTestCount * 2)) {
        Stop-Certification (
            "Pinned test artifact witness must contain exactly " +
            "$($script:ExpectedTestCount * 2) engine/transcript files."
        )
    }
    return [ordered]@{
        report_object = $report
        report_path = Get-NormalizedFullPath -Path $ReportPath
        report_sha256 = Get-BytesSha256 -Bytes $reportBytes
        report_bytes = [long]$reportBytes.Length
        report_payload_base64 = [System.Convert]::ToBase64String(
            $reportBytes
        )
        artifacts = $artifacts
    }
}


function Assert-TestEvidenceUnchanged {
    param(
        [Parameter(Mandatory = $true)]$Witness,
        [Parameter(Mandatory = $true)][string]$Stage
    )

    if (
        -not (Test-Path `
            -LiteralPath ([string]$Witness.report_path) `
            -PathType Leaf) -or
        (Get-Sha256 -Path ([string]$Witness.report_path)) -cne
            [string]$Witness.report_sha256 -or
        [long](Get-Item -LiteralPath (
            [string]$Witness.report_path
        )).Length -ne [long]$Witness.report_bytes
    ) {
        Stop-Certification (
            "Pinned test report changed or disappeared at $Stage."
        )
    }
    $artifacts = @($Witness.artifacts)
    if ($artifacts.Count -ne ($script:ExpectedTestCount * 2)) {
        Stop-Certification (
            "Pinned test artifact inventory changed at $Stage."
        )
    }
    foreach ($artifact in $artifacts) {
        $path = [string]$artifact.path
        if (
            -not (Test-Path -LiteralPath $path -PathType Leaf) -or
            (Get-Sha256 -Path $path) -cne [string]$artifact.sha256 -or
            [long](Get-Item -LiteralPath $path).Length -ne
                [long]$artifact.bytes
        ) {
            Stop-Certification (
                "Pinned test artifact changed or disappeared at " +
                "${Stage}: $path"
            )
        }
    }
}


function Get-TrustStoreSnapshot {
    param(
        [Parameter(Mandatory = $true)][string]$TrustRoot
    )

    $root = Get-NormalizedFullPath -Path $TrustRoot
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        Stop-Certification "Production trust root is missing: $root"
    }
    Assert-NoReparseAncestor `
        -Path $root `
        -Label "Production trust root"
    $rootAcl = Get-Acl -LiteralPath $root -ErrorAction Stop
    $entries = @([ordered]@{
        path = "."
        kind = "directory"
        bytes = $null
        sha256 = $null
        owner = [string]$rootAcl.Owner
        sddl = $rootAcl.Sddl
        reparse_point = $false
    })
    foreach ($item in @(
        Get-ChildItem -LiteralPath $root -Force -Recurse |
            Sort-Object FullName
    )) {
        $fullPath = Get-NormalizedFullPath -Path $item.FullName
        if (
            (
                $item.Attributes -band
                [System.IO.FileAttributes]::ReparsePoint
            ) -ne 0
        ) {
            Stop-Certification (
                "Production trust store contains a reparse point: " +
                $fullPath
            )
        }
        $relative = [System.IO.Path]::GetRelativePath(
            $root,
            $fullPath
        ).Replace("\", "/")
        $acl = Get-Acl -LiteralPath $fullPath -ErrorAction Stop
        $isDirectory = $item -is [System.IO.DirectoryInfo]
        $entries += [ordered]@{
            path = $relative
            kind = if ($isDirectory) {
                "directory"
            } else {
                "file"
            }
            bytes = if ($isDirectory) {
                $null
            } else {
                [long]$item.Length
            }
            sha256 = if ($isDirectory) {
                $null
            } else {
                Get-Sha256 -Path $fullPath
            }
            owner = [string]$acl.Owner
            sddl = $acl.Sddl
            reparse_point = $false
        }
    }
    $snapshotJson = $entries | ConvertTo-Json -Depth 8 -Compress
    return [ordered]@{
        root = $root
        entry_count = $entries.Count
        sha256 = Get-TextSha256 -Text $snapshotJson
        entries = $entries
    }
}


function Assert-LaunchProcessIdentity {
    param(
        [Parameter(Mandatory = $true)][string]$PhysicsChildGodotPath,
        [Parameter(Mandatory = $true)][string]$BundlePath,
        [Parameter(Mandatory = $true)][string]$ReplicateRoot,
        [Parameter(Mandatory = $true)][string]$ResourcePath,
        [Parameter(Mandatory = $true)][long]$Seed,
        [Parameter(Mandatory = $true)][string]$Observer,
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$ExpectedResourceSha256
    )

    $processPath = Join-Path $BundlePath "process_metadata.json"
    $launchPlanArtifactPath = Join-Path $BundlePath "launch_plan.json"
    $process = Read-JsonObject `
        -Path $processPath `
        -Label "$RunId process metadata"
    $launchPlan = Read-JsonObject `
        -Path $launchPlanArtifactPath `
        -Label "$RunId frozen launch plan"
    $payload = $launchPlan.payload
    $outerParentPid = [long]$process.parent_process_id
    $physicsChildPid = [long]$process.child_process_id
    $terminationObserverPid = [long](
        $process.termination_observer_process_id
    )
    $planParentPid = [long]$payload.parent_process_id
    $reservationId = [string]$process.reservation_id
    $partialPath = [string]$payload.partial_path
    $finalPath = [string]$payload.final_path
    $plannedLaunchPlanPath = Join-Path $partialPath "launch_plan.json"
    $plannedTokenPath = Join-Path $partialPath ".adoption_token"
    $plannedLaunchPlanArgument = $plannedLaunchPlanPath.Replace("\", "/")
    $expectedRequestedArguments = @(
        "--experiment-spec",
        $ResourcePath,
        "--seed",
        $Seed.ToString(
            [System.Globalization.CultureInfo]::InvariantCulture
        ),
        "--observer",
        $Observer,
        "--output-root",
        $ReplicateRoot
    )
    $requestedArguments = @(
        $payload.requested_user_arguments |
            ForEach-Object { [string]$_ }
    )
    Assert-ExactOrderedValues `
        -Expected $expectedRequestedArguments `
        -Actual $requestedArguments `
        -Label "$RunId exact outer requested arguments"

    $processRequestedArguments = @(
        $process.requested_user_arguments |
            ForEach-Object { [string]$_ }
    )
    Assert-ExactOrderedValues `
        -Expected $expectedRequestedArguments `
        -Actual $processRequestedArguments `
        -Label "$RunId process-metadata requested arguments"

    $planEngineArguments = @(
        $payload.engine_arguments |
            ForEach-Object { [string]$_ }
    )
    $processEngineArguments = @(
        $process.engine_arguments |
            ForEach-Object { [string]$_ }
    )
    Assert-ExactOrderedValues `
        -Expected $planEngineArguments `
        -Actual $processEngineArguments `
        -Label "$RunId engine argument witness"

    $expectedChildArguments = @(
        "--child-launch-plan",
        $plannedLaunchPlanArgument
    )
    $planChildArguments = @(
        $payload.user_arguments |
            ForEach-Object { [string]$_ }
    )
    $processChildArguments = @(
        $process.user_arguments |
            ForEach-Object { [string]$_ }
    )
    Assert-ExactOrderedValues `
        -Expected $expectedChildArguments `
        -Actual $planChildArguments `
        -Label "$RunId planned child arguments"
    Assert-ExactOrderedValues `
        -Expected $expectedChildArguments `
        -Actual $processChildArguments `
        -Label "$RunId process-metadata child arguments"

    $expectedExactChildInvocation = @(
        $planEngineArguments +
        @("--") +
        $expectedChildArguments
    )
    $plannedExactInvocation = @(
        $payload.arguments |
            ForEach-Object { [string]$_ }
    )
    $processExactInvocation = @(
        $process.arguments |
            ForEach-Object { [string]$_ }
    )
    Assert-ExactOrderedValues `
        -Expected $expectedExactChildInvocation `
        -Actual $plannedExactInvocation `
        -Label "$RunId frozen exact child invocation"
    Assert-ExactOrderedValues `
        -Expected $expectedExactChildInvocation `
        -Actual $processExactInvocation `
        -Label "$RunId observed exact child invocation"

    $engineScriptIndex = [Array]::IndexOf(
        [object[]]$planEngineArguments,
        "--script"
    )
    $enginePathIndex = [Array]::IndexOf(
        [object[]]$planEngineArguments,
        "--path"
    )
    $engineLogIndex = [Array]::IndexOf(
        [object[]]$planEngineArguments,
        "--log-file"
    )
    if (
        $planEngineArguments.Count -ne 7 -or
        $planEngineArguments[0] -cne "--headless" -or
        $enginePathIndex -ne 1 -or
        $engineLogIndex -ne 3 -or
        $engineScriptIndex -ne 5 -or
        $planEngineArguments[6] -cne
            "res://scripts/lab/run_lab.gd"
    ) {
        Stop-Certification (
            "$RunId child engine arguments do not match the canonical " +
            "headless run_lab launch shape."
        )
    }
    if (-not (Get-NormalizedFullPath -Path (
        $planEngineArguments[2]
    )).Equals(
        (Get-NormalizedFullPath -Path $script:RepoRoot),
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        Stop-Certification "$RunId child --path names another repository."
    }
    $expectedPlannedEngineLog = Join-Path $partialPath "engine.log"
    if (-not (Get-NormalizedFullPath -Path (
        $planEngineArguments[4]
    )).Equals(
        (Get-NormalizedFullPath -Path $expectedPlannedEngineLog),
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        Stop-Certification (
            "$RunId child --log-file differs from its reserved bundle path."
        )
    }

    $actualLaunchPlanSha256 = Get-Sha256 -Path $launchPlanArtifactPath
    if (
        $process.schema -cne
            "sporespore.lab.process_metadata.v1" -or
        $process.run_id -cne $RunId -or
        $process.status -cne "COMPLETE" -or
        [int]$process.exit_code -ne 0 -or
        $process.exit_disposition -cne
            "candidate_ready_parent_observed" -or
        $process.argument_capture_quality -cne "launcher_exact" -or
        $outerParentPid -le 0 -or
        $physicsChildPid -le 0 -or
        $outerParentPid -eq $physicsChildPid -or
        $terminationObserverPid -ne $outerParentPid -or
        $planParentPid -ne $outerParentPid -or
        $RunId -notmatch (
            "_pid-" + [regex]::Escape(
                $outerParentPid.ToString(
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
            ) + "_"
        ) -or
        $reservationId -notmatch '^[a-f0-9]{32}$' -or
        $launchPlan.schema -cne
            "sporespore.lab.launch_plan.v1" -or
        $launchPlan.status -cne "FROZEN" -or
        $launchPlan.run_id -cne $RunId -or
        $launchPlan.reservation_id -cne $reservationId -or
        $payload.run_id -cne $RunId -or
        $payload.reservation_id -cne $reservationId -or
        $process.launch_plan_sha256 -cne
            $actualLaunchPlanSha256 -or
        $process.launch_plan_payload_sha256 -cne
            $launchPlan.payload_sha256 -or
        $process.adoption_token_sha256 -cne
            $payload.adoption_token_sha256 -or
        $process.started_utc -cne $payload.created_utc -or
        -not (Get-NormalizedFullPath -Path (
            [string]$process.executable
        )).Equals(
            (Get-NormalizedFullPath -Path $PhysicsChildGodotPath),
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        -not (Get-NormalizedFullPath -Path (
            [string]$payload.executable
        )).Equals(
            (Get-NormalizedFullPath -Path $PhysicsChildGodotPath),
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        -not (Get-NormalizedFullPath -Path (
            [string]$process.working_directory
        )).Equals(
            (Get-NormalizedFullPath -Path $script:RepoRoot),
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        -not (Get-NormalizedFullPath -Path (
            [string]$payload.working_directory
        )).Equals(
            (Get-NormalizedFullPath -Path $script:RepoRoot),
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        -not (Get-NormalizedFullPath -Path $finalPath).Equals(
            (Get-NormalizedFullPath -Path $BundlePath),
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        -not (Get-NormalizedFullPath -Path (
            [string]$process.partial_path
        )).Equals(
            (Get-NormalizedFullPath -Path $partialPath),
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        -not (Get-NormalizedFullPath -Path (
            Split-Path -Parent $partialPath
        )).Equals(
            (Get-NormalizedFullPath -Path $ReplicateRoot),
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        (Split-Path -Leaf $partialPath) -cne "$RunId.partial" -or
        -not (Get-NormalizedFullPath -Path (
            [string]$process.final_path
        )).Equals(
            (Get-NormalizedFullPath -Path $BundlePath),
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        -not (Get-NormalizedFullPath -Path (
            [string]$payload.output_root
        )).Equals(
            (Get-NormalizedFullPath -Path $ReplicateRoot),
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        -not (Get-NormalizedFullPath -Path (
            [string]$process.launch_plan_path
        )).Equals(
            (Get-NormalizedFullPath -Path $plannedLaunchPlanPath),
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        -not (Get-NormalizedFullPath -Path (
            [string]$payload.token_descriptor_path
        )).Equals(
            (Get-NormalizedFullPath -Path $plannedTokenPath),
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        $payload.experiment_identity.resource_path -cne
            $ResourcePath -or
        [long]$payload.experiment_identity.root_seed -ne $Seed -or
        $payload.experiment_identity.observer_profile_id -cne
            $Observer -or
        $payload.experiment_identity.resource_sha256 -cne
            $ExpectedResourceSha256
    ) {
        Stop-Certification (
            "$RunId process/launch-plan identity is incomplete or " +
            "inconsistent with the exact formal invocation."
        )
    }
    return [ordered]@{
        outer_parent_process_id = $outerParentPid
        physics_child_process_id = $physicsChildPid
        termination_observer_process_id = $terminationObserverPid
        reservation_id = $reservationId
        process_metadata_sha256 = Get-Sha256 -Path $processPath
        launch_plan_sha256 = $actualLaunchPlanSha256
        launch_plan_payload_sha256 = [string](
            $launchPlan.payload_sha256
        )
        started_utc = [string]$process.started_utc
        ended_utc = [string]$process.ended_utc
        executable = [string]$process.executable
        argument_capture_quality = "launcher_exact"
        exact_argument_match = $true
        run_id_parent_pid_binding = $true
    }
}


function Assert-CampaignContract {
    param(
        [Parameter(Mandatory = $true)]$Campaign
    )

    if (
        $Campaign.schema -cne
            "sporespore.lab.br1_l0_certification_campaign.v1" -or
        $Campaign.campaign_id -cne "BR1_L0_CERTIFICATION_V1" -or
        [int]$Campaign.campaign_version -ne 1 -or
        [int]$Campaign.cell_count -ne 7 -or
        $Campaign.resource_patch_policy -cne "forbidden" -or
        $Campaign.process_policy.fresh_process_per_replicate -ne $true -or
        $Campaign.process_policy.replicate_isolation -cne
            "one_physics_run_per_os_process" -or
        [int]$Campaign.process_policy.required_replicates_per_cell -ne 2
    ) {
        Stop-Certification "The BR1 campaign contract is unknown or weakened."
    }
    $cells = @($Campaign.cells)
    if ($cells.Count -ne 7) {
        Stop-Certification (
            "The BR1 campaign must contain exactly seven cells."
        )
    }
    # This operator and campaign version are one immutable contract. Merely
    # preserving a seven-cell shape is insufficient: without exact identities,
    # a clean commit could silently replace the 30/60/120 Hz and observer-A/B
    # matrix with seven easier experiments while retaining all outer counts.
    $expectedCells = @(
        [ordered]@{
            cell_id = "BR1_L0_0_STATIONARY_60HZ_V1"
            resource_path = (
                "res://data/lab/experiments/br1/" +
                "BR1_L0_0_stationary_60hz_v1.tres"
            )
            comparison_profiles = @()
        },
        [ordered]@{
            cell_id = "BR1_L0_1_FREE_FALL_30HZ_V1"
            resource_path = (
                "res://data/lab/experiments/br1/" +
                "BR1_L0_1_free_fall_30hz_v1.tres"
            )
            comparison_profiles = @()
        },
        [ordered]@{
            cell_id = "BR1_L0_1_FREE_FALL_60HZ_V1"
            resource_path = (
                "res://data/lab/experiments/br1/" +
                "BR1_L0_1_free_fall_60hz_v1.tres"
            )
            comparison_profiles = @()
        },
        [ordered]@{
            cell_id = "BR1_L0_1_FREE_FALL_120HZ_V1"
            resource_path = (
                "res://data/lab/experiments/br1/" +
                "BR1_L0_1_free_fall_120hz_v1.tres"
            )
            comparison_profiles = @()
        },
        [ordered]@{
            cell_id = "BR1_L0_2_BALLISTIC_GRAVITY_OFF_60HZ_V1"
            resource_path = (
                "res://data/lab/experiments/br1/" +
                "BR1_L0_2_ballistic_gravity_off_60hz_v1.tres"
            )
            comparison_profiles = @()
        },
        [ordered]@{
            cell_id = "BR1_L0_2_BALLISTIC_GRAVITY_ON_60HZ_V1"
            resource_path = (
                "res://data/lab/experiments/br1/" +
                "BR1_L0_2_ballistic_gravity_on_60hz_v1.tres"
            )
            comparison_profiles = @()
        },
        [ordered]@{
            cell_id = "BR1_L0_3_OBSERVER_AB_60HZ_V1"
            resource_path = (
                "res://data/lab/experiments/br1/" +
                "BR1_L0_3_observer_ab_60hz_v1.tres"
            )
            comparison_profiles = @(
                "minimal_state_v1",
                "full_state_v1",
                "full_contacts_v1"
            )
        }
    )
    $cellIds = @()
    $resourcePaths = @()
    $br1ExperimentRoot = Join-Path (
        $script:RepoRoot
    ) "data\lab\experiments\br1"
    for ($cellIndex = 0; $cellIndex -lt $cells.Count; $cellIndex += 1) {
        $cell = $cells[$cellIndex]
        $expectedCell = $expectedCells[$cellIndex]
        $cellId = [string]$cell.cell_id
        $resourcePath = [string]$cell.resource_path
        if (
            $cellId -cne [string]$expectedCell.cell_id -or
            $resourcePath -cne [string]$expectedCell.resource_path -or
            $cellId -notmatch '^[A-Z][A-Z0-9_]{1,127}$' -or
            $resourcePath -notmatch
                '^res://data/lab/experiments/br1/[A-Za-z0-9_]+\.tres$' -or
            [int]$cell.repeat_count -ne 2 -or
            $cell.replay_required -ne $true -or
            $cell.seed_policy.kind -cne
                "fixed_same_seed_fresh_process" -or
            [long]$cell.seed_policy.root_seed -ne 42 -or
            $cell.observer.adapter_id -cne
                "rigid_body_integrate_forces_v1" -or
            $cell.observer.primary_profile_id -cne "full_contacts_v1"
        ) {
            Stop-Certification (
                "BR1 campaign cell at ordered index $cellIndex is " +
                "malformed, substituted, or weakened: $cellId"
            )
        }
        $actualComparisonProfiles = @(
            $cell.observer.comparison_profile_ids |
                ForEach-Object { [string]$_ }
        )
        Assert-ExactStringList `
            -Expected @($expectedCell.comparison_profiles) `
            -Actual $actualComparisonProfiles `
            -Label "$cellId observer comparison-profile list"
        $resourceRelative = $resourcePath.Substring(6).Replace(
            "/",
            [System.IO.Path]::DirectorySeparatorChar
        )
        $resourceAbsolute = Get-NormalizedFullPath -Path (
            Join-Path $script:RepoRoot $resourceRelative
        )
        if (
            -not (Test-PathAtOrBelow `
                -Candidate $resourceAbsolute `
                -Parent $br1ExperimentRoot) -or
            -not (Test-Path -LiteralPath $resourceAbsolute -PathType Leaf)
        ) {
            Stop-Certification (
                "BR1 campaign resource is missing or outside its fixed " +
                "directory: $resourcePath"
            )
        }
        $cellIds += $cellId
        $resourcePaths += $resourcePath
    }
    if (
        @($cellIds | Sort-Object -Unique).Count -ne 7 -or
        @($resourcePaths | Sort-Object -Unique).Count -ne 7
    ) {
        Stop-Certification (
            "BR1 campaign cell IDs and resource paths must each be unique."
        )
    }
    return $cells
}


function Invoke-BundleValidation {
    param(
        [Parameter(Mandatory = $true)][string]$GodotPath,
        [Parameter(Mandatory = $true)][string]$BundlePath,
        [Parameter(Mandatory = $true)][string]$LabelStem,
        [Parameter(Mandatory = $true)][string]$LogDirectory
    )

    $engineLog = Join-Path $LogDirectory "$LabelStem.validator.engine.log"
    $transcript = Join-Path (
        $LogDirectory
    ) "$LabelStem.validator.transcript.log"
    $invocation = Invoke-CertificationProcess `
        -Label "$($LabelStem.ToUpperInvariant())_VALIDATE" `
        -FilePath $GodotPath `
        -ArgumentList @(
            "--headless",
            "--path",
            $script:RepoRoot,
            "--log-file",
            $engineLog,
            "--script",
            "res://scripts/lab/validate_bundle_cli.gd",
            "--",
            "--bundle",
            $BundlePath,
            "--require-attestation",
            "--require-promotion"
        ) `
        -TranscriptPath $transcript `
        -TimeoutSeconds $StepTimeoutSeconds
    Assert-GodotInvocationClean `
        -Invocation $invocation `
        -EngineLogPath $engineLog `
        -Label "$LabelStem independent bundle validation"
    if ($invocation.ExitCode -ne 0) {
        Stop-Certification (
            "$LabelStem independent bundle validation returned exit " +
            "$($invocation.ExitCode)."
        )
    }
    [void](Get-SingleMatch `
        -Lines @($invocation.Lines) `
        -Pattern (
            '^BUNDLE_VALIDATION verdict=pass can_promote=true\s*$'
        ) `
        -Label "$LabelStem promotion verdict")
    $resultMatch = Get-SingleMatch `
        -Lines @($invocation.Lines) `
        -Pattern '^BUNDLE_VALIDATION result=(\{.*\})\s*$' `
        -Label "$LabelStem validator result"
    $resultJson = $resultMatch.Groups[1].Value
    try {
        $result = ConvertFrom-JsonPreservingStrings `
            -Json $resultJson `
            -Depth 100
    } catch {
        Stop-Certification (
            "$LabelStem validator emitted invalid result JSON: " +
            $_.Exception.Message
        )
    }
    $publicationAttestation = $result.stats.publication_attestation
    if (
        $result.ok -ne $true -or
        $result.can_finalize -ne $true -or
        $result.can_promote -ne $true -or
        @($result.errors).Count -ne 0 -or
        $publicationAttestation.ok -ne $true -or
        $publicationAttestation.trust_mode -cne "production" -or
        $publicationAttestation.key_id -notmatch
            '^sha256:[a-f0-9]{64}$' -or
        $publicationAttestation.receipt_sha256 -notmatch
            '^sha256:[a-f0-9]{64}$' -or
        [string]::IsNullOrWhiteSpace(
            [string]$publicationAttestation.receipt_path
        ) -or
        [string]::IsNullOrWhiteSpace(
            [string]$publicationAttestation.run_id
        )
    ) {
        Stop-Certification (
            "$LabelStem validator JSON contradicts its passing verdict."
        )
    }
    return [ordered]@{
        can_finalize = $true
        can_promote = $true
        result_sha256 = Get-TextSha256 -Text $resultJson
        publication_attestation = [ordered]@{
            valid = $true
            trust_mode = "production"
            key_id = [string]$publicationAttestation.key_id
            receipt_path = [string]$publicationAttestation.receipt_path
            receipt_sha256 = [string](
                $publicationAttestation.receipt_sha256
            )
            run_id = [string]$publicationAttestation.run_id
            attested_utc = [string](
                $publicationAttestation.attested_utc
            )
        }
        engine_log = $engineLog
        transcript = $transcript
    }
}


function Get-TextSha256 {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text
    )

    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Text)
    try {
        return "sha256:$(
            [System.Convert]::ToHexString(
                [System.Security.Cryptography.SHA256]::HashData($bytes)
            ).ToLowerInvariant()
        )"
    } finally {
        [System.Security.Cryptography.CryptographicOperations]::ZeroMemory(
            $bytes
        )
    }
}


function Invoke-TraceReplay {
    param(
        [Parameter(Mandatory = $true)][string]$GodotPath,
        [Parameter(Mandatory = $true)][string]$BundlePath,
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$LabelStem,
        [Parameter(Mandatory = $true)][string]$LogDirectory
    )

    $engineLog = Join-Path $LogDirectory "$LabelStem.replay.engine.log"
    $transcript = Join-Path (
        $LogDirectory
    ) "$LabelStem.replay.transcript.log"
    $invocation = Invoke-CertificationProcess `
        -Label "$($LabelStem.ToUpperInvariant())_REPLAY" `
        -FilePath $GodotPath `
        -ArgumentList @(
            "--headless",
            "--path",
            $script:RepoRoot,
            "--log-file",
            $engineLog,
            "--script",
            "res://scripts/lab/run_lab.gd",
            "--",
            "--experiment-spec",
            $replaySpec,
            "--replay-bundle",
            $BundlePath
        ) `
        -TranscriptPath $transcript `
        -TimeoutSeconds $StepTimeoutSeconds
    Assert-GodotInvocationClean `
        -Invocation $invocation `
        -EngineLogPath $engineLog `
        -Label "$LabelStem L0.4 replay"
    if ($invocation.ExitCode -ne 0) {
        Stop-Certification (
            "$LabelStem L0.4 replay returned exit " +
            "$($invocation.ExitCode)."
        )
    }
    $marker = Get-SingleMatch `
        -Lines @($invocation.Lines) `
        -Pattern (
            '^LAB replay=pass simulation_steps=0 run_id=' +
            [regex]::Escape($RunId) +
            ' frames=(\d+) events=(\d+)\s*$'
        ) `
        -Label "$LabelStem L0.4 replay witness"
    $frames = [int]$marker.Groups[1].Value
    $events = [int]$marker.Groups[2].Value
    if ($frames -le 0 -or $events -lt 0) {
        Stop-Certification (
            "$LabelStem L0.4 replay reported invalid record counts."
        )
    }
    return [ordered]@{
        pass = $true
        simulation_steps = 0
        frames = $frames
        events = $events
        production_attestation_required = $true
        engine_log = $engineLog
        transcript = $transcript
    }
}


function Invoke-ReplicateComparison {
    param(
        [Parameter(Mandatory = $true)][string]$GodotPath,
        [Parameter(Mandatory = $true)][string]$CellId,
        [Parameter(Mandatory = $true)][string]$LeftBundle,
        [Parameter(Mandatory = $true)][string]$RightBundle,
        [Parameter(Mandatory = $true)][string]$LogDirectory,
        [ValidatePattern('^[a-z][a-z0-9_]{0,31}$')]
        [string]$Phase = "initial"
    )

    if (-not (Test-Path -LiteralPath $comparatorCliPath -PathType Leaf)) {
        Stop-Certification (
            "The required BR1 replicate-comparator CLI is absent: " +
            $comparatorCliPath
        )
    }
    $engineLog = Join-Path (
        $LogDirectory
    ) "$Phase.replicate_compare.engine.log"
    $transcript = Join-Path (
        $LogDirectory
    ) "$Phase.replicate_compare.transcript.log"
    $invocation = Invoke-CertificationProcess `
        -Label "$($CellId)_$($Phase.ToUpperInvariant())_REPLICATE_COMPARE" `
        -FilePath $GodotPath `
        -ArgumentList @(
            "--headless",
            "--path",
            $script:RepoRoot,
            "--log-file",
            $engineLog,
            "--script",
            "res://scripts/lab/l0_replicate_comparator_cli.gd",
            "--",
            "--left-bundle",
            $LeftBundle,
            "--right-bundle",
            $RightBundle,
            "--require-attestation",
            "--require-promotion"
        ) `
        -TranscriptPath $transcript `
        -TimeoutSeconds $StepTimeoutSeconds
    Assert-GodotInvocationClean `
        -Invocation $invocation `
        -EngineLogPath $engineLog `
        -Label "$CellId replicate comparison"
    if ($invocation.ExitCode -ne 0) {
        Stop-Certification (
            "$CellId replicate comparison returned exit " +
            "$($invocation.ExitCode)."
        )
    }
    [void](Get-SingleMatch `
        -Lines @($invocation.Lines) `
        -Pattern '^REPLICATE_COMPARISON verdict=pass\s*$' `
        -Label "$CellId replicate-comparison verdict")
    $resultMatch = Get-SingleMatch `
        -Lines @($invocation.Lines) `
        -Pattern '^REPLICATE_COMPARISON result=(\{.*\})\s*$' `
        -Label "$CellId replicate-comparison result"
    $resultJson = $resultMatch.Groups[1].Value
    try {
        $result = ConvertFrom-JsonPreservingStrings `
            -Json $resultJson `
            -Depth 100
    } catch {
        Stop-Certification (
            "$CellId comparator emitted invalid JSON: " +
            $_.Exception.Message
        )
    }
    if (
        $result.ok -ne $true -or
        $result.comparator_id -cne
            "sporespore.lab.br1_l0_replicate_comparator.v1" -or
        [int]$result.mismatch_count -ne 0 -or
        $result.fresh_process_proof.ok -ne $true -or
        $result.left_validation.can_promote -ne $true -or
        $result.right_validation.can_promote -ne $true -or
        $result.production_attestation.pass -ne $true -or
        $result.cli_policy.attestation_requirement -cne "required" -or
        $result.cli_policy.attestation_trust_mode -cne "production" -or
        $result.cli_policy.promotion_pass -ne $true -or
        [string]::IsNullOrWhiteSpace(
            [string]$result.left_evidence_digest
        ) -or
        $result.left_evidence_digest -cne
            $result.right_evidence_digest
    ) {
        Stop-Certification (
            "$CellId comparator JSON contradicts its passing verdict."
        )
    }
    return [ordered]@{
        pass = $true
        comparator_id = [string]$result.comparator_id
        mismatch_count = 0
        production_attestation_required = $true
        left_evidence_digest = $result.left_evidence_digest
        right_evidence_digest = $result.right_evidence_digest
        result_sha256 = Get-TextSha256 -Text $resultJson
        engine_log = $engineLog
        transcript = $transcript
    }
}


function Invoke-ReportAttestation {
    param(
        [Parameter(Mandatory = $true)][string]$GodotPath,
        [Parameter(Mandatory = $true)]
        [ValidateSet("attest", "verify")]
        [string]$Mode,
        [Parameter(Mandatory = $true)][string]$ReportPath,
        [Parameter(Mandatory = $true)][string]$ReportSha256,
        [Parameter(Mandatory = $true)][string]$CertificationId,
        [Parameter(Mandatory = $true)][string]$ExpectedKeyId,
        [Parameter(Mandatory = $true)][string]$ExpectedCommitSha,
        [Parameter(Mandatory = $true)][string]$ExpectedCampaignSha256,
        [Parameter(Mandatory = $true)][string]$ProductionTrustRoot,
        [Parameter(Mandatory = $true)][string]$LogDirectory
    )

    if (
        $null -eq $script:ReportAttestationContract -or
        -not (Test-Path `
            -LiteralPath $reportAttestationCliPath `
            -PathType Leaf)
    ) {
        Stop-Certification (
            "The pinned detached certification-report attestation boundary " +
            "is unavailable."
        )
    }
    if ($CertificationId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,159}$') {
        Stop-Certification (
            "Certification report attestation ID is unsafe: " +
            $CertificationId
        )
    }
    $engineLog = Join-Path (
        $LogDirectory
    ) "report_attestation.$Mode.engine.log"
    $transcript = Join-Path (
        $LogDirectory
    ) "report_attestation.$Mode.transcript.log"
    $invocation = Invoke-CertificationProcess `
        -Label "REPORT_ATTESTATION_$($Mode.ToUpperInvariant())" `
        -FilePath $GodotPath `
        -ArgumentList @(
            "--headless",
            "--path",
            $script:RepoRoot,
            "--log-file",
            $engineLog,
            "--script",
            [string]$script:ReportAttestationContract.cli_resource,
            "--",
            "--mode",
            $Mode,
            "--report",
            $ReportPath,
            "--certification-id",
            $CertificationId,
            "--require-promotion"
        ) `
        -TranscriptPath $transcript `
        -TimeoutSeconds $StepTimeoutSeconds
    Assert-GodotInvocationClean `
        -Invocation $invocation `
        -EngineLogPath $engineLog `
        -Label "Detached report attestation $Mode"
    if (
        $invocation.ExitCode -ne
            [int]$script:ReportAttestationContract.exit_pass
    ) {
        Stop-Certification (
            "Detached report attestation $Mode returned exit " +
            "$($invocation.ExitCode); production promotion requires exit 0."
        )
    }
    [void](Get-SingleMatch `
        -Lines @($invocation.Lines) `
        -Pattern (
            '^BR1_REPORT_ATTESTATION verdict=pass mode=' +
            [regex]::Escape($Mode) +
            ' trust_mode=production can_promote=true\s*$'
        ) `
        -Label "Detached report-attestation $Mode verdict")
    $resultMatch = Get-SingleMatch `
        -Lines @($invocation.Lines) `
        -Pattern '^BR1_REPORT_ATTESTATION result=(\{.*\})\s*$' `
        -Label "Detached report-attestation $Mode result"
    $resultJson = $resultMatch.Groups[1].Value
    try {
        $result = ConvertFrom-JsonPreservingStrings `
            -Json $resultJson `
            -Depth 100
    } catch {
        Stop-Certification (
            "Detached report attestation $Mode emitted invalid result JSON: " +
            $_.Exception.Message
        )
    }
    $expectedReceiptRoot = Join-Path (
        $ProductionTrustRoot
    ) "certification_reports_v2\receipts"
    if (
        $result.ok -ne $true -or
        -not [string]::IsNullOrWhiteSpace([string]$result.code) -or
        -not [string]::IsNullOrWhiteSpace(
            [string]$result.failure_code
        ) -or
        $result.algorithm -cne
            [string]$script:ReportAttestationContract.algorithm -or
        $result.trust_mode -cne "production" -or
        $result.can_promote -ne $true -or
        $result.key_id -cne $ExpectedKeyId -or
        $result.certification_id -cne $CertificationId -or
        $result.report_sha256 -cne $ReportSha256 -or
        $result.report_schema -cne
            "sporespore.lab.br1_certification_report.v2" -or
        $result.certification_contract_id -cne
            "BR1_L0_V2_CURRENT_I62" -or
        $result.legacy_verification_only -ne $false -or
        $result.report_status -cne "pass" -or
        $result.certification -cne "BR1_L0_EVIDENCE_PIPELINE" -or
        $result.commit_sha -cne $ExpectedCommitSha -or
        $result.campaign_id -cne "BR1_L0_CERTIFICATION_V1" -or
        $result.campaign_sha256 -cne $ExpectedCampaignSha256 -or
        [long]$result.report_bytes -ne
            [long](Get-Item -LiteralPath $ReportPath).Length -or
        -not (Get-NormalizedFullPath -Path (
            [string]$result.report_path
        )).Equals(
            (Get-NormalizedFullPath -Path $ReportPath),
            [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        -not (Test-Path `
            -LiteralPath ([string]$result.receipt_path) `
            -PathType Leaf) -or
        -not (Test-PathAtOrBelow `
            -Candidate ([string]$result.receipt_path) `
            -Parent $expectedReceiptRoot) -or
        $result.receipt_sha256 -cne
            (Get-Sha256 -Path ([string]$result.receipt_path))
    ) {
        Stop-Certification (
            "Detached report attestation $Mode result contradicts the " +
            "serialized report, production trust identity, or receipt bytes."
        )
    }
    return [ordered]@{
        pass = $true
        mode = $Mode
        trust_mode = "production"
        can_promote = $true
        algorithm = [string]$result.algorithm
        key_id = [string]$result.key_id
        certification_id = [string]$result.certification_id
        report_path = [string]$result.report_path
        report_sha256 = [string]$result.report_sha256
        report_bytes = [long]$result.report_bytes
        receipt_path = [string]$result.receipt_path
        receipt_sha256 = [string]$result.receipt_sha256
        attested_utc = [string]$result.attested_utc
        result_sha256 = Get-TextSha256 -Text $resultJson
        engine_log = $engineLog
        transcript = $transcript
    }
}


try {
    Write-Host (
        "BR1 step=JSON_SCALAR_PRESERVATION_SELF_TEST state=started"
    )
    Assert-JsonScalarPreservation
    Write-Host (
        "JSON_SCALAR_PRESERVATION_SELF_TEST pass=true " +
        "rfc3339_values_remain_strings=true"
    )
    Write-Host (
        "BR1 step=JSON_SCALAR_PRESERVATION_SELF_TEST state=finished " +
        "native_exit=0 timed_out=False"
    )

    foreach ($requiredFile in @(
        $processRunnerPath,
        $processRunnerContainmentHostPath,
        $processRunnerTestPath,
        $testHarnessPath,
        $attestationInitializerPath,
        $attestationInitializerTestPath,
        $campaignPath,
        $inventoryPath,
        $comparatorCliPath,
        $reportAttestationCliPath,
        (Join-Path $script:RepoRoot "scripts\lab\launch_lab.gd"),
        (Join-Path $script:RepoRoot "scripts\lab\validate_bundle_cli.gd"),
        (Join-Path $script:RepoRoot "scripts\lab\run_lab.gd"),
        (Join-Path (
            $script:RepoRoot
        ) "data\lab\experiments\L0_4_trace_playback_v1.tres")
    )) {
        if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
            Stop-Certification (
                "Required BR1 certification input is missing: $requiredFile"
            )
        }
    }
    if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
        Stop-Certification "Godot executable is missing: $Godot"
    }
    if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        Stop-Certification (
            "LOCALAPPDATA is unavailable; specify an external durable " +
            "-OutputRoot explicitly."
        )
    }

    $godotPath = Get-NormalizedFullPath -Path $Godot
    $physicsChildGodotPath = Get-NormalizedFullPath -Path (
        Join-Path (
            Split-Path -Parent $godotPath
        ) $script:ExpectedPhysicsChildExecutableName
    )
    $outputRootPath = Get-NormalizedFullPath -Path $OutputRoot
    $productionTrustRoot = Get-NormalizedFullPath -Path (
        Join-Path $env:LOCALAPPDATA "SporeSpore\LabTrust\v1"
    )
    if (
        (Test-PathAtOrBelow `
            -Candidate $outputRootPath `
            -Parent $script:RepoRoot) -or
        (Test-PathAtOrBelow `
            -Candidate $script:RepoRoot `
            -Parent $outputRootPath)
    ) {
        Stop-Certification (
            "Certification evidence output must be isolated from the " +
            "repository tree."
        )
    }
    if (
        (Test-PathAtOrBelow `
            -Candidate $outputRootPath `
            -Parent $productionTrustRoot) -or
        (Test-PathAtOrBelow `
            -Candidate $productionTrustRoot `
            -Parent $outputRootPath)
    ) {
        Stop-Certification (
            "Certification evidence output must be isolated from the " +
            "production trust store."
        )
    }
    Assert-NoReparseAncestor `
        -Path $outputRootPath `
        -Label "Certification output root"
    [void][System.IO.Directory]::CreateDirectory($outputRootPath)
    Assert-NoReparseAncestor `
        -Path $outputRootPath `
        -Label "Certification output root"
    $sessionName = (
        "br1_" +
        (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ") +
        "_" +
        [guid]::NewGuid().ToString("N").Substring(0, 8)
    )
    $script:SessionRoot = Join-Path $outputRootPath $sessionName
    if (Test-Path -LiteralPath $script:SessionRoot) {
        Stop-Certification (
            "Certification session path unexpectedly already exists: " +
            $script:SessionRoot
        )
    }
    [void][System.IO.Directory]::CreateDirectory($script:SessionRoot)
    Assert-NoReparseAncestor `
        -Path $script:SessionRoot `
        -Label "Certification session root"
    $script:ReportPath = Join-Path (
        $script:SessionRoot
    ) "br1_certification_report.json"
    $script:FailureReportPath = Join-Path (
        $script:SessionRoot
    ) "br1_certification_failure.json"

    . $processRunnerPath

    # This is the first stateful certification gate. No trust initialization,
    # test, simulation, validation, replay, or comparison happens before it.
    $initialSource = Get-CleanSourceState -Stage "INITIAL"
    $commitSha = [string]$initialSource.commit_sha

    $inventory = Read-JsonObject `
        -Path $inventoryPath `
        -Label "Pinned BR1 test inventory"
    $expectedTests = @(
        Assert-PinnedInventory -Inventory $inventory
    )
    $campaign = Read-JsonObject `
        -Path $campaignPath `
        -Label "Fixed BR1 certification campaign"
    $cells = @(Assert-CampaignContract -Campaign $campaign)

    $powerShellExecutable = (Get-Process -Id $PID).Path
    if ([string]::IsNullOrWhiteSpace($powerShellExecutable)) {
        Stop-Certification "Could not resolve the active PowerShell 7 binary."
    }

    $initialGodotIdentity = Assert-GodotBinaryIdentity `
        -GodotPath $godotPath `
        -Stage "INITIAL"
    $initialPhysicsChildIdentity = Assert-PhysicsChildBinaryIdentity `
        -GodotPath $physicsChildGodotPath `
        -Stage "INITIAL"
    $godotVersionInvocation = Invoke-CertificationProcess `
        -Label "GODOT_VERSION" `
        -FilePath $godotPath `
        -ArgumentList @("--version") `
        -TranscriptPath (Join-Path (
            $script:SessionRoot
        ) "godot_version.transcript.log") `
        -TimeoutSeconds 30
    if ($godotVersionInvocation.ExitCode -ne 0) {
        Stop-Certification (
            "Godot --version returned exit " +
            "$($godotVersionInvocation.ExitCode)."
        )
    }
    $godotVersion = ([string]$godotVersionInvocation.Stdout).Trim()
    if (
        $godotVersion -cne $script:ExpectedGodotVersion -or
        $godotVersion -match "\r|\n"
    ) {
        Stop-Certification (
            "Godot --version does not match the pinned BR1 build: " +
            "expected '$script:ExpectedGodotVersion', observed " +
            "'$godotVersion'."
        )
    }

    $processSelfTestRoot = Join-Path (
        $script:SessionRoot
    ) "process_runner_self_test"
    $processSelfTestTranscript = Join-Path (
        $script:SessionRoot
    ) "process_runner_self_test.transcript.log"
    $processSelfTest = Invoke-CertificationProcess `
        -Label "PROCESS_RUNNER_SELF_TEST" `
        -FilePath $powerShellExecutable `
        -ArgumentList @(
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            $processRunnerTestPath,
            "-ScratchRoot",
            $processSelfTestRoot
        ) `
        -TranscriptPath $processSelfTestTranscript `
        -TimeoutSeconds 30
    if ($processSelfTest.ExitCode -ne 0) {
        Stop-Certification (
            "The bounded-process-runner self-test returned exit " +
            "$($processSelfTest.ExitCode)."
        )
    }
    [void](Get-SingleMatch `
        -Lines @($processSelfTest.Lines) `
        -Pattern (
            '^PROCESS_RUNNER_SELF_TEST pass=true success_exit=0 ' +
            'timeout_detected=True process_tree_killed=True\s*$'
        ) `
        -Label "Bounded-process-runner success witness")
    [void](Get-SingleMatch `
        -Lines @($processSelfTest.Lines) `
        -Pattern (
            '^PROCESS_RUNNER_SELF_TEST nonzero_exit=37 ' +
            'inherited_descendant_terminated=True ' +
            'containment_tree_closed=True\s*$'
        ) `
        -Label "Bounded-process-runner containment witness")
    $processSelfTestWitness = [ordered]@{
        pass = $true
        success_exit = 0
        nonzero_exit = 37
        timeout_detected = $true
        process_tree_killed = $true
        inherited_descendant_terminated = $true
        containment_tree_closed = $true
        transcript_path = $processSelfTestTranscript
        transcript_sha256 = Get-Sha256 -Path $processSelfTestTranscript
    }

    $initializerSelfTestTranscript = Join-Path (
        $script:SessionRoot
    ) "attestation_initializer_self_test.transcript.log"
    $initializerSelfTest = Invoke-CertificationProcess `
        -Label "ATTESTATION_INITIALIZER_SELF_TEST" `
        -FilePath $powerShellExecutable `
        -ArgumentList @(
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            $attestationInitializerTestPath
        ) `
        -TranscriptPath $initializerSelfTestTranscript `
        -TimeoutSeconds 120
    if ($initializerSelfTest.ExitCode -ne 0) {
        Stop-Certification (
            "The attestation-initializer self-test returned exit " +
            "$($initializerSelfTest.ExitCode)."
        )
    }
    $initializerSelfTestMatch = Get-SingleMatch `
        -Lines @($initializerSelfTest.Lines) `
        -Pattern (
            '^LAB_ATTESTATION_INITIALIZER_SELF_TEST pass=true ' +
            'assertions=(\d+) production_store_touched=false\s*$'
        ) `
        -Label "Attestation-initializer isolated success witness"
    $initializerAssertionCount = [int](
        $initializerSelfTestMatch.Groups[1].Value
    )
    if ($initializerAssertionCount -le 0) {
        Stop-Certification (
            "Attestation-initializer self-test reported no assertions."
        )
    }
    $initializerSelfTestWitness = [ordered]@{
        pass = $true
        assertions = $initializerAssertionCount
        production_store_touched = $false
        transcript_path = $initializerSelfTestTranscript
        transcript_sha256 = Get-Sha256 `
            -Path $initializerSelfTestTranscript
    }

    $attestationInvocation = Invoke-CertificationProcess `
        -Label "ATTESTATION_TRUST_INITIALIZE" `
        -FilePath $powerShellExecutable `
        -ArgumentList @(
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            $attestationInitializerPath
        ) `
        -TranscriptPath (Join-Path (
            $script:SessionRoot
        ) "attestation_initialize.transcript.log") `
        -TimeoutSeconds 120
    if ($attestationInvocation.ExitCode -ne 0) {
        Stop-Certification (
            "Production attestation initialization returned exit " +
            "$($attestationInvocation.ExitCode)."
        )
    }
    try {
        $trust = ConvertFrom-JsonPreservingStrings `
            -Json ([string]$attestationInvocation.Stdout).Trim() `
            -Depth 10
    } catch {
        Stop-Certification (
            "Attestation initializer did not emit exactly one JSON object: " +
            $_.Exception.Message
        )
    }
    if (
        [string]$trust.key_id -notmatch '^sha256:[a-f0-9]{64}$' -or
        -not (Get-NormalizedFullPath -Path (
            [string]$trust.trust_root
        )).Equals(
            $productionTrustRoot,
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {
        Stop-Certification (
            "Attestation initializer returned an unexpected production " +
            "trust identity."
        )
    }
    $productionTrustBeforeTests = Get-TrustStoreSnapshot `
        -TrustRoot $productionTrustRoot

    $testLogRoot = Join-Path $script:SessionRoot "tests"
    $testInvocation = Invoke-CertificationProcess `
        -Label "PINNED_LAB_TESTS" `
        -FilePath $powerShellExecutable `
        -ArgumentList @(
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            $testHarnessPath,
            "-Godot",
            $godotPath,
            "-Pattern",
            "test_lab_*.gd",
            "-LogRoot",
            $testLogRoot,
            "-TestTimeoutSeconds",
            $TestTimeoutSeconds.ToString(
                [System.Globalization.CultureInfo]::InvariantCulture
            )
        ) `
        -TranscriptPath (Join-Path (
            $script:SessionRoot
        ) "pinned_lab_tests.transcript.log") `
        -TimeoutSeconds $LabSuiteTimeoutSeconds
    if ($testInvocation.ExitCode -ne 0) {
        Stop-Certification (
            "The exact pinned lab-test suite returned exit " +
            "$($testInvocation.ExitCode)."
        )
    }
    $testReportMarker = Get-SingleMatch `
        -Lines @($testInvocation.Lines) `
        -Pattern '^REPORT\s+(.+?)\s*$' `
        -Label "Pinned lab-test REPORT"
    try {
        $testReportPath = (
            Resolve-Path `
                -LiteralPath $testReportMarker.Groups[1].Value `
                -ErrorAction Stop
        ).Path
    } catch {
        Stop-Certification (
            "Pinned lab-test REPORT names a missing file."
        )
    }
    if (-not (Test-PathAtOrBelow `
        -Candidate $testReportPath `
        -Parent $testLogRoot
    )) {
        Stop-Certification (
            "Pinned lab-test report was written outside its assigned root."
        )
    }
    $testEvidenceWitness = Read-TestEvidenceWitness `
        -ReportPath $testReportPath `
        -ExpectedTests $expectedTests `
        -ExpectedGodot $godotPath `
        -ExpectedLogRoot $testLogRoot `
        -ExpectedTimeoutSeconds $TestTimeoutSeconds
    $testReport = $testEvidenceWitness.report_object
    $productionTrustAfterTests = Get-TrustStoreSnapshot `
        -TrustRoot $productionTrustRoot
    if (
        [string]$productionTrustBeforeTests.sha256 -cne
            [string]$productionTrustAfterTests.sha256 -or
        [int]$productionTrustBeforeTests.entry_count -ne
            [int]$productionTrustAfterTests.entry_count
    ) {
        Stop-Certification (
            "The pinned lab-test suite changed production trust-store " +
            "contents, ACLs, ownership, or entry shape."
        )
    }
    $productionTrustTestWitness = [ordered]@{
        unchanged = $true
        before_sha256 = [string]$productionTrustBeforeTests.sha256
        after_sha256 = [string]$productionTrustAfterTests.sha256
        entry_count = [int]$productionTrustBeforeTests.entry_count
    }
    $afterTestsSource = Assert-SameCleanSource `
        -ExpectedCommit $commitSha `
        -Stage "AFTER_TESTS"
    $afterTestsGodotIdentity = Assert-GodotBinaryIdentity `
        -GodotPath $godotPath `
        -Stage "AFTER_TESTS"
    $afterTestsPhysicsChildIdentity = Assert-PhysicsChildBinaryIdentity `
        -GodotPath $physicsChildGodotPath `
        -Stage "AFTER_TESTS"

    $cellReports = @()
    $bundlePaths = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $receiptPaths = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $script:CampaignProcessLedger = @{
        outer_parent = @{}
        physics_child = @{}
    }
    $script:CampaignProcessInvocationCounts = @{
        outer_parent = [long]0
        physics_child = [long]0
    }
    $script:PidRecycleEvents = (
        [System.Collections.Generic.List[object]]::new()
    )
    $bundleCount = 0
    $replayCount = 0
    $comparisonCount = 0

    $cellOrdinal = 0
    foreach ($cell in $cells) {
        $cellOrdinal += 1
        $cellId = [string]$cell.cell_id
        $resourcePath = [string]$cell.resource_path
        $seed = [long]$cell.seed_policy.root_seed
        $observer = [string]$cell.observer.primary_profile_id
        $resourceAbsolutePath = Join-Path $script:RepoRoot (
            $resourcePath.Substring(6).Replace(
                "/",
                [System.IO.Path]::DirectorySeparatorChar
            )
        )
        $resourceSha256 = Get-Sha256 -Path $resourceAbsolutePath
        # Keep durable Windows paths short. The run ID itself is intentionally
        # descriptive, so duplicating the full cell ID in every parent
        # directory can cross legacy MAX_PATH boundaries.
        $safeCell = "c{0:d2}" -f $cellOrdinal
        $cellRoot = Join-Path $script:SessionRoot $safeCell
        [void][System.IO.Directory]::CreateDirectory($cellRoot)
        $replicateReports = @()

        for ($replicate = 1; $replicate -le 2; $replicate += 1) {
            $labelStem = "$safeCell.r$replicate"
            $replicateRoot = Join-Path $cellRoot "r$replicate"
            [void][System.IO.Directory]::CreateDirectory($replicateRoot)
            $launchEngineLog = Join-Path (
                $cellRoot
            ) "$labelStem.launch.engine.log"
            $launchTranscript = Join-Path (
                $cellRoot
            ) "$labelStem.launch.transcript.log"
            $launch = Invoke-CertificationProcess `
                -Label "$($cellId)_REPLICATE_$($replicate)_LAUNCH" `
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
                    $resourcePath,
                    "--seed",
                    $seed.ToString(
                        [System.Globalization.CultureInfo]::InvariantCulture
                    ),
                    "--observer",
                    $observer,
                    "--output-root",
                    $replicateRoot
                ) `
                -TranscriptPath $launchTranscript `
                -TimeoutSeconds $StepTimeoutSeconds
            Assert-GodotInvocationClean `
                -Invocation $launch `
                -EngineLogPath $launchEngineLog `
                -Label "$cellId replicate $replicate launch"
            if ($launch.ExitCode -ne 0) {
                Stop-Certification (
                    "$cellId replicate $replicate launch must return exit " +
                    "0 for clean promotion; observed $($launch.ExitCode)."
                )
            }

            $artifactMatch = Get-SingleMatch `
                -Lines @($launch.Lines) `
                -Pattern '^LAB artifacts=(.+?)\s*$' `
                -Label "$cellId replicate $replicate artifact marker"
            try {
                $bundlePath = (
                    Resolve-Path `
                        -LiteralPath $artifactMatch.Groups[1].Value `
                        -ErrorAction Stop
                ).Path
            } catch {
                Stop-Certification (
                    "$cellId replicate $replicate artifact marker names a " +
                    "missing bundle."
                )
            }
            if (
                -not (Test-Path -LiteralPath $bundlePath -PathType Container) -or
                -not (Test-PathAtOrBelow `
                    -Candidate $bundlePath `
                    -Parent $replicateRoot) -or
                -not (Get-NormalizedFullPath -Path (
                    Split-Path -Parent $bundlePath
                )).Equals(
                    (Get-NormalizedFullPath -Path $replicateRoot),
                    [System.StringComparison]::OrdinalIgnoreCase
                ) -or
                -not $bundlePaths.Add(
                    (Get-NormalizedFullPath -Path $bundlePath)
                )
            ) {
                Stop-Certification (
                    "$cellId replicate $replicate did not produce one " +
                    "unique direct-child final bundle."
                )
            }
            $finalDirectories = @(
                Get-ChildItem -LiteralPath $replicateRoot -Directory |
                    Where-Object {
                        -not $_.Name.EndsWith(
                            ".partial",
                            [System.StringComparison]::OrdinalIgnoreCase
                        )
                    }
            )
            $partialDirectories = @(
                Get-ChildItem -LiteralPath $replicateRoot -Directory |
                    Where-Object {
                        $_.Name.EndsWith(
                            ".partial",
                            [System.StringComparison]::OrdinalIgnoreCase
                        )
                    }
            )
            if (
                $finalDirectories.Count -ne 1 -or
                $partialDirectories.Count -ne 0 -or
                -not $finalDirectories[0].FullName.Equals(
                    $bundlePath,
                    [System.StringComparison]::OrdinalIgnoreCase
                )
            ) {
                Stop-Certification (
                    "$cellId replicate $replicate left an ambiguous " +
                    "final/partial bundle set."
                )
            }

            $attestationMatch = Get-SingleMatch `
                -Lines @($launch.Lines) `
                -Pattern (
                    '^LAB attestation=valid algorithm=hmac-sha256 ' +
                    'key_id=(sha256:[a-f0-9]{64}) receipt=(.+?)\s*$'
                ) `
                -Label "$cellId replicate $replicate attestation marker"
            $keyId = $attestationMatch.Groups[1].Value
            if ($keyId -cne [string]$trust.key_id) {
                Stop-Certification (
                    "$cellId replicate $replicate used a different " +
                    "attestation key from the initialized active key."
                )
            }
            try {
                $receiptPath = (
                    Resolve-Path `
                        -LiteralPath $attestationMatch.Groups[2].Value `
                        -ErrorAction Stop
                ).Path
            } catch {
                Stop-Certification (
                    "$cellId replicate $replicate attestation marker names " +
                    "a missing receipt."
                )
            }
            $receiptsRoot = Join-Path $productionTrustRoot "receipts"
            if (
                -not (Test-PathAtOrBelow `
                    -Candidate $receiptPath `
                    -Parent $receiptsRoot) -or
                -not (Test-Path -LiteralPath $receiptPath -PathType Leaf) -or
                -not $receiptPaths.Add(
                    (Get-NormalizedFullPath -Path $receiptPath)
                )
            ) {
                Stop-Certification (
                    "$cellId replicate $replicate receipt is not a unique " +
                    "file in the production receipt store."
                )
            }

            $manifest = Read-JsonObject `
                -Path (Join-Path $bundlePath "manifest.json") `
                -Label "$cellId replicate $replicate manifest"
            $summary = Read-JsonObject `
                -Path (Join-Path $bundlePath "summary.json") `
                -Label "$cellId replicate $replicate summary"
            $childEngineLog = Join-Path $bundlePath "engine.log"
            if (-not (Test-Path -LiteralPath $childEngineLog -PathType Leaf)) {
                Stop-Certification (
                    "$cellId replicate $replicate final bundle is missing " +
                    "the sealed child engine log."
                )
            }
            $childEngineErrors = @(
                [regex]::Matches(
                    [string](
                        Get-Content -LiteralPath $childEngineLog -Raw
                    ),
                    '(?im)^\s*(?:SCRIPT ERROR:|ERROR:).*$'
                ) |
                    ForEach-Object { $_.Value.Trim() } |
                    Sort-Object -Unique
            )
            if ($childEngineErrors.Count -gt 0) {
                Stop-Certification (
                    "$cellId replicate $replicate sealed child engine log " +
                    "contains $($childEngineErrors.Count) engine/script " +
                    "error line(s): " +
                    ((@(
                        $childEngineErrors |
                            Select-Object -First 4
                    )) -join " | ")
                )
            }
            $runId = [string]$manifest.run_id
            if (
                [string]::IsNullOrWhiteSpace($runId) -or
                $runId -cne (Split-Path -Leaf $bundlePath) -or
                $manifest.status -cne "COMPLETE" -or
                $manifest.experiment_resource_path -cne $resourcePath -or
                $manifest.experiment_resource_sha256 -cne
                    $resourceSha256 -or
                [long]$manifest.seed_root -ne $seed -or
                $manifest.observer_profile -cne $observer -or
                $manifest.git_commit -cne $commitSha -or
                $manifest.dirty_worktree -ne $false -or
                $manifest.execution_mode -cne "promotion" -or
                $summary.run_id -cne $runId -or
                $summary.termination -cne "completed" -or
                $summary.evidence_validity -cne "valid" -or
                $summary.promotion -cne "pass" -or
                $summary.gate_results.source_state.pass -ne $true -or
                $summary.gate_results.configuration.pass -ne $true -or
                $summary.gate_results.physical.pass -ne $true
            ) {
                Stop-Certification (
                    "$cellId replicate $replicate final bundle identity or " +
                    "clean-source completion witness is inconsistent."
                )
            }

            $launchIdentity = Assert-LaunchProcessIdentity `
                -PhysicsChildGodotPath $physicsChildGodotPath `
                -BundlePath $bundlePath `
                -ReplicateRoot $replicateRoot `
                -ResourcePath $resourcePath `
                -Seed $seed `
                -Observer $observer `
                -RunId $runId `
                -ExpectedResourceSha256 $resourceSha256
            Register-CampaignProcessInvocation `
                -Role "outer_parent" `
                -ProcessId ([long]$launchIdentity.outer_parent_process_id) `
                -RunId $runId `
                -StartedUtc ([string]$launchIdentity.started_utc) `
                -EndedUtc ([string]$launchIdentity.ended_utc) `
                -Label "$cellId replicate $replicate"
            Register-CampaignProcessInvocation `
                -Role "physics_child" `
                -ProcessId ([long]$launchIdentity.physics_child_process_id) `
                -RunId $runId `
                -StartedUtc ([string]$launchIdentity.started_utc) `
                -EndedUtc ([string]$launchIdentity.ended_utc) `
                -Label "$cellId replicate $replicate"
            $validation = Invoke-BundleValidation `
                -GodotPath $godotPath `
                -BundlePath $bundlePath `
                -LabelStem $labelStem `
                -LogDirectory $cellRoot
            $validatedAttestation = (
                $validation.publication_attestation
            )
            $receiptSha256 = Get-Sha256 -Path $receiptPath
            if (
                $validatedAttestation.key_id -cne $keyId -or
                $validatedAttestation.run_id -cne $runId -or
                $validatedAttestation.receipt_sha256 -cne
                    $receiptSha256 -or
                -not (Get-NormalizedFullPath -Path (
                    [string]$validatedAttestation.receipt_path
                )).Equals(
                    (Get-NormalizedFullPath -Path $receiptPath),
                    [System.StringComparison]::OrdinalIgnoreCase
                )
            ) {
                Stop-Certification (
                    "$cellId replicate $replicate launch receipt and " +
                    "independent validator receipt identities disagree."
                )
            }
            $replay = Invoke-TraceReplay `
                -GodotPath $godotPath `
                -BundlePath $bundlePath `
                -RunId $runId `
                -LabelStem $labelStem `
                -LogDirectory $cellRoot
            $bundleCount += 1
            $replayCount += 1
            $replicateReports += [ordered]@{
                replicate = $replicate
                run_id = $runId
                experiment_id = [string]$manifest.experiment_id
                physics_ticks_per_second = [int](
                    $manifest.physics_ticks_per_second
                )
                bundle_path = $bundlePath
                bundle_manifest_sha256 = Get-Sha256 -Path (
                    Join-Path $bundlePath "manifest.json"
                )
                bundle_checksums_sha256 = Get-Sha256 -Path (
                    Join-Path $bundlePath "checksums.json"
                )
                bundle_summary_sha256 = Get-Sha256 -Path (
                    Join-Path $bundlePath "summary.json"
                )
                process_metadata_sha256 = Get-Sha256 -Path (
                    Join-Path $bundlePath "process_metadata.json"
                )
                launch_plan_sha256 = Get-Sha256 -Path (
                    Join-Path $bundlePath "launch_plan.json"
                )
                replicate_root = $replicateRoot
                launch = [ordered]@{
                    exit_code = [int]$launch.ExitCode
                    duration_ms = [int64]$launch.DurationMs
                    engine_log = $launchEngineLog
                    sealed_child_engine_log = $childEngineLog
                    transcript = $launchTranscript
                }
                attestation = [ordered]@{
                    valid = $true
                    algorithm = "hmac-sha256"
                    key_id = $keyId
                    receipt_path = $receiptPath
                    receipt_sha256 = $receiptSha256
                    trust_mode = "production"
                }
                process_identity = $launchIdentity
                independent_validation = $validation
                replay = $replay
            }
        }

        if ($replicateReports.Count -ne 2) {
            Stop-Certification (
                "$cellId did not produce exactly two replicate reports."
            )
        }
        $leftProcessIdentity = $replicateReports[0].process_identity
        $rightProcessIdentity = $replicateReports[1].process_identity
        # PID equality between replicates is not asserted here: legal Windows
        # PID recycling is adjudicated by Register-CampaignProcessInvocation,
        # which rejects overlapping sealed run windows and records every
        # accepted recycle as a report witness.
        if (
            $leftProcessIdentity.reservation_id -ceq
                $rightProcessIdentity.reservation_id -or
            $leftProcessIdentity.launch_plan_sha256 -ceq
                $rightProcessIdentity.launch_plan_sha256 -or
            $leftProcessIdentity.launch_plan_payload_sha256 -ceq
                $rightProcessIdentity.launch_plan_payload_sha256 -or
            $replicateReports[0].run_id -ceq
                $replicateReports[1].run_id
        ) {
            Stop-Certification (
                "$cellId replicate pair lacks distinct reservation, run, " +
                "or frozen launch-plan identity."
            )
        }
        $comparison = Invoke-ReplicateComparison `
            -GodotPath $godotPath `
            -CellId $cellId `
            -LeftBundle ([string]$replicateReports[0].bundle_path) `
            -RightBundle ([string]$replicateReports[1].bundle_path) `
            -LogDirectory $cellRoot `
            -Phase "initial"
        $comparisonCount += 1
        $cellReports += [ordered]@{
            cell_id = $cellId
            resource_path = $resourcePath
            resource_sha256 = $resourceSha256
            root_seed = $seed
            observer_adapter = [string]$cell.observer.adapter_id
            observer_profile = $observer
            replicates = $replicateReports
            comparison = $comparison
        }
    }

    if (
        $cellReports.Count -ne 7 -or
        $bundleCount -ne 14 -or
        $replayCount -ne 14 -or
        $comparisonCount -ne 7 -or
        $bundlePaths.Count -ne 14 -or
        $receiptPaths.Count -ne 14 -or
        $script:CampaignProcessInvocationCounts["outer_parent"] -ne 14 -or
        $script:CampaignProcessInvocationCounts["physics_child"] -ne 14
    ) {
        Stop-Certification (
            "BR1 evidence cardinality is incomplete: " +
            "cells=$($cellReports.Count)/7 " +
            "bundles=$bundleCount/14 replays=$replayCount/14 " +
            "comparisons=$comparisonCount/7 " +
            "unique_bundles=$($bundlePaths.Count)/14 " +
            "unique_receipts=$($receiptPaths.Count)/14 " +
            "distinct_outer_parent_invocations=$(
                $script:CampaignProcessInvocationCounts["outer_parent"]
            )/14 " +
            "distinct_physics_child_invocations=$(
                $script:CampaignProcessInvocationCounts["physics_child"]
            )/14."
        )
    }

    $beforeFinalSweepSource = Assert-SameCleanSource `
        -ExpectedCommit $commitSha `
        -Stage "BEFORE_FINAL_SWEEP"
    $beforeFinalSweepGodotIdentity = Assert-GodotBinaryIdentity `
        -GodotPath $godotPath `
        -Stage "BEFORE_FINAL_SWEEP"
    $beforeFinalSweepPhysicsChildIdentity = (
        Assert-PhysicsChildBinaryIdentity `
            -GodotPath $physicsChildGodotPath `
            -Stage "BEFORE_FINAL_SWEEP"
    )

    # Re-open every retained bundle at the end of the campaign. This second
    # sweep is intentionally separate from the initial per-run validation:
    # it catches replacement, receipt swapping, or evidence mutation that
    # occurs after an early bundle passed but before the report is published.
    $finalSweepBundleCount = 0
    $finalSweepReplayCount = 0
    $finalSweepComparisonCount = 0
    $finalSweepCellOrdinal = 0
    foreach ($cellReport in $cellReports) {
        $finalSweepCellOrdinal += 1
        $safeCell = "c{0:d2}" -f $finalSweepCellOrdinal
        $cellId = [string]$cellReport.cell_id
        $resourcePath = [string]$cellReport.resource_path
        $resourceSha256 = [string]$cellReport.resource_sha256
        $seed = [long]$cellReport.root_seed
        $observer = [string]$cellReport.observer_profile
        $replicateReports = @($cellReport.replicates)
        if ($replicateReports.Count -ne 2) {
            Stop-Certification (
                "$cellId retained report no longer contains two replicates."
            )
        }
        $cellRoot = Split-Path -Parent (
            [string]$replicateReports[0].launch.engine_log
        )

        foreach ($replicateReport in $replicateReports) {
            $replicate = [int]$replicateReport.replicate
            $runId = [string]$replicateReport.run_id
            $bundlePath = [string]$replicateReport.bundle_path
            $replicateRoot = [string]$replicateReport.replicate_root
            $receiptPath = [string](
                $replicateReport.attestation.receipt_path
            )
            $labelStem = "$safeCell.r$replicate.final"
            if (
                -not (Test-Path `
                    -LiteralPath $bundlePath `
                    -PathType Container) -or
                -not (Test-Path `
                    -LiteralPath $receiptPath `
                    -PathType Leaf)
            ) {
                Stop-Certification (
                    "$cellId replicate $replicate retained bundle or " +
                    "receipt disappeared before the final sweep."
                )
            }

            $currentManifestSha256 = Get-Sha256 -Path (
                Join-Path $bundlePath "manifest.json"
            )
            $currentChecksumsSha256 = Get-Sha256 -Path (
                Join-Path $bundlePath "checksums.json"
            )
            $currentSummarySha256 = Get-Sha256 -Path (
                Join-Path $bundlePath "summary.json"
            )
            $currentProcessSha256 = Get-Sha256 -Path (
                Join-Path $bundlePath "process_metadata.json"
            )
            $currentLaunchPlanSha256 = Get-Sha256 -Path (
                Join-Path $bundlePath "launch_plan.json"
            )
            $currentReceiptSha256 = Get-Sha256 -Path $receiptPath
            if (
                $currentManifestSha256 -cne
                    [string]$replicateReport.bundle_manifest_sha256 -or
                $currentChecksumsSha256 -cne
                    [string]$replicateReport.bundle_checksums_sha256 -or
                $currentSummarySha256 -cne
                    [string]$replicateReport.bundle_summary_sha256 -or
                $currentProcessSha256 -cne
                    [string]$replicateReport.process_metadata_sha256 -or
                $currentLaunchPlanSha256 -cne
                    [string]$replicateReport.launch_plan_sha256 -or
                $currentReceiptSha256 -cne
                    [string]$replicateReport.attestation.receipt_sha256
            ) {
                Stop-Certification (
                    "$cellId replicate $replicate retained artifact or " +
                    "detached receipt digest changed before final publication."
                )
            }

            $finalLaunchIdentity = Assert-LaunchProcessIdentity `
                -PhysicsChildGodotPath $physicsChildGodotPath `
                -BundlePath $bundlePath `
                -ReplicateRoot $replicateRoot `
                -ResourcePath $resourcePath `
                -Seed $seed `
                -Observer $observer `
                -RunId $runId `
                -ExpectedResourceSha256 $resourceSha256
            $initialLaunchIdentity = $replicateReport.process_identity
            if (
                [long]$finalLaunchIdentity.outer_parent_process_id -ne
                    [long]$initialLaunchIdentity.outer_parent_process_id -or
                [long]$finalLaunchIdentity.physics_child_process_id -ne
                    [long]$initialLaunchIdentity.physics_child_process_id -or
                $finalLaunchIdentity.reservation_id -cne
                    $initialLaunchIdentity.reservation_id -or
                $finalLaunchIdentity.process_metadata_sha256 -cne
                    $initialLaunchIdentity.process_metadata_sha256 -or
                $finalLaunchIdentity.launch_plan_sha256 -cne
                    $initialLaunchIdentity.launch_plan_sha256 -or
                $finalLaunchIdentity.launch_plan_payload_sha256 -cne
                    $initialLaunchIdentity.launch_plan_payload_sha256 -or
                $finalLaunchIdentity.started_utc -cne
                    $initialLaunchIdentity.started_utc -or
                $finalLaunchIdentity.ended_utc -cne
                    $initialLaunchIdentity.ended_utc
            ) {
                Stop-Certification (
                    "$cellId replicate $replicate retained launch/process " +
                    "identity changed before final publication."
                )
            }

            $finalValidation = Invoke-BundleValidation `
                -GodotPath $godotPath `
                -BundlePath $bundlePath `
                -LabelStem $labelStem `
                -LogDirectory $cellRoot
            $initialValidation = (
                $replicateReport.independent_validation
            )
            $finalAttestation = (
                $finalValidation.publication_attestation
            )
            $initialAttestation = $replicateReport.attestation
            if (
                $finalValidation.result_sha256 -cne
                    $initialValidation.result_sha256 -or
                $finalAttestation.key_id -cne
                    $initialAttestation.key_id -or
                $finalAttestation.run_id -cne $runId -or
                $finalAttestation.receipt_sha256 -cne
                    $initialAttestation.receipt_sha256 -or
                -not (Get-NormalizedFullPath -Path (
                    [string]$finalAttestation.receipt_path
                )).Equals(
                    (Get-NormalizedFullPath -Path (
                        [string]$initialAttestation.receipt_path
                    )),
                    [System.StringComparison]::OrdinalIgnoreCase
                )
            ) {
                Stop-Certification (
                    "$cellId replicate $replicate final validation witness " +
                    "or production receipt identity differs from its " +
                    "retained initial witness."
                )
            }

            $finalReplay = Invoke-TraceReplay `
                -GodotPath $godotPath `
                -BundlePath $bundlePath `
                -RunId $runId `
                -LabelStem $labelStem `
                -LogDirectory $cellRoot
            $initialReplay = $replicateReport.replay
            if (
                $finalReplay.pass -ne $true -or
                [int]$finalReplay.simulation_steps -ne 0 -or
                [int]$finalReplay.frames -ne
                    [int]$initialReplay.frames -or
                [int]$finalReplay.events -ne
                    [int]$initialReplay.events
            ) {
                Stop-Certification (
                    "$cellId replicate $replicate final physics-free replay " +
                    "differs from its retained initial witness."
                )
            }

            $replicateReport["final_sweep"] = [ordered]@{
                pass = $true
                retained_witness_match = $true
                production_attestation_required = $true
                promotion_required = $true
                manifest_sha256 = $currentManifestSha256
                checksums_sha256 = $currentChecksumsSha256
                summary_sha256 = $currentSummarySha256
                process_metadata_sha256 = $currentProcessSha256
                launch_plan_sha256 = $currentLaunchPlanSha256
                receipt_path = $receiptPath
                receipt_sha256 = $currentReceiptSha256
                process_identity = $finalLaunchIdentity
                validation = $finalValidation
                replay = $finalReplay
            }
            $finalSweepBundleCount += 1
            $finalSweepReplayCount += 1
        }

        $finalComparison = Invoke-ReplicateComparison `
            -GodotPath $godotPath `
            -CellId $cellId `
            -LeftBundle ([string]$replicateReports[0].bundle_path) `
            -RightBundle ([string]$replicateReports[1].bundle_path) `
            -LogDirectory $cellRoot `
            -Phase "final_sweep"
        if (
            $finalComparison.result_sha256 -cne
                $cellReport.comparison.result_sha256 -or
            $finalComparison.comparator_id -cne
                $cellReport.comparison.comparator_id -or
            $finalComparison.left_evidence_digest -cne
                $cellReport.comparison.left_evidence_digest -or
            $finalComparison.right_evidence_digest -cne
                $cellReport.comparison.right_evidence_digest
        ) {
            Stop-Certification (
                "$cellId final replicate comparison differs from its " +
                "retained initial comparator witness."
            )
        }
        $cellReport["final_comparison"] = $finalComparison
        $finalSweepComparisonCount += 1
    }

    if (
        $finalSweepBundleCount -ne 14 -or
        $finalSweepReplayCount -ne 14 -or
        $finalSweepComparisonCount -ne 7
    ) {
        Stop-Certification (
            "Final readback sweep is incomplete: " +
            "bundles=$finalSweepBundleCount/14 " +
            "replays=$finalSweepReplayCount/14 " +
            "comparisons=$finalSweepComparisonCount/7."
        )
    }
    Assert-TestEvidenceUnchanged `
        -Witness $testEvidenceWitness `
        -Stage "BEFORE_FINAL_REPORT"
    $afterFinalSweepGodotIdentity = Assert-GodotBinaryIdentity `
        -GodotPath $godotPath `
        -Stage "AFTER_FINAL_SWEEP"
    $afterFinalSweepPhysicsChildIdentity = (
        Assert-PhysicsChildBinaryIdentity `
            -GodotPath $physicsChildGodotPath `
            -Stage "AFTER_FINAL_SWEEP"
    )
    $finalSource = Assert-SameCleanSource `
        -ExpectedCommit $commitSha `
        -Stage "AFTER_FINAL_SWEEP"
    $campaignSha256 = Get-Sha256 -Path $campaignPath
    $report = [ordered]@{
        schema = "sporespore.lab.br1_certification_report.v2"
        status = "pass"
        certification = "BR1_L0_EVIDENCE_PIPELINE"
        claim_boundary = $script:ClaimBoundary
        generated_utc = (Get-Date).ToUniversalTime().ToString("o")
        serialization = "ordered_compact_utf8_no_bom_v1"
        repository = [ordered]@{
            root = $script:RepoRoot
            commit_sha = $commitSha
            clean_at_all_recorded_gates = $true
            commit_unchanged_at_all_recorded_gates = $true
            temporal_claim = (
                "Cleanliness and commit identity were observed at the " +
                "listed gates; this does not claim continuous monitoring " +
                "between gates."
            )
            gates = @(
                $initialSource,
                $afterTestsSource,
                $beforeFinalSweepSource,
                $finalSource
            )
        }
        engine = [ordered]@{
            executable = $godotPath
            expected_version = $script:ExpectedGodotVersion
            observed_version = $godotVersion
            expected_executable_sha256 = (
                $script:ExpectedGodotExecutableSha256
            )
            observed_executable_sha256 = (
                $initialGodotIdentity.executable_sha256
            )
            product_version = $initialGodotIdentity.product_version
            file_description = $initialGodotIdentity.file_description
            exact_build_match_at_all_recorded_gates = $true
            identity_gates = @(
                $initialGodotIdentity,
                $afterTestsGodotIdentity,
                $beforeFinalSweepGodotIdentity,
                $afterFinalSweepGodotIdentity
            )
            physics_child_executable = $physicsChildGodotPath
            expected_physics_child_executable_sha256 = (
                $script:ExpectedPhysicsChildExecutableSha256
            )
            observed_physics_child_executable_sha256 = (
                $initialPhysicsChildIdentity.executable_sha256
            )
            physics_child_product_version = (
                $initialPhysicsChildIdentity.product_version
            )
            physics_child_file_description = (
                $initialPhysicsChildIdentity.file_description
            )
            physics_child_exact_build_match_at_all_recorded_gates = $true
            physics_child_identity_gates = @(
                $initialPhysicsChildIdentity,
                $afterTestsPhysicsChildIdentity,
                $beforeFinalSweepPhysicsChildIdentity,
                $afterFinalSweepPhysicsChildIdentity
            )
        }
        timeout_policy = [ordered]@{
            per_test_seconds = $TestTimeoutSeconds
            lab_suite_seconds = $LabSuiteTimeoutSeconds
            per_step_seconds = $StepTimeoutSeconds
            process_tree_kill_on_timeout = $true
            process_runner_self_test = $true
        }
        operator_self_tests = [ordered]@{
            process_runner = $processSelfTestWitness
            attestation_initializer = $initializerSelfTestWitness
        }
        attestation = [ordered]@{
            requirement = "production_required"
            algorithm = "hmac-sha256"
            key_id = [string]$trust.key_id
            trust_root = [string]$trust.trust_root
            scope = (
                "Detects post-publication bundle replacement by a writer " +
                "that cannot read or alter the external trust store."
            )
        }
        detached_report_attestation = [ordered]@{
            required = $true
            timing = "after_complete_report_serialization"
            report_rewrite_after_attestation_forbidden = $true
            cli_resource = [string](
                $script:ReportAttestationContract.cli_resource
            )
            receipt_schema = [string](
                $script:ReportAttestationContract.receipt_schema
            )
            algorithm = [string](
                $script:ReportAttestationContract.algorithm
            )
            trust_mode = "production"
            certification_id = $sessionName
        }
        test_inventory = [ordered]@{
            path = $inventoryPath
            sha256 = Get-Sha256 -Path $inventoryPath
            required = $expectedTests.Count
            executed = [int]$testReport.total
            passed = [int]$testReport.passed
            failed = [int]$testReport.failed
            missing = 0
            extra = 0
            report_path = [string]$testEvidenceWitness.report_path
            report_sha256 = [string]$testEvidenceWitness.report_sha256
            report_bytes = [long]$testEvidenceWitness.report_bytes
            report_payload_base64 = [string](
                $testEvidenceWitness.report_payload_base64
            )
            artifacts = @($testEvidenceWitness.artifacts)
            production_trust_store = $productionTrustTestWitness
        }
        campaign = [ordered]@{
            path = $campaignPath
            sha256 = $campaignSha256
            campaign_id = [string]$campaign.campaign_id
            cells_required = 7
            cells_passed = $cellReports.Count
            bundles_required = 14
            bundles_passed = $bundleCount
            replays_required = 14
            replays_passed = $replayCount
            replicate_comparisons_required = 7
            replicate_comparisons_passed = $comparisonCount
            unique_outer_parent_processes = [int](
                $script:CampaignProcessInvocationCounts["outer_parent"]
            )
            unique_physics_child_processes = [int](
                $script:CampaignProcessInvocationCounts["physics_child"]
            )
            pid_recycle_events = @($script:PidRecycleEvents)
            final_readback = [ordered]@{
                bundles_required = 14
                bundles_passed = $finalSweepBundleCount
                replays_required = 14
                replays_passed = $finalSweepReplayCount
                replicate_comparisons_required = 7
                replicate_comparisons_passed = (
                    $finalSweepComparisonCount
                )
                retained_witnesses_match = $true
                receipt_identities_match = $true
            }
            cells = $cellReports
        }
    }
    Write-CompactJson -Value $report -Path $script:ReportPath
    $reportSha256 = Get-Sha256 -Path $script:ReportPath
    $reportAttestation = Invoke-ReportAttestation `
        -GodotPath $godotPath `
        -Mode "attest" `
        -ReportPath $script:ReportPath `
        -ReportSha256 $reportSha256 `
        -CertificationId $sessionName `
        -ExpectedKeyId ([string]$trust.key_id) `
        -ExpectedCommitSha $commitSha `
        -ExpectedCampaignSha256 $campaignSha256 `
        -ProductionTrustRoot $productionTrustRoot `
        -LogDirectory $script:SessionRoot
    $reportAttestationVerification = Invoke-ReportAttestation `
        -GodotPath $godotPath `
        -Mode "verify" `
        -ReportPath $script:ReportPath `
        -ReportSha256 $reportSha256 `
        -CertificationId $sessionName `
        -ExpectedKeyId ([string]$trust.key_id) `
        -ExpectedCommitSha $commitSha `
        -ExpectedCampaignSha256 $campaignSha256 `
        -ProductionTrustRoot $productionTrustRoot `
        -LogDirectory $script:SessionRoot
    if (
        $reportAttestation.receipt_path -cne
            $reportAttestationVerification.receipt_path -or
        $reportAttestation.receipt_sha256 -cne
            $reportAttestationVerification.receipt_sha256 -or
        $reportAttestation.report_sha256 -cne
            $reportAttestationVerification.report_sha256 -or
        $reportAttestation.key_id -cne
            $reportAttestationVerification.key_id -or
        $reportAttestation.attested_utc -cne
            $reportAttestationVerification.attested_utc
    ) {
        Stop-Certification (
            "Detached report attestation and immediate production " +
            "verification returned different receipt identities."
        )
    }
    [void](Assert-GodotBinaryIdentity `
        -GodotPath $godotPath `
        -Stage "AFTER_REPORT_ATTESTATION")
    [void](Assert-PhysicsChildBinaryIdentity `
        -GodotPath $physicsChildGodotPath `
        -Stage "AFTER_REPORT_ATTESTATION")
    [void](Assert-SameCleanSource `
        -ExpectedCommit $commitSha `
        -Stage "AFTER_REPORT_ATTESTATION")
    if (
        (Get-Sha256 -Path $script:ReportPath) -cne $reportSha256 -or
        (Get-Sha256 -Path (
            [string]$reportAttestation.receipt_path
        )) -cne [string]$reportAttestation.receipt_sha256
    ) {
        Stop-Certification (
            "Report or detached report receipt changed after immediate " +
            "production verification."
        )
    }
    Assert-TestEvidenceUnchanged `
        -Witness $testEvidenceWitness `
        -Stage "AFTER_REPORT_ATTESTATION"
    Write-Host (
        "BR1 evidence cells=7/7 bundles=14/14 replays=14/14 " +
        "replicate_comparisons=7/7 final_readback=14/14"
    )
    Write-Host (
        "BR1 claim_boundary=" +
        "no_standing_bracing_recovery_or_walking_capability_established"
    )
    Write-Host (
        "BR1 report=$script:ReportPath sha256=$reportSha256"
    )
    Write-Host (
        "BR1 report_attestation=pass trust_mode=production " +
        "receipt=$($reportAttestation.receipt_path) " +
        "receipt_sha256=$($reportAttestation.receipt_sha256)"
    )
    Write-Host "BR1 certification=pass"
    exit 0
} catch {
    $failureMessage = $_.Exception.Message
    if (
        $null -ne $script:FailureReportPath -and
        $null -ne $script:SessionRoot -and
        (Test-Path -LiteralPath $script:SessionRoot -PathType Container)
    ) {
        try {
            $failureReport = [ordered]@{
                schema = "sporespore.lab.br1_certification_failure.v1"
                status = "failed"
                certification = "BR1_L0_EVIDENCE_PIPELINE"
                claim_boundary = $script:ClaimBoundary
                generated_utc = (
                    Get-Date
                ).ToUniversalTime().ToString("o")
                message = $failureMessage
                session_root = $script:SessionRoot
            }
            Write-CompactJson `
                -Value $failureReport `
                -Path $script:FailureReportPath
            [Console]::Error.WriteLine(
                "BR1 failure_report=$script:FailureReportPath"
            )
        } catch {
            # The original certification failure remains authoritative.
        }
    }
    [Console]::Error.WriteLine("BR1 failure=$failureMessage")
    [Console]::Error.WriteLine(
        "BR1 claim_boundary=" +
        "no_standing_bracing_recovery_or_walking_capability_established"
    )
    [Console]::Error.WriteLine("BR1 certification=failed")
    exit 1
}

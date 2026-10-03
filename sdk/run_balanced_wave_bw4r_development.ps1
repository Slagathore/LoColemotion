#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    )
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$godotPath = [System.IO.Path]::GetFullPath($Godot)
$evidenceRootPath = [System.IO.Path]::GetFullPath($EvidenceRoot)

function Assert-Exact {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Get-SourceState {
    $status = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    )
    Assert-Exact ($LASTEXITCODE -eq 0) "Unable to read the BW4R source worktree"
    $head = (& git -C $repoRoot rev-parse HEAD).Trim()
    Assert-Exact ($LASTEXITCODE -eq 0) "Unable to resolve BW4R source HEAD"
    $originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
    Assert-Exact ($LASTEXITCODE -eq 0) "Unable to resolve origin/main"
    return [ordered]@{
        commit = $head
        clean = $status.Count -eq 0
        matches_origin_main = $head -ceq $originMain
    }
}

function Get-Sha256 {
    param([string]$Path)
    return (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Read-CompleteReport {
    param(
        [string]$Path,
        [string]$Candidate,
        [string]$Role,
        [int]$ExpectedWorldCount,
        [string]$SourceCommit
    )
    Assert-Exact (
        Test-Path -LiteralPath $Path -PathType Leaf
    ) "$Candidate $Role did not retain report.json"
    $report = Get-Content -LiteralPath $Path -Raw |
        ConvertFrom-Json -AsHashtable
    $observedWorldCount = switch ($Role) {
        "reference" { [int]$report.receipt.world_count; break }
        "counterexamples" { [int]$report.observed_world_count; break }
        default { [int]$report.receipt.observed_world_count; break }
    }
    Assert-Exact (
        [string]$report.source_commit -ceq $SourceCommit -and
        [bool]$report.source_worktree_clean -and
        [bool]$report.source_matches_origin_main -and
        [bool]$report.development_data_only -and
        [string]$report.candidate_id -ceq $Candidate -and
        $observedWorldCount -eq $ExpectedWorldCount
    ) "$Candidate $Role report is incomplete or source-mismatched"
    return $report
}

function Invoke-OrResumeRetainedCampaign {
    param(
        [string]$Candidate,
        [string]$Role,
        [string]$ReportPath,
        [int]$ExpectedWorldCount,
        [string]$SourceCommit,
        [string]$ScriptPath,
        [System.Collections.IDictionary]$Arguments
    )
    if (Test-Path -LiteralPath $ReportPath -PathType Leaf) {
        [void](Read-CompleteReport `
            -Path $ReportPath `
            -Candidate $Candidate `
            -Role $Role `
            -ExpectedWorldCount $ExpectedWorldCount `
            -SourceCommit $SourceCommit)
        Write-Host "BW4R resume accepted existing $Candidate $Role report: $ReportPath"
        return
    }
    $reportDirectory = Split-Path -Parent $ReportPath
    if (Test-Path -LiteralPath $reportDirectory) {
        Assert-Exact (
            @(Get-ChildItem -LiteralPath $reportDirectory -Force).Count -eq 0
        ) (
            "$Candidate $Role output directory is partial and has no report.json. " +
            "Preserve it for recovery instead of overwriting it: $reportDirectory"
        )
    }

    $runnerError = $null
    try {
        & $ScriptPath @Arguments
        if ($LASTEXITCODE -ne 0) {
            $runnerError = "runner exit code $LASTEXITCODE"
        }
    } catch {
        $runnerError = $_.Exception.Message
        Write-Warning (
            "$Candidate $Role runner reported a retained negative or failure: " +
            $runnerError
        )
    }

    [void](Read-CompleteReport `
        -Path $ReportPath `
        -Candidate $Candidate `
        -Role $Role `
        -ExpectedWorldCount $ExpectedWorldCount `
        -SourceCommit $SourceCommit)
    if ($null -ne $runnerError) {
        Write-Host (
            "$Candidate $Role retained a complete report despite runner status: " +
            $runnerError
        )
    } else {
        Write-Host "BW4R retained complete $Candidate $Role report: $ReportPath"
    }
}

Assert-Exact (
    Test-Path -LiteralPath $godotPath -PathType Leaf
) "Godot executable not found: $godotPath"
if (-not (Test-Path -LiteralPath $evidenceRootPath)) {
    [void][System.IO.Directory]::CreateDirectory($evidenceRootPath)
}
Assert-Exact (
    Test-Path -LiteralPath $evidenceRootPath -PathType Container
) "Evidence root is not a directory: $evidenceRootPath"

$sourceBefore = Get-SourceState
Assert-Exact (
    [bool]$sourceBefore.clean -and [bool]$sourceBefore.matches_origin_main
) "BW4R development requires clean source exactly matching origin/main"
$sourceCommit = [string]$sourceBefore.commit
$sourceShort = $sourceCommit.Substring(0, 7)

$reportSets = @()
foreach ($candidate in @("BW4R-A", "BW4R-B")) {
    $candidateSlug = $candidate.ToLowerInvariant()
    $referencePath = Join-Path $evidenceRootPath (
        "balanced-wave-$candidateSlug-reference-$sourceShort\report.json"
    )
    $materialPath = Join-Path $evidenceRootPath (
        "balanced-wave-$candidateSlug-opened-bw2-material-$sourceShort\report.json"
    )
    $counterexamplePath = Join-Path $evidenceRootPath (
        "balanced-wave-$candidateSlug-opened-counterexamples-$sourceShort\report.json"
    )
    $bw3rPath = Join-Path $evidenceRootPath (
        "balanced-wave-$candidateSlug-opened-bw3r-$sourceShort\report.json"
    )
    $bw4Path = Join-Path $evidenceRootPath (
        "balanced-wave-$candidateSlug-opened-bw4-$sourceShort\report.json"
    )

    Invoke-OrResumeRetainedCampaign `
        -Candidate $candidate `
        -Role "reference" `
        -ReportPath $referencePath `
        -ExpectedWorldCount 2 `
        -SourceCommit $sourceCommit `
        -ScriptPath (Join-Path $sdkRoot "run_balanced_wave_bw2_reference_pair.ps1") `
        -Arguments ([ordered]@{
            Godot = $godotPath
            Candidate = $candidate
            Output = $referencePath
        })
    Invoke-OrResumeRetainedCampaign `
        -Candidate $candidate `
        -Role "material" `
        -ReportPath $materialPath `
        -ExpectedWorldCount 23 `
        -SourceCommit $sourceCommit `
        -ScriptPath (Join-Path $sdkRoot "run_balanced_wave_bw2_material_matrix.ps1") `
        -Arguments ([ordered]@{
            Godot = $godotPath
            Candidate = $candidate
            Output = $materialPath
        })
    Invoke-OrResumeRetainedCampaign `
        -Candidate $candidate `
        -Role "counterexamples" `
        -ReportPath $counterexamplePath `
        -ExpectedWorldCount 4 `
        -SourceCommit $sourceCommit `
        -ScriptPath (Join-Path $sdkRoot "run_balanced_wave_bw2_counterexamples.ps1") `
        -Arguments ([ordered]@{
            Godot = $godotPath
            Candidate = $candidate
            Output = $counterexamplePath
        })
    Invoke-OrResumeRetainedCampaign `
        -Candidate $candidate `
        -Role "opened_bw3r" `
        -ReportPath $bw3rPath `
        -ExpectedWorldCount 12 `
        -SourceCommit $sourceCommit `
        -ScriptPath (Join-Path $sdkRoot "run_balanced_wave_bw3_validation.ps1") `
        -Arguments ([ordered]@{
            Godot = $godotPath
            Campaign = "BW3R"
            Candidate = $candidate
            Output = $bw3rPath
        })
    Invoke-OrResumeRetainedCampaign `
        -Candidate $candidate `
        -Role "opened_bw4" `
        -ReportPath $bw4Path `
        -ExpectedWorldCount 17 `
        -SourceCommit $sourceCommit `
        -ScriptPath (Join-Path $sdkRoot "run_balanced_wave_bw4_validation.ps1") `
        -Arguments ([ordered]@{
            Godot = $godotPath
            Candidate = $candidate
            Output = $bw4Path
        })

    $reportSets += [ordered]@{
        candidate_id = $candidate
        reference = $referencePath
        material = $materialPath
        counterexamples = $counterexamplePath
        opened_bw3r = $bw3rPath
        opened_bw4 = $bw4Path
    }
}

$sourceAfterCampaigns = Get-SourceState
Assert-Exact (
    [bool]$sourceAfterCampaigns.clean -and
    [bool]$sourceAfterCampaigns.matches_origin_main -and
    [string]$sourceAfterCampaigns.commit -ceq $sourceCommit
) "Source changed during the complete BW4R development matrix"

$selectionPath = Join-Path $evidenceRootPath (
    "balanced-wave-bw4r-selection-$sourceShort\report.json"
)
if (-not (Test-Path -LiteralPath $selectionPath -PathType Leaf)) {
    & (Join-Path $sdkRoot "compile_balanced_wave_bw4r_selection.ps1") `
        -ReferenceReport @($reportSets | ForEach-Object { $_.reference }) `
        -MaterialReport @($reportSets | ForEach-Object { $_.material }) `
        -CounterexampleReport @($reportSets | ForEach-Object { $_.counterexamples }) `
        -OpenedBw3rReplayReport @($reportSets | ForEach-Object { $_.opened_bw3r }) `
        -OpenedBw4ReplayReport @($reportSets | ForEach-Object { $_.opened_bw4 }) `
        -Output $selectionPath
    if ($LASTEXITCODE -ne 0) {
        throw "BW4R selection compiler failed with exit code $LASTEXITCODE"
    }
} else {
    Write-Host "BW4R resume found existing selection report: $selectionPath"
}

$selection = Get-Content -LiteralPath $selectionPath -Raw |
    ConvertFrom-Json -AsHashtable
$expectedInputPaths = @(
    foreach ($reportSet in $reportSets) {
        [string]$reportSet.reference
        [string]$reportSet.material
        [string]$reportSet.counterexamples
        [string]$reportSet.opened_bw3r
        [string]$reportSet.opened_bw4
    }
)
$selectionInputs = @($selection.inputs)
$selectionInputsExact = $selectionInputs.Count -eq $expectedInputPaths.Count
foreach ($expectedInputPath in $expectedInputPaths) {
    $matches = @(
        $selectionInputs |
            Where-Object {
                [string]$_['path'] -ceq $expectedInputPath -and
                [string]$_['source_commit'] -ceq $sourceCommit
            }
    )
    $selectionInputsExact = (
        $selectionInputsExact -and
        $matches.Count -eq 1 -and
        [string]$matches[0].sha256 -ceq (Get-Sha256 $expectedInputPath)
    )
}
$selectionSourcesExact = $true
foreach ($source in $selection.sources.GetEnumerator()) {
    $sourcePath = Join-Path $repoRoot ([string]$source.Value.path)
    $selectionSourcesExact = (
        $selectionSourcesExact -and
        (Test-Path -LiteralPath $sourcePath -PathType Leaf) -and
        [string]$source.Value.sha256 -ceq (Get-Sha256 $sourcePath)
    )
}
$selectedCandidateValid = if ([bool]$selection.family_rejected) {
    [string]::IsNullOrWhiteSpace([string]$selection.selected_candidate_id)
} else {
    [string]$selection.selected_candidate_id -cin @("BW4R-A", "BW4R-B")
}
Assert-Exact (
    [string]$selection.schema_version -ceq
        "sporespore_balanced_wave_bw4r_selection_report_v1" -and
    [string]$selection.source_commit -ceq $sourceCommit -and
    [bool]$selection.source_worktree_clean -and
    [bool]$selection.source_matches_origin_main -and
    [bool]$selection.accepted -and
    [bool]$selection.development_data_only -and
    [int]$selection.expected_world_count -eq 116 -and
    [int]$selection.observed_world_count -eq 116 -and
    [int]$selection.input_report_count -eq 10 -and
    [int]$selection.candidate_count -eq 2 -and
    [bool]$selection.complete_matrix_per_candidate -and
    [string]$selection.preregistration_sha256 -ceq
        (Get-Sha256 (Join-Path $sdkRoot "balanced_wave_bw4r_preregistration.json")) -and
    $selectionInputsExact -and
    $selectionSourcesExact -and
    $selectedCandidateValid -and
    -not [bool]$selection.walking_acceptance -and
    -not [bool]$selection.material_robustness -and
    -not [bool]$selection.cross_engine_c6 -and
    -not [bool]$selection.completed_engine_neutral_sdk -and
    -not [bool]$selection.physical_acceptance_authority
) "Retained BW4R selection report is invalid"

Write-Host "BW4R complete development selection report: $selectionPath"
if ([bool]$selection.family_rejected) {
    Write-Host "BW4R complete 116-world candidate family was rejected."
} else {
    Write-Host (
        "BW4R selected $($selection.selected_candidate_id) by " +
        "$($selection.deciding_metric). New validation remains mandatory."
    )
}

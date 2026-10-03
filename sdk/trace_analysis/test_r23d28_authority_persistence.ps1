#requires -Version 7.0

# Focused zero-world persistence diagnosis over immutable R23D28 CAS traces.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$contractPath = Join-Path $PSScriptRoot "retained_trace_lineage_contract_v1.json"
$manifestPath = Join-Path $PSScriptRoot (
    "r23d28_authority_persistence_analysis_manifest_v1.json"
)
$analyzerPath = Join-Path $PSScriptRoot "analyze_retained_trace_lineage.py"
$evidenceRoot = Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence"

function Assert-R23D28Persistence([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "R23D28_AUTHORITY_PERSISTENCE: $Message" }
}

function Get-R23D28GitBlobSha256([string]$Commit, [string]$RelativePath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $repoRoot, "cat-file", "blob", "${Commit}:$RelativePath"
    )) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        Assert-R23D28Persistence $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D28Persistence ($process.ExitCode -eq 0) (
            "Git blob read failed for ${RelativePath}: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Invoke-R23D28PersistenceAnalyzer(
    [string]$Python,
    [string]$InputManifest,
    [string]$OutputPath
) {
    $output = & $Python $analyzerPath `
        --manifest $InputManifest `
        --evidence-root $evidenceRoot `
        --analyzer-source-commit ((git -C $repoRoot rev-parse HEAD).Trim()) `
        --output $OutputPath 2>&1 | Out-String
    return [ordered]@{ output = $output; exit_code = $LASTEXITCODE }
}

Assert-R23D28Persistence (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace('\', '/') -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @($contractPath, $manifestPath, $analyzerPath, $evidenceRoot)) {
    Assert-R23D28Persistence (Test-Path -LiteralPath $path) "missing path: $path"
}

$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$manifest = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$sourceClosure = $manifest.source_closure
$projection = $manifest.trace_contract.steering_floor_hold_projection
$closureCommit = [string]$sourceClosure.source_commit
$closureRelative = [string]$sourceClosure.path
Assert-R23D28Persistence (
    [string]$contract.schema_version -ceq
        "sporespore_retained_trace_lineage_contract_v1" -and
    [bool]$contract.steering_floor_persistence_diagnosis_boundary.
        hold_duration_grid_must_be_simultaneously_manifest_bound -and
    [bool]$contract.steering_floor_persistence_diagnosis_boundary.
        every_duration_must_be_an_integer_multiple_of_the_declared_scheduler_swing -and
    [bool]$contract.steering_floor_persistence_diagnosis_boundary.
        projection_may_mask_recorded_authority_but_may_not_recompute_commands_or_physics -and
    [bool]$contract.steering_floor_persistence_diagnosis_boundary.
        descriptive_projection_cannot_claim_counterfactual_recovery -and
    [string]$manifest.analysis_id -ceq
        "QSDK-R23D28-AUTHORITY-PERSISTENCE-D1" -and
    [string]$manifest.question_class -ceq "postclosure_development_diagnosis" -and
    [bool]$manifest.data_exposure_boundary.r23d28_outcomes_already_observed -and
    [bool]$manifest.data_exposure_boundary.projection_is_descriptive_not_confirmatory -and
    -not [bool]$manifest.data_exposure_boundary.future_controller_parameter_selected_by_this_analysis -and
    [bool]$projection.enabled -and
    [int]$projection.scheduler_swing_steps -eq 72 -and
    [int]$projection.scheduler_cycle_steps -eq 360 -and
    (@($projection.hold_duration_steps) -join ',') -ceq "72,144,216,288,360" -and
    [double]$projection.full_authority_maximum_tilt_rad -eq 0.1 -and
    [double]$projection.baseline_maximum_steering_fraction -eq 0.2 -and
    [double]$projection.expanded_maximum_steering_fraction -eq 0.28 -and
    @($manifest.cells).Count -eq 3 -and
    (git -C $repoRoot rev-parse "${closureCommit}:${closureRelative}").Trim() -ceq
        [string]$sourceClosure.git_blob_oid -and
    (Get-R23D28GitBlobSha256 $closureCommit $closureRelative) -ceq
        [string]$sourceClosure.raw_sha256
) "contract, manifest, or immutable closure binding changed"

foreach ($cell in $manifest.cells) {
    $digest = [string]$cell.trace_sha256
    $payload = Join-Path $evidenceRoot (
        "artifacts\sha256\" + $digest.Substring(7) + "\payload.bin"
    )
    Assert-R23D28Persistence (
        $digest -match '^sha256:[0-9a-f]{64}$' -and
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq [long]$cell.trace_byte_length -and
        ("sha256:" + (
            Get-FileHash -LiteralPath $payload -Algorithm SHA256
        ).Hash.ToLowerInvariant()) -ceq $digest
    ) "CAS trace identity changed for $($cell.cell_id)"
}

$pythonMatches = @(Get-Command python.exe -CommandType Application -ErrorAction Stop)
Assert-R23D28Persistence ($pythonMatches.Count -ge 1) "python.exe unavailable"
$python = [IO.Path]::GetFullPath([string]$pythonMatches[0].Source)
$testRoot = Join-Path ([IO.Path]::GetTempPath()) (
    "sporespore-r23d28-persistence-" + [guid]::NewGuid().ToString("N")
)
$resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$resolvedTest = [IO.Path]::GetFullPath($testRoot)
Assert-R23D28Persistence (
    $resolvedTest.StartsWith(
        $resolvedTemp + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    (Split-Path -Leaf $resolvedTest).StartsWith(
        "sporespore-r23d28-persistence-",
        [StringComparison]::Ordinal
    )
) "temporary mutation root escaped the system temp directory"
[void][IO.Directory]::CreateDirectory($resolvedTest)

try {
    $reportPath = Join-Path $resolvedTest "report.json"
    $run = Invoke-R23D28PersistenceAnalyzer $python $manifestPath $reportPath
    Assert-R23D28Persistence ($run.exit_code -eq 0) (
        "real CAS analysis failed: $($run.output)"
    )
    $prefix = "RETAINED_TRACE_LINEAGE_PASS "
    $markers = @(($run.output -split '\r?\n') | Where-Object {
        $_.StartsWith($prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D28Persistence ($markers.Count -eq 1) "analysis marker count changed"
    $report = $markers[0].Substring($prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
    $reference = @($report.cells | Where-Object arm_id -eq "reference_zero")[0]
    $positive = @($report.cells | Where-Object arm_id -eq "positive_heading")[0]
    $negative = @($report.cells | Where-Object arm_id -eq "negative_heading")[0]
    $summary = $report.steering_floor_hold_summary

    Assert-R23D28Persistence (
        [string]$report.schema_version -ceq
            "sporespore_retained_trace_lineage_report_v1" -and
        [int]$report.input_summary.cell_count -eq 3 -and
        [long]$report.input_summary.total_trace_byte_length -eq 32640009 -and
        [int]$report.input_summary.total_trace_row_count -eq 8976 -and
        [int]$reference.steering_floor_hold.observed_floor_row_count -eq 0 -and
        $null -eq $reference.steering_floor_hold.first_actual_full_authority_tilt_exceeded_step -and
        [int]$positive.steering_floor_hold.observed_floor_row_count -eq 853 -and
        [int]$positive.steering_floor_hold.observed_floor_episode_count -eq 2 -and
        [int]$positive.steering_floor_hold.first_observed_floor_step -eq 839 -and
        [int]$positive.steering_floor_hold.first_actual_full_authority_tilt_exceeded_step -eq 975 -and
        [int]$negative.steering_floor_hold.observed_floor_row_count -eq 1042 -and
        [int]$negative.steering_floor_hold.observed_floor_episode_count -eq 2 -and
        [int]$negative.steering_floor_hold.first_observed_floor_step -eq 646 -and
        [int]$negative.steering_floor_hold.first_actual_full_authority_tilt_exceeded_step -eq 784 -and
        (@($positive.steering_floor_hold.durations | ForEach-Object {
            [int]$_.expanded_authority_reopened_row_count_after_first_floor_before_actual_full_tilt_exceeded
        }) -join ',') -ceq "25,0,0,0,0" -and
        (@($negative.steering_floor_hold.durations | ForEach-Object {
            [int]$_.expanded_authority_reopened_row_count_after_first_floor_before_actual_full_tilt_exceeded
        }) -join ',') -ceq "32,0,0,0,0" -and
        [int]$summary.smallest_declared_duration_satisfying_replay_property_steps -eq 144 -and
        (@($summary.durations | ForEach-Object {
            [int]$_.commanded_expanded_authority_reopened_row_count_before_actual_full_tilt_exceeded
        }) -join ',') -ceq "57,0,0,0,0" -and
        -not [bool]$summary.future_controller_parameter_authorized -and
        -not [bool]$summary.candidate_selection_authorized -and
        -not [bool]$summary.counterfactual_physical_outcome_claimed -and
        -not [bool]$summary.physical_execution_authorized -and
        [int]$report.model_construction_count -eq 0 -and
        [int]$report.world_attempt_count -eq 0 -and
        [int]$report.world_build_count -eq 0 -and
        -not [bool]$report.turning_validation -and
        -not [bool]$report.physical_acceptance_authority
    ) "authority persistence projection or claim boundary changed"

    $mutations = @(
        [ordered]@{
            name = "duration_order"
            expected = "TRACE_LINEAGE_STEERING_FLOOR_HOLD_DURATIONS"
            mutate = { param($copy)
                $copy.trace_contract.steering_floor_hold_projection.hold_duration_steps = @(144, 72)
            }
        },
        [ordered]@{
            name = "non_swing_duration"
            expected = "TRACE_LINEAGE_STEERING_FLOOR_HOLD_DURATIONS"
            mutate = { param($copy)
                $copy.trace_contract.steering_floor_hold_projection.hold_duration_steps = @(73)
            }
        },
        [ordered]@{
            name = "changed_baseline"
            expected = "TRACE_LINEAGE_STEERING_FLOOR_HOLD_GUARD_BOUNDS"
            mutate = { param($copy)
                $copy.trace_contract.steering_floor_hold_projection.
                    baseline_maximum_steering_fraction = 0.19
            }
        },
        [ordered]@{
            name = "missing_cas"
            expected = "TRACE_LINEAGE_CAS_OBJECT_MISSING"
            mutate = { param($copy)
                $copy.cells[0].trace_sha256 = "sha256:" + ("0" * 64)
            }
        }
    )
    foreach ($mutation in $mutations) {
        $copy = Get-Content -LiteralPath $manifestPath -Raw |
            ConvertFrom-Json -AsHashtable -Depth 100
        & $mutation.mutate $copy
        $mutatedPath = Join-Path $resolvedTest "$($mutation.name).json"
        [IO.File]::WriteAllText(
            $mutatedPath,
            ($copy | ConvertTo-Json -Depth 100) + "`n",
            [Text.UTF8Encoding]::new($false)
        )
        $mutatedOutput = Join-Path $resolvedTest "$($mutation.name)-report.json"
        $mutatedRun = Invoke-R23D28PersistenceAnalyzer $python $mutatedPath $mutatedOutput
        Assert-R23D28Persistence (
            $mutatedRun.exit_code -ne 0 -and
            $mutatedRun.output.Contains([string]$mutation.expected)
        ) "mutation did not fail closed: $($mutation.name): $($mutatedRun.output)"
    }

    $rerun = Invoke-R23D28PersistenceAnalyzer $python $manifestPath $reportPath
    Assert-R23D28Persistence (
        $rerun.exit_code -ne 0 -and
        $rerun.output.Contains("TRACE_LINEAGE_OUTPUT_EXISTS")
    ) "create-only output refusal changed"
} finally {
    if (Test-Path -LiteralPath $resolvedTest) {
        $rechecked = [IO.Path]::GetFullPath($resolvedTest)
        Assert-R23D28Persistence (
            $rechecked.StartsWith(
                $resolvedTemp + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            ) -and
            (Split-Path -Leaf $rechecked).StartsWith(
                "sporespore-r23d28-persistence-",
                [StringComparison]::Ordinal
            )
        ) "refusing unsafe temporary cleanup"
        Remove-Item -LiteralPath $rechecked -Recurse -Force
    }
}

Write-Host (
    "R23D28_AUTHORITY_PERSISTENCE_PASS cells=3 rows=8976 durations=5 " +
    "smallest_descriptive_hold_steps=144 one_swing_reopenings=57 " +
    "reference_floor_rows=0 mutations=4 models=0 worlds=0 " +
    "selection=False counterfactual_recovery=False physical=False"
)

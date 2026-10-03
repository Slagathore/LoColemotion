#requires -Version 7.0

# Focused zero-world diagnosis for the immutable R23D27 retained traces.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$analysisRoot = Join-Path $repoRoot "sdk\trace_analysis"
$contractPath = Join-Path $analysisRoot "retained_trace_lineage_contract_v1.json"
$manifestPath = Join-Path $analysisRoot "r23d27_predictive_tilt_analysis_manifest_v1.json"
$analyzerPath = Join-Path $analysisRoot "analyze_retained_trace_lineage.py"
$evidenceRoot = Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence"

function Assert-R23D27TiltDiagnosis([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "R23D27_TILT_DIAGNOSIS: $Message" }
}

function Get-R23D27GitBlobSha256([string]$Commit, [string]$RelativePath) {
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
        Assert-R23D27TiltDiagnosis $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D27TiltDiagnosis ($process.ExitCode -eq 0) (
            "Git blob read failed for ${RelativePath}: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Invoke-R23D27TiltAnalyzer(
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

Assert-R23D27TiltDiagnosis (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace('\', '/') -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @(
    $contractPath,
    $manifestPath,
    $analyzerPath,
    $evidenceRoot
)) {
    Assert-R23D27TiltDiagnosis (Test-Path -LiteralPath $path) "missing path: $path"
}

$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$manifest = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$sourceClosure = $manifest.source_closure
$closureCommit = [string]$sourceClosure.source_commit
$closureRelative = [string]$sourceClosure.path
$projection = $manifest.trace_contract.tilt_precursor_projection
Assert-R23D27TiltDiagnosis (
    [string]$contract.schema_version -ceq
        "sporespore_retained_trace_lineage_contract_v1" -and
    [bool]$contract.predictive_tilt_diagnosis_boundary.
        finite_difference_windows_must_be_simultaneously_manifest_bound -and
    [bool]$contract.predictive_tilt_diagnosis_boundary.
        prediction_horizon_requires_scheduler_or_dimensional_provenance -and
    [bool]$contract.predictive_tilt_diagnosis_boundary.
        descriptive_projection_cannot_claim_counterfactual_recovery -and
    [string]$manifest.analysis_id -ceq
        "QSDK-R23D27-PREDICTIVE-TILT-PRECURSOR-D1" -and
    [string]$manifest.question_class -ceq "postclosure_development_diagnosis" -and
    [bool]$manifest.data_exposure_boundary.r23d27_outcomes_already_observed -and
    [bool]$manifest.data_exposure_boundary.projection_is_descriptive_not_confirmatory -and
    -not [bool]$manifest.data_exposure_boundary.future_controller_window_selected_from_this_analysis -and
    @($manifest.cells).Count -eq 3 -and
    @($manifest.comparison_groups).Count -eq 1 -and
    [int]$manifest.trace_contract.expected_row_count -eq 2992 -and
    [string]$manifest.trace_contract.analysis_phase_id -ceq "commanded_turn" -and
    [bool]$projection.enabled -and
    [int]$projection.physics_hz -eq 120 -and
    @($projection.finite_difference_window_steps).Count -eq 7 -and
    (@($projection.finite_difference_window_steps) -join ',') -ceq
        "4,8,12,24,36,60,72" -and
    [double]$projection.prediction_horizon_s -eq 0.6 -and
    [double]$projection.full_authority_maximum_tilt_rad -eq 0.1 -and
    [double]$projection.minimum_authority_tilt_rad -eq 0.2 -and
    -not [bool]$manifest.replayed_thresholds.threshold_change_authorized -and
    (git -C $repoRoot rev-parse "${closureCommit}:${closureRelative}").Trim() -ceq
        [string]$sourceClosure.git_blob_oid -and
    (Get-R23D27GitBlobSha256 $closureCommit $closureRelative) -ceq
        [string]$sourceClosure.raw_sha256
) "contract, manifest, or immutable closure binding changed"

$uniqueDigests = @($manifest.cells | ForEach-Object { [string]$_.trace_sha256 } |
    Sort-Object -Unique)
Assert-R23D27TiltDiagnosis ($uniqueDigests.Count -eq 3) "trace digests are not unique"
foreach ($cell in $manifest.cells) {
    $digest = [string]$cell.trace_sha256
    Assert-R23D27TiltDiagnosis (
        $digest -match '^sha256:[0-9a-f]{64}$' -and
        [long]$cell.trace_byte_length -gt 0
    ) "invalid trace identity for $($cell.cell_id)"
    $payload = Join-Path $evidenceRoot (
        "artifacts\sha256\" + $digest.Substring(7) + "\payload.bin"
    )
    Assert-R23D27TiltDiagnosis (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq [long]$cell.trace_byte_length -and
        ("sha256:" + (
            Get-FileHash -LiteralPath $payload -Algorithm SHA256
        ).Hash.ToLowerInvariant()) -ceq $digest
    ) "CAS trace identity changed for $($cell.cell_id)"
}

$analyzerSource = Get-Content -LiteralPath $analyzerPath -Raw
foreach ($forbidden in @(
    "import mujoco",
    "import rapier",
    "import godot",
    "import subprocess",
    "PhysicsServer",
    "mj_step("
)) {
    Assert-R23D27TiltDiagnosis (-not $analyzerSource.Contains($forbidden)) (
        "analyzer gained physical dependency: $forbidden"
    )
}

$pythonMatches = @(Get-Command python.exe -CommandType Application -ErrorAction Stop)
Assert-R23D27TiltDiagnosis ($pythonMatches.Count -ge 1) "python.exe unavailable"
$python = [IO.Path]::GetFullPath([string]$pythonMatches[0].Source)
$testRoot = Join-Path ([IO.Path]::GetTempPath()) (
    "sporespore-r23d27-tilt-diagnosis-" + [guid]::NewGuid().ToString("N")
)
$resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$resolvedTest = [IO.Path]::GetFullPath($testRoot)
Assert-R23D27TiltDiagnosis (
    $resolvedTest.StartsWith(
        $resolvedTemp + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    (Split-Path -Leaf $resolvedTest).StartsWith(
        "sporespore-r23d27-tilt-diagnosis-",
        [StringComparison]::Ordinal
    )
) "temporary mutation root escaped the system temp directory"
[void][IO.Directory]::CreateDirectory($resolvedTest)

try {
    $reportPath = Join-Path $resolvedTest "report.json"
    $run = Invoke-R23D27TiltAnalyzer $python $manifestPath $reportPath
    Assert-R23D27TiltDiagnosis ($run.exit_code -eq 0) (
        "real CAS analysis failed: $($run.output)"
    )
    $prefix = "RETAINED_TRACE_LINEAGE_PASS "
    $markers = @(($run.output -split '\r?\n') | Where-Object {
        $_.StartsWith($prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D27TiltDiagnosis ($markers.Count -eq 1) "analysis marker count changed"
    $report = $markers[0].Substring($prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
    $reference = @($report.cells | Where-Object {
        [string]$_.arm_id -ceq "reference_zero"
    })
    $positive = @($report.cells | Where-Object {
        [string]$_.arm_id -ceq "positive_heading"
    })
    $negative = @($report.cells | Where-Object {
        [string]$_.arm_id -ceq "negative_heading"
    })
    Assert-R23D27TiltDiagnosis (
        [string]$report.schema_version -ceq
            "sporespore_retained_trace_lineage_report_v1" -and
        [int]$report.input_summary.cell_count -eq 3 -and
        [long]$report.input_summary.total_trace_byte_length -eq 29252801 -and
        [int]$report.input_summary.total_trace_row_count -eq 8976 -and
        @($report.comparisons).Count -eq 1 -and
        $reference.Count -eq 1 -and
        $positive.Count -eq 1 -and
        $negative.Count -eq 1 -and
        [int]$report.observability.complete_limiting_actuator_cell_count -eq 3
    ) "report shape or complete actuator observability changed"

    $positiveProjection = $positive[0].tilt_precursor
    $negativeProjection = $negative[0].tilt_precursor
    $referenceProjection = $reference[0].tilt_precursor
    Assert-R23D27TiltDiagnosis (
        [string]$positiveProjection.status -ceq
            "descriptive_postclosure_projection_only" -and
        [int]$positiveProjection.first_actual_full_authority_tilt_exceeded_step -eq 975 -and
        [int]$positiveProjection.observed_first_guard_reduction_step -eq 976 -and
        [int]$positiveProjection.observed_first_guard_floor_step -eq 1033 -and
        (@($positiveProjection.windows | ForEach-Object {
            [int]$_.first_projected_minimum_authority_tilt_reached_step
        }) -join ',') -ceq "840,952,954,959,966,978,982" -and
        (@($positiveProjection.windows | ForEach-Object {
            [int]$_.projected_floor_lead_over_observed_guard_reduction_steps
        }) -join ',') -ceq "136,24,22,17,10,-2,-6" -and
        [int]$negativeProjection.first_actual_full_authority_tilt_exceeded_step -eq 785 -and
        [int]$negativeProjection.observed_first_guard_reduction_step -eq 786 -and
        [int]$negativeProjection.observed_first_guard_floor_step -eq 819 -and
        (@($negativeProjection.windows | ForEach-Object {
            [int]$_.first_projected_minimum_authority_tilt_reached_step
        }) -join ',') -ceq "646,763,765,771,777,787,791" -and
        (@($negativeProjection.windows | ForEach-Object {
            [int]$_.projected_floor_lead_over_observed_guard_reduction_steps
        }) -join ',') -ceq "140,23,21,15,9,-1,-5" -and
        $null -eq $referenceProjection.first_actual_full_authority_tilt_exceeded_step -and
        $null -eq $referenceProjection.observed_first_guard_reduction_step -and
        $null -eq $referenceProjection.observed_first_guard_floor_step -and
        @($referenceProjection.windows | Where-Object {
            $null -ne $_.first_projected_minimum_authority_tilt_reached_step
        }).Count -eq 0 -and
        $null -eq $positiveProjection.window_selected_for_future_controller -and
        -not [bool]$positiveProjection.counterfactual_physical_outcome_claimed -and
        -not [bool]$positiveProjection.successor_physical_authority
    ) "predictive tilt precursor projection changed"

    Assert-R23D27TiltDiagnosis (
        [int]$report.model_construction_count -eq 0 -and
        [int]$report.world_attempt_count -eq 0 -and
        [int]$report.world_build_count -eq 0 -and
        -not [bool]$report.closed_campaign_reinterpreted -and
        -not [bool]$report.candidate_selection_authorized -and
        -not [bool]$report.threshold_change_authorized -and
        -not [bool]$report.physical_campaign_opened -and
        -not [bool]$report.physical_execution_authorized -and
        -not [bool]$report.turning_validation -and
        -not [bool]$report.cross_engine_equivalence -and
        -not [bool]$report.release_authorized -and
        -not [bool]$report.physical_acceptance_authority
    ) "diagnostic claim boundary changed"

    $mutations = @(
        [ordered]@{
            name = "window_order"
            expected = "TRACE_LINEAGE_TILT_PRECURSOR_WINDOWS"
            mutate = { param($copy)
                $copy.trace_contract.tilt_precursor_projection.
                    finite_difference_window_steps = @(8, 4)
            }
        },
        [ordered]@{
            name = "zero_horizon"
            expected = "TRACE_LINEAGE_TILT_PRECURSOR_PARAMETERS"
            mutate = { param($copy)
                $copy.trace_contract.tilt_precursor_projection.prediction_horizon_s = 0.0
            }
        },
        [ordered]@{
            name = "disabled_projection"
            expected = "TRACE_LINEAGE_TILT_PRECURSOR_ENABLED"
            mutate = { param($copy)
                $copy.trace_contract.tilt_precursor_projection.enabled = $false
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
        $mutatedRun = Invoke-R23D27TiltAnalyzer $python $mutatedPath $mutatedOutput
        Assert-R23D27TiltDiagnosis (
            $mutatedRun.exit_code -ne 0 -and
            $mutatedRun.output.Contains([string]$mutation.expected)
        ) "mutation did not fail closed: $($mutation.name): $($mutatedRun.output)"
    }

    $rerun = Invoke-R23D27TiltAnalyzer $python $manifestPath $reportPath
    Assert-R23D27TiltDiagnosis (
        $rerun.exit_code -ne 0 -and
        $rerun.output.Contains("TRACE_LINEAGE_OUTPUT_EXISTS")
    ) "create-only output refusal changed"
} finally {
    if (Test-Path -LiteralPath $resolvedTest) {
        $rechecked = [IO.Path]::GetFullPath($resolvedTest)
        Assert-R23D27TiltDiagnosis (
            $rechecked.StartsWith(
                $resolvedTemp + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            ) -and
            (Split-Path -Leaf $rechecked).StartsWith(
                "sporespore-r23d27-tilt-diagnosis-",
                [StringComparison]::Ordinal
            )
        ) "refusing unsafe temporary cleanup"
        Remove-Item -LiteralPath $rechecked -Recurse -Force
    }
}

Write-Host (
    "R23D27_PREDICTIVE_TILT_DIAGNOSIS_PASS cells=3 rows=8976 windows=7 " +
    "commanded_precursors=2 reference_floor_crossings=0 mutations=5 " +
    "models=0 worlds=0 selection=False threshold_change=False " +
    "counterfactual_recovery=False physical=False"
)

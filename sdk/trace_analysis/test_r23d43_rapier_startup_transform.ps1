#requires -Version 7.0

# Zero-world regression and mutation controls for the R23D43 retained-trace diagnosis.

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$manifestPath = Join-Path $PSScriptRoot (
    "r23d43_rapier_startup_transform_analysis_manifest_v1.json"
)
$analyzerPath = Join-Path $PSScriptRoot (
    "analyze_r23d43_rapier_startup_transform.py"
)
$evidenceRoot = Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence"

function Assert-R23D43StartupTransform([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "R23D43_STARTUP_TRANSFORM: $Message" }
}

function Assert-R23D43Close(
    [double]$Actual,
    [double]$Expected,
    [double]$Tolerance,
    [string]$Message
) {
    Assert-R23D43StartupTransform (
        [Math]::Abs($Actual - $Expected) -le $Tolerance
    ) "$Message actual=$Actual expected=$Expected tolerance=$Tolerance"
}

function Get-R23D43GitBlobSha256([string]$Commit, [string]$RelativePath) {
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
        Assert-R23D43StartupTransform $process.Start() (
            "could not start Git blob reader"
        )
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D43StartupTransform ($process.ExitCode -eq 0) (
            "Git blob read failed for ${RelativePath}: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Invoke-R23D43StartupTransformAnalyzer(
    [string]$Python,
    [string]$InputManifest,
    [string]$OutputPath
) {
    $output = & $Python $analyzerPath `
        --manifest $InputManifest `
        --evidence-root $evidenceRoot `
        --analyzer-source-commit ((git -C $repoRoot rev-parse HEAD).Trim()) `
        --output $OutputPath 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    return [ordered]@{ output = $output; exit_code = $exitCode }
}

Assert-R23D43StartupTransform (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace('\', '/') -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @($manifestPath, $analyzerPath, $evidenceRoot)) {
    Assert-R23D43StartupTransform (Test-Path -LiteralPath $path) (
        "missing path: $path"
    )
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$contract = $manifest.analysis_contract
$provenance = $manifest.threshold_provenance
$decision = $manifest.decision_boundary
Assert-R23D43StartupTransform (
    [string]$manifest.schema_version -ceq
        "sporespore_r23d43_rapier_startup_transform_analysis_manifest_v1" -and
    [string]$manifest.analysis_id -ceq
        "QSDK-R23D43-RAPIER-STARTUP-TRANSFORM-D1" -and
    [string]$manifest.question_class -ceq
        "postclosure_development_diagnosis" -and
    [bool]$manifest.data_exposure_boundary.all_six_campaign_outcomes_already_observed -and
    [bool]$manifest.data_exposure_boundary.projection_is_descriptive_not_confirmatory -and
    [bool]$manifest.data_exposure_boundary.startup_transform_and_seed_are_confounded -and
    -not [bool]$manifest.data_exposure_boundary.causal_startup_transform_effect_identified -and
    [string]$contract.engine_id -ceq "rapier_parry" -and
    [int]$contract.physics_hz -eq 120 -and
    [int]$contract.expected_row_count_per_cell -eq 2992 -and
    (@($contract.ordered_arm_ids) -join ',') -ceq
        "reference_zero,positive_heading,negative_heading" -and
    (@($contract.baseline_window) -join ',') -ceq "240,600" -and
    (@($contract.terminal_window) -join ',') -ceq "1440,1800" -and
    [double]$provenance.minimum_cycle_shift_rad -eq 0.01 -and
    [double]$provenance.heading_command_magnitude_rad -eq 0.2 -and
    [double]$provenance.command_fraction -eq 0.05 -and
    -not [bool]$provenance.calibrated_release_acceptance_margin -and
    -not [bool]$provenance.calibrated_population_margin -and
    -not [bool]$provenance.calibrated_cross_engine_equivalence_margin -and
    -not [bool]$provenance.threshold_change_authorized -and
    [bool]$decision.retained_r23d43_turning_passes_after_path_identity_projection -eq $false -and
    [bool]$decision.verifier_only_successor_sufficient -eq $false -and
    [bool]$decision.paired_outcome_exposed_startup_transform_development_is_the_next_testable_question -and
    -not [bool]$decision.paired_screen_can_satisfy_qsdk_r23 -and
    -not [bool]$decision.paired_screen_can_consume_a_new_held_out_validation_seed -and
    @($manifest.campaigns).Count -eq 6 -and
    @($manifest.groups).Count -eq 2 -and
    @($manifest.claim_limits.Keys).Count -eq 12 -and
    @($manifest.claim_limits.Values | Where-Object { [bool]$_ }).Count -eq 0
) "manifest identity, threshold provenance, or claim boundary changed"

foreach ($campaign in $manifest.campaigns) {
    $closure = $campaign.closure
    $closureCommit = [string]$closure.git_commit
    $closureRelative = [string]$closure.path
    Assert-R23D43StartupTransform (
        (git -C $repoRoot rev-parse "${closureCommit}:${closureRelative}").Trim() -ceq
            [string]$closure.git_blob_oid -and
        (Get-R23D43GitBlobSha256 $closureCommit $closureRelative) -ceq
            [string]$closure.raw_sha256 -and
        @($campaign.cells).Count -eq 3
    ) "immutable closure binding changed for $($campaign.campaign_key)"

    foreach ($cell in $campaign.cells) {
        $digest = [string]$cell.trace_sha256
        $payload = Join-Path $evidenceRoot (
            "artifacts\sha256\" + $digest.Substring(7) + "\payload.bin"
        )
        $casManifest = Join-Path (Split-Path -Parent $payload) "manifest.json"
        Assert-R23D43StartupTransform (
            $digest -match '^sha256:[0-9a-f]{64}$' -and
            (Test-Path -LiteralPath $payload -PathType Leaf) -and
            (Test-Path -LiteralPath $casManifest -PathType Leaf) -and
            (Get-Item -LiteralPath $payload).Length -eq
                [long]$cell.trace_byte_length -and
            ("sha256:" + (
                Get-FileHash -LiteralPath $payload -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -ceq $digest
        ) "CAS trace identity changed for $($campaign.campaign_key):$($cell.arm_id)"
    }
}

$pythonMatches = @(Get-Command python.exe -CommandType Application -ErrorAction Stop)
Assert-R23D43StartupTransform ($pythonMatches.Count -ge 1) "python.exe unavailable"
$python = [IO.Path]::GetFullPath([string]$pythonMatches[0].Source)
$testRoot = Join-Path ([IO.Path]::GetTempPath()) (
    "sporespore-r23d43-startup-transform-" + [guid]::NewGuid().ToString("N")
)
$resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$resolvedTest = [IO.Path]::GetFullPath($testRoot)
Assert-R23D43StartupTransform (
    $resolvedTest.StartsWith(
        $resolvedTemp + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    (Split-Path -Leaf $resolvedTest).StartsWith(
        "sporespore-r23d43-startup-transform-",
        [StringComparison]::Ordinal
    )
) "temporary mutation root escaped the system temp directory"
[void][IO.Directory]::CreateDirectory($resolvedTest)

try {
    $reportPath = Join-Path $resolvedTest "report.json"
    $run = Invoke-R23D43StartupTransformAnalyzer $python $manifestPath $reportPath
    Assert-R23D43StartupTransform ($run.exit_code -eq 0) (
        "real CAS analysis failed: $($run.output)"
    )
    $prefix = "R23D43_STARTUP_TRANSFORM_ANALYSIS_PASS "
    $markers = @(($run.output -split '\r?\n') | Where-Object {
        $_.StartsWith($prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D43StartupTransform ($markers.Count -eq 1) (
        "analysis marker count changed"
    )
    $report = $markers[0].Substring($prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
    $byCampaign = @{}
    foreach ($campaign in $report.campaigns) {
        $byCampaign[[string]$campaign.campaign_key] = $campaign
    }
    $byGroup = @{}
    foreach ($group in $report.groups) {
        $byGroup[[string]$group.group_id] = $group
    }
    $noRamp = $byGroup.no_startup_ramp
    $ramped = $byGroup.canonical_startup_ramp

    Assert-R23D43StartupTransform (
        [string]$report.schema_version -ceq
            "sporespore_r23d43_rapier_startup_transform_analysis_report_v1" -and
        [int]$report.input_summary.campaign_count -eq 6 -and
        [int]$report.input_summary.group_count -eq 2 -and
        [int]$report.input_summary.cell_count -eq 18 -and
        [int]$report.input_summary.trace_count -eq 18 -and
        [int]$report.input_summary.content_addressed_input_count -eq 18 -and
        [int]$report.input_summary.live_attempt_path_input_count -eq 0 -and
        [long]$report.input_summary.total_trace_byte_length -eq 233763048 -and
        [int]$report.input_summary.total_trace_row_count -eq 53856 -and
        [int]$noRamp.seed_count -eq 3 -and
        [int]$noRamp.raw_signed_gate_pass_count -eq 3 -and
        [int]$noRamp.conditioned_gate_pass_count -eq 3 -and
        (@($noRamp.seeds) -join ',') -ceq "21504,21505,21506" -and
        [int]$ramped.seed_count -eq 3 -and
        [int]$ramped.raw_signed_gate_pass_count -eq 3 -and
        [int]$ramped.conditioned_gate_pass_count -eq 0 -and
        (@($ramped.seeds) -join ',') -ceq "21509,21510,21511" -and
        [bool]$report.direct_observations.all_three_no_ramp_triplets_pass_raw_signed_cycle_gate -and
        [bool]$report.direct_observations.all_three_no_ramp_triplets_pass_conditioned_cycle_gate -and
        [bool]$report.direct_observations.all_three_ramped_triplets_pass_raw_signed_cycle_gate -and
        [bool]$report.direct_observations.all_three_ramped_triplets_fail_only_the_positive_conditioned_floor -and
        [bool]$report.direct_observations.r23d43_verifier_projection_would_remain_turning_negative -and
        [bool]$report.direct_observations.phase_minus_one_exists_in_both_transform_groups -and
        [bool]$report.direct_observations.startup_transform_and_seed_remain_confounded -and
        -not [bool]$report.direct_observations.causal_effect_or_population_inference_permitted -and
        [int]$report.model_construction_count -eq 0 -and
        [int]$report.world_attempt_count -eq 0 -and
        [int]$report.world_build_count -eq 0 -and
        @($manifest.claim_limits.Keys | Where-Object {
            [bool]$report[$_]
        }).Count -eq 0
    ) "retained-trace projection or claim boundary changed"

    $expected = [ordered]@{
        r23d30 = @(0.010030533017876247, 0.02141143422947276)
        r23d31 = @(0.010401935693835691, 0.02164533301193136)
        r23d32 = @(0.012882768312606334, 0.01890633414478069)
        r23d41 = @(0.005401148214074572, 0.02650468857654588)
        r23d42 = @(0.005978002522826736, 0.027941858140360883)
        r23d43 = @(0.005927633920819846, 0.02746974383341804)
    }
    foreach ($campaignKey in $expected.Keys) {
        $measurement = $byCampaign[$campaignKey].cycle_integrated_measurement
        Assert-R23D43Close (
            [double]$measurement.positive_reference_conditioned_cycle_shift_rad
        ) ([double]$expected[$campaignKey][0]) 1.0e-15 (
            "$campaignKey positive conditioned cycle shift changed"
        )
        Assert-R23D43Close (
            [double]$measurement.negative_reference_conditioned_cycle_shift_rad
        ) ([double]$expected[$campaignKey][1]) 1.0e-15 (
            "$campaignKey negative conditioned cycle shift changed"
        )
        foreach ($cell in $byCampaign[$campaignKey].cells) {
            Assert-R23D43StartupTransform (
                [int]$cell.trace_row_count -eq 2992 -and
                [int]$cell.startup_ramp_validation.undeclared_ramp_field_count -eq 0 -and
                [double]$cell.startup_ramp_validation.maximum_absolute_scale_error -le 1.0e-12
            ) "trace validation changed for ${campaignKey}:$($cell.arm_id)"
        }
    }

    $mutations = @(
        [ordered]@{
            name = "threshold_provenance"
            expected = "R23D43_STARTUP_DIAG_THRESHOLD_PROVENANCE"
            mutate = { param($copy)
                $copy.threshold_provenance.calibrated_release_acceptance_margin = $true
            }
        },
        [ordered]@{
            name = "group_membership"
            expected = "R23D43_STARTUP_DIAG_GROUP_IDENTITY"
            mutate = { param($copy)
                $copy.groups[1].ordered_campaign_keys[0] = "r23d30"
            }
        },
        [ordered]@{
            name = "decision_flip"
            expected = "R23D43_STARTUP_DIAG_DECISION_BOUNDARY"
            mutate = { param($copy)
                $copy.decision_boundary.verifier_only_successor_sufficient = $true
            }
        },
        [ordered]@{
            name = "missing_cas"
            expected = "R23D43_STARTUP_DIAG_CAS_OBJECT_MISSING"
            mutate = { param($copy)
                $copy.campaigns[0].cells[0].trace_sha256 = "sha256:" + ("0" * 64)
            }
        },
        [ordered]@{
            name = "claim_escalation"
            expected = "R23D43_STARTUP_DIAG_CLAIM_LIMITS"
            mutate = { param($copy)
                $copy.claim_limits.turning_validation = $true
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
        $mutatedRun = Invoke-R23D43StartupTransformAnalyzer `
            $python $mutatedPath $mutatedOutput
        Assert-R23D43StartupTransform (
            $mutatedRun.exit_code -ne 0 -and
            $mutatedRun.output.Contains([string]$mutation.expected)
        ) "mutation did not fail closed: $($mutation.name): $($mutatedRun.output)"
    }

    $rerun = Invoke-R23D43StartupTransformAnalyzer $python $manifestPath $reportPath
    Assert-R23D43StartupTransform (
        $rerun.exit_code -ne 0 -and
        $rerun.output.Contains("R23D43_STARTUP_DIAG_OUTPUT_EXISTS")
    ) "create-only output refusal changed"
} finally {
    if (Test-Path -LiteralPath $resolvedTest) {
        $rechecked = [IO.Path]::GetFullPath($resolvedTest)
        Assert-R23D43StartupTransform (
            $rechecked.StartsWith(
                $resolvedTemp + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            ) -and
            (Split-Path -Leaf $rechecked).StartsWith(
                "sporespore-r23d43-startup-transform-",
                [StringComparison]::Ordinal
            )
        ) "refusing unsafe temporary cleanup"
        Remove-Item -LiteralPath $rechecked -Recurse -Force
    }
}

Write-Host (
    "R23D43_STARTUP_TRANSFORM_PASS campaigns=6 cells=18 rows=53856 " +
    "no_ramp_conditioned=3/3 ramped_conditioned=0/3 ramped_raw=3/3 " +
    "confounded=True mutations=5 models=0 worlds=0 turning=False physical=False"
)

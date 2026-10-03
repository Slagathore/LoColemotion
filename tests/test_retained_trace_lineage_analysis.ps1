#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$analysisRoot = Join-Path $sdkRoot "trace_analysis"
$contractPath = Join-Path $analysisRoot "retained_trace_lineage_contract_v1.json"
$manifestPath = Join-Path $analysisRoot "r23d26_lineage_analysis_manifest_v1.json"
$closurePath = Join-Path $analysisRoot "r23d26_lineage_diagnosis_closure_v1.json"
$analyzerPath = Join-Path $analysisRoot "analyze_retained_trace_lineage.py"
$unitTestPath = Join-Path $analysisRoot "test_analyze_retained_trace_lineage.py"
$runnerPath = Join-Path $sdkRoot "run_retained_trace_lineage_analysis.ps1"
$evidenceRoot = Join-Path (
    Split-Path -Parent $repoRoot
) "SporeSpore_Evidence"

function Assert-TraceLineageTest([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "TRACE_LINEAGE_TEST: $Message" }
}

function Get-TraceLineageTestGitBlobSha256(
    [string]$Commit,
    [string]$RelativePath
) {
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
        Assert-TraceLineageTest $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-TraceLineageTest ($process.ExitCode -eq 0) (
            "Git blob read failed for ${RelativePath}: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

Assert-TraceLineageTest (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace('\', '/') -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @(
    $contractPath,
    $manifestPath,
    $closurePath,
    $analyzerPath,
    $unitTestPath,
    $runnerPath,
    $evidenceRoot
)) {
    Assert-TraceLineageTest (Test-Path -LiteralPath $path) "required path missing: $path"
}

$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$manifest = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-TraceLineageTest (
    [string]$contract.schema_version -ceq
        "sporespore_retained_trace_lineage_contract_v1" -and
    [string]$contract.status -ceq
        "normative_zero_world_diagnostic_contract" -and
    -not [bool]$contract.input_boundary.live_attempt_paths_permitted -and
    [bool]$contract.input_boundary.every_trace_requires_sha256_and_byte_length -and
    [bool]$contract.input_boundary.phase_order_and_row_counts_are_manifest_bound -and
    [bool]$contract.output_boundary.create_only_output -and
    [bool]$contract.output_boundary.content_addressed_retention_required_for_durable_use -and
    [int]$contract.output_boundary.model_construction_count -eq 0 -and
    [int]$contract.output_boundary.world_attempt_count -eq 0 -and
    [int]$contract.output_boundary.world_build_count -eq 0 -and
    -not [bool]$contract.output_boundary.physical_execution_authorized -and
    -not [bool]$contract.output_boundary.physical_acceptance_authority
) "normative contract changed"

$sourceClosure = $manifest.source_closure
$closureCommit = [string]$sourceClosure.source_commit
$closureRelative = [string]$sourceClosure.path
Assert-TraceLineageTest (
    [string]$manifest.schema_version -ceq
        "sporespore_retained_trace_lineage_manifest_v1" -and
    [string]$manifest.analysis_id -ceq
        "QSDK-R23D26-RETAINED-TRACE-LINEAGE-D1" -and
    [string]$manifest.question_class -ceq
        "postclosure_development_diagnosis" -and
    @($manifest.cells).Count -eq 9 -and
    @($manifest.comparison_groups).Count -eq 3 -and
    [int]$manifest.trace_contract.expected_row_count -eq 2992 -and
    [string]$manifest.trace_contract.analysis_phase_id -ceq "commanded_turn" -and
    [int]$manifest.trace_contract.final_window_row_count -eq 120 -and
    $null -eq $manifest.trace_contract.ordered_actuator_velocity_limits_rad_s -and
    [double]$manifest.replayed_thresholds.minimum_command_conditioned_yaw_separation_rad -eq 0.01 -and
    -not [bool]$manifest.replayed_thresholds.threshold_change_authorized -and
    (git -C $repoRoot rev-parse "${closureCommit}:${closureRelative}").Trim() -ceq
        [string]$sourceClosure.git_blob_oid -and
    (Get-TraceLineageTestGitBlobSha256 $closureCommit $closureRelative) -ceq
        [string]$sourceClosure.raw_sha256
) "R23D26 retained-input declaration changed"

$retainedReportPath = [string]$closure.retained_evidence.report.path
$retainedReceiptPath = [string]$closure.retained_evidence.receipt.path
$retainedCasPayloadPath = [string]$closure.retained_evidence.report.cas_payload_path
foreach ($path in @(
    $retainedReportPath,
    $retainedReceiptPath,
    $retainedCasPayloadPath
)) {
    Assert-TraceLineageTest (Test-Path -LiteralPath $path -PathType Leaf) (
        "retained diagnosis object missing: $path"
    )
}
$retainedReportHash = "sha256:" + (
    Get-FileHash -LiteralPath $retainedReportPath -Algorithm SHA256
).Hash.ToLowerInvariant()
$retainedReceiptHash = "sha256:" + (
    Get-FileHash -LiteralPath $retainedReceiptPath -Algorithm SHA256
).Hash.ToLowerInvariant()
$retainedCasHash = "sha256:" + (
    Get-FileHash -LiteralPath $retainedCasPayloadPath -Algorithm SHA256
).Hash.ToLowerInvariant()
$retainedReport = Get-Content -LiteralPath $retainedReportPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$retainedReceipt = Get-Content -LiteralPath $retainedReceiptPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-TraceLineageTest (
    [string]$closure.schema_version -ceq
        "sporespore_retained_trace_lineage_diagnosis_closure_v1" -and
    [string]$closure.analysis_id -ceq
        "QSDK-R23D26-RETAINED-TRACE-LINEAGE-D1" -and
    [string]$closure.status -ceq "closed_complete_development_diagnosis" -and
    [string]$closure.source_commit -ceq
        "97024ce9da77ff260f5282b5991b39fe97f69cbc" -and
    [string]$closure.source_manifest.raw_sha256 -ceq
        "sha256:2170f44f5200c264166de5e97a58a84071c9ac04a6023c6a6ca300fc1b08f53d" -and
    $retainedReportHash -ceq [string]$closure.retained_evidence.report.sha256 -and
    $retainedCasHash -ceq $retainedReportHash -and
    (Get-Item -LiteralPath $retainedReportPath).Length -eq
        [long]$closure.retained_evidence.report.byte_length -and
    (Get-Item -LiteralPath $retainedCasPayloadPath).Length -eq
        [long]$closure.retained_evidence.report.byte_length -and
    $retainedReceiptHash -ceq [string]$closure.retained_evidence.receipt.sha256 -and
    (Get-Item -LiteralPath $retainedReceiptPath).Length -eq
        [long]$closure.retained_evidence.receipt.byte_length -and
    [string]$retainedReport.schema_version -ceq
        "sporespore_retained_trace_lineage_report_v1" -and
    [string]$retainedReport.analyzer_source_commit -ceq
        [string]$closure.source_commit -and
    [string]$retainedReceipt.report_sha256 -ceq $retainedReportHash -and
    [long]$retainedReceipt.report_byte_length -eq
        [long]$closure.retained_evidence.report.byte_length -and
    [int]$retainedReport.input_summary.cell_count -eq 9 -and
    [int]$retainedReport.input_summary.total_trace_row_count -eq 26928 -and
    [int]$retainedReport.observability.complete_limiting_actuator_cell_count -eq 0 -and
    [int]$retainedReport.observability.limiting_actuator_unavailable_cell_count -eq 9 -and
    [int]$retainedReport.model_construction_count -eq 0 -and
    [int]$retainedReport.world_attempt_count -eq 0 -and
    [int]$retainedReport.world_build_count -eq 0 -and
    -not [bool]$retainedReport.physical_execution_authorized -and
    -not [bool]$retainedReport.physical_acceptance_authority -and
    [bool]$closure.successor_constraints.complete_ordered_final_actuator_commands_required -and
    [bool]$closure.successor_constraints.complete_ordered_actuator_velocity_limits_required -and
    [bool]$closure.successor_constraints.direction_neutral_rule_required -and
    [bool]$closure.successor_constraints.support_and_stability_aware_authority_required -and
    -not [bool]$closure.claim_limits.turning_verified -and
    -not [bool]$closure.claim_limits.portable_turning_verified -and
    -not [bool]$closure.claim_limits.cross_engine_equivalence -and
    -not [bool]$closure.claim_limits.physical_acceptance_authority
) "retained diagnosis closure or CAS binding changed"

$uniqueCellIds = @($manifest.cells | ForEach-Object { [string]$_.cell_id } |
    Sort-Object -Unique)
$uniqueDigests = @($manifest.cells | ForEach-Object { [string]$_.trace_sha256 } |
    Sort-Object -Unique)
Assert-TraceLineageTest (
    $uniqueCellIds.Count -eq 9 -and
    $uniqueDigests.Count -eq 9 -and
    @($manifest.cells | Where-Object {
        [string]$_.engine_id -cne "rapier_parry" -or
        [string]$_.trace_sha256 -notmatch '^sha256:[0-9a-f]{64}$' -or
        [long]$_.trace_byte_length -le 0
    }).Count -eq 0
) "retained cell identities are not exact and unique"

$analyzerSource = Get-Content -LiteralPath $analyzerPath -Raw
$runnerSource = Get-Content -LiteralPath $runnerPath -Raw
foreach ($forbidden in @(
    "import mujoco",
    "import rapier",
    "import godot",
    "import subprocess",
    "PhysicsServer",
    "mj_step("
)) {
    Assert-TraceLineageTest (-not $analyzerSource.Contains($forbidden)) (
        "analyzer gained a physical/runtime dependency: $forbidden"
    )
}
foreach ($required in @(
    "status --short",
    "rev-parse origin/main",
    "ls-remote origin refs/heads/main",
    "Publish-SporeSporeContentAddressedArtifact",
    "world_build_count",
    "physical_execution_authorized"
)) {
    Assert-TraceLineageTest ($runnerSource.Contains($required)) (
        "production runner lost boundary: $required"
    )
}

$pythonMatches = @(
    Get-Command python.exe -CommandType Application -ErrorAction Stop
)
Assert-TraceLineageTest ($pythonMatches.Count -ge 1) "python.exe unavailable"
$python = [IO.Path]::GetFullPath([string]$pythonMatches[0].Source)
$unitOutput = & $python $unitTestPath 2>&1 | Out-String
$unitExit = $LASTEXITCODE
Assert-TraceLineageTest (
    $unitExit -eq 0 -and
    $unitOutput.Contains("Ran 8 tests") -and
    $unitOutput.Contains("OK")
) "Python mutation suite failed: $unitOutput"

$testRoot = Join-Path ([IO.Path]::GetTempPath()) (
    "sporespore-trace-lineage-" + [guid]::NewGuid().ToString("N")
)
$resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$resolvedTest = [IO.Path]::GetFullPath($testRoot)
Assert-TraceLineageTest (
    $resolvedTest.StartsWith(
        $resolvedTemp + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    (Split-Path -Leaf $resolvedTest).StartsWith(
        "sporespore-trace-lineage-",
        [StringComparison]::Ordinal
    )
) "temporary test root escaped the system temporary directory"
[void][IO.Directory]::CreateDirectory($resolvedTest)
$testReportPath = Join-Path $resolvedTest "report.json"
$sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim()
try {
    $analysisOutput = & $python $analyzerPath `
        --manifest $manifestPath `
        --evidence-root $evidenceRoot `
        --analyzer-source-commit $sourceCommit `
        --output $testReportPath 2>&1 | Out-String
    $analysisExit = $LASTEXITCODE
    Assert-TraceLineageTest ($analysisExit -eq 0) (
        "real retained analysis failed: $analysisOutput"
    )
    $prefix = "RETAINED_TRACE_LINEAGE_PASS "
    $markers = @(($analysisOutput -split '\r?\n') | Where-Object {
        $_.StartsWith($prefix, [StringComparison]::Ordinal)
    })
    Assert-TraceLineageTest ($markers.Count -eq 1) "analysis marker count changed"
    $report = $markers[0].Substring($prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100

    $cap10 = @($report.comparisons | Where-Object {
        [string]$_.candidate_id -ceq "cap_0p10"
    })
    $cap20 = @($report.comparisons | Where-Object {
        [string]$_.candidate_id -ceq "cap_0p20"
    })
    $cap30 = @($report.comparisons | Where-Object {
        [string]$_.candidate_id -ceq "cap_0p30"
    })
    $cap20Reference = @($report.cells | Where-Object {
        [string]$_.cell_id -ceq "rapier_parry__cap_0p20__reference_zero"
    })
    $cap20Positive = @($report.cells | Where-Object {
        [string]$_.cell_id -ceq "rapier_parry__cap_0p20__positive_heading"
    })
    $cap20Negative = @($report.cells | Where-Object {
        [string]$_.cell_id -ceq "rapier_parry__cap_0p20__negative_heading"
    })
    $cap30Positive = @($report.cells | Where-Object {
        [string]$_.cell_id -ceq "rapier_parry__cap_0p30__positive_heading"
    })
    $cap30Negative = @($report.cells | Where-Object {
        [string]$_.cell_id -ceq "rapier_parry__cap_0p30__negative_heading"
    })

    Assert-TraceLineageTest (
        [string]$report.schema_version -ceq
            "sporespore_retained_trace_lineage_report_v1" -and
        [int]$report.input_summary.cell_count -eq 9 -and
        [int]$report.input_summary.trace_count -eq 9 -and
        [long]$report.input_summary.total_trace_byte_length -eq 61554504 -and
        [int]$report.input_summary.total_trace_row_count -eq 26928 -and
        [int]$report.input_summary.content_addressed_input_count -eq 9 -and
        [int]$report.input_summary.live_attempt_path_input_count -eq 0 -and
        @($report.cells).Count -eq 9 -and
        @($report.comparisons).Count -eq 3 -and
        $cap10.Count -eq 1 -and
        $cap20.Count -eq 1 -and
        $cap30.Count -eq 1 -and
        $cap20Reference.Count -eq 1 -and
        $cap20Positive.Count -eq 1 -and
        $cap20Negative.Count -eq 1 -and
        $cap30Positive.Count -eq 1 -and
        $cap30Negative.Count -eq 1
    ) "real retained report shape changed"

    Assert-TraceLineageTest (
        [Math]::Abs(
            [double]$cap20[0].positive_reference_conditioned_yaw_delta_rad -
            0.007249956486773179
        ) -lt 1.0e-12 -and
        [Math]::Abs(
            [double]$cap20[0].negative_reference_conditioned_yaw_delta_rad -
            0.03248383673776267
        ) -lt 1.0e-12 -and
        [Math]::Abs(
            [double]$cap20[0].bilateral_yaw_separation_rad -
            0.03973379322453585
        ) -lt 1.0e-12 -and
        -not [bool]$cap10[0].both_conditioned_thresholds_met -and
        -not [bool]$cap20[0].both_conditioned_thresholds_met -and
        -not [bool]$cap30[0].both_conditioned_thresholds_met -and
        -not [bool]$cap20[0].candidate_selection_authorized
    ) "conditioned-response replay changed"

    Assert-TraceLineageTest (
        [int]$cap20Reference[0].authority.steering_saturation_row_count -eq 0 -and
        [int]$cap20Positive[0].authority.steering_saturation_row_count -eq 1200 -and
        [int]$cap20Positive[0].authority.first_held_cap_reach_step -eq 669 -and
        [int]$cap20Negative[0].authority.steering_saturation_row_count -eq 1011 -and
        [int]$cap20Negative[0].authority.first_held_cap_reach_step -eq 665 -and
        [double]$cap20Positive[0].stability.maximum_torso_tilt_rad -eq
            0.12181901186704636 -and
        [double]$cap20Negative[0].stability.maximum_torso_tilt_rad -eq
            0.18924522399902344 -and
        [int]$cap20Positive[0].contacts.zero_foot_contact_row_count -eq 0 -and
        [int]$cap20Negative[0].contacts.zero_foot_contact_row_count -eq 0 -and
        [int]$cap20Positive[0].contacts.torso_ground_contact_row_count -eq 0 -and
        [int]$cap20Negative[0].contacts.torso_ground_contact_row_count -eq 0 -and
        [int]$cap30Positive[0].contacts.torso_ground_contact_row_count -eq 678 -and
        [int]$cap30Negative[0].contacts.torso_ground_contact_row_count -eq 890 -and
        [int]$cap30Positive[0].support.availability_counts.measurement_unavailable -eq 74 -and
        [int]$cap30Negative[0].support.availability_counts.measurement_unavailable -eq 58
    ) "authority, contact, support, or stability projection changed"

    Assert-TraceLineageTest (
        [int]$report.observability.complete_limiting_actuator_cell_count -eq 0 -and
        [int]$report.observability.limiting_actuator_unavailable_cell_count -eq 9 -and
        -not [bool]$report.observability.limiting_actuator_claim_authorized -and
        @($report.cells | Where-Object {
            [bool]$_.actuators.limiting_actuator_available -or
            [string]$_.actuators.limiting_actuator_unavailable_reason -cne
                "ordered_final_commands_not_complete"
        }).Count -eq 0 -and
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
    ) "observability or claim boundary changed"

    $rerunOutput = & $python $analyzerPath `
        --manifest $manifestPath `
        --evidence-root $evidenceRoot `
        --analyzer-source-commit $sourceCommit `
        --output $testReportPath 2>&1 | Out-String
    $rerunExit = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    Assert-TraceLineageTest (
        $rerunExit -ne 0 -and
        $rerunOutput.Contains("TRACE_LINEAGE_OUTPUT_EXISTS")
    ) "create-only output refusal changed"
} finally {
    if (Test-Path -LiteralPath $resolvedTest) {
        $rechecked = [IO.Path]::GetFullPath($resolvedTest)
        Assert-TraceLineageTest (
            $rechecked.StartsWith(
                $resolvedTemp + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            ) -and
            (Split-Path -Leaf $rechecked).StartsWith(
                "sporespore-trace-lineage-",
                [StringComparison]::Ordinal
            )
        ) "refusing unsafe temporary test cleanup"
        Remove-Item -LiteralPath $rechecked -Recurse -Force
    }
}

Write-Host (
    "RETAINED_TRACE_LINEAGE_ANALYSIS_PASS cells=9 traces=9 rows=26928 " +
    "bytes=61554504 comparisons=3 mutations=8 cap20_positive=0.007249956486773179 " +
    "cap20_negative=0.03248383673776267 limiting_actuator=unavailable retained=1 " +
    "models=0 worlds=0 selection=False turning=False equivalence=False release=False"
)

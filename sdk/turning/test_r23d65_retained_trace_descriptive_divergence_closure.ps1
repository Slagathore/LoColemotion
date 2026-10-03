#requires -Version 7.0

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$closurePath = Join-Path $PSScriptRoot "r23d65_retained_trace_descriptive_divergence_closure_v1.json"
$focusedGatePath = Join-Path $PSScriptRoot "test_r23d65_retained_trace_descriptive_divergence.ps1"

function Assert-R23D65DivergenceClosure {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,

        [Parameter(Mandatory = $true)]
        [string]$FailureCode
    )

    if (-not $Condition) {
        throw $FailureCode
    }
}

function Get-Sha256Prefixed {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LiteralPath
    )

    return "sha256:" + (
        Get-FileHash -LiteralPath $LiteralPath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-BytesSha256Prefixed {
    param(
        [Parameter(Mandatory = $true)]
        [byte[]]$Bytes
    )

    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        $digest = $hasher.ComputeHash($Bytes)
    } finally {
        $hasher.Dispose()
    }
    return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
}

function Get-GitBlobSha256 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Commit,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-C",
        $repoRoot,
        "cat-file",
        "blob",
        "${Commit}:$RelativePath"
    )) {
        [void]$start.ArgumentList.Add($argument)
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        Assert-R23D65DivergenceClosure $process.Start() (
            "R23D65_DIVERGENCE_CLOSURE_GIT_BLOB_START_FAILED:$RelativePath"
        )
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try {
            $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream)
        } finally {
            $hasher.Dispose()
        }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D65DivergenceClosure ($process.ExitCode -eq 0) (
            "R23D65_DIVERGENCE_CLOSURE_GIT_BLOB_READ_FAILED:$RelativePath`n$stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally {
        $process.Dispose()
    }
}

function Assert-FileIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LiteralPath,

        [Parameter(Mandatory = $true)]
        [long]$ExpectedLength,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedSha256,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    Assert-R23D65DivergenceClosure (
        Test-Path -LiteralPath $LiteralPath -PathType Leaf
    ) "R23D65_DIVERGENCE_CLOSURE_FILE_MISSING:$Label"
    $item = Get-Item -LiteralPath $LiteralPath
    Assert-R23D65DivergenceClosure (
        $item.Length -eq $ExpectedLength
    ) "R23D65_DIVERGENCE_CLOSURE_FILE_LENGTH_MISMATCH:$Label"
    Assert-R23D65DivergenceClosure (
        (Get-Sha256Prefixed -LiteralPath $LiteralPath) -ceq $ExpectedSha256
    ) "R23D65_DIVERGENCE_CLOSURE_FILE_DIGEST_MISMATCH:$Label"
}

function Assert-Near {
    param(
        [Parameter(Mandatory = $true)]
        [double]$Observed,

        [Parameter(Mandatory = $true)]
        [double]$Expected,

        [Parameter(Mandatory = $true)]
        [double]$Tolerance,

        [Parameter(Mandatory = $true)]
        [string]$FailureCode
    )

    Assert-R23D65DivergenceClosure (
        [Math]::Abs($Observed - $Expected) -le $Tolerance
    ) $FailureCode
}

$observedRoot = (& git -C $repoRoot rev-parse --show-toplevel).Trim()
Assert-R23D65DivergenceClosure ($LASTEXITCODE -eq 0) (
    "R23D65_DIVERGENCE_CLOSURE_REPO_QUERY_FAILED"
)
Assert-R23D65DivergenceClosure (
    [IO.Path]::GetFullPath($observedRoot) -ceq $repoRoot
) "R23D65_DIVERGENCE_CLOSURE_REPO_ROOT_MISMATCH"
$observedRemote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R23D65DivergenceClosure ($LASTEXITCODE -eq 0) (
    "R23D65_DIVERGENCE_CLOSURE_REMOTE_QUERY_FAILED"
)
Assert-R23D65DivergenceClosure (
    $observedRemote -ceq $expectedRemote
) "R23D65_DIVERGENCE_CLOSURE_REMOTE_MISMATCH"

Assert-R23D65DivergenceClosure (
    Test-Path -LiteralPath $closurePath -PathType Leaf
) "R23D65_DIVERGENCE_CLOSURE_RECORD_MISSING"
$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100

Assert-R23D65DivergenceClosure (
    [string]$closure.schema_version -ceq
        "sporespore_r23d65_retained_trace_descriptive_divergence_closure_v1" -and
    [string]$closure.analysis_id -ceq
        "QSDK-R23D65-RETAINED-TRACE-DESCRIPTIVE-DIVERGENCE-V1" -and
    [string]$closure.status -ceq
        "closed_complete_retrospective_descriptive_development_analysis" -and
    [string]$closure.ledger_scope.subsystem -ceq "turning" -and
    [string]$closure.ledger_scope.engine_scope -ceq
        "godot_jolt_and_rapier_parry" -and
    [string]$closure.ledger_scope.authority_mode -ceq
        "retrospective_retained_trace_description" -and
    [string]$closure.ledger_scope.question_class -ceq "development"
) "R23D65_DIVERGENCE_CLOSURE_BOUNDARY_INVALID"

$source = $closure.analysis_source
$sourceCommit = [string]$source.commit
$sourceTree = (& git -C $repoRoot rev-parse "${sourceCommit}^{tree}").Trim()
Assert-R23D65DivergenceClosure ($LASTEXITCODE -eq 0) (
    "R23D65_DIVERGENCE_CLOSURE_SOURCE_COMMIT_MISSING"
)
Assert-R23D65DivergenceClosure (
    $sourceCommit -ceq "cecfda67d81ebc4a0834bc679f640c9207670f43" -and
    $sourceTree -ceq [string]$source.tree_git_oid -and
    [string]$source.branch -ceq "main" -and
    [string]$source.origin_url -ceq $expectedRemote -and
    [bool]$source.clean_pushed_live_main_verified_before_compilation -and
    @($source.source_bindings).Count -eq 3
) "R23D65_DIVERGENCE_CLOSURE_SOURCE_BOUNDARY_INVALID"

foreach ($binding in $source.source_bindings) {
    $relativePath = [string]$binding.path
    $blobOid = (& git -C $repoRoot rev-parse "${sourceCommit}:${relativePath}").Trim()
    Assert-R23D65DivergenceClosure ($LASTEXITCODE -eq 0) (
        "R23D65_DIVERGENCE_CLOSURE_SOURCE_PATH_MISSING:$relativePath"
    )
    $blobLength = [long]((& git -C $repoRoot cat-file -s $blobOid).Trim())
    Assert-R23D65DivergenceClosure ($LASTEXITCODE -eq 0) (
        "R23D65_DIVERGENCE_CLOSURE_SOURCE_LENGTH_QUERY_FAILED:$relativePath"
    )
    Assert-R23D65DivergenceClosure (
        $blobOid -ceq [string]$binding.git_blob_oid -and
        $blobLength -eq [long]$binding.byte_length -and
        (Get-GitBlobSha256 -Commit $sourceCommit -RelativePath $relativePath) -ceq
            [string]$binding.raw_sha256
    ) "R23D65_DIVERGENCE_CLOSURE_SOURCE_BINDING_CHANGED:$relativePath"
}

$historical = $closure.immutable_historical_input
$historicalClosurePath = Join-Path $repoRoot ([string]$historical.closure_path)
Assert-FileIdentity `
    -LiteralPath $historicalClosurePath `
    -ExpectedLength ([long]$historical.closure_byte_length) `
    -ExpectedSha256 ([string]$historical.closure_raw_sha256) `
    -Label "historical-r23d65-closure"
$historicalBlob = (& git -C $repoRoot rev-parse (
    "${sourceCommit}:$([string]$historical.closure_path)"
)).Trim()
Assert-R23D65DivergenceClosure (
    $historicalBlob -ceq [string]$historical.closure_git_blob_oid_at_analysis_source -and
    [string]$historical.campaign_status -ceq
        "closed_consumed_invalid_incomplete_after_four_worlds_runtime_terminal_and_trace_retention_failures" -and
    -not [bool]$historical.historical_evaluator_invoked -and
    -not [bool]$historical.historical_result_reinterpreted -and
    -not [bool]$historical.historical_identity_rerun -and
    -not [bool]$historical.retained_population.input_population_mutated -and
    [int]$historical.retained_population.file_count -eq 41 -and
    [long]$historical.retained_population.byte_count -eq 134685582 -and
    [string]$historical.retained_population.canonical_manifest_sha256 -ceq
        "sha256:bade316726f84e1c6d08bfa5a0ba960db240d6dc462fd808caf3627feaf249ba" -and
    [int]$historical.retained_population.trace_count_parsed -eq 4 -and
    [int]$historical.retained_population.trace_row_count_total -eq 11968
) "R23D65_DIVERGENCE_CLOSURE_HISTORICAL_BOUNDARY_INVALID"

$bundle = $closure.retained_analysis_bundle
$bundleRoot = [IO.Path]::GetFullPath([string]$bundle.root)
Assert-R23D65DivergenceClosure (
    Test-Path -LiteralPath $bundleRoot -PathType Container
) "R23D65_DIVERGENCE_CLOSURE_BUNDLE_ROOT_MISSING"
Assert-R23D65DivergenceClosure (
    -not $bundleRoot.StartsWith(
        $repoRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    )
) "R23D65_DIVERGENCE_CLOSURE_BUNDLE_INSIDE_REPOSITORY"

$bundleFiles = @(Get-ChildItem -LiteralPath $bundleRoot -File -Recurse)
$bundleDirectories = @(Get-ChildItem -LiteralPath $bundleRoot -Directory -Recurse)
Assert-R23D65DivergenceClosure ($bundleDirectories.Count -eq 0) (
    "R23D65_DIVERGENCE_CLOSURE_BUNDLE_NESTED_DIRECTORY_PRESENT"
)
$observedRelativePaths = [Collections.Generic.List[string]]::new()
$bundleByteCount = [long]0
foreach ($file in $bundleFiles) {
    $relativePath = [IO.Path]::GetRelativePath($bundleRoot, $file.FullName).Replace('\', '/')
    [void]$observedRelativePaths.Add($relativePath)
    $bundleByteCount += [long]$file.Length
}
$expectedRelativePaths = @(
    "bundle-manifest.tsv",
    "contact_events.csv",
    "per_step_reference_zero.csv",
    "README.md",
    "report.json",
    "summary.csv"
)
Assert-R23D65DivergenceClosure (
    $observedRelativePaths.Count -eq 6 -and
    @(Compare-Object $observedRelativePaths $expectedRelativePaths).Count -eq 0 -and
    (@($bundle.canonical_manifest_order) -join "|") -ceq
        ($expectedRelativePaths -join "|") -and
    $bundleByteCount -eq 1607556 -and
    [int]$bundle.file_count -eq 6 -and
    [long]$bundle.byte_count -eq 1607556
) "R23D65_DIVERGENCE_CLOSURE_BUNDLE_POPULATION_CHANGED"

$manifestBuilder = [Text.StringBuilder]::new()
foreach ($relativePath in $expectedRelativePaths) {
    $literalPath = Join-Path $bundleRoot $relativePath
    $item = Get-Item -LiteralPath $literalPath
    [void]$manifestBuilder.Append($relativePath)
    [void]$manifestBuilder.Append("`t")
    [void]$manifestBuilder.Append($item.Length.ToString([Globalization.CultureInfo]::InvariantCulture))
    [void]$manifestBuilder.Append("`t")
    [void]$manifestBuilder.Append((Get-Sha256Prefixed -LiteralPath $literalPath))
    [void]$manifestBuilder.Append("`n")
}
$canonicalManifestBytes = [Text.UTF8Encoding]::new($false).GetBytes(
    $manifestBuilder.ToString()
)
Assert-R23D65DivergenceClosure (
    $canonicalManifestBytes.Length -eq [int]$bundle.canonical_manifest_byte_length -and
    (Get-BytesSha256Prefixed -Bytes $canonicalManifestBytes) -ceq
        [string]$bundle.canonical_manifest_sha256
) "R23D65_DIVERGENCE_CLOSURE_BUNDLE_MANIFEST_CHANGED"

foreach ($binding in $bundle.files) {
    Assert-FileIdentity `
        -LiteralPath (Join-Path $bundleRoot ([string]$binding.path)) `
        -ExpectedLength ([long]$binding.byte_length) `
        -ExpectedSha256 ([string]$binding.sha256) `
        -Label ([string]$binding.path)
}
Assert-R23D65DivergenceClosure (
    [int]$bundle.bundle_manifest_entry_count -eq 5 -and
    [bool]$bundle.bundle_manifest_excludes_itself -and
    [bool]$bundle.output_was_outside_repository -and
    [bool]$bundle.output_directory_did_not_preexist -and
    [bool]$bundle.deterministic_recompile_byte_equal
) "R23D65_DIVERGENCE_CLOSURE_BUNDLE_GUARDS_INVALID"

$bundleManifestRows = @(
    Get-Content -LiteralPath (Join-Path $bundleRoot "bundle-manifest.tsv") |
        Where-Object { $_.Length -gt 0 }
)
$manifestNames = [Collections.Generic.List[string]]::new()
foreach ($line in $bundleManifestRows) {
    $fields = @($line -split "`t")
    Assert-R23D65DivergenceClosure ($fields.Count -eq 3) (
        "R23D65_DIVERGENCE_CLOSURE_INTERNAL_MANIFEST_ROW_INVALID"
    )
    $name = [string]$fields[0]
    [void]$manifestNames.Add($name)
    Assert-R23D65DivergenceClosure ($name -cne "bundle-manifest.tsv") (
        "R23D65_DIVERGENCE_CLOSURE_INTERNAL_MANIFEST_SELF_REFERENCE"
    )
    $item = Get-Item -LiteralPath (Join-Path $bundleRoot $name)
    Assert-R23D65DivergenceClosure (
        $item.Length -eq [long]$fields[1] -and
        (Get-Sha256Prefixed -LiteralPath $item.FullName) -ceq [string]$fields[2]
    ) "R23D65_DIVERGENCE_CLOSURE_INTERNAL_MANIFEST_BINDING_CHANGED:$name"
}
$manifestNames.Sort([StringComparer]::Ordinal)
$expectedInternalNames = @(
    "README.md",
    "contact_events.csv",
    "per_step_reference_zero.csv",
    "report.json",
    "summary.csv"
)
Assert-R23D65DivergenceClosure (
    $manifestNames.Count -eq 5 -and
    ($manifestNames -join "|") -ceq ($expectedInternalNames -join "|")
) "R23D65_DIVERGENCE_CLOSURE_INTERNAL_MANIFEST_POPULATION_INVALID"

$reportPath = Join-Path $bundleRoot "report.json"
$report = Get-Content -LiteralPath $reportPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$overall = $report.matched_reference_zero.overall
$heading = $overall.heading
$torso = $overall.torso_reference_point
$contacts = $overall.foot_contacts

Assert-R23D65DivergenceClosure (
    [string]$report.schema_version -ceq
        "sporespore_r23d65_retained_trace_descriptive_divergence_report_v1" -and
    [string]$report.analysis_id -ceq [string]$closure.analysis_id -and
    [string]$report.status -ceq "complete_descriptive_development_artifact" -and
    [string]$report.repository.source_commit -ceq $sourceCommit -and
    [string]$report.repository.origin_main_commit -ceq $sourceCommit -and
    [bool]$report.input_integrity.all_bound_inputs_match -and
    [int]$overall.row_count -eq 2992 -and
    [double]$overall.duration_s -eq 24.933333333333334
) "R23D65_DIVERGENCE_CLOSURE_REPORT_IDENTITY_INVALID"

Assert-Near ([double]$heading.godot_terminal_start_aligned_change_deg) 9.090876866404047 1e-12 (
    "R23D65_DIVERGENCE_CLOSURE_GODOT_TERMINAL_HEADING_CHANGED"
)
Assert-Near ([double]$heading.rapier_terminal_start_aligned_change_deg) -0.7400052299783488 1e-12 (
    "R23D65_DIVERGENCE_CLOSURE_RAPIER_TERMINAL_HEADING_CHANGED"
)
Assert-Near ([double]$heading.terminal_signed_godot_minus_rapier_deg) 9.830882096382394 1e-12 (
    "R23D65_DIVERGENCE_CLOSURE_TERMINAL_HEADING_SEPARATION_CHANGED"
)
Assert-Near ([double]$heading.root_mean_square_separation_deg) 8.984082620087577 1e-12 (
    "R23D65_DIVERGENCE_CLOSURE_HEADING_RMS_CHANGED"
)
Assert-Near ([double]$heading.mean_absolute_separation_deg) 7.780151712292604 1e-12 (
    "R23D65_DIVERGENCE_CLOSURE_HEADING_MEAN_CHANGED"
)
Assert-Near ([double]$heading.maximum_absolute_separation_deg) 20.709966649554953 1e-12 (
    "R23D65_DIVERGENCE_CLOSURE_HEADING_MAXIMUM_CHANGED"
)
Assert-Near ([double]$torso.terminal_3d_separation_m) 0.6609454382177944 1e-12 (
    "R23D65_DIVERGENCE_CLOSURE_TORSO_TERMINAL_CHANGED"
)
Assert-Near ([double]$torso.root_mean_square_3d_separation_m) 0.5644153290401815 1e-12 (
    "R23D65_DIVERGENCE_CLOSURE_TORSO_RMS_CHANGED"
)
Assert-Near ([double]$torso.maximum_3d_separation_m) 0.8122733120008356 1e-12 (
    "R23D65_DIVERGENCE_CLOSURE_TORSO_MAXIMUM_CHANGED"
)
Assert-R23D65DivergenceClosure (
    [int]$contacts.contact_state_mismatch_count -eq 2817 -and
    [int]$contacts.contact_state_sample_count -eq 11968 -and
    [int]$contacts.godot_event_count -eq 54 -and
    [int]$contacts.rapier_event_count -eq 45 -and
    -not [bool]$contacts.nearest_event_pairing_is_one_to_one -and
    [int]$contacts.nearest_same_foot_same_transition_timing.event_observation_count -eq 99
) "R23D65_DIVERGENCE_CLOSURE_CONTACT_COUNTS_CHANGED"
Assert-Near ([double]$contacts.contact_state_mismatch_fraction) 0.23537767379679145 1e-15 (
    "R23D65_DIVERGENCE_CLOSURE_CONTACT_FRACTION_CHANGED"
)
Assert-Near ([double]$contacts.nearest_same_foot_same_transition_timing.median_absolute_offset_ms) 300.0 1e-12 (
    "R23D65_DIVERGENCE_CLOSURE_CONTACT_MEDIAN_CHANGED"
)

$jointAvailability = @(
    $report.requested_measurement_availability |
        Where-Object {
            [string]$_.requested_measurement -ceq
                "per-step joint-angle RMS between engines"
        }
)
$comAvailability = @(
    $report.requested_measurement_availability |
        Where-Object {
            [string]$_.requested_measurement -ceq
                "center-of-mass trajectory drift"
        }
)
Assert-R23D65DivergenceClosure (
    $jointAvailability.Count -eq 1 -and
    [string]$jointAvailability[0].status -ceq "unavailable_not_recorded" -and
    -not [bool]$jointAvailability[0].substitution_permitted -and
    $comAvailability.Count -eq 1 -and
    [string]$comAvailability[0].status -ceq "unavailable_not_recorded" -and
    -not [bool]$comAvailability[0].substitution_permitted -and
    -not [bool]$report.observed_instrumentation.measured_joint_angle_series_field_present_in_godot -and
    -not [bool]$report.observed_instrumentation.measured_joint_angle_series_field_present_in_rapier -and
    -not [bool]$report.observed_instrumentation.center_of_mass_series_field_present_in_godot -and
    -not [bool]$report.observed_instrumentation.center_of_mass_series_field_present_in_rapier -and
    [bool]$report.observed_instrumentation.torso_position_series_present_in_both
) "R23D65_DIVERGENCE_CLOSURE_INSTRUMENTATION_GAP_CHANGED"

Assert-R23D65DivergenceClosure (
    @($report.claim_boundary.Values | Where-Object { [bool]$_ }).Count -eq 0 -and
    @($closure.claim_limits.Values | Where-Object { [bool]$_ }).Count -eq 0 -and
    -not [bool]$closure.findings.torso_reference_point.is_whole_body_center_of_mass -and
    -not [bool]$closure.comparison_identity.complete_three_engine_comparison -and
    -not [bool]$closure.comparison_identity.mujoco_matched_trace_available -and
    -not [bool]$closure.comparison_identity.closed_loop_commands_guaranteed_identical_after_state_divergence
) "R23D65_DIVERGENCE_CLOSURE_CLAIM_PROMOTED"
Assert-R23D65DivergenceClosure (
    [int]$report.execution.physics_world_build_count -eq 0 -and
    [int]$report.execution.model_construction_count -eq 0 -and
    [int]$report.execution.native_read_count -eq 0 -and
    [int]$report.execution.solver_step_count -eq 0 -and
    [int]$report.execution.historical_evaluator_invocation_count -eq 0 -and
    [int]$closure.execution.physics_engine_process_count -eq 0 -and
    [int]$closure.execution.model_construction_count -eq 0 -and
    [int]$closure.execution.physics_world_build_count -eq 0 -and
    [int]$closure.execution.native_physics_read_count -eq 0 -and
    [int]$closure.execution.solver_step_count -eq 0 -and
    [int]$closure.execution.historical_evaluator_invocation_count -eq 0
) "R23D65_DIVERGENCE_CLOSURE_ZERO_WORLD_BOUNDARY_CHANGED"

$summaryRows = @(Import-Csv -LiteralPath (Join-Path $bundleRoot "summary.csv"))
$perStepRows = @(Import-Csv -LiteralPath (Join-Path $bundleRoot "per_step_reference_zero.csv"))
$eventRows = @(Import-Csv -LiteralPath (Join-Path $bundleRoot "contact_events.csv"))
Assert-R23D65DivergenceClosure (
    $summaryRows.Count -eq 10 -and
    $perStepRows.Count -eq 2992 -and
    $eventRows.Count -eq 99 -and
    [int]$perStepRows[0].semantic_step -eq 0 -and
    [int]$perStepRows[-1].semantic_step -eq 2991
) "R23D65_DIVERGENCE_CLOSURE_FLAT_TABLE_POPULATION_CHANGED"
$summaryJoint = @($summaryRows | Where-Object { $_.metric_id -ceq "joint_angle_rms" })
$summaryCom = @($summaryRows | Where-Object { $_.metric_id -ceq "center_of_mass_trajectory_drift" })
$summaryHeading = @($summaryRows | Where-Object { $_.metric_id -ceq "heading_rms_separation" })
Assert-R23D65DivergenceClosure (
    $summaryJoint.Count -eq 1 -and
    $summaryJoint[0].availability -ceq "unavailable_not_recorded" -and
    $summaryCom.Count -eq 1 -and
    $summaryCom[0].availability -ceq "unavailable_not_recorded" -and
    $summaryHeading.Count -eq 1
) "R23D65_DIVERGENCE_CLOSURE_SUMMARY_DISPOSITION_CHANGED"
Assert-Near ([double]$summaryHeading[0].cross_engine_value) 8.984082620087577 1e-12 (
    "R23D65_DIVERGENCE_CLOSURE_SUMMARY_HEADING_CHANGED"
)

$readmeText = Get-Content -LiteralPath (Join-Path $bundleRoot "README.md") -Raw
foreach ($requiredText in @(
    "descriptive development artifact",
    "Cannot be computed.",
    "does not say which engine is more correct",
    "MuJoCo is absent",
    "two-engine reference description",
    "A separately named torso-reference-point comparison is published. It is not relabeled as COM.",
    "no unique gait-cycle pairing is claimed.",
    "9.831 deg signed G-R",
    "2,817 / 11,968 (23.54%)"
)) {
    Assert-R23D65DivergenceClosure ($readmeText.Contains($requiredText)) (
        "R23D65_DIVERGENCE_CLOSURE_README_BOUNDARY_MISSING:$requiredText"
    )
}
Assert-R23D65DivergenceClosure (-not $readmeText.Contains([char]0xFFFD)) (
    "R23D65_DIVERGENCE_CLOSURE_README_REPLACEMENT_CHARACTER_PRESENT"
)

$requiredDocumentation = @(
    "docs/README.md",
    "docs/ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md",
    "docs/SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md",
    "sdk/release/README.md",
    "sdk/turning/README.md"
)
foreach ($relativePath in $requiredDocumentation) {
    $documentationText = Get-Content -LiteralPath (Join-Path $repoRoot $relativePath) -Raw
    Assert-R23D65DivergenceClosure (
        $documentationText.Contains(
            "r23d65_retained_trace_descriptive_divergence_closure_v1.json"
        ) -and
        $documentationText.Contains(
            "sha256:4ea979975242953e70196383482614f375b16cec0935750d37fcb3cdc3d03752"
        ) -and
        $documentationText.Contains("M20") -and
        $documentationText.Contains("12/20") -and
        $documentationText.Contains("12/25")
    ) "R23D65_DIVERGENCE_CLOSURE_DOCUMENTATION_MISSING:$relativePath"
}

$mappingBinding = $closure.sdk1_m20_integration.milestone_mapping_at_analysis_source
$mappingRelativePath = [string]$mappingBinding.path
$mappingBlob = (& git -C $repoRoot rev-parse (
    "${sourceCommit}:${mappingRelativePath}"
)).Trim()
Assert-R23D65DivergenceClosure ($LASTEXITCODE -eq 0) (
    "R23D65_DIVERGENCE_CLOSURE_M20_MAPPING_SOURCE_MISSING"
)
$mappingBlobLength = [long]((& git -C $repoRoot cat-file -s $mappingBlob).Trim())
Assert-R23D65DivergenceClosure ($LASTEXITCODE -eq 0) (
    "R23D65_DIVERGENCE_CLOSURE_M20_MAPPING_LENGTH_QUERY_FAILED"
)
$mappingText = (& git -C $repoRoot show "${sourceCommit}:${mappingRelativePath}" |
    Out-String)
Assert-R23D65DivergenceClosure ($LASTEXITCODE -eq 0) (
    "R23D65_DIVERGENCE_CLOSURE_M20_MAPPING_READ_FAILED"
)
$mapping = $mappingText | ConvertFrom-Json -AsHashtable -Depth 100
$m20 = @(
    $mapping.sdk1_contract.milestones |
        Where-Object { [string]$_.milestone_id -ceq "SDK1-M20" }
)
Assert-R23D65DivergenceClosure (
    $mappingBlob -ceq [string]$mappingBinding.git_blob_oid -and
    $mappingBlobLength -eq [long]$mappingBinding.byte_length -and
    (Get-GitBlobSha256 -Commit $sourceCommit -RelativePath $mappingRelativePath) -ceq
        [string]$mappingBinding.raw_sha256 -and
    $m20.Count -eq 1 -and
    [string]$m20[0].source.kind -ceq [string]$mappingBinding.source_kind -and
    [string]$m20[0].source.proof.kind -ceq [string]$mappingBinding.proof_kind
) "R23D65_DIVERGENCE_CLOSURE_M20_MAPPING_BOUNDARY_CHANGED"

Assert-R23D65DivergenceClosure (
    [bool]$closure.sdk1_m20_integration.development_diagnostic_available -and
    [bool]$closure.sdk1_m20_integration.useful_to_explorer_diagnostics_and_provenance_design -and
    -not [bool]$closure.sdk1_m20_integration.milestone_mapping_mutated_for_diagnostic -and
    -not [bool]$closure.sdk1_m20_integration.polished_release_packaged_explorer_proved -and
    -not [bool]$closure.sdk1_m20_integration.sdk1_m20_satisfied -and
    [string]$closure.sdk1_m20_integration.sdk1_score_before -ceq "12/20" -and
    [string]$closure.sdk1_m20_integration.sdk1_score_after -ceq "12/20" -and
    [string]$closure.sdk1_m20_integration.full_program_score_before -ceq "12/25" -and
    [string]$closure.sdk1_m20_integration.full_program_score_after -ceq "12/25"
) "R23D65_DIVERGENCE_CLOSURE_M20_BOUNDARY_CHANGED"

$focusedGateText = (& pwsh -NoLogo -NoProfile -File $focusedGatePath 2>&1 |
    Out-String).Trim()
$focusedGateExit = $LASTEXITCODE
$global:LASTEXITCODE = 0
Assert-R23D65DivergenceClosure ($focusedGateExit -eq 0) (
    "R23D65_DIVERGENCE_CLOSURE_FOCUSED_GATE_FAILED`n$focusedGateText"
)
$focusedGate = $focusedGateText | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D65DivergenceClosure (
    [bool]$focusedGate.ok -and
    [int]$focusedGate.trace_source_count -eq 4 -and
    [int]$focusedGate.matched_cross_engine_pair_count -eq 1 -and
    [int]$focusedGate.context_only_trace_count -eq 2 -and
    [int]$focusedGate.unavailable_requested_metric_count -eq 2 -and
    [int]$focusedGate.compiler_self_test_check_count -eq 8 -and
    [bool]$focusedGate.inside_repository_output_refused -and
    [bool]$focusedGate.descriptive_only -and
    [bool]$focusedGate.non_authoritative -and
    -not [bool]$focusedGate.sdk1_m20_satisfied -and
    -not [bool]$focusedGate.cross_engine_equivalence_claimed -and
    [int]$focusedGate.model_construction_count -eq 0 -and
    [int]$focusedGate.physics_world_build_count -eq 0 -and
    [int]$focusedGate.solver_step_count -eq 0 -and
    [int]$focusedGate.native_read_count -eq 0 -and
    -not [bool]$focusedGate.release_authority
) "R23D65_DIVERGENCE_CLOSURE_FOCUSED_GATE_RECEIPT_INVALID"

$receipt = [ordered]@{
    schema_version = "sporespore_r23d65_retained_trace_descriptive_divergence_closure_audit_v1"
    ok = $true
    analysis_id = [string]$closure.analysis_id
    source_commit = $sourceCommit
    retained_bundle_file_count = $bundleFiles.Count
    retained_bundle_byte_count = $bundleByteCount
    retained_bundle_manifest_sha256 = [string]$bundle.canonical_manifest_sha256
    summary_row_count = $summaryRows.Count
    matched_step_row_count = $perStepRows.Count
    contact_event_row_count = $eventRows.Count
    terminal_heading_separation_deg = [double]$heading.terminal_signed_godot_minus_rapier_deg
    terminal_torso_reference_point_separation_m = [double]$torso.terminal_3d_separation_m
    contact_state_mismatch_fraction = [double]$contacts.contact_state_mismatch_fraction
    joint_angle_rms_available = $false
    center_of_mass_drift_available = $false
    two_engine_descriptive_only = $true
    sdk1_m20_satisfied = $false
    sdk1_score = "12/20"
    full_program_score = "12/25"
    model_construction_count = 0
    physics_world_build_count = 0
    native_read_count = 0
    solver_step_count = 0
    release_authority = $false
}
$receipt | ConvertTo-Json -Depth 10 -Compress

#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$GodotRepositoryRoot = (
        "C:\Users\Cole\CodeStuff\dependencies\godot-sporespore-4.7"
    ),
    [string]$ScratchRoot = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$expectedRepoRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRepoRemote = "https://github.com/Slagathore/sporespore.git"
$expectedEvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$expectedGodotRoot = (
    "C:\Users\Cole\CodeStuff\dependencies\godot-sporespore-4.7"
)
$expectedGodotRemote = "https://github.com/godotengine/godot.git"
$sourceCommit = "b17a6677e711625061726279a1b0287c57fa82ec"
$sourceTree = "6902d1cb7076e01192c3065074809897a64246c4"
$godotCommit = "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"
$patchHash = "9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c"
$closureRelative = (
    "sdk/recovery/" +
    "r24d8_godot_jolt_active_step_snapshot_timing_positive_closure_v1.json"
)
$manifestRelative = (
    "sdk/recovery/" +
    "r24d8_godot_jolt_active_step_snapshot_timing_validation_manifest.json"
)
$diagnosticsRelative = (
    "sdk/recovery/r24d8_positive_closure_precommit_diagnostics_v1.json"
)
$markerPrefix = "QSDK_R24D8_ACTIVE_STEP_SNAPSHOT_TIMING_POSITIVE_CLOSURE_PASS "

. (Join-Path $repoRoot "sdk/content_addressed_artifact_store.ps1")

function Assert-R24D8Closure {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Code
    )
    if (-not $Condition) {
        throw "QSDK-R24D8 positive closure: $Code"
    }
}

function Get-R24D8ClosureRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R24D8ClosureBytesSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Invoke-R24D8ClosureGit {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Code
    )
    $output = @(& git -C $Root @Arguments 2>&1)
    Assert-R24D8Closure ($LASTEXITCODE -eq 0) (
        "$Code`:$($output -join '|')"
    )
    return @($output)
}

function Get-R24D8ClosureGitValue {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Code
    )
    $output = @(Invoke-R24D8ClosureGit `
        -Root $Root `
        -Arguments $Arguments `
        -Code $Code)
    Assert-R24D8Closure ($output.Count -eq 1) "${Code}_line_count"
    return ([string]$output[0]).Trim()
}

function Get-R24D8ClosureGitBlobBytes {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$RelativePath
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $RepositoryRoot, "cat-file", "blob", "${Commit}:$RelativePath"
    )) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-R24D8Closure ($process.Start()) "git_cat_file_start"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R24D8Closure ($process.ExitCode -eq 0) (
            "historical_blob_unavailable_${RelativePath}:$stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Get-R24D8ClosureCasPayload {
    param(
        [Parameter(Mandatory)][string]$RawSha256,
        [Parameter(Mandatory)][long]$ByteLength,
        [Parameter(Mandatory)][string]$Code
    )
    Assert-R24D8Closure (
        $RawSha256 -cmatch '^sha256:[0-9a-f]{64}$'
    ) "${Code}_digest_shape"
    $digest = $RawSha256.Substring(7)
    $directory = Join-Path $expectedEvidenceRoot "artifacts/sha256/$digest"
    Assert-R24D8Closure (
        Test-SporeSporeStoredArtifact `
            -Directory $directory `
            -ExpectedSha256 $digest `
            -ExpectedByteLength $ByteLength
    ) "${Code}_cas"
    return Join-Path $directory "payload.bin"
}

function Copy-R24D8ClosureValue {
    param([Parameter(Mandatory)]$Value)
    return $Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json `
        -AsHashtable -Depth 100
}

function Test-R24D8ClosureSemanticVector {
    param([Parameter(Mandatory)]$Candidate)
    try {
        $source = $Candidate.source
        $lineage = $Candidate.lineage
        $runtime = $Candidate.runtime
        $zero = $Candidate.prerequisite_zero_world
        $physical = $Candidate.physical_attempt
        $timing = $Candidate.timing_observation
        $retention = $Candidate.retention
        $statistics = $Candidate.statistical_claim_boundary
        $immutability = $Candidate.immutability
        $next = $Candidate.next_boundary
        $diagnostics = $Candidate.closure_audit_diagnostics
        $audit = $Candidate.audit_contract
        $claims = $Candidate.claims
        return (
            [string]$Candidate.schema_version -ceq
                "sporespore_qsdk_r24d8_active_step_snapshot_timing_positive_closure_v1" -and
            [string]$Candidate.closure_id -ceq "QSDK-R24D8-PH1-CLOSURE" -and
            [string]$Candidate.gate_id -ceq "QSDK-R24D8" -and
            [string]$Candidate.question_class -ceq "development" -and
            [string]$Candidate.status -ceq
                "zero_world_passed_physical_timing_positive_exact_finite_active_and_sleeping_semantics" -and
            [string]$Candidate.result_class -ceq
                "valid_finite_descriptive_development_timing_result" -and
            [string]$source.commit -ceq $sourceCommit -and
            [string]$source.tree_git_oid -ceq $sourceTree -and
            [string]$source.validation_manifest.raw_sha256 -ceq
                "sha256:463d51b301b4bf74f9b26dd99c528408bcb1daaf8f9097db81a41856cef1fc5c" -and
            [int]$source.validation_manifest.source_binding_count -eq 15 -and
            [int]$lineage.official_zero_world_attempt_count -eq 2 -and
            [int]$lineage.official_zero_world_incomplete_count -eq 1 -and
            [int]$lineage.official_zero_world_pass_count -eq 1 -and
            -not [bool]$lineage.predecessor_result_or_interpretation_rewritten -and
            -not [bool]$lineage.first_incomplete_result_or_interpretation_rewritten -and
            [string]$runtime.godot_source_commit -ceq $godotCommit -and
            [string]$runtime.combined_patch_raw_sha256 -ceq
                "sha256:$patchHash" -and
            [int]$runtime.patched_file_count -eq 10 -and
            [string]$runtime.console_binary_raw_sha256 -ceq
                "sha256:8a629f16859f653d447cd7f07f712f0045a1aed3f27be53413d97df6ff1ec0e6" -and
            [string]$runtime.engine_binary_raw_sha256 -ceq
                "sha256:0d77df42106c6d2f6fa51727d8051bf403e8a0273b3242daee581c93c4ba7257" -and
            [bool]$runtime.retained_binary_pair_executed -and
            -not [bool]$runtime.reproducible_build_claimed -and
            -not [bool]$runtime.result_reuse_authority -and
            [string]$zero.receipt_raw_sha256 -ceq
                "sha256:f89f37b077e329c57fde787ddd4adae307dc7ead033b6f896b9497d764014855" -and
            [int]$zero.static_stage_count -eq 5 -and
            [int]$zero.static_stage_pass_count -eq 5 -and
            [int]$zero.world_attempt_count -eq 0 -and
            [int]$zero.world_build_count -eq 0 -and
            [int]$zero.solver_step_count -eq 0 -and
            [string]$physical.receipt_raw_sha256 -ceq
                "sha256:a4bf658df837eaa991aa4421cbba1398949d1267558c738d5c5eb930800d886b" -and
            [string]$physical.result -ceq
                "finite_native_active_step_snapshot_timing_positive" -and
            [int]$physical.world_attempt_count -eq 1 -and
            [int]$physical.world_build_count -eq 1 -and
            [int]$physical.solver_step_count -eq 8 -and
            [int]$physical.retained_sample_count -eq 8 -and
            [int]$physical.same_source_repeat_count -eq 0 -and
            -not [bool]$physical.same_source_rerun_allowed -and
            (@($timing.fresh_step_indices) -join "|") -ceq "1|2|3|4" -and
            (@($timing.fresh_telemetry_sequences) -join "|") -ceq "2|3|4|5" -and
            (@($timing.fresh_capture_space_step_sequences) -join "|") -ceq
                "2|3|4|5" -and
            (@($timing.fresh_read_space_step_sequences) -join "|") -ceq
                "2|3|4|5" -and
            (@($timing.fresh_captured_during_active_step_values) -join "|") -ceq
                "True|True|True|True" -and
            (@($timing.fresh_snapshot_is_current_space_step_values) -join "|") -ceq
                "True|True|True|True" -and
            (@($timing.sleeping_step_indices) -join "|") -ceq "5|6|7|8" -and
            (@($timing.sleeping_telemetry_sequences) -join "|") -ceq "5|5|5|5" -and
            (@($timing.sleeping_capture_space_step_sequences) -join "|") -ceq
                "5|5|5|5" -and
            (@($timing.sleeping_read_space_step_sequences) -join "|") -ceq
                "6|7|8|9" -and
            (@($timing.sleeping_snapshot_is_current_space_step_values) -join "|") -ceq
                "False|False|False|False" -and
            [bool]$timing.active_step_capture_invariant_passed -and
            [bool]$timing.sleeping_stale_token_preservation_invariant_passed -and
            [int]$timing.raw_numerical_outcome_summary_count -eq 0 -and
            -not [bool]$timing.raw_numerical_values_accepted_as_accuracy_or_semantics_characterization -and
            @($Candidate.zero_world_retained_files).Count -eq 17 -and
            @($Candidate.physical_retained_files).Count -eq 13 -and
            [int]$retention.zero_world_unique_content_digest_count -eq 16 -and
            [int]$retention.physical_unique_content_digest_count -eq 12 -and
            [int]$retention.cross_run_unique_content_digest_count -eq 24 -and
            [int]$retention.closure_intake_file_count -eq 30 -and
            [bool]$retention.all_retained_files_content_addressed_before_closure_authority -and
            [string]$statistics.physical_question_class -ceq "development" -and
            @($statistics.empirical_acceptance_thresholds).Count -eq 0 -and
            @($statistics.superiority_margins).Count -eq 0 -and
            @($statistics.equivalence_or_non_inferiority_margins).Count -eq 0 -and
            @($statistics.held_out_validation_cohorts).Count -eq 0 -and
            @($statistics.population_claims).Count -eq 0 -and
            [bool]$immutability.same_source_zero_world_rerun_forbidden -and
            [bool]$immutability.same_source_physical_rerun_forbidden -and
            [bool]$immutability.r24d8_result_reinterpretation_forbidden -and
            [bool]$immutability.raw_numerical_outcome_promotion_forbidden -and
            [string]$next.work -ceq
                "distinct_prospectively_frozen_full_one_hinge_numerical_telemetry_characterization" -and
            [string]$next.question_class -ceq "development" -and
            [bool]$next.declaration_authorized -and
            -not [bool]$next.physical_execution_authorized -and
            -not [bool]$next.recovery_world_authorized -and
            -not [bool]$next.prone_to_standing_world_authorized -and
            [string]$diagnostics.path -ceq $diagnosticsRelative -and
            [string]$diagnostics.raw_sha256 -ceq
                "sha256:b6e4e7918ff43e46896e5ddb572d3c93fb6326e82d684712e54133b52d0622b7" -and
            [long]$diagnostics.byte_length -eq 5135 -and
            [int]$diagnostics.attempt_count -eq 5 -and
            [int]$diagnostics.negative_attempt_count -eq 4 -and
            [int]$diagnostics.passing_attempt_count -eq 1 -and
            [int]$diagnostics.world_attempt_count -eq 0 -and
            [int]$diagnostics.world_build_count -eq 0 -and
            [int]$diagnostics.solver_step_count -eq 0 -and
            [int]$audit.closure_mutation_rejection_count -eq 39 -and
            [int]$audit.diagnostic_mutation_rejection_count -eq 7 -and
            [bool]$audit.external_source_reconstruction_required -and
            [bool]$audit.executed_source_git_blob_verification_required -and
            [bool]$audit.complete_live_and_cas_inventory_verification_required -and
            [int]$audit.matching_physical_attempt_count_required -eq 1 -and
            [bool]$claims.complete_zero_world_gate_passed -and
            [bool]$claims.physical_world_executed -and
            [bool]$claims.valid_finite_descriptive_development_timing_result -and
            [bool]$claims.native_active_step_snapshot_timing_established_for_exact_fixture -and
            [bool]$claims.sleeping_stale_snapshot_preservation_established_for_exact_fixture -and
            -not [bool]$claims.native_numerical_telemetry_characterized -and
            -not [bool]$claims.numerical_accuracy_or_telemetry_values_accepted -and
            [int]$claims.empirical_acceptance_threshold_count -eq 0 -and
            [int]$claims.superiority_margin_count -eq 0 -and
            [int]$claims.equivalence_or_non_inferiority_margin_count -eq 0 -and
            [int]$claims.held_out_validation_cohort_count -eq 0 -and
            [int]$claims.population_claim_count -eq 0 -and
            -not [bool]$claims.instrumented_profile_promoted -and
            -not [bool]$claims.stock_godot_profile_promoted -and
            -not [bool]$claims.turning_claim_changed -and
            -not [bool]$claims.recovery_world_opened -and
            -not [bool]$claims.prone_to_standing_world_opened -and
            -not [bool]$claims.cross_engine_equivalence_claimed -and
            -not [bool]$claims.physical_acceptance_authority -and
            -not [bool]$claims.release_authority
        )
    } catch { return $false }
}

function Test-R24D8ClosureDiagnostics {
    param([Parameter(Mandatory)]$Candidate)
    try {
        $attempts = @($Candidate.attempts)
        $fourth = $attempts[3]
        $fifth = $attempts[4]
        $adequacy = $Candidate.adequacy
        $counts = $Candidate.actual_counts
        $claims = $Candidate.claims
        return (
            [string]$Candidate.schema_version -ceq
                "sporespore_qsdk_r24d8_positive_closure_precommit_diagnostics_v1" -and
            [string]$Candidate.gate_id -ceq "QSDK-R24D8" -and
            [string]$Candidate.question_class -ceq
                "non_physical_closure_conformance_development_diagnostics" -and
            [string]$Candidate.status -ceq
                "complete_local_closure_audit_pass_after_four_diagnostic_negatives" -and
            [int]$Candidate.attempt_count -eq 5 -and
            [int]$Candidate.negative_attempt_count -eq 4 -and
            [int]$Candidate.passing_attempt_count -eq 1 -and
            $attempts.Count -eq 5 -and
            (@($attempts | ForEach-Object { [int]$_.attempt_index }) -join "|") -ceq
                "1|2|3|4|5" -and
            @($attempts | Where-Object { [bool]$_.passed }).Count -eq 1 -and
            [string]$attempts[0].first_failed_gate -ceq
                "reconstructed_diff_patch" -and
            [string]$attempts[1].first_failed_gate -ceq
                "reconstructed_diff_patch" -and
            [string]$attempts[2].first_failed_gate -ceq
                "reconstructed_diff_patch" -and
            [string]$fourth.first_failed_gate -ceq
                "reconstructed_active_step_capture_order" -and
            [bool]$fourth.reconstructed_diff_exact -and
            [bool]$fifth.passed -and
            [string]$fifth.result -ceq
                "complete_positive_closure_conformance_pass" -and
            [int]$fifth.historical_source_binding_count -eq 15 -and
            [int]$fifth.reconstructed_external_source_file_count -eq 10 -and
            [int]$fifth.zero_world_retained_file_count -eq 17 -and
            [int]$fifth.physical_retained_file_count -eq 13 -and
            [int]$fifth.cross_run_unique_digest_count -eq 24 -and
            [int]$fifth.matching_physical_attempt_count -eq 1 -and
            [int]$fifth.closure_mutation_rejection_count -eq 38 -and
            @($attempts | Where-Object {
                -not [bool]$_.reconstructed_source_view_removed
            }).Count -eq 0 -and
            -not [bool]$adequacy.campaign_source_worker_evaluator_receipt_or_interpretation_changed -and
            -not [bool]$adequacy.physical_attempt_repeated -and
            -not [bool]$adequacy.retained_evidence_deleted_or_replaced -and
            [bool]$adequacy.reconstructed_view_derived_only_from_pinned_upstream_commit_and_executed_patch_blob -and
            -not [bool]$adequacy.safecrlf_warning_suppression_changed_reconstructed_source_bytes -and
            [bool]$adequacy.final_source_order_probe_matches_executed_r24d8_freeze_semantics -and
            [bool]$adequacy.every_temporary_worktree_removed -and
            [int]$counts.world_attempt_count -eq 0 -and
            [int]$counts.world_build_count -eq 0 -and
            [int]$counts.solver_step_count -eq 0 -and
            [int]$counts.physical_world_count -eq 0 -and
            -not [bool]$claims.complete_zero_world_gate_passed_by_diagnostics -and
            -not [bool]$claims.physical_timing_question_executed_by_diagnostics -and
            -not [bool]$claims.native_numerical_telemetry_characterized -and
            -not [bool]$claims.instrumented_profile_promoted -and
            -not [bool]$claims.recovery_world_opened -and
            -not [bool]$claims.prone_to_standing_world_opened -and
            -not [bool]$claims.turning_claim_changed -and
            -not [bool]$claims.cross_engine_equivalence_claimed -and
            -not [bool]$claims.physical_acceptance_authority -and
            -not [bool]$claims.release_authority
        )
    } catch { return $false }
}

function Test-R24D8ClosureInventory {
    param(
        [Parameter(Mandatory)][string]$RunRoot,
        [Parameter(Mandatory)][object[]]$Entries,
        [Parameter(Mandatory)][int]$ExpectedFileCount,
        [Parameter(Mandatory)][int]$ExpectedUniqueDigestCount,
        [Parameter(Mandatory)][string]$Code
    )
    $root = [IO.Path]::GetFullPath($RunRoot).TrimEnd("\", "/")
    Assert-R24D8Closure (
        $root.StartsWith(
            $expectedEvidenceRoot + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        (Test-Path -LiteralPath $root -PathType Container)
    ) "${Code}_run_root"
    $liveFiles = @(Get-ChildItem -LiteralPath $root -File -Recurse -Force)
    Assert-R24D8Closure (
        $Entries.Count -eq $ExpectedFileCount -and
        $liveFiles.Count -eq $ExpectedFileCount
    ) "${Code}_file_count"
    $byPath = @{}
    $uniqueDigests = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($entryValue in $Entries) {
        $entry = [hashtable]$entryValue
        $relative = [string]$entry.path
        Assert-R24D8Closure (-not $byPath.ContainsKey($relative)) (
            "${Code}_duplicate_path:$relative"
        )
        $byPath[$relative] = $entry
        [void]$uniqueDigests.Add([string]$entry.raw_sha256)
        $path = [IO.Path]::GetFullPath((Join-Path $root $relative))
        Assert-R24D8Closure (
            $path.StartsWith(
                $root + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            ) -and
            (Test-Path -LiteralPath $path -PathType Leaf) -and
            (Get-R24D8ClosureRawSha256 $path) -ceq
                [string]$entry.raw_sha256 -and
            (Get-Item -LiteralPath $path).Length -eq [long]$entry.byte_length
        ) "${Code}_live_file:$relative"
        [void](Get-R24D8ClosureCasPayload `
            -RawSha256 ([string]$entry.raw_sha256) `
            -ByteLength ([long]$entry.byte_length) `
            -Code "${Code}_$relative")
    }
    foreach ($file in $liveFiles) {
        $relative = [IO.Path]::GetRelativePath($root, $file.FullName).
            Replace("\", "/")
        Assert-R24D8Closure ($byPath.ContainsKey($relative)) (
            "${Code}_unlisted_file:$relative"
        )
    }
    Assert-R24D8Closure (
        $byPath.Count -eq $ExpectedFileCount -and
        $uniqueDigests.Count -eq $ExpectedUniqueDigestCount
    ) "${Code}_inventory_counts"
    return [ordered]@{
        root = $root
        by_path = $byPath
        unique_digests = $uniqueDigests
    }
}

function Get-R24D8ClosureRetainedJson {
    param(
        [Parameter(Mandatory)]$Inventory,
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$Code
    )
    Assert-R24D8Closure (
        $Inventory.by_path.ContainsKey($RelativePath)
    ) "${Code}_unknown_path"
    $entry = [hashtable]$Inventory.by_path[$RelativePath]
    $payload = Get-R24D8ClosureCasPayload `
        -RawSha256 ([string]$entry.raw_sha256) `
        -ByteLength ([long]$entry.byte_length) `
        -Code $Code
    return Get-Content -Raw -LiteralPath $payload |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Assert-R24D8ClosureSamples {
    param([Parameter(Mandatory)][object[]]$Samples)
    Assert-R24D8Closure ($Samples.Count -eq 8) "sample_count"
    foreach ($index in 0..3) {
        $sample = [hashtable]$Samples[$index]
        $telemetry = [hashtable]$sample.telemetry
        $expectedSequence = $index + 2
        Assert-R24D8Closure (
            [string]$sample.phase -ceq "fresh_active" -and
            [int]$sample.step_index -eq ($index + 1) -and
            -not [bool]$sample.child_sleeping -and
            [string]$telemetry.schema -ceq
                "sporespore.godot_jolt_hinge_motor_telemetry.v2" -and
            [bool]$telemetry.captured_during_active_step -and
            [bool]$telemetry.snapshot_is_current_space_step -and
            [long]$telemetry.telemetry_sequence -eq $expectedSequence -and
            [long]$telemetry.capture_space_step_sequence -eq $expectedSequence -and
            [long]$telemetry.read_space_step_sequence -eq $expectedSequence
        ) "fresh_sample_$index"
    }
    foreach ($index in 4..7) {
        $sample = [hashtable]$Samples[$index]
        $telemetry = [hashtable]$sample.telemetry
        Assert-R24D8Closure (
            [string]$sample.phase -ceq "sleeping_stale" -and
            [int]$sample.step_index -eq ($index + 1) -and
            [bool]$sample.child_sleeping -and
            [string]$telemetry.schema -ceq
                "sporespore.godot_jolt_hinge_motor_telemetry.v2" -and
            [bool]$telemetry.captured_during_active_step -and
            -not [bool]$telemetry.snapshot_is_current_space_step -and
            [long]$telemetry.telemetry_sequence -eq 5 -and
            [long]$telemetry.capture_space_step_sequence -eq 5 -and
            [long]$telemetry.read_space_step_sequence -eq ($index + 2)
        ) "sleeping_sample_$index"
    }
}

$repoTop = Get-R24D8ClosureGitValue `
    -Root $repoRoot `
    -Arguments @("rev-parse", "--show-toplevel") `
    -Code "repository_top"
$repoRemote = Get-R24D8ClosureGitValue `
    -Root $repoRoot `
    -Arguments @("remote", "get-url", "origin") `
    -Code "repository_remote"
Assert-R24D8Closure (
    [IO.Path]::GetFullPath($repoTop) -ceq $expectedRepoRoot -and
    $repoRoot -ceq $expectedRepoRoot -and
    $repoRemote -ceq $expectedRepoRemote
) "repository_identity"

$closurePath = Join-Path $repoRoot $closureRelative
Assert-R24D8Closure (
    Test-Path -LiteralPath $closurePath -PathType Leaf
) "closure_missing"
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D8Closure (Test-R24D8ClosureSemanticVector $closure) (
    "closure_semantic_vector"
)

$mutations = @(
    { param($v) $v.status = "invalid" },
    { param($v) $v.result_class = "invalid" },
    { param($v) $v.source.commit = "bad" },
    { param($v) $v.source.tree_git_oid = "bad" },
    { param($v) $v.source.validation_manifest.source_binding_count = 14 },
    { param($v) $v.lineage.official_zero_world_incomplete_count = 0 },
    { param($v) $v.lineage.official_zero_world_pass_count = 0 },
    { param($v) $v.runtime.engine_binary_raw_sha256 = "sha256:bad" },
    { param($v) $v.prerequisite_zero_world.receipt_raw_sha256 = "sha256:bad" },
    { param($v) $v.prerequisite_zero_world.static_stage_pass_count = 4 },
    { param($v) $v.prerequisite_zero_world.world_attempt_count = 1 },
    { param($v) $v.physical_attempt.receipt_raw_sha256 = "sha256:bad" },
    { param($v) $v.physical_attempt.world_attempt_count = 2 },
    { param($v) $v.physical_attempt.world_build_count = 0 },
    { param($v) $v.physical_attempt.solver_step_count = 7 },
    { param($v) $v.physical_attempt.retained_sample_count = 7 },
    { param($v) $v.physical_attempt.same_source_rerun_allowed = $true },
    { param($v) $v.timing_observation.fresh_telemetry_sequences[3] = 4 },
    { param($v) $v.timing_observation.fresh_captured_during_active_step_values[0] = $false },
    { param($v) $v.timing_observation.fresh_snapshot_is_current_space_step_values[0] = $false },
    { param($v) $v.timing_observation.sleeping_telemetry_sequences[0] = 6 },
    { param($v) $v.timing_observation.sleeping_capture_space_step_sequences[0] = 6 },
    { param($v) $v.timing_observation.sleeping_read_space_step_sequences[3] = 8 },
    { param($v) $v.timing_observation.sleeping_snapshot_is_current_space_step_values[0] = $true },
    { param($v) $v.timing_observation.raw_numerical_values_accepted_as_accuracy_or_semantics_characterization = $true },
    { param($v) $v.statistical_claim_boundary.empirical_acceptance_thresholds = @(0.1) },
    { param($v) $v.immutability.same_source_physical_rerun_forbidden = $false },
    { param($v) $v.next_boundary.physical_execution_authorized = $true },
    { param($v) $v.claims.valid_finite_descriptive_development_timing_result = $false },
    { param($v) $v.claims.native_active_step_snapshot_timing_established_for_exact_fixture = $false },
    { param($v) $v.claims.native_numerical_telemetry_characterized = $true },
    { param($v) $v.claims.instrumented_profile_promoted = $true },
    { param($v) $v.claims.turning_claim_changed = $true },
    { param($v) $v.claims.prone_to_standing_world_opened = $true },
    { param($v) $v.claims.recovery_world_opened = $true },
    { param($v) $v.claims.cross_engine_equivalence_claimed = $true },
    { param($v) $v.claims.physical_acceptance_authority = $true },
    { param($v) $v.claims.release_authority = $true },
    { param($v) $v.closure_audit_diagnostics.raw_sha256 = "sha256:bad" }
)
$mutationPasses = 0
foreach ($mutation in $mutations) {
    $candidate = Copy-R24D8ClosureValue $closure
    & $mutation $candidate
    if (-not (Test-R24D8ClosureSemanticVector $candidate)) {
        $mutationPasses += 1
    }
}
Assert-R24D8Closure (
    $mutations.Count -eq 39 -and $mutationPasses -eq 39
) "closure_mutation_controls"

$diagnosticsPath = Join-Path $repoRoot $diagnosticsRelative
$diagnosticsBinding = [hashtable]$closure.closure_audit_diagnostics
Assert-R24D8Closure (
    (Test-Path -LiteralPath $diagnosticsPath -PathType Leaf) -and
    (Get-R24D8ClosureRawSha256 $diagnosticsPath) -ceq
        [string]$diagnosticsBinding.raw_sha256 -and
    (Get-Item -LiteralPath $diagnosticsPath).Length -eq
        [long]$diagnosticsBinding.byte_length
) "closure_diagnostics_identity"
$diagnostics = Get-Content -Raw -LiteralPath $diagnosticsPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D8Closure (Test-R24D8ClosureDiagnostics $diagnostics) (
    "closure_diagnostics_semantics"
)
$diagnosticMutations = @(
    { param($v) $v.attempt_count = 4 },
    { param($v) $v.negative_attempt_count = 3 },
    { param($v) $v.attempts[3].first_failed_gate = "different" },
    { param($v) $v.attempts[4].passed = $false },
    { param($v) $v.adequacy.every_temporary_worktree_removed = $false },
    { param($v) $v.actual_counts.world_attempt_count = 1 },
    { param($v) $v.claims.physical_acceptance_authority = $true }
)
$diagnosticMutationPasses = 0
foreach ($mutation in $diagnosticMutations) {
    $candidate = Copy-R24D8ClosureValue $diagnostics
    & $mutation $candidate
    if (-not (Test-R24D8ClosureDiagnostics $candidate)) {
        $diagnosticMutationPasses += 1
    }
}
Assert-R24D8Closure (
    $diagnosticMutations.Count -eq 7 -and
    $diagnosticMutationPasses -eq 7
) "closure_diagnostic_mutation_controls"

$resolvedTree = Get-R24D8ClosureGitValue `
    -Root $repoRoot `
    -Arguments @("rev-parse", "$sourceCommit`^{tree}") `
    -Code "source_tree"
Assert-R24D8Closure ($resolvedTree -ceq $sourceTree) "source_tree_identity"

$manifestBinding = [hashtable]$closure.source.validation_manifest
$manifestBytes = Get-R24D8ClosureGitBlobBytes `
    -RepositoryRoot $repoRoot `
    -Commit $sourceCommit `
    -RelativePath ([string]$manifestBinding.path)
$manifestBlob = Get-R24D8ClosureGitValue `
    -Root $repoRoot `
    -Arguments @("rev-parse", "$sourceCommit`:$([string]$manifestBinding.path)") `
    -Code "manifest_blob"
Assert-R24D8Closure (
    (Get-R24D8ClosureBytesSha256 $manifestBytes) -ceq
        [string]$manifestBinding.raw_sha256 -and
    $manifestBytes.Length -eq [long]$manifestBinding.byte_length -and
    $manifestBlob -ceq [string]$manifestBinding.git_blob_oid
) "historical_manifest_identity"
$manifest = [Text.Encoding]::UTF8.GetString($manifestBytes) |
    ConvertFrom-Json -AsHashtable -Depth 100
$sourceBindings = @($manifest.source_bindings)
Assert-R24D8Closure (
    [string]$manifest.status -ceq
        "prospective_maintenance_source_bytes_bound_after_one_incomplete_official_zero_world_attempt_official_zero_world_pending" -and
    [int]$manifest.source_binding_count -eq 15 -and
    $sourceBindings.Count -eq 15 -and
    -not [bool]$manifest.includes_self -and
    [int]$manifest.official_zero_world_qualification_count -eq 0 -and
    [int]$manifest.world_attempt_count -eq 0
) "historical_manifest_semantics"
foreach ($bindingValue in $sourceBindings) {
    $binding = [hashtable]$bindingValue
    $relative = [string]$binding.path
    $bytes = Get-R24D8ClosureGitBlobBytes `
        -RepositoryRoot $repoRoot `
        -Commit $sourceCommit `
        -RelativePath $relative
    $blob = Get-R24D8ClosureGitValue `
        -Root $repoRoot `
        -Arguments @("rev-parse", "$sourceCommit`:$relative") `
        -Code "source_blob:$relative"
    Assert-R24D8Closure (
        (Get-R24D8ClosureBytesSha256 $bytes) -ceq
            [string]$binding.raw_sha256 -and
        $bytes.Length -eq [long]$binding.byte_length -and
        $blob -ceq [string]$binding.git_blob_oid
    ) "source_binding:$relative"
}

$godotRoot = [IO.Path]::GetFullPath($GodotRepositoryRoot)
Assert-R24D8Closure ($godotRoot -ceq $expectedGodotRoot) (
    "godot_repository_substitution_forbidden"
)
$godotRemote = Get-R24D8ClosureGitValue `
    -Root $godotRoot `
    -Arguments @("remote", "get-url", "origin") `
    -Code "godot_remote"
[void](Invoke-R24D8ClosureGit `
    -Root $godotRoot `
    -Arguments @("cat-file", "-e", "$godotCommit`^{commit}") `
    -Code "godot_commit_available")
Assert-R24D8Closure ($godotRemote -ceq $expectedGodotRemote) (
    "godot_remote_identity"
)

$patchRelative = [string]$closure.runtime.combined_patch_path
$patchBytes = Get-R24D8ClosureGitBlobBytes `
    -RepositoryRoot $repoRoot `
    -Commit $sourceCommit `
    -RelativePath $patchRelative
Assert-R24D8Closure (
    (Get-R24D8ClosureBytesSha256 $patchBytes) -ceq "sha256:$patchHash" -and
    $patchBytes.Length -eq 18593
) "historical_patch_identity"
$patchText = [Text.Encoding]::UTF8.GetString($patchBytes).Replace("`r`n", "`n")
Assert-R24D8Closure (
    [regex]::Matches($patchText, "(?m)^diff --git ").Count -eq 10
) "historical_patch_file_count"

$scratchBase = [IO.Path]::GetFullPath(
    (Join-Path $expectedEvidenceRoot "qualification-scratch")
)
if ([string]::IsNullOrWhiteSpace($ScratchRoot)) {
    $ScratchRoot = Join-Path $scratchBase (
        "r24d8-positive-closure-$PID-$([Guid]::NewGuid().ToString('N'))"
    )
}
$scratchSession = [IO.Path]::GetFullPath($ScratchRoot)
Assert-R24D8Closure (
    $scratchSession.StartsWith(
        $scratchBase + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    -not (Test-Path -LiteralPath $scratchSession)
) "reconstructed_source_scratch_boundary"
[void][IO.Directory]::CreateDirectory($scratchSession)
$viewRoot = Join-Path $scratchSession "source"
$patchPath = Join-Path $scratchSession "r24d8.patch"
[IO.File]::WriteAllBytes($patchPath, $patchBytes)
$patchPaths = @(
    & git -C $repoRoot apply --numstat -- $patchPath 2>&1 |
        ForEach-Object {
            $parts = ([string]$_) -split "`t"
            if ($parts.Count -eq 3) { $parts[2].Replace("\", "/") }
        }
)
Assert-R24D8Closure (
    $LASTEXITCODE -eq 0 -and
    $patchPaths.Count -eq 10 -and
    @($patchPaths | Sort-Object -Unique).Count -eq 10
) "reconstructed_patch_paths"
$worktreeCountBefore = @(
    & git -C $godotRoot worktree list --porcelain |
        Where-Object { ([string]$_).StartsWith("worktree ") }
).Count
Assert-R24D8Closure (
    $LASTEXITCODE -eq 0 -and $worktreeCountBefore -ge 1
) "godot_worktree_count_before"
$worktreeAdded = $false
try {
    [void](Invoke-R24D8ClosureGit `
        -Root $godotRoot `
        -Arguments @(
            "worktree", "add", "--detach", "--no-checkout", $viewRoot, $godotCommit
        ) `
        -Code "reconstructed_worktree_add")
    $worktreeAdded = $true
    [void](Invoke-R24D8ClosureGit `
        -Root $viewRoot `
        -Arguments (@("sparse-checkout", "set", "--no-cone") + $patchPaths) `
        -Code "reconstructed_sparse_checkout")
    [void](Invoke-R24D8ClosureGit `
        -Root $viewRoot `
        -Arguments @("checkout", "--force", $godotCommit) `
        -Code "reconstructed_checkout")
    [void](Invoke-R24D8ClosureGit `
        -Root $viewRoot `
        -Arguments @("apply", "--whitespace=nowarn", "--", $patchPath) `
        -Code "reconstructed_patch_apply")
    $statusLines = @(& git -C $viewRoot status --short 2>&1)
    Assert-R24D8Closure ($LASTEXITCODE -eq 0) "reconstructed_status"
    $statusPaths = @($statusLines | ForEach-Object {
        ([string]$_).Substring(3).Replace("\", "/")
    })
    Assert-R24D8Closure (
        (($statusPaths | Sort-Object) -join "|") -ceq
            (($patchPaths | Sort-Object) -join "|")
    ) "reconstructed_status_paths"
    $diffLines = @(
        & git -C $viewRoot -c core.safecrlf=false diff --no-ext-diff 2>&1
    )
    Assert-R24D8Closure ($LASTEXITCODE -eq 0) "reconstructed_diff"
    $diffText = (($diffLines -join "`n") + "`n").Replace("`r`n", "`n")
    $expectedDiffText = $patchText.TrimEnd("`n") + "`n"
    $actualDiffLines = @($diffText -split "`n")
    $expectedDiffLines = @($expectedDiffText -split "`n")
    $firstDiffLine = -1
    $sharedDiffLineCount = [Math]::Min(
        $actualDiffLines.Count,
        $expectedDiffLines.Count
    )
    for ($diffLineIndex = 0; $diffLineIndex -lt $sharedDiffLineCount; $diffLineIndex++) {
        if ($actualDiffLines[$diffLineIndex] -cne $expectedDiffLines[$diffLineIndex]) {
            $firstDiffLine = $diffLineIndex
            break
        }
    }
    Assert-R24D8Closure (
        $diffText -ceq $expectedDiffText
    ) (
        "reconstructed_diff_patch:" +
        "actual=$(Get-R24D8ClosureBytesSha256 ([Text.Encoding]::UTF8.GetBytes($diffText)))" +
        "/$($diffText.Length)/$($actualDiffLines.Count);" +
        "expected=$(Get-R24D8ClosureBytesSha256 ([Text.Encoding]::UTF8.GetBytes($expectedDiffText)))" +
        "/$($expectedDiffText.Length)/$($expectedDiffLines.Count);" +
        "first_line=$firstDiffLine;" +
        "actual_line=$([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$actualDiffLines[$firstDiffLine])));" +
        "expected_line=$([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$expectedDiffLines[$firstDiffLine])))"
    )
    $reverse = @(
        & git -C $viewRoot apply --reverse --check --whitespace=error-all `
            $patchPath 2>&1
    )
    Assert-R24D8Closure ($LASTEXITCODE -eq 0) (
        "reconstructed_reverse_check:$($reverse -join '|')"
    )
    $spaceText = [IO.File]::ReadAllText((Join-Path $viewRoot (
        "modules/jolt_physics/spaces/jolt_space_3d.cpp"
    ))).Replace("`r`n", "`n")
    $stepStartIndex = $spaceText.IndexOf(
        "void JoltSpace3D::step(float p_step)",
        [StringComparison]::Ordinal
    )
    $steppingTrueIndex = $spaceText.IndexOf(
        "stepping = true;", $stepStartIndex
    )
    $updateIndex = $spaceText.IndexOf(
        "physics_system->Update", $stepStartIndex
    )
    $captureIndex = $spaceText.IndexOf(
        "_capture_joint_telemetry(p_step);", $stepStartIndex
    )
    $postIndex = $spaceText.IndexOf(
        "_post_step(p_step);", $stepStartIndex
    )
    $steppingFalseIndex = $spaceText.IndexOf(
        "stepping = false;", $stepStartIndex
    )
    Assert-R24D8Closure (
        $stepStartIndex -ge 0 -and
        $stepStartIndex -lt $steppingTrueIndex -and
        $steppingTrueIndex -lt $updateIndex -and
        $captureIndex -gt $updateIndex -and
        $postIndex -gt $captureIndex -and
        $steppingFalseIndex -gt $postIndex
    ) "reconstructed_active_step_capture_order"
} finally {
    if ($worktreeAdded) {
        [void](Invoke-R24D8ClosureGit `
            -Root $godotRoot `
            -Arguments @("worktree", "remove", "--force", "--", $viewRoot) `
            -Code "reconstructed_worktree_remove")
    }
    if (Test-Path -LiteralPath $scratchSession) {
        $validatedScratch = [IO.Path]::GetFullPath($scratchSession)
        Assert-R24D8Closure (
            $validatedScratch.StartsWith(
                $scratchBase + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            ) -and
            (Split-Path -Leaf $validatedScratch).StartsWith(
                "r24d8-positive-closure-", [StringComparison]::Ordinal
            )
        ) "reconstructed_scratch_cleanup_boundary"
        Remove-Item -LiteralPath $validatedScratch -Recurse -Force
    }
}
$worktreeCountAfter = @(
    & git -C $godotRoot worktree list --porcelain |
        Where-Object { ([string]$_).StartsWith("worktree ") }
).Count
Assert-R24D8Closure (
    $LASTEXITCODE -eq 0 -and
    $worktreeCountAfter -eq $worktreeCountBefore -and
    -not (Test-Path -LiteralPath $scratchSession)
) "reconstructed_source_cleanup"

$zeroInventory = Test-R24D8ClosureInventory `
    -RunRoot ([string]$closure.prerequisite_zero_world.run_root) `
    -Entries @($closure.zero_world_retained_files) `
    -ExpectedFileCount 17 `
    -ExpectedUniqueDigestCount 16 `
    -Code "zero_world"
$physicalInventory = Test-R24D8ClosureInventory `
    -RunRoot ([string]$closure.physical_attempt.run_root) `
    -Entries @($closure.physical_retained_files) `
    -ExpectedFileCount 13 `
    -ExpectedUniqueDigestCount 12 `
    -Code "physical"
$crossRunDigests = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::Ordinal
)
foreach ($digest in @(
    @($zeroInventory.unique_digests) + @($physicalInventory.unique_digests)
)) {
    [void]$crossRunDigests.Add([string]$digest)
}
Assert-R24D8Closure ($crossRunDigests.Count -eq 24) (
    "cross_run_unique_digest_count"
)

$zeroReceipt = Get-R24D8ClosureRetainedJson `
    -Inventory $zeroInventory `
    -RelativePath "receipt.json" `
    -Code "zero_receipt"
$zeroStageNames = @($zeroReceipt.stages | ForEach-Object { [string]$_.name })
Assert-R24D8Closure (
    [string]$zeroReceipt.schema_version -ceq
        "sporespore_qsdk_r24d8_active_step_snapshot_zero_world_receipt_v1" -and
    [bool]$zeroReceipt.ok -and
    [string]$zeroReceipt.status -ceq
        "complete_zero_world_gate_passed_physical_execution_separately_authorized" -and
    [string]$zeroReceipt.source.head -ceq $sourceCommit -and
    [bool]$zeroReceipt.source.worktree_clean -and
    ($zeroStageNames -join "|") -ceq
        "immutable_r24d7_closure|r24d8_freeze|r24d8_evaluator_self_test|cold_cleanup|cold_build" -and
    [string]$zeroReceipt.validation_manifest.raw_sha256 -ceq
        [string]$closure.source.validation_manifest.raw_sha256 -and
    [string]$zeroReceipt.binary_pair.console.raw_sha256 -ceq
        [string]$closure.runtime.console_binary_raw_sha256 -and
    [string]$zeroReceipt.binary_pair.engine.raw_sha256 -ceq
        [string]$closure.runtime.engine_binary_raw_sha256 -and
    [int]$zeroReceipt.worker.receipt.world_attempt_count -eq 0 -and
    [string]$zeroReceipt.evaluation.receipt.result -ceq
        "synthetic_shape_conforms_zero_world_only" -and
    [int]$zeroReceipt.actual_counts.world_attempt_count -eq 0 -and
    [int]$zeroReceipt.actual_counts.world_build_count -eq 0 -and
    [int]$zeroReceipt.actual_counts.solver_step_count -eq 0 -and
    [bool]$zeroReceipt.claims.complete_zero_world_gate_passed -and
    -not [bool]$zeroReceipt.claims.physical_timing_question_executed -and
    -not [bool]$zeroReceipt.claims.physical_acceptance_authority -and
    -not [bool]$zeroReceipt.claims.release_authority
) "zero_receipt_semantics"

$attempt = Get-R24D8ClosureRetainedJson `
    -Inventory $physicalInventory `
    -RelativePath "attempt.json" `
    -Code "physical_attempt"
$raw = Get-R24D8ClosureRetainedJson `
    -Inventory $physicalInventory `
    -RelativePath "raw-report.json" `
    -Code "physical_raw"
$evaluation = Get-R24D8ClosureRetainedJson `
    -Inventory $physicalInventory `
    -RelativePath "evaluation.json" `
    -Code "physical_evaluation"
$physicalReceipt = Get-R24D8ClosureRetainedJson `
    -Inventory $physicalInventory `
    -RelativePath "receipt.json" `
    -Code "physical_receipt"
Assert-R24D8Closure (
    [string]$attempt.schema_version -ceq
        "sporespore_qsdk_r24d8_physical_attempt_v1" -and
    [string]$attempt.status -ceq "consumed_before_worker_launch" -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.execution_nonce -ceq
        [string]$closure.physical_attempt.execution_nonce -and
    [string]$attempt.console_binary_sha256 -ceq
        [string]$closure.runtime.console_binary_raw_sha256 -and
    [string]$attempt.engine_binary_sha256 -ceq
        [string]$closure.runtime.engine_binary_raw_sha256 -and
    [string]$attempt.zero_world_receipt_sha256 -ceq
        [string]$closure.prerequisite_zero_world.receipt_raw_sha256 -and
    [int]$attempt.declared_world_attempt_count -eq 1 -and
    [int]$attempt.declared_solver_step_count -eq 8 -and
    -not [bool]$attempt.same_source_rerun_allowed
) "physical_attempt_semantics"
Assert-R24D8Closure (
    [string]$raw.schema_version -ceq
        "sporespore_qsdk_r24d8_godot_jolt_active_step_snapshot_timing_raw_report_v1" -and
    [string]$raw.source_commit -ceq $sourceCommit -and
    [string]$raw.execution_nonce -ceq [string]$attempt.execution_nonce -and
    [string]$raw.evidence_kind -ceq "native_physical" -and
    [bool]$raw.evidence_provenance.native_physical_observation -and
    -not [bool]$raw.evidence_provenance.synthetic_shape_only -and
    [int]$raw.execution.world_attempt_count -eq 1 -and
    [int]$raw.execution.world_build_count -eq 1 -and
    [int]$raw.execution.physics_step_count -eq 8 -and
    [int]$raw.execution.retained_sample_count -eq 8 -and
    -not [bool]$raw.claims.native_numerical_telemetry_characterized -and
    -not [bool]$raw.claims.instrumented_profile_promoted -and
    -not [bool]$raw.claims.physical_acceptance_authority -and
    -not [bool]$raw.claims.release_authority
) "physical_raw_semantics"
Assert-R24D8ClosureSamples -Samples @($raw.samples)
Assert-R24D8Closure (
    [string]$evaluation.schema_version -ceq
        "sporespore_qsdk_r24d8_godot_jolt_active_step_snapshot_timing_evaluation_v1" -and
    [bool]$evaluation.ok -and
    [string]$evaluation.result -ceq
        "finite_native_active_step_snapshot_timing_positive" -and
    [string]$evaluation.source_commit -ceq $sourceCommit -and
    [string]$evaluation.execution_nonce -ceq [string]$attempt.execution_nonce -and
    [string]$evaluation.raw_report_sha256 -ceq
        [string]$closure.physical_attempt.raw_report_raw_sha256 -and
    [int]$evaluation.timing_observations.fresh_sample_count -eq 4 -and
    [int]$evaluation.timing_observations.stale_sample_count -eq 4 -and
    [long]$evaluation.timing_observations.final_fresh_telemetry_sequence -eq 5 -and
    [long]$evaluation.timing_observations.final_stale_read_space_step_sequence -eq 9 -and
    [int]$evaluation.empirical_acceptance_threshold_count -eq 0 -and
    -not [bool]$evaluation.native_numerical_telemetry_characterized -and
    -not [bool]$evaluation.instrumented_profile_promoted -and
    -not [bool]$evaluation.physical_acceptance_authority -and
    -not [bool]$evaluation.release_authority
) "physical_evaluation_semantics"
$physicalRecheckNames = @(
    $physicalReceipt.rechecks | ForEach-Object { [string]$_.name }
)
Assert-R24D8Closure (
    [string]$physicalReceipt.schema_version -ceq
        "sporespore_qsdk_r24d8_active_step_snapshot_physical_receipt_v1" -and
    [bool]$physicalReceipt.ok -and
    [string]$physicalReceipt.status -ceq
        "finite_native_active_step_snapshot_timing_positive" -and
    [string]$physicalReceipt.source.head -ceq $sourceCommit -and
    [string]$physicalReceipt.attempt.raw_sha256 -ceq
        [string]$closure.physical_attempt.attempt_record_raw_sha256 -and
    [string]$physicalReceipt.zero_world_receipt.raw_sha256 -ceq
        [string]$closure.prerequisite_zero_world.receipt_raw_sha256 -and
    [bool]$physicalReceipt.zero_world_receipt_cas_verified -and
    ($physicalRecheckNames -join "|") -ceq
        "immutable_r24d7_closure_recheck|r24d8_freeze_recheck" -and
    [string]$physicalReceipt.worker.raw_report.raw_sha256 -ceq
        [string]$closure.physical_attempt.raw_report_raw_sha256 -and
    [string]$physicalReceipt.evaluation.file.raw_sha256 -ceq
        [string]$closure.physical_attempt.evaluation_raw_sha256 -and
    [int]$physicalReceipt.finite_counts.world_attempt_count -eq 1 -and
    [int]$physicalReceipt.finite_counts.world_build_count -eq 1 -and
    [int]$physicalReceipt.finite_counts.solver_step_count -eq 8 -and
    [int]$physicalReceipt.finite_counts.retained_sample_count -eq 8 -and
    [int]$physicalReceipt.finite_counts.same_source_repeat_count -eq 0 -and
    [bool]$physicalReceipt.claims.physical_timing_question_executed -and
    [bool]$physicalReceipt.claims.active_step_capture_observed -and
    [bool]$physicalReceipt.claims.sleeping_stale_preservation_observed -and
    -not [bool]$physicalReceipt.claims.native_numerical_telemetry_characterized -and
    -not [bool]$physicalReceipt.claims.instrumented_profile_promoted -and
    -not [bool]$physicalReceipt.claims.prone_to_standing_world_opened -and
    -not [bool]$physicalReceipt.claims.physical_acceptance_authority -and
    -not [bool]$physicalReceipt.claims.release_authority
) "physical_receipt_semantics"

$physicalParent = Split-Path -Parent ([string]$closure.physical_attempt.run_root)
$matchingAttempts = [Collections.Generic.List[string]]::new()
foreach ($attemptFile in @(Get-ChildItem -LiteralPath $physicalParent `
    -Filter "attempt.json" -File -Recurse)) {
    $candidate = Get-Content -Raw -LiteralPath $attemptFile.FullName |
        ConvertFrom-Json -AsHashtable -Depth 100
    if (
        [string]$candidate.source_commit -ceq $sourceCommit -and
        [string]$candidate.console_binary_sha256 -ceq
            [string]$closure.runtime.console_binary_raw_sha256 -and
        [string]$candidate.engine_binary_sha256 -ceq
            [string]$closure.runtime.engine_binary_raw_sha256
    ) {
        $matchingAttempts.Add($attemptFile.FullName)
    }
}
$expectedAttemptPath = [IO.Path]::GetFullPath((Join-Path (
    [string]$closure.physical_attempt.run_root
) "attempt.json"))
Assert-R24D8Closure (
    $matchingAttempts.Count -eq 1 -and
    [IO.Path]::GetFullPath($matchingAttempts[0]) -ceq $expectedAttemptPath
) "matching_physical_attempt_count"

Write-Output (
    $markerPrefix +
    ([ordered]@{
        ok = $true
        closure_id = "QSDK-R24D8-PH1-CLOSURE"
        status = [string]$closure.status
        result_class = [string]$closure.result_class
        question_class = "development"
        source_commit = $sourceCommit
        source_binding_count = 15
        reconstructed_external_source_file_count = 10
        reconstructed_external_source_view_removed = $true
        godot_worktree_count_before = $worktreeCountBefore
        godot_worktree_count_after = $worktreeCountAfter
        zero_world_retained_file_count = 17
        zero_world_unique_digest_count = 16
        physical_retained_file_count = 13
        physical_unique_digest_count = 12
        cross_run_unique_digest_count = 24
        world_attempt_count = 1
        world_build_count = 1
        solver_step_count = 8
        retained_sample_count = 8
        fresh_sample_count = 4
        sleeping_stale_sample_count = 4
        closure_mutation_rejection_count = $mutations.Count
        closure_diagnostic_attempt_count = 5
        closure_diagnostic_negative_count = 4
        closure_diagnostic_mutation_rejection_count = $diagnosticMutations.Count
        same_source_rerun_forbidden = $true
        native_active_step_snapshot_timing_established = $true
        sleeping_stale_snapshot_preservation_established = $true
        native_numerical_telemetry_characterized = $false
        instrumented_profile_promoted = $false
        recovery_world_opened = $false
        prone_to_standing_world_opened = $false
        turning_claim_changed = $false
        cross_engine_equivalence_claimed = $false
        physical_acceptance_authority = $false
        release_authority = $false
    } | ConvertTo-Json -Depth 30 -Compress)
)

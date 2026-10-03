#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$GodotSourceRoot =
        "C:\Users\Cole\CodeStuff\dependencies\godot-sporespore-4.7"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$closureRelative = (
    "sdk/recovery/r24d7_godot_jolt_one_hinge_telemetry_" +
    "physical_failure_closure_v1.json"
)
$closurePath = Join-Path $repoRoot $closureRelative
. (Join-Path $repoRoot "sdk/content_addressed_artifact_store.ps1")

function Assert-R24D7PhysicalClosure {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Code
    )
    if (-not $Condition) {
        throw "QSDK-R24D7 physical failure closure: $Code"
    }
}

function Get-R24D7RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R24D7BytesSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R24D7GitBlobBytes {
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
    Assert-R24D7PhysicalClosure ($process.Start()) "git_cat_file_start"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R24D7PhysicalClosure ($process.ExitCode -eq 0) (
            "historical_blob_unavailable_${RelativePath}:$stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Get-R24D7CasPayloadPath {
    param(
        [Parameter(Mandatory)][string]$EvidenceRoot,
        [Parameter(Mandatory)][string]$RawSha256,
        [Parameter(Mandatory)][long]$ByteLength,
        [Parameter(Mandatory)][string]$Code
    )
    Assert-R24D7PhysicalClosure (
        $RawSha256 -cmatch '^sha256:[0-9a-f]{64}$'
    ) "${Code}_digest_shape"
    $digest = $RawSha256.Substring(7)
    $directory = Join-Path $EvidenceRoot "artifacts/sha256/$digest"
    Assert-R24D7PhysicalClosure (
        Test-SporeSporeStoredArtifact `
            -Directory $directory `
            -ExpectedSha256 $digest `
            -ExpectedByteLength $ByteLength
    ) "${Code}_cas"
    return Join-Path $directory "payload.bin"
}

function Get-R24D7Marker {
    param(
        [AllowEmptyString()][Parameter(Mandatory)][string[]]$Lines,
        [Parameter(Mandatory)][string]$Prefix,
        [Parameter(Mandatory)][string]$Code
    )
    $matches = @($Lines | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R24D7PhysicalClosure ($matches.Count -eq 1) "${Code}_marker_count"
    return ([string]$matches[0]).Substring($Prefix.Length)
}

function Test-R24D7ClosureSemanticVector {
    param([Parameter(Mandatory)]$Candidate)
    try {
        $attempt = $Candidate.attempt
        $worker = $Candidate.worker_execution
        $diagnosis = $Candidate.diagnosis
        $retention = $Candidate.retention
        $statistics = $Candidate.statistical_claim_boundary
        $immutability = $Candidate.immutability
        $claims = $Candidate.claims
        return (
            [string]$Candidate.schema_version -ceq
                "sporespore_qsdk_r24d7_one_hinge_telemetry_physical_failure_closure_v1" -and
            [string]$Candidate.closure_id -ceq "QSDK-R24D7-PH1-CLOSURE" -and
            [string]$Candidate.gate_id -ceq "QSDK-R24D7" -and
            [string]$Candidate.question_class -ceq "development" -and
            [string]$Candidate.status -ceq
                "zero_world_passed_physical_attempt_implementation_invalid_callback_outside_stepping_window" -and
            [string]$Candidate.result_class -ceq
                "invalid_development_result_no_characterization" -and
            [int]$attempt.world_attempt_count -eq 1 -and
            [int]$attempt.world_build_count -eq 1 -and
            [int]$attempt.physics_step_count -eq 20 -and
            [int]$attempt.retained_sample_count -eq 68 -and
            [int]$attempt.evaluator_exit_code -eq 2 -and
            -not [bool]$attempt.same_source_rerun_allowed -and
            [int]$worker.integrate_forces_callback_attempt_count -eq 65 -and
            [int]$worker.integrate_forces_callback_refusal_count -eq 0 -and
            -not [bool]$worker.unsafe_read_control_requirement_satisfied -and
            -not [bool]$worker.raw_numerical_outcomes_accepted_as_characterization -and
            [string]$diagnosis.classification -ceq
                "implementation_invalid_timing_control_callback_dispatched_after_space_step" -and
            [bool]$diagnosis.observed_non_refusal_is_consistent_with_guard_and_actual_callback_timing -and
            -not [bool]$diagnosis.observed_non_refusal_proves_read_during_active_step_safe -and
            -not [bool]$diagnosis.native_guard_invalidated -and
            -not [bool]$diagnosis.zero_world_gate_proved_callback_entered_active_stepping_window -and
            [bool]$diagnosis.r24d7_preregistration_evaluator_probe_worker_or_result_repair_forbidden -and
            [bool]$diagnosis.scientifically_distinct_prospectively_frozen_successor_required -and
            [int]$retention.zero_world_retained_file_count -eq 21 -and
            [int]$retention.physical_retained_file_count -eq 27 -and
            [bool]$retention.all_retained_files_content_addressed_before_closure_authority -and
            [string]$statistics.physical_question_class -ceq "development" -and
            @($statistics.empirical_acceptance_thresholds).Count -eq 0 -and
            @($statistics.superiority_margins).Count -eq 0 -and
            @($statistics.equivalence_or_non_inferiority_margins).Count -eq 0 -and
            @($statistics.held_out_validation_cohorts).Count -eq 0 -and
            @($statistics.population_claims).Count -eq 0 -and
            [bool]$immutability.same_source_physical_rerun_forbidden -and
            [bool]$immutability.r24d7_result_reinterpretation_forbidden -and
            [bool]$immutability.raw_numerical_outcome_promotion_forbidden -and
            [bool]$claims.complete_zero_world_gate_passed -and
            [bool]$claims.zero_world_gate_adequate_for_integral_variant_serialization -and
            -not [bool]$claims.zero_world_gate_adequate_for_active_stepping_callback_timing -and
            [bool]$claims.physical_world_executed -and
            [bool]$claims.physical_worker_raw_report_completed -and
            -not [bool]$claims.valid_descriptive_development_characterization -and
            -not [bool]$claims.native_read_during_active_step_safety_established -and
            -not [bool]$claims.numerical_accuracy_or_telemetry_semantics_accepted -and
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

function Test-R24D7RetainedInventory {
    param(
        [Parameter(Mandatory)][string]$RunRoot,
        [Parameter(Mandatory)][object[]]$Entries,
        [Parameter(Mandatory)][int]$ExpectedFileCount,
        [Parameter(Mandatory)][int]$ExpectedUniqueDigestCount,
        [Parameter(Mandatory)][string]$EvidenceRoot,
        [Parameter(Mandatory)][string]$Code
    )
    $root = [IO.Path]::GetFullPath($RunRoot).TrimEnd("\", "/")
    Assert-R24D7PhysicalClosure (
        Test-Path -LiteralPath $root -PathType Container
    ) "${Code}_run_root_missing"
    $liveFiles = @(Get-ChildItem -LiteralPath $root -File -Recurse)
    Assert-R24D7PhysicalClosure (
        $Entries.Count -eq $ExpectedFileCount -and
        $liveFiles.Count -eq $ExpectedFileCount
    ) "${Code}_file_count"
    $byPath = @{}
    $uniqueDigests = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($entry in $Entries) {
        $relative = [string]$entry.path
        Assert-R24D7PhysicalClosure (
            -not $byPath.ContainsKey($relative)
        ) "${Code}_duplicate_path_$relative"
        $byPath[$relative] = $entry
        [void]$uniqueDigests.Add([string]$entry.raw_sha256)
        $path = [IO.Path]::GetFullPath((Join-Path $root $relative))
        Assert-R24D7PhysicalClosure (
            $path.StartsWith(
                $root + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            ) -and
            (Test-Path -LiteralPath $path -PathType Leaf) -and
            (Get-R24D7RawSha256 $path) -ceq [string]$entry.raw_sha256 -and
            (Get-Item -LiteralPath $path).Length -eq [long]$entry.byte_length
        ) "${Code}_live_copy_$relative"
        [void](Get-R24D7CasPayloadPath `
            -EvidenceRoot $EvidenceRoot `
            -RawSha256 ([string]$entry.raw_sha256) `
            -ByteLength ([long]$entry.byte_length) `
            -Code "${Code}_$relative")
    }
    foreach ($file in $liveFiles) {
        $relative = $file.FullName.Substring($root.Length + 1).Replace("\", "/")
        Assert-R24D7PhysicalClosure (
            $byPath.ContainsKey($relative)
        ) "${Code}_unlisted_live_file_$relative"
    }
    Assert-R24D7PhysicalClosure (
        $byPath.Count -eq $ExpectedFileCount -and
        $uniqueDigests.Count -eq $ExpectedUniqueDigestCount
    ) "${Code}_inventory_counts"
    return [ordered]@{
        root = $root
        by_path = $byPath
        unique_digest_count = $uniqueDigests.Count
    }
}

function Get-R24D7RetainedText {
    param(
        [Parameter(Mandatory)]$Inventory,
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$EvidenceRoot,
        [Parameter(Mandatory)][string]$Code
    )
    Assert-R24D7PhysicalClosure (
        $Inventory.by_path.ContainsKey($RelativePath)
    ) "${Code}_unknown_$RelativePath"
    $entry = $Inventory.by_path[$RelativePath]
    $payload = Get-R24D7CasPayloadPath `
        -EvidenceRoot $EvidenceRoot `
        -RawSha256 ([string]$entry.raw_sha256) `
        -ByteLength ([long]$entry.byte_length) `
        -Code "${Code}_$RelativePath"
    return Get-Content -Raw -LiteralPath $payload
}

Assert-R24D7PhysicalClosure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/")
) "repository_root"
Assert-R24D7PhysicalClosure (
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository_remote"
Assert-R24D7PhysicalClosure (
    Test-Path -LiteralPath $closurePath -PathType Leaf
) "closure_missing"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D7PhysicalClosure (
    Test-R24D7ClosureSemanticVector $closure
) "closure_semantic_vector"

$source = $closure.source
$sourceCommit = [string]$source.commit
Assert-R24D7PhysicalClosure (
    [string]$source.repository_root -ceq $repoRoot.Replace("\", "/") -and
    [string]$source.remote -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    [string]$source.branch -ceq "main" -and
    $sourceCommit -ceq "ab6e763e466db86ea1d6fea6b72a23a68ff63587" -and
    [bool]$source.clean_pushed_before_zero_world_and_physical_attempt -and
    [bool]$source.local_upstream_cached_live_equal_before_attempt -and
    [int]$source.worktree_count -eq 1
) "source_identity"
git -C $repoRoot cat-file -e "$sourceCommit^{commit}"
Assert-R24D7PhysicalClosure ($LASTEXITCODE -eq 0) "source_commit_missing"

$validationManifest = $source.validation_manifest
$sourceBindings = @($closure.source_bindings)
Assert-R24D7PhysicalClosure ($sourceBindings.Count -eq 11) "source_binding_count"
$allBindings = @($validationManifest) + $sourceBindings
foreach ($binding in $allBindings) {
    $relative = [string]$binding.path
    $bytes = Get-R24D7GitBlobBytes `
        -RepositoryRoot $repoRoot `
        -Commit $sourceCommit `
        -RelativePath $relative
    $blobOid = (git -C $repoRoot rev-parse "$sourceCommit`:$relative").Trim()
    Assert-R24D7PhysicalClosure (
        $blobOid -ceq [string]$binding.git_blob_oid -and
        (Get-R24D7BytesSha256 $bytes) -ceq [string]$binding.raw_sha256 -and
        $bytes.Length -eq [long]$binding.byte_length
    ) "source_binding_$relative"
}

$manifestBytes = Get-R24D7GitBlobBytes `
    -RepositoryRoot $repoRoot `
    -Commit $sourceCommit `
    -RelativePath ([string]$validationManifest.path)
$manifest = [Text.Encoding]::UTF8.GetString($manifestBytes) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D7PhysicalClosure (
    [string]$manifest.schema_version -ceq
        "sporespore_qsdk_r24d7_one_hinge_telemetry_validation_manifest_v1" -and
    [string]$manifest.gate_id -ceq "QSDK-R24D7" -and
    [string]$manifest.question_class -ceq "development" -and
    [int]$manifest.source_binding_count -eq 11 -and
    @($manifest.bindings).Count -eq 11 -and
    [int]$manifest.world_attempt_count -eq 0 -and
    [int]$manifest.world_build_count -eq 0 -and
    [int]$manifest.solver_step_count -eq 0 -and
    -not [bool]$manifest.complete_zero_world_gate_passed -and
    -not [bool]$manifest.physical_characterization_executed
) "frozen_prospective_manifest"
for ($index = 0; $index -lt $sourceBindings.Count; $index++) {
    $declared = $sourceBindings[$index]
    $frozen = @($manifest.bindings)[$index]
    Assert-R24D7PhysicalClosure (
        [string]$declared.path -ceq [string]$frozen.path -and
        [string]$declared.raw_sha256 -ceq [string]$frozen.raw_sha256 -and
        [long]$declared.byte_length -eq [long]$frozen.byte_length -and
        [string]$declared.git_blob_oid -ceq [string]$frozen.git_blob_oid
    ) "manifest_binding_$index"
}

$runtime = $closure.runtime
foreach ($binary in @(
    @{ path = [string]$runtime.console_binary_path; sha = [string]$runtime.console_binary_raw_sha256; bytes = [long]$runtime.console_binary_byte_length; code = "console" },
    @{ path = [string]$runtime.engine_binary_path; sha = [string]$runtime.engine_binary_raw_sha256; bytes = [long]$runtime.engine_binary_byte_length; code = "engine" }
)) {
    $binaryPath = [IO.Path]::GetFullPath($binary.path)
    Assert-R24D7PhysicalClosure (
        (Test-Path -LiteralPath $binaryPath -PathType Leaf) -and
        (Get-R24D7RawSha256 $binaryPath) -ceq $binary.sha -and
        (Get-Item -LiteralPath $binaryPath).Length -eq $binary.bytes
    ) "runtime_binary_$($binary.code)"
}
Assert-R24D7PhysicalClosure (
    [string]$runtime.profile_id -ceq
        "godot_4_7_jolt_sporespore_motor_telemetry_v1" -and
    [string]$runtime.physics_engine -ceq "Jolt Physics" -and
    [int]$runtime.physics_ticks_per_second -eq 120 -and
    [int]$runtime.solver_velocity_steps -eq 20 -and
    [int]$runtime.solver_position_steps -eq 7 -and
    [string]$runtime.thread_model -ceq "single_safe" -and
    [bool]$runtime.telemetry_class_registered -and
    [bool]$runtime.telemetry_method_registered
) "runtime_profile"

$evidenceRoot = [IO.Path]::GetFullPath(
    (Join-Path $repoRoot "../SporeSpore_Evidence")
).TrimEnd("\", "/")
$retention = $closure.retention
$zero = $closure.prerequisite_zero_world
$zeroInventory = Test-R24D7RetainedInventory `
    -RunRoot ([string]$zero.run_root) `
    -Entries @($closure.zero_world_retained_files) `
    -ExpectedFileCount ([int]$retention.zero_world_retained_file_count) `
    -ExpectedUniqueDigestCount ([int]$retention.zero_world_unique_content_digest_count) `
    -EvidenceRoot $evidenceRoot `
    -Code "zero_world"
Assert-R24D7PhysicalClosure (
    [string]$zero.receipt_path -ceq
        ((Join-Path $zeroInventory.root "receipt.json").Replace("\", "/")) -and
    [string]$zero.receipt_raw_sha256 -ceq
        [string]$zeroInventory.by_path["receipt.json"].raw_sha256 -and
    [long]$zero.receipt_byte_length -eq
        [long]$zeroInventory.by_path["receipt.json"].byte_length
) "zero_world_receipt_inventory_binding"
$zeroReceipt = Get-R24D7RetainedText `
    -Inventory $zeroInventory `
    -RelativePath "receipt.json" `
    -EvidenceRoot $evidenceRoot `
    -Code "zero_receipt" |
    ConvertFrom-Json -AsHashtable -Depth 100
$zeroIntegral = $zeroReceipt.worker.receipt.integral_variant_schema
$zeroDefault = $zeroReceipt.serialized_envelope_oracle.default_precision_negative_control
$zeroFull = $zeroReceipt.serialized_envelope_oracle.full_precision_positive_control
Assert-R24D7PhysicalClosure (
    [string]$zero.status -ceq
        "complete_zero_world_serialized_envelope_gate_passed" -and
    [string]$zeroReceipt.schema_version -ceq
        "sporespore_qsdk_r24d7_one_hinge_telemetry_zero_world_qualification_receipt_v1" -and
    [bool]$zeroReceipt.ok -and
    [string]$zeroReceipt.gate_id -ceq "QSDK-R24D7" -and
    [string]$zeroReceipt.question_class -ceq
        "non_physical_source_conformance" -and
    [string]$zeroReceipt.source.head -ceq $sourceCommit -and
    [string]$zeroReceipt.source.upstream -ceq $sourceCommit -and
    [string]$zeroReceipt.source.cached_origin_main -ceq $sourceCommit -and
    [string]$zeroReceipt.source.live_origin_main -ceq $sourceCommit -and
    [bool]$zeroReceipt.source.clean -and
    [int]$zeroReceipt.source.worktree_count -eq 1 -and
    [string]$zeroReceipt.source.validation_manifest.raw_sha256 -ceq
        [string]$validationManifest.raw_sha256 -and
    [int]$zeroReceipt.static_audit_stage_count -eq 5 -and
    [int]$zeroReceipt.source.source_binding_count -eq 11 -and
    [int]$zeroReceipt.evaluator_baseline_negative_control_count -eq 29 -and
    [int]$zeroReceipt.integral_family_type_loss_negative_control_count -eq 21 -and
    [int]$zeroReceipt.evaluator_total_negative_control_count -eq 50 -and
    [int]$zeroReceipt.accepted_outcome_mutation_count -eq 2 -and
    [int]$zeroReceipt.contract_mutation_rejection_count -eq 22 -and
    [bool]$zeroIntegral.ok -and
    [int]$zeroIntegral.declared_path_family_count -eq 21 -and
    [int]$zeroIntegral.declared_occurrence_count -eq 313 -and
    [int]$zeroIntegral.predecessor_strict_occurrence_count -eq 234 -and
    [int]$zeroIntegral.pre_normalization_float_occurrence_count -eq 313 -and
    [int]$zeroIntegral.post_normalization_integer_occurrence_count -eq 313 -and
    [int]$zeroIntegral.missing_occurrence_count -eq 0 -and
    [int]$zeroIntegral.numeric_value_change_count -eq 0 -and
    [int]$zeroDefault.evaluator_exit_code -eq 2 -and
    [string]$zeroDefault.evaluator_terminal_error -ceq
        "QSDK_R24D7_EVALUATION_ERROR fixture_inertia_representation" -and
    -not [bool]$zeroDefault.evaluation_record_written -and
    [bool]$zeroFull.evaluation_receipt.execution_valid -and
    [int]$zeroReceipt.worker.receipt.active_physics_object_count -eq 0 -and
    [int]$zeroReceipt.world_attempt_count -eq 0 -and
    [int]$zeroReceipt.world_build_count -eq 0 -and
    [int]$zeroReceipt.solver_step_count -eq 0 -and
    -not [bool]$zeroReceipt.physical_characterization_executed -and
    -not [bool]$zeroReceipt.instrumented_profile_promoted -and
    -not [bool]$zeroReceipt.recovery_world_opened -and
    -not [bool]$zeroReceipt.prone_to_standing_world_opened -and
    -not [bool]$zeroReceipt.physical_acceptance_authority -and
    -not [bool]$zeroReceipt.release_authority
) "zero_world_receipt"

$attempt = $closure.attempt
$physicalInventory = Test-R24D7RetainedInventory `
    -RunRoot ([string]$attempt.run_root) `
    -Entries @($closure.physical_retained_files) `
    -ExpectedFileCount ([int]$retention.physical_retained_file_count) `
    -ExpectedUniqueDigestCount ([int]$retention.physical_unique_content_digest_count) `
    -EvidenceRoot $evidenceRoot `
    -Code "physical"
$expectedStages = @(
    @("01-r24d6_zero_world_failure_closure.log", "QSDK_R24D6_ZERO_WORLD_FAILURE_CLOSURE_PASS "),
    @("02-r24d7_freeze_audit.log", "QSDK_R24D7_ONE_HINGE_TELEMETRY_FREEZE_PASS "),
    @("03-r24d3_source_audit.log", "QSDK_R24D3_GODOT_JOLT_MOTOR_TELEMETRY_SOURCE_PASS "),
    @("04-r24d3_cold_adoption_audit.log", "QSDK_R24D3_COLD_QUALIFICATION_ADOPTION_PASS "),
    @("05-r24d3_post_adoption_full_cold_audit.log", "QSDK_R24D3_POST_ADOPTION_FULL_COLD_CONFORMANCE_QUALIFICATION_PASS ")
)
foreach ($stage in $expectedStages) {
    $stageLines = @((Get-R24D7RetainedText `
        -Inventory $physicalInventory `
        -RelativePath $stage[0] `
        -EvidenceRoot $evidenceRoot `
        -Code "physical_stage") -split "`r?`n")
    [void](Get-R24D7Marker `
        -Lines $stageLines `
        -Prefix $stage[1] `
        -Code $stage[0])
}

$attemptRecord = Get-R24D7RetainedText `
    -Inventory $physicalInventory `
    -RelativePath "attempt.json" `
    -EvidenceRoot $evidenceRoot `
    -Code "attempt" |
    ConvertFrom-Json -AsHashtable -Depth 100
$failureRecord = Get-R24D7RetainedText `
    -Inventory $physicalInventory `
    -RelativePath "failure.json" `
    -EvidenceRoot $evidenceRoot `
    -Code "failure" |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D7PhysicalClosure (
    [string]$attemptRecord.schema_version -ceq
        "sporespore_qsdk_r24d7_physical_attempt_v1" -and
    [string]$attemptRecord.gate_id -ceq "QSDK-R24D7" -and
    [string]$attemptRecord.question_class -ceq "development" -and
    [string]$attemptRecord.status -ceq "consumed_before_worker_launch" -and
    [string]$attemptRecord.source_commit -ceq $sourceCommit -and
    [string]$attemptRecord.execution_nonce -ceq [string]$attempt.execution_nonce -and
    [string]$attemptRecord.console_binary_sha256 -ceq
        [string]$runtime.console_binary_raw_sha256 -and
    [string]$attemptRecord.engine_binary_sha256 -ceq
        [string]$runtime.engine_binary_raw_sha256 -and
    [string]$attemptRecord.zero_world_receipt_sha256 -ceq
        [string]$zero.receipt_raw_sha256 -and
    [int]$attemptRecord.declared_world_attempt_count -eq 1 -and
    [int]$attemptRecord.declared_world_build_count -eq 1 -and
    -not [bool]$attemptRecord.same_source_rerun_allowed -and
    -not [bool]$attemptRecord.physical_acceptance_authority -and
    -not [bool]$attemptRecord.release_authority -and
    [string]$failureRecord.schema_version -ceq
        "sporespore_qsdk_r24d7_physical_failure_v1" -and
    [string]$failureRecord.status -ceq
        "retained_incomplete_or_invalid_attempt_no_same_source_rerun" -and
    [string]$failureRecord.message -ceq [string]$attempt.supervisor_terminal_error -and
    [int]$failureRecord.world_attempt_count_lower_bound -eq 0 -and
    [int]$failureRecord.world_attempt_count_upper_bound -eq 1 -and
    [int]$failureRecord.world_build_count_lower_bound -eq 0 -and
    [int]$failureRecord.world_build_count_upper_bound -eq 1 -and
    -not [bool]$failureRecord.same_source_rerun_allowed -and
    -not [bool]$failureRecord.physical_acceptance_authority -and
    -not [bool]$failureRecord.release_authority
) "attempt_failure_records"

$rawText = Get-R24D7RetainedText `
    -Inventory $physicalInventory `
    -RelativePath "raw_report.json" `
    -EvidenceRoot $evidenceRoot `
    -Code "raw_report"
$raw = $rawText | ConvertFrom-Json -AsHashtable -Depth 100
$worker = $closure.worker_execution
$cells = @($raw.cells)
$cellIds = @($cells | ForEach-Object { [string]$_.cell_id })
$sampleCounts = @($cells | ForEach-Object { @($_.samples).Count })
$callbackAttempts = 0
$callbackRefusals = 0
$nonNullTelemetry = 0
foreach ($cell in $cells) {
    foreach ($sample in @($cell.samples)) {
        $callbackAttempts += [int]$sample.stepping_read_attempt_count
        $callbackRefusals += [int]$sample.stepping_read_refusal_count
        if ($null -ne $sample.telemetry) { $nonNullTelemetry += 1 }
    }
}
$firstSample = @($cells[0].samples)[0]
Assert-R24D7PhysicalClosure (
    [string]$raw.schema_version -ceq [string]$worker.raw_report_schema_version -and
    [string]$raw.gate_id -ceq "QSDK-R24D7" -and
    [string]$raw.question_class -ceq "development" -and
    [string]$raw.source_commit -ceq $sourceCommit -and
    [string]$raw.execution_nonce -ceq [string]$attempt.execution_nonce -and
    [string]$raw.fixture.fixture_id -ceq [string]$worker.fixture_id -and
    [int]$raw.fixture.cell_count -eq 9 -and
    [int]$raw.fixture.collision_layer -eq 0 -and
    [int]$raw.fixture.collision_mask -eq 0 -and
    [int]$raw.fixture.contact_count -eq 0 -and
    ($cellIds -join "|") -ceq (@($worker.cell_ids_in_order) -join "|") -and
    ($sampleCounts -join "|") -ceq
        (@($worker.retained_sample_counts_in_order) -join "|") -and
    [int]$raw.execution.world_attempt_count -eq 1 -and
    [int]$raw.execution.world_build_count -eq 1 -and
    [int]$raw.execution.physics_step_count -eq 20 -and
    [int]$raw.execution.retained_sample_count -eq 68 -and
    [int]$raw.execution.direct_force_write_count -eq 0 -and
    [int]$raw.execution.direct_torque_write_count -eq 0 -and
    [int]$raw.execution.direct_impulse_write_count -eq 0 -and
    [int]$raw.execution.post_activation_transform_write_count -eq 0 -and
    [int]$raw.execution.pre_activation_initial_angular_velocity_write_count -eq 4 -and
    [int]$raw.execution.declared_sleep_input_write_count -eq 1 -and
    [int]$raw.execution.outcome_dependent_early_stop_count -eq 0 -and
    [bool]$raw.refusals.invalid_rid_refused -and
    @($raw.refusals.not_in_tree_joint_read_refused_by_cell.Values |
        Where-Object { [bool]$_ }).Count -eq 9 -and
    $callbackAttempts -eq 65 -and
    $callbackRefusals -eq 0 -and
    $nonNullTelemetry -eq 68 -and
    [int]$firstSample.step_index -eq 1 -and
    [int]$firstSample.stepping_read_attempt_count -eq 1 -and
    [int]$firstSample.stepping_read_refusal_count -eq 0 -and
    $null -ne $firstSample.telemetry -and
    [bool]$raw.claims.descriptive_development_characterization_only -and
    -not [bool]$raw.claims.turning_claim_changed -and
    -not [bool]$raw.claims.recovery_claimed -and
    -not [bool]$raw.claims.prone_to_standing_claimed -and
    -not [bool]$raw.claims.cross_engine_equivalence_claimed -and
    -not [bool]$raw.claims.physical_acceptance_authority -and
    -not [bool]$raw.claims.release_authority
) "raw_worker_execution"

$physicalLines = @((Get-R24D7RetainedText `
    -Inventory $physicalInventory `
    -RelativePath "godot-physical-stdout.log" `
    -EvidenceRoot $evidenceRoot `
    -Code "physical_stdout") -split "`r?`n")
$rawMarker = Get-R24D7Marker `
    -Lines $physicalLines `
    -Prefix "QSDK_R24D7_PHYSICAL_RAW_REPORT " `
    -Code "physical_raw_marker" |
    ConvertFrom-Json -AsHashtable -Depth 100
$termination = Get-R24D7Marker `
    -Lines $physicalLines `
    -Prefix "QSDK_R24D7_GODOT_SUPERVISOR_TERMINATION_READY " `
    -Code "physical_termination_marker" |
    ConvertFrom-Json -AsHashtable -Depth 100
$evaluationLines = @((Get-R24D7RetainedText `
    -Inventory $physicalInventory `
    -RelativePath "05-evaluation.log" `
    -EvidenceRoot $evidenceRoot `
    -Code "evaluation_log") -split "`r?`n")
[void](Get-R24D7Marker `
    -Lines $evaluationLines `
    -Prefix ([string]$attempt.evaluator_terminal_error) `
    -Code "evaluation_error")
Assert-R24D7PhysicalClosure (
    [string]$rawMarker.execution_nonce -ceq [string]$raw.execution_nonce -and
    [string]$rawMarker.source_commit -ceq $sourceCommit -and
    [int]$rawMarker.execution.world_attempt_count -eq 1 -and
    [int]$rawMarker.execution.world_build_count -eq 1 -and
    [string]$termination.schema_version -ceq
        "sporespore_godot_supervised_termination_ready_v1" -and
    [string]$termination.termination_nonce -ceq [string]$attempt.execution_nonce -and
    [string]$termination.worker_receipt_kind -ceq "physical_raw_report" -and
    [bool]$termination.worker_receipt_emitted -and
    [int]$termination.requested_exit_code -eq 0 -and
    [int]$termination.drained_process_frame_count -eq 2 -and
    -not [bool]$termination.physics_evidence_authority -and
    -not $physicalInventory.by_path.ContainsKey("evaluation.json") -and
    -not $physicalInventory.by_path.ContainsKey("receipt.json")
) "physical_worker_and_evaluator_boundary"

$diagnosis = $closure.diagnosis
$patchBinding = $diagnosis.instrumentation_patch
$patchBytes = Get-R24D7GitBlobBytes `
    -RepositoryRoot $repoRoot `
    -Commit $sourceCommit `
    -RelativePath ([string]$patchBinding.path)
$patchText = [Text.Encoding]::UTF8.GetString($patchBytes)
Assert-R24D7PhysicalClosure (
    (Get-R24D7BytesSha256 $patchBytes) -ceq [string]$patchBinding.raw_sha256 -and
    $patchBytes.Length -eq [long]$patchBinding.byte_length -and
    (git -C $repoRoot rev-parse (
        "$sourceCommit`:$([string]$patchBinding.path)"
    )).Trim() -ceq [string]$patchBinding.git_blob_oid -and
    $patchText.Contains(
        "if (space == nullptr || space->is_stepping()) {",
        [StringComparison]::Ordinal
    ) -and
    $patchText.Contains("return Variant();", [StringComparison]::Ordinal)
) "instrumentation_guard"

$probeBinding = $sourceBindings[4]
$probeBytes = Get-R24D7GitBlobBytes `
    -RepositoryRoot $repoRoot `
    -Commit $sourceCommit `
    -RelativePath ([string]$probeBinding.path)
$probeText = [Text.Encoding]::UTF8.GetString($probeBytes)
Assert-R24D7PhysicalClosure (
    $probeText.Contains(
        [string]$diagnosis.frozen_probe_claim,
        [StringComparison]::Ordinal
    ) -and
    $probeText.Contains(
        [string]$diagnosis.frozen_probe_method,
        [StringComparison]::Ordinal
    ) -and
    $probeText.Contains(
        "JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(",
        [StringComparison]::Ordinal
    )
) "frozen_probe_timing_claim"

$preregBytes = Get-R24D7GitBlobBytes `
    -RepositoryRoot $repoRoot `
    -Commit $sourceCommit `
    -RelativePath ([string]$sourceBindings[0].path)
$preregText = [Text.Encoding]::UTF8.GetString($preregBytes)
Assert-R24D7PhysicalClosure (
    $preregText.Contains(
        ('"{0}": true' -f [string]$diagnosis.frozen_control_requirement),
        [StringComparison]::Ordinal
    )
) "frozen_control_requirement"

$godotRoot = [IO.Path]::GetFullPath($GodotSourceRoot)
Assert-R24D7PhysicalClosure (
    (git -C $godotRoot rev-parse --show-toplevel).Trim() -ceq
        $godotRoot.Replace("\", "/") -and
    (git -C $godotRoot remote get-url origin).Trim() -ceq
        [string]$runtime.godot_source_repository -and
    (git -C $godotRoot rev-parse HEAD).Trim() -ceq
        [string]$runtime.godot_source_commit
) "godot_source_identity"
foreach ($binding in @($diagnosis.pinned_upstream_source_bindings)) {
    $bytes = Get-R24D7GitBlobBytes `
        -RepositoryRoot $godotRoot `
        -Commit ([string]$runtime.godot_source_commit) `
        -RelativePath ([string]$binding.path)
    $blob = (git -C $godotRoot rev-parse (
        "{0}:{1}" -f [string]$runtime.godot_source_commit, [string]$binding.path
    )).Trim()
    Assert-R24D7PhysicalClosure (
        $blob -ceq [string]$binding.git_blob_oid -and
        (Get-R24D7BytesSha256 $bytes) -ceq [string]$binding.raw_sha256 -and
        $bytes.Length -eq [long]$binding.byte_length
    ) "godot_upstream_binding_$([string]$binding.path)"
}

$mainText = [Text.Encoding]::UTF8.GetString((Get-R24D7GitBlobBytes `
    -RepositoryRoot $godotRoot `
    -Commit ([string]$runtime.godot_source_commit) `
    -RelativePath "main/main.cpp"))
$spaceText = [Text.Encoding]::UTF8.GetString((Get-R24D7GitBlobBytes `
    -RepositoryRoot $godotRoot `
    -Commit ([string]$runtime.godot_source_commit) `
    -RelativePath "modules/jolt_physics/spaces/jolt_space_3d.cpp"))
$bodyText = [Text.Encoding]::UTF8.GetString((Get-R24D7GitBlobBytes `
    -RepositoryRoot $godotRoot `
    -Commit ([string]$runtime.godot_source_commit) `
    -RelativePath "modules/jolt_physics/objects/jolt_body_3d.cpp"))
$mainFlush = $mainText.IndexOf(
    "PhysicsServer3D::get_singleton()->flush_queries();",
    [StringComparison]::Ordinal
)
$mainStep = $mainText.IndexOf(
    "PhysicsServer3D::get_singleton()->step(physics_step * time_scale);",
    [StringComparison]::Ordinal
)
$spaceTrue = $spaceText.IndexOf("stepping = true;", [StringComparison]::Ordinal)
$spaceFalse = $spaceText.IndexOf("stepping = false;", [StringComparison]::Ordinal)
$spaceCalls = $spaceText.IndexOf("body->call_queries();", [StringComparison]::Ordinal)
$bodyCall = $bodyText.IndexOf(
    "void JoltBody3D::call_queries() {",
    [StringComparison]::Ordinal
)
$bodyCallback = $bodyText.IndexOf(
    "custom_integration_callback.callp(args, argc, ret, ce);",
    [StringComparison]::Ordinal
)
$bodyPreStep = $bodyText.IndexOf(
    "void JoltBody3D::pre_step(float p_step) {",
    [StringComparison]::Ordinal
)
$bodyEnqueue = $bodyText.IndexOf("_enqueue_call_queries();", $bodyPreStep)
Assert-R24D7PhysicalClosure (
    $mainFlush -ge 0 -and $mainStep -gt $mainFlush -and
    $spaceTrue -ge 0 -and $spaceFalse -gt $spaceTrue -and
    $spaceCalls -gt $spaceFalse -and
    $bodyCall -ge 0 -and $bodyCallback -gt $bodyCall -and
    $bodyPreStep -gt $bodyCallback -and $bodyEnqueue -gt $bodyPreStep -and
    @($diagnosis.callback_order_proof).Count -eq 6 -and
    [string]$diagnosis.actual_callback_timing -ceq
        "Godot dispatches the custom integration callback from JoltSpace3D::call_queries during PhysicsServer3D::flush_queries after the preceding JoltSpace3D::step returned and cleared stepping, before the next PhysicsServer3D::step begins."
) "callback_order_diagnosis"

$patchedServer = $diagnosis.patched_server_live_source
$patchedServerPath = Join-Path $godotRoot ([string]$patchedServer.path)
Assert-R24D7PhysicalClosure (
    (Get-R24D7RawSha256 $patchedServerPath) -ceq
        [string]$patchedServer.raw_sha256 -and
    (Get-Item -LiteralPath $patchedServerPath).Length -eq
        [long]$patchedServer.byte_length -and
    (git -C $godotRoot hash-object -- $patchedServerPath).Trim() -ceq
        [string]$patchedServer.git_blob_oid
) "patched_server_live_source"
& git -C $godotRoot apply --reverse --check --whitespace=nowarn -- (
    Join-Path $repoRoot ([string]$patchBinding.path)
)
Assert-R24D7PhysicalClosure ($LASTEXITCODE -eq 0) "patch_reverse_apply"

$runnerText = [Text.Encoding]::UTF8.GetString((Get-R24D7GitBlobBytes `
    -RepositoryRoot $repoRoot `
    -Commit $sourceCommit `
    -RelativePath ([string]$sourceBindings[6].path)))
Assert-R24D7PhysicalClosure (
    $runnerText.Contains(
        "same_source_physical_attempt_already_exists",
        [StringComparison]::Ordinal
    ) -and
    $runnerText.Contains(
        "Get-R24D7MatchingPhysicalAttempts",
        [StringComparison]::Ordinal
    )
) "same_source_rerun_guard"
$expectedPhysicalBase = [IO.Path]::GetFullPath(
    (Join-Path $evidenceRoot "qsdk-r24d7-one-hinge-physical")
)
$matchingAttempts = [Collections.Generic.List[string]]::new()
foreach ($attemptFile in @(
    Get-ChildItem `
        -LiteralPath $expectedPhysicalBase `
        -Filter "attempt.json" `
        -File `
        -Recurse
)) {
    $candidateAttempt = Get-Content -Raw -LiteralPath $attemptFile.FullName |
        ConvertFrom-Json -AsHashtable -Depth 100
    if (
        [string]$candidateAttempt.source_commit -ceq $sourceCommit -and
        [string]$candidateAttempt.console_binary_sha256 -ceq
            [string]$runtime.console_binary_raw_sha256 -and
        [string]$candidateAttempt.engine_binary_sha256 -ceq
            [string]$runtime.engine_binary_raw_sha256
    ) {
        $matchingAttempts.Add($attemptFile.FullName)
    }
}
Assert-R24D7PhysicalClosure (
    $matchingAttempts.Count -eq 1 -and
    [IO.Path]::GetFullPath($matchingAttempts[0]) -ceq
        [IO.Path]::GetFullPath((Join-Path $physicalInventory.root "attempt.json"))
) "same_source_attempt_count"

$mutations = @(
    { param($value) $value.status = "complete_valid_characterization" },
    { param($value) $value.result_class = "positive" },
    { param($value) $value.attempt.world_attempt_count = 0 },
    { param($value) $value.attempt.evaluator_exit_code = 0 },
    { param($value) $value.attempt.same_source_rerun_allowed = $true },
    { param($value) $value.worker_execution.integrate_forces_callback_refusal_count = 1 },
    { param($value) $value.worker_execution.unsafe_read_control_requirement_satisfied = $true },
    { param($value) $value.diagnosis.native_guard_invalidated = $true },
    { param($value) $value.diagnosis.observed_non_refusal_proves_read_during_active_step_safe = $true },
    { param($value) $value.immutability.raw_numerical_outcome_promotion_forbidden = $false },
    { param($value) $value.claims.valid_descriptive_development_characterization = $true },
    { param($value) $value.claims.native_read_during_active_step_safety_established = $true },
    { param($value) $value.claims.turning_claim_changed = $true },
    { param($value) $value.claims.prone_to_standing_world_opened = $true },
    { param($value) $value.claims.release_authority = $true },
    { param($value) $value.statistical_claim_boundary.empirical_acceptance_thresholds = @("retrofitted") }
)
$mutationRejectionCount = 0
foreach ($mutation in $mutations) {
    $candidate = $closure | ConvertTo-Json -Depth 100 |
        ConvertFrom-Json -AsHashtable -Depth 100
    & $mutation $candidate
    if (-not (Test-R24D7ClosureSemanticVector $candidate)) {
        $mutationRejectionCount += 1
    }
}
Assert-R24D7PhysicalClosure (
    $mutationRejectionCount -eq 16
) "closure_mutation_controls"

Write-Output (
    "QSDK_R24D7_PHYSICAL_FAILURE_CLOSURE_PASS " +
    ([ordered]@{
        ok = $true
        closure_id = "QSDK-R24D7-PH1-CLOSURE"
        status = (
            "zero_world_passed_physical_attempt_implementation_invalid_" +
            "callback_outside_stepping_window"
        )
        question_class = "development"
        source_commit = $sourceCommit
        complete_zero_world_gate_passed = $true
        zero_world_retained_file_count = 21
        zero_world_unique_digest_count = 20
        physical_world_attempt_count = 1
        physical_world_build_count = 1
        physics_step_count = 20
        retained_sample_count = 68
        callback_attempt_count = 65
        callback_refusal_count = 0
        physical_retained_file_count = 27
        physical_unique_digest_count = 24
        evaluator_exit_code = 2
        valid_characterization = $false
        native_read_during_active_step_safety_established = $false
        same_source_rerun_forbidden = $true
        distinct_successor_required = $true
        closure_mutation_rejection_count = $mutationRejectionCount
        turning_claim_changed = $false
        prone_to_standing_world_opened = $false
        physical_acceptance_authority = $false
        release_authority = $false
    } | ConvertTo-Json -Compress)
)

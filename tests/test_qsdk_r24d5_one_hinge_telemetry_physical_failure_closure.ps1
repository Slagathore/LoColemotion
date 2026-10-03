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
    "sdk/recovery/r24d5_godot_jolt_one_hinge_telemetry_" +
    "physical_failure_closure_v1.json"
)
$closurePath = Join-Path $repoRoot $closureRelative
. (Join-Path $repoRoot "sdk/content_addressed_artifact_store.ps1")

function Assert-R24D5PhysicalClosure {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Code
    )
    if (-not $Condition) {
        throw "QSDK-R24D5 physical failure closure: $Code"
    }
}

function Get-R24D5RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R24D5BytesSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R24D5GitBlobBytes {
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
    Assert-R24D5PhysicalClosure ($process.Start()) "git_cat_file_start"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R24D5PhysicalClosure ($process.ExitCode -eq 0) (
            "historical_blob_unavailable_${RelativePath}:$stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Get-R24D5CasPayloadPath {
    param(
        [Parameter(Mandatory)][string]$EvidenceRoot,
        [Parameter(Mandatory)][string]$RawSha256,
        [Parameter(Mandatory)][long]$ByteLength,
        [Parameter(Mandatory)][string]$Code
    )
    Assert-R24D5PhysicalClosure (
        $RawSha256 -cmatch '^sha256:[0-9a-f]{64}$'
    ) "${Code}_digest_shape"
    $digest = $RawSha256.Substring(7)
    $directory = Join-Path $EvidenceRoot "artifacts/sha256/$digest"
    Assert-R24D5PhysicalClosure (
        Test-SporeSporeStoredArtifact `
            -Directory $directory `
            -ExpectedSha256 $digest `
            -ExpectedByteLength $ByteLength
    ) "${Code}_cas"
    return Join-Path $directory "payload.bin"
}

function Get-R24D5Marker {
    param(
        [AllowEmptyString()][Parameter(Mandatory)][string[]]$Lines,
        [Parameter(Mandatory)][string]$Prefix,
        [Parameter(Mandatory)][string]$Code
    )
    $matches = @($Lines | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R24D5PhysicalClosure ($matches.Count -eq 1) "${Code}_marker_count"
    return ([string]$matches[0]).Substring($Prefix.Length)
}

function ConvertTo-R24D5RoundTripString {
    param([Parameter(Mandatory)][double]$Value)
    return $Value.ToString(
        "R",
        [Globalization.CultureInfo]::InvariantCulture
    )
}

function Test-R24D5ClosureSemanticVector {
    param([Parameter(Mandatory)]$Candidate)
    try {
        $attempt = $Candidate.attempt
        $diagnosis = $Candidate.diagnosis
        $immutability = $Candidate.immutability
        $claims = $Candidate.claims
        return (
            [string]$Candidate.schema_version -ceq
                "sporespore_qsdk_r24d5_one_hinge_telemetry_physical_failure_closure_v1" -and
            [string]$Candidate.closure_id -ceq "QSDK-R24D5-PH1-CLOSURE" -and
            [string]$Candidate.gate_id -ceq "QSDK-R24D5" -and
            [string]$Candidate.question_class -ceq "development" -and
            [string]$Candidate.status -ceq
                "worker_execution_complete_evaluation_invalid_fixture_json_identity_mismatch" -and
            [string]$Candidate.result_class -ceq
                "invalid_development_result_no_characterization" -and
            [int]$attempt.world_attempt_count -eq 1 -and
            [int]$attempt.world_build_count -eq 1 -and
            [int]$attempt.physics_step_count -eq 20 -and
            [int]$attempt.retained_sample_count -eq 68 -and
            [int]$attempt.evaluator_exit_code -eq 2 -and
            -not [bool]$attempt.same_source_rerun_allowed -and
            [string]$diagnosis.frozen_evaluator_expected_component_json_number_text -ceq
                "0.0500000007450581" -and
            [string]$diagnosis.physical_worker_observed_component_json_number_text -ceq
                "0.05000000074505806" -and
            -not [bool]$diagnosis.identity_values_equal -and
            -not [bool]$diagnosis.tolerance_or_rethreshold_permitted -and
            [bool]$diagnosis.r24d5_preregistration_evaluator_worker_or_result_repair_forbidden -and
            [bool]$diagnosis.scientifically_distinct_prospectively_frozen_successor_required -and
            [bool]$immutability.same_source_physical_rerun_forbidden -and
            [bool]$immutability.r24d5_result_reinterpretation_or_tolerance_forbidden -and
            [bool]$immutability.raw_numerical_outcome_promotion_forbidden -and
            [bool]$claims.declared_zero_world_gate_passed -and
            -not [bool]$claims.zero_world_gate_adequate_for_physical_full_precision_serialization_identity -and
            [bool]$claims.physical_world_executed -and
            [bool]$claims.physical_worker_raw_report_completed -and
            -not [bool]$claims.valid_descriptive_development_characterization -and
            -not [bool]$claims.numerical_accuracy_or_telemetry_semantics_accepted -and
            [int]$claims.empirical_acceptance_threshold_count -eq 0 -and
            [int]$claims.superiority_margin_count -eq 0 -and
            [int]$claims.equivalence_or_non_inferiority_margin_count -eq 0 -and
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

Assert-R24D5PhysicalClosure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/")
) "repository_root"
Assert-R24D5PhysicalClosure (
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository_remote"
Assert-R24D5PhysicalClosure (
    Test-Path -LiteralPath $closurePath -PathType Leaf
) "closure_missing"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D5PhysicalClosure (
    Test-R24D5ClosureSemanticVector $closure
) "closure_semantic_vector"

$source = $closure.source
$sourceCommit = [string]$source.commit
Assert-R24D5PhysicalClosure (
    [string]$source.repository_root -ceq $repoRoot.Replace("\", "/") -and
    [string]$source.remote -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    [string]$source.branch -ceq "main" -and
    $sourceCommit -ceq "fffb773b408b0cf8bb4a3ba78e773b62c3a0e52a" -and
    [bool]$source.clean_pushed_before_zero_world_and_physical_attempt -and
    [bool]$source.local_upstream_cached_live_equal_before_attempt -and
    [int]$source.worktree_count -eq 1
) "source_identity"
git -C $repoRoot cat-file -e "$sourceCommit^{commit}"
Assert-R24D5PhysicalClosure ($LASTEXITCODE -eq 0) "source_commit_missing"

$validationManifest = $source.validation_manifest
$sourceBindings = @($closure.source_bindings)
Assert-R24D5PhysicalClosure ($sourceBindings.Count -eq 10) "source_binding_count"
$allBindings = @($validationManifest) + $sourceBindings
foreach ($binding in $allBindings) {
    $relative = [string]$binding.path
    $bytes = Get-R24D5GitBlobBytes `
        -RepositoryRoot $repoRoot `
        -Commit $sourceCommit `
        -RelativePath $relative
    $blobOid = (git -C $repoRoot rev-parse "$sourceCommit`:$relative").Trim()
    Assert-R24D5PhysicalClosure (
        $blobOid -ceq [string]$binding.git_blob_oid -and
        (Get-R24D5BytesSha256 $bytes) -ceq [string]$binding.raw_sha256 -and
        $bytes.Length -eq [long]$binding.byte_length
    ) "source_binding_$relative"
}

$manifestBytes = Get-R24D5GitBlobBytes `
    -RepositoryRoot $repoRoot `
    -Commit $sourceCommit `
    -RelativePath ([string]$validationManifest.path)
$manifest = [Text.Encoding]::UTF8.GetString($manifestBytes) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D5PhysicalClosure (
    [string]$manifest.schema_version -ceq
        "sporespore_qsdk_r24d5_one_hinge_telemetry_validation_manifest_v1" -and
    [string]$manifest.gate_id -ceq "QSDK-R24D5" -and
    [string]$manifest.question_class -ceq "development" -and
    [int]$manifest.source_binding_count -eq 10 -and
    @($manifest.bindings).Count -eq 10
) "validation_manifest_identity"
for ($index = 0; $index -lt $sourceBindings.Count; $index += 1) {
    Assert-R24D5PhysicalClosure (
        (@($manifest.bindings)[$index] | ConvertTo-Json -Compress) -ceq
        ($sourceBindings[$index] | ConvertTo-Json -Compress)
    ) "validation_manifest_binding_$index"
}

$runtime = $closure.runtime
Assert-R24D5PhysicalClosure (
    [string]$runtime.profile_id -ceq
        "godot_4_7_jolt_sporespore_motor_telemetry_v1" -and
    [string]$runtime.console_binary_raw_sha256 -ceq
        "sha256:762ed7137d06284742b53abdde9b98c692ab1e8d3a184458db4d8e7a39782462" -and
    [long]$runtime.console_binary_byte_length -eq 293376 -and
    [string]$runtime.engine_binary_raw_sha256 -ceq
        "sha256:d0bb895b996fa98ec69a68b9f98ca6ed99af2eb18ef67a0b176ad1a55220278d" -and
    [long]$runtime.engine_binary_byte_length -eq 188826624 -and
    [string]$runtime.physics_engine -ceq "Jolt Physics" -and
    [int]$runtime.physics_ticks_per_second -eq 120 -and
    [int]$runtime.solver_velocity_steps -eq 20 -and
    [int]$runtime.solver_position_steps -eq 7 -and
    [string]$runtime.thread_model -ceq "single_safe" -and
    [bool]$runtime.telemetry_class_registered -and
    [bool]$runtime.telemetry_method_registered
) "runtime_identity"

$evidenceRoot = [IO.Path]::GetFullPath(
    (Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot)
).TrimEnd("\", "/")
$zero = $closure.prerequisite_zero_world
$zeroPayload = Get-R24D5CasPayloadPath `
    -EvidenceRoot $evidenceRoot `
    -RawSha256 ([string]$zero.receipt_raw_sha256) `
    -ByteLength ([long]$zero.receipt_byte_length) `
    -Code "zero_world_receipt"
$zeroReceipt = Get-Content -Raw -LiteralPath $zeroPayload |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D5PhysicalClosure (
    [string]$zero.status -ceq "declared_complete_zero_world_gate_passed" -and
    [string]$zeroReceipt.schema_version -ceq
        "sporespore_qsdk_r24d5_one_hinge_telemetry_zero_world_qualification_receipt_v1" -and
    [bool]$zeroReceipt.ok -and
    [string]$zeroReceipt.gate_id -ceq "QSDK-R24D5" -and
    [string]$zeroReceipt.question_class -ceq
        "non_physical_source_conformance" -and
    [string]$zeroReceipt.source.head -ceq $sourceCommit -and
    [string]$zeroReceipt.source.upstream -ceq $sourceCommit -and
    [string]$zeroReceipt.source.cached_origin_main -ceq $sourceCommit -and
    [string]$zeroReceipt.source.live_origin_main -ceq $sourceCommit -and
    [bool]$zeroReceipt.source.clean -and
    [int]$zeroReceipt.static_audit_stage_count -eq 5 -and
    [int]$zeroReceipt.source.source_binding_count -eq 10 -and
    [int]$zeroReceipt.evaluator_negative_control_count -eq 24 -and
    [int]$zeroReceipt.accepted_outcome_mutation_count -eq 2 -and
    [int]$zeroReceipt.contract_mutation_rejection_count -eq 14 -and
    [int]$zeroReceipt.worker.receipt.active_physics_object_count -eq 0 -and
    [int]$zeroReceipt.worker.receipt.world_attempt_count -eq 0 -and
    [int]$zeroReceipt.worker.receipt.world_build_count -eq 0 -and
    [int]$zeroReceipt.worker.receipt.solver_step_count -eq 0 -and
    -not [bool]$zeroReceipt.physical_characterization_executed -and
    -not [bool]$zeroReceipt.physical_acceptance_authority -and
    -not [bool]$zeroReceipt.release_authority
) "zero_world_receipt"
$passingFixtureGates = @(
    $zeroReceipt.worker.receipt.fixture_description_gates.Values |
        Where-Object { [bool]$_ }
).Count
Assert-R24D5PhysicalClosure (
    $zeroReceipt.worker.receipt.fixture_description_gates.Count -eq 10 -and
    $passingFixtureGates -eq 10 -and
    [int]$zero.static_audit_stage_count -eq 5 -and
    [int]$zero.source_binding_count -eq 10 -and
    [int]$zero.evaluator_negative_control_count -eq 24 -and
    [int]$zero.accepted_outcome_mutation_count -eq 2 -and
    [int]$zero.contract_mutation_rejection_count -eq 14 -and
    [int]$zero.worker_fixture_gate_count -eq 10 -and
    [int]$zero.worker_fixture_gate_pass_count -eq 10
) "zero_world_closure_binding"

$attempt = $closure.attempt
$runRoot = [IO.Path]::GetFullPath([string]$attempt.run_root)
$expectedPhysicalBase = [IO.Path]::GetFullPath(
    (Join-Path $evidenceRoot "qsdk-r24d5-one-hinge-physical")
).TrimEnd("\", "/")
Assert-R24D5PhysicalClosure (
    $runRoot.StartsWith(
        $expectedPhysicalBase + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    (Split-Path -Leaf $runRoot) -ceq
        "fffb773b408b0cf8bb4a3ba78e773b62c3a0e52a-762ed7137d06-d0bb895b996f-20260816T140344350Z-b98d8e813932" -and
    (Test-Path -LiteralPath $runRoot -PathType Container)
) "run_root"

$retained = @($closure.retained_files)
$retention = $closure.retention
$liveFiles = @(Get-ChildItem -LiteralPath $runRoot -File -Recurse)
Assert-R24D5PhysicalClosure (
    $retained.Count -eq 19 -and
    $liveFiles.Count -eq 19 -and
    [int]$retention.retained_file_count -eq 19 -and
    [int]$retention.unique_content_digest_count -eq 16 -and
    [bool]$retention.all_retained_files_content_addressed_before_closure_authority -and
    [bool]$retention.supervisor_published_attempt_failure_and_raw_report -and
    [bool]$retention.closure_intake_published_remaining_missing_digests -and
    [bool]$retention.live_run_root_is_a_durable_convenience_copy_not_historical_identity_authority -and
    [bool]$retention.cas_payloads_are_historical_result_identity_authority
) "retention_boundary"

$retainedByPath = @{}
$uniqueDigests = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::Ordinal
)
foreach ($entry in $retained) {
    $relative = [string]$entry.path
    Assert-R24D5PhysicalClosure (
        -not $retainedByPath.ContainsKey($relative)
    ) "duplicate_retained_path_$relative"
    $retainedByPath[$relative] = $entry
    [void]$uniqueDigests.Add([string]$entry.raw_sha256)
    $retainedPath = [IO.Path]::GetFullPath((Join-Path $runRoot $relative))
    Assert-R24D5PhysicalClosure (
        $retainedPath.StartsWith(
            $runRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        (Test-Path -LiteralPath $retainedPath -PathType Leaf) -and
        (Get-R24D5RawSha256 $retainedPath) -ceq [string]$entry.raw_sha256 -and
        (Get-Item -LiteralPath $retainedPath).Length -eq [long]$entry.byte_length
    ) "retained_live_copy_$relative"
    [void](Get-R24D5CasPayloadPath `
        -EvidenceRoot $evidenceRoot `
        -RawSha256 ([string]$entry.raw_sha256) `
        -ByteLength ([long]$entry.byte_length) `
        -Code "retained_$relative")
}
Assert-R24D5PhysicalClosure (
    $retainedByPath.Count -eq 19 -and $uniqueDigests.Count -eq 16
) "retained_inventory_counts"

function Get-R24D5RetainedText {
    param([Parameter(Mandatory)][string]$RelativePath)
    Assert-R24D5PhysicalClosure (
        $retainedByPath.ContainsKey($RelativePath)
    ) "retained_text_unknown_$RelativePath"
    $entry = $retainedByPath[$RelativePath]
    $payload = Get-R24D5CasPayloadPath `
        -EvidenceRoot $evidenceRoot `
        -RawSha256 ([string]$entry.raw_sha256) `
        -ByteLength ([long]$entry.byte_length) `
        -Code "retained_text_$RelativePath"
    return Get-Content -Raw -LiteralPath $payload
}

$expectedStages = @(
    @("01-r24d4_zero_world_failure_closure.log", "QSDK_R24D4_ZERO_WORLD_FAILURE_CLOSURE_PASS "),
    @("02-r24d5_freeze_audit.log", "QSDK_R24D5_ONE_HINGE_TELEMETRY_FREEZE_PASS "),
    @("03-r24d3_source_audit.log", "QSDK_R24D3_GODOT_JOLT_MOTOR_TELEMETRY_SOURCE_PASS "),
    @("04-r24d3_cold_adoption_audit.log", "QSDK_R24D3_COLD_QUALIFICATION_ADOPTION_PASS "),
    @("05-r24d3_post_adoption_full_cold_audit.log", "QSDK_R24D3_POST_ADOPTION_FULL_COLD_CONFORMANCE_QUALIFICATION_PASS ")
)
foreach ($stage in $expectedStages) {
    $stageLines = @((Get-R24D5RetainedText $stage[0]) -split "`r?`n")
    [void](Get-R24D5Marker `
        -Lines $stageLines `
        -Prefix $stage[1] `
        -Code $stage[0])
}

$attemptRecord = Get-R24D5RetainedText "attempt.json" |
    ConvertFrom-Json -AsHashtable -Depth 100
$failureRecord = Get-R24D5RetainedText "failure.json" |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D5PhysicalClosure (
    [string]$attemptRecord.schema_version -ceq
        "sporespore_qsdk_r24d5_physical_attempt_v1" -and
    [string]$attemptRecord.gate_id -ceq "QSDK-R24D5" -and
    [string]$attemptRecord.question_class -ceq "development" -and
    [string]$attemptRecord.status -ceq "consumed_before_worker_launch" -and
    [string]$attemptRecord.source_commit -ceq $sourceCommit -and
    [string]$attemptRecord.execution_nonce -ceq
        [string]$attempt.execution_nonce -and
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
    -not [bool]$attemptRecord.release_authority
) "attempt_record"
Assert-R24D5PhysicalClosure (
    [string]$failureRecord.schema_version -ceq
        "sporespore_qsdk_r24d5_physical_failure_v1" -and
    [string]$failureRecord.status -ceq
        "retained_incomplete_or_invalid_attempt_no_same_source_rerun" -and
    [string]$failureRecord.message -ceq
        [string]$attempt.supervisor_terminal_error -and
    [int]$failureRecord.world_attempt_count_lower_bound -eq 0 -and
    [int]$failureRecord.world_attempt_count_upper_bound -eq 1 -and
    [int]$failureRecord.world_build_count_lower_bound -eq 0 -and
    [int]$failureRecord.world_build_count_upper_bound -eq 1 -and
    -not [bool]$failureRecord.same_source_rerun_allowed -and
    -not [bool]$failureRecord.physical_acceptance_authority -and
    -not [bool]$failureRecord.release_authority
) "failure_record"

$rawText = Get-R24D5RetainedText "raw_report.json"
$raw = $rawText | ConvertFrom-Json -AsHashtable -Depth 100
$workerExecution = $closure.worker_execution
$expectedCellIds = @($workerExecution.cell_ids_in_order)
$expectedSampleCounts = @($workerExecution.retained_sample_counts_in_order)
Assert-R24D5PhysicalClosure (
    [string]$raw.schema_version -ceq
        "sporespore_qsdk_r24d5_godot_jolt_one_hinge_raw_report_v1" -and
    [string]$raw.gate_id -ceq "QSDK-R24D5" -and
    [string]$raw.question_class -ceq "development" -and
    [string]$raw.source_commit -ceq $sourceCommit -and
    [string]$raw.execution_nonce -ceq [string]$attempt.execution_nonce -and
    [string]$raw.engine.physics_engine -ceq "Jolt Physics" -and
    [int]$raw.engine.physics_ticks_per_second -eq 120 -and
    [int]$raw.engine.solver_velocity_steps -eq 20 -and
    [int]$raw.engine.solver_position_steps -eq 7 -and
    [string]$raw.engine.thread_model -ceq "single_safe" -and
    [bool]$raw.engine.telemetry_class_registered -and
    [bool]$raw.engine.telemetry_method_registered -and
    [string]$raw.fixture.fixture_id -ceq
        "QSDK.R24D5.godot_jolt_one_hinge_telemetry.v1" -and
    (@($raw.fixture.hinge_axis_parent_local) -join ",") -ceq "0,0,1" -and
    [int]$raw.fixture.contact_count -eq 0 -and
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
    @($raw.cells).Count -eq 9
) "raw_report_identity"

$retainedSampleCount = 0
for ($index = 0; $index -lt 9; $index += 1) {
    $cell = @($raw.cells)[$index]
    $samples = @($cell.samples)
    $retainedSampleCount += $samples.Count
    Assert-R24D5PhysicalClosure (
        [string]$cell.cell_id -ceq [string]$expectedCellIds[$index] -and
        [int]$cell.retained_step_count -eq [int]$expectedSampleCounts[$index] -and
        $samples.Count -eq [int]$expectedSampleCounts[$index] -and
        [bool]$cell.pre_tree_read_refused -and
        [bool]$raw.refusals.not_in_tree_joint_read_refused_by_cell[
            [string]$cell.cell_id
        ]
    ) "raw_cell_$index"
    foreach ($component in @($cell.parameter_readback.child_inertia_diagonal_kg_m2)) {
        Assert-R24D5PhysicalClosure (
            (ConvertTo-R24D5RoundTripString ([double]$component)) -ceq
                "0.05000000074505806"
        ) "raw_cell_inertia_$index"
    }
}
Assert-R24D5PhysicalClosure (
    $retainedSampleCount -eq 68 -and
    [bool]$workerExecution.worker_execution_completed -and
    -not [bool]$workerExecution.raw_numerical_outcomes_accepted_as_characterization
) "raw_sample_inventory"

$fixtureComponents = @($raw.fixture.child_inertia_diagonal_kg_m2)
Assert-R24D5PhysicalClosure ($fixtureComponents.Count -eq 3) "fixture_inertia_count"
foreach ($component in $fixtureComponents) {
    Assert-R24D5PhysicalClosure (
        (ConvertTo-R24D5RoundTripString ([double]$component)) -ceq
            "0.05000000074505806"
    ) "fixture_inertia_value"
}
Assert-R24D5PhysicalClosure (
    $rawText.Contains(
        '"child_inertia_diagonal_kg_m2":[0.05000000074505806,0.05000000074505806,0.05000000074505806]',
        [StringComparison]::Ordinal
    )
) "fixture_inertia_raw_json"

$physicalStdout = Get-R24D5RetainedText "godot-physical-stdout.log"
$physicalLines = @($physicalStdout -split "`r?`n")
$rawMarker = Get-R24D5Marker `
    -Lines $physicalLines `
    -Prefix "QSDK_R24D5_PHYSICAL_RAW_REPORT " `
    -Code "physical_raw_report"
$termination = Get-R24D5Marker `
    -Lines $physicalLines `
    -Prefix "QSDK_R24D5_GODOT_SUPERVISOR_TERMINATION_READY " `
    -Code "physical_termination" |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D5PhysicalClosure (
    $rawMarker -ceq $rawText.TrimEnd("`r", "`n") -and
    [string]$termination.schema_version -ceq
        "sporespore_godot_supervised_termination_ready_v1" -and
    [string]$termination.termination_protocol_id -ceq
        "godot_4_7_gdscript_shutdown_containment_v1" -and
    [string]$termination.termination_nonce -ceq [string]$attempt.execution_nonce -and
    [int]$termination.requested_exit_code -eq 0 -and
    [int]$termination.drained_process_frame_count -eq 2 -and
    [bool]$termination.worker_receipt_emitted -and
    [string]$termination.worker_receipt_kind -ceq "physical_raw_report" -and
    -not [bool]$termination.physics_evidence_authority
) "physical_worker_termination"

$evaluationLog = Get-R24D5RetainedText "05-evaluation.log"
Assert-R24D5PhysicalClosure (
    $evaluationLog.Contains("exit_code=2", [StringComparison]::Ordinal) -and
    $evaluationLog.Contains(
        "QSDK_R24D5_EVALUATION_ERROR fixture_inertia_representation",
        [StringComparison]::Ordinal
    ) -and
    -not (Test-Path -LiteralPath (Join-Path $runRoot "evaluation.json")) -and
    -not (Test-Path -LiteralPath (Join-Path $runRoot "receipt.json")) -and
    -not [bool]$attempt.evaluation_record_written -and
    -not [bool]$attempt.terminal_physical_receipt_written
) "evaluator_terminal"

$preregistrationText = [Text.Encoding]::UTF8.GetString(
    (Get-R24D5GitBlobBytes `
        -RepositoryRoot $repoRoot `
        -Commit $sourceCommit `
        -RelativePath ([string]$sourceBindings[0].path))
)
$evaluatorText = [Text.Encoding]::UTF8.GetString(
    (Get-R24D5GitBlobBytes `
        -RepositoryRoot $repoRoot `
        -Commit $sourceCommit `
        -RelativePath ([string]$sourceBindings[1].path))
)
$workerText = [Text.Encoding]::UTF8.GetString(
    (Get-R24D5GitBlobBytes `
        -RepositoryRoot $repoRoot `
        -Commit $sourceCommit `
        -RelativePath ([string]$sourceBindings[4].path))
)
$supervisorText = [Text.Encoding]::UTF8.GetString(
    (Get-R24D5GitBlobBytes `
        -RepositoryRoot $repoRoot `
        -Commit $sourceCommit `
        -RelativePath ([string]$sourceBindings[5].path))
)
$diagnosis = $closure.diagnosis
$expectedValue = [double]::Parse(
    [string]$diagnosis.frozen_evaluator_expected_component_json_number_text,
    [Globalization.CultureInfo]::InvariantCulture
)
$actualValue = [double]::Parse(
    [string]$diagnosis.physical_worker_observed_component_json_number_text,
    [Globalization.CultureInfo]::InvariantCulture
)
Assert-R24D5PhysicalClosure (
    $preregistrationText.Contains(
        '"child_inertia_default_json_stringify_diagonal_kg_m2": [0.0500000007450581, 0.0500000007450581, 0.0500000007450581]',
        [StringComparison]::Ordinal
    ) -and
    $evaluatorText.Contains(
        "EXPECTED_CHILD_INERTIA_JSON_COMPONENT_KG_M2 = 0.0500000007450581",
        [StringComparison]::Ordinal
    ) -and
    $evaluatorText.Contains(
        '"fixture_inertia_representation",',
        [StringComparison]::Ordinal
    ) -and
    $workerText.Contains(
        'JSON.stringify(report, "", true, true)',
        [StringComparison]::Ordinal
    ) -and
    $supervisorText.Contains(
        "same_source_physical_attempt_already_exists",
        [StringComparison]::Ordinal
    ) -and
    $supervisorText.Contains(
        "Get-R24D5MatchingPhysicalAttempts",
        [StringComparison]::Ordinal
    ) -and
    (ConvertTo-R24D5RoundTripString $expectedValue) -ceq
        "0.0500000007450581" -and
    (ConvertTo-R24D5RoundTripString $actualValue) -ceq
        "0.05000000074505806" -and
    ('0x{0:x16}' -f [BitConverter]::DoubleToInt64Bits($expectedValue)) -ceq
        [string]$diagnosis.frozen_evaluator_expected_component_binary64_bits -and
    ('0x{0:x16}' -f [BitConverter]::DoubleToInt64Bits($actualValue)) -ceq
        [string]$diagnosis.physical_worker_observed_component_binary64_bits -and
    $expectedValue -ne $actualValue -and
    [Math]::Abs($expectedValue - $actualValue).ToString(
        "R", [Globalization.CultureInfo]::InvariantCulture
    ) -ceq [string]$diagnosis.absolute_binary64_value_difference_text -and
    [string]$diagnosis.worker_report_stringify_call -ceq
        'JSON.stringify(report, "", true, true)' -and
    [bool]$diagnosis.declared_zero_world_gate_passed_without_exercising_physical_raw_report_serialization_identity -and
    [bool]$diagnosis.failure_occurred_after_one_complete_worker_world_and_before_any_valid_evaluation_record
) "frozen_serialization_diagnosis"

$godotRoot = [IO.Path]::GetFullPath($GodotSourceRoot)
$godotSource = $diagnosis.godot_full_precision_source
Assert-R24D5PhysicalClosure (
    (git -C $godotRoot remote get-url origin).Trim() -ceq
        [string]$runtime.godot_source_repository
) "godot_source_remote"
$godotBytes = Get-R24D5GitBlobBytes `
    -RepositoryRoot $godotRoot `
    -Commit ([string]$runtime.godot_source_commit) `
    -RelativePath ([string]$godotSource.path)
$godotBlob = (git -C $godotRoot rev-parse (
    "{0}:{1}" -f [string]$runtime.godot_source_commit, [string]$godotSource.path
)).Trim()
$godotText = [Text.Encoding]::UTF8.GetString($godotBytes)
Assert-R24D5PhysicalClosure (
    $godotBlob -ceq [string]$godotSource.git_blob_oid -and
    (Get-R24D5BytesSha256 $godotBytes) -ceq
        [string]$godotSource.raw_sha256 -and
    $godotBytes.Length -eq [long]$godotSource.byte_length -and
    $godotText.Contains(
        [string]$godotSource.full_precision_branch_line,
        [StringComparison]::Ordinal
    ) -and
    $godotText.Contains(
        [string]$godotSource.full_precision_conversion_line,
        [StringComparison]::Ordinal
    ) -and
    $godotText.Contains(
        'D_METHOD("stringify", "data", "indent", "sort_keys", "full_precision")',
        [StringComparison]::Ordinal
    ) -and
    (@($godotSource.script_binding_argument_order) -join "|") -ceq
        "data|indent|sort_keys|full_precision"
) "godot_full_precision_source"

$projectRig = $retainedByPath[
    "project/scripts/lab/rigs/r24d5_godot_jolt_one_hinge_telemetry_rig.gd"
]
$projectProbe = $retainedByPath[
    "project/scripts/lab/rigs/r24d5_godot_jolt_telemetry_stepping_probe_body.gd"
]
$projectWorker = $retainedByPath[
    "project/tests/test_sdk_qsdk_r24d5_godot_jolt_one_hinge_telemetry_physical_worker.gd"
]
Assert-R24D5PhysicalClosure (
    [string]$projectRig.raw_sha256 -ceq [string]$sourceBindings[2].raw_sha256 -and
    [long]$projectRig.byte_length -eq [long]$sourceBindings[2].byte_length -and
    [string]$projectProbe.raw_sha256 -ceq [string]$sourceBindings[3].raw_sha256 -and
    [long]$projectProbe.byte_length -eq [long]$sourceBindings[3].byte_length -and
    [string]$projectWorker.raw_sha256 -ceq [string]$sourceBindings[4].raw_sha256 -and
    [long]$projectWorker.byte_length -eq [long]$sourceBindings[4].byte_length
) "isolated_project_source_binding"

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
Assert-R24D5PhysicalClosure (
    $matchingAttempts.Count -eq 1 -and
    [IO.Path]::GetFullPath($matchingAttempts[0]) -ceq
        [IO.Path]::GetFullPath((Join-Path $runRoot "attempt.json"))
) "same_source_attempt_count"

$mutations = @(
    { param($value) $value.status = "complete_valid_characterization" },
    { param($value) $value.result_class = "positive" },
    { param($value) $value.attempt.world_attempt_count = 0 },
    { param($value) $value.attempt.evaluator_exit_code = 0 },
    { param($value) $value.attempt.same_source_rerun_allowed = $true },
    { param($value) $value.diagnosis.physical_worker_observed_component_json_number_text = "0.0500000007450581" },
    { param($value) $value.diagnosis.identity_values_equal = $true },
    { param($value) $value.diagnosis.tolerance_or_rethreshold_permitted = $true },
    { param($value) $value.immutability.raw_numerical_outcome_promotion_forbidden = $false },
    { param($value) $value.claims.valid_descriptive_development_characterization = $true },
    { param($value) $value.claims.turning_claim_changed = $true },
    { param($value) $value.claims.release_authority = $true }
)
$mutationRejectionCount = 0
foreach ($mutation in $mutations) {
    $candidate = $closure | ConvertTo-Json -Depth 100 |
        ConvertFrom-Json -AsHashtable -Depth 100
    & $mutation $candidate
    if (-not (Test-R24D5ClosureSemanticVector $candidate)) {
        $mutationRejectionCount += 1
    }
}
Assert-R24D5PhysicalClosure (
    $mutationRejectionCount -eq 12
) "closure_mutation_controls"

Write-Output (
    "QSDK_R24D5_PHYSICAL_FAILURE_CLOSURE_PASS " +
    ([ordered]@{
        ok = $true
        closure_id = "QSDK-R24D5-PH1-CLOSURE"
        status = (
            "worker_execution_complete_evaluation_invalid_" +
            "fixture_json_identity_mismatch"
        )
        question_class = "development"
        source_commit = $sourceCommit
        declared_zero_world_gate_passed = $true
        physical_world_attempt_count = 1
        physical_world_build_count = 1
        physics_step_count = 20
        retained_sample_count = 68
        retained_file_count = $retained.Count
        retained_unique_digest_count = $uniqueDigests.Count
        evaluator_exit_code = 2
        valid_characterization = $false
        same_source_rerun_forbidden = $true
        distinct_successor_required = $true
        closure_mutation_rejection_count = $mutationRejectionCount
        turning_claim_changed = $false
        prone_to_standing_world_opened = $false
        physical_acceptance_authority = $false
        release_authority = $false
    } | ConvertTo-Json -Compress)
)

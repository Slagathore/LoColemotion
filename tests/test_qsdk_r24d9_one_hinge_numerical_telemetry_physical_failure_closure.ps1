#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$AllowProspectiveUncommitted
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$expectedRepoRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$evidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$sourceCommit = "62b6b98c45d65d0fe7262969213a1e2898bd57f3"
$sourceTree = "5db62acf5db9316309d123ffd73c91c9715b1bac"
$closureRelative = (
    "sdk/recovery/" +
    "r24d9_godot_jolt_one_hinge_numerical_telemetry_physical_failure_closure_v1.json"
)
$closurePath = Join-Path $repoRoot $closureRelative
$marker = "QSDK_R24D9_ONE_HINGE_NUMERICAL_TELEMETRY_PHYSICAL_FAILURE_CLOSURE_PASS"

function Assert-R24D9Closure {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Code
    )
    if (-not $Condition) {
        throw "QSDK-R24D9 physical failure closure: $Code"
    }
}

function Get-R24D9RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R24D9BytesSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Invoke-R24D9Git {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Code
    )
    $output = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-R24D9Closure ($LASTEXITCODE -eq 0) (
        "$Code`:$($output -join '|')"
    )
    return @($output)
}

function Get-R24D9GitValue {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Code
    )
    $output = @(Invoke-R24D9Git -Arguments $Arguments -Code $Code)
    Assert-R24D9Closure ($output.Count -eq 1) "${Code}_line_count"
    return ([string]$output[0]).Trim()
}

function Get-R24D9GitBlobBytes {
    param(
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
        "-C", $repoRoot, "cat-file", "blob", "${Commit}:$RelativePath"
    )) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-R24D9Closure ($process.Start()) "git_cat_file_start"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R24D9Closure ($process.ExitCode -eq 0) (
            "historical_blob_unavailable_${RelativePath}:$stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Get-R24D9Utf8Text {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return [Text.UTF8Encoding]::new($false, $true).GetString($Bytes)
}

function Get-R24D9CasPayloadPath {
    param(
        [Parameter(Mandatory)][string]$RawSha256,
        [Parameter(Mandatory)][long]$ByteLength,
        [Parameter(Mandatory)][string]$Code
    )
    Assert-R24D9Closure (
        $RawSha256 -cmatch '^sha256:[0-9a-f]{64}$'
    ) "${Code}_digest_shape"
    $digest = $RawSha256.Substring(7)
    $directory = Join-Path $evidenceRoot "artifacts/sha256/$digest"
    $payloadPath = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R24D9Closure (
        (Test-Path -LiteralPath $payloadPath -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf)
    ) "${Code}_retained_cas_missing"
    Assert-R24D9Closure (
        (Get-Item -LiteralPath $payloadPath).Length -eq $ByteLength -and
        (Get-R24D9RawSha256 -Path $payloadPath) -ceq $RawSha256
    ) "${Code}_retained_cas_payload"
    $manifest = Get-Content -LiteralPath $manifestPath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 20
    Assert-R24D9Closure (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.algorithm -ceq "sha256" -and
        [string]$manifest.sha256 -ceq $RawSha256 -and
        [long]$manifest.byte_length -eq $ByteLength -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "${Code}_retained_cas_manifest"
    return $payloadPath
}

function Get-R24D9CasJson {
    param(
        [Parameter(Mandatory)][string]$RawSha256,
        [Parameter(Mandatory)][long]$ByteLength,
        [Parameter(Mandatory)][string]$Code
    )
    $payload = Get-R24D9CasPayloadPath `
        -RawSha256 $RawSha256 `
        -ByteLength $ByteLength `
        -Code $Code
    return Get-Content -LiteralPath $payload -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Copy-R24D9Value {
    param([Parameter(Mandatory)]$Value)
    return $Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json `
        -AsHashtable -Depth 100
}

function Test-R24D9ClosureSemanticVector {
    param([Parameter(Mandatory)]$Candidate)
    try {
        $source = $Candidate.source
        $runtime = $Candidate.runtime
        $zero = $Candidate.prerequisite_zero_world
        $physical = $Candidate.physical_attempt
        $findings = $Candidate.reported_descriptive_findings_preserved_but_not_promotable
        $diagnosis = $Candidate.diagnosis
        $parent = $Candidate.parent_authorization_correction
        $retention = $Candidate.retention
        $statistics = $Candidate.statistical_claim_boundary
        $immutability = $Candidate.immutability
        $next = $Candidate.next_boundary
        $audit = $Candidate.audit_contract
        $claims = $Candidate.claims
        return (
            [string]$Candidate.schema_version -ceq
                "sporespore_qsdk_r24d9_one_hinge_numerical_telemetry_physical_failure_closure_v1" -and
            [string]$Candidate.closure_id -ceq "QSDK-R24D9-PH1-CLOSURE" -and
            [string]$Candidate.gate_id -ceq "QSDK-R24D9" -and
            [string]$Candidate.question_class -ceq "development" -and
            [string]$Candidate.status -ceq
                "zero_world_passed_physical_attempt_implementation_invalid_extra_unretained_post_activation_solver_step" -and
            [string]$Candidate.result_class -ceq
                "invalid_development_result_no_native_numerical_characterization" -and
            [string]$source.commit -ceq $sourceCommit -and
            [string]$source.tree_git_oid -ceq $sourceTree -and
            [string]$source.remote -ceq $expectedRemote -and
            [bool]$source.clean_pushed_before_zero_world_and_physical_attempt -and
            [bool]$source.local_upstream_cached_live_equal_before_zero_world_and_physical_attempt -and
            [int]$source.worktree_count -eq 1 -and
            [int]$source.validation_manifest.source_binding_count -eq 15 -and
            [string]$runtime.profile_id -ceq
                "godot_4_7_jolt_sporespore_motor_telemetry_active_step_snapshot_v2" -and
            [string]$runtime.godot_source_commit -ceq
                "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88" -and
            [string]$runtime.combined_patch_raw_sha256 -ceq
                "sha256:9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c" -and
            [string]$runtime.console_binary_raw_sha256 -ceq
                "sha256:9506c1c51ec3cfdeb7dffecce702410498a1793da9d36270a21088f9a8c33e51" -and
            [string]$runtime.engine_binary_raw_sha256 -ceq
                "sha256:03a24e45e77197445ddb9d85385aa6f5904a2e358684fdb01c3cabe9f656bf9d" -and
            [bool]$runtime.retained_binary_pair_executed -and
            -not [bool]$runtime.reproducible_build_claimed -and
            -not [bool]$runtime.result_reuse_authority -and
            [string]$zero.receipt_raw_sha256 -ceq
                "sha256:c0aacb88def170019585c81563e4f1c92e20d003cabc75fdba3260518d7cc64c" -and
            [int]$zero.static_stage_count -eq 8 -and
            [int]$zero.static_stage_pass_count -eq 8 -and
            [int]$zero.world_attempt_count -eq 0 -and
            [int]$zero.world_build_count -eq 0 -and
            [int]$zero.solver_step_count -eq 0 -and
            [bool]$zero.static_and_serialization_qualification_passed_on_its_declared_terms -and
            -not [bool]$zero.adequate_to_detect_the_later_unretained_step_defect -and
            -not [bool]$zero.adequate_to_repair_invalid_parent_authorization -and
            [string]$physical.execution_nonce -ceq
                "80063d5bc6ee48ff8dda1644104916bf" -and
            [string]$physical.immutable_attempt_status -ceq
                "complete_valid_finite_descriptive_development_result" -and
            [string]$physical.immutable_evaluator_result -ceq
                "complete_valid_finite_descriptive_native_numerical_characterization" -and
            [bool]$physical.immutable_evaluator_execution_valid -and
            [bool]$physical.immutable_evaluator_native_numerical_telemetry_characterized -and
            -not [bool]$physical.immutable_evaluator_numerical_accuracy_accepted -and
            [int]$physical.immutable_reported_world_attempt_count -eq 1 -and
            [int]$physical.immutable_reported_world_build_count -eq 1 -and
            [int]$physical.immutable_reported_solver_step_count -eq 20 -and
            [int]$physical.retained_sample_count -eq 68 -and
            -not [bool]$physical.same_source_rerun_allowed -and
            [string]$physical.posthoc_closure_disposition -ceq
                "implementation_invalid_no_characterization" -and
            -not [bool]$physical.immutable_attempt_evaluator_result_or_receipt_rewritten -and
            [int]$findings.all_awake_first_retained_telemetry_sequence -eq 2 -and
            [int]$findings.limit_positive_last_retained_telemetry_sequence -eq 21 -and
            [int]$findings.limit_negative_last_retained_capture_space_step_sequence -eq 21 -and
            [double]$findings.brake_positive_declared_initial_rate_rad_s -eq 0.4 -and
            [double]$findings.brake_positive_first_retained_pre_rate_rad_s -eq 0.0 -and
            [double]$findings.disabled_negative_declared_initial_rate_rad_s -eq -0.4 -and
            [double]$findings.disabled_negative_first_retained_pre_rate_rad_s -eq 0.0 -and
            (@($findings.sleep_stale_read_space_step_sequences) -join "|") -ceq
                "2|3|4|5" -and
            -not [bool]$findings.descriptive_values_are_valid_characterization_evidence -and
            [string]$diagnosis.classification -ceq
                "implementation_invalid_extra_unretained_post_activation_solver_step_and_initial_state_loss" -and
            [int]$diagnosis.declared_maximum_physics_step_count -eq 20 -and
            [int]$diagnosis.worker_reported_physics_step_count -eq 20 -and
            [int]$diagnosis.observed_exact_jolt_space_step_count -eq 21 -and
            [int]$diagnosis.unretained_post_activation_solver_step_count -eq 1 -and
            [int]$diagnosis.retained_solver_step_count -eq 20 -and
            -not [bool]$diagnosis.step_count_contract_satisfied -and
            -not [bool]$diagnosis.declared_initial_rate_state_preserved_until_first_retained_pre_rate -and
            [int]@($diagnosis.source_proof).Count -eq 6 -and
            [bool]$diagnosis.reported_evaluator_pass_is_consistent_with_frozen_evaluator -and
            -not [bool]$diagnosis.reported_evaluator_pass_establishes_execution_validity_after_posthoc_step_proof -and
            -not [bool]$diagnosis.native_patch_or_telemetry_binding_invalidated -and
            [bool]$diagnosis.same_source_worker_evaluator_or_result_repair_forbidden -and
            [bool]$diagnosis.scientifically_distinct_prospectively_frozen_successor_required -and
            [string]$parent.parent_gate_id -ceq "QSDK-R24D8" -and
            -not [bool]$parent.historical_positive_closure_rewritten -and
            [int]$parent.historical_positive_closure_recorded_solver_step_count -eq 8 -and
            (@($parent.historical_positive_closure_recorded_fresh_capture_sequences) -join "|") -ceq
                "2|3|4|5" -and
            (@($parent.historical_positive_closure_recorded_sleeping_read_sequences) -join "|") -ceq
                "6|7|8|9" -and
            [int]$parent.parent_preregistration_declared_exact_jolt_space_step_count -eq 8 -and
            [int]$parent.parent_observed_exact_jolt_space_step_count -eq 9 -and
            -not [bool]$parent.parent_exact_step_contract_satisfied -and
            [bool]$parent.parent_observed_current_and_stale_snapshot_tokens_preserved -and
            -not [bool]$parent.parent_valid_finite_campaign_result_accepted_by_this_later_authority -and
            -not [bool]$parent.parent_authorization_was_adequate_for_r24d9_physical_execution -and
            -not [bool]$parent.historical_campaign_result_or_interpretation_silently_rewritten -and
            [int]@($Candidate.execution_source_bindings).Count -eq 15 -and
            [int]@($Candidate.posthoc_diagnostic_source_bindings).Count -eq 2 -and
            [int]@($Candidate.zero_world_retained_files).Count -eq 21 -and
            [int]@($Candidate.physical_retained_files).Count -eq 14 -and
            [int]$retention.zero_world_unique_content_digest_count -eq 18 -and
            [int]$retention.physical_unique_content_digest_count -eq 13 -and
            [int]$retention.cross_run_retained_file_reference_count -eq 35 -and
            [int]$retention.cross_run_unique_content_digest_count -eq 27 -and
            [bool]$retention.all_retained_files_content_addressed_before_closure_authority -and
            [int]@($statistics.empirical_acceptance_thresholds).Count -eq 0 -and
            [int]@($statistics.superiority_margins).Count -eq 0 -and
            [int]@($statistics.equivalence_or_non_inferiority_margins).Count -eq 0 -and
            [int]@($statistics.held_out_validation_cohorts).Count -eq 0 -and
            [int]@($statistics.population_claims).Count -eq 0 -and
            [bool]$immutability.same_source_physical_rerun_forbidden -and
            [bool]$immutability.r24d9_evaluator_repair_forbidden -and
            [bool]$immutability.r24d9_result_reinterpretation_as_valid_characterization_forbidden -and
            [bool]$immutability.r24d8_historical_positive_closure_rewrite_forbidden -and
            [string]$next.gate_id -ceq "QSDK-R24D10" -and
            [string]$next.question_class -ceq "development" -and
            [int]@($next.required_source_derived_validity_controls).Count -eq 7 -and
            -not [bool]$next.physical_world_authorized_now -and
            -not [bool]$next.recovery_world_authorized_now -and
            -not [bool]$next.prone_to_standing_world_authorized_now -and
            [bool]$audit.source_commit_git_blob_verification_required -and
            [bool]$audit.retained_cas_payload_verification_required -and
            [int]$audit.world_attempt_count -eq 0 -and
            [int]$audit.world_build_count -eq 0 -and
            [int]$audit.solver_step_count -eq 0 -and
            [bool]$claims.complete_zero_world_gate_passed -and
            [bool]$claims.physical_world_executed -and
            [bool]$claims.frozen_evaluator_completed_and_reported_valid -and
            -not [bool]$claims.posthoc_execution_validity_audit_passed -and
            -not [bool]$claims.valid_descriptive_development_characterization -and
            -not [bool]$claims.native_numerical_telemetry_characterized -and
            -not [bool]$claims.numerical_accuracy_or_telemetry_values_accepted -and
            -not [bool]$claims.instrumented_profile_promoted -and
            -not [bool]$claims.turning_claim_changed -and
            -not [bool]$claims.recovery_world_opened -and
            -not [bool]$claims.prone_to_standing_world_opened -and
            -not [bool]$claims.cross_engine_equivalence_claimed -and
            -not [bool]$claims.q_sdk_r24_satisfied -and
            -not [bool]$claims.physical_acceptance_authority -and
            -not [bool]$claims.release_authority
        )
    } catch {
        return $false
    }
}

Assert-R24D9Closure (
    [IO.Path]::GetFullPath($repoRoot) -ceq
        [IO.Path]::GetFullPath($expectedRepoRoot) -and
    (Get-R24D9GitValue -Arguments @("rev-parse", "--show-toplevel") `
        -Code "repo_root") -ceq $repoRoot.Replace("\", "/") -and
    (Get-R24D9GitValue -Arguments @("remote", "get-url", "origin") `
        -Code "repo_remote") -ceq $expectedRemote -and
    (Test-Path -LiteralPath $closurePath -PathType Leaf)
) "repository_or_closure_identity"

if (-not $AllowProspectiveUncommitted) {
    Assert-R24D9Closure (
        @(& git -C $repoRoot status --short).Count -eq 0
    ) "worktree_not_clean"
}

Assert-R24D9Closure (
    (Get-R24D9GitValue -Arguments @("cat-file", "-t", $sourceCommit) `
        -Code "source_commit_type") -ceq "commit" -and
    (Get-R24D9GitValue -Arguments @("rev-parse", "${sourceCommit}^{tree}") `
        -Code "source_tree") -ceq $sourceTree
) "source_commit_or_tree"

$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D9Closure (
    Test-R24D9ClosureSemanticVector -Candidate $closure
) "semantic_vector"

$allBindings = @($closure.execution_source_bindings) +
    @($closure.posthoc_diagnostic_source_bindings)
$bindingPaths = @($allBindings | ForEach-Object { [string]$_.path })
Assert-R24D9Closure (
    @($bindingPaths | Sort-Object -Unique).Count -eq 17
) "source_binding_paths_unique"
$blobTexts = @{}
foreach ($binding in $allBindings) {
    $path = [string]$binding.path
    $bytes = Get-R24D9GitBlobBytes -Commit $sourceCommit -RelativePath $path
    $oid = Get-R24D9GitValue `
        -Arguments @("rev-parse", "${sourceCommit}:$path") `
        -Code "source_blob_oid_$path"
    Assert-R24D9Closure (
        $oid -ceq [string]$binding.git_blob_oid -and
        $bytes.Length -eq [long]$binding.byte_length -and
        (Get-R24D9BytesSha256 -Bytes $bytes) -ceq [string]$binding.raw_sha256
    ) "source_binding_$path"
    $blobTexts[$path] = Get-R24D9Utf8Text -Bytes $bytes
}

$manifestPath = "sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_validation_manifest.json"
$manifestBytes = Get-R24D9GitBlobBytes `
    -Commit $sourceCommit `
    -RelativePath $manifestPath
Assert-R24D9Closure (
    $manifestBytes.Length -eq [long]$closure.source.validation_manifest.byte_length -and
    (Get-R24D9BytesSha256 -Bytes $manifestBytes) -ceq
        [string]$closure.source.validation_manifest.raw_sha256 -and
    (Get-R24D9GitValue -Arguments @("rev-parse", "${sourceCommit}:$manifestPath") `
        -Code "validation_manifest_oid") -ceq
        [string]$closure.source.validation_manifest.git_blob_oid
) "validation_manifest_binding"

$preregPath = "sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_characterization_preregistration_v1.json"
$workerPath = "tests/test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_worker.gd"
$patchPath = "sdk/adapters/godot/engine_patches/godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch"
$r24d8PreregPath = "sdk/recovery/r24d8_godot_jolt_active_step_snapshot_timing_preregistration_v1.json"
$r24d8WorkerPath = "tests/test_sdk_qsdk_r24d8_godot_jolt_active_step_snapshot_timing_worker.gd"
$r24d8ClosurePath = "sdk/recovery/r24d8_godot_jolt_active_step_snapshot_timing_positive_closure_v1.json"

$prereg = $blobTexts[$preregPath] | ConvertFrom-Json -AsHashtable -Depth 100
$r24d8Prereg = $blobTexts[$r24d8PreregPath] |
    ConvertFrom-Json -AsHashtable -Depth 100
$r24d8Closure = $blobTexts[$r24d8ClosurePath] |
    ConvertFrom-Json -AsHashtable -Depth 100
$patchText = [string]$blobTexts[$patchPath]
$workerText = [string]$blobTexts[$workerPath]
$r24d8WorkerText = [string]$blobTexts[$r24d8WorkerPath]

Assert-R24D9Closure (
    [int]$prereg.fixture_freeze.maximum_physics_step_count -eq 20 -and
    [int]$prereg.fixture_freeze.pre_activation_initial_angular_velocity_write_count -eq 4 -and
    [double]$prereg.cell_families.signed_braking.initial_canonical_rate_rad_s[0] -eq 0.4 -and
    [double]$prereg.cell_families.signed_braking.initial_canonical_rate_rad_s[1] -eq -0.4 -and
    [double]$prereg.cell_families.motor_disabled.initial_canonical_rate_rad_s[0] -eq 0.4 -and
    [double]$prereg.cell_families.motor_disabled.initial_canonical_rate_rad_s[1] -eq -0.4
) "r24d9_preregistered_step_and_initial_state"
Assert-R24D9Closure (
    $patchText.Contains("uint64_t step_sequence = 0;", [StringComparison]::Ordinal) -and
    $patchText.Contains("if (unlikely(++step_sequence == 0))", [StringComparison]::Ordinal) -and
    $patchText.Contains("joint->capture_post_step_telemetry(step_sequence, p_step);", [StringComparison]::Ordinal)
) "v2_patch_step_token_semantics"

$activateIndex = $workerText.IndexOf(
    "initial_velocity_write_count += RigScript.activate(cell)",
    [StringComparison]::Ordinal
)
$preSampleIndex = $workerText.IndexOf(
    "pre_sample_physics_frame_count += 1",
    [StringComparison]::Ordinal
)
$loopIndex = $workerText.IndexOf(
    "for step_index in range(1, RigScript.MAXIMUM_PHYSICS_STEP_COUNT + 1):",
    [StringComparison]::Ordinal
)
$deactivateIndex = $workerText.IndexOf(
    "PhysicsServer3D.set_active(false)",
    [StringComparison]::Ordinal
)
Assert-R24D9Closure (
    $activateIndex -ge 0 -and
    $preSampleIndex -gt $activateIndex -and
    $loopIndex -gt $preSampleIndex -and
    $deactivateIndex -gt $loopIndex
) "r24d9_worker_unretained_boundary_order"

Assert-R24D9Closure (
    [int]$r24d8Prereg.finite_physical_question.maximum_physics_step_count -eq 8 -and
    [int]$r24d8Prereg.finite_physical_question.pre_sample_physics_frame_count -eq 1 -and
    [string]$r24d8Prereg.finite_physical_question.terminal_deactivation_timing -ceq
        "The isolated PhysicsServer3D is deactivated after reading completed solve 8 and before JoltSpace3D can execute solve 9." -and
    [int]$r24d8Closure.physical_attempt.solver_step_count -eq 8 -and
    (@($r24d8Closure.timing_observation.fresh_capture_space_step_sequences) -join "|") -ceq
        "2|3|4|5" -and
    (@($r24d8Closure.timing_observation.sleeping_read_space_step_sequences) -join "|") -ceq
        "6|7|8|9" -and
    $r24d8WorkerText.Contains("pre_sample_physics_frame_count += 1", [StringComparison]::Ordinal)
) "r24d8_parent_step_contradiction"

$allRetained = @($closure.zero_world_retained_files) +
    @($closure.physical_retained_files)
$uniqueDigests = @($allRetained | ForEach-Object { [string]$_.raw_sha256 } |
    Sort-Object -Unique)
Assert-R24D9Closure (
    $allRetained.Count -eq 35 -and
    $uniqueDigests.Count -eq 27
) "retained_inventory_counts"
foreach ($file in $allRetained) {
    [void](Get-R24D9CasPayloadPath `
        -RawSha256 ([string]$file.raw_sha256) `
        -ByteLength ([long]$file.byte_length) `
        -Code ("retained_" + ([string]$file.path).Replace("/", "_")))
}

$zeroReceipt = Get-R24D9CasJson `
    -RawSha256 "sha256:c0aacb88def170019585c81563e4f1c92e20d003cabc75fdba3260518d7cc64c" `
    -ByteLength 89612 `
    -Code "zero_receipt"
$attempt = Get-R24D9CasJson `
    -RawSha256 "sha256:e652a5ae759e829b39d74a66a26bed93d23f8c46ed74cca2d53bb1f3bf6dae25" `
    -ByteLength 860 `
    -Code "physical_attempt"
$raw = Get-R24D9CasJson `
    -RawSha256 "sha256:c34158a59dfb4f932fa74373d8893cccfc96008bb46578dfbf61da5ce07804d8" `
    -ByteLength 73983 `
    -Code "physical_raw_report"
$evaluation = Get-R24D9CasJson `
    -RawSha256 "sha256:f60d1c188077accaaabd90e057aa3f1189bdb70260ff6e0a1c25bbdc857cf909" `
    -ByteLength 63095 `
    -Code "physical_evaluation"
$physicalReceipt = Get-R24D9CasJson `
    -RawSha256 "sha256:db5070bb486695c2ca4aff0ec85bc847986ff0f0946eaaa1d189bcf943c4646a" `
    -ByteLength 84408 `
    -Code "physical_receipt"

Assert-R24D9Closure (
    [bool]$zeroReceipt.ok -and
    [string]$zeroReceipt.status -ceq
        "complete_zero_world_gate_passed_physical_execution_separately_authorized" -and
    [int]$zeroReceipt.actual_counts.world_attempt_count -eq 0 -and
    [int]$zeroReceipt.actual_counts.world_build_count -eq 0 -and
    [int]$zeroReceipt.actual_counts.solver_step_count -eq 0 -and
    [bool]$zeroReceipt.claims.complete_zero_world_gate_passed -and
    -not [bool]$zeroReceipt.claims.native_numerical_telemetry_characterized
) "immutable_zero_receipt"
Assert-R24D9Closure (
    [string]$attempt.status -ceq
        "complete_valid_finite_descriptive_development_result" -and
    [int]$attempt.solver_step_count -eq 20 -and
    -not [bool]$attempt.same_source_rerun_allowed -and
    [string]$physicalReceipt.status -ceq
        "complete_valid_finite_descriptive_development_result" -and
    [int]$physicalReceipt.actual_counts.solver_step_count -eq 20 -and
    [bool]$physicalReceipt.claims.native_numerical_telemetry_characterized -and
    -not [bool]$physicalReceipt.claims.numerical_accuracy_accepted -and
    -not [bool]$physicalReceipt.claims.instrumented_profile_promoted
) "immutable_attempt_and_receipt_labels"
Assert-R24D9Closure (
    [string]$evaluation.result -ceq
        "complete_valid_finite_descriptive_native_numerical_characterization" -and
    [bool]$evaluation.execution_valid -and
    [bool]$evaluation.native_numerical_telemetry_characterized -and
    -not [bool]$evaluation.numerical_accuracy_accepted -and
    -not [bool]$evaluation.instrumented_profile_promoted -and
    [double]$evaluation.summary.maximum_absolute_impulse_residual_nms -eq
        0.05999999679625034 -and
    [double]$evaluation.summary.maximum_absolute_work_residual_j -eq
        0.03599999602884063
) "immutable_evaluator_result"

Assert-R24D9Closure (
    [int]$raw.execution.physics_step_count -eq 20 -and
    [int]$raw.execution.pre_sample_physics_frame_count -eq 1 -and
    [int]$raw.execution.retained_sample_count -eq 68 -and
    [int]@($raw.cells).Count -eq 9
) "raw_execution_shape"
$cells = @{}
foreach ($cell in @($raw.cells)) {
    $cells[[string]$cell.cell_id] = $cell
}
Assert-R24D9Closure ($cells.Count -eq 9) "raw_cell_identity_count"

foreach ($cellId in @(
    "drive_positive", "drive_negative", "brake_positive", "brake_negative",
    "disabled_positive", "disabled_negative", "limit_positive", "limit_negative",
    "sleep_stale"
)) {
    Assert-R24D9Closure ($cells.ContainsKey($cellId)) "raw_cell_missing_$cellId"
}

foreach ($cellId in @(
    "drive_positive", "drive_negative", "brake_positive", "brake_negative",
    "disabled_positive", "disabled_negative", "limit_positive", "limit_negative"
)) {
    $first = @($cells[$cellId].samples)[0]
    Assert-R24D9Closure (
        [int]$first.telemetry.telemetry_sequence -eq 2 -and
        [int]$first.telemetry.capture_space_step_sequence -eq 2 -and
        [int]$first.telemetry.read_space_step_sequence -eq 2
    ) "raw_first_sequence_$cellId"
}
$limitPositiveLast = @($cells.limit_positive.samples)[-1]
$limitNegativeLast = @($cells.limit_negative.samples)[-1]
Assert-R24D9Closure (
    [int]$limitPositiveLast.telemetry.telemetry_sequence -eq 21 -and
    [int]$limitPositiveLast.telemetry.capture_space_step_sequence -eq 21 -and
    [int]$limitPositiveLast.telemetry.read_space_step_sequence -eq 21 -and
    [int]$limitNegativeLast.telemetry.telemetry_sequence -eq 21 -and
    [int]$limitNegativeLast.telemetry.capture_space_step_sequence -eq 21 -and
    [int]$limitNegativeLast.telemetry.read_space_step_sequence -eq 21
) "raw_exact_twenty_one_space_steps"

foreach ($case in @(
    @{ id = "brake_positive"; declared = 0.4 },
    @{ id = "brake_negative"; declared = -0.4 },
    @{ id = "disabled_positive"; declared = 0.4 },
    @{ id = "disabled_negative"; declared = -0.4 }
)) {
    $cell = $cells[[string]$case.id]
    $first = @($cell.samples)[0]
    Assert-R24D9Closure (
        [double]$cell.initial_canonical_rate_rad_s -eq [double]$case.declared -and
        [double]$first.pre_canonical_relative_rate_rad_s -eq 0.0
    ) "raw_initial_state_consumed_$($case.id)"
}

$sleep = @($cells.sleep_stale.samples)
Assert-R24D9Closure (
    (@($sleep | ForEach-Object { [int]$_.telemetry.telemetry_sequence }) -join "|") -ceq
        "2|2|2|2" -and
    (@($sleep | ForEach-Object { [int]$_.telemetry.capture_space_step_sequence }) -join "|") -ceq
        "2|2|2|2" -and
    (@($sleep | ForEach-Object { [int]$_.telemetry.read_space_step_sequence }) -join "|") -ceq
        "2|3|4|5"
) "raw_sleep_stale_tokens"

$mutationCases = @(
    @{ name = "status"; apply = { param($m) $m.status = "valid" } },
    @{ name = "result_class"; apply = { param($m) $m.result_class = "valid_characterization" } },
    @{ name = "source_commit"; apply = { param($m) $m.source.commit = ("0" * 40) } },
    @{ name = "source_tree"; apply = { param($m) $m.source.tree_git_oid = ("0" * 40) } },
    @{ name = "zero_receipt"; apply = { param($m) $m.prerequisite_zero_world.receipt_raw_sha256 = "sha256:$('0' * 64)" } },
    @{ name = "physical_nonce"; apply = { param($m) $m.physical_attempt.execution_nonce = ("0" * 32) } },
    @{ name = "immutable_result"; apply = { param($m) $m.physical_attempt.immutable_evaluator_result = "invalid" } },
    @{ name = "reported_step_count"; apply = { param($m) $m.physical_attempt.immutable_reported_solver_step_count = 21 } },
    @{ name = "posthoc_disposition"; apply = { param($m) $m.physical_attempt.posthoc_closure_disposition = "valid" } },
    @{ name = "last_token"; apply = { param($m) $m.reported_descriptive_findings_preserved_but_not_promotable.limit_positive_last_retained_telemetry_sequence = 20 } },
    @{ name = "initial_rate"; apply = { param($m) $m.reported_descriptive_findings_preserved_but_not_promotable.brake_positive_declared_initial_rate_rad_s = 0.0 } },
    @{ name = "characterization_promotion"; apply = { param($m) $m.reported_descriptive_findings_preserved_but_not_promotable.descriptive_values_are_valid_characterization_evidence = $true } },
    @{ name = "diagnosis"; apply = { param($m) $m.diagnosis.classification = "valid" } },
    @{ name = "declared_max"; apply = { param($m) $m.diagnosis.declared_maximum_physics_step_count = 21 } },
    @{ name = "observed_step_count"; apply = { param($m) $m.diagnosis.observed_exact_jolt_space_step_count = 20 } },
    @{ name = "step_gate"; apply = { param($m) $m.diagnosis.step_count_contract_satisfied = $true } },
    @{ name = "parent_rewrite"; apply = { param($m) $m.parent_authorization_correction.historical_positive_closure_rewritten = $true } },
    @{ name = "parent_observed_steps"; apply = { param($m) $m.parent_authorization_correction.parent_observed_exact_jolt_space_step_count = 8 } },
    @{ name = "parent_valid"; apply = { param($m) $m.parent_authorization_correction.parent_valid_finite_campaign_result_accepted_by_this_later_authority = $true } },
    @{ name = "parent_authorization"; apply = { param($m) $m.parent_authorization_correction.parent_authorization_was_adequate_for_r24d9_physical_execution = $true } },
    @{ name = "source_binding_drop"; apply = { param($m) $m.execution_source_bindings = @($m.execution_source_bindings)[0..13] } },
    @{ name = "diagnostic_binding_drop"; apply = { param($m) $m.posthoc_diagnostic_source_bindings = @($m.posthoc_diagnostic_source_bindings)[0] } },
    @{ name = "zero_inventory_drop"; apply = { param($m) $m.zero_world_retained_files = @($m.zero_world_retained_files)[0..19] } },
    @{ name = "physical_inventory_drop"; apply = { param($m) $m.physical_retained_files = @($m.physical_retained_files)[0..12] } },
    @{ name = "cross_digest_count"; apply = { param($m) $m.retention.cross_run_unique_content_digest_count = 26 } },
    @{ name = "same_source_rerun"; apply = { param($m) $m.immutability.same_source_physical_rerun_forbidden = $false } },
    @{ name = "next_gate"; apply = { param($m) $m.next_boundary.gate_id = "QSDK-R24D9" } },
    @{ name = "physical_authorization"; apply = { param($m) $m.next_boundary.physical_world_authorized_now = $true } },
    @{ name = "posthoc_valid"; apply = { param($m) $m.claims.posthoc_execution_validity_audit_passed = $true } },
    @{ name = "native_characterized"; apply = { param($m) $m.claims.native_numerical_telemetry_characterized = $true } },
    @{ name = "profile_promoted"; apply = { param($m) $m.claims.instrumented_profile_promoted = $true } },
    @{ name = "prone_opened"; apply = { param($m) $m.claims.prone_to_standing_world_opened = $true } },
    @{ name = "turning_changed"; apply = { param($m) $m.claims.turning_claim_changed = $true } },
    @{ name = "equivalence"; apply = { param($m) $m.claims.cross_engine_equivalence_claimed = $true } },
    @{ name = "release"; apply = { param($m) $m.claims.release_authority = $true } }
)
$rejectedMutationCount = 0
foreach ($case in $mutationCases) {
    $mutant = Copy-R24D9Value -Value $closure
    & $case.apply $mutant
    Assert-R24D9Closure (
        -not (Test-R24D9ClosureSemanticVector -Candidate $mutant)
    ) "mutation_accepted_$($case.name)"
    $rejectedMutationCount += 1
}

Write-Host (
    "$marker source=$($sourceCommit.Substring(0, 8)) " +
    "source_bindings=17 retained_files=35 retained_unique=27 " +
    "reported_steps=20 proven_steps=21 parent_reported_steps=8 " +
    "parent_proven_steps=9 mutations=$rejectedMutationCount " +
    "worlds=0 builds=0 solver_steps=0 physical_authority=False release=False"
)

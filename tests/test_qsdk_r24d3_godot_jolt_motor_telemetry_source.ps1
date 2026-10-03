#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$GodotSourceRoot = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$contractPath = Join-Path $repoRoot (
    "sdk\recovery\r24d3_godot_jolt_motor_telemetry_source_v1.json"
)
$manifestPath = Join-Path $repoRoot (
    "sdk\recovery\" +
    "r24d3_godot_jolt_motor_telemetry_source_validation_manifest.json"
)
$successorPath = Join-Path $repoRoot (
    "sdk\recovery\" +
    "r24d3_godot_jolt_motor_telemetry_artifact_complete_successor_v2.json"
)
$adoptionPath = Join-Path $repoRoot (
    "sdk\recovery\" +
    "r24d3_godot_jolt_motor_telemetry_cold_qualification_adoption_v2.json"
)
$adoptionAuditPath = Join-Path $repoRoot (
    "tests\" +
    "test_qsdk_r24d3_godot_jolt_motor_telemetry_cold_qualification_adoption.ps1"
)
$fullColdQualificationPath = Join-Path $repoRoot (
    "sdk\recovery\" +
    "r24d3_godot_jolt_motor_telemetry_post_adoption_" +
    "full_cold_conformance_qualification_v1.json"
)
$fullColdQualificationAuditPath = Join-Path $repoRoot (
    "tests\" +
    "test_qsdk_r24d3_godot_jolt_motor_telemetry_post_adoption_" +
    "full_cold_conformance_qualification.ps1"
)
$runnerPath = Join-Path $repoRoot (
    "sdk\run_qsdk_r24d3_instrumented_zero_world_gate.ps1"
)
$patchPath = Join-Path $repoRoot (
    "sdk\adapters\godot\engine_patches\" +
    "godot_4_7_jolt_motor_telemetry.patch"
)
$bindingTestPath = Join-Path $repoRoot (
    "tests\test_sdk_qsdk_r24d3_godot_jolt_motor_telemetry_binding_zero_world.gd"
)
$attributesPath = Join-Path $repoRoot ".gitattributes"
$releasePath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$expectedRepoRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRepoRemote = "https://github.com/Slagathore/sporespore.git"
$expectedGodotRemote = "https://github.com/godotengine/godot.git"
$expectedGodotCommit = "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"
$expectedPatchHash = (
    "f067543bc6237a38c0c0935a56b3bbebcd318dc6d82cec1321ea5d52e45dae2f"
)

function Assert-R24D3 {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "QSDK-R24D3: $Message" }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Normalize-Lf {
    param([Parameter(Mandatory)][string]$Text)
    return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Get-GitValue {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    $output = @(& git -C $Root @Arguments 2>&1)
    Assert-R24D3 ($LASTEXITCODE -eq 0) (
        "git $($Arguments -join ' ') failed: $($output -join ' | ')"
    )
    return ($output -join "`n").Trim()
}

function Test-R24D3PatchSemantics {
    param([Parameter(Mandatory)][string]$Text)

    $requiredMarkers = @(
        "GetMotorTelemetrySequence() const",
        "GetMotorTelemetryStep() const",
        "GetMotorTelemetryState() const",
        "GetTotalLambdaMotor()",
        "r_telemetry.signed_motor_impulse_nms = constraint->GetTotalLambdaMotor();",
        "return mA1.Dot(mBody2->GetAngularVelocity() - mBody1->GetAngularVelocity());",
        "float work = inAppliedImpulse * 0.5f * (inRelativeAngularVelocityBefore + inRelativeAngularVelocityAfter);",
        "mPositiveMotorWork += work;",
        "mAbsorbedMotorWork -= work;",
        "mPositiveMotorWork = 0.0f;",
        "mAbsorbedMotorWork = 0.0f;",
        "mMotorConstraintPart.WarmStart(*mBody1, *mBody2, inWarmStartImpulseRatio);",
        "AccumulateMotorWork(mMotorConstraintPart.GetTotalLambda(), motor_velocity_before, motor_velocity_after);",
        "float motor_lambda_before = mMotorConstraintPart.GetTotalLambda();",
        "AccumulateMotorWork(motor_lambda_after - motor_lambda_before, motor_velocity_before, motor_velocity_after);",
        "if (unlikely(_is_fixed()) || jolt_ref == nullptr)",
        "if (sequence == 0 || solver_step_s <= 0.0f)",
        "joint == nullptr || joint->get_type() != JOINT_TYPE_HINGE",
        "space == nullptr || space->is_stepping()",
        "if (physics_server == nullptr || (physics_server->on_separate_thread && !physics_server->doing_sync))",
        'result["schema"] = "sporespore.godot_jolt_hinge_motor_telemetry.v1";',
        'result["signed_motor_impulse_nms"] = motor_telemetry.signed_motor_impulse_nms;',
        'result["positive_motor_work_j"] = motor_telemetry.positive_motor_work_j;',
        'result["absorbed_motor_work_j"] = motor_telemetry.absorbed_motor_work_j;',
        'result["net_motor_work_j"] = motor_telemetry.positive_motor_work_j - motor_telemetry.absorbed_motor_work_j;'
    )
    foreach ($marker in $requiredMarkers) {
        if (-not $Text.Contains($marker, [StringComparison]::Ordinal)) {
            return $false
        }
    }
    return $true
}

function Test-R24D3ArtifactCompleteRunner {
    param([Parameter(Mandatory)][string]$Text)

    $requiredMarkers = @(
        'sporespore_qsdk_r24d3_instrumented_zero_world_gate_receipt_v2',
        '$retainedBinaryRoot = Join-Path $runRoot "artifacts"',
        '-Destination $retainedConsolePath',
        '-Destination $retainedEnginePath',
        '$retainedConsoleHash -ceq $consoleSourceHash',
        '$retainedEngineHash -ceq $engineSourceHash',
        '$postBindingConsoleHash -ceq $retainedConsoleHash',
        '$postBindingEngineHash -ceq $retainedEngineHash',
        'retained_binary_count = 2',
        'execution_used_retained_binary_pair = $true'
    )
    foreach ($marker in $requiredMarkers) {
        if (-not $Text.Contains($marker, [StringComparison]::Ordinal)) {
            return $false
        }
    }
    if (
        [regex]::Matches(
            $Text,
            [regex]::Escape('-FileName $retainedConsolePath')
        ).Count -ne 2
    ) {
        return $false
    }
    $retentionIndex = $Text.IndexOf(
        '$retainedBinaryRoot = Join-Path $runRoot "artifacts"',
        [StringComparison]::Ordinal
    )
    $versionIndex = $Text.IndexOf(
        '$godotVersion = Invoke-R24D3Checked',
        [StringComparison]::Ordinal
    )
    $bindingIndex = $Text.IndexOf(
        '$binding = Invoke-R24D3Checked',
        [StringComparison]::Ordinal
    )
    $postBindingIndex = $Text.IndexOf(
        '$postBindingConsoleHash =',
        [StringComparison]::Ordinal
    )
    return (
        $retentionIndex -ge 0 -and
        $retentionIndex -lt $versionIndex -and
        $versionIndex -lt $bindingIndex -and
        $bindingIndex -lt $postBindingIndex
    )
}

foreach ($path in @(
    $contractPath,
    $manifestPath,
    $successorPath,
    $adoptionPath,
    $adoptionAuditPath,
    $fullColdQualificationPath,
    $fullColdQualificationAuditPath,
    $runnerPath,
    $patchPath,
    $bindingTestPath,
    $attributesPath,
    $releasePath,
    $supportPath
)) {
    Assert-R24D3 (Test-Path -LiteralPath $path -PathType Leaf) (
        "Required source is missing: $path"
    )
}

$root = Get-GitValue -Root $repoRoot -Arguments @("rev-parse", "--show-toplevel")
$remote = Get-GitValue -Root $repoRoot -Arguments @("remote", "get-url", "origin")
$branch = Get-GitValue -Root $repoRoot -Arguments @("branch", "--show-current")
Assert-R24D3 ([IO.Path]::GetFullPath($root) -ceq $expectedRepoRoot) (
    "Canonical repository root changed: $root"
)
Assert-R24D3 ($remote -ceq $expectedRepoRemote) "Origin changed: $remote"
Assert-R24D3 ($branch -ceq "main") "Branch changed: $branch"

$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$manifest = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$successor = Get-Content -LiteralPath $successorPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$adoption = Get-Content -LiteralPath $adoptionPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$fullColdQualification = Get-Content -LiteralPath $fullColdQualificationPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$release = Get-Content -LiteralPath $releasePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$support = Get-Content -LiteralPath $supportPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$patchText = Normalize-Lf ([IO.File]::ReadAllText($patchPath))
$bindingTestText = Normalize-Lf ([IO.File]::ReadAllText($bindingTestPath))
$attributesText = Normalize-Lf ([IO.File]::ReadAllText($attributesPath))
$runnerText = Normalize-Lf ([IO.File]::ReadAllText($runnerPath))
$patchHash = Get-RawSha256 $patchPath

Assert-R24D3 (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r24d3_godot_jolt_motor_telemetry_source_contract_v1" -and
    [string]$contract.gate_id -ceq "QSDK-R24D3" -and
    [string]$contract.work_id -ceq
        "QSDK-R24D3-GODOT-JOLT-EXACT-MOTOR-TELEMETRY-SOURCE" -and
    [string]$contract.status -ceq
        "implemented_compile_proved_zero_world_binding_proved_characterization_withheld" -and
    [string]$contract.question_class -ceq "non_physical_source_conformance" -and
    -not [bool]$contract.physical_question_opened
) "Contract identity or non-physical boundary changed."

$parent = $contract.parent_boundary
Assert-R24D3 (
    [string]$parent.parent_commit -ceq
        "d7995aeac268f22142edd82564c79b5d7b56c881" -and
    [string]$parent.parent_gate_id -ceq "QSDK-R24D2" -and
    [int]$parent.preserved_stock_godot_supported_channel_count -eq 8 -and
    (@($parent.preserved_stock_godot_unsupported_channels) -join "|") -ceq
        "applied_actuation_receipts|energy_balance_ledger" -and
    -not [bool]$parent.parent_result_rewritten -and
    -not [bool]$parent.parent_threshold_changed -and
    -not [bool]$parent.parent_selector_changed -and
    -not [bool]$parent.parent_interpretation_changed
) "The immutable R24D2 parent boundary changed."

$upstream = $contract.upstream_source
$expectedPatchedPaths = @(
    "modules/jolt_physics/joints/jolt_hinge_joint_3d.cpp",
    "modules/jolt_physics/joints/jolt_hinge_joint_3d.h",
    "modules/jolt_physics/jolt_physics_server_3d.cpp",
    "modules/jolt_physics/jolt_physics_server_3d.h",
    "modules/jolt_physics/register_types.cpp",
    "thirdparty/jolt_physics/Jolt/Physics/Constraints/HingeConstraint.cpp",
    "thirdparty/jolt_physics/Jolt/Physics/Constraints/HingeConstraint.h"
)
Assert-R24D3 (
    [string]$upstream.repository -ceq $expectedGodotRemote -and
    [string]$upstream.release -ceq "4.7-stable" -and
    [string]$upstream.commit -ceq $expectedGodotCommit -and
    [string]$upstream.patch_raw_sha256 -ceq "sha256:$expectedPatchHash" -and
    [int]$upstream.patch_file_count -eq 7 -and
    (@($upstream.patched_paths) -join "|") -ceq
        ($expectedPatchedPaths -join "|") -and
    [string]$upstream.custom_engine_profile_id -ceq
        "godot_4_7_jolt_sporespore_motor_telemetry_v1" -and
    -not [bool]$upstream.stock_godot_profile_changed -and
    $patchHash -ceq $expectedPatchHash
) "Pinned upstream or patch identity changed."

$diffHeaders = @(
    [regex]::Matches($patchText, '(?m)^diff --git a/([^ ]+) b/([^\n]+)$') |
        ForEach-Object { [string]$_.Groups[1].Value }
)
Assert-R24D3 (
    $diffHeaders.Count -eq 7 -and
    (@($diffHeaders | Sort-Object) -join "|") -ceq
        (@($expectedPatchedPaths | Sort-Object) -join "|")
) "Patch file inventory changed."
Assert-R24D3 (Test-R24D3PatchSemantics $patchText) (
    "Required exact motor impulse/work semantics are absent."
)

$decision = $contract.source_decision
$measurement = $contract.measurement_semantics
Assert-R24D3 (
    [bool]$decision.actuator_semantics_unchanged -and
    -not [bool]$decision.selected_velocity_motor_replaced_with_direct_body_torque -and
    -not [bool]$decision.configured_target_or_limit_relabelled_as_applied_effort -and
    -not [bool]$decision.aggregate_joint_reaction_relabelled_as_motor_effort -and
    -not [bool]$decision.endpoint_only_work_estimator_used -and
    [string]$measurement.receipt_schema -ceq
        "sporespore.godot_jolt_hinge_motor_telemetry.v1" -and
    [string]$measurement.binding_method -ceq
        "hinge_joint_get_motor_telemetry" -and
    [bool]$measurement.warm_start_included -and
    [bool]$measurement.every_iterative_motor_impulse_included -and
    [bool]$measurement.positive_and_absorbed_work_retained_separately -and
    -not [bool]$measurement.invalid_read_synthesizes_zero -and
    @($measurement.receipt_fields).Count -eq 11 -and
    @($measurement.refusal_conditions).Count -eq 8
) "Measurement semantics or refusal boundary changed."

$profiles = $contract.profile_boundary
Assert-R24D3 (
    [int]$profiles.stock_godot_4_7_jolt.supported_channel_count -eq 8 -and
    [int]$profiles.stock_godot_4_7_jolt.required_channel_count -eq 10 -and
    [bool]$profiles.stock_godot_4_7_jolt.typed_refusal_preserved -and
    -not [bool]$profiles.stock_godot_4_7_jolt.qualified_for_r24_recovery -and
    [int]$profiles.instrumented_godot_4_7_jolt_candidate.source_field_count -eq 10 -and
    [bool]$profiles.instrumented_godot_4_7_jolt_candidate.compile_proved -and
    [bool]$profiles.instrumented_godot_4_7_jolt_candidate.zero_world_binding_proved -and
    -not [bool]$profiles.instrumented_godot_4_7_jolt_candidate.native_sign_characterized -and
    -not [bool]$profiles.instrumented_godot_4_7_jolt_candidate.work_energy_oracle_characterized -and
    -not [bool]$profiles.instrumented_godot_4_7_jolt_candidate.qualified_for_r24_recovery -and
    -not [bool]$profiles.profile_substitution_allowed -and
    -not [bool]$profiles.stock_and_instrumented_results_interchangeable
) "Stock and instrumented Godot profiles were conflated."

$zeroWorld = $contract.zero_world_evidence
Assert-R24D3 (
    [bool]$zeroWorld.source_compile_passed -and
    [int]$zeroWorld.binding_assertion_count -eq 6 -and
    [int]$zeroWorld.binding_failed_assertion_count -eq 0 -and
    [bool]$zeroWorld.invalid_rid_refused -and
    [int]$zeroWorld.model_construction_count -eq 0 -and
    [int]$zeroWorld.world_attempt_count -eq 0 -and
    [int]$zeroWorld.world_build_count -eq 0 -and
    [int]$zeroWorld.solver_step_count -eq 0 -and
    -not [bool]$zeroWorld.physics_state_modified
) "Compile/binding evidence was inflated into physical evidence."

$adequacy = $contract.threshold_margin_cohort_and_population_adequacy
Assert-R24D3 (
    [int]$adequacy.empirical_physical_threshold_count -eq 0 -and
    [int]$adequacy.superiority_margin_count -eq 0 -and
    [int]$adequacy.equivalence_or_non_inferiority_margin_count -eq 0 -and
    [int]$adequacy.physical_cohort_identity_count -eq 0 -and
    [int]$adequacy.population_claim_count -eq 0 -and
    [int]$adequacy.algebraic_invariant_count -eq 3
) "Threshold, margin, cohort, or population authority appeared."

$claims = $contract.claims
foreach ($claim in @(
    "stock_godot_capability_promoted",
    "instrumented_godot_capability_promoted",
    "native_measurement_accuracy_claimed",
    "complete_r24_prephysical_gate_passed",
    "recovery_controller_implemented",
    "native_recovery_collector_implemented",
    "physical_recovery_world_opened",
    "prone_to_standing_claimed",
    "cross_engine_equivalence_claimed",
    "q_sdk_r24_satisfied",
    "physical_acceptance_authority",
    "release_authority"
)) {
    Assert-R24D3 (-not [bool]$claims[$claim]) "Nonclaim became true: $claim"
}

$predecessor = $successor.immutable_predecessor_observation
$predecessorAdequacy = $successor.predecessor_adequacy_disposition
$successorReceipt = $successor.successor_receipt_contract
$successorOpening = $successor.successor_opening_state
Assert-R24D3 (
    [string]$successor.schema_version -ceq
        "sporespore_qsdk_r24d3_artifact_complete_cold_qualification_successor_v2" -and
    [string]$successor.gate_id -ceq "QSDK-R24D3" -and
    [string]$successor.question_class -ceq "non_physical_source_conformance" -and
    [string]$successor.status -ceq
        "prospective_successor_declared_after_incomplete_artifact_retention" -and
    [string]$predecessor.source_commit -ceq
        "5f01d8ef3babb1132d341ee92f3773e653046d33" -and
    [string]$predecessor.receipt_schema -ceq
        "sporespore_qsdk_r24d3_instrumented_zero_world_gate_receipt_v1" -and
    [string]$predecessor.receipt_raw_sha256 -ceq
        "sha256:6b1c507e07024912d33171f859fc8c0fe5937b00bf67e372a2414dc42fd4b4b1" -and
    [int64]$predecessor.receipt_byte_length -eq 3550 -and
    [bool]$predecessor.cold_build -and
    [bool]$predecessor.compile_passed -and
    [int]$predecessor.binding_assertion_count -eq 6 -and
    [int]$predecessor.binding_failed_assertion_count -eq 0 -and
    [int]$predecessor.world_build_count -eq 0 -and
    [int]$predecessor.solver_step_count -eq 0 -and
    -not [bool]$predecessor.result_rewritten -and
    -not [bool]$predecessor.interpretation_rewritten -and
    -not [bool]$predecessorAdequacy.artifact_complete_qualification -and
    -not [bool]$predecessorAdequacy.clean_pushed_cold_build_qualified -and
    [bool]$predecessorAdequacy.console_launcher_hashed_in_original_receipt -and
    -not [bool]$predecessorAdequacy.engine_executable_hashed_in_original_receipt -and
    -not [bool]$predecessorAdequacy.console_launcher_retained_in_durable_evidence_root -and
    -not [bool]$predecessorAdequacy.engine_executable_retained_in_durable_evidence_root -and
    -not [bool]$predecessorAdequacy.post_hoc_hash_or_copy_may_repair_original_receipt -and
    [string]$successorReceipt.schema_version -ceq
        "sporespore_qsdk_r24d3_instrumented_zero_world_gate_receipt_v2" -and
    [bool]$successorReceipt.cold_build_required -and
    [int]$successorReceipt.required_retained_binary_count -eq 2 -and
    [bool]$successorReceipt.copy_before_version_and_binding_probe -and
    [bool]$successorReceipt.source_to_retained_sha256_equality_required -and
    [bool]$successorReceipt.execution_must_use_retained_console_and_sibling_engine_pair -and
    [bool]$successorReceipt.post_binding_retained_sha256_stability_required -and
    [int]$successor.runner_negative_controls.count -eq 6 -and
    @($successor.runner_negative_controls.required_rejections).Count -eq 6 -and
    -not [bool]$successorOpening.artifact_complete_successor_receipt_observed -and
    -not [bool]$successorOpening.clean_pushed_cold_build_qualified -and
    [int]$successorOpening.world_build_count -eq 0 -and
    [int]$successorOpening.solver_step_count -eq 0 -and
    -not [bool]$successorOpening.physical_question_opened -and
    -not [bool]$successorOpening.prone_to_standing_claimed -and
    -not [bool]$successorOpening.release_authority
) "Artifact-complete cold-qualification successor changed."

$adoptedClaims = $adoption.adopted_claim_boundary
Assert-R24D3 (
    [string]$adoption.schema_version -ceq
        "sporespore_qsdk_r24d3_artifact_complete_cold_qualification_adoption_v2" -and
    [string]$adoption.status -ceq
        "adopted_artifact_complete_cold_build_characterization_withheld" -and
    [string]$adoption.source_freeze.commit -ceq
        "2ca77925147db4ef381737b17aedc4af723130b4" -and
    [string]$adoption.retained_evidence.receipt_raw_sha256 -ceq
        "sha256:a72e1c6c5b51799bec46fe76737ea23f9998c0af6778bb52dc0b7ed2cd9f36d9" -and
    [int]$adoption.retained_evidence.retained_binary_count -eq 2 -and
    [bool]$adoption.retained_evidence.execution_used_retained_binary_pair -and
    [bool]$adoptedClaims.clean_pushed_cold_build_qualified -and
    -not [bool]$adoption.reproducibility_and_reuse_boundary.reproducible_build_claimed -and
    -not [bool]$adoption.reproducibility_and_reuse_boundary.result_reuse_authority -and
    -not [bool]$adoptedClaims.instrumented_native_sign_characterized -and
    -not [bool]$adoptedClaims.instrumented_godot_capability_promoted -and
    -not [bool]$adoptedClaims.physical_question_opened -and
    -not [bool]$adoptedClaims.release_authority
) "Artifact-complete cold qualification adoption changed."

$fullColdClaims = $fullColdQualification.adequacy_and_claim_boundary
Assert-R24D3 (
    [string]$fullColdQualification.schema_version -ceq
        "sporespore_qsdk_r24d3_post_adoption_full_cold_conformance_qualification_v1" -and
    [string]$fullColdQualification.status -ceq
        "qualified_exact_adoption_source_full_cold_conformance_characterization_withheld" -and
    [string]$fullColdQualification.qualified_source.commit -ceq
        "e0626fad670e74f1f6b195eb771892e7de054624" -and
    [string]$fullColdQualification.canonical_full_cold_conformance.receipt_raw_sha256 -ceq
        "sha256:1ab1342391ceaf972500b2221781ce52d2e266cf52ddb0c863f02c52c6c46157" -and
    [int]$fullColdQualification.canonical_full_cold_conformance.stage_count -eq 8 -and
    -not [bool]$fullColdQualification.canonical_full_cold_conformance.result_reused -and
    [bool]$fullColdClaims.post_adoption_full_cold_conformance_prerequisite_satisfied -and
    -not [bool]$fullColdClaims.instrumented_godot_capability_promoted -and
    -not [bool]$fullColdClaims.new_physical_campaign_executed -and
    -not [bool]$fullColdClaims.release_authority
) "Post-adoption full-cold conformance qualification changed."

$releaseR24 = @(
    $release.gates | Where-Object { [string]$_.gate_id -ceq "QSDK-R24" }
)
Assert-R24D3 ($releaseR24.Count -eq 1) (
    "Release contract must contain exactly one QSDK-R24 gate."
)
$releaseR24Boundary = $releaseR24[0].proof.active_zero_world_boundary
$releaseR24D3 = $releaseR24Boundary.instrumented_godot_motor_telemetry_source_boundary
$matrixR24Boundary = $support.locomotion_modes.canonical_prone_to_standing_design
$matrixR24D3 = $matrixR24Boundary.instrumented_godot_motor_telemetry_source_boundary
Assert-R24D3 (
    [string]$releaseR24[0].proof.kind -ceq "missing" -and
    [string]$releaseR24D3.gate_id -ceq "QSDK-R24D3" -and
    [string]$releaseR24D3.status -ceq
        "artifact_complete_cold_build_and_post_adoption_full_conformance_qualified_characterization_withheld" -and
    [string]$releaseR24D3.patch_raw_sha256 -ceq "sha256:$expectedPatchHash" -and
    [int]$releaseR24D3.stock_godot_supported_channel_count -eq 8 -and
    [int]$releaseR24D3.instrumented_source_field_count -eq 10 -and
    [int]$releaseR24D3.cold_build_attempt_count -eq 2 -and
    [string]$releaseR24D3.incomplete_cold_build_receipt_schema -ceq
        [string]$predecessor.receipt_schema -and
    [string]$releaseR24D3.incomplete_cold_build_source_commit -ceq
        [string]$predecessor.source_commit -and
    [string]$releaseR24D3.incomplete_cold_build_receipt_raw_sha256 -ceq
        [string]$predecessor.receipt_raw_sha256 -and
    -not [bool]$releaseR24D3.incomplete_cold_build_artifact_retention_adequate -and
    -not [bool]$releaseR24D3.artifact_complete_successor_required -and
    [bool]$releaseR24D3.artifact_complete_successor_observed -and
    [string]$releaseR24D3.artifact_complete_successor_receipt_schema -ceq
        [string]$successorReceipt.schema_version -and
    [int]$releaseR24D3.required_retained_binary_count -eq 2 -and
    [string]$releaseR24D3.artifact_complete_receipt_raw_sha256 -ceq
        [string]$adoption.retained_evidence.receipt_raw_sha256 -and
    [string]$releaseR24D3.artifact_complete_engine_binary_raw_sha256 -ceq
        [string]$adoption.retained_evidence.engine_binary_raw_sha256 -and
    [int]$releaseR24D3.retained_binary_count -eq 2 -and
    [bool]$releaseR24D3.artifact_complete_binary_pair_retained -and
    [bool]$releaseR24D3.execution_used_retained_binary_pair -and
    [bool]$releaseR24D3.clean_pushed_cold_build_qualified -and
    [bool]$releaseR24D3.post_adoption_full_cold_conformance_qualified -and
    [string]$releaseR24D3.post_adoption_full_cold_source_commit -ceq
        [string]$fullColdQualification.qualified_source.commit -and
    [string]$releaseR24D3.post_adoption_full_cold_receipt_raw_sha256 -ceq
        [string]$fullColdQualification.canonical_full_cold_conformance.receipt_raw_sha256 -and
    [string]$releaseR24D3.post_adoption_full_cold_attestation_raw_sha256 -ceq
        [string]$fullColdQualification.durable_attestation.raw_sha256 -and
    [int]$releaseR24D3.post_adoption_full_cold_stage_count -eq 8 -and
    -not [bool]$releaseR24D3.reproducible_build_claimed -and
    -not [bool]$releaseR24D3.result_reuse_authority -and
    -not [bool]$releaseR24D3.stock_godot_capability_promoted -and
    -not [bool]$releaseR24D3.instrumented_godot_capability_promoted -and
    -not [bool]$releaseR24D3.native_capability_conjunction_complete -and
    [int]$releaseR24D3.world_build_count -eq 0 -and
    -not [bool]$releaseR24D3.q_sdk_r24_satisfied -and
    -not [bool]$releaseR24D3.release_authority -and
    (($releaseR24D3 | ConvertTo-Json -Depth 30 -Compress) -ceq
        ($matrixR24D3 | ConvertTo-Json -Depth 30 -Compress))
) "Release and support-matrix R24D3 boundaries changed or diverged."

$expectedManifestPaths = @(
    ".gitattributes",
    "sdk/closure_evidence_provenance_contract.json",
    "tests/test_closure_evidence_provenance_contract.ps1",
    "sdk/adapters/godot/engine_patches/README.md",
    "sdk/adapters/godot/engine_patches/godot_4_7_jolt_motor_telemetry.patch",
    "sdk/recovery/r24d3_godot_jolt_motor_telemetry_source_v1.json",
    "sdk/recovery/r24d3_godot_jolt_motor_telemetry_artifact_complete_successor_v2.json",
    "sdk/recovery/r24d3_godot_jolt_motor_telemetry_cold_qualification_adoption_v2.json",
    "tests/test_qsdk_r24d3_godot_jolt_motor_telemetry_cold_qualification_adoption.ps1",
    "sdk/recovery/r24d3_godot_jolt_motor_telemetry_post_adoption_full_cold_conformance_qualification_v1.json",
    "tests/test_qsdk_r24d3_godot_jolt_motor_telemetry_post_adoption_full_cold_conformance_qualification.ps1",
    "tests/test_qsdk_r24d3_godot_jolt_motor_telemetry_source.ps1",
    "sdk/run_qsdk_r24d3_instrumented_zero_world_gate.ps1",
    "tests/test_sdk_qsdk_r24d3_godot_jolt_motor_telemetry_binding_zero_world.gd"
)
$manifestBindings = @($manifest.source_bindings)
$manifestPaths = @($manifestBindings | ForEach-Object { [string]$_.path })
Assert-R24D3 (
    [string]$manifest.schema_version -ceq
        "sporespore_qsdk_r24d3_source_validation_manifest_v1" -and
    [string]$manifest.gate_id -ceq "QSDK-R24D3" -and
    [string]$manifest.godot_source_commit -ceq $expectedGodotCommit -and
    [string]$manifest.godot_patch_raw_sha256 -ceq "sha256:$expectedPatchHash" -and
    [int]$manifest.source_binding_count -eq $expectedManifestPaths.Count -and
    $manifestBindings.Count -eq $expectedManifestPaths.Count -and
    ($manifestPaths -join "|") -ceq ($expectedManifestPaths -join "|") -and
    -not [bool]$manifest.includes_self -and
    [int]$manifest.world_build_count -eq 0 -and
    [int]$manifest.solver_step_count -eq 0 -and
    -not [bool]$manifest.physical_acceptance_authority -and
    -not [bool]$manifest.release_authority
) "Validation manifest identity or source inventory changed."
foreach ($binding in $manifestBindings) {
    $relativePath = [string]$binding.path
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-R24D3 (Test-Path -LiteralPath $absolutePath -PathType Leaf) (
        "Manifest source is missing: $relativePath"
    )
    $bytes = [IO.File]::ReadAllBytes($absolutePath)
    Assert-R24D3 (
        [string]$binding.raw_sha256 -ceq
            "sha256:$(Get-RawSha256 $absolutePath)" -and
        [int64]$binding.byte_length -eq $bytes.LongLength
    ) "Manifest source binding drifted: $relativePath"
}

$requiredBindingMarkers = @(
    'const METHOD_NAME := &"hinge_joint_get_motor_telemetry"',
    'const RECEIPT_SCHEMA := "sporespore.godot_jolt_hinge_motor_telemetry.v1"',
    "RECEIPT_FIELDS.size() == 11",
    "invalid_readback == null",
    "Performance.PHYSICS_3D_ACTIVE_OBJECTS",
    "world_build_count=0 solver_step_count=0"
)
foreach ($marker in $requiredBindingMarkers) {
    Assert-R24D3 ($bindingTestText.Contains($marker, [StringComparison]::Ordinal)) (
        "Binding zero-world probe is missing: $marker"
    )
}
foreach ($rule in @(
    "sdk/recovery/r24d3_* text eol=lf",
    "sdk/run_qsdk_r24d3_* text eol=lf",
    "sdk/adapters/godot/engine_patches/* text eol=lf",
    "sdk/adapters/godot/engine_patches/*.patch whitespace=-blank-at-eol,-blank-at-eof,-space-before-tab",
    "tests/test_qsdk_r24d3_* text eol=lf",
    "tests/test_sdk_qsdk_r24d3_* text eol=lf"
)) {
    Assert-R24D3 ($attributesText.Contains($rule, [StringComparison]::Ordinal)) (
        "Prospective LF rule is missing: $rule"
    )
}

Assert-R24D3 (Test-R24D3ArtifactCompleteRunner $runnerText) (
    "Artifact-complete runner semantics changed."
)
$runnerMutationCases = [ordered]@{
    receipt_v1_substitution_rejected = @(
        "sporespore_qsdk_r24d3_instrumented_zero_world_gate_receipt_v2",
        "sporespore_qsdk_r24d3_instrumented_zero_world_gate_receipt_v1"
    )
    single_binary_retention_rejected = @(
        "retained_binary_count = 2",
        "retained_binary_count = 1"
    )
    source_console_execution_after_retention_rejected = @(
        '-FileName $retainedConsolePath',
        '-FileName $godotConsoleSourcePath'
    )
    console_source_to_retained_hash_equality_omission_rejected = @(
        '$retainedConsoleHash -ceq $consoleSourceHash',
        '$retainedConsoleHash -cne $consoleSourceHash'
    )
    engine_source_to_retained_hash_equality_omission_rejected = @(
        '$retainedEngineHash -ceq $engineSourceHash',
        '$retainedEngineHash -cne $engineSourceHash'
    )
    post_binding_retained_pair_stability_omission_rejected = @(
        '$postBindingEngineHash -ceq $retainedEngineHash',
        '$postBindingEngineHash -cne $retainedEngineHash'
    )
}
Assert-R24D3 ($runnerMutationCases.Count -eq 6) (
    "Artifact-retention mutation inventory changed."
)
Assert-R24D3 (
    (@($runnerMutationCases.Keys) -join "|") -ceq
        (@($successor.runner_negative_controls.required_rejections) -join "|")
) "Artifact-retention mutation names diverged from the successor contract."
foreach ($entry in $runnerMutationCases.GetEnumerator()) {
    $from = [string]$entry.Value[0]
    $to = [string]$entry.Value[1]
    Assert-R24D3 ($runnerText.Contains($from, [StringComparison]::Ordinal)) (
        "Runner mutation source marker is absent: $($entry.Key)"
    )
    $mutatedRunner = $runnerText.Replace(
        $from,
        $to,
        [StringComparison]::Ordinal
    )
    Assert-R24D3 (-not (Test-R24D3ArtifactCompleteRunner $mutatedRunner)) (
        "Runner mutation was not rejected: $($entry.Key)"
    )
}

$mutationCases = [ordered]@{
    configured_limit_substitution_rejected = @(
        "r_telemetry.signed_motor_impulse_nms = constraint->GetTotalLambdaMotor();",
        "r_telemetry.signed_motor_impulse_nms = motor_max_torque;"
    )
    aggregate_reaction_substitution_rejected = @(
        "r_telemetry.signed_motor_impulse_nms = constraint->GetTotalLambdaMotor();",
        "r_telemetry.signed_motor_impulse_nms = get_applied_force();"
    )
    endpoint_only_work_substitution_rejected = @(
        "AccumulateMotorWork(motor_lambda_after - motor_lambda_before, motor_velocity_before, motor_velocity_after);",
        "// Work estimated only from outer step endpoints."
    )
    warm_start_omission_rejected = @(
        "AccumulateMotorWork(mMotorConstraintPart.GetTotalLambda(), motor_velocity_before, motor_velocity_after);",
        "// Warm-start work omitted."
    )
    iterative_delta_lambda_omission_rejected = @(
        "float motor_lambda_before = mMotorConstraintPart.GetTotalLambda();",
        "float motor_lambda_before = 0.0f;"
    )
    positive_absorbed_cancellation_rejected = @(
        "mAbsorbedMotorWork -= work;",
        "mPositiveMotorWork += work;"
    )
    work_sign_mutation_rejected = @(
        "return mA1.Dot(mBody2->GetAngularVelocity() - mBody1->GetAngularVelocity());",
        "return mA1.Dot(mBody1->GetAngularVelocity() - mBody2->GetAngularVelocity());"
    )
    invalid_rid_zero_synthesis_rejected = @(
        "joint == nullptr || joint->get_type() != JOINT_TYPE_HINGE",
        "joint != nullptr && joint->get_type() == JOINT_TYPE_HINGE"
    )
    stepping_read_allowed_mutation_rejected = @(
        "space == nullptr || space->is_stepping()",
        "space == nullptr && space->is_stepping()"
    )
    fixed_joint_substitution_allowed_mutation_rejected = @(
        "if (unlikely(_is_fixed()) || jolt_ref == nullptr)",
        "if (jolt_ref == nullptr)"
    )
    unsequenced_receipt_mutation_rejected = @(
        "if (sequence == 0 || solver_step_s <= 0.0f)",
        "if (solver_step_s < 0.0f)"
    )
    receipt_schema_mutation_rejected = @(
        'sporespore.godot_jolt_hinge_motor_telemetry.v1',
        'sporespore.godot_jolt_hinge_motor_telemetry.v2'
    )
}
Assert-R24D3 ($mutationCases.Count -eq 12) "Mutation inventory changed."
foreach ($entry in $mutationCases.GetEnumerator()) {
    $from = [string]$entry.Value[0]
    $to = [string]$entry.Value[1]
    Assert-R24D3 ($patchText.Contains($from, [StringComparison]::Ordinal)) (
        "Mutation source marker is absent: $($entry.Key)"
    )
    $mutated = $patchText.Replace($from, $to, [StringComparison]::Ordinal)
    Assert-R24D3 (-not (Test-R24D3PatchSemantics $mutated)) (
        "Mutation was not rejected: $($entry.Key)"
    )
}

function Get-WorkSplit {
    param(
        [double]$Impulse,
        [double]$RateBefore,
        [double]$RateAfter
    )
    $work = $Impulse * 0.5 * ($RateBefore + $RateAfter)
    return [ordered]@{
        positive = if ($work -ge 0.0) { $work } else { 0.0 }
        absorbed = if ($work -lt 0.0) { -$work } else { 0.0 }
    }
}

$supplied = Get-WorkSplit -Impulse 2.0 -RateBefore 1.0 -RateAfter 3.0
$absorbed = Get-WorkSplit -Impulse -2.0 -RateBefore 3.0 -RateAfter 1.0
Assert-R24D3 (
    [double]$supplied.positive -eq 4.0 -and
    [double]$supplied.absorbed -eq 0.0 -and
    [double]$absorbed.positive -eq 0.0 -and
    [double]$absorbed.absorbed -eq 4.0 -and
    ([double]$supplied.positive - [double]$absorbed.absorbed) -eq 0.0 -and
    ([double]$supplied.positive + [double]$absorbed.absorbed) -eq 8.0
) "Positive/absorbed work canary changed or cancellation hid activity."

$externalSourceVerified = $false
if (-not [string]::IsNullOrWhiteSpace($GodotSourceRoot)) {
    $godotRoot = [IO.Path]::GetFullPath($GodotSourceRoot)
    $observedGodotRoot = Get-GitValue `
        -Root $godotRoot `
        -Arguments @("rev-parse", "--show-toplevel")
    $godotRemote = Get-GitValue `
        -Root $godotRoot `
        -Arguments @("remote", "get-url", "origin")
    $godotHead = Get-GitValue `
        -Root $godotRoot `
        -Arguments @("rev-parse", "HEAD")
    Assert-R24D3 ([IO.Path]::GetFullPath($observedGodotRoot) -ceq $godotRoot) (
        "Godot source root changed: $observedGodotRoot"
    )
    Assert-R24D3 ($godotRemote -ceq $expectedGodotRemote) (
        "Godot origin changed: $godotRemote"
    )
    Assert-R24D3 ($godotHead -ceq $expectedGodotCommit) (
        "Godot source commit changed: $godotHead"
    )

    $statusLines = @(
        & git -C $godotRoot status --short 2>&1 |
            ForEach-Object { ([string]$_).Substring(3).Replace("\", "/") }
    )
    Assert-R24D3 ($LASTEXITCODE -eq 0) "Could not inspect Godot source status."
    Assert-R24D3 (
        (@($statusLines | Sort-Object) -join "|") -ceq
            (@($expectedPatchedPaths | Sort-Object) -join "|")
    ) "Godot source contains unexpected or missing changes."

    $externalDiffLines = @(
        & git -C $godotRoot diff --no-ext-diff -- @expectedPatchedPaths 2>&1
    )
    Assert-R24D3 ($LASTEXITCODE -eq 0) "Could not read exact Godot source diff."
    $externalDiff = Normalize-Lf (($externalDiffLines -join "`n") + "`n")
    $normalizedPatch = (Normalize-Lf $patchText).TrimEnd("`n") + "`n"
    Assert-R24D3 ($externalDiff -ceq $normalizedPatch) (
        "Godot source diff does not exactly equal the durable patch."
    )

    $reverseOutput = @(
        & git -C $godotRoot apply --reverse --check --whitespace=error-all $patchPath 2>&1
    )
    Assert-R24D3 ($LASTEXITCODE -eq 0) (
        "Durable patch does not reverse-apply cleanly: $($reverseOutput -join ' | ')"
    )
    $externalSourceVerified = $true
}

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r24d3_source_audit_receipt_v1"
    ok = $true
    gate_id = "QSDK-R24D3"
    question_class = "non_physical_source_conformance"
    result = "source_selected_compile_proved_characterization_withheld"
    patch_sha256 = "sha256:$patchHash"
    patched_file_count = 7
    receipt_field_count = 11
    declared_negative_control_count = 12
    rejected_mutation_count = 12
    artifact_retention_negative_control_count = 6
    artifact_retention_negative_controls_passed = 6
    artifact_complete_successor_declared = $true
    artifact_complete_cold_qualification_adopted = $true
    clean_pushed_cold_build_qualified = $true
    post_adoption_full_cold_conformance_qualified = $true
    reproducible_build_claimed = $false
    result_reuse_authority = $false
    algebraic_canary_count = 2
    external_pinned_source_verified = $externalSourceVerified
    stock_godot_supported_channel_count = 8
    stock_godot_required_channel_count = 10
    instrumented_source_field_count = 10
    instrumented_capability_promoted = $false
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    solver_step_count = 0
    physical_question_opened = $false
    prone_to_standing_claimed = $false
    cross_engine_equivalence_claimed = $false
    physical_acceptance_authority = $false
    release_authority = $false
}
Write-Output (
    "QSDK_R24D3_GODOT_JOLT_MOTOR_TELEMETRY_SOURCE_PASS " +
    ($receipt | ConvertTo-Json -Depth 20 -Compress)
)

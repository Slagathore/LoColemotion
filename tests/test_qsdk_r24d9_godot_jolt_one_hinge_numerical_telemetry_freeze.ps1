#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Python = "python",
    [string]$GodotSourceRoot = (
        "C:\Users\Cole\CodeStuff\dependencies\godot-sporespore-4.7"
    ),
    [switch]$AllowProspectiveUncommitted
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$godotRoot = [IO.Path]::GetFullPath($GodotSourceRoot)
$expectedRepoRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$expectedGodotRoot = "C:\Users\Cole\CodeStuff\dependencies\godot-sporespore-4.7"
$expectedGodotRemote = "https://github.com/godotengine/godot.git"
$expectedGodotCommit = "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"
$expectedPatchHash = (
    "9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c"
)
$contractRelative = (
    "sdk/recovery/" +
    "r24d9_godot_jolt_one_hinge_numerical_telemetry_" +
    "characterization_preregistration_v1.json"
)
$manifestRelative = (
    "sdk/recovery/" +
    "r24d9_godot_jolt_one_hinge_numerical_telemetry_validation_manifest.json"
)
$patchRelative = (
    "sdk/adapters/godot/engine_patches/" +
    "godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch"
)
$rigRelative = (
    "scripts/lab/rigs/" +
    "r24d9_godot_jolt_one_hinge_numerical_telemetry_rig.gd"
)
$workerRelative = (
    "tests/" +
    "test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_worker.gd"
)
$evaluatorRelative = (
    "sdk/recovery/" +
    "r24d9_godot_jolt_one_hinge_numerical_telemetry_" +
    "characterization_evaluator.py"
)
$supervisorRelative = (
    "sdk/run_qsdk_r24d9_one_hinge_numerical_telemetry_characterization.ps1"
)
$auditRelative = (
    "tests/test_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_freeze.ps1"
)
$declarationAuditRelative = "tests/test_qsdk_r24d9_numerical_telemetry_preregistration.ps1"
$precommitDiagnosticsRelative = (
    "sdk/recovery/r24d9_precommit_zero_world_diagnostics_v1.json"
)
$parentClosureRelative = (
    "sdk/recovery/" +
    "r24d8_godot_jolt_active_step_snapshot_timing_positive_closure_v1.json"
)
$parentClosureAuditRelative = (
    "tests/test_qsdk_r24d8_active_step_snapshot_timing_positive_closure.ps1"
)
$expectedManifestPaths = @(
    ".gitattributes",
    $patchRelative,
    $contractRelative,
    $declarationAuditRelative,
    $precommitDiagnosticsRelative,
    $parentClosureRelative,
    $parentClosureAuditRelative,
    $rigRelative,
    $workerRelative,
    $evaluatorRelative,
    $supervisorRelative,
    $auditRelative,
    "sdk/locomotion_operation_lock.ps1",
    "sdk/godot_receipt_terminated_process.ps1",
    "sdk/content_addressed_artifact_store.ps1"
)
$expectedPatchedPaths = @(
    "modules/jolt_physics/joints/jolt_hinge_joint_3d.cpp",
    "modules/jolt_physics/joints/jolt_hinge_joint_3d.h",
    "modules/jolt_physics/joints/jolt_joint_3d.h",
    "modules/jolt_physics/jolt_physics_server_3d.cpp",
    "modules/jolt_physics/jolt_physics_server_3d.h",
    "modules/jolt_physics/register_types.cpp",
    "modules/jolt_physics/spaces/jolt_space_3d.cpp",
    "modules/jolt_physics/spaces/jolt_space_3d.h",
    "thirdparty/jolt_physics/Jolt/Physics/Constraints/HingeConstraint.cpp",
    "thirdparty/jolt_physics/Jolt/Physics/Constraints/HingeConstraint.h"
)

function Assert-R24D9 {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) { throw "QSDK-R24D9 freeze: $Code" }
}

function Get-R24D9Path {
    param([Parameter(Mandatory)][string]$Relative)
    return [IO.Path]::GetFullPath((Join-Path $repoRoot $Relative))
}

function Get-R24D9Sha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).
        Hash.ToLowerInvariant()
}

function Get-R24D9Git {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    $output = @(& git -C $Root @Arguments 2>&1)
    Assert-R24D9 ($LASTEXITCODE -eq 0) (
        "git_$($Arguments -join '_'):$($output -join '|')"
    )
    return ($output -join "`n").Trim()
}

function Test-R24D9ContainsAll {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string[]]$Markers
    )
    foreach ($marker in $Markers) {
        if (-not $Text.Contains($marker, [StringComparison]::Ordinal)) {
            return $false
        }
    }
    return $true
}

function Test-R24D9RigSemantics {
    param([Parameter(Mandatory)][string]$Text)
    $markers = @(
        'class_name R24D9GodotJoltOneHingeNumericalTelemetryRig',
        'const FIXTURE_ID := "QSDK.R24D9.godot_jolt_one_hinge_numerical_telemetry.v1"',
        'const MAXIMUM_PHYSICS_STEP_COUNT := 20',
        'const RETAINED_SAMPLE_COUNT := 68',
        '"cell_id": "drive_positive"',
        '"cell_id": "drive_negative"',
        '"cell_id": "brake_positive"',
        '"cell_id": "brake_negative"',
        '"cell_id": "disabled_positive"',
        '"cell_id": "disabled_negative"',
        '"cell_id": "limit_positive"',
        '"cell_id": "limit_negative"',
        '"cell_id": "sleep_stale"',
        'var child := RigidBody3D.new()',
        'child.angular_velocity = canonical_axis_world(cell) * initial_rate',
        'child.freeze = false',
        'static func force_declared_sleep(cell: Dictionary) -> void:',
        'JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(joint.get_rid())'
    )
    return (
        (Test-R24D9ContainsAll -Text $Text -Markers $markers) -and
        -not $Text.Contains("func _integrate_forces", [StringComparison]::Ordinal) -and
        -not $Text.Contains("ProbeBodyScript", [StringComparison]::Ordinal) -and
        -not $Text.Contains("apply_torque", [StringComparison]::Ordinal) -and
        -not $Text.Contains("apply_impulse", [StringComparison]::Ordinal) -and
        $Text.IndexOf(
            'child.angular_velocity = canonical_axis_world(cell) * initial_rate',
            [StringComparison]::Ordinal
        ) -lt $Text.IndexOf('child.freeze = false', [StringComparison]::Ordinal)
    )
}

function Test-R24D9WorkerSemantics {
    param([Parameter(Mandatory)][string]$Text)
    $markers = @(
        'const ZERO_WORLD_TEMPLATE_PATH := "res://zero_world_template.json"',
        'const TELEMETRY_SCHEMA := "sporespore.godot_jolt_hinge_motor_telemetry.v2"',
        'if mode != "zero_world_preflight" and mode != "physical":',
        'Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)',
        'var pre_sample_physics_frame_count := 0',
        'await physics_frame',
        'var pre_rate_by_id := {}',
        'JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(',
        'RigScript.force_declared_sleep(cell)',
        'PhysicsServer3D.set_active(false)',
        '"pre_activation_initial_angular_velocity_write_count"',
        '"terminal_physics_server_deactivation_count"',
        '"synthetic_shape_only": false',
        '"native_physical_observation": true',
        'QSDK_R24D9_GODOT_SUPERVISOR_TERMINATION_READY'
    )
    return (
        (Test-R24D9ContainsAll -Text $Text -Markers $markers) -and
        -not $Text.Contains("func _integrate_forces", [StringComparison]::Ordinal) -and
        -not $Text.Contains("stepping_probe", [StringComparison]::Ordinal) -and
        -not $Text.Contains("apply_torque", [StringComparison]::Ordinal) -and
        -not $Text.Contains("apply_impulse", [StringComparison]::Ordinal) -and
        $Text.IndexOf('var pre_rate_by_id := {}', [StringComparison]::Ordinal) -lt
            $Text.IndexOf(
                'JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(',
                $Text.IndexOf('var pre_rate_by_id := {}', [StringComparison]::Ordinal),
                [StringComparison]::Ordinal
            )
    )
}

function Test-R24D9SupervisorSemantics {
    param([Parameter(Mandatory)][string]$Text)
    $markers = @(
        '[ValidateSet("ZeroWorld", "Physical")]',
        '[switch]$RunPhysical',
        'Enter-SporeSporeLocomotionOperationLock -Role $lockRole',
        '"ls-remote", "--heads", "origin", "refs/heads/main"',
        '"-m", "SCons", "--clean"',
        '"-m", "SCons"',
        'name = "r24d9_evaluator_self_test"',
        '"--emit-zero-world-template", $templatePath',
        '-WorkerMode "zero_world_preflight"',
        '-EvidenceKind "synthetic_zero_world"',
        'Assert-R24D9Supervisor ($RunPhysical)',
        'status = "consumed_before_worker_launch"',
        '-WorkerMode "physical"',
        '-EvidenceKind "native_physical"',
        'same_source_rerun_allowed = $false',
        'Exit-SporeSporeLocomotionOperationLock -Receipt $operationLock'
    )
    return Test-R24D9ContainsAll -Text $Text -Markers $markers
}

function Test-R24D9PatchSemantics {
    param([Parameter(Mandatory)][string]$Text)
    return Test-R24D9ContainsAll -Text $Text -Markers @(
        'sporespore.godot_jolt_hinge_motor_telemetry.v2',
        'capture_space_step_sequence',
        'read_space_step_sequence',
        'captured_during_active_step',
        'snapshot_is_current_space_step',
        'GetTotalLambdaMotor()',
        'GetPositiveMotorWork()',
        'GetAbsorbedMotorWork()',
        'space->is_stepping()',
        '_capture_joint_telemetry(p_step);'
    )
}

$root = Get-R24D9Git -Root $repoRoot -Arguments @("rev-parse", "--show-toplevel")
$remote = Get-R24D9Git -Root $repoRoot -Arguments @("remote", "get-url", "origin")
Assert-R24D9 ([IO.Path]::GetFullPath($root) -ceq $expectedRepoRoot) "repo_root"
Assert-R24D9 ($repoRoot -ceq $expectedRepoRoot) "script_root"
Assert-R24D9 ($remote -ceq $expectedRemote) "repo_remote"
Assert-R24D9 ($godotRoot -ceq $expectedGodotRoot) "godot_root_substitution"
$godotRepoRoot = Get-R24D9Git -Root $godotRoot -Arguments @(
    "rev-parse", "--show-toplevel"
)
$godotRemote = Get-R24D9Git -Root $godotRoot -Arguments @(
    "remote", "get-url", "origin"
)
$godotHead = Get-R24D9Git -Root $godotRoot -Arguments @("rev-parse", "HEAD")
Assert-R24D9 ([IO.Path]::GetFullPath($godotRepoRoot) -ceq $expectedGodotRoot) (
    "godot_repo_root"
)
Assert-R24D9 ($godotRemote -ceq $expectedGodotRemote) "godot_remote"
Assert-R24D9 ($godotHead -ceq $expectedGodotCommit) "godot_commit"
$godotStatus = @(& git -C $godotRoot status --short 2>&1)
Assert-R24D9 ($LASTEXITCODE -eq 0) "godot_status"
$godotPaths = @($godotStatus | ForEach-Object {
    ([string]$_).Substring(3).Replace("\", "/")
})
Assert-R24D9 (
    (($godotPaths | Sort-Object) -join "|") -ceq
    (($expectedPatchedPaths | Sort-Object) -join "|")
) "godot_patch_path_set"

foreach ($relative in @($expectedManifestPaths + $manifestRelative)) {
    Assert-R24D9 (Test-Path -LiteralPath (Get-R24D9Path $relative) -PathType Leaf) (
        "missing_source:$relative"
    )
}

$contract = Get-Content -Raw -LiteralPath (Get-R24D9Path $contractRelative) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D9 ([string]$contract.gate_id -ceq "QSDK-R24D9") "contract_gate"
Assert-R24D9 ([string]$contract.question_class -ceq "development") (
    "contract_question_class"
)
Assert-R24D9 ([int]$contract.negative_controls.declared_count -eq 46) (
    "contract_negative_count"
)
Assert-R24D9 (
    -not [bool]$contract.physical_authorization.permitted_now -and
    [int]$contract.physical_authorization.same_source_physical_attempt_limit -eq 1 -and
    -not [bool]$contract.physical_authorization.same_source_physical_rerun_allowed
) "contract_physical_boundary"
Assert-R24D9 (
    [int]$contract.fixture_freeze.world_count -eq 1 -and
    [int]$contract.fixture_freeze.isolated_cell_count -eq 9 -and
    [int]$contract.fixture_freeze.maximum_physics_step_count -eq 20 -and
    [int]$contract.fixture_freeze.retained_sample_count -eq 68 -and
    [int]$contract.threshold_margin_cohort_and_population_adequacy.empirical_acceptance_threshold_count -eq 0 -and
    [int]$contract.threshold_margin_cohort_and_population_adequacy.population_claim_count -eq 0
) "contract_finite_design"

$diagnostics = Get-Content -Raw -LiteralPath (
    Get-R24D9Path $precommitDiagnosticsRelative
) | ConvertFrom-Json -AsHashtable -Depth 100
$diagnosticAttempts = @($diagnostics.attempts)
Assert-R24D9 (
    [string]$diagnostics.schema_version -ceq
        "sporespore_qsdk_r24d9_precommit_zero_world_diagnostics_v1" -and
    [string]$diagnostics.record_id -ceq
        "QSDK-R24D9-PRECOMMIT-ZERO-WORLD-DIAGNOSTICS" -and
    [string]$diagnostics.gate_id -ceq "QSDK-R24D9" -and
    [string]$diagnostics.question_class -ceq
        "non_physical_development_diagnostic" -and
    [string]$diagnostics.source_boundary.observed_parent_commit -ceq
        "e5c53367d1d1c37dadabf3c5f9ad23a933a01904" -and
    -not [bool]$diagnostics.source_boundary.source_committed_or_pushed -and
    -not [bool]$diagnostics.source_boundary.independent_r24d9_native_compile_observed -and
    -not [bool]$diagnostics.source_boundary.official_zero_world_qualification -and
    -not [bool]$diagnostics.source_boundary.physical_authorization -and
    $diagnosticAttempts.Count -eq 5
) "precommit_diagnostics_header"
Assert-R24D9 (
    ((@($diagnosticAttempts | ForEach-Object {
        [string]$_.classification
    })) -join "|") -ceq (
        "valid_precommit_worker_template_shape_negative|" +
        "valid_precommit_integral_variant_serialization_negative|" +
        "valid_precommit_real_t_serialization_negative|" +
        "valid_precommit_real_t_literal_restoration_negative|" +
        "complete_local_precommit_toolchain_compatibility_pass"
    )
) "precommit_diagnostics_classification_order"
Assert-R24D9 (
    [string]$diagnosticAttempts[0].failure_code -ceq
        "worker_zero_world_template_shape_or_write_validation" -and
    [string]$diagnosticAttempts[1].failure_code -ceq
        "cell_drive_positive_retained_step_count" -and
    [string]$diagnosticAttempts[2].failure_code -ceq
        "parameter_drive_positive_public_maximum_motor_impulse_nms" -and
    [string]$diagnosticAttempts[3].failure_code -ceq
        "parameter_drive_positive_public_maximum_motor_impulse_nms" -and
    [bool]$diagnosticAttempts[4].worker_receipt_ok -and
    [bool]$diagnosticAttempts[4].template_shape_matches -and
    [bool]$diagnosticAttempts[4].template_identity_matches -and
    [bool]$diagnosticAttempts[4].template_byte_passthrough -and
    [bool]$diagnosticAttempts[4].synthetic_evaluator_passed -and
    -not [bool]$diagnosticAttempts[4].synthetic_hard_cap_count_is_acceptance_gate
) "precommit_diagnostics_outcomes"

$diagnosticRetainedFileCount = 0
foreach ($attempt in $diagnosticAttempts) {
    Assert-R24D9 (
        [int]$attempt.active_physics_object_observation_count -eq 0 -and
        [int]$attempt.world_attempt_count -eq 0 -and
        [int]$attempt.world_build_count -eq 0 -and
        [int]$attempt.solver_step_count -eq 0 -and
        -not [bool]$attempt.official_qualification
    ) "precommit_diagnostics_zero_world:$($attempt.attempt_index)"
    $runRoot = [IO.Path]::GetFullPath([string]$attempt.run_root)
    Assert-R24D9 (Test-Path -LiteralPath $runRoot -PathType Container) (
        "precommit_diagnostics_missing_root:$($attempt.attempt_index)"
    )
    $retainedFiles = @($attempt.retained_files)
    Assert-R24D9 (
        $retainedFiles.Count -eq [int]$attempt.retained_file_count
    ) "precommit_diagnostics_file_count:$($attempt.attempt_index)"
    Assert-R24D9 (
        (@($retainedFiles | ForEach-Object { [string]$_.relative_path } |
            Sort-Object -Unique)).Count -eq $retainedFiles.Count
    ) "precommit_diagnostics_duplicate_file:$($attempt.attempt_index)"
    foreach ($retainedFile in $retainedFiles) {
        $relative = [string]$retainedFile.relative_path
        Assert-R24D9 (-not [IO.Path]::IsPathRooted($relative)) (
            "precommit_diagnostics_absolute_file:$($attempt.attempt_index)"
        )
        $artifactPath = [IO.Path]::GetFullPath((Join-Path $runRoot $relative))
        Assert-R24D9 (
            $artifactPath.StartsWith(
                "$runRoot$([IO.Path]::DirectorySeparatorChar)",
                [StringComparison]::OrdinalIgnoreCase
            ) -and
            (Test-Path -LiteralPath $artifactPath -PathType Leaf)
        ) "precommit_diagnostics_missing_file:$($attempt.attempt_index):$relative"
        Assert-R24D9 (
            [string]$retainedFile.raw_sha256 -ceq
                "sha256:$(Get-R24D9Sha256 $artifactPath)" -and
            [long]$retainedFile.byte_length -eq
                [long](Get-Item -LiteralPath $artifactPath).Length
        ) "precommit_diagnostics_identity:$($attempt.attempt_index):$relative"
        $diagnosticRetainedFileCount += 1
    }
}
Assert-R24D9 (
    [int]$diagnostics.finite_counts.diagnostic_attempt_count -eq 5 -and
    [int]$diagnostics.finite_counts.worker_template_negative_count -eq 1 -and
    [int]$diagnostics.finite_counts.strict_serialization_negative_count -eq 3 -and
    [int]$diagnostics.finite_counts.synthetic_zero_world_compatibility_pass_count -eq 1 -and
    [int]$diagnostics.finite_counts.official_zero_world_qualification_count -eq 0 -and
    [int]$diagnostics.finite_counts.retained_file_count -eq
        $diagnosticRetainedFileCount -and
    $diagnosticRetainedFileCount -eq 40 -and
    [int]$diagnostics.finite_counts.world_attempt_count -eq 0 -and
    [int]$diagnostics.finite_counts.world_build_count -eq 0 -and
    [int]$diagnostics.finite_counts.solver_step_count -eq 0 -and
    [int]$diagnostics.finite_counts.physical_world_count -eq 0 -and
    -not [bool]$diagnostics.claims.complete_zero_world_gate_passed -and
    -not [bool]$diagnostics.claims.native_numerical_telemetry_characterized -and
    -not [bool]$diagnostics.claims.physical_acceptance_authority -and
    -not [bool]$diagnostics.claims.release_authority
) "precommit_diagnostics_finite_counts_and_claims"

$patchPath = Get-R24D9Path $patchRelative
$patchText = [IO.File]::ReadAllText($patchPath).Replace("`r`n", "`n")
Assert-R24D9 ((Get-R24D9Sha256 $patchPath) -ceq $expectedPatchHash) "patch_hash"
Assert-R24D9 (Test-R24D9PatchSemantics $patchText) "patch_semantics"
$rigText = [IO.File]::ReadAllText((Get-R24D9Path $rigRelative)).Replace("`r`n", "`n")
$workerText = [IO.File]::ReadAllText((Get-R24D9Path $workerRelative)).Replace("`r`n", "`n")
$supervisorText = [IO.File]::ReadAllText((Get-R24D9Path $supervisorRelative)).Replace("`r`n", "`n")
Assert-R24D9 (Test-R24D9RigSemantics $rigText) "rig_semantics"
Assert-R24D9 (Test-R24D9WorkerSemantics $workerText) "worker_semantics"
Assert-R24D9 (Test-R24D9SupervisorSemantics $supervisorText) (
    "supervisor_semantics"
)

$sourceMutationPasses = 0
foreach ($case in @(
    @{ family = "rig"; text = $rigText; marker = 'const MAXIMUM_PHYSICS_STEP_COUNT := 20' },
    @{ family = "rig"; text = $rigText; marker = 'const RETAINED_SAMPLE_COUNT := 68' },
    @{ family = "rig"; text = $rigText; marker = 'var child := RigidBody3D.new()' },
    @{ family = "rig"; text = $rigText; marker = '"cell_id": "sleep_stale"' },
    @{ family = "rig"; text = $rigText; marker = 'static func force_declared_sleep(cell: Dictionary) -> void:' },
    @{ family = "worker"; text = $workerText; marker = 'const ZERO_WORLD_TEMPLATE_PATH := "res://zero_world_template.json"' },
    @{ family = "worker"; text = $workerText; marker = 'Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)' },
    @{ family = "worker"; text = $workerText; marker = 'var pre_rate_by_id := {}' },
    @{ family = "worker"; text = $workerText; marker = 'PhysicsServer3D.set_active(false)' },
    @{ family = "worker"; text = $workerText; marker = 'QSDK_R24D9_GODOT_SUPERVISOR_TERMINATION_READY' },
    @{ family = "supervisor"; text = $supervisorText; marker = '[switch]$RunPhysical' },
    @{ family = "supervisor"; text = $supervisorText; marker = 'Enter-SporeSporeLocomotionOperationLock -Role $lockRole' },
    @{ family = "supervisor"; text = $supervisorText; marker = '"ls-remote", "--heads", "origin", "refs/heads/main"' },
    @{ family = "supervisor"; text = $supervisorText; marker = '"-m", "SCons", "--clean"' },
    @{ family = "supervisor"; text = $supervisorText; marker = 'status = "consumed_before_worker_launch"' },
    @{ family = "patch"; text = $patchText; marker = 'capture_space_step_sequence' },
    @{ family = "patch"; text = $patchText; marker = 'read_space_step_sequence' },
    @{ family = "patch"; text = $patchText; marker = 'space->is_stepping()' },
    @{ family = "patch"; text = $patchText; marker = 'GetTotalLambdaMotor()' },
    @{ family = "patch"; text = $patchText; marker = '_capture_joint_telemetry(p_step);' }
)) {
    Assert-R24D9 (
        ([string]$case.text).Contains(
            [string]$case.marker,
            [StringComparison]::Ordinal
        )
    ) "mutation_marker_missing:$($case.family):$($case.marker)"
    $mutated = ([string]$case.text).Replace(
        [string]$case.marker,
        "R24D9_MUTATED_MARKER"
    )
    $accepted = switch ([string]$case.family) {
        "rig" { Test-R24D9RigSemantics $mutated }
        "worker" { Test-R24D9WorkerSemantics $mutated }
        "supervisor" { Test-R24D9SupervisorSemantics $mutated }
        "patch" { Test-R24D9PatchSemantics $mutated }
        default { $true }
    }
    Assert-R24D9 (-not $accepted) "source_mutation_accepted:$($case.family)"
    $sourceMutationPasses += 1
}
Assert-R24D9 ($sourceMutationPasses -eq 20) "source_mutation_count"

$pythonOutput = @(
    & $Python (Get-R24D9Path $evaluatorRelative) --self-test 2>&1
)
Assert-R24D9 ($LASTEXITCODE -eq 0) (
    "evaluator_self_test:$($pythonOutput -join '|')"
)
$evaluatorMarkers = @($pythonOutput | Where-Object {
    ([string]$_).StartsWith(
        "QSDK_R24D9_EVALUATOR_SELF_TEST ",
        [StringComparison]::Ordinal
    )
})
Assert-R24D9 ($evaluatorMarkers.Count -eq 1) "evaluator_marker_count"
$evaluatorReceipt = ([string]$evaluatorMarkers[0]).Substring(
    "QSDK_R24D9_EVALUATOR_SELF_TEST ".Length
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D9 (
    [bool]$evaluatorReceipt.ok -and
    [int]$evaluatorReceipt.synthetic_cell_count -eq 9 -and
    [int]$evaluatorReceipt.synthetic_sample_count -eq 68 -and
    [int]$evaluatorReceipt.declared_negative_control_count -eq 46 -and
    [int]$evaluatorReceipt.rejected_negative_control_count -eq 46 -and
    [int]$evaluatorReceipt.accepted_descriptive_outcome_mutation_count -eq 3 -and
    [int]$evaluatorReceipt.empirical_acceptance_threshold_count -eq 0 -and
    [int]$evaluatorReceipt.world_attempt_count -eq 0 -and
    [int]$evaluatorReceipt.world_build_count -eq 0 -and
    [int]$evaluatorReceipt.solver_step_count -eq 0 -and
    -not [bool]$evaluatorReceipt.physical_acceptance_authority -and
    -not [bool]$evaluatorReceipt.release_authority
) "evaluator_receipt"
$declaredNames = @($contract.negative_controls.required_rejections)
$rejectedNames = @($evaluatorReceipt.rejected_negative_controls)
Assert-R24D9 (($declaredNames -join "|") -ceq ($rejectedNames -join "|")) (
    "declared_evaluator_negative_identity"
)

foreach ($scriptRelative in @($supervisorRelative, $auditRelative)) {
    $parseErrors = $null
    [void][Management.Automation.Language.Parser]::ParseFile(
        (Get-R24D9Path $scriptRelative),
        [ref]$null,
        [ref]$parseErrors
    )
    Assert-R24D9 ($parseErrors.Count -eq 0) (
        "powershell_parse:${scriptRelative}:$($parseErrors -join '|')"
    )
}

$manifest = Get-Content -Raw -LiteralPath (Get-R24D9Path $manifestRelative) |
    ConvertFrom-Json -AsHashtable -Depth 100
$bindings = @($manifest.source_bindings)
Assert-R24D9 (
    [string]$manifest.schema_version -ceq
        "sporespore_qsdk_r24d9_one_hinge_numerical_telemetry_validation_manifest_v1" -and
    [string]$manifest.gate_id -ceq "QSDK-R24D9" -and
    [string]$manifest.question_class -ceq "development" -and
    [string]$manifest.status -ceq
        "prospective_implementation_source_bytes_bound_zero_world_pending" -and
    [string]$manifest.godot_source_commit -ceq $expectedGodotCommit -and
    [string]$manifest.combined_patch_raw_sha256 -ceq "sha256:$expectedPatchHash" -and
    [int]$manifest.declared_evaluator_negative_control_count -eq 46 -and
    [int]$manifest.source_binding_count -eq $expectedManifestPaths.Count -and
    $bindings.Count -eq $expectedManifestPaths.Count -and
    -not [bool]$manifest.includes_self -and
    [int]$manifest.official_zero_world_qualification_count -eq 0 -and
    [int]$manifest.world_attempt_count -eq 0 -and
    [int]$manifest.world_build_count -eq 0 -and
    [int]$manifest.solver_step_count -eq 0 -and
    -not [bool]$manifest.physical_characterization_executed -and
    -not [bool]$manifest.physical_acceptance_authority -and
    -not [bool]$manifest.release_authority
) "manifest_header"
Assert-R24D9 (
    ((@($bindings | ForEach-Object { [string]$_.path })) -join "|") -ceq
    ($expectedManifestPaths -join "|")
) "manifest_path_order"

$head = Get-R24D9Git -Root $repoRoot -Arguments @("rev-parse", "HEAD")
foreach ($binding in $bindings) {
    $relative = [string]$binding.path
    $path = Get-R24D9Path $relative
    $digest = Get-R24D9Sha256 $path
    $length = (Get-Item -LiteralPath $path).Length
    $workingBlob = Get-R24D9Git -Root $repoRoot -Arguments @("hash-object", $path)
    Assert-R24D9 (
        [string]$binding.raw_sha256 -ceq "sha256:$digest" -and
        [long]$binding.byte_length -eq [long]$length -and
        [string]$binding.git_blob_oid -ceq $workingBlob
    ) "manifest_binding:$relative"
    if (-not $AllowProspectiveUncommitted) {
        $committedBlob = Get-R24D9Git -Root $repoRoot -Arguments @(
            "rev-parse", "$head`:$relative"
        )
        Assert-R24D9 ($committedBlob -ceq $workingBlob) (
            "manifest_committed_blob:$relative"
        )
    }
}

Write-Output (
    "QSDK_R24D9_NUMERICAL_TELEMETRY_FREEZE_PASS " +
    ([ordered]@{
        ok = $true
        question_class = "development"
        source_binding_count = $bindings.Count
        declared_evaluator_negative_control_count = 46
        rejected_evaluator_negative_control_count = 46
        accepted_descriptive_outcome_mutation_count = 3
        source_mutation_rejection_count = $sourceMutationPasses
        retained_precommit_diagnostic_attempt_count = $diagnosticAttempts.Count
        retained_precommit_diagnostic_file_count = $diagnosticRetainedFileCount
        prospective_uncommitted_mode = [bool]$AllowProspectiveUncommitted
        empirical_acceptance_threshold_count = 0
        superiority_margin_count = 0
        equivalence_or_non_inferiority_margin_count = 0
        held_out_validation_cohort_count = 0
        population_claim_count = 0
        worlds = 0
        builds = 0
        solver_steps = 0
        physical_acceptance_authority = $false
        release_authority = $false
    } | ConvertTo-Json -Compress)
)

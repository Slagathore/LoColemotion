param(
    [string]$Python = "python",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [switch]$SkipGodot
)

$ErrorActionPreference = "Stop"

function Assert-R23D60([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "QSDK-R23D60 preregistration audit failed: $Message"
    }
}

function Get-R23D60Sha256([string]$Path) {
    return "sha256:$((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant())"
}

function Assert-R23D60DoubleEqual($Actual, $Expected, [string]$Label) {
    Assert-R23D60 (
        [BitConverter]::DoubleToInt64Bits([double]$Actual) -eq
        [BitConverter]::DoubleToInt64Bits([double]$Expected)
    ) "$Label changed"
}

function Assert-R23D60VectorEqual($Actual, $Expected, [string]$Label) {
    Assert-R23D60 (@($Actual).Count -eq @($Expected).Count) "$Label length changed"
    for ($index = 0; $index -lt @($Expected).Count; $index++) {
        Assert-R23D60DoubleEqual $Actual[$index] $Expected[$index] (
            "$Label value $index"
        )
    }
}

function Find-R23D60Record($Value) {
    if ($null -eq $Value) { return $null }
    if ($Value -is [Collections.IDictionary]) {
        if ($Value.Contains("prospective_r23d60_held_out_turning_validation")) {
            return $Value["prospective_r23d60_held_out_turning_validation"]
        }
        foreach ($child in $Value.Values) {
            $found = Find-R23D60Record $child
            if ($null -ne $found) { return $found }
        }
        return $null
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($child in $Value) {
            $found = Find-R23D60Record $child
            if ($null -ne $found) { return $found }
        }
    }
    return $null
}

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$expectedRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$r59DeclarationCommit = "63c927a92173aee953effd5a9c26dc5155a68fac"
$r59PhysicalSourceCommit = "22020d397ea4ce952a67051a843c22b388f0f78b"
$designPath = Join-Path $repoRoot (
    "sdk\turning\r23d60_godot_fixture_knee_held_out_turning_validation.py"
)
$declarationPath = Join-Path $repoRoot (
    "sdk\turning\r23d60_godot_fixture_knee_held_out_turning_validation_" +
    "preregistration_v1.json"
)
$seedCompilerPath = Join-Path $repoRoot (
    "sdk\turning\r23d59_seed_fixture_compiler.gd"
)
$r59ClosurePath = Join-Path $repoRoot (
    "sdk\turning\r23d59_godot_knee_source_finite_decision_closure_v1.json"
)
$r59ClosureAuditPath = Join-Path $repoRoot (
    "tests\test_qsdk_r23d59_physical_closure.ps1"
)
$releaseContractPath = Join-Path $repoRoot (
    "sdk\release\quadruped_release_contract.json"
)
$supportMatrixPath = Join-Path $repoRoot (
    "sdk\release\quadruped_support_matrix.json"
)
$workbenchPath = Join-Path $repoRoot "sdk\workbench\experiment_catalog.json"

Assert-R23D60 ($repoRoot.TrimEnd("\") -ceq $expectedRoot) "repository root changed"
Assert-R23D60 (
    (& git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
    $expectedRoot
) "Git top-level changed"
Assert-R23D60 (
    (& git -C $repoRoot remote get-url origin).Trim() -ceq $expectedRemote
) "origin remote changed"
foreach ($path in @(
    $designPath,
    $declarationPath,
    $seedCompilerPath,
    $r59ClosurePath,
    $r59ClosureAuditPath,
    $releaseContractPath,
    $supportMatrixPath,
    $workbenchPath
)) {
    Assert-R23D60 (Test-Path -LiteralPath $path -PathType Leaf) "required file missing: $path"
}

$attributes = Get-Content -Raw -LiteralPath (Join-Path $repoRoot ".gitattributes")
foreach ($rule in @(
    "sdk/turning/r23d60_* text eol=lf",
    "sdk/run_qsdk_r23d60_* text eol=lf",
    "tests/test_qsdk_r23d60_* text eol=lf",
    "tests/test_sdk_qsdk_r23d60_* text eol=lf"
)) {
    Assert-R23D60 ($attributes.Contains($rule)) "missing byte-stable rule: $rule"
}

$declaration = Get-Content -Raw -LiteralPath $declarationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$r59Closure = Get-Content -Raw -LiteralPath $r59ClosurePath |
    ConvertFrom-Json -AsHashtable -Depth 100

Assert-R23D60 (
    [string]$declaration.campaign_id -ceq
        "QSDK-R23D60-GODOT-KNEE-SOURCE-FROZEN-PROFILE-HELD-OUT-TURNING-VALIDATION" -and
    [string]$declaration.gate_id -ceq "QSDK-R23D60" -and
    [string]$declaration.question_class -ceq "finite_decision" -and
    [bool]$declaration.physical_question_declared -and
    -not [bool]$declaration.physical_campaign_opened
) "campaign identity or finite-decision classification changed"

Assert-R23D60 (
    [string]$r59Closure.status -ceq
        "closed_consumed_valid_complete_fixture_knee_profile_selected_r23d59_finite_decision" -and
    [string]$r59Closure.source_commit -ceq $r59PhysicalSourceCommit -and
    [bool]$r59Closure.identity_consumed -and
    -not [bool]$r59Closure.same_identity_rerun_allowed -and
    -not [bool]$r59Closure.reserved_r23d60_seed_consumed -and
    [bool]$r59Closure.claims.r23d59_all_six_cells_execution_valid -and
    [bool]$r59Closure.claims.r23d59_complete_dependency_inventory_proved -and
    [bool]$r59Closure.claims.r23d60_preregistration_permitted -and
    -not [bool]$r59Closure.claims.r23d60_campaign_opened
) "R23D59 closure permission or consumed boundary changed"
Assert-R23D60 (
    [string]$r59Closure.official_result.selected_profile_id -ceq
        "portable_hip__fixture_knee" -and
    [bool]$r59Closure.official_result.matrix_execution_valid -and
    [bool]$r59Closure.official_result.portable_hip_fixture_knee_profile_adequate -and
    -not [bool]$r59Closure.official_result.portable_hip_portable_knee_profile_adequate -and
    [bool]$r59Closure.bounded_interpretation.selected_profile_binding_for_r23d60_preregistration_authorized -and
    -not [bool]$r59Closure.bounded_interpretation.r23d59_cells_may_count_as_r23d60_held_out_worlds
) "R23D59 selected-profile binding changed"

$matrix = $declaration.frozen_matrix
Assert-R23D60 (
    [int]$matrix.seed -eq 21516 -and
    [string]$declaration.candidate_resolution.selected_profile_id -ceq
        "portable_hip__fixture_knee" -and
    [string]$declaration.candidate_resolution.profile_definition.hip_cap_source -ceq
        "portable_compiled_morphology" -and
    [string]$declaration.candidate_resolution.profile_definition.knee_cap_source -ceq
        "fixture_realized_prebinding" -and
    @($matrix.cells).Count -eq 3 -and
    [int]$matrix.declared_cell_count -eq 3 -and
    [int]$matrix.declared_world_count -eq 3 -and
    (@($matrix.ordered_arm_ids) -join ",") -ceq
        "reference_zero,positive_heading,negative_heading" -and
    [int]$matrix.turn_start_step -eq 600 -and
    [int]$matrix.turn_end_step_exclusive -eq 1800 -and
    [int]$matrix.recovery_duration_steps -eq 600 -and
    [bool]$matrix.serial_execution_required -and
    [bool]$matrix.fresh_world_required_per_arm -and
    [bool]$matrix.all_cells_run_regardless_of_intermediate_outcome
) "held-out matrix changed"
foreach ($pair in @(
    @($matrix.ordered_heading_offsets_rad[0], 0.0),
    @($matrix.ordered_heading_offsets_rad[1], 0.2),
    @($matrix.ordered_heading_offsets_rad[2], -0.2)
)) {
    Assert-R23D60DoubleEqual $pair[0] $pair[1] "ordered heading offset"
}
Assert-R23D60DoubleEqual (
    $declaration.cycle_integrated_measurement.minimum_raw_signed_cycle_shift_rad
) 0.01 "raw signed cycle-shift floor"
Assert-R23D60DoubleEqual (
    $declaration.cycle_integrated_measurement.minimum_reference_conditioned_cycle_shift_rad
) 0.01 "reference-conditioned cycle-shift floor"
Assert-R23D60 (
    [double]$declaration.frozen_common_physical_gates.minimum_final_forward_displacement_m -eq
        [double]$r59Closure.threshold_margin_and_cohort_provenance.minimum_final_forward_displacement_m -and
    [double]$declaration.frozen_common_physical_gates.maximum_tilt_rad -eq
        [double]$r59Closure.threshold_margin_and_cohort_provenance.maximum_tilt_rad -and
    [double]$declaration.frozen_common_physical_gates.minimum_torso_height_m -eq
        [double]$r59Closure.threshold_margin_and_cohort_provenance.minimum_torso_height_m -and
    [int]$declaration.frozen_common_physical_gates.minimum_contact_cycles_per_limb -eq 2 -and
    [int]$declaration.frozen_common_physical_gates.exact_controller_semantic_step_count -eq 2992 -and
    [int]$declaration.frozen_common_physical_gates.exact_validated_portable_command_count -eq 23936 -and
    [int]$declaration.frozen_common_physical_gates.exact_native_actuation_application_count -eq 23936
) "unchanged common physical gates changed"

$trueClaims = @(
    $declaration.claims.GetEnumerator() |
        Where-Object { [bool]$_.Value } |
        ForEach-Object { [string]$_.Key }
)
Assert-R23D60 (
    $trueClaims.Count -eq 1 -and
    $trueClaims[0] -ceq "r23d60_preregistered" -and
    -not [bool]$declaration.implementation_and_execution_requirements.physical_world_may_open_from_this_declaration_alone
) "preregistration-only claim boundary changed"

$parentSeedUses = @(
    & git -C $repoRoot grep -n -E "(^|[^0-9])21516([^0-9]|`$)" `
        "${r59DeclarationCommit}^" -- sdk tests docs 2>$null
)
Assert-R23D60 ($LASTEXITCODE -in @(0, 1)) "parent seed scan failed"
Assert-R23D60 ($parentSeedUses.Count -eq 0) "held-out seed predates its prospective reservation"
$reservedSeedUses = @(
    & git -C $repoRoot grep -n -E "(^|[^0-9])21516([^0-9]|`$)" `
        $r59DeclarationCommit -- sdk tests docs 2>$null
)
Assert-R23D60 ($LASTEXITCODE -eq 0) "reserved seed is absent at the R23D59 declaration"
Assert-R23D60 ($reservedSeedUses.Count -gt 0) "reserved seed has no prospective source record"
& git -C $repoRoot merge-base --is-ancestor $r59DeclarationCommit $r59PhysicalSourceCommit
Assert-R23D60 ($LASTEXITCODE -eq 0) "seed reservation was not ancestral to physical source"
Assert-R23D60 (
    [int]$r59Closure.successor_requirements.r23d60_reserved_seed -eq 21516 -and
    -not [bool]$r59Closure.successor_requirements.r23d60_physical_world_opened_by_this_closure -and
    -not [bool]$r59Closure.successor_requirements.physical_successor_authorized_by_this_closure
) "held-out seed consumption or authorization changed"

$oldNoBytecode = $env:PYTHONDONTWRITEBYTECODE
try {
    $env:PYTHONDONTWRITEBYTECODE = "1"
    $pythonOutput = @(
        & $Python $designPath --declaration $declarationPath 2>&1
    )
    Assert-R23D60 ($LASTEXITCODE -eq 0) "Python declaration audit failed"
} finally {
    if ($null -eq $oldNoBytecode) {
        Remove-Item Env:PYTHONDONTWRITEBYTECODE -ErrorAction SilentlyContinue
    } else {
        $env:PYTHONDONTWRITEBYTECODE = $oldNoBytecode
    }
}
$auditMarker = @($pythonOutput | Where-Object {
    [string]$_ -like "QSDK_R23D60_DECLARATION_PASS *"
})
Assert-R23D60 ($auditMarker.Count -eq 1) "Python audit marker changed"
$audit = ([string]$auditMarker[0]).Substring(
    "QSDK_R23D60_DECLARATION_PASS ".Length
) | ConvertFrom-Json -AsHashtable
Assert-R23D60 (
    [string]$audit.question_class -ceq "finite_decision" -and
    [int]$audit.cell_count -eq 3 -and
    [int]$audit.mutation_rejection_count -eq 20 -and
    [int]$audit.reserved_seed -eq 21516 -and
    [string]$audit.selected_profile_id -ceq "portable_hip__fixture_knee" -and
    [int]$audit.model_construction_count -eq 0 -and
    [int]$audit.world_attempt_count -eq 0 -and
    [int]$audit.world_build_count -eq 0 -and
    -not [bool]$audit.physical_campaign_opened -and
    -not [bool]$audit.godot_jolt_turning -and
    -not [bool]$audit.physical_acceptance_authority
) "Python audit receipt changed"

$compilerText = Get-Content -Raw -LiteralPath $seedCompilerPath
foreach ($forbidden in @(
    "WaveGaitScript.new(",
    ".run(",
    "add_child(",
    "RigidBody3D",
    "StaticBody3D",
    "PackedScene",
    "instantiate(",
    "await "
)) {
    Assert-R23D60 (-not $compilerText.Contains($forbidden)) (
        "seed compiler contains physical construction token: $forbidden"
    )
}

$godotCompilerRun = $false
if (-not $SkipGodot) {
    Assert-R23D60 (Test-Path -LiteralPath $Godot -PathType Leaf) "Godot executable missing"
    $godotOutput = @(
        & $Godot --headless --path $repoRoot --script `
            "res://sdk/turning/r23d59_seed_fixture_compiler.gd" 2>&1
    )
    Assert-R23D60 ($LASTEXITCODE -eq 0) "Godot seed compiler failed"
    $seedMarker = @($godotOutput | Where-Object {
        [string]$_ -like "QSDK_R23D59_SEED_FIXTURES *"
    })
    Assert-R23D60 ($seedMarker.Count -eq 1) "Godot seed fixture marker changed"
    $receipt = ([string]$seedMarker[0]).Substring(
        "QSDK_R23D59_SEED_FIXTURES ".Length
    ) | ConvertFrom-Json -AsHashtable
    $fixtureMatches = @($receipt.fixtures | Where-Object {
        [int]$_.campaign_seed -eq 21516
    })
    Assert-R23D60 (
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        (@($receipt.r23d60_unopened_held_out_seeds) -join ",") -ceq "21516" -and
        $fixtureMatches.Count -eq 1
    ) "Godot seed compiler receipt changed"
    $actual = $fixtureMatches[0]
    $expected = $matrix.initial_perturbation
    foreach ($key in @("fixture_vertical_clearance_m", "fixture_yaw_rad")) {
        Assert-R23D60DoubleEqual $actual[$key] $expected[$key] "compiled $key"
    }
    Assert-R23D60VectorEqual $actual.initial_linear_velocity_world_m_s `
        $expected.initial_linear_velocity_world_m_s "compiled linear velocity"
    Assert-R23D60VectorEqual $actual.initial_torso_angular_velocity_world_rad_s `
        $expected.initial_torso_angular_velocity_world_rad_s "compiled angular velocity"
    Assert-R23D60 (
        [int]$actual.gait_phase_offset_ticks -eq [int]$expected.gait_phase_offset_ticks
    ) "compiled gait phase changed"
    $godotCompilerRun = $true
}

$releaseContract = Get-Content -Raw -LiteralPath $releaseContractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$supportMatrix = Get-Content -Raw -LiteralPath $supportMatrixPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$turningGates = @($releaseContract.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R23"
})
$contractRecord = if ($turningGates.Count -eq 1) {
    $turningGates[0].proof.prospective_r23d60_held_out_turning_validation
} else { $null }
$matrixRecord = Find-R23D60Record $supportMatrix
$designHash = Get-R23D60Sha256 $designPath
$declarationHash = Get-R23D60Sha256 $declarationPath
$auditHash = Get-R23D60Sha256 ([IO.Path]::GetFullPath($PSCommandPath))
Assert-R23D60 (
    $null -ne $contractRecord -and
    $null -ne $matrixRecord -and
    [string]$turningGates[0].proof.kind -ceq "missing" -and
    [string]$turningGates[0].proof.current_prospective_successor_status -ceq
        "r23d60_held_out_turning_validation_complete_zero_world_passed_initial_qualification_failed_provenance_inventory_corrected_fresh_qualification_pending_physical_not_opened" -and
    [string]$contractRecord.status -ceq
        "prospective_complete_zero_world_passed_initial_qualification_failed_provenance_inventory_corrected_fresh_qualification_pending_physical_not_opened" -and
    [string]$matrixRecord.status -ceq [string]$contractRecord.status -and
    [string]$contractRecord.question_class -ceq "finite_decision" -and
    [string]$matrixRecord.question_class -ceq "finite_decision" -and
    [string]$contractRecord.preregistration_raw_sha256 -ceq $declarationHash -and
    [string]$matrixRecord.preregistration_sha256 -ceq $declarationHash -and
    [string]$contractRecord.design_raw_sha256 -ceq $designHash -and
    [string]$matrixRecord.design_sha256 -ceq $designHash -and
    [string]$contractRecord.local_declaration_audit_raw_sha256 -ceq $auditHash -and
    [string]$matrixRecord.local_declaration_audit_sha256 -ceq $auditHash -and
    [int]$contractRecord.reserved_seed -eq 21516 -and
    [int]$matrixRecord.reserved_seed -eq 21516 -and
    [int]$contractRecord.declared_world_count -eq 3 -and
    [int]$matrixRecord.declared_world_count -eq 3 -and
    [int]$contractRecord.local_mutation_rejection_count -eq 20 -and
    [int]$matrixRecord.local_mutation_rejection_count -eq 20 -and
    [bool]$contractRecord.local_declaration_gate_passed -and
    [bool]$matrixRecord.local_declaration_gate_passed -and
    [int]$contractRecord.dependency_inventory_transitive_path_count -eq 136 -and
    [int]$matrixRecord.dependency_inventory_transitive_path_count -eq 136 -and
    [int]$contractRecord.dependency_inventory_edge_count -eq 159 -and
    [int]$matrixRecord.dependency_inventory_edge_count -eq 159 -and
    [string]$contractRecord.dependency_inventory_projection_sha256 -ceq
        "sha256:5f29293d2bdac29661c267a1960b38adc32417809b7634363c6a3d4e9fbeed6e" -and
    [string]$matrixRecord.dependency_inventory_projection_sha256 -ceq
        [string]$contractRecord.dependency_inventory_projection_sha256 -and
    [bool]$contractRecord.dependency_closed_worker_implemented -and
    [bool]$matrixRecord.dependency_closed_worker_implemented -and
    [bool]$contractRecord.dependency_closed_evaluator_implemented -and
    [bool]$matrixRecord.dependency_closed_evaluator_implemented -and
    [bool]$contractRecord.one_shot_supervisor_implemented -and
    [bool]$matrixRecord.one_shot_supervisor_implemented -and
    [int]$contractRecord.campaign_role_count -eq 3 -and
    [int]$matrixRecord.campaign_role_count -eq 3 -and
    [bool]$contractRecord.complete_campaign_zero_world_gate_passed -and
    [bool]$matrixRecord.complete_campaign_zero_world_gate_passed -and
    [string]$contractRecord.initial_qualification.source_commit -ceq
        "66b7ea6d1e37ff1e00252571c9253beffc8a916e" -and
    [string]$matrixRecord.initial_qualification.source_commit -ceq
        [string]$contractRecord.initial_qualification.source_commit -and
    [string]$contractRecord.initial_qualification.failure_gate_id -ceq
        "CAK1-EVIDENCE-PROVENANCE" -and
    [string]$matrixRecord.initial_qualification.failure_gate_id -ceq
        [string]$contractRecord.initial_qualification.failure_gate_id -and
    [int]$contractRecord.initial_qualification.passed_gate_count -eq 3 -and
    [int]$matrixRecord.initial_qualification.passed_gate_count -eq 3 -and
    [int]$contractRecord.initial_qualification.world_build_count -eq 0 -and
    [int]$matrixRecord.initial_qualification.world_build_count -eq 0 -and
    -not [bool]$contractRecord.initial_qualification.reusable -and
    -not [bool]$matrixRecord.initial_qualification.reusable -and
    [bool]$contractRecord.provenance_inventory_corrected -and
    [bool]$matrixRecord.provenance_inventory_corrected -and
    -not [bool]$contractRecord.fresh_scoped_qualification_passed -and
    -not [bool]$matrixRecord.fresh_scoped_qualification_passed -and
    -not [bool]$contractRecord.campaign_attestation_adoption_passed -and
    -not [bool]$matrixRecord.campaign_attestation_adoption_passed -and
    -not [bool]$contractRecord.physical_campaign_opened -and
    -not [bool]$matrixRecord.physical_campaign_opened -and
    [int]$contractRecord.world_build_count -eq 0 -and
    [int]$matrixRecord.world_build_count -eq 0 -and
    [int]$contractRecord.world_attempt_count -eq 0 -and
    [int]$matrixRecord.world_attempt_count -eq 0 -and
    -not [bool]$contractRecord.godot_jolt_turning -and
    -not [bool]$matrixRecord.godot_jolt_turning -and
    -not [bool]$contractRecord.prone_to_standing -and
    -not [bool]$matrixRecord.prone_to_standing -and
    -not [bool]$contractRecord.release_authorized -and
    -not [bool]$matrixRecord.release_authorized -and
    -not [bool]$contractRecord.physical_acceptance_authority -and
    -not [bool]$matrixRecord.physical_acceptance_authority
) "release contract or support-matrix declaration record changed"

$workbench = Get-Content -Raw -LiteralPath $workbenchPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$workbenchRuns = @($workbench.runs | Where-Object {
    [string]$_.id -ceq "qsdk_r23d60_preregistration"
})
Assert-R23D60 (
    $workbenchRuns.Count -eq 1 -and
    [string]$workbenchRuns[0].kind -ceq "zero_world_declaration_gate" -and
    [string]$workbenchRuns[0].world_policy -ceq "zero_world_declaration_only" -and
    [string]$workbenchRuns[0].risk -ceq "safe" -and
    [string]$workbenchRuns[0].runner_path -ceq
        "tests/test_qsdk_r23d60_preregistration.ps1" -and
    (@($workbenchRuns[0].arguments) -join ",") -ceq "-SkipGodot" -and
    @($workbenchRuns[0].proofs).Count -eq 5 -and
    [string]$workbenchRuns[0].proofs[0].expected_sha256 -ceq
        $declarationHash.Substring(7) -and
    [string]$workbenchRuns[0].proofs[1].expected_sha256 -ceq
        $designHash.Substring(7) -and
    [string]$workbenchRuns[0].proofs[2].expected_sha256 -ceq
        $auditHash.Substring(7)
) "Workbench declaration exposure changed"

Write-Output (
    "QSDK_R23D60_PREREGISTRATION_PASS " +
    "question=finite_decision cells=3 seed=21516 " +
    "profile=portable_hip__fixture_knee mutations=20 " +
    "godot_seed_compiler=$godotCompilerRun models=0 worlds=0 " +
    "physical=False turning=False release=False " +
    "design=$(Get-R23D60Sha256 $designPath) " +
    "declaration=$(Get-R23D60Sha256 $declarationPath) " +
    "seed_compiler=$(Get-R23D60Sha256 $seedCompilerPath) " +
    "r59_closure=$(Get-R23D60Sha256 $r59ClosurePath) " +
    "r59_closure_audit=$(Get-R23D60Sha256 $r59ClosureAuditPath)"
)

#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$SkipGodotPreflight,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$implementationParentCommit = "f6667c153679adb8e66c3e95da30e77435a7976e"
$preregistrationPath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw24m_fresh_material_preregistration.json"
$runnerPath = Join-Path (
    $repoRoot
) "sdk\run_balanced_wave_bw24m_material_declaration_preflight.ps1"
$preflightPath = Join-Path (
    $repoRoot
) "tests\test_sdk_balanced_wave_bw24m_material_preflight.gd"
$rigPath = Join-Path (
    $repoRoot
) "scripts\lab\rigs\sdk_bw24m_friction_ladder_sled_rig.gd"
$conformancePath = Join-Path $repoRoot "sdk\run_conformance.ps1"

$boundFiles = [ordered]@{
    "sdk/balanced_wave_bw24m_fresh_material_preregistration.json" =
        "7e622d2ef25cc3d0224e95f21cd00fff3a60ac96c8179e6ccfe36f0043375815"
    "sdk/run_balanced_wave_bw24m_material_declaration_preflight.ps1" =
        "e5376e695e60060c98d63aebae4d01ba39430cd94f20c2c2657283fb25069f38"
    "tests/test_sdk_balanced_wave_bw24m_material_preflight.gd" =
        "bd11397e7062c56232fe29b54c49adf95671bd72281096e92abe9d1af72a07e7"
    "scripts/lab/rigs/sdk_friction_ladder_sled_rig.gd" =
        "bcd40080800669492dbc0633d5aa95ed11461d7ae29756c05e892b3467ccd014"
    "scripts/lab/rigs/sdk_bw24m_friction_ladder_sled_rig.gd" =
        "72170b65a934c47758bdce08e1589ba2e81a7222e1e890554a35c50c1951cf3b"
}

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Assert-SequenceExact {
    param(
        [Parameter(Mandatory)][object[]]$Actual,
        [Parameter(Mandatory)][object[]]$Expected,
        [Parameter(Mandatory)][string]$Label
    )
    Assert-Exact ($Actual.Count -eq $Expected.Count) "$Label count changed"
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        Assert-Exact (
            [string]$Actual[$index] -ceq [string]$Expected[$index]
        ) "$Label order/value changed at index $index"
    }
}

function Assert-SourceContains {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string[]]$Needles,
        [Parameter(Mandatory)][string]$Label
    )
    foreach ($needle in $Needles) {
        Assert-Exact (
            $Source.Contains($needle, [StringComparison]::Ordinal)
        ) "BW24M $Label lost required text: $needle"
    }
}

foreach ($entry in $boundFiles.GetEnumerator()) {
    $path = Join-Path $repoRoot $entry.Key
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 $path) -ceq [string]$entry.Value
    ) "BW24M declaration artifact is missing or changed: $($entry.Key)"
}

& git -C $repoRoot merge-base --is-ancestor $implementationParentCommit HEAD
Assert-Exact (
    $LASTEXITCODE -eq 0
) "BW24M implementation parent is not an ancestor of HEAD"

# Establish exact outcome freshness against the predecessor snapshot. The
# pathspec deliberately covers campaign declarations, runners, and controller
# execution surfaces, while excluding unrelated test literals such as a
# material-profile tamper canary that never opened an outcome.
$freshnessPattern = (
    '(^|[^0-9.])(0\.59|0\.71|0\.83)([^0-9]|$)|' +
    '(^|[^0-9])(26011|26012|26013|26014)([^0-9]|$)'
)
$freshnessMatches = @(
    & git -C $repoRoot grep -n -E $freshnessPattern `
        $implementationParentCommit -- `
        "sdk/balanced_wave_*.json" `
        "sdk/*balanced_wave*.json" `
        "sdk/run_balanced_wave*" `
        "sdk/core/src/*.rs" `
        "tests/test_sdk_balanced_wave*" `
        "scripts/lab/gait/*balanced_wave*" `
        2>$null
)
$freshnessExitCode = $LASTEXITCODE
Assert-Exact (
    $freshnessExitCode -eq 1 -and $freshnessMatches.Count -eq 0
) "BW24M values or seeds were already exposed in the predecessor campaign surface"

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable
$study = $preregistration.study_class
$stages = $preregistration.pipeline_stages
$hostIdentity = $preregistration.host_identity
$reservation = $preregistration.fresh_reservation
$characterization = $preregistration.material_characterization
$future = $preregistration.planned_future_bw25y_development_contract
$stage0 = $preregistration.stage_0_preflight_contract
$stage1 = $preregistration.required_stage_1_freeze_contract
$claims = $preregistration.current_claim_boundary

Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw24m_fresh_material_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "prospective_declaration_preflight_only_physical_execution_blocked" -and
    [string]$preregistration.campaign_id -ceq
        "BW24M-BW23Y-FRESH-MATERIAL-CHARACTERIZATION" -and
    [string]$preregistration.gate_id -ceq "BW24M" -and
    [string]$preregistration.implementation_parent_commit -ceq
        $implementationParentCommit -and
    [string]$study.classification -ceq
        "exact_finite_cell_adapter_material_characterization" -and
    [bool]$study.finite_decision -and
    -not [bool]$study.development_screen -and
    -not [bool]$study.population_inference -and
    [int]$study.expected_physical_world_count_after_complete_freeze -eq 10 -and
    -not [bool]$study.physical_execution_currently_authorized -and
    [string]$hostIdentity.operating_system_family -ceq "windows" -and
    [string]$hostIdentity.godot_launcher_executable_sha256 -ceq
        "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896" -and
    [string]$hostIdentity.godot_runtime_executable_sha256 -ceq
        "baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4" -and
    [string]$hostIdentity.physics_engine -ceq "Jolt Physics" -and
    [int]$hostIdentity.physics_hz -eq 120 -and
    [int]$hostIdentity.solver_velocity_steps -eq 20 -and
    [int]$hostIdentity.solver_position_steps -eq 7
) "BW24M identity, study class, or pinned host changed"

Assert-SequenceExact @($reservation.authored_friction_values) @(
    0.59, 0.71, 0.83
) "BW24M fresh authored values"
Assert-SequenceExact @($reservation.downstream_locomotion_seeds) @(
    26011, 26012, 26013, 26014
) "BW24M downstream seeds"
Assert-SequenceExact @($characterization.authored_friction_values) @(
    0.59, 0.71, 0.83
) "BW24M characterization values"
Assert-SequenceExact @($future.authored_friction_values) @(
    0.59, 0.71, 0.83
) "BW25Y planned material values"
Assert-SequenceExact @($future.seeds) @(
    26011, 26012, 26013, 26014
) "BW25Y planned seeds"
Assert-SequenceExact @($future.candidate_order) @(
    "BW25Y-A", "BW25Y-B"
) "BW25Y planned candidate order"

Assert-Exact (
    [bool]$reservation.prior_informed_development_grid -and
    -not [bool]$reservation.independent_validation_grid -and
    [string]$stages.stage_0_declaration_and_fixture_preflight.status -ceq
        "prospectively_declared_zero_world_only" -and
    [int]$stages.stage_0_declaration_and_fixture_preflight.physical_world_count -eq 0 -and
    [string]$stages.stage_1_material_characterization.status -ceq
        "blocked_until_complete_production_gate_supervisor_and_freeze_are_committed_and_pushed" -and
    [bool]$stages.stage_1_material_characterization.may_not_open_from_this_declaration_alone -and
    [int]$characterization.expected_world_count -eq 10 -and
    [int]$characterization.expected_gate_count -eq 19 -and
    [int]$characterization.replicate_count_per_value -eq 3 -and
    [int]$characterization.frictionless_control_world_count -eq 1 -and
    [int]$future.expected_candidate_world_count -eq 24 -and
    [int]$future.expected_control_world_count -eq 3 -and
    [int]$future.expected_zero_friction_safety_world_count -eq 1 -and
    [int]$future.expected_world_count -eq 28
) "BW24M stage or downstream finite matrix changed"

Assert-Exact (
    [string]$future.candidate_a.controller_policy_id -ceq
        "sporespore_balanced_wave_bw15f_b_v1" -and
    [double]$future.candidate_a.yaw_error_stride_gain_per_rad -eq 1.3 -and
    [string]$future.candidate_b.controller_policy_id -ceq
        "sporespore_balanced_wave_bw23y_b_v1" -and
    [string]$future.candidate_b.runtime_profile_sha256 -ceq
        "sha256:d345d9607bed545ee6c58a20055cd6258f38ed581dd3d9f6490a9ae7f1a57570" -and
    [double]$future.candidate_b.yaw_error_stride_gain_per_rad -eq 1.0 -and
    [bool]$future.receipt_shape_requires_exact_four_walking_keys -and
    [bool]$future.receipt_shape_requires_controller_coefficient_in_all_worlds -and
    [bool]$future.receipt_shape_requires_common_identity_fields_in_zero_friction_safety_world -and
    [bool]$future.stale_debug_adapter_artifact_must_fail_before_any_world -and
    [bool]$future.selected_candidate_still_requires_distinct_independent_validation
) "BW25Y candidate or repaired-receipt contract changed"

Assert-Exact (
    [int]$stage0.world_build_count -eq 0 -and
    [int]$stage0.scene_tree_insertion_count -eq 0 -and
    [int]$stage0.physics_state_mutation_count -eq 0 -and
    -not [bool]$stage0.locomotion_outcome_exposed -and
    -not [bool]$stage0.characterization_outcome_exposed -and
    -not [bool]$stage0.physical_acceptance_authority -and
    [bool]$stage1.complete_production_receipt_gate_must_accept_perfect_synthetic_input -and
    [bool]$stage1.complete_one_shot_supervisor_must_be_frozen -and
    [bool]$stage1.complete_freeze_audit_must_bind_every_production_blob -and
    -not [bool]$stage1.physical_execution_authorized_by_this_document_alone -and
    [bool]$claims.declaration_preflight_only -and
    -not [bool]$claims.material_characterization_complete -and
    -not [bool]$claims.controller_selection -and
    -not [bool]$claims.physical_acceptance_authority
) "BW24M zero-world boundary or physical interlock changed"

$rigSource = Get-Content -Raw -LiteralPath $rigPath
$preflightSource = Get-Content -Raw -LiteralPath $preflightPath
$runnerSource = Get-Content -Raw -LiteralPath $runnerPath
$conformanceSource = Get-Content -Raw -LiteralPath $conformancePath
Assert-SourceContains $rigSource @(
    'const BW24M_FIXTURE_ID := "SDK.BW24M.godot_jolt_material_sled.v1"',
    'const BW24M_AUTHORED_FRICTION_VALUES := [0.0, 0.59, 0.71, 0.83]',
    'static func build(',
    'ParentRigScript',
    'successor_wrapper_id',
    'immutable_parent_fixture_source'
) "fixture surface"
Assert-SourceContains $preflightSource @(
    'sdk_bw24m_friction_ladder_sled_rig.gd',
    'const EXPECTED_VALUES := [0.59, 0.71, 0.83]',
    'const EXPECTED_SEEDS := [26011, 26012, 26013, 26014]',
    'RigScript.build(CaptureClockScript.new(), profile, 0.81)',
    'OS.get_executable_path()',
    '"world_build_count": 0',
    '"physical_acceptance_authority": false'
) "zero-world preflight"
Assert-SourceContains $runnerSource @(
    '$expectedGodotLauncherSha256 = (',
    'Get-FileHash -LiteralPath $godotPath -Algorithm SHA256',
    'BW24M_MATERIAL_PREFLIGHT_PASS fixtures=4 positive_values=3',
    "'(?m)^ERROR:'",
    'throw "BW24M material declaration preflight failed'
) "preflight runner"
Assert-Exact (
    ([regex]::Matches(
        $conformanceSource,
        'run_balanced_wave_bw24m_material_declaration_preflight\.ps1'
    )).Count -eq 1 -and
    ([regex]::Matches(
        $conformanceSource,
        'test_bw24m_material_declaration\.ps1'
    )).Count -eq 1
) "BW24M runner parse or declaration-audit invocation is absent from conformance"

if (-not $SkipGodotPreflight) {
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File $runnerPath `
        -Godot $Godot
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "BW24M zero-world Godot preflight failed"
}

Write-Host (
    "BW24M_MATERIAL_DECLARATION_PASS values=3 seeds=4 fixtures=4 " +
    "future_worlds=28 characterization_worlds_opened=0 " +
    "locomotion_worlds_opened=0 physical_authority=False"
)

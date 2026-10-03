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
$implementationParentCommit = "4b2f6bec8a1f9b95938c9571553699f59791c26e"
$preregistrationPath = Join-Path (
    $repoRoot
) "sdk\balanced_wave_bw22m_fresh_material_preregistration.json"
$runnerPath = Join-Path (
    $repoRoot
) "sdk\run_balanced_wave_bw22m_material_declaration_preflight.ps1"
$preflightPath = Join-Path (
    $repoRoot
) "tests\test_sdk_balanced_wave_bw22m_material_preflight.gd"
$rigPath = Join-Path (
    $repoRoot
) "scripts\lab\rigs\sdk_bw22m_friction_ladder_sled_rig.gd"
$conformancePath = Join-Path $repoRoot "sdk\run_conformance.ps1"

$boundFiles = [ordered]@{
    "sdk/balanced_wave_bw22m_fresh_material_preregistration.json" =
        "efb2d89a684bae1127ddccdfe74284795f1c78eccdec6661d3b4e640be1d868b"
    "sdk/run_balanced_wave_bw22m_material_declaration_preflight.ps1" =
        "56159fd573d4cf6ed6d33b65741ed47cedfc75b3e52a60223cac0b3b8936466b"
    "tests/test_sdk_balanced_wave_bw22m_material_preflight.gd" =
        "bc5a0c27565513d0e599d52a037e5c0f857a826a841b16851bea803e3e269dda"
    "scripts/lab/rigs/sdk_friction_ladder_sled_rig.gd" =
        "bcd40080800669492dbc0633d5aa95ed11461d7ae29756c05e892b3467ccd014"
    "scripts/lab/rigs/sdk_bw22m_friction_ladder_sled_rig.gd" =
        "7214c9c23551b50a1ff7fe90cb7e6a5ec45bb74593e471a50612d3d84aa266e2"
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
        ) "BW22M $Label lost required text: $needle"
    }
}

foreach ($entry in $boundFiles.GetEnumerator()) {
    $path = Join-Path $repoRoot $entry.Key
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 $path) -ceq [string]$entry.Value
    ) "BW22M declaration artifact is missing or changed: $($entry.Key)"
}

& git -C $repoRoot merge-base --is-ancestor $implementationParentCommit HEAD
Assert-Exact (
    $LASTEXITCODE -eq 0
) "BW22M implementation parent is not an ancestor of HEAD"

# Prove freshness against the entire predecessor snapshot, rather than merely
# searching today's working tree after BW22M has necessarily introduced the
# reserved values and seeds itself. Pathspecs cover declarations, workers,
# supervisors, and balanced-wave controller sources that could expose them as
# campaign inputs or outcomes.
$freshnessPattern = (
    '(^|[^0-9])(0\.57|0\.69|0\.81)([^0-9]|$)|' +
    '24011|24012|24013|24014'
)
$freshnessMatches = @(
    & git -C $repoRoot grep -n -E $freshnessPattern `
        $implementationParentCommit -- `
        "sdk/balanced_wave_*.json" `
        "sdk/*balanced_wave*.json" `
        "sdk/run_balanced_wave*" `
        "tests/test_sdk_balanced_wave*" `
        "scripts/lab/gait/*balanced_wave*" `
        2>$null
)
$freshnessExitCode = $LASTEXITCODE
Assert-Exact (
    $freshnessExitCode -eq 1 -and $freshnessMatches.Count -eq 0
) "BW22M values or seeds were already exposed in the predecessor campaign surface"

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable
$study = $preregistration.study_class
$stages = $preregistration.pipeline_stages
$hostIdentity = $preregistration.host_identity
$reservation = $preregistration.fresh_reservation
$characterization = $preregistration.material_characterization
$future = $preregistration.planned_future_bw22l_development_contract
$stage0 = $preregistration.stage_0_preflight_contract
$stage1 = $preregistration.required_stage_1_freeze_contract
$claims = $preregistration.current_claim_boundary

Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw22m_fresh_material_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "prospective_declaration_preflight_only_physical_execution_blocked" -and
    [string]$preregistration.campaign_id -ceq
        "BW22M-BW21L-FRESH-MATERIAL-CHARACTERIZATION" -and
    [string]$preregistration.gate_id -ceq "BW22M" -and
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
) "BW22M identity or study class changed"

Assert-SequenceExact @($reservation.authored_friction_values) @(
    0.57, 0.69, 0.81
) "BW22M fresh authored values"
Assert-SequenceExact @($reservation.downstream_locomotion_seeds) @(
    24011, 24012, 24013, 24014
) "BW22M downstream seeds"
Assert-SequenceExact @($characterization.authored_friction_values) @(
    0.57, 0.69, 0.81
) "BW22M characterization values"
Assert-SequenceExact @($future.authored_friction_values) @(
    0.57, 0.69, 0.81
) "BW22L planned material values"
Assert-SequenceExact @($future.seeds) @(
    24011, 24012, 24013, 24014
) "BW22L planned seeds"
Assert-SequenceExact @($future.candidate_order) @(
    "BW22L-A", "BW22L-B"
) "BW22L planned candidate order"

Assert-Exact (
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
) "BW22M stage or downstream finite matrix changed"

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
) "BW22M zero-world boundary or physical interlock changed"

$rigSource = Get-Content -Raw -LiteralPath $rigPath
$preflightSource = Get-Content -Raw -LiteralPath $preflightPath
$runnerSource = Get-Content -Raw -LiteralPath $runnerPath
$conformanceSource = Get-Content -Raw -LiteralPath $conformancePath
Assert-SourceContains $rigSource @(
    'const BW22M_FIXTURE_ID := "SDK.BW22M.godot_jolt_material_sled.v1"',
    'const BW22M_AUTHORED_FRICTION_VALUES := [0.0, 0.57, 0.69, 0.81]',
    'static func build(',
    'ParentRigScript',
    'successor_wrapper_id',
    'immutable_parent_fixture_source'
) "fixture surface"
Assert-SourceContains $preflightSource @(
    'sdk_bw22m_friction_ladder_sled_rig.gd',
    'const EXPECTED_VALUES := [0.57, 0.69, 0.81]',
    'const EXPECTED_SEEDS := [24011, 24012, 24013, 24014]',
    '. build(',
    '0.76,',
    'OS.get_executable_path()',
    '"world_build_count": 0',
    '"physical_acceptance_authority": false'
) "zero-world preflight"
Assert-SourceContains $runnerSource @(
    '$expectedGodotLauncherSha256 = (',
    'Get-FileHash -LiteralPath $godotPath -Algorithm SHA256',
    'BW22M_MATERIAL_PREFLIGHT_PASS fixtures=4 positive_values=3',
    "'(?m)^ERROR:'",
    'throw "BW22M material declaration preflight failed'
) "preflight runner"
Assert-Exact (
    ([regex]::Matches(
        $conformanceSource,
        'run_balanced_wave_bw22m_material_declaration_preflight\.ps1'
    )).Count -eq 2
) "BW22M runner is not both parsed and invoked by conformance"

if (-not $SkipGodotPreflight) {
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File $runnerPath `
        -Godot $Godot
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "BW22M zero-world Godot preflight failed"
}

Write-Host (
    "BW22M_MATERIAL_DECLARATION_PASS values=3 seeds=4 fixtures=4 " +
    "future_worlds=28 characterization_worlds_opened=0 " +
    "locomotion_worlds_opened=0 physical_authority=False"
)

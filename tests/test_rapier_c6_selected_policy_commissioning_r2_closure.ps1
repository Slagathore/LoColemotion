$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$closurePath = Join-Path (
    $repoRoot
) "sdk\rapier_c6_selected_policy_commissioning_r2_closure.json"
$expectedClosureRawSha256 = (
    "sha256:" +
    "07b02dbd2343d772a002b045ce32cbc6d5bb07c3fa63a308a4b06d70f202097d"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

Assert-Exact (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-RawSha256 $closurePath) -ceq $expectedClosureRawSha256
) "Rapier C6-RAP-SP1-R2 closure is missing or changed"
$closure = (
    Get-Content -Raw -LiteralPath $closurePath |
        ConvertFrom-Json
)
foreach ($source in @(
    $closure.preregistration,
    $closure.predecessor_closure
)) {
    $path = Join-Path $repoRoot ([string]$source.path)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 $path) -ceq [string]$source.raw_sha256
    ) "Rapier C6-RAP-SP1-R2 source chain failed its hash audit"
}
foreach ($artifactName in @("report", "stdout", "stderr")) {
    $artifact = $closure.artifacts.$artifactName
    $path = [string]$artifact.path
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$artifact.bytes -and
        (Get-RawSha256 $path) -ceq [string]$artifact.sha256
    ) "Rapier C6-RAP-SP1-R2 $artifactName failed its artifact audit"
}
$report = (
    Get-Content -Raw -LiteralPath ([string]$closure.artifacts.report.path) |
        ConvertFrom-Json
)
$postSettle = $report.observability.post_settle
$actuators = @($report.observability.actuators.psobject.Properties)
$contacts = @($report.observability.contacts.psobject.Properties)
$limbMemory = @($report.observability.final_limb_memory.psobject.Properties)
$maximumImpulse = (
    $actuators |
        ForEach-Object {
            [double]$_.Value.maximum_motor_impulse_nms
        } |
        Measure-Object -Maximum
).Maximum
$maximumUtilization = (
    $actuators |
        ForEach-Object {
            [double]$_.Value.maximum_motor_impulse_utilization
        } |
        Measure-Object -Maximum
).Maximum
Assert-Exact (
    [string]$closure.status -ceq
        "closed_diagnostic_declared_motor_model_mismatch" -and
    [string]$closure.source.commit -ceq
        "441a70e963356c106aef1d1375e72b1ce280bee1" -and
    -not [bool]$report.ok -and
    [int]$report.controller_semantic_step_count -eq 2992 -and
    [int]$report.validated_portable_command_count -eq 23936 -and
    [int]$report.native_motor_application_count -eq 23936 -and
    [int]$report.controller_error_count -eq 0 -and
    [int]$report.safe_no_actuation_count -eq 0 -and
    [int]$report.nonfinite_observation_count -eq 0 -and
    [int]$report.motor_impulse_limit_violation_count -eq 0 -and
    $actuators.Count -eq 8 -and
    $contacts.Count -eq 4 -and
    $limbMemory.Count -eq 4
) "Rapier C6-RAP-SP1-R2 diagnostic integrity changed"
Assert-Exact (
    [math]::Abs([double]$postSettle.torso_position_m.x + 0.4698747396469116) -le
        1.0e-12 -and
    [math]::Abs([double]$postSettle.torso_height_m - 0.23770499229431152) -le
        1.0e-12 -and
    [math]::Abs([double]$postSettle.torso_tilt_rad - 0.4253164231777191) -le
        1.0e-12 -and
    -not [bool]$postSettle.torso_ground_contact -and
    [int]$report.observability.first_torso_ground_contact_semantic_step -eq 26 -and
    [math]::Abs([double]$maximumImpulse - 0.00001134399735747138) -le 1.0e-15 -and
    [math]::Abs([double]$maximumUtilization - 0.0002423111195756869) -le 1.0e-15
) "Rapier C6-RAP-SP1-R2 post-settle or motor diagnosis changed"
foreach ($contact in $contacts) {
    Assert-Exact (
        [int]$contact.Value.bearing_true_step_count -eq 2992 -and
        [int]$contact.Value.bearing_false_step_count -eq 0 -and
        [int]$contact.Value.transition_count -eq 0
    ) "Rapier C6-RAP-SP1-R2 contact occupancy changed"
}
Assert-Exact (
    [string]$closure.contract_diagnosis.classification -ceq
        "declared_force_based_motor_model_not_realized" -and
    -not [bool]$closure.contract_diagnosis.post_settle_support_initialization_passed -and
    -not [bool]$closure.contract_diagnosis.selected_policy_locomotion_was_fairly_initialized -and
    -not [bool]$closure.contract_diagnosis.policy_performance_interpretation_allowed -and
    [bool]$closure.host_characterization_impact.c6_hc1_r2_material_grid_remains_valid_for_its_declared_discrete_material_worlds -and
    [bool]$closure.host_characterization_impact.c6_hc1_r2_actuator_grid_measured_acceleration_based_default_behavior -and
    -not [bool]$closure.host_characterization_impact.c6_hc1_r2_actuator_grid_supports_force_based_claim -and
    -not [bool]$closure.disposition.another_unchanged_locomotion_probe_allowed -and
    [bool]$closure.disposition.force_based_host_characterization_successor_allowed -and
    [bool]$closure.disposition.locomotion_successor_blocked_until_host_characterization_closes
) "Rapier C6-RAP-SP1-R2 contract diagnosis or disposition changed"
Assert-Exact (
    -not [bool]$closure.claim_boundary.independent_validation -and
    -not [bool]$closure.claim_boundary.arbitrary_quadruped_coverage -and
    -not [bool]$closure.claim_boundary.continuous_full_volume_coverage -and
    -not [bool]$closure.claim_boundary.material_robustness -and
    -not [bool]$closure.claim_boundary.cross_engine_c6 -and
    -not [bool]$closure.claim_boundary.locomotion_acceptance -and
    -not [bool]$closure.claim_boundary.release_authorized -and
    -not [bool]$closure.claim_boundary.physical_acceptance_authority -and
    -not [bool]$closure.claim_boundary.completed_engine_neutral_sdk
) "Rapier C6-RAP-SP1-R2 closure overclaims authority"

Write-Host (
    "Rapier C6-RAP-SP1-R2 closure passed: post-settle failure, " +
    "motor-model mismatch, 3 artifacts, and host-characterization impact audited."
)

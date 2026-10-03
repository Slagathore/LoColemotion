#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$preregistrationPath = Join-Path (
    $sdkRoot
) "mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5_preregistration.json"
$runnerPath = Join-Path (
    $sdkRoot
) "run_mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5.ps1"
$expectedParent = "086f3019228167e8f8d526200d2b7304af0ed6e0"
$expectedPreregistrationSha256 = (
    "dfe87630215f3c857b0edff51678b8e113acaf216b3d12e6b3a923ad0db30d90"
)
$campaignId = (
    "C6-MUJOCO-S169-PER-ACTUATOR-FORCE-LIMIT-HOST-CHARACTERIZATION-VH5"
)
$gateId = "C6-MJC-HC-VH5"
$evidenceRoot = [IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

Assert-Exact (
    (Test-Path -LiteralPath $preregistrationPath -PathType Leaf) -and
    (Get-RawSha256 -Path $preregistrationPath) -ceq
        $expectedPreregistrationSha256
) "$gateId frozen preregistration is missing or changed"

$expectedFiles = [ordered]@{
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/s169_force_limit_characterization_vh5.py" = "1eb818c74d8087d15f7b93e9ec147815576e362dc8fbb355a2dc3f0a1f9fcbe1"
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/velocity_only_stability_characterization_vh4.py" = "24539f4b082a8c703e0bd45483b0f353cd513c79cc487745c55200c32b89c14e"
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_development.py" = "a4dd40eac736c88c6acf661e503aa3cb4414a3e5f8e5e4fc6cc8ef226ab609e0"
    "sdk/adapters/mujoco/test_conformance.py" = "e29abf03b8b021c4ec6bc257f2bc69a44f961ced49cab19b6e1af46a7f5a05dc"
    "sdk/core/src/canonical_actuation.rs" = "33082ebac939141dc6999a9e9d5743a156fa8f89f67b077042fb906518a6e198"
    "sdk/adapters/mujoco/requirements-lock.txt" = "38e97a013ec5e7c5bd88cd4dc1c2c54dd151936aa7f24c1f87abac19853b77b9"
    "sdk/mujoco_c6_velocity_only_stability_host_characterization_vh4_closure.json" = "faf6aabe9d5bb36a410a4447416c63697666640b458bae49ee1662aa045e4cb9"
    "sdk/run_mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5.ps1" = "f87fc96b471f2230c6fd4b9beb02df78024aeed9ececd50d8eb5765efbf7acfa"
}
foreach ($entry in $expectedFiles.GetEnumerator()) {
    $path = [IO.Path]::GetFullPath((Join-Path $repoRoot ([string]$entry.Key)))
    $prefix = $repoRoot.TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    ) + [IO.Path]::DirectorySeparatorChar
    Assert-Exact (
        $path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 -Path $path) -ceq [string]$entry.Value
    ) "$gateId frozen source changed: $($entry.Key)"
}

$declaration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$classes = @($declaration.motor_profile.force_limit_classes)
Assert-Exact (
    [string]$declaration.campaign_id -ceq $campaignId -and
    [string]$declaration.gate_id -ceq $gateId -and
    [string]$declaration.status -ceq
        "frozen_before_first_c6_mjc_hc_vh5_campaign_world" -and
    [string]$declaration.implementation_parent_commit -ceq $expectedParent -and
    [int]$classes.Count -eq 4 -and
    (@($classes | ForEach-Object { [string]$_.class_id }) -join ",") -ceq
        "front_hip,front_knee,rear_hip,rear_knee" -and
    [int]$declaration.physical_grid.worlds -eq 96 -and
    [int]$declaration.physical_grid.aggregate_internal_trace_records -eq 172800 -and
    [int]$declaration.physical_grid.mirrored_signed_pairs -eq 48 -and
    [int]$declaration.preflight_contract.negative_control_count -eq 24 -and
    [int]$declaration.preflight_contract.
        compiled_s169_force_limit_reconstruction_canary_count -eq 4 -and
    [int]$declaration.preflight_contract.binding_surface_canary_count -eq 5
) "$gateId declaration identity, classes, or grid changed"
$expectedForceLimits = @(
    6.435150204824762,
    5.265122894856622,
    6.764849795175239,
    5.534877105143378
)
for ($index = 0; $index -lt $expectedForceLimits.Count; $index += 1) {
    Assert-Exact (
        [double]$classes[$index].maximum_force_nm -eq $expectedForceLimits[$index]
    ) "$gateId force-limit class $index changed"
}

$qualification = $declaration.pre_freeze_implementation_qualification
Assert-Exact (
    [string]$qualification.draft_preregistration_raw_sha256 -ceq
        "6ae2b1dee6036c0cdda8573eaa8610b816642da4b94b091cc8f76c624c94d2a2" -and
    [bool]$qualification.complete_synthetic_preflight_passed_before_any_qualification_model -and
    [int]$qualification.synthetic_preflight_world_build_count -eq 0 -and
    [int]$qualification.ordinary_non_campaign_world_count -eq 4 -and
    [bool]$qualification.all_four_qualification_cells_passed_the_already_declared_cell_gate -and
    [bool]$qualification.qualification_results_may_not_be_substituted_into_campaign_report -and
    -not [bool]$qualification.grid_thresholds_estimand_and_claim_boundary_changed_after_qualification -and
    [bool]$qualification.first_supervised_campaign_world_has_not_opened
) "$gateId pre-freeze qualification disclosure changed"

foreach ($claim in @(
    "continuous_force_limit_gain_inertia_load_or_timestep_domain",
    "selected_robot_multibody_dynamics_characterized",
    "mujoco_selected_policy_locomotion",
    "mujoco_walking",
    "cross_engine_equivalence",
    "arbitrary_quadruped_coverage",
    "friction_material_or_terrain_robustness",
    "release_authorized",
    "completed_engine_neutral_sdk",
    "physical_acceptance_authority"
)) {
    Assert-Exact (-not [bool]$declaration.claim_boundary[$claim]) (
        "$gateId declaration inflated claim: $claim"
    )
}

& git -C $repoRoot cat-file -e "$expectedParent`^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId implementation parent is not retained"
& git -C $repoRoot merge-base --is-ancestor $expectedParent HEAD
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId implementation parent is not an ancestor"
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId origin/main could not be resolved"
& git -C $repoRoot merge-base --is-ancestor $expectedParent $originMain
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId implementation parent is not on origin/main"

$rootsBefore = @(
    Get-ChildItem -LiteralPath $evidenceRoot `
        -Directory `
        -Filter "c6-mujoco-s169-force-limit-vh5-*" `
        -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        ForEach-Object { $_.FullName }
)
Assert-Exact (
    $rootsBefore.Count -eq 0
) "$gateId campaign evidence already exists; the prospective freeze is no longer current"
$output = & pwsh `
    -NoLogo `
    -NoProfile `
    -File $runnerPath `
    -PreflightOnly 2>&1 | Out-String
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $output.Contains(
        "C6_MJC_HC_VH5_FREEZE_PASS classes=4 cells=96 pairs=48 " +
        "traces=172800 canaries=24 compiled_canaries=4 binding_canaries=5 " +
        "qualification_worlds=4 campaign_worlds=0 physical_authority=False"
    )
) "$gateId supervisor did not pass the complete zero-world freeze gate"
$rootsAfter = @(
    Get-ChildItem -LiteralPath $evidenceRoot `
        -Directory `
        -Filter "c6-mujoco-s169-force-limit-vh5-*" `
        -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        ForEach-Object { $_.FullName }
)
Assert-Exact (
    ($rootsAfter -join "`n") -ceq ($rootsBefore -join "`n")
) "$gateId freeze audit created or changed a campaign evidence root"

$physicalRefusalOutput = & pwsh `
    -NoLogo `
    -NoProfile `
    -File $runnerPath `
    -RunPhysical 2>&1 | Out-String
$physicalRefusalExitCode = $LASTEXITCODE
$rootsAfterRefusal = @(
    Get-ChildItem -LiteralPath $evidenceRoot `
        -Directory `
        -Filter "c6-mujoco-s169-force-limit-vh5-*" `
        -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        ForEach-Object { $_.FullName }
)
Assert-Exact (
    $physicalRefusalExitCode -ne 0 -and
    $physicalRefusalOutput.Contains(
        "$gateId -RunPhysical requires an exact full-Godot V2 attestation"
    ) -and
    ($rootsAfterRefusal -join "`n") -ceq ($rootsBefore -join "`n")
) "$gateId unqualified physical execution was not refused before evidence creation"

$runnerText = Get-Content -Raw -LiteralPath $runnerPath
Assert-Exact (
    $runnerText.Contains("same-identity rerun is forbidden") -and
    $runnerText.Contains("is closed and may not open another world") -and
    $runnerText.Contains("replacement_processes_allowed = 0") -and
    $runnerText.Contains("physical execution requires distinct clean HEAD == origin/main == live GitHub main") -and
    $runnerText.Contains("retained a complete negative report")
) "$gateId physical lifecycle no longer fails closed"

Write-Host (
    "C6_MJC_HC_VH5_FREEZE_AUDIT_PASS classes=4 cells=96 pairs=48 " +
    "traces=172800 canaries=24 qualification_worlds=4 campaign_worlds=0 " +
    "physical_authority=False"
)

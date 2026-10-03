#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$python = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$preregistrationPath = Join-Path $sdkRoot (
    "cross_engine_c6_bw19v_discrete_material_validation_xv2_preregistration.json"
)
$gatePath = Join-Path $sdkRoot (
    "cross_engine_c6_bw19v_discrete_material_validation_xv2_gate.ps1"
)
$supervisorProjectionPath = Join-Path $sdkRoot (
    "cross_engine_c6_bw19v_discrete_material_validation_xv2_supervisor_projection.ps1"
)
$runnerPath = Join-Path $sdkRoot (
    "run_cross_engine_c6_bw19v_discrete_material_validation_xv2.ps1"
)
$rapierWorkerPath = Join-Path $sdkRoot (
    "adapters\rapier\src\cross_engine_discrete_material_validation_xv2_rapier.rs"
)
$rapierCliPath = Join-Path $sdkRoot (
    "adapters\rapier\src\bin\cross_engine_discrete_material_validation_xv2_rapier.rs"
)
$rapierLocomotionPath = Join-Path $sdkRoot "adapters\rapier\src\locomotion.rs"
$mujocoWorkerPath = Join-Path $mujocoRoot (
    "sporespore_mujoco_adapter\cross_engine_discrete_material_validation_xv2_mujoco.py"
)
$mujocoBridgePath = Join-Path $mujocoRoot (
    "sporespore_mujoco_adapter\cross_engine_discrete_material_validation_xv2_bridge.py"
)
$mujocoBaselineBridgePath = Join-Path $mujocoRoot (
    "sporespore_mujoco_adapter\selected_policy_development.py"
)
$closurePath = Join-Path $sdkRoot (
    "cross_engine_c6_bw19v_discrete_material_validation_xv2_closure.json"
)
$evidenceRoot = [IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$campaignId = "C6-CROSS-ENGINE-BW19V-DISCRETE-MATERIAL-VALIDATION-XV2"
$gateId = "C6-XE-BW19V-XV2"
$implementationParent = "36f17791d1887f5a76b773a255f7502f805b44ca"
$expectedPreregistrationSha256 = (
    "33127f0534d919dc026320dc6ba9600c0245a35271ad7e53ba9fdf32953b8ea7"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Get-CampaignEvidenceDirectories {
    if (-not (Test-Path -LiteralPath $evidenceRoot -PathType Container)) {
        return @()
    }
    return @(
        Get-ChildItem -LiteralPath $evidenceRoot `
            -Directory `
            -Filter "c6-cross-engine-bw19v-xv2-*" `
            -ErrorAction SilentlyContinue |
            Sort-Object FullName |
            ForEach-Object { $_.FullName }
    )
}

Assert-Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "$gateId repository identity changed"

foreach ($path in @(
    $python,
    $preregistrationPath,
    $gatePath,
    $supervisorProjectionPath,
    $runnerPath,
    $rapierWorkerPath,
    $rapierCliPath,
    $rapierLocomotionPath,
    $mujocoWorkerPath,
    $mujocoBridgePath,
    $mujocoBaselineBridgePath
)) {
    Assert-Exact (Test-Path -LiteralPath $path -PathType Leaf) (
        "$gateId required freeze surface is missing: $path"
    )
}
Assert-Exact (
    (Get-RawSha256 $preregistrationPath) -ceq $expectedPreregistrationSha256 -and
    -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
) "$gateId preregistration changed or prospective campaign is already closed"

$declaration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$cells = @($declaration.matrix.ordered_cells)
$expectedCells = @(
    @("1", "rapier_mu020", "rapier", "0.34.0", "0.2", "0.2", "rapier_bw19v_xv2_mu020_v1", "PH1"),
    @("2", "rapier_mu060", "rapier", "0.34.0", "0.6", "0.6", "rapier_bw19v_xv2_mu060_v1", "PH1"),
    @("3", "rapier_mu100", "rapier", "0.34.0", "1", "1", "rapier_bw19v_xv2_mu100_v1", "PH1"),
    @("4", "mujoco_mu020", "mujoco", "3.11.0", "0.2", "0.2|0|0", "mujoco_bw19v_xv2_mu020_v1", "MV6"),
    @("5", "mujoco_mu060", "mujoco", "3.11.0", "0.6", "0.6|0|0", "mujoco_bw19v_xv2_mu060_v1", "MV6"),
    @("6", "mujoco_mu100", "mujoco", "3.11.0", "1", "1|0|0", "mujoco_bw19v_xv2_mu100_v1", "MV6")
)
$actualCells = @(
    $cells | ForEach-Object {
        @(
            [string]$_.ordinal,
            [string]$_.cell_id,
            [string]$_.engine,
            [string]$_.engine_version,
            [string]$_.authored_sliding_friction,
            (@($_.authored_friction_vector) -join "|"),
            [string]$_.material_profile_id,
            [string]$_.inherited_worker_contract
        ) -join "::"
    }
)
$expectedCellRows = @($expectedCells | ForEach-Object { $_ -join "::" })
Assert-Exact (
    [string]$declaration.schema_version -ceq
        "sporespore_cross_engine_c6_bw19v_discrete_material_validation_xv2_preregistration_v1" -and
    [string]$declaration.status -ceq
        "frozen_before_first_c6_xe_bw19v_xv2_physics_world" -and
    [string]$declaration.campaign_id -ceq $campaignId -and
    [string]$declaration.gate_id -ceq $gateId -and
    [string]$declaration.implementation_parent_commit -ceq $implementationParent -and
    [string]$declaration.study_class.classification -ceq
        "exact_finite_cell_successor_validation_after_implementation_invalid_incomplete_predecessor" -and
    [bool]$declaration.study_class.finite_decision -and
    [bool]$declaration.study_class.independent_validation -and
    -not [bool]$declaration.study_class.population_inference -and
    -not [bool]$declaration.study_class.cross_engine_equivalence_study -and
    [int]$declaration.study_class.expected_world_count -eq 6 -and
    [int]$declaration.matrix.expected_world_count -eq 6 -and
    ($actualCells -join "`n") -ceq ($expectedCellRows -join "`n") -and
    (@($declaration.material_contract.authored_sliding_friction_values) -join "|") -ceq
        "0.2|0.6|1" -and
    [string]$declaration.material_contract.rapier.friction_combine_rule -ceq "min" -and
    [string]$declaration.material_contract.mujoco.friction_cone -ceq "elliptic" -and
    [double]$declaration.material_contract.mujoco.torsional_friction -eq 0.0 -and
    [double]$declaration.material_contract.mujoco.rolling_friction -eq 0.0 -and
    [string]$declaration.material_contract.mujoco.immutable_mv6_bridge_raw_sha256 -ceq
        "306669481601cc91c8146e84a202a57228672e23c3f9daa0c531d2eb9d077e46" -and
    [string]$declaration.material_contract.mujoco.xv2_material_successor_bridge_raw_sha256 -ceq
        "bee9ec0f4e56b501c6d0feb2de00e5c68ee145a59e18a0e24e710090e3dfa009" -and
    (Get-RawSha256 $mujocoBridgePath) -ceq
        [string]$declaration.material_contract.mujoco.xv2_material_successor_bridge_raw_sha256 -and
    [bool]$declaration.material_contract.continuous_interpolation_or_extrapolation_forbidden -and
    [int]$declaration.engine_contracts.rapier.total_controller_semantic_steps -eq 3172 -and
    [int]$declaration.engine_contracts.mujoco.total_controller_semantic_steps -eq 2992 -and
    [bool]$declaration.execution_contract.all_six_cells_execute_serially_under_one_operation_lock -and
    [bool]$declaration.execution_contract.all_six_cell_attempts_are_made_even_if_an_earlier_cell_fails -and
    [int]$declaration.execution_contract.replacement_worker_processes_allowed -eq 0 -and
    -not [bool]$declaration.execution_contract.same_identity_physical_rerun_allowed -and
    [bool]$declaration.scientific_distinction_from_xv1.xv1_is_immutable_and_not_resumed -and
    [bool]$declaration.scientific_distinction_from_xv1.xv1_had_no_aggregate_scientific_result -and
    -not [bool]$declaration.scientific_distinction_from_xv1.matrix_changed -and
    -not [bool]$declaration.scientific_distinction_from_xv1.policy_changed -and
    -not [bool]$declaration.scientific_distinction_from_xv1.thresholds_changed -and
    -not [bool]$declaration.scientific_distinction_from_xv1.four_xv1_observations_used_for_parameter_selection -and
    [bool]$declaration.scientific_distinction_from_xv1.xv2_requires_six_new_worker_processes -and
    [bool]$declaration.scientific_distinction_from_xv1.xv1_reports_may_not_be_substituted_into_xv2
) "$gateId identity, exact finite matrix, material, or execution contract changed"

foreach ($claimName in @(
    "formal_cross_engine_equivalence",
    "trajectory_equivalence",
    "continuous_friction_coverage",
    "arbitrary_material_robustness",
    "population_inference",
    "arbitrary_quadruped_coverage",
    "continuous_morphology_coverage",
    "rough_terrain_robustness",
    "external_push_recovery",
    "sensor_noise_or_latency_robustness",
    "release_authorized",
    "completed_engine_neutral_sdk",
    "physical_acceptance_authority"
)) {
    Assert-Exact (-not [bool]$declaration.claims_if_accepted[$claimName]) (
        "$gateId preregistration inflated claim: $claimName"
    )
}

foreach ($authority in $declaration.bound_authorities.Values) {
    $authorityPath = [IO.Path]::GetFullPath(
        (Join-Path $repoRoot ([string]$authority.path))
    )
    Assert-Exact (
        (Test-Path -LiteralPath $authorityPath -PathType Leaf) -and
        (Get-RawSha256 $authorityPath) -ceq [string]$authority.raw_sha256
    ) "$gateId bound authority changed: $authorityPath"
}
$ph1 = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
$mv6 = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_closure.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
$xv1 = Get-Content -Raw -LiteralPath (
    Join-Path $sdkRoot "cross_engine_c6_bw19v_discrete_material_validation_xv1_closure.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-Exact (
    [string]$ph1.status -ceq
        "closed_complete_valid_positive_exact_s169_pose_hold_restoration_and_finite_walking_contract" -and
    [string]$mv6.status -ceq
        "closed_complete_valid_positive_exact_s169_pose_hold_restoration_and_finite_walking_contract" -and
    [string]$xv1.status -ceq
        "closed_consumed_implementation_invalid_incomplete_no_aggregate_result" -and
    -not [bool]$xv1.technical_disposition.scientific_positive -and
    -not [bool]$xv1.technical_disposition.scientific_negative -and
    [bool]$xv1.immutability.same_identity_rerun_forbidden
) "$gateId no longer descends from immutable PH1, MV6, and XV1 closures"

. $gatePath
. $supervisorProjectionPath
$aggregatePreflight = Invoke-CrossEngineC6Bw19vDiscreteMaterialValidationXv2Preflight
Assert-Exact (
    [bool]$aggregatePreflight.ok -and
    [bool]$aggregatePreflight.perfect_synthetic_result_passed -and
    [bool]$aggregatePreflight.serialization_round_trip_passed -and
    [int]$aggregatePreflight.negative_control_count -eq 22 -and
    [bool]$aggregatePreflight.all_negative_controls_rejected -and
    [int]$aggregatePreflight.model_or_world_build_count -eq 0 -and
    -not [bool]$aggregatePreflight.physical_acceptance_authority
) "$gateId aggregate zero-world evaluator gate failed"

$projectionCanary = [ordered]@{
    preworld_real_controller_trace_projection_canary = [ordered]@{ ok = $true }
    preworld_engine_neutral_terminal_restoration_canary = [ordered]@{ ok = $true }
    preworld_production_kinematic_vector_representation_canary = [ordered]@{ ok = $true }
    preworld_material_xml_authoring_canary = [ordered]@{ ok = $true }
    preworld_shared_report_assembler_authority_schema_canary = [ordered]@{ ok = $true }
}
Assert-Exact (
    (Test-Xv2WorkerPreflightProjection `
        -Engine rapier `
        -WorkerReport ([ordered]@{ preflight = [ordered]@{ ok = $true } })) -and
    (Test-Xv2WorkerPreflightProjection `
        -Engine mujoco `
        -WorkerReport $projectionCanary)
) "$gateId exact supervisor projection rejected valid zero-world reports"
foreach ($mutation in @("missing", "false", "malformed", "non_boolean")) {
    $candidate = [ordered]@{}
    foreach ($entry in $projectionCanary.GetEnumerator()) {
        if (
            $entry.Key -ceq "preworld_material_xml_authoring_canary" -and
            $mutation -ceq "missing"
        ) {
            continue
        }
        $candidate[$entry.Key] = if (
            $entry.Key -cne "preworld_material_xml_authoring_canary"
        ) {
            $entry.Value
        }
        elseif ($mutation -ceq "false") { [ordered]@{ ok = $false } }
        elseif ($mutation -ceq "malformed") { "not_a_canary_map" }
        elseif ($mutation -ceq "non_boolean") { [ordered]@{ ok = "true" } }
        else { $entry.Value }
    }
    Assert-Exact (-not (Test-Xv2WorkerPreflightProjection `
        -Engine mujoco `
        -WorkerReport $candidate)) (
        "$gateId exact supervisor projection accepted $mutation MuJoCo input"
    )
}

$rapierSource = Get-Content -Raw -LiteralPath $rapierWorkerPath
$rapierLocomotionSource = Get-Content -Raw -LiteralPath $rapierLocomotionPath
$rapierCampaignStart = $rapierSource.IndexOf(
    "fn run_physical_report(", [StringComparison]::Ordinal
)
$rapierDeclarationCheck = $rapierSource.IndexOf(
    "declared_material_cell(cell_id, authored_friction, material_profile_id)?;",
    $rapierCampaignStart,
    [StringComparison]::Ordinal
)
$rapierPreflightCall = $rapierSource.IndexOf(
    "run_cross_engine_discrete_material_validation_xv2_rapier_preflight()?;",
    $rapierCampaignStart,
    [StringComparison]::Ordinal
)
$rapierWorldBuilder = $rapierSource.IndexOf(
    "build_bw19v_velocity_only_v4_robot_with_friction",
    $rapierCampaignStart,
    [StringComparison]::Ordinal
)
Assert-Exact (
    $rapierCampaignStart -ge 0 -and
    $rapierDeclarationCheck -gt $rapierCampaignStart -and
    $rapierPreflightCall -gt $rapierDeclarationCheck -and
    $rapierWorldBuilder -gt $rapierPreflightCall -and
    $rapierLocomotionSource.Contains(
        "build_bw19v_velocity_only_v4_robot_with_friction",
        [StringComparison]::Ordinal
    ) -and
    [regex]::IsMatch(
        $rapierLocomotionSource,
        "BW19V_AUTHORED_FRICTION,\r?\n\s+HostMotorProfile::CanonicalVelocityOnlyV4"
    )
) "$gateId Rapier declared-material or retained-constructor isolation changed"

$mujocoSource = Get-Content -Raw -LiteralPath $mujocoWorkerPath
$mujocoBridgeSource = Get-Content -Raw -LiteralPath $mujocoBridgePath
$mujocoBaselineBridgeSource = Get-Content -Raw -LiteralPath $mujocoBaselineBridgePath
$mujocoCampaignStart = $mujocoSource.IndexOf(
    "def run_campaign(", [StringComparison]::Ordinal
)
$mujocoDeclarationCheck = $mujocoSource.IndexOf(
    "friction_vector = _declared_material_cell(",
    $mujocoCampaignStart,
    [StringComparison]::Ordinal
)
$mujocoPreflightCall = $mujocoSource.IndexOf(
    "preflight = run_preflight()",
    $mujocoCampaignStart,
    [StringComparison]::Ordinal
)
$mujocoWorldBuilder = $mujocoSource.IndexOf(
    "robot = material_bridge.MujocoBw19vRobot(",
    $mujocoCampaignStart,
    [StringComparison]::Ordinal
)
Assert-Exact (
    $mujocoCampaignStart -ge 0 -and
    $mujocoDeclarationCheck -gt $mujocoCampaignStart -and
    $mujocoPreflightCall -gt $mujocoDeclarationCheck -and
    $mujocoWorldBuilder -gt $mujocoPreflightCall -and
    (Get-RawSha256 $mujocoBaselineBridgePath) -ceq
        "306669481601cc91c8146e84a202a57228672e23c3f9daa0c531d2eb9d077e46" -and
    $mujocoBaselineBridgeSource.Contains(
        '"friction": f"{AUTHORED_FRICTION:.17g} .005 .0001"',
        [StringComparison]::Ordinal
    ) -and
    $mujocoBridgeSource.Contains(
        "class MujocoBw19vRobot(baseline.MujocoBw19vRobot):",
        [StringComparison]::Ordinal
    ) -and
    $mujocoBridgeSource.Contains(
        'named_geoms[geom_name].set("friction", encoded_vector)',
        [StringComparison]::Ordinal
    )
) "$gateId MuJoCo declared-material or immutable-baseline isolation changed"

$pythonCanary = @'
import json
from sporespore_mujoco_adapter import selected_policy_development as bridge
from sporespore_mujoco_adapter import cross_engine_discrete_material_validation_xv2_bridge as material_bridge
from sporespore_mujoco_adapter import cross_engine_discrete_material_validation_xv2_mujoco as xv2

undeclared_rejected = False
try:
    xv2._declared_material_cell("mujoco_mu999", 0.2, "mujoco_bw19v_xv2_mu020_v1")
except ValueError:
    undeclared_rejected = True
print(json.dumps({
    "default": (bridge.AUTHORED_FRICTION, 0.005, 0.0001),
    "explicit": material_bridge.validated_friction_vector((0.2, 0.0, 0.0)),
    "declared": xv2._declared_material_cell(
        "mujoco_mu020", 0.2, "mujoco_bw19v_xv2_mu020_v1"
    ),
    "undeclared_rejected": undeclared_rejected,
    "boolean_is_not_finite": not xv2._finite(True),
}))
'@
Push-Location -LiteralPath $mujocoRoot
try {
    $pythonCanaryLines = @(& $python -c $pythonCanary)
    Assert-Exact ($LASTEXITCODE -eq 0) "$gateId MuJoCo zero-model material canary failed"
}
finally {
    Pop-Location
}
$pythonCanaryResult = ($pythonCanaryLines -join [Environment]::NewLine) |
    ConvertFrom-Json -AsHashtable
Assert-Exact (
    (@($pythonCanaryResult.default) -join "|") -ceq "0.95|0.005|0.0001" -and
    (@($pythonCanaryResult.explicit) -join "|") -ceq "0.2|0|0" -and
    (@($pythonCanaryResult.declared) -join "|") -ceq "0.2|0|0" -and
    [bool]$pythonCanaryResult.undeclared_rejected -and
    [bool]$pythonCanaryResult.boolean_is_not_finite
) "$gateId MuJoCo retained default or explicit material-vector boundary changed"

$runnerSource = Get-Content -Raw -LiteralPath $runnerPath
$supervisorProjectionSource = Get-Content -Raw -LiteralPath $supervisorProjectionPath
foreach ($needle in @(
    "all_six_cell_attempts_are_made_even_if_an_earlier_cell_fails",
    "Enter-SporeSporeLocomotionOperationLock -Role physical",
    "Test-SporeSporeFullConformanceAttestationFile",
    "INTEGRITY_ABORT_NO_WORLD_OPENED",
    "supervisor_failed_after_identity_consumption",
    "supervisor_projection_raw_sha256",
    "Test-Xv2WorkerPreflightProjection",
    "missing_mujoco_canary_rejected",
    "non_boolean_mujoco_ok_rejected",
    "same_identity_rerun_allowed = `$false",
    "ls-remote origin refs/heads/main",
    "-WindowStyle Hidden",
    "SporeSpore_Evidence"
)) {
    Assert-Exact ($runnerSource.Contains($needle, [StringComparison]::Ordinal)) (
        "$gateId runner lost fail-closed lifecycle surface: $needle"
    )
}
Assert-Exact (
    $supervisorProjectionSource.Contains(
        "function Test-Xv2WorkerPreflightProjection",
        [StringComparison]::Ordinal
    ) -and
    ([regex]::Matches($runnerSource, "(?m)^\s*-and\s*$")).Count -eq 0 -and
    ([regex]::Matches($supervisorProjectionSource, "(?m)^\s*-and\s*$")).Count -eq 0
) "$gateId supervisor projection regressed to runtime-only standalone operators"

$priorAttempts = @()
if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
    $priorAttempts = @(
        Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File -Filter "attempt.json" |
        Where-Object {
            try {
                $attempt = Get-Content -Raw -LiteralPath $_.FullName |
                    ConvertFrom-Json
                [string]$attempt.campaign_id -ceq $campaignId
            }
            catch { $false }
        }
    )
}
Assert-Exact ($priorAttempts.Count -eq 0) (
    "$gateId already has a retained physical attempt and is not prospective"
)
$evidenceBefore = @(Get-CampaignEvidenceDirectories)
$refusalOutput = & pwsh `
    -NoLogo `
    -NoProfile `
    -File $runnerPath `
    -RunPhysical 2>&1 | Out-String
$refusalExitCode = $LASTEXITCODE
$evidenceAfterRefusal = @(Get-CampaignEvidenceDirectories)
Assert-Exact (
    $refusalExitCode -ne 0 -and
    $refusalOutput.Contains(
        "$gateId -RunPhysical requires an exact full-Godot V2 attestation"
    ) -and
    ($evidenceAfterRefusal -join "`n") -ceq ($evidenceBefore -join "`n")
) "$gateId unqualified physical mode was not refused before evidence creation"

$preflightOutput = & pwsh `
    -NoLogo `
    -NoProfile `
    -File $runnerPath `
    -PreflightOnly 2>&1 | Out-String
$preflightExitCode = $LASTEXITCODE
$evidenceAfterPreflight = @(Get-CampaignEvidenceDirectories)
Assert-Exact (
    $preflightExitCode -eq 0 -and
    $preflightOutput.Contains(
        "C6_XE_BW19V_XV2_FREEZE_PASS worlds=0 aggregate=22 " +
        "rapier=38 mujoco=57 supervisor=4 material_cells=6 physical_authority=False"
    ) -and
    ($evidenceAfterPreflight -join "`n") -ceq ($evidenceBefore -join "`n")
) "$gateId complete supervisor zero-world preflight failed or touched evidence"

& cargo test `
    --manifest-path (Join-Path $sdkRoot "Cargo.toml") `
    -p sporespore-rapier-adapter `
    --lib `
    cross_engine_discrete_material_validation_xv2_rapier::tests::undeclared_material_identity_is_rejected_before_world_construction
Assert-Exact ($LASTEXITCODE -eq 0) (
    "$gateId Rapier undeclared-material zero-world unit test failed"
)

Write-Host (
    "C6_XE_BW19V_XV2_FREEZE_AUDIT_PASS worlds=0 cells=6 aggregate=22 " +
    "rapier=38 mujoco=57 supervisor=4 retained_default=True physical_authority=False"
)

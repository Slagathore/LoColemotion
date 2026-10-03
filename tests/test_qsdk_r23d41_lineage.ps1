#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$records = @(
    [ordered]@{
        key = "rapier_validation_closure_raw_sha256"
        file = "r23d32_finite_rapier_turning_replication_closure_v1.json"
        sha256 = "sha256:40c7f4797916a5780d331f2676b2956875a35f28f79ef2043db30fef0eb09c93"
        status = "closed_valid_complete_positive_finite_rapier_turning_validation"
        claim = "finite_rapier_turning_validation"
    },
    [ordered]@{
        key = "godot_validation_closure_raw_sha256"
        file = "r23d35_godot_trace_recovery_closure_v1.json"
        sha256 = "sha256:6f96ed00593ead67a118d1c07a6c54fb8f5892aa2599a121fd59c1f2efb6f148"
        status = "closed_valid_complete_positive_finite_godot_jolt_r23d29_turning"
        claim = "finite_godot_jolt_turning"
    },
    [ordered]@{
        key = "mujoco_development_closure_raw_sha256"
        file = "r23d39_mujoco_startup_ramp_turning_closure_v1.json"
        sha256 = "sha256:5e61c8daca4a9bfe1a10e7d4e520b4207b3acccce173f408fd9723d75305802a"
        status = "closed_consumed_valid_complete_positive_mujoco_startup_ramp_turning_development"
        claim = "mujoco_r23d29_turning"
    },
    [ordered]@{
        key = "measurement_closure_raw_sha256"
        file = "r23d31_cycle_integrated_directional_response_closure_v1.json"
        sha256 = "sha256:364f44e3a974d81e6b98073e02e4c46abf927cbabed933d0d1aae706e5890b4c"
        status = "closed_valid_complete_positive_measurement_validation_candidate"
        claim = "finite_rapier_cycle_integrated_measurement_validation"
    },
    [ordered]@{
        key = "implementation_invalid_predecessor_closure_raw_sha256"
        file = "r23d40_three_engine_startup_ramp_turning_closure_v1.json"
        sha256 = "sha256:3ffa024c0c704e3c93ee42cbf6bd06d57cb80529a499e4bfb4203301f42be801"
        status = "closed_consumed_invalid_complete_rapier_godot_authorization_with_valid_mujoco_turning_positive"
        claim = "mujoco_seed_21508_walking_and_turning"
    }
)

function Assert-R23D41Lineage([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D41 LINEAGE: $Message" }
}

function Get-R23D41Hash([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

Assert-R23D41Lineage (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$preregistrationPath = Join-Path $turningRoot (
    "r23d41_three_engine_startup_ramp_turning_preregistration_v1.json"
)
$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
foreach ($record in $records) {
    $path = Join-Path $turningRoot ([string]$record.file)
    Assert-R23D41Lineage (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-R23D41Hash $path) -ceq [string]$record.sha256 -and
        [string]$preregistration.immutable_lineage[[string]$record.key] -ceq
            [string]$record.sha256
    ) "closure bytes or preregistered digest changed: $($record.file)"
    $closure = Get-Content -Raw -LiteralPath $path |
        ConvertFrom-Json -AsHashtable -Depth 100
    $claim = [string]$record.claim
    Assert-R23D41Lineage (
        [string]$closure.status -ceq [string]$record.status -and
        [bool]$closure.identity_consumed -and
        -not [bool]$closure.same_identity_rerun_allowed -and
        [bool]$closure.claims[$claim] -and
        -not [bool]$closure.claims.cross_engine_equivalence -and
        -not [bool]$closure.claims.release_authorized
    ) "closure claim boundary changed: $($record.file)"
}

Assert-R23D41Lineage (
    [string]$preregistration.status -ceq "prospective_zero_world_only" -and
    [int]$preregistration.frozen_matrix.seed -eq 21509 -and
    [int]$preregistration.frozen_matrix.declared_world_count -eq 9 -and
    [bool]$preregistration.frozen_matrix.serial_execution_required -and
    [bool]$preregistration.frozen_matrix.all_cells_run_regardless_of_intermediate_outcome -and
    [bool]$preregistration.immutable_lineage.r23d40_identity_consumed -and
    -not [bool]$preregistration.immutable_lineage.r23d40_same_identity_rerun_permitted -and
    [int]$preregistration.scientifically_distinct_successor.implementation_change_count -eq 2 -and
    -not [bool]$preregistration.claims.finite_three_engine_turning -and
    -not [bool]$preregistration.claims.cross_engine_equivalence
) "prospective R23D41 boundary changed"

Write-Host (
    "QSDK_R23D41_LINEAGE_PASS closures=5 seed=21509 worlds=9 " +
    "separate_engine_positives=True cross_engine=False physical=False"
)

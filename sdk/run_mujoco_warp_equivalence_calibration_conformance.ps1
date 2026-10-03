[CmdletBinding()]
param(
    [string]$Output = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$contractPath = Join-Path (
    $sdkRoot
) "adaptation_provider\mujoco_warp_equivalence_calibration_contract_v1.json"

function Assert-Mjcal {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "MJCAL_RUNNER $Message" }
}

Assert-Mjcal (
    Test-Path -LiteralPath $contractPath -PathType Leaf
) "calibration protocol contract is missing: $contractPath"
$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -Depth 64
Assert-Mjcal (
    $contract.schema_version -ceq
        "sporespore_mujoco_warp_equivalence_calibration_contract_v1" -and
    $contract.status -ceq
        "prospective_zero_world_protocol_source_only_production_plan_absent" -and
    $contract.question_class -ceq "development" -and
    -not [bool]$contract.production_plan_requirements.production_plan_exists -and
    -not [bool]$contract.production_plan_requirements.physical_calibration_series_open -and
    -not [bool]$contract.production_plan_requirements.heldout_qualification_series_open -and
    [int]$contract.source_conformance.model_construction_count -eq 0 -and
    [int]$contract.source_conformance.step_invocation_count -eq 0 -and
    [int]$contract.source_conformance.world_attempt_count -eq 0 -and
    [int]$contract.source_conformance.world_build_count -eq 0
) "contract identity, zero-world boundary, or series seal changed"
foreach ($claim in $contract.claims.psobject.Properties) {
    Assert-Mjcal (-not [bool]$claim.Value) "contract claim became true: $($claim.Name)"
}

Push-Location -LiteralPath $sdkRoot
try {
    & python -m unittest -v `
        adaptation_provider.test_mujoco_warp_equivalence_calibration
    Assert-Mjcal (
        $LASTEXITCODE -eq 0
    ) "calibration protocol tests failed with exit code $LASTEXITCODE"

    $arguments = @(
        "-m",
        "adaptation_provider.mujoco_warp_equivalence_calibration_conformance"
    )
    if (-not [string]::IsNullOrWhiteSpace($Output)) {
        $outputPath = [System.IO.Path]::GetFullPath($Output)
        Assert-Mjcal (
            [System.IO.Path]::GetFileName($outputPath) -ceq "report.json"
        ) "calibration report filename must be report.json"
        Assert-Mjcal (
            -not (Test-Path -LiteralPath $outputPath)
        ) "refusing to overwrite calibration report: $outputPath"
        $arguments += @("--output", $outputPath)
    }
    & python @arguments
    Assert-Mjcal (
        $LASTEXITCODE -eq 0
    ) "calibration report compiler failed with exit code $LASTEXITCODE"
} finally {
    Pop-Location
}

if (-not [string]::IsNullOrWhiteSpace($Output)) {
    $retainedPath = [System.IO.Path]::GetFullPath($Output)
    Assert-Mjcal (
        Test-Path -LiteralPath $retainedPath -PathType Leaf
    ) "calibration report was not retained: $retainedPath"
    $retained = Get-Content -LiteralPath $retainedPath -Raw |
        ConvertFrom-Json -Depth 64
    Assert-Mjcal (
        $retained.schema_version -ceq
            "sporespore_mujoco_warp_equivalence_calibration_conformance_report_v1" -and
        [bool]$retained.ok -and
        [int]$retained.passed_cells -eq 8 -and
        [int]$retained.failed_cells -eq 0 -and
        [int]$retained.minimum_unique_calibration_condition_groups -eq 59 -and
        [int]$retained.minimum_unique_heldout_condition_groups -eq 59 -and
        [int]$retained.mutation_control_count -ge 10 -and
        [bool]$retained.positive_and_negative_calibration_fixtures_retained -and
        [bool]$retained.fixture_only -and
        -not [bool]$retained.production_plan_frozen -and
        -not [bool]$retained.calibration_executed -and
        -not [bool]$retained.production_margins_frozen -and
        -not [bool]$retained.heldout_execution_authorized -and
        [int]$retained.model_construction_count -eq 0 -and
        [int]$retained.step_invocation_count -eq 0 -and
        [int]$retained.world_attempt_count -eq 0 -and
        [int]$retained.world_build_count -eq 0 -and
        -not [bool]$retained.physics_state_modified -and
        -not [bool]$retained.scientific_result -and
        -not [bool]$retained.physical_acceptance_authority -and
        -not [bool]$retained.release_authority
    ) "retained calibration report failed its terminal contract"
    Write-Host "MuJoCo-Warp calibration protocol evidence retained: $retainedPath"
}

Write-Host (
    "MJCAL_CONFORMANCE_PASS cells=8 calibration_min=59 heldout_min=59 " +
    "worlds=0 calibration=false margins=false qualification=false"
)

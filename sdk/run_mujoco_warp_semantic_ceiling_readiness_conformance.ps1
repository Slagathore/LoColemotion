[CmdletBinding()]
param(
    [string]$Output = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$contractPath = Join-Path (
    $sdkRoot
) "adaptation_provider\mujoco_warp_semantic_ceiling_readiness_contract_v1.json"

function Assert-Mjsc {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "MJSC_RUNNER $Message" }
}

Assert-Mjsc (
    Test-Path -LiteralPath $contractPath -PathType Leaf
) "semantic-ceiling readiness contract is missing: $contractPath"
$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -Depth 64
Assert-Mjsc (
    $contract.schema_version -ceq
        "sporespore_mujoco_warp_semantic_ceiling_readiness_contract_v1" -and
    $contract.status -ceq
        "zero_world_source_only_all_production_semantic_ceilings_unresolved" -and
    $contract.question_class -ceq "development" -and
    [int]$contract.current_inventory.accepted_production_source_count -eq 0 -and
    [int]$contract.current_inventory.unresolved_metric_count -eq 5 -and
    -not [bool]$contract.current_inventory.production_plan_exists -and
    -not [bool]$contract.current_inventory.production_margins_frozen -and
    -not [bool]$contract.current_inventory.calibration_authorized -and
    [int]$contract.source_conformance.model_construction_count -eq 0 -and
    [int]$contract.source_conformance.step_invocation_count -eq 0 -and
    [int]$contract.source_conformance.world_attempt_count -eq 0 -and
    [int]$contract.source_conformance.world_build_count -eq 0
) "contract identity, unresolved inventory, or zero-world boundary changed"
foreach ($claim in $contract.claims.psobject.Properties) {
    Assert-Mjsc (-not [bool]$claim.Value) "contract claim became true: $($claim.Name)"
}

Push-Location -LiteralPath $sdkRoot
try {
    & python -m unittest -v `
        adaptation_provider.test_mujoco_warp_semantic_ceiling_readiness
    Assert-Mjsc (
        $LASTEXITCODE -eq 0
    ) "semantic-ceiling readiness tests failed with exit code $LASTEXITCODE"

    $arguments = @(
        "-m",
        "adaptation_provider.mujoco_warp_semantic_ceiling_readiness_conformance"
    )
    if (-not [string]::IsNullOrWhiteSpace($Output)) {
        $outputPath = [System.IO.Path]::GetFullPath($Output)
        Assert-Mjsc (
            [System.IO.Path]::GetFileName($outputPath) -ceq "report.json"
        ) "semantic-ceiling report filename must be report.json"
        Assert-Mjsc (
            -not (Test-Path -LiteralPath $outputPath)
        ) "refusing to overwrite semantic-ceiling report: $outputPath"
        $arguments += @("--output", $outputPath)
    }
    & python @arguments
    Assert-Mjsc (
        $LASTEXITCODE -eq 0
    ) "semantic-ceiling report compiler failed with exit code $LASTEXITCODE"
} finally {
    Pop-Location
}

if (-not [string]::IsNullOrWhiteSpace($Output)) {
    $retainedPath = [System.IO.Path]::GetFullPath($Output)
    Assert-Mjsc (
        Test-Path -LiteralPath $retainedPath -PathType Leaf
    ) "semantic-ceiling report was not retained: $retainedPath"
    $retained = Get-Content -LiteralPath $retainedPath -Raw |
        ConvertFrom-Json -Depth 64
    Assert-Mjsc (
        $retained.schema_version -ceq
            "sporespore_mujoco_warp_semantic_ceiling_conformance_report_v1" -and
        [bool]$retained.ok -and
        [int]$retained.passed_cells -eq 8 -and
        [int]$retained.failed_cells -eq 0 -and
        [int]$retained.mutation_control_count -eq 25 -and
        [int]$retained.required_metric_count -eq 5 -and
        [int]$retained.accepted_production_source_count -eq 0 -and
        [int]$retained.unresolved_metric_count -eq 5 -and
        [bool]$retained.all_unresolved_reasons_retained -and
        [int]$retained.positive_fixture_accepted_source_count -eq 5 -and
        [bool]$retained.fixture_only -and
        -not [bool]$retained.production_semantic_ceiling_sources_complete -and
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
    ) "retained semantic-ceiling report failed its terminal contract"
    Write-Host "MuJoCo-Warp semantic-ceiling evidence retained: $retainedPath"
}

Write-Host (
    "MJSC_CONFORMANCE_PASS cells=8 mutations=25 metrics=5 accepted=0 " +
    "unresolved=5 worlds=0 plan=false margins=false calibration=false"
)

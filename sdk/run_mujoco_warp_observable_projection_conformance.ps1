[CmdletBinding()]
param(
    [string]$Output = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $sdkRoot ".."))
$evidenceRoot = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)
$contractPath = Join-Path (
    $sdkRoot
) "adaptation_provider\mujoco_warp_observable_projection_contract_v1.json"

function Assert-Mjop {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "MJOP_RUNNER $Message" }
}

Assert-Mjop (
    Test-Path -LiteralPath $contractPath -PathType Leaf
) "observable-projection contract is missing: $contractPath"
$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -Depth 64
$contractHash = "sha256:" + (
    Get-FileHash -LiteralPath $contractPath -Algorithm SHA256
).Hash.ToLowerInvariant()
Assert-Mjop (
    $contract.schema_version -ceq
        "sporespore_mujoco_warp_observable_projection_contract_v1" -and
    $contract.status -ceq
        "zero_world_source_only_production_topology_bindings_unresolved" -and
    $contract.question_class -ceq "development" -and
    [int]$contract.current_inventory.required_initial_topology_binding_count -eq 1 -and
    [int]$contract.current_inventory.production_topology_binding_count -eq 0 -and
    [int]$contract.current_inventory.unresolved_topology_binding_count -eq 1 -and
    -not [bool]$contract.current_inventory.production_native_observable_binding_complete -and
    [int]$contract.current_inventory.production_metric_definition_count -eq 0 -and
    -not [bool]$contract.current_inventory.production_metric_semantics_complete -and
    -not [bool]$contract.current_inventory.production_plan_exists -and
    -not [bool]$contract.current_inventory.calibration_authorized -and
    [int]$contract.source_conformance.exact_control_count -eq 48 -and
    [int]$contract.source_conformance.minimum_rejected_mutation_count -eq 24 -and
    [int]$contract.source_conformance.model_construction_count -eq 0 -and
    [int]$contract.source_conformance.step_invocation_count -eq 0 -and
    [int]$contract.source_conformance.world_attempt_count -eq 0 -and
    [int]$contract.source_conformance.world_build_count -eq 0 -and
    -not [bool]$contract.source_conformance.physics_state_modified
) "contract identity, incomplete inventory, controls, or zero-world boundary changed"
foreach ($claim in $contract.claims.psobject.Properties) {
    Assert-Mjop (-not [bool]$claim.Value) "contract claim became true: $($claim.Name)"
}

$retainedSourceHead = ""
$retainedSourceOrigin = ""

Push-Location -LiteralPath $repoRoot
try {
    & python -m unittest -v `
        sdk.adaptation_provider.test_mujoco_warp_observable_projection
    Assert-Mjop (
        $LASTEXITCODE -eq 0
    ) "observable-projection tests failed with exit code $LASTEXITCODE"

    $arguments = @(
        "-m",
        "sdk.adaptation_provider.mujoco_warp_observable_projection_conformance"
    )
    if (-not [string]::IsNullOrWhiteSpace($Output)) {
        $outputPath = [System.IO.Path]::GetFullPath($Output)
        $evidencePrefix = $evidenceRoot.TrimEnd(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        ) + [System.IO.Path]::DirectorySeparatorChar
        Assert-Mjop (
            $outputPath.StartsWith(
                $evidencePrefix,
                [System.StringComparison]::OrdinalIgnoreCase
            )
        ) "observable-projection report must be retained under $evidenceRoot"
        Assert-Mjop (
            [System.IO.Path]::GetFileName($outputPath) -ceq "report.json"
        ) "observable-projection report filename must be report.json"
        Assert-Mjop (
            -not (Test-Path -LiteralPath $outputPath)
        ) "refusing to overwrite observable-projection report: $outputPath"

        $sourceRoot = [System.IO.Path]::GetFullPath(
            (& git -C $repoRoot rev-parse --show-toplevel).Trim()
        )
        Assert-Mjop ($LASTEXITCODE -eq 0) "cannot resolve source root"
        $sourceRemote = (& git -C $repoRoot remote get-url origin).Trim()
        Assert-Mjop ($LASTEXITCODE -eq 0) "cannot resolve source remote"
        $sourceBranch = (& git -C $repoRoot branch --show-current).Trim()
        Assert-Mjop ($LASTEXITCODE -eq 0) "cannot resolve source branch"
        $retainedSourceHead = (& git -C $repoRoot rev-parse HEAD).Trim()
        Assert-Mjop ($LASTEXITCODE -eq 0) "cannot resolve source HEAD"
        $retainedSourceOrigin = (& git -C $repoRoot rev-parse origin/main).Trim()
        Assert-Mjop ($LASTEXITCODE -eq 0) "cannot resolve local origin/main"
        $liveRemoteLines = @(
            & git -C $repoRoot ls-remote origin refs/heads/main
        )
        Assert-Mjop (
            $LASTEXITCODE -eq 0 -and $liveRemoteLines.Count -eq 1
        ) "cannot resolve live origin/main"
        $liveRemoteHead = ($liveRemoteLines[0] -split "\s+")[0]
        $sourceStatus = @(
            & git -C $repoRoot status --porcelain=v1 --untracked-files=all
        )
        Assert-Mjop ($LASTEXITCODE -eq 0) "cannot inspect source worktree"
        Assert-Mjop (
            $sourceRoot -ceq $repoRoot -and
            $sourceRemote -ceq "https://github.com/Slagathore/sporespore.git" -and
            $sourceBranch -ceq "main" -and
            $retainedSourceHead -ceq $retainedSourceOrigin -and
            $retainedSourceHead -ceq $liveRemoteHead -and
            $sourceStatus.Count -eq 0
        ) "retained report requires exact clean pushed live source"
        $arguments += @("--output", $outputPath)
    }
    & python @arguments
    Assert-Mjop (
        $LASTEXITCODE -eq 0
    ) "observable-projection compiler failed with exit code $LASTEXITCODE"
} finally {
    Pop-Location
}

if (-not [string]::IsNullOrWhiteSpace($Output)) {
    $retainedPath = [System.IO.Path]::GetFullPath($Output)
    Assert-Mjop (
        Test-Path -LiteralPath $retainedPath -PathType Leaf
    ) "observable-projection report was not retained: $retainedPath"
    $retained = Get-Content -LiteralPath $retainedPath -Raw |
        ConvertFrom-Json -Depth 64
    $retainedControls = @($retained.controls.psobject.Properties)
    $retainedRejected = @($retained.rejected_mutations.psobject.Properties)
    Assert-Mjop (
        $retained.schema_version -ceq
            "sporespore_mujoco_warp_observable_projection_conformance_report_v1" -and
        [bool]$retained.ok -and
        [int]$retained.passed_cells -eq 8 -and
        [int]$retained.failed_cells -eq 0 -and
        [int]$retained.control_count -eq 48 -and
        $retainedControls.Count -eq 48 -and
        [int]$retained.rejected_mutation_count -eq 24 -and
        $retainedRejected.Count -eq 24 -and
        [string]$retained.contract_raw_sha256 -ceq $contractHash -and
        [bool]$retained.source.clean -and
        [bool]$retained.source.matches_origin_main -and
        [string]$retained.source.commit -ceq $retainedSourceHead -and
        [string]$retained.source.origin_main -ceq $retainedSourceOrigin -and
        @($retained.source.status_entries).Count -eq 0 -and
        [int]$retained.fixture.metric_count -eq 5 -and
        [int]$retained.fixture.contact_event_count_per_role -eq 4 -and
        [int]$retained.fixture.contact_event_time_error_steps -eq 1 -and
        [bool]$retained.fixture.fixture_only -and
        -not [bool]$retained.fixture.production_authority -and
        [int]$retained.production_topology_binding_count -eq 0 -and
        [int]$retained.unresolved_topology_binding_count -eq 1 -and
        -not [bool]$retained.production_native_observable_binding_complete -and
        [int]$retained.production_metric_definition_count -eq 0 -and
        -not [bool]$retained.production_metric_semantics_complete -and
        -not [bool]$retained.production_semantic_ceiling_sources_complete -and
        -not [bool]$retained.production_plan_exists -and
        -not [bool]$retained.calibration_authorized -and
        -not [bool]$retained.supported_physics_subset_qualified -and
        -not [bool]$retained.training_data_authority -and
        -not [bool]$retained.training_plane_authorized -and
        -not [bool]$retained.native_mujoco_equivalence -and
        -not [bool]$retained.cross_engine_equivalence -and
        [int]$retained.model_construction_count -eq 0 -and
        [int]$retained.step_invocation_count -eq 0 -and
        [int]$retained.world_attempt_count -eq 0 -and
        [int]$retained.world_build_count -eq 0 -and
        -not [bool]$retained.physics_state_modified -and
        -not [bool]$retained.scientific_result -and
        -not [bool]$retained.physical_acceptance_authority -and
        -not [bool]$retained.release_authority
    ) "retained observable-projection report failed its terminal contract"
    foreach ($control in $retainedControls) {
        Assert-Mjop (
            [bool]$control.Value
        ) "retained observable-projection control is false: $($control.Name)"
    }
    Write-Host "MuJoCo-Warp observable-projection evidence retained: $retainedPath"
}

Write-Host (
    "MJOP_CONFORMANCE_PASS cells=8 controls=48 rejected=24 metrics=5 " +
    "bindings=0 unresolved=1 models=0 steps=0 worlds=0 " +
    "plan=false calibration=false"
)

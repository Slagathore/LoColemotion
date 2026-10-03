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
) "adaptation_provider\mujoco_warp_metric_semantics_contract_v1.json"

function Assert-Mjms {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "MJMS_RUNNER $Message" }
}

Assert-Mjms (
    Test-Path -LiteralPath $contractPath -PathType Leaf
) "metric-semantics contract is missing: $contractPath"
$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -Depth 64
$contractHash = "sha256:" + (
    Get-FileHash -LiteralPath $contractPath -Algorithm SHA256
).Hash.ToLowerInvariant()
Assert-Mjms (
    $contract.schema_version -ceq
        "sporespore_mujoco_warp_metric_semantics_contract_v1" -and
    $contract.status -ceq
        "zero_world_source_only_all_production_metric_semantics_unresolved" -and
    $contract.question_class -ceq "development" -and
    [int]$contract.current_inventory.production_metric_definition_count -eq 0 -and
    [int]$contract.current_inventory.unresolved_metric_count -eq 5 -and
    -not [bool]$contract.current_inventory.production_metric_semantics_complete -and
    -not [bool]$contract.current_inventory.production_plan_exists -and
    -not [bool]$contract.current_inventory.calibration_authorized -and
    [int]$contract.source_conformance.exact_mutation_control_count -eq 52 -and
    [int]$contract.source_conformance.model_construction_count -eq 0 -and
    [int]$contract.source_conformance.step_invocation_count -eq 0 -and
    [int]$contract.source_conformance.world_attempt_count -eq 0 -and
    [int]$contract.source_conformance.world_build_count -eq 0
) "contract identity, unresolved inventory, controls, or zero-world boundary changed"
foreach ($claim in $contract.claims.psobject.Properties) {
    Assert-Mjms (-not [bool]$claim.Value) "contract claim became true: $($claim.Name)"
}

$retainedSourceHead = ""
$retainedSourceOrigin = ""

Push-Location -LiteralPath $sdkRoot
try {
    & python -m unittest -v adaptation_provider.test_mujoco_warp_metric_semantics
    Assert-Mjms (
        $LASTEXITCODE -eq 0
    ) "metric-semantics tests failed with exit code $LASTEXITCODE"

    $arguments = @(
        "-m",
        "adaptation_provider.mujoco_warp_metric_semantics_conformance"
    )
    if (-not [string]::IsNullOrWhiteSpace($Output)) {
        $outputPath = [System.IO.Path]::GetFullPath($Output)
        $evidencePrefix = $evidenceRoot.TrimEnd(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        ) + [System.IO.Path]::DirectorySeparatorChar
        Assert-Mjms (
            $outputPath.StartsWith(
                $evidencePrefix,
                [System.StringComparison]::OrdinalIgnoreCase
            )
        ) "metric-semantics report must be retained under $evidenceRoot"
        Assert-Mjms (
            [System.IO.Path]::GetFileName($outputPath) -ceq "report.json"
        ) "metric-semantics report filename must be report.json"
        Assert-Mjms (
            -not (Test-Path -LiteralPath $outputPath)
        ) "refusing to overwrite metric-semantics report: $outputPath"

        $sourceRoot = [System.IO.Path]::GetFullPath(
            (& git -C $repoRoot rev-parse --show-toplevel).Trim()
        )
        Assert-Mjms ($LASTEXITCODE -eq 0) "cannot resolve source root"
        $sourceRemote = (& git -C $repoRoot remote get-url origin).Trim()
        Assert-Mjms ($LASTEXITCODE -eq 0) "cannot resolve source remote"
        $sourceBranch = (& git -C $repoRoot branch --show-current).Trim()
        Assert-Mjms ($LASTEXITCODE -eq 0) "cannot resolve source branch"
        $retainedSourceHead = (& git -C $repoRoot rev-parse HEAD).Trim()
        Assert-Mjms ($LASTEXITCODE -eq 0) "cannot resolve source HEAD"
        $retainedSourceOrigin = (& git -C $repoRoot rev-parse origin/main).Trim()
        Assert-Mjms ($LASTEXITCODE -eq 0) "cannot resolve local origin/main"
        $liveRemoteLines = @(
            & git -C $repoRoot ls-remote origin refs/heads/main
        )
        Assert-Mjms (
            $LASTEXITCODE -eq 0 -and $liveRemoteLines.Count -eq 1
        ) "cannot resolve live origin/main"
        $liveRemoteHead = ($liveRemoteLines[0] -split "\s+")[0]
        $sourceStatus = @(
            & git -C $repoRoot status --porcelain=v1 --untracked-files=all
        )
        Assert-Mjms ($LASTEXITCODE -eq 0) "cannot inspect source worktree"
        Assert-Mjms (
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
    Assert-Mjms (
        $LASTEXITCODE -eq 0
    ) "metric-semantics report compiler failed with exit code $LASTEXITCODE"
} finally {
    Pop-Location
}

if (-not [string]::IsNullOrWhiteSpace($Output)) {
    $retainedPath = [System.IO.Path]::GetFullPath($Output)
    Assert-Mjms (
        Test-Path -LiteralPath $retainedPath -PathType Leaf
    ) "metric-semantics report was not retained: $retainedPath"
    $retained = Get-Content -LiteralPath $retainedPath -Raw |
        ConvertFrom-Json -Depth 64
    $retainedControls = @(
        $retained.rejected_mutations.psobject.Properties
    )
    Assert-Mjms (
        $retained.schema_version -ceq
            "sporespore_mujoco_warp_metric_semantics_conformance_report_v1" -and
        [bool]$retained.ok -and
        [int]$retained.passed_cells -eq 8 -and
        [int]$retained.failed_cells -eq 0 -and
        [int]$retained.mutation_control_count -eq 52 -and
        $retainedControls.Count -eq 52 -and
        [string]$retained.contract_raw_sha256 -ceq $contractHash -and
        [bool]$retained.source.clean -and
        [bool]$retained.source.matches_origin_main -and
        [string]$retained.source.commit -ceq $retainedSourceHead -and
        [string]$retained.source.origin_main -ceq $retainedSourceOrigin -and
        @($retained.source.status_entries).Count -eq 0 -and
        [int]$retained.required_metric_count -eq 5 -and
        [int]$retained.production_metric_definition_count -eq 0 -and
        [int]$retained.unresolved_metric_count -eq 5 -and
        [bool]$retained.all_unresolved_reasons_retained -and
        [int]$retained.positive_fixture_metric_count -eq 5 -and
        [bool]$retained.fixture_only -and
        -not [bool]$retained.production_metric_semantics_complete -and
        -not [bool]$retained.production_semantic_ceiling_sources_complete -and
        -not [bool]$retained.production_plan_frozen -and
        -not [bool]$retained.calibration_executed -and
        -not [bool]$retained.production_margins_frozen -and
        -not [bool]$retained.heldout_execution_authorized -and
        -not [bool]$retained.supported_physics_subset_qualified -and
        -not [bool]$retained.training_data_authority -and
        -not [bool]$retained.training_plane_authorized -and
        [int]$retained.model_construction_count -eq 0 -and
        [int]$retained.step_invocation_count -eq 0 -and
        [int]$retained.world_attempt_count -eq 0 -and
        [int]$retained.world_build_count -eq 0 -and
        -not [bool]$retained.physics_state_modified -and
        -not [bool]$retained.scientific_result -and
        -not [bool]$retained.physical_acceptance_authority -and
        -not [bool]$retained.release_authority
    ) "retained metric-semantics report failed its terminal contract"
    foreach ($control in $retainedControls) {
        Assert-Mjms (
            [bool]$control.Value
        ) "retained metric-semantics control is false: $($control.Name)"
    }
    Write-Host "MuJoCo-Warp metric-semantics evidence retained: $retainedPath"
}

Write-Host (
    "MJMS_CONFORMANCE_PASS cells=8 mutations=52 metrics=5 definitions=0 " +
    "unresolved=5 worlds=0 plan=false calibration=false"
)

[CmdletBinding()]
param(
    [string]$Closure = (
        Join-Path $PSScriptRoot "quadruped_distribution_licensing_predecision_closure_v1.json"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$releaseRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$sdkRoot = [IO.Path]::GetFullPath((Split-Path -Parent $releaseRoot))
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$closurePath = [IO.Path]::GetFullPath($Closure)

function Assert-Exact([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Read-JsonObject([string]$Path) {
    Assert-Exact (Test-Path -LiteralPath $Path -PathType Leaf) (
        "Required R19 predecision closure source is missing: $Path"
    )
    try {
        $value = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 100
    } catch {
        throw "Invalid JSON at ${Path}: $($_.Exception.Message)"
    }
    Assert-Exact ($null -ne $value -and $value -is [pscustomobject]) (
        "Expected one JSON object at $Path"
    )
    return $value
}

function Get-Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

$closureObject = Read-JsonObject $closurePath
Assert-Exact (
    [string]$closureObject.schema_version -ceq
        "sporespore_quadruped_distribution_licensing_predecision_closure_v1" -and
    [string]$closureObject.status -ceq
        "closed_clean_source_predecision_inventory_owner_choice_pending" -and
    [string]$closureObject.release_gate_id -ceq "QSDK-R19" -and
    [string]$closureObject.sdk1_milestone_id -ceq "SDK1-M14"
) "Unexpected R19 predecision closure identity"
Assert-Exact (
    [string]$closureObject.ledger_scope.subsystem -ceq "release" -and
    [string]$closureObject.ledger_scope.engine_scope -ceq "engine_neutral" -and
    [string]$closureObject.ledger_scope.question_class -ceq "development"
) "R19 predecision closure ledger scope drifted"

$sourceCommit = [string]$closureObject.implementation_source.commit
$commitType = @(& git -C $repoRoot cat-file -t $sourceCommit 2>&1) -join "`n"
Assert-Exact ($LASTEXITCODE -eq 0 -and $commitType.Trim() -ceq "commit") (
    "R19 predecision implementation source is not a Git commit"
)
$observedTree = (& git -C $repoRoot rev-parse ($sourceCommit + "^{tree}")).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $observedTree -ceq [string]$closureObject.implementation_source.tree_git_oid
) "R19 predecision implementation tree drifted"
foreach ($binding in @($closureObject.bound_source_blobs)) {
    $observedBlob = @(
        & git -C $repoRoot rev-parse ($sourceCommit + ":" + [string]$binding.path) 2>&1
    ) -join "`n"
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        $observedBlob.Trim() -ceq [string]$binding.git_blob_oid
    ) "R19 predecision source blob drifted: $($binding.path)"
    $observedSize = @(
        & git -C $repoRoot cat-file -s ([string]$binding.git_blob_oid) 2>&1
    ) -join "`n"
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        [long]$observedSize.Trim() -eq [long]$binding.git_blob_byte_length
    ) "R19 predecision source blob size drifted: $($binding.path)"
}

$reportPath = [IO.Path]::GetFullPath([string]$closureObject.retained_report.path)
Assert-Exact (Test-Path -LiteralPath $reportPath -PathType Leaf) (
    "R19 predecision retained report is missing: $reportPath"
)
Assert-Exact (
    (Get-Sha256 $reportPath) -ceq [string]$closureObject.retained_report.sha256 -and
    (Get-Item -LiteralPath $reportPath).Length -eq
        [long]$closureObject.retained_report.byte_length
) "R19 predecision retained report identity drifted"
$report = Read-JsonObject $reportPath
Assert-Exact (
    [string]$report.schema_version -ceq
        [string]$closureObject.retained_report.schema_version -and
    [string]$report.status -ceq "owner_decision_pending" -and
    [string]$report.source.commit -ceq $sourceCommit -and
    [string]$report.source.origin_main -ceq $sourceCommit -and
    [bool]$report.source.clean -and
    [bool]$report.source.matches_origin_main
) "R19 predecision retained report source boundary drifted"
Assert-Exact (
    [int]$report.package_source_inventory.tracked_file_count -eq 1435 -and
    [int]$report.package_source_inventory.binary_like_file_count -eq 0 -and
    [int]$report.locked_dependencies.workspace_package_count -eq 3 -and
    [int]$report.locked_dependencies.external_package_count -eq 84 -and
    [int]$report.locked_dependencies.external_packages_with_declared_license_count -eq 84 -and
    @($report.locked_dependencies.declared_license_expression_counts).Count -eq 10 -and
    [int]$report.redistributed_patch_population.count -eq 6
) "R19 predecision observed package or dependency population drifted"
Assert-Exact (
    (@($report.blocking_conditions) -join "|") -ceq
        (@($closureObject.decision.blocking_conditions) -join "|") -and
    -not [bool]$report.owner_decision.recorded -and
    -not [bool]$report.r19_passed -and
    -not [bool]$report.sdk1_m14_passed -and
    -not [bool]$closureObject.claims.q_sdk_r19_satisfied -and
    -not [bool]$closureObject.claims.sdk1_m14_satisfied -and
    -not [bool]$closureObject.claims.release_authorized
) "R19 predecision blocker or claim boundary drifted"
Assert-Exact (
    [int]$report.execution.physics_engine_process_count -eq 0 -and
    [int]$report.execution.physics_model_construction_count -eq 0 -and
    [int]$report.execution.world_build_count -eq 0 -and
    [int]$report.execution.native_physics_read_count -eq 0 -and
    [int]$report.execution.solver_step_count -eq 0
) "R19 predecision retained report is not zero-world"

Write-Host (
    "Quadruped R19 licensing predecision closure passed: " +
    "source=$($sourceCommit.Substring(0, 8)) files=1435 dependencies=84 " +
    "expressions=10 patches=6 blockers=5 worlds=0 r19_passed=False."
)

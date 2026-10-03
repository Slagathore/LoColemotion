[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$releaseRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$compilerPath = Join-Path $releaseRoot "compile_quadruped_distribution_licensing_readiness.ps1"
$contractPath = Join-Path $releaseRoot "quadruped_distribution_licensing_contract_v1.json"
$systemTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
)
$testRoot = Join-Path (
    $systemTempRoot
) ("sporespore-r19-test-" + [Guid]::NewGuid().ToString("N"))

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Invoke-Compiler([string]$Contract = $contractPath) {
    $lines = @(& $compilerPath -Contract $Contract 6>$null)
    $prefix = "QUADRUPED_DISTRIBUTION_LICENSING_READINESS "
    $matches = @($lines | Where-Object {
        $_.StartsWith($prefix, [StringComparison]::Ordinal)
    })
    Assert-True ($matches.Count -eq 1) "Expected exactly one R19 readiness marker"
    return $matches[0].Substring($prefix.Length) | ConvertFrom-Json -Depth 100
}

[void][IO.Directory]::CreateDirectory($testRoot)
try {
    $report = Invoke-Compiler
    Assert-True (
        [string]$report.schema_version -ceq
            "sporespore_quadruped_distribution_licensing_readiness_report_v1" -and
        [string]$report.status -ceq "owner_decision_pending" -and
        -not [bool]$report.owner_decision.recorded -and
        -not [bool]$report.r19_passed -and
        -not [bool]$report.sdk1_m14_passed
    ) "Current R19 predecision status drifted"
    Assert-True (
        [int]$report.locked_dependencies.workspace_package_count -eq 3 -and
        [int]$report.locked_dependencies.external_package_count -eq 84 -and
        [int]$report.locked_dependencies.external_packages_with_declared_license_count -eq 84 -and
        @($report.locked_dependencies.declared_license_expression_counts).Count -eq 10
    ) "Locked dependency license population drifted"
    Assert-True (
        [int]$report.redistributed_patch_population.count -eq 6 -and
        [bool]$report.redistributed_patch_population.exact_identity_passed -and
        [int]$report.package_source_inventory.binary_like_file_count -eq 0 -and
        [bool]$report.package_source_inventory.source_first_projection_passed
    ) "Source-first package or redistributed patch population drifted"
    Assert-True (
        @($report.blocking_conditions) -contains "QSDK-R19-OWNER-LICENSE-CHOICE" -and
        @($report.blocking_conditions) -contains "QSDK-R19-COPYRIGHT-HOLDER" -and
        @($report.blocking_conditions) -contains "QSDK-R19-OWNER-DECISION-RECORD" -and
        @($report.blocking_conditions) -contains "QSDK-R19-LEGAL-FILE-BINDINGS" -and
        @($report.blocking_conditions) -contains "QSDK-R19-CARGO-LICENSE-METADATA"
    ) "R19 predecision blockers drifted"
    Assert-True (
        [int]$report.execution.physics_engine_process_count -eq 0 -and
        [int]$report.execution.physics_model_construction_count -eq 0 -and
        [int]$report.execution.world_build_count -eq 0 -and
        [int]$report.execution.native_physics_read_count -eq 0 -and
        [int]$report.execution.solver_step_count -eq 0 -and
        -not [bool]$report.claims.package_authorized -and
        -not [bool]$report.claims.publication_authorized -and
        -not [bool]$report.claims.release_authorized
    ) "R19 predecision escaped its zero-world claim boundary"

    $requireReadyRefused = $false
    try {
        & $compilerPath -RequireReady 6>$null | Out-Null
    } catch {
        $requireReadyRefused = (
            $_.Exception.Message -like
                "*Quadruped distribution/licensing is blocked by:*"
        )
    }
    Assert-True $requireReadyRefused "R19 -RequireReady did not fail closed"

    $forgedDecision = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json -Depth 100
    $forgedDecision.status = "active_distribution_decision"
    $forgedDecision.owner_decision.status = "selected"
    $forgedDecision.owner_decision.selected_spdx_expression = "MIT OR Apache-2.0"
    $forgedDecision.owner_decision.copyright_holder = "FORGED TEST HOLDER"
    $forgedDecisionPath = Join-Path $testRoot "forged_owner_decision.json"
    [IO.File]::WriteAllText(
        $forgedDecisionPath,
        ($forgedDecision | ConvertTo-Json -Depth 100) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
    $forgedDecisionReport = Invoke-Compiler -Contract $forgedDecisionPath
    Assert-True (
        [bool]$forgedDecisionReport.owner_decision.recorded -and
        -not [bool]$forgedDecisionReport.r19_passed -and
        @($forgedDecisionReport.blocking_conditions) -contains
            "QSDK-R19-LEGAL-FILE-BINDINGS" -and
        @($forgedDecisionReport.blocking_conditions) -contains
            "QSDK-R19-CARGO-LICENSE-METADATA"
    ) "R19 compiler trusted an owner choice without matching package evidence"

    $mutatedLock = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json -Depth 100
    $mutatedLock.locked_dependency_population.cargo_lock_sha256 = "sha256:" + ("0" * 64)
    $mutatedLockPath = Join-Path $testRoot "mutated_lock_contract.json"
    [IO.File]::WriteAllText(
        $mutatedLockPath,
        ($mutatedLock | ConvertTo-Json -Depth 100) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
    $mutatedLockRefused = $false
    try {
        & $compilerPath -Contract $mutatedLockPath 6>$null | Out-Null
    } catch {
        $mutatedLockRefused = $_.Exception.Message -like "*Locked dependency population changed*"
    }
    Assert-True $mutatedLockRefused "R19 compiler accepted a mutated Cargo.lock identity"

    $mutatedPatch = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json -Depth 100
    $mutatedPatch.distribution_scope.godot_jolt_patch_files[0].sha256 = (
        "sha256:" + ("f" * 64)
    )
    $mutatedPatchPath = Join-Path $testRoot "mutated_patch_contract.json"
    [IO.File]::WriteAllText(
        $mutatedPatchPath,
        ($mutatedPatch | ConvertTo-Json -Depth 100) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
    $mutatedPatchRefused = $false
    try {
        & $compilerPath -Contract $mutatedPatchPath 6>$null | Out-Null
    } catch {
        $mutatedPatchRefused = $_.Exception.Message -like "*patch identity drifted*"
    }
    Assert-True $mutatedPatchRefused "R19 compiler accepted a mutated patch identity"

    Write-Host (
        "Quadruped distribution/licensing predecision tests passed: " +
        "3 workspace packages, 84 locked dependencies, 10 license expressions, " +
        "6 redistributed patches, and 4 fail-closed controls."
    )
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
        $tempPrefix = $systemTempRoot + [IO.Path]::DirectorySeparatorChar
        Assert-True (
            $resolvedTestRoot.StartsWith(
                $tempPrefix,
                [StringComparison]::OrdinalIgnoreCase
            ) -and
            (Split-Path -Leaf $resolvedTestRoot) -like
                "sporespore-r19-test-*"
        ) "Refusing to remove an unsafe R19 test path: $resolvedTestRoot"
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}

#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$contractPath = Join-Path $repoRoot "sdk\closure_evidence_provenance_contract.json"
$inventoryPath = Join-Path $repoRoot "sdk\closure_evidence_mode_inventory.json"
$analyzerPath = Join-Path $repoRoot "sdk\audit_closure_evidence_modes.ps1"
$attributesPath = Join-Path $repoRoot ".gitattributes"

function Assert-Exact([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Get-RawSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-GitBlobRawIdentity([string]$ObjectId) {
    $type = @(& git -C $repoRoot cat-file -t $ObjectId 2>&1 |
        ForEach-Object { [string]$_ })
    if ($LASTEXITCODE -ne 0 -or ($type -join "`n").Trim() -cne "blob") {
        throw "Closure evidence provenance Git object is not a blob: $ObjectId"
    }
    $size = @(& git -C $repoRoot cat-file -s $ObjectId 2>&1 |
        ForEach-Object { [string]$_ })
    if ($LASTEXITCODE -ne 0) {
        throw "Closure evidence provenance Git blob size failed: $ObjectId"
    }
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @("-C", $repoRoot, "cat-file", "blob", $ObjectId)) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    [void]$process.Start()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream)
    } finally {
        $hasher.Dispose()
    }
    $process.WaitForExit()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = $process.ExitCode
    $process.Dispose()
    if ($exitCode -ne 0) {
        throw "Closure evidence provenance Git blob read failed: $ObjectId $stderr"
    }
    return [ordered]@{
        object_id = $ObjectId
        raw_sha256 = [Convert]::ToHexString($digest).ToLowerInvariant()
        byte_length = [long](($size -join "`n").Trim())
    }
}

foreach ($path in @($contractPath, $inventoryPath, $analyzerPath, $attributesPath)) {
    Assert-Exact (Test-Path -LiteralPath $path -PathType Leaf) (
        "Closure evidence provenance authority is missing: $path"
    )
}

$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$inventory = Get-Content -LiteralPath $inventoryPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$attributesText = Get-Content -LiteralPath $attributesPath -Raw
$r23d8Extension = $contract.checkout_filter_migration.r23d8_non_migration_rule_extension
$r23d9StageZeroExtension = $contract.checkout_filter_migration.r23d9_stage_zero_non_migration_rule_extension
$r23d9StageOneExtension = $contract.checkout_filter_migration.r23d9_stage_one_non_migration_rule_extension
$r23d10StageZeroExtension = $contract.checkout_filter_migration.r23d10_stage_zero_non_migration_rule_extension
$r23d10StageOneExtension = $contract.checkout_filter_migration.r23d10_stage_one_non_migration_rule_extension
$r23d11StageZeroExtension = $contract.checkout_filter_migration.r23d11_stage_zero_non_migration_rule_extension
$r23d11StageOneExtension = $contract.checkout_filter_migration.r23d11_stage_one_non_migration_rule_extension
$r23d11StageTwoExtension = $contract.checkout_filter_migration.r23d11_stage_two_non_migration_rule_extension
$latestExtension = $contract.checkout_filter_migration.latest_non_migration_rule_extension
$r23d12StageThreeExtension = $contract.checkout_filter_migration.r23d12_stage_three_non_migration_rule_extension
$r23d13StageZeroExtension = $contract.checkout_filter_migration.r23d13_stage_zero_non_migration_rule_extension
$conformanceProfilerExtension = $contract.checkout_filter_migration.conformance_profiler_non_migration_rule_extension
$transitiveHistoricalAuditExtension = $contract.checkout_filter_migration.transitive_historical_audit_non_migration_rule_extension
$r23d14StageZeroExtension = $contract.checkout_filter_migration.r23d14_stage_zero_non_migration_rule_extension
$r23d15StageZeroExtension = $contract.checkout_filter_migration.r23d15_stage_zero_non_migration_rule_extension
$r23d16Extension = $contract.checkout_filter_migration.r23d16_non_migration_rule_extension
$r23d17Extension = $contract.checkout_filter_migration.r23d17_non_migration_rule_extension
$campaignAttestationExtension =
    $contract.checkout_filter_migration.campaign_attestation_non_migration_rule_extension
$r23d19InheritedGodotExtension =
    $contract.checkout_filter_migration.r23d19_inherited_godot_input_non_migration_rule_extension
$r23d20Extension =
    $contract.checkout_filter_migration.r23d20_non_migration_rule_extension
$r23d21Extension =
    $contract.checkout_filter_migration.r23d21_non_migration_rule_extension
$r23d22Extension =
    $contract.checkout_filter_migration.r23d22_non_migration_rule_extension
$r23d23Extension =
    $contract.checkout_filter_migration.r23d23_non_migration_rule_extension
$r23d24Extension =
    $contract.checkout_filter_migration.r23d24_non_migration_rule_extension
$r23d25Extension =
    $contract.checkout_filter_migration.r23d25_non_migration_rule_extension
$r23d26Extension =
    $contract.checkout_filter_migration.r23d26_non_migration_rule_extension
$traceLineageExtension =
    $contract.checkout_filter_migration.retained_trace_lineage_non_migration_rule_extension
$r23d27Extension =
    $contract.checkout_filter_migration.r23d27_non_migration_rule_extension
$r23d28Extension =
    $contract.checkout_filter_migration.r23d28_non_migration_rule_extension
$r23d29Extension =
    $contract.checkout_filter_migration.r23d29_non_migration_rule_extension
$r23d30Extension =
    $contract.checkout_filter_migration.r23d30_non_migration_rule_extension
$r23d31Extension =
    $contract.checkout_filter_migration.r23d31_non_migration_rule_extension
$r23d32ClosureExtension =
    $contract.checkout_filter_migration.r23d32_closure_non_migration_rule_extension
$r23d33Extension =
    $contract.checkout_filter_migration.r23d33_non_migration_rule_extension
$r23d34Extension =
    $contract.checkout_filter_migration.r23d34_postclosure_non_migration_rule_extension
$r23d35Extension =
    $contract.checkout_filter_migration.r23d35_non_migration_rule_extension
$r23d36Extension =
    $contract.checkout_filter_migration.r23d36_non_migration_rule_extension
$r23d37Extension =
    $contract.checkout_filter_migration.r23d37_non_migration_rule_extension
$r23d38Extension =
    $contract.checkout_filter_migration.r23d38_non_migration_rule_extension
$r23d39Extension =
    $contract.checkout_filter_migration.r23d39_non_migration_rule_extension
$r23d40Extension =
    $contract.checkout_filter_migration.r23d40_non_migration_rule_extension
$r23d41Extension =
    $contract.checkout_filter_migration.r23d41_non_migration_rule_extension
$r23d42Extension =
    $contract.checkout_filter_migration.r23d42_non_migration_rule_extension
$r23d43Extension =
    $contract.checkout_filter_migration.r23d43_non_migration_rule_extension
$r23d44Extension =
    $contract.checkout_filter_migration.r23d44_non_migration_rule_extension
$r23d45Extension =
    $contract.checkout_filter_migration.r23d45_non_migration_rule_extension
$r23d46Extension =
    $contract.checkout_filter_migration.r23d46_non_migration_rule_extension
$r23d47Extension =
    $contract.checkout_filter_migration.r23d47_non_migration_rule_extension
$r23d48Extension =
    $contract.checkout_filter_migration.r23d48_non_migration_rule_extension
$r23d49Extension =
    $contract.checkout_filter_migration.r23d49_non_migration_rule_extension
$r23d50Extension =
    $contract.checkout_filter_migration.r23d50_non_migration_rule_extension
$r23d51Extension =
    $contract.checkout_filter_migration.r23d51_non_migration_rule_extension
$r23d52Extension =
    $contract.checkout_filter_migration.r23d52_non_migration_rule_extension
$r23d53Extension =
    $contract.checkout_filter_migration.r23d53_non_migration_rule_extension
$r23d54Extension =
    $contract.checkout_filter_migration.r23d54_non_migration_rule_extension
$r23d55Extension =
    $contract.checkout_filter_migration.r23d55_non_migration_rule_extension
$r23d56Extension =
    $contract.checkout_filter_migration.r23d56_non_migration_rule_extension
$r23d57Extension =
    $contract.checkout_filter_migration.r23d57_non_migration_rule_extension
$r23d57WorkbenchAuditExtension =
    $contract.checkout_filter_migration.r23d57_workbench_audit_non_migration_rule_extension
$r23d58Extension =
    $contract.checkout_filter_migration.r23d58_non_migration_rule_extension
$r23d59Extension =
    $contract.checkout_filter_migration.r23d59_non_migration_rule_extension
$r23d60Extension =
    $contract.checkout_filter_migration.r23d60_non_migration_rule_extension
$r23d61Extension =
    $contract.checkout_filter_migration.r23d61_postclosure_non_migration_rule_extension
$r23d62Extension =
    $contract.checkout_filter_migration.r23d62_non_migration_rule_extension
$r23d62RapierRouteExtension =
    $contract.checkout_filter_migration.r23d62_rapier_route_checkout_stability_extension
$r24d1Extension =
    $contract.checkout_filter_migration.r24d1_non_migration_rule_extension
$r24d2Extension =
    $contract.checkout_filter_migration.r24d2_non_migration_rule_extension
$r24d2IntegrationExtension =
    $contract.checkout_filter_migration.r24d2_integration_checkout_stability_extension
$r24d3Extension =
    $contract.checkout_filter_migration.r24d3_non_migration_rule_extension
$r24d4Extension =
    $contract.checkout_filter_migration.r24d4_non_migration_rule_extension
$r24d4ClosureExtension =
    $contract.checkout_filter_migration.r24d4_zero_world_failure_closure_non_migration_extension
$r24d5Extension =
    $contract.checkout_filter_migration.r24d5_non_migration_rule_extension
$r24d5ClosureExtension =
    $contract.checkout_filter_migration.r24d5_physical_failure_closure_non_migration_extension
$r24d6Extension =
    $contract.checkout_filter_migration.r24d6_non_migration_rule_extension
$r24d6ClosureExtension =
    $contract.checkout_filter_migration.r24d6_zero_world_failure_closure_non_migration_extension
$r24d7Extension =
    $contract.checkout_filter_migration.r24d7_non_migration_rule_extension
$r24d7ClosureExtension =
    $contract.checkout_filter_migration.r24d7_physical_failure_closure_non_migration_extension
$r24d8Extension =
    $contract.checkout_filter_migration.r24d8_non_migration_rule_extension
$r24d9Extension =
    $contract.checkout_filter_migration.r24d9_non_migration_rule_extension
$r23d62PrephysicalCheckoutRepair =
    $contract.checkout_filter_migration.r23d62_prephysical_checkout_blob_non_migration_rule_repair
$postR23D62RuleReconciliation =
    $contract.checkout_filter_migration.post_r23d62_rule_extension_reconciliation
$r23d67QualificationProvenanceReconciliation =
    $contract.checkout_filter_migration.r23d67_qualification_provenance_reconciliation
$r23d78QualificationProvenanceReconciliation =
    $contract.checkout_filter_migration.r23d78_qualification_provenance_reconciliation
$postR23D78CurrentIdentityReconciliation =
    $contract.checkout_filter_migration.post_r23d78_current_checkout_identity_reconciliation
$r23d38Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d38Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d39Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d39Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d40Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d40Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d41Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d41Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d42Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d42Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d43Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d43Extension.declared_from_parent_commit) `
        ([string]$r23d43Extension.source_rule_commit) `
        -- .gitattributes
) -join "`n"
$r23d44Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d44Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d45Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d45Extension.declared_from_parent_commit) `
        ([string]$r23d45Extension.source_rule_commit) `
        -- .gitattributes
) -join "`n"
$r23d46Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d46Extension.declared_from_parent_commit) `
        ([string]$r23d46Extension.source_rule_commit) `
        -- .gitattributes
) -join "`n"
$r23d47Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d47Extension.declared_from_parent_commit) `
        ([string]$r23d47Extension.source_rule_commit) `
        -- .gitattributes
) -join "`n"
$r23d48Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d48Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d49Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d49Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d50Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d50Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d51Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d51Extension.declared_from_parent_commit) `
        ([string]$r23d51Extension.source_rule_commit) `
        -- .gitattributes
) -join "`n"
$r23d52Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d52Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d53Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d53Extension.declared_from_parent_commit) `
        ([string]$r23d53Extension.source_rule_commit) `
        -- .gitattributes
) -join "`n"
$r23d54Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d54Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d57Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d57Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d57WorkbenchAuditDiff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d57WorkbenchAuditExtension.declared_from_parent_commit) `
        ([string]$r23d57WorkbenchAuditExtension.source_rule_commit) `
        -- .gitattributes
) -join "`n"
$r23d58Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d58Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d59Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d59Extension.declared_from_parent_commit) `
        ([string]$r23d59Extension.source_rule_commit) `
        -- .gitattributes
) -join "`n"
$r23d60Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d60Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d61Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d61Extension.declared_from_closure_commit) `
        -- .gitattributes
) -join "`n"
$r23d62Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d62Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d62RapierRouteDiff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d62RapierRouteExtension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r24d1Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r24d1Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r24d2Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r24d2Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r24d2IntegrationDiff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r24d2IntegrationExtension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r24d3Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r24d3Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r24d4Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r24d4Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r24d5Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r24d5Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r24d6Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r24d6Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r24d7Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r24d7Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r24d8Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r24d8Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r24d9Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r24d9Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d55Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d55Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d56Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d56Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d8Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d8Extension.parent_commit) `
        ([string]$r23d8Extension.commit) `
        -- .gitattributes
) -join "`n"
$r23d9StageZeroDiff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d9StageZeroExtension.parent_commit) `
        ([string]$r23d9StageZeroExtension.commit) `
        -- .gitattributes
) -join "`n"
$r23d9StageOneDiff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d9StageOneExtension.parent_commit) `
        ([string]$r23d9StageOneExtension.commit) `
        -- .gitattributes
) -join "`n"
$r23d10StageZeroDiff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d10StageZeroExtension.parent_commit) `
        ([string]$r23d10StageZeroExtension.commit) `
        -- .gitattributes
) -join "`n"
$r23d10StageOneDiff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d10StageOneExtension.parent_commit) `
        ([string]$r23d10StageOneExtension.commit) `
        -- .gitattributes
) -join "`n"
$r23d11StageZeroDiff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d11StageZeroExtension.parent_commit) `
        ([string]$r23d11StageZeroExtension.commit) `
        -- .gitattributes
) -join "`n"
$r23d11StageOneDiff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d11StageOneExtension.parent_commit) `
        ([string]$r23d11StageOneExtension.commit) `
        -- .gitattributes
) -join "`n"
$r23d11StageTwoDiff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d11StageTwoExtension.parent_commit) `
        ([string]$r23d11StageTwoExtension.commit) `
        -- .gitattributes
) -join "`n"
$latestDiff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$latestExtension.parent_commit) `
        ([string]$latestExtension.commit) `
        -- .gitattributes
) -join "`n"
$r23d12StageThreeDiff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d12StageThreeExtension.parent_commit) `
        ([string]$r23d12StageThreeExtension.commit) `
        -- .gitattributes
) -join "`n"
$r23d13StageZeroDiff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d13StageZeroExtension.parent_commit) `
        ([string]$r23d13StageZeroExtension.commit) `
        -- .gitattributes
) -join "`n"
$conformanceProfilerDiff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$conformanceProfilerExtension.parent_commit) `
        ([string]$conformanceProfilerExtension.commit) `
        -- .gitattributes
) -join "`n"
$transitiveHistoricalAuditDiff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$transitiveHistoricalAuditExtension.parent_commit) `
        ([string]$transitiveHistoricalAuditExtension.commit) `
        -- .gitattributes
) -join "`n"
$r23d14StageZeroDiff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d14StageZeroExtension.parent_commit) `
        ([string]$r23d14StageZeroExtension.commit) `
        -- .gitattributes
) -join "`n"
$r23d15StageZeroDiff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d15StageZeroExtension.parent_commit) `
        ([string]$r23d15StageZeroExtension.commit) `
        -- .gitattributes
) -join "`n"
$r23d16Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d16Extension.parent_commit) `
        ([string]$r23d16Extension.commit) `
        -- .gitattributes
) -join "`n"
$r23d17Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d17Extension.parent_commit) `
        ([string]$r23d17Extension.commit) `
        -- .gitattributes
) -join "`n"
$campaignAttestationDiff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$campaignAttestationExtension.parent_commit) `
        ([string]$campaignAttestationExtension.commit) `
        -- .gitattributes
) -join "`n"
$r23d19InheritedGodotDiff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d19InheritedGodotExtension.parent_commit) `
        ([string]$r23d19InheritedGodotExtension.commit) `
        -- .gitattributes
) -join "`n"
$r23d20Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d20Extension.parent_commit) `
        ([string]$r23d20Extension.commit) `
        -- .gitattributes
) -join "`n"
$r23d21Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d21Extension.parent_commit) `
        ([string]$r23d21Extension.commit) `
        -- .gitattributes
) -join "`n"
$r23d22Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d22Extension.parent_commit) `
        ([string]$r23d22Extension.commit) `
        -- .gitattributes
) -join "`n"
$r23d23Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d23Extension.parent_commit) `
        ([string]$r23d23Extension.commit) `
        -- .gitattributes
) -join "`n"
$r23d24Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d24Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d25Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d25Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d26Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d26Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$traceLineageDiff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$traceLineageExtension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d27Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d27Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d28Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d28Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d29Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d29Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d30Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d30Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d31Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d31Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d32ClosureDiff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d32ClosureExtension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d33Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d33Extension.declared_from_parent_commit) `
        ([string]$r23d33Extension.source_rule_commit) `
        -- .gitattributes
) -join "`n"
$r23d34Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d34Extension.declared_from_parent_commit) `
        ([string]$r23d34Extension.source_rule_commit) `
        -- .gitattributes
) -join "`n"
$r23d35Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d35Extension.declared_from_parent_commit) `
        -- .gitattributes
) -join "`n"
$r23d36Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d36Extension.declared_from_parent_commit) `
        ([string]$r23d36Extension.source_rule_commit) `
        -- .gitattributes
) -join "`n"
$r23d37Diff = @(
    git -C $repoRoot diff --unified=0 `
        ([string]$r23d37Extension.declared_from_parent_commit) `
        ([string]$r23d37Extension.source_rule_commit) `
        -- .gitattributes
) -join "`n"
$r23d14RequiredRules = @(
    "sdk/turning/terminal_tight_first_* text eol=lf",
    "sdk/run_qsdk_turning_tight_first_development.ps1 text eol=lf",
    "tests/test_terminal_tight_first_* text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_turning_tight_first_*.py text eol=lf",
    "sdk/adapters/mujoco/test_qsdk_turning_tight_first_*.py text eol=lf",
    "sdk/turning/r23d14_* text eol=lf",
    "sdk/turning/test_r23d14_* text eol=lf",
    "sdk/run_qsdk_r23d14_*.ps1 text eol=lf",
    "sdk/publish_qsdk_r23d14_*.ps1 text eol=lf",
    "tests/test_qsdk_r23d14_*.ps1 text eol=lf",
    "tests/test_sdk_qsdk_r23d14_*.gd text eol=lf",
    "scripts/lab/gait/sdk_godot_jolt_r23d14_*.gd text eol=lf",
    "sdk/adapters/rapier/src/qsdk_r23d14_*.rs text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d14_*.rs text eol=lf",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d14_*.rs text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d14_*.py text eol=lf",
    "sdk/adapters/mujoco/test_qsdk_r23d14_*.py text eol=lf"
)
$r23d14MissingDiffRules = @(
    $r23d14RequiredRules | Where-Object {
        -not $r23d14StageZeroDiff.Contains("+$_")
    }
)
$r23d14MissingLiveRules = @(
    $r23d14RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d15RequiredRules = @(
    "sdk/turning/r23d15_* text eol=lf",
    "sdk/turning/test_r23d15_* text eol=lf",
    "sdk/run_qsdk_r23d15_*.ps1 text eol=lf",
    "sdk/publish_qsdk_r23d15_*.ps1 text eol=lf",
    "tests/test_qsdk_r23d15_*.ps1 text eol=lf",
    "tests/test_sdk_qsdk_r23d15_*.gd text eol=lf",
    "scripts/lab/gait/sdk_godot_jolt_r23d15_*.gd text eol=lf",
    "sdk/adapters/rapier/src/qsdk_r23d15_*.rs text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d15_*.rs text eol=lf",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d15_*.rs text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d15_*.py text eol=lf",
    "sdk/adapters/mujoco/test_qsdk_r23d15_*.py text eol=lf"
)
$r23d15MissingDiffRules = @(
    $r23d15RequiredRules | Where-Object {
        -not $r23d15StageZeroDiff.Contains("+$_")
    }
)
$r23d15MissingLiveRules = @(
    $r23d15RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d16RequiredRules = @(
    "sdk/turning/r23d16_* text eol=lf",
    "sdk/turning/test_r23d16_* text eol=lf",
    "sdk/run_qsdk_r23d16_*.ps1 text eol=lf",
    "sdk/publish_qsdk_r23d16_*.ps1 text eol=lf",
    "tests/test_qsdk_r23d16_*.ps1 text eol=lf",
    "tests/test_sdk_qsdk_r23d16_*.gd text eol=lf",
    "scripts/lab/gait/sdk_godot_jolt_r23d16_*.gd text eol=lf",
    "sdk/adapters/rapier/src/qsdk_r23d16_*.rs text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d16_*.rs text eol=lf",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d16_*.rs text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d16_*.py text eol=lf",
    "sdk/adapters/mujoco/test_qsdk_r23d16_*.py text eol=lf"
)
$r23d16MissingDiffRules = @(
    $r23d16RequiredRules | Where-Object { -not $r23d16Diff.Contains("+$_") }
)
$r23d16MissingLiveRules = @(
    $r23d16RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d17RequiredRules = @(
    "sdk/turning/r23d17_* text eol=lf",
    "sdk/turning/test_r23d17_* text eol=lf",
    "sdk/run_qsdk_r23d17_*.ps1 text eol=lf",
    "sdk/publish_qsdk_r23d17_*.ps1 text eol=lf",
    "tests/test_qsdk_r23d17_*.ps1 text eol=lf",
    "tests/test_sdk_qsdk_r23d17_*.gd text eol=lf",
    "scripts/lab/gait/sdk_godot_jolt_r23d17_*.gd text eol=lf",
    "sdk/adapters/rapier/src/qsdk_r23d17_*.rs text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d17_*.rs text eol=lf",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d17_*.rs text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d17_*.py text eol=lf",
    "sdk/adapters/mujoco/test_qsdk_r23d17_*.py text eol=lf"
)
$r23d17MissingDiffRules = @(
    $r23d17RequiredRules | Where-Object { -not $r23d17Diff.Contains("+$_") }
)
$r23d17MissingLiveRules = @(
    $r23d17RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$campaignAttestationRequiredRules = @(
    "sdk/locomotion_campaign_attestation*.ps1 text eol=lf",
    "sdk/locomotion_campaign_attestation*.json text eol=lf",
    "sdk/run_locomotion_campaign_attestation.ps1 text eol=lf",
    "tests/test_locomotion_campaign_attestation*.ps1 text eol=lf"
)
$campaignAttestationMissingDiffRules = @(
    $campaignAttestationRequiredRules | Where-Object {
        -not $campaignAttestationDiff.Contains("+$_")
    }
)
$campaignAttestationMissingLiveRules = @(
    $campaignAttestationRequiredRules | Where-Object {
        -not $attributesText.Contains($_)
    }
)
$r23d19InheritedGodotRequiredRules = @(
    "sdk/adapters/godot/Cargo.toml text eol=lf",
    "sdk/adapters/godot/sporespore_locomotion.gdextension text eol=lf",
    "sdk/core/Cargo.toml text eol=lf"
)
$r23d19InheritedGodotMissingDiffRules = @(
    $r23d19InheritedGodotRequiredRules | Where-Object {
        -not $r23d19InheritedGodotDiff.Contains("+$_")
    }
)
$r23d19InheritedGodotMissingLiveRules = @(
    $r23d19InheritedGodotRequiredRules | Where-Object {
        -not $attributesText.Contains($_)
    }
)
$r23d20RequiredRules = @(
    "sdk/turning/r23d20_* text eol=lf",
    "sdk/turning/test_r23d20_* text eol=lf",
    "sdk/run_qsdk_r23d20_*.ps1 text eol=lf",
    "sdk/publish_qsdk_r23d20_*.ps1 text eol=lf",
    "tests/test_qsdk_r23d20_*.ps1 text eol=lf",
    "tests/test_sdk_qsdk_r23d20_*.gd text eol=lf"
)
$r23d20MissingDiffRules = @(
    $r23d20RequiredRules | Where-Object {
        -not $r23d20Diff.Contains("+$_")
    }
)
$r23d20MissingLiveRules = @(
    $r23d20RequiredRules | Where-Object {
        -not $attributesText.Contains($_)
    }
)
$r23d21RequiredRules = @(
    "sdk/turning/r23d21_* text eol=lf",
    "sdk/turning/test_r23d21_* text eol=lf",
    "sdk/run_qsdk_r23d21_*.ps1 text eol=lf",
    "sdk/publish_qsdk_r23d21_*.ps1 text eol=lf",
    "tests/test_qsdk_r23d21_*.ps1 text eol=lf",
    "tests/test_sdk_qsdk_r23d21_*.gd text eol=lf"
)
$r23d21MissingDiffRules = @(
    $r23d21RequiredRules | Where-Object {
        -not $r23d21Diff.Contains("+$_")
    }
)
$r23d21MissingLiveRules = @(
    $r23d21RequiredRules | Where-Object {
        -not $attributesText.Contains($_)
    }
)
$r23d22RequiredRules = @(
    "sdk/turning/r23d22_* text eol=lf",
    "sdk/turning/test_r23d22_* text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d22_* text eol=lf",
    "sdk/adapters/mujoco/test_qsdk_r23d22_* text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d22_* text eol=lf",
    "sdk/adapters/rapier/src/qsdk_r23d22_* text eol=lf",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d22_* text eol=lf",
    "sdk/publish_qsdk_r23d22_* text eol=lf",
    "sdk/run_qsdk_r23d22_* text eol=lf",
    "tests/test_qsdk_r23d22_* text eol=lf"
)
$r23d22MissingDiffRules = @(
    $r23d22RequiredRules | Where-Object {
        -not $r23d22Diff.Contains("+$_")
    }
)
$r23d22MissingLiveRules = @(
    $r23d22RequiredRules | Where-Object {
        -not $attributesText.Contains($_)
    }
)
$r23d23RequiredRules = @(
    "sdk/turning/r23d23_* text eol=lf",
    "sdk/turning/test_r23d23_* text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d23_* text eol=lf",
    "sdk/adapters/mujoco/test_qsdk_r23d23_* text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d23_* text eol=lf",
    "sdk/adapters/rapier/src/qsdk_r23d23_* text eol=lf",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d23_* text eol=lf",
    "sdk/publish_qsdk_r23d23_* text eol=lf",
    "sdk/run_qsdk_r23d23_* text eol=lf",
    "tests/test_qsdk_r23d23_* text eol=lf"
)
$r23d23MissingDiffRules = @(
    $r23d23RequiredRules | Where-Object {
        -not $r23d23Diff.Contains("+$_")
    }
)
$r23d23MissingLiveRules = @(
    $r23d23RequiredRules | Where-Object {
        -not $attributesText.Contains($_)
    }
)
$r23d24RequiredRules = @(
    "sdk/turning/r23d24_* text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d24_* text eol=lf",
    "sdk/publish_qsdk_r23d24_* text eol=lf",
    "sdk/run_qsdk_r23d24_* text eol=lf",
    "tests/test_qsdk_r23d24_* text eol=lf"
)
$r23d24MissingDiffRules = @(
    $r23d24RequiredRules | Where-Object {
        -not $r23d24Diff.Contains("+$_")
    }
)
$r23d24MissingLiveRules = @(
    $r23d24RequiredRules | Where-Object {
        -not $attributesText.Contains($_)
    }
)
$r23d25RequiredRules = @(
    "sdk/turning/r23d25_* text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d25_* text eol=lf",
    "sdk/publish_qsdk_r23d25_* text eol=lf",
    "sdk/run_qsdk_r23d25_* text eol=lf",
    "tests/test_qsdk_r23d25_* text eol=lf"
)
$r23d25MissingDiffRules = @(
    $r23d25RequiredRules | Where-Object {
        -not $r23d25Diff.Contains("+$_")
    }
)
$r23d25MissingLiveRules = @(
    $r23d25RequiredRules | Where-Object {
        -not $attributesText.Contains($_)
    }
)
$r23d26RequiredRules = @(
    "sdk/turning/r23d26_* text eol=lf",
    "sdk/turning/test_r23d26_* text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d26_* text eol=lf",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d26_* text eol=lf",
    "sdk/publish_qsdk_r23d26_* text eol=lf",
    "sdk/run_qsdk_r23d26_* text eol=lf",
    "tests/test_qsdk_r23d26_* text eol=lf"
)
$r23d26MissingDiffRules = @(
    $r23d26RequiredRules | Where-Object {
        -not $r23d26Diff.Contains("+$_")
    }
)
$r23d26MissingLiveRules = @(
    $r23d26RequiredRules | Where-Object {
        -not $attributesText.Contains($_)
    }
)
$traceLineageRequiredRules = @(
    "sdk/trace_analysis/* text eol=lf",
    "sdk/run_retained_trace_lineage_analysis.ps1 text eol=lf",
    "tests/test_retained_trace_lineage_analysis.ps1 text eol=lf"
)
$traceLineageMissingDiffRules = @(
    $traceLineageRequiredRules | Where-Object {
        -not $traceLineageDiff.Contains("+$_")
    }
)
$traceLineageMissingLiveRules = @(
    $traceLineageRequiredRules | Where-Object {
        -not $attributesText.Contains($_)
    }
)
$r23d27RequiredRules = @(
    "sdk/core/src/controller.rs text eol=lf",
    "sdk/core/src/lib.rs text eol=lf",
    "sdk/core/src/protocol.rs text eol=lf",
    "sdk/core/src/runtime.rs text eol=lf",
    "sdk/adapters/rapier/src/lib.rs text eol=lf",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced.rs text eol=lf",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d27_physical.rs text eol=lf",
    "sdk/turning/r23d27_* text eol=lf",
    "sdk/turning/test_r23d27_* text eol=lf",
    "sdk/publish_qsdk_r23d27_* text eol=lf",
    "sdk/run_qsdk_r23d27_* text eol=lf",
    "tests/test_qsdk_r23d27_* text eol=lf"
)
$r23d27MissingDiffRules = @(
    $r23d27RequiredRules | Where-Object { -not $r23d27Diff.Contains("+$_") }
)
$r23d27MissingLiveRules = @(
    $r23d27RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d28RequiredRules = @(
    "sdk/turning/r23d28_* text eol=lf",
    "sdk/turning/test_r23d28_* text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d28_* text eol=lf",
    "sdk/publish_qsdk_r23d28_* text eol=lf",
    "sdk/run_qsdk_r23d28_* text eol=lf",
    "tests/test_qsdk_r23d28_* text eol=lf"
)
$r23d28MissingDiffRules = @(
    $r23d28RequiredRules | Where-Object { -not $r23d28Diff.Contains("+$_") }
)
$r23d28MissingLiveRules = @(
    $r23d28RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d29RequiredRules = @(
    "sdk/turning/r23d29_* text eol=lf",
    "sdk/turning/test_r23d29_* text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d29_* text eol=lf",
    "sdk/publish_qsdk_r23d29_* text eol=lf",
    "sdk/run_qsdk_r23d29_* text eol=lf",
    "tests/test_qsdk_r23d29_* text eol=lf"
)
$r23d29MissingDiffRules = @(
    $r23d29RequiredRules | Where-Object { -not $r23d29Diff.Contains("+$_") }
)
$r23d29MissingLiveRules = @(
    $r23d29RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d30RequiredRules = @(
    "sdk/turning/r23d30_* text eol=lf",
    "sdk/turning/test_r23d30_* text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d30_* text eol=lf",
    "sdk/publish_qsdk_r23d30_* text eol=lf",
    "sdk/run_qsdk_r23d30_* text eol=lf",
    "tests/test_qsdk_r23d30_* text eol=lf"
)
$r23d30MissingDiffRules = @(
    $r23d30RequiredRules | Where-Object { -not $r23d30Diff.Contains("+$_") }
)
$r23d30MissingLiveRules = @(
    $r23d30RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d31RequiredRules = @(
    "sdk/turning/r23d31_* text eol=lf",
    "sdk/turning/test_r23d31_* text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d31_* text eol=lf",
    "sdk/publish_qsdk_r23d31_* text eol=lf",
    "sdk/run_qsdk_r23d31_* text eol=lf",
    "tests/test_qsdk_r23d31_* text eol=lf"
)
$r23d31MissingDiffRules = @(
    $r23d31RequiredRules | Where-Object { -not $r23d31Diff.Contains("+$_") }
)
$r23d31MissingLiveRules = @(
    $r23d31RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d32ClosureRequiredRules = @(
    "sdk/turning/r23d32_finite_rapier_turning_replication_closure_v1.json text eol=lf",
    "tests/test_qsdk_r23d32_closure.ps1 text eol=lf"
)
$r23d32ClosureMissingDiffRules = @(
    $r23d32ClosureRequiredRules | Where-Object {
        -not $r23d32ClosureDiff.Contains("+$_")
    }
)
$r23d32ClosureMissingLiveRules = @(
    $r23d32ClosureRequiredRules | Where-Object {
        -not $attributesText.Contains($_)
    }
)
$r23d33RequiredRules = @(
    "sdk/turning/r23d33_* text eol=lf",
    "sdk/turning/test_r23d33_* text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d33_* text eol=lf",
    "sdk/publish_qsdk_r23d33_* text eol=lf",
    "sdk/run_qsdk_r23d33_* text eol=lf",
    "tests/test_qsdk_r23d33_* text eol=lf",
    "tests/test_sdk_qsdk_r23d33_* text eol=lf"
)
$r23d33MissingDiffRules = @(
    $r23d33RequiredRules | Where-Object { -not $r23d33Diff.Contains("+$_") }
)
$r23d33MissingLiveRules = @(
    $r23d33RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d34RequiredRules = @(
    "sdk/turning/r23d34_* text eol=lf",
    "sdk/turning/test_r23d34_* text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d34_* text eol=lf",
    "sdk/publish_qsdk_r23d34_* text eol=lf",
    "sdk/run_qsdk_r23d34_* text eol=lf",
    "tests/test_qsdk_r23d34_* text eol=lf",
    "tests/test_sdk_qsdk_r23d34_* text eol=lf"
)
$r23d34MissingDiffRules = @(
    $r23d34RequiredRules | Where-Object { -not $r23d34Diff.Contains("+$_") }
)
$r23d34MissingLiveRules = @(
    $r23d34RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d35RequiredRules = @(
    "sdk/turning/r23d35_* text eol=lf",
    "sdk/turning/test_r23d35_* text eol=lf",
    "sdk/publish_qsdk_r23d35_* text eol=lf",
    "sdk/run_qsdk_r23d35_* text eol=lf",
    "tests/test_qsdk_r23d35_* text eol=lf",
    "tests/test_sdk_qsdk_r23d35_* text eol=lf"
)
$r23d35MissingDiffRules = @(
    $r23d35RequiredRules | Where-Object { -not $r23d35Diff.Contains("+$_") }
)
$r23d35MissingLiveRules = @(
    $r23d35RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d36RequiredRules = @(
    "sdk/turning/r23d36_* text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d36_* text eol=lf",
    "sdk/run_qsdk_r23d36_* text eol=lf",
    "tests/test_qsdk_r23d36_* text eol=lf"
)
$r23d36MissingDiffRules = @(
    $r23d36RequiredRules | Where-Object { -not $r23d36Diff.Contains("+$_") }
)
$r23d36MissingLiveRules = @(
    $r23d36RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d37RequiredRules = @(
    "sdk/turning/r23d37_* text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d37_* text eol=lf",
    "sdk/run_qsdk_r23d37_* text eol=lf",
    "tests/test_qsdk_r23d37_* text eol=lf",
    "sdk/strict_json_array_document.ps1 text eol=lf",
    "tests/test_strict_json_array_document.ps1 text eol=lf"
)
$r23d37MissingDiffRules = @(
    $r23d37RequiredRules | Where-Object { -not $r23d37Diff.Contains("+$_") }
)
$r23d37MissingLiveRules = @(
    $r23d37RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d38RequiredRules = @(
    "sdk/turning/r23d38_* text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d38_* text eol=lf",
    "sdk/run_qsdk_r23d38_* text eol=lf",
    "tests/test_qsdk_r23d38_* text eol=lf"
)
$r23d38MissingDiffRules = @(
    $r23d38RequiredRules | Where-Object { -not $r23d38Diff.Contains("+$_") }
)
$r23d38MissingLiveRules = @(
    $r23d38RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d39RequiredRules = @(
    "sdk/turning/r23d39_* text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d39_* text eol=lf",
    "sdk/run_qsdk_r23d39_* text eol=lf",
    "tests/test_qsdk_r23d39_* text eol=lf"
)
$r23d39MissingDiffRules = @(
    $r23d39RequiredRules | Where-Object { -not $r23d39Diff.Contains("+$_") }
)
$r23d39MissingLiveRules = @(
    $r23d39RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d40RequiredRules = @(
    "sdk/turning/r23d40_* text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d40_* text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d40_* text eol=lf",
    "sdk/publish_qsdk_r23d40_* text eol=lf",
    "sdk/run_qsdk_r23d40_* text eol=lf",
    "tests/test_qsdk_r23d40_* text eol=lf",
    "tests/test_sdk_qsdk_r23d40_* text eol=lf",
    "scripts/lab/gait/sdk_startup_velocity_ramp.gd text eol=lf",
    "sdk/turning/README.md text eol=lf"
)
$r23d40MissingDiffRules = @(
    $r23d40RequiredRules | Where-Object { -not $r23d40Diff.Contains("+$_") }
)
$r23d40MissingLiveRules = @(
    $r23d40RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d41RequiredRules = @(
    "sdk/turning/r23d41_* text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d41_* text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d41_* text eol=lf",
    "sdk/publish_qsdk_r23d41_* text eol=lf",
    "sdk/run_qsdk_r23d41_* text eol=lf",
    "tests/test_qsdk_r23d41_* text eol=lf",
    "tests/test_sdk_qsdk_r23d41_* text eol=lf"
)
$r23d41MissingDiffRules = @(
    $r23d41RequiredRules | Where-Object { -not $r23d41Diff.Contains("+$_") }
)
$r23d41MissingLiveRules = @(
    $r23d41RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d42RequiredRules = @(
    "sdk/turning/r23d42_* text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d42_* text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d42_* text eol=lf",
    "sdk/publish_qsdk_r23d42_* text eol=lf",
    "sdk/run_qsdk_r23d42_* text eol=lf",
    "tests/test_qsdk_r23d42_* text eol=lf",
    "tests/test_sdk_qsdk_r23d42_* text eol=lf"
)
$r23d42MissingDiffRules = @(
    $r23d42RequiredRules | Where-Object { -not $r23d42Diff.Contains("+$_") }
)
$r23d42MissingLiveRules = @(
    $r23d42RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d43RequiredRules = @(
    "sdk/turning/r23d43_* text eol=lf",
    "sdk/turning/test_r23d43_* text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d43_* text eol=lf",
    "sdk/publish_qsdk_r23d43_* text eol=lf",
    "sdk/run_qsdk_r23d43_* text eol=lf",
    "tests/test_qsdk_r23d43_* text eol=lf"
)
$r23d43MissingDiffRules = @(
    $r23d43RequiredRules | Where-Object { -not $r23d43Diff.Contains("+$_") }
)
$r23d43MissingLiveRules = @(
    $r23d43RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d44RequiredRules = @(
    "sdk/turning/r23d44_* text eol=lf",
    "sdk/turning/test_r23d44_* text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d44_* text eol=lf",
    "sdk/publish_qsdk_r23d44_* text eol=lf",
    "sdk/run_qsdk_r23d44_* text eol=lf",
    "tests/test_qsdk_r23d44_* text eol=lf"
)
$r23d44MissingDiffRules = @(
    $r23d44RequiredRules | Where-Object { -not $r23d44Diff.Contains("+$_") }
)
$r23d44MissingLiveRules = @(
    $r23d44RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d45RequiredRules = @(
    "sdk/turning/r23d45_* text eol=lf",
    "sdk/turning/test_r23d45_* text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d45_* text eol=lf",
    "sdk/run_qsdk_r23d45_* text eol=lf"
)
$r23d45MissingDiffRules = @(
    $r23d45RequiredRules | Where-Object { -not $r23d45Diff.Contains("+$_") }
)
$r23d45MissingLiveRules = @(
    $r23d45RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d46RequiredRules = @(
    "tests/test_qsdk_r23d45_* text eol=lf",
    "sdk/turning/r23d46_* text eol=lf",
    "sdk/turning/test_r23d46_* text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d46_* text eol=lf",
    "sdk/run_qsdk_r23d46_* text eol=lf",
    "tests/test_qsdk_r23d46_* text eol=lf"
)
$r23d46MissingDiffRules = @(
    $r23d46RequiredRules | Where-Object { -not $r23d46Diff.Contains("+$_") }
)
$r23d46MissingLiveRules = @(
    $r23d46RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d47RequiredRules = @(
    "sdk/turning/r23d47_* text eol=lf",
    "sdk/turning/test_r23d47_* text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d47_* text eol=lf",
    "sdk/run_qsdk_r23d47_* text eol=lf",
    "tests/test_qsdk_r23d47_* text eol=lf"
)
$r23d47MissingDiffRules = @(
    $r23d47RequiredRules | Where-Object { -not $r23d47Diff.Contains("+$_") }
)
$r23d47MissingLiveRules = @(
    $r23d47RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d48RequiredRules = @(
    "sdk/turning/r23d48_* text eol=lf",
    "sdk/turning/test_r23d48_* text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d48_* text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d48_* text eol=lf",
    "sdk/run_qsdk_r23d48_* text eol=lf",
    "sdk/publish_qsdk_r23d48_* text eol=lf",
    "tests/test_qsdk_r23d48_* text eol=lf",
    "tests/test_sdk_qsdk_r23d48_* text eol=lf"
)
$r23d48MissingDiffRules = @(
    $r23d48RequiredRules | Where-Object { -not $r23d48Diff.Contains("+$_") }
)
$r23d48MissingLiveRules = @(
    $r23d48RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d49RequiredRules = @(
    "sdk/turning/r23d49_* text eol=lf",
    "sdk/turning/test_r23d49_* text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d49_* text eol=lf",
    "sdk/run_qsdk_r23d49_* text eol=lf",
    "sdk/publish_qsdk_r23d49_* text eol=lf",
    "tests/test_qsdk_r23d49_* text eol=lf"
)
$r23d49MissingDiffRules = @(
    $r23d49RequiredRules | Where-Object { -not $r23d49Diff.Contains("+$_") }
)
$r23d49MissingLiveRules = @(
    $r23d49RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d50RequiredRules = @(
    "sdk/turning/r23d50_* text eol=lf",
    "sdk/turning/test_r23d50_* text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d50_* text eol=lf",
    "sdk/run_qsdk_r23d50_* text eol=lf",
    "sdk/publish_qsdk_r23d50_* text eol=lf",
    "tests/test_qsdk_r23d50_* text eol=lf"
)
$r23d50MissingDiffRules = @(
    $r23d50RequiredRules | Where-Object { -not $r23d50Diff.Contains("+$_") }
)
$r23d50MissingLiveRules = @(
    $r23d50RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d51RequiredRules = @(
    "sdk/turning/r23d51_* text eol=lf",
    "sdk/run_qsdk_r23d51_* text eol=lf",
    "sdk/godot_receipt_terminated_process.ps1 text eol=lf",
    "tests/test_qsdk_r23d51_* text eol=lf",
    "tests/test_sdk_qsdk_r23d51_* text eol=lf",
    "sdk/godot_jolt_transport_execution_contract.json text eol=lf",
    "sdk/godot_jolt_persistent_session_contract.json text eol=lf",
    "sdk/versioning/c_abi_manifest_v1.json text eol=lf",
    "sdk/versioning/schema_registry_v1.json text eol=lf",
    "tests/test_godot_jolt_persistent_session_contract.ps1 text eol=lf"
)
$r23d51MissingDiffRules = @(
    $r23d51RequiredRules | Where-Object { -not $r23d51Diff.Contains("+$_") }
)
$r23d51MissingLiveRules = @(
    $r23d51RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d52RequiredRules = @(
    "sdk/turning/r23d52_* text eol=lf",
    "sdk/run_qsdk_r23d52_* text eol=lf",
    "sdk/locomotion_terminal_execution_projection.ps1 text eol=lf",
    "tests/test_locomotion_terminal_execution_projection.ps1 text eol=lf",
    "tests/test_qsdk_r23d52_* text eol=lf",
    "tests/test_sdk_qsdk_r23d52_* text eol=lf"
)
$r23d52MissingDiffRules = @(
    $r23d52RequiredRules | Where-Object { -not $r23d52Diff.Contains("+$_") }
)
$r23d52MissingLiveRules = @(
    $r23d52RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d53RequiredRules = @(
    "sdk/turning/r23d53_* text eol=lf",
    "sdk/run_qsdk_r23d53_* text eol=lf",
    "tests/test_qsdk_r23d53_* text eol=lf",
    "tests/test_sdk_qsdk_r23d53_* text eol=lf"
)
$r23d53MissingDiffRules = @(
    $r23d53RequiredRules | Where-Object { -not $r23d53Diff.Contains("+$_") }
)
$r23d53MissingLiveRules = @(
    $r23d53RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d54RequiredRules = @(
    "sdk/turning/r23d54_* text eol=lf",
    "sdk/run_qsdk_r23d54_* text eol=lf",
    "tests/test_qsdk_r23d54_* text eol=lf",
    "tests/test_sdk_qsdk_r23d54_* text eol=lf"
)
$r23d54MissingDiffRules = @(
    $r23d54RequiredRules | Where-Object { -not $r23d54Diff.Contains("+$_") }
)
$r23d54MissingLiveRules = @(
    $r23d54RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d55RequiredRules = @(
    "sdk/turning/r23d55_* text eol=lf",
    "tests/test_qsdk_r23d55_* text eol=lf",
    "tests/test_sdk_qsdk_r23d55_* text eol=lf",
    "scripts/lab/gait/sdk_godot_jolt_live_fixture_actuator_cap_binding.gd text eol=lf"
)
$r23d55MissingDiffRules = @(
    $r23d55RequiredRules | Where-Object { -not $r23d55Diff.Contains("+$_") }
)
$r23d55MissingLiveRules = @(
    $r23d55RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d56RequiredRules = @(
    "sdk/turning/r23d56_* text eol=lf",
    "sdk/run_qsdk_r23d56_* text eol=lf",
    "tests/test_qsdk_r23d56_* text eol=lf",
    "tests/test_sdk_qsdk_r23d56_* text eol=lf"
)
$r23d56MissingDiffRules = @(
    $r23d56RequiredRules | Where-Object { -not $r23d56Diff.Contains("+$_") }
)
$r23d56MissingLiveRules = @(
    $r23d56RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d57RequiredRules = @(
    "sdk/turning/r23d57_* text eol=lf",
    "sdk/run_qsdk_r23d57_* text eol=lf",
    "tests/test_qsdk_r23d57_* text eol=lf",
    "tests/test_sdk_qsdk_r23d57_* text eol=lf"
)
$r23d57MissingDiffRules = @(
    $r23d57RequiredRules | Where-Object { -not $r23d57Diff.Contains("+$_") }
)
$r23d57MissingLiveRules = @(
    $r23d57RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d57WorkbenchAuditRequiredRules = @(
    "tests/test_locomotion_experiment_workbench.ps1 text eol=lf"
)
$r23d57WorkbenchAuditMissingDiffRules = @(
    $r23d57WorkbenchAuditRequiredRules | Where-Object {
        -not $r23d57WorkbenchAuditDiff.Contains("+$_")
    }
)
$r23d57WorkbenchAuditMissingLiveRules = @(
    $r23d57WorkbenchAuditRequiredRules | Where-Object {
        -not $attributesText.Contains($_)
    }
)
$r23d58RequiredRules = @(
    "sdk/turning/r23d58_* text eol=lf",
    "sdk/run_qsdk_r23d58_* text eol=lf",
    "tests/test_qsdk_r23d58_* text eol=lf",
    "tests/test_sdk_qsdk_r23d58_* text eol=lf",
    "scripts/lab/gait/sdk_godot_jolt_live_fixture_actuator_cap_factorial_binding.gd text eol=lf"
)
$r23d58MissingDiffRules = @(
    $r23d58RequiredRules | Where-Object { -not $r23d58Diff.Contains("+$_") }
)
$r23d58MissingLiveRules = @(
    $r23d58RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d59RequiredRules = @(
    "sdk/turning/r23d59_* text eol=lf",
    "sdk/run_qsdk_r23d59_* text eol=lf",
    "tests/test_qsdk_r23d59_* text eol=lf",
    "tests/test_sdk_qsdk_r23d59_* text eol=lf"
)
$r23d59MissingDiffRules = @(
    $r23d59RequiredRules | Where-Object { -not $r23d59Diff.Contains("+$_") }
)
$r23d59MissingLiveRules = @(
    $r23d59RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d60RequiredRules = @(
    "sdk/turning/r23d60_* text eol=lf",
    "sdk/run_qsdk_r23d60_* text eol=lf",
    "tests/test_qsdk_r23d60_* text eol=lf",
    "tests/test_sdk_qsdk_r23d60_* text eol=lf"
)
$r23d60MissingDiffRules = @(
    $r23d60RequiredRules | Where-Object { -not $r23d60Diff.Contains("+$_") }
)
$r23d60MissingLiveRules = @(
    $r23d60RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d61RequiredRules = @(
    "sdk/turning/r23d61_* text eol=lf",
    "sdk/run_qsdk_r23d61_* text eol=lf",
    "tests/test_qsdk_r23d61_* text eol=lf",
    "tests/test_sdk_qsdk_r23d61_* text eol=lf"
)
$r23d61MissingDiffRules = @(
    $r23d61RequiredRules | Where-Object { -not $r23d61Diff.Contains("+$_") }
)
$r23d61MissingLiveRules = @(
    $r23d61RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d62RequiredRules = @(
    "sdk/turning/r23d62_* text eol=lf",
    "sdk/run_qsdk_r23d62_* text eol=lf",
    "tests/test_qsdk_r23d62_* text eol=lf",
    "tests/test_sdk_qsdk_r23d62_* text eol=lf",
    "sdk/adapters/rapier/src/bin/qsdk_r23d62_* text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d62_* text eol=lf"
)
$r23d62MissingDiffRules = @(
    $r23d62RequiredRules | Where-Object { -not $r23d62Diff.Contains("+$_") }
)
$r23d62MissingLiveRules = @(
    $r23d62RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r23d62RapierRouteRequiredRules = @(
    "sdk/adapters/rapier/src/actuator_cap_profile.rs text eol=lf",
    "sdk/adapters/rapier/src/qsdk_r23d62_* text eol=lf"
)
$r23d62RapierRouteMissingDiffRules = @(
    $r23d62RapierRouteRequiredRules |
        Where-Object { -not $r23d62RapierRouteDiff.Contains("+$_") }
)
$r23d62RapierRouteMissingLiveRules = @(
    $r23d62RapierRouteRequiredRules |
        Where-Object { -not $attributesText.Contains($_) }
)
$r24d1RequiredRules = @(
    "sdk/recovery/r24d1_* text eol=lf",
    "sdk/run_qsdk_r24d1_* text eol=lf",
    "tests/test_qsdk_r24d1_* text eol=lf"
)
$r24d1MissingDiffRules = @(
    $r24d1RequiredRules | Where-Object { -not $r24d1Diff.Contains("+$_") }
)
$r24d1MissingLiveRules = @(
    $r24d1RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r24d2RequiredRules = @(
    "sdk/recovery/r24d2_* text eol=lf",
    "sdk/run_qsdk_r24d2_* text eol=lf",
    "tests/test_qsdk_r24d2_* text eol=lf",
    "tests/test_sdk_qsdk_r24d2_* text eol=lf",
    "sdk/core/src/recovery.rs text eol=lf",
    "sdk/adapters/rapier/src/recovery_capability.rs text eol=lf",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/recovery_capability.py text eol=lf",
    "sdk/adapters/mujoco/test_recovery_capability.py text eol=lf",
    "sdk/adapters/godot/gdscript/recovery_capability.gd text eol=lf"
)
$r24d2MissingDiffRules = @(
    $r24d2RequiredRules | Where-Object { -not $r24d2Diff.Contains("+$_") }
)
$r24d2MissingLiveRules = @(
    $r24d2RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r24d2IntegrationRequiredRules = @(
    "docs/LOCOMOTION_ARCHITECTURE.md text eol=lf",
    "sdk/adapters/godot/src/lib.rs text eol=lf",
    "sdk/include/sporespore_locomotion.h text eol=lf",
    "sdk/recovery/README.md text eol=lf",
    "sdk/release/README.md text eol=lf",
    "sdk/test_quadruped_sdk_release_readiness.ps1 text eol=lf",
    "sdk/versioning/README.md text eol=lf",
    "sdk/versioning/test_conformance.py text eol=lf"
)
$r24d2IntegrationMissingDiffRules = @(
    $r24d2IntegrationRequiredRules |
        Where-Object { -not $r24d2IntegrationDiff.Contains("+$_") }
)
$r24d2IntegrationMissingLiveRules = @(
    $r24d2IntegrationRequiredRules |
        Where-Object { -not $attributesText.Contains($_) }
)
$r24d3RequiredRules = @(
    "sdk/recovery/r24d3_* text eol=lf",
    "sdk/run_qsdk_r24d3_* text eol=lf",
    "sdk/adapters/godot/engine_patches/* text eol=lf",
    "sdk/adapters/godot/engine_patches/*.patch whitespace=-blank-at-eol,-blank-at-eof,-space-before-tab",
    "tests/test_qsdk_r24d3_* text eol=lf",
    "tests/test_sdk_qsdk_r24d3_* text eol=lf"
)
$r24d3MissingDiffRules = @(
    $r24d3RequiredRules | Where-Object { -not $r24d3Diff.Contains("+$_") }
)
$r24d3MissingLiveRules = @(
    $r24d3RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r24d4RequiredRules = @(
    "sdk/recovery/r24d4_* text eol=lf",
    "sdk/run_qsdk_r24d4_* text eol=lf",
    "scripts/lab/rigs/r24d4_* text eol=lf",
    "tests/test_qsdk_r24d4_* text eol=lf",
    "tests/test_sdk_qsdk_r24d4_* text eol=lf"
)
$r24d4MissingDiffRules = @(
    $r24d4RequiredRules | Where-Object { -not $r24d4Diff.Contains("+$_") }
)
$r24d4MissingLiveRules = @(
    $r24d4RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r24d4ExistingNewPaths = @(
    "scripts/lab/rigs/r24d4_godot_jolt_one_hinge_telemetry_rig.gd",
    "scripts/lab/rigs/r24d4_godot_jolt_telemetry_stepping_probe_body.gd",
    "sdk/recovery/r24d4_godot_jolt_one_hinge_telemetry_characterization_evaluator.py",
    "sdk/recovery/r24d4_godot_jolt_one_hinge_telemetry_characterization_preregistration_v1.json",
    "sdk/recovery/r24d4_godot_jolt_one_hinge_telemetry_validation_manifest.json",
    "sdk/run_qsdk_r24d4_one_hinge_telemetry_characterization.ps1",
    "tests/test_qsdk_r24d4_one_hinge_telemetry_freeze.ps1",
    "tests/test_sdk_qsdk_r24d4_godot_jolt_one_hinge_telemetry_physical_worker.gd"
)
$r24d4BlobFaithfulPathCount = 0
$r24d4CrByteCount = 0
foreach ($relativePath in $r24d4ExistingNewPaths) {
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Exact (
        Test-Path -LiteralPath $absolutePath -PathType Leaf
    ) "R24D4 declared uncommitted source path is absent: $relativePath"
    $rawOid = @(
        git -C $repoRoot hash-object --no-filters -- $relativePath
    ) -join ""
    $filteredOid = @(
        git -C $repoRoot hash-object --path=$relativePath -- $relativePath
    ) -join ""
    if ($rawOid -ceq $filteredOid) {
        $r24d4BlobFaithfulPathCount += 1
    }
    $r24d4CrByteCount += @(
        [System.IO.File]::ReadAllBytes($absolutePath) |
            Where-Object { $_ -eq 13 }
    ).Count
}

$r24d4ClosureReusedRules = @(
    "sdk/recovery/r24d4_* text eol=lf",
    "tests/test_qsdk_r24d4_* text eol=lf"
)
$r24d4ClosureMissingLiveRules = @(
    $r24d4ClosureReusedRules |
        Where-Object { -not $attributesText.Contains($_) }
)
$r24d4ClosurePaths = @(
    "sdk/recovery/r24d4_godot_jolt_one_hinge_telemetry_zero_world_failure_closure_v1.json",
    "tests/test_qsdk_r24d4_one_hinge_telemetry_zero_world_failure_closure.ps1"
)
$r24d4ClosureBlobFaithfulPathCount = 0
$r24d4ClosureCrByteCount = 0
foreach ($relativePath in $r24d4ClosurePaths) {
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Exact (
        Test-Path -LiteralPath $absolutePath -PathType Leaf
    ) "R24D4 zero-world closure path is absent: $relativePath"
    $rawOid = @(
        git -C $repoRoot hash-object --no-filters -- $relativePath
    ) -join ""
    $filteredOid = @(
        git -C $repoRoot hash-object --path=$relativePath -- $relativePath
    ) -join ""
    if ($rawOid -ceq $filteredOid) {
        $r24d4ClosureBlobFaithfulPathCount += 1
    }
    $r24d4ClosureCrByteCount += @(
        [System.IO.File]::ReadAllBytes($absolutePath) |
            Where-Object { $_ -eq 13 }
    ).Count
}

$r24d5RequiredRules = @(
    "sdk/recovery/r24d5_* text eol=lf",
    "sdk/run_qsdk_r24d5_* text eol=lf",
    "scripts/lab/rigs/r24d5_* text eol=lf",
    "tests/test_qsdk_r24d5_* text eol=lf",
    "tests/test_sdk_qsdk_r24d5_* text eol=lf"
)
$r24d5MissingDiffRules = @(
    $r24d5RequiredRules | Where-Object { -not $r24d5Diff.Contains("+$_") }
)
$r24d5MissingLiveRules = @(
    $r24d5RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r24d5ExistingNewPaths = @(
    "scripts/lab/rigs/r24d5_godot_jolt_one_hinge_telemetry_rig.gd",
    "scripts/lab/rigs/r24d5_godot_jolt_telemetry_stepping_probe_body.gd",
    "sdk/recovery/r24d5_godot_jolt_one_hinge_telemetry_characterization_evaluator.py",
    "sdk/recovery/r24d5_godot_jolt_one_hinge_telemetry_characterization_preregistration_v1.json",
    "sdk/recovery/r24d5_godot_jolt_one_hinge_telemetry_validation_manifest.json",
    "sdk/recovery/r24d5_precommit_zero_world_diagnostics_v1.json",
    "sdk/run_qsdk_r24d5_one_hinge_telemetry_characterization.ps1",
    "tests/test_qsdk_r24d5_one_hinge_telemetry_freeze.ps1",
    "tests/test_sdk_qsdk_r24d5_godot_jolt_one_hinge_telemetry_physical_worker.gd"
)
$r24d5BlobFaithfulPathCount = 0
$r24d5CrByteCount = 0
foreach ($relativePath in $r24d5ExistingNewPaths) {
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Exact (
        Test-Path -LiteralPath $absolutePath -PathType Leaf
    ) "R24D5 declared uncommitted source path is absent: $relativePath"
    $rawOid = @(
        git -C $repoRoot hash-object --no-filters -- $relativePath
    ) -join ""
    $filteredOid = @(
        git -C $repoRoot hash-object --path=$relativePath -- $relativePath
    ) -join ""
    if ($rawOid -ceq $filteredOid) {
        $r24d5BlobFaithfulPathCount += 1
    }
    $r24d5CrByteCount += @(
        [System.IO.File]::ReadAllBytes($absolutePath) |
            Where-Object { $_ -eq 13 }
    ).Count
}

$r24d6RequiredRules = @(
    "sdk/recovery/r24d6_* text eol=lf",
    "sdk/run_qsdk_r24d6_* text eol=lf",
    "scripts/lab/rigs/r24d6_* text eol=lf",
    "tests/test_qsdk_r24d6_* text eol=lf",
    "tests/test_sdk_qsdk_r24d6_* text eol=lf"
)
$r24d6MissingDiffRules = @(
    $r24d6RequiredRules | Where-Object { -not $r24d6Diff.Contains("+$_") }
)
$r24d6MissingLiveRules = @(
    $r24d6RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r24d6SourcePaths = @(
    "scripts/lab/rigs/r24d6_godot_jolt_one_hinge_telemetry_rig.gd",
    "scripts/lab/rigs/r24d6_godot_jolt_telemetry_stepping_probe_body.gd",
    "sdk/recovery/r24d6_godot_jolt_one_hinge_telemetry_characterization_evaluator.py",
    "sdk/recovery/r24d6_godot_jolt_one_hinge_telemetry_characterization_preregistration_v1.json",
    "sdk/recovery/r24d6_godot_jolt_one_hinge_telemetry_validation_manifest.json",
    "sdk/recovery/r24d6_precommit_godot_parser_diagnostics_v1.json",
    "sdk/run_qsdk_r24d6_one_hinge_telemetry_characterization.ps1",
    "tests/test_qsdk_r24d6_one_hinge_telemetry_freeze.ps1",
    "tests/test_sdk_qsdk_r24d6_godot_jolt_one_hinge_telemetry_physical_worker.gd"
)
$r24d6BlobFaithfulPathCount = 0
$r24d6CrByteCount = 0
foreach ($relativePath in $r24d6SourcePaths) {
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Exact (
        Test-Path -LiteralPath $absolutePath -PathType Leaf
    ) "R24D6 declared source path is absent: $relativePath"
    $rawOid = @(
        git -C $repoRoot hash-object --no-filters -- $relativePath
    ) -join ""
    $filteredOid = @(
        git -C $repoRoot hash-object --path=$relativePath -- $relativePath
    ) -join ""
    if ($rawOid -ceq $filteredOid) {
        $r24d6BlobFaithfulPathCount += 1
    }
    $r24d6CrByteCount += @(
        [System.IO.File]::ReadAllBytes($absolutePath) |
            Where-Object { $_ -eq 13 }
    ).Count
}

$r24d7RequiredRules = @(
    "sdk/recovery/r24d7_* text eol=lf",
    "sdk/run_qsdk_r24d7_* text eol=lf",
    "scripts/lab/rigs/r24d7_* text eol=lf",
    "tests/test_qsdk_r24d7_* text eol=lf",
    "tests/test_sdk_qsdk_r24d7_* text eol=lf"
)
$r24d7MissingDiffRules = @(
    $r24d7RequiredRules | Where-Object { -not $r24d7Diff.Contains("+$_") }
)
$r24d7MissingLiveRules = @(
    $r24d7RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r24d7SourcePaths = @(
    "scripts/lab/rigs/r24d7_godot_jolt_one_hinge_telemetry_rig.gd",
    "scripts/lab/rigs/r24d7_godot_jolt_telemetry_stepping_probe_body.gd",
    "sdk/recovery/r24d7_godot_jolt_one_hinge_telemetry_characterization_evaluator.py",
    "sdk/recovery/r24d7_godot_jolt_one_hinge_telemetry_characterization_preregistration_v1.json",
    "sdk/recovery/r24d7_godot_jolt_one_hinge_telemetry_validation_manifest.json",
    "sdk/recovery/r24d7_integral_variant_schema_v1.json",
    "sdk/recovery/r24d7_precommit_godot_parser_diagnostics_v1.json",
    "sdk/run_qsdk_r24d7_one_hinge_telemetry_characterization.ps1",
    "tests/test_qsdk_r24d7_one_hinge_telemetry_freeze.ps1",
    "tests/test_sdk_qsdk_r24d7_godot_jolt_one_hinge_telemetry_physical_worker.gd"
)
$r24d7BlobFaithfulPathCount = 0
$r24d7CrByteCount = 0
foreach ($relativePath in $r24d7SourcePaths) {
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Exact (
        Test-Path -LiteralPath $absolutePath -PathType Leaf
    ) "R24D7 declared source path is absent: $relativePath"
    $rawOid = @(
        git -C $repoRoot hash-object --no-filters -- $relativePath
    ) -join ""
    $filteredOid = @(
        git -C $repoRoot hash-object --path=$relativePath -- $relativePath
    ) -join ""
    if ($rawOid -ceq $filteredOid) {
        $r24d7BlobFaithfulPathCount += 1
    }
    $r24d7CrByteCount += @(
        [System.IO.File]::ReadAllBytes($absolutePath) |
            Where-Object { $_ -eq 13 }
    ).Count
}

$r24d8RequiredRules = @(
    "sdk/recovery/r24d8_* text eol=lf",
    "sdk/run_qsdk_r24d8_* text eol=lf",
    "scripts/lab/rigs/r24d8_* text eol=lf",
    "tests/test_qsdk_r24d8_* text eol=lf",
    "tests/test_sdk_qsdk_r24d8_* text eol=lf",
    "sdk/adapters/godot/engine_patches/godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch text eol=lf"
)
$r24d8MissingDiffRules = @(
    $r24d8RequiredRules | Where-Object { -not $r24d8Diff.Contains("+$_") }
)
$r24d8MissingLiveRules = @(
    $r24d8RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r24d8SourcePaths = @(
    "scripts/lab/rigs/r24d8_godot_jolt_active_step_snapshot_timing_rig.gd",
    "sdk/adapters/godot/engine_patches/godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch",
    "sdk/recovery/r24d8_godot_jolt_active_step_snapshot_timing_evaluator.py",
    "sdk/recovery/r24d8_godot_jolt_active_step_snapshot_timing_preregistration_v1.json",
    "sdk/recovery/r24d8_godot_jolt_active_step_snapshot_timing_validation_manifest.json",
    "sdk/recovery/r24d8_first_official_zero_world_qualification_failure_v1.json",
    "sdk/recovery/r24d8_maintenance_precommit_diagnostics_v1.json",
    "sdk/recovery/r24d8_precommit_zero_world_diagnostics_v1.json",
    "sdk/run_qsdk_r24d8_active_step_snapshot_timing.ps1",
    "tests/test_qsdk_r24d8_godot_jolt_active_step_snapshot_timing_freeze.ps1",
    "tests/test_qsdk_r24d8_predecessor_evidence_compatibility.ps1",
    "tests/test_sdk_qsdk_r24d8_godot_jolt_active_step_snapshot_timing_worker.gd"
)
$r24d8BlobFaithfulPathCount = 0
$r24d8CrByteCount = 0
foreach ($relativePath in $r24d8SourcePaths) {
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Exact (
        Test-Path -LiteralPath $absolutePath -PathType Leaf
    ) "R24D8 declared source path is absent: $relativePath"
    $rawOid = @(
        git -C $repoRoot hash-object --no-filters -- $relativePath
    ) -join ""
    $filteredOid = @(
        git -C $repoRoot hash-object --path=$relativePath -- $relativePath
    ) -join ""
    if ($rawOid -ceq $filteredOid) {
        $r24d8BlobFaithfulPathCount += 1
    }
    $r24d8CrByteCount += @(
        [System.IO.File]::ReadAllBytes($absolutePath) |
            Where-Object { $_ -eq 13 }
    ).Count
}

$r24d9RequiredRules = @(
    "sdk/recovery/r24d9_* text eol=lf",
    "sdk/run_qsdk_r24d9_* text eol=lf",
    "scripts/lab/rigs/r24d9_* text eol=lf",
    "tests/test_qsdk_r24d9_* text eol=lf",
    "tests/test_sdk_qsdk_r24d9_* text eol=lf"
)
$r24d9MissingDiffRules = @(
    $r24d9RequiredRules | Where-Object { -not $r24d9Diff.Contains("+$_") }
)
$r24d9MissingLiveRules = @(
    $r24d9RequiredRules | Where-Object { -not $attributesText.Contains($_) }
)
$r24d9SourcePaths = @(
    "sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_characterization_preregistration_v1.json",
    "tests/test_qsdk_r24d9_numerical_telemetry_preregistration.ps1"
)
$r24d9BlobFaithfulPathCount = 0
$r24d9CrByteCount = 0
foreach ($relativePath in $r24d9SourcePaths) {
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Exact (
        Test-Path -LiteralPath $absolutePath -PathType Leaf
    ) "R24D9 declared source path is absent: $relativePath"
    $rawOid = @(
        git -C $repoRoot hash-object --no-filters -- $relativePath
    ) -join ""
    $filteredOid = @(
        git -C $repoRoot hash-object --path=$relativePath -- $relativePath
    ) -join ""
    if ($rawOid -ceq $filteredOid) {
        $r24d9BlobFaithfulPathCount += 1
    }
    $r24d9CrByteCount += @(
        [System.IO.File]::ReadAllBytes($absolutePath) |
            Where-Object { $_ -eq 13 }
    ).Count
}

$r24d5ClosureReusedRules = @(
    "sdk/recovery/r24d5_* text eol=lf",
    "tests/test_qsdk_r24d5_* text eol=lf"
)
$r24d5ClosureMissingLiveRules = @(
    $r24d5ClosureReusedRules |
        Where-Object { -not $attributesText.Contains($_) }
)
$r24d5ClosurePaths = @(
    "sdk/recovery/r24d5_godot_jolt_one_hinge_telemetry_physical_failure_closure_v1.json",
    "tests/test_qsdk_r24d5_one_hinge_telemetry_physical_failure_closure.ps1"
)
$r24d5ClosureBlobFaithfulPathCount = 0
$r24d5ClosureCrByteCount = 0
foreach ($relativePath in $r24d5ClosurePaths) {
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Exact (
        Test-Path -LiteralPath $absolutePath -PathType Leaf
    ) "R24D5 physical failure closure path is absent: $relativePath"
    $rawOid = @(
        git -C $repoRoot hash-object --no-filters -- $relativePath
    ) -join ""
    $filteredOid = @(
        git -C $repoRoot hash-object --path=$relativePath -- $relativePath
    ) -join ""
    if ($rawOid -ceq $filteredOid) {
        $r24d5ClosureBlobFaithfulPathCount += 1
    }
    $r24d5ClosureCrByteCount += @(
        [System.IO.File]::ReadAllBytes($absolutePath) |
            Where-Object { $_ -eq 13 }
    ).Count
}

$r24d6ClosureReusedRules = @(
    "sdk/recovery/r24d6_* text eol=lf",
    "tests/test_qsdk_r24d6_* text eol=lf"
)
$r24d6ClosureMissingLiveRules = @(
    $r24d6ClosureReusedRules |
        Where-Object { -not $attributesText.Contains($_) }
)
$r24d6ClosurePaths = @(
    "sdk/recovery/r24d6_godot_jolt_one_hinge_telemetry_zero_world_failure_closure_v1.json",
    "tests/test_qsdk_r24d6_one_hinge_telemetry_zero_world_failure_closure.ps1"
)
$r24d6ClosureBlobFaithfulPathCount = 0
$r24d6ClosureCrByteCount = 0
foreach ($relativePath in $r24d6ClosurePaths) {
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Exact (
        Test-Path -LiteralPath $absolutePath -PathType Leaf
    ) "R24D6 zero-world failure closure path is absent: $relativePath"
    $rawOid = @(
        git -C $repoRoot hash-object --no-filters -- $relativePath
    ) -join ""
    $filteredOid = @(
        git -C $repoRoot hash-object --path=$relativePath -- $relativePath
    ) -join ""
    if ($rawOid -ceq $filteredOid) {
        $r24d6ClosureBlobFaithfulPathCount += 1
    }
    $r24d6ClosureCrByteCount += @(
        [System.IO.File]::ReadAllBytes($absolutePath) |
            Where-Object { $_ -eq 13 }
    ).Count
}

$r24d7ClosureReusedRules = @(
    "sdk/recovery/r24d7_* text eol=lf",
    "tests/test_qsdk_r24d7_* text eol=lf"
)
$r24d7ClosureMissingLiveRules = @(
    $r24d7ClosureReusedRules |
        Where-Object { -not $attributesText.Contains($_) }
)
$r24d7ClosurePaths = @(
    "sdk/recovery/r24d7_godot_jolt_one_hinge_telemetry_physical_failure_closure_v1.json",
    "tests/test_qsdk_r24d7_one_hinge_telemetry_physical_failure_closure.ps1"
)
$r24d7ClosureBlobFaithfulPathCount = 0
$r24d7ClosureCrByteCount = 0
foreach ($relativePath in $r24d7ClosurePaths) {
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Exact (
        Test-Path -LiteralPath $absolutePath -PathType Leaf
    ) "R24D7 physical failure closure path is absent: $relativePath"
    $rawOid = @(
        git -C $repoRoot hash-object --no-filters -- $relativePath
    ) -join ""
    $filteredOid = @(
        git -C $repoRoot hash-object --path=$relativePath -- $relativePath
    ) -join ""
    if ($rawOid -ceq $filteredOid) {
        $r24d7ClosureBlobFaithfulPathCount += 1
    }
    $r24d7ClosureCrByteCount += @(
        [System.IO.File]::ReadAllBytes($absolutePath) |
            Where-Object { $_ -eq 13 }
    ).Count
}

Assert-Exact (
    [string]$r23d37Extension.declared_from_parent_commit -ceq
        "23036cd777bd371065e0a7d086dbe4cd92f8bb56" -and
    [string]$r23d37Extension.source_rule_commit -ceq
        "1010479fbabfe6a0702bc31b4623a65b9ca0dbb0" -and
    [string]$r23d37Extension.scope -ceq
        "prospective_r23d37_mujoco_policy_seed_isolation_and_strict_array_source_family_only" -and
    [int]$r23d37Extension.added_rule_count -eq 6 -and
    -not [bool]$r23d37Extension.ambient_rule_changed -and
    -not [bool]$r23d37Extension.historical_path_rule_changed -and
    -not [bool]$r23d37Extension.renormalization_executed -and
    -not [bool]$r23d37Extension.checkout_filter_migration_executed -and
    $r23d37RequiredRules.Count -eq 6 -and
    $r23d37MissingDiffRules.Count -eq 0 -and
    $r23d37MissingLiveRules.Count -eq 0 -and
    -not $r23d37Diff.Contains("+* text=auto") -and
    -not $r23d37Diff.Contains("+* -text")
) "R23D37 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d38Extension.declared_from_parent_commit -ceq
        "b23acf11b725ae51e77c58ed82d61bb1c858806c" -and
    [string]$r23d38Extension.scope -ceq
        "prospective_r23d38_mujoco_canonical_startup_ramp_stabilization_source_family_only" -and
    [int]$r23d38Extension.added_rule_count -eq 4 -and
    -not [bool]$r23d38Extension.ambient_rule_changed -and
    -not [bool]$r23d38Extension.historical_path_rule_changed -and
    -not [bool]$r23d38Extension.renormalization_executed -and
    -not [bool]$r23d38Extension.checkout_filter_migration_executed -and
    $r23d38RequiredRules.Count -eq 4 -and
    $r23d38MissingDiffRules.Count -eq 0 -and
    $r23d38MissingLiveRules.Count -eq 0 -and
    -not $r23d38Diff.Contains("+* text=auto") -and
    -not $r23d38Diff.Contains("+* -text")
) "R23D38 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d39Extension.declared_from_parent_commit -ceq
        "5ee7d2d114aad078d89d7eb44f990f5971f0d7b7" -and
    [string]$r23d39Extension.scope -ceq
        "prospective_r23d39_mujoco_startup_ramp_turning_development_source_family_only" -and
    [int]$r23d39Extension.added_rule_count -eq 4 -and
    -not [bool]$r23d39Extension.ambient_rule_changed -and
    -not [bool]$r23d39Extension.historical_path_rule_changed -and
    -not [bool]$r23d39Extension.renormalization_executed -and
    -not [bool]$r23d39Extension.checkout_filter_migration_executed -and
    $r23d39RequiredRules.Count -eq 4 -and
    $r23d39MissingDiffRules.Count -eq 0 -and
    $r23d39MissingLiveRules.Count -eq 0 -and
    -not $r23d39Diff.Contains("+* text=auto") -and
    -not $r23d39Diff.Contains("+* -text")
) "R23D39 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d40Extension.declared_from_parent_commit -ceq
        "db0cc25a44128273c30b8c727ed773e3dcdcb1a2" -and
    [string]$r23d40Extension.scope -ceq
        "prospective_r23d40_three_engine_startup_ramp_turning_validation_source_family_only" -and
    [int]$r23d40Extension.added_rule_count -eq 9 -and
    -not [bool]$r23d40Extension.ambient_rule_changed -and
    -not [bool]$r23d40Extension.historical_path_rule_changed -and
    -not [bool]$r23d40Extension.renormalization_executed -and
    -not [bool]$r23d40Extension.checkout_filter_migration_executed -and
    $r23d40RequiredRules.Count -eq 9 -and
    $r23d40MissingDiffRules.Count -eq 0 -and
    $r23d40MissingLiveRules.Count -eq 0 -and
    -not $r23d40Diff.Contains("+* text=auto") -and
    -not $r23d40Diff.Contains("+* -text")
) "R23D40 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d41Extension.declared_from_parent_commit -ceq
        "5a61ccac16b71a17fd50573475fbff7778e68920" -and
    [string]$r23d41Extension.scope -ceq
        "prospective_r23d41_authorization_repaired_three_engine_turning_validation_source_family_only" -and
    [int]$r23d41Extension.added_rule_count -eq 7 -and
    -not [bool]$r23d41Extension.ambient_rule_changed -and
    -not [bool]$r23d41Extension.historical_path_rule_changed -and
    -not [bool]$r23d41Extension.renormalization_executed -and
    -not [bool]$r23d41Extension.checkout_filter_migration_executed -and
    $r23d41RequiredRules.Count -eq 7 -and
    $r23d41MissingDiffRules.Count -eq 0 -and
    $r23d41MissingLiveRules.Count -eq 0 -and
    -not $r23d41Diff.Contains("+* text=auto") -and
    -not $r23d41Diff.Contains("+* -text")
) "R23D41 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d42Extension.declared_from_parent_commit -ceq
        "636fe87fb7bd4ae1f796eb672d5577de51e5e1fa" -and
    [string]$r23d42Extension.scope -ceq
        "prospective_r23d42_trace_interface_repair_replication_source_family_only" -and
    [int]$r23d42Extension.added_rule_count -eq 7 -and
    -not [bool]$r23d42Extension.ambient_rule_changed -and
    -not [bool]$r23d42Extension.historical_path_rule_changed -and
    -not [bool]$r23d42Extension.renormalization_executed -and
    -not [bool]$r23d42Extension.checkout_filter_migration_executed -and
    $r23d42RequiredRules.Count -eq 7 -and
    $r23d42MissingDiffRules.Count -eq 0 -and
    $r23d42MissingLiveRules.Count -eq 0 -and
    -not $r23d42Diff.Contains("+* text=auto") -and
    -not $r23d42Diff.Contains("+* -text")
) "R23D42 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d43Extension.declared_from_parent_commit -ceq
        "0790d1ae01efd32b5a2f9e0edf1ccfa70012dec9" -and
    [string]$r23d43Extension.source_rule_commit -ceq
        "f6eba21ac7c5bddd6763db37a65ed547ed8a3c38" -and
    [string]$r23d43Extension.scope -ceq
        "prospective_r23d43_rapier_retention_hardened_turning_replication_source_family_only" -and
    [int]$r23d43Extension.added_rule_count -eq 6 -and
    -not [bool]$r23d43Extension.ambient_rule_changed -and
    -not [bool]$r23d43Extension.historical_path_rule_changed -and
    -not [bool]$r23d43Extension.renormalization_executed -and
    -not [bool]$r23d43Extension.checkout_filter_migration_executed -and
    $r23d43RequiredRules.Count -eq 6 -and
    $r23d43MissingDiffRules.Count -eq 0 -and
    $r23d43MissingLiveRules.Count -eq 0 -and
    -not $r23d43Diff.Contains("+* text=auto") -and
    -not $r23d43Diff.Contains("+* -text")
) "R23D43 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d44Extension.declared_from_parent_commit -ceq
        "6bc708ce5ab63157fa36f73f30414b80244f82d4" -and
    [string]$r23d44Extension.scope -ceq
        "prospective_r23d44_rapier_paired_startup_transform_development_source_family_only" -and
    [int]$r23d44Extension.added_rule_count -eq 6 -and
    -not [bool]$r23d44Extension.ambient_rule_changed -and
    -not [bool]$r23d44Extension.historical_path_rule_changed -and
    -not [bool]$r23d44Extension.renormalization_executed -and
    -not [bool]$r23d44Extension.checkout_filter_migration_executed -and
    $r23d44RequiredRules.Count -eq 6 -and
    $r23d44MissingDiffRules.Count -eq 0 -and
    $r23d44MissingLiveRules.Count -eq 0 -and
    -not $r23d44Diff.Contains("+* text=auto") -and
    -not $r23d44Diff.Contains("+* -text")
) "R23D44 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d45Extension.declared_from_parent_commit -ceq
        "d599333286c1d0e2da6c0bf837fcddad1e634921" -and
    [string]$r23d45Extension.source_rule_commit -ceq
        "0db5316ddafe2ab5ce9e2211227269f45fcbcea6" -and
    [string]$r23d45Extension.scope -ceq
        "prospective_r23d45_support_loss_conditioned_startup_development_source_family_only" -and
    [int]$r23d45Extension.added_rule_count -eq 4 -and
    -not [bool]$r23d45Extension.ambient_rule_changed -and
    -not [bool]$r23d45Extension.historical_path_rule_changed -and
    -not [bool]$r23d45Extension.renormalization_executed -and
    -not [bool]$r23d45Extension.checkout_filter_migration_executed -and
    $r23d45RequiredRules.Count -eq 4 -and
    $r23d45MissingDiffRules.Count -eq 0 -and
    $r23d45MissingLiveRules.Count -eq 0 -and
    -not $r23d45Diff.Contains("+* text=auto") -and
    -not $r23d45Diff.Contains("+* -text")
) "R23D45 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d46Extension.declared_from_parent_commit -ceq
        "006776801640f5e4b221a9fc3822567cdd0177a1" -and
    [string]$r23d46Extension.source_rule_commit -ceq
        "341e7ba3bcf0c12231f715c62da54034bc67d6b6" -and
    [string]$r23d46Extension.scope -ceq
        "r23d45_closure_audit_and_prospective_r23d46_inherited_interface_repair_source_families_only" -and
    [int]$r23d46Extension.added_rule_count -eq 6 -and
    -not [bool]$r23d46Extension.ambient_rule_changed -and
    -not [bool]$r23d46Extension.historical_path_rule_changed -and
    -not [bool]$r23d46Extension.renormalization_executed -and
    -not [bool]$r23d46Extension.checkout_filter_migration_executed -and
    $r23d46RequiredRules.Count -eq 6 -and
    $r23d46MissingDiffRules.Count -eq 0 -and
    $r23d46MissingLiveRules.Count -eq 0 -and
    -not $r23d46Diff.Contains("+* text=auto") -and
    -not $r23d46Diff.Contains("+* -text")
) "R23D46 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d47Extension.declared_from_parent_commit -ceq
        "7b02303cecfeed73910310b53c1b1ae344bee67a" -and
    [string]$r23d47Extension.source_rule_commit -ceq
        "4059eb703428b60a88837e426d38411bdf69058d" -and
    [string]$r23d47Extension.scope -ceq
        "prospective_r23d47_trace_retention_interface_repair_source_family_only" -and
    [int]$r23d47Extension.added_rule_count -eq 5 -and
    -not [bool]$r23d47Extension.ambient_rule_changed -and
    -not [bool]$r23d47Extension.historical_path_rule_changed -and
    -not [bool]$r23d47Extension.renormalization_executed -and
    -not [bool]$r23d47Extension.checkout_filter_migration_executed -and
    $r23d47RequiredRules.Count -eq 5 -and
    $r23d47MissingDiffRules.Count -eq 0 -and
    $r23d47MissingLiveRules.Count -eq 0 -and
    -not $r23d47Diff.Contains("+* text=auto") -and
    -not $r23d47Diff.Contains("+* -text")
) "R23D47 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d48Extension.declared_from_parent_commit -ceq
        "de9cd4691f53eabf926c9ecb87258714257da472" -and
    [string]$r23d48Extension.scope -ceq
        "prospective_r23d48_support_loss_conditioned_three_engine_turning_source_family_only" -and
    [int]$r23d48Extension.added_rule_count -eq 8 -and
    -not [bool]$r23d48Extension.ambient_rule_changed -and
    -not [bool]$r23d48Extension.historical_path_rule_changed -and
    -not [bool]$r23d48Extension.renormalization_executed -and
    -not [bool]$r23d48Extension.checkout_filter_migration_executed -and
    $r23d48RequiredRules.Count -eq 8 -and
    $r23d48MissingDiffRules.Count -eq 0 -and
    $r23d48MissingLiveRules.Count -eq 0 -and
    -not $r23d48Diff.Contains("+* text=auto") -and
    -not $r23d48Diff.Contains("+* -text")
) "R23D48 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d49Extension.declared_from_parent_commit -ceq
        "2553aad64ca695bbb55a426207c7b9e21cdb85c4" -and
    [string]$r23d49Extension.scope -ceq
        "prospective_r23d49_rapier_retention_repair_replay_source_family_only" -and
    [int]$r23d49Extension.added_rule_count -eq 6 -and
    -not [bool]$r23d49Extension.ambient_rule_changed -and
    -not [bool]$r23d49Extension.historical_path_rule_changed -and
    -not [bool]$r23d49Extension.renormalization_executed -and
    -not [bool]$r23d49Extension.checkout_filter_migration_executed -and
    $r23d49RequiredRules.Count -eq 6 -and
    $r23d49MissingDiffRules.Count -eq 0 -and
    $r23d49MissingLiveRules.Count -eq 0 -and
    -not $r23d49Diff.Contains("+* text=auto") -and
    -not $r23d49Diff.Contains("+* -text")
) "R23D49 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d50Extension.declared_from_parent_commit -ceq
        "10e7f32c1f0fb938f5c937b30012c501769f3698" -and
    [string]$r23d50Extension.scope -ceq
        "prospective_r23d50_rapier_cas_path_identity_replay_source_family_only" -and
    [int]$r23d50Extension.added_rule_count -eq 6 -and
    -not [bool]$r23d50Extension.ambient_rule_changed -and
    -not [bool]$r23d50Extension.historical_path_rule_changed -and
    -not [bool]$r23d50Extension.renormalization_executed -and
    -not [bool]$r23d50Extension.checkout_filter_migration_executed -and
    $r23d50RequiredRules.Count -eq 6 -and
    $r23d50MissingDiffRules.Count -eq 0 -and
    $r23d50MissingLiveRules.Count -eq 0 -and
    -not $r23d50Diff.Contains("+* text=auto") -and
    -not $r23d50Diff.Contains("+* -text")
) "R23D50 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d51Extension.declared_from_parent_commit -ceq
        "5dabcbde0411799f270cca8bfca2d1d78c719b5b" -and
    [string]$r23d51Extension.source_rule_commit -ceq
        "0fcd4d3836dbf86423f1923b66c87d3b20b2ff0b" -and
    [string]$r23d51Extension.scope -ceq
        "prospective_r23d51_godot_segment_origin_and_transport_session_source_families_only" -and
    [int]$r23d51Extension.added_rule_count -eq 10 -and
    -not [bool]$r23d51Extension.ambient_rule_changed -and
    -not [bool]$r23d51Extension.historical_path_rule_changed -and
    -not [bool]$r23d51Extension.renormalization_executed -and
    -not [bool]$r23d51Extension.checkout_filter_migration_executed -and
    [string]$r23d51Extension.first_scoped_qualification_disposition -ceq
        "failed_closed_at_cak1_evidence_provenance_before_physics_because_this_extension_was_not_yet_declared" -and
    $r23d51RequiredRules.Count -eq 10 -and
    $r23d51MissingDiffRules.Count -eq 0 -and
    $r23d51MissingLiveRules.Count -eq 0 -and
    -not $r23d51Diff.Contains("+* text=auto") -and
    -not $r23d51Diff.Contains("+* -text")
) "R23D51 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d52Extension.declared_from_parent_commit -ceq
        "22ebf4de32a8867beb2140db6827b9f374daf69c" -and
    [string]$r23d52Extension.scope -ceq
        "prospective_r23d52_supervisor_schema_replay_and_shared_terminal_projection_source_families_only" -and
    [int]$r23d52Extension.added_rule_count -eq 6 -and
    -not [bool]$r23d52Extension.ambient_rule_changed -and
    -not [bool]$r23d52Extension.historical_path_rule_changed -and
    -not [bool]$r23d52Extension.renormalization_executed -and
    -not [bool]$r23d52Extension.checkout_filter_migration_executed -and
    $r23d52RequiredRules.Count -eq 6 -and
    $r23d52MissingDiffRules.Count -eq 0 -and
    $r23d52MissingLiveRules.Count -eq 0 -and
    -not $r23d52Diff.Contains("+* text=auto") -and
    -not $r23d52Diff.Contains("+* -text")
) "R23D52 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d53Extension.declared_from_parent_commit -ceq
        "d0603d0f46540ca36a4027bfac33cc66f112dc40" -and
    [string]$r23d53Extension.source_rule_commit -ceq
        "64a84efb648cd505c6718e235f30bb9db5c1ca1f" -and
    [string]$r23d53Extension.scope -ceq
        "prospective_r23d53_warmup_preserving_origin_source_family_only" -and
    [int]$r23d53Extension.added_rule_count -eq 4 -and
    -not [bool]$r23d53Extension.ambient_rule_changed -and
    -not [bool]$r23d53Extension.historical_path_rule_changed -and
    -not [bool]$r23d53Extension.renormalization_executed -and
    -not [bool]$r23d53Extension.checkout_filter_migration_executed -and
    [string]$r23d53Extension.first_scoped_qualification_disposition -ceq
        "failed_closed_at_cak1_evidence_provenance_before_physics_because_this_extension_was_not_yet_declared" -and
    $r23d53RequiredRules.Count -eq 4 -and
    $r23d53MissingDiffRules.Count -eq 0 -and
    $r23d53MissingLiveRules.Count -eq 0 -and
    -not $r23d53Diff.Contains("+* text=auto") -and
    -not $r23d53Diff.Contains("+* -text")
) "R23D53 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d54Extension.declared_from_parent_commit -ceq
        "3046e53a1146bd1604c80f110f90ea1afa5e198b" -and
    [string]$r23d54Extension.scope -ceq
        "prospective_r23d54_godot_actuator_phase_characterization_source_family_only" -and
    [int]$r23d54Extension.added_rule_count -eq 4 -and
    -not [bool]$r23d54Extension.ambient_rule_changed -and
    -not [bool]$r23d54Extension.historical_path_rule_changed -and
    -not [bool]$r23d54Extension.renormalization_executed -and
    -not [bool]$r23d54Extension.checkout_filter_migration_executed -and
    [int]$r23d54Extension.physical_world_count -eq 0 -and
    -not [bool]$r23d54Extension.physical_acceptance_authority -and
    $r23d54RequiredRules.Count -eq 4 -and
    $r23d54MissingDiffRules.Count -eq 0 -and
    $r23d54MissingLiveRules.Count -eq 0 -and
    -not $r23d54Diff.Contains("+* text=auto") -and
    -not $r23d54Diff.Contains("+* -text")
) "R23D54 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d55Extension.declared_from_parent_commit -ceq
        "1aceffccffa1838f01ec0f5463b7157d7c430232" -and
    [string]$r23d55Extension.scope -ceq
        "prospective_r23d55_zero_world_live_fixture_actuator_cap_conformance_source_family_only" -and
    [int]$r23d55Extension.added_rule_count -eq 4 -and
    -not [bool]$r23d55Extension.ambient_rule_changed -and
    -not [bool]$r23d55Extension.historical_path_rule_changed -and
    [int]$r23d55Extension.historical_tracked_file_renormalization_count -eq 0 -and
    [int]$r23d55Extension.new_uncommitted_source_lf_normalization_count -eq 2 -and
    -not [bool]$r23d55Extension.renormalization_executed -and
    -not [bool]$r23d55Extension.checkout_filter_migration_executed -and
    [string]$r23d55Extension.first_provenance_gate_disposition -ceq
        "failed_closed_after_inventory_verification_before_any_physics_due_to_undeclared_r23d55_non_migration_rule_extension" -and
    [int]$r23d55Extension.physical_world_count -eq 0 -and
    -not [bool]$r23d55Extension.physical_acceptance_authority -and
    $r23d55RequiredRules.Count -eq 4 -and
    $r23d55MissingDiffRules.Count -eq 0 -and
    $r23d55MissingLiveRules.Count -eq 0 -and
    -not $r23d55Diff.Contains("+* text=auto") -and
    -not $r23d55Diff.Contains("+* -text")
) "R23D55 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d56Extension.declared_from_parent_commit -ceq
        "169671734bd9d9fa7cdb837262aa6d5a0d911c6c" -and
    [string]$r23d56Extension.scope -ceq
        "prospective_r23d56_post_r23d55_valid_route_actuator_phase_characterization_source_family_only" -and
    [int]$r23d56Extension.added_rule_count -eq 4 -and
    -not [bool]$r23d56Extension.ambient_rule_changed -and
    -not [bool]$r23d56Extension.historical_path_rule_changed -and
    [int]$r23d56Extension.historical_tracked_file_renormalization_count -eq 0 -and
    [int]$r23d56Extension.new_uncommitted_source_lf_normalization_count -eq 0 -and
    -not [bool]$r23d56Extension.renormalization_executed -and
    -not [bool]$r23d56Extension.checkout_filter_migration_executed -and
    [bool]$r23d56Extension.initial_provenance_failure_observed -and
    [string]$r23d56Extension.initial_provenance_failure_message -ceq
        "Checkout-filter migration moved without its distinct provenance boundary" -and
    [string]$r23d56Extension.initial_provenance_failure_boundary -ceq
        "current_gitattributes_raw_sha256_and_git_blob_oid_not_rebound_with_declared_r23d56_rules" -and
    [string]$r23d56Extension.first_provenance_gate_disposition -ceq
        "failed_closed_at_checkout_filter_current_identity_before_any_r23d56_source_or_physics" -and
    [int]$r23d56Extension.physical_world_count -eq 0 -and
    -not [bool]$r23d56Extension.physical_acceptance_authority -and
    $r23d56RequiredRules.Count -eq 4 -and
    $r23d56MissingDiffRules.Count -eq 0 -and
    $r23d56MissingLiveRules.Count -eq 0 -and
    -not $r23d56Diff.Contains("+* text=auto") -and
    -not $r23d56Diff.Contains("+* -text")
) "R23D56 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d57Extension.declared_from_parent_commit -ceq
        "5008c44a418eed3f3e1a56d8ef005394d84b68e1" -and
    [string]$r23d57Extension.scope -ceq
        "prospective_r23d57_full_precision_trace_transport_and_physical_source_family_only" -and
    [int]$r23d57Extension.added_rule_count -eq 4 -and
    -not [bool]$r23d57Extension.ambient_rule_changed -and
    -not [bool]$r23d57Extension.historical_path_rule_changed -and
    [int]$r23d57Extension.historical_tracked_file_renormalization_count -eq 0 -and
    [int]$r23d57Extension.new_uncommitted_source_lf_normalization_count -eq 0 -and
    -not [bool]$r23d57Extension.renormalization_executed -and
    -not [bool]$r23d57Extension.checkout_filter_migration_executed -and
    -not [bool]$r23d57Extension.initial_provenance_failure_observed -and
    [string]$r23d57Extension.declaration_mode -ceq
        "proactive_before_first_r23d57_source_file_creation" -and
    [int]$r23d57Extension.physical_world_count -eq 0 -and
    -not [bool]$r23d57Extension.physical_acceptance_authority -and
    $r23d57RequiredRules.Count -eq 4 -and
    $r23d57MissingDiffRules.Count -eq 0 -and
    $r23d57MissingLiveRules.Count -eq 0 -and
    -not $r23d57Diff.Contains("+* text=auto") -and
    -not $r23d57Diff.Contains("+* -text")
) "R23D57 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d57WorkbenchAuditExtension.declared_from_parent_commit -ceq
        "7fbc2bf7e6194a8f7f98e42a157d9451bca3d53d" -and
    [string]$r23d57WorkbenchAuditExtension.source_rule_commit -ceq
        "fb460ab6828e6e38342c305faf58c80eb3744b08" -and
    [string]$r23d57WorkbenchAuditExtension.scope -ceq
        "prospective_r23d57_campaign_workbench_lineage_audit_only" -and
    [string]$r23d57WorkbenchAuditExtension.path_rule -ceq
        "tests/test_locomotion_experiment_workbench.ps1 text eol=lf" -and
    [int]$r23d57WorkbenchAuditExtension.added_rule_count -eq 1 -and
    -not [bool]$r23d57WorkbenchAuditExtension.ambient_rule_changed -and
    [bool]$r23d57WorkbenchAuditExtension.existing_shared_audit_checkout_rule_added -and
    -not [bool]$r23d57WorkbenchAuditExtension.historical_campaign_source_identity_changed -and
    [int]$r23d57WorkbenchAuditExtension.historical_tracked_file_renormalization_count -eq 0 -and
    -not [bool]$r23d57WorkbenchAuditExtension.renormalization_executed -and
    -not [bool]$r23d57WorkbenchAuditExtension.checkout_filter_migration_executed -and
    [bool]$r23d57WorkbenchAuditExtension.first_clean_pushed_preflight_failure_observed -and
    [string]$r23d57WorkbenchAuditExtension.failure_stage -ceq
        "r23d57_lineage_bounded_checkout_provenance" -and
    [string]$r23d57WorkbenchAuditExtension.failure_message -ceq
        "QSDK-R23D57 LINEAGE: bounded checkout provenance changed" -and
    [string]$r23d57WorkbenchAuditExtension.failure_disposition -ceq
        "failed_closed_before_worker_role_evaluator_role_model_or_world" -and
    [bool]$r23d57WorkbenchAuditExtension.repair_qualification_pending -and
    [int]$r23d57WorkbenchAuditExtension.physical_world_count -eq 0 -and
    -not [bool]$r23d57WorkbenchAuditExtension.physical_acceptance_authority -and
    $r23d57WorkbenchAuditRequiredRules.Count -eq 1 -and
    $r23d57WorkbenchAuditMissingDiffRules.Count -eq 0 -and
    $r23d57WorkbenchAuditMissingLiveRules.Count -eq 0 -and
    -not $r23d57WorkbenchAuditDiff.Contains("+* text=auto") -and
    -not $r23d57WorkbenchAuditDiff.Contains("+* -text")
) "R23D57 Workbench-audit bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d58Extension.declared_from_parent_commit -ceq
        "fe1836f12c6233468f4db94017de84645c14bca9" -and
    [string]$r23d58Extension.scope -ceq
        "prospective_r23d58_terminal_trace_transport_and_cap_source_factorial_zero_world_source_family_only" -and
    [int]$r23d58Extension.added_rule_count -eq 5 -and
    -not [bool]$r23d58Extension.ambient_rule_changed -and
    -not [bool]$r23d58Extension.historical_path_rule_changed -and
    [int]$r23d58Extension.historical_tracked_file_renormalization_count -eq 0 -and
    [int]$r23d58Extension.new_uncommitted_source_lf_normalization_count -eq 0 -and
    -not [bool]$r23d58Extension.renormalization_executed -and
    -not [bool]$r23d58Extension.checkout_filter_migration_executed -and
    [string]$r23d58Extension.declaration_mode -ceq
        "prospective_before_any_r23d58_physical_campaign" -and
    -not [bool]$r23d58Extension.closure_inventory_scope_match -and
    [int]$r23d58Extension.closure_inventory_audit_count_delta -eq 0 -and
    [int]$r23d58Extension.physical_world_count -eq 0 -and
    -not [bool]$r23d58Extension.physical_acceptance_authority -and
    $r23d58RequiredRules.Count -eq 5 -and
    $r23d58MissingDiffRules.Count -eq 0 -and
    $r23d58MissingLiveRules.Count -eq 0 -and
    -not $r23d58Diff.Contains("+* text=auto") -and
    -not $r23d58Diff.Contains("+* -text")
) "R23D58 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d59Extension.declared_from_parent_commit -ceq
        "fb24fe080387b919ff5ba3ecbb22a6bca0220ff2" -and
    [string]$r23d59Extension.source_rule_commit -ceq
        "63c927a92173aee953effd5a9c26dc5155a68fac" -and
    [string]$r23d59Extension.scope -ceq
        "prospective_r23d59_finite_knee_source_decision_and_reserved_r23d60_held_out_source_family_only" -and
    [int]$r23d59Extension.added_rule_count -eq 4 -and
    -not [bool]$r23d59Extension.ambient_rule_changed -and
    -not [bool]$r23d59Extension.historical_path_rule_changed -and
    [int]$r23d59Extension.historical_tracked_file_renormalization_count -eq 0 -and
    [int]$r23d59Extension.new_uncommitted_source_lf_normalization_count -eq 0 -and
    -not [bool]$r23d59Extension.renormalization_executed -and
    -not [bool]$r23d59Extension.checkout_filter_migration_executed -and
    [string]$r23d59Extension.declaration_mode -ceq
        "prospective_before_any_r23d59_or_r23d60_physical_campaign" -and
    [bool]$r23d59Extension.initial_provenance_failure_observed -and
    [string]$r23d59Extension.initial_provenance_failure_message -ceq
        "Checkout-filter migration moved without its distinct provenance boundary" -and
    [string]$r23d59Extension.initial_provenance_failure_boundary -ceq
        "current_gitattributes_raw_sha256_and_git_blob_oid_not_rebound_with_declared_r23d59_rules" -and
    [string]$r23d59Extension.first_provenance_gate_disposition -ceq
        "failed_closed_before_clean_pushed_qualification_model_or_world" -and
    [bool]$r23d59Extension.clean_pushed_requalification_required -and
    [int]$r23d59Extension.threshold_selector_evaluator_or_result_change_count -eq 0 -and
    [int]$r23d59Extension.physical_world_count -eq 0 -and
    -not [bool]$r23d59Extension.physical_acceptance_authority -and
    $r23d59RequiredRules.Count -eq 4 -and
    $r23d59MissingDiffRules.Count -eq 0 -and
    $r23d59MissingLiveRules.Count -eq 0 -and
    -not $r23d59Diff.Contains("+* text=auto") -and
    -not $r23d59Diff.Contains("+* -text")
) "R23D59 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d60Extension.declared_from_parent_commit -ceq
        "b06fdaf0d460c0667d328b66c1b26fb28714130a" -and
    [string]$r23d60Extension.scope -ceq
        "prospective_r23d60_exact_held_out_godot_jolt_turning_validation_source_family_only" -and
    [int]$r23d60Extension.added_rule_count -eq 4 -and
    -not [bool]$r23d60Extension.ambient_rule_changed -and
    -not [bool]$r23d60Extension.historical_path_rule_changed -and
    [int]$r23d60Extension.historical_tracked_file_renormalization_count -eq 0 -and
    [int]$r23d60Extension.new_uncommitted_source_lf_normalization_count -eq 0 -and
    -not [bool]$r23d60Extension.renormalization_executed -and
    -not [bool]$r23d60Extension.checkout_filter_migration_executed -and
    [string]$r23d60Extension.declaration_mode -ceq
        "prospective_before_any_r23d60_implementation_qualification_or_physical_world" -and
    [int]$r23d60Extension.threshold_selector_evaluator_or_result_change_count -eq 0 -and
    [int]$r23d60Extension.physical_world_count -eq 0 -and
    -not [bool]$r23d60Extension.physical_acceptance_authority -and
    $r23d60RequiredRules.Count -eq 4 -and
    $r23d60MissingDiffRules.Count -eq 0 -and
    $r23d60MissingLiveRules.Count -eq 0 -and
    -not $r23d60Diff.Contains("+* text=auto") -and
    -not $r23d60Diff.Contains("+* -text")
) "R23D60 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d61Extension.declared_from_closure_commit -ceq
        "0319dcc39a3454029025d5995168af5f5225ccb0" -and
    [string]$r23d61Extension.scope -ceq
        "postclosure_r23d61_nonphysical_publication_source_family_stabilization_only" -and
    [int]$r23d61Extension.added_rule_count -eq 4 -and
    [int]$r23d61Extension.covered_tracked_path_count -eq 6 -and
    [int]$r23d61Extension.pre_rule_worktree_git_blob_equality_count -eq 6 -and
    -not [bool]$r23d61Extension.ambient_rule_changed -and
    -not [bool]$r23d61Extension.historical_path_rule_changed -and
    [int]$r23d61Extension.historical_tracked_file_renormalization_count -eq 0 -and
    [int]$r23d61Extension.existing_r23d61_file_content_change_count -eq 0 -and
    -not [bool]$r23d61Extension.renormalization_executed -and
    -not [bool]$r23d61Extension.checkout_filter_migration_executed -and
    [string]$r23d61Extension.declaration_mode -ceq
        "post_publication_closure_provenance_repair_before_prone_design" -and
    [bool]$r23d61Extension.initial_clean_pushed_full_cold_failure_observed -and
    [string]$r23d61Extension.initial_failure_message -ceq
        "Closure evidence-mode executable inventory verification failed" -and
    [string]$r23d61Extension.initial_failure_source_commit -ceq
        "0319dcc39a3454029025d5995168af5f5225ccb0" -and
    [int]$r23d61Extension.initial_failure_world_count -eq 0 -and
    [int]$r23d61Extension.threshold_selector_evaluator_or_result_change_count -eq 0 -and
    [int]$r23d61Extension.physical_world_count -eq 0 -and
    -not [bool]$r23d61Extension.physical_acceptance_authority -and
    $r23d61RequiredRules.Count -eq 4 -and
    $r23d61MissingDiffRules.Count -eq 0 -and
    $r23d61MissingLiveRules.Count -eq 0 -and
    -not $r23d61Diff.Contains("+* text=auto") -and
    -not $r23d61Diff.Contains("+* -text")
) "R23D61 postclosure checkout-rule extension changed"

Assert-Exact (
    [string]$r23d62Extension.declared_from_parent_commit -ceq
        "fa4001578e244deff25cce4dd32d7a0c9e5d3418" -and
    [string]$r23d62Extension.scope -ceq
        "prospective_r23d62_selected_profile_matched_three_engine_turning_validation_source_family_only" -and
    [int]$r23d62Extension.added_rule_count -eq 6 -and
    -not [bool]$r23d62Extension.ambient_rule_changed -and
    -not [bool]$r23d62Extension.historical_path_rule_changed -and
    [int]$r23d62Extension.historical_tracked_file_renormalization_count -eq 0 -and
    [int]$r23d62Extension.new_uncommitted_source_lf_normalization_count -eq 0 -and
    -not [bool]$r23d62Extension.renormalization_executed -and
    -not [bool]$r23d62Extension.checkout_filter_migration_executed -and
    [string]$r23d62Extension.declaration_mode -ceq
        "prospective_before_any_r23d62_implementation_qualification_or_physical_world" -and
    [int]$r23d62Extension.threshold_selector_evaluator_or_result_change_count -eq 0 -and
    [int]$r23d62Extension.physical_world_count -eq 0 -and
    -not [bool]$r23d62Extension.physical_acceptance_authority -and
    $r23d62RequiredRules.Count -eq 6 -and
    $r23d62MissingDiffRules.Count -eq 0 -and
    $r23d62MissingLiveRules.Count -eq 0 -and
    -not $r23d62Diff.Contains("+* text=auto") -and
    -not $r23d62Diff.Contains("+* -text")
) "R23D62 bounded checkout-rule extension changed"

Assert-Exact (
    [string]$r23d62RapierRouteExtension.declared_from_parent_commit -ceq
        "df12c9a7a54b0ea90abc2fa5422599c105a8b8ce" -and
    [string]$r23d62RapierRouteExtension.scope -ceq
        "r23d62_rapier_public_profile_route_and_shared_mapping_checkout_stabilization_only" -and
    [int]$r23d62RapierRouteExtension.added_rule_count -eq 2 -and
    [int]$r23d62RapierRouteExtension.existing_shared_source_path_count -eq 1 -and
    [int]$r23d62RapierRouteExtension.new_route_source_family_rule_count -eq 1 -and
    [int]$r23d62RapierRouteExtension.existing_rule_line_modified_count -eq 0 -and
    -not [bool]$r23d62RapierRouteExtension.ambient_rule_changed -and
    -not [bool]$r23d62RapierRouteExtension.historical_path_rule_changed -and
    [int]$r23d62RapierRouteExtension.historical_tracked_file_renormalization_count -eq 0 -and
    [int]$r23d62RapierRouteExtension.existing_shared_source_checkout_byte_change_count -eq 0 -and
    -not [bool]$r23d62RapierRouteExtension.renormalization_executed -and
    -not [bool]$r23d62RapierRouteExtension.checkout_filter_migration_executed -and
    [string]$r23d62RapierRouteExtension.declaration_mode -ceq
        "post_implementation_precommit_provenance_repair_before_rapier_worker_or_physical_world" -and
    [int]$r23d62RapierRouteExtension.threshold_selector_evaluator_or_result_change_count -eq 0 -and
    [int]$r23d62RapierRouteExtension.model_construction_count -eq 0 -and
    [int]$r23d62RapierRouteExtension.physical_world_count -eq 0 -and
    -not [bool]$r23d62RapierRouteExtension.physical_acceptance_authority -and
    -not [bool]$r23d62RapierRouteExtension.release_authority -and
    $r23d62RapierRouteRequiredRules.Count -eq 2 -and
    $r23d62RapierRouteMissingDiffRules.Count -eq 0 -and
    $r23d62RapierRouteMissingLiveRules.Count -eq 0 -and
    -not $r23d62RapierRouteDiff.Contains("+* text=auto") -and
    -not $r23d62RapierRouteDiff.Contains("+* -text")
) "R23D62 Rapier-route checkout-stability extension changed"

Assert-Exact (
    [string]$r24d1Extension.declared_from_parent_commit -ceq
        "a56e4f4b966de733b16d418b814151e895844a8a" -and
    [string]$r24d1Extension.scope -ceq
        "prospective_qsdk_r24d1_canonical_prone_to_standing_zero_world_design_source_family_only" -and
    [int]$r24d1Extension.added_rule_count -eq 3 -and
    [int]$r24d1Extension.covered_new_path_count -eq 4 -and
    [int]$r24d1Extension.pre_rule_worktree_git_blob_equality_count -eq 4 -and
    -not [bool]$r24d1Extension.ambient_rule_changed -and
    -not [bool]$r24d1Extension.historical_path_rule_changed -and
    [int]$r24d1Extension.historical_tracked_file_renormalization_count -eq 0 -and
    [int]$r24d1Extension.new_uncommitted_source_lf_normalization_count -eq 0 -and
    -not [bool]$r24d1Extension.renormalization_executed -and
    -not [bool]$r24d1Extension.checkout_filter_migration_executed -and
    [string]$r24d1Extension.declaration_mode -ceq
        "prospective_before_any_r24_recovery_implementation_controller_or_physical_world" -and
    [int]$r24d1Extension.threshold_selector_evaluator_or_result_change_count -eq 0 -and
    [int]$r24d1Extension.physical_threshold_value_count -eq 0 -and
    [int]$r24d1Extension.physical_cohort_identity_count -eq 0 -and
    [int]$r24d1Extension.physical_world_count -eq 0 -and
    -not [bool]$r24d1Extension.physical_acceptance_authority -and
    -not [bool]$r24d1Extension.release_authority -and
    $r24d1RequiredRules.Count -eq 3 -and
    $r24d1MissingDiffRules.Count -eq 0 -and
    $r24d1MissingLiveRules.Count -eq 0 -and
    -not $r24d1Diff.Contains("+* text=auto") -and
    -not $r24d1Diff.Contains("+* -text")
) "R24D1 prospective checkout-rule extension changed"

Assert-Exact (
    [string]$r24d2Extension.declared_from_parent_commit -ceq
        "07aee8b9113026fdf4894ce6b3235a9bbaef7434" -and
    [string]$r24d2Extension.scope -ceq
        "prospective_qsdk_r24d2_portable_recovery_semantics_and_native_capability_mapping_source_families_only" -and
    [int]$r24d2Extension.added_rule_count -eq 9 -and
    [int]$r24d2Extension.planned_new_path_count -eq 10 -and
    [int]$r24d2Extension.existing_new_path_count_at_declaration -eq 0 -and
    [int]$r24d2Extension.pre_rule_worktree_git_blob_equality_count -eq 0 -and
    -not [bool]$r24d2Extension.ambient_rule_changed -and
    -not [bool]$r24d2Extension.historical_path_rule_changed -and
    [int]$r24d2Extension.historical_tracked_file_renormalization_count -eq 0 -and
    [int]$r24d2Extension.new_uncommitted_source_lf_normalization_count -eq 0 -and
    -not [bool]$r24d2Extension.renormalization_executed -and
    -not [bool]$r24d2Extension.checkout_filter_migration_executed -and
    [string]$r24d2Extension.declaration_mode -ceq
        "prospective_before_any_r24d2_source_creation_controller_tuning_or_physical_world" -and
    [int]$r24d2Extension.threshold_selector_evaluator_or_physical_result_change_count -eq 0 -and
    [int]$r24d2Extension.physical_threshold_value_count -eq 0 -and
    [int]$r24d2Extension.physical_cohort_identity_count -eq 0 -and
    [int]$r24d2Extension.physical_world_count -eq 0 -and
    -not [bool]$r24d2Extension.physical_acceptance_authority -and
    -not [bool]$r24d2Extension.release_authority -and
    $r24d2RequiredRules.Count -eq 9 -and
    $r24d2MissingDiffRules.Count -eq 0 -and
    $r24d2MissingLiveRules.Count -eq 0 -and
    -not $r24d2Diff.Contains("+* text=auto") -and
    -not $r24d2Diff.Contains("+* -text")
) "R24D2 prospective checkout-rule extension changed"

Assert-Exact (
    [string]$r24d2IntegrationExtension.declared_from_parent_commit -ceq
        "07aee8b9113026fdf4894ce6b3235a9bbaef7434" -and
    [string]$r24d2IntegrationExtension.declared_after_first_extension_raw_sha256 -ceq
        "e3c4c448524a689db26ece163cac3f694bdf75013216fba353d6706675d5f6f1" -and
    [string]$r24d2IntegrationExtension.declared_after_first_extension_git_blob -ceq
        "a950fa2ed794c0a1ecf5cd533ae55484e3c86860" -and
    [string]$r24d2IntegrationExtension.scope -ceq
        "r24d2_modified_existing_integration_surfaces_checkout_stability_before_validation_manifest_and_first_commit" -and
    [int]$r24d2IntegrationExtension.added_rule_count -eq 8 -and
    [int]$r24d2IntegrationExtension.targeted_existing_modified_path_count -eq 8 -and
    [int]$r24d2IntegrationExtension.targeted_unmodified_historical_path_count -eq 0 -and
    [bool]$r24d2IntegrationExtension.rules_added_before_first_r24d2_commit -and
    [string]$r24d2IntegrationExtension.gitattributes_raw_sha256_after_second_extension -ceq
        "51300f85e7fc0810ddf7bb917eb4d25c586350d1d638b77f1d7aee5915e54d27" -and
    [string]$r24d2IntegrationExtension.gitattributes_git_blob_after_second_extension -ceq
        "e5a9f5ce8ebdf16944888933a8bb86a121f45da3" -and
    -not [bool]$r24d2IntegrationExtension.git_add_renormalize_executed -and
    [int]$r24d2IntegrationExtension.historical_tracked_file_renormalization_count -eq 0 -and
    -not [bool]$r24d2IntegrationExtension.checkout_filter_migration_executed -and
    [string]$r24d2IntegrationExtension.declaration_mode -ceq
        "after_r24d2_source_creation_before_validation_manifest_and_first_commit" -and
    [int]$r24d2IntegrationExtension.threshold_selector_evaluator_or_physical_result_change_count -eq 0 -and
    [int]$r24d2IntegrationExtension.physical_threshold_value_count -eq 0 -and
    [int]$r24d2IntegrationExtension.physical_cohort_identity_count -eq 0 -and
    [int]$r24d2IntegrationExtension.physical_world_count -eq 0 -and
    -not [bool]$r24d2IntegrationExtension.physical_acceptance_authority -and
    -not [bool]$r24d2IntegrationExtension.release_authority -and
    $r24d2IntegrationRequiredRules.Count -eq 8 -and
    $r24d2IntegrationMissingDiffRules.Count -eq 0 -and
    $r24d2IntegrationMissingLiveRules.Count -eq 0 -and
    -not $r24d2IntegrationDiff.Contains("+* text=auto") -and
    -not $r24d2IntegrationDiff.Contains("+* -text")
) "R24D2 integration checkout-stability extension changed"

Assert-Exact (
    [string]$r24d3Extension.declared_from_parent_commit -ceq
        "d7995aeac268f22142edd82564c79b5d7b56c881" -and
    [string]$r24d3Extension.scope -ceq
        "qsdk_r24d3_pinned_godot_jolt_motor_telemetry_source_and_zero_world_qualification_families_only" -and
    [int]$r24d3Extension.added_rule_count -eq 6 -and
    [int]$r24d3Extension.planned_new_path_count -eq 7 -and
    [int]$r24d3Extension.existing_new_path_count_at_declaration -eq 5 -and
    [bool]$r24d3Extension.rules_added_before_first_r24d3_commit -and
    -not [bool]$r24d3Extension.ambient_rule_changed -and
    -not [bool]$r24d3Extension.historical_path_rule_changed -and
    [int]$r24d3Extension.historical_tracked_file_renormalization_count -eq 0 -and
    [int]$r24d3Extension.new_uncommitted_source_lf_normalization_count -eq 0 -and
    -not [bool]$r24d3Extension.renormalization_executed -and
    -not [bool]$r24d3Extension.checkout_filter_migration_executed -and
    [string]$r24d3Extension.declaration_mode -ceq
        "post_initial_source_implementation_before_validation_manifest_first_commit_or_physical_world" -and
    [int]$r24d3Extension.threshold_selector_evaluator_or_physical_result_change_count -eq 0 -and
    [int]$r24d3Extension.physical_threshold_value_count -eq 0 -and
    [int]$r24d3Extension.physical_cohort_identity_count -eq 0 -and
    [int]$r24d3Extension.physical_world_count -eq 0 -and
    -not [bool]$r24d3Extension.physical_acceptance_authority -and
    -not [bool]$r24d3Extension.release_authority -and
    $r24d3RequiredRules.Count -eq 6 -and
    $r24d3MissingDiffRules.Count -eq 0 -and
    $r24d3MissingLiveRules.Count -eq 0 -and
    -not $r24d3Diff.Contains("+* text=auto") -and
    -not $r24d3Diff.Contains("+* -text")
) "R24D3 checkout-rule extension changed"

Assert-Exact (
    [string]$r24d4Extension.declared_from_parent_commit -ceq
        "ebf60df39f055d721b7868efa44feb34e3a941a6" -and
    [string]$r24d4Extension.scope -ceq
        "qsdk_r24d4_one_hinge_godot_jolt_telemetry_characterization_source_oracle_worker_and_supervisor_families_only" -and
    [int]$r24d4Extension.added_rule_count -eq 5 -and
    [int]$r24d4Extension.planned_new_path_count -eq 8 -and
    [int]$r24d4Extension.existing_new_path_count_at_declaration -eq 8 -and
    [int]$r24d4Extension.pre_rule_worktree_git_blob_equality_count -eq 8 -and
    [int]$r24d4Extension.pre_rule_cr_byte_count -eq 0 -and
    [string]$r24d4Extension.pre_rule_gitattributes_raw_sha256 -ceq
        "1bd2bf17bdc9a9ddb77cd61f6be4c4fd11fc9dc348e5af0426e6d42c4e4ba75d" -and
    [string]$r24d4Extension.pre_rule_gitattributes_git_blob -ceq
        "890d6c0bbb7b392293c6c2f9f330141b3f5c137f" -and
    [int]$r24d4Extension.pre_rule_gitattributes_byte_length -eq 56519 -and
    [bool]$r24d4Extension.rules_added_before_first_r24d4_commit -and
    -not [bool]$r24d4Extension.ambient_rule_changed -and
    -not [bool]$r24d4Extension.historical_path_rule_changed -and
    [int]$r24d4Extension.historical_tracked_file_renormalization_count -eq 0 -and
    [int]$r24d4Extension.new_uncommitted_source_lf_normalization_count -eq 0 -and
    -not [bool]$r24d4Extension.renormalization_executed -and
    -not [bool]$r24d4Extension.checkout_filter_migration_executed -and
    [string]$r24d4Extension.declaration_mode -ceq
        "post_initial_source_implementation_before_validation_manifest_first_commit_or_physical_world" -and
    [int]$r24d4Extension.threshold_selector_evaluator_or_physical_result_change_count -eq 0 -and
    [int]$r24d4Extension.physical_threshold_value_count -eq 0 -and
    [int]$r24d4Extension.physical_cohort_identity_count -eq 0 -and
    [int]$r24d4Extension.physical_world_count -eq 0 -and
    -not [bool]$r24d4Extension.physical_acceptance_authority -and
    -not [bool]$r24d4Extension.release_authority -and
    $r24d4RequiredRules.Count -eq 5 -and
    $r24d4MissingDiffRules.Count -eq 0 -and
    $r24d4MissingLiveRules.Count -eq 0 -and
    $r24d4ExistingNewPaths.Count -eq 8 -and
    $r24d4BlobFaithfulPathCount -eq 8 -and
    $r24d4CrByteCount -eq 0 -and
    -not $r24d4Diff.Contains("+* text=auto") -and
    -not $r24d4Diff.Contains("+* -text")
) "R24D4 checkout-rule extension changed"

Assert-Exact (
    [string]$r24d4ClosureExtension.declared_from_source_commit -ceq
        "6e24a729bac03e02cf247583f5e321040b4b011a" -and
    [string]$r24d4ClosureExtension.scope -ceq
        "post_attempt_qsdk_r24d4_zero_world_failure_closure_and_executable_audit_only" -and
    [int]$r24d4ClosureExtension.added_rule_count -eq 0 -and
    [int]$r24d4ClosureExtension.existing_r24d4_wildcard_rule_count_reused -eq 2 -and
    [int]$r24d4ClosureExtension.new_closure_path_count -eq 2 -and
    [int]$r24d4ClosureExtension.closure_path_checkout_git_blob_equality_count -eq 2 -and
    [int]$r24d4ClosureExtension.closure_path_cr_byte_count -eq 0 -and
    -not [bool]$r24d4ClosureExtension.executed_r24d4_source_rule_changed -and
    -not [bool]$r24d4ClosureExtension.executed_r24d4_source_evaluator_or_worker_changed -and
    -not [bool]$r24d4ClosureExtension.historical_path_rule_changed -and
    -not [bool]$r24d4ClosureExtension.renormalization_executed -and
    -not [bool]$r24d4ClosureExtension.checkout_filter_migration_executed -and
    [string]$r24d4ClosureExtension.declaration_mode -ceq
        "post_zero_world_failure_before_closure_commit_without_reopening_physics" -and
    [int]$r24d4ClosureExtension.threshold_selector_evaluator_or_result_interpretation_change_count -eq 0 -and
    [int]$r24d4ClosureExtension.world_attempt_count -eq 0 -and
    [int]$r24d4ClosureExtension.world_build_count -eq 0 -and
    [int]$r24d4ClosureExtension.solver_step_count -eq 0 -and
    [bool]$r24d4ClosureExtension.same_source_physical_open_forbidden -and
    -not [bool]$r24d4ClosureExtension.physical_acceptance_authority -and
    -not [bool]$r24d4ClosureExtension.release_authority -and
    $r24d4ClosureReusedRules.Count -eq 2 -and
    $r24d4ClosureMissingLiveRules.Count -eq 0 -and
    $r24d4ClosurePaths.Count -eq 2 -and
    $r24d4ClosureBlobFaithfulPathCount -eq 2 -and
    $r24d4ClosureCrByteCount -eq 0
) "R24D4 zero-world failure closure checkout boundary changed"

Assert-Exact (
    [string]$r24d5Extension.declared_from_parent_commit -ceq
        "6e24a729bac03e02cf247583f5e321040b4b011a" -and
    [string]$r24d5Extension.scope -ceq
        "qsdk_r24d5_axis_consistent_one_hinge_godot_jolt_telemetry_successor_source_oracle_worker_supervisor_and_diagnostics_families_only" -and
    [int]$r24d5Extension.added_rule_count -eq 5 -and
    [int]$r24d5Extension.planned_new_path_count -eq 9 -and
    [int]$r24d5Extension.existing_new_path_count_at_rule_declaration -eq 8 -and
    [int]$r24d5Extension.post_rule_diagnostics_path_count -eq 1 -and
    [int]$r24d5Extension.pre_rule_worktree_git_blob_equality_count -eq 8 -and
    [int]$r24d5Extension.pre_rule_cr_byte_count -eq 0 -and
    [string]$r24d5Extension.pre_rule_gitattributes_raw_sha256 -ceq
        "649db808082d90436ce76733b78d590559898f84e928f15fcbea8c98cb0216a4" -and
    [string]$r24d5Extension.pre_rule_gitattributes_git_blob -ceq
        "9ee806c38726747e32fdcbad8ad38a32a36d7280" -and
    [int]$r24d5Extension.pre_rule_gitattributes_byte_length -eq 56906 -and
    [bool]$r24d5Extension.rules_added_before_first_r24d5_commit -and
    -not [bool]$r24d5Extension.ambient_rule_changed -and
    -not [bool]$r24d5Extension.historical_path_rule_changed -and
    [int]$r24d5Extension.historical_tracked_file_renormalization_count -eq 0 -and
    [int]$r24d5Extension.new_uncommitted_source_lf_normalization_count -eq 0 -and
    -not [bool]$r24d5Extension.renormalization_executed -and
    -not [bool]$r24d5Extension.checkout_filter_migration_executed -and
    [string]$r24d5Extension.declaration_mode -ceq
        "post_initial_successor_source_implementation_before_validation_manifest_first_commit_or_physical_world" -and
    [int]$r24d5Extension.threshold_selector_evaluator_or_physical_result_change_count -eq 0 -and
    [int]$r24d5Extension.physical_threshold_value_count -eq 0 -and
    [int]$r24d5Extension.physical_cohort_identity_count -eq 0 -and
    [int]$r24d5Extension.physical_world_count -eq 0 -and
    -not [bool]$r24d5Extension.physical_acceptance_authority -and
    -not [bool]$r24d5Extension.release_authority -and
    $r24d5RequiredRules.Count -eq 5 -and
    $r24d5MissingDiffRules.Count -eq 0 -and
    $r24d5MissingLiveRules.Count -eq 0 -and
    $r24d5ExistingNewPaths.Count -eq 9 -and
    $r24d5BlobFaithfulPathCount -eq 9 -and
    $r24d5CrByteCount -eq 0 -and
    -not $r24d5Diff.Contains("+* text=auto") -and
    -not $r24d5Diff.Contains("+* -text")
) "R24D5 checkout-rule extension changed"

Assert-Exact (
    [string]$r24d5ClosureExtension.declared_from_source_commit -ceq
        "fffb773b408b0cf8bb4a3ba78e773b62c3a0e52a" -and
    [string]$r24d5ClosureExtension.scope -ceq
        "post_attempt_qsdk_r24d5_physical_failure_closure_and_executable_audit_only" -and
    [int]$r24d5ClosureExtension.added_rule_count -eq 0 -and
    [int]$r24d5ClosureExtension.existing_r24d5_wildcard_rule_count_reused -eq 2 -and
    [int]$r24d5ClosureExtension.new_closure_path_count -eq 2 -and
    [int]$r24d5ClosureExtension.closure_path_checkout_git_blob_equality_count -eq 2 -and
    [int]$r24d5ClosureExtension.closure_path_cr_byte_count -eq 0 -and
    -not [bool]$r24d5ClosureExtension.executed_r24d5_source_rule_changed -and
    -not [bool]$r24d5ClosureExtension.executed_r24d5_source_evaluator_or_worker_changed -and
    -not [bool]$r24d5ClosureExtension.historical_path_rule_changed -and
    -not [bool]$r24d5ClosureExtension.renormalization_executed -and
    -not [bool]$r24d5ClosureExtension.checkout_filter_migration_executed -and
    [string]$r24d5ClosureExtension.declaration_mode -ceq
        "post_consumed_physical_failure_before_closure_commit_without_reopening_physics" -and
    [int]$r24d5ClosureExtension.threshold_selector_evaluator_or_result_interpretation_change_count -eq 0 -and
    [int]$r24d5ClosureExtension.physical_world_attempt_count -eq 1 -and
    [int]$r24d5ClosureExtension.world_build_count -eq 1 -and
    [int]$r24d5ClosureExtension.physics_step_count -eq 20 -and
    [int]$r24d5ClosureExtension.maintenance_process_physical_world_count -eq 0 -and
    [bool]$r24d5ClosureExtension.same_source_physical_open_forbidden -and
    -not [bool]$r24d5ClosureExtension.physical_acceptance_authority -and
    -not [bool]$r24d5ClosureExtension.release_authority -and
    $r24d5ClosureReusedRules.Count -eq 2 -and
    $r24d5ClosureMissingLiveRules.Count -eq 0 -and
    $r24d5ClosurePaths.Count -eq 2 -and
    $r24d5ClosureBlobFaithfulPathCount -eq 2 -and
    $r24d5ClosureCrByteCount -eq 0
) "R24D5 physical failure closure checkout boundary changed"

Assert-Exact (
    [string]$r24d6Extension.declared_from_parent_commit -ceq
        "f10492b795b35325c09ee25325d195d8db2357fb" -and
    [string]$r24d6Extension.scope -ceq
        "qsdk_r24d6_serialized_envelope_adequacy_successor_source_oracle_worker_supervisor_and_parser_diagnostics_families_only" -and
    [int]$r24d6Extension.added_rule_count -eq 5 -and
    [int]$r24d6Extension.planned_new_path_count -eq 9 -and
    [int]$r24d6Extension.source_path_count_at_contract_binding -eq 9 -and
    [int]$r24d6Extension.source_path_checkout_git_blob_equality_count -eq 9 -and
    [int]$r24d6Extension.source_path_cr_byte_count -eq 0 -and
    [string]$r24d6Extension.pre_rule_gitattributes_raw_sha256 -ceq
        "2bea8dc2ced827a7add46bdb7b93f9c7ab8841c6ddc59a3e81aa3e24ccd275f2" -and
    [string]$r24d6Extension.pre_rule_gitattributes_git_blob -ceq
        "3dc1d9dd06474903c1dec6484d4cb0225a3d753d" -and
    [int]$r24d6Extension.pre_rule_gitattributes_byte_length -eq 57222 -and
    [bool]$r24d6Extension.rules_added_before_first_r24d6_commit -and
    -not [bool]$r24d6Extension.ambient_rule_changed -and
    -not [bool]$r24d6Extension.historical_path_rule_changed -and
    [int]$r24d6Extension.historical_tracked_file_renormalization_count -eq 0 -and
    [int]$r24d6Extension.new_uncommitted_source_lf_normalization_count -eq 0 -and
    -not [bool]$r24d6Extension.renormalization_executed -and
    -not [bool]$r24d6Extension.checkout_filter_migration_executed -and
    [string]$r24d6Extension.declaration_mode -ceq
        "post_successor_source_implementation_and_precommit_parser_diagnostics_before_validation_manifest_first_commit_or_physical_world" -and
    [int]$r24d6Extension.precommit_parser_attempt_count -eq 2 -and
    [int]$r24d6Extension.precommit_parser_negative_count -eq 1 -and
    [int]$r24d6Extension.precommit_parser_pass_count -eq 1 -and
    [int]$r24d6Extension.official_zero_world_qualification_count -eq 0 -and
    [int]$r24d6Extension.threshold_selector_evaluator_or_physical_result_change_count -eq 0 -and
    [int]$r24d6Extension.predecessor_r24d5_source_or_result_change_count -eq 0 -and
    [int]$r24d6Extension.physical_threshold_value_count -eq 0 -and
    [int]$r24d6Extension.physical_cohort_identity_count -eq 0 -and
    [int]$r24d6Extension.physical_world_count -eq 0 -and
    -not [bool]$r24d6Extension.physical_acceptance_authority -and
    -not [bool]$r24d6Extension.release_authority -and
    $r24d6RequiredRules.Count -eq 5 -and
    $r24d6MissingDiffRules.Count -eq 0 -and
    $r24d6MissingLiveRules.Count -eq 0 -and
    $r24d6SourcePaths.Count -eq 9 -and
    $r24d6BlobFaithfulPathCount -eq 9 -and
    $r24d6CrByteCount -eq 0 -and
    -not $r24d6Diff.Contains("+* text=auto") -and
    -not $r24d6Diff.Contains("+* -text")
) "R24D6 checkout-rule extension changed"

Assert-Exact (
    [string]$r24d6ClosureExtension.declared_from_source_commit -ceq
        "55032839756cc8a9089a2a4eb4e06db71ab99ca4" -and
    [string]$r24d6ClosureExtension.scope -ceq
        "post_attempt_qsdk_r24d6_zero_world_failure_closure_and_executable_audit_only" -and
    [int]$r24d6ClosureExtension.added_rule_count -eq 0 -and
    [int]$r24d6ClosureExtension.existing_r24d6_wildcard_rule_count_reused -eq 2 -and
    [int]$r24d6ClosureExtension.new_closure_path_count -eq 2 -and
    [int]$r24d6ClosureExtension.closure_path_checkout_git_blob_equality_count -eq 2 -and
    [int]$r24d6ClosureExtension.closure_path_cr_byte_count -eq 0 -and
    -not [bool]$r24d6ClosureExtension.executed_r24d6_source_rule_changed -and
    -not [bool]$r24d6ClosureExtension.executed_r24d6_source_evaluator_or_worker_changed -and
    -not [bool]$r24d6ClosureExtension.historical_path_rule_changed -and
    -not [bool]$r24d6ClosureExtension.renormalization_executed -and
    -not [bool]$r24d6ClosureExtension.checkout_filter_migration_executed -and
    [string]$r24d6ClosureExtension.declaration_mode -ceq
        "post_valid_zero_world_negative_before_closure_commit_without_reopening_physics" -and
    [int]$r24d6ClosureExtension.threshold_selector_evaluator_or_result_interpretation_change_count -eq 0 -and
    [int]$r24d6ClosureExtension.physical_world_attempt_count -eq 0 -and
    [int]$r24d6ClosureExtension.world_build_count -eq 0 -and
    [int]$r24d6ClosureExtension.physics_step_count -eq 0 -and
    [int]$r24d6ClosureExtension.maintenance_process_physical_world_count -eq 0 -and
    [bool]$r24d6ClosureExtension.same_source_zero_world_rerun_forbidden -and
    [bool]$r24d6ClosureExtension.same_source_physical_open_forbidden -and
    -not [bool]$r24d6ClosureExtension.physical_acceptance_authority -and
    -not [bool]$r24d6ClosureExtension.release_authority -and
    $r24d6ClosureReusedRules.Count -eq 2 -and
    $r24d6ClosureMissingLiveRules.Count -eq 0 -and
    $r24d6ClosurePaths.Count -eq 2 -and
    $r24d6ClosureBlobFaithfulPathCount -eq 2 -and
    $r24d6ClosureCrByteCount -eq 0
) "R24D6 zero-world failure closure checkout boundary changed"

Assert-Exact (
    [string]$r24d7Extension.declared_from_parent_commit -ceq
        "1c4d05859cd7e19198179482c858dc8d7911575f" -and
    [string]$r24d7Extension.scope -ceq
        "qsdk_r24d7_integral_variant_schema_successor_source_oracle_worker_supervisor_and_parser_diagnostics_families_only" -and
    [int]$r24d7Extension.added_rule_count -eq 5 -and
    [int]$r24d7Extension.planned_new_path_count -eq 10 -and
    [int]$r24d7Extension.source_path_count_at_contract_binding -eq 10 -and
    [int]$r24d7Extension.source_path_checkout_git_blob_equality_count -eq 10 -and
    [int]$r24d7Extension.source_path_cr_byte_count -eq 0 -and
    [string]$r24d7Extension.pre_rule_gitattributes_raw_sha256 -ceq
        "41b2055af81be982dfa3e00993c5fce3e858ec17afea36a52a3793f54aaa3516" -and
    [string]$r24d7Extension.pre_rule_gitattributes_git_blob -ceq
        "4329ead144a0ad04b2faa7728bc8d6fa58743c3f" -and
    [int]$r24d7Extension.pre_rule_gitattributes_byte_length -eq 57629 -and
    [bool]$r24d7Extension.rules_added_before_first_r24d7_commit -and
    -not [bool]$r24d7Extension.ambient_rule_changed -and
    -not [bool]$r24d7Extension.historical_path_rule_changed -and
    [int]$r24d7Extension.historical_tracked_file_renormalization_count -eq 0 -and
    [int]$r24d7Extension.new_uncommitted_source_lf_normalization_count -eq 0 -and
    -not [bool]$r24d7Extension.renormalization_executed -and
    -not [bool]$r24d7Extension.checkout_filter_migration_executed -and
    [string]$r24d7Extension.declaration_mode -ceq
        "post_successor_source_implementation_and_single_passing_precommit_parser_diagnostic_before_first_commit_or_physical_world" -and
    [int]$r24d7Extension.precommit_parser_attempt_count -eq 1 -and
    [int]$r24d7Extension.precommit_parser_negative_count -eq 0 -and
    [int]$r24d7Extension.precommit_parser_pass_count -eq 1 -and
    [int]$r24d7Extension.official_zero_world_qualification_count -eq 0 -and
    [int]$r24d7Extension.declared_integral_variant_path_family_count -eq 21 -and
    [int]$r24d7Extension.declared_integral_variant_occurrence_count -eq 313 -and
    [int]$r24d7Extension.threshold_selector_evaluator_or_physical_result_change_count -eq 0 -and
    [int]$r24d7Extension.predecessor_r24d6_source_or_result_change_count -eq 0 -and
    [int]$r24d7Extension.physical_threshold_value_count -eq 0 -and
    [int]$r24d7Extension.physical_cohort_identity_count -eq 0 -and
    [int]$r24d7Extension.physical_world_count -eq 0 -and
    -not [bool]$r24d7Extension.physical_acceptance_authority -and
    -not [bool]$r24d7Extension.release_authority -and
    $r24d7RequiredRules.Count -eq 5 -and
    $r24d7MissingDiffRules.Count -eq 0 -and
    $r24d7MissingLiveRules.Count -eq 0 -and
    $r24d7SourcePaths.Count -eq 10 -and
    $r24d7BlobFaithfulPathCount -eq 10 -and
    $r24d7CrByteCount -eq 0 -and
    -not $r24d7Diff.Contains("+* text=auto") -and
    -not $r24d7Diff.Contains("+* -text")
) "R24D7 checkout-rule extension changed"

Assert-Exact (
    [string]$r24d7ClosureExtension.declared_from_source_commit -ceq
        "ab6e763e466db86ea1d6fea6b72a23a68ff63587" -and
    [string]$r24d7ClosureExtension.scope -ceq
        "post_attempt_qsdk_r24d7_physical_implementation_invalid_closure_and_executable_audit_only" -and
    [int]$r24d7ClosureExtension.added_rule_count -eq 0 -and
    [int]$r24d7ClosureExtension.existing_r24d7_wildcard_rule_count_reused -eq 2 -and
    [int]$r24d7ClosureExtension.new_closure_path_count -eq 2 -and
    [int]$r24d7ClosureExtension.closure_path_checkout_git_blob_equality_count -eq 2 -and
    [int]$r24d7ClosureExtension.closure_path_cr_byte_count -eq 0 -and
    -not [bool]$r24d7ClosureExtension.executed_r24d7_source_rule_changed -and
    -not [bool]$r24d7ClosureExtension.executed_r24d7_source_evaluator_or_worker_changed -and
    -not [bool]$r24d7ClosureExtension.historical_path_rule_changed -and
    -not [bool]$r24d7ClosureExtension.renormalization_executed -and
    -not [bool]$r24d7ClosureExtension.checkout_filter_migration_executed -and
    [string]$r24d7ClosureExtension.declaration_mode -ceq
        "post_consumed_physical_implementation_invalid_attempt_before_closure_commit_without_reopening_physics" -and
    [int]$r24d7ClosureExtension.threshold_selector_evaluator_or_result_interpretation_change_count -eq 0 -and
    [int]$r24d7ClosureExtension.physical_world_attempt_count -eq 1 -and
    [int]$r24d7ClosureExtension.world_build_count -eq 1 -and
    [int]$r24d7ClosureExtension.physics_step_count -eq 20 -and
    [int]$r24d7ClosureExtension.retained_sample_count -eq 68 -and
    [int]$r24d7ClosureExtension.integrate_callback_attempt_count -eq 65 -and
    [int]$r24d7ClosureExtension.integrate_callback_refusal_count -eq 0 -and
    -not [bool]$r24d7ClosureExtension.active_step_timing_control_adequate -and
    -not [bool]$r24d7ClosureExtension.valid_characterization -and
    [int]$r24d7ClosureExtension.maintenance_process_physical_world_count -eq 0 -and
    [bool]$r24d7ClosureExtension.same_source_physical_rerun_forbidden -and
    -not [bool]$r24d7ClosureExtension.physical_acceptance_authority -and
    -not [bool]$r24d7ClosureExtension.release_authority -and
    $r24d7ClosureReusedRules.Count -eq 2 -and
    $r24d7ClosureMissingLiveRules.Count -eq 0 -and
    $r24d7ClosurePaths.Count -eq 2 -and
    $r24d7ClosureBlobFaithfulPathCount -eq 2 -and
    $r24d7ClosureCrByteCount -eq 0
) "R24D7 physical failure closure checkout boundary changed"

Assert-Exact (
    [string]$r24d8Extension.declared_from_parent_commit -ceq
        "9fb088d3de8a656f2ec5e45b71b900002cc66578" -and
    [string]$r24d8Extension.scope -ceq
        "qsdk_r24d8_active_step_snapshot_timing_source_patch_diagnostics_official_failure_compatibility_worker_supervisor_and_freeze_families_only" -and
    [int]$r24d8Extension.added_rule_count -eq 6 -and
    [int]$r24d8Extension.planned_new_path_count -eq 12 -and
    [int]$r24d8Extension.source_path_count_at_contract_binding -eq 12 -and
    [int]$r24d8Extension.source_path_checkout_git_blob_equality_count -eq 12 -and
    [int]$r24d8Extension.source_path_cr_byte_count -eq 0 -and
    [string]$r24d8Extension.pre_rule_gitattributes_raw_sha256 -ceq
        "74b8732df3c4814f0ae564f30a22a77e33cb5a2599b60fdd44a8d71e7959bddc" -and
    [string]$r24d8Extension.pre_rule_gitattributes_git_blob -ceq
        "c84dcf29768921cca4d9080c04f2f5f821c33343" -and
    [int]$r24d8Extension.pre_rule_gitattributes_byte_length -eq 58036 -and
    [bool]$r24d8Extension.rules_added_before_first_r24d8_commit -and
    -not [bool]$r24d8Extension.ambient_rule_changed -and
    -not [bool]$r24d8Extension.historical_path_rule_changed -and
    [int]$r24d8Extension.historical_tracked_file_renormalization_count -eq 0 -and
    [int]$r24d8Extension.new_uncommitted_source_lf_normalization_count -eq 0 -and
    -not [bool]$r24d8Extension.renormalization_executed -and
    -not [bool]$r24d8Extension.checkout_filter_migration_executed -and
    [string]$r24d8Extension.declaration_mode -ceq
        "post_first_official_zero_world_incomplete_static_dependency_attempt_distinct_maintenance_source_before_second_official_attempt_or_physical_world" -and
    [int]$r24d8Extension.precommit_zero_world_diagnostic_attempt_count -eq 2 -and
    [int]$r24d8Extension.precommit_runtime_freeze_negative_count -eq 1 -and
    [int]$r24d8Extension.precommit_isolated_synthetic_pass_count -eq 1 -and
    [int]$r24d8Extension.precommit_parser_attempt_count -eq 1 -and
    [int]$r24d8Extension.precommit_parser_pass_count -eq 1 -and
    [string]$r24d8Extension.first_official_zero_world_source_commit -ceq
        "49c643dec947088bffbec4703c3fe076b9768a9f" -and
    [string]$r24d8Extension.first_official_zero_world_source_tree_git_oid -ceq
        "9e3c0a6fa1934bd26a027ec5ee2e77c3039c4d51" -and
    [int]$r24d8Extension.first_official_zero_world_attempt_count -eq 1 -and
    [int]$r24d8Extension.first_official_zero_world_incomplete_count -eq 1 -and
    [int]$r24d8Extension.first_official_zero_world_retained_file_count -eq 2 -and
    [int]$r24d8Extension.first_official_zero_world_retained_unique_digest_count -eq 2 -and
    [int]$r24d8Extension.first_official_zero_world_cold_build_count -eq 0 -and
    [int]$r24d8Extension.first_official_zero_world_worker_launch_count -eq 0 -and
    [int]$r24d8Extension.first_official_zero_world_world_attempt_count -eq 0 -and
    [int]$r24d8Extension.first_official_zero_world_world_build_count -eq 0 -and
    [int]$r24d8Extension.first_official_zero_world_solver_step_count -eq 0 -and
    -not [bool]$r24d8Extension.same_source_official_zero_world_rerun_allowed -and
    [int]$r24d8Extension.maintenance_precommit_attempt_count -eq 6 -and
    [int]$r24d8Extension.maintenance_precommit_negative_count -eq 5 -and
    [int]$r24d8Extension.maintenance_precommit_pass_count -eq 1 -and
    [int]$r24d8Extension.official_zero_world_qualification_count -eq 0 -and
    [int]$r24d8Extension.maintenance_source_binding_count -eq 15 -and
    [int]$r24d8Extension.patched_native_source_file_count -eq 10 -and
    [int]$r24d8Extension.receipt_field_count -eq 15 -and
    [int]$r24d8Extension.contract_mutation_rejection_count -eq 18 -and
    [int]$r24d8Extension.first_official_failure_mutation_rejection_count -eq 8 -and
    [int]$r24d8Extension.maintenance_diagnostic_mutation_rejection_count -eq 7 -and
    [int]$r24d8Extension.predecessor_compatibility_source_mutation_rejection_count -eq 14 -and
    [int]$r24d8Extension.evaluator_mutation_rejection_count -eq 25 -and
    [int]$r24d8Extension.threshold_selector_evaluator_or_physical_result_change_count -eq 0 -and
    [int]$r24d8Extension.predecessor_r24d7_source_or_result_change_count -eq 0 -and
    [int]$r24d8Extension.physical_threshold_value_count -eq 0 -and
    [int]$r24d8Extension.physical_cohort_identity_count -eq 0 -and
    [int]$r24d8Extension.physical_world_count -eq 0 -and
    [int]$r24d8Extension.recovery_world_count -eq 0 -and
    [int]$r24d8Extension.prone_to_standing_world_count -eq 0 -and
    -not [bool]$r24d8Extension.turning_claim_changed -and
    -not [bool]$r24d8Extension.physical_acceptance_authority -and
    -not [bool]$r24d8Extension.release_authority -and
    $r24d8RequiredRules.Count -eq 6 -and
    $r24d8MissingDiffRules.Count -eq 0 -and
    $r24d8MissingLiveRules.Count -eq 0 -and
    $r24d8SourcePaths.Count -eq 12 -and
    $r24d8BlobFaithfulPathCount -eq 12 -and
    $r24d8CrByteCount -eq 0 -and
    -not $r24d8Diff.Contains("+* text=auto") -and
    -not $r24d8Diff.Contains("+* -text")
) "R24D8 checkout-rule extension changed"

Assert-Exact (
    [string]$r24d9Extension.declared_from_parent_commit -ceq
        "4088881d92ea335c1cb70ff42e15abe5bf5d42c5" -and
    [string]$r24d9Extension.scope -ceq
        "qsdk_r24d9_numerical_telemetry_declaration_and_future_implementation_families_only" -and
    [int]$r24d9Extension.added_rule_count -eq 5 -and
    [int]$r24d9Extension.planned_new_path_count -eq 8 -and
    [int]$r24d9Extension.source_path_count_at_contract_binding -eq 2 -and
    [int]$r24d9Extension.source_path_checkout_git_blob_equality_count -eq 2 -and
    [int]$r24d9Extension.source_path_cr_byte_count -eq 0 -and
    [string]$r24d9Extension.pre_rule_gitattributes_raw_sha256 -ceq
        "f09ced86135a37ebefe2c5b824ad717316c17fee8717a95f6d0729e94416b3a6" -and
    [string]$r24d9Extension.pre_rule_gitattributes_git_blob -ceq
        "7185808d4b896aab56c1976593f79e34a78ff14d" -and
    [long]$r24d9Extension.pre_rule_gitattributes_byte_length -eq 58555 -and
    [bool]$r24d9Extension.rules_added_before_first_r24d9_commit -and
    -not [bool]$r24d9Extension.ambient_rule_changed -and
    -not [bool]$r24d9Extension.historical_path_rule_changed -and
    [int]$r24d9Extension.historical_tracked_file_renormalization_count -eq 0 -and
    [int]$r24d9Extension.new_uncommitted_source_lf_normalization_count -eq 0 -and
    -not [bool]$r24d9Extension.renormalization_executed -and
    -not [bool]$r24d9Extension.checkout_filter_migration_executed -and
    [string]$r24d9Extension.declaration_mode -ceq
        "prospective_development_declaration_before_implementation_zero_world_or_physical_execution" -and
    [string]$r24d9Extension.question_class -ceq "development" -and
    [string]$r24d9Extension.authorization_gate_id -ceq "QSDK-R24D8" -and
    [string]$r24d9Extension.authorization_closure_raw_sha256 -ceq
        "a068b13f8fa97db5559572b1a221bff262da4c3d933a2544198ec67156cbba4d" -and
    [string]$r24d9Extension.preregistration_raw_sha256 -ceq
        "0ecd8c9af7d3a79bdc8b02419816bada5e5c7f2dd837f837b42eb3a31c3176cc" -and
    [string]$r24d9Extension.declaration_audit_raw_sha256 -ceq
        "6bb53430556918886e53c818d0e7492a4a2c1a6b0df60ecc35d7a4ee37164874" -and
    [int]$r24d9Extension.declared_fixture_world_count -eq 1 -and
    [int]$r24d9Extension.declared_cell_count -eq 9 -and
    [int]$r24d9Extension.declared_maximum_physics_step_count -eq 20 -and
    [int]$r24d9Extension.declared_retained_sample_count -eq 68 -and
    [int]$r24d9Extension.declared_evaluator_negative_control_count -eq 46 -and
    [int]$r24d9Extension.declaration_mutation_rejection_count -eq 33 -and
    [int]$r24d9Extension.empirical_acceptance_threshold_count -eq 0 -and
    [int]$r24d9Extension.superiority_margin_count -eq 0 -and
    [int]$r24d9Extension.equivalence_or_non_inferiority_margin_count -eq 0 -and
    [int]$r24d9Extension.held_out_validation_cohort_count -eq 0 -and
    [int]$r24d9Extension.population_claim_count -eq 0 -and
    -not [bool]$r24d9Extension.implementation_complete -and
    -not [bool]$r24d9Extension.complete_zero_world_gate_passed -and
    [int]$r24d9Extension.physical_world_count -eq 0 -and
    [int]$r24d9Extension.world_build_count -eq 0 -and
    [int]$r24d9Extension.physics_step_count -eq 0 -and
    [int]$r24d9Extension.recovery_world_count -eq 0 -and
    [int]$r24d9Extension.prone_to_standing_world_count -eq 0 -and
    -not [bool]$r24d9Extension.turning_claim_changed -and
    -not [bool]$r24d9Extension.physical_acceptance_authority -and
    -not [bool]$r24d9Extension.release_authority -and
    $r24d9RequiredRules.Count -eq 5 -and
    $r24d9MissingDiffRules.Count -eq 0 -and
    $r24d9MissingLiveRules.Count -eq 0 -and
    $r24d9SourcePaths.Count -eq 2 -and
    $r24d9BlobFaithfulPathCount -eq 2 -and
    $r24d9CrByteCount -eq 0 -and
    -not $r24d9Diff.Contains("+* text=auto") -and
    -not $r24d9Diff.Contains("+* -text")
) "R24D9 checkout-rule extension changed"

$r23d62RepairPaths = @(
    "docs/research/LOCOMOTION_RESEARCH_SOURCES.md",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/__init__.py",
    "sdk/adapters/rapier/src/conformance.rs"
)
$r23d62RepairCrByteCount = 0
foreach ($relativePath in $r23d62RepairPaths) {
    $r23d62RepairCrByteCount += @(
        [IO.File]::ReadAllBytes((Join-Path $repoRoot $relativePath)) |
            Where-Object { $_ -eq 13 }
    ).Count
}
$r23d62RefusalPath =
    [string]$r23d62PrephysicalCheckoutRepair.prephysical_refusal_record_path
$r23d62PostRuleAttributesBlob = Get-GitBlobRawIdentity (
    [string]$r23d62PrephysicalCheckoutRepair.post_rule_gitattributes_git_blob_oid
)
Assert-Exact (
    [string]$r23d62PrephysicalCheckoutRepair.declared_from_parent_commit -ceq
        "103e2043f09e7c3f131042e1b9b5250df7ccc652" -and
    [string]$r23d62PrephysicalCheckoutRepair.declared_from_parent_tree_git_oid -ceq
        "4c8da505e32f413c4b760bf4e2dfea873a8fc9bd" -and
    [string]$r23d62PrephysicalCheckoutRepair.source_process_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$r23d62PrephysicalCheckoutRepair.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$r23d62PrephysicalCheckoutRepair.pre_rule_gitattributes_raw_sha256 -ceq
        "0256d751e2e704f6888a5c3aa5de5f6a06474885b8ecfc8e6e1260184ec206f0" -and
    [string]$r23d62PrephysicalCheckoutRepair.pre_rule_gitattributes_git_blob_oid -ceq
        "904e8a67158c542126101d4f6967069fee629f9b" -and
    [long]$r23d62PrephysicalCheckoutRepair.pre_rule_gitattributes_byte_length -eq 59458 -and
    [string]$r23d62PrephysicalCheckoutRepair.post_rule_gitattributes_raw_sha256 -ceq
        [string]$r23d62PostRuleAttributesBlob.raw_sha256 -and
    [string]$r23d62PrephysicalCheckoutRepair.post_rule_gitattributes_git_blob_oid -ceq
        [string]$r23d62PostRuleAttributesBlob.object_id -and
    [long]$r23d62PrephysicalCheckoutRepair.post_rule_gitattributes_byte_length -eq
        [long]$r23d62PostRuleAttributesBlob.byte_length -and
    [int]$r23d62PrephysicalCheckoutRepair.added_rule_count -eq 3 -and
    (@($r23d62PrephysicalCheckoutRepair.added_rules) -join "|") -ceq
        "docs/research/LOCOMOTION_RESEARCH_SOURCES.md text eol=lf|sdk/adapters/rapier/src/conformance.rs text eol=lf|sdk/adapters/mujoco/sporespore_mujoco_adapter/__init__.py text eol=lf" -and
    -not [bool]$r23d62PrephysicalCheckoutRepair.ambient_rule_changed -and
    [bool]$r23d62PrephysicalCheckoutRepair.historical_path_rule_changed -and
    [bool]$r23d62PrephysicalCheckoutRepair.bounded_existing_path_materialization_repair -and
    [int]$r23d62PrephysicalCheckoutRepair.historical_tracked_file_lf_normalization_count -eq 3 -and
    [int]$r23d62PrephysicalCheckoutRepair.documentation_only_source_annotation_count -eq 3 -and
    [bool]$r23d62PrephysicalCheckoutRepair.renormalization_executed -and
    -not [bool]$r23d62PrephysicalCheckoutRepair.checkout_filter_migration_executed -and
    [int]$r23d62PrephysicalCheckoutRepair.complete_dependency_population_size -eq 221 -and
    [bool]$r23d62PrephysicalCheckoutRepair.complete_dependency_population_compared -and
    -not [bool]$r23d62PrephysicalCheckoutRepair.dependency_sampling_claimed -and
    [int]$r23d62PrephysicalCheckoutRepair.pre_repair_checkout_blob_match_count -eq 218 -and
    [int]$r23d62PrephysicalCheckoutRepair.pre_repair_checkout_blob_mismatch_count -eq 3 -and
    (@($r23d62PrephysicalCheckoutRepair.mismatch_paths) -join "|") -ceq
        ($r23d62RepairPaths -join "|") -and
    [bool]$r23d62PrephysicalCheckoutRepair.all_mismatch_filtered_identities_equal_HEAD -and
    [string]$r23d62PrephysicalCheckoutRepair.threshold_origin -ceq
        "exact_raw_checkout_blob_oid_equality_against_HEAD_for_all_221_dependencies" -and
    [int]$r23d62PrephysicalCheckoutRepair.equivalence_margin -eq 0 -and
    [int]$r23d62PrephysicalCheckoutRepair.non_inferiority_margin -eq 0 -and
    $r23d62RepairCrByteCount -eq 0 -and
    (Test-Path -LiteralPath $r23d62RefusalPath -PathType Leaf) -and
    (Get-RawSha256 $r23d62RefusalPath) -ceq
        [string]$r23d62PrephysicalCheckoutRepair.prephysical_refusal_record_raw_sha256 -and
    (Get-Item -LiteralPath $r23d62RefusalPath).Length -eq
        [long]$r23d62PrephysicalCheckoutRepair.prephysical_refusal_record_byte_length -and
    -not [bool]$r23d62PrephysicalCheckoutRepair.physical_freeze_written -and
    -not [bool]$r23d62PrephysicalCheckoutRepair.attempt_authorization_written -and
    -not [bool]$r23d62PrephysicalCheckoutRepair.attempt_consumed -and
    [int]$r23d62PrephysicalCheckoutRepair.model_construction_count -eq 0 -and
    [int]$r23d62PrephysicalCheckoutRepair.world_attempt_count -eq 0 -and
    [int]$r23d62PrephysicalCheckoutRepair.world_build_count -eq 0 -and
    [bool]$r23d62PrephysicalCheckoutRepair.strict_raw_checkout_gate_added_to_clean_source_qualification -and
    -not [bool]$r23d62PrephysicalCheckoutRepair.prior_qualification_and_adoption_reusable_for_repaired_source -and
    [bool]$r23d62PrephysicalCheckoutRepair.fresh_clean_pushed_qualification_and_adoption_required -and
    [int]$r23d62PrephysicalCheckoutRepair.route_worker_controller_physics_threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    -not [bool]$r23d62PrephysicalCheckoutRepair.turning_claim_changed -and
    -not [bool]$r23d62PrephysicalCheckoutRepair.prone_to_standing_claimed -and
    -not [bool]$r23d62PrephysicalCheckoutRepair.physical_acceptance_authority -and
    -not [bool]$r23d62PrephysicalCheckoutRepair.release_authority -and
    $attributesText.Contains("docs/research/LOCOMOTION_RESEARCH_SOURCES.md text eol=lf") -and
    $attributesText.Contains("sdk/adapters/rapier/src/conformance.rs text eol=lf") -and
    $attributesText.Contains("sdk/adapters/mujoco/sporespore_mujoco_adapter/__init__.py text eol=lf") -and
    -not $attributesText.Contains("* -text")
) "R23D62 prephysical checkout-byte bounded repair changed"

$postR23D62SnapshotCommit = [string]@(
    $postR23D62RuleReconciliation.ordered_rule_commits
)[-1]
$postR23D62PostExtensionBlob = Get-GitBlobRawIdentity (
    [string]$postR23D62RuleReconciliation.post_extension_gitattributes_git_blob_oid
)
$postR23D62Diff = @(
    git -C $repoRoot diff --unified=0 `
        "cb5883ce1bd0528a6279bcda4d0cde3947cfe664" `
        $postR23D62SnapshotCommit `
        -- .gitattributes
)
$postR23D62AddedLines = @($postR23D62Diff | Where-Object {
    ([string]$_).StartsWith("+", [StringComparison]::Ordinal) -and
    -not ([string]$_).StartsWith("+++", [StringComparison]::Ordinal)
})
$postR23D62AddedRules = @($postR23D62AddedLines | ForEach-Object {
    ([string]$_).Substring(1)
} | Where-Object {
    -not [string]::IsNullOrWhiteSpace([string]$_) -and
    -not ([string]$_).StartsWith("#", [StringComparison]::Ordinal)
})
$postR23D62RemovedLines = @($postR23D62Diff | Where-Object {
    ([string]$_).StartsWith("-", [StringComparison]::Ordinal) -and
    -not ([string]$_).StartsWith("---", [StringComparison]::Ordinal)
})
$postR23D62EvidenceBindings = @(
    [ordered]@{
        Path = [string]$postR23D62RuleReconciliation.failed_qualification_failure_path
        Sha256 = [string]$postR23D62RuleReconciliation.failed_qualification_failure_raw_sha256
        ByteLength = [long]$postR23D62RuleReconciliation.failed_qualification_failure_byte_length
    },
    [ordered]@{
        Path = [string]$postR23D62RuleReconciliation.failed_provenance_gate_receipt_path
        Sha256 = [string]$postR23D62RuleReconciliation.failed_provenance_gate_receipt_raw_sha256
        ByteLength = [long]$postR23D62RuleReconciliation.failed_provenance_gate_receipt_byte_length
    },
    [ordered]@{
        Path = [string]$postR23D62RuleReconciliation.failed_provenance_gate_stderr_path
        Sha256 = [string]$postR23D62RuleReconciliation.failed_provenance_gate_stderr_raw_sha256
        ByteLength = [long]$postR23D62RuleReconciliation.failed_provenance_gate_stderr_byte_length
    }
)
$postR23D62RetainedFiles = @(Get-ChildItem -LiteralPath (
    [string]$postR23D62RuleReconciliation.failed_qualification_root
) -Recurse -File)
Assert-Exact (
    [string]$postR23D62RuleReconciliation.status -ceq
        "failed_closed_then_repaired_before_any_r23d66_physics" -and
    [string]$postR23D62RuleReconciliation.qualification_process_question_class -ceq
        "development" -and
    [string]$postR23D62RuleReconciliation.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$postR23D62RuleReconciliation.declared_from_failed_clean_pushed_source_commit -ceq
        "bf6836de7806c18e39eafa10a942ae0d77bc310a" -and
    [string]$postR23D62RuleReconciliation.declared_from_failed_clean_pushed_source_tree_git_oid -ceq
        "318cc30559ad0031a13dc84339e72b3c84e5f6ae" -and
    [int]$postR23D62RuleReconciliation.failed_qualification_passed_gate_count -eq 3 -and
    [string]$postR23D62RuleReconciliation.failed_qualification_gate_id -ceq
        "CAK1-EVIDENCE-PROVENANCE" -and
    [int]$postR23D62RuleReconciliation.failed_qualification_campaign_role_gate_count -eq 0 -and
    [int]$postR23D62RuleReconciliation.failed_qualification_model_construction_count -eq 0 -and
    [int]$postR23D62RuleReconciliation.failed_qualification_world_attempt_count -eq 0 -and
    [int]$postR23D62RuleReconciliation.failed_qualification_world_build_count -eq 0 -and
    [string]$postR23D62RuleReconciliation.historical_repair_post_rule_raw_sha256 -ceq
        [string]$r23d62PostRuleAttributesBlob.raw_sha256 -and
    [string]$postR23D62RuleReconciliation.historical_repair_post_rule_git_blob_oid -ceq
        [string]$r23d62PostRuleAttributesBlob.object_id -and
    [long]$postR23D62RuleReconciliation.historical_repair_post_rule_byte_length -eq
        [long]$r23d62PostRuleAttributesBlob.byte_length -and
    [bool]$postR23D62RuleReconciliation.historical_repair_audit_now_reads_pinned_git_blob -and
    [string]$postR23D62RuleReconciliation.post_extension_gitattributes_raw_sha256 -ceq
        [string]$postR23D62PostExtensionBlob.raw_sha256 -and
    [string]$postR23D62RuleReconciliation.post_extension_gitattributes_git_blob_oid -ceq
        [string]$postR23D62PostExtensionBlob.object_id -and
    [long]$postR23D62RuleReconciliation.post_extension_gitattributes_byte_length -eq
        [long]$postR23D62PostExtensionBlob.byte_length -and
    [int]$postR23D62RuleReconciliation.ordered_rule_commit_count -eq 5 -and
    (@($postR23D62RuleReconciliation.ordered_rule_commits) -join "|") -ceq
        "89306ba122c0781af8915cccde23c737e3e9b471|e2fc35e8c247f7706ca8f41d58acb21843d5ae3f|39c8ff7560f3be8b75c214cbe39ed1662af652e3|52f567557b79a7992084ac5eba9ce25d9ba6ed23|3966be211981261991b527163cc9c70f89847b8d" -and
    [int]$postR23D62RuleReconciliation.added_line_count -eq
        $postR23D62AddedLines.Count -and
    [int]$postR23D62RuleReconciliation.added_rule_count -eq
        $postR23D62AddedRules.Count -and
    (@($postR23D62RuleReconciliation.added_rules) -join "|") -ceq
        ($postR23D62AddedRules -join "|") -and
    $postR23D62RemovedLines.Count -eq 0 -and
    -not [bool]$postR23D62RuleReconciliation.ambient_rule_changed -and
    [int]$postR23D62RuleReconciliation.existing_rule_removed_or_modified_count -eq 0 -and
    [int]$postR23D62RuleReconciliation.historical_tracked_file_renormalization_count -eq 0 -and
    -not [bool]$postR23D62RuleReconciliation.checkout_filter_migration_executed -and
    $postR23D62RetainedFiles.Count -eq
        [int]$postR23D62RuleReconciliation.failed_qualification_retained_file_count -and
    [long](($postR23D62RetainedFiles | Measure-Object Length -Sum).Sum) -eq
        [long]$postR23D62RuleReconciliation.failed_qualification_retained_byte_count -and
    [bool]$postR23D62RuleReconciliation.failed_qualification_retained -and
    -not [bool]$postR23D62RuleReconciliation.failed_qualification_reusable -and
    [bool]$postR23D62RuleReconciliation.qualification_retry_requires_distinct_corrected_clean_pushed_source -and
    [int]$postR23D62RuleReconciliation.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$postR23D62RuleReconciliation.maintenance_process_physical_world_count -eq 0 -and
    [int]$postR23D62RuleReconciliation.r23d66_physical_world_count -eq 0 -and
    -not [bool]$postR23D62RuleReconciliation.r23d66_turning_claim_changed -and
    -not [bool]$postR23D62RuleReconciliation.cross_engine_equivalence_claimed -and
    -not [bool]$postR23D62RuleReconciliation.prone_to_standing_claimed -and
    -not [bool]$postR23D62RuleReconciliation.physical_acceptance_authority -and
    -not [bool]$postR23D62RuleReconciliation.release_authority
) "Post-R23D62 checkout-rule reconciliation changed"
foreach ($binding in $postR23D62EvidenceBindings) {
    Assert-Exact (Test-Path -LiteralPath $binding.Path -PathType Leaf) (
        "Post-R23D62 retained qualification evidence missing: $($binding.Path)"
    )
    Assert-Exact (
        (Get-RawSha256 $binding.Path) -ceq $binding.Sha256 -and
        (Get-Item -LiteralPath $binding.Path).Length -eq $binding.ByteLength
    ) "Post-R23D62 retained qualification evidence bytes changed: $($binding.Path)"
}

$r23d67ProvenanceEvidenceBindings = @(
    [ordered]@{
        Path = [string]$r23d67QualificationProvenanceReconciliation.failed_qualification_failure_path
        Sha256 = [string]$r23d67QualificationProvenanceReconciliation.failed_qualification_failure_raw_sha256
        ByteLength = [long]$r23d67QualificationProvenanceReconciliation.failed_qualification_failure_byte_length
    },
    [ordered]@{
        Path = [string]$r23d67QualificationProvenanceReconciliation.failed_provenance_gate_receipt_path
        Sha256 = [string]$r23d67QualificationProvenanceReconciliation.failed_provenance_gate_receipt_raw_sha256
        ByteLength = [long]$r23d67QualificationProvenanceReconciliation.failed_provenance_gate_receipt_byte_length
    },
    [ordered]@{
        Path = [string]$r23d67QualificationProvenanceReconciliation.failed_provenance_gate_stderr_path
        Sha256 = [string]$r23d67QualificationProvenanceReconciliation.failed_provenance_gate_stderr_raw_sha256
        ByteLength = [long]$r23d67QualificationProvenanceReconciliation.failed_provenance_gate_stderr_byte_length
    }
)
$r23d67ProvenanceRetainedFiles = @(Get-ChildItem -LiteralPath (
    [string]$r23d67QualificationProvenanceReconciliation.failed_qualification_root
) -Recurse -File)
$r23d67HistoricalSnapshotBlob = Get-GitBlobRawIdentity (
    [string]$r23d67QualificationProvenanceReconciliation.historical_snapshot_git_blob_oid
)
Assert-Exact (
    [string]$r23d67QualificationProvenanceReconciliation.status -ceq
        "failed_closed_then_repaired_before_any_r23d67_physics" -and
    [string]$r23d67QualificationProvenanceReconciliation.qualification_process_question_class -ceq
        "development" -and
    [string]$r23d67QualificationProvenanceReconciliation.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$r23d67QualificationProvenanceReconciliation.failed_source_commit -ceq
        "6e6e72e8568ec57b477f3e961945cdc873220630" -and
    [string]$r23d67QualificationProvenanceReconciliation.failed_source_tree_git_oid -ceq
        "8b2139a2b89834c1da6931b7946923a34609c47d" -and
    [int]$r23d67QualificationProvenanceReconciliation.failed_qualification_passed_gate_count -eq 3 -and
    [string]$r23d67QualificationProvenanceReconciliation.failed_qualification_gate_id -ceq
        "CAK1-EVIDENCE-PROVENANCE" -and
    [int]$r23d67QualificationProvenanceReconciliation.failed_qualification_campaign_role_gate_count -eq 0 -and
    [int]$r23d67QualificationProvenanceReconciliation.failed_qualification_model_construction_count -eq 0 -and
    [int]$r23d67QualificationProvenanceReconciliation.failed_qualification_world_attempt_count -eq 0 -and
    [int]$r23d67QualificationProvenanceReconciliation.failed_qualification_world_build_count -eq 0 -and
    [string]$r23d67QualificationProvenanceReconciliation.failure_code -ceq
        "historical_post_r23d62_snapshot_compared_to_live_gitattributes_after_later_valid_rule_extensions" -and
    [string]$r23d67QualificationProvenanceReconciliation.historical_snapshot_base_commit -ceq
        "cb5883ce1bd0528a6279bcda4d0cde3947cfe664" -and
    [string]$r23d67QualificationProvenanceReconciliation.historical_snapshot_terminal_commit -ceq
        "3966be211981261991b527163cc9c70f89847b8d" -and
    [string]$r23d67QualificationProvenanceReconciliation.historical_snapshot_raw_sha256 -ceq
        [string]$r23d67HistoricalSnapshotBlob.raw_sha256 -and
    [string]$r23d67QualificationProvenanceReconciliation.historical_snapshot_git_blob_oid -ceq
        [string]$r23d67HistoricalSnapshotBlob.object_id -and
    [long]$r23d67QualificationProvenanceReconciliation.historical_snapshot_byte_length -eq
        [long]$r23d67HistoricalSnapshotBlob.byte_length -and
    [bool]$r23d67QualificationProvenanceReconciliation.historical_snapshot_now_reads_pinned_git_blob -and
    -not [bool]$r23d67QualificationProvenanceReconciliation.historical_r23d66_record_rewritten -and
    [string]$r23d67QualificationProvenanceReconciliation.current_gitattributes_raw_sha256 -ceq
        (Get-RawSha256 $attributesPath) -and
    [string]$r23d67QualificationProvenanceReconciliation.current_gitattributes_git_blob_oid -ceq
        (git -C $repoRoot hash-object $attributesPath).Trim() -and
    [long]$r23d67QualificationProvenanceReconciliation.current_gitattributes_byte_length -eq
        (Get-Item -LiteralPath $attributesPath).Length -and
    [bool]$r23d67QualificationProvenanceReconciliation.top_level_current_identity_rebound -and
    $r23d67ProvenanceRetainedFiles.Count -eq
        [int]$r23d67QualificationProvenanceReconciliation.failed_qualification_retained_file_count -and
    [long](($r23d67ProvenanceRetainedFiles | Measure-Object Length -Sum).Sum) -eq
        [long]$r23d67QualificationProvenanceReconciliation.failed_qualification_retained_byte_count -and
    [bool]$r23d67QualificationProvenanceReconciliation.failed_qualification_retained -and
    -not [bool]$r23d67QualificationProvenanceReconciliation.failed_qualification_reusable -and
    [bool]$r23d67QualificationProvenanceReconciliation.qualification_retry_requires_distinct_corrected_clean_pushed_source -and
    [int]$r23d67QualificationProvenanceReconciliation.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$r23d67QualificationProvenanceReconciliation.maintenance_process_physical_world_count -eq 0 -and
    [int]$r23d67QualificationProvenanceReconciliation.r23d67_physical_world_count -eq 0 -and
    -not [bool]$r23d67QualificationProvenanceReconciliation.r23d67_turning_claim_changed -and
    -not [bool]$r23d67QualificationProvenanceReconciliation.q_sdk_r23_satisfied -and
    [string]$r23d67QualificationProvenanceReconciliation.release_score_before -ceq "10/25" -and
    [string]$r23d67QualificationProvenanceReconciliation.release_score_after -ceq "10/25" -and
    -not [bool]$r23d67QualificationProvenanceReconciliation.cross_engine_equivalence_claimed -and
    -not [bool]$r23d67QualificationProvenanceReconciliation.prone_to_standing_claimed -and
    -not [bool]$r23d67QualificationProvenanceReconciliation.physical_acceptance_authority -and
    -not [bool]$r23d67QualificationProvenanceReconciliation.release_authority
) "R23D67 qualification provenance reconciliation changed"
foreach ($binding in $r23d67ProvenanceEvidenceBindings) {
    Assert-Exact (Test-Path -LiteralPath $binding.Path -PathType Leaf) (
        "R23D67 retained failed qualification evidence missing: $($binding.Path)"
    )
    Assert-Exact (
        (Get-RawSha256 $binding.Path) -ceq $binding.Sha256 -and
        (Get-Item -LiteralPath $binding.Path).Length -eq $binding.ByteLength
    ) "R23D67 retained failed qualification evidence bytes changed: $($binding.Path)"
}

$r23d78ProvenanceEvidenceBindings = @(
    [ordered]@{
        Path = [string]$r23d78QualificationProvenanceReconciliation.failed_qualification_failure_path
        Sha256 = [string]$r23d78QualificationProvenanceReconciliation.failed_qualification_failure_raw_sha256
        ByteLength = [long]$r23d78QualificationProvenanceReconciliation.failed_qualification_failure_byte_length
    },
    [ordered]@{
        Path = [string]$r23d78QualificationProvenanceReconciliation.failed_provenance_gate_receipt_path
        Sha256 = [string]$r23d78QualificationProvenanceReconciliation.failed_provenance_gate_receipt_raw_sha256
        ByteLength = [long]$r23d78QualificationProvenanceReconciliation.failed_provenance_gate_receipt_byte_length
    },
    [ordered]@{
        Path = [string]$r23d78QualificationProvenanceReconciliation.failed_provenance_gate_stderr_path
        Sha256 = [string]$r23d78QualificationProvenanceReconciliation.failed_provenance_gate_stderr_raw_sha256
        ByteLength = [long]$r23d78QualificationProvenanceReconciliation.failed_provenance_gate_stderr_byte_length
    }
)
$r23d78ProvenanceRetainedFiles = @(Get-ChildItem -LiteralPath (
    [string]$r23d78QualificationProvenanceReconciliation.failed_qualification_root
) -Recurse -File)
$r23d78QualificationFailure = Get-Content -LiteralPath (
    [string]$r23d78QualificationProvenanceReconciliation.failed_qualification_failure_path
) -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$r23d78QualificationReceipt = Get-Content -LiteralPath (
    [string]$r23d78QualificationProvenanceReconciliation.failed_provenance_gate_receipt_path
) -Raw | ConvertFrom-Json -AsHashtable -Depth 100
Assert-Exact (
    [string]$r23d78QualificationProvenanceReconciliation.status -ceq
        "failed_closed_then_current_checkout_identity_rebound_before_any_r23d78_physics" -and
    [string]$r23d78QualificationProvenanceReconciliation.qualification_process_question_class -ceq
        "development" -and
    [string]$r23d78QualificationProvenanceReconciliation.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$r23d78QualificationProvenanceReconciliation.failed_source_commit -ceq
        "0e47997990617ee5582b6ebacd552ad4a29378af" -and
    [string]$r23d78QualificationProvenanceReconciliation.failed_source_tree_git_oid -ceq
        "685aa3738e16e0fd00ad849787bc75cab75d5527" -and
    [int]$r23d78QualificationProvenanceReconciliation.failed_qualification_passed_gate_count -eq 3 -and
    [string]$r23d78QualificationProvenanceReconciliation.failed_qualification_gate_id -ceq
        "CAK1-EVIDENCE-PROVENANCE" -and
    [int]$r23d78QualificationProvenanceReconciliation.failed_qualification_campaign_role_gate_count -eq 0 -and
    [int]$r23d78QualificationProvenanceReconciliation.failed_qualification_model_construction_count -eq 0 -and
    [int]$r23d78QualificationProvenanceReconciliation.failed_qualification_world_attempt_count -eq 0 -and
    [int]$r23d78QualificationProvenanceReconciliation.failed_qualification_world_build_count -eq 0 -and
    [int]$r23d78QualificationProvenanceReconciliation.failed_qualification_solver_step_count -eq 0 -and
    [string]$r23d78QualificationProvenanceReconciliation.failure_code -ceq
        "current_gitattributes_identity_not_rebound_after_r23d78_lf_rule_extension" -and
    [string]$r23d78QualificationProvenanceReconciliation.r23d78_lf_rule_extension_commit -ceq
        "3ed9934e80c56baea19415aaf685155f5688944f" -and
    [string]$r23d78QualificationProvenanceReconciliation.previous_current_gitattributes_raw_sha256 -ceq
        "bb593853ffdb6a94e7ab797612ad9effdc15a419f2e2d263dd81f0cee7330433" -and
    [string]$r23d78QualificationProvenanceReconciliation.previous_current_gitattributes_git_blob_oid -ceq
        "7351309656ce43f19fb5a6eba2e7bce0eb59e442" -and
    [long]$r23d78QualificationProvenanceReconciliation.previous_current_gitattributes_byte_length -eq 61642 -and
    [string]$r23d78QualificationProvenanceReconciliation.current_gitattributes_raw_sha256 -ceq
        (Get-RawSha256 $attributesPath) -and
    [string]$r23d78QualificationProvenanceReconciliation.current_gitattributes_git_blob_oid -ceq
        (git -C $repoRoot hash-object $attributesPath).Trim() -and
    [long]$r23d78QualificationProvenanceReconciliation.current_gitattributes_byte_length -eq
        (Get-Item -LiteralPath $attributesPath).Length -and
    [bool]$r23d78QualificationProvenanceReconciliation.top_level_current_identity_rebound -and
    -not [bool]$r23d78QualificationProvenanceReconciliation.historical_rule_extension_receipt_rewritten -and
    -not [bool]$r23d78QualificationProvenanceReconciliation.historical_r23d67_qualification_result_rewritten -and
    $r23d78ProvenanceRetainedFiles.Count -eq
        [int]$r23d78QualificationProvenanceReconciliation.failed_qualification_retained_file_count -and
    [long](($r23d78ProvenanceRetainedFiles | Measure-Object Length -Sum).Sum) -eq
        [long]$r23d78QualificationProvenanceReconciliation.failed_qualification_retained_byte_count -and
    [bool]$r23d78QualificationProvenanceReconciliation.failed_qualification_retained -and
    -not [bool]$r23d78QualificationProvenanceReconciliation.failed_qualification_reusable -and
    -not [bool]$r23d78QualificationProvenanceReconciliation.same_source_qualification_rerun_allowed -and
    [bool]$r23d78QualificationProvenanceReconciliation.qualification_retry_requires_distinct_corrected_clean_pushed_source -and
    [int]$r23d78QualificationProvenanceReconciliation.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$r23d78QualificationProvenanceReconciliation.maintenance_process_physical_world_count -eq 0 -and
    [int]$r23d78QualificationProvenanceReconciliation.r23d78_physical_world_count -eq 0 -and
    -not [bool]$r23d78QualificationProvenanceReconciliation.r23d78_turning_claim_changed -and
    -not [bool]$r23d78QualificationProvenanceReconciliation.q_sdk_r23_satisfied -and
    [string]$r23d78QualificationProvenanceReconciliation.release_score_before -ceq "10/25" -and
    [string]$r23d78QualificationProvenanceReconciliation.release_score_after -ceq "10/25" -and
    -not [bool]$r23d78QualificationProvenanceReconciliation.cross_engine_equivalence_claimed -and
    -not [bool]$r23d78QualificationProvenanceReconciliation.prone_to_standing_claimed -and
    -not [bool]$r23d78QualificationProvenanceReconciliation.physical_acceptance_authority -and
    -not [bool]$r23d78QualificationProvenanceReconciliation.release_authority -and
    [string]$r23d78QualificationFailure.schema_version -ceq
        "sporespore_locomotion_campaign_attestation_failure_v1" -and
    [string]$r23d78QualificationFailure.campaign_id -ceq
        "QSDK-R23D78-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION" -and
    [string]$r23d78QualificationFailure.source_commit -ceq
        "0e47997990617ee5582b6ebacd552ad4a29378af" -and
    -not [bool]$r23d78QualificationFailure.campaign_local_qualification_passed -and
    -not [bool]$r23d78QualificationFailure.physical_launch_prerequisite_satisfied -and
    [string]$r23d78QualificationReceipt.gate_id -ceq "CAK1-EVIDENCE-PROVENANCE" -and
    [int]$r23d78QualificationReceipt.ordinal -eq 4 -and
    -not [bool]$r23d78QualificationReceipt.passed -and
    [int]$r23d78QualificationReceipt.physical_process_launch_count -eq 0 -and
    [int]$r23d78QualificationReceipt.physical_world_count -eq 0 -and
    -not [bool]$r23d78QualificationReceipt.physical_acceptance_authority
) "R23D78 qualification provenance reconciliation changed"
foreach ($binding in $r23d78ProvenanceEvidenceBindings) {
    Assert-Exact (Test-Path -LiteralPath $binding.Path -PathType Leaf) (
        "R23D78 retained failed qualification evidence missing: $($binding.Path)"
    )
    Assert-Exact (
        (Get-RawSha256 $binding.Path) -ceq $binding.Sha256 -and
        (Get-Item -LiteralPath $binding.Path).Length -eq $binding.ByteLength
    ) "R23D78 retained failed qualification evidence bytes changed: $($binding.Path)"
}

Assert-Exact (
    [string]$postR23D78CurrentIdentityReconciliation.status -ceq
        "two_valid_lf_rule_extensions_reconciled_without_physics" -and
    [string]$postR23D78CurrentIdentityReconciliation.maintenance_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$postR23D78CurrentIdentityReconciliation.scope -ceq
        "explicitly_current_checkout_identity_only" -and
    [string]$postR23D78CurrentIdentityReconciliation.previous_current_gitattributes_raw_sha256 -ceq
        "cb74cf46db161eadf0a03ac72e5e2e6a808bb52034a82fa614cb218adc7341f5" -and
    [string]$postR23D78CurrentIdentityReconciliation.previous_current_gitattributes_git_blob_oid -ceq
        "fcf936bb540bbda0d1ffd90e9d309ba0d645cc63" -and
    [long]$postR23D78CurrentIdentityReconciliation.previous_current_gitattributes_byte_length -eq 62289 -and
    [string]$postR23D78CurrentIdentityReconciliation.sdk1_milestone_mapping_rule_extension_commit -ceq
        "070bb14abc1ea2a113fdce386e3c9bfec9103030" -and
    [string]$postR23D78CurrentIdentityReconciliation.sdk1_milestone_mapping_rule_extension_parent_commit -ceq
        "60d6294fb1479d55344188b6eaf1f838c491baad" -and
    (git -C $repoRoot rev-parse (
        "{0}:.gitattributes" -f
            [string]$postR23D78CurrentIdentityReconciliation.sdk1_milestone_mapping_rule_extension_commit
    )).Trim() -ceq
        [string]$postR23D78CurrentIdentityReconciliation.sdk1_milestone_mapping_rule_extension_git_blob_oid -and
    [long]$postR23D78CurrentIdentityReconciliation.sdk1_milestone_mapping_rule_extension_byte_length -eq 62417 -and
    [int]$postR23D78CurrentIdentityReconciliation.sdk1_milestone_mapping_added_rule_count -eq 2 -and
    [string]$postR23D78CurrentIdentityReconciliation.r24d10_rule_extension_commit -ceq
        "11df9b566dda911c6c3f1a8ad76369c8ee0c340e" -and
    [string]$postR23D78CurrentIdentityReconciliation.r24d10_rule_extension_parent_commit -ceq
        "070bb14abc1ea2a113fdce386e3c9bfec9103030" -and
    (git -C $repoRoot rev-parse (
        "{0}:.gitattributes" -f
            [string]$postR23D78CurrentIdentityReconciliation.r24d10_rule_extension_commit
    )).Trim() -ceq
        [string]$postR23D78CurrentIdentityReconciliation.r24d10_rule_extension_git_blob_oid -and
    [long]$postR23D78CurrentIdentityReconciliation.r24d10_rule_extension_byte_length -eq 62830 -and
    [int]$postR23D78CurrentIdentityReconciliation.r24d10_added_rule_count -eq 5 -and
    [string]$postR23D78CurrentIdentityReconciliation.current_gitattributes_raw_sha256 -ceq
        (Get-RawSha256 $attributesPath) -and
    [string]$postR23D78CurrentIdentityReconciliation.current_gitattributes_git_blob_oid -ceq
        (git -C $repoRoot hash-object $attributesPath).Trim() -and
    [long]$postR23D78CurrentIdentityReconciliation.current_gitattributes_byte_length -eq
        (Get-Item -LiteralPath $attributesPath).Length -and
    [bool]$postR23D78CurrentIdentityReconciliation.top_level_current_identity_rebound -and
    [bool]$postR23D78CurrentIdentityReconciliation.r23d67_current_identity_binding_rebound -and
    [bool]$postR23D78CurrentIdentityReconciliation.r23d78_current_identity_binding_rebound -and
    -not [bool]$postR23D78CurrentIdentityReconciliation.ambient_rule_changed -and
    -not [bool]$postR23D78CurrentIdentityReconciliation.historical_path_rule_changed -and
    -not [bool]$postR23D78CurrentIdentityReconciliation.renormalization_executed -and
    -not [bool]$postR23D78CurrentIdentityReconciliation.checkout_filter_migration_executed -and
    -not [bool]$postR23D78CurrentIdentityReconciliation.historical_rule_extension_receipt_rewritten -and
    -not [bool]$postR23D78CurrentIdentityReconciliation.historical_campaign_result_or_interpretation_rewritten -and
    [int]$postR23D78CurrentIdentityReconciliation.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$postR23D78CurrentIdentityReconciliation.maintenance_process_physical_world_count -eq 0 -and
    [int]$postR23D78CurrentIdentityReconciliation.retained_r24d10_zero_world_physical_world_count -eq 0 -and
    [string]$postR23D78CurrentIdentityReconciliation.release_score_before -ceq "11/25" -and
    [string]$postR23D78CurrentIdentityReconciliation.release_score_after -ceq "11/25" -and
    -not [bool]$postR23D78CurrentIdentityReconciliation.q_sdk_r24_satisfied -and
    -not [bool]$postR23D78CurrentIdentityReconciliation.prone_to_standing_claimed -and
    -not [bool]$postR23D78CurrentIdentityReconciliation.cross_engine_equivalence_claimed -and
    -not [bool]$postR23D78CurrentIdentityReconciliation.physical_acceptance_authority -and
    -not [bool]$postR23D78CurrentIdentityReconciliation.release_authority
) "Post-R23D78 current checkout identity reconciliation changed"

Assert-Exact (
    [string]$contract.schema_version -ceq
        "sporespore_closure_evidence_provenance_contract_v1" -and
    [string]$contract.contract_id -ceq
        "CEP1-CLOSURE-EVIDENCE-PROVENANCE-MODES" -and
    [string]$contract.declared_from_parent_commit -ceq
        "cb1ef4f168e08bfe9ff87976a1080407ab9f81e3" -and
    [string]$contract.status -ceq
        "active_for_new_closures_legacy_inventory_frozen_filter_migration_not_authorized"
) "Closure evidence provenance contract identity changed"

$allowedModes = @($contract.rules_for_new_closures.allowed_historical_identity_modes)
Assert-Exact (
    ($allowedModes -join "|") -ceq "retained_cas_bytes|pinned_git_blob" -and
    [bool]$contract.rules_for_new_closures.reconstructed_checkout_requires_filter_state_receipt -and
    [bool]$contract.rules_for_new_closures.reconstructed_checkout_allowed_only_for_legacy_receipts_with_filter_state -and
    [bool]$contract.rules_for_new_closures.live_path_historical_identity_prohibited -and
    [bool]$contract.rules_for_new_closures.generated_and_build_artifacts_must_be_retained_before_first_consumption -and
    [bool]$contract.rules_for_new_closures.content_addressed_object_digest_must_equal_path_name -and
    [bool]$contract.rules_for_new_closures.new_physical_source_inputs_must_resolve_to_pinned_commit_git_blobs -and
    [bool]$contract.rules_for_new_closures.new_physical_source_receipts_must_record_git_blob_oid_blob_sha256_and_checkout_sha256 -and
    [bool]$contract.rules_for_new_closures.new_physical_checkout_bytes_must_equal_git_blob_bytes_or_a_declared_deterministic_projection -and
    [bool]$contract.rules_for_new_closures.cas_retention_alone_does_not_make_nonreconstructable_checkout_source_reproducible -and
    [bool]$contract.rules_for_new_closures.source_reproducibility_must_be_verified_after_clean_commit_and_before_first_world -and
    [bool]$contract.rules_for_new_closures.git_object_missing_must_report_evidence_unavailable_not_evidence_mismatched -and
    [bool]$contract.rules_for_new_closures.current_runtime_safety_check_never_repairs_or_replaces_historical_identity
) "Closure evidence provenance mode rules changed"

Assert-Exact (
    [string]$contract.checkout_filter_migration.current_status -ceq "not_executed" -and
    [string]$contract.checkout_filter_migration.current_gitattributes_raw_sha256 -ceq
        (Get-RawSha256 $attributesPath) -and
    [string]$contract.checkout_filter_migration.current_gitattributes_git_blob_oid -ceq
        (git -C $repoRoot hash-object $attributesPath).Trim() -and
    [string]$contract.checkout_filter_migration.current_ambient_rule -ceq
        "star_text_auto" -and
    [string]$r23d8Extension.commit -ceq
        "629fab3b1d0d8e6000479d3c90ec25562dde07f0" -and
    [string]$r23d8Extension.parent_commit -ceq
        "e3d18cab09d80cb765e4ceeb17a0ceda8dfa03a8" -and
    [string]$r23d8Extension.scope -ceq "prospective_r23d8_source_family_only" -and
    [int]$r23d8Extension.added_rule_count -eq 9 -and
    -not [bool]$r23d8Extension.ambient_rule_changed -and
    -not [bool]$r23d8Extension.historical_path_rule_changed -and
    -not [bool]$r23d8Extension.renormalization_executed -and
    -not [bool]$r23d8Extension.checkout_filter_migration_executed -and
    $r23d8Diff.Contains("+sdk/turning/r23d8_* text eol=lf") -and
    $r23d8Diff.Contains("+sdk/adapters/mujoco/test_qsdk_r23d8_*.py text eol=lf") -and
    -not $r23d8Diff.Contains("+* text=auto") -and
    -not $r23d8Diff.Contains("+* -text") -and
    [string]$r23d9StageZeroExtension.commit -ceq
        "53df1481aa03e1d638a46222c51f0d40fdb457ed" -and
    [string]$r23d9StageZeroExtension.parent_commit -ceq
        "5869318963a07c6572d1fa3ee2faa9c751e78abc" -and
    [string]$r23d9StageZeroExtension.scope -ceq
        "prospective_r23d9_source_family_only" -and
    [int]$r23d9StageZeroExtension.added_rule_count -eq 9 -and
    -not [bool]$r23d9StageZeroExtension.ambient_rule_changed -and
    -not [bool]$r23d9StageZeroExtension.historical_path_rule_changed -and
    -not [bool]$r23d9StageZeroExtension.renormalization_executed -and
    -not [bool]$r23d9StageZeroExtension.checkout_filter_migration_executed -and
    $r23d9StageZeroDiff.Contains("+sdk/turning/r23d9_* text eol=lf") -and
    $r23d9StageZeroDiff.Contains("+sdk/adapters/mujoco/test_qsdk_r23d9_*.py text eol=lf") -and
    -not $r23d9StageZeroDiff.Contains("+* text=auto") -and
    -not $r23d9StageZeroDiff.Contains("+* -text") -and
    [string]$r23d9StageOneExtension.commit -ceq
        "ddb8f962a93daa65f812204e56c2e1bdd78233d7" -and
    [string]$r23d9StageOneExtension.parent_commit -ceq
        "53df1481aa03e1d638a46222c51f0d40fdb457ed" -and
    [string]$r23d9StageOneExtension.scope -ceq
        "prospective_r23d9_native_shared_sources_only" -and
    [int]$r23d9StageOneExtension.added_rule_count -eq 2 -and
    -not [bool]$r23d9StageOneExtension.ambient_rule_changed -and
    -not [bool]$r23d9StageOneExtension.historical_path_rule_changed -and
    -not [bool]$r23d9StageOneExtension.renormalization_executed -and
    -not [bool]$r23d9StageOneExtension.checkout_filter_migration_executed -and
    $r23d9StageOneDiff.Contains("+sdk/adapters/rapier/src/qsdk_r23d9_*.rs text eol=lf") -and
    $r23d9StageOneDiff.Contains("+scripts/lab/gait/sdk_godot_jolt_support_handoff.gd text eol=lf") -and
    [string]$r23d10StageZeroExtension.commit -ceq
        "6b39e1df77a403d474924d203ab706f8fa495687" -and
    [string]$r23d10StageZeroExtension.parent_commit -ceq
        "29f3204763b475a0803c107deb760d87b3120608" -and
    [string]$r23d10StageZeroExtension.scope -ceq
        "prospective_r23d10_source_family_only" -and
    [int]$r23d10StageZeroExtension.added_rule_count -eq 10 -and
    -not [bool]$r23d10StageZeroExtension.ambient_rule_changed -and
    -not [bool]$r23d10StageZeroExtension.historical_path_rule_changed -and
    -not [bool]$r23d10StageZeroExtension.renormalization_executed -and
    -not [bool]$r23d10StageZeroExtension.checkout_filter_migration_executed -and
    $r23d10StageZeroDiff.Contains("+sdk/turning/r23d10_* text eol=lf") -and
    $r23d10StageZeroDiff.Contains("+sdk/adapters/mujoco/test_qsdk_r23d10_*.py text eol=lf") -and
    [string]$r23d10StageOneExtension.commit -ceq
        "60f475352fde6958798b4a0d7c21fb0dc354f87b" -and
    [string]$r23d10StageOneExtension.parent_commit -ceq
        "6b39e1df77a403d474924d203ab706f8fa495687" -and
    [string]$r23d10StageOneExtension.scope -ceq
        "prospective_r23d10_godot_native_source_only" -and
    [int]$r23d10StageOneExtension.added_rule_count -eq 1 -and
    -not [bool]$r23d10StageOneExtension.ambient_rule_changed -and
    -not [bool]$r23d10StageOneExtension.historical_path_rule_changed -and
    -not [bool]$r23d10StageOneExtension.renormalization_executed -and
    -not [bool]$r23d10StageOneExtension.checkout_filter_migration_executed -and
    $r23d10StageOneDiff.Contains("+scripts/lab/gait/sdk_godot_jolt_quiescent_taper.gd text eol=lf") -and
    [string]$r23d11StageZeroExtension.commit -ceq
        "40ebd67d3a1936be23a9ee6d1a6761e931dfb5d8" -and
    [string]$r23d11StageZeroExtension.parent_commit -ceq
        "71da97b50731d995bbf79c945736a6d5129b2404" -and
    [string]$r23d11StageZeroExtension.scope -ceq
        "prospective_r23d11_source_family_only" -and
    [int]$r23d11StageZeroExtension.added_rule_count -eq 11 -and
    -not [bool]$r23d11StageZeroExtension.ambient_rule_changed -and
    -not [bool]$r23d11StageZeroExtension.historical_path_rule_changed -and
    -not [bool]$r23d11StageZeroExtension.renormalization_executed -and
    -not [bool]$r23d11StageZeroExtension.checkout_filter_migration_executed -and
    $r23d11StageZeroDiff.Contains("+sdk/turning/r23d11_* text eol=lf") -and
    $r23d11StageZeroDiff.Contains("+sdk/adapters/mujoco/test_qsdk_r23d11_*.py text eol=lf") -and
    -not $r23d11StageZeroDiff.Contains("+* text=auto") -and
    -not $r23d11StageZeroDiff.Contains("+* -text") -and
    [string]$r23d11StageOneExtension.commit -ceq
        "9686045903c3e6ccaf237276526c52c7862e67d2" -and
    [string]$r23d11StageOneExtension.parent_commit -ceq
        "40ebd67d3a1936be23a9ee6d1a6761e931dfb5d8" -and
    [string]$r23d11StageOneExtension.scope -ceq
        "prospective_r23d11_roadmap_authority_sources_only" -and
    [int]$r23d11StageOneExtension.added_rule_count -eq 3 -and
    -not [bool]$r23d11StageOneExtension.ambient_rule_changed -and
    -not [bool]$r23d11StageOneExtension.historical_path_rule_changed -and
    -not [bool]$r23d11StageOneExtension.renormalization_executed -and
    -not [bool]$r23d11StageOneExtension.checkout_filter_migration_executed -and
    $r23d11StageOneDiff.Contains("+docs/ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md text eol=lf") -and
    $r23d11StageOneDiff.Contains("+docs/SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md text eol=lf") -and
    [string]$r23d11StageTwoExtension.commit -ceq
        "166845a67ed0a166cff789b691c76173d85e796b" -and
    [string]$r23d11StageTwoExtension.parent_commit -ceq
        "9686045903c3e6ccaf237276526c52c7862e67d2" -and
    [string]$r23d11StageTwoExtension.scope -ceq
        "prospective_r23d11_stage_two_documentation_authorities_only" -and
    [int]$r23d11StageTwoExtension.added_rule_count -eq 2 -and
    -not [bool]$r23d11StageTwoExtension.ambient_rule_changed -and
    -not [bool]$r23d11StageTwoExtension.historical_path_rule_changed -and
    -not [bool]$r23d11StageTwoExtension.renormalization_executed -and
    -not [bool]$r23d11StageTwoExtension.checkout_filter_migration_executed -and
    $r23d11StageTwoDiff.Contains("+docs/README.md text eol=lf") -and
    $r23d11StageTwoDiff.Contains("+docs/LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md text eol=lf") -and
    [string]$latestExtension.commit -ceq
        "7093082481bfa6d82484b9d86d48ea09e1b4847e" -and
    [string]$latestExtension.parent_commit -ceq
        "a873b54ec60e3435c09714c09c78ba848cfa47d8" -and
    [string]$latestExtension.scope -ceq
        "prospective_r23d12_source_family_only" -and
    [int]$latestExtension.added_rule_count -eq 11 -and
    -not [bool]$latestExtension.ambient_rule_changed -and
    -not [bool]$latestExtension.historical_path_rule_changed -and
    -not [bool]$latestExtension.renormalization_executed -and
    -not [bool]$latestExtension.checkout_filter_migration_executed -and
    $latestDiff.Contains("+sdk/turning/r23d12_* text eol=lf") -and
    $latestDiff.Contains("+sdk/adapters/mujoco/test_qsdk_r23d12_*.py text eol=lf") -and
    -not $latestDiff.Contains("+* text=auto") -and
    -not $latestDiff.Contains("+* -text") -and
    [string]$r23d12StageThreeExtension.commit -ceq
        "188ea95202aa2308f6d897a1dcb7232204086380" -and
    [string]$r23d12StageThreeExtension.parent_commit -ceq
        "bf418e9db4cc0b08add0de1715173dfac595bcb5" -and
    [string]$r23d12StageThreeExtension.scope -ceq
        "prospective_r23d12_nested_rapier_physical_source_only" -and
    [string]$r23d12StageThreeExtension.path_rule -ceq
        "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d12_*.rs text eol=lf" -and
    [int]$r23d12StageThreeExtension.added_rule_count -eq 1 -and
    -not [bool]$r23d12StageThreeExtension.ambient_rule_changed -and
    -not [bool]$r23d12StageThreeExtension.historical_path_rule_changed -and
    -not [bool]$r23d12StageThreeExtension.renormalization_executed -and
    -not [bool]$r23d12StageThreeExtension.checkout_filter_migration_executed -and
    $r23d12StageThreeDiff.Contains(
        "+sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d12_*.rs text eol=lf"
    ) -and
    -not $r23d12StageThreeDiff.Contains("+* text=auto") -and
    -not $r23d12StageThreeDiff.Contains("+* -text") -and
    [string]$r23d13StageZeroExtension.commit -ceq
        "a0872c6da7758528325320ed9596c498c30be864" -and
    [string]$r23d13StageZeroExtension.parent_commit -ceq
        "e93ac8a42407926ff55fcde876402e68bfdf8038" -and
    [string]$r23d13StageZeroExtension.scope -ceq
        "prospective_r23d13_source_family_only" -and
    [int]$r23d13StageZeroExtension.added_rule_count -eq 13 -and
    -not [bool]$r23d13StageZeroExtension.ambient_rule_changed -and
    -not [bool]$r23d13StageZeroExtension.historical_path_rule_changed -and
    -not [bool]$r23d13StageZeroExtension.renormalization_executed -and
    -not [bool]$r23d13StageZeroExtension.checkout_filter_migration_executed -and
    $r23d13StageZeroDiff.Contains("+sdk/turning/r23d13_* text eol=lf") -and
    $r23d13StageZeroDiff.Contains(
        "+sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d13_*.rs text eol=lf"
    ) -and
    $r23d13StageZeroDiff.Contains(
        "+sdk/adapters/mujoco/test_qsdk_r23d13_*.py text eol=lf"
    ) -and
    -not $r23d13StageZeroDiff.Contains("+* text=auto") -and
    -not $r23d13StageZeroDiff.Contains("+* -text") -and
    [string]$conformanceProfilerExtension.commit -ceq
        "6be80ba81c25ed29bd2644fca5bb3c8dec4a6dc4" -and
    [string]$conformanceProfilerExtension.parent_commit -ceq
        "8878a464e3c43c56a4e9b82d5910b46b77521c46" -and
    [string]$conformanceProfilerExtension.scope -ceq
        "prospective_conformance_profiler_source_family_only" -and
    [int]$conformanceProfilerExtension.added_rule_count -eq 5 -and
    -not [bool]$conformanceProfilerExtension.ambient_rule_changed -and
    -not [bool]$conformanceProfilerExtension.historical_path_rule_changed -and
    -not [bool]$conformanceProfilerExtension.renormalization_executed -and
    -not [bool]$conformanceProfilerExtension.checkout_filter_migration_executed -and
    $conformanceProfilerDiff.Contains("+sdk/conformance_audit_profiler_* text eol=lf") -and
    $conformanceProfilerDiff.Contains("+sdk/measure_conformance_audit_durations*.ps1 text eol=lf") -and
    $conformanceProfilerDiff.Contains("+sdk/run_conformance_audit_profiler*.ps1 text eol=lf") -and
    $conformanceProfilerDiff.Contains("+sdk/conformance_dependency_key.ps1 text eol=lf") -and
    $conformanceProfilerDiff.Contains("+tests/test_conformance_audit_profiler*.ps1 text eol=lf") -and
    -not $conformanceProfilerDiff.Contains("+* text=auto") -and
    -not $conformanceProfilerDiff.Contains("+* -text") -and
    [string]$transitiveHistoricalAuditExtension.commit -ceq
        "2890ce0e8ffdcd0cdf8e3493ed3574c03a9ed32e" -and
    [string]$transitiveHistoricalAuditExtension.parent_commit -ceq
        "f440791a3b42d9fe02f5127cd06647b0cae12416" -and
    [string]$transitiveHistoricalAuditExtension.scope -ceq
        "prospective_transitive_historical_audit_source_family_only" -and
    [int]$transitiveHistoricalAuditExtension.added_rule_count -eq 2 -and
    -not [bool]$transitiveHistoricalAuditExtension.ambient_rule_changed -and
    -not [bool]$transitiveHistoricalAuditExtension.historical_path_rule_changed -and
    -not [bool]$transitiveHistoricalAuditExtension.renormalization_executed -and
    -not [bool]$transitiveHistoricalAuditExtension.checkout_filter_migration_executed -and
    $transitiveHistoricalAuditDiff.Contains(
        "+sdk/conformance_transitive_historical_audit_* text eol=lf"
    ) -and
    $transitiveHistoricalAuditDiff.Contains(
        "+tests/test_conformance_transitive_historical_audit.ps1 text eol=lf"
    ) -and
    -not $transitiveHistoricalAuditDiff.Contains("+* text=auto") -and
    -not $transitiveHistoricalAuditDiff.Contains("+* -text") -and
    [string]$r23d14StageZeroExtension.commit -ceq
        "5cf482638e3c15c5ec051e3a4687e740ccd99dad" -and
    [string]$r23d14StageZeroExtension.parent_commit -ceq
        "ad34a258c101361a67f50becb2e3d3ed02c3e3b8" -and
    [string]$r23d14StageZeroExtension.scope -ceq
        "prospective_tight_first_development_and_r23d14_source_families_only" -and
    [int]$r23d14StageZeroExtension.added_rule_count -eq 17 -and
    -not [bool]$r23d14StageZeroExtension.ambient_rule_changed -and
    -not [bool]$r23d14StageZeroExtension.historical_path_rule_changed -and
    -not [bool]$r23d14StageZeroExtension.renormalization_executed -and
    -not [bool]$r23d14StageZeroExtension.checkout_filter_migration_executed -and
    $r23d14RequiredRules.Count -eq 17 -and
    $r23d14MissingDiffRules.Count -eq 0 -and
    $r23d14MissingLiveRules.Count -eq 0 -and
    -not $r23d14StageZeroDiff.Contains("+* text=auto") -and
    -not $r23d14StageZeroDiff.Contains("+* -text") -and
    [string]$r23d15StageZeroExtension.commit -ceq
        "51eb3d9f8ad6ef26d6e9859d8c8c9b7b93ca8cf3" -and
    [string]$r23d15StageZeroExtension.parent_commit -ceq
        "24ca52c4a2450184285f31e9f425155b4ae7b52e" -and
    [string]$r23d15StageZeroExtension.scope -ceq
        "prospective_r23d15_source_family_only" -and
    [int]$r23d15StageZeroExtension.added_rule_count -eq 12 -and
    -not [bool]$r23d15StageZeroExtension.ambient_rule_changed -and
    -not [bool]$r23d15StageZeroExtension.historical_path_rule_changed -and
    -not [bool]$r23d15StageZeroExtension.renormalization_executed -and
    -not [bool]$r23d15StageZeroExtension.checkout_filter_migration_executed -and
    $r23d15RequiredRules.Count -eq 12 -and
    $r23d15MissingDiffRules.Count -eq 0 -and
    $r23d15MissingLiveRules.Count -eq 0 -and
    -not $r23d15StageZeroDiff.Contains("+* text=auto") -and
    -not $r23d15StageZeroDiff.Contains("+* -text") -and
    [string]$r23d16Extension.commit -ceq
        "ad89cde1ac0edc0171337d84b047adba7336efb4" -and
    [string]$r23d16Extension.parent_commit -ceq
        "61d25cda35af4e55c94d54daf86c51a98129c0b9" -and
    [string]$r23d16Extension.scope -ceq
        "prospective_r23d16_source_family_only" -and
    [int]$r23d16Extension.added_rule_count -eq 12 -and
    -not [bool]$r23d16Extension.ambient_rule_changed -and
    -not [bool]$r23d16Extension.historical_path_rule_changed -and
    -not [bool]$r23d16Extension.renormalization_executed -and
    -not [bool]$r23d16Extension.checkout_filter_migration_executed -and
    $r23d16RequiredRules.Count -eq 12 -and
    $r23d16MissingDiffRules.Count -eq 0 -and
    $r23d16MissingLiveRules.Count -eq 0 -and
    -not $r23d16Diff.Contains("+* text=auto") -and
    -not $r23d16Diff.Contains("+* -text") -and
    [string]$r23d17Extension.commit -ceq
        "15625487b9631cd2a882d719d46957abc92eeade" -and
    [string]$r23d17Extension.parent_commit -ceq
        "64a543253fa2a0d89bfc2a6507b88152b854a44c" -and
    [string]$r23d17Extension.scope -ceq
        "prospective_r23d17_source_family_only" -and
    [int]$r23d17Extension.added_rule_count -eq 12 -and
    -not [bool]$r23d17Extension.ambient_rule_changed -and
    -not [bool]$r23d17Extension.historical_path_rule_changed -and
    -not [bool]$r23d17Extension.renormalization_executed -and
    -not [bool]$r23d17Extension.checkout_filter_migration_executed -and
    $r23d17RequiredRules.Count -eq 12 -and
    $r23d17MissingDiffRules.Count -eq 0 -and
    $r23d17MissingLiveRules.Count -eq 0 -and
    -not $r23d17Diff.Contains("+* text=auto") -and
    -not $r23d17Diff.Contains("+* -text") -and
    [string]$campaignAttestationExtension.commit -ceq
        "0ac42af3ef7bd67c8eba6f5f0244a5b50009d5db" -and
    [string]$campaignAttestationExtension.parent_commit -ceq
        "16f53bdd3238db948781352a57e1c908518542ad" -and
    [string]$campaignAttestationExtension.scope -ceq
        "prospective_lca1_campaign_attestation_source_family_only" -and
    [int]$campaignAttestationExtension.added_rule_count -eq 4 -and
    -not [bool]$campaignAttestationExtension.ambient_rule_changed -and
    -not [bool]$campaignAttestationExtension.historical_path_rule_changed -and
    -not [bool]$campaignAttestationExtension.renormalization_executed -and
    -not [bool]$campaignAttestationExtension.checkout_filter_migration_executed -and
    $campaignAttestationRequiredRules.Count -eq 4 -and
    $campaignAttestationMissingDiffRules.Count -eq 0 -and
    $campaignAttestationMissingLiveRules.Count -eq 0 -and
    -not $campaignAttestationDiff.Contains("+* text=auto") -and
    -not $campaignAttestationDiff.Contains("+* -text") -and
    [string]$r23d19InheritedGodotExtension.commit -ceq
        "0cb07bd11c1ae192912cdee8484d9fe52d9304b5" -and
    [string]$r23d19InheritedGodotExtension.parent_commit -ceq
        "812ca22af7ca0c38a0b01e7b69a44470363c7252" -and
    [string]$r23d19InheritedGodotExtension.scope -ceq
        "prospective_r23d19_inherited_godot_source_inputs_only" -and
    [int]$r23d19InheritedGodotExtension.added_rule_count -eq 3 -and
    -not [bool]$r23d19InheritedGodotExtension.ambient_rule_changed -and
    -not [bool]$r23d19InheritedGodotExtension.historical_path_rule_changed -and
    -not [bool]$r23d19InheritedGodotExtension.renormalization_executed -and
    -not [bool]$r23d19InheritedGodotExtension.checkout_filter_migration_executed -and
    $r23d19InheritedGodotRequiredRules.Count -eq 3 -and
    $r23d19InheritedGodotMissingDiffRules.Count -eq 0 -and
    $r23d19InheritedGodotMissingLiveRules.Count -eq 0 -and
    -not $r23d19InheritedGodotDiff.Contains("+* text=auto") -and
    -not $r23d19InheritedGodotDiff.Contains("+* -text") -and
    [string]$r23d20Extension.commit -ceq
        "d60c9a463b949591eacc5dc175944d8e2e28e867" -and
    [string]$r23d20Extension.parent_commit -ceq
        "a8a1e7c8d899b8d0c322e7e97dd6164466147add" -and
    [string]$r23d20Extension.scope -ceq
        "prospective_r23d20_source_family_only" -and
    [int]$r23d20Extension.added_rule_count -eq 6 -and
    -not [bool]$r23d20Extension.ambient_rule_changed -and
    -not [bool]$r23d20Extension.historical_path_rule_changed -and
    -not [bool]$r23d20Extension.renormalization_executed -and
    -not [bool]$r23d20Extension.checkout_filter_migration_executed -and
    $r23d20RequiredRules.Count -eq 6 -and
    $r23d20MissingDiffRules.Count -eq 0 -and
    $r23d20MissingLiveRules.Count -eq 0 -and
    -not $r23d20Diff.Contains("+* text=auto") -and
    -not $r23d20Diff.Contains("+* -text") -and
    [string]$r23d21Extension.commit -ceq
        "d754a2c617afabec818af081e5c9fad1e8288033" -and
    [string]$r23d21Extension.parent_commit -ceq
        "56bdd0e1923aaa16afdfb8159d4bacb1b8a8e130" -and
    [string]$r23d21Extension.scope -ceq
        "prospective_r23d21_source_family_only" -and
    [int]$r23d21Extension.added_rule_count -eq 6 -and
    -not [bool]$r23d21Extension.ambient_rule_changed -and
    -not [bool]$r23d21Extension.historical_path_rule_changed -and
    -not [bool]$r23d21Extension.renormalization_executed -and
    -not [bool]$r23d21Extension.checkout_filter_migration_executed -and
    $r23d21RequiredRules.Count -eq 6 -and
    $r23d21MissingDiffRules.Count -eq 0 -and
    $r23d21MissingLiveRules.Count -eq 0 -and
    -not $r23d21Diff.Contains("+* text=auto") -and
    -not $r23d21Diff.Contains("+* -text") -and
    [string]$r23d22Extension.commit -ceq
        "05b491c516b8ea1588629b4aebbb648eadf75af0" -and
    [string]$r23d22Extension.parent_commit -ceq
        "0401f3adc9caf07cf4be91d55ffeec73be8fe29b" -and
    [string]$r23d22Extension.scope -ceq
        "prospective_r23d22_source_family_only" -and
    [int]$r23d22Extension.added_rule_count -eq 10 -and
    -not [bool]$r23d22Extension.ambient_rule_changed -and
    -not [bool]$r23d22Extension.historical_path_rule_changed -and
    -not [bool]$r23d22Extension.renormalization_executed -and
    -not [bool]$r23d22Extension.checkout_filter_migration_executed -and
    $r23d22RequiredRules.Count -eq 10 -and
    $r23d22MissingDiffRules.Count -eq 0 -and
    $r23d22MissingLiveRules.Count -eq 0 -and
    -not $r23d22Diff.Contains("+* text=auto") -and
    -not $r23d22Diff.Contains("+* -text") -and
    [string]$r23d23Extension.commit -ceq
        "499782d27f061d7ccc577d1f006b99abd2a7e742" -and
    [string]$r23d23Extension.parent_commit -ceq
        "5d413b2b203b306c1e243706ce542a8710b23a20" -and
    [string]$r23d23Extension.scope -ceq
        "prospective_r23d23_source_family_only" -and
    [int]$r23d23Extension.added_rule_count -eq 10 -and
    -not [bool]$r23d23Extension.ambient_rule_changed -and
    -not [bool]$r23d23Extension.historical_path_rule_changed -and
    -not [bool]$r23d23Extension.renormalization_executed -and
    -not [bool]$r23d23Extension.checkout_filter_migration_executed -and
    $r23d23RequiredRules.Count -eq 10 -and
    $r23d23MissingDiffRules.Count -eq 0 -and
    $r23d23MissingLiveRules.Count -eq 0 -and
    -not $r23d23Diff.Contains("+* text=auto") -and
    -not $r23d23Diff.Contains("+* -text") -and
    [string]$r23d24Extension.declared_from_parent_commit -ceq
        "f8857f14ee9abb38a82e9de5fe2f0994a569aa79" -and
    [string]$r23d24Extension.scope -ceq
        "prospective_r23d24_source_family_only" -and
    [int]$r23d24Extension.added_rule_count -eq 5 -and
    -not [bool]$r23d24Extension.ambient_rule_changed -and
    -not [bool]$r23d24Extension.historical_path_rule_changed -and
    -not [bool]$r23d24Extension.renormalization_executed -and
    -not [bool]$r23d24Extension.checkout_filter_migration_executed -and
    $r23d24RequiredRules.Count -eq 5 -and
    $r23d24MissingDiffRules.Count -eq 0 -and
    $r23d24MissingLiveRules.Count -eq 0 -and
    -not $r23d24Diff.Contains("+* text=auto") -and
    -not $r23d24Diff.Contains("+* -text") -and
    [string]$r23d25Extension.declared_from_parent_commit -ceq
        "fa6a88dd5f4767e3ef0714ac331b02f4c7919ffe" -and
    [string]$r23d25Extension.scope -ceq
        "prospective_r23d25_source_family_only" -and
    [int]$r23d25Extension.added_rule_count -eq 5 -and
    -not [bool]$r23d25Extension.ambient_rule_changed -and
    -not [bool]$r23d25Extension.historical_path_rule_changed -and
    -not [bool]$r23d25Extension.renormalization_executed -and
    -not [bool]$r23d25Extension.checkout_filter_migration_executed -and
    $r23d25RequiredRules.Count -eq 5 -and
    $r23d25MissingDiffRules.Count -eq 0 -and
    $r23d25MissingLiveRules.Count -eq 0 -and
    -not $r23d25Diff.Contains("+* text=auto") -and
    -not $r23d25Diff.Contains("+* -text") -and
    [string]$r23d26Extension.declared_from_parent_commit -ceq
        "2cf13973f9c8c53798c239edffc983dda8240cd5" -and
    [string]$r23d26Extension.scope -ceq
        "prospective_r23d26_source_family_only" -and
    [int]$r23d26Extension.added_rule_count -eq 7 -and
    -not [bool]$r23d26Extension.ambient_rule_changed -and
    -not [bool]$r23d26Extension.historical_path_rule_changed -and
    -not [bool]$r23d26Extension.renormalization_executed -and
    -not [bool]$r23d26Extension.checkout_filter_migration_executed -and
    $r23d26RequiredRules.Count -eq 7 -and
    $r23d26MissingDiffRules.Count -eq 0 -and
    $r23d26MissingLiveRules.Count -eq 0 -and
    -not $r23d26Diff.Contains("+* text=auto") -and
    -not $r23d26Diff.Contains("+* -text") -and
    [string]$traceLineageExtension.declared_from_parent_commit -ceq
        "c5ef0edc82879547d0548c725b7846c9eccca8ec" -and
    [string]$traceLineageExtension.scope -ceq
        "prospective_retained_trace_lineage_analysis_source_family_only" -and
    [int]$traceLineageExtension.added_rule_count -eq 3 -and
    -not [bool]$traceLineageExtension.ambient_rule_changed -and
    -not [bool]$traceLineageExtension.historical_path_rule_changed -and
    -not [bool]$traceLineageExtension.renormalization_executed -and
    -not [bool]$traceLineageExtension.checkout_filter_migration_executed -and
    $traceLineageRequiredRules.Count -eq 3 -and
    $traceLineageMissingDiffRules.Count -eq 0 -and
    $traceLineageMissingLiveRules.Count -eq 0 -and
    -not $traceLineageDiff.Contains("+* text=auto") -and
    -not $traceLineageDiff.Contains("+* -text") -and
    [string]$r23d27Extension.declared_from_parent_commit -ceq
        "c7ae475dd1e70d4619c627d0610ba045e6830d08" -and
    [string]$r23d27Extension.scope -ceq
        "r23d27_stability_guarded_turning_validation_source_family_only" -and
    [int]$r23d27Extension.added_rule_count -eq 13 -and
    -not [bool]$r23d27Extension.ambient_rule_changed -and
    -not [bool]$r23d27Extension.historical_path_rule_changed -and
    -not [bool]$r23d27Extension.renormalization_executed -and
    -not [bool]$r23d27Extension.checkout_filter_migration_executed -and
    $r23d27RequiredRules.Count -eq 13 -and
    $r23d27MissingDiffRules.Count -eq 0 -and
    $r23d27MissingLiveRules.Count -eq 0 -and
    -not $r23d27Diff.Contains("+* text=auto") -and
    -not $r23d27Diff.Contains("+* -text") -and
    [string]$r23d28Extension.declared_from_parent_commit -ceq
        "012338ebce78d197fd648d190f1265b2cfa9cc3e" -and
    [string]$r23d28Extension.scope -ceq
        "prospective_r23d28_predictive_stability_guarded_turning_development_source_family_only" -and
    [int]$r23d28Extension.added_rule_count -eq 6 -and
    -not [bool]$r23d28Extension.ambient_rule_changed -and
    -not [bool]$r23d28Extension.historical_path_rule_changed -and
    -not [bool]$r23d28Extension.renormalization_executed -and
    -not [bool]$r23d28Extension.checkout_filter_migration_executed -and
    $r23d28RequiredRules.Count -eq 6 -and
    $r23d28MissingDiffRules.Count -eq 0 -and
    $r23d28MissingLiveRules.Count -eq 0 -and
    -not $r23d28Diff.Contains("+* text=auto") -and
    -not $r23d28Diff.Contains("+* -text") -and
    [string]$r23d29Extension.declared_from_parent_commit -ceq
        "b43d0ca9ed6a6d0a35e0322a3d42abba565b2396" -and
    [string]$r23d29Extension.scope -ceq
        "prospective_r23d29_two_swing_persistent_predictive_guard_development_source_family_only" -and
    [int]$r23d29Extension.added_rule_count -eq 6 -and
    -not [bool]$r23d29Extension.ambient_rule_changed -and
    -not [bool]$r23d29Extension.historical_path_rule_changed -and
    -not [bool]$r23d29Extension.renormalization_executed -and
    -not [bool]$r23d29Extension.checkout_filter_migration_executed -and
    $r23d29RequiredRules.Count -eq 6 -and
    $r23d29MissingDiffRules.Count -eq 0 -and
    $r23d29MissingLiveRules.Count -eq 0 -and
    -not $r23d29Diff.Contains("+* text=auto") -and
    -not $r23d29Diff.Contains("+* -text") -and
    [string]$r23d30Extension.declared_from_parent_commit -ceq
        "de03dc7979c7a3f5c0d6c01bef6ae32ed9d69000" -and
    [string]$r23d30Extension.scope -ceq
        "prospective_r23d30_cycle_coherent_response_measurement_validation_source_family_only" -and
    [int]$r23d30Extension.added_rule_count -eq 6 -and
    -not [bool]$r23d30Extension.ambient_rule_changed -and
    -not [bool]$r23d30Extension.historical_path_rule_changed -and
    -not [bool]$r23d30Extension.renormalization_executed -and
    -not [bool]$r23d30Extension.checkout_filter_migration_executed -and
    $r23d30RequiredRules.Count -eq 6 -and
    $r23d30MissingDiffRules.Count -eq 0 -and
    $r23d30MissingLiveRules.Count -eq 0 -and
    -not $r23d30Diff.Contains("+* text=auto") -and
    -not $r23d30Diff.Contains("+* -text") -and
    [string]$r23d31Extension.declared_from_parent_commit -ceq
        "491fa9f0a51a76aada7265034aad72db4cf230b3" -and
    [string]$r23d31Extension.scope -ceq
        "prospective_r23d31_cycle_integrated_response_measurement_validation_source_family_only" -and
    [int]$r23d31Extension.added_rule_count -eq 6 -and
    -not [bool]$r23d31Extension.ambient_rule_changed -and
    -not [bool]$r23d31Extension.historical_path_rule_changed -and
    -not [bool]$r23d31Extension.renormalization_executed -and
    -not [bool]$r23d31Extension.checkout_filter_migration_executed -and
    $r23d31RequiredRules.Count -eq 6 -and
    $r23d31MissingDiffRules.Count -eq 0 -and
    $r23d31MissingLiveRules.Count -eq 0 -and
    -not $r23d31Diff.Contains("+* text=auto") -and
    -not $r23d31Diff.Contains("+* -text") -and
    [string]$r23d32ClosureExtension.declared_from_parent_commit -ceq
        "d92ef53681071bb4f25c393dff69004b151901d2" -and
    [string]$r23d32ClosureExtension.scope -ceq
        "post_campaign_r23d32_closure_artifacts_created_after_physical_source_freeze_only" -and
    [int]$r23d32ClosureExtension.added_rule_count -eq 2 -and
    -not [bool]$r23d32ClosureExtension.executed_source_family_rule_changed -and
    -not [bool]$r23d32ClosureExtension.ambient_rule_changed -and
    -not [bool]$r23d32ClosureExtension.historical_path_rule_changed -and
    -not [bool]$r23d32ClosureExtension.renormalization_executed -and
    -not [bool]$r23d32ClosureExtension.checkout_filter_migration_executed -and
    $r23d32ClosureRequiredRules.Count -eq 2 -and
    $r23d32ClosureMissingDiffRules.Count -eq 0 -and
    $r23d32ClosureMissingLiveRules.Count -eq 0 -and
    -not $r23d32ClosureDiff.Contains("+* text=auto") -and
    -not $r23d32ClosureDiff.Contains("+* -text") -and
    [string]$r23d33Extension.declared_from_parent_commit -ceq
        "859aecd39e922a767d2e15766349ffa4e9cdb2b4" -and
    [string]$r23d33Extension.source_rule_commit -ceq
        "696abb9e50a7910fc8ddfae72d4eced513c54faf" -and
    [string]$r23d33Extension.scope -ceq
        "prospective_r23d33_native_two_engine_transfer_source_family_only" -and
    [int]$r23d33Extension.added_rule_count -eq 7 -and
    -not [bool]$r23d33Extension.ambient_rule_changed -and
    -not [bool]$r23d33Extension.historical_path_rule_changed -and
    -not [bool]$r23d33Extension.renormalization_executed -and
    -not [bool]$r23d33Extension.checkout_filter_migration_executed -and
    $r23d33RequiredRules.Count -eq 7 -and
    $r23d33MissingDiffRules.Count -eq 0 -and
    $r23d33MissingLiveRules.Count -eq 0 -and
    -not $r23d33Diff.Contains("+* text=auto") -and
    -not $r23d33Diff.Contains("+* -text") -and
    [string]$r23d34Extension.declared_from_parent_commit -ceq
        "b896dc8d268ce5ca7dfae47280f7e0b57e79ffe7" -and
    [string]$r23d34Extension.source_rule_commit -ceq
        "148eb2108ff2eb02e781b5933e06c1e75ea521db" -and
    [string]$r23d34Extension.scope -ceq
        "r23d34_source_and_closure_family_only_after_physical_closure" -and
    [int]$r23d34Extension.added_rule_count -eq 7 -and
    -not [bool]$r23d34Extension.executed_source_bytes_changed -and
    -not [bool]$r23d34Extension.ambient_rule_changed -and
    -not [bool]$r23d34Extension.historical_path_rule_changed -and
    -not [bool]$r23d34Extension.renormalization_executed -and
    -not [bool]$r23d34Extension.checkout_filter_migration_executed -and
    $r23d34RequiredRules.Count -eq 7 -and
    $r23d34MissingDiffRules.Count -eq 0 -and
    $r23d34MissingLiveRules.Count -eq 0 -and
    -not $r23d34Diff.Contains("+* text=auto") -and
    -not $r23d34Diff.Contains("+* -text") -and
    [string]$r23d35Extension.declared_from_parent_commit -ceq
        "887dfb4c3491871ba299bef2b9680cf6d1fbd2cc" -and
    [string]$r23d35Extension.scope -ceq
        "prospective_r23d35_godot_trace_recovery_source_family_only" -and
    [int]$r23d35Extension.added_rule_count -eq 6 -and
    -not [bool]$r23d35Extension.ambient_rule_changed -and
    -not [bool]$r23d35Extension.historical_path_rule_changed -and
    -not [bool]$r23d35Extension.renormalization_executed -and
    -not [bool]$r23d35Extension.checkout_filter_migration_executed -and
    $r23d35RequiredRules.Count -eq 6 -and
    $r23d35MissingDiffRules.Count -eq 0 -and
    $r23d35MissingLiveRules.Count -eq 0 -and
    -not $r23d35Diff.Contains("+* text=auto") -and
    -not $r23d35Diff.Contains("+* -text") -and
    [string]$r23d36Extension.declared_from_parent_commit -ceq
        "a73d5d08fd82332be89c0add9b5c71b169da40e8" -and
    [string]$r23d36Extension.source_rule_commit -ceq
        "6bbd3560fa80cd97c657d05a89e40ec492097f87" -and
    [string]$r23d36Extension.scope -ceq
        "prospective_r23d36_mujoco_bw19v_walking_restoration_source_family_only" -and
    [int]$r23d36Extension.added_rule_count -eq 4 -and
    -not [bool]$r23d36Extension.ambient_rule_changed -and
    -not [bool]$r23d36Extension.historical_path_rule_changed -and
    -not [bool]$r23d36Extension.renormalization_executed -and
    -not [bool]$r23d36Extension.checkout_filter_migration_executed -and
    $r23d36RequiredRules.Count -eq 4 -and
    $r23d36MissingDiffRules.Count -eq 0 -and
    $r23d36MissingLiveRules.Count -eq 0 -and
    -not $r23d36Diff.Contains("+* text=auto") -and
    -not $r23d36Diff.Contains("+* -text") -and
    $attributesText.Contains("sdk/turning/r23d9_* text eol=lf") -and
    $attributesText.Contains("sdk/adapters/mujoco/test_qsdk_r23d9_*.py text eol=lf") -and
    $attributesText.Contains("sdk/adapters/rapier/src/qsdk_r23d9_*.rs text eol=lf") -and
    $attributesText.Contains("scripts/lab/gait/sdk_godot_jolt_support_handoff.gd text eol=lf") -and
    $attributesText.Contains("sdk/turning/r23d10_* text eol=lf") -and
    $attributesText.Contains("scripts/lab/gait/sdk_godot_jolt_quiescent_taper.gd text eol=lf") -and
    $attributesText.Contains("sdk/turning/r23d11_* text eol=lf") -and
    $attributesText.Contains("sdk/turning/r23d12_* text eol=lf") -and
    $attributesText.Contains("sdk/turning/r23d13_* text eol=lf") -and
    $attributesText.Contains("sdk/adapters/mujoco/test_qsdk_r23d13_*.py text eol=lf") -and
    $attributesText.Contains(
        "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d12_*.rs text eol=lf"
    ) -and
    $attributesText.Contains("sdk/adapters/mujoco/test_qsdk_r23d12_*.py text eol=lf") -and
    $attributesText.Contains("docs/SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md text eol=lf") -and
    $attributesText.Contains("docs/LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md text eol=lf") -and
    $attributesText.Contains("sdk/conformance_audit_profiler_* text eol=lf") -and
    $attributesText.Contains("sdk/conformance_transitive_historical_audit_* text eol=lf") -and
    $attributesText.Contains("tests/test_conformance_transitive_historical_audit.ps1 text eol=lf") -and
    $attributesText.Contains("sdk/recovery/r24d3_* text eol=lf") -and
    $attributesText.Contains("sdk/run_qsdk_r24d3_* text eol=lf") -and
    $attributesText.Contains("sdk/adapters/godot/engine_patches/* text eol=lf") -and
    $attributesText.Contains("sdk/adapters/godot/engine_patches/*.patch whitespace=-blank-at-eol,-blank-at-eof,-space-before-tab") -and
    $attributesText.Contains("tests/test_qsdk_r24d3_* text eol=lf") -and
    $attributesText.Contains("tests/test_sdk_qsdk_r24d3_* text eol=lf") -and
    $attributesText.Contains("sdk/recovery/r24d4_* text eol=lf") -and
    $attributesText.Contains("sdk/run_qsdk_r24d4_* text eol=lf") -and
    $attributesText.Contains("scripts/lab/rigs/r24d4_* text eol=lf") -and
    $attributesText.Contains("tests/test_qsdk_r24d4_* text eol=lf") -and
    $attributesText.Contains("tests/test_sdk_qsdk_r24d4_* text eol=lf") -and
    $attributesText.Contains("sdk/recovery/r24d5_* text eol=lf") -and
    $attributesText.Contains("sdk/run_qsdk_r24d5_* text eol=lf") -and
    $attributesText.Contains("scripts/lab/rigs/r24d5_* text eol=lf") -and
    $attributesText.Contains("tests/test_qsdk_r24d5_* text eol=lf") -and
    $attributesText.Contains("tests/test_sdk_qsdk_r24d5_* text eol=lf") -and
    $attributesText.Contains("sdk/recovery/r24d6_* text eol=lf") -and
    $attributesText.Contains("sdk/run_qsdk_r24d6_* text eol=lf") -and
    $attributesText.Contains("scripts/lab/rigs/r24d6_* text eol=lf") -and
    $attributesText.Contains("tests/test_qsdk_r24d6_* text eol=lf") -and
    $attributesText.Contains("tests/test_sdk_qsdk_r24d6_* text eol=lf") -and
    $attributesText.Contains("sdk/recovery/r24d7_* text eol=lf") -and
    $attributesText.Contains("sdk/run_qsdk_r24d7_* text eol=lf") -and
    $attributesText.Contains("scripts/lab/rigs/r24d7_* text eol=lf") -and
    $attributesText.Contains("tests/test_qsdk_r24d7_* text eol=lf") -and
    $attributesText.Contains("tests/test_sdk_qsdk_r24d7_* text eol=lf") -and
    $attributesText.Contains("sdk/recovery/r24d8_* text eol=lf") -and
    $attributesText.Contains("sdk/run_qsdk_r24d8_* text eol=lf") -and
    $attributesText.Contains("scripts/lab/rigs/r24d8_* text eol=lf") -and
    $attributesText.Contains("tests/test_qsdk_r24d8_* text eol=lf") -and
    $attributesText.Contains("tests/test_sdk_qsdk_r24d8_* text eol=lf") -and
    $attributesText.Contains("sdk/adapters/godot/engine_patches/godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch text eol=lf") -and
    $attributesText.Contains("sdk/recovery/r24d9_* text eol=lf") -and
    $attributesText.Contains("sdk/run_qsdk_r24d9_* text eol=lf") -and
    $attributesText.Contains("scripts/lab/rigs/r24d9_* text eol=lf") -and
    $attributesText.Contains("tests/test_qsdk_r24d9_* text eol=lf") -and
    $attributesText.Contains("tests/test_sdk_qsdk_r24d9_* text eol=lf") -and
    [bool]$contract.checkout_filter_migration.bare_filter_flip_forbidden -and
    $attributesText.Contains("* text=auto") -and
    -not $attributesText.Contains("* -text") -and
    -not [bool]$contract.checkout_filter_migration.migration_authorized_by_this_contract
) "Checkout-filter migration moved without its distinct provenance boundary"

Assert-Exact (
    [string]$inventory.schema_version -ceq
        "sporespore_closure_evidence_mode_inventory_v1" -and
    [string]$inventory.analyzer_version -ceq
        "sporespore_closure_evidence_mode_static_analyzer_v2" -and
    [int]$inventory.audit_count -eq [int]$contract.inventory.baseline_audit_count -and
    [int]$inventory.cas_path_check_signature_count -eq
        [int]$contract.inventory.baseline_cas_path_check_signature_count -and
    [int]$inventory.pinned_git_blob_signature_count -eq
        [int]$contract.inventory.baseline_pinned_git_blob_signature_count -and
    [int]$inventory.reconstructed_checkout_signature_count -eq
        [int]$contract.inventory.baseline_reconstructed_checkout_signature_count -and
    [int]$inventory.live_historical_identity_risk_count -eq
        [int]$contract.inventory.baseline_live_historical_identity_risk_count -and
    [int]$inventory.manual_review_required_count -eq
        [int]$contract.inventory.baseline_manual_review_required_count -and
    [int]$inventory.world_build_count -eq 0 -and
    -not [bool]$inventory.historical_campaign_reclassification_authorized -and
    -not [bool]$inventory.physical_execution_authorized -and
    -not [bool]$inventory.physical_acceptance_authority
) "Closure evidence-mode inventory summary changed"

$actualLegacyRisks = @(
    $inventory.entries |
        Where-Object { [bool]$_.live_historical_identity_risk } |
        ForEach-Object { [string]$_.path } |
        Sort-Object
)
$declaredLegacyRisks = @(
    $contract.inventory.legacy_live_path_exception_paths |
        ForEach-Object { [string]$_ } |
        Sort-Object
)
Assert-Exact (
    ($actualLegacyRisks -join "|") -ceq ($declaredLegacyRisks -join "|") -and
    [bool]$contract.inventory.new_live_path_risk_not_in_legacy_exception_list_is_forbidden -and
    [bool]$contract.inventory.legacy_exception_count_may_decrease_but_may_not_increase
) "Closure evidence-mode live-path exception inventory changed"

$mv5 = @($inventory.entries | Where-Object {
    [string]$_.path -ceq
        "tests/test_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv5_closure.ps1"
})
$mv6 = @($inventory.entries | Where-Object {
    [string]$_.path -ceq
        "tests/test_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_closure.ps1"
})
$r23d13StageZero = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d13_stage_zero_closure.ps1"
})
$r23d13StageOne = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d13_stage_one_closure.ps1"
})
$r23d13StageTwo = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d13_stage_two_closure.ps1"
})
$r23d13Physical = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d13_closure.ps1"
})
$r23d14StageZero = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d14_stage_zero_closure.ps1"
})
$r23d14StageOne = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d14_stage_one_closure.ps1"
})
$r23d15StageZero = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d15_stage_zero_closure.ps1"
})
$r23d15StageOne = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d15_stage_one_closure.ps1"
})
$r23d15StageTwo = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d15_stage_two_closure.ps1"
})
$r23d17Physical = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d17_closure.ps1"
})
$r23d18Physical = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d18_closure.ps1"
})
$r23d19Physical = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d19_closure.ps1"
})
$r23d23Physical = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d23_closure.ps1"
})
$r23d23Postclosure = @($inventory.entries | Where-Object {
    [string]$_.path -ceq
        "tests/test_qsdk_r23d23_postclosure_forward_receipt_compatibility.ps1"
})
$r23d24Physical = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d24_closure.ps1"
})
$r23d25Physical = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d25_closure.ps1"
})
$r23d26Physical = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d26_closure.ps1"
})
$r23d27Physical = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d27_closure.ps1"
})
$r23d27PredictiveTiltDiagnosis = @($inventory.entries | Where-Object {
    [string]$_.path -ceq
        "tests/test_qsdk_r23d27_predictive_tilt_diagnosis_closure.ps1"
})
$r23d28Physical = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d28_closure.ps1"
})
$r23d28AuthorityPersistenceDiagnosis = @($inventory.entries | Where-Object {
    [string]$_.path -ceq
        "tests/test_qsdk_r23d28_authority_persistence_diagnosis_closure.ps1"
})
$r23d29Physical = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d29_closure.ps1"
})
$r23d29DirectionalResponseDiagnosis = @($inventory.entries | Where-Object {
    [string]$_.path -ceq
        "tests/test_qsdk_r23d29_directional_response_diagnosis_closure.ps1"
})
$r23d30Physical = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d30_closure.ps1"
})
$r23d31Physical = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d31_closure.ps1"
})
$r23d32Physical = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d32_closure.ps1"
})
$r23d43Physical = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d43_closure.ps1"
})
$r23d53Physical = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d53_closure.ps1"
})
$r23d54Physical = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d54_closure.ps1"
})
$r23d56Physical = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d56_closure.ps1"
})
$r23d57TransportClosure = @($inventory.entries | Where-Object {
    [string]$_.path -ceq
        "tests/test_qsdk_r23d57_godot_full_precision_trace_transport_closure.ps1"
})
$r23d57Physical = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d57_physical_closure.ps1"
})
$r23d58Physical = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d58_physical_closure.ps1"
})
$r23d59DependencyClosure = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d59_dependency_closure.ps1"
})
$r23d59Physical = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d59_physical_closure.ps1"
})
$r23d60DependencyClosure = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d60_dependency_closure.ps1"
})
$r23d60Physical = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d60_physical_closure.ps1"
})
$r23d61PublicationClosure = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d61_publication_closure.ps1"
})
$r23d62DependencyClosure = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d62_dependency_closure.ps1"
})
$r24d4ZeroWorldFailureClosure = @($inventory.entries | Where-Object {
    [string]$_.path -ceq
        "tests/test_qsdk_r24d4_one_hinge_telemetry_zero_world_failure_closure.ps1"
})
$r24d5PhysicalFailureClosure = @($inventory.entries | Where-Object {
    [string]$_.path -ceq
        "tests/test_qsdk_r24d5_one_hinge_telemetry_physical_failure_closure.ps1"
})
$r24d6ZeroWorldFailureClosure = @($inventory.entries | Where-Object {
    [string]$_.path -ceq
        "tests/test_qsdk_r24d6_one_hinge_telemetry_zero_world_failure_closure.ps1"
})
$r24d7PhysicalFailureClosure = @($inventory.entries | Where-Object {
    [string]$_.path -ceq
        "tests/test_qsdk_r24d7_one_hinge_telemetry_physical_failure_closure.ps1"
})
$r24d8PositiveClosure = @($inventory.entries | Where-Object {
    [string]$_.path -ceq
        "tests/test_qsdk_r24d8_active_step_snapshot_timing_positive_closure.ps1"
})
$r24d9PhysicalFailureClosure = @($inventory.entries | Where-Object {
    [string]$_.path -ceq
        "tests/test_qsdk_r24d9_one_hinge_numerical_telemetry_physical_failure_closure.ps1"
})
$lca1Commissioning = @($inventory.entries | Where-Object {
    [string]$_.path -ceq
        "tests/test_locomotion_campaign_attestation_v1_commissioning_closure.ps1"
})
$lca1ReusableRecommissioning = @($inventory.entries | Where-Object {
    [string]$_.path -ceq
        "tests/test_locomotion_campaign_attestation_recommissioning_closure.ps1"
})
$tightFirstDevelopment = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_terminal_tight_first_development_closure.ps1"
})
$tightFirstHorizonDevelopment = @($inventory.entries | Where-Object {
    [string]$_.path -ceq
        "tests/test_terminal_tight_first_horizon_development_closure.ps1"
})
Assert-Exact (
    $mv5.Count -eq 1 -and
    $mv6.Count -eq 1 -and
    [string]$mv5[0].historical_identity_mode -ceq
        "pinned_git_blob_with_checkout_reconstruction" -and
    [string]$mv6[0].historical_identity_mode -ceq
        "pinned_git_blob_with_checkout_reconstruction" -and
    -not [bool]$mv5[0].live_historical_identity_risk -and
    -not [bool]$mv6[0].live_historical_identity_risk -and
    [int]$contract.known_legacy_findings.mv5.unretained_mixed_line_ending_checkout_byte_receipt_count -eq 1 -and
    [int]$contract.known_legacy_findings.mv6.unretained_generated_artifact_count -eq 1 -and
    [bool]$contract.known_legacy_findings.mv6.wrb1_artifact_substitution_forbidden -and
    [bool]$contract.known_legacy_findings.mv6.frozen_evaluator_replay_forbidden_while_historical_dll_is_unretained -and
    [bool]$contract.known_legacy_findings.mv6.independent_retained_trace_replay_still_required
) "MV5 or MV6 evidence-mode repair boundary changed"
Assert-Exact (
    $r23d13StageZero.Count -eq 1 -and
    [string]$r23d13StageZero[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d13StageZero[0].detected_modes) -ccontains "pinned_git_blob" -and
    -not [bool]$r23d13StageZero[0].live_historical_identity_risk -and
    -not [bool]$r23d13StageZero[0].manual_review_required
) "R23D13 stage-zero closure provenance classification changed"
Assert-Exact (
    $r23d13StageOne.Count -eq 1 -and
    [string]$r23d13StageOne[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d13StageOne[0].detected_modes) -ccontains "pinned_git_blob" -and
    -not [bool]$r23d13StageOne[0].live_historical_identity_risk -and
    -not [bool]$r23d13StageOne[0].manual_review_required
) "R23D13 stage-one closure provenance classification changed"
Assert-Exact (
    $r23d13StageTwo.Count -eq 1 -and
    [string]$r23d13StageTwo[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d13StageTwo[0].detected_modes) -ccontains "cas_path_check" -and
    @($r23d13StageTwo[0].detected_modes) -ccontains "pinned_git_blob" -and
    -not [bool]$r23d13StageTwo[0].live_historical_identity_risk -and
    -not [bool]$r23d13StageTwo[0].manual_review_required
) "R23D13 stage-two closure provenance classification changed"
Assert-Exact (
    $r23d13Physical.Count -eq 1 -and
    [string]$r23d13Physical[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d13Physical[0].detected_modes) -ccontains "cas_path_check" -and
    @($r23d13Physical[0].detected_modes) -ccontains "pinned_git_blob" -and
    @($r23d13Physical[0].detected_modes) -ccontains "retained_evidence_bytes" -and
    @($r23d13Physical[0].detected_modes) -ccontains "live_runtime_safety_check" -and
    -not [bool]$r23d13Physical[0].live_historical_identity_risk -and
    -not [bool]$r23d13Physical[0].manual_review_required
) "R23D13 physical closure provenance classification changed"
Assert-Exact (
    $r23d14StageZero.Count -eq 1 -and
    [string]$r23d14StageZero[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d14StageZero[0].detected_modes) -ccontains "pinned_git_blob" -and
    -not [bool]$r23d14StageZero[0].live_historical_identity_risk -and
    -not [bool]$r23d14StageZero[0].manual_review_required -and
    $r23d14StageOne.Count -eq 1 -and
    [string]$r23d14StageOne[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d14StageOne[0].detected_modes) -ccontains "pinned_git_blob" -and
    -not [bool]$r23d14StageOne[0].live_historical_identity_risk -and
    -not [bool]$r23d14StageOne[0].manual_review_required -and
    $tightFirstDevelopment.Count -eq 1 -and
    $tightFirstHorizonDevelopment.Count -eq 1 -and
    [string]$tightFirstDevelopment[0].historical_identity_mode -ceq
        "record_retained_evidence_or_manual_review" -and
    [string]$tightFirstHorizonDevelopment[0].historical_identity_mode -ceq
        "record_retained_evidence_or_manual_review" -and
    -not [bool]$tightFirstDevelopment[0].live_historical_identity_risk -and
    -not [bool]$tightFirstHorizonDevelopment[0].live_historical_identity_risk -and
    [bool]$tightFirstDevelopment[0].manual_review_required -and
    [bool]$tightFirstHorizonDevelopment[0].manual_review_required
) "R23D14 or tight-first development closure provenance classification changed"
Assert-Exact (
    $r23d15StageZero.Count -eq 1 -and
    [string]$r23d15StageZero[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d15StageZero[0].detected_modes) -ccontains "pinned_git_blob" -and
    -not [bool]$r23d15StageZero[0].live_historical_identity_risk -and
    -not [bool]$r23d15StageZero[0].manual_review_required -and
    $r23d15StageOne.Count -eq 1 -and
    [string]$r23d15StageOne[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d15StageOne[0].detected_modes) -ccontains "pinned_git_blob" -and
    @($r23d15StageOne[0].detected_modes) -ccontains "cas_path_check" -and
    -not [bool]$r23d15StageOne[0].live_historical_identity_risk -and
    -not [bool]$r23d15StageOne[0].manual_review_required -and
    $r23d15StageTwo.Count -eq 1 -and
    [string]$r23d15StageTwo[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d15StageTwo[0].detected_modes) -ccontains "cas_path_check" -and
    @($r23d15StageTwo[0].detected_modes) -ccontains "pinned_git_blob" -and
    -not [bool]$r23d15StageTwo[0].live_historical_identity_risk -and
    -not [bool]$r23d15StageTwo[0].manual_review_required
) "R23D15 stage-zero, stage-one, or stage-two closure provenance classification changed"
Assert-Exact (
    $r23d17Physical.Count -eq 1 -and
    [string]$r23d17Physical[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d17Physical[0].detected_modes) -ccontains "cas_path_check" -and
    @($r23d17Physical[0].detected_modes) -ccontains "pinned_git_blob" -and
    @($r23d17Physical[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    @($r23d17Physical[0].detected_modes) -ccontains
        "live_runtime_safety_check" -and
    -not [bool]$r23d17Physical[0].live_historical_identity_risk -and
    -not [bool]$r23d17Physical[0].manual_review_required
) "R23D17 physical closure provenance classification changed"
Assert-Exact (
    $r23d18Physical.Count -eq 1 -and
    [string]$r23d18Physical[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d18Physical[0].detected_modes) -ccontains "cas_path_check" -and
    @($r23d18Physical[0].detected_modes) -ccontains "pinned_git_blob" -and
    @($r23d18Physical[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    @($r23d18Physical[0].detected_modes) -ccontains
        "live_runtime_safety_check" -and
    -not [bool]$r23d18Physical[0].live_historical_identity_risk -and
    -not [bool]$r23d18Physical[0].manual_review_required
) "R23D18 physical closure provenance classification changed"
Assert-Exact (
    $r23d19Physical.Count -eq 1 -and
    [string]$r23d19Physical[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d19Physical[0].detected_modes) -ccontains "cas_path_check" -and
    @($r23d19Physical[0].detected_modes) -ccontains "pinned_git_blob" -and
    @($r23d19Physical[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    -not [bool]$r23d19Physical[0].live_historical_identity_risk -and
    -not [bool]$r23d19Physical[0].manual_review_required
) "R23D19 physical closure provenance classification changed"
Assert-Exact (
    $r23d23Physical.Count -eq 1 -and
    [string]$r23d23Physical[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d23Physical[0].detected_modes) -ccontains "cas_path_check" -and
    @($r23d23Physical[0].detected_modes) -ccontains "pinned_git_blob" -and
    @($r23d23Physical[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    @($r23d23Physical[0].detected_modes) -ccontains
        "live_runtime_safety_check" -and
    -not [bool]$r23d23Physical[0].live_historical_identity_risk -and
    -not [bool]$r23d23Physical[0].manual_review_required
) "R23D23 physical closure provenance classification changed"
Assert-Exact (
    $r23d23Postclosure.Count -eq 1 -and
    [string]$r23d23Postclosure[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d23Postclosure[0].detected_modes) -ccontains "pinned_git_blob" -and
    @($r23d23Postclosure[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    -not [bool]$r23d23Postclosure[0].live_historical_identity_risk -and
    -not [bool]$r23d23Postclosure[0].manual_review_required
) "R23D23 postclosure diagnosis provenance classification changed"
Assert-Exact (
    $r23d24Physical.Count -eq 1 -and
    [string]$r23d24Physical[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d24Physical[0].detected_modes) -ccontains "cas_path_check" -and
    @($r23d24Physical[0].detected_modes) -ccontains "pinned_git_blob" -and
    @($r23d24Physical[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    @($r23d24Physical[0].detected_modes) -ccontains
        "live_runtime_safety_check" -and
    -not [bool]$r23d24Physical[0].live_historical_identity_risk -and
    -not [bool]$r23d24Physical[0].manual_review_required
) "R23D24 physical closure provenance classification changed"
Assert-Exact (
    $r23d25Physical.Count -eq 1 -and
    [string]$r23d25Physical[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d25Physical[0].detected_modes) -ccontains "cas_path_check" -and
    @($r23d25Physical[0].detected_modes) -ccontains "pinned_git_blob" -and
    @($r23d25Physical[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    @($r23d25Physical[0].detected_modes) -ccontains
        "live_runtime_safety_check" -and
    -not [bool]$r23d25Physical[0].live_historical_identity_risk -and
    -not [bool]$r23d25Physical[0].manual_review_required
) "R23D25 physical closure provenance classification changed"
Assert-Exact (
    $r23d26Physical.Count -eq 1 -and
    [string]$r23d26Physical[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d26Physical[0].detected_modes) -ccontains "cas_path_check" -and
    @($r23d26Physical[0].detected_modes) -ccontains "pinned_git_blob" -and
    @($r23d26Physical[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    @($r23d26Physical[0].detected_modes) -ccontains
        "live_runtime_safety_check" -and
    -not [bool]$r23d26Physical[0].live_historical_identity_risk -and
    -not [bool]$r23d26Physical[0].manual_review_required
) "R23D26 physical closure provenance classification changed"
Assert-Exact (
    $r23d27Physical.Count -eq 1 -and
    [string]$r23d27Physical[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d27Physical[0].detected_modes) -ccontains "cas_path_check" -and
    @($r23d27Physical[0].detected_modes) -ccontains "pinned_git_blob" -and
    @($r23d27Physical[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    @($r23d27Physical[0].detected_modes) -ccontains
        "live_runtime_safety_check" -and
    -not [bool]$r23d27Physical[0].live_historical_identity_risk -and
    -not [bool]$r23d27Physical[0].manual_review_required
) "R23D27 physical closure provenance classification changed"
Assert-Exact (
    $r23d27PredictiveTiltDiagnosis.Count -eq 1 -and
    [string]$r23d27PredictiveTiltDiagnosis[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d27PredictiveTiltDiagnosis[0].detected_modes) -ccontains
        "cas_path_check" -and
    @($r23d27PredictiveTiltDiagnosis[0].detected_modes) -ccontains
        "pinned_git_blob" -and
    @($r23d27PredictiveTiltDiagnosis[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    -not [bool]$r23d27PredictiveTiltDiagnosis[0].live_historical_identity_risk -and
    -not [bool]$r23d27PredictiveTiltDiagnosis[0].manual_review_required
) "R23D27 predictive-tilt diagnosis closure provenance classification changed"
Assert-Exact (
    $r23d28Physical.Count -eq 1 -and
    [string]$r23d28Physical[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d28Physical[0].detected_modes) -ccontains "cas_path_check" -and
    @($r23d28Physical[0].detected_modes) -ccontains "pinned_git_blob" -and
    @($r23d28Physical[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    @($r23d28Physical[0].detected_modes) -ccontains
        "live_runtime_safety_check" -and
    -not [bool]$r23d28Physical[0].live_historical_identity_risk -and
    -not [bool]$r23d28Physical[0].manual_review_required
) "R23D28 physical closure provenance classification changed"
Assert-Exact (
    $r23d28AuthorityPersistenceDiagnosis.Count -eq 1 -and
    [string]$r23d28AuthorityPersistenceDiagnosis[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d28AuthorityPersistenceDiagnosis[0].detected_modes) -ccontains
        "cas_path_check" -and
    @($r23d28AuthorityPersistenceDiagnosis[0].detected_modes) -ccontains
        "pinned_git_blob" -and
    @($r23d28AuthorityPersistenceDiagnosis[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    -not [bool]$r23d28AuthorityPersistenceDiagnosis[0].live_historical_identity_risk -and
    -not [bool]$r23d28AuthorityPersistenceDiagnosis[0].manual_review_required
) "R23D28 authority-persistence diagnosis closure provenance classification changed"
Assert-Exact (
    $r23d29Physical.Count -eq 1 -and
    [string]$r23d29Physical[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d29Physical[0].detected_modes) -ccontains "cas_path_check" -and
    @($r23d29Physical[0].detected_modes) -ccontains "pinned_git_blob" -and
    @($r23d29Physical[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    @($r23d29Physical[0].detected_modes) -ccontains
        "live_runtime_safety_check" -and
    -not [bool]$r23d29Physical[0].live_historical_identity_risk -and
    -not [bool]$r23d29Physical[0].manual_review_required
) "R23D29 physical closure provenance classification changed"
Assert-Exact (
    $r23d29DirectionalResponseDiagnosis.Count -eq 1 -and
    [string]$r23d29DirectionalResponseDiagnosis[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d29DirectionalResponseDiagnosis[0].detected_modes) -ccontains
        "cas_path_check" -and
    @($r23d29DirectionalResponseDiagnosis[0].detected_modes) -ccontains
        "pinned_git_blob" -and
    @($r23d29DirectionalResponseDiagnosis[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    -not [bool]$r23d29DirectionalResponseDiagnosis[0].live_historical_identity_risk -and
    -not [bool]$r23d29DirectionalResponseDiagnosis[0].manual_review_required
) "R23D29 directional-response diagnosis closure provenance classification changed"
Assert-Exact (
    $r23d30Physical.Count -eq 1 -and
    [string]$r23d30Physical[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d30Physical[0].detected_modes) -ccontains "cas_path_check" -and
    @($r23d30Physical[0].detected_modes) -ccontains "pinned_git_blob" -and
    @($r23d30Physical[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    @($r23d30Physical[0].detected_modes) -ccontains
        "live_runtime_safety_check" -and
    -not [bool]$r23d30Physical[0].live_historical_identity_risk -and
    -not [bool]$r23d30Physical[0].manual_review_required
) "R23D30 physical closure provenance classification changed"
Assert-Exact (
    $r23d31Physical.Count -eq 1 -and
    [string]$r23d31Physical[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d31Physical[0].detected_modes) -ccontains "cas_path_check" -and
    @($r23d31Physical[0].detected_modes) -ccontains "pinned_git_blob" -and
    @($r23d31Physical[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    @($r23d31Physical[0].detected_modes) -ccontains
        "live_runtime_safety_check" -and
    -not [bool]$r23d31Physical[0].live_historical_identity_risk -and
    -not [bool]$r23d31Physical[0].manual_review_required
) "R23D31 physical closure provenance classification changed"
Assert-Exact (
    $r23d32Physical.Count -eq 1 -and
    [string]$r23d32Physical[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d32Physical[0].detected_modes) -ccontains "cas_path_check" -and
    @($r23d32Physical[0].detected_modes) -ccontains "pinned_git_blob" -and
    @($r23d32Physical[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    @($r23d32Physical[0].detected_modes) -ccontains
        "live_runtime_safety_check" -and
    -not [bool]$r23d32Physical[0].live_historical_identity_risk -and
    -not [bool]$r23d32Physical[0].manual_review_required
) "R23D32 physical closure provenance classification changed"
Assert-Exact (
    $r23d43Physical.Count -eq 1 -and
    [string]$r23d43Physical[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d43Physical[0].detected_modes) -ccontains "cas_path_check" -and
    @($r23d43Physical[0].detected_modes) -ccontains "pinned_git_blob" -and
    @($r23d43Physical[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    -not [bool]$r23d43Physical[0].live_historical_identity_risk -and
    -not [bool]$r23d43Physical[0].manual_review_required
) "R23D43 physical closure provenance classification changed"
Assert-Exact (
    $r23d53Physical.Count -eq 1 -and
    [string]$r23d53Physical[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d53Physical[0].detected_modes) -ccontains "cas_path_check" -and
    @($r23d53Physical[0].detected_modes) -ccontains "pinned_git_blob" -and
    @($r23d53Physical[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    -not [bool]$r23d53Physical[0].live_historical_identity_risk -and
    -not [bool]$r23d53Physical[0].manual_review_required
) "R23D53 physical closure provenance classification changed"
Assert-Exact (
    $r23d54Physical.Count -eq 1 -and
    [string]$r23d54Physical[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d54Physical[0].detected_modes) -ccontains "cas_path_check" -and
    @($r23d54Physical[0].detected_modes) -ccontains "pinned_git_blob" -and
    @($r23d54Physical[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    -not [bool]$r23d54Physical[0].live_historical_identity_risk -and
    -not [bool]$r23d54Physical[0].manual_review_required
) "R23D54 physical closure provenance classification changed"
Assert-Exact (
    $r23d56Physical.Count -eq 1 -and
    [string]$r23d56Physical[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d56Physical[0].detected_modes) -ccontains "cas_path_check" -and
    @($r23d56Physical[0].detected_modes) -ccontains "pinned_git_blob" -and
    @($r23d56Physical[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    -not [bool]$r23d56Physical[0].live_historical_identity_risk -and
    -not [bool]$r23d56Physical[0].manual_review_required -and
    [string]$contract.inventory.r23d56_closure_inventory_extension.declared_from_parent_commit -ceq
        "cedd787f548929c03e114d33f6cdf28c35e62b5f" -and
    [string]$contract.inventory.r23d56_closure_inventory_extension.scope -ceq
        "new_r23d56_immutable_physical_closure_audit_only" -and
    [bool]$contract.inventory.r23d56_closure_inventory_extension.initial_inventory_failure_observed -and
    [string]$contract.inventory.r23d56_closure_inventory_extension.initial_inventory_failure_message -ceq
        "Closure evidence-mode executable inventory verification failed" -and
    [int]$contract.inventory.r23d56_closure_inventory_extension.added_audit_count -eq 1 -and
    [int]$contract.inventory.r23d56_closure_inventory_extension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$contract.inventory.r23d56_closure_inventory_extension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$contract.inventory.r23d56_closure_inventory_extension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$contract.inventory.r23d56_closure_inventory_extension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$contract.inventory.r23d56_closure_inventory_extension.manual_review_required_count_delta -eq 0 -and
    -not [bool]$contract.inventory.r23d56_closure_inventory_extension.historical_campaign_reclassification_authorized -and
    [int]$contract.inventory.r23d56_closure_inventory_extension.maintenance_process_physical_world_count -eq 0 -and
    -not [bool]$contract.inventory.r23d56_closure_inventory_extension.physical_acceptance_authority
) "R23D56 physical closure provenance classification or inventory extension changed"
Assert-Exact (
    $r23d57TransportClosure.Count -eq 1 -and
    [string]$r23d57TransportClosure[0].raw_sha256 -ceq
        "9d320c532b60551652fe2aee04369c5f44106aeb0fa09c80b01cb67031da9970" -and
    [string]$r23d57TransportClosure[0].historical_identity_mode -ceq
        "pinned_git_blob_with_checkout_reconstruction" -and
    @($r23d57TransportClosure[0].detected_modes) -ccontains
        "pinned_git_blob" -and
    @($r23d57TransportClosure[0].detected_modes) -ccontains
        "reconstructed_checkout" -and
    @($r23d57TransportClosure[0].detected_modes) -ccontains
        "live_repo_or_checkout_hash" -and
    -not [bool]$r23d57TransportClosure[0].live_historical_identity_risk -and
    -not [bool]$r23d57TransportClosure[0].manual_review_required -and
    [string]$contract.inventory.r23d57_transport_closure_inventory_extension.declared_from_source_freeze_commit -ceq
        "95f6acf3d52bcaffda84833dc59d39a38f8c7f42" -and
    [string]$contract.inventory.r23d57_transport_closure_inventory_extension.scope -ceq
        "new_r23d57_zero_world_transport_closure_audit_only" -and
    [bool]$contract.inventory.r23d57_transport_closure_inventory_extension.initial_inventory_failure_observed -and
    [string]$contract.inventory.r23d57_transport_closure_inventory_extension.initial_inventory_failure_message -ceq
        "Closure evidence-mode executable inventory verification failed" -and
    [int]$contract.inventory.r23d57_transport_closure_inventory_extension.pre_extension_audit_count -eq 152 -and
    [int]$contract.inventory.r23d57_transport_closure_inventory_extension.post_extension_audit_count -eq 153 -and
    [int]$contract.inventory.r23d57_transport_closure_inventory_extension.added_audit_count -eq 1 -and
    [int]$contract.inventory.r23d57_transport_closure_inventory_extension.cas_path_check_signature_count_delta -eq 0 -and
    [int]$contract.inventory.r23d57_transport_closure_inventory_extension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$contract.inventory.r23d57_transport_closure_inventory_extension.reconstructed_checkout_signature_count_delta -eq 1 -and
    [int]$contract.inventory.r23d57_transport_closure_inventory_extension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$contract.inventory.r23d57_transport_closure_inventory_extension.manual_review_required_count_delta -eq 0 -and
    [string]$contract.inventory.r23d57_transport_closure_inventory_extension.new_audit_path -ceq
        "tests/test_qsdk_r23d57_godot_full_precision_trace_transport_closure.ps1" -and
    [string]$contract.inventory.r23d57_transport_closure_inventory_extension.new_audit_raw_sha256_at_initial_failure -ceq
        "4dc2eca01c0aae92e47dbb9a948c845de989a5b3711674e11ff8fb28ec5a3ee4" -and
    [string]$contract.inventory.r23d57_transport_closure_inventory_extension.adopted_new_audit_raw_sha256 -ceq
        "0e4523146cbe5ae78049ef36a1f291a9a59bbaa0b15eb9cfcca7a709eb4f4fb9" -and
    [string]$contract.inventory.r23d57_transport_closure_inventory_extension.historical_identity_mode_at_initial_failure -ceq
        "pinned_git_blob" -and
    (@($contract.inventory.r23d57_transport_closure_inventory_extension.detected_modes_at_initial_failure) -join "|") -ceq
        "pinned_git_blob|live_repo_or_checkout_hash" -and
    [string]$contract.inventory.r23d57_transport_closure_inventory_extension.adopted_historical_identity_mode -ceq
        "pinned_git_blob_with_checkout_reconstruction" -and
    (@($contract.inventory.r23d57_transport_closure_inventory_extension.adopted_detected_modes) -join "|") -ceq
        "pinned_git_blob|reconstructed_checkout|live_repo_or_checkout_hash" -and
    -not [bool]$contract.inventory.r23d57_transport_closure_inventory_extension.live_historical_identity_risk -and
    -not [bool]$contract.inventory.r23d57_transport_closure_inventory_extension.manual_review_required -and
    [bool]$contract.inventory.r23d57_transport_closure_inventory_extension.post_adoption_contract_test_failure_observed -and
    [string]$contract.inventory.r23d57_transport_closure_inventory_extension.post_adoption_contract_test_failure_message -ceq
        "R23D56 physical closure provenance classification or inventory extension changed" -and
    [string]$contract.inventory.r23d57_transport_closure_inventory_extension.post_adoption_contract_test_failure_root_cause -ceq
        "a_non_scoped_patch_changed_the_r23d56_reconstructed_checkout_delta_instead_of_the_r23d57_delta" -and
    [int]$contract.inventory.r23d57_transport_closure_inventory_extension.r23d56_reconstructed_checkout_delta_restored_to -eq 0 -and
    [int]$contract.inventory.r23d57_transport_closure_inventory_extension.r23d57_reconstructed_checkout_delta_corrected_to -eq 1 -and
    [int]$contract.inventory.r23d57_transport_closure_inventory_extension.post_adoption_failure_threshold_or_result_change_count -eq 0 -and
    [int]$contract.inventory.r23d57_transport_closure_inventory_extension.post_adoption_failure_physical_world_count -eq 0 -and
    -not [bool]$contract.inventory.r23d57_transport_closure_inventory_extension.historical_campaign_reclassification_authorized -and
    [int]$contract.inventory.r23d57_transport_closure_inventory_extension.threshold_or_result_change_count -eq 0 -and
    [int]$contract.inventory.r23d57_transport_closure_inventory_extension.maintenance_process_physical_world_count -eq 0 -and
    -not [bool]$contract.inventory.r23d57_transport_closure_inventory_extension.physical_acceptance_authority -and
    [string]$contract.inventory.r23d57_transport_closure_audit_compatibility_maintenance.declared_from_initial_closure_boundary_commit -ceq
        "7fbc2bf7e6194a8f7f98e42a157d9451bca3d53d" -and
    [string]$contract.inventory.r23d57_transport_closure_audit_compatibility_maintenance.scope -ceq
        "live_audit_compatibility_only_pinning_immutable_initial_audit" -and
    [string]$contract.inventory.r23d57_transport_closure_audit_compatibility_maintenance.audit_path -ceq
        "tests/test_qsdk_r23d57_godot_full_precision_trace_transport_closure.ps1" -and
    [string]$contract.inventory.r23d57_transport_closure_audit_compatibility_maintenance.initial_audit_raw_sha256 -ceq
        "0e4523146cbe5ae78049ef36a1f291a9a59bbaa0b15eb9cfcca7a709eb4f4fb9" -and
    [string]$contract.inventory.r23d57_transport_closure_audit_compatibility_maintenance.prior_compatibility_audit_raw_sha256 -ceq
        "12b8cc79d17ec4847b60b9c55e73836053524ceea8681b8d592174a18cd9dc62" -and
    [string]$contract.inventory.r23d57_transport_closure_audit_compatibility_maintenance.compatibility_audit_raw_sha256 -ceq
        "9d320c532b60551652fe2aee04369c5f44106aeb0fa09c80b01cb67031da9970" -and
    [bool]$contract.inventory.r23d57_transport_closure_audit_compatibility_maintenance.initial_audit_bytes_reconstructed_from_git_blob -and
    [bool]$contract.inventory.r23d57_transport_closure_audit_compatibility_maintenance.initial_audit_hash_reverified_by_compatibility_audit -and
    [string]$contract.inventory.r23d57_transport_closure_audit_compatibility_maintenance.immutable_transport_closure_raw_sha256 -ceq
        "92e903daa814e8ec243a75a9a7f33be4a4565cd9afab804e420d591a03b00b62" -and
    [bool]$contract.inventory.r23d57_transport_closure_audit_compatibility_maintenance.mutable_live_campaign_state_excluded_from_immutable_result_inputs -and
    [int]$contract.inventory.r23d57_transport_closure_audit_compatibility_maintenance.observed_transport_result_change_count -eq 0 -and
    [int]$contract.inventory.r23d57_transport_closure_audit_compatibility_maintenance.fixture_threshold_selector_or_evaluator_change_count -eq 0 -and
    -not [bool]$contract.inventory.r23d57_transport_closure_audit_compatibility_maintenance.historical_campaign_reclassification_authorized -and
    [int]$contract.inventory.r23d57_transport_closure_audit_compatibility_maintenance.maintenance_process_physical_world_count -eq 0 -and
    -not [bool]$contract.inventory.r23d57_transport_closure_audit_compatibility_maintenance.physical_acceptance_authority
) "R23D57 zero-world transport closure provenance classification or inventory extension changed"
Assert-Exact (
    $r23d57Physical.Count -eq 1 -and
    [string]$r23d57Physical[0].raw_sha256 -ceq
        "679b16191c210b68419501f22c8b8db433a60faf58b577e3bdcba0e1a7ce67cf" -and
    [string]$r23d57Physical[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    (@($r23d57Physical[0].detected_modes) -join "|") -ceq
        "cas_path_check|pinned_git_blob|retained_evidence_bytes|live_repo_or_checkout_hash" -and
    -not [bool]$r23d57Physical[0].live_historical_identity_risk -and
    -not [bool]$r23d57Physical[0].manual_review_required -and
    [string]$contract.inventory.r23d57_physical_closure_inventory_extension.declared_from_physical_source_commit -ceq
        "f0993e7e4886ff51254fb4de47f22a1bf0cc7ebe" -and
    [string]$contract.inventory.r23d57_physical_closure_inventory_extension.scope -ceq
        "new_r23d57_immutable_physical_closure_audit_only" -and
    [int]$contract.inventory.r23d57_physical_closure_inventory_extension.pre_extension_audit_count -eq 153 -and
    [int]$contract.inventory.r23d57_physical_closure_inventory_extension.post_extension_audit_count -eq 154 -and
    [int]$contract.inventory.r23d57_physical_closure_inventory_extension.added_audit_count -eq 1 -and
    [int]$contract.inventory.r23d57_physical_closure_inventory_extension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$contract.inventory.r23d57_physical_closure_inventory_extension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$contract.inventory.r23d57_physical_closure_inventory_extension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$contract.inventory.r23d57_physical_closure_inventory_extension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$contract.inventory.r23d57_physical_closure_inventory_extension.manual_review_required_count_delta -eq 0 -and
    [string]$contract.inventory.r23d57_physical_closure_inventory_extension.new_audit_path -ceq
        "tests/test_qsdk_r23d57_physical_closure.ps1" -and
    [string]$contract.inventory.r23d57_physical_closure_inventory_extension.new_audit_raw_sha256 -ceq
        "679b16191c210b68419501f22c8b8db433a60faf58b577e3bdcba0e1a7ce67cf" -and
    [int]$contract.inventory.r23d57_physical_closure_inventory_extension.retained_physical_world_count -eq 3 -and
    [int]$contract.inventory.r23d57_physical_closure_inventory_extension.maintenance_process_physical_world_count -eq 0 -and
    -not [bool]$contract.inventory.r23d57_physical_closure_inventory_extension.historical_campaign_reclassification_authorized -and
    -not [bool]$contract.inventory.r23d57_physical_closure_inventory_extension.live_historical_identity_risk -and
    -not [bool]$contract.inventory.r23d57_physical_closure_inventory_extension.manual_review_required -and
    -not [bool]$contract.inventory.r23d57_physical_closure_inventory_extension.physical_acceptance_authority
) "R23D57 physical closure provenance classification or inventory extension changed"
Assert-Exact (
    $r23d58Physical.Count -eq 1 -and
    [string]$r23d58Physical[0].raw_sha256 -ceq
        "4c06c990c35f3ea9babbc13efc1fb9da8bbcd5f4d19cd49adb9c785d85ce9ccd" -and
    [string]$r23d58Physical[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    (@($r23d58Physical[0].detected_modes) -join "|") -ceq
        "cas_path_check|pinned_git_blob|retained_evidence_bytes|live_repo_or_checkout_hash" -and
    -not [bool]$r23d58Physical[0].live_historical_identity_risk -and
    -not [bool]$r23d58Physical[0].manual_review_required -and
    [string]$contract.inventory.r23d58_physical_closure_inventory_extension.declared_from_physical_source_commit -ceq
        "ecfc191bcc97ea53b089e9862a5d0b5a7a8ad6b5" -and
    [string]$contract.inventory.r23d58_physical_closure_inventory_extension.scope -ceq
        "new_r23d58_immutable_physical_closure_audit_only" -and
    [int]$contract.inventory.r23d58_physical_closure_inventory_extension.pre_extension_audit_count -eq 154 -and
    [int]$contract.inventory.r23d58_physical_closure_inventory_extension.post_extension_audit_count -eq 155 -and
    [int]$contract.inventory.r23d58_physical_closure_inventory_extension.added_audit_count -eq 1 -and
    [int]$contract.inventory.r23d58_physical_closure_inventory_extension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$contract.inventory.r23d58_physical_closure_inventory_extension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$contract.inventory.r23d58_physical_closure_inventory_extension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$contract.inventory.r23d58_physical_closure_inventory_extension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$contract.inventory.r23d58_physical_closure_inventory_extension.manual_review_required_count_delta -eq 0 -and
    [string]$contract.inventory.r23d58_physical_closure_inventory_extension.new_audit_path -ceq
        "tests/test_qsdk_r23d58_physical_closure.ps1" -and
    [string]$contract.inventory.r23d58_physical_closure_inventory_extension.new_audit_raw_sha256 -ceq
        "4c06c990c35f3ea9babbc13efc1fb9da8bbcd5f4d19cd49adb9c785d85ce9ccd" -and
    [int]$contract.inventory.r23d58_physical_closure_inventory_extension.retained_physical_world_count -eq 4 -and
    [int]$contract.inventory.r23d58_physical_closure_inventory_extension.maintenance_process_physical_world_count -eq 0 -and
    [int]$contract.inventory.r23d58_physical_closure_inventory_extension.physical_freeze_explicit_source_binding_count -eq 87 -and
    [int]$contract.inventory.r23d58_physical_closure_inventory_extension.postclosure_detected_unbound_runtime_dependency_count -eq 4 -and
    -not [bool]$contract.inventory.r23d58_physical_closure_inventory_extension.prospective_explicit_dependency_inventory_complete -and
    [bool]$contract.inventory.r23d58_physical_closure_inventory_extension.full_clean_pushed_source_tree_identity_complete -and
    [bool]$contract.inventory.r23d58_physical_closure_inventory_extension.cold_evaluator_replay_passed_after_exact_git_blob_materialization -and
    -not [bool]$contract.inventory.r23d58_physical_closure_inventory_extension.result_payload_or_interpretation_changed -and
    -not [bool]$contract.inventory.r23d58_physical_closure_inventory_extension.result_reuse_authorized -and
    -not [bool]$contract.inventory.r23d58_physical_closure_inventory_extension.historical_campaign_reclassification_authorized -and
    -not [bool]$contract.inventory.r23d58_physical_closure_inventory_extension.live_historical_identity_risk -and
    -not [bool]$contract.inventory.r23d58_physical_closure_inventory_extension.manual_review_required -and
    -not [bool]$contract.inventory.r23d58_physical_closure_inventory_extension.physical_acceptance_authority
) "R23D58 physical closure provenance classification or inventory extension changed"
Assert-Exact (
    $r23d59DependencyClosure.Count -eq 1 -and
    [string]$r23d59DependencyClosure[0].raw_sha256 -ceq
        "b1645547a57d08d4f1df3d45e802d4c91f20702e6fe56b78474f2dc44a5c9e66" -and
    [string]$r23d59DependencyClosure[0].historical_identity_mode -ceq
        "record_retained_evidence_or_manual_review" -and
    (@($r23d59DependencyClosure[0].detected_modes) -join "|") -ceq
        "cas_path_check" -and
    -not [bool]$r23d59DependencyClosure[0].live_historical_identity_risk -and
    [bool]$r23d59DependencyClosure[0].manual_review_required -and
    [string]$contract.inventory.r23d59_dependency_closure_inventory_extension.declared_from_r23d59_preregistration_commit -ceq
        "63c927a92173aee953effd5a9c26dc5155a68fac" -and
    [string]$contract.inventory.r23d59_dependency_closure_inventory_extension.scope -ceq
        "new_r23d59_prospective_zero_world_dependency_closure_audit_only" -and
    [bool]$contract.inventory.r23d59_dependency_closure_inventory_extension.initial_inventory_failure_observed -and
    [string]$contract.inventory.r23d59_dependency_closure_inventory_extension.initial_inventory_failure_message -ceq
        "Closure evidence-mode executable inventory verification failed" -and
    [int]$contract.inventory.r23d59_dependency_closure_inventory_extension.pre_extension_audit_count -eq 155 -and
    [int]$contract.inventory.r23d59_dependency_closure_inventory_extension.post_extension_audit_count -eq 156 -and
    [int]$contract.inventory.r23d59_dependency_closure_inventory_extension.added_audit_count -eq 1 -and
    [int]$contract.inventory.r23d59_dependency_closure_inventory_extension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$contract.inventory.r23d59_dependency_closure_inventory_extension.pinned_git_blob_signature_count_delta -eq 0 -and
    [int]$contract.inventory.r23d59_dependency_closure_inventory_extension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$contract.inventory.r23d59_dependency_closure_inventory_extension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$contract.inventory.r23d59_dependency_closure_inventory_extension.manual_review_required_count_delta -eq 1 -and
    [string]$contract.inventory.r23d59_dependency_closure_inventory_extension.new_audit_path -ceq
        "tests/test_qsdk_r23d59_dependency_closure.ps1" -and
    [string]$contract.inventory.r23d59_dependency_closure_inventory_extension.new_audit_raw_sha256 -ceq
        "b1645547a57d08d4f1df3d45e802d4c91f20702e6fe56b78474f2dc44a5c9e66" -and
    [string]$contract.inventory.r23d59_dependency_closure_inventory_extension.historical_identity_mode -ceq
        "record_retained_evidence_or_manual_review" -and
    (@($contract.inventory.r23d59_dependency_closure_inventory_extension.detected_modes) -join "|") -ceq
        "cas_path_check" -and
    [string]$contract.inventory.r23d59_dependency_closure_inventory_extension.manual_review_disposition -ceq
        "prospective_dependency_omission_and_receipt_mutation_gate_not_a_historical_result_identity" -and
    -not [bool]$contract.inventory.r23d59_dependency_closure_inventory_extension.live_historical_identity_risk -and
    [bool]$contract.inventory.r23d59_dependency_closure_inventory_extension.manual_review_required -and
    -not [bool]$contract.inventory.r23d59_dependency_closure_inventory_extension.historical_campaign_reclassification_authorized -and
    [int]$contract.inventory.r23d59_dependency_closure_inventory_extension.threshold_selector_evaluator_or_result_change_count -eq 0 -and
    [int]$contract.inventory.r23d59_dependency_closure_inventory_extension.maintenance_process_physical_world_count -eq 0 -and
    -not [bool]$contract.inventory.r23d59_dependency_closure_inventory_extension.physical_acceptance_authority
) "R23D59 dependency-closure provenance classification or inventory extension changed"
Assert-Exact (
    $r23d59Physical.Count -eq 1 -and
    [string]$r23d59Physical[0].raw_sha256 -ceq
        "6cf2921c94e78521f1c3b1bab5d019300ade8e45107ec54f2682c9bd2f02c55f" -and
    [string]$r23d59Physical[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    (@($r23d59Physical[0].detected_modes) -join "|") -ceq
        "cas_path_check|pinned_git_blob|retained_evidence_bytes|live_repo_or_checkout_hash" -and
    -not [bool]$r23d59Physical[0].live_historical_identity_risk -and
    -not [bool]$r23d59Physical[0].manual_review_required -and
    [string]$contract.inventory.r23d59_physical_closure_inventory_extension.declared_from_physical_source_commit -ceq
        "22020d397ea4ce952a67051a843c22b388f0f78b" -and
    [string]$contract.inventory.r23d59_physical_closure_inventory_extension.scope -ceq
        "new_r23d59_immutable_physical_closure_audit_only" -and
    [bool]$contract.inventory.r23d59_physical_closure_inventory_extension.initial_inventory_failure_observed -and
    [string]$contract.inventory.r23d59_physical_closure_inventory_extension.initial_inventory_failure_message -ceq
        "Closure evidence-mode executable inventory verification failed" -and
    [int]$contract.inventory.r23d59_physical_closure_inventory_extension.pre_extension_audit_count -eq 156 -and
    [int]$contract.inventory.r23d59_physical_closure_inventory_extension.post_extension_audit_count -eq 157 -and
    [int]$contract.inventory.r23d59_physical_closure_inventory_extension.added_audit_count -eq 1 -and
    [int]$contract.inventory.r23d59_physical_closure_inventory_extension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$contract.inventory.r23d59_physical_closure_inventory_extension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$contract.inventory.r23d59_physical_closure_inventory_extension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$contract.inventory.r23d59_physical_closure_inventory_extension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$contract.inventory.r23d59_physical_closure_inventory_extension.manual_review_required_count_delta -eq 0 -and
    [string]$contract.inventory.r23d59_physical_closure_inventory_extension.new_audit_path -ceq
        "tests/test_qsdk_r23d59_physical_closure.ps1" -and
    [string]$contract.inventory.r23d59_physical_closure_inventory_extension.new_audit_raw_sha256 -ceq
        "6cf2921c94e78521f1c3b1bab5d019300ade8e45107ec54f2682c9bd2f02c55f" -and
    [string]$contract.inventory.r23d59_physical_closure_inventory_extension.historical_identity_mode -ceq
        "pinned_git_blob" -and
    (@($contract.inventory.r23d59_physical_closure_inventory_extension.detected_modes) -join "|") -ceq
        "cas_path_check|pinned_git_blob|retained_evidence_bytes|live_repo_or_checkout_hash" -and
    [int]$contract.inventory.r23d59_physical_closure_inventory_extension.retained_physical_world_count -eq 6 -and
    [int]$contract.inventory.r23d59_physical_closure_inventory_extension.maintenance_process_physical_world_count -eq 0 -and
    [int]$contract.inventory.r23d59_physical_closure_inventory_extension.physical_freeze_explicit_source_binding_count -eq 128 -and
    [int]$contract.inventory.r23d59_physical_closure_inventory_extension.physical_freeze_explicit_dependency_edge_count -eq 146 -and
    [bool]$contract.inventory.r23d59_physical_closure_inventory_extension.prospective_explicit_dependency_inventory_complete -and
    [bool]$contract.inventory.r23d59_physical_closure_inventory_extension.cold_evaluator_replay_passed_from_exact_git_blob_materialization -and
    -not [bool]$contract.inventory.r23d59_physical_closure_inventory_extension.result_payload_or_interpretation_changed -and
    [bool]$contract.inventory.r23d59_physical_closure_inventory_extension.finite_selection_binding_for_r23d60_preregistration_authorized -and
    -not [bool]$contract.inventory.r23d59_physical_closure_inventory_extension.r23d59_rerun_authorized -and
    -not [bool]$contract.inventory.r23d59_physical_closure_inventory_extension.historical_campaign_reclassification_authorized -and
    -not [bool]$contract.inventory.r23d59_physical_closure_inventory_extension.live_historical_identity_risk -and
    -not [bool]$contract.inventory.r23d59_physical_closure_inventory_extension.manual_review_required -and
    -not [bool]$contract.inventory.r23d59_physical_closure_inventory_extension.physical_acceptance_authority
) "R23D59 physical closure provenance classification or inventory extension changed"
Assert-Exact (
    $r23d60DependencyClosure.Count -eq 1 -and
    [string]$r23d60DependencyClosure[0].raw_sha256 -ceq
        "03efd671c76cbdcea4036e9d5699e0cf25cb1942e12e9586ce0113db13c52953" -and
    [string]$r23d60DependencyClosure[0].historical_identity_mode -ceq
        "record_retained_evidence_or_manual_review" -and
    (@($r23d60DependencyClosure[0].detected_modes) -join "|") -ceq
        "cas_path_check" -and
    -not [bool]$r23d60DependencyClosure[0].live_historical_identity_risk -and
    [bool]$r23d60DependencyClosure[0].manual_review_required -and
    [string]$contract.inventory.r23d60_dependency_closure_inventory_extension.declared_from_prospective_source_commit -ceq
        "66b7ea6d1e37ff1e00252571c9253beffc8a916e" -and
    [string]$contract.inventory.r23d60_dependency_closure_inventory_extension.scope -ceq
        "new_r23d60_prospective_zero_world_dependency_closure_audit_only" -and
    [bool]$contract.inventory.r23d60_dependency_closure_inventory_extension.initial_inventory_failure_observed -and
    [string]$contract.inventory.r23d60_dependency_closure_inventory_extension.initial_inventory_failure_message -ceq
        "Closure evidence-mode executable inventory verification failed" -and
    [string]$contract.inventory.r23d60_dependency_closure_inventory_extension.initial_failed_qualification_root -ceq
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r23d60-qualification-20260815T234728Z" -and
    [string]$contract.inventory.r23d60_dependency_closure_inventory_extension.initial_failed_qualification_failure_raw_sha256 -ceq
        "fab282b36adb943ce68724b5e266109db9fa7ebd1cf300c71ab9802cc366f160" -and
    [string]$contract.inventory.r23d60_dependency_closure_inventory_extension.initial_failed_provenance_gate_receipt_raw_sha256 -ceq
        "d38782679180fa0d279f21d0e9b9825343824280ea86584e7cf2a0f1ef971c9e" -and
    [string]$contract.inventory.r23d60_dependency_closure_inventory_extension.initial_failed_provenance_gate_stderr_raw_sha256 -ceq
        "195a6079048e4b7ab1bbaa049ff8fb66ddf9cbcb90cb37a554cd97472e479521" -and
    [int]$contract.inventory.r23d60_dependency_closure_inventory_extension.initial_failed_qualification_passed_gate_count -eq 3 -and
    [string]$contract.inventory.r23d60_dependency_closure_inventory_extension.initial_failed_qualification_failure_gate_id -ceq
        "CAK1-EVIDENCE-PROVENANCE" -and
    [int]$contract.inventory.r23d60_dependency_closure_inventory_extension.pre_extension_audit_count -eq 157 -and
    [int]$contract.inventory.r23d60_dependency_closure_inventory_extension.post_extension_audit_count -eq 158 -and
    [int]$contract.inventory.r23d60_dependency_closure_inventory_extension.added_audit_count -eq 1 -and
    [int]$contract.inventory.r23d60_dependency_closure_inventory_extension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$contract.inventory.r23d60_dependency_closure_inventory_extension.pinned_git_blob_signature_count_delta -eq 0 -and
    [int]$contract.inventory.r23d60_dependency_closure_inventory_extension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$contract.inventory.r23d60_dependency_closure_inventory_extension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$contract.inventory.r23d60_dependency_closure_inventory_extension.manual_review_required_count_delta -eq 1 -and
    [string]$contract.inventory.r23d60_dependency_closure_inventory_extension.new_audit_path -ceq
        "tests/test_qsdk_r23d60_dependency_closure.ps1" -and
    [string]$contract.inventory.r23d60_dependency_closure_inventory_extension.new_audit_raw_sha256 -ceq
        "03efd671c76cbdcea4036e9d5699e0cf25cb1942e12e9586ce0113db13c52953" -and
    [string]$contract.inventory.r23d60_dependency_closure_inventory_extension.historical_identity_mode -ceq
        "record_retained_evidence_or_manual_review" -and
    (@($contract.inventory.r23d60_dependency_closure_inventory_extension.detected_modes) -join "|") -ceq
        "cas_path_check" -and
    [string]$contract.inventory.r23d60_dependency_closure_inventory_extension.manual_review_disposition -ceq
        "prospective_dependency_omission_and_receipt_mutation_gate_not_a_historical_result_identity" -and
    -not [bool]$contract.inventory.r23d60_dependency_closure_inventory_extension.live_historical_identity_risk -and
    [bool]$contract.inventory.r23d60_dependency_closure_inventory_extension.manual_review_required -and
    [bool]$contract.inventory.r23d60_dependency_closure_inventory_extension.failed_qualification_retained -and
    [bool]$contract.inventory.r23d60_dependency_closure_inventory_extension.qualification_retry_requires_distinct_corrected_clean_pushed_source -and
    -not [bool]$contract.inventory.r23d60_dependency_closure_inventory_extension.historical_campaign_reclassification_authorized -and
    [int]$contract.inventory.r23d60_dependency_closure_inventory_extension.threshold_selector_evaluator_or_result_change_count -eq 0 -and
    [int]$contract.inventory.r23d60_dependency_closure_inventory_extension.maintenance_process_physical_world_count -eq 0 -and
    -not [bool]$contract.inventory.r23d60_dependency_closure_inventory_extension.physical_acceptance_authority
) "R23D60 dependency-closure provenance classification or inventory extension changed"
Assert-Exact (
    $r23d60Physical.Count -eq 1 -and
    [string]$r23d60Physical[0].raw_sha256 -ceq
        "2a20b8fe7ee35407c83f2f54ce4f60eb301c3fd89f7e33dff05c7a1f6a92c63e" -and
    [string]$r23d60Physical[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    (@($r23d60Physical[0].detected_modes) -join "|") -ceq
        "cas_path_check|pinned_git_blob|retained_evidence_bytes|live_repo_or_checkout_hash" -and
    -not [bool]$r23d60Physical[0].live_historical_identity_risk -and
    -not [bool]$r23d60Physical[0].manual_review_required -and
    [string]$contract.inventory.r23d60_physical_closure_inventory_extension.declared_from_physical_source_commit -ceq
        "3d884af6dc0a15aa9bd2cde15de4535a24bb44a2" -and
    [string]$contract.inventory.r23d60_physical_closure_inventory_extension.scope -ceq
        "new_r23d60_immutable_physical_closure_audit_only" -and
    [int]$contract.inventory.r23d60_physical_closure_inventory_extension.pre_extension_audit_count -eq 158 -and
    [int]$contract.inventory.r23d60_physical_closure_inventory_extension.post_extension_audit_count -eq 159 -and
    [int]$contract.inventory.r23d60_physical_closure_inventory_extension.added_audit_count -eq 1 -and
    [int]$contract.inventory.r23d60_physical_closure_inventory_extension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$contract.inventory.r23d60_physical_closure_inventory_extension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$contract.inventory.r23d60_physical_closure_inventory_extension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$contract.inventory.r23d60_physical_closure_inventory_extension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$contract.inventory.r23d60_physical_closure_inventory_extension.manual_review_required_count_delta -eq 0 -and
    [string]$contract.inventory.r23d60_physical_closure_inventory_extension.new_audit_path -ceq
        "tests/test_qsdk_r23d60_physical_closure.ps1" -and
    [string]$contract.inventory.r23d60_physical_closure_inventory_extension.new_audit_raw_sha256 -ceq
        "2a20b8fe7ee35407c83f2f54ce4f60eb301c3fd89f7e33dff05c7a1f6a92c63e" -and
    [string]$contract.inventory.r23d60_physical_closure_inventory_extension.historical_identity_mode -ceq
        "pinned_git_blob" -and
    (@($contract.inventory.r23d60_physical_closure_inventory_extension.detected_modes) -join "|") -ceq
        "cas_path_check|pinned_git_blob|retained_evidence_bytes|live_repo_or_checkout_hash" -and
    [int]$contract.inventory.r23d60_physical_closure_inventory_extension.retained_physical_world_count -eq 3 -and
    [int]$contract.inventory.r23d60_physical_closure_inventory_extension.maintenance_process_physical_world_count -eq 0 -and
    [int]$contract.inventory.r23d60_physical_closure_inventory_extension.physical_freeze_explicit_source_binding_count -eq 136 -and
    [int]$contract.inventory.r23d60_physical_closure_inventory_extension.physical_freeze_explicit_dependency_edge_count -eq 159 -and
    [bool]$contract.inventory.r23d60_physical_closure_inventory_extension.prospective_explicit_dependency_inventory_complete -and
    [bool]$contract.inventory.r23d60_physical_closure_inventory_extension.cold_evaluator_replay_passed_from_exact_git_blob_materialization -and
    [bool]$contract.inventory.r23d60_physical_closure_inventory_extension.initial_failed_qualification_retained_non_reusable -and
    -not [bool]$contract.inventory.r23d60_physical_closure_inventory_extension.result_payload_or_interpretation_changed -and
    [bool]$contract.inventory.r23d60_physical_closure_inventory_extension.exact_bounded_godot_jolt_turning_positive -and
    -not [bool]$contract.inventory.r23d60_physical_closure_inventory_extension.finite_three_engine_turning_established -and
    -not [bool]$contract.inventory.r23d60_physical_closure_inventory_extension.prone_to_standing_established -and
    -not [bool]$contract.inventory.r23d60_physical_closure_inventory_extension.r23d60_rerun_authorized -and
    -not [bool]$contract.inventory.r23d60_physical_closure_inventory_extension.historical_campaign_reclassification_authorized -and
    -not [bool]$contract.inventory.r23d60_physical_closure_inventory_extension.live_historical_identity_risk -and
    -not [bool]$contract.inventory.r23d60_physical_closure_inventory_extension.manual_review_required -and
    -not [bool]$contract.inventory.r23d60_physical_closure_inventory_extension.physical_acceptance_authority
) "R23D60 physical closure provenance classification or inventory extension changed"

$r23d61InventoryExtension =
    $contract.inventory.r23d61_publication_closure_inventory_extension
$r23d61FailureRoot = [IO.Path]::GetFullPath(
    [string]$r23d61InventoryExtension.initial_failed_full_cold_run_root
)
$r23d61FailureReceiptPath = Join-Path $r23d61FailureRoot "receipt.json"
$r23d61FailureStagePath = Join-Path (
    $r23d61FailureRoot
) "stages\01-authority_and_historical_closures.json"
$r23d61FailureExcerptPath = Join-Path $r23d61FailureRoot "failure_excerpt.txt"
$r23d61FailureLogPath = Join-Path $r23d61FailureRoot "conformance.log"
Assert-Exact (
    $r23d61PublicationClosure.Count -eq 1 -and
    [string]$r23d61PublicationClosure[0].raw_sha256 -ceq
        "4a301056da7fa2f28a94c21719705d32a507cf994caadd40241e834d93ae026c" -and
    [string]$r23d61PublicationClosure[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    (@($r23d61PublicationClosure[0].detected_modes) -join "|") -ceq
        "pinned_git_blob|retained_evidence_bytes|live_repo_or_checkout_hash" -and
    -not [bool]$r23d61PublicationClosure[0].live_historical_identity_risk -and
    -not [bool]$r23d61PublicationClosure[0].manual_review_required -and
    [string]$r23d61InventoryExtension.declared_from_closure_commit -ceq
        "0319dcc39a3454029025d5995168af5f5225ccb0" -and
    [string]$r23d61InventoryExtension.scope -ceq
        "new_r23d61_nonphysical_publication_closure_audit_only" -and
    [bool]$r23d61InventoryExtension.initial_inventory_failure_observed -and
    [string]$r23d61InventoryExtension.initial_inventory_failure_message -ceq
        "Closure evidence-mode executable inventory verification failed" -and
    [int]$r23d61InventoryExtension.pre_extension_audit_count -eq 159 -and
    [int]$r23d61InventoryExtension.post_extension_audit_count -eq 160 -and
    [int]$r23d61InventoryExtension.added_audit_count -eq 1 -and
    [int]$r23d61InventoryExtension.cas_path_check_signature_count_delta -eq 0 -and
    [int]$r23d61InventoryExtension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$r23d61InventoryExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r23d61InventoryExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r23d61InventoryExtension.manual_review_required_count_delta -eq 0 -and
    [string]$r23d61InventoryExtension.new_audit_path -ceq
        "tests/test_qsdk_r23d61_publication_closure.ps1" -and
    [string]$r23d61InventoryExtension.new_audit_raw_sha256 -ceq
        "4a301056da7fa2f28a94c21719705d32a507cf994caadd40241e834d93ae026c" -and
    [string]$r23d61InventoryExtension.historical_identity_mode -ceq
        "pinned_git_blob" -and
    (@($r23d61InventoryExtension.detected_modes) -join "|") -ceq
        "pinned_git_blob|retained_evidence_bytes|live_repo_or_checkout_hash" -and
    [string]$r23d61InventoryExtension.publication_source_commit -ceq
        "c61e56907d255e920297f088b93fc3e09ba12aef" -and
    [string]$r23d61InventoryExtension.publication_closure_commit -ceq
        "0319dcc39a3454029025d5995168af5f5225ccb0" -and
    [bool]$r23d61InventoryExtension.qualification_retry_requires_distinct_corrected_clean_pushed_source -and
    [bool]$r23d61InventoryExtension.failed_qualification_retained_non_reusable -and
    -not [bool]$r23d61InventoryExtension.historical_result_or_interpretation_changed -and
    -not [bool]$r23d61InventoryExtension.historical_campaign_reclassification_authorized -and
    -not [bool]$r23d61InventoryExtension.live_historical_identity_risk -and
    -not [bool]$r23d61InventoryExtension.manual_review_required -and
    [int]$r23d61InventoryExtension.maintenance_process_physical_world_count -eq 0 -and
    -not [bool]$r23d61InventoryExtension.physical_acceptance_authority -and
    -not [bool]$r23d61InventoryExtension.release_authority
) "R23D61 publication-closure provenance classification or inventory extension changed"

$r24d4ClosureInventoryExtension =
    $contract.inventory.r24d4_zero_world_failure_closure_inventory_extension
Assert-Exact (
    $r24d4ZeroWorldFailureClosure.Count -eq 1 -and
    [string]$r24d4ZeroWorldFailureClosure[0].raw_sha256 -ceq
        "9f2497382de1e7bfd10acc53f3836b4f994fdea8285722654b8ee6157fad8aaf" -and
    [string]$r24d4ZeroWorldFailureClosure[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    (@($r24d4ZeroWorldFailureClosure[0].detected_modes) -join "|") -ceq
        "cas_path_check|pinned_git_blob|retained_evidence_bytes|live_repo_or_checkout_hash" -and
    -not [bool]$r24d4ZeroWorldFailureClosure[0].live_historical_identity_risk -and
    -not [bool]$r24d4ZeroWorldFailureClosure[0].manual_review_required -and
    [string]$r24d4ClosureInventoryExtension.declared_from_source_commit -ceq
        "6e24a729bac03e02cf247583f5e321040b4b011a" -and
    [string]$r24d4ClosureInventoryExtension.scope -ceq
        "new_r24d4_immutable_zero_world_failure_closure_audit_only" -and
    [bool]$r24d4ClosureInventoryExtension.initial_inventory_failure_observed -and
    [string]$r24d4ClosureInventoryExtension.initial_inventory_failure_message -ceq
        "Closure evidence-mode executable inventory verification failed" -and
    [int]$r24d4ClosureInventoryExtension.pre_extension_audit_count -eq 160 -and
    [int]$r24d4ClosureInventoryExtension.post_extension_audit_count -eq 161 -and
    [int]$r24d4ClosureInventoryExtension.added_audit_count -eq 1 -and
    [int]$r24d4ClosureInventoryExtension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$r24d4ClosureInventoryExtension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$r24d4ClosureInventoryExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r24d4ClosureInventoryExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r24d4ClosureInventoryExtension.manual_review_required_count_delta -eq 0 -and
    [string]$r24d4ClosureInventoryExtension.new_audit_path -ceq
        "tests/test_qsdk_r24d4_one_hinge_telemetry_zero_world_failure_closure.ps1" -and
    [string]$r24d4ClosureInventoryExtension.new_audit_raw_sha256 -ceq
        "9f2497382de1e7bfd10acc53f3836b4f994fdea8285722654b8ee6157fad8aaf" -and
    [string]$r24d4ClosureInventoryExtension.historical_identity_mode -ceq
        "pinned_git_blob" -and
    (@($r24d4ClosureInventoryExtension.detected_modes) -join "|") -ceq
        "cas_path_check|pinned_git_blob|retained_evidence_bytes|live_repo_or_checkout_hash" -and
    [int]$r24d4ClosureInventoryExtension.retained_zero_world_failure_count -eq 1 -and
    [int]$r24d4ClosureInventoryExtension.retained_physical_world_count -eq 0 -and
    [int]$r24d4ClosureInventoryExtension.maintenance_process_physical_world_count -eq 0 -and
    [bool]$r24d4ClosureInventoryExtension.same_source_physical_open_forbidden -and
    -not [bool]$r24d4ClosureInventoryExtension.source_or_result_interpretation_changed -and
    -not [bool]$r24d4ClosureInventoryExtension.historical_campaign_reclassification_authorized -and
    -not [bool]$r24d4ClosureInventoryExtension.live_historical_identity_risk -and
    -not [bool]$r24d4ClosureInventoryExtension.manual_review_required -and
    -not [bool]$r24d4ClosureInventoryExtension.physical_acceptance_authority -and
    -not [bool]$r24d4ClosureInventoryExtension.release_authority
) "R24D4 zero-world closure provenance classification or inventory extension changed"

$r24d5ClosureInventoryExtension =
    $contract.inventory.r24d5_physical_failure_closure_inventory_extension
Assert-Exact (
    $r24d5PhysicalFailureClosure.Count -eq 1 -and
    [string]$r24d5PhysicalFailureClosure[0].raw_sha256 -ceq
        "6c0fb1c60488820e264000ba82a7219582a6160ea1caad3dc9a62f803df0876d" -and
    [string]$r24d5PhysicalFailureClosure[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    (@($r24d5PhysicalFailureClosure[0].detected_modes) -join "|") -ceq
        "cas_path_check|pinned_git_blob|retained_evidence_bytes|live_repo_or_checkout_hash" -and
    -not [bool]$r24d5PhysicalFailureClosure[0].live_historical_identity_risk -and
    -not [bool]$r24d5PhysicalFailureClosure[0].manual_review_required -and
    [string]$r24d5ClosureInventoryExtension.declared_from_source_commit -ceq
        "fffb773b408b0cf8bb4a3ba78e773b62c3a0e52a" -and
    [string]$r24d5ClosureInventoryExtension.scope -ceq
        "new_r24d5_immutable_consumed_physical_failure_closure_audit_only" -and
    [bool]$r24d5ClosureInventoryExtension.initial_inventory_failure_observed -and
    [string]$r24d5ClosureInventoryExtension.initial_inventory_failure_message -ceq
        "Closure evidence-mode inventory drifted; regenerate and review the complete classification" -and
    [int]$r24d5ClosureInventoryExtension.pre_extension_audit_count -eq 161 -and
    [int]$r24d5ClosureInventoryExtension.post_extension_audit_count -eq 162 -and
    [int]$r24d5ClosureInventoryExtension.added_audit_count -eq 1 -and
    [int]$r24d5ClosureInventoryExtension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$r24d5ClosureInventoryExtension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$r24d5ClosureInventoryExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r24d5ClosureInventoryExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r24d5ClosureInventoryExtension.manual_review_required_count_delta -eq 0 -and
    [string]$r24d5ClosureInventoryExtension.new_audit_path -ceq
        "tests/test_qsdk_r24d5_one_hinge_telemetry_physical_failure_closure.ps1" -and
    [string]$r24d5ClosureInventoryExtension.new_audit_raw_sha256 -ceq
        "6c0fb1c60488820e264000ba82a7219582a6160ea1caad3dc9a62f803df0876d" -and
    [string]$r24d5ClosureInventoryExtension.historical_identity_mode -ceq
        "pinned_git_blob" -and
    (@($r24d5ClosureInventoryExtension.detected_modes) -join "|") -ceq
        "cas_path_check|pinned_git_blob|retained_evidence_bytes|live_repo_or_checkout_hash" -and
    [int]$r24d5ClosureInventoryExtension.retained_invalid_physical_result_count -eq 1 -and
    [int]$r24d5ClosureInventoryExtension.retained_physical_world_count -eq 1 -and
    [int]$r24d5ClosureInventoryExtension.retained_physics_step_count -eq 20 -and
    [int]$r24d5ClosureInventoryExtension.maintenance_process_physical_world_count -eq 0 -and
    [bool]$r24d5ClosureInventoryExtension.same_source_physical_open_forbidden -and
    -not [bool]$r24d5ClosureInventoryExtension.source_or_result_interpretation_changed -and
    -not [bool]$r24d5ClosureInventoryExtension.historical_campaign_reclassification_authorized -and
    -not [bool]$r24d5ClosureInventoryExtension.live_historical_identity_risk -and
    -not [bool]$r24d5ClosureInventoryExtension.manual_review_required -and
    -not [bool]$r24d5ClosureInventoryExtension.physical_acceptance_authority -and
    -not [bool]$r24d5ClosureInventoryExtension.release_authority
) "R24D5 physical closure provenance classification or inventory extension changed"

$r24d6ClosureInventoryExtension =
    $contract.inventory.r24d6_zero_world_failure_closure_inventory_extension
Assert-Exact (
    $r24d6ZeroWorldFailureClosure.Count -eq 1 -and
    [string]$r24d6ZeroWorldFailureClosure[0].raw_sha256 -ceq
        "48d150501785de227ce1a1097efe20e6b952f6759b77d34a3f8df1da6e09851a" -and
    [string]$r24d6ZeroWorldFailureClosure[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    (@($r24d6ZeroWorldFailureClosure[0].detected_modes) -join "|") -ceq
        "cas_path_check|pinned_git_blob|retained_evidence_bytes|live_repo_or_checkout_hash" -and
    -not [bool]$r24d6ZeroWorldFailureClosure[0].live_historical_identity_risk -and
    -not [bool]$r24d6ZeroWorldFailureClosure[0].manual_review_required -and
    [string]$r24d6ClosureInventoryExtension.declared_from_source_commit -ceq
        "55032839756cc8a9089a2a4eb4e06db71ab99ca4" -and
    [string]$r24d6ClosureInventoryExtension.scope -ceq
        "new_r24d6_immutable_zero_world_failure_closure_audit_only" -and
    [bool]$r24d6ClosureInventoryExtension.initial_inventory_failure_observed -and
    [string]$r24d6ClosureInventoryExtension.initial_inventory_failure_message -ceq
        "Closure evidence-mode inventory drifted; regenerate and review the complete classification" -and
    [int]$r24d6ClosureInventoryExtension.pre_extension_audit_count -eq 162 -and
    [int]$r24d6ClosureInventoryExtension.post_extension_audit_count -eq 163 -and
    [int]$r24d6ClosureInventoryExtension.added_audit_count -eq 1 -and
    [int]$r24d6ClosureInventoryExtension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$r24d6ClosureInventoryExtension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$r24d6ClosureInventoryExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r24d6ClosureInventoryExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r24d6ClosureInventoryExtension.manual_review_required_count_delta -eq 0 -and
    [string]$r24d6ClosureInventoryExtension.new_audit_path -ceq
        "tests/test_qsdk_r24d6_one_hinge_telemetry_zero_world_failure_closure.ps1" -and
    [string]$r24d6ClosureInventoryExtension.new_audit_raw_sha256 -ceq
        "48d150501785de227ce1a1097efe20e6b952f6759b77d34a3f8df1da6e09851a" -and
    [string]$r24d6ClosureInventoryExtension.historical_identity_mode -ceq
        "pinned_git_blob" -and
    (@($r24d6ClosureInventoryExtension.detected_modes) -join "|") -ceq
        "cas_path_check|pinned_git_blob|retained_evidence_bytes|live_repo_or_checkout_hash" -and
    [int]$r24d6ClosureInventoryExtension.retained_zero_world_failure_count -eq 1 -and
    [int]$r24d6ClosureInventoryExtension.retained_physical_world_count -eq 0 -and
    [int]$r24d6ClosureInventoryExtension.retained_actual_world_attempt_count -eq 0 -and
    [int]$r24d6ClosureInventoryExtension.retained_actual_world_build_count -eq 0 -and
    [int]$r24d6ClosureInventoryExtension.retained_actual_solver_step_count -eq 0 -and
    [int]$r24d6ClosureInventoryExtension.retained_serializer_envelope_count -eq 2 -and
    [int]$r24d6ClosureInventoryExtension.retained_integer_variant_projection_count -eq 313 -and
    [int]$r24d6ClosureInventoryExtension.retained_strict_integer_evaluator_projection_count -eq 234 -and
    [int]$r24d6ClosureInventoryExtension.maintenance_process_physical_world_count -eq 0 -and
    [bool]$r24d6ClosureInventoryExtension.same_source_zero_world_rerun_forbidden -and
    [bool]$r24d6ClosureInventoryExtension.same_source_physical_open_forbidden -and
    -not [bool]$r24d6ClosureInventoryExtension.source_or_result_interpretation_changed -and
    -not [bool]$r24d6ClosureInventoryExtension.historical_campaign_reclassification_authorized -and
    -not [bool]$r24d6ClosureInventoryExtension.live_historical_identity_risk -and
    -not [bool]$r24d6ClosureInventoryExtension.manual_review_required -and
    -not [bool]$r24d6ClosureInventoryExtension.physical_acceptance_authority -and
    -not [bool]$r24d6ClosureInventoryExtension.release_authority
) "R24D6 zero-world closure provenance classification or inventory extension changed"

$r24d7ClosureInventoryExtension =
    $contract.inventory.r24d7_physical_failure_closure_inventory_extension
Assert-Exact (
    $r24d7PhysicalFailureClosure.Count -eq 1 -and
    [string]$r24d7PhysicalFailureClosure[0].raw_sha256 -ceq
        "f715f3a9e44abcd660db4fb0900c921c39b7de6bac5e0fd3d3b3167cff288cb3" -and
    [string]$r24d7PhysicalFailureClosure[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    (@($r24d7PhysicalFailureClosure[0].detected_modes) -join "|") -ceq
        "cas_path_check|pinned_git_blob|retained_evidence_bytes|live_repo_or_checkout_hash" -and
    -not [bool]$r24d7PhysicalFailureClosure[0].live_historical_identity_risk -and
    -not [bool]$r24d7PhysicalFailureClosure[0].manual_review_required -and
    [string]$r24d7ClosureInventoryExtension.declared_from_source_commit -ceq
        "ab6e763e466db86ea1d6fea6b72a23a68ff63587" -and
    [string]$r24d7ClosureInventoryExtension.scope -ceq
        "new_r24d7_immutable_consumed_physical_implementation_invalid_closure_audit_only" -and
    [bool]$r24d7ClosureInventoryExtension.initial_inventory_failure_observed -and
    [string]$r24d7ClosureInventoryExtension.initial_inventory_failure_message -ceq
        "Closure evidence-mode executable inventory verification failed" -and
    [int]$r24d7ClosureInventoryExtension.pre_extension_audit_count -eq 163 -and
    [int]$r24d7ClosureInventoryExtension.post_extension_audit_count -eq 164 -and
    [int]$r24d7ClosureInventoryExtension.added_audit_count -eq 1 -and
    [int]$r24d7ClosureInventoryExtension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$r24d7ClosureInventoryExtension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$r24d7ClosureInventoryExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r24d7ClosureInventoryExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r24d7ClosureInventoryExtension.manual_review_required_count_delta -eq 0 -and
    [string]$r24d7ClosureInventoryExtension.new_audit_path -ceq
        "tests/test_qsdk_r24d7_one_hinge_telemetry_physical_failure_closure.ps1" -and
    [string]$r24d7ClosureInventoryExtension.new_audit_raw_sha256 -ceq
        "f715f3a9e44abcd660db4fb0900c921c39b7de6bac5e0fd3d3b3167cff288cb3" -and
    [string]$r24d7ClosureInventoryExtension.historical_identity_mode -ceq
        "pinned_git_blob" -and
    (@($r24d7ClosureInventoryExtension.detected_modes) -join "|") -ceq
        "cas_path_check|pinned_git_blob|retained_evidence_bytes|live_repo_or_checkout_hash" -and
    [int]$r24d7ClosureInventoryExtension.retained_valid_zero_world_result_count -eq 1 -and
    [int]$r24d7ClosureInventoryExtension.retained_invalid_physical_result_count -eq 1 -and
    [int]$r24d7ClosureInventoryExtension.retained_physical_world_count -eq 1 -and
    [int]$r24d7ClosureInventoryExtension.retained_physics_step_count -eq 20 -and
    [int]$r24d7ClosureInventoryExtension.retained_sample_count -eq 68 -and
    [int]$r24d7ClosureInventoryExtension.retained_cell_count -eq 9 -and
    [int]$r24d7ClosureInventoryExtension.integrate_callback_attempt_count -eq 65 -and
    [int]$r24d7ClosureInventoryExtension.integrate_callback_refusal_count -eq 0 -and
    [int]$r24d7ClosureInventoryExtension.evaluator_exit_code -eq 2 -and
    -not [bool]$r24d7ClosureInventoryExtension.active_step_timing_control_adequate -and
    -not [bool]$r24d7ClosureInventoryExtension.valid_characterization -and
    [int]$r24d7ClosureInventoryExtension.maintenance_process_physical_world_count -eq 0 -and
    [bool]$r24d7ClosureInventoryExtension.same_source_physical_rerun_forbidden -and
    -not [bool]$r24d7ClosureInventoryExtension.source_or_result_interpretation_changed -and
    -not [bool]$r24d7ClosureInventoryExtension.historical_campaign_reclassification_authorized -and
    -not [bool]$r24d7ClosureInventoryExtension.live_historical_identity_risk -and
    -not [bool]$r24d7ClosureInventoryExtension.manual_review_required -and
    -not [bool]$r24d7ClosureInventoryExtension.physical_acceptance_authority -and
    -not [bool]$r24d7ClosureInventoryExtension.release_authority
) "R24D7 physical closure provenance classification or inventory extension changed"

$r24d8ClosureInventoryExtension =
    $contract.inventory.r24d8_positive_closure_inventory_extension
Assert-Exact (
    $r24d8PositiveClosure.Count -eq 1 -and
    [string]$r24d8PositiveClosure[0].raw_sha256 -ceq
        "9f8ef518e3168107188cb2e5dcc488b25e969983bdd48601bc750d4cf93d0cf1" -and
    [string]$r24d8PositiveClosure[0].historical_identity_mode -ceq
        "pinned_git_blob_with_checkout_reconstruction" -and
    (@($r24d8PositiveClosure[0].detected_modes) -join "|") -ceq
        "cas_path_check|pinned_git_blob|reconstructed_checkout|retained_evidence_bytes|live_repo_or_checkout_hash" -and
    -not [bool]$r24d8PositiveClosure[0].live_historical_identity_risk -and
    -not [bool]$r24d8PositiveClosure[0].manual_review_required -and
    [string]$r24d8ClosureInventoryExtension.declared_from_source_commit -ceq
        "b17a6677e711625061726279a1b0287c57fa82ec" -and
    [string]$r24d8ClosureInventoryExtension.scope -ceq
        "new_r24d8_immutable_consumed_finite_positive_active_step_snapshot_timing_closure_audit_only" -and
    [bool]$r24d8ClosureInventoryExtension.inventory_delta_measured_before_update -and
    -not [bool]$r24d8ClosureInventoryExtension.initial_inventory_failure_observed -and
    [int]$r24d8ClosureInventoryExtension.pre_extension_audit_count -eq 164 -and
    [int]$r24d8ClosureInventoryExtension.post_extension_audit_count -eq 165 -and
    [int]$r24d8ClosureInventoryExtension.added_audit_count -eq 1 -and
    [int]$r24d8ClosureInventoryExtension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$r24d8ClosureInventoryExtension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$r24d8ClosureInventoryExtension.reconstructed_checkout_signature_count_delta -eq 1 -and
    [int]$r24d8ClosureInventoryExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r24d8ClosureInventoryExtension.manual_review_required_count_delta -eq 0 -and
    [string]$r24d8ClosureInventoryExtension.new_audit_path -ceq
        "tests/test_qsdk_r24d8_active_step_snapshot_timing_positive_closure.ps1" -and
    [string]$r24d8ClosureInventoryExtension.new_audit_raw_sha256 -ceq
        "9f8ef518e3168107188cb2e5dcc488b25e969983bdd48601bc750d4cf93d0cf1" -and
    [string]$r24d8ClosureInventoryExtension.historical_identity_mode -ceq
        "pinned_git_blob_with_checkout_reconstruction" -and
    (@($r24d8ClosureInventoryExtension.detected_modes) -join "|") -ceq
        "cas_path_check|pinned_git_blob|reconstructed_checkout|retained_evidence_bytes|live_repo_or_checkout_hash" -and
    [int]$r24d8ClosureInventoryExtension.retained_valid_zero_world_result_count -eq 1 -and
    [int]$r24d8ClosureInventoryExtension.retained_valid_physical_development_result_count -eq 1 -and
    [int]$r24d8ClosureInventoryExtension.retained_physical_world_count -eq 1 -and
    [int]$r24d8ClosureInventoryExtension.retained_physics_step_count -eq 8 -and
    [int]$r24d8ClosureInventoryExtension.retained_sample_count -eq 8 -and
    [int]$r24d8ClosureInventoryExtension.fresh_active_sample_count -eq 4 -and
    [int]$r24d8ClosureInventoryExtension.sleeping_stale_sample_count -eq 4 -and
    [int]$r24d8ClosureInventoryExtension.executed_source_binding_count -eq 15 -and
    [int]$r24d8ClosureInventoryExtension.closure_mutation_rejection_count -eq 39 -and
    [int]$r24d8ClosureInventoryExtension.closure_diagnostic_attempt_count -eq 5 -and
    [int]$r24d8ClosureInventoryExtension.closure_diagnostic_negative_count -eq 4 -and
    [int]$r24d8ClosureInventoryExtension.closure_diagnostic_mutation_rejection_count -eq 7 -and
    [bool]$r24d8ClosureInventoryExtension.native_active_step_snapshot_timing_established -and
    [bool]$r24d8ClosureInventoryExtension.sleeping_stale_snapshot_preservation_established -and
    -not [bool]$r24d8ClosureInventoryExtension.native_numerical_telemetry_characterized -and
    -not [bool]$r24d8ClosureInventoryExtension.instrumented_profile_promoted -and
    [int]$r24d8ClosureInventoryExtension.maintenance_process_physical_world_count -eq 0 -and
    [bool]$r24d8ClosureInventoryExtension.same_source_physical_rerun_forbidden -and
    -not [bool]$r24d8ClosureInventoryExtension.source_or_result_interpretation_changed -and
    -not [bool]$r24d8ClosureInventoryExtension.historical_campaign_reclassification_authorized -and
    -not [bool]$r24d8ClosureInventoryExtension.live_historical_identity_risk -and
    -not [bool]$r24d8ClosureInventoryExtension.manual_review_required -and
    -not [bool]$r24d8ClosureInventoryExtension.recovery_world_opened -and
    -not [bool]$r24d8ClosureInventoryExtension.prone_to_standing_world_opened -and
    -not [bool]$r24d8ClosureInventoryExtension.turning_claim_changed -and
    -not [bool]$r24d8ClosureInventoryExtension.cross_engine_equivalence_claimed -and
    -not [bool]$r24d8ClosureInventoryExtension.physical_acceptance_authority -and
    -not [bool]$r24d8ClosureInventoryExtension.release_authority
) "R24D8 timing-positive closure provenance classification or inventory extension changed"

$r24d9ClosureInventoryExtension =
    $contract.inventory.r24d9_physical_failure_closure_inventory_extension
Assert-Exact (
    $r24d9PhysicalFailureClosure.Count -eq 1 -and
    [string]$r24d9PhysicalFailureClosure[0].raw_sha256 -ceq
        "f500d5715eb59e9e56cd9d2638604257284b9c185a5ed81960978988918503be" -and
    [string]$r24d9PhysicalFailureClosure[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    (@($r24d9PhysicalFailureClosure[0].detected_modes) -join "|") -ceq
        "cas_path_check|pinned_git_blob|retained_evidence_bytes|live_repo_or_checkout_hash" -and
    -not [bool]$r24d9PhysicalFailureClosure[0].live_historical_identity_risk -and
    -not [bool]$r24d9PhysicalFailureClosure[0].manual_review_required -and
    [string]$r24d9ClosureInventoryExtension.declared_from_source_commit -ceq
        "62b6b98c45d65d0fe7262969213a1e2898bd57f3" -and
    [string]$r24d9ClosureInventoryExtension.scope -ceq
        "new_r24d9_immutable_consumed_implementation_invalid_numerical_telemetry_physical_failure_closure_audit_only" -and
    [bool]$r24d9ClosureInventoryExtension.inventory_delta_measured_before_update -and
    -not [bool]$r24d9ClosureInventoryExtension.initial_inventory_failure_observed -and
    [int]$r24d9ClosureInventoryExtension.pre_extension_audit_count -eq 165 -and
    [int]$r24d9ClosureInventoryExtension.post_extension_audit_count -eq 166 -and
    [int]$r24d9ClosureInventoryExtension.added_audit_count -eq 1 -and
    [int]$r24d9ClosureInventoryExtension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$r24d9ClosureInventoryExtension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$r24d9ClosureInventoryExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r24d9ClosureInventoryExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r24d9ClosureInventoryExtension.manual_review_required_count_delta -eq 0 -and
    [string]$r24d9ClosureInventoryExtension.new_audit_path -ceq
        "tests/test_qsdk_r24d9_one_hinge_numerical_telemetry_physical_failure_closure.ps1" -and
    [string]$r24d9ClosureInventoryExtension.new_audit_raw_sha256 -ceq
        "f500d5715eb59e9e56cd9d2638604257284b9c185a5ed81960978988918503be" -and
    [string]$r24d9ClosureInventoryExtension.historical_identity_mode -ceq
        "pinned_git_blob" -and
    (@($r24d9ClosureInventoryExtension.detected_modes) -join "|") -ceq
        "cas_path_check|pinned_git_blob|retained_evidence_bytes|live_repo_or_checkout_hash" -and
    [int]$r24d9ClosureInventoryExtension.retained_valid_zero_world_result_count -eq 1 -and
    [int]$r24d9ClosureInventoryExtension.retained_invalid_physical_development_result_count -eq 1 -and
    [int]$r24d9ClosureInventoryExtension.retained_physical_world_count -eq 1 -and
    [int]$r24d9ClosureInventoryExtension.immutable_reported_solver_step_count -eq 20 -and
    [int]$r24d9ClosureInventoryExtension.observed_exact_solver_step_count -eq 21 -and
    [int]$r24d9ClosureInventoryExtension.unretained_post_activation_solver_step_count -eq 1 -and
    [int]$r24d9ClosureInventoryExtension.retained_sample_count -eq 68 -and
    [int]$r24d9ClosureInventoryExtension.zero_world_retained_file_count -eq 21 -and
    [int]$r24d9ClosureInventoryExtension.zero_world_unique_content_digest_count -eq 18 -and
    [int]$r24d9ClosureInventoryExtension.physical_retained_file_count -eq 14 -and
    [int]$r24d9ClosureInventoryExtension.physical_unique_content_digest_count -eq 13 -and
    [int]$r24d9ClosureInventoryExtension.cross_run_unique_content_digest_count -eq 27 -and
    [int]$r24d9ClosureInventoryExtension.executed_source_binding_count -eq 17 -and
    [int]$r24d9ClosureInventoryExtension.closure_mutation_rejection_count -eq 35 -and
    -not [bool]$r24d9ClosureInventoryExtension.declared_step_contract_satisfied -and
    -not [bool]$r24d9ClosureInventoryExtension.declared_initial_state_preserved -and
    [bool]$r24d9ClosureInventoryExtension.immutable_evaluator_reported_valid_result_preserved -and
    -not [bool]$r24d9ClosureInventoryExtension.native_numerical_telemetry_characterized -and
    -not [bool]$r24d9ClosureInventoryExtension.instrumented_profile_promoted -and
    -not [bool]$r24d9ClosureInventoryExtension.r24d8_historical_positive_closure_rewritten -and
    -not [bool]$r24d9ClosureInventoryExtension.r24d8_parent_exact_step_contract_satisfied -and
    -not [bool]$r24d9ClosureInventoryExtension.r24d8_parent_valid_campaign_authority_preserved -and
    [bool]$r24d9ClosureInventoryExtension.same_source_physical_rerun_forbidden -and
    [bool]$r24d9ClosureInventoryExtension.scientifically_distinct_successor_required -and
    [int]$r24d9ClosureInventoryExtension.maintenance_process_physical_world_count -eq 0 -and
    -not [bool]$r24d9ClosureInventoryExtension.source_or_result_interpretation_changed -and
    -not [bool]$r24d9ClosureInventoryExtension.historical_campaign_reclassification_authorized -and
    -not [bool]$r24d9ClosureInventoryExtension.live_historical_identity_risk -and
    -not [bool]$r24d9ClosureInventoryExtension.manual_review_required -and
    -not [bool]$r24d9ClosureInventoryExtension.recovery_world_opened -and
    -not [bool]$r24d9ClosureInventoryExtension.prone_to_standing_world_opened -and
    -not [bool]$r24d9ClosureInventoryExtension.turning_claim_changed -and
    -not [bool]$r24d9ClosureInventoryExtension.cross_engine_equivalence_claimed -and
    -not [bool]$r24d9ClosureInventoryExtension.physical_acceptance_authority -and
    -not [bool]$r24d9ClosureInventoryExtension.release_authority
) "R24D9 physical failure closure provenance classification or inventory extension changed"

$r23d62DependencyClosureInventoryExtension =
    $contract.inventory.r23d62_dependency_closure_inventory_extension
Assert-Exact (
    $r23d62DependencyClosure.Count -eq 1 -and
    [string]$r23d62DependencyClosure[0].raw_sha256 -ceq
        "4535ea8e47bee3755b746d23ee108d40305efc5aab828e9b8776e3212621b294" -and
    [string]$r23d62DependencyClosure[0].historical_identity_mode -ceq
        "record_retained_evidence_or_manual_review" -and
    (@($r23d62DependencyClosure[0].detected_modes) -join "|") -ceq
        "cas_path_check" -and
    -not [bool]$r23d62DependencyClosure[0].live_historical_identity_risk -and
    [bool]$r23d62DependencyClosure[0].manual_review_required -and
    [string]$r23d62DependencyClosureInventoryExtension.declared_from_verified_parent_commit -ceq
        "98ac431139611e750aa94c2b4f1ebb83505cb276" -and
    [string]$r23d62DependencyClosureInventoryExtension.declaration_source_state -ceq
        "prospective_uncommitted_successor_worktree_on_verified_parent" -and
    [string]$r23d62DependencyClosureInventoryExtension.scope -ceq
        "new_r23d62_prospective_zero_world_dependency_closure_audit_only" -and
    [bool]$r23d62DependencyClosureInventoryExtension.inventory_delta_measured_before_update -and
    [bool]$r23d62DependencyClosureInventoryExtension.initial_inventory_failure_observed -and
    [string]$r23d62DependencyClosureInventoryExtension.initial_inventory_failure_message -ceq
        "Closure evidence-mode executable inventory verification failed" -and
    [bool]$r23d62DependencyClosureInventoryExtension.failure_was_local_zero_world_integration_check -and
    [int]$r23d62DependencyClosureInventoryExtension.pre_extension_audit_count -eq 166 -and
    [int]$r23d62DependencyClosureInventoryExtension.post_extension_audit_count -eq 167 -and
    [int]$r23d62DependencyClosureInventoryExtension.added_audit_count -eq 1 -and
    [int]$r23d62DependencyClosureInventoryExtension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$r23d62DependencyClosureInventoryExtension.pinned_git_blob_signature_count_delta -eq 0 -and
    [int]$r23d62DependencyClosureInventoryExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r23d62DependencyClosureInventoryExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r23d62DependencyClosureInventoryExtension.manual_review_required_count_delta -eq 1 -and
    [string]$r23d62DependencyClosureInventoryExtension.new_audit_path -ceq
        "tests/test_qsdk_r23d62_dependency_closure.ps1" -and
    [string]$r23d62DependencyClosureInventoryExtension.new_audit_raw_sha256 -ceq
        "e48793789ec3f5bc4e7d66a7f489b8904ca30140fcfb4a7aa11bf98aed150973" -and
    [string]$r23d62DependencyClosureInventoryExtension.historical_identity_mode -ceq
        "record_retained_evidence_or_manual_review" -and
    (@($r23d62DependencyClosureInventoryExtension.detected_modes) -join "|") -ceq
        "cas_path_check" -and
    [string]$r23d62DependencyClosureInventoryExtension.manual_review_disposition -ceq
        "prospective_recursive_dependency_omission_receipt_and_structure_mutation_gate_not_a_historical_result_identity" -and
    -not [bool]$r23d62DependencyClosureInventoryExtension.live_historical_identity_risk -and
    [bool]$r23d62DependencyClosureInventoryExtension.manual_review_required -and
    -not [bool]$r23d62DependencyClosureInventoryExtension.historical_campaign_result_created -and
    -not [bool]$r23d62DependencyClosureInventoryExtension.historical_campaign_reclassification_authorized -and
    [int]$r23d62DependencyClosureInventoryExtension.threshold_selector_evaluator_or_result_change_count -eq 0 -and
    [int]$r23d62DependencyClosureInventoryExtension.maintenance_process_physical_world_count -eq 0 -and
    [int]$r23d62DependencyClosureInventoryExtension.physical_world_count -eq 0 -and
    -not [bool]$r23d62DependencyClosureInventoryExtension.physical_acceptance_authority -and
    -not [bool]$r23d62DependencyClosureInventoryExtension.release_authority
) "R23D62 dependency-closure provenance classification or inventory extension changed"

foreach ($binding in @(
    @{
        Path = $r23d61FailureReceiptPath
        Sha256 = [string]$r23d61InventoryExtension.initial_failed_full_cold_receipt_raw_sha256
        ByteLength = [long]$r23d61InventoryExtension.initial_failed_full_cold_receipt_byte_length
    },
    @{
        Path = $r23d61FailureStagePath
        Sha256 = [string]$r23d61InventoryExtension.initial_failed_stage_receipt_raw_sha256
        ByteLength = [long]$r23d61InventoryExtension.initial_failed_stage_receipt_byte_length
    },
    @{
        Path = $r23d61FailureExcerptPath
        Sha256 = [string]$r23d61InventoryExtension.initial_failed_failure_excerpt_raw_sha256
        ByteLength = [long]$r23d61InventoryExtension.initial_failed_failure_excerpt_byte_length
    },
    @{
        Path = $r23d61FailureLogPath
        Sha256 = [string]$r23d61InventoryExtension.initial_failed_log_raw_sha256
        ByteLength = [long]$r23d61InventoryExtension.initial_failed_log_byte_length
    }
)) {
    Assert-Exact (
        (Test-Path -LiteralPath $binding.Path -PathType Leaf) -and
        (Get-RawSha256 $binding.Path) -ceq $binding.Sha256 -and
        (Get-Item -LiteralPath $binding.Path).Length -eq $binding.ByteLength
    ) "R23D61 failed clean-pushed provenance evidence changed: $($binding.Path)"
}
$r23d61FailedReceipt = Get-Content -Raw -LiteralPath $r23d61FailureReceiptPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$r23d61FailedTrueClaims = @(
    $r23d61FailedReceipt.claims.GetEnumerator() |
        Where-Object { [bool]$_.Value }
)
Assert-Exact (
    [string]$r23d61FailedReceipt.status -ceq "failed" -and
    [string]$r23d61FailedReceipt.tier -ceq "full_cold" -and
    [string]$r23d61FailedReceipt.source.head -ceq
        "0319dcc39a3454029025d5995168af5f5225ccb0" -and
    [string]$r23d61FailedReceipt.source.origin_main -ceq
        "0319dcc39a3454029025d5995168af5f5225ccb0" -and
    [bool]$r23d61FailedReceipt.source.worktree_clean -and
    @($r23d61FailedReceipt.stage_receipts).Count -eq 1 -and
    [string]$r23d61FailedReceipt.stage_receipts[0].stage_id -ceq
        "authority_and_historical_closures" -and
    [string]$r23d61FailedReceipt.stage_receipts[0].status -ceq "failed" -and
    [double]$r23d61FailedReceipt.duration_seconds -eq 174.7357193 -and
    $r23d61FailedTrueClaims.Count -eq 0
) "R23D61 failed clean-pushed provenance receipt changed"

$r23d61CadReconciliation =
    $contract.inventory.r23d61_postclosure_audit_dependency_reconciliation
$r23d61CadFailureRoot = [IO.Path]::GetFullPath(
    [string]$r23d61CadReconciliation.failed_full_cold_run_root
)
$r23d61CadFailureReceiptPath = Join-Path $r23d61CadFailureRoot "receipt.json"
$r23d61CadFailureStagePath = Join-Path (
    $r23d61CadFailureRoot
) "stages\01-authority_and_historical_closures.json"
$r23d61CadFailureExcerptPath = Join-Path $r23d61CadFailureRoot "failure_excerpt.txt"
$r23d61CadFailureLogPath = Join-Path $r23d61CadFailureRoot "conformance.log"
Assert-Exact (
    [string]$r23d61CadReconciliation.declared_from_provenance_commit -ceq
        "2c44ed6a755227a3306884e3233f2c831a23251b" -and
    [string]$r23d61CadReconciliation.scope -ceq
        "postclosure_zero_world_cad1_cdk1_count_reconciliation_only" -and
    [bool]$r23d61CadReconciliation.failure_observed -and
    [string]$r23d61CadReconciliation.failure_message -ceq
        "Audit-dependency registry no longer reconciles with CEP1." -and
    [double]$r23d61CadReconciliation.failed_duration_seconds -eq 45.7605747 -and
    [string]$r23d61CadReconciliation.failed_source_commit -ceq
        "2c44ed6a755227a3306884e3233f2c831a23251b" -and
    [string]$r23d61CadReconciliation.failed_source_tree -ceq
        "bb33e05bb6f0714aa805c62dfdb6eb507b616e6d" -and
    [bool]$r23d61CadReconciliation.failed_source_worktree_clean -and
    [bool]$r23d61CadReconciliation.failed_source_matched_origin_main -and
    [int]$r23d61CadReconciliation.failed_stage_count -eq 1 -and
    [string]$r23d61CadReconciliation.failed_stage_id -ceq
        "authority_and_historical_closures" -and
    [int]$r23d61CadReconciliation.failed_true_claim_count -eq 0 -and
    -not [bool]$r23d61CadReconciliation.result_reused -and
    [int]$r23d61CadReconciliation.pre_reconciliation_cep1_audit_count -eq 160 -and
    [int]$r23d61CadReconciliation.pre_reconciliation_cad1_audit_count -eq 159 -and
    [int]$r23d61CadReconciliation.pre_reconciliation_cad1_unregistered_audit_count -eq 158 -and
    [int]$r23d61CadReconciliation.post_reconciliation_cep1_audit_count -eq 160 -and
    [int]$r23d61CadReconciliation.post_reconciliation_cad1_audit_count -eq 160 -and
    [int]$r23d61CadReconciliation.post_reconciliation_cad1_registered_audit_count -eq 1 -and
    [int]$r23d61CadReconciliation.post_reconciliation_cad1_complete_audit_count -eq 1 -and
    [int]$r23d61CadReconciliation.post_reconciliation_cad1_unregistered_audit_count -eq 159 -and
    [int]$r23d61CadReconciliation.post_reconciliation_cdk1_audit_count -eq 160 -and
    [int]$r23d61CadReconciliation.post_reconciliation_cdk1_unregistered_audit_count -eq 159 -and
    [int]$r23d61CadReconciliation.dependency_shape_or_registration_change_count -eq 0 -and
    [bool]$r23d61CadReconciliation.qualification_retry_requires_distinct_corrected_clean_pushed_source -and
    [bool]$r23d61CadReconciliation.failed_qualification_retained_non_reusable -and
    -not [bool]$r23d61CadReconciliation.historical_result_or_interpretation_changed -and
    -not [bool]$r23d61CadReconciliation.historical_campaign_reclassification_authorized -and
    [int]$r23d61CadReconciliation.maintenance_process_physical_world_count -eq 0 -and
    -not [bool]$r23d61CadReconciliation.cache_lookup_permitted -and
    -not [bool]$r23d61CadReconciliation.result_reuse_permitted -and
    -not [bool]$r23d61CadReconciliation.physical_acceptance_authority -and
    -not [bool]$r23d61CadReconciliation.release_authority
) "R23D61 postclosure audit-dependency reconciliation changed"

foreach ($binding in @(
    @{
        Path = $r23d61CadFailureReceiptPath
        Sha256 = [string]$r23d61CadReconciliation.failed_full_cold_receipt_raw_sha256
        ByteLength = [long]$r23d61CadReconciliation.failed_full_cold_receipt_byte_length
    },
    @{
        Path = $r23d61CadFailureStagePath
        Sha256 = [string]$r23d61CadReconciliation.failed_stage_receipt_raw_sha256
        ByteLength = [long]$r23d61CadReconciliation.failed_stage_receipt_byte_length
    },
    @{
        Path = $r23d61CadFailureExcerptPath
        Sha256 = [string]$r23d61CadReconciliation.failed_failure_excerpt_raw_sha256
        ByteLength = [long]$r23d61CadReconciliation.failed_failure_excerpt_byte_length
    },
    @{
        Path = $r23d61CadFailureLogPath
        Sha256 = [string]$r23d61CadReconciliation.failed_log_raw_sha256
        ByteLength = [long]$r23d61CadReconciliation.failed_log_byte_length
    }
)) {
    Assert-Exact (
        (Test-Path -LiteralPath $binding.Path -PathType Leaf) -and
        (Get-RawSha256 $binding.Path) -ceq $binding.Sha256 -and
        (Get-Item -LiteralPath $binding.Path).Length -eq $binding.ByteLength
    ) "R23D61 CAD1 failed clean-pushed evidence changed: $($binding.Path)"
}
$r23d61CadFailedReceipt =
    Get-Content -Raw -LiteralPath $r23d61CadFailureReceiptPath |
        ConvertFrom-Json -AsHashtable -Depth 100
$r23d61CadFailedTrueClaims = @(
    $r23d61CadFailedReceipt.claims.GetEnumerator() |
        Where-Object { [bool]$_.Value }
)
Assert-Exact (
    [string]$r23d61CadFailedReceipt.status -ceq "failed" -and
    [string]$r23d61CadFailedReceipt.tier -ceq "full_cold" -and
    [string]$r23d61CadFailedReceipt.source.head -ceq
        "2c44ed6a755227a3306884e3233f2c831a23251b" -and
    [string]$r23d61CadFailedReceipt.source.head_tree -ceq
        "bb33e05bb6f0714aa805c62dfdb6eb507b616e6d" -and
    [string]$r23d61CadFailedReceipt.source.origin_main -ceq
        "2c44ed6a755227a3306884e3233f2c831a23251b" -and
    [bool]$r23d61CadFailedReceipt.source.worktree_clean -and
    -not [bool]$r23d61CadFailedReceipt.cache.result_reused -and
    @($r23d61CadFailedReceipt.stage_receipts).Count -eq 1 -and
    [string]$r23d61CadFailedReceipt.stage_receipts[0].stage_id -ceq
        "authority_and_historical_closures" -and
    [string]$r23d61CadFailedReceipt.stage_receipts[0].status -ceq "failed" -and
    [string]$r23d61CadFailedReceipt.failure.message -ceq
        "Audit-dependency registry no longer reconciles with CEP1." -and
    [double]$r23d61CadFailedReceipt.duration_seconds -eq 45.7605747 -and
    $r23d61CadFailedTrueClaims.Count -eq 0
) "R23D61 CAD1 failed clean-pushed receipt changed"

Assert-Exact (
    $lca1Commissioning.Count -eq 1 -and
    [string]$lca1Commissioning[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($lca1Commissioning[0].detected_modes) -ccontains "cas_path_check" -and
    @($lca1Commissioning[0].detected_modes) -ccontains "pinned_git_blob" -and
    @($lca1Commissioning[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    -not [bool]$lca1Commissioning[0].live_historical_identity_risk -and
    -not [bool]$lca1Commissioning[0].manual_review_required
) "LCA1 commissioning closure provenance classification changed"
Assert-Exact (
    $lca1ReusableRecommissioning.Count -eq 1 -and
    [string]$lca1ReusableRecommissioning[0].raw_sha256 -ceq
        "257423b0b4c0ea3c50e578e50e7e7eaa879998e15de0397bd6398a0db2041631" -and
    [string]$lca1ReusableRecommissioning[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($lca1ReusableRecommissioning[0].detected_modes) -ccontains
        "cas_path_check" -and
    @($lca1ReusableRecommissioning[0].detected_modes) -ccontains
        "pinned_git_blob" -and
    @($lca1ReusableRecommissioning[0].detected_modes) -ccontains
        "retained_evidence_bytes" -and
    @($lca1ReusableRecommissioning[0].detected_modes) -ccontains
        "live_runtime_safety_check" -and
    -not [bool]$lca1ReusableRecommissioning[0].live_historical_identity_risk -and
    -not [bool]$lca1ReusableRecommissioning[0].manual_review_required
) "LCA1 reusable recommissioning closure provenance classification changed"

$r23d62PostRc12Maintenance =
    $contract.inventory.r23d62_post_rc12_qualification_inventory_hash_maintenance
Assert-Exact (
    [string]$r23d62PostRc12Maintenance.qualification_process_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$r23d62PostRc12Maintenance.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$r23d62PostRc12Maintenance.scope -ceq
        "existing_lca1_recommissioning_closure_audit_raw_hash_refresh_only" -and
    [string]$r23d62PostRc12Maintenance.declared_from_failed_clean_pushed_source_commit -ceq
        "f55930f881560aa5398d2527e8fb30fdb780c7ae" -and
    [string]$r23d62PostRc12Maintenance.declared_from_failed_clean_pushed_source_tree_git_oid -ceq
        "dfb3f323341a86b14b6ea3cd0d5fcc76722e399d" -and
    [bool]$r23d62PostRc12Maintenance.initial_inventory_failure_observed -and
    [string]$r23d62PostRc12Maintenance.initial_inventory_failure_message -ceq
        "Closure evidence-mode executable inventory verification failed" -and
    [string]$r23d62PostRc12Maintenance.initial_failed_qualification_root -ceq
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r23d62-qualification-20260825T033717Z-f55930f8" -and
    [string]$r23d62PostRc12Maintenance.initial_failed_qualification_failure_raw_sha256 -ceq
        "5ed3c4bdf569fb7570f57b540518857eaa333ff814c3381ed20c86b05a0d78cd" -and
    [long]$r23d62PostRc12Maintenance.initial_failed_qualification_failure_byte_length -eq 628 -and
    [string]$r23d62PostRc12Maintenance.initial_failed_provenance_gate_receipt_raw_sha256 -ceq
        "0181d05e07de83640a1d548bfa91a90d4b98a8af0dd474b216d1017231f3c214" -and
    [long]$r23d62PostRc12Maintenance.initial_failed_provenance_gate_receipt_byte_length -eq 2707 -and
    [string]$r23d62PostRc12Maintenance.initial_failed_provenance_gate_stderr_raw_sha256 -ceq
        "b28acb33c56b6a6174983302ef2fa32bb65da482b57742e30169984c7dd04f48" -and
    [long]$r23d62PostRc12Maintenance.initial_failed_provenance_gate_stderr_byte_length -eq 251 -and
    [int]$r23d62PostRc12Maintenance.initial_failed_qualification_retained_file_count -eq 13 -and
    [long]$r23d62PostRc12Maintenance.initial_failed_qualification_retained_byte_count -eq 12675 -and
    [int]$r23d62PostRc12Maintenance.initial_failed_qualification_passed_gate_count -eq 3 -and
    [string]$r23d62PostRc12Maintenance.initial_failed_qualification_failure_gate_id -ceq
        "CAK1-EVIDENCE-PROVENANCE" -and
    [int]$r23d62PostRc12Maintenance.initial_failed_qualification_campaign_role_gate_count -eq 0 -and
    [int]$r23d62PostRc12Maintenance.initial_failed_qualification_model_construction_count -eq 0 -and
    [int]$r23d62PostRc12Maintenance.initial_failed_qualification_world_attempt_count -eq 0 -and
    [int]$r23d62PostRc12Maintenance.initial_failed_qualification_world_build_count -eq 0 -and
    [int]$r23d62PostRc12Maintenance.inventory_population_size -eq 167 -and
    [bool]$r23d62PostRc12Maintenance.inventory_population_compared_completely -and
    [int]$r23d62PostRc12Maintenance.inventory_sample_size -eq 167 -and
    -not [bool]$r23d62PostRc12Maintenance.inventory_sampling_claimed -and
    [int]$r23d62PostRc12Maintenance.pre_maintenance_audit_count -eq 167 -and
    [int]$r23d62PostRc12Maintenance.post_maintenance_audit_count -eq 167 -and
    [int]$r23d62PostRc12Maintenance.audit_count_delta -eq 0 -and
    [int]$r23d62PostRc12Maintenance.cas_path_check_signature_count_delta -eq 0 -and
    [int]$r23d62PostRc12Maintenance.pinned_git_blob_signature_count_delta -eq 0 -and
    [int]$r23d62PostRc12Maintenance.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r23d62PostRc12Maintenance.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r23d62PostRc12Maintenance.manual_review_required_count_delta -eq 0 -and
    [int]$r23d62PostRc12Maintenance.changed_entry_count -eq 1 -and
    [string]$r23d62PostRc12Maintenance.changed_entry_path -ceq
        "tests/test_locomotion_campaign_attestation_recommissioning_closure.ps1" -and
    [string]$r23d62PostRc12Maintenance.pre_maintenance_raw_sha256 -ceq
        "dff0e6b44eee7c9673d3708291edf25d22df0bf8fbb9ba9961a8244dc46f31e7" -and
    [string]$r23d62PostRc12Maintenance.post_maintenance_raw_sha256 -ceq
        "257423b0b4c0ea3c50e578e50e7e7eaa879998e15de0397bd6398a0db2041631" -and
    [int]$r23d62PostRc12Maintenance.prospective_live_authority_status_consumer_reconciliation_count -eq 4 -and
    (@($r23d62PostRc12Maintenance.prospective_live_authority_status_consumer_paths) -join "|") -ceq
        "tests/test_qsdk_r23d62_godot_public_profile_physical_route.py|tests/test_qsdk_r23d62_rapier_public_profile_physical_route.py|tests/test_qsdk_r23d62_mujoco_public_profile_physical_route.py|sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d62_selected_profile_turning_test.py" -and
    [int]$r23d62PostRc12Maintenance.prospective_implementation_hash_binding_refresh_count -eq 3 -and
    [int]$r23d62PostRc12Maintenance.prospective_release_support_hash_field_refresh_count -eq 8 -and
    [int]$r23d62PostRc12Maintenance.prospective_workbench_proof_binding_refresh_count -eq 4 -and
    [int]$r23d62PostRc12Maintenance.prospective_route_worker_controller_physics_or_evaluator_semantics_change_count -eq 0 -and
    [string]$r23d62PostRc12Maintenance.historical_identity_mode_before -ceq
        "pinned_git_blob" -and
    [string]$r23d62PostRc12Maintenance.historical_identity_mode_after -ceq
        "pinned_git_blob" -and
    (@($r23d62PostRc12Maintenance.detected_modes_before) -join "|") -ceq
        "cas_path_check|pinned_git_blob|retained_evidence_bytes|live_repo_or_checkout_hash|live_runtime_safety_check" -and
    (@($r23d62PostRc12Maintenance.detected_modes_after) -join "|") -ceq
        "cas_path_check|pinned_git_blob|retained_evidence_bytes|live_repo_or_checkout_hash|live_runtime_safety_check" -and
    -not [bool]$r23d62PostRc12Maintenance.live_historical_identity_risk_before -and
    -not [bool]$r23d62PostRc12Maintenance.live_historical_identity_risk_after -and
    -not [bool]$r23d62PostRc12Maintenance.manual_review_required_before -and
    -not [bool]$r23d62PostRc12Maintenance.manual_review_required_after -and
    [string]$r23d62PostRc12Maintenance.threshold_origin -ceq
        "exact_sha256_and_complete_inventory_object_equality_no_statistical_threshold" -and
    [int]$r23d62PostRc12Maintenance.equivalence_margin -eq 0 -and
    [int]$r23d62PostRc12Maintenance.non_inferiority_margin -eq 0 -and
    [bool]$r23d62PostRc12Maintenance.failed_qualification_retained -and
    -not [bool]$r23d62PostRc12Maintenance.failed_qualification_reusable -and
    [bool]$r23d62PostRc12Maintenance.qualification_retry_requires_distinct_corrected_clean_pushed_source -and
    -not [bool]$r23d62PostRc12Maintenance.historical_campaign_result_created -and
    -not [bool]$r23d62PostRc12Maintenance.historical_campaign_reclassification_authorized -and
    [int]$r23d62PostRc12Maintenance.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$r23d62PostRc12Maintenance.maintenance_process_physical_world_count -eq 0 -and
    [int]$r23d62PostRc12Maintenance.r23d62_physical_world_count -eq 0 -and
    -not [bool]$r23d62PostRc12Maintenance.r23d62_turning_claim_changed -and
    -not [bool]$r23d62PostRc12Maintenance.cross_engine_equivalence_claimed -and
    -not [bool]$r23d62PostRc12Maintenance.prone_to_standing_claimed -and
    -not [bool]$r23d62PostRc12Maintenance.physical_acceptance_authority -and
    -not [bool]$r23d62PostRc12Maintenance.release_authority
) "R23D62 post-RC12 qualification provenance maintenance changed"
foreach ($binding in @(
    @{
        Path = [string]$r23d62PostRc12Maintenance.initial_failed_qualification_failure_path
        Sha256 = [string]$r23d62PostRc12Maintenance.initial_failed_qualification_failure_raw_sha256
        ByteLength = [long]$r23d62PostRc12Maintenance.initial_failed_qualification_failure_byte_length
    },
    @{
        Path = [string]$r23d62PostRc12Maintenance.initial_failed_provenance_gate_receipt_path
        Sha256 = [string]$r23d62PostRc12Maintenance.initial_failed_provenance_gate_receipt_raw_sha256
        ByteLength = [long]$r23d62PostRc12Maintenance.initial_failed_provenance_gate_receipt_byte_length
    },
    @{
        Path = [string]$r23d62PostRc12Maintenance.initial_failed_provenance_gate_stderr_path
        Sha256 = [string]$r23d62PostRc12Maintenance.initial_failed_provenance_gate_stderr_raw_sha256
        ByteLength = [long]$r23d62PostRc12Maintenance.initial_failed_provenance_gate_stderr_byte_length
    }
)) {
    Assert-Exact (Test-Path -LiteralPath $binding.Path -PathType Leaf) (
        "R23D62 retained post-RC12 qualification evidence missing: $($binding.Path)"
    )
    $retainedFile = Get-Item -LiteralPath $binding.Path
    Assert-Exact (
        [long]$retainedFile.Length -eq [long]$binding.ByteLength -and
        (Get-RawSha256 -Path $binding.Path) -ceq [string]$binding.Sha256
    ) "R23D62 retained post-RC12 qualification evidence bytes changed: $($binding.Path)"
}

$r23d63QualificationExtension =
    $contract.inventory.r23d63_post_freeze_qualification_inventory_extension
$r23d63AddedEntries = @($r23d63QualificationExtension.added_entries)
Assert-Exact (
    [string]$r23d63QualificationExtension.qualification_process_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$r23d63QualificationExtension.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$r23d63QualificationExtension.scope -ceq
        "complete_closure_audit_population_extension_for_retained_r23d62_physical_closure_and_r23d63_dependency_closure" -and
    [string]$r23d63QualificationExtension.declared_from_failed_clean_pushed_source_commit -ceq
        "2918e29d4899d785b4c8b7ca148e0aaf60264aa6" -and
    [string]$r23d63QualificationExtension.declared_from_failed_clean_pushed_source_tree_git_oid -ceq
        "1d866ceab93cb5eb764a8c5fc59cb8bccc033cbb" -and
    [bool]$r23d63QualificationExtension.initial_inventory_failure_observed -and
    [string]$r23d63QualificationExtension.initial_inventory_failure_message -ceq
        "Closure evidence-mode executable inventory verification failed" -and
    [string]$r23d63QualificationExtension.initial_failed_qualification_root -ceq
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r23d63-qualification-20260825T075836Z-2918e29d" -and
    [int]$r23d63QualificationExtension.initial_failed_qualification_retained_file_count -eq 13 -and
    [long]$r23d63QualificationExtension.initial_failed_qualification_retained_byte_count -eq 12698 -and
    [int]$r23d63QualificationExtension.initial_failed_qualification_passed_gate_count -eq 3 -and
    [string]$r23d63QualificationExtension.initial_failed_qualification_failure_gate_id -ceq
        "CAK1-EVIDENCE-PROVENANCE" -and
    [int]$r23d63QualificationExtension.initial_failed_qualification_campaign_role_gate_count -eq 0 -and
    [int]$r23d63QualificationExtension.initial_failed_qualification_model_construction_count -eq 0 -and
    [int]$r23d63QualificationExtension.initial_failed_qualification_world_attempt_count -eq 0 -and
    [int]$r23d63QualificationExtension.initial_failed_qualification_world_build_count -eq 0 -and
    [int]$r23d63QualificationExtension.inventory_population_size -eq 169 -and
    [bool]$r23d63QualificationExtension.inventory_population_compared_completely -and
    [int]$r23d63QualificationExtension.inventory_sample_size -eq 169 -and
    -not [bool]$r23d63QualificationExtension.inventory_sampling_claimed -and
    [int]$r23d63QualificationExtension.pre_extension_audit_count -eq 167 -and
    [int]$r23d63QualificationExtension.post_extension_audit_count -eq 169 -and
    [int]$r23d63QualificationExtension.added_audit_count -eq 2 -and
    [int]$r23d63QualificationExtension.changed_audit_count -eq 0 -and
    [int]$r23d63QualificationExtension.removed_audit_count -eq 0 -and
    [int]$r23d63QualificationExtension.cas_path_check_signature_count_delta -eq 2 -and
    [int]$r23d63QualificationExtension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$r23d63QualificationExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r23d63QualificationExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r23d63QualificationExtension.manual_review_required_count_delta -eq 1 -and
    $r23d63AddedEntries.Count -eq 2 -and
    (@($r23d63AddedEntries.path) -join "|") -ceq
        "tests/test_qsdk_r23d62_physical_closure.ps1|tests/test_qsdk_r23d63_dependency_closure.ps1" -and
    [string]$r23d63QualificationExtension.threshold_origin -ceq
        "exact_complete_inventory_object_comparison_no_statistical_threshold" -and
    [int]$r23d63QualificationExtension.equivalence_margin -eq 0 -and
    [int]$r23d63QualificationExtension.non_inferiority_margin -eq 0 -and
    [bool]$r23d63QualificationExtension.failed_qualification_retained -and
    -not [bool]$r23d63QualificationExtension.failed_qualification_reusable -and
    [bool]$r23d63QualificationExtension.qualification_retry_requires_distinct_corrected_clean_pushed_source -and
    -not [bool]$r23d63QualificationExtension.physical_attempt_identity_consumed -and
    -not [bool]$r23d63QualificationExtension.historical_campaign_result_created -and
    -not [bool]$r23d63QualificationExtension.historical_campaign_reclassification_authorized -and
    [int]$r23d63QualificationExtension.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$r23d63QualificationExtension.route_worker_controller_physics_or_evaluator_semantics_change_count -eq 0 -and
    [int]$r23d63QualificationExtension.maintenance_process_physical_world_count -eq 0 -and
    [int]$r23d63QualificationExtension.r23d63_physical_world_count -eq 0 -and
    -not [bool]$r23d63QualificationExtension.r23d63_turning_claim_changed -and
    -not [bool]$r23d63QualificationExtension.cross_engine_equivalence_claimed -and
    -not [bool]$r23d63QualificationExtension.prone_to_standing_claimed -and
    -not [bool]$r23d63QualificationExtension.physical_acceptance_authority -and
    -not [bool]$r23d63QualificationExtension.release_authority
) "R23D63 post-freeze qualification inventory extension changed"
foreach ($declaredEntry in $r23d63AddedEntries) {
    $inventoryEntry = @($inventory.entries | Where-Object {
        [string]$_.path -ceq [string]$declaredEntry.path
    })
    Assert-Exact (
        $inventoryEntry.Count -eq 1 -and
        ($inventoryEntry[0] | ConvertTo-Json -Depth 20 -Compress) -ceq
            ($declaredEntry | ConvertTo-Json -Depth 20 -Compress)
    ) "R23D63 declared inventory entry differs from the complete inventory: $($declaredEntry.path)"
}
$r23d63FailedRoot = [string]$r23d63QualificationExtension.initial_failed_qualification_root
$r23d63FailedRootFiles = @(Get-ChildItem -LiteralPath $r23d63FailedRoot -File)
Assert-Exact (
    $r23d63FailedRootFiles.Count -eq
        [int]$r23d63QualificationExtension.initial_failed_qualification_retained_file_count -and
    [long]($r23d63FailedRootFiles | Measure-Object Length -Sum).Sum -eq
        [long]$r23d63QualificationExtension.initial_failed_qualification_retained_byte_count
) "R23D63 retained failed qualification root changed"
foreach ($binding in @(
    @{
        Path = [string]$r23d63QualificationExtension.initial_failed_qualification_failure_path
        Sha256 = [string]$r23d63QualificationExtension.initial_failed_qualification_failure_raw_sha256
        ByteLength = [long]$r23d63QualificationExtension.initial_failed_qualification_failure_byte_length
    },
    @{
        Path = [string]$r23d63QualificationExtension.initial_failed_provenance_gate_receipt_path
        Sha256 = [string]$r23d63QualificationExtension.initial_failed_provenance_gate_receipt_raw_sha256
        ByteLength = [long]$r23d63QualificationExtension.initial_failed_provenance_gate_receipt_byte_length
    },
    @{
        Path = [string]$r23d63QualificationExtension.initial_failed_provenance_gate_stderr_path
        Sha256 = [string]$r23d63QualificationExtension.initial_failed_provenance_gate_stderr_raw_sha256
        ByteLength = [long]$r23d63QualificationExtension.initial_failed_provenance_gate_stderr_byte_length
    }
)) {
    Assert-Exact (Test-Path -LiteralPath $binding.Path -PathType Leaf) (
        "R23D63 retained failed qualification evidence is missing: $($binding.Path)"
    )
    $retainedFile = Get-Item -LiteralPath $binding.Path
    Assert-Exact (
        [long]$retainedFile.Length -eq [long]$binding.ByteLength -and
        (Get-RawSha256 -Path $binding.Path) -ceq [string]$binding.Sha256
    ) "R23D63 retained failed qualification evidence bytes changed: $($binding.Path)"
}

$r23d63PhysicalClosureExtension =
    $contract.inventory.r23d63_physical_closure_inventory_extension
$r23d63PhysicalClosureAddedEntries = @(
    $r23d63PhysicalClosureExtension.added_entries
)
Assert-Exact (
    [string]$r23d63PhysicalClosureExtension.maintenance_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$r23d63PhysicalClosureExtension.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$r23d63PhysicalClosureExtension.scope -ceq
        "complete_closure_audit_population_extension_for_retained_r23d63_invalid_incomplete_pre_world_attempt" -and
    [string]$r23d63PhysicalClosureExtension.physical_source_commit -ceq
        "649277e3abc8cfd481cfc6cd22719f32ebc9a332" -and
    [string]$r23d63PhysicalClosureExtension.physical_source_tree_git_oid -ceq
        "0e6aed54cb392354b87b5269e0a49055f767af9b" -and
    [string]$r23d63PhysicalClosureExtension.attempt_id -ceq
        "a48bcdec043e453497d1097754d47630" -and
    [bool]$r23d63PhysicalClosureExtension.physical_attempt_identity_consumed -and
    [string]$r23d63PhysicalClosureExtension.physical_attempt_status -ceq
        "invalid_or_incomplete_first_attempt" -and
    [int]$r23d63PhysicalClosureExtension.physical_world_count -eq 0 -and
    [int]$r23d63PhysicalClosureExtension.inventory_population_size -eq 170 -and
    [bool]$r23d63PhysicalClosureExtension.inventory_population_compared_completely -and
    [int]$r23d63PhysicalClosureExtension.inventory_sample_size -eq 170 -and
    -not [bool]$r23d63PhysicalClosureExtension.inventory_sampling_claimed -and
    [int]$r23d63PhysicalClosureExtension.pre_extension_audit_count -eq 169 -and
    [int]$r23d63PhysicalClosureExtension.post_extension_audit_count -eq 170 -and
    [int]$r23d63PhysicalClosureExtension.added_audit_count -eq 1 -and
    [int]$r23d63PhysicalClosureExtension.changed_audit_count -eq 0 -and
    [int]$r23d63PhysicalClosureExtension.removed_audit_count -eq 0 -and
    [int]$r23d63PhysicalClosureExtension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$r23d63PhysicalClosureExtension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$r23d63PhysicalClosureExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r23d63PhysicalClosureExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r23d63PhysicalClosureExtension.manual_review_required_count_delta -eq 0 -and
    $r23d63PhysicalClosureAddedEntries.Count -eq 1 -and
    [string]$r23d63PhysicalClosureAddedEntries[0].path -ceq
        "tests/test_qsdk_r23d63_physical_closure.ps1" -and
    [string]$r23d63PhysicalClosureAddedEntries[0].raw_sha256 -ceq
        "4f9ad16e22e208a0c4816348f73dd3723018abceb6055fb73d01bf1d7199eb80" -and
    [string]$r23d63PhysicalClosureExtension.threshold_origin -ceq
        "exact_complete_inventory_object_comparison_no_statistical_threshold" -and
    [int]$r23d63PhysicalClosureExtension.equivalence_margin -eq 0 -and
    [int]$r23d63PhysicalClosureExtension.non_inferiority_margin -eq 0 -and
    [string]$r23d63PhysicalClosureExtension.r23d63_closure_path -ceq
        "sdk/turning/r23d63_selected_profile_three_engine_turning_validation_closure_v1.json" -and
    [string]$r23d63PhysicalClosureExtension.r23d63_closure_raw_sha256 -ceq
        "f69fb663cfc98d98f171311896025abd1cbfeba582be55616a0abecdeaa4acdb" -and
    [string]$r23d63PhysicalClosureExtension.r23d63_closure_audit_path -ceq
        "tests/test_qsdk_r23d63_physical_closure.ps1" -and
    [string]$r23d63PhysicalClosureExtension.r23d63_closure_audit_raw_sha256 -ceq
        "4f9ad16e22e208a0c4816348f73dd3723018abceb6055fb73d01bf1d7199eb80" -and
    [bool]$r23d63PhysicalClosureExtension.r23d63_closure_passed -and
    [bool]$r23d63PhysicalClosureExtension.campaign_identity_consumed -and
    -not [bool]$r23d63PhysicalClosureExtension.same_identity_rerun_allowed -and
    -not [bool]$r23d63PhysicalClosureExtension.historical_campaign_result_created -and
    -not [bool]$r23d63PhysicalClosureExtension.historical_campaign_reclassification_authorized -and
    [int]$r23d63PhysicalClosureExtension.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$r23d63PhysicalClosureExtension.route_worker_controller_physics_or_evaluator_semantics_change_count -eq 0 -and
    [int]$r23d63PhysicalClosureExtension.maintenance_process_physical_world_count -eq 0 -and
    -not [bool]$r23d63PhysicalClosureExtension.r23d63_turning_claim_changed -and
    -not [bool]$r23d63PhysicalClosureExtension.q_sdk_r23_satisfied -and
    -not [bool]$r23d63PhysicalClosureExtension.cross_engine_equivalence_claimed -and
    -not [bool]$r23d63PhysicalClosureExtension.prone_to_standing_claimed -and
    -not [bool]$r23d63PhysicalClosureExtension.physical_acceptance_authority -and
    -not [bool]$r23d63PhysicalClosureExtension.release_authority
) "R23D63 physical-closure inventory extension changed"
$r23d63PhysicalInventoryEntry = @($inventory.entries | Where-Object {
    [string]$_.path -ceq [string]$r23d63PhysicalClosureAddedEntries[0].path
})
Assert-Exact (
    $r23d63PhysicalInventoryEntry.Count -eq 1 -and
    ($r23d63PhysicalInventoryEntry[0] | ConvertTo-Json -Depth 20 -Compress) -ceq
        ($r23d63PhysicalClosureAddedEntries[0] | ConvertTo-Json -Depth 20 -Compress)
) "R23D63 physical-closure entry differs from the complete inventory"

$r23d64DependencyClosureExtension =
    $contract.inventory.r23d64_dependency_closure_inventory_extension
$r23d64DependencyClosureAddedEntries = @(
    $r23d64DependencyClosureExtension.added_entries
)
Assert-Exact (
    [string]$r23d64DependencyClosureExtension.maintenance_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$r23d64DependencyClosureExtension.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$r23d64DependencyClosureExtension.scope -ceq
        "complete_closure_audit_population_extension_for_r23d64_prospective_zero_world_dependency_closure" -and
    [string]$r23d64DependencyClosureExtension.declared_from_verified_parent_commit -ceq
        "3d48f06dd22825c5aef7c638e64eb1788023795a" -and
    [string]$r23d64DependencyClosureExtension.declaration_source_state -ceq
        "prospective_uncommitted_successor_worktree_on_verified_parent" -and
    [bool]$r23d64DependencyClosureExtension.inventory_delta_measured_before_update -and
    -not [bool]$r23d64DependencyClosureExtension.initial_inventory_failure_observed -and
    [int]$r23d64DependencyClosureExtension.physical_world_count -eq 0 -and
    [int]$r23d64DependencyClosureExtension.inventory_population_size -eq 171 -and
    [bool]$r23d64DependencyClosureExtension.inventory_population_compared_completely -and
    [int]$r23d64DependencyClosureExtension.inventory_sample_size -eq 171 -and
    -not [bool]$r23d64DependencyClosureExtension.inventory_sampling_claimed -and
    [int]$r23d64DependencyClosureExtension.pre_extension_audit_count -eq 170 -and
    [int]$r23d64DependencyClosureExtension.post_extension_audit_count -eq 171 -and
    [int]$r23d64DependencyClosureExtension.added_audit_count -eq 1 -and
    [int]$r23d64DependencyClosureExtension.changed_audit_count -eq 0 -and
    [int]$r23d64DependencyClosureExtension.removed_audit_count -eq 0 -and
    [int]$r23d64DependencyClosureExtension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$r23d64DependencyClosureExtension.pinned_git_blob_signature_count_delta -eq 0 -and
    [int]$r23d64DependencyClosureExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r23d64DependencyClosureExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r23d64DependencyClosureExtension.manual_review_required_count_delta -eq 1 -and
    $r23d64DependencyClosureAddedEntries.Count -eq 1 -and
    [string]$r23d64DependencyClosureAddedEntries[0].path -ceq
        "tests/test_qsdk_r23d64_dependency_closure.ps1" -and
    [string]$r23d64DependencyClosureAddedEntries[0].raw_sha256 -ceq
        "c8f76a2c6ac233ea533c908fa96e4eadaf124500f5c5c18875cf4da8060ae703" -and
    [string]$r23d64DependencyClosureAddedEntries[0].historical_identity_mode -ceq
        "record_retained_evidence_or_manual_review" -and
    @($r23d64DependencyClosureAddedEntries[0].detected_modes).Count -eq 1 -and
    [string]$r23d64DependencyClosureAddedEntries[0].detected_modes[0] -ceq
        "cas_path_check" -and
    -not [bool]$r23d64DependencyClosureAddedEntries[0].live_historical_identity_risk -and
    [bool]$r23d64DependencyClosureAddedEntries[0].manual_review_required -and
    [string]$r23d64DependencyClosureExtension.manual_review_disposition -ceq
        "the_r23d64_entry_is_a_prospective_recursive_dependency_omission_and_structure_mutation_gate_not_a_historical_result_identity" -and
    [string]$r23d64DependencyClosureExtension.threshold_origin -ceq
        "exact_complete_inventory_object_comparison_no_statistical_threshold" -and
    [int]$r23d64DependencyClosureExtension.equivalence_margin -eq 0 -and
    [int]$r23d64DependencyClosureExtension.non_inferiority_margin -eq 0 -and
    -not [bool]$r23d64DependencyClosureExtension.historical_campaign_result_created -and
    -not [bool]$r23d64DependencyClosureExtension.historical_campaign_reclassification_authorized -and
    [int]$r23d64DependencyClosureExtension.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$r23d64DependencyClosureExtension.route_worker_controller_physics_or_evaluator_semantics_change_count -eq 0 -and
    [int]$r23d64DependencyClosureExtension.maintenance_process_physical_world_count -eq 0 -and
    [int]$r23d64DependencyClosureExtension.r23d64_physical_world_count -eq 0 -and
    -not [bool]$r23d64DependencyClosureExtension.r23d64_turning_claim_changed -and
    -not [bool]$r23d64DependencyClosureExtension.q_sdk_r23_satisfied -and
    -not [bool]$r23d64DependencyClosureExtension.cross_engine_equivalence_claimed -and
    -not [bool]$r23d64DependencyClosureExtension.prone_to_standing_claimed -and
    -not [bool]$r23d64DependencyClosureExtension.physical_acceptance_authority -and
    -not [bool]$r23d64DependencyClosureExtension.release_authority
) "R23D64 dependency-closure inventory extension changed"
$r23d64DependencyClosureInventoryEntry = @($inventory.entries | Where-Object {
    [string]$_.path -ceq [string]$r23d64DependencyClosureAddedEntries[0].path
})
Assert-Exact (
    $r23d64DependencyClosureInventoryEntry.Count -eq 1 -and
    ($r23d64DependencyClosureInventoryEntry[0] | ConvertTo-Json -Depth 20 -Compress) -ceq
        ($r23d64DependencyClosureAddedEntries[0] | ConvertTo-Json -Depth 20 -Compress)
) "R23D64 dependency-closure entry differs from the complete inventory"

$r23d64FirstQualification =
    $contract.inventory.r23d64_first_scoped_qualification_runtime_dependency_failure
$r23d64RetainedBindings = @($r23d64FirstQualification.retained_files)
Assert-Exact (
    [string]$r23d64FirstQualification.qualification_process_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$r23d64FirstQualification.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$r23d64FirstQualification.scope -ceq
        "complete_retained_first_r23d64_scoped_qualification_file_population_and_runtime_dependency_failure" -and
    [string]$r23d64FirstQualification.source_commit -ceq
        "d1b3f9bfb06cac1418f11ee671a2126d59fb2bd8" -and
    [string]$r23d64FirstQualification.source_tree_git_oid -ceq
        "87ffab964deb73f229e3f0fdbaf97480b4ca0835" -and
    [string]$r23d64FirstQualification.status -ceq
        "failed_incomplete_lineage_runtime_dependency_binding" -and
    [string]$r23d64FirstQualification.qualification_root -ceq
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r23d64-qualification-20260825T105952Z-d1b3f9bf" -and
    [string]$r23d64FirstQualification.failure_message -ceq
        "Campaign-local attestation gate failed: R23D64-AUTHORIZATION-RECEIPT-SCHEMA-CONFORMANCE exit=1 timeout=False marker_count=0" -and
    [string]$r23d64FirstQualification.failed_gate_id -ceq
        "R23D64-AUTHORIZATION-RECEIPT-SCHEMA-CONFORMANCE" -and
    [string]$r23d64FirstQualification.failed_gate_error -ceq
        "ModuleNotFoundError: No module named 'mujoco'" -and
    [int]$r23d64FirstQualification.original_attestation_output_file_count -eq 46 -and
    [long]$r23d64FirstQualification.original_attestation_output_byte_count -eq 338175 -and
    [int]$r23d64FirstQualification.retained_file_count -eq 47 -and
    [long]$r23d64FirstQualification.retained_byte_count -eq 341615 -and
    [bool]$r23d64FirstQualification.retained_file_population_compared_completely -and
    [int]$r23d64FirstQualification.retained_file_sample_size -eq 47 -and
    -not [bool]$r23d64FirstQualification.retained_file_sampling_claimed -and
    $r23d64RetainedBindings.Count -eq 47 -and
    [int]$r23d64FirstQualification.passed_gate_count -eq 14 -and
    [int]$r23d64FirstQualification.passed_global_gate_count -eq 12 -and
    [int]$r23d64FirstQualification.passed_lineage_gate_count -eq 2 -and
    [int]$r23d64FirstQualification.failed_lineage_gate_count -eq 1 -and
    [int]$r23d64FirstQualification.campaign_role_gate_count -eq 0 -and
    [int]$r23d64FirstQualification.model_construction_count -eq 0 -and
    [int]$r23d64FirstQualification.world_attempt_count -eq 0 -and
    [int]$r23d64FirstQualification.world_build_count -eq 0 -and
    [int]$r23d64FirstQualification.solver_step_count -eq 0 -and
    -not [bool]$r23d64FirstQualification.physical_attempt_identity_consumed -and
    -not [bool]$r23d64FirstQualification.failed_qualification_reusable -and
    [bool]$r23d64FirstQualification.qualification_retry_requires_distinct_corrected_clean_pushed_source
) "R23D64 first scoped qualification identity or complete-population declaration changed"
Assert-Exact (
    [bool]$r23d64FirstQualification.runtime_dependency_diagnosis.lineage_gate_was_invoked_directly_by_campaign_attestation -and
    [string]$r23d64FirstQualification.runtime_dependency_diagnosis.explicit_python_host -ceq
        "C:/Program Files/Python311/python.exe" -and
    [bool]$r23d64FirstQualification.runtime_dependency_diagnosis.caller_pythonpath_was_empty -and
    -not [bool]$r23d64FirstQualification.runtime_dependency_diagnosis.gate_self_bound_mujoco_site_packages_before_failure -and
    [bool]$r23d64FirstQualification.runtime_dependency_diagnosis.supervisor_only_inherited_pythonpath_assumption_exposed -and
    -not [bool]$r23d64FirstQualification.runtime_dependency_diagnosis.physics_or_turning_evaluator_reached
) "R23D64 first scoped qualification runtime-dependency diagnosis changed"
Assert-Exact (
    [string]$r23d64FirstQualification.prospective_repair_boundary.question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$r23d64FirstQualification.prospective_repair_boundary.population -ceq
        "complete_locked_mujoco_python_environment_and_both_empty_or_non_empty_caller_pythonpath_compositions" -and
    [bool]$r23d64FirstQualification.prospective_repair_boundary.population_compared_completely -and
    -not [bool]$r23d64FirstQualification.prospective_repair_boundary.sampling_used -and
    [int]$r23d64FirstQualification.prospective_repair_boundary.locked_distribution_count -eq 9 -and
    [int]$r23d64FirstQualification.prospective_repair_boundary.locked_distribution_file_count -eq 8094 -and
    [long]$r23d64FirstQualification.prospective_repair_boundary.locked_distribution_byte_count -eq 131440050 -and
    [string]$r23d64FirstQualification.prospective_repair_boundary.locked_environment_manifest_sha256 -ceq
        "95ea9d7f02a82fc84f62b04cf3c3a7415b62ccab4d04cb56cd12df7cd7696f68" -and
    [int]$r23d64FirstQualification.prospective_repair_boundary.caller_pythonpath_composition_control_count -eq 2 -and
    [int]$r23d64FirstQualification.prospective_repair_boundary.equivalence_margin -eq 0 -and
    [int]$r23d64FirstQualification.prospective_repair_boundary.non_inferiority_margin -eq 0 -and
    [bool]$r23d64FirstQualification.prospective_repair_boundary.receipt_gate_runtime_dependency_binding_change_only -and
    [int]$r23d64FirstQualification.prospective_repair_boundary.route_worker_controller_physics_threshold_selector_evaluator_result_or_interpretation_change_count -eq 0
) "R23D64 runtime-dependency repair population, controls, or zero-margin boundary changed"
Assert-Exact (
    -not [bool]$r23d64FirstQualification.historical_campaign_result_created -and
    -not [bool]$r23d64FirstQualification.historical_campaign_reclassification_authorized -and
    -not [bool]$r23d64FirstQualification.r23d64_turning_claim_changed -and
    -not [bool]$r23d64FirstQualification.q_sdk_r23_satisfied -and
    -not [bool]$r23d64FirstQualification.cross_engine_equivalence_claimed -and
    -not [bool]$r23d64FirstQualification.prone_to_standing_claimed -and
    -not [bool]$r23d64FirstQualification.physical_acceptance_authority -and
    -not [bool]$r23d64FirstQualification.release_authority
) "R23D64 failed-qualification non-claims changed"

$r23d64FailedRoot = [string]$r23d64FirstQualification.qualification_root
$r23d64FailedRootFiles = @(Get-ChildItem -LiteralPath $r23d64FailedRoot -File | Sort-Object Name)
Assert-Exact (
    $r23d64FailedRootFiles.Count -eq 47 -and
    [long]($r23d64FailedRootFiles | Measure-Object Length -Sum).Sum -eq 341615 -and
    (@($r23d64FailedRootFiles.Name) -join "|") -ceq
        (@($r23d64RetainedBindings.relative_path) -join "|")
) "R23D64 retained first-qualification file population changed"
foreach ($binding in $r23d64RetainedBindings) {
    $retainedPath = Join-Path $r23d64FailedRoot ([string]$binding.relative_path)
    Assert-Exact (Test-Path -LiteralPath $retainedPath -PathType Leaf) (
        "R23D64 retained first-qualification file is missing: $retainedPath"
    )
    $retainedFile = Get-Item -LiteralPath $retainedPath
    Assert-Exact (
        [long]$retainedFile.Length -eq [long]$binding.byte_length -and
        (Get-RawSha256 -Path $retainedPath) -ceq [string]$binding.raw_sha256
    ) "R23D64 retained first-qualification bytes changed: $retainedPath"
}

$r23d64GateReceipts = @(
    Get-ChildItem -LiteralPath $r23d64FailedRoot -Filter "*.receipt.json" -File |
        Sort-Object Name |
        ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json }
)
$r23d64PassedReceipts = @($r23d64GateReceipts | Where-Object { [bool]$_.passed })
$r23d64FailedReceipts = @($r23d64GateReceipts | Where-Object { -not [bool]$_.passed })
Assert-Exact (
    $r23d64GateReceipts.Count -eq 15 -and
    $r23d64PassedReceipts.Count -eq 14 -and
    $r23d64FailedReceipts.Count -eq 1 -and
    [int]($r23d64GateReceipts | Measure-Object physical_process_launch_count -Sum).Sum -eq 0 -and
    [int]($r23d64GateReceipts | Measure-Object physical_world_count -Sum).Sum -eq 0 -and
    -not ($r23d64GateReceipts | Where-Object { [bool]$_.physical_acceptance_authority })
) "R23D64 retained first-qualification receipt population changed"
$r23d64FailedReceipt = $r23d64FailedReceipts[0]
Assert-Exact (
    [int]$r23d64FailedReceipt.ordinal -eq 15 -and
    [string]$r23d64FailedReceipt.gate_id -ceq
        "R23D64-AUTHORIZATION-RECEIPT-SCHEMA-CONFORMANCE" -and
    [string]$r23d64FailedReceipt.role -ceq "lineage" -and
    [int]$r23d64FailedReceipt.exit_code -eq 1 -and
    -not [bool]$r23d64FailedReceipt.timed_out -and
    [int]$r23d64FailedReceipt.terminal_marker_count -eq 0 -and
    [int]$r23d64FailedReceipt.physical_process_launch_count -eq 0 -and
    [int]$r23d64FailedReceipt.physical_world_count -eq 0 -and
    -not [bool]$r23d64FailedReceipt.physical_acceptance_authority
) "R23D64 retained failed lineage-gate receipt changed"

$r23d64Failure = Get-Content -LiteralPath (Join-Path $r23d64FailedRoot "failure.json") -Raw |
    ConvertFrom-Json
$r23d64FailedStderr = Get-Content -LiteralPath (
    Join-Path $r23d64FailedRoot "015-R23D64-AUTHORIZATION-RECEIPT-SCHEMA-CONFORMANCE.stderr.log"
) -Raw
$r23d64Diagnosis = Get-Content -LiteralPath (
    [string]$r23d64FirstQualification.postqualification_diagnosis_path
) -Raw | ConvertFrom-Json
Assert-Exact (
    [string]$r23d64Failure.schema_version -ceq
        "sporespore_locomotion_campaign_attestation_failure_v1" -and
    [string]$r23d64Failure.source_commit -ceq [string]$r23d64FirstQualification.source_commit -and
    [string]$r23d64Failure.message -ceq [string]$r23d64FirstQualification.failure_message -and
    -not [bool]$r23d64Failure.campaign_local_qualification_passed -and
    -not [bool]$r23d64Failure.physical_launch_prerequisite_satisfied -and
    -not [bool]$r23d64Failure.physical_acceptance_authority -and
    -not [bool]$r23d64Failure.release_authority -and
    $r23d64FailedStderr.Contains("ModuleNotFoundError: No module named 'mujoco'")
) "R23D64 retained first-qualification terminal failure changed"
Assert-Exact (
    [string]$r23d64Diagnosis.schema_version -ceq
        "sporespore_qsdk_r23d64_first_qualification_postfailure_diagnosis_v1" -and
    [string]$r23d64Diagnosis.question_class -ceq "equivalence_non_inferiority" -and
    [string]$r23d64Diagnosis.physical_question_class_inherited_unchanged -ceq "finite_decision" -and
    [string]$r23d64Diagnosis.source_commit -ceq [string]$r23d64FirstQualification.source_commit -and
    [string]$r23d64Diagnosis.source_tree_git_oid -ceq [string]$r23d64FirstQualification.source_tree_git_oid -and
    [int]$r23d64Diagnosis.failure.failed_gate_ordinal -eq 15 -and
    [string]$r23d64Diagnosis.failure.failure_code -ceq
        "ModuleNotFoundError: No module named 'mujoco'" -and
    [string]$r23d64Diagnosis.diagnosis.classification -ceq
        "failed_incomplete_source_runtime_dependency_binding" -and
    -not [bool]$r23d64Diagnosis.diagnosis.receipt_gate_self_bound_mujoco_site_packages -and
    [bool]$r23d64Diagnosis.diagnosis.receipt_gate_depended_on_supervisor_only_inherited_pythonpath -and
    [bool]$r23d64Diagnosis.diagnosis.formal_attestation_invokes_lineage_gate_directly -and
    -not [bool]$r23d64Diagnosis.diagnosis.route_worker_controller_physics_threshold_selector_evaluator_result_or_interpretation_reached -and
    [int]$r23d64Diagnosis.model_construction_count -eq 0 -and
    [int]$r23d64Diagnosis.world_attempt_count -eq 0 -and
    [int]$r23d64Diagnosis.world_build_count -eq 0 -and
    [int]$r23d64Diagnosis.solver_step_count -eq 0 -and
    -not [bool]$r23d64Diagnosis.physical_attempt_identity_consumed -and
    -not [bool]$r23d64Diagnosis.turning_result_created -and
    -not [bool]$r23d64Diagnosis.q_sdk_r23_satisfied -and
    -not [bool]$r23d64Diagnosis.physical_acceptance_authority -and
    -not [bool]$r23d64Diagnosis.release_authority
) "R23D64 retained postqualification diagnosis changed"

$r23d64PhysicalClosureExtension =
    $contract.inventory.r23d64_physical_closure_inventory_extension
$r23d64PhysicalClosureAddedEntries = @(
    $r23d64PhysicalClosureExtension.added_entries
)
Assert-Exact (
    [string]$r23d64PhysicalClosureExtension.maintenance_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$r23d64PhysicalClosureExtension.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$r23d64PhysicalClosureExtension.scope -ceq
        "complete_closure_audit_population_extension_for_r23d64_consumed_invalid_incomplete_physical_closure" -and
    [string]$r23d64PhysicalClosureExtension.declared_from_physical_source_commit -ceq
        "8277ab3e934561902bd375f7bcaf263ac7fae231" -and
    [string]$r23d64PhysicalClosureExtension.declared_from_physical_source_tree_git_oid -ceq
        "0aa240e74791df0d49a201c95bcc4179d0cab6b6" -and
    [bool]$r23d64PhysicalClosureExtension.initial_inventory_failure_observed -and
    [string]$r23d64PhysicalClosureExtension.initial_inventory_failure_message -ceq
        "Closure evidence-mode inventory drifted; regenerate and review the complete classification" -and
    [int]$r23d64PhysicalClosureExtension.inventory_population_size -eq 172 -and
    [bool]$r23d64PhysicalClosureExtension.inventory_population_compared_completely -and
    [int]$r23d64PhysicalClosureExtension.inventory_sample_size -eq 172 -and
    -not [bool]$r23d64PhysicalClosureExtension.inventory_sampling_claimed -and
    [int]$r23d64PhysicalClosureExtension.pre_extension_audit_count -eq 171 -and
    [int]$r23d64PhysicalClosureExtension.post_extension_audit_count -eq 172 -and
    [int]$r23d64PhysicalClosureExtension.added_audit_count -eq 1 -and
    [int]$r23d64PhysicalClosureExtension.changed_audit_count -eq 0 -and
    [int]$r23d64PhysicalClosureExtension.removed_audit_count -eq 0 -and
    [int]$r23d64PhysicalClosureExtension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$r23d64PhysicalClosureExtension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$r23d64PhysicalClosureExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r23d64PhysicalClosureExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r23d64PhysicalClosureExtension.manual_review_required_count_delta -eq 0 -and
    $r23d64PhysicalClosureAddedEntries.Count -eq 1 -and
    [string]$r23d64PhysicalClosureAddedEntries[0].path -ceq
        "tests/test_qsdk_r23d64_physical_closure.ps1" -and
    [string]$r23d64PhysicalClosureAddedEntries[0].raw_sha256 -ceq
        "7164a504b71ee5a1ac30118001367a3a6425db5ff94c9175ebb4c6b597caab25" -and
    [string]$r23d64PhysicalClosureAddedEntries[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    @($r23d64PhysicalClosureAddedEntries[0].detected_modes).Count -eq 4 -and
    $r23d64PhysicalClosureAddedEntries[0].detected_modes -ccontains "cas_path_check" -and
    $r23d64PhysicalClosureAddedEntries[0].detected_modes -ccontains "pinned_git_blob" -and
    $r23d64PhysicalClosureAddedEntries[0].detected_modes -ccontains "retained_evidence_bytes" -and
    $r23d64PhysicalClosureAddedEntries[0].detected_modes -ccontains "live_repo_or_checkout_hash" -and
    -not [bool]$r23d64PhysicalClosureAddedEntries[0].live_historical_identity_risk -and
    -not [bool]$r23d64PhysicalClosureAddedEntries[0].manual_review_required -and
    [string]$r23d64PhysicalClosureExtension.closure_path -ceq
        "sdk/turning/r23d64_selected_profile_three_engine_turning_validation_closure_v1.json" -and
    [string]$r23d64PhysicalClosureExtension.closure_raw_sha256 -ceq
        "dd7b5f49387bba790efdec46c8f4d4fdd65e9bb89caf74bb1a8af5a9d7929685" -and
    [long]$r23d64PhysicalClosureExtension.closure_byte_length -eq 30449 -and
    [string]$r23d64PhysicalClosureExtension.audit_path -ceq
        "tests/test_qsdk_r23d64_physical_closure.ps1" -and
    [string]$r23d64PhysicalClosureExtension.audit_raw_sha256 -ceq
        "7164a504b71ee5a1ac30118001367a3a6425db5ff94c9175ebb4c6b597caab25" -and
    [long]$r23d64PhysicalClosureExtension.audit_byte_length -eq 38868 -and
    [int]$r23d64PhysicalClosureExtension.retained_physical_file_count -eq 60 -and
    [long]$r23d64PhysicalClosureExtension.retained_physical_byte_count -eq 265254983 -and
    [int]$r23d64PhysicalClosureExtension.retained_physical_world_count -eq 6 -and
    [int]$r23d64PhysicalClosureExtension.execution_valid_cell_count -eq 0 -and
    [int]$r23d64PhysicalClosureExtension.turning_evaluated_cell_count -eq 0 -and
    [string]$r23d64PhysicalClosureExtension.threshold_origin -ceq
        "exact_complete_inventory_object_comparison_no_statistical_threshold" -and
    [int]$r23d64PhysicalClosureExtension.equivalence_margin -eq 0 -and
    [int]$r23d64PhysicalClosureExtension.non_inferiority_margin -eq 0 -and
    -not [bool]$r23d64PhysicalClosureExtension.historical_campaign_result_created -and
    -not [bool]$r23d64PhysicalClosureExtension.historical_campaign_reclassification_authorized -and
    -not [bool]$r23d64PhysicalClosureExtension.posthoc_trace_evaluation_performed -and
    [int]$r23d64PhysicalClosureExtension.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$r23d64PhysicalClosureExtension.maintenance_process_physical_world_count -eq 0 -and
    -not [bool]$r23d64PhysicalClosureExtension.r23d64_turning_positive -and
    -not [bool]$r23d64PhysicalClosureExtension.r23d64_turning_negative -and
    -not [bool]$r23d64PhysicalClosureExtension.q_sdk_r23_satisfied -and
    [string]$r23d64PhysicalClosureExtension.release_score_before -ceq "10/25" -and
    [string]$r23d64PhysicalClosureExtension.release_score_after -ceq "10/25" -and
    -not [bool]$r23d64PhysicalClosureExtension.cross_engine_equivalence_claimed -and
    -not [bool]$r23d64PhysicalClosureExtension.prone_to_standing_claimed -and
    -not [bool]$r23d64PhysicalClosureExtension.live_historical_identity_risk -and
    -not [bool]$r23d64PhysicalClosureExtension.manual_review_required -and
    -not [bool]$r23d64PhysicalClosureExtension.physical_acceptance_authority -and
    -not [bool]$r23d64PhysicalClosureExtension.release_authority
) "R23D64 physical-closure inventory extension changed"
$r23d64PhysicalClosureInventoryEntry = @($inventory.entries | Where-Object {
    [string]$_.path -ceq [string]$r23d64PhysicalClosureAddedEntries[0].path
})
Assert-Exact (
    $r23d64PhysicalClosureInventoryEntry.Count -eq 1 -and
    ($r23d64PhysicalClosureInventoryEntry[0] | ConvertTo-Json -Depth 20 -Compress) -ceq
        ($r23d64PhysicalClosureAddedEntries[0] | ConvertTo-Json -Depth 20 -Compress)
) "R23D64 physical-closure entry differs from the complete inventory"

$r23d65QualificationExtension =
    $contract.inventory.r23d65_first_clean_pushed_qualification_inventory_extension
$r23d65QualificationAddedEntries = @($r23d65QualificationExtension.added_entries)
$r23d65QualificationRetainedFiles = @($r23d65QualificationExtension.retained_files)
Assert-Exact (
    [string]$r23d65QualificationExtension.qualification_process_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$r23d65QualificationExtension.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$r23d65QualificationExtension.scope -ceq
        "complete_retained_first_r23d65_clean_pushed_qualification_file_population_and_complete_closure_audit_inventory_extension" -and
    [string]$r23d65QualificationExtension.declared_from_failed_clean_pushed_source_commit -ceq
        "15e308aa4f61d9a5d382f90fdef59f41cee32438" -and
    [string]$r23d65QualificationExtension.declared_from_failed_clean_pushed_source_tree_git_oid -ceq
        "5d09992f66ff453fc32c370d018ab66c54c69059" -and
    [string]$r23d65QualificationExtension.status -ceq
        "failed_incomplete_global_provenance_inventory" -and
    [bool]$r23d65QualificationExtension.initial_inventory_failure_observed -and
    [string]$r23d65QualificationExtension.initial_inventory_failure_message -ceq
        "Closure evidence-mode executable inventory verification failed" -and
    [string]$r23d65QualificationExtension.initial_failed_qualification_root -ceq
        "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r23d65-qualification-20260825T142802Z-15e308aa" -and
    [string]$r23d65QualificationExtension.initial_failed_qualification_failure_message -ceq
        "Campaign-local attestation gate failed: CAK1-EVIDENCE-PROVENANCE exit=1 timeout=False marker_count=0" -and
    [string]$r23d65QualificationExtension.initial_failed_qualification_failure_gate_id -ceq
        "CAK1-EVIDENCE-PROVENANCE" -and
    [string]$r23d65QualificationExtension.initial_failed_qualification_failure_error -ceq
        "Closure evidence-mode executable inventory verification failed" -and
    [int]$r23d65QualificationExtension.initial_failed_qualification_retained_file_count -eq 13 -and
    [long]$r23d65QualificationExtension.initial_failed_qualification_retained_byte_count -eq 12703 -and
    [bool]$r23d65QualificationExtension.retained_file_population_compared_completely -and
    [int]$r23d65QualificationExtension.retained_file_sample_size -eq 13 -and
    -not [bool]$r23d65QualificationExtension.retained_file_sampling_claimed -and
    $r23d65QualificationRetainedFiles.Count -eq 13 -and
    [int]$r23d65QualificationExtension.initial_failed_qualification_passed_gate_count -eq 3 -and
    [int]$r23d65QualificationExtension.initial_failed_qualification_passed_global_gate_count -eq 3 -and
    [int]$r23d65QualificationExtension.initial_failed_qualification_passed_lineage_gate_count -eq 0 -and
    [int]$r23d65QualificationExtension.initial_failed_qualification_campaign_role_gate_count -eq 0 -and
    [int]$r23d65QualificationExtension.initial_failed_qualification_model_construction_count -eq 0 -and
    [int]$r23d65QualificationExtension.initial_failed_qualification_world_attempt_count -eq 0 -and
    [int]$r23d65QualificationExtension.initial_failed_qualification_world_build_count -eq 0 -and
    [int]$r23d65QualificationExtension.initial_failed_qualification_solver_step_count -eq 0 -and
    [int]$r23d65QualificationExtension.inventory_population_size -eq 173 -and
    [bool]$r23d65QualificationExtension.inventory_population_compared_completely -and
    [int]$r23d65QualificationExtension.inventory_sample_size -eq 173 -and
    -not [bool]$r23d65QualificationExtension.inventory_sampling_claimed -and
    [int]$r23d65QualificationExtension.pre_extension_audit_count -eq 172 -and
    [int]$r23d65QualificationExtension.post_extension_audit_count -eq 173 -and
    [int]$r23d65QualificationExtension.added_audit_count -eq 1 -and
    [int]$r23d65QualificationExtension.changed_audit_count -eq 0 -and
    [int]$r23d65QualificationExtension.removed_audit_count -eq 0 -and
    [int]$r23d65QualificationExtension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$r23d65QualificationExtension.pinned_git_blob_signature_count_delta -eq 0 -and
    [int]$r23d65QualificationExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r23d65QualificationExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r23d65QualificationExtension.manual_review_required_count_delta -eq 1 -and
    $r23d65QualificationAddedEntries.Count -eq 1 -and
    [string]$r23d65QualificationAddedEntries[0].path -ceq
        "tests/test_qsdk_r23d65_dependency_closure.ps1" -and
    [string]$r23d65QualificationAddedEntries[0].raw_sha256 -ceq
        "c574bc52009e92c21d3bb5033444dfe470609eac385eebbfe1093f273cee7836" -and
    [string]$r23d65QualificationAddedEntries[0].historical_identity_mode -ceq
        "record_retained_evidence_or_manual_review" -and
    @($r23d65QualificationAddedEntries[0].detected_modes).Count -eq 1 -and
    @($r23d65QualificationAddedEntries[0].detected_modes)[0] -ceq "cas_path_check" -and
    -not [bool]$r23d65QualificationAddedEntries[0].live_historical_identity_risk -and
    [bool]$r23d65QualificationAddedEntries[0].manual_review_required -and
    [string]$r23d65QualificationExtension.manual_review_disposition -ceq
        "the_r23d65_entry_is_a_prospective_recursive_dependency_omission_and_structure_mutation_gate_not_a_historical_result_identity" -and
    [string]$r23d65QualificationExtension.threshold_origin -ceq
        "exact_complete_inventory_object_and_retained_file_sha256_comparison_no_statistical_threshold" -and
    [int]$r23d65QualificationExtension.equivalence_margin -eq 0 -and
    [int]$r23d65QualificationExtension.non_inferiority_margin -eq 0 -and
    [string]$r23d65QualificationExtension.adequacy_argument -ceq
        "All 173 discovered closure audits and every field in all 172 retained entries were compared exactly. Exactly the new R23D65 dependency-closure audit was added, no retained entry changed or disappeared, and the aggregate deltas equal its declared classification. Every byte of all 13 files retained by the failed qualification was hashed and compared. These complete finite-population comparisons require no sample extrapolation or statistical margin." -and
    [bool]$r23d65QualificationExtension.failed_qualification_retained -and
    -not [bool]$r23d65QualificationExtension.failed_qualification_reusable -and
    [bool]$r23d65QualificationExtension.qualification_retry_requires_distinct_corrected_clean_pushed_source -and
    -not [bool]$r23d65QualificationExtension.physical_attempt_identity_consumed -and
    -not [bool]$r23d65QualificationExtension.campaign_identity_consumed -and
    -not [bool]$r23d65QualificationExtension.historical_campaign_result_created -and
    -not [bool]$r23d65QualificationExtension.historical_campaign_reclassification_authorized -and
    [int]$r23d65QualificationExtension.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$r23d65QualificationExtension.route_worker_controller_physics_or_evaluator_semantics_change_count -eq 0 -and
    [int]$r23d65QualificationExtension.maintenance_process_physical_world_count -eq 0 -and
    [int]$r23d65QualificationExtension.r23d65_physical_world_count -eq 0 -and
    -not [bool]$r23d65QualificationExtension.r23d65_turning_claim_changed -and
    -not [bool]$r23d65QualificationExtension.q_sdk_r23_satisfied -and
    [string]$r23d65QualificationExtension.release_score_before -ceq "10/25" -and
    [string]$r23d65QualificationExtension.release_score_after -ceq "10/25" -and
    -not [bool]$r23d65QualificationExtension.cross_engine_equivalence_claimed -and
    -not [bool]$r23d65QualificationExtension.prone_to_standing_claimed -and
    -not [bool]$r23d65QualificationExtension.live_historical_identity_risk -and
    [bool]$r23d65QualificationExtension.manual_review_required -and
    -not [bool]$r23d65QualificationExtension.physical_acceptance_authority -and
    -not [bool]$r23d65QualificationExtension.release_authority
) "R23D65 first qualification or inventory extension changed"
$r23d65QualificationInventoryEntry = @($inventory.entries | Where-Object {
    [string]$_.path -ceq [string]$r23d65QualificationAddedEntries[0].path
})
Assert-Exact (
    $r23d65QualificationInventoryEntry.Count -eq 1 -and
    ($r23d65QualificationInventoryEntry[0] | ConvertTo-Json -Depth 20 -Compress) -ceq
        ($r23d65QualificationAddedEntries[0] | ConvertTo-Json -Depth 20 -Compress)
) "R23D65 dependency-closure entry differs from the complete inventory"
$r23d65QualificationRoot = [IO.Path]::GetFullPath(
    [string]$r23d65QualificationExtension.initial_failed_qualification_root
)
Assert-Exact (Test-Path -LiteralPath $r23d65QualificationRoot -PathType Container) (
    "R23D65 retained failed qualification root is missing"
)
$r23d65ObservedRetainedFiles = @(
    Get-ChildItem -LiteralPath $r23d65QualificationRoot -File -Recurse |
        ForEach-Object {
            [IO.Path]::GetRelativePath($r23d65QualificationRoot, $_.FullName).
                Replace("\", "/")
        } |
        Sort-Object -CaseSensitive
)
$r23d65BoundRetainedFiles = @(
    $r23d65QualificationRetainedFiles |
        ForEach-Object { [string]$_.relative_path } |
        Sort-Object -CaseSensitive
)
Assert-Exact (
    $r23d65ObservedRetainedFiles.Count -eq 13 -and
    $r23d65BoundRetainedFiles.Count -eq 13 -and
    @(
        Compare-Object `
            -ReferenceObject $r23d65BoundRetainedFiles `
            -DifferenceObject $r23d65ObservedRetainedFiles `
            -CaseSensitive
    ).Count -eq 0
) "R23D65 retained failed qualification population changed"
$r23d65RetainedByteTotal = 0L
foreach ($binding in $r23d65QualificationRetainedFiles) {
    $retainedPath = Join-Path `
        $r23d65QualificationRoot `
        ([string]$binding.relative_path).Replace("/", "\")
    Assert-Exact (Test-Path -LiteralPath $retainedPath -PathType Leaf) (
        "R23D65 retained failed qualification file is missing: $retainedPath"
    )
    $retainedItem = Get-Item -LiteralPath $retainedPath
    Assert-Exact (
        [long]$retainedItem.Length -eq [long]$binding.byte_length -and
        (Get-RawSha256 -Path $retainedPath) -ceq [string]$binding.raw_sha256
    ) "R23D65 retained failed qualification bytes changed: $retainedPath"
    $r23d65RetainedByteTotal += [long]$retainedItem.Length
}
Assert-Exact (
    $r23d65RetainedByteTotal -eq 12703
) "R23D65 retained failed qualification byte population changed"

$r23d65PhysicalExtension =
    $contract.inventory.r23d65_physical_closure_inventory_extension
$r23d65PhysicalAddedEntries = @($r23d65PhysicalExtension.added_entries)
Assert-Exact (
    [string]$r23d65PhysicalExtension.maintenance_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$r23d65PhysicalExtension.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$r23d65PhysicalExtension.declared_from_physical_source_commit -ceq
        "4ecb24cc1f5f7bc864578c8915dd7028a99990bf" -and
    [string]$r23d65PhysicalExtension.declared_from_physical_source_tree_git_oid -ceq
        "637b1cafd786037f11060fd5deaa08d3f6b59c06" -and
    [int]$r23d65PhysicalExtension.inventory_population_size -eq 174 -and
    [bool]$r23d65PhysicalExtension.inventory_population_compared_completely -and
    [int]$r23d65PhysicalExtension.inventory_sample_size -eq 174 -and
    -not [bool]$r23d65PhysicalExtension.inventory_sampling_claimed -and
    [int]$r23d65PhysicalExtension.pre_extension_audit_count -eq 173 -and
    [int]$r23d65PhysicalExtension.post_extension_audit_count -eq 174 -and
    [int]$r23d65PhysicalExtension.added_audit_count -eq 1 -and
    [int]$r23d65PhysicalExtension.changed_audit_count -eq 0 -and
    [int]$r23d65PhysicalExtension.removed_audit_count -eq 0 -and
    [int]$r23d65PhysicalExtension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$r23d65PhysicalExtension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$r23d65PhysicalExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r23d65PhysicalExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r23d65PhysicalExtension.manual_review_required_count_delta -eq 0 -and
    $r23d65PhysicalAddedEntries.Count -eq 1 -and
    [string]$r23d65PhysicalAddedEntries[0].path -ceq
        "tests/test_qsdk_r23d65_physical_closure.ps1" -and
    [string]$r23d65PhysicalAddedEntries[0].raw_sha256 -ceq
        "47715a6909c50aeb48ddf26cbe11a8e679c9de39d0578bfbabe64f462a8bcc74" -and
    [string]$r23d65PhysicalAddedEntries[0].historical_identity_mode -ceq
        "pinned_git_blob" -and
    (@($r23d65PhysicalAddedEntries[0].detected_modes) -join "|") -ceq
        "cas_path_check|pinned_git_blob|retained_evidence_bytes|live_repo_or_checkout_hash" -and
    -not [bool]$r23d65PhysicalAddedEntries[0].live_historical_identity_risk -and
    -not [bool]$r23d65PhysicalAddedEntries[0].manual_review_required -and
    [int]$r23d65PhysicalExtension.complete_retained_physical_file_population_count -eq 41 -and
    [long]$r23d65PhysicalExtension.complete_retained_physical_file_population_byte_count -eq 134685582 -and
    [bool]$r23d65PhysicalExtension.complete_retained_physical_file_population_compared -and
    [int]$r23d65PhysicalExtension.retained_physical_unique_digest_count -eq 29 -and
    [int]$r23d65PhysicalExtension.retained_physical_cas_backed_file_count -eq 37 -and
    [int]$r23d65PhysicalExtension.retained_physical_non_cas_row_file_count -eq 4 -and
    [string]$r23d65PhysicalExtension.retained_physical_population_manifest_sha256 -ceq
        "sha256:bade316726f84e1c6d08bfa5a0ba960db240d6dc462fd808caf3627feaf249ba" -and
    [int]$r23d65PhysicalExtension.physical_worker_process_count -eq 4 -and
    [int]$r23d65PhysicalExtension.actual_worker_reported_world_attempt_count -eq 4 -and
    [int]$r23d65PhysicalExtension.actual_worker_reported_world_build_count -eq 4 -and
    [int]$r23d65PhysicalExtension.unopened_declared_cell_count -eq 5 -and
    [int]$r23d65PhysicalExtension.turning_evaluated_cell_count -eq 0 -and
    [double]$r23d65PhysicalExtension.equivalence_margin -eq 0.0 -and
    [double]$r23d65PhysicalExtension.non_inferiority_margin -eq 0.0 -and
    [bool]$r23d65PhysicalExtension.campaign_identity_consumed -and
    -not [bool]$r23d65PhysicalExtension.same_identity_rerun_allowed -and
    -not [bool]$r23d65PhysicalExtension.replacement_or_selective_rerun_allowed -and
    -not [bool]$r23d65PhysicalExtension.historical_campaign_reclassification_authorized -and
    [int]$r23d65PhysicalExtension.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$r23d65PhysicalExtension.maintenance_process_physical_world_count -eq 0 -and
    [int]$r23d65PhysicalExtension.r23d65_observed_physical_world_count -eq 4 -and
    -not [bool]$r23d65PhysicalExtension.r23d65_turning_claim_changed -and
    -not [bool]$r23d65PhysicalExtension.q_sdk_r23_satisfied -and
    [string]$r23d65PhysicalExtension.release_score_before -ceq "10/25" -and
    [string]$r23d65PhysicalExtension.release_score_after -ceq "10/25" -and
    -not [bool]$r23d65PhysicalExtension.cross_engine_equivalence_claimed -and
    -not [bool]$r23d65PhysicalExtension.prone_to_standing_claimed -and
    -not [bool]$r23d65PhysicalExtension.live_historical_identity_risk -and
    -not [bool]$r23d65PhysicalExtension.manual_review_required -and
    -not [bool]$r23d65PhysicalExtension.physical_acceptance_authority -and
    -not [bool]$r23d65PhysicalExtension.release_authority
) "R23D65 physical-closure inventory extension changed"
$r23d65PhysicalInventoryEntry = @($inventory.entries | Where-Object {
    [string]$_.path -ceq [string]$r23d65PhysicalAddedEntries[0].path
})
Assert-Exact (
    $r23d65PhysicalInventoryEntry.Count -eq 1 -and
    ($r23d65PhysicalInventoryEntry[0] | ConvertTo-Json -Depth 20 -Compress) -ceq
        ($r23d65PhysicalAddedEntries[0] | ConvertTo-Json -Depth 20 -Compress)
) "R23D65 physical-closure entry differs from the complete inventory"

$routeClosureInventoryReconciliation =
    $contract.inventory.three_engine_turning_route_closure_inventory_reconciliation
$routeClosureInventoryEntry = @($inventory.entries | Where-Object {
    [string]$_.path -ceq
        "tests/test_three_engine_turning_production_route_development_closure.ps1"
})
Assert-Exact (
    [string]$routeClosureInventoryReconciliation.maintenance_question_class -ceq
        "development" -and
    [string]$routeClosureInventoryReconciliation.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$routeClosureInventoryReconciliation.scope -ceq
        "complete_inventory_reconciliation_for_the_already_closed_three_engine_turning_production_route_development_audit" -and
    [string]$routeClosureInventoryReconciliation.declared_from_failed_clean_pushed_source_commit -ceq
        "bf6836de7806c18e39eafa10a942ae0d77bc310a" -and
    [string]$routeClosureInventoryReconciliation.declared_from_failed_clean_pushed_source_tree_git_oid -ceq
        "318cc30559ad0031a13dc84339e72b3c84e5f6ae" -and
    [int]$routeClosureInventoryReconciliation.inventory_population_size -eq 175 -and
    [bool]$routeClosureInventoryReconciliation.inventory_population_compared_completely -and
    [int]$routeClosureInventoryReconciliation.inventory_sample_size -eq 175 -and
    -not [bool]$routeClosureInventoryReconciliation.inventory_sampling_claimed -and
    [int]$routeClosureInventoryReconciliation.pre_reconciliation_audit_count -eq 174 -and
    [int]$routeClosureInventoryReconciliation.post_reconciliation_audit_count -eq 175 -and
    [int]$routeClosureInventoryReconciliation.added_audit_count -eq 1 -and
    [int]$routeClosureInventoryReconciliation.changed_audit_count -eq 0 -and
    [int]$routeClosureInventoryReconciliation.removed_audit_count -eq 0 -and
    [int]$routeClosureInventoryReconciliation.cas_path_check_signature_count_delta -eq 1 -and
    [int]$routeClosureInventoryReconciliation.pinned_git_blob_signature_count_delta -eq 0 -and
    [int]$routeClosureInventoryReconciliation.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$routeClosureInventoryReconciliation.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$routeClosureInventoryReconciliation.manual_review_required_count_delta -eq 1 -and
    $routeClosureInventoryEntry.Count -eq 1 -and
    ($routeClosureInventoryEntry[0] | ConvertTo-Json -Depth 20 -Compress) -ceq
        ($routeClosureInventoryReconciliation.added_entry |
            ConvertTo-Json -Depth 20 -Compress) -and
    [string]$routeClosureInventoryReconciliation.threshold_origin -ceq
        "exact_complete_inventory_object_comparison_no_statistical_threshold" -and
    [double]$routeClosureInventoryReconciliation.equivalence_margin -eq 0.0 -and
    [double]$routeClosureInventoryReconciliation.non_inferiority_margin -eq 0.0 -and
    [bool]$routeClosureInventoryReconciliation.failed_qualification_retained -and
    -not [bool]$routeClosureInventoryReconciliation.failed_qualification_reusable -and
    [bool]$routeClosureInventoryReconciliation.qualification_retry_requires_distinct_corrected_clean_pushed_source -and
    -not [bool]$routeClosureInventoryReconciliation.historical_route_development_result_created -and
    -not [bool]$routeClosureInventoryReconciliation.historical_campaign_reclassification_authorized -and
    [int]$routeClosureInventoryReconciliation.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$routeClosureInventoryReconciliation.maintenance_process_physical_world_count -eq 0 -and
    [int]$routeClosureInventoryReconciliation.r23d66_physical_world_count -eq 0 -and
    -not [bool]$routeClosureInventoryReconciliation.r23d66_turning_claim_changed -and
    -not [bool]$routeClosureInventoryReconciliation.q_sdk_r23_satisfied -and
    [string]$routeClosureInventoryReconciliation.release_score_before -ceq "10/25" -and
    [string]$routeClosureInventoryReconciliation.release_score_after -ceq "10/25" -and
    -not [bool]$routeClosureInventoryReconciliation.cross_engine_equivalence_claimed -and
    -not [bool]$routeClosureInventoryReconciliation.prone_to_standing_claimed -and
    -not [bool]$routeClosureInventoryReconciliation.live_historical_identity_risk -and
    [bool]$routeClosureInventoryReconciliation.manual_review_required -and
    -not [bool]$routeClosureInventoryReconciliation.physical_acceptance_authority -and
    -not [bool]$routeClosureInventoryReconciliation.release_authority
) "Three-engine turning route-closure inventory reconciliation changed"

$r23d66PhysicalExtension =
    $contract.inventory.r23d66_physical_closure_inventory_extension
$r23d66PhysicalInventoryEntry = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d66_physical_closure.ps1"
})
Assert-Exact (
    [string]$r23d66PhysicalExtension.maintenance_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$r23d66PhysicalExtension.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$r23d66PhysicalExtension.scope -ceq
        "complete_closure_audit_population_extension_for_r23d66_consumed_invalid_incomplete_authorization_schema_attempt" -and
    [string]$r23d66PhysicalExtension.declared_from_physical_source_commit -ceq
        "2d57cac49744337a80e4558bc1a44c44cf631bed" -and
    [string]$r23d66PhysicalExtension.declared_from_physical_source_tree_git_oid -ceq
        "39615ec94f227c94836d19d49d7420f5c2bf9f76" -and
    [int]$r23d66PhysicalExtension.inventory_population_size -eq 176 -and
    [bool]$r23d66PhysicalExtension.inventory_population_compared_completely -and
    [int]$r23d66PhysicalExtension.inventory_sample_size -eq 176 -and
    -not [bool]$r23d66PhysicalExtension.inventory_sampling_claimed -and
    [int]$r23d66PhysicalExtension.pre_extension_audit_count -eq 175 -and
    [int]$r23d66PhysicalExtension.post_extension_audit_count -eq 176 -and
    [int]$r23d66PhysicalExtension.added_audit_count -eq 1 -and
    [int]$r23d66PhysicalExtension.changed_audit_count -eq 0 -and
    [int]$r23d66PhysicalExtension.removed_audit_count -eq 0 -and
    [int]$r23d66PhysicalExtension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$r23d66PhysicalExtension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$r23d66PhysicalExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r23d66PhysicalExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r23d66PhysicalExtension.manual_review_required_count_delta -eq 0 -and
    $r23d66PhysicalInventoryEntry.Count -eq 1 -and
    ($r23d66PhysicalInventoryEntry[0] | ConvertTo-Json -Depth 20 -Compress) -ceq
        ($r23d66PhysicalExtension.added_entry |
            ConvertTo-Json -Depth 20 -Compress) -and
    [int]$r23d66PhysicalExtension.complete_retained_physical_file_population_count -eq 22 -and
    [long]$r23d66PhysicalExtension.complete_retained_physical_file_population_byte_count -eq 484991 -and
    [bool]$r23d66PhysicalExtension.complete_retained_physical_file_population_compared -and
    [int]$r23d66PhysicalExtension.retained_physical_unique_digest_count -eq 14 -and
    [int]$r23d66PhysicalExtension.retained_physical_cas_backed_file_count -eq 21 -and
    [int]$r23d66PhysicalExtension.retained_physical_non_cas_file_count -eq 1 -and
    [string]$r23d66PhysicalExtension.retained_physical_population_manifest_sha256 -ceq
        "sha256:a2099f6c514d7ce9c0c33fa8428147c38b487bae029c2174111b7ec0093ded75" -and
    [int]$r23d66PhysicalExtension.authorization_preflight_receipt_count -eq 9 -and
    [int]$r23d66PhysicalExtension.authorization_preflight_pass_count -eq 6 -and
    [int]$r23d66PhysicalExtension.mujoco_authorization_schema_failure_count -eq 3 -and
    [int]$r23d66PhysicalExtension.physical_worker_process_count -eq 0 -and
    [int]$r23d66PhysicalExtension.actual_worker_reported_world_attempt_count -eq 0 -and
    [int]$r23d66PhysicalExtension.actual_worker_reported_world_build_count -eq 0 -and
    [int]$r23d66PhysicalExtension.turning_evaluated_cell_count -eq 0 -and
    [string]$r23d66PhysicalExtension.threshold_origin -ceq
        "exact_complete_inventory_object_and_complete_retained_file_population_manifest_comparison_no_statistical_threshold" -and
    [double]$r23d66PhysicalExtension.equivalence_margin -eq 0.0 -and
    [double]$r23d66PhysicalExtension.non_inferiority_margin -eq 0.0 -and
    [bool]$r23d66PhysicalExtension.campaign_identity_consumed -and
    -not [bool]$r23d66PhysicalExtension.same_identity_rerun_allowed -and
    -not [bool]$r23d66PhysicalExtension.replacement_or_selective_rerun_allowed -and
    -not [bool]$r23d66PhysicalExtension.historical_campaign_reclassification_authorized -and
    [int]$r23d66PhysicalExtension.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$r23d66PhysicalExtension.maintenance_process_physical_world_count -eq 0 -and
    [int]$r23d66PhysicalExtension.r23d66_observed_physical_world_count -eq 0 -and
    -not [bool]$r23d66PhysicalExtension.r23d66_turning_claim_changed -and
    -not [bool]$r23d66PhysicalExtension.q_sdk_r23_satisfied -and
    [string]$r23d66PhysicalExtension.release_score_before -ceq "10/25" -and
    [string]$r23d66PhysicalExtension.release_score_after -ceq "10/25" -and
    -not [bool]$r23d66PhysicalExtension.cross_engine_equivalence_claimed -and
    -not [bool]$r23d66PhysicalExtension.prone_to_standing_claimed -and
    -not [bool]$r23d66PhysicalExtension.live_historical_identity_risk -and
    -not [bool]$r23d66PhysicalExtension.manual_review_required -and
    -not [bool]$r23d66PhysicalExtension.physical_acceptance_authority -and
    -not [bool]$r23d66PhysicalExtension.release_authority
) "R23D66 physical-closure inventory extension changed"

$r23d67PhysicalExtension =
    $contract.inventory.r23d67_physical_closure_inventory_extension
$r23d67PhysicalInventoryEntry = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d67_physical_closure.ps1"
})
$r23d68FailedQualificationRoot = [IO.Path]::GetFullPath(
    [string]$r23d67PhysicalExtension.r23d68_initial_qualification_root
)
$r23d68FailedQualificationFiles = @(
    Get-ChildItem -LiteralPath $r23d68FailedQualificationRoot -Recurse -File |
        Sort-Object FullName
)
$r23d68FailedQualificationRows = @(
    foreach ($file in $r23d68FailedQualificationFiles) {
        $relative = [IO.Path]::GetRelativePath(
            $r23d68FailedQualificationRoot,
            $file.FullName
        ).Replace("\", "/")
        $sha = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).
            Hash.ToLowerInvariant()
        "$relative`t$($file.Length)`tsha256:$sha"
    }
)
$r23d68FailedQualificationManifestRaw =
    ($r23d68FailedQualificationRows -join "`n") + "`n"
$r23d68FailedQualificationManifestSha = "sha256:" + [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData(
        [Text.Encoding]::UTF8.GetBytes($r23d68FailedQualificationManifestRaw)
    )
).ToLowerInvariant()
$r23d68FailedQualificationFailurePath = Join-Path (
    $r23d68FailedQualificationRoot
) "failure.json"
Assert-Exact (
    [string]$r23d67PhysicalExtension.maintenance_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$r23d67PhysicalExtension.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$r23d67PhysicalExtension.scope -ceq
        "complete_closure_audit_population_extension_for_r23d67_consumed_invalid_incomplete_production_integration_attempt" -and
    [string]$r23d67PhysicalExtension.declared_from_physical_source_commit -ceq
        "5d9469087ab86640a6413ed320c8bcd02ca630e4" -and
    [string]$r23d67PhysicalExtension.declared_from_physical_source_tree_git_oid -ceq
        "d5bbf367069743809fa8667c7d7168afa04dd54f" -and
    [string]$r23d67PhysicalExtension.declared_from_closure_commit -ceq
        "970a338d9e05cf65104178f2a5c5d9f8e7f6313e" -and
    [string]$r23d67PhysicalExtension.declared_from_closure_tree_git_oid -ceq
        "ab411937651b8269de5b600f277d5d4d048f38c3" -and
    [int]$r23d67PhysicalExtension.inventory_population_size -eq 177 -and
    [bool]$r23d67PhysicalExtension.inventory_population_compared_completely -and
    [int]$r23d67PhysicalExtension.inventory_sample_size -eq 177 -and
    -not [bool]$r23d67PhysicalExtension.inventory_sampling_claimed -and
    [int]$r23d67PhysicalExtension.pre_extension_audit_count -eq 176 -and
    [int]$r23d67PhysicalExtension.post_extension_audit_count -eq 177 -and
    [int]$r23d67PhysicalExtension.added_audit_count -eq 1 -and
    [int]$r23d67PhysicalExtension.changed_audit_count -eq 0 -and
    [int]$r23d67PhysicalExtension.removed_audit_count -eq 0 -and
    [int]$r23d67PhysicalExtension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$r23d67PhysicalExtension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$r23d67PhysicalExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r23d67PhysicalExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r23d67PhysicalExtension.manual_review_required_count_delta -eq 0 -and
    $r23d67PhysicalInventoryEntry.Count -eq 1 -and
    ($r23d67PhysicalInventoryEntry[0] | ConvertTo-Json -Depth 20 -Compress) -ceq
        ($r23d67PhysicalExtension.added_entry |
            ConvertTo-Json -Depth 20 -Compress) -and
    [int]$r23d67PhysicalExtension.complete_retained_physical_file_population_count -eq 27 -and
    [long]$r23d67PhysicalExtension.complete_retained_physical_file_population_byte_count -eq 16423522 -and
    [int]$r23d67PhysicalExtension.retained_physical_unique_digest_count -eq 18 -and
    [int]$r23d67PhysicalExtension.retained_physical_cas_backed_file_count -eq 25 -and
    [int]$r23d67PhysicalExtension.retained_physical_non_cas_file_count -eq 2 -and
    [string]$r23d67PhysicalExtension.retained_physical_population_manifest_sha256 -ceq
        "sha256:4ba642c67f3698c99efbb0e48c506e981d58c5d0e375430a6fccfbd56738eca0" -and
    [int]$r23d67PhysicalExtension.complete_retained_qualification_file_population_count -eq 50 -and
    [long]$r23d67PhysicalExtension.complete_retained_qualification_file_population_byte_count -eq 493789 -and
    [int]$r23d67PhysicalExtension.qualification_gate_pass_count -eq 16 -and
    [bool]$r23d67PhysicalExtension.qualification_adoption_passed -and
    [int]$r23d67PhysicalExtension.authorization_preflight_receipt_count -eq 9 -and
    [int]$r23d67PhysicalExtension.authorization_preflight_pass_count -eq 9 -and
    [int]$r23d67PhysicalExtension.physical_worker_process_count -eq 1 -and
    [int]$r23d67PhysicalExtension.actual_worker_reported_world_attempt_count -eq 1 -and
    [int]$r23d67PhysicalExtension.actual_worker_reported_world_build_count -eq 1 -and
    [int]$r23d67PhysicalExtension.complete_raw_trace_row_count -eq 2992 -and
    [int]$r23d67PhysicalExtension.trace_vocabulary_mismatch_row_count -eq 592 -and
    [int]$r23d67PhysicalExtension.supervisor_process_shape_mismatch_count -eq 1 -and
    [int]$r23d67PhysicalExtension.turning_evaluated_cell_count -eq 0 -and
    [double]$r23d67PhysicalExtension.equivalence_margin -eq 0.0 -and
    [double]$r23d67PhysicalExtension.non_inferiority_margin -eq 0.0 -and
    [bool]$r23d67PhysicalExtension.campaign_identity_consumed -and
    -not [bool]$r23d67PhysicalExtension.same_identity_rerun_allowed -and
    -not [bool]$r23d67PhysicalExtension.replacement_or_selective_rerun_allowed -and
    -not [bool]$r23d67PhysicalExtension.historical_campaign_reclassification_authorized -and
    [int]$r23d67PhysicalExtension.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$r23d67PhysicalExtension.maintenance_process_physical_world_count -eq 0 -and
    [int]$r23d67PhysicalExtension.r23d67_observed_physical_world_count -eq 1 -and
    -not [bool]$r23d67PhysicalExtension.r23d67_turning_claim_changed -and
    [bool]$r23d67PhysicalExtension.r23d68_initial_qualification_failure_retained -and
    -not [bool]$r23d67PhysicalExtension.r23d68_initial_qualification_reusable -and
    [string]$r23d67PhysicalExtension.r23d68_initial_qualification_source_commit -ceq
        "537023b7b50888156f03de2bfe25900587846b2e" -and
    [string]$r23d67PhysicalExtension.r23d68_initial_qualification_failure_gate_id -ceq
        "CAK1-EVIDENCE-PROVENANCE" -and
    [string]$r23d67PhysicalExtension.r23d68_initial_qualification_failure_message -ceq
        "Closure evidence-mode executable inventory verification failed" -and
    $r23d68FailedQualificationFiles.Count -eq 13 -and
    [long]($r23d68FailedQualificationFiles |
        Measure-Object -Property Length -Sum).Sum -eq 12686 -and
    $r23d68FailedQualificationManifestSha -ceq
        "sha256:0fc92124b4b4993f76acb846263a34f841f90ee1346d01150832f541e2ca7425" -and
    ("sha256:" + (Get-FileHash -LiteralPath $r23d68FailedQualificationFailurePath `
        -Algorithm SHA256).Hash.ToLowerInvariant()) -ceq
        "sha256:7c2544fa11c81a2cd4adccc78256da067aa52e091e476a20752d7e067ea83c7e" -and
    [bool]$r23d67PhysicalExtension.r23d68_retry_requires_distinct_corrected_clean_pushed_source -and
    [int]$r23d67PhysicalExtension.r23d68_physical_world_count -eq 0 -and
    -not [bool]$r23d67PhysicalExtension.q_sdk_r23_satisfied -and
    [string]$r23d67PhysicalExtension.release_score_before -ceq "10/25" -and
    [string]$r23d67PhysicalExtension.release_score_after -ceq "10/25" -and
    -not [bool]$r23d67PhysicalExtension.cross_engine_equivalence_claimed -and
    -not [bool]$r23d67PhysicalExtension.prone_to_standing_claimed -and
    -not [bool]$r23d67PhysicalExtension.live_historical_identity_risk -and
    -not [bool]$r23d67PhysicalExtension.manual_review_required -and
    -not [bool]$r23d67PhysicalExtension.physical_acceptance_authority -and
    -not [bool]$r23d67PhysicalExtension.release_authority
) "R23D67 physical-closure and R23D68 failed-qualification provenance changed"

$r23d68PhysicalExtension =
    $contract.inventory.r23d68_physical_closure_inventory_extension
$r23d68PhysicalInventoryEntry = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d68_physical_closure.ps1"
})
Assert-Exact (
    [string]$r23d68PhysicalExtension.maintenance_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$r23d68PhysicalExtension.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$r23d68PhysicalExtension.declared_from_physical_source_commit -ceq
        "23358ebbc21fa4ddd5208c22a46b21e6abf8c4dc" -and
    [string]$r23d68PhysicalExtension.declared_from_physical_source_tree_git_oid -ceq
        "00820b2baf193eaf1524b5481a468fed65d6b44d" -and
    [int]$r23d68PhysicalExtension.inventory_population_size -eq 178 -and
    [bool]$r23d68PhysicalExtension.inventory_population_compared_completely -and
    [int]$r23d68PhysicalExtension.inventory_sample_size -eq 178 -and
    -not [bool]$r23d68PhysicalExtension.inventory_sampling_claimed -and
    [int]$r23d68PhysicalExtension.pre_extension_audit_count -eq 177 -and
    [int]$r23d68PhysicalExtension.post_extension_audit_count -eq 178 -and
    [int]$r23d68PhysicalExtension.added_audit_count -eq 1 -and
    [int]$r23d68PhysicalExtension.changed_audit_count -eq 0 -and
    [int]$r23d68PhysicalExtension.removed_audit_count -eq 0 -and
    [int]$r23d68PhysicalExtension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$r23d68PhysicalExtension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$r23d68PhysicalExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r23d68PhysicalExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r23d68PhysicalExtension.manual_review_required_count_delta -eq 0 -and
    $r23d68PhysicalInventoryEntry.Count -eq 1 -and
    ($r23d68PhysicalInventoryEntry[0] | ConvertTo-Json -Depth 20 -Compress) -ceq
        ($r23d68PhysicalExtension.added_entry | ConvertTo-Json -Depth 20 -Compress) -and
    [int]$r23d68PhysicalExtension.complete_retained_physical_file_population_count -eq 66 -and
    [long]$r23d68PhysicalExtension.complete_retained_physical_file_population_byte_count -eq 182502686 -and
    [int]$r23d68PhysicalExtension.retained_physical_unique_digest_count -eq 47 -and
    [int]$r23d68PhysicalExtension.retained_physical_cas_backed_file_count -eq 57 -and
    [int]$r23d68PhysicalExtension.retained_physical_non_cas_file_count -eq 9 -and
    [string]$r23d68PhysicalExtension.retained_physical_population_manifest_sha256 -ceq
        "sha256:a4b7c584ad8a9d719d75516ca6fbd9369bed4e6ef3b453f050fc181ab0de913f" -and
    [int]$r23d68PhysicalExtension.complete_retained_qualification_file_population_count -eq 50 -and
    [long]$r23d68PhysicalExtension.complete_retained_qualification_file_population_byte_count -eq 496146 -and
    [int]$r23d68PhysicalExtension.qualification_gate_pass_count -eq 16 -and
    [bool]$r23d68PhysicalExtension.qualification_adoption_passed -and
    [int]$r23d68PhysicalExtension.authorization_preflight_receipt_count -eq 9 -and
    [int]$r23d68PhysicalExtension.authorization_preflight_pass_count -eq 9 -and
    [int]$r23d68PhysicalExtension.physical_worker_process_count -eq 9 -and
    [int]$r23d68PhysicalExtension.supervisor_reported_world_attempt_count -eq 6 -and
    [int]$r23d68PhysicalExtension.supervisor_reported_world_build_count -eq 6 -and
    [int]$r23d68PhysicalExtension.closure_derived_world_attempt_count -eq 9 -and
    [int]$r23d68PhysicalExtension.closure_derived_world_build_count -eq 9 -and
    [int]$r23d68PhysicalExtension.complete_native_horizon_count -eq 9 -and
    [int]$r23d68PhysicalExtension.godot_complete_raw_trace_row_count -eq 8976 -and
    [int]$r23d68PhysicalExtension.godot_missing_actuator_phase_observation_row_count -eq 8976 -and
    [int]$r23d68PhysicalExtension.rapier_complete_raw_trace_row_count -eq 8976 -and
    [int]$r23d68PhysicalExtension.rapier_trace_vocabulary_mismatch_row_count -eq 1776 -and
    [int]$r23d68PhysicalExtension.mujoco_complete_horizon_count -eq 3 -and
    [int]$r23d68PhysicalExtension.mujoco_partial_serialization_file_count -eq 3 -and
    [int]$r23d68PhysicalExtension.mujoco_boolean_serialization_failure_count -eq 3 -and
    [int]$r23d68PhysicalExtension.mujoco_outer_failure_projection_loss_count -eq 3 -and
    [int]$r23d68PhysicalExtension.execution_valid_cell_count -eq 0 -and
    [int]$r23d68PhysicalExtension.turning_evaluated_cell_count -eq 0 -and
    [double]$r23d68PhysicalExtension.equivalence_margin -eq 0.0 -and
    [double]$r23d68PhysicalExtension.non_inferiority_margin -eq 0.0 -and
    [bool]$r23d68PhysicalExtension.campaign_identity_consumed -and
    -not [bool]$r23d68PhysicalExtension.same_identity_rerun_allowed -and
    -not [bool]$r23d68PhysicalExtension.replacement_or_selective_rerun_allowed -and
    -not [bool]$r23d68PhysicalExtension.historical_campaign_reclassification_authorized -and
    -not [bool]$r23d68PhysicalExtension.supervisor_report_rewritten -and
    [int]$r23d68PhysicalExtension.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$r23d68PhysicalExtension.maintenance_process_physical_world_count -eq 0 -and
    [int]$r23d68PhysicalExtension.r23d68_observed_complete_native_horizon_count -eq 9 -and
    -not [bool]$r23d68PhysicalExtension.r23d68_turning_claim_changed -and
    -not [bool]$r23d68PhysicalExtension.q_sdk_r23_satisfied -and
    [string]$r23d68PhysicalExtension.release_score_before -ceq "10/25" -and
    [string]$r23d68PhysicalExtension.release_score_after -ceq "10/25" -and
    -not [bool]$r23d68PhysicalExtension.cross_engine_equivalence_claimed -and
    -not [bool]$r23d68PhysicalExtension.prone_to_standing_claimed -and
    -not [bool]$r23d68PhysicalExtension.live_historical_identity_risk -and
    -not [bool]$r23d68PhysicalExtension.manual_review_required -and
    -not [bool]$r23d68PhysicalExtension.physical_acceptance_authority -and
    -not [bool]$r23d68PhysicalExtension.release_authority
) "R23D68 physical-closure inventory extension changed"

$r23d69PhysicalExtension =
    $contract.inventory.r23d69_physical_closure_inventory_extension
$r23d69PhysicalInventoryEntry = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d69_physical_closure.ps1"
})
Assert-Exact (
    [string]$r23d69PhysicalExtension.maintenance_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$r23d69PhysicalExtension.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$r23d69PhysicalExtension.declared_from_physical_source_commit -ceq
        "2b7a2be1012d7e1d8f2ca41a6c4cd71769d097f7" -and
    [string]$r23d69PhysicalExtension.declared_from_physical_source_tree_git_oid -ceq
        "7c0e9e99fabed27f819b65dbf4d24f72690dd5de" -and
    [int]$r23d69PhysicalExtension.inventory_population_size -eq 179 -and
    [bool]$r23d69PhysicalExtension.inventory_population_compared_completely -and
    [int]$r23d69PhysicalExtension.inventory_sample_size -eq 179 -and
    -not [bool]$r23d69PhysicalExtension.inventory_sampling_claimed -and
    [int]$r23d69PhysicalExtension.pre_extension_audit_count -eq 178 -and
    [int]$r23d69PhysicalExtension.post_extension_audit_count -eq 179 -and
    [int]$r23d69PhysicalExtension.added_audit_count -eq 1 -and
    [int]$r23d69PhysicalExtension.changed_audit_count -eq 0 -and
    [int]$r23d69PhysicalExtension.removed_audit_count -eq 0 -and
    [int]$r23d69PhysicalExtension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$r23d69PhysicalExtension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$r23d69PhysicalExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r23d69PhysicalExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r23d69PhysicalExtension.manual_review_required_count_delta -eq 0 -and
    $r23d69PhysicalInventoryEntry.Count -eq 1 -and
    ($r23d69PhysicalInventoryEntry[0] | ConvertTo-Json -Depth 20 -Compress) -ceq
        ($r23d69PhysicalExtension.added_entry | ConvertTo-Json -Depth 20 -Compress) -and
    [int]$r23d69PhysicalExtension.complete_retained_physical_file_population_count -eq 75 -and
    [long]$r23d69PhysicalExtension.complete_retained_physical_file_population_byte_count -eq 779848989 -and
    [bool]$r23d69PhysicalExtension.complete_retained_physical_file_population_compared -and
    [int]$r23d69PhysicalExtension.retained_physical_unique_digest_count -eq 58 -and
    [int]$r23d69PhysicalExtension.retained_physical_cas_backed_file_count -eq 66 -and
    [int]$r23d69PhysicalExtension.retained_physical_non_cas_file_count -eq 9 -and
    [string]$r23d69PhysicalExtension.retained_physical_population_manifest_sha256 -ceq
        "sha256:3a1fb9af425fc19ae86010cbf6ad8f779618262ee6f58e757d4934618ccd12c6" -and
    [int]$r23d69PhysicalExtension.complete_retained_qualification_file_population_count -eq 50 -and
    [long]$r23d69PhysicalExtension.complete_retained_qualification_file_population_byte_count -eq 497000 -and
    [string]$r23d69PhysicalExtension.retained_qualification_population_manifest_sha256 -ceq
        "sha256:89fca256b93de301385f577a780b141b3789efa3d9f3030ea27e8925adf63e5f" -and
    [int]$r23d69PhysicalExtension.qualification_gate_pass_count -eq 16 -and
    [bool]$r23d69PhysicalExtension.qualification_adoption_passed -and
    [int]$r23d69PhysicalExtension.authorization_preflight_receipt_count -eq 9 -and
    [int]$r23d69PhysicalExtension.authorization_preflight_pass_count -eq 9 -and
    [int]$r23d69PhysicalExtension.physical_worker_process_count -eq 9 -and
    [int]$r23d69PhysicalExtension.world_attempt_count -eq 9 -and
    [int]$r23d69PhysicalExtension.world_build_count -eq 9 -and
    [bool]$r23d69PhysicalExtension.world_count_exact -and
    [int]$r23d69PhysicalExtension.complete_native_horizon_count -eq 9 -and
    [int]$r23d69PhysicalExtension.complete_retained_trace_count -eq 9 -and
    [int]$r23d69PhysicalExtension.retained_trace_row_count_per_cell -eq 2992 -and
    [int]$r23d69PhysicalExtension.total_retained_trace_row_count -eq 26928 -and
    [int]$r23d69PhysicalExtension.shared_receipt_schema_failure_count -eq 9 -and
    -not [bool]$r23d69PhysicalExtension.producer_top_level_row_count_present -and
    [bool]$r23d69PhysicalExtension.producer_nested_trace_summary_row_count_present -and
    [int]$r23d69PhysicalExtension.frozen_top_level_row_count_consumer_count -eq 3 -and
    [int]$r23d69PhysicalExtension.execution_valid_cell_count -eq 0 -and
    [int]$r23d69PhysicalExtension.turning_evaluated_cell_count -eq 0 -and
    [double]$r23d69PhysicalExtension.equivalence_margin -eq 0.0 -and
    [double]$r23d69PhysicalExtension.non_inferiority_margin -eq 0.0 -and
    [bool]$r23d69PhysicalExtension.pre_root_operator_invocation_recorded -and
    [int]$r23d69PhysicalExtension.pre_root_operator_invocation_world_count -eq 0 -and
    -not [bool]$r23d69PhysicalExtension.pre_root_operator_invocation_consumed_finite_identity -and
    [bool]$r23d69PhysicalExtension.campaign_identity_consumed -and
    -not [bool]$r23d69PhysicalExtension.same_identity_rerun_allowed -and
    -not [bool]$r23d69PhysicalExtension.replacement_or_selective_rerun_allowed -and
    -not [bool]$r23d69PhysicalExtension.historical_campaign_reclassification_authorized -and
    -not [bool]$r23d69PhysicalExtension.supervisor_report_rewritten -and
    [int]$r23d69PhysicalExtension.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$r23d69PhysicalExtension.maintenance_process_physical_world_count -eq 0 -and
    [int]$r23d69PhysicalExtension.r23d69_observed_complete_native_horizon_count -eq 9 -and
    -not [bool]$r23d69PhysicalExtension.r23d69_turning_claim_changed -and
    -not [bool]$r23d69PhysicalExtension.q_sdk_r23_satisfied -and
    [string]$r23d69PhysicalExtension.release_score_before -ceq "10/25" -and
    [string]$r23d69PhysicalExtension.release_score_after -ceq "10/25" -and
    -not [bool]$r23d69PhysicalExtension.cross_engine_equivalence_claimed -and
    -not [bool]$r23d69PhysicalExtension.prone_to_standing_claimed -and
    -not [bool]$r23d69PhysicalExtension.live_historical_identity_risk -and
    -not [bool]$r23d69PhysicalExtension.manual_review_required -and
    -not [bool]$r23d69PhysicalExtension.physical_acceptance_authority -and
    -not [bool]$r23d69PhysicalExtension.release_authority
) "R23D69 physical-closure inventory extension changed"

$r23d70PhysicalExtension =
    $contract.inventory.r23d70_physical_closure_inventory_extension
$r23d70PhysicalInventoryEntry = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d70_physical_closure.ps1"
})
$r23d71FailedQualificationRoot = [IO.Path]::GetFullPath(
    [string]$r23d70PhysicalExtension.r23d71_initial_qualification_root
)
$r23d71FailedQualificationFiles = @(
    Get-ChildItem -LiteralPath $r23d71FailedQualificationRoot -Recurse -File |
        Sort-Object FullName
)
$r23d71FailedQualificationRows = @(
    foreach ($file in $r23d71FailedQualificationFiles) {
        $relative = [IO.Path]::GetRelativePath(
            $r23d71FailedQualificationRoot,
            $file.FullName
        ).Replace("\", "/")
        $sha = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).
            Hash.ToLowerInvariant()
        "$relative`t$($file.Length)`tsha256:$sha"
    }
)
$r23d71FailedQualificationManifestRaw =
    ($r23d71FailedQualificationRows -join "`n") + "`n"
$r23d71FailedQualificationManifestSha = "sha256:" + [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData(
        [Text.Encoding]::UTF8.GetBytes($r23d71FailedQualificationManifestRaw)
    )
).ToLowerInvariant()
$r23d71FailedQualificationFailurePath = Join-Path (
    $r23d71FailedQualificationRoot
) "failure.json"
$r23d71FailedQualificationProvenanceReceiptPath = Join-Path (
    $r23d71FailedQualificationRoot
) "004-CAK1-EVIDENCE-PROVENANCE.receipt.json"
Assert-Exact (
    [string]$r23d70PhysicalExtension.maintenance_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$r23d70PhysicalExtension.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$r23d70PhysicalExtension.qualification_work_class -ceq
        "exact_clean_pushed_campaign_local_process_qualification" -and
    [string]$r23d70PhysicalExtension.declared_from_physical_source_commit -ceq
        "fc79836bf440e9958e6d05179834c9fe44c7acf5" -and
    [string]$r23d70PhysicalExtension.declared_from_physical_source_tree_git_oid -ceq
        "79f0c1dfcc7e1e6b36d089ac633f4539fdada827" -and
    [string]$r23d70PhysicalExtension.declared_from_failed_qualification_source_commit -ceq
        "3e433d359753abc89abdf1418fd6bbfa9f4a9acf" -and
    [string]$r23d70PhysicalExtension.declared_from_failed_qualification_source_tree_git_oid -ceq
        "eac8067620cd0af5f454d5e18bc2e75ef1dc9b47" -and
    [int]$r23d70PhysicalExtension.inventory_population_size -eq 180 -and
    [bool]$r23d70PhysicalExtension.inventory_population_compared_completely -and
    [int]$r23d70PhysicalExtension.inventory_sample_size -eq 180 -and
    -not [bool]$r23d70PhysicalExtension.inventory_sampling_claimed -and
    [int]$r23d70PhysicalExtension.pre_extension_audit_count -eq 179 -and
    [int]$r23d70PhysicalExtension.post_extension_audit_count -eq 180 -and
    [int]$r23d70PhysicalExtension.added_audit_count -eq 1 -and
    [int]$r23d70PhysicalExtension.changed_audit_count -eq 0 -and
    [int]$r23d70PhysicalExtension.removed_audit_count -eq 0 -and
    [int]$r23d70PhysicalExtension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$r23d70PhysicalExtension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$r23d70PhysicalExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r23d70PhysicalExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r23d70PhysicalExtension.manual_review_required_count_delta -eq 0 -and
    $r23d70PhysicalInventoryEntry.Count -eq 1 -and
    ($r23d70PhysicalInventoryEntry[0] | ConvertTo-Json -Depth 20 -Compress) -ceq
        ($r23d70PhysicalExtension.added_entry | ConvertTo-Json -Depth 20 -Compress) -and
    [int]$r23d70PhysicalExtension.complete_retained_r23d70_physical_file_population_count -eq 26 -and
    [long]$r23d70PhysicalExtension.complete_retained_r23d70_physical_file_population_byte_count -eq 70628011 -and
    [int]$r23d70PhysicalExtension.retained_r23d70_physical_unique_digest_count -eq 17 -and
    [int]$r23d70PhysicalExtension.retained_r23d70_physical_cas_backed_file_count -eq 25 -and
    [int]$r23d70PhysicalExtension.retained_r23d70_physical_non_cas_file_count -eq 1 -and
    [string]$r23d70PhysicalExtension.retained_r23d70_physical_population_manifest_sha256 -ceq
        "sha256:e1cc63926494bf66916b2ecbe2624c68d638f7ef3b5e84186cd0ccab58c865c8" -and
    [bool]$r23d70PhysicalExtension.r23d70_campaign_identity_consumed -and
    [int]$r23d70PhysicalExtension.r23d70_observed_physical_world_count -eq 1 -and
    -not [bool]$r23d70PhysicalExtension.r23d70_turning_claim_changed -and
    [bool]$r23d70PhysicalExtension.r23d71_initial_qualification_failure_retained -and
    -not [bool]$r23d70PhysicalExtension.r23d71_initial_qualification_reusable -and
    [string]$r23d70PhysicalExtension.r23d71_initial_qualification_source_commit -ceq
        "3e433d359753abc89abdf1418fd6bbfa9f4a9acf" -and
    [string]$r23d70PhysicalExtension.r23d71_initial_qualification_failure_gate_id -ceq
        "CAK1-EVIDENCE-PROVENANCE" -and
    [string]$r23d70PhysicalExtension.r23d71_initial_qualification_failure_message -ceq
        "Closure evidence-mode executable inventory verification failed" -and
    [int]$r23d70PhysicalExtension.r23d71_initial_qualification_passed_gate_count -eq 3 -and
    $r23d71FailedQualificationFiles.Count -eq 13 -and
    [long]($r23d71FailedQualificationFiles |
        Measure-Object -Property Length -Sum).Sum -eq 12782 -and
    $r23d71FailedQualificationManifestSha -ceq
        "sha256:e470ae6478a91f3929f72d81e483daf4b6c917f4183f16a76e03a2e2b4ba735a" -and
    ("sha256:" + (Get-FileHash -LiteralPath $r23d71FailedQualificationFailurePath `
        -Algorithm SHA256).Hash.ToLowerInvariant()) -ceq
        "sha256:7753eff85b45d136d66a66e7ba20f38cdc8b44f62ec623362cead57c700b5143" -and
    ("sha256:" + (Get-FileHash `
        -LiteralPath $r23d71FailedQualificationProvenanceReceiptPath `
        -Algorithm SHA256).Hash.ToLowerInvariant()) -ceq
        "sha256:529059dd35fad5c0d3f2faa195b1b6f55ac9ae82834e6f0bd4aab40c1bce39c2" -and
    [bool]$r23d70PhysicalExtension.r23d71_retry_requires_distinct_corrected_clean_pushed_source -and
    -not [bool]$r23d70PhysicalExtension.r23d71_finite_identity_consumed -and
    [int]$r23d70PhysicalExtension.r23d71_physical_world_count -eq 0 -and
    [double]$r23d70PhysicalExtension.equivalence_margin -eq 0.0 -and
    [double]$r23d70PhysicalExtension.non_inferiority_margin -eq 0.0 -and
    -not [bool]$r23d70PhysicalExtension.historical_campaign_reclassification_authorized -and
    [int]$r23d70PhysicalExtension.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$r23d70PhysicalExtension.maintenance_process_physical_world_count -eq 0 -and
    -not [bool]$r23d70PhysicalExtension.q_sdk_r23_satisfied -and
    [string]$r23d70PhysicalExtension.release_score_before -ceq "10/25" -and
    [string]$r23d70PhysicalExtension.release_score_after -ceq "10/25" -and
    -not [bool]$r23d70PhysicalExtension.cross_engine_equivalence_claimed -and
    -not [bool]$r23d70PhysicalExtension.prone_to_standing_claimed -and
    -not [bool]$r23d70PhysicalExtension.live_historical_identity_risk -and
    -not [bool]$r23d70PhysicalExtension.manual_review_required -and
    -not [bool]$r23d70PhysicalExtension.physical_acceptance_authority -and
    -not [bool]$r23d70PhysicalExtension.release_authority
) "R23D70 physical-closure and R23D71 failed-qualification provenance changed"

$r23d71PhysicalExtension =
    $contract.inventory.r23d71_physical_closure_inventory_extension
$r23d71PhysicalInventoryEntry = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d71_physical_closure.ps1"
})
Assert-Exact (
    [string]$r23d71PhysicalExtension.maintenance_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$r23d71PhysicalExtension.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$r23d71PhysicalExtension.declared_from_physical_source_commit -ceq
        "f82e3454dd8cfa53a7efced948c9ba130a0e2cda" -and
    [string]$r23d71PhysicalExtension.declared_from_physical_source_tree_git_oid -ceq
        "e35098f839f6dcdc6af2a0620bfd8335b7735381" -and
    [int]$r23d71PhysicalExtension.inventory_population_size -eq 181 -and
    [bool]$r23d71PhysicalExtension.inventory_population_compared_completely -and
    [int]$r23d71PhysicalExtension.inventory_sample_size -eq 181 -and
    -not [bool]$r23d71PhysicalExtension.inventory_sampling_claimed -and
    [int]$r23d71PhysicalExtension.pre_extension_audit_count -eq 180 -and
    [int]$r23d71PhysicalExtension.post_extension_audit_count -eq 181 -and
    [int]$r23d71PhysicalExtension.added_audit_count -eq 1 -and
    [int]$r23d71PhysicalExtension.changed_audit_count -eq 0 -and
    [int]$r23d71PhysicalExtension.removed_audit_count -eq 0 -and
    [int]$r23d71PhysicalExtension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$r23d71PhysicalExtension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$r23d71PhysicalExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r23d71PhysicalExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r23d71PhysicalExtension.manual_review_required_count_delta -eq 0 -and
    $r23d71PhysicalInventoryEntry.Count -eq 1 -and
    ($r23d71PhysicalInventoryEntry[0] | ConvertTo-Json -Depth 20 -Compress) -ceq
        ($r23d71PhysicalExtension.added_entry | ConvertTo-Json -Depth 20 -Compress) -and
    [int]$r23d71PhysicalExtension.complete_retained_qualification_file_population_count -eq 50 -and
    [long]$r23d71PhysicalExtension.complete_retained_qualification_file_population_byte_count -eq 499566 -and
    [string]$r23d71PhysicalExtension.retained_qualification_population_manifest_sha256 -ceq
        "sha256:8b8e636ae4ba4d72413f59b4fbb134625ac32dcd59dc8969252b56e886a183f9" -and
    [int]$r23d71PhysicalExtension.qualification_gate_pass_count -eq 16 -and
    [bool]$r23d71PhysicalExtension.qualification_adoption_passed -and
    [int]$r23d71PhysicalExtension.complete_retained_physical_file_population_count -eq 72 -and
    [long]$r23d71PhysicalExtension.complete_retained_physical_file_population_byte_count -eq 677221819 -and
    [int]$r23d71PhysicalExtension.retained_physical_unique_digest_count -eq 54 -and
    [int]$r23d71PhysicalExtension.retained_physical_cas_backed_file_count -eq 63 -and
    [int]$r23d71PhysicalExtension.retained_physical_non_cas_file_count -eq 9 -and
    [string]$r23d71PhysicalExtension.retained_physical_population_manifest_sha256 -ceq
        "sha256:28f122f0ed80f1aa50e0ef9ff8b76105d339dd35d186ddbb0f66b03f72f653c7" -and
    [int]$r23d71PhysicalExtension.authorization_preflight_receipt_count -eq 9 -and
    [int]$r23d71PhysicalExtension.authorization_preflight_pass_count -eq 9 -and
    [int]$r23d71PhysicalExtension.world_attempt_count -eq 9 -and
    [int]$r23d71PhysicalExtension.world_build_count -eq 9 -and
    [bool]$r23d71PhysicalExtension.world_count_exact -and
    [int]$r23d71PhysicalExtension.complete_native_horizon_count -eq 9 -and
    [int]$r23d71PhysicalExtension.complete_retained_trace_count -eq 9 -and
    [int]$r23d71PhysicalExtension.retained_trace_row_count_per_cell -eq 2992 -and
    [int]$r23d71PhysicalExtension.total_retained_trace_row_count -eq 26928 -and
    [int]$r23d71PhysicalExtension.supervisor_success_terminal_count -eq 6 -and
    [int]$r23d71PhysicalExtension.supervisor_transport_failure_count -eq 3 -and
    [int]$r23d71PhysicalExtension.frozen_trace_artifact_identity_failure_count -eq 6 -and
    [int]$r23d71PhysicalExtension.mujoco_missing_question_class_count -eq 3 -and
    [int]$r23d71PhysicalExtension.rapier_forward_displacement_failure_count -eq 3 -and
    [int]$r23d71PhysicalExtension.execution_valid_cell_count -eq 0 -and
    [bool]$r23d71PhysicalExtension.campaign_identity_consumed -and
    -not [bool]$r23d71PhysicalExtension.same_identity_rerun_allowed -and
    -not [bool]$r23d71PhysicalExtension.replacement_or_selective_rerun_allowed -and
    [double]$r23d71PhysicalExtension.equivalence_margin -eq 0.0 -and
    [double]$r23d71PhysicalExtension.non_inferiority_margin -eq 0.0 -and
    -not [bool]$r23d71PhysicalExtension.historical_campaign_reclassification_authorized -and
    [int]$r23d71PhysicalExtension.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$r23d71PhysicalExtension.maintenance_process_physical_world_count -eq 0 -and
    -not [bool]$r23d71PhysicalExtension.q_sdk_r23_satisfied -and
    [string]$r23d71PhysicalExtension.release_score_before -ceq "10/25" -and
    [string]$r23d71PhysicalExtension.release_score_after -ceq "10/25" -and
    -not [bool]$r23d71PhysicalExtension.cross_engine_equivalence_claimed -and
    -not [bool]$r23d71PhysicalExtension.prone_to_standing_claimed -and
    -not [bool]$r23d71PhysicalExtension.live_historical_identity_risk -and
    -not [bool]$r23d71PhysicalExtension.manual_review_required -and
    -not [bool]$r23d71PhysicalExtension.physical_acceptance_authority -and
    -not [bool]$r23d71PhysicalExtension.release_authority
) "R23D71 physical-closure provenance extension changed"

$r23d74PhysicalExtension =
    $contract.inventory.r23d74_physical_closure_inventory_extension
$r23d74PhysicalInventoryEntry = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d74_physical_closure.ps1"
})
Assert-Exact (
    [string]$r23d74PhysicalExtension.maintenance_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$r23d74PhysicalExtension.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$r23d74PhysicalExtension.declared_from_physical_source_commit -ceq
        "32b9db7f67c15f72181a5e5ac8a412e5f7a51a57" -and
    [string]$r23d74PhysicalExtension.declared_from_physical_source_tree_git_oid -ceq
        "939d356e6ca8e94361f8d4ff8cafaee75865f07d" -and
    [int]$r23d74PhysicalExtension.inventory_population_size -eq 182 -and
    [bool]$r23d74PhysicalExtension.inventory_population_compared_completely -and
    [int]$r23d74PhysicalExtension.inventory_sample_size -eq 182 -and
    -not [bool]$r23d74PhysicalExtension.inventory_sampling_claimed -and
    [int]$r23d74PhysicalExtension.pre_extension_audit_count -eq 181 -and
    [int]$r23d74PhysicalExtension.post_extension_audit_count -eq 182 -and
    [int]$r23d74PhysicalExtension.added_audit_count -eq 1 -and
    [int]$r23d74PhysicalExtension.changed_audit_count -eq 0 -and
    [int]$r23d74PhysicalExtension.removed_audit_count -eq 0 -and
    [int]$r23d74PhysicalExtension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$r23d74PhysicalExtension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$r23d74PhysicalExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r23d74PhysicalExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r23d74PhysicalExtension.manual_review_required_count_delta -eq 0 -and
    $r23d74PhysicalInventoryEntry.Count -eq 1 -and
    ($r23d74PhysicalInventoryEntry[0] | ConvertTo-Json -Depth 20 -Compress) -ceq
        ($r23d74PhysicalExtension.added_entry | ConvertTo-Json -Depth 20 -Compress) -and
    [int]$r23d74PhysicalExtension.nested_lock_negative_file_population_count -eq 40 -and
    [string]$r23d74PhysicalExtension.nested_lock_negative_population_manifest_sha256 -ceq
        "sha256:101567ff4e1d985ceec5fdecf9534088baf039905d868d7694e8c9623be6158e" -and
    [int]$r23d74PhysicalExtension.inventory_negative_file_population_count -eq 13 -and
    [string]$r23d74PhysicalExtension.inventory_negative_population_manifest_sha256 -ceq
        "sha256:43f1975c8b57966b9aa8ba150bf858c3447a2149659b1cac9bce8c5fa1b8a2be" -and
    [int]$r23d74PhysicalExtension.passing_nonadoptable_qualification_file_population_count -eq 49 -and
    [string]$r23d74PhysicalExtension.passing_nonadoptable_qualification_population_manifest_sha256 -ceq
        "sha256:f192424eb9a400a4bd8faeea34568b03ae27030f9523165b1115e5d3e9bbd548" -and
    [int]$r23d74PhysicalExtension.passing_adopted_qualification_file_population_count -eq 50 -and
    [long]$r23d74PhysicalExtension.passing_adopted_qualification_file_population_byte_count -eq 502494 -and
    [string]$r23d74PhysicalExtension.passing_adopted_qualification_population_manifest_sha256 -ceq
        "sha256:4514cff8962f75092b6793571c0631f7de96bfda93fc09879276e5bcb75c0e95" -and
    [int]$r23d74PhysicalExtension.qualification_gate_pass_count -eq 16 -and
    [bool]$r23d74PhysicalExtension.qualification_adoption_passed -and
    [int]$r23d74PhysicalExtension.complete_retained_physical_file_population_count -eq 67 -and
    [long]$r23d74PhysicalExtension.complete_retained_physical_file_population_byte_count -eq 575683495 -and
    [int]$r23d74PhysicalExtension.retained_physical_unique_digest_count -eq 49 -and
    [int]$r23d74PhysicalExtension.retained_physical_cas_backed_file_count -eq 58 -and
    [int]$r23d74PhysicalExtension.retained_physical_non_cas_file_count -eq 9 -and
    [string]$r23d74PhysicalExtension.retained_physical_population_manifest_sha256 -ceq
        "sha256:b2f86f47e922e20598c48d5317b2fef56425387f7b0c88ff954775b393f18821" -and
    [int]$r23d74PhysicalExtension.authorization_preflight_receipt_count -eq 9 -and
    [int]$r23d74PhysicalExtension.authorization_preflight_pass_count -eq 9 -and
    [int]$r23d74PhysicalExtension.world_attempt_count -eq 9 -and
    [int]$r23d74PhysicalExtension.world_build_count -eq 9 -and
    [bool]$r23d74PhysicalExtension.world_count_exact -and
    [int]$r23d74PhysicalExtension.complete_native_horizon_count -eq 9 -and
    [int]$r23d74PhysicalExtension.complete_retained_trace_count -eq 9 -and
    [int]$r23d74PhysicalExtension.retained_trace_row_count_per_cell -eq 2992 -and
    [int]$r23d74PhysicalExtension.total_retained_trace_row_count -eq 26928 -and
    [int]$r23d74PhysicalExtension.supervisor_success_terminal_count -eq 6 -and
    [int]$r23d74PhysicalExtension.supervisor_failure_terminal_count -eq 3 -and
    [int]$r23d74PhysicalExtension.mujoco_startup_trace_evaluator_binding_failure_count -eq 3 -and
    [int]$r23d74PhysicalExtension.complete_evaluator_accepted_cell_count -eq 0 -and
    [bool]$r23d74PhysicalExtension.campaign_identity_consumed -and
    -not [bool]$r23d74PhysicalExtension.same_identity_rerun_allowed -and
    -not [bool]$r23d74PhysicalExtension.replacement_or_selective_rerun_allowed -and
    [double]$r23d74PhysicalExtension.equivalence_margin -eq 0.0 -and
    [double]$r23d74PhysicalExtension.non_inferiority_margin -eq 0.0 -and
    -not [bool]$r23d74PhysicalExtension.historical_campaign_reclassification_authorized -and
    [int]$r23d74PhysicalExtension.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$r23d74PhysicalExtension.maintenance_process_physical_world_count -eq 0 -and
    -not [bool]$r23d74PhysicalExtension.q_sdk_r23_satisfied -and
    [string]$r23d74PhysicalExtension.release_score_before -ceq "10/25" -and
    [string]$r23d74PhysicalExtension.release_score_after -ceq "10/25" -and
    -not [bool]$r23d74PhysicalExtension.cross_engine_equivalence_claimed -and
    -not [bool]$r23d74PhysicalExtension.prone_to_standing_claimed -and
    -not [bool]$r23d74PhysicalExtension.live_historical_identity_risk -and
    -not [bool]$r23d74PhysicalExtension.manual_review_required -and
    -not [bool]$r23d74PhysicalExtension.physical_acceptance_authority -and
    -not [bool]$r23d74PhysicalExtension.release_authority
) "R23D74 physical-closure provenance extension changed"

$r23d75ConformanceExtension =
    $contract.inventory.r23d75_native_startup_trace_evaluator_conformance_closure_inventory_extension
$r23d75ConformanceInventoryEntry = @($inventory.entries | Where-Object {
    [string]$_.path -ceq
        "tests/test_qsdk_r23d75_native_startup_trace_evaluator_conformance_closure.ps1"
})
Assert-Exact (
    [string]$r23d75ConformanceExtension.maintenance_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$r23d75ConformanceExtension.development_question_class_inherited_unchanged -ceq
        "development" -and
    [string]$r23d75ConformanceExtension.declared_from_source_commit -ceq
        "440c375cc8d082461fd1de1ccb71d5a696103eb6" -and
    [string]$r23d75ConformanceExtension.declared_from_source_tree_git_oid -ceq
        "4beb62aa6a7b53764e381d3318e83db8fa20e578" -and
    [string]$r23d75ConformanceExtension.closure_path -ceq
        "sdk/turning/r23d75_native_startup_trace_evaluator_conformance_closure_v1.json" -and
    [string]$r23d75ConformanceExtension.closure_raw_sha256 -ceq
        "sha256:b5c637c0c59c5cc23fa6224494a4dd8914610da4c1a892067f7f736f133e7fde" -and
    [int]$r23d75ConformanceExtension.inventory_population_size -eq 183 -and
    [bool]$r23d75ConformanceExtension.inventory_population_compared_completely -and
    [int]$r23d75ConformanceExtension.inventory_sample_size -eq 183 -and
    -not [bool]$r23d75ConformanceExtension.inventory_sampling_claimed -and
    [int]$r23d75ConformanceExtension.pre_extension_audit_count -eq 182 -and
    [int]$r23d75ConformanceExtension.post_extension_audit_count -eq 183 -and
    [int]$r23d75ConformanceExtension.added_audit_count -eq 1 -and
    [int]$r23d75ConformanceExtension.changed_audit_count -eq 0 -and
    [int]$r23d75ConformanceExtension.removed_audit_count -eq 0 -and
    [int]$r23d75ConformanceExtension.cas_path_check_signature_count_delta -eq 0 -and
    [int]$r23d75ConformanceExtension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$r23d75ConformanceExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r23d75ConformanceExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r23d75ConformanceExtension.manual_review_required_count_delta -eq 0 -and
    $r23d75ConformanceInventoryEntry.Count -eq 1 -and
    ($r23d75ConformanceInventoryEntry[0] | ConvertTo-Json -Depth 20 -Compress) -ceq
        ($r23d75ConformanceExtension.added_entry | ConvertTo-Json -Depth 20 -Compress) -and
    [int]$r23d75ConformanceExtension.complete_engine_binding_enumeration_count -eq 3 -and
    [int]$r23d75ConformanceExtension.compact_positive_sequence_count -eq 6 -and
    [int]$r23d75ConformanceExtension.compact_row_count_per_sequence -eq 361 -and
    [int]$r23d75ConformanceExtension.sampled_boundary_step_count -eq 7 -and
    [int]$r23d75ConformanceExtension.startup_mutation_rejection_count -eq 19 -and
    [int]$r23d75ConformanceExtension.unsupported_engine_rejection_count -eq 1 -and
    [int]$r23d75ConformanceExtension.complete_retained_trace_count -eq 9 -and
    [int]$r23d75ConformanceExtension.complete_retained_trace_row_count -eq 26928 -and
    [int]$r23d75ConformanceExtension.complete_retained_trace_count_by_engine.godot_jolt -eq 3 -and
    [int]$r23d75ConformanceExtension.complete_retained_trace_count_by_engine.rapier_parry -eq 3 -and
    [int]$r23d75ConformanceExtension.complete_retained_trace_count_by_engine.mujoco -eq 3 -and
    [string]$r23d75ConformanceExtension.retained_trace_replay_projection_sha256 -ceq
        "sha256:d7f8f8e865959857cc59ce856294db80508a9f3bb4508d40fc8a542b43b33245" -and
    [double]$r23d75ConformanceExtension.equivalence_margin -eq 0.0 -and
    [double]$r23d75ConformanceExtension.non_inferiority_margin -eq 0.0 -and
    -not [bool]$r23d75ConformanceExtension.r23d74_result_reinterpreted -and
    [int]$r23d75ConformanceExtension.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$r23d75ConformanceExtension.maintenance_process_physical_world_count -eq 0 -and
    -not [bool]$r23d75ConformanceExtension.q_sdk_r23_satisfied -and
    [string]$r23d75ConformanceExtension.release_score_before -ceq "10/25" -and
    [string]$r23d75ConformanceExtension.release_score_after -ceq "10/25" -and
    -not [bool]$r23d75ConformanceExtension.finite_three_engine_turning_claimed -and
    -not [bool]$r23d75ConformanceExtension.cross_engine_equivalence_claimed -and
    -not [bool]$r23d75ConformanceExtension.prone_to_standing_claimed -and
    -not [bool]$r23d75ConformanceExtension.live_historical_identity_risk -and
    -not [bool]$r23d75ConformanceExtension.manual_review_required -and
    -not [bool]$r23d75ConformanceExtension.physical_acceptance_authority -and
    -not [bool]$r23d75ConformanceExtension.release_authority
) "R23D75 conformance-closure provenance extension changed"

$r23d76LateInventoryReconciliation =
    $contract.inventory.r23d78_successor_r23d76_late_closure_inventory_reconciliation
$r23d76LateInventoryEntry = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d76_physical_closure.ps1"
})
Assert-Exact (
    [string]$r23d76LateInventoryReconciliation.maintenance_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$r23d76LateInventoryReconciliation.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$r23d76LateInventoryReconciliation.r23d76_closure_audit_creation_commit -ceq
        "ae73563261654d9d272e1ede14336d64eb5a1fcc" -and
    [string]$r23d76LateInventoryReconciliation.r23d76_closure_audit_creation_tree_git_oid -ceq
        "3755f8d1c6482b18b15faef37f50b6d53acc903a" -and
    [string]$r23d76LateInventoryReconciliation.r23d78_failed_qualification_source_commit -ceq
        "0e47997990617ee5582b6ebacd552ad4a29378af" -and
    -not [bool]$r23d76LateInventoryReconciliation.r23d78_failed_qualification_reached_inventory_assertion -and
    [bool]$r23d76LateInventoryReconciliation.detected_during_distinct_corrected_successor_preparation -and
    [bool]$r23d76LateInventoryReconciliation.local_failure_observed -and
    [string]$r23d76LateInventoryReconciliation.local_failure_message -ceq
        "Closure evidence-mode executable inventory verification failed" -and
    [int]$r23d76LateInventoryReconciliation.inventory_population_size -eq 184 -and
    [bool]$r23d76LateInventoryReconciliation.inventory_population_compared_completely -and
    [int]$r23d76LateInventoryReconciliation.inventory_sample_size -eq 184 -and
    -not [bool]$r23d76LateInventoryReconciliation.inventory_sampling_claimed -and
    [int]$r23d76LateInventoryReconciliation.pre_reconciliation_audit_count -eq 183 -and
    [int]$r23d76LateInventoryReconciliation.post_reconciliation_audit_count -eq 184 -and
    [int]$r23d76LateInventoryReconciliation.added_audit_count -eq 1 -and
    [int]$r23d76LateInventoryReconciliation.changed_audit_count -eq 0 -and
    [int]$r23d76LateInventoryReconciliation.removed_audit_count -eq 0 -and
    [int]$r23d76LateInventoryReconciliation.cas_path_check_signature_count_delta -eq 0 -and
    [int]$r23d76LateInventoryReconciliation.pinned_git_blob_signature_count_delta -eq 0 -and
    [int]$r23d76LateInventoryReconciliation.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r23d76LateInventoryReconciliation.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r23d76LateInventoryReconciliation.manual_review_required_count_delta -eq 1 -and
    $r23d76LateInventoryEntry.Count -eq 1 -and
    ($r23d76LateInventoryEntry[0] | ConvertTo-Json -Depth 20 -Compress) -ceq
        ($r23d76LateInventoryReconciliation.added_entry |
            ConvertTo-Json -Depth 20 -Compress) -and
    [double]$r23d76LateInventoryReconciliation.equivalence_margin -eq 0.0 -and
    [double]$r23d76LateInventoryReconciliation.non_inferiority_margin -eq 0.0 -and
    -not [bool]$r23d76LateInventoryReconciliation.historical_r23d76_result_reinterpreted -and
    -not [bool]$r23d76LateInventoryReconciliation.historical_campaign_reclassification_authorized -and
    [int]$r23d76LateInventoryReconciliation.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$r23d76LateInventoryReconciliation.maintenance_process_physical_world_count -eq 0 -and
    [int]$r23d76LateInventoryReconciliation.r23d78_physical_world_count -eq 0 -and
    -not [bool]$r23d76LateInventoryReconciliation.r23d78_turning_claim_changed -and
    -not [bool]$r23d76LateInventoryReconciliation.q_sdk_r23_satisfied -and
    [string]$r23d76LateInventoryReconciliation.release_score_before -ceq "10/25" -and
    [string]$r23d76LateInventoryReconciliation.release_score_after -ceq "10/25" -and
    -not [bool]$r23d76LateInventoryReconciliation.cross_engine_equivalence_claimed -and
    -not [bool]$r23d76LateInventoryReconciliation.prone_to_standing_claimed -and
    -not [bool]$r23d76LateInventoryReconciliation.live_historical_identity_risk -and
    [bool]$r23d76LateInventoryReconciliation.manual_review_required -and
    -not [bool]$r23d76LateInventoryReconciliation.physical_acceptance_authority -and
    -not [bool]$r23d76LateInventoryReconciliation.release_authority
) "R23D76 late closure-inventory reconciliation changed"

$r23d78PhysicalClosureExtension =
    $contract.inventory.r23d78_physical_closure_inventory_extension
$r23d78PhysicalClosureEntry = @($inventory.entries | Where-Object {
    [string]$_.path -ceq "tests/test_qsdk_r23d78_physical_closure.ps1"
})
Assert-Exact (
    [string]$r23d78PhysicalClosureExtension.maintenance_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$r23d78PhysicalClosureExtension.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$r23d78PhysicalClosureExtension.physical_source_commit -ceq
        "7b876726ba1471c6acd228181a877bd18bbb08a3" -and
    [string]$r23d78PhysicalClosureExtension.physical_source_tree_git_oid -ceq
        "5a7ee58cff5eee5e2be9ddd7f369351fd5a8561f" -and
    [int]$r23d78PhysicalClosureExtension.inventory_population_size -eq 185 -and
    [bool]$r23d78PhysicalClosureExtension.inventory_population_compared_completely -and
    [int]$r23d78PhysicalClosureExtension.inventory_sample_size -eq 185 -and
    -not [bool]$r23d78PhysicalClosureExtension.inventory_sampling_claimed -and
    [int]$r23d78PhysicalClosureExtension.pre_extension_audit_count -eq 184 -and
    [int]$r23d78PhysicalClosureExtension.post_extension_audit_count -eq 185 -and
    [int]$r23d78PhysicalClosureExtension.added_audit_count -eq 1 -and
    [int]$r23d78PhysicalClosureExtension.changed_audit_count -eq 0 -and
    [int]$r23d78PhysicalClosureExtension.removed_audit_count -eq 0 -and
    [int]$r23d78PhysicalClosureExtension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$r23d78PhysicalClosureExtension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$r23d78PhysicalClosureExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r23d78PhysicalClosureExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r23d78PhysicalClosureExtension.manual_review_required_count_delta -eq 0 -and
    $r23d78PhysicalClosureEntry.Count -eq 1 -and
    ($r23d78PhysicalClosureEntry[0] | ConvertTo-Json -Depth 20 -Compress) -ceq
        ($r23d78PhysicalClosureExtension.added_entry |
            ConvertTo-Json -Depth 20 -Compress) -and
    [double]$r23d78PhysicalClosureExtension.equivalence_margin -eq 0.0 -and
    [double]$r23d78PhysicalClosureExtension.non_inferiority_margin -eq 0.0 -and
    -not [bool]$r23d78PhysicalClosureExtension.historical_result_reinterpreted -and
    -not [bool]$r23d78PhysicalClosureExtension.historical_campaign_reclassification_authorized -and
    [int]$r23d78PhysicalClosureExtension.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$r23d78PhysicalClosureExtension.maintenance_process_physical_world_count -eq 0 -and
    [int]$r23d78PhysicalClosureExtension.retained_r23d78_physical_world_count -eq 9 -and
    [bool]$r23d78PhysicalClosureExtension.r23d78_finite_three_engine_turning_positive -and
    [bool]$r23d78PhysicalClosureExtension.q_sdk_r23_satisfied -and
    [string]$r23d78PhysicalClosureExtension.release_score_before -ceq "10/25" -and
    [string]$r23d78PhysicalClosureExtension.release_score_after -ceq "11/25" -and
    -not [bool]$r23d78PhysicalClosureExtension.cross_engine_equivalence_claimed -and
    -not [bool]$r23d78PhysicalClosureExtension.prone_to_standing_claimed -and
    -not [bool]$r23d78PhysicalClosureExtension.live_historical_identity_risk -and
    -not [bool]$r23d78PhysicalClosureExtension.manual_review_required -and
    -not [bool]$r23d78PhysicalClosureExtension.physical_acceptance_authority -and
    -not [bool]$r23d78PhysicalClosureExtension.release_authority
) "R23D78 physical-closure provenance extension changed"

$r24d10ZeroWorldClosureExtension =
    $contract.inventory.r24d10_zero_world_positive_closure_inventory_extension
$r24d10ZeroWorldClosureEntry = @($inventory.entries | Where-Object {
    [string]$_.path -ceq
        "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_zero_world_positive_closure.ps1"
})
Assert-Exact (
    [string]$r24d10ZeroWorldClosureExtension.maintenance_question_class -ceq
        "equivalence_non_inferiority" -and
    [string]$r24d10ZeroWorldClosureExtension.physical_question_class -ceq
        "development" -and
    [string]$r24d10ZeroWorldClosureExtension.zero_world_source_commit -ceq
        "11df9b566dda911c6c3f1a8ad76369c8ee0c340e" -and
    [string]$r24d10ZeroWorldClosureExtension.zero_world_source_tree_git_oid -ceq
        "3daee26820a8a9a6fbbc177ce4eaec2469b1d1dd" -and
    [int]$r24d10ZeroWorldClosureExtension.inventory_population_size -eq 186 -and
    [bool]$r24d10ZeroWorldClosureExtension.inventory_population_compared_completely -and
    [int]$r24d10ZeroWorldClosureExtension.inventory_sample_size -eq 186 -and
    -not [bool]$r24d10ZeroWorldClosureExtension.inventory_sampling_claimed -and
    [int]$r24d10ZeroWorldClosureExtension.pre_extension_audit_count -eq 185 -and
    [int]$r24d10ZeroWorldClosureExtension.post_extension_audit_count -eq 186 -and
    [int]$r24d10ZeroWorldClosureExtension.added_audit_count -eq 1 -and
    [int]$r24d10ZeroWorldClosureExtension.changed_audit_count -eq 0 -and
    [int]$r24d10ZeroWorldClosureExtension.removed_audit_count -eq 0 -and
    [int]$r24d10ZeroWorldClosureExtension.cas_path_check_signature_count_delta -eq 1 -and
    [int]$r24d10ZeroWorldClosureExtension.pinned_git_blob_signature_count_delta -eq 1 -and
    [int]$r24d10ZeroWorldClosureExtension.reconstructed_checkout_signature_count_delta -eq 0 -and
    [int]$r24d10ZeroWorldClosureExtension.live_historical_identity_risk_count_delta -eq 0 -and
    [int]$r24d10ZeroWorldClosureExtension.manual_review_required_count_delta -eq 0 -and
    $r24d10ZeroWorldClosureEntry.Count -eq 1 -and
    ($r24d10ZeroWorldClosureEntry[0] | ConvertTo-Json -Depth 20 -Compress) -ceq
        ($r24d10ZeroWorldClosureExtension.added_entry |
            ConvertTo-Json -Depth 20 -Compress) -and
    [double]$r24d10ZeroWorldClosureExtension.equivalence_margin -eq 0.0 -and
    [double]$r24d10ZeroWorldClosureExtension.non_inferiority_margin -eq 0.0 -and
    -not [bool]$r24d10ZeroWorldClosureExtension.historical_result_reinterpreted -and
    -not [bool]$r24d10ZeroWorldClosureExtension.historical_campaign_reclassification_authorized -and
    [int]$r24d10ZeroWorldClosureExtension.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$r24d10ZeroWorldClosureExtension.maintenance_process_physical_world_count -eq 0 -and
    [int]$r24d10ZeroWorldClosureExtension.retained_r24d10_physical_world_count -eq 0 -and
    [bool]$r24d10ZeroWorldClosureExtension.r24d10_complete_zero_world_gate_passed -and
    -not [bool]$r24d10ZeroWorldClosureExtension.r24d10_native_numerical_telemetry_characterized -and
    -not [bool]$r24d10ZeroWorldClosureExtension.q_sdk_r24_satisfied -and
    [string]$r24d10ZeroWorldClosureExtension.release_score_before -ceq "11/25" -and
    [string]$r24d10ZeroWorldClosureExtension.release_score_after -ceq "11/25" -and
    -not [bool]$r24d10ZeroWorldClosureExtension.cross_engine_equivalence_claimed -and
    -not [bool]$r24d10ZeroWorldClosureExtension.prone_to_standing_claimed -and
    -not [bool]$r24d10ZeroWorldClosureExtension.live_historical_identity_risk -and
    -not [bool]$r24d10ZeroWorldClosureExtension.manual_review_required -and
    -not [bool]$r24d10ZeroWorldClosureExtension.physical_acceptance_authority -and
    -not [bool]$r24d10ZeroWorldClosureExtension.release_authority
) "R24D10 zero-world positive-closure provenance extension changed"

$inventoryOutput = & pwsh `
    -NoLogo `
    -NoProfile `
    -File $analyzerPath `
    -VerifyInventory 2>&1 | Out-String
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $inventoryOutput.Contains(
        "CLOSURE_EVIDENCE_MODE_INVENTORY_PASS audits=186"
    ) -and
    $inventoryOutput.Contains("cas_path_checks=103") -and
    $inventoryOutput.Contains("git_blob=158") -and
    $inventoryOutput.Contains("reconstructed_checkout=4") -and
    $inventoryOutput.Contains("live_risk=0") -and
    $inventoryOutput.Contains("manual_review=28")
) "Closure evidence-mode executable inventory verification failed"
$global:LASTEXITCODE = 0

Assert-Exact (
    [double]$contract.performance_boundary.gjpt2_instrumented_seconds -eq 62.929861
) "GJPT2 provenance-contract timing identity changed"
Assert-Exact (
    [double]$contract.performance_boundary.physics_frame_wait_share -eq 0.05503332 -and
    [double]$contract.performance_boundary.active_pre_physics_excluding_native_boundary_share -eq 0.83972138 -and
    [bool]$contract.performance_boundary.process_parallelism_is_not_disproven_by_physics_frame_wait_share -and
    [bool]$contract.performance_boundary.process_parallelism_remains_blocked_on_load_independence_and_scaling_evidence -and
    [int]$contract.world_build_count -eq 0 -and
    -not [bool]$contract.historical_campaign_reclassification_authorized -and
    -not [bool]$contract.physical_execution_authorized -and
    -not [bool]$contract.release_authorized -and
    -not [bool]$contract.physical_acceptance_authority
) "Closure provenance or GJPT2 claim boundary changed"

Write-Host (
    "CLOSURE_EVIDENCE_PROVENANCE_CONTRACT_PASS audits=186 modes=4 " +
    "cas_path=103 git_blob=158 reconstructed_checkout=4 live_legacy=0 manual_review=28 " +
    "mv5_unretained_checkout=1 mv6_unretained_dll=1 r23d13_rules=13 " +
    "r23d14_rules=17 r23d15_rules=12 r23d16_rules=12 r23d17_rules=12 " +
    "lca1_rules=4 r23d19_inherited_godot_rules=3 r23d20_rules=6 " +
    "r23d21_rules=6 r23d22_rules=10 r23d23_rules=10 r23d24_rules=5 r23d25_rules=5 " +
    "r23d26_rules=7 trace_lineage_rules=3 r23d27_rules=13 r23d28_rules=6 " +
    "r23d29_rules=6 r23d30_rules=6 r23d31_rules=6 r23d32_closure_rules=2 " +
    "r23d33_rules=7 r23d34_rules=7 r23d35_rules=6 r23d36_rules=4 " +
    "r23d37_rules=6 r23d38_rules=4 r23d39_rules=4 r23d40_rules=9 " +
    "r23d41_rules=7 r23d42_rules=7 r23d43_rules=6 r23d44_rules=6 " +
    "r23d45_rules=4 r23d46_rules=6 r23d47_rules=5 r23d48_rules=8 " +
    "r23d49_rules=6 r23d50_rules=6 r23d51_rules=10 r23d52_rules=6 " +
    "r23d53_rules=4 r23d54_rules=4 r23d55_rules=4 r23d56_rules=4 " +
    "r23d57_rules=4 r23d57_transport_closure=1 r23d57_physical_closure=1 " +
    "r23d58_rules=5 r23d58_closure_inventory_delta=0 r23d59_rules=4 " +
    "r23d58_physical_closure=1 r23d59_dependency_closure_inventory=1 " +
    "r23d60_rules=4 r23d60_dependency_closure_inventory=1 " +
    "r23d59_physical_closure=1 r23d60_physical_closure=1 " +
    "r23d61_rules=4 r23d61_publication_closure_inventory=1 " +
    "r23d61_audit_dependency_reconciliation=1 " +
    "r23d62_dependency_closure_inventory=1 r23d62_post_rc12_inventory_hash_maintenance=1 " +
    "r23d62_rapier_route_rules=2 r23d63_physical_closure_inventory=1 " +
    "r23d64_dependency_closure_inventory=1 r23d64_physical_closure_inventory=1 " +
    "r23d65_first_qualification_inventory=1 r23d65_physical_closure_inventory=1 " +
    "r23d66_physical_closure_inventory=1 r23d67_physical_closure_inventory=1 " +
    "r23d68_physical_closure_inventory=1 r23d69_physical_closure_inventory=1 " +
    "r23d70_physical_closure_inventory=1 r23d71_initial_qualification_negative=1 " +
    "r23d71_physical_closure_inventory=1 r23d75_conformance_closure_inventory=1 " +
    "r24d1_rules=3 r24d2_rules=9 r24d2_integration_rules=8 r24d3_rules=6 " +
    "r24d4_rules=5 r24d4_pre_rule_blob_faithful_paths=8 " +
    "r24d4_zero_world_closure_paths=2 r24d4_closure_inventory=1 " +
    "r24d5_rules=5 r24d5_blob_faithful_paths=9 " +
    "r24d5_physical_closure_paths=2 r24d5_closure_inventory=1 " +
    "r24d6_rules=5 r24d6_blob_faithful_paths=9 " +
    "r24d6_zero_world_closure_paths=2 r24d6_closure_inventory=1 " +
    "r24d7_rules=5 r24d7_blob_faithful_paths=10 " +
    "r24d7_physical_closure_paths=2 r24d7_closure_inventory=1 " +
    "r24d8_rules=6 r24d8_blob_faithful_paths=12 " +
    "r24d9_rules=5 r24d9_blob_faithful_paths=2 " +
    "r24d9_physical_failure_closure_inventory=1 " +
    "filter_migration=False " +
    "worlds=0 history_reclassified=False physical_authority=False"
)

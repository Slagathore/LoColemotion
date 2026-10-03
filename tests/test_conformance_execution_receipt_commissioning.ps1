#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot (
    "conformance_execution_receipt_cold_equivalence_closure_v1.json"
)
$contractPath = Join-Path $sdkRoot (
    "conformance_execution_receipt_contract_v1.json"
)
$modulePath = Join-Path $sdkRoot "conformance_execution_receipt.ps1"
$runnerPath = Join-Path $sdkRoot (
    "run_conformance_execution_receipt_commissioning.ps1"
)
$canonicalRunnerPath = Join-Path $sdkRoot "run_conformance.ps1"

function Assert-Cer1Commissioning {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw "CER1 cold-equivalence closure audit failed: $Message"
    }
}

foreach ($path in @(
    $closurePath, $contractPath, $modulePath, $runnerPath, $canonicalRunnerPath
)) {
    Assert-Cer1Commissioning (Test-Path -LiteralPath $path -PathType Leaf) (
        "missing source: $path"
    )
}

. $modulePath
$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 64
$contract = Get-SporeSporeConformanceExecutionReceiptContract
$canonicalRunnerSource = Get-Content -LiteralPath $canonicalRunnerPath -Raw

Assert-Cer1Commissioning (
    [string]$closure.schema_version -ceq
        "sporespore_conformance_execution_receipt_cold_equivalence_closure_v1" -and
    [string]$closure.closure_id -ceq
        "CER1-R23D13-CLEAN-COLD-EQUIVALENCE-C1" -and
    [string]$closure.status -ceq
        "valid_positive_zero_world_process_commissioning_no_reuse_authority" -and
    [string]$contract.status -ceq
        "prospective_one_audit_cold_equivalence_uncommissioned" -and
    -not [bool]$contract.claims.cold_equivalence_complete -and
    -not [bool]$contract.claims.production_cache_lookup_permitted -and
    -not [bool]$contract.claims.production_result_reuse_permitted -and
    $canonicalRunnerSource.Contains(
        "tests\test_conformance_execution_receipt_commissioning.ps1",
        [StringComparison]::Ordinal
    )
) "closure identity or canonical route changed"

$sourceObjects = Get-SporeSporeGitObjectSetInventory `
    -RepoRoot $repoRoot `
    -Objects @(
        [ordered]@{
            role = "cer1_source_commit"
            object_id = [string]$closure.prospective_boundary.source_commit
            object_type = "commit"
        },
        [ordered]@{
            role = "cer1_source_tree"
            object_id = [string]$closure.prospective_boundary.source_tree
            object_type = "tree"
        }
    ) `
    -InventoryId "cer1_cold_equivalence_source"
Assert-Cer1Commissioning (
    [int]$sourceObjects.object_count -eq 2 -and
    [bool]$sourceObjects.git_object_ids_recomputed -and
    [string]$sourceObjects.inventory_sha256 -ceq
        [string]$closure.prospective_boundary.source_git_object_inventory_sha256
) "prospective source commit/tree bytes changed or disappeared"

$evidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
$relativeRecordPath = [string]$closure.executed_candidate.record_evidence_path
Assert-Cer1Commissioning (
    -not [IO.Path]::IsPathRooted($relativeRecordPath) -and
    -not $relativeRecordPath.Contains("..", [StringComparison]::Ordinal)
) "closure record path is not a bounded evidence-relative path"
$recordPath = Join-Path $evidenceRoot $relativeRecordPath
Assert-Cer1Commissioning (
    (Test-Path -LiteralPath $recordPath -PathType Leaf) -and
    (Get-Item -LiteralPath $recordPath).Length -eq
        [long]$closure.executed_candidate.record_byte_length -and
    (Get-SporeSporeDependencyRawSha256 $recordPath) -ceq
        [string]$closure.executed_candidate.record_sha256
) "retained candidate record bytes changed"

$readBack = Read-SporeSporeConformanceExecutionCandidate `
    -RepoRoot $repoRoot `
    -ExpectedInputKeySha256 (
        [string]$closure.executed_candidate.input_key_sha256
    )
Assert-Cer1Commissioning (
    [string]$readBack.status -ceq
        "verified_read_back_not_production_reuse" -and
    [string]$readBack.record_sha256 -ceq
        [string]$closure.executed_candidate.record_sha256 -and
    [string]$readBack.result_projection_sha256 -ceq
        [string]$closure.executed_candidate.result_projection_sha256 -and
    [string]$readBack.result.stdout_sha256 -ceq
        [string]$closure.executed_candidate.stdout_sha256 -and
    [long]$readBack.result.stdout_byte_length -eq
        [long]$closure.executed_candidate.stdout_byte_length -and
    [string]$readBack.result.stderr_sha256 -ceq
        [string]$closure.executed_candidate.stderr_sha256 -and
    [long]$readBack.result.stderr_byte_length -eq
        [long]$closure.executed_candidate.stderr_byte_length -and
    [string]$readBack.result.terminal_marker -ceq
        [string]$closure.executed_candidate.terminal_marker -and
    [int]$readBack.audit_invocation_count -eq 0 -and
    -not [bool]$readBack.cold_equivalence_complete -and
    -not [bool]$readBack.production_cache_lookup_permitted -and
    -not [bool]$readBack.production_result_reuse_permitted -and
    -not [bool]$readBack.physical_authority -and
    -not [bool]$readBack.release_authority
) "retained candidate read-back changed or exceeded CER1 authority"

Assert-Cer1Commissioning (
    [int]$closure.executed_candidate.audit_invocation_count -eq 1 -and
    [int]$closure.cold_read_back.audit_invocation_count -eq 0 -and
    [bool]$closure.cold_read_back.distinct_process -and
    [string]$closure.executed_candidate.input_key_sha256 -ceq
        [string]$closure.cold_read_back.input_key_sha256 -and
    [string]$closure.executed_candidate.record_sha256 -ceq
        [string]$closure.cold_read_back.record_sha256 -and
    [string]$closure.executed_candidate.result_projection_sha256 -ceq
        [string]$closure.cold_read_back.result_projection_sha256 -and
    [bool]$closure.cold_read_back.record_cas_verified -and
    [bool]$closure.cold_read_back.stdout_cas_verified -and
    [bool]$closure.cold_read_back.stderr_cas_verified -and
    [bool]$closure.cold_read_back.terminal_marker_verified -and
    [bool]$closure.cold_read_back.semantic_result_projection_equal -and
    [double]$closure.interpretation.speed_ratio_executed_process_over_read_back_process -eq
        2.044893 -and
    [double]$closure.interpretation.time_saved_seconds_for_this_observation -eq
        6.463421 -and
    [bool]$closure.interpretation.cold_equivalence_observed_for_exact_r23d13_audit -and
    [bool]$closure.interpretation.successor_reuse_contract_may_be_designed -and
    -not [bool]$closure.interpretation.population_or_cross_audit_claim -and
    -not [bool]$closure.interpretation.production_cache_lookup_currently_permitted -and
    -not [bool]$closure.interpretation.production_result_reuse_currently_permitted -and
    -not [bool]$closure.interpretation.historical_audit_waiver_currently_permitted
) "cold process comparison or interpretation changed"

Assert-Cer1Commissioning (
    [bool]$closure.claims.zero_world_process_commissioning_positive -and
    [bool]$closure.claims.exact_audit_cold_equivalence_observed -and
    -not [bool]$closure.claims.production_cache_lookup_permitted -and
    -not [bool]$closure.claims.production_result_reuse_permitted -and
    -not [bool]$closure.claims.historical_audit_waiver_permitted -and
    -not [bool]$closure.claims.movement_successor_authorized_by_this_closure -and
    -not [bool]$closure.claims.physical_execution_authorized -and
    -not [bool]$closure.claims.scientific_locomotion_authority -and
    -not [bool]$closure.claims.turning_authority -and
    -not [bool]$closure.claims.cross_engine_equivalence_authority -and
    -not [bool]$closure.claims.release_authority
) "CER1 closure claim boundary changed"

Write-Output (
    "CONFORMANCE_EXECUTION_RECEIPT_COMMISSIONING_PASS audit=r23d13 " +
    "source_objects=2 record_bytes=1920 execute_invocations=1 " +
    "readback_invocations=0 exact_projection=True speed_ratio=2.044893 " +
    "saved_seconds=6.463421 worlds=0 cache=disabled physical_authority=False " +
    "release_authority=False"
)

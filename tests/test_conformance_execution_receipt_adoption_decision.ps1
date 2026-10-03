#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$decisionPath = Join-Path $sdkRoot (
    "conformance_execution_receipt_adoption_decision_v1.json"
)
$closurePath = Join-Path $sdkRoot (
    "conformance_execution_receipt_cold_equivalence_closure_v1.json"
)
$contractPath = Join-Path $sdkRoot (
    "conformance_execution_receipt_contract_v1.json"
)
$dependencyKeyPath = Join-Path $sdkRoot "conformance_dependency_key.ps1"
$dependencyPath = Join-Path $sdkRoot "conformance_audit_dependency.ps1"
$runnerPath = Join-Path $sdkRoot "run_conformance.ps1"

function Assert-Cer1AdoptionDecision {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw "CER1 adoption-decision audit failed: $Message"
    }
}

foreach ($path in @(
    $decisionPath, $closurePath, $contractPath, $dependencyKeyPath,
    $dependencyPath, $runnerPath
)) {
    Assert-Cer1AdoptionDecision (Test-Path -LiteralPath $path -PathType Leaf) (
        "missing input: $path"
    )
}

. $dependencyKeyPath
. $dependencyPath
$decision = Get-Content -LiteralPath $decisionPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 32
$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 32
$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 32
$runnerSource = Get-Content -LiteralPath $runnerPath -Raw

Assert-Cer1AdoptionDecision (
    [string]$decision.schema_version -ceq
        "sporespore_conformance_execution_receipt_adoption_decision_v1" -and
    [string]$decision.decision_id -ceq
        "CER1-R23D13-PRODUCTION-REUSE-ADOPTION-D1" -and
    [string]$decision.status -ceq
        "negative_for_single_audit_speed_no_production_reuse" -and
    [string]$decision.subject.cold_equivalence_closure_id -ceq
        [string]$closure.closure_id -and
    [string]$decision.subject.audit_path -ceq
        [string]$closure.prospective_boundary.audit_path -and
    [string]$contract.status -ceq
        "prospective_one_audit_cold_equivalence_uncommissioned"
) "decision, closure, or contract identity changed"

$sourceObjects = Get-SporeSporeGitObjectSetInventory `
    -RepoRoot $repoRoot `
    -Objects @(
        [ordered]@{
            role = "cer1_adoption_decision_source_commit"
            object_id = [string]$decision.subject.decision_source_commit
            object_type = "commit"
        },
        [ordered]@{
            role = "cer1_adoption_decision_source_tree"
            object_id = [string]$decision.subject.decision_source_tree
            object_type = "tree"
        }
    ) `
    -InventoryId "cer1_adoption_decision_source"
Assert-Cer1AdoptionDecision (
    [int]$sourceObjects.object_count -eq 2 -and
    [bool]$sourceObjects.git_object_ids_recomputed
) "decision source commit/tree disappeared or failed raw rehash"

$direct = [double]$decision.comparison.direct_cold_process_seconds
$readBack = [double]$decision.comparison.verified_read_back_process_seconds
$ratio = [Math]::Round($readBack / $direct, 6)
$slowerSeconds = [Math]::Round($readBack - $direct, 7)
$slowerPercent = [Math]::Round((($readBack / $direct) - 1.0) * 100.0, 4)
Assert-Cer1AdoptionDecision (
    $direct -eq 5.2191931 -and
    $readBack -eq 6.1857223 -and
    $ratio -eq [double]$decision.comparison.read_back_over_direct_ratio -and
    $slowerSeconds -eq
        [double]$decision.comparison.read_back_slower_seconds -and
    $slowerPercent -eq
        [double]$decision.comparison.read_back_slower_percent -and
    [bool]$decision.comparison.direct_terminal_marker_reproduced -and
    [int]$decision.comparison.direct_exit_code -eq 0 -and
    [int]$decision.comparison.direct_audit_invocation_count -eq 1 -and
    [int]$decision.comparison.read_back_audit_invocation_count -eq 0 -and
    [int]$decision.comparison.physics_worlds_opened_by_either_process -eq 0
) "direct-versus-read-back arithmetic or observation changed"

$directRoute = '& (Join-Path $repoRoot "tests\test_qsdk_r23d13_closure.ps1")'
Assert-Cer1AdoptionDecision (
    [bool]$decision.interpretation.cold_semantic_equivalence_remains_positive -and
    [bool]$decision.interpretation.wrapper_to_wrapper_speedup_remains_true_for_the_commissioning_observation -and
    -not [bool]$decision.interpretation.canonical_single_audit_speedup_established -and
    [bool]$decision.interpretation.canonical_single_audit_reuse_is_counterproductive -and
    [bool]$decision.interpretation.direct_timing_transcript_was_not_separately_retained -and
    [string]$decision.interpretation.conservative_decision_despite_retention_limit -ceq
        "do_not_enable_reuse" -and
    [bool]$decision.scheduler_decision.keep_r23d13_direct_execution -and
    -not [bool]$decision.scheduler_decision.connect_r23d13_production_lookup -and
    -not [bool]$decision.scheduler_decision.connect_r23d13_production_reuse -and
    -not [bool]$decision.scheduler_decision.permit_historical_audit_waiver -and
    -not [bool]$decision.scheduler_decision.permit_silent_skip -and
    $runnerSource.Contains($directRoute, [StringComparison]::Ordinal) -and
    -not $runnerSource.Contains("-Mode ReadBack", [StringComparison]::Ordinal)
) "negative scheduler decision is not enforced by the canonical runner"

Assert-Cer1AdoptionDecision (
    -not [bool]$decision.claims.performance_adoption_positive -and
    -not [bool]$decision.claims.production_cache_lookup_permitted -and
    -not [bool]$decision.claims.production_result_reuse_permitted -and
    -not [bool]$decision.claims.historical_audit_waiver_permitted -and
    -not [bool]$decision.claims.physical_execution_authorized -and
    -not [bool]$decision.claims.scientific_locomotion_authority -and
    -not [bool]$decision.claims.release_authority -and
    -not [bool]$contract.claims.production_cache_lookup_permitted -and
    -not [bool]$contract.claims.production_result_reuse_permitted
) "negative adoption decision gained unsupported authority"

Write-Output (
    "CONFORMANCE_EXECUTION_RECEIPT_ADOPTION_DECISION_PASS audit=r23d13 " +
    "direct_seconds=5.2191931 readback_seconds=6.1857223 " +
    "readback_slower_percent=18.5187 direct_route_retained=True " +
    "reuse_adopted=False worlds=0 physical_authority=False release_authority=False"
)

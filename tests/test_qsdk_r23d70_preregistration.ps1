#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$parentCommit = "7d3cf80c99d5322e853d4657178db9c651e18189"
$parentTree = "645988ed14825da054f2c86d0814e65c83300a39"
$campaignId = "QSDK-R23D70-TRACE-RETENTION-RECEIPT-CONTRACT-REPAIRED-THREE-ENGINE-TURNING-VALIDATION"
$gateId = "QSDK-R23D70"
$status = "prospective_declaration_complete_minimal_receipt_contract_ghost_and_implementation_pending_physical_not_authorized"
$declarationPath = Join-Path $repoRoot (
    "sdk\turning\r23d70_trace_retention_receipt_contract_repaired_" +
    "three_engine_turning_preregistration_v1.json"
)
$compilerPath = Join-Path $repoRoot "sdk\turning\r23d70_seed_fixture_compiler.gd"
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d69_complete_production_row_three_engine_" +
    "turning_validation_closure_v1.json"
)
$closureAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d69_physical_closure.ps1"
$releasePath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$godot = "C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe"

function Assert-Exact([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D70 PREREGISTRATION: $Message" }
}

function Get-RawSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-ObjectMatches($Value, [scriptblock]$Predicate) {
    $matches = [Collections.Generic.List[object]]::new()
    function Visit($Item) {
        if ($null -eq $Item) { return }
        if ($Item -is [pscustomobject]) {
            if (& $Predicate $Item) { [void]$matches.Add($Item) }
            foreach ($property in $Item.PSObject.Properties) { Visit $property.Value }
            return
        }
        if ($Item -is [Collections.IEnumerable] -and $Item -isnot [string]) {
            foreach ($child in $Item) { Visit $child }
        }
    }
    Visit $Value
    return @($matches)
}

Assert-Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq $repoRoot.Replace("\", "/")
) "wrong repository"
Assert-Exact (
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "wrong origin"
Assert-Exact (
    (git -C $repoRoot rev-parse "$parentCommit`^{tree}").Trim() -ceq $parentTree
) "declaration parent tree changed"
Assert-Exact (
    (git -C $repoRoot rev-parse origin/main).Trim() -ceq $parentCommit
) "declaration parent is not the live tracking branch"

foreach ($path in @(
    $declarationPath,
    $compilerPath,
    $closurePath,
    $closureAuditPath,
    $releasePath,
    $supportPath,
    $godot
)) {
    Assert-Exact (Test-Path -LiteralPath $path -PathType Leaf) "missing authority: $path"
}

$declaration = Get-Content -LiteralPath $declarationPath -Raw | ConvertFrom-Json
$closure = Get-Content -LiteralPath $closurePath -Raw | ConvertFrom-Json
Assert-Exact (
    [string]$declaration.status -ceq $status -and
    [string]$declaration.campaign_id -ceq $campaignId -and
    [string]$declaration.gate_id -ceq $gateId -and
    [string]$declaration.release_gate_id -ceq "QSDK-R23" -and
    [string]$declaration.physical_question_class -ceq "finite_decision" -and
    [string]$declaration.integration_repair_work_class -ceq
        "development_then_complete_population_equivalence_non_inferiority" -and
    [string]$declaration.declaration_parent.commit -ceq $parentCommit -and
    [string]$declaration.declaration_parent.tree_git_oid -ceq $parentTree -and
    [string]$declaration.immutable_predecessor.gate_id -ceq "QSDK-R23D69" -and
    [string]$declaration.immutable_predecessor.closure_raw_sha256 -ceq
        "sha256:0838e5c53fe368c0dc04b2127c398ed19e7fd96370412cc7f6c9e26c162f5df2" -and
    [string]$declaration.immutable_predecessor.closure_audit_raw_sha256 -ceq
        "sha256:c496885ed8d436c8de54cf495e30d81f83566aa06b2e12dc7b0debd94e4b6077" -and
    [bool]$declaration.immutable_predecessor.campaign_identity_consumed -and
    -not [bool]$declaration.immutable_predecessor.same_identity_rerun_allowed -and
    [int]$declaration.immutable_predecessor.world_build_count -eq 9 -and
    [int]$declaration.immutable_predecessor.complete_retained_trace_count -eq 9 -and
    [int]$declaration.immutable_predecessor.execution_valid_cell_count -eq 0 -and
    -not [bool]$declaration.immutable_predecessor.turning_result_created
) "identity or immutable predecessor changed"

Assert-Exact (
    (Get-RawSha256 $closurePath) -ceq
        "sha256:0838e5c53fe368c0dc04b2127c398ed19e7fd96370412cc7f6c9e26c162f5df2" -and
    (Get-RawSha256 $closureAuditPath) -ceq
        "sha256:c496885ed8d436c8de54cf495e30d81f83566aa06b2e12dc7b0debd94e4b6077" -and
    [string]$closure.status -ceq
        "closed_consumed_invalid_complete_nine_cell_population_shared_trace_retention_receipt_schema_mismatch" -and
    [int]$closure.attempt.world_build_count -eq 9 -and
    [int]$closure.shared_receipt_schema_failure.affected_cell_count -eq 9 -and
    -not [bool]$closure.claims.turning_claimed
) "predecessor closure bytes or claims changed"

$seedHits = @(& git -C $repoRoot grep -I -n -E '(^|[^0-9])23189([^0-9]|$)' `
    $parentCommit -- . 2>$null | ForEach-Object { [string]$_ })
Assert-Exact ($seedHits.Count -eq 0 -and $LASTEXITCODE -eq 1) (
    "seed 23189 was not unused at the declaration parent"
)
$global:LASTEXITCODE = 0

Assert-Exact (
    (Get-RawSha256 $compilerPath) -ceq
        "sha256:d87068db66077db8f47cb3cfc3fc69cc9540a59fc66d8fc76e9c5f223f30a492" -and
    [int]$declaration.seed_fixture_compilation.seed -eq 23189 -and
    [int]$declaration.seed_fixture_compilation.model_construction_count -eq 0 -and
    [int]$declaration.seed_fixture_compilation.world_attempt_count -eq 0 -and
    [int]$declaration.seed_fixture_compilation.world_build_count -eq 0
) "seed compiler identity changed"

$godotOutput = @(& $godot --headless --path $repoRoot --script $compilerPath 2>&1 |
    ForEach-Object { [string]$_ })
Assert-Exact ($LASTEXITCODE -eq 0) "seed compiler execution failed"
$markers = @($godotOutput | Where-Object { $_ -clike "QSDK_R23D70_SEED_FIXTURES *" })
Assert-Exact ($markers.Count -eq 1) "seed compiler marker population changed"
$seedReceipt = $markers[0].Substring("QSDK_R23D70_SEED_FIXTURES ".Length) |
    ConvertFrom-Json
$fixture = @($seedReceipt.fixtures)[0]
Assert-Exact (
    @($seedReceipt.fixtures).Count -eq 1 -and
    [int]$fixture.campaign_seed -eq 23189 -and
    [double]$fixture.fixture_vertical_clearance_m -eq 0.0005549218039959669 -and
    [double]$fixture.fixture_yaw_rad -eq 0.0006206459365785122 -and
    [int]$fixture.gait_phase_offset_ticks -eq 3 -and
    [int]$seedReceipt.model_construction_count -eq 0 -and
    [int]$seedReceipt.world_attempt_count -eq 0 -and
    [int]$seedReceipt.world_build_count -eq 0 -and
    ($fixture | ConvertTo-Json -Depth 20 -Compress) -ceq
        ($declaration.seed_fixture_compilation.compiled_initial_perturbation |
            ConvertTo-Json -Depth 20 -Compress)
) "compiled seed fixture changed"

$change = $declaration.scientific_distinction_and_change_budget
$ghost = $declaration.compact_receipt_contract_ghost
$matrix = $declaration.frozen_matrix
$provenance = $declaration.threshold_and_population_provenance
$claims = $declaration.claims
Assert-Exact (
    [int]$change.fresh_seed -eq 23189 -and
    [int]$change.first_candidate_token_occurrence_count_at_declaration_parent -eq 0 -and
    @($change.allowed_integration_changes).Count -eq 4 -and
    @($change.forbidden_changes).Count -eq 10 -and
    [int]$ghost.producer_projection_count -eq 1 -and
    [int]$ghost.consumer_parser_count -eq 3 -and
    [int]$ghost.complete_contract_surface_count -eq 4 -and
    [int]$ghost.published_trace_row_count -eq 2 -and
    [bool]$ghost.actual_cas_publisher_required -and
    [bool]$ghost.actual_successor_producer_projection_required -and
    [bool]$ghost.actual_three_consumer_validators_required -and
    [int]$ghost.negative_receipt_mutation_count -eq 4 -and
    [int]$ghost.negative_consumer_decision_count -eq 12 -and
    -not [bool]$ghost.full_seeded_world_required -and
    -not [bool]$ghost.behavioral_success_prediction_allowed -and
    [int]$ghost.model_construction_count -eq 0 -and
    [int]$ghost.world_attempt_count -eq 0 -and
    [int]$ghost.world_build_count -eq 0 -and
    [int]$matrix.campaign_seed -eq 23189 -and
    @($matrix.ordered_cell_ids).Count -eq 9 -and
    [int]$matrix.declared_cell_count -eq 9 -and
    [bool]$matrix.complete_population_required -and
    -not [bool]$matrix.sampling_used -and
    [double]$provenance.equivalence_margin -eq 0.0 -and
    [double]$provenance.non_inferiority_margin -eq 0.0 -and
    [int]$provenance.physical_cohort_size -eq 9 -and
    [int]$provenance.receipt_contract_surface_population_size -eq 4 -and
    [int]$provenance.receipt_negative_decision_population_size -eq 12 -and
    [bool]$claims.declaration_complete -and
    -not [bool]$claims.implementation_complete -and
    -not [bool]$claims.compact_receipt_contract_ghost_passed -and
    -not [bool]$claims.physical_execution_authorized -and
    -not [bool]$claims.q_sdk_r23_satisfied -and
    -not [bool]$claims.turning_claimed -and
    -not [bool]$claims.physical_acceptance_authority -and
    -not [bool]$claims.release_authority
) "development, matrix, provenance, or claim boundary changed"

$declarationSha = Get-RawSha256 $declarationPath
$auditSha = Get-RawSha256 $PSCommandPath
foreach ($authorityPath in @($releasePath, $supportPath)) {
    $authority = Get-Content -LiteralPath $authorityPath -Raw | ConvertFrom-Json
    $matches = @(Get-ObjectMatches $authority {
        param($item)
        $item.PSObject.Properties["campaign_id"] -and
        [string]$item.campaign_id -ceq $campaignId
    })
    Assert-Exact ($matches.Count -eq 1) "live authority campaign population changed"
    $item = $matches[0]
    Assert-Exact (
        [string]$item.gate_id -ceq $gateId -and
        [string]$item.status -ceq $status -and
        [string]$item.preregistration_raw_sha256 -ceq $declarationSha -and
        [string]$item.declaration_audit_raw_sha256 -ceq $auditSha -and
        [string]$item.seed_fixture_compiler_raw_sha256 -ceq
            "sha256:d87068db66077db8f47cb3cfc3fc69cc9540a59fc66d8fc76e9c5f223f30a492" -and
        [int]$item.fresh_seed -eq 23189 -and
        [int]$item.declared_cell_count -eq 9 -and
        [int]$item.receipt_contract_surface_population_size -eq 4 -and
        [int]$item.receipt_negative_decision_population_size -eq 12 -and
        -not [bool]$item.implementation_complete -and
        -not [bool]$item.complete_zero_world_gate_passed -and
        -not [bool]$item.qualification_passed -and
        -not [bool]$item.physical_campaign_opened -and
        [int]$item.model_construction_count -eq 0 -and
        [int]$item.world_attempt_count -eq 0 -and
        [int]$item.world_build_count -eq 0 -and
        -not [bool]$item.q_sdk_r23_satisfied -and
        -not [bool]$item.physical_acceptance_authority -and
        -not [bool]$item.release_authorized
    ) "live authority projection changed"
}

foreach ($mutation in @(
    @{ path = "status"; value = "passing" },
    @{ path = "scientific_distinction_and_change_budget.fresh_seed"; value = 23187 },
    @{ path = "compact_receipt_contract_ghost.full_seeded_world_required"; value = $true },
    @{ path = "decision_rule.same_identity_rerun_allowed"; value = $true },
    @{ path = "claims.q_sdk_r23_satisfied"; value = $true }
)) {
    $copy = $declaration | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    $target = $copy
    $parts = [string]$mutation.path -split '\.'
    if ($parts.Count -gt 1) {
        foreach ($part in $parts[0..($parts.Count - 2)]) { $target = $target.$part }
    }
    $target.($parts[-1]) = $mutation.value
    Assert-Exact (
        ($copy | ConvertTo-Json -Depth 100 -Compress) -cne
            ($declaration | ConvertTo-Json -Depth 100 -Compress)
    ) "mutation control failed: $($mutation.path)"
}

Write-Host (
    "[turning/3e] PASS R23D70 prospective declaration: seed=23189 " +
    "receipt_surfaces=4 ghost_rows=2 negative_decisions=12 models=0 worlds=0 " +
    "physics=False QSDK-R23=False score=10/25"
)

#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$parentCommit = "69e1c46c66ef2ec65f6886db7e5cbeda36168163"
$parentTree = "fc73cee9c11744b7a5563e0e7b990873e6427287"
$campaignId = (
    "QSDK-R23D71-SUCCESS-TERMINAL-PROJECTION-REPAIRED-" +
    "THREE-ENGINE-TURNING-VALIDATION"
)
$gateId = "QSDK-R23D71"
$status = (
    "prospective_declaration_complete_compact_success_terminal_projection_" +
    "ghost_and_implementation_pending_physical_not_authorized"
)
$declarationPath = Join-Path $repoRoot (
    "sdk\turning\r23d71_success_terminal_projection_repaired_" +
    "three_engine_turning_preregistration_v1.json"
)
$materializerPath = Join-Path $repoRoot "sdk\turning\materialize_r23d71_declaration.py"
$compilerPath = Join-Path $repoRoot "sdk\turning\r23d71_seed_fixture_compiler.gd"
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d70_trace_retention_receipt_contract_repaired_" +
    "three_engine_turning_validation_closure_v1.json"
)
$closureAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d70_physical_closure.ps1"
$projectorPath = Join-Path $repoRoot "sdk\locomotion_terminal_execution_projection.ps1"
$releasePath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$godot = "C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe"

function Assert-Exact([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D71 PREREGISTRATION: $Message" }
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
    $materializerPath,
    $compilerPath,
    $closurePath,
    $closureAuditPath,
    $projectorPath,
    $releasePath,
    $supportPath,
    $godot
)) {
    Assert-Exact (Test-Path -LiteralPath $path -PathType Leaf) "missing authority: $path"
}

$declaration = Get-Content -LiteralPath $declarationPath -Raw | ConvertFrom-Json
$closure = Get-Content -LiteralPath $closurePath -Raw | ConvertFrom-Json
$materializerSha = Get-RawSha256 $materializerPath
$auditSha = Get-RawSha256 $PSCommandPath
$declarationSha = Get-RawSha256 $declarationPath
$compilerSha = Get-RawSha256 $compilerPath
$projectorSha = Get-RawSha256 $projectorPath

Assert-Exact (
    $materializerSha -ceq
        "sha256:e21c114eed14cdcb6db065ec912a445798788d825f3765dd3028027a45c402a8" -and
    $compilerSha -ceq
        "sha256:9a5becd07d86afd553fc5197c06be0e06ab76b3a8757aefed81d413d70922876" -and
    $projectorSha -ceq
        "sha256:6d167f802c8c2aa804e8444429af5b13ed7c072c4001e0bd9df921b1ab4e8bf6"
) "materializer, compiler, or unchanged shared projector bytes changed"

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
    [string]$declaration.declaration_materializer.raw_sha256 -ceq $materializerSha -and
    [string]$declaration.declaration_audit.raw_sha256 -ceq $auditSha
) "identity, work class, parent, or declaration content address changed"

Assert-Exact (
    (Get-RawSha256 $closurePath) -ceq
        "sha256:a67ae88c274360841a77bbb3a36973da78a4cf7e1c82391eee31af4156976b2e" -and
    (Get-RawSha256 $closureAuditPath) -ceq
        "sha256:0025953ab00fe1489c01d7c026759c0718e05939f0e076964d39416cc209d6d9" -and
    [string]$declaration.immutable_predecessor.gate_id -ceq "QSDK-R23D70" -and
    [string]$declaration.immutable_predecessor.status -ceq [string]$closure.status -and
    [bool]$declaration.immutable_predecessor.campaign_identity_consumed -and
    -not [bool]$declaration.immutable_predecessor.same_identity_rerun_allowed -and
    -not [bool]$declaration.immutable_predecessor.replacement_or_selective_completion_allowed -and
    [int]$declaration.immutable_predecessor.world_build_count -eq 1 -and
    [int]$declaration.immutable_predecessor.complete_retained_trace_count -eq 1 -and
    [int]$declaration.immutable_predecessor.execution_valid_cell_count -eq 0 -and
    [int]$declaration.immutable_predecessor.unopened_cell_count -eq 8 -and
    -not [bool]$declaration.immutable_predecessor.turning_result_created -and
    [int]$closure.attempt.world_build_count -eq 1 -and
    [int]$closure.observed_cell.retained_trace_row_count -eq 2992 -and
    [int]$closure.unopened_population.cell_count -eq 8 -and
    -not [bool]$closure.claims.turning_claimed
) "immutable R23D70 closure bytes or claim boundary changed"

$seedHits = @(& git -C $repoRoot grep -I -n -E '(^|[^0-9])23191([^0-9]|$)' `
    $parentCommit -- . 2>$null | ForEach-Object { [string]$_ })
Assert-Exact ($seedHits.Count -eq 0 -and $LASTEXITCODE -eq 1) (
    "seed 23191 was not unused at the declaration parent"
)
$global:LASTEXITCODE = 0

$godotOutput = @(& $godot --headless --path $repoRoot --script $compilerPath 2>&1 |
    ForEach-Object { [string]$_ })
Assert-Exact ($LASTEXITCODE -eq 0) "seed compiler execution failed"
$markers = @($godotOutput | Where-Object { $_ -clike "QSDK_R23D71_SEED_FIXTURES *" })
Assert-Exact ($markers.Count -eq 1) "seed compiler marker population changed"
$seedReceipt = $markers[0].Substring("QSDK_R23D71_SEED_FIXTURES ".Length) |
    ConvertFrom-Json
$fixture = @($seedReceipt.fixtures)[0]
Assert-Exact (
    @($seedReceipt.fixtures).Count -eq 1 -and
    [int]$fixture.campaign_seed -eq 23191 -and
    [double]$fixture.fixture_vertical_clearance_m -eq 0.0002604132751002908 -and
    [double]$fixture.fixture_yaw_rad -eq -0.0049262382090091705 -and
    [int]$fixture.gait_phase_offset_ticks -eq -1 -and
    [int]$seedReceipt.model_construction_count -eq 0 -and
    [int]$seedReceipt.world_attempt_count -eq 0 -and
    [int]$seedReceipt.world_build_count -eq 0 -and
    ($fixture | ConvertTo-Json -Depth 20 -Compress) -ceq
        ($declaration.seed_fixture_compilation.compiled_initial_perturbation |
            ConvertTo-Json -Depth 20 -Compress)
) "compiled seed fixture changed"

$producerContract = $declaration.success_terminal_projection_contract
$ghost = $declaration.compact_success_terminal_projection_ghost
$matrix = $declaration.frozen_matrix
$provenance = $declaration.threshold_and_population_provenance
$claims = $declaration.claims
$forbiddenKeys = @(
    "world_attempt_count",
    "world_build_count",
    "world_build_count_exact",
    "world_build_count_lower_bound",
    "world_build_count_upper_bound"
)
Assert-Exact (
    @($producerContract.producer_population).Count -eq 3 -and
    @($producerContract.producer_population.engine_id) -join "," -ceq
        "godot_jolt,rapier_parry,mujoco" -and
    [int]$producerContract.producer_population_size -eq 3 -and
    [bool]$producerContract.producer_population_complete -and
    [string]$producerContract.shared_projector_raw_sha256 -ceq $projectorSha -and
    -not [bool]$producerContract.shared_projector_semantic_change_allowed -and
    [bool]$producerContract.success_execution_object_required -and
    [int]$producerContract.success_execution_world_attempt_count -eq 1 -and
    [int]$producerContract.success_execution_world_build_count -eq 1 -and
    [bool]$producerContract.success_root_model_construction_count_forbidden -and
    @($producerContract.forbidden_success_root_count_keys) -join "," -ceq
        ($forbiddenKeys -join ",") -and
    [bool]$producerContract.failure_terminal_root_count_contract_inherited_unchanged -and
    [int]$ghost.native_success_producer_count -eq 3 -and
    [int]$ghost.shared_projector_count -eq 1 -and
    [int]$ghost.complete_contract_surface_count -eq 4 -and
    [int]$ghost.positive_projection_decision_count -eq 3 -and
    [int]$ghost.negative_root_count_mutation_count -eq 5 -and
    [int]$ghost.negative_projection_decision_count -eq 15 -and
    -not [bool]$ghost.full_seeded_world_required -and
    -not [bool]$ghost.behavioral_success_prediction_allowed -and
    [int]$ghost.model_construction_count -eq 0 -and
    [int]$ghost.world_attempt_count -eq 0 -and
    [int]$ghost.world_build_count -eq 0 -and
    [int]$matrix.campaign_seed -eq 23191 -and
    @($matrix.ordered_cell_ids).Count -eq 9 -and
    [int]$matrix.declared_cell_count -eq 9 -and
    [bool]$matrix.complete_population_required -and
    -not [bool]$matrix.sampling_used -and
    [double]$provenance.equivalence_margin -eq 0.0 -and
    [double]$provenance.non_inferiority_margin -eq 0.0 -and
    [int]$provenance.physical_cohort_size -eq 9 -and
    [int]$provenance.success_terminal_producer_population_size -eq 3 -and
    [int]$provenance.forbidden_root_count_key_population_size -eq 5 -and
    [int]$provenance.negative_projection_decision_population_size -eq 15 -and
    [bool]$claims.declaration_complete -and
    -not [bool]$claims.implementation_complete -and
    -not [bool]$claims.compact_success_terminal_projection_ghost_passed -and
    -not [bool]$claims.physical_execution_authorized -and
    -not [bool]$claims.q_sdk_r23_satisfied -and
    -not [bool]$claims.turning_claimed -and
    -not [bool]$claims.physical_acceptance_authority -and
    -not [bool]$claims.release_authority
) "producer population, ghost, matrix, provenance, or claim boundary changed"

foreach ($producer in @($producerContract.producer_population)) {
    $actualBlob = (
        git -C $repoRoot rev-parse (
            "$parentCommit`:$([string]$producer.observed_predecessor_path)"
        )
    ).Trim()
    Assert-Exact (
        $actualBlob -ceq [string]$producer.observed_predecessor_git_blob_oid
    ) "predecessor producer blob changed: $([string]$producer.engine_id)"
}
Assert-Exact (
    (git -C $repoRoot rev-parse "$parentCommit`:sdk/locomotion_terminal_execution_projection.ps1").Trim() -ceq
        [string]$producerContract.shared_projector_git_blob_oid
) "shared projector parent blob changed"

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
        [string]$item.declaration_materializer_raw_sha256 -ceq $materializerSha -and
        [string]$item.declaration_audit_raw_sha256 -ceq $auditSha -and
        [string]$item.seed_fixture_compiler_raw_sha256 -ceq $compilerSha -and
        [int]$item.fresh_seed -eq 23191 -and
        [int]$item.declared_cell_count -eq 9 -and
        [int]$item.success_terminal_producer_population_size -eq 3 -and
        [int]$item.forbidden_root_count_key_population_size -eq 5 -and
        [int]$item.negative_projection_decision_population_size -eq 15 -and
        -not [bool]$item.implementation_complete -and
        -not [bool]$item.compact_success_terminal_projection_ghost_passed -and
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
    @{ path = "scientific_distinction_and_change_budget.fresh_seed"; value = 23189 },
    @{ path = "compact_success_terminal_projection_ghost.full_seeded_world_required"; value = $true },
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
    "[turning/3e] PASS R23D71 prospective declaration: seed=23191 " +
    "producers=3 projector=1 positives=3 negative_decisions=15 " +
    "models=0 worlds=0 physics=False QSDK-R23=False score=10/25"
)

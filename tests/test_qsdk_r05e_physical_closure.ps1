#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$closureRelative = (
    "sdk/qsdk_r05e_exact_finite_morphology_physical_closure_v1.json"
)
$closurePath = Join-Path $repoRoot $closureRelative
$auditRelative = "sdk/audit_qsdk_r05e_exact_finite_morphology_result.ps1"
$auditPath = Join-Path $repoRoot $auditRelative
$preregistrationPath = Join-Path $repoRoot (
    "sdk/qsdk_r05e_exact_finite_morphology_preregistration.json"
)
$expectedPhysicalSource = "2c47d8b05e3f46f1c752bc544937c0b69826069e"
$expectedAuditCommit = "d4692c02f020332c34765514fafbb62247dbd2b4"
$expectedClosureCommit = "25cef1f7e72322f2297dcb16b01ac9b1af76703a"
$expectedAuditBlob = "189a8f92f3409f050dda9d4587d9335b68877592"
$expectedClosureBlob = "090979d8998711c84daef7b07d97c0afb0ff1441"
$expectedAuditSha256 = (
    "sha256:" +
    "cd8372f779ac0a5fcb175e8f822994637a1b537d092bbef2898df4779638459d"
)
$expectedClosureSha256 = (
    "sha256:" +
    "dac4ac8790cd74d89da0286c36aaf541fbfe7011d2bea66077b941363d47b33e"
)

. (Join-Path $repoRoot "sdk\qsdk_r05e_execution_authority_contract.ps1")
. (Join-Path $PSScriptRoot "closed_experiment_source_audit.ps1")

function Assert-Exact {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Get-GitText {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Message,
        [switch]$AllowEmpty
    )
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-Exact ($LASTEXITCODE -eq 0) $Message
    $text = (($lines | ForEach-Object { [string]$_ }) -join "`n").Trim()
    if (-not $AllowEmpty) {
        Assert-Exact (-not [string]::IsNullOrWhiteSpace($text)) $Message
    }
    return $text
}

function Assert-SinglePathCommit {
    param(
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$Parent,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name
    )
    $lineage = Get-GitText `
        -Arguments @("rev-list", "--parents", "-n", "1", $Commit) `
        -Message "$Name lineage is unavailable"
    Assert-Exact (
        $lineage -ceq "$Commit $Parent"
    ) "$Name is not the required direct child"
    $changed = @(
        (Get-GitText `
            -Arguments @(
                "diff-tree", "--no-commit-id", "--name-only",
                "--no-renames", "-r", $Commit
            ) `
            -Message "$Name changed-path inventory is unavailable" `
            -AllowEmpty) -split "`n" |
            ForEach-Object { $_.Trim().Replace("\", "/") } |
            Where-Object { $_ }
    )
    Assert-Exact (
        $changed.Count -eq 1 -and [string]$changed[0] -ceq $Path
    ) "$Name is not a single-path commit"
}

Assert-Exact (
    Test-Path -LiteralPath $closurePath -PathType Leaf
) "The QSDK-R05E physical closure is missing"
Assert-Exact (
    Test-Path -LiteralPath $auditPath -PathType Leaf
) "The QSDK-R05E physical evidence audit is missing"
Assert-Exact (
    (Get-SporeSporeR05ERawSha256 -Path $closurePath) -ceq
        $expectedClosureSha256 -and
    [int64](Get-Item -LiteralPath $closurePath).Length -eq 49049L
) "The QSDK-R05E physical closure bytes changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100 -DateKind String
$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100 -DateKind String

Assert-SinglePathCommit `
    -Commit $expectedAuditCommit `
    -Parent $expectedPhysicalSource `
    -Path $auditRelative `
    -Name "R05E post-result auditor"
Assert-SinglePathCommit `
    -Commit $expectedClosureCommit `
    -Parent $expectedAuditCommit `
    -Path $closureRelative `
    -Name "R05E physical closure"
foreach ($commit in @($expectedAuditCommit, $expectedClosureCommit)) {
    [void](Get-GitText `
        -Arguments @("merge-base", "--is-ancestor", $commit, "HEAD") `
        -Message "R05E closure lineage is not retained by HEAD" `
        -AllowEmpty)
    [void](Get-GitText `
        -Arguments @("merge-base", "--is-ancestor", $commit, "origin/main") `
        -Message "R05E closure lineage is not retained by origin/main" `
        -AllowEmpty)
}
Assert-Exact (
    (Get-GitText `
        -Arguments @("rev-parse", "$expectedAuditCommit`:$auditRelative") `
        -Message "R05E audit blob is unavailable") -ceq $expectedAuditBlob -and
    (Get-GitText `
        -Arguments @("rev-parse", "$expectedClosureCommit`:$closureRelative") `
        -Message "R05E closure blob is unavailable") -ceq $expectedClosureBlob
) "The committed R05E audit or closure blob changed"
Assert-Exact (
    [string]$closure.audit_implementation.raw_sha256 -ceq
        $expectedAuditSha256 -and
    [string]$closure.audit_implementation.git_blob_oid -ceq
        $expectedAuditBlob -and
    [int64]$closure.audit_implementation.byte_length -eq 53872L -and
    (
        (Get-SporeSporeR05ERawSha256 -Path $auditPath) -ceq
            $expectedAuditSha256 -or
        (Test-SporeHistoricalSourceSha256 `
            -RepositoryRoot $repoRoot `
            -Commit $expectedAuditCommit `
            -Path $auditRelative `
            -ExpectedSha256 $expectedAuditSha256)
    )
) "The R05E audit implementation binding changed"

Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r05e_exact_finite_morphology_physical_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_complete_held_out_finite_positive_eligible_for_separate_qsdk_r05_adoption" -and
    [string]$closure.gate_id -ceq "QSDK-R05E" -and
    [string]$closure.campaign_id -ceq
        "QSDK-R05E-EXACT-FINITE-MORPHOLOGY-VALIDATION" -and
    [string]$closure.campaign_role -ceq "held_out_finite_decision" -and
    [string]$closure.question_class -ceq "finite decision" -and
    [string]$closure.closed_utc -ceq "2026-09-03T21:17:16.6803437Z" -and
    [string]$closure.ledger_scope.subsystem -ceq "walking" -and
    [string]$closure.ledger_scope.engine_scope -ceq "godot_jolt" -and
    [string]$closure.ledger_scope.authority_mode -ceq
        "closed_consumed_held_out_finite_decision_evidence" -and
    [string]$closure.ledger_scope.question_class -ceq "finite decision"
) "The R05E closure identity or ledger scope changed"
Assert-Exact (
    [string]$closure.audit_implementation.source_commit -ceq
        $expectedAuditCommit -and
    [string]$closure.audit_implementation.parent_physical_source_commit -ceq
        $expectedPhysicalSource -and
    [string]$closure.audit_implementation.path -ceq $auditRelative -and
    [bool]$closure.audit_implementation.single_path_direct_child_of_physical_source -and
    [bool]$closure.audit_implementation.committed_after_physical_outcome -and
    [bool]$closure.audit_implementation.read_only_post_result_audit -and
    -not [bool]$closure.audit_implementation.outcome_policy_threshold_or_evaluator_mutation_authority
) "The post-result audit boundary changed"

$auditJson = & $auditPath -EmitJson
$audit = $auditJson |
    ConvertFrom-Json -AsHashtable -Depth 100 -DateKind String
Assert-Exact (
    [string]$audit.schema_version -ceq
        "sporespore_qsdk_r05e_exact_finite_morphology_physical_evidence_audit_projection_v1" -and
    [string]$audit.status -ceq "passed_complete_read_only_post_result_audit"
) "The live R05E evidence audit did not pass"

foreach ($section in @(
    "retained_evidence",
    "outcome",
    "authority_and_integrity",
    "observed_extrema",
    "claim_boundary",
    "audit_execution"
)) {
    Assert-Exact (
        (ConvertTo-SporeSporeR05ECanonicalJson -Value $closure[$section]) -ceq
        (ConvertTo-SporeSporeR05ECanonicalJson -Value $audit[$section])
    ) "The R05E closure $section no longer matches the evidence audit"
}
foreach ($key in $audit.physical_attempt.Keys) {
    Assert-Exact (
        (ConvertTo-SporeSporeR05ECanonicalJson `
            -Value $closure.physical_attempt[$key]) -ceq
        (ConvertTo-SporeSporeR05ECanonicalJson `
            -Value $audit.physical_attempt[$key])
    ) "The R05E closure physical-attempt field changed: $key"
}
Assert-Exact (
    [bool]$closure.physical_attempt.physics_state_modified -and
    -not [bool]$closure.physical_attempt.additional_physical_execution_authorized -and
    [int]$closure.physical_attempt.exact_source_and_gate_campaign_attempt_count -eq 1 -and
    [bool]$closure.physical_attempt.physical_identity_consumed -and
    [bool]$closure.physical_attempt.first_complete_result_is_final -and
    -not [bool]$closure.physical_attempt.same_identity_rerun_permitted -and
    [int]$closure.physical_attempt.world_attempt_count -eq 36 -and
    [int]$closure.physical_attempt.world_build_count -eq 36 -and
    [int]$closure.physical_attempt.retry_count -eq 0
) "The R05E physical consumption boundary changed"

foreach ($key in $audit.population.Keys) {
    Assert-Exact (
        (ConvertTo-SporeSporeR05ECanonicalJson `
            -Value $closure.population[$key]) -ceq
        (ConvertTo-SporeSporeR05ECanonicalJson `
            -Value $audit.population[$key])
    ) "The R05E closure population field changed: $key"
}
Assert-Exact (
    [string]$closure.population.generator_policy_id -ceq
        "qsdk_r05e_exact_finite_axis_star_v1" -and
    @($closure.population.frozen_cells).Count -eq 12 -and
    (ConvertTo-SporeSporeR05ECanonicalJson `
        -Value @($closure.population.frozen_cells)) -ceq
    (ConvertTo-SporeSporeR05ECanonicalJson `
        -Value @($preregistration.morphology_generator.cells)) -and
    [bool]$closure.population.index_selection_was_frozen_before_physics -and
    -not [bool]$closure.population.failed_cell_replacement_or_post_outcome_substitution_used
) "The exact frozen R05E population changed"

Assert-Exact (
    [string]$closure.selected_policy.candidate_id -ceq "BW5R-B" -and
    [string]$closure.selected_policy.controller_policy_id -ceq
        "sporespore_balanced_wave_bw5r_b_v1" -and
    [string]$closure.selected_policy.candidate_policy_digest -ceq
        "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f" -and
    [int]$closure.selected_policy.policy_branch_surface_count -eq 0 -and
    [bool]$closure.selected_policy.unchanged_from_preregistration -and
    -not [bool]$closure.selected_policy.controller_threshold_material_solver_or_host_change_from_r05b -and
    [string]$closure.engine_and_material.physics_engine -ceq "Jolt Physics" -and
    [int]$closure.engine_and_material.physics_hz -eq 120 -and
    [int]$closure.engine_and_material.solver_velocity_steps -eq 20 -and
    [int]$closure.engine_and_material.solver_position_steps -eq 7 -and
    [string]$closure.engine_and_material.material_profile_id -ceq
        "godot_jolt_bw5c_mu095_v1" -and
    -not [bool]$closure.engine_and_material.material_robustness_claim
) "The frozen R05E policy, engine, or material boundary changed"

Assert-Exact (
    [bool]$closure.decision.accepted -and
    [bool]$closure.decision.complete_result_valid -and
    [bool]$closure.decision.technical_sdk_execution_valid -and
    [bool]$closure.decision.all_frozen_walking_requirements_passed -and
    [bool]$closure.decision.same_selected_policy_independent_morphology_evidence -and
    [bool]$closure.decision.qsdk_r05e_finite_decision_passed -and
    [bool]$closure.decision.qsdk_r05_eligible_for_separate_adoption -and
    [bool]$closure.decision.sdk1_m05_eligible_for_separate_adoption -and
    -not [bool]$closure.decision.score_advanced_by_this_closure_alone
) "The R05E finite decision changed"
Assert-Exact (
    [bool]$closure.immutability.first_complete_result_is_final -and
    [bool]$closure.immutability.exact_source_and_gate_identity_consumed -and
    -not [bool]$closure.immutability.same_identity_rerun_permitted -and
    -not [bool]$closure.immutability.report_rewrite_permitted -and
    -not [bool]$closure.immutability.retained_artifact_replacement_deletion_or_averaging_permitted -and
    -not [bool]$closure.immutability.threshold_relaxation_permitted -and
    -not [bool]$closure.immutability.post_outcome_morphology_or_seed_replacement_permitted -and
    -not [bool]$closure.immutability.outcome_driven_policy_change_under_r05e_permitted -and
    [bool]$closure.immutability.any_new_physical_question_requires_a_distinct_prospective_identity
) "The R05E immutable-result boundary changed"

$falseClaimKeys = @(
    "all_points_inside_axis_minima_and_maxima_supported",
    "multi_axis_combinations_supported",
    "interpolation_supported",
    "extrapolation_supported",
    "arbitrary_quadruped_coverage",
    "continuous_full_volume_coverage",
    "material_or_friction_robustness",
    "rough_terrain_robustness",
    "external_push_recovery",
    "sensor_noise_or_latency_robustness",
    "running",
    "different_physics_engines",
    "completed_engine_neutral_sdk",
    "release_authorized",
    "physical_acceptance_authority"
)
Assert-Exact (
    [bool]$closure.claim_boundary.exact_twelve_descriptor_identities_under_exact_three_seeds_only -and
    [bool]$closure.claim_boundary.finite_population_only
) "The exact-finite positive claim was lost"
foreach ($claimKey in $falseClaimKeys) {
    Assert-Exact (
        -not [bool]$closure.claim_boundary[$claimKey]
    ) "R05E unlawfully gained a broader claim: $claimKey"
}
Assert-Exact (
    [int]$closure.audit_execution.model_construction_count -eq 0 -and
    [int]$closure.audit_execution.world_attempt_count -eq 0 -and
    [int]$closure.audit_execution.world_build_count -eq 0 -and
    [int]$closure.audit_execution.native_readback_count -eq 0 -and
    [int]$closure.audit_execution.solver_step_count -eq 0 -and
    -not [bool]$closure.audit_execution.physics_state_modified -and
    [string]$closure.sdk_status.sdk1_score_before_separate_adoption -ceq
        "12/20" -and
    [string]$closure.sdk_status.full_program_score_before_separate_adoption -ceq
        "12/25" -and
    -not [bool]$closure.sdk_status.sdk1_m05_advanced_by_this_closure_only -and
    -not [bool]$closure.sdk_status.release_contract_or_support_matrix_modified_by_this_closure -and
    [bool]$closure.sdk_status.separate_release_ledger_adoption_required -and
    [string]$closure.sdk_status.sdk1_score_if_qsdk_r05_adoption_audit_passes -ceq
        "13/20" -and
    [string]$closure.sdk_status.full_program_score_if_qsdk_r05_adoption_audit_passes -ceq
        "13/25" -and
    -not [bool]$closure.sdk_status.release_authorized -and
    -not [bool]$closure.sdk_status.physical_acceptance_authority -and
    [bool]$closure.next_allowed_work.r05e_is_closed -and
    [bool]$closure.next_allowed_work.additional_r05e_physical_execution_forbidden
) "The R05E zero-world closure or SDK handoff boundary changed"

Write-Host (
    "QSDK-R05E physical closure passed: 36/36 exact held-out worlds, " +
    "972/972 walking receipts, 149 retained files, finite claim only."
)

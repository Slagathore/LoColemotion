#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r05e-exact-finite-morphology-physical-" +
        "20260903T200811432Z-3228ad65"
    ),
    [switch]$EmitJson
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRepoRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore"
)
$expectedEvidenceRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "qsdk-r05e-exact-finite-morphology-physical-" +
    "20260903T200811432Z-3228ad65"
)
$evidence = [IO.Path]::GetFullPath($EvidenceRoot).TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
)
$reportPath = Join-Path $evidence "report.json"

$expectedSourceCommit = "2c47d8b05e3f46f1c752bc544937c0b69826069e"
$expectedQualificationCommit = "3228ad65f3afafe0d53572a0bc375e89ff0ea85c"
$expectedSourceFreezeCommit = "54d23a7afcca6e98f35eebf5479b1fd145b11c23"
$expectedReportSha256 = (
    "sha256:" +
    "0fb1d495d079beeda1412c8f3c0af5127dc0646429debf80cf0d20e0d3cd1ab6"
)
$expectedReportByteLength = 890301L
$expectedRetainedManifestSha256 = (
    "sha256:" +
    "39100949b3fdc0f8534bdbdd2d4dbf7b0bf74cff9c4f8d6d01b6773dbd50ffd5"
)
$expectedRetainedManifestByteLength = 26618L
$expectedRetainedFileCount = 149
$expectedRetainedTotalByteLength = 4545211L
$expectedPolicyId = "sporespore_balanced_wave_bw5r_b_v1"
$expectedPolicyDigest = (
    "sha256:" +
    "9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
)
$expectedPreregistrationSha256 = (
    "sha256:" +
    "3e51a1b2198740bf3a54198bb6cfdbdc946429fb69528378dba7d25cc2d21895"
)
$expectedAuthoritySha256 = (
    "sha256:" +
    "9ee819949d7d74d1a784485ee4783fcbe15421af396d09fcaa86ae8e38b57d69"
)
$expectedQualificationSha256 = (
    "sha256:" +
    "ca30ccbe5dc1d284bfca22602f59ef2ca650c00f5cf26f858185e1a7922b837c"
)
$expectedRuntimeIdentitySha256 = (
    "sha256:" +
    "f093fa62a28044dcb700bf47a236bf8fcef9617e8b5242df89c77aff83f7770a"
)
$expectedDesignSha256 = (
    "sha256:" +
    "3b75b7609b638470ee947326f71018d082beb4a2c2909e78dae77d3b50250a6c"
)

. (Join-Path $repoRoot "sdk\experiment_result_integrity.ps1")
. (Join-Path $repoRoot "sdk\qsdk_r05e_execution_authority_contract.ps1")

function Assert-R05EExact {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Code
    )
    if (-not $Condition) {
        throw "QSDK_R05E_PHYSICAL_AUDIT:$Code"
    }
}

function Assert-R05EPathEquals {
    param(
        [Parameter(Mandatory)][string]$Actual,
        [Parameter(Mandatory)][string]$Expected,
        [Parameter(Mandatory)][string]$Code
    )
    Assert-R05EExact `
        -Condition (
            [IO.Path]::GetFullPath($Actual) -ieq
                [IO.Path]::GetFullPath($Expected)
        ) `
        -Code $Code
}

function Assert-R05EHashedArtifact {
    param(
        [Parameter(Mandatory)][string]$ActualPath,
        [Parameter(Mandatory)][string]$ExpectedPath,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][string]$Code
    )
    Assert-R05EPathEquals `
        -Actual $ActualPath `
        -Expected $ExpectedPath `
        -Code "${Code}_path"
    Assert-R05EExact `
        -Condition (Test-Path -LiteralPath $ExpectedPath -PathType Leaf) `
        -Code "${Code}_missing"
    Assert-R05EExact `
        -Condition (
            (Get-SporeSporeR05ERawSha256 -Path $ExpectedPath) -ceq
                $ExpectedSha256
        ) `
        -Code "${Code}_sha256"
}

function Assert-R05EDoubleBitsEqual {
    param(
        [Parameter(Mandatory)][double]$Actual,
        [Parameter(Mandatory)][double]$Expected,
        [Parameter(Mandatory)][string]$Code
    )
    Assert-R05EExact `
        -Condition (
            [BitConverter]::DoubleToInt64Bits($Actual) -eq
                [BitConverter]::DoubleToInt64Bits($Expected)
        ) `
        -Code $Code
}

function Get-R05EGitText {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Code,
        [switch]$AllowEmpty
    )
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-R05EExact -Condition ($LASTEXITCODE -eq 0) -Code $Code
    $text = (($lines | ForEach-Object { [string]$_ }) -join "`n").Trim()
    if (-not $AllowEmpty) {
        Assert-R05EExact `
            -Condition (-not [string]::IsNullOrWhiteSpace($text)) `
            -Code "${Code}_empty"
    }
    return $text
}

Assert-R05EExact `
    -Condition ($repoRoot -ieq $expectedRepoRoot) `
    -Code "repository_root"
Assert-R05EExact `
    -Condition ($evidence -ieq $expectedEvidenceRoot) `
    -Code "evidence_root"
Assert-R05EExact `
    -Condition (Test-Path -LiteralPath $evidence -PathType Container) `
    -Code "evidence_root_missing"
$remote = Get-R05EGitText -Arguments @("remote", "get-url", "origin") `
    -Code "origin_remote"
Assert-R05EExact `
    -Condition ($remote -ceq "https://github.com/Slagathore/sporespore.git") `
    -Code "origin_remote_value"
foreach ($commit in @(
    $expectedSourceFreezeCommit,
    $expectedQualificationCommit,
    $expectedSourceCommit
)) {
    [void](Get-R05EGitText `
        -Arguments @("cat-file", "-e", "${commit}^{commit}") `
        -Code "commit_retained_$commit" `
        -AllowEmpty)
    [void](Get-R05EGitText `
        -Arguments @("merge-base", "--is-ancestor", $commit, "origin/main") `
        -Code "commit_on_origin_main_$commit" `
        -AllowEmpty)
}

$qualificationRelative = (
    "sdk/qsdk_r05e_exact_finite_morphology_" +
    "zero_world_qualification_closure_v1.json"
)
$authorityRelative = "sdk/qsdk_r05e_exact_finite_execution_authority.json"
$preregistrationRelative = (
    "sdk/qsdk_r05e_exact_finite_morphology_preregistration.json"
)
$qualificationPath = Join-Path $repoRoot $qualificationRelative
$authorityPath = Join-Path $repoRoot $authorityRelative
$preregistrationPath = Join-Path $repoRoot $preregistrationRelative

Assert-R05EExact `
    -Condition (
        (Get-SporeSporeR05ERawSha256 -Path $qualificationPath) -ceq
            $expectedQualificationSha256
    ) `
    -Code "qualification_sha256"
Assert-R05EExact `
    -Condition (
        (Get-SporeSporeR05ERawSha256 -Path $authorityPath) -ceq
            $expectedAuthoritySha256
    ) `
    -Code "authority_sha256"
Assert-R05EExact `
    -Condition (
        (Get-SporeSporeR05ERawSha256 -Path $preregistrationPath) -ceq
            $expectedPreregistrationSha256
    ) `
    -Code "preregistration_sha256"

$qualification = Get-Content -Raw -LiteralPath $qualificationPath |
    ConvertFrom-Json -AsHashtable -Depth 100 -DateKind String
$authority = Get-Content -Raw -LiteralPath $authorityPath |
    ConvertFrom-Json -AsHashtable -Depth 100 -DateKind String
$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100 -DateKind String
$qualifiedSourcePaths = [string[]]@(
    $qualification.source.source_bindings |
        ForEach-Object { [string]$_.path }
)
$evidenceParent = Split-Path -Parent $evidence
$authorityExpected = [ordered]@{
    authority_schema = (
        "sporespore_qsdk_r05e_exact_finite_execution_authority_v1"
    )
    authority_path = $authorityRelative
    qualification_schema = (
        "sporespore_qsdk_r05e_exact_finite_morphology_" +
        "zero_world_qualification_closure_v1"
    )
    qualification_closure_path = $qualificationRelative
    campaign_id = "QSDK-R05E-EXACT-FINITE-MORPHOLOGY-VALIDATION"
    gate_id = "QSDK-R05E"
    campaign_role = "held_out_finite_decision"
    question_class = "finite decision"
    remote = "https://github.com/Slagathore/sporespore.git"
    r05d_design_sha256 = $expectedDesignSha256
    preregistration_path = $preregistrationRelative
    preregistration_sha256 = $expectedPreregistrationSha256
    expected_morphology_count = 12
    expected_world_count = 36
    output_report_path = $reportPath
    held_out = $true
    heldout_access_permitted = $true
    development_route_ghost_required = $true
    development_route_ghost_complete = $true
    development_route_ghost_closure_path = (
        "sdk/qsdk_r05e_development_route_ghost_physical_closure_v1.json"
    )
    dependency_gdscript_direct_entry_count = 4
    dependency_gdscript_transitive_path_count = 41
    dependency_rust_build_path_count = 25
    dependency_process_and_audit_path_count = 15
    qualified_source_path_count = 80
    qualified_source_path_sha256 = (
        "sha256:" +
        "2097b6962dd41cc0554355a9418365b917f25393752b5712ea26141cf6ab5fa7"
    )
    runtime_identity_projection = $qualification.runtime
}
$authorityProjection = Assert-SporeSporeR05EExecutionAuthority `
    -RepoRoot $repoRoot `
    -Head $expectedSourceCommit `
    -AuthorityPath $authorityPath `
    -QualificationClosurePath $qualificationPath `
    -EvidenceRoot $evidenceParent `
    -QualifiedSourcePaths $qualifiedSourcePaths `
    -Expected $authorityExpected
Assert-R05EExact `
    -Condition (
        [bool]$authorityProjection.physical_execution_authorized -and
        [bool]$authorityProjection.authorization_only_commit -and
        [string]$authorityProjection.authorization_commit -ceq
            $expectedSourceCommit -and
        [string]$authorityProjection.authorization_parent_commit -ceq
            $expectedQualificationCommit -and
        [string]$authorityProjection.source_freeze_commit -ceq
            $expectedSourceFreezeCommit -and
        [int]$authorityProjection.qualified_source_file_count -eq 80 -and
        [string]$authorityProjection.runtime_identity_sha256 -ceq
            $expectedRuntimeIdentitySha256
    ) `
    -Code "authority_projection"

Assert-R05EExact `
    -Condition (
        [string]$authority.status -ceq "authorized_single_use_unconsumed" -and
        -not [bool]$authority.physical_identity_consumed -and
        -not [bool]$authority.same_identity_rerun_permitted -and
        [int]$authority.maximum_campaign_attempt_count -eq 1 -and
        [int]$authority.maximum_world_attempt_count -eq 36 -and
        [int]$authority.maximum_world_build_count -eq 36 -and
        [int]$authority.maximum_world_build_count_per_worker -eq 1 -and
        -not [bool]$authority.physical_acceptance_authority -and
        -not [bool]$authority.release_authority
    ) `
    -Code "immutable_authority_document"

Assert-R05EExact `
    -Condition (Test-Path -LiteralPath $reportPath -PathType Leaf) `
    -Code "report_missing"
Assert-R05EExact `
    -Condition (
        (Get-SporeSporeR05ERawSha256 -Path $reportPath) -ceq
            $expectedReportSha256 -and
        [int64](Get-Item -LiteralPath $reportPath).Length -eq
            $expectedReportByteLength
    ) `
    -Code "report_bytes"
$report = Get-Content -Raw -LiteralPath $reportPath |
    ConvertFrom-Json -AsHashtable -Depth 100 -DateKind String
$results = @($report.results)

Assert-R05EExact `
    -Condition (
        [string]$report.schema_version -ceq
            "sporespore_qsdk_r05e_exact_finite_morphology_report_v1" -and
        [string]$report.generated_utc -ceq
            "2026-09-03T20:50:44.9719572Z" -and
        [string]$report.campaign_id -ceq
            "QSDK-R05E-EXACT-FINITE-MORPHOLOGY-VALIDATION" -and
        [string]$report.gate_id -ceq "QSDK-R05E" -and
        [string]$report.campaign_role -ceq "held_out_finite_decision" -and
        [string]$report.selected_candidate_id -ceq "BW5R-B" -and
        [string]$report.selected_policy_id -ceq $expectedPolicyId -and
        [string]$report.selected_policy_digest -ceq $expectedPolicyDigest -and
        [string]$report.source.commit -ceq $expectedSourceCommit -and
        [string]$report.source.origin_main_commit -ceq $expectedSourceCommit -and
        [bool]$report.source.clean -and
        [bool]$report.source.matches_origin_main -and
        $results.Count -eq 36
    ) `
    -Code "report_identity"

$expectedReportSourceBindings = @(
    foreach ($binding in @($qualification.source.source_bindings)) {
        [ordered]@{
            path = [string]$binding.path
            sha256 = [string]$binding.raw_sha256
        }
    }
)
Assert-R05EExact `
    -Condition (
        (ConvertTo-SporeSporeR05ECanonicalJson `
            -Value @($report.source.source_files)) -ceq
        (ConvertTo-SporeSporeR05ECanonicalJson `
            -Value $expectedReportSourceBindings)
    ) `
    -Code "report_source_bindings"
Assert-R05EExact `
    -Condition (
        (ConvertTo-SporeSporeR05ECanonicalJson `
            -Value $report.runtime_identity_projection) -ceq
        (ConvertTo-SporeSporeR05ECanonicalJson `
            -Value $qualification.runtime)
    ) `
    -Code "runtime_identity_projection"
Assert-R05EPathEquals `
    -Actual ([string]$report.preregistration.path) `
    -Expected $preregistrationPath `
    -Code "report_preregistration_path"
Assert-R05EPathEquals `
    -Actual ([string]$report.physical_execution_authority.path) `
    -Expected $authorityPath `
    -Code "report_authority_path"
Assert-R05EExact `
    -Condition (
        [string]$report.preregistration.sha256 -ceq
            $expectedPreregistrationSha256 -and
        [string]$report.preregistration.status -ceq
            "frozen_before_first_qsdk_r05e_heldout_physics_world" -and
        [string]$report.preregistration.freeze_parent_commit -ceq
            "3aa9f4d7642ba498635a0680b85a94432bcd5048" -and
        [bool]$report.physical_execution_authority.required -and
        [string]$report.physical_execution_authority.sha256 -ceq
            $expectedAuthoritySha256 -and
        [string]$report.physical_execution_authority.authorization_commit -ceq
            $expectedSourceCommit -and
        [string]$report.physical_execution_authority.authorization_parent_commit -ceq
            $expectedQualificationCommit -and
        [string]$report.physical_execution_authority.source_freeze_commit -ceq
            $expectedSourceFreezeCommit -and
        [bool]$report.physical_execution_authority.authorization_only_commit -and
        [int]$report.physical_execution_authority.qualified_source_file_count -eq 80 -and
        [bool]$report.physical_execution_authority.worker_authorization_preflight_passed -and
        [bool]$report.physical_execution_authority.mismatched_worker_authorization_token_refused -and
        [bool]$report.physical_execution_authority.worker_authorization_type_mutation_refused -and
        [bool]$report.physical_execution_authority.direct_physical_worker_bypass_refused -and
        -not [bool]$report.physical_execution_authority.physical_acceptance_authority
    ) `
    -Code "report_preregistration_and_authority"

$metrics = Measure-SporeExperimentResults `
    -Results $results `
    -ExpectedCount 36
Assert-R05EExact `
    -Condition (
        (ConvertTo-SporeSporeR05ECanonicalJson -Value $report.metrics) -ceq
        (ConvertTo-SporeSporeR05ECanonicalJson -Value $metrics)
    ) `
    -Code "recomputed_metrics"
Assert-R05EExact `
    -Condition (
        [int]$metrics.observed_world_count -eq 36 -and
        [int]$metrics.complete_receipt_count -eq 36 -and
        [int]$metrics.harness_pass_count -eq 36 -and
        [int]$metrics.integrity_pass_count -eq 36 -and
        [int]$metrics.mechanism_pass_count -eq 36 -and
        [int]$metrics.combined_application_pass_count -eq 36 -and
        [int]$metrics.walking_conjunction_pass_count -eq 36 -and
        [int]$metrics.walking_conjunction_failure_count -eq 0 -and
        [int]$metrics.aggregate_failed_production_walking_gate_count -eq 0 -and
        [int]$metrics.aggregate_release_timeout_count -eq 0 -and
        [bool]$metrics.integrity_and_mechanism_complete
    ) `
    -Code "recomputed_metric_values"

$preflightArtifacts = @(
    [ordered]@{
        actual_path = [string]$report.full_integrity_preflight.transcript_path
        expected_path = Join-Path $evidence "full-integrity-preflight.log"
        sha256 = [string]$report.full_integrity_preflight.transcript_sha256
        expected_sha256 = (
            "sha256:" +
            "c95ab8b631a1da2aac2538b80fa35fc3b4dce33949685fa056066aa25348e82f"
        )
        code = "full_integrity_preflight"
    },
    [ordered]@{
        actual_path = [string]$report.experiment_result_integrity_preflight.artifact_path
        expected_path = Join-Path $evidence (
            "qsdk_r05e_exact_finite_morphology-result-integrity-preflight.json"
        )
        sha256 = [string]$report.experiment_result_integrity_preflight.artifact_sha256
        expected_sha256 = (
            "sha256:" +
            "0b77b1e0245c53eb94818a609581a68ce68970c83b11bcdd1b5c059fcb86b349"
        )
        code = "result_integrity_preflight"
    },
    [ordered]@{
        actual_path = [string]$report.r05e_entrypoint_preflight.transcript_path
        expected_path = Join-Path $evidence (
            "qsdk_r05e_exact_finite_morphology-entrypoint-preflight.log"
        )
        sha256 = [string]$report.r05e_entrypoint_preflight.transcript_sha256
        expected_sha256 = (
            "sha256:" +
            "c9303d059b20969d5c6d7ed04771f0bdfb43c36b5421841d4ce3909c41e66896"
        )
        code = "entrypoint_preflight"
    },
    [ordered]@{
        actual_path = [string]$report.exact_finite_morphology_source_preflight.transcript_path
        expected_path = Join-Path $evidence (
            "qsdk_r05e_exact_finite_morphology-exact-finite-source-preflight.log"
        )
        sha256 = [string]$report.exact_finite_morphology_source_preflight.transcript_sha256
        expected_sha256 = (
            "sha256:" +
            "56eea39b154114953839cd3f81bfa5bf6f44bc7393cb01dd1d216141229f2cb4"
        )
        code = "exact_finite_source_preflight"
    }
)
foreach ($artifact in $preflightArtifacts) {
    Assert-R05EExact `
        -Condition (
            [string]$artifact.sha256 -ceq
                [string]$artifact.expected_sha256
        ) `
        -Code "$([string]$artifact.code)_report_sha256"
    Assert-R05EHashedArtifact `
        -ActualPath ([string]$artifact.actual_path) `
        -ExpectedPath ([string]$artifact.expected_path) `
        -ExpectedSha256 ([string]$artifact.expected_sha256) `
        -Code ([string]$artifact.code)
}
Assert-R05EExact `
    -Condition (
        [bool]$report.full_integrity_preflight.passed -and
        [int]$report.full_integrity_preflight.actual_world_build_count -eq 0 -and
        [bool]$report.full_integrity_preflight.bw12e_exact_zero_control_mismatch_detected -and
        [bool]$report.experiment_result_integrity_preflight.passed -and
        [bool]$report.experiment_result_integrity_preflight.perfect_all_zero_36_cell_matrix_passed -and
        [bool]$report.experiment_result_integrity_preflight.perfect_all_zero_expected_cell_matrix_passed -and
        [int]$report.experiment_result_integrity_preflight.expected_synthetic_cell_count -eq 36 -and
        [bool]$report.experiment_result_integrity_preflight.nonzero_ordered_dictionary_canary_passed -and
        [int]$report.experiment_result_integrity_preflight.nonzero_canary_failed_production_walking_gate_count -eq 3 -and
        [int]$report.experiment_result_integrity_preflight.nonzero_canary_release_timeout_count -eq 2 -and
        [int]$report.experiment_result_integrity_preflight.actual_world_build_count -eq 0 -and
        [bool]$report.r05e_entrypoint_preflight.passed -and
        [int]$report.r05e_entrypoint_preflight.cell_count -eq 36 -and
        [int]$report.r05e_entrypoint_preflight.exact_candidate_full_authority_start_count -eq 36 -and
        [int]$report.r05e_entrypoint_preflight.exact_candidate_declared_policy_runtime_boundary_count -eq 36 -and
        [int]$report.r05e_entrypoint_preflight.actual_world_build_count -eq 0 -and
        [bool]$report.exact_finite_morphology_source_preflight.passed -and
        [int]$report.exact_finite_morphology_source_preflight.official_descriptor_compile_count -eq 12 -and
        [int]$report.exact_finite_morphology_source_preflight.development_ghost_descriptor_compile_count -eq 1 -and
        [int]$report.exact_finite_morphology_source_preflight.negative_control_count -eq 32 -and
        [int]$report.exact_finite_morphology_source_preflight.negative_controls_passed -eq 32 -and
        [int]$report.exact_finite_morphology_source_preflight.actual_world_build_count -eq 0 -and
        [int]$report.exact_finite_morphology_source_preflight.solver_step_count -eq 0 -and
        -not [bool]$report.exact_finite_morphology_source_preflight.locomotion_outcome_exposed -and
        -not [bool]$report.exact_finite_morphology_source_preflight.physical_acceptance_authority -and
        -not [bool]$report.candidate_mechanism_preflight.required -and
        [bool]$report.candidate_mechanism_preflight.passed -and
        -not [bool]$report.candidate_selector_preflight.required -and
        [bool]$report.candidate_selector_preflight.passed
    ) `
    -Code "zero_world_preflights"

$expectedMorphologyCells = @($preregistration.morphology_generator.cells)
$expectedSeeds = [int[]]@($preregistration.repetitions.campaign_seeds)
$expectedGateNames = [string[]]@(
    "bounded_anchor_error",
    "bounded_hinge_axis_error",
    "bounded_joint_only_lateral_stride_steering",
    "bounded_lateral_drift",
    "bounded_tilt",
    "bounded_torso_height",
    "bounded_yaw_drift",
    "contact_gated_evidence_horizon_completed",
    "contact_gating_completed_without_timeout",
    "every_contact_observer_executed",
    "every_limb_completed_evidence_gait_horizon",
    "every_limb_forward_relocation",
    "every_limb_two_contact_cycles",
    "evidence_four_contact_stance",
    "explicit_sdk_controller_session_shutdown",
    "fixture_spec_compiled_before_world_creation",
    "initial_four_contact_stance",
    "initial_perturbation_within_declared_envelope",
    "minimum_evidence_forward_translation",
    "minimum_final_forward_translation",
    "native_sdk_exclusive_post_settle_actuation",
    "no_torso_force_or_impulse_or_velocity_or_transform_command",
    "no_world_reset",
    "one_continuous_world",
    "pinned_jolt_solver_settings",
    "terminal_four_contact_recovery",
    "zero_torso_contact"
)
Assert-R05EExact `
    -Condition (
        $expectedMorphologyCells.Count -eq 12 -and
        ($expectedSeeds -join ",") -ceq "40101,40102,40103" -and
        (@($report.morphology_ids) -join "|") -ceq
            ((@($expectedMorphologyCells) | ForEach-Object {
                [string]$_.morphology_id
            }) -join "|") -and
        (@($report.generator_indices) -join ",") -ceq
            ((@($expectedMorphologyCells) | ForEach-Object {
                [string]$_.generator_index
            }) -join ",") -and
        (@($report.campaign_seeds) -join ",") -ceq
            ($expectedSeeds -join ",")
    ) `
    -Code "frozen_population"
Assert-R05EExact `
    -Condition (
        [string]$preregistration.morphology_generator.support_topology -ceq
            "exact_finite_six_axis_local_star_not_a_box_or_interpolation_domain" -and
        [bool]$preregistration.morphology_generator.index_selection_was_frozen_before_physics -and
        [bool]$preregistration.morphology_generator.post_outcome_index_replacement_forbidden -and
        [bool]$preregistration.repetitions.first_complete_result_is_final_for_this_source_identity -and
        [bool]$preregistration.repetitions.early_stop_for_outcome_forbidden -and
        [bool]$preregistration.repetitions.failed_cell_deletion_replacement_averaging_or_threshold_change_forbidden -and
        [bool]$preregistration.walking_gate.all_36_cells_must_walk -and
        [bool]$preregistration.walking_gate.every_production_walking_receipt_must_be_true -and
        -not [bool]$preregistration.walking_gate.threshold_change_from_r05b
    ) `
    -Code "prospective_decision_rule"

$globalLockJson = ConvertTo-SporeSporeR05ECanonicalJson `
    -Value $report.physical_execution_authority.operation_lock
Assert-R05EExact `
    -Condition (
        [bool]$report.physical_execution_authority.operation_lock.acquired -and
        [string]$report.physical_execution_authority.operation_lock.role -ceq
            "physical" -and
        [bool]$report.physical_execution_authority.operation_lock.created_new -and
        -not [bool]$report.physical_execution_authority.operation_lock.abandoned_owner_recovered -and
        -not [bool]$report.physical_execution_authority.operation_lock.test_only -and
        -not [bool]$report.physical_execution_authority.operation_lock.physical_acceptance_authority
    ) `
    -Code "physical_operation_lock"

$pairs = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::Ordinal
)
$tokens = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::Ordinal
)
$sdkStepCount = 0L
$validatedCommandCount = 0L
$nativeMotorWriteCount = 0L
$directBodyWriteCount = 0L
$legacyPostSettleWriteCount = 0L
$legacyEvidenceWriteCount = 0L
$sdkMismatchCount = 0L
$sdkSafeDisableCount = 0L
$sdkSafeNoActuationCount = 0L
$summedDurationSeconds = 0.0
$walkingGateReceiptCount = 0
$falseWalkingGateReceiptCount = 0
$verifiedCellArtifactCount = 0
$verifiedAttemptCount = 0
$minimumEvidenceForward = [double]::PositiveInfinity
$minimumFinalForward = [double]::PositiveInfinity
$maximumAbsoluteLateral = 0.0
$maximumTilt = 0.0
$minimumTorsoHeight = [double]::PositiveInfinity
$maximumAnchorError = 0.0
$maximumHingeAxisError = 0.0
$resultOrdinal = 0

foreach ($cell in $expectedMorphologyCells) {
    foreach ($seed in $expectedSeeds) {
        $result = $results[$resultOrdinal]
        $resultOrdinal += 1
        $pair = "$([string]$cell.morphology_id)|$seed"
        Assert-R05EExact -Condition ($pairs.Add($pair)) `
            -Code "duplicate_pair_$pair"
        Assert-R05EExact `
            -Condition (
                [string]$result.morphology_id -ceq
                    [string]$cell.morphology_id -and
                [int]$result.generator_index -eq
                    [int]$cell.generator_index -and
                [int]$result.campaign_seed -eq $seed -and
                [int]$result.process_exit_code -eq 0 -and
                -not [bool]$result.timed_out -and
                -not [bool]$result.killed_process_tree -and
                [bool]$result.receipt_parsed -and
                [string]$result.receipt_parse_error -ceq "" -and
                [bool]$result.harness_passed -and
                [bool]$result.walking_observed -and
                [bool]$result.common_execution_integrity -and
                [bool]$result.mechanism_gate_passed -and
                [bool]$result.combined_application_gate_passed -and
                [int]$result.failed_production_walking_gate_count -eq 0 -and
                [int]$result.release_timeout_count -eq 0
            ) `
            -Code "result_$pair"

        $receipt = $result.receipt
        Assert-R05EExact `
            -Condition (
                [string]$receipt.schema_version -ceq
                    "sporespore_qsdk_r05e_exact_finite_cell_v1" -and
                [string]$receipt.campaign_id -ceq
                    "QSDK-R05E-EXACT-FINITE-MORPHOLOGY-VALIDATION" -and
                [string]$receipt.gate_id -ceq "QSDK-R05E" -and
                [string]$receipt.campaign_role -ceq
                    "held_out_finite_decision" -and
                [string]$receipt.morphology_id -ceq
                    [string]$cell.morphology_id -and
                [int]$receipt.generator_index -eq
                    [int]$cell.generator_index -and
                [int]$receipt.campaign_seed -eq $seed -and
                [string]$receipt.selected_candidate_id -ceq "BW5R-B" -and
                [string]$receipt.controller_policy_id -ceq
                    $expectedPolicyId -and
                [string]$receipt.selected_policy_digest -ceq
                    $expectedPolicyDigest -and
                [string]$receipt.generator_receipt_sha256 -ceq
                    [string]$cell.generator_receipt_sha256 -and
                [string]$receipt.proportion_spec_sha256 -ceq
                    [string]$cell.proportion_spec_sha256 -and
                [string]$receipt.material_profile_id -ceq
                    "godot_jolt_bw5c_mu095_v1" -and
                [bool]$receipt.harness_passed -and
                [bool]$receipt.walking_observed -and
                [bool]$receipt.common_execution_integrity -and
                [bool]$receipt.sdk_authority_enabled -and
                [string]$receipt.sdk_authority_failure_code -ceq "" -and
                [string]$receipt.sdk_authority_scope -ceq "post_settle_full" -and
                [int]$receipt.assertions_passed -eq 9 -and
                [int]$receipt.assertions_failed -eq 0 -and
                [int]$receipt.world_build_count -eq 1
            ) `
            -Code "receipt_identity_$pair"
        Assert-R05EExact `
            -Condition (
                [bool]$receipt.sdk_authority_start_result.ok -and
                [bool]$receipt.sdk_authority_start_result.actuation_authority -and
                [string]$receipt.sdk_authority_start_result.failure_code -ceq "" -and
                [string]$receipt.sdk_authority_start_result.authority_scope -ceq
                    "post_settle_full" -and
                [string]$receipt.sdk_authority_start_result.controller_policy_id -ceq
                    $expectedPolicyId -and
                [int]$receipt.sdk_authority_start_result.world_build_count -eq 0 -and
                -not [bool]$receipt.sdk_authority_start_result.physical_acceptance_authority -and
                [string]$receipt.sdk_authority_start_result.adapter_capability_sha256 -ceq
                    [string]$receipt.adapter_capability_sha256 -and
                [string]$receipt.sdk_authority_start_result.controller_profile_sha256 -ceq
                    [string]$receipt.controller_profile_sha256 -and
                [string]$receipt.sdk_authority_start_result.adapter_manifest.physics_engine -ceq
                    "Jolt Physics" -and
                [int]$receipt.sdk_authority_start_result.adapter_manifest.physics_hz -eq 120 -and
                [int]$receipt.sdk_authority_start_result.adapter_manifest.solver_velocity_steps -eq 20 -and
                [int]$receipt.sdk_authority_start_result.adapter_manifest.solver_position_steps -eq 7 -and
                [string]$receipt.sdk_authority_start_result.adapter_manifest.controller_policy_id -ceq
                    $expectedPolicyId
            ) `
            -Code "sdk_authority_$pair"
        Assert-R05EExact `
            -Condition (
                [long]$receipt.sdk_step_count -gt 0 -and
                [long]$receipt.validated_balanced_wave_command_count -eq
                    ([long]$receipt.sdk_step_count * 8L) -and
                [long]$receipt.native_motor_write_count -eq
                    [long]$receipt.validated_balanced_wave_command_count -and
                [long]$receipt.direct_body_write_count -eq 0 -and
                [long]$receipt.legacy_post_settle_motor_write_count -eq 0 -and
                [long]$receipt.legacy_evidence_motor_write_count -eq 0 -and
                [long]$receipt.sdk_mismatch_count -eq 0 -and
                [long]$receipt.sdk_safe_disable_count -eq 0 -and
                [long]$receipt.sdk_safe_no_actuation_count -eq 0
            ) `
            -Code "command_arithmetic_$pair"

        $actualGateNames = [string[]]@(
            $receipt.walking_gate_receipts.Keys |
                ForEach-Object { [string]$_ } |
                Sort-Object
        )
        Assert-R05EExact `
            -Condition (
                ($actualGateNames -join "|") -ceq
                    ($expectedGateNames -join "|")
            ) `
            -Code "walking_gate_set_$pair"
        foreach ($gateName in $expectedGateNames) {
            $walkingGateReceiptCount += 1
            Assert-R05EExact `
                -Condition (
                    $receipt.walking_gate_receipts[$gateName] -is [bool]
                ) `
                -Code "walking_gate_type_${pair}_$gateName"
            if (-not [bool]$receipt.walking_gate_receipts[$gateName]) {
                $falseWalkingGateReceiptCount += 1
            }
        }
        Assert-R05EExact `
            -Condition ($falseWalkingGateReceiptCount -eq 0) `
            -Code "walking_gate_false_$pair"

        Assert-R05EExact `
            -Condition (
                [bool]$receipt.finite_population_only -and
                -not [bool]$receipt.arbitrary_quadruped_coverage -and
                -not [bool]$receipt.continuous_full_volume_coverage -and
                -not [bool]$receipt.material_robustness -and
                -not [bool]$receipt.cross_engine_c6 -and
                -not [bool]$receipt.completed_engine_neutral_sdk -and
                -not [bool]$receipt.physical_acceptance_authority
            ) `
            -Code "cell_claim_boundary_$pair"

        $cellRoot = Join-Path $evidence ("{0}-s{1}" -f @(
            [string]$cell.morphology_id,
            $seed
        ))
        $attemptPath = Join-Path $cellRoot "attempt.json"
        $transcriptPath = Join-Path $cellRoot "transcript.log"
        $stderrPath = Join-Path $cellRoot "stderr.log"
        $engineLogPath = Join-Path $cellRoot "engine.log"
        Assert-R05EHashedArtifact `
            -ActualPath ([string]$result.transcript_path) `
            -ExpectedPath $transcriptPath `
            -ExpectedSha256 ([string]$result.transcript_sha256) `
            -Code "transcript_$pair"
        Assert-R05EHashedArtifact `
            -ActualPath ([string]$result.stderr_path) `
            -ExpectedPath $stderrPath `
            -ExpectedSha256 ([string]$result.stderr_sha256) `
            -Code "stderr_$pair"
        Assert-R05EHashedArtifact `
            -ActualPath ([string]$result.engine_log_path) `
            -ExpectedPath $engineLogPath `
            -ExpectedSha256 ([string]$result.engine_log_sha256) `
            -Code "engine_log_$pair"
        $verifiedCellArtifactCount += 3

        $receiptPrefix = "QSDK_R05E_EXACT_FINITE_CELL "
        $receiptLines = @(
            [IO.File]::ReadAllLines($transcriptPath) |
                Where-Object {
                    $_.StartsWith($receiptPrefix, [StringComparison]::Ordinal)
                }
        )
        Assert-R05EExact `
            -Condition ($receiptLines.Count -eq 1) `
            -Code "transcript_receipt_count_$pair"
        $transcriptReceipt = $receiptLines[0].Substring($receiptPrefix.Length) |
            ConvertFrom-Json -AsHashtable -Depth 100 -DateKind String
        Assert-R05EExact `
            -Condition (
                (ConvertTo-SporeSporeR05ECanonicalJson `
                    -Value $transcriptReceipt) -ceq
                (ConvertTo-SporeSporeR05ECanonicalJson `
                    -Value $receipt)
            ) `
            -Code "transcript_receipt_binding_$pair"

        Assert-R05EPathEquals `
            -Actual ([string]$receipt.physical_authorization.attempt_path) `
            -Expected $attemptPath `
            -Code "attempt_path_$pair"
        Assert-R05EExact `
            -Condition (Test-Path -LiteralPath $attemptPath -PathType Leaf) `
            -Code "attempt_missing_$pair"
        $attempt = Get-Content -Raw -LiteralPath $attemptPath |
            ConvertFrom-Json -AsHashtable -Depth 100 -DateKind String
        Assert-SporeSporeR05EExactKeys -Value $attempt -ExpectedKeys @(
            "schema_version", "authorization_token", "campaign_id", "gate_id",
            "campaign_role", "generator_index", "morphology_id", "campaign_seed",
            "source_commit", "r05d_design_sha256", "preregistration_sha256",
            "execution_authority_path", "execution_authority_sha256",
            "synthetic_authorization_preflight", "supervisor_physical_authorized",
            "maximum_world_attempt_count", "maximum_world_build_count",
            "world_attempt_count_before_worker", "world_build_count_before_worker",
            "same_identity_rerun_permitted", "operation_lock",
            "physical_acceptance_authority"
        ) -Code "physical_audit_attempt_key_set"
        Assert-R05EExact `
            -Condition (
                [string]$attempt.schema_version -ceq
                    "sporespore_qsdk_r05e_morphology_attempt_v1" -and
                [string]$attempt.authorization_token -cmatch '^[0-9a-f]{32}$' -and
                $tokens.Add([string]$attempt.authorization_token) -and
                [string]$attempt.campaign_id -ceq
                    "QSDK-R05E-EXACT-FINITE-MORPHOLOGY-VALIDATION" -and
                [string]$attempt.gate_id -ceq "QSDK-R05E" -and
                [string]$attempt.campaign_role -ceq "held_out_finite_decision" -and
                [int]$attempt.generator_index -eq [int]$cell.generator_index -and
                [string]$attempt.morphology_id -ceq [string]$cell.morphology_id -and
                [int]$attempt.campaign_seed -eq $seed -and
                [string]$attempt.source_commit -ceq $expectedSourceCommit -and
                [string]$attempt.r05d_design_sha256 -ceq $expectedDesignSha256 -and
                [string]$attempt.preregistration_sha256 -ceq
                    $expectedPreregistrationSha256 -and
                [string]$attempt.execution_authority_sha256 -ceq
                    $expectedAuthoritySha256 -and
                -not [bool]$attempt.synthetic_authorization_preflight -and
                [bool]$attempt.supervisor_physical_authorized -and
                [int]$attempt.maximum_world_attempt_count -eq 1 -and
                [int]$attempt.maximum_world_build_count -eq 1 -and
                [int]$attempt.world_attempt_count_before_worker -eq 0 -and
                [int]$attempt.world_build_count_before_worker -eq 0 -and
                -not [bool]$attempt.same_identity_rerun_permitted -and
                -not [bool]$attempt.physical_acceptance_authority -and
                (ConvertTo-SporeSporeR05ECanonicalJson `
                    -Value $attempt.operation_lock) -ceq $globalLockJson
            ) `
            -Code "attempt_content_$pair"
        Assert-R05EPathEquals `
            -Actual ([string]$attempt.execution_authority_path) `
            -Expected $authorityPath `
            -Code "attempt_authority_path_$pair"
        Assert-R05EExact `
            -Condition (
                [bool]$receipt.physical_authorization.required -and
                [bool]$receipt.physical_authorization.ok -and
                -not [bool]$receipt.physical_authorization.authorization_preflight -and
                [string]$receipt.physical_authorization.failure_code -ceq "" -and
                [string]$receipt.physical_authorization.source_commit -ceq
                    $expectedSourceCommit -and
                [string]$receipt.physical_authorization.campaign_role -ceq
                    "held_out_finite_decision" -and
                [int]$receipt.physical_authorization.generator_index -eq
                    [int]$cell.generator_index -and
                [string]$receipt.physical_authorization.morphology_id -ceq
                    [string]$cell.morphology_id -and
                [int]$receipt.physical_authorization.campaign_seed -eq $seed -and
                [int]$receipt.physical_authorization.world_build_count -eq 0 -and
                -not [bool]$receipt.physical_authorization.physical_acceptance_authority
            ) `
            -Code "physical_authorization_receipt_$pair"
        $verifiedAttemptCount += 1

        $sdkStepCount += [long]$receipt.sdk_step_count
        $validatedCommandCount += [long]$receipt.validated_balanced_wave_command_count
        $nativeMotorWriteCount += [long]$receipt.native_motor_write_count
        $directBodyWriteCount += [long]$receipt.direct_body_write_count
        $legacyPostSettleWriteCount += [long]$receipt.legacy_post_settle_motor_write_count
        $legacyEvidenceWriteCount += [long]$receipt.legacy_evidence_motor_write_count
        $sdkMismatchCount += [long]$receipt.sdk_mismatch_count
        $sdkSafeDisableCount += [long]$receipt.sdk_safe_disable_count
        $sdkSafeNoActuationCount += [long]$receipt.sdk_safe_no_actuation_count
        $summedDurationSeconds += [double]$result.duration_seconds
        $minimumEvidenceForward = [Math]::Min(
            $minimumEvidenceForward,
            [double]$receipt.evidence_task_frame_forward_displacement_m
        )
        $minimumFinalForward = [Math]::Min(
            $minimumFinalForward,
            [double]$receipt.final_task_frame_forward_displacement_m
        )
        $maximumAbsoluteLateral = [Math]::Max(
            $maximumAbsoluteLateral,
            [Math]::Abs(
                [double]$receipt.final_task_frame_lateral_displacement_m
            )
        )
        $maximumTilt = [Math]::Max(
            $maximumTilt,
            [double]$receipt.maximum_tilt_rad
        )
        $minimumTorsoHeight = [Math]::Min(
            $minimumTorsoHeight,
            [double]$receipt.minimum_torso_height_m
        )
        $maximumAnchorError = [Math]::Max(
            $maximumAnchorError,
            [double]$receipt.maximum_anchor_error_m
        )
        $maximumHingeAxisError = [Math]::Max(
            $maximumHingeAxisError,
            [double]$receipt.maximum_hinge_axis_error_rad
        )
    }
}

Assert-R05EExact `
    -Condition (
        $pairs.Count -eq 36 -and
        $tokens.Count -eq 36 -and
        $verifiedAttemptCount -eq 36 -and
        $verifiedCellArtifactCount -eq 108 -and
        $walkingGateReceiptCount -eq 972 -and
        $falseWalkingGateReceiptCount -eq 0 -and
        $sdkStepCount -eq 97862L -and
        $validatedCommandCount -eq 782896L -and
        $nativeMotorWriteCount -eq 782896L -and
        $directBodyWriteCount -eq 0L -and
        $legacyPostSettleWriteCount -eq 0L -and
        $legacyEvidenceWriteCount -eq 0L -and
        $sdkMismatchCount -eq 0L -and
        $sdkSafeDisableCount -eq 0L -and
        $sdkSafeNoActuationCount -eq 0L
    ) `
    -Code "population_totals"
Assert-R05EDoubleBitsEqual -Actual $summedDurationSeconds `
    -Expected 2120.8909891 -Code "summed_duration"
Assert-R05EDoubleBitsEqual -Actual $minimumEvidenceForward `
    -Expected 0.6315072774887085 -Code "minimum_evidence_forward"
Assert-R05EDoubleBitsEqual -Actual $minimumFinalForward `
    -Expected 0.7512508034706116 -Code "minimum_final_forward"
Assert-R05EDoubleBitsEqual -Actual $maximumAbsoluteLateral `
    -Expected 0.08032993227243423 -Code "maximum_absolute_lateral"
Assert-R05EDoubleBitsEqual -Actual $maximumTilt `
    -Expected 0.1628541571195807 -Code "maximum_tilt"
Assert-R05EDoubleBitsEqual -Actual $minimumTorsoHeight `
    -Expected 0.4259062111377716 -Code "minimum_torso_height"
Assert-R05EDoubleBitsEqual -Actual $maximumAnchorError `
    -Expected 0.022097904235124588 -Code "maximum_anchor_error"
Assert-R05EDoubleBitsEqual -Actual $maximumHingeAxisError `
    -Expected 0.11492926608480802 -Code "maximum_hinge_axis_error"

$falseReportClaimKeys = @(
    "arbitrary_quadruped_coverage",
    "continuous_full_volume_coverage",
    "material_robustness",
    "rough_terrain_robustness",
    "external_push_recovery",
    "sensor_noise_or_latency_robustness",
    "running",
    "cross_engine_c6",
    "completed_engine_neutral_sdk",
    "release_authorized",
    "physical_acceptance_authority"
)
Assert-R05EExact `
    -Condition (
        [bool]$report.same_selected_policy_independent_morphology_evidence -and
        -not [bool]$report.development_data_only -and
        [bool]$report.finite_population_only -and
        [bool]$report.r05e_passed -and
        [int]$report.expected_world_count -eq 36 -and
        [int]$report.observed_world_count -eq 36 -and
        [int]$report.complete_receipt_count -eq 36 -and
        [int]$report.harness_pass_count -eq 36 -and
        [int]$report.walking_pass_count -eq 36 -and
        [int]$report.integrity_pass_count -eq 36 -and
        [int]$report.failure_count -eq 0
    ) `
    -Code "finite_decision"
foreach ($claimKey in $falseReportClaimKeys) {
    Assert-R05EExact `
        -Condition (-not [bool]$report[$claimKey]) `
        -Code "false_claim_$claimKey"
}

$artifacts = @(
    Get-SporeSporeR05ERetainedFileArtifacts -Root $evidence
)
$retainedManifest = [ordered]@{
    schema_version = "sporespore_retained_file_tree_manifest_v1"
    artifacts = $artifacts
}
$retainedManifestJson = ConvertTo-SporeSporeR05ECanonicalJson `
    -Value $retainedManifest
$retainedManifestByteLength = [Text.UTF8Encoding]::new($false).GetByteCount(
    $retainedManifestJson
)
$retainedManifestSha256 = Get-SporeSporeR05ETextSha256 `
    -Text $retainedManifestJson
$retainedTotalByteLength = 0L
foreach ($artifact in $artifacts) {
    $retainedTotalByteLength += [int64]$artifact.byte_length
}
Assert-R05EExact `
    -Condition (
        $artifacts.Count -eq $expectedRetainedFileCount -and
        $retainedTotalByteLength -eq $expectedRetainedTotalByteLength -and
        $retainedManifestByteLength -eq $expectedRetainedManifestByteLength -and
        $retainedManifestSha256 -ceq $expectedRetainedManifestSha256 -and
        @($artifacts | Where-Object {
            [string]$_.path -like "*/attempt.json"
        }).Count -eq 36 -and
        @($artifacts | Where-Object {
            [string]$_.path -like "*/transcript.log"
        }).Count -eq 36 -and
        @($artifacts | Where-Object {
            [string]$_.path -like "*/stderr.log"
        }).Count -eq 36 -and
        @($artifacts | Where-Object {
            [string]$_.path -like "*/engine.log"
        }).Count -eq 36
    ) `
    -Code "retained_tree_manifest"

# These two controls exercise the post-result auditor itself without opening a
# model or touching retained evidence. One alters the aggregate input and the
# other alters the canonical file-tree input; both must leave the official
# reconstruction rather than accidentally compare equal.
$metricCanaryResults = @(
    $results |
        ConvertTo-Json -Compress -Depth 100 |
        ConvertFrom-Json -AsHashtable -Depth 100 -DateKind String
)
$metricCanaryResults[0].failed_production_walking_gate_count = 1
$metricCanary = Measure-SporeExperimentResults `
    -Results $metricCanaryResults `
    -ExpectedCount 36
Assert-R05EExact `
    -Condition (
        [int]$metricCanary.aggregate_failed_production_walking_gate_count -eq 1 -and
        (ConvertTo-SporeSporeR05ECanonicalJson -Value $metricCanary) -cne
            (ConvertTo-SporeSporeR05ECanonicalJson -Value $metrics)
    ) `
    -Code "metric_mutation_control"
$manifestCanaryArtifacts = @(
    $artifacts |
        ConvertTo-Json -Compress -Depth 10 |
        ConvertFrom-Json -AsHashtable -Depth 10 -DateKind String
)
$manifestCanaryArtifacts[0].byte_length = (
    [int64]$manifestCanaryArtifacts[0].byte_length + 1L
)
$manifestCanaryJson = ConvertTo-SporeSporeR05ECanonicalJson -Value ([ordered]@{
    schema_version = "sporespore_retained_file_tree_manifest_v1"
    artifacts = $manifestCanaryArtifacts
})
Assert-R05EExact `
    -Condition (
        (Get-SporeSporeR05ETextSha256 -Text $manifestCanaryJson) -cne
            $expectedRetainedManifestSha256
    ) `
    -Code "retained_manifest_mutation_control"

$projection = [ordered]@{
    schema_version = (
        "sporespore_qsdk_r05e_exact_finite_morphology_" +
        "physical_evidence_audit_projection_v1"
    )
    status = "passed_complete_read_only_post_result_audit"
    gate_id = "QSDK-R05E"
    campaign_id = "QSDK-R05E-EXACT-FINITE-MORPHOLOGY-VALIDATION"
    source_and_authority = [ordered]@{
        source_freeze_commit = $expectedSourceFreezeCommit
        qualification_commit = $expectedQualificationCommit
        authorization_commit = $expectedSourceCommit
        qualification_closure_path = $qualificationRelative
        qualification_closure_raw_sha256 = $expectedQualificationSha256
        execution_authority_path = $authorityRelative
        execution_authority_raw_sha256 = $expectedAuthoritySha256
        immutable_authority_document_status = "authorized_single_use_unconsumed"
        authority_document_rewritten_after_consumption = $false
        preregistration_path = $preregistrationRelative
        preregistration_raw_sha256 = $expectedPreregistrationSha256
        runtime_identity_sha256 = $expectedRuntimeIdentitySha256
        qualified_source_file_count = 80
    }
    physical_attempt = [ordered]@{
        exact_source_and_gate_campaign_attempt_count = 1
        physical_identity_consumed = $true
        first_complete_result_is_final = $true
        same_identity_rerun_permitted = $false
        evidence_root = $evidence.Replace("\", "/")
        report_path = $reportPath.Replace("\", "/")
        report_raw_sha256 = $expectedReportSha256
        report_byte_length = $expectedReportByteLength
        report_generated_utc = [string]$report.generated_utc
        expected_world_count = 36
        observed_world_count = 36
        complete_receipt_count = 36
        world_attempt_count = 36
        world_build_count = 36
        retry_count = 0
        timeout_count = 0
        killed_process_tree_count = 0
        receipt_parse_failure_count = 0
        process_exit_zero_count = 36
        operation_lock_acquired = $true
        operation_lock_abandoned_owner_recovered = $false
    }
    retained_evidence = [ordered]@{
        tree_schema_version = "sporespore_retained_file_tree_manifest_v1"
        file_count = $artifacts.Count
        total_byte_length = $retainedTotalByteLength
        manifest_canonical_byte_length = $retainedManifestByteLength
        manifest_canonical_sha256 = $retainedManifestSha256
        artifacts = $artifacts
    }
    population = [ordered]@{
        support_topology = (
            "exact_finite_six_axis_local_star_not_a_box_or_interpolation_domain"
        )
        morphology_count = 12
        generator_indices = @($report.generator_indices)
        morphology_ids = @($report.morphology_ids)
        campaign_seeds = @($report.campaign_seeds)
        cartesian_world_count = 36
        unique_morphology_seed_pair_count = $pairs.Count
        unique_authorization_token_count = $tokens.Count
    }
    outcome = [ordered]@{
        classification = "valid_complete_held_out_finite_positive"
        harness_pass_count = 36
        walking_pass_count = 36
        integrity_pass_count = 36
        mechanism_pass_count = 36
        combined_application_pass_count = 36
        walking_gate_receipt_count = $walkingGateReceiptCount
        false_walking_gate_receipt_count = $falseWalkingGateReceiptCount
        failure_count = 0
        r05e_passed = $true
        same_selected_policy_independent_morphology_evidence = $true
    }
    authority_and_integrity = [ordered]@{
        verified_source_file_count = 80
        verified_preflight_artifact_count = 4
        verified_attempt_receipt_count = $verifiedAttemptCount
        verified_cell_artifact_count = $verifiedCellArtifactCount
        sdk_step_count = $sdkStepCount
        validated_balanced_wave_command_count = $validatedCommandCount
        native_motor_write_count = $nativeMotorWriteCount
        native_motor_write_count_per_sdk_step = 8
        direct_body_write_count = $directBodyWriteCount
        legacy_post_settle_motor_write_count = $legacyPostSettleWriteCount
        legacy_evidence_motor_write_count = $legacyEvidenceWriteCount
        sdk_mismatch_count = $sdkMismatchCount
        sdk_safe_disable_count = $sdkSafeDisableCount
        sdk_safe_no_actuation_count = $sdkSafeNoActuationCount
        summed_cell_duration_seconds = $summedDurationSeconds
    }
    observed_extrema = [ordered]@{
        minimum_evidence_task_frame_forward_displacement_m = $minimumEvidenceForward
        minimum_final_task_frame_forward_displacement_m = $minimumFinalForward
        maximum_absolute_final_task_frame_lateral_displacement_m = (
            $maximumAbsoluteLateral
        )
        maximum_tilt_rad = $maximumTilt
        minimum_torso_height_m = $minimumTorsoHeight
        maximum_anchor_error_m = $maximumAnchorError
        maximum_hinge_axis_error_rad = $maximumHingeAxisError
    }
    claim_boundary = [ordered]@{
        exact_twelve_descriptor_identities_under_exact_three_seeds_only = $true
        finite_population_only = $true
        all_points_inside_axis_minima_and_maxima_supported = $false
        multi_axis_combinations_supported = $false
        interpolation_supported = $false
        extrapolation_supported = $false
        arbitrary_quadruped_coverage = $false
        continuous_full_volume_coverage = $false
        material_or_friction_robustness = $false
        rough_terrain_robustness = $false
        external_push_recovery = $false
        sensor_noise_or_latency_robustness = $false
        running = $false
        different_physics_engines = $false
        completed_engine_neutral_sdk = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
    audit_execution = [ordered]@{
        post_result_audit = $true
        outcome_or_threshold_mutation_authority = $false
        metric_mutation_control_count = 1
        retained_manifest_mutation_control_count = 1
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        native_readback_count = 0
        solver_step_count = 0
        physics_state_modified = $false
    }
}

if ($EmitJson) {
    $projection | ConvertTo-Json -Depth 100
} else {
    Write-Host (
        "QSDK-R05E physical evidence audit passed: 36/36 exact held-out " +
        "finite worlds, 972/972 walking receipts, 149 retained files, " +
        "no rerun and no broad-coverage or release claim."
    )
}

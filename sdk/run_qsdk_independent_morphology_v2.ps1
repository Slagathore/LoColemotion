#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Output = "",
    [switch]$PreflightOnly,
    [ValidateSet(
        "QSDK-R05",
        "QSDK-R05B",
        "QSDK-R05C",
        "QSDK-R05E-DEVELOPMENT-ROUTE-GHOST",
        "QSDK-R05E-EXACT-FINITE-MORPHOLOGY-VALIDATION",
        "BW14V-MORPHOLOGY-DEVELOPMENT",
        "BW15F-MORPHOLOGY-DEVELOPMENT"
    )]
    [string]$CampaignId = "QSDK-R05",
    [string]$Candidate = "",
    [string]$ExecutionAuthority = "",
    [ValidateRange(30, 600)]
    [int]$CellTimeoutSeconds = 240
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$godotPath = [System.IO.Path]::GetFullPath($Godot)
$fullGateTest = "tests/test_sdk_full_integrity_gate_satisfiability.gd"
$experimentResultIntegrityPath = Join-Path $sdkRoot (
    "experiment_result_integrity.ps1"
)
$campaignConfig = if (
    $CampaignId -ceq "BW14V-MORPHOLOGY-DEVELOPMENT"
) {
    if ($Candidate -cnotin @("BW14V-A", "BW14V-B")) {
        throw "BW14V requires -Candidate BW14V-A or BW14V-B"
    }
    $bw14vTreatment = $Candidate -ceq "BW14V-B"
    [ordered]@{
        id = "BW14V-MORPHOLOGY-DEVELOPMENT"
        gate_id = "BW14V"
        slug = "bw14v_morphology_development_$($Candidate.ToLowerInvariant())"
        preregistration_file = (
            "balanced_wave_bw14v_morphology_development_preregistration.json"
        )
        preregistration_schema = (
            "sporespore_balanced_wave_bw14v_morphology_development_preregistration_v1"
        )
        preregistration_status = "frozen_before_first_bw14v_physics_world"
        preregistration_sha256 = (
            "5030239a59fa477f0dab6cf749572edf7c9040569fff93d42d40c18da3dedd33"
        )
        test = "tests/test_sdk_balanced_wave_bw14v_morphology_development.gd"
        indices_csv = "181,182,183,184,185,186,187,188,189,190,191,192"
        seeds_csv = "21601,21602,21603"
        entrypoint_prefix = "BW14V_DEVELOPMENT_ENTRYPOINT_PREFLIGHT "
        entrypoint_schema = (
            "sporespore_bw14v_development_entrypoint_preflight_v1"
        )
        cell_prefix = "BW14V_DEVELOPMENT_CELL "
        runner_preflight_schema = (
            "sporespore_bw14v_runner_preflight_v1"
        )
        preflight_bundle_prefix = "BW14V_PREFLIGHT_BUNDLE "
        preflight_bundle_schema = "sporespore_bw14v_preflight_bundle_v1"
        report_schema = (
            "sporespore_bw14v_morphology_development_report_v1"
        )
        pass_field = "development_complete"
        entrypoint_report_field = "bw14v_entrypoint_preflight"
        wrapper_source = (
            "sdk/run_balanced_wave_bw14v_morphology_development.ps1"
        )
        candidate_id = $Candidate
        policy_id = $(if ($bw14vTreatment) {
            "sporespore_balanced_wave_bw14v_b_v1"
        } else {
            "sporespore_balanced_wave_bw5r_b_v1"
        })
        policy_digest = $(if ($bw14vTreatment) {
            "sha256:3404217d991b8eaf6b9c0d74e84768ffd36264b6d664a7c02fc14f57b176713b"
        } else {
            "sha256:288012fe4af5e93f1ecd2f007821a03e95c316c27cda196317617b8130017292"
        })
        candidate_environment_variable = "SPORESPORE_BW14V_CANDIDATE"
        walking_required = $false
        campaign_role = (
            "paired_outcome_exposed_base_controller_hypothesis_selection"
        )
        include_selected_policy_source = $false
        selected_policy_source = ""
        additional_source_files = @()
        paired_candidate_contract = $true
        mechanism_authority_test = (
            "tests/test_sdk_balanced_wave_bw14v_authority_contract.gd"
        )
        mechanism_authority_summary = (
            "SDK BW14V authority summary: 11 passed, 0 failed"
        )
        selector_regression_test = "tests/test_bw14v_selector.ps1"
        paired_source_files = @(
            "tests/test_sdk_balanced_wave_bw14v_authority_contract.gd",
            "sdk/compile_balanced_wave_bw14v_selection.ps1",
            "tests/test_bw14v_selector.ps1",
            "tests/test_bw13p_r3_closure.ps1",
            "sdk/balanced_wave_bw13p_r3_closure_manifest.json"
        )
    }
} elseif ($CampaignId -ceq "BW15F-MORPHOLOGY-DEVELOPMENT") {
    $bw15fPolicyIds = [ordered]@{
        "BW15F-A" = "sporespore_balanced_wave_bw5r_b_v1"
        "BW15F-B" = "sporespore_balanced_wave_bw15f_b_v1"
        "BW15F-C" = "sporespore_balanced_wave_bw15f_c_v1"
        "BW15F-D" = "sporespore_balanced_wave_bw15f_d_v1"
    }
    $bw15fPolicyDigests = [ordered]@{
        "BW15F-A" = (
            "sha256:ac9fe7e62493ed2d21d3c95f0eb51cde45d7a53e7e22365ce422c68ad031a423"
        )
        "BW15F-B" = (
            "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd"
        )
        "BW15F-C" = (
            "sha256:7ba445b2756a8fc43e245334f3215fc77dd5c68142dd0be33a3dfeaf2c75433f"
        )
        "BW15F-D" = (
            "sha256:f26320a4019a86f1ec700f297af12156a61ea41a026d489b69d1b649fafdcf60"
        )
    }
    if (-not $bw15fPolicyIds.Contains($Candidate)) {
        throw "BW15F requires -Candidate BW15F-A, BW15F-B, BW15F-C, or BW15F-D"
    }
    [ordered]@{
        id = "BW15F-MORPHOLOGY-DEVELOPMENT"
        gate_id = "BW15F"
        slug = "bw15f_morphology_development_$($Candidate.ToLowerInvariant())"
        preregistration_file = (
            "balanced_wave_bw15f_morphology_development_preregistration.json"
        )
        preregistration_schema = (
            "sporespore_balanced_wave_bw15f_morphology_development_preregistration_v1"
        )
        preregistration_status = "frozen_before_first_bw15f_physics_world"
        preregistration_sha256 = (
            "722a65c741d3bd41c5374225c5d7b0d611ce87cf5ac5ede1d3eda9142c362e29"
        )
        test = "tests/test_sdk_balanced_wave_bw15f_morphology_development.gd"
        indices_csv = "181,182,183,184,185,186,187,188,189,190,191,192"
        seeds_csv = "21601,21602,21603"
        entrypoint_prefix = "BW15F_DEVELOPMENT_ENTRYPOINT_PREFLIGHT "
        entrypoint_schema = (
            "sporespore_bw15f_development_entrypoint_preflight_v1"
        )
        cell_prefix = "BW15F_DEVELOPMENT_CELL "
        runner_preflight_schema = "sporespore_bw15f_runner_preflight_v1"
        preflight_bundle_prefix = "BW15F_PREFLIGHT_BUNDLE "
        preflight_bundle_schema = "sporespore_bw15f_preflight_bundle_v1"
        report_schema = (
            "sporespore_bw15f_morphology_development_report_v1"
        )
        pass_field = "development_complete"
        entrypoint_report_field = "bw15f_entrypoint_preflight"
        wrapper_source = (
            "sdk/run_balanced_wave_bw15f_morphology_development.ps1"
        )
        candidate_id = $Candidate
        policy_id = [string]$bw15fPolicyIds[$Candidate]
        policy_digest = [string]$bw15fPolicyDigests[$Candidate]
        candidate_environment_variable = "SPORESPORE_BW15F_CANDIDATE"
        walking_required = $false
        campaign_role = (
            "paired_outcome_exposed_global_sign_gain_hypothesis_selection"
        )
        include_selected_policy_source = $false
        selected_policy_source = ""
        additional_source_files = @()
        paired_candidate_contract = $true
        mechanism_authority_test = (
            "tests/test_sdk_balanced_wave_bw15f_authority_contract.gd"
        )
        mechanism_authority_summary = (
            "SDK BW15F authority summary: 8 passed, 0 failed"
        )
        selector_regression_test = "tests/test_bw15f_selector.ps1"
        paired_source_files = @(
            "tests/test_sdk_balanced_wave_bw15f_authority_contract.gd",
            "sdk/compile_balanced_wave_bw15f_selection.ps1",
            "tests/test_bw15f_selector.ps1",
            "tests/test_bw14v_closure.ps1",
            "sdk/balanced_wave_bw14v_closure_manifest.json",
            "tests/test_bw14v_posthoc_diagnostic.ps1",
            "sdk/balanced_wave_bw14v_posthoc_diagnostic.json"
        )
    }
} elseif ($CampaignId -ceq "QSDK-R05B") {
    [ordered]@{
        id = "QSDK-R05B"
        gate_id = "QSDK-R05B"
        slug = "qsdk_r05b"
        preregistration_file = (
            "qsdk_r05b_independent_morphology_preregistration.json"
        )
        preregistration_schema = (
            "sporespore_qsdk_r05b_independent_morphology_preregistration_v1"
        )
        preregistration_status = (
            "frozen_before_first_qsdk_r05b_physics_world"
        )
        test = "tests/test_sdk_qsdk_r05b_independent_morphology.gd"
        indices_csv = "181,182,183,184,185,186,187,188,189,190,191,192"
        seeds_csv = "21601,21602,21603"
        entrypoint_prefix = "QSDK_R05B_ENTRYPOINT_PREFLIGHT "
        entrypoint_schema = (
            "sporespore_qsdk_r05b_entrypoint_preflight_receipt_v1"
        )
        cell_prefix = "QSDK_R05B_CELL "
        runner_preflight_schema = (
            "sporespore_qsdk_r05b_runner_preflight_v1"
        )
        preflight_bundle_prefix = "QSDK_R05B_PREFLIGHT_BUNDLE "
        preflight_bundle_schema = (
            "sporespore_qsdk_r05b_preflight_bundle_v1"
        )
        report_schema = (
            "sporespore_qsdk_r05b_independent_morphology_report_v1"
        )
        pass_field = "r05b_passed"
        entrypoint_report_field = "r05b_entrypoint_preflight"
        wrapper_source = "sdk/run_qsdk_r05b_independent_morphology.ps1"
        candidate_id = "BW5R-B"
        policy_id = "sporespore_balanced_wave_bw5r_b_v1"
        policy_digest = (
            "sha256:" +
            "9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
        )
        candidate_environment_variable = ""
        walking_required = $true
        campaign_role = "independent_validation"
        include_selected_policy_source = $true
        selected_policy_source = "sdk/balanced_wave_selected_policy.json"
        additional_source_files = @()
        paired_candidate_contract = $false
    }
} elseif ($CampaignId -ceq "QSDK-R05C") {
    [ordered]@{
        id = "QSDK-R05C"
        gate_id = "QSDK-R05C"
        slug = "qsdk_r05c"
        preregistration_file = (
            "qsdk_r05c_independent_morphology_preregistration.json"
        )
        preregistration_schema = (
            "sporespore_qsdk_r05c_independent_morphology_preregistration_v1"
        )
        preregistration_status = (
            "frozen_before_first_qsdk_r05c_physics_world"
        )
        preregistration_sha256 = (
            "1fa59563ac88de693028be0cf541a9a94b22fe15dad0a70d86ace95abd0789d6"
        )
        test = "tests/test_sdk_qsdk_r05c_independent_morphology.gd"
        indices_csv = "193,194,195,196,197,198,199,200,201,202,203,204"
        seeds_csv = "38101,38102,38103"
        entrypoint_prefix = "QSDK_R05C_ENTRYPOINT_PREFLIGHT "
        entrypoint_schema = (
            "sporespore_qsdk_r05c_entrypoint_preflight_receipt_v1"
        )
        cell_prefix = "QSDK_R05C_CELL "
        runner_preflight_schema = (
            "sporespore_qsdk_r05c_runner_preflight_v1"
        )
        preflight_bundle_prefix = "QSDK_R05C_PREFLIGHT_BUNDLE "
        preflight_bundle_schema = (
            "sporespore_qsdk_r05c_preflight_bundle_v1"
        )
        report_schema = (
            "sporespore_qsdk_r05c_independent_morphology_report_v1"
        )
        pass_field = "r05c_passed"
        entrypoint_report_field = "r05c_entrypoint_preflight"
        wrapper_source = "sdk/run_qsdk_r05c_independent_morphology.ps1"
        candidate_id = "BW15F-B"
        policy_id = "sporespore_balanced_wave_bw15f_b_v1"
        policy_digest = (
            "sha256:" +
            "7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd"
        )
        candidate_environment_variable = ""
        walking_required = $true
        campaign_role = "independent_validation"
        include_selected_policy_source = $true
        selected_policy_source = (
            "sdk/balanced_wave_bw15f_selected_policy.json"
        )
        additional_source_files = @(
            "sdk/balanced_wave_bw15f_morphology_development_preregistration.json",
            "sdk/balanced_wave_bw15f_closure_manifest.json",
            "tests/test_bw15f_closure.ps1",
            "sdk/Cargo.toml",
            "sdk/Cargo.lock",
            "sdk/core/Cargo.toml",
            "sdk/core/src/controller.rs",
            "sdk/core/src/lib.rs",
            "sdk/core/src/protocol.rs",
            "sdk/core/src/runtime.rs",
            "sdk/adapters/godot/Cargo.toml",
            "sdk/adapters/godot/src/lib.rs",
            "docs/research/LOCOMOTION_RESEARCH_SOURCES.md",
            "DReCon.pdf",
            "2604.08780v1.pdf",
            "2507.22653v2.pdf"
        )
        paired_candidate_contract = $false
    }
} elseif ($CampaignId -ceq "QSDK-R05E-DEVELOPMENT-ROUTE-GHOST") {
    if (-not [string]::IsNullOrWhiteSpace($Candidate)) {
        throw "-Candidate is not valid for the R05E development route ghost"
    }
    [ordered]@{
        id = "QSDK-R05E-DEVELOPMENT-ROUTE-GHOST"
        gate_id = "QSDK-R05E-GHOST"
        slug = "qsdk_r05e_development_route_ghost"
        preregistration_file = (
            "qsdk_r05e_development_route_ghost_preregistration.json"
        )
        preregistration_schema = (
            "sporespore_qsdk_r05e_development_route_ghost_preregistration_v1"
        )
        preregistration_status = (
            "frozen_before_first_qsdk_r05e_development_ghost_world"
        )
        preregistration_sha256 = (
            "ce1ef34851f81455115dd7031546f867f466c8ce264e375faba6c2d4436cf7f9"
        )
        test = "tests/test_sdk_qsdk_r05e_development_route_ghost.gd"
        indices_csv = "229"
        seeds_csv = "40001"
        expected_morphology_count = 1
        expected_world_count = 1
        entrypoint_prefix = "QSDK_R05E_DEVELOPMENT_GHOST_ENTRYPOINT_PREFLIGHT "
        entrypoint_schema = (
            "sporespore_qsdk_r05e_development_ghost_entrypoint_preflight_v1"
        )
        authorization_preflight_prefix = (
            "QSDK_R05E_DEVELOPMENT_GHOST_AUTHORIZATION_PREFLIGHT "
        )
        authorization_preflight_schema = (
            "sporespore_qsdk_r05e_development_ghost_authorization_preflight_v1"
        )
        source_gate_test = (
            "tests/test_sdk_qsdk_r05e_exact_finite_morphology_source.gd"
        )
        source_gate_prefix = (
            "QSDK_R05E_EXACT_FINITE_MORPHOLOGY_SOURCE_ZERO_WORLD "
        )
        source_gate_schema = (
            "sporespore_qsdk_r05e_exact_finite_morphology_source_zero_world_v1"
        )
        cell_prefix = "QSDK_R05E_DEVELOPMENT_GHOST_CELL "
        runner_preflight_schema = (
            "sporespore_qsdk_r05e_development_ghost_runner_preflight_v1"
        )
        preflight_bundle_prefix = "QSDK_R05E_DEVELOPMENT_GHOST_PREFLIGHT_BUNDLE "
        preflight_bundle_schema = (
            "sporespore_qsdk_r05e_development_ghost_preflight_bundle_v1"
        )
        report_schema = "sporespore_qsdk_r05e_development_route_ghost_report_v1"
        pass_field = "route_complete"
        entrypoint_report_field = "development_ghost_entrypoint_preflight"
        wrapper_source = "sdk/run_qsdk_r05e_development_route_ghost.ps1"
        candidate_id = "BW5R-B"
        policy_id = "sporespore_balanced_wave_bw5r_b_v1"
        policy_digest = (
            "sha256:" +
            "9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
        )
        candidate_environment_variable = ""
        walking_required = $false
        campaign_role = "development_route_ghost"
        include_selected_policy_source = $true
        selected_policy_source = "sdk/balanced_wave_selected_policy.json"
        additional_source_files = @(
            "sdk/qsdk_r05d_exact_finite_morphology_successor_design_v1.json",
            "sdk/conformance/qsdk_r05d_exact_finite_morphology_successor_design.py",
            "sdk/conformance/qsdk_r05e_zero_world_implementation.py",
            "sdk/locomotion_operation_lock.ps1",
            "sdk/qsdk_r05e_execution_authority_contract.ps1",
            "scripts/lab/gait/qsdk_r05e_exact_finite_morphology_spec.gd",
            "tests/test_sdk_qsdk_r05e_morphology_route.gd",
            "tests/test_sdk_qsdk_r05e_exact_finite_morphology_source.gd",
            "tests/test_qsdk_r05e_execution_authority_contract.ps1"
        )
        dependency_manifest_relative_path = "sdk/qsdk_r05e_dependency_manifest_v1.json"
        dependency_manifest_schema = "sporespore_qsdk_r05e_dependency_manifest_v1"
        dependency_manifest_status = (
            "prospective_complete_transitive_source_closure_zero_world"
        )
        dependency_manifest_policy_id = (
            "qsdk_r05e_declared_roots_recursive_gdscript_and_rust_build_closure_v1"
        )
        dependency_gdscript_direct_entry_count = 4
        dependency_gdscript_transitive_path_count = 41
        dependency_rust_build_path_count = 25
        dependency_process_and_audit_path_count = 15
        qualified_source_file_count = 80
        qualified_source_path_sha256 = (
            "sha256:2097b6962dd41cc0554355a9418365b917f25393752b5712ea26141cf6ab5fa7"
        )
        complete_transitive_dependency_required = $true
        paired_candidate_contract = $false
        same_selected_policy_evidence_on_pass = $false
        development_data_only = $true
        physical_authorization_required = $true
        execution_authority_schema = (
            "sporespore_qsdk_r05e_development_ghost_execution_authority_v1"
        )
        execution_authority_relative_path = (
            "sdk/qsdk_r05e_development_route_ghost_execution_authority.json"
        )
        qualification_closure_relative_path = (
            "sdk/qsdk_r05e_development_route_ghost_zero_world_qualification_closure_v1.json"
        )
        qualification_closure_schema = (
            "sporespore_qsdk_r05e_development_route_ghost_zero_world_qualification_closure_v1"
        )
        authority_question_class = "development"
        held_out = $false
        heldout_access_permitted = $false
        development_route_ghost_required = $false
        development_route_ghost_complete = $false
        development_route_ghost_closure_path = ""
    }
} elseif (
    $CampaignId -ceq "QSDK-R05E-EXACT-FINITE-MORPHOLOGY-VALIDATION"
) {
    if (-not [string]::IsNullOrWhiteSpace($Candidate)) {
        throw "-Candidate is not valid for the R05E held-out decision"
    }
    [ordered]@{
        id = "QSDK-R05E-EXACT-FINITE-MORPHOLOGY-VALIDATION"
        gate_id = "QSDK-R05E"
        slug = "qsdk_r05e_exact_finite_morphology"
        preregistration_file = (
            "qsdk_r05e_exact_finite_morphology_preregistration.json"
        )
        preregistration_schema = (
            "sporespore_qsdk_r05e_exact_finite_morphology_preregistration_v1"
        )
        preregistration_status = (
            "frozen_before_first_qsdk_r05e_heldout_physics_world"
        )
        preregistration_sha256 = (
            "3e51a1b2198740bf3a54198bb6cfdbdc946429fb69528378dba7d25cc2d21895"
        )
        test = "tests/test_sdk_qsdk_r05e_exact_finite_morphology.gd"
        indices_csv = "217,218,219,220,221,222,223,224,225,226,227,228"
        seeds_csv = "40101,40102,40103"
        expected_morphology_count = 12
        expected_world_count = 36
        entrypoint_prefix = "QSDK_R05E_EXACT_FINITE_ENTRYPOINT_PREFLIGHT "
        entrypoint_schema = (
            "sporespore_qsdk_r05e_exact_finite_entrypoint_preflight_v1"
        )
        authorization_preflight_prefix = (
            "QSDK_R05E_EXACT_FINITE_AUTHORIZATION_PREFLIGHT "
        )
        authorization_preflight_schema = (
            "sporespore_qsdk_r05e_exact_finite_authorization_preflight_v1"
        )
        source_gate_test = (
            "tests/test_sdk_qsdk_r05e_exact_finite_morphology_source.gd"
        )
        source_gate_prefix = (
            "QSDK_R05E_EXACT_FINITE_MORPHOLOGY_SOURCE_ZERO_WORLD "
        )
        source_gate_schema = (
            "sporespore_qsdk_r05e_exact_finite_morphology_source_zero_world_v1"
        )
        cell_prefix = "QSDK_R05E_EXACT_FINITE_CELL "
        runner_preflight_schema = (
            "sporespore_qsdk_r05e_exact_finite_runner_preflight_v1"
        )
        preflight_bundle_prefix = "QSDK_R05E_EXACT_FINITE_PREFLIGHT_BUNDLE "
        preflight_bundle_schema = (
            "sporespore_qsdk_r05e_exact_finite_preflight_bundle_v1"
        )
        report_schema = "sporespore_qsdk_r05e_exact_finite_morphology_report_v1"
        pass_field = "r05e_passed"
        entrypoint_report_field = "r05e_entrypoint_preflight"
        wrapper_source = "sdk/run_qsdk_r05e_exact_finite_morphology.ps1"
        candidate_id = "BW5R-B"
        policy_id = "sporespore_balanced_wave_bw5r_b_v1"
        policy_digest = (
            "sha256:" +
            "9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
        )
        candidate_environment_variable = ""
        walking_required = $true
        campaign_role = "held_out_finite_decision"
        include_selected_policy_source = $true
        selected_policy_source = "sdk/balanced_wave_selected_policy.json"
        additional_source_files = @(
            "sdk/qsdk_r05d_exact_finite_morphology_successor_design_v1.json",
            "sdk/conformance/qsdk_r05d_exact_finite_morphology_successor_design.py",
            "sdk/conformance/qsdk_r05e_zero_world_implementation.py",
            "sdk/qsdk_r05e_development_route_ghost_preregistration.json",
            "sdk/locomotion_operation_lock.ps1",
            "sdk/qsdk_r05e_execution_authority_contract.ps1",
            "scripts/lab/gait/qsdk_r05e_exact_finite_morphology_spec.gd",
            "tests/test_sdk_qsdk_r05e_morphology_route.gd",
            "tests/test_sdk_qsdk_r05e_development_route_ghost.gd",
            "tests/test_sdk_qsdk_r05e_exact_finite_morphology_source.gd",
            "tests/test_qsdk_r05e_execution_authority_contract.ps1"
        )
        dependency_manifest_relative_path = "sdk/qsdk_r05e_dependency_manifest_v1.json"
        dependency_manifest_schema = "sporespore_qsdk_r05e_dependency_manifest_v1"
        dependency_manifest_status = (
            "prospective_complete_transitive_source_closure_zero_world"
        )
        dependency_manifest_policy_id = (
            "qsdk_r05e_declared_roots_recursive_gdscript_and_rust_build_closure_v1"
        )
        dependency_gdscript_direct_entry_count = 4
        dependency_gdscript_transitive_path_count = 41
        dependency_rust_build_path_count = 25
        dependency_process_and_audit_path_count = 15
        qualified_source_file_count = 80
        qualified_source_path_sha256 = (
            "sha256:2097b6962dd41cc0554355a9418365b917f25393752b5712ea26141cf6ab5fa7"
        )
        complete_transitive_dependency_required = $true
        paired_candidate_contract = $false
        same_selected_policy_evidence_on_pass = $true
        development_data_only = $false
        physical_authorization_required = $true
        execution_authority_schema = (
            "sporespore_qsdk_r05e_exact_finite_execution_authority_v1"
        )
        execution_authority_relative_path = (
            "sdk/qsdk_r05e_exact_finite_execution_authority.json"
        )
        qualification_closure_relative_path = (
            "sdk/qsdk_r05e_exact_finite_morphology_zero_world_qualification_closure_v1.json"
        )
        qualification_closure_schema = (
            "sporespore_qsdk_r05e_exact_finite_morphology_zero_world_qualification_closure_v1"
        )
        authority_question_class = "finite decision"
        held_out = $true
        heldout_access_permitted = $true
        development_route_ghost_required = $true
        development_route_ghost_complete = $true
        development_route_ghost_closure_path = (
            "sdk/qsdk_r05e_development_route_ghost_physical_closure_v1.json"
        )
    }
} else {
    if (-not [string]::IsNullOrWhiteSpace($Candidate)) {
        throw "-Candidate is only valid for BW14V or BW15F"
    }
    [ordered]@{
        id = "QSDK-R05"
        gate_id = "QSDK-R05"
        slug = "qsdk_r05"
        preregistration_file = (
            "qsdk_r05_independent_morphology_preregistration.json"
        )
        preregistration_schema = (
            "sporespore_qsdk_r05_independent_morphology_preregistration_v1"
        )
        preregistration_status = (
            "frozen_before_first_qsdk_r05_physics_world"
        )
        test = "tests/test_sdk_qsdk_r05_independent_morphology.gd"
        indices_csv = "169,170,171,172,173,174,175,176,177,178,179,180"
        seeds_csv = "21501,21502,21503"
        entrypoint_prefix = "QSDK_R05_ENTRYPOINT_PREFLIGHT "
        entrypoint_schema = (
            "sporespore_qsdk_r05_entrypoint_preflight_receipt_v1"
        )
        cell_prefix = "QSDK_R05_CELL "
        runner_preflight_schema = (
            "sporespore_qsdk_r05_runner_preflight_v1"
        )
        preflight_bundle_prefix = "QSDK_R05_PREFLIGHT_BUNDLE "
        preflight_bundle_schema = (
            "sporespore_qsdk_r05_preflight_bundle_v1"
        )
        report_schema = (
            "sporespore_qsdk_r05_independent_morphology_report_v1"
        )
        pass_field = "r05_passed"
        entrypoint_report_field = "r05_entrypoint_preflight"
        wrapper_source = ""
        candidate_id = "BW5R-B"
        policy_id = "sporespore_balanced_wave_bw5r_b_v1"
        policy_digest = (
            "sha256:" +
            "9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
        )
        candidate_environment_variable = ""
        walking_required = $true
        campaign_role = "independent_validation"
        include_selected_policy_source = $true
        selected_policy_source = "sdk/balanced_wave_selected_policy.json"
        additional_source_files = @()
        paired_candidate_contract = $false
    }
}
$expectedPolicyId = [string]$campaignConfig.policy_id
$expectedPolicyDigest = [string]$campaignConfig.policy_digest
$expectedMorphologyCount = if ($campaignConfig.Contains("expected_morphology_count")) {
    [int]$campaignConfig.expected_morphology_count
} else {
    12
}
$expectedWorldCount = if ($campaignConfig.Contains("expected_world_count")) {
    [int]$campaignConfig.expected_world_count
} else {
    36
}
$sameSelectedPolicyEvidenceOnPass = if (
    $campaignConfig.Contains("same_selected_policy_evidence_on_pass")
) {
    [bool]$campaignConfig.same_selected_policy_evidence_on_pass
} else {
    -not [bool]$campaignConfig.paired_candidate_contract
}
$developmentDataOnly = if ($campaignConfig.Contains("development_data_only")) {
    [bool]$campaignConfig.development_data_only
} else {
    [bool]$campaignConfig.paired_candidate_contract
}
$physicalAuthorizationRequired = (
    $campaignConfig.Contains("physical_authorization_required") -and
    [bool]$campaignConfig.physical_authorization_required
)
$preregistrationPath = Join-Path $sdkRoot (
    [string]$campaignConfig.preregistration_file
)
$campaignTest = [string]$campaignConfig.test

if (
    -not (
        Test-Path -LiteralPath $experimentResultIntegrityPath -PathType Leaf
    )
) {
    throw "The fail-closed experiment result aggregator is missing"
}
. $experimentResultIntegrityPath
$operationLockReceipt = $null
$operationLockPublic = $null
$qualificationInterlock = $null
$qualificationInterlockAcquired = $false
$qualificationInterlockName = (
    "Global\SporeSpore.QSDK.R05E.ZeroWorldQualification.Serial.v1"
)
if ($physicalAuthorizationRequired) {
    $locomotionOperationLockPath = Join-Path (
        $sdkRoot
    ) "locomotion_operation_lock.ps1"
    if (-not (Test-Path -LiteralPath $locomotionOperationLockPath -PathType Leaf)) {
        throw "The shared locomotion operation lock is missing"
    }
    . $locomotionOperationLockPath
    $executionAuthorityContractPath = Join-Path (
        $sdkRoot
    ) "qsdk_r05e_execution_authority_contract.ps1"
    if (-not (Test-Path -LiteralPath $executionAuthorityContractPath -PathType Leaf)) {
        throw "The R05E execution-authority contract is missing"
    }
    . $executionAuthorityContractPath
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )
    [System.IO.File]::WriteAllText(
        $Path,
        $Text,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Get-PrefixedSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:$(Get-Sha256 -Path $Path)"
}

function Get-R05ETextSha256 {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Text)
    $digest = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return "sha256:$([Convert]::ToHexString($digest).ToLowerInvariant())"
}

function ConvertTo-R05ECanonicalValue {
    param([Parameter(Mandatory)]$Value)
    if ($Value -is [System.Collections.IDictionary]) {
        $keys = [string[]]@($Value.Keys | ForEach-Object { [string]$_ })
        [Array]::Sort($keys, [StringComparer]::Ordinal)
        $ordered = [ordered]@{}
        foreach ($key in $keys) {
            $ordered[$key] = ConvertTo-R05ECanonicalValue -Value $Value[$key]
        }
        return $ordered
    }
    if (
        $Value -is [System.Collections.IList] -and
        $Value -isnot [string]
    ) {
        $items = @(
            foreach ($item in @($Value)) {
                ConvertTo-R05ECanonicalValue -Value $item
            }
        )
        return ,$items
    }
    return $Value
}

function ConvertTo-R05ECanonicalJson {
    param([Parameter(Mandatory)]$Value)
    $canonical = ConvertTo-R05ECanonicalValue -Value $Value
    return $canonical | ConvertTo-Json -Compress -Depth 50
}

function Invoke-R05EVersionCommand {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Label
    )
    $lines = @(& $Path @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $text = (($lines | ForEach-Object { [string]$_ }) -join "`n").Trim()
    if ($exitCode -ne 0 -or [string]::IsNullOrWhiteSpace($text)) {
        throw "$CampaignId could not identify the $Label runtime"
    }
    return $text
}

function Get-R05EApplicationPath {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Label
    )
    $commands = @(Get-Command -Name $Name -CommandType Application -ErrorAction Stop)
    if ($commands.Count -lt 1) {
        throw "$CampaignId could not resolve the $Label executable"
    }
    $path = [IO.Path]::GetFullPath([string]$commands[0].Source)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "$CampaignId resolved a missing $Label executable"
    }
    return [string](Get-Item -LiteralPath $path).FullName
}

function ConvertTo-R05ERuntimeIdentityPath {
    param([Parameter(Mandatory)][string]$Path)
    $normalized = [IO.Path]::GetFullPath($Path).Replace("\", "/")
    if ([System.OperatingSystem]::IsWindows()) {
        # Windows executable lookup is case-insensitive. Canonicalizing only the
        # identity projection prevents equivalent spellings such as pwsh.EXE
        # and pwsh.exe from producing different physical-authority identities.
        return $normalized.ToLowerInvariant()
    }
    return $normalized
}

function Get-R05EFileIdentity {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Version
    )
    $item = Get-Item -LiteralPath $Path
    $fullPath = ConvertTo-R05ERuntimeIdentityPath -Path $item.FullName
    return [ordered]@{
        path = $fullPath
        raw_sha256 = Get-PrefixedSha256 -Path $item.FullName
        byte_length = [int64]$item.Length
        version = $Version
    }
}

function Get-R05ERustToolIdentity {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$CommandPath,
        [Parameter(Mandatory)][string]$RustupPath,
        [Parameter(Mandatory)][string[]]$VersionArguments,
        [Parameter(Mandatory)][string]$Label
    )
    $commandItem = Get-Item -LiteralPath $CommandPath
    $resolvedLauncherPath = if (
        -not [string]::IsNullOrWhiteSpace([string]$commandItem.ResolvedTarget)
    ) {
        [string](Get-Item -LiteralPath ([string]$commandItem.ResolvedTarget)).FullName
    } else {
        [string]$commandItem.FullName
    }
    $effectivePathText = Invoke-R05EVersionCommand `
        -Path $RustupPath `
        -Arguments @("which", $Name) `
        -Label "Rustup $Label resolver"
    if ($effectivePathText.Contains("`n", [StringComparison]::Ordinal)) {
        throw "$CampaignId Rustup returned multiple $Label executable paths"
    }
    $effectivePath = [IO.Path]::GetFullPath($effectivePathText)
    if (-not (Test-Path -LiteralPath $effectivePath -PathType Leaf)) {
        throw "$CampaignId Rustup resolved a missing $Label executable"
    }
    $effectiveItem = Get-Item -LiteralPath $effectivePath
    return [ordered]@{
        command_path = ConvertTo-R05ERuntimeIdentityPath -Path $commandItem.FullName
        command_resolved_launcher_path = ConvertTo-R05ERuntimeIdentityPath `
            -Path $resolvedLauncherPath
        effective_path = ConvertTo-R05ERuntimeIdentityPath -Path $effectiveItem.FullName
        effective_raw_sha256 = Get-PrefixedSha256 -Path $effectiveItem.FullName
        effective_byte_length = [int64]$effectiveItem.Length
        version = Invoke-R05EVersionCommand `
            -Path $CommandPath -Arguments $VersionArguments -Label $Label
    }
}

function Get-R05ERuntimeIdentityProjection {
    $cargoPath = Get-R05EApplicationPath -Name "cargo" -Label "Cargo"
    $rustcPath = Get-R05EApplicationPath -Name "rustc" -Label "Rust compiler"
    $rustupPath = Get-R05EApplicationPath -Name "rustup" -Label "Rustup"
    $gitPath = Get-R05EApplicationPath -Name "git" -Label "Git"
    $powershellPath = [string](
        Get-Item -LiteralPath ([Environment]::ProcessPath)
    ).FullName
    if (-not (Test-Path -LiteralPath $powershellPath -PathType Leaf)) {
        throw "$CampaignId current PowerShell executable is missing"
    }
    $adapterRelativePath = "sdk/target/debug/sporespore_godot_adapter.dll"
    $adapterPath = Join-Path $repoRoot $adapterRelativePath
    if (-not (Test-Path -LiteralPath $adapterPath -PathType Leaf)) {
        throw "$CampaignId active Godot adapter runtime is missing"
    }

    $identity = [ordered]@{
        schema_version = "sporespore_qsdk_r05e_runtime_identity_v1"
        godot = Get-R05EFileIdentity `
            -Path $godotPath `
            -Version (Invoke-R05EVersionCommand `
                -Path $godotPath -Arguments @("--version") -Label "Godot")
        active_adapter = [ordered]@{
            relative_path = $adapterRelativePath
            raw_sha256 = Get-PrefixedSha256 -Path $adapterPath
            byte_length = [int64](Get-Item -LiteralPath $adapterPath).Length
        }
        rustup = Get-R05EFileIdentity `
            -Path $rustupPath `
            -Version (Invoke-R05EVersionCommand `
                -Path $rustupPath -Arguments @("--version") -Label "Rustup")
        cargo = Get-R05ERustToolIdentity `
            -Name "cargo" `
            -CommandPath $cargoPath `
            -RustupPath $rustupPath `
            -VersionArguments @("-Vv") `
            -Label "Cargo"
        rustc = Get-R05ERustToolIdentity `
            -Name "rustc" `
            -CommandPath $rustcPath `
            -RustupPath $rustupPath `
            -VersionArguments @("-vV") `
            -Label "Rust compiler"
        powershell = Get-R05EFileIdentity `
            -Path $powershellPath `
            -Version $PSVersionTable.PSVersion.ToString()
        git = Get-R05EFileIdentity `
            -Path $gitPath `
            -Version (Invoke-R05EVersionCommand `
                -Path $gitPath -Arguments @("--version") -Label "Git")
        host = [ordered]@{
            os_description = [Runtime.InteropServices.RuntimeInformation]::OSDescription
            os_architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
            process_architecture = [Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
            framework_description = [Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
            processor_identifier = [string][Environment]::GetEnvironmentVariable(
                "PROCESSOR_IDENTIFIER"
            )
            logical_processor_count = [int][Environment]::ProcessorCount
        }
        build_environment = [ordered]@{
            cargo_target_dir = [string][Environment]::GetEnvironmentVariable(
                "CARGO_TARGET_DIR"
            )
            cargo_build_target = [string][Environment]::GetEnvironmentVariable(
                "CARGO_BUILD_TARGET"
            )
            rustflags = [string][Environment]::GetEnvironmentVariable("RUSTFLAGS")
            rustc_wrapper = [string][Environment]::GetEnvironmentVariable(
                "RUSTC_WRAPPER"
            )
            rustup_toolchain = [string][Environment]::GetEnvironmentVariable(
                "RUSTUP_TOOLCHAIN"
            )
            rustup_active_toolchain = Invoke-R05EVersionCommand `
                -Path $rustupPath `
                -Arguments @("show", "active-toolchain") `
                -Label "active Rustup toolchain"
        }
    }
    $canonical = ConvertTo-R05ECanonicalJson -Value $identity
    return [ordered]@{
        schema_version = "sporespore_qsdk_r05e_runtime_identity_projection_v1"
        identity_sha256 = Get-R05ETextSha256 -Text $canonical
        identity = $identity
    }
}

function Assert-R05EExactKeys {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Value,
        [Parameter(Mandatory)][string[]]$ExpectedKeys,
        [Parameter(Mandatory)][string]$Label
    )
    $actual = @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object)
    $expected = @($ExpectedKeys | Sort-Object)
    if (@(Compare-Object -CaseSensitive $expected $actual).Count -ne 0) {
        throw "$CampaignId $Label key set drifted"
    }
}

function Get-R05EExactDependencyPaths {
    param(
        [Parameter(Mandatory)]$Value,
        [Parameter(Mandatory)][string]$Label
    )
    if ($Value -isnot [System.Collections.IList]) {
        throw "$CampaignId $Label must be an array"
    }
    $paths = @(
        foreach ($item in @($Value)) {
            if (
                $item -isnot [string] -or
                [string]::IsNullOrWhiteSpace([string]$item) -or
                [string]$item -cne ([string]$item).Trim() -or
                ([string]$item).Contains("\", [StringComparison]::Ordinal) -or
                [IO.Path]::IsPathRooted([string]$item) -or
                @(([string]$item).Split("/")) -ccontains ".."
            ) {
                throw "$CampaignId $Label contains an invalid path"
            }
            [string]$item
        }
    )
    if ($paths.Count -eq 0) {
        throw "$CampaignId $Label must not be empty"
    }
    $ordered = [string[]]@($paths)
    [Array]::Sort($ordered, [StringComparer]::Ordinal)
    for ($index = 0; $index -lt $paths.Count; $index += 1) {
        if ([string]$paths[$index] -cne [string]$ordered[$index]) {
            throw "$CampaignId $Label must be ordinal-sorted and unique"
        }
        if (
            $index -gt 0 -and
            [string]$ordered[$index - 1] -ceq [string]$ordered[$index]
        ) {
            throw "$CampaignId $Label must be ordinal-sorted and unique"
        }
    }
    return @($paths)
}

function Get-R05EDependencyManifestProjection {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Config)

    $relative = [string]$Config.dependency_manifest_relative_path
    $path = Join-Path $repoRoot $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "$CampaignId complete dependency manifest is missing"
    }
    try {
        $manifest = Get-Content -Raw -LiteralPath $path |
            ConvertFrom-Json -AsHashtable -Depth 100
    } catch {
        throw "$CampaignId complete dependency manifest is invalid JSON"
    }
    if ($manifest -isnot [System.Collections.IDictionary]) {
        throw "$CampaignId complete dependency manifest must be an object"
    }
    Assert-R05EExactKeys `
        -Value $manifest `
        -ExpectedKeys @(
            "schema_version", "status", "gate_id", "ledger_scope", "policy",
            "claim_boundary"
        ) `
        -Label "dependency manifest"
    if (
        [string]$manifest.schema_version -cne [string]$Config.dependency_manifest_schema -or
        [string]$manifest.status -cne [string]$Config.dependency_manifest_status -or
        [string]$manifest.gate_id -cne "QSDK-R05E" -or
        $manifest.policy -isnot [System.Collections.IDictionary] -or
        $manifest.claim_boundary -isnot [System.Collections.IDictionary]
    ) {
        throw "$CampaignId complete dependency manifest identity drifted"
    }
    Assert-R05EExactKeys `
        -Value $manifest.policy `
        -ExpectedKeys @(
            "policy_id", "gdscript_direct_entry_paths",
            "expected_gdscript_transitive_paths", "rust_build_paths",
            "process_and_audit_paths", "expected_qualified_source_count",
            "expected_qualified_source_path_sha256", "active_runtime_artifact_paths",
            "inactive_declared_runtime_artifact_paths"
        ) `
        -Label "dependency policy"
    Assert-R05EExactKeys `
        -Value $manifest.claim_boundary `
        -ExpectedKeys @(
            "complete_transitive_local_gdscript_resource_closure_claimed",
            "complete_local_rust_build_input_closure_claimed",
            "cargo_registry_sources_identified_by_lockfile_not_copied_into_repository",
            "active_runtime_artifact_requires_separate_qualification_binding",
            "external_toolchain_requires_separate_qualification_binding",
            "model_construction_count", "world_attempt_count", "world_build_count",
            "solver_step_count", "physical_acceptance_authority", "release_authority"
        ) `
        -Label "dependency claim boundary"

    $direct = @(Get-R05EExactDependencyPaths `
        -Value $manifest.policy.gdscript_direct_entry_paths `
        -Label "GDScript direct roots")
    $gdscript = @(Get-R05EExactDependencyPaths `
        -Value $manifest.policy.expected_gdscript_transitive_paths `
        -Label "GDScript transitive closure")
    $rust = @(Get-R05EExactDependencyPaths `
        -Value $manifest.policy.rust_build_paths `
        -Label "Rust build closure")
    $process = @(Get-R05EExactDependencyPaths `
        -Value $manifest.policy.process_and_audit_paths `
        -Label "process and audit closure")
    $activeRuntime = @(Get-R05EExactDependencyPaths `
        -Value $manifest.policy.active_runtime_artifact_paths `
        -Label "active runtime artifacts")
    $inactiveRuntime = @(Get-R05EExactDependencyPaths `
        -Value $manifest.policy.inactive_declared_runtime_artifact_paths `
        -Label "inactive runtime artifacts")
    $qualifiedSet = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($relativePath in @($gdscript + $rust + $process)) {
        [void]$qualifiedSet.Add([string]$relativePath)
    }
    $qualified = [string[]]@($qualifiedSet)
    [Array]::Sort($qualified, [StringComparer]::Ordinal)
    $qualifiedDigest = Get-R05ETextSha256 -Text ($qualified -join "`n")
    $runtimeOverlap = @(
        @($activeRuntime + $inactiveRuntime) |
            Where-Object { $qualifiedSet.Contains([string]$_) }
    )
    if (
        [string]$manifest.policy.policy_id -cne
            [string]$Config.dependency_manifest_policy_id -or
        $direct.Count -ne [int]$Config.dependency_gdscript_direct_entry_count -or
        $gdscript.Count -ne [int]$Config.dependency_gdscript_transitive_path_count -or
        $rust.Count -ne [int]$Config.dependency_rust_build_path_count -or
        $process.Count -ne [int]$Config.dependency_process_and_audit_path_count -or
        $qualified.Count -ne [int]$Config.qualified_source_file_count -or
        [int]$manifest.policy.expected_qualified_source_count -ne $qualified.Count -or
        [string]$manifest.policy.expected_qualified_source_path_sha256 -cne
            [string]$Config.qualified_source_path_sha256 -or
        $qualifiedDigest -cne [string]$Config.qualified_source_path_sha256 -or
        $runtimeOverlap.Count -ne 0 -or
        $activeRuntime.Count -ne 1 -or
        [string]$activeRuntime[0] -cne
            "sdk/target/debug/sporespore_godot_adapter.dll" -or
        $inactiveRuntime.Count -ne 1 -or
        [string]$inactiveRuntime[0] -cne
            "sdk/target/release/sporespore_godot_adapter.dll" -or
        -not ($qualified -ccontains $relative) -or
        -not [bool]$manifest.claim_boundary.complete_transitive_local_gdscript_resource_closure_claimed -or
        -not [bool]$manifest.claim_boundary.complete_local_rust_build_input_closure_claimed -or
        -not [bool]$manifest.claim_boundary.cargo_registry_sources_identified_by_lockfile_not_copied_into_repository -or
        -not [bool]$manifest.claim_boundary.active_runtime_artifact_requires_separate_qualification_binding -or
        -not [bool]$manifest.claim_boundary.external_toolchain_requires_separate_qualification_binding -or
        [int]$manifest.claim_boundary.model_construction_count -ne 0 -or
        [int]$manifest.claim_boundary.world_attempt_count -ne 0 -or
        [int]$manifest.claim_boundary.world_build_count -ne 0 -or
        [int]$manifest.claim_boundary.solver_step_count -ne 0 -or
        [bool]$manifest.claim_boundary.physical_acceptance_authority -or
        [bool]$manifest.claim_boundary.release_authority
    ) {
        throw "$CampaignId complete dependency manifest failed strict reconciliation"
    }
    return [ordered]@{
        schema_version = [string]$manifest.schema_version
        gdscript_direct_entry_count = $direct.Count
        gdscript_transitive_path_count = $gdscript.Count
        rust_build_path_count = $rust.Count
        process_and_audit_path_count = $process.Count
        qualified_source_path_count = $qualified.Count
        qualified_source_path_sha256 = $qualifiedDigest
        qualified_source_paths = @($qualified)
    }
}

function Get-CampaignSourcePaths {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Config)

    if (
        $Config.Contains("complete_transitive_dependency_required") -and
        [bool]$Config.complete_transitive_dependency_required
    ) {
        $projection = Get-R05EDependencyManifestProjection -Config $Config
        return @($projection.qualified_source_paths)
    }

    $paths = [System.Collections.Generic.List[string]]::new()
    foreach ($relativePath in @(
        "sdk/$([string]$Config.preregistration_file)",
        "sdk/run_qsdk_independent_morphology_v2.ps1",
        "sdk/experiment_result_integrity.ps1",
        "tests/test_sdk_qsdk_independent_morphology_v2.gd",
        "tests/test_experiment_result_integrity_preflight.ps1",
        "tests/test_sdk_full_integrity_gate_satisfiability.gd",
        "scripts/lab/gait/physical_quadruped_proportion_spec_v2.gd",
        "scripts/lab/gait/physical_wave_gait_quadruped.gd",
        "scripts/lab/gait/sdk_godot_jolt_adapter.gd"
    )) {
        $paths.Add($relativePath)
    }
    if ([bool]$Config.include_selected_policy_source) {
        $paths.Add([string]$Config.selected_policy_source)
    }
    if (@($Config.additional_source_files).Count -gt 0) {
        foreach ($relativePath in @($Config.additional_source_files)) {
            $paths.Add([string]$relativePath)
        }
    }
    if ([bool]$Config.paired_candidate_contract) {
        foreach ($relativePath in @($Config.paired_source_files)) {
            $paths.Add([string]$relativePath)
        }
        foreach ($relativePath in @(
            "sdk/Cargo.toml",
            "sdk/Cargo.lock",
            "sdk/core/Cargo.toml",
            "sdk/core/src/controller.rs",
            "sdk/core/src/lib.rs",
            "sdk/core/src/protocol.rs",
            "sdk/core/src/runtime.rs",
            "sdk/adapters/godot/Cargo.toml",
            "sdk/adapters/godot/src/lib.rs",
            "docs/research/LOCOMOTION_RESEARCH_SOURCES.md",
            "DReCon.pdf",
            "2604.08780v1.pdf",
            "2507.22653v2.pdf"
        )) {
            $paths.Add($relativePath)
        }
    }
    if (
        [string]$Config.test -cne
            "tests/test_sdk_qsdk_r05_independent_morphology.gd"
    ) {
        $paths.Add([string]$Config.test)
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$Config.wrapper_source)) {
        $paths.Add([string]$Config.wrapper_source)
    }
    return @($paths)
}

function Get-ReceiptFromOutput {
    param(
        [Parameter(Mandatory)]
        [string]$OutputText,
        [Parameter(Mandatory)]
        [string]$Prefix
    )
    $lines = @(
        $OutputText -split "\r?\n" |
            Where-Object { $_.StartsWith($Prefix) }
    )
    if ($lines.Count -ne 1) {
        throw "Expected one '$Prefix' receipt, found $($lines.Count)"
    }
    return (
        $lines[0].Substring($Prefix.Length) |
            ConvertFrom-Json -AsHashtable
    )
}

function Invoke-GodotCaptured {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        [Parameter(Mandatory)]
        [string]$WorkerRoot,
        [Parameter(Mandatory)]
        [int]$TimeoutSeconds,
        [hashtable]$AdditionalEnvironment = @{}
    )
    $appData = Join-Path $WorkerRoot "appdata"
    $localAppData = Join-Path $WorkerRoot "localappdata"
    [void][System.IO.Directory]::CreateDirectory($appData)
    [void][System.IO.Directory]::CreateDirectory($localAppData)
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $godotPath
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment["APPDATA"] = $appData
    $start.Environment["LOCALAPPDATA"] = $localAppData
    if (-not [string]::IsNullOrWhiteSpace(
        [string]$campaignConfig.candidate_environment_variable
    )) {
        $start.Environment[
            [string]$campaignConfig.candidate_environment_variable
        ] = [string]$campaignConfig.candidate_id
    }
    foreach ($environmentName in $AdditionalEnvironment.Keys) {
        $start.Environment[[string]$environmentName] = (
            [string]$AdditionalEnvironment[$environmentName]
        )
    }
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    $startedUtc = [DateTime]::UtcNow
    if (-not $process.Start()) {
        throw "Failed to start Godot"
    }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    $killedTree = $false
    if ($timedOut) {
        try {
            $process.Kill($true)
            $killedTree = $true
        } catch {
            $killedTree = $false
        }
        [void]$process.WaitForExit(10000)
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($process.HasExited) { $process.ExitCode } else { -1 }
    $durationSeconds = (
        [DateTime]::UtcNow - $startedUtc
    ).TotalSeconds
    $process.Dispose()
    return [ordered]@{
        exit_code = $exitCode
        timed_out = $timedOut
        killed_process_tree = $killedTree
        duration_seconds = $durationSeconds
        stdout = $stdout
        stderr = $stderr
    }
}

function New-R05CellResult {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Cell,
        [Parameter(Mandatory)]
        [string]$MorphologyId,
        [Parameter(Mandatory)]
        [int]$Seed,
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Execution,
        [AllowNull()]
        [object]$Receipt,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$ReceiptError,
        [Parameter(Mandatory)]
        [string]$TranscriptPath,
        [Parameter(Mandatory)]
        [string]$StderrPath,
        [Parameter(Mandatory)]
        [string]$EngineLogPath
    )
    $parsed = $null -ne $Receipt
    $harnessPassed = (
        $parsed -and
        [int]$Execution.exit_code -eq 0 -and
        -not [bool]$Execution.timed_out -and
        [bool]$Receipt.harness_passed -and
        [int]$Receipt.assertions_failed -eq 0
    )
    $engineLogSha256 = ""
    if (Test-Path -LiteralPath $EngineLogPath) {
        $engineLogSha256 = Get-PrefixedSha256 $EngineLogPath
    }
    return [ordered]@{
        morphology_id = $MorphologyId
        generator_index = [int]$Cell.generator_index
        campaign_seed = $Seed
        process_exit_code = [int]$Execution.exit_code
        timed_out = [bool]$Execution.timed_out
        killed_process_tree = [bool]$Execution.killed_process_tree
        duration_seconds = [double]$Execution.duration_seconds
        receipt_parsed = $parsed
        receipt_parse_error = $ReceiptError
        harness_passed = $harnessPassed
        walking_observed = (
            $parsed -and [bool]$Receipt.walking_observed
        )
        common_execution_integrity = (
            $parsed -and [bool]$Receipt.common_execution_integrity
        )
        mechanism_gate_passed = $(if (
            $parsed -and $Receipt.Contains("mechanism_gate_passed")
        ) {
            [bool]$Receipt.mechanism_gate_passed
        } else {
            $parsed -and [bool]$Receipt.common_execution_integrity
        })
        combined_application_gate_passed = $(if (
            $parsed -and $Receipt.Contains("combined_application_gate_passed")
        ) {
            [bool]$Receipt.combined_application_gate_passed
        } else {
            $parsed -and [bool]$Receipt.common_execution_integrity
        })
        failed_production_walking_gate_count = $(if (
            $parsed -and
            $Receipt.Contains(
                "failed_production_walking_gate_count"
            )
        ) {
            [int]$Receipt.failed_production_walking_gate_count
        } elseif ($parsed -and [bool]$Receipt.walking_observed) {
            0
        } else {
            1
        })
        release_timeout_count = $(if (
            $parsed -and $Receipt.Contains("release_timeout_count")
        ) {
            [int]$Receipt.release_timeout_count
        } else {
            0
        })
        normalized_absolute_task_frame_lateral_displacement = $(if (
            $parsed -and
            $Receipt.Contains(
                "normalized_absolute_task_frame_lateral_displacement"
            )
        ) {
            $Receipt.normalized_absolute_task_frame_lateral_displacement
        } else {
            0.0
        })
        cumulative_absolute_cross_track_error_m_s = $(if (
            $parsed -and
            $Receipt.Contains(
                "cumulative_absolute_cross_track_error_m_s"
            )
        ) {
            $Receipt.cumulative_absolute_cross_track_error_m_s
        } else {
            0.0
        })
        receipt = $Receipt
        transcript_path = $TranscriptPath
        transcript_sha256 = Get-PrefixedSha256 $TranscriptPath
        stderr_path = $StderrPath
        stderr_sha256 = Get-PrefixedSha256 $StderrPath
        engine_log_path = $EngineLogPath
        engine_log_sha256 = $engineLogSha256
    }
}

if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable not found: $godotPath"
}
if (-not (Test-Path -LiteralPath $preregistrationPath -PathType Leaf)) {
    throw "$CampaignId preregistration not found: $preregistrationPath"
}
if (
    $campaignConfig.Contains("preregistration_sha256") -and
    (Get-Sha256 -Path $preregistrationPath) -cne
        [string]$campaignConfig.preregistration_sha256
) {
    throw "$CampaignId preregistration bytes do not match the frozen SHA-256"
}
if ($PreflightOnly -and -not [string]::IsNullOrWhiteSpace($Output)) {
    throw "Preflight-only mode cannot create a retained physics report"
}
if (-not $PreflightOnly -and [string]::IsNullOrWhiteSpace($Output)) {
    throw "The physical campaign requires a durable -Output report.json path"
}

$preregistration = (
    Get-Content -Raw -LiteralPath $preregistrationPath |
        ConvertFrom-Json -AsHashtable
)
$indices = @(
    $preregistration.morphology_generator.generator_indices |
        ForEach-Object { [int]$_ }
)
$cells = @($preregistration.morphology_generator.cells)
$seeds = @(
    $preregistration.repetitions.campaign_seeds |
        ForEach-Object { [int]$_ }
)
$candidateContractExact = $true
if ([bool]$campaignConfig.paired_candidate_contract) {
    $candidateDeclaration = @(
        $preregistration.candidates |
            Where-Object {
                [string]$_.candidate_id -ceq
                    [string]$campaignConfig.candidate_id
            }
    )
    $candidateContractExact = (
        $candidateDeclaration.Count -eq 1 -and
        [string]$candidateDeclaration[0].controller_policy_id -ceq
            $expectedPolicyId -and
        [string]$preregistration.candidate_policy_digests[
            [string]$campaignConfig.candidate_id
        ] -ceq $expectedPolicyDigest -and
        @($candidateDeclaration[0].branch_surfaces).Count -eq 0
    )
} else {
    $candidateContractExact = (
        [string]$preregistration.selected_candidate_id -ceq
            [string]$campaignConfig.candidate_id -and
        [string]$preregistration.selected_policy_id -ceq
            $expectedPolicyId -and
        [string]$preregistration.selected_policy_digest -ceq
            $expectedPolicyDigest
    )
}
$firstCompleteFinal = if (
    [bool]$campaignConfig.paired_candidate_contract
) {
    [bool]$preregistration.repetitions.first_complete_result_is_final_for_each_candidate_source_identity
} else {
    [bool]$preregistration.repetitions.first_complete_result_is_final_for_this_source_identity
}
$freezeParentCommit = if (
    [bool]$campaignConfig.paired_candidate_contract
) {
    [string]$preregistration.implementation_parent_commit
} else {
    [string]$preregistration.freeze_parent_commit
}
$independentValidationInterlockExact = $true
if ($CampaignId -ceq "QSDK-R05C") {
    $predecessorInterlock = $preregistration.predecessor_interlock
    $closurePath = Join-Path $repoRoot (
        [string]$predecessorInterlock.development_closure_manifest
    )
    $selectedPolicyPath = Join-Path $repoRoot (
        [string]$predecessorInterlock.selected_policy_source
    )
    $selectionReportPath = [string]$predecessorInterlock.selection_report_path
    $selectedCandidateReportPath = (
        [string]$predecessorInterlock.selected_candidate_report_path
    )
    $requiredInterlockFilesExist = (
        (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
        (Test-Path -LiteralPath $selectedPolicyPath -PathType Leaf) -and
        (Test-Path -LiteralPath $selectionReportPath -PathType Leaf) -and
        (Test-Path -LiteralPath $selectedCandidateReportPath -PathType Leaf)
    )
    if ($requiredInterlockFilesExist) {
        $closure = (
            Get-Content -Raw -LiteralPath $closurePath |
                ConvertFrom-Json -AsHashtable
        )
        $selectedPolicy = (
            Get-Content -Raw -LiteralPath $selectedPolicyPath |
                ConvertFrom-Json -AsHashtable
        )
        $selection = (
            Get-Content -Raw -LiteralPath $selectionReportPath |
                ConvertFrom-Json -AsHashtable
        )
        $selectedCandidateReport = (
            Get-Content -Raw -LiteralPath $selectedCandidateReportPath |
                ConvertFrom-Json -AsHashtable
        )
        $independentValidationInterlockExact = (
            (Get-PrefixedSha256 $closurePath) -ceq
                [string]$predecessorInterlock.development_closure_manifest_sha256 -and
            (Get-PrefixedSha256 $selectedPolicyPath) -ceq
                [string]$predecessorInterlock.selected_policy_source_sha256 -and
            (Get-PrefixedSha256 $selectionReportPath) -ceq
                [string]$predecessorInterlock.selection_report_sha256 -and
            (Get-PrefixedSha256 $selectedCandidateReportPath) -ceq
                [string]$predecessorInterlock.selected_candidate_report_sha256 -and
            [string]$closure.status -ceq
                [string]$predecessorInterlock.development_closure_status -and
            -not [bool]$closure.reservations.r05c_opened -and
            [string]$closure.selection.selected_candidate_id -ceq
                [string]$campaignConfig.candidate_id -and
            [string]$closure.selection.selected_controller_policy_id -ceq
                $expectedPolicyId -and
            [string]$closure.selection.selected_candidate_policy_digest -ceq
                $expectedPolicyDigest -and
            [string]$selectedPolicy.selected_candidate_id -ceq
                [string]$campaignConfig.candidate_id -and
            [string]$selectedPolicy.selected_policy_id -ceq
                $expectedPolicyId -and
            [string]$selectedPolicy.selected_candidate_policy_digest -ceq
                $expectedPolicyDigest -and
            @($selectedPolicy.selected_profile.branch_surfaces).Count -eq 0 -and
            [string]$selection.selected_candidate_id -ceq
                [string]$campaignConfig.candidate_id -and
            [bool]$selection.family_selected -and
            [int]$selectedCandidateReport.observed_world_count -eq 36 -and
            [int]$selectedCandidateReport.integrity_pass_count -eq 36 -and
            [int]$selectedCandidateReport.walking_pass_count -eq 34 -and
            [bool]$predecessorInterlock.r05b_failure_identities_may_not_condition_r05c_policy_or_gates -and
            [int]$predecessorInterlock.r05c_policy_threshold_material_solver_and_host_scaffold_changes_after_selection -eq 0
        )
    } else {
        $independentValidationInterlockExact = $false
    }
}
$contractExact = (
    [string]$preregistration.schema_version -ceq
        [string]$campaignConfig.preregistration_schema -and
    [string]$preregistration.status -ceq
        [string]$campaignConfig.preregistration_status -and
    [string]$preregistration.gate_id -ceq
        [string]$campaignConfig.gate_id -and
    [string]$preregistration.campaign_id -ceq
        [string]$campaignConfig.id -and
    $candidateContractExact -and
    $independentValidationInterlockExact -and
    ($indices -join ",") -ceq [string]$campaignConfig.indices_csv -and
    $cells.Count -eq $expectedMorphologyCount -and
    ($seeds -join ",") -ceq [string]$campaignConfig.seeds_csv -and
    [int]$preregistration.repetitions.expected_world_count -eq $expectedWorldCount -and
    -not [string]::IsNullOrWhiteSpace($freezeParentCommit) -and
    [string]$preregistration.material.profile_id -ceq
        "godot_jolt_bw5c_mu095_v1" -and
    [bool]$preregistration.repetitions.early_stop_for_outcome_forbidden -and
    $firstCompleteFinal -and
    -not [bool]$preregistration.claim_boundary.arbitrary_quadruped_coverage -and
    -not [bool]$preregistration.claim_boundary.continuous_full_volume_coverage -and
    -not [bool]$preregistration.claim_boundary.completed_engine_neutral_sdk -and
    -not [bool]$preregistration.claim_boundary.release_authorized
)
if (-not $contractExact) {
    throw "$CampaignId preregistration failed strict reconciliation"
}

$executionAuthorityPath = ""
$executionAuthoritySha256 = ""
$executionAuthorityDocument = $null
$executionAuthorityProjection = $null
$executionAuthorityExpected = $null
$qualificationClosurePath = ""
$qualifiedSourcePaths = @()
$preBuildRuntimeIdentityProjection = $null
$runtimeIdentityProjection = $null
if ($physicalAuthorizationRequired) {
    if ($PreflightOnly) {
        if (-not [string]::IsNullOrWhiteSpace($ExecutionAuthority)) {
            throw "Preflight-only mode must not consume a physical execution authority"
        }
    } else {
        if ([string]::IsNullOrWhiteSpace($ExecutionAuthority)) {
            throw "$CampaignId physical execution authority is required"
        }
        $executionAuthorityPath = [System.IO.Path]::GetFullPath($ExecutionAuthority)
        if (-not (Test-Path -LiteralPath $executionAuthorityPath -PathType Leaf)) {
            throw "$CampaignId physical execution authority does not exist"
        }
    }
} elseif (-not [string]::IsNullOrWhiteSpace($ExecutionAuthority)) {
    throw "-ExecutionAuthority is only valid for authorization-gated campaigns"
}

$outputPath = ""
$outputDirectory = ""
$sourceCommit = ""
$originMain = ""
if (-not $PreflightOnly) {
    $sourceStatus = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    )
    if ($LASTEXITCODE -ne 0 -or $sourceStatus.Count -ne 0) {
        throw "Refusing to open $CampaignId worlds from dirty source"
    }
    $sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    $originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
    if (
        $LASTEXITCODE -ne 0 -or
        [string]::IsNullOrWhiteSpace($sourceCommit) -or
        $sourceCommit -cne $originMain
    ) {
        throw "Refusing $CampaignId because HEAD does not match origin/main"
    }
    if ($physicalAuthorizationRequired) {
        $remoteMainRecord = @(
            & git -C $repoRoot ls-remote origin refs/heads/main
        )
        $remoteMain = if ($remoteMainRecord.Count -eq 1) {
            ([string]$remoteMainRecord[0] -split "\s+")[0]
        } else {
            ""
        }
        if (
            $LASTEXITCODE -ne 0 -or
            $remoteMain -cne $sourceCommit
        ) {
            throw (
                "Refusing $CampaignId because source is not equal to live origin/main"
            )
        }
    }
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    if ([System.IO.Path]::GetFileName($outputPath) -cne "report.json") {
        throw "The retained $CampaignId report filename must be exactly report.json"
    }
    if ($physicalAuthorizationRequired) {
        $durableEvidenceRoot = [System.IO.Path]::GetFullPath(
            (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
        )
        $durableEvidencePrefix = $durableEvidenceRoot.TrimEnd(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        ) + [System.IO.Path]::DirectorySeparatorChar
        if (
            -not $outputPath.StartsWith(
                $durableEvidencePrefix,
                [System.StringComparison]::OrdinalIgnoreCase
            )
        ) {
            throw (
                "$CampaignId output must be inside the durable SporeSpore_Evidence root"
            )
        }

        $qualifiedSourcePaths = @(Get-CampaignSourcePaths -Config $campaignConfig)
        $preBuildRuntimeIdentityProjection = Get-R05ERuntimeIdentityProjection
        $qualificationClosurePath = [System.IO.Path]::GetFullPath((
            Join-Path $repoRoot (
                [string]$campaignConfig.qualification_closure_relative_path
            )
        ))
        $executionAuthorityExpected = [ordered]@{
            authority_schema = [string]$campaignConfig.execution_authority_schema
            authority_path = [string]$campaignConfig.execution_authority_relative_path
            qualification_schema = [string]$campaignConfig.qualification_closure_schema
            qualification_closure_path = (
                [string]$campaignConfig.qualification_closure_relative_path
            )
            campaign_id = $CampaignId
            gate_id = [string]$campaignConfig.gate_id
            campaign_role = [string]$campaignConfig.campaign_role
            question_class = [string]$campaignConfig.authority_question_class
            remote = "https://github.com/Slagathore/sporespore.git"
            r05d_design_sha256 = (
                "sha256:3b75b7609b638470ee947326f71018d082beb4a2c2909e78dae77d3b50250a6c"
            )
            preregistration_path = "sdk/$([string]$campaignConfig.preregistration_file)"
            preregistration_sha256 = Get-PrefixedSha256 $preregistrationPath
            expected_morphology_count = $expectedMorphologyCount
            expected_world_count = $expectedWorldCount
            output_report_path = $outputPath
            held_out = [bool]$campaignConfig.held_out
            heldout_access_permitted = [bool]$campaignConfig.heldout_access_permitted
            development_route_ghost_required = (
                [bool]$campaignConfig.development_route_ghost_required
            )
            development_route_ghost_complete = (
                [bool]$campaignConfig.development_route_ghost_complete
            )
            development_route_ghost_closure_path = (
                [string]$campaignConfig.development_route_ghost_closure_path
            )
            dependency_gdscript_direct_entry_count = [int](
                $campaignConfig.dependency_gdscript_direct_entry_count
            )
            dependency_gdscript_transitive_path_count = [int](
                $campaignConfig.dependency_gdscript_transitive_path_count
            )
            dependency_rust_build_path_count = [int](
                $campaignConfig.dependency_rust_build_path_count
            )
            dependency_process_and_audit_path_count = [int](
                $campaignConfig.dependency_process_and_audit_path_count
            )
            qualified_source_path_count = [int](
                $campaignConfig.qualified_source_file_count
            )
            qualified_source_path_sha256 = [string](
                $campaignConfig.qualified_source_path_sha256
            )
            runtime_identity_projection = $preBuildRuntimeIdentityProjection
        }
        $executionAuthorityProjection = Assert-SporeSporeR05EExecutionAuthority `
            -RepoRoot $repoRoot `
            -Head $sourceCommit `
            -AuthorityPath $executionAuthorityPath `
            -QualificationClosurePath $qualificationClosurePath `
            -EvidenceRoot $durableEvidenceRoot `
            -QualifiedSourcePaths $qualifiedSourcePaths `
            -Expected $executionAuthorityExpected
        $executionAuthorityDocument = $executionAuthorityProjection.authority
        $executionAuthoritySha256 = [string](
            $executionAuthorityProjection.authority_sha256
        )
    }
    if (Test-Path -LiteralPath $outputPath) {
        throw "Refusing to overwrite an existing $CampaignId report: $outputPath"
    }
    $outputDirectory = Split-Path -Parent $outputPath
    if (Test-Path -LiteralPath $outputDirectory) {
        $existing = @(Get-ChildItem -LiteralPath $outputDirectory -Force)
        if ($existing.Count -ne 0) {
            throw "Refusing a nonempty $CampaignId evidence directory: $outputDirectory"
        }
    }
}

$tempBase = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::GetTempPath()
)
$tempRoot = Join-Path $tempBase (
    "sporespore_$([string]$campaignConfig.slug)_" +
        [Guid]::NewGuid().ToString("N")
)
$projectRoot = Join-Path $tempRoot "project"
try {
    if ($physicalAuthorizationRequired -and -not $PreflightOnly) {
        $qualificationInterlock = [Threading.Mutex]::new(
            $false,
            $qualificationInterlockName
        )
        try {
            $qualificationInterlockAcquired = $qualificationInterlock.WaitOne(0)
        } catch [Threading.AbandonedMutexException] {
            $qualificationInterlockAcquired = $true
            throw "$CampaignId qualification interlock had an abandoned owner"
        }
        if (-not $qualificationInterlockAcquired) {
            throw "$CampaignId qualification or physical execution is already running"
        }
    }
    if ($physicalAuthorizationRequired) {
        $operationRole = if ($PreflightOnly) {
            "conformance"
        } elseif (
            [string]$campaignConfig.campaign_role -ceq "development_route_ghost"
        ) {
            "physical_development"
        } else {
            "physical"
        }
        $operationLockReceipt = Enter-SporeSporeLocomotionOperationLock `
            -Role $operationRole
        if (-not [bool]$operationLockReceipt.acquired) {
            throw "$CampaignId could not acquire the exclusive locomotion operation lock"
        }
        $operationLockPublic = Get-SporeSporeLocomotionOperationLockPublicReceipt `
            -Receipt $operationLockReceipt
        if (
            -not [bool]$operationLockPublic.acquired -or
            [string]$operationLockPublic.role -cne $operationRole -or
            [bool]$operationLockPublic.test_only -or
            [bool]$operationLockPublic.abandoned_owner_recovered
        ) {
            throw "$CampaignId locomotion operation lock receipt is invalid"
        }
    }

    Push-Location -LiteralPath $sdkRoot
    try {
        & cargo build -p sporespore-godot-adapter --offline
        if ($LASTEXITCODE -ne 0) {
            throw "Godot adapter build failed with exit code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }
    if ($physicalAuthorizationRequired) {
        $runtimeIdentityProjection = Get-R05ERuntimeIdentityProjection
        if (
            -not $PreflightOnly -and
            (
                [string]$runtimeIdentityProjection.identity_sha256 -cne
                    [string]$preBuildRuntimeIdentityProjection.identity_sha256 -or
                (ConvertTo-R05ECanonicalJson `
                    -Value $runtimeIdentityProjection.identity) -cne
                    (ConvertTo-R05ECanonicalJson `
                        -Value $preBuildRuntimeIdentityProjection.identity)
            )
        ) {
            throw "$CampaignId runtime identity changed during the adapter build"
        }
    }

    & (Join-Path $repoRoot "tests\test_experiment_result_integrity_preflight.ps1")
    if ($LASTEXITCODE -ne 0) {
        throw (
            "The exact all-zero and nonzero result-integrity preflight failed " +
            "before $CampaignId"
        )
    }

    [void][System.IO.Directory]::CreateDirectory($projectRoot)
    foreach ($directory in @("scripts", "tests", "sdk")) {
        [void](New-Item `
            -ItemType Junction `
            -Path (Join-Path $projectRoot $directory) `
            -Target (Join-Path $repoRoot $directory))
    }
    $projectText = @"
; Isolated SporeSpore $CampaignId independent morphology campaign.

config_version=5

[application]

config/name="sporespore-$([string]$campaignConfig.slug)-independent-morphology"
config/features=PackedStringArray("4.7", "Forward Plus")

[debug]

gdscript/warnings/shadowed_global_identifier=0

[physics]

3d/physics_engine="Jolt Physics"
jolt_physics_3d/simulation/velocity_steps=20
jolt_physics_3d/simulation/position_steps=7
"@
    Write-Utf8NoBom -Path (Join-Path $projectRoot "project.godot") -Text $projectText

    # These two checks deliberately run before any durable evidence directory
    # is created and before any physical world can open.
    $fullPreflight = Invoke-GodotCaptured `
        -Arguments @(
            "--headless",
            "--path", $projectRoot,
            "--script", "res://$fullGateTest"
        ) `
        -WorkerRoot (Join-Path $tempRoot "preflight-full") `
        -TimeoutSeconds 300
    if ($fullPreflight.exit_code -ne 0 -or $fullPreflight.timed_out) {
        throw "The full synthetic integrity gate failed before $CampaignId"
    }
    $fullReceipt = Get-ReceiptFromOutput `
        -OutputText $fullPreflight.stdout `
        -Prefix "FULL_INTEGRITY_GATE_SATISFIABILITY "
    $runtimeBoundaryWitnesses = @(
        $fullReceipt.policy_runtime_boundary_witnesses
    )
    $runtimeBoundaryFailures = @(
        $runtimeBoundaryWitnesses |
            Where-Object {
                -not [bool]$_.ok -or
                [string]$_.schema_version -cne
                    "sporespore_declared_policy_runtime_boundary_preflight_v1" -or
                [int]$_.native_controller_command_count -ne 8 -or
                -not [bool]$_.native_controller_command_order_exact -or
                -not [bool]$_.execution_mode_plan_passed -or
                -not [bool]$_.gait_memory_nonnegative -or
                -not [bool]$_.native_next_memory_nonnegative -or
                [int]$_.actual_world_build_count -ne 0 -or
                [int]$_.scene_tree_insertion_count -ne 0 -or
                [bool]$_.physics_state_modified -or
                [bool]$_.locomotion_outcome_exposed -or
                [bool]$_.physical_acceptance_authority
            }
    )
    $runtimeBoundaryKeys = @(
        $runtimeBoundaryWitnesses |
            ForEach-Object {
                "{0}|{1}" -f @(
                    [string]$_.stability_policy_id,
                    [int]$_.requested_phase_offset_ticks
                )
            } |
            Sort-Object -Unique
    )
    $declaredSignedOffsetsExact = (
        (
            @(
                $fullReceipt.declared_signed_phase_offsets |
                    ForEach-Object { [int]$_ }
            ) -join ","
        ) -ceq "-3,-2"
    )
    $worstCaseRuntimeHorizon = $fullReceipt.worst_case_runtime_horizon_witness
    $worstCaseRuntimeHorizonExact = (
        [bool]$fullReceipt.worst_case_runtime_horizon_passed -and
        [bool]$worstCaseRuntimeHorizon.ok -and
        [string]$worstCaseRuntimeHorizon.schema_version -ceq
            "sporespore_declared_policy_runtime_horizon_preflight_v1" -and
        [int]$worstCaseRuntimeHorizon.declared_step_count -gt 0 -and
        [int]$worstCaseRuntimeHorizon.native_controller_step_count -eq
            [int]$worstCaseRuntimeHorizon.declared_step_count -and
        [int]$worstCaseRuntimeHorizon.native_controller_command_count -eq
            (8 * [int]$worstCaseRuntimeHorizon.declared_step_count) -and
        [int]$worstCaseRuntimeHorizon.portable_scheduled_plan_count -eq
            [int]$worstCaseRuntimeHorizon.declared_step_count -and
        [bool]$worstCaseRuntimeHorizon.execution_mode_plan_passed -and
        [int]$worstCaseRuntimeHorizon.actual_world_build_count -eq 0 -and
        [int]$worstCaseRuntimeHorizon.scene_tree_insertion_count -eq 0 -and
        -not [bool]$worstCaseRuntimeHorizon.physics_state_modified -and
        -not [bool]$worstCaseRuntimeHorizon.locomotion_outcome_exposed -and
        -not [bool]$worstCaseRuntimeHorizon.physical_acceptance_authority
    )
    $fullPreflightExact = (
        [bool]$fullReceipt.passed -and
        [string]$fullReceipt.schema_version -ceq
            "sporespore_full_integrity_gate_satisfiability_receipt_v5" -and
        [bool]$fullReceipt.exact_declared_policy_runtime_boundaries_called -and
        [bool]$fullReceipt.exact_worst_case_declared_policy_runtime_horizon_called -and
        [int]$fullReceipt.declared_policy_runtime_boundary_count -eq 8 -and
        [bool]$fullReceipt.declared_policy_runtime_boundaries_passed -and
        [bool]$fullReceipt.production_execution_mode_resolver_called -and
        [bool]$fullReceipt.perfect_zero_error_runtime_boundary_on_every_declared_policy -and
        [bool]$fullReceipt.perfect_zero_error_full_runtime_horizon_on_worst_signed_offset -and
        [bool]$fullReceipt.perfect_synthetic_full_integrity_gate_passed -and
        [bool]$fullReceipt.r1_misroute_detected_before_world -and
        $worstCaseRuntimeHorizonExact -and
        $declaredSignedOffsetsExact -and
        $runtimeBoundaryWitnesses.Count -eq 8 -and
        $runtimeBoundaryFailures.Count -eq 0 -and
        $runtimeBoundaryKeys.Count -eq 8 -and
        [bool]$fullReceipt.exact_pre_world_entrypoint_called -and
        [bool]$fullReceipt.exact_selected_policy_full_authority_start_called -and
        [bool]$fullReceipt.selected_policy_full_authority_start_passed -and
        [bool]$fullReceipt.real_portable_policy_semantics_called -and
        [bool]$fullReceipt.exact_post_physics_gate_called -and
        [bool]$fullReceipt.perfect_zero_error_mismatch_failure_and_violation_counts -and
        [bool]$fullReceipt.mechanism_activity_counts_derived_from_real_policy_receipts -and
        [bool]$fullReceipt.bw12e_exact_zero_control_mismatch_detected -and
        [bool]$fullReceipt.missing_policy_semantic_witness_rejected -and
        [int]$fullReceipt.actual_world_build_count -eq 0 -and
        [int]$fullReceipt.scene_tree_insertion_count -eq 0 -and
        -not [bool]$fullReceipt.physics_state_modified -and
        -not [bool]$fullReceipt.locomotion_outcome_exposed -and
        -not [bool]$fullReceipt.physical_acceptance_authority
    )
    if (-not $fullPreflightExact) {
        throw "The full synthetic integrity receipt failed strict reconciliation"
    }

    $candidateMechanismPreflightExact = $true
    $candidateMechanismPreflight = $null
    if ([bool]$campaignConfig.paired_candidate_contract) {
        $candidateMechanismPreflight = Invoke-GodotCaptured `
            -Arguments @(
                "--headless",
                "--path", $projectRoot,
                "--script",
                "res://$([string]$campaignConfig.mechanism_authority_test)"
            ) `
            -WorkerRoot (Join-Path $tempRoot "preflight-mechanism") `
            -TimeoutSeconds 120
        $candidateMechanismPreflightExact = (
            [int]$candidateMechanismPreflight.exit_code -eq 0 -and
            -not [bool]$candidateMechanismPreflight.timed_out -and
            [string]$candidateMechanismPreflight.stdout -match
                [regex]::Escape(
                    [string]$campaignConfig.mechanism_authority_summary
                )
        )
        if (-not $candidateMechanismPreflightExact) {
            throw (
                "The $CampaignId zero-world mechanism authority contract failed"
            )
        }
    }

    $candidateSelectorPreflightExact = $true
    if ([bool]$campaignConfig.paired_candidate_contract) {
        & pwsh `
            -NoLogo `
            -NoProfile `
            -File (
                Join-Path $repoRoot (
                    [string]$campaignConfig.selector_regression_test
                )
            )
        $candidateSelectorPreflightExact = $LASTEXITCODE -eq 0
        if (-not $candidateSelectorPreflightExact) {
            throw (
                "The $CampaignId synthetic selector regression failed before world"
            )
        }
    }

    $exactFiniteSourceGateExact = $true
    $exactFiniteSourceGate = $null
    $exactFiniteSourceReceipt = $null
    if ($campaignConfig.Contains("source_gate_test")) {
        $exactFiniteSourceGate = Invoke-GodotCaptured `
            -Arguments @(
                "--headless",
                "--path", $projectRoot,
                "--script", "res://$([string]$campaignConfig.source_gate_test)"
            ) `
            -WorkerRoot (Join-Path $tempRoot "preflight-exact-finite-source") `
            -TimeoutSeconds 120
        $exactFiniteSourceReceipt = Get-ReceiptFromOutput `
            -OutputText $exactFiniteSourceGate.stdout `
            -Prefix ([string]$campaignConfig.source_gate_prefix)
        $exactFiniteSourceGateExact = (
            [int]$exactFiniteSourceGate.exit_code -eq 0 -and
            -not [bool]$exactFiniteSourceGate.timed_out -and
            [bool]$exactFiniteSourceReceipt.ok -and
            [string]$exactFiniteSourceReceipt.schema_version -ceq
                [string]$campaignConfig.source_gate_schema -and
            [string]$exactFiniteSourceReceipt.gate_id -ceq "QSDK-R05E" -and
            [int]$exactFiniteSourceReceipt.official_descriptor_compile_count -eq 12 -and
            [int]$exactFiniteSourceReceipt.development_ghost_descriptor_compile_count -eq 1 -and
            [bool]$exactFiniteSourceReceipt.official_exact_set_validation_passed -and
            [bool]$exactFiniteSourceReceipt.development_ghost_exact_set_validation_passed -and
            [bool]$exactFiniteSourceReceipt.one_axis_changed_per_official_descriptor -and
            [bool]$exactFiniteSourceReceipt.every_axis_has_exactly_one_low_and_one_high_descriptor -and
            [bool]$exactFiniteSourceReceipt.development_ghost_distinct_from_official_population -and
            [int]$exactFiniteSourceReceipt.negative_control_count -eq 32 -and
            [int]$exactFiniteSourceReceipt.negative_controls_passed -eq 32 -and
            [int]$exactFiniteSourceReceipt.held_out_locomotion_outcome_exposure_count -eq 0 -and
            [int]$exactFiniteSourceReceipt.model_construction_count -eq 0 -and
            [int]$exactFiniteSourceReceipt.world_attempt_count -eq 0 -and
            [int]$exactFiniteSourceReceipt.world_build_count -eq 0 -and
            [int]$exactFiniteSourceReceipt.scene_tree_insertion_count -eq 0 -and
            [int]$exactFiniteSourceReceipt.native_readback_count -eq 0 -and
            [int]$exactFiniteSourceReceipt.solver_step_count -eq 0 -and
            -not [bool]$exactFiniteSourceReceipt.physics_state_modified -and
            -not [bool]$exactFiniteSourceReceipt.physical_question_opened -and
            -not [bool]$exactFiniteSourceReceipt.physical_acceptance_authority -and
            -not [bool]$exactFiniteSourceReceipt.release_authority
        )
        if (-not $exactFiniteSourceGateExact) {
            throw "$CampaignId exact finite morphology source gate failed"
        }
    }

    $entrypointPreflight = Invoke-GodotCaptured `
        -Arguments @(
            "--headless",
            "--path", $projectRoot,
            "--script", "res://$campaignTest",
            "--", "preflight"
        ) `
        -WorkerRoot (Join-Path $tempRoot "preflight-campaign") `
        -TimeoutSeconds 120
    if (
        $entrypointPreflight.exit_code -ne 0 -or
        $entrypointPreflight.timed_out
    ) {
        throw "The $CampaignId $expectedWorldCount-cell entrypoint preflight failed"
    }
    $entrypointReceipt = Get-ReceiptFromOutput `
        -OutputText $entrypointPreflight.stdout `
        -Prefix ([string]$campaignConfig.entrypoint_prefix)
    $entrypointPreflightExact = (
        [bool]$entrypointReceipt.ok -and
        [string]$entrypointReceipt.schema_version -ceq
            [string]$campaignConfig.entrypoint_schema -and
        [string]$entrypointReceipt.campaign_id -ceq $CampaignId -and
        [string]$entrypointReceipt.selected_policy_id -ceq
            $expectedPolicyId -and
        [int]$entrypointReceipt.cell_count -eq $expectedWorldCount -and
        [int]$entrypointReceipt.actual_world_build_count -eq 0 -and
        [int]$entrypointReceipt.scene_tree_insertion_count -eq 0 -and
        -not [bool]$entrypointReceipt.physics_state_modified -and
        [int]$entrypointReceipt.exact_selected_policy_full_authority_start_count -eq $expectedWorldCount -and
        [bool]$entrypointReceipt.selected_policy_full_authority_start_passed -and
        [int]$entrypointReceipt.exact_declared_policy_runtime_boundary_count -eq $expectedWorldCount -and
        [bool]$entrypointReceipt.declared_policy_runtime_boundary_preflight_passed -and
        -not [bool]$entrypointReceipt.locomotion_outcome_exposed -and
        -not [bool]$entrypointReceipt.physical_acceptance_authority
    )
    if (-not $entrypointPreflightExact) {
        throw "The $CampaignId entrypoint receipt failed strict reconciliation"
    }

    $workerAuthorizationPreflightExact = $true
    $workerAuthorizationReceipt = $null
    $workerAuthorizationBypassRefused = $true
    $workerAuthorizationMismatchedTokenRefused = $true
    $workerAuthorizationTypeMutationRefused = $true
    if ($physicalAuthorizationRequired) {
        $authorizationPreflightToken = [Guid]::NewGuid().ToString("N")
        $authorizationPreflightPath = Join-Path (
            $tempRoot
        ) "synthetic-authorization-attempt.json"
        $authorizationPreflightAttempt = [ordered]@{
            schema_version = "sporespore_qsdk_r05e_morphology_attempt_v1"
            authorization_token = $authorizationPreflightToken
            campaign_id = $CampaignId
            gate_id = [string]$campaignConfig.gate_id
            campaign_role = [string]$campaignConfig.campaign_role
            generator_index = [int]$cells[0].generator_index
            morphology_id = [string]$cells[0].morphology_id
            campaign_seed = [int]$seeds[0]
            source_commit = "0" * 40
            r05d_design_sha256 = (
                "sha256:3b75b7609b638470ee947326f71018d082beb4a2c2909e78dae77d3b50250a6c"
            )
            preregistration_sha256 = Get-PrefixedSha256 $preregistrationPath
            execution_authority_path = ""
            execution_authority_sha256 = ""
            synthetic_authorization_preflight = $true
            supervisor_physical_authorized = $false
            maximum_world_attempt_count = 0
            maximum_world_build_count = 0
            world_attempt_count_before_worker = 0
            world_build_count_before_worker = 0
            same_identity_rerun_permitted = $false
            operation_lock = [ordered]@{
                schema_version = "sporespore_locomotion_operation_lock_receipt_v1"
                acquired = $true
                role = "preflight"
            }
            physical_acceptance_authority = $false
        }
        Write-Utf8NoBom `
            -Path $authorizationPreflightPath `
            -Text (
                $authorizationPreflightAttempt |
                    ConvertTo-Json -Depth 20 -Compress
            )
        $authorizationEnvironment = @{
            SPORESPORE_QSDK_R05E_ATTEMPT = $authorizationPreflightPath
            SPORESPORE_QSDK_R05E_TOKEN = $authorizationPreflightToken
        }
        $authorizationPreflight = Invoke-GodotCaptured `
            -Arguments @(
                "--headless",
                "--path", $projectRoot,
                "--script", "res://$campaignTest",
                "--", "authorization-preflight",
                ([string]$cells[0].morphology_id),
                ([string]$seeds[0])
            ) `
            -WorkerRoot (Join-Path $tempRoot "preflight-authorization") `
            -TimeoutSeconds 120 `
            -AdditionalEnvironment $authorizationEnvironment
        $workerAuthorizationReceipt = Get-ReceiptFromOutput `
            -OutputText $authorizationPreflight.stdout `
            -Prefix ([string]$campaignConfig.authorization_preflight_prefix)
        $workerAuthorizationProjection = $workerAuthorizationReceipt.authorization
        $workerAuthorizationPreflightExact = (
            [int]$authorizationPreflight.exit_code -eq 0 -and
            -not [bool]$authorizationPreflight.timed_out -and
            [bool]$workerAuthorizationReceipt.ok -and
            [string]$workerAuthorizationReceipt.schema_version -ceq
                [string]$campaignConfig.authorization_preflight_schema -and
            [int]$workerAuthorizationReceipt.actual_world_build_count -eq 0 -and
            [int]$workerAuthorizationReceipt.scene_tree_insertion_count -eq 0 -and
            -not [bool]$workerAuthorizationReceipt.physics_state_modified -and
            -not [bool]$workerAuthorizationReceipt.locomotion_outcome_exposed -and
            -not [bool]$workerAuthorizationReceipt.physical_acceptance_authority -and
            ($workerAuthorizationProjection -is [System.Collections.IDictionary]) -and
            [bool]$workerAuthorizationProjection.ok -and
            [string]$workerAuthorizationProjection.failure_code -ceq "" -and
            [bool]$workerAuthorizationProjection.required -and
            [string]$workerAuthorizationProjection.campaign_role -ceq
                [string]$campaignConfig.campaign_role -and
            [int]$workerAuthorizationProjection.generator_index -eq
                [int]$cells[0].generator_index -and
            [string]$workerAuthorizationProjection.morphology_id -ceq
                [string]$cells[0].morphology_id -and
            [int]$workerAuthorizationProjection.campaign_seed -eq
                [int]$seeds[0] -and
            [string]$workerAuthorizationProjection.source_commit -ceq ("0" * 40) -and
            [bool]$workerAuthorizationProjection.authorization_preflight -and
            [int]$workerAuthorizationProjection.world_build_count -eq 0 -and
            -not [bool]$workerAuthorizationProjection.physical_acceptance_authority
        )
        if (-not $workerAuthorizationPreflightExact) {
            throw (
                "$CampaignId worker authorization preflight failed: " +
                ($workerAuthorizationReceipt | ConvertTo-Json -Compress -Depth 20)
            )
        }

        $mismatchedEnvironment = @{
            SPORESPORE_QSDK_R05E_ATTEMPT = $authorizationPreflightPath
            SPORESPORE_QSDK_R05E_TOKEN = "wrong-$authorizationPreflightToken"
        }
        $mismatchedAuthorization = Invoke-GodotCaptured `
            -Arguments @(
                "--headless",
                "--path", $projectRoot,
                "--script", "res://$campaignTest",
                "--", "authorization-preflight",
                ([string]$cells[0].morphology_id),
                ([string]$seeds[0])
            ) `
            -WorkerRoot (Join-Path $tempRoot "preflight-authorization-mismatch") `
            -TimeoutSeconds 120 `
            -AdditionalEnvironment $mismatchedEnvironment
        $mismatchedReceipt = Get-ReceiptFromOutput `
            -OutputText $mismatchedAuthorization.stdout `
            -Prefix ([string]$campaignConfig.authorization_preflight_prefix)
        $workerAuthorizationMismatchedTokenRefused = (
            [int]$mismatchedAuthorization.exit_code -ne 0 -and
            -not [bool]$mismatchedReceipt.ok -and
            [int]$mismatchedReceipt.actual_world_build_count -eq 0 -and
            -not [bool]$mismatchedReceipt.locomotion_outcome_exposed
        )
        if (-not $workerAuthorizationMismatchedTokenRefused) {
            throw "$CampaignId mismatched worker authorization token did not fail closed"
        }

        $typeMutationPath = Join-Path (
            $tempRoot
        ) "synthetic-authorization-attempt-type-mutation.json"
        $typeMutationAttempt = (
            $authorizationPreflightAttempt |
                ConvertTo-Json -Depth 20 -Compress |
                ConvertFrom-Json -AsHashtable
        )
        $typeMutationAttempt.generator_index = (
            [string]$typeMutationAttempt.generator_index
        )
        Write-Utf8NoBom `
            -Path $typeMutationPath `
            -Text (
                $typeMutationAttempt |
                    ConvertTo-Json -Depth 20 -Compress
            )
        $typeMutationEnvironment = @{
            SPORESPORE_QSDK_R05E_ATTEMPT = $typeMutationPath
            SPORESPORE_QSDK_R05E_TOKEN = $authorizationPreflightToken
        }
        $typeMutationAuthorization = Invoke-GodotCaptured `
            -Arguments @(
                "--headless",
                "--path", $projectRoot,
                "--script", "res://$campaignTest",
                "--", "authorization-preflight",
                ([string]$cells[0].morphology_id),
                ([string]$seeds[0])
            ) `
            -WorkerRoot (Join-Path $tempRoot "preflight-authorization-type-mutation") `
            -TimeoutSeconds 120 `
            -AdditionalEnvironment $typeMutationEnvironment
        $typeMutationReceipt = Get-ReceiptFromOutput `
            -OutputText $typeMutationAuthorization.stdout `
            -Prefix ([string]$campaignConfig.authorization_preflight_prefix)
        $workerAuthorizationTypeMutationRefused = (
            [int]$typeMutationAuthorization.exit_code -ne 0 -and
            -not [bool]$typeMutationReceipt.ok -and
            [string]$typeMutationReceipt.authorization.failure_code -ceq
                "QSDK_R05E_PHYSICAL_AUTHORIZATION_INVALID_TYPES" -and
            [int]$typeMutationReceipt.actual_world_build_count -eq 0 -and
            [int]$typeMutationReceipt.scene_tree_insertion_count -eq 0 -and
            -not [bool]$typeMutationReceipt.locomotion_outcome_exposed
        )
        if (-not $workerAuthorizationTypeMutationRefused) {
            throw "$CampaignId worker authorization type mutation did not fail closed"
        }

        $directBypass = Invoke-GodotCaptured `
            -Arguments @(
                "--headless",
                "--path", $projectRoot,
                "--script", "res://$campaignTest",
                "--", "physical",
                ([string]$cells[0].morphology_id),
                ([string]$seeds[0])
            ) `
            -WorkerRoot (Join-Path $tempRoot "preflight-direct-bypass") `
            -TimeoutSeconds 120
        $directBypassText = $directBypass.stdout + $directBypass.stderr
        $workerAuthorizationBypassRefused = (
            [int]$directBypass.exit_code -ne 0 -and
            $directBypassText.Contains(
                "QSDK_R05E_PHYSICAL_AUTHORIZATION_REQUIRED",
                [StringComparison]::Ordinal
            )
        )
        if (-not $workerAuthorizationBypassRefused) {
            throw "$CampaignId direct physical worker bypass did not fail closed"
        }
    }

    # Resolve and hash every source that the final report will retain before
    # any world. A missing wrapper, campaign specialization, or preregistration
    # is therefore a launch failure, not an end-of-campaign surprise.
    $sourceFiles = @(Get-CampaignSourcePaths -Config $campaignConfig)
    $sourceFileReceipts = @(
        foreach ($relativePath in $sourceFiles) {
            $absolutePath = Join-Path $repoRoot $relativePath
            if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
                throw "$CampaignId source file not found: $relativePath"
            }
            [ordered]@{
                path = $relativePath
                sha256 = Get-PrefixedSha256 $absolutePath
            }
        }
    )

    # Exercise the entire retained aggregate/report path with perfect
    # synthetic input before the first physical world. This is deliberately
    # separate from the Godot policy-semantic gate: it catches launcher,
    # dynamic-field, source-inventory, and report defects that would otherwise
    # appear only after an expensive complete campaign.
    $runnerProbeRoot = Join-Path $tempRoot "preflight-runner-report"
    [void][System.IO.Directory]::CreateDirectory($runnerProbeRoot)
    $runnerProbeTranscript = Join-Path $runnerProbeRoot "transcript.log"
    $runnerProbeStderr = Join-Path $runnerProbeRoot "stderr.log"
    $runnerProbeMissingEngineLog = Join-Path $runnerProbeRoot "engine.log"
    $runnerProbeReport = Join-Path $runnerProbeRoot "report.json"
    Write-Utf8NoBom -Path $runnerProbeTranscript -Text "synthetic-perfect"
    Write-Utf8NoBom -Path $runnerProbeStderr -Text ""
    $runnerProbeExecution = [ordered]@{
        exit_code = 0
        timed_out = $false
        killed_process_tree = $false
        duration_seconds = 0.0
    }
    $runnerProbeReceipt = [ordered]@{
        harness_passed = $true
        assertions_failed = 0
        walking_observed = $true
        common_execution_integrity = $true
    }
    $runnerProbeResults = [System.Collections.Generic.List[object]]::new()
    foreach ($cell in $cells) {
        foreach ($seed in $seeds) {
            $runnerProbeResults.Add(
                (
                    New-R05CellResult `
                        -Cell $cell `
                        -MorphologyId ([string]$cell.morphology_id) `
                        -Seed ([int]$seed) `
                        -Execution $runnerProbeExecution `
                        -Receipt $runnerProbeReceipt `
                        -ReceiptError "" `
                        -TranscriptPath $runnerProbeTranscript `
                        -StderrPath $runnerProbeStderr `
                        -EngineLogPath $runnerProbeMissingEngineLog
                )
            )
        }
    }
    $syntheticMetrics = Measure-SporeExperimentResults `
        -Results @($runnerProbeResults) `
        -ExpectedCount $expectedWorldCount
    $syntheticPerfectExact = (
        [bool]$syntheticMetrics.integrity_and_mechanism_complete -and
        [int]$syntheticMetrics.observed_world_count -eq $expectedWorldCount -and
        [int]$syntheticMetrics.complete_receipt_count -eq $expectedWorldCount -and
        [int]$syntheticMetrics.harness_pass_count -eq $expectedWorldCount -and
        [int]$syntheticMetrics.integrity_pass_count -eq $expectedWorldCount -and
        [int]$syntheticMetrics.mechanism_pass_count -eq $expectedWorldCount -and
        [int]$syntheticMetrics.combined_application_pass_count -eq $expectedWorldCount -and
        [int]$syntheticMetrics.walking_conjunction_pass_count -eq $expectedWorldCount -and
        [int]$syntheticMetrics.aggregate_failed_production_walking_gate_count -eq 0 -and
        [int]$syntheticMetrics.aggregate_release_timeout_count -eq 0 -and
        [double]$syntheticMetrics.maximum_normalized_absolute_task_frame_lateral_displacement -eq 0.0 -and
        [double]$syntheticMetrics.aggregate_normalized_absolute_task_frame_lateral_displacement -eq 0.0 -and
        [double]$syntheticMetrics.aggregate_cumulative_absolute_cross_track_error_m_s -eq 0.0
    )
    if (-not $syntheticPerfectExact) {
        throw (
            "The exact production aggregate cannot accept a perfect " +
            "synthetic $CampaignId result"
        )
    }
    $canaryResults = @(
        foreach ($probeResult in $runnerProbeResults) {
            (
                $probeResult |
                    ConvertTo-Json -Depth 40 |
                    ConvertFrom-Json -AsHashtable
            )
        }
    )
    $primaryCanaryIndex = [Math]::Min(6, $expectedWorldCount - 1)
    $lastCanaryIndex = $expectedWorldCount - 1
    $canaryResults[$primaryCanaryIndex]["failed_production_walking_gate_count"] = 3
    $canaryResults[$primaryCanaryIndex]["release_timeout_count"] = 2
    $canaryResults[$primaryCanaryIndex][
        "normalized_absolute_task_frame_lateral_displacement"
    ] = 1.25
    $canaryResults[$primaryCanaryIndex][
        "cumulative_absolute_cross_track_error_m_s"
    ] = 0.75
    $expectedCanaryAggregateLateral = 1.25
    $expectedCanaryAggregateCrossTrack = 0.75
    if ($expectedWorldCount -ge 20) {
        $canaryResults[19][
            "normalized_absolute_task_frame_lateral_displacement"
        ] = 0.50
        $canaryResults[19]["cumulative_absolute_cross_track_error_m_s"] = 0.25
        $expectedCanaryAggregateLateral = 1.75
        $expectedCanaryAggregateCrossTrack = 1.0
    }
    $canaryResults[$lastCanaryIndex]["walking_observed"] = $false
    $canaryMetrics = Measure-SporeExperimentResults `
        -Results $canaryResults `
        -ExpectedCount $expectedWorldCount
    $nonzeroCanaryExact = (
        [bool]$canaryMetrics.integrity_and_mechanism_complete -and
        [int]$canaryMetrics.walking_conjunction_pass_count -eq
            ($expectedWorldCount - 1) -and
        [int]$canaryMetrics.walking_conjunction_failure_count -eq 1 -and
        [int]$canaryMetrics.aggregate_failed_production_walking_gate_count -eq 3 -and
        [int]$canaryMetrics.aggregate_release_timeout_count -eq 2 -and
        [double]$canaryMetrics.maximum_normalized_absolute_task_frame_lateral_displacement -eq 1.25 -and
        [double]$canaryMetrics.aggregate_normalized_absolute_task_frame_lateral_displacement -eq
            $expectedCanaryAggregateLateral -and
        [double]$canaryMetrics.aggregate_cumulative_absolute_cross_track_error_m_s -eq
            $expectedCanaryAggregateCrossTrack
    )
    if (-not $nonzeroCanaryExact) {
        throw "$CampaignId nonzero ordered-dictionary aggregation canary failed"
    }
    $runnerProbeDocument = [ordered]@{
        schema_version = [string]$campaignConfig.report_schema
        synthetic_preflight_schema = (
            [string]$campaignConfig.runner_preflight_schema
        )
        perfect_zero_error_input = $true
        source = [ordered]@{
            commit = "synthetic-zero-world"
            remote = "origin/main"
            clean = $true
            matches_origin_main = $true
            source_files = $sourceFileReceipts
        }
        campaign_id = $CampaignId
        gate_id = [string]$campaignConfig.gate_id
        campaign_role = [string]$campaignConfig.campaign_role
        selected_candidate_id = [string]$campaignConfig.candidate_id
        selected_policy_id = $expectedPolicyId
        selected_policy_digest = $expectedPolicyDigest
        expected_world_count = $expectedWorldCount
        observed_world_count = $runnerProbeResults.Count
        complete_receipt_count = $runnerProbeResults.Count
        harness_pass_count = $runnerProbeResults.Count
        walking_pass_count = $runnerProbeResults.Count
        integrity_pass_count = $runnerProbeResults.Count
        failure_count = 0
        metrics = $syntheticMetrics
        nonzero_canary_metrics = $canaryMetrics
        full_integrity_preflight = [ordered]@{
            passed = $fullPreflightExact
            actual_world_build_count = 0
        }
        candidate_selector_preflight = [ordered]@{
            required = [bool]$campaignConfig.paired_candidate_contract
            passed = $candidateSelectorPreflightExact
            actual_world_build_count = 0
            physical_acceptance_authority = $false
        }
        results = @($runnerProbeResults)
        same_selected_policy_independent_morphology_evidence = (
            $sameSelectedPolicyEvidenceOnPass
        )
        development_data_only = $developmentDataOnly
        physical_world_build_count = 0
        physical_acceptance_authority = $false
    }
    $runnerProbeDocument[
        [string]$campaignConfig.entrypoint_report_field
    ] = [ordered]@{
        passed = $entrypointPreflightExact
        cell_count = $expectedWorldCount
        actual_world_build_count = 0
    }
    $runnerProbeDocument[[string]$campaignConfig.pass_field] = $true
    Write-Utf8NoBom `
        -Path $runnerProbeReport `
        -Text (
            $runnerProbeDocument |
                ConvertTo-Json -Depth 20 |
                ForEach-Object { $_ + [Environment]::NewLine }
        )
    $runnerProbeRoundTrip = (
        Get-Content -Raw -LiteralPath $runnerProbeReport |
            ConvertFrom-Json -AsHashtable
    )
    $runnerPreflightExact = (
        [string]$runnerProbeRoundTrip.schema_version -ceq
            [string]$campaignConfig.report_schema -and
        [string]$runnerProbeRoundTrip.synthetic_preflight_schema -ceq
            [string]$campaignConfig.runner_preflight_schema -and
        [bool]$runnerProbeRoundTrip.perfect_zero_error_input -and
        [string]$runnerProbeRoundTrip.campaign_id -ceq $CampaignId -and
        [int]$runnerProbeRoundTrip.source.source_files.Count -eq
            $sourceFileReceipts.Count -and
        [int]$runnerProbeRoundTrip.expected_world_count -eq $expectedWorldCount -and
        [int]$runnerProbeRoundTrip.observed_world_count -eq $expectedWorldCount -and
        [int]$runnerProbeRoundTrip.complete_receipt_count -eq $expectedWorldCount -and
        [int]$runnerProbeRoundTrip.harness_pass_count -eq $expectedWorldCount -and
        [int]$runnerProbeRoundTrip.walking_pass_count -eq $expectedWorldCount -and
        [int]$runnerProbeRoundTrip.integrity_pass_count -eq $expectedWorldCount -and
        [int]$runnerProbeRoundTrip.failure_count -eq 0 -and
        [int]$runnerProbeRoundTrip.results.Count -eq $expectedWorldCount -and
        [bool]$runnerProbeRoundTrip.metrics.integrity_and_mechanism_complete -and
        [int]$runnerProbeRoundTrip.metrics.aggregate_failed_production_walking_gate_count -eq 0 -and
        [int]$runnerProbeRoundTrip.metrics.aggregate_release_timeout_count -eq 0 -and
        [int]$runnerProbeRoundTrip.nonzero_canary_metrics.aggregate_failed_production_walking_gate_count -eq 3 -and
        [int]$runnerProbeRoundTrip.nonzero_canary_metrics.aggregate_release_timeout_count -eq 2 -and
        [double]$runnerProbeRoundTrip.nonzero_canary_metrics.maximum_normalized_absolute_task_frame_lateral_displacement -eq 1.25 -and
        [double]$runnerProbeRoundTrip.nonzero_canary_metrics.aggregate_normalized_absolute_task_frame_lateral_displacement -eq
            $expectedCanaryAggregateLateral -and
        [double]$runnerProbeRoundTrip.nonzero_canary_metrics.aggregate_cumulative_absolute_cross_track_error_m_s -eq
            $expectedCanaryAggregateCrossTrack -and
        (
            [bool]$runnerProbeRoundTrip.candidate_selector_preflight.passed -eq
                $candidateSelectorPreflightExact
        ) -and
        -not [bool]$runnerProbeRoundTrip.candidate_selector_preflight.physical_acceptance_authority -and
        [bool]$runnerProbeRoundTrip[
            [string]$campaignConfig.entrypoint_report_field
        ].passed -and
        [bool]$runnerProbeRoundTrip[
            [string]$campaignConfig.pass_field
        ] -and
        (
            [bool]$runnerProbeRoundTrip.same_selected_policy_independent_morphology_evidence -eq
                $sameSelectedPolicyEvidenceOnPass
        ) -and
        (
            [bool]$runnerProbeRoundTrip.development_data_only -eq
                $developmentDataOnly
        ) -and
        [int]$runnerProbeRoundTrip.physical_world_build_count -eq 0 -and
        -not [bool]$runnerProbeRoundTrip.physical_acceptance_authority
    )
    if (-not $runnerPreflightExact) {
        throw "The $CampaignId runner/report synthetic preflight failed"
    }

    if ($PreflightOnly) {
        $preflightBundle = [ordered]@{
            schema_version = [string]$campaignConfig.preflight_bundle_schema
            campaign_id = $CampaignId
            gate_id = [string]$campaignConfig.gate_id
            candidate_id = [string]$campaignConfig.candidate_id
            controller_policy_id = $expectedPolicyId
            candidate_policy_digest = $expectedPolicyDigest
            full_integrity_receipt_schema = (
                [string]$fullReceipt.schema_version
            )
            full_integrity_passed = [bool]$fullReceipt.passed
            exact_declared_policy_runtime_boundaries_called = (
                [bool]$fullReceipt.exact_declared_policy_runtime_boundaries_called
            )
            declared_policy_runtime_boundary_count = (
                [int]$fullReceipt.declared_policy_runtime_boundary_count
            )
            declared_policy_runtime_boundaries_passed = (
                [bool]$fullReceipt.declared_policy_runtime_boundaries_passed
            )
            exact_worst_case_declared_policy_runtime_horizon_called = (
                [bool]$fullReceipt.exact_worst_case_declared_policy_runtime_horizon_called
            )
            worst_case_declared_policy_runtime_horizon_passed = (
                [bool]$fullReceipt.worst_case_runtime_horizon_passed
            )
            worst_case_declared_policy_runtime_horizon_step_count = (
                [int]$fullReceipt.worst_case_runtime_horizon_witness.declared_step_count
            )
            worst_case_declared_policy_runtime_horizon_command_count = (
                [int]$fullReceipt.worst_case_runtime_horizon_witness.native_controller_command_count
            )
            production_execution_mode_resolver_called = (
                [bool]$fullReceipt.production_execution_mode_resolver_called
            )
            perfect_zero_error_runtime_boundary_on_every_declared_policy = (
                [bool]$fullReceipt.perfect_zero_error_runtime_boundary_on_every_declared_policy
            )
            perfect_zero_error_full_runtime_horizon_on_worst_signed_offset = (
                [bool]$fullReceipt.perfect_zero_error_full_runtime_horizon_on_worst_signed_offset
            )
            perfect_synthetic_full_integrity_gate_passed = (
                [bool]$fullReceipt.perfect_synthetic_full_integrity_gate_passed
            )
            r1_misroute_detected_before_world = (
                [bool]$fullReceipt.r1_misroute_detected_before_world
            )
            baseline_regression_full_authority_start_called = (
                [bool]$fullReceipt.exact_selected_policy_full_authority_start_called
            )
            baseline_regression_full_authority_start_passed = (
                [bool]$fullReceipt.selected_policy_full_authority_start_passed
            )
            baseline_regression_full_authority_start_receipt = (
                $fullReceipt.selected_policy_full_authority_start
            )
            candidate_mechanism_authority_preflight_passed = (
                $candidateMechanismPreflightExact
            )
            candidate_selector_regression_preflight_passed = (
                $candidateSelectorPreflightExact
            )
            entrypoint_receipt_schema = (
                [string]$entrypointReceipt.schema_version
            )
            entrypoint_cell_count = [int]$entrypointReceipt.cell_count
            exact_candidate_full_authority_start_count = (
                [int]$entrypointReceipt.exact_selected_policy_full_authority_start_count
            )
            candidate_full_authority_start_passed = (
                [bool]$entrypointReceipt.selected_policy_full_authority_start_passed
            )
            exact_candidate_declared_policy_runtime_boundary_count = (
                [int]$entrypointReceipt.exact_declared_policy_runtime_boundary_count
            )
            candidate_declared_policy_runtime_boundary_preflight_passed = (
                [bool]$entrypointReceipt.declared_policy_runtime_boundary_preflight_passed
            )
            runner_report_serialization_passed = $runnerPreflightExact
            runner_report_synthetic_cell_count = $runnerProbeResults.Count
            runner_report_source_file_count = $sourceFileReceipts.Count
            perfect_all_zero_production_aggregate_gate_passed = (
                $syntheticPerfectExact
            )
            nonzero_ordered_dictionary_canary_passed = $nonzeroCanaryExact
            nonzero_canary_failed_production_walking_gate_count = (
                [int]$canaryMetrics.aggregate_failed_production_walking_gate_count
            )
            nonzero_canary_release_timeout_count = (
                [int]$canaryMetrics.aggregate_release_timeout_count
            )
            worker_physical_authorization_required = $physicalAuthorizationRequired
            worker_authorization_preflight_passed = (
                $workerAuthorizationPreflightExact
            )
            mismatched_worker_authorization_token_refused = (
                $workerAuthorizationMismatchedTokenRefused
            )
            worker_authorization_type_mutation_refused = (
                $workerAuthorizationTypeMutationRefused
            )
            direct_physical_worker_bypass_refused = (
                $workerAuthorizationBypassRefused
            )
            actual_world_build_count = 0
            scene_tree_insertion_count = 0
            physics_state_modified = $false
            locomotion_outcome_exposed = $false
            physical_acceptance_authority = $false
        }
        if (
            $campaignConfig.Contains("complete_transitive_dependency_required") -and
            [bool]$campaignConfig.complete_transitive_dependency_required
        ) {
            $dependencyProjection = Get-R05EDependencyManifestProjection `
                -Config $campaignConfig
            $preflightBundle["dependency_manifest_schema"] = [string](
                $dependencyProjection.schema_version
            )
            $preflightBundle["complete_transitive_dependency_manifest_reconciled"] = $true
            $preflightBundle["dependency_gdscript_direct_entry_count"] = [int](
                $dependencyProjection.gdscript_direct_entry_count
            )
            $preflightBundle["dependency_gdscript_transitive_path_count"] = [int](
                $dependencyProjection.gdscript_transitive_path_count
            )
            $preflightBundle["dependency_rust_build_path_count"] = [int](
                $dependencyProjection.rust_build_path_count
            )
            $preflightBundle["dependency_process_and_audit_path_count"] = [int](
                $dependencyProjection.process_and_audit_path_count
            )
            $preflightBundle["qualified_source_path_count"] = [int](
                $dependencyProjection.qualified_source_path_count
            )
            $preflightBundle["qualified_source_path_sha256"] = [string](
                $dependencyProjection.qualified_source_path_sha256
            )
            $preflightBundle["runtime_identity_projection"] = $runtimeIdentityProjection
        }
        if (-not [bool]$campaignConfig.paired_candidate_contract) {
            # Preserve the frozen R05/R05B receipt vocabulary for historical
            # consumers. BW14V uses the explicit baseline/candidate names
            # above so its treatment proof cannot be confused with the shared
            # selected-policy regression.
            $preflightBundle[
                "exact_selected_policy_full_authority_start_called"
            ] = [bool]$fullReceipt.exact_selected_policy_full_authority_start_called
            $preflightBundle[
                "selected_policy_full_authority_start_passed"
            ] = [bool]$fullReceipt.selected_policy_full_authority_start_passed
            $preflightBundle["selected_policy_full_authority_start"] = (
                $fullReceipt.selected_policy_full_authority_start
            )
            $preflightBundle[
                "exact_selected_policy_full_authority_start_count"
            ] = [int]$entrypointReceipt.exact_selected_policy_full_authority_start_count
            $preflightBundle["entrypoint_full_authority_start_passed"] = (
                [bool]$entrypointReceipt.selected_policy_full_authority_start_passed
            )
            $preflightBundle[
                "exact_entrypoint_declared_policy_runtime_boundary_count"
            ] = [int]$entrypointReceipt.exact_declared_policy_runtime_boundary_count
            $preflightBundle[
                "entrypoint_declared_policy_runtime_boundary_preflight_passed"
            ] = [bool]$entrypointReceipt.declared_policy_runtime_boundary_preflight_passed
        }
        if ($campaignConfig.Contains("source_gate_test")) {
            $preflightBundle["expected_morphology_count"] = $expectedMorphologyCount
            $preflightBundle["expected_world_count"] = $expectedWorldCount
            $preflightBundle["exact_finite_morphology_source_gate"] = [ordered]@{
                passed = $exactFiniteSourceGateExact
                schema_version = [string]$exactFiniteSourceReceipt.schema_version
                official_descriptor_compile_count = (
                    [int]$exactFiniteSourceReceipt.official_descriptor_compile_count
                )
                development_ghost_descriptor_compile_count = (
                    [int]$exactFiniteSourceReceipt.development_ghost_descriptor_compile_count
                )
                negative_control_count = (
                    [int]$exactFiniteSourceReceipt.negative_control_count
                )
                negative_controls_passed = (
                    [int]$exactFiniteSourceReceipt.negative_controls_passed
                )
                actual_world_build_count = 0
                solver_step_count = 0
                locomotion_outcome_exposed = $false
                physical_acceptance_authority = $false
            }
            $preflightBundle["operation_lock"] = $operationLockPublic
        }
        Write-Host (
            [string]$campaignConfig.preflight_bundle_prefix +
            (
                $preflightBundle |
                    ConvertTo-Json -Compress -Depth 50
            )
        )
        Write-Host (
            "$CampaignId preflight passed: full synthetic gate plus " +
            "$expectedWorldCount/$expectedWorldCount real entrypoint cells plus " +
            "runner/report serialization, " +
            "zero worlds."
        )
        return
    }

    if ($physicalAuthorizationRequired) {
        # The complete qualification has run under the same lock that remains
        # held for physical work. Reconcile source and the one-shot authority
        # again at the last possible boundary before retained state exists.
        $finalSourceStatus = @(
            & git -C $repoRoot status --porcelain=v1 --untracked-files=all
        )
        $finalStatusExitCode = $LASTEXITCODE
        $finalHead = (& git -C $repoRoot rev-parse HEAD).Trim()
        $finalHeadExitCode = $LASTEXITCODE
        $finalOriginMain = (& git -C $repoRoot rev-parse origin/main).Trim()
        $finalOriginExitCode = $LASTEXITCODE
        $finalRemoteMainRecord = @(
            & git -C $repoRoot ls-remote origin refs/heads/main
        )
        $finalRemoteExitCode = $LASTEXITCODE
        $finalRemoteMain = if ($finalRemoteMainRecord.Count -eq 1) {
            ([string]$finalRemoteMainRecord[0] -split "\s+")[0]
        } else {
            ""
        }
        if (
            $finalStatusExitCode -ne 0 -or
            $finalHeadExitCode -ne 0 -or
            $finalOriginExitCode -ne 0 -or
            $finalRemoteExitCode -ne 0 -or
            $finalSourceStatus.Count -ne 0 -or
            $finalHead -cne $sourceCommit -or
            $finalOriginMain -cne $sourceCommit -or
            $finalRemoteMain -cne $sourceCommit
        ) {
            throw "$CampaignId source or single-use authority drifted during qualification"
        }
        $finalExecutionAuthorityProjection = (
            Assert-SporeSporeR05EExecutionAuthority `
                -RepoRoot $repoRoot `
                -Head $sourceCommit `
                -AuthorityPath $executionAuthorityPath `
                -QualificationClosurePath $qualificationClosurePath `
                -EvidenceRoot $durableEvidenceRoot `
                -QualifiedSourcePaths $qualifiedSourcePaths `
                -Expected $executionAuthorityExpected
        )
        if (
            [string]$finalExecutionAuthorityProjection.authority_sha256 -cne
                $executionAuthoritySha256 -or
            [string]$finalExecutionAuthorityProjection.qualification_closure_sha256 -cne
                [string]$executionAuthorityProjection.qualification_closure_sha256 -or
            [string]$finalExecutionAuthorityProjection.source_freeze_commit -cne
                [string]$executionAuthorityProjection.source_freeze_commit
        ) {
            throw "$CampaignId single-use authority binding drifted during qualification"
        }
        if (Test-Path -LiteralPath $outputPath) {
            throw "Refusing to overwrite an existing $CampaignId report: $outputPath"
        }
        if (Test-Path -LiteralPath $outputDirectory) {
            $finalExistingOutput = @(
                Get-ChildItem -LiteralPath $outputDirectory -Force
            )
            if ($finalExistingOutput.Count -ne 0) {
                throw "Refusing a nonempty $CampaignId evidence directory: $outputDirectory"
            }
        }
    }

    # Only now may retained campaign state exist.
    [void][System.IO.Directory]::CreateDirectory($outputDirectory)
    $fullPreflightPath = Join-Path $outputDirectory (
        "full-integrity-preflight.log"
    )
    $entrypointPreflightPath = Join-Path $outputDirectory (
        "$([string]$campaignConfig.slug)-entrypoint-preflight.log"
    )
    Write-Utf8NoBom `
        -Path $fullPreflightPath `
        -Text ($fullPreflight.stdout + $fullPreflight.stderr)
    Write-Utf8NoBom `
        -Path $entrypointPreflightPath `
        -Text ($entrypointPreflight.stdout + $entrypointPreflight.stderr)
    $runnerResultIntegrityPreflightPath = Join-Path $outputDirectory (
        "$([string]$campaignConfig.slug)-result-integrity-preflight.json"
    )
    Write-Utf8NoBom `
        -Path $runnerResultIntegrityPreflightPath `
        -Text (Get-Content -Raw -LiteralPath $runnerProbeReport)
    $exactFiniteSourcePreflightPath = ""
    if ($campaignConfig.Contains("source_gate_test")) {
        $exactFiniteSourcePreflightPath = Join-Path $outputDirectory (
            "$([string]$campaignConfig.slug)-exact-finite-source-preflight.log"
        )
        Write-Utf8NoBom `
            -Path $exactFiniteSourcePreflightPath `
            -Text ($exactFiniteSourceGate.stdout + $exactFiniteSourceGate.stderr)
    }
    $candidateMechanismPreflightPath = ""
    if ([bool]$campaignConfig.paired_candidate_contract) {
        $candidateMechanismPreflightPath = Join-Path $outputDirectory (
            "$([string]$campaignConfig.slug)-mechanism-preflight.log"
        )
        Write-Utf8NoBom `
            -Path $candidateMechanismPreflightPath `
            -Text (
                $candidateMechanismPreflight.stdout +
                $candidateMechanismPreflight.stderr
            )
    }

    $results = [System.Collections.Generic.List[object]]::new()
    $worldOrdinal = 0
    foreach ($cell in $cells) {
        $morphologyId = [string]$cell.morphology_id
        foreach ($seed in $seeds) {
            $worldOrdinal += 1
            Write-Host (
                "$CampaignId world $worldOrdinal/${expectedWorldCount}: " +
                "$morphologyId seed=$seed"
            )
            $cellRoot = Join-Path $outputDirectory (
                "{0}-s{1}" -f $morphologyId, $seed
            )
            [void][System.IO.Directory]::CreateDirectory($cellRoot)
            $engineLogPath = Join-Path $cellRoot "engine.log"
            $workerRoot = Join-Path $tempRoot (
                "worker-{0:D2}" -f $worldOrdinal
            )
            $workerEnvironment = @{}
            if ($physicalAuthorizationRequired) {
                $workerAuthorizationToken = [Guid]::NewGuid().ToString("N")
                $workerAttemptPath = Join-Path $cellRoot "attempt.json"
                $workerAttempt = [ordered]@{
                    schema_version = "sporespore_qsdk_r05e_morphology_attempt_v1"
                    authorization_token = $workerAuthorizationToken
                    campaign_id = $CampaignId
                    gate_id = [string]$campaignConfig.gate_id
                    campaign_role = [string]$campaignConfig.campaign_role
                    generator_index = [int]$cell.generator_index
                    morphology_id = $morphologyId
                    campaign_seed = [int]$seed
                    source_commit = $sourceCommit
                    r05d_design_sha256 = (
                        "sha256:3b75b7609b638470ee947326f71018d082beb4a2c2909e78dae77d3b50250a6c"
                    )
                    preregistration_sha256 = Get-PrefixedSha256 $preregistrationPath
                    execution_authority_path = $executionAuthorityPath
                    execution_authority_sha256 = $executionAuthoritySha256
                    synthetic_authorization_preflight = $false
                    supervisor_physical_authorized = $true
                    maximum_world_attempt_count = 1
                    maximum_world_build_count = 1
                    world_attempt_count_before_worker = 0
                    world_build_count_before_worker = 0
                    same_identity_rerun_permitted = $false
                    operation_lock = $operationLockPublic
                    physical_acceptance_authority = $false
                }
                Write-Utf8NoBom `
                    -Path $workerAttemptPath `
                    -Text ($workerAttempt | ConvertTo-Json -Depth 30 -Compress)
                $workerEnvironment = @{
                    SPORESPORE_QSDK_R05E_ATTEMPT = $workerAttemptPath
                    SPORESPORE_QSDK_R05E_TOKEN = $workerAuthorizationToken
                }
            }
            $execution = Invoke-GodotCaptured `
                -Arguments @(
                    "--headless",
                    "--path", $projectRoot,
                    "--log-file", $engineLogPath,
                    "--script", "res://$campaignTest",
                    "--", "physical", $morphologyId, ([string]$seed)
                ) `
                -WorkerRoot $workerRoot `
                -TimeoutSeconds $CellTimeoutSeconds `
                -AdditionalEnvironment $workerEnvironment
            $transcriptPath = Join-Path $cellRoot "transcript.log"
            $stderrPath = Join-Path $cellRoot "stderr.log"
            Write-Utf8NoBom -Path $transcriptPath -Text $execution.stdout
            Write-Utf8NoBom -Path $stderrPath -Text $execution.stderr

            $receipt = $null
            $receiptError = ""
            try {
                $receipt = Get-ReceiptFromOutput `
                    -OutputText $execution.stdout `
                    -Prefix ([string]$campaignConfig.cell_prefix)
            } catch {
                $receiptError = $_.Exception.Message
            }
            $cellResult = New-R05CellResult `
                -Cell $cell `
                -MorphologyId $morphologyId `
                -Seed $seed `
                -Execution $execution `
                -Receipt $receipt `
                -ReceiptError $receiptError `
                -TranscriptPath $transcriptPath `
                -StderrPath $stderrPath `
                -EngineLogPath $engineLogPath
            $results.Add($cellResult)
        }
    }

    $metrics = Measure-SporeExperimentResults `
        -Results @($results) `
        -ExpectedCount $expectedWorldCount
    $harnessPassCount = [int]$metrics.harness_pass_count
    $walkingPassCount = [int]$metrics.walking_conjunction_pass_count
    $integrityPassCount = [int]$metrics.integrity_pass_count
    $completedCount = [int]$metrics.complete_receipt_count
    $campaignPassed = (
        [bool]$metrics.integrity_and_mechanism_complete -and
        (
            -not [bool]$campaignConfig.walking_required -or
            $walkingPassCount -eq $expectedWorldCount
        )
    )

    $report = [ordered]@{
        schema_version = [string]$campaignConfig.report_schema
        generated_utc = [DateTime]::UtcNow.ToString("o")
        source = [ordered]@{
            commit = $sourceCommit
            remote = "origin/main"
            origin_main_commit = $originMain
            clean = $true
            matches_origin_main = $true
            source_files = $sourceFileReceipts
        }
        runtime_identity_projection = $runtimeIdentityProjection
        preregistration = [ordered]@{
            path = $preregistrationPath
            sha256 = Get-PrefixedSha256 $preregistrationPath
            status = [string]$preregistration.status
            freeze_parent_commit = $freezeParentCommit
        }
        physical_execution_authority = [ordered]@{
            required = $physicalAuthorizationRequired
            path = $executionAuthorityPath
            sha256 = $executionAuthoritySha256
            schema_version = $(if ($physicalAuthorizationRequired) {
                [string]$executionAuthorityDocument.schema_version
            } else { "" })
            status = $(if ($physicalAuthorizationRequired) {
                [string]$executionAuthorityDocument.status
            } else { "not_required" })
            authorization_commit = $(if ($physicalAuthorizationRequired) {
                [string]$executionAuthorityProjection.authorization_commit
            } else { "" })
            authorization_parent_commit = $(if ($physicalAuthorizationRequired) {
                [string]$executionAuthorityProjection.authorization_parent_commit
            } else { "" })
            source_freeze_commit = $(if ($physicalAuthorizationRequired) {
                [string]$executionAuthorityProjection.source_freeze_commit
            } else { "" })
            qualification_closure_path = $(if ($physicalAuthorizationRequired) {
                [string]$executionAuthorityProjection.qualification_closure_path
            } else { "" })
            qualification_closure_sha256 = $(if ($physicalAuthorizationRequired) {
                [string]$executionAuthorityProjection.qualification_closure_sha256
            } else { "" })
            authorization_only_commit = $(if ($physicalAuthorizationRequired) {
                [bool]$executionAuthorityProjection.authorization_only_commit
            } else { $false })
            qualified_source_file_count = $(if ($physicalAuthorizationRequired) {
                [int]$executionAuthorityProjection.qualified_source_file_count
            } else { 0 })
            worker_authorization_preflight_passed = (
                $workerAuthorizationPreflightExact
            )
            mismatched_worker_authorization_token_refused = (
                $workerAuthorizationMismatchedTokenRefused
            )
            worker_authorization_type_mutation_refused = (
                $workerAuthorizationTypeMutationRefused
            )
            direct_physical_worker_bypass_refused = (
                $workerAuthorizationBypassRefused
            )
            operation_lock = $(if ($physicalAuthorizationRequired) {
                $operationLockPublic
            } else { $null })
            physical_acceptance_authority = $false
        }
        campaign_id = $CampaignId
        gate_id = [string]$campaignConfig.gate_id
        campaign_role = [string]$campaignConfig.campaign_role
        selected_candidate_id = [string]$campaignConfig.candidate_id
        selected_policy_id = $expectedPolicyId
        selected_policy_digest = $expectedPolicyDigest
        morphology_ids = @(
            $cells | ForEach-Object { [string]$_.morphology_id }
        )
        generator_indices = $indices
        campaign_seeds = $seeds
        expected_world_count = $expectedWorldCount
        observed_world_count = $results.Count
        complete_receipt_count = $completedCount
        harness_pass_count = $harnessPassCount
        walking_pass_count = $walkingPassCount
        integrity_pass_count = $integrityPassCount
        failure_count = $expectedWorldCount - $harnessPassCount
        metrics = $metrics
        material_profile_id = "godot_jolt_bw5c_mu095_v1"
        authored_friction = 0.95
        full_integrity_preflight = [ordered]@{
            passed = $fullPreflightExact
            scope = "baseline_regression_all_declared_bw13p_policies"
            actual_world_build_count = 0
            transcript_path = $fullPreflightPath
            transcript_sha256 = Get-PrefixedSha256 $fullPreflightPath
            bw12e_exact_zero_control_mismatch_detected = (
                [bool]$fullReceipt.bw12e_exact_zero_control_mismatch_detected
            )
        }
        experiment_result_integrity_preflight = [ordered]@{
            passed = (
                $runnerPreflightExact -and
                $syntheticPerfectExact -and
                $nonzeroCanaryExact
            )
            perfect_all_zero_36_cell_matrix_passed = (
                $syntheticPerfectExact -and $expectedWorldCount -eq 36
            )
            perfect_all_zero_expected_cell_matrix_passed = $syntheticPerfectExact
            expected_synthetic_cell_count = $expectedWorldCount
            perfect_observed_world_count = (
                [int]$syntheticMetrics.observed_world_count
            )
            perfect_failed_production_walking_gate_count = (
                [int]$syntheticMetrics.aggregate_failed_production_walking_gate_count
            )
            perfect_release_timeout_count = (
                [int]$syntheticMetrics.aggregate_release_timeout_count
            )
            nonzero_ordered_dictionary_canary_passed = $nonzeroCanaryExact
            nonzero_canary_failed_production_walking_gate_count = (
                [int]$canaryMetrics.aggregate_failed_production_walking_gate_count
            )
            nonzero_canary_release_timeout_count = (
                [int]$canaryMetrics.aggregate_release_timeout_count
            )
            nonzero_canary_maximum_normalized_lateral_displacement = (
                [double]$canaryMetrics.maximum_normalized_absolute_task_frame_lateral_displacement
            )
            nonzero_canary_aggregate_normalized_lateral_displacement = (
                [double]$canaryMetrics.aggregate_normalized_absolute_task_frame_lateral_displacement
            )
            nonzero_canary_aggregate_cross_track_error_m_s = (
                [double]$canaryMetrics.aggregate_cumulative_absolute_cross_track_error_m_s
            )
            actual_world_build_count = 0
            artifact_path = $runnerResultIntegrityPreflightPath
            artifact_sha256 = (
                Get-PrefixedSha256 $runnerResultIntegrityPreflightPath
            )
        }
        candidate_mechanism_preflight = [ordered]@{
            required = [bool]$campaignConfig.paired_candidate_contract
            passed = $candidateMechanismPreflightExact
            candidate_id = [string]$campaignConfig.candidate_id
            controller_policy_id = $expectedPolicyId
            transcript_path = $candidateMechanismPreflightPath
            transcript_sha256 = $(if (
                -not [string]::IsNullOrWhiteSpace(
                    $candidateMechanismPreflightPath
                )
            ) {
                Get-PrefixedSha256 $candidateMechanismPreflightPath
            } else {
                ""
            })
            actual_world_build_count = 0
        }
        candidate_selector_preflight = [ordered]@{
            required = [bool]$campaignConfig.paired_candidate_contract
            passed = $candidateSelectorPreflightExact
            test_path = $(
                if ([bool]$campaignConfig.paired_candidate_contract) {
                    [string]$campaignConfig.selector_regression_test
                } else {
                    ""
                }
            )
            actual_world_build_count = 0
            physical_acceptance_authority = $false
        }
        results = @($results)
        same_selected_policy_independent_morphology_evidence = (
            $campaignPassed -and
            $sameSelectedPolicyEvidenceOnPass
        )
        development_data_only = (
            $developmentDataOnly
        )
        finite_population_only = $true
        arbitrary_quadruped_coverage = $false
        continuous_full_volume_coverage = $false
        material_robustness = $false
        rough_terrain_robustness = $false
        external_push_recovery = $false
        sensor_noise_or_latency_robustness = $false
        running = $false
        cross_engine_c6 = $false
        completed_engine_neutral_sdk = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
    $report[[string]$campaignConfig.entrypoint_report_field] = [ordered]@{
        passed = $entrypointPreflightExact
        candidate_id = [string]$campaignConfig.candidate_id
        controller_policy_id = $expectedPolicyId
        cell_count = $expectedWorldCount
        exact_candidate_full_authority_start_count = (
            [int]$entrypointReceipt.exact_selected_policy_full_authority_start_count
        )
        exact_candidate_declared_policy_runtime_boundary_count = (
            [int]$entrypointReceipt.exact_declared_policy_runtime_boundary_count
        )
        actual_world_build_count = 0
        transcript_path = $entrypointPreflightPath
        transcript_sha256 = (
            Get-PrefixedSha256 $entrypointPreflightPath
        )
    }
    if ($campaignConfig.Contains("source_gate_test")) {
        $report["exact_finite_morphology_source_preflight"] = [ordered]@{
            passed = $exactFiniteSourceGateExact
            schema_version = [string]$exactFiniteSourceReceipt.schema_version
            official_descriptor_compile_count = (
                [int]$exactFiniteSourceReceipt.official_descriptor_compile_count
            )
            development_ghost_descriptor_compile_count = (
                [int]$exactFiniteSourceReceipt.development_ghost_descriptor_compile_count
            )
            negative_control_count = (
                [int]$exactFiniteSourceReceipt.negative_control_count
            )
            negative_controls_passed = (
                [int]$exactFiniteSourceReceipt.negative_controls_passed
            )
            actual_world_build_count = 0
            solver_step_count = 0
            locomotion_outcome_exposed = $false
            transcript_path = $exactFiniteSourcePreflightPath
            transcript_sha256 = Get-PrefixedSha256 $exactFiniteSourcePreflightPath
            physical_acceptance_authority = $false
        }
    }
    $report[[string]$campaignConfig.pass_field] = $campaignPassed
    Write-Utf8NoBom `
        -Path $outputPath `
        -Text (
            $report |
                ConvertTo-Json -Depth 100 |
                ForEach-Object { $_ + [Environment]::NewLine }
        )
    $reportHash = Get-PrefixedSha256 $outputPath
    Write-Host "REPORT=$outputPath"
    Write-Host "REPORT_SHA256=$reportHash"
    Write-Host (
        "$($CampaignId.Replace('-', '_'))=$campaignPassed " +
        "WALKING=$walkingPassCount/$expectedWorldCount " +
        "INTEGRITY=$integrityPassCount/$expectedWorldCount"
    )
    if (-not $campaignPassed) {
        throw (
            "$CampaignId first complete result did not pass. " +
            "The retained report is final for source $sourceCommit."
        )
    }
} finally {
    if ($null -ne $operationLockReceipt) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $operationLockReceipt
    }
    if ($qualificationInterlockAcquired) {
        try {
            $qualificationInterlock.ReleaseMutex()
        } catch {
        }
    }
    if ($null -ne $qualificationInterlock) {
        $qualificationInterlock.Dispose()
    }
    if (
        (Test-Path -LiteralPath $tempRoot) -and
        $tempRoot.StartsWith(
            $tempBase,
            [System.StringComparison]::OrdinalIgnoreCase
        ) -and
        $tempRoot.Length -gt ($tempBase.Length + 20)
    ) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

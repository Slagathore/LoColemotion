#requires -Version 7.0

<#
Fail-closed, zero-world validation for QSDK-R05E execution authorities.

An execution authority cannot contain the object ID of the commit that contains
the authority itself: changing that field would change the commit again. R05E
therefore uses a parent-bound authorization commit. The authority names its
qualification parent and the earlier source-freeze commit; this validator then
derives the authorization commit from the checked-out HEAD, requires that HEAD
change exactly the authority file, and proves that every qualified source blob
is unchanged from the source freeze.

This file validates authorization metadata and, for the held-out route, the
already-consumed development ghost's immutable repository graph, retained bytes,
route-completion semantics, and narrow claim boundary. It does not construct a
model, open a physics world, read native state, advance a solver, or accept a new
outcome.
#>

function Throw-SporeSporeR05EAuthorityFailure {
    param([Parameter(Mandatory)][string]$Code)
    throw "QSDK_R05E_EXECUTION_AUTHORITY:$Code"
}

function Test-SporeSporeR05ELowerHex {
    param(
        [AllowEmptyString()][string]$Value,
        [Parameter(Mandatory)][int]$Length
    )
    return $Value -cmatch "^[0-9a-f]{$Length}$"
}

function Test-SporeSporeR05EPrefixedSha256 {
    param([AllowEmptyString()][string]$Value)
    return $Value -cmatch '^sha256:[0-9a-f]{64}$'
}

function Test-SporeSporeR05EJsonInteger {
    param($Value)
    return (
        $Value -is [sbyte] -or
        $Value -is [byte] -or
        $Value -is [int16] -or
        $Value -is [uint16] -or
        $Value -is [int32] -or
        $Value -is [uint32] -or
        $Value -is [int64] -or
        $Value -is [uint64]
    )
}

function Assert-SporeSporeR05EExactKeys {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Value,
        [Parameter(Mandatory)][string[]]$ExpectedKeys,
        [Parameter(Mandatory)][string]$Code
    )
    $actual = @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object)
    $expected = @($ExpectedKeys | Sort-Object)
    $difference = @(Compare-Object -CaseSensitive $expected $actual)
    if ($difference.Count -ne 0) {
        Throw-SporeSporeR05EAuthorityFailure $Code
    }
}

function Assert-SporeSporeR05EAuthorityContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Authority,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Qualification,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Expected,
        [Parameter(Mandatory)][object[]]$ExpectedSourceBindings,
        [Parameter(Mandatory)][string]$QualificationRawSha256,
        [Parameter(Mandatory)][string]$QualificationGitBlobOid
    )

    $authorityKeys = @(
        "schema_version",
        "status",
        "campaign_id",
        "gate_id",
        "campaign_role",
        "question_class",
        "ledger_scope",
        "authorization_commit_derived_from_current_head",
        "authorization_parent_commit",
        "source_freeze_commit",
        "qualification_closure_path",
        "qualification_closure_sha256",
        "qualification_closure_git_blob_oid",
        "r05d_design_sha256",
        "preregistration_sha256",
        "expected_morphology_count",
        "expected_world_count",
        "output_report_path",
        "maximum_campaign_attempt_count",
        "maximum_world_attempt_count",
        "maximum_world_build_count",
        "maximum_world_build_count_per_worker",
        "zero_world_qualification_passed",
        "physical_execution_authorized",
        "physical_identity_consumed",
        "same_identity_rerun_permitted",
        "held_out",
        "heldout_access_permitted",
        "development_route_ghost_complete",
        "prerequisite_development_route_ghost_closure_path",
        "prerequisite_development_route_ghost_closure_sha256",
        "prerequisite_development_route_ghost_closure_git_blob_oid",
        "physical_acceptance_authority",
        "release_authority"
    )
    Assert-SporeSporeR05EExactKeys `
        -Value $Authority `
        -ExpectedKeys $authorityKeys `
        -Code "authority_key_set"

    foreach ($field in @(
        "schema_version", "status", "campaign_id", "gate_id", "campaign_role",
        "question_class", "authorization_parent_commit", "source_freeze_commit",
        "qualification_closure_path", "qualification_closure_sha256",
        "qualification_closure_git_blob_oid", "r05d_design_sha256",
        "preregistration_sha256", "output_report_path",
        "prerequisite_development_route_ghost_closure_path",
        "prerequisite_development_route_ghost_closure_sha256",
        "prerequisite_development_route_ghost_closure_git_blob_oid"
    )) {
        if ($Authority[$field] -isnot [string]) {
            Throw-SporeSporeR05EAuthorityFailure "authority_${field}_type"
        }
    }
    foreach ($field in @(
        "authorization_commit_derived_from_current_head",
        "zero_world_qualification_passed",
        "physical_execution_authorized",
        "physical_identity_consumed",
        "same_identity_rerun_permitted",
        "held_out",
        "heldout_access_permitted",
        "development_route_ghost_complete",
        "physical_acceptance_authority",
        "release_authority"
    )) {
        if ($Authority[$field] -isnot [bool]) {
            Throw-SporeSporeR05EAuthorityFailure "authority_${field}_type"
        }
    }
    foreach ($field in @(
        "expected_morphology_count",
        "expected_world_count",
        "maximum_campaign_attempt_count",
        "maximum_world_attempt_count",
        "maximum_world_build_count",
        "maximum_world_build_count_per_worker"
    )) {
        if (-not (Test-SporeSporeR05EJsonInteger $Authority[$field])) {
            Throw-SporeSporeR05EAuthorityFailure "authority_${field}_type"
        }
    }
    if ($Authority.ledger_scope -isnot [System.Collections.IDictionary]) {
        Throw-SporeSporeR05EAuthorityFailure "authority_ledger_scope_type"
    }
    Assert-SporeSporeR05EExactKeys `
        -Value $Authority.ledger_scope `
        -ExpectedKeys @("subsystem", "engine_scope", "authority_mode", "question_class") `
        -Code "authority_ledger_scope_key_set"

    $authorityExact = (
        [string]$Authority.schema_version -ceq [string]$Expected.authority_schema -and
        [string]$Authority.status -ceq "authorized_single_use_unconsumed" -and
        [string]$Authority.campaign_id -ceq [string]$Expected.campaign_id -and
        [string]$Authority.gate_id -ceq [string]$Expected.gate_id -and
        [string]$Authority.campaign_role -ceq [string]$Expected.campaign_role -and
        [string]$Authority.question_class -ceq [string]$Expected.question_class -and
        [string]$Authority.ledger_scope.subsystem -ceq "walking" -and
        [string]$Authority.ledger_scope.engine_scope -ceq "godot_jolt" -and
        [string]$Authority.ledger_scope.authority_mode -ceq
            "single_use_physical_execution_authorization" -and
        [string]$Authority.ledger_scope.question_class -ceq
            [string]$Expected.question_class -and
        [bool]$Authority.authorization_commit_derived_from_current_head -and
        (Test-SporeSporeR05ELowerHex `
            -Value ([string]$Authority.authorization_parent_commit) -Length 40) -and
        [string]$Authority.authorization_parent_commit -ceq
            [string]$Expected.authorization_parent_commit -and
        (Test-SporeSporeR05ELowerHex `
            -Value ([string]$Authority.source_freeze_commit) -Length 40) -and
        [string]$Authority.source_freeze_commit -ceq
            [string]$Expected.source_freeze_commit -and
        [string]$Authority.qualification_closure_path -ceq
            [string]$Expected.qualification_closure_path -and
        [string]$Authority.qualification_closure_sha256 -ceq $QualificationRawSha256 -and
        [string]$Authority.qualification_closure_git_blob_oid -ceq
            $QualificationGitBlobOid -and
        (Test-SporeSporeR05EPrefixedSha256 `
            ([string]$Authority.qualification_closure_sha256)) -and
        (Test-SporeSporeR05ELowerHex `
            -Value ([string]$Authority.qualification_closure_git_blob_oid) -Length 40) -and
        [string]$Authority.r05d_design_sha256 -ceq
            [string]$Expected.r05d_design_sha256 -and
        [string]$Authority.preregistration_sha256 -ceq
            [string]$Expected.preregistration_sha256 -and
        [int64]$Authority.expected_morphology_count -eq
            [int64]$Expected.expected_morphology_count -and
        [int64]$Authority.expected_world_count -eq [int64]$Expected.expected_world_count -and
        [string]$Authority.output_report_path -ceq [string]$Expected.output_report_path -and
        [int64]$Authority.maximum_campaign_attempt_count -eq 1 -and
        [int64]$Authority.maximum_world_attempt_count -eq
            [int64]$Expected.expected_world_count -and
        [int64]$Authority.maximum_world_build_count -eq
            [int64]$Expected.expected_world_count -and
        [int64]$Authority.maximum_world_build_count_per_worker -eq 1 -and
        [bool]$Authority.zero_world_qualification_passed -and
        [bool]$Authority.physical_execution_authorized -and
        -not [bool]$Authority.physical_identity_consumed -and
        -not [bool]$Authority.same_identity_rerun_permitted -and
        [bool]$Authority.held_out -eq [bool]$Expected.held_out -and
        [bool]$Authority.heldout_access_permitted -eq
            [bool]$Expected.heldout_access_permitted -and
        [bool]$Authority.development_route_ghost_complete -eq
            [bool]$Expected.development_route_ghost_complete -and
        -not [bool]$Authority.physical_acceptance_authority -and
        -not [bool]$Authority.release_authority
    )
    if (-not $authorityExact) {
        Throw-SporeSporeR05EAuthorityFailure "authority_content"
    }

    foreach ($value in @(
        [string]$Authority.r05d_design_sha256,
        [string]$Authority.preregistration_sha256
    )) {
        if (-not (Test-SporeSporeR05EPrefixedSha256 $value)) {
            Throw-SporeSporeR05EAuthorityFailure "authority_digest_shape"
        }
    }

    $qualificationKeys = @(
        "schema_version", "status", "gate_id", "campaign_id", "campaign_role",
        "question_class", "ledger_scope", "source", "preregistration",
        "qualification", "runtime", "prerequisite", "decision", "claim_boundary"
    )
    Assert-SporeSporeR05EExactKeys `
        -Value $Qualification `
        -ExpectedKeys $qualificationKeys `
        -Code "qualification_key_set"
    foreach ($field in @(
        "ledger_scope", "source", "preregistration", "qualification",
        "runtime", "prerequisite", "decision", "claim_boundary"
    )) {
        if ($Qualification[$field] -isnot [System.Collections.IDictionary]) {
            Throw-SporeSporeR05EAuthorityFailure "qualification_${field}_type"
        }
    }
    foreach ($field in @(
        "schema_version", "status", "gate_id", "campaign_id", "campaign_role",
        "question_class"
    )) {
        if ($Qualification[$field] -isnot [string]) {
            Throw-SporeSporeR05EAuthorityFailure "qualification_${field}_type"
        }
    }
    Assert-SporeSporeR05EExactKeys `
        -Value $Qualification.ledger_scope `
        -ExpectedKeys @("subsystem", "engine_scope", "authority_mode", "question_class") `
        -Code "qualification_ledger_scope_key_set"
    Assert-SporeSporeR05EExactKeys `
        -Value $Qualification.source `
        -ExpectedKeys @(
            "source_freeze_commit", "branch", "remote",
            "upstream_equal_at_qualification", "live_remote_equal_at_qualification",
            "worktree_clean_at_qualification_start_and_end",
            "qualified_source_file_count", "source_bindings"
        ) `
        -Code "qualification_source_key_set"
    Assert-SporeSporeR05EExactKeys `
        -Value $Qualification.preregistration `
        -ExpectedKeys @("path", "sha256", "r05d_design_sha256") `
        -Code "qualification_preregistration_key_set"
    Assert-SporeSporeR05EExactKeys `
        -Value $Qualification.qualification `
        -ExpectedKeys @(
            "qualification_receipt_path", "qualification_receipt_sha256",
            "qualification_receipt_byte_length", "implementation_audit_path",
            "implementation_audit_sha256", "official_zero_world_qualification_passed",
            "qualification_attempt_count_for_source", "supervisor_preflight_count",
            "serialized_conformance_lock_count",
            "dependency_closure_audit_passed",
            "dependency_gdscript_direct_entry_count",
            "dependency_gdscript_transitive_path_count",
            "dependency_rust_build_path_count",
            "dependency_process_and_audit_path_count",
            "qualified_source_path_count", "qualified_source_path_sha256",
            "dependency_mutation_rejection_count",
            "dependency_all_qualified_paths_lf_checkout_policy",
            "dependency_all_qualified_paths_tracked",
            "dependency_tracked_source_required",
            "runtime_identity_exact_across_supervisors",
            "source_mutation_control_count_per_supervisor",
            "physical_missing_authority_refusal_count", "model_construction_count",
            "world_attempt_count", "world_build_count", "native_readback_count",
            "solver_step_count", "physics_state_modified", "operation_lock_released"
        ) `
        -Code "qualification_evidence_key_set"
    Assert-SporeSporeR05EExactKeys `
        -Value $Qualification.runtime `
        -ExpectedKeys @("schema_version", "identity_sha256", "identity") `
        -Code "qualification_runtime_key_set"
    Assert-SporeSporeR05EExactKeys `
        -Value $Qualification.prerequisite `
        -ExpectedKeys @(
            "development_route_ghost_required",
            "development_route_ghost_complete",
            "development_route_ghost_closure_path",
            "development_route_ghost_closure_sha256",
            "development_route_ghost_closure_git_blob_oid"
        ) `
        -Code "qualification_prerequisite_key_set"
    Assert-SporeSporeR05EExactKeys `
        -Value $Qualification.decision `
        -ExpectedKeys @(
            "qualification_complete", "execution_authority_creation_permitted",
            "physical_execution_authorized", "same_identity_rerun_permitted",
            "held_out"
        ) `
        -Code "qualification_decision_key_set"
    Assert-SporeSporeR05EExactKeys `
        -Value $Qualification.claim_boundary `
        -ExpectedKeys @(
            "physical_attempted", "locomotion_outcome_exposed",
            "same_selected_policy_independent_morphology_evidence",
            "sdk1_milestone_advanced", "physical_acceptance_authority",
            "release_authority"
        ) `
        -Code "qualification_claim_key_set"

    foreach ($field in @(
        "subsystem", "engine_scope", "authority_mode", "question_class"
    )) {
        if ($Qualification.ledger_scope[$field] -isnot [string]) {
            Throw-SporeSporeR05EAuthorityFailure "qualification_ledger_${field}_type"
        }
    }
    foreach ($field in @("source_freeze_commit", "branch", "remote")) {
        if ($Qualification.source[$field] -isnot [string]) {
            Throw-SporeSporeR05EAuthorityFailure "qualification_source_${field}_type"
        }
    }
    foreach ($field in @(
        "upstream_equal_at_qualification", "live_remote_equal_at_qualification",
        "worktree_clean_at_qualification_start_and_end"
    )) {
        if ($Qualification.source[$field] -isnot [bool]) {
            Throw-SporeSporeR05EAuthorityFailure "qualification_source_${field}_type"
        }
    }
    if (
        -not (Test-SporeSporeR05EJsonInteger `
            $Qualification.source.qualified_source_file_count) -or
        $Qualification.source.source_bindings -isnot [System.Collections.IList]
    ) {
        Throw-SporeSporeR05EAuthorityFailure "qualification_source_manifest_type"
    }
    foreach ($field in @("path", "sha256", "r05d_design_sha256")) {
        if ($Qualification.preregistration[$field] -isnot [string]) {
            Throw-SporeSporeR05EAuthorityFailure "qualification_preregistration_${field}_type"
        }
    }
    foreach ($field in @(
        "qualification_complete", "execution_authority_creation_permitted",
        "physical_execution_authorized", "same_identity_rerun_permitted", "held_out"
    )) {
        if ($Qualification.decision[$field] -isnot [bool]) {
            Throw-SporeSporeR05EAuthorityFailure "qualification_decision_${field}_type"
        }
    }
    foreach ($field in @(
        "physical_attempted", "locomotion_outcome_exposed",
        "same_selected_policy_independent_morphology_evidence",
        "sdk1_milestone_advanced", "physical_acceptance_authority",
        "release_authority"
    )) {
        if ($Qualification.claim_boundary[$field] -isnot [bool]) {
            Throw-SporeSporeR05EAuthorityFailure "qualification_claim_${field}_type"
        }
    }

    $qualificationEvidence = $Qualification.qualification
    foreach ($field in @(
        "official_zero_world_qualification_passed", "physics_state_modified",
        "operation_lock_released", "dependency_closure_audit_passed",
        "dependency_all_qualified_paths_lf_checkout_policy",
        "dependency_all_qualified_paths_tracked",
        "dependency_tracked_source_required",
        "runtime_identity_exact_across_supervisors"
    )) {
        if ($qualificationEvidence[$field] -isnot [bool]) {
            Throw-SporeSporeR05EAuthorityFailure "qualification_${field}_type"
        }
    }
    foreach ($field in @(
        "qualification_receipt_byte_length", "qualification_attempt_count_for_source",
        "supervisor_preflight_count", "serialized_conformance_lock_count",
        "dependency_gdscript_direct_entry_count",
        "dependency_gdscript_transitive_path_count",
        "dependency_rust_build_path_count",
        "dependency_process_and_audit_path_count", "qualified_source_path_count",
        "dependency_mutation_rejection_count",
        "source_mutation_control_count_per_supervisor",
        "physical_missing_authority_refusal_count", "model_construction_count",
        "world_attempt_count", "world_build_count", "native_readback_count",
        "solver_step_count"
    )) {
        if (-not (Test-SporeSporeR05EJsonInteger $qualificationEvidence[$field])) {
            Throw-SporeSporeR05EAuthorityFailure "qualification_${field}_type"
        }
    }
    foreach ($field in @(
        "qualification_receipt_path", "qualification_receipt_sha256",
        "implementation_audit_path", "implementation_audit_sha256",
        "qualified_source_path_sha256"
    )) {
        if ($qualificationEvidence[$field] -isnot [string]) {
            Throw-SporeSporeR05EAuthorityFailure "qualification_${field}_type"
        }
    }

    $runtime = $Qualification.runtime
    if (
        $runtime.schema_version -isnot [string] -or
        $runtime.identity_sha256 -isnot [string] -or
        $runtime.identity -isnot [System.Collections.IDictionary] -or
        $Expected.runtime_identity_projection -isnot [System.Collections.IDictionary] -or
        $Expected.runtime_identity_projection.identity -isnot
            [System.Collections.IDictionary]
    ) {
        Throw-SporeSporeR05EAuthorityFailure "qualification_runtime_type"
    }
    $runtimeCanonical = ConvertTo-SporeSporeR05ECanonicalJson `
        -Value $runtime.identity
    $expectedRuntimeCanonical = ConvertTo-SporeSporeR05ECanonicalJson `
        -Value $Expected.runtime_identity_projection.identity
    if (
        [string]$runtime.schema_version -cne
            "sporespore_qsdk_r05e_runtime_identity_projection_v1" -or
        [string]$runtime.schema_version -cne
            [string]$Expected.runtime_identity_projection.schema_version -or
        [string]$runtime.identity_sha256 -cne
            [string]$Expected.runtime_identity_projection.identity_sha256 -or
        [string]$runtime.identity_sha256 -cne
            (Get-SporeSporeR05ETextSha256 -Text $runtimeCanonical) -or
        $runtimeCanonical -cne $expectedRuntimeCanonical
    ) {
        Throw-SporeSporeR05EAuthorityFailure "qualification_runtime_content"
    }

    $qualificationExact = (
        [string]$Qualification.schema_version -ceq
            [string]$Expected.qualification_schema -and
        [string]$Qualification.status -ceq
            "closed_complete_zero_world_qualification_physics_still_sealed" -and
        [string]$Qualification.gate_id -ceq [string]$Expected.gate_id -and
        [string]$Qualification.campaign_id -ceq [string]$Expected.campaign_id -and
        [string]$Qualification.campaign_role -ceq [string]$Expected.campaign_role -and
        [string]$Qualification.question_class -ceq [string]$Expected.question_class -and
        [string]$Qualification.ledger_scope.subsystem -ceq "walking" -and
        [string]$Qualification.ledger_scope.engine_scope -ceq "godot_jolt" -and
        [string]$Qualification.ledger_scope.authority_mode -ceq
            "closed_content_addressed_zero_world_qualification" -and
        [string]$Qualification.ledger_scope.question_class -ceq
            [string]$Expected.question_class -and
        [string]$Qualification.source.source_freeze_commit -ceq
            [string]$Expected.source_freeze_commit -and
        [string]$Qualification.source.branch -ceq "main" -and
        [string]$Qualification.source.remote -ceq [string]$Expected.remote -and
        [bool]$Qualification.source.upstream_equal_at_qualification -and
        [bool]$Qualification.source.live_remote_equal_at_qualification -and
        [bool]$Qualification.source.worktree_clean_at_qualification_start_and_end -and
        [int64]$Qualification.source.qualified_source_file_count -eq
            [int64]$ExpectedSourceBindings.Count -and
        [string]$Qualification.preregistration.path -ceq
            [string]$Expected.preregistration_path -and
        [string]$Qualification.preregistration.sha256 -ceq
            [string]$Expected.preregistration_sha256 -and
        [string]$Qualification.preregistration.r05d_design_sha256 -ceq
            [string]$Expected.r05d_design_sha256 -and
        (Test-SporeSporeR05EPrefixedSha256 `
            ([string]$qualificationEvidence.qualification_receipt_sha256)) -and
        [int64]$qualificationEvidence.qualification_receipt_byte_length -gt 0 -and
        [string]$qualificationEvidence.implementation_audit_path -ceq
            "sdk/conformance/qsdk_r05e_zero_world_implementation.py" -and
        [string]$qualificationEvidence.implementation_audit_sha256 -ceq
            [string]$Expected.implementation_audit_sha256 -and
        [bool]$qualificationEvidence.official_zero_world_qualification_passed -and
        [int64]$qualificationEvidence.qualification_attempt_count_for_source -eq 1 -and
        [int64]$qualificationEvidence.supervisor_preflight_count -eq 2 -and
        [int64]$qualificationEvidence.serialized_conformance_lock_count -eq 2 -and
        [bool]$qualificationEvidence.dependency_closure_audit_passed -and
        [int64]$qualificationEvidence.dependency_gdscript_direct_entry_count -eq
            [int64]$Expected.dependency_gdscript_direct_entry_count -and
        [int64]$qualificationEvidence.dependency_gdscript_transitive_path_count -eq
            [int64]$Expected.dependency_gdscript_transitive_path_count -and
        [int64]$qualificationEvidence.dependency_rust_build_path_count -eq
            [int64]$Expected.dependency_rust_build_path_count -and
        [int64]$qualificationEvidence.dependency_process_and_audit_path_count -eq
            [int64]$Expected.dependency_process_and_audit_path_count -and
        [int64]$qualificationEvidence.qualified_source_path_count -eq
            [int64]$ExpectedSourceBindings.Count -and
        [string]$qualificationEvidence.qualified_source_path_sha256 -ceq
            [string]$Expected.qualified_source_path_sha256 -and
        [int64]$qualificationEvidence.dependency_mutation_rejection_count -eq 4 -and
        [bool]$qualificationEvidence.dependency_all_qualified_paths_lf_checkout_policy -and
        [bool]$qualificationEvidence.dependency_all_qualified_paths_tracked -and
        [bool]$qualificationEvidence.dependency_tracked_source_required -and
        [bool]$qualificationEvidence.runtime_identity_exact_across_supervisors -and
        [int64]$qualificationEvidence.source_mutation_control_count_per_supervisor -eq 32 -and
        [int64]$qualificationEvidence.physical_missing_authority_refusal_count -eq 2 -and
        [int64]$qualificationEvidence.model_construction_count -eq 0 -and
        [int64]$qualificationEvidence.world_attempt_count -eq 0 -and
        [int64]$qualificationEvidence.world_build_count -eq 0 -and
        [int64]$qualificationEvidence.native_readback_count -eq 0 -and
        [int64]$qualificationEvidence.solver_step_count -eq 0 -and
        -not [bool]$qualificationEvidence.physics_state_modified -and
        [bool]$qualificationEvidence.operation_lock_released -and
        [bool]$Qualification.decision.qualification_complete -and
        [bool]$Qualification.decision.execution_authority_creation_permitted -and
        -not [bool]$Qualification.decision.physical_execution_authorized -and
        -not [bool]$Qualification.decision.same_identity_rerun_permitted -and
        [bool]$Qualification.decision.held_out -eq [bool]$Expected.held_out -and
        -not [bool]$Qualification.claim_boundary.physical_attempted -and
        -not [bool]$Qualification.claim_boundary.locomotion_outcome_exposed -and
        -not [bool]$Qualification.claim_boundary.same_selected_policy_independent_morphology_evidence -and
        -not [bool]$Qualification.claim_boundary.sdk1_milestone_advanced -and
        -not [bool]$Qualification.claim_boundary.physical_acceptance_authority -and
        -not [bool]$Qualification.claim_boundary.release_authority
    )
    if (-not $qualificationExact) {
        Throw-SporeSporeR05EAuthorityFailure "qualification_content"
    }

    $sourceBindings = @($Qualification.source.source_bindings)
    if ($sourceBindings.Count -ne $ExpectedSourceBindings.Count) {
        Throw-SporeSporeR05EAuthorityFailure "qualification_source_binding_count"
    }
    for ($index = 0; $index -lt $ExpectedSourceBindings.Count; $index += 1) {
        $actualBinding = $sourceBindings[$index]
        $expectedBinding = $ExpectedSourceBindings[$index]
        if ($actualBinding -isnot [System.Collections.IDictionary]) {
            Throw-SporeSporeR05EAuthorityFailure "qualification_source_binding_type"
        }
        Assert-SporeSporeR05EExactKeys `
            -Value $actualBinding `
            -ExpectedKeys @("path", "git_blob_oid", "raw_sha256", "byte_length") `
            -Code "qualification_source_binding_key_set"
        if (
            $actualBinding.path -isnot [string] -or
            $actualBinding.git_blob_oid -isnot [string] -or
            $actualBinding.raw_sha256 -isnot [string] -or
            -not (Test-SporeSporeR05EJsonInteger $actualBinding.byte_length) -or
            [string]$actualBinding.path -cne [string]$expectedBinding.path -or
            [string]$actualBinding.git_blob_oid -cne
                [string]$expectedBinding.git_blob_oid -or
            [string]$actualBinding.raw_sha256 -cne [string]$expectedBinding.raw_sha256 -or
            [int64]$actualBinding.byte_length -ne [int64]$expectedBinding.byte_length
        ) {
            Throw-SporeSporeR05EAuthorityFailure "qualification_source_binding_content"
        }
    }

    $prerequisite = $Qualification.prerequisite
    foreach ($field in @(
        "development_route_ghost_required", "development_route_ghost_complete"
    )) {
        if ($prerequisite[$field] -isnot [bool]) {
            Throw-SporeSporeR05EAuthorityFailure "qualification_prerequisite_${field}_type"
        }
    }
    foreach ($field in @(
        "development_route_ghost_closure_path",
        "development_route_ghost_closure_sha256",
        "development_route_ghost_closure_git_blob_oid"
    )) {
        if ($prerequisite[$field] -isnot [string]) {
            Throw-SporeSporeR05EAuthorityFailure "qualification_prerequisite_${field}_type"
        }
    }
    $prerequisiteExact = (
        [bool]$prerequisite.development_route_ghost_required -eq
            [bool]$Expected.development_route_ghost_required -and
        [bool]$prerequisite.development_route_ghost_complete -eq
            [bool]$Expected.development_route_ghost_complete -and
        [string]$prerequisite.development_route_ghost_closure_path -ceq
            [string]$Expected.development_route_ghost_closure_path -and
        [string]$Authority.prerequisite_development_route_ghost_closure_path -ceq
            [string]$prerequisite.development_route_ghost_closure_path -and
        [string]$Authority.prerequisite_development_route_ghost_closure_sha256 -ceq
            [string]$prerequisite.development_route_ghost_closure_sha256 -and
        [string]$Authority.prerequisite_development_route_ghost_closure_git_blob_oid -ceq
            [string]$prerequisite.development_route_ghost_closure_git_blob_oid
    )
    if ([bool]$Expected.development_route_ghost_complete) {
        $prerequisiteExact = (
            $prerequisiteExact -and
            (Test-SporeSporeR05EPrefixedSha256 `
                ([string]$prerequisite.development_route_ghost_closure_sha256)) -and
            (Test-SporeSporeR05ELowerHex `
                -Value ([string]$prerequisite.development_route_ghost_closure_git_blob_oid) `
                -Length 40)
        )
    } else {
        $prerequisiteExact = (
            $prerequisiteExact -and
            [string]::IsNullOrEmpty(
                [string]$prerequisite.development_route_ghost_closure_sha256
            ) -and
            [string]::IsNullOrEmpty(
                [string]$prerequisite.development_route_ghost_closure_git_blob_oid
            )
        )
    }
    if (-not $prerequisiteExact) {
        Throw-SporeSporeR05EAuthorityFailure "prerequisite_content"
    }

    return [ordered]@{
        authority = $Authority
        qualification = $Qualification
        source_freeze_commit = [string]$Authority.source_freeze_commit
        authorization_parent_commit = [string]$Authority.authorization_parent_commit
        qualification_closure_sha256 = $QualificationRawSha256
        qualification_closure_git_blob_oid = $QualificationGitBlobOid
        qualified_source_file_count = $ExpectedSourceBindings.Count
        physical_execution_authorized = $true
        physical_acceptance_authority = $false
        release_authority = $false
    }
}

function Invoke-SporeSporeR05EGit {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Code,
        [switch]$AllowEmpty
    )
    $lines = @(& git -C $RepoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        Throw-SporeSporeR05EAuthorityFailure $Code
    }
    $value = (($lines | ForEach-Object { [string]$_ }) -join "`n").Trim()
    if (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($value)) {
        Throw-SporeSporeR05EAuthorityFailure $Code
    }
    return $value
}

function Get-SporeSporeR05ERawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:$((Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant())"
}

function Get-SporeSporeR05ETextSha256 {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    $digest = [Security.Cryptography.SHA256]::HashData($bytes)
    return "sha256:$([Convert]::ToHexString($digest).ToLowerInvariant())"
}

function ConvertTo-SporeSporeR05ECanonicalValue {
    param([Parameter(Mandatory)]$Value)
    if ($Value -is [System.Collections.IDictionary]) {
        $keys = [string[]]@($Value.Keys | ForEach-Object { [string]$_ })
        [Array]::Sort($keys, [StringComparer]::Ordinal)
        $ordered = [ordered]@{}
        foreach ($key in $keys) {
            $ordered[$key] = ConvertTo-SporeSporeR05ECanonicalValue `
                -Value $Value[$key]
        }
        return $ordered
    }
    if (
        $Value -is [System.Collections.IList] -and
        $Value -isnot [string]
    ) {
        $items = @(
            foreach ($item in @($Value)) {
                ConvertTo-SporeSporeR05ECanonicalValue -Value $item
            }
        )
        return ,$items
    }
    return $Value
}

function ConvertTo-SporeSporeR05ECanonicalJson {
    param([Parameter(Mandatory)]$Value)
    $canonical = ConvertTo-SporeSporeR05ECanonicalValue -Value $Value
    return $canonical | ConvertTo-Json -Compress -Depth 100
}

function Assert-SporeSporeR05EBooleanFields {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Value,
        [Parameter(Mandatory)][string[]]$Fields,
        [Parameter(Mandatory)][string]$Code
    )
    foreach ($field in $Fields) {
        if ($Value[$field] -isnot [bool]) {
            Throw-SporeSporeR05EAuthorityFailure "${Code}_${field}_type"
        }
    }
}

function Assert-SporeSporeR05EIntegerFields {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Value,
        [Parameter(Mandatory)][string[]]$Fields,
        [Parameter(Mandatory)][string]$Code
    )
    foreach ($field in $Fields) {
        if (-not (Test-SporeSporeR05EJsonInteger $Value[$field])) {
            Throw-SporeSporeR05EAuthorityFailure "${Code}_${field}_type"
        }
    }
}

function Assert-SporeSporeR05EStringFields {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Value,
        [Parameter(Mandatory)][string[]]$Fields,
        [Parameter(Mandatory)][string]$Code
    )
    foreach ($field in $Fields) {
        if ($Value[$field] -isnot [string]) {
            Throw-SporeSporeR05EAuthorityFailure "${Code}_${field}_type"
        }
    }
}

function Get-SporeSporeR05ERetainedFileArtifacts {
    param([Parameter(Mandatory)][string]$Root)
    $absoluteRoot = [IO.Path]::GetFullPath($Root).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    if (-not (Test-Path -LiteralPath $absoluteRoot -PathType Container)) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_evidence_root_missing"
    }
    $files = @(Get-ChildItem -LiteralPath $absoluteRoot -File -Recurse -Force)
    $relativePaths = [string[]]@(
        foreach ($file in $files) {
            if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                Throw-SporeSporeR05EAuthorityFailure `
                    "development_ghost_evidence_reparse_point"
            }
            [IO.Path]::GetRelativePath($absoluteRoot, $file.FullName).Replace("\", "/")
        }
    )
    [Array]::Sort($relativePaths, [StringComparer]::Ordinal)
    return @(
        foreach ($relative in $relativePaths) {
            if (
                [string]::IsNullOrWhiteSpace($relative) -or
                $relative.StartsWith("/", [StringComparison]::Ordinal) -or
                $relative.Split('/') -contains ".."
            ) {
                Throw-SporeSporeR05EAuthorityFailure `
                    "development_ghost_evidence_relative_path"
            }
            $absolute = [IO.Path]::GetFullPath((Join-Path $absoluteRoot $relative))
            [ordered]@{
                path = $relative
                byte_length = [int64](Get-Item -LiteralPath $absolute).Length
                raw_sha256 = Get-SporeSporeR05ERawSha256 -Path $absolute
            }
        }
    )
}

function Assert-SporeSporeR05EDevelopmentGhostClosureContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Closure,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Report,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Attempt,
        [Parameter(Mandatory)][object[]]$CurrentArtifacts
    )

    Assert-SporeSporeR05EExactKeys -Value $Closure -ExpectedKeys @(
        "schema_version", "status", "gate_id", "campaign_id", "campaign_role",
        "question_class", "closed_utc", "ledger_scope", "source_and_authority",
        "nonconsuming_pre_authority_refusal", "physical_attempt",
        "retained_evidence", "result", "decision", "claim_boundary", "sdk_status"
    ) -Code "development_ghost_closure_key_set"
    foreach ($field in @(
        "ledger_scope", "source_and_authority", "nonconsuming_pre_authority_refusal",
        "physical_attempt", "retained_evidence", "result", "decision",
        "claim_boundary", "sdk_status"
    )) {
        if ($Closure[$field] -isnot [System.Collections.IDictionary]) {
            Throw-SporeSporeR05EAuthorityFailure `
                "development_ghost_closure_${field}_type"
        }
    }
    Assert-SporeSporeR05EStringFields -Value $Closure -Fields @(
        "schema_version", "status", "gate_id", "campaign_id", "campaign_role",
        "question_class"
    ) -Code "development_ghost_closure"
    Assert-SporeSporeR05EExactKeys -Value $Closure.ledger_scope -ExpectedKeys @(
        "subsystem", "engine_scope", "authority_mode", "question_class"
    ) -Code "development_ghost_ledger_key_set"

    $source = $Closure.source_and_authority
    Assert-SporeSporeR05EExactKeys -Value $source -ExpectedKeys @(
        "source_freeze_commit", "qualification_commit", "authorization_commit",
        "branch", "remote", "head_origin_main_live_equal_at_physical_launch",
        "worktree_clean_at_physical_launch_and_close", "qualified_source_file_count",
        "qualification_closure", "execution_authority", "preregistration",
        "r05d_design_sha256", "runtime_identity_sha256"
    ) -Code "development_ghost_source_key_set"
    foreach ($field in @("qualification_closure", "execution_authority", "preregistration")) {
        if ($source[$field] -isnot [System.Collections.IDictionary]) {
            Throw-SporeSporeR05EAuthorityFailure "development_ghost_source_${field}_type"
        }
    }
    Assert-SporeSporeR05EExactKeys -Value $source.qualification_closure -ExpectedKeys @(
        "path", "raw_sha256", "git_blob_oid"
    ) -Code "development_ghost_qualification_binding_key_set"
    Assert-SporeSporeR05EExactKeys -Value $source.execution_authority -ExpectedKeys @(
        "path", "raw_sha256", "byte_length", "git_blob_oid",
        "immutable_document_status", "authority_document_is_not_rewritten_after_consumption"
    ) -Code "development_ghost_authority_binding_key_set"
    Assert-SporeSporeR05EExactKeys -Value $source.preregistration -ExpectedKeys @(
        "path", "raw_sha256", "git_blob_oid"
    ) -Code "development_ghost_preregistration_binding_key_set"
    Assert-SporeSporeR05EStringFields -Value $source -Fields @(
        "source_freeze_commit", "qualification_commit", "authorization_commit",
        "branch", "remote", "r05d_design_sha256", "runtime_identity_sha256"
    ) -Code "development_ghost_source"
    Assert-SporeSporeR05EBooleanFields -Value $source -Fields @(
        "head_origin_main_live_equal_at_physical_launch",
        "worktree_clean_at_physical_launch_and_close"
    ) -Code "development_ghost_source"
    Assert-SporeSporeR05EIntegerFields -Value $source -Fields @(
        "qualified_source_file_count"
    ) -Code "development_ghost_source"
    Assert-SporeSporeR05EBooleanFields -Value $source.execution_authority -Fields @(
        "authority_document_is_not_rewritten_after_consumption"
    ) -Code "development_ghost_authority_binding"
    Assert-SporeSporeR05EIntegerFields -Value $source.execution_authority -Fields @(
        "byte_length"
    ) -Code "development_ghost_authority_binding"

    $refusal = $Closure.nonconsuming_pre_authority_refusal
    Assert-SporeSporeR05EExactKeys -Value $refusal -ExpectedKeys @(
        "observed", "refusal_count", "failure_code", "phase",
        "qualified_powershell_path", "refused_invocation_powershell_path",
        "powershell_raw_sha256_equal", "powershell_raw_sha256",
        "powershell_byte_length_equal", "powershell_byte_length",
        "powershell_version_equal", "powershell_version",
        "qualified_runtime_identity_sha256", "refused_runtime_identity_sha256",
        "sole_difference_was_windows_path_case", "output_directory_created",
        "attempt_receipt_created", "model_construction_count", "world_attempt_count",
        "world_build_count", "native_readback_count", "solver_step_count",
        "physics_state_modified", "physical_identity_consumed",
        "separate_raw_refusal_log_retained", "exact_refusal_retained_by_this_closure"
    ) -Code "development_ghost_refusal_key_set"
    Assert-SporeSporeR05EStringFields -Value $refusal -Fields @(
        "failure_code", "phase", "qualified_powershell_path",
        "refused_invocation_powershell_path", "powershell_raw_sha256",
        "powershell_version", "qualified_runtime_identity_sha256",
        "refused_runtime_identity_sha256"
    ) -Code "development_ghost_refusal"
    Assert-SporeSporeR05EBooleanFields -Value $refusal -Fields @(
        "observed", "powershell_raw_sha256_equal", "powershell_byte_length_equal",
        "powershell_version_equal", "sole_difference_was_windows_path_case",
        "output_directory_created", "attempt_receipt_created", "physics_state_modified",
        "physical_identity_consumed", "separate_raw_refusal_log_retained",
        "exact_refusal_retained_by_this_closure"
    ) -Code "development_ghost_refusal"
    Assert-SporeSporeR05EIntegerFields -Value $refusal -Fields @(
        "refusal_count", "powershell_byte_length", "model_construction_count",
        "world_attempt_count", "world_build_count", "native_readback_count",
        "solver_step_count"
    ) -Code "development_ghost_refusal"

    $physical = $Closure.physical_attempt
    Assert-SporeSporeR05EExactKeys -Value $physical -ExpectedKeys @(
        "attempt_count_for_exact_source_and_gate", "physical_identity_consumed",
        "first_complete_result_is_final", "same_identity_rerun_permitted",
        "evidence_root", "report_path", "report_raw_sha256", "report_byte_length",
        "report_generated_utc", "attempt_path", "attempt_raw_sha256",
        "attempt_byte_length", "expected_world_count", "observed_world_count",
        "complete_receipt_count", "world_attempt_count", "world_build_count",
        "process_exit_code", "process_timed_out", "process_tree_killed",
        "cell_duration_seconds", "physics_state_modified", "engine", "morphology"
    ) -Code "development_ghost_physical_key_set"
    foreach ($field in @("engine", "morphology")) {
        if ($physical[$field] -isnot [System.Collections.IDictionary]) {
            Throw-SporeSporeR05EAuthorityFailure "development_ghost_physical_${field}_type"
        }
    }
    Assert-SporeSporeR05EExactKeys -Value $physical.engine -ExpectedKeys @(
        "adapter_id", "physics_engine", "physics_hz", "solver_velocity_steps",
        "solver_position_steps"
    ) -Code "development_ghost_engine_key_set"
    Assert-SporeSporeR05EExactKeys -Value $physical.morphology -ExpectedKeys @(
        "generator_index", "morphology_id", "generator_receipt_sha256",
        "proportion_spec_sha256", "campaign_seed"
    ) -Code "development_ghost_morphology_key_set"
    Assert-SporeSporeR05EStringFields -Value $physical -Fields @(
        "evidence_root", "report_path", "report_raw_sha256", "attempt_path",
        "attempt_raw_sha256"
    ) -Code "development_ghost_physical"
    Assert-SporeSporeR05EBooleanFields -Value $physical -Fields @(
        "physical_identity_consumed", "first_complete_result_is_final",
        "same_identity_rerun_permitted", "process_timed_out", "process_tree_killed",
        "physics_state_modified"
    ) -Code "development_ghost_physical"
    Assert-SporeSporeR05EIntegerFields -Value $physical -Fields @(
        "attempt_count_for_exact_source_and_gate", "report_byte_length",
        "attempt_byte_length", "expected_world_count", "observed_world_count",
        "complete_receipt_count", "world_attempt_count", "world_build_count",
        "process_exit_code"
    ) -Code "development_ghost_physical"
    Assert-SporeSporeR05EIntegerFields -Value $physical.engine -Fields @(
        "physics_hz", "solver_velocity_steps", "solver_position_steps"
    ) -Code "development_ghost_engine"
    Assert-SporeSporeR05EIntegerFields -Value $physical.morphology -Fields @(
        "generator_index", "campaign_seed"
    ) -Code "development_ghost_morphology"

    $retained = $Closure.retained_evidence
    Assert-SporeSporeR05EExactKeys -Value $retained -ExpectedKeys @(
        "tree_schema_version", "file_count", "total_byte_length",
        "manifest_canonical_byte_length", "manifest_canonical_sha256", "artifacts"
    ) -Code "development_ghost_retained_key_set"
    if ($retained.artifacts -isnot [System.Collections.IList]) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_artifacts_type"
    }
    Assert-SporeSporeR05EIntegerFields -Value $retained -Fields @(
        "file_count", "total_byte_length", "manifest_canonical_byte_length"
    ) -Code "development_ghost_retained"
    $recordedArtifacts = @($retained.artifacts)
    foreach ($artifact in $recordedArtifacts) {
        if ($artifact -isnot [System.Collections.IDictionary]) {
            Throw-SporeSporeR05EAuthorityFailure "development_ghost_artifact_type"
        }
        Assert-SporeSporeR05EExactKeys -Value $artifact -ExpectedKeys @(
            "path", "byte_length", "raw_sha256"
        ) -Code "development_ghost_artifact_key_set"
        Assert-SporeSporeR05EStringFields -Value $artifact -Fields @(
            "path", "raw_sha256"
        ) -Code "development_ghost_artifact"
        Assert-SporeSporeR05EIntegerFields -Value $artifact -Fields @(
            "byte_length"
        ) -Code "development_ghost_artifact"
    }
    $currentManifest = [ordered]@{
        schema_version = "sporespore_retained_file_tree_manifest_v1"
        artifacts = @($CurrentArtifacts)
    }
    $recordedManifest = [ordered]@{
        schema_version = [string]$retained.tree_schema_version
        artifacts = $recordedArtifacts
    }
    $currentManifestJson = ConvertTo-SporeSporeR05ECanonicalJson -Value $currentManifest
    $recordedManifestJson = ConvertTo-SporeSporeR05ECanonicalJson -Value $recordedManifest
    $currentTotalBytes = [int64]0
    foreach ($artifact in @($CurrentArtifacts)) {
        $currentTotalBytes += [int64]$artifact.byte_length
    }
    if (
        $currentManifestJson -cne $recordedManifestJson -or
        @($CurrentArtifacts).Count -ne 9 -or
        [int64]$retained.file_count -ne 9 -or
        $currentTotalBytes -ne 437196 -or
        [int64]$retained.total_byte_length -ne 437196 -or
        [Text.UTF8Encoding]::new($false).GetByteCount($currentManifestJson) -ne 1665 -or
        [int64]$retained.manifest_canonical_byte_length -ne 1665 -or
        (Get-SporeSporeR05ETextSha256 -Text $currentManifestJson) -cne
            "sha256:f21fedd25851ea8b5517b3a2ee3db34a63466b6cdfe564ba54a37128aaf0deea" -or
        [string]$retained.manifest_canonical_sha256 -cne
            "sha256:f21fedd25851ea8b5517b3a2ee3db34a63466b6cdfe564ba54a37128aaf0deea"
    ) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_retained_evidence"
    }

    $result = $Closure.result
    Assert-SporeSporeR05EExactKeys -Value $result -ExpectedKeys @(
        "classification", "route_complete", "behavior_success_required",
        "walking_observed", "harness_passed", "common_execution_integrity",
        "mechanism_gate_passed", "combined_application_gate_passed",
        "assertion_pass_count", "assertion_failure_count", "walking_gate_receipt_count",
        "walking_gate_failure_count", "failed_production_walking_gate_count",
        "release_timeout_count", "sdk_step_count", "native_motor_write_count",
        "native_motor_write_count_per_sdk_step", "validated_balanced_wave_command_count",
        "direct_body_write_count", "legacy_post_settle_motor_write_count",
        "legacy_evidence_motor_write_count", "sdk_mismatch_count",
        "sdk_safe_disable_count", "sdk_safe_no_actuation_count",
        "evidence_task_frame_forward_displacement_m",
        "final_task_frame_forward_displacement_m",
        "final_task_frame_lateral_displacement_m", "minimum_torso_height_m",
        "maximum_tilt_rad", "maximum_anchor_error_m", "maximum_hinge_axis_error_rad",
        "one_continuous_world", "no_world_reset", "terminal_four_contact_recovery"
    ) -Code "development_ghost_result_key_set"
    Assert-SporeSporeR05EBooleanFields -Value $result -Fields @(
        "route_complete", "behavior_success_required", "walking_observed",
        "harness_passed", "common_execution_integrity", "mechanism_gate_passed",
        "combined_application_gate_passed", "one_continuous_world", "no_world_reset",
        "terminal_four_contact_recovery"
    ) -Code "development_ghost_result"
    Assert-SporeSporeR05EIntegerFields -Value $result -Fields @(
        "assertion_pass_count", "assertion_failure_count", "walking_gate_receipt_count",
        "walking_gate_failure_count", "failed_production_walking_gate_count",
        "release_timeout_count", "sdk_step_count", "native_motor_write_count",
        "native_motor_write_count_per_sdk_step", "validated_balanced_wave_command_count",
        "direct_body_write_count", "legacy_post_settle_motor_write_count",
        "legacy_evidence_motor_write_count", "sdk_mismatch_count",
        "sdk_safe_disable_count", "sdk_safe_no_actuation_count"
    ) -Code "development_ghost_result"

    $decision = $Closure.decision
    Assert-SporeSporeR05EExactKeys -Value $decision -ExpectedKeys @(
        "development_route_ghost_complete",
        "route_construction_stepping_finalization_retention_and_evaluation_complete",
        "ghost_prerequisite_for_heldout_qualification_satisfied",
        "heldout_zero_world_qualification_work_permitted",
        "heldout_execution_authority_creation_permitted",
        "heldout_physical_execution_authorized", "heldout_cells_remain_sealed",
        "heldout_world_attempt_count", "same_identity_rerun_permitted",
        "current_execution_authority_consumed", "current_physical_execution_authorized",
        "new_source_freeze_required_before_heldout_authority",
        "normalize_windows_runtime_identity_paths_before_next_qualification",
        "semantically_validate_this_ghost_closure_before_next_qualification",
        "controller_policy_changed", "walking_threshold_changed", "material_changed",
        "solver_changed", "host_scaffold_changed", "sdk1_milestone_advanced",
        "physical_acceptance_authority", "release_authority"
    ) -Code "development_ghost_decision_key_set"
    $decisionBooleanFields = @($decision.Keys | Where-Object {
        [string]$_ -cne "heldout_world_attempt_count"
    })
    Assert-SporeSporeR05EBooleanFields -Value $decision `
        -Fields $decisionBooleanFields -Code "development_ghost_decision"
    Assert-SporeSporeR05EIntegerFields -Value $decision -Fields @(
        "heldout_world_attempt_count"
    ) -Code "development_ghost_decision"

    $claims = $Closure.claim_boundary
    Assert-SporeSporeR05EExactKeys -Value $claims -ExpectedKeys @(
        "physical_attempted", "physical_attempt_consumed", "valid_complete_route_result",
        "nonheldout_ghost_walk_observed", "development_data_only", "heldout_evidence",
        "same_selected_policy_independent_morphology_evidence",
        "exact_twelve_descriptor_support_established", "arbitrary_quadruped_coverage",
        "continuous_full_volume_coverage", "interpolation_supported",
        "extrapolation_supported", "repeatability_claimed", "population_claimed",
        "material_robustness", "external_push_recovery", "cross_engine_c6",
        "cross_engine_equivalence", "completed_engine_neutral_sdk",
        "sdk1_milestone_advanced", "physical_acceptance_authority", "release_authority"
    ) -Code "development_ghost_claim_key_set"
    Assert-SporeSporeR05EBooleanFields -Value $claims `
        -Fields @($claims.Keys) -Code "development_ghost_claim"

    $sdkStatus = $Closure.sdk_status
    Assert-SporeSporeR05EExactKeys -Value $sdkStatus -ExpectedKeys @(
        "sdk1_completed_steps", "sdk1_total_steps", "full_program_completed_steps",
        "full_program_total_steps", "m05_satisfied"
    ) -Code "development_ghost_sdk_status_key_set"
    Assert-SporeSporeR05EIntegerFields -Value $sdkStatus -Fields @(
        "sdk1_completed_steps", "sdk1_total_steps", "full_program_completed_steps",
        "full_program_total_steps"
    ) -Code "development_ghost_sdk_status"
    Assert-SporeSporeR05EBooleanFields -Value $sdkStatus -Fields @(
        "m05_satisfied"
    ) -Code "development_ghost_sdk_status"

    $topExact = (
        [string]$Closure.schema_version -ceq
            "sporespore_qsdk_r05e_development_route_ghost_physical_closure_v1" -and
        [string]$Closure.status -ceq
            "closed_consumed_complete_development_route_ghost_passed_heldout_still_sealed" -and
        [string]$Closure.gate_id -ceq "QSDK-R05E-GHOST" -and
        [string]$Closure.campaign_id -ceq "QSDK-R05E-DEVELOPMENT-ROUTE-GHOST" -and
        [string]$Closure.campaign_role -ceq "development_route_ghost" -and
        [string]$Closure.question_class -ceq "development" -and
        [string]$Closure.ledger_scope.subsystem -ceq "walking" -and
        [string]$Closure.ledger_scope.engine_scope -ceq "godot_jolt" -and
        [string]$Closure.ledger_scope.authority_mode -ceq
            "closed_consumed_development_route_ghost_evidence" -and
        [string]$Closure.ledger_scope.question_class -ceq "development"
    )
    if (-not $topExact) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_closure_identity"
    }
    $sourceExact = (
        [string]$source.source_freeze_commit -ceq
            "52beaf3c8ec1bf6a583635a792a8fe16ddf89c9f" -and
        [string]$source.qualification_commit -ceq
            "33d2a821be838404119a050265a7adf0f406c3ef" -and
        [string]$source.authorization_commit -ceq
            "f44dcc9131e70bf769efbda1491dd61fac8f28e2" -and
        [string]$source.branch -ceq "main" -and
        [string]$source.remote -ceq "https://github.com/Slagathore/sporespore.git" -and
        [bool]$source.head_origin_main_live_equal_at_physical_launch -and
        [bool]$source.worktree_clean_at_physical_launch_and_close -and
        [int64]$source.qualified_source_file_count -eq 80 -and
        [string]$source.qualification_closure.path -ceq
            "sdk/qsdk_r05e_development_route_ghost_zero_world_qualification_closure_v1.json" -and
        [string]$source.qualification_closure.raw_sha256 -ceq
            "sha256:f6a3480205364a620a6ea131ab8106058b51b665826902aea3fc6e595cd71141" -and
        [string]$source.qualification_closure.git_blob_oid -ceq
            "8d9d60ab501bd536af0122c4c5753d54ff50a1cf" -and
        [string]$source.execution_authority.path -ceq
            "sdk/qsdk_r05e_development_route_ghost_execution_authority.json" -and
        [string]$source.execution_authority.raw_sha256 -ceq
            "sha256:5443e0650f3263bb44de53343651d609da0933024bd19ad62b9add49053debc1" -and
        [int64]$source.execution_authority.byte_length -eq 2121 -and
        [string]$source.execution_authority.git_blob_oid -ceq
            "e16077a5ad55cd1ae2295058eea8aa5f4b119b10" -and
        [string]$source.execution_authority.immutable_document_status -ceq
            "authorized_single_use_unconsumed" -and
        [bool]$source.execution_authority.authority_document_is_not_rewritten_after_consumption -and
        [string]$source.preregistration.path -ceq
            "sdk/qsdk_r05e_development_route_ghost_preregistration.json" -and
        [string]$source.preregistration.raw_sha256 -ceq
            "sha256:ce1ef34851f81455115dd7031546f867f466c8ce264e375faba6c2d4436cf7f9" -and
        [string]$source.preregistration.git_blob_oid -ceq
            "b62192c82ebb0ac3c4254f7ec4d5187974b55065" -and
        [string]$source.r05d_design_sha256 -ceq
            "sha256:3b75b7609b638470ee947326f71018d082beb4a2c2909e78dae77d3b50250a6c" -and
        [string]$source.runtime_identity_sha256 -ceq
            "sha256:59dca6d9750d3315b93378a6b911aae28ffb7cb96f00f6a097e0111b069d7f96"
    )
    if (-not $sourceExact) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_source_content"
    }
    $refusalExact = (
        [bool]$refusal.observed -and [int64]$refusal.refusal_count -eq 1 -and
        [string]$refusal.failure_code -ceq
            "QSDK_R05E_EXECUTION_AUTHORITY:qualification_runtime_content" -and
        [string]$refusal.phase -ceq
            "runtime_identity_reconciliation_before_build_retention_or_world" -and
        [string]$refusal.qualified_powershell_path -ceq
            "C:/Program Files/PowerShell/7/pwsh.EXE" -and
        [string]$refusal.refused_invocation_powershell_path -ceq
            "C:/Program Files/PowerShell/7/pwsh.exe" -and
        [bool]$refusal.powershell_raw_sha256_equal -and
        [string]$refusal.powershell_raw_sha256 -ceq
            "sha256:362a356ce7f0940ec74f73a8fc2c990a2cc24a38a11c90bbd8eca947110ad139" -and
        [bool]$refusal.powershell_byte_length_equal -and
        [int64]$refusal.powershell_byte_length -eq 301368 -and
        [bool]$refusal.powershell_version_equal -and
        [string]$refusal.powershell_version -ceq "7.6.5" -and
        [string]$refusal.qualified_runtime_identity_sha256 -ceq
            "sha256:59dca6d9750d3315b93378a6b911aae28ffb7cb96f00f6a097e0111b069d7f96" -and
        [string]$refusal.refused_runtime_identity_sha256 -ceq
            "sha256:c98b507b17526ec55c126ce14ae8a309f9c166d61ba3461497833a375b19121c" -and
        [bool]$refusal.sole_difference_was_windows_path_case -and
        -not [bool]$refusal.output_directory_created -and
        -not [bool]$refusal.attempt_receipt_created -and
        [int64]$refusal.model_construction_count -eq 0 -and
        [int64]$refusal.world_attempt_count -eq 0 -and
        [int64]$refusal.world_build_count -eq 0 -and
        [int64]$refusal.native_readback_count -eq 0 -and
        [int64]$refusal.solver_step_count -eq 0 -and
        -not [bool]$refusal.physics_state_modified -and
        -not [bool]$refusal.physical_identity_consumed -and
        -not [bool]$refusal.separate_raw_refusal_log_retained -and
        [bool]$refusal.exact_refusal_retained_by_this_closure
    )
    if (-not $refusalExact) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_refusal_content"
    }

    $physicalExact = (
        [int64]$physical.attempt_count_for_exact_source_and_gate -eq 1 -and
        [bool]$physical.physical_identity_consumed -and
        [bool]$physical.first_complete_result_is_final -and
        -not [bool]$physical.same_identity_rerun_permitted -and
        [string]$physical.evidence_root -ceq
            "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r05e-development-route-ghost-physical-20260903T185904839Z-33d2a821" -and
        [string]$physical.report_path -ceq
            "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r05e-development-route-ghost-physical-20260903T185904839Z-33d2a821/report.json" -and
        [string]$physical.report_raw_sha256 -ceq
            "sha256:744b6153b9e39a61a2669f93b48ff6edd432457e7b066c03086d3d037062d719" -and
        [int64]$physical.report_byte_length -eq 50232 -and
        [string]$physical.attempt_path -ceq
            "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r05e-development-route-ghost-physical-20260903T185904839Z-33d2a821/qsdk_r05d_development_ghost_torso_length_mid_high_s229-s40001/attempt.json" -and
        [string]$physical.attempt_raw_sha256 -ceq
            "sha256:126fcd748e47de0841f172b05f7b3267ab3211aa78fc174bbf806b25a31518d3" -and
        [int64]$physical.attempt_byte_length -eq 1553 -and
        [int64]$physical.expected_world_count -eq 1 -and
        [int64]$physical.observed_world_count -eq 1 -and
        [int64]$physical.complete_receipt_count -eq 1 -and
        [int64]$physical.world_attempt_count -eq 1 -and
        [int64]$physical.world_build_count -eq 1 -and
        [int64]$physical.process_exit_code -eq 0 -and
        -not [bool]$physical.process_timed_out -and
        -not [bool]$physical.process_tree_killed -and
        [double]$physical.cell_duration_seconds -eq 44.0467862 -and
        [bool]$physical.physics_state_modified -and
        [string]$physical.engine.adapter_id -ceq "godot_jolt_gdextension_v1" -and
        [string]$physical.engine.physics_engine -ceq "Jolt Physics" -and
        [int64]$physical.engine.physics_hz -eq 120 -and
        [int64]$physical.engine.solver_velocity_steps -eq 20 -and
        [int64]$physical.engine.solver_position_steps -eq 7 -and
        [int64]$physical.morphology.generator_index -eq 229 -and
        [string]$physical.morphology.morphology_id -ceq
            "qsdk_r05d_development_ghost_torso_length_mid_high_s229" -and
        [string]$physical.morphology.generator_receipt_sha256 -ceq
            "sha256:5cf395118ca625753de17ebcebe6a52cd456a09d67a25921425cf076663639b5" -and
        [string]$physical.morphology.proportion_spec_sha256 -ceq
            "sha256:7e756f2718a95fc4aa0c31cb908ae2c68686a229c38abeeaf0d374ad31f889f6" -and
        [int64]$physical.morphology.campaign_seed -eq 40001
    )
    if (-not $physicalExact) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_physical_content"
    }

    $resultExact = (
        [string]$result.classification -ceq
            "valid_complete_development_route_ghost_positive" -and
        [bool]$result.route_complete -and
        -not [bool]$result.behavior_success_required -and
        [bool]$result.walking_observed -and [bool]$result.harness_passed -and
        [bool]$result.common_execution_integrity -and
        [bool]$result.mechanism_gate_passed -and
        [bool]$result.combined_application_gate_passed -and
        [int64]$result.assertion_pass_count -eq 9 -and
        [int64]$result.assertion_failure_count -eq 0 -and
        [int64]$result.walking_gate_receipt_count -eq 27 -and
        [int64]$result.walking_gate_failure_count -eq 0 -and
        [int64]$result.failed_production_walking_gate_count -eq 0 -and
        [int64]$result.release_timeout_count -eq 0 -and
        [int64]$result.sdk_step_count -eq 2782 -and
        [int64]$result.native_motor_write_count -eq 22256 -and
        [int64]$result.native_motor_write_count_per_sdk_step -eq 8 -and
        [int64]$result.validated_balanced_wave_command_count -eq 22256 -and
        [int64]$result.direct_body_write_count -eq 0 -and
        [int64]$result.legacy_post_settle_motor_write_count -eq 0 -and
        [int64]$result.legacy_evidence_motor_write_count -eq 0 -and
        [int64]$result.sdk_mismatch_count -eq 0 -and
        [int64]$result.sdk_safe_disable_count -eq 0 -and
        [int64]$result.sdk_safe_no_actuation_count -eq 0 -and
        [double]$result.evidence_task_frame_forward_displacement_m -eq
            0.9404882788658142 -and
        [double]$result.final_task_frame_forward_displacement_m -eq
            1.0868496894836426 -and
        [double]$result.final_task_frame_lateral_displacement_m -eq
            -0.0031537972390651703 -and
        [double]$result.minimum_torso_height_m -eq 0.42829155921936035 -and
        [double]$result.maximum_tilt_rad -eq 0.11897792691477668 -and
        [double]$result.maximum_anchor_error_m -eq 0.018249409273266792 -and
        [double]$result.maximum_hinge_axis_error_rad -eq 0.09523956587405306 -and
        [bool]$result.one_continuous_world -and [bool]$result.no_world_reset -and
        [bool]$result.terminal_four_contact_recovery
    )
    if (-not $resultExact) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_result_content"
    }

    $decisionExact = (
        [bool]$decision.development_route_ghost_complete -and
        [bool]$decision.route_construction_stepping_finalization_retention_and_evaluation_complete -and
        [bool]$decision.ghost_prerequisite_for_heldout_qualification_satisfied -and
        [bool]$decision.heldout_zero_world_qualification_work_permitted -and
        -not [bool]$decision.heldout_execution_authority_creation_permitted -and
        -not [bool]$decision.heldout_physical_execution_authorized -and
        [bool]$decision.heldout_cells_remain_sealed -and
        [int64]$decision.heldout_world_attempt_count -eq 0 -and
        -not [bool]$decision.same_identity_rerun_permitted -and
        [bool]$decision.current_execution_authority_consumed -and
        -not [bool]$decision.current_physical_execution_authorized -and
        [bool]$decision.new_source_freeze_required_before_heldout_authority -and
        [bool]$decision.normalize_windows_runtime_identity_paths_before_next_qualification -and
        [bool]$decision.semantically_validate_this_ghost_closure_before_next_qualification -and
        -not [bool]$decision.controller_policy_changed -and
        -not [bool]$decision.walking_threshold_changed -and
        -not [bool]$decision.material_changed -and -not [bool]$decision.solver_changed -and
        -not [bool]$decision.host_scaffold_changed -and
        -not [bool]$decision.sdk1_milestone_advanced -and
        -not [bool]$decision.physical_acceptance_authority -and
        -not [bool]$decision.release_authority
    )
    if (-not $decisionExact) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_decision_content"
    }
    $claimExact = (
        [bool]$claims.physical_attempted -and [bool]$claims.physical_attempt_consumed -and
        [bool]$claims.valid_complete_route_result -and
        [bool]$claims.nonheldout_ghost_walk_observed -and
        [bool]$claims.development_data_only -and
        -not [bool]$claims.heldout_evidence -and
        -not [bool]$claims.same_selected_policy_independent_morphology_evidence -and
        -not [bool]$claims.exact_twelve_descriptor_support_established -and
        -not [bool]$claims.arbitrary_quadruped_coverage -and
        -not [bool]$claims.continuous_full_volume_coverage -and
        -not [bool]$claims.interpolation_supported -and
        -not [bool]$claims.extrapolation_supported -and
        -not [bool]$claims.repeatability_claimed -and
        -not [bool]$claims.population_claimed -and
        -not [bool]$claims.material_robustness -and
        -not [bool]$claims.external_push_recovery -and
        -not [bool]$claims.cross_engine_c6 -and
        -not [bool]$claims.cross_engine_equivalence -and
        -not [bool]$claims.completed_engine_neutral_sdk -and
        -not [bool]$claims.sdk1_milestone_advanced -and
        -not [bool]$claims.physical_acceptance_authority -and
        -not [bool]$claims.release_authority
    )
    if (-not $claimExact) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_claim_content"
    }
    if (
        [int64]$sdkStatus.sdk1_completed_steps -ne 12 -or
        [int64]$sdkStatus.sdk1_total_steps -ne 20 -or
        [int64]$sdkStatus.full_program_completed_steps -ne 12 -or
        [int64]$sdkStatus.full_program_total_steps -ne 25 -or
        [bool]$sdkStatus.m05_satisfied
    ) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_sdk_status_content"
    }

    foreach ($field in @(
        "source", "runtime_identity_projection", "preregistration",
        "physical_execution_authority", "metrics", "full_integrity_preflight",
        "experiment_result_integrity_preflight", "development_ghost_entrypoint_preflight",
        "exact_finite_morphology_source_preflight"
    )) {
        if ($Report[$field] -isnot [System.Collections.IDictionary]) {
            Throw-SporeSporeR05EAuthorityFailure "development_ghost_report_${field}_type"
        }
    }
    $reportResults = @($Report.results)
    if (
        $Report.results -isnot [System.Collections.IList] -or
        $reportResults.Count -ne 1 -or
        $reportResults[0] -isnot [System.Collections.IDictionary] -or
        $reportResults[0].receipt -isnot [System.Collections.IDictionary]
    ) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_report_results"
    }
    $cell = $reportResults[0]
    $receipt = $cell.receipt
    $walkingGates = $receipt.walking_gate_receipts
    if ($walkingGates -isnot [System.Collections.IDictionary]) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_walking_gates_type"
    }
    $failedWalkingGates = @($walkingGates.Keys | Where-Object {
        $walkingGates[$_] -isnot [bool] -or -not [bool]$walkingGates[$_]
    })
    if (@($walkingGates.Keys).Count -ne 27 -or $failedWalkingGates.Count -ne 0) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_walking_gates"
    }

    $reportExact = (
        [string]$Report.schema_version -ceq
            "sporespore_qsdk_r05e_development_route_ghost_report_v1" -and
        [string]$Report.source.commit -ceq [string]$source.authorization_commit -and
        [string]$Report.source.remote -ceq "origin/main" -and
        [string]$Report.source.origin_main_commit -ceq
            [string]$source.authorization_commit -and
        [bool]$Report.source.clean -and [bool]$Report.source.matches_origin_main -and
        @($Report.source.source_files).Count -eq 80 -and
        [string]$Report.runtime_identity_projection.identity_sha256 -ceq
            [string]$source.runtime_identity_sha256 -and
        [string]$Report.preregistration.sha256 -ceq
            [string]$source.preregistration.raw_sha256 -and
        [string]$Report.physical_execution_authority.sha256 -ceq
            [string]$source.execution_authority.raw_sha256 -and
        [string]$Report.physical_execution_authority.authorization_commit -ceq
            [string]$source.authorization_commit -and
        [string]$Report.physical_execution_authority.authorization_parent_commit -ceq
            [string]$source.qualification_commit -and
        [string]$Report.physical_execution_authority.source_freeze_commit -ceq
            [string]$source.source_freeze_commit -and
        [bool]$Report.physical_execution_authority.authorization_only_commit -and
        [int64]$Report.physical_execution_authority.qualified_source_file_count -eq 80 -and
        [bool]$Report.physical_execution_authority.worker_authorization_preflight_passed -and
        [bool]$Report.physical_execution_authority.mismatched_worker_authorization_token_refused -and
        [bool]$Report.physical_execution_authority.worker_authorization_type_mutation_refused -and
        [bool]$Report.physical_execution_authority.direct_physical_worker_bypass_refused -and
        -not [bool]$Report.physical_execution_authority.physical_acceptance_authority -and
        [string]$Report.campaign_id -ceq "QSDK-R05E-DEVELOPMENT-ROUTE-GHOST" -and
        [string]$Report.gate_id -ceq "QSDK-R05E-GHOST" -and
        [string]$Report.campaign_role -ceq "development_route_ghost" -and
        [string]$Report.selected_candidate_id -ceq "BW5R-B" -and
        [string]$Report.selected_policy_id -ceq "sporespore_balanced_wave_bw5r_b_v1" -and
        [string]$Report.selected_policy_digest -ceq
            "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f" -and
        @($Report.morphology_ids).Count -eq 1 -and
        [string]$Report.morphology_ids[0] -ceq
            "qsdk_r05d_development_ghost_torso_length_mid_high_s229" -and
        @($Report.generator_indices).Count -eq 1 -and
        [int64]$Report.generator_indices[0] -eq 229 -and
        @($Report.campaign_seeds).Count -eq 1 -and
        [int64]$Report.campaign_seeds[0] -eq 40001 -and
        [int64]$Report.expected_world_count -eq 1 -and
        [int64]$Report.observed_world_count -eq 1 -and
        [int64]$Report.complete_receipt_count -eq 1 -and
        [int64]$Report.harness_pass_count -eq 1 -and
        [int64]$Report.walking_pass_count -eq 1 -and
        [int64]$Report.integrity_pass_count -eq 1 -and
        [int64]$Report.failure_count -eq 0 -and
        [bool]$Report.route_complete -and [bool]$Report.development_data_only -and
        [bool]$Report.finite_population_only -and
        -not [bool]$Report.same_selected_policy_independent_morphology_evidence -and
        -not [bool]$Report.arbitrary_quadruped_coverage -and
        -not [bool]$Report.continuous_full_volume_coverage -and
        -not [bool]$Report.material_robustness -and
        -not [bool]$Report.rough_terrain_robustness -and
        -not [bool]$Report.external_push_recovery -and
        -not [bool]$Report.sensor_noise_or_latency_robustness -and
        -not [bool]$Report.running -and -not [bool]$Report.cross_engine_c6 -and
        -not [bool]$Report.completed_engine_neutral_sdk -and
        -not [bool]$Report.release_authorized -and
        -not [bool]$Report.physical_acceptance_authority -and
        [bool]$Report.full_integrity_preflight.passed -and
        [int64]$Report.full_integrity_preflight.actual_world_build_count -eq 0 -and
        [bool]$Report.experiment_result_integrity_preflight.passed -and
        [int64]$Report.experiment_result_integrity_preflight.actual_world_build_count -eq 0 -and
        [bool]$Report.development_ghost_entrypoint_preflight.passed -and
        [int64]$Report.development_ghost_entrypoint_preflight.actual_world_build_count -eq 0 -and
        [bool]$Report.exact_finite_morphology_source_preflight.passed -and
        [int64]$Report.exact_finite_morphology_source_preflight.official_descriptor_compile_count -eq 12 -and
        [int64]$Report.exact_finite_morphology_source_preflight.development_ghost_descriptor_compile_count -eq 1 -and
        [int64]$Report.exact_finite_morphology_source_preflight.negative_control_count -eq 32 -and
        [int64]$Report.exact_finite_morphology_source_preflight.negative_controls_passed -eq 32 -and
        [int64]$Report.exact_finite_morphology_source_preflight.actual_world_build_count -eq 0 -and
        [int64]$Report.exact_finite_morphology_source_preflight.solver_step_count -eq 0 -and
        -not [bool]$Report.exact_finite_morphology_source_preflight.locomotion_outcome_exposed -and
        -not [bool]$Report.exact_finite_morphology_source_preflight.physical_acceptance_authority
    )
    if (-not $reportExact) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_report_content"
    }

    $cellExact = (
        [string]$cell.morphology_id -ceq [string]$physical.morphology.morphology_id -and
        [int64]$cell.generator_index -eq 229 -and [int64]$cell.campaign_seed -eq 40001 -and
        [int64]$cell.process_exit_code -eq 0 -and -not [bool]$cell.timed_out -and
        -not [bool]$cell.killed_process_tree -and
        [double]$cell.duration_seconds -eq [double]$physical.cell_duration_seconds -and
        [bool]$cell.receipt_parsed -and [string]$cell.receipt_parse_error -ceq "" -and
        [bool]$cell.harness_passed -and [bool]$cell.walking_observed -and
        [bool]$cell.common_execution_integrity -and [bool]$cell.mechanism_gate_passed -and
        [bool]$cell.combined_application_gate_passed -and
        [int64]$cell.failed_production_walking_gate_count -eq 0 -and
        [int64]$cell.release_timeout_count -eq 0 -and
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r05e_development_ghost_cell_v1" -and
        [string]$receipt.campaign_id -ceq "QSDK-R05E-DEVELOPMENT-ROUTE-GHOST" -and
        [string]$receipt.gate_id -ceq "QSDK-R05E-GHOST" -and
        [string]$receipt.campaign_role -ceq "development_route_ghost" -and
        [int64]$receipt.generator_index -eq 229 -and
        [string]$receipt.morphology_id -ceq [string]$physical.morphology.morphology_id -and
        [int64]$receipt.campaign_seed -eq 40001 -and
        [bool]$receipt.harness_passed -and [bool]$receipt.walking_observed -and
        [bool]$receipt.common_execution_integrity -and [bool]$receipt.sdk_authority_enabled -and
        [int64]$receipt.assertions_passed -eq [int64]$result.assertion_pass_count -and
        [int64]$receipt.assertions_failed -eq [int64]$result.assertion_failure_count -and
        [int64]$receipt.sdk_step_count -eq [int64]$result.sdk_step_count -and
        [int64]$receipt.native_motor_write_count -eq [int64]$result.native_motor_write_count -and
        [int64]$receipt.validated_balanced_wave_command_count -eq
            [int64]$result.validated_balanced_wave_command_count -and
        [int64]$receipt.direct_body_write_count -eq 0 -and
        [int64]$receipt.legacy_post_settle_motor_write_count -eq 0 -and
        [int64]$receipt.legacy_evidence_motor_write_count -eq 0 -and
        [int64]$receipt.sdk_mismatch_count -eq 0 -and
        [int64]$receipt.sdk_safe_disable_count -eq 0 -and
        [int64]$receipt.sdk_safe_no_actuation_count -eq 0 -and
        [int64]$receipt.world_build_count -eq 1 -and
        [double]$receipt.evidence_task_frame_forward_displacement_m -eq
            [double]$result.evidence_task_frame_forward_displacement_m -and
        [double]$receipt.final_task_frame_forward_displacement_m -eq
            [double]$result.final_task_frame_forward_displacement_m -and
        [double]$receipt.final_task_frame_lateral_displacement_m -eq
            [double]$result.final_task_frame_lateral_displacement_m -and
        [double]$receipt.minimum_torso_height_m -eq [double]$result.minimum_torso_height_m -and
        [double]$receipt.maximum_tilt_rad -eq [double]$result.maximum_tilt_rad -and
        [double]$receipt.maximum_anchor_error_m -eq [double]$result.maximum_anchor_error_m -and
        [double]$receipt.maximum_hinge_axis_error_rad -eq
            [double]$result.maximum_hinge_axis_error_rad -and
        [bool]$receipt.finite_population_only -and
        -not [bool]$receipt.arbitrary_quadruped_coverage -and
        -not [bool]$receipt.continuous_full_volume_coverage -and
        -not [bool]$receipt.material_robustness -and
        -not [bool]$receipt.cross_engine_c6 -and
        -not [bool]$receipt.completed_engine_neutral_sdk -and
        -not [bool]$receipt.physical_acceptance_authority
    )
    if (-not $cellExact) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_cell_content"
    }

    Assert-SporeSporeR05EExactKeys -Value $Attempt -ExpectedKeys @(
        "schema_version", "authorization_token", "campaign_id", "gate_id",
        "campaign_role", "generator_index", "morphology_id", "campaign_seed",
        "source_commit", "r05d_design_sha256", "preregistration_sha256",
        "execution_authority_path", "execution_authority_sha256",
        "synthetic_authorization_preflight", "supervisor_physical_authorized",
        "maximum_world_attempt_count", "maximum_world_build_count",
        "world_attempt_count_before_worker", "world_build_count_before_worker",
        "same_identity_rerun_permitted", "operation_lock", "physical_acceptance_authority"
    ) -Code "development_ghost_attempt_key_set"
    if ($Attempt.operation_lock -isnot [System.Collections.IDictionary]) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_attempt_lock_type"
    }
    $attemptExact = (
        [string]$Attempt.schema_version -ceq "sporespore_qsdk_r05e_morphology_attempt_v1" -and
        (Test-SporeSporeR05ELowerHex -Value ([string]$Attempt.authorization_token) -Length 32) -and
        [string]$Attempt.campaign_id -ceq "QSDK-R05E-DEVELOPMENT-ROUTE-GHOST" -and
        [string]$Attempt.gate_id -ceq "QSDK-R05E-GHOST" -and
        [string]$Attempt.campaign_role -ceq "development_route_ghost" -and
        [int64]$Attempt.generator_index -eq 229 -and
        [string]$Attempt.morphology_id -ceq [string]$physical.morphology.morphology_id -and
        [int64]$Attempt.campaign_seed -eq 40001 -and
        [string]$Attempt.source_commit -ceq [string]$source.authorization_commit -and
        [string]$Attempt.r05d_design_sha256 -ceq [string]$source.r05d_design_sha256 -and
        [string]$Attempt.preregistration_sha256 -ceq
            [string]$source.preregistration.raw_sha256 -and
        [string]$Attempt.execution_authority_sha256 -ceq
            [string]$source.execution_authority.raw_sha256 -and
        -not [bool]$Attempt.synthetic_authorization_preflight -and
        [bool]$Attempt.supervisor_physical_authorized -and
        [int64]$Attempt.maximum_world_attempt_count -eq 1 -and
        [int64]$Attempt.maximum_world_build_count -eq 1 -and
        [int64]$Attempt.world_attempt_count_before_worker -eq 0 -and
        [int64]$Attempt.world_build_count_before_worker -eq 0 -and
        -not [bool]$Attempt.same_identity_rerun_permitted -and
        [bool]$Attempt.operation_lock.acquired -and
        [string]$Attempt.operation_lock.role -ceq "physical_development" -and
        -not [bool]$Attempt.operation_lock.abandoned_owner_recovered -and
        -not [bool]$Attempt.operation_lock.test_only -and
        -not [bool]$Attempt.operation_lock.physical_acceptance_authority -and
        -not [bool]$Attempt.physical_acceptance_authority
    )
    if (-not $attemptExact) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_attempt_content"
    }

    return [ordered]@{
        schema_version = [string]$Closure.schema_version
        status = [string]$Closure.status
        development_route_ghost_complete = $true
        route_complete = $true
        development_data_only = $true
        heldout_evidence = $false
        heldout_world_attempt_count = 0
        physical_world_count = 1
        retained_file_count = 9
        retained_total_byte_length = 437196
        retained_manifest_sha256 = [string]$retained.manifest_canonical_sha256
        model_construction_count_during_audit = 0
        world_attempt_count_during_audit = 0
        world_build_count_during_audit = 0
        native_readback_count_during_audit = 0
        solver_step_count_during_audit = 0
        physics_state_modified_during_audit = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
}

function Assert-SporeSporeR05ESinglePathCommit {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$Parent,
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$Code
    )
    $parentText = Invoke-SporeSporeR05EGit -RepoRoot $RepoRoot `
        -Arguments @("rev-list", "--parents", "-n", "1", $Commit) `
        -Code "${Code}_parent"
    $parts = @($parentText -split ' ' | Where-Object { $_ })
    if (
        $parts.Count -ne 2 -or [string]$parts[0] -cne $Commit -or
        [string]$parts[1] -cne $Parent
    ) {
        Throw-SporeSporeR05EAuthorityFailure "${Code}_parent"
    }
    $changedText = Invoke-SporeSporeR05EGit -RepoRoot $RepoRoot -Arguments @(
        "diff-tree", "--no-commit-id", "--name-only", "--no-renames", "-r", $Commit
    ) -Code "${Code}_diff" -AllowEmpty
    $changed = @(
        $changedText -split "`n" |
            ForEach-Object { $_.Trim().Replace("\", "/") } |
            Where-Object { $_ }
    )
    if ($changed.Count -ne 1 -or [string]$changed[0] -cne $RelativePath) {
        Throw-SporeSporeR05EAuthorityFailure "${Code}_not_single_path"
    }
}

function Assert-SporeSporeR05EDevelopmentGhostClosure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Head,
        [Parameter(Mandatory)][string]$ClosurePath,
        [Parameter(Mandatory)][string]$EvidenceRoot
    )
    $repo = [IO.Path]::GetFullPath($RepoRoot)
    $relative = "sdk/qsdk_r05e_development_route_ghost_physical_closure_v1.json"
    $expectedPath = [IO.Path]::GetFullPath((Join-Path $repo $relative))
    if ([IO.Path]::GetFullPath($ClosurePath) -cne $expectedPath) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_closure_path"
    }
    if (-not (Test-Path -LiteralPath $expectedPath -PathType Leaf)) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_closure_missing"
    }
    $tracked = Invoke-SporeSporeR05EGit -RepoRoot $repo `
        -Arguments @("ls-files", "--error-unmatch", $relative) `
        -Code "development_ghost_closure_tracked"
    $workingBlob = Invoke-SporeSporeR05EGit -RepoRoot $repo `
        -Arguments @("hash-object", $relative) -Code "development_ghost_working_blob"
    $headBlob = Invoke-SporeSporeR05EGit -RepoRoot $repo `
        -Arguments @("rev-parse", "$Head`:$relative") -Code "development_ghost_head_blob"
    $historyText = Invoke-SporeSporeR05EGit -RepoRoot $repo `
        -Arguments @("log", $Head, "--format=%H", "--", $relative) `
        -Code "development_ghost_history"
    $history = @($historyText -split "`n" | Where-Object { $_ })
    if (
        $tracked.Replace("\", "/") -cne $relative -or
        $workingBlob -cne $headBlob -or
        $headBlob -cne "09ea9be8fbc6cf6acb4da888323cd1020db09712" -or
        (Get-SporeSporeR05ERawSha256 -Path $expectedPath) -cne
            "sha256:3753b6847cbcc7f2ec49f4f118f15ddc8a566bdfb3286f45db0f23f542b3a921" -or
        $history.Count -ne 1 -or
        [string]$history[0] -cne "6ea17c4e949824f4bda0900ed4755e11181aff36"
    ) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_closure_repository_binding"
    }
    Assert-SporeSporeR05ESinglePathCommit -RepoRoot $repo `
        -Commit "33d2a821be838404119a050265a7adf0f406c3ef" `
        -Parent "52beaf3c8ec1bf6a583635a792a8fe16ddf89c9f" `
        -RelativePath "sdk/qsdk_r05e_development_route_ghost_zero_world_qualification_closure_v1.json" `
        -Code "development_ghost_qualification_commit"
    Assert-SporeSporeR05ESinglePathCommit -RepoRoot $repo `
        -Commit "f44dcc9131e70bf769efbda1491dd61fac8f28e2" `
        -Parent "33d2a821be838404119a050265a7adf0f406c3ef" `
        -RelativePath "sdk/qsdk_r05e_development_route_ghost_execution_authority.json" `
        -Code "development_ghost_authorization_commit"
    Assert-SporeSporeR05ESinglePathCommit -RepoRoot $repo `
        -Commit "6ea17c4e949824f4bda0900ed4755e11181aff36" `
        -Parent "f44dcc9131e70bf769efbda1491dd61fac8f28e2" `
        -RelativePath $relative -Code "development_ghost_closure_commit"

    $closure = Get-Content -Raw -LiteralPath $expectedPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    foreach ($binding in @(
        $closure.source_and_authority.qualification_closure,
        $closure.source_and_authority.execution_authority,
        $closure.source_and_authority.preregistration
    )) {
        $bindingPath = [IO.Path]::GetFullPath((Join-Path $repo ([string]$binding.path)))
        if (
            -not (Test-Path -LiteralPath $bindingPath -PathType Leaf) -or
            (Get-SporeSporeR05ERawSha256 -Path $bindingPath) -cne
                [string]$binding.raw_sha256 -or
            (Invoke-SporeSporeR05EGit -RepoRoot $repo -Arguments @(
                "rev-parse", "$Head`:$([string]$binding.path)"
            ) -Code "development_ghost_bound_document_blob") -cne
                [string]$binding.git_blob_oid
        ) {
            Throw-SporeSporeR05EAuthorityFailure "development_ghost_bound_document"
        }
    }
    $designPath = Join-Path $repo "sdk/qsdk_r05d_exact_finite_morphology_successor_design_v1.json"
    if (
        (Get-SporeSporeR05ERawSha256 -Path $designPath) -cne
            [string]$closure.source_and_authority.r05d_design_sha256
    ) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_design_binding"
    }

    $durableRoot = [IO.Path]::GetFullPath($EvidenceRoot).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    $repoWithoutTrailingSeparator = $repo.TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    $expectedDurableRoot = [IO.Path]::GetFullPath(
        "${repoWithoutTrailingSeparator}_Evidence"
    ).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    if (-not $durableRoot.Equals(
        $expectedDurableRoot, [StringComparison]::OrdinalIgnoreCase
    )) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_durable_root"
    }
    $campaignRoot = [IO.Path]::GetFullPath([string]$closure.physical_attempt.evidence_root)
    $durablePrefix = $durableRoot + [IO.Path]::DirectorySeparatorChar
    if (-not $campaignRoot.StartsWith(
        $durablePrefix, [StringComparison]::OrdinalIgnoreCase
    )) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_evidence_outside_root"
    }
    $reportPath = [IO.Path]::GetFullPath([string]$closure.physical_attempt.report_path)
    $attemptPath = [IO.Path]::GetFullPath([string]$closure.physical_attempt.attempt_path)
    foreach ($path in @($reportPath, $attemptPath)) {
        if (
            -not $path.StartsWith(
                $campaignRoot + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            ) -or
            -not (Test-Path -LiteralPath $path -PathType Leaf)
        ) {
            Throw-SporeSporeR05EAuthorityFailure "development_ghost_evidence_path"
        }
    }
    if (
        (Get-SporeSporeR05ERawSha256 -Path $reportPath) -cne
            [string]$closure.physical_attempt.report_raw_sha256 -or
        [int64](Get-Item -LiteralPath $reportPath).Length -ne
            [int64]$closure.physical_attempt.report_byte_length -or
        (Get-SporeSporeR05ERawSha256 -Path $attemptPath) -cne
            [string]$closure.physical_attempt.attempt_raw_sha256 -or
        [int64](Get-Item -LiteralPath $attemptPath).Length -ne
            [int64]$closure.physical_attempt.attempt_byte_length
    ) {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_evidence_binding"
    }
    try {
        $report = Get-Content -Raw -LiteralPath $reportPath |
            ConvertFrom-Json -AsHashtable -Depth 100
        $attempt = Get-Content -Raw -LiteralPath $attemptPath |
            ConvertFrom-Json -AsHashtable -Depth 100
    } catch {
        Throw-SporeSporeR05EAuthorityFailure "development_ghost_evidence_json"
    }
    $artifacts = @(Get-SporeSporeR05ERetainedFileArtifacts -Root $campaignRoot)
    $projection = Assert-SporeSporeR05EDevelopmentGhostClosureContent `
        -Closure $closure -Report $report -Attempt $attempt -CurrentArtifacts $artifacts
    $projection["closure_path"] = $relative
    $projection["closure_raw_sha256"] = Get-SporeSporeR05ERawSha256 -Path $expectedPath
    $projection["closure_git_blob_oid"] = $headBlob
    $projection["closure_commit"] = "6ea17c4e949824f4bda0900ed4755e11181aff36"
    return $projection
}

function Assert-SporeSporeR05EQualificationReceipt {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Receipt,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Qualification,
        [Parameter(Mandatory)][string]$SourceFreeze,
        [Parameter(Mandatory)][int]$ExpectedSourceCount,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Expected
    )
    Assert-SporeSporeR05EExactKeys `
        -Value $Receipt `
        -ExpectedKeys @(
            "schema_version", "gate_id", "ledger_scope", "ok",
            "source_commit", "branch", "worktree_clean",
            "head_origin_main_equal", "head_live_remote_main_equal",
            "official_qualification_mode", "r05d_design_audit_passed",
            "dependency_closure_audit_passed",
            "dependency_gdscript_direct_entry_count",
            "dependency_gdscript_transitive_path_count",
            "dependency_rust_build_path_count",
            "dependency_process_and_audit_path_count",
            "qualified_source_path_count", "qualified_source_path_sha256",
            "dependency_mutation_rejection_count",
            "dependency_all_qualified_paths_lf_checkout_policy",
            "dependency_all_qualified_paths_tracked",
            "dependency_tracked_source_required", "runtime_identity_projection",
            "qualification_tool_identity",
            "runtime_identity_exact_across_supervisors", "preregistration_count",
            "supervisor_preflight_count", "serialized_conformance_lock_count",
            "final_operation_lock_release_probe_passed",
            "official_descriptor_compile_count_per_supervisor",
            "development_ghost_descriptor_compile_count_per_supervisor",
            "source_mutation_control_count_per_supervisor",
            "worker_authorization_type_mutation_refusal_count",
            "authority_contract_positive_repository_graph_count",
            "authority_contract_content_mutation_rejection_count",
            "authority_contract_repository_binding_rejection_count",
            "physical_missing_authority_refusal_count",
            "held_out_locomotion_outcome_exposure_count",
            "model_construction_count", "world_attempt_count", "world_build_count",
            "native_readback_count", "solver_step_count", "physics_state_modified",
            "physical_execution_authorized", "physical_acceptance_authority",
            "release_authority"
        ) `
        -Code "qualification_receipt_key_set"
    if (
        $Receipt.ledger_scope -isnot [System.Collections.IDictionary] -or
        $Receipt.runtime_identity_projection -isnot
            [System.Collections.IDictionary] -or
        $Receipt.qualification_tool_identity -isnot
            [System.Collections.IDictionary]
    ) {
        Throw-SporeSporeR05EAuthorityFailure "qualification_receipt_object_type"
    }
    Assert-SporeSporeR05EExactKeys `
        -Value $Receipt.ledger_scope `
        -ExpectedKeys @("subsystem", "engine_scope", "authority_mode", "question_class") `
        -Code "qualification_receipt_ledger_key_set"
    Assert-SporeSporeR05EExactKeys `
        -Value $Receipt.qualification_tool_identity `
        -ExpectedKeys @("path", "raw_sha256", "byte_length", "version") `
        -Code "qualification_tool_identity_key_set"
    foreach ($field in @(
        "schema_version", "gate_id", "source_commit", "branch",
        "qualified_source_path_sha256"
    )) {
        if ($Receipt[$field] -isnot [string]) {
            Throw-SporeSporeR05EAuthorityFailure `
                "qualification_receipt_${field}_type"
        }
    }
    foreach ($field in @(
        "ok", "worktree_clean", "head_origin_main_equal",
        "head_live_remote_main_equal", "official_qualification_mode",
        "r05d_design_audit_passed", "dependency_closure_audit_passed",
        "dependency_all_qualified_paths_lf_checkout_policy",
        "dependency_all_qualified_paths_tracked",
        "dependency_tracked_source_required",
        "runtime_identity_exact_across_supervisors",
        "final_operation_lock_release_probe_passed", "physics_state_modified",
        "physical_execution_authorized", "physical_acceptance_authority",
        "release_authority"
    )) {
        if ($Receipt[$field] -isnot [bool]) {
            Throw-SporeSporeR05EAuthorityFailure `
                "qualification_receipt_${field}_type"
        }
    }
    foreach ($field in @(
        "dependency_gdscript_direct_entry_count",
        "dependency_gdscript_transitive_path_count",
        "dependency_rust_build_path_count",
        "dependency_process_and_audit_path_count", "qualified_source_path_count",
        "dependency_mutation_rejection_count", "preregistration_count",
        "supervisor_preflight_count", "serialized_conformance_lock_count",
        "official_descriptor_compile_count_per_supervisor",
        "development_ghost_descriptor_compile_count_per_supervisor",
        "source_mutation_control_count_per_supervisor",
        "worker_authorization_type_mutation_refusal_count",
        "authority_contract_positive_repository_graph_count",
        "authority_contract_content_mutation_rejection_count",
        "authority_contract_repository_binding_rejection_count",
        "physical_missing_authority_refusal_count",
        "held_out_locomotion_outcome_exposure_count", "model_construction_count",
        "world_attempt_count", "world_build_count", "native_readback_count",
        "solver_step_count"
    )) {
        if (-not (Test-SporeSporeR05EJsonInteger $Receipt[$field])) {
            Throw-SporeSporeR05EAuthorityFailure `
                "qualification_receipt_${field}_type"
        }
    }
    $qualificationTool = $Receipt.qualification_tool_identity
    if (
        $qualificationTool.path -isnot [string] -or
        $qualificationTool.raw_sha256 -isnot [string] -or
        -not (Test-SporeSporeR05EJsonInteger $qualificationTool.byte_length) -or
        $qualificationTool.version -isnot [string] -or
        [string]::IsNullOrWhiteSpace([string]$qualificationTool.version) -or
        -not (Test-SporeSporeR05EPrefixedSha256 `
            ([string]$qualificationTool.raw_sha256))
    ) {
        Throw-SporeSporeR05EAuthorityFailure "qualification_tool_identity_type"
    }
    $qualificationToolPath = [IO.Path]::GetFullPath(
        [string]$qualificationTool.path
    )
    if (
        -not (Test-Path -LiteralPath $qualificationToolPath -PathType Leaf) -or
        (Get-SporeSporeR05ERawSha256 $qualificationToolPath) -cne
            [string]$qualificationTool.raw_sha256 -or
        [int64](Get-Item -LiteralPath $qualificationToolPath).Length -ne
            [int64]$qualificationTool.byte_length -or
        [int64]$qualificationTool.byte_length -le 0
    ) {
        Throw-SporeSporeR05EAuthorityFailure "qualification_tool_identity_content"
    }
    $receiptRuntimeCanonical = ConvertTo-SporeSporeR05ECanonicalJson `
        -Value $Receipt.runtime_identity_projection
    $qualificationRuntimeCanonical = ConvertTo-SporeSporeR05ECanonicalJson `
        -Value $Qualification.runtime
    $qualificationEvidence = $Qualification.qualification
    $exact = (
        [string]$Receipt.schema_version -ceq
            "sporespore_qsdk_r05e_zero_world_implementation_audit_v1" -and
        [string]$Receipt.gate_id -ceq "QSDK-R05E" -and
        [string]$Receipt.ledger_scope.subsystem -ceq "walking" -and
        [string]$Receipt.ledger_scope.engine_scope -ceq "godot_jolt" -and
        [string]$Receipt.ledger_scope.authority_mode -ceq
            "prospective_zero_world_implementation_audit" -and
        [string]$Receipt.ledger_scope.question_class -ceq "development" -and
        [bool]$Receipt.ok -and
        [string]$Receipt.source_commit -ceq $SourceFreeze -and
        [string]$Receipt.branch -ceq "main" -and
        [bool]$Receipt.worktree_clean -and
        [bool]$Receipt.head_origin_main_equal -and
        [bool]$Receipt.head_live_remote_main_equal -and
        [bool]$Receipt.official_qualification_mode -and
        [bool]$Receipt.r05d_design_audit_passed -and
        [bool]$Receipt.dependency_closure_audit_passed -and
        [int64]$Receipt.dependency_gdscript_direct_entry_count -eq
            [int64]$Expected.dependency_gdscript_direct_entry_count -and
        [int64]$Receipt.dependency_gdscript_transitive_path_count -eq
            [int64]$Expected.dependency_gdscript_transitive_path_count -and
        [int64]$Receipt.dependency_rust_build_path_count -eq
            [int64]$Expected.dependency_rust_build_path_count -and
        [int64]$Receipt.dependency_process_and_audit_path_count -eq
            [int64]$Expected.dependency_process_and_audit_path_count -and
        [int64]$Receipt.qualified_source_path_count -eq $ExpectedSourceCount -and
        [string]$Receipt.qualified_source_path_sha256 -ceq
            [string]$Expected.qualified_source_path_sha256 -and
        [int64]$Receipt.dependency_mutation_rejection_count -eq 4 -and
        [bool]$Receipt.dependency_all_qualified_paths_lf_checkout_policy -and
        [bool]$Receipt.dependency_all_qualified_paths_tracked -and
        [bool]$Receipt.dependency_tracked_source_required -and
        [bool]$Receipt.runtime_identity_exact_across_supervisors -and
        $receiptRuntimeCanonical -ceq $qualificationRuntimeCanonical -and
        [int64]$Receipt.preregistration_count -eq 2 -and
        [int64]$Receipt.supervisor_preflight_count -eq 2 -and
        [int64]$Receipt.serialized_conformance_lock_count -eq 2 -and
        [bool]$Receipt.final_operation_lock_release_probe_passed -and
        [int64]$Receipt.official_descriptor_compile_count_per_supervisor -eq 12 -and
        [int64]$Receipt.development_ghost_descriptor_compile_count_per_supervisor -eq 1 -and
        [int64]$Receipt.source_mutation_control_count_per_supervisor -eq 32 -and
        [int64]$Receipt.worker_authorization_type_mutation_refusal_count -eq 2 -and
        [int64]$Receipt.authority_contract_positive_repository_graph_count -eq 2 -and
        [int64]$Receipt.authority_contract_content_mutation_rejection_count -eq 35 -and
        [int64]$Receipt.authority_contract_repository_binding_rejection_count -eq 5 -and
        [int64]$Receipt.physical_missing_authority_refusal_count -eq 2 -and
        [int64]$Receipt.held_out_locomotion_outcome_exposure_count -eq 0 -and
        [int64]$Receipt.model_construction_count -eq 0 -and
        [int64]$Receipt.world_attempt_count -eq 0 -and
        [int64]$Receipt.world_build_count -eq 0 -and
        [int64]$Receipt.native_readback_count -eq 0 -and
        [int64]$Receipt.solver_step_count -eq 0 -and
        -not [bool]$Receipt.physics_state_modified -and
        -not [bool]$Receipt.physical_execution_authorized -and
        -not [bool]$Receipt.physical_acceptance_authority -and
        -not [bool]$Receipt.release_authority -and
        [bool]$qualificationEvidence.dependency_closure_audit_passed -eq
            [bool]$Receipt.dependency_closure_audit_passed -and
        [bool]$qualificationEvidence.dependency_all_qualified_paths_lf_checkout_policy -eq
            [bool]$Receipt.dependency_all_qualified_paths_lf_checkout_policy -and
        [int64]$qualificationEvidence.qualified_source_path_count -eq
            [int64]$Receipt.qualified_source_path_count -and
        [string]$qualificationEvidence.qualified_source_path_sha256 -ceq
            [string]$Receipt.qualified_source_path_sha256 -and
        [bool]$qualificationEvidence.runtime_identity_exact_across_supervisors -eq
            [bool]$Receipt.runtime_identity_exact_across_supervisors
    )
    if (-not $exact) {
        Throw-SporeSporeR05EAuthorityFailure "qualification_receipt_content"
    }
}

function Assert-SporeSporeR05EExecutionAuthority {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Head,
        [Parameter(Mandatory)][string]$AuthorityPath,
        [Parameter(Mandatory)][string]$QualificationClosurePath,
        [Parameter(Mandatory)][string]$EvidenceRoot,
        [Parameter(Mandatory)][string[]]$QualifiedSourcePaths,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Expected
    )

    $repo = [IO.Path]::GetFullPath($RepoRoot)
    $authorityRelative = ([string]$Expected.authority_path).Replace("\", "/")
    $qualificationRelative = ([string]$Expected.qualification_closure_path).Replace("\", "/")
    $expectedAuthorityPath = [IO.Path]::GetFullPath((Join-Path $repo $authorityRelative))
    $expectedQualificationPath = [IO.Path]::GetFullPath((
        Join-Path $repo $qualificationRelative
    ))
    if ([IO.Path]::GetFullPath($AuthorityPath) -cne $expectedAuthorityPath) {
        Throw-SporeSporeR05EAuthorityFailure "authority_path"
    }
    if ([IO.Path]::GetFullPath($QualificationClosurePath) -cne $expectedQualificationPath) {
        Throw-SporeSporeR05EAuthorityFailure "qualification_path"
    }
    if (-not (Test-Path -LiteralPath $expectedAuthorityPath -PathType Leaf)) {
        Throw-SporeSporeR05EAuthorityFailure "authority_missing"
    }
    if (-not (Test-Path -LiteralPath $expectedQualificationPath -PathType Leaf)) {
        Throw-SporeSporeR05EAuthorityFailure "qualification_missing"
    }
    if (-not (Test-SporeSporeR05ELowerHex -Value $Head -Length 40)) {
        Throw-SporeSporeR05EAuthorityFailure "head_shape"
    }

    $parentText = Invoke-SporeSporeR05EGit `
        -RepoRoot $repo `
        -Arguments @("rev-list", "--parents", "-n", "1", $Head) `
        -Code "authorization_parent"
    $parentParts = @($parentText -split ' ' | Where-Object { $_ })
    if ($parentParts.Count -ne 2 -or [string]$parentParts[0] -cne $Head) {
        Throw-SporeSporeR05EAuthorityFailure "authorization_parent"
    }
    $authorizationParent = [string]$parentParts[1]

    $changedText = Invoke-SporeSporeR05EGit `
        -RepoRoot $repo `
        -Arguments @(
            "diff-tree", "--no-commit-id", "--name-only", "--no-renames", "-r", $Head
        ) `
        -Code "authorization_commit_diff" `
        -AllowEmpty
    $changedPaths = @(
        $changedText -split "`n" |
            ForEach-Object { $_.Trim().Replace("\", "/") } |
            Where-Object { $_ }
    )
    if ($changedPaths.Count -ne 1 -or [string]$changedPaths[0] -cne $authorityRelative) {
        Throw-SporeSporeR05EAuthorityFailure "authorization_commit_not_authority_only"
    }

    foreach ($relative in @($authorityRelative, $qualificationRelative)) {
        $tracked = Invoke-SporeSporeR05EGit `
            -RepoRoot $repo `
            -Arguments @("ls-files", "--error-unmatch", $relative) `
            -Code "tracked_binding"
        if ($tracked.Replace("\", "/") -cne $relative) {
            Throw-SporeSporeR05EAuthorityFailure "tracked_binding"
        }
        $workingBlob = Invoke-SporeSporeR05EGit `
            -RepoRoot $repo `
            -Arguments @("hash-object", $relative) `
            -Code "working_blob"
        $headBlob = Invoke-SporeSporeR05EGit `
            -RepoRoot $repo `
            -Arguments @("rev-parse", "$Head`:$relative") `
            -Code "head_blob"
        if ($workingBlob -cne $headBlob) {
            Throw-SporeSporeR05EAuthorityFailure "working_tree_blob_drift"
        }
    }

    $sourceFreeze = [string](
        Get-Content -Raw -LiteralPath $expectedQualificationPath |
            ConvertFrom-Json -AsHashtable -Depth 100
    ).source.source_freeze_commit
    if (-not (Test-SporeSporeR05ELowerHex -Value $sourceFreeze -Length 40)) {
        Throw-SporeSporeR05EAuthorityFailure "source_freeze_shape"
    }
    & git -C $repo merge-base --is-ancestor $sourceFreeze $authorizationParent 2>&1 |
        Out-Null
    if ($LASTEXITCODE -ne 0) {
        Throw-SporeSporeR05EAuthorityFailure "source_freeze_not_ancestor"
    }
    $qualificationParentText = Invoke-SporeSporeR05EGit `
        -RepoRoot $repo `
        -Arguments @("rev-list", "--parents", "-n", "1", $authorizationParent) `
        -Code "qualification_parent"
    $qualificationParentParts = @(
        $qualificationParentText -split ' ' | Where-Object { $_ }
    )
    if (
        $qualificationParentParts.Count -ne 2 -or
        [string]$qualificationParentParts[0] -cne $authorizationParent -or
        [string]$qualificationParentParts[1] -cne $sourceFreeze
    ) {
        Throw-SporeSporeR05EAuthorityFailure "qualification_not_direct_source_child"
    }
    $qualificationChangedText = Invoke-SporeSporeR05EGit `
        -RepoRoot $repo `
        -Arguments @(
            "diff-tree", "--no-commit-id", "--name-only", "--no-renames",
            "-r", $authorizationParent
        ) `
        -Code "qualification_commit_diff" `
        -AllowEmpty
    $qualificationChangedPaths = @(
        $qualificationChangedText -split "`n" |
            ForEach-Object { $_.Trim().Replace("\", "/") } |
            Where-Object { $_ }
    )
    if (
        $qualificationChangedPaths.Count -ne 1 -or
        [string]$qualificationChangedPaths[0] -cne $qualificationRelative
    ) {
        Throw-SporeSporeR05EAuthorityFailure `
            "qualification_commit_not_closure_only"
    }

    $normalizedSources = @($QualifiedSourcePaths | ForEach-Object {
        ([string]$_).Replace("\", "/")
    })
    if (
        $normalizedSources.Count -eq 0 -or
        @($normalizedSources | Sort-Object -Unique).Count -ne $normalizedSources.Count -or
        $normalizedSources -ccontains $authorityRelative -or
        $normalizedSources -ccontains $qualificationRelative
    ) {
        Throw-SporeSporeR05EAuthorityFailure "qualified_source_path_set"
    }
    $qualifiedSourcePathSha256 = Get-SporeSporeR05ETextSha256 `
        -Text ($normalizedSources -join "`n")
    if (
        $normalizedSources.Count -ne [int]$Expected.qualified_source_path_count -or
        $qualifiedSourcePathSha256 -cne
            [string]$Expected.qualified_source_path_sha256
    ) {
        Throw-SporeSporeR05EAuthorityFailure "qualified_source_path_digest"
    }
    $sourceBindings = @(
        foreach ($relative in $normalizedSources) {
            $absolute = [IO.Path]::GetFullPath((Join-Path $repo $relative))
            if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) {
                Throw-SporeSporeR05EAuthorityFailure "qualified_source_missing"
            }
            $freezeBlob = Invoke-SporeSporeR05EGit `
                -RepoRoot $repo `
                -Arguments @("rev-parse", "$sourceFreeze`:$relative") `
                -Code "qualified_source_missing_at_freeze"
            $headBlob = Invoke-SporeSporeR05EGit `
                -RepoRoot $repo `
                -Arguments @("rev-parse", "$Head`:$relative") `
                -Code "qualified_source_missing_at_head"
            $workingBlob = Invoke-SporeSporeR05EGit `
                -RepoRoot $repo `
                -Arguments @("hash-object", $relative) `
                -Code "qualified_source_working_blob"
            if ($freezeBlob -cne $headBlob -or $workingBlob -cne $headBlob) {
                Throw-SporeSporeR05EAuthorityFailure "qualified_source_drift"
            }
            [ordered]@{
                path = $relative
                git_blob_oid = $headBlob
                raw_sha256 = Get-SporeSporeR05ERawSha256 $absolute
                byte_length = [int64](Get-Item -LiteralPath $absolute).Length
            }
        }
    )

    $qualificationRawSha256 = Get-SporeSporeR05ERawSha256 $expectedQualificationPath
    $qualificationGitBlobOid = Invoke-SporeSporeR05EGit `
        -RepoRoot $repo `
        -Arguments @("rev-parse", "$Head`:$qualificationRelative") `
        -Code "qualification_blob"
    $authority = Get-Content -Raw -LiteralPath $expectedAuthorityPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    $qualification = Get-Content -Raw -LiteralPath $expectedQualificationPath |
        ConvertFrom-Json -AsHashtable -Depth 100

    $expectedWithRuntime = [ordered]@{}
    foreach ($key in $Expected.Keys) {
        $expectedWithRuntime[[string]$key] = $Expected[$key]
    }
    $expectedWithRuntime["authorization_parent_commit"] = $authorizationParent
    $expectedWithRuntime["source_freeze_commit"] = $sourceFreeze
    $implementationAuditSha256 = ""
    foreach ($binding in $sourceBindings) {
        if (
            [string]$binding["path"] -ceq
                "sdk/conformance/qsdk_r05e_zero_world_implementation.py"
        ) {
            $implementationAuditSha256 = [string]$binding["raw_sha256"]
            break
        }
    }
    $expectedWithRuntime["implementation_audit_sha256"] = $implementationAuditSha256
    if ([string]::IsNullOrWhiteSpace(
        [string]$expectedWithRuntime.implementation_audit_sha256
    )) {
        Throw-SporeSporeR05EAuthorityFailure "implementation_audit_not_qualified"
    }

    $projection = Assert-SporeSporeR05EAuthorityContent `
        -Authority $authority `
        -Qualification $qualification `
        -Expected $expectedWithRuntime `
        -ExpectedSourceBindings $sourceBindings `
        -QualificationRawSha256 $qualificationRawSha256 `
        -QualificationGitBlobOid $qualificationGitBlobOid

    $evidence = [IO.Path]::GetFullPath($EvidenceRoot).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    $evidencePrefix = $evidence + [IO.Path]::DirectorySeparatorChar
    $outputPath = [IO.Path]::GetFullPath([string]$authority.output_report_path)
    if (-not $outputPath.StartsWith(
        $evidencePrefix,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        Throw-SporeSporeR05EAuthorityFailure "output_outside_evidence_root"
    }
    $qualificationReceiptPath = [IO.Path]::GetFullPath(
        [string]$qualification.qualification.qualification_receipt_path
    )
    if (
        -not $qualificationReceiptPath.StartsWith(
            $evidencePrefix,
            [StringComparison]::OrdinalIgnoreCase
        ) -or
        -not (Test-Path -LiteralPath $qualificationReceiptPath -PathType Leaf) -or
        (Get-SporeSporeR05ERawSha256 $qualificationReceiptPath) -cne
            [string]$qualification.qualification.qualification_receipt_sha256 -or
        [int64](Get-Item -LiteralPath $qualificationReceiptPath).Length -ne
            [int64]$qualification.qualification.qualification_receipt_byte_length
    ) {
        Throw-SporeSporeR05EAuthorityFailure "qualification_receipt_binding"
    }
    try {
        $qualificationReceipt = Get-Content -Raw -LiteralPath (
            $qualificationReceiptPath
        ) | ConvertFrom-Json -AsHashtable -Depth 100
    } catch {
        Throw-SporeSporeR05EAuthorityFailure "qualification_receipt_json"
    }
    if ($qualificationReceipt -isnot [System.Collections.IDictionary]) {
        Throw-SporeSporeR05EAuthorityFailure "qualification_receipt_type"
    }
    Assert-SporeSporeR05EQualificationReceipt `
        -Receipt $qualificationReceipt `
        -Qualification $qualification `
        -SourceFreeze $sourceFreeze `
        -ExpectedSourceCount $sourceBindings.Count `
        -Expected $expectedWithRuntime

    if ([bool]$Expected.development_route_ghost_complete) {
        $ghostRelative = ([string]$Expected.development_route_ghost_closure_path).
            Replace("\", "/")
        $ghostPath = [IO.Path]::GetFullPath((Join-Path $repo $ghostRelative))
        if (-not (Test-Path -LiteralPath $ghostPath -PathType Leaf)) {
            Throw-SporeSporeR05EAuthorityFailure "development_ghost_closure_missing"
        }
        $ghostWorkingBlob = Invoke-SporeSporeR05EGit `
            -RepoRoot $repo `
            -Arguments @("hash-object", $ghostRelative) `
            -Code "development_ghost_working_blob"
        $ghostHeadBlob = Invoke-SporeSporeR05EGit `
            -RepoRoot $repo `
            -Arguments @("rev-parse", "$Head`:$ghostRelative") `
            -Code "development_ghost_head_blob"
        if (
            $ghostWorkingBlob -cne $ghostHeadBlob -or
            $ghostHeadBlob -cne
                [string]$qualification.prerequisite.development_route_ghost_closure_git_blob_oid -or
            (Get-SporeSporeR05ERawSha256 $ghostPath) -cne
                [string]$qualification.prerequisite.development_route_ghost_closure_sha256
        ) {
            Throw-SporeSporeR05EAuthorityFailure "development_ghost_closure_binding"
        }
        $ghostProjection = Assert-SporeSporeR05EDevelopmentGhostClosure `
            -RepoRoot $repo `
            -Head $Head `
            -ClosurePath $ghostPath `
            -EvidenceRoot $evidence
        $projection["development_route_ghost"] = $ghostProjection
    }

    $projection["authorization_commit"] = $Head
    $projection["authorization_only_commit"] = $true
    $projection["authority_path"] = $authorityRelative
    $projection["authority_sha256"] = Get-SporeSporeR05ERawSha256 $expectedAuthorityPath
    $projection["qualification_closure_path"] = $qualificationRelative
    $projection["runtime_identity_sha256"] = [string](
        $qualification.runtime.identity_sha256
    )
    $projection["output_report_path"] = $outputPath
    return $projection
}

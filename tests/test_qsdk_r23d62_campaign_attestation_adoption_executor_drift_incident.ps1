#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$incidentPath = Join-Path $sdkRoot (
    "turning\r23d62_campaign_attestation_adoption_executor_drift_incident_v1.json"
)

. (Join-Path $sdkRoot "content_addressed_artifact_store.ps1")

function Assert-R23d62AdoptionDriftIncident(
    [bool]$Condition,
    [string]$Message
) {
    if (-not $Condition) {
        throw "QSDK_R23D62_ADOPTION_EXECUTOR_DRIFT_INCIDENT $Message"
    }
}

function Read-R23d62AdoptionDriftJson([string]$Path) {
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-R23d62AdoptionDriftSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Copy-R23d62AdoptionDriftDocument([object]$Value) {
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-R23d62AdoptionDriftGitBlobSha256(
    [string]$Commit,
    [string]$RelativePath
) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $repoRoot, "cat-file", "blob", "${Commit}:$RelativePath"
    )) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        Assert-R23d62AdoptionDriftIncident $process.Start() (
            "could not start Git blob reader"
        )
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try {
            $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream)
        } finally {
            $hasher.Dispose()
        }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23d62AdoptionDriftIncident ($process.ExitCode -eq 0) (
            "Git blob read failed for $RelativePath`: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally {
        $process.Dispose()
    }
}

function Read-R23d62AdoptionDriftGitJson(
    [string]$Commit,
    [string]$RelativePath
) {
    $text = (& git -C $repoRoot show "${Commit}:$RelativePath" 2>&1) -join "`n"
    Assert-R23d62AdoptionDriftIncident ($LASTEXITCODE -eq 0) (
        "could not read Git JSON: $RelativePath"
    )
    return $text | ConvertFrom-Json -AsHashtable -Depth 100
}

function Test-R23d62AdoptionDriftIncidentDocument(
    [Parameter(Mandatory)][System.Collections.IDictionary]$Document
) {
    $failures = [Collections.Generic.List[string]]::new()
    if ([string]$Document.schema_version -cne
            "sporespore_qsdk_r23d62_campaign_attestation_adoption_executor_drift_incident_v1" -or
        [string]$Document.status -cne
            "retained_zero_world_adoption_verification_refusal_requires_prospective_full_lca1_recommissioning" -or
        [string]$Document.campaign_id -cne
            "QSDK-R23D62-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION" -or
        [string]$Document.gate_id -cne "QSDK-R23D62" -or
        [string]$Document.release_gate_id -cne "QSDK-R23" -or
        [string]$Document.question_class -cne "finite_decision" -or
        ([datetime]$Document.recorded_utc).ToUniversalTime().ToString('o') -cne
            "2026-08-24T21:21:24.5346532Z") {
        $failures.Add("IDENTITY")
    }

    $source = $Document.qualified_source
    if ([string]$source.commit -cne
            "93d31e8eceeab519692f03470f20c9da5a86cc63" -or
        [string]$source.tree_git_oid -cne
            "145e485c1ad5a15126d3ac0d380ebb910707e392" -or
        [string]$source.branch -cne "main" -or
        [string]$source.origin_main -cne [string]$source.commit -or
        [string]$source.live_github_main -cne [string]$source.commit -or
        -not [bool]$source.worktree_clean) {
        $failures.Add("SOURCE")
    }

    $qualification = $Document.scoped_qualification
    if ([string]$qualification.status -cne
            "passed_complete_zero_world_not_adopted" -or
        [string]$qualification.raw_sha256 -cne
            "sha256:46e609462cb82d8d4b56c9c77f8d89f974160acfb011cf08c1b8dec46927eca0" -or
        [long]$qualification.byte_length -ne 106935 -or
        [int]$qualification.global_gate_count -ne 12 -or
        [int]$qualification.lineage_gate_count -ne 7 -or
        [int]$qualification.campaign_gate_count -ne 3 -or
        [int]$qualification.executed_gate_count -ne 22 -or
        [int]$qualification.gate_cas_reference_count -ne 66 -or
        [int]$qualification.gate_cas_unique_object_count -ne 46 -or
        -not [bool]$qualification.all_gates_executed -or
        -not [bool]$qualification.all_gate_streams_content_addressed -or
        [int]$qualification.physical_world_count -ne 0 -or
        -not [bool]$qualification.campaign_local_qualification_passed -or
        [bool]$qualification.physical_launch_prerequisite_satisfied -or
        [bool]$qualification.physical_acceptance_authority) {
        $failures.Add("QUALIFICATION")
    }

    $refusal = $Document.adoption_verification_refusal
    if ([string]$refusal.invocation_kind -cne
            "verified_inputs_with_create_only_output_path" -or
        [string]$refusal.failure_boundary -cne
            "commissioned_core_source_binding_verification_after_commissioning_closure_audit_and_before_adoption_document_creation" -or
        [string]$refusal.failure_message -cne
            "Commissioned executor source changed: sdk/run_conformance.ps1" -or
        [string]$refusal.failure_source_path -cne
            "sdk/locomotion_campaign_attestation_adoption.ps1" -or
        [int]$refusal.failure_source_line -ne 198 -or
        -not [bool]$refusal.commissioning_closure_audit_passed_first -or
        -not [bool]$refusal.adoption_output_path_requested -or
        [bool]$refusal.adoption_document_created -or
        [bool]$refusal.raw_process_transcript_was_separately_retained -or
        -not [bool]$refusal.record_reconstructed_from_observed_terminal_and_verified_files -or
        [bool]$refusal.operation_lock_acquired -or
        [int]$refusal.physical_process_launch_count -ne 0 -or
        [int]$refusal.model_construction_count -ne 0 -or
        [int]$refusal.world_attempt_count -ne 0 -or
        [int]$refusal.world_build_count -ne 0 -or
        [bool]$refusal.physical_attempt_consumed -or
        [bool]$refusal.same_source_adoption_retry_allowed) {
        $failures.Add("REFUSAL")
    }

    $preflight = $Document.post_refusal_rc8_candidate_preflight
    if (([datetime]$preflight.recorded_utc).ToUniversalTime().ToString('o') -cne
            "2026-08-24T21:30:05.1303288Z" -or
        [string]$preflight.invocation_kind -cne
            "direct_runtime_profile_candidate_preflight" -or
        [bool]$preflight.full_cold_half_started -or
        [bool]$preflight.scoped_half_started -or
        [bool]$preflight.pair_root_created -or
        [string]$preflight.failure_message -cne
            "PowerShell runtime profile file count or byte count changed." -or
        [string]$preflight.commissioned_powershell_version -cne "7.6.4" -or
        [string]$preflight.observed_powershell_version -cne "7.6.5" -or
        [string]$preflight.commissioned_framework_description -cne
            ".NET 10.0.10" -or
        [string]$preflight.observed_framework_description -cne
            ".NET 10.0.11" -or
        [string]$preflight.commissioned_powershell_executable_raw_sha256 -cne
            "sha256:db6dd81183fe57d22e03b911ec9a30a2fd7c40542e97743615355a6fb44f458f" -or
        [string]$preflight.observed_powershell_executable_raw_sha256 -cne
            "sha256:362a356ce7f0940ec74f73a8fc2c990a2cc24a38a11c90bbd8eca947110ad139" -or
        [int]$preflight.declared_powershell_file_count -ne 86 -or
        [int]$preflight.observed_powershell_file_count -ne 86 -or
        [long]$preflight.declared_powershell_byte_count -ne 85258167 -or
        [long]$preflight.observed_powershell_byte_count -ne 85306718 -or
        [long]$preflight.powershell_byte_delta -ne 48551 -or
        [string]$preflight.commissioned_powershell_inventory_sha256 -cne
            "sha256:805f538abafb574efb02104b41215b1c8e4c16404b90edb1ea3fce3ed4256ef3" -or
        [string]$preflight.observed_powershell_inventory_sha256 -cne
            "sha256:fbaa97db61be866688668c2d65fce95eb5e1e8b59f263b7b491689107764fff3" -or
        -not [bool]$preflight.windows_file_count_unchanged -or
        -not [bool]$preflight.windows_byte_count_unchanged -or
        -not [bool]$preflight.windows_ubr_unchanged -or
        -not [bool]$preflight.git_identity_unchanged -or
        -not [bool]$preflight.defender_identity_unchanged -or
        -not [bool]$preflight.runtime_profile_refresh_required_before_pair -or
        ([datetime]$preflight.subsequent_audit_dependency_reconciliation.recorded_utc).ToUniversalTime().ToString('o') -cne
            "2026-08-24T21:34:38.9611744Z" -or
        [string]$preflight.subsequent_audit_dependency_reconciliation.failure_message -cne
            "Audit-dependency registry no longer reconciles with CEP1." -or
        [int]$preflight.subsequent_audit_dependency_reconciliation.pre_reconciliation_declared_audit_count -ne 164 -or
        [int]$preflight.subsequent_audit_dependency_reconciliation.observed_audit_count -ne 167 -or
        [int]$preflight.subsequent_audit_dependency_reconciliation.post_reconciliation_declared_audit_count -ne 167 -or
        [int]$preflight.subsequent_audit_dependency_reconciliation.registered_audit_count -ne 1 -or
        [int]$preflight.subsequent_audit_dependency_reconciliation.complete_audit_count -ne 1 -or
        [int]$preflight.subsequent_audit_dependency_reconciliation.post_reconciliation_unregistered_audit_count -ne 166 -or
        (@($preflight.subsequent_audit_dependency_reconciliation.newly_reconciled_unregistered_audit_paths) -join "|") -cne
            "tests/test_qsdk_r23d62_dependency_closure.ps1|tests/test_qsdk_r24d8_active_step_snapshot_timing_positive_closure.ps1|tests/test_qsdk_r24d9_one_hinge_numerical_telemetry_physical_failure_closure.ps1" -or
        -not [bool]$preflight.subsequent_audit_dependency_reconciliation.historical_reconciliation_preserved -or
        [int]$preflight.subsequent_audit_dependency_reconciliation.dependency_registration_added_count -ne 0 -or
        [bool]$preflight.subsequent_audit_dependency_reconciliation.cache_lookup_permitted -or
        [bool]$preflight.subsequent_audit_dependency_reconciliation.result_reuse_permitted -or
        [int]$preflight.subsequent_audit_dependency_reconciliation.physical_world_count -ne 0 -or
        [int]$preflight.physical_process_launch_count -ne 0 -or
        [int]$preflight.model_construction_count -ne 0 -or
        [int]$preflight.world_attempt_count -ne 0 -or
        [int]$preflight.world_build_count -ne 0 -or
        [bool]$preflight.physical_authority) {
        $failures.Add("RUNTIME_PREFLIGHT")
    }

    $comparison = $Document.commissioned_executor_comparison
    if ([string]$comparison.commissioned_source_commit -cne
            "da5e35817d413b159dbb1665542de10c9ce76c46" -or
        [string]$comparison.commissioning_closure_raw_sha256 -cne
            "sha256:cd809da2a18508e923c1b7809d2d93b8c3a257ff246cd0e91014317bade549b5" -or
        [string]$comparison.commissioning_closure_audit_raw_sha256 -cne
            "sha256:dff0e6b44eee7c9673d3708291edf25d22df0bf8fbb9ba9961a8244dc46f31e7" -or
        [string]$comparison.adoption_contract_raw_sha256 -cne
            "sha256:3140940c63f50890a51648563527f3d1d237508aac245d119a3cae4197d112a4" -or
        [int]$comparison.declared_core_source_binding_count -ne 10 -or
        [int]$comparison.matching_core_source_binding_count -ne 9 -or
        [int]$comparison.mismatching_core_source_binding_count -ne 1 -or
        [string]$comparison.mismatching_path -cne "sdk/run_conformance.ps1" -or
        [string]$comparison.commissioned_raw_sha256 -cne
            "sha256:c02bd9b0fa222958ca475dee4ee264a90e246828fbb60595560fcd58e2318da7" -or
        [string]$comparison.observed_raw_sha256 -cne
            "sha256:905abe2043847afa5494efe624f97e6fcad86cd5a5d01375fa2b1495a03ef304" -or
        [string]$comparison.observed_git_blob_oid -cne
            "c72b75a76878258d2bce971743a792afa8d36247" -or
        [long]$comparison.observed_byte_length -ne 135961) {
        $failures.Add("COMPARISON")
    }

    $diagnosis = $Document.diagnosis
    $expectedFamilies = @(
        "r23d61_selected_actuator_profile_publication",
        "r23d62_selected_profile_three_engine_turning_declaration_evaluator_routes_and_godot_worker",
        "r24d1_canonical_prone_to_standing_design",
        "r24d2_portable_recovery_semantics",
        "r24d3_instrumented_motor_telemetry_source_and_cold_qualification",
        "r24d4_through_r24d6_one_hinge_telemetry_freezes_and_closures"
    )
    if (-not [bool]$diagnosis.executor_byte_drift_is_real -or
        -not [bool]$diagnosis.executor_drift_is_explained_by_retained_canonical_conformance_extensions -or
        [int]$diagnosis.net_line_additions_since_commissioned_source -ne 192 -or
        [int]$diagnosis.net_line_deletions_since_commissioned_source -ne 0 -or
        (@($diagnosis.extension_families) -join "|") -cne
            ($expectedFamilies -join "|") -or
        [int]$diagnosis.other_commissioned_core_source_binding_drift_count -ne 0 -or
        [bool]$diagnosis.adoption_verifier_reached_runtime_comparison -or
        -not [bool]$diagnosis.subsequent_rc8_candidate_preflight_found_runtime_drift -or
        [bool]$diagnosis.r23d62_manifest_or_campaign_role_defect -or
        [bool]$diagnosis.r23d62_controller_or_physics_defect -or
        [bool]$diagnosis.threshold_margin_or_cohort_defect -or
        [bool]$diagnosis.scientific_interpretation_available) {
        $failures.Add("DIAGNOSIS")
    }

    $successor = $Document.required_successor_boundary
    if ([string]$successor.program_id -cne
            "LCA1-RC8-CANONICAL-RUNNER-EXTENSION-RECOMMISSIONING" -or
        [string]$successor.question_class -cne "equivalence_non_inferiority" -or
        -not [bool]$successor.prospective_declaration_required -or
        -not [bool]$successor.complete_fresh_full_godot_v2_required -or
        -not [bool]$successor.fresh_scoped_lca1_required -or
        -not [bool]$successor.same_clean_pushed_source_and_runtime_required -or
        -not [bool]$successor.complete_cold_equivalence_baseline_required -or
        -not [bool]$successor.mutation_controls_required -or
        -not [bool]$successor.prospective_runtime_profile_refresh_required -or
        -not [bool]$successor.rc7_commissioning_closure_must_remain_immutable -or
        -not [bool]$successor.adoption_contract_must_not_repoint_before_positive_rc8_closure -or
        -not [bool]$successor.passing_r23d62_scoped_attestation_may_not_be_reused_after_source_change -or
        -not [bool]$successor.fresh_r23d62_qualification_and_adoption_required_after_recommissioning -or
        [bool]$successor.physical_worlds_may_open_before_recommissioning_and_fresh_adoption) {
        $failures.Add("SUCCESSOR")
    }

    $claims = $Document.claims
    $trueClaims = @(
        $claims.r23d62_scoped_qualification_passed_for_qualified_source
    )
    $falseClaimKeys = @(
        "r23d62_scoped_qualification_adopted",
        "campaign_local_attestation_implementation_commissioned_for_current_runner",
        "physical_launch_prerequisite_satisfied",
        "physical_campaign_executed",
        "scientific_result",
        "walking_acceptance",
        "turning_acceptance",
        "finite_three_engine_turning",
        "q_sdk_r23_satisfied",
        "cross_engine_equivalence",
        "prone_to_standing",
        "physical_acceptance_authority",
        "release_authority"
    )
    if (@($claims.Keys).Count -ne 14 -or
        @($trueClaims | Where-Object { -not [bool]$_ }).Count -ne 0 -or
        @($falseClaimKeys | Where-Object { [bool]$claims[$_] }).Count -ne 0) {
        $failures.Add("CLAIMS")
    }

    return [ordered]@{
        ok = $failures.Count -eq 0
        failure_codes = @($failures | Sort-Object -Unique)
    }
}

Assert-R23d62AdoptionDriftIncident (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$incident = Read-R23d62AdoptionDriftJson $incidentPath
$documentResult = Test-R23d62AdoptionDriftIncidentDocument $incident
Assert-R23d62AdoptionDriftIncident ([bool]$documentResult.ok) (
    "incident document changed: $(@($documentResult.failure_codes) -join ',')"
)

$mutations = @(
    @{ name = "status"; apply = { param($d) $d.status = "passed" } },
    @{ name = "question"; apply = { param($d) $d.question_class = "development" } },
    @{ name = "source"; apply = { param($d) $d.qualified_source.commit = "0" * 40 } },
    @{ name = "qualification_hash"; apply = { param($d) $d.scoped_qualification.raw_sha256 = "sha256:" + ("0" * 64) } },
    @{ name = "qualification_gates"; apply = { param($d) $d.scoped_qualification.executed_gate_count = 21 } },
    @{ name = "qualification_world"; apply = { param($d) $d.scoped_qualification.physical_world_count = 1 } },
    @{ name = "adoption_created"; apply = { param($d) $d.adoption_verification_refusal.adoption_document_created = $true } },
    @{ name = "transcript"; apply = { param($d) $d.adoption_verification_refusal.raw_process_transcript_was_separately_retained = $true } },
    @{ name = "retry"; apply = { param($d) $d.adoption_verification_refusal.same_source_adoption_retry_allowed = $true } },
    @{ name = "runtime_started"; apply = { param($d) $d.post_refusal_rc8_candidate_preflight.full_cold_half_started = $true } },
    @{ name = "runtime_version"; apply = { param($d) $d.post_refusal_rc8_candidate_preflight.observed_powershell_version = "7.6.4" } },
    @{ name = "runtime_bytes"; apply = { param($d) $d.post_refusal_rc8_candidate_preflight.observed_powershell_byte_count = 85258167 } },
    @{ name = "runtime_refresh"; apply = { param($d) $d.post_refusal_rc8_candidate_preflight.runtime_profile_refresh_required_before_pair = $false } },
    @{ name = "audit_count"; apply = { param($d) $d.post_refusal_rc8_candidate_preflight.subsequent_audit_dependency_reconciliation.observed_audit_count = 164 } },
    @{ name = "audit_reuse"; apply = { param($d) $d.post_refusal_rc8_candidate_preflight.subsequent_audit_dependency_reconciliation.result_reuse_permitted = $true } },
    @{ name = "matching"; apply = { param($d) $d.commissioned_executor_comparison.matching_core_source_binding_count = 10 } },
    @{ name = "mismatch"; apply = { param($d) $d.commissioned_executor_comparison.mismatching_core_source_binding_count = 0 } },
    @{ name = "mismatch_path"; apply = { param($d) $d.commissioned_executor_comparison.mismatching_path = "sdk/other.ps1" } },
    @{ name = "runner_hash"; apply = { param($d) $d.commissioned_executor_comparison.observed_raw_sha256 = "sha256:" + ("0" * 64) } },
    @{ name = "runner_lines"; apply = { param($d) $d.diagnosis.net_line_additions_since_commissioned_source = 191 } },
    @{ name = "other_core"; apply = { param($d) $d.diagnosis.other_commissioned_core_source_binding_drift_count = 1 } },
    @{ name = "controller"; apply = { param($d) $d.diagnosis.r23d62_controller_or_physics_defect = $true } },
    @{ name = "successor"; apply = { param($d) $d.required_successor_boundary.program_id = "LCA1-RC7" } },
    @{ name = "cold"; apply = { param($d) $d.required_successor_boundary.complete_cold_equivalence_baseline_required = $false } },
    @{ name = "profile_refresh"; apply = { param($d) $d.required_successor_boundary.prospective_runtime_profile_refresh_required = $false } },
    @{ name = "old_qualification"; apply = { param($d) $d.required_successor_boundary.passing_r23d62_scoped_attestation_may_not_be_reused_after_source_change = $false } },
    @{ name = "physical_open"; apply = { param($d) $d.required_successor_boundary.physical_worlds_may_open_before_recommissioning_and_fresh_adoption = $true } },
    @{ name = "turning"; apply = { param($d) $d.claims.turning_acceptance = $true } },
    @{ name = "gate"; apply = { param($d) $d.claims.q_sdk_r23_satisfied = $true } },
    @{ name = "release"; apply = { param($d) $d.claims.release_authority = $true } }
)
$mutationRefusals = 0
foreach ($mutation in $mutations) {
    $changed = Copy-R23d62AdoptionDriftDocument $incident
    & $mutation.apply $changed
    $result = Test-R23d62AdoptionDriftIncidentDocument $changed
    Assert-R23d62AdoptionDriftIncident (-not [bool]$result.ok) (
        "mutation was accepted: $($mutation.name)"
    )
    $mutationRefusals += 1
}

$sourceCommit = [string]$incident.qualified_source.commit
$comparison = $incident.commissioned_executor_comparison
Assert-R23d62AdoptionDriftIncident (
    (Get-R23d62AdoptionDriftGitBlobSha256 `
        -Commit $sourceCommit -RelativePath "sdk/run_conformance.ps1") -ceq
        [string]$comparison.observed_raw_sha256 -and
    (& git -C $repoRoot rev-parse "${sourceCommit}:sdk/run_conformance.ps1").Trim() -ceq
        [string]$comparison.observed_git_blob_oid -and
    [long](& git -C $repoRoot cat-file -s "${sourceCommit}:sdk/run_conformance.ps1") -eq
        [long]$comparison.observed_byte_length
) "observed runner Git identity changed"

$historicalContract = Read-R23d62AdoptionDriftGitJson `
    -Commit $sourceCommit `
    -RelativePath "sdk/locomotion_campaign_attestation_adoption_contract_v1.json"
Assert-R23d62AdoptionDriftIncident (
    (Get-R23d62AdoptionDriftGitBlobSha256 `
        -Commit $sourceCommit `
        -RelativePath "sdk/locomotion_campaign_attestation_adoption_contract_v1.json") -ceq
        [string]$comparison.adoption_contract_raw_sha256 -and
    @($historicalContract.commissioned_core_source_bindings).Count -eq 10
) "historical adoption contract changed"

$qualification = $incident.scoped_qualification
$qualificationPath = [IO.Path]::GetFullPath([string]$qualification.path)
Assert-R23d62AdoptionDriftIncident (
    (Test-Path -LiteralPath $qualificationPath -PathType Leaf) -and
    (Get-R23d62AdoptionDriftSha256 $qualificationPath) -ceq
        [string]$qualification.raw_sha256 -and
    (Get-Item -LiteralPath $qualificationPath).Length -eq
        [long]$qualification.byte_length
) "retained scoped qualification bytes changed"

$attestation = Read-R23d62AdoptionDriftJson $qualificationPath
Assert-R23d62AdoptionDriftIncident (
    [string]$attestation.status -ceq
        "campaign_local_godot_including_qualification_passed" -and
    -not [bool]$attestation.test_only -and
    [string]$attestation.campaign_id -ceq [string]$incident.campaign_id -and
    [string]$attestation.question_class -ceq "finite_decision" -and
    [int]$attestation.declared_physical_world_count -eq 9 -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq
        [string]$incident.qualified_source.tree_git_oid -and
    [bool]$attestation.source.clean_pushed_live -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 7 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    [int]$attestation.executed_gate_count -eq 22 -and
    [bool]$attestation.all_gates_executed -and
    [bool]$attestation.all_gate_streams_content_addressed -and
    -not [bool]$attestation.commissioned -and
    [bool]$attestation.claims.campaign_local_qualification_passed -and
    -not [bool]$attestation.claims.physical_launch_prerequisite_satisfied -and
    -not [bool]$attestation.claims.turning_acceptance -and
    -not [bool]$attestation.claims.release_authority
) "retained scoped qualification identity or claims changed"

$casReferences = [Collections.Generic.List[object]]::new()
foreach ($gate in @($attestation.gate_receipts)) {
    Assert-R23d62AdoptionDriftIncident (
        [bool]$gate.passed -and
        -not [bool]$gate.timed_out -and
        [int]$gate.exit_code -eq 0 -and
        [int]$gate.physical_process_launch_count -eq 0 -and
        [int]$gate.physical_world_count -eq 0 -and
        -not [bool]$gate.physical_acceptance_authority
    ) "qualification gate execution changed: $($gate.gate_id)"
    foreach ($kind in @("stdout_cas", "stderr_cas", "receipt_cas")) {
        $cas = $gate[$kind]
        $digest = ([string]$cas.sha256).Substring(7)
        Assert-R23d62AdoptionDriftIncident (
            Test-SporeSporeStoredArtifact `
                -Directory (Split-Path -Parent ([string]$cas.payload_path)) `
                -ExpectedSha256 $digest `
                -ExpectedByteLength ([long]$cas.byte_length)
        ) "qualification CAS changed: $($gate.gate_id)/$kind"
        $casReferences.Add($cas)
    }
}
$uniqueCas = @($casReferences.sha256 | Sort-Object -Unique)
Assert-R23d62AdoptionDriftIncident (
    $casReferences.Count -eq [int]$qualification.gate_cas_reference_count -and
    $uniqueCas.Count -eq [int]$qualification.gate_cas_unique_object_count
) "qualification CAS cardinality changed"

$historicalBindings = @($historicalContract.commissioned_core_source_bindings)
$candidateBindings = @($attestation.core_source_bindings)
$matching = 0
$mismatching = 0
foreach ($binding in $historicalBindings) {
    $candidate = @($candidateBindings | Where-Object {
        [string]$_.path -ceq [string]$binding.path
    })
    Assert-R23d62AdoptionDriftIncident ($candidate.Count -eq 1) (
        "candidate core binding missing: $($binding.path)"
    )
    if ([string]$candidate[0].raw_sha256 -ceq [string]$binding.raw_sha256) {
        $matching += 1
    } else {
        $mismatching += 1
        Assert-R23d62AdoptionDriftIncident (
            [string]$binding.path -ceq [string]$comparison.mismatching_path -and
            [string]$binding.raw_sha256 -ceq [string]$comparison.commissioned_raw_sha256 -and
            [string]$candidate[0].raw_sha256 -ceq [string]$comparison.observed_raw_sha256
        ) "unexpected commissioned core mismatch"
    }
}
Assert-R23d62AdoptionDriftIncident (
    $matching -eq [int]$comparison.matching_core_source_binding_count -and
    $mismatching -eq [int]$comparison.mismatching_core_source_binding_count
) "commissioned core comparison count changed"

Assert-R23d62AdoptionDriftIncident (
    -not (Test-Path -LiteralPath (
        [string]$incident.adoption_verification_refusal.requested_output_path
    ))
) "refused adoption output now exists"

Write-Host (
    "QSDK_R23D62_ADOPTION_EXECUTOR_DRIFT_INCIDENT_PASS " +
    "qualification_gates=22 cas_refs=$($casReferences.Count) " +
    "cas_unique=$($uniqueCas.Count) core_match=$matching " +
    "core_mismatch=$mismatching mutations=$mutationRefusals " +
    "models=0 worlds=0 physical_authority=False release_authority=False"
)

#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$freezePath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc5_freeze.json"
)
$manifestPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc5_manifest.json"
)
$incidentPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc4_incident.json"
)
$incidentAuditPath = Join-Path $repoRoot (
    "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc4_incident.ps1"
)

. (Join-Path $sdkRoot "conformance_dependency_key.ps1")
. (Join-Path $sdkRoot "conformance_runtime_profile.ps1")

function Assert-Lca1Rc5Freeze([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "LCA1_RC5_FREEZE $Message" }
}

function Read-Lca1Rc5Json([string]$Path) {
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-Lca1Rc5Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Copy-Lca1Rc5Document([object]$Value) {
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Test-Lca1Rc5FreezeDocument(
    [Parameter(Mandatory)][System.Collections.IDictionary]$Document
) {
    $failures = [Collections.Generic.List[string]]::new()
    if ([string]$Document.schema_version -cne
            "sporespore_locomotion_campaign_attestation_v1_recommissioning_rc5_freeze_v1" -or
        [string]$Document.status -cne
            "prospective_zero_world_workbench_proof_binding_repaired_complete_cold_full_scoped_pair_required" -or
        [string]$Document.program_id -cne
            "LCA1-RC5-WORKBENCH-PROOF-BINDING-REPAIRED-RECOMMISSIONING") {
        $failures.Add("IDENTITY")
    }
    if ([string]$Document.question_class -cne "equivalence_non_inferiority" -or
        [bool]$Document.physical_question) {
        $failures.Add("QUESTION")
    }
    $trigger = $Document.trigger
    if ([string]$trigger.rc4_status -cne
            "closed_negative_full_stage_1_workbench_proof_digest_mismatch_scoped_not_started" -or
        -not [bool]$trigger.rc4_full_half_attempted -or
        [bool]$trigger.rc4_pair_completed -or [bool]$trigger.rc4_scoped_attempted -or
        [bool]$trigger.rc4_commissioning_passed -or
        [bool]$trigger.rc4_same_source_rerun_allowed -or
        [int]$trigger.rc4_physical_world_count -ne 0) {
        $failures.Add("TRIGGER")
    }
    $repair = $Document.workbench_proof_binding_repair
    if ([string]$repair.catalog_path -cne
            "sdk/workbench/experiment_catalog.json" -or
        [string]$repair.catalog_raw_sha256 -cne
            "sha256:41e681f3ef4775663e55dcb376fa79cd7382922fae07bd7675d269918921f80d" -or
        [long]$repair.catalog_byte_length -ne 127429 -or
        [string]$repair.workbench_audit_raw_sha256 -cne
            "sha256:574e17b4ff569ad7d1441b95e3fb8991392e73eec3853104e0fdd4f68bd5d143" -or
        [long]$repair.workbench_audit_byte_length -ne 45104 -or
        [string]$repair.release_contract.raw_sha256 -cne
            "sha256:beeb50a154d07574daa98414f269b82b8b0f8fefe4c4294e69e583ca8c1c2a39" -or
        [long]$repair.release_contract.byte_length -ne 278786 -or
        [int]$repair.release_contract.catalog_reference_count -ne 4 -or
        [string]$repair.support_matrix.raw_sha256 -cne
            "sha256:7b77ef024f48db10089ed2e72ce5925c2dd93a9f06d5e3ca8b540593d2e2a36d" -or
        [long]$repair.support_matrix.byte_length -ne 452934 -or
        [int]$repair.support_matrix.catalog_reference_count -ne 4 -or
        [int]$repair.catalog_expected_sha256_field_repair_count -ne 8 -or
        -not [bool]$repair.every_repaired_proof_matches_current_ledger_bytes -or
        -not [bool]$repair.workbench_audit_passed_after_repair -or
        [string]$repair.workbench_audit_terminal_marker_prefix -cne
            "LOCOMOTION_EXPERIMENT_WORKBENCH_AUDIT_PASS " -or
        [bool]$repair.workbench_audit_source_changed -or
        [bool]$repair.executor_runner_source_changed -or
        [bool]$repair.physics_changed -or [bool]$repair.controller_changed -or
        [bool]$repair.gates_changed -or [bool]$repair.margins_changed -or
        [bool]$repair.claim_vector_changed) {
        $failures.Add("REPAIR")
    }
    $candidate = $Document.candidate_executor
    if ([string]$candidate.path -cne "sdk/run_conformance.ps1" -or
        [string]$candidate.raw_sha256 -cne
            "sha256:9fcf3e52451b7045a52e4b48f5119e8740abd9e2c9425b1686e49e60e5f1f349" -or
        [string]$candidate.git_blob_oid -cne
            "a662bc731846f037e8b3386fcb4c581d86b64745" -or
        [long]$candidate.byte_length -ne 127905 -or
        -not [bool]$candidate.runner_bytes_match_rc4_candidate -or
        [bool]$candidate.complete_source_tree_matches_rc4 -or
        [bool]$candidate.complete_transitive_dependency_key -or
        [bool]$candidate.declared_lca1_full_and_scoped_gate_set_change_from_rc4 -or
        [bool]$candidate.physics_change_from_rc4 -or
        [bool]$candidate.controller_change_from_rc4 -or
        [bool]$candidate.gate_change_from_rc4 -or
        [bool]$candidate.margin_change_from_rc4 -or
        [bool]$candidate.claim_vector_change_from_rc4 -or
        -not [bool]$candidate.workbench_proof_binding_repair_is_only_executor_dependency_change) {
        $failures.Add("EXECUTOR")
    }
    $runtime = $Document.accepted_runtime
    if ([string]$runtime.powershell_version -cne "7.6.4" -or
        [string]$runtime.powershell_edition -cne "Core" -or
        [string]$runtime.framework_description -cne ".NET 10.0.10" -or
        [int]$runtime.declared_file_count -ne 86 -or
        [long]$runtime.declared_byte_count -ne 85258167 -or
        [string]$runtime.declared_inventory_sha256 -cne
            "sha256:805f538abafb574efb02104b41215b1c8e4c16404b90edb1ea3fce3ed4256ef3" -or
        -not [bool]$runtime.runtime_profile_candidate_preflight_required -or
        -not [bool]$runtime.runtime_profile_candidate_preflight_must_pass -or
        [int]$runtime.outer_and_nested_runtime_identity_margin -ne 0 -or
        [int]$runtime.declared_inventory_count_and_byte_margin -ne 0) {
        $failures.Add("RUNTIME")
    }
    $pair = $Document.prospective_pair
    if ([int]$pair.pair_count -ne 1 -or -not [bool]$pair.serialized -or
        (@($pair.execution_order) -join "|") -cne
            "complete_full_godot_v2|scoped_lca1_rc5" -or
        -not [bool]$pair.same_clean_pushed_source_commit_and_tree_required -or
        -not [bool]$pair.outer_powershell_must_equal_accepted_runtime -or
        -not [bool]$pair.nested_powershell_must_equal_accepted_runtime -or
        -not [bool]$pair.runtime_profile_candidate_preflight_before_full_required -or
        [bool]$pair.cache_lookup_allowed -or [bool]$pair.prior_result_reuse_allowed -or
        [bool]$pair.selective_gate_execution_allowed -or
        [bool]$pair.same_source_rerun_after_complete_or_failed_pair_allowed -or
        [int]$pair.physical_process_launch_count -ne 0 -or
        [int]$pair.model_construction_count -ne 0 -or
        [int]$pair.world_build_count -ne 0) {
        $failures.Add("PAIR")
    }
    $acceptance = $Document.estimand_and_exact_acceptance
    if ([int]$acceptance.full_required_stage_count -ne 8 -or
        [int]$acceptance.full_allowed_failed_stage_count -ne 0 -or
        [int]$acceptance.scoped_required_global_gate_count -ne 12 -or
        [int]$acceptance.scoped_required_lineage_gate_count -ne 1 -or
        [int]$acceptance.scoped_required_campaign_role_gate_count -ne 3 -or
        [int]$acceptance.scoped_required_executed_gate_count -ne 16 -or
        [int]$acceptance.scoped_required_gate_cas_object_count -ne 48 -or
        @($acceptance.full_run_receipt_required_true_claim_keys).Count -ne 0 -or
        @($acceptance.full_v2_attestation_required_true_claim_keys).Count -ne 0 -or
        (@($acceptance.scoped_attestation_required_true_claim_keys) -join "|") -cne
            "campaign_local_qualification_passed" -or
        @($acceptance.scoped_attestation_required_false_claim_keys).Count -ne 10 -or
        [int]$acceptance.full_and_scoped_physical_world_count_required -ne 0 -or
        [int]$acceptance.numeric_equivalence_margin -ne 0 -or
        [int]$acceptance.marker_cardinality_margin -ne 0 -or
        [int]$acceptance.source_runtime_host_identity_margin -ne 0 -or
        [int]$acceptance.claim_vector_margin -ne 0 -or
        -not [bool]$acceptance.duration_ratio_is_descriptive_only -or
        [bool]$acceptance.duration_ratio_threshold_or_acceptance_role) {
        $failures.Add("ACCEPTANCE")
    }
    if (-not [bool]$Document.adequacy_argument.
            single_pair_is_adequate_for_exact_deterministic_executor_commissioning -or
        [bool]$Document.adequacy_argument.population_claim -or
        [bool]$Document.adequacy_argument.physics_equivalence_claim -or
        [bool]$Document.adequacy_argument.cross_engine_equivalence_claim -or
        [bool]$Document.adequacy_argument.movement_claim) {
        $failures.Add("ADEQUACY")
    }
    if (-not [bool]$Document.promotion_rule.
            positive_pair_must_be_closed_in_new_versioned_closure -or
        [string]$Document.promotion_rule.prospective_closure_path -cne
            "sdk/locomotion_campaign_attestation_v1_recommissioning_rc5_closure.json" -or
        -not [bool]$Document.promotion_rule.rc4_negative_remains_immutable -or
        [bool]$Document.promotion_rule.
            adoption_contract_may_reference_rc5_before_positive_closure_and_audit -or
        -not [bool]$Document.promotion_rule.
            fresh_r23d54_clean_pushed_qualification_and_adoption_required -or
        -not [bool]$Document.promotion_rule.
            physical_launch_before_fresh_r23d54_adoption_forbidden) {
        $failures.Add("PROMOTION")
    }
    if (@($Document.claims.Values | Where-Object { [bool]$_ }).Count -ne 0) {
        $failures.Add("CLAIMS")
    }
    return [ordered]@{
        ok = $failures.Count -eq 0
        failure_codes = @($failures | Sort-Object -Unique)
    }
}

Assert-Lca1Rc5Freeze (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$freeze = Read-Lca1Rc5Json $freezePath
$manifest = Read-Lca1Rc5Json $manifestPath
$incident = Read-Lca1Rc5Json $incidentPath
$documentTest = Test-Lca1Rc5FreezeDocument -Document $freeze
Assert-Lca1Rc5Freeze ([bool]$documentTest.ok) (
    "freeze document changed: $(@($documentTest.failure_codes) -join ',')"
)

$mutations = @(
    @{ name = "status"; apply = { param($d) $d.status = "passed" } },
    @{ name = "question"; apply = { param($d) $d.question_class = "development" } },
    @{ name = "trigger"; apply = { param($d) $d.trigger.rc4_pair_completed = $true } },
    @{ name = "catalog"; apply = { param($d) $d.workbench_proof_binding_repair.catalog_raw_sha256 = "sha256:" + ("0" * 64) } },
    @{ name = "repair_count"; apply = { param($d) $d.workbench_proof_binding_repair.catalog_expected_sha256_field_repair_count = 7 } },
    @{ name = "audit_change"; apply = { param($d) $d.workbench_proof_binding_repair.workbench_audit_source_changed = $true } },
    @{ name = "runner"; apply = { param($d) $d.candidate_executor.raw_sha256 = "sha256:" + ("0" * 64) } },
    @{ name = "tree"; apply = { param($d) $d.candidate_executor.complete_source_tree_matches_rc4 = $true } },
    @{ name = "runtime"; apply = { param($d) $d.accepted_runtime.powershell_version = "7.6.0-preview.6" } },
    @{ name = "pair_count"; apply = { param($d) $d.prospective_pair.pair_count = 2 } },
    @{ name = "reuse"; apply = { param($d) $d.prospective_pair.prior_result_reuse_allowed = $true } },
    @{ name = "full_count"; apply = { param($d) $d.estimand_and_exact_acceptance.full_required_stage_count = 7 } },
    @{ name = "scoped_count"; apply = { param($d) $d.estimand_and_exact_acceptance.scoped_required_executed_gate_count = 15 } },
    @{ name = "claim_true"; apply = { param($d) $d.estimand_and_exact_acceptance.scoped_attestation_required_true_claim_keys = @() } },
    @{ name = "claim_false"; apply = { param($d) $d.estimand_and_exact_acceptance.scoped_attestation_required_false_claim_keys = @($d.estimand_and_exact_acceptance.scoped_attestation_required_false_claim_keys)[0..8] } },
    @{ name = "margin"; apply = { param($d) $d.estimand_and_exact_acceptance.claim_vector_margin = 1 } },
    @{ name = "population"; apply = { param($d) $d.adequacy_argument.population_claim = $true } },
    @{ name = "authority"; apply = { param($d) $d.claims.release_authority = $true } }
)
$mutationRefusals = 0
foreach ($mutation in $mutations) {
    $copy = Copy-Lca1Rc5Document $freeze
    & $mutation.apply $copy
    $result = Test-Lca1Rc5FreezeDocument -Document $copy
    Assert-Lca1Rc5Freeze (-not [bool]$result.ok) (
        "freeze mutation was accepted: $($mutation.name)"
    )
    $mutationRefusals++
}

Assert-Lca1Rc5Freeze (
    (Get-Lca1Rc5Sha256 $incidentPath) -ceq
        [string]$freeze.trigger.rc4_incident_raw_sha256 -and
    (Get-Item -LiteralPath $incidentPath).Length -eq
        [long]$freeze.trigger.rc4_incident_byte_length -and
    (Get-Lca1Rc5Sha256 $incidentAuditPath) -ceq
        [string]$freeze.trigger.rc4_incident_audit_raw_sha256 -and
    (Get-Item -LiteralPath $incidentAuditPath).Length -eq
        [long]$freeze.trigger.rc4_incident_audit_byte_length -and
    [string]$incident.status -ceq [string]$freeze.trigger.rc4_status -and
    -not [bool]$incident.interpretation.same_source_rerun_authorized
) "RC4 negative trigger changed"

$repair = $freeze.workbench_proof_binding_repair
foreach ($binding in @(
    @{ path = $repair.catalog_path; hash = $repair.catalog_raw_sha256; bytes = $repair.catalog_byte_length },
    @{ path = $repair.workbench_audit_path; hash = $repair.workbench_audit_raw_sha256; bytes = $repair.workbench_audit_byte_length },
    @{ path = $repair.release_contract.path; hash = $repair.release_contract.raw_sha256; bytes = $repair.release_contract.byte_length },
    @{ path = $repair.support_matrix.path; hash = $repair.support_matrix.raw_sha256; bytes = $repair.support_matrix.byte_length },
    @{ path = $repair.freeze_audit_path; hash = $repair.freeze_audit_raw_sha256; bytes = $repair.freeze_audit_byte_length }
)) {
    $absolute = Join-Path $repoRoot ([string]$binding.path)
    Assert-Lca1Rc5Freeze (
        (Test-Path -LiteralPath $absolute -PathType Leaf) -and
        (Get-Lca1Rc5Sha256 $absolute) -ceq [string]$binding.hash -and
        (Get-Item -LiteralPath $absolute).Length -eq [long]$binding.bytes
    ) "RC5 repaired binding changed: $($binding.path)"
}

$catalog = Read-Lca1Rc5Json (Join-Path $repoRoot ([string]$repair.catalog_path))
$releaseReferences = [Collections.Generic.List[object]]::new()
$supportReferences = [Collections.Generic.List[object]]::new()
foreach ($run in @($catalog.runs)) {
    foreach ($proof in @($run.proofs)) {
        if ([string]$proof.path -ceq [string]$repair.release_contract.path) {
            $releaseReferences.Add($proof)
        }
        if ([string]$proof.path -ceq [string]$repair.support_matrix.path) {
            $supportReferences.Add($proof)
        }
    }
}
Assert-Lca1Rc5Freeze (
    $releaseReferences.Count -eq 4 -and
    @($releaseReferences.expected_sha256 | Sort-Object -Unique).Count -eq 1 -and
    ("sha256:" + [string]$releaseReferences[0].expected_sha256) -ceq
        [string]$repair.release_contract.raw_sha256 -and
    $supportReferences.Count -eq 4 -and
    @($supportReferences.expected_sha256 | Sort-Object -Unique).Count -eq 1 -and
    ("sha256:" + [string]$supportReferences[0].expected_sha256) -ceq
        [string]$repair.support_matrix.raw_sha256
) "RC5 catalog proof repair changed"

$incidentOutput = @(& pwsh -NoLogo -NoProfile -File $incidentAuditPath 2>&1)
Assert-Lca1Rc5Freeze (
    $LASTEXITCODE -eq 0 -and
    @($incidentOutput | Where-Object {
        [string]$_ -clike "LCA1_RC4_INCIDENT_PASS *"
    }).Count -eq 1
) "RC4 incident audit did not preserve the negative"

$workbenchAudit = Join-Path $repoRoot ([string]$repair.workbench_audit_path)
$workbenchOutput = @(& pwsh -NoLogo -NoProfile -File $workbenchAudit 2>&1)
Assert-Lca1Rc5Freeze (
    $LASTEXITCODE -eq 0 -and
    @($workbenchOutput | Where-Object {
        [string]$_ -clike "$($repair.workbench_audit_terminal_marker_prefix)*"
    }).Count -eq 1
) "repaired workbench audit did not pass exactly once"

$candidatePath = Join-Path $repoRoot ([string]$freeze.candidate_executor.path)
Assert-Lca1Rc5Freeze (
    (Get-Lca1Rc5Sha256 $candidatePath) -ceq
        [string]$freeze.candidate_executor.raw_sha256 -and
    (Get-Item -LiteralPath $candidatePath).Length -eq
        [long]$freeze.candidate_executor.byte_length -and
    (& git -C $repoRoot hash-object -- $candidatePath).Trim() -ceq
        [string]$freeze.candidate_executor.git_blob_oid
) "candidate executor bytes changed"

$runtime = $freeze.accepted_runtime
foreach ($role in @("profile_contract", "profile_registry", "profile_evaluator")) {
    $absolute = Join-Path $repoRoot ([string]$runtime[$role + "_path"])
    Assert-Lca1Rc5Freeze (
        (Get-Lca1Rc5Sha256 $absolute) -ceq
            [string]$runtime[$role + "_raw_sha256"]
    ) "runtime-profile source changed: $role"
}
$candidate = Get-SporeSporeConformanceRuntimeProfileCandidate -RepoRoot $repoRoot
$profile = @($candidate.profiles)[0]
Assert-Lca1Rc5Freeze (
    [string]$profile.profile_id -ceq [string]$runtime.profile_id -and
    [int]$profile.powershell.file_count -eq [int]$runtime.declared_file_count -and
    [long]$profile.powershell.byte_count -eq [long]$runtime.declared_byte_count -and
    [string]$profile.powershell.inventory_sha256 -ceq
        [string]$runtime.declared_inventory_sha256
) "accepted runtime-profile candidate changed"
$runtimeIdentity = & ([string]$runtime.outer_powershell_executable_path) `
    -NoLogo -NoProfile -Command (
        '$PSVersionTable.PSVersion.ToString() + "|" + ' +
        '$PSVersionTable.PSEdition + "|" + ' +
        '[Runtime.InteropServices.RuntimeInformation]::FrameworkDescription'
    )
Assert-Lca1Rc5Freeze (
    (Get-Lca1Rc5Sha256 ([string]$runtime.outer_powershell_executable_path)) -ceq
        [string]$runtime.outer_powershell_executable_raw_sha256 -and
    $runtimeIdentity -ceq (
        [string]$runtime.powershell_version + "|" +
        [string]$runtime.powershell_edition + "|" +
        [string]$runtime.framework_description
    )
) "accepted PowerShell executable changed"

Assert-Lca1Rc5Freeze (
    [string]$manifest.schema_version -ceq
        "sporespore_locomotion_campaign_attestation_manifest_v1" -and
    [string]$manifest.status -ceq "cold_commissioning_only" -and
    [string]$manifest.campaign_id -ceq [string]$freeze.program_id -and
    [string]$manifest.question_class -ceq "equivalence_non_inferiority" -and
    [int]$manifest.declared_physical_world_count -eq 0 -and
    -not [bool]$manifest.physical_launch_candidate -and
    [bool]$manifest.godot_including -and -not [bool]$manifest.skip_godot -and
    -not [bool]$manifest.physical_execution_authorized -and
    [int]$manifest.declared_lineage_gate_count -eq 1 -and
    [int]$manifest.declared_campaign_gate_count -eq 3 -and
    [int]$manifest.declared_total_gate_count -eq 4 -and
    [int]$manifest.declared_role_binding_count -eq 3 -and
    @($manifest.lineage_gates).Count -eq 1 -and
    @($manifest.campaign_gates).Count -eq 3 -and
    @($manifest.campaign_role_bindings).Count -eq 3 -and
    @($manifest.source_bindings).Count -eq 39 -and
    [string]$manifest.dependency_authority.path -ceq
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc5_freeze.json" -and
    [string]$manifest.dependency_authority.raw_sha256 -ceq
        (Get-Lca1Rc5Sha256 $freezePath) -and
    @($manifest.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "RC5 campaign manifest boundary changed"

$seenBindings = @{}
foreach ($binding in @($manifest.source_bindings)) {
    $path = [string]$binding.path
    Assert-Lca1Rc5Freeze (
        -not $seenBindings.ContainsKey($path)
    ) "duplicate manifest source binding: $path"
    $seenBindings[$path] = $true
    $absolute = Join-Path $repoRoot $path
    Assert-Lca1Rc5Freeze (
        (Test-Path -LiteralPath $absolute -PathType Leaf) -and
        (Get-Lca1Rc5Sha256 $absolute) -ceq [string]$binding.raw_sha256
    ) "manifest source binding changed: $path"
}

$requiredMarkers = $freeze.estimand_and_exact_acceptance.required_terminal_marker_counts
Assert-Lca1Rc5Freeze (
    @($requiredMarkers.Keys).Count -eq 4 -and
    @($requiredMarkers.Values | Where-Object { [int]$_ -ne 1 }).Count -eq 0
) "required marker cardinalities changed"

Write-Host (
    "LCA1_RC5_FREEZE_PASS class=equivalence_non_inferiority pairs=1 " +
    "runtime=7.6.4 runtime_files=86 runtime_bytes=85258167 " +
    "full_stages=8 scoped_gates=16 cas=48 markers=4 " +
    "workbench_proofs=8 scoped_true_claim=campaign_local_qualification_passed " +
    "claim_margin=0 prior_reuse=False mutations=$mutationRefusals " +
    "models=0 worlds=0 physical_authority=False release_authority=False"
)

#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$freezePath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc2_freeze.json"
)
$manifestPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc2_manifest.json"
)
$incidentPath = Join-Path $sdkRoot (
    "turning\r23d54_campaign_attestation_adoption_executor_drift_incident_v1.json"
)
$oldClosurePath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_commissioning_closure.json"
)
$oldClosureAuditPath = Join-Path $repoRoot (
    "tests\test_locomotion_campaign_attestation_v1_commissioning_closure.ps1"
)
$adoptionContractPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_adoption_contract_v1.json"
)
$runnerPath = Join-Path $sdkRoot "run_conformance.ps1"
$commissionedSource = "655d425b25606ca81cb821c8fdc61d7bf771d7af"

. (Join-Path $sdkRoot "locomotion_campaign_attestation.ps1")

function Assert-Lca1Rc2([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "LCA1_RC2_FREEZE $Message" }
}

function Read-Lca1Rc2Json([string]$Path) {
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-Lca1Rc2Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Copy-Lca1Rc2([object]$Value) {
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Test-Lca1Rc2FreezeDocument(
    [Parameter(Mandatory)][System.Collections.IDictionary]$Document
) {
    $failures = [Collections.Generic.List[string]]::new()
    if ([string]$Document.schema_version -cne
        "sporespore_locomotion_campaign_attestation_v1_recommissioning_rc2_freeze_v1") {
        $failures.Add("SCHEMA")
    }
    if ([string]$Document.status -cne
        "prospective_zero_world_complete_cold_full_scoped_pair_required") {
        $failures.Add("STATUS")
    }
    if ([string]$Document.program_id -cne
        "LCA1-RC2-EXPANDED-CANONICAL-RUNNER-RECOMMISSIONING" -or
        [string]$Document.question_class -cne "equivalence_non_inferiority" -or
        [bool]$Document.physical_question) {
        $failures.Add("QUESTION")
    }
    if ([int]$Document.prospective_pair.pair_count -ne 1 -or
        (@($Document.prospective_pair.execution_order) -join "|") -cne
            "complete_full_godot_v2|scoped_lca1_rc2" -or
        -not [bool]$Document.prospective_pair.serialized -or
        [bool]$Document.prospective_pair.cache_lookup_allowed -or
        [bool]$Document.prospective_pair.prior_result_reuse_allowed -or
        [bool]$Document.prospective_pair.selective_gate_execution_allowed -or
        [bool]$Document.prospective_pair.same_source_rerun_after_complete_or_failed_pair_allowed -or
        [int]$Document.prospective_pair.physical_process_launch_count -ne 0 -or
        [int]$Document.prospective_pair.model_construction_count -ne 0 -or
        [int]$Document.prospective_pair.world_build_count -ne 0) {
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
        [int]$acceptance.full_and_scoped_physical_world_count_required -ne 0 -or
        [double]$acceptance.numeric_equivalence_margin -ne 0.0 -or
        [int]$acceptance.marker_cardinality_margin -ne 0 -or
        [int]$acceptance.source_runtime_host_identity_margin -ne 0 -or
        -not [bool]$acceptance.duration_ratio_is_descriptive_only -or
        [bool]$acceptance.duration_ratio_threshold_or_acceptance_role) {
        $failures.Add("ACCEPTANCE")
    }
    $markers = $acceptance.required_terminal_marker_counts
    if (@($markers.Keys).Count -ne 4 -or
        [int]$markers.QSDK_R23D17_CLOSURE_PASS -ne 1 -or
        [int]$markers.LCA1_COMMISSIONING_WORKER_PASS -ne 1 -or
        [int]$markers.LCA1_COMMISSIONING_EVALUATOR_PASS -ne 1 -or
        [int]$markers.LCA1_COMMISSIONING_SUPERVISOR_PASS -ne 1) {
        $failures.Add("MARKERS")
    }
    if (-not [bool]$Document.adequacy_argument.
            single_pair_is_adequate_for_exact_deterministic_executor_commissioning -or
        [bool]$Document.adequacy_argument.population_claim -or
        [bool]$Document.adequacy_argument.physics_equivalence_claim -or
        [bool]$Document.adequacy_argument.cross_engine_equivalence_claim -or
        [bool]$Document.adequacy_argument.movement_claim) {
        $failures.Add("ADEQUACY")
    }
    if ([bool]$Document.development_calibration_only.
            complete_source_commit_and_tree_match_candidate_freeze -or
        [bool]$Document.development_calibration_only.transitive_dependency_key_complete -or
        [bool]$Document.development_calibration_only.reuse_as_rc2_full_baseline_allowed -or
        -not [bool]$Document.development_calibration_only.
            adequate_only_for_runtime_estimation_and_candidate_feasibility) {
        $failures.Add("REUSE")
    }
    if ([bool]$Document.immutable_prior_commissioning.
            old_closure_or_results_may_be_rewritten -or
        [bool]$Document.immutable_prior_commissioning.
            old_contract_may_be_repointed_before_rc2_positive_closure -or
        -not [bool]$Document.promotion_rule.
            positive_pair_must_be_closed_in_new_versioned_closure -or
        -not [bool]$Document.promotion_rule.
            fresh_r23d54_clean_pushed_qualification_and_adoption_required -or
        [bool]$Document.promotion_rule.
            physical_launch_before_fresh_r23d54_adoption_forbidden -ne $true) {
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

Assert-Lca1Rc2 (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$freeze = Read-Lca1Rc2Json $freezePath
$incident = Read-Lca1Rc2Json $incidentPath
$manifest = Get-SporeSporeCampaignAttestationManifest -Path $manifestPath
$oldClosure = Read-Lca1Rc2Json $oldClosurePath
$adoptionContract = Read-Lca1Rc2Json $adoptionContractPath
$freezeTest = Test-Lca1Rc2FreezeDocument -Document $freeze
Assert-Lca1Rc2 ([bool]$freezeTest.ok) (
    "prospective freeze changed: $(@($freezeTest.failure_codes) -join ',')"
)

$mutations = @(
    @{ name = "question_class"; apply = { param($d) $d.question_class = "development" } },
    @{ name = "pair_count"; apply = { param($d) $d.prospective_pair.pair_count = 2 } },
    @{ name = "prior_reuse"; apply = { param($d) $d.prospective_pair.prior_result_reuse_allowed = $true } },
    @{ name = "cache_lookup"; apply = { param($d) $d.prospective_pair.cache_lookup_allowed = $true } },
    @{ name = "full_stages"; apply = { param($d) $d.estimand_and_exact_acceptance.full_required_stage_count = 7 } },
    @{ name = "scoped_gates"; apply = { param($d) $d.estimand_and_exact_acceptance.scoped_required_executed_gate_count = 15 } },
    @{ name = "cas_count"; apply = { param($d) $d.estimand_and_exact_acceptance.scoped_required_gate_cas_object_count = 47 } },
    @{ name = "marker_margin"; apply = { param($d) $d.estimand_and_exact_acceptance.marker_cardinality_margin = 1 } },
    @{ name = "duration_threshold"; apply = { param($d) $d.estimand_and_exact_acceptance.duration_ratio_threshold_or_acceptance_role = $true } },
    @{ name = "world_count"; apply = { param($d) $d.prospective_pair.world_build_count = 1 } },
    @{ name = "rewrite_old"; apply = { param($d) $d.immutable_prior_commissioning.old_closure_or_results_may_be_rewritten = $true } },
    @{ name = "claim_inflation"; apply = { param($d) $d.claims.physical_acceptance_authority = $true } }
)
$mutationRefusals = 0
foreach ($mutation in $mutations) {
    $copy = Copy-Lca1Rc2 $freeze
    & $mutation.apply $copy
    $result = Test-Lca1Rc2FreezeDocument -Document $copy
    Assert-Lca1Rc2 (-not [bool]$result.ok) (
        "freeze mutation was accepted: $($mutation.name)"
    )
    $mutationRefusals++
}

Assert-Lca1Rc2 (
    [string]$incident.status -ceq
        "retained_zero_world_adoption_verification_refusal_requires_prospective_full_lca1_recommissioning" -and
    [string]$incident.qualified_source.commit -ceq
        "846295d1506626f7909d8045b992e2aa6a16f1c7" -and
    [string]$incident.adoption_verification_refusal.failure_message -ceq
        "Commissioned executor source changed: sdk/run_conformance.ps1" -and
    -not [bool]$incident.adoption_verification_refusal.adoption_document_created -and
    [int]$incident.adoption_verification_refusal.world_build_count -eq 0 -and
    -not [bool]$incident.adoption_verification_refusal.physical_attempt_consumed -and
    [int]$incident.commissioned_executor_comparison.declared_core_source_binding_count -eq 10 -and
    [int]$incident.commissioned_executor_comparison.matching_core_source_binding_count -eq 9 -and
    [int]$incident.commissioned_executor_comparison.mismatching_core_source_binding_count -eq 1 -and
    [string]$incident.commissioned_executor_comparison.mismatching_path -ceq
        "sdk/run_conformance.ps1" -and
    -not [bool]$incident.claims.r23d54_scoped_qualification_adopted -and
    -not [bool]$incident.claims.physical_launch_prerequisite_satisfied -and
    -not [bool]$incident.claims.physical_campaign_executed
) "R23D54 adoption-refusal incident changed"
Assert-Lca1Rc2 (
    (Get-Lca1Rc2Sha256 $incidentPath) -ceq [string]$freeze.trigger.incident_raw_sha256
) "incident digest changed"

$qualifiedPath = [string]$freeze.trigger.qualified_scoped_attestation_path
Assert-Lca1Rc2 (
    (Test-Path -LiteralPath $qualifiedPath -PathType Leaf) -and
    (Get-Lca1Rc2Sha256 $qualifiedPath) -ceq
        [string]$freeze.trigger.qualified_scoped_attestation_raw_sha256 -and
    (Get-Item -LiteralPath $qualifiedPath).Length -eq
        [long]$freeze.trigger.qualified_scoped_attestation_byte_length
) "qualified R23D54 scoped attestation bytes changed"
$qualified = Read-Lca1Rc2Json $qualifiedPath
Assert-Lca1Rc2 (
    [string]$qualified.source.commit -ceq
        [string]$freeze.trigger.qualified_source_commit -and
    [string]$qualified.source.tree_git_oid -ceq
        [string]$freeze.trigger.qualified_source_tree_git_oid -and
    [int]$qualified.executed_gate_count -eq 18 -and
    @($qualified.gate_receipts).Count -eq 18 -and
    @($qualified.gate_receipts | Where-Object {
        -not [bool]$_.passed -or [int]$_.physical_world_count -ne 0
    }).Count -eq 0 -and
    [bool]$qualified.all_gates_executed -and
    [bool]$qualified.all_gate_streams_content_addressed -and
    [bool]$qualified.claims.campaign_local_qualification_passed -and
    -not [bool]$qualified.claims.physical_launch_prerequisite_satisfied -and
    -not [bool]$qualified.claims.physical_campaign_executed
) "qualified R23D54 scoped attestation semantics changed"
$qualifiedCasCount = 0
foreach ($gate in @($qualified.gate_receipts)) {
    foreach ($field in @("stdout_cas", "stderr_cas", "receipt_cas")) {
        $cas = $gate[$field]
        $digest = ([string]$cas.sha256).Substring(7)
        Assert-Lca1Rc2 (
            Test-SporeSporeStoredArtifact `
                -Directory (Split-Path -Parent ([string]$cas.payload_path)) `
                -ExpectedSha256 $digest `
                -ExpectedByteLength ([long]$cas.byte_length)
        ) "qualified R23D54 gate CAS changed: $($gate.gate_id)/$field"
        $qualifiedCasCount++
    }
}
Assert-Lca1Rc2 ($qualifiedCasCount -eq 54) "qualified R23D54 CAS count changed"

Assert-Lca1Rc2 (
    (Get-Lca1Rc2Sha256 $oldClosurePath) -ceq
        [string]$freeze.immutable_prior_commissioning.closure_raw_sha256 -and
    (Get-Lca1Rc2Sha256 $oldClosureAuditPath) -ceq
        [string]$freeze.immutable_prior_commissioning.closure_audit_raw_sha256 -and
    (Get-Lca1Rc2Sha256 $adoptionContractPath) -ceq
        [string]$freeze.immutable_prior_commissioning.adoption_contract_raw_sha256 -and
    [string]$oldClosure.commissioned_implementation_source.commit -ceq
        $commissionedSource -and
    [bool]$oldClosure.comparison.commissioning_passed
) "immutable prior commissioning changed"

$bindingMismatches = [Collections.Generic.List[object]]::new()
foreach ($binding in @($adoptionContract.commissioned_core_source_bindings)) {
    $absolute = Join-Path $repoRoot ([string]$binding.path)
    $actual = Get-Lca1Rc2Sha256 $absolute
    if ($actual -cne [string]$binding.raw_sha256) {
        $bindingMismatches.Add([ordered]@{
            path = [string]$binding.path
            expected = [string]$binding.raw_sha256
            actual = $actual
        })
    }
}
Assert-Lca1Rc2 (
    @($adoptionContract.commissioned_core_source_bindings).Count -eq 10 -and
    $bindingMismatches.Count -eq 1 -and
    [string]$bindingMismatches[0].path -ceq "sdk/run_conformance.ps1" -and
    [string]$bindingMismatches[0].expected -ceq
        [string]$freeze.candidate_executor.commissioned_raw_sha256 -and
    [string]$bindingMismatches[0].actual -ceq
        [string]$freeze.candidate_executor.candidate_raw_sha256
) "live commissioned-executor drift negative control changed"

$runnerHash = Get-Lca1Rc2Sha256 $runnerPath
$runnerBlob = (& git -C $repoRoot hash-object -- $runnerPath).Trim()
$numstat = ((& git -C $repoRoot diff --numstat (
    $commissionedSource + "..HEAD"
) -- "sdk/run_conformance.ps1") -join "`n").Trim() -split "\s+"
Assert-Lca1Rc2 (
    $runnerHash -ceq [string]$freeze.candidate_executor.candidate_raw_sha256 -and
    $runnerBlob -ceq [string]$freeze.candidate_executor.candidate_git_blob_oid -and
    (Get-Item -LiteralPath $runnerPath).Length -eq
        [long]$freeze.candidate_executor.candidate_byte_length -and
    [int]$numstat[0] -eq 111 -and [int]$numstat[1] -eq 0
) "candidate canonical runner identity changed"
$runnerSource = Get-Content -Raw -LiteralPath $runnerPath
foreach ($requiredFragment in @(
    "test_godot_actuator_phase_observation_contract.ps1",
    "run_adaptation_experience_encyclopedia_conformance.ps1",
    "run_mujoco_warp_supported_subset_preflight.ps1",
    "run_mujoco_warp_equivalence_calibration_conformance.ps1",
    "run_mujoco_warp_semantic_ceiling_readiness_conformance.ps1",
    "run_mujoco_warp_metric_semantics_conformance.ps1",
    "run_mujoco_warp_observable_projection_conformance.ps1"
)) {
    Assert-Lca1Rc2 ($runnerSource.Contains($requiredFragment)) (
        "candidate runner lost explained extension: $requiredFragment"
    )
}
Assert-Lca1Rc2 (-not $runnerSource.Contains("r23d54_campaign")) (
    "campaign-specific R23D54 gates entered the permanent executor"
)

$priorReceiptPath = [string]$freeze.development_calibration_only.prior_receipt_path
$priorLogPath = [string]$freeze.development_calibration_only.prior_full_log_path
Assert-Lca1Rc2 (
    (Get-Lca1Rc2Sha256 $priorReceiptPath) -ceq
        [string]$freeze.development_calibration_only.prior_receipt_raw_sha256 -and
    (Get-Lca1Rc2Sha256 $priorLogPath) -ceq
        [string]$freeze.development_calibration_only.prior_full_log_raw_sha256
) "development calibration evidence changed"
$priorReceipt = Read-Lca1Rc2Json $priorReceiptPath
Assert-Lca1Rc2 (
    [string]$priorReceipt.status -ceq "passed" -and
    [string]$priorReceipt.source.head -ceq
        [string]$freeze.development_calibration_only.prior_full_conformance_source_commit -and
    [string]$priorReceipt.source.head_tree -ceq
        [string]$freeze.development_calibration_only.prior_full_conformance_source_tree_git_oid -and
    -not [bool]$priorReceipt.source.transitive_dependency_key_complete -and
    @($priorReceipt.stage_receipts).Count -eq 8 -and
    @($priorReceipt.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "development calibration receipt changed or became reusable"

Assert-Lca1Rc2 (
    [string]$manifest.campaign_id -ceq
        "LCA1-RC2-EXPANDED-CANONICAL-RUNNER-RECOMMISSIONING" -and
    [string]$manifest.question_class -ceq "equivalence_non_inferiority" -and
    [string]$manifest.status -ceq "cold_commissioning_only" -and
    [int]$manifest.declared_physical_world_count -eq 0 -and
    -not [bool]$manifest.physical_launch_candidate -and
    @($manifest.lineage_gates).Count -eq 1 -and
    @($manifest.campaign_gates).Count -eq 3 -and
    @($manifest.campaign_role_bindings).role -join "|" -ceq
        "worker|evaluator|supervisor" -and
    @($manifest.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "RC2 scoped manifest changed"
$candidate = Get-SporeSporeCampaignAttestationCandidate `
    -RepoRoot $repoRoot -ManifestPath $manifestPath -TestOnly
Assert-Lca1Rc2 (
    [int]$candidate.global_gate_count -eq 12 -and
    [int]$candidate.lineage_gate_count -eq 1 -and
    [int]$candidate.campaign_gate_count -eq 3 -and
    [bool]$candidate.campaign_roles_complete -and
    [bool]$candidate.godot_including -and
    -not [bool]$candidate.commissioned -and
    -not [bool]$candidate.physical_launch_prerequisite_satisfied -and
    -not [bool]$candidate.physical_acceptance_authority
) "RC2 scoped candidate projection changed"

Write-Host (
    "LCA1_RC2_FREEZE_PASS class=equivalence_non_inferiority pairs=1 " +
    "full_stages=8 scoped_gates=16 cas=48 markers=4 " +
    "executor_mismatches=1 prior_reuse=False mutations=$mutationRefusals " +
    "models=0 worlds=0 physical_authority=False release_authority=False"
)

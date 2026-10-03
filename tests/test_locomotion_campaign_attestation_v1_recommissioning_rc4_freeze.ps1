#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$freezePath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc4_freeze.json"
)
$manifestPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc4_manifest.json"
)
$runnerPath = Join-Path $sdkRoot "run_conformance.ps1"
$acceptedPowerShell = "C:\Program Files\PowerShell\7\pwsh.exe"

. (Join-Path $sdkRoot "locomotion_campaign_attestation.ps1")
. (Join-Path $sdkRoot "conformance_dependency_key.ps1")

function Assert-Lca1Rc4([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "LCA1_RC4_FREEZE $Message" }
}

function Read-Lca1Rc4Json([string]$Path) {
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-Lca1Rc4Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Copy-Lca1Rc4([object]$Value) {
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Test-Lca1Rc4FreezeDocument(
    [Parameter(Mandatory)][System.Collections.IDictionary]$Document
) {
    $failures = [Collections.Generic.List[string]]::new()
    if ([string]$Document.schema_version -cne
        "sporespore_locomotion_campaign_attestation_v1_recommissioning_rc4_freeze_v1" -or
        [string]$Document.status -cne
            "prospective_zero_world_schema_aligned_claim_vector_complete_cold_full_scoped_pair_required" -or
        [string]$Document.program_id -cne
            "LCA1-RC4-SCHEMA-ALIGNED-CLAIM-VECTOR-RECOMMISSIONING") {
        $failures.Add("IDENTITY")
    }
    if ([string]$Document.question_class -cne "equivalence_non_inferiority" -or
        [bool]$Document.physical_question) {
        $failures.Add("QUESTION")
    }
    $trigger = $Document.trigger
    if (-not [bool]$trigger.rc3_full_half_passed -or
        -not [bool]$trigger.rc3_scoped_half_passed -or
        -not [bool]$trigger.rc3_pair_completed -or
        [bool]$trigger.rc3_exact_acceptance_satisfied -or
        [bool]$trigger.rc3_commissioning_passed -or
        [bool]$trigger.rc3_same_source_rerun_allowed -or
        [int]$trigger.rc3_physical_world_count -ne 0) {
        $failures.Add("RC3_TRIGGER")
    }
    $prior = $Document.immutable_rc3_result
    if ([string]$prior.source_commit -cne
            "3cdc4a8cafecf40051c5f6dea1b186fccb991cc8" -or
        -not [bool]$prior.frozen_all_full_and_scoped_claims_must_remain_false -or
        [string]$prior.observed_scoped_true_claim_key -cne
            "campaign_local_qualification_passed" -or
        [bool]$prior.literal_frozen_claim_vector_condition_satisfied -or
        [bool]$prior.observed_result_or_interpretation_may_be_rewritten) {
        $failures.Add("RC3_IMMUTABLE")
    }
    $executor = $Document.candidate_executor
    if ([string]$executor.path -cne "sdk/run_conformance.ps1" -or
        [string]$executor.raw_sha256 -cne
            "sha256:9fcf3e52451b7045a52e4b48f5119e8740abd9e2c9425b1686e49e60e5f1f349" -or
        [string]$executor.git_blob_oid -cne
            "a662bc731846f037e8b3386fcb4c581d86b64745" -or
        [long]$executor.byte_length -ne 127905 -or
        -not [bool]$executor.runner_bytes_match_rc3_candidate -or
        [bool]$executor.complete_source_tree_matches_rc3 -or
        [bool]$executor.complete_transitive_dependency_key -or
        [bool]$executor.declared_lca1_full_and_scoped_gate_set_change_from_rc3 -or
        [bool]$executor.physics_change_from_rc3 -or
        [bool]$executor.controller_change_from_rc3 -or
        [bool]$executor.gate_change_from_rc3 -or
        [bool]$executor.margin_change_from_rc3 -or
        -not [bool]$executor.
            claim_vector_declaration_is_only_acceptance_semantic_change) {
        $failures.Add("EXECUTOR")
    }
    $runtime = $Document.accepted_runtime
    if ([string]$runtime.outer_powershell_executable_path -cne
            "C:/Program Files/PowerShell/7/pwsh.exe" -or
        [string]$runtime.outer_powershell_executable_raw_sha256 -cne
            "sha256:db6dd81183fe57d22e03b911ec9a30a2fd7c40542e97743615355a6fb44f458f" -or
        [string]$runtime.nested_powershell_executable_path -cne
            [string]$runtime.outer_powershell_executable_path -or
        [string]$runtime.nested_powershell_executable_raw_sha256 -cne
            [string]$runtime.outer_powershell_executable_raw_sha256 -or
        [string]$runtime.powershell_version -cne "7.6.4" -or
        [string]$runtime.powershell_edition -cne "Core" -or
        [string]$runtime.framework_description -cne ".NET 10.0.10" -or
        [string]$runtime.profile_id -cne
            "windows-powershell-git-r23d13-parent-child-v2" -or
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
    $calibration = $Document.rc3_development_calibration_only
    if (-not [bool]$calibration.same_candidate_executor_bytes -or
        -not [bool]$calibration.same_accepted_runtime -or
        -not [bool]$calibration.full_process_passed -or
        -not [bool]$calibration.scoped_process_passed -or
        [bool]$calibration.complete_source_commit_and_tree_match_rc4_freeze -or
        [bool]$calibration.transitive_dependency_key_complete -or
        [bool]$calibration.reuse_as_rc4_full_or_scoped_result_allowed -or
        -not [bool]$calibration.
            adequate_only_for_identifying_and_repairing_the_claim_vector_declaration) {
        $failures.Add("REUSE")
    }
    $pair = $Document.prospective_pair
    if ([int]$pair.pair_count -ne 1 -or
        (@($pair.execution_order) -join "|") -cne
            "complete_full_godot_v2|scoped_lca1_rc4" -or
        -not [bool]$pair.serialized -or
        -not [bool]$pair.same_clean_pushed_source_commit_and_tree_required -or
        -not [bool]$pair.same_godot_identity_required -or
        -not [bool]$pair.same_powershell_identity_required -or
        -not [bool]$pair.same_python_identity_required -or
        -not [bool]$pair.same_cargo_identity_required -or
        -not [bool]$pair.same_rustc_identity_required -or
        -not [bool]$pair.same_host_os_and_process_architecture_required -or
        -not [bool]$pair.runtime_profile_candidate_preflight_before_full_required -or
        [bool]$pair.cache_lookup_allowed -or
        [bool]$pair.prior_result_reuse_allowed -or
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
        -not [bool]$acceptance.
            successful_scoped_process_status_is_not_physical_or_scientific_authority -or
        -not [bool]$acceptance.
            all_authority_scientific_movement_coverage_and_release_claims_must_remain_false -or
        [int]$acceptance.full_and_scoped_physical_world_count_required -ne 0 -or
        [double]$acceptance.numeric_equivalence_margin -ne 0.0 -or
        [int]$acceptance.marker_cardinality_margin -ne 0 -or
        [int]$acceptance.source_runtime_host_identity_margin -ne 0 -or
        [int]$acceptance.claim_vector_margin -ne 0 -or
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
    if ([bool]$Document.immutable_prior_history.old_results_may_be_rewritten -or
        [bool]$Document.immutable_prior_history.
            old_adoption_contract_may_be_repointed_before_rc4_positive_closure -or
        -not [bool]$Document.promotion_rule.rc2_negative_remains_immutable -or
        -not [bool]$Document.promotion_rule.rc3_invalid_result_remains_immutable -or
        -not [bool]$Document.promotion_rule.
            positive_pair_must_be_closed_in_new_versioned_closure -or
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

Assert-Lca1Rc4 (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$freeze = Read-Lca1Rc4Json $freezePath
$freezeTest = Test-Lca1Rc4FreezeDocument -Document $freeze
Assert-Lca1Rc4 ([bool]$freezeTest.ok) (
    "prospective freeze changed: $(@($freezeTest.failure_codes) -join ',')"
)

$mutations = @(
    @{ name = "question_class"; apply = { param($d) $d.question_class = "development" } },
    @{ name = "rc3_acceptance"; apply = { param($d) $d.trigger.rc3_exact_acceptance_satisfied = $true } },
    @{ name = "rc3_rewrite"; apply = { param($d) $d.immutable_rc3_result.observed_result_or_interpretation_may_be_rewritten = $true } },
    @{ name = "executor_hash"; apply = { param($d) $d.candidate_executor.raw_sha256 = "sha256:" + ("0" * 64) } },
    @{ name = "executor_gate_set"; apply = { param($d) $d.candidate_executor.declared_lca1_full_and_scoped_gate_set_change_from_rc3 = $true } },
    @{ name = "runtime_bytes"; apply = { param($d) $d.accepted_runtime.declared_byte_count++ } },
    @{ name = "runtime_margin"; apply = { param($d) $d.accepted_runtime.declared_inventory_count_and_byte_margin = 1 } },
    @{ name = "prior_reuse"; apply = { param($d) $d.prospective_pair.prior_result_reuse_allowed = $true } },
    @{ name = "pair_count"; apply = { param($d) $d.prospective_pair.pair_count = 2 } },
    @{ name = "full_stages"; apply = { param($d) $d.estimand_and_exact_acceptance.full_required_stage_count = 7 } },
    @{ name = "scoped_gates"; apply = { param($d) $d.estimand_and_exact_acceptance.scoped_required_executed_gate_count = 15 } },
    @{ name = "cas_count"; apply = { param($d) $d.estimand_and_exact_acceptance.scoped_required_gate_cas_object_count = 47 } },
    @{ name = "claim_vector"; apply = { param($d) $d.estimand_and_exact_acceptance.scoped_attestation_required_true_claim_keys = @() } },
    @{ name = "claim_margin"; apply = { param($d) $d.estimand_and_exact_acceptance.claim_vector_margin = 1 } },
    @{ name = "duration_role"; apply = { param($d) $d.estimand_and_exact_acceptance.duration_ratio_threshold_or_acceptance_role = $true } },
    @{ name = "world_count"; apply = { param($d) $d.prospective_pair.world_build_count = 1 } },
    @{ name = "authority"; apply = { param($d) $d.claims.physical_acceptance_authority = $true } }
)
$mutationRefusals = 0
foreach ($mutation in $mutations) {
    $copy = Copy-Lca1Rc4 $freeze
    & $mutation.apply $copy
    $result = Test-Lca1Rc4FreezeDocument -Document $copy
    Assert-Lca1Rc4 (-not [bool]$result.ok) (
        "freeze mutation was accepted: $($mutation.name)"
    )
    $mutationRefusals++
}

foreach ($role in @("rc3_incident", "rc3_incident_audit")) {
    $pathKey = $role + "_path"
    $hashKey = $role + "_raw_sha256"
    $bytesKey = $role + "_byte_length"
    $absolute = Join-Path $repoRoot ([string]$freeze.trigger[$pathKey])
    Assert-Lca1Rc4 (
        (Get-Lca1Rc4Sha256 $absolute) -ceq
            [string]$freeze.trigger[$hashKey] -and
        (Get-Item -LiteralPath $absolute).Length -eq
            [long]$freeze.trigger[$bytesKey]
    ) "RC3 incident binding changed: $role"
}

foreach ($role in @("freeze", "manifest", "freeze_audit")) {
    $pathKey = $role + "_path"
    $hashKey = $role + "_raw_sha256"
    $bytesKey = $role + "_byte_length"
    $absolute = Join-Path $repoRoot (
        [string]$freeze.immutable_rc3_result[$pathKey]
    )
    Assert-Lca1Rc4 (
        (Get-Lca1Rc4Sha256 $absolute) -ceq
            [string]$freeze.immutable_rc3_result[$hashKey] -and
        (Get-Item -LiteralPath $absolute).Length -eq
            [long]$freeze.immutable_rc3_result[$bytesKey]
    ) "immutable RC3 preregistration changed: $role"
}

foreach ($role in @("full_run_receipt", "scoped_attestation")) {
    $pathKey = $role + "_path"
    $hashKey = $role + "_raw_sha256"
    $bytesKey = $role + "_byte_length"
    $path = [string]$freeze.immutable_rc3_result[$pathKey]
    Assert-Lca1Rc4 (
        (Get-Lca1Rc4Sha256 $path) -ceq
            [string]$freeze.immutable_rc3_result[$hashKey] -and
        (Get-Item -LiteralPath $path).Length -eq
            [long]$freeze.immutable_rc3_result[$bytesKey]
    ) "immutable RC3 evidence changed: $role"
}

foreach ($role in @(
    "rc2_incident",
    "rc2_incident_audit",
    "old_commissioning_closure",
    "old_commissioning_closure_audit",
    "adoption_contract"
)) {
    $absolute = Join-Path $repoRoot (
        [string]$freeze.immutable_prior_history[$role + "_path"]
    )
    Assert-Lca1Rc4 (
        (Get-Lca1Rc4Sha256 $absolute) -ceq
            [string]$freeze.immutable_prior_history[$role + "_raw_sha256"]
    ) "immutable prior history changed: $role"
}

$rc3IncidentOutput = @(& $acceptedPowerShell -NoLogo -NoProfile -File (
    Join-Path $repoRoot ([string]$freeze.trigger.rc3_incident_audit_path)
) 2>&1)
Assert-Lca1Rc4 (
    $LASTEXITCODE -eq 0 -and
    @($rc3IncidentOutput | Where-Object {
        ([string]$_).StartsWith(
            "LCA1_RC3_INCIDENT_PASS ",
            [StringComparison]::Ordinal
        )
    }).Count -eq 1
) "immutable RC3 incident audit failed"

$processPath = [IO.Path]::GetFullPath((Get-Process -Id $PID).Path)
$resolvedNested = [IO.Path]::GetFullPath((
    Get-Command pwsh -CommandType Application | Select-Object -First 1
).Source)
$runtimeIdentity = (
    $PSVersionTable.PSVersion.ToString() + "|" +
    $PSVersionTable.PSEdition + "|" +
    [Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
)
Assert-Lca1Rc4 (
    $processPath -ceq $acceptedPowerShell -and
    $resolvedNested -ceq $acceptedPowerShell -and
    (Get-Lca1Rc4Sha256 $acceptedPowerShell) -ceq
        [string]$freeze.accepted_runtime.outer_powershell_executable_raw_sha256 -and
    $runtimeIdentity -ceq "7.6.4|Core|.NET 10.0.10"
) "current outer or nested PowerShell is not the accepted runtime"

foreach ($role in @("profile_contract", "profile_registry", "profile_evaluator")) {
    $absolute = Join-Path $repoRoot (
        [string]$freeze.accepted_runtime[$role + "_path"]
    )
    Assert-Lca1Rc4 (
        (Get-Lca1Rc4Sha256 $absolute) -ceq
            [string]$freeze.accepted_runtime[$role + "_raw_sha256"]
    ) "accepted runtime-profile source changed: $role"
}
$registry = Get-SporeSporeConformanceRuntimeProfileRegistry
$profile = @($registry.profiles)[0]
$acceptedInventory = Get-SporeSporeDeclaredFileInventory `
    -Root (Split-Path -Parent $acceptedPowerShell) `
    -RelativePaths @($profile.powershell.relative_files) `
    -InventoryId "powershell_r23d13_parent"
$runtimeCandidate = Get-SporeSporeConformanceRuntimeProfileCandidate `
    -RepoRoot $repoRoot
Assert-Lca1Rc4 (
    [string]$profile.profile_id -ceq [string]$freeze.accepted_runtime.profile_id -and
    [int]$acceptedInventory.file_count -eq
        [int]$freeze.accepted_runtime.declared_file_count -and
    [long]$acceptedInventory.byte_count -eq
        [long]$freeze.accepted_runtime.declared_byte_count -and
    [string]$acceptedInventory.inventory_sha256 -ceq
        [string]$freeze.accepted_runtime.declared_inventory_sha256 -and
    [string]$runtimeCandidate.status -ceq
        "partial_runtime_profile_cache_disabled" -and
    [string]$runtimeCandidate.profiles[0].powershell.inventory_sha256 -ceq
        [string]$freeze.accepted_runtime.declared_inventory_sha256 -and
    -not [bool]$runtimeCandidate.cache_lookup_permitted -and
    -not [bool]$runtimeCandidate.result_reuse_permitted -and
    -not [bool]$runtimeCandidate.physical_authority
) "accepted runtime-profile preflight changed"

Assert-Lca1Rc4 (
    (Get-Lca1Rc4Sha256 $runnerPath) -ceq
        [string]$freeze.candidate_executor.raw_sha256 -and
    (& git -C $repoRoot hash-object -- $runnerPath).Trim() -ceq
        [string]$freeze.candidate_executor.git_blob_oid -and
    (Get-Item -LiteralPath $runnerPath).Length -eq
        [long]$freeze.candidate_executor.byte_length
) "candidate canonical runner identity changed"

$manifest = Get-SporeSporeCampaignAttestationManifest -Path $manifestPath
Assert-Lca1Rc4 (
    [string]$manifest.campaign_id -ceq [string]$freeze.program_id -and
    [string]$manifest.question_class -ceq "equivalence_non_inferiority" -and
    [string]$manifest.status -ceq "cold_commissioning_only" -and
    [int]$manifest.declared_physical_world_count -eq 0 -and
    -not [bool]$manifest.physical_launch_candidate -and
    @($manifest.lineage_gates).Count -eq 1 -and
    @($manifest.campaign_gates).Count -eq 3 -and
    @($manifest.campaign_role_bindings).role -join "|" -ceq
        "worker|evaluator|supervisor" -and
    @($manifest.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "RC4 scoped manifest changed"
$candidate = Get-SporeSporeCampaignAttestationCandidate `
    -RepoRoot $repoRoot -ManifestPath $manifestPath -TestOnly
Assert-Lca1Rc4 (
    [int]$candidate.global_gate_count -eq 12 -and
    [int]$candidate.lineage_gate_count -eq 1 -and
    [int]$candidate.campaign_gate_count -eq 3 -and
    [bool]$candidate.campaign_roles_complete -and
    [bool]$candidate.godot_including -and
    -not [bool]$candidate.commissioned -and
    -not [bool]$candidate.physical_launch_prerequisite_satisfied -and
    -not [bool]$candidate.physical_acceptance_authority
) "RC4 scoped candidate projection changed"

Write-Host (
    "LCA1_RC4_FREEZE_PASS class=equivalence_non_inferiority pairs=1 " +
    "runtime=7.6.4 runtime_files=86 runtime_bytes=85258167 " +
    "full_stages=8 scoped_gates=16 cas=48 markers=4 " +
    "scoped_true_claim=campaign_local_qualification_passed claim_margin=0 " +
    "prior_reuse=False mutations=$mutationRefusals models=0 worlds=0 " +
    "physical_authority=False release_authority=False"
)

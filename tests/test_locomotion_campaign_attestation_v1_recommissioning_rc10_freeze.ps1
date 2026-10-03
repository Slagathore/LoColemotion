#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$freezePath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc10_freeze.json"
)
$manifestPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc10_manifest.json"
)

. (Join-Path $sdkRoot "conformance_dependency_key.ps1")
. (Join-Path $sdkRoot "conformance_runtime_profile.ps1")

function Assert-Lca1Rc10Freeze([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "LCA1_RC10_FREEZE $Message" }
}

function Read-Lca1Rc10Json([string]$Path) {
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-Lca1Rc10Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Copy-Lca1Rc10Document([object]$Value) {
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Find-Lca1Rc10ObjectsWithKey {
    param(
        [Parameter(Mandatory)][AllowNull()][object]$Value,
        [Parameter(Mandatory)][string]$Key
    )
    $found = @()
    if ($null -eq $Value) { return $found }
    if ($Value -is [System.Collections.IDictionary]) {
        if ($Value.Contains($Key)) { $found += ,$Value }
        foreach ($child in $Value.Values) {
            $found += @(Find-Lca1Rc10ObjectsWithKey -Value $child -Key $Key)
        }
    } elseif ($Value -is [System.Collections.IEnumerable] -and
        $Value -isnot [string]) {
        foreach ($child in $Value) {
            $found += @(Find-Lca1Rc10ObjectsWithKey -Value $child -Key $Key)
        }
    }
    return $found
}

function Invoke-Lca1Rc10PowerShellMarker(
    [string]$Path,
    [string]$Marker,
    [string[]]$Arguments = @()
) {
    $output = @(& pwsh -NoLogo -NoProfile -File $Path @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    Assert-Lca1Rc10Freeze ($exitCode -eq 0) (
        "gate failed: $Path exit=$exitCode output=$($output -join ' | ')"
    )
    Assert-Lca1Rc10Freeze (
        @($output | Where-Object { [string]$_ -clike "$Marker*" }).Count -eq 1
    ) "gate marker cardinality changed: $Marker"
}

function Test-Lca1Rc10FreezeDocument(
    [Parameter(Mandatory)][System.Collections.IDictionary]$Document
) {
    $failures = [Collections.Generic.List[string]]::new()
    if ([string]$Document.schema_version -cne
            "sporespore_locomotion_campaign_attestation_v1_recommissioning_rc10_freeze_v1" -or
        [string]$Document.status -cne
            "prospective_zero_world_exact_same_source_full_scoped_pair_required" -or
        [string]$Document.program_id -cne
            "LCA1-RC10-R23D62-ROUTE-LIVE-AUTHORITY-RECONCILIATION") {
        $failures.Add("IDENTITY")
    }
    if ([string]$Document.question_class -cne "equivalence_non_inferiority" -or
        [bool]$Document.physical_question -or
        [bool]$Document.physical_campaign_opened) {
        $failures.Add("QUESTION")
    }

    $trigger = $Document.trigger
    if ([string]$trigger.rc9_source_commit -cne
            "8d55aad2b19d88d80455fc16ae9b9ce74cdd7b7e" -or
        [string]$trigger.rc9_source_tree_git_oid -cne
            "2da6b343a5b6197f3f3e286da7573e139bb6e412" -or
        [string]$trigger.rc9_incident_raw_sha256 -cne
            "sha256:c012ee33662aeadeeb54b0fa785f376d48a48e44b4e5ed34bfbe13576bb1b0b6" -or
        [string]$trigger.rc9_incident_audit_raw_sha256 -cne
            "sha256:2b489f31e1a591418e6618dddec728639d249cc58a8cb1d0a42b22974ac628a3" -or
        [string]$trigger.rc9_full_run_receipt_raw_sha256 -cne
            "sha256:98775688881bfcccf6e9288502a21b6c5a2757179ffa27e75ebd117837c9792f" -or
        [int]$trigger.rc9_full_passed_stage_count -ne 3 -or
        [int]$trigger.rc9_full_failed_stage_count -ne 1 -or
        [string]$trigger.rc9_first_failed_stage_id -cne
            "campaign_closures_and_zero_world_gates" -or
        [string]$trigger.rc9_inner_failure_code -cne
            "QSDK_R23D62_RAP_ROUTE_AUTHORITY_STATUS_INVALID" -or
        [bool]$trigger.rc9_scoped_attempted -or
        [int]$trigger.rc9_executed_mismatched_value_count -ne 2 -or
        [int]$trigger.rc9_prospectively_identified_same_defect_consumer_count -ne 3 -or
        [int]$trigger.rc9_physical_world_count -ne 0) {
        $failures.Add("TRIGGER")
    }

    $change = $Document.change_declaration
    if ([int]$change.live_authority_consumer_source_change_count -ne 4 -or
        [int]$change.expected_status_literal_change_count -ne 4 -or
        [int]$change.implementation_hash_binding_change_count -ne 3 -or
        [int]$change.canonical_runner_source_change_count -ne 0 -or
        [int]$change.runtime_profile_registry_field_change_count -ne 0 -or
        [int]$change.audit_dependency_count_change -ne 0 -or
        [int]$change.campaign_declaration_change_count -ne 0 -or
        [int]$change.campaign_evaluator_change_count -ne 0 -or
        [int]$change.campaign_worker_or_supervisor_source_change_count -ne 0 -or
        [int]$change.physics_change_count -ne 0 -or
        [int]$change.controller_semantics_change_count -ne 0 -or
        [int]$change.threshold_or_margin_change_count -ne 0 -or
        [bool]$change.physical_outcome_evaluated) {
        $failures.Add("CHANGE")
    }

    $candidate = $Document.candidate_executor
    if ([string]$candidate.path -cne "sdk/run_conformance.ps1" -or
        [string]$candidate.raw_sha256 -cne
            "sha256:905abe2043847afa5494efe624f97e6fcad86cd5a5d01375fa2b1495a03ef304" -or
        [string]$candidate.git_blob_oid -cne
            "c72b75a76878258d2bce971743a792afa8d36247" -or
        [long]$candidate.byte_length -ne 135961 -or
        -not [bool]$candidate.unchanged_from_rc9 -or
        -not [bool]$candidate.full_cold_recomputation_required -or
        [bool]$candidate.complete_transitive_dependency_key_claimed_before_pair) {
        $failures.Add("RUNNER")
    }

    $runtime = $Document.accepted_runtime
    if ([string]$runtime.powershell_version -cne "7.6.5" -or
        [string]$runtime.powershell_edition -cne "Core" -or
        [string]$runtime.framework_description -cne ".NET 10.0.11" -or
        [int]$runtime.declared_file_count -ne 86 -or
        [long]$runtime.declared_byte_count -ne 85306718 -or
        [string]$runtime.declared_inventory_sha256 -cne
            "sha256:fbaa97db61be866688668c2d65fce95eb5e1e8b59f263b7b491689107764fff3" -or
        [string]$runtime.runtime_profile_candidate_inventory_sha256 -cne
            "sha256:0b16b5d300144dc0a7227279991dbfbd6c2158aeb3d7669fd761456fba45fc75" -or
        -not [bool]$runtime.runtime_profile_candidate_preflight_required -or
        [int]$runtime.source_runtime_host_identity_margin -ne 0) {
        $failures.Add("RUNTIME")
    }

    $pair = $Document.prospective_pair
    if ([int]$pair.pair_count -ne 1 -or
        (@($pair.execution_order) -join "|") -cne
            "complete_full_godot_v2|scoped_lca1_rc10" -or
        -not [bool]$pair.serialized -or
        -not [bool]$pair.same_clean_pushed_source_commit_and_tree_required -or
        -not [bool]$pair.same_toolchain_runtime_and_host_required -or
        -not [bool]$pair.runtime_profile_candidate_preflight_before_full_required -or
        -not [bool]$pair.audit_dependency_candidate_preflight_before_full_required -or
        -not [bool]$pair.dependency_key_candidate_preflight_before_full_required -or
        -not [bool]$pair.freeze_audit_must_pass_before_full -or
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
        [int]$acceptance.scoped_required_gate_cas_reference_count -ne 48 -or
        (@($acceptance.scoped_attestation_required_true_claim_keys) -join "|") -cne
            "campaign_local_qualification_passed" -or
        @($acceptance.scoped_attestation_required_false_claim_keys).Count -ne 10 -or
        [int]$acceptance.full_and_scoped_physical_world_count_required -ne 0 -or
        [int]$acceptance.numeric_equivalence_margin -ne 0 -or
        [int]$acceptance.marker_cardinality_margin -ne 0 -or
        [int]$acceptance.source_runtime_host_identity_margin -ne 0 -or
        [int]$acceptance.claim_vector_margin -ne 0 -or
        [bool]$acceptance.duration_ratio_threshold_or_acceptance_role) {
        $failures.Add("ACCEPTANCE")
    }

    $provenance = $Document.threshold_and_margin_provenance
    if ([string]$provenance.origin -cne
            "inherited_exact_zero_margin_from_closed_lca1_rc7_process_commissioning" -or
        [bool]$provenance.fitted_from_rc8_or_rc9_failure_or_r23d62_physical_outcomes -or
        [bool]$provenance.relaxed_after_rc8_or_rc9 -or
        [int]$provenance.threshold_change_count -ne 0 -or
        [int]$provenance.margin_change_count -ne 0) {
        $failures.Add("PROVENANCE")
    }
    if (-not [bool]$Document.adequacy_argument.single_pair_is_adequate_for_exact_deterministic_executor_commissioning -or
        [bool]$Document.adequacy_argument.population_claim -or
        [bool]$Document.adequacy_argument.physics_equivalence_claim -or
        [bool]$Document.adequacy_argument.cross_engine_equivalence_claim -or
        [bool]$Document.adequacy_argument.movement_claim) {
        $failures.Add("ADEQUACY")
    }
    if ([int]$Document.exact_dependency_binding_count -ne 72 -or
        @($Document.exact_dependency_bindings).Count -ne 72) {
        $failures.Add("DEPENDENCIES")
    }
    if (-not [bool]$Document.promotion_rule.positive_pair_must_be_closed_in_new_versioned_closure -or
        [string]$Document.promotion_rule.prospective_closure_path -cne
            "sdk/locomotion_campaign_attestation_v1_recommissioning_rc10_closure.json" -or
        -not [bool]$Document.promotion_rule.rc8_and_rc9_negatives_remain_immutable -or
        [bool]$Document.promotion_rule.adoption_may_move_before_rc10_closure -or
        [bool]$Document.promotion_rule.physical_successor_may_open_before_rc10_closure) {
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

Assert-Lca1Rc10Freeze (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
Assert-Lca1Rc10Freeze (Test-Path -LiteralPath $Godot -PathType Leaf) (
    "Godot executable is missing: $Godot"
)

$freeze = Read-Lca1Rc10Json $freezePath
$manifest = Read-Lca1Rc10Json $manifestPath
Assert-Lca1Rc10Freeze (
    [IO.Path]::GetFullPath($Godot).Replace("\", "/") -ceq
        [string]$freeze.accepted_runtime.godot_executable_path
) "selected Godot path differs from the frozen runtime"
$documentTest = Test-Lca1Rc10FreezeDocument -Document $freeze
Assert-Lca1Rc10Freeze ([bool]$documentTest.ok) (
    "freeze document changed: $(@($documentTest.failure_codes) -join ',')"
)

$mutations = @(
    @{ name = "status"; apply = { param($d) $d.status = "passed" } },
    @{ name = "question"; apply = { param($d) $d.question_class = "development" } },
    @{ name = "incident"; apply = { param($d) $d.trigger.rc9_incident_raw_sha256 = "sha256:" + ("0" * 64) } },
    @{ name = "stages"; apply = { param($d) $d.trigger.rc9_full_passed_stage_count = 4 } },
    @{ name = "consumer"; apply = { param($d) $d.change_declaration.live_authority_consumer_source_change_count = 3 } },
    @{ name = "binding"; apply = { param($d) $d.change_declaration.implementation_hash_binding_change_count = 2 } },
    @{ name = "runner_change"; apply = { param($d) $d.change_declaration.canonical_runner_source_change_count = 1 } },
    @{ name = "campaign"; apply = { param($d) $d.change_declaration.campaign_evaluator_change_count = 1 } },
    @{ name = "threshold"; apply = { param($d) $d.change_declaration.threshold_or_margin_change_count = 1 } },
    @{ name = "runner"; apply = { param($d) $d.candidate_executor.raw_sha256 = "sha256:" + ("0" * 64) } },
    @{ name = "runtime"; apply = { param($d) $d.accepted_runtime.powershell_version = "7.6.4" } },
    @{ name = "order"; apply = { param($d) $d.prospective_pair.execution_order[1] = "scoped_lca1_rc9" } },
    @{ name = "reuse"; apply = { param($d) $d.prospective_pair.prior_result_reuse_allowed = $true } },
    @{ name = "rerun"; apply = { param($d) $d.prospective_pair.same_source_rerun_after_complete_or_failed_pair_allowed = $true } },
    @{ name = "full"; apply = { param($d) $d.estimand_and_exact_acceptance.full_required_stage_count = 7 } },
    @{ name = "scoped"; apply = { param($d) $d.estimand_and_exact_acceptance.scoped_required_executed_gate_count = 15 } },
    @{ name = "margin"; apply = { param($d) $d.estimand_and_exact_acceptance.claim_vector_margin = 1 } },
    @{ name = "provenance"; apply = { param($d) $d.threshold_and_margin_provenance.fitted_from_rc8_or_rc9_failure_or_r23d62_physical_outcomes = $true } },
    @{ name = "population"; apply = { param($d) $d.adequacy_argument.population_claim = $true } },
    @{ name = "dependencies"; apply = { param($d) $d.exact_dependency_binding_count = 71 } },
    @{ name = "promotion"; apply = { param($d) $d.promotion_rule.adoption_may_move_before_rc10_closure = $true } },
    @{ name = "claim"; apply = { param($d) $d.claims.turning_acceptance = $true } }
)
$mutationRefusals = 0
foreach ($mutation in $mutations) {
    $changed = Copy-Lca1Rc10Document $freeze
    & $mutation.apply $changed
    $result = Test-Lca1Rc10FreezeDocument -Document $changed
    Assert-Lca1Rc10Freeze (-not [bool]$result.ok) (
        "mutation was accepted: $($mutation.name)"
    )
    $mutationRefusals += 1
}

$bindings = @($freeze.exact_dependency_bindings)
$bindingPaths = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::Ordinal
)
foreach ($binding in $bindings) {
    $relativePath = [string]$binding.path
    Assert-Lca1Rc10Freeze ($bindingPaths.Add($relativePath)) (
        "duplicate exact dependency: $relativePath"
    )
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Lca1Rc10Freeze (
        (Test-Path -LiteralPath $absolutePath -PathType Leaf) -and
        (Get-Lca1Rc10Sha256 $absolutePath) -ceq [string]$binding.raw_sha256 -and
        (Get-Item -LiteralPath $absolutePath).Length -eq [long]$binding.byte_length
    ) "exact dependency changed: $relativePath"
}
Assert-Lca1Rc10Freeze ($bindingPaths.Count -eq 72) (
    "exact dependency cardinality changed"
)
foreach ($requiredPath in @(
    "sdk/run_conformance.ps1",
    "sdk/conformance_runtime_profile_registry_v1.json",
    "tests/test_conformance_runtime_profile.ps1",
    "sdk/conformance_audit_dependency_contract_v1.json",
    "sdk/conformance_audit_dependency_registry_v1.json",
    "sdk/conformance_dependency_contract_v1.json",
    "tests/test_conformance_audit_dependency.ps1",
    "tests/test_conformance_dependency_key.ps1",
    "sdk/locomotion_campaign_attestation_adoption_contract_v1.json",
    "sdk/locomotion_campaign_attestation_v1_recommissioning_rc8_incident.json",
    "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc8_incident.ps1",
    "sdk/locomotion_campaign_attestation_v1_recommissioning_rc9_incident.json",
    "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc9_incident.ps1",
    "tests/test_qsdk_r23d62_preregistration.ps1",
    "tests/test_qsdk_r23d62_rapier_public_profile_physical_route.py",
    "tests/test_qsdk_r23d62_godot_public_profile_physical_route.py",
    "tests/test_qsdk_r23d62_mujoco_public_profile_physical_route.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d62_selected_profile_turning_test.py",
    "sdk/turning/r23d62_selected_profile_three_engine_turning_validation_implementation_v1.json",
    "sdk/closure_evidence_provenance_contract.json",
    "tests/test_closure_evidence_provenance_contract.ps1",
    "sdk/closure_evidence_mode_inventory.json",
    "sdk/workbench/experiment_catalog.json",
    "tests/test_locomotion_experiment_workbench.ps1",
    "sdk/release/quadruped_release_contract.json",
    "sdk/release/quadruped_support_matrix.json",
    "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc10_freeze.ps1"
)) {
    Assert-Lca1Rc10Freeze ($bindingPaths.Contains($requiredPath)) (
        "required exact dependency omitted: $requiredPath"
    )
}

$runnerPath = Join-Path $repoRoot ([string]$freeze.candidate_executor.path)
Assert-Lca1Rc10Freeze (
    (Get-Lca1Rc10Sha256 $runnerPath) -ceq
        [string]$freeze.candidate_executor.raw_sha256 -and
    (& git -C $repoRoot hash-object -- $runnerPath).Trim() -ceq
        [string]$freeze.candidate_executor.git_blob_oid
) "candidate executor bytes changed"

$runtime = $freeze.accepted_runtime
foreach ($role in @("profile_contract", "profile_registry", "profile_evaluator")) {
    $absolutePath = Join-Path $repoRoot ([string]$runtime[$role + "_path"])
    Assert-Lca1Rc10Freeze (
        (Get-Lca1Rc10Sha256 $absolutePath) -ceq
            [string]$runtime[$role + "_raw_sha256"]
    ) "runtime-profile source changed: $role"
}
$runtimeCandidate = Get-SporeSporeConformanceRuntimeProfileCandidate `
    -RepoRoot $repoRoot
$profile = @($runtimeCandidate.profiles)[0]
Assert-Lca1Rc10Freeze (
    [string]$runtimeCandidate.inventory_sha256 -ceq
        [string]$runtime.runtime_profile_candidate_inventory_sha256 -and
    [string]$profile.profile_id -ceq [string]$runtime.profile_id -and
    [int]$profile.powershell.file_count -eq [int]$runtime.declared_file_count -and
    [long]$profile.powershell.byte_count -eq [long]$runtime.declared_byte_count -and
    [string]$profile.powershell.inventory_sha256 -ceq
        [string]$runtime.declared_inventory_sha256
) "accepted runtime-profile candidate changed"

foreach ($binding in @(
    [ordered]@{ path = $runtime.outer_powershell_executable_path; hash = $runtime.outer_powershell_executable_raw_sha256 },
    [ordered]@{ path = $runtime.godot_executable_path; hash = $runtime.godot_executable_raw_sha256 },
    [ordered]@{ path = $runtime.python_executable_path; hash = $runtime.python_executable_raw_sha256 },
    [ordered]@{ path = $runtime.git_executable_path; hash = $runtime.git_executable_raw_sha256 },
    [ordered]@{ path = $runtime.cargo_executable_path; hash = $runtime.cargo_executable_raw_sha256 },
    [ordered]@{ path = $runtime.rustc_executable_path; hash = $runtime.rustc_executable_raw_sha256 }
)) {
    Assert-Lca1Rc10Freeze (
        (Test-Path -LiteralPath ([string]$binding.path) -PathType Leaf) -and
        (Get-Lca1Rc10Sha256 ([string]$binding.path)) -ceq [string]$binding.hash
    ) "accepted runtime executable changed: $($binding.path)"
}

$cep1 = Read-Lca1Rc10Json (
    Join-Path $repoRoot "sdk/closure_evidence_mode_inventory.json"
)
$cadContract = Read-Lca1Rc10Json (
    Join-Path $repoRoot "sdk/conformance_audit_dependency_contract_v1.json"
)
$cadRegistry = Read-Lca1Rc10Json (
    Join-Path $repoRoot "sdk/conformance_audit_dependency_registry_v1.json"
)
Assert-Lca1Rc10Freeze (
    [int]$cep1.audit_count -eq 167 -and @($cep1.entries).Count -eq 167 -and
    [int]$cadContract.authority.cep1_audit_count -eq 167 -and
    [int]$cadContract.authority.registered_audit_count -eq 1 -and
    [int]$cadContract.authority.complete_audit_count -eq 1 -and
    [int]$cadContract.authority.unregistered_audit_count -eq 166 -and
    [int]$cadRegistry.cep1_audit_count -eq 167 -and
    [int]$cadRegistry.complete_audit_count -eq 1 -and
    [int]$cadRegistry.unregistered_audit_count -eq 166 -and
    -not [bool]$cadRegistry.cache_lookup_permitted -and
    -not [bool]$cadRegistry.result_reuse_permitted
) "RC10 audit-dependency boundary changed"

$release = Read-Lca1Rc10Json (
    Join-Path $repoRoot "sdk/release/quadruped_release_contract.json"
)
$support = Read-Lca1Rc10Json (
    Join-Path $repoRoot "sdk/release/quadruped_support_matrix.json"
)
$blockKey = "prospective_r23d62_selected_profile_three_engine_turning_validation"
$releaseBlocks = @(Find-Lca1Rc10ObjectsWithKey -Value $release -Key $blockKey)
$supportBlocks = @(Find-Lca1Rc10ObjectsWithKey -Value $support -Key $blockKey)
Assert-Lca1Rc10Freeze ($releaseBlocks.Count -eq 1 -and $supportBlocks.Count -eq 1) (
    "R23D62 release/support authority is ambiguous"
)
$expectedStatus = (
    "clean_pushed_qualification_passed_adoption_refused_rc8_closed_negative_" +
    "rc9_closed_negative_rc10_recommissioning_prospective_physical_not_opened"
)
foreach ($parent in @($releaseBlocks[0], $supportBlocks[0])) {
    $block = $parent[$blockKey]
    $localAuditHash = if ($block.Contains("local_declaration_audit_raw_sha256")) {
        [string]$block.local_declaration_audit_raw_sha256
    } else {
        [string]$block.local_declaration_audit_sha256
    }
    Assert-Lca1Rc10Freeze (
        [string]$block.status -ceq $expectedStatus -and
        $localAuditHash -ceq
            "sha256:19c35c64ed0aa080cea6533297b54f4902ee5429c33ea158251f19f9e5d6a77b" -and
        [bool]$block.clean_pushed_qualification_retained -and
        [int]$block.qualification_executed_gate_count -eq 22 -and
        [int]$block.qualification_gate_cas_reference_count -eq 66 -and
        [int]$block.qualification_gate_cas_unique_object_count -eq 46 -and
        [int]$block.qualification_physical_world_count -eq 0 -and
        -not [bool]$block.campaign_attestation_adopted -and
        [string]$block.lca1_rc8_status -ceq
            "closed_negative_full_stage_4_r23d62_preregistration_live_authority_expectation_mismatch_scoped_not_started" -and
        [string]$block.lca1_rc9_status -ceq
            "closed_negative_full_stage_4_r23d62_rapier_route_live_authority_expectation_mismatch_scoped_not_started" -and
        [bool]$block.lca1_rc9_full_half_attempted -and
        [int]$block.lca1_rc9_passed_stage_count -eq 3 -and
        [string]$block.lca1_rc9_inner_failure_code -ceq
            "QSDK_R23D62_RAP_ROUTE_AUTHORITY_STATUS_INVALID" -and
        -not [bool]$block.lca1_rc9_scoped_attempted -and
        [string]$block.lca1_rc9_incident_raw_sha256 -ceq
            "sha256:c012ee33662aeadeeb54b0fa785f376d48a48e44b4e5ed34bfbe13576bb1b0b6" -and
        [string]$block.lca1_rc10_program_id -ceq
            "LCA1-RC10-R23D62-ROUTE-LIVE-AUTHORITY-RECONCILIATION" -and
        [string]$block.lca1_rc10_status -ceq
            "prospective_zero_world_exact_same_source_full_scoped_pair_not_executed" -and
        [int]$block.lca1_rc10_live_authority_consumer_change_count -eq 4 -and
        [int]$block.lca1_rc10_runner_source_change_count -eq 0 -and
        [int]$block.lca1_rc10_campaign_semantics_change_count -eq 0 -and
        [bool]$block.lca1_rc10_complete_full_scoped_pair_required -and
        [int]$block.lca1_rc10_full_required_stage_count -eq 8 -and
        [int]$block.lca1_rc10_scoped_required_executed_gate_count -eq 16 -and
        [int]$block.lca1_rc10_source_runtime_host_identity_margin -eq 0 -and
        [int]$block.lca1_rc10_claim_vector_margin -eq 0 -and
        -not [bool]$block.lca1_rc10_prior_result_reuse_allowed -and
        -not [bool]$block.lca1_rc10_pair_executed -and
        -not [bool]$block.lca1_rc10_commissioning_passed -and
        [int]$block.lca1_rc10_physical_world_count -eq 0 -and
        [bool]$block.fresh_qualification_required_after_recommissioning -and
        -not [bool]$block.physical_campaign_opened -and
        -not [bool]$block.finite_three_engine_turning -and
        -not [bool]$block.q_sdk_r23_satisfied -and
        -not [bool]$block.release_authorized
    ) "RC10 release/support boundary changed"
}

$consumerBindings = [ordered]@{
    "tests/test_qsdk_r23d62_rapier_public_profile_physical_route.py" =
        "sha256:17aefe8433f44f1a7d509141cf8a367a833bdf956134d569bea29edc64d794e9"
    "tests/test_qsdk_r23d62_godot_public_profile_physical_route.py" =
        "sha256:21e9915737f1b9218ca88d9725e4c210a24a7f648870f4ed798c2aa663cf1b98"
    "tests/test_qsdk_r23d62_mujoco_public_profile_physical_route.py" =
        "sha256:f913052c05ebab205879527131e3245888017cb18c40f009165a4394c887a318"
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d62_selected_profile_turning_test.py" =
        "sha256:3ca65c881fc4df75bf7765759a2a16210960eb3f762f6ee7b2d0423acba51f08"
}
foreach ($relativePath in $consumerBindings.Keys) {
    $absolutePath = Join-Path $repoRoot $relativePath
    $source = Get-Content -Raw -LiteralPath $absolutePath
    Assert-Lca1Rc10Freeze (
        (Get-Lca1Rc10Sha256 $absolutePath) -ceq
            [string]$consumerBindings[$relativePath] -and
        $source.Contains(
            "closed_negative_rc10_recommissioning_prospective_physical_not_opened"
        ) -and
        -not $source.Contains(
            "prospective_campaign_machinery_implemented_complete_zero_world_gate_"
        )
    ) "RC10 reconciled consumer changed: $relativePath"
}

$implementationPath = Join-Path $repoRoot (
    "sdk/turning/" +
    "r23d62_selected_profile_three_engine_turning_validation_implementation_v1.json"
)
Assert-Lca1Rc10Freeze (
    (Get-Lca1Rc10Sha256 $implementationPath) -ceq
        "sha256:10d2bf310b7fd29461c70afa285a91609ac9fc656894c5014724de91e9846a4f"
) "R23D62 implementation hash authority changed"

Assert-Lca1Rc10Freeze (
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
    @($manifest.source_bindings).Count -eq 73 -and
    [string]$manifest.dependency_authority.path -ceq
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc10_freeze.json" -and
    [string]$manifest.dependency_authority.raw_sha256 -ceq
        (Get-Lca1Rc10Sha256 $freezePath) -and
    @($manifest.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "RC10 campaign manifest boundary changed"

$manifestBindings = @{}
foreach ($binding in @($manifest.source_bindings)) {
    $relativePath = [string]$binding.path
    Assert-Lca1Rc10Freeze (-not $manifestBindings.ContainsKey($relativePath)) (
        "duplicate manifest source binding: $relativePath"
    )
    $manifestBindings[$relativePath] = [string]$binding.raw_sha256
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Lca1Rc10Freeze (
        (Test-Path -LiteralPath $absolutePath -PathType Leaf) -and
        (Get-Lca1Rc10Sha256 $absolutePath) -ceq [string]$binding.raw_sha256
    ) "manifest source binding changed: $relativePath"
}
foreach ($binding in @($freeze.exact_dependency_bindings)) {
    Assert-Lca1Rc10Freeze (
        $manifestBindings.ContainsKey([string]$binding.path) -and
        [string]$manifestBindings[[string]$binding.path] -ceq
            [string]$binding.raw_sha256
    ) "freeze dependency not mirrored by manifest: $($binding.path)"
}
Assert-Lca1Rc10Freeze (
    $manifestBindings.ContainsKey(
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc10_freeze.json"
    )
) "manifest omitted its dependency authority"

Invoke-Lca1Rc10PowerShellMarker (
    Join-Path $repoRoot "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc9_incident.ps1"
) "LCA1_RC9_INCIDENT_PASS "
Invoke-Lca1Rc10PowerShellMarker (
    Join-Path $repoRoot "tests/test_qsdk_r23d62_preregistration.ps1"
) "QSDK_R23D62_PREREGISTRATION_PASS " @("-Godot", $Godot)
Invoke-Lca1Rc10PowerShellMarker (
    Join-Path $repoRoot "tests/test_qsdk_r23d62_rapier_public_profile_physical_route.ps1"
) "QSDK_R23D62_RAPIER_PUBLIC_PROFILE_ROUTE_PASS "
Invoke-Lca1Rc10PowerShellMarker (
    Join-Path $repoRoot "tests/test_qsdk_r23d62_godot_public_profile_physical_route.ps1"
) "QSDK_R23D62_GODOT_PUBLIC_PROFILE_ROUTE_PASS " @("-Godot", $Godot)
Invoke-Lca1Rc10PowerShellMarker (
    Join-Path $repoRoot "tests/test_qsdk_r23d62_mujoco_public_profile_physical_route.ps1"
) "QSDK_R23D62_MUJOCO_PUBLIC_PROFILE_ROUTE_PASS "
Invoke-Lca1Rc10PowerShellMarker (
    Join-Path $repoRoot "tests/test_qsdk_r23d62_mujoco_physical_worker.ps1"
) "QSDK_R23D62_MUJOCO_PHYSICAL_WORKER_PASS "
Invoke-Lca1Rc10PowerShellMarker (
    Join-Path $repoRoot "tests/test_conformance_runtime_profile.ps1"
) "CONFORMANCE_RUNTIME_PROFILE_PASS "
Invoke-Lca1Rc10PowerShellMarker (
    Join-Path $repoRoot "tests/test_conformance_audit_dependency.ps1"
) "CONFORMANCE_AUDIT_DEPENDENCY_PASS "
Invoke-Lca1Rc10PowerShellMarker (
    Join-Path $repoRoot "tests/test_conformance_dependency_key.ps1"
) "CONFORMANCE_DEPENDENCY_KEY_PASS "
Invoke-Lca1Rc10PowerShellMarker (
    Join-Path $repoRoot "tests/test_locomotion_campaign_attestation_recommissioning_closure.ps1"
) "LCA1_RECOMMISSIONING_CLOSURE_PASS "
Invoke-Lca1Rc10PowerShellMarker (
    Join-Path $repoRoot "tests/test_closure_evidence_provenance_contract.ps1"
) "CLOSURE_EVIDENCE_PROVENANCE_CONTRACT_PASS "
Invoke-Lca1Rc10PowerShellMarker (
    Join-Path $repoRoot "tests/test_locomotion_experiment_workbench.ps1"
) "LOCOMOTION_EXPERIMENT_WORKBENCH_AUDIT_PASS " @("-Godot", $Godot)

$requiredMarkers = $freeze.estimand_and_exact_acceptance.required_terminal_marker_counts
Assert-Lca1Rc10Freeze (
    @($requiredMarkers.Keys).Count -eq 4 -and
    @($requiredMarkers.Values | Where-Object { [int]$_ -ne 1 }).Count -eq 0
) "required marker cardinalities changed"

Write-Host (
    "LCA1_RC10_FREEZE_PASS class=equivalence_non_inferiority pairs=1 " +
    "runtime=7.6.5 runtime_files=86 runtime_bytes=85306718 " +
    "cep1=167 declared=167 unregistered=166 preflight=direct_all " +
    "full_stages=8 scoped_gates=16 cas_refs=48 markers=4 " +
    "dependencies=72 consumers=4 claim_margin=0 prior_reuse=False " +
    "mutations=$mutationRefusals models=0 worlds=0 " +
    "physical_authority=False release_authority=False"
)

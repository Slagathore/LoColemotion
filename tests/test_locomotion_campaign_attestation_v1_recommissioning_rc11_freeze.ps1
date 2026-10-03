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
    "locomotion_campaign_attestation_v1_recommissioning_rc11_freeze.json"
)
$manifestPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc11_manifest.json"
)

. (Join-Path $sdkRoot "conformance_dependency_key.ps1")
. (Join-Path $sdkRoot "conformance_runtime_profile.ps1")

function Assert-Lca1Rc11Freeze([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "LCA1_RC11_FREEZE $Message" }
}

function Read-Lca1Rc11Json([string]$Path) {
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-Lca1Rc11Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Copy-Lca1Rc11Document([object]$Value) {
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Find-Lca1Rc11ObjectsWithKey {
    param(
        [Parameter(Mandatory)][AllowNull()][object]$Value,
        [Parameter(Mandatory)][string]$Key
    )
    $found = @()
    if ($null -eq $Value) { return $found }
    if ($Value -is [System.Collections.IDictionary]) {
        if ($Value.Contains($Key)) { $found += ,$Value }
        foreach ($child in $Value.Values) {
            $found += @(Find-Lca1Rc11ObjectsWithKey -Value $child -Key $Key)
        }
    } elseif ($Value -is [System.Collections.IEnumerable] -and
        $Value -isnot [string]) {
        foreach ($child in $Value) {
            $found += @(Find-Lca1Rc11ObjectsWithKey -Value $child -Key $Key)
        }
    }
    return $found
}

function Invoke-Lca1Rc11PowerShellMarker(
    [string]$Path,
    [string]$Marker,
    [string[]]$Arguments = @()
) {
    $output = @(& pwsh -NoLogo -NoProfile -File $Path @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    Assert-Lca1Rc11Freeze ($exitCode -eq 0) (
        "gate failed: $Path exit=$exitCode output=$($output -join ' | ')"
    )
    Assert-Lca1Rc11Freeze (
        @($output | Where-Object { [string]$_ -clike "$Marker*" }).Count -eq 1
    ) "gate marker cardinality changed: $Marker"
}

function Test-Lca1Rc11FreezeDocument(
    [Parameter(Mandatory)][System.Collections.IDictionary]$Document
) {
    $failures = [Collections.Generic.List[string]]::new()
    if ([string]$Document.schema_version -cne
            "sporespore_locomotion_campaign_attestation_v1_recommissioning_rc11_freeze_v1" -or
        [string]$Document.status -cne
            "prospective_zero_world_exact_same_source_full_scoped_pair_required" -or
        [string]$Document.program_id -cne
            "LCA1-RC11-R24D3-LIVE-SOURCE-AUDIT-RECONCILIATION") {
        $failures.Add("IDENTITY")
    }
    if ([string]$Document.question_class -cne "equivalence_non_inferiority" -or
        [bool]$Document.physical_question -or
        [bool]$Document.physical_campaign_opened) {
        $failures.Add("QUESTION")
    }

    $trigger = $Document.trigger
    if ([string]$trigger.rc10_source_commit -cne
            "fad968e7609a4f15fcd4ade834f953cd0e972eec" -or
        [string]$trigger.rc10_source_tree_git_oid -cne
            "df6218701b6a0d33655970a1ba08dbf1d038d7b9" -or
        [string]$trigger.rc10_incident_raw_sha256 -cne
            "sha256:fe470ea3cd04154c49a439835bd2ad3a47ca66113a51af5ee4e041955203c87c" -or
        [string]$trigger.rc10_incident_audit_raw_sha256 -cne
            "sha256:7c9c67cb939e0adae3e69716dbfd3b4d7ba03575631ec2c9724fbe70e12d7495" -or
        [string]$trigger.rc10_full_run_receipt_raw_sha256 -cne
            "sha256:5889d7b74a0785c50f03e067d17de8e5f5f71fa0fe826c1327abd199daadafbd" -or
        [int]$trigger.rc10_full_passed_stage_count -ne 5 -or
        [int]$trigger.rc10_full_failed_stage_count -ne 1 -or
        [string]$trigger.rc10_first_failed_stage_id -cne
            "godot_runtime_regression" -or
        [string]$trigger.rc10_failure_message -cne
            "QSDK-R24D3: Manifest source binding drifted: .gitattributes" -or
        [string]$trigger.rc10_inner_failure_code -cne
            "QSDK_R24D3_MANIFEST_SOURCE_BINDING_DRIFT" -or
        [bool]$trigger.rc10_scoped_attempted -or
        [int]$trigger.rc10_r24d3_manifest_binding_count -ne 14 -or
        [int]$trigger.rc10_r24d3_manifest_matching_binding_count -ne 10 -or
        [int]$trigger.rc10_r24d3_manifest_stale_binding_count -ne 4 -or
        [int]$trigger.rc10_r24d3_manifest_stale_field_count -ne 8 -or
        -not [bool]$trigger.rc10_r23d62_stage4_passed -or
        [int]$trigger.rc10_physical_world_count -ne 0) {
        $failures.Add("TRIGGER")
    }

    $change = $Document.change_declaration
    if ([int]$change.r24d3_live_manifest_binding_reconciliation_count -ne 4 -or
        [int]$change.r24d3_live_manifest_field_repair_count -ne 8 -or
        [int]$change.r24d3_historical_toolchain_audit_semantic_repair_count -ne 1 -or
        [int]$change.r24d3_historical_qualification_record_change_count -ne 0 -or
        [string]$change.r24d3_historical_powershell_record_version -cne "7.6.4" -or
        [string]$change.r24d3_current_outer_runtime_version -cne "7.6.5" -or
        [int]$change.r23d62_live_authority_consumer_source_change_count -ne 4 -or
        [int]$change.r23d62_expected_status_literal_change_count -ne 4 -or
        [int]$change.r23d62_implementation_hash_binding_change_count -ne 3 -or
        [int]$change.r23d62_campaign_manifest_binding_refresh_count -ne 3 -or
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
        -not [bool]$candidate.unchanged_from_rc10 -or
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
            "complete_full_godot_v2|scoped_lca1_rc11" -or
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
        [bool]$provenance.fitted_from_rc8_rc9_or_rc10_failure_or_r23d62_physical_outcomes -or
        [bool]$provenance.relaxed_after_rc10 -or
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
    if ([int]$Document.exact_dependency_binding_count -ne 80 -or
        @($Document.exact_dependency_bindings).Count -ne 80) {
        $failures.Add("DEPENDENCIES")
    }
    if (-not [bool]$Document.promotion_rule.positive_pair_must_be_closed_in_new_versioned_closure -or
        [string]$Document.promotion_rule.prospective_closure_path -cne
            "sdk/locomotion_campaign_attestation_v1_recommissioning_rc11_closure.json" -or
        -not [bool]$Document.promotion_rule.rc8_rc9_and_rc10_negatives_remain_immutable -or
        [bool]$Document.promotion_rule.adoption_may_move_before_rc11_closure -or
        [bool]$Document.promotion_rule.physical_successor_may_open_before_rc11_closure) {
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

Assert-Lca1Rc11Freeze (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
Assert-Lca1Rc11Freeze (Test-Path -LiteralPath $Godot -PathType Leaf) (
    "Godot executable is missing: $Godot"
)

$freeze = Read-Lca1Rc11Json $freezePath
$manifest = Read-Lca1Rc11Json $manifestPath
Assert-Lca1Rc11Freeze (
    [IO.Path]::GetFullPath($Godot).Replace("\", "/") -ceq
        [string]$freeze.accepted_runtime.godot_executable_path
) "selected Godot path differs from the frozen runtime"
$documentTest = Test-Lca1Rc11FreezeDocument -Document $freeze
Assert-Lca1Rc11Freeze ([bool]$documentTest.ok) (
    "freeze document changed: $(@($documentTest.failure_codes) -join ',')"
)

$mutations = @(
    @{ name = "status"; apply = { param($d) $d.status = "passed" } },
    @{ name = "question"; apply = { param($d) $d.question_class = "development" } },
    @{ name = "incident"; apply = { param($d) $d.trigger.rc10_incident_raw_sha256 = "sha256:" + ("0" * 64) } },
    @{ name = "stages"; apply = { param($d) $d.trigger.rc10_full_passed_stage_count = 4 } },
    @{ name = "r24d3_binding"; apply = { param($d) $d.change_declaration.r24d3_live_manifest_binding_reconciliation_count = 3 } },
    @{ name = "r24d3_field"; apply = { param($d) $d.change_declaration.r24d3_live_manifest_field_repair_count = 7 } },
    @{ name = "historical_audit"; apply = { param($d) $d.change_declaration.r24d3_historical_toolchain_audit_semantic_repair_count = 0 } },
    @{ name = "historical_record"; apply = { param($d) $d.change_declaration.r24d3_historical_qualification_record_change_count = 1 } },
    @{ name = "consumer"; apply = { param($d) $d.change_declaration.r23d62_live_authority_consumer_source_change_count = 3 } },
    @{ name = "binding"; apply = { param($d) $d.change_declaration.r23d62_implementation_hash_binding_change_count = 2 } },
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
    @{ name = "provenance"; apply = { param($d) $d.threshold_and_margin_provenance.fitted_from_rc8_rc9_or_rc10_failure_or_r23d62_physical_outcomes = $true } },
    @{ name = "population"; apply = { param($d) $d.adequacy_argument.population_claim = $true } },
    @{ name = "dependencies"; apply = { param($d) $d.exact_dependency_binding_count = 79 } },
    @{ name = "promotion"; apply = { param($d) $d.promotion_rule.adoption_may_move_before_rc11_closure = $true } },
    @{ name = "claim"; apply = { param($d) $d.claims.turning_acceptance = $true } }
)
$mutationRefusals = 0
foreach ($mutation in $mutations) {
    $changed = Copy-Lca1Rc11Document $freeze
    & $mutation.apply $changed
    $result = Test-Lca1Rc11FreezeDocument -Document $changed
    Assert-Lca1Rc11Freeze (-not [bool]$result.ok) (
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
    Assert-Lca1Rc11Freeze ($bindingPaths.Add($relativePath)) (
        "duplicate exact dependency: $relativePath"
    )
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Lca1Rc11Freeze (
        (Test-Path -LiteralPath $absolutePath -PathType Leaf) -and
        (Get-Lca1Rc11Sha256 $absolutePath) -ceq [string]$binding.raw_sha256 -and
        (Get-Item -LiteralPath $absolutePath).Length -eq [long]$binding.byte_length
    ) "exact dependency changed: $relativePath"
}
Assert-Lca1Rc11Freeze ($bindingPaths.Count -eq 80) (
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
    "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc10_freeze.ps1",
    "sdk/locomotion_campaign_attestation_v1_recommissioning_rc10_incident.json",
    "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc10_incident.ps1",
    "sdk/recovery/r24d3_godot_jolt_motor_telemetry_source_validation_manifest.json",
    "tests/test_qsdk_r24d3_godot_jolt_motor_telemetry_source.ps1",
    "tests/test_qsdk_r24d3_godot_jolt_motor_telemetry_cold_qualification_adoption.ps1",
    "tests/test_qsdk_r24d3_godot_jolt_motor_telemetry_post_adoption_full_cold_conformance_qualification.ps1",
    "sdk/adapters/godot/engine_patches/README.md",
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
    "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc11_freeze.ps1"
)) {
    Assert-Lca1Rc11Freeze ($bindingPaths.Contains($requiredPath)) (
        "required exact dependency omitted: $requiredPath"
    )
}

$runnerPath = Join-Path $repoRoot ([string]$freeze.candidate_executor.path)
Assert-Lca1Rc11Freeze (
    (Get-Lca1Rc11Sha256 $runnerPath) -ceq
        [string]$freeze.candidate_executor.raw_sha256 -and
    (& git -C $repoRoot hash-object -- $runnerPath).Trim() -ceq
        [string]$freeze.candidate_executor.git_blob_oid
) "candidate executor bytes changed"

$runtime = $freeze.accepted_runtime
foreach ($role in @("profile_contract", "profile_registry", "profile_evaluator")) {
    $absolutePath = Join-Path $repoRoot ([string]$runtime[$role + "_path"])
    Assert-Lca1Rc11Freeze (
        (Get-Lca1Rc11Sha256 $absolutePath) -ceq
            [string]$runtime[$role + "_raw_sha256"]
    ) "runtime-profile source changed: $role"
}
$runtimeCandidate = Get-SporeSporeConformanceRuntimeProfileCandidate `
    -RepoRoot $repoRoot
$profile = @($runtimeCandidate.profiles)[0]
Assert-Lca1Rc11Freeze (
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
    Assert-Lca1Rc11Freeze (
        (Test-Path -LiteralPath ([string]$binding.path) -PathType Leaf) -and
        (Get-Lca1Rc11Sha256 ([string]$binding.path)) -ceq [string]$binding.hash
    ) "accepted runtime executable changed: $($binding.path)"
}

$cep1 = Read-Lca1Rc11Json (
    Join-Path $repoRoot "sdk/closure_evidence_mode_inventory.json"
)
$cadContract = Read-Lca1Rc11Json (
    Join-Path $repoRoot "sdk/conformance_audit_dependency_contract_v1.json"
)
$cadRegistry = Read-Lca1Rc11Json (
    Join-Path $repoRoot "sdk/conformance_audit_dependency_registry_v1.json"
)
Assert-Lca1Rc11Freeze (
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
) "RC11 audit-dependency boundary changed"

$release = Read-Lca1Rc11Json (
    Join-Path $repoRoot "sdk/release/quadruped_release_contract.json"
)
$support = Read-Lca1Rc11Json (
    Join-Path $repoRoot "sdk/release/quadruped_support_matrix.json"
)
$blockKey = "prospective_r23d62_selected_profile_three_engine_turning_validation"
$releaseBlocks = @(Find-Lca1Rc11ObjectsWithKey -Value $release -Key $blockKey)
$supportBlocks = @(Find-Lca1Rc11ObjectsWithKey -Value $support -Key $blockKey)
Assert-Lca1Rc11Freeze ($releaseBlocks.Count -eq 1 -and $supportBlocks.Count -eq 1) (
    "R23D62 release/support authority is ambiguous"
)
$expectedStatus = (
    "clean_pushed_qualification_passed_adoption_refused_rc8_closed_negative_" +
    "rc9_closed_negative_rc10_closed_negative_rc11_recommissioning_" +
    "prospective_physical_not_opened"
)
foreach ($parent in @($releaseBlocks[0], $supportBlocks[0])) {
    $block = $parent[$blockKey]
    $localAuditHash = if ($block.Contains("local_declaration_audit_raw_sha256")) {
        [string]$block.local_declaration_audit_raw_sha256
    } else {
        [string]$block.local_declaration_audit_sha256
    }
    Assert-Lca1Rc11Freeze (
        [string]$block.status -ceq $expectedStatus -and
        $localAuditHash -ceq
            "sha256:7b799e399cebc8880757eff53d51c479a699426656968d1004c3f5726a90ed76" -and
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
        [string]$block.lca1_rc10_status -ceq
            "closed_negative_full_stage_6_r24d3_live_source_manifest_binding_drift_scoped_not_started" -and
        [bool]$block.lca1_rc10_full_half_attempted -and
        [int]$block.lca1_rc10_passed_stage_count -eq 5 -and
        [int]$block.lca1_rc10_failed_stage_count -eq 1 -and
        [string]$block.lca1_rc10_first_failed_stage_id -ceq
            "godot_runtime_regression" -and
        [string]$block.lca1_rc10_inner_failure_code -ceq
            "QSDK_R24D3_MANIFEST_SOURCE_BINDING_DRIFT" -and
        -not [bool]$block.lca1_rc10_scoped_attempted -and
        [int]$block.lca1_rc10_r24d3_manifest_matching_binding_count -eq 10 -and
        [int]$block.lca1_rc10_r24d3_manifest_stale_binding_count -eq 4 -and
        [bool]$block.lca1_rc10_r23d62_stage4_passed -and
        [string]$block.lca1_rc10_incident_raw_sha256 -ceq
            "sha256:fe470ea3cd04154c49a439835bd2ad3a47ca66113a51af5ee4e041955203c87c" -and
        [string]$block.lca1_rc11_program_id -ceq
            "LCA1-RC11-R24D3-LIVE-SOURCE-AUDIT-RECONCILIATION" -and
        [string]$block.lca1_rc11_status -ceq
            "prospective_zero_world_exact_same_source_full_scoped_pair_not_executed" -and
        [int]$block.lca1_rc11_r24d3_live_manifest_binding_reconciliation_count -eq 4 -and
        [int]$block.lca1_rc11_r24d3_live_manifest_field_repair_count -eq 8 -and
        [int]$block.lca1_rc11_r24d3_historical_toolchain_audit_semantic_repair_count -eq 1 -and
        [int]$block.lca1_rc11_live_authority_consumer_change_count -eq 4 -and
        [int]$block.lca1_rc11_implementation_hash_binding_change_count -eq 3 -and
        [int]$block.lca1_rc11_campaign_manifest_binding_refresh_count -eq 3 -and
        [int]$block.lca1_rc11_runner_source_change_count -eq 0 -and
        [int]$block.lca1_rc11_campaign_semantics_change_count -eq 0 -and
        [bool]$block.lca1_rc11_complete_full_scoped_pair_required -and
        [int]$block.lca1_rc11_full_required_stage_count -eq 8 -and
        [int]$block.lca1_rc11_scoped_required_executed_gate_count -eq 16 -and
        [int]$block.lca1_rc11_source_runtime_host_identity_margin -eq 0 -and
        [int]$block.lca1_rc11_claim_vector_margin -eq 0 -and
        -not [bool]$block.lca1_rc11_prior_result_reuse_allowed -and
        -not [bool]$block.lca1_rc11_pair_executed -and
        -not [bool]$block.lca1_rc11_full_half_attempted -and
        -not [bool]$block.lca1_rc11_commissioning_passed -and
        [int]$block.lca1_rc11_physical_world_count -eq 0 -and
        [bool]$block.fresh_qualification_required_after_recommissioning -and
        -not [bool]$block.physical_campaign_opened -and
        -not [bool]$block.finite_three_engine_turning -and
        -not [bool]$block.q_sdk_r23_satisfied -and
        -not [bool]$block.release_authorized
    ) "RC11 release/support boundary changed"
}

$consumerBindings = [ordered]@{
    "tests/test_qsdk_r23d62_rapier_public_profile_physical_route.py" =
        "sha256:c57eb1147cbfa68670accbcebad80b87a7b8641e7aed7fe0a95bec72aa74d3b1"
    "tests/test_qsdk_r23d62_godot_public_profile_physical_route.py" =
        "sha256:cb8151a2e185c1020dc4f8612d5fcdd2e6bb42ecc0a4d58d465b0e2e49395934"
    "tests/test_qsdk_r23d62_mujoco_public_profile_physical_route.py" =
        "sha256:6df2cd766d1362e1384da8a6f2ee6cc28ce4c8d07d4720cbab0cd63734ba6627"
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d62_selected_profile_turning_test.py" =
        "sha256:a5da511ceb3545f94c1dc076762379153f29aea59d917a5ebf4968d6bbf68b26"
}
foreach ($relativePath in $consumerBindings.Keys) {
    $absolutePath = Join-Path $repoRoot $relativePath
    $source = Get-Content -Raw -LiteralPath $absolutePath
    Assert-Lca1Rc11Freeze (
        (Get-Lca1Rc11Sha256 $absolutePath) -ceq
            [string]$consumerBindings[$relativePath] -and
        $source.Contains(
            "closed_negative_rc10_closed_negative_rc11_recommissioning_" +
            "prospective_"
        ) -and
        $source.Contains(
            '"physical_not_opened"'
        ) -and
        -not $source.Contains(
            "prospective_campaign_machinery_implemented_complete_zero_world_gate_"
        )
    ) "RC11 reconciled consumer changed: $relativePath"
}

$implementationPath = Join-Path $repoRoot (
    "sdk/turning/" +
    "r23d62_selected_profile_three_engine_turning_validation_implementation_v1.json"
)
Assert-Lca1Rc11Freeze (
    (Get-Lca1Rc11Sha256 $implementationPath) -ceq
        "sha256:19ce72cb4121ab9122835419fe26f1b78ed6e7813bdbe2275868afdc2d05acb1"
) "R23D62 implementation hash authority changed"

$r24d3ManifestPath = Join-Path $repoRoot (
    "sdk/recovery/" +
    "r24d3_godot_jolt_motor_telemetry_source_validation_manifest.json"
)
$r24d3SourceAuditPath = Join-Path $repoRoot (
    "tests/test_qsdk_r24d3_godot_jolt_motor_telemetry_source.ps1"
)
$r24d3AdoptionAuditPath = Join-Path $repoRoot (
    "tests/test_qsdk_r24d3_godot_jolt_motor_telemetry_" +
    "cold_qualification_adoption.ps1"
)
$r24d3PostAuditPath = Join-Path $repoRoot (
    "tests/test_qsdk_r24d3_godot_jolt_motor_telemetry_" +
    "post_adoption_full_cold_conformance_qualification.ps1"
)
$r24d3HistoricalQualificationPath = Join-Path $repoRoot (
    "sdk/recovery/r24d3_godot_jolt_motor_telemetry_" +
    "post_adoption_full_cold_conformance_qualification_v1.json"
)
Assert-Lca1Rc11Freeze (
    (Get-Lca1Rc11Sha256 $r24d3ManifestPath) -ceq
        "sha256:ea4c1391e708d1901117520a85bf033bf6da7012dfc9ed0c7f0c89579ba00d1c" -and
    (Get-Lca1Rc11Sha256 $r24d3SourceAuditPath) -ceq
        "sha256:018a430a21a957fb39afbfdf0e15d96c40ae40a9538ff3a3c18ceeea0dcaf3f6" -and
    (Get-Lca1Rc11Sha256 $r24d3AdoptionAuditPath) -ceq
        "sha256:0cec8b4a971ac5fba33fee07d7c44879cb6f200701a94ea1d48ec3d5406b05c4" -and
    (Get-Lca1Rc11Sha256 $r24d3PostAuditPath) -ceq
        "sha256:2fc547745b3eb3418682f15540323776c5c9dcbf4e99d96bde7c619b4d4acc0b"
) "R24D3 reconciled audit source changed"
$r24d3HistoricalQualification = Read-Lca1Rc11Json $r24d3HistoricalQualificationPath
Assert-Lca1Rc11Freeze (
    [string]$r24d3HistoricalQualification.durable_attestation.powershell_version -ceq
        "7.6.4" -and
    [string]$r24d3HistoricalQualification.durable_attestation.powershell_executable_raw_sha256 -ceq
        "sha256:db6dd81183fe57d22e03b911ec9a30a2fd7c40542e97743615355a6fb44f458f" -and
    [string]$r24d3HistoricalQualification.durable_attestation.godot_executable_raw_sha256 -ceq
        "sha256:c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896" -and
    [string]$freeze.accepted_runtime.powershell_version -ceq "7.6.5" -and
    [string]$freeze.accepted_runtime.outer_powershell_executable_raw_sha256 -ceq
        "sha256:362a356ce7f0940ec74f73a8fc2c990a2cc24a38a11c90bbd8eca947110ad139"
) "R24D3 historical qualification or separately bound current runtime changed"

Assert-Lca1Rc11Freeze (
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
    @($manifest.source_bindings).Count -eq 81 -and
    [string]$manifest.dependency_authority.path -ceq
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc11_freeze.json" -and
    [string]$manifest.dependency_authority.raw_sha256 -ceq
        (Get-Lca1Rc11Sha256 $freezePath) -and
    @($manifest.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "RC11 campaign manifest boundary changed"

$manifestBindings = @{}
foreach ($binding in @($manifest.source_bindings)) {
    $relativePath = [string]$binding.path
    Assert-Lca1Rc11Freeze (-not $manifestBindings.ContainsKey($relativePath)) (
        "duplicate manifest source binding: $relativePath"
    )
    $manifestBindings[$relativePath] = [string]$binding.raw_sha256
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Lca1Rc11Freeze (
        (Test-Path -LiteralPath $absolutePath -PathType Leaf) -and
        (Get-Lca1Rc11Sha256 $absolutePath) -ceq [string]$binding.raw_sha256
    ) "manifest source binding changed: $relativePath"
}
foreach ($binding in @($freeze.exact_dependency_bindings)) {
    Assert-Lca1Rc11Freeze (
        $manifestBindings.ContainsKey([string]$binding.path) -and
        [string]$manifestBindings[[string]$binding.path] -ceq
            [string]$binding.raw_sha256
    ) "freeze dependency not mirrored by manifest: $($binding.path)"
}
Assert-Lca1Rc11Freeze (
    $manifestBindings.ContainsKey(
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc11_freeze.json"
    )
) "manifest omitted its dependency authority"

Invoke-Lca1Rc11PowerShellMarker (
    Join-Path $repoRoot "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc9_incident.ps1"
) "LCA1_RC9_INCIDENT_PASS "
Invoke-Lca1Rc11PowerShellMarker (
    Join-Path $repoRoot "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc10_incident.ps1"
) "LCA1_RC10_INCIDENT_PASS "
Invoke-Lca1Rc11PowerShellMarker (
    Join-Path $repoRoot "tests/test_qsdk_r24d3_godot_jolt_motor_telemetry_source.ps1"
) "QSDK_R24D3_GODOT_JOLT_MOTOR_TELEMETRY_SOURCE_PASS "
Invoke-Lca1Rc11PowerShellMarker (
    Join-Path $repoRoot "tests/test_qsdk_r24d3_godot_jolt_motor_telemetry_cold_qualification_adoption.ps1"
) "QSDK_R24D3_COLD_QUALIFICATION_ADOPTION_PASS "
Invoke-Lca1Rc11PowerShellMarker (
    Join-Path $repoRoot (
        "tests/test_qsdk_r24d3_godot_jolt_motor_telemetry_" +
        "post_adoption_full_cold_conformance_qualification.ps1"
    )
) "QSDK_R24D3_POST_ADOPTION_FULL_COLD_CONFORMANCE_QUALIFICATION_PASS "
Invoke-Lca1Rc11PowerShellMarker (
    Join-Path $repoRoot "tests/test_qsdk_r23d62_preregistration.ps1"
) "QSDK_R23D62_PREREGISTRATION_PASS " @("-Godot", $Godot)
Invoke-Lca1Rc11PowerShellMarker (
    Join-Path $repoRoot "tests/test_qsdk_r23d62_rapier_public_profile_physical_route.ps1"
) "QSDK_R23D62_RAPIER_PUBLIC_PROFILE_ROUTE_PASS "
Invoke-Lca1Rc11PowerShellMarker (
    Join-Path $repoRoot "tests/test_qsdk_r23d62_godot_public_profile_physical_route.ps1"
) "QSDK_R23D62_GODOT_PUBLIC_PROFILE_ROUTE_PASS " @("-Godot", $Godot)
Invoke-Lca1Rc11PowerShellMarker (
    Join-Path $repoRoot "tests/test_qsdk_r23d62_mujoco_public_profile_physical_route.ps1"
) "QSDK_R23D62_MUJOCO_PUBLIC_PROFILE_ROUTE_PASS "
Invoke-Lca1Rc11PowerShellMarker (
    Join-Path $repoRoot "tests/test_qsdk_r23d62_mujoco_physical_worker.ps1"
) "QSDK_R23D62_MUJOCO_PHYSICAL_WORKER_PASS "
Invoke-Lca1Rc11PowerShellMarker (
    Join-Path $repoRoot "tests/test_conformance_runtime_profile.ps1"
) "CONFORMANCE_RUNTIME_PROFILE_PASS "
Invoke-Lca1Rc11PowerShellMarker (
    Join-Path $repoRoot "tests/test_conformance_audit_dependency.ps1"
) "CONFORMANCE_AUDIT_DEPENDENCY_PASS "
Invoke-Lca1Rc11PowerShellMarker (
    Join-Path $repoRoot "tests/test_conformance_dependency_key.ps1"
) "CONFORMANCE_DEPENDENCY_KEY_PASS "
Invoke-Lca1Rc11PowerShellMarker (
    Join-Path $repoRoot "tests/test_locomotion_campaign_attestation_recommissioning_closure.ps1"
) "LCA1_RECOMMISSIONING_CLOSURE_PASS "
Invoke-Lca1Rc11PowerShellMarker (
    Join-Path $repoRoot "tests/test_closure_evidence_provenance_contract.ps1"
) "CLOSURE_EVIDENCE_PROVENANCE_CONTRACT_PASS "
Invoke-Lca1Rc11PowerShellMarker (
    Join-Path $repoRoot "tests/test_locomotion_experiment_workbench.ps1"
) "LOCOMOTION_EXPERIMENT_WORKBENCH_AUDIT_PASS " @("-Godot", $Godot)

$requiredMarkers = $freeze.estimand_and_exact_acceptance.required_terminal_marker_counts
Assert-Lca1Rc11Freeze (
    @($requiredMarkers.Keys).Count -eq 4 -and
    @($requiredMarkers.Values | Where-Object { [int]$_ -ne 1 }).Count -eq 0
) "required marker cardinalities changed"

Write-Host (
    "LCA1_RC11_FREEZE_PASS class=equivalence_non_inferiority pairs=1 " +
    "runtime=7.6.5 runtime_files=86 runtime_bytes=85306718 " +
    "cep1=167 declared=167 unregistered=166 preflight=direct_all " +
    "full_stages=8 scoped_gates=16 cas_refs=48 markers=4 " +
    "dependencies=80 r24d3_bindings=4 r24d3_fields=8 " +
    "historical_audit_repairs=1 lifecycle_consumers=4 claim_margin=0 " +
    "prior_reuse=False " +
    "mutations=$mutationRefusals models=0 worlds=0 " +
    "physical_authority=False release_authority=False"
)

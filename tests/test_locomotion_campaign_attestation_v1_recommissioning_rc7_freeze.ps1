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
    "locomotion_campaign_attestation_v1_recommissioning_rc7_freeze.json"
)
$manifestPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc7_manifest.json"
)

. (Join-Path $sdkRoot "conformance_dependency_key.ps1")
. (Join-Path $sdkRoot "conformance_runtime_profile.ps1")

function Assert-Lca1Rc7Freeze([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "LCA1_RC7_FREEZE $Message" }
}

function Read-Lca1Rc7Json([string]$Path) {
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-Lca1Rc7Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Copy-Lca1Rc7Document([object]$Value) {
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Find-Lca1Rc7ObjectsWithKey {
    param(
        [Parameter(Mandatory)][AllowNull()][object]$Value,
        [Parameter(Mandatory)][string]$Key
    )
    $found = @()
    if ($null -eq $Value) { return $found }
    if ($Value -is [System.Collections.IDictionary]) {
        if ($Value.Contains($Key)) { $found += ,$Value }
        foreach ($child in $Value.Values) {
            $found += @(Find-Lca1Rc7ObjectsWithKey -Value $child -Key $Key)
        }
    } elseif ($Value -is [System.Collections.IEnumerable] -and
        $Value -isnot [string]) {
        foreach ($child in $Value) {
            $found += @(Find-Lca1Rc7ObjectsWithKey -Value $child -Key $Key)
        }
    }
    return $found
}

function Invoke-Lca1Rc7PowerShellMarker(
    [string]$Path,
    [string]$Marker,
    [string[]]$Arguments = @()
) {
    $output = @(& pwsh -NoLogo -NoProfile -File $Path @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    Assert-Lca1Rc7Freeze ($exitCode -eq 0) (
        "gate failed: $Path exit=$exitCode output=$($output -join ' | ')"
    )
    Assert-Lca1Rc7Freeze (
        @($output | Where-Object { [string]$_ -clike "$Marker*" }).Count -eq 1
    ) "gate marker cardinality changed: $Marker"
}

function Test-Lca1Rc7FreezeDocument(
    [Parameter(Mandatory)][System.Collections.IDictionary]$Document
) {
    $failures = [Collections.Generic.List[string]]::new()
    if ([string]$Document.schema_version -cne
            "sporespore_locomotion_campaign_attestation_v1_recommissioning_rc7_freeze_v1" -or
        [string]$Document.status -cne
            "prospective_zero_world_exact_same_source_full_scoped_pair_required" -or
        [string]$Document.program_id -cne
            "LCA1-RC7-CEP1-AUDIT-DEPENDENCY-COUNT-RECONCILIATION") {
        $failures.Add("IDENTITY")
    }
    if ([string]$Document.question_class -cne "equivalence_non_inferiority" -or
        [bool]$Document.physical_question -or
        [bool]$Document.physical_campaign_opened) {
        $failures.Add("QUESTION")
    }
    $trigger = $Document.trigger
    if ([string]$trigger.declared_from_parent_commit -cne
            "b96bf2452889d0ca2050a48ef81e82a6666410bb" -or
        [string]$trigger.declared_from_parent_tree_git_oid -cne
            "58a9b5d6ccc00ee28988f1ec2d5f60ad5a86538a" -or
        [string]$trigger.rc6_status -cne
            "closed_negative_full_stage_1_cep1_audit_dependency_count_mismatch_scoped_not_started" -or
        [string]$trigger.rc6_observed_source_commit -cne
            "6457be4a6d42794b60331b50eb2e399c16c589e4" -or
        -not [bool]$trigger.rc6_full_half_attempted -or
        [bool]$trigger.rc6_pair_completed -or
        [bool]$trigger.rc6_same_source_rerun_allowed -or
        [int]$trigger.rc6_physical_world_count -ne 0 -or
        [int]$trigger.cep1_observed_audit_count -ne 150 -or
        [int]$trigger.stale_declared_audit_count -ne 148) {
        $failures.Add("TRIGGER")
    }
    $change = $Document.change_declaration
    if ([int]$change.semantic_count_field_change_count -ne 4 -or
        [int]$change.test_count_literal_change_count -ne 8 -or
        [int]$change.post_incident_additional_test_literal_count -ne 2 -or
        [int]$change.audit_dependency_preflight_addition_count -ne 1 -or
        [int]$change.dependency_key_preflight_addition_count -ne 1 -or
        [int]$change.cep1_audit_count_before -ne 148 -or
        [int]$change.cep1_audit_count_after -ne 150 -or
        [int]$change.unregistered_audit_count_before -ne 147 -or
        [int]$change.unregistered_audit_count_after -ne 149 -or
        [int]$change.runner_source_change_count -ne 0 -or
        [int]$change.physics_change_count -ne 0 -or
        [int]$change.controller_semantics_change_count -ne 0 -or
        [int]$change.threshold_or_margin_change_count -ne 0 -or
        [bool]$change.physical_outcome_evaluated) {
        $failures.Add("CHANGE")
    }
    $candidate = $Document.candidate_executor
    if ([string]$candidate.path -cne "sdk/run_conformance.ps1" -or
        [string]$candidate.raw_sha256 -cne
            "sha256:c02bd9b0fa222958ca475dee4ee264a90e246828fbb60595560fcd58e2318da7" -or
        [string]$candidate.git_blob_oid -cne
            "c19157937b587e8b46bc01125cb05bd77645c949" -or
        [long]$candidate.byte_length -ne 128440 -or
        [bool]$candidate.changed_from_rc6 -or
        -not [bool]$candidate.full_cold_recomputation_required -or
        [bool]$candidate.complete_transitive_dependency_key_claimed_before_pair) {
        $failures.Add("EXECUTOR")
    }
    $runtime = $Document.accepted_runtime
    if ([string]$runtime.powershell_version -cne "7.6.4" -or
        [string]$runtime.powershell_edition -cne "Core" -or
        [string]$runtime.framework_description -cne ".NET 10.0.10" -or
        [string]$runtime.godot_version -cne
            "4.7.stable.mono.official.5b4e0cb0f" -or
        [string]$runtime.python_version -cne "Python 3.11.9" -or
        [string]$runtime.git_version -cne "git version 2.53.0.windows.3" -or
        [string]$runtime.cargo_version -cne
            "cargo 1.97.0 (c980f4866 2026-06-30)" -or
        [string]$runtime.rustc_version -cne
            "rustc 1.97.0 (2d8144b78 2026-07-07)" -or
        [string]$runtime.host_os -cne "Microsoft Windows 10.0.26100" -or
        [string]$runtime.process_architecture -cne "X64" -or
        [int]$runtime.declared_file_count -ne 86 -or
        [long]$runtime.declared_byte_count -ne 85258167 -or
        [string]$runtime.declared_inventory_sha256 -cne
            "sha256:805f538abafb574efb02104b41215b1c8e4c16404b90edb1ea3fce3ed4256ef3" -or
        -not [bool]$runtime.runtime_profile_candidate_preflight_required -or
        [int]$runtime.source_runtime_host_identity_margin -ne 0) {
        $failures.Add("RUNTIME")
    }
    $pair = $Document.prospective_pair
    if ([int]$pair.pair_count -ne 1 -or -not [bool]$pair.serialized -or
        (@($pair.execution_order) -join "|") -cne
            "complete_full_godot_v2|scoped_lca1_rc7" -or
        -not [bool]$pair.same_clean_pushed_source_commit_and_tree_required -or
        -not [bool]$pair.same_toolchain_runtime_and_host_required -or
        -not [bool]$pair.audit_dependency_candidate_preflight_before_full_required -or
        -not [bool]$pair.dependency_key_candidate_preflight_before_full_required -or
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
            "inherited_exact_zero_margin_from_closed_lca1_rc5_process_commissioning" -or
        [bool]$provenance.fitted_from_rc6_or_rc7_observation -or
        [bool]$provenance.relaxed_after_rc5 -or
        [int]$provenance.threshold_change_count -ne 0 -or
        [int]$provenance.margin_change_count -ne 0) {
        $failures.Add("PROVENANCE")
    }
    if (-not [bool]$Document.adequacy_argument.
            single_pair_is_adequate_for_exact_deterministic_executor_commissioning -or
        [bool]$Document.adequacy_argument.population_claim -or
        [bool]$Document.adequacy_argument.physics_equivalence_claim -or
        [bool]$Document.adequacy_argument.cross_engine_equivalence_claim -or
        [bool]$Document.adequacy_argument.movement_claim) {
        $failures.Add("ADEQUACY")
    }
    if ([int]$Document.exact_dependency_binding_count -ne 53 -or
        @($Document.exact_dependency_bindings).Count -ne 53) {
        $failures.Add("DEPENDENCIES")
    }
    if (-not [bool]$Document.promotion_rule.
            positive_pair_must_be_closed_in_new_versioned_closure -or
        [string]$Document.promotion_rule.prospective_closure_path -cne
            "sdk/locomotion_campaign_attestation_v1_recommissioning_rc7_closure.json" -or
        -not [bool]$Document.promotion_rule.rc6_negative_remains_immutable -or
        [bool]$Document.promotion_rule.adoption_may_move_before_rc7_closure -or
        [bool]$Document.promotion_rule.physical_successor_may_open_before_rc7_closure) {
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

Assert-Lca1Rc7Freeze (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
Assert-Lca1Rc7Freeze (Test-Path -LiteralPath $Godot -PathType Leaf) (
    "Godot executable is missing: $Godot"
)

$freeze = Read-Lca1Rc7Json $freezePath
$manifest = Read-Lca1Rc7Json $manifestPath
Assert-Lca1Rc7Freeze (
    [IO.Path]::GetFullPath($Godot).Replace("\", "/") -ceq
        [string]$freeze.accepted_runtime.godot_executable_path
) "selected Godot path differs from the frozen runtime"
$documentTest = Test-Lca1Rc7FreezeDocument -Document $freeze
Assert-Lca1Rc7Freeze ([bool]$documentTest.ok) (
    "freeze document changed: $(@($documentTest.failure_codes) -join ',')"
)

$mutations = @(
    @{ name = "status"; apply = { param($d) $d.status = "passed" } },
    @{ name = "question"; apply = { param($d) $d.question_class = "development" } },
    @{ name = "parent"; apply = { param($d) $d.trigger.declared_from_parent_commit = "0" * 40 } },
    @{ name = "rc6_rerun"; apply = { param($d) $d.trigger.rc6_same_source_rerun_allowed = $true } },
    @{ name = "semantic_counts"; apply = { param($d) $d.change_declaration.semantic_count_field_change_count = 3 } },
    @{ name = "test_literals"; apply = { param($d) $d.change_declaration.test_count_literal_change_count = 7 } },
    @{ name = "preflight"; apply = { param($d) $d.change_declaration.audit_dependency_preflight_addition_count = 0 } },
    @{ name = "dependency_preflight"; apply = { param($d) $d.prospective_pair.dependency_key_candidate_preflight_before_full_required = $false } },
    @{ name = "runner"; apply = { param($d) $d.candidate_executor.raw_sha256 = "sha256:" + ("0" * 64) } },
    @{ name = "runner_changed"; apply = { param($d) $d.candidate_executor.changed_from_rc6 = $true } },
    @{ name = "runtime"; apply = { param($d) $d.accepted_runtime.powershell_version = "7.6.0-preview.6" } },
    @{ name = "pair"; apply = { param($d) $d.prospective_pair.pair_count = 2 } },
    @{ name = "order"; apply = { param($d) [array]::Reverse($d.prospective_pair.execution_order) } },
    @{ name = "cache"; apply = { param($d) $d.prospective_pair.cache_lookup_allowed = $true } },
    @{ name = "reuse"; apply = { param($d) $d.prospective_pair.prior_result_reuse_allowed = $true } },
    @{ name = "rerun"; apply = { param($d) $d.prospective_pair.same_source_rerun_after_complete_or_failed_pair_allowed = $true } },
    @{ name = "full"; apply = { param($d) $d.estimand_and_exact_acceptance.full_required_stage_count = 7 } },
    @{ name = "scoped"; apply = { param($d) $d.estimand_and_exact_acceptance.scoped_required_executed_gate_count = 15 } },
    @{ name = "margin"; apply = { param($d) $d.estimand_and_exact_acceptance.claim_vector_margin = 1 } },
    @{ name = "provenance"; apply = { param($d) $d.threshold_and_margin_provenance.fitted_from_rc6_or_rc7_observation = $true } },
    @{ name = "dependencies"; apply = { param($d) $d.exact_dependency_binding_count = 52 } },
    @{ name = "promotion"; apply = { param($d) $d.promotion_rule.adoption_may_move_before_rc7_closure = $true } },
    @{ name = "claim"; apply = { param($d) $d.claims.turning_acceptance = $true } }
)
$mutationRefusals = 0
foreach ($mutation in $mutations) {
    $changed = Copy-Lca1Rc7Document $freeze
    & $mutation.apply $changed
    $result = Test-Lca1Rc7FreezeDocument -Document $changed
    Assert-Lca1Rc7Freeze (-not [bool]$result.ok) (
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
    Assert-Lca1Rc7Freeze ($bindingPaths.Add($relativePath)) (
        "duplicate exact dependency: $relativePath"
    )
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Lca1Rc7Freeze (
        (Test-Path -LiteralPath $absolutePath -PathType Leaf) -and
        (Get-Lca1Rc7Sha256 $absolutePath) -ceq [string]$binding.raw_sha256 -and
        (Get-Item -LiteralPath $absolutePath).Length -eq [long]$binding.byte_length
    ) "exact dependency changed: $relativePath"
}
Assert-Lca1Rc7Freeze ($bindingPaths.Count -eq 53) (
    "exact dependency cardinality changed"
)
foreach ($requiredPath in @(
    "sdk/run_conformance.ps1",
    "sdk/conformance_dependency_key.ps1",
    "sdk/conformance_audit_dependency.ps1",
    "sdk/conformance_audit_dependency_contract_v1.json",
    "sdk/conformance_audit_dependency_registry_v1.json",
    "tests/test_conformance_audit_dependency.ps1",
    "tests/test_conformance_dependency_key.ps1",
    "sdk/locomotion_campaign_attestation_v1_recommissioning_rc6_incident.json",
    "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc6_incident.ps1",
    "sdk/locomotion_campaign_attestation_v1_recommissioning_rc5_closure.json",
    "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc5_closure.ps1",
    "sdk/turning/r23d55_godot_live_fixture_actuator_cap_conformance_v1.json",
    "tests/test_qsdk_r23d55_live_fixture_actuator_cap_contract.ps1",
    "tests/test_sdk_qsdk_r23d55_godot_live_fixture_actuator_cap_conformance.gd",
    "sdk/closure_evidence_provenance_contract.json",
    "tests/test_closure_evidence_provenance_contract.ps1",
    "sdk/closure_evidence_mode_inventory.json",
    "sdk/workbench/experiment_catalog.json",
    "sdk/release/quadruped_release_contract.json",
    "sdk/release/quadruped_support_matrix.json",
    "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc7_freeze.ps1"
)) {
    Assert-Lca1Rc7Freeze ($bindingPaths.Contains($requiredPath)) (
        "required exact dependency omitted: $requiredPath"
    )
}

$runnerPath = Join-Path $repoRoot ([string]$freeze.candidate_executor.path)
Assert-Lca1Rc7Freeze (
    (Get-Lca1Rc7Sha256 $runnerPath) -ceq
        [string]$freeze.candidate_executor.raw_sha256 -and
    (& git -C $repoRoot hash-object -- $runnerPath).Trim() -ceq
        [string]$freeze.candidate_executor.git_blob_oid
) "candidate executor bytes changed"

$runtime = $freeze.accepted_runtime
foreach ($role in @("profile_contract", "profile_registry", "profile_evaluator")) {
    $absolutePath = Join-Path $repoRoot ([string]$runtime[$role + "_path"])
    Assert-Lca1Rc7Freeze (
        (Get-Lca1Rc7Sha256 $absolutePath) -ceq
            [string]$runtime[$role + "_raw_sha256"]
    ) "runtime-profile source changed: $role"
}
$runtimeCandidate = Get-SporeSporeConformanceRuntimeProfileCandidate -RepoRoot $repoRoot
$profile = @($runtimeCandidate.profiles)[0]
Assert-Lca1Rc7Freeze (
    [string]$profile.profile_id -ceq [string]$runtime.profile_id -and
    [int]$profile.powershell.file_count -eq [int]$runtime.declared_file_count -and
    [long]$profile.powershell.byte_count -eq [long]$runtime.declared_byte_count -and
    [string]$profile.powershell.inventory_sha256 -ceq
        [string]$runtime.declared_inventory_sha256
) "accepted runtime-profile candidate changed"

$runtimeFiles = @(
    [ordered]@{ path = $runtime.outer_powershell_executable_path; hash = $runtime.outer_powershell_executable_raw_sha256 },
    [ordered]@{ path = $runtime.godot_executable_path; hash = $runtime.godot_executable_raw_sha256 },
    [ordered]@{ path = $runtime.python_executable_path; hash = $runtime.python_executable_raw_sha256 },
    [ordered]@{ path = $runtime.git_executable_path; hash = $runtime.git_executable_raw_sha256 },
    [ordered]@{ path = $runtime.cargo_executable_path; hash = $runtime.cargo_executable_raw_sha256 },
    [ordered]@{ path = $runtime.rustc_executable_path; hash = $runtime.rustc_executable_raw_sha256 }
)
foreach ($binding in $runtimeFiles) {
    Assert-Lca1Rc7Freeze (
        (Test-Path -LiteralPath ([string]$binding.path) -PathType Leaf) -and
        (Get-Lca1Rc7Sha256 ([string]$binding.path)) -ceq [string]$binding.hash
    ) "accepted runtime executable changed: $($binding.path)"
}
$outerRuntimeIdentity = & ([string]$runtime.outer_powershell_executable_path) `
    -NoLogo -NoProfile -Command (
        '$PSVersionTable.PSVersion.ToString() + "|" + ' +
        '$PSVersionTable.PSEdition + "|" + ' +
        '[Runtime.InteropServices.RuntimeInformation]::FrameworkDescription'
    )
Assert-Lca1Rc7Freeze (
    $outerRuntimeIdentity -ceq (
        [string]$runtime.powershell_version + "|" +
        [string]$runtime.powershell_edition + "|" +
        [string]$runtime.framework_description
    ) -and
    (& ([string]$runtime.godot_executable_path) --version) -ceq
        [string]$runtime.godot_version -and
    (& ([string]$runtime.python_executable_path) --version 2>&1) -ceq
        [string]$runtime.python_version -and
    (& ([string]$runtime.git_executable_path) --version) -ceq
        [string]$runtime.git_version -and
    (& ([string]$runtime.cargo_executable_path) --version) -ceq
        [string]$runtime.cargo_version -and
    (& ([string]$runtime.rustc_executable_path) --version) -ceq
        [string]$runtime.rustc_version
) "accepted runtime or toolchain version changed"

$cep1 = Read-Lca1Rc7Json (Join-Path $repoRoot "sdk/closure_evidence_mode_inventory.json")
$cadContract = Read-Lca1Rc7Json (
    Join-Path $repoRoot "sdk/conformance_audit_dependency_contract_v1.json"
)
$cadRegistry = Read-Lca1Rc7Json (
    Join-Path $repoRoot "sdk/conformance_audit_dependency_registry_v1.json"
)
Assert-Lca1Rc7Freeze (
    [int]$cep1.audit_count -eq 150 -and @($cep1.entries).Count -eq 150 -and
    [int]$cadContract.authority.cep1_audit_count -eq 150 -and
    [int]$cadContract.authority.registered_audit_count -eq 1 -and
    [int]$cadContract.authority.complete_audit_count -eq 1 -and
    [int]$cadContract.authority.unregistered_audit_count -eq 149 -and
    [int]$cadRegistry.cep1_audit_count -eq 150 -and
    @($cadRegistry.entries).Count -eq 1 -and
    [int]$cadRegistry.complete_audit_count -eq 1 -and
    [int]$cadRegistry.unregistered_audit_count -eq 149 -and
    -not [bool]$cadRegistry.cache_lookup_permitted -and
    -not [bool]$cadRegistry.result_reuse_permitted
) "RC7 audit-dependency count reconciliation changed"

$release = Read-Lca1Rc7Json (Join-Path $repoRoot "sdk/release/quadruped_release_contract.json")
$support = Read-Lca1Rc7Json (Join-Path $repoRoot "sdk/release/quadruped_support_matrix.json")
$blockKey = "prospective_r23d55_live_fixture_actuator_cap_conformance"
$releaseBlocks = @(Find-Lca1Rc7ObjectsWithKey -Value $release -Key $blockKey)
$supportBlocks = @(Find-Lca1Rc7ObjectsWithKey -Value $support -Key $blockKey)
Assert-Lca1Rc7Freeze ($releaseBlocks.Count -eq 1 -and $supportBlocks.Count -eq 1) (
    "R23D55 release/support authority is ambiguous"
)
foreach ($parent in @($releaseBlocks[0], $supportBlocks[0])) {
    $block = $parent[$blockKey]
    Assert-Lca1Rc7Freeze (
        [string]$block.lca1_rc6_status -ceq
            "closed_negative_full_stage_1_cep1_audit_dependency_count_mismatch_scoped_not_started" -and
        -not [bool]$block.lca1_rc6_same_source_rerun_allowed -and
        [string]$block.lca1_rc7_program_id -ceq [string]$freeze.program_id -and
        [string]$block.lca1_rc7_status -ceq
            "prospective_zero_world_exact_same_source_full_scoped_pair_not_executed" -and
        [string]$block.lca1_rc7_question_class -ceq "equivalence_non_inferiority" -and
        [string]$block.lca1_rc7_declared_from_parent_commit -ceq
            "b96bf2452889d0ca2050a48ef81e82a6666410bb" -and
        [int]$block.lca1_rc7_semantic_count_field_change_count -eq 4 -and
        [int]$block.lca1_rc7_test_count_literal_change_count -eq 8 -and
        [int]$block.lca1_rc7_post_incident_additional_test_literal_count -eq 2 -and
        [bool]$block.lca1_rc7_audit_dependency_preflight_required -and
        [bool]$block.lca1_rc7_dependency_key_preflight_required -and
        [int]$block.lca1_rc7_runner_source_change_count -eq 0 -and
        [bool]$block.lca1_rc7_complete_full_scoped_pair_required -and
        [int]$block.lca1_rc7_full_required_stage_count -eq 8 -and
        [int]$block.lca1_rc7_scoped_required_executed_gate_count -eq 16 -and
        [int]$block.lca1_rc7_scoped_required_gate_cas_object_count -eq 48 -and
        [int]$block.lca1_rc7_source_runtime_host_identity_margin -eq 0 -and
        [int]$block.lca1_rc7_claim_vector_margin -eq 0 -and
        -not [bool]$block.lca1_rc7_prior_result_reuse_allowed -and
        -not [bool]$block.lca1_rc7_pair_executed -and
        -not [bool]$block.lca1_rc7_commissioning_passed -and
        [int]$block.lca1_rc7_physical_world_count -eq 0 -and
        -not [bool]$block.canonical_full_conformance_recommissioned_for_current_source -and
        -not [bool]$block.physical_successor_opened -and
        -not [bool]$block.turning_acceptance -and
        -not [bool]$block.prone_to_standing -and
        -not [bool]$block.physical_acceptance_authority -and
        -not [bool]$block.release_authority
    ) "RC7 release/support boundary changed"
}

Assert-Lca1Rc7Freeze (
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
    @($manifest.source_bindings).Count -eq 54 -and
    [string]$manifest.dependency_authority.path -ceq
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc7_freeze.json" -and
    [string]$manifest.dependency_authority.raw_sha256 -ceq
        (Get-Lca1Rc7Sha256 $freezePath) -and
    @($manifest.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "RC7 campaign manifest boundary changed"

$manifestBindings = @{}
foreach ($binding in @($manifest.source_bindings)) {
    $relativePath = [string]$binding.path
    Assert-Lca1Rc7Freeze (-not $manifestBindings.ContainsKey($relativePath)) (
        "duplicate manifest source binding: $relativePath"
    )
    $manifestBindings[$relativePath] = [string]$binding.raw_sha256
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Lca1Rc7Freeze (
        (Test-Path -LiteralPath $absolutePath -PathType Leaf) -and
        (Get-Lca1Rc7Sha256 $absolutePath) -ceq [string]$binding.raw_sha256
    ) "manifest source binding changed: $relativePath"
}
foreach ($binding in @($freeze.exact_dependency_bindings)) {
    Assert-Lca1Rc7Freeze (
        $manifestBindings.ContainsKey([string]$binding.path) -and
        [string]$manifestBindings[[string]$binding.path] -ceq
            [string]$binding.raw_sha256
    ) "freeze dependency not mirrored by manifest: $($binding.path)"
}
Assert-Lca1Rc7Freeze (
    $manifestBindings.ContainsKey(
        "sdk/locomotion_campaign_attestation_v1_recommissioning_rc7_freeze.json"
    )
) "manifest omitted its dependency authority"

Invoke-Lca1Rc7PowerShellMarker (
    Join-Path $repoRoot "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc6_incident.ps1"
) "LCA1_RC6_INCIDENT_PASS "
Invoke-Lca1Rc7PowerShellMarker (
    Join-Path $repoRoot "tests/test_conformance_audit_dependency.ps1"
) "CONFORMANCE_AUDIT_DEPENDENCY_PASS "
Invoke-Lca1Rc7PowerShellMarker (
    Join-Path $repoRoot "tests/test_conformance_dependency_key.ps1"
) "CONFORMANCE_DEPENDENCY_KEY_PASS "
Invoke-Lca1Rc7PowerShellMarker (
    Join-Path $repoRoot "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc5_closure.ps1"
) "LCA1_RC5_CLOSURE_PASS "
Invoke-Lca1Rc7PowerShellMarker (
    Join-Path $repoRoot "tests/test_qsdk_r23d55_live_fixture_actuator_cap_contract.ps1"
) "QSDK_R23D55_LIVE_FIXTURE_ACTUATOR_CAP_CONTRACT_PASS "
Invoke-Lca1Rc7PowerShellMarker (
    Join-Path $repoRoot "tests/test_closure_evidence_provenance_contract.ps1"
) "CLOSURE_EVIDENCE_PROVENANCE_CONTRACT_PASS "
Invoke-Lca1Rc7PowerShellMarker (
    Join-Path $repoRoot "tests/test_locomotion_experiment_workbench.ps1"
) "LOCOMOTION_EXPERIMENT_WORKBENCH_AUDIT_PASS " @("-Godot", $Godot)

$godotOutput = @(& $Godot --headless --path $repoRoot --script (
    "res://tests/test_sdk_qsdk_r23d55_godot_live_fixture_actuator_cap_conformance.gd"
) 2>&1)
$godotExitCode = $LASTEXITCODE
Assert-Lca1Rc7Freeze ($godotExitCode -eq 0) (
    "R23D55 runtime gate failed: $($godotOutput -join ' | ')"
)
Assert-Lca1Rc7Freeze (
    @($godotOutput | Where-Object {
        [string]$_ -clike "QSDK_R23D55_GODOT_LIVE_FIXTURE_ACTUATOR_CAP_CONFORMANCE *"
    }).Count -eq 1
) "R23D55 runtime marker cardinality changed"

$requiredMarkers = $freeze.estimand_and_exact_acceptance.required_terminal_marker_counts
Assert-Lca1Rc7Freeze (
    @($requiredMarkers.Keys).Count -eq 4 -and
    @($requiredMarkers.Values | Where-Object { [int]$_ -ne 1 }).Count -eq 0
) "required marker cardinalities changed"

Write-Host (
    "LCA1_RC7_FREEZE_PASS class=equivalence_non_inferiority pairs=1 " +
    "runtime=7.6.4 runtime_files=86 runtime_bytes=85258167 " +
    "cep1=150 declared=150 unregistered=149 preflight=direct_both " +
    "full_stages=8 scoped_gates=16 cas=48 markers=4 " +
    "dependencies=53 claim_margin=0 prior_reuse=False " +
    "mutations=$mutationRefusals models=0 worlds=0 " +
    "physical_authority=False release_authority=False"
)

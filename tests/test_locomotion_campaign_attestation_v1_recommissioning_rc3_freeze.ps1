#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$freezePath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc3_freeze.json"
)
$manifestPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc3_manifest.json"
)
$runnerPath = Join-Path $sdkRoot "run_conformance.ps1"
$acceptedPowerShell = "C:\Program Files\PowerShell\7\pwsh.exe"
$rejectedPowerShell = "C:\Program Files\PowerShell\7-preview\pwsh.exe"
$commissionedSource = "655d425b25606ca81cb821c8fdc61d7bf771d7af"

. (Join-Path $sdkRoot "locomotion_campaign_attestation.ps1")
. (Join-Path $sdkRoot "conformance_dependency_key.ps1")

function Assert-Lca1Rc3([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "LCA1_RC3_FREEZE $Message" }
}

function Read-Lca1Rc3Json([string]$Path) {
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-Lca1Rc3Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Copy-Lca1Rc3([object]$Value) {
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Test-Lca1Rc3FreezeDocument(
    [Parameter(Mandatory)][System.Collections.IDictionary]$Document
) {
    $failures = [Collections.Generic.List[string]]::new()
    if ([string]$Document.schema_version -cne
        "sporespore_locomotion_campaign_attestation_v1_recommissioning_rc3_freeze_v1" -or
        [string]$Document.status -cne
        "prospective_zero_world_runtime_pinned_complete_cold_full_scoped_pair_required") {
        $failures.Add("IDENTITY")
    }
    if ([string]$Document.program_id -cne
            "LCA1-RC3-RUNTIME-PINNED-EXPANDED-CANONICAL-RUNNER-RECOMMISSIONING" -or
        [string]$Document.question_class -cne "equivalence_non_inferiority" -or
        [bool]$Document.physical_question) {
        $failures.Add("QUESTION")
    }
    $prior = $Document.immutable_rc2_negative
    if ([string]$prior.failed_source_commit -cne
            "0d5c44986a4783269fead70b14472fcdbace7736" -or
        [string]$prior.failure_message -cne
            "PowerShell runtime profile file count or byte count changed." -or
        [int]$prior.full_stage_receipt_count -ne 1 -or
        [bool]$prior.scoped_attempted -or
        [int]$prior.physical_world_count -ne 0 -or
        [bool]$prior.same_source_rerun_allowed -or
        [bool]$prior.observed_result_may_be_rewritten) {
        $failures.Add("RC2")
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
        $failures.Add("ACCEPTED_RUNTIME")
    }
    $rejected = $Document.rejected_rc2_runtime
    if ([string]$rejected.executable_path -cne
            "C:/Program Files/PowerShell/7-preview/pwsh.exe" -or
        [string]$rejected.powershell_version -cne "7.6.0-preview.6" -or
        [int]$rejected.observed_file_count -ne 86 -or
        [long]$rejected.observed_byte_count -ne 85403280 -or
        [int]$rejected.file_count_delta -ne 0 -or
        [long]$rejected.byte_count_delta -ne 145113 -or
        [bool]$rejected.runtime_profile_match -or
        [bool]$rejected.eligible_for_rc3) {
        $failures.Add("REJECTED_RUNTIME")
    }
    $pair = $Document.prospective_pair
    if ([int]$pair.pair_count -ne 1 -or
        (@($pair.execution_order) -join "|") -cne
            "complete_full_godot_v2|scoped_lca1_rc3" -or
        -not [bool]$pair.serialized -or
        -not [bool]$pair.same_clean_pushed_source_commit_and_tree_required -or
        -not [bool]$pair.outer_powershell_must_equal_accepted_runtime -or
        -not [bool]$pair.nested_powershell_must_equal_accepted_runtime -or
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
    if (-not [bool]$Document.development_calibration_only.
            accepted_runtime_matches_prior_run -or
        [bool]$Document.development_calibration_only.
            complete_source_commit_and_tree_match_candidate_freeze -or
        [bool]$Document.development_calibration_only.transitive_dependency_key_complete -or
        [bool]$Document.development_calibration_only.reuse_as_rc3_full_baseline_allowed -or
        -not [bool]$Document.development_calibration_only.
            adequate_only_for_runtime_selection_and_candidate_feasibility) {
        $failures.Add("REUSE")
    }
    if ([bool]$Document.immutable_prior_commissioning.
            old_closure_or_results_may_be_rewritten -or
        [bool]$Document.immutable_prior_commissioning.
            old_contract_may_be_repointed_before_rc3_positive_closure -or
        -not [bool]$Document.promotion_rule.rc2_negative_remains_immutable -or
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

Assert-Lca1Rc3 (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$freeze = Read-Lca1Rc3Json $freezePath
$freezeTest = Test-Lca1Rc3FreezeDocument -Document $freeze
Assert-Lca1Rc3 ([bool]$freezeTest.ok) (
    "prospective freeze changed: $(@($freezeTest.failure_codes) -join ',')"
)

$mutations = @(
    @{ name = "question_class"; apply = { param($d) $d.question_class = "development" } },
    @{ name = "rc2_rerun"; apply = { param($d) $d.immutable_rc2_negative.same_source_rerun_allowed = $true } },
    @{ name = "runtime_path"; apply = { param($d) $d.accepted_runtime.outer_powershell_executable_path = "C:/Program Files/PowerShell/7-preview/pwsh.exe" } },
    @{ name = "runtime_hash"; apply = { param($d) $d.accepted_runtime.outer_powershell_executable_raw_sha256 = "sha256:" + ("0" * 64) } },
    @{ name = "runtime_bytes"; apply = { param($d) $d.accepted_runtime.declared_byte_count++ } },
    @{ name = "runtime_margin"; apply = { param($d) $d.accepted_runtime.declared_inventory_count_and_byte_margin = 1 } },
    @{ name = "profile_preflight"; apply = { param($d) $d.accepted_runtime.runtime_profile_candidate_preflight_required = $false } },
    @{ name = "rejected_runtime"; apply = { param($d) $d.rejected_rc2_runtime.eligible_for_rc3 = $true } },
    @{ name = "pair_count"; apply = { param($d) $d.prospective_pair.pair_count = 2 } },
    @{ name = "prior_reuse"; apply = { param($d) $d.prospective_pair.prior_result_reuse_allowed = $true } },
    @{ name = "full_stages"; apply = { param($d) $d.estimand_and_exact_acceptance.full_required_stage_count = 7 } },
    @{ name = "scoped_gates"; apply = { param($d) $d.estimand_and_exact_acceptance.scoped_required_executed_gate_count = 15 } },
    @{ name = "cas_count"; apply = { param($d) $d.estimand_and_exact_acceptance.scoped_required_gate_cas_object_count = 47 } },
    @{ name = "marker_margin"; apply = { param($d) $d.estimand_and_exact_acceptance.marker_cardinality_margin = 1 } },
    @{ name = "world_count"; apply = { param($d) $d.prospective_pair.world_build_count = 1 } },
    @{ name = "claim_inflation"; apply = { param($d) $d.claims.physical_acceptance_authority = $true } }
)
$mutationRefusals = 0
foreach ($mutation in $mutations) {
    $copy = Copy-Lca1Rc3 $freeze
    & $mutation.apply $copy
    $result = Test-Lca1Rc3FreezeDocument -Document $copy
    Assert-Lca1Rc3 (-not [bool]$result.ok) (
        "freeze mutation was accepted: $($mutation.name)"
    )
    $mutationRefusals++
}

$priorAudits = @(
    [ordered]@{
        path = [string]$freeze.immutable_rc2_negative.freeze_audit_path
        marker = "LCA1_RC2_FREEZE_PASS "
    },
    [ordered]@{
        path = [string]$freeze.immutable_rc2_negative.incident_audit_path
        marker = "LCA1_RC2_INCIDENT_PASS "
    }
)
foreach ($audit in $priorAudits) {
    $output = @(& $acceptedPowerShell -NoLogo -NoProfile -File (
        Join-Path $repoRoot ([string]$audit.path)
    ) 2>&1)
    $exitCode = $LASTEXITCODE
    Assert-Lca1Rc3 (
        $exitCode -eq 0 -and
        @($output | Where-Object {
            ([string]$_).StartsWith(
                [string]$audit.marker,
                [StringComparison]::Ordinal
            )
        }).Count -eq 1
    ) "immutable predecessor audit failed: $($audit.path)"
}

foreach ($role in @("incident", "incident_audit", "freeze", "manifest", "freeze_audit")) {
    $pathKey = $role + "_path"
    $hashKey = $role + "_raw_sha256"
    $absolute = Join-Path $repoRoot (
        [string]$freeze.immutable_rc2_negative[$pathKey]
    )
    Assert-Lca1Rc3 (
        (Get-Lca1Rc3Sha256 $absolute) -ceq
            [string]$freeze.immutable_rc2_negative[$hashKey]
    ) "immutable RC2 source changed: $role"
}

foreach ($role in @("closure", "closure_audit", "adoption_contract")) {
    $pathKey = $role + "_path"
    $hashKey = $role + "_raw_sha256"
    $absolute = Join-Path $repoRoot (
        [string]$freeze.immutable_prior_commissioning[$pathKey]
    )
    Assert-Lca1Rc3 (
        (Get-Lca1Rc3Sha256 $absolute) -ceq
            [string]$freeze.immutable_prior_commissioning[$hashKey]
    ) "immutable prior commissioning source changed: $role"
}

$processPath = [IO.Path]::GetFullPath((Get-Process -Id $PID).Path)
$resolvedNested = [IO.Path]::GetFullPath((
    Get-Command pwsh -CommandType Application | Select-Object -First 1
).Source)
$runtimeIdentity = (
    $PSVersionTable.PSVersion.ToString() + "|" +
    $PSVersionTable.PSEdition + "|" +
    [Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
)
Assert-Lca1Rc3 (
    $processPath -ceq $acceptedPowerShell -and
    $resolvedNested -ceq $acceptedPowerShell -and
    (Get-Lca1Rc3Sha256 $acceptedPowerShell) -ceq
        [string]$freeze.accepted_runtime.outer_powershell_executable_raw_sha256 -and
    $runtimeIdentity -ceq "7.6.4|Core|.NET 10.0.10"
) "current outer or nested PowerShell is not the accepted runtime"

foreach ($role in @("profile_contract", "profile_registry", "profile_evaluator")) {
    $absolute = Join-Path $repoRoot (
        [string]$freeze.accepted_runtime[$role + "_path"]
    )
    Assert-Lca1Rc3 (
        (Get-Lca1Rc3Sha256 $absolute) -ceq
            [string]$freeze.accepted_runtime[$role + "_raw_sha256"]
    ) "accepted runtime-profile source changed: $role"
}
$registry = Get-SporeSporeConformanceRuntimeProfileRegistry
$profile = @($registry.profiles)[0]
$acceptedInventory = Get-SporeSporeDeclaredFileInventory `
    -Root (Split-Path -Parent $acceptedPowerShell) `
    -RelativePaths @($profile.powershell.relative_files) `
    -InventoryId "powershell_r23d13_parent"
$rejectedInventory = Get-SporeSporeDeclaredFileInventory `
    -Root (Split-Path -Parent $rejectedPowerShell) `
    -RelativePaths @($profile.powershell.relative_files) `
    -InventoryId "powershell_rc2_failed_preview_runtime"
$runtimeCandidate = Get-SporeSporeConformanceRuntimeProfileCandidate `
    -RepoRoot $repoRoot
Assert-Lca1Rc3 (
    [string]$profile.profile_id -ceq [string]$freeze.accepted_runtime.profile_id -and
    [int]$acceptedInventory.file_count -eq
        [int]$freeze.accepted_runtime.declared_file_count -and
    [long]$acceptedInventory.byte_count -eq
        [long]$freeze.accepted_runtime.declared_byte_count -and
    [string]$acceptedInventory.inventory_sha256 -ceq
        [string]$freeze.accepted_runtime.declared_inventory_sha256 -and
    [int]$rejectedInventory.file_count -eq
        [int]$freeze.rejected_rc2_runtime.observed_file_count -and
    [long]$rejectedInventory.byte_count -eq
        [long]$freeze.rejected_rc2_runtime.observed_byte_count -and
    [string]$rejectedInventory.inventory_sha256 -ceq
        [string]$freeze.rejected_rc2_runtime.observed_inventory_sha256 -and
    [string]$runtimeCandidate.status -ceq
        "partial_runtime_profile_cache_disabled" -and
    @($runtimeCandidate.profiles).Count -eq 1 -and
    [string]$runtimeCandidate.profiles[0].powershell.inventory_sha256 -ceq
        [string]$freeze.accepted_runtime.declared_inventory_sha256 -and
    -not [bool]$runtimeCandidate.cache_lookup_permitted -and
    -not [bool]$runtimeCandidate.result_reuse_permitted -and
    -not [bool]$runtimeCandidate.physical_authority
) "accepted or rejected runtime-profile preflight changed"

$runnerHash = Get-Lca1Rc3Sha256 $runnerPath
$runnerBlob = (& git -C $repoRoot hash-object -- $runnerPath).Trim()
$numstat = ((& git -C $repoRoot diff --numstat (
    $commissionedSource + "..HEAD"
) -- "sdk/run_conformance.ps1") -join "`n").Trim() -split "\s+"
Assert-Lca1Rc3 (
    $runnerHash -ceq [string]$freeze.candidate_executor.candidate_raw_sha256 -and
    $runnerBlob -ceq [string]$freeze.candidate_executor.candidate_git_blob_oid -and
    (Get-Item -LiteralPath $runnerPath).Length -eq
        [long]$freeze.candidate_executor.candidate_byte_length -and
    [int]$numstat[0] -eq 111 -and [int]$numstat[1] -eq 0
) "candidate canonical runner identity changed"

$priorReceiptPath = [string]$freeze.development_calibration_only.prior_receipt_path
$priorLogPath = [string]$freeze.development_calibration_only.prior_full_log_path
Assert-Lca1Rc3 (
    (Get-Lca1Rc3Sha256 $priorReceiptPath) -ceq
        [string]$freeze.development_calibration_only.prior_receipt_raw_sha256 -and
    (Get-Lca1Rc3Sha256 $priorLogPath) -ceq
        [string]$freeze.development_calibration_only.prior_full_log_raw_sha256
) "development calibration evidence changed"
$priorReceipt = Read-Lca1Rc3Json $priorReceiptPath
Assert-Lca1Rc3 (
    [string]$priorReceipt.status -ceq "passed" -and
    [string]$priorReceipt.source.head -ceq
        [string]$freeze.development_calibration_only.
            prior_full_conformance_source_commit -and
    [string]$priorReceipt.source.head_tree -ceq
        [string]$freeze.development_calibration_only.
            prior_full_conformance_source_tree_git_oid -and
    [string]$priorReceipt.toolchain_runtime_identity.powershell.executable_sha256 -ceq
        [string]$freeze.accepted_runtime.outer_powershell_executable_raw_sha256 -and
    -not [bool]$priorReceipt.source.transitive_dependency_key_complete -and
    @($priorReceipt.stage_receipts).Count -eq 8 -and
    @($priorReceipt.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "development calibration receipt changed or became reusable"

$manifest = Get-SporeSporeCampaignAttestationManifest -Path $manifestPath
Assert-Lca1Rc3 (
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
) "RC3 scoped manifest changed"
$candidate = Get-SporeSporeCampaignAttestationCandidate `
    -RepoRoot $repoRoot -ManifestPath $manifestPath -TestOnly
Assert-Lca1Rc3 (
    [int]$candidate.global_gate_count -eq 12 -and
    [int]$candidate.lineage_gate_count -eq 1 -and
    [int]$candidate.campaign_gate_count -eq 3 -and
    [bool]$candidate.campaign_roles_complete -and
    [bool]$candidate.godot_including -and
    -not [bool]$candidate.commissioned -and
    -not [bool]$candidate.physical_launch_prerequisite_satisfied -and
    -not [bool]$candidate.physical_acceptance_authority
) "RC3 scoped candidate projection changed"

Write-Host (
    "LCA1_RC3_FREEZE_PASS class=equivalence_non_inferiority pairs=1 " +
    "runtime=7.6.4 runtime_files=86 runtime_bytes=85258167 " +
    "full_stages=8 scoped_gates=16 cas=48 markers=4 prior_reuse=False " +
    "mutations=$mutationRefusals models=0 worlds=0 " +
    "physical_authority=False release_authority=False"
)

#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$incidentPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc6_incident.json"
)

. (Join-Path $sdkRoot "content_addressed_artifact_store.ps1")

function Assert-Lca1Rc6Incident([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "LCA1_RC6_INCIDENT $Message" }
}

function Read-Lca1Rc6IncidentJson([string]$Path) {
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-Lca1Rc6IncidentSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Copy-Lca1Rc6IncidentDocument([object]$Value) {
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-Lca1Rc6IncidentSourceBlob(
    [Parameter(Mandatory)][string]$Commit,
    [Parameter(Mandatory)][string]$Path
) {
    $oid = (& git -C $repoRoot rev-parse "$Commit`:$Path").Trim()
    Assert-Lca1Rc6Incident ($LASTEXITCODE -eq 0) "missing source blob: $Path"
    $type = (& git -C $repoRoot cat-file -t $oid).Trim()
    $bytes = [long]((& git -C $repoRoot cat-file -s $oid).Trim())
    Assert-Lca1Rc6Incident (
        $LASTEXITCODE -eq 0 -and $type -ceq "blob"
    ) "invalid source object: $Path"
    return [ordered]@{ oid = $oid; byte_length = $bytes }
}

function Read-Lca1Rc6IncidentSourceJson(
    [Parameter(Mandatory)][string]$Commit,
    [Parameter(Mandatory)][string]$Path
) {
    $text = @(& git -C $repoRoot show "$Commit`:$Path") -join "`n"
    Assert-Lca1Rc6Incident ($LASTEXITCODE -eq 0) (
        "cannot read source JSON: $Commit`:$Path"
    )
    return $text | ConvertFrom-Json -AsHashtable -Depth 100
}

function Test-Lca1Rc6IncidentDocument(
    [Parameter(Mandatory)][System.Collections.IDictionary]$Document
) {
    $failures = [Collections.Generic.List[string]]::new()
    if ([string]$Document.schema_version -cne
            "sporespore_locomotion_campaign_attestation_commissioning_incident_v1" -or
        [string]$Document.incident_id -cne "LCA1-RC6-COLD-PAIR-20260815" -or
        [string]$Document.status -cne
            "closed_negative_full_stage_1_cep1_audit_dependency_count_mismatch_scoped_not_started") {
        $failures.Add("IDENTITY")
    }
    if ([string]$Document.question_class -cne "equivalence_non_inferiority" -or
        [bool]$Document.physical_question) {
        $failures.Add("QUESTION")
    }
    $source = $Document.observed_source_identity
    if ([string]$source.commit -cne
            "6457be4a6d42794b60331b50eb2e399c16c589e4" -or
        [string]$source.tree_git_oid -cne
            "70c5ba297ea7d31cd616bdba8162c818a2dd0e33" -or
        [string]$source.origin_main -cne [string]$source.commit -or
        [string]$source.live_github_main -cne [string]$source.commit -or
        [string]$source.remote_url -cne
            "https://github.com/Slagathore/sporespore.git" -or
        [string]$source.branch -cne "main" -or
        -not [bool]$source.worktree_clean) {
        $failures.Add("SOURCE")
    }
    $pre = $Document.preregistration
    if ([string]$pre.freeze_path -cne
            "sdk/locomotion_campaign_attestation_v1_recommissioning_rc6_freeze.json" -or
        [string]$pre.freeze_raw_sha256 -cne
            "sha256:b412c9e0ea22e0ba47ef77c69cf604d0074d46d3a95bd3cc51c6c52a7f79960c" -or
        [string]$pre.freeze_git_blob_oid -cne
            "f3ac0ffb1f80204ce121f42b6d59ec2f35026387" -or
        [long]$pre.freeze_byte_length -ne 19495 -or
        [string]$pre.manifest_path -cne
            "sdk/locomotion_campaign_attestation_v1_recommissioning_rc6_manifest.json" -or
        [string]$pre.manifest_raw_sha256 -cne
            "sha256:c7f11f894df544451cb80b7b308e989519704b9d3dbab5677159ee97dfec299b" -or
        [string]$pre.manifest_git_blob_oid -cne
            "898ec86d28afca204e13ac20f0fee70731d5d76e" -or
        [long]$pre.manifest_byte_length -ne 11638 -or
        [string]$pre.freeze_audit_path -cne
            "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc6_freeze.ps1" -or
        [string]$pre.freeze_audit_raw_sha256 -cne
            "sha256:443000cd6d290aec91e205e9647f5b0b1187b3cca468f49bf3c220644dee9e5a" -or
        [string]$pre.freeze_audit_git_blob_oid -cne
            "6475c085c90ebace7fff7a71454cf8de4d1e8cd7" -or
        [long]$pre.freeze_audit_byte_length -ne 25772 -or
        [string]$pre.program_id -cne
            "LCA1-RC6-R23D55-CANONICAL-RUNNER-RECOMMISSIONING" -or
        [int]$pre.pair_count -ne 1 -or
        [int]$pre.full_required_stage_count -ne 8 -or
        [int]$pre.scoped_required_executed_gate_count -ne 16 -or
        [int]$pre.scoped_required_gate_cas_object_count -ne 48 -or
        [bool]$pre.same_source_rerun_after_complete_or_failed_pair_allowed -or
        [bool]$pre.prior_result_reuse_allowed -or
        [int]$pre.physical_world_count -ne 0) {
        $failures.Add("PREREGISTRATION")
    }
    $launch = $Document.launch
    if ([bool]$launch.full_attestation_created -or
        [bool]$launch.scoped_output_root_created -or
        [bool]$launch.scoped_attempted -or
        [int]$launch.pair_root_entry_count_after_failure -ne 0) {
        $failures.Add("LAUNCH")
    }
    $full = $Document.cold_full_v2
    if ([string]$full.status -cne
            "failed_stage_1_cep1_audit_dependency_count_mismatch" -or
        [string]$full.run_id -cne
            "20260815T084153Z-6457be4a-6ec5222cd72b4e428f5dc5b4b8a9f337" -or
        [int]$full.required_stage_count -ne 8 -or
        [int]$full.stage_receipt_count -ne 1 -or
        [int]$full.failed_stage_count -ne 1 -or
        [string]$full.first_failed_stage_id -cne
            "authority_and_historical_closures" -or
        [int]$full.first_failed_stage_ordinal -ne 1 -or
        [int]$full.first_failed_stage_exit_code -ne 1 -or
        [string]$full.canonical_failure_message -cne
            "Audit-dependency registry no longer reconciles with CEP1." -or
        [string]$full.cache_status -cne "disabled_uncommissioned" -or
        [bool]$full.cache_lookup_performed -or [bool]$full.result_reused -or
        [string]$full.observed_input_status -cne "observed_not_transitive" -or
        [string]$full.dependency_key_candidate_status -cne
            "candidate_construction_failed" -or
        [bool]$full.full_attestation_created -or
        [int]$full.physical_campaign_process_launch_count -ne 0 -or
        [int]$full.model_construction_count -ne 0 -or
        [int]$full.world_attempt_count -ne 0 -or
        [int]$full.world_build_count -ne 0) {
        $failures.Add("FULL")
    }
    $scoped = $Document.cold_scoped_lca1
    if ([string]$scoped.status -cne
            "not_started_after_full_stage_1_failure" -or
        [bool]$scoped.attempted -or [bool]$scoped.output_root_created -or
        [int]$scoped.gate_execution_count -ne 0 -or
        [int]$scoped.gate_cas_object_count -ne 0 -or
        [int]$scoped.physical_worlds_opened -ne 0) {
        $failures.Add("SCOPED")
    }
    $diagnosis = $Document.audit_dependency_count_diagnosis
    if ([string]$diagnosis.classification -cne
            "post_failure_deterministic_source_count_reconciliation_diagnosis" -or
        [string]$diagnosis.last_reconciled_inventory_source_commit -cne
            "1baf64e9ae49ca27ce062613947434d391f8ef3a" -or
        [int]$diagnosis.last_reconciled_cep1_audit_count -ne 148 -or
        [int]$diagnosis.observed_cep1_audit_count -ne 150 -or
        [int]$diagnosis.observed_count_delta -ne 2 -or
        [int]$diagnosis.added_audit_entry_count -ne 2 -or
        [int]$diagnosis.removed_audit_entry_count -ne 0 -or
        @($diagnosis.added_audit_entries).Count -ne 2 -or
        [string]$diagnosis.added_audit_entries[0].path -cne
            "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc5_closure.ps1" -or
        [string]$diagnosis.added_audit_entries[0].raw_sha256 -cne
            "11defd8f9e1a4227dfde1b97e2702f8131e1b14a991a9dd0eef9d07897429358" -or
        [string]$diagnosis.added_audit_entries[0].historical_identity_mode -cne
            "pinned_git_blob" -or
        [bool]$diagnosis.added_audit_entries[0].manual_review_required -or
        [string]$diagnosis.added_audit_entries[1].path -cne
            "tests/test_qsdk_r23d54_closure.ps1" -or
        [string]$diagnosis.added_audit_entries[1].raw_sha256 -cne
            "9037eac6d5b363a7c98bbc8b24f17a5e6634c164931e131a3947ae0dfb07e0e3" -or
        [string]$diagnosis.added_audit_entries[1].historical_identity_mode -cne
            "pinned_git_blob" -or
        [bool]$diagnosis.added_audit_entries[1].manual_review_required -or
        [int]$diagnosis.contract.declared_cep1_audit_count -ne 148 -or
        [int]$diagnosis.contract.declared_unregistered_audit_count -ne 147 -or
        [int]$diagnosis.registry.declared_cep1_audit_count -ne 148 -or
        [int]$diagnosis.registry.declared_unregistered_audit_count -ne 147 -or
        [int]$diagnosis.registry.registered_audit_count -ne 1 -or
        [int]$diagnosis.registry.complete_audit_count -ne 1 -or
        -not [bool]$diagnosis.contract.unchanged_from_last_reconciled_source -or
        -not [bool]$diagnosis.registry.unchanged_from_last_reconciled_source -or
        -not [bool]$diagnosis.candidate_evaluator.
            unchanged_from_last_reconciled_source -or
        -not [bool]$diagnosis.candidate_test.unchanged_from_last_reconciled_source -or
        [int]$diagnosis.stale_semantic_count_field_count -ne 4 -or
        [int]$diagnosis.stale_test_count_literal_count -ne 6 -or
        [int]$diagnosis.required_successor_change_count -ne 10 -or
        [bool]$diagnosis.runner_source_change_required -or
        [bool]$diagnosis.candidate_evaluator_source_change_required -or
        [bool]$diagnosis.physics_change_required -or
        [bool]$diagnosis.controller_change_required -or
        [bool]$diagnosis.threshold_or_margin_change_required) {
        $failures.Add("DIAGNOSIS")
    }
    $interpretation = $Document.interpretation
    if (-not [bool]$interpretation.process_commissioning_failure -or
        [bool]$interpretation.executor_semantics_evaluated -or
        [bool]$interpretation.executor_equivalence_or_non_inferiority_promoted -or
        [bool]$interpretation.physics_failure -or
        [bool]$interpretation.scientific_failure -or
        [string]$interpretation.failure_class -cne
            "full_runner_dependency_candidate_pinned_stale_cep1_audit_counts" -or
        [bool]$interpretation.same_source_rerun_authorized -or
        [bool]$interpretation.observed_result_or_interpretation_rewrite_authorized -or
        [bool]$interpretation.threshold_change_authorized -or
        [bool]$interpretation.controller_change_authorized -or
        [bool]$interpretation.physics_change_authorized -or
        [bool]$interpretation.physical_rerun_authorized_by_incident) {
        $failures.Add("INTERPRETATION")
    }
    $trueClaims = @($Document.claims.Keys | Where-Object {
        $_ -cne "rc6_full_half_attempted" -and [bool]$Document.claims[$_]
    })
    if (-not [bool]$Document.claims.rc6_full_half_attempted -or
        $trueClaims.Count -ne 0) {
        $failures.Add("CLAIMS")
    }
    return [ordered]@{
        ok = $failures.Count -eq 0
        failure_codes = @($failures | Sort-Object -Unique)
    }
}

Assert-Lca1Rc6Incident (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$incident = Read-Lca1Rc6IncidentJson $incidentPath
$documentTest = Test-Lca1Rc6IncidentDocument -Document $incident
Assert-Lca1Rc6Incident ([bool]$documentTest.ok) (
    "incident document changed: $(@($documentTest.failure_codes) -join ',')"
)

$mutations = @(
    @{ name = "status"; apply = { param($d) $d.status = "passed" } },
    @{ name = "question"; apply = { param($d) $d.physical_question = $true } },
    @{ name = "source"; apply = { param($d) $d.observed_source_identity.commit = "0" * 40 } },
    @{ name = "freeze"; apply = { param($d) $d.preregistration.freeze_raw_sha256 = "sha256:" + ("0" * 64) } },
    @{ name = "rerun"; apply = { param($d) $d.preregistration.same_source_rerun_after_complete_or_failed_pair_allowed = $true } },
    @{ name = "full_status"; apply = { param($d) $d.cold_full_v2.status = "passed" } },
    @{ name = "full_stage_count"; apply = { param($d) $d.cold_full_v2.stage_receipt_count = 8 } },
    @{ name = "reuse"; apply = { param($d) $d.cold_full_v2.result_reused = $true } },
    @{ name = "scoped"; apply = { param($d) $d.cold_scoped_lca1.attempted = $true } },
    @{ name = "inventory"; apply = { param($d) $d.audit_dependency_count_diagnosis.observed_cep1_audit_count = 149 } },
    @{ name = "contract"; apply = { param($d) $d.audit_dependency_count_diagnosis.contract.declared_cep1_audit_count = 150 } },
    @{ name = "registry"; apply = { param($d) $d.audit_dependency_count_diagnosis.registry.declared_unregistered_audit_count = 149 } },
    @{ name = "addition"; apply = { param($d) $d.audit_dependency_count_diagnosis.added_audit_entries[0].path = "tests/forged.ps1" } },
    @{ name = "repair"; apply = { param($d) $d.audit_dependency_count_diagnosis.required_successor_change_count = 9 } },
    @{ name = "runner"; apply = { param($d) $d.audit_dependency_count_diagnosis.runner_source_change_required = $true } },
    @{ name = "physics"; apply = { param($d) $d.interpretation.physics_failure = $true } },
    @{ name = "same_source"; apply = { param($d) $d.interpretation.same_source_rerun_authorized = $true } },
    @{ name = "claim"; apply = { param($d) $d.claims.turning_acceptance = $true } }
)
$mutationRefusals = 0
foreach ($mutation in $mutations) {
    $changed = Copy-Lca1Rc6IncidentDocument $incident
    & $mutation.apply $changed
    $result = Test-Lca1Rc6IncidentDocument -Document $changed
    Assert-Lca1Rc6Incident (-not [bool]$result.ok) (
        "mutation was accepted: $($mutation.name)"
    )
    $mutationRefusals += 1
}

$casVerifiedCount = 0
foreach ($artifact in @(
    $incident.cold_full_v2.run_receipt,
    $incident.cold_full_v2.failed_stage_receipt,
    $incident.cold_full_v2.full_log,
    $incident.cold_full_v2.failure_excerpt
)) {
    $path = [string]$artifact.path
    Assert-Lca1Rc6Incident (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Lca1Rc6IncidentSha256 $path) -ceq [string]$artifact.raw_sha256 -and
        (Get-Item -LiteralPath $path).Length -eq [long]$artifact.byte_length -and
        [bool]$artifact.cas_required -and [bool]$artifact.cas_verified
    ) "retained artifact changed: $path"
    $digest = ([string]$artifact.raw_sha256).Substring(7)
    $casDirectory = Join-Path (
        Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
    ) "artifacts\sha256\$digest"
    Assert-Lca1Rc6Incident (
        Test-SporeSporeStoredArtifact `
            -Directory $casDirectory `
            -ExpectedSha256 $digest `
            -ExpectedByteLength ([long]$artifact.byte_length)
    ) "retained CAS object changed: $digest"
    $casVerifiedCount += 1
}

$receipt = Read-Lca1Rc6IncidentJson (
    [string]$incident.cold_full_v2.run_receipt.path
)
$stage = Read-Lca1Rc6IncidentJson (
    [string]$incident.cold_full_v2.failed_stage_receipt.path
)
Assert-Lca1Rc6Incident (
    [string]$receipt.status -ceq "failed" -and
    [string]$receipt.tier -ceq "full_cold" -and
    -not [bool]$receipt.skip_godot -and -not [bool]$receipt.test_only -and
    [string]$receipt.source.head -ceq
        [string]$incident.observed_source_identity.commit -and
    [string]$receipt.source.head_tree -ceq
        [string]$incident.observed_source_identity.tree_git_oid -and
    [string]$receipt.source.origin_main -ceq
        [string]$incident.observed_source_identity.commit -and
    [bool]$receipt.source.worktree_clean -and
    [string]$receipt.cache.status -ceq "disabled_uncommissioned" -and
    -not [bool]$receipt.cache.lookup_performed -and
    -not [bool]$receipt.cache.result_reused -and
    [string]$receipt.input_identity.dependency_key_candidate.status -ceq
        "candidate_construction_failed" -and
    [string]$receipt.failure.message -ceq
        [string]$incident.cold_full_v2.canonical_failure_message -and
    @($receipt.stage_receipts).Count -eq 1 -and
    @($receipt.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "retained run receipt changed"
Assert-Lca1Rc6Incident (
    [string]$stage.status -ceq "failed" -and
    [string]$stage.stage_id -ceq "authority_and_historical_closures" -and
    [int]$stage.ordinal -eq 1 -and [int]$stage.exit_code -eq 1 -and
    [string]$stage.error.message -ceq
        [string]$incident.cold_full_v2.canonical_failure_message -and
    @($stage.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "retained failed-stage receipt changed"

$toolchain = $incident.toolchain_runtime_identity
Assert-Lca1Rc6Incident (
    [string]$receipt.toolchain_runtime_identity_sha256 -ceq
        [string]$toolchain.identity_sha256 -and
    [string]$receipt.toolchain_runtime_identity.powershell.executable_sha256 -ceq
        [string]$toolchain.powershell_executable_raw_sha256 -and
    [string]$receipt.toolchain_runtime_identity.powershell.version -ceq
        [string]$toolchain.powershell_version -and
    [string]$receipt.toolchain_runtime_identity.python.executable_sha256 -ceq
        [string]$toolchain.python_executable_raw_sha256 -and
    [string]$receipt.toolchain_runtime_identity.godot.executable_sha256 -ceq
        [string]$toolchain.godot_executable_raw_sha256 -and
    [string]$receipt.toolchain_runtime_identity.godot.version -ceq
        [string]$toolchain.godot_version
) "retained RC6 toolchain identity changed"

Assert-Lca1Rc6Incident (
    (Test-Path -LiteralPath ([string]$incident.launch.pair_root) -PathType Container) -and
    @(Get-ChildItem -LiteralPath ([string]$incident.launch.pair_root) -Force).Count -eq 0 -and
    -not (Test-Path -LiteralPath ([string]$incident.launch.full_attestation_path)) -and
    -not (Test-Path -LiteralPath ([string]$incident.launch.scoped_output_root))
) "RC6 create-only pair-root boundary changed"

$commit = [string]$incident.observed_source_identity.commit
$tree = (& git -C $repoRoot rev-parse "$commit^{tree}").Trim()
Assert-Lca1Rc6Incident (
    $LASTEXITCODE -eq 0 -and
    $tree -ceq [string]$incident.observed_source_identity.tree_git_oid
) "RC6 source tree object changed"

foreach ($binding in @(
    [ordered]@{ path = $incident.preregistration.freeze_path; oid = $incident.preregistration.freeze_git_blob_oid; bytes = $incident.preregistration.freeze_byte_length },
    [ordered]@{ path = $incident.preregistration.manifest_path; oid = $incident.preregistration.manifest_git_blob_oid; bytes = $incident.preregistration.manifest_byte_length },
    [ordered]@{ path = $incident.preregistration.freeze_audit_path; oid = $incident.preregistration.freeze_audit_git_blob_oid; bytes = $incident.preregistration.freeze_audit_byte_length },
    [ordered]@{ path = $incident.audit_dependency_count_diagnosis.observed_inventory_path; oid = $incident.audit_dependency_count_diagnosis.observed_inventory_git_blob_oid; bytes = $incident.audit_dependency_count_diagnosis.observed_inventory_byte_length },
    [ordered]@{ path = $incident.audit_dependency_count_diagnosis.contract.path; oid = $incident.audit_dependency_count_diagnosis.contract.git_blob_oid; bytes = $incident.audit_dependency_count_diagnosis.contract.byte_length },
    [ordered]@{ path = $incident.audit_dependency_count_diagnosis.registry.path; oid = $incident.audit_dependency_count_diagnosis.registry.git_blob_oid; bytes = $incident.audit_dependency_count_diagnosis.registry.byte_length },
    [ordered]@{ path = $incident.audit_dependency_count_diagnosis.candidate_evaluator.path; oid = $incident.audit_dependency_count_diagnosis.candidate_evaluator.git_blob_oid; bytes = $incident.audit_dependency_count_diagnosis.candidate_evaluator.byte_length },
    [ordered]@{ path = $incident.audit_dependency_count_diagnosis.candidate_test.path; oid = $incident.audit_dependency_count_diagnosis.candidate_test.git_blob_oid; bytes = $incident.audit_dependency_count_diagnosis.candidate_test.byte_length }
)) {
    $blob = Get-Lca1Rc6IncidentSourceBlob -Commit $commit -Path ([string]$binding.path)
    Assert-Lca1Rc6Incident (
        [string]$blob.oid -ceq [string]$binding.oid -and
        [long]$blob.byte_length -eq [long]$binding.bytes
    ) "RC6 source-bound object changed: $($binding.path)"
}

$diagnosis = $incident.audit_dependency_count_diagnosis
$sourceInventory = Read-Lca1Rc6IncidentSourceJson -Commit $commit `
    -Path ([string]$diagnosis.observed_inventory_path)
$sourceContract = Read-Lca1Rc6IncidentSourceJson -Commit $commit `
    -Path ([string]$diagnosis.contract.path)
$sourceRegistry = Read-Lca1Rc6IncidentSourceJson -Commit $commit `
    -Path ([string]$diagnosis.registry.path)
$baselineCommit = [string]$diagnosis.last_reconciled_inventory_source_commit
$baselineInventory = Read-Lca1Rc6IncidentSourceJson -Commit $baselineCommit `
    -Path ([string]$diagnosis.observed_inventory_path)
$baselineBlob = Get-Lca1Rc6IncidentSourceBlob -Commit $baselineCommit `
    -Path ([string]$diagnosis.observed_inventory_path)
Assert-Lca1Rc6Incident (
    [string]$sourceInventory.schema_version -ceq
        [string]$diagnosis.observed_inventory_schema_version -and
    [int]$sourceInventory.audit_count -eq [int]$diagnosis.observed_cep1_audit_count -and
    @($sourceInventory.entries).Count -eq [int]$diagnosis.observed_cep1_audit_count -and
    [int]$baselineInventory.audit_count -eq
        [int]$diagnosis.last_reconciled_cep1_audit_count -and
    [string]$baselineBlob.oid -ceq
        [string]$diagnosis.last_reconciled_inventory_git_blob_oid -and
    [int]$sourceContract.authority.cep1_audit_count -eq
        [int]$diagnosis.contract.declared_cep1_audit_count -and
    [int]$sourceContract.authority.unregistered_audit_count -eq
        [int]$diagnosis.contract.declared_unregistered_audit_count -and
    [int]$sourceRegistry.cep1_audit_count -eq
        [int]$diagnosis.registry.declared_cep1_audit_count -and
    [int]$sourceRegistry.unregistered_audit_count -eq
        [int]$diagnosis.registry.declared_unregistered_audit_count -and
    @($sourceRegistry.entries).Count -eq
        [int]$diagnosis.registry.registered_audit_count -and
    [int]$sourceRegistry.complete_audit_count -eq
        [int]$diagnosis.registry.complete_audit_count
) "RC6 historical count diagnosis changed"

$basePaths = @($baselineInventory.entries.path)
$sourcePaths = @($sourceInventory.entries.path)
$addedPaths = @(
    Compare-Object $basePaths $sourcePaths |
        Where-Object { $_.SideIndicator -ceq "=>" } |
        ForEach-Object { [string]$_.InputObject }
)
$removedPaths = @(
    Compare-Object $basePaths $sourcePaths |
        Where-Object { $_.SideIndicator -ceq "<=" } |
        ForEach-Object { [string]$_.InputObject }
)
$declaredAddedPaths = @($diagnosis.added_audit_entries.path)
Assert-Lca1Rc6Incident (
    $addedPaths.Count -eq 2 -and $removedPaths.Count -eq 0 -and
    @(Compare-Object ($addedPaths | Sort-Object) ($declaredAddedPaths | Sort-Object)).Count -eq 0
) "RC6 inventory set-difference diagnosis changed"
foreach ($declared in @($diagnosis.added_audit_entries)) {
    $matched = @($sourceInventory.entries | Where-Object {
        [string]$_.path -ceq [string]$declared.path
    })
    Assert-Lca1Rc6Incident (
        $matched.Count -eq 1 -and
        [string]$matched[0].raw_sha256 -ceq [string]$declared.raw_sha256 -and
        [string]$matched[0].historical_identity_mode -ceq
            [string]$declared.historical_identity_mode -and
        [bool]$matched[0].manual_review_required -eq
            [bool]$declared.manual_review_required
    ) "RC6 added inventory entry changed: $($declared.path)"
}

foreach ($path in @(
    [string]$diagnosis.contract.path,
    [string]$diagnosis.registry.path,
    [string]$diagnosis.candidate_evaluator.path,
    [string]$diagnosis.candidate_test.path
)) {
    $baseObject = Get-Lca1Rc6IncidentSourceBlob -Commit $baselineCommit -Path $path
    $observedObject = Get-Lca1Rc6IncidentSourceBlob -Commit $commit -Path $path
    Assert-Lca1Rc6Incident (
        [string]$baseObject.oid -ceq [string]$observedObject.oid
    ) "RC6 stale-count source changed from baseline: $path"
}

$failureText = Get-Content -Raw -LiteralPath (
    [string]$incident.cold_full_v2.failure_excerpt.path
)
Assert-Lca1Rc6Incident (
    $failureText.Contains([string]$incident.cold_full_v2.canonical_failure_message)
) "RC6 failure excerpt lost the canonical error"

Write-Host (
    "LCA1_RC6_INCIDENT_PASS class=equivalence_non_inferiority " +
    "full_stage_receipts=1 scoped_gates=0 cas=$casVerifiedCount " +
    "cep1_observed=150 cep1_declared=148 added_audits=2 " +
    "repair_literals=10 mutations=$mutationRefusals models=0 worlds=0 " +
    "physical_authority=False release_authority=False"
)

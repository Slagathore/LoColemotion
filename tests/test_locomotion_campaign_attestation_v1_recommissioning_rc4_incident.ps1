#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$incidentPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc4_incident.json"
)

. (Join-Path $sdkRoot "content_addressed_artifact_store.ps1")

function Assert-Lca1Rc4Incident([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "LCA1_RC4_INCIDENT $Message" }
}

function Read-Lca1Rc4IncidentJson([string]$Path) {
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-Lca1Rc4IncidentSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Copy-Lca1Rc4Incident([object]$Value) {
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-Lca1Rc4SourceBlob(
    [Parameter(Mandatory)][string]$Commit,
    [Parameter(Mandatory)][string]$Path
) {
    $oid = (& git -C $repoRoot rev-parse "$Commit`:$Path").Trim()
    Assert-Lca1Rc4Incident ($LASTEXITCODE -eq 0) "missing source blob: $Path"
    $type = (& git -C $repoRoot cat-file -t $oid).Trim()
    $bytes = [long]((& git -C $repoRoot cat-file -s $oid).Trim())
    Assert-Lca1Rc4Incident (
        $LASTEXITCODE -eq 0 -and $type -ceq "blob"
    ) "invalid source object: $Path"
    return [ordered]@{ oid = $oid; byte_length = $bytes }
}

function Test-Lca1Rc4IncidentDocument(
    [Parameter(Mandatory)][System.Collections.IDictionary]$Document
) {
    $failures = [Collections.Generic.List[string]]::new()
    if ([string]$Document.schema_version -cne
        "sporespore_locomotion_campaign_attestation_commissioning_incident_v1" -or
        [string]$Document.incident_id -cne "LCA1-RC4-COLD-PAIR-20260815" -or
        [string]$Document.status -cne
            "closed_negative_full_stage_1_workbench_proof_digest_mismatch_scoped_not_started") {
        $failures.Add("IDENTITY")
    }
    if ([string]$Document.question_class -cne "equivalence_non_inferiority" -or
        [bool]$Document.physical_question) {
        $failures.Add("QUESTION")
    }
    if ([string]$Document.observed_source_identity.commit -cne
            "78aee8886209102f5cb9d5c167886c739cbe0ff7" -or
        [string]$Document.observed_source_identity.tree_git_oid -cne
            "5003f1409582a3b095d2b713a76d5e8a54fc4ee2" -or
        [string]$Document.observed_source_identity.remote_url -cne
            "https://github.com/Slagathore/sporespore.git" -or
        -not [bool]$Document.observed_source_identity.worktree_clean) {
        $failures.Add("SOURCE")
    }
    if ([string]$Document.preregistration.program_id -cne
            "LCA1-RC4-SCHEMA-ALIGNED-CLAIM-VECTOR-RECOMMISSIONING" -or
        [int]$Document.preregistration.pair_count -ne 1 -or
        [bool]$Document.preregistration.
            same_source_rerun_after_complete_or_failed_pair_allowed -or
        [bool]$Document.preregistration.prior_result_reuse_allowed -or
        [int]$Document.preregistration.physical_world_count -ne 0) {
        $failures.Add("PREREGISTRATION")
    }
    if ([bool]$Document.launch.full_attestation_created -or
        [bool]$Document.launch.scoped_output_root_created -or
        [bool]$Document.launch.scoped_attempted -or
        [int]$Document.launch.pair_root_entry_count_after_failure -ne 0) {
        $failures.Add("LAUNCH")
    }
    $full = $Document.cold_full_v2
    if ([string]$full.status -cne
            "failed_stage_1_workbench_proof_digest_mismatch" -or
        [double]$full.duration_seconds -ne 152.6247014 -or
        [int]$full.required_stage_count -ne 8 -or
        [int]$full.stage_receipt_count -ne 1 -or
        [int]$full.failed_stage_count -ne 1 -or
        [string]$full.first_failed_stage_id -cne
            "authority_and_historical_closures" -or
        [int]$full.first_failed_stage_ordinal -ne 1 -or
        [int]$full.first_failed_stage_exit_code -ne 1 -or
        [string]$full.canonical_failure_message -cne
            "Locomotion experiment workbench audit failed with exit code 1" -or
        [string]$full.nested_workbench_error_observed_by_launching_process -cne
            "LOCOMOTION_EXPERIMENT_WORKBENCH proof digest mismatch: sdk/release/quadruped_release_contract.json" -or
        [string]$full.cache_status -cne "disabled_uncommissioned" -or
        [bool]$full.cache_lookup_performed -or [bool]$full.result_reused -or
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
    $diagnosis = $Document.workbench_proof_binding_diagnosis
    if ([string]$diagnosis.classification -cne
            "post_failure_deterministic_source_binding_diagnosis" -or
        [string]$diagnosis.observed_first_failed_proof_path -cne
            "sdk/release/quadruped_release_contract.json" -or
        [int]$diagnosis.release_contract.catalog_reference_count -ne 4 -or
        [string]$diagnosis.release_contract.catalog_unique_expected_sha256 -ceq
            [string]$diagnosis.release_contract.observed_source_raw_sha256 -or
        -not [bool]$diagnosis.release_contract.live_gate_reached_this_mismatch -or
        [int]$diagnosis.support_matrix.catalog_reference_count -ne 4 -or
        [string]$diagnosis.support_matrix.catalog_unique_expected_sha256 -ceq
            [string]$diagnosis.support_matrix.observed_source_raw_sha256 -or
        [bool]$diagnosis.support_matrix.live_gate_reached_this_mismatch -or
        -not [bool]$diagnosis.support_matrix.
            mismatch_established_only_by_post_failure_static_diagnosis -or
        [int]$diagnosis.catalog_expected_sha256_field_repair_count -ne 8 -or
        [bool]$diagnosis.workbench_audit_source_change_required -or
        [bool]$diagnosis.executor_runner_source_change_required -or
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
            "full_runner_dependency_workbench_catalog_pinned_stale_release_ledgers" -or
        [bool]$interpretation.same_source_rerun_authorized -or
        [bool]$interpretation.observed_result_or_interpretation_rewrite_authorized -or
        [bool]$interpretation.threshold_change_authorized -or
        [bool]$interpretation.controller_change_authorized -or
        [bool]$interpretation.physics_change_authorized -or
        [bool]$interpretation.physical_rerun_authorized_by_incident) {
        $failures.Add("INTERPRETATION")
    }
    $claims = $Document.claims
    if (-not [bool]$claims.rc4_full_half_attempted -or
        [bool]$claims.rc4_pair_completed -or
        [bool]$claims.rc4_commissioning_passed -or
        [bool]$claims.current_executor_commissioned -or
        [bool]$claims.physical_launch_prerequisite_satisfied -or
        [bool]$claims.physical_campaign_executed -or
        [bool]$claims.scientific_result -or [bool]$claims.walking_acceptance -or
        [bool]$claims.turning_acceptance -or
        [bool]$claims.cross_engine_equivalence -or
        [bool]$claims.arbitrary_quadruped_coverage -or
        [bool]$claims.release_authority -or
        [bool]$claims.physical_acceptance_authority -or
        @($claims.Values | Where-Object { [bool]$_ }).Count -ne 1) {
        $failures.Add("CLAIMS")
    }
    return [ordered]@{
        ok = $failures.Count -eq 0
        failure_codes = @($failures | Sort-Object -Unique)
    }
}

Assert-Lca1Rc4Incident (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$incident = Read-Lca1Rc4IncidentJson $incidentPath
$documentTest = Test-Lca1Rc4IncidentDocument -Document $incident
Assert-Lca1Rc4Incident ([bool]$documentTest.ok) (
    "incident document changed: $(@($documentTest.failure_codes) -join ',')"
)

$mutations = @(
    @{ name = "status"; apply = { param($d) $d.status = "passed" } },
    @{ name = "question"; apply = { param($d) $d.question_class = "development" } },
    @{ name = "source"; apply = { param($d) $d.observed_source_identity.commit = "0" * 40 } },
    @{ name = "rerun"; apply = { param($d) $d.preregistration.same_source_rerun_after_complete_or_failed_pair_allowed = $true } },
    @{ name = "full_status"; apply = { param($d) $d.cold_full_v2.status = "passed" } },
    @{ name = "stage_count"; apply = { param($d) $d.cold_full_v2.stage_receipt_count = 8 } },
    @{ name = "scoped_attempt"; apply = { param($d) $d.cold_scoped_lca1.attempted = $true } },
    @{ name = "release_expected"; apply = { param($d) $d.workbench_proof_binding_diagnosis.release_contract.catalog_unique_expected_sha256 = $d.workbench_proof_binding_diagnosis.release_contract.observed_source_raw_sha256 } },
    @{ name = "release_count"; apply = { param($d) $d.workbench_proof_binding_diagnosis.release_contract.catalog_reference_count = 3 } },
    @{ name = "support_observed"; apply = { param($d) $d.workbench_proof_binding_diagnosis.support_matrix.live_gate_reached_this_mismatch = $true } },
    @{ name = "repair_count"; apply = { param($d) $d.workbench_proof_binding_diagnosis.catalog_expected_sha256_field_repair_count = 7 } },
    @{ name = "runner_change"; apply = { param($d) $d.workbench_proof_binding_diagnosis.executor_runner_source_change_required = $true } },
    @{ name = "physics_failure"; apply = { param($d) $d.interpretation.physics_failure = $true } },
    @{ name = "commissioned"; apply = { param($d) $d.claims.current_executor_commissioned = $true } },
    @{ name = "authority"; apply = { param($d) $d.claims.physical_acceptance_authority = $true } }
)
$mutationRefusals = 0
foreach ($mutation in $mutations) {
    $copy = Copy-Lca1Rc4Incident $incident
    & $mutation.apply $copy
    $result = Test-Lca1Rc4IncidentDocument -Document $copy
    Assert-Lca1Rc4Incident (-not [bool]$result.ok) (
        "incident mutation was accepted: $($mutation.name)"
    )
    $mutationRefusals++
}

foreach ($bindingName in @("freeze", "manifest", "freeze_audit")) {
    $pathKey = $bindingName + "_path"
    $hashKey = $bindingName + "_raw_sha256"
    $bytesKey = $bindingName + "_byte_length"
    $absolute = Join-Path $repoRoot ([string]$incident.preregistration[$pathKey])
    Assert-Lca1Rc4Incident (
        (Test-Path -LiteralPath $absolute -PathType Leaf) -and
        (Get-Lca1Rc4IncidentSha256 $absolute) -ceq
            [string]$incident.preregistration[$hashKey] -and
        (Get-Item -LiteralPath $absolute).Length -eq
            [long]$incident.preregistration[$bytesKey]
    ) "RC4 preregistration binding changed: $bindingName"
}

$evidenceRecords = @(
    $incident.cold_full_v2.run_receipt,
    $incident.cold_full_v2.failed_stage_receipt,
    $incident.cold_full_v2.full_log,
    $incident.cold_full_v2.failure_excerpt
)
$casVerifiedCount = 0
foreach ($record in $evidenceRecords) {
    $path = [string]$record.path
    $digest = ([string]$record.raw_sha256).Substring(7)
    $casDirectory = Join-Path (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\artifacts\sha256"
    ) $digest
    Assert-Lca1Rc4Incident (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Lca1Rc4IncidentSha256 $path) -ceq [string]$record.raw_sha256 -and
        (Get-Item -LiteralPath $path).Length -eq [long]$record.byte_length -and
        [bool]$record.cas_required -and [bool]$record.cas_verified -and
        (Test-SporeSporeStoredArtifact `
            -Directory $casDirectory `
            -ExpectedSha256 $digest `
            -ExpectedByteLength ([long]$record.byte_length))
    ) "retained RC4 artifact or CAS changed: $path"
    $casVerifiedCount++
}

$receipt = Read-Lca1Rc4IncidentJson ([string]$incident.cold_full_v2.run_receipt.path)
$stage = Read-Lca1Rc4IncidentJson (
    [string]$incident.cold_full_v2.failed_stage_receipt.path
)
Assert-Lca1Rc4Incident (
    [string]$receipt.schema_version -ceq
        "sporespore_conformance_run_observation_v1" -and
    [string]$receipt.run_id -ceq [string]$incident.cold_full_v2.run_id -and
    [string]$receipt.status -ceq "failed" -and
    [string]$receipt.tier -ceq "full_cold" -and
    -not [bool]$receipt.skip_godot -and -not [bool]$receipt.test_only -and
    [string]$receipt.source.head -ceq
        [string]$incident.observed_source_identity.commit -and
    [string]$receipt.source.head_tree -ceq
        [string]$incident.observed_source_identity.tree_git_oid -and
    [string]$receipt.source.origin_main -ceq
        [string]$incident.observed_source_identity.origin_main -and
    [bool]$receipt.source.worktree_clean -and
    @($receipt.stage_receipts).Count -eq 1 -and
    [string]$receipt.stage_receipts[0].stage_id -ceq
        "authority_and_historical_closures" -and
    [string]$receipt.stage_receipts[0].status -ceq "failed" -and
    [string]$receipt.failure.message -ceq
        [string]$incident.cold_full_v2.canonical_failure_message -and
    [string]$receipt.cache.status -ceq "disabled_uncommissioned" -and
    -not [bool]$receipt.cache.lookup_performed -and
    -not [bool]$receipt.cache.result_reused -and
    @($receipt.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "retained RC4 run receipt semantics changed"
Assert-Lca1Rc4Incident (
    [string]$stage.status -ceq "failed" -and
    [int]$stage.ordinal -eq 1 -and [int]$stage.exit_code -eq 1 -and
    [string]$stage.error.message -ceq
        [string]$incident.cold_full_v2.canonical_failure_message -and
    [string]$stage.cache.status -ceq "disabled_uncommissioned" -and
    -not [bool]$stage.cache.result_reused -and
    @($stage.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "retained RC4 failed stage semantics changed"

$toolchain = $incident.toolchain_runtime_identity
Assert-Lca1Rc4Incident (
    [string]$receipt.toolchain_runtime_identity_sha256 -ceq
        [string]$toolchain.identity_sha256 -and
    [string]$receipt.toolchain_runtime_identity.powershell.executable_sha256 -ceq
        [string]$toolchain.powershell_executable_raw_sha256 -and
    [string]$receipt.toolchain_runtime_identity.powershell.version -ceq
        [string]$toolchain.powershell_version -and
    [string]$receipt.toolchain_runtime_identity.python.executable_sha256 -ceq
        [string]$toolchain.python_executable_raw_sha256 -and
    [string]$receipt.toolchain_runtime_identity.godot.executable_sha256 -ceq
        [string]$toolchain.godot_executable_raw_sha256
) "retained RC4 toolchain identity changed"

$pairRoot = [string]$incident.launch.pair_root
Assert-Lca1Rc4Incident (
    (Test-Path -LiteralPath $pairRoot -PathType Container) -and
    @(Get-ChildItem -LiteralPath $pairRoot -Force).Count -eq 0 -and
    -not (Test-Path -LiteralPath ([string]$incident.launch.full_attestation_path)) -and
    -not (Test-Path -LiteralPath ([string]$incident.launch.scoped_output_root))
) "RC4 create-only pair-root boundary changed"

$commit = [string]$incident.observed_source_identity.commit
$tree = (& git -C $repoRoot rev-parse "$commit^{tree}").Trim()
Assert-Lca1Rc4Incident (
    $LASTEXITCODE -eq 0 -and
    $tree -ceq [string]$incident.observed_source_identity.tree_git_oid
) "RC4 source tree object changed"

$diagnosis = $incident.workbench_proof_binding_diagnosis
$runnerBlob = Get-Lca1Rc4SourceBlob -Commit $commit `
    -Path ([string]$diagnosis.executor_runner_path)
$catalogBlob = Get-Lca1Rc4SourceBlob -Commit $commit `
    -Path ([string]$diagnosis.catalog_path)
$auditBlob = Get-Lca1Rc4SourceBlob -Commit $commit `
    -Path ([string]$diagnosis.workbench_audit_path)
$releaseBlob = Get-Lca1Rc4SourceBlob -Commit $commit `
    -Path ([string]$diagnosis.release_contract.path)
$supportBlob = Get-Lca1Rc4SourceBlob -Commit $commit `
    -Path ([string]$diagnosis.support_matrix.path)
Assert-Lca1Rc4Incident (
    [string]$runnerBlob.oid -ceq [string]$diagnosis.executor_runner_git_blob_oid -and
    [long]$runnerBlob.byte_length -eq [long]$diagnosis.executor_runner_byte_length -and
    [string]$catalogBlob.oid -ceq
        [string]$diagnosis.catalog_git_blob_oid_at_observed_source -and
    [long]$catalogBlob.byte_length -eq
        [long]$diagnosis.catalog_byte_length_at_observed_source -and
    [string]$auditBlob.oid -ceq
        [string]$diagnosis.workbench_audit_git_blob_oid_at_observed_source -and
    [long]$auditBlob.byte_length -eq
        [long]$diagnosis.workbench_audit_byte_length_at_observed_source -and
    [string]$releaseBlob.oid -ceq
        [string]$diagnosis.release_contract.observed_source_git_blob_oid -and
    [long]$releaseBlob.byte_length -eq
        [long]$diagnosis.release_contract.observed_source_byte_length -and
    [string]$supportBlob.oid -ceq
        [string]$diagnosis.support_matrix.observed_source_git_blob_oid -and
    [long]$supportBlob.byte_length -eq
        [long]$diagnosis.support_matrix.observed_source_byte_length
) "RC4 source-bound diagnosis objects changed"

$catalogText = @(& git -C $repoRoot show "$commit`:$($diagnosis.catalog_path)") -join "`n"
Assert-Lca1Rc4Incident ($LASTEXITCODE -eq 0) "cannot read RC4 source catalog"
$sourceCatalog = $catalogText | ConvertFrom-Json -AsHashtable -Depth 100
$releaseReferences = [Collections.Generic.List[object]]::new()
$supportReferences = [Collections.Generic.List[object]]::new()
foreach ($run in @($sourceCatalog.runs)) {
    foreach ($proof in @($run.proofs)) {
        if ([string]$proof.path -ceq [string]$diagnosis.release_contract.path) {
            $releaseReferences.Add($proof)
        }
        if ([string]$proof.path -ceq [string]$diagnosis.support_matrix.path) {
            $supportReferences.Add($proof)
        }
    }
}
Assert-Lca1Rc4Incident (
    $releaseReferences.Count -eq 4 -and
    @($releaseReferences.expected_sha256 | Sort-Object -Unique).Count -eq 1 -and
    ("sha256:" + [string]$releaseReferences[0].expected_sha256) -ceq
        [string]$diagnosis.release_contract.catalog_unique_expected_sha256 -and
    $supportReferences.Count -eq 4 -and
    @($supportReferences.expected_sha256 | Sort-Object -Unique).Count -eq 1 -and
    ("sha256:" + [string]$supportReferences[0].expected_sha256) -ceq
        [string]$diagnosis.support_matrix.catalog_unique_expected_sha256
) "RC4 source catalog diagnosis changed"

Write-Host (
    "LCA1_RC4_INCIDENT_PASS class=equivalence_non_inferiority " +
    "full_stage_receipts=1 scoped_gates=0 cas=$casVerifiedCount " +
    "release_proof_refs=$($releaseReferences.Count) " +
    "support_proof_refs=$($supportReferences.Count) repair_fields=8 " +
    "mutations=$mutationRefusals models=0 worlds=0 " +
    "physical_authority=False release_authority=False"
)

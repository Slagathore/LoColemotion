#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$incidentPath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc8_incident.json"
)

. (Join-Path $sdkRoot "content_addressed_artifact_store.ps1")

function Assert-Lca1Rc8Incident([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "LCA1_RC8_INCIDENT $Message" }
}

function Read-Lca1Rc8IncidentJson([string]$Path) {
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-Lca1Rc8IncidentSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Copy-Lca1Rc8IncidentDocument([object]$Value) {
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-Lca1Rc8IncidentSourceBlob(
    [Parameter(Mandatory)][string]$Commit,
    [Parameter(Mandatory)][string]$Path
) {
    $oid = (& git -C $repoRoot rev-parse "$Commit`:$Path").Trim()
    Assert-Lca1Rc8Incident ($LASTEXITCODE -eq 0) "missing source blob: $Path"
    $type = (& git -C $repoRoot cat-file -t $oid).Trim()
    $bytes = [long]((& git -C $repoRoot cat-file -s $oid).Trim())
    Assert-Lca1Rc8Incident (
        $LASTEXITCODE -eq 0 -and $type -ceq "blob"
    ) "invalid source object: $Path"
    return [ordered]@{ oid = $oid; byte_length = $bytes }
}

function Read-Lca1Rc8IncidentSourceJson(
    [Parameter(Mandatory)][string]$Commit,
    [Parameter(Mandatory)][string]$Path
) {
    $text = @(& git -C $repoRoot show "$Commit`:$Path") -join "`n"
    Assert-Lca1Rc8Incident ($LASTEXITCODE -eq 0) (
        "cannot read source JSON: $Commit`:$Path"
    )
    return $text | ConvertFrom-Json -AsHashtable -Depth 100
}

function Read-Lca1Rc8IncidentSourceText(
    [Parameter(Mandatory)][string]$Commit,
    [Parameter(Mandatory)][string]$Path
) {
    $text = @(& git -C $repoRoot show "$Commit`:$Path") -join "`n"
    Assert-Lca1Rc8Incident ($LASTEXITCODE -eq 0) (
        "cannot read source text: $Commit`:$Path"
    )
    return $text
}

function Find-Lca1Rc8IncidentRecordByGate(
    [object]$Value,
    [string]$GateId
) {
    if ($null -eq $Value) { return $null }
    if ($Value -is [System.Collections.IDictionary]) {
        if ($Value.Contains("gate_id") -and
            [string]$Value.gate_id -ceq $GateId) {
            return $Value
        }
        foreach ($key in @($Value.Keys)) {
            $found = Find-Lca1Rc8IncidentRecordByGate $Value[$key] $GateId
            if ($null -ne $found) { return $found }
        }
    } elseif ($Value -is [System.Collections.IEnumerable] -and
        -not ($Value -is [string])) {
        foreach ($item in @($Value)) {
            $found = Find-Lca1Rc8IncidentRecordByGate $item $GateId
            if ($null -ne $found) { return $found }
        }
    }
    return $null
}

function Test-Lca1Rc8IncidentDocument(
    [Parameter(Mandatory)][System.Collections.IDictionary]$Document
) {
    $failures = [Collections.Generic.List[string]]::new()
    if ([string]$Document.schema_version -cne
            "sporespore_locomotion_campaign_attestation_commissioning_incident_v1" -or
        [string]$Document.incident_id -cne "LCA1-RC8-COLD-PAIR-20260824" -or
        [string]$Document.status -cne
            "closed_negative_full_stage_4_r23d62_preregistration_live_authority_expectation_mismatch_scoped_not_started") {
        $failures.Add("IDENTITY")
    }
    if ([string]$Document.question_class -cne "equivalence_non_inferiority" -or
        [bool]$Document.physical_question) {
        $failures.Add("QUESTION")
    }
    $source = $Document.observed_source_identity
    if ([string]$source.commit -cne
            "f01d87b116cde05498126bf1f325f08e07d8d66a" -or
        [string]$source.tree_git_oid -cne
            "2f0d49d95623e364aed077b89ea29aee96e015b5" -or
        [string]$source.origin_main -cne [string]$source.commit -or
        [string]$source.live_github_main -cne [string]$source.commit -or
        [string]$source.remote_url -cne
            "https://github.com/Slagathore/sporespore.git" -or
        [string]$source.branch -cne "main" -or
        -not [bool]$source.worktree_clean) {
        $failures.Add("SOURCE")
    }
    $pre = $Document.preregistration
    if ([string]$pre.freeze_raw_sha256 -cne
            "sha256:a0d89051e825a9c4b970bf87620808a4fb1add8dc67e96b3cca15c81a941cad8" -or
        [string]$pre.freeze_git_blob_oid -cne
            "195aed240b20e9dce3cc98deebbac2fa03385613" -or
        [long]$pre.freeze_byte_length -ne 22671 -or
        [string]$pre.manifest_raw_sha256 -cne
            "sha256:2a4bf468da923d1d927e7a1dd162bc48abe1d810d9bad97a34ee00fc07101bfd" -or
        [string]$pre.manifest_git_blob_oid -cne
            "d0a9b07d26724d03aa6ee94f3b0d7237b1380236" -or
        [long]$pre.manifest_byte_length -ne 13912 -or
        [string]$pre.freeze_audit_raw_sha256 -cne
            "sha256:f01fe9379d432ef7ea642f89e13a57dd6ac7b5db592eacd75dfd9f3ff4a8b63f" -or
        [string]$pre.freeze_audit_git_blob_oid -cne
            "a0e4c6636817e7b91092934f8ca51f6f84c9dd7d" -or
        [long]$pre.freeze_audit_byte_length -ne 30078 -or
        [string]$pre.program_id -cne
            "LCA1-RC8-CANONICAL-RUNNER-EXTENSION-RECOMMISSIONING" -or
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
            "failed_stage_4_r23d62_preregistration_live_authority_expectation_mismatch" -or
        [string]$full.run_id -cne
            "20260824T215814Z-f01d87b1-f1cb7b9c01324d4d9b25200dca573bcb" -or
        [int]$full.required_stage_count -ne 8 -or
        [int]$full.stage_receipt_count -ne 4 -or
        [int]$full.passed_stage_count -ne 3 -or
        [int]$full.failed_stage_count -ne 1 -or
        [string]$full.first_failed_stage_id -cne
            "campaign_closures_and_zero_world_gates" -or
        [int]$full.first_failed_stage_ordinal -ne 4 -or
        [int]$full.first_failed_stage_exit_code -ne 1 -or
        [string]$full.canonical_failure_message -cne
            "R23D62 preregistration audit failed with exit code 1" -or
        [string]$full.inner_audit_failure_message -cne
            "QSDK-R23D62 preregistration audit failed: release contract or support-matrix declaration record changed" -or
        [string]$full.cache_status -cne "disabled_uncommissioned" -or
        [bool]$full.cache_lookup_performed -or [bool]$full.result_reused -or
        [string]$full.observed_input_status -cne "observed_not_transitive" -or
        [string]$full.dependency_key_candidate_status -cne
            "candidate_incomplete_cache_disabled" -or
        [bool]$full.full_attestation_created -or
        [int]$full.physical_campaign_process_launch_count -ne 0 -or
        [int]$full.model_construction_count -ne 0 -or
        [int]$full.world_attempt_count -ne 0 -or
        [int]$full.world_build_count -ne 0) {
        $failures.Add("FULL")
    }
    if (@($full.stage_receipts).Count -ne 4 -or
        (@($full.stage_receipts.status) -join ",") -cne
            "passed,passed,passed,failed" -or
        (@($full.stage_receipts.ordinal) -join ",") -cne "1,2,3,4") {
        $failures.Add("STAGES")
    }
    $scoped = $Document.cold_scoped_lca1
    if ([string]$scoped.status -cne
            "not_started_after_full_stage_4_failure" -or
        [bool]$scoped.attempted -or [bool]$scoped.output_root_created -or
        [int]$scoped.gate_execution_count -ne 0 -or
        [int]$scoped.gate_cas_object_count -ne 0 -or
        [int]$scoped.physical_worlds_opened -ne 0) {
        $failures.Add("SCOPED")
    }
    $diagnosis = $Document.live_authority_expectation_diagnosis
    if ([string]$diagnosis.classification -cne
            "post_failure_pinned_source_authority_consumer_reconciliation" -or
        [string]$diagnosis.failing_audit.path -cne
            "tests/test_qsdk_r23d62_preregistration.ps1" -or
        [string]$diagnosis.failing_audit.raw_sha256 -cne
            "sha256:130c959154dc0cdca86697f4788ab3b4badb71c6afe727ab1d8465fbd99ccbe7" -or
        [string]$diagnosis.failing_audit.git_blob_oid -cne
            "9533ab61e5774f21e6755fd22a1b775a61d59f28" -or
        [int]$diagnosis.failing_audit.compound_assertion_start_line -ne 350 -or
        [int]$diagnosis.failing_audit.compound_assertion_end_line -ne 411 -or
        [string]$diagnosis.stale_expected_prospective_status -cne
            "r23d62_campaign_machinery_complete_zero_world_gate_passed_physical_not_opened" -or
        [string]$diagnosis.stale_expected_record_status -cne
            "prospective_campaign_machinery_implemented_complete_zero_world_gate_passed_physical_not_opened" -or
        [bool]$diagnosis.stale_expected_clean_pushed_qualification_retained -or
        [string]$diagnosis.observed_prospective_status -cne
            "r23d62_clean_pushed_qualification_passed_adoption_refused_rc8_recommissioning_prospective_physical_not_opened" -or
        [string]$diagnosis.observed_record_status -cne
            "clean_pushed_qualification_passed_adoption_refused_rc8_recommissioning_prospective_physical_not_opened" -or
        -not [bool]$diagnosis.observed_clean_pushed_qualification_retained -or
        [int]$diagnosis.observed_qualification_executed_gate_count -ne 22 -or
        [int]$diagnosis.observed_qualification_gate_cas_reference_count -ne 66 -or
        [int]$diagnosis.observed_qualification_unique_gate_cas_object_count -ne 46 -or
        [int]$diagnosis.observed_qualification_physical_world_count -ne 0 -or
        -not [bool]$diagnosis.observed_adoption_attempted -or
        [bool]$diagnosis.observed_campaign_attestation_adopted -or
        [int]$diagnosis.observed_commissioned_core_match_count -ne 9 -or
        [int]$diagnosis.observed_commissioned_core_mismatch_count -ne 1 -or
        [int]$diagnosis.mismatched_value_count -ne 5 -or
        -not [bool]$diagnosis.failing_audit_source_change_required -or
        [bool]$diagnosis.canonical_runner_source_change_required -or
        [bool]$diagnosis.campaign_declaration_change_required -or
        [bool]$diagnosis.campaign_evaluator_change_required -or
        [bool]$diagnosis.campaign_worker_or_supervisor_change_required -or
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
            "full_runner_r23d62_preregistration_audit_pinned_stale_live_release_support_state" -or
        [bool]$interpretation.same_source_rerun_authorized -or
        [bool]$interpretation.observed_result_or_interpretation_rewrite_authorized -or
        [bool]$interpretation.threshold_change_authorized -or
        [bool]$interpretation.controller_change_authorized -or
        [bool]$interpretation.physics_change_authorized -or
        [bool]$interpretation.physical_rerun_authorized_by_incident) {
        $failures.Add("INTERPRETATION")
    }
    $trueClaims = @($Document.claims.Keys | Where-Object {
        $_ -cne "rc8_full_half_attempted" -and [bool]$Document.claims[$_]
    })
    if (-not [bool]$Document.claims.rc8_full_half_attempted -or
        $trueClaims.Count -ne 0) {
        $failures.Add("CLAIMS")
    }
    return [ordered]@{
        ok = $failures.Count -eq 0
        failure_codes = @($failures | Sort-Object -Unique)
    }
}

Assert-Lca1Rc8Incident (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$incident = Read-Lca1Rc8IncidentJson $incidentPath
$documentTest = Test-Lca1Rc8IncidentDocument -Document $incident
Assert-Lca1Rc8Incident ([bool]$documentTest.ok) (
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
    @{ name = "passed_stages"; apply = { param($d) $d.cold_full_v2.passed_stage_count = 4 } },
    @{ name = "reuse"; apply = { param($d) $d.cold_full_v2.result_reused = $true } },
    @{ name = "scoped"; apply = { param($d) $d.cold_scoped_lca1.attempted = $true } },
    @{ name = "stale_status"; apply = { param($d) $d.live_authority_expectation_diagnosis.stale_expected_record_status = "forged" } },
    @{ name = "observed_status"; apply = { param($d) $d.live_authority_expectation_diagnosis.observed_record_status = "forged" } },
    @{ name = "qualification"; apply = { param($d) $d.live_authority_expectation_diagnosis.observed_clean_pushed_qualification_retained = $false } },
    @{ name = "adoption"; apply = { param($d) $d.live_authority_expectation_diagnosis.observed_campaign_attestation_adopted = $true } },
    @{ name = "mismatches"; apply = { param($d) $d.live_authority_expectation_diagnosis.mismatched_value_count = 4 } },
    @{ name = "runner"; apply = { param($d) $d.live_authority_expectation_diagnosis.canonical_runner_source_change_required = $true } },
    @{ name = "evaluator"; apply = { param($d) $d.live_authority_expectation_diagnosis.campaign_evaluator_change_required = $true } },
    @{ name = "physics"; apply = { param($d) $d.interpretation.physics_failure = $true } },
    @{ name = "same_source"; apply = { param($d) $d.interpretation.same_source_rerun_authorized = $true } },
    @{ name = "claim"; apply = { param($d) $d.claims.turning_acceptance = $true } }
)
$mutationRefusals = 0
foreach ($mutation in $mutations) {
    $changed = Copy-Lca1Rc8IncidentDocument $incident
    & $mutation.apply $changed
    $result = Test-Lca1Rc8IncidentDocument -Document $changed
    Assert-Lca1Rc8Incident (-not [bool]$result.ok) (
        "mutation was accepted: $($mutation.name)"
    )
    $mutationRefusals += 1
}

$retainedArtifacts = @(
    $incident.cold_full_v2.run_receipt
) + @($incident.cold_full_v2.stage_receipts) + @(
    $incident.cold_full_v2.full_log,
    $incident.cold_full_v2.failure_excerpt
)
$casVerifiedCount = 0
foreach ($artifact in $retainedArtifacts) {
    $path = [string]$artifact.path
    Assert-Lca1Rc8Incident (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Lca1Rc8IncidentSha256 $path) -ceq [string]$artifact.raw_sha256 -and
        (Get-Item -LiteralPath $path).Length -eq [long]$artifact.byte_length -and
        [bool]$artifact.cas_required -and [bool]$artifact.cas_verified
    ) "retained artifact changed: $path"
    $digest = ([string]$artifact.raw_sha256).Substring(7)
    $casDirectory = Join-Path (
        Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
    ) "artifacts\sha256\$digest"
    Assert-Lca1Rc8Incident (
        Test-SporeSporeStoredArtifact `
            -Directory $casDirectory `
            -ExpectedSha256 $digest `
            -ExpectedByteLength ([long]$artifact.byte_length)
    ) "retained CAS object changed: $digest"
    $casVerifiedCount += 1
}

$receipt = Read-Lca1Rc8IncidentJson (
    [string]$incident.cold_full_v2.run_receipt.path
)
Assert-Lca1Rc8Incident (
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
    [string]$receipt.source.status -ceq "observed_not_transitive" -and
    -not [bool]$receipt.source.transitive_dependency_key_complete -and
    [string]$receipt.cache.status -ceq "disabled_uncommissioned" -and
    -not [bool]$receipt.cache.lookup_performed -and
    -not [bool]$receipt.cache.result_reused -and
    [string]$receipt.input_identity.dependency_key_candidate.status -ceq
        "candidate_incomplete_cache_disabled" -and
    [string]$receipt.failure.message -ceq
        [string]$incident.cold_full_v2.canonical_failure_message -and
    @($receipt.stage_receipts).Count -eq 4 -and
    (@($receipt.stage_receipts.status) -join ",") -ceq
        "passed,passed,passed,failed" -and
    @($receipt.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
) "retained run receipt changed"

foreach ($expected in @($incident.cold_full_v2.stage_receipts)) {
    $stage = Read-Lca1Rc8IncidentJson ([string]$expected.path)
    Assert-Lca1Rc8Incident (
        [string]$stage.status -ceq [string]$expected.status -and
        [string]$stage.stage_id -ceq [string]$expected.stage_id -and
        [int]$stage.ordinal -eq [int]$expected.ordinal -and
        [int]$stage.exit_code -eq [int]$expected.exit_code -and
        [string]$stage.observed_input_identity_sha256 -ceq
            [string]$incident.cold_full_v2.observed_input_identity_sha256 -and
        [string]$stage.observed_input_status -ceq "observed_not_transitive" -and
        -not [bool]$stage.transitive_dependency_key_complete -and
        [string]$stage.cache.status -ceq "disabled_uncommissioned" -and
        -not [bool]$stage.cache.lookup_performed -and
        -not [bool]$stage.cache.result_reused -and
        @($stage.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
    ) "retained stage receipt changed: $($expected.stage_id)"
}
$failedStage = Read-Lca1Rc8IncidentJson (
    [string]$incident.cold_full_v2.stage_receipts[3].path
)
Assert-Lca1Rc8Incident (
    [string]$failedStage.error.message -ceq
        [string]$incident.cold_full_v2.canonical_failure_message
) "retained failed-stage error changed"

$toolchain = $incident.toolchain_runtime_identity
Assert-Lca1Rc8Incident (
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
) "retained RC8 toolchain identity changed"

Assert-Lca1Rc8Incident (
    (Test-Path -LiteralPath ([string]$incident.launch.pair_root) -PathType Container) -and
    @(Get-ChildItem -LiteralPath ([string]$incident.launch.pair_root) -Force).Count -eq 0 -and
    -not (Test-Path -LiteralPath ([string]$incident.launch.full_attestation_path)) -and
    -not (Test-Path -LiteralPath ([string]$incident.launch.scoped_output_root))
) "RC8 create-only pair-root boundary changed"

$commit = [string]$incident.observed_source_identity.commit
$tree = (& git -C $repoRoot rev-parse "$commit^{tree}").Trim()
Assert-Lca1Rc8Incident (
    $LASTEXITCODE -eq 0 -and
    $tree -ceq [string]$incident.observed_source_identity.tree_git_oid
) "RC8 source tree object changed"

$diagnosis = $incident.live_authority_expectation_diagnosis
foreach ($binding in @(
    [ordered]@{ path = $incident.preregistration.freeze_path; oid = $incident.preregistration.freeze_git_blob_oid; bytes = $incident.preregistration.freeze_byte_length },
    [ordered]@{ path = $incident.preregistration.manifest_path; oid = $incident.preregistration.manifest_git_blob_oid; bytes = $incident.preregistration.manifest_byte_length },
    [ordered]@{ path = $incident.preregistration.freeze_audit_path; oid = $incident.preregistration.freeze_audit_git_blob_oid; bytes = $incident.preregistration.freeze_audit_byte_length },
    [ordered]@{ path = $diagnosis.failing_audit.path; oid = $diagnosis.failing_audit.git_blob_oid; bytes = $diagnosis.failing_audit.byte_length },
    [ordered]@{ path = $diagnosis.release_contract.path; oid = $diagnosis.release_contract.git_blob_oid; bytes = $diagnosis.release_contract.byte_length },
    [ordered]@{ path = $diagnosis.support_matrix.path; oid = $diagnosis.support_matrix.git_blob_oid; bytes = $diagnosis.support_matrix.byte_length }
)) {
    $blob = Get-Lca1Rc8IncidentSourceBlob -Commit $commit -Path ([string]$binding.path)
    Assert-Lca1Rc8Incident (
        [string]$blob.oid -ceq [string]$binding.oid -and
        [long]$blob.byte_length -eq [long]$binding.bytes
    ) "RC8 source-bound object changed: $($binding.path)"
}

$sourceRelease = Read-Lca1Rc8IncidentSourceJson -Commit $commit `
    -Path ([string]$diagnosis.release_contract.path)
$sourceMatrix = Read-Lca1Rc8IncidentSourceJson -Commit $commit `
    -Path ([string]$diagnosis.support_matrix.path)
$turningGates = @($sourceRelease.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R23"
})
Assert-Lca1Rc8Incident ($turningGates.Count -eq 1) "RC8 release turning gate changed"
$contractRecord = $turningGates[0].proof.
    prospective_r23d62_selected_profile_three_engine_turning_validation
$matrixRecord = Find-Lca1Rc8IncidentRecordByGate $sourceMatrix "QSDK-R23D62"
Assert-Lca1Rc8Incident ($null -ne $matrixRecord) "RC8 support record changed"
Assert-Lca1Rc8Incident (
    [string]$turningGates[0].proof.current_prospective_successor_status -ceq
        [string]$diagnosis.observed_prospective_status -and
    [string]$contractRecord.status -ceq [string]$diagnosis.observed_record_status -and
    [string]$matrixRecord.status -ceq [string]$diagnosis.observed_record_status -and
    [bool]$contractRecord.clean_pushed_qualification_retained -and
    [bool]$matrixRecord.clean_pushed_qualification_retained -and
    [string]$contractRecord.qualification_source_commit -ceq
        [string]$diagnosis.observed_qualification_source_commit -and
    [string]$matrixRecord.qualification_source_commit -ceq
        [string]$diagnosis.observed_qualification_source_commit -and
    [string]$contractRecord.qualification_attestation_raw_sha256 -ceq
        [string]$diagnosis.observed_qualification_attestation_raw_sha256 -and
    [string]$matrixRecord.qualification_attestation_raw_sha256 -ceq
        [string]$diagnosis.observed_qualification_attestation_raw_sha256 -and
    [int]$contractRecord.qualification_executed_gate_count -eq 22 -and
    [int]$matrixRecord.qualification_executed_gate_count -eq 22 -and
    [int]$contractRecord.qualification_gate_cas_reference_count -eq 66 -and
    [int]$matrixRecord.qualification_gate_cas_reference_count -eq 66 -and
    [int]$contractRecord.qualification_gate_cas_unique_object_count -eq 46 -and
    [int]$matrixRecord.qualification_gate_cas_unique_object_count -eq 46 -and
    [int]$contractRecord.qualification_physical_world_count -eq 0 -and
    [int]$matrixRecord.qualification_physical_world_count -eq 0 -and
    [bool]$contractRecord.qualification_adoption_attempted -and
    [bool]$matrixRecord.qualification_adoption_attempted -and
    -not [bool]$contractRecord.campaign_attestation_adopted -and
    -not [bool]$matrixRecord.campaign_attestation_adopted -and
    [string]$contractRecord.adoption_refusal_failure_message -ceq
        [string]$diagnosis.observed_adoption_failure_message -and
    [string]$matrixRecord.adoption_refusal_failure_message -ceq
        [string]$diagnosis.observed_adoption_failure_message -and
    [int]$contractRecord.commissioned_core_source_binding_match_count -eq 9 -and
    [int]$matrixRecord.commissioned_core_source_binding_match_count -eq 9 -and
    [int]$contractRecord.commissioned_core_source_binding_mismatch_count -eq 1 -and
    [int]$matrixRecord.commissioned_core_source_binding_mismatch_count -eq 1 -and
    -not [bool]$contractRecord.physical_campaign_opened -and
    -not [bool]$matrixRecord.physical_campaign_opened -and
    [int]$contractRecord.world_build_count -eq 0 -and
    [int]$matrixRecord.world_build_count -eq 0 -and
    -not [bool]$contractRecord.finite_three_engine_turning -and
    -not [bool]$matrixRecord.finite_three_engine_turning -and
    -not [bool]$contractRecord.q_sdk_r23_satisfied -and
    -not [bool]$matrixRecord.q_sdk_r23_satisfied -and
    -not [bool]$contractRecord.release_authorized -and
    -not [bool]$matrixRecord.release_authorized
) "RC8 observed release/support authority changed"

$failingAuditText = Read-Lca1Rc8IncidentSourceText -Commit $commit `
    -Path ([string]$diagnosis.failing_audit.path)
Assert-Lca1Rc8Incident (
    $failingAuditText.Contains(
        '"r23d62_campaign_machinery_complete_zero_world_gate_passed_physical_not_opened"'
    ) -and
    $failingAuditText.Contains(
        '"prospective_campaign_machinery_implemented_complete_zero_world_gate_passed_physical_not_opened"'
    ) -and
    $failingAuditText.Contains(
        '-not [bool]$contractRecord.clean_pushed_qualification_retained'
    ) -and
    $failingAuditText.Contains(
        '-not [bool]$matrixRecord.clean_pushed_qualification_retained'
    )
) "RC8 pinned stale audit expectation changed"

$mismatches = 0
if ([string]$turningGates[0].proof.current_prospective_successor_status -cne
    [string]$diagnosis.stale_expected_prospective_status) { $mismatches += 1 }
if ([string]$contractRecord.status -cne
    [string]$diagnosis.stale_expected_record_status) { $mismatches += 1 }
if ([string]$matrixRecord.status -cne
    [string]$diagnosis.stale_expected_record_status) { $mismatches += 1 }
if ([bool]$contractRecord.clean_pushed_qualification_retained -ne
    [bool]$diagnosis.stale_expected_clean_pushed_qualification_retained) {
    $mismatches += 1
}
if ([bool]$matrixRecord.clean_pushed_qualification_retained -ne
    [bool]$diagnosis.stale_expected_clean_pushed_qualification_retained) {
    $mismatches += 1
}
Assert-Lca1Rc8Incident (
    $mismatches -eq [int]$diagnosis.mismatched_value_count
) "RC8 deterministic mismatch count changed"

Assert-Lca1Rc8Incident (
    [string]$contractRecord.local_declaration_audit_raw_sha256 -ceq
        [string]$diagnosis.failing_audit.raw_sha256 -and
    [string]$matrixRecord.local_declaration_audit_sha256 -ceq
        [string]$diagnosis.failing_audit.raw_sha256 -and
    [string]$contractRecord.question_class -ceq "finite_decision" -and
    [string]$matrixRecord.question_class -ceq "finite_decision" -and
    [int]$contractRecord.reserved_seed -eq 23167 -and
    [int]$matrixRecord.reserved_seed -eq 23167 -and
    [int]$contractRecord.declared_world_count -eq 9 -and
    [int]$matrixRecord.declared_world_count -eq 9
) "RC8 unchanged R23D62 declaration identity changed"

$failureText = Get-Content -Raw -LiteralPath (
    [string]$incident.cold_full_v2.failure_excerpt.path
)
$fullLogText = Get-Content -Raw -LiteralPath (
    [string]$incident.cold_full_v2.full_log.path
)
Assert-Lca1Rc8Incident (
    $failureText.Contains([string]$incident.cold_full_v2.canonical_failure_message) -and
    $fullLogText.Contains('"stage_id":"campaign_closures_and_zero_world_gates"') -and
    $fullLogText.Contains('"status":"failed"')
) "RC8 retained failure text changed"

Write-Host (
    "LCA1_RC8_INCIDENT_PASS class=equivalence_non_inferiority " +
    "full_stage_receipts=4 passed_stages=3 scoped_gates=0 " +
    "cas=$casVerifiedCount mismatches=$mismatches mutations=$mutationRefusals " +
    "models=0 worlds=0 physical_authority=False release_authority=False"
)

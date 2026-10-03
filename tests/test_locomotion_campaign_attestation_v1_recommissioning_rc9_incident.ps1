#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$incidentPath = Join-Path $repoRoot (
    "sdk\locomotion_campaign_attestation_v1_recommissioning_rc9_incident.json"
)
$evidenceRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)
$campaignId = (
    "QSDK-R23D62-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION"
)

function Assert-Lca1Rc9Incident([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "LCA1_RC9_INCIDENT $Message" }
}

function Read-Lca1Rc9IncidentJson([string]$Path) {
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Copy-Lca1Rc9IncidentDocument([object]$Value) {
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-Lca1Rc9SourceBlob(
    [Parameter(Mandatory)][string]$Commit,
    [Parameter(Mandatory)][string]$Path
) {
    $oid = (& git -C $repoRoot rev-parse "$Commit`:$Path").Trim()
    Assert-Lca1Rc9Incident ($LASTEXITCODE -eq 0) "missing source blob: $Path"
    $type = (& git -C $repoRoot cat-file -t $oid).Trim()
    $bytes = [long]((& git -C $repoRoot cat-file -s $oid).Trim())
    Assert-Lca1Rc9Incident (
        $LASTEXITCODE -eq 0 -and $type -ceq "blob"
    ) "invalid source object: $Path"
    return [ordered]@{ oid = $oid; byte_length = $bytes }
}

function Read-Lca1Rc9SourceText([string]$Commit, [string]$Path) {
    $text = @(& git -C $repoRoot show "$Commit`:$Path") -join "`n"
    Assert-Lca1Rc9Incident ($LASTEXITCODE -eq 0) (
        "cannot read source text: $Commit`:$Path"
    )
    return $text
}

function Find-Lca1Rc9CampaignRecord([object]$Value) {
    if ($null -eq $Value) { return $null }
    if ($Value -is [Collections.IDictionary]) {
        if ($Value.Contains("campaign_id") -and
            [string]$Value.campaign_id -ceq $campaignId) {
            return $Value
        }
        foreach ($key in @($Value.Keys)) {
            $found = Find-Lca1Rc9CampaignRecord $Value[$key]
            if ($null -ne $found) { return $found }
        }
    } elseif ($Value -is [Collections.IEnumerable] -and
        -not ($Value -is [string])) {
        foreach ($item in @($Value)) {
            $found = Find-Lca1Rc9CampaignRecord $item
            if ($null -ne $found) { return $found }
        }
    }
    return $null
}

function Test-Lca1Rc9IncidentDocument(
    [Parameter(Mandatory)][Collections.IDictionary]$Document
) {
    $failures = [Collections.Generic.List[string]]::new()
    if ([string]$Document.schema_version -cne
            "sporespore_locomotion_campaign_attestation_commissioning_incident_v1" -or
        [string]$Document.incident_id -cne "LCA1-RC9-COLD-PAIR-20260824" -or
        [string]$Document.status -cne
            "closed_negative_full_stage_4_r23d62_rapier_route_live_authority_expectation_mismatch_scoped_not_started" -or
        [string]$Document.question_class -cne "equivalence_non_inferiority" -or
        [bool]$Document.physical_question) {
        $failures.Add("IDENTITY")
    }
    $source = $Document.observed_source_identity
    if ([string]$source.commit -cne
            "8d55aad2b19d88d80455fc16ae9b9ce74cdd7b7e" -or
        [string]$source.tree_git_oid -cne
            "2da6b343a5b6197f3f3e286da7573e139bb6e412" -or
        [string]$source.origin_main -cne [string]$source.commit -or
        [string]$source.live_github_main -cne [string]$source.commit -or
        [string]$source.remote_url -cne
            "https://github.com/Slagathore/sporespore.git" -or
        [string]$source.branch -cne "main" -or
        -not [bool]$source.worktree_clean) {
        $failures.Add("SOURCE")
    }
    $pre = $Document.preregistration
    if ([string]$pre.program_id -cne
            "LCA1-RC9-R23D62-PREREGISTRATION-LIVE-AUTHORITY-RECONCILIATION" -or
        [string]$pre.freeze_raw_sha256 -cne
            "sha256:767360539b283de0407bc93f227c371b63be77eabe8ee323bc842a9cd517e80a" -or
        [string]$pre.manifest_raw_sha256 -cne
            "sha256:71ef2cf4dbdfa6e6779477b392363e11d559dee7bb35055b8a6c777f838cf556" -or
        [string]$pre.freeze_audit_raw_sha256 -cne
            "sha256:33547b3f5bc679e2b7e9cb91aedace14982afcaf367a0ca3068fb2f8ce747a59" -or
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
            "failed_stage_4_r23d62_rapier_route_live_authority_expectation_mismatch" -or
        [string]$full.run_id -cne
            "20260824T223428Z-8d55aad2-599e171a05ae4165ac457bd3580a1140" -or
        [double]$full.duration_seconds -ne 697.9611346 -or
        [int]$full.required_stage_count -ne 8 -or
        [int]$full.stage_receipt_count -ne 4 -or
        [int]$full.passed_stage_count -ne 3 -or
        [int]$full.failed_stage_count -ne 1 -or
        [string]$full.first_failed_stage_id -cne
            "campaign_closures_and_zero_world_gates" -or
        [int]$full.first_failed_stage_ordinal -ne 4 -or
        [int]$full.first_failed_stage_exit_code -ne 1 -or
        [string]$full.canonical_failure_message -cne
            "R23D62 Rapier public-profile production-route audit failed with exit code 1" -or
        [string]$full.inner_audit_failure_code -cne
            "QSDK_R23D62_RAP_ROUTE_AUTHORITY_STATUS_INVALID" -or
        [string]$full.cache_status -cne "disabled_uncommissioned" -or
        [bool]$full.cache_lookup_performed -or [bool]$full.result_reused -or
        [bool]$full.full_attestation_created -or
        [int]$full.physical_campaign_process_launch_count -ne 0 -or
        [int]$full.model_construction_count -ne 0 -or
        [int]$full.world_attempt_count -ne 0 -or
        [int]$full.world_build_count -ne 0) {
        $failures.Add("FULL")
    }
    if ((@($full.stage_receipts.status) -join ",") -cne
            "passed,passed,passed,failed" -or
        (@($full.stage_receipts.ordinal) -join ",") -cne "1,2,3,4" -or
        (@($full.stage_receipts.exit_code) -join ",") -cne "0,0,0,1") {
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
    $runtime = $Document.toolchain_runtime_identity
    if ([string]$runtime.identity_sha256 -cne
            "sha256:5e47a7b9e84994e94d839c17b02f61397c2eb2e0deb8ff358f734ab2ca3bf98f" -or
        [string]$runtime.powershell_version -cne "7.6.5" -or
        [string]$runtime.python_version -cne "Python 3.11.9" -or
        [string]$runtime.godot_version -cne
            "4.7.stable.mono.official.5b4e0cb0f") {
        $failures.Add("RUNTIME")
    }
    $diagnosis = $Document.live_authority_expectation_diagnosis
    if ([string]$diagnosis.executed_failing_audit.path -cne
            "tests/test_qsdk_r23d62_rapier_public_profile_physical_route.py" -or
        [string]$diagnosis.executed_failing_audit.raw_sha256 -cne
            "sha256:1e1fcbaa2c79ea07ca6adf6bba8db565ad04e53d8096996bd632c16c7b47ae86" -or
        [string]$diagnosis.stale_expected_record_status -cne
            "prospective_campaign_machinery_implemented_complete_zero_world_gate_passed_physical_not_opened" -or
        [string]$diagnosis.observed_release_record_status -cne
            "clean_pushed_qualification_passed_adoption_refused_rc8_closed_negative_rc9_recommissioning_prospective_physical_not_opened" -or
        [string]$diagnosis.observed_support_record_status -cne
            [string]$diagnosis.observed_release_record_status -or
        [int]$diagnosis.executed_mismatched_value_count -ne 2 -or
        @($diagnosis.prospectively_identified_unreached_same_defect_consumers).Count -ne 3 -or
        [int]$diagnosis.prospective_consumer_reconciliation_count -ne 4 -or
        -not [bool]$diagnosis.implementation_hash_binding_reconciliation_required -or
        -not [bool]$diagnosis.failing_audit_source_change_required -or
        [bool]$diagnosis.canonical_runner_source_change_required -or
        [bool]$diagnosis.campaign_preregistration_semantics_change_required -or
        [bool]$diagnosis.campaign_evaluator_change_required -or
        [bool]$diagnosis.campaign_worker_or_supervisor_behavior_change_required -or
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
        [bool]$interpretation.same_source_rerun_authorized -or
        [bool]$interpretation.observed_result_or_interpretation_rewrite_authorized -or
        [bool]$interpretation.threshold_change_authorized -or
        [bool]$interpretation.controller_change_authorized -or
        [bool]$interpretation.physics_change_authorized -or
        [bool]$interpretation.physical_rerun_authorized_by_incident) {
        $failures.Add("INTERPRETATION")
    }
    $claims = $Document.claims
    if (-not [bool]$claims.rc9_full_half_attempted -or
        [bool]$claims.rc9_pair_completed -or
        [bool]$claims.rc9_commissioning_passed -or
        [bool]$claims.current_executor_commissioned -or
        [bool]$claims.physical_launch_prerequisite_satisfied -or
        [bool]$claims.physical_campaign_executed -or
        [bool]$claims.scientific_result -or
        [bool]$claims.walking_acceptance -or
        [bool]$claims.turning_acceptance -or
        [bool]$claims.cross_engine_equivalence -or
        [bool]$claims.arbitrary_quadruped_coverage -or
        [bool]$claims.release_authority -or
        [bool]$claims.physical_acceptance_authority) {
        $failures.Add("CLAIMS")
    }
    return @($failures)
}

Assert-Lca1Rc9Incident (Test-Path -LiteralPath $incidentPath -PathType Leaf) (
    "incident missing"
)
$document = Read-Lca1Rc9IncidentJson $incidentPath
$documentFailures = @(Test-Lca1Rc9IncidentDocument $document)
Assert-Lca1Rc9Incident ($documentFailures.Count -eq 0) (
    "document invalid: $($documentFailures -join ',')"
)

$sourceCommit = [string]$document.observed_source_identity.commit
$tree = (& git -C $repoRoot rev-parse "$sourceCommit^{tree}").Trim()
Assert-Lca1Rc9Incident (
    $LASTEXITCODE -eq 0 -and
    $tree -ceq [string]$document.observed_source_identity.tree_git_oid
) "source tree changed"

$sourceChecks = @(
    @($document.preregistration.freeze_path,
      $document.preregistration.freeze_git_blob_oid,
      $document.preregistration.freeze_byte_length),
    @($document.preregistration.manifest_path,
      $document.preregistration.manifest_git_blob_oid,
      $document.preregistration.manifest_byte_length),
    @($document.preregistration.freeze_audit_path,
      $document.preregistration.freeze_audit_git_blob_oid,
      $document.preregistration.freeze_audit_byte_length),
    @($document.live_authority_expectation_diagnosis.executed_failing_audit.path,
      $document.live_authority_expectation_diagnosis.executed_failing_audit.git_blob_oid,
      $document.live_authority_expectation_diagnosis.executed_failing_audit.byte_length),
    @($document.live_authority_expectation_diagnosis.release_contract.path,
      $document.live_authority_expectation_diagnosis.release_contract.git_blob_oid,
      $document.live_authority_expectation_diagnosis.release_contract.byte_length),
    @($document.live_authority_expectation_diagnosis.support_matrix.path,
      $document.live_authority_expectation_diagnosis.support_matrix.git_blob_oid,
      $document.live_authority_expectation_diagnosis.support_matrix.byte_length)
)
foreach ($check in $sourceChecks) {
    $blob = Get-Lca1Rc9SourceBlob -Commit $sourceCommit -Path ([string]$check[0])
    Assert-Lca1Rc9Incident (
        [string]$blob.oid -ceq [string]$check[1] -and
        [long]$blob.byte_length -eq [long]$check[2]
    ) "source binding changed: $($check[0])"
}
foreach ($consumer in @(
    $document.live_authority_expectation_diagnosis.
        prospectively_identified_unreached_same_defect_consumers
)) {
    $blob = Get-Lca1Rc9SourceBlob -Commit $sourceCommit -Path ([string]$consumer.path)
    Assert-Lca1Rc9Incident (
        [string]$blob.oid -ceq [string]$consumer.git_blob_oid -and
        [long]$blob.byte_length -eq [long]$consumer.byte_length
    ) "unreached consumer binding changed: $($consumer.path)"
}

foreach ($path in @(
    [string]$document.live_authority_expectation_diagnosis.executed_failing_audit.path
) + @(
    $document.live_authority_expectation_diagnosis.
        prospectively_identified_unreached_same_defect_consumers.path
)) {
    $sourceText = Read-Lca1Rc9SourceText -Commit $sourceCommit -Path $path
    Assert-Lca1Rc9Incident (
        $sourceText.Contains(
            "prospective_campaign_machinery_implemented_complete_zero_world_gate_"
        ) -and $sourceText.Contains("passed_physical_not_opened")
    ) (
        "stale source expectation no longer reproduced: $path"
    )
}

$releaseSource = Read-Lca1Rc9SourceText -Commit $sourceCommit -Path (
    [string]$document.live_authority_expectation_diagnosis.release_contract.path
) | ConvertFrom-Json -AsHashtable -Depth 100
$matrixSource = Read-Lca1Rc9SourceText -Commit $sourceCommit -Path (
    [string]$document.live_authority_expectation_diagnosis.support_matrix.path
) | ConvertFrom-Json -AsHashtable -Depth 100
$releaseRecord = Find-Lca1Rc9CampaignRecord $releaseSource
$matrixRecord = Find-Lca1Rc9CampaignRecord $matrixSource
Assert-Lca1Rc9Incident (
    $null -ne $releaseRecord -and $null -ne $matrixRecord -and
    [string]$releaseRecord.status -ceq
        [string]$document.live_authority_expectation_diagnosis.observed_release_record_status -and
    [string]$matrixRecord.status -ceq
        [string]$document.live_authority_expectation_diagnosis.observed_support_record_status
) "observed source authority state changed"

$pairRoot = [IO.Path]::GetFullPath(
    ([string]$document.launch.pair_root).Replace("/", "\")
)
Assert-Lca1Rc9Incident (
    (Test-Path -LiteralPath $pairRoot -PathType Container) -and
    @(Get-ChildItem -LiteralPath $pairRoot -Force).Count -eq 0 -and
    -not (Test-Path -LiteralPath (
        [IO.Path]::GetFullPath(
            ([string]$document.launch.full_attestation_path).Replace("/", "\")
        )
    )) -and
    -not (Test-Path -LiteralPath (
        [IO.Path]::GetFullPath(
            ([string]$document.launch.scoped_output_root).Replace("/", "\")
        )
    ))
) "pair launch boundary changed"

$artifactRecords = @($document.cold_full_v2.run_receipt) +
    @($document.cold_full_v2.stage_receipts) +
    @($document.cold_full_v2.full_log) +
    @($document.cold_full_v2.failure_excerpt)
foreach ($record in $artifactRecords) {
    $path = [IO.Path]::GetFullPath(([string]$record.path).Replace("/", "\"))
    Assert-Lca1Rc9Incident ($path.StartsWith($evidenceRoot)) (
        "artifact escaped evidence root: $path"
    )
    $hex = [string]$record.raw_sha256
    Assert-Lca1Rc9Incident (
        $hex -cmatch '^sha256:[0-9a-f]{64}$' -and
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        ("sha256:" + (Get-FileHash -LiteralPath $path -Algorithm SHA256).
            Hash.ToLowerInvariant()) -ceq $hex -and
        [long](Get-Item -LiteralPath $path).Length -eq [long]$record.byte_length -and
        [bool]$record.cas_required -and [bool]$record.cas_verified
    ) "artifact receipt invalid: $path"
    $payload = Join-Path $evidenceRoot (
        "artifacts\sha256\" + $hex.Substring(7) + "\payload.bin"
    )
    Assert-Lca1Rc9Incident (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        ("sha256:" + (Get-FileHash -LiteralPath $payload -Algorithm SHA256).
            Hash.ToLowerInvariant()) -ceq $hex -and
        [long](Get-Item -LiteralPath $payload).Length -eq [long]$record.byte_length
    ) "CAS verification failed: $hex"
}

$receipt = Read-Lca1Rc9IncidentJson (
    [IO.Path]::GetFullPath(
        ([string]$document.cold_full_v2.run_receipt.path).Replace("/", "\")
    )
)
Assert-Lca1Rc9Incident (
    [string]$receipt.status -ceq "failed" -and
    [string]$receipt.tier -ceq "full_cold" -and
    [string]$receipt.source.head -ceq $sourceCommit -and
    [string]$receipt.source.head_tree -ceq
        [string]$document.observed_source_identity.tree_git_oid -and
    [bool]$receipt.source.worktree_clean -and
    [string]$receipt.failure.message -ceq
        [string]$document.cold_full_v2.canonical_failure_message -and
    (@($receipt.stage_receipts.status) -join ",") -ceq
        "passed,passed,passed,failed" -and
    -not [bool]$receipt.claims.physical_campaign_executed -and
    -not [bool]$receipt.claims.physical_acceptance_authority -and
    -not [bool]$receipt.claims.scientific_result -and
    -not [bool]$receipt.claims.release_authority
) "run receipt semantics changed"

$mutations = @(
    @{ name = "status"; apply = { param($d) $d.status = "positive" } },
    @{ name = "source"; apply = { param($d) $d.observed_source_identity.commit = "0" * 40 } },
    @{ name = "freeze"; apply = { param($d) $d.preregistration.freeze_raw_sha256 = "sha256:" + ("0" * 64) } },
    @{ name = "rerun"; apply = { param($d) $d.preregistration.same_source_rerun_after_complete_or_failed_pair_allowed = $true } },
    @{ name = "launch"; apply = { param($d) $d.launch.full_attestation_created = $true } },
    @{ name = "duration"; apply = { param($d) $d.cold_full_v2.duration_seconds = 1.0 } },
    @{ name = "stage"; apply = { param($d) $d.cold_full_v2.stage_receipts[3].status = "passed" } },
    @{ name = "failure"; apply = { param($d) $d.cold_full_v2.inner_audit_failure_code = "OTHER" } },
    @{ name = "scoped"; apply = { param($d) $d.cold_scoped_lca1.attempted = $true } },
    @{ name = "runtime"; apply = { param($d) $d.toolchain_runtime_identity.powershell_version = "0.0.0" } },
    @{ name = "observed"; apply = { param($d) $d.live_authority_expectation_diagnosis.observed_release_record_status = "other" } },
    @{ name = "mismatch"; apply = { param($d) $d.live_authority_expectation_diagnosis.executed_mismatched_value_count = 1 } },
    @{ name = "consumers"; apply = { param($d) $d.live_authority_expectation_diagnosis.prospective_consumer_reconciliation_count = 1 } },
    @{ name = "runner"; apply = { param($d) $d.live_authority_expectation_diagnosis.canonical_runner_source_change_required = $true } },
    @{ name = "physics"; apply = { param($d) $d.live_authority_expectation_diagnosis.physics_change_required = $true } },
    @{ name = "interpretation"; apply = { param($d) $d.interpretation.physics_failure = $true } },
    @{ name = "same-source"; apply = { param($d) $d.interpretation.same_source_rerun_authorized = $true } },
    @{ name = "commissioned"; apply = { param($d) $d.claims.rc9_commissioning_passed = $true } },
    @{ name = "turning"; apply = { param($d) $d.claims.turning_acceptance = $true } },
    @{ name = "release"; apply = { param($d) $d.claims.release_authority = $true } }
)
foreach ($mutation in $mutations) {
    $candidate = Copy-Lca1Rc9IncidentDocument $document
    & $mutation.apply $candidate
    Assert-Lca1Rc9Incident (
        @(Test-Lca1Rc9IncidentDocument $candidate).Count -gt 0
    ) "mutation accepted: $($mutation.name)"
}

Write-Host (
    "LCA1_RC9_INCIDENT_PASS class=equivalence_non_inferiority " +
    "full_stage_receipts=4 passed_stages=3 scoped_gates=0 cas=7 " +
    "mismatches=2 prospective_consumers=4 mutations=$($mutations.Count) " +
    "models=0 worlds=0 physical_authority=False release_authority=False"
)

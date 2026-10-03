#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$incidentPath = Join-Path $repoRoot (
    "sdk\locomotion_campaign_attestation_v1_recommissioning_rc11_incident.json"
)
$evidenceRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

function Assert-Lca1Rc11Incident([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "LCA1_RC11_INCIDENT $Message" }
}

function Read-Lca1Rc11IncidentJson([string]$Path) {
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Copy-Lca1Rc11IncidentDocument([object]$Value) {
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-Lca1Rc11SourceBlob(
    [Parameter(Mandatory)][string]$Commit,
    [Parameter(Mandatory)][string]$Path
) {
    $oid = (& git -C $repoRoot rev-parse "$Commit`:$Path").Trim()
    Assert-Lca1Rc11Incident ($LASTEXITCODE -eq 0) "missing source blob: $Path"
    $type = (& git -C $repoRoot cat-file -t $oid).Trim()
    $bytes = [long]((& git -C $repoRoot cat-file -s $oid).Trim())
    Assert-Lca1Rc11Incident (
        $LASTEXITCODE -eq 0 -and $type -ceq "blob"
    ) "invalid source object: $Path"

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = "git"
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in @("-C", $repoRoot, "cat-file", "blob", $oid)) {
        [void]$startInfo.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    Assert-Lca1Rc11Incident ($process.Start()) "cannot start git cat-file: $Path"
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $digest = $sha.ComputeHash($process.StandardOutput.BaseStream)
    } finally {
        $sha.Dispose()
    }
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    Assert-Lca1Rc11Incident ($process.ExitCode -eq 0) (
        "git cat-file failed: $Path $stderr"
    )
    $rawSha256 = -join ($digest | ForEach-Object { $_.ToString("x2") })
    return [ordered]@{
        oid = $oid
        byte_length = $bytes
        raw_sha256 = "sha256:$rawSha256"
    }
}

function Read-Lca1Rc11SourceText([string]$Commit, [string]$Path) {
    $text = @(& git -C $repoRoot show "$Commit`:$Path") -join "`n"
    Assert-Lca1Rc11Incident ($LASTEXITCODE -eq 0) (
        "cannot read source text: $Commit`:$Path"
    )
    return $text
}

function Test-Lca1Rc11IncidentDocument(
    [Parameter(Mandatory)][Collections.IDictionary]$Document
) {
    $failures = [Collections.Generic.List[string]]::new()
    if ([string]$Document.schema_version -cne
            "sporespore_locomotion_campaign_attestation_commissioning_incident_v1" -or
        [string]$Document.incident_id -cne "LCA1-RC11-COLD-PAIR-20260825" -or
        [string]$Document.status -cne
            "closed_negative_full_stage_6_r24d2_live_source_manifest_binding_drift_scoped_not_started" -or
        [string]$Document.question_class -cne "equivalence_non_inferiority" -or
        [bool]$Document.physical_question) {
        $failures.Add("IDENTITY")
    }
    $source = $Document.observed_source_identity
    if ([string]$source.commit -cne
            "2b109c2f791531d875d63704f970fcaded1eb433" -or
        [string]$source.tree_git_oid -cne
            "d8700c2cd5d066302dc9cef6d2a2005465381262" -or
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
            "LCA1-RC11-R24D3-LIVE-SOURCE-AUDIT-RECONCILIATION" -or
        [string]$pre.freeze_raw_sha256 -cne
            "sha256:f097481dd521be6cfdf90d692398b3e6404df665f4396ee65a8af8c6ae7abc62" -or
        [string]$pre.manifest_raw_sha256 -cne
            "sha256:f90a446ddd40050e49b19c8e679ea067ff849f938ca98fd3e42151d4aebd58fb" -or
        [string]$pre.freeze_audit_raw_sha256 -cne
            "sha256:7942b3be8628ed2d2d6b9b78ccea8cc67515be631a14dfa3fa08dc8574007afb" -or
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
            "failed_stage_6_r24d2_live_source_manifest_binding_drift" -or
        [string]$full.run_id -cne
            "20260825T002211Z-2b109c2f-d9d6a44cb03c4977adaa022e4781dd5a" -or
        [double]$full.duration_seconds -ne 1015.2435862 -or
        [int]$full.required_stage_count -ne 8 -or
        [int]$full.stage_receipt_count -ne 6 -or
        [int]$full.passed_stage_count -ne 5 -or
        [int]$full.failed_stage_count -ne 1 -or
        [string]$full.first_failed_stage_id -cne "godot_runtime_regression" -or
        [int]$full.first_failed_stage_ordinal -ne 6 -or
        [int]$full.first_failed_stage_exit_code -ne 1 -or
        -not ([string]$full.canonical_failure_message).Contains(
            "QSDK-R24D2: Manifest source binding drifted: .gitattributes"
        ) -or
        [string]$full.inner_failure_message -cne
            "QSDK-R24D2: Manifest source binding drifted: .gitattributes" -or
        [string]$full.inner_audit_failure_code -cne
            "QSDK_R24D2_MANIFEST_SOURCE_BINDING_DRIFT" -or
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
            "passed,passed,passed,passed,passed,failed" -or
        (@($full.stage_receipts.ordinal) -join ",") -cne "1,2,3,4,5,6" -or
        (@($full.stage_receipts.exit_code) -join ",") -cne "0,0,0,0,0,1" -or
        (@($full.stage_receipts.stage_id) -join "|") -cne
            "authority_and_historical_closures|source_inventory_and_zero_world_preflights|portable_core_and_release_source|campaign_closures_and_zero_world_gates|selectors_and_integrity|godot_runtime_regression") {
        $failures.Add("STAGES")
    }
    $scoped = $Document.cold_scoped_lca1
    if ([string]$scoped.status -cne "not_started_after_full_stage_6_failure" -or
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
    $progress = $Document.r23d62_stage_progress
    if ([string]$progress.stage_id -cne "campaign_closures_and_zero_world_gates" -or
        [int]$progress.stage_ordinal -ne 4 -or
        [string]$progress.stage_status -cne "passed" -or
        -not [bool]$progress.r23d62_preregistration_gate_passed -or
        -not [bool]$progress.r23d62_evaluator_v2_gate_passed -or
        -not [bool]$progress.r23d62_rapier_public_profile_route_gate_passed -or
        [bool]$progress.r23d62_rapier_worker_executed_in_this_stage -or
        -not [bool]$progress.r23d62_godot_route_and_worker_gates_passed -or
        [bool]$progress.r23d62_mujoco_route_or_worker_executed_in_this_stage -or
        -not [bool]$progress.defined_r23d62_stage4_gate_sequence_passed -or
        [bool]$progress.qualification_or_adoption_created -or
        [bool]$progress.physical_semantics_evaluated -or
        [int]$progress.physical_world_count -ne 0) {
        $failures.Add("R23D62_PROGRESS")
    }
    $diagnosis = $Document.live_source_manifest_diagnosis
    if ([string]$diagnosis.classification -cne
            "post_failure_live_source_validation_manifest_reconciliation" -or
        [string]$diagnosis.manifest_last_changed_commit -cne
            "9fb088d3de8a656f2ec5e45b71b900002cc66578" -or
        [string]$diagnosis.executed_first_failure_path -cne ".gitattributes" -or
        [int]$diagnosis.manifest_binding_count -ne 33 -or
        [int]$diagnosis.matching_binding_count -ne 18 -or
        [int]$diagnosis.stale_binding_count -ne 15 -or
        [int]$diagnosis.stale_hash_field_count -ne 15 -or
        [int]$diagnosis.stale_byte_length_field_count -ne 15 -or
        [int]$diagnosis.stale_binding_field_count -ne 30 -or
        @($diagnosis.stale_bindings).Count -ne 15 -or
        -not [bool]$diagnosis.r24d2_contract_binding_unchanged -or
        -not [bool]$diagnosis.r24d2_audit_binding_unchanged -or
        -not [bool]$diagnosis.r24d2_zero_world_runner_binding_unchanged -or
        -not [bool]$diagnosis.r24d2_core_recovery_binding_unchanged -or
        -not [bool]$diagnosis.r24d2_godot_adapter_binding_unchanged -or
        -not [bool]$diagnosis.r24d2_mujoco_adapter_binding_unchanged -or
        -not [bool]$diagnosis.r24d2_rapier_recovery_capability_binding_unchanged -or
        -not [bool]$diagnosis.r24d3_gate_passed_before_failure -or
        [bool]$diagnosis.canonical_runner_source_change_required -or
        [bool]$diagnosis.r24d2_recovery_contract_change_required -or
        [bool]$diagnosis.r24d2_recovery_semantics_change_required -or
        [bool]$diagnosis.r23d62_declaration_change_required -or
        [bool]$diagnosis.r23d62_evaluator_change_required -or
        [bool]$diagnosis.r23d62_worker_or_supervisor_change_required -or
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
    if (-not [bool]$claims.rc11_full_half_attempted -or
        [bool]$claims.rc11_pair_completed -or
        [bool]$claims.rc11_commissioning_passed -or
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

Assert-Lca1Rc11Incident (Test-Path -LiteralPath $incidentPath -PathType Leaf) (
    "incident missing"
)
$document = Read-Lca1Rc11IncidentJson $incidentPath
$documentFailures = @(Test-Lca1Rc11IncidentDocument $document)
Assert-Lca1Rc11Incident ($documentFailures.Count -eq 0) (
    "document invalid: $($documentFailures -join ',')"
)

$sourceCommit = [string]$document.observed_source_identity.commit
$tree = (& git -C $repoRoot rev-parse "$sourceCommit^{tree}").Trim()
Assert-Lca1Rc11Incident (
    $LASTEXITCODE -eq 0 -and
    $tree -ceq [string]$document.observed_source_identity.tree_git_oid
) "source tree changed"

$sourceChecks = @(
    @($document.preregistration.freeze_path,
      $document.preregistration.freeze_raw_sha256,
      $document.preregistration.freeze_git_blob_oid,
      $document.preregistration.freeze_byte_length),
    @($document.preregistration.manifest_path,
      $document.preregistration.manifest_raw_sha256,
      $document.preregistration.manifest_git_blob_oid,
      $document.preregistration.manifest_byte_length),
    @($document.preregistration.freeze_audit_path,
      $document.preregistration.freeze_audit_raw_sha256,
      $document.preregistration.freeze_audit_git_blob_oid,
      $document.preregistration.freeze_audit_byte_length),
    @($document.live_source_manifest_diagnosis.manifest_path,
      $document.live_source_manifest_diagnosis.manifest_raw_sha256,
      $document.live_source_manifest_diagnosis.manifest_git_blob_oid,
      $document.live_source_manifest_diagnosis.manifest_byte_length),
    @($document.live_source_manifest_diagnosis.executed_failing_audit_path,
      $document.live_source_manifest_diagnosis.executed_failing_audit_raw_sha256,
      $document.live_source_manifest_diagnosis.executed_failing_audit_git_blob_oid,
      $document.live_source_manifest_diagnosis.executed_failing_audit_byte_length)
)
foreach ($check in $sourceChecks) {
    $blob = Get-Lca1Rc11SourceBlob -Commit $sourceCommit -Path ([string]$check[0])
    Assert-Lca1Rc11Incident (
        [string]$blob.raw_sha256 -ceq [string]$check[1] -and
        [string]$blob.oid -ceq [string]$check[2] -and
        [long]$blob.byte_length -eq [long]$check[3]
    ) "source binding changed: $($check[0])"
}

$historicalManifest = Read-Lca1Rc11SourceText -Commit $sourceCommit -Path (
    [string]$document.live_source_manifest_diagnosis.manifest_path
) | ConvertFrom-Json -AsHashtable -Depth 100
$manifestByPath = @{}
foreach ($binding in @($historicalManifest.source_bindings)) {
    $manifestByPath[[string]$binding.path] = $binding
}
foreach ($stale in @($document.live_source_manifest_diagnosis.stale_bindings)) {
    $path = [string]$stale.path
    Assert-Lca1Rc11Incident ($manifestByPath.ContainsKey($path)) (
        "historical manifest binding missing: $path"
    )
    $binding = $manifestByPath[$path]
    $blob = Get-Lca1Rc11SourceBlob -Commit $sourceCommit -Path $path
    $firstChanged = @(
        & git -C $repoRoot log --reverse --format=%H (
            "9fb088d3de8a656f2ec5e45b71b900002cc66578..$sourceCommit"
        ) -- $path | Select-Object -First 1
    )[0]
    Assert-Lca1Rc11Incident ($LASTEXITCODE -eq 0) (
        "cannot resolve first post-manifest change: $path"
    )
    Assert-Lca1Rc11Incident (
        [string]$binding.raw_sha256 -ceq [string]$stale.expected_raw_sha256 -and
        [long]$binding.byte_length -eq [long]$stale.expected_byte_length -and
        [string]$blob.raw_sha256 -ceq [string]$stale.observed_raw_sha256 -and
        [string]$blob.oid -ceq [string]$stale.observed_git_blob_oid -and
        [long]$blob.byte_length -eq [long]$stale.observed_byte_length -and
        [string]$binding.raw_sha256 -cne [string]$blob.raw_sha256 -and
        [long]$binding.byte_length -ne [long]$blob.byte_length -and
        [string]$firstChanged -cmatch '^[0-9a-f]{40}$' -and
        [string]$stale.first_changed_after_manifest_commit -ceq
            [string]$firstChanged
    ) "stale binding diagnosis changed: $path"
}

$runnerText = Read-Lca1Rc11SourceText -Commit $sourceCommit -Path (
    "sdk/run_conformance.ps1"
)
foreach ($marker in @(
    "test_qsdk_r23d62_preregistration.ps1",
    "test_qsdk_r23d62_evaluator_v2.ps1",
    "test_qsdk_r23d62_rapier_public_profile_physical_route.ps1",
    "test_qsdk_r23d62_godot_public_profile_physical_route.ps1",
    "test_qsdk_r23d62_godot_jolt_physical_worker.ps1"
)) {
    Assert-Lca1Rc11Incident ($runnerText.Contains($marker)) (
        "R23D62 stage marker missing from observed runner: $marker"
    )
}

$pairRoot = [IO.Path]::GetFullPath(
    ([string]$document.launch.pair_root).Replace("/", "\")
)
Assert-Lca1Rc11Incident (
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
Assert-Lca1Rc11Incident ($artifactRecords.Count -eq 9) (
    "retained artifact count changed"
)
foreach ($record in $artifactRecords) {
    $path = [IO.Path]::GetFullPath(([string]$record.path).Replace("/", "\"))
    Assert-Lca1Rc11Incident ($path.StartsWith($evidenceRoot)) (
        "artifact escaped evidence root: $path"
    )
    $hex = [string]$record.raw_sha256
    Assert-Lca1Rc11Incident (
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
    Assert-Lca1Rc11Incident (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        ("sha256:" + (Get-FileHash -LiteralPath $payload -Algorithm SHA256).
            Hash.ToLowerInvariant()) -ceq $hex -and
        [long](Get-Item -LiteralPath $payload).Length -eq [long]$record.byte_length
    ) "CAS verification failed: $hex"
}

$receipt = Read-Lca1Rc11IncidentJson (
    [IO.Path]::GetFullPath(
        ([string]$document.cold_full_v2.run_receipt.path).Replace("/", "\")
    )
)
Assert-Lca1Rc11Incident (
    [string]$receipt.status -ceq "failed" -and
    [string]$receipt.tier -ceq "full_cold" -and
    [string]$receipt.source.head -ceq $sourceCommit -and
    [string]$receipt.source.head_tree -ceq
        [string]$document.observed_source_identity.tree_git_oid -and
    [bool]$receipt.source.worktree_clean -and
    [string]$receipt.failure.message -ceq
        [string]$document.cold_full_v2.canonical_failure_message -and
    (@($receipt.stage_receipts.status) -join ",") -ceq
        "passed,passed,passed,passed,passed,failed" -and
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
    @{ name = "stage"; apply = { param($d) $d.cold_full_v2.stage_receipts[5].status = "passed" } },
    @{ name = "failure"; apply = { param($d) $d.cold_full_v2.inner_audit_failure_code = "OTHER" } },
    @{ name = "scoped"; apply = { param($d) $d.cold_scoped_lca1.attempted = $true } },
    @{ name = "runtime"; apply = { param($d) $d.toolchain_runtime_identity.powershell_version = "0.0.0" } },
    @{ name = "progress"; apply = { param($d) $d.r23d62_stage_progress.stage_status = "failed" } },
    @{ name = "rapier-worker"; apply = { param($d) $d.r23d62_stage_progress.r23d62_rapier_worker_executed_in_this_stage = $true } },
    @{ name = "manifest"; apply = { param($d) $d.live_source_manifest_diagnosis.manifest_binding_count = 13 } },
    @{ name = "matching"; apply = { param($d) $d.live_source_manifest_diagnosis.matching_binding_count = 11 } },
    @{ name = "stale"; apply = { param($d) $d.live_source_manifest_diagnosis.stale_binding_count = 3 } },
    @{ name = "field-count"; apply = { param($d) $d.live_source_manifest_diagnosis.stale_binding_field_count = 7 } },
    @{ name = "patch"; apply = { param($d) $d.live_source_manifest_diagnosis.r24d2_contract_binding_unchanged = $false } },
    @{ name = "runner"; apply = { param($d) $d.live_source_manifest_diagnosis.canonical_runner_source_change_required = $true } },
    @{ name = "physics"; apply = { param($d) $d.live_source_manifest_diagnosis.physics_change_required = $true } },
    @{ name = "interpretation"; apply = { param($d) $d.interpretation.physics_failure = $true } },
    @{ name = "commissioned"; apply = { param($d) $d.claims.rc11_commissioning_passed = $true } },
    @{ name = "turning"; apply = { param($d) $d.claims.turning_acceptance = $true } },
    @{ name = "release"; apply = { param($d) $d.claims.release_authority = $true } }
)
foreach ($mutation in $mutations) {
    $candidate = Copy-Lca1Rc11IncidentDocument $document
    & $mutation.apply $candidate
    Assert-Lca1Rc11Incident (
        @(Test-Lca1Rc11IncidentDocument $candidate).Count -gt 0
    ) "mutation accepted: $($mutation.name)"
}

Write-Host (
    "LCA1_RC11_INCIDENT_PASS class=equivalence_non_inferiority " +
    "full_stage_receipts=6 passed_stages=5 scoped_gates=0 cas=9 " +
    "r23d62_stage4=passed stale_bindings=15 stale_fields=30 " +
    "mutations=$($mutations.Count) models=0 worlds=0 " +
    "physical_authority=False release_authority=False"
)

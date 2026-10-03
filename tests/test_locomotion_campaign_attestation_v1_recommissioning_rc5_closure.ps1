#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot (
    "locomotion_campaign_attestation_v1_recommissioning_rc5_closure.json"
)
$sourceCommit = "ae2ba9d5eee1fb75a46a7b37016d6167b89fab42"
$sourceTree = "24d3a9f10ad07c87d6d573e0a29c65a1c1f18009"
. (Join-Path $sdkRoot "content_addressed_artifact_store.ps1")

function Assert-Lca1Rc5Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "LCA1_RC5_CLOSURE $Message" }
}

function Read-Lca1Rc5ClosureJson([string]$Path) {
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-Lca1Rc5ClosureSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Copy-Lca1Rc5ClosureDocument([object]$Value) {
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-Lca1Rc5ClosureGitBlobSha256([string]$RelativePath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $repoRoot, "cat-file", "blob", "${sourceCommit}:$RelativePath"
    )) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        Assert-Lca1Rc5Closure $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-Lca1Rc5Closure ($process.ExitCode -eq 0) (
            "Git blob read failed for $RelativePath`: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Get-Lca1Rc5ClosureGitBlobOid([string]$RelativePath) {
    $oid = (& git -C $repoRoot rev-parse "${sourceCommit}:$RelativePath").Trim()
    Assert-Lca1Rc5Closure ($LASTEXITCODE -eq 0) (
        "could not resolve source Git blob: $RelativePath"
    )
    return $oid
}

function Get-Lca1Rc5ClosureGitBlobLength([string]$RelativePath) {
    $length = (& git -C $repoRoot cat-file -s "${sourceCommit}:$RelativePath").Trim()
    Assert-Lca1Rc5Closure ($LASTEXITCODE -eq 0) (
        "could not measure source Git blob: $RelativePath"
    )
    return [long]$length
}

function Assert-Lca1Rc5ClosureArtifact(
    [Parameter(Mandatory)][System.Collections.IDictionary]$Artifact
) {
    $path = [IO.Path]::GetFullPath([string]$Artifact.path)
    Assert-Lca1Rc5Closure (Test-Path -LiteralPath $path -PathType Leaf) `
        "retained artifact is missing: $path"
    Assert-Lca1Rc5Closure (
        (Get-Item -LiteralPath $path).Length -eq [long]$Artifact.byte_length -and
        (Get-Lca1Rc5ClosureSha256 $path) -ceq [string]$Artifact.raw_sha256
    ) "retained artifact bytes changed: $path"
    if ([bool]$Artifact.cas_required) {
        $digest = ([string]$Artifact.raw_sha256).Substring(7)
        $artifactRoot = Join-Path (
            Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
        ) "artifacts\sha256"
        Assert-Lca1Rc5Closure (
            Test-SporeSporeStoredArtifact `
                -Directory (Join-Path $artifactRoot $digest) `
                -ExpectedSha256 $digest `
                -ExpectedByteLength ([long]$Artifact.byte_length)
        ) "retained CAS object changed: $digest"
    }
}

function Test-Lca1Rc5ClosureClaimVector(
    [Parameter(Mandatory)][System.Collections.IDictionary]$Actual,
    [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$TrueKeys,
    [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$FalseKeys
) {
    $expected = @($TrueKeys) + @($FalseKeys)
    if ((@($Actual.Keys | Sort-Object) -join "|") -cne
        (@($expected | Sort-Object) -join "|")) { return $false }
    foreach ($key in @($TrueKeys)) {
        if (-not [bool]$Actual[[string]$key]) { return $false }
    }
    foreach ($key in @($FalseKeys)) {
        if ([bool]$Actual[[string]$key]) { return $false }
    }
    return $true
}

function Test-Lca1Rc5ClosureDocument(
    [Parameter(Mandatory)][System.Collections.IDictionary]$Document
) {
    $failures = [Collections.Generic.List[string]]::new()
    if ([string]$Document.schema_version -cne
            "sporespore_locomotion_campaign_attestation_v1_recommissioning_rc5_closure_v1" -or
        [string]$Document.closure_id -cne
            "LCA1-RC5-COLD-RECOMMISSIONING-CLOSURE-20260815" -or
        [string]$Document.status -cne
            "closed_positive_exact_same_source_full_scoped_pair_cas_claim_vector_and_serialization_verified" -or
        [string]$Document.program_id -cne
            "LCA1-RC5-WORKBENCH-PROOF-BINDING-REPAIRED-RECOMMISSIONING") {
        $failures.Add("IDENTITY")
    }
    if ([string]$Document.question_class -cne "equivalence_non_inferiority" -or
        [bool]$Document.physical_question -or
        [string]$Document.inferential_unit -cne
            "one_predeclared_serialized_same_source_full_scoped_deterministic_process_pair") {
        $failures.Add("QUESTION")
    }
    $source = $Document.commissioned_implementation_source
    if ([string]$source.commit -cne $sourceCommit -or
        [string]$source.tree_git_oid -cne $sourceTree -or
        [string]$source.origin_main -cne $sourceCommit -or
        [string]$source.live_github_main -cne $sourceCommit -or
        [string]$source.remote_url -cne
            "https://github.com/Slagathore/sporespore.git" -or
        -not [bool]$source.worktree_clean -or $null -ne $source.status_entries) {
        $failures.Add("SOURCE")
    }
    $authority = $Document.prospective_authority
    if (-not [bool]$authority.freeze_was_clean_pushed_before_execution -or
        -not [bool]$authority.pair_was_executed_exactly_once -or
        [bool]$authority.prior_result_reuse_allowed -or
        [bool]$authority.cache_lookup_allowed -or
        [bool]$authority.selective_gate_execution_allowed -or
        [bool]$authority.same_source_rerun_allowed -or
        [string]$authority.closure_audit.path -cne
            "tests/test_locomotion_campaign_attestation_v1_recommissioning_rc5_closure.ps1" -or
        [string]$authority.closure_audit.raw_sha256 -notmatch '^sha256:[0-9a-f]{64}$' -or
        [string]$authority.closure_audit.raw_sha256 -ceq "sha256:" + ("0" * 64) -or
        [long]$authority.closure_audit.byte_length -le 0) {
        $failures.Add("AUTHORITY")
    }
    $full = $Document.full_v2
    if ([string]$full.status -cne "passed" -or
        [string]$full.tier -cne "full_cold" -or [bool]$full.test_only -or
        [int]$full.required_stage_count -ne 8 -or
        @($full.stage_receipts).Count -ne 8 -or
        [int]$full.failed_stage_count -ne 0 -or
        [bool]$full.cache_lookup_performed -or [bool]$full.result_reused -or
        [bool]$full.transitive_dependency_key_complete -or
        @($full.required_true_claim_keys).Count -ne 0 -or
        @($full.required_false_claim_keys).Count -ne 6 -or
        [int]$full.physical_process_launch_count -ne 0 -or
        [int]$full.physical_world_count -ne 0) {
        $failures.Add("FULL")
    }
    $scoped = $Document.scoped_lca1
    if ([string]$scoped.status -cne
            "campaign_local_godot_including_qualification_passed" -or
        [bool]$scoped.test_only -or [int]$scoped.global_gate_count -ne 12 -or
        [int]$scoped.lineage_gate_count -ne 1 -or
        [int]$scoped.campaign_role_gate_count -ne 3 -or
        [int]$scoped.executed_gate_count -ne 16 -or
        [int]$scoped.core_source_binding_count -ne 11 -or
        [int]$scoped.campaign_source_binding_count -ne 39 -or
        [int]$scoped.campaign_role_binding_count -ne 3 -or
        [int]$scoped.gate_cas_reference_count -ne 48 -or
        [int]$scoped.gate_cas_unique_object_count -ne 35 -or
        (@($scoped.required_true_claim_keys) -join "|") -cne
            "campaign_local_qualification_passed" -or
        @($scoped.required_false_claim_keys).Count -ne 10 -or
        -not [bool]$scoped.all_gates_executed -or
        -not [bool]$scoped.all_gate_streams_content_addressed -or
        -not [bool]$scoped.commissioned_field_remained_false -or
        [int]$scoped.physical_process_launch_count -ne 0 -or
        [int]$scoped.physical_world_count -ne 0) {
        $failures.Add("SCOPED")
    }
    $comparison = $Document.comparison
    if (-not [bool]$comparison.serialized_no_overlap -or
        -not [bool]$comparison.same_source_commit_and_tree -or
        -not [bool]$comparison.same_godot_identity -or
        -not [bool]$comparison.same_powershell_identity -or
        -not [bool]$comparison.same_python_identity -or
        -not [bool]$comparison.same_cargo_identity -or
        -not [bool]$comparison.same_rustc_identity -or
        -not [bool]$comparison.same_host_os_and_process_architecture -or
        @($comparison.required_full_terminal_marker_counts.Keys).Count -ne 5 -or
        @($comparison.required_scoped_terminal_marker_counts.Keys).Count -ne 4 -or
        @($comparison.required_full_terminal_marker_counts.Values |
            Where-Object { [int]$_ -ne 1 }).Count -ne 0 -or
        @($comparison.required_scoped_terminal_marker_counts.Values |
            Where-Object { [int]$_ -ne 1 }).Count -ne 0 -or
        [int]$comparison.numeric_equivalence_margin -ne 0 -or
        [int]$comparison.marker_cardinality_margin -ne 0 -or
        [int]$comparison.source_runtime_host_identity_margin -ne 0 -or
        [int]$comparison.claim_vector_margin -ne 0 -or
        -not [bool]$comparison.duration_ratios_are_descriptive_only -or
        [bool]$comparison.duration_ratio_threshold_or_acceptance_role -or
        -not [bool]$comparison.exact_acceptance_satisfied -or
        -not [bool]$comparison.commissioning_passed) {
        $failures.Add("COMPARISON")
    }
    $validation = $Document.independent_validation
    if ([int]$validation.full_validation_check_count -ne 14 -or
        [int]$validation.full_validation_failed_check_count -ne 0 -or
        [int]$validation.scoped_primary_validation_check_count -ne 14 -or
        [int]$validation.scoped_primary_evidence_check_pass_count -ne 13 -or
        [int]$validation.scoped_primary_source_check_false_alarm_count -ne 1 -or
        -not [bool]$validation.corrected_explicit_null_source_check_passed -or
        -not [bool]$validation.all_retained_source_fields_were_exact_during_false_alarm -or
        [bool]$validation.false_alarm_was_campaign_evaluator_or_result -or
        [bool]$validation.campaign_was_rerun_after_false_alarm -or
        [int]$validation.full_required_cas_object_count -ne 10 -or
        -not [bool]$validation.full_required_cas_objects_verified -or
        [int]$validation.scoped_required_cas_reference_count -ne 48 -or
        -not [bool]$validation.scoped_required_cas_references_verified -or
        -not [bool]$validation.scoped_top_attestation_cas_verified -or
        -not [bool]$validation.overall_pair_validation_passed) {
        $failures.Add("VALIDATION")
    }
    if (@($Document.immutable_prior_history).Count -ne 3 -or
        @($Document.immutable_prior_history |
            Where-Object { [bool]$_.same_source_rerun_allowed }).Count -ne 0) {
        $failures.Add("HISTORY")
    }
    $adequacy = $Document.adequacy_argument
    if (-not [bool]$adequacy.
            single_pair_is_adequate_for_exact_deterministic_executor_commissioning -or
        [bool]$adequacy.population_claim -or
        [bool]$adequacy.physics_equivalence_claim -or
        [bool]$adequacy.cross_engine_equivalence_claim -or
        [bool]$adequacy.movement_claim -or
        [bool]$adequacy.arbitrary_morphology_claim -or
        [bool]$adequacy.robustness_claim) {
        $failures.Add("ADEQUACY")
    }
    $adoption = $Document.adoption_boundary
    if (-not [bool]$adoption.
            exact_rc5_campaign_local_attestation_implementation_commissioned -or
        -not [bool]$adoption.
            original_scoped_attestation_document_remains_uncommissioned_and_zero_authority -or
        -not [bool]$adoption.old_commissioning_closure_remains_authoritative_for_its_old_executor -or
        -not [bool]$adoption.separate_fail_closed_adoption_composition_required -or
        [bool]$adoption.adoption_contract_updated_by_this_closure -or
        -not [bool]$adoption.fresh_clean_pushed_r23d54_qualification_and_adoption_required -or
        [bool]$adoption.r23d54_physical_launch_prerequisite_satisfied -or
        [bool]$adoption.physical_launch_authorized) {
        $failures.Add("ADOPTION")
    }
    $claims = $Document.claims
    $allowedTrue = @(
        "rc5_pair_executed",
        "rc5_exact_acceptance_satisfied",
        "campaign_local_attestation_implementation_commissioned"
    )
    if (@($claims.Keys).Count -ne 13 -or
        @($claims.GetEnumerator() | Where-Object {
            [bool]$_.Value -and $_.Key -cnotin $allowedTrue
        }).Count -ne 0 -or
        @($allowedTrue | Where-Object { -not [bool]$claims[$_] }).Count -ne 0) {
        $failures.Add("CLAIMS")
    }
    return [ordered]@{
        ok = $failures.Count -eq 0
        failure_codes = @($failures | Sort-Object -Unique)
    }
}

Assert-Lca1Rc5Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (git -C $repoRoot rev-parse ($sourceCommit + "^{tree}")) -ceq $sourceTree
) "repository or commissioned source identity changed"

$closure = Read-Lca1Rc5ClosureJson $closurePath
$documentTest = Test-Lca1Rc5ClosureDocument -Document $closure
Assert-Lca1Rc5Closure ([bool]$documentTest.ok) (
    "closure document changed: $(@($documentTest.failure_codes) -join ',')"
)

$mutations = @(
    @{ name = "status"; apply = { param($d) $d.status = "pending" } },
    @{ name = "question"; apply = { param($d) $d.question_class = "development" } },
    @{ name = "physical_question"; apply = { param($d) $d.physical_question = $true } },
    @{ name = "source"; apply = { param($d) $d.commissioned_implementation_source.commit = "0" * 40 } },
    @{ name = "reuse"; apply = { param($d) $d.prospective_authority.prior_result_reuse_allowed = $true } },
    @{ name = "rerun"; apply = { param($d) $d.prospective_authority.same_source_rerun_allowed = $true } },
    @{ name = "full_stage_count"; apply = { param($d) $d.full_v2.required_stage_count = 7 } },
    @{ name = "full_world"; apply = { param($d) $d.full_v2.physical_world_count = 1 } },
    @{ name = "scoped_gate_count"; apply = { param($d) $d.scoped_lca1.executed_gate_count = 15 } },
    @{ name = "scoped_binding_count"; apply = { param($d) $d.scoped_lca1.campaign_source_binding_count = 38 } },
    @{ name = "scoped_cas_count"; apply = { param($d) $d.scoped_lca1.gate_cas_reference_count = 47 } },
    @{ name = "scoped_true_claim"; apply = { param($d) $d.scoped_lca1.required_true_claim_keys = @() } },
    @{ name = "scoped_false_claim"; apply = { param($d) $d.scoped_lca1.required_false_claim_keys = @($d.scoped_lca1.required_false_claim_keys)[0..8] } },
    @{ name = "commissioned_field"; apply = { param($d) $d.scoped_lca1.commissioned_field_remained_false = $false } },
    @{ name = "serialization"; apply = { param($d) $d.comparison.serialized_no_overlap = $false } },
    @{ name = "margin"; apply = { param($d) $d.comparison.claim_vector_margin = 1 } },
    @{ name = "ratio_authority"; apply = { param($d) $d.comparison.duration_ratio_threshold_or_acceptance_role = $true } },
    @{ name = "validation"; apply = { param($d) $d.independent_validation.overall_pair_validation_passed = $false } },
    @{ name = "false_alarm"; apply = { param($d) $d.independent_validation.false_alarm_was_campaign_evaluator_or_result = $true } },
    @{ name = "history"; apply = { param($d) $d.immutable_prior_history[0].same_source_rerun_allowed = $true } },
    @{ name = "population"; apply = { param($d) $d.adequacy_argument.population_claim = $true } },
    @{ name = "physical_launch"; apply = { param($d) $d.adoption_boundary.physical_launch_authorized = $true } },
    @{ name = "movement_claim"; apply = { param($d) $d.claims.turning_acceptance = $true } },
    @{ name = "commissioning_claim"; apply = { param($d) $d.claims.campaign_local_attestation_implementation_commissioned = $false } }
)
$mutationRefusals = 0
foreach ($mutation in $mutations) {
    $copy = Copy-Lca1Rc5ClosureDocument $closure
    & $mutation.apply $copy
    $result = Test-Lca1Rc5ClosureDocument -Document $copy
    Assert-Lca1Rc5Closure (-not [bool]$result.ok) (
        "closure mutation was accepted: $($mutation.name)"
    )
    $mutationRefusals++
}

$authority = $closure.prospective_authority
foreach ($binding in @($authority.freeze, $authority.freeze_audit, $authority.manifest)) {
    $relative = [string]$binding.path
    Assert-Lca1Rc5Closure (
        (Get-Lca1Rc5ClosureGitBlobSha256 $relative) -ceq
            [string]$binding.raw_sha256 -and
        (Get-Lca1Rc5ClosureGitBlobLength $relative) -eq
            [long]$binding.byte_length
    ) "prospective source binding changed: $relative"
}
$auditPath = Join-Path $repoRoot ([string]$authority.closure_audit.path)
Assert-Lca1Rc5Closure (
    (Get-Lca1Rc5ClosureSha256 $auditPath) -ceq
        [string]$authority.closure_audit.raw_sha256 -and
    (Get-Item -LiteralPath $auditPath).Length -eq
        [long]$authority.closure_audit.byte_length
) "closure audit binding changed"

$full = $closure.full_v2
$scoped = $closure.scoped_lca1
Assert-Lca1Rc5ClosureArtifact $full.attestation
Assert-Lca1Rc5ClosureArtifact $full.run_receipt
Assert-Lca1Rc5ClosureArtifact $full.full_log
foreach ($stage in @($full.stage_receipts)) {
    Assert-Lca1Rc5ClosureArtifact $stage
}
Assert-Lca1Rc5ClosureArtifact $scoped.attestation

$fullReceipt = Read-Lca1Rc5ClosureJson ([string]$full.run_receipt.path)
$fullAttestation = Read-Lca1Rc5ClosureJson ([string]$full.attestation.path)
$scopedAttestation = Read-Lca1Rc5ClosureJson ([string]$scoped.attestation.path)
$source = $closure.commissioned_implementation_source
Assert-Lca1Rc5Closure (
    [string]$fullReceipt.status -ceq "passed" -and
    [string]$fullReceipt.tier -ceq "full_cold" -and
    -not [bool]$fullReceipt.skip_godot -and -not [bool]$fullReceipt.test_only -and
    [string]$fullReceipt.run_id -ceq [string]$full.run_id -and
    [string]$fullReceipt.source.head -ceq $sourceCommit -and
    [string]$fullReceipt.source.head_tree -ceq $sourceTree -and
    [string]$fullReceipt.source.origin_main -ceq $sourceCommit -and
    [string]$fullReceipt.source.remote_url -ceq [string]$source.remote_url -and
    [bool]$fullReceipt.source.worktree_clean -and
    $null -eq $fullReceipt.source.status_entries -and
    [string]$fullReceipt.started_utc -ceq [string]$full.run_receipt_started_utc -and
    [string]$fullReceipt.completed_utc -ceq [string]$full.run_receipt_completed_utc -and
    [double]$fullReceipt.duration_seconds -eq
        [double]$full.run_receipt_duration_seconds -and
    [string]$fullReceipt.cache.status -ceq "disabled_uncommissioned" -and
    -not [bool]$fullReceipt.cache.lookup_performed -and
    -not [bool]$fullReceipt.cache.result_reused -and
    -not [bool]$fullReceipt.source.transitive_dependency_key_complete -and
    -not [bool]$fullReceipt.source.cache_key_authority -and
    (Test-Lca1Rc5ClosureClaimVector `
        -Actual $fullReceipt.claims `
        -TrueKeys @($full.required_true_claim_keys) `
        -FalseKeys @($full.required_false_claim_keys))
) "full run receipt identity, cache, or claim vector changed"

Assert-Lca1Rc5Closure (
    [string]$fullAttestation.status -ceq "full_godot_conformance_passed" -and
    -not [bool]$fullAttestation.test_only -and
    [bool]$fullAttestation.conformance.passed -and
    [bool]$fullAttestation.conformance.godot_including -and
    -not [bool]$fullAttestation.conformance.one_shot_physical_campaign_executed -and
    [string]$fullAttestation.source.commit -ceq $sourceCommit -and
    [string]$fullAttestation.source.tree_git_oid -ceq $sourceTree -and
    [string]$fullAttestation.source.origin_main -ceq $sourceCommit -and
    [string]$fullAttestation.source.live_github_main -ceq $sourceCommit -and
    [bool]$fullAttestation.source.clean_pushed_live -and
    [string]$fullAttestation.conformance.started_utc -ceq
        [string]$full.attestation_started_utc -and
    [string]$fullAttestation.conformance.completed_utc -ceq
        [string]$full.attestation_completed_utc -and
    [double]$fullAttestation.conformance.duration_seconds -eq
        [double]$full.attestation_duration_seconds -and
    @($fullAttestation.claims.Values | Where-Object { [bool]$_ }).Count -eq 0 -and
    -not [bool]$fullAttestation.operation_lock.physical_acceptance_authority
) "full V2 attestation changed"

Assert-Lca1Rc5Closure (
    @($fullReceipt.stage_receipts).Count -eq 8 -and
    ((@($fullReceipt.stage_receipts.ordinal) -join ",") -ceq
        "1,2,3,4,5,6,7,8")
) "full stage receipt order changed"
$fullCasCount = 2
for ($index = 0; $index -lt 8; $index++) {
    $declared = @($full.stage_receipts)[$index]
    $observed = @($fullReceipt.stage_receipts)[$index]
    $stageReceipt = Read-Lca1Rc5ClosureJson ([string]$declared.path)
    Assert-Lca1Rc5Closure (
        [int]$observed.ordinal -eq [int]$declared.ordinal -and
        [string]$observed.stage_id -ceq [string]$declared.stage_id -and
        [string]$observed.status -ceq "passed" -and
        [int]$observed.exit_code -eq 0 -and
        [string]$observed.receipt_raw_sha256 -ceq
            [string]$declared.raw_sha256 -and
        [string]$stageReceipt.status -ceq "passed" -and
        [int]$stageReceipt.exit_code -eq 0 -and
        [string]$stageReceipt.run_id -ceq [string]$full.run_id -and
        [string]$stageReceipt.tier -ceq "full_cold" -and
        -not [bool]$stageReceipt.skip_godot -and
        -not [bool]$stageReceipt.transitive_dependency_key_complete -and
        [string]$stageReceipt.cache.status -ceq "disabled_uncommissioned" -and
        -not [bool]$stageReceipt.cache.lookup_performed -and
        -not [bool]$stageReceipt.cache.result_reused -and
        @($stageReceipt.claims.Values | Where-Object { [bool]$_ }).Count -eq 0
    ) "full stage changed: $($declared.stage_id)"
    $fullCasCount++
}
Assert-Lca1Rc5Closure (
    $fullCasCount -eq [int]$closure.independent_validation.full_required_cas_object_count
) "full required CAS count changed"

$fullText = Get-Content -LiteralPath ([string]$full.full_log.path) -Raw
foreach ($marker in @($closure.comparison.required_full_terminal_marker_counts.Keys)) {
    Assert-Lca1Rc5Closure (
        [regex]::Matches($fullText, [regex]::Escape([string]$marker)).Count -eq
            [int]$closure.comparison.required_full_terminal_marker_counts[$marker]
    ) "full transcript marker count changed: $marker"
}

Assert-Lca1Rc5Closure (
    [string]$scopedAttestation.status -ceq [string]$scoped.status -and
    -not [bool]$scopedAttestation.test_only -and
    [string]$scopedAttestation.campaign_id -ceq [string]$closure.program_id -and
    [string]$scopedAttestation.question_class -ceq
        [string]$closure.question_class -and
    [int]$scopedAttestation.declared_physical_world_count -eq 0 -and
    [string]$scopedAttestation.source.commit -ceq $sourceCommit -and
    [string]$scopedAttestation.source.tree_git_oid -ceq $sourceTree -and
    [string]$scopedAttestation.source.origin_main -ceq $sourceCommit -and
    [string]$scopedAttestation.source.live_github_main -ceq $sourceCommit -and
    [bool]$scopedAttestation.source.clean_pushed_live -and
    $null -eq $scopedAttestation.source.status_entries -and
    [string]$scopedAttestation.started_utc -ceq [string]$scoped.started_utc -and
    [string]$scopedAttestation.completed_utc -ceq [string]$scoped.completed_utc -and
    [double]$scopedAttestation.duration_seconds -eq [double]$scoped.duration_seconds -and
    [string]$scopedAttestation.candidate_inventory_sha256 -ceq
        [string]$scoped.candidate_inventory_sha256 -and
    [string]$scopedAttestation.global_kernel_inventory_sha256 -ceq
        [string]$scoped.global_kernel_inventory_sha256 -and
    [int]$scopedAttestation.global_gate_count -eq 12 -and
    [int]$scopedAttestation.lineage_gate_count -eq 1 -and
    [int]$scopedAttestation.campaign_gate_count -eq 3 -and
    [int]$scopedAttestation.executed_gate_count -eq 16 -and
    @($scopedAttestation.core_source_bindings).Count -eq 11 -and
    @($scopedAttestation.campaign_source_bindings).Count -eq 39 -and
    @($scopedAttestation.campaign_role_bindings).Count -eq 3 -and
    [bool]$scopedAttestation.all_gates_executed -and
    [bool]$scopedAttestation.all_gate_streams_content_addressed -and
    -not [bool]$scopedAttestation.commissioned -and
    (Test-Lca1Rc5ClosureClaimVector `
        -Actual $scopedAttestation.claims `
        -TrueKeys @($scoped.required_true_claim_keys) `
        -FalseKeys @($scoped.required_false_claim_keys))
) "scoped attestation identity, counts, or claims changed"

$expectedGateIds = @(
    "CAK1-REPOSITORY-AUTHORITY",
    "CAK1-REPRODUCIBLE-ARTIFACTS",
    "CAK1-OPERATION-LOCK",
    "CAK1-EVIDENCE-PROVENANCE",
    "CAK1-FULL-ATTESTATION",
    "CAK1-RESULT-INTEGRITY",
    "CAK1-PHYSICAL-ENTRYPOINT-INTEGRITY",
    "CAK1-PHYSICAL-RECEIPT-INTEGRITY",
    "CAK1-SHARED-ADAPTER-INVARIANTS",
    "CAK1-SHARED-ABI-INVARIANTS",
    "CAK1-LANGUAGE-BINDING-INVARIANTS",
    "CAK1-RELEASE-CLAIM-REFUSAL",
    "LCA1-RC5-R23D17-IMMUTABLE-LINEAGE",
    "LCA1-RC5-WORKER-ROLE",
    "LCA1-RC5-EVALUATOR-ROLE",
    "LCA1-RC5-SUPERVISOR-ROLE"
)
Assert-Lca1Rc5Closure (
    (@($scopedAttestation.gate_receipts.gate_id) -join "|") -ceq
        ($expectedGateIds -join "|") -and
    ((@($scopedAttestation.gate_receipts.ordinal) -join ",") -ceq
        "1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16")
) "scoped gate order changed"

$scopedCasReferences = [Collections.Generic.List[object]]::new()
$scopedStdout = [Collections.Generic.List[string]]::new()
foreach ($gate in @($scopedAttestation.gate_receipts)) {
    $requiresMarker = [string]$gate.role -cne "global_safety_kernel"
    Assert-Lca1Rc5Closure (
        [bool]$gate.passed -and -not [bool]$gate.timed_out -and
        [int]$gate.exit_code -eq 0 -and
        [int]$gate.physical_process_launch_count -eq 0 -and
        [int]$gate.physical_world_count -eq 0 -and
        -not [bool]$gate.physical_acceptance_authority -and
        [bool]$gate.terminal_marker_required -eq $requiresMarker -and
        [int]$gate.terminal_marker_count -eq $(if ($requiresMarker) { 1 } else { 0 })
    ) "scoped gate execution changed: $($gate.gate_id)"
    $scopedStdout.Add([IO.File]::ReadAllText([string]$gate.stdout_path))
    foreach ($kind in @("stdout", "stderr", "receipt")) {
        $cas = $gate[$kind + "_cas"]
        $path = [string]$gate[$kind + "_path"]
        $digest = ([string]$cas.sha256).Substring(7)
        Assert-Lca1Rc5Closure (
            (Get-Lca1Rc5ClosureSha256 $path) -ceq [string]$cas.sha256 -and
            (Get-Item -LiteralPath $path).Length -eq [long]$cas.byte_length -and
            (Test-SporeSporeStoredArtifact `
                -Directory (Split-Path -Parent ([string]$cas.payload_path)) `
                -ExpectedSha256 $digest `
                -ExpectedByteLength ([long]$cas.byte_length))
        ) "scoped gate CAS changed: $($gate.gate_id)/$kind"
        $scopedCasReferences.Add($cas)
    }
}
$uniqueScopedCas = @($scopedCasReferences.sha256 | Sort-Object -Unique)
Assert-Lca1Rc5Closure (
    $scopedCasReferences.Count -eq [int]$scoped.gate_cas_reference_count -and
    $uniqueScopedCas.Count -eq [int]$scoped.gate_cas_unique_object_count
) "scoped gate CAS cardinality changed"

$scopedText = @($scopedStdout) -join "`n"
foreach ($marker in @($closure.comparison.required_scoped_terminal_marker_counts.Keys)) {
    Assert-Lca1Rc5Closure (
        [regex]::Matches($scopedText, [regex]::Escape([string]$marker)).Count -eq
            [int]$closure.comparison.required_scoped_terminal_marker_counts[$marker]
    ) "scoped transcript marker count changed: $marker"
}

foreach ($binding in @($scopedAttestation.core_source_bindings) +
    @($scopedAttestation.campaign_source_bindings)) {
    $relative = [string]$binding.path
    Assert-Lca1Rc5Closure (
        [string]$binding.raw_sha256 -ceq [string]$binding.git_blob_raw_sha256 -and
        (Get-Lca1Rc5ClosureGitBlobSha256 $relative) -ceq
            [string]$binding.git_blob_raw_sha256 -and
        (Get-Lca1Rc5ClosureGitBlobOid $relative) -ceq
            [string]$binding.git_blob_oid
    ) "scoped source Git blob changed: $relative"
}

$manifestPath = Join-Path $repoRoot ([string]$authority.manifest.path)
$manifest = Read-Lca1Rc5ClosureJson $manifestPath
$manifestBindings = @{}
foreach ($binding in @($manifest.source_bindings)) {
    $manifestBindings[[string]$binding.path] = [string]$binding.raw_sha256
}
Assert-Lca1Rc5Closure (
    $manifestBindings.Count -eq 39 -and
    @($scopedAttestation.campaign_source_bindings).Count -eq 39
) "frozen campaign binding count changed"
foreach ($binding in @($scopedAttestation.campaign_source_bindings)) {
    Assert-Lca1Rc5Closure (
        $manifestBindings.ContainsKey([string]$binding.path) -and
        [string]$manifestBindings[[string]$binding.path] -ceq
            [string]$binding.raw_sha256
    ) "scoped binding differs from frozen manifest: $($binding.path)"
}

$sharedRuntimePairs = @(
    @($fullReceipt.toolchain_runtime_identity.godot, $scopedAttestation.runtime.godot),
    @($fullReceipt.toolchain_runtime_identity.powershell, $scopedAttestation.runtime.powershell),
    @($fullReceipt.toolchain_runtime_identity.python, $scopedAttestation.runtime.python),
    @($fullReceipt.toolchain_runtime_identity.cargo, $scopedAttestation.runtime.cargo),
    @($fullReceipt.toolchain_runtime_identity.rustc, $scopedAttestation.runtime.rustc)
)
foreach ($pair in $sharedRuntimePairs) {
    Assert-Lca1Rc5Closure (
        [string]$pair[0].executable_path -ceq [string]$pair[1].executable_path -and
        [string]$pair[0].executable_sha256 -ceq [string]$pair[1].executable_sha256 -and
        [string]$pair[0].version -ceq [string]$pair[1].version
    ) "full/scoped runtime identity diverged"
}
Assert-Lca1Rc5Closure (
    [string]$fullReceipt.toolchain_runtime_identity.operating_system -ceq
        [string]$scopedAttestation.runtime.host.os_description -and
    [string]$fullReceipt.toolchain_runtime_identity.process_architecture -ceq
        [string]$scopedAttestation.runtime.host.process_architecture -and
    [string]$scopedAttestation.runtime.host.framework_description -ceq
        ".NET 10.0.10"
) "full/scoped host identity diverged"

$fullCompleted = [datetime]$full.run_receipt_completed_utc
$scopedStarted = [datetime]$scoped.started_utc
$gap = ($scopedStarted - $fullCompleted).TotalSeconds
$scopedOverFull = [double]$scoped.duration_seconds /
    [double]$full.run_receipt_duration_seconds
$fullOverScoped = [double]$full.run_receipt_duration_seconds /
    [double]$scoped.duration_seconds
Assert-Lca1Rc5Closure (
    $scopedStarted -gt $fullCompleted -and
    $gap -eq [double]$closure.comparison.
        full_receipt_completion_to_scoped_start_seconds -and
    [Math]::Abs($scopedOverFull - [double]$closure.comparison.
        scoped_over_full_receipt_duration_ratio) -lt 1e-15 -and
    [Math]::Abs($fullOverScoped - [double]$closure.comparison.
        full_receipt_over_scoped_duration_ratio) -lt 1e-12
) "serialization or descriptive duration calculation changed"

foreach ($incident in @($closure.immutable_prior_history)) {
    $path = Join-Path $repoRoot ([string]$incident.path)
    $document = Read-Lca1Rc5ClosureJson $path
    Assert-Lca1Rc5Closure (
        (Get-Lca1Rc5ClosureSha256 $path) -ceq [string]$incident.raw_sha256 -and
        (Get-Item -LiteralPath $path).Length -eq [long]$incident.byte_length -and
        [string]$document.status -ceq [string]$incident.status -and
        -not [bool]$incident.same_source_rerun_allowed
    ) "immutable prior result changed: $($incident.campaign)"
}

Write-Host (
    "LCA1_RC5_CLOSURE_PASS source=$sourceCommit full_stages=8 " +
    "full_seconds=$($full.run_receipt_duration_seconds) scoped_gates=16 " +
    "scoped_seconds=$($scoped.duration_seconds) full_cas=$fullCasCount " +
    "scoped_cas_refs=$($scopedCasReferences.Count) " +
    "scoped_cas_unique=$($uniqueScopedCas.Count) markers=5+4 " +
    "mutations=$mutationRefusals incidents=3 worlds=0 " +
    "implementation_commissioned=True r23d54_prerequisite=False " +
    "turning=False prone_to_stand=False physical_authority=False " +
    "release_authority=False"
)

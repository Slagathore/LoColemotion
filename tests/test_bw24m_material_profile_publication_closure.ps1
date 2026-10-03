#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot "..")
)
$sdkRoot = Join-Path $repoRoot "sdk"
$evidenceBase = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$campaignId = "BW24M-BW23Y-FRESH-MATERIAL-PROFILE-PUBLICATION"
$gateId = "BW24M-PROFILE"
$sourceCommit = "f9adde8caf0f159858f4819b02de1d5daff87f77"
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw24m_material_profile_publication_closure.json"
$expectedClosureSha256 =
    "f2921cb510b8283316f7c00bef4ff17492806f5d671c459efdde87b4a79eb0f0"
$supervisorPath = Join-Path (
    $sdkRoot
) "run_balanced_wave_bw24m_material_profile_publication.ps1"
$runnerPath = Join-Path (
    $sdkRoot
) "run_godot_jolt_bw24m_material_profile_conformance.ps1"
$characterizationClosureAuditPath = Join-Path (
    $PSScriptRoot
) "test_bw24m_material_characterization_closure.ps1"
$priorProfileClosureAuditPath = Join-Path (
    $PSScriptRoot
) "test_bw22m_material_profile_publication_closure.ps1"
$expectedProfileIds = @(
    "godot_jolt_bw24m_mu059_v1",
    "godot_jolt_bw24m_mu071_v1",
    "godot_jolt_bw24m_mu083_v1"
)
$expectedProfileSha256 = @(
    "sha256:2d8a2571c129dbe7b2b894bae1aa28f5650fdbea27fcb65a149566c54a536173",
    "sha256:a8efdd111b740391931219d720079beffeea8181e5c46fd00ea7acb6108ab8ee",
    "sha256:e5916d9e17f87120e5cc04ff03e8688c4dea3919715a68854a8dce29e4d9c2a0"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Get-GitBlobText {
    param(
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$Path
    )
    $lines = @(& git -C $repoRoot show "${Commit}:$Path")
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "$gateId could not reconstruct frozen source text: $Path"
    return ($lines -join "`n")
}

function Invoke-ExpectedFailure {
    param(
        [Parameter(Mandatory)][scriptblock]$Action,
        [Parameter(Mandatory)][string]$Needle,
        [Parameter(Mandatory)][string]$Label
    )
    $output = @(& $Action 2>&1 | ForEach-Object { $_.ToString() })
    $exitCode = $LASTEXITCODE
    Assert-Exact (
        $exitCode -ne 0 -and
        ($output -join [Environment]::NewLine).Contains($Needle)
    ) "$gateId $Label did not fail closed with '$Needle'"
}

Assert-Exact (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-RawSha256 -Path $closurePath) -ceq $expectedClosureSha256
) "$gateId closure is missing or changed"
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable
Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_balanced_wave_bw24m_material_profile_publication_closure_v1" -and
    [string]$closure.status -ceq
        "closed_incomplete_invalid_publication_attempt_contract_mismatch" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.study_classification -ceq
        "deterministic_zero_world_adapter_profile_publication" -and
    [string]$closure.publication_source_commit -ceq $sourceCommit -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.profile_record_or_retained_evidence_rewrite_allowed
) "$gateId closure identity or immutability changed"

$lifecycle = $closure.publication_lifecycle
Assert-Exact (
    [bool]$lifecycle.complete_pre_attempt_zero_world_gate_passed -and
    [int]$lifecycle.pre_attempt_profile_count -eq 35 -and
    [int]$lifecycle.pre_attempt_adapter_start_count -eq 36 -and
    [int]$lifecycle.pre_attempt_passed_gate_count -eq 46 -and
    [int]$lifecycle.pre_attempt_failed_gate_count -eq 0 -and
    [int]$lifecycle.identity_consuming_attempt_count -eq 1 -and
    [int]$lifecycle.duplicate_pre_attempt_refusal_count -eq 1 -and
    [bool]$lifecycle.retained_worker_zero_world_gate_passed -and
    [int]$lifecycle.retained_worker_profile_count -eq 35 -and
    [int]$lifecycle.retained_worker_adapter_start_count -eq 36 -and
    [int]$lifecycle.retained_worker_passed_gate_count -eq 46 -and
    [int]$lifecycle.retained_worker_failed_gate_count -eq 0 -and
    [int]$lifecycle.attempt_declared_profile_count -eq 32 -and
    [int]$lifecycle.attempt_declared_gate_count -eq 43 -and
    [int]$lifecycle.publication_contract_required_profile_count -eq 35 -and
    [int]$lifecycle.publication_contract_required_gate_count -eq 46 -and
    -not [bool]$lifecycle.retained_report_created -and
    -not [bool]$lifecycle.completion_receipt_created -and
    [int]$lifecycle.world_build_count -eq 0 -and
    [int]$lifecycle.sample_count -eq 0 -and
    [int]$lifecycle.command_count -eq 0 -and
    [int]$lifecycle.locomotion_seed_world_count -eq 0
) "$gateId publication lifecycle changed"

$failure = $closure.failure_analysis
Assert-Exact (
    [string]$failure.failure_class -ceq
        "publication_supervisor_attempt_cardinality_defect" -and
    [string]$failure.causal_source -ceq
        "sdk/run_balanced_wave_bw24m_material_profile_publication.ps1" -and
    [int]$failure.supervisor_wrote_inherited_predecessor_profile_count -eq 32 -and
    [int]$failure.supervisor_wrote_inherited_predecessor_gate_count -eq 43 -and
    [int]$failure.publication_runner_correctly_required_profile_count -eq 35 -and
    [int]$failure.publication_runner_correctly_required_gate_count -eq 46 -and
    -not [bool]$failure.worker_profile_conformance_failed -and
    -not [bool]$failure.profile_payload_changed_in_response_to_result -and
    -not [bool]$failure.physical_or_locomotion_outcome_observed
) "$gateId failure analysis changed"

$duplicate = $closure.duplicate_launch_refusal
Assert-Exact (
    [string]$duplicate.stage_reached -ceq
        "complete_zero_world_preflight_then_existing_output_root_refusal" -and
    [bool]$duplicate.existing_attempt_observed -and
    -not [bool]$duplicate.new_attempt_created -and
    -not [bool]$duplicate.publication_identity_consumed_by_duplicate -and
    [int]$duplicate.world_build_count -eq 0 -and
    -not [bool]$duplicate.scientific_result_created
) "$gateId duplicate-launch refusal changed"

Assert-Exact (
    $closure.frozen_source_blobs.Count -eq 14
) "$gateId frozen source binding count changed"
foreach ($binding in @($closure.frozen_source_blobs.Values)) {
    $relativePath = ([string]$binding.path).Replace([char]92, [char]47)
    $blobOid = (& git -C $repoRoot rev-parse (
        "${sourceCommit}:$relativePath"
    )).Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        $blobOid -ceq [string]$binding.git_blob_oid -and
        [string]$binding.raw_sha256 -cmatch "^[0-9a-f]{64}$"
    ) "$gateId source-commit blob changed: $($binding.path)"
}

$evidenceRoot = [System.IO.Path]::GetFullPath(
    [string]$closure.retained_evidence.root
)
Assert-Exact (
    $evidenceRoot.StartsWith(
        $evidenceBase.TrimEnd("\") + "\",
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    (Test-Path -LiteralPath $evidenceRoot -PathType Container)
) "$gateId retained evidence root is invalid"
$evidenceFiles = @(
    Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File
)
Assert-Exact (
    $evidenceFiles.Count -eq 7
) "$gateId retained evidence tree cardinality changed"
foreach ($binding in @($closure.retained_evidence.Values)) {
    if ($binding -is [string]) {
        continue
    }
    $path = Join-Path $evidenceRoot ([string]$binding.path)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$binding.byte_length -and
        (Get-RawSha256 -Path $path) -ceq [string]$binding.raw_sha256
    ) "$gateId retained evidence changed: $($binding.path)"
}

$attemptPath = Join-Path $evidenceRoot "attempt.json"
$attempt = Get-Content -Raw -LiteralPath $attemptPath |
    ConvertFrom-Json -AsHashtable
Assert-Exact (
    [string]$attempt.schema_version -ceq
        "sporespore_balanced_wave_bw24m_material_profile_publication_attempt_v1" -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [string]$attempt.source_commit -ceq $sourceCommit -and
    [string]$attempt.origin_main_commit -ceq $sourceCommit -and
    [string]$attempt.remote_main_commit -ceq $sourceCommit -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [string]$attempt.godot_version -ceq
        "4.7.stable.mono.official.5b4e0cb0f" -and
    [string]$attempt.godot_executable_sha256 -ceq
        "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896" -and
    [bool]$attempt.complete_zero_world_gate_passed -and
    [int]$attempt.expected_profile_count -eq 32 -and
    [int]$attempt.expected_gate_count -eq 43 -and
    [int]$attempt.expected_world_count -eq 0 -and
    [int]$attempt.expected_sample_count -eq 0 -and
    [int]$attempt.expected_command_count -eq 0 -and
    [int]$attempt.locomotion_seed_world_count -eq 0 -and
    [bool]$attempt.publication_identity_consumed -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    -not [bool]$attempt.physical_acceptance_authority
) "$gateId malformed retained attempt changed"
Assert-Exact (
    -not (Test-Path -LiteralPath (Join-Path $evidenceRoot "report.json")) -and
    -not (Test-Path -LiteralPath (Join-Path $evidenceRoot "completion.json"))
) "$gateId incomplete attempt unexpectedly gained a report or completion receipt"

$transcriptPath = Join-Path (
    $evidenceRoot
) "worker/20260802T004945374/transcript.log"
$receiptLines = @(
    Get-Content -LiteralPath $transcriptPath |
        Where-Object { $_.StartsWith("SDK_MATERIAL_PROFILE_RECEIPT ") }
)
Assert-Exact (
    $receiptLines.Count -eq 1
) "$gateId retained worker receipt count changed"
$receipt = $receiptLines[0].Substring(
    "SDK_MATERIAL_PROFILE_RECEIPT ".Length
) | ConvertFrom-Json -AsHashtable
Assert-Exact (
    [string]$receipt.schema_version -ceq
        "sporespore_godot_jolt_material_profile_receipt_v1" -and
    [bool]$receipt.ok -and
    [int]$receipt.expected_profile_count -eq 35 -and
    [int]$receipt.observed_profile_count -eq 35 -and
    [int]$receipt.expected_adapter_start_count -eq 36 -and
    [int]$receipt.observed_adapter_start_count -eq 36 -and
    [int]$receipt.expected_gate_count -eq 46 -and
    [int]$receipt.passed_gate_count -eq 46 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.observed_world_count -eq 0 -and
    [int]$receipt.observed_sample_count -eq 0 -and
    [int]$receipt.observed_command_count -eq 0 -and
    (@($receipt.profile_ids | Select-Object -Last 3) -join "|") -ceq
        ($expectedProfileIds -join "|") -and
    (@($receipt.profile_sha256 | Select-Object -Last 3) -join "|") -ceq
        ($expectedProfileSha256 -join "|") -and
    [bool]$receipt.bw24m_fresh_material_profile_publication -and
    -not [bool]$receipt.walking -and
    -not [bool]$receipt.material_robustness -and
    -not [bool]$receipt.physical_acceptance_authority
) "$gateId retained worker receipt changed"

$supervisorText = Get-GitBlobText -Commit $sourceCommit `
    -Path "sdk/run_balanced_wave_bw24m_material_profile_publication.ps1"
$runnerText = Get-GitBlobText -Commit $sourceCommit `
    -Path "sdk/run_godot_jolt_bw24m_material_profile_conformance.ps1"
Assert-Exact (
    $supervisorText.Contains('expected_profile_count = 32') -and
    $supervisorText.Contains('expected_gate_count = 43') -and
    $runnerText.Contains('[int]$attempt.expected_profile_count -eq 35') -and
    $runnerText.Contains('[int]$attempt.expected_gate_count -eq 46')
) "$gateId causal source mismatch is no longer reconstructable"

$result = $closure.result
$disposition = $closure.scientific_disposition
$immutability = $closure.immutability
$next = $closure.next_allowed_work
Assert-Exact (
    -not [bool]$result.accepted -and
    [string]$result.result_status -ceq
        "incomplete_invalid_publication_attempt_contract" -and
    [bool]$result.worker_zero_world_conformance_passed -and
    [int]$result.worker_observed_profile_count -eq 35 -and
    [int]$result.worker_observed_adapter_start_count -eq 36 -and
    [int]$result.worker_passed_gate_count -eq 46 -and
    [int]$result.worker_failed_gate_count -eq 0 -and
    -not [bool]$result.profile_published -and
    [int]$result.world_build_count -eq 0 -and
    -not [bool]$disposition.complete_valid_positive_deterministic_zero_world_profile_publication -and
    -not [bool]$disposition.complete_valid_negative_profile_payload_result -and
    [bool]$disposition.infrastructure_contract_defect_established -and
    [bool]$disposition.exact_profile_payload_zero_world_conformance_observed -and
    -not [bool]$disposition.profile_published -and
    -not [bool]$disposition.bw25y_manifest_freeze_authorized -and
    -not [bool]$disposition.future_locomotion_seeds_opened -and
    -not [bool]$disposition.walking_acceptance -and
    -not [bool]$disposition.friction_or_material_locomotion_robustness -and
    -not [bool]$disposition.cross_engine_equivalence -and
    -not [bool]$disposition.physical_acceptance_authority -and
    [bool]$immutability.attempt_and_partial_logs_may_not_be_rewritten -and
    [bool]$immutability.same_campaign_identity_may_not_publish_again -and
    [bool]$immutability.malformed_attempt_may_not_be_repaired_in_place -and
    [bool]$next.bw24m_profile_publication_is_closed_incomplete -and
    [bool]$next.scientifically_distinct_zero_world_publication_successor_required -and
    [bool]$next.successor_requires_new_campaign_gate_source_preregistration_and_evidence_identity -and
    [bool]$next.successor_may_reuse_exact_unchanged_profile_payloads -and
    [bool]$next.successor_must_preflight_the_real_attempt_authorization_contract -and
    (@($next.sealed_future_locomotion_seeds) -join ",") -ceq
        "26011,26012,26013,26014" -and
    [bool]$next.bw25y_manifest_remains_blocked_until_successor_profile_publication_closes_positive -and
    [int]$next.bw25y_expected_world_count -eq 28 -and
    [bool]$next.release_not_authorized
) "$gateId result, claim boundary, or next-work contract changed"

$attemptFiles = @(
    Get-ChildItem -LiteralPath $evidenceBase -Recurse -File -Filter "attempt.json" |
        Where-Object {
            try {
                $candidate = Get-Content -Raw -LiteralPath $_.FullName |
                    ConvertFrom-Json
                [string]$candidate.campaign_id -ceq $campaignId
            } catch {
                $false
            }
        }
)
Assert-Exact (
    $attemptFiles.Count -eq 1 -and
    [System.IO.Path]::GetFullPath($attemptFiles[0].FullName) -ceq $attemptPath
) "$gateId must retain exactly one identity-consuming publication attempt"

& pwsh -NoProfile -File $characterizationClosureAuditPath
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId characterization closure audit failed"
& pwsh -NoProfile -File $priorProfileClosureAuditPath
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId prior profile closure audit failed"

$canaryRoot = Join-Path $evidenceBase (
    "bw24m-profile-closed-canary-" + [Guid]::NewGuid().ToString("N")
)
try {
    Invoke-ExpectedFailure -Label "closed-state rerun canary" `
        -Needle "$gateId publication is already closed and may not rerun" `
        -Action {
            & pwsh -NoProfile -File $supervisorPath `
                -Publish `
                -OutputRoot $canaryRoot
        }
    Assert-Exact (
        -not (Test-Path -LiteralPath $canaryRoot)
    ) "$gateId closed-state canary unexpectedly created an evidence root"
} finally {
    if (Test-Path -LiteralPath $canaryRoot) {
        throw "$gateId closed-state canary left an unexpected artifact root"
    }
}

Write-Host (
    "BW24M_PROFILE_CLOSURE_PASS status=incomplete_invalid_contract " +
    "worker_profiles=35 worker_gates=46 attempt_profiles=32 " +
    "attempt_gates=43 worlds=0 report=False completion=False " +
    "duplicate_refusal=True rerun_refused=True profile_published=False " +
    "bw25y_blocked=True physical_authority=False"
)

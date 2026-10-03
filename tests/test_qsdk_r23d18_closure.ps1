#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "r23d18-physical-20260812-c5f1862"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot "turning\r23d18_physical_closure_v1.json"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d18_supervisor.ps1"
$campaignId = "QSDK-R23D18-RECEIPT-INTEGRITY-RECOVERY-THREE-ENGINE-TURN-CONFIRMATION"
$gateId = "QSDK-R23D18"
$sourceCommit = "c5f1862a96a92b294b4eda0a3bde2674cc8d24ea"
$sourceTree = "8b326733657a502f8df49941a046608be2bebb35"
$attemptId = "f0a4e6ee44314354ab5a415773ffd2c4"

. $artifactStorePath

function Assert-R23D18Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D18 closure: $Message" }
}

function Get-R23D18ClosureSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D18ClosureBytesSha256([byte[]]$Bytes) {
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D18ClosureGitBlobSha256([string]$RelativePath) {
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
        Assert-R23D18Closure $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream) }
        finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D18Closure ($process.ExitCode -eq 0) (
            "Git blob read failed for $RelativePath`: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Test-R23D18ClosureCas([string]$Sha256, [long]$ByteLength) {
    $artifactRoot = Join-Path (
        Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
    ) "artifacts\sha256"
    $digest = $Sha256.Substring(7)
    return Test-SporeSporeStoredArtifact `
        -Directory (Join-Path $artifactRoot $digest) `
        -ExpectedSha256 $digest `
        -ExpectedByteLength $ByteLength
}

function Assert-R23D18ClosureFile(
    [string]$Path,
    [string]$ExpectedSha256,
    [string]$Label
) {
    Assert-R23D18Closure (Test-Path -LiteralPath $Path -PathType Leaf) (
        "retained file is missing: $Label"
    )
    $item = Get-Item -LiteralPath $Path
    Assert-R23D18Closure (
        (Get-R23D18ClosureSha256 $Path) -ceq $ExpectedSha256 -and
        (Test-R23D18ClosureCas $ExpectedSha256 ([long]$item.Length))
    ) "retained bytes or CAS changed: $Label"
}

Assert-R23D18Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (git -C $repoRoot rev-parse ($sourceCommit + "^{tree}")) -ceq $sourceTree
) "repository or frozen source identity changed"
Assert-R23D18Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) `
    "closure is missing"
Assert-R23D18Closure (Test-Path -LiteralPath $EvidenceRoot -PathType Container) `
    "retained attempt root is missing"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D18Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d18_physical_confirmation_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_valid_complete_negative_one_godot_signed_yaw_failure_three_rapier_outcome_failures_three_mujoco_positives" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.source_identity.commit -ceq $sourceCommit -and
    [string]$closure.source_identity.tree_git_oid -ceq $sourceTree -and
    [int]$closure.source_identity.declared_source_binding_count -eq 132 -and
    [int]$closure.source_identity.declared_worker_dependency_count -eq 77 -and
    -not [bool]$closure.source_identity.controller_or_physics_changed_by_closure
) "closure identity changed"

$files = @(Get-ChildItem -LiteralPath $EvidenceRoot -File -Recurse | Sort-Object {
    $_.FullName.Substring($EvidenceRoot.Length + 1).Replace("\", "/")
})
$lines = @($files | ForEach-Object {
    $relative = $_.FullName.Substring($EvidenceRoot.Length + 1).Replace("\", "/")
    "{0}`t{1}`t{2}" -f $relative, $_.Length, (
        Get-R23D18ClosureSha256 $_.FullName
    ).Substring(7)
})
$treeBytes = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n") + "`n")
$treeSha256 = Get-R23D18ClosureBytesSha256 $treeBytes
$totalBytes = [int64](($files | Measure-Object Length -Sum).Sum)
Assert-R23D18Closure (
    $files.Count -eq 66 -and
    $files.Count -eq [int]$closure.attempt.evidence_file_count -and
    $totalBytes -eq 161070137 -and
    $totalBytes -eq [int64]$closure.attempt.evidence_total_byte_length -and
    $treeSha256 -ceq [string]$closure.attempt.evidence_tree_raw_sha256
) "retained evidence tree changed"
foreach ($file in $files) {
    $sha256 = Get-R23D18ClosureSha256 $file.FullName
    Assert-R23D18Closure (
        Test-R23D18ClosureCas $sha256 ([long]$file.Length)
    ) "attempt file is absent from CAS: $($file.FullName)"
}

$qualification = $closure.campaign_local_qualification
Assert-R23D18ClosureFile `
    ([string]$qualification.scoped_attestation_path) `
    ([string]$qualification.scoped_attestation_raw_sha256) `
    "scoped campaign attestation"
Assert-R23D18ClosureFile `
    ([string]$qualification.adoption_path) `
    ([string]$qualification.adoption_raw_sha256) `
    "campaign adoption"
$scoped = Get-Content -Raw -LiteralPath ([string]$qualification.scoped_attestation_path) |
    ConvertFrom-Json -AsHashtable -Depth 100
$adoption = Get-Content -Raw -LiteralPath ([string]$qualification.adoption_path) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D18Closure (
    [string]$scoped.source.commit -ceq $sourceCommit -and
    [int]$scoped.global_gate_count -eq 12 -and
    [int]$scoped.lineage_gate_count -eq 1 -and
    [int]$scoped.campaign_gate_count -eq 3 -and
    [int]$scoped.executed_gate_count -eq 16 -and
    @($scoped.gate_receipts).Count -eq 16 -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [string]$adoption.scoped_attestation_raw_sha256 -ceq
        [string]$qualification.scoped_attestation_raw_sha256 -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority -and
    -not [bool]$adoption.release_authority
) "campaign qualification or adoption changed"

$expectedAttemptFiles = [ordered]@{
    "physical-freeze.json" = [string]$closure.attempt.physical_freeze_raw_sha256
    "matrix-authorization.json" = [string]$closure.attempt.matrix_authorization_raw_sha256
    "matrix-terminal-paths.json" = [string]$closure.attempt.matrix_terminal_paths_raw_sha256
    "report.json" = [string]$closure.attempt.report_raw_sha256
    "completion.json" = [string]$closure.attempt.completion_raw_sha256
    "complete-evaluator/evaluation.json" = [string]$closure.attempt.complete_evaluation_raw_sha256
}
foreach ($relative in $expectedAttemptFiles.Keys) {
    Assert-R23D18ClosureFile `
        (Join-Path $EvidenceRoot $relative) `
        ([string]$expectedAttemptFiles[$relative]) `
        $relative
}

$freeze = Get-Content -Raw -LiteralPath (Join-Path $EvidenceRoot "physical-freeze.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$authorization = Get-Content -Raw -LiteralPath (
    Join-Path $EvidenceRoot "matrix-authorization.json"
) | ConvertFrom-Json -AsHashtable -Depth 100
$completion = Get-Content -Raw -LiteralPath (Join-Path $EvidenceRoot "completion.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$report = Get-Content -Raw -LiteralPath (Join-Path $EvidenceRoot "report.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$evaluation = Get-Content -Raw -LiteralPath (
    Join-Path $EvidenceRoot "complete-evaluator\evaluation.json"
) | ConvertFrom-Json -AsHashtable -Depth 100

$sourceBindings = @($freeze.source_bindings)
$sourceReceipts = @($freeze.content_addressed_inputs.source_bindings)
Assert-R23D18Closure (
    $sourceBindings.Count -eq 132 -and
    $sourceReceipts.Count -eq 132 -and
    @($sourceBindings.path | Sort-Object -Unique).Count -eq 132
) "frozen source-binding inventory changed"
for ($index = 0; $index -lt $sourceBindings.Count; $index++) {
    $binding = $sourceBindings[$index]
    $receipt = $sourceReceipts[$index]
    Assert-R23D18Closure (
        [string]$receipt.payload_path -like "*\artifacts\sha256\*\payload.bin"
    ) "source receipt shape changed at index $index"
    $gitBlobSha256 = Get-R23D18ClosureGitBlobSha256 ([string]$binding.path)
    Assert-R23D18Closure (
        [string]$binding.raw_sha256 -ceq $gitBlobSha256 -and
        [string]$receipt.sha256 -ceq $gitBlobSha256 -and
        (Test-R23D18ClosureCas ([string]$receipt.sha256) ([long]$receipt.byte_length))
    ) "frozen source binding changed: $($binding.path)"
}

$canaries = $freeze.production_authorization_canaries
Assert-R23D18Closure (
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$authorization.source_commit -ceq $sourceCommit -and
    [string]$authorization.attempt_id -ceq $attemptId -and
    [string]$freeze.campaign_attestation_adoption_sha256 -ceq
        [string]$qualification.adoption_raw_sha256 -and
    [int]$canaries.engine_count -eq 3 -and
    [int]$canaries.worker_process_launch_count -eq 6 -and
    [int]$canaries.positive_authorization_canary_count -eq 3 -and
    [int]$canaries.mutated_binding_refusal_canary_count -eq 3 -and
    [int]$canaries.content_addressed_input_count -eq 77 -and
    [int]$canaries.world_build_count -eq 0
) "physical freeze, authorization, or production canaries changed"

Assert-R23D18Closure (
    [string]$completion.status -ceq "valid_complete_negative_first_attempt" -and
    [string]$completion.result_classification -ceq "valid_complete_negative" -and
    [int]$completion.matrix_terminal_entry_count -eq 9 -and
    [bool]$completion.one_shot_identity_consumed -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    [string]$report.result_classification -ceq "valid_complete_negative" -and
    [bool]$report.finite_matrix_result_valid -and
    @($report.ordered_matrix_cells).Count -eq 9 -and
    [string]$evaluation.classification -ceq "valid_complete_negative" -and
    [bool]$evaluation.matrix_valid -and
    [int]$evaluation.outcome_failure_count -eq 4 -and
    @($evaluation.cell_evaluations).Count -eq 9 -and
    [int]$evaluation.world_attempt_count -eq 9 -and
    [int]$evaluation.world_build_count -eq 9 -and
    @($evaluation.failure_codes).Count -eq 0
) "completion or complete evaluation changed"

$expectedCells = [ordered]@{
    "godot_jolt__tight_gated_horizon__reference_zero" = @(-0.118800280009468, $true, @())
    "godot_jolt__tight_gated_horizon__positive_heading" = @(-0.107375230994726, $false, @("R23D18_SIGNED_YAW_RESPONSE"))
    "godot_jolt__tight_gated_horizon__negative_heading" = @(-0.0517322445148429, $true, @())
    "rapier_parry__tight_gated_horizon__reference_zero" = @(0.00943962730442927, $false, @("R23D18_QUIESCENT_TAPER"))
    "rapier_parry__tight_gated_horizon__positive_heading" = @(0.0236917275559643, $false, @("R23D18_QUIESCENT_TAPER"))
    "rapier_parry__tight_gated_horizon__negative_heading" = @(-2.61300510841816, $false, @("R23D18_MAXIMUM_TILT", "R23D18_MINIMUM_TORSO_HEIGHT", "R23D18_CONTACT_CYCLES:front_left", "R23D18_CONTACT_CYCLES:front_right", "R23D18_TORSO_GROUND_CONTACT", "R23D18_QUIESCENT_TAPER"))
    "mujoco__tight_gated_horizon__reference_zero" = @(-0.0234130469516889, $true, @())
    "mujoco__tight_gated_horizon__positive_heading" = @(0.0842283890494393, $true, @())
    "mujoco__tight_gated_horizon__negative_heading" = @(-0.152579124360836, $true, @())
}
foreach ($cellId in $expectedCells.Keys) {
    $actual = @($evaluation.cell_evaluations | Where-Object {
        [string]$_.cell_id -ceq $cellId
    })
    $expected = $expectedCells[$cellId]
    Assert-R23D18Closure ($actual.Count -eq 1) "cell evaluation missing: $cellId"
    $entry = $actual[0]
    Assert-R23D18Closure (
        [bool]$entry.entry_valid -and
        [bool]$entry.execution_integrity_passed -and
        [Math]::Abs(
            [double]$entry.outcome.turn_phase_yaw_delta_rad - [double]$expected[0]
        ) -lt 1e-12 -and
        [bool]$entry.outcome.outcome_gate_passed -eq [bool]$expected[1] -and
        (@($entry.outcome.failed_gate_ids) -join "|") -ceq
            (@($expected[2]) -join "|") -and
        [int]$entry.world_attempt_count -eq 1 -and
        [int]$entry.world_build_count -eq 1
    ) "cell outcome changed: $cellId"
    $terminal = @($report.ordered_matrix_cells | Where-Object {
        [string]$_.cell_id -ceq $cellId
    })[0].terminal_marker_classification.terminal_entry
    Assert-R23D18Closure (
        [bool]$terminal.execution.integrity_passed -and
        [int]$terminal.trace_summary.row_count -eq 3952 -and
        [string]$terminal.trace_artifact.sha256 -ceq
            [string]$terminal.trace_summary.raw_sha256 -and
        (Test-R23D18ClosureCas `
            ([string]$terminal.trace_artifact.sha256) `
            ([long]$terminal.trace_artifact.byte_length))
    ) "cell trace changed: $cellId"
}

Assert-R23D18Closure (
    [bool]$closure.scientific_observation_boundary.godot_receipt_integrity_recovery_confirmed -and
    [string]$closure.scientific_observation_boundary.complete_matrix_scientific_result -ceq
        "valid_complete_finite_negative" -and
    [bool]$closure.claims.finite_complete_three_engine_execution_validity -and
    [bool]$closure.claims.scientific_negative -and
    -not [bool]$closure.claims.scientific_positive -and
    -not [bool]$closure.claims.finite_three_engine_turning -and
    -not [bool]$closure.claims.command_conditioned_turning -and
    -not [bool]$closure.claims.bilateral_signed_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.prone_to_standing -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "scientific or claim boundary changed"

$refusal = @(& pwsh -NoLogo -NoProfile -File $supervisorPath -RunPhysical *>&1)
$refusalExit = $LASTEXITCODE
Assert-R23D18Closure (
    $refusalExit -ne 0 -and
    @($refusal | Where-Object {
        ([string]$_).StartsWith("QSDK_R23D18_PHYSICAL_REFUSAL ") -and
        ([string]$_).Contains('"reason":"r23d18_identity_closed"')
    }).Count -eq 1
) "same-identity supervisor rerun did not refuse at the closure interlock"

Write-Host (
    "QSDK_R23D18_CLOSURE_PASS status=valid_complete_negative matrix=9/9-valid " +
    "outcomes=5-pass/4-fail godot=2/3 rapier=0/3 mujoco=3/3 " +
    "trace_rows=35568 evidence_files=66 evidence_bytes=161070137 cas_files=66 " +
    "same_identity_refusal=1 same_identity_rerun=False turning=False " +
    "equivalence=False physical_authority=False"
)

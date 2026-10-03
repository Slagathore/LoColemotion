#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r23d4-20260808T124127Z"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path $sdkRoot "turning\r23d4_physical_closure_v1.json"
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d4_supervisor.ps1"
$conformancePath = Join-Path $sdkRoot "run_conformance.ps1"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$campaignId = "QSDK-R23D4-TERMINAL-STABILIZED-BILATERAL-TURN-DEVELOPMENT"
$gateId = "QSDK-R23D4"
$sourceCommit = "7cb164527df62c71c55fc40fdba486af48e4797a"
$sourceTree = "ba38d97e143baca5803b6fc34ca9efe37fa1f878"

. $artifactStorePath

function Assert-R23D4Closure {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D4ClosureRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D4ClosureBytesSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D4ClosureEvidenceTree {
    param([Parameter(Mandatory)][string]$Root)
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse | Sort-Object {
        $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
    })
    $lines = @($files | ForEach-Object {
        $relative = $_.FullName.Substring($Root.Length + 1).Replace("\", "/")
        "{0}`t{1}`t{2}" -f `
            $relative, $_.Length, (
                Get-R23D4ClosureRawSha256 $_.FullName
            ).Substring(7)
    })
    $projection = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n") + "`n")
    return [ordered]@{
        file_count = $files.Count
        total_byte_length = [int64](($files | Measure-Object Length -Sum).Sum)
        raw_sha256 = Get-R23D4ClosureBytesSha256 $projection
    }
}

function Get-R23D4ClosureGitBlob {
    param(
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$Path
    )
    $spec = "$Commit`:$Path"
    $oid = (& git -C $repoRoot rev-parse $spec 2>$null).Trim()
    Assert-R23D4Closure (
        $LASTEXITCODE -eq 0 -and $oid -match '^[0-9a-f]{40}$'
    ) "QSDK-R23D4 historical Git blob is unavailable: $spec"

    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    [void]$start.ArgumentList.Add("cat-file")
    [void]$start.ArgumentList.Add("blob")
    [void]$start.ArgumentList.Add($spec)
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-R23D4Closure $process.Start() "QSDK-R23D4 could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D4Closure ($process.ExitCode -eq 0) (
            "QSDK-R23D4 git cat-file failed for $spec`: $stderr"
        )
        $bytes = $memory.ToArray()
        return [ordered]@{
            oid = $oid
            byte_length = $bytes.Length
            raw_sha256 = Get-R23D4ClosureBytesSha256 $bytes
            text = [Text.Encoding]::UTF8.GetString($bytes)
        }
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

Assert-R23D4Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D4 closure repository identity mismatch"
Assert-R23D4Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "QSDK-R23D4 closure is missing"
)
Assert-R23D4Closure (Test-Path -LiteralPath $EvidenceRoot -PathType Container) (
    "QSDK-R23D4 retained attempt root is missing"
)

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$freezePath = Join-Path $EvidenceRoot "physical-freeze.json"
$authorizationPath = Join-Path $EvidenceRoot "stage-a-authorization.json"
$completionPath = Join-Path $EvidenceRoot "completion.json"
$cellRoot = Join-Path $EvidenceRoot (
    "stage-a\mujoco__terminal_restoration__positive_heading"
)
$processPath = Join-Path $cellRoot "process.json"
$stdoutPath = Join-Path $cellRoot "stdout.txt"
$stderrPath = Join-Path $cellRoot "stderr.txt"

$keyDigests = [ordered]@{
    "physical-freeze.json" = $closure.attempt.physical_freeze_raw_sha256
    "stage-a-authorization.json" = $closure.attempt.stage_a_authorization_raw_sha256
    "completion.json" = $closure.attempt.completion_raw_sha256
    "stage-a/mujoco__terminal_restoration__positive_heading/process.json" =
        $closure.retained_first_worker_process.process_raw_sha256
    "stage-a/mujoco__terminal_restoration__positive_heading/stdout.txt" =
        $closure.retained_first_worker_process.stdout_raw_sha256
    "stage-a/mujoco__terminal_restoration__positive_heading/stderr.txt" =
        $closure.retained_first_worker_process.stderr_raw_sha256
}
foreach ($item in $keyDigests.GetEnumerator()) {
    $path = Join-Path $EvidenceRoot $item.Key
    Assert-R23D4Closure (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D4 retained file is missing: $($item.Key)"
    )
    Assert-R23D4Closure (
        (Get-R23D4ClosureRawSha256 $path) -ceq [string]$item.Value
    ) "QSDK-R23D4 retained file changed: $($item.Key)"
}

$tree = Get-R23D4ClosureEvidenceTree $EvidenceRoot
Assert-R23D4Closure (
    [int]$tree.file_count -eq [int]$closure.attempt.evidence_file_count -and
    [int64]$tree.total_byte_length -eq
        [int64]$closure.attempt.evidence_total_byte_length -and
    [string]$tree.raw_sha256 -ceq
        [string]$closure.attempt.evidence_tree_raw_sha256
) "QSDK-R23D4 retained evidence tree changed"

$freeze = Get-Content -Raw -LiteralPath $freezePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$authorization = Get-Content -Raw -LiteralPath $authorizationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$completion = Get-Content -Raw -LiteralPath $completionPath |
    ConvertFrom-Json -AsHashtable -Depth 30
$processReceipt = Get-Content -Raw -LiteralPath $processPath |
    ConvertFrom-Json -AsHashtable -Depth 30
$stdout = Get-Content -Raw -LiteralPath $stdoutPath
$stderr = Get-Content -Raw -LiteralPath $stderrPath

Assert-R23D4Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d4_physical_development_closure_v1" -and
    [string]$closure.status -ceq
        "closed_consumed_implementation_invalid_zero_world" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.source_identity.commit -ceq $sourceCommit -and
    [string]$closure.source_identity.tree_git_oid -ceq $sourceTree -and
    [int]$closure.source_identity.declared_source_binding_count -eq 65 -and
    [bool]$closure.attempt.one_shot_identity_consumed -and
    -not [bool]$closure.attempt.same_identity_rerun_allowed -and
    [int]$closure.attempt.world_attempt_count -eq 0 -and
    [int]$closure.attempt.world_build_count -eq 0
) "QSDK-R23D4 closure identity changed"

Assert-R23D4Closure (
    [string]$freeze.schema_version -ceq
        "sporespore_qsdk_r23d4_physical_freeze_v1" -and
    [string]$freeze.status -ceq "frozen_supervisor_only_physical_authorized" -and
    [string]$freeze.campaign_id -ceq $campaignId -and
    [string]$freeze.gate_id -ceq $gateId -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq $sourceTree -and
    @($freeze.source_bindings).Count -eq 65 -and
    @($freeze.runtime_artifacts).Count -eq 3 -and
    @($freeze.external_runtime_bindings).Count -eq 4 -and
    [bool]$freeze.physical_execution_authorized
) "QSDK-R23D4 physical freeze changed"
Assert-R23D4Closure (
    [string]$authorization.schema_version -ceq
        "sporespore_qsdk_r23d4_attempt_v1" -and
    [string]$authorization.attempt_id -ceq
        [string]$closure.attempt.attempt_id -and
    [string]$authorization.source_commit -ceq $sourceCommit -and
    [bool]$authorization.physical_execution_authorized -and
    [bool]$authorization.one_shot_attempt_unconsumed -and
    @($authorization.ordered_stage_a_cell_ids).Count -eq 2 -and
    @($authorization.ordered_stage_b_cell_ids).Count -eq 0 -and
    [string]$authorization.full_godot_attestation_sha256 -ceq
        [string]$closure.full_godot_attestation.raw_sha256
) "QSDK-R23D4 Stage A authorization changed"
Assert-R23D4Closure (
    [string]$completion.status -ceq "invalid_or_incomplete_first_attempt" -and
    [string]$completion.failure_code -ceq "SUPERVISOR_INFRASTRUCTURE_EXCEPTION" -and
    [string]$completion.failure_detail -ceq
        [string]$closure.immutable_completion_record.failure_detail -and
    [bool]$completion.one_shot_identity_consumed -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    -not [bool]$completion.command_conditioned_turning -and
    -not [bool]$completion.q_sdk_r23_satisfied -and
    -not [bool]$completion.cross_engine_equivalence -and
    -not [bool]$completion.release_authorized -and
    -not [bool]$completion.physical_acceptance_authority
) "QSDK-R23D4 immutable completion changed"

Assert-R23D4Closure (
    [string]$processReceipt.schema_version -ceq
        "sporespore_qsdk_r23d4_worker_process_v1" -and
    [string]$processReceipt.cell_id -ceq
        "mujoco__terminal_restoration__positive_heading" -and
    [bool]$processReceipt.process_launch_succeeded -and
    [int]$processReceipt.exit_code -eq 1 -and
    -not [bool]$processReceipt.timed_out -and
    [double]$processReceipt.duration_seconds -eq 0.3911156
) "QSDK-R23D4 retained worker process changed"
$terminalLines = @($stdout -split "`r?`n" | Where-Object {
    $_.StartsWith("QSDK_R23D4_TERMINAL ", [StringComparison]::Ordinal)
})
Assert-R23D4Closure ($terminalLines.Count -eq 1) (
    "QSDK-R23D4 retained stdout terminal count changed"
)
$terminal = $terminalLines[0].Substring("QSDK_R23D4_TERMINAL ".Length) |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D4Closure (
    [string]$terminal.schema_version -ceq
        "sporespore_qsdk_r23d4_worker_failure_v1" -and
    [string]$terminal.failure_code -ceq
        "QSDK_R23D4_MJC_PHYSICAL_AUTHORIZATION_INVALID" -and
    [string]$terminal.failure_stage -ceq "before_world" -and
    [int]$terminal.world_attempt_count -eq 0 -and
    [int]$terminal.world_build_count -eq 0 -and
    $null -eq $terminal.trace_artifact -and
    -not [bool]$terminal.claims.command_conditioned_turning -and
    -not [bool]$terminal.claims.physical_acceptance_authority -and
    $stderr.Trim() -ceq (
        "QSDK_R23D4_MUJOCO_FAILURE " +
        "QSDK_R23D4_MJC_PHYSICAL_AUTHORIZATION_INVALID"
    )
) "QSDK-R23D4 retained worker failure changed"

foreach ($path in @(
    (Join-Path $cellRoot "terminal-entry.json"),
    (Join-Path $EvidenceRoot (
        "stage-a\mujoco__terminal_restoration__negative_heading"
    )),
    (Join-Path $EvidenceRoot "stage-a-terminal-paths.json"),
    (Join-Path $EvidenceRoot "stage-a-evaluation.json"),
    (Join-Path $EvidenceRoot "stage-b-authorization.json"),
    (Join-Path $EvidenceRoot "report.json")
)) {
    Assert-R23D4Closure (-not (Test-Path -LiteralPath $path)) (
        "QSDK-R23D4 forbidden post-failure artifact exists: $path"
    )
}

$bindingByPath = @{}
foreach ($binding in @($freeze.source_bindings)) {
    $bindingByPath[[string]$binding.path] = [string]$binding.raw_sha256
}
$missingDependency = [string](
    $closure.worker_authorization_diagnosis.missing_direct_runtime_dependency_path
)
Assert-R23D4Closure (-not $bindingByPath.ContainsKey($missingDependency)) (
    "QSDK-R23D4 missing dependency unexpectedly exists in frozen bindings"
)
foreach ($requiredPath in @(
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d4_terminal_stabilization.py",
    "sdk/turning/r23d4_terminal_stabilization_preregistration_v1.json",
    "sdk/turning/r23d4_physical_evaluator.py",
    "sdk/publish_qsdk_r23d4_trace.ps1",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_pose_hold_restoration_mv6.py"
)) {
    Assert-R23D4Closure ($bindingByPath.ContainsKey($requiredPath)) (
        "QSDK-R23D4 expected worker binding is absent: $requiredPath"
    )
}

$historicalTexts = @{}
foreach ($expected in @($closure.historical_source_blobs)) {
    $actual = Get-R23D4ClosureGitBlob `
        -Commit $sourceCommit `
        -Path ([string]$expected.path)
    Assert-R23D4Closure (
        [string]$actual.oid -ceq [string]$expected.git_blob_oid -and
        [int64]$actual.byte_length -eq [int64]$expected.byte_length -and
        [string]$actual.raw_sha256 -ceq [string]$expected.raw_sha256
    ) "QSDK-R23D4 historical source blob changed: $($expected.path)"
    $historicalTexts[[string]$expected.path] = [string]$actual.text
}
Assert-R23D4Closure (
    $historicalTexts["sdk/run_qsdk_r23d4_supervisor.ps1"].Contains(
        '$terminalLines.Count'
    ) -and
    $historicalTexts[
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d4_terminal_stabilization.py"
    ].Contains("Path(base.__file__).resolve()") -and
    $historicalTexts[
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d4_terminal_stabilization.py"
    ].Contains("QSDK_R23D4_MJC_PHYSICAL_AUTHORIZATION_INVALID") -and
    [int]$closure.worker_authorization_diagnosis.checked_predicate_count -eq 28 -and
    @($closure.worker_authorization_diagnosis.failed_predicate_ids).Count -eq 1 -and
    [string]$closure.worker_authorization_diagnosis.failed_predicate_ids[0] -ceq
        "source_bindings"
) "QSDK-R23D4 infrastructure diagnosis changed"

foreach ($artifact in @(
    @{ digest = $closure.retained_first_worker_process.process_raw_sha256; length = 320 },
    @{ digest = $closure.retained_first_worker_process.stdout_raw_sha256; length = 916 },
    @{ digest = $closure.retained_first_worker_process.stderr_raw_sha256; length = 73 }
)) {
    $raw = ([string]$artifact.digest).Substring(7)
    $directory = Join-Path (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\artifacts\sha256"
    ) $raw
    Assert-R23D4Closure (
        Test-SporeSporeStoredArtifact `
            -Directory $directory `
            -ExpectedSha256 $raw `
            -ExpectedByteLength ([long]$artifact.length)
    ) "QSDK-R23D4 content-addressed worker artifact changed: $raw"
}

$attestationPath = [string]$closure.full_godot_attestation.path
Assert-R23D4Closure (
    (Get-R23D4ClosureRawSha256 $attestationPath) -ceq
        [string]$closure.full_godot_attestation.raw_sha256
) "QSDK-R23D4 full-Godot attestation bytes changed"
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-R23D4Closure (
    [string]$attestation.status -ceq "full_godot_conformance_passed" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [double]$attestation.conformance.duration_seconds -eq
        [double]$closure.full_godot_attestation.duration_seconds -and
    -not [bool]$attestation.claims.physical_acceptance_authority
) "QSDK-R23D4 full-Godot attestation semantics changed"

$supervisorSource = [IO.File]::ReadAllText($supervisorPath)
$workerSources = @(
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d4_terminal_stabilization.py",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced.rs",
    "tests/test_sdk_qsdk_r23d4_godot_jolt_worker.gd"
)
Assert-R23D4Closure (
    $supervisorSource.Contains(
        'Test-Path -LiteralPath $closurePath -PathType Leaf'
    ) -and
    $supervisorSource.Contains("QSDK-R23D4 CLOSED")
) "QSDK-R23D4 supervisor closure interlock is missing"
foreach ($relative in $workerSources) {
    $text = [IO.File]::ReadAllText((Join-Path $repoRoot $relative))
    Assert-R23D4Closure (
        $text.Contains("r23d4_physical_closure_v1.json")
    ) "QSDK-R23D4 worker closure interlock is missing: $relative"
}

$beforeRoots = @(
    Get-ChildItem -LiteralPath (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    ) -Directory | Where-Object Name -like "qsdk-r23d4-*"
).Count
$refusal = @(& (Get-Process -Id $PID).Path `
    -NoProfile -File $supervisorPath `
    -RunPhysical `
    -FullConformanceAttestation "R23D4_CLOSED_CANARY" 2>&1)
$refusalExit = $LASTEXITCODE
$afterRoots = @(
    Get-ChildItem -LiteralPath (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    ) -Directory | Where-Object Name -like "qsdk-r23d4-*"
).Count
Assert-R23D4Closure (
    $refusalExit -ne 0 -and
    ($refusal -join "`n").Contains("QSDK-R23D4 CLOSED") -and
    $afterRoots -eq $beforeRoots
) "QSDK-R23D4 same-identity supervisor did not fail closed"
$global:LASTEXITCODE = 0

$conformanceSource = [IO.File]::ReadAllText($conformancePath)
Assert-R23D4Closure (
    $conformanceSource.Contains("tests\test_qsdk_r23d4_closure.ps1") -and
    -not $conformanceSource.Contains(
        'Join-Path $sdkRoot "run_qsdk_r23d4_terminal_stabilization_preflight.ps1"'
    ) -and
    -not $conformanceSource.Contains(
        'Join-Path $sdkRoot "run_qsdk_r23d4_mujoco_worker_preflight.ps1"'
    )
) "QSDK-R23D4 canonical conformance routing changed"

Assert-R23D4Closure (
    -not [bool]$closure.claims.scientific_positive -and
    -not [bool]$closure.claims.scientific_negative -and
    -not [bool]$closure.claims.command_conditioned_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.q_sdk_r23_satisfied -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "QSDK-R23D4 closed claims changed"

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d4_closure_audit_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    status = [string]$closure.status
    retained_evidence_file_count = [int]$tree.file_count
    launched_worker_process_count = 1
    completed_cell_count = 0
    missing_source_binding_count = 1
    content_addressed_worker_artifact_count = 3
    world_attempt_count = 0
    world_build_count = 0
    one_shot_identity_consumed = $true
    same_identity_rerun_allowed = $false
    scientific_positive = $false
    scientific_negative = $false
    command_conditioned_turning = $false
    cross_engine_equivalence = $false
    q_sdk_r23_satisfied = $false
    release_authorized = $false
    physical_acceptance_authority = $false
}
Write-Host "QSDK_R23D4_CLOSURE_AUDIT $($receipt | ConvertTo-Json -Compress)"
Write-Host (
    "QSDK_R23D4_CLOSURE_PASS status=$($closure.status) " +
    "files=$($tree.file_count) workers=1 cells=0 missing_bindings=1 " +
    "worlds=0 consumed=True rerun=False turning=False equivalence=False " +
    "physical_authority=False"
)

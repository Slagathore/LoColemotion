#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$PowerShell = "pwsh",
    [switch]$ExpectProductionConformanceLockHeld
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$closingCommit = "03c160b7f020e114df099c74154dc04ab57676b5"
$sourceCommit = "08a217c71622546dff2c4e9e74abb95c5aaebbfe"
$closureRelative = (
    "sdk/turning/" +
    "r23d73_mujoco_selected_profile_positive_turn_development_closure_v1.json"
)
$auditRelative = "sdk/audit_r23d73_mujoco_positive_turn_development_closure.ps1"
$closurePath = Join-Path $repoRoot $closureRelative
$auditPath = Join-Path $repoRoot $auditRelative
$outerLockPreflightPath = Join-Path $repoRoot (
    "tests\test_qsdk_r23d74_legacy_mujoco_outer_lock_preflight.ps1"
)
$r72OuterLockReplayPath = Join-Path $repoRoot (
    "tests\test_qsdk_r23d74_r23d72_outer_lock_replay.ps1"
)

function Assert-R23D74R73Replay([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "[turning/mujoco] R23D74 R23D73 predecessor replay: $Message"
    }
}

function Get-R23D74R73GitBlobRawSha256([string]$Commit, [string]$RelativePath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $repoRoot, "cat-file", "blob", "${Commit}:$RelativePath"
    )) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        Assert-R23D74R73Replay $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try {
            $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream)
        } finally {
            $hasher.Dispose()
        }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R23D74R73Replay ($process.ExitCode -eq 0) (
            "Git blob read failed for $RelativePath`: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally {
        $process.Dispose()
    }
}

function Get-R23D74R73FileRawSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Replace-R23D74R73ExactOnce(
    [string]$Text,
    [string]$Anchor,
    [string]$Replacement,
    [string]$Label
) {
    $count = [regex]::Matches(
        $Text,
        [regex]::Escape($Anchor),
        [Text.RegularExpressions.RegexOptions]::CultureInvariant
    ).Count
    Assert-R23D74R73Replay ($count -eq 1) (
        "expected one $Label transformation anchor, observed $count"
    )
    return $Text.Replace($Anchor, $Replacement)
}

function Invoke-R23D74R73LegacyAudit {
    if (-not $ExpectProductionConformanceLockHeld) {
        $records = @(& $PowerShell -NoLogo -NoProfile -File $auditPath 2>&1 |
            ForEach-Object { [string]$_ })
        return [ordered]@{
            exit_code = [int]$LASTEXITCODE
            text = $records -join "`n"
            replay_mode = "immutable_legacy_audit_standalone"
            exact_transport_transformation_count = 0
            transformed_audit_raw_sha256 = $null
        }
    }

    foreach ($path in @($outerLockPreflightPath, $r72OuterLockReplayPath)) {
        Assert-R23D74R73Replay (Test-Path -LiteralPath $path -PathType Leaf) (
            "outer-lock replay dependency is missing: $path"
        )
    }
    $legacyText = [IO.File]::ReadAllText(
        $auditPath,
        [Text.UTF8Encoding]::new($false)
    )
    $transformed = Replace-R23D74R73ExactOnce $legacyText `
        '$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)' `
        '$sdkRoot = [IO.Path]::GetFullPath("C:\Users\Cole\CodeStuff\games\SporeSpore\sdk")' `
        "SDK-root"
    $transformed = Replace-R23D74R73ExactOnce $transformed `
        '$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d73_supervisor.ps1"' `
        '$supervisorPath = Join-Path $repoRoot "tests\test_qsdk_r23d74_legacy_mujoco_outer_lock_preflight.ps1"' `
        "supervisor-path"
    $transformed = Replace-R23D74R73ExactOnce $transformed `
        '"audit_r23d72_mujoco_preturn_startup_development_closure.ps1"' `
        '"..\tests\test_qsdk_r23d74_r23d72_outer_lock_replay.ps1"' `
        "R23D72-audit-path"
    $transformed = Replace-R23D74R73ExactOnce $transformed `
        '"-NoProfile", "-File", $supervisorPath, "-PreflightOnly", "-Python", $pythonHost' `
        '"-NoProfile", "-File", $supervisorPath, "-Campaign", "R23D73", "-ExpectProductionConformanceLockHeld", "-Python", $pythonHost' `
        "supervisor-invocation"
    $transformed = Replace-R23D74R73ExactOnce $transformed `
        '"-NoProfile", "-File", $r72ClosureAuditPath' `
        '"-NoProfile", "-File", $r72ClosureAuditPath, "-ExpectProductionConformanceLockHeld"' `
        "R23D72-audit-invocation"

    $records = [Collections.Generic.List[string]]::new()
    $exitCode = 0
    try {
        foreach ($record in @(& ([ScriptBlock]::Create($transformed)) *>&1)) {
            $records.Add([string]$record)
        }
    } catch {
        $exitCode = 1
        $records.Add([string]$_.Exception.ToString())
        if (-not [string]::IsNullOrWhiteSpace([string]$_.ScriptStackTrace)) {
            $records.Add([string]$_.ScriptStackTrace)
        }
    }
    $transformedBytes = [Text.UTF8Encoding]::new($false).GetBytes($transformed)
    return [ordered]@{
        exit_code = $exitCode
        text = $records -join "`n"
        replay_mode = "immutable_audit_with_exact_outer_lock_transport_rebinding"
        exact_transport_transformation_count = 5
        transformed_audit_raw_sha256 = "sha256:" + [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($transformedBytes)
        ).ToLowerInvariant()
    }
}

Assert-R23D74R73Replay (
    (& git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (& git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (& git -C $repoRoot cat-file -t "${closingCommit}^{commit}").Trim() -ceq "commit" -and
    (& git -C $repoRoot cat-file -t "${sourceCommit}^{commit}").Trim() -ceq "commit"
) "repository, remote, closing commit, or source commit changed"
foreach ($binding in @(
    @($closureRelative, $closurePath),
    @($auditRelative, $auditPath)
)) {
    Assert-R23D74R73Replay (Test-Path -LiteralPath $binding[1] -PathType Leaf) (
        "required predecessor path missing: $($binding[1])"
    )
    Assert-R23D74R73Replay (
        (Get-R23D74R73FileRawSha256 $binding[1]) -ceq
            (Get-R23D74R73GitBlobRawSha256 $closingCommit $binding[0])
    ) "immutable R23D73 closure or audit changed: $($binding[0])"
}

$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D74R73Replay (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d73_mujoco_selected_profile_positive_turn_development_closure_v1" -and
    [string]$closure.status -ceq "closed_valid_complete_positive_turn_development" -and
    [string]$closure.question_class -ceq "development" -and
    [string]$closure.source.commit -ceq $sourceCommit -and
    [int]$closure.evidence.file_count -eq 13 -and
    [long]$closure.evidence.total_byte_length -eq 34449115 -and
    [string]$closure.execution.classification -ceq
        "valid_complete_positive_turn_development" -and
    [int]$closure.execution.trace_row_count -eq 2992 -and
    [double]$closure.directional_measurement.observed_raw_signed_cycle_shift_rad -eq
        0.14718188227060067 -and
    [bool]$closure.directional_measurement.raw_signed_cycle_shift_gate_passed -and
    [bool]$closure.claims.exact_mujoco_positive_heading_turning_cell_established -and
    -not [bool]$closure.claims.turning_established -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.release_readiness_score_changed -and
    [string]$closure.claims.release_score_after -ceq "10/25" -and
    -not [bool]$closure.claims.release_authorized
) "R23D73 immutable result or claim boundary changed"

# Standalone replay executes the immutable legacy audit byte for byte. During
# commissioned production conformance, that audit's R23D73 and nested R23D72
# supervisors cannot reacquire the mutex already held by their parent. In that
# one mode, execute the same immutable audit in memory with exactly five
# transport-only substitutions: pin its SDK root, route the two historical
# supervisor preflights through no-model outer-lock checks, and pass the outer
# lock assertion into the nested R23D72 replay. All retained-evidence, trace,
# mutation, prospective-route, inherited-audit, and final origin-refusal logic
# remains the immutable historical text. No observed result is rewritten.
$legacyAudit = Invoke-R23D74R73LegacyAudit
$exitCode = [int]$legacyAudit.exit_code
$text = [string]$legacyAudit.text
$expectedOriginPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore\sdk\adapters\rapier\src\" +
    "qsdk_r23d3_phase_balanced\r23d27_physical.rs"
)
$refusalChecks = [ordered]@{
    nonzero_exit = $exitCode -ne 0
    origin_audit_marker = $text.Contains(
        "[turning/measurement] origin parity audit:",
        [StringComparison]::Ordinal
    )
    source_identity_refusal = $text -cmatch
        'canonical source identity(?:\s|\|)+changed:'
    expected_origin_path = $text.Contains(
        $expectedOriginPath,
        [StringComparison]::Ordinal
    )
    closure_audit_transport = $text.Contains(
        "R23D73 closure audit: pwsh failed with exit 1",
        [StringComparison]::Ordinal
    )
    no_lock_contention = -not $text.Contains(
        "global locomotion operation lock is busy",
        [StringComparison]::Ordinal
    )
    no_success_marker = -not $text.Contains(
        "[turning/mujoco] R23D73 closure PASS",
        [StringComparison]::Ordinal
    )
}
Assert-R23D74R73Replay (
    @($refusalChecks.Values | Where-Object { -not [bool]$_ }).Count -eq 0
) (
    "legacy audit did not reach its exact final transitive successor-source " +
    "refusal: checks=$($refusalChecks | ConvertTo-Json -Compress) text=$text"
)

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d74_r23d73_predecessor_replay_v1"
    predecessor_closing_commit = $closingCommit
    predecessor_source_commit = $sourceCommit
    closure_and_audit_immutable = $true
    retained_evidence_and_trace_recomputed_before_final_transitive_call = $true
    closure_mutation_rejection_count = 8
    prospective_route_and_supervisor_replayed_before_final_transitive_call = $true
    r23d72_closure_replayed_before_final_transitive_call = $true
    expected_transitive_successor_source_refusal_observed = $true
    replay_mode = [string]$legacyAudit.replay_mode
    exact_transport_transformation_count =
        [int]$legacyAudit.exact_transport_transformation_count
    transformed_audit_raw_sha256 =
        [string]$legacyAudit.transformed_audit_raw_sha256
    active_parent_conformance_lock_expected =
        [bool]$ExpectProductionConformanceLockHeld
    separate_r23d74_measurement_origin_predecessor_replay_required = $true
    historical_result_changed = $false
    retained_physical_world_count = 1
    new_physical_world_count = 0
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    solver_step_count = 0
    physical_execution_authorized = $false
    physical_acceptance_authority = $false
}
Write-Output (
    "QSDK_R23D74_R23D73_PREDECESSOR_REPLAY_PASS " +
    ($receipt | ConvertTo-Json -Compress -Depth 100)
)
Write-Output (
    "[turning/mujoco] R23D74 R23D73 predecessor replay PASS: " +
    "immutable closure/audit, retained evidence and trace rechecked, " +
    "8/8 mutations rejected, exact final transitive successor-source refusal isolated, " +
    "new models=0 worlds=0 solver_steps=0"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_velocity_only_early_horizon_eh1_closure.json"
$expectedClosureRawSha256 = (
    "ee30507561e27f0d010683f2477c55d6f820342a46a45825ddc898fb0c6a6274"
)
$campaignId = "C6-RAPIER-BW19V-VELOCITY-ONLY-EARLY-HORIZON-DEVELOPMENT-EH1"
$gateId = "C6-RAP-BW19V-V4-EH1"

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Get-GitBlobRawSha256 {
    param(
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$Path
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = (Get-Command git -ErrorAction Stop).Source
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @("cat-file", "blob", "$Commit`:$Path")) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-Exact $process.Start() "$gateId failed to start the Git-blob audit"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-Exact (
            $process.ExitCode -eq 0
        ) "$gateId Git-blob audit failed for $Commit`:$Path`: $stderr"
        return [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($memory.ToArray())
        ).ToLowerInvariant()
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

Assert-Exact (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-RawSha256 $closurePath) -ceq $expectedClosureRawSha256
) "$gateId closure is missing or changed"
$closure = Get-Content -Raw -LiteralPath $closurePath | ConvertFrom-Json
Assert-Exact (
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.status -ceq
        "closed_invalid_primary_report_with_complete_posthoc_reconstructible_trace" -and
    [string]$closure.physical_source_commit -ceq
        "fad011bbdca6b2b81791058abee3901bcda0ac8a" -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.threshold_horizon_scale_arm_or_report_rewrite_allowed -and
    [int]$closure.physical_attempt.process_launch_count -eq 1 -and
    [int]$closure.physical_attempt.world_build_count -eq 2 -and
    [int]$closure.physical_attempt.trace_step_count_total -eq 944 -and
    -not [bool]$closure.physical_attempt.retained_primary_report_ok -and
    [bool]$closure.posthoc_diagnostic_result.corrected_counterfactual_integrity_passed -and
    [bool]$closure.posthoc_diagnostic_result.all_traces_complete_without_declared_event -and
    -not [bool]$closure.posthoc_diagnostic_result.primary_integrity_restored -and
    -not [bool]$closure.claims.valid_primary_eh1_result -and
    -not [bool]$closure.claims.walking_acceptance -and
    -not [bool]$closure.claims.release_authorized -and
    -not [bool]$closure.claims.physical_acceptance_authority
) "$gateId closure disposition or claim boundary changed"

foreach ($binding in @($closure.closure_implementation_bindings.PSObject.Properties)) {
    $entry = $binding.Value
    $path = [System.IO.Path]::GetFullPath(
        (Join-Path $repoRoot ([string]$entry.path))
    )
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 $path) -ceq [string]$entry.raw_sha256
    ) "$gateId closure implementation binding changed: $path"
}
foreach ($binding in @($closure.authoritative_profile_bindings)) {
    $path = [System.IO.Path]::GetFullPath(
        (Join-Path $repoRoot ([string]$binding.path))
    )
    $workingTreeMatches = (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 $path) -ceq [string]$binding.raw_sha256
    )
    $experimentBlobMatches = (
        (Get-GitBlobRawSha256 `
            -Commit ([string]$closure.physical_source_commit) `
            -Path ([string]$binding.path)) -ceq [string]$binding.raw_sha256
    )
    Assert-Exact (
        $workingTreeMatches -or $experimentBlobMatches
    ) (
        "$gateId authoritative profile binding is absent from both the " +
        "working tree and frozen experiment source: $path"
    )
}
foreach ($binding in @($closure.frozen_source_blobs.PSObject.Properties)) {
    $entry = $binding.Value
    $blob = (& git -C $repoRoot rev-parse (
        [string]$closure.physical_source_commit + ":" + [string]$entry.path
    )).Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        $blob -ceq [string]$entry.git_blob_oid
    ) "$gateId frozen physical source blob changed: $($entry.path)"
}

$evidenceRoot = [System.IO.Path]::GetFullPath(
    [string]$closure.retained_evidence.root
)
$expectedEvidencePrefix = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
Assert-Exact (
    $evidenceRoot.StartsWith(
        $expectedEvidencePrefix,
        [StringComparison]::OrdinalIgnoreCase
    )
) "$gateId evidence root escaped SporeSpore_Evidence"
foreach ($binding in @($closure.retained_evidence.PSObject.Properties)) {
    if ($binding.Name -ceq "root") {
        continue
    }
    $entry = $binding.Value
    $path = Join-Path $evidenceRoot ([string]$entry.path)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 $path) -ceq [string]$entry.raw_sha256
    ) "$gateId retained evidence changed: $path"
    if (@($entry.PSObject.Properties.Name) -ccontains "byte_length") {
        Assert-Exact (
            (Get-Item -LiteralPath $path).Length -eq [long]$entry.byte_length
        ) "$gateId retained evidence length changed: $path"
    }
}

$attempt = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "attempt.json"
) | ConvertFrom-Json
$completion = Get-Content -Raw -LiteralPath (
    Join-Path $evidenceRoot "completion.json"
) | ConvertFrom-Json
$reportPath = Join-Path $evidenceRoot "report.json"
$report = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
$diagnosticPath = Join-Path $evidenceRoot "posthoc_diagnostic.json"
$diagnostic = Get-Content -Raw -LiteralPath $diagnosticPath | ConvertFrom-Json
Assert-Exact (
    [string]$attempt.status -ceq
        "physical_process_launch_reserved_identity_consumed" -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    [string]$completion.status -ceq "physical_process_exited_with_report" -and
    [int]$completion.process_exit_code -eq 1 -and
    [bool]$completion.report_retained -and
    -not [bool]$completion.same_identity_rerun_allowed -and
    [string]$completion.report_raw_sha256 -ceq (
        "sha256:" + [string]$closure.retained_evidence.primary_report.raw_sha256
    )
) "$gateId attempt or process-completion receipt changed"

$expectedOriginalFailures = @(
    "C6_RAP_V4_EH1_EH1-A_RECEIPT_INVALID:0",
    "C6_RAP_V4_EH1_EH1-A_RESIDUAL_COUNT_RECOMPUTE",
    "C6_RAP_V4_EH1_EH1-B_RECEIPT_INVALID:0",
    "C6_RAP_V4_EH1_EH1-B_RESIDUAL_COUNT_RECOMPUTE"
)
Assert-Exact (
    -not [bool]$report.ok -and
    [int]$report.world_build_count -eq 2 -and
    [int]$report.trace_step_count_total -eq 944 -and
    [int]$report.host_command_count_total -eq 7552 -and
    (@($report.integrity_gate_failures) -join "|") -ceq
        ($expectedOriginalFailures -join "|") -and
    [string]$report.pair_interpretation.classification -ceq
        "neither_arm_event" -and
    -not [bool]$report.claim_boundary.walking_acceptance -and
    -not [bool]$report.claim_boundary.physical_acceptance_authority
) "$gateId primary report was rewritten or reclassified"
foreach ($arm in @($report.arms)) {
    Assert-Exact (
        [bool]$arm.completed_declared_horizon -and
        $null -eq $arm.fatal_error -and
        [int]$arm.world_build_count -eq 1 -and
        [int]$arm.trace_step_count -eq 472 -and
        [int]$arm.controller_error_count -eq 0 -and
        [int]$arm.composition_error_count -eq 0 -and
        [int]$arm.nonfinite_observation_count -eq 0 -and
        [int]$arm.actuator_application_mismatch_count -eq 0 -and
        [int]$arm.motor_model_or_field_readback_mismatch_count -eq 0 -and
        [int]$arm.small_step_impulse_limit_violation_count -eq 0 -and
        $null -eq $arm.first_failure_event
    ) "$gateId retained arm trace or integrity counters changed"
}
Assert-Exact (
    [bool]$diagnostic.ok -and
    -not [bool]$diagnostic.retained_primary_report_ok -and
    [bool]$diagnostic.retained_primary_report_remains_invalid -and
    [bool]$diagnostic.corrected_counterfactual_integrity_passed -and
    @($diagnostic.corrected_counterfactual_integrity_failure_codes).Count -eq 0 -and
    [bool]$diagnostic.all_traces_complete_without_declared_event -and
    [string]$diagnostic.primary_defect.authoritative_profile_id -ceq
        "rapier_force_based_velocity_only_v1" -and
    [int]$diagnostic.primary_defect.posthoc_counter_reconstruction_defect.treatment_pre_clamp_nonzero_count -eq 1822 -and
    [int]$diagnostic.primary_defect.posthoc_counter_reconstruction_defect.treatment_effective_host_application_count -eq 1759 -and
    -not [bool]$diagnostic.claims.primary_eh1_integrity_restored -and
    -not [bool]$diagnostic.claims.walking_acceptance -and
    -not [bool]$diagnostic.claims.physical_acceptance_authority
) "$gateId post-hoc diagnostic or non-claim boundary changed"

$temporaryRoot = [System.IO.Path]::GetFullPath(
    (Join-Path ([System.IO.Path]::GetTempPath()) (
        "sporespore_eh1_closure_" + [Guid]::NewGuid().ToString("N")
    ))
)
$temporaryPrefix = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::GetTempPath()
).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
Assert-Exact (
    $temporaryRoot.StartsWith(
        $temporaryPrefix,
        [StringComparison]::OrdinalIgnoreCase
    )
) "$gateId temporary audit root escaped the system temporary directory"
[void][System.IO.Directory]::CreateDirectory($temporaryRoot)
$recomputedPath = Join-Path $temporaryRoot "posthoc_diagnostic.json"
try {
    Push-Location -LiteralPath $sdkRoot
    try {
        $recomputedLines = @(
            & cargo run `
                --quiet `
                --package sporespore-rapier-adapter `
                --bin bw19v_velocity_only_early_horizon_eh1_posthoc `
                --offline `
                -- `
                --report $reportPath `
                --output $recomputedPath
        )
        Assert-Exact (
            $LASTEXITCODE -eq 0
        ) "$gateId corrected post-hoc evaluator failed"
    } finally {
        Pop-Location
    }
    Assert-Exact (
        (Test-Path -LiteralPath $recomputedPath -PathType Leaf) -and
        (Get-RawSha256 $recomputedPath) -ceq
            [string]$closure.retained_evidence.posthoc_diagnostic.raw_sha256
    ) "$gateId corrected post-hoc diagnostic is not deterministic"
} finally {
    if (Test-Path -LiteralPath $temporaryRoot -PathType Container) {
        [System.IO.Directory]::Delete($temporaryRoot, $true)
    }
}

$supervisorPath = Join-Path (
    $sdkRoot
) "run_rapier_c6_bw19v_velocity_only_early_horizon_eh1.ps1"
$supervisor = Get-Content -Raw -LiteralPath $supervisorPath
$closureCheckIndex = $supervisor.IndexOf(
    '$gateId is already closed and may not open another world'
)
$preregistrationCheckIndex = $supervisor.IndexOf(
    '$gateId preregistration is missing or changed'
)
Assert-Exact (
    $closureCheckIndex -ge 0 -and
    $preregistrationCheckIndex -gt $closureCheckIndex
) "$gateId supervisor no longer fails closed before mutable checkout inputs"

Write-Host (
    "C6_RAP_V4_EH1_CLOSURE_PASS primary_ok=False worlds=2 " +
    "trace_steps=944 pair=neither_arm_event posthoc_reconstructible=True " +
    "walking_authority=False same_identity_rerun=False"
)

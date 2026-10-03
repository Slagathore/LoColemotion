#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$closurePath = Join-Path $repoRoot `
    "sdk\locomotion_full_conformance_attestation_v1_closure.json"
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 64

function Assert-Exact([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256([string]$Path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

$sourceCommit = [string]$closure.closed_source_commit
$attestationPath = [System.IO.Path]::GetFullPath(
    [string]$closure.retained_attestation.path
)
Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v1_closure_v1" -and
    [string]$closure.status -ceq
        "closed_infrastructure_invalid_postpublication_timestamp_roundtrip" -and
    $sourceCommit -ceq "3a52c764adfcf494cf9d2b13ca9d0fa4a6b41a35" -and
    [string]$closure.closed_source_tree_git_oid -ceq
        "f3899e1dc57f184acdc67d5f1cf6e634c970f45f"
) "V1 closure identity changed."

& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "V1 source commit is unavailable."
$historicalTree = (& git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim()
Assert-Exact (
    $historicalTree -ceq [string]$closure.closed_source_tree_git_oid
) "V1 source tree changed."

Assert-Exact (
    (Test-Path -LiteralPath $attestationPath -PathType Leaf) -and
    (Get-RawSha256 $attestationPath) -ceq
        [string]$closure.retained_attestation.raw_sha256 -and
    (Get-Item -LiteralPath $attestationPath).Length -eq
        [long]$closure.retained_attestation.byte_length
) "Retained V1 attestation bytes changed."

$document = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Exact (
    [string]$document.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v1" -and
    [string]$document.source.commit -ceq $sourceCommit -and
    [string]$document.source.tree_git_oid -ceq $historicalTree -and
    [bool]$document.conformance.passed -and
    -not [bool]$document.conformance.skip_godot -and
    [bool]$document.conformance.godot_including -and
    -not [bool]$document.conformance.one_shot_physical_campaign_executed -and
    [double]$document.conformance.duration_seconds -eq 844.6916806 -and
    [string]$document.godot.executable_sha256 -ceq
        [string]$closure.retained_attestation.godot_executable_sha256
) "Retained V1 attestation content changed."

$retainedBindingJson = @($document.source_bindings) |
    ConvertTo-Json -Depth 16 -Compress
$closureBindingJson = @($closure.source_bindings) |
    ConvertTo-Json -Depth 16 -Compress
Assert-Exact ($retainedBindingJson -ceq $closureBindingJson) `
    "Retained V1 source-binding identities changed."

foreach ($binding in @($closure.source_bindings)) {
    $historicalOid = (& git -C $repoRoot rev-parse (
        "$sourceCommit`:$([string]$binding.path)"
    )).Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        $historicalOid -ceq [string]$binding.git_blob_oid
    ) "Historical V1 binding changed: $([string]$binding.path)"
}

# Load the exact historical validator without touching the current source. The
# timestamp fields are explicitly materialized as DateTime to reproduce the
# PowerShell 7.6 JSON shape independent of the shell running this closure audit.
$lockSource = ((& git -C $repoRoot show (
    "$sourceCommit`:sdk/locomotion_operation_lock.ps1"
)) -join "`n") -replace '^#requires[^\r\n]*\r?\n', ''
$validatorSource = ((& git -C $repoRoot show (
    "$sourceCommit`:sdk/locomotion_full_conformance_attestation.ps1"
)) -join "`n") -replace '^#requires[^\r\n]*\r?\n', ''
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $validatorSource -match '\[DateTime\]::Parse\(' -and
    $validatorSource -notmatch 'ConvertTo-SporeSporeAttestationUtcDateTime'
) "Historical V1 verifier mechanism changed."
Invoke-Expression $lockSource
Invoke-Expression $validatorSource

$document.conformance.started_utc = [DateTime]::Parse(
    [string]$closure.full_suite.started_utc,
    [System.Globalization.CultureInfo]::InvariantCulture,
    [System.Globalization.DateTimeStyles]::RoundtripKind
)
$document.conformance.completed_utc = [DateTime]::Parse(
    [string]$closure.full_suite.completed_utc,
    [System.Globalization.CultureInfo]::InvariantCulture,
    [System.Globalization.DateTimeStyles]::RoundtripKind
)
$historicalVerification = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $document `
    -ExpectedSource $document.source `
    -ExpectedGodotIdentity $document.godot `
    -ExpectedSourceBindings @($document.source_bindings)
Assert-Exact (
    -not [bool]$historicalVerification.ok -and
    @($historicalVerification.failure_codes).Count -eq 1 -and
    [string]$historicalVerification.failure_codes[0] -ceq
        "FULL_GODOT_CONFORMANCE"
) "Historical V1 verifier failure did not reproduce exactly."

$startedLossy = [DateTime]::Parse(
    [string]$document.conformance.started_utc,
    [System.Globalization.CultureInfo]::InvariantCulture,
    [System.Globalization.DateTimeStyles]::RoundtripKind
).ToUniversalTime()
$completedLossy = [DateTime]::Parse(
    [string]$document.conformance.completed_utc,
    [System.Globalization.CultureInfo]::InvariantCulture,
    [System.Globalization.DateTimeStyles]::RoundtripKind
).ToUniversalTime()
$lossyDuration = ($completedLossy - $startedLossy).TotalSeconds
$difference = [Math]::Abs(
    $lossyDuration - [double]$document.conformance.duration_seconds
)
Assert-Exact (
    $lossyDuration -eq 845.0 -and
    [Math]::Abs($difference - 0.3083194) -le 0.0000001
) "Historical V1 duration defect did not reproduce."

$overwriteRejected = $false
try {
    [void](Assert-SporeSporeDurableAttestationOutputPath `
        -RepoRoot $repoRoot `
        -OutputPath $attestationPath)
} catch { $overwriteRejected = $true }
Assert-Exact $overwriteRejected "Historical V1 artifact could be overwritten."

foreach ($claim in $document.claims.Keys) {
    Assert-Exact (-not [bool]$document.claims[$claim]) `
        "Historical V1 artifact inflated claim: $claim"
}
Assert-Exact (
    -not [bool]$closure.immutable_disposition.attestation_valid -and
    [bool]$closure.immutable_disposition.full_suite_process_passed -and
    -not [bool]$closure.immutable_disposition.reusable_conformance_authority -and
    -not [bool]$closure.immutable_disposition.physical_launch_authority -and
    [bool]$closure.postpublication_verification.
        production_lock_released_after_completion -and
    [bool]$closure.successor_requirements.
        serialized_temporary_file_must_verify_before_atomic_publication
) "Historical V1 claim or successor boundary changed."

Write-Host (
    "FULL_CONFORMANCE_ATTESTATION_V1_CLOSURE_PASS " +
    "status=infrastructure-invalid source=3a52c764 full_suite_exit=0 " +
    "verifier_failure=FULL_GODOT_CONFORMANCE recorded_duration=844.6916806 " +
    "recomputed_duration=845 difference=0.3083194 lock_released=True " +
    "physical_authority=False"
)

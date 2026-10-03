#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$closurePath = Join-Path $repoRoot `
    "sdk\locomotion_full_conformance_attestation_v2_closure.json"
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
        "sporespore_full_godot_conformance_attestation_v2_closure_v1" -and
    [string]$closure.status -ceq
        "closed_positive_infrastructure_commissioning" -and
    $sourceCommit -ceq "0513be82370604e958c2ff1e563e444b70746b72" -and
    [string]$closure.closed_source_tree_git_oid -ceq
        "612f9a2532758904a53a6668de6858fcaa5c9fda"
) "V2 closure identity changed."

& git -C $repoRoot cat-file -e "$sourceCommit`^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "V2 source commit is unavailable."
$historicalTree = (& git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim()
Assert-Exact (
    $historicalTree -ceq [string]$closure.closed_source_tree_git_oid
) "V2 source tree changed."

Assert-Exact (
    (Test-Path -LiteralPath $attestationPath -PathType Leaf) -and
    (Get-RawSha256 $attestationPath) -ceq
        [string]$closure.retained_attestation.raw_sha256 -and
    (Get-Item -LiteralPath $attestationPath).Length -eq
        [long]$closure.retained_attestation.byte_length
) "Retained V2 attestation bytes changed."

$document = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Exact (
    [string]$document.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$document.status -ceq "full_godot_conformance_passed" -and
    -not [bool]$document.test_only -and
    [string]$document.source.commit -ceq $sourceCommit -and
    [string]$document.source.tree_git_oid -ceq $historicalTree -and
    [string]$document.source.origin_main -ceq $sourceCommit -and
    [string]$document.source.live_github_main -ceq $sourceCommit -and
    [bool]$document.source.worktree_clean -and
    [bool]$document.source.clean_pushed_live -and
    [bool]$document.conformance.passed -and
    -not [bool]$document.conformance.skip_godot -and
    [bool]$document.conformance.godot_including -and
    [bool]$document.conformance.regression_test_physics_permitted -and
    -not [bool]$document.conformance.one_shot_physical_campaign_executed -and
    [double]$document.conformance.duration_seconds -eq 855.3993872
) "Retained V2 attestation content changed."

Assert-Exact (
    [string]$document.godot.executable_sha256 -ceq
        [string]$closure.godot.executable_sha256 -and
    [string]$document.godot.version -ceq [string]$closure.godot.version -and
    [string]$document.powershell.executable_sha256 -ceq
        [string]$closure.powershell.executable_sha256 -and
    [string]$document.powershell.version -ceq
        [string]$closure.powershell.version -and
    [string]$document.powershell.edition -ceq
        [string]$closure.powershell.edition -and
    [string]$document.powershell.process_architecture -ceq
        [string]$closure.powershell.process_architecture
) "Retained V2 host identities changed."

$retainedBindingJson = @($document.source_bindings) |
    ConvertTo-Json -Depth 16 -Compress
$closureBindingJson = @($closure.source_bindings) |
    ConvertTo-Json -Depth 16 -Compress
Assert-Exact ($retainedBindingJson -ceq $closureBindingJson) `
    "Retained V2 source-binding identities changed."

foreach ($binding in @($closure.source_bindings)) {
    $historicalOid = (& git -C $repoRoot rev-parse (
        "$sourceCommit`:$([string]$binding.path)"
    )).Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        $historicalOid -ceq [string]$binding.git_blob_oid
    ) "Historical V2 binding changed: $([string]$binding.path)"
}

$attestedLockJson = $document.operation_lock |
    ConvertTo-Json -Depth 16 -Compress
$closedLockJson = $closure.operation_lock |
    ConvertTo-Json -Depth 16 -Compress
Assert-Exact ($attestedLockJson -ceq $closedLockJson) `
    "Retained V2 operation-lock receipt changed."

# Load the exact historical validator from the attested commit. This makes the
# closure independent of later changes to the production verifier while still
# replaying the V2 type-aware serialized-document gate.
$lockSource = ((& git -C $repoRoot show (
    "$sourceCommit`:sdk/locomotion_operation_lock.ps1"
)) -join "`n") -replace '^#requires[^\r\n]*\r?\n', ''
$validatorSource = ((& git -C $repoRoot show (
    "$sourceCommit`:sdk/locomotion_full_conformance_attestation.ps1"
)) -join "`n") -replace '^#requires[^\r\n]*\r?\n', ''
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $validatorSource -match 'ConvertTo-SporeSporeAttestationUtcDateTime' -and
    $validatorSource -match 'ExpectedPowerShellIdentity' -and
    $validatorSource -match 'serializedDocument'
) "Historical V2 verifier mechanism changed."
Invoke-Expression $lockSource
Invoke-Expression $validatorSource

$historicalVerification = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $document `
    -ExpectedSource $document.source `
    -ExpectedGodotIdentity $document.godot `
    -ExpectedPowerShellIdentity $document.powershell `
    -ExpectedSourceBindings @($document.source_bindings)
Assert-Exact (
    [bool]$historicalVerification.ok -and
    @($historicalVerification.failure_codes).Count -eq 0 -and
    -not [bool]$historicalVerification.physical_acceptance_authority
) "Historical V2 serialized attestation no longer verifies."

$started = ConvertTo-SporeSporeAttestationUtcDateTime `
    $document.conformance.started_utc
$completed = ConvertTo-SporeSporeAttestationUtcDateTime `
    $document.conformance.completed_utc
$durationDifference = [Math]::Abs(
    ($completed - $started).TotalSeconds -
    [double]$document.conformance.duration_seconds
)
Assert-Exact ($durationDifference -le 0.001) `
    "Historical V2 timestamp round trip changed."

$overwriteRejected = $false
try {
    [void](Assert-SporeSporeDurableAttestationOutputPath `
        -RepoRoot $repoRoot `
        -OutputPath $attestationPath)
} catch { $overwriteRejected = $true }
Assert-Exact $overwriteRejected "Historical V2 artifact could be overwritten."

foreach ($claim in $document.claims.Keys) {
    Assert-Exact (-not [bool]$document.claims[$claim]) `
        "Historical V2 artifact inflated claim: $claim"
}
Assert-Exact (
    [bool]$closure.postpublication_verification.production_verifier_ok -and
    @($closure.postpublication_verification.failure_codes).Count -eq 0 -and
    [bool]$closure.postpublication_verification.all_claims_false -and
    [bool]$closure.postpublication_verification.
        production_lock_reacquired_after_completion -and
    -not [bool]$closure.postpublication_verification.
        postcompletion_abandoned_owner_recovered -and
    [bool]$closure.immutable_disposition.
        attestation_valid_for_closed_source_and_bound_hosts -and
    [bool]$closure.immutable_disposition.operational_safeguard_commissioned -and
    -not [bool]$closure.immutable_disposition.
        historical_attestation_authorizes_later_source -and
    -not [bool]$closure.immutable_disposition.physical_acceptance_authority
) "Historical V2 commissioning or nonclaim boundary changed."

Write-Host (
    "FULL_CONFORMANCE_ATTESTATION_V2_CLOSURE_PASS " +
    "status=positive-infrastructure source=0513be82 duration=855.3993872 " +
    "serialized_verifier=True powershell_bound=True lock_released=True " +
    "one_shot_worlds=0 physical_authority=False"
)

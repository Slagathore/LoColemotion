#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
. (Join-Path $repoRoot "sdk\locomotion_operation_lock.ps1")
. (Join-Path $repoRoot "sdk\locomotion_full_conformance_attestation.ps1")
$contract = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "sdk\locomotion_operation_attestation_contract.json"
) | ConvertFrom-Json -AsHashtable -Depth 64

function Assert-Exact([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Copy-Value([object]$Value) {
    return $Value | ConvertTo-Json -Depth 64 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 64
}

$source = Copy-Value (Get-SporeSporeAttestationSourceIdentity -RepoRoot $repoRoot)
# The constructor preflight must be runnable before these new files are
# committed. Its document is explicitly test-only; production publication and
# file verification independently require a clean pushed live source.
$source.worktree_clean = $true
$source.clean_pushed_live = $true
$source.status_entries = @()
$godotIdentity = Get-SporeSporeAttestationGodotIdentity -Godot $Godot
$powerShellIdentity = Get-SporeSporeAttestationPowerShellIdentity
$bindings = @(
    foreach ($relativePath in @(
        "sdk/run_conformance.ps1",
        "sdk/locomotion_operation_lock.ps1",
        "sdk/locomotion_full_conformance_attestation.ps1",
        "sdk/locomotion_operation_attestation_contract.json"
    )) {
        $absolutePath = Join-Path $repoRoot $relativePath
        [ordered]@{
            path = $relativePath
            raw_sha256 = Get-SporeSporeSha256 $absolutePath
            git_blob_oid = (& git -C $repoRoot hash-object $absolutePath).Trim()
        }
    }
)
Assert-Exact (
    [string]$contract.schema_version -ceq
        "sporespore_locomotion_operation_attestation_contract_v2" -and
    [string]$contract.operation_lock.mutex_name -ceq
        (Get-SporeSporeLocomotionOperationMutexName) -and
    [bool]$contract.durable_attestation.skip_godot_forbidden -and
    @($contract.durable_attestation.required_source_bindings).Count -eq 4 -and
    @($contract.durable_attestation.required_host_bindings.godot).Count -eq 3 -and
    @($contract.durable_attestation.required_host_bindings.powershell).Count -eq 5 -and
    [bool]$contract.durable_attestation.
        serialized_temporary_file_must_verify_before_atomic_publication
) "Operation/attestation contract identity changed."
$lock = [ordered]@{
    schema_version = "sporespore_locomotion_operation_lock_receipt_v1"
    acquired = $true
    role = "conformance"
    mutex_name = Get-SporeSporeLocomotionOperationMutexName
    created_new = $true
    abandoned_owner_recovered = $false
    owner_process_id = $PID
    owner_session_id = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
    acquired_utc = [DateTime]::UtcNow.AddMinutes(-1).ToString("o")
    test_only = $false
    physical_acceptance_authority = $false
}
$started = [DateTime]::UtcNow.AddMinutes(-1)
$completed = [DateTime]::UtcNow
$document = New-SporeSporeFullConformanceAttestationDocument `
    -Source $source `
    -GodotIdentity $godotIdentity `
    -PowerShellIdentity $powerShellIdentity `
    -SourceBindings $bindings `
    -OperationLock $lock `
    -StartedUtc $started `
    -CompletedUtc $completed `
    -TestOnly
$perfect = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $document `
    -ExpectedSource $source `
    -ExpectedGodotIdentity $godotIdentity `
    -ExpectedPowerShellIdentity $powerShellIdentity `
    -ExpectedSourceBindings $bindings `
    -AllowTestOnly
Assert-Exact ([bool]$perfect.ok) "Perfect synthetic full-conformance attestation failed."

$serializedDocument = $document | ConvertTo-Json -Depth 64 |
    ConvertFrom-Json -AsHashtable -Depth 64
$serializedRoundTrip = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $serializedDocument `
    -ExpectedSource $source `
    -ExpectedGodotIdentity $godotIdentity `
    -ExpectedPowerShellIdentity $powerShellIdentity `
    -ExpectedSourceBindings $bindings `
    -AllowTestOnly
Assert-Exact ([bool]$serializedRoundTrip.ok) `
    "Serialized full-conformance attestation did not verify after JSON round-trip."

$productionRejectsTest = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $document `
    -ExpectedSource $source `
    -ExpectedGodotIdentity $godotIdentity `
    -ExpectedPowerShellIdentity $powerShellIdentity `
    -ExpectedSourceBindings $bindings
Assert-Exact (
    -not [bool]$productionRejectsTest.ok -and
    @($productionRejectsTest.failure_codes) -contains "TEST_ATTESTATION_FORBIDDEN"
) "Production verifier accepted a test-only attestation."

$sourceTamper = Copy-Value $document
$sourceTamper.source.commit = "0" * 40
$sourceRejected = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $sourceTamper -ExpectedSource $source `
    -ExpectedGodotIdentity $godotIdentity `
    -ExpectedPowerShellIdentity $powerShellIdentity `
    -ExpectedSourceBindings $bindings `
    -AllowTestOnly
Assert-Exact (-not [bool]$sourceRejected.ok) "Source tamper was accepted."

$godotTamper = Copy-Value $document
$godotTamper.godot.executable_sha256 = "sha256:" + ("0" * 64)
$godotRejected = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $godotTamper -ExpectedSource $source `
    -ExpectedGodotIdentity $godotIdentity `
    -ExpectedPowerShellIdentity $powerShellIdentity `
    -ExpectedSourceBindings $bindings `
    -AllowTestOnly
Assert-Exact (-not [bool]$godotRejected.ok) "Godot tamper was accepted."

$powerShellTamper = Copy-Value $document
$powerShellTamper.powershell.executable_sha256 = "sha256:" + ("0" * 64)
$powerShellRejected = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $powerShellTamper -ExpectedSource $source `
    -ExpectedGodotIdentity $godotIdentity `
    -ExpectedPowerShellIdentity $powerShellIdentity `
    -ExpectedSourceBindings $bindings `
    -AllowTestOnly
Assert-Exact (-not [bool]$powerShellRejected.ok) `
    "PowerShell identity tamper was accepted."

$bindingTamper = Copy-Value $document
$bindingTamper.source_bindings[0].raw_sha256 = "sha256:" + ("0" * 64)
$bindingRejected = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $bindingTamper -ExpectedSource $source `
    -ExpectedGodotIdentity $godotIdentity `
    -ExpectedPowerShellIdentity $powerShellIdentity `
    -ExpectedSourceBindings $bindings `
    -AllowTestOnly
Assert-Exact (-not [bool]$bindingRejected.ok) "Source-binding tamper was accepted."

$skipTamper = Copy-Value $document
$skipTamper.conformance.skip_godot = $true
$skipTamper.conformance.godot_including = $false
$skipRejected = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $skipTamper -ExpectedSource $source `
    -ExpectedGodotIdentity $godotIdentity `
    -ExpectedPowerShellIdentity $powerShellIdentity `
    -ExpectedSourceBindings $bindings `
    -AllowTestOnly
Assert-Exact (-not [bool]$skipRejected.ok) "Skip-Godot attestation was accepted."

$claimTamper = Copy-Value $document
$claimTamper.claims.walking_acceptance = $true
$claimRejected = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $claimTamper -ExpectedSource $source `
    -ExpectedGodotIdentity $godotIdentity `
    -ExpectedPowerShellIdentity $powerShellIdentity `
    -ExpectedSourceBindings $bindings `
    -AllowTestOnly
Assert-Exact (-not [bool]$claimRejected.ok) "Inflated attestation claim was accepted."

$missingClaim = Copy-Value $document
$missingClaim.claims.Remove("walking_acceptance")
$missingClaimRejected = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $missingClaim -ExpectedSource $source `
    -ExpectedGodotIdentity $godotIdentity `
    -ExpectedPowerShellIdentity $powerShellIdentity `
    -ExpectedSourceBindings $bindings `
    -AllowTestOnly
Assert-Exact (
    -not [bool]$missingClaimRejected.ok -and
    @($missingClaimRejected.failure_codes) -contains "CLAIM_SCHEMA"
) "Attestation with a missing claim field was accepted."

$extraClaim = Copy-Value $document
$extraClaim.claims.unexpected_claim = $false
$extraClaimRejected = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $extraClaim -ExpectedSource $source `
    -ExpectedGodotIdentity $godotIdentity `
    -ExpectedPowerShellIdentity $powerShellIdentity `
    -ExpectedSourceBindings $bindings `
    -AllowTestOnly
Assert-Exact (
    -not [bool]$extraClaimRejected.ok -and
    @($extraClaimRejected.failure_codes) -contains "CLAIM_SCHEMA"
) "Attestation with an extra claim field was accepted."

$campaignTamper = Copy-Value $document
$campaignTamper.conformance.one_shot_physical_campaign_executed = $true
$campaignRejected = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $campaignTamper -ExpectedSource $source `
    -ExpectedGodotIdentity $godotIdentity `
    -ExpectedPowerShellIdentity $powerShellIdentity `
    -ExpectedSourceBindings $bindings `
    -AllowTestOnly
Assert-Exact (-not [bool]$campaignRejected.ok) `
    "Attestation claiming a one-shot physical campaign was accepted."

$durationTamper = Copy-Value $document
$durationTamper.conformance.duration_seconds = 1.0
$durationRejected = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $durationTamper -ExpectedSource $source `
    -ExpectedGodotIdentity $godotIdentity `
    -ExpectedPowerShellIdentity $powerShellIdentity `
    -ExpectedSourceBindings $bindings `
    -AllowTestOnly
Assert-Exact (-not [bool]$durationRejected.ok) "Timestamp/duration tamper was accepted."

$lockTamper = Copy-Value $document
$lockTamper.operation_lock.mutex_name = "Local\wrong"
$lockRejected = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $lockTamper -ExpectedSource $source `
    -ExpectedGodotIdentity $godotIdentity `
    -ExpectedPowerShellIdentity $powerShellIdentity `
    -ExpectedSourceBindings $bindings `
    -AllowTestOnly
Assert-Exact (-not [bool]$lockRejected.ok) "Operation-lock tamper was accepted."

$nondurableRejected = $false
try {
    [void](Assert-SporeSporeDurableAttestationOutputPath `
        -RepoRoot $repoRoot `
        -OutputPath (Join-Path $repoRoot "sdk\target\not-durable.json"))
} catch { $nondurableRejected = $true }
Assert-Exact $nondurableRejected "A nondurable attestation output path was accepted."

$forbiddenOutput = Join-Path (
    Split-Path -Parent $repoRoot
) (
    "SporeSpore_Evidence\full-conformance-forbidden-test-" +
    [guid]::NewGuid().ToString("N") + "\attestation.json"
)
$skipEntrypointOutput = @(
    & pwsh -NoProfile -File (Join-Path $repoRoot "sdk\run_conformance.ps1") `
        -SkipGodot `
        -DurableAttestationOutput $forbiddenOutput 2>&1
)
$skipEntrypointRejected = (
    $LASTEXITCODE -ne 0 -and
    ($skipEntrypointOutput -join [Environment]::NewLine) -match
        "cannot be written with -SkipGodot" -and
    -not (Test-Path -LiteralPath $forbiddenOutput)
)
Assert-Exact $skipEntrypointRejected `
    "The real conformance entrypoint accepted a Skip-Godot attestation."

Write-Host (
    "FULL_CONFORMANCE_ATTESTATION_PREFLIGHT_PASS perfect=True " +
    "json_roundtrip=True " +
    "test_receipt_production_rejected=True source_tamper=True godot_tamper=True " +
    "powershell_tamper=True " +
    "binding_tamper=True skip_godot=True claim_inflation=True " +
    "claim_schema=True campaign_execution_veto=True worlds=0 " +
    "duration_tamper=True lock_tamper=True nondurable_path=True " +
    "skip_godot_entrypoint=True " +
    "physical_authority=False"
)

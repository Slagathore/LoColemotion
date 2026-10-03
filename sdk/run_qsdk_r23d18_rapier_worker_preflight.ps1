#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$manifest = Join-Path $sdkRoot "Cargo.toml"
$binary = Join-Path $sdkRoot "target\release\qsdk_r23d18_physical.exe"
$publisher = Join-Path $sdkRoot "publish_qsdk_r23d18_trace.ps1"
$stageId = "finite_three_engine_confirmation_receipt_integrity_recovery"
$campaignId = "QSDK-R23D18-RECEIPT-INTEGRITY-RECOVERY-THREE-ENGINE-TURN-CONFIRMATION"

function Assert-R23D18Rapier([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-R23D18Rapier([string[]]$Arguments, [string]$Label) {
    $output = & $binary @Arguments 2>&1 | Out-String
    return [ordered]@{
        label = $Label
        exit_code = $LASTEXITCODE
        output = $output
    }
}

function Read-R23D18RapierMarker(
    [Collections.IDictionary]$Execution,
    [string]$Prefix
) {
    $matches = @(([string]$Execution.output -split "\r?\n") | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D18Rapier ($matches.Count -eq 1) (
        "Expected one $Prefix marker from $($Execution.label): $($Execution.output)"
    )
    return $matches[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

foreach ($path in @(
    $manifest,
    $publisher,
    (Join-Path $sdkRoot "adapters\rapier\src\bin\qsdk_r23d18_physical.rs"),
    (Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d14_tight_gated_horizon.rs"),
    (Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d18_composition_recovery.rs"),
    (Join-Path $sdkRoot "adapters\rapier\src\qsdk_r23d3_phase_balanced\r23d18_physical.rs")
)) {
    Assert-R23D18Rapier (Test-Path -LiteralPath $path -PathType Leaf) (
        "Rapier input missing: $path"
    )
}
Assert-R23D18Rapier (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "Rapier repository identity changed"

$testOutput = & cargo test --quiet --locked --offline `
    --manifest-path $manifest --package sporespore-rapier-adapter `
    r23d18_physical --no-fail-fast 2>&1 | Out-String
Assert-R23D18Rapier ($LASTEXITCODE -eq 0) "Rapier tests failed: $testOutput"
& cargo build --quiet --release --locked --offline `
    --manifest-path $manifest --package sporespore-rapier-adapter `
    --bin qsdk_r23d18_physical
Assert-R23D18Rapier ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $binary)) (
    "Rapier worker build failed"
)

$sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim()
$compiledRepoRoot = ""
foreach ($armId in @("reference_zero", "positive_heading", "negative_heading")) {
    $execution = Invoke-R23D18Rapier @(
        "preflight", "--stage", $stageId, "--arm", $armId
    ) "$stageId`:$armId"
    Assert-R23D18Rapier ($execution.exit_code -eq 0) "Rapier preflight failed: $armId"
    $receipt = Read-R23D18RapierMarker $execution "QSDK_R23D18_RAPIER_PREFLIGHT "
    Assert-R23D18Rapier (
        [string]$receipt.campaign_id -ceq $campaignId -and
        [string]$receipt.cell_id -ceq "rapier_parry__tight_gated_horizon__$armId" -and
        -not [string]::IsNullOrWhiteSpace(
            [string]$receipt.compiled_worker_repo_root_spelling
        ) -and
        [bool]$receipt.r23d14_tight_gated_horizon_inherited_unchanged -and
        [bool]$receipt.r23d18_composition_recovery_identity_enabled -and
        [bool]$receipt.physical_worker_implemented -and
        -not [bool]$receipt.physical_execution_authorized -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0
    ) "Rapier preflight receipt changed: $armId"
    if ([string]::IsNullOrWhiteSpace($compiledRepoRoot)) {
        $compiledRepoRoot = [string]$receipt.compiled_worker_repo_root_spelling
    } else {
        Assert-R23D18Rapier (
            $compiledRepoRoot -ceq [string]$receipt.compiled_worker_repo_root_spelling
        ) "Compiled worker repository-root spelling changed across arms"
    }
}

$canaryBase = [IO.Path]::GetFullPath(
    (Join-Path $sdkRoot "target\qsdk-r23d18-publisher-path-canary")
).TrimEnd('\')
$canaryRoot = Join-Path $canaryBase ([guid]::NewGuid().ToString("N"))
$artifact = Join-Path $canaryRoot "trace.ndjson"
$artifactText = "[]`n"
try {
    [void][IO.Directory]::CreateDirectory($canaryRoot)
    [IO.File]::WriteAllText($artifact, $artifactText, [Text.UTF8Encoding]::new($false))
    $digest = "sha256:" + (
        Get-FileHash -LiteralPath $artifact -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    $length = (Get-Item -LiteralPath $artifact).Length
    $positiveRoots = @($repoRoot, $compiledRepoRoot)
    $positiveCount = 0
    foreach ($rootSpelling in $positiveRoots) {
        $evidence = Join-Path $canaryRoot "evidence-positive-$positiveCount"
        [void][IO.Directory]::CreateDirectory($evidence)
        $output = & pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File $publisher `
            -RepoRoot $rootSpelling -ArtifactPath $artifact `
            -ExpectedSha256 $digest -ExpectedByteLength $length `
            -TestOnly -EvidenceRootOverride $evidence 2>&1 | Out-String
        Assert-R23D18Rapier ($LASTEXITCODE -eq 0) (
            "Rapier publisher path positive failed: $rootSpelling $output"
        )
        Assert-R23D18Rapier (
            @($output -split "\r?\n" | Where-Object {
                $_.StartsWith("QSDK_R23D18_TRACE_CAS ", [StringComparison]::Ordinal)
            }).Count -eq 1
        ) "Rapier publisher path positive marker changed: $rootSpelling"
        $positiveCount += 1
    }
    Assert-R23D18Rapier ($compiledRepoRoot.StartsWith('\\?\')) (
        "Compiled worker did not expose the extended local-drive spelling"
    )
    $negativeRoots = @(
        @{ root = $sdkRoot; message = "repository root mismatch" },
        @{ root = '\\?\UNC\server\share\SporeSpore'; message = "path identity kind is unsupported" },
        @{ root = '\\.\C:\SporeSpore'; message = "path identity kind is unsupported" }
    )
    $negativeCount = 0
    foreach ($case in $negativeRoots) {
        $evidence = Join-Path $canaryRoot "evidence-negative-$negativeCount"
        [void][IO.Directory]::CreateDirectory($evidence)
        $output = & pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File $publisher `
            -RepoRoot ([string]$case.root) -ArtifactPath $artifact `
            -ExpectedSha256 $digest -ExpectedByteLength $length `
            -TestOnly -EvidenceRootOverride $evidence 2>&1 | Out-String
        Assert-R23D18Rapier ($LASTEXITCODE -ne 0) (
            "Rapier publisher path negative passed unexpectedly: $($case.root)"
        )
        Assert-R23D18Rapier ($output.Contains([string]$case.message)) (
            "Rapier publisher path negative failure changed: $($case.root) $output"
        )
        $negativeCount += 1
    }
} finally {
    $resolvedCanaryRoot = [IO.Path]::GetFullPath($canaryRoot)
    $requiredPrefix = $canaryBase + [IO.Path]::DirectorySeparatorChar
    if ($resolvedCanaryRoot.StartsWith(
        $requiredPrefix,
        [StringComparison]::OrdinalIgnoreCase
    ) -and (Test-Path -LiteralPath $resolvedCanaryRoot)) {
        Remove-Item -LiteralPath $resolvedCanaryRoot -Recurse -Force
    }
}

$refusal = Invoke-R23D18Rapier @(
    "physical", "--stage", $stageId, "--arm", "negative_heading",
    "--source-commit", $sourceCommit
) "physical-refusal"
Assert-R23D18Rapier ($refusal.exit_code -ne 0) "Rapier physical route did not refuse"
$terminal = Read-R23D18RapierMarker $refusal "QSDK_R23D18_RAPIER_TERMINAL "
Assert-R23D18Rapier (
    [string]$terminal.failure_code -ceq "QSDK_R23D18_RAP_PHYSICAL_AUTHORIZATION_REQUIRED" -and
    [int]$terminal.world_attempt_count -eq 0 -and
    [int]$terminal.world_build_count -eq 0
) "Rapier physical refusal changed"

Write-Host (
    "QSDK_R23D18_RAPIER_WORKER_PASS identities=3 tests=3 " +
    "publisher_path_positives=2 publisher_path_mutations=3 " +
    "temporal_steps=960 models=0 worlds=0 physical_authority=False"
)

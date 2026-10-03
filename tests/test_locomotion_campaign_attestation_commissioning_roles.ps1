#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("worker", "evaluator", "supervisor")]
    [string]$Role
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$implementationPath = Join-Path `
    $sdkRoot "turning\r23d17_physical_implementation_contract_v1.json"
$closurePath = Join-Path $sdkRoot "turning\r23d17_physical_closure_v1.json"
$sourceCommit = "d1f247b6147dabfd05123b1242bc650de3905f9a"
$campaignId =
    "QSDK-R23D17-LIVE-COMPOSITION-RECOVERY-THREE-ENGINE-TURN-CONFIRMATION"

function Assert-Lca1Role([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "LCA1_COMMISSIONING_ROLE role=$Role $Message"
    }
}

function Get-Lca1RawSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-Lca1GitBlobRawSha256([string]$RelativePath) {
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
        Assert-Lca1Role $process.Start() "could not start Git blob reader"
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try {
            $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream)
        } finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-Lca1Role ($process.ExitCode -eq 0) (
            "Git blob read failed for $RelativePath`: $stderr"
        )
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

foreach ($path in @($implementationPath, $closurePath)) {
    Assert-Lca1Role (Test-Path -LiteralPath $path -PathType Leaf) `
        "required authority is missing: $path"
}
$implementation = Get-Content -LiteralPath $implementationPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Lca1Role (
    [string]$implementation.schema_version -ceq
        "sporespore_qsdk_r23d17_physical_implementation_contract_v1" -and
    [string]$implementation.campaign_id -ceq $campaignId -and
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d17_physical_confirmation_closure_v1" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.source_identity.commit -ceq $sourceCommit -and
    [bool]$closure.immutability.same_identity_rerun_forbidden -and
    [bool]$closure.immutability.all_three_physical_worker_closure_interlocks_required -and
    -not [bool]$closure.claims.portable_basic_turning -and
    -not [bool]$closure.claims.cross_engine_equivalence -and
    -not [bool]$closure.claims.release_authorized
) "R23D17 closed-lineage boundary changed"

$checkedPaths = [Collections.Generic.List[string]]::new()
switch ($Role) {
    "worker" {
        Assert-Lca1Role (@($implementation.workers).Count -eq 3) `
            "worker contract count changed"
        foreach ($worker in @($implementation.workers)) {
            $path = if ($worker.Contains("physical_implementation_path")) {
                [string]$worker.physical_implementation_path
            } else { [string]$worker.implementation_path }
            Assert-Lca1Role (-not [string]::IsNullOrWhiteSpace($path)) `
                "worker implementation path is missing"
            $checkedPaths.Add($path)
        }
        Assert-Lca1Role (
            [int]$implementation.authorization.world_attempt_count -eq 0 -and
            [int]$implementation.authorization.world_build_count -eq 0 -and
            -not [bool]$implementation.authorization.physical_execution_authorized
        ) "prospective worker authority was inflated"
    }
    "evaluator" {
        $checkedPaths.Add([string]$implementation.production_evaluator.path)
        Assert-Lca1Role (
            -not [bool]$implementation.production_evaluator.
                worker_authored_outcome_bits_authoritative -and
            [bool]$implementation.production_evaluator.
                validates_complete_trace_before_terminal_interpretation -and
            -not [bool]$implementation.production_evaluator.
                formal_cross_engine_equivalence_inference_performed
        ) "evaluator boundary changed"
    }
    "supervisor" {
        $checkedPaths.Add([string]$implementation.supervisor.path)
        Assert-Lca1Role (
            [int]$implementation.supervisor.declared_world_count -eq 9 -and
            [bool]$implementation.supervisor.all_cells_serial_without_outcome_early_stop -and
            -not [bool]$implementation.supervisor.parallel_execution_permitted -and
            -not [bool]$implementation.supervisor.replacement_or_selective_rerun_permitted -and
            [bool]$implementation.runtime_freeze.global_operation_lock_required
        ) "supervisor serialization or lock boundary changed"
    }
}

foreach ($relativePath in $checkedPaths) {
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Lca1Role (Test-Path -LiteralPath $absolutePath -PathType Leaf) `
        "bound source is missing: $relativePath"
    Assert-Lca1Role (
        (Get-Lca1RawSha256 $absolutePath) -ceq
            (Get-Lca1GitBlobRawSha256 $relativePath)
    ) "live source differs from frozen R23D17 blob: $relativePath"
}

$marker = "LCA1_COMMISSIONING_$($Role.ToUpperInvariant())_PASS"
Write-Host (
    "$marker campaign=R23D17 source=$sourceCommit bound_sources=$($checkedPaths.Count) " +
    "same_identity_closed=True worlds=0 physical_authority=False release_authority=False"
)

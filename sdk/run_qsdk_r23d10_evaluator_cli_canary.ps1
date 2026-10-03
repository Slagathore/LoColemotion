#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$script = Join-Path $sdkRoot "turning\r23d10_evaluator_cli.py"
$test = Join-Path $sdkRoot "turning\test_r23d10_evaluator_cli.py"
$python = (Get-Command python -ErrorAction Stop).Source

function Assert-R23D10Cli([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

Assert-R23D10Cli (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D10 evaluator CLI repository identity changed"

$unitOutput = & $python -m unittest -v $test 2>&1 | Out-String
Assert-R23D10Cli ($LASTEXITCODE -eq 0) (
    "QSDK-R23D10 evaluator CLI tests failed: $unitOutput"
)

$commands = [ordered]@{
    "evaluate-stage-a" = "QSDK_R23D10_STAGE_A_EVALUATION "
    "evaluate-complete" = "QSDK_R23D10_COMPLETE_EVALUATION "
}
foreach ($entry in $commands.GetEnumerator()) {
    $output = & $python $script $entry.Key --zero-world-canary 2>&1 | Out-String
    Assert-R23D10Cli ($LASTEXITCODE -eq 0) (
        "QSDK-R23D10 evaluator command failed: $($entry.Key); $output"
    )
    $lines = @($output -split "\r?\n")
    $matches = @($lines | Where-Object {
        $_.StartsWith([string]$entry.Value, [StringComparison]::Ordinal)
    })
    $generic = @($lines | Where-Object {
        $_.StartsWith("QSDK_R23D10_EVALUATION ", [StringComparison]::Ordinal)
    })
    Assert-R23D10Cli ($matches.Count -eq 1 -and $generic.Count -eq 0) (
        "QSDK-R23D10 evaluator producer/consumer marker mismatch: $($entry.Key)"
    )
    $receipt = $matches[0].Substring(([string]$entry.Value).Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R23D10Cli (
        [string]$receipt.command -ceq [string]$entry.Key -and
        [bool]$receipt.zero_world_canary -and
        -not [bool]$receipt.production_evaluator_implemented -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0
    ) "QSDK-R23D10 evaluator CLI receipt changed: $($entry.Key)"
}

Write-Host (
    "QSDK_R23D10_EVALUATOR_CLI_CANARY_PASS commands=2 exact_markers=2 " +
    "generic_markers=0 evaluator=0 models=0 worlds=0 physical_authority=False"
)

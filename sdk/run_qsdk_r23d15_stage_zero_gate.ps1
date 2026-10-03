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
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$auditPath = Join-Path $repoRoot "tests\test_qsdk_r23d15_composition_recovery.ps1"
$output = @(
    & pwsh -NoLogo -NoProfile -File $auditPath -Godot $Godot 2>&1
) -join "`n"
if (
    $LASTEXITCODE -ne 0 -or
    -not $output.Contains("QSDK_R23D15_COMPOSITION_RECOVERY_PASS")
) {
    throw "QSDK-R23D15 composition-recovery audit failed: $output"
}
$global:LASTEXITCODE = 0

Write-Host (
    "QSDK_R23D15_STAGE_ZERO_GATE_PASS predecessor=consumed-invalid " +
    "scientific_question_changed=False godot_canaries=2 godot_mutations=1 " +
    "rapier_arms=3 rapier_tests=4 workers=0 physical_processes=0 " +
    "models=0 worlds=0 turning=False equivalence=False physical_authority=False"
)

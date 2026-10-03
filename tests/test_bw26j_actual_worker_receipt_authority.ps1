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
$runnerPath = Join-Path $repoRoot `
    "sdk\run_balanced_wave_bw26j_actual_worker_receipt_authority_commissioning.ps1"

& pwsh -NoProfile -File $runnerPath -Godot $Godot
if ($LASTEXITCODE -ne 0) {
    throw "BW26J actual-worker receipt authority commissioning failed."
}

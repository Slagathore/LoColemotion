[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64.exe"
    ),
    [switch]$SelfTest,
    [switch]$SafeProcessSelfTest
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$scene = "res://scenes/tools/locomotion_experiment_workbench.tscn"
$expectedRemote = "https://github.com/Slagathore/LoColemotion.git"

if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
    throw "Godot 4.7 executable does not exist: $Godot"
}

$actualRoot = [System.IO.Path]::GetFullPath(
    (& git -C $repoRoot rev-parse --show-toplevel).Trim()
)
$actualRemote = (& git -C $repoRoot remote get-url origin).Trim()
if ($actualRoot -cne $repoRoot -or $actualRemote -cne $expectedRemote) {
    throw "Refusing to open the workbench outside the canonical SporeSpore repository."
}

if ($SelfTest -or $SafeProcessSelfTest) {
    $consoleGodot = if ($Godot.EndsWith(
        "_console.exe",
        [StringComparison]::OrdinalIgnoreCase
    )) {
        $Godot
    }
    else {
        $Godot.Substring(0, $Godot.Length - ".exe".Length) + "_console.exe"
    }
    if (-not (Test-Path -LiteralPath $consoleGodot -PathType Leaf)) {
        throw "Godot console executable does not exist: $consoleGodot"
    }
    $selfTestArgument = if ($SafeProcessSelfTest) {
        "--workbench-safe-process-self-test"
    }
    else {
        "--workbench-self-test"
    }
    $expectedMarker = if ($SafeProcessSelfTest) {
        "LOCOMOTION_EXPERIMENT_WORKBENCH_SAFE_PROCESS_PASS"
    }
    else {
        "LOCOMOTION_EXPERIMENT_WORKBENCH_PASS"
    }
    $output = @(
        & $consoleGodot `
            --headless `
            --path $repoRoot `
            --scene $scene `
            --quit-after 3600 `
            -- `
            $selfTestArgument 2>&1
    )
    $exitCode = $LASTEXITCODE
    $text = $output -join [Environment]::NewLine
    $output | Write-Host
    if (
        $exitCode -ne 0 -or
        $text -match "SCRIPT ERROR|ERROR:" -or
        $text -notmatch $expectedMarker
    ) {
        throw "Locomotion experiment workbench self-test failed."
    }
    exit 0
}

$arguments = @(
    "--path"
    $repoRoot
    "--scene"
    $scene
    "--resolution"
    "1600x950"
)

Write-Host "Opening the SporeSpore Locomotion Experiment Workbench."
Write-Host "Repository: $repoRoot"
Write-Host "Scene: $scene"
Write-Host "No physics campaign runs until you select and authorize one in the UI."

[void](Start-Process `
    -FilePath $Godot `
    -ArgumentList $arguments `
    -WorkingDirectory $repoRoot)

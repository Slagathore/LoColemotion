#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("worker", "evaluator", "supervisor")]
    [string]$Role,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$campaignId = "QSDK-R23D23-IMPLEMENTATION-RECOVERY-TRANSFER-CONFORMANCE"
$resolvedPython = [IO.Path]::GetFullPath((Get-Command $Python -ErrorAction Stop).Source)

function Assert-R23D23CampaignRole([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D23 campaign role: $Message" }
}

function Invoke-R23D23CampaignRolePowerShell {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Marker,
        [string[]]$Arguments = @()
    )
    $output = @(& pwsh -NoLogo -NoProfile -File $Path @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    foreach ($line in $output) { Write-Host ([string]$line) }
    Assert-R23D23CampaignRole ($exitCode -eq 0) "child failed: $Path"
    Assert-R23D23CampaignRole (
        @($output | Where-Object {
            ([string]$_).StartsWith($Marker, [StringComparison]::Ordinal)
        }).Count -eq 1
    ) "child marker changed: $Marker"
}

switch ($Role) {
    "worker" {
        Invoke-R23D23CampaignRolePowerShell `
            -Path (Join-Path $sdkRoot "run_qsdk_r23d23_mujoco_worker_preflight.ps1") `
            -Marker "QSDK_R23D23_MUJOCO_WORKER_PASS "
        Invoke-R23D23CampaignRolePowerShell `
            -Path (Join-Path $sdkRoot "run_qsdk_r23d23_rapier_worker_preflight.ps1") `
            -Marker "QSDK_R23D23_RAPIER_WORKER_PASS "
        Write-Host (
            "QSDK_R23D23_CAMPAIGN_WORKER_ROLE_PASS campaign=$campaignId " +
            "workers=2 authorization_functions=2 historical_godot_binding=1 " +
            "worlds=0 physical_authority=False"
        )
    }
    "evaluator" {
        $oldPythonPath = $env:PYTHONPATH
        try {
            $env:PYTHONPATH = Join-Path $sdkRoot "turning"
            $output = @(& $resolvedPython -m unittest -v `
                sdk.turning.test_r23d23_physical_evaluator 2>&1)
            $exitCode = $LASTEXITCODE
        } finally {
            $env:PYTHONPATH = $oldPythonPath
        }
        foreach ($line in $output) { Write-Host ([string]$line) }
        Assert-R23D23CampaignRole ($exitCode -eq 0) "production evaluator tests failed"
        Assert-R23D23CampaignRole (
            @($output | Where-Object { ([string]$_) -match '^Ran 10 tests' }).Count -eq 1
        ) "production evaluator test count changed"
        Write-Host (
            "QSDK_R23D23_CAMPAIGN_EVALUATOR_ROLE_PASS campaign=$campaignId " +
            "tests=10 worlds=0 physical_authority=False"
        )
    }
    "supervisor" {
        Invoke-R23D23CampaignRolePowerShell `
            -Path (Join-Path $sdkRoot "run_qsdk_r23d23_supervisor.ps1") `
            -Marker "QSDK_R23D23_CAMPAIGN_SUPERVISOR_ROLE_PASS " `
            -Arguments @(
                "-CampaignRolePreflight", "-Godot", $Godot,
                "-Python", $resolvedPython
        )
        Write-Host (
            "QSDK_R23D23_CAMPAIGN_SUPERVISOR_GATE_PASS campaign=$campaignId " +
            "supervisor=1 adoption_required=True worlds=0 physical_authority=False"
        )
    }
}

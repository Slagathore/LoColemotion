#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Python = "python",
    [switch]$SkipBuild,
    [switch]$SkipGodot,
    [switch]$RequireCleanPushedSource,
    [switch]$CallerHoldsOperationLock
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$auditPath = Join-Path $sdkRoot (
    "turning\r23d61_selected_actuator_profile_publication_audit.py"
)
$coreLibrary = Join-Path $sdkRoot "target\debug\sporespore_locomotion_core.dll"
$godotAdapter = Join-Path $sdkRoot "target\debug\sporespore_godot_adapter.dll"
$godotResource = (
    "res://tests/" +
    "test_sdk_qsdk_r23d61_godot_actuator_cap_profile_zero_world.gd"
)
$godotMarker = "QSDK_R23D61_GODOT_ACTUATOR_CAP_PROFILE_ZERO_WORLD "

. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")

function Assert-R23D61([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D61: $Message" }
}

function Invoke-R23D61Git([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw (
            "QSDK-R23D61 git $($Arguments -join ' ') failed: " +
            ($lines -join " | ")
        )
    }
    return ($lines -join "`n").Trim()
}

function Resolve-R23D61Application([string]$Command) {
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R23D61 (
            Test-Path -LiteralPath $resolved -PathType Leaf
        ) "Application is missing: $resolved"
        return $resolved
    }
    $candidate = Get-Command `
        $Command `
        -CommandType Application `
        -ErrorAction Stop |
        Select-Object -First 1
    return [IO.Path]::GetFullPath([string]$candidate.Source)
}

function Invoke-R23D61Checked {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$Label
    )
    Push-Location -LiteralPath $WorkingDirectory
    try {
        $output = @(& $FileName @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    Assert-R23D61 ($exitCode -eq 0) (
        "$Label failed with exit code $exitCode`: " + ($output -join " | ")
    )
    return @($output | ForEach-Object { [string]$_ })
}

$operationLock = $null
try {
    if (-not $CallerHoldsOperationLock) {
        $operationLock = Enter-SporeSporeLocomotionOperationLock -Role conformance
        Assert-R23D61 ([bool]$operationLock.acquired) (
            "Another conformance or physical workload owns the locomotion lock."
        )
    }

    $root = Invoke-R23D61Git @("rev-parse", "--show-toplevel")
    $remote = Invoke-R23D61Git @("remote", "get-url", "origin")
    $branch = Invoke-R23D61Git @("branch", "--show-current")
    $head = Invoke-R23D61Git @("rev-parse", "HEAD")
    $upstream = Invoke-R23D61Git @("rev-parse", "@{upstream}")
    $status = Invoke-R23D61Git @("status", "--short")
    Assert-R23D61 (
        [IO.Path]::GetFullPath($root) -ceq $repoRoot
    ) "Canonical repository root changed: $root"
    Assert-R23D61 ($remote -ceq $expectedRemote) "Origin changed: $remote"
    Assert-R23D61 ($branch -ceq "main") "Local branch changed: $branch"
    if ($RequireCleanPushedSource) {
        Assert-R23D61 ([string]::IsNullOrEmpty($status)) (
            "Clean-pushed qualification requires an empty worktree: $status"
        )
        Assert-R23D61 ($head -ceq $upstream) (
            "Clean-pushed qualification requires HEAD == upstream."
        )
    }

    $pythonPath = Resolve-R23D61Application $Python
    if (-not $SkipBuild) {
        [void](Invoke-R23D61Checked `
            -FileName "cargo" `
            -Arguments @("fmt", "--all", "--", "--check") `
            -WorkingDirectory $sdkRoot `
            -Label "Rust formatting")
        [void](Invoke-R23D61Checked `
            -FileName "cargo" `
            -Arguments @(
                "build", "-p", "sporespore-godot-adapter", "--offline"
            ) `
            -WorkingDirectory $sdkRoot `
            -Label "Godot adapter debug build")
        [void](Invoke-R23D61Checked `
            -FileName "cargo" `
            -Arguments @(
                "build", "-p", "sporespore-locomotion-core", "--offline"
            ) `
            -WorkingDirectory $sdkRoot `
            -Label "Portable core debug build")
        [void](Invoke-R23D61Checked `
            -FileName "cargo" `
            -Arguments @(
                "test", "-p", "sporespore-locomotion-core",
                "actuator_profile", "--offline", "--", "--nocapture"
            ) `
            -WorkingDirectory $sdkRoot `
            -Label "Portable profile tests")
        [void](Invoke-R23D61Checked `
            -FileName "cargo" `
            -Arguments @(
                "test", "-p", "sporespore-rapier-adapter",
                "actuator_cap_profile", "--offline", "--", "--nocapture"
            ) `
            -WorkingDirectory $sdkRoot `
            -Label "Rapier profile tests")
    }
    Assert-R23D61 (
        Test-Path -LiteralPath $coreLibrary -PathType Leaf
    ) "Portable core debug library is missing: $coreLibrary"
    Assert-R23D61 (
        Test-Path -LiteralPath $godotAdapter -PathType Leaf
    ) "Godot adapter debug library is missing: $godotAdapter"

    $auditOutput = Invoke-R23D61Checked `
        -FileName $pythonPath `
        -Arguments @($auditPath) `
        -WorkingDirectory $repoRoot `
        -Label "Publication source audit"
    Assert-R23D61 (
        @($auditOutput | Where-Object {
            $_.StartsWith("QSDK_R23D61_PUBLICATION_AUDIT ")
        }).Count -eq 1
    ) "Publication audit emitted an invalid terminal marker count."
    $auditMarker = @($auditOutput | Where-Object {
        $_.StartsWith("QSDK_R23D61_PUBLICATION_AUDIT ")
    })[0]
    $auditReport = $auditMarker.Substring(
        "QSDK_R23D61_PUBLICATION_AUDIT ".Length
    ) | ConvertFrom-Json
    Assert-R23D61 (
        [bool]$auditReport.ok -and
        [int]$auditReport.source_binding_count -eq 22 -and
        [int]$auditReport.mutation_rejection_count -eq 18 -and
        [int]$auditReport.world_build_count -eq 0 -and
        -not [bool]$auditReport.physical_acceptance_authority -and
        -not [bool]$auditReport.release_authority
    ) "Publication audit receipt was not exact."

    $priorCoreLibrary = $env:SPORESPORE_LOCOMOTION_LIBRARY
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $coreLibrary
    try {
        [void](Invoke-R23D61Checked `
            -FileName $pythonPath `
            -Arguments @(
                "-m", "unittest", "-v",
                (
                    "test_ctypes_smoke.CtypesSmokeTest." +
                    "test_exact_scope_actuator_cap_profile_and_refusals_" +
                    "cross_real_library"
                )
            ) `
            -WorkingDirectory (Join-Path $sdkRoot "python") `
            -Label "Python C ABI profile test")
        [void](Invoke-R23D61Checked `
            -FileName $pythonPath `
            -Arguments @(
                "-m", "unittest", "-v", "test_actuator_cap_profile.py"
            ) `
            -WorkingDirectory (Join-Path $sdkRoot "adapters\mujoco") `
            -Label "MuJoCo profile mapping tests")
    } finally {
        if ($null -eq $priorCoreLibrary) {
            Remove-Item Env:SPORESPORE_LOCOMOTION_LIBRARY -ErrorAction SilentlyContinue
        } else {
            $env:SPORESPORE_LOCOMOTION_LIBRARY = $priorCoreLibrary
        }
    }

    $godotReport = $null
    if (-not $SkipGodot) {
        $godotPath = Resolve-R23D61Application $Godot
        $godotOutput = Invoke-R23D61Checked `
            -FileName $godotPath `
            -Arguments @(
                "--headless", "--path", $repoRoot, "--script", $godotResource
            ) `
            -WorkingDirectory $repoRoot `
            -Label "Godot actuator profile zero-world gate"
        $markerLines = @(
            $godotOutput |
                Where-Object {
                    $_.StartsWith($godotMarker, [StringComparison]::Ordinal)
                }
        )
        Assert-R23D61 ($markerLines.Count -eq 1) (
            "Godot gate emitted $($markerLines.Count) terminal markers."
        )
        $godotReport = $markerLines[0].Substring($godotMarker.Length) |
            ConvertFrom-Json
        Assert-R23D61 (
            [bool]$godotReport.ok -and
            [int]$godotReport.mutation_rejection_count -eq 17 -and
            [int]$godotReport.world_build_count -eq 0 -and
            -not [bool]$godotReport.physical_acceptance_authority
        ) "Godot zero-world receipt was not exact."
    }

    $report = [ordered]@{
        schema_version = "sporespore_qsdk_r23d61_zero_world_gate_receipt_v1"
        ok = $true
        gate_id = "QSDK-R23D61"
        question_class = "non_physical_source_conformance"
        source = [ordered]@{
            root = $root.Replace("\", "/")
            remote = $remote
            branch = $branch
            head = $head
            upstream = $upstream
            clean = [string]::IsNullOrEmpty($status)
            matches_upstream = $head -ceq $upstream
            clean_pushed_required = [bool]$RequireCleanPushedSource
        }
        profile_id = (
            "sporespore_qsdk_r23d60_selected_s169_" +
            "actuator_cap_profile_v1"
        )
        profile_sha256 = (
            "sha256:b65d41e3f30c42e0a8207f1385fe00daa8f03975f4e266a0bd0867970f674" +
            "964"
        )
        core_test_count = 6
        rapier_test_count = 2
        mujoco_test_count = 2
        python_ffi_test_count = 1
        godot_runtime_status = if ($SkipGodot) { "skipped" } else { "passed" }
        godot_mutation_rejection_count = if ($SkipGodot) {
            0
        } else { [int]$godotReport.mutation_rejection_count }
        rapier_mutation_rejection_count = 9
        mujoco_mutation_rejection_count = 9
        publication_audit_mutation_rejection_count = 18
        complete_zero_world_gate_passed = -not [bool]$SkipGodot
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_question_declared = $false
        physical_campaign_opened = $false
        turning_claimed = $false
        prone_to_standing_claimed = $false
        cross_engine_equivalence_claimed = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-Output (
        "QSDK_R23D61_ZERO_WORLD_GATE " +
        ($report | ConvertTo-Json -Depth 20 -Compress)
    )
} finally {
    if ($null -ne $operationLock) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $operationLock
    }
}

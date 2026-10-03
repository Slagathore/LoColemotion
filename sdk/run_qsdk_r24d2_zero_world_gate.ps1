#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Cargo = "cargo",
    [string]$Python = "python",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [switch]$RequireCleanPushedSource,
    [switch]$CallerHoldsOperationLock
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$manifestPath = Join-Path $sdkRoot "Cargo.toml"
$coreLibraryPath = Join-Path (
    $sdkRoot
) "target\debug\sporespore_locomotion_core.dll"
$mujocoTestPath = Join-Path (
    $sdkRoot
) "adapters\mujoco\test_recovery_capability.py"
$godotTestPath = "res://tests/test_sdk_qsdk_r24d2_godot_recovery_zero_world.gd"
$auditPath = Join-Path (
    $repoRoot
) "tests\test_qsdk_r24d2_portable_recovery_semantics.ps1"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$godotMarker = "QSDK_R24D2_GODOT_RECOVERY_ZERO_WORLD "
$auditMarker = "QSDK_R24D2_PORTABLE_RECOVERY_SEMANTICS_PASS "

. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")

function Assert-R24D2 {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "QSDK-R24D2: $Message" }
}

function Resolve-R24D2Application {
    param([Parameter(Mandatory)][string]$Command)
    if ([System.IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [System.IO.Path]::GetFullPath($Command)
        Assert-R24D2 (
            Test-Path -LiteralPath $resolved -PathType Leaf
        ) "Application is missing: $resolved"
        return $resolved
    }
    $candidate = Get-Command `
        -Name $Command `
        -CommandType Application `
        -ErrorAction Stop |
        Select-Object -First 1
    return [System.IO.Path]::GetFullPath([string]$candidate.Source)
}

function Get-R24D2GitValue {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-R24D2 ($LASTEXITCODE -eq 0) (
        "git $($Arguments -join ' ') failed: $($output -join ' | ')"
    )
    return ($output -join "`n").Trim()
}

function Invoke-R24D2Checked {
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
    }
    finally {
        Pop-Location
    }
    Assert-R24D2 ($exitCode -eq 0) (
        "$Label failed with exit code $exitCode`: $($output -join ' | ')"
    )
    return @($output | ForEach-Object { [string]$_ })
}

function Get-OneMarkerReceipt {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$Output,
        [Parameter(Mandatory)][string]$Prefix,
        [Parameter(Mandatory)][string]$Label
    )
    $markers = @($Output | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R24D2 ($markers.Count -eq 1) (
        "$Label emitted $($markers.Count) terminal markers."
    )
    return $markers[0].Substring($Prefix.Length) |
        ConvertFrom-Json -Depth 100
}

$operationLock = $null
$previousCoreLibrary = $null
$coreLibraryEnvironmentChanged = $false
try {
    if (-not $CallerHoldsOperationLock) {
        $operationLock = Enter-SporeSporeLocomotionOperationLock -Role conformance
        Assert-R24D2 ([bool]$operationLock.acquired) (
            "Another conformance or physical workload owns the locomotion lock."
        )
    }

    $root = Get-R24D2GitValue @("rev-parse", "--show-toplevel")
    $remote = Get-R24D2GitValue @("remote", "get-url", "origin")
    $branch = Get-R24D2GitValue @("branch", "--show-current")
    $head = Get-R24D2GitValue @("rev-parse", "HEAD")
    $upstream = Get-R24D2GitValue @("rev-parse", "@{upstream}")
    $live = (
        Get-R24D2GitValue @("ls-remote", "origin", "refs/heads/main")
    ).Split("`t")[0]
    $status = Get-R24D2GitValue @("status", "--short")
    Assert-R24D2 (
        [System.IO.Path]::GetFullPath($root) -ceq $repoRoot
    ) "Canonical repository root changed: $root"
    Assert-R24D2 ($remote -ceq $expectedRemote) "Origin changed: $remote"
    Assert-R24D2 ($branch -ceq "main") "Branch changed: $branch"
    if ($RequireCleanPushedSource) {
        Assert-R24D2 ([string]::IsNullOrEmpty($status)) (
            "Clean-pushed qualification requires an empty worktree: $status"
        )
        Assert-R24D2 (
            $head -ceq $upstream -and $head -ceq $live
        ) "Clean-pushed qualification requires HEAD == upstream == live main."
    }

    foreach ($path in @(
        $manifestPath,
        $mujocoTestPath,
        $auditPath
    )) {
        Assert-R24D2 (
            Test-Path -LiteralPath $path -PathType Leaf
        ) "Required zero-world source is missing: $path"
    }
    $cargoPath = Resolve-R24D2Application $Cargo
    $pythonPath = Resolve-R24D2Application $Python
    $godotPath = Resolve-R24D2Application $Godot
    $pwshPath = Resolve-R24D2Application "pwsh"

    [void](Invoke-R24D2Checked `
        -FileName $cargoPath `
        -Arguments @(
            "fmt",
            "--manifest-path", $manifestPath,
            "--all",
            "--",
            "--check"
        ) `
        -WorkingDirectory $repoRoot `
        -Label "Rust formatting")

    [void](Invoke-R24D2Checked `
        -FileName $cargoPath `
        -Arguments @(
            "build",
            "--manifest-path", $manifestPath,
            "-p", "sporespore-locomotion-core",
            "-p", "sporespore-godot-adapter",
            "--offline"
        ) `
        -WorkingDirectory $repoRoot `
        -Label "Recovery core and Godot adapter debug build")
    Assert-R24D2 (
        Test-Path -LiteralPath $coreLibraryPath -PathType Leaf
    ) "Debug core library was not produced: $coreLibraryPath"

    [void](Invoke-R24D2Checked `
        -FileName $cargoPath `
        -Arguments @(
            "test",
            "--manifest-path", $manifestPath,
            "-p", "sporespore-locomotion-core",
            "--lib",
            "recovery",
            "--offline",
            "--",
            "--nocapture"
        ) `
        -WorkingDirectory $repoRoot `
        -Label "Portable recovery semantics tests")

    [void](Invoke-R24D2Checked `
        -FileName $cargoPath `
        -Arguments @(
            "test",
            "--manifest-path", $manifestPath,
            "-p", "sporespore-rapier-adapter",
            "--lib",
            "recovery_capability",
            "--offline",
            "--",
            "--nocapture"
        ) `
        -WorkingDirectory $repoRoot `
        -Label "Rapier recovery source-capability tests")

    $previousCoreLibrary = [Environment]::GetEnvironmentVariable(
        "SPORESPORE_LOCOMOTION_LIBRARY",
        "Process"
    )
    [Environment]::SetEnvironmentVariable(
        "SPORESPORE_LOCOMOTION_LIBRARY",
        $coreLibraryPath,
        "Process"
    )
    $coreLibraryEnvironmentChanged = $true
    [void](Invoke-R24D2Checked `
        -FileName $pythonPath `
        -Arguments @($mujocoTestPath, "-v") `
        -WorkingDirectory $repoRoot `
        -Label "MuJoCo recovery source-capability C ABI tests")
    [void](Invoke-R24D2Checked `
        -FileName $pythonPath `
        -Arguments @("-m", "unittest", "-v", "versioning.test_conformance") `
        -WorkingDirectory $sdkRoot `
        -Label "SDK versioning and real-library ABI tests")

    $godotOutput = Invoke-R24D2Checked `
        -FileName $godotPath `
        -Arguments @(
            "--headless",
            "--path", $repoRoot,
            "--script", $godotTestPath
        ) `
        -WorkingDirectory $repoRoot `
        -Label "Godot 4.7 recovery source-capability refusal test"
    $godotReceipt = Get-OneMarkerReceipt `
        -Output $godotOutput `
        -Prefix $godotMarker `
        -Label "Godot recovery test"
    Assert-R24D2 (
        [bool]$godotReceipt.ok -and
        [string]$godotReceipt.runtime_api_version -ceq "4.7-stable (official)" -and
        [int]$godotReceipt.required_channel_count -eq 10 -and
        [int]$godotReceipt.supported_channel_count -eq 8 -and
        [int]$godotReceipt.unsupported_channel_count -eq 2 -and
        [string]$godotReceipt.typed_refusal_status -ceq "unsupported_capability" -and
        [bool]$godotReceipt.false_promotion_rejected -and
        [bool]$godotReceipt.missing_channel_rejected -and
        [bool]$godotReceipt.synthesized_channel_rejected -and
        [int]$godotReceipt.world_build_count -eq 0 -and
        -not [bool]$godotReceipt.prone_to_standing_claimed -and
        -not [bool]$godotReceipt.release_authority
    ) "Godot capability test did not preserve the exact typed refusal."

    $auditOutput = Invoke-R24D2Checked `
        -FileName $pwshPath `
        -Arguments @(
            "-NoLogo",
            "-NoProfile",
            "-File", $auditPath
        ) `
        -WorkingDirectory $repoRoot `
        -Label "R24D2 source and authority audit"
    $auditReceipt = Get-OneMarkerReceipt `
        -Output $auditOutput `
        -Prefix $auditMarker `
        -Label "R24D2 source audit"
    Assert-R24D2 (
        [bool]$auditReceipt.ok -and
        [string]$auditReceipt.result -ceq "partial_fail_closed" -and
        [int]$auditReceipt.rapier_supported_channel_count -eq 10 -and
        [int]$auditReceipt.mujoco_supported_channel_count -eq 10 -and
        [int]$auditReceipt.godot_supported_channel_count -eq 8 -and
        [int]$auditReceipt.godot_unsupported_channel_count -eq 2 -and
        [bool]$auditReceipt.godot_typed_refusal -and
        -not [bool]$auditReceipt.native_capability_conjunction_complete -and
        [int]$auditReceipt.world_build_count -eq 0 -and
        -not [bool]$auditReceipt.q_sdk_r24_satisfied -and
        -not [bool]$auditReceipt.release_authority
    ) "R24D2 source audit receipt changed."

    $report = [ordered]@{
        schema_version = "sporespore_qsdk_r24d2_zero_world_gate_receipt_v1"
        ok = $true
        gate_id = "QSDK-R24D2"
        question_class = "non_physical_source_conformance"
        result = "partial_fail_closed"
        source = [ordered]@{
            root = $root.Replace("\", "/")
            remote = $remote
            branch = $branch
            head = $head
            upstream = $upstream
            live_main = $live
            clean = [string]::IsNullOrEmpty($status)
            matches_upstream = $head -ceq $upstream
            matches_live_main = $head -ceq $live
            clean_pushed_required = [bool]$RequireCleanPushedSource
        }
        stage_count = 8
        portable_semantics_implemented = $true
        c_abi_and_host_bindings_passed = $true
        versioning_conformance_passed = $true
        required_engine_count = 3
        required_channel_count_per_engine = 10
        rapier_supported_channel_count = 10
        mujoco_supported_channel_count = 10
        godot_supported_channel_count = 8
        godot_unsupported_channel_count = 2
        godot_unsupported_channels = @(
            "applied_actuation_receipts",
            "energy_balance_ledger"
        )
        godot_typed_refusal_passed = $true
        native_capability_conjunction_complete = $false
        declared_negative_control_count = 12
        declared_negative_controls_passed = 12
        set_physical_threshold_count = 0
        thresholds_and_cohorts_frozen = $false
        controller_implemented = $false
        native_runtime_observation_collection_executed = $false
        complete_prephysical_gate_passed = $false
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_question_opened = $false
        physical_campaign_opened = $false
        prone_to_standing_claimed = $false
        cross_engine_equivalence_claimed = $false
        q_sdk_r24_satisfied = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-Output (
        "QSDK_R24D2_ZERO_WORLD_GATE " +
        ($report | ConvertTo-Json -Depth 30 -Compress)
    )
}
finally {
    if ($coreLibraryEnvironmentChanged) {
        [Environment]::SetEnvironmentVariable(
            "SPORESPORE_LOCOMOTION_LIBRARY",
            $previousCoreLibrary,
            "Process"
        )
    }
    if ($null -ne $operationLock) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $operationLock
    }
}

#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$GodotSourceRoot = (
        "C:\Users\Cole\CodeStuff\dependencies\godot-sporespore-4.7"
    ),
    [string]$Python = "python",
    [string]$Godot = "",
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    ),
    [switch]$ColdBuild,
    [switch]$RequireCleanPushedSource,
    [switch]$CallerHoldsOperationLock
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$godotRoot = [IO.Path]::GetFullPath($GodotSourceRoot)
$patchPath = Join-Path $repoRoot (
    "sdk\adapters\godot\engine_patches\" +
    "godot_4_7_jolt_motor_telemetry.patch"
)
$contractPath = Join-Path $repoRoot (
    "sdk\recovery\r24d3_godot_jolt_motor_telemetry_source_v1.json"
)
$sourceAuditPath = Join-Path $repoRoot (
    "tests\test_qsdk_r24d3_godot_jolt_motor_telemetry_source.ps1"
)
$bindingTestPath = (
    "res://tests/" +
    "test_sdk_qsdk_r24d3_godot_jolt_motor_telemetry_binding_zero_world.gd"
)
$expectedRepoRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRepoRemote = "https://github.com/Slagathore/sporespore.git"
$expectedGodotRemote = "https://github.com/godotengine/godot.git"
$expectedGodotCommit = "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"
$expectedGodotConsoleRelativePath = (
    "bin\godot.windows.editor.dev.x86_64.console.exe"
)
$expectedGodotEngineRelativePath = "bin\godot.windows.editor.dev.x86_64.exe"
$expectedPatchHash = (
    "f067543bc6237a38c0c0935a56b3bbebcd318dc6d82cec1321ea5d52e45dae2f"
)
$expectedPatchedPaths = @(
    "modules/jolt_physics/joints/jolt_hinge_joint_3d.cpp",
    "modules/jolt_physics/joints/jolt_hinge_joint_3d.h",
    "modules/jolt_physics/jolt_physics_server_3d.cpp",
    "modules/jolt_physics/jolt_physics_server_3d.h",
    "modules/jolt_physics/register_types.cpp",
    "thirdparty/jolt_physics/Jolt/Physics/Constraints/HingeConstraint.cpp",
    "thirdparty/jolt_physics/Jolt/Physics/Constraints/HingeConstraint.h"
)
$sconsArguments = @(
    "platform=windows",
    "target=editor",
    "dev_build=yes",
    "debug_symbols=no",
    "module_mono_enabled=no",
    "tests=no",
    "accesskit=no",
    "d3d12=no",
    "angle=no",
    "-j12"
)

. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")

function Assert-R24D3 {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "QSDK-R24D3: $Message" }
}

function Resolve-R24D3Application {
    param([Parameter(Mandatory)][string]$Command)
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R24D3 (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "Application is missing: $resolved"
        )
        return $resolved
    }
    $candidate = Get-Command `
        -Name $Command `
        -CommandType Application `
        -ErrorAction Stop |
        Select-Object -First 1
    return [IO.Path]::GetFullPath([string]$candidate.Source)
}

function Get-R24D3GitValue {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    $output = @(& git -C $Root @Arguments 2>&1)
    Assert-R24D3 ($LASTEXITCODE -eq 0) (
        "git $($Arguments -join ' ') failed: $($output -join ' | ')"
    )
    return ($output -join "`n").Trim()
}

function Invoke-R24D3Checked {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$Label,
        [string]$LogPath = ""
    )
    Push-Location -LiteralPath $WorkingDirectory
    try {
        $started = [DateTimeOffset]::UtcNow
        $output = @(& $FileName @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
        $finished = [DateTimeOffset]::UtcNow
    }
    finally {
        Pop-Location
    }
    if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
        $log = @(
            "label=$Label"
            "started_utc=$($started.ToString('o'))"
            "finished_utc=$($finished.ToString('o'))"
            "exit_code=$exitCode"
            "command=$FileName $($Arguments -join ' ')"
            "working_directory=$WorkingDirectory"
            "--- output ---"
            @($output | ForEach-Object { [string]$_ })
        ) -join "`n"
        [IO.File]::WriteAllText(
            $LogPath,
            $log + "`n",
            [Text.UTF8Encoding]::new($false)
        )
    }
    Assert-R24D3 ($exitCode -eq 0) (
        "$Label failed with exit code $exitCode`: $($output -join ' | ')"
    )
    return [ordered]@{
        output = @($output | ForEach-Object { [string]$_ })
        duration_s = [Math]::Round(($finished - $started).TotalSeconds, 6)
    }
}

function Get-OneMarkerLine {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$Output,
        [Parameter(Mandatory)][string]$Prefix,
        [Parameter(Mandatory)][string]$Label
    )
    $markers = @($Output | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R24D3 ($markers.Count -eq 1) (
        "$Label emitted $($markers.Count) terminal markers."
    )
    return [string]$markers[0]
}

function Get-StringSha256 {
    param([Parameter(Mandatory)][string]$Value)
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Value)
    return [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()
}

function Normalize-Lf {
    param([Parameter(Mandatory)][string]$Text)
    return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

$operationLock = $null
try {
    if (-not $CallerHoldsOperationLock) {
        $operationLock = Enter-SporeSporeLocomotionOperationLock -Role conformance
        Assert-R24D3 ([bool]$operationLock.acquired) (
            "Another conformance or physical workload owns the locomotion lock."
        )
    }

    foreach ($path in @($patchPath, $contractPath, $sourceAuditPath)) {
        Assert-R24D3 (Test-Path -LiteralPath $path -PathType Leaf) (
            "Required durable source is missing: $path"
        )
    }
    Assert-R24D3 (Test-Path -LiteralPath $godotRoot -PathType Container) (
        "Pinned Godot source root is missing: $godotRoot"
    )

    $root = Get-R24D3GitValue `
        -Root $repoRoot `
        -Arguments @("rev-parse", "--show-toplevel")
    $remote = Get-R24D3GitValue `
        -Root $repoRoot `
        -Arguments @("remote", "get-url", "origin")
    $branch = Get-R24D3GitValue `
        -Root $repoRoot `
        -Arguments @("branch", "--show-current")
    $head = Get-R24D3GitValue `
        -Root $repoRoot `
        -Arguments @("rev-parse", "HEAD")
    $upstream = Get-R24D3GitValue `
        -Root $repoRoot `
        -Arguments @("rev-parse", "@{upstream}")
    $live = (
        Get-R24D3GitValue `
            -Root $repoRoot `
            -Arguments @("ls-remote", "origin", "refs/heads/main")
    ).Split("`t")[0]
    $status = Get-R24D3GitValue `
        -Root $repoRoot `
        -Arguments @("status", "--short")
    Assert-R24D3 ([IO.Path]::GetFullPath($root) -ceq $expectedRepoRoot) (
        "Canonical repository root changed: $root"
    )
    Assert-R24D3 ($remote -ceq $expectedRepoRemote) "Origin changed: $remote"
    Assert-R24D3 ($branch -ceq "main") "Branch changed: $branch"
    if ($RequireCleanPushedSource) {
        Assert-R24D3 ([string]::IsNullOrEmpty($status)) (
            "Clean-pushed qualification requires an empty worktree: $status"
        )
        Assert-R24D3 (
            $head -ceq $upstream -and $head -ceq $live
        ) "Clean-pushed qualification requires HEAD == upstream == live main."
    }

    $godotObservedRoot = Get-R24D3GitValue `
        -Root $godotRoot `
        -Arguments @("rev-parse", "--show-toplevel")
    $godotRemote = Get-R24D3GitValue `
        -Root $godotRoot `
        -Arguments @("remote", "get-url", "origin")
    $godotHead = Get-R24D3GitValue `
        -Root $godotRoot `
        -Arguments @("rev-parse", "HEAD")
    Assert-R24D3 ([IO.Path]::GetFullPath($godotObservedRoot) -ceq $godotRoot) (
        "Godot source root changed: $godotObservedRoot"
    )
    Assert-R24D3 ($godotRemote -ceq $expectedGodotRemote) (
        "Godot origin changed: $godotRemote"
    )
    Assert-R24D3 ($godotHead -ceq $expectedGodotCommit) (
        "Godot source commit changed: $godotHead"
    )

    $patchHash = (
        Get-FileHash -LiteralPath $patchPath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    Assert-R24D3 ($patchHash -ceq $expectedPatchHash) (
        "Durable patch hash changed: $patchHash"
    )
    $patchText = Normalize-Lf ([IO.File]::ReadAllText($patchPath))
    $diffLines = @(
        & git -C $godotRoot diff --no-ext-diff -- @expectedPatchedPaths 2>&1
    )
    Assert-R24D3 ($LASTEXITCODE -eq 0) "Could not read pinned Godot diff."
    $diffText = Normalize-Lf (($diffLines -join "`n") + "`n")
    Assert-R24D3 (
        $diffText -ceq ((Normalize-Lf $patchText).TrimEnd("`n") + "`n")
    ) "Pinned Godot source diff does not equal the durable patch."
    $sourceDiffHash = Get-StringSha256 $diffText
    Assert-R24D3 ($sourceDiffHash -ceq $expectedPatchHash) (
        "Pinned source diff hash does not equal patch hash: $sourceDiffHash"
    )

    $pythonPath = Resolve-R24D3Application $Python
    $pwshPath = Resolve-R24D3Application "pwsh"
    $expectedGodotConsolePath = [IO.Path]::GetFullPath(
        (Join-Path $godotRoot $expectedGodotConsoleRelativePath)
    )
    $godotEngineSourcePath = [IO.Path]::GetFullPath(
        (Join-Path $godotRoot $expectedGodotEngineRelativePath)
    )
    if ([string]::IsNullOrWhiteSpace($Godot)) {
        $Godot = $expectedGodotConsolePath
    }
    $godotConsoleSourcePath = [IO.Path]::GetFullPath($Godot)
    Assert-R24D3 (
        $godotConsoleSourcePath.Equals(
            $expectedGodotConsolePath,
            [StringComparison]::OrdinalIgnoreCase
        )
    ) (
        "The exact evidence key requires the pinned build's console launcher: " +
        $expectedGodotConsolePath
    )

    $evidenceBase = [IO.Path]::GetFullPath($EvidenceRoot)
    Assert-R24D3 (-not $evidenceBase.StartsWith($repoRoot + "\", [StringComparison]::OrdinalIgnoreCase)) (
        "Qualification evidence must not be stored in the source repository."
    )
    $runId = (
        [DateTimeOffset]::UtcNow.ToString("yyyyMMddTHHmmssZ") + "-" +
        $head.Substring(0, 8) + "-" + $patchHash.Substring(0, 12)
    )
    $runRoot = Join-Path $evidenceBase ("qsdk-r24d3-builds\" + $runId)
    Assert-R24D3 (-not (Test-Path -LiteralPath $runRoot)) (
        "Evidence run path already exists: $runRoot"
    )
    [void](New-Item -ItemType Directory -Path $runRoot)

    $pythonVersion = Invoke-R24D3Checked `
        -FileName $pythonPath `
        -Arguments @("--version") `
        -WorkingDirectory $godotRoot `
        -Label "Python version"
    $sconsVersion = Invoke-R24D3Checked `
        -FileName $pythonPath `
        -Arguments @("-m", "SCons", "--version") `
        -WorkingDirectory $godotRoot `
        -Label "SCons version"

    $cleanDuration = 0.0
    if ($ColdBuild) {
        $clean = Invoke-R24D3Checked `
            -FileName $pythonPath `
            -Arguments (@("-m", "SCons", "--clean") + $sconsArguments) `
            -WorkingDirectory $godotRoot `
            -Label "Pinned Godot cold-build cleanup" `
            -LogPath (Join-Path $runRoot "01-clean.log")
        $cleanDuration = [double]$clean.duration_s
    }

    $build = Invoke-R24D3Checked `
        -FileName $pythonPath `
        -Arguments (@("-m", "SCons") + $sconsArguments) `
        -WorkingDirectory $godotRoot `
        -Label "Pinned Godot instrumented build" `
        -LogPath (Join-Path $runRoot "02-build.log")
    Assert-R24D3 (
        Test-Path -LiteralPath $godotConsoleSourcePath -PathType Leaf
    ) (
        "Instrumented Godot console launcher is missing after build: " +
        $godotConsoleSourcePath
    )
    Assert-R24D3 (
        Test-Path -LiteralPath $godotEngineSourcePath -PathType Leaf
    ) (
        "Instrumented Godot engine executable is missing after build: " +
        $godotEngineSourcePath
    )

    $retainedBinaryRoot = Join-Path $runRoot "artifacts"
    [void](New-Item -ItemType Directory -Path $retainedBinaryRoot)
    $retainedConsolePath = Join-Path $retainedBinaryRoot (
        Split-Path -Leaf $godotConsoleSourcePath
    )
    $retainedEnginePath = Join-Path $retainedBinaryRoot (
        Split-Path -Leaf $godotEngineSourcePath
    )
    Copy-Item `
        -LiteralPath $godotConsoleSourcePath `
        -Destination $retainedConsolePath
    Copy-Item `
        -LiteralPath $godotEngineSourcePath `
        -Destination $retainedEnginePath

    $consoleSourceHash = (
        Get-FileHash -LiteralPath $godotConsoleSourcePath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    $engineSourceHash = (
        Get-FileHash -LiteralPath $godotEngineSourcePath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    $retainedConsoleHash = (
        Get-FileHash -LiteralPath $retainedConsolePath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    $retainedEngineHash = (
        Get-FileHash -LiteralPath $retainedEnginePath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    Assert-R24D3 ($retainedConsoleHash -ceq $consoleSourceHash) (
        "Retained console launcher does not equal the built source artifact."
    )
    Assert-R24D3 ($retainedEngineHash -ceq $engineSourceHash) (
        "Retained engine executable does not equal the built source artifact."
    )

    $godotVersion = Invoke-R24D3Checked `
        -FileName $retainedConsolePath `
        -Arguments @("--version") `
        -WorkingDirectory $repoRoot `
        -Label "Instrumented Godot version"
    $sourceAudit = Invoke-R24D3Checked `
        -FileName $pwshPath `
        -Arguments @(
            "-NoLogo",
            "-NoProfile",
            "-File", $sourceAuditPath,
            "-GodotSourceRoot", $godotRoot
        ) `
        -WorkingDirectory $repoRoot `
        -Label "R24D3 source and mutation audit" `
        -LogPath (Join-Path $runRoot "03-source-audit.log")
    $sourceMarker = Get-OneMarkerLine `
        -Output $sourceAudit.output `
        -Prefix "QSDK_R24D3_GODOT_JOLT_MOTOR_TELEMETRY_SOURCE_PASS " `
        -Label "R24D3 source audit"
    $sourceReceipt = $sourceMarker.Substring(
        "QSDK_R24D3_GODOT_JOLT_MOTOR_TELEMETRY_SOURCE_PASS ".Length
    ) | ConvertFrom-Json -Depth 30
    Assert-R24D3 (
        [bool]$sourceReceipt.ok -and
        [int]$sourceReceipt.rejected_mutation_count -eq 12 -and
        [bool]$sourceReceipt.external_pinned_source_verified -and
        -not [bool]$sourceReceipt.instrumented_capability_promoted -and
        [int]$sourceReceipt.world_build_count -eq 0 -and
        -not [bool]$sourceReceipt.release_authority
    ) "R24D3 source audit receipt changed."

    $binding = Invoke-R24D3Checked `
        -FileName $retainedConsolePath `
        -Arguments @(
            "--headless",
            "--path", $repoRoot,
            "--script", $bindingTestPath
        ) `
        -WorkingDirectory $repoRoot `
        -Label "Instrumented Godot/Jolt binding zero-world probe" `
        -LogPath (Join-Path $runRoot "04-binding-zero-world.log")
    $bindingMarker = Get-OneMarkerLine `
        -Output $binding.output `
        -Prefix "QSDK_R24D3_GODOT_BINDING_ZERO_WORLD " `
        -Label "R24D3 binding probe"
    $expectedBindingMarker = (
        "QSDK_R24D3_GODOT_BINDING_ZERO_WORLD passed=6 failed=0 " +
        "world_build_count=0 solver_step_count=0"
    )
    Assert-R24D3 (
        $bindingMarker -ceq $expectedBindingMarker
    ) "Binding zero-world receipt changed: $bindingMarker"

    $postBuildDiffLines = @(
        & git -C $godotRoot diff --no-ext-diff -- @expectedPatchedPaths 2>&1
    )
    Assert-R24D3 ($LASTEXITCODE -eq 0) "Could not re-read Godot diff."
    $postBuildDiff = Normalize-Lf (($postBuildDiffLines -join "`n") + "`n")
    Assert-R24D3 ($postBuildDiff -ceq $diffText) (
        "Pinned Godot source drifted during qualification."
    )

    $postBindingConsoleHash = (
        Get-FileHash -LiteralPath $retainedConsolePath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    $postBindingEngineHash = (
        Get-FileHash -LiteralPath $retainedEnginePath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    Assert-R24D3 ($postBindingConsoleHash -ceq $retainedConsoleHash) (
        "Retained console launcher drifted during the binding probe."
    )
    Assert-R24D3 ($postBindingEngineHash -ceq $retainedEngineHash) (
        "Retained engine executable drifted during the binding probe."
    )
    $buildLogPath = Join-Path $runRoot "02-build.log"
    $buildLogHash = (
        Get-FileHash -LiteralPath $buildLogPath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    $bindingLogPath = Join-Path $runRoot "04-binding-zero-world.log"
    $bindingLogHash = (
        Get-FileHash -LiteralPath $bindingLogPath -Algorithm SHA256
    ).Hash.ToLowerInvariant()

    $receipt = [ordered]@{
        schema_version = "sporespore_qsdk_r24d3_instrumented_zero_world_gate_receipt_v2"
        ok = $true
        gate_id = "QSDK-R24D3"
        question_class = "non_physical_source_conformance"
        result = "compile_and_zero_world_binding_pass_characterization_withheld"
        source = [ordered]@{
            repository_root = $root.Replace("\", "/")
            repository_remote = $remote
            branch = $branch
            head = $head
            upstream = $upstream
            live_main = $live
            clean = [string]::IsNullOrEmpty($status)
            clean_pushed_required = [bool]$RequireCleanPushedSource
            godot_source_root = $godotRoot.Replace("\", "/")
            godot_remote = $godotRemote
            godot_commit = $godotHead
            patch_sha256 = "sha256:$patchHash"
            source_diff_sha256 = "sha256:$sourceDiffHash"
            patched_file_count = 7
        }
        toolchain = [ordered]@{
            os_version = [Environment]::OSVersion.VersionString
            python_path = $pythonPath.Replace("\", "/")
            python_version = ($pythonVersion.output -join " | ")
            scons_version = ($sconsVersion.output -join " | ")
            build_arguments = @($sconsArguments)
            cold_build = [bool]$ColdBuild
            clean_duration_s = $cleanDuration
            build_duration_s = [double]$build.duration_s
            godot_version = ($godotVersion.output -join " | ")
        }
        artifacts = [ordered]@{
            execution_console_binary_path = $retainedConsolePath.Replace("\", "/")
            source_console_binary_path = $godotConsoleSourcePath.Replace("\", "/")
            retained_console_binary_path = $retainedConsolePath.Replace("\", "/")
            console_binary_sha256 = "sha256:$retainedConsoleHash"
            console_binary_byte_length = (
                Get-Item -LiteralPath $retainedConsolePath
            ).Length
            source_engine_binary_path = $godotEngineSourcePath.Replace("\", "/")
            retained_engine_binary_path = $retainedEnginePath.Replace("\", "/")
            engine_binary_sha256 = "sha256:$retainedEngineHash"
            engine_binary_byte_length = (
                Get-Item -LiteralPath $retainedEnginePath
            ).Length
            retained_binary_count = 2
            execution_used_retained_binary_pair = $true
            build_log_path = $buildLogPath.Replace("\", "/")
            build_log_sha256 = "sha256:$buildLogHash"
            binding_log_path = $bindingLogPath.Replace("\", "/")
            binding_log_sha256 = "sha256:$bindingLogHash"
        }
        patched_file_count = 7
        receipt_field_count = 11
        rejected_mutation_count = 12
        compile_passed = $true
        binding_assertion_count = 6
        binding_failed_assertion_count = 0
        invalid_rid_refused = $true
        stock_godot_supported_channel_count = 8
        instrumented_source_field_count = 10
        instrumented_capability_promoted = $false
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        physical_question_opened = $false
        prone_to_standing_claimed = $false
        cross_engine_equivalence_claimed = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    $receiptPath = Join-Path $runRoot "receipt.json"
    [IO.File]::WriteAllText(
        $receiptPath,
        ($receipt | ConvertTo-Json -Depth 50) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
    $receiptHash = (
        Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    Write-Output (
        "QSDK_R24D3_INSTRUMENTED_ZERO_WORLD_GATE " +
        ([ordered]@{
            ok = $true
            result = [string]$receipt.result
            cold_build = [bool]$ColdBuild
            patch_sha256 = "sha256:$patchHash"
            console_binary_sha256 = "sha256:$retainedConsoleHash"
            engine_binary_sha256 = "sha256:$retainedEngineHash"
            retained_binary_count = 2
            execution_used_retained_binary_pair = $true
            receipt_path = $receiptPath.Replace("\", "/")
            receipt_sha256 = "sha256:$receiptHash"
            world_build_count = 0
            solver_step_count = 0
            instrumented_capability_promoted = $false
            release_authority = $false
        } | ConvertTo-Json -Depth 20 -Compress)
    )
}
finally {
    if ($null -ne $operationLock) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $operationLock
    }
}

#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet("Development", "Qualification")]
    [string]$Mode = "Development",
    [string]$Cargo = "cargo",
    [string]$Python = "python",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$evidenceBase = [IO.Path]::GetFullPath($EvidenceRoot)
$expectedRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$expectedEvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$contractRelative = (
    "sdk/recovery/" +
    "r24d17_native_recovery_runtime_and_physical_profile_contract_v1.json"
)
$sourceAuditRelative = (
    "tests/test_qsdk_r24d17_native_recovery_runtime_source.py"
)
$godotWorkerRelative = (
    "tests/test_sdk_qsdk_r24d17_godot_recovery_runtime_zero_world.gd"
)
$manifestRelative = "sdk/Cargo.toml"
$terminalMarker = "QSDK_R24D17_RECOVERY_RUNTIME_ZERO_WORLD "
$godotMarker = "QSDK_R24D17_GODOT_RECOVERY_RUNTIME_ZERO_WORLD "

. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")

function Assert-R24D17 {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) {
        throw "QSDK-R24D17 zero-world gate: $Code"
    }
}

function Get-R24D17Git {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-R24D17 ($LASTEXITCODE -eq 0) (
        "git_$($Arguments -join '_'):$($output -join '|')"
    )
    return ($output -join "`n").Trim()
}

function Resolve-R24D17Application {
    param([Parameter(Mandatory)][string]$Command)
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R24D17 (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application_missing:$resolved"
        )
        return $resolved
    }
    $candidate = Get-Command -Name $Command -CommandType Application |
        Select-Object -First 1
    Assert-R24D17 ($null -ne $candidate) "application_missing:$Command"
    return [IO.Path]::GetFullPath([string]$candidate.Source)
}

function Write-R24D17Json {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Value
    )
    [IO.File]::WriteAllText(
        $Path,
        ($Value | ConvertTo-Json -Depth 100) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
}

function Get-R24D17FileReceipt {
    param([Parameter(Mandatory)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    Assert-R24D17 (Test-Path -LiteralPath $full -PathType Leaf) (
        "file_missing:$full"
    )
    $item = Get-Item -LiteralPath $full
    return [ordered]@{
        path = $full.Replace("\", "/")
        raw_sha256 = "sha256:" + (
            Get-FileHash -Algorithm SHA256 -LiteralPath $full
        ).Hash.ToLowerInvariant()
        byte_length = [long]$item.Length
    }
}

function Invoke-R24D17Process {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$LogStem,
        [hashtable]$Environment = @{},
        [int]$TimeoutSeconds = 300
    )
    $stdoutPath = "$LogStem.stdout.log"
    $stderrPath = "$LogStem.stderr.log"
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $FileName
    $info.WorkingDirectory = $repoRoot
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($argument in $Arguments) {
        [void]$info.ArgumentList.Add($argument)
    }
    foreach ($entry in $Environment.GetEnumerator()) {
        $info.Environment[[string]$entry.Key] = [string]$entry.Value
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    $started = [DateTimeOffset]::UtcNow
    Assert-R24D17 ($process.Start()) "process_start_failed:$Label"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $completed = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $completed) {
        $process.Kill($true)
    }
    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $finished = [DateTimeOffset]::UtcNow
    [IO.File]::WriteAllText($stdoutPath, $stdout, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($stderrPath, $stderr, [Text.UTF8Encoding]::new($false))
    $exitCode = if ($completed) { $process.ExitCode } else { -2 }
    return [ordered]@{
        label = $Label
        command = $FileName
        arguments = @($Arguments)
        started_utc = $started.ToString("o")
        finished_utc = $finished.ToString("o")
        duration_s = [Math]::Round(($finished - $started).TotalSeconds, 6)
        timed_out = -not $completed
        exit_code = $exitCode
        ok = $completed -and $exitCode -eq 0
        stdout = $stdout
        stderr = $stderr
        stdout_file = Get-R24D17FileReceipt $stdoutPath
        stderr_file = Get-R24D17FileReceipt $stderrPath
    }
}

function Get-R24D17MarkerJson {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Prefix
    )
    $markers = @($Text -split "`r?`n" | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R24D17 ($markers.Count -eq 1) "marker_count:$Prefix`:$($markers.Count)"
    return ([string]$markers[0]).Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-R24D17SourceBoundary {
    param([switch]$RequireCleanPushed)
    $root = Get-R24D17Git @("rev-parse", "--show-toplevel")
    $remote = Get-R24D17Git @("remote", "get-url", "origin")
    $branch = Get-R24D17Git @("branch", "--show-current")
    $head = Get-R24D17Git @("rev-parse", "HEAD")
    $tree = Get-R24D17Git @("rev-parse", "HEAD^{tree}")
    $upstream = Get-R24D17Git @("rev-parse", "@{upstream}")
    $cached = Get-R24D17Git @("rev-parse", "refs/remotes/origin/main")
    $live = (Get-R24D17Git @(
        "ls-remote", "--heads", "origin", "refs/heads/main"
    )).Split("`t")[0]
    $status = Get-R24D17Git @("status", "--short")
    $worktreeText = Get-R24D17Git @("worktree", "list", "--porcelain")
    $worktrees = @($worktreeText -split "`r?`n" | Where-Object {
        $_.StartsWith("worktree ", [StringComparison]::Ordinal)
    })
    Assert-R24D17 ([IO.Path]::GetFullPath($root) -ceq $expectedRoot) "root"
    Assert-R24D17 ($remote -ceq $expectedRemote) "remote"
    Assert-R24D17 ($branch -ceq "main") "branch"
    Assert-R24D17 ($worktrees.Count -eq 1) "worktree_count"
    if ($RequireCleanPushed) {
        Assert-R24D17 ([string]::IsNullOrEmpty($status)) "dirty_worktree"
        Assert-R24D17 (
            $head -ceq $upstream -and $head -ceq $cached -and $head -ceq $live
        ) "local_upstream_cached_live_inequality"
    }
    return [ordered]@{
        root = $root.Replace("\", "/")
        remote = $remote
        branch = $branch
        head = $head
        tree_git_oid = $tree
        upstream = $upstream
        cached_origin_main = $cached
        live_origin_main = $live
        status_porcelain = $status
        worktree_count = $worktrees.Count
        clean_pushed = [bool](
            [string]::IsNullOrEmpty($status) -and
            $head -ceq $upstream -and $head -ceq $cached -and $head -ceq $live
        )
    }
}

Assert-R24D17 ($repoRoot -ceq $expectedRoot) "script_root"
Assert-R24D17 ($evidenceBase -ceq $expectedEvidenceRoot) "evidence_root"
[void][IO.Directory]::CreateDirectory($evidenceBase)

$cargoPath = Resolve-R24D17Application $Cargo
$pythonPath = Resolve-R24D17Application $Python
$godotPath = Resolve-R24D17Application $Godot
$qualification = $Mode -ceq "Qualification"
$boundary = Get-R24D17SourceBoundary -RequireCleanPushed:$qualification
$headPrefix = ([string]$boundary.head).Substring(0, 8)
if ($qualification) {
    $prior = @(Get-ChildItem -LiteralPath $evidenceBase -Directory |
        Where-Object { $_.Name -like "qsdk-r24d17-qualification-*-$headPrefix" })
    Assert-R24D17 ($prior.Count -eq 0) (
        "qualification_already_consumed_for_source:$($boundary.head)"
    )
}

$timestamp = [DateTimeOffset]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
$kind = if ($qualification) { "qualification" } else { "development" }
$runId = "$timestamp-$headPrefix"
$runRoot = Join-Path $evidenceBase "qsdk-r24d17-$kind-$runId"
[void][IO.Directory]::CreateDirectory($runRoot)
$operationLock = $null
$processes = [Collections.Generic.List[object]]::new()

try {
    $operationLock = Enter-SporeSporeLocomotionOperationLock `
        -Role conformance `
        -TimeoutMilliseconds 0
    Assert-R24D17 ([bool]$operationLock.acquired) "operation_lock_unavailable"

    $sourceMode = if ($qualification) {
        "--require-committed-source"
    } else {
        "--allow-prospective-uncommitted"
    }
    $sourceAudit = Invoke-R24D17Process `
        -FileName $pythonPath `
        -Arguments @((Join-Path $repoRoot $sourceAuditRelative), $sourceMode) `
        -Label "source and contract audit" `
        -LogStem (Join-Path $runRoot "01-source-audit")
    $processes.Add($sourceAudit)
    Assert-R24D17 ([bool]$sourceAudit.ok) "source_audit_failed"

    $build = Invoke-R24D17Process `
        -FileName $cargoPath `
        -Arguments @(
            "build", "--manifest-path", (Join-Path $repoRoot $manifestRelative),
            "-p", "sporespore-locomotion-core",
            "-p", "sporespore-godot-adapter",
            "--offline"
        ) `
        -Label "offline core and Godot build" `
        -LogStem (Join-Path $runRoot "02-cargo-build") `
        -TimeoutSeconds 600
    $processes.Add($build)
    Assert-R24D17 ([bool]$build.ok) "cargo_build_failed"

    $coreTests = Invoke-R24D17Process `
        -FileName $cargoPath `
        -Arguments @(
            "test", "--manifest-path", (Join-Path $repoRoot $manifestRelative),
            "-p", "sporespore-locomotion-core", "--lib", "recovery_runtime", "--offline",
            "--", "--nocapture"
        ) `
        -Label "core collector and controller tests" `
        -LogStem (Join-Path $runRoot "03-core-tests") `
        -TimeoutSeconds 600
    $processes.Add($coreTests)
    Assert-R24D17 ([bool]$coreTests.ok) "core_tests_failed"
    Assert-R24D17 ($coreTests.stdout -match "5 passed") "core_test_count"

    $rapierTests = Invoke-R24D17Process `
        -FileName $cargoPath `
        -Arguments @(
            "test", "--manifest-path", (Join-Path $repoRoot $manifestRelative),
            "-p", "sporespore-rapier-adapter", "--lib", "recovery_runtime", "--offline",
            "--", "--nocapture"
        ) `
        -Label "Rapier recovery surface tests" `
        -LogStem (Join-Path $runRoot "04-rapier-tests") `
        -TimeoutSeconds 600
    $processes.Add($rapierTests)
    Assert-R24D17 ([bool]$rapierTests.ok) "rapier_tests_failed"
    Assert-R24D17 ($rapierTests.stdout -match "2 passed") "rapier_test_count"

    $coreLibrary = Join-Path $sdkRoot "target/debug/sporespore_locomotion_core.dll"
    Assert-R24D17 (Test-Path -LiteralPath $coreLibrary -PathType Leaf) "core_library_missing"
    $pythonTests = Invoke-R24D17Process `
        -FileName $pythonPath `
        -Arguments @(
            "-m", "unittest",
            "sdk.python.test_ctypes_smoke.CtypesSmokeTest.test_recovery_development_profile_through_real_dynamic_library",
            "sdk.adapters.mujoco.test_recovery_runtime",
            "sdk.versioning.test_conformance.VersioningConformanceTest.test_manifest_symbols_resolve_from_real_library",
            "-v"
        ) `
        -Label "Python ABI and MuJoCo surface tests" `
        -LogStem (Join-Path $runRoot "05-python-tests") `
        -Environment @{
            SPORESPORE_LOCOMOTION_LIBRARY = $coreLibrary
            PYTHONPATH = $sdkRoot
        }
    $processes.Add($pythonTests)
    Assert-R24D17 ([bool]$pythonTests.ok) "python_tests_failed"
    Assert-R24D17 ($pythonTests.stderr -match "Ran 4 tests") "python_test_count"

    $godotAppData = Join-Path $runRoot "godot-appdata"
    $godotLocalAppData = Join-Path $runRoot "godot-localappdata"
    [void][IO.Directory]::CreateDirectory($godotAppData)
    [void][IO.Directory]::CreateDirectory($godotLocalAppData)
    $godotRun = Invoke-R24D17Process `
        -FileName $godotPath `
        -Arguments @(
            "--headless", "--path", $repoRoot,
            "--log-file", (Join-Path $runRoot "06-godot-engine.log"),
            "--script", "res://$godotWorkerRelative"
        ) `
        -Label "Godot recovery runtime surface ghost" `
        -LogStem (Join-Path $runRoot "06-godot") `
        -Environment @{
            APPDATA = $godotAppData
            LOCALAPPDATA = $godotLocalAppData
        }
    $processes.Add($godotRun)
    Assert-R24D17 ([bool]$godotRun.ok) "godot_surface_failed"
    $godotReceipt = Get-R24D17MarkerJson $godotRun.stdout $godotMarker
    Assert-R24D17 ([bool]$godotReceipt.ok) "godot_receipt_invalid"
    Assert-R24D17 ([int]$godotReceipt.world_attempt_count -eq 0) "godot_world_attempt"
    Assert-R24D17 ([int]$godotReceipt.solver_step_count -eq 0) "godot_solver_step"

    $contractPath = Join-Path $repoRoot $contractRelative
    $artifactFiles = @($processes | ForEach-Object {
        @($_.stdout_file, $_.stderr_file)
    })
    $receipt = [ordered]@{
        schema_version = "sporespore_qsdk_r24d17_native_recovery_runtime_zero_world_receipt_v1"
        gate_id = "QSDK-R24D17"
        run_id = $runId
        mode = $Mode
        status = if ($qualification) {
            "qualification_passed_physics_not_opened"
        } else {
            "development_ghost_passed_physics_not_opened"
        }
        question_class = "non_physical_source_conformance"
        source_boundary = $boundary
        contract = Get-R24D17FileReceipt $contractPath
        operation_lock = Get-SporeSporeLocomotionOperationLockPublicReceipt $operationLock
        process_count = $processes.Count
        processes = @($processes)
        core_recovery_test_count = 5
        rapier_surface_test_count = 2
        python_test_count = 4
        godot_process_count = 1
        native_engine_identity_count = 3
        required_channel_count_per_engine = 10
        runtime_mutation_refusal_count = 8
        controller_mutation_refusal_count = 1
        development_cell_count = 3
        held_out_cell_count = 9
        held_out_cells_executed = 0
        native_runtime_observation_collection_executed = $false
        physical_question_opened = $false
        physical_execution_authorized = $false
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        controller_physical_viability_proven = $false
        prone_to_standing_claimed = $false
        cross_engine_recovery_claimed = $false
        cross_engine_equivalence_claimed = $false
        sdk1_milestone_advanced = $false
        physical_acceptance_authority = $false
        release_authority = $false
        artifact_count = $artifactFiles.Count
        artifacts = $artifactFiles
    }
    $receiptPath = Join-Path $runRoot "receipt.json"
    Write-R24D17Json $receiptPath $receipt
    Write-Output ($terminalMarker + ($receipt | ConvertTo-Json -Depth 100 -Compress))
} catch {
    $failure = [ordered]@{
        schema_version = "sporespore_qsdk_r24d17_native_recovery_runtime_zero_world_failure_v1"
        gate_id = "QSDK-R24D17"
        run_id = $runId
        mode = $Mode
        status = "invalid_or_incomplete_zero_world_attempt"
        failure = $_.Exception.Message
        source_boundary = $boundary
        completed_process_count = $processes.Count
        processes = @($processes)
        physical_question_opened = $false
        physical_execution_authorized = $false
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        prone_to_standing_claimed = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-R24D17Json (Join-Path $runRoot "failure.json") $failure
    Write-Error $_
    exit 1
} finally {
    if ($null -ne $operationLock) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $operationLock
    }
}

#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet("Development", "Qualification")]
    [string]$Mode = "Development",
    [string]$Cargo = "cargo",
    [string]$Python = "python",
    [string]$InstrumentedGodot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r24d10-exact-step-numerical-telemetry\zero-world\" +
        "20260826T190352433Z-11df9b56-65f7856d452f\artifacts\" +
        "godot.windows.editor.dev.x86_64.console.exe"
    ),
    [string]$StockGodot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    ),
    [switch]$CallerHoldsOperationLock
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$evidenceBase = [IO.Path]::GetFullPath($EvidenceRoot)
$expectedRepoRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$expectedEvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$contractRelative = (
    "sdk/recovery/" +
    "r24d16_godot_jolt_profile_scoped_recovery_capability_contract_v1.json"
)
$sourceAuditRelative = (
    "tests/" +
    "test_qsdk_r24d16_godot_jolt_profile_scoped_recovery_capability_source.py"
)
$mappingRelative = (
    "sdk/adapters/godot/gdscript/" +
    "recovery_capability_instrumented_v2.gd"
)
$stockMappingRelative = "sdk/adapters/godot/gdscript/recovery_capability.gd"
$predecessorRelative = (
    "sdk/recovery/" +
    "r24d15_godot_jolt_instrumented_profile_promotion_decision_v1.json"
)
$workerRelative = (
    "tests/" +
    "test_sdk_qsdk_r24d16_godot_profile_scoped_recovery_capability_zero_world.gd"
)
$runnerRelative = (
    "sdk/run_qsdk_r24d16_profile_scoped_recovery_capability_zero_world.ps1"
)
$manifestRelative = "sdk/Cargo.toml"
$workerResource = "res://$workerRelative"
$workerMarker = "QSDK_R24D16_GODOT_PROFILE_CAPABILITY_ZERO_WORLD "
$terminalMarker = "QSDK_R24D16_PROFILE_CAPABILITY_GATE "
$expectedInstrumentedConsoleHash = (
    "ff655a567d31f51628d5b21742a0618e53f9fbf8a94937dd07d9882a0739872f"
)
$expectedInstrumentedConsoleBytes = 293376L
$expectedInstrumentedEngineHash = (
    "2d68ed7ae53704ffb532cd5633241c74d599d69e3bf1968de0ef261553030ffb"
)
$expectedInstrumentedEngineBytes = 188829184L
$expectedStockConsoleHash = (
    "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
)
$expectedStockConsoleBytes = 198152L
$sourceInventoryRelatives = @(
    $contractRelative,
    $mappingRelative,
    $stockMappingRelative,
    $predecessorRelative,
    $workerRelative,
    $sourceAuditRelative,
    $runnerRelative,
    "sdk/core/src/recovery.rs",
    "sdk/adapters/godot/src/lib.rs",
    "sdk/adapters/godot/sporespore_locomotion.gdextension"
)

. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")

function Assert-R24D16 {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) {
        throw "QSDK-R24D16 profile capability gate: $Code"
    }
}

function Get-R24D16Path {
    param([Parameter(Mandatory)][string]$Relative)
    return [IO.Path]::GetFullPath((Join-Path $repoRoot $Relative))
}

function Get-R24D16Git {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-R24D16 ($LASTEXITCODE -eq 0) (
        "git_$($Arguments -join '_'):$($output -join '|')"
    )
    return ($output -join "`n").Trim()
}

function Resolve-R24D16Application {
    param([Parameter(Mandatory)][string]$Command)
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R24D16 (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application_missing:$resolved"
        )
        return $resolved
    }
    $candidate = Get-Command -Name $Command -CommandType Application |
        Select-Object -First 1
    Assert-R24D16 ($null -ne $candidate) "application_missing:$Command"
    return [IO.Path]::GetFullPath([string]$candidate.Source)
}

function Get-R24D16FileReceipt {
    param([Parameter(Mandatory)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    Assert-R24D16 (Test-Path -LiteralPath $full -PathType Leaf) (
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

function Write-R24D16Json {
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

function Invoke-R24D16Process {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$LogStem,
        [hashtable]$Environment = @{},
        [int]$TimeoutSeconds = 180
    )
    $stdoutPath = "$LogStem.stdout.log"
    $stderrPath = "$LogStem.stderr.log"
    $processInfo = [Diagnostics.ProcessStartInfo]::new()
    $processInfo.FileName = $FileName
    $processInfo.WorkingDirectory = $WorkingDirectory
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) {
        [void]$processInfo.ArgumentList.Add($argument)
    }
    foreach ($entry in $Environment.GetEnumerator()) {
        $processInfo.Environment[[string]$entry.Key] = [string]$entry.Value
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $processInfo
    $started = [DateTimeOffset]::UtcNow
    Assert-R24D16 ($process.Start()) "process_start_failed:$Label"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $completed = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $completed) {
        $process.Kill($true)
        $process.WaitForExit()
    } else {
        $process.WaitForExit()
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $finished = [DateTimeOffset]::UtcNow
    $exitCode = if ($completed) { $process.ExitCode } else { -2 }
    [IO.File]::WriteAllText(
        $stdoutPath,
        $stdout,
        [Text.UTF8Encoding]::new($false)
    )
    [IO.File]::WriteAllText(
        $stderrPath,
        $stderr,
        [Text.UTF8Encoding]::new($false)
    )
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
        stdout_file = Get-R24D16FileReceipt $stdoutPath
        stderr_file = Get-R24D16FileReceipt $stderrPath
    }
}

function Get-R24D16MarkerReceipt {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Prefix,
        [Parameter(Mandatory)][string]$Label
    )
    $lines = @($Text -split "`r?`n")
    $markers = @($lines | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R24D16 ($markers.Count -eq 1) (
        "marker_count:$Label`:$($markers.Count)"
    )
    return ([string]$markers[0]).Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-R24D16SourceBoundary {
    param([switch]$RequireCleanPushed)
    $root = Get-R24D16Git @("rev-parse", "--show-toplevel")
    $remote = Get-R24D16Git @("remote", "get-url", "origin")
    $branch = Get-R24D16Git @("branch", "--show-current")
    $head = Get-R24D16Git @("rev-parse", "HEAD")
    $tree = Get-R24D16Git @("rev-parse", "HEAD^{tree}")
    $upstream = Get-R24D16Git @("rev-parse", "@{upstream}")
    $cached = Get-R24D16Git @("rev-parse", "refs/remotes/origin/main")
    $live = (Get-R24D16Git @(
        "ls-remote", "--heads", "origin", "refs/heads/main"
    )).Split("`t")[0]
    $status = Get-R24D16Git @("status", "--short")
    $worktreeText = Get-R24D16Git @("worktree", "list", "--porcelain")
    $worktrees = @($worktreeText -split "`r?`n" | Where-Object {
        $_.StartsWith("worktree ", [StringComparison]::Ordinal)
    })
    Assert-R24D16 (
        [IO.Path]::GetFullPath($root) -ceq $expectedRepoRoot -and
        $repoRoot -ceq $expectedRepoRoot
    ) "repository_root"
    Assert-R24D16 ($remote -ceq $expectedRemote) "repository_remote"
    Assert-R24D16 ($branch -ceq "main") "branch"
    Assert-R24D16 ($worktrees.Count -eq 1) "worktree_count"
    if ($RequireCleanPushed) {
        Assert-R24D16 ([string]::IsNullOrEmpty($status)) "dirty_worktree"
        Assert-R24D16 (
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
        worktree_count = $worktrees.Count
        status_porcelain = $status
        clean_pushed = [bool](
            [string]::IsNullOrEmpty($status) -and
            $head -ceq $upstream -and $head -ceq $cached -and $head -ceq $live
        )
    }
}

function Get-R24D16SourceInventory {
    param(
        [Parameter(Mandatory)][string]$Head,
        [switch]$RequireCommitted
    )
    $inventory = @()
    foreach ($relative in $sourceInventoryRelatives) {
        $full = Get-R24D16Path $relative
        $file = Get-R24D16FileReceipt $full
        $blob = Get-R24D16Git @("hash-object", "--", $relative)
        if ($RequireCommitted) {
            $committedBlob = Get-R24D16Git @(
                "rev-parse", "$Head`:$relative"
            )
            Assert-R24D16 ($blob -ceq $committedBlob) (
                "source_not_committed:$relative"
            )
        }
        $inventory += [ordered]@{
            path = $relative
            raw_sha256 = [string]$file.raw_sha256
            byte_length = [long]$file.byte_length
            git_blob_oid = $blob
        }
    }
    return @($inventory)
}

Assert-R24D16 ($repoRoot -ceq $expectedRepoRoot) "repository_root_initial"
Assert-R24D16 ($evidenceBase -ceq $expectedEvidenceRoot) "evidence_root"
$qualification = $Mode -ceq "Qualification"
$operationLock = $null
$runRoot = ""
$receiptPath = ""
$terminal = $null

try {
    if (-not $CallerHoldsOperationLock) {
        $operationLock = Enter-SporeSporeLocomotionOperationLock `
            -Role conformance
        Assert-R24D16 ([bool]$operationLock.acquired) (
            "locomotion_operation_lock_unavailable"
        )
    }
    foreach ($relative in $sourceInventoryRelatives) {
        Assert-R24D16 (
            Test-Path -LiteralPath (Get-R24D16Path $relative) -PathType Leaf
        ) "required_source_missing:$relative"
    }
    $source = Get-R24D16SourceBoundary -RequireCleanPushed:$qualification
    $head = [string]$source.head
    $modeFolder = $Mode.ToLowerInvariant()
    $baseRoot = Join-Path $evidenceBase (
        "qsdk-r24d16-profile-scoped-recovery-capability\$modeFolder"
    )
    [void][IO.Directory]::CreateDirectory($baseRoot)
    if ($qualification) {
        $priorTerminal = @(Get-ChildItem -LiteralPath $baseRoot `
            -Filter receipt.json -File -Recurse -ErrorAction SilentlyContinue |
            ForEach-Object {
                try {
                    Get-Content -Raw -LiteralPath $_.FullName |
                        ConvertFrom-Json -AsHashtable -Depth 100
                } catch {
                    $null
                }
            } | Where-Object {
                $null -ne $_ -and [string]$_.source.head -ceq $head
            })
        Assert-R24D16 ($priorTerminal.Count -eq 0) (
            "qualification_already_consumed_for_source:$head"
        )
    }
    $runId = (
        [DateTimeOffset]::UtcNow.ToString("yyyyMMddTHHmmssfffZ") + "-" +
        $head.Substring(0, 8) + "-" + [Guid]::NewGuid().ToString("N").Substring(0, 12)
    )
    $runRoot = Join-Path $baseRoot $runId
    [void][IO.Directory]::CreateDirectory($runRoot)
    $receiptPath = Join-Path $runRoot "receipt.json"
    Write-R24D16Json -Path (Join-Path $runRoot "attempt.json") -Value ([ordered]@{
        schema_version = "sporespore_qsdk_r24d16_profile_capability_attempt_v1"
        gate_id = "QSDK-R24D16"
        mode = $Mode
        status = "opened_incomplete_until_terminal_receipt"
        opened_utc = [DateTimeOffset]::UtcNow.ToString("o")
        source_head = $head
        source_tree_git_oid = [string]$source.tree_git_oid
        run_id = $runId
        physical_execution_authorized = $false
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
    })

    $cargoPath = Resolve-R24D16Application $Cargo
    $pythonPath = Resolve-R24D16Application $Python
    $instrumentedPath = Resolve-R24D16Application $InstrumentedGodot
    $stockPath = Resolve-R24D16Application $StockGodot
    $instrumentedConsole = Get-R24D16FileReceipt $instrumentedPath
    $instrumentedEnginePath = $instrumentedPath.Substring(
        0,
        $instrumentedPath.Length - ".console.exe".Length
    ) + ".exe"
    $instrumentedEngine = Get-R24D16FileReceipt $instrumentedEnginePath
    $stockConsole = Get-R24D16FileReceipt $stockPath
    Assert-R24D16 (
        [string]$instrumentedConsole.raw_sha256 -ceq
            "sha256:$expectedInstrumentedConsoleHash" -and
        [long]$instrumentedConsole.byte_length -eq
            $expectedInstrumentedConsoleBytes -and
        [string]$instrumentedEngine.raw_sha256 -ceq
            "sha256:$expectedInstrumentedEngineHash" -and
        [long]$instrumentedEngine.byte_length -eq
            $expectedInstrumentedEngineBytes
    ) "instrumented_binary_pair_identity"
    Assert-R24D16 (
        [string]$stockConsole.raw_sha256 -ceq
            "sha256:$expectedStockConsoleHash" -and
        [long]$stockConsole.byte_length -eq $expectedStockConsoleBytes
    ) "stock_console_identity"

    $sourceInventory = Get-R24D16SourceInventory `
        -Head $head `
        -RequireCommitted:$qualification
    $sourceAuditArguments = @(
        (Get-R24D16Path $sourceAuditRelative)
    )
    if ($qualification) {
        $sourceAuditArguments += "--require-committed-source"
    } else {
        $sourceAuditArguments += "--allow-prospective-uncommitted"
    }
    $sourceAudit = Invoke-R24D16Process `
        -FileName $pythonPath `
        -Arguments $sourceAuditArguments `
        -WorkingDirectory $repoRoot `
        -Label "R24D16 immutable source audit" `
        -LogStem (Join-Path $runRoot "01-source-audit")
    Assert-R24D16 ([bool]$sourceAudit.ok) (
        "source_audit_failed:$($sourceAudit.exit_code)"
    )

    $build = Invoke-R24D16Process `
        -FileName $cargoPath `
        -Arguments @(
            "build",
            "--manifest-path", (Get-R24D16Path $manifestRelative),
            "-p", "sporespore-locomotion-core",
            "-p", "sporespore-godot-adapter",
            "--offline"
        ) `
        -WorkingDirectory $repoRoot `
        -Label "offline recovery core and Godot adapter build" `
        -LogStem (Join-Path $runRoot "02-cargo-build")
    Assert-R24D16 ([bool]$build.ok) "cargo_build_failed:$($build.exit_code)"

    $instrumentedEnvironment = @{
        APPDATA = (Join-Path $runRoot "instrumented-appdata")
        LOCALAPPDATA = (Join-Path $runRoot "instrumented-localappdata")
    }
    $stockEnvironment = @{
        APPDATA = (Join-Path $runRoot "stock-appdata")
        LOCALAPPDATA = (Join-Path $runRoot "stock-localappdata")
    }
    foreach ($path in @(
        $instrumentedEnvironment.APPDATA,
        $instrumentedEnvironment.LOCALAPPDATA,
        $stockEnvironment.APPDATA,
        $stockEnvironment.LOCALAPPDATA
    )) {
        [void][IO.Directory]::CreateDirectory($path)
    }
    $instrumentedRun = Invoke-R24D16Process `
        -FileName $instrumentedPath `
        -Arguments @(
            "--headless",
            "--path", $repoRoot,
            "--log-file", (Join-Path $runRoot "03-instrumented-godot.log"),
            "--script", $workerResource,
            "--",
            "--expected_profile=instrumented"
        ) `
        -WorkingDirectory $repoRoot `
        -Label "exact instrumented profile positive" `
        -LogStem (Join-Path $runRoot "03-instrumented") `
        -Environment $instrumentedEnvironment
    Assert-R24D16 ([bool]$instrumentedRun.ok) (
        "instrumented_runtime_failed:$($instrumentedRun.exit_code)"
    )
    $instrumentedReceipt = Get-R24D16MarkerReceipt `
        -Text ([string]$instrumentedRun.stdout) `
        -Prefix $workerMarker `
        -Label "instrumented"

    $stockRun = Invoke-R24D16Process `
        -FileName $stockPath `
        -Arguments @(
            "--headless",
            "--path", $repoRoot,
            "--log-file", (Join-Path $runRoot "04-stock-godot.log"),
            "--script", $workerResource,
            "--",
            "--expected_profile=stock"
        ) `
        -WorkingDirectory $repoRoot `
        -Label "exact stock runtime typed-refusal negative" `
        -LogStem (Join-Path $runRoot "04-stock") `
        -Environment $stockEnvironment
    Assert-R24D16 ([bool]$stockRun.ok) (
        "stock_runtime_failed:$($stockRun.exit_code)"
    )
    $stockReceipt = Get-R24D16MarkerReceipt `
        -Text ([string]$stockRun.stdout) `
        -Prefix $workerMarker `
        -Label "stock"

    $exact = (
        [bool]$instrumentedReceipt.ok -and
        [string]$instrumentedReceipt.expected_profile -ceq "instrumented" -and
        [bool]$instrumentedReceipt.instrumented_profile_selected -and
        [bool]$instrumentedReceipt.exact_binary_pair_match -and
        [int]$instrumentedReceipt.required_channel_count -eq 10 -and
        [int]$instrumentedReceipt.supported_channel_count -eq 10 -and
        [int]$instrumentedReceipt.unsupported_channel_count -eq 0 -and
        [string]$instrumentedReceipt.core_support_status -ceq "supported_exact" -and
        [bool]$instrumentedReceipt.core_memory_present -and
        [int]$instrumentedReceipt.mutation_count -eq 4 -and
        [int]$instrumentedReceipt.mutation_rejection_count -eq 4 -and
        [bool]$stockReceipt.ok -and
        [string]$stockReceipt.expected_profile -ceq "stock" -and
        -not [bool]$stockReceipt.instrumented_profile_selected -and
        [bool]$stockReceipt.stock_fallback_exact -and
        [int]$stockReceipt.required_channel_count -eq 10 -and
        [int]$stockReceipt.supported_channel_count -eq 8 -and
        [int]$stockReceipt.unsupported_channel_count -eq 2 -and
        [string]$stockReceipt.core_support_status -ceq "unsupported_capability" -and
        [string]$stockReceipt.core_refusal_reason -clike
            "required_channel_unsupported:AppliedActuationReceipts*" -and
        -not [bool]$stockReceipt.core_memory_present -and
        [int]$stockReceipt.mutation_count -eq 4 -and
        [int]$stockReceipt.mutation_rejection_count -eq 4
    )
    foreach ($runtimeReceipt in @($instrumentedReceipt, $stockReceipt)) {
        $exact = $exact -and
            [int]$runtimeReceipt.model_construction_count -eq 0 -and
            [int]$runtimeReceipt.world_attempt_count -eq 0 -and
            [int]$runtimeReceipt.world_build_count -eq 0 -and
            [int]$runtimeReceipt.solver_step_count -eq 0 -and
            -not [bool]$runtimeReceipt.physics_state_modified -and
            -not [bool]$runtimeReceipt.native_observation_collection_executed -and
            -not [bool]$runtimeReceipt.prone_to_standing_claimed -and
            -not [bool]$runtimeReceipt.physical_acceptance_authority -and
            -not [bool]$runtimeReceipt.release_authority
    }
    Assert-R24D16 $exact "combined_runtime_decision"

    $terminal = [ordered]@{
        schema_version = "sporespore_qsdk_r24d16_profile_capability_gate_receipt_v1"
        gate_id = "QSDK-R24D16"
        work_id = (
            "QSDK-R24D16-GODOT-JOLT-PROFILE-SCOPED-" +
            "RECOVERY-CAPABILITY-MAPPING"
        )
        question_class = "non_physical_source_conformance"
        mode = $Mode
        status = if ($qualification) {
            "qualified_exact_profile_mapping_positive_stock_refusal_preserved"
        } else {
            "development_check_passed_non_authoritative"
        }
        ok = $true
        run_id = $runId
        recorded_utc = [DateTimeOffset]::UtcNow.ToString("o")
        source = $source
        source_inventory = $sourceInventory
        source_inventory_count = @($sourceInventory).Count
        runtime_inputs = [ordered]@{
            instrumented_console = $instrumentedConsole
            instrumented_engine = $instrumentedEngine
            stock_console = $stockConsole
        }
        stages = @(
            $sourceAudit,
            $build,
            $instrumentedRun,
            $stockRun
        ) | ForEach-Object {
            [ordered]@{
                label = [string]$_.label
                started_utc = [string]$_.started_utc
                finished_utc = [string]$_.finished_utc
                duration_s = [double]$_.duration_s
                timed_out = [bool]$_.timed_out
                exit_code = [int]$_.exit_code
                ok = [bool]$_.ok
                stdout_file = $_.stdout_file
                stderr_file = $_.stderr_file
            }
        }
        stage_count = 4
        passed_stage_count = 4
        instrumented_positive = $instrumentedReceipt
        stock_negative_control = $stockReceipt
        runtime_process_count = 2
        instrumented_positive_count = 1
        stock_negative_control_count = 1
        capability_mutation_count = 8
        capability_mutation_rejection_count = 8
        empirical_performance_threshold_count = 0
        superiority_margin_count = 0
        equivalence_or_non_inferiority_margin_count = 0
        held_out_validation_cohort_count = 0
        population_claim_count = 0
        profile_scoped_mapping_qualified = [bool]$qualification
        exact_profile_native_capability_conjunction_complete = [bool]$qualification
        stock_profile_promoted = $false
        numerical_accuracy_accepted = $false
        native_observation_collectors_complete = $false
        recovery_controller_implemented = $false
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_question_opened = $false
        recovery_world_opened = $false
        prone_to_standing_world_opened = $false
        turning_claim_changed = $false
        cross_engine_equivalence_claimed = $false
        q_sdk_r24_satisfied = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-R24D16Json -Path $receiptPath -Value $terminal
    Write-Output (
        $terminalMarker + ($terminal | ConvertTo-Json -Depth 100 -Compress)
    )
} catch {
    $failure = [ordered]@{
        schema_version = "sporespore_qsdk_r24d16_profile_capability_gate_receipt_v1"
        gate_id = "QSDK-R24D16"
        question_class = "non_physical_source_conformance"
        mode = $Mode
        status = "failed_or_invalid_profile_mapping_not_adopted"
        ok = $false
        recorded_utc = [DateTimeOffset]::UtcNow.ToString("o")
        failure = [string]$_.Exception.Message
        profile_scoped_mapping_qualified = $false
        exact_profile_native_capability_conjunction_complete = $false
        stock_profile_promoted = $false
        numerical_accuracy_accepted = $false
        native_observation_collectors_complete = $false
        recovery_controller_implemented = $false
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_question_opened = $false
        recovery_world_opened = $false
        prone_to_standing_world_opened = $false
        turning_claim_changed = $false
        cross_engine_equivalence_claimed = $false
        q_sdk_r24_satisfied = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    if (-not [string]::IsNullOrWhiteSpace($receiptPath)) {
        Write-R24D16Json -Path $receiptPath -Value $failure
    }
    Write-Output (
        $terminalMarker + ($failure | ConvertTo-Json -Depth 100 -Compress)
    )
    throw
} finally {
    if ($null -ne $operationLock) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $operationLock
    }
}

#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet("ZeroWorld", "Physical")]
    [string]$Mode = "ZeroWorld",
    [string]$AuthorizationCommit = "",
    [string]$ZeroWorldReceiptPath = "",
    [string]$Python = "python",
    [string]$GodotSourceRoot = (
        "C:\Users\Cole\CodeStuff\dependencies\godot-sporespore-4.7"
    ),
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$godotRoot = [IO.Path]::GetFullPath($GodotSourceRoot)
$evidenceBase = [IO.Path]::GetFullPath($EvidenceRoot)
$expectedRepoRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedGodotRoot = (
    "C:\Users\Cole\CodeStuff\dependencies\godot-sporespore-4.7"
)
$expectedEvidenceRoot = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)
$expectedRepoRemote = "https://github.com/Slagathore/sporespore.git"
$expectedGodotRemote = "https://github.com/godotengine/godot.git"
$expectedGodotCommit = "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"
$expectedPatchHash = (
    "9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c"
)
$contractRelative = (
    "sdk/recovery/" +
    "r24d8_godot_jolt_active_step_snapshot_timing_preregistration_v1.json"
)
$manifestRelative = (
    "sdk/recovery/" +
    "r24d8_godot_jolt_active_step_snapshot_timing_validation_manifest.json"
)
$patchRelative = (
    "sdk/adapters/godot/engine_patches/" +
    "godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch"
)
$rigRelative = (
    "scripts/lab/rigs/" +
    "r24d8_godot_jolt_active_step_snapshot_timing_rig.gd"
)
$workerRelative = (
    "tests/" +
    "test_sdk_qsdk_r24d8_godot_jolt_active_step_snapshot_timing_worker.gd"
)
$evaluatorRelative = (
    "sdk/recovery/" +
    "r24d8_godot_jolt_active_step_snapshot_timing_evaluator.py"
)
$freezeAuditRelative = (
    "tests/test_qsdk_r24d8_godot_jolt_active_step_snapshot_timing_freeze.ps1"
)
$predecessorClosureAuditRelative = (
    "tests/test_qsdk_r24d7_one_hinge_telemetry_physical_failure_closure.ps1"
)
$predecessorCompatibilityAuditRelative = (
    "tests/test_qsdk_r24d8_predecessor_evidence_compatibility.ps1"
)
$readyPrefix = "QSDK_R24D8_GODOT_SUPERVISOR_TERMINATION_READY "
$zeroWorkerPrefix = "QSDK_R24D8_WORKER_ZERO_WORLD "
$physicalWorkerPrefix = "QSDK_R24D8_PHYSICAL_RAW_REPORT "
$evaluationPrefix = "QSDK_R24D8_EVALUATION_PASS "
$expectedPatchedPaths = @(
    "modules/jolt_physics/joints/jolt_hinge_joint_3d.cpp",
    "modules/jolt_physics/joints/jolt_hinge_joint_3d.h",
    "modules/jolt_physics/joints/jolt_joint_3d.h",
    "modules/jolt_physics/jolt_physics_server_3d.cpp",
    "modules/jolt_physics/jolt_physics_server_3d.h",
    "modules/jolt_physics/register_types.cpp",
    "modules/jolt_physics/spaces/jolt_space_3d.cpp",
    "modules/jolt_physics/spaces/jolt_space_3d.h",
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
. (Join-Path $sdkRoot "godot_receipt_terminated_process.ps1")
. (Join-Path $sdkRoot "content_addressed_artifact_store.ps1")

function Assert-R24D8Supervisor {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) { throw "QSDK-R24D8 supervisor: $Code" }
}

function Get-R24D8Path {
    param([Parameter(Mandatory)][string]$Relative)
    return [IO.Path]::GetFullPath((Join-Path $repoRoot $Relative))
}

function Resolve-R24D8Application {
    param([Parameter(Mandatory)][string]$Command)
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R24D8Supervisor (
            Test-Path -LiteralPath $resolved -PathType Leaf
        ) "application_missing:$resolved"
        return $resolved
    }
    $candidate = Get-Command -Name $Command -CommandType Application |
        Select-Object -First 1
    Assert-R24D8Supervisor ($null -ne $candidate) "application_missing:$Command"
    return [IO.Path]::GetFullPath([string]$candidate.Source)
}

function Get-R24D8GitValue {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    $output = @(& git -C $Root @Arguments 2>&1)
    Assert-R24D8Supervisor ($LASTEXITCODE -eq 0) (
        "git_$($Arguments -join '_'):$($output -join '|')"
    )
    return ($output -join "`n").Trim()
}

function Get-R24D8FileReceipt {
    param([Parameter(Mandatory)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    Assert-R24D8Supervisor (Test-Path -LiteralPath $full -PathType Leaf) (
        "file_missing:$full"
    )
    $item = Get-Item -LiteralPath $full
    return [ordered]@{
        path = $full.Replace("\", "/")
        raw_sha256 = "sha256:" + (
            Get-FileHash -LiteralPath $full -Algorithm SHA256
        ).Hash.ToLowerInvariant()
        byte_length = [long]$item.Length
    }
}

function Publish-R24D8Artifact {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$MediaType = "application/json"
    )
    return Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot `
        -ArtifactPath $Path `
        -MediaType $MediaType
}

function Get-R24D8Marker {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines,
        [Parameter(Mandatory)][string]$Prefix,
        [Parameter(Mandatory)][string]$Code
    )
    $matches = @($Lines | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R24D8Supervisor ($matches.Count -eq 1) (
        "$Code`_marker_count:$($matches.Count)"
    )
    return ([string]$matches[0]).Substring($Prefix.Length)
}

function Invoke-R24D8Checked {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$LogPath
    )
    $started = [DateTimeOffset]::UtcNow
    Push-Location -LiteralPath $WorkingDirectory
    try {
        $output = @(& $FileName @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    $finished = [DateTimeOffset]::UtcNow
    $lines = @($output | ForEach-Object { [string]$_ })
    $text = @(
        "label=$Label",
        "started_utc=$($started.ToString('o'))",
        "finished_utc=$($finished.ToString('o'))",
        "exit_code=$exitCode",
        "command=$FileName $($Arguments -join ' ')",
        "--- output ---",
        $lines
    ) -join "`n"
    [IO.File]::WriteAllText(
        $LogPath,
        $text + "`n",
        [Text.UTF8Encoding]::new($false)
    )
    Assert-R24D8Supervisor ($exitCode -eq 0) (
        "$Label`:$($lines -join '|')"
    )
    return [ordered]@{
        output = $lines
        duration_s = [Math]::Round(($finished - $started).TotalSeconds, 6)
        log = Get-R24D8FileReceipt $LogPath
    }
}

function Assert-R24D8RepositoryBoundary {
    $root = Get-R24D8GitValue -Root $repoRoot -Arguments @(
        "rev-parse", "--show-toplevel"
    )
    $remote = Get-R24D8GitValue -Root $repoRoot -Arguments @(
        "remote", "get-url", "origin"
    )
    $branch = Get-R24D8GitValue -Root $repoRoot -Arguments @(
        "branch", "--show-current"
    )
    $head = Get-R24D8GitValue -Root $repoRoot -Arguments @("rev-parse", "HEAD")
    $upstream = Get-R24D8GitValue -Root $repoRoot -Arguments @(
        "rev-parse", "@{upstream}"
    )
    $cached = Get-R24D8GitValue -Root $repoRoot -Arguments @(
        "rev-parse", "refs/remotes/origin/main"
    )
    $liveText = Get-R24D8GitValue -Root $repoRoot -Arguments @(
        "ls-remote", "--heads", "origin", "refs/heads/main"
    )
    $live = $liveText.Split("`t")[0]
    $status = Get-R24D8GitValue -Root $repoRoot -Arguments @(
        "status", "--short"
    )
    $worktreeText = Get-R24D8GitValue -Root $repoRoot -Arguments @(
        "worktree", "list", "--porcelain"
    )
    $worktrees = @($worktreeText -split "`r?`n" | Where-Object {
        $_.StartsWith("worktree ", [StringComparison]::Ordinal)
    })
    Assert-R24D8Supervisor (
        [IO.Path]::GetFullPath($root) -ceq $expectedRepoRoot -and
        $repoRoot -ceq $expectedRepoRoot
    ) "repository_root"
    Assert-R24D8Supervisor ($remote -ceq $expectedRepoRemote) "repository_remote"
    Assert-R24D8Supervisor ($branch -ceq "main") "branch"
    Assert-R24D8Supervisor ([string]::IsNullOrEmpty($status)) "dirty_worktree"
    Assert-R24D8Supervisor (
        $head -ceq $upstream -and $head -ceq $cached -and $head -ceq $live
    ) "local_upstream_cached_live_inequality"
    Assert-R24D8Supervisor ($worktrees.Count -eq 1) "worktree_count"
    return [ordered]@{
        root = $root.Replace("\", "/")
        remote = $remote
        branch = $branch
        head = $head
        upstream = $upstream
        cached_origin_main = $cached
        live_origin_main = $live
        worktree_count = $worktrees.Count
        worktree_clean = $true
    }
}

function Assert-R24D8GodotSourceBoundary {
    $root = Get-R24D8GitValue -Root $godotRoot -Arguments @(
        "rev-parse", "--show-toplevel"
    )
    $remote = Get-R24D8GitValue -Root $godotRoot -Arguments @(
        "remote", "get-url", "origin"
    )
    $head = Get-R24D8GitValue -Root $godotRoot -Arguments @("rev-parse", "HEAD")
    Assert-R24D8Supervisor (
        [IO.Path]::GetFullPath($root) -ceq $godotRoot
    ) "godot_source_root"
    Assert-R24D8Supervisor ($remote -ceq $expectedGodotRemote) "godot_remote"
    Assert-R24D8Supervisor ($head -ceq $expectedGodotCommit) "godot_commit"
    $statusOutput = @(& git -C $godotRoot status --short 2>&1)
    Assert-R24D8Supervisor ($LASTEXITCODE -eq 0) "godot_status"
    $statusPaths = @($statusOutput | ForEach-Object {
        ([string]$_).Substring(3).Replace("\", "/")
    })
    Assert-R24D8Supervisor (
        (($statusPaths | Sort-Object) -join "|") -ceq
        (($expectedPatchedPaths | Sort-Object) -join "|")
    ) "godot_dirty_path_set"
    $patchPath = Get-R24D8Path $patchRelative
    $patchReceipt = Get-R24D8FileReceipt $patchPath
    Assert-R24D8Supervisor (
        [string]$patchReceipt.raw_sha256 -ceq "sha256:$expectedPatchHash"
    ) "patch_digest"
    $diffLines = @(& git -C $godotRoot diff --no-ext-diff 2>&1)
    Assert-R24D8Supervisor ($LASTEXITCODE -eq 0) "godot_diff"
    $diffText = (($diffLines -join "`n") + "`n").Replace("`r`n", "`n")
    $patchText = [IO.File]::ReadAllText($patchPath).
        Replace("`r`n", "`n").TrimEnd("`n") + "`n"
    Assert-R24D8Supervisor ($diffText -ceq $patchText) "godot_diff_patch_inequality"
    $reverse = @(
        & git -C $godotRoot apply --reverse --check --whitespace=error-all $patchPath 2>&1
    )
    Assert-R24D8Supervisor ($LASTEXITCODE -eq 0) (
        "patch_reverse_check:$($reverse -join '|')"
    )
    return [ordered]@{
        root = $root.Replace("\", "/")
        remote = $remote
        commit = $head
        combined_patch = $patchReceipt
        patched_file_count = $expectedPatchedPaths.Count
        exact_external_diff_verified = $true
        reverse_apply_check_passed = $true
    }
}

function New-R24D8Project {
    param([Parameter(Mandatory)][string]$ProjectRoot)
    $rigDestination = Join-Path $ProjectRoot (
        "scripts\lab\rigs\" +
        "r24d8_godot_jolt_active_step_snapshot_timing_rig.gd"
    )
    $workerDestination = Join-Path $ProjectRoot (
        "tests\" +
        "test_sdk_qsdk_r24d8_godot_jolt_active_step_snapshot_timing_worker.gd"
    )
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $rigDestination))
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $workerDestination))
    Copy-Item -LiteralPath (Get-R24D8Path $rigRelative) -Destination $rigDestination
    Copy-Item `
        -LiteralPath (Get-R24D8Path $workerRelative) `
        -Destination $workerDestination
    $projectText = @'
; QSDK-R24D8 isolated active-step snapshot timing control.
config_version=5

[application]
config/name="qsdk-r24d8-active-step-snapshot-timing"
config/features=PackedStringArray("4.7", "Forward Plus")
run/flush_stdout_on_print=true

[debug]
gdscript/warnings/shadowed_global_identifier=0

[physics]
common/physics_ticks_per_second=120
3d/physics_engine="Jolt Physics"
3d/run_on_separate_thread=false
jolt_physics_3d/simulation/velocity_steps=20
jolt_physics_3d/simulation/position_steps=7
'@
    [IO.File]::WriteAllText(
        (Join-Path $ProjectRoot "project.godot"),
        $projectText.Replace("`r`n", "`n") + "`n",
        [Text.UTF8Encoding]::new($false)
    )
}

function Invoke-R24D8Worker {
    param(
        [Parameter(Mandatory)][string]$ConsolePath,
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][string]$RunRoot,
        [Parameter(Mandatory)][string]$WorkerMode,
        [Parameter(Mandatory)][string]$Nonce,
        [Parameter(Mandatory)][string]$Head,
        [Parameter(Mandatory)][string]$ReportPath
    )
    $engineLogPath = Join-Path $RunRoot "godot-$WorkerMode-engine.log"
    $arguments = @(
        "--headless",
        "--path", $ProjectRoot,
        "--log-file", $engineLogPath,
        "--script", (
            "res://tests/" +
            "test_sdk_qsdk_r24d8_godot_jolt_active_step_snapshot_timing_worker.gd"
        ),
        "--",
        "--mode=$WorkerMode",
        "--nonce=$Nonce",
        "--source_commit=$Head",
        "--report_path=$ReportPath"
    )
    $environment = @{
        SPORESPORE_R24D8_SUPERVISED_TERMINATION = "1"
        SPORESPORE_R24D8_TERMINATION_NONCE = $Nonce
        SPORESPORE_R24D8_EXECUTION_NONCE = $Nonce
        SPORESPORE_R24D8_SOURCE_COMMIT = $Head
        APPDATA = (Join-Path $RunRoot "appdata")
        LOCALAPPDATA = (Join-Path $RunRoot "localappdata")
    }
    [void][IO.Directory]::CreateDirectory([string]$environment.APPDATA)
    [void][IO.Directory]::CreateDirectory([string]$environment.LOCALAPPDATA)
    $result = Invoke-SporeSporeGodotReceiptTerminatedProcess `
        -FileName $ConsolePath `
        -Arguments $arguments `
        -WorkingDirectory $ProjectRoot `
        -ReadyMarkerPrefix $readyPrefix `
        -ExpectedNonce $Nonce `
        -Environment $environment `
        -ScrubEnvironmentNames @(
            "SPORESPORE_R24D8_EXECUTION_NONCE",
            "SPORESPORE_R24D8_SOURCE_COMMIT"
        ) `
        -TimeoutSeconds 180
    $stdoutPath = Join-Path $RunRoot "godot-$WorkerMode-stdout.log"
    $stderrPath = Join-Path $RunRoot "godot-$WorkerMode-stderr.log"
    [IO.File]::WriteAllText(
        $stdoutPath,
        [string]$result.stdout,
        [Text.UTF8Encoding]::new($false)
    )
    [IO.File]::WriteAllText(
        $stderrPath,
        [string]$result.stderr,
        [Text.UTF8Encoding]::new($false)
    )
    Assert-R24D8Supervisor (
        [bool]$result.termination_protocol_valid -and
        [bool]$result.supervisor_terminated -and
        [int]$result.exit_code -eq 0
    ) (
        "worker_$WorkerMode`_failed:semantic=$($result.exit_code):" +
        "host=$($result.host_exit_code):protocol=" +
        "$($result.termination_protocol_failure_code)"
    )
    $stdoutLines = @(([string]$result.stdout) -split "`r?`n")
    $errorLines = @(
        $stdoutLines + @(([string]$result.stderr) -split "`r?`n") |
        Where-Object { $_ -match "(^|\s)(SCRIPT ERROR|ERROR):" }
    )
    Assert-R24D8Supervisor ($errorLines.Count -eq 0) (
        "worker_$WorkerMode`_error_lines:$($errorLines -join '|')"
    )
    Assert-R24D8Supervisor (Test-Path -LiteralPath $ReportPath -PathType Leaf) (
        "worker_$WorkerMode`_report_missing"
    )
    return [ordered]@{
        result = $result
        stdout_lines = $stdoutLines
        stdout = Get-R24D8FileReceipt $stdoutPath
        stderr = Get-R24D8FileReceipt $stderrPath
        engine_log = Get-R24D8FileReceipt $engineLogPath
        report = Get-R24D8FileReceipt $ReportPath
    }
}

function Invoke-R24D8Evaluation {
    param(
        [Parameter(Mandatory)][string]$PythonPath,
        [Parameter(Mandatory)][string]$InputPath,
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][string]$SourceCommit,
        [Parameter(Mandatory)][string]$Nonce,
        [Parameter(Mandatory)][string]$EvidenceKind,
        [Parameter(Mandatory)][string]$LogPath
    )
    $run = Invoke-R24D8Checked `
        -FileName $PythonPath `
        -Arguments @(
            (Get-R24D8Path $evaluatorRelative),
            "--input", $InputPath,
            "--output", $OutputPath,
            "--expected-source-commit", $SourceCommit,
            "--expected-nonce", $Nonce,
            "--expected-evidence-kind", $EvidenceKind
        ) `
        -WorkingDirectory $repoRoot `
        -Label "R24D8 $EvidenceKind evaluator" `
        -LogPath $LogPath
    [void](Get-R24D8Marker `
        -Lines $run.output `
        -Prefix $evaluationPrefix `
        -Code "$EvidenceKind`_evaluation")
    return [ordered]@{
        run = $run
        output = Get-R24D8FileReceipt $OutputPath
        receipt = Get-Content -Raw -LiteralPath $OutputPath |
            ConvertFrom-Json -AsHashtable -Depth 100
    }
}

function Assert-R24D8ZeroReceipt {
    param(
        [Parameter(Mandatory)][hashtable]$Receipt,
        [Parameter(Mandatory)][string]$ExpectedHead
    )
    $liveManifest = Get-R24D8FileReceipt (Get-R24D8Path $manifestRelative)
    $stageNames = @($Receipt.stages | ForEach-Object { [string]$_.name })
    Assert-R24D8Supervisor (
        [string]$Receipt.schema_version -ceq
            "sporespore_qsdk_r24d8_active_step_snapshot_zero_world_receipt_v1" -and
        [bool]$Receipt.ok -and
        [string]$Receipt.gate_id -ceq "QSDK-R24D8" -and
        [string]$Receipt.question_class -ceq "development" -and
        [string]$Receipt.status -ceq
            "complete_zero_world_gate_passed_physical_execution_separately_authorized" -and
        [string]$Receipt.source.head -ceq $ExpectedHead -and
        [string]$Receipt.source.root -ceq $expectedRepoRoot.Replace("\", "/") -and
        [string]$Receipt.source.remote -ceq $expectedRepoRemote -and
        [string]$Receipt.source.branch -ceq "main" -and
        [string]$Receipt.source.upstream -ceq $ExpectedHead -and
        [string]$Receipt.source.cached_origin_main -ceq $ExpectedHead -and
        [string]$Receipt.source.live_origin_main -ceq $ExpectedHead -and
        [int]$Receipt.source.worktree_count -eq 1 -and
        [bool]$Receipt.source.worktree_clean -and
        [string]$Receipt.godot_source.root -ceq $expectedGodotRoot.Replace("\", "/") -and
        [string]$Receipt.godot_source.remote -ceq $expectedGodotRemote -and
        [string]$Receipt.godot_source.commit -ceq $expectedGodotCommit -and
        [string]$Receipt.godot_source.combined_patch.raw_sha256 -ceq
            "sha256:$expectedPatchHash" -and
        [int]$Receipt.godot_source.patched_file_count -eq 10 -and
        [bool]$Receipt.godot_source.exact_external_diff_verified -and
        [bool]$Receipt.godot_source.reverse_apply_check_passed -and
        [string]$Receipt.validation_manifest.path -ceq
            [string]$liveManifest.path -and
        [string]$Receipt.validation_manifest.raw_sha256 -ceq
            [string]$liveManifest.raw_sha256 -and
        [long]$Receipt.validation_manifest.byte_length -eq
            [long]$liveManifest.byte_length -and
        $stageNames.Count -eq 5 -and
        ($stageNames -join "|") -ceq (
            "immutable_r24d7_closure|r24d8_freeze|" +
            "r24d8_evaluator_self_test|cold_cleanup|cold_build"
        ) -and
        [int]$Receipt.binary_pair.retained_binary_count -eq 2 -and
        [bool]$Receipt.binary_pair.executed_retained_pair -and
        -not [bool]$Receipt.binary_pair.reproducible_build_claimed -and
        -not [bool]$Receipt.binary_pair.result_reuse_authority -and
        [bool]$Receipt.worker.receipt.ok -and
        [bool]$Receipt.worker.receipt.engine_freeze_matches -and
        [bool]$Receipt.worker.receipt.invalid_rid_refused -and
        [bool]$Receipt.worker.receipt.synthetic_report_written -and
        [int]$Receipt.worker.receipt.world_attempt_count -eq 0 -and
        [int]$Receipt.worker.receipt.world_build_count -eq 0 -and
        [int]$Receipt.worker.receipt.solver_step_count -eq 0 -and
        [bool]$Receipt.evaluation.receipt.ok -and
        [string]$Receipt.evaluation.receipt.result -ceq
            "synthetic_shape_conforms_zero_world_only" -and
        [int]$Receipt.actual_counts.world_attempt_count -eq 0 -and
        [int]$Receipt.actual_counts.world_build_count -eq 0 -and
        [int]$Receipt.actual_counts.solver_step_count -eq 0 -and
        [int]$Receipt.actual_counts.physical_world_count -eq 0 -and
        [int]$Receipt.synthetic_shape.declared_world_count -eq 1 -and
        [int]$Receipt.synthetic_shape.declared_solver_step_count -eq 8 -and
        [int]$Receipt.synthetic_shape.declared_retained_sample_count -eq 8 -and
        [bool]$Receipt.claims.complete_zero_world_gate_passed -and
        -not [bool]$Receipt.claims.physical_timing_question_executed -and
        -not [bool]$Receipt.claims.instrumented_profile_promoted -and
        -not [bool]$Receipt.claims.recovery_world_opened -and
        -not [bool]$Receipt.claims.prone_to_standing_world_opened -and
        -not [bool]$Receipt.claims.turning_claim_changed -and
        -not [bool]$Receipt.claims.cross_engine_equivalence_claimed -and
        -not [bool]$Receipt.claims.physical_acceptance_authority -and
        -not [bool]$Receipt.claims.release_authority
    ) "zero_world_receipt"
    foreach ($binaryName in @("console", "engine")) {
        $binary = [hashtable]$Receipt.binary_pair[$binaryName]
        $binaryCas = [hashtable]$binary.cas
        $liveBinary = Get-R24D8FileReceipt ([string]$binary.path)
        Assert-R24D8Supervisor (
            (Test-Path -LiteralPath ([string]$binary.path) -PathType Leaf) -and
            [string]$binary.raw_sha256 -ceq
                [string]$liveBinary.raw_sha256 -and
            [long]$binary.byte_length -eq
                [long]$liveBinary.byte_length -and
            [string]$binaryCas.sha256 -ceq [string]$binary.raw_sha256 -and
            [long]$binaryCas.byte_length -eq [long]$binary.byte_length -and
            (Test-SporeSporeStoredArtifact `
                -Directory (Split-Path -Parent ([string]$binaryCas.payload_path)) `
                -ExpectedSha256 ([string]$binary.raw_sha256).Substring(7) `
                -ExpectedByteLength ([long]$binary.byte_length))
        ) "zero_world_binary_$binaryName"
    }
}

function Get-R24D8MatchingAttempts {
    param(
        [Parameter(Mandatory)][string]$PhysicalRoot,
        [Parameter(Mandatory)][string]$SourceCommit,
        [Parameter(Mandatory)][string]$ConsoleSha,
        [Parameter(Mandatory)][string]$EngineSha
    )
    if (-not (Test-Path -LiteralPath $PhysicalRoot -PathType Container)) {
        return @()
    }
    $matches = [Collections.Generic.List[string]]::new()
    foreach ($file in @(Get-ChildItem -LiteralPath $PhysicalRoot `
        -Filter "attempt.json" -File -Recurse -ErrorAction Stop)) {
        $attempt = Get-Content -Raw -LiteralPath $file.FullName |
            ConvertFrom-Json -AsHashtable -Depth 100
        if (
            [string]$attempt.source_commit -ceq $SourceCommit -and
            [string]$attempt.console_binary_sha256 -ceq $ConsoleSha -and
            [string]$attempt.engine_binary_sha256 -ceq $EngineSha
        ) {
            $matches.Add($file.FullName)
        }
    }
    return @($matches)
}

$operationLock = $null
$runRoot = ""
$physicalAttemptCreated = $false
try {
    $lockRole = if ($Mode -ceq "Physical") { "physical" } else { "conformance" }
    $operationLock = Enter-SporeSporeLocomotionOperationLock -Role $lockRole
    Assert-R24D8Supervisor ([bool]$operationLock.acquired) (
        "another_physical_or_conformance_workload_owns_the_lock"
    )
    Assert-R24D8Supervisor ($godotRoot -ceq $expectedGodotRoot) (
        "godot_source_root_substitution_forbidden"
    )
    Assert-R24D8Supervisor ($evidenceBase -ceq $expectedEvidenceRoot) (
        "evidence_root_substitution_forbidden"
    )
    $source = Assert-R24D8RepositoryBoundary
    $head = [string]$source.head
    if ($Mode -ceq "Physical") {
        Assert-R24D8Supervisor ($AuthorizationCommit -ceq $head) (
            "authorization_commit"
        )
    }
    $godotSource = Assert-R24D8GodotSourceBoundary
    $pythonPath = Resolve-R24D8Application $Python
    Assert-R24D8Supervisor (
        -not $evidenceBase.StartsWith(
            $repoRoot + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        )
    ) "evidence_root_inside_repository"

    $preflightRoot = Join-Path $evidenceBase "qsdk-r24d8-active-step-snapshot"
    [void][IO.Directory]::CreateDirectory($preflightRoot)
    $stamp = [DateTimeOffset]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
    if ($Mode -ceq "ZeroWorld") {
        $runRoot = Join-Path $preflightRoot (
            "zero-world\$stamp-$($head.Substring(0, 8))-$($expectedPatchHash.Substring(0, 12))"
        )
        Assert-R24D8Supervisor (-not (Test-Path -LiteralPath $runRoot)) (
            "run_root_exists"
        )
        [void][IO.Directory]::CreateDirectory($runRoot)
        $stageReceipts = [Collections.Generic.List[object]]::new()
        $stageDefinitions = @(
            [ordered]@{
                name = "immutable_r24d7_closure"
                file = "pwsh"
                arguments = @(
                    "-NoLogo", "-NoProfile", "-File",
                    (Get-R24D8Path $predecessorCompatibilityAuditRelative),
                    "-GodotRepositoryRoot", $godotRoot
                )
            },
            [ordered]@{
                name = "r24d8_freeze"
                file = "pwsh"
                arguments = @(
                    "-NoLogo", "-NoProfile", "-File",
                    (Get-R24D8Path $freezeAuditRelative),
                    "-Python", $pythonPath,
                    "-GodotSourceRoot", $godotRoot
                )
            },
            [ordered]@{
                name = "r24d8_evaluator_self_test"
                file = $pythonPath
                arguments = @(
                    (Get-R24D8Path $evaluatorRelative), "--self-test"
                )
            }
        )
        $stageIndex = 0
        foreach ($stage in $stageDefinitions) {
            $stageIndex += 1
            $logPath = Join-Path $runRoot (
                "{0:d2}-{1}.log" -f $stageIndex, [string]$stage.name
            )
            $resolvedFile = Resolve-R24D8Application ([string]$stage.file)
            $stageRun = Invoke-R24D8Checked `
                -FileName $resolvedFile `
                -Arguments @($stage.arguments) `
                -WorkingDirectory $repoRoot `
                -Label ([string]$stage.name) `
                -LogPath $logPath
            $stageReceipts.Add([ordered]@{
                index = $stageIndex
                name = [string]$stage.name
                duration_s = [double]$stageRun.duration_s
                log = $stageRun.log
                cas = Publish-R24D8Artifact -Path $logPath -MediaType "text/plain"
            })
        }

        $cleanLog = Join-Path $runRoot "04-cold-clean.log"
        $cleanRun = Invoke-R24D8Checked `
            -FileName $pythonPath `
            -Arguments (@("-m", "SCons", "--clean") + $sconsArguments) `
            -WorkingDirectory $godotRoot `
            -Label "R24D8 pinned Godot cold cleanup" `
            -LogPath $cleanLog
        $buildLog = Join-Path $runRoot "05-cold-build.log"
        $buildRun = Invoke-R24D8Checked `
            -FileName $pythonPath `
            -Arguments (@("-m", "SCons") + $sconsArguments) `
            -WorkingDirectory $godotRoot `
            -Label "R24D8 pinned Godot cold build" `
            -LogPath $buildLog
        $sourceAfterBuild = Assert-R24D8RepositoryBoundary
        Assert-R24D8Supervisor ([string]$sourceAfterBuild.head -ceq $head) (
            "source_drift_during_cold_build"
        )
        [void](Assert-R24D8GodotSourceBoundary)
        $stageReceipts.Add([ordered]@{
            index = 4
            name = "cold_cleanup"
            duration_s = [double]$cleanRun.duration_s
            log = $cleanRun.log
            cas = Publish-R24D8Artifact -Path $cleanLog -MediaType "text/plain"
        })
        $stageReceipts.Add([ordered]@{
            index = 5
            name = "cold_build"
            duration_s = [double]$buildRun.duration_s
            log = $buildRun.log
            cas = Publish-R24D8Artifact -Path $buildLog -MediaType "text/plain"
        })
        $consoleSource = Join-Path $godotRoot (
            "bin\godot.windows.editor.dev.x86_64.console.exe"
        )
        $engineSource = Join-Path $godotRoot (
            "bin\godot.windows.editor.dev.x86_64.exe"
        )
        Assert-R24D8Supervisor (
            (Test-Path -LiteralPath $consoleSource -PathType Leaf) -and
            (Test-Path -LiteralPath $engineSource -PathType Leaf)
        ) "cold_binary_pair_missing"
        $artifactRoot = Join-Path $runRoot "artifacts"
        [void][IO.Directory]::CreateDirectory($artifactRoot)
        $consolePath = Join-Path $artifactRoot (
            Split-Path -Leaf $consoleSource
        )
        $enginePath = Join-Path $artifactRoot (Split-Path -Leaf $engineSource)
        Copy-Item -LiteralPath $consoleSource -Destination $consolePath
        Copy-Item -LiteralPath $engineSource -Destination $enginePath
        $consoleReceipt = Get-R24D8FileReceipt $consolePath
        $engineReceipt = Get-R24D8FileReceipt $enginePath
        $consoleSourceReceipt = Get-R24D8FileReceipt $consoleSource
        $engineSourceReceipt = Get-R24D8FileReceipt $engineSource
        Assert-R24D8Supervisor (
            [string]$consoleReceipt.raw_sha256 -ceq
                [string]$consoleSourceReceipt.raw_sha256 -and
            [string]$engineReceipt.raw_sha256 -ceq
                [string]$engineSourceReceipt.raw_sha256
        ) "retained_binary_pair_copy"
        $consoleCas = Publish-R24D8Artifact `
            -Path $consolePath `
            -MediaType "application/vnd.microsoft.portable-executable"
        $engineCas = Publish-R24D8Artifact `
            -Path $enginePath `
            -MediaType "application/vnd.microsoft.portable-executable"

        $projectRoot = Join-Path $runRoot "project"
        [void][IO.Directory]::CreateDirectory($projectRoot)
        New-R24D8Project -ProjectRoot $projectRoot
        $nonce = [Guid]::NewGuid().ToString("N")
        $rawPath = Join-Path $runRoot "synthetic-raw-report.json"
        $worker = Invoke-R24D8Worker `
            -ConsolePath $consolePath `
            -ProjectRoot $projectRoot `
            -RunRoot $runRoot `
            -WorkerMode "zero_world_preflight" `
            -Nonce $nonce `
            -Head $head `
            -ReportPath $rawPath
        $workerMarkerText = Get-R24D8Marker `
            -Lines $worker.stdout_lines `
            -Prefix $zeroWorkerPrefix `
            -Code "zero_worker"
        $workerReceipt = $workerMarkerText |
            ConvertFrom-Json -AsHashtable -Depth 100
        Assert-R24D8Supervisor (
            [bool]$workerReceipt.ok -and
            [bool]$workerReceipt.engine_freeze_matches -and
            [bool]$workerReceipt.fixture_description_matches -and
            [bool]$workerReceipt.invalid_rid_refused -and
            [bool]$workerReceipt.synthetic_report_written -and
            [double]$workerReceipt.active_physics_object_count -eq 0.0 -and
            [int]$workerReceipt.telemetry_field_count -eq 15 -and
            [string]$workerReceipt.telemetry_schema -ceq
                "sporespore.godot_jolt_hinge_motor_telemetry.v2" -and
            [int]$workerReceipt.world_attempt_count -eq 0 -and
            [int]$workerReceipt.world_build_count -eq 0 -and
            [int]$workerReceipt.solver_step_count -eq 0 -and
            -not [bool]$workerReceipt.physical_acceptance_authority -and
            -not [bool]$workerReceipt.release_authority
        ) "zero_worker_receipt"
        $evaluationPath = Join-Path $runRoot "synthetic-evaluation.json"
        $evaluationLog = Join-Path $runRoot "06-synthetic-evaluation.log"
        $evaluation = Invoke-R24D8Evaluation `
            -PythonPath $pythonPath `
            -InputPath $rawPath `
            -OutputPath $evaluationPath `
            -SourceCommit $head `
            -Nonce $nonce `
            -EvidenceKind "synthetic_zero_world" `
            -LogPath $evaluationLog
        Assert-R24D8Supervisor (
            [bool]$evaluation.receipt.ok -and
            [string]$evaluation.receipt.result -ceq
                "synthetic_shape_conforms_zero_world_only" -and
            -not [bool]$evaluation.receipt.physical_acceptance_authority -and
            -not [bool]$evaluation.receipt.release_authority
        ) "zero_evaluation_receipt"
        $rawReceipt = Get-R24D8FileReceipt $rawPath
        $rawCas = Publish-R24D8Artifact -Path $rawPath
        $evaluationCas = Publish-R24D8Artifact -Path $evaluationPath
        $evaluationLogCas = Publish-R24D8Artifact `
            -Path $evaluationLog `
            -MediaType "text/plain"
        $stdoutCas = Publish-R24D8Artifact `
            -Path ([string]$worker.stdout.path) `
            -MediaType "text/plain"
        $stderrCas = Publish-R24D8Artifact `
            -Path ([string]$worker.stderr.path) `
            -MediaType "text/plain"
        $engineLogCas = Publish-R24D8Artifact `
            -Path ([string]$worker.engine_log.path) `
            -MediaType "text/plain"
        $postConsoleReceipt = Get-R24D8FileReceipt $consolePath
        $postEngineReceipt = Get-R24D8FileReceipt $enginePath
        Assert-R24D8Supervisor (
            [string]$postConsoleReceipt.raw_sha256 -ceq
                [string]$consoleReceipt.raw_sha256 -and
            [string]$postEngineReceipt.raw_sha256 -ceq
                [string]$engineReceipt.raw_sha256
        ) "retained_binary_pair_drift"
        $sourceAfterZeroWorld = Assert-R24D8RepositoryBoundary
        Assert-R24D8Supervisor ([string]$sourceAfterZeroWorld.head -ceq $head) (
            "source_drift_during_zero_world_runtime"
        )
        [void](Assert-R24D8GodotSourceBoundary)

        $receipt = [ordered]@{
            schema_version = (
                "sporespore_qsdk_r24d8_active_step_snapshot_zero_world_receipt_v1"
            )
            ok = $true
            gate_id = "QSDK-R24D8"
            question_class = "development"
            status = (
                "complete_zero_world_gate_passed_physical_execution_separately_authorized"
            )
            source = $source
            godot_source = $godotSource
            validation_manifest = Get-R24D8FileReceipt (
                Get-R24D8Path $manifestRelative
            )
            stages = @($stageReceipts)
            binary_pair = [ordered]@{
                console = [ordered]@{
                    path = [string]$consoleReceipt.path
                    raw_sha256 = [string]$consoleReceipt.raw_sha256
                    byte_length = [long]$consoleReceipt.byte_length
                    cas = $consoleCas
                }
                engine = [ordered]@{
                    path = [string]$engineReceipt.path
                    raw_sha256 = [string]$engineReceipt.raw_sha256
                    byte_length = [long]$engineReceipt.byte_length
                    cas = $engineCas
                }
                retained_binary_count = 2
                executed_retained_pair = $true
                reproducible_build_claimed = $false
                result_reuse_authority = $false
            }
            worker = [ordered]@{
                receipt = $workerReceipt
                raw_report = $rawReceipt
                raw_report_cas = $rawCas
                stdout = $worker.stdout
                stdout_cas = $stdoutCas
                stderr = $worker.stderr
                stderr_cas = $stderrCas
                engine_log = $worker.engine_log
                engine_log_cas = $engineLogCas
            }
            evaluation = [ordered]@{
                receipt = $evaluation.receipt
                file = $evaluation.output
                cas = $evaluationCas
                log = $evaluation.run.log
                log_cas = $evaluationLogCas
            }
            synthetic_shape = [ordered]@{
                declared_world_count = 1
                declared_solver_step_count = 8
                declared_retained_sample_count = 8
                is_physical_observation = $false
            }
            actual_counts = [ordered]@{
                active_physics_object_count = 0
                world_attempt_count = 0
                world_build_count = 0
                solver_step_count = 0
                physical_world_count = 0
            }
            claims = [ordered]@{
                complete_zero_world_gate_passed = $true
                physical_timing_question_executed = $false
                native_numerical_telemetry_characterized = $false
                instrumented_profile_promoted = $false
                recovery_world_opened = $false
                prone_to_standing_world_opened = $false
                turning_claim_changed = $false
                cross_engine_equivalence_claimed = $false
                physical_acceptance_authority = $false
                release_authority = $false
            }
        }
        $receiptPath = Join-Path $runRoot "receipt.json"
        [IO.File]::WriteAllText(
            $receiptPath,
            ($receipt | ConvertTo-Json -Depth 100) + "`n",
            [Text.UTF8Encoding]::new($false)
        )
        $receiptFile = Get-R24D8FileReceipt $receiptPath
        $receiptCas = Publish-R24D8Artifact -Path $receiptPath
        Write-Output (
            "QSDK_R24D8_ACTIVE_STEP_SNAPSHOT_ZERO_WORLD_GATE " +
            ([ordered]@{
                ok = $true
                source_commit = $head
                receipt = $receiptFile
                receipt_cas = $receiptCas
                console_sha256 = [string]$consoleReceipt.raw_sha256
                engine_sha256 = [string]$engineReceipt.raw_sha256
                world_attempt_count = 0
                world_build_count = 0
                solver_step_count = 0
                physical_acceptance_authority = $false
                release_authority = $false
            } | ConvertTo-Json -Depth 30 -Compress)
        )
        return
    }

    Assert-R24D8Supervisor (
        -not [string]::IsNullOrWhiteSpace($ZeroWorldReceiptPath)
    ) "zero_world_receipt_path_required"
    $zeroPath = [IO.Path]::GetFullPath($ZeroWorldReceiptPath)
    $zeroWorldRoot = [IO.Path]::GetFullPath((Join-Path $preflightRoot "zero-world"))
    Assert-R24D8Supervisor (
        $zeroPath.StartsWith(
            $zeroWorldRoot + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        (Split-Path -Leaf $zeroPath) -ceq "receipt.json" -and
        (Split-Path -Leaf (Split-Path -Parent $zeroPath)).EndsWith(
            "-$($head.Substring(0, 8))-$($expectedPatchHash.Substring(0, 12))",
            [StringComparison]::Ordinal
        )
    ) "zero_world_receipt_location"
    $zeroReceiptFile = Get-R24D8FileReceipt $zeroPath
    $zeroReceipt = Get-Content -Raw -LiteralPath $zeroPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D8ZeroReceipt -Receipt $zeroReceipt -ExpectedHead $head
    $zeroReceiptCasDirectory = Join-Path $evidenceBase (
        "artifacts\sha256\" + ([string]$zeroReceiptFile.raw_sha256).Substring(7)
    )
    Assert-R24D8Supervisor (
        Test-SporeSporeStoredArtifact `
            -Directory $zeroReceiptCasDirectory `
            -ExpectedSha256 ([string]$zeroReceiptFile.raw_sha256).Substring(7) `
            -ExpectedByteLength ([long]$zeroReceiptFile.byte_length)
    ) "zero_world_receipt_cas"
    $console = [hashtable]$zeroReceipt.binary_pair.console
    $engine = [hashtable]$zeroReceipt.binary_pair.engine
    $consolePath = [IO.Path]::GetFullPath([string]$console.path)
    $enginePath = [IO.Path]::GetFullPath([string]$engine.path)
    $physicalRoot = Join-Path $preflightRoot "physical"
    $matching = @(Get-R24D8MatchingAttempts `
        -PhysicalRoot $physicalRoot `
        -SourceCommit $head `
        -ConsoleSha ([string]$console.raw_sha256) `
        -EngineSha ([string]$engine.raw_sha256))
    Assert-R24D8Supervisor ($matching.Count -eq 0) (
        "same_source_physical_attempt_already_consumed:$($matching -join '|')"
    )
    $identity = (
        "$head-$(([string]$console.raw_sha256).Substring(7, 12))-" +
        "$(([string]$engine.raw_sha256).Substring(7, 12))-$stamp"
    )
    $runRoot = Join-Path $physicalRoot $identity
    Assert-R24D8Supervisor (-not (Test-Path -LiteralPath $runRoot)) (
        "physical_run_root_exists"
    )
    [void][IO.Directory]::CreateDirectory($runRoot)
    $nonce = [Guid]::NewGuid().ToString("N")
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_r24d8_physical_attempt_v1"
        gate_id = "QSDK-R24D8"
        question_class = "development"
        status = "consumed_before_worker_launch"
        source_commit = $head
        execution_nonce = $nonce
        console_binary_sha256 = [string]$console.raw_sha256
        engine_binary_sha256 = [string]$engine.raw_sha256
        zero_world_receipt_sha256 = [string]$zeroReceiptFile.raw_sha256
        declared_world_attempt_count = 1
        declared_world_build_count = 1
        declared_solver_step_count = 8
        declared_retained_sample_count = 8
        same_source_rerun_allowed = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    $attemptPath = Join-Path $runRoot "attempt.json"
    [IO.File]::WriteAllText(
        $attemptPath,
        ($attempt | ConvertTo-Json -Depth 30) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
    $physicalAttemptCreated = $true
    $attemptFile = Get-R24D8FileReceipt $attemptPath
    $attemptCas = Publish-R24D8Artifact -Path $attemptPath

    $auditDefinitions = @(
        [ordered]@{
            name = "immutable_r24d7_closure_recheck"
            file = "pwsh"
            arguments = @(
                "-NoLogo", "-NoProfile", "-File",
                (Get-R24D8Path $predecessorCompatibilityAuditRelative),
                "-GodotRepositoryRoot", $godotRoot
            )
        },
        [ordered]@{
            name = "r24d8_freeze_recheck"
            file = "pwsh"
            arguments = @(
                "-NoLogo", "-NoProfile", "-File",
                (Get-R24D8Path $freezeAuditRelative),
                "-Python", $pythonPath,
                "-GodotSourceRoot", $godotRoot
            )
        }
    )
    $auditReceipts = [Collections.Generic.List[object]]::new()
    $auditIndex = 0
    foreach ($audit in $auditDefinitions) {
        $auditIndex += 1
        $logPath = Join-Path $runRoot (
            "{0:d2}-{1}.log" -f $auditIndex, [string]$audit.name
        )
        $auditRun = Invoke-R24D8Checked `
            -FileName (Resolve-R24D8Application ([string]$audit.file)) `
            -Arguments @($audit.arguments) `
            -WorkingDirectory $repoRoot `
            -Label ([string]$audit.name) `
            -LogPath $logPath
        $auditReceipts.Add([ordered]@{
            index = $auditIndex
            name = [string]$audit.name
            duration_s = [double]$auditRun.duration_s
            log = $auditRun.log
            cas = Publish-R24D8Artifact -Path $logPath -MediaType "text/plain"
        })
    }
    $sourceAfterAudit = Assert-R24D8RepositoryBoundary
    Assert-R24D8Supervisor ([string]$sourceAfterAudit.head -ceq $head) (
        "source_drift_before_physical_worker"
    )
    [void](Assert-R24D8GodotSourceBoundary)
    $projectRoot = Join-Path $runRoot "project"
    [void][IO.Directory]::CreateDirectory($projectRoot)
    New-R24D8Project -ProjectRoot $projectRoot
    $rawPath = Join-Path $runRoot "raw-report.json"
    $worker = Invoke-R24D8Worker `
        -ConsolePath $consolePath `
        -ProjectRoot $projectRoot `
        -RunRoot $runRoot `
        -WorkerMode "physical" `
        -Nonce $nonce `
        -Head $head `
        -ReportPath $rawPath
    $workerMarkerText = Get-R24D8Marker `
        -Lines $worker.stdout_lines `
        -Prefix $physicalWorkerPrefix `
        -Code "physical_worker"
    $workerReceipt = $workerMarkerText |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D8Supervisor (
        [bool]$workerReceipt.ok -and
        [int]$workerReceipt.world_attempt_count -eq 1 -and
        [int]$workerReceipt.world_build_count -eq 1 -and
        [int]$workerReceipt.solver_step_count -eq 8 -and
        [int]$workerReceipt.retained_sample_count -eq 8 -and
        [int]$workerReceipt.pre_sample_physics_frame_count -eq 1 -and
        [int]$workerReceipt.terminal_physics_server_deactivation_count -eq 1 -and
        -not [bool]$workerReceipt.physical_acceptance_authority -and
        -not [bool]$workerReceipt.release_authority
    ) "physical_worker_receipt"
    $rawFile = Get-R24D8FileReceipt $rawPath
    $rawCas = Publish-R24D8Artifact -Path $rawPath
    $evaluationPath = Join-Path $runRoot "evaluation.json"
    $evaluationLog = Join-Path $runRoot "03-evaluation.log"
    $evaluation = Invoke-R24D8Evaluation `
        -PythonPath $pythonPath `
        -InputPath $rawPath `
        -OutputPath $evaluationPath `
        -SourceCommit $head `
        -Nonce $nonce `
        -EvidenceKind "native_physical" `
        -LogPath $evaluationLog
    Assert-R24D8Supervisor (
        [bool]$evaluation.receipt.ok -and
        [string]$evaluation.receipt.result -ceq
            "finite_native_active_step_snapshot_timing_positive" -and
        -not [bool]$evaluation.receipt.native_numerical_telemetry_characterized -and
        -not [bool]$evaluation.receipt.instrumented_profile_promoted -and
        -not [bool]$evaluation.receipt.recovery_claimed -and
        -not [bool]$evaluation.receipt.prone_to_standing_claimed -and
        -not [bool]$evaluation.receipt.physical_acceptance_authority -and
        -not [bool]$evaluation.receipt.release_authority
    ) "physical_evaluation_receipt"
    $evaluationCas = Publish-R24D8Artifact -Path $evaluationPath
    $evaluationLogCas = Publish-R24D8Artifact `
        -Path $evaluationLog `
        -MediaType "text/plain"
    $stdoutCas = Publish-R24D8Artifact `
        -Path ([string]$worker.stdout.path) `
        -MediaType "text/plain"
    $stderrCas = Publish-R24D8Artifact `
        -Path ([string]$worker.stderr.path) `
        -MediaType "text/plain"
    $engineLogCas = Publish-R24D8Artifact `
        -Path ([string]$worker.engine_log.path) `
        -MediaType "text/plain"
    $postPhysicalConsole = Get-R24D8FileReceipt $consolePath
    $postPhysicalEngine = Get-R24D8FileReceipt $enginePath
    Assert-R24D8Supervisor (
        [string]$postPhysicalConsole.raw_sha256 -ceq
            [string]$console.raw_sha256 -and
        [string]$postPhysicalEngine.raw_sha256 -ceq
            [string]$engine.raw_sha256
    ) "physical_binary_pair_drift"
    $sourceAfterPhysical = Assert-R24D8RepositoryBoundary
    Assert-R24D8Supervisor ([string]$sourceAfterPhysical.head -ceq $head) (
        "source_drift_during_physical_runtime"
    )
    [void](Assert-R24D8GodotSourceBoundary)
    $physicalReceipt = [ordered]@{
        schema_version = (
            "sporespore_qsdk_r24d8_active_step_snapshot_physical_receipt_v1"
        )
        ok = $true
        gate_id = "QSDK-R24D8"
        question_class = "development"
        status = "finite_native_active_step_snapshot_timing_positive"
        source = $source
        godot_source = $godotSource
        attempt = $attemptFile
        attempt_cas = $attemptCas
        zero_world_receipt = $zeroReceiptFile
        zero_world_receipt_cas_verified = $true
        binary_pair = [ordered]@{
            console = $console
            engine = $engine
        }
        rechecks = @($auditReceipts)
        worker = [ordered]@{
            receipt = $workerReceipt
            raw_report = $rawFile
            raw_report_cas = $rawCas
            stdout = $worker.stdout
            stdout_cas = $stdoutCas
            stderr = $worker.stderr
            stderr_cas = $stderrCas
            engine_log = $worker.engine_log
            engine_log_cas = $engineLogCas
        }
        evaluation = [ordered]@{
            receipt = $evaluation.receipt
            file = $evaluation.output
            cas = $evaluationCas
            log = $evaluation.run.log
            log_cas = $evaluationLogCas
        }
        finite_counts = [ordered]@{
            world_attempt_count = 1
            world_build_count = 1
            solver_step_count = 8
            retained_sample_count = 8
            same_source_repeat_count = 0
        }
        claims = [ordered]@{
            physical_timing_question_executed = $true
            active_step_capture_observed = $true
            sleeping_stale_preservation_observed = $true
            native_numerical_telemetry_characterized = $false
            instrumented_profile_promoted = $false
            recovery_world_opened = $false
            prone_to_standing_world_opened = $false
            turning_claim_changed = $false
            cross_engine_equivalence_claimed = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
    }
    $physicalReceiptPath = Join-Path $runRoot "receipt.json"
    [IO.File]::WriteAllText(
        $physicalReceiptPath,
        ($physicalReceipt | ConvertTo-Json -Depth 100) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
    $physicalReceiptFile = Get-R24D8FileReceipt $physicalReceiptPath
    $physicalReceiptCas = Publish-R24D8Artifact -Path $physicalReceiptPath
    Write-Output (
        "QSDK_R24D8_ACTIVE_STEP_SNAPSHOT_PHYSICAL " +
        ([ordered]@{
            ok = $true
            result = "finite_native_active_step_snapshot_timing_positive"
            source_commit = $head
            receipt = $physicalReceiptFile
            receipt_cas = $physicalReceiptCas
            world_attempt_count = 1
            world_build_count = 1
            solver_step_count = 8
            retained_sample_count = 8
            native_numerical_telemetry_characterized = $false
            instrumented_profile_promoted = $false
            physical_acceptance_authority = $false
            release_authority = $false
        } | ConvertTo-Json -Depth 30 -Compress)
    )
} catch {
    if (-not [string]::IsNullOrWhiteSpace($runRoot) -and
        (Test-Path -LiteralPath $runRoot -PathType Container)) {
        $failurePath = Join-Path $runRoot "supervisor-failure.json"
        $failure = [ordered]@{
            schema_version = "sporespore_qsdk_r24d8_supervisor_failure_v1"
            gate_id = "QSDK-R24D8"
            mode = $Mode
            observed_at_utc = [DateTimeOffset]::UtcNow.ToString("o")
            error = [string]$_
            physical_attempt_created = $physicalAttemptCreated
            same_source_rerun_allowed = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
        [IO.File]::WriteAllText(
            $failurePath,
            ($failure | ConvertTo-Json -Depth 30) + "`n",
            [Text.UTF8Encoding]::new($false)
        )
        try { [void](Publish-R24D8Artifact -Path $failurePath) } catch {}
    }
    throw
} finally {
    if ($null -ne $operationLock) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $operationLock
    }
}

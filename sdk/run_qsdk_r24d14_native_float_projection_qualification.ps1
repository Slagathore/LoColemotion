#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet("Development", "Qualification")]
    [string]$Mode = "Development",
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
$expectedRepoRemote = "https://github.com/Slagathore/sporespore.git"
$expectedGodotRoot = "C:\Users\Cole\CodeStuff\dependencies\godot-sporespore-4.7"
$expectedGodotRemote = "https://github.com/godotengine/godot.git"
$expectedEvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$manifestRelative = (
    "sdk/recovery/r24d14_godot_native_float_projection_validation_manifest.json"
)
$sourceAuditRelative = (
    "tests/test_qsdk_r24d14_godot_native_float_projection_source.py"
)
$predecessorClosureAuditRelative = (
    "tests/test_qsdk_r24d13_braking_mechanism_activation_physical_attempt_closure.py"
)
$evaluatorRelative = (
    "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_evaluator.py"
)
$workerRelative = (
    "tests/test_sdk_qsdk_r24d14_godot_native_float_projection_worker.gd"
)
$projectSources = @(
    "scripts/lab/rigs/r24d9_godot_jolt_one_hinge_numerical_telemetry_rig.gd",
    "scripts/lab/rigs/r24d13_godot_jolt_braking_mechanism_activation_rig.gd",
    "tests/test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_worker.gd",
    "tests/test_sdk_qsdk_r24d13_godot_jolt_braking_mechanism_activation_worker.gd",
    $workerRelative
)
$readyPrefix = "QSDK_R24D14_GODOT_SUPERVISOR_TERMINATION_READY "
$workerPrefix = "QSDK_R24D14_NATIVE_PROJECTION "
$expectedNativeImpulse = [double][BitConverter]::Int32BitsToSingle(0x3b03126f)
$expectedNativeTimestep = [double][BitConverter]::Int32BitsToSingle(0x3c088889)

. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")
. (Join-Path $sdkRoot "godot_receipt_terminated_process.ps1")
. (Join-Path $sdkRoot "content_addressed_artifact_store.ps1")

function Assert-R24D14 {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) {
        throw "QSDK-R24D14 native projection qualification: $Code"
    }
}

function Get-R24D14Path {
    param([Parameter(Mandatory)][string]$Relative)
    return [IO.Path]::GetFullPath((Join-Path $repoRoot $Relative))
}

function Get-R24D14Git {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    $output = @(& git -C $Root @Arguments 2>&1)
    Assert-R24D14 ($LASTEXITCODE -eq 0) (
        "git_$($Arguments -join '_'):$($output -join '|')"
    )
    return ($output -join "`n").Trim()
}

function Get-R24D14FileReceipt {
    param([Parameter(Mandatory)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    Assert-R24D14 (Test-Path -LiteralPath $full -PathType Leaf) (
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

function Write-R24D14Json {
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

function Publish-R24D14Artifact {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$MediaType = "application/json"
    )
    return Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot `
        -ArtifactPath $Path `
        -MediaType $MediaType
}

function Resolve-R24D14Application {
    param([Parameter(Mandatory)][string]$Command)
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R24D14 (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application_missing:$resolved"
        )
        return $resolved
    }
    $candidate = Get-Command -Name $Command -CommandType Application |
        Select-Object -First 1
    Assert-R24D14 ($null -ne $candidate) "application_missing:$Command"
    return [IO.Path]::GetFullPath([string]$candidate.Source)
}

function Invoke-R24D14Checked {
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
    [IO.File]::WriteAllText(
        $LogPath,
        (@(
            "label=$Label",
            "started_utc=$($started.ToString('o'))",
            "finished_utc=$($finished.ToString('o'))",
            "exit_code=$exitCode",
            "command=$FileName $($Arguments -join ' ')",
            "--- output ---",
            $lines
        ) -join "`n") + "`n",
        [Text.UTF8Encoding]::new($false)
    )
    Assert-R24D14 ($exitCode -eq 0) "$Label`:$($lines -join '|')"
    return [ordered]@{
        output = $lines
        duration_s = [Math]::Round(($finished - $started).TotalSeconds, 6)
        log = Get-R24D14FileReceipt $LogPath
    }
}

function Get-R24D14RepositoryBoundary {
    param([switch]$RequireCleanPushed)
    $root = Get-R24D14Git -Root $repoRoot -Arguments @(
        "rev-parse", "--show-toplevel"
    )
    $remote = Get-R24D14Git -Root $repoRoot -Arguments @(
        "remote", "get-url", "origin"
    )
    $branch = Get-R24D14Git -Root $repoRoot -Arguments @(
        "branch", "--show-current"
    )
    $head = Get-R24D14Git -Root $repoRoot -Arguments @("rev-parse", "HEAD")
    $upstream = Get-R24D14Git -Root $repoRoot -Arguments @(
        "rev-parse", "@{upstream}"
    )
    $cached = Get-R24D14Git -Root $repoRoot -Arguments @(
        "rev-parse", "refs/remotes/origin/main"
    )
    $liveText = Get-R24D14Git -Root $repoRoot -Arguments @(
        "ls-remote", "--heads", "origin", "refs/heads/main"
    )
    $live = $liveText.Split("`t")[0]
    $status = Get-R24D14Git -Root $repoRoot -Arguments @(
        "status", "--short"
    )
    $worktreeText = Get-R24D14Git -Root $repoRoot -Arguments @(
        "worktree", "list", "--porcelain"
    )
    $worktrees = @($worktreeText -split "`r?`n" | Where-Object {
        $_.StartsWith("worktree ", [StringComparison]::Ordinal)
    })
    Assert-R24D14 (
        [IO.Path]::GetFullPath($root) -ceq $expectedRepoRoot -and
        $repoRoot -ceq $expectedRepoRoot
    ) "repository_root"
    Assert-R24D14 ($remote -ceq $expectedRepoRemote) "repository_remote"
    Assert-R24D14 ($branch -ceq "main") "branch"
    Assert-R24D14 ($worktrees.Count -eq 1) "worktree_count"
    if ($RequireCleanPushed) {
        Assert-R24D14 ([string]::IsNullOrEmpty($status)) "dirty_worktree"
        Assert-R24D14 (
            $head -ceq $upstream -and $head -ceq $cached -and $head -ceq $live
        ) "local_upstream_cached_live_inequality"
    }
    return [ordered]@{
        root = $root.Replace("\", "/")
        remote = $remote
        branch = $branch
        head = $head
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

function Assert-R24D14Manifest {
    param(
        [Parameter(Mandatory)][string]$Head,
        [switch]$RequireCommitted
    )
    $path = Get-R24D14Path $manifestRelative
    $manifest = Get-Content -Raw -LiteralPath $path |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D14 (
        [string]$manifest.schema_version -ceq
            "sporespore_qsdk_r24d14_godot_native_float_projection_validation_manifest_v1" -and
        [string]$manifest.gate_id -ceq "QSDK-R24D14" -and
        [string]$manifest.question_class -ceq "development" -and
        -not [bool]$manifest.includes_self
    ) "manifest_header"
    $seen = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($binding in @($manifest.source_bindings)) {
        $relative = [string]$binding.path
        Assert-R24D14 ($seen.Add($relative)) "manifest_duplicate:$relative"
        $full = Get-R24D14Path $relative
        Assert-R24D14 ($full.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar)) (
            "manifest_path_escape:$relative"
        )
        $receipt = Get-R24D14FileReceipt $full
        $blob = Get-R24D14Git -Root $repoRoot -Arguments @(
            "hash-object", "--", $relative
        )
        Assert-R24D14 (
            [string]$binding.raw_sha256 -ceq [string]$receipt.raw_sha256 -and
            [long]$binding.byte_length -eq [long]$receipt.byte_length -and
            [string]$binding.git_blob_oid -ceq $blob
        ) "manifest_binding:$relative"
        if ($RequireCommitted) {
            $committedBlob = Get-R24D14Git -Root $repoRoot -Arguments @(
                "rev-parse", "$Head`:$relative"
            )
            Assert-R24D14 ($committedBlob -ceq $blob) (
                "manifest_uncommitted_binding:$relative"
            )
        }
    }
    Assert-R24D14 ($seen.Count -eq [int]$manifest.source_binding_count) (
        "manifest_binding_count"
    )
    return [ordered]@{
        value = $manifest
        file = Get-R24D14FileReceipt $path
    }
}

function Assert-R24D14Runtime {
    param([Parameter(Mandatory)][hashtable]$Manifest)
    Assert-R24D14 ($godotRoot -ceq $expectedGodotRoot) "godot_root_argument"
    $root = Get-R24D14Git -Root $godotRoot -Arguments @(
        "rev-parse", "--show-toplevel"
    )
    $remote = Get-R24D14Git -Root $godotRoot -Arguments @(
        "remote", "get-url", "origin"
    )
    $head = Get-R24D14Git -Root $godotRoot -Arguments @("rev-parse", "HEAD")
    Assert-R24D14 ([IO.Path]::GetFullPath($root) -ceq $expectedGodotRoot) (
        "godot_source_root"
    )
    Assert-R24D14 ($remote -ceq $expectedGodotRemote) "godot_remote"
    Assert-R24D14 ($head -ceq [string]$Manifest.runtime.godot_source_commit) (
        "godot_commit"
    )
    $statusOutput = @(& git -C $godotRoot status --short 2>&1)
    Assert-R24D14 ($LASTEXITCODE -eq 0) "godot_status"
    $statusPaths = @($statusOutput | ForEach-Object {
        ([string]$_).Substring(3).Replace("\", "/")
    })
    $expectedPatched = @($Manifest.runtime.expected_patched_paths)
    Assert-R24D14 (
        (($statusPaths | Sort-Object) -join "|") -ceq
        (($expectedPatched | Sort-Object) -join "|")
    ) "godot_patched_path_population"
    $patchPath = Get-R24D14Path ([string]$Manifest.runtime.patch_path)
    $diff = ((@(& git -C $godotRoot diff --no-ext-diff 2>&1) -join "`n") + "`n").
        Replace("`r`n", "`n")
    Assert-R24D14 ($LASTEXITCODE -eq 0) "godot_diff"
    $patchText = [IO.File]::ReadAllText($patchPath).
        Replace("`r`n", "`n").TrimEnd("`n") + "`n"
    Assert-R24D14 ($diff -ceq $patchText) "godot_patch_identity"

    foreach ($binding in @($Manifest.native_source_bindings)) {
        $full = [IO.Path]::GetFullPath((Join-Path $godotRoot ([string]$binding.path)))
        Assert-R24D14 ($full.StartsWith($godotRoot + [IO.Path]::DirectorySeparatorChar)) (
            "native_source_path_escape:$($binding.path)"
        )
        $receipt = Get-R24D14FileReceipt $full
        Assert-R24D14 (
            [string]$binding.raw_sha256 -ceq [string]$receipt.raw_sha256 -and
            [long]$binding.byte_length -eq [long]$receipt.byte_length
        ) "native_source_binding:$($binding.path)"
    }
    Assert-R24D14 (
        @($Manifest.native_source_bindings).Count -eq
            [int]$Manifest.native_source_binding_count
    ) "native_source_binding_count"

    $consolePath = Join-Path $godotRoot ([string]$Manifest.runtime.console_path)
    $enginePath = Join-Path $godotRoot ([string]$Manifest.runtime.engine_path)
    $console = Get-R24D14FileReceipt $consolePath
    $engine = Get-R24D14FileReceipt $enginePath
    Assert-R24D14 (
        [string]$console.raw_sha256 -ceq [string]$Manifest.runtime.console_raw_sha256 -and
        [long]$console.byte_length -eq [long]$Manifest.runtime.console_byte_length -and
        [string]$engine.raw_sha256 -ceq [string]$Manifest.runtime.engine_raw_sha256 -and
        [long]$engine.byte_length -eq [long]$Manifest.runtime.engine_byte_length
    ) "runtime_binary_pair"
    return [ordered]@{
        godot_source_root = $root.Replace("\", "/")
        godot_source_remote = $remote
        godot_source_commit = $head
        patch = Get-R24D14FileReceipt $patchPath
        native_source_binding_count = @($Manifest.native_source_bindings).Count
        console = $console
        engine = $engine
        engine_build_reused = $true
        campaign_result_reused = $false
        physical_evidence_reused = $false
    }
}

function New-R24D14Project {
    param([Parameter(Mandatory)][string]$ProjectRoot)
    foreach ($relative in $projectSources) {
        $destination = Join-Path $ProjectRoot $relative.Replace("/", "\")
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
        Copy-Item -LiteralPath (Get-R24D14Path $relative) -Destination $destination
    }
    $projectText = @'
; QSDK-R24D14 zero-step native float-projection route.
config_version=5

[application]
config/name="qsdk-r24d14-native-float-projection"
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

function Invoke-R24D14Worker {
    param(
        [Parameter(Mandatory)][string]$ConsolePath,
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][string]$RunRoot,
        [Parameter(Mandatory)][string]$Nonce,
        [Parameter(Mandatory)][string]$Head,
        [Parameter(Mandatory)][string]$ReportPath
    )
    $engineLogPath = Join-Path $RunRoot "godot-native-projection-engine.log"
    $arguments = @(
        "--headless",
        "--path", $ProjectRoot,
        "--log-file", $engineLogPath,
        "--script", ("res://" + $workerRelative),
        "--",
        "--mode=native_projection_preflight",
        "--nonce=$Nonce",
        "--source_commit=$Head",
        "--report_path=$ReportPath"
    )
    $environment = @{
        SPORESPORE_R24D14_SUPERVISED_TERMINATION = "1"
        SPORESPORE_R24D14_TERMINATION_NONCE = $Nonce
        SPORESPORE_R24D14_EXECUTION_NONCE = $Nonce
        SPORESPORE_R24D14_SOURCE_COMMIT = $Head
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
            "SPORESPORE_R24D14_EXECUTION_NONCE",
            "SPORESPORE_R24D14_SOURCE_COMMIT"
        ) `
        -TimeoutSeconds 120
    $stdoutPath = Join-Path $RunRoot "godot-native-projection-stdout.log"
    $stderrPath = Join-Path $RunRoot "godot-native-projection-stderr.log"
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
    Assert-R24D14 (
        [bool]$result.termination_protocol_valid -and
        [bool]$result.supervisor_terminated -and
        [int]$result.exit_code -eq 0
    ) (
        "worker_failed:semantic=$($result.exit_code):" +
        "host=$($result.host_exit_code):protocol=" +
        "$($result.termination_protocol_failure_code)"
    )
    $stdoutLines = @(([string]$result.stdout) -split "`r?`n")
    $errorLines = @(
        $stdoutLines + @(([string]$result.stderr) -split "`r?`n") |
            Where-Object { $_ -match "(^|\s)(SCRIPT ERROR|ERROR):" }
    )
    Assert-R24D14 ($errorLines.Count -eq 0) (
        "worker_error_lines:$($errorLines -join '|')"
    )
    Assert-R24D14 (Test-Path -LiteralPath $ReportPath -PathType Leaf) (
        "worker_report_missing"
    )
    $markers = @($stdoutLines | Where-Object {
        ([string]$_).StartsWith($workerPrefix, [StringComparison]::Ordinal)
    })
    Assert-R24D14 ($markers.Count -eq 1) "worker_marker_count:$($markers.Count)"
    $receipt = ([string]$markers[0]).Substring($workerPrefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
    return [ordered]@{
        receipt = $receipt
        stdout = Get-R24D14FileReceipt $stdoutPath
        stderr = Get-R24D14FileReceipt $stderrPath
        engine_log = Get-R24D14FileReceipt $engineLogPath
    }
}

Assert-R24D14 ($repoRoot -ceq $expectedRepoRoot) "repository_root_initial"
Assert-R24D14 ($evidenceBase -ceq $expectedEvidenceRoot) "evidence_root"
$pythonPath = Resolve-R24D14Application $Python
$requireQualification = $Mode -ceq "Qualification"
$source = Get-R24D14RepositoryBoundary -RequireCleanPushed:$requireQualification
$head = [string]$source.head
$statusBefore = [string]$source.status_porcelain
$manifestReceipt = Assert-R24D14Manifest `
    -Head $head `
    -RequireCommitted:$requireQualification
$runtime = Assert-R24D14Runtime -Manifest $manifestReceipt.value

if ($requireQualification) {
    $qualificationRoot = Join-Path $evidenceBase (
        "qsdk-r24d14-native-float-projection\qualification"
    )
    if (Test-Path -LiteralPath $qualificationRoot -PathType Container) {
        $prior = @(Get-ChildItem -LiteralPath $qualificationRoot `
            -Recurse -File -Filter "receipt.json" | Where-Object {
                try {
                    $value = Get-Content -Raw -LiteralPath $_.FullName |
                        ConvertFrom-Json -Depth 100
                    [string]$value.source.head -ceq $head -and
                    [string]$value.validation_manifest.raw_sha256 -ceq
                        [string]$manifestReceipt.file.raw_sha256
                } catch { $false }
            })
        Assert-R24D14 ($prior.Count -eq 0) (
            "same_source_official_qualification_already_consumed:" +
            (($prior | ForEach-Object { $_.FullName }) -join "|")
        )
    }
}

$lockReceipt = Enter-SporeSporeLocomotionOperationLock -Role "conformance"
Assert-R24D14 ([bool]$lockReceipt.acquired) "operation_lock_unavailable"
$stamp = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
$nonce = [Guid]::NewGuid().ToString("N")
$modeFolder = $Mode.ToLowerInvariant()
$runRoot = Join-Path $evidenceBase (
    "qsdk-r24d14-native-float-projection\$modeFolder\" +
    "$stamp-$($head.Substring(0, 8))-$($nonce.Substring(0, 12))"
)
Assert-R24D14 (-not (Test-Path -LiteralPath $runRoot)) "run_root_exists"
[void][IO.Directory]::CreateDirectory($runRoot)
$attemptPath = Join-Path $runRoot "attempt.json"
$attempt = [ordered]@{
    schema_version = "sporespore_qsdk_r24d14_native_float_projection_attempt_v1"
    gate_id = "QSDK-R24D14"
    question_class = "development"
    mode = $Mode
    status = "started_zero_step_native_projection"
    source_commit = $head
    source_clean_pushed = [bool]$source.clean_pushed
    validation_manifest_sha256 = [string]$manifestReceipt.file.raw_sha256
    execution_nonce = $nonce
    created_utc = [DateTimeOffset]::UtcNow.ToString("o")
    native_joint_allocation_count = 0
    world_attempt_count = 0
    world_build_count = 0
    solver_step_count = 0
    physical_acceptance_authority = $false
    release_authority = $false
}
Write-R24D14Json -Path $attemptPath -Value $attempt

try {
    $stages = [Collections.Generic.List[object]]::new()
    $stageSpecs = @(
        [ordered]@{
            name = "r24d14_native_projection_source_audit"
            file = $pythonPath
            arguments = @(
                (Get-R24D14Path $sourceAuditRelative)
            ) + $(if ($requireQualification) { @("--require-committed") } else { @() })
        },
        [ordered]@{
            name = "immutable_r24d13_physical_closure_audit"
            file = $pythonPath
            arguments = @((Get-R24D14Path $predecessorClosureAuditRelative))
        },
        [ordered]@{
            name = "r24d14_evaluator_self_test_and_adjacent_value_controls"
            file = $pythonPath
            arguments = @((Get-R24D14Path $evaluatorRelative), "--self-test")
        }
    )
    $stageIndex = 0
    foreach ($stage in $stageSpecs) {
        $stageIndex += 1
        $logPath = Join-Path $runRoot (
            "{0:d2}-{1}.log" -f $stageIndex, [string]$stage.name
        )
        $stageRun = Invoke-R24D14Checked `
            -FileName ([string]$stage.file) `
            -Arguments @($stage.arguments) `
            -WorkingDirectory $repoRoot `
            -Label ([string]$stage.name) `
            -LogPath $logPath
        $stages.Add([ordered]@{
            index = $stageIndex
            name = [string]$stage.name
            duration_s = [double]$stageRun.duration_s
            log = $stageRun.log
            cas = Publish-R24D14Artifact -Path $logPath -MediaType "text/plain"
        })
    }

    $projectRoot = Join-Path $runRoot "project"
    [void][IO.Directory]::CreateDirectory($projectRoot)
    New-R24D14Project -ProjectRoot $projectRoot
    $rawPath = Join-Path $runRoot "synthetic-raw-report.json"
    $worker = Invoke-R24D14Worker `
        -ConsolePath ([string]$runtime.console.path) `
        -ProjectRoot $projectRoot `
        -RunRoot $runRoot `
        -Nonce $nonce `
        -Head $head `
        -ReportPath $rawPath
    $workerReceipt = $worker.receipt
    Assert-R24D14 (
        [bool]$workerReceipt.ok -and
        [string]$workerReceipt.source_commit -ceq $head -and
        [string]$workerReceipt.execution_nonce -ceq $nonce -and
        [bool]$workerReceipt.native_joint_rid_valid -and
        [int]$workerReceipt.native_joint_allocation_count -eq 1 -and
        [int]$workerReceipt.native_joint_release_call_count -eq 1 -and
        [double]$workerReceipt.native_impulse_readback_nms -eq
            $expectedNativeImpulse -and
        [double]$workerReceipt.native_timestep_carrier_readback_s -eq
            $expectedNativeTimestep -and
        [double]$workerReceipt.native_timestep_float32_projection_s -eq
            $expectedNativeTimestep -and
        [bool]$workerReceipt.adjacent_negative_controls_pass -and
        [bool]$workerReceipt.full_precision_text_matches -and
        -not [bool]$workerReceipt.godot_json_parser_is_production_evaluator -and
        [string]$workerReceipt.production_evaluator_parser -ceq "python_json" -and
        [double]$workerReceipt.active_physics_object_count_before -eq 0.0 -and
        [double]$workerReceipt.active_physics_object_count_after -eq 0.0 -and
        [int]$workerReceipt.world_attempt_count -eq 0 -and
        [int]$workerReceipt.world_build_count -eq 0 -and
        [int]$workerReceipt.solver_step_count -eq 0 -and
        -not [bool]$workerReceipt.physical_acceptance_authority -and
        -not [bool]$workerReceipt.release_authority
    ) "worker_receipt"

    $stageIndex += 1
    $workerLog = Join-Path $runRoot (
        "{0:d2}-native_float_projection_worker.log" -f $stageIndex
    )
    [IO.File]::WriteAllText(
        $workerLog,
        (Get-Content -Raw -LiteralPath ([string]$worker.stdout.path)),
        [Text.UTF8Encoding]::new($false)
    )
    $stages.Add([ordered]@{
        index = $stageIndex
        name = "custom_runtime_native_float_projection_worker"
        duration_s = 0.0
        log = Get-R24D14FileReceipt $workerLog
        cas = Publish-R24D14Artifact -Path $workerLog -MediaType "text/plain"
    })

    $stageIndex += 1
    $evaluationPath = Join-Path $runRoot "synthetic-evaluation.json"
    $evaluationLog = Join-Path $runRoot (
        "{0:d2}-independent_synthetic_evaluation.log" -f $stageIndex
    )
    $evaluationRun = Invoke-R24D14Checked `
        -FileName $pythonPath `
        -Arguments @(
            (Get-R24D14Path $evaluatorRelative),
            "--input", $rawPath,
            "--output", $evaluationPath,
            "--expected-source-commit", $head,
            "--expected-nonce", $nonce,
            "--expected-evidence-kind", "synthetic_zero_world"
        ) `
        -WorkingDirectory $repoRoot `
        -Label "R24D14 independent synthetic evaluation" `
        -LogPath $evaluationLog
    $evaluation = Get-Content -Raw -LiteralPath $evaluationPath |
        ConvertFrom-Json -Depth 100
    Assert-R24D14 (
        [bool]$evaluation.ok -and
        [bool]$evaluation.execution_valid -and
        [string]$evaluation.gate_id -ceq "QSDK-R24D14" -and
        [string]$evaluation.result -ceq
            "synthetic_shape_conforms_zero_world_only" -and
        [int]$evaluation.summary.cell_count -eq 4 -and
        [int]$evaluation.summary.retained_sample_count -eq 4 -and
        -not [bool]$evaluation.summary.native_braking_mechanism_activation_observed -and
        -not [bool]$evaluation.physical_acceptance_authority -and
        -not [bool]$evaluation.release_authority
    ) "synthetic_evaluation"
    $stages.Add([ordered]@{
        index = $stageIndex
        name = "independent_native_float_projection_evaluation"
        duration_s = [double]$evaluationRun.duration_s
        log = $evaluationRun.log
        cas = Publish-R24D14Artifact -Path $evaluationLog -MediaType "text/plain"
    })

    $sourceAfter = Get-R24D14RepositoryBoundary `
        -RequireCleanPushed:$requireQualification
    Assert-R24D14 (
        [string]$sourceAfter.head -ceq $head -and
        [string]$sourceAfter.status_porcelain -ceq $statusBefore
    ) "repository_drift_during_qualification"

    $attempt.status = "complete_zero_step_native_projection_passed"
    $attempt.native_joint_allocation_count = 1
    $attempt.completed_utc = [DateTimeOffset]::UtcNow.ToString("o")
    Write-R24D14Json -Path $attemptPath -Value $attempt
    $rawReceipt = Get-R24D14FileReceipt $rawPath
    $evaluationReceipt = Get-R24D14FileReceipt $evaluationPath
    $receipt = [ordered]@{
        schema_version = "sporespore_qsdk_r24d14_native_float_projection_qualification_receipt_v1"
        ok = $true
        gate_id = "QSDK-R24D14"
        question_class = "development"
        mode = $Mode
        status = "complete_zero_step_native_property_and_telemetry_projection_passed"
        source = $source
        validation_manifest = $manifestReceipt.file
        runtime = $runtime
        operation_lock = Get-SporeSporeLocomotionOperationLockPublicReceipt `
            -Receipt $lockReceipt
        stages = @($stages)
        attempt = Get-R24D14FileReceipt $attemptPath
        worker = [ordered]@{
            receipt = $workerReceipt
            raw_report = $rawReceipt
            raw_report_cas = Publish-R24D14Artifact -Path $rawPath
            stdout = $worker.stdout
            stdout_cas = Publish-R24D14Artifact `
                -Path ([string]$worker.stdout.path) -MediaType "text/plain"
            stderr = $worker.stderr
            stderr_cas = Publish-R24D14Artifact `
                -Path ([string]$worker.stderr.path) -MediaType "text/plain"
            engine_log = $worker.engine_log
            engine_log_cas = Publish-R24D14Artifact `
                -Path ([string]$worker.engine_log.path) -MediaType "text/plain"
        }
        evaluation = [ordered]@{
            file = $evaluationReceipt
            cas = Publish-R24D14Artifact -Path $evaluationPath
            result = [string]$evaluation.result
        }
        exact_projection = [ordered]@{
            impulse_binary32_hex = "3b03126f"
            impulse_binary64_hex = "3f60624de0000000"
            impulse_value = $expectedNativeImpulse
            timestep_binary32_hex = "3c088889"
            timestep_binary64_hex = "3f81111120000000"
            timestep_value = $expectedNativeTimestep
            adjacent_r24d13_values_rejected = $true
            production_evaluator_full_precision_json_round_trip_passed = $true
            production_evaluator_parser = "python_json"
            godot_json_parser_is_production_evaluator = $false
            godot_json_parser_diagnostic_only = [ordered]@{
                impulse_value = [double]$workerReceipt.godot_reparsed_impulse_nms
                timestep_value = [double]$workerReceipt.godot_reparsed_timestep_s
                matches_native = [bool]$workerReceipt.godot_json_round_trip_matches_native
            }
        }
        actual_counts = [ordered]@{
            native_joint_allocation_count = 1
            native_joint_release_call_count = 1
            active_physics_object_count_before = 0
            active_physics_object_count_after = 0
            body_count = 0
            space_count = 0
            viewport_count = 0
            world_attempt_count = 0
            world_build_count = 0
            solver_step_count = 0
        }
        claims = [ordered]@{
            native_property_readback_projection_qualified = $true
            telemetry_float32_variant_projection_qualified = $true
            physical_supervisor_implemented = $false
            physical_characterization_executed = $false
            native_braking_mechanism_activation_observed = $false
            recovery_world_opened = $false
            prone_to_standing_world_opened = $false
            q_sdk_r24_satisfied = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
        official_qualification = $requireQualification
        same_source_official_qualification_rerun_allowed = $false
    }
    $receiptPath = Join-Path $runRoot "receipt.json"
    Write-R24D14Json -Path $receiptPath -Value $receipt
    $receiptFile = Get-R24D14FileReceipt $receiptPath
    $receiptCas = Publish-R24D14Artifact -Path $receiptPath
    Write-Output (
        "QSDK_R24D14_NATIVE_PROJECTION_QUALIFICATION_PASS " +
        ([ordered]@{
            ok = $true
            mode = $Mode
            source_commit = $head
            run_root = $runRoot.Replace("\", "/")
            receipt_path = [string]$receiptFile.path
            receipt_raw_sha256 = [string]$receiptFile.raw_sha256
            receipt_cas_payload_path = [string]$receiptCas.payload_path
            stage_count = $stages.Count
            native_joint_allocation_count = 1
            world_attempt_count = 0
            world_build_count = 0
            solver_step_count = 0
            physical_characterization_executed = $false
            release_authority = $false
        } | ConvertTo-Json -Compress)
    )
} catch {
    $attempt.status = "invalid_or_incomplete_zero_step_qualification"
    $attempt.failure = [string]$_
    $attempt.completed_utc = [DateTimeOffset]::UtcNow.ToString("o")
    Write-R24D14Json -Path $attemptPath -Value $attempt
    throw
} finally {
    Exit-SporeSporeLocomotionOperationLock -Receipt $lockReceipt
}

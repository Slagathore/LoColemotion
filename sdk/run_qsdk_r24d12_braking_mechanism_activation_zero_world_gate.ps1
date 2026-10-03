#requires -Version 7.0

[CmdletBinding()]
param(
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
$expectedGodotCommit = "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"
$expectedPatchHash = "9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c"
$expectedBodySourceHash = "36842eb8765e1a4abe9eb2fbb20d85ab14b653c7333bd043beb2c6cab5392408"
$expectedConsoleHash = "ff655a567d31f51628d5b21742a0618e53f9fbf8a94937dd07d9882a0739872f"
$expectedEngineHash = "2d68ed7ae53704ffb532cd5633241c74d599d69e3bf1968de0ef261553030ffb"
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
$declarationRelative = (
    "sdk/recovery/" +
    "r24d12_godot_jolt_braking_mechanism_activation_preregistration_v1.json"
)
$manifestRelative = (
    "sdk/recovery/" +
    "r24d12_godot_jolt_braking_mechanism_activation_validation_manifest.json"
)
$evaluatorRelative = (
    "sdk/recovery/" +
    "r24d12_godot_jolt_braking_mechanism_activation_evaluator.py"
)
$freezeAuditRelative = (
    "tests/test_qsdk_r24d12_godot_jolt_braking_mechanism_activation_freeze.py"
)
$baseRigRelative = (
    "scripts/lab/rigs/" +
    "r24d9_godot_jolt_one_hinge_numerical_telemetry_rig.gd"
)
$rigRelative = (
    "scripts/lab/rigs/" +
    "r24d12_godot_jolt_braking_mechanism_activation_rig.gd"
)
$baseWorkerRelative = (
    "tests/test_sdk_qsdk_r24d9_godot_jolt_one_hinge_" +
    "numerical_telemetry_worker.gd"
)
$workerRelative = (
    "tests/test_sdk_qsdk_r24d12_godot_jolt_" +
    "braking_mechanism_activation_worker.gd"
)
$patchRelative = (
    "sdk/adapters/godot/engine_patches/" +
    "godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch"
)
$coldBaselineRelative = (
    "sdk/recovery/" +
    "r24d10_godot_jolt_exact_step_numerical_telemetry_" +
    "zero_world_positive_closure_v1.json"
)
$readyPrefix = "QSDK_R24D12_GODOT_SUPERVISOR_TERMINATION_READY "
$workerPrefix = "QSDK_R24D12_WORKER_ZERO_WORLD "

. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")
. (Join-Path $sdkRoot "godot_receipt_terminated_process.ps1")
. (Join-Path $sdkRoot "content_addressed_artifact_store.ps1")

function Assert-R24D12 {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) {
        throw "QSDK-R24D12 zero-world supervisor: $Code"
    }
}

function Get-R24D12Path {
    param([Parameter(Mandatory)][string]$Relative)
    return [IO.Path]::GetFullPath((Join-Path $repoRoot $Relative))
}

function Get-R24D12Git {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    $output = @(& git -C $Root @Arguments 2>&1)
    Assert-R24D12 ($LASTEXITCODE -eq 0) (
        "git_$($Arguments -join '_'):$($output -join '|')"
    )
    return ($output -join "`n").Trim()
}

function Get-R24D12FileReceipt {
    param([Parameter(Mandatory)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    Assert-R24D12 (Test-Path -LiteralPath $full -PathType Leaf) (
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

function Write-R24D12Json {
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

function Publish-R24D12Artifact {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$MediaType = "application/json"
    )
    return Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot `
        -ArtifactPath $Path `
        -MediaType $MediaType
}

function Resolve-R24D12Application {
    param([Parameter(Mandatory)][string]$Command)
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R24D12 (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application_missing:$resolved"
        )
        return $resolved
    }
    $candidate = Get-Command -Name $Command -CommandType Application |
        Select-Object -First 1
    Assert-R24D12 ($null -ne $candidate) "application_missing:$Command"
    return [IO.Path]::GetFullPath([string]$candidate.Source)
}

function Invoke-R24D12Checked {
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
    Assert-R24D12 ($exitCode -eq 0) "$Label`:$($lines -join '|')"
    return [ordered]@{
        output = $lines
        duration_s = [Math]::Round(($finished - $started).TotalSeconds, 6)
        log = Get-R24D12FileReceipt $LogPath
    }
}

function Assert-R24D12RepositoryBoundary {
    $root = Get-R24D12Git -Root $repoRoot -Arguments @(
        "rev-parse", "--show-toplevel"
    )
    $remote = Get-R24D12Git -Root $repoRoot -Arguments @(
        "remote", "get-url", "origin"
    )
    $branch = Get-R24D12Git -Root $repoRoot -Arguments @(
        "branch", "--show-current"
    )
    $head = Get-R24D12Git -Root $repoRoot -Arguments @("rev-parse", "HEAD")
    $upstream = Get-R24D12Git -Root $repoRoot -Arguments @(
        "rev-parse", "@{upstream}"
    )
    $cached = Get-R24D12Git -Root $repoRoot -Arguments @(
        "rev-parse", "refs/remotes/origin/main"
    )
    $liveText = Get-R24D12Git -Root $repoRoot -Arguments @(
        "ls-remote", "--heads", "origin", "refs/heads/main"
    )
    $live = $liveText.Split("`t")[0]
    $status = Get-R24D12Git -Root $repoRoot -Arguments @(
        "status", "--short"
    )
    $worktreeText = Get-R24D12Git -Root $repoRoot -Arguments @(
        "worktree", "list", "--porcelain"
    )
    $worktrees = @($worktreeText -split "`r?`n" | Where-Object {
        $_.StartsWith("worktree ", [StringComparison]::Ordinal)
    })
    Assert-R24D12 (
        [IO.Path]::GetFullPath($root) -ceq $expectedRepoRoot -and
        $repoRoot -ceq $expectedRepoRoot
    ) "repository_root"
    Assert-R24D12 ($remote -ceq $expectedRepoRemote) "repository_remote"
    Assert-R24D12 ($branch -ceq "main") "branch"
    Assert-R24D12 ([string]::IsNullOrEmpty($status)) "dirty_worktree"
    Assert-R24D12 (
        $head -ceq $upstream -and $head -ceq $cached -and $head -ceq $live
    ) "local_upstream_cached_live_inequality"
    Assert-R24D12 ($worktrees.Count -eq 1) "worktree_count"
    return [ordered]@{
        root = $root.Replace("\", "/")
        remote = $remote
        branch = $branch
        head = $head
        upstream = $upstream
        cached_origin_main = $cached
        live_origin_main = $live
        worktree_count = 1
        worktree_clean = $true
    }
}

function Assert-R24D12RuntimeReuseKey {
    $root = Get-R24D12Git -Root $godotRoot -Arguments @(
        "rev-parse", "--show-toplevel"
    )
    $remote = Get-R24D12Git -Root $godotRoot -Arguments @(
        "remote", "get-url", "origin"
    )
    $head = Get-R24D12Git -Root $godotRoot -Arguments @("rev-parse", "HEAD")
    Assert-R24D12 ([IO.Path]::GetFullPath($root) -ceq $godotRoot) (
        "godot_source_root"
    )
    Assert-R24D12 ($remote -ceq $expectedGodotRemote) "godot_remote"
    Assert-R24D12 ($head -ceq $expectedGodotCommit) "godot_commit"
    $statusOutput = @(& git -C $godotRoot status --short 2>&1)
    Assert-R24D12 ($LASTEXITCODE -eq 0) "godot_status"
    $statusPaths = @($statusOutput | ForEach-Object {
        ([string]$_).Substring(3).Replace("\", "/")
    })
    Assert-R24D12 (
        (($statusPaths | Sort-Object) -join "|") -ceq
        (($expectedPatchedPaths | Sort-Object) -join "|")
    ) "godot_patched_path_population"
    $patchPath = Get-R24D12Path $patchRelative
    Assert-R24D12 (
        (Get-FileHash -LiteralPath $patchPath -Algorithm SHA256).
            Hash.ToLowerInvariant() -ceq $expectedPatchHash
    ) "patch_hash"
    $diff = ((@(& git -C $godotRoot diff --no-ext-diff 2>&1) -join "`n") + "`n").
        Replace("`r`n", "`n")
    Assert-R24D12 ($LASTEXITCODE -eq 0) "godot_diff"
    $patchText = [IO.File]::ReadAllText($patchPath).
        Replace("`r`n", "`n").TrimEnd("`n") + "`n"
    Assert-R24D12 ($diff -ceq $patchText) "godot_patch_identity"
    $bodyPath = Join-Path $godotRoot (
        "modules\jolt_physics\objects\jolt_body_3d.cpp"
    )
    Assert-R24D12 (
        (Get-FileHash -LiteralPath $bodyPath -Algorithm SHA256).
            Hash.ToLowerInvariant() -ceq $expectedBodySourceHash
    ) "jolt_body_source_hash"
    $consolePath = Join-Path $godotRoot (
        "bin\godot.windows.editor.dev.x86_64.console.exe"
    )
    $enginePath = Join-Path $godotRoot (
        "bin\godot.windows.editor.dev.x86_64.exe"
    )
    $console = Get-R24D12FileReceipt $consolePath
    $engine = Get-R24D12FileReceipt $enginePath
    Assert-R24D12 (
        [string]$console.raw_sha256 -ceq "sha256:$expectedConsoleHash" -and
        [long]$console.byte_length -eq 293376 -and
        [string]$engine.raw_sha256 -ceq "sha256:$expectedEngineHash" -and
        [long]$engine.byte_length -eq 188829184
    ) "runtime_binary_pair"
    $baselinePath = Get-R24D12Path $coldBaselineRelative
    $baseline = Get-Content -Raw -LiteralPath $baselinePath |
        ConvertFrom-Json -Depth 100
    Assert-R24D12 (
        [string]$baseline.status -ceq
            "complete_zero_world_gate_passed_physical_execution_still_forbidden_pending_explicit_separate_authorization" -and
        [bool]$baseline.source.clean_pushed_before_qualification -and
        [bool]$baseline.runtime.retained_binary_pair_executed -and
        [double]$baseline.runtime.independent_cold_build_duration_s -gt 0.0 -and
        [string]$baseline.runtime.console_binary_raw_sha256 -ceq
            "sha256:$expectedConsoleHash" -and
        [string]$baseline.runtime.engine_binary_raw_sha256 -ceq
            "sha256:$expectedEngineHash" -and
        -not [bool]$baseline.runtime.result_reuse_authority
    ) "cold_baseline"
    return [ordered]@{
        key_id = "QSDK.R24D12.runtime_reuse_key.v1"
        godot_source_root = $godotRoot.Replace("\", "/")
        godot_source_commit = $head
        combined_patch_raw_sha256 = "sha256:$expectedPatchHash"
        jolt_body_source_raw_sha256 = "sha256:$expectedBodySourceHash"
        cold_baseline_closure = Get-R24D12FileReceipt $baselinePath
        console = $console
        engine = $engine
        host_os_version = [Environment]::OSVersion.VersionString
        process_architecture = [Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
        engine_build_reused = $true
        campaign_result_reused = $false
        physical_evidence_reused = $false
    }
}

function New-R24D12Project {
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][string]$TemplatePath
    )
    foreach ($relative in @(
        $baseRigRelative,
        $rigRelative,
        $baseWorkerRelative,
        $workerRelative
    )) {
        $destination = Join-Path $ProjectRoot $relative.Replace("/", "\")
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
        Copy-Item -LiteralPath (Get-R24D12Path $relative) -Destination $destination
    }
    Copy-Item -LiteralPath $TemplatePath -Destination (
        Join-Path $ProjectRoot "zero_world_template.json"
    )
    $projectText = @'
; QSDK-R24D12 minimal braking mechanism zero-world qualification.
config_version=5

[application]
config/name="qsdk-r24d12-braking-mechanism-activation"
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

function Invoke-R24D12Worker {
    param(
        [Parameter(Mandatory)][string]$ConsolePath,
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][string]$RunRoot,
        [Parameter(Mandatory)][string]$Nonce,
        [Parameter(Mandatory)][string]$Head,
        [Parameter(Mandatory)][string]$ReportPath
    )
    $engineLogPath = Join-Path $RunRoot "godot-zero-world-engine.log"
    $arguments = @(
        "--headless",
        "--path", $ProjectRoot,
        "--log-file", $engineLogPath,
        "--script", ("res://" + $workerRelative),
        "--",
        "--mode=zero_world_preflight",
        "--nonce=$Nonce",
        "--source_commit=$Head",
        "--report_path=$ReportPath"
    )
    $environment = @{
        SPORESPORE_R24D12_SUPERVISED_TERMINATION = "1"
        SPORESPORE_R24D12_TERMINATION_NONCE = $Nonce
        SPORESPORE_R24D12_EXECUTION_NONCE = $Nonce
        SPORESPORE_R24D12_SOURCE_COMMIT = $Head
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
            "SPORESPORE_R24D12_EXECUTION_NONCE",
            "SPORESPORE_R24D12_SOURCE_COMMIT"
        ) `
        -TimeoutSeconds 120
    $stdoutPath = Join-Path $RunRoot "godot-zero-world-stdout.log"
    $stderrPath = Join-Path $RunRoot "godot-zero-world-stderr.log"
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
    Assert-R24D12 (
        [bool]$result.termination_protocol_valid -and
        [bool]$result.supervisor_terminated -and
        [int]$result.exit_code -eq 0
    ) (
        "zero_worker_failed:semantic=$($result.exit_code):" +
        "host=$($result.host_exit_code):protocol=" +
        "$($result.termination_protocol_failure_code)"
    )
    $stdoutLines = @(([string]$result.stdout) -split "`r?`n")
    $errorLines = @(
        $stdoutLines + @(([string]$result.stderr) -split "`r?`n") |
            Where-Object { $_ -match "(^|\s)(SCRIPT ERROR|ERROR):" }
    )
    Assert-R24D12 ($errorLines.Count -eq 0) (
        "zero_worker_error_lines:$($errorLines -join '|')"
    )
    Assert-R24D12 (Test-Path -LiteralPath $ReportPath -PathType Leaf) (
        "zero_worker_report_missing"
    )
    return [ordered]@{
        result = $result
        stdout_lines = $stdoutLines
        stdout = Get-R24D12FileReceipt $stdoutPath
        stderr = Get-R24D12FileReceipt $stderrPath
        engine_log = Get-R24D12FileReceipt $engineLogPath
    }
}

function Get-R24D12Marker {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines,
        [Parameter(Mandatory)][string]$Prefix,
        [Parameter(Mandatory)][string]$Code
    )
    $matches = @($Lines | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R24D12 ($matches.Count -eq 1) "$Code`_marker_count:$($matches.Count)"
    return ([string]$matches[0]).Substring($Prefix.Length)
}

function Get-R24D12PriorAttempts {
    param(
        [Parameter(Mandatory)][string]$CampaignRoot,
        [Parameter(Mandatory)][string]$Head
    )
    if (-not (Test-Path -LiteralPath $CampaignRoot -PathType Container)) {
        return @()
    }
    $matches = [Collections.Generic.List[string]]::new()
    foreach ($path in @(Get-ChildItem -LiteralPath $CampaignRoot `
        -Filter "attempt.json" -File -Recurse -ErrorAction Stop)) {
        try {
            $attempt = Get-Content -Raw -LiteralPath $path.FullName |
                ConvertFrom-Json -AsHashtable -Depth 100
            if ([string]$attempt.source_commit -ceq $Head) {
                $matches.Add($path.FullName)
            }
        } catch {
            throw "Unreadable retained R24D12 attempt: $($path.FullName)"
        }
    }
    return @($matches)
}

$operationLock = $null
$runRoot = ""
$attemptPath = ""
try {
    $operationLock = Enter-SporeSporeLocomotionOperationLock -Role "conformance"
    Assert-R24D12 ([bool]$operationLock.acquired) (
        "another_physical_or_conformance_workload_owns_the_lock"
    )
    Assert-R24D12 ($godotRoot -ceq $expectedGodotRoot) (
        "godot_source_root_substitution_forbidden"
    )
    Assert-R24D12 ($evidenceBase -ceq $expectedEvidenceRoot) (
        "evidence_root_substitution_forbidden"
    )
    $source = Assert-R24D12RepositoryBoundary
    $head = [string]$source.head
    $pythonPath = Resolve-R24D12Application $Python
    $campaignRoot = Join-Path $evidenceBase (
        "qsdk-r24d12-braking-mechanism-activation\zero-world"
    )
    $prior = @(Get-R24D12PriorAttempts -CampaignRoot $campaignRoot -Head $head)
    Assert-R24D12 ($prior.Count -eq 0) (
        "same_source_zero_world_attempt_already_consumed:$($prior -join '|')"
    )

    $stamp = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
    $nonce = [Guid]::NewGuid().ToString("N")
    $runRoot = Join-Path $campaignRoot (
        "$stamp-$($head.Substring(0, 8))-$($nonce.Substring(0, 12))"
    )
    Assert-R24D12 (-not (Test-Path -LiteralPath $runRoot)) "run_root_exists"
    [void][IO.Directory]::CreateDirectory($runRoot)
    $attemptPath = Join-Path $runRoot "attempt.json"
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_r24d12_zero_world_attempt_v1"
        gate_id = "QSDK-R24D12"
        question_class = "development"
        status = "consumed_before_first_stage"
        source_commit = $head
        created_utc = [DateTimeOffset]::UtcNow.ToString("o")
        zero_world_attempt_count = 1
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        same_source_rerun_allowed = $false
        physical_authority = $false
        release_authority = $false
    }
    Write-R24D12Json -Path $attemptPath -Value $attempt
    $attemptCas = Publish-R24D12Artifact -Path $attemptPath

    $stageReceipts = [Collections.Generic.List[object]]::new()
    $stageIndex = 1
    $freezeLog = Join-Path $runRoot "01-r24d12_freeze_and_mutation_audit.log"
    $freezeRun = Invoke-R24D12Checked `
        -FileName $pythonPath `
        -Arguments @(
            (Get-R24D12Path $freezeAuditRelative),
            "--require-committed",
            "--godot-source-root", $godotRoot
        ) `
        -WorkingDirectory $repoRoot `
        -Label "R24D12 freeze and mutation audit" `
        -LogPath $freezeLog
    $stageReceipts.Add([ordered]@{
        index = $stageIndex
        name = "r24d12_freeze_and_mutation_audit"
        duration_s = $freezeRun.duration_s
        log = $freezeRun.log
        cas = Publish-R24D12Artifact -Path $freezeLog -MediaType "text/plain"
    })

    $stageIndex += 1
    $runtimeLog = Join-Path $runRoot "02-exact_runtime_reuse_key.log"
    $runtimeStarted = [DateTimeOffset]::UtcNow
    $runtimeReuse = Assert-R24D12RuntimeReuseKey
    $runtimeFinished = [DateTimeOffset]::UtcNow
    Write-R24D12Json -Path $runtimeLog -Value $runtimeReuse
    $stageReceipts.Add([ordered]@{
        index = $stageIndex
        name = "r24d10_cold_baseline_and_exact_runtime_reuse_key"
        duration_s = [Math]::Round(($runtimeFinished - $runtimeStarted).TotalSeconds, 6)
        log = Get-R24D12FileReceipt $runtimeLog
        cas = Publish-R24D12Artifact -Path $runtimeLog
    })
    $consolePath = [string]$runtimeReuse.console.path
    $consoleCas = Publish-R24D12Artifact `
        -Path $consolePath `
        -MediaType "application/vnd.microsoft.portable-executable"
    $engineCas = Publish-R24D12Artifact `
        -Path ([string]$runtimeReuse.engine.path) `
        -MediaType "application/vnd.microsoft.portable-executable"

    $stageIndex += 1
    $templatePath = Join-Path $runRoot "zero-world-template.json"
    $templateLog = Join-Path $runRoot "03-evaluator_shaped_zero_world_template.log"
    $templateRun = Invoke-R24D12Checked `
        -FileName $pythonPath `
        -Arguments @(
            (Get-R24D12Path $evaluatorRelative),
            "--emit-zero-world-template", $templatePath,
            "--expected-source-commit", $head,
            "--expected-nonce", $nonce
        ) `
        -WorkingDirectory $repoRoot `
        -Label "R24D12 evaluator-shaped zero-world template" `
        -LogPath $templateLog
    $stageReceipts.Add([ordered]@{
        index = $stageIndex
        name = "evaluator_shaped_zero_world_template"
        duration_s = $templateRun.duration_s
        log = $templateRun.log
        cas = Publish-R24D12Artifact -Path $templateLog -MediaType "text/plain"
    })

    $projectRoot = Join-Path $runRoot "project"
    [void][IO.Directory]::CreateDirectory($projectRoot)
    New-R24D12Project -ProjectRoot $projectRoot -TemplatePath $templatePath
    $stageIndex += 1
    $rawPath = Join-Path $runRoot "synthetic-raw-report.json"
    $worker = Invoke-R24D12Worker `
        -ConsolePath $consolePath `
        -ProjectRoot $projectRoot `
        -RunRoot $runRoot `
        -Nonce $nonce `
        -Head $head `
        -ReportPath $rawPath
    $workerReceipt = (Get-R24D12Marker `
        -Lines $worker.stdout_lines `
        -Prefix $workerPrefix `
        -Code "zero_worker") |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D12 (
        [bool]$workerReceipt.ok -and
        [bool]$workerReceipt.engine_freeze_matches -and
        [bool]$workerReceipt.fixture_description_matches -and
        [bool]$workerReceipt.invalid_rid_refused -and
        [bool]$workerReceipt.template_shape_matches -and
        [bool]$workerReceipt.template_identity_matches -and
        [bool]$workerReceipt.template_byte_passthrough -and
        [bool]$workerReceipt.synthetic_report_written -and
        [double]$workerReceipt.active_physics_object_count -eq 0.0 -and
        [int]$workerReceipt.synthetic_embedded_world_count -eq 1 -and
        [int]$workerReceipt.synthetic_embedded_physics_step_count -eq 1 -and
        [int]$workerReceipt.synthetic_embedded_retained_sample_count -eq 4 -and
        -not [bool]$workerReceipt.synthetic_envelope_is_physical_observation -and
        [int]$workerReceipt.world_attempt_count -eq 0 -and
        [int]$workerReceipt.world_build_count -eq 0 -and
        [int]$workerReceipt.solver_step_count -eq 0 -and
        -not [bool]$workerReceipt.physical_acceptance_authority -and
        -not [bool]$workerReceipt.release_authority
    ) "zero_worker_receipt"
    $workerLog = Join-Path $runRoot "04-custom_runtime_zero_object_worker.log"
    [IO.File]::WriteAllText(
        $workerLog,
        [string]$worker.result.stdout,
        [Text.UTF8Encoding]::new($false)
    )
    $stageReceipts.Add([ordered]@{
        index = $stageIndex
        name = "custom_runtime_zero_object_worker"
        duration_s = 0.0
        log = Get-R24D12FileReceipt $workerLog
        cas = Publish-R24D12Artifact -Path $workerLog -MediaType "text/plain"
    })

    $stageIndex += 1
    $evaluationPath = Join-Path $runRoot "synthetic-evaluation.json"
    $evaluationLog = Join-Path $runRoot "05-independent_synthetic_evaluation.log"
    $evaluationRun = Invoke-R24D12Checked `
        -FileName $pythonPath `
        -Arguments @(
            (Get-R24D12Path $evaluatorRelative),
            "--input", $rawPath,
            "--output", $evaluationPath,
            "--expected-source-commit", $head,
            "--expected-nonce", $nonce,
            "--expected-evidence-kind", "synthetic_zero_world"
        ) `
        -WorkingDirectory $repoRoot `
        -Label "R24D12 independent synthetic evaluation" `
        -LogPath $evaluationLog
    $evaluation = Get-Content -Raw -LiteralPath $evaluationPath |
        ConvertFrom-Json -Depth 100
    Assert-R24D12 (
        [bool]$evaluation.ok -and
        [bool]$evaluation.execution_valid -and
        [string]$evaluation.result -ceq "synthetic_shape_conforms_zero_world_only" -and
        [int]$evaluation.summary.cell_count -eq 4 -and
        [int]$evaluation.summary.retained_sample_count -eq 4 -and
        -not [bool]$evaluation.summary.native_braking_mechanism_activation_observed -and
        -not [bool]$evaluation.instrumented_profile_promoted -and
        -not [bool]$evaluation.physical_acceptance_authority -and
        -not [bool]$evaluation.release_authority
    ) "synthetic_evaluation"
    $stageReceipts.Add([ordered]@{
        index = $stageIndex
        name = "independent_synthetic_evaluation"
        duration_s = $evaluationRun.duration_s
        log = $evaluationRun.log
        cas = Publish-R24D12Artifact -Path $evaluationLog -MediaType "text/plain"
    })

    $sourceAfter = Assert-R24D12RepositoryBoundary
    Assert-R24D12 ([string]$sourceAfter.head -ceq $head) (
        "source_drift_during_zero_world_gate"
    )
    $rawReceipt = Get-R24D12FileReceipt $rawPath
    $evaluationReceipt = Get-R24D12FileReceipt $evaluationPath
    $templateReceipt = Get-R24D12FileReceipt $templatePath
    $receipt = [ordered]@{
        schema_version = "sporespore_qsdk_r24d12_braking_mechanism_activation_zero_world_receipt_v1"
        ok = $true
        gate_id = "QSDK-R24D12"
        question_class = "development"
        status = (
            "complete_zero_world_gate_passed_physical_execution_still_forbidden_" +
            "pending_explicit_separate_authorization"
        )
        source = $source
        declaration = Get-R24D12FileReceipt (Get-R24D12Path $declarationRelative)
        validation_manifest = Get-R24D12FileReceipt (Get-R24D12Path $manifestRelative)
        runtime_reuse_key = $runtimeReuse
        operation_lock = Get-SporeSporeLocomotionOperationLockPublicReceipt `
            -Receipt $operationLock
        stages = @($stageReceipts)
        attempt = Get-R24D12FileReceipt $attemptPath
        attempt_cas = $attemptCas
        binary_pair = [ordered]@{
            console = $runtimeReuse.console
            console_cas = $consoleCas
            engine = $runtimeReuse.engine
            engine_cas = $engineCas
            exact_cold_baseline_bytes_reused = $true
            campaign_result_reused = $false
            physical_evidence_reused = $false
        }
        worker = [ordered]@{
            receipt = $workerReceipt
            raw_report = $rawReceipt
            raw_report_cas = Publish-R24D12Artifact -Path $rawPath
            stdout = $worker.stdout
            stdout_cas = Publish-R24D12Artifact `
                -Path ([string]$worker.stdout.path) -MediaType "text/plain"
            stderr = $worker.stderr
            stderr_cas = Publish-R24D12Artifact `
                -Path ([string]$worker.stderr.path) -MediaType "text/plain"
            engine_log = $worker.engine_log
            engine_log_cas = Publish-R24D12Artifact `
                -Path ([string]$worker.engine_log.path) -MediaType "text/plain"
        }
        evaluation = [ordered]@{
            file = $evaluationReceipt
            cas = Publish-R24D12Artifact -Path $evaluationPath
            result = [string]$evaluation.result
        }
        synthetic_shape = [ordered]@{
            template = $templateReceipt
            template_cas = Publish-R24D12Artifact -Path $templatePath
            declared_world_count = 1
            declared_solver_step_count = 1
            declared_retained_sample_count = 4
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
            corrected_activation_route_source_qualified = $true
            exact_runtime_reuse_key_passed = $true
            physical_characterization_executed = $false
            braking_mechanism_activated = $false
            numerical_accuracy_accepted = $false
            instrumented_profile_promoted = $false
            stock_godot_profile_promoted = $false
            recovery_world_opened = $false
            prone_to_standing_world_opened = $false
            q_sdk_r24_satisfied = $false
            physical_authorization = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
        same_source_zero_world_rerun_allowed = $false
    }
    $receiptPath = Join-Path $runRoot "receipt.json"
    Write-R24D12Json -Path $receiptPath -Value $receipt
    $receiptFile = Get-R24D12FileReceipt $receiptPath
    $receiptCas = Publish-R24D12Artifact -Path $receiptPath
    Write-Output (
        "QSDK_R24D12_BRAKING_MECHANISM_ZERO_WORLD_GATE " +
        ([ordered]@{
            ok = $true
            status = [string]$receipt.status
            source_commit = $head
            run_root = $runRoot.Replace("\", "/")
            receipt_path = [string]$receiptFile.path
            receipt_raw_sha256 = [string]$receiptFile.raw_sha256
            receipt_cas_payload_path = [string]$receiptCas.payload_path
            runtime_build_reused = $true
            stage_count = $stageReceipts.Count
            world_attempt_count = 0
            world_build_count = 0
            solver_step_count = 0
            physical_authorization = $false
            release_authority = $false
        } | ConvertTo-Json -Compress)
    )
} catch {
    if (-not [string]::IsNullOrEmpty($attemptPath) -and
        (Test-Path -LiteralPath $attemptPath -PathType Leaf)) {
        try {
            $failedAttempt = Get-Content -Raw -LiteralPath $attemptPath |
                ConvertFrom-Json -AsHashtable -Depth 100
            $failedAttempt.status = "failed_or_incomplete_retained"
            $failedAttempt.failure = $_.Exception.Message
            $failedAttempt.failed_utc = [DateTimeOffset]::UtcNow.ToString("o")
            Write-R24D12Json -Path $attemptPath -Value $failedAttempt
            [void](Publish-R24D12Artifact -Path $attemptPath)
        } catch {
            Write-Warning "Could not update retained R24D12 attempt: $_"
        }
    }
    throw
} finally {
    if ($null -ne $operationLock) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $operationLock
    }
}

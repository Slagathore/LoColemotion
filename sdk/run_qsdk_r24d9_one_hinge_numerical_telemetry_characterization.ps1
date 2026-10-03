#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet("ZeroWorld", "Physical")]
    [string]$Mode = "ZeroWorld",
    [switch]$RunPhysical,
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
$expectedRepoRemote = "https://github.com/Slagathore/sporespore.git"
$expectedGodotRoot = "C:\Users\Cole\CodeStuff\dependencies\godot-sporespore-4.7"
$expectedGodotRemote = "https://github.com/godotengine/godot.git"
$expectedEvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$expectedGodotCommit = "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"
$expectedPatchHash = (
    "9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c"
)
$contractRelative = (
    "sdk/recovery/" +
    "r24d9_godot_jolt_one_hinge_numerical_telemetry_" +
    "characterization_preregistration_v1.json"
)
$manifestRelative = (
    "sdk/recovery/" +
    "r24d9_godot_jolt_one_hinge_numerical_telemetry_validation_manifest.json"
)
$patchRelative = (
    "sdk/adapters/godot/engine_patches/" +
    "godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch"
)
$rigRelative = (
    "scripts/lab/rigs/" +
    "r24d9_godot_jolt_one_hinge_numerical_telemetry_rig.gd"
)
$workerRelative = (
    "tests/" +
    "test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_worker.gd"
)
$evaluatorRelative = (
    "sdk/recovery/" +
    "r24d9_godot_jolt_one_hinge_numerical_telemetry_" +
    "characterization_evaluator.py"
)
$freezeAuditRelative = (
    "tests/test_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_freeze.ps1"
)
$declarationAuditRelative = "tests/test_qsdk_r24d9_numerical_telemetry_preregistration.ps1"
$parentClosureAuditRelative = (
    "tests/test_qsdk_r24d8_active_step_snapshot_timing_positive_closure.ps1"
)
$readyPrefix = "QSDK_R24D9_GODOT_SUPERVISOR_TERMINATION_READY "
$zeroWorkerPrefix = "QSDK_R24D9_WORKER_ZERO_WORLD "
$physicalWorkerPrefix = "QSDK_R24D9_PHYSICAL_RAW_REPORT "
$evaluationPrefix = "QSDK_R24D9_EVALUATION_PASS "
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

function Assert-R24D9Supervisor {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) { throw "QSDK-R24D9 supervisor: $Code" }
}

function Get-R24D9Path {
    param([Parameter(Mandatory)][string]$Relative)
    return [IO.Path]::GetFullPath((Join-Path $repoRoot $Relative))
}

function Resolve-R24D9Application {
    param([Parameter(Mandatory)][string]$Command)
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R24D9Supervisor (
            Test-Path -LiteralPath $resolved -PathType Leaf
        ) "application_missing:$resolved"
        return $resolved
    }
    $candidate = Get-Command -Name $Command -CommandType Application |
        Select-Object -First 1
    Assert-R24D9Supervisor ($null -ne $candidate) "application_missing:$Command"
    return [IO.Path]::GetFullPath([string]$candidate.Source)
}

function Get-R24D9GitValue {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    $output = @(& git -C $Root @Arguments 2>&1)
    Assert-R24D9Supervisor ($LASTEXITCODE -eq 0) (
        "git_$($Arguments -join '_'):$($output -join '|')"
    )
    return ($output -join "`n").Trim()
}

function Get-R24D9FileReceipt {
    param([Parameter(Mandatory)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    Assert-R24D9Supervisor (Test-Path -LiteralPath $full -PathType Leaf) (
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

function Publish-R24D9Artifact {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$MediaType = "application/json"
    )
    return Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot `
        -ArtifactPath $Path `
        -MediaType $MediaType
}

function Write-R24D9Json {
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

function Get-R24D9Marker {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines,
        [Parameter(Mandatory)][string]$Prefix,
        [Parameter(Mandatory)][string]$Code
    )
    $matches = @($Lines | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R24D9Supervisor ($matches.Count -eq 1) (
        "$Code`_marker_count:$($matches.Count)"
    )
    return ([string]$matches[0]).Substring($Prefix.Length)
}

function Invoke-R24D9Checked {
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
    Assert-R24D9Supervisor ($exitCode -eq 0) (
        "$Label`:$($lines -join '|')"
    )
    return [ordered]@{
        output = $lines
        duration_s = [Math]::Round(($finished - $started).TotalSeconds, 6)
        log = Get-R24D9FileReceipt $LogPath
    }
}

function Assert-R24D9RepositoryBoundary {
    $root = Get-R24D9GitValue -Root $repoRoot -Arguments @(
        "rev-parse", "--show-toplevel"
    )
    $remote = Get-R24D9GitValue -Root $repoRoot -Arguments @(
        "remote", "get-url", "origin"
    )
    $branch = Get-R24D9GitValue -Root $repoRoot -Arguments @(
        "branch", "--show-current"
    )
    $head = Get-R24D9GitValue -Root $repoRoot -Arguments @("rev-parse", "HEAD")
    $upstream = Get-R24D9GitValue -Root $repoRoot -Arguments @(
        "rev-parse", "@{upstream}"
    )
    $cached = Get-R24D9GitValue -Root $repoRoot -Arguments @(
        "rev-parse", "refs/remotes/origin/main"
    )
    $liveText = Get-R24D9GitValue -Root $repoRoot -Arguments @(
        "ls-remote", "--heads", "origin", "refs/heads/main"
    )
    $live = $liveText.Split("`t")[0]
    $status = Get-R24D9GitValue -Root $repoRoot -Arguments @(
        "status", "--short"
    )
    $worktreeText = Get-R24D9GitValue -Root $repoRoot -Arguments @(
        "worktree", "list", "--porcelain"
    )
    $worktrees = @($worktreeText -split "`r?`n" | Where-Object {
        $_.StartsWith("worktree ", [StringComparison]::Ordinal)
    })
    Assert-R24D9Supervisor (
        [IO.Path]::GetFullPath($root) -ceq $expectedRepoRoot -and
        $repoRoot -ceq $expectedRepoRoot
    ) "repository_root"
    Assert-R24D9Supervisor ($remote -ceq $expectedRepoRemote) "repository_remote"
    Assert-R24D9Supervisor ($branch -ceq "main") "branch"
    Assert-R24D9Supervisor ([string]::IsNullOrEmpty($status)) "dirty_worktree"
    Assert-R24D9Supervisor (
        $head -ceq $upstream -and $head -ceq $cached -and $head -ceq $live
    ) "local_upstream_cached_live_inequality"
    Assert-R24D9Supervisor ($worktrees.Count -eq 1) "worktree_count"
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

function Assert-R24D9GodotSourceBoundary {
    $root = Get-R24D9GitValue -Root $godotRoot -Arguments @(
        "rev-parse", "--show-toplevel"
    )
    $remote = Get-R24D9GitValue -Root $godotRoot -Arguments @(
        "remote", "get-url", "origin"
    )
    $head = Get-R24D9GitValue -Root $godotRoot -Arguments @("rev-parse", "HEAD")
    Assert-R24D9Supervisor ([IO.Path]::GetFullPath($root) -ceq $godotRoot) (
        "godot_source_root"
    )
    Assert-R24D9Supervisor ($remote -ceq $expectedGodotRemote) "godot_remote"
    Assert-R24D9Supervisor ($head -ceq $expectedGodotCommit) "godot_commit"
    $statusOutput = @(& git -C $godotRoot status --short 2>&1)
    Assert-R24D9Supervisor ($LASTEXITCODE -eq 0) "godot_status"
    $statusPaths = @($statusOutput | ForEach-Object {
        ([string]$_).Substring(3).Replace("\", "/")
    })
    Assert-R24D9Supervisor (
        (($statusPaths | Sort-Object) -join "|") -ceq
        (($expectedPatchedPaths | Sort-Object) -join "|")
    ) "godot_dirty_path_set"
    $patchPath = Get-R24D9Path $patchRelative
    $patchReceipt = Get-R24D9FileReceipt $patchPath
    Assert-R24D9Supervisor (
        [string]$patchReceipt.raw_sha256 -ceq "sha256:$expectedPatchHash"
    ) "patch_digest"
    $diffLines = @(& git -C $godotRoot diff --no-ext-diff 2>&1)
    Assert-R24D9Supervisor ($LASTEXITCODE -eq 0) "godot_diff"
    $diffText = (($diffLines -join "`n") + "`n").Replace("`r`n", "`n")
    $patchText = [IO.File]::ReadAllText($patchPath).
        Replace("`r`n", "`n").TrimEnd("`n") + "`n"
    Assert-R24D9Supervisor ($diffText -ceq $patchText) (
        "godot_diff_patch_inequality"
    )
    $reverse = @(
        & git -C $godotRoot apply --reverse --check --whitespace=error-all $patchPath 2>&1
    )
    Assert-R24D9Supervisor ($LASTEXITCODE -eq 0) (
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

function New-R24D9Project {
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [string]$TemplatePath = ""
    )
    $rigDestination = Join-Path $ProjectRoot (
        "scripts\lab\rigs\" +
        "r24d9_godot_jolt_one_hinge_numerical_telemetry_rig.gd"
    )
    $workerDestination = Join-Path $ProjectRoot (
        "tests\" +
        "test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_worker.gd"
    )
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $rigDestination))
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $workerDestination))
    Copy-Item -LiteralPath (Get-R24D9Path $rigRelative) -Destination $rigDestination
    Copy-Item -LiteralPath (Get-R24D9Path $workerRelative) -Destination $workerDestination
    if (-not [string]::IsNullOrWhiteSpace($TemplatePath)) {
        Copy-Item -LiteralPath $TemplatePath -Destination (
            Join-Path $ProjectRoot "zero_world_template.json"
        )
    }
    $projectText = @'
; QSDK-R24D9 isolated one-hinge numerical telemetry characterization.
config_version=5

[application]
config/name="qsdk-r24d9-one-hinge-numerical-telemetry"
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

function Invoke-R24D9Worker {
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
            "test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_worker.gd"
        ),
        "--",
        "--mode=$WorkerMode",
        "--nonce=$Nonce",
        "--source_commit=$Head",
        "--report_path=$ReportPath"
    )
    $environment = @{
        SPORESPORE_R24D9_SUPERVISED_TERMINATION = "1"
        SPORESPORE_R24D9_TERMINATION_NONCE = $Nonce
        SPORESPORE_R24D9_EXECUTION_NONCE = $Nonce
        SPORESPORE_R24D9_SOURCE_COMMIT = $Head
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
            "SPORESPORE_R24D9_EXECUTION_NONCE",
            "SPORESPORE_R24D9_SOURCE_COMMIT"
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
    Assert-R24D9Supervisor (
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
    Assert-R24D9Supervisor ($errorLines.Count -eq 0) (
        "worker_$WorkerMode`_error_lines:$($errorLines -join '|')"
    )
    Assert-R24D9Supervisor (Test-Path -LiteralPath $ReportPath -PathType Leaf) (
        "worker_$WorkerMode`_report_missing"
    )
    return [ordered]@{
        result = $result
        stdout_lines = $stdoutLines
        stdout = Get-R24D9FileReceipt $stdoutPath
        stderr = Get-R24D9FileReceipt $stderrPath
        engine_log = Get-R24D9FileReceipt $engineLogPath
    }
}

function Invoke-R24D9Evaluation {
    param(
        [Parameter(Mandatory)][string]$PythonPath,
        [Parameter(Mandatory)][string]$InputPath,
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][string]$SourceCommit,
        [Parameter(Mandatory)][string]$Nonce,
        [Parameter(Mandatory)][string]$EvidenceKind,
        [Parameter(Mandatory)][string]$LogPath
    )
    $run = Invoke-R24D9Checked `
        -FileName $PythonPath `
        -Arguments @(
            (Get-R24D9Path $evaluatorRelative),
            "--input", $InputPath,
            "--output", $OutputPath,
            "--expected-source-commit", $SourceCommit,
            "--expected-nonce", $Nonce,
            "--expected-evidence-kind", $EvidenceKind
        ) `
        -WorkingDirectory $repoRoot `
        -Label "R24D9 $EvidenceKind evaluation" `
        -LogPath $LogPath
    $marker = Get-R24D9Marker `
        -Lines $run.output `
        -Prefix $evaluationPrefix `
        -Code "evaluation"
    return [ordered]@{
        receipt = $marker | ConvertFrom-Json -AsHashtable -Depth 100
        output = Get-R24D9FileReceipt $OutputPath
        run = $run
    }
}

function Assert-R24D9ZeroReceipt {
    param(
        [Parameter(Mandatory)][hashtable]$Receipt,
        [Parameter(Mandatory)][string]$Head,
        [Parameter(Mandatory)][hashtable]$ManifestReceipt
    )
    Assert-R24D9Supervisor (
        [string]$Receipt.schema_version -ceq
            "sporespore_qsdk_r24d9_one_hinge_numerical_telemetry_zero_world_receipt_v1" -and
        [bool]$Receipt.ok -and
        [string]$Receipt.gate_id -ceq "QSDK-R24D9" -and
        [string]$Receipt.question_class -ceq "development" -and
        [string]$Receipt.status -ceq
            "complete_zero_world_gate_passed_physical_execution_separately_authorized" -and
        [string]$Receipt.source.head -ceq $Head -and
        [string]$Receipt.source.upstream -ceq $Head -and
        [string]$Receipt.source.cached_origin_main -ceq $Head -and
        [string]$Receipt.source.live_origin_main -ceq $Head -and
        [string]$Receipt.validation_manifest.raw_sha256 -ceq
            [string]$ManifestReceipt.raw_sha256 -and
        [long]$Receipt.validation_manifest.byte_length -eq
            [long]$ManifestReceipt.byte_length -and
        [int]$Receipt.actual_counts.world_attempt_count -eq 0 -and
        [int]$Receipt.actual_counts.world_build_count -eq 0 -and
        [int]$Receipt.actual_counts.solver_step_count -eq 0 -and
        [int]$Receipt.actual_counts.physical_world_count -eq 0 -and
        [bool]$Receipt.claims.complete_zero_world_gate_passed -and
        -not [bool]$Receipt.claims.physical_characterization_executed -and
        -not [bool]$Receipt.claims.physical_acceptance_authority -and
        -not [bool]$Receipt.claims.release_authority
    ) "zero_world_receipt"
    foreach ($binaryName in @("console", "engine")) {
        $binary = [hashtable]$Receipt.binary_pair[$binaryName]
        $cas = [hashtable]$binary.cas
        Assert-R24D9Supervisor (
            (Test-Path -LiteralPath ([string]$binary.path) -PathType Leaf) -and
            [string]$binary.raw_sha256 -ceq
                [string](Get-R24D9FileReceipt ([string]$binary.path)).raw_sha256 -and
            [long]$binary.byte_length -eq
                [long](Get-R24D9FileReceipt ([string]$binary.path)).byte_length -and
            [string]$cas.sha256 -ceq [string]$binary.raw_sha256 -and
            [long]$cas.byte_length -eq [long]$binary.byte_length -and
            (Test-SporeSporeStoredArtifact `
                -Directory (Split-Path -Parent ([string]$cas.payload_path)) `
                -ExpectedSha256 ([string]$binary.raw_sha256).Substring(7) `
                -ExpectedByteLength ([long]$binary.byte_length))
        ) "zero_world_binary_$binaryName"
    }
}

function Get-R24D9MatchingAttempts {
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
try {
    $lockRole = if ($Mode -ceq "Physical") { "physical" } else { "conformance" }
    $operationLock = Enter-SporeSporeLocomotionOperationLock -Role $lockRole
    Assert-R24D9Supervisor ([bool]$operationLock.acquired) (
        "another_physical_or_conformance_workload_owns_the_lock"
    )
    Assert-R24D9Supervisor ($godotRoot -ceq $expectedGodotRoot) (
        "godot_source_root_substitution_forbidden"
    )
    Assert-R24D9Supervisor ($evidenceBase -ceq $expectedEvidenceRoot) (
        "evidence_root_substitution_forbidden"
    )
    Assert-R24D9Supervisor (
        -not $evidenceBase.StartsWith(
            $repoRoot + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        )
    ) "evidence_root_inside_repository"
    $source = Assert-R24D9RepositoryBoundary
    $head = [string]$source.head
    $godotSource = Assert-R24D9GodotSourceBoundary
    $pythonPath = Resolve-R24D9Application $Python
    $manifestReceipt = Get-R24D9FileReceipt (Get-R24D9Path $manifestRelative)
    $campaignRoot = Join-Path $evidenceBase (
        "qsdk-r24d9-one-hinge-numerical-telemetry"
    )
    [void][IO.Directory]::CreateDirectory($campaignRoot)
    $stamp = [DateTimeOffset]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")

    if ($Mode -ceq "ZeroWorld") {
        Assert-R24D9Supervisor (-not $RunPhysical) "physical_switch_in_zero_world_mode"
        $runRoot = Join-Path $campaignRoot (
            "zero-world\$stamp-$($head.Substring(0, 8))-$($expectedPatchHash.Substring(0, 12))"
        )
        Assert-R24D9Supervisor (-not (Test-Path -LiteralPath $runRoot)) (
            "run_root_exists"
        )
        [void][IO.Directory]::CreateDirectory($runRoot)
        $stageReceipts = [Collections.Generic.List[object]]::new()
        $stageDefinitions = @(
            [ordered]@{
                name = "r24d9_declaration"
                file = "pwsh"
                arguments = @(
                    "-NoLogo", "-NoProfile", "-File",
                    (Get-R24D9Path $declarationAuditRelative)
                )
            },
            [ordered]@{
                name = "immutable_r24d8_closure"
                file = "pwsh"
                arguments = @(
                    "-NoLogo", "-NoProfile", "-File",
                    (Get-R24D9Path $parentClosureAuditRelative),
                    "-GodotRepositoryRoot", $godotRoot
                )
            },
            [ordered]@{
                name = "r24d9_freeze"
                file = "pwsh"
                arguments = @(
                    "-NoLogo", "-NoProfile", "-File",
                    (Get-R24D9Path $freezeAuditRelative),
                    "-Python", $pythonPath,
                    "-GodotSourceRoot", $godotRoot
                )
            },
            [ordered]@{
                name = "r24d9_evaluator_self_test"
                file = $pythonPath
                arguments = @(
                    (Get-R24D9Path $evaluatorRelative), "--self-test"
                )
            }
        )
        $stageIndex = 0
        foreach ($stage in $stageDefinitions) {
            $stageIndex += 1
            $logPath = Join-Path $runRoot (
                "{0:d2}-{1}.log" -f $stageIndex, [string]$stage.name
            )
            $stageRun = Invoke-R24D9Checked `
                -FileName (Resolve-R24D9Application ([string]$stage.file)) `
                -Arguments @($stage.arguments) `
                -WorkingDirectory $repoRoot `
                -Label ([string]$stage.name) `
                -LogPath $logPath
            $stageReceipts.Add([ordered]@{
                index = $stageIndex
                name = [string]$stage.name
                duration_s = [double]$stageRun.duration_s
                log = $stageRun.log
                cas = Publish-R24D9Artifact -Path $logPath -MediaType "text/plain"
            })
        }

        $cleanLog = Join-Path $runRoot "05-cold-clean.log"
        $cleanRun = Invoke-R24D9Checked `
            -FileName $pythonPath `
            -Arguments (@("-m", "SCons", "--clean") + $sconsArguments) `
            -WorkingDirectory $godotRoot `
            -Label "R24D9 pinned Godot cold cleanup" `
            -LogPath $cleanLog
        $buildLog = Join-Path $runRoot "06-cold-build.log"
        $buildRun = Invoke-R24D9Checked `
            -FileName $pythonPath `
            -Arguments (@("-m", "SCons") + $sconsArguments) `
            -WorkingDirectory $godotRoot `
            -Label "R24D9 pinned Godot cold build" `
            -LogPath $buildLog
        $stageReceipts.Add([ordered]@{
            index = 5
            name = "cold_cleanup"
            duration_s = [double]$cleanRun.duration_s
            log = $cleanRun.log
            cas = Publish-R24D9Artifact -Path $cleanLog -MediaType "text/plain"
        })
        $stageReceipts.Add([ordered]@{
            index = 6
            name = "cold_build"
            duration_s = [double]$buildRun.duration_s
            log = $buildRun.log
            cas = Publish-R24D9Artifact -Path $buildLog -MediaType "text/plain"
        })
        $sourceAfterBuild = Assert-R24D9RepositoryBoundary
        Assert-R24D9Supervisor ([string]$sourceAfterBuild.head -ceq $head) (
            "source_drift_during_cold_build"
        )
        [void](Assert-R24D9GodotSourceBoundary)

        $consoleSource = Join-Path $godotRoot (
            "bin\godot.windows.editor.dev.x86_64.console.exe"
        )
        $engineSource = Join-Path $godotRoot (
            "bin\godot.windows.editor.dev.x86_64.exe"
        )
        Assert-R24D9Supervisor (
            (Test-Path -LiteralPath $consoleSource -PathType Leaf) -and
            (Test-Path -LiteralPath $engineSource -PathType Leaf)
        ) "cold_binary_pair_missing"
        $artifactRoot = Join-Path $runRoot "artifacts"
        [void][IO.Directory]::CreateDirectory($artifactRoot)
        $consolePath = Join-Path $artifactRoot (Split-Path -Leaf $consoleSource)
        $enginePath = Join-Path $artifactRoot (Split-Path -Leaf $engineSource)
        Copy-Item -LiteralPath $consoleSource -Destination $consolePath
        Copy-Item -LiteralPath $engineSource -Destination $enginePath
        $consoleReceipt = Get-R24D9FileReceipt $consolePath
        $engineReceipt = Get-R24D9FileReceipt $enginePath
        Assert-R24D9Supervisor (
            [string]$consoleReceipt.raw_sha256 -ceq
                [string](Get-R24D9FileReceipt $consoleSource).raw_sha256 -and
            [string]$engineReceipt.raw_sha256 -ceq
                [string](Get-R24D9FileReceipt $engineSource).raw_sha256
        ) "retained_binary_pair_copy"
        $consoleCas = Publish-R24D9Artifact `
            -Path $consolePath `
            -MediaType "application/vnd.microsoft.portable-executable"
        $engineCas = Publish-R24D9Artifact `
            -Path $enginePath `
            -MediaType "application/vnd.microsoft.portable-executable"

        $nonce = [Guid]::NewGuid().ToString("N")
        $templatePath = Join-Path $runRoot "zero-world-template.json"
        $templateLog = Join-Path $runRoot "07-zero-world-template.log"
        $templateRun = Invoke-R24D9Checked `
            -FileName $pythonPath `
            -Arguments @(
                (Get-R24D9Path $evaluatorRelative),
                "--emit-zero-world-template", $templatePath,
                "--expected-source-commit", $head,
                "--expected-nonce", $nonce
            ) `
            -WorkingDirectory $repoRoot `
            -Label "R24D9 evaluator-shaped zero-world template" `
            -LogPath $templateLog
        $stageReceipts.Add([ordered]@{
            index = 7
            name = "evaluator_shaped_zero_world_template"
            duration_s = [double]$templateRun.duration_s
            log = $templateRun.log
            cas = Publish-R24D9Artifact -Path $templateLog -MediaType "text/plain"
        })
        $projectRoot = Join-Path $runRoot "project"
        [void][IO.Directory]::CreateDirectory($projectRoot)
        New-R24D9Project -ProjectRoot $projectRoot -TemplatePath $templatePath
        $rawPath = Join-Path $runRoot "synthetic-raw-report.json"
        $worker = Invoke-R24D9Worker `
            -ConsolePath $consolePath `
            -ProjectRoot $projectRoot `
            -RunRoot $runRoot `
            -WorkerMode "zero_world_preflight" `
            -Nonce $nonce `
            -Head $head `
            -ReportPath $rawPath
        $workerReceipt = (Get-R24D9Marker `
            -Lines $worker.stdout_lines `
            -Prefix $zeroWorkerPrefix `
            -Code "zero_worker") |
            ConvertFrom-Json -AsHashtable -Depth 100
        Assert-R24D9Supervisor (
            [bool]$workerReceipt.ok -and
            [bool]$workerReceipt.engine_freeze_matches -and
            [bool]$workerReceipt.fixture_description_matches -and
            [bool]$workerReceipt.invalid_rid_refused -and
            [bool]$workerReceipt.template_identity_matches -and
            [bool]$workerReceipt.template_byte_passthrough -and
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
        $evaluationLog = Join-Path $runRoot "08-synthetic-evaluation.log"
        $evaluation = Invoke-R24D9Evaluation `
            -PythonPath $pythonPath `
            -InputPath $rawPath `
            -OutputPath $evaluationPath `
            -SourceCommit $head `
            -Nonce $nonce `
            -EvidenceKind "synthetic_zero_world" `
            -LogPath $evaluationLog
        Assert-R24D9Supervisor (
            [bool]$evaluation.receipt.ok -and
            [string]$evaluation.receipt.result -ceq
                "synthetic_shape_conforms_zero_world_only" -and
            [int]$evaluation.receipt.summary.cell_count -eq 9 -and
            [int]$evaluation.receipt.summary.retained_sample_count -eq 68 -and
            -not [bool]$evaluation.receipt.native_numerical_telemetry_characterized -and
            -not [bool]$evaluation.receipt.physical_acceptance_authority -and
            -not [bool]$evaluation.receipt.release_authority
        ) "zero_evaluation_receipt"

        $rawReceipt = Get-R24D9FileReceipt $rawPath
        $rawCas = Publish-R24D9Artifact -Path $rawPath
        $evaluationCas = Publish-R24D9Artifact -Path $evaluationPath
        $evaluationLogCas = Publish-R24D9Artifact `
            -Path $evaluationLog `
            -MediaType "text/plain"
        $templateReceipt = Get-R24D9FileReceipt $templatePath
        $templateCas = Publish-R24D9Artifact -Path $templatePath
        $stdoutCas = Publish-R24D9Artifact `
            -Path ([string]$worker.stdout.path) `
            -MediaType "text/plain"
        $stderrCas = Publish-R24D9Artifact `
            -Path ([string]$worker.stderr.path) `
            -MediaType "text/plain"
        $engineLogCas = Publish-R24D9Artifact `
            -Path ([string]$worker.engine_log.path) `
            -MediaType "text/plain"
        Assert-R24D9Supervisor (
            [string](Get-R24D9FileReceipt $consolePath).raw_sha256 -ceq
                [string]$consoleReceipt.raw_sha256 -and
            [string](Get-R24D9FileReceipt $enginePath).raw_sha256 -ceq
                [string]$engineReceipt.raw_sha256
        ) "retained_binary_pair_drift"
        $sourceAfterZero = Assert-R24D9RepositoryBoundary
        Assert-R24D9Supervisor ([string]$sourceAfterZero.head -ceq $head) (
            "source_drift_during_zero_world_runtime"
        )
        [void](Assert-R24D9GodotSourceBoundary)

        $receipt = [ordered]@{
            schema_version = (
                "sporespore_qsdk_r24d9_one_hinge_numerical_telemetry_zero_world_receipt_v1"
            )
            ok = $true
            gate_id = "QSDK-R24D9"
            question_class = "development"
            status = (
                "complete_zero_world_gate_passed_physical_execution_separately_authorized"
            )
            source = $source
            godot_source = $godotSource
            validation_manifest = $manifestReceipt
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
                template = $templateReceipt
                template_cas = $templateCas
                declared_world_count = 1
                declared_solver_step_count = 20
                declared_retained_sample_count = 68
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
                physical_characterization_executed = $false
                native_numerical_telemetry_characterized = $false
                numerical_accuracy_accepted = $false
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
        Write-R24D9Json -Path $receiptPath -Value $receipt
        $receiptFile = Get-R24D9FileReceipt $receiptPath
        $receiptCas = Publish-R24D9Artifact -Path $receiptPath
        Write-Output (
            "QSDK_R24D9_NUMERICAL_TELEMETRY_ZERO_WORLD_GATE " +
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

    Assert-R24D9Supervisor ($RunPhysical) "explicit_run_physical_switch_required"
    Assert-R24D9Supervisor ($AuthorizationCommit -ceq $head) "authorization_commit"
    Assert-R24D9Supervisor (-not [string]::IsNullOrWhiteSpace($ZeroWorldReceiptPath)) (
        "zero_world_receipt_path_required"
    )
    $zeroPath = [IO.Path]::GetFullPath($ZeroWorldReceiptPath)
    $campaignPrefix = $campaignRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    Assert-R24D9Supervisor (
        $zeroPath.StartsWith($campaignPrefix, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $zeroPath) -ceq "receipt.json"
    ) "zero_world_receipt_location"
    $zeroReceipt = Get-Content -Raw -LiteralPath $zeroPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D9ZeroReceipt `
        -Receipt $zeroReceipt `
        -Head $head `
        -ManifestReceipt $manifestReceipt
    $zeroReceiptFile = Get-R24D9FileReceipt $zeroPath
    $zeroCasDirectory = Join-Path (
        Join-Path $evidenceBase "artifacts\sha256"
    ) ([string]$zeroReceiptFile.raw_sha256).Substring(7)
    Assert-R24D9Supervisor (
        Test-SporeSporeStoredArtifact `
            -Directory $zeroCasDirectory `
            -ExpectedSha256 ([string]$zeroReceiptFile.raw_sha256).Substring(7) `
            -ExpectedByteLength ([long]$zeroReceiptFile.byte_length)
    ) "zero_world_receipt_cas"
    $console = [hashtable]$zeroReceipt.binary_pair.console
    $engine = [hashtable]$zeroReceipt.binary_pair.engine
    $physicalRoot = Join-Path $campaignRoot "physical"
    $priorAttempts = @(Get-R24D9MatchingAttempts `
        -PhysicalRoot $physicalRoot `
        -SourceCommit $head `
        -ConsoleSha ([string]$console.raw_sha256) `
        -EngineSha ([string]$engine.raw_sha256))
    Assert-R24D9Supervisor ($priorAttempts.Count -eq 0) (
        "same_source_binary_pair_physical_attempt_already_consumed"
    )
    $runRoot = Join-Path $physicalRoot (
        "$stamp-$($head.Substring(0, 8))-$(([string]$console.raw_sha256).Substring(7, 12))"
    )
    Assert-R24D9Supervisor (-not (Test-Path -LiteralPath $runRoot)) "run_root_exists"
    [void][IO.Directory]::CreateDirectory($runRoot)
    $attemptPath = Join-Path $runRoot "attempt.json"
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_r24d9_physical_attempt_v1"
        gate_id = "QSDK-R24D9"
        question_class = "development"
        status = "consumed_before_worker_launch"
        source_commit = $head
        console_binary_sha256 = [string]$console.raw_sha256
        engine_binary_sha256 = [string]$engine.raw_sha256
        zero_world_receipt_sha256 = [string]$zeroReceiptFile.raw_sha256
        created_utc = [DateTimeOffset]::UtcNow.ToString("o")
        world_attempt_count = 1
        world_build_count = 0
        solver_step_count = 0
        worker_launch_count = 0
        same_source_rerun_allowed = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-R24D9Json -Path $attemptPath -Value $attempt
    [void](Publish-R24D9Artifact -Path $attemptPath)

    $stageDefinitions = @(
        [ordered]@{
            name = "r24d9_declaration_recheck"
            file = "pwsh"
            arguments = @(
                "-NoLogo", "-NoProfile", "-File",
                (Get-R24D9Path $declarationAuditRelative)
            )
        },
        [ordered]@{
            name = "immutable_r24d8_closure_recheck"
            file = "pwsh"
            arguments = @(
                "-NoLogo", "-NoProfile", "-File",
                (Get-R24D9Path $parentClosureAuditRelative),
                "-GodotRepositoryRoot", $godotRoot
            )
        },
        [ordered]@{
            name = "r24d9_freeze_recheck"
            file = "pwsh"
            arguments = @(
                "-NoLogo", "-NoProfile", "-File",
                (Get-R24D9Path $freezeAuditRelative),
                "-Python", $pythonPath,
                "-GodotSourceRoot", $godotRoot
            )
        }
    )
    $stageReceipts = [Collections.Generic.List[object]]::new()
    $stageIndex = 0
    foreach ($stage in $stageDefinitions) {
        $stageIndex += 1
        $logPath = Join-Path $runRoot (
            "{0:d2}-{1}.log" -f $stageIndex, [string]$stage.name
        )
        $stageRun = Invoke-R24D9Checked `
            -FileName (Resolve-R24D9Application ([string]$stage.file)) `
            -Arguments @($stage.arguments) `
            -WorkingDirectory $repoRoot `
            -Label ([string]$stage.name) `
            -LogPath $logPath
        $stageReceipts.Add([ordered]@{
            index = $stageIndex
            name = [string]$stage.name
            duration_s = [double]$stageRun.duration_s
            log = $stageRun.log
            cas = Publish-R24D9Artifact -Path $logPath -MediaType "text/plain"
        })
    }
    $sourceBeforeLaunch = Assert-R24D9RepositoryBoundary
    Assert-R24D9Supervisor ([string]$sourceBeforeLaunch.head -ceq $head) (
        "source_drift_before_physical_worker"
    )
    [void](Assert-R24D9GodotSourceBoundary)

    $projectRoot = Join-Path $runRoot "project"
    [void][IO.Directory]::CreateDirectory($projectRoot)
    New-R24D9Project -ProjectRoot $projectRoot
    $nonce = [Guid]::NewGuid().ToString("N")
    $rawPath = Join-Path $runRoot "raw-report.json"
    $attempt.worker_launch_count = 1
    Write-R24D9Json -Path $attemptPath -Value $attempt
    $worker = Invoke-R24D9Worker `
        -ConsolePath ([string]$console.path) `
        -ProjectRoot $projectRoot `
        -RunRoot $runRoot `
        -WorkerMode "physical" `
        -Nonce $nonce `
        -Head $head `
        -ReportPath $rawPath
    $workerReceipt = (Get-R24D9Marker `
        -Lines $worker.stdout_lines `
        -Prefix $physicalWorkerPrefix `
        -Code "physical_worker") |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D9Supervisor (
        [bool]$workerReceipt.ok -and
        [int]$workerReceipt.world_attempt_count -eq 1 -and
        [int]$workerReceipt.world_build_count -eq 1 -and
        [int]$workerReceipt.solver_step_count -eq 20 -and
        [int]$workerReceipt.retained_sample_count -eq 68 -and
        -not [bool]$workerReceipt.physical_acceptance_authority -and
        -not [bool]$workerReceipt.release_authority
    ) "physical_worker_receipt"
    $evaluationPath = Join-Path $runRoot "evaluation.json"
    $evaluationLog = Join-Path $runRoot "04-evaluation.log"
    $evaluation = Invoke-R24D9Evaluation `
        -PythonPath $pythonPath `
        -InputPath $rawPath `
        -OutputPath $evaluationPath `
        -SourceCommit $head `
        -Nonce $nonce `
        -EvidenceKind "native_physical" `
        -LogPath $evaluationLog
    Assert-R24D9Supervisor (
        [bool]$evaluation.receipt.ok -and
        [string]$evaluation.receipt.result -ceq
            "complete_valid_finite_descriptive_native_numerical_characterization" -and
        [bool]$evaluation.receipt.native_numerical_telemetry_characterized -and
        -not [bool]$evaluation.receipt.numerical_accuracy_accepted -and
        -not [bool]$evaluation.receipt.instrumented_profile_promoted -and
        -not [bool]$evaluation.receipt.physical_acceptance_authority -and
        -not [bool]$evaluation.receipt.release_authority
    ) "physical_evaluation_receipt"
    $attempt.status = "complete_valid_finite_descriptive_development_result"
    $attempt.world_build_count = 1
    $attempt.solver_step_count = 20
    Write-R24D9Json -Path $attemptPath -Value $attempt
    $attemptFile = Get-R24D9FileReceipt $attemptPath
    $attemptCas = Publish-R24D9Artifact -Path $attemptPath
    $rawReceipt = Get-R24D9FileReceipt $rawPath
    $rawCas = Publish-R24D9Artifact -Path $rawPath
    $evaluationCas = Publish-R24D9Artifact -Path $evaluationPath
    $evaluationLogCas = Publish-R24D9Artifact `
        -Path $evaluationLog `
        -MediaType "text/plain"
    $receipt = [ordered]@{
        schema_version = (
            "sporespore_qsdk_r24d9_one_hinge_numerical_telemetry_physical_receipt_v1"
        )
        ok = $true
        gate_id = "QSDK-R24D9"
        question_class = "development"
        status = "complete_valid_finite_descriptive_development_result"
        source = $source
        godot_source = $godotSource
        validation_manifest = $manifestReceipt
        prerequisite_zero_world = [ordered]@{
            receipt = $zeroReceiptFile
            cas_verified = $true
        }
        binary_pair = $zeroReceipt.binary_pair
        attempt = [ordered]@{
            file = $attemptFile
            cas = $attemptCas
            same_source_rerun_allowed = $false
        }
        stages = @($stageReceipts)
        worker = [ordered]@{
            receipt = $workerReceipt
            raw_report = $rawReceipt
            raw_report_cas = $rawCas
            stdout = $worker.stdout
            stderr = $worker.stderr
            engine_log = $worker.engine_log
        }
        evaluation = [ordered]@{
            receipt = $evaluation.receipt
            file = $evaluation.output
            cas = $evaluationCas
            log = $evaluation.run.log
            log_cas = $evaluationLogCas
        }
        actual_counts = [ordered]@{
            world_attempt_count = 1
            world_build_count = 1
            solver_step_count = 20
            retained_sample_count = 68
        }
        claims = [ordered]@{
            native_numerical_telemetry_characterized = $true
            numerical_accuracy_accepted = $false
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
    Write-R24D9Json -Path $receiptPath -Value $receipt
    $receiptFile = Get-R24D9FileReceipt $receiptPath
    $receiptCas = Publish-R24D9Artifact -Path $receiptPath
    Write-Output (
        "QSDK_R24D9_NUMERICAL_TELEMETRY_PHYSICAL_RESULT " +
        ([ordered]@{
            ok = $true
            source_commit = $head
            receipt = $receiptFile
            receipt_cas = $receiptCas
            world_attempt_count = 1
            world_build_count = 1
            solver_step_count = 20
            retained_sample_count = 68
            same_source_rerun_allowed = $false
            numerical_accuracy_accepted = $false
            instrumented_profile_promoted = $false
            physical_acceptance_authority = $false
            release_authority = $false
        } | ConvertTo-Json -Depth 30 -Compress)
    )
} finally {
    if ($null -ne $operationLock) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $operationLock
    }
}

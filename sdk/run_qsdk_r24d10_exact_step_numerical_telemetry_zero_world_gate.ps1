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
$expectedPatchHash = (
    "9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c"
)
$manifestRelative = (
    "sdk/recovery/" +
    "r24d10_godot_jolt_exact_step_numerical_telemetry_validation_manifest.json"
)
$patchRelative = (
    "sdk/adapters/godot/engine_patches/" +
    "godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch"
)
$evaluatorRelative = (
    "sdk/recovery/" +
    "r24d10_godot_jolt_exact_step_numerical_telemetry_" +
    "characterization_evaluator.py"
)
$freezeAuditRelative = (
    "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_freeze.ps1"
)
$parentClosureAuditRelative = (
    "tests/test_qsdk_r24d9_one_hinge_numerical_telemetry_" +
    "physical_failure_closure.ps1"
)
$baseRigRelative = (
    "scripts/lab/rigs/" +
    "r24d9_godot_jolt_one_hinge_numerical_telemetry_rig.gd"
)
$rigRelative = (
    "scripts/lab/rigs/" +
    "r24d10_godot_jolt_exact_step_numerical_telemetry_rig.gd"
)
$baseWorkerRelative = (
    "tests/test_sdk_qsdk_r24d9_godot_jolt_one_hinge_" +
    "numerical_telemetry_worker.gd"
)
$workerRelative = (
    "tests/test_sdk_qsdk_r24d10_godot_jolt_exact_step_" +
    "numerical_telemetry_worker.gd"
)
$readyPrefix = "QSDK_R24D10_GODOT_SUPERVISOR_TERMINATION_READY "
$workerPrefix = "QSDK_R24D10_WORKER_ZERO_WORLD "
$evaluationPrefix = "QSDK_R24D10_EVALUATION_PASS "
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

function Assert-R24D10 {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) { throw "QSDK-R24D10 zero-world supervisor: $Code" }
}

function Get-R24D10Path {
    param([Parameter(Mandatory)][string]$Relative)
    return [IO.Path]::GetFullPath((Join-Path $repoRoot $Relative))
}

function Resolve-R24D10Application {
    param([Parameter(Mandatory)][string]$Command)
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R24D10 (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application_missing:$resolved"
        )
        return $resolved
    }
    $candidate = Get-Command -Name $Command -CommandType Application |
        Select-Object -First 1
    Assert-R24D10 ($null -ne $candidate) "application_missing:$Command"
    return [IO.Path]::GetFullPath([string]$candidate.Source)
}

function Get-R24D10Git {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    $output = @(& git -C $Root @Arguments 2>&1)
    Assert-R24D10 ($LASTEXITCODE -eq 0) (
        "git_$($Arguments -join '_'):$($output -join '|')"
    )
    return ($output -join "`n").Trim()
}

function Get-R24D10FileReceipt {
    param([Parameter(Mandatory)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    Assert-R24D10 (Test-Path -LiteralPath $full -PathType Leaf) (
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

function Write-R24D10Json {
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

function Publish-R24D10Artifact {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$MediaType = "application/json"
    )
    return Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot `
        -ArtifactPath $Path `
        -MediaType $MediaType
}

function Get-R24D10Marker {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines,
        [Parameter(Mandatory)][string]$Prefix,
        [Parameter(Mandatory)][string]$Code
    )
    $matches = @($Lines | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R24D10 ($matches.Count -eq 1) "$Code`_marker_count:$($matches.Count)"
    return ([string]$matches[0]).Substring($Prefix.Length)
}

function Invoke-R24D10Checked {
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
    Assert-R24D10 ($exitCode -eq 0) "$Label`:$($lines -join '|')"
    return [ordered]@{
        output = $lines
        duration_s = [Math]::Round(($finished - $started).TotalSeconds, 6)
        log = Get-R24D10FileReceipt $LogPath
    }
}

function Assert-R24D10RepositoryBoundary {
    $root = Get-R24D10Git -Root $repoRoot -Arguments @(
        "rev-parse", "--show-toplevel"
    )
    $remote = Get-R24D10Git -Root $repoRoot -Arguments @(
        "remote", "get-url", "origin"
    )
    $branch = Get-R24D10Git -Root $repoRoot -Arguments @(
        "branch", "--show-current"
    )
    $head = Get-R24D10Git -Root $repoRoot -Arguments @("rev-parse", "HEAD")
    $upstream = Get-R24D10Git -Root $repoRoot -Arguments @(
        "rev-parse", "@{upstream}"
    )
    $cached = Get-R24D10Git -Root $repoRoot -Arguments @(
        "rev-parse", "refs/remotes/origin/main"
    )
    $liveText = Get-R24D10Git -Root $repoRoot -Arguments @(
        "ls-remote", "--heads", "origin", "refs/heads/main"
    )
    $live = $liveText.Split("`t")[0]
    $status = Get-R24D10Git -Root $repoRoot -Arguments @(
        "status", "--short"
    )
    $worktreeText = Get-R24D10Git -Root $repoRoot -Arguments @(
        "worktree", "list", "--porcelain"
    )
    $worktrees = @($worktreeText -split "`r?`n" | Where-Object {
        $_.StartsWith("worktree ", [StringComparison]::Ordinal)
    })
    Assert-R24D10 (
        [IO.Path]::GetFullPath($root) -ceq $expectedRepoRoot -and
        $repoRoot -ceq $expectedRepoRoot
    ) "repository_root"
    Assert-R24D10 ($remote -ceq $expectedRepoRemote) "repository_remote"
    Assert-R24D10 ($branch -ceq "main") "branch"
    Assert-R24D10 ([string]::IsNullOrEmpty($status)) "dirty_worktree"
    Assert-R24D10 (
        $head -ceq $upstream -and $head -ceq $cached -and $head -ceq $live
    ) "local_upstream_cached_live_inequality"
    Assert-R24D10 ($worktrees.Count -eq 1) "worktree_count"
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

function Assert-R24D10GodotSourceBoundary {
    $root = Get-R24D10Git -Root $godotRoot -Arguments @(
        "rev-parse", "--show-toplevel"
    )
    $remote = Get-R24D10Git -Root $godotRoot -Arguments @(
        "remote", "get-url", "origin"
    )
    $head = Get-R24D10Git -Root $godotRoot -Arguments @("rev-parse", "HEAD")
    Assert-R24D10 ([IO.Path]::GetFullPath($root) -ceq $godotRoot) (
        "godot_source_root"
    )
    Assert-R24D10 ($remote -ceq $expectedGodotRemote) "godot_remote"
    Assert-R24D10 ($head -ceq $expectedGodotCommit) "godot_commit"
    $statusOutput = @(& git -C $godotRoot status --short 2>&1)
    Assert-R24D10 ($LASTEXITCODE -eq 0) "godot_status"
    $statusPaths = @($statusOutput | ForEach-Object {
        ([string]$_).Substring(3).Replace("\", "/")
    })
    Assert-R24D10 (
        (($statusPaths | Sort-Object) -join "|") -ceq
        (($expectedPatchedPaths | Sort-Object) -join "|")
    ) "godot_dirty_path_set"
    $patchPath = Get-R24D10Path $patchRelative
    $patchReceipt = Get-R24D10FileReceipt $patchPath
    Assert-R24D10 (
        [string]$patchReceipt.raw_sha256 -ceq "sha256:$expectedPatchHash"
    ) "patch_digest"
    $diffLines = @(& git -C $godotRoot diff --no-ext-diff 2>&1)
    Assert-R24D10 ($LASTEXITCODE -eq 0) "godot_diff"
    $diffText = (($diffLines -join "`n") + "`n").Replace("`r`n", "`n")
    $patchText = [IO.File]::ReadAllText($patchPath).
        Replace("`r`n", "`n").TrimEnd("`n") + "`n"
    Assert-R24D10 ($diffText -ceq $patchText) "godot_diff_patch_inequality"
    $reverse = @(
        & git -C $godotRoot apply --reverse --check --whitespace=error-all `
            $patchPath 2>&1
    )
    Assert-R24D10 ($LASTEXITCODE -eq 0) (
        "patch_reverse_check:$($reverse -join '|')"
    )
    return [ordered]@{
        root = $root.Replace("\", "/")
        remote = $remote
        commit = $head
        combined_patch = $patchReceipt
        patched_file_count = 10
        exact_external_diff_verified = $true
        reverse_apply_check_passed = $true
    }
}

function Assert-R24D10Manifest {
    param([Parameter(Mandatory)][string]$Head)
    $manifestPath = Get-R24D10Path $manifestRelative
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D10 (
        [string]$manifest.schema_version -ceq
            "sporespore_qsdk_r24d10_exact_step_numerical_telemetry_validation_manifest_v1" -and
        [string]$manifest.gate_id -ceq "QSDK-R24D10" -and
        [string]$manifest.question_class -ceq "development" -and
        [string]$manifest.status -ceq
            "prospective_exact_step_implementation_source_bytes_bound_zero_world_pending" -and
        [string]$manifest.godot_source_commit -ceq $expectedGodotCommit -and
        [string]$manifest.combined_patch_raw_sha256 -ceq
            "sha256:$expectedPatchHash" -and
        [int]$manifest.inherited_evaluator_negative_control_count -eq 46 -and
        [int]$manifest.new_exact_step_negative_control_count -eq 12 -and
        [int]$manifest.accepted_adverse_finite_outcome_count -eq 3 -and
        -not [bool]$manifest.includes_self -and
        [int]$manifest.official_zero_world_qualification_count -eq 0 -and
        [int]$manifest.world_attempt_count -eq 0 -and
        [int]$manifest.world_build_count -eq 0 -and
        [int]$manifest.solver_step_count -eq 0 -and
        [bool]$manifest.prospective_development_question_declared -and
        [bool]$manifest.exact_step_schedule_source_implemented -and
        [bool]$manifest.complete_zero_world_gate_source_implemented -and
        -not [bool]$manifest.complete_zero_world_gate_passed -and
        -not [bool]$manifest.physical_authorization -and
        -not [bool]$manifest.physical_characterization_executed -and
        -not [bool]$manifest.native_numerical_telemetry_characterized -and
        -not [bool]$manifest.numerical_accuracy_accepted -and
        -not [bool]$manifest.instrumented_profile_promoted -and
        -not [bool]$manifest.stock_godot_profile_promoted -and
        -not [bool]$manifest.recovery_world_opened -and
        -not [bool]$manifest.prone_to_standing_world_opened -and
        -not [bool]$manifest.turning_claim_changed -and
        -not [bool]$manifest.cross_engine_equivalence_claimed -and
        -not [bool]$manifest.q_sdk_r24_satisfied -and
        -not [bool]$manifest.physical_acceptance_authority -and
        -not [bool]$manifest.release_authority
    ) "validation_manifest_header"
    $bindings = @($manifest.source_bindings)
    Assert-R24D10 (
        $bindings.Count -eq [int]$manifest.source_binding_count
    ) "validation_manifest_binding_count"
    foreach ($binding in $bindings) {
        $relative = [string]$binding.path
        $path = Get-R24D10Path $relative
        $receipt = Get-R24D10FileReceipt $path
        $workingBlob = Get-R24D10Git -Root $repoRoot -Arguments @(
            "hash-object", $relative
        )
        $committedBlob = Get-R24D10Git -Root $repoRoot -Arguments @(
            "rev-parse", "$Head`:$relative"
        )
        Assert-R24D10 (
            [string]$binding.raw_sha256 -ceq [string]$receipt.raw_sha256 -and
            [long]$binding.byte_length -eq [long]$receipt.byte_length -and
            [string]$binding.git_blob_oid -ceq $workingBlob -and
            $committedBlob -ceq $workingBlob
        ) "validation_manifest_binding:$relative"
    }
    return [ordered]@{
        manifest = $manifest
        receipt = Get-R24D10FileReceipt $manifestPath
    }
}

function New-R24D10Project {
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
        Copy-Item -LiteralPath (Get-R24D10Path $relative) -Destination $destination
    }
    Copy-Item -LiteralPath $TemplatePath -Destination (
        Join-Path $ProjectRoot "zero_world_template.json"
    )
    $projectText = @'
; QSDK-R24D10 exact-step zero-world qualification.
config_version=5

[application]
config/name="qsdk-r24d10-exact-step-numerical-telemetry"
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

function Invoke-R24D10Worker {
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
        "--script", (
            "res://tests/" +
            "test_sdk_qsdk_r24d10_godot_jolt_exact_step_" +
            "numerical_telemetry_worker.gd"
        ),
        "--",
        "--mode=zero_world_preflight",
        "--nonce=$Nonce",
        "--source_commit=$Head",
        "--report_path=$ReportPath"
    )
    $environment = @{
        SPORESPORE_R24D10_SUPERVISED_TERMINATION = "1"
        SPORESPORE_R24D10_TERMINATION_NONCE = $Nonce
        SPORESPORE_R24D10_EXECUTION_NONCE = $Nonce
        SPORESPORE_R24D10_SOURCE_COMMIT = $Head
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
            "SPORESPORE_R24D10_EXECUTION_NONCE",
            "SPORESPORE_R24D10_SOURCE_COMMIT"
        ) `
        -TimeoutSeconds 180
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
    Assert-R24D10 (
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
    Assert-R24D10 ($errorLines.Count -eq 0) (
        "zero_worker_error_lines:$($errorLines -join '|')"
    )
    Assert-R24D10 (Test-Path -LiteralPath $ReportPath -PathType Leaf) (
        "zero_worker_report_missing"
    )
    return [ordered]@{
        result = $result
        stdout_lines = $stdoutLines
        stdout = Get-R24D10FileReceipt $stdoutPath
        stderr = Get-R24D10FileReceipt $stderrPath
        engine_log = Get-R24D10FileReceipt $engineLogPath
    }
}

function Get-R24D10PriorAttempts {
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
            throw "Unreadable retained R24D10 attempt: $($path.FullName)"
        }
    }
    return @($matches)
}

$operationLock = $null
$runRoot = ""
$attemptPath = ""
try {
    $operationLock = Enter-SporeSporeLocomotionOperationLock -Role "conformance"
    Assert-R24D10 ([bool]$operationLock.acquired) (
        "another_physical_or_conformance_workload_owns_the_lock"
    )
    Assert-R24D10 ($godotRoot -ceq $expectedGodotRoot) (
        "godot_source_root_substitution_forbidden"
    )
    Assert-R24D10 ($evidenceBase -ceq $expectedEvidenceRoot) (
        "evidence_root_substitution_forbidden"
    )
    Assert-R24D10 (
        -not $evidenceBase.StartsWith(
            $repoRoot + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        )
    ) "evidence_root_inside_repository"

    $source = Assert-R24D10RepositoryBoundary
    $head = [string]$source.head
    $godotSource = Assert-R24D10GodotSourceBoundary
    $pythonPath = Resolve-R24D10Application $Python
    $pwshPath = Resolve-R24D10Application "pwsh"
    $manifestResult = Assert-R24D10Manifest -Head $head
    $manifestReceipt = $manifestResult.receipt

    $campaignRoot = Join-Path $evidenceBase (
        "qsdk-r24d10-exact-step-numerical-telemetry\zero-world"
    )
    $prior = @(Get-R24D10PriorAttempts -CampaignRoot $campaignRoot -Head $head)
    Assert-R24D10 ($prior.Count -eq 0) (
        "same_source_zero_world_attempt_already_consumed:$($prior -join '|')"
    )
    $stamp = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
    $nonce = [Guid]::NewGuid().ToString("N")
    $runRoot = Join-Path $campaignRoot (
        "$stamp-$($head.Substring(0, 8))-$($nonce.Substring(0, 12))"
    )
    Assert-R24D10 (-not (Test-Path -LiteralPath $runRoot)) "run_root_exists"
    [void][IO.Directory]::CreateDirectory($runRoot)
    $attemptPath = Join-Path $runRoot "attempt.json"
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_r24d10_zero_world_attempt_v1"
        gate_id = "QSDK-R24D10"
        question_class = "development"
        status = "consumed_before_first_stage"
        source_commit = $head
        validation_manifest_sha256 = [string]$manifestReceipt.raw_sha256
        created_utc = [DateTimeOffset]::UtcNow.ToString("o")
        zero_world_attempt_count = 1
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        same_source_rerun_allowed = $false
        physical_authority = $false
        release_authority = $false
    }
    Write-R24D10Json -Path $attemptPath -Value $attempt
    [void](Publish-R24D10Artifact -Path $attemptPath)

    $stageReceipts = [Collections.Generic.List[object]]::new()
    $stageIndex = 0
    $staticStages = @(
        [ordered]@{
            name = "immutable_r24d9_failure_closure_recheck"
            file = $pwshPath
            arguments = @(
                "-NoLogo", "-NoProfile", "-File",
                (Get-R24D10Path $parentClosureAuditRelative)
            )
        },
        [ordered]@{
            name = "r24d10_manifest_freeze_and_parser_audit"
            file = $pwshPath
            arguments = @(
                "-NoLogo", "-NoProfile", "-File",
                (Get-R24D10Path $freezeAuditRelative),
                "-Python", $pythonPath,
                "-GodotSourceRoot", $godotRoot
            )
        }
    )
    foreach ($stage in $staticStages) {
        $stageIndex += 1
        $logPath = Join-Path $runRoot (
            "{0:d2}-{1}.log" -f $stageIndex, [string]$stage.name
        )
        $stageRun = Invoke-R24D10Checked `
            -FileName ([string]$stage.file) `
            -Arguments @($stage.arguments) `
            -WorkingDirectory $repoRoot `
            -Label ([string]$stage.name) `
            -LogPath $logPath
        $stageReceipts.Add([ordered]@{
            index = $stageIndex
            name = [string]$stage.name
            duration_s = [double]$stageRun.duration_s
            log = $stageRun.log
            cas = Publish-R24D10Artifact -Path $logPath -MediaType "text/plain"
        })
    }

    $stageIndex += 1
    $cleanLog = Join-Path $runRoot (
        "{0:d2}-independent_godot_cold_cleanup.log" -f $stageIndex
    )
    $cleanRun = Invoke-R24D10Checked `
        -FileName $pythonPath `
        -Arguments (@("-m", "SCons", "--clean") + $sconsArguments) `
        -WorkingDirectory $godotRoot `
        -Label "R24D10 pinned Godot cold cleanup" `
        -LogPath $cleanLog
    $stageReceipts.Add([ordered]@{
        index = $stageIndex
        name = "independent_godot_cold_cleanup"
        duration_s = [double]$cleanRun.duration_s
        log = $cleanRun.log
        cas = Publish-R24D10Artifact -Path $cleanLog -MediaType "text/plain"
    })

    $stageIndex += 1
    $buildLog = Join-Path $runRoot (
        "{0:d2}-independent_godot_cold_build.log" -f $stageIndex
    )
    $buildRun = Invoke-R24D10Checked `
        -FileName $pythonPath `
        -Arguments (@("-m", "SCons") + $sconsArguments) `
        -WorkingDirectory $godotRoot `
        -Label "R24D10 pinned Godot cold build" `
        -LogPath $buildLog
    $stageReceipts.Add([ordered]@{
        index = $stageIndex
        name = "independent_godot_cold_build"
        duration_s = [double]$buildRun.duration_s
        log = $buildRun.log
        cas = Publish-R24D10Artifact -Path $buildLog -MediaType "text/plain"
    })
    $sourceAfterBuild = Assert-R24D10RepositoryBoundary
    Assert-R24D10 ([string]$sourceAfterBuild.head -ceq $head) (
        "source_drift_during_cold_build"
    )
    [void](Assert-R24D10GodotSourceBoundary)

    $consoleSource = Join-Path $godotRoot (
        "bin\godot.windows.editor.dev.x86_64.console.exe"
    )
    $engineSource = Join-Path $godotRoot (
        "bin\godot.windows.editor.dev.x86_64.exe"
    )
    Assert-R24D10 (
        (Test-Path -LiteralPath $consoleSource -PathType Leaf) -and
        (Test-Path -LiteralPath $engineSource -PathType Leaf)
    ) "cold_binary_pair_missing"
    $artifactRoot = Join-Path $runRoot "artifacts"
    [void][IO.Directory]::CreateDirectory($artifactRoot)
    $consolePath = Join-Path $artifactRoot (Split-Path -Leaf $consoleSource)
    $enginePath = Join-Path $artifactRoot (Split-Path -Leaf $engineSource)
    Copy-Item -LiteralPath $consoleSource -Destination $consolePath
    Copy-Item -LiteralPath $engineSource -Destination $enginePath
    $consoleReceipt = Get-R24D10FileReceipt $consolePath
    $engineReceipt = Get-R24D10FileReceipt $enginePath
    Assert-R24D10 (
        [string]$consoleReceipt.raw_sha256 -ceq
            [string](Get-R24D10FileReceipt $consoleSource).raw_sha256 -and
        [string]$engineReceipt.raw_sha256 -ceq
            [string](Get-R24D10FileReceipt $engineSource).raw_sha256
    ) "retained_binary_pair_copy"
    $consoleCas = Publish-R24D10Artifact `
        -Path $consolePath `
        -MediaType "application/vnd.microsoft.portable-executable"
    $engineCas = Publish-R24D10Artifact `
        -Path $enginePath `
        -MediaType "application/vnd.microsoft.portable-executable"

    $stageIndex += 1
    $templatePath = Join-Path $runRoot "zero-world-template.json"
    $templateLog = Join-Path $runRoot (
        "{0:d2}-exact_step_zero_world_template.log" -f $stageIndex
    )
    $templateRun = Invoke-R24D10Checked `
        -FileName $pythonPath `
        -Arguments @(
            (Get-R24D10Path $evaluatorRelative),
            "--emit-zero-world-template", $templatePath,
            "--expected-source-commit", $head,
            "--expected-nonce", $nonce
        ) `
        -WorkingDirectory $repoRoot `
        -Label "R24D10 evaluator-shaped exact-step zero-world template" `
        -LogPath $templateLog
    $stageReceipts.Add([ordered]@{
        index = $stageIndex
        name = "exact_step_evaluator_shaped_zero_world_template"
        duration_s = [double]$templateRun.duration_s
        log = $templateRun.log
        cas = Publish-R24D10Artifact -Path $templateLog -MediaType "text/plain"
    })

    $projectRoot = Join-Path $runRoot "project"
    [void][IO.Directory]::CreateDirectory($projectRoot)
    New-R24D10Project -ProjectRoot $projectRoot -TemplatePath $templatePath
    $stageIndex += 1
    $rawPath = Join-Path $runRoot "synthetic-raw-report.json"
    $worker = Invoke-R24D10Worker `
        -ConsolePath $consolePath `
        -ProjectRoot $projectRoot `
        -RunRoot $runRoot `
        -Nonce $nonce `
        -Head $head `
        -ReportPath $rawPath
    $workerReceipt = (Get-R24D10Marker `
        -Lines $worker.stdout_lines `
        -Prefix $workerPrefix `
        -Code "zero_worker") |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D10 (
        [bool]$workerReceipt.ok -and
        [bool]$workerReceipt.engine_freeze_matches -and
        [bool]$workerReceipt.fixture_description_matches -and
        [bool]$workerReceipt.invalid_rid_refused -and
        [bool]$workerReceipt.template_shape_matches -and
        [bool]$workerReceipt.template_identity_matches -and
        [bool]$workerReceipt.template_byte_passthrough -and
        [bool]$workerReceipt.synthetic_report_written -and
        [double]$workerReceipt.active_physics_object_count -eq 0.0 -and
        [int]$workerReceipt.synthetic_first_retained_space_step_sequence -eq 1 -and
        [int]$workerReceipt.synthetic_last_retained_space_step_sequence -eq 20 -and
        [int]$workerReceipt.synthetic_pre_sample_physics_frame_count -eq 0 -and
        [int]$workerReceipt.world_attempt_count -eq 0 -and
        [int]$workerReceipt.world_build_count -eq 0 -and
        [int]$workerReceipt.solver_step_count -eq 0 -and
        -not [bool]$workerReceipt.physical_acceptance_authority -and
        -not [bool]$workerReceipt.release_authority
    ) "zero_worker_receipt"
    $workerLog = Join-Path $runRoot (
        "{0:d2}-custom_runtime_zero_object_worker.log" -f $stageIndex
    )
    [IO.File]::WriteAllText(
        $workerLog,
        [string]$worker.result.stdout,
        [Text.UTF8Encoding]::new($false)
    )
    $stageReceipts.Add([ordered]@{
        index = $stageIndex
        name = "custom_runtime_zero_object_worker"
        duration_s = [Math]::Round((
            [DateTimeOffset]::Parse([string]$worker.result.completed_utc) -
            [DateTimeOffset]::Parse([string]$worker.result.started_utc)
        ).TotalSeconds, 6)
        log = Get-R24D10FileReceipt $workerLog
        cas = Publish-R24D10Artifact -Path $workerLog -MediaType "text/plain"
    })

    $stageIndex += 1
    $evaluationPath = Join-Path $runRoot "synthetic-evaluation.json"
    $evaluationLog = Join-Path $runRoot (
        "{0:d2}-independent_exact_step_evaluation.log" -f $stageIndex
    )
    $evaluationRun = Invoke-R24D10Checked `
        -FileName $pythonPath `
        -Arguments @(
            (Get-R24D10Path $evaluatorRelative),
            "--input", $rawPath,
            "--output", $evaluationPath,
            "--expected-source-commit", $head,
            "--expected-nonce", $nonce,
            "--expected-evidence-kind", "synthetic_zero_world"
        ) `
        -WorkingDirectory $repoRoot `
        -Label "R24D10 independent exact-step synthetic evaluation" `
        -LogPath $evaluationLog
    $evaluationReceipt = (Get-R24D10Marker `
        -Lines $evaluationRun.output `
        -Prefix $evaluationPrefix `
        -Code "evaluation") |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D10 (
        [bool]$evaluationReceipt.ok -and
        [bool]$evaluationReceipt.execution_valid -and
        [string]$evaluationReceipt.result -ceq
            "synthetic_exact_step_shape_conforms_zero_world_only" -and
        [int]$evaluationReceipt.exact_step_execution.first_retained_space_step_sequence -eq 1 -and
        [int]$evaluationReceipt.exact_step_execution.last_retained_space_step_sequence -eq 20 -and
        [int]$evaluationReceipt.exact_step_execution.token_derived_physics_step_count -eq 20 -and
        [int]$evaluationReceipt.exact_step_execution.pre_sample_physics_frame_count -eq 0 -and
        -not [bool]$evaluationReceipt.native_numerical_telemetry_characterized -and
        -not [bool]$evaluationReceipt.physical_acceptance_authority -and
        -not [bool]$evaluationReceipt.release_authority
    ) "zero_evaluation_receipt"
    $stageReceipts.Add([ordered]@{
        index = $stageIndex
        name = "independent_exact_step_synthetic_evaluation"
        duration_s = [double]$evaluationRun.duration_s
        log = $evaluationRun.log
        cas = Publish-R24D10Artifact -Path $evaluationLog -MediaType "text/plain"
    })

    $sourceAfter = Assert-R24D10RepositoryBoundary
    Assert-R24D10 ([string]$sourceAfter.head -ceq $head) (
        "source_drift_during_zero_world_gate"
    )
    [void](Assert-R24D10GodotSourceBoundary)
    $rawReceipt = Get-R24D10FileReceipt $rawPath
    $rawCas = Publish-R24D10Artifact -Path $rawPath
    $evaluationFile = Get-R24D10FileReceipt $evaluationPath
    $evaluationCas = Publish-R24D10Artifact -Path $evaluationPath
    $templateReceipt = Get-R24D10FileReceipt $templatePath
    $templateCas = Publish-R24D10Artifact -Path $templatePath
    $stdoutCas = Publish-R24D10Artifact `
        -Path ([string]$worker.stdout.path) `
        -MediaType "text/plain"
    $stderrCas = Publish-R24D10Artifact `
        -Path ([string]$worker.stderr.path) `
        -MediaType "text/plain"
    $engineLogCas = Publish-R24D10Artifact `
        -Path ([string]$worker.engine_log.path) `
        -MediaType "text/plain"

    $receipt = [ordered]@{
        schema_version = (
            "sporespore_qsdk_r24d10_exact_step_numerical_telemetry_" +
            "zero_world_receipt_v1"
        )
        ok = $true
        gate_id = "QSDK-R24D10"
        question_class = "development"
        status = (
            "complete_zero_world_gate_passed_physical_execution_still_forbidden_" +
            "pending_explicit_separate_authorization"
        )
        source = $source
        godot_source = $godotSource
        validation_manifest = $manifestReceipt
        operation_lock = Get-SporeSporeLocomotionOperationLockPublicReceipt `
            -Receipt $operationLock
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
            receipt = $evaluationReceipt
            file = $evaluationFile
            cas = $evaluationCas
            log = $evaluationRun.log
        }
        synthetic_shape = [ordered]@{
            template = $templateReceipt
            template_cas = $templateCas
            declared_world_count = 1
            declared_solver_step_count = 20
            declared_retained_sample_count = 68
            first_retained_space_step_sequence = 1
            last_retained_space_step_sequence = 20
            pre_sample_physics_frame_count = 0
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
            exact_step_schedule_source_qualified = $true
            physical_characterization_executed = $false
            native_numerical_telemetry_characterized = $false
            numerical_accuracy_accepted = $false
            instrumented_profile_promoted = $false
            recovery_world_opened = $false
            prone_to_standing_world_opened = $false
            turning_claim_changed = $false
            cross_engine_equivalence_claimed = $false
            physical_authorization = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
    }
    $receiptPath = Join-Path $runRoot "receipt.json"
    Write-R24D10Json -Path $receiptPath -Value $receipt
    $receiptFile = Get-R24D10FileReceipt $receiptPath
    $receiptCas = Publish-R24D10Artifact -Path $receiptPath
    Write-Output (
        "QSDK_R24D10_EXACT_STEP_ZERO_WORLD_GATE " +
        ([ordered]@{
            ok = $true
            source_commit = $head
            receipt = $receiptFile
            receipt_cas = $receiptCas
            run_root = $runRoot.Replace("\", "/")
            stage_count = $stageReceipts.Count
            console_sha256 = [string]$consoleReceipt.raw_sha256
            engine_sha256 = [string]$engineReceipt.raw_sha256
            world_attempt_count = 0
            world_build_count = 0
            solver_step_count = 0
            physical_authorization = $false
            physical_acceptance_authority = $false
            release_authority = $false
        } | ConvertTo-Json -Depth 30 -Compress)
    )
} catch {
    if (-not [string]::IsNullOrWhiteSpace($runRoot) -and (
        Test-Path -LiteralPath $runRoot -PathType Container
    )) {
        $failurePath = Join-Path $runRoot "terminal-failure.json"
        if (-not (Test-Path -LiteralPath $failurePath)) {
            Write-R24D10Json -Path $failurePath -Value ([ordered]@{
                schema_version = "sporespore_qsdk_r24d10_zero_world_failure_v1"
                gate_id = "QSDK-R24D10"
                question_class = "development"
                status = "consumed_zero_world_attempt_failed"
                failure = [string]$_.Exception.Message
                observed_utc = [DateTimeOffset]::UtcNow.ToString("o")
                world_attempt_count = 0
                world_build_count = 0
                solver_step_count = 0
                same_source_rerun_allowed = $false
                physical_authority = $false
                release_authority = $false
            })
            try { [void](Publish-R24D10Artifact -Path $failurePath) } catch {}
        }
    }
    throw
} finally {
    if ($null -ne $operationLock) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $operationLock
    }
}

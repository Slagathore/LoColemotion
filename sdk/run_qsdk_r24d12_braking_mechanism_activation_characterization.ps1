#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet("Preflight", "Authorization", "Physical")]
    [string]$Mode = "Preflight",
    [switch]$RunPhysical,
    [string]$QualificationReceiptPath = "",
    [string]$AuthorizationPath = "",
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
$expectedZeroWorldSource = "7b807819a6ed1d1864f5a5410bbb9b17667624e1"
$expectedZeroWorldReceiptHash = (
    "sha256:f8fd379f95f89197b1742efeeed41b55d0c71948634aaaf6d7a62d661f3aeb77"
)
$expectedZeroWorldReceiptBytes = 20588L
$expectedZeroWorldRunRoot = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "qsdk-r24d12-braking-mechanism-activation\zero-world\" +
    "20260826T220001659Z-7b807819-1c77888f5b1c"
)
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
$supervisorContractRelative = (
    "sdk/recovery/" +
    "r24d12_godot_jolt_braking_mechanism_activation_" +
    "physical_supervisor_contract_v1.json"
)
$supervisorManifestRelative = (
    "sdk/recovery/" +
    "r24d12_godot_jolt_braking_mechanism_activation_" +
    "physical_supervisor_manifest_v1.json"
)
$qualificationClosureRelative = (
    "sdk/recovery/" +
    "r24d12_godot_jolt_braking_mechanism_activation_" +
    "physical_supervisor_qualification_positive_closure_v1.json"
)
$authorizationRelative = (
    "sdk/recovery/" +
    "r24d12_godot_jolt_braking_mechanism_activation_" +
    "physical_authorization_v1.json"
)
$zeroWorldClosureRelative = (
    "sdk/recovery/" +
    "r24d12_godot_jolt_braking_mechanism_activation_" +
    "zero_world_positive_closure_v1.json"
)
$zeroWorldClosureAuditRelative = (
    "tests/test_qsdk_r24d12_braking_mechanism_activation_" +
    "zero_world_positive_closure.py"
)
$sourceAuditRelative = (
    "tests/test_qsdk_r24d12_braking_mechanism_activation_" +
    "physical_supervisor_source.py"
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
$zeroWorkerPrefix = "QSDK_R24D12_WORKER_ZERO_WORLD "
$physicalWorkerPrefix = "QSDK_R24D12_PHYSICAL_RAW_REPORT "

. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")
. (Join-Path $sdkRoot "godot_receipt_terminated_process.ps1")
. (Join-Path $sdkRoot "content_addressed_artifact_store.ps1")

function Assert-R24D12 {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) {
        throw "QSDK-R24D12 physical supervisor: $Code"
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
        [string]$TemplatePath = ""
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
    if (-not [string]::IsNullOrWhiteSpace($TemplatePath)) {
        Copy-Item -LiteralPath $TemplatePath -Destination (
            Join-Path $ProjectRoot "zero_world_template.json"
        )
    }
    $projectText = @'
; QSDK-R24D12 bounded braking-mechanism production route.
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
        [Parameter(Mandatory)][ValidateSet("zero_world_preflight", "physical")]
        [string]$WorkerMode,
        [Parameter(Mandatory)][string]$Nonce,
        [Parameter(Mandatory)][string]$Head,
        [Parameter(Mandatory)][string]$ReportPath
    )
    $engineLogPath = Join-Path $RunRoot "godot-$WorkerMode-engine.log"
    $arguments = @(
        "--headless",
        "--path", $ProjectRoot,
        "--log-file", $engineLogPath,
        "--script", ("res://" + $workerRelative),
        "--",
        "--mode=$WorkerMode",
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
    Assert-R24D12 (
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
    Assert-R24D12 ($errorLines.Count -eq 0) (
        "worker_$WorkerMode`_error_lines:$($errorLines -join '|')"
    )
    Assert-R24D12 (Test-Path -LiteralPath $ReportPath -PathType Leaf) (
        "worker_$WorkerMode`_report_missing"
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

function Assert-R24D12SupervisorManifest {
    param([Parameter(Mandatory)][string]$Head)
    $path = Get-R24D12Path $supervisorManifestRelative
    $manifest = Get-Content -Raw -LiteralPath $path |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D12 (
        [string]$manifest.schema_version -ceq
            "sporespore_qsdk_r24d12_physical_supervisor_manifest_v1" -and
        [string]$manifest.gate_id -ceq "QSDK-R24D12" -and
        [string]$manifest.question_class -ceq "development" -and
        [string]$manifest.status -ceq
            "prospective_physical_supervisor_v1_parent_bound_source_frozen_preflight_pending" -and
        -not [bool]$manifest.includes_self -and
        [string]$manifest.zero_world_source_commit -ceq $expectedZeroWorldSource -and
        [string]$manifest.zero_world_receipt_raw_sha256 -ceq
            $expectedZeroWorldReceiptHash -and
        [string]$manifest.executed_console_binary_raw_sha256 -ceq
            "sha256:$expectedConsoleHash" -and
        [string]$manifest.executed_engine_binary_raw_sha256 -ceq
            "sha256:$expectedEngineHash" -and
        [int]$manifest.declared_world_count -eq 1 -and
        [int]$manifest.declared_cell_count -eq 4 -and
        [int]$manifest.declared_solver_step_count -eq 1 -and
        [int]$manifest.declared_retained_sample_count -eq 4 -and
        [int]$manifest.declared_preflight_stage_count -eq 6 -and
        [int]$manifest.threshold_count -eq 0 -and
        [int]$manifest.margin_count -eq 0 -and
        [int]$manifest.held_out_cohort_count -eq 0 -and
        [int]$manifest.population_claim_count -eq 0 -and
        -not [bool]$manifest.preflight_passed -and
        -not [bool]$manifest.physical_authorization -and
        -not [bool]$manifest.physical_characterization_executed -and
        -not [bool]$manifest.physical_acceptance_authority -and
        -not [bool]$manifest.release_authority
    ) "supervisor_manifest_header"
    $bindings = @($manifest.source_bindings)
    Assert-R24D12 (
        $bindings.Count -eq [int]$manifest.source_binding_count
    ) "supervisor_manifest_binding_count"
    foreach ($binding in $bindings) {
        $relative = [string]$binding.path
        $receipt = Get-R24D12FileReceipt (Get-R24D12Path $relative)
        $workingBlob = Get-R24D12Git -Root $repoRoot -Arguments @(
            "hash-object", $relative
        )
        $committedBlob = Get-R24D12Git -Root $repoRoot -Arguments @(
            "rev-parse", "$Head`:$relative"
        )
        Assert-R24D12 (
            [string]$binding.raw_sha256 -ceq [string]$receipt.raw_sha256 -and
            [long]$binding.byte_length -eq [long]$receipt.byte_length -and
            [string]$binding.git_blob_oid -ceq $workingBlob -and
            $workingBlob -ceq $committedBlob
        ) "supervisor_manifest_binding:$relative"
    }
    return [ordered]@{
        value = $manifest
        file = Get-R24D12FileReceipt $path
    }
}

function Assert-R24D12ZeroWorldClosure {
    $closurePath = Get-R24D12Path $zeroWorldClosureRelative
    $closure = Get-Content -Raw -LiteralPath $closurePath |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D12 (
        [string]$closure.schema_version -ceq
            "sporespore_qsdk_r24d12_braking_mechanism_activation_zero_world_positive_closure_v1" -and
        [string]$closure.gate_id -ceq "QSDK-R24D12" -and
        [string]$closure.question_class -ceq "development" -and
        [string]$closure.status -ceq
            "complete_zero_world_gate_passed_physical_execution_still_forbidden_pending_explicit_separate_authorization" -and
        [string]$closure.source.commit -ceq $expectedZeroWorldSource -and
        [bool]$closure.source.clean_pushed_before_qualification -and
        [bool]$closure.source.local_upstream_cached_live_equal_before_qualification -and
        [string]$closure.runtime_reuse.console_binary_raw_sha256 -ceq
            "sha256:$expectedConsoleHash" -and
        [long]$closure.runtime_reuse.console_binary_byte_length -eq 293376L -and
        [string]$closure.runtime_reuse.engine_binary_raw_sha256 -ceq
            "sha256:$expectedEngineHash" -and
        [long]$closure.runtime_reuse.engine_binary_byte_length -eq 188829184L -and
        [string]$closure.zero_world_qualification.run_root -ceq
            $expectedZeroWorldRunRoot.Replace("\", "/") -and
        [string]$closure.zero_world_qualification.receipt_raw_sha256 -ceq
            $expectedZeroWorldReceiptHash -and
        [long]$closure.zero_world_qualification.receipt_byte_length -eq
            $expectedZeroWorldReceiptBytes -and
        [int]$closure.zero_world_qualification.world_attempt_count -eq 0 -and
        [int]$closure.zero_world_qualification.world_build_count -eq 0 -and
        [int]$closure.zero_world_qualification.solver_step_count -eq 0 -and
        [bool]$closure.claims.complete_zero_world_gate_passed -and
        -not [bool]$closure.claims.physical_characterization_executed -and
        -not [bool]$closure.claims.physical_acceptance_authority -and
        -not [bool]$closure.claims.release_authority
    ) "zero_world_closure"
    $receiptPath = Join-Path $expectedZeroWorldRunRoot "receipt.json"
    $receipt = Get-R24D12FileReceipt $receiptPath
    Assert-R24D12 (
        [string]$receipt.raw_sha256 -ceq $expectedZeroWorldReceiptHash -and
        [long]$receipt.byte_length -eq $expectedZeroWorldReceiptBytes
    ) "zero_world_retained_receipt"
    $digest = ([string]$receipt.raw_sha256).Substring(7)
    Assert-R24D12 (
        Test-SporeSporeStoredArtifact `
            -Directory (Join-Path (
                Join-Path $evidenceBase "artifacts\sha256"
            ) $digest) `
            -ExpectedSha256 $digest `
            -ExpectedByteLength ([long]$receipt.byte_length)
    ) "zero_world_receipt_cas"
    return [ordered]@{
        value = $closure
        file = Get-R24D12FileReceipt $closurePath
        receipt = $receipt
    }
}

function Invoke-R24D12Evaluation {
    param(
        [Parameter(Mandatory)][string]$PythonPath,
        [Parameter(Mandatory)][string]$InputPath,
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][string]$SourceCommit,
        [Parameter(Mandatory)][string]$Nonce,
        [Parameter(Mandatory)][ValidateSet("synthetic_zero_world", "native_physical")]
        [string]$EvidenceKind,
        [Parameter(Mandatory)][string]$LogPath
    )
    $run = Invoke-R24D12Checked `
        -FileName $PythonPath `
        -Arguments @(
            (Get-R24D12Path $evaluatorRelative),
            "--input", $InputPath,
            "--output", $OutputPath,
            "--expected-source-commit", $SourceCommit,
            "--expected-nonce", $Nonce,
            "--expected-evidence-kind", $EvidenceKind
        ) `
        -WorkingDirectory $repoRoot `
        -Label "R24D12 $EvidenceKind evaluation" `
        -LogPath $LogPath
    return [ordered]@{
        run = $run
        value = Get-Content -Raw -LiteralPath $OutputPath |
            ConvertFrom-Json -AsHashtable -Depth 100
        file = Get-R24D12FileReceipt $OutputPath
    }
}

function Get-R24D12PriorFiles {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][scriptblock]$Match
    )
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        return @()
    }
    $matches = [Collections.Generic.List[string]]::new()
    foreach ($file in @(Get-ChildItem -LiteralPath $Root `
        -Filter $FileName -File -Recurse -ErrorAction Stop)) {
        try {
            $value = Get-Content -Raw -LiteralPath $file.FullName |
                ConvertFrom-Json -AsHashtable -Depth 100
            if (& $Match $value) { $matches.Add($file.FullName) }
        } catch {
            throw "Unreadable retained R24D12 record: $($file.FullName)"
        }
    }
    return @($matches)
}

function Assert-R24D12QualificationReceipt {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Manifest,
        [Parameter(Mandatory)][System.Collections.IDictionary]$ZeroWorld
    )
    $full = [IO.Path]::GetFullPath($Path)
    $root = Join-Path $evidenceBase (
        "qsdk-r24d12-braking-mechanism-activation\" +
        "physical-supervisor-qualification"
    )
    $prefix = $root.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    Assert-R24D12 (
        $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $full) -ceq "receipt.json"
    ) "qualification_receipt_location"
    $receipt = Get-Content -Raw -LiteralPath $full |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D12 (
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r24d12_physical_supervisor_qualification_receipt_v1" -and
        [bool]$receipt.ok -and
        [string]$receipt.gate_id -ceq "QSDK-R24D12" -and
        [string]$receipt.question_class -ceq "development" -and
        [string]$receipt.status -ceq
            "complete_physical_supervisor_preflight_passed_zero_world_only" -and
        [string]$receipt.validation_manifest.raw_sha256 -ceq
            [string]$Manifest.file.raw_sha256 -and
        [string]$receipt.prerequisite_zero_world.receipt.raw_sha256 -ceq
            [string]$ZeroWorld.receipt.raw_sha256 -and
        [string]$receipt.source.root -ceq $expectedRepoRoot.Replace("\", "/") -and
        [string]$receipt.source.remote -ceq $expectedRepoRemote -and
        [string]$receipt.source.branch -ceq "main" -and
        [string]$receipt.source.head -ceq [string]$receipt.source.upstream -and
        [string]$receipt.source.head -ceq
            [string]$receipt.source.cached_origin_main -and
        [string]$receipt.source.head -ceq [string]$receipt.source.live_origin_main -and
        [bool]$receipt.source.worktree_clean -and
        [string]$receipt.binary_pair.console.raw_sha256 -ceq
            "sha256:$expectedConsoleHash" -and
        [string]$receipt.binary_pair.engine.raw_sha256 -ceq
            "sha256:$expectedEngineHash" -and
        [bool]$receipt.binary_pair.executed_exact_qualified_pair -and
        [int]$receipt.actual_counts.world_attempt_count -eq 0 -and
        [int]$receipt.actual_counts.world_build_count -eq 0 -and
        [int]$receipt.actual_counts.solver_step_count -eq 0 -and
        [bool]$receipt.claims.physical_supervisor_preflight_passed -and
        -not [bool]$receipt.claims.physical_characterization_executed -and
        -not [bool]$receipt.claims.physical_acceptance_authority -and
        -not [bool]$receipt.claims.release_authority
    ) "qualification_receipt"
    $file = Get-R24D12FileReceipt $full
    $digest = ([string]$file.raw_sha256).Substring(7)
    Assert-R24D12 (
        Test-SporeSporeStoredArtifact `
            -Directory (Join-Path (
                Join-Path $evidenceBase "artifacts\sha256"
            ) $digest) `
            -ExpectedSha256 $digest `
            -ExpectedByteLength ([long]$file.byte_length)
    ) "qualification_receipt_cas"
    return [ordered]@{ value = $receipt; file = $file }
}

function Assert-R24D12QualificationClosure {
    param(
        [Parameter(Mandatory)][string]$Head,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Manifest,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Qualification
    )
    $path = Get-R24D12Path $qualificationClosureRelative
    $closure = Get-Content -Raw -LiteralPath $path |
        ConvertFrom-Json -AsHashtable -Depth 100
    $parentText = Get-R24D12Git -Root $repoRoot -Arguments @(
        "rev-list", "--parents", "-n", "1", $Head
    )
    $parts = @($parentText -split " " | Where-Object { $_ })
    Assert-R24D12 ($parts.Count -eq 2) (
        "authorization_commit_must_have_exactly_one_parent"
    )
    $parent = [string]$parts[1]
    $supervisorBlob = Get-R24D12Git -Root $repoRoot -Arguments @(
        "rev-parse", "$Head`:sdk/run_qsdk_r24d12_braking_mechanism_activation_characterization.ps1"
    )
    $manifestBlob = Get-R24D12Git -Root $repoRoot -Arguments @(
        "rev-parse", "$Head`:$supervisorManifestRelative"
    )
    Assert-R24D12 (
        [string]$closure.schema_version -ceq
            "sporespore_qsdk_r24d12_physical_supervisor_qualification_positive_closure_v1" -and
        [string]$closure.gate_id -ceq "QSDK-R24D12" -and
        [string]$closure.question_class -ceq "development" -and
        [string]$closure.status -ceq
            "complete_physical_supervisor_preflight_passed_zero_world_only_authorization_separate" -and
        [string]$closure.supervisor_freeze_commit -ceq $parent -and
        $parent -ceq [string]$Qualification.value.source.head -and
        [string]$closure.qualification_receipt_raw_sha256 -ceq
            [string]$Qualification.file.raw_sha256 -and
        [long]$closure.qualification_receipt_byte_length -eq
            [long]$Qualification.file.byte_length -and
        [string]$closure.validation_manifest_raw_sha256 -ceq
            [string]$Manifest.file.raw_sha256 -and
        [string]$closure.supervisor_git_blob_oid -ceq $supervisorBlob -and
        [string]$closure.supervisor_manifest_git_blob_oid -ceq $manifestBlob -and
        [bool]$closure.claims.physical_supervisor_preflight_passed -and
        -not [bool]$closure.claims.physical_authorization -and
        -not [bool]$closure.claims.physical_characterization_executed -and
        -not [bool]$closure.claims.physical_acceptance_authority -and
        -not [bool]$closure.claims.release_authority
    ) "qualification_closure"
    $workingBlob = Get-R24D12Git -Root $repoRoot -Arguments @(
        "hash-object", $qualificationClosureRelative
    )
    $committedBlob = Get-R24D12Git -Root $repoRoot -Arguments @(
        "rev-parse", "$Head`:$qualificationClosureRelative"
    )
    Assert-R24D12 ($workingBlob -ceq $committedBlob) (
        "qualification_closure_uncommitted"
    )
    return [ordered]@{
        value = $closure
        file = Get-R24D12FileReceipt $path
        git_blob_oid = $workingBlob
        authorization_parent_commit = $parent
    }
}

function Assert-R24D12PhysicalAuthorization {
    param(
        [Parameter(Mandatory)][string]$Head,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Manifest,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Qualification,
        [Parameter(Mandatory)][System.Collections.IDictionary]$QualificationClosure,
        [Parameter(Mandatory)][System.Collections.IDictionary]$ZeroWorld
    )
    $full = [IO.Path]::GetFullPath($Path)
    Assert-R24D12 ($full -ceq (Get-R24D12Path $authorizationRelative)) (
        "authorization_path"
    )
    $authorization = Get-Content -Raw -LiteralPath $full |
        ConvertFrom-Json -AsHashtable -Depth 100
    $parent = [string]$QualificationClosure.authorization_parent_commit
    $parentSupervisorBlob = Get-R24D12Git -Root $repoRoot -Arguments @(
        "rev-parse", "$parent`:sdk/run_qsdk_r24d12_braking_mechanism_activation_characterization.ps1"
    )
    $currentSupervisorBlob = Get-R24D12Git -Root $repoRoot -Arguments @(
        "rev-parse", "$Head`:sdk/run_qsdk_r24d12_braking_mechanism_activation_characterization.ps1"
    )
    $parentManifestBlob = Get-R24D12Git -Root $repoRoot -Arguments @(
        "rev-parse", "$parent`:$supervisorManifestRelative"
    )
    $currentManifestBlob = Get-R24D12Git -Root $repoRoot -Arguments @(
        "rev-parse", "$Head`:$supervisorManifestRelative"
    )
    Assert-R24D12 (
        [string]$authorization.schema_version -ceq
            "sporespore_qsdk_r24d12_physical_authorization_v1" -and
        [string]$authorization.gate_id -ceq "QSDK-R24D12" -and
        [string]$authorization.question_class -ceq "development" -and
        [string]$authorization.status -ceq
            "authorized_one_bounded_native_development_attempt_parent_bound" -and
        -not $authorization.Contains("authorization_commit") -and
        [bool]$authorization.authorization_commit_derived_from_current_head -and
        [string]$authorization.authorization_parent_commit -ceq $parent -and
        [string]$authorization.supervisor_freeze_commit -ceq $parent -and
        $parentSupervisorBlob -ceq $currentSupervisorBlob -and
        [string]$authorization.supervisor_git_blob_oid -ceq
            $currentSupervisorBlob -and
        $parentManifestBlob -ceq $currentManifestBlob -and
        [string]$authorization.supervisor_manifest_git_blob_oid -ceq
            $currentManifestBlob -and
        [string]$authorization.supervisor_manifest_raw_sha256 -ceq
            [string]$Manifest.file.raw_sha256 -and
        [string]$authorization.qualification_receipt_raw_sha256 -ceq
            [string]$Qualification.file.raw_sha256 -and
        [string]$authorization.qualification_closure_raw_sha256 -ceq
            [string]$QualificationClosure.file.raw_sha256 -and
        [string]$authorization.prerequisite_zero_world_receipt_raw_sha256 -ceq
            [string]$ZeroWorld.receipt.raw_sha256 -and
        [string]$authorization.executed_console_binary_raw_sha256 -ceq
            "sha256:$expectedConsoleHash" -and
        [string]$authorization.executed_engine_binary_raw_sha256 -ceq
            "sha256:$expectedEngineHash" -and
        [int]$authorization.physical_attempt_limit -eq 1 -and
        -not [bool]$authorization.same_source_rerun_allowed -and
        [int]$authorization.world_count -eq 1 -and
        [int]$authorization.fixture_cell_count -eq 4 -and
        [int]$authorization.solver_step_count -eq 1 -and
        [int]$authorization.retained_sample_count -eq 4 -and
        [int]$authorization.threshold_count -eq 0 -and
        [int]$authorization.margin_count -eq 0 -and
        [int]$authorization.held_out_cohort_count -eq 0 -and
        [int]$authorization.population_claim_count -eq 0 -and
        [bool]$authorization.physical_execution_authorized -and
        -not [bool]$authorization.numerical_accuracy_accepted -and
        -not [bool]$authorization.instrumented_profile_promoted -and
        -not [bool]$authorization.physical_acceptance_authority -and
        -not [bool]$authorization.release_authority
    ) "physical_authorization"
    $workingBlob = Get-R24D12Git -Root $repoRoot -Arguments @(
        "hash-object", $authorizationRelative
    )
    $committedBlob = Get-R24D12Git -Root $repoRoot -Arguments @(
        "rev-parse", "$Head`:$authorizationRelative"
    )
    Assert-R24D12 ($workingBlob -ceq $committedBlob) "authorization_uncommitted"
    return [ordered]@{
        value = $authorization
        file = Get-R24D12FileReceipt $full
        git_blob_oid = $workingBlob
    }
}

$operationLock = $null
$runRoot = ""
$attemptPath = ""
$attempt = $null
try {
    $lockRole = if ($Mode -ceq "Physical") { "physical" } else { "conformance" }
    $operationLock = Enter-SporeSporeLocomotionOperationLock -Role $lockRole
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
    $manifestReceipt = Assert-R24D12SupervisorManifest -Head $head
    $zeroWorld = Assert-R24D12ZeroWorldClosure
    $runtimeReuse = Assert-R24D12RuntimeReuseKey

    if ($Mode -ceq "Preflight") {
        Assert-R24D12 (-not $RunPhysical) "physical_switch_in_preflight"
        Assert-R24D12 ([string]::IsNullOrWhiteSpace($QualificationReceiptPath)) (
            "qualification_receipt_forbidden_in_preflight"
        )
        Assert-R24D12 ([string]::IsNullOrWhiteSpace($AuthorizationPath)) (
            "authorization_forbidden_in_preflight"
        )
    $campaignRoot = Join-Path $evidenceBase (
        "qsdk-r24d12-braking-mechanism-activation\" +
        "physical-supervisor-qualification"
    )
    $prior = @(Get-R24D12PriorFiles `
        -Root $campaignRoot `
        -FileName "attempt.json" `
        -Match { param($value) [string]$value.source_commit -ceq $head })
    Assert-R24D12 ($prior.Count -eq 0) (
        "same_source_preflight_attempt_already_consumed:$($prior -join '|')"
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
        schema_version = "sporespore_qsdk_r24d12_physical_supervisor_preflight_attempt_v1"
        gate_id = "QSDK-R24D12"
        question_class = "development"
        status = "consumed_before_first_stage"
        source_commit = $head
        created_utc = [DateTimeOffset]::UtcNow.ToString("o")
        qualification_attempt_count = 1
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        same_source_rerun_allowed = $false
        physical_authorization = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-R24D12Json -Path $attemptPath -Value $attempt
    $attemptCas = Publish-R24D12Artifact -Path $attemptPath

    $stageReceipts = [Collections.Generic.List[object]]::new()
    $stageIndex = 1
    $freezeLog = Join-Path $runRoot "01-r24d12_supervisor_source_audit.log"
    $freezeRun = Invoke-R24D12Checked `
        -FileName $pythonPath `
        -Arguments @(
            (Get-R24D12Path $sourceAuditRelative),
            "--require-committed"
        ) `
        -WorkingDirectory $repoRoot `
        -Label "R24D12 physical supervisor source audit" `
        -LogPath $freezeLog
    $stageReceipts.Add([ordered]@{
        index = $stageIndex
        name = "r24d12_physical_supervisor_source_audit"
        duration_s = $freezeRun.duration_s
        log = $freezeRun.log
        cas = Publish-R24D12Artifact -Path $freezeLog -MediaType "text/plain"
    })

    $stageIndex += 1
    $zeroClosureLog = Join-Path $runRoot "02-r24d12_zero_world_closure_audit.log"
    $zeroClosureRun = Invoke-R24D12Checked `
        -FileName $pythonPath `
        -Arguments @((Get-R24D12Path $zeroWorldClosureAuditRelative)) `
        -WorkingDirectory $repoRoot `
        -Label "R24D12 immutable zero-world closure audit" `
        -LogPath $zeroClosureLog
    $stageReceipts.Add([ordered]@{
        index = $stageIndex
        name = "immutable_r24d12_zero_world_closure_audit"
        duration_s = $zeroClosureRun.duration_s
        log = $zeroClosureRun.log
        cas = Publish-R24D12Artifact -Path $zeroClosureLog -MediaType "text/plain"
    })

    $stageIndex += 1
    $selfTestLog = Join-Path $runRoot "03-r24d12_evaluator_self_test.log"
    $selfTestRun = Invoke-R24D12Checked `
        -FileName $pythonPath `
        -Arguments @((Get-R24D12Path $evaluatorRelative), "--self-test") `
        -WorkingDirectory $repoRoot `
        -Label "R24D12 evaluator self-test and negative controls" `
        -LogPath $selfTestLog
    $stageReceipts.Add([ordered]@{
        index = $stageIndex
        name = "r24d12_evaluator_self_test_and_negative_controls"
        duration_s = $selfTestRun.duration_s
        log = $selfTestRun.log
        cas = Publish-R24D12Artifact -Path $selfTestLog -MediaType "text/plain"
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
    $templateLog = Join-Path $runRoot "04-evaluator_shaped_zero_world_template.log"
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
        -WorkerMode "zero_world_preflight" `
        -Nonce $nonce `
        -Head $head `
        -ReportPath $rawPath
    $workerReceipt = (Get-R24D12Marker `
        -Lines $worker.stdout_lines `
        -Prefix $zeroWorkerPrefix `
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
    $workerLog = Join-Path $runRoot "05-custom_runtime_zero_object_worker.log"
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
    $evaluationLog = Join-Path $runRoot "06-independent_synthetic_evaluation.log"
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
        "source_drift_during_supervisor_preflight"
    )
    $rawReceipt = Get-R24D12FileReceipt $rawPath
    $evaluationReceipt = Get-R24D12FileReceipt $evaluationPath
    $templateReceipt = Get-R24D12FileReceipt $templatePath
    $receipt = [ordered]@{
        schema_version = "sporespore_qsdk_r24d12_physical_supervisor_qualification_receipt_v1"
        ok = $true
        gate_id = "QSDK-R24D12"
        question_class = "development"
        status = "complete_physical_supervisor_preflight_passed_zero_world_only"
        source = $source
        supervisor_contract = Get-R24D12FileReceipt (
            Get-R24D12Path $supervisorContractRelative
        )
        validation_manifest = $manifestReceipt.file
        prerequisite_zero_world = [ordered]@{
            closure = $zeroWorld.file
            receipt = $zeroWorld.receipt
            cas_verified = $true
        }
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
            executed_exact_qualified_pair = $true
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
            physical_supervisor_preflight_passed = $true
            complete_zero_world_gate_rechecked = $true
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
        same_source_preflight_rerun_allowed = $false
    }
    $receiptPath = Join-Path $runRoot "receipt.json"
    Write-R24D12Json -Path $receiptPath -Value $receipt
    $receiptFile = Get-R24D12FileReceipt $receiptPath
    $receiptCas = Publish-R24D12Artifact -Path $receiptPath
    Write-Output (
        "QSDK_R24D12_PHYSICAL_SUPERVISOR_PREFLIGHT_PASS " +
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
            physical_supervisor_preflight_passed = $true
            physical_authorization = $false
            release_authority = $false
        } | ConvertTo-Json -Compress)
    )
        return
    }

    if ($Mode -ceq "Physical") {
        Assert-R24D12 ($RunPhysical) "explicit_run_physical_switch_required"
    } else {
        Assert-R24D12 (-not $RunPhysical) (
            "physical_switch_forbidden_in_authorization_check"
        )
    }
    Assert-R24D12 (-not [string]::IsNullOrWhiteSpace($QualificationReceiptPath)) (
        "qualification_receipt_path_required"
    )
    if ([string]::IsNullOrWhiteSpace($AuthorizationPath)) {
        $AuthorizationPath = Get-R24D12Path $authorizationRelative
    }
    $qualification = Assert-R24D12QualificationReceipt `
        -Path $QualificationReceiptPath `
        -Manifest $manifestReceipt `
        -ZeroWorld $zeroWorld
    $qualificationClosure = Assert-R24D12QualificationClosure `
        -Head $head `
        -Manifest $manifestReceipt `
        -Qualification $qualification
    $authorization = Assert-R24D12PhysicalAuthorization `
        -Head $head `
        -Path $AuthorizationPath `
        -Manifest $manifestReceipt `
        -Qualification $qualification `
        -QualificationClosure $qualificationClosure `
        -ZeroWorld $zeroWorld

    $physicalRoot = Join-Path $evidenceBase (
        "qsdk-r24d12-braking-mechanism-activation\physical"
    )
    $priorPhysical = @(Get-R24D12PriorFiles `
        -Root $physicalRoot `
        -FileName "attempt.json" `
        -Match {
            param($value)
            [string]$value.authorization_commit -ceq $head -and
            [string]$value.console_binary_sha256 -ceq "sha256:$expectedConsoleHash" -and
            [string]$value.engine_binary_sha256 -ceq "sha256:$expectedEngineHash"
        })
    Assert-R24D12 ($priorPhysical.Count -eq 0) (
        "same_authorization_binary_pair_physical_attempt_already_consumed:" +
        ($priorPhysical -join "|")
    )

    if ($Mode -ceq "Authorization") {
        Write-Output (
            "QSDK_R24D12_PHYSICAL_AUTHORIZATION_CHECK_PASS " +
            ([ordered]@{
                ok = $true
                authorization_commit = $head
                authorization_parent_commit = (
                    [string]$authorization.value.authorization_parent_commit
                )
                qualification_receipt_sha256 = (
                    [string]$qualification.file.raw_sha256
                )
                qualification_closure_sha256 = (
                    [string]$qualificationClosure.file.raw_sha256
                )
                world_attempt_count = 0
                world_build_count = 0
                solver_step_count = 0
                physical_attempt_consumed = $false
                physical_acceptance_authority = $false
                release_authority = $false
            } | ConvertTo-Json -Depth 30 -Compress)
        )
        return
    }

    $stamp = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
    $nonce = [Guid]::NewGuid().ToString("N")
    $runRoot = Join-Path $physicalRoot (
        "$stamp-$($head.Substring(0, 8))-$($nonce.Substring(0, 12))"
    )
    Assert-R24D12 (-not (Test-Path -LiteralPath $runRoot)) "run_root_exists"
    [void][IO.Directory]::CreateDirectory($runRoot)
    $stageReceipts = [Collections.Generic.List[object]]::new()
    $stageIndex = 0
    $physicalStaticStages = @(
        [ordered]@{
            name = "r24d12_physical_supervisor_source_audit"
            file = $pythonPath
            arguments = @(
                (Get-R24D12Path $sourceAuditRelative), "--require-committed"
            )
        },
        [ordered]@{
            name = "immutable_r24d12_zero_world_closure_audit"
            file = $pythonPath
            arguments = @((Get-R24D12Path $zeroWorldClosureAuditRelative))
        },
        [ordered]@{
            name = "r24d12_evaluator_self_test_and_negative_controls"
            file = $pythonPath
            arguments = @((Get-R24D12Path $evaluatorRelative), "--self-test")
        }
    )
    foreach ($stage in $physicalStaticStages) {
        $stageIndex += 1
        $logPath = Join-Path $runRoot (
            "{0:d2}-{1}.log" -f $stageIndex, [string]$stage.name
        )
        $stageRun = Invoke-R24D12Checked `
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
            cas = Publish-R24D12Artifact -Path $logPath -MediaType "text/plain"
        })
    }

    $projectRoot = Join-Path $runRoot "project"
    [void][IO.Directory]::CreateDirectory($projectRoot)
    New-R24D12Project -ProjectRoot $projectRoot
    $sourceBeforeLaunch = Assert-R24D12RepositoryBoundary
    Assert-R24D12 ([string]$sourceBeforeLaunch.head -ceq $head) (
        "source_drift_before_physical_worker"
    )
    $runtimeBeforeLaunch = Assert-R24D12RuntimeReuseKey
    Assert-R24D12 (
        [string]$runtimeBeforeLaunch.console.raw_sha256 -ceq
            "sha256:$expectedConsoleHash" -and
        [string]$runtimeBeforeLaunch.engine.raw_sha256 -ceq
            "sha256:$expectedEngineHash"
    ) "binary_pair_drift_before_physical_worker"

    $attemptPath = Join-Path $runRoot "attempt.json"
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_r24d12_physical_attempt_v1"
        gate_id = "QSDK-R24D12"
        question_class = "development"
        status = "consumed_before_worker_launch"
        authorization_commit = $head
        authorization_parent_commit = (
            [string]$authorization.value.authorization_parent_commit
        )
        authorization_sha256 = [string]$authorization.file.raw_sha256
        supervisor_freeze_commit = (
            [string]$authorization.value.supervisor_freeze_commit
        )
        qualification_receipt_sha256 = [string]$qualification.file.raw_sha256
        qualification_closure_sha256 = [string]$qualificationClosure.file.raw_sha256
        prerequisite_zero_world_receipt_sha256 = $expectedZeroWorldReceiptHash
        console_binary_sha256 = "sha256:$expectedConsoleHash"
        engine_binary_sha256 = "sha256:$expectedEngineHash"
        execution_nonce = $nonce
        created_utc = [DateTimeOffset]::UtcNow.ToString("o")
        world_attempt_count = 1
        world_build_count = 0
        solver_step_count = 0
        retained_sample_count = 0
        worker_launch_count = 1
        same_source_rerun_allowed = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-R24D12Json -Path $attemptPath -Value $attempt
    [void](Publish-R24D12Artifact -Path $attemptPath)

    $rawPath = Join-Path $runRoot "raw-report.json"
    $worker = Invoke-R24D12Worker `
        -ConsolePath ([string]$runtimeBeforeLaunch.console.path) `
        -ProjectRoot $projectRoot `
        -RunRoot $runRoot `
        -WorkerMode "physical" `
        -Nonce $nonce `
        -Head $head `
        -ReportPath $rawPath
    $workerReceipt = (Get-R24D12Marker `
        -Lines $worker.stdout_lines `
        -Prefix $physicalWorkerPrefix `
        -Code "physical_worker") |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D12 (
        [bool]$workerReceipt.ok -and
        [string]$workerReceipt.source_commit -ceq $head -and
        [string]$workerReceipt.execution_nonce -ceq $nonce -and
        [int]$workerReceipt.world_attempt_count -eq 1 -and
        [int]$workerReceipt.world_build_count -eq 1 -and
        [int]$workerReceipt.solver_step_count -eq 1 -and
        [int]$workerReceipt.retained_sample_count -eq 4 -and
        -not [bool]$workerReceipt.physical_acceptance_authority -and
        -not [bool]$workerReceipt.release_authority
    ) "physical_worker_receipt"
    $attempt.status = "worker_complete_evaluation_pending"
    $attempt.world_build_count = 1
    $attempt.solver_step_count = 1
    $attempt.retained_sample_count = 4
    Write-R24D12Json -Path $attemptPath -Value $attempt
    [void](Publish-R24D12Artifact -Path $attemptPath)

    $stageIndex += 1
    $workerLog = Join-Path $runRoot (
        "{0:d2}-native_braking_mechanism_worker.log" -f $stageIndex
    )
    [IO.File]::WriteAllText(
        $workerLog,
        [string]$worker.result.stdout,
        [Text.UTF8Encoding]::new($false)
    )
    $stageReceipts.Add([ordered]@{
        index = $stageIndex
        name = "native_braking_mechanism_worker"
        duration_s = 0.0
        log = Get-R24D12FileReceipt $workerLog
        cas = Publish-R24D12Artifact -Path $workerLog -MediaType "text/plain"
    })

    $stageIndex += 1
    $evaluationPath = Join-Path $runRoot "evaluation.json"
    $evaluationLog = Join-Path $runRoot (
        "{0:d2}-native_braking_mechanism_evaluation.log" -f $stageIndex
    )
    $evaluation = Invoke-R24D12Evaluation `
        -PythonPath $pythonPath `
        -InputPath $rawPath `
        -OutputPath $evaluationPath `
        -SourceCommit $head `
        -Nonce $nonce `
        -EvidenceKind "native_physical" `
        -LogPath $evaluationLog
    $validResults = @(
        "complete_valid_finite_native_braking_mechanism_activation_positive",
        "complete_valid_finite_native_braking_mechanism_activation_negative"
    )
    Assert-R24D12 (
        [bool]$evaluation.value.ok -and
        [bool]$evaluation.value.execution_valid -and
        $validResults -ccontains [string]$evaluation.value.result -and
        [int]$evaluation.value.summary.cell_count -eq 4 -and
        [int]$evaluation.value.summary.retained_sample_count -eq 4 -and
        -not [bool]$evaluation.value.numerical_accuracy_accepted -and
        -not [bool]$evaluation.value.instrumented_profile_promoted -and
        -not [bool]$evaluation.value.physical_acceptance_authority -and
        -not [bool]$evaluation.value.release_authority
    ) "physical_evaluation_receipt"
    $mechanismObserved = [bool](
        $evaluation.value.summary.native_braking_mechanism_activation_observed
    )
    Assert-R24D12 (
        ($mechanismObserved -and [string]$evaluation.value.result -ceq
            $validResults[0]) -or
        (-not $mechanismObserved -and [string]$evaluation.value.result -ceq
            $validResults[1])
    ) "physical_result_interpretation"
    $stageReceipts.Add([ordered]@{
        index = $stageIndex
        name = "native_braking_mechanism_evaluation"
        duration_s = [double]$evaluation.run.duration_s
        log = $evaluation.run.log
        cas = Publish-R24D12Artifact -Path $evaluationLog -MediaType "text/plain"
    })

    $attempt.status = [string]$evaluation.value.result
    Write-R24D12Json -Path $attemptPath -Value $attempt
    $attemptFile = Get-R24D12FileReceipt $attemptPath
    $attemptCas = Publish-R24D12Artifact -Path $attemptPath
    $rawReceipt = Get-R24D12FileReceipt $rawPath
    $receipt = [ordered]@{
        schema_version = "sporespore_qsdk_r24d12_braking_mechanism_activation_physical_receipt_v1"
        ok = $true
        gate_id = "QSDK-R24D12"
        question_class = "development"
        status = [string]$evaluation.value.result
        source = $source
        authorization = [ordered]@{
            file = $authorization.file
            value = $authorization.value
        }
        validation_manifest = $manifestReceipt.file
        prerequisite_qualification = [ordered]@{
            receipt = $qualification.file
            value = $qualification.value
            cas_verified = $true
        }
        prerequisite_qualification_closure = [ordered]@{
            file = $qualificationClosure.file
            value = $qualificationClosure.value
            git_blob_oid = $qualificationClosure.git_blob_oid
        }
        prerequisite_zero_world = [ordered]@{
            closure = $zeroWorld.file
            receipt = $zeroWorld.receipt
            cas_verified = $true
        }
        binary_pair = [ordered]@{
            console = $runtimeBeforeLaunch.console
            engine = $runtimeBeforeLaunch.engine
            executed_exact_qualified_pair = $true
            precise_reuse_only = $true
        }
        attempt = [ordered]@{
            file = $attemptFile
            cas = $attemptCas
            same_source_rerun_allowed = $false
        }
        stages = @($stageReceipts)
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
            receipt = $evaluation.value
            file = $evaluation.file
            cas = Publish-R24D12Artifact -Path $evaluationPath
            log = $evaluation.run.log
        }
        actual_counts = [ordered]@{
            world_attempt_count = 1
            world_build_count = 1
            solver_step_count = 1
            retained_sample_count = 4
        }
        claims = [ordered]@{
            native_braking_mechanism_characterized = $true
            native_braking_mechanism_activation_observed = $mechanismObserved
            numerical_accuracy_accepted = $false
            instrumented_profile_promoted = $false
            stock_godot_profile_promoted = $false
            recovery_world_opened = $false
            prone_to_standing_world_opened = $false
            turning_claim_changed = $false
            cross_engine_equivalence_claimed = $false
            q_sdk_r24_satisfied = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
    }
    $receiptPath = Join-Path $runRoot "receipt.json"
    Write-R24D12Json -Path $receiptPath -Value $receipt
    $receiptFile = Get-R24D12FileReceipt $receiptPath
    $receiptCas = Publish-R24D12Artifact -Path $receiptPath
    Write-Output (
        "QSDK_R24D12_BRAKING_MECHANISM_PHYSICAL_RESULT " +
        ([ordered]@{
            ok = $true
            status = [string]$receipt.status
            source_commit = $head
            run_root = $runRoot.Replace("\", "/")
            receipt = $receiptFile
            receipt_cas = $receiptCas
            world_attempt_count = 1
            world_build_count = 1
            solver_step_count = 1
            retained_sample_count = 4
            native_braking_mechanism_activation_observed = $mechanismObserved
            numerical_accuracy_accepted = $false
            instrumented_profile_promoted = $false
            physical_acceptance_authority = $false
            release_authority = $false
        } | ConvertTo-Json -Depth 30 -Compress)
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

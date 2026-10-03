#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet("Preflight", "Authorization", "Physical")]
    [string]$Mode = "Preflight",
    [switch]$RunPhysical,
    [string]$QualificationReceiptPath = "",
    [string]$AuthorizationPath = "",
    [string]$Python = "python",
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$evidenceBase = [IO.Path]::GetFullPath($EvidenceRoot)
$expectedRepoRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRepoRemote = "https://github.com/Slagathore/sporespore.git"
$expectedEvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$expectedZeroWorldSource = "11df9b566dda911c6c3f1a8ad76369c8ee0c340e"
$expectedConsoleSha = (
    "sha256:ff655a567d31f51628d5b21742a0618e53f9fbf8a94937dd07d9882a0739872f"
)
$expectedConsoleBytes = 293376L
$expectedEngineSha = (
    "sha256:2d68ed7ae53704ffb532cd5633241c74d599d69e3bf1968de0ef261553030ffb"
)
$expectedEngineBytes = 188829184L
$expectedToolchainConsoleSha = (
    "sha256:8a629f16859f653d447cd7f07f712f0045a1aed3f27be53413d97df6ff1ec0e6"
)
$expectedToolchainEngineSha = (
    "sha256:0d77df42106c6d2f6fa51727d8051bf403e8a0273b3242daee581c93c4ba7257"
)
$expectedZeroReceiptSha = (
    "sha256:093db061d3bb4799c4ac6a0a4c30364031297aee4b27608ef797cea05c6bb34f"
)
$expectedZeroReceiptBytes = 91320L
$expectedV1RefusalSource = "be6365cea71351519c796cefa4ec3900eed77539"
$expectedV1RefusalSha = (
    "sha256:10d3e7a5e1d6215ddfd917e7b6b55522f75cfe73265dcd6b02ab23d711a03cf5"
)
$expectedZeroRunRoot = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "qsdk-r24d10-exact-step-numerical-telemetry\zero-world\" +
    "20260826T190352433Z-11df9b56-65f7856d452f"
)
$contractRelative = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_" +
    "characterization_preregistration_v1.json"
)
$supervisorContractRelative = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_" +
    "physical_supervisor_contract_v2.json"
)
$manifestRelative = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_" +
    "physical_supervisor_manifest_v2.json"
)
$authorizationRelative = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_" +
    "physical_authorization_v2.json"
)
$qualificationClosureRelative = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_" +
    "physical_supervisor_qualification_positive_closure_v2.json"
)
$zeroClosureRelative = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_" +
    "zero_world_positive_closure_v1.json"
)
$zeroClosureAuditRelative = (
    "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_" +
    "zero_world_positive_closure.ps1"
)
$v1RefusalAuditRelative = (
    "tests/test_qsdk_r24d10_first_physical_supervisor_qualification_" +
    "adoption_refusal.py"
)
$sourceAuditRelative = (
    "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_" +
    "physical_supervisor_source_v2.py"
)
$baseRigRelative = (
    "scripts/lab/rigs/r24d9_godot_jolt_one_hinge_numerical_telemetry_rig.gd"
)
$rigRelative = (
    "scripts/lab/rigs/r24d10_godot_jolt_exact_step_numerical_telemetry_rig.gd"
)
$baseWorkerRelative = (
    "tests/test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_worker.gd"
)
$workerRelative = (
    "tests/test_sdk_qsdk_r24d10_godot_jolt_exact_step_" +
    "numerical_telemetry_worker.gd"
)
$evaluatorRelative = (
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_" +
    "characterization_evaluator.py"
)
$readyPrefix = "QSDK_R24D10_GODOT_SUPERVISOR_TERMINATION_READY "
$zeroWorkerPrefix = "QSDK_R24D10_WORKER_ZERO_WORLD "
$physicalWorkerPrefix = "QSDK_R24D10_PHYSICAL_RAW_REPORT "
$evaluationPrefix = "QSDK_R24D10_EVALUATION_PASS "

. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")
. (Join-Path $sdkRoot "godot_receipt_terminated_process.ps1")
. (Join-Path $sdkRoot "content_addressed_artifact_store.ps1")

function Assert-R24D10Supervisor {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) {
        throw "QSDK-R24D10 physical supervisor: $Code"
    }
}

function Get-R24D10SupervisorPath {
    param([Parameter(Mandatory)][string]$Relative)
    return [IO.Path]::GetFullPath((Join-Path $repoRoot $Relative))
}

function Resolve-R24D10SupervisorApplication {
    param([Parameter(Mandatory)][string]$Command)
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R24D10Supervisor (
            Test-Path -LiteralPath $resolved -PathType Leaf
        ) "application_missing:$resolved"
        return $resolved
    }
    $candidate = Get-Command -Name $Command -CommandType Application |
        Select-Object -First 1
    Assert-R24D10Supervisor ($null -ne $candidate) "application_missing:$Command"
    return [IO.Path]::GetFullPath([string]$candidate.Source)
}

function Get-R24D10SupervisorGit {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    $output = @(& git -C $Root @Arguments 2>&1)
    Assert-R24D10Supervisor ($LASTEXITCODE -eq 0) (
        "git_$($Arguments -join '_'):$($output -join '|')"
    )
    return ($output -join "`n").Trim()
}

function Get-R24D10SupervisorFileReceipt {
    param([Parameter(Mandatory)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    Assert-R24D10Supervisor (Test-Path -LiteralPath $full -PathType Leaf) (
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

function Write-R24D10SupervisorJson {
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

function Publish-R24D10SupervisorArtifact {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$MediaType = "application/json"
    )
    return Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot `
        -ArtifactPath $Path `
        -MediaType $MediaType
}

function Get-R24D10SupervisorMarker {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines,
        [Parameter(Mandatory)][string]$Prefix,
        [Parameter(Mandatory)][string]$Code
    )
    $matches = @($Lines | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R24D10Supervisor ($matches.Count -eq 1) (
        "$Code`_marker_count:$($matches.Count)"
    )
    return ([string]$matches[0]).Substring($Prefix.Length)
}

function Invoke-R24D10SupervisorChecked {
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
    Assert-R24D10Supervisor ($exitCode -eq 0) "$Label`:$($lines -join '|')"
    return [ordered]@{
        output = $lines
        duration_s = [Math]::Round(($finished - $started).TotalSeconds, 6)
        log = Get-R24D10SupervisorFileReceipt $LogPath
    }
}

function Assert-R24D10SupervisorRepositoryBoundary {
    $root = Get-R24D10SupervisorGit -Root $repoRoot -Arguments @(
        "rev-parse", "--show-toplevel"
    )
    $remote = Get-R24D10SupervisorGit -Root $repoRoot -Arguments @(
        "remote", "get-url", "origin"
    )
    $branch = Get-R24D10SupervisorGit -Root $repoRoot -Arguments @(
        "branch", "--show-current"
    )
    $head = Get-R24D10SupervisorGit -Root $repoRoot -Arguments @(
        "rev-parse", "HEAD"
    )
    $upstream = Get-R24D10SupervisorGit -Root $repoRoot -Arguments @(
        "rev-parse", "@{upstream}"
    )
    $cached = Get-R24D10SupervisorGit -Root $repoRoot -Arguments @(
        "rev-parse", "refs/remotes/origin/main"
    )
    $liveText = Get-R24D10SupervisorGit -Root $repoRoot -Arguments @(
        "ls-remote", "--heads", "origin", "refs/heads/main"
    )
    $live = $liveText.Split("`t")[0]
    $status = Get-R24D10SupervisorGit -Root $repoRoot -Arguments @(
        "status", "--short"
    )
    $worktreeText = Get-R24D10SupervisorGit -Root $repoRoot -Arguments @(
        "worktree", "list", "--porcelain"
    )
    $worktrees = @($worktreeText -split "`r?`n" | Where-Object {
        $_.StartsWith("worktree ", [StringComparison]::Ordinal)
    })
    Assert-R24D10Supervisor (
        [IO.Path]::GetFullPath($root) -ceq $expectedRepoRoot -and
        $repoRoot -ceq $expectedRepoRoot
    ) "repository_root"
    Assert-R24D10Supervisor ($remote -ceq $expectedRepoRemote) "repository_remote"
    Assert-R24D10Supervisor ($branch -ceq "main") "branch"
    Assert-R24D10Supervisor ([string]::IsNullOrEmpty($status)) "dirty_worktree"
    Assert-R24D10Supervisor (
        $head -ceq $upstream -and $head -ceq $cached -and $head -ceq $live
    ) "local_upstream_cached_live_inequality"
    Assert-R24D10Supervisor ($worktrees.Count -eq 1) "worktree_count"
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

function Assert-R24D10SupervisorManifest {
    param([Parameter(Mandatory)][string]$Head)
    $manifestPath = Get-R24D10SupervisorPath $manifestRelative
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D10Supervisor (
        [string]$manifest.schema_version -ceq
            "sporespore_qsdk_r24d10_physical_supervisor_manifest_v2" -and
        [string]$manifest.gate_id -ceq "QSDK-R24D10" -and
        [string]$manifest.question_class -ceq "development" -and
        [string]$manifest.status -ceq
            "prospective_physical_supervisor_v2_parent_bound_source_frozen_preflight_pending" -and
        -not [bool]$manifest.includes_self -and
        [string]$manifest.zero_world_source_commit -ceq $expectedZeroWorldSource -and
        [string]$manifest.v1_refusal_source_commit -ceq
            $expectedV1RefusalSource -and
        [string]$manifest.v1_refusal_raw_sha256 -ceq $expectedV1RefusalSha -and
        [string]$manifest.executed_console_binary_raw_sha256 -ceq
            $expectedConsoleSha -and
        [string]$manifest.executed_engine_binary_raw_sha256 -ceq
            $expectedEngineSha -and
        [string]$manifest.lineage_toolchain_console_binary_raw_sha256 -ceq
            $expectedToolchainConsoleSha -and
        [string]$manifest.lineage_toolchain_engine_binary_raw_sha256 -ceq
            $expectedToolchainEngineSha -and
        [int]$manifest.declared_world_count -eq 1 -and
        [int]$manifest.declared_cell_count -eq 9 -and
        [int]$manifest.declared_solver_step_count -eq 20 -and
        [int]$manifest.declared_retained_sample_count -eq 68 -and
        [int]$manifest.declared_preflight_stage_count -eq 7 -and
        [int]$manifest.threshold_count -eq 0 -and
        [int]$manifest.margin_count -eq 0 -and
        [int]$manifest.population_claim_count -eq 0 -and
        -not [bool]$manifest.v2_preflight_passed -and
        -not [bool]$manifest.physical_authorization -and
        -not [bool]$manifest.physical_characterization_executed -and
        -not [bool]$manifest.physical_acceptance_authority -and
        -not [bool]$manifest.release_authority
    ) "manifest_header"
    $bindings = @($manifest.source_bindings)
    Assert-R24D10Supervisor (
        $bindings.Count -eq [int]$manifest.source_binding_count
    ) "manifest_binding_count"
    foreach ($binding in $bindings) {
        $relative = [string]$binding.path
        $path = Get-R24D10SupervisorPath $relative
        $receipt = Get-R24D10SupervisorFileReceipt $path
        $workingBlob = Get-R24D10SupervisorGit -Root $repoRoot -Arguments @(
            "hash-object", $relative
        )
        $committedBlob = Get-R24D10SupervisorGit -Root $repoRoot -Arguments @(
            "rev-parse", "$Head`:$relative"
        )
        Assert-R24D10Supervisor (
            [string]$binding.raw_sha256 -ceq [string]$receipt.raw_sha256 -and
            [long]$binding.byte_length -eq [long]$receipt.byte_length -and
            [string]$binding.git_blob_oid -ceq $workingBlob -and
            $committedBlob -ceq $workingBlob
        ) "manifest_binding:$relative"
    }
    return [ordered]@{
        manifest = $manifest
        receipt = Get-R24D10SupervisorFileReceipt $manifestPath
    }
}

function Assert-R24D10ZeroWorldClosure {
    $closurePath = Get-R24D10SupervisorPath $zeroClosureRelative
    $closure = Get-Content -Raw -LiteralPath $closurePath |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D10Supervisor (
        [string]$closure.schema_version -ceq
            "sporespore_qsdk_r24d10_exact_step_numerical_telemetry_zero_world_positive_closure_v1" -and
        [string]$closure.gate_id -ceq "QSDK-R24D10" -and
        [string]$closure.question_class -ceq "development" -and
        [string]$closure.status -ceq
            "complete_zero_world_gate_passed_physical_execution_still_forbidden_pending_explicit_separate_authorization" -and
        [string]$closure.source.commit -ceq $expectedZeroWorldSource -and
        [bool]$closure.source.clean_pushed_before_qualification -and
        [bool]$closure.source.local_upstream_cached_live_equal_before_qualification -and
        [string]$closure.runtime.console_binary_raw_sha256 -ceq
            $expectedConsoleSha -and
        [long]$closure.runtime.console_binary_byte_length -eq
            $expectedConsoleBytes -and
        [string]$closure.runtime.engine_binary_raw_sha256 -ceq
            $expectedEngineSha -and
        [long]$closure.runtime.engine_binary_byte_length -eq
            $expectedEngineBytes -and
        [bool]$closure.runtime.retained_binary_pair_executed -and
        -not [bool]$closure.runtime.result_reuse_authority -and
        [string]$closure.zero_world_qualification.run_root -ceq
            $expectedZeroRunRoot.Replace("\", "/") -and
        [string]$closure.zero_world_qualification.receipt_raw_sha256 -ceq
            $expectedZeroReceiptSha -and
        [long]$closure.zero_world_qualification.receipt_byte_length -eq
            $expectedZeroReceiptBytes -and
        [int]$closure.zero_world_qualification.world_attempt_count -eq 0 -and
        [int]$closure.zero_world_qualification.world_build_count -eq 0 -and
        [int]$closure.zero_world_qualification.solver_step_count -eq 0 -and
        -not [bool]$closure.next_boundary.physical_execution_authorized -and
        [bool]$closure.next_boundary.distinct_explicit_physical_authorization_required -and
        [string]$closure.next_boundary.next_question_class -ceq "development" -and
        [bool]$closure.claims.complete_zero_world_gate_passed -and
        -not [bool]$closure.claims.physical_characterization_executed -and
        -not [bool]$closure.claims.physical_acceptance_authority -and
        -not [bool]$closure.claims.release_authority
    ) "zero_world_closure"

    $receiptPath = Join-Path $expectedZeroRunRoot "receipt.json"
    $consolePath = Join-Path $expectedZeroRunRoot (
        "artifacts\godot.windows.editor.dev.x86_64.console.exe"
    )
    $enginePath = Join-Path $expectedZeroRunRoot (
        "artifacts\godot.windows.editor.dev.x86_64.exe"
    )
    $receipt = Get-R24D10SupervisorFileReceipt $receiptPath
    $console = Get-R24D10SupervisorFileReceipt $consolePath
    $engine = Get-R24D10SupervisorFileReceipt $enginePath
    Assert-R24D10Supervisor (
        [string]$receipt.raw_sha256 -ceq $expectedZeroReceiptSha -and
        [long]$receipt.byte_length -eq $expectedZeroReceiptBytes -and
        [string]$console.raw_sha256 -ceq $expectedConsoleSha -and
        [long]$console.byte_length -eq $expectedConsoleBytes -and
        [string]$engine.raw_sha256 -ceq $expectedEngineSha -and
        [long]$engine.byte_length -eq $expectedEngineBytes
    ) "zero_world_retained_files"
    foreach ($item in @($receipt, $console, $engine)) {
        $digest = ([string]$item.raw_sha256).Substring(7)
        $casDirectory = Join-Path (
            Join-Path $evidenceBase "artifacts\sha256"
        ) $digest
        Assert-R24D10Supervisor (
            Test-SporeSporeStoredArtifact `
                -Directory $casDirectory `
                -ExpectedSha256 $digest `
                -ExpectedByteLength ([long]$item.byte_length)
        ) "zero_world_cas:$digest"
    }
    return [ordered]@{
        closure = $closure
        closure_file = Get-R24D10SupervisorFileReceipt $closurePath
        receipt = $receipt
        console = $console
        engine = $engine
    }
}

function New-R24D10SupervisorProject {
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
        Copy-Item -LiteralPath (
            Get-R24D10SupervisorPath $relative
        ) -Destination $destination
    }
    if (-not [string]::IsNullOrWhiteSpace($TemplatePath)) {
        Copy-Item -LiteralPath $TemplatePath -Destination (
            Join-Path $ProjectRoot "zero_world_template.json"
        )
    }
    $projectText = @'
; QSDK-R24D10 exact-step physical supervisor route.
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

function Invoke-R24D10SupervisorWorker {
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
        "--script", (
            "res://tests/test_sdk_qsdk_r24d10_godot_jolt_exact_step_" +
            "numerical_telemetry_worker.gd"
        ),
        "--",
        "--mode=$WorkerMode",
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
    Assert-R24D10Supervisor (
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
    Assert-R24D10Supervisor ($errorLines.Count -eq 0) (
        "worker_$WorkerMode`_error_lines:$($errorLines -join '|')"
    )
    Assert-R24D10Supervisor (Test-Path -LiteralPath $ReportPath -PathType Leaf) (
        "worker_$WorkerMode`_report_missing"
    )
    return [ordered]@{
        result = $result
        stdout_lines = $stdoutLines
        stdout = Get-R24D10SupervisorFileReceipt $stdoutPath
        stderr = Get-R24D10SupervisorFileReceipt $stderrPath
        engine_log = Get-R24D10SupervisorFileReceipt $engineLogPath
    }
}

function Invoke-R24D10SupervisorEvaluation {
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
    $run = Invoke-R24D10SupervisorChecked `
        -FileName $PythonPath `
        -Arguments @(
            (Get-R24D10SupervisorPath $evaluatorRelative),
            "--input", $InputPath,
            "--output", $OutputPath,
            "--expected-source-commit", $SourceCommit,
            "--expected-nonce", $Nonce,
            "--expected-evidence-kind", $EvidenceKind
        ) `
        -WorkingDirectory $repoRoot `
        -Label "R24D10 $EvidenceKind evaluation" `
        -LogPath $LogPath
    $marker = Get-R24D10SupervisorMarker `
        -Lines $run.output `
        -Prefix $evaluationPrefix `
        -Code "evaluation"
    return [ordered]@{
        receipt = $marker | ConvertFrom-Json -AsHashtable -Depth 100
        output = Get-R24D10SupervisorFileReceipt $OutputPath
        run = $run
    }
}

function Get-R24D10SupervisorPriorFiles {
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
            throw "Unreadable retained R24D10 record: $($file.FullName)"
        }
    }
    return @($matches)
}

function Assert-R24D10QualificationReceipt {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][hashtable]$ManifestReceipt,
        [Parameter(Mandatory)][System.Collections.IDictionary]$ZeroWorld
    )
    $full = [IO.Path]::GetFullPath($Path)
    $qualificationRoot = Join-Path $evidenceBase (
        "qsdk-r24d10-exact-step-numerical-telemetry\" +
        "physical-supervisor-qualification"
    )
    $prefix = $qualificationRoot.TrimEnd("\", "/") +
        [IO.Path]::DirectorySeparatorChar
    Assert-R24D10Supervisor (
        $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $full) -ceq "receipt.json"
    ) "qualification_receipt_location"
    $receipt = Get-Content -Raw -LiteralPath $full |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D10Supervisor (
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r24d10_physical_supervisor_qualification_receipt_v2" -and
        [bool]$receipt.ok -and
        [string]$receipt.gate_id -ceq "QSDK-R24D10" -and
        [string]$receipt.question_class -ceq "development" -and
        [string]$receipt.status -ceq
            "complete_physical_supervisor_preflight_passed_zero_world_only" -and
        [string]$receipt.validation_manifest.raw_sha256 -ceq
            [string]$ManifestReceipt.raw_sha256 -and
        [string]$receipt.prerequisite_zero_world.receipt.raw_sha256 -ceq
            [string]$ZeroWorld.receipt.raw_sha256 -and
        [string]$receipt.source.root -ceq $expectedRepoRoot.Replace("\", "/") -and
        [string]$receipt.source.remote -ceq $expectedRepoRemote -and
        [string]$receipt.source.branch -ceq "main" -and
        [string]$receipt.source.head -ceq [string]$receipt.source.upstream -and
        [string]$receipt.source.head -ceq
            [string]$receipt.source.cached_origin_main -and
        [string]$receipt.source.head -ceq
            [string]$receipt.source.live_origin_main -and
        [bool]$receipt.source.worktree_clean -and
        [string]$receipt.binary_pair.console.raw_sha256 -ceq
            $expectedConsoleSha -and
        [string]$receipt.binary_pair.engine.raw_sha256 -ceq
            $expectedEngineSha -and
        [bool]$receipt.binary_pair.executed_retained_pair -and
        [int]$receipt.actual_counts.world_attempt_count -eq 0 -and
        [int]$receipt.actual_counts.world_build_count -eq 0 -and
        [int]$receipt.actual_counts.solver_step_count -eq 0 -and
        [bool]$receipt.claims.physical_supervisor_preflight_passed -and
        -not [bool]$receipt.claims.physical_characterization_executed -and
        -not [bool]$receipt.claims.physical_acceptance_authority -and
        -not [bool]$receipt.claims.release_authority
    ) "qualification_receipt"
    $file = Get-R24D10SupervisorFileReceipt $full
    $digest = ([string]$file.raw_sha256).Substring(7)
    Assert-R24D10Supervisor (
        Test-SporeSporeStoredArtifact `
            -Directory (Join-Path (
                Join-Path $evidenceBase "artifacts\sha256"
            ) $digest) `
            -ExpectedSha256 $digest `
            -ExpectedByteLength ([long]$file.byte_length)
    ) "qualification_receipt_cas"
    return [ordered]@{
        value = $receipt
        file = $file
    }
}

function Assert-R24D10QualificationClosure {
    param(
        [Parameter(Mandatory)][string]$Head,
        [Parameter(Mandatory)][hashtable]$ManifestReceipt,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Qualification
    )
    $full = Get-R24D10SupervisorPath $qualificationClosureRelative
    $closure = Get-Content -Raw -LiteralPath $full |
        ConvertFrom-Json -AsHashtable -Depth 100
    $workingBlob = Get-R24D10SupervisorGit -Root $repoRoot -Arguments @(
        "hash-object", $qualificationClosureRelative
    )
    $committedBlob = Get-R24D10SupervisorGit -Root $repoRoot -Arguments @(
        "rev-parse", "$Head`:$qualificationClosureRelative"
    )
    $file = Get-R24D10SupervisorFileReceipt $full
    Assert-R24D10Supervisor (
        [string]$closure.schema_version -ceq
            "sporespore_qsdk_r24d10_physical_supervisor_qualification_positive_closure_v2" -and
        [string]$closure.closure_id -ceq "QSDK-R24D10-PSQ2-CLOSURE" -and
        [string]$closure.gate_id -ceq "QSDK-R24D10" -and
        [string]$closure.question_class -ceq "development" -and
        [string]$closure.status -ceq
            "complete_v2_physical_supervisor_preflight_passed_zero_world_only_authorization_separate" -and
        [string]$closure.qualified_source_commit -ceq
            [string]$Qualification.value.source.head -and
        [string]$closure.validation_manifest_raw_sha256 -ceq
            [string]$ManifestReceipt.raw_sha256 -and
        [string]$closure.qualification_receipt_raw_sha256 -ceq
            [string]$Qualification.file.raw_sha256 -and
        [long]$closure.qualification_receipt_byte_length -eq
            [long]$Qualification.file.byte_length -and
        [string]$closure.executed_console_binary_raw_sha256 -ceq
            $expectedConsoleSha -and
        [string]$closure.executed_engine_binary_raw_sha256 -ceq
            $expectedEngineSha -and
        [int]$closure.stage_count -eq 7 -and
        [int]$closure.world_attempt_count -eq 0 -and
        [int]$closure.world_build_count -eq 0 -and
        [int]$closure.solver_step_count -eq 0 -and
        [bool]$closure.claims.v2_physical_supervisor_preflight_passed -and
        -not [bool]$closure.claims.physical_authorization -and
        -not [bool]$closure.claims.physical_characterization_executed -and
        -not [bool]$closure.claims.physical_acceptance_authority -and
        -not [bool]$closure.claims.release_authority -and
        $workingBlob -ceq $committedBlob
    ) "qualification_closure"
    return [ordered]@{
        value = $closure
        file = $file
        git_blob_oid = $workingBlob
    }
}

function Assert-R24D10PhysicalAuthorization {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Head,
        [Parameter(Mandatory)][hashtable]$ManifestReceipt,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Qualification,
        [Parameter(Mandatory)][System.Collections.IDictionary]$QualificationClosure
    )
    $expectedPath = Get-R24D10SupervisorPath $authorizationRelative
    $full = [IO.Path]::GetFullPath($Path)
    Assert-R24D10Supervisor ($full -ceq $expectedPath) "authorization_path"
    $authorization = Get-Content -Raw -LiteralPath $full |
        ConvertFrom-Json -AsHashtable -Depth 100
    $supervisorRelative = (
        "sdk/run_qsdk_r24d10_exact_step_numerical_telemetry_characterization.ps1"
    )
    $parentLine = Get-R24D10SupervisorGit -Root $repoRoot -Arguments @(
        "rev-list", "--parents", "-n", "1", $Head
    )
    $parentParts = @($parentLine -split " " | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_)
    })
    Assert-R24D10Supervisor (
        $parentParts.Count -eq 2 -and [string]$parentParts[0] -ceq $Head
    ) "authorization_commit_must_have_exactly_one_parent"
    $authorizationParentCommit = [string]$parentParts[1]
    $parentBlob = Get-R24D10SupervisorGit -Root $repoRoot -Arguments @(
        "rev-parse", "$authorizationParentCommit`:$supervisorRelative"
    )
    $currentBlob = Get-R24D10SupervisorGit -Root $repoRoot -Arguments @(
        "rev-parse", "$Head`:$supervisorRelative"
    )
    $parentManifestBlob = Get-R24D10SupervisorGit -Root $repoRoot -Arguments @(
        "rev-parse", "$authorizationParentCommit`:$manifestRelative"
    )
    $currentManifestBlob = Get-R24D10SupervisorGit -Root $repoRoot -Arguments @(
        "rev-parse", "$Head`:$manifestRelative"
    )
    $authorizationWorkingBlob = Get-R24D10SupervisorGit `
        -Root $repoRoot `
        -Arguments @("hash-object", $authorizationRelative)
    $authorizationCommittedBlob = Get-R24D10SupervisorGit `
        -Root $repoRoot `
        -Arguments @("rev-parse", "$Head`:$authorizationRelative")
    Assert-R24D10Supervisor (
        [string]$authorization.schema_version -ceq
            "sporespore_qsdk_r24d10_physical_authorization_v2" -and
        [string]$authorization.gate_id -ceq "QSDK-R24D10" -and
        [string]$authorization.question_class -ceq "development" -and
        [string]$authorization.status -ceq
            "one_bounded_native_development_characterization_authorized" -and
        -not $authorization.Contains("authorization_commit") -and
        [bool]$authorization.authorization_commit_derived_from_current_head -and
        [string]$authorization.authorization_parent_commit -ceq
            $authorizationParentCommit -and
        $authorizationParentCommit -ceq
            [string]$Qualification.value.source.head -and
        [string]$QualificationClosure.value.qualified_source_commit -ceq
            $authorizationParentCommit -and
        $parentBlob -ceq $currentBlob -and
        [string]$authorization.supervisor_git_blob_oid -ceq $currentBlob -and
        $parentManifestBlob -ceq $currentManifestBlob -and
        [string]$authorization.supervisor_manifest_git_blob_oid -ceq
            $currentManifestBlob -and
        [string]$authorization.supervisor_manifest_raw_sha256 -ceq
            [string]$ManifestReceipt.raw_sha256 -and
        [string]$authorization.qualification_receipt_raw_sha256 -ceq
            [string]$Qualification.file.raw_sha256 -and
        [string]$authorization.qualification_closure_raw_sha256 -ceq
            [string]$QualificationClosure.file.raw_sha256 -and
        [string]$authorization.prerequisite_zero_world_receipt_raw_sha256 -ceq
            $expectedZeroReceiptSha -and
        [string]$authorization.executed_console_binary_raw_sha256 -ceq
            $expectedConsoleSha -and
        [string]$authorization.executed_engine_binary_raw_sha256 -ceq
            $expectedEngineSha -and
        [int]$authorization.physical_attempt_limit -eq 1 -and
        -not [bool]$authorization.same_source_rerun_allowed -and
        [int]$authorization.world_count -eq 1 -and
        [int]$authorization.fixture_cell_count -eq 9 -and
        [int]$authorization.solver_step_count -eq 20 -and
        [int]$authorization.retained_sample_count -eq 68 -and
        [int]$authorization.threshold_count -eq 0 -and
        [int]$authorization.margin_count -eq 0 -and
        [int]$authorization.population_claim_count -eq 0 -and
        [bool]$authorization.physical_execution_authorized -and
        -not [bool]$authorization.numerical_accuracy_accepted -and
        -not [bool]$authorization.instrumented_profile_promoted -and
        -not [bool]$authorization.physical_acceptance_authority -and
        -not [bool]$authorization.release_authority -and
        $authorizationWorkingBlob -ceq $authorizationCommittedBlob
    ) "physical_authorization"
    return [ordered]@{
        value = $authorization
        file = Get-R24D10SupervisorFileReceipt $full
    }
}

$operationLock = $null
$runRoot = ""
$attemptPath = ""
$attempt = $null
try {
    $lockRole = if ($Mode -ceq "Physical") { "physical" } else { "conformance" }
    $operationLock = Enter-SporeSporeLocomotionOperationLock -Role $lockRole
    Assert-R24D10Supervisor ([bool]$operationLock.acquired) (
        "another_physical_or_conformance_workload_owns_the_lock"
    )
    Assert-R24D10Supervisor ($evidenceBase -ceq $expectedEvidenceRoot) (
        "evidence_root_substitution_forbidden"
    )
    Assert-R24D10Supervisor (
        -not $evidenceBase.StartsWith(
            $repoRoot + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        )
    ) "evidence_root_inside_repository"

    $source = Assert-R24D10SupervisorRepositoryBoundary
    $head = [string]$source.head
    $pythonPath = Resolve-R24D10SupervisorApplication $Python
    $pwshPath = Resolve-R24D10SupervisorApplication "pwsh"
    $manifestResult = Assert-R24D10SupervisorManifest -Head $head
    $manifestReceipt = [hashtable]$manifestResult.receipt
    $zeroWorld = Assert-R24D10ZeroWorldClosure
    $campaignRoot = Join-Path $evidenceBase (
        "qsdk-r24d10-exact-step-numerical-telemetry"
    )
    [void][IO.Directory]::CreateDirectory($campaignRoot)

    if ($Mode -ceq "Preflight") {
        Assert-R24D10Supervisor (-not $RunPhysical) "physical_switch_in_preflight"
        Assert-R24D10Supervisor (
            [string]::IsNullOrWhiteSpace($QualificationReceiptPath)
        ) "qualification_receipt_forbidden_in_preflight"
        Assert-R24D10Supervisor (
            [string]::IsNullOrWhiteSpace($AuthorizationPath)
        ) "authorization_forbidden_in_preflight"
        $qualificationRoot = Join-Path $campaignRoot (
            "physical-supervisor-qualification"
        )
        $prior = @(Get-R24D10SupervisorPriorFiles `
            -Root $qualificationRoot `
            -FileName "attempt.json" `
            -Match {
                param($value)
                [string]$value.source_commit -ceq $head
            })
        Assert-R24D10Supervisor ($prior.Count -eq 0) (
            "same_source_preflight_attempt_already_consumed:$($prior -join '|')"
        )
        $stamp = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
        $nonce = [Guid]::NewGuid().ToString("N")
        $runRoot = Join-Path $qualificationRoot (
            "$stamp-$($head.Substring(0, 8))-$($nonce.Substring(0, 12))"
        )
        Assert-R24D10Supervisor (-not (Test-Path -LiteralPath $runRoot)) (
            "run_root_exists"
        )
        [void][IO.Directory]::CreateDirectory($runRoot)
        $attemptPath = Join-Path $runRoot "attempt.json"
        $attempt = [ordered]@{
            schema_version = "sporespore_qsdk_r24d10_physical_supervisor_preflight_attempt_v2"
            gate_id = "QSDK-R24D10"
            question_class = "development"
            status = "consumed_before_first_stage"
            source_commit = $head
            validation_manifest_sha256 = [string]$manifestReceipt.raw_sha256
            created_utc = [DateTimeOffset]::UtcNow.ToString("o")
            qualification_attempt_count = 1
            world_attempt_count = 0
            world_build_count = 0
            solver_step_count = 0
            same_source_rerun_allowed = $false
            physical_authorization = $false
            release_authority = $false
        }
        Write-R24D10SupervisorJson -Path $attemptPath -Value $attempt
        [void](Publish-R24D10SupervisorArtifact -Path $attemptPath)

        $stages = [Collections.Generic.List[object]]::new()
        $stageIndex = 0
        $staticStages = @(
            [ordered]@{
                name = "immutable_r24d10_v1_adoption_refusal_recheck"
                file = $pythonPath
                arguments = @(
                    (Get-R24D10SupervisorPath $v1RefusalAuditRelative)
                )
            },
            [ordered]@{
                name = "immutable_r24d10_zero_world_closure_recheck"
                file = $pwshPath
                arguments = @(
                    "-NoLogo", "-NoProfile", "-File",
                    (Get-R24D10SupervisorPath $zeroClosureAuditRelative),
                    "-Python", $pythonPath
                )
            },
            [ordered]@{
                name = "r24d10_physical_supervisor_source_audit"
                file = $pythonPath
                arguments = @(
                    (Get-R24D10SupervisorPath $sourceAuditRelative)
                )
            },
            [ordered]@{
                name = "r24d10_evaluator_self_test"
                file = $pythonPath
                arguments = @(
                    (Get-R24D10SupervisorPath $evaluatorRelative), "--self-test"
                )
            }
        )
        foreach ($stage in $staticStages) {
            $stageIndex += 1
            $logPath = Join-Path $runRoot (
                "{0:d2}-{1}.log" -f $stageIndex, [string]$stage.name
            )
            $stageRun = Invoke-R24D10SupervisorChecked `
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
                cas = Publish-R24D10SupervisorArtifact `
                    -Path $logPath `
                    -MediaType "text/plain"
            })
        }

        $stageIndex += 1
        $templatePath = Join-Path $runRoot "zero-world-template.json"
        $templateLog = Join-Path $runRoot (
            "{0:d2}-evaluator_shaped_zero_world_template.log" -f $stageIndex
        )
        $templateRun = Invoke-R24D10SupervisorChecked `
            -FileName $pythonPath `
            -Arguments @(
                (Get-R24D10SupervisorPath $evaluatorRelative),
                "--emit-zero-world-template", $templatePath,
                "--expected-source-commit", $head,
                "--expected-nonce", $nonce
            ) `
            -WorkingDirectory $repoRoot `
            -Label "R24D10 physical supervisor zero-world template" `
            -LogPath $templateLog
        $stages.Add([ordered]@{
            index = $stageIndex
            name = "evaluator_shaped_zero_world_template"
            duration_s = [double]$templateRun.duration_s
            log = $templateRun.log
            cas = Publish-R24D10SupervisorArtifact `
                -Path $templateLog `
                -MediaType "text/plain"
        })

        $projectRoot = Join-Path $runRoot "project"
        [void][IO.Directory]::CreateDirectory($projectRoot)
        New-R24D10SupervisorProject `
            -ProjectRoot $projectRoot `
            -TemplatePath $templatePath
        $stageIndex += 1
        $rawPath = Join-Path $runRoot "synthetic-raw-report.json"
        $worker = Invoke-R24D10SupervisorWorker `
            -ConsolePath ([string]$zeroWorld.console.path) `
            -ProjectRoot $projectRoot `
            -RunRoot $runRoot `
            -WorkerMode "zero_world_preflight" `
            -Nonce $nonce `
            -Head $head `
            -ReportPath $rawPath
        $workerReceipt = (Get-R24D10SupervisorMarker `
            -Lines $worker.stdout_lines `
            -Prefix $zeroWorkerPrefix `
            -Code "zero_worker") |
            ConvertFrom-Json -AsHashtable -Depth 100
        Assert-R24D10Supervisor (
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
            "{0:d2}-production_worker_zero_object_route.log" -f $stageIndex
        )
        [IO.File]::WriteAllText(
            $workerLog,
            [string]$worker.result.stdout,
            [Text.UTF8Encoding]::new($false)
        )
        $stages.Add([ordered]@{
            index = $stageIndex
            name = "production_worker_zero_object_route"
            duration_s = [Math]::Round((
                [DateTimeOffset]::Parse([string]$worker.result.completed_utc) -
                [DateTimeOffset]::Parse([string]$worker.result.started_utc)
            ).TotalSeconds, 6)
            log = Get-R24D10SupervisorFileReceipt $workerLog
            cas = Publish-R24D10SupervisorArtifact `
                -Path $workerLog `
                -MediaType "text/plain"
        })

        $stageIndex += 1
        $evaluationPath = Join-Path $runRoot "synthetic-evaluation.json"
        $evaluationLog = Join-Path $runRoot (
            "{0:d2}-production_evaluator_zero_world.log" -f $stageIndex
        )
        $evaluation = Invoke-R24D10SupervisorEvaluation `
            -PythonPath $pythonPath `
            -InputPath $rawPath `
            -OutputPath $evaluationPath `
            -SourceCommit $head `
            -Nonce $nonce `
            -EvidenceKind "synthetic_zero_world" `
            -LogPath $evaluationLog
        Assert-R24D10Supervisor (
            [bool]$evaluation.receipt.ok -and
            [bool]$evaluation.receipt.execution_valid -and
            [string]$evaluation.receipt.result -ceq
                "synthetic_exact_step_shape_conforms_zero_world_only" -and
            [int]$evaluation.receipt.exact_step_execution.first_retained_space_step_sequence -eq 1 -and
            [int]$evaluation.receipt.exact_step_execution.last_retained_space_step_sequence -eq 20 -and
            [int]$evaluation.receipt.exact_step_execution.token_derived_physics_step_count -eq 20 -and
            [int]$evaluation.receipt.exact_step_execution.pre_sample_physics_frame_count -eq 0 -and
            -not [bool]$evaluation.receipt.native_numerical_telemetry_characterized -and
            -not [bool]$evaluation.receipt.physical_acceptance_authority -and
            -not [bool]$evaluation.receipt.release_authority
        ) "zero_evaluation_receipt"
        $stages.Add([ordered]@{
            index = $stageIndex
            name = "production_evaluator_zero_world_route"
            duration_s = [double]$evaluation.run.duration_s
            log = $evaluation.run.log
            cas = Publish-R24D10SupervisorArtifact `
                -Path $evaluationLog `
                -MediaType "text/plain"
        })

        $sourceAfter = Assert-R24D10SupervisorRepositoryBoundary
        Assert-R24D10Supervisor ([string]$sourceAfter.head -ceq $head) (
            "source_drift_during_preflight"
        )
        $zeroAfter = Assert-R24D10ZeroWorldClosure
        Assert-R24D10Supervisor (
            [string]$zeroAfter.console.raw_sha256 -ceq
                [string]$zeroWorld.console.raw_sha256 -and
            [string]$zeroAfter.engine.raw_sha256 -ceq
                [string]$zeroWorld.engine.raw_sha256
        ) "retained_binary_pair_drift"

        $rawReceipt = Get-R24D10SupervisorFileReceipt $rawPath
        $rawCas = Publish-R24D10SupervisorArtifact -Path $rawPath
        $evaluationCas = Publish-R24D10SupervisorArtifact -Path $evaluationPath
        $templateReceipt = Get-R24D10SupervisorFileReceipt $templatePath
        $templateCas = Publish-R24D10SupervisorArtifact -Path $templatePath
        $stdoutCas = Publish-R24D10SupervisorArtifact `
            -Path ([string]$worker.stdout.path) `
            -MediaType "text/plain"
        $stderrCas = Publish-R24D10SupervisorArtifact `
            -Path ([string]$worker.stderr.path) `
            -MediaType "text/plain"
        $engineLogCas = Publish-R24D10SupervisorArtifact `
            -Path ([string]$worker.engine_log.path) `
            -MediaType "text/plain"
        $attempt.status = "complete_preflight_passed_zero_world_only"
        Write-R24D10SupervisorJson -Path $attemptPath -Value $attempt
        $attemptFile = Get-R24D10SupervisorFileReceipt $attemptPath
        $attemptCas = Publish-R24D10SupervisorArtifact -Path $attemptPath
        $receipt = [ordered]@{
            schema_version = (
                "sporespore_qsdk_r24d10_physical_supervisor_" +
                "qualification_receipt_v2"
            )
            ok = $true
            gate_id = "QSDK-R24D10"
            question_class = "development"
            status = "complete_physical_supervisor_preflight_passed_zero_world_only"
            source = $source
            validation_manifest = $manifestReceipt
            operation_lock = Get-SporeSporeLocomotionOperationLockPublicReceipt `
                -Receipt $operationLock
            prerequisite_zero_world = [ordered]@{
                closure = $zeroWorld.closure_file
                receipt = $zeroWorld.receipt
                closure_audit_replayed = $true
            }
            runtime_identity_semantics = [ordered]@{
                executed_binary_pair = "r24d10_independent_cold_build_retained_pair"
                embedded_report_toolchain_pair = "r24d8_lineage_provenance_only"
                identities_are_not_interchangeable = $true
            }
            binary_pair = [ordered]@{
                console = $zeroWorld.console
                engine = $zeroWorld.engine
                retained_binary_count = 2
                executed_retained_pair = $true
                precise_reuse_of_exact_zero_world_pair = $true
                rebuilt_for_supervisor_preflight = $false
            }
            attempt = [ordered]@{
                file = $attemptFile
                cas = $attemptCas
                same_source_rerun_allowed = $false
            }
            stages = @($stages)
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
                physical_supervisor_preflight_passed = $true
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
        Write-R24D10SupervisorJson -Path $receiptPath -Value $receipt
        $receiptFile = Get-R24D10SupervisorFileReceipt $receiptPath
        $receiptCas = Publish-R24D10SupervisorArtifact -Path $receiptPath
        Write-Output (
            "QSDK_R24D10_PHYSICAL_SUPERVISOR_PREFLIGHT_PASS " +
            ([ordered]@{
                ok = $true
                source_commit = $head
                receipt = $receiptFile
                receipt_cas = $receiptCas
                run_root = $runRoot.Replace("\", "/")
                stage_count = $stages.Count
                console_sha256 = [string]$zeroWorld.console.raw_sha256
                engine_sha256 = [string]$zeroWorld.engine.raw_sha256
                world_attempt_count = 0
                world_build_count = 0
                solver_step_count = 0
                physical_authorization = $false
                physical_acceptance_authority = $false
                release_authority = $false
            } | ConvertTo-Json -Depth 30 -Compress)
        )
        return
    }

    if ($Mode -ceq "Physical") {
        Assert-R24D10Supervisor ($RunPhysical) "explicit_run_physical_switch_required"
    }
    else {
        Assert-R24D10Supervisor (-not $RunPhysical) (
            "physical_switch_forbidden_in_authorization_check"
        )
    }
    Assert-R24D10Supervisor (
        -not [string]::IsNullOrWhiteSpace($QualificationReceiptPath)
    ) "qualification_receipt_path_required"
    if ([string]::IsNullOrWhiteSpace($AuthorizationPath)) {
        $AuthorizationPath = Get-R24D10SupervisorPath $authorizationRelative
    }
    $qualification = Assert-R24D10QualificationReceipt `
        -Path $QualificationReceiptPath `
        -ManifestReceipt $manifestReceipt `
        -ZeroWorld $zeroWorld
    $qualificationClosure = Assert-R24D10QualificationClosure `
        -Head $head `
        -ManifestReceipt $manifestReceipt `
        -Qualification $qualification
    $authorization = Assert-R24D10PhysicalAuthorization `
        -Path $AuthorizationPath `
        -Head $head `
        -ManifestReceipt $manifestReceipt `
        -Qualification $qualification `
        -QualificationClosure $qualificationClosure

    $preflightRoot = Join-Path $campaignRoot "physical"
    $prior = @(Get-R24D10SupervisorPriorFiles `
        -Root $preflightRoot `
        -FileName "attempt.json" `
        -Match {
            param($value)
            [string]$value.authorization_commit -ceq $head -and
            [string]$value.console_binary_sha256 -ceq $expectedConsoleSha -and
            [string]$value.engine_binary_sha256 -ceq $expectedEngineSha
        })
    Assert-R24D10Supervisor ($prior.Count -eq 0) (
        "same_authorization_binary_pair_physical_attempt_already_consumed"
    )

    if ($Mode -ceq "Authorization") {
        Write-Output (
            "QSDK_R24D10_PHYSICAL_AUTHORIZATION_CHECK_PASS " +
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
    $runRoot = Join-Path $preflightRoot (
        "$stamp-$($head.Substring(0, 8))-$($nonce.Substring(0, 12))"
    )
    Assert-R24D10Supervisor (-not (Test-Path -LiteralPath $runRoot)) (
        "run_root_exists"
    )
    [void][IO.Directory]::CreateDirectory($runRoot)
    $stages = [Collections.Generic.List[object]]::new()
    $stageIndex = 0
    $physicalStaticStages = @(
        [ordered]@{
            name = "immutable_r24d10_v1_adoption_refusal_recheck"
            file = $pythonPath
            arguments = @(
                (Get-R24D10SupervisorPath $v1RefusalAuditRelative)
            )
        },
        [ordered]@{
            name = "immutable_r24d10_zero_world_closure_recheck"
            file = $pwshPath
            arguments = @(
                "-NoLogo", "-NoProfile", "-File",
                (Get-R24D10SupervisorPath $zeroClosureAuditRelative),
                "-Python", $pythonPath
            )
        },
        [ordered]@{
            name = "r24d10_physical_supervisor_source_audit"
            file = $pythonPath
            arguments = @(
                (Get-R24D10SupervisorPath $sourceAuditRelative)
            )
        },
        [ordered]@{
            name = "r24d10_evaluator_self_test"
            file = $pythonPath
            arguments = @(
                (Get-R24D10SupervisorPath $evaluatorRelative), "--self-test"
            )
        }
    )
    foreach ($stage in $physicalStaticStages) {
        $stageIndex += 1
        $logPath = Join-Path $runRoot (
            "{0:d2}-{1}.log" -f $stageIndex, [string]$stage.name
        )
        $stageRun = Invoke-R24D10SupervisorChecked `
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
            cas = Publish-R24D10SupervisorArtifact `
                -Path $logPath `
                -MediaType "text/plain"
        })
    }

    $projectRoot = Join-Path $runRoot "project"
    [void][IO.Directory]::CreateDirectory($projectRoot)
    New-R24D10SupervisorProject -ProjectRoot $projectRoot
    $sourceBeforeLaunch = Assert-R24D10SupervisorRepositoryBoundary
    Assert-R24D10Supervisor ([string]$sourceBeforeLaunch.head -ceq $head) (
        "source_drift_before_physical_worker"
    )
    $zeroBeforeLaunch = Assert-R24D10ZeroWorldClosure
    Assert-R24D10Supervisor (
        [string]$zeroBeforeLaunch.console.raw_sha256 -ceq $expectedConsoleSha -and
        [string]$zeroBeforeLaunch.engine.raw_sha256 -ceq $expectedEngineSha
    ) "binary_pair_drift_before_physical_worker"

    $attemptPath = Join-Path $runRoot "attempt.json"
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_r24d10_physical_attempt_v2"
        gate_id = "QSDK-R24D10"
        question_class = "development"
        status = "consumed_before_worker_launch"
        authorization_commit = $head
        authorization_parent_commit = [string]$authorization.value.authorization_parent_commit
        authorization_sha256 = [string]$authorization.file.raw_sha256
        supervisor_freeze_commit = [string]$authorization.value.authorization_parent_commit
        qualification_receipt_sha256 = [string]$qualification.file.raw_sha256
        qualification_closure_sha256 = [string]$qualificationClosure.file.raw_sha256
        prerequisite_zero_world_receipt_sha256 = $expectedZeroReceiptSha
        console_binary_sha256 = $expectedConsoleSha
        engine_binary_sha256 = $expectedEngineSha
        execution_nonce = $nonce
        created_utc = [DateTimeOffset]::UtcNow.ToString("o")
        world_attempt_count = 1
        world_build_count = 0
        solver_step_count = 0
        retained_sample_count = 0
        worker_launch_count = 0
        same_source_rerun_allowed = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-R24D10SupervisorJson -Path $attemptPath -Value $attempt
    [void](Publish-R24D10SupervisorArtifact -Path $attemptPath)

    $rawPath = Join-Path $runRoot "raw-report.json"
    $attempt.worker_launch_count = 1
    Write-R24D10SupervisorJson -Path $attemptPath -Value $attempt
    $worker = Invoke-R24D10SupervisorWorker `
        -ConsolePath ([string]$zeroWorld.console.path) `
        -ProjectRoot $projectRoot `
        -RunRoot $runRoot `
        -WorkerMode "physical" `
        -Nonce $nonce `
        -Head $head `
        -ReportPath $rawPath
    $workerReceipt = (Get-R24D10SupervisorMarker `
        -Lines $worker.stdout_lines `
        -Prefix $physicalWorkerPrefix `
        -Code "physical_worker") |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D10Supervisor (
        [bool]$workerReceipt.ok -and
        [string]$workerReceipt.source_commit -ceq $head -and
        [string]$workerReceipt.execution_nonce -ceq $nonce -and
        [int]$workerReceipt.world_attempt_count -eq 1 -and
        [int]$workerReceipt.world_build_count -eq 1 -and
        [int]$workerReceipt.solver_step_count -eq 20 -and
        [int]$workerReceipt.first_retained_space_step_sequence -eq 1 -and
        [int]$workerReceipt.last_retained_space_step_sequence -eq 20 -and
        [int]$workerReceipt.observed_retained_awake_space_step_token_count -eq 20 -and
        [int]$workerReceipt.retained_sample_count -eq 68 -and
        [int]$workerReceipt.pre_sample_physics_frame_count -eq 0 -and
        [int]$workerReceipt.terminal_physics_server_deactivation_count -eq 1 -and
        -not [bool]$workerReceipt.physical_acceptance_authority -and
        -not [bool]$workerReceipt.release_authority
    ) "physical_worker_receipt"
    $attempt.status = "worker_complete_evaluation_pending"
    $attempt.world_build_count = 1
    $attempt.solver_step_count = 20
    $attempt.retained_sample_count = 68
    Write-R24D10SupervisorJson -Path $attemptPath -Value $attempt
    [void](Publish-R24D10SupervisorArtifact -Path $attemptPath)

    $stageIndex += 1
    $evaluationPath = Join-Path $runRoot "evaluation.json"
    $evaluationLog = Join-Path $runRoot (
        "{0:d2}-native_exact_step_evaluation.log" -f $stageIndex
    )
    $evaluation = Invoke-R24D10SupervisorEvaluation `
        -PythonPath $pythonPath `
        -InputPath $rawPath `
        -OutputPath $evaluationPath `
        -SourceCommit $head `
        -Nonce $nonce `
        -EvidenceKind "native_physical" `
        -LogPath $evaluationLog
    Assert-R24D10Supervisor (
        [bool]$evaluation.receipt.ok -and
        [bool]$evaluation.receipt.execution_valid -and
        [string]$evaluation.receipt.result -ceq
            "complete_valid_finite_descriptive_native_exact_step_numerical_characterization" -and
        [int]$evaluation.receipt.exact_step_execution.first_retained_space_step_sequence -eq 1 -and
        [int]$evaluation.receipt.exact_step_execution.last_retained_space_step_sequence -eq 20 -and
        [int]$evaluation.receipt.exact_step_execution.token_derived_physics_step_count -eq 20 -and
        [int]$evaluation.receipt.exact_step_execution.pre_sample_physics_frame_count -eq 0 -and
        [bool]$evaluation.receipt.native_numerical_telemetry_characterized -and
        -not [bool]$evaluation.receipt.numerical_accuracy_accepted -and
        -not [bool]$evaluation.receipt.instrumented_profile_promoted -and
        -not [bool]$evaluation.receipt.physical_acceptance_authority -and
        -not [bool]$evaluation.receipt.release_authority
    ) "physical_evaluation_receipt"
    $stages.Add([ordered]@{
        index = $stageIndex
        name = "native_exact_step_evaluation"
        duration_s = [double]$evaluation.run.duration_s
        log = $evaluation.run.log
        cas = Publish-R24D10SupervisorArtifact `
            -Path $evaluationLog `
            -MediaType "text/plain"
    })

    $attempt.status = "complete_valid_finite_descriptive_development_result"
    $attempt.world_build_count = 1
    $attempt.solver_step_count = 20
    Write-R24D10SupervisorJson -Path $attemptPath -Value $attempt
    $attemptFile = Get-R24D10SupervisorFileReceipt $attemptPath
    $attemptCas = Publish-R24D10SupervisorArtifact -Path $attemptPath
    $rawReceipt = Get-R24D10SupervisorFileReceipt $rawPath
    $rawCas = Publish-R24D10SupervisorArtifact -Path $rawPath
    $evaluationCas = Publish-R24D10SupervisorArtifact -Path $evaluationPath
    $stdoutCas = Publish-R24D10SupervisorArtifact `
        -Path ([string]$worker.stdout.path) `
        -MediaType "text/plain"
    $stderrCas = Publish-R24D10SupervisorArtifact `
        -Path ([string]$worker.stderr.path) `
        -MediaType "text/plain"
    $engineLogCas = Publish-R24D10SupervisorArtifact `
        -Path ([string]$worker.engine_log.path) `
        -MediaType "text/plain"
    $receipt = [ordered]@{
        schema_version = (
            "sporespore_qsdk_r24d10_exact_step_numerical_telemetry_" +
            "physical_receipt_v2"
        )
        ok = $true
        gate_id = "QSDK-R24D10"
        question_class = "development"
        status = "complete_valid_finite_descriptive_development_result"
        source = $source
        authorization = [ordered]@{
            file = $authorization.file
            value = $authorization.value
        }
        validation_manifest = $manifestReceipt
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
            closure = $zeroWorld.closure_file
            receipt = $zeroWorld.receipt
            cas_verified = $true
        }
        runtime_identity_semantics = [ordered]@{
            executed_binary_pair = "r24d10_independent_cold_build_retained_pair"
            embedded_report_toolchain_pair = "r24d8_lineage_provenance_only"
            identities_are_not_interchangeable = $true
        }
        binary_pair = [ordered]@{
            console = $zeroWorld.console
            engine = $zeroWorld.engine
            executed_retained_pair = $true
            precise_reuse_of_exact_qualified_pair = $true
        }
        attempt = [ordered]@{
            file = $attemptFile
            cas = $attemptCas
            same_source_rerun_allowed = $false
        }
        stages = @($stages)
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
        }
        actual_counts = [ordered]@{
            world_attempt_count = 1
            world_build_count = 1
            solver_step_count = 20
            retained_sample_count = 68
        }
        claims = [ordered]@{
            native_numerical_telemetry_characterized = $true
            exact_step_schedule_observed = $true
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
    Write-R24D10SupervisorJson -Path $receiptPath -Value $receipt
    $receiptFile = Get-R24D10SupervisorFileReceipt $receiptPath
    $receiptCas = Publish-R24D10SupervisorArtifact -Path $receiptPath
    Write-Output (
        "QSDK_R24D10_EXACT_STEP_PHYSICAL_RESULT " +
        ([ordered]@{
            ok = $true
            source_commit = $head
            receipt = $receiptFile
            receipt_cas = $receiptCas
            run_root = $runRoot.Replace("\", "/")
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
} catch {
    if (-not [string]::IsNullOrWhiteSpace($runRoot) -and (
        Test-Path -LiteralPath $runRoot -PathType Container
    )) {
        $failurePath = Join-Path $runRoot "terminal-failure.json"
        if (-not (Test-Path -LiteralPath $failurePath)) {
            $worldAttemptCount = if ($Mode -ceq "Physical" -and (
                -not [string]::IsNullOrWhiteSpace($attemptPath)
            )) { 1 } else { 0 }
            $worldBuildCount = 0
            $solverStepCount = 0
            $retainedSampleCount = 0
            if ($null -ne $attempt) {
                if ($attempt.Contains("world_build_count")) {
                    $worldBuildCount = [int]$attempt.world_build_count
                }
                if ($attempt.Contains("solver_step_count")) {
                    $solverStepCount = [int]$attempt.solver_step_count
                }
                if ($attempt.Contains("retained_sample_count")) {
                    $retainedSampleCount = [int]$attempt.retained_sample_count
                }
                $attempt.status = if ($Mode -ceq "Physical") {
                    "consumed_physical_attempt_failed_or_incomplete"
                } else {
                    "consumed_preflight_attempt_failed"
                }
                try {
                    Write-R24D10SupervisorJson -Path $attemptPath -Value $attempt
                    [void](Publish-R24D10SupervisorArtifact -Path $attemptPath)
                } catch {}
            }
            Write-R24D10SupervisorJson -Path $failurePath -Value ([ordered]@{
                schema_version = "sporespore_qsdk_r24d10_supervisor_failure_v2"
                gate_id = "QSDK-R24D10"
                question_class = "development"
                mode = $Mode
                status = if ($Mode -ceq "Physical") {
                    "physical_attempt_failed_or_incomplete_if_consumed"
                } else {
                    "preflight_attempt_failed"
                }
                failure = [string]$_.Exception.Message
                observed_utc = [DateTimeOffset]::UtcNow.ToString("o")
                world_attempt_count = $worldAttemptCount
                world_build_count = $worldBuildCount
                solver_step_count = $solverStepCount
                retained_sample_count = $retainedSampleCount
                same_source_rerun_allowed = $false
                physical_acceptance_authority = $false
                release_authority = $false
            })
            try {
                [void](Publish-R24D10SupervisorArtifact -Path $failurePath)
            } catch {}
        }
    }
    throw
} finally {
    if ($null -ne $operationLock) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $operationLock
    }
}

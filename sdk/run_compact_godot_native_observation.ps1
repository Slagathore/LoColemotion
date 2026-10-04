#requires -Version 7.0

<#
.SYNOPSIS
Shared one-world/two-step Godot native-observation supervisor.

.DESCRIPTION
This runner consumes a compact declarative contract, a committed zero-world
authorization closure, and the shared Godot receipt-termination primitive. It
does not contain campaign physics or thresholds. Every valid, invalid, or
incomplete physical attempt is retained once; no automatic retry is possible.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ContractRelativePath,
    [ValidateSet("Preflight", "Physical")][string]$Mode = "Preflight",
    [switch]$RunPhysical,
    [string]$AuthorizationPath = "",
    [string]$EvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = "C:\Users\Cole\CodeStuff\games\LoColemotion"
$expectedRemote = "https://github.com/Slagathore/LoColemotion.git"
$expectedEvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
. (Join-Path $PSScriptRoot "locomotion_operation_lock.ps1")
. (Join-Path $PSScriptRoot "godot_receipt_terminated_process.ps1")

function Assert-CompactNativeObservation {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) { throw "COMPACT_GODOT_NATIVE_OBSERVATION:$Code" }
}

function Get-CompactNativeGit {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = @(& git -C $repoRoot @Arguments)
    Assert-CompactNativeObservation ($LASTEXITCODE -eq 0) (
        "git_$($Arguments -join '_')"
    )
    return ($output -join "`n").Trim()
}

function Get-CompactNativeSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Write-CompactNativeJson {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Value
    )
    [IO.File]::WriteAllText(
        $Path,
        ($Value | ConvertTo-Json -Depth 100 -Compress) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
}

function Get-CompactNativeRepositoryBoundary {
    $root = Get-CompactNativeGit @("rev-parse", "--show-toplevel")
    $remote = Get-CompactNativeGit @("remote", "get-url", "origin")
    $branch = Get-CompactNativeGit @("branch", "--show-current")
    $head = Get-CompactNativeGit @("rev-parse", "HEAD")
    $cached = Get-CompactNativeGit @("rev-parse", "origin/main")
    $liveText = Get-CompactNativeGit @(
        "ls-remote", "--heads", "origin", "refs/heads/main"
    )
    $live = $liveText.Split("`t")[0]
    $status = Get-CompactNativeGit @("status", "--porcelain=v2")
    $worktrees = Get-CompactNativeGit @("worktree", "list", "--porcelain")
    $worktreeCount = @($worktrees -split "`r?`n" | Where-Object {
        $_.StartsWith("worktree ", [StringComparison]::Ordinal)
    }).Count
    Assert-CompactNativeObservation (
        [IO.Path]::GetFullPath($root) -ceq $expectedRoot
    ) "repository_root"
    Assert-CompactNativeObservation ($repoRoot -ceq $expectedRoot) "runner_root"
    Assert-CompactNativeObservation ($remote -ceq $expectedRemote) "origin_url"
    Assert-CompactNativeObservation ($branch -ceq "main") "branch"
    Assert-CompactNativeObservation ([string]::IsNullOrEmpty($status)) "dirty_worktree"
    Assert-CompactNativeObservation (
        $head -ceq $cached -and $head -ceq $live
    ) "local_cached_live_inequality"
    Assert-CompactNativeObservation ($worktreeCount -eq 1) "worktree_count"
    return [ordered]@{
        root = $root.Replace("\", "/")
        remote = $remote
        branch = $branch
        head = $head
        cached_origin_main = $cached
        live_origin_main = $live
        worktree_count = $worktreeCount
        worktree_clean = $true
    }
}

$contractPath = [IO.Path]::GetFullPath((Join-Path $repoRoot $ContractRelativePath))
Assert-CompactNativeObservation (
    $contractPath.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar)
) "contract_outside_repository"
Assert-CompactNativeObservation (
    Test-Path -LiteralPath $contractPath -PathType Leaf
) "contract_missing"
$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$runner = $contract.physical_runner
$question = $contract.prospective_physical_question
$gateId = [string]$contract.gate_id
$workerGateId = $gateId
if ($runner.Contains("worker_gate_id")) {
    $workerGateId = [string]$runner.worker_gate_id
}
$evidenceDirectoryName = ""
if ($runner.Contains("evidence_directory_name")) {
    $evidenceDirectoryName = [string]$runner.evidence_directory_name
}
$workerRelative = [string]$runner.worker_path
$workerPath = Join-Path $repoRoot $workerRelative
$auditRelative = [string]$runner.source_audit_path
$auditPath = Join-Path $repoRoot $auditRelative
$consolePath = [IO.Path]::GetFullPath([string]$contract.exact_runtime.console_path)
$closureRelative = [string]$contract.closure.path
$closurePath = Join-Path $repoRoot $closureRelative
$rawMarker = [string]$runner.raw_marker
$readyMarker = [string]$runner.ready_marker
$supervisorMarker = [string]$runner.supervisor_marker
$seed = [int]$question.seed
$seedLabel = [string]$question.seed_label
$seedSha = [string]$question.seed_sha256

function Assert-CompactNativeContract {
    Assert-CompactNativeObservation ($gateId.Length -gt 0) "gate_id"
    Assert-CompactNativeObservation (
        [string]$contract.question_class -ceq "development" -and
        [string]$question.physical_question_kind -ceq "native_observation_smoke" -and
        [int]$question.world_count -eq 1 -and
        [int]$question.maximum_world_build_count -eq 1 -and
        [int]$question.maximum_outer_solver_steps -eq 2 -and
        [int]$question.native_observation_count -eq 2 -and
        [int]$question.portable_collection_count -eq 0 -and
        [int]$question.portable_control_plan_count -eq 0 -and
        [int]$question.portable_command_application_count -eq 0 -and
        -not [bool]$question.held_out -and
        -not [bool]$question.same_identity_rerun_permitted
    ) "question_contract"
    Assert-CompactNativeObservation (
        [string]$runner.physical_question_kind -ceq "native_observation_smoke" -and
        [string]$runner.valid_complete_status -ceq
            "valid_complete_native_observation_smoke" -and
        [string]$runner.invalid_or_incomplete_status -ceq
            "invalid_or_incomplete_native_observation_smoke" -and
        [int]$runner.maximum_world_build_count -eq 1 -and
        [int]$runner.maximum_outer_solver_steps -eq 2 -and
        [int]$runner.seed -eq $seed -and
        [string]$runner.seed_sha256 -ceq $seedSha
    ) "runner_contract"
    Assert-CompactNativeObservation (
        -not [string]::IsNullOrWhiteSpace($workerGateId) -and
        $workerGateId.StartsWith("QSDK-R24D", [StringComparison]::Ordinal)
    ) "worker_gate_id"
    if (-not [string]::IsNullOrEmpty($evidenceDirectoryName)) {
        Assert-CompactNativeObservation (
            $evidenceDirectoryName -cmatch '^[a-z0-9][a-z0-9-]*$'
        ) "evidence_directory_name"
    }
    foreach ($path in @(
        $workerRelative,
        $auditRelative,
        [string]$runner.script_path,
        [string]$runner.shared_supervisor_path
    )) {
        Assert-CompactNativeObservation (
            $contract.source_inventory -ccontains $path
        ) "source_inventory:$path"
        Assert-CompactNativeObservation (
            Test-Path -LiteralPath (Join-Path $repoRoot $path) -PathType Leaf
        ) "source_missing:$path"
    }
    Assert-CompactNativeObservation (
        Test-Path -LiteralPath $consolePath -PathType Leaf
    ) "runtime_missing"
    Assert-CompactNativeObservation (
        (Get-CompactNativeSha256 $consolePath) -ceq
            [string]$contract.exact_runtime.console_sha256
    ) "runtime_sha256"
    Assert-CompactNativeObservation (
        (Get-Item -LiteralPath $consolePath).Length -eq
            [long]$contract.exact_runtime.console_byte_length
    ) "runtime_byte_length"
}

function Invoke-CompactNativeClosureAudit {
    $output = @(& python $auditPath --mode verify-closure)
    Assert-CompactNativeObservation ($LASTEXITCODE -eq 0) "closure_audit_exit"
    $marker = [string]$contract.closure.audit_marker + " "
    $lines = @($output | Where-Object {
        ([string]$_).StartsWith($marker, [StringComparison]::Ordinal)
    })
    Assert-CompactNativeObservation ($lines.Count -eq 1) "closure_audit_marker"
    return [ordered]@{
        marker = $marker.TrimEnd()
        output_line = [string]$lines[0]
    }
}

function Get-CompactNativeAuthorization {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Repository)
    Assert-CompactNativeObservation (
        -not [string]::IsNullOrWhiteSpace($AuthorizationPath)
    ) "authorization_path_required"
    $resolved = [IO.Path]::GetFullPath($AuthorizationPath)
    Assert-CompactNativeObservation ($resolved -ceq $closurePath) "authorization_path"
    Assert-CompactNativeObservation (
        Test-Path -LiteralPath $resolved -PathType Leaf
    ) "authorization_missing"
    $closure = Get-Content -Raw -LiteralPath $resolved |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-CompactNativeObservation (
        [string]$closure.schema_version -ceq [string]$contract.closure.schema -and
        [string]$closure.gate_id -ceq $gateId -and
        [string]$closure.status -ceq
            "closed_passing_zero_world_implementation_qualification" -and
        [string]$closure.question_class -ceq "development" -and
        [bool]$closure.qualification.official_zero_world_qualification_passed -and
        [int]$closure.qualification.model_construction_count -eq 0 -and
        [int]$closure.qualification.world_attempt_count -eq 0 -and
        [int]$closure.qualification.world_build_count -eq 0 -and
        [int]$closure.qualification.solver_step_count -eq 0 -and
        [bool]$closure.decision.physical_execution_authorized -and
        [bool]$closure.decision.physical_native_observation_authorized -and
        -not [bool]$closure.decision.physical_route_ghost_authorized -and
        -not [bool]$closure.decision.physical_ghost_authorized -and
        [int]$closure.decision.authorized_world_count -eq 1 -and
        [int]$closure.decision.maximum_world_build_count -eq 1 -and
        [int]$closure.decision.maximum_outer_solver_steps -eq 2 -and
        [int]$closure.decision.seed -eq $seed -and
        [string]$closure.decision.seed_label -ceq $seedLabel -and
        [string]$closure.decision.seed_sha256 -ceq $seedSha -and
        -not [bool]$closure.decision.held_out -and
        -not [bool]$closure.claim_boundary.prone_to_standing_claimed -and
        -not [bool]$closure.claim_boundary.physical_acceptance_authority -and
        -not [bool]$closure.claim_boundary.release_authority
    ) "authorization_content"
    $freeze = [string]$closure.source.source_freeze_commit
    Assert-CompactNativeObservation ($freeze -cmatch '^[0-9a-f]{40}$') "freeze_commit"
    & git -C $repoRoot merge-base --is-ancestor $freeze $Repository.head
    Assert-CompactNativeObservation ($LASTEXITCODE -eq 0) "freeze_not_ancestor"
    foreach ($path in @($contract.qualified_physical_paths)) {
        & git -C $repoRoot diff --quiet $freeze $Repository.head -- ([string]$path)
        Assert-CompactNativeObservation ($LASTEXITCODE -eq 0) (
            "qualified_physical_source_drift:$path"
        )
    }
    $tracked = Get-CompactNativeGit @("ls-files", "--error-unmatch", $closureRelative)
    Assert-CompactNativeObservation ($tracked -ceq $closureRelative) (
        "authorization_uncommitted"
    )
    return [ordered]@{
        path = $resolved.Replace("\", "/")
        raw_sha256 = Get-CompactNativeSha256 $resolved
        byte_length = (Get-Item -LiteralPath $resolved).Length
        source_freeze_commit = $freeze
        qualified_physical_path_count = @($contract.qualified_physical_paths).Count
        closure = $closure
    }
}

function Invoke-CompactNativePreflight {
    Assert-CompactNativeObservation (-not $RunPhysical.IsPresent) (
        "preflight_cannot_run_physics"
    )
    Assert-CompactNativeContract
    $output = @(& python $auditPath --mode development)
    Assert-CompactNativeObservation ($LASTEXITCODE -eq 0) "development_preflight_exit"
    $marker = [string]$contract.qualification.pass_marker + " "
    Assert-CompactNativeObservation (
        @($output | Where-Object {
            ([string]$_).StartsWith($marker, [StringComparison]::Ordinal)
        }).Count -eq 1
    ) "development_preflight_marker"
    return [ordered]@{
        schema_version = [string]$runner.preflight_schema
        gate_id = $gateId
        ok = $true
        physical_question_kind = "native_observation_smoke"
        physical_question_gate_id = $workerGateId
        worker_zero_world_executed = $true
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
}

function Invoke-CompactNativePhysical {
    Assert-CompactNativeObservation ($RunPhysical.IsPresent) "physical_switch_required"
    Assert-CompactNativeObservation (
        [IO.Path]::GetFullPath($EvidenceRoot) -ceq $expectedEvidenceRoot
    ) "evidence_root"
    Assert-CompactNativeContract
    Assert-CompactNativeObservation (
        -not [string]::IsNullOrWhiteSpace($evidenceDirectoryName) -and
        $evidenceDirectoryName -cmatch '^[a-z0-9][a-z0-9-]*$'
    ) "evidence_directory_name_required"
    Assert-CompactNativeObservation (
        -not (Test-Path -LiteralPath (
            Join-Path $repoRoot ([string]$contract.physical_closure.path)
        ))
    ) "physical_identity_consumed"
    $lock = Enter-SporeSporeLocomotionOperationLock -Role physical_development
    Assert-CompactNativeObservation ([bool]$lock.acquired) "operation_lock"
    try {
        $repository = Get-CompactNativeRepositoryBoundary
        $authorization = Get-CompactNativeAuthorization -Repository $repository
        $closureAudit = Invoke-CompactNativeClosureAudit
        $campaignRoot = Join-Path $EvidenceRoot $evidenceDirectoryName
        Assert-CompactNativeObservation (
            [IO.Path]::GetFullPath((Split-Path -Parent $campaignRoot)) -ceq
                [IO.Path]::GetFullPath($EvidenceRoot)
        ) "evidence_directory_parent"
        Assert-CompactNativeObservation (
            -not (Test-Path -LiteralPath $campaignRoot)
        ) "same_identity_evidence_already_exists"
        [void][IO.Directory]::CreateDirectory($campaignRoot)
        $attemptId = [guid]::NewGuid().ToString("N")
        $nonce = [guid]::NewGuid().ToString("N")
        $attemptRoot = Join-Path $campaignRoot (
            "$($repository.head.Substring(0, 8))-$($attemptId.Substring(0, 8))"
        )
        [void][IO.Directory]::CreateDirectory($attemptRoot)
        $reportPath = Join-Path $attemptRoot "native_observation.json"
        $attemptPath = Join-Path $attemptRoot "attempt.json"
        $attempt = [ordered]@{
            schema_version = [string]$runner.attempt_schema
            gate_id = $gateId
            physical_question_gate_id = $workerGateId
            question_class = "development"
            physical_question_kind = "native_observation_smoke"
            status = "running"
            attempt_id = $attemptId
            created_utc = [DateTimeOffset]::UtcNow.ToString("o")
            source = $repository
            authorization = [ordered]@{
                path = [string]$authorization.path
                raw_sha256 = [string]$authorization.raw_sha256
                byte_length = [long]$authorization.byte_length
                source_freeze_commit = [string]$authorization.source_freeze_commit
            }
            seed = $seed
            seed_label = $seedLabel
            seed_sha256 = $seedSha
            maximum_world_build_count = 1
            maximum_outer_solver_steps = 2
            same_identity_rerun_permitted = $false
            operation_lock = Get-SporeSporeLocomotionOperationLockPublicReceipt $lock
            physical_acceptance_authority = $false
            release_authority = $false
        }
        Write-CompactNativeJson -Path $attemptPath -Value $attempt
        $process = Invoke-SporeSporeGodotReceiptTerminatedProcess `
            -FileName $consolePath `
            -Arguments @(
                "--headless", "--path", $repoRoot, "--fixed-fps", "120", "--script",
                ("res://" + $workerRelative.Replace("\", "/")), "--",
                "--mode=physical", "--source_commit=$($repository.head)",
                "--authorization_sha256=$($authorization.raw_sha256)",
                "--attempt_id=$attemptId", "--nonce=$nonce", "--seed=$seed",
                "--seed_label=$seedLabel", "--seed_sha256=$seedSha",
                "--report_path=$reportPath"
            ) `
            -WorkingDirectory $repoRoot `
            -ReadyMarkerPrefix $readyMarker `
            -ExpectedNonce $nonce `
            -Environment @{
                SPORESPORE_R24D158_SOURCE_COMMIT = $repository.head
                SPORESPORE_R24D158_AUTHORIZATION_SHA256 = $authorization.raw_sha256
                SPORESPORE_R24D158_ATTEMPT_ID = $attemptId
                SPORESPORE_R24D158_EXECUTION_NONCE = $nonce
                SPORESPORE_R24D158_SUPERVISED_TERMINATION = "1"
                SPORESPORE_R24D158_TERMINATION_NONCE = $nonce
            } `
            -TimeoutSeconds ([int]$runner.timeout_seconds)
        $stdoutPath = Join-Path $attemptRoot "godot.stdout.log"
        $stderrPath = Join-Path $attemptRoot "godot.stderr.log"
        [IO.File]::WriteAllText(
            $stdoutPath, [string]$process.stdout, [Text.UTF8Encoding]::new($false)
        )
        [IO.File]::WriteAllText(
            $stderrPath, [string]$process.stderr, [Text.UTF8Encoding]::new($false)
        )
        $rawLines = @(([string]$process.stdout -split "`r?`n") | Where-Object {
            $_.StartsWith($rawMarker, [StringComparison]::Ordinal)
        })
        $raw = $null
        if ($rawLines.Count -eq 1) {
            try {
                $raw = $rawLines[0].Substring($rawMarker.Length) |
                    ConvertFrom-Json -AsHashtable -Depth 100
            } catch { $raw = $null }
        }
        $report = $null
        if (Test-Path -LiteralPath $reportPath -PathType Leaf) {
            try {
                $report = Get-Content -Raw -LiteralPath $reportPath |
                    ConvertFrom-Json -AsHashtable -Depth 100
            } catch { $report = $null }
        }
        $engineHealth = Get-SporeSporeGodotEngineHealthProjection `
            -StandardError ([string]$process.stderr)
        $sourceSuccessorBindingValid = $true
        if ($runner.Contains("source_successor_id")) {
            $sourceSuccessorBindingValid = (
                $null -ne $raw -and $null -ne $report -and
                [string]$raw.source_successor_id -ceq
                    [string]$runner.source_successor_id -and
                [string]$report.source_successor_id -ceq
                    [string]$runner.source_successor_id
            )
        }
        $worldBindingValid = $true
        if ($runner.Contains("expected_world_binding")) {
            $worldBindingValid = $null -ne $report -and
                $report.Contains("world_binding")
            if ($worldBindingValid) {
                foreach ($key in @($runner.expected_world_binding.Keys)) {
                    $worldBindingValid = (
                        $worldBindingValid -and
                        $report.world_binding.Contains($key) -and
                        [object]::Equals(
                            $report.world_binding[$key],
                            $runner.expected_world_binding[$key]
                        )
                    )
                }
            }
        }
        $terminalDeactivationCountValid = $true
        if ($runner.Contains("terminal_physics_server_deactivation_count")) {
            $expectedDeactivationCount = [int](
                $runner.terminal_physics_server_deactivation_count
            )
            $terminalDeactivationCountValid = (
                $null -ne $raw -and $null -ne $report -and
                [int]$raw.terminal_physics_server_deactivation_count -eq
                    $expectedDeactivationCount -and
                [int]$report.execution.terminal_physics_server_deactivation_count -eq
                    $expectedDeactivationCount
            )
        }
        $bindingValid = (
            $sourceSuccessorBindingValid -and $worldBindingValid -and
            $terminalDeactivationCountValid -and
            $null -ne $raw -and $null -ne $report -and
            [string]$raw.gate_id -ceq $workerGateId -and
            [string]$raw.source_commit -ceq $repository.head -and
            [string]$raw.authorization_sha256 -ceq $authorization.raw_sha256 -and
            [string]$raw.attempt_id -ceq $attemptId -and
            [string]$raw.execution_nonce -ceq $nonce -and
            [int]$raw.seed -eq $seed -and [string]$raw.seed_sha256 -ceq $seedSha -and
            [string]$report.gate_id -ceq $workerGateId -and
            [string]$report.source_commit -ceq $repository.head -and
            [string]$report.authorization_sha256 -ceq $authorization.raw_sha256 -and
            [string]$report.attempt_id -ceq $attemptId -and
            [string]$report.execution_nonce -ceq $nonce
        )
        $observationValid = (
            $bindingValid -and [bool]$raw.ok -and [bool]$report.ok -and
            [string]$raw.status -ceq "valid_complete_native_observation_smoke" -and
            [string]$report.status -ceq "valid_complete_native_observation_smoke" -and
            [int]$raw.model_construction_count -eq 1 -and
            [int]$raw.world_attempt_count -eq 1 -and
            [int]$raw.world_build_count -eq 1 -and
            [int]$raw.solver_step_count -eq 2 -and
            [int]$raw.native_readback_count -eq 2 -and
            [int]$raw.in_run_physical_invariant_step_count -eq 2 -and
            [bool]$raw.all_in_run_physical_invariants_passed -and
            @($report.samples).Count -eq 2 -and
            [int]$report.execution.solver_step_count -eq 2 -and
            [int]$report.execution.native_readback_count -eq 2 -and
            [bool]$report.execution.all_in_run_physical_invariants_passed -and
            [bool]$report.claims.native_v6_field_population_observed -and
            -not [bool]$report.claims.prone_to_standing_claimed -and
            -not [bool]$report.claims.physical_acceptance_authority -and
            -not [bool]$report.claims.release_authority
        )
        $validComplete = (
            $observationValid -and [int]$process.exit_code -eq 0 -and
            [bool]$process.termination_protocol_valid -and [bool]$engineHealth.passed
        )
        $status = if ($validComplete) {
            "valid_complete_native_observation_smoke"
        } else { "invalid_or_incomplete_native_observation_smoke" }
        $terminal = [ordered]@{
            schema_version = [string]$runner.terminal_schema
            gate_id = $gateId
            physical_question_gate_id = $workerGateId
            question_class = "development"
            physical_question_kind = "native_observation_smoke"
            status = $status
            valid_complete = $validComplete
            attempt_id = $attemptId
            completed_utc = [DateTimeOffset]::UtcNow.ToString("o")
            source = $repository
            authorization = [ordered]@{
                path = [string]$authorization.path
                raw_sha256 = [string]$authorization.raw_sha256
                byte_length = [long]$authorization.byte_length
                source_freeze_commit = [string]$authorization.source_freeze_commit
                closure_audit_marker = [string]$closureAudit.marker
            }
            worker = [ordered]@{
                semantic_exit_code = [int]$process.exit_code
                host_exit_code = [int]$process.host_exit_code
                timed_out = [bool]$process.timed_out
                termination_protocol_valid = [bool]$process.termination_protocol_valid
                raw_marker_count = $rawLines.Count
                raw_binding_valid = $bindingValid
                engine_health = $engineHealth
            }
            artifacts = [ordered]@{
                report = if ($null -ne $report) { [ordered]@{
                    path = $reportPath.Replace("\", "/")
                    raw_sha256 = Get-CompactNativeSha256 $reportPath
                    byte_length = (Get-Item -LiteralPath $reportPath).Length
                } } else { $null }
                stdout = [ordered]@{
                    path = $stdoutPath.Replace("\", "/")
                    raw_sha256 = Get-CompactNativeSha256 $stdoutPath
                    byte_length = (Get-Item -LiteralPath $stdoutPath).Length
                }
                stderr = [ordered]@{
                    path = $stderrPath.Replace("\", "/")
                    raw_sha256 = Get-CompactNativeSha256 $stderrPath
                    byte_length = (Get-Item -LiteralPath $stderrPath).Length
                }
            }
            same_identity_rerun_permitted = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
        $terminalPath = Join-Path $attemptRoot "terminal.json"
        Write-CompactNativeJson -Path $terminalPath -Value $terminal
        $attempt.status = $status
        $attempt.completed_utc = [string]$terminal.completed_utc
        $attempt.terminal_path = "terminal.json"
        Write-CompactNativeJson -Path $attemptPath -Value $attempt
        $summary = [ordered]@{
            schema_version = [string]$runner.supervisor_result_schema
            gate_id = $gateId
            physical_question_gate_id = $workerGateId
            ok = $validComplete
            status = $status
            attempt_id = $attemptId
            evidence_root = $attemptRoot.Replace("\", "/")
            terminal_sha256 = Get-CompactNativeSha256 $terminalPath
            report_sha256 = if ($null -ne $report) {
                Get-CompactNativeSha256 $reportPath
            } else { $null }
            model_construction_count = if ($null -ne $raw) {
                [int]$raw.model_construction_count
            } else { 0 }
            world_attempt_count = if ($null -ne $raw) {
                [int]$raw.world_attempt_count
            } else { 0 }
            world_build_count = if ($null -ne $raw) {
                [int]$raw.world_build_count
            } else { 0 }
            solver_step_count = if ($null -ne $raw) {
                [int]$raw.solver_step_count
            } else { 0 }
            native_readback_count = if ($null -ne $raw) {
                [int]$raw.native_readback_count
            } else { 0 }
            physical_acceptance_authority = $false
            release_authority = $false
        }
        Write-Output ($supervisorMarker + (
            $summary | ConvertTo-Json -Depth 20 -Compress
        ))
        if ($validComplete) { return 0 }
        return 1
    } finally {
        Exit-SporeSporeLocomotionOperationLock -Receipt $lock
    }
}

try {
    if ($Mode -ceq "Preflight") {
        $receipt = Invoke-CompactNativePreflight
        Write-Output ($supervisorMarker + (
            $receipt | ConvertTo-Json -Depth 20 -Compress
        ))
        exit 0
    }
    $exitCode = Invoke-CompactNativePhysical
    exit $exitCode
} catch {
    Write-Error $_
    exit 1
}

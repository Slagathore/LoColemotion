#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("worker", "evaluator", "supervisor")]
    [string]$Role,
    [string]$Python = "",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$PowerShell = "pwsh"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$mujocoPython = Join-Path $repoRoot (
    "sdk\adapters\mujoco\.venv\Scripts\python.exe"
)
$implementationPath = Join-Path $turningRoot (
    "r23d74_production_route_three_engine_turning_implementation_v1.json"
)
$implementationMaterializer = Join-Path $turningRoot (
    "materialize_r23d74_implementation.py"
)
$manifestMaterializer = Join-Path $turningRoot (
    "materialize_r23d74_campaign_attestation_manifest.py"
)
$evaluatorPath = Join-Path $turningRoot (
    "r23d74_production_route_three_engine_turning_evaluator.py"
)
$supervisorPath = Join-Path $repoRoot "sdk\run_qsdk_r23d74_supervisor.ps1"
$campaignId = "QSDK-R23D74-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION"

function Assert-R23D74Role([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D74 $Role ROLE: $Message" }
}

function Resolve-R23D74RoleApplication([string]$Value, [string]$Fallback) {
    $candidate = if ([string]::IsNullOrWhiteSpace($Value)) {
        $Fallback
    } else {
        $Value
    }
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return [IO.Path]::GetFullPath($candidate)
    }
    $command = Get-Command $candidate -CommandType Application -ErrorAction Stop |
        Select-Object -First 1
    return [IO.Path]::GetFullPath([string]$command.Source)
}

function Get-R23D74RoleSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Invoke-R23D74RoleProcess(
    [string]$FileName,
    [string[]]$Arguments,
    [int]$TimeoutSeconds = 300
) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FileName
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) {
        try { $process.Kill($true) } catch {}
        [void]$process.WaitForExit(10000)
    } else {
        $process.WaitForExit()
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($timedOut) { 124 } else { $process.ExitCode }
    $process.Dispose()
    return [ordered]@{
        exit_code = [int]$exitCode
        timed_out = [bool]$timedOut
        stdout = [string]$stdout
        stderr = [string]$stderr
    }
}

function Get-R23D74RoleMarker([string]$Text, [string]$Prefix) {
    $lines = @($Text -split "`r?`n" | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D74Role ($lines.Count -eq 1) (
        "expected one '$Prefix' marker, observed $($lines.Count)"
    )
    return $lines[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

$pythonHost = Resolve-R23D74RoleApplication $Python $mujocoPython
$powerShellHost = Resolve-R23D74RoleApplication $PowerShell "pwsh"
$godotHost = Resolve-R23D74RoleApplication $Godot $Godot

Assert-R23D74Role (
    (& git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot.TrimEnd("\", "/") -and
    (& git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @(
    $implementationPath,
    $implementationMaterializer,
    $manifestMaterializer,
    $evaluatorPath,
    $supervisorPath
)) {
    Assert-R23D74Role (Test-Path -LiteralPath $path -PathType Leaf) (
        "role source is missing: $path"
    )
}

$implementation = Get-Content -LiteralPath $implementationPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D74Role (
    [string]$implementation.campaign_id -ceq $campaignId -and
    [string]$implementation.gate_id -ceq "QSDK-R23D74" -and
    [string]$implementation.question_class -ceq "finite_decision" -and
    [bool]$implementation.claims.implementation_complete -and
    [bool]$implementation.claims.complete_zero_world_gate_passed -and
    [bool]$implementation.claims.complete_authorization_ghost_passed -and
    [bool]$implementation.claims.all_four_predecessor_replays_passed -and
    -not [bool]$implementation.claims.full_seeded_world_ghost_used -and
    -not [bool]$implementation.claims.physical_campaign_opened -and
    @($implementation.ordered_cell_ids).Count -eq 9 -and
    [int]$implementation.dependency_inventory.transitive_path_count -eq
        @($implementation.dependency_digests.Keys).Count -and
    @($implementation.dependency_digests.Keys).Count -gt 0
) "implementation authority changed"

$receipt = switch ($Role) {
    "worker" {
        $implementationCheck = Invoke-R23D74RoleProcess $pythonHost @(
            $implementationMaterializer, "check"
        )
        $manifestCheck = Invoke-R23D74RoleProcess $pythonHost @(
            $manifestMaterializer, "check"
        )
        Assert-R23D74Role (
            [int]$implementationCheck.exit_code -eq 0 -and
            -not [bool]$implementationCheck.timed_out -and
            [string]$implementationCheck.stdout -cmatch
                "QSDK_R23D74_IMPLEMENTATION" -and
            [int]$manifestCheck.exit_code -eq 0 -and
            -not [bool]$manifestCheck.timed_out -and
            [string]$manifestCheck.stdout -cmatch
                "QSDK_R23D74_ATTESTATION_MANIFEST"
        ) (
            "materialized worker/manifest binding drifted: " +
            "$($implementationCheck.stderr) $($manifestCheck.stderr)"
        )
        $workerCount = 0
        foreach ($engineId in @("godot_jolt", "rapier_parry", "mujoco")) {
            $worker = $implementation.workers[$engineId]
            $path = Join-Path $repoRoot ([string]$worker.path)
            Assert-R23D74Role (
                (Test-Path -LiteralPath $path -PathType Leaf) -and
                (Get-R23D74RoleSha256 $path) -ceq [string]$worker.raw_sha256 -and
                [bool]$worker.shared_native_kernel_reused -and
                [bool]$worker.implementation_complete -and
                -not [bool]$worker.physical_execution_authorized -and
                -not [bool]$worker.physical_acceptance_authority
            ) "worker binding changed: $engineId"
            $workerCount += 1
        }
        [ordered]@{
            schema_version = "sporespore_qsdk_r23d74_worker_role_gate_v1"
            bound_worker_count = $workerCount
            complete_dependency_inventory_bound = $true
            authorization_receipt_contract_bound = $true
            returned_before_model = $true
        }
    }
    "evaluator" {
        Assert-R23D74Role (
            [string]$implementation.evaluator.path -ceq
                "sdk/turning/r23d74_production_route_three_engine_turning_evaluator.py" -and
            [string]$implementation.evaluator.raw_sha256 -ceq
                (Get-R23D74RoleSha256 $evaluatorPath) -and
            [bool]$implementation.evaluator.accepted_algorithm_rebound_without_threshold_change -and
            (@($implementation.evaluator.outcome_classes) -join "|") -ceq
                "positive|negative|invalid|incomplete"
        ) "evaluator binding changed"
        $compile = Invoke-R23D74RoleProcess $pythonHost @(
            "-m", "py_compile", $evaluatorPath
        )
        Assert-R23D74Role (
            [int]$compile.exit_code -eq 0 -and -not [bool]$compile.timed_out
        ) "evaluator compile failed: $($compile.stderr)"
        [ordered]@{
            schema_version = "sporespore_qsdk_r23d74_evaluator_role_gate_v1"
            accepted_algorithm_bound_without_threshold_change = $true
            outcome_class_count = 4
            returned_before_model = $true
        }
    }
    "supervisor" {
        $process = Invoke-R23D74RoleProcess $powerShellHost @(
            "-NoLogo", "-NoProfile", "-File", $supervisorPath,
            "-RolePreflight",
            "-Python", $pythonHost,
            "-Godot", $godotHost,
            "-PowerShell", $powerShellHost
        ) 600
        Assert-R23D74Role (
            [int]$process.exit_code -eq 0 -and -not [bool]$process.timed_out
        ) "supervisor role preflight failed: $($process.stderr) $($process.stdout)"
        $supervisor = Get-R23D74RoleMarker $process.stdout (
            "QSDK_R23D74_SUPERVISOR_ROLE_PREFLIGHT "
        )
        Assert-R23D74Role (
            [string]$supervisor.campaign_id -ceq $campaignId -and
            [string]$supervisor.gate_id -ceq "QSDK-R23D74" -and
            [string]$supervisor.question_class -ceq "finite_decision" -and
            [int]$supervisor.implementation_dependency_count -eq
                @($implementation.dependency_digests.Keys).Count -and
            [int]$supervisor.terminal_transport_control_count -eq 6 -and
            [int]$supervisor.success_terminal_transport_control_count -eq 3 -and
            [int]$supervisor.failure_terminal_transport_control_count -eq 3 -and
            [bool]$supervisor.supervisor_physical_entry_implemented -and
            [bool]$supervisor.returned_before_model -and
            [int]$supervisor.model_construction_count -eq 0 -and
            [int]$supervisor.world_attempt_count -eq 0 -and
            [int]$supervisor.world_build_count -eq 0 -and
            -not [bool]$supervisor.physical_execution_authorized -and
            -not [bool]$supervisor.physical_acceptance_authority
        ) "supervisor role receipt changed"
        [ordered]@{
            schema_version = "sporespore_qsdk_r23d74_supervisor_role_gate_v1"
            implementation_dependency_count =
                [int]$supervisor.implementation_dependency_count
            terminal_transport_control_count =
                [int]$supervisor.terminal_transport_control_count
            success_terminal_transport_control_count =
                [int]$supervisor.success_terminal_transport_control_count
            failure_terminal_transport_control_count =
                [int]$supervisor.failure_terminal_transport_control_count
            returned_before_model = $true
        }
    }
}

$receipt["campaign_id"] = $campaignId
$receipt["gate_id"] = "QSDK-R23D74"
$receipt["question_class"] = "finite_decision"
$receipt["role"] = $Role
$receipt["model_construction_count"] = 0
$receipt["world_attempt_count"] = 0
$receipt["world_build_count"] = 0
$receipt["physical_execution_authorized"] = $false
$receipt["physical_acceptance_authority"] = $false

$prefix = switch ($Role) {
    "worker" { "QSDK_R23D74_CAMPAIGN_WORKER_ROLE_PASS " }
    "evaluator" { "QSDK_R23D74_CAMPAIGN_EVALUATOR_ROLE_PASS " }
    default { "QSDK_R23D74_CAMPAIGN_SUPERVISOR_ROLE_PASS " }
}
Write-Output ($prefix + ($receipt | ConvertTo-Json -Compress -Depth 100))

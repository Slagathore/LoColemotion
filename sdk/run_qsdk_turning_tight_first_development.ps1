#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
    [ValidateSet(
        "tight_gated_acquisition_v1",
        "tight_gated_acquisition_active600_v2"
    )]
    [string]$CandidateId = "tight_gated_acquisition_v1"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

if ($PreflightOnly -and $RunPhysical) {
    throw "Tight-first development accepts only one execution mode."
}
if (-not $PreflightOnly -and -not $RunPhysical) { $PreflightOnly = $true }

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$pythonRoot = Join-Path $sdkRoot "python"
$turningRoot = Join-Path $sdkRoot "turning"
$python = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$manifest = Join-Path $sdkRoot "Cargo.toml"
$releaseLibrary = Join-Path $sdkRoot "target\release\sporespore_locomotion_core.dll"
$materializer = Join-Path $sdkRoot "r23d3_reproducible_runtime_materialization.ps1"
$operationLockPath = Join-Path $sdkRoot "locomotion_operation_lock.ps1"
$marker = "QSDK_TURNING_TIGHT_FIRST_DEVELOPMENT "
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$candidateConfiguration = @{
    tight_gated_acquisition_v1 = [ordered]@{
        module = "sporespore_mujoco_adapter.qsdk_turning_tight_first_development"
        run_slug = "turning-tight-first"
        expected_test_count = 10
        test_modules = @(
            "sdk.turning.test_terminal_tight_first_development",
            "test_qsdk_turning_tight_first_development"
        )
    }
    tight_gated_acquisition_active600_v2 = [ordered]@{
        module = (
            "sporespore_mujoco_adapter." +
            "qsdk_turning_tight_first_horizon_development"
        )
        run_slug = "turning-tight-first-horizon"
        expected_test_count = 18
        test_modules = @(
            "sdk.turning.test_terminal_tight_first_development",
            "sdk.turning.test_terminal_tight_first_horizon_development",
            "test_qsdk_turning_tight_first_development",
            "test_qsdk_turning_tight_first_horizon_development"
        )
    }
}
$configuration = $candidateConfiguration[$CandidateId]
$module = [string]$configuration.module

function Assert-TightFirstDevelopment([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-TightFirstDevelopmentSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Invoke-TightFirstGit([string[]]$Arguments) {
    $output = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-TightFirstDevelopment ($LASTEXITCODE -eq 0) (
        "Tight-first Git command failed: git $($Arguments -join ' ') :: " +
        ($output -join "`n")
    )
    return ($output -join "`n").Trim()
}

function Invoke-TightFirstPython {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][int]$TimeoutSeconds
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $python
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment["SPORESPORE_LOCOMOTION_LIBRARY"] = $releaseLibrary
    $start.Environment["PYTHONPATH"] = (
        $mujocoRoot + [IO.Path]::PathSeparator +
        $pythonRoot + [IO.Path]::PathSeparator +
        $turningRoot
    )
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-TightFirstDevelopment $process.Start() (
        "Tight-first Python process did not start."
    )
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) {
        $process.Kill($true)
        $process.WaitForExit()
    }
    return [ordered]@{
        exit_code = $process.ExitCode
        timed_out = $timedOut
        stdout = $stdoutTask.GetAwaiter().GetResult()
        stderr = $stderrTask.GetAwaiter().GetResult()
    }
}

function Get-TightFirstMarker([Collections.IDictionary]$Execution) {
    $lines = @(([string]$Execution.stdout -split "\r?\n") | Where-Object {
        $_.StartsWith($marker, [StringComparison]::Ordinal)
    })
    Assert-TightFirstDevelopment ($lines.Count -eq 1) (
        "Tight-first process did not emit exactly one terminal marker."
    )
    return $lines[0].Substring($marker.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

foreach ($path in @(
    $python,
    $manifest,
    $materializer,
    $operationLockPath,
    (Join-Path $turningRoot "terminal_tight_first_development.py"),
    (Join-Path $turningRoot "test_terminal_tight_first_development.py"),
    (Join-Path $turningRoot "terminal_tight_first_horizon_development.py"),
    (Join-Path $turningRoot "test_terminal_tight_first_horizon_development.py"),
    (Join-Path $mujocoRoot (
        "sporespore_mujoco_adapter\qsdk_turning_tight_first_development.py"
    )),
    (Join-Path $mujocoRoot "test_qsdk_turning_tight_first_development.py"),
    (Join-Path $mujocoRoot (
        "sporespore_mujoco_adapter\qsdk_turning_tight_first_horizon_development.py"
    )),
    (Join-Path $mujocoRoot "test_qsdk_turning_tight_first_horizon_development.py")
)) {
    Assert-TightFirstDevelopment (Test-Path -LiteralPath $path -PathType Leaf) (
        "Tight-first development input is missing: $path"
    )
}

Assert-TightFirstDevelopment (
    (Invoke-TightFirstGit @("rev-parse", "--show-toplevel")) -ceq
        $repoRoot.Replace("\", "/") -and
    (Invoke-TightFirstGit @("remote", "get-url", "origin")) -ceq $expectedRemote
) "Tight-first development repository identity changed."

. $materializer
. $operationLockPath
$sourceCommit = Invoke-TightFirstGit @("rev-parse", "HEAD")
$lockRole = if ($RunPhysical) { "physical" } else { "conformance" }
$lock = Enter-SporeSporeLocomotionOperationLock -Role $lockRole
Assert-TightFirstDevelopment ([bool]$lock.acquired) (
    "Tight-first development could not acquire the global locomotion lock."
)

try {
    $build = Invoke-SporeSporeR23D3PinnedCargo `
        -RepoRoot $repoRoot `
        -SourceCommit $sourceCommit `
        -TargetRoot (Join-Path $sdkRoot "target") `
        -CargoArguments @(
            "build", "--quiet", "--release", "--locked", "--offline",
            "--manifest-path", $manifest,
            "--package", "sporespore-locomotion-core"
        )
    Assert-TightFirstDevelopment (
        [int]$build.exit_code -eq 0 -and
        (Test-Path -LiteralPath $releaseLibrary -PathType Leaf)
    ) "Tight-first development portable-core build failed."

    $testArguments = @("-m", "unittest", "-v") + @(
        $configuration.test_modules
    )
    $tests = Invoke-TightFirstPython `
        -TimeoutSeconds 120 `
        -Arguments $testArguments
    if ($tests.stdout) { Write-Host ([string]$tests.stdout).TrimEnd() }
    if ($tests.stderr) { Write-Host ([string]$tests.stderr).TrimEnd() }
    Assert-TightFirstDevelopment (
        -not [bool]$tests.timed_out -and [int]$tests.exit_code -eq 0
    ) "Tight-first development unit tests failed."

    $preflight = Invoke-TightFirstPython -TimeoutSeconds 60 -Arguments @(
        "-m", $module, "preflight", "--source-commit", $sourceCommit
    )
    if ($preflight.stdout) { Write-Host ([string]$preflight.stdout).TrimEnd() }
    if ($preflight.stderr) { Write-Host ([string]$preflight.stderr).TrimEnd() }
    $preflightReceipt = Get-TightFirstMarker $preflight
    Assert-TightFirstDevelopment (
        -not [bool]$preflight.timed_out -and
        [int]$preflight.exit_code -eq 0 -and
        [string]$preflightReceipt.candidate_id -ceq $CandidateId -and
        [int]$preflightReceipt.world_build_count -eq 0 -and
        [bool]$preflightReceipt.development_only -and
        -not [bool]$preflightReceipt.validation_authority -and
        -not [bool]$preflightReceipt.physical_acceptance_authority -and
        [string]$preflightReceipt.frozen_r23d13_production_refusal -ceq
            "QSDK_R23D13_MJC_CLOSED"
    ) "Tight-first development preflight receipt changed."

    if (-not $RunPhysical) {
        Write-Host (
            "QSDK_TURNING_TIGHT_FIRST_DEVELOPMENT_PREFLIGHT_PASS " +
            "candidate=$CandidateId " +
            "tests=$([int]$configuration.expected_test_count) " +
            "models=0 worlds=0 " +
            "development_only=True validation_authority=False " +
            "physical_authority=False"
        )
        return
    }

    Assert-TightFirstDevelopment (
        [string]::IsNullOrWhiteSpace((Invoke-TightFirstGit @("status", "--porcelain")))
    ) "Tight-first physical development requires a clean source tree."
    $originMain = Invoke-TightFirstGit @("rev-parse", "origin/main")
    $liveOutput = @(& git ls-remote origin refs/heads/main 2>&1)
    Assert-TightFirstDevelopment ($LASTEXITCODE -eq 0) (
        "Tight-first live GitHub main lookup failed: $($liveOutput -join "`n")"
    )
    $liveMain = ([string]$liveOutput[0] -split "\s+")[0]
    Assert-TightFirstDevelopment (
        $sourceCommit -ceq $originMain -and $sourceCommit -ceq $liveMain
    ) "Tight-first physical development requires local/origin/live source equality."

    $evidenceRoot = [IO.Path]::GetFullPath((Join-Path (
        Split-Path -Parent $repoRoot
    ) "SporeSpore_Evidence\development"))
    [void][IO.Directory]::CreateDirectory($evidenceRoot)
    $runId = "$([string]$configuration.run_slug)-{0}-{1}" -f (
        $sourceCommit.Substring(0, 8)
    ), [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ")
    $runRoot = Join-Path $evidenceRoot $runId
    [void][IO.Directory]::CreateDirectory($runRoot)
    $results = @()
    foreach ($arm in @("positive_heading", "negative_heading")) {
        $armRoot = Join-Path $runRoot $arm
        $execution = Invoke-TightFirstPython -TimeoutSeconds 180 -Arguments @(
            "-m", $module, "run", "--arm-id", $arm,
            "--source-commit", $sourceCommit, "--output-root", $armRoot
        )
        $stdoutPath = Join-Path $runRoot "$arm.stdout.log"
        $stderrPath = Join-Path $runRoot "$arm.stderr.log"
        [IO.File]::WriteAllText($stdoutPath, [string]$execution.stdout, (
            [Text.UTF8Encoding]::new($false)
        ))
        [IO.File]::WriteAllText($stderrPath, [string]$execution.stderr, (
            [Text.UTF8Encoding]::new($false)
        ))
        $receipt = Get-TightFirstMarker $execution
        $receipt["process_exit_code"] = [int]$execution.exit_code
        $receipt["process_timed_out"] = [bool]$execution.timed_out
        $receipt["stdout_path"] = $stdoutPath
        $receipt["stdout_raw_sha256"] = Get-TightFirstDevelopmentSha256 $stdoutPath
        $receipt["stderr_path"] = $stderrPath
        $receipt["stderr_raw_sha256"] = Get-TightFirstDevelopmentSha256 $stderrPath
        $results += $receipt
        Assert-TightFirstDevelopment (
            -not [bool]$execution.timed_out -and [int]$execution.exit_code -eq 0
        ) "Tight-first physical development failed for $arm; evidence retained at $runRoot"
    }

    $aggregate = [ordered]@{
        schema_version = "sporespore_qsdk_turning_tight_first_development_aggregate_v1"
        run_id = $runId
        source_commit = $sourceCommit
        candidate_id = $CandidateId
        ordered_arm_ids = @("positive_heading", "negative_heading")
        results = $results
        declared_world_count = 2
        observed_world_count = [int](($results | ForEach-Object {
            [int]$_['world_build_count']
        } | Measure-Object -Sum).Sum)
        both_development_screens_passed = @($results | Where-Object {
            [bool]$_['screen_conjunction']['development_screen_passed']
        }).Count -eq 2
        development_only = $true
        outcomes_are_exposed = $true
        candidate_selection_authority = $true
        validation_authority = $false
        cross_engine_equivalence = $false
        portable_basic_turning = $false
        physical_acceptance_authority = $false
        release_authorized = $false
    }
    $aggregatePath = Join-Path $runRoot "aggregate.json"
    [IO.File]::WriteAllText(
        $aggregatePath,
        ($aggregate | ConvertTo-Json -Depth 100) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
    Write-Host (
        "QSDK_TURNING_TIGHT_FIRST_DEVELOPMENT_PHYSICAL_COMPLETE " +
        "candidate=$CandidateId " +
        "run_root=$runRoot aggregate_sha256=$(Get-TightFirstDevelopmentSha256 $aggregatePath) " +
        "worlds=$($aggregate.observed_world_count) " +
        "both_passed=$($aggregate.both_development_screens_passed) " +
        "development_only=True validation_authority=False " +
        "physical_authority=False"
    )
} finally {
    Exit-SporeSporeLocomotionOperationLock $lock
}

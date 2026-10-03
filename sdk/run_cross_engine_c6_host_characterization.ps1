[CmdletBinding()]
param(
    [ValidateSet("rapier", "mujoco", "both")]
    [string]$HostAdapter = "both",
    [switch]$PreflightOnly,
    [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $sdkRoot)
)
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$preregistrationPath = Join-Path (
    $sdkRoot
) "cross_engine_c6_host_characterization_r2_preregistration.json"
$basePreregistrationPath = Join-Path (
    $sdkRoot
) "cross_engine_c6_host_characterization_preregistration.json"
$predecessorClosurePath = Join-Path (
    $sdkRoot
) "cross_engine_c6_host_characterization_closure.json"
$r1PreregistrationPath = Join-Path (
    $sdkRoot
) "cross_engine_c6_host_characterization_r1_preregistration.json"
$r1ClosurePath = Join-Path (
    $sdkRoot
) "cross_engine_c6_host_characterization_r1_closure.json"
$r2ClosurePath = Join-Path (
    $sdkRoot
) "cross_engine_c6_host_characterization_r2_closure.json"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$mujocoPython = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$expectedPreregistrationSchema = (
    "sporespore_cross_engine_c6_host_characterization_" +
    "r2_preregistration_v1"
)
$expectedPreregistrationStatus = (
    "frozen_before_first_c6_hc1_r2_physics_world"
)
$expectedPreregistrationRawSha256 = (
    "sha256:" +
    "690dc6e5ed4d8d0be2c0c5e4eb294d8160f9ac9ec4309de7ded82aa89951f451"
)
$expectedBasePreregistrationRawSha256 = (
    "sha256:" +
    "2ff51bc87745d84f2d4d0521005098ead3bef20e691b25f9f49c0cf7eadade8e"
)
$expectedPredecessorClosureRawSha256 = (
    "sha256:" +
    "dadd1e8a44dca2e66136c496a91bf2d4e579300459af4f0884b9040aa3faff21"
)
$expectedR1PreregistrationRawSha256 = (
    "sha256:" +
    "a5ebb5c3fa827ec6d4952326f63ef68a87134d2cea71186ca15bd3174df84e11"
)
$expectedR1ClosureRawSha256 = (
    "sha256:" +
    "c4fac9d63428e747ac052169d97b344e2b774ce728f1a368f3e842f70248da12"
)

function Assert-Exact {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory)][scriptblock]$Command,
        [Parameter(Mandatory)][string]$Failure
    )
    & $Command
    Assert-Exact ($LASTEXITCODE -eq 0) $Failure
}

function Invoke-LoggedProcess {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$StdoutPath,
        [Parameter(Mandatory)][string]$StderrPath
    )
    Assert-Exact (
        -not (Test-Path -LiteralPath $StdoutPath) -and
        -not (Test-Path -LiteralPath $StderrPath)
    ) "Refusing to overwrite a C6-HC1-R2 supervisor artifact"
    $process = Start-Process `
        -FilePath $FilePath `
        -ArgumentList $ArgumentList `
        -WorkingDirectory $WorkingDirectory `
        -WindowStyle Hidden `
        -Wait `
        -PassThru `
        -RedirectStandardOutput $StdoutPath `
        -RedirectStandardError $StderrPath
    return $process.ExitCode
}

Assert-Exact (
    (Test-Path -LiteralPath $preregistrationPath -PathType Leaf) -and
    (Test-Path -LiteralPath $basePreregistrationPath -PathType Leaf) -and
    (Test-Path -LiteralPath $predecessorClosurePath -PathType Leaf) -and
    (Test-Path -LiteralPath $r1PreregistrationPath -PathType Leaf) -and
    (Test-Path -LiteralPath $r1ClosurePath -PathType Leaf)
) "C6-HC1-R2 declaration or predecessor source is missing"
$preregistrationRawSha256 = "sha256:" + (
    Get-FileHash -Algorithm SHA256 -LiteralPath $preregistrationPath
).Hash.ToLowerInvariant()
$basePreregistrationRawSha256 = "sha256:" + (
    Get-FileHash -Algorithm SHA256 -LiteralPath $basePreregistrationPath
).Hash.ToLowerInvariant()
$predecessorClosureRawSha256 = "sha256:" + (
    Get-FileHash -Algorithm SHA256 -LiteralPath $predecessorClosurePath
).Hash.ToLowerInvariant()
$r1PreregistrationRawSha256 = "sha256:" + (
    Get-FileHash -Algorithm SHA256 -LiteralPath $r1PreregistrationPath
).Hash.ToLowerInvariant()
$r1ClosureRawSha256 = "sha256:" + (
    Get-FileHash -Algorithm SHA256 -LiteralPath $r1ClosurePath
).Hash.ToLowerInvariant()
Assert-Exact (
    $preregistrationRawSha256 -ceq
        $expectedPreregistrationRawSha256 -and
    $basePreregistrationRawSha256 -ceq
        $expectedBasePreregistrationRawSha256 -and
    $predecessorClosureRawSha256 -ceq
        $expectedPredecessorClosureRawSha256 -and
    $r1PreregistrationRawSha256 -ceq
        $expectedR1PreregistrationRawSha256 -and
    $r1ClosureRawSha256 -ceq $expectedR1ClosureRawSha256
) "C6-HC1-R2 declaration or predecessor hash changed"
$preregistration = (
    Get-Content -Raw -LiteralPath $preregistrationPath |
        ConvertFrom-Json
)
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        $expectedPreregistrationSchema -and
    [string]$preregistration.campaign_id -ceq
        "C6-HOST-CHARACTERIZATION-R2" -and
    [string]$preregistration.gate_id -ceq "C6-HC1-R2" -and
    [string]$preregistration.status -ceq
        $expectedPreregistrationStatus -and
    [string]$preregistration.base_preregistration.raw_sha256 -ceq
        $expectedBasePreregistrationRawSha256 -and
    [string]$preregistration.r1_preregistration.raw_sha256 -ceq
        $expectedR1PreregistrationRawSha256 -and
    [string]$preregistration.r1_closure.raw_sha256 -ceq
        $expectedR1ClosureRawSha256 -and
    [bool]$preregistration.preflight_contract.must_run_before_any_physics_world -and
    [bool]$preregistration.preflight_contract.perfect_synthetic_zero_failure_result_must_pass_full_integrity_gate -and
    [bool]$preregistration.preflight_contract.nonzero_failure_canary_must_fail_full_integrity_gate
) "C6-HC1-R2 preregistration identity or preflight boundary changed"
Assert-Exact (
    Test-Path -LiteralPath $mujocoPython -PathType Leaf
) "The project-local MuJoCo Python 3.11 environment is missing"

$requestedHosts = if ($HostAdapter -ceq "both") {
    @("rapier", "mujoco")
} else {
    @($HostAdapter)
}

# This block is deliberately first. Both binaries parse the exact frozen
# declaration and run the complete result-integrity gate against a perfect
# all-zero synthetic matrix plus a deliberately nonzero canary. Neither path
# constructs a physics world.
if ($requestedHosts -ccontains "rapier") {
    Push-Location -LiteralPath $sdkRoot
    try {
        Invoke-Checked `
            -Command {
                & cargo run `
                    --package sporespore-rapier-adapter `
                    --bin characterization `
                    --offline `
                    -- `
                    --preflight-only
            } `
            -Failure "Rapier C6-HC1-R2 zero-world preflight failed"
    } finally {
        Pop-Location
    }
}
if ($requestedHosts -ccontains "mujoco") {
    Push-Location -LiteralPath $mujocoRoot
    try {
        Invoke-Checked `
            -Command {
                & $mujocoPython `
                    -m sporespore_mujoco_adapter.characterization `
                    --preflight-only
            } `
            -Failure "MuJoCo C6-HC1-R2 zero-world preflight failed"
    } finally {
        Pop-Location
    }
}

if ($PreflightOnly) {
    Write-Host (
        "C6-HC1-R2 zero-world preflight passed for: " +
        ($requestedHosts -join ", ") +
        ". Perfect synthetic inputs passed; nonzero canaries failed closed."
    )
    return
}

Assert-Exact (
    -not (Test-Path -LiteralPath $r2ClosurePath -PathType Leaf)
) (
    "C6-HC1-R2 is closed and may not open another physics world; " +
    "audit sdk/cross_engine_c6_host_characterization_r2_closure.json instead"
)

$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $sourceCommit -cmatch "^[0-9a-f]{40}$"
) "Could not resolve the C6-HC1-R2 source commit"
$originMainCommit = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $sourceCommit -ceq $originMainCommit
) "C6-HC1-R2 physical execution requires HEAD == origin/main"
$sourceStatus = @(& git -C $repoRoot status --porcelain=v1)
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $sourceStatus.Count -eq 0
) "C6-HC1-R2 physical execution requires a clean worktree"

$shortCommit = $sourceCommit.Substring(0, 7)
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path (
        $evidenceRoot
    ) "c6-host-characterization-r2-$shortCommit"
}
$resolvedOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$evidencePrefix = $evidenceRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
Assert-Exact (
    $resolvedOutputRoot.StartsWith(
        $evidencePrefix,
        [StringComparison]::OrdinalIgnoreCase
    )
) "C6-HC1-R2 evidence must live beneath the durable SporeSpore_Evidence root"

$hostFailures = [System.Collections.Generic.List[string]]::new()
foreach ($hostName in $requestedHosts) {
    $hostRoot = Join-Path $resolvedOutputRoot $hostName
    Assert-Exact (
        -not (Test-Path -LiteralPath (Join-Path $hostRoot "report.json")) -and
        -not (Test-Path -LiteralPath (Join-Path $hostRoot "stdout.log")) -and
        -not (Test-Path -LiteralPath (Join-Path $hostRoot "stderr.log"))
    ) "Refusing to overwrite existing C6-HC1-R2 $hostName evidence"
}

foreach ($hostName in $requestedHosts) {
    $hostRoot = Join-Path $resolvedOutputRoot $hostName
    [void][System.IO.Directory]::CreateDirectory($hostRoot)
    $reportPath = Join-Path $hostRoot "report.json"
    $stdoutPath = Join-Path $hostRoot "stdout.log"
    $stderrPath = Join-Path $hostRoot "stderr.log"
    $processExitCode = $null
    try {
        if ($hostName -ceq "rapier") {
            $cargo = (Get-Command cargo -ErrorAction Stop).Source
            $processExitCode = Invoke-LoggedProcess `
                -FilePath $cargo `
                -ArgumentList @(
                    "run",
                    "--package",
                    "sporespore-rapier-adapter",
                    "--bin",
                    "characterization",
                    "--release",
                    "--offline",
                    "--",
                    "--source-commit",
                    $sourceCommit,
                    "--output",
                    $reportPath
                ) `
                -WorkingDirectory $sdkRoot `
                -StdoutPath $stdoutPath `
                -StderrPath $stderrPath
        } else {
            $processExitCode = Invoke-LoggedProcess `
                -FilePath $mujocoPython `
                -ArgumentList @(
                    "-m",
                    "sporespore_mujoco_adapter.characterization",
                    "--source-commit",
                    $sourceCommit,
                    "--output",
                    $reportPath
                ) `
                -WorkingDirectory $mujocoRoot `
                -StdoutPath $stdoutPath `
                -StderrPath $stderrPath
        }
    } catch {
        $hostFailures.Add(
            "$hostName process launch or supervision failed: $($_.Exception.Message)"
        )
        continue
    }
    if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
        $hostFailures.Add(
            "$hostName exited $processExitCode without retaining report.json"
        )
        continue
    }
    try {
        $report = (
            Get-Content -Raw -LiteralPath $reportPath |
                ConvertFrom-Json
        )
    } catch {
        $hostFailures.Add(
            "$hostName retained an unreadable report: $($_.Exception.Message)"
        )
        continue
    }
    $boundaryValid = (
        [string]$report.campaign_id -ceq
            "C6-HOST-CHARACTERIZATION-R2" -and
        [string]$report.gate_id -ceq "C6-HC1-R2" -and
        [string]$report.source.commit -ceq $sourceCommit -and
        [bool]$report.source.clean -and
        [bool]$report.source.matches_origin_main -and
        [bool]$report.preflight.perfect_synthetic_result_passed -and
        [bool]$report.preflight.nonzero_failure_canary_rejected -and
        [int]$report.preflight.world_build_count -eq 0 -and
        [string]$report.preregistration.raw_sha256 -ceq
            $expectedPreregistrationRawSha256 -and
        [string]$report.preregistration.base_raw_sha256 -ceq
            $expectedBasePreregistrationRawSha256 -and
        [string]$report.preregistration.predecessor_closure_raw_sha256 -ceq
            $expectedPredecessorClosureRawSha256 -and
        [string]$report.preregistration.r1_raw_sha256 -ceq
            $expectedR1PreregistrationRawSha256 -and
        [string]$report.preregistration.r1_closure_raw_sha256 -ceq
            $expectedR1ClosureRawSha256 -and
        [int]$report.world_attempt_count -eq 28 -and
        -not [bool]$report.controller_policy_authority -and
        -not [bool]$report.selected_policy_physical_authority -and
        -not [bool]$report.cross_engine_c6 -and
        -not [bool]$report.physical_acceptance_authority -and
        -not [bool]$report.release_authorized -and
        -not [bool]$report.completed_engine_neutral_sdk
    )
    if (-not $boundaryValid) {
        $hostFailures.Add(
            "$hostName report violated the frozen identity, count, or claim boundary"
        )
    }
    $reportPassed = [bool]$report.ok
    if ($reportPassed) {
        if (
            [int]$processExitCode -ne 0 -or
            [int]$report.world_build_count -ne 28 -or
            -not [bool]$report.material_characterization_complete_for_declared_grid -or
            -not [bool]$report.actuator_characterization_complete_for_declared_grid
        ) {
            $hostFailures.Add(
                "$hostName claimed success with an inconsistent process or grid"
            )
        }
    } else {
        if ([int]$processExitCode -eq 0) {
            $hostFailures.Add(
                "$hostName retained a negative report but exited successfully"
            )
        } else {
            $hostFailures.Add(
                "$hostName retained a complete negative report (exit $processExitCode)"
            )
        }
    }
    $sha256 = (
        Get-FileHash -Algorithm SHA256 -LiteralPath $reportPath
    ).Hash.ToLowerInvariant()
    Write-Host (
        "C6-HC1-R2 $hostName retained: $reportPath " +
        "sha256:$sha256"
    )
}

if ($hostFailures.Count -gt 0) {
    throw (
        "C6-HC1-R2 completed with retained failures:`n- " +
        ($hostFailures -join "`n- ")
    )
}

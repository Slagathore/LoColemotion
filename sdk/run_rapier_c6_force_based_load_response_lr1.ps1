[CmdletBinding()]
param(
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
) "rapier_c6_force_based_load_response_lr1_preregistration.json"
$predecessorClosurePath = Join-Path (
    $sdkRoot
) "rapier_c6_force_based_host_characterization_closure.json"
$cargoLockPath = Join-Path $sdkRoot "Cargo.lock"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_force_based_load_response_lr1_closure.json"
$expectedPreregistrationRawSha256 = (
    "sha256:" +
    "975e9205c46b3e718d3484a3e2d9185bddf4cd04da66ce326fc9bd14671dc031"
)
$expectedPredecessorClosureRawSha256 = (
    "sha256:" +
    "48a46e3533a45226f8dddab64d962814bd88e3526202d48242b0400ec9d32416"
)
$expectedCargoLockRawSha256 = (
    "sha256:" +
    "0b8c50eac716ebd82fd323fcf52dad357f2e3128c382be26f291a224139c5cbc"
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

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)

    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

foreach (
    $requiredPath in @(
        $preregistrationPath,
        $predecessorClosurePath,
        $cargoLockPath
    )
) {
    Assert-Exact (
        Test-Path -LiteralPath $requiredPath -PathType Leaf
    ) "A C6-RAP-HC-LR1 declaration, predecessor, or lock file is missing"
}
Assert-Exact (
    (Get-Sha256 -Path $preregistrationPath) -ceq
        $expectedPreregistrationRawSha256 -and
    (Get-Sha256 -Path $predecessorClosurePath) -ceq
        $expectedPredecessorClosureRawSha256 -and
    (Get-Sha256 -Path $cargoLockPath) -ceq
        $expectedCargoLockRawSha256
) "A C6-RAP-HC-LR1 declaration, predecessor, or lock hash changed"

$preregistration = (
    Get-Content -Raw -LiteralPath $preregistrationPath |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_rapier_c6_force_based_load_response_preregistration_v1" -and
    [string]$preregistration.campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-LOAD-RESPONSE" -and
    [string]$preregistration.gate_id -ceq "C6-RAP-HC-LR1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_c6_rap_hc_lr1_physics_world" -and
    [string]$preregistration.estimand.class -ceq
        "exact_finite_cell_host_characterization" -and
    [bool]$preregistration.scientifically_distinct_from_fb1 -and
    [bool]$preregistration.physical_grid.fb1_exposed_cells_excluded -and
    [int]$preregistration.physical_grid.expected_world_count -eq 8 -and
    [bool]$preregistration.preflight_contract.must_run_before_any_physics_world -and
    [bool]$preregistration.preflight_contract.perfect_analytic_eight_cell_result_must_pass_entire_gate -and
    [bool]$preregistration.preflight_contract.whole_outer_step_impulse_canary_must_fail -and
    [bool]$preregistration.preflight_contract.wrong_signed_response_canary_must_fail -and
    [bool]$preregistration.preflight_contract.missing_cell_canary_must_fail
) "The C6-RAP-HC-LR1 declaration identity or preflight contract changed"

# Cargo verifies the package checksum. This additional audit resolves the
# installed Rapier 0.34 crate and hashes every upstream source file used to
# derive LR1's numeric response contract before the Rust preflight can run.
Push-Location -LiteralPath $sdkRoot
try {
    $metadataRaw = (& cargo metadata `
        --format-version 1 `
        --offline)
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Cargo metadata failed before the C6-RAP-HC-LR1 source audit"
} finally {
    Pop-Location
}
$metadata = $metadataRaw | ConvertFrom-Json -AsHashtable
$rapierPackages = @(
    $metadata.packages | Where-Object {
        [string]$_.name -ceq "rapier3d" -and
        [string]$_.version -ceq "0.34.0"
    }
)
Assert-Exact (
    $rapierPackages.Count -eq 1
) "C6-RAP-HC-LR1 requires exactly one resolved rapier3d 0.34.0 package"
$rapierManifestPath = [System.IO.Path]::GetFullPath(
    [string]$rapierPackages[0].manifest_path
)
$rapierSourceRoot = Split-Path -Parent $rapierManifestPath
foreach ($sourceDeclaration in @(
    $preregistration.host_source_semantics.upstream_files
)) {
    $relativeSourcePath = (
        [string]$sourceDeclaration.path
    ).Replace("/", [System.IO.Path]::DirectorySeparatorChar)
    $sourcePath = [System.IO.Path]::GetFullPath(
        (Join-Path $rapierSourceRoot $relativeSourcePath)
    )
    $sourcePrefix = $rapierSourceRoot.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    ) + [System.IO.Path]::DirectorySeparatorChar
    Assert-Exact (
        $sourcePath.StartsWith(
            $sourcePrefix,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        (Test-Path -LiteralPath $sourcePath -PathType Leaf) -and
        (Get-Sha256 -Path $sourcePath) -ceq
            [string]$sourceDeclaration.raw_sha256
    ) (
        "C6-RAP-HC-LR1 pinned Rapier source mismatch: " +
        [string]$sourceDeclaration.path
    )
}

# This is the first executable path that could lead to LR1. It creates no
# PhysicsWorld. The Rust path applies the complete cell evaluator and aggregate
# gate to an analytic eight-cell result, then proves whole-step, sign, and
# missing-cell canaries fail closed.
Push-Location -LiteralPath $sdkRoot
try {
    & cargo run `
        --package sporespore-rapier-adapter `
        --bin force_based_load_response `
        --offline `
        -- `
        --preflight-only
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "C6-RAP-HC-LR1 zero-world preflight failed"
} finally {
    Pop-Location
}

if ($PreflightOnly) {
    Write-Host (
        "C6-RAP-HC-LR1 zero-world preflight passed: pinned Rapier source " +
        "hashes, default/explicit/mutable model readbacks, complete analytic " +
        "eight-cell gate, and whole-step/sign/missing-cell canaries."
    )
    return
}

Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
) (
    "C6-RAP-HC-LR1 is already closed and may not open another physics " +
    "world; audit its closure instead"
)

$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMainCommit = (& git -C $repoRoot rev-parse origin/main).Trim()
$sourceStatus = @(& git -C $repoRoot status --porcelain=v1)
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $sourceCommit -cmatch "^[0-9a-f]{40}$" -and
    $sourceCommit -ceq $originMainCommit -and
    $sourceStatus.Count -eq 0
) "C6-RAP-HC-LR1 physical execution requires clean HEAD == origin/main"

$shortCommit = $sourceCommit.Substring(0, 7)
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path (
        $evidenceRoot
    ) "c6-rapier-force-based-load-response-lr1-$shortCommit"
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
) "C6-RAP-HC-LR1 evidence must live beneath SporeSpore_Evidence"

$reportPath = Join-Path $resolvedOutputRoot "report.json"
$stdoutPath = Join-Path $resolvedOutputRoot "stdout.log"
$stderrPath = Join-Path $resolvedOutputRoot "stderr.log"
foreach ($path in @($reportPath, $stdoutPath, $stderrPath)) {
    Assert-Exact (
        -not (Test-Path -LiteralPath $path)
    ) "Refusing to overwrite an existing C6-RAP-HC-LR1 artifact"
}
[void][System.IO.Directory]::CreateDirectory($resolvedOutputRoot)

$cargo = (Get-Command cargo -ErrorAction Stop).Source
$process = Start-Process `
    -FilePath $cargo `
    -ArgumentList @(
        "run",
        "--package",
        "sporespore-rapier-adapter",
        "--bin",
        "force_based_load_response",
        "--release",
        "--offline",
        "--",
        "--source-commit",
        $sourceCommit,
        "--output",
        $reportPath
    ) `
    -WorkingDirectory $sdkRoot `
    -WindowStyle Hidden `
    -Wait `
    -PassThru `
    -RedirectStandardOutput $stdoutPath `
    -RedirectStandardError $stderrPath

Assert-Exact (
    Test-Path -LiteralPath $reportPath -PathType Leaf
) "C6-RAP-HC-LR1 did not retain report.json"
$report = (
    Get-Content -Raw -LiteralPath $reportPath |
        ConvertFrom-Json -AsHashtable
)
$boundaryValid = (
    [string]$report.schema_version -ceq
        "sporespore_rapier_c6_force_based_load_response_report_v1" -and
    [string]$report.campaign_id -ceq
        "C6-RAPIER-FORCE-BASED-LOAD-RESPONSE" -and
    [string]$report.gate_id -ceq "C6-RAP-HC-LR1" -and
    [string]$report.estimand_class -ceq
        "exact_finite_cell_host_characterization" -and
    [string]$report.source.commit -ceq $sourceCommit -and
    [string]$report.source.origin_main_commit -ceq $sourceCommit -and
    [bool]$report.source.clean -and
    [bool]$report.source.matches_origin_main -and
    [string]$report.preregistration.raw_sha256 -ceq
        $expectedPreregistrationRawSha256 -and
    [string]$report.predecessor_fb1_closure_raw_sha256 -ceq
        $expectedPredecessorClosureRawSha256 -and
    [bool]$report.preflight.ok -and
    [int]$report.preflight.world_build_count -eq 0 -and
    [int]$report.aggregate.world_attempt_count -eq 8 -and
    [int]$report.aggregate.world_build_count -eq 8 -and
    [int]$report.aggregate.cell_count -eq 8 -and
    [int]$report.aggregate.motor_model_readback_count -eq 8 -and
    -not [bool]$report.rapier_selected_policy_physical_authority -and
    -not [bool]$report.rapier_locomotion_acceptance -and
    -not [bool]$report.different_physics_engines -and
    -not [bool]$report.cross_engine_c6 -and
    -not [bool]$report.physical_acceptance_authority -and
    -not [bool]$report.completed_engine_neutral_sdk
)
Assert-Exact (
    $boundaryValid
) "C6-RAP-HC-LR1 retained report violated its identity or claim boundary"

$reportSha256 = Get-Sha256 -Path $reportPath
Write-Host (
    "C6-RAP-HC-LR1 retained: $reportPath $reportSha256 " +
    "passed=$([bool]$report.ok) cells=" +
    "$([int]$report.aggregate.passed_cell_count)/8"
)
if (
    $process.ExitCode -ne 0 -or
    -not [bool]$report.ok -or
    -not [bool]$report.rapier_force_based_load_response_characterization -or
    -not [bool]$report.rapier_force_based_host_characterization
) {
    throw (
        "C6-RAP-HC-LR1 retained a complete negative result " +
        "(process exit $($process.ExitCode)); close it without rerunning"
    )
}

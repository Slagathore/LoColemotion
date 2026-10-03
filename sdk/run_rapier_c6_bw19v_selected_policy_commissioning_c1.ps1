[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$preregistrationPath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_selected_policy_commissioning_c1_preregistration.json"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_selected_policy_commissioning_c1_closure.json"
$expectedPreregistrationRawSha256 = (
    "sha256:" +
    "231ddf65d2f12137f1215182c9076b46cd5f1adf3e0db2443ac4da1ecf1af319"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Write-NewJsonArtifact {
    param(
        [Parameter(Mandatory)][object]$Value,
        [Parameter(Mandatory)][string]$Path
    )

    Assert-Exact (
        -not (Test-Path -LiteralPath $Path)
    ) "Refusing to overwrite a C6-RAP-BW19V-C1 supervisor receipt: $Path"
    $parent = Split-Path -Parent $Path
    [void][System.IO.Directory]::CreateDirectory($parent)
    $temporary = $Path + ".tmp"
    Assert-Exact (
        -not (Test-Path -LiteralPath $temporary)
    ) "Refusing stale C6-RAP-BW19V-C1 supervisor receipt: $temporary"
    [System.IO.File]::WriteAllText(
        $temporary,
        (($Value | ConvertTo-Json -Depth 20) + [Environment]::NewLine),
        [System.Text.UTF8Encoding]::new($false)
    )
    Move-Item -LiteralPath $temporary -Destination $Path
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
    ) "Refusing to overwrite a C6-RAP-BW19V-C1 supervisor artifact"
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

# Physical rerun refusal is a closed-campaign safety property, so it must not be
# masked by later changes to mutable checkout documentation or dependencies.
# PreflightOnly deliberately continues to the historical input checks below;
# the closure audit is the current authority for the completed C1 outcome.
if (-not $PreflightOnly) {
    Assert-Exact (
        -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
    ) "C6-RAP-BW19V-C1 is already closed and may not open another world"
}

Assert-Exact (
    (Test-Path -LiteralPath $preregistrationPath -PathType Leaf) -and
    (Get-RawSha256 $preregistrationPath) -ceq
        $expectedPreregistrationRawSha256
) "The C6-RAP-BW19V-C1 preregistration is missing or changed"
$preregistration = (
    Get-Content -Raw -LiteralPath $preregistrationPath |
        ConvertFrom-Json
)
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_rapier_c6_bw19v_selected_policy_commissioning_c1_preregistration_v1" -and
    [string]$preregistration.campaign_id -ceq
        "C6-RAPIER-BW19V-SELECTED-POLICY-COMMISSIONING-C1" -and
    [string]$preregistration.gate_id -ceq "C6-RAP-BW19V-C1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_c6_rap_bw19v_c1_physics_world" -and
    [string]$preregistration.study_class.classification -ceq
        "outcome_exposed_single_body_technical_commissioning" -and
    [int]$preregistration.study_class.world_count -eq 1 -and
    -not [bool]$preregistration.study_class.independent_validation -and
    -not [bool]$preregistration.study_class.population_inference -and
    [string]$preregistration.portable_policy_identity.candidate_id -ceq
        "BW19V-B" -and
    [string]$preregistration.portable_policy_identity.controller_policy_id -ceq
        "sporespore_balanced_wave_bw15f_b_v1" -and
    [double]$preregistration.portable_policy_identity.global_requested_correction_scale -eq
        0.5 -and
    [string]$preregistration.host_contract.motor_model -ceq "ForceBased" -and
    [int]$preregistration.host_contract.solver_iterations -eq 16 -and
    [int]$preregistration.host_contract.internal_pgs_iterations -eq 3 -and
    [int]$preregistration.host_contract.internal_stabilization_iterations -eq 5 -and
    [bool]$preregistration.claim_boundary.technical_commissioning_only -and
    -not [bool]$preregistration.claim_boundary.cross_engine_c6 -and
    -not [bool]$preregistration.claim_boundary.release_authorized
) "C6-RAP-BW19V-C1 identity, study class, host, or claim boundary changed"

foreach ($declaration in @(
    @{
        path = [string]$preregistration.predecessor_interlocks.rapier_sp1_r2_closure_path
        sha256 = "sha256:" + [string]$preregistration.predecessor_interlocks.rapier_sp1_r2_closure_raw_sha256
    },
    @{
        path = [string]$preregistration.predecessor_interlocks.spv1_closure_path
        sha256 = "sha256:" + [string]$preregistration.predecessor_interlocks.spv1_closure_raw_sha256
    },
    @{
        path = [string]$preregistration.predecessor_interlocks.active_configuration_path
        sha256 = "sha256:" + [string]$preregistration.predecessor_interlocks.active_configuration_raw_sha256
    },
    @{
        path = [string]$preregistration.portable_policy_identity.bw19v_closure_path
        sha256 = "sha256:" + [string]$preregistration.portable_policy_identity.bw19v_closure_raw_sha256
    },
    @{
        path = [string]$preregistration.portable_policy_identity.bw19v_candidate_declaration_path
        sha256 = "sha256:" + [string]$preregistration.portable_policy_identity.bw19v_candidate_declaration_raw_sha256
    },
    @{
        path = [string]$preregistration.portable_policy_identity.bw15f_selected_policy_path
        sha256 = "sha256:" + [string]$preregistration.portable_policy_identity.bw15f_selected_policy_raw_sha256
    },
    @{
        path = [string]$preregistration.host_source_semantics.cargo_lock_path
        sha256 = "sha256:" + [string]$preregistration.host_source_semantics.cargo_lock_raw_sha256
    }
)) {
    $path = [System.IO.Path]::GetFullPath(
        (Join-Path $repoRoot ([string]$declaration.path))
    )
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 $path) -ceq [string]$declaration.sha256
    ) "A C6-RAP-BW19V-C1 pinned repository input changed: $path"
}

foreach ($source in $preregistration.method_sources.local_research_inputs) {
    $sourcePath = [System.IO.Path]::GetFullPath(
        (Join-Path $repoRoot ([string]$source.path))
    )
    Assert-Exact (
        (Test-Path -LiteralPath $sourcePath -PathType Leaf) -and
        (Get-RawSha256 $sourcePath) -ceq [string]$source.sha256
    ) "A C6-RAP-BW19V-C1 research source changed: $sourcePath"
}

Push-Location -LiteralPath $sdkRoot
try {
    $metadataRaw = (& cargo metadata --format-version 1 --offline)
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Cargo metadata failed before the C6-RAP-BW19V-C1 source audit"
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
) "C6-RAP-BW19V-C1 requires exactly one resolved rapier3d 0.34.0 package"
$rapierSourceRoot = Split-Path -Parent (
    [System.IO.Path]::GetFullPath(
        [string]$rapierPackages[0].manifest_path
    )
)
$sourcePrefix = $rapierSourceRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
foreach ($sourceDeclaration in @(
    $preregistration.host_source_semantics.upstream_files
)) {
    $relativeSourcePath = (
        [string]$sourceDeclaration.path
    ).Replace("/", [System.IO.Path]::DirectorySeparatorChar)
    $sourcePath = [System.IO.Path]::GetFullPath(
        (Join-Path $rapierSourceRoot $relativeSourcePath)
    )
    Assert-Exact (
        $sourcePath.StartsWith(
            $sourcePrefix,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        (Test-Path -LiteralPath $sourcePath -PathType Leaf) -and
        (Get-RawSha256 $sourcePath) -ceq (
            "sha256:" + [string]$sourceDeclaration.raw_sha256
        )
    ) "A pinned Rapier source changed: $sourcePath"
}

Push-Location -LiteralPath $sdkRoot
try {
    & cargo run `
        --package sporespore-rapier-adapter `
        --bin bw19v_commissioning `
        --offline `
        -- `
        --preflight-only
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "C6-RAP-BW19V-C1 zero-world whole-gate preflight failed"
} finally {
    Pop-Location
}
if ($PreflightOnly) {
    Write-Host (
        "C6-RAP-BW19V-C1 zero-world preflight passed: pinned evidence " +
        "graph and Rapier sources, exact BW19V-B/BW15F-B identities, " +
        "ForceBased builder and update canaries, signed source response, " +
        "complete 3232-step available/partial/fail-zero composition horizon, " +
        "whole report gate, negative canaries, worlds=0."
    )
    return
}

Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
) "C6-RAP-BW19V-C1 is already closed and may not open another world"
$priorAttemptReceipts = @()
if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
    $priorAttemptReceipts = @(
        Get-ChildItem `
            -LiteralPath $evidenceRoot `
            -Filter "attempt.json" `
            -File `
            -Recurse |
            Where-Object {
                try {
                    $receipt = Get-Content -Raw -LiteralPath $_.FullName |
                        ConvertFrom-Json
                    [string]$receipt.campaign_id -ceq
                        "C6-RAPIER-BW19V-SELECTED-POLICY-COMMISSIONING-C1" -and
                    [string]$receipt.gate_id -ceq "C6-RAP-BW19V-C1"
                } catch {
                    $false
                }
            }
    )
}
Assert-Exact (
    $priorAttemptReceipts.Count -eq 0
) (
    "C6-RAP-BW19V-C1 already has a retained physical attempt receipt; " +
    "any process launch consumes this campaign identity and requires closure"
)
$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMainCommit = (& git -C $repoRoot rev-parse origin/main).Trim()
$remoteLine = (& git -C $repoRoot ls-remote origin refs/heads/main).Trim()
$remoteCommit = ($remoteLine -split "\s+")[0]
$sourceStatus = @(& git -C $repoRoot status --porcelain=v1)
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $sourceCommit -cmatch "^[0-9a-f]{40}$" -and
    $sourceCommit -ceq $originMainCommit -and
    $sourceCommit -ceq $remoteCommit -and
    $sourceStatus.Count -eq 0
) "C6-RAP-BW19V-C1 requires clean source with HEAD == origin/main == GitHub"

$shortCommit = $sourceCommit.Substring(0, 7)
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path (
        $evidenceRoot
    ) "c6-rapier-bw19v-selected-policy-c1-$shortCommit"
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
) "C6-RAP-BW19V-C1 evidence must live beneath SporeSpore_Evidence"
$reportPath = Join-Path $resolvedOutputRoot "report.json"
$stdoutPath = Join-Path $resolvedOutputRoot "stdout.log"
$stderrPath = Join-Path $resolvedOutputRoot "stderr.log"
$attemptPath = Join-Path $resolvedOutputRoot "attempt.json"
$completionPath = Join-Path $resolvedOutputRoot "completion.json"
Assert-Exact (
    -not (Test-Path -LiteralPath $reportPath) -and
    -not (Test-Path -LiteralPath $stdoutPath) -and
    -not (Test-Path -LiteralPath $stderrPath) -and
    -not (Test-Path -LiteralPath $attemptPath) -and
    -not (Test-Path -LiteralPath $completionPath)
) "Refusing to overwrite C6-RAP-BW19V-C1 evidence"
[void][System.IO.Directory]::CreateDirectory($resolvedOutputRoot)
$attemptReceipt = [ordered]@{
    schema_version = (
        "sporespore_rapier_c6_bw19v_selected_policy_" +
        "commissioning_c1_attempt_v1"
    )
    campaign_id = "C6-RAPIER-BW19V-SELECTED-POLICY-COMMISSIONING-C1"
    gate_id = "C6-RAP-BW19V-C1"
    status = "reserved_before_physical_process_launch"
    reserved_utc = (Get-Date -AsUTC -Format "yyyy-MM-ddTHH:mm:ss.fffffffZ")
    source_commit = $sourceCommit
    origin_main_commit = $originMainCommit
    live_remote_main_commit = $remoteCommit
    preregistration_raw_sha256 = $expectedPreregistrationRawSha256
    output_root = $resolvedOutputRoot
    report_path = $reportPath
    any_physical_process_launch_consumes_campaign_identity = $true
    same_identity_rerun_forbidden = $true
    scientific_result_claim = $false
}
Write-NewJsonArtifact -Value $attemptReceipt -Path $attemptPath
$cargo = (Get-Command cargo -ErrorAction Stop).Source
$processExitCode = Invoke-LoggedProcess `
    -FilePath $cargo `
    -ArgumentList @(
        "run",
        "--package",
        "sporespore-rapier-adapter",
        "--bin",
        "bw19v_commissioning",
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
$reportRetained = Test-Path -LiteralPath $reportPath -PathType Leaf
$completionReceipt = [ordered]@{
    schema_version = (
        "sporespore_rapier_c6_bw19v_selected_policy_" +
        "commissioning_c1_process_completion_v1"
    )
    campaign_id = "C6-RAPIER-BW19V-SELECTED-POLICY-COMMISSIONING-C1"
    gate_id = "C6-RAP-BW19V-C1"
    status = if ($reportRetained) {
        "physical_process_exited_with_report"
    } else {
        "physical_process_exited_without_report_abnormal_attempt"
    }
    completed_utc = (Get-Date -AsUTC -Format "yyyy-MM-ddTHH:mm:ss.fffffffZ")
    source_commit = $sourceCommit
    preregistration_raw_sha256 = $expectedPreregistrationRawSha256
    process_exit_code = [int]$processExitCode
    report_retained = [bool]$reportRetained
    report_raw_sha256 = if ($reportRetained) {
        Get-RawSha256 $reportPath
    } else {
        $null
    }
    stdout_raw_sha256 = Get-RawSha256 $stdoutPath
    stderr_raw_sha256 = Get-RawSha256 $stderrPath
    any_physical_process_launch_consumes_campaign_identity = $true
    same_identity_rerun_forbidden = $true
    abnormal_attempt_is_not_a_scientific_result = -not $reportRetained
}
Write-NewJsonArtifact -Value $completionReceipt -Path $completionPath
Assert-Exact (
    $reportRetained
) (
    "C6-RAP-BW19V-C1 exited $processExitCode without retaining report.json; " +
    "attempt and completion receipts are durable, the identity is consumed, " +
    "and an immutable abnormal closure is required"
)
$report = (
    Get-Content -Raw -LiteralPath $reportPath |
        ConvertFrom-Json
)
Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_rapier_c6_bw19v_selected_policy_commissioning_c1_report_v1" -and
    [string]$report.campaign_id -ceq
        "C6-RAPIER-BW19V-SELECTED-POLICY-COMMISSIONING-C1" -and
    [string]$report.gate_id -ceq "C6-RAP-BW19V-C1" -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [string]$report.preregistration_raw_sha256 -ceq
        $expectedPreregistrationRawSha256 -and
    [string]$report.candidate_id -ceq "BW19V-B" -and
    [string]$report.selected_policy_id -ceq
        "sporespore_balanced_wave_bw15f_b_v1" -and
    [bool]$report.preflight.complete_declared_horizon_passed -and
    [bool]$report.preflight.perfect_synthetic_whole_gate_passed -and
    [int]$report.preflight.world_build_count -eq 0 -and
    [int]$report.world_attempt_count -eq 1 -and
    [int]$report.world_build_count -eq 1 -and
    [bool]$report.claim_boundary.technical_commissioning_only -and
    -not [bool]$report.rapier_selected_policy_physical_c6 -and
    -not [bool]$report.claim_boundary.cross_engine_c6 -and
    -not [bool]$report.claim_boundary.release_authorized -and
    -not [bool]$report.claim_boundary.physical_acceptance_authority
) "C6-RAP-BW19V-C1 report violated its identity or claim boundary"
$reportSha256 = Get-RawSha256 $reportPath
Write-Host (
    "C6-RAP-BW19V-C1 retained: $reportPath $reportSha256 " +
    "(process exit $processExitCode)"
)
if ([bool]$report.ok) {
    Assert-Exact (
        [int]$processExitCode -eq 0
    ) "C6-RAP-BW19V-C1 claimed success with a nonzero process exit"
} else {
    Assert-Exact (
        [int]$processExitCode -ne 0
    ) "C6-RAP-BW19V-C1 retained a negative report but exited successfully"
    throw (
        "C6-RAP-BW19V-C1 retained its complete negative report at " +
        "$reportPath; the same identity may not be rerun"
    )
}

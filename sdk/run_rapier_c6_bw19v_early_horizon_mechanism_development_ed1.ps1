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
) "rapier_c6_bw19v_early_horizon_mechanism_development_ed1_preregistration.json"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_early_horizon_mechanism_development_ed1_closure.json"
$expectedPreregistrationRawSha256 = (
    "sha256:" +
    "8c149f47a87bbd72402a7aa98fec1e75ff05abb36df2802f9b8a333f469b3197"
)
$campaignId = "C6-RAPIER-BW19V-EARLY-HORIZON-MECHANISM-DEVELOPMENT-ED1"
$gateId = "C6-RAP-BW19V-ED1"

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
    ) "Refusing to overwrite a $gateId supervisor receipt: $Path"
    $parent = Split-Path -Parent $Path
    [void][System.IO.Directory]::CreateDirectory($parent)
    $temporary = $Path + ".tmp"
    Assert-Exact (
        -not (Test-Path -LiteralPath $temporary)
    ) "Refusing stale $gateId supervisor receipt: $temporary"
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
    ) "Refusing to overwrite a $gateId supervisor artifact"
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

# A consumed physical identity must fail closed before validating any mutable
# current-checkout input. This keeps later source/documentation evolution from
# obscuring the stronger invariant: ED1 can never launch another world.
if (-not $PreflightOnly) {
    Assert-Exact (
        -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
    ) "$gateId is already closed and may not open another world"
}

Assert-Exact (
    (Test-Path -LiteralPath $preregistrationPath -PathType Leaf) -and
    (Get-RawSha256 $preregistrationPath) -ceq
        $expectedPreregistrationRawSha256
) "The $gateId preregistration is missing or changed"
$preregistration = (
    Get-Content -Raw -LiteralPath $preregistrationPath |
        ConvertFrom-Json
)
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_rapier_c6_bw19v_early_horizon_mechanism_development_ed1_preregistration_v1" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$preregistration.status -ceq
        "frozen_before_first_c6_rap_bw19v_ed1_physics_world" -and
    [string]$preregistration.study_class.classification -ceq
        "outcome_exposed_paired_single_body_mechanism_development_screen" -and
    [int]$preregistration.study_class.world_count -eq 2 -and
    [int]$preregistration.study_class.arm_count -eq 2 -and
    [bool]$preregistration.study_class.development_screen -and
    -not [bool]$preregistration.study_class.population_inference -and
    -not [bool]$preregistration.study_class.walking_acceptance -and
    -not [bool]$preregistration.study_class.technical_commissioning_authority -and
    [string]$preregistration.predecessor_interlocks.c2_status -ceq
        "closed_negative_corrected_composition_complete_physical_walking_gate_failed" -and
    -not [bool]$preregistration.predecessor_interlocks.c2_same_identity_rerun -and
    -not [bool]$preregistration.predecessor_interlocks.c2_physical_failure_cause_identified -and
    [bool]$preregistration.causal_intervention.single_changed_mechanism -and
    -not [bool]$preregistration.causal_intervention.controller_identity_changed -and
    -not [bool]$preregistration.causal_intervention.host_fixture_changed -and
    [string]$preregistration.causal_intervention.arm_a.arm_id -ceq "ED1-A" -and
    -not [bool]$preregistration.causal_intervention.arm_a.bw19v_stability_contribution_applied_to_host -and
    [string]$preregistration.causal_intervention.arm_b.arm_id -ceq "ED1-B" -and
    [bool]$preregistration.causal_intervention.arm_b.bw19v_stability_contribution_applied_to_host -and
    [int]$preregistration.physical_fixture.controller_semantic_steps_per_arm -eq 472 -and
    [int]$preregistration.diagnostic_integrity_gate.trace_step_count_total -eq 944 -and
    [int]$preregistration.diagnostic_integrity_gate.base_command_count_total -eq 7552 -and
    [int]$preregistration.diagnostic_integrity_gate.shadow_residual_command_count_total -eq 7552 -and
    [int]$preregistration.diagnostic_integrity_gate.final_host_command_count_total -eq 7552 -and
    [bool]$preregistration.claim_boundary.complete_mechanism_development_trace_only -and
    -not [bool]$preregistration.claim_boundary.walking_acceptance -and
    -not [bool]$preregistration.claim_boundary.rapier_selected_policy_physical_c6 -and
    -not [bool]$preregistration.claim_boundary.release_authorized
) "$gateId identity, intervention, horizon, or claim boundary changed"

$repositoryDeclarations = @(
    @{
        path = [string]$preregistration.predecessor_interlocks.c2_closure_path
        sha256 = "sha256:" + [string]$preregistration.predecessor_interlocks.c2_closure_raw_sha256
    },
    @{
        path = [string]$preregistration.host_contract.active_configuration_path
        sha256 = "sha256:" + [string]$preregistration.host_contract.active_configuration_raw_sha256
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
)
foreach ($source in $preregistration.method_sources.repository_contracts) {
    $repositoryDeclarations += @{
        path = [string]$source.path
        sha256 = [string]$source.sha256
    }
}
foreach ($source in $preregistration.method_sources.local_research_inputs) {
    $repositoryDeclarations += @{
        path = [string]$source.path
        sha256 = [string]$source.sha256
    }
}
foreach ($declaration in $repositoryDeclarations) {
    $path = [System.IO.Path]::GetFullPath(
        (Join-Path $repoRoot ([string]$declaration.path))
    )
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 $path) -ceq [string]$declaration.sha256
    ) "A $gateId pinned repository input changed: $path"
}

Push-Location -LiteralPath $sdkRoot
try {
    $metadataRaw = (& cargo metadata --format-version 1 --offline)
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Cargo metadata failed before the $gateId source audit"
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
) "$gateId requires exactly one resolved rapier3d 0.34.0 package"
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
    $preflightLines = @(
        & cargo run `
            --quiet `
            --package sporespore-rapier-adapter `
            --bin bw19v_early_horizon_development `
            --offline `
            -- `
            --preflight-only
    )
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "$gateId zero-world whole-gate preflight failed"
} finally {
    Pop-Location
}
$preflight = (($preflightLines -join [Environment]::NewLine) | ConvertFrom-Json)
Assert-Exact (
    [bool]$preflight.ok -and
    [string]$preflight.campaign_id -ceq $campaignId -and
    [string]$preflight.gate_id -ceq $gateId -and
    [string]$preflight.preregistration_raw_sha256 -ceq
        $expectedPreregistrationRawSha256 -and
    [bool]$preflight.perfect_synthetic_two_arm_report_passed_complete_integrity_gate -and
    [bool]$preflight.synthetic_outcome_variants_all_integrity_valid -and
    [int]$preflight.synthetic_arm_count -eq 2 -and
    [int]$preflight.synthetic_trace_step_count -eq 944 -and
    [int]$preflight.synthetic_command_count_per_layer -eq 7552 -and
    [bool]$preflight.missing_trace_step_canary_rejected -and
    [bool]$preflight.reordered_semantic_step_canary_rejected -and
    [bool]$preflight.arm_a_nonzero_applied_residual_canary_rejected -and
    [bool]$preflight.arm_b_missing_nonzero_shadow_residual_canary_rejected -and
    [bool]$preflight.final_command_count_canary_rejected -and
    [bool]$preflight.claim_inflation_canary_rejected -and
    [bool]$preflight.serialization_round_trip_passed -and
    [int]$preflight.world_build_count -eq 0 -and
    [int]$preflight.scene_insertion_count -eq 0 -and
    [int]$preflight.physics_state_mutation_count -eq 0 -and
    -not [bool]$preflight.physical_acceptance_authority
) "$gateId zero-world receipt changed or is incomplete"
if ($PreflightOnly) {
    Write-Host (
        "$gateId zero-world preflight passed: two arms, 944 trace steps, " +
        "7552 commands per layer, four outcome patterns, all canaries, " +
        "worlds=0."
    )
    return
}

if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
    foreach ($candidate in @(
        Get-ChildItem `
            -LiteralPath $evidenceRoot `
            -Recurse `
            -File `
            -Filter "attempt.json" `
            -ErrorAction Stop
    )) {
        try {
            $receipt = Get-Content -Raw -LiteralPath $candidate.FullName |
                ConvertFrom-Json
            Assert-Exact (
                [string]$receipt.campaign_id -cne $campaignId
            ) "$gateId already has a retained physical attempt receipt"
        } catch {
            if ($_.Exception.Message -like "$gateId already has*") {
                throw
            }
        }
    }
}

$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMainCommit = (& git -C $repoRoot rev-parse origin/main).Trim()
$remoteLine = (& git -C $repoRoot ls-remote origin refs/heads/main).Trim()
$remoteCommit = ($remoteLine -split "\s+")[0]
$sourceStatus = @(& git -C $repoRoot status --porcelain=v1)
Assert-Exact (
    $sourceCommit -cmatch "^[0-9a-f]{40}$" -and
    $sourceCommit -ceq $originMainCommit -and
    $sourceCommit -ceq $remoteCommit -and
    $sourceStatus.Count -eq 0
) "$gateId requires clean source with HEAD == origin/main == GitHub"

$shortCommit = $sourceCommit.Substring(0, 7)
$resolvedOutputRoot = if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    Join-Path (
        $evidenceRoot
    ) "c6-rapier-bw19v-early-horizon-ed1-$shortCommit"
} else {
    [System.IO.Path]::GetFullPath($OutputRoot)
}
$evidencePrefix = $evidenceRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
Assert-Exact (
    $resolvedOutputRoot.StartsWith(
        $evidencePrefix,
        [StringComparison]::OrdinalIgnoreCase
    )
) "$gateId evidence must live beneath SporeSpore_Evidence"
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
) "Refusing to overwrite $gateId evidence"

$attemptReceipt = [ordered]@{
    schema_version = (
        "sporespore_rapier_c6_bw19v_early_horizon_" +
        "mechanism_development_ed1_attempt_v1"
    )
    campaign_id = $campaignId
    gate_id = $gateId
    status = "physical_process_launch_reserved_identity_consumed"
    recorded_utc = (Get-Date).ToUniversalTime().ToString("o")
    source_commit = $sourceCommit
    origin_main_commit = $originMainCommit
    live_remote_main_commit = $remoteCommit
    preregistration_raw_sha256 = $expectedPreregistrationRawSha256
    c2_closure_raw_sha256 = (
        "sha256:" +
        [string]$preregistration.predecessor_interlocks.c2_closure_raw_sha256
    )
    report_path = $reportPath
    stdout_path = $stdoutPath
    stderr_path = $stderrPath
    fixed_arm_order = @("ED1-A", "ED1-B")
    declared_world_count = 2
    process_launch_consumes_identity = $true
    same_identity_rerun_allowed = $false
}
Write-NewJsonArtifact -Value $attemptReceipt -Path $attemptPath
$cargo = (Get-Command cargo -ErrorAction Stop).Source
$processExitCode = Invoke-LoggedProcess `
    -FilePath $cargo `
    -ArgumentList @(
        "run",
        "--quiet",
        "--package",
        "sporespore-rapier-adapter",
        "--bin",
        "bw19v_early_horizon_development",
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
        "sporespore_rapier_c6_bw19v_early_horizon_" +
        "mechanism_development_ed1_process_completion_v1"
    )
    campaign_id = $campaignId
    gate_id = $gateId
    status = if ($reportRetained) {
        "physical_process_exited_with_report"
    } else {
        "physical_process_exited_without_report_abnormal_attempt"
    }
    recorded_utc = (Get-Date).ToUniversalTime().ToString("o")
    source_commit = $sourceCommit
    process_exit_code = $processExitCode
    physical_process_launched = $true
    report_retained = [bool]$reportRetained
    report_raw_sha256 = if ($reportRetained) {
        Get-RawSha256 $reportPath
    } else {
        $null
    }
    same_identity_rerun_allowed = $false
    abnormal_attempt_is_not_a_scientific_result = -not $reportRetained
}
Write-NewJsonArtifact -Value $completionReceipt -Path $completionPath
Assert-Exact (
    $reportRetained
) (
    "$gateId exited $processExitCode without retaining report.json; " +
    "attempt and completion receipts are durable, the identity is consumed, " +
    "and an immutable abnormal closure is required"
)
$report = (
    Get-Content -Raw -LiteralPath $reportPath |
        ConvertFrom-Json
)
Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_rapier_c6_bw19v_early_horizon_mechanism_development_ed1_report_v1" -and
    [string]$report.campaign_id -ceq $campaignId -and
    [string]$report.gate_id -ceq $gateId -and
    [string]$report.source_commit -ceq $sourceCommit -and
    [string]$report.preregistration_raw_sha256 -ceq
        $expectedPreregistrationRawSha256 -and
    [bool]$report.preflight.ok -and
    [int]$report.preflight.world_build_count -eq 0 -and
    [int]$report.world_attempt_count -eq 2 -and
    [int]$report.world_build_count -eq 2 -and
    [int]$report.trace_step_count_total -eq 944 -and
    [int]$report.base_command_count_total -eq 7552 -and
    [int]$report.shadow_residual_command_count_total -eq 7552 -and
    [int]$report.final_host_command_count_total -eq 7552 -and
    [int]$report.post_step_host_observation_count_total -eq 7552 -and
    [bool]$report.claim_boundary.complete_mechanism_development_trace_only -and
    -not [bool]$report.claim_boundary.walking_acceptance -and
    -not [bool]$report.claim_boundary.rapier_selected_policy_physical_c6 -and
    -not [bool]$report.claim_boundary.release_authorized -and
    -not [bool]$report.claim_boundary.physical_acceptance_authority
) "$gateId report violated its identity, trace, or claim boundary"
$reportSha256 = Get-RawSha256 $reportPath
Write-Host (
    "$gateId retained: $reportPath $reportSha256 " +
    "process_exit=$processExitCode complete=$([bool]$report.ok) " +
    "classification=$([string]$report.pair_interpretation.classification)"
)
if ([bool]$report.ok) {
    Assert-Exact (
        $processExitCode -eq 0
    ) "$gateId claimed complete diagnostic integrity with a nonzero exit"
} else {
    Assert-Exact (
        $processExitCode -ne 0
    ) "$gateId retained an invalid diagnostic but exited successfully"
    throw (
        "$gateId retained an invalid diagnostic report at $reportPath; " +
        "the same identity may not be rerun"
    )
}

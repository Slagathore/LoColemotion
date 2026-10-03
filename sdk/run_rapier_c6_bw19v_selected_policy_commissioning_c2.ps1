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
) "rapier_c6_bw19v_selected_policy_commissioning_c2_preregistration.json"
$closurePath = Join-Path (
    $sdkRoot
) "rapier_c6_bw19v_selected_policy_commissioning_c2_closure.json"
$expectedPreregistrationRawSha256 = (
    "sha256:" +
    "c2f4c071c7b55e20dd77f32b72370f6891c3b1b2426baa2fca2ac0e23730da27"
)
$campaignId = "C6-RAPIER-BW19V-SELECTED-POLICY-COMMISSIONING-C2"
$gateId = "C6-RAP-BW19V-C2"

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

# Physical rerun refusal is a closed-campaign safety property, so it must not be
# masked by later changes to mutable checkout documentation or dependencies.
# PreflightOnly deliberately continues to the historical input checks below;
# the closure audit is the current authority for the completed C2 outcome.
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
        "sporespore_rapier_c6_bw19v_selected_policy_commissioning_c2_preregistration_v1" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$preregistration.status -ceq
        "frozen_before_first_c6_rap_bw19v_c2_physics_world" -and
    [string]$preregistration.study_class.classification -ceq
        "outcome_exposed_single_body_technical_commissioning" -and
    [int]$preregistration.study_class.world_count -eq 1 -and
    -not [bool]$preregistration.study_class.independent_validation -and
    -not [bool]$preregistration.study_class.population_inference -and
    [string]$preregistration.predecessor_interlocks.c1_closure_status -ceq
        "closed_negative_portable_observation_availability_routing_failure" -and
    -not [bool]$preregistration.predecessor_interlocks.c1_same_identity_rerun -and
    [int]$preregistration.prospective_change_under_test.changed_surface_count -eq 3 -and
    -not [bool]$preregistration.prospective_change_under_test.controller_or_policy_parameter_changed -and
    -not [bool]$preregistration.prospective_change_under_test.physical_fixture_changed -and
    -not [bool]$preregistration.prospective_change_under_test.walking_threshold_changed -and
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
) "$gateId identity, study class, correction, host, or claim boundary changed"

foreach ($declaration in @(
    @{
        path = [string]$preregistration.predecessor_interlocks.c1_closure_path
        sha256 = "sha256:" + [string]$preregistration.predecessor_interlocks.c1_closure_raw_sha256
    },
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
    ) "A $gateId pinned repository input changed: $path"
}

foreach ($source in $preregistration.method_sources.local_research_inputs) {
    $sourcePath = [System.IO.Path]::GetFullPath(
        (Join-Path $repoRoot ([string]$source.path))
    )
    Assert-Exact (
        (Test-Path -LiteralPath $sourcePath -PathType Leaf) -and
        (Get-RawSha256 $sourcePath) -ceq [string]$source.sha256
    ) "A $gateId research source changed: $sourcePath"
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
            --bin bw19v_commissioning_c2 `
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
    [int]$preflight.complete_declared_horizon_steps -eq 3232 -and
    [int]$preflight.synthetic_available_plan_count -eq 1920 -and
    [int]$preflight.synthetic_observation_unavailable_plan_count -eq 1312 -and
    [int]$preflight.synthetic_explicit_host_observation_unavailable_plan_count -eq 360 -and
    [int]$preflight.synthetic_observed_planning_unavailable_plan_count -eq 952 -and
    [int]$preflight.synthetic_upstream_infeasible_plan_count -eq 0 -and
    [int]$preflight.synthetic_fail_zero_count -eq 1312 -and
    [int]$preflight.synthetic_partial_support_mapping_count -eq 960 -and
    [int]$preflight.synthetic_influence_output_count -eq 25856 -and
    [int]$preflight.synthetic_explicit_host_unavailable_base_application_count -eq 2880 -and
    [int]$preflight.synthetic_explicit_host_unavailable_exact_zero_stability_output_count -eq 2880 -and
    [bool]$preflight.available_receipt_before_zero_support_segment -and
    [bool]$preflight.available_receipt_after_zero_support_segment -and
    [bool]$preflight.perfect_synthetic_whole_gate_passed -and
    [bool]$preflight.observation_unavailable_route_canary_rejected -and
    [int]$preflight.world_build_count -eq 0 -and
    [int]$preflight.scene_insertion_count -eq 0 -and
    [int]$preflight.physics_state_mutation_count -eq 0
) "$gateId zero-world receipt changed or is incomplete"
if ($PreflightOnly) {
    Write-Host (
        "$gateId zero-world preflight passed: exact C1 predecessor and " +
        "BW19V-B identities, 3232 steps, available=1920, " +
        "explicit_host_unavailable=360, observed_planning_unavailable=952, " +
        "partial_support=960, final_outputs=25856, worlds=0."
    )
    return
}

Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
) "$gateId is already closed and may not open another world"
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
    ) "c6-rapier-bw19v-selected-policy-c2-$shortCommit"
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
        "sporespore_rapier_c6_bw19v_selected_policy_" +
        "commissioning_c2_attempt_v1"
    )
    campaign_id = $campaignId
    gate_id = $gateId
    status = "physical_process_launch_reserved_identity_consumed"
    recorded_utc = (Get-Date).ToUniversalTime().ToString("o")
    source_commit = $sourceCommit
    origin_main_commit = $originMainCommit
    live_remote_main_commit = $remoteCommit
    preregistration_raw_sha256 = $expectedPreregistrationRawSha256
    c1_closure_raw_sha256 = (
        "sha256:" + [string]$preregistration.predecessor_interlocks.c1_closure_raw_sha256
    )
    report_path = $reportPath
    stdout_path = $stdoutPath
    stderr_path = $stderrPath
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
        "bw19v_commissioning_c2",
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
        "commissioning_c2_process_completion_v1"
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
        "sporespore_rapier_c6_bw19v_selected_policy_commissioning_c2_report_v1" -and
    [string]$report.campaign_id -ceq $campaignId -and
    [string]$report.gate_id -ceq $gateId -and
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
) "$gateId report violated its identity or claim boundary"
$reportSha256 = Get-RawSha256 $reportPath
Write-Host (
    "$gateId retained: $reportPath $reportSha256 " +
    "process_exit=$processExitCode ok=$([bool]$report.ok)"
)
if ([bool]$report.ok) {
    Assert-Exact (
        $processExitCode -eq 0
    ) "$gateId claimed success with a nonzero process exit"
} else {
    Assert-Exact (
        $processExitCode -ne 0
    ) "$gateId retained a negative report but exited successfully"
    throw (
        "$gateId retained its complete negative report at " +
        "$reportPath; the same identity may not be rerun"
    )
}

#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$sdkRoot = Join-Path $repoRoot "sdk"
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw27m_material_characterization_closure.json"
$supervisorPath = Join-Path (
    $sdkRoot
) "run_balanced_wave_bw27m_material_characterization.ps1"
$productionGatePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw27m_material_characterization_gate.ps1"
$attestationHelperPath = Join-Path (
    $sdkRoot
) "locomotion_full_conformance_attestation.ps1"
$operationLockHelperPath = Join-Path (
    $sdkRoot
) "locomotion_operation_lock.ps1"
$conformancePath = Join-Path $sdkRoot "run_conformance.ps1"
$expectedClosureRawSha256 = (
    "5960c5d7f5b70f4d98356de884bb4d0c6fbc55f14d7060780efe07d6b278d519"
)
$campaignId = "BW27M-BW25Y-FRESH-MATERIAL-CHARACTERIZATION"
$gateId = "BW27M"
$physicalSourceCommit = "a219ba86f8033971c6025edb4e45d04d651a73ee"
$expectedValues = @(0.62, 0.74, 0.86)
$expectedLowerForces = @(24.0, 29.0, 33.0)
$expectedUpperForces = @(25.0, 30.0, 35.0)
$expectedLowerRatios = @(
    0.6119398367698766,
    0.739513920992915,
    0.8415623682133044
)
$expectedControllerMus = @(0.61, 0.73, 0.84)
$expectedAttestationBindingPaths = @(
    "sdk/run_conformance.ps1",
    "sdk/locomotion_operation_lock.ps1",
    "sdk/locomotion_full_conformance_attestation.ps1",
    "sdk/locomotion_operation_attestation_contract.json"
)
$expectedAttestationRawSha256 = @{
    "sdk/run_conformance.ps1" = (
        "sha256:1868325eebff349ccf2e990d3c762b16060d0030774f78a7933ee5221ac0edf9"
    )
    "sdk/locomotion_operation_lock.ps1" = (
        "sha256:105964dfcd3fdf0a4aca27cb369e2714d7ec0cc8bf7e0204e559f85567fa3e31"
    )
    "sdk/locomotion_full_conformance_attestation.ps1" = (
        "sha256:b70d00f9b77f46676520d3c39c63882313449376383758484a74690bd389a267"
    )
    "sdk/locomotion_operation_attestation_contract.json" = (
        "sha256:b7723f9c01a27eac5304fc949f0a4676589eb6b171a864978589d9e02df50742"
    )
}
$falseClaimKeys = @(
    "walking_acceptance",
    "friction_or_material_locomotion_robustness",
    "continuous_friction_coverage",
    "portable_material_coefficient",
    "cross_engine_equivalence",
    "arbitrary_quadruped_coverage",
    "continuous_full_volume_morphology_coverage",
    "rough_terrain_robustness",
    "external_push_recovery",
    "sensor_noise_or_latency_robustness",
    "turning",
    "release_authorized",
    "physical_acceptance_authority",
    "completed_engine_neutral_sdk"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Get-GitBlobRawSha256 {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$RelativePath
    )
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = "git"
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $RepoRoot, "cat-file", "blob", "${Commit}:$RelativePath"
    )) {
        [void]$startInfo.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        Assert-Exact $process.Start() (
            "$gateId could not start Git blob reader for $RelativePath"
        )
        $standardErrorTask = $process.StandardError.ReadToEndAsync()
        $hasher = [System.Security.Cryptography.SHA256]::Create()
        try {
            $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream)
        } finally {
            $hasher.Dispose()
        }
        $process.WaitForExit()
        $standardError = $standardErrorTask.GetAwaiter().GetResult()
        Assert-Exact ($process.ExitCode -eq 0) (
            "$gateId could not read historical Git blob for $RelativePath`: " +
            $standardError.Trim()
        )
        return [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally {
        $process.Dispose()
    }
}

function Assert-HashedFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][long]$ExpectedLength,
        [Parameter(Mandatory)][string]$Message
    )
    Assert-Exact (
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-RawSha256 -Path $Path) -ceq $ExpectedSha256 -and
        (Get-Item -LiteralPath $Path).Length -eq $ExpectedLength
    ) $Message
}

Assert-Exact (
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Get-RawSha256 -Path $closurePath) -ceq $expectedClosureRawSha256
) "$gateId closure is missing or changed"
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100

Assert-Exact (
    [string]$closure.schema_version -ceq
        "sporespore_balanced_wave_bw27m_material_characterization_closure_v1" -and
    [string]$closure.status -ceq
        "closed_complete_valid_positive_exact_finite_adapter_material_characterization" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq $gateId -and
    [string]$closure.study_classification -ceq
        "exact_finite_cell_adapter_material_characterization" -and
    [string]$closure.decision_classification -ceq "finite_decision" -and
    [string]$closure.physical_source_commit -ceq $physicalSourceCommit -and
    -not [bool]$closure.same_identity_rerun_allowed -and
    -not [bool]$closure.threshold_fixture_host_report_or_world_rewrite_allowed -and
    [int]$closure.physical_attempt.process_launch_count -eq 1 -and
    [int]$closure.physical_attempt.process_exit_code -eq 0 -and
    -not [bool]$closure.physical_attempt.process_timed_out -and
    -not [bool]$closure.physical_attempt.process_tree_killed -and
    [double]$closure.physical_attempt.process_duration_seconds -gt 0.0 -and
    [bool]$closure.physical_attempt.identity_consumed -and
    [bool]$closure.physical_attempt.report_retained -and
    [int]$closure.physical_attempt.expected_world_count -eq 10 -and
    [int]$closure.physical_attempt.observed_world_count -eq 10 -and
    [int]$closure.physical_attempt.locomotion_world_count -eq 0 -and
    [int]$closure.physical_attempt.expected_gate_count -eq 19 -and
    [int]$closure.physical_attempt.passed_gate_count -eq 19 -and
    [int]$closure.physical_attempt.failed_gate_count -eq 0 -and
    [bool]$closure.physical_attempt.accepted
) "$gateId closure identity, classification, or attempt summary changed"

& git -C $repoRoot cat-file -e "${physicalSourceCommit}^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) (
    "$gateId physical source commit is not retained by Git"
)
& git -C $repoRoot merge-base --is-ancestor $physicalSourceCommit HEAD
Assert-Exact ($LASTEXITCODE -eq 0) (
    "$gateId physical source is not an ancestor of HEAD"
)
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId origin/main cannot be resolved"
& git -C $repoRoot merge-base --is-ancestor $physicalSourceCommit $originMain
Assert-Exact ($LASTEXITCODE -eq 0) (
    "$gateId physical source is not retained by origin/main"
)

$sourceBindings = @($closure.frozen_source_blobs)
Assert-Exact ($sourceBindings.Count -eq 27) (
    "$gateId closure must bind all 27 report source blobs"
)
$sourcePaths = @($sourceBindings | ForEach-Object { [string]$_.path })
Assert-Exact (
    @($sourcePaths | Sort-Object -Unique).Count -eq 27
) "$gateId closure source paths are duplicated"
foreach ($entry in $sourceBindings) {
    $relativePath = [string]$entry.path
    Assert-Exact (
        [string]$entry.raw_sha256 -cmatch "^[0-9a-f]{64}$" -and
        [string]$entry.git_blob_oid -cmatch "^[0-9a-f]{40}$"
    ) "$gateId frozen source receipt is malformed: $relativePath"
    $gitBlob = (& git -C $repoRoot rev-parse (
        $physicalSourceCommit + ":" + $relativePath
    )).Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        $gitBlob -ceq [string]$entry.git_blob_oid
    ) "$gateId physical-source Git blob changed: $relativePath"
}

$qualification = $closure.pre_physical_qualification
$attestationPath = [System.IO.Path]::GetFullPath(
    [string]$qualification.attestation_path
)
$expectedAttestationPath = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "full-godot-conformance-v2-a219ba86-20260802T152828Z\attestation.json"
)
Assert-Exact (
    [bool]$qualification.full_godot_conformance_passed -and
    [string]$qualification.conformance_source_commit -ceq
        $physicalSourceCommit -and
    [string]$qualification.conformance_success_marker -ceq
        "SDK C0/C1 conformance passed." -and
    $attestationPath -ceq $expectedAttestationPath -and
    [string]$qualification.attestation_schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [double]$qualification.attestation_duration_seconds -gt 900.0 -and
    [bool]$qualification.production_file_verifier_ok -and
    @($qualification.production_file_verifier_failure_codes).Count -eq 0 -and
    -not [bool]$qualification.attestation_one_shot_physical_campaign_executed -and
    [int]$qualification.attestation_true_claim_count -eq 0 -and
    [bool]$qualification.conformance_and_physical_serialized_by_global_mutex -and
    -not [bool]$qualification.physical_lock_abandoned_owner_recovered -and
    [bool]$qualification.post_physical_lock_reacquired_cleanly -and
    -not [bool]$qualification.overlapping_physics_or_conformance_process_observed -and
    -not [bool]$qualification.physical_acceptance_authority
) "$gateId pre-physical qualification summary changed"
Assert-HashedFile `
    -Path $attestationPath `
    -ExpectedSha256 ([string]$qualification.attestation_raw_sha256) `
    -ExpectedLength ([long]$qualification.attestation_byte_length) `
    -Message "$gateId retained full-conformance attestation changed"

. $operationLockHelperPath
. $attestationHelperPath
$attestation = Get-Content -Raw -LiteralPath $attestationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$expectedTree = (& git -C $repoRoot rev-parse (
    "${physicalSourceCommit}^{tree}"
)).Trim()
$expectedAttestationBindings = @(
    foreach ($relativePath in $expectedAttestationBindingPaths) {
        $gitBlob = (& git -C $repoRoot rev-parse (
            $physicalSourceCommit + ":" + $relativePath
        )).Trim()
        Assert-Exact ($LASTEXITCODE -eq 0) (
            "$gateId cannot resolve historical attestation source $relativePath"
        )
        $historicalGitRawSha256 = "sha256:" + (
            Get-GitBlobRawSha256 `
                -RepoRoot $repoRoot `
                -Commit $physicalSourceCommit `
                -RelativePath $relativePath
        )
        $expectedRawSha256 = [string](
            $expectedAttestationRawSha256[$relativePath]
        )
        Assert-Exact ($expectedRawSha256 -cmatch "^sha256:[0-9a-f]{64}$") (
            "$gateId expected attestation hash is missing for $relativePath"
        )
        # run_conformance.ps1 had mixed working-tree line endings at the
        # pre-physical boundary. Git correctly retained its normalized source
        # as the independently checked blob above, while the attestation bound
        # the exact raw checkout bytes. The retained attestation file hash and
        # this explicit digest preserve both identities without falsely
        # reconstructing checkout line endings from a normalized Git blob.
        if ($relativePath -cne "sdk/run_conformance.ps1") {
            Assert-Exact ($expectedRawSha256 -ceq $historicalGitRawSha256) (
                "$gateId historical raw/blob digest changed for $relativePath"
            )
        }
        [ordered]@{
            path = $relativePath
            raw_sha256 = $expectedRawSha256
            git_blob_oid = $gitBlob
        }
    }
)
$attestationValidation = Test-SporeSporeFullConformanceAttestationDocument `
    -Document $attestation `
    -ExpectedSource $attestation.source `
    -ExpectedGodotIdentity $attestation.godot `
    -ExpectedPowerShellIdentity $attestation.powershell `
    -ExpectedSourceBindings $expectedAttestationBindings
Assert-Exact (
    [string]$attestation.schema_version -ceq
        "sporespore_full_godot_conformance_attestation_v2" -and
    [string]$attestation.source.commit -ceq $physicalSourceCommit -and
    [string]$attestation.source.origin_main -ceq $physicalSourceCommit -and
    [string]$attestation.source.live_github_main -ceq $physicalSourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $expectedTree -and
    [bool]$attestation.source.clean_pushed_live -and
    -not [bool]$attestation.conformance.one_shot_physical_campaign_executed -and
    [bool]$attestationValidation.ok -and
    @($attestationValidation.failure_codes).Count -eq 0 -and
    @($attestation.claims.GetEnumerator() |
        Where-Object { [bool]$_.Value }).Count -eq 0
) (
    "$gateId historical full-conformance attestation no longer validates: " +
    (@($attestationValidation.failure_codes) -join ", ")
)

$lock = $closure.operation_lock
Assert-Exact (
    [string]$lock.schema_version -ceq
        "sporespore_locomotion_operation_lock_receipt_v1" -and
    [bool]$lock.acquired -and
    [string]$lock.role -ceq "physical" -and
    [string]$lock.mutex_name -ceq
        "Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1" -and
    -not [bool]$lock.abandoned_owner_recovered -and
    [int]$lock.owner_process_id -gt 0 -and
    [int]$lock.owner_session_id -ge 0 -and
    -not [bool]$lock.test_only -and
    -not [bool]$lock.physical_acceptance_authority
) "$gateId retained physical operation-lock receipt changed"

$evidenceRoot = [System.IO.Path]::GetFullPath(
    [string]$closure.retained_evidence.root
)
$expectedEvidenceRoot = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "balanced-wave-bw27m-material-characterization-a219ba8"
)
Assert-Exact (
    $evidenceRoot -ceq $expectedEvidenceRoot -and
    -not $evidenceRoot.StartsWith(
        "C:\tmp\",
        [StringComparison]::OrdinalIgnoreCase
    )
) "$gateId retained evidence root changed or escaped durable storage"
$declaredEvidencePaths = @()
foreach ($entry in @($closure.retained_evidence.files)) {
    $declaredEvidencePaths += [string]$entry.path
    Assert-HashedFile `
        -Path (Join-Path $evidenceRoot ([string]$entry.path)) `
        -ExpectedSha256 ([string]$entry.raw_sha256) `
        -ExpectedLength ([long]$entry.byte_length) `
        -Message "$gateId retained evidence changed: $($entry.path)"
}
$observedEvidencePaths = @(
    Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File |
        ForEach-Object {
            [System.IO.Path]::GetRelativePath(
                $evidenceRoot,
                $_.FullName
            ).Replace("\", "/")
        } |
        Sort-Object
)
$declaredEvidencePaths = @($declaredEvidencePaths | Sort-Object)
Assert-Exact (
    $observedEvidencePaths.Count -eq 5 -and
    ($observedEvidencePaths -join "|") -ceq
        ($declaredEvidencePaths -join "|")
) "$gateId retained evidence file set changed"

$attemptPath = Join-Path $evidenceRoot "attempt.json"
$reportPath = Join-Path $evidenceRoot "report.json"
$attempt = Get-Content -Raw -LiteralPath $attemptPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$report = Get-Content -Raw -LiteralPath $reportPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Exact (
    [string]$attempt.schema_version -ceq
        "sporespore_balanced_wave_bw27m_material_characterization_attempt_v1" -and
    [string]$attempt.campaign_id -ceq $campaignId -and
    [string]$attempt.gate_id -ceq $gateId -and
    [string]$attempt.source_commit -ceq $physicalSourceCommit -and
    [string]$attempt.attestation_source_commit -ceq $physicalSourceCommit -and
    [string]$attempt.origin_main_commit -ceq $physicalSourceCommit -and
    [string]$attempt.remote_main_commit -ceq $physicalSourceCommit -and
    [string]$attempt.full_conformance_attestation_path -ceq $attestationPath -and
    [string]$attempt.full_conformance_attestation_sha256 -ceq
        [string]$qualification.attestation_raw_sha256 -and
    [bool]$attempt.source_worktree_clean -and
    [bool]$attempt.source_matches_live_github_main -and
    [bool]$attempt.complete_synthetic_production_gate_passed -and
    [bool]$attempt.zero_world_fixture_preflight_passed -and
    [bool]$attempt.physical_process_launch_reserved_identity_consumed -and
    -not [bool]$attempt.same_identity_rerun_allowed -and
    [int]$attempt.expected_world_count -eq 10 -and
    [int]$attempt.expected_gate_count -eq 19 -and
    [int]$attempt.locomotion_world_count -eq 0 -and
    -not [bool]$attempt.physical_acceptance_authority -and
    [int]$attempt.process_exit_code -eq 0 -and
    -not [bool]$attempt.process_timed_out -and
    -not [bool]$attempt.process_tree_killed -and
    [bool]$attempt.receipt_parsed -and
    [bool]$attempt.accepted -and
    [bool]$attempt.operation_lock.acquired -and
    [string]$attempt.operation_lock.role -ceq "physical" -and
    -not [bool]$attempt.operation_lock.abandoned_owner_recovered
) "$gateId retained attempt changed"

Assert-Exact (
    [string]$report.schema_version -ceq
        "sporespore_balanced_wave_bw27m_material_characterization_report_v1" -and
    [string]$report.campaign_id -ceq $campaignId -and
    [string]$report.gate_id -ceq $gateId -and
    [string]$report.source_commit -ceq $physicalSourceCommit -and
    [bool]$report.source_worktree_clean -and
    [bool]$report.source_matches_origin_main -and
    [bool]$report.source_matches_live_github_main -and
    [bool]$report.accepted -and
    [string]$report.result_status -ceq "passed" -and
    [bool]$report.first_complete_result_is_final -and
    -not [bool]$report.selective_replicate_rerun_allowed -and
    [int]$report.locomotion_world_count -eq 0 -and
    -not [bool]$report.material_robustness -and
    -not [bool]$report.continuous_friction_coverage -and
    -not [bool]$report.cross_engine_equivalence -and
    -not [bool]$report.physical_acceptance_authority -and
    [int]$report.godot_process.exit_code -eq 0 -and
    -not [bool]$report.godot_process.timed_out -and
    -not [bool]$report.godot_process.killed_process_tree -and
    [string]$report.godot_process.receipt_parse_failure -ceq "" -and
    [string]$report.host_identity.physics_engine -ceq "Jolt Physics" -and
    [int]$report.host_identity.physics_hz -eq 120 -and
    [int]$report.host_identity.solver_velocity_steps -eq 20 -and
    [int]$report.host_identity.solver_position_steps -eq 7 -and
    [string]$report.full_conformance_attestation.source_commit -ceq
        $physicalSourceCommit -and
    [string]$report.full_conformance_attestation.sha256 -ceq
        [string]$qualification.attestation_raw_sha256 -and
    [bool]$report.full_conformance_attestation.production_verifier_ok -and
    [bool]$report.operation_lock.acquired -and
    -not [bool]$report.operation_lock.abandoned_owner_recovered
) "$gateId retained report identity, host, result, or qualification changed"

$receipt = $report.receipt
Assert-Exact (
    [string]$receipt.schema_version -ceq
        "sporespore_balanced_wave_bw27m_material_characterization_receipt_v1" -and
    [bool]$receipt.ok -and
    [int]$receipt.expected_world_count -eq 10 -and
    [int]$receipt.observed_world_count -eq 10 -and
    [int]$receipt.expected_gate_count -eq 19 -and
    [int]$receipt.passed_gate_count -eq 19 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [bool]$receipt.cold_characterization -and
    -not [bool]$receipt.development_data_only -and
    -not [bool]$receipt.adapter_actuation_applied -and
    -not [bool]$receipt.physics_transform_or_velocity_written -and
    -not [bool]$receipt.walking -and
    -not [bool]$receipt.material_robustness -and
    -not [bool]$receipt.continuous_friction_coverage -and
    -not [bool]$receipt.cross_engine_equivalence -and
    -not [bool]$receipt.physical_acceptance_authority -and
    -not [bool]$receipt.completed_engine_neutral_sdk -and
    [bool]$receipt.invalid_value_control.rejected -and
    [double]$receipt.invalid_value_control.attempted_friction -eq 0.25 -and
    [string]$receipt.invalid_value_control.failure_code -ceq
        "SDK_FRICTION_LADDER_VALUE_INVALID" -and
    [bool]$receipt.frictionless_control.ok -and
    [string]$receipt.frictionless_control.classification -ceq "SLIDING" -and
    [int]$receipt.frictionless_control.world_build_count -eq 1 -and
    [bool]$receipt.monotonicity.ok -and
    @($receipt.monotonicity.violations).Count -eq 0
) "$gateId receipt integrity, controls, or claim boundary changed"

$authoredValues = @($receipt.fixture.authored_friction_values)
$positiveValues = @($receipt.fixture.positive_friction_values)
Assert-Exact (
    $authoredValues.Count -eq 4 -and
    [double]$authoredValues[0] -eq 0.0 -and
    $positiveValues.Count -eq 3 -and
    (@(for ($i = 0; $i -lt 3; $i += 1) {
        [double]$authoredValues[$i + 1] -eq $expectedValues[$i] -and
        [double]$positiveValues[$i] -eq $expectedValues[$i]
    }) -notcontains $false)
) "$gateId authored friction matrix changed"

$cells = @($receipt.positive_cells)
$evaluatedCells = @($report.production_gate_evaluation.cells)
$closedCells = @($closure.result.cells)
Assert-Exact (
    $cells.Count -eq 3 -and
    $evaluatedCells.Count -eq 3 -and
    $closedCells.Count -eq 3
) "$gateId must retain exactly three positive characterization cells"
for ($cellIndex = 0; $cellIndex -lt 3; $cellIndex += 1) {
    $cell = $cells[$cellIndex]
    $evaluated = $evaluatedCells[$cellIndex]
    $closed = $closedCells[$cellIndex]
    $replicates = @($cell.replicates)
    $closedBrackets = @($closed.replicate_breakaway_brackets_n)
    Assert-Exact (
        [double]$cell.authored_friction -eq $expectedValues[$cellIndex] -and
        [bool]$cell.ok -and
        $replicates.Count -eq 3 -and
        [double]$cell.minimum_lower_breakaway_force_n -eq
            $expectedLowerForces[$cellIndex] -and
        [double]$cell.minimum_lower_empirical_ratio -eq
            $expectedLowerRatios[$cellIndex] -and
        [double]$cell.coefficient_derivation.controller_mu -eq
            $expectedControllerMus[$cellIndex] -and
        [bool]$cell.coefficient_derivation.ok -and
        -not [bool]$cell.coefficient_derivation.cross_engine_equivalent -and
        -not [bool]$cell.coefficient_derivation.locomotion_robustness -and
        [double]$cell.first_sliding_force_spread_n -eq 0.0 -and
        [double]$cell.lower_breakaway_force_spread_n -eq 0.0 -and
        [double]$evaluated.authored_friction -eq $expectedValues[$cellIndex] -and
        [double]$evaluated.minimum_lower_breakaway_force_n -eq
            $expectedLowerForces[$cellIndex] -and
        [double]$evaluated.minimum_lower_empirical_ratio -eq
            $expectedLowerRatios[$cellIndex] -and
        [double]$evaluated.controller_mu -eq
            $expectedControllerMus[$cellIndex] -and
        [bool]$evaluated.passed -and
        [double]$closed.authored_friction -eq $expectedValues[$cellIndex] -and
        [double]$closed.minimum_lower_breakaway_force_n -eq
            $expectedLowerForces[$cellIndex] -and
        [double]$closed.minimum_lower_empirical_ratio -eq
            $expectedLowerRatios[$cellIndex] -and
        [double]$closed.controller_mu -eq
            $expectedControllerMus[$cellIndex] -and
        [bool]$closed.passed -and
        $closedBrackets.Count -eq 3
    ) "$gateId cell $cellIndex summary or coefficient changed"
    for ($replicateIndex = 0; $replicateIndex -lt 3; $replicateIndex += 1) {
        $replicate = $replicates[$replicateIndex]
        $closedBracket = @($closedBrackets[$replicateIndex])
        Assert-Exact (
            $closedBracket.Count -eq 2 -and
            [double]$closedBracket[0] -eq
                $expectedLowerForces[$cellIndex] -and
            [double]$closedBracket[1] -eq
                $expectedUpperForces[$cellIndex] -and
            [bool]$replicate.ok -and
            [bool]$replicate.all_stage_observations_complete -and
            [bool]$replicate.breakaway_analysis.breakaway_detected -and
            [double]$replicate.breakaway_analysis.breakaway_force_lower_n -eq
                $expectedLowerForces[$cellIndex] -and
            [double]$replicate.breakaway_analysis.breakaway_force_upper_n -eq
                $expectedUpperForces[$cellIndex] -and
            [bool]$replicate.two_consecutive_sliding_stages_observed -and
            [bool]$replicate.positive_force_held_observed -and
            [int]$replicate.world_build_count -eq 1
        ) "$gateId cell $cellIndex replicate $replicateIndex changed"
    }
}

Assert-Exact (
    [bool]$report.production_gate_evaluation.ok -and
    [int]$report.production_gate_evaluation.expected_gate_count -eq 19 -and
    [int]$report.production_gate_evaluation.reconstructed_passed_gate_count -eq 19 -and
    [int]$report.production_gate_evaluation.reconstructed_failed_gate_count -eq 0 -and
    [bool]$report.production_gate_evaluation.receipt_meta_integrity_passed -and
    [bool]$report.production_gate_evaluation.fixture_identity_and_matrix_passed -and
    [int]$report.production_gate_evaluation.observed_world_count -eq 10 -and
    @($report.production_gate_evaluation.gates).Count -eq 19 -and
    @($report.production_gate_evaluation.failure_codes).Count -eq 0 -and
    [bool]$report.production_gate_evaluation.claims_remain_bounded -and
    -not [bool]$report.production_gate_evaluation.physical_acceptance_authority
) "$gateId retained production-gate evaluation changed"
. $productionGatePath
$recomputed = Test-Bw27mMaterialCharacterizationReceipt -Receipt $receipt
Assert-Exact (
    [bool]$recomputed.ok -and
    [int]$recomputed.reconstructed_passed_gate_count -eq 19 -and
    [int]$recomputed.reconstructed_failed_gate_count -eq 0 -and
    [int]$recomputed.observed_world_count -eq 10 -and
    @($recomputed.failure_codes).Count -eq 0 -and
    -not [bool]$recomputed.physical_acceptance_authority
) "$gateId frozen production evaluator no longer accepts retained evidence"

$reportSources = $report.sources
Assert-Exact ($reportSources.Count -eq 27) (
    "$gateId retained report source map changed"
)
foreach ($entry in $sourceBindings) {
    $path = [string]$entry.path
    Assert-Exact (
        $reportSources.Contains($path) -and
        [string]$reportSources[$path].path -ceq $path -and
        [string]$reportSources[$path].sha256 -ceq
            [string]$entry.raw_sha256
    ) "$gateId report/source hash reconciliation changed: $path"
}
$evidenceMap = [ordered]@{}
foreach ($entry in @($closure.retained_evidence.files)) {
    $evidenceMap[[string]$entry.path] = $entry
}
Assert-Exact (
    [string]$report.attempt.sha256 -ceq
        [string]$evidenceMap["attempt.json"].raw_sha256 -and
    [string]$report.transcript.sha256 -ceq
        [string]$evidenceMap["transcript.log"].raw_sha256 -and
    [string]$report.engine_log.sha256 -ceq
        [string]$evidenceMap["engine.log"].raw_sha256
) "$gateId report/evidence hash reconciliation changed"

Assert-Exact (
    [bool]$closure.result.accepted -and
    [string]$closure.result.result_status -ceq "passed" -and
    [bool]$closure.result.cold_characterization -and
    (@($closure.result.authored_friction_values) -join ",") -ceq
        "0.62,0.74,0.86" -and
    [int]$closure.result.replicates_per_positive_value -eq 3 -and
    [int]$closure.result.frictionless_control_count -eq 1 -and
    [string]$closure.result.frictionless_control_classification -ceq
        "SLIDING" -and
    [double]$closure.result.invalid_authored_value -eq 0.25 -and
    [bool]$closure.result.invalid_authored_value_rejected -and
    [bool]$closure.result.operational_monotonicity_passed -and
    [bool]$closure.scientific_disposition.complete_valid_positive_exact_finite_characterization -and
    [bool]$closure.scientific_disposition.adapter_profile_publication_authorized -and
    -not [bool]$closure.scientific_disposition.locomotion_outcome_observed -and
    -not [bool]$closure.scientific_disposition.future_locomotion_seeds_opened -and
    -not [bool]$closure.scientific_disposition.material_robustness_established -and
    -not [bool]$closure.scientific_disposition.continuous_friction_coverage_established -and
    -not [bool]$closure.scientific_disposition.portable_material_coefficient_established -and
    -not [bool]$closure.scientific_disposition.cross_engine_equivalence_established -and
    -not [bool]$closure.scientific_disposition.physical_acceptance_authority
) "$gateId result or scientific disposition changed"

Assert-Exact (
    [bool]$closure.next_allowed_work.bw27m_stage_1_is_closed -and
    [bool]$closure.next_allowed_work.immutable_adapter_profile_publication_may_proceed -and
    (@($closure.next_allowed_work.profile_must_retain_exact_authored_values) -join ",") -ceq
        "0.62,0.74,0.86" -and
    (@($closure.next_allowed_work.profile_must_retain_exact_characterized_coefficients) -join ",") -ceq
        "0.61,0.73,0.84" -and
    [bool]$closure.next_allowed_work.profile_publication_must_open_zero_locomotion_worlds -and
    [bool]$closure.next_allowed_work.bw28y_manifest_may_freeze_only_after_profile_publication -and
    (@($closure.next_allowed_work.sealed_future_locomotion_seeds) -join ",") -ceq
        "27011,27012,27013,27014" -and
    [bool]$closure.next_allowed_work.bw28y_physical_locomotion_may_not_open_before_distinct_manifest_and_complete_zero_world_gate -and
    [bool]$closure.next_allowed_work.post_closure_full_conformance_pass_required_before_profile_publication -and
    [bool]$closure.next_allowed_work.release_selected_policy_unchanged -and
    [bool]$closure.next_allowed_work.release_not_authorized
) "$gateId profile-publication interlock or sealed seeds changed"

Assert-Exact (
    [bool]$closure.claims.exact_finite_godot_jolt_material_characterization -and
    [bool]$closure.claims.immutable_profile_publication_authorized
) "$gateId positive finite characterization claim changed"
foreach ($key in $falseClaimKeys) {
    Assert-Exact (-not [bool]$closure.claims[$key]) (
        "$gateId unsupported claim became true: $key"
    )
}

$conformanceRaw = Get-Content -Raw -LiteralPath $conformancePath
Assert-Exact (
    $conformanceRaw.Contains(
        'tests\test_bw27m_material_characterization_closure.ps1'
    ) -and
    -not [regex]::IsMatch(
        $conformanceRaw,
        'run_balanced_wave_bw27m_material_characterization\.ps1[\s\S]{0,320}-PreflightOnly'
    ) -and
    -not [regex]::IsMatch(
        $conformanceRaw,
        'run_balanced_wave_bw27m_material_characterization\.ps1[\s\S]{0,320}-RunPhysical'
    )
) "$gateId normal conformance can replay a consumed prospective route"

$allAttemptPaths = @(
    Get-ChildItem `
        -LiteralPath (Join-Path (
            Split-Path -Parent $repoRoot
        ) "SporeSpore_Evidence") `
        -Recurse `
        -File `
        -Filter "attempt.json" |
        Where-Object {
            try {
                $candidateAttempt = Get-Content -Raw -LiteralPath $_.FullName |
                    ConvertFrom-Json
                [string]$candidateAttempt.campaign_id -ceq $campaignId
            } catch { $false }
        }
)
Assert-Exact (
    $allAttemptPaths.Count -eq 1 -and
    [System.IO.Path]::GetFullPath($allAttemptPaths[0].FullName) -ceq
        [System.IO.Path]::GetFullPath($attemptPath)
) "$gateId must retain exactly one physical attempt"

$rerunOutput = @(
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File $supervisorPath `
        -RunPhysical `
        -OutputRoot $evidenceRoot `
        -FullConformanceAttestation $attestationPath 2>&1
)
$rerunExitCode = $LASTEXITCODE
Assert-Exact (
    $rerunExitCode -ne 0 -and
    (($rerunOutput | Out-String) -match
        "BW27M characterization is already closed and may not rerun")
) "$gateId physical rerun did not fail at the immutable closure interlock"

Write-Host (
    "BW27M_MATERIAL_CLOSURE_PASS status=positive worlds=10 gates=19 " +
    "cells=3 profile_publication=True locomotion_seeds_opened=0 " +
    "pre_physical_attestation=True conformance_overlap=False " +
    "post_closure_conformance_required=True rerun_refused=True " +
    "material_robustness=False physical_authority=False"
)

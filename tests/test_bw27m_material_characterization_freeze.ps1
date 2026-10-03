#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$SkipSupervisorPreflight,
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
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$campaignId = "BW27M-BW25Y-FRESH-MATERIAL-CHARACTERIZATION"
$gateId = "BW27M"
$freezePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw27m_material_characterization_freeze.json"
$supervisorPath = Join-Path (
    $sdkRoot
) "run_balanced_wave_bw27m_material_characterization.ps1"
$workerPath = Join-Path (
    $repoRoot
) "tests\test_sdk_balanced_wave_bw27m_material_characterization.gd"
$gateTestPath = Join-Path (
    $repoRoot
) "tests\test_bw27m_material_characterization_gate.ps1"
$declarationAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw27m_material_declaration.ps1"
$conformancePath = Join-Path $sdkRoot "run_conformance.ps1"
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw27m_material_characterization_closure.json"
$expectedFreezeSha256 = (
    "8d17138df375dcde3db1542ff02462412530687a6a5a7d986562971532329b36"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Assert-SourceContains {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string[]]$Needles,
        [Parameter(Mandatory)][string]$Label
    )
    foreach ($needle in $Needles) {
        Assert-Exact (
            $Source.Contains($needle, [StringComparison]::Ordinal)
        ) "$gateId $Label lost required text: $needle"
    }
}

Assert-Exact (
    (Test-Path -LiteralPath $freezePath -PathType Leaf) -and
    (Get-RawSha256 $freezePath) -ceq $expectedFreezeSha256
) "$gateId freeze declaration is missing or changed"
Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
) "$gateId already has a closure and is not a prospective freeze"

$freeze = Get-Content -Raw -LiteralPath $freezePath |
    ConvertFrom-Json -AsHashtable
$study = $freeze.study_class
$matrix = $freeze.physical_matrix
$correction = $freeze.gate_count_freeze
$preflight = $freeze.zero_world_authorization_preflight
$execution = $freeze.one_shot_execution_contract
$claims = $freeze.claims_after_positive_characterization
$bindings = $freeze.source_bindings
Assert-Exact (
    [string]$freeze.schema_version -ceq
        "sporespore_balanced_wave_bw27m_material_characterization_freeze_v1" -and
    [string]$freeze.status -ceq
        "frozen_before_first_bw27m_physical_world" -and
    -not [bool]$freeze.current_physical_execution_authorized -and
    [string]$freeze.campaign_id -ceq $campaignId -and
    [string]$freeze.gate_id -ceq $gateId -and
    [string]$freeze.freeze_parent_commit -ceq
        "5fe3abfcb8004c5b52caec6daf1a06ffb2224e24" -and
    [string]$study.classification -ceq
        "exact_finite_cell_adapter_material_characterization" -and
    [int]$study.positive_authored_value_count -eq 3 -and
    [int]$study.replicate_count_per_positive_value -eq 3 -and
    [int]$study.frictionless_control_world_count -eq 1 -and
    [int]$study.expected_world_count -eq 10 -and
    [int]$study.expected_gate_count -eq 19 -and
    -not [bool]$study.population_inference -and
    -not [bool]$study.superiority_study -and
    -not [bool]$study.noninferiority_or_equivalence_study -and
    -not [bool]$study.continuous_friction_coverage
) "$gateId freeze identity or finite study class changed"

Assert-Exact (
    (@($matrix.authored_friction_values) -join ",") -ceq "0.62,0.74,0.86" -and
    [double]$matrix.frictionless_control_value -eq 0.0 -and
    [int]$matrix.replicates_per_positive_value -eq 3 -and
    [int]$matrix.expected_world_count -eq 10 -and
    [int]$matrix.expected_gate_count -eq 19 -and
    [int]$matrix.downstream_locomotion_seeds_opened -eq 0 -and
    [int]$correction.stage_zero_declared_count -eq 19 -and
    [int]$correction.frozen_count -eq 19 -and
    [bool]$correction.frozen_before_any_physical_world -and
    [bool]$correction.frozen_before_any_characterization_outcome -and
    -not [bool]$correction.threshold_value_seed_or_stopping_rule_changed -and
    -not [bool]$correction.post_result_gate_edit
) "$gateId physical matrix or prephysical gate-count freeze changed"

Assert-Exact (
    [int]$preflight.production_gate_count -eq 19 -and
    [int]$preflight.negative_canary_count -eq 10 -and
    [int]$preflight.declaration_fixture_gate_count -eq 7 -and
    [int]$preflight.fixture_count -eq 4 -and
    [int]$preflight.authorization_receipt_canary_count -eq 2 -and
    [int]$preflight.direct_worker_bypass_canary_count -eq 1 -and
    [int]$preflight.world_build_count -eq 0 -and
    [int]$preflight.scene_tree_insertion_count -eq 0 -and
    [int]$preflight.physics_state_mutation_count -eq 0 -and
    -not [bool]$preflight.characterization_outcome_exposed -and
    -not [bool]$preflight.locomotion_outcome_exposed -and
    -not [bool]$preflight.physical_acceptance_authority -and
    [bool]$execution.worker_requires_explicit_run_physical_token -and
    [bool]$execution.worker_requires_exact_retained_attempt_and_matching_authorization_token -and
    [bool]$execution.worker_rejects_a_forged_run_physical_argument_without_supervisor_authorization -and
    [bool]$execution.worker_token_supplied_only_after_attempt_json_is_durably_created -and
    [bool]$execution.output_root_must_be_new_and_inside_sporespore_evidence -and
    [bool]$execution.retained_output_forbidden_under_c_tmp -and
    [bool]$execution.head_must_equal_origin_main_and_live_github_main -and
    [bool]$execution.worktree_must_be_clean -and
    [bool]$execution.matching_full_godot_conformance_attestation_v2_required -and
    [bool]$execution.attestation_must_pass_current_production_verifier -and
    [bool]$execution.attestation_source_must_equal_physical_source_commit -and
    [bool]$execution.attestation_claims_must_all_be_false -and
    [bool]$execution.global_physical_conformance_mutex_required -and
    [bool]$execution.mutex_must_be_acquired_before_source_attempt_and_attestation_checks -and
    [bool]$execution.abandoned_lock_owner_forbidden -and
    [bool]$execution.lock_must_be_held_through_final_report_write -and
    [bool]$execution.lock_release_guaranteed_by_finally -and
    [bool]$execution.prior_attempt_count_must_be_zero -and
    [bool]$execution.first_complete_result_final_for_source_identity -and
    [bool]$execution.incomplete_attempt_cannot_resume_in_place -and
    [bool]$execution.selective_replicate_rerun_forbidden -and
    [bool]$execution.failed_cell_replacement_forbidden -and
    [bool]$execution.averaging_forbidden -and
    [bool]$execution.post_result_gate_edit_forbidden
) "$gateId zero-world or one-shot execution contract changed"

Assert-Exact (
    [bool]$claims.exact_finite_godot_jolt_material_characterization -and
    [bool]$claims.profile_publication_may_proceed -and
    -not [bool]$claims.walking_acceptance -and
    -not [bool]$claims.controller_selection -and
    -not [bool]$claims.material_robustness -and
    -not [bool]$claims.continuous_friction_coverage -and
    -not [bool]$claims.arbitrary_material_robustness -and
    -not [bool]$claims.population_inference -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.release_authorized -and
    -not [bool]$claims.physical_acceptance_authority -and
    -not [bool]$claims.completed_engine_neutral_sdk
) "$gateId positive-result claim boundary changed"

Assert-Exact (
    $bindings.Count -eq 25
) "$gateId source-binding cardinality changed"
foreach ($binding in $bindings.GetEnumerator()) {
    $relativePath = [string]$binding.Value.path
    $expectedSha256 = [string]$binding.Value.raw_sha256
    $absolutePath = Join-Path $repoRoot $relativePath
    Assert-Exact (
        $expectedSha256 -cmatch "^[0-9a-f]{64}$" -and
        (Test-Path -LiteralPath $absolutePath -PathType Leaf) -and
        (Get-RawSha256 $absolutePath) -ceq $expectedSha256
    ) "$gateId frozen source is missing or changed: $relativePath"
}

& git -C $repoRoot merge-base --is-ancestor `
    ([string]$freeze.freeze_parent_commit) HEAD
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId freeze parent is not an ancestor of HEAD"

$priorAttempts = @()
if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
    $priorAttempts = @(
        Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File `
            -Filter "attempt.json" |
        Where-Object {
            try {
                $attempt = Get-Content -Raw -LiteralPath $_.FullName |
                    ConvertFrom-Json
                [string]$attempt.campaign_id -ceq $campaignId
            } catch { $false }
        }
    )
}
Assert-Exact (
    $priorAttempts.Count -eq 0
) "$gateId physical identity was already consumed"

$workerSource = Get-Content -Raw -LiteralPath $workerPath
$supervisorSource = Get-Content -Raw -LiteralPath $supervisorPath
$conformanceSource = Get-Content -Raw -LiteralPath $conformancePath
Assert-SourceContains $workerSource @(
    'extends "res://tests/test_sdk_godot_jolt_friction_ladder_characterization.gd"',
    'String(arguments[0]) != "--run-physical"',
    'BW27M_PHYSICAL_AUTHORIZATION_REQUIRED',
    'SPORESPORE_BW27M_ATTEMPT',
    'SPORESPORE_BW27M_TOKEN',
    'func _physical_authorization_exact() -> bool:',
    'func _is_lower_hex(value: String, expected_length: int) -> bool:',
    'attestation_source_commit',
    'full_conformance_attestation_path',
    'full_conformance_attestation_sha256',
    'operation_lock',
    'abandoned_owner_recovered',
    'physical_process_launch_reserved_identity_consumed',
    'const BW27M_EXPECTED_WORLD_COUNT := 10',
    'const BW27M_EXPECTED_GATE_COUNT := 19',
    'return Bw27mRigScript.build(clock, profile, friction)'
) "physical worker"
Assert-SourceContains $supervisorSource @(
    '[bool]$PreflightOnly -xor [bool]$RunPhysical',
    '[string]$FullConformanceAttestation = ""',
    '. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")',
    '. (Join-Path $sdkRoot "locomotion_full_conformance_attestation.ps1")',
    'Enter-SporeSporeLocomotionOperationLock -Role physical',
    'Test-SporeSporeFullConformanceAttestationFile',
    'Get-SporeSporeLocomotionOperationLockPublicReceipt',
    'abandoned_owner_recovered',
    'source_matches_live_github_main = $true',
    'full_conformance_attestation_path = $resolvedAttestationPath',
    'full_conformance_attestation_sha256 = $attestationSha256',
    'operation_lock = $operationLockPublic',
    'physical_process_launch_reserved_identity_consumed = $true',
    'Write-NewJsonArtifact -Value $attempt -Path $attemptPath',
    'SPORESPORE_BW27M_ATTEMPT',
    'SPORESPORE_BW27M_TOKEN',
    '@("--", "--run-physical")',
    '$process.Kill($true)',
    'same_identity_rerun_allowed = $false',
    'material_robustness = $false',
    'physical_acceptance_authority = $false',
    'Exit-SporeSporeLocomotionOperationLock -Receipt $operationLockReceipt'
) "one-shot supervisor"
$lockAcquireIndex = $supervisorSource.IndexOf(
    'Enter-SporeSporeLocomotionOperationLock -Role physical',
    [StringComparison]::Ordinal
)
$firstFrozenHashCheckIndex = $supervisorSource.IndexOf(
    'foreach ($entry in $expectedHashes.GetEnumerator())',
    [StringComparison]::Ordinal
)
$attestationVerificationIndex = $supervisorSource.IndexOf(
    'Test-SporeSporeFullConformanceAttestationFile',
    [StringComparison]::Ordinal
)
$attemptWriteIndex = $supervisorSource.IndexOf(
    'Write-NewJsonArtifact -Value $attempt -Path $attemptPath',
    [StringComparison]::Ordinal
)
$physicalTokenIndex = $supervisorSource.LastIndexOf(
    '@("--", "--run-physical")',
    [StringComparison]::Ordinal
)
$reportWriteIndex = $supervisorSource.IndexOf(
    'Write-NewJsonArtifact -Value $report -Path $reportPath',
    [StringComparison]::Ordinal
)
$lockReleaseIndex = $supervisorSource.LastIndexOf(
    'Exit-SporeSporeLocomotionOperationLock -Receipt $operationLockReceipt',
    [StringComparison]::Ordinal
)
Assert-Exact (
    $lockAcquireIndex -ge 0 -and
    $firstFrozenHashCheckIndex -gt $lockAcquireIndex -and
    $attestationVerificationIndex -gt $lockAcquireIndex -and
    $attemptWriteIndex -gt $attestationVerificationIndex -and
    $attemptWriteIndex -ge 0 -and
    $physicalTokenIndex -gt $attemptWriteIndex -and
    $reportWriteIndex -gt $physicalTokenIndex -and
    $lockReleaseIndex -gt $reportWriteIndex
) "$gateId supervisor lock, attestation, attempt, physical token, report, or release ordering changed"
Assert-Exact (
    [regex]::IsMatch(
        $conformanceSource,
        'run_balanced_wave_bw27m_material_characterization\.ps1[\s\S]{0,320}-PreflightOnly'
    ) -and
    $conformanceSource.Contains(
        'test_bw27m_material_characterization_freeze.ps1',
        [StringComparison]::Ordinal
    ) -and
    $conformanceSource.Contains(
        '-SkipSupervisorPreflight',
        [StringComparison]::Ordinal
    ) -and
    -not [regex]::IsMatch(
        $conformanceSource,
        'run_balanced_wave_bw27m_material_characterization\.ps1[\s\S]{0,240}-RunPhysical'
    )
) "$gateId normal conformance does not retain a zero-world-only invocation"

& pwsh -NoLogo -NoProfile -File $gateTestPath
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId production-gate canaries failed"
& pwsh `
    -NoLogo `
    -NoProfile `
    -File $declarationAuditPath
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId declaration audit failed"
if (-not $SkipSupervisorPreflight) {
    & pwsh `
        -NoLogo `
        -NoProfile `
        -File $supervisorPath `
        -PreflightOnly `
        -Godot $Godot
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "$gateId complete supervisor preflight failed"
}

Write-Host (
    "BW27M MATERIAL_CHARACTERIZATION_FREEZE_PASS worlds=0 " +
    "production_gates=19 canaries=12 fixture_gates=7 fixtures=4 " +
    "bypass_canaries=2 source_bindings=25 " +
    "one_shot_contract_frozen=True physical_execution_authorized=False " +
    "physical_authority=False"
)

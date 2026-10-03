#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$closurePath = Join-Path $repoRoot (
    "sdk\turning\terminal_tight_first_horizon_development_closure_v1.json"
)

function Assert-TightFirstHorizonClosure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-TightFirstHorizonSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Assert-TightFirstHorizonNumber(
    [double]$Actual, [double]$Expected, [string]$Label
) {
    Assert-TightFirstHorizonClosure (
        [Math]::Abs($Actual - $Expected) -le 1e-15
    ) "$Label changed: expected $Expected, observed $Actual"
}

Assert-TightFirstHorizonClosure (
    Test-Path -LiteralPath $closurePath -PathType Leaf
) "Tight-first horizon development closure is missing."
$closure = Get-Content -Raw -LiteralPath $closurePath | ConvertFrom-Json
Assert-TightFirstHorizonClosure (
    [string]$closure.schema_version -ceq
        "sporespore_terminal_tight_first_horizon_development_closure_v1" -and
    [string]$closure.status -ceq
        "closed_complete_development_pass_selected_for_successor_design" -and
    [string]$closure.candidate_id -ceq
        "tight_gated_acquisition_active600_v2" -and
    [string]$closure.predecessor_candidate_id -ceq
        "tight_gated_acquisition_v1" -and
    [string]$closure.study_classification -ceq
        "repeatable_outcome_exposed_two_arm_mujoco_development_screen"
) "Tight-first horizon development closure identity changed."

$source = $closure.source_identity
$commit = [string]$source.commit
& git -C $repoRoot cat-file -e "$commit^{commit}" 2>$null
Assert-TightFirstHorizonClosure ($LASTEXITCODE -eq 0) (
    "Tight-first horizon source commit is absent."
)
$observedTree = (& git -C $repoRoot rev-parse "$commit^{tree}").Trim()
Assert-TightFirstHorizonClosure (
    $LASTEXITCODE -eq 0 -and
    $observedTree -ceq [string]$source.tree_git_oid -and
    [bool]$source.clean_local_origin_live_equality_required_and_observed
) "Tight-first horizon source identity changed."
foreach ($binding in @($closure.source_git_blobs)) {
    $observed = (& git -C $repoRoot rev-parse (
        "$commit`:$([string]$binding.path)"
    )).Trim()
    Assert-TightFirstHorizonClosure (
        $LASTEXITCODE -eq 0 -and
        $observed -ceq [string]$binding.git_blob_oid
    ) "Tight-first horizon source Git blob changed: $([string]$binding.path)"
}

$contract = $closure.candidate_contract
Assert-TightFirstHorizonClosure (
    [int]$contract.maximum_active_step_count -eq 600 -and
    [int]$contract.terminal_step_count -eq 960 -and
    [int]$contract.minimum_confirmed_taper_step_count -eq 120 -and
    [int]$contract.minimum_passive_step_count -eq 360 -and
    [double]$contract.maximum_torso_tilt_rad -eq 0.01 -and
    [double]$contract.maximum_joint_position_error_rad -eq 0.2 -and
    -not [bool]$contract.arm_identity_or_heading_sign_used_by_temporal_policy
) "Tight-first horizon candidate contract changed."

$preflight = $closure.zero_world_preflight
Assert-TightFirstHorizonClosure (
    [int]$preflight.oracle_and_wrapper_test_count -eq 18 -and
    [string]$preflight.frozen_r23d13_production_refusal -ceq
        "QSDK_R23D13_MJC_CLOSED" -and
    [int]$preflight.model_construction_count -eq 0 -and
    [int]$preflight.world_attempt_count -eq 0 -and
    [int]$preflight.world_build_count -eq 0 -and
    [bool]$preflight.passed
) "Tight-first horizon zero-world boundary changed."

$run = $closure.retained_run
$runRoot = [IO.Path]::GetFullPath([string]$run.root)
Assert-TightFirstHorizonClosure (
    Test-Path -LiteralPath $runRoot -PathType Container
) "Tight-first horizon durable development run is missing."
$files = @(Get-ChildItem -LiteralPath $runRoot -Recurse -File | Sort-Object {
    $_.FullName.Substring($runRoot.Length + 1).Replace("\", "/")
})
$projectionLines = @($files | ForEach-Object {
    $relative = $_.FullName.Substring($runRoot.Length + 1).Replace("\", "/")
    "{0}`t{1}`t{2}" -f $relative, $_.Length, (
        Get-TightFirstHorizonSha256 $_.FullName
    ).Substring(7)
})
$projectionBytes = [Text.Encoding]::UTF8.GetBytes(
    ($projectionLines -join "`n") + "`n"
)
$treeSha = "sha256:" + [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData($projectionBytes)
).ToLowerInvariant()
Assert-TightFirstHorizonClosure (
    $files.Count -eq [int]$run.file_count -and
    [long](($files | Measure-Object Length -Sum).Sum) -eq
        [long]$run.total_byte_length -and
    $treeSha -ceq [string]$run.tree_raw_sha256 -and
    [int]$run.declared_world_count -eq 2 -and
    [int]$run.observed_world_count -eq 2 -and
    [bool]$run.both_development_screens_passed
) "Tight-first horizon evidence tree or disposition changed."

$aggregatePath = Join-Path $runRoot ([string]$run.aggregate_path)
Assert-TightFirstHorizonClosure (
    (Get-Item -LiteralPath $aggregatePath).Length -eq
        [long]$run.aggregate_byte_length -and
    (Get-TightFirstHorizonSha256 $aggregatePath) -ceq
        [string]$run.aggregate_raw_sha256
) "Tight-first horizon aggregate bytes changed."
$aggregate = Get-Content -Raw -LiteralPath $aggregatePath | ConvertFrom-Json
$positive = @($aggregate.results | Where-Object arm_id -ceq "positive_heading")[0]
$negative = @($aggregate.results | Where-Object arm_id -ceq "negative_heading")[0]
Assert-TightFirstHorizonClosure (
    [string]$aggregate.source_commit -ceq $commit -and
    [string]$aggregate.candidate_id -ceq
        "tight_gated_acquisition_active600_v2" -and
    [int]$aggregate.declared_world_count -eq 2 -and
    [int]$aggregate.observed_world_count -eq 2 -and
    [bool]$aggregate.both_development_screens_passed -and
    [bool]$aggregate.development_only -and
    -not [bool]$aggregate.validation_authority -and
    -not [bool]$aggregate.physical_acceptance_authority -and
    -not [bool]$aggregate.portable_basic_turning -and
    -not [bool]$aggregate.cross_engine_equivalence
) "Tight-first horizon aggregate authority changed."

foreach ($pair in @(
    [ordered]@{ result = $positive; frozen = $closure.positive_heading },
    [ordered]@{ result = $negative; frozen = $closure.negative_heading }
)) {
    $result = $pair.result
    $frozen = $pair.frozen
    Assert-TightFirstHorizonClosure (
        [int]$result.process_exit_code -eq 0 -and
        -not [bool]$result.process_timed_out -and
        [bool]$result.screen_conjunction.execution_integrity_passed -and
        [bool]$result.screen_conjunction.walking_safety_conjunction_passed -and
        [bool]$result.screen_conjunction.signed_yaw_response_passed -and
        [bool]$result.screen_conjunction.tight_first_terminal_gate_passed -and
        [bool]$result.screen_conjunction.development_screen_passed -and
        [string]$result.result_raw_sha256 -ceq
            [string]$frozen.result_raw_sha256 -and
        [string]$result.trace_artifact.raw_sha256 -ceq
            [string]$frozen.trace_raw_sha256 -and
        [int]$result.measurements.quiescent_taper_step_count -eq 120 -and
        [int]$result.measurements.passive_terminal_step_count -ge 360 -and
        [string]$result.measurements.handoff_reason -ceq
            "support_pose_quiescence_confirmed" -and
        [int]$result.measurements.post_handoff_contact_loss_step_count -eq 0
    ) "Tight-first horizon arm result changed: $([string]$result.arm_id)"
}

function Assert-TightFirstHorizonTrace(
    [object]$Result, [object]$Frozen, [int]$ExpectedActive,
    [int]$ExpectedPassive, [int]$ExpectedCoarse, [int]$ExpectedTight,
    [int]$ExpectedTaper
) {
    $tracePath = [string]$Result.trace_artifact.path
    Assert-TightFirstHorizonClosure (
        (Get-TightFirstHorizonSha256 $tracePath) -ceq
            [string]$Frozen.trace_raw_sha256
    ) "Tight-first horizon trace bytes changed: $([string]$Result.arm_id)"
    $terminal = @(Get-Content -LiteralPath $tracePath -Tail 960 |
        ForEach-Object { $_ | ConvertFrom-Json })
    $active = @($terminal | Where-Object { -not [bool]$_.zero_actuation })
    $passive = @($terminal | Where-Object { [bool]$_.zero_actuation })
    $firstCoarse = [int](0..($active.Count - 1) | Where-Object {
        [bool]$active[$_].coarse_pose_satisfied
    } | Select-Object -First 1)
    $firstTight = [int](0..($active.Count - 1) | Where-Object {
        [bool]$active[$_].tight_pose_satisfied
    } | Select-Object -First 1)
    $firstTaper = [int](0..($active.Count - 1) | Where-Object {
        [string]$active[$_].phase_id -ceq "terminal_quiescent_taper"
    } | Select-Object -First 1)
    Assert-TightFirstHorizonClosure (
        $terminal.Count -eq 960 -and
        $active.Count -eq $ExpectedActive -and
        $passive.Count -eq $ExpectedPassive -and
        $firstCoarse -eq $ExpectedCoarse -and
        $firstTight -eq $ExpectedTight -and
        $firstTaper -eq $ExpectedTaper -and
        @($active | Where-Object tight_pose_satisfied).Count -eq 121 -and
        @($passive | Where-Object {
            -not ($_.ordered_foot_contacts.front_left -and
                $_.ordered_foot_contacts.front_right -and
                $_.ordered_foot_contacts.rear_left -and
                $_.ordered_foot_contacts.rear_right)
        }).Count -eq 0
    ) "Tight-first horizon trace diagnosis changed: $([string]$Result.arm_id)"
    Assert-TightFirstHorizonNumber ([double]$active[-1].torso_tilt_rad) `
        ([double]$Frozen.final_active_torso_tilt_rad) `
        "$([string]$Result.arm_id) final active tilt"
    Assert-TightFirstHorizonNumber (
        [double]$active[-1].maximum_absolute_joint_position_error_rad
    ) ([double]$Frozen.final_active_joint_position_error_rad) `
        "$([string]$Result.arm_id) final active joint error"
    Assert-TightFirstHorizonNumber ([double]$passive[-1].torso_tilt_rad) `
        ([double]$Frozen.final_passive_torso_tilt_rad) `
        "$([string]$Result.arm_id) final passive tilt"
    Assert-TightFirstHorizonNumber (
        [double]$passive[-1].maximum_absolute_joint_position_error_rad
    ) ([double]$Frozen.final_passive_joint_position_error_rad) `
        "$([string]$Result.arm_id) final passive joint error"
}

Assert-TightFirstHorizonTrace $positive $closure.positive_heading 439 521 318 318 319
Assert-TightFirstHorizonTrace $negative $closure.negative_heading 580 380 339 459 460

$interpretation = $closure.development_interpretation
$claims = $closure.claims
Assert-TightFirstHorizonClosure (
    [string]$interpretation.candidate_result -ceq
        "complete_two_arm_development_screen_pass_selected_for_successor_design" -and
    -not [bool]$interpretation.threshold_rewrite_authorized -and
    -not [bool]$interpretation.r23d13_reclassification_authorized -and
    [bool]$interpretation.successor_design_authorized -and
    -not [bool]$interpretation.successor_physical_execution_authorized -and
    [bool]$claims.development_only -and
    [bool]$claims.candidate_selection_complete -and
    -not [bool]$claims.validation_authority -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.portable_basic_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.physical_acceptance_authority -and
    -not [bool]$claims.release_authorized
) "Tight-first horizon development claim boundary changed."

Write-Host (
    "TERMINAL_TIGHT_FIRST_HORIZON_DEVELOPMENT_CLOSURE_PASS worlds=2 " +
    "positive=pass negative=pass negative_first_tight=459 taper=120/120 " +
    "passive_positive=521 passive_negative=380 selected=True " +
    "validation=False turning=False equivalence=False physical_authority=False"
)

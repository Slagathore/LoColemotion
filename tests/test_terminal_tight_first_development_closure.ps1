#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$closurePath = Join-Path $repoRoot (
    "sdk\turning\terminal_tight_first_development_closure_v1.json"
)

function Assert-TightFirstClosure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-TightFirstClosureSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Assert-TightFirstClosureNumber(
    [double]$Actual, [double]$Expected, [string]$Label
) {
    Assert-TightFirstClosure ([Math]::Abs($Actual - $Expected) -le 1e-15) (
        "$Label changed: expected $Expected, observed $Actual"
    )
}

Assert-TightFirstClosure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "Tight-first development closure is missing."
)
$closure = Get-Content -Raw -LiteralPath $closurePath | ConvertFrom-Json
Assert-TightFirstClosure (
    [string]$closure.schema_version -ceq
        "sporespore_terminal_tight_first_development_closure_v1" -and
    [string]$closure.status -ceq
        "closed_complete_development_near_miss_negative_requires_more_confirmed_horizon" -and
    [string]$closure.candidate_id -ceq "tight_gated_acquisition_v1" -and
    [string]$closure.study_classification -ceq
        "repeatable_outcome_exposed_two_arm_mujoco_development_screen"
) "Tight-first development closure identity changed."

$source = $closure.source_identity
$commit = [string]$source.commit
$tree = [string]$source.tree_git_oid
& git -C $repoRoot cat-file -e "$commit^{commit}" 2>$null
Assert-TightFirstClosure ($LASTEXITCODE -eq 0) "Development source commit is absent."
$observedTree = (& git -C $repoRoot rev-parse "$commit^{tree}").Trim()
Assert-TightFirstClosure (
    $LASTEXITCODE -eq 0 -and $observedTree -ceq $tree -and
    [bool]$source.clean_local_origin_live_equality_required_and_observed
) "Development source tree identity changed."
foreach ($binding in @($closure.source_git_blobs)) {
    $observed = (& git -C $repoRoot rev-parse (
        "$commit`:$([string]$binding.path)"
    )).Trim()
    Assert-TightFirstClosure (
        $LASTEXITCODE -eq 0 -and $observed -ceq [string]$binding.git_blob_oid
    ) "Development source Git blob changed: $([string]$binding.path)"
}

$preflight = $closure.zero_world_preflight
Assert-TightFirstClosure (
    [int]$preflight.oracle_and_wrapper_test_count -eq 10 -and
    [string]$preflight.frozen_r23d13_production_refusal -ceq
        "QSDK_R23D13_MJC_CLOSED" -and
    [int]$preflight.model_construction_count -eq 0 -and
    [int]$preflight.world_attempt_count -eq 0 -and
    [int]$preflight.world_build_count -eq 0 -and
    [bool]$preflight.passed
) "Tight-first development zero-world boundary changed."

$run = $closure.retained_run
$runRoot = [IO.Path]::GetFullPath([string]$run.root)
Assert-TightFirstClosure (Test-Path -LiteralPath $runRoot -PathType Container) (
    "Tight-first durable development run is missing."
)
$files = @(Get-ChildItem -LiteralPath $runRoot -Recurse -File | Sort-Object {
    $_.FullName.Substring($runRoot.Length + 1).Replace("\", "/")
})
$projectionLines = @($files | ForEach-Object {
    $relative = $_.FullName.Substring($runRoot.Length + 1).Replace("\", "/")
    "{0}`t{1}`t{2}" -f $relative, $_.Length, (
        Get-TightFirstClosureSha256 $_.FullName
    ).Substring(7)
})
$projectionBytes = [Text.Encoding]::UTF8.GetBytes(
    ($projectionLines -join "`n") + "`n"
)
$treeSha = "sha256:" + [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData($projectionBytes)
).ToLowerInvariant()
Assert-TightFirstClosure (
    $files.Count -eq [int]$run.file_count -and
    [long](($files | Measure-Object Length -Sum).Sum) -eq
        [long]$run.total_byte_length -and
    $treeSha -ceq [string]$run.tree_raw_sha256 -and
    [int]$run.declared_world_count -eq 2 -and
    [int]$run.observed_world_count -eq 2 -and
    -not [bool]$run.both_development_screens_passed
) "Tight-first durable evidence tree or disposition changed."

$aggregatePath = Join-Path $runRoot ([string]$run.aggregate_path)
Assert-TightFirstClosure (
    (Get-Item -LiteralPath $aggregatePath).Length -eq
        [long]$run.aggregate_byte_length -and
    (Get-TightFirstClosureSha256 $aggregatePath) -ceq
        [string]$run.aggregate_raw_sha256
) "Tight-first aggregate bytes changed."
$aggregate = Get-Content -Raw -LiteralPath $aggregatePath | ConvertFrom-Json
$positive = @($aggregate.results | Where-Object arm_id -ceq "positive_heading")[0]
$negative = @($aggregate.results | Where-Object arm_id -ceq "negative_heading")[0]
Assert-TightFirstClosure (
    [string]$aggregate.source_commit -ceq $commit -and
    [string]$aggregate.candidate_id -ceq "tight_gated_acquisition_v1" -and
    [int]$aggregate.declared_world_count -eq 2 -and
    [int]$aggregate.observed_world_count -eq 2 -and
    -not [bool]$aggregate.both_development_screens_passed -and
    [bool]$aggregate.development_only -and
    -not [bool]$aggregate.validation_authority -and
    -not [bool]$aggregate.physical_acceptance_authority
) "Tight-first aggregate authority changed."

Assert-TightFirstClosure (
    [int]$positive.process_exit_code -eq 0 -and
    -not [bool]$positive.process_timed_out -and
    [bool]$positive.screen_conjunction.development_screen_passed -and
    [bool]$positive.screen_conjunction.tight_first_terminal_gate_passed -and
    [string]$positive.result_raw_sha256 -ceq
        [string]$closure.positive_heading.result_raw_sha256 -and
    [string]$positive.trace_artifact.raw_sha256 -ceq
        [string]$closure.positive_heading.trace_raw_sha256 -and
    [int]$positive.measurements.active_terminal_step_count -eq 439 -and
    [int]$positive.measurements.quiescent_taper_step_count -eq 120 -and
    [int]$positive.measurements.passive_terminal_step_count -eq 461 -and
    [int]$positive.measurements.post_handoff_contact_loss_step_count -eq 0
) "Tight-first positive development result changed."

Assert-TightFirstClosure (
    [int]$negative.process_exit_code -eq 0 -and
    -not [bool]$negative.process_timed_out -and
    [bool]$negative.screen_conjunction.execution_integrity_passed -and
    [bool]$negative.screen_conjunction.walking_safety_conjunction_passed -and
    [bool]$negative.screen_conjunction.signed_yaw_response_passed -and
    -not [bool]$negative.screen_conjunction.tight_first_terminal_gate_passed -and
    -not [bool]$negative.screen_conjunction.development_screen_passed -and
    [string]$negative.result_raw_sha256 -ceq
        [string]$closure.negative_heading.result_raw_sha256 -and
    [string]$negative.trace_artifact.raw_sha256 -ceq
        [string]$closure.negative_heading.trace_raw_sha256 -and
    [int]$negative.measurements.active_terminal_step_count -eq 540 -and
    [int]$negative.measurements.quiescent_taper_step_count -eq 80 -and
    [int]$negative.measurements.passive_terminal_step_count -eq 360 -and
    [string]$negative.measurements.handoff_reason -ceq
        "deadline_forced_without_quiescence_confirmation" -and
    [int]$negative.measurements.post_handoff_contact_loss_step_count -eq 0
) "Tight-first negative development result changed."

$negativeTrace = [string]$negative.trace_artifact.path
Assert-TightFirstClosure (
    (Get-TightFirstClosureSha256 $negativeTrace) -ceq
        [string]$closure.negative_heading.trace_raw_sha256
) "Tight-first negative trace bytes changed."
$terminal = @(Get-Content -LiteralPath $negativeTrace -Tail 900 |
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
Assert-TightFirstClosure (
    $active.Count -eq 540 -and $passive.Count -eq 360 -and
    $firstCoarse -eq 339 -and $firstTight -eq 459 -and $firstTaper -eq 460 -and
    @($active | Where-Object tight_pose_satisfied).Count -eq 81 -and
    @($passive | Where-Object {
        -not ($_.ordered_foot_contacts.front_left -and
            $_.ordered_foot_contacts.front_right -and
            $_.ordered_foot_contacts.rear_left -and
            $_.ordered_foot_contacts.rear_right)
    }).Count -eq 0
) "Tight-first negative trace diagnosis changed."
Assert-TightFirstClosureNumber ([double]$active[-1].torso_tilt_rad) `
    0.0050791195589021225 "Negative final active tilt"
Assert-TightFirstClosureNumber (
    [double]$active[-1].maximum_absolute_joint_position_error_rad
) 0.11415099747099541 "Negative final active joint error"
Assert-TightFirstClosureNumber ([double]$passive[-1].torso_tilt_rad) `
    0.00999446493288633 "Negative final passive tilt"
Assert-TightFirstClosureNumber (
    [double]$passive[-1].maximum_absolute_joint_position_error_rad
) 0.13998430332609546 "Negative final passive joint error"

$interpretation = $closure.development_interpretation
$claims = $closure.claims
Assert-TightFirstClosure (
    [string]$interpretation.candidate_result -ceq
        "near_miss_not_selected_as_complete_candidate" -and
    -not [bool]$interpretation.threshold_rewrite_authorized -and
    -not [bool]$interpretation.r23d13_reclassification_authorized -and
    -not [bool]$interpretation.frozen_successor_authorized -and
    [bool]$claims.development_only -and
    -not [bool]$claims.candidate_selection_complete -and
    -not [bool]$claims.validation_authority -and
    -not [bool]$claims.command_conditioned_turning -and
    -not [bool]$claims.portable_basic_turning -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.physical_acceptance_authority -and
    -not [bool]$claims.release_authorized
) "Tight-first development claim boundary changed."

Write-Host (
    "TERMINAL_TIGHT_FIRST_DEVELOPMENT_CLOSURE_PASS worlds=2 " +
    "positive=pass negative=near_miss first_tight=459 taper=80/120 " +
    "passive_contacts=360/360 selected=False validation=False " +
    "turning=False equivalence=False physical_authority=False"
)

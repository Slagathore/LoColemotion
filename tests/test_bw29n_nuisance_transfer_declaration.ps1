[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$sdkRoot = Join-Path $repoRoot "sdk"
$evidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$preregPath = Join-Path $sdkRoot "balanced_wave_bw29n_nuisance_transfer_preregistration.json"
$candidatesPath = Join-Path $sdkRoot "balanced_wave_bw29n_nuisance_transfer_candidates.json"
$manifestPath = Join-Path $sdkRoot "balanced_wave_bw29n_nuisance_transfer_manifest.json"

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Read-JsonMap {
    param([Parameter(Mandatory)][string]$Path)
    return Get-Content -Raw -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable -Depth 64
}

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) { throw $Message }
}

function Assert-ExactKeys {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Map,
        [Parameter(Mandatory)][string[]]$Keys,
        [Parameter(Mandatory)][string]$Context
    )
    $actual = @($Map.Keys | ForEach-Object { [string]$_ } | Sort-Object)
    $expected = @($Keys | Sort-Object)
    Assert-True ($actual.Count -eq $expected.Count) "$Context key count changed"
    Assert-True (($actual -join "`n") -ceq ($expected -join "`n")) "$Context keys changed"
}

function Assert-Near {
    param(
        [Parameter(Mandatory)][double]$Actual,
        [Parameter(Mandatory)][double]$Expected,
        [Parameter(Mandatory)][string]$Context
    )
    Assert-True ([math]::Abs($Actual - $Expected) -le 1.0e-12) "$Context changed"
}

$prereg = Read-JsonMap $preregPath
$declarations = Read-JsonMap $candidatesPath
$manifest = Read-JsonMap $manifestPath

Assert-True ([string]$prereg.schema_version -ceq
    "sporespore_balanced_wave_bw29n_nuisance_transfer_preregistration_v1") `
    "BW29N preregistration schema changed"
Assert-True ([string]$declarations.schema_version -ceq
    "sporespore_balanced_wave_bw29n_nuisance_transfer_candidates_v1") `
    "BW29N candidate declaration schema changed"
Assert-True ([string]$manifest.schema_version -ceq
    "sporespore_balanced_wave_bw29n_nuisance_transfer_manifest_v1") `
    "BW29N manifest schema changed"

foreach ($document in @($prereg, $declarations, $manifest)) {
    Assert-True ([string]$document.campaign_id -ceq
        "BW29N-BW19V-NUISANCE-TRANSFER-DEVELOPMENT") `
        "BW29N campaign identity changed"
    Assert-True ([string]$document.gate_id -ceq "BW29N") `
        "BW29N gate identity changed"
    Assert-True ([string]$document.implementation_parent_commit -ceq
        "57ca9f0a5eca0bba0c13570ec4a10ddcfcb0e961") `
        "BW29N implementation parent changed"
}

& git -C $repoRoot cat-file -e (
    [string]$prereg.implementation_parent_commit + "^{commit}"
) 2>$null
Assert-True ($LASTEXITCODE -eq 0) "BW29N implementation parent does not exist"

foreach ($binding in @($prereg.source_bindings.Values)) {
    $boundPath = Join-Path $repoRoot ([string]$binding.path)
    Assert-True (Test-Path -LiteralPath $boundPath -PathType Leaf) `
        ("BW29N source binding is missing: " + [string]$binding.path)
    Assert-True ((Get-RawSha256 $boundPath) -ceq [string]$binding.raw_sha256) `
        ("BW29N source binding changed: " + [string]$binding.path)
}
foreach ($binding in @($manifest.source_bindings.Values)) {
    $boundPath = Join-Path $repoRoot ([string]$binding.path)
    Assert-True (Test-Path -LiteralPath $boundPath -PathType Leaf) `
        ("BW29N manifest binding is missing: " + [string]$binding.path)
    Assert-True ((Get-RawSha256 $boundPath) -ceq [string]$binding.raw_sha256) `
        ("BW29N manifest binding changed: " + [string]$binding.path)
}
foreach ($binding in @($prereg.retained_evidence_bindings.Values)) {
    Assert-True (Test-Path -LiteralPath ([string]$binding.path) -PathType Leaf) `
        ("BW29N retained evidence is missing: " + [string]$binding.path)
    Assert-True ((Get-RawSha256 ([string]$binding.path)) -ceq
        [string]$binding.raw_sha256) `
        ("BW29N retained evidence changed: " + [string]$binding.path)
}

Assert-True ([string]$prereg.study_class.classification -ceq
    "paired_outcome_exposed_exact_finite_nuisance_transfer_development_screen") `
    "BW29N study classification changed"
Assert-True ([bool]$prereg.study_class.outcome_exposed_profiles) `
    "BW29N must disclose profile outcome exposure"
Assert-True ([bool]$prereg.study_class.outcome_exposed_seeds) `
    "BW29N must disclose seed outcome exposure"
Assert-True ([int]$prereg.study_class.expected_world_count -eq 24) `
    "BW29N preregistered world count changed"
Assert-True (-not [bool]$prereg.study_class.population_inference) `
    "BW29N may not claim population inference"
Assert-True (-not [bool]$prereg.study_class.superiority_study) `
    "BW29N is not a superiority study"
Assert-True (-not [bool]$prereg.study_class.single_mechanism_causal_attribution) `
    "BW29N may not claim a single causal mechanism"
Assert-True ([bool]$prereg.study_class.development_result_may_validly_select_none) `
    "BW29N must retain NONE as a valid result"
Assert-True ([bool]$prereg.study_class.selected_candidate_requires_distinct_independent_validation) `
    "BW29N selection must require distinct independent validation"

$candidateOrder = @($declarations.candidate_order)
Assert-True (($candidateOrder -join ',') -ceq "BW29N-A,BW29N-B") `
    "BW29N candidate order changed"
Assert-True (@($declarations.candidates).Count -eq 2) `
    "BW29N must declare exactly two candidates"
Assert-True ([string]$declarations.candidate_composition_digests.'BW29N-A' -ceq
    "sha256:794b42e64e1a89f371b0113ad1c3cf14c0a3d87abfed876323eda9e4aaeed1e6") `
    "BW29N-A canonical composition digest changed"
Assert-True ([string]$declarations.candidate_composition_digests.'BW29N-B' -ceq
    "sha256:3490c1934bb018ef68a54b5d5415c7d19dddf7696ee0ac7fca4ab27951957e4d") `
    "BW29N-B canonical composition digest changed"

$candidateA = @($declarations.candidates | Where-Object {
    [string]$_.candidate_id -ceq "BW29N-A"
}) | Select-Object -First 1
$candidateB = @($declarations.candidates | Where-Object {
    [string]$_.candidate_id -ceq "BW29N-B"
}) | Select-Object -First 1
Assert-True ($null -ne $candidateA -and $null -ne $candidateB) `
    "BW29N candidate declarations are incomplete"
Assert-True ([string]$candidateA.controller_policy_id -ceq
    "sporespore_balanced_wave_bw5r_b_v1") "BW29N-A controller changed"
Assert-True ([string]$candidateA.stability_policy_id -ceq
    "p5i3c_support_centroid_tilt_feedback_v1") "BW29N-A stability policy changed"
Assert-True ([string]$candidateA.authority_scope -ceq
    "stability_contribution_overlay") "BW29N-A authority scope changed"
Assert-True ([string]$candidateB.controller_policy_id -ceq
    "sporespore_balanced_wave_bw15f_b_v1") "BW29N-B controller changed"
Assert-True ([string]$candidateB.stability_policy_id -ceq
    "sporespore_scheduled_load_transfer_bw13p_a_v3") "BW29N-B stability policy changed"
Assert-True ([string]$candidateB.authority_scope -ceq "post_settle_full") `
    "BW29N-B authority scope changed"
Assert-Near ([double]$candidateB.global_requested_correction_scale) 0.5 `
    "BW29N-B correction scale"

foreach ($candidate in @($candidateA, $candidateB)) {
    foreach ($conditionCount in @(
        "morphology_condition_count", "material_condition_count",
        "seed_condition_count", "challenge_condition_count",
        "failure_identity_condition_count", "outcome_condition_count"
    )) {
        Assert-True ([int]$candidate[$conditionCount] -eq 0) `
            ("BW29N candidate conditions on " + $conditionCount)
    }
    Assert-True (@($candidate.branch_surfaces).Count -eq 0) `
        "BW29N candidates may not expose branch surfaces"
    Assert-True ([string]$candidate.evidence_acquisition_policy_id -ceq
        "bounded_all_support_acquisition_v1") "BW29N measurement policy changed"
    Assert-True ([int]$candidate.evidence_acquisition_maximum_ticks -eq 15) `
        "BW29N acquisition maximum changed"
    Assert-True ([int]$candidate.evidence_acquisition_minimum_all_support_dwell_ticks -eq 3) `
        "BW29N acquisition dwell changed"
    Assert-True (-not [bool]$candidate.physical_acceptance_authority) `
        "BW29N candidates have no physical authority"
}

Assert-True ([string]$declarations.controlled_comparison.comparison_type -ceq
    "whole_portable_policy_and_authority_composition") `
    "BW29N comparison type changed"
Assert-True (-not [bool]$declarations.controlled_comparison.single_mechanism_causal_attribution_authorized) `
    "BW29N may not attribute a whole-stack result to one mechanism"
Assert-True ([bool]$declarations.controlled_comparison.measurement_policy_held_identical) `
    "BW29N must hold measurement policy identical"

$profiles = @(
    [ordered]@{ id = "bw6n_baseline_v1"; token = "baseline" },
    [ordered]@{ id = "bw6n_rough_v1"; token = "rough" },
    [ordered]@{ id = "bw6n_push_v1"; token = "push" },
    [ordered]@{ id = "bw6n_sensor_noise_v1"; token = "sensor_noise" }
)
$seeds = @(21001, 21002, 21003)
$candidateSpecs = @(
    [ordered]@{ id = "BW29N-A"; suffix = "bw29n_a"; digest = "sha256:794b42e64e1a89f371b0113ad1c3cf14c0a3d87abfed876323eda9e4aaeed1e6" },
    [ordered]@{ id = "BW29N-B"; suffix = "bw29n_b"; digest = "sha256:3490c1934bb018ef68a54b5d5415c7d19dddf7696ee0ac7fca4ab27951957e4d" }
)
$expected = [System.Collections.Generic.List[object]]::new()
foreach ($profile in $profiles) {
    foreach ($seed in $seeds) {
        foreach ($candidate in $candidateSpecs) {
            $expected.Add([ordered]@{
                cell_id = "$($profile.token)_s${seed}_$($candidate.suffix)"
                cohort = "paired_outcome_exposed_nuisance_transfer"
                role = "candidate"
                campaign_seed = $seed
                challenge_profile_id = $profile.id
                candidate_id = $candidate.id
                candidate_composition_digest = $candidate.digest
                material_profile_id = "godot_jolt_bw5c_mu095_v1"
                measurement_policy_id = "bounded_all_support_acquisition_v1"
            })
        }
    }
}

$cells = @($manifest.ordered_cells)
Assert-True ($cells.Count -eq 24 -and $expected.Count -eq 24) `
    "BW29N manifest must contain exactly 24 cells"
$expectedKeys = @(
    "cell_id", "cohort", "role", "campaign_seed", "challenge_profile_id",
    "candidate_id", "candidate_composition_digest", "material_profile_id",
    "measurement_policy_id"
)
for ($index = 0; $index -lt $expected.Count; $index += 1) {
    $actual = $cells[$index]
    $wanted = $expected[$index]
    Assert-ExactKeys $actual $expectedKeys ("BW29N cell " + [string]$index)
    foreach ($key in $expectedKeys) {
        Assert-True ([string]$actual[$key] -ceq [string]$wanted[$key]) `
            ("BW29N cell " + [string]$index + " " + $key + " changed")
    }
}
Assert-True (@($cells | Group-Object cell_id | Where-Object Count -ne 1).Count -eq 0) `
    "BW29N cell IDs must be unique"
foreach ($profile in $profiles) {
    foreach ($seed in $seeds) {
        $pair = @($cells | Where-Object {
            [string]$_.challenge_profile_id -ceq $profile.id -and
            [int]$_.campaign_seed -eq $seed
        })
        Assert-True ($pair.Count -eq 2) `
            "Every BW29N profile-seed cell must have one candidate pair"
        Assert-True ((@($pair.candidate_id) -join ',') -ceq "BW29N-A,BW29N-B") `
            "BW29N within-pair candidate order changed"
    }
}

Assert-True ([bool]$prereg.historical_result_boundary.bw6n_remains_immutable_closed_negative) `
    "BW29N may not reopen BW6N"
Assert-True ([int]$prereg.historical_result_boundary.bw6n_observed_failures.total_walking_conjunction_failures -eq 5) `
    "BW29N historical BW6N failure count changed"
Assert-True (-not [bool]$prereg.measurement_policy.historical_bw6n_reinterpretation) `
    "BW29N measurement policy may not reinterpret BW6N"
Assert-True ([string]$prereg.selection_contract.neutral_or_tied_result_selects -ceq "NONE") `
    "BW29N neutral result must select NONE"
Assert-True ([string]$prereg.selection_contract.incomplete_or_integrity_invalid_result_selects -ceq "NONE") `
    "BW29N invalid result must select NONE"
Assert-True ([bool]$prereg.selection_contract.strict_total_improvement_required) `
    "BW29N selection must require strict total improvement"
Assert-True ([bool]$prereg.selection_contract.per_axis_non_regression_required) `
    "BW29N selection must forbid per-axis regression"
Assert-True (-not [bool]$prereg.selection_contract.selection_grants_nuisance_acceptance) `
    "BW29N selection may not grant nuisance acceptance"
Assert-True (-not [bool]$prereg.gate_contract.sensor_latency_in_scope) `
    "BW29N may not add uncalibrated sensor latency"

$reservedSeeds = @($prereg.pipeline_stages.stage_2_independent_nuisance_validation.reserved_unopened_seed_ids)
Assert-True (($reservedSeeds -join ',') -ceq "49101,49102,49103") `
    "BW29N reserved independent seeds changed"
Assert-True (Test-Path -LiteralPath $evidenceRoot -PathType Container) `
    "SporeSpore durable evidence root is missing"
foreach ($seed in $reservedSeeds) {
    $pattern = '"campaign_seed"\s*:\s*' + [string]$seed + '(?:\D|$)'
    $hits = @(& rg --files-with-matches -g '*.json' -- $pattern $repoRoot $evidenceRoot 2>$null)
    Assert-True ($LASTEXITCODE -eq 1) `
        ("Reserved BW29N independent seed has already been opened: " + [string]$seed)
    Assert-True ($hits.Count -eq 0) `
        ("Reserved BW29N independent seed has campaign receipts: " + [string]$seed)
}

Assert-True (-not [bool]$manifest.physical_execution_authorized) `
    "BW29N manifest may not authorize physical execution"
Assert-True (-not [bool]$manifest.independent_validation_authority) `
    "BW29N manifest may not authorize independent validation"
Assert-True (-not [bool]$manifest.release_gate_promotion_authority) `
    "BW29N manifest may not promote release gates"
Assert-True ([int]$manifest.preflight_contract.world_build_count -eq 0 -and
    [int]$prereg.required_stage_one_freeze_contract.world_build_count -eq 0) `
    "BW29N declaration preflight must remain zero-world"

foreach ($claim in @($prereg.claims_before_and_after_development.Values)) {
    Assert-True (-not [bool]$claim) "BW29N preregistration inflates a scientific claim"
}
foreach ($entry in @($declarations.claim_boundary.GetEnumerator())) {
    if ([string]$entry.Key -ceq "development_only") {
        Assert-True ([bool]$entry.Value) "BW29N must remain development-only"
    } elseif ($entry.Value -is [bool]) {
        Assert-True (-not [bool]$entry.Value) "BW29N candidate declaration inflates a claim"
    }
}

Write-Output "BW29N_DECLARATION_PASS"
Write-Output "cells=$($cells.Count)"
Write-Output "paired_profiles=4"
Write-Output "paired_seeds=3"
Write-Output "outcome_exposed=True"
Write-Output "reserved_fresh_seeds=3"
Write-Output "worlds=0"
Write-Output "physical_authority=False"

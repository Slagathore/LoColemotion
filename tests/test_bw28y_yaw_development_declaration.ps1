[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$sdkRoot = Join-Path $repoRoot "sdk"
$preregPath = Join-Path $sdkRoot "balanced_wave_bw28y_yaw_development_preregistration.json"
$candidatesPath = Join-Path $sdkRoot "balanced_wave_bw28y_yaw_development_candidates.json"
$manifestPath = Join-Path $sdkRoot "balanced_wave_bw28y_yaw_development_manifest.json"

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
    "sporespore_balanced_wave_bw28y_yaw_development_preregistration_v1") `
    "BW28Y preregistration schema changed"
Assert-True ([string]$declarations.schema_version -ceq
    "sporespore_balanced_wave_bw28y_yaw_development_candidates_v1") `
    "BW28Y candidate declaration schema changed"
Assert-True ([string]$manifest.schema_version -ceq
    "sporespore_balanced_wave_bw28y_yaw_development_manifest_v1") `
    "BW28Y manifest schema changed"
foreach ($document in @($prereg, $declarations, $manifest)) {
    Assert-True ([string]$document.campaign_id -ceq
        "BW28Y-FRESH-MATERIAL-YAW-DEVELOPMENT") "BW28Y campaign identity changed"
    Assert-True ([string]$document.gate_id -ceq "BW28Y") "BW28Y gate identity changed"
    Assert-True ([string]$document.implementation_parent_commit -ceq
        "96835e39a68f4c0ae4931338a44d7c72008c8c9a") `
        "BW28Y implementation parent changed"
}

& git -C $repoRoot cat-file -e (
    [string]$prereg.implementation_parent_commit + "^{commit}"
) 2>$null
Assert-True ($LASTEXITCODE -eq 0) "BW28Y implementation parent commit does not exist"

foreach ($binding in @($prereg.successor_provenance.source_bindings.Values)) {
    $boundPath = Join-Path $repoRoot ([string]$binding.path)
    Assert-True (Test-Path -LiteralPath $boundPath -PathType Leaf) `
        ("BW28Y source binding is missing: " + [string]$binding.path)
    Assert-True ((Get-RawSha256 $boundPath) -ceq [string]$binding.raw_sha256) `
        ("BW28Y source binding changed: " + [string]$binding.path)
}
foreach ($binding in @($manifest.source_bindings.Values)) {
    $boundPath = Join-Path $repoRoot ([string]$binding.path)
    Assert-True (Test-Path -LiteralPath $boundPath -PathType Leaf) `
        ("BW28Y manifest binding is missing: " + [string]$binding.path)
    Assert-True ((Get-RawSha256 $boundPath) -ceq [string]$binding.raw_sha256) `
        ("BW28Y manifest binding changed: " + [string]$binding.path)
}

Assert-True ([string]$prereg.study_class.classification -ceq
    "paired_outcome_unexposed_finite_controller_development_screen") `
    "BW28Y study classification changed"
Assert-True ([int]$prereg.study_class.expected_world_count -eq 28) `
    "BW28Y preregistered world count changed"
Assert-True (-not [bool]$prereg.study_class.population_inference) `
    "BW28Y may not claim population inference"
Assert-True (-not [bool]$prereg.study_class.superiority_study) `
    "BW28Y is not a superiority study"
Assert-True ([bool]$prereg.study_class.development_result_may_validly_select_none) `
    "BW28Y must retain NONE as a valid complete development result"
Assert-True ([bool]$prereg.study_class.selected_candidate_requires_distinct_independent_validation) `
    "BW28Y selection must require independent validation"

$candidateOrder = @($declarations.candidate_order)
Assert-True (($candidateOrder -join ',') -ceq "BW28Y-A,BW28Y-B") `
    "BW28Y candidate order changed"
Assert-True (@($declarations.candidates).Count -eq 2) `
    "BW28Y must declare exactly two candidates"
Assert-True ([string]$declarations.candidate_composition_digests.'BW28Y-A' -ceq
    "sha256:62c9ace116b4c7eae8bfe2253d2eb929673e3ee92a51f53ae7508fc6463f0547") `
    "BW28Y-A composition digest changed"
Assert-True ([string]$declarations.candidate_composition_digests.'BW28Y-B' -ceq
    "sha256:2dc42e65615e7472cdcc50f77b4d9d200aeb06be93c3db271f882be0a062b333") `
    "BW28Y-B composition digest changed"
Assert-True ([string]$declarations.policy_relative_control_composition_digest -ceq
    "sha256:1cab3e88229ab79779fcf10b7d2b0bfa354a8cd6c05efe924d4cfcaee1602a02") `
    "BW28Y control composition digest changed"

$candidateA = @($declarations.candidates | Where-Object {
    [string]$_.candidate_id -ceq "BW28Y-A"
}) | Select-Object -First 1
$candidateB = @($declarations.candidates | Where-Object {
    [string]$_.candidate_id -ceq "BW28Y-B"
}) | Select-Object -First 1
Assert-True ($null -ne $candidateA -and $null -ne $candidateB) `
    "BW28Y candidate declarations are incomplete"
Assert-True ([string]$candidateA.controller_policy_id -ceq
    "sporespore_balanced_wave_bw15f_b_v1") "BW28Y-A policy changed"
Assert-True ([string]$candidateB.controller_policy_id -ceq
    "sporespore_balanced_wave_bw23y_b_v1") "BW28Y-B policy changed"
Assert-Near ([double]$candidateA.yaw_error_stride_gain_per_rad) 1.3 `
    "BW28Y-A yaw gain"
Assert-Near ([double]$candidateB.yaw_error_stride_gain_per_rad) 1.0 `
    "BW28Y-B yaw gain"
foreach ($candidate in @($candidateA, $candidateB)) {
    foreach ($conditionCount in @(
        "morphology_condition_count",
        "material_condition_count",
        "seed_condition_count",
        "failure_identity_condition_count",
        "outcome_condition_count"
    )) {
        Assert-True ([int]$candidate[$conditionCount] -eq 0) `
            ("BW28Y candidate conditions on " + $conditionCount)
    }
    Assert-True (@($candidate.branch_surfaces).Count -eq 0) `
        "BW28Y candidates may not expose branch surfaces"
    Assert-True (-not [bool]$candidate.physical_acceptance_authority) `
        "BW28Y candidate declarations have no physical authority"
}

$materials = @(
    [ordered]@{ authored = 0.62; coefficient = 0.61; token = "062"; profile = "godot_jolt_bw27m_mu062_v1"; digest = "sha256:62bd8b2543c7c3cdb9b389029e5ae3de777cbcc29c5a5ba5b769863442c854c3" },
    [ordered]@{ authored = 0.74; coefficient = 0.73; token = "074"; profile = "godot_jolt_bw27m_mu074_v1"; digest = "sha256:6a8128171b87ad824b3675cbf731927681b55c0f529d179e3dbb32c842752857" },
    [ordered]@{ authored = 0.86; coefficient = 0.84; token = "086"; profile = "godot_jolt_bw27m_mu086_v1"; digest = "sha256:29735973a8334064f1a1a1fb8c8d679c335e68b4a97a396c550f68b76321863d" }
)
$seeds = @(27011, 27012, 27013, 27014)
$expected = [System.Collections.Generic.List[object]]::new()
foreach ($material in $materials) {
    foreach ($seed in $seeds) {
        foreach ($candidate in @(
            [ordered]@{ id = "BW28Y-A"; suffix = "bw28y_a"; digest = "sha256:62c9ace116b4c7eae8bfe2253d2eb929673e3ee92a51f53ae7508fc6463f0547"; policy = "sporespore_balanced_wave_bw15f_b_v1"; runtime = "sha256:1134302a1566e12d1e1179beebed893176eeed88065920855026e903738bb413"; yaw = 1.3 },
            [ordered]@{ id = "BW28Y-B"; suffix = "bw28y_b"; digest = "sha256:2dc42e65615e7472cdcc50f77b4d9d200aeb06be93c3db271f882be0a062b333"; policy = "sporespore_balanced_wave_bw23y_b_v1"; runtime = "sha256:d345d9607bed545ee6c58a20055cd6258f38ed581dd3d9f6490a9ae7f1a57570"; yaw = 1.0 }
        )) {
            $expected.Add([ordered]@{
                cell_id = "development_mu$($material.token)_s${seed}_$($candidate.suffix)"
                cohort = "paired_yaw_development"; role = "candidate"
                campaign_seed = $seed; authored_friction = $material.authored
                controller_coefficient = $material.coefficient
                profile_id = $material.profile; profile_digest = $material.digest
                candidate_id = $candidate.id; candidate_composition_digest = $candidate.digest
                controller_policy_id = $candidate.policy; runtime_profile_sha256 = $candidate.runtime
                global_requested_correction_scale = 0.5
                yaw_error_stride_gain_per_rad = $candidate.yaw
            })
        }
        if ($seed -eq 27011) {
            $expected.Add([ordered]@{
                cell_id = "development_mu$($material.token)_s27011_control"
                cohort = "material_matched_zero_residual_control"; role = "control"
                campaign_seed = 27011; authored_friction = $material.authored
                controller_coefficient = $material.coefficient
                profile_id = $material.profile; profile_digest = $material.digest
                candidate_id = "BW28Y-CONTROL"
                candidate_composition_digest = "sha256:1cab3e88229ab79779fcf10b7d2b0bfa354a8cd6c05efe924d4cfcaee1602a02"
                controller_policy_id = "sporespore_balanced_wave_bw15f_b_v1"
                runtime_profile_sha256 = "sha256:1134302a1566e12d1e1179beebed893176eeed88065920855026e903738bb413"
                global_requested_correction_scale = 0.0; yaw_error_stride_gain_per_rad = 1.3
            })
        }
    }
}
$expected.Add([ordered]@{
    cell_id = "negative_mu000_s27011_safety"; cohort = "zero_friction_safety"
    role = "safety"; campaign_seed = 27011; authored_friction = 0.0
    controller_coefficient = 0.0; profile_id = "godot_jolt_p5m1r1_mu000_v1"
    profile_digest = "sha256:b70b71e4aa16f877d1ddaf45ffc233a23300196eeb3240f4fefbe666b915b070"
    candidate_id = "BW28Y-SAFETY"; candidate_composition_digest = "NONE"
    controller_policy_id = "NONE"; runtime_profile_sha256 = "NONE"
    global_requested_correction_scale = 0.0; yaw_error_stride_gain_per_rad = 0.0
})

$cells = @($manifest.ordered_cells)
Assert-True ($cells.Count -eq 28 -and $expected.Count -eq 28) `
    "BW28Y manifest must contain exactly 28 cells"
$expectedKeys = @(
    "cell_id", "cohort", "role", "campaign_seed", "authored_friction",
    "controller_coefficient", "profile_id", "profile_digest", "candidate_id",
    "candidate_composition_digest", "controller_policy_id", "runtime_profile_sha256",
    "global_requested_correction_scale", "yaw_error_stride_gain_per_rad"
)
for ($index = 0; $index -lt $expected.Count; $index += 1) {
    $actual = $cells[$index]
    $wanted = $expected[$index]
    Assert-ExactKeys $actual $expectedKeys ("BW28Y cell " + [string]$index)
    foreach ($key in $expectedKeys) {
        if ($wanted[$key] -is [double] -or $wanted[$key] -is [float]) {
            Assert-Near ([double]$actual[$key]) ([double]$wanted[$key]) `
                ("BW28Y cell " + [string]$index + " " + $key)
        } else {
            Assert-True ([string]$actual[$key] -ceq [string]$wanted[$key]) `
                ("BW28Y cell " + [string]$index + " " + $key + " changed")
        }
    }
}

$candidateCells = @($cells | Where-Object { [string]$_.role -ceq "candidate" })
$controlCells = @($cells | Where-Object { [string]$_.role -ceq "control" })
$safetyCells = @($cells | Where-Object { [string]$_.role -ceq "safety" })
Assert-True ($candidateCells.Count -eq 24 -and $controlCells.Count -eq 3 -and
    $safetyCells.Count -eq 1) "BW28Y role cardinality changed"
Assert-True (@($cells | Group-Object cell_id | Where-Object Count -ne 1).Count -eq 0) `
    "BW28Y cell IDs must be unique"
Assert-True (@($cells | Where-Object {
    -not $_.Contains("cohort") -or [string]::IsNullOrWhiteSpace([string]$_.cohort)
}).Count -eq 0) "Every BW28Y cell must carry the inherited constructor cohort"

Assert-True ([bool]$prereg.receipt_schema_contract.actual_inherited_constructor_must_run_for_real_shaped_candidate_control_and_safety_summaries) `
    "BW28Y actual constructor preflight requirement changed"
Assert-True ([bool]$prereg.receipt_schema_contract.actual_final_composer_must_consume_every_constructor_output) `
    "BW28Y actual composer preflight requirement changed"
Assert-True ([string]$prereg.selection_contract.neutral_perfect_fixture_selects -ceq "NONE") `
    "BW28Y neutral perfect fixture must select NONE"
Assert-True ([bool]$prereg.selection_contract.empty_candidate_set_must_fail_closed_without_parameter_binding_exception) `
    "BW28Y empty-candidate evaluator canary changed"
Assert-True (-not [bool]$manifest.physical_execution_authorized) `
    "BW28Y manifest may not authorize physical execution"
Assert-True (-not [bool]$manifest.independent_validation_authority) `
    "BW28Y manifest may not authorize independent validation"
Assert-True ([int]$manifest.preflight_contract.world_build_count -eq 0 -and
    [int]$prereg.required_stage_one_freeze_contract.world_build_count -eq 0) `
    "BW28Y declaration preflight must remain zero-world"

foreach ($claim in @($prereg.claims_before_and_after_development.Values)) {
    Assert-True (-not [bool]$claim) "BW28Y preregistration inflates a scientific claim"
}
foreach ($entry in @($declarations.claim_boundary.GetEnumerator())) {
    if ([string]$entry.Key -ceq "development_only") {
        Assert-True ([bool]$entry.Value) "BW28Y must remain development-only"
    } elseif ($entry.Value -is [bool]) {
        Assert-True (-not [bool]$entry.Value) "BW28Y candidate declaration inflates a claim"
    }
}

Write-Output "BW28Y_DECLARATION_PASS"
Write-Output "cells=$($cells.Count)"
Write-Output "candidates=$($candidateCells.Count)"
Write-Output "controls=$($controlCells.Count)"
Write-Output "safety=$($safetyCells.Count)"
Write-Output "cohort_complete=True"
Write-Output "worlds=0"
Write-Output "physical_authority=False"

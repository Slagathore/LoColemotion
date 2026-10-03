#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$manifestPath = Join-Path $repoRoot `
    "sdk\balanced_wave_bw27m_fresh_material_preregistration.json"
$manifest = Get-Content -Raw -LiteralPath $manifestPath |
    ConvertFrom-Json -AsHashtable -Depth 100

function Assert-Exact([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256([string]$Path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Add-HistoricalReservationValues(
    [object]$Node,
    [System.Collections.Generic.HashSet[double]]$FrictionValues,
    [System.Collections.Generic.HashSet[long]]$Seeds
) {
    if ($Node -is [System.Collections.IDictionary]) {
        foreach ($key in $Node.Keys) {
            $value = $Node[$key]
            if ([string]$key -cmatch '^(' +
                'authored_friction|authored_friction_values|' +
                'bw4_authored_friction_values|previous_authored_friction_values|' +
                'opened_bw4_authored_friction_values|' +
                'cold_unbiased_authored_friction_values)$') {
                foreach ($entry in @($value)) {
                    if ($entry -is [ValueType]) {
                        [void]$FrictionValues.Add([double]$entry)
                    }
                }
            }
            if ([string]$key -cmatch '^(' +
                'campaign_seed|campaign_seeds|seeds|downstream_locomotion_seeds|' +
                'locomotion_campaign_seeds|reserved_campaign_seeds|' +
                'r05c_campaign_seeds|independent_validation_campaign_seeds|' +
                'cold_unbiased_campaign_seeds)$') {
                foreach ($entry in @($value)) {
                    if ($entry -is [ValueType]) {
                        [void]$Seeds.Add([long]$entry)
                    }
                }
            }
            Add-HistoricalReservationValues $value $FrictionValues $Seeds
        }
    } elseif ($Node -is [array]) {
        foreach ($entry in $Node) {
            Add-HistoricalReservationValues $entry $FrictionValues $Seeds
        }
    }
}

Assert-Exact (
    [string]$manifest.schema_version -ceq
        "sporespore_balanced_wave_bw27m_fresh_material_preregistration_v1" -and
    [string]$manifest.status -ceq
        "prospective_reservation_and_stage_order_only_physical_execution_blocked" -and
    [string]$manifest.campaign_id -ceq
        "BW27M-BW25Y-FRESH-MATERIAL-CHARACTERIZATION" -and
    [string]$manifest.gate_id -ceq "BW27M"
) "BW27M declaration identity changed."

$parentCommit = [string]$manifest.implementation_parent_commit
& git -C $repoRoot cat-file -e "$parentCommit`^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "BW27M implementation parent is unavailable."
$parentTree = (& git -C $repoRoot rev-parse "$parentCommit`^{tree}").Trim()
Assert-Exact (
    $parentCommit -ceq "f375caade24d07db8df88105b8b03eb0c6a353fa" -and
    $parentTree -ceq [string]$manifest.implementation_parent_tree_git_oid
) "BW27M implementation parent identity changed."

foreach ($binding in $manifest.successor_provenance.source_bindings.Values) {
    $path = Join-Path $repoRoot ([string]$binding.path)
    Assert-Exact (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 $path) -ceq [string]$binding.raw_sha256
    ) "BW27M source binding changed: $([string]$binding.path)"
}

$parentJsonPaths = @(& git -C $repoRoot ls-tree -r --name-only $parentCommit -- `
    "sdk" | Where-Object {
        [string]$_ -cmatch '^sdk/balanced_wave[^/]*\.json$'
    })
Assert-Exact ($LASTEXITCODE -eq 0 -and $parentJsonPaths.Count -gt 0) `
    "BW27M parent JSON inventory is unavailable."
$historicalFriction = [System.Collections.Generic.HashSet[double]]::new()
$historicalSeeds = [System.Collections.Generic.HashSet[long]]::new()
foreach ($relativePath in $parentJsonPaths) {
    $raw = (& git -C $repoRoot show "$parentCommit`:$relativePath") -join "`n"
    Assert-Exact ($LASTEXITCODE -eq 0) `
        "BW27M parent blob is unavailable: $relativePath"
    $document = $raw | ConvertFrom-Json -AsHashtable -Depth 100
    Add-HistoricalReservationValues $document $historicalFriction $historicalSeeds
}

$values = @($manifest.fresh_reservation.authored_friction_values |
    ForEach-Object { [double]$_ })
$seeds = @($manifest.fresh_reservation.downstream_locomotion_seeds |
    ForEach-Object { [long]$_ })
Assert-Exact (
    ($values | ConvertTo-Json -Compress) -ceq '[0.62,0.74,0.86]' -and
    ($seeds | ConvertTo-Json -Compress) -ceq '[27011,27012,27013,27014]' -and
    ($values | Sort-Object -Unique).Count -eq 3 -and
    ($seeds | Sort-Object -Unique).Count -eq 4
) "BW27M fresh reservation changed."
foreach ($value in $values) {
    Assert-Exact (-not $historicalFriction.Contains($value)) `
        "BW27M friction value was already authored or reserved: $value"
}
foreach ($seed in $seeds) {
    Assert-Exact (-not $historicalSeeds.Contains($seed)) `
        "BW27M seed was already used or reserved: $seed"
}

$bw24m = Get-Content -Raw -LiteralPath (Join-Path $repoRoot `
    "sdk\balanced_wave_bw24m_fresh_material_preregistration.json") |
    ConvertFrom-Json -AsHashtable -Depth 100
$bw24mValues = @($bw24m.fresh_reservation.authored_friction_values |
    ForEach-Object { [double]$_ })
for ($index = 0; $index -lt $values.Count; $index++) {
    Assert-Exact (
        [Math]::Abs(($values[$index] - $bw24mValues[$index]) - 0.03) -le 1e-12
    ) "BW27M deterministic +0.03 value derivation changed."
}

$future = $manifest.planned_future_bw28y_development_contract
Assert-Exact (
    [string]$future.candidate_a.controller_policy_id -ceq
        "sporespore_balanced_wave_bw15f_b_v1" -and
    [double]$future.candidate_a.yaw_error_stride_gain_per_rad -eq 1.3 -and
    [string]$future.candidate_b.controller_policy_id -ceq
        "sporespore_balanced_wave_bw23y_b_v1" -and
    [double]$future.candidate_b.yaw_error_stride_gain_per_rad -eq 1.0 -and
    [int]$future.expected_world_count -eq 28 -and
    [bool]$future.actual_constructor_and_final_composer_preflight_required -and
    [bool]$future.nested_selection_authority_firewall_required -and
    [bool]$future.neutral_perfect_fixture_must_select_none -and
    [bool]$future.valid_walking_negative_must_remain_structurally_valid
) "BW27M planned BW28Y controlled contrast changed."

Assert-Exact (
    [int]$manifest.planned_material_characterization.expected_world_count -eq 10 -and
    [int]$manifest.planned_material_characterization.expected_gate_count -eq 19 -and
    [bool]$manifest.pipeline_stages.stage_1_material_characterization.
        may_not_open_from_this_document -and
    -not [bool]$manifest.current_claim_boundary.material_characterization_complete -and
    -not [bool]$manifest.current_claim_boundary.development_result_complete -and
    -not [bool]$manifest.current_claim_boundary.controller_selected -and
    -not [bool]$manifest.current_claim_boundary.walking_acceptance -and
    -not [bool]$manifest.current_claim_boundary.turning_acceptance -and
    -not [bool]$manifest.current_claim_boundary.bounded_discrete_material_robustness -and
    -not [bool]$manifest.current_claim_boundary.cross_engine_equivalence -and
    -not [bool]$manifest.current_claim_boundary.release_authorized -and
    -not [bool]$manifest.current_claim_boundary.physical_acceptance_authority -and
    [int]$manifest.stage_0_contract.world_build_count -eq 0 -and
    [int]$manifest.stage_0_contract.scene_tree_insertion_count -eq 0 -and
    [int]$manifest.stage_0_contract.physics_state_mutation_count -eq 0
) "BW27M stage or claim boundary changed."

Write-Host (
    "BW27M_MATERIAL_DECLARATION_PASS values=0.62,0.74,0.86 " +
    "seeds=27011,27012,27013,27014 historical_values=$($historicalFriction.Count) " +
    "historical_seeds=$($historicalSeeds.Count) worlds=0 physical_authority=False"
)

#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
. (Join-Path $root "sdk\physical_authorization_projection.ps1")

$schema = "sporespore_qsdk_physical_route_authorization_projection_v1"
$closureSchema = "sporespore_qsdk_r24d59_godot_authorization_projection_zero_world_qualification_closure_v1"
$gate = "QSDK-R24D59"
$seed = 1802965793
$label = "QSDK-R24D59/ghost/godot/route-smoke-v1"
$seedSha = "sha256:6b7713211af9307aa873e63613a9433a0ec138cbd1e6ec0ed893fcd39a8d99d8"
$freeze = ("a" * 40) -join ""
$valid = [ordered]@{
    schema_version = $closureSchema
    gate_id = $gate
    question_class = "development"
    source = [ordered]@{ source_freeze_commit = $freeze }
    physical_authorization = [ordered]@{
        schema_version = $schema
        gate_id = $gate
        question_class = "development"
        zero_world_qualification_passed = $true
        source_freeze_commit = $freeze
        seed = $seed
        seed_label = $label
        seed_sha256 = $seedSha
        held_out = $false
        maximum_model_construction_attempt_count = 1
        maximum_model_construction_count = 1
        maximum_world_attempt_count = 1
        maximum_world_build_count = 1
        maximum_outer_solver_steps = 2
        physics_ticks_per_second = 120
        outer_step_duration_s = 1.0 / 120.0
        same_identity_rerun_permitted = $false
        recovery_success_required = $false
        physical_execution_authorized = $true
        prone_to_standing_claimed = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
}
function Invoke-Projection {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Closure)
    ConvertTo-SporeSporePhysicalAuthorizationProjection `
        -Closure $Closure -ClosureSchema $closureSchema `
        -ProjectionSchema $schema -GateId $gate -Seed $seed `
        -SeedLabel $label -SeedSha256 $seedSha
}
function Copy-Fixture {
    return ($valid | ConvertTo-Json -Depth 40 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 40)
}

$positive = Invoke-Projection -Closure $valid
$mutations = @(
    @{ id="missing_projection"; code="missing_projection"; apply={ param($v) $v.Remove("physical_authorization") } },
    @{ id="projection_type"; code="projection_type"; apply={ param($v) $v.physical_authorization="invalid" } },
    @{ id="source_type"; code="source_type"; apply={ param($v) $v.source="invalid" } },
    @{ id="wrong_closure_schema"; code="closure_schema"; apply={ param($v) $v.schema_version="wrong" } },
    @{ id="wrong_gate"; code="closure_gate"; apply={ param($v) $v.gate_id="QSDK-WRONG" } },
    @{ id="wrong_closure_question"; code="closure_question"; apply={ param($v) $v.question_class="finite_decision" } },
    @{ id="wrong_projection_schema"; code="projection_schema"; apply={ param($v) $v.physical_authorization.schema_version="wrong" } },
    @{ id="wrong_projection_gate"; code="projection_gate"; apply={ param($v) $v.physical_authorization.gate_id="QSDK-WRONG" } },
    @{ id="wrong_projection_question"; code="projection_question"; apply={ param($v) $v.physical_authorization.question_class="finite_decision" } },
    @{ id="qualification_false"; code="qualification"; apply={ param($v) $v.physical_authorization.zero_world_qualification_passed=$false } },
    @{ id="freeze_shape"; code="freeze_shape"; apply={ param($v) $v.source.source_freeze_commit="bad"; $v.physical_authorization.source_freeze_commit="bad" } },
    @{ id="freeze_mismatch"; code="freeze_binding"; apply={ param($v) $v.physical_authorization.source_freeze_commit=("b"*40)-join "" } },
    @{ id="wrong_seed"; code="seed"; apply={ param($v) $v.physical_authorization.seed=1 } },
    @{ id="wrong_seed_label"; code="seed_label"; apply={ param($v) $v.physical_authorization.seed_label="wrong" } },
    @{ id="wrong_seed_sha"; code="seed_sha"; apply={ param($v) $v.physical_authorization.seed_sha256="sha256:"+("0"*64) } },
    @{ id="held_out"; code="held_out"; apply={ param($v) $v.physical_authorization.held_out=$true } },
    @{ id="model_attempt_budget"; code="model_attempt_budget"; apply={ param($v) $v.physical_authorization.maximum_model_construction_attempt_count=2 } },
    @{ id="model_budget"; code="model_budget"; apply={ param($v) $v.physical_authorization.maximum_model_construction_count=2 } },
    @{ id="world_attempt_budget"; code="world_attempt_budget"; apply={ param($v) $v.physical_authorization.maximum_world_attempt_count=2 } },
    @{ id="world_budget"; code="world_budget"; apply={ param($v) $v.physical_authorization.maximum_world_build_count=2 } },
    @{ id="step_budget"; code="step_budget"; apply={ param($v) $v.physical_authorization.maximum_outer_solver_steps=3 } },
    @{ id="physics_hz"; code="physics_hz"; apply={ param($v) $v.physical_authorization.physics_ticks_per_second=121 } },
    @{ id="step_duration"; code="step_duration"; apply={ param($v) $v.physical_authorization.outer_step_duration_s=0.01 } },
    @{ id="rerun"; code="rerun"; apply={ param($v) $v.physical_authorization.same_identity_rerun_permitted=$true } },
    @{ id="recovery_success"; code="recovery_success"; apply={ param($v) $v.physical_authorization.recovery_success_required=$true } },
    @{ id="physical_execution"; code="physical_execution"; apply={ param($v) $v.physical_authorization.physical_execution_authorized=$false } },
    @{ id="prone_claim"; code="prone_claim"; apply={ param($v) $v.physical_authorization.prone_to_standing_claimed=$true } },
    @{ id="physical_authority"; code="physical_authority"; apply={ param($v) $v.physical_authorization.physical_acceptance_authority=$true } },
    @{ id="release_authority"; code="release_authority"; apply={ param($v) $v.physical_authorization.release_authority=$true } }
)
$rejections = @()
foreach ($mutation in $mutations) {
    $fixture = Copy-Fixture
    & $mutation.apply $fixture
    $rejected = $false
    try { $null = Invoke-Projection -Closure $fixture }
    catch {
        $rejected = $_.Exception.Message -ceq (
            "SPORESPORE_PHYSICAL_AUTHORIZATION_PROJECTION:" + $mutation.code
        )
    }
    if (-not $rejected) { throw "AUTHORIZATION_MUTATION_NOT_REJECTED:$($mutation.id)" }
    $rejections += [ordered]@{ mutation_id=$mutation.id; expected_code=$mutation.code; rejected=$true }
}
$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_physical_authorization_projection_zero_world_v1"
    gate_id = $gate
    ok = $true
    projection = $positive
    positive_control_count = 1
    mutation_rejection_count = $rejections.Count
    mutation_rejections = $rejections
    held_out_cell_access_count = 0
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    solver_step_count = 0
    physics_state_modified = $false
    physical_execution_authorized = $false
    physical_acceptance_authority = $false
    release_authority = $false
}
Write-Output (
    "QSDK_PHYSICAL_AUTHORIZATION_PROJECTION_ZERO_WORLD " +
    ($receipt | ConvertTo-Json -Depth 60 -Compress)
)

#requires -Version 7.0

<#
Shared, zero-world projection of a published scientific closure into the small
authorization record consumed by bounded physical supervisors.
#>

function Test-SporeSporeDirectQuestionAuthorization {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Closure,
        [Parameter(Mandatory)][string]$PhysicalQuestionKind
    )

    if (-not $Closure.Contains("decision") -or
        $Closure["decision"] -isnot [System.Collections.IDictionary]) {
        return $false
    }
    $decision = $Closure["decision"]
    if ($PhysicalQuestionKind -ceq "integration_ghost") {
        return [bool]$decision["physical_ghost_authorized"]
    }
    if ($PhysicalQuestionKind -ceq "behavior_development") {
        return [bool]$decision["physical_behavior_attempt_authorized"]
    }
    return $false
}

function ConvertTo-SporeSporePhysicalAuthorizationProjection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Closure,
        [Parameter(Mandatory)][string]$ClosureSchema,
        [Parameter(Mandatory)][string]$ProjectionSchema,
        [Parameter(Mandatory)][string]$GateId,
        [Parameter(Mandatory)][int]$Seed,
        [Parameter(Mandatory)][string]$SeedLabel,
        [Parameter(Mandatory)][string]$SeedSha256,
        [int]$PhysicsTicksPerSecond = 120,
        [int]$MaximumModelConstructionAttemptCount = 1,
        [int]$MaximumModelConstructionCount = 1,
        [int]$MaximumWorldAttemptCount = 1,
        [int]$MaximumWorldBuildCount = 1,
        [int]$MaximumOuterSolverSteps = 2
    )

    $fail = {
        param([string]$Code)
        throw "SPORESPORE_PHYSICAL_AUTHORIZATION_PROJECTION:$Code"
    }
    if (-not $Closure.Contains("physical_authorization")) {
        & $fail "missing_projection"
    }
    $projection = $Closure["physical_authorization"]
    if ($projection -isnot [System.Collections.IDictionary]) {
        & $fail "projection_type"
    }
    if (-not $Closure.Contains("source") -or
        $Closure["source"] -isnot [System.Collections.IDictionary]) {
        & $fail "source_type"
    }
    $source = $Closure["source"]
    $freeze = [string]$source["source_freeze_commit"]
    $outerStepDurationS = 1.0 / [double]$PhysicsTicksPerSecond
    $checks = [ordered]@{
        closure_schema = [string]$Closure["schema_version"] -ceq $ClosureSchema
        closure_gate = [string]$Closure["gate_id"] -ceq $GateId
        closure_question = [string]$Closure["question_class"] -ceq "development"
        projection_schema = [string]$projection["schema_version"] -ceq $ProjectionSchema
        projection_gate = [string]$projection["gate_id"] -ceq $GateId
        projection_question = [string]$projection["question_class"] -ceq "development"
        qualification = [bool]$projection["zero_world_qualification_passed"]
        freeze_shape = $freeze -cmatch '^[0-9a-f]{40}$'
        freeze_binding = [string]$projection["source_freeze_commit"] -ceq $freeze
        seed = [int]$projection["seed"] -eq $Seed
        seed_label = [string]$projection["seed_label"] -ceq $SeedLabel
        seed_sha = [string]$projection["seed_sha256"] -ceq $SeedSha256
        held_out = -not [bool]$projection["held_out"]
        model_attempt_budget = [int]$projection["maximum_model_construction_attempt_count"] -eq
            $MaximumModelConstructionAttemptCount
        model_budget = [int]$projection["maximum_model_construction_count"] -eq
            $MaximumModelConstructionCount
        world_attempt_budget = [int]$projection["maximum_world_attempt_count"] -eq
            $MaximumWorldAttemptCount
        world_budget = [int]$projection["maximum_world_build_count"] -eq $MaximumWorldBuildCount
        step_budget = [int]$projection["maximum_outer_solver_steps"] -eq $MaximumOuterSolverSteps
        physics_hz = [int]$projection["physics_ticks_per_second"] -eq $PhysicsTicksPerSecond
        step_duration = [double]$projection["outer_step_duration_s"] -eq $outerStepDurationS
        rerun = -not [bool]$projection["same_identity_rerun_permitted"]
        recovery_success = -not [bool]$projection["recovery_success_required"]
        physical_execution = [bool]$projection["physical_execution_authorized"]
        prone_claim = -not [bool]$projection["prone_to_standing_claimed"]
        physical_authority = -not [bool]$projection["physical_acceptance_authority"]
        release_authority = -not [bool]$projection["release_authority"]
    }
    foreach ($entry in $checks.GetEnumerator()) {
        if (-not [bool]$entry.Value) { & $fail ([string]$entry.Key) }
    }
    return [ordered]@{
        schema_version = $ProjectionSchema
        gate_id = $GateId
        question_class = "development"
        zero_world_qualification_passed = $true
        source_freeze_commit = $freeze
        seed = $Seed
        seed_label = $SeedLabel
        seed_sha256 = $SeedSha256
        held_out = $false
        maximum_model_construction_attempt_count = $MaximumModelConstructionAttemptCount
        maximum_model_construction_count = $MaximumModelConstructionCount
        maximum_world_attempt_count = $MaximumWorldAttemptCount
        maximum_world_build_count = $MaximumWorldBuildCount
        maximum_outer_solver_steps = $MaximumOuterSolverSteps
        physics_ticks_per_second = $PhysicsTicksPerSecond
        outer_step_duration_s = $outerStepDurationS
        same_identity_rerun_permitted = $false
        recovery_success_required = $false
        physical_execution_authorized = $true
        prone_to_standing_claimed = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
}

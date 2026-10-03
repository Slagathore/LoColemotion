#requires -Version 7.0
<# Source-only IPC fixture: use the actual pair consumer, never its supervisor. #>
[CmdletBinding()]
param([ValidateSet("Child", "Population")][string]$Mode = "Child")
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
if ($root -cne "C:\Users\Cole\CodeStuff\games\SporeSpore") { throw "L14_PAIR_TEST_ROOT" }
. (Join-Path $root "sdk/qsdk_r10f_process_isolated_pair_evaluator.ps1")
$inputText = [Console]::In.ReadToEnd()
$request = $inputText | ConvertFrom-Json -AsHashtable -Depth 100
$before = $request | ConvertTo-Json -Depth 100 -Compress
if ($Mode -ceq "Child") {
    $identity = $request.expected_identity
    $result = Get-QsdkR10fL9ChildValidation `
        -Report $request.report `
        -ExpectedRole $identity.expected_role `
        -ExpectedParentAttemptId $identity.expected_parent_attempt_id `
        -ExpectedChildAttemptId $identity.expected_child_attempt_id `
        -ExpectedSourceCommit $identity.expected_source_commit `
        -ExpectedAuthoritySha256 $identity.expected_authority_sha256 `
        -ExpectedWorkerProcessId $identity.expected_worker_process_id
} else {
    $result = Invoke-QsdkR10fL9ProcessPopulationEvaluation `
        -ChildEnvelopes $request.child_envelopes `
        -ExpectedParentAttemptId $request.expected_parent_attempt_id `
        -ExpectedSourceCommit $request.expected_source_commit `
        -ExpectedAuthoritySha256 $request.expected_authority_sha256
}
$after = $request | ConvertTo-Json -Depth 100 -Compress
if ($before -cne $after) { throw "L14_PAIR_TEST_SOURCE_OBJECT_MUTATED" }
$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r10f_l14_pair_source_bridge_zero_world_v1"
    gate_id = "QSDK-R10F"
    repair_id = "QSDK-R10F-L14"
    ledger_scope = [ordered]@{
        subsystem = "recovery"
        engine_scope = "godot_jolt"
        authority_mode = "source_only_actual_pair_consumer_fixture"
        question_class = "development"
    }
    result = $result
    source_object_changed = $false
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    scene_tree_insertion_count = 0
    native_readback_count = 0
    solver_step_count = 0
    physics_state_modified = $false
    physical_execution_authorized = $false
    physical_acceptance_authority = $false
    release_authority = $false
}
Write-Output ("QSDK_R10F_L14_PAIR_SOURCE_BRIDGE_ZERO_WORLD " + ($receipt | ConvertTo-Json -Depth 100 -Compress))

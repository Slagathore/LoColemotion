#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$GodotSourceRoot =
        "C:\Users\Cole\CodeStuff\dependencies\godot-sporespore-4.7"
)

$ErrorActionPreference = "Stop"
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$closureRelative = (
    "sdk/recovery/r24d4_godot_jolt_one_hinge_telemetry_" +
    "zero_world_failure_closure_v1.json"
)
$closurePath = Join-Path $repoRoot $closureRelative
$artifactStorePath = Join-Path $repoRoot "sdk/content_addressed_artifact_store.ps1"
. $artifactStorePath

function Assert-R24D4Closure {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Code
    )
    if (-not $Condition) { throw "QSDK-R24D4 zero-world closure: $Code" }
}

function Get-R24D4ClosureSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Get-R24D4ClosureMarker {
    param(
        [AllowEmptyString()][Parameter(Mandatory)][string[]]$Lines,
        [Parameter(Mandatory)][string]$Prefix,
        [Parameter(Mandatory)][string]$Code
    )
    $matches = @($Lines | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R24D4Closure ($matches.Count -eq 1) "${Code}_marker_count"
    return ([string]$matches[0]).Substring($Prefix.Length)
}

Assert-R24D4Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/")
) "repository_root"
Assert-R24D4Closure (
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository_remote"
Assert-R24D4Closure (
    Test-Path -LiteralPath $closurePath -PathType Leaf
) "closure_missing"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D4Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r24d4_one_hinge_telemetry_zero_world_failure_closure_v1" -and
    [string]$closure.closure_id -ceq "QSDK-R24D4-ZW1-CLOSURE" -and
    [string]$closure.gate_id -ceq "QSDK-R24D4" -and
    [string]$closure.question_class -ceq "non_physical_source_conformance" -and
    [string]$closure.status -ceq
        "valid_zero_world_negative_source_oracle_axis_mismatch"
) "closure_identity"

$source = [hashtable]$closure.source
$sourceCommit = [string]$source.commit
Assert-R24D4Closure (
    $sourceCommit -ceq "6e24a729bac03e02cf247583f5e321040b4b011a" -and
    [string]$source.repository_root -ceq $repoRoot.Replace("\", "/") -and
    [string]$source.remote -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    [string]$source.branch -ceq "main" -and
    [bool]$source.clean_pushed_before_attempt -and
    [bool]$source.local_upstream_cached_live_equal_before_attempt -and
    [int]$source.worktree_count -eq 1
) "source_identity"
git -C $repoRoot cat-file -e "$sourceCommit^{commit}"
Assert-R24D4Closure ($LASTEXITCODE -eq 0) "source_commit_missing"

$validationManifest = [hashtable]$source.validation_manifest
$sourceBindings = @($closure.source_bindings)
Assert-R24D4Closure ($sourceBindings.Count -eq 6) "source_binding_count"
$allBindings = @($validationManifest) + $sourceBindings
foreach ($bindingValue in $allBindings) {
    $binding = [hashtable]$bindingValue
    $relative = [string]$binding.path
    $absolute = Join-Path $repoRoot $relative
    Assert-R24D4Closure (
        Test-Path -LiteralPath $absolute -PathType Leaf
    ) "source_file_missing_$relative"
    $sourceBlob = (git -C $repoRoot rev-parse "$sourceCommit`:$relative").Trim()
    $headBlob = (git -C $repoRoot rev-parse "HEAD`:$relative").Trim()
    Assert-R24D4Closure (
        $sourceBlob -ceq [string]$binding.git_blob_oid -and
        $headBlob -ceq $sourceBlob -and
        (Get-R24D4ClosureSha256 $absolute) -ceq
            [string]$binding.raw_sha256 -and
        (Get-Item -LiteralPath $absolute).Length -eq
            [long]$binding.byte_length
    ) "source_binding_$relative"
}

$runtime = [hashtable]$closure.runtime
Assert-R24D4Closure (
    [string]$runtime.godot_source_repository -ceq
        "https://github.com/godotengine/godot.git" -and
    [string]$runtime.godot_source_commit -ceq
        "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88" -and
    [string]$runtime.console_binary_raw_sha256 -ceq
        "sha256:762ed7137d06284742b53abdde9b98c692ab1e8d3a184458db4d8e7a39782462" -and
    [long]$runtime.console_binary_byte_length -eq 293376 -and
    [string]$runtime.engine_binary_raw_sha256 -ceq
        "sha256:d0bb895b996fa98ec69a68b9f98ca6ed99af2eb18ef67a0b176ad1a55220278d" -and
    [long]$runtime.engine_binary_byte_length -eq 188826624 -and
    [string]$runtime.physics_engine -ceq "Jolt Physics" -and
    [int]$runtime.physics_ticks_per_second -eq 120 -and
    [int]$runtime.solver_velocity_steps -eq 20 -and
    [int]$runtime.solver_position_steps -eq 7 -and
    [string]$runtime.thread_model -ceq "single_safe"
) "runtime_identity"

$attempt = [hashtable]$closure.attempt
$runRoot = [IO.Path]::GetFullPath([string]$attempt.run_root)
$evidenceRoot = [IO.Path]::GetFullPath(
    (Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot)
).TrimEnd("\", "/")
$expectedAttemptBase = [IO.Path]::GetFullPath(
    (Join-Path $evidenceRoot "qsdk-r24d4-one-hinge-zero-world")
).TrimEnd("\", "/")
Assert-R24D4Closure (
    $runRoot.StartsWith(
        $expectedAttemptBase + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    (Split-Path -Leaf $runRoot) -ceq
        "20260816T123830Z-6e24a729-c5021de53c58" -and
    (Test-Path -LiteralPath $runRoot -PathType Container)
) "run_root"
Assert-R24D4Closure (
    [string]$attempt.requested_mode -ceq "ZeroWorld" -and
    [int]$attempt.static_audit_stage_count -eq 4 -and
    [int]$attempt.static_audit_stage_pass_count -eq 4 -and
    [bool]$attempt.worker_receipt_emitted -and
    -not [bool]$attempt.worker_receipt_ok -and
    [int]$attempt.worker_semantic_exit_code -eq 1 -and
    [bool]$attempt.supervised_termination_ready -and
    [int]$attempt.supervised_termination_requested_exit_code -eq 1 -and
    [int]$attempt.supervised_termination_drained_process_frame_count -eq 2 -and
    [string]$attempt.supervisor_terminal_error -ceq
        "worker_zero_world_preflight_failed:semantic=1:host=-1:protocol=" -and
    -not [bool]$attempt.terminal_receipt_written -and
    [int]$attempt.world_attempt_count -eq 0 -and
    [int]$attempt.world_build_count -eq 0 -and
    [int]$attempt.solver_step_count -eq 0 -and
    -not [bool]$attempt.physics_state_modified -and
    -not [bool]$attempt.physical_characterization_executed -and
    -not (Test-Path -LiteralPath (Join-Path $runRoot "receipt.json")) -and
    -not (Test-Path -LiteralPath (Join-Path $runRoot "attempt.json"))
) "attempt_boundary"

$retained = @($closure.retained_files)
Assert-R24D4Closure ($retained.Count -eq 11) "retained_file_count"
$liveFiles = @(Get-ChildItem -LiteralPath $runRoot -Recurse -File)
Assert-R24D4Closure ($liveFiles.Count -eq 11) "live_file_count"
foreach ($entryValue in $retained) {
    $entry = [hashtable]$entryValue
    $relative = [string]$entry.path
    $absolute = [IO.Path]::GetFullPath((Join-Path $runRoot $relative))
    Assert-R24D4Closure (
        $absolute.StartsWith(
            $runRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        (Test-Path -LiteralPath $absolute -PathType Leaf) -and
        (Get-R24D4ClosureSha256 $absolute) -ceq [string]$entry.raw_sha256 -and
        (Get-Item -LiteralPath $absolute).Length -eq [long]$entry.byte_length
    ) "retained_file_$relative"
    $digest = ([string]$entry.raw_sha256).Substring(7)
    Assert-R24D4Closure (
        Test-SporeSporeStoredArtifact `
            -Directory (Join-Path $evidenceRoot "artifacts\sha256\$digest") `
            -ExpectedSha256 $digest `
            -ExpectedByteLength ([long]$entry.byte_length)
    ) "retained_cas_$relative"
}

$expectedStages = @(
    @("01-r24d4_freeze_audit.log", "QSDK_R24D4_ONE_HINGE_TELEMETRY_FREEZE_PASS "),
    @("02-r24d3_source_audit.log", "QSDK_R24D3_GODOT_JOLT_MOTOR_TELEMETRY_SOURCE_PASS "),
    @("03-r24d3_cold_adoption_audit.log", "QSDK_R24D3_COLD_QUALIFICATION_ADOPTION_PASS "),
    @("04-r24d3_post_adoption_full_cold_audit.log", "QSDK_R24D3_POST_ADOPTION_FULL_COLD_CONFORMANCE_QUALIFICATION_PASS ")
)
foreach ($stage in $expectedStages) {
    [void](Get-R24D4ClosureMarker `
        -Lines @(Get-Content -LiteralPath (Join-Path $runRoot $stage[0])) `
        -Prefix $stage[1] `
        -Code $stage[0])
}

$stdoutLines = @(
    Get-Content -LiteralPath (
        Join-Path $runRoot "godot-zero_world_preflight-stdout.log"
    )
)
$worker = Get-R24D4ClosureMarker `
    -Lines $stdoutLines `
    -Prefix "QSDK_R24D4_WORKER_ZERO_WORLD " `
    -Code "worker" |
    ConvertFrom-Json -AsHashtable -Depth 100
$termination = Get-R24D4ClosureMarker `
    -Lines $stdoutLines `
    -Prefix "QSDK_R24D4_GODOT_SUPERVISOR_TERMINATION_READY " `
    -Code "termination" |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D4Closure (
    -not [bool]$worker.ok -and
    [string]$worker.schema_version -ceq
        "sporespore_qsdk_r24d4_godot_jolt_one_hinge_worker_preflight_v1" -and
    [string]$worker.fixture_id -ceq
        "QSDK.R24D4.godot_jolt_one_hinge_telemetry.v1" -and
    [int]$worker.cell_count -eq 9 -and
    [bool]$worker.telemetry_class_registered -and
    [bool]$worker.telemetry_method_registered -and
    [bool]$worker.invalid_rid_refused -and
    [int]$worker.world_attempt_count -eq 0 -and
    [int]$worker.world_build_count -eq 0 -and
    [int]$worker.solver_step_count -eq 0 -and
    -not [bool]$worker.physical_acceptance_authority -and
    -not [bool]$worker.release_authority -and
    [string]$worker.engine.physics_engine -ceq "Jolt Physics" -and
    [int]$worker.engine.physics_ticks_per_second -eq 120 -and
    [int]$worker.engine.solver_velocity_steps -eq 20 -and
    [int]$worker.engine.solver_position_steps -eq 7 -and
    [string]$worker.engine.thread_model -ceq "single_safe"
) "worker_observation"
Assert-R24D4Closure (
    [string]$termination.schema_version -ceq
        "sporespore_godot_supervised_termination_ready_v1" -and
    [string]$termination.termination_protocol_id -ceq
        "godot_4_7_gdscript_shutdown_containment_v1" -and
    [int]$termination.requested_exit_code -eq 1 -and
    [int]$termination.drained_process_frame_count -eq 2 -and
    [bool]$termination.worker_receipt_emitted -and
    [string]$termination.worker_receipt_kind -ceq "zero_world_preflight" -and
    -not [bool]$termination.physics_evidence_authority
) "termination_observation"

$diagnosis = [hashtable]$closure.diagnosis
$preregistration = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot $sourceBindings[0].path
) | ConvertFrom-Json -AsHashtable -Depth 100
$rigText = Get-Content -Raw -LiteralPath (Join-Path $repoRoot $sourceBindings[2].path)
$evaluatorText = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot $sourceBindings[1].path
)
$workerText = Get-Content -Raw -LiteralPath (Join-Path $repoRoot $sourceBindings[3].path)
Assert-R24D4Closure (
    (@($preregistration.fixture_freeze.hinge_axis_parent_local) -join ",") -ceq
        "0,0,1" -and
    $rigText.Contains(
        "const CANONICAL_AXIS_PARENT_LOCAL := Vector3.BACK",
        [StringComparison]::Ordinal
    ) -and
    $evaluatorText.Contains(
        '== [0.0, 0.0, -1.0],',
        [StringComparison]::Ordinal
    ) -and
    $workerText.Contains(
        'and axis == [0.0, 0.0, -1.0]',
        [StringComparison]::Ordinal
    ) -and
    (@($diagnosis.pre_registered_hinge_axis_parent_local) -join ",") -ceq
        "0,0,1" -and
    (@($diagnosis.frozen_evaluator_expected_hinge_axis_parent_local) -join ",") -ceq
        "0,0,-1" -and
    (@($diagnosis.frozen_worker_preflight_expected_hinge_axis_parent_local) -join ",") -ceq
        "0,0,-1" -and
    (@($diagnosis.frozen_rig_realized_hinge_axis_parent_local) -join ",") -ceq
        "0,0,1" -and
    [bool]$diagnosis.failure_occurred_before_world_construction -and
    [bool]$diagnosis.r24d4_source_or_evaluator_repair_forbidden -and
    [bool]$diagnosis.distinct_prospectively_frozen_successor_required
) "axis_diagnosis"

$godotRoot = [IO.Path]::GetFullPath($GodotSourceRoot)
$godotVectorPath = Join-Path $godotRoot "core/math/vector3.h"
Assert-R24D4Closure (
    (git -C $godotRoot rev-parse HEAD).Trim() -ceq
        [string]$runtime.godot_source_commit -and
    (git -C $godotRoot remote get-url origin).Trim() -ceq
        [string]$runtime.godot_source_repository -and
    (git -C $godotRoot rev-parse "HEAD:core/math/vector3.h").Trim() -ceq
        [string]$diagnosis.pinned_godot_constant.git_blob_oid -and
    (Get-R24D4ClosureSha256 $godotVectorPath) -ceq
        [string]$diagnosis.pinned_godot_constant.raw_sha256 -and
    (Get-Item -LiteralPath $godotVectorPath).Length -eq
        [long]$diagnosis.pinned_godot_constant.byte_length -and
    (Get-Content -LiteralPath $godotVectorPath)[234] -ceq
        [string]$diagnosis.pinned_godot_constant.line
) "pinned_godot_axis_constant"

$immutability = [hashtable]$closure.immutability
$claims = [hashtable]$closure.claims
Assert-R24D4Closure (
    [bool]$immutability.same_source_zero_world_result_rewrite_forbidden -and
    [bool]$immutability.same_source_physical_open_forbidden -and
    [bool]$immutability.r24d4_evaluator_repair_forbidden -and
    [bool]$immutability.r24d4_worker_oracle_repair_forbidden -and
    [bool]$immutability.retained_file_deletion_or_replacement_forbidden -and
    [bool]$immutability.all_r24d4_claims_remain_false -and
    -not [bool]$claims.complete_zero_world_gate_passed -and
    -not [bool]$claims.physical_characterization_executed -and
    -not [bool]$claims.instrumented_profile_promoted -and
    -not [bool]$claims.recovery_world_opened -and
    -not [bool]$claims.prone_to_standing_world_opened -and
    -not [bool]$claims.physical_acceptance_authority -and
    -not [bool]$claims.release_authority
) "immutability_and_claims"

Write-Output (
    "QSDK_R24D4_ZERO_WORLD_FAILURE_CLOSURE_PASS " +
    ([ordered]@{
        ok = $true
        closure_id = "QSDK-R24D4-ZW1-CLOSURE"
        status = "valid_zero_world_negative_source_oracle_axis_mismatch"
        source_commit = $sourceCommit
        static_audit_stage_count = 4
        retained_file_count = $retained.Count
        retained_cas_count = $retained.Count
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        physical_characterization_executed = $false
        same_source_physical_open_forbidden = $true
        distinct_successor_required = $true
        physical_acceptance_authority = $false
        release_authority = $false
    } | ConvertTo-Json -Compress)
)

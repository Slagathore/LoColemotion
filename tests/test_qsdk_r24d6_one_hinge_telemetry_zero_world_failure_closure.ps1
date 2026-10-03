#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$closureRelative = (
    "sdk/recovery/r24d6_godot_jolt_one_hinge_telemetry_" +
    "zero_world_failure_closure_v1.json"
)
$closurePath = Join-Path $repoRoot $closureRelative
$artifactStorePath = Join-Path $repoRoot "sdk/content_addressed_artifact_store.ps1"
. $artifactStorePath

function Assert-R24D6Closure {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Code
    )
    if (-not $Condition) {
        throw "QSDK-R24D6 zero-world failure closure: $Code"
    }
}

function Get-R24D6ClosureSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R24D6ClosureMarker {
    param(
        [AllowEmptyString()][Parameter(Mandatory)][string[]]$Lines,
        [Parameter(Mandatory)][string]$Prefix,
        [Parameter(Mandatory)][string]$Code
    )
    $matches = @($Lines | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R24D6Closure ($matches.Count -eq 1) "${Code}_marker_count"
    return ([string]$matches[0]).Substring($Prefix.Length)
}

function Test-R24D6IntegerValue {
    param([AllowNull()][object]$Value)
    return (
        $Value -is [sbyte] -or
        $Value -is [byte] -or
        $Value -is [int16] -or
        $Value -is [uint16] -or
        $Value -is [int32] -or
        $Value -is [uint32] -or
        $Value -is [int64] -or
        $Value -is [uint64]
    )
}

function Add-R24D6IntegerToDoubleProjection {
    param(
        [AllowNull()][object]$Template,
        [AllowNull()][object]$Envelope,
        [Parameter(Mandatory)][string]$Path
    )
    if ($Template -is [System.Collections.IDictionary]) {
        Assert-R24D6Closure (
            $Envelope -is [System.Collections.IDictionary]
        ) "projection_envelope_dictionary_$Path"
        foreach ($key in $Template.Keys) {
            Assert-R24D6Closure ($Envelope.Contains($key)) (
                "projection_envelope_key_${Path}_$key"
            )
            Add-R24D6IntegerToDoubleProjection `
                -Template $Template[$key] `
                -Envelope $Envelope[$key] `
                -Path "$Path.$key"
        }
        return
    }
    if ($Template -is [System.Collections.IList] -and
        $Template -isnot [string]) {
        Assert-R24D6Closure (
            $Envelope -is [System.Collections.IList] -and
            $Envelope -isnot [string] -and
            $Envelope.Count -eq $Template.Count
        ) "projection_envelope_array_$Path"
        for ($index = 0; $index -lt $Template.Count; $index += 1) {
            Add-R24D6IntegerToDoubleProjection `
                -Template $Template[$index] `
                -Envelope $Envelope[$index] `
                -Path "$Path[$index]"
        }
        return
    }
    if ((Test-R24D6IntegerValue $Template) -and $Envelope -is [double]) {
        $script:r24d6ProjectionResults.Add([ordered]@{
            path = $Path
            normalized_path = ($Path -replace '\[\d+\]', '[]')
            template_value = $Template
            envelope_value = $Envelope
        })
    }
}

function Assert-R24D6ClosureContract {
    param([Parameter(Mandatory)][hashtable]$Value)
    $attempt = [hashtable]$Value.attempt
    $diagnosis = [hashtable]$Value.diagnosis
    $immutability = [hashtable]$Value.immutability
    $claims = [hashtable]$Value.claims
    Assert-R24D6Closure (
        [string]$Value.schema_version -ceq
            "sporespore_qsdk_r24d6_one_hinge_telemetry_zero_world_failure_closure_v1" -and
        [string]$Value.closure_id -ceq "QSDK-R24D6-ZW2-CLOSURE" -and
        [string]$Value.gate_id -ceq "QSDK-R24D6" -and
        [string]$Value.question_class -ceq "non_physical_source_conformance" -and
        [string]$Value.status -ceq
            "valid_zero_world_negative_full_precision_integral_variant_type_loss" -and
        [string]$Value.source.commit -ceq
            "55032839756cc8a9089a2a4eb4e06db71ab99ca4" -and
        [int]$Value.source_binding_count -eq 11 -and
        [int]$Value.retained_file_count -eq 18 -and
        [int]$attempt.static_audit_stage_pass_count -eq 5 -and
        [bool]$attempt.worker_receipt_ok -and
        [int]$attempt.serializer_call_count -eq 2 -and
        [string]$attempt.default_precision_evaluator_terminal_error -ceq
            "QSDK_R24D6_EVALUATION_ERROR fixture_inertia_representation" -and
        [string]$attempt.full_precision_evaluator_terminal_error -ceq
            "QSDK_R24D6_EVALUATION_ERROR fixture_collision_layer" -and
        [int]$attempt.world_attempt_count -eq 0 -and
        [int]$attempt.world_build_count -eq 0 -and
        [int]$attempt.solver_step_count -eq 0 -and
        [int]$diagnosis.integer_to_double_projection_count -eq 313 -and
        [string]$diagnosis.first_failing_evaluator_code -ceq
            "fixture_collision_layer" -and
        [bool]$immutability.same_source_zero_world_rerun_forbidden -and
        [bool]$immutability.same_source_physical_open_forbidden -and
        -not [bool]$claims.complete_zero_world_gate_passed -and
        -not [bool]$claims.physical_characterization_executed -and
        -not [bool]$claims.turning_claim_changed -and
        -not [bool]$claims.release_authority
    ) "contract"
}

function Copy-R24D6ClosureValue {
    param([Parameter(Mandatory)][hashtable]$Value)
    return ($Value | ConvertTo-Json -Depth 100 -Compress) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

Assert-R24D6Closure (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/")
) "repository_root"
Assert-R24D6Closure (
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository_remote"
Assert-R24D6Closure (
    Test-Path -LiteralPath $closurePath -PathType Leaf
) "closure_missing"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D6ClosureContract $closure

$source = [hashtable]$closure.source
$sourceCommit = [string]$source.commit
Assert-R24D6Closure (
    [string]$source.repository_root -ceq $repoRoot.Replace("\", "/") -and
    [string]$source.remote -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    [string]$source.branch -ceq "main" -and
    [bool]$source.clean_pushed_before_attempt -and
    [bool]$source.local_upstream_cached_live_equal_before_attempt -and
    [int]$source.worktree_count -eq 1
) "source_identity"
git -C $repoRoot cat-file -e "$sourceCommit^{commit}"
Assert-R24D6Closure ($LASTEXITCODE -eq 0) "source_commit_missing"

$validationManifest = [hashtable]$source.validation_manifest
$sourceBindings = @($closure.source_bindings)
Assert-R24D6Closure ($sourceBindings.Count -eq 11) "source_binding_count"
$manifestAtSource = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot ([string]$validationManifest.path)
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R24D6Closure (
    [int]$manifestAtSource.source_binding_count -eq 11 -and
    (@($manifestAtSource.bindings | ConvertTo-Json -Depth 100 -Compress) -join "") -ceq
        (@($sourceBindings | ConvertTo-Json -Depth 100 -Compress) -join "")
) "source_binding_manifest_identity"
$allBindings = @($validationManifest) + $sourceBindings
foreach ($bindingValue in $allBindings) {
    $binding = [hashtable]$bindingValue
    $relative = [string]$binding.path
    $absolute = Join-Path $repoRoot $relative
    Assert-R24D6Closure (
        Test-Path -LiteralPath $absolute -PathType Leaf
    ) "source_file_missing_$relative"
    $sourceBlob = (git -C $repoRoot rev-parse "$sourceCommit`:$relative").Trim()
    $headBlob = (git -C $repoRoot hash-object -- $absolute).Trim()
    Assert-R24D6Closure (
        $LASTEXITCODE -eq 0 -and
        $sourceBlob -ceq [string]$binding.git_blob_oid -and
        $headBlob -ceq $sourceBlob -and
        (Get-R24D6ClosureSha256 $absolute) -ceq
            [string]$binding.raw_sha256 -and
        (Get-Item -LiteralPath $absolute).Length -eq
            [long]$binding.byte_length
    ) "source_binding_$relative"
}

$runtime = [hashtable]$closure.runtime
foreach ($binaryName in @("console", "engine")) {
    $path = [string]$runtime["${binaryName}_binary_path"]
    Assert-R24D6Closure (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-R24D6ClosureSha256 $path) -ceq
            [string]$runtime["${binaryName}_binary_raw_sha256"] -and
        (Get-Item -LiteralPath $path).Length -eq
            [long]$runtime["${binaryName}_binary_byte_length"]
    ) "runtime_$binaryName"
}
Assert-R24D6Closure (
    [string]$runtime.profile_id -ceq
        "godot_4_7_jolt_sporespore_motor_telemetry_v1" -and
    [string]$runtime.godot_source_commit -ceq
        "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88" -and
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
$attemptBase = [IO.Path]::GetFullPath(
    (Join-Path $evidenceRoot "qsdk-r24d6-one-hinge-zero-world")
).TrimEnd("\", "/")
Assert-R24D6Closure (
    $runRoot.StartsWith(
        $attemptBase + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    (Split-Path -Leaf $runRoot) -ceq
        "20260816T160737Z-55032839-326d0f70c7c1" -and
    (Test-Path -LiteralPath $runRoot -PathType Container)
) "run_root"
Assert-R24D6Closure (
    [string]$attempt.requested_mode -ceq "ZeroWorld" -and
    [int]$attempt.supervisor_exit_code -eq 1 -and
    [int]$attempt.static_audit_stage_count -eq 5 -and
    [int]$attempt.static_audit_stage_pass_count -eq 5 -and
    [int]$attempt.synthetic_template_emission_count -eq 1 -and
    [int]$attempt.worker_launch_count -eq 1 -and
    [int]$attempt.godot_process_launch_count -eq 1 -and
    [bool]$attempt.worker_receipt_emitted -and
    [bool]$attempt.worker_receipt_ok -and
    [int]$attempt.worker_semantic_exit_code -eq 0 -and
    [bool]$attempt.supervised_termination_ready -and
    [int]$attempt.supervised_termination_requested_exit_code -eq 0 -and
    [int]$attempt.supervised_termination_drained_process_frame_count -eq 2 -and
    [int]$attempt.serializer_call_count -eq 2 -and
    [int]$attempt.real_evaluator_envelope_invocation_count -eq 2 -and
    [int]$attempt.expected_evaluator_negative_count -eq 1 -and
    [int]$attempt.unexpected_evaluator_negative_count -eq 1 -and
    [int]$attempt.evaluator_success_count -eq 0 -and
    -not [bool]$attempt.terminal_receipt_written -and
    -not [bool]$attempt.full_precision_evaluation_record_written -and
    -not [bool]$attempt.physics_state_modified -and
    -not [bool]$attempt.physical_characterization_executed -and
    -not (Test-Path -LiteralPath (Join-Path $runRoot "receipt.json")) -and
    -not (Test-Path -LiteralPath (
        Join-Path $runRoot "zero-world-full-precision-evaluation.json"
    ))
) "attempt_boundary"

$retained = @($closure.retained_files)
$liveFiles = @(Get-ChildItem -LiteralPath $runRoot -Recurse -File)
Assert-R24D6Closure (
    $retained.Count -eq 18 -and
    [int]$closure.retained_file_count -eq 18 -and
    $liveFiles.Count -eq 18 -and
    [int]$closure.retained_unique_digest_count -eq 17 -and
    @($retained.raw_sha256 | Sort-Object -Unique).Count -eq 17
) "retained_counts"
foreach ($entryValue in $retained) {
    $entry = [hashtable]$entryValue
    $relative = [string]$entry.path
    $absolute = [IO.Path]::GetFullPath((Join-Path $runRoot $relative))
    Assert-R24D6Closure (
        $absolute.StartsWith(
            $runRoot.TrimEnd("\", "/") +
                [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        (Test-Path -LiteralPath $absolute -PathType Leaf) -and
        (Get-R24D6ClosureSha256 $absolute) -ceq
            [string]$entry.raw_sha256 -and
        (Get-Item -LiteralPath $absolute).Length -eq
            [long]$entry.byte_length
    ) "retained_file_$relative"
    $digest = ([string]$entry.raw_sha256).Substring(7)
    Assert-R24D6Closure (
        Test-SporeSporeStoredArtifact `
            -Directory (Join-Path $evidenceRoot "artifacts\sha256\$digest") `
            -ExpectedSha256 $digest `
            -ExpectedByteLength ([long]$entry.byte_length)
    ) "retained_cas_$relative"
}

$expectedStages = @(
    @("01-r24d5_physical_failure_closure.log", "QSDK_R24D5_PHYSICAL_FAILURE_CLOSURE_PASS "),
    @("02-r24d6_freeze_audit.log", "QSDK_R24D6_ONE_HINGE_TELEMETRY_FREEZE_PASS "),
    @("03-r24d3_source_audit.log", "QSDK_R24D3_GODOT_JOLT_MOTOR_TELEMETRY_SOURCE_PASS "),
    @("04-r24d3_cold_adoption_audit.log", "QSDK_R24D3_COLD_QUALIFICATION_ADOPTION_PASS "),
    @("05-r24d3_post_adoption_full_cold_audit.log", "QSDK_R24D3_POST_ADOPTION_FULL_COLD_CONFORMANCE_QUALIFICATION_PASS "),
    @("06-zero-world-template.log", "QSDK_R24D6_ZERO_WORLD_TEMPLATE ")
)
foreach ($stage in $expectedStages) {
    [void](Get-R24D6ClosureMarker `
        -Lines @(Get-Content -LiteralPath (Join-Path $runRoot $stage[0])) `
        -Prefix $stage[1] `
        -Code $stage[0])
}

$defaultLog = @(Get-Content -LiteralPath (
    Join-Path $runRoot "07-default-precision-negative-control.log"
))
$fullLog = @(Get-Content -LiteralPath (
    Join-Path $runRoot "08-full-precision-evaluator.log"
))
Assert-R24D6Closure (
    @($defaultLog | Where-Object {
        [string]$_ -ceq
            "QSDK_R24D6_EVALUATION_ERROR fixture_inertia_representation"
    }).Count -eq 1 -and
    @($fullLog | Where-Object {
        [string]$_ -ceq
            "QSDK_R24D6_EVALUATION_ERROR fixture_collision_layer"
    }).Count -eq 1
) "evaluator_terminal_errors"

$stdoutLines = @(Get-Content -LiteralPath (
    Join-Path $runRoot "godot-zero_world_preflight-stdout.log"
))
$worker = Get-R24D6ClosureMarker `
    -Lines $stdoutLines `
    -Prefix "QSDK_R24D6_WORKER_ZERO_WORLD " `
    -Code "worker" |
    ConvertFrom-Json -AsHashtable -Depth 100
$termination = Get-R24D6ClosureMarker `
    -Lines $stdoutLines `
    -Prefix "QSDK_R24D6_GODOT_SUPERVISOR_TERMINATION_READY " `
    -Code "termination" |
    ConvertFrom-Json -AsHashtable -Depth 100
$defaultEnvelopeText = Get-R24D6ClosureMarker `
    -Lines $stdoutLines `
    -Prefix "QSDK_R24D6_ZERO_WORLD_DEFAULT_PRECISION_ENVELOPE " `
    -Code "default_envelope"
$fullEnvelopeText = Get-R24D6ClosureMarker `
    -Lines $stdoutLines `
    -Prefix "QSDK_R24D6_ZERO_WORLD_FULL_PRECISION_ENVELOPE " `
    -Code "full_envelope"
$defaultEnvelopePath = Join-Path $runRoot (
    [string]$closure.serialized_envelope_observation.default_precision.relative_path
)
$fullEnvelopePath = Join-Path $runRoot (
    [string]$closure.serialized_envelope_observation.full_precision.relative_path
)
Assert-R24D6Closure (
    [IO.File]::ReadAllText($defaultEnvelopePath) -ceq $defaultEnvelopeText -and
    [IO.File]::ReadAllText($fullEnvelopePath) -ceq $fullEnvelopeText
) "envelope_stdout_binding"
$serialized = [hashtable]$worker.serialized_envelope
Assert-R24D6Closure (
    [bool]$worker.ok -and
    [string]$worker.source_commit -ceq $sourceCommit -and
    [int]$worker.active_physics_object_count -eq 0 -and
    [bool]$worker.active_physics_object_count_is_zero -and
    [int]$worker.world_attempt_count -eq 0 -and
    [int]$worker.world_build_count -eq 0 -and
    [int]$worker.solver_step_count -eq 0 -and
    [int]$serialized.serializer_call_count -eq 2 -and
    [string]$serialized.default_precision_raw_sha256 -ceq
        [string]$closure.serialized_envelope_observation.default_precision.raw_sha256 -and
    [string]$serialized.full_precision_raw_sha256 -ceq
        [string]$closure.serialized_envelope_observation.full_precision.raw_sha256 -and
    [string]$termination.termination_nonce -ceq
        [string]$worker.execution_nonce -and
    [int]$termination.requested_exit_code -eq 0 -and
    [int]$termination.drained_process_frame_count -eq 2 -and
    [bool]$termination.worker_receipt_emitted
) "worker_and_termination"

$templatePath = Join-Path $runRoot (
    [string]$closure.serialized_envelope_observation.template.relative_path
)
$templateDocument = Get-Content -Raw -LiteralPath $templatePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$defaultDocument = Get-Content -Raw -LiteralPath $defaultEnvelopePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$fullDocument = Get-Content -Raw -LiteralPath $fullEnvelopePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$script:r24d6ProjectionResults = [System.Collections.Generic.List[object]]::new()
Add-R24D6IntegerToDoubleProjection `
    -Template $templateDocument `
    -Envelope $fullDocument `
    -Path '$'
$projections = $script:r24d6ProjectionResults
$groups = @(
    $projections |
        Group-Object { [string]$_.normalized_path } |
        Sort-Object Name
)
$declaredFamilies = @(
    $closure.diagnosis.integer_to_double_projection_families |
        Sort-Object path
)
Assert-R24D6Closure (
    $projections.Count -eq 313 -and
    $groups.Count -eq 21 -and
    $declaredFamilies.Count -eq 21
) (
    "projection_counts_observed_" +
    "$($projections.Count)_$($groups.Count)_$($declaredFamilies.Count)"
)
for ($index = 0; $index -lt $groups.Count; $index += 1) {
    Assert-R24D6Closure (
        [string]$groups[$index].Name -ceq
            [string]$declaredFamilies[$index].path -and
        [int]$groups[$index].Count -eq
            [int]$declaredFamilies[$index].count
    ) "projection_family_$index"
}
$strictFamilies = @($declaredFamilies | Where-Object { [bool]$_.strict_integer })
Assert-R24D6Closure (
    $strictFamilies.Count -eq 9 -and
    [int](($strictFamilies | Measure-Object -Property count -Sum).Sum) -eq 234 -and
    (Test-R24D6IntegerValue $templateDocument.fixture.collision_layer) -and
    $defaultDocument.fixture.collision_layer -is [double] -and
    $fullDocument.fixture.collision_layer -is [double] -and
    [int64]$templateDocument.fixture.collision_layer -eq 0 -and
    [double]$defaultDocument.fixture.collision_layer -eq 0.0 -and
    [double]$fullDocument.fixture.collision_layer -eq 0.0
) "projection_diagnosis"

$immutability = [hashtable]$closure.immutability
$claims = [hashtable]$closure.claims
Assert-R24D6Closure (
    [bool]$immutability.same_source_zero_world_result_rewrite_forbidden -and
    [bool]$immutability.same_source_zero_world_rerun_forbidden -and
    [bool]$immutability.same_source_physical_open_forbidden -and
    [bool]$immutability.r24d6_evaluator_repair_forbidden -and
    [bool]$immutability.r24d6_worker_repair_forbidden -and
    [bool]$immutability.r24d6_supervisor_repair_forbidden -and
    [bool]$closure.diagnosis.distinct_prospectively_frozen_successor_required -and
    [bool]$claims.default_precision_negative_control_passed -and
    -not [bool]$claims.full_precision_positive_control_passed -and
    -not [bool]$claims.official_zero_world_qualification_complete -and
    -not [bool]$claims.complete_zero_world_gate_passed -and
    -not [bool]$claims.native_telemetry_characterized -and
    -not [bool]$claims.instrumented_profile_promoted -and
    -not [bool]$claims.recovery_world_opened -and
    -not [bool]$claims.prone_to_standing_world_opened -and
    -not [bool]$claims.turning_claim_changed -and
    -not [bool]$claims.q_sdk_r24_satisfied -and
    -not [bool]$claims.physical_acceptance_authority -and
    -not [bool]$claims.release_authority
) "immutability_and_claims"

$mutations = @(
    @{ path = @("status"); value = "passed" },
    @{ path = @("source", "commit"); value = "0" * 40 },
    @{ path = @("source_binding_count"); value = 10 },
    @{ path = @("retained_file_count"); value = 17 },
    @{ path = @("attempt", "static_audit_stage_pass_count"); value = 4 },
    @{ path = @("attempt", "worker_receipt_ok"); value = $false },
    @{ path = @("attempt", "default_precision_evaluator_terminal_error"); value = "mutated" },
    @{ path = @("attempt", "full_precision_evaluator_terminal_error"); value = "mutated" },
    @{ path = @("attempt", "world_attempt_count"); value = 1 },
    @{ path = @("diagnosis", "integer_to_double_projection_count"); value = 312 },
    @{ path = @("diagnosis", "first_failing_evaluator_code"); value = "mutated" },
    @{ path = @("immutability", "same_source_zero_world_rerun_forbidden"); value = $false },
    @{ path = @("claims", "complete_zero_world_gate_passed"); value = $true },
    @{ path = @("claims", "release_authority"); value = $true }
)
$rejectedMutations = 0
foreach ($mutation in $mutations) {
    $candidate = Copy-R24D6ClosureValue $closure
    $target = $candidate
    for ($index = 0; $index -lt $mutation.path.Count - 1; $index += 1) {
        $target = [hashtable]$target[$mutation.path[$index]]
    }
    $target[$mutation.path[-1]] = $mutation.value
    try {
        Assert-R24D6ClosureContract $candidate
    } catch {
        $rejectedMutations += 1
        continue
    }
    throw "QSDK-R24D6 closure accepted mutation: $($mutation.path -join '.')"
}
Assert-R24D6Closure (
    $rejectedMutations -eq 14
) "closure_mutation_rejection_count"

$receipt = [ordered]@{
    ok = $true
    closure_id = "QSDK-R24D6-ZW2-CLOSURE"
    status = "valid_zero_world_negative_full_precision_integral_variant_type_loss"
    question_class = "non_physical_source_conformance"
    source_commit = $sourceCommit
    static_audit_stage_pass_count = 5
    serializer_call_count = 2
    default_precision_negative_control_passed = $true
    full_precision_positive_control_passed = $false
    integer_to_double_projection_count = 313
    strict_evaluator_integer_projection_count = 234
    retained_file_count = 18
    retained_unique_digest_count = 17
    world_attempt_count = 0
    world_build_count = 0
    solver_step_count = 0
    same_source_rerun_forbidden = $true
    distinct_successor_required = $true
    closure_mutation_rejection_count = 14
    turning_claim_changed = $false
    prone_to_standing_world_opened = $false
    physical_acceptance_authority = $false
    release_authority = $false
}
Write-Output (
    "QSDK_R24D6_ZERO_WORLD_FAILURE_CLOSURE_PASS " +
    ($receipt | ConvertTo-Json -Depth 20 -Compress)
)

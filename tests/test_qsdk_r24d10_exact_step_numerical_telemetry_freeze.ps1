#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Python = "python",
    [string]$GodotSourceRoot = (
        "C:\Users\Cole\CodeStuff\dependencies\godot-sporespore-4.7"
    ),
    [switch]$AllowProspectiveUncommitted
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$godotRoot = [IO.Path]::GetFullPath($GodotSourceRoot)
$expectedRepoRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$expectedGodotRoot = "C:\Users\Cole\CodeStuff\dependencies\godot-sporespore-4.7"
$expectedGodotRemote = "https://github.com/godotengine/godot.git"
$expectedGodotCommit = "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"
$expectedPatchHash = (
    "9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c"
)
$manifestRelative = (
    "sdk/recovery/" +
    "r24d10_godot_jolt_exact_step_numerical_telemetry_validation_manifest.json"
)
$supervisorRelative = (
    "sdk/run_qsdk_r24d10_exact_step_numerical_telemetry_zero_world_gate.ps1"
)
$workerRelative = (
    "tests/test_sdk_qsdk_r24d10_godot_jolt_exact_step_" +
    "numerical_telemetry_worker.gd"
)
$sourceAuditRelative = "tests/test_qsdk_r24d10_exact_step_source.py"
$expectedBindingPaths = @(
    ".gitattributes",
    "sdk/adapters/godot/engine_patches/godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch",
    "sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_physical_failure_closure_v1.json",
    "tests/test_qsdk_r24d9_one_hinge_numerical_telemetry_physical_failure_closure.ps1",
    "sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_characterization_preregistration_v1.json",
    "sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_characterization_evaluator.py",
    "scripts/lab/rigs/r24d9_godot_jolt_one_hinge_numerical_telemetry_rig.gd",
    "tests/test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_worker.gd",
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_characterization_preregistration_v1.json",
    "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_preregistration.py",
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_characterization_evaluator.py",
    "scripts/lab/rigs/r24d10_godot_jolt_exact_step_numerical_telemetry_rig.gd",
    "tests/test_sdk_qsdk_r24d10_godot_jolt_exact_step_numerical_telemetry_worker.gd",
    "tests/test_qsdk_r24d10_exact_step_source.py",
    "sdk/run_qsdk_r24d10_exact_step_numerical_telemetry_zero_world_gate.ps1",
    "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_freeze.ps1",
    "sdk/locomotion_operation_lock.ps1",
    "sdk/godot_receipt_terminated_process.ps1",
    "sdk/content_addressed_artifact_store.ps1"
)
$expectedPatchedPaths = @(
    "modules/jolt_physics/joints/jolt_hinge_joint_3d.cpp",
    "modules/jolt_physics/joints/jolt_hinge_joint_3d.h",
    "modules/jolt_physics/joints/jolt_joint_3d.h",
    "modules/jolt_physics/jolt_physics_server_3d.cpp",
    "modules/jolt_physics/jolt_physics_server_3d.h",
    "modules/jolt_physics/register_types.cpp",
    "modules/jolt_physics/spaces/jolt_space_3d.cpp",
    "modules/jolt_physics/spaces/jolt_space_3d.h",
    "thirdparty/jolt_physics/Jolt/Physics/Constraints/HingeConstraint.cpp",
    "thirdparty/jolt_physics/Jolt/Physics/Constraints/HingeConstraint.h"
)

function Assert-R24D10Freeze {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) { throw "QSDK-R24D10 freeze audit: $Code" }
}

function Get-R24D10Path {
    param([Parameter(Mandatory)][string]$Relative)
    return [IO.Path]::GetFullPath((Join-Path $repoRoot $Relative))
}

function Get-R24D10Git {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    $output = @(& git -C $Root @Arguments 2>&1)
    Assert-R24D10Freeze ($LASTEXITCODE -eq 0) (
        "git_$($Arguments -join '_'):$($output -join '|')"
    )
    return ($output -join "`n").Trim()
}

function Get-R24D10Sha256 {
    param([Parameter(Mandatory)][string]$Path)
    Assert-R24D10Freeze (Test-Path -LiteralPath $Path -PathType Leaf) (
        "missing:$Path"
    )
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).
        Hash.ToLowerInvariant()
}

function Test-R24D10SupervisorSemantics {
    param([Parameter(Mandatory)][string]$Text)
    $markers = @(
        'Enter-SporeSporeLocomotionOperationLock -Role "conformance"',
        '"ls-remote", "--heads", "origin", "refs/heads/main"',
        '"same_source_zero_world_attempt_already_consumed:',
        'status = "consumed_before_first_stage"',
        '@("-m", "SCons", "--clean") + $sconsArguments',
        '@("-m", "SCons") + $sconsArguments',
        '"--mode=zero_world_preflight"',
        '$workerReceipt.synthetic_first_retained_space_step_sequence',
        '$workerReceipt.synthetic_last_retained_space_step_sequence',
        '$workerReceipt.synthetic_pre_sample_physics_frame_count',
        '"complete_zero_world_gate_passed_physical_execution_still_forbidden_"',
        'physical_authorization = $false',
        'world_attempt_count = 0',
        'solver_step_count = 0',
        'QSDK_R24D10_EXACT_STEP_ZERO_WORLD_GATE'
    )
    foreach ($marker in $markers) {
        if (-not $Text.Contains($marker, [StringComparison]::Ordinal)) {
            return $false
        }
    }
    $ordered = @(
        'name = "immutable_r24d9_failure_closure_recheck"',
        'name = "r24d10_manifest_freeze_and_parser_audit"',
        '"R24D10 pinned Godot cold cleanup"',
        '"R24D10 pinned Godot cold build"',
        '"--emit-zero-world-template"',
        '$worker = Invoke-R24D10Worker',
        '"--expected-evidence-kind", "synthetic_zero_world"',
        'QSDK_R24D10_EXACT_STEP_ZERO_WORLD_GATE'
    )
    $offsets = @($ordered | ForEach-Object { $Text.IndexOf($_) })
    if (@($offsets | Where-Object { $_ -lt 0 }).Count -gt 0) { return $false }
    if (($offsets -join "|") -cne (($offsets | Sort-Object) -join "|")) {
        return $false
    }
    return (
        -not $Text.Contains("[switch]`$RunPhysical", [StringComparison]::Ordinal) -and
        -not $Text.Contains('"--mode=physical"', [StringComparison]::Ordinal)
    )
}

$root = Get-R24D10Git -Root $repoRoot -Arguments @(
    "rev-parse", "--show-toplevel"
)
$remote = Get-R24D10Git -Root $repoRoot -Arguments @(
    "remote", "get-url", "origin"
)
$head = Get-R24D10Git -Root $repoRoot -Arguments @("rev-parse", "HEAD")
Assert-R24D10Freeze (
    [IO.Path]::GetFullPath($root) -ceq $expectedRepoRoot -and
    $repoRoot -ceq $expectedRepoRoot
) "repository_root"
Assert-R24D10Freeze ($remote -ceq $expectedRemote) "repository_remote"
if (-not $AllowProspectiveUncommitted) {
    $status = Get-R24D10Git -Root $repoRoot -Arguments @("status", "--short")
    Assert-R24D10Freeze ([string]::IsNullOrEmpty($status)) "dirty_worktree"
}

Assert-R24D10Freeze ($godotRoot -ceq $expectedGodotRoot) "godot_root"
$godotRepo = Get-R24D10Git -Root $godotRoot -Arguments @(
    "rev-parse", "--show-toplevel"
)
$godotRemote = Get-R24D10Git -Root $godotRoot -Arguments @(
    "remote", "get-url", "origin"
)
$godotHead = Get-R24D10Git -Root $godotRoot -Arguments @("rev-parse", "HEAD")
Assert-R24D10Freeze ([IO.Path]::GetFullPath($godotRepo) -ceq $godotRoot) (
    "godot_repo_root"
)
Assert-R24D10Freeze ($godotRemote -ceq $expectedGodotRemote) "godot_remote"
Assert-R24D10Freeze ($godotHead -ceq $expectedGodotCommit) "godot_commit"
$godotStatus = @(& git -C $godotRoot status --short 2>&1)
Assert-R24D10Freeze ($LASTEXITCODE -eq 0) "godot_status"
$godotPaths = @($godotStatus | ForEach-Object {
    ([string]$_).Substring(3).Replace("\", "/")
})
Assert-R24D10Freeze (
    (($godotPaths | Sort-Object) -join "|") -ceq
    (($expectedPatchedPaths | Sort-Object) -join "|")
) "godot_patched_path_population"
$patchPath = Get-R24D10Path (
    "sdk/adapters/godot/engine_patches/" +
    "godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch"
)
Assert-R24D10Freeze ((Get-R24D10Sha256 $patchPath) -ceq $expectedPatchHash) (
    "patch_hash"
)
$diff = ((@(& git -C $godotRoot diff --no-ext-diff 2>&1) -join "`n") + "`n").
    Replace("`r`n", "`n")
Assert-R24D10Freeze ($LASTEXITCODE -eq 0) "godot_diff"
$patchText = [IO.File]::ReadAllText($patchPath).
    Replace("`r`n", "`n").TrimEnd("`n") + "`n"
Assert-R24D10Freeze ($diff -ceq $patchText) "godot_patch_identity"

$sourceAudit = @(& $Python (Get-R24D10Path $sourceAuditRelative) 2>&1)
Assert-R24D10Freeze ($LASTEXITCODE -eq 0) (
    "source_audit:$($sourceAudit -join '|')"
)
$sourceMarkers = @($sourceAudit | Where-Object {
    ([string]$_).StartsWith(
        "QSDK_R24D10_EXACT_STEP_SOURCE_AUDIT_PASS ",
        [StringComparison]::Ordinal
    )
})
Assert-R24D10Freeze (
    $sourceMarkers.Count -eq 1 -and
    ([string]$sourceMarkers[0]).Contains(
        "worlds=0 builds=0 solver_steps=0",
        [StringComparison]::Ordinal
    )
) "source_audit_receipt"

$supervisorPath = Get-R24D10Path $supervisorRelative
$supervisorText = [IO.File]::ReadAllText($supervisorPath).Replace("`r`n", "`n")
Assert-R24D10Freeze (Test-R24D10SupervisorSemantics $supervisorText) (
    "supervisor_semantics"
)
$parseErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile(
    $supervisorPath,
    [ref]$null,
    [ref]$parseErrors
)
Assert-R24D10Freeze ($parseErrors.Count -eq 0) (
    "supervisor_parse:$($parseErrors -join '|')"
)

$mutationMarkers = @(
    'Enter-SporeSporeLocomotionOperationLock -Role "conformance"',
    '"same_source_zero_world_attempt_already_consumed:',
    '@("-m", "SCons", "--clean") + $sconsArguments',
    '"--mode=zero_world_preflight"',
    '$workerReceipt.synthetic_first_retained_space_step_sequence',
    '$workerReceipt.synthetic_pre_sample_physics_frame_count',
    '"complete_zero_world_gate_passed_physical_execution_still_forbidden_"',
    'QSDK_R24D10_EXACT_STEP_ZERO_WORLD_GATE'
)
$rejectedMutations = 0
foreach ($marker in $mutationMarkers) {
    Assert-R24D10Freeze (
        ([regex]::Matches($supervisorText, [regex]::Escape($marker))).Count -ge 1
    ) "mutation_marker:$marker"
    $mutated = $supervisorText.Replace($marker, "R24D10_MUTATED_MARKER")
    if (-not (Test-R24D10SupervisorSemantics $mutated)) {
        $rejectedMutations += 1
    }
}
Assert-R24D10Freeze ($rejectedMutations -eq $mutationMarkers.Count) (
    "supervisor_mutation_controls"
)

$consolePath = Join-Path $godotRoot (
    "bin\godot.windows.editor.dev.x86_64.console.exe"
)
Assert-R24D10Freeze (Test-Path -LiteralPath $consolePath -PathType Leaf) (
    "current_custom_console_missing"
)
$parserOutput = @(
    & $consolePath `
        --headless `
        --path $repoRoot `
        --check-only `
        --script ("res://" + $workerRelative) 2>&1
)
Assert-R24D10Freeze ($LASTEXITCODE -eq 0) (
    "gdscript_parser:$($parserOutput -join '|')"
)
$parserErrors = @($parserOutput | Where-Object {
    [string]$_ -match "(^|\s)(SCRIPT ERROR|ERROR):"
})
Assert-R24D10Freeze ($parserErrors.Count -eq 0) (
    "gdscript_parser_errors:$($parserErrors -join '|')"
)

$manifestPath = Get-R24D10Path $manifestRelative
$manifest = Get-Content -Raw -LiteralPath $manifestPath |
    ConvertFrom-Json -Depth 100
$bindings = @($manifest.source_bindings)
Assert-R24D10Freeze (
    [string]$manifest.schema_version -ceq
        "sporespore_qsdk_r24d10_exact_step_numerical_telemetry_validation_manifest_v1" -and
    [string]$manifest.gate_id -ceq "QSDK-R24D10" -and
    [string]$manifest.question_class -ceq "development" -and
    [string]$manifest.status -ceq
        "prospective_exact_step_implementation_source_bytes_bound_zero_world_pending" -and
    [string]$manifest.godot_source_commit -ceq $expectedGodotCommit -and
    [string]$manifest.combined_patch_raw_sha256 -ceq "sha256:$expectedPatchHash" -and
    [int]$manifest.inherited_evaluator_negative_control_count -eq 46 -and
    [int]$manifest.new_exact_step_negative_control_count -eq 12 -and
    [int]$manifest.accepted_adverse_finite_outcome_count -eq 3 -and
    [int]$manifest.source_binding_count -eq $expectedBindingPaths.Count -and
    $bindings.Count -eq $expectedBindingPaths.Count -and
    -not [bool]$manifest.includes_self -and
    [int]$manifest.official_zero_world_qualification_count -eq 0 -and
    [int]$manifest.world_attempt_count -eq 0 -and
    [int]$manifest.world_build_count -eq 0 -and
    [int]$manifest.solver_step_count -eq 0 -and
    [bool]$manifest.prospective_development_question_declared -and
    [bool]$manifest.exact_step_schedule_source_implemented -and
    [bool]$manifest.complete_zero_world_gate_source_implemented -and
    -not [bool]$manifest.complete_zero_world_gate_passed -and
    -not [bool]$manifest.physical_authorization -and
    -not [bool]$manifest.physical_characterization_executed -and
    -not [bool]$manifest.native_numerical_telemetry_characterized -and
    -not [bool]$manifest.numerical_accuracy_accepted -and
    -not [bool]$manifest.instrumented_profile_promoted -and
    -not [bool]$manifest.stock_godot_profile_promoted -and
    -not [bool]$manifest.recovery_world_opened -and
    -not [bool]$manifest.prone_to_standing_world_opened -and
    -not [bool]$manifest.turning_claim_changed -and
    -not [bool]$manifest.cross_engine_equivalence_claimed -and
    -not [bool]$manifest.q_sdk_r24_satisfied -and
    -not [bool]$manifest.physical_acceptance_authority -and
    -not [bool]$manifest.release_authority
) "manifest_header"
Assert-R24D10Freeze (
    ((@($bindings | ForEach-Object { [string]$_.path })) -join "|") -ceq
    ($expectedBindingPaths -join "|")
) "manifest_path_order"
foreach ($binding in $bindings) {
    $relative = [string]$binding.path
    $path = Get-R24D10Path $relative
    $item = Get-Item -LiteralPath $path
    $digest = Get-R24D10Sha256 $path
    $workingBlob = Get-R24D10Git -Root $repoRoot -Arguments @(
        "hash-object", $relative
    )
    Assert-R24D10Freeze (
        [string]$binding.raw_sha256 -ceq "sha256:$digest" -and
        [long]$binding.byte_length -eq [long]$item.Length -and
        [string]$binding.git_blob_oid -ceq $workingBlob
    ) "manifest_binding:$relative"
    if (-not $AllowProspectiveUncommitted) {
        $committedBlob = Get-R24D10Git -Root $repoRoot -Arguments @(
            "rev-parse", "$head`:$relative"
        )
        Assert-R24D10Freeze ($committedBlob -ceq $workingBlob) (
            "manifest_committed_binding:$relative"
        )
    }
}

Write-Output (
    "QSDK_R24D10_EXACT_STEP_FREEZE_AUDIT_PASS " +
    ([ordered]@{
        ok = $true
        gate_id = "QSDK-R24D10"
        question_class = "development"
        source_binding_count = $bindings.Count
        supervisor_mutation_count = $rejectedMutations
        inherited_evaluator_negative_control_count = 46
        new_exact_step_negative_control_count = 12
        accepted_adverse_finite_outcome_count = 3
        gdscript_parse_passed = $true
        official_zero_world_qualification_count = 0
        world_attempt_count = 0
        world_build_count = 0
        solver_step_count = 0
        physical_authorization = $false
        physical_acceptance_authority = $false
        release_authority = $false
    } | ConvertTo-Json -Depth 20 -Compress)
)

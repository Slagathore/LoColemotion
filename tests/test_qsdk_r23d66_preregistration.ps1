#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$declarationPath = Join-Path $repoRoot (
    "sdk\turning\r23d66_production_route_three_engine_turning_validation_" +
    "preregistration_v1.json"
)
$designPath = Join-Path $repoRoot (
    "sdk\turning\r23d66_production_route_three_engine_turning_validation.py"
)
$seedCompilerPath = Join-Path $repoRoot "sdk\turning\r23d66_seed_fixture_compiler.gd"
$implementationPath = Join-Path $repoRoot (
    "sdk\turning\r23d66_production_route_three_engine_turning_" +
    "implementation_v1.json"
)
$materializerPath = Join-Path $repoRoot (
    "sdk\turning\materialize_r23d66_implementation.py"
)
$zeroWorldRunnerPath = Join-Path $repoRoot "sdk\run_qsdk_r23d66_zero_world.ps1"
$zeroWorldAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d66_zero_world.ps1"
$evaluatorPath = Join-Path $repoRoot (
    "sdk\turning\r23d66_production_route_three_engine_turning_evaluator.py"
)
$campaignManifestPath = Join-Path $repoRoot (
    "sdk\turning\r23d66_campaign_attestation_manifest_v1.json"
)
$campaignManifestMaterializerPath = Join-Path $repoRoot (
    "sdk\turning\materialize_r23d66_campaign_attestation_manifest.py"
)
$campaignRoleAuditPath = Join-Path $repoRoot (
    "tests\test_qsdk_r23d66_campaign_roles.ps1"
)
$physicalSupervisorPath = Join-Path $repoRoot "sdk\run_qsdk_r23d66_supervisor.ps1"
$predecessorAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d65_physical_closure.ps1"
$routeAuditPath = Join-Path $repoRoot (
    "tests\test_three_engine_turning_production_route_development_closure.ps1"
)
$releaseContractPath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportMatrixPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$parentCommit = "e2fc35e8c247f7706ca8f41d58acb21843d5ae3f"
$parentTree = "ca2f63c3073c1ad2e7872b1b6fd138f497fdb37d"
$seed = 23179

function Assert-R23D66Declaration([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "QSDK-R23D66 DECLARATION: $Message"
    }
}

function Get-R23D66Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Invoke-R23D66Git([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-R23D66Declaration ($LASTEXITCODE -eq 0) (
        "git $($Arguments -join ' ') failed: $($lines -join ' ')"
    )
    return ($lines -join "`n").Trim()
}

Assert-R23D66Declaration (
    (Invoke-R23D66Git @("rev-parse", "--show-toplevel")) -ceq
        $repoRoot.Replace("\", "/") -and
    (Invoke-R23D66Git @("remote", "get-url", "origin")) -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @(
    $declarationPath,
    $designPath,
    $seedCompilerPath,
    $implementationPath,
    $materializerPath,
    $zeroWorldRunnerPath,
    $zeroWorldAuditPath,
    $evaluatorPath,
    $campaignManifestPath,
    $campaignManifestMaterializerPath,
    $campaignRoleAuditPath,
    $physicalSupervisorPath,
    $predecessorAuditPath,
    $routeAuditPath,
    $releaseContractPath,
    $supportMatrixPath
)) {
    Assert-R23D66Declaration (Test-Path -LiteralPath $path -PathType Leaf) (
        "path is missing: $path"
    )
}

$declaration = Get-Content -LiteralPath $declarationPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D66Declaration (
    [string]$declaration.schema_version -ceq
        "sporespore_qsdk_r23d66_production_route_three_engine_turning_validation_preregistration_v1" -and
    [string]$declaration.status -ceq
        "prospective_declaration_complete_physical_not_authorized" -and
    [string]$declaration.gate_id -ceq "QSDK-R23D66" -and
    [string]$declaration.release_gate_id -ceq "QSDK-R23" -and
    [string]$declaration.physical_question_class -ceq "finite_decision" -and
    [string]$declaration.ledger_scope.subsystem -ceq "turning" -and
    [string]$declaration.ledger_scope.engine_scope -ceq "3e" -and
    [string]$declaration.ledger_scope.authority_mode -ceq "held_out_prospective" -and
    [string]$declaration.ledger_scope.question_class -ceq "finite_decision" -and
    [bool]$declaration.physical_question_declared -and
    -not [bool]$declaration.physical_campaign_opened
) "question identity changed"
Assert-R23D66Declaration (
    [string]$declaration.declaration_parent.commit -ceq $parentCommit -and
    [string]$declaration.declaration_parent.tree_git_oid -ceq $parentTree -and
    (Invoke-R23D66Git @("rev-parse", "$parentCommit^{tree}")) -ceq $parentTree
) "declaration parent changed"

$seedPattern = "(^|[^0-9A-Za-z])23179([^0-9A-Za-z]|$)|23_179"
$seedOccurrences = @(
    & git -C $repoRoot grep -n -E $seedPattern $parentCommit -- . 2>$null
)
$seedGrepExit = $LASTEXITCODE
Assert-R23D66Declaration (
    $seedGrepExit -eq 1 -and
    $seedOccurrences.Count -eq 0 -and
    [int]$declaration.scientific_distinction_and_change_budget.fresh_seed -eq $seed -and
    [int]$declaration.scientific_distinction_and_change_budget.fresh_seed_identity_occurrence_count_at_declaration_parent -eq 0
) "fresh seed identity was not absent at the declaration parent"

$bindings = $declaration.lineage_bindings
foreach ($relative in @($bindings.Keys)) {
    $path = Join-Path $repoRoot ([string]$relative).Replace("/", "\")
    Assert-R23D66Declaration (
        (Get-R23D66Sha256 $path) -ceq [string]$bindings[$relative]
    ) "lineage binding changed: $relative"
}
Assert-R23D66Declaration (
    (Get-R23D66Sha256 $seedCompilerPath) -ceq
        [string]$declaration.seed_fixture_compilation.compiler_raw_sha256
) "seed compiler digest changed"

$python = (Get-Command python -ErrorAction Stop).Source
$designOutput = @(& $python $designPath --declaration $declarationPath 2>&1)
Assert-R23D66Declaration ($LASTEXITCODE -eq 0) (
    "declaration validator failed: $($designOutput -join ' ')"
)
$designMarkers = @($designOutput | Where-Object {
    ([string]$_).StartsWith("QSDK_R23D66_DECLARATION_PASS ")
})
Assert-R23D66Declaration ($designMarkers.Count -eq 1) (
    "declaration validator marker changed"
)
$designReceipt = ([string]$designMarkers[0]).Substring(
    "QSDK_R23D66_DECLARATION_PASS ".Length
) | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D66Declaration (
    [string]$designReceipt.question_class -ceq "finite_decision" -and
    [int]$designReceipt.reserved_seed -eq $seed -and
    [int]$designReceipt.cell_count -eq 9 -and
    [int]$designReceipt.schedule_segment_counts.reference_warmup -eq 600 -and
    [int]$designReceipt.schedule_segment_counts.commanded_turn -eq 1200 -and
    [int]$designReceipt.schedule_segment_counts.reference_recovery -eq 600 -and
    [int]$designReceipt.schedule_segment_counts.reference_continuation -eq 592 -and
    [int]$designReceipt.mutation_rejection_count -eq 13 -and
    @($designReceipt.mutation_ids).Count -eq 13 -and
    [int]$designReceipt.model_construction_count -eq 0 -and
    [int]$designReceipt.world_attempt_count -eq 0 -and
    [int]$designReceipt.world_build_count -eq 0 -and
    -not [bool]$designReceipt.physical_campaign_opened -and
    -not [bool]$designReceipt.q_sdk_r23_satisfied -and
    -not [bool]$designReceipt.release_authorized
) "declaration validator receipt changed"

$godot = "C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe"
Assert-R23D66Declaration (Test-Path -LiteralPath $godot -PathType Leaf) (
    "Godot executable is missing: $godot"
)
$seedOutput = @(
    & $godot --headless --path $repoRoot --script (
        "res://sdk/turning/r23d66_seed_fixture_compiler.gd"
    ) 2>&1
)
Assert-R23D66Declaration ($LASTEXITCODE -eq 0) (
    "pure seed compiler failed: $($seedOutput -join ' ')"
)
$seedMarkers = @($seedOutput | Where-Object {
    ([string]$_).StartsWith("QSDK_R23D66_SEED_FIXTURES ")
})
Assert-R23D66Declaration ($seedMarkers.Count -eq 1) (
    "seed compiler marker changed"
)
$seedReceipt = ([string]$seedMarkers[0]).Substring(
    "QSDK_R23D66_SEED_FIXTURES ".Length
) | ConvertFrom-Json -AsHashtable -Depth 100
$fixture = @($seedReceipt.fixtures)[0]
$frozen = $declaration.frozen_matrix.initial_perturbation
Assert-R23D66Declaration (
    @($seedReceipt.fixtures).Count -eq 1 -and
    [int]$fixture.campaign_seed -eq $seed -and
    [double]$fixture.fixture_vertical_clearance_m -eq
        [double]$frozen.fixture_vertical_clearance_m -and
    [double]$fixture.fixture_yaw_rad -eq [double]$frozen.fixture_yaw_rad -and
    (@($fixture.initial_linear_velocity_world_m_s) -join "|") -ceq
        (@($frozen.initial_linear_velocity_world_m_s) -join "|") -and
    (@($fixture.initial_torso_angular_velocity_world_rad_s) -join "|") -ceq
        (@($frozen.initial_torso_angular_velocity_world_rad_s) -join "|") -and
    [int]$fixture.gait_phase_offset_ticks -eq [int]$frozen.gait_phase_offset_ticks -and
    [int]$seedReceipt.model_construction_count -eq 0 -and
    [int]$seedReceipt.world_attempt_count -eq 0 -and
    [int]$seedReceipt.world_build_count -eq 0
) "pure seed fixture compilation changed"

$predecessorOutput = @(& pwsh -NoProfile -File $predecessorAuditPath 2>&1)
Assert-R23D66Declaration ($LASTEXITCODE -eq 0) (
    "immutable R23D65 predecessor audit failed: $($predecessorOutput -join ' ')"
)
$routeOutput = @(& pwsh -NoProfile -File $routeAuditPath 2>&1)
Assert-R23D66Declaration ($LASTEXITCODE -eq 0) (
    "qualified development-route audit failed: $($routeOutput -join ' ')"
)

$release = Get-Content -LiteralPath $releaseContractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$support = Get-Content -LiteralPath $supportMatrixPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$turningGate = @($release.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R23"
})
$releaseSuccessor = $turningGate[0].proof.prospective_r23d66_production_route_three_engine_turning_validation
$supportSuccessor = $support.locomotion_modes.three_engine_turning_production_route.prospective_held_out_successor
Assert-R23D66Declaration (
    $turningGate.Count -eq 1 -and
    [string]$turningGate[0].proof.kind -ceq "missing" -and
    -not [bool]$support.locomotion_modes.command_conditioned_turning -and
    -not [bool]$support.claim_boundary.command_conditioned_turning -and
    -not [bool]$support.release_authorized
) "declaration promoted a public turning or release claim"
foreach ($successor in @($releaseSuccessor, $supportSuccessor)) {
    Assert-R23D66Declaration (
        $null -ne $successor -and
        [string]$successor.gate_id -ceq "QSDK-R23D66" -and
        [string]$successor.status -ceq
            "five_qualifications_retained_latest_generic_cas_repair_qualification_passed_adoption_refused_by_commissioned_executor_guard_scoped_supervisor_symlink_resolution_implemented_fresh_clean_push_qualification_and_adoption_pending_physical_not_opened" -and
        [string]$successor.question_class -ceq "finite_decision" -and
        [string]$successor.preregistration_path -ceq
            "sdk/turning/r23d66_production_route_three_engine_turning_validation_preregistration_v1.json" -and
        [string]$successor.preregistration_raw_sha256 -ceq
            (Get-R23D66Sha256 $declarationPath) -and
        [string]$successor.design_path -ceq
            "sdk/turning/r23d66_production_route_three_engine_turning_validation.py" -and
        [string]$successor.design_raw_sha256 -ceq
            (Get-R23D66Sha256 $designPath) -and
        [string]$successor.seed_fixture_compiler_path -ceq
            "sdk/turning/r23d66_seed_fixture_compiler.gd" -and
        [string]$successor.seed_fixture_compiler_raw_sha256 -ceq
            (Get-R23D66Sha256 $seedCompilerPath) -and
        [string]$successor.declaration_audit_path -ceq
            "tests/test_qsdk_r23d66_preregistration.ps1" -and
        [string]$successor.declaration_audit_raw_sha256 -ceq
            (Get-R23D66Sha256 $MyInvocation.MyCommand.Path) -and
        [string]$successor.implementation_contract_path -ceq
            "sdk/turning/r23d66_production_route_three_engine_turning_implementation_v1.json" -and
        [string]$successor.implementation_contract_raw_sha256 -ceq
            (Get-R23D66Sha256 $implementationPath) -and
        [string]$successor.implementation_materializer_path -ceq
            "sdk/turning/materialize_r23d66_implementation.py" -and
        [string]$successor.implementation_materializer_raw_sha256 -ceq
            (Get-R23D66Sha256 $materializerPath) -and
        [string]$successor.zero_world_runner_path -ceq
            "sdk/run_qsdk_r23d66_zero_world.ps1" -and
        [string]$successor.zero_world_runner_raw_sha256 -ceq
            (Get-R23D66Sha256 $zeroWorldRunnerPath) -and
        [string]$successor.zero_world_audit_path -ceq
            "tests/test_qsdk_r23d66_zero_world.ps1" -and
        [string]$successor.zero_world_audit_raw_sha256 -ceq
            (Get-R23D66Sha256 $zeroWorldAuditPath) -and
        [string]$successor.evaluator_path -ceq
            "sdk/turning/r23d66_production_route_three_engine_turning_evaluator.py" -and
        [string]$successor.evaluator_raw_sha256 -ceq
            (Get-R23D66Sha256 $evaluatorPath) -and
        [string]$successor.campaign_attestation_manifest_path -ceq
            "sdk/turning/r23d66_campaign_attestation_manifest_v1.json" -and
        [string]$successor.campaign_attestation_manifest_raw_sha256 -ceq
            (Get-R23D66Sha256 $campaignManifestPath) -and
        [string]$successor.campaign_attestation_manifest_materializer_path -ceq
            "sdk/turning/materialize_r23d66_campaign_attestation_manifest.py" -and
        [string]$successor.campaign_attestation_manifest_materializer_raw_sha256 -ceq
            (Get-R23D66Sha256 $campaignManifestMaterializerPath) -and
        [string]$successor.campaign_role_audit_path -ceq
            "tests/test_qsdk_r23d66_campaign_roles.ps1" -and
        [string]$successor.campaign_role_audit_raw_sha256 -ceq
            (Get-R23D66Sha256 $campaignRoleAuditPath) -and
        [string]$successor.physical_supervisor_path -ceq
            "sdk/run_qsdk_r23d66_supervisor.ps1" -and
        [string]$successor.physical_supervisor_raw_sha256 -ceq
            (Get-R23D66Sha256 $physicalSupervisorPath) -and
        [string]$successor.first_scoped_qualification_source_commit -ceq
            "bf6836de7806c18e39eafa10a942ae0d77bc310a" -and
        [string]$successor.first_scoped_qualification_source_tree_git_oid -ceq
            "318cc30559ad0031a13dc84339e72b3c84e5f6ae" -and
        [string]$successor.first_scoped_qualification_root -ceq
            "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r23d66-qualification-20260825T204759Z-bf6836de7806" -and
        [string]$successor.first_scoped_qualification_failure_raw_sha256 -ceq
            "sha256:ef5148a0ded45000eb4b1f426ae80ba2a71c30cfbad9b3ff03e84cb3711be092" -and
        [long]$successor.first_scoped_qualification_failure_byte_length -eq 647 -and
        [string]$successor.first_scoped_qualification_failed_gate_receipt_raw_sha256 -ceq
            "sha256:92e7a7080ed3297242cfa1d772429b271b772c35335ae3a48c9379e4d3fca212" -and
        [long]$successor.first_scoped_qualification_failed_gate_receipt_byte_length -eq 2715 -and
        [bool]$successor.first_scoped_qualification_attempted -and
        -not [bool]$successor.first_scoped_qualification_passed -and
        [int]$successor.first_scoped_qualification_passed_gate_count -eq 3 -and
        [string]$successor.first_scoped_qualification_failed_gate_id -ceq
            "CAK1-EVIDENCE-PROVENANCE" -and
        [int]$successor.first_scoped_qualification_campaign_role_gate_count -eq 0 -and
        [int]$successor.first_scoped_qualification_retained_file_count -eq 13 -and
        [long]$successor.first_scoped_qualification_retained_byte_count -eq 12719 -and
        [int]$successor.first_scoped_qualification_model_construction_count -eq 0 -and
        [int]$successor.first_scoped_qualification_world_attempt_count -eq 0 -and
        [int]$successor.first_scoped_qualification_world_build_count -eq 0 -and
        [bool]$successor.failed_qualification_retained -and
        -not [bool]$successor.failed_qualification_reusable -and
        [bool]$successor.provenance_reconciliation_implemented -and
        [int]$successor.qualification_attempt_count -eq 5 -and
        [int]$successor.failed_qualification_count -eq 2 -and
        [string]$successor.second_scoped_qualification_source_commit -ceq
            "74016b9813965fd73fdaa5718596f19caaa8c051" -and
        [string]$successor.second_scoped_qualification_source_tree_git_oid -ceq
            "43cff29c590c00a97340091d08b3c41a1bb12e82" -and
        [string]$successor.second_scoped_qualification_root -ceq
            "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r23d66-qualification-20260825T210306Z-74016b981396" -and
        [string]$successor.second_scoped_qualification_failure_path -ceq
            "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r23d66-qualification-20260825T210306Z-74016b981396/failure.json" -and
        [string]$successor.second_scoped_qualification_failure_raw_sha256 -ceq
            "sha256:fb615dd9037867d074080d71b04b0bc26616764c5ed14bb4d3def868acda25de" -and
        [long]$successor.second_scoped_qualification_failure_byte_length -eq 649 -and
        [string]$successor.second_scoped_qualification_failed_gate_receipt_path -ceq
            "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r23d66-qualification-20260825T210306Z-74016b981396/013-R23D66-COMPLETE-ZERO-WORLD.receipt.json" -and
        [string]$successor.second_scoped_qualification_failed_gate_receipt_raw_sha256 -ceq
            "sha256:9515ebe3689a63ea7de502008c8edff6f8b15f4a1f3e558fa91564d9201b9fe6" -and
        [long]$successor.second_scoped_qualification_failed_gate_receipt_byte_length -eq 2855 -and
        [string]$successor.second_scoped_qualification_failed_gate_stderr_raw_sha256 -ceq
            "sha256:f14d64eb4e46298bb8de6ebfea3fa2bb76e0de1c57344af62f73b7c6f4862c38" -and
        [long]$successor.second_scoped_qualification_failed_gate_stderr_byte_length -eq 995 -and
        [int]$successor.second_scoped_qualification_global_gate_pass_count -eq 12 -and
        [int]$successor.second_scoped_qualification_lineage_gate_pass_count -eq 0 -and
        [string]$successor.second_scoped_qualification_failed_gate_id -ceq
            "R23D66-COMPLETE-ZERO-WORLD" -and
        [int]$successor.second_scoped_qualification_campaign_role_gate_count -eq 0 -and
        [int]$successor.second_scoped_qualification_retained_file_count -eq 40 -and
        [long]$successor.second_scoped_qualification_retained_byte_count -eq 330920 -and
        [int]$successor.second_scoped_qualification_model_construction_count -eq 0 -and
        [int]$successor.second_scoped_qualification_world_attempt_count -eq 0 -and
        [int]$successor.second_scoped_qualification_world_build_count -eq 0 -and
        [string]$successor.second_scoped_qualification_failure_code -ceq
            "nested_operation_lock_gate_invoked_standalone_mode_under_outer_production_conformance_lock" -and
        [bool]$successor.second_scoped_qualification_retained -and
        -not [bool]$successor.second_scoped_qualification_reusable -and
        [bool]$successor.nested_lock_mode_integration_repair_implemented -and
        [int]$successor.passing_qualification_count -eq 3 -and
        [int]$successor.non_adoptable_passing_qualification_count -eq 2 -and
        [int]$successor.adopted_qualification_count -eq 1 -and
        [string]$successor.third_scoped_qualification_source_commit -ceq
            "74f061c53cd8d363831bf39393bf31fbf1276fb2" -and
        [string]$successor.third_scoped_qualification_source_tree_git_oid -ceq
            "5e65ce1df8899d9c33ed50b67ead8f78a05e40e6" -and
        [string]$successor.third_scoped_qualification_root -ceq
            "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r23d66-qualification-20260825T211949Z-74f061c53cd8" -and
        [string]$successor.third_scoped_qualification_attestation_raw_sha256 -ceq
            "sha256:5449836806f11014c460857cb7cca283b9a83a8d5fc132ee582d2c3f6ce0c377" -and
        [long]$successor.third_scoped_qualification_attestation_byte_length -eq 145461 -and
        [int]$successor.third_scoped_qualification_retained_file_count -eq 49 -and
        [long]$successor.third_scoped_qualification_retained_byte_count -eq 486952 -and
        [int]$successor.third_scoped_qualification_global_gate_pass_count -eq 12 -and
        [int]$successor.third_scoped_qualification_lineage_gate_pass_count -eq 1 -and
        [int]$successor.third_scoped_qualification_campaign_role_gate_pass_count -eq 3 -and
        [bool]$successor.third_scoped_qualification_passed -and
        [string]$successor.third_scoped_qualification_python_path -ceq
            "C:/Users/Cole/CodeStuff/games/SporeSpore/sdk/adapters/mujoco/.venv/Scripts/python.exe" -and
        [string]$successor.third_scoped_qualification_python_raw_sha256 -ceq
            "sha256:21bb438c0d4a6f1f164b9a646f6ee000340185e5871180aec06db8d3f07c0082" -and
        [bool]$successor.third_scoped_qualification_adoption_attempted -and
        -not [bool]$successor.third_scoped_qualification_adoption_passed -and
        [string]$successor.third_scoped_qualification_adoption_failure_code -ceq
            "runtime_python_launcher_did_not_match_commissioned_lca1_runtime" -and
        -not [bool]$successor.third_scoped_qualification_reusable_for_physical_launch -and
        [string]$successor.fourth_scoped_qualification_source_commit -ceq
            "74f061c53cd8d363831bf39393bf31fbf1276fb2" -and
        [string]$successor.fourth_scoped_qualification_source_tree_git_oid -ceq
            "5e65ce1df8899d9c33ed50b67ead8f78a05e40e6" -and
        [string]$successor.fourth_scoped_qualification_root -ceq
            "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r23d66-qualification-20260825T212635Z-74f061c53cd8-commissioned-runtime" -and
        [string]$successor.fourth_scoped_qualification_attestation_raw_sha256 -ceq
            "sha256:98ba36a72669308dbe5d524db4da25d3a95b4e30c43d8de49d97dd37dfc9f534" -and
        [long]$successor.fourth_scoped_qualification_attestation_byte_length -eq 146404 -and
        [int]$successor.fourth_scoped_qualification_global_gate_pass_count -eq 12 -and
        [int]$successor.fourth_scoped_qualification_lineage_gate_pass_count -eq 1 -and
        [int]$successor.fourth_scoped_qualification_campaign_role_gate_pass_count -eq 3 -and
        [bool]$successor.fourth_scoped_qualification_passed -and
        [string]$successor.fourth_scoped_qualification_python_path -ceq
            "C:/Program Files/Python311/python.exe" -and
        [string]$successor.fourth_scoped_qualification_python_raw_sha256 -ceq
            "sha256:5f7b89a612c9b8af1d6456cdfcd1dbe5ca630849e79aebced9bee9a6694952ec" -and
        [string]$successor.fourth_scoped_qualification_adoption_raw_sha256 -ceq
            "sha256:7a8bf66d007766f505e839a349ea70750df4fd142219d35808a955fcb8d7eea9" -and
        [long]$successor.fourth_scoped_qualification_adoption_byte_length -eq 3322 -and
        [bool]$successor.fourth_scoped_qualification_adoption_passed -and
        [int]$successor.fourth_scoped_qualification_and_adoption_retained_file_count -eq 50 -and
        [long]$successor.fourth_scoped_qualification_and_adoption_retained_byte_count -eq 491881 -and
        [string]$successor.fifth_scoped_qualification_source_commit -ceq
            "ac534fd485a2a54859ab1d4bc88153c425d7120f" -and
        [string]$successor.fifth_scoped_qualification_source_tree_git_oid -ceq
            "d1903d59a6a9592eda54759ebf1e2bdfffcb528d" -and
        [string]$successor.fifth_scoped_qualification_root -ceq
            "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r23d66-qualification-20260825T214559Z-ac534fd485a2-cas-symlink-repair" -and
        [string]$successor.fifth_scoped_qualification_attestation_raw_sha256 -ceq
            "sha256:f843f0a255128d2e4aaf790781cbe1fdbfe45254564b95c37d51a4fdc7a1c833" -and
        [long]$successor.fifth_scoped_qualification_attestation_byte_length -eq 146313 -and
        [int]$successor.fifth_scoped_qualification_retained_file_count -eq 49 -and
        [long]$successor.fifth_scoped_qualification_retained_byte_count -eq 488409 -and
        [int]$successor.fifth_scoped_qualification_global_gate_pass_count -eq 12 -and
        [int]$successor.fifth_scoped_qualification_lineage_gate_pass_count -eq 1 -and
        [int]$successor.fifth_scoped_qualification_campaign_role_gate_pass_count -eq 3 -and
        [bool]$successor.fifth_scoped_qualification_passed -and
        [string]$successor.fifth_scoped_qualification_python_path -ceq
            "C:/Program Files/Python311/python.exe" -and
        [string]$successor.fifth_scoped_qualification_python_raw_sha256 -ceq
            "sha256:5f7b89a612c9b8af1d6456cdfcd1dbe5ca630849e79aebced9bee9a6694952ec" -and
        [bool]$successor.fifth_scoped_qualification_adoption_attempted -and
        -not [bool]$successor.fifth_scoped_qualification_adoption_passed -and
        [string]$successor.fifth_scoped_qualification_adoption_failure_code -ceq
            "commissioned_executor_source_changed_content_addressed_artifact_store" -and
        -not [bool]$successor.fifth_scoped_qualification_reusable_for_physical_launch -and
        [string]$successor.first_physical_supervisor_invocation_source_commit -ceq
            "74f061c53cd8d363831bf39393bf31fbf1276fb2" -and
        [string]$successor.first_physical_supervisor_invocation_root -ceq
            "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r23d66-physical-20260825T213353Z-74f061c53cd8" -and
        [string]$successor.first_physical_supervisor_invocation_failure_stage -ceq
            "input_content_addressed_artifact_publication_before_physical_freeze" -and
        [string]$successor.first_physical_supervisor_invocation_failure_code -ceq
            "rustup_proxy_symlink_fileinfo_length_diverged_from_followed_target_byte_stream" -and
        [string]$successor.first_physical_supervisor_invocation_failed_input_path -ceq
            "C:/Users/Cole/.cargo/bin/cargo.exe" -and
        [string]$successor.first_physical_supervisor_invocation_failed_input_raw_sha256 -ceq
            "sha256:86478e53f769379d7f0ebfa7c9aa97cb76ca92233f79aa2cc0dbee2efaac73c7" -and
        [long]$successor.first_physical_supervisor_invocation_failed_input_link_metadata_byte_length -eq 0 -and
        [long]$successor.first_physical_supervisor_invocation_failed_input_target_stream_byte_length -eq 12814336 -and
        [int]$successor.first_physical_supervisor_invocation_retained_file_count -eq 0 -and
        [long]$successor.first_physical_supervisor_invocation_retained_byte_count -eq 0 -and
        -not [bool]$successor.first_physical_supervisor_invocation_freeze_written -and
        -not [bool]$successor.first_physical_supervisor_invocation_attempt_authorization_written -and
        -not [bool]$successor.first_physical_supervisor_invocation_attempt_consumed -and
        [int]$successor.first_physical_supervisor_invocation_model_construction_count -eq 0 -and
        [int]$successor.first_physical_supervisor_invocation_world_attempt_count -eq 0 -and
        [int]$successor.first_physical_supervisor_invocation_world_build_count -eq 0 -and
        [bool]$successor.first_physical_supervisor_invocation_retained -and
        -not [bool]$successor.content_addressed_artifact_symlink_target_length_repair_implemented -and
        [string]$successor.generic_content_addressed_artifact_symlink_repair_source_commit -ceq
            "ac534fd485a2a54859ab1d4bc88153c425d7120f" -and
        [bool]$successor.generic_content_addressed_artifact_symlink_repair_rejected_by_commissioned_executor_guard -and
        [bool]$successor.commissioned_content_addressed_artifact_store_restored_exactly -and
        [bool]$successor.r23d66_scoped_runtime_symlink_content_source_resolution_implemented -and
        -not [bool]$successor.r23d66_scoped_runtime_symlink_content_source_ghost_pending -and
        [bool]$successor.r23d66_scoped_runtime_symlink_content_source_ghost_passed -and
        [bool]$successor.content_addressed_rustup_symlink_development_ghost_passed -and
        [bool]$successor.qualification_retry_requires_distinct_corrected_clean_pushed_source -and
        [int]$successor.fresh_seed -eq $seed -and
        [int]$successor.declared_cell_count -eq 9 -and
        [int]$successor.declared_world_count -eq 9 -and
        [int]$successor.declaration_mutation_rejection_count -eq 13 -and
        [int]$successor.implementation_dependency_count -eq 201 -and
        [int]$successor.declared_lineage_gate_count -eq 1 -and
        [int]$successor.declared_campaign_role_gate_count -eq 3 -and
        [int]$successor.declared_total_scoped_campaign_gate_count -eq 4 -and
        [int]$successor.scoped_qualification_gate_count -eq 16 -and
        [int]$successor.representative_worker_preflight_count -eq 3 -and
        [int]$successor.native_selector_negative_count -eq 3 -and
        [int]$successor.physical_authorization_negative_count -eq 3 -and
        [int]$successor.evaluator_outcome_control_count -eq 4 -and
        [int]$successor.model_construction_count -eq 0 -and
        [int]$successor.world_attempt_count -eq 0 -and
        [int]$successor.world_build_count -eq 0 -and
        [bool]$successor.implementation_complete -and
        [bool]$successor.complete_zero_world_gate_passed -and
        [bool]$successor.compact_qualification_machinery_implemented -and
        [bool]$successor.physical_supervisor_implemented -and
        -not [bool]$successor.scoped_qualification_passed -and
        -not [bool]$successor.campaign_attestation_adopted -and
        -not [bool]$successor.physical_campaign_opened -and
        -not [bool]$successor.q_sdk_r23_satisfied -and
        -not [bool]$successor.cross_engine_equivalence -and
        -not [bool]$successor.release_authorized
    ) "release or support successor declaration changed"
}

Write-Output (
    "[turning/3e] PASS R23D66 finite-decision declaration: seed=23179 " +
    "cells=9 mutations=13 models=0 worlds=0 turning=False QSDK-R23=False"
)

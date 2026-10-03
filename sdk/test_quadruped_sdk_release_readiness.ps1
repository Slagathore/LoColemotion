[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$compilerPath = Join-Path $sdkRoot "compile_quadruped_sdk_release_readiness.ps1"
$sdk1CompilerPath = Join-Path $sdkRoot "compile_quadruped_sdk1_milestone_readiness.ps1"
$sdk1MappingPath = Join-Path (
    $sdkRoot
) "release\quadruped_sdk1_milestone_mapping_v1.json"
$sdk1CandidateAuthorityClosurePath = Join-Path (
    $sdkRoot
) "release\quadruped_sdk1_candidate_authority_closure_v1.json"
$packagerPath = Join-Path $sdkRoot "package_quadruped_sdk.ps1"
$qsdkR01Sdk1CandidateBridgeTestPath = Join-Path (
    $repoRoot
) "tests\test_qsdk_r01_sdk1_candidate_bridge.ps1"
$contractPath = Join-Path $sdkRoot "release\quadruped_release_contract.json"
$supportMatrixPath = Join-Path $sdkRoot "release\quadruped_support_matrix.json"
$r24d1DesignPath = Join-Path (
    $sdkRoot
) "recovery\r24d1_canonical_prone_to_standing_design_v1.json"
$r24d2SemanticsPath = Join-Path (
    $sdkRoot
) "recovery\r24d2_portable_recovery_semantics_v1.json"
$r24d2ManifestPath = Join-Path (
    $sdkRoot
) "recovery\r24d2_portable_recovery_semantics_validation_manifest.json"
$r24d3SourcePath = Join-Path (
    $sdkRoot
) "recovery\r24d3_godot_jolt_motor_telemetry_source_v1.json"
$r24d3ManifestPath = Join-Path (
    $sdkRoot
) "recovery\r24d3_godot_jolt_motor_telemetry_source_validation_manifest.json"
$r24d3AdoptionPath = Join-Path (
    $sdkRoot
) "recovery\r24d3_godot_jolt_motor_telemetry_cold_qualification_adoption_v2.json"
$r24d3FullColdQualificationPath = Join-Path (
    $sdkRoot
) (
    "recovery\r24d3_godot_jolt_motor_telemetry_post_adoption_" +
    "full_cold_conformance_qualification_v1.json"
)
$r24d4PreregistrationPath = Join-Path (
    $sdkRoot
) (
    "recovery\r24d4_godot_jolt_one_hinge_telemetry_" +
    "characterization_preregistration_v1.json"
)
$r24d4ManifestPath = Join-Path (
    $sdkRoot
) "recovery\r24d4_godot_jolt_one_hinge_telemetry_validation_manifest.json"
$r24d4ClosurePath = Join-Path (
    $sdkRoot
) (
    "recovery\r24d4_godot_jolt_one_hinge_telemetry_" +
    "zero_world_failure_closure_v1.json"
)
$r24d5PreregistrationPath = Join-Path (
    $sdkRoot
) (
    "recovery\r24d5_godot_jolt_one_hinge_telemetry_" +
    "characterization_preregistration_v1.json"
)
$r24d5ManifestPath = Join-Path (
    $sdkRoot
) "recovery\r24d5_godot_jolt_one_hinge_telemetry_validation_manifest.json"
$r24d5DiagnosticsPath = Join-Path (
    $sdkRoot
) "recovery\r24d5_precommit_zero_world_diagnostics_v1.json"
$r24d5PhysicalClosurePath = Join-Path (
    $sdkRoot
) (
    "recovery\r24d5_godot_jolt_one_hinge_telemetry_" +
    "physical_failure_closure_v1.json"
)
$r24d5PhysicalClosureAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d5_one_hinge_telemetry_physical_failure_closure.ps1"
$r24d6PreregistrationPath = Join-Path (
    $sdkRoot
) (
    "recovery\r24d6_godot_jolt_one_hinge_telemetry_" +
    "characterization_preregistration_v1.json"
)
$r24d6ManifestPath = Join-Path (
    $sdkRoot
) "recovery\r24d6_godot_jolt_one_hinge_telemetry_validation_manifest.json"
$r24d6DiagnosticsPath = Join-Path (
    $sdkRoot
) "recovery\r24d6_precommit_godot_parser_diagnostics_v1.json"
$r24d6FirstQualificationFailurePath = Join-Path (
    $sdkRoot
) "recovery\r24d6_first_official_zero_world_qualification_failure_v1.json"
$r24d6ZeroWorldFailureClosurePath = Join-Path (
    $sdkRoot
) (
    "recovery\r24d6_godot_jolt_one_hinge_telemetry_" +
    "zero_world_failure_closure_v1.json"
)
$r24d6ZeroWorldFailureClosureAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d6_one_hinge_telemetry_zero_world_failure_closure.ps1"
$r24d7PreregistrationPath = Join-Path (
    $sdkRoot
) (
    "recovery\r24d7_godot_jolt_one_hinge_telemetry_" +
    "characterization_preregistration_v1.json"
)
$r24d7ManifestPath = Join-Path (
    $sdkRoot
) "recovery\r24d7_godot_jolt_one_hinge_telemetry_validation_manifest.json"
$r24d7IntegralSchemaPath = Join-Path (
    $sdkRoot
) "recovery\r24d7_integral_variant_schema_v1.json"
$r24d7DiagnosticsPath = Join-Path (
    $sdkRoot
) "recovery\r24d7_precommit_godot_parser_diagnostics_v1.json"
$r24d7PhysicalClosurePath = Join-Path (
    $sdkRoot
) (
    "recovery\r24d7_godot_jolt_one_hinge_telemetry_" +
    "physical_failure_closure_v1.json"
)
$r24d7PhysicalClosureAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d7_one_hinge_telemetry_physical_failure_closure.ps1"
$r24d8PreregistrationPath = Join-Path (
    $sdkRoot
) "recovery\r24d8_godot_jolt_active_step_snapshot_timing_preregistration_v1.json"
$r24d8ManifestPath = Join-Path (
    $sdkRoot
) "recovery\r24d8_godot_jolt_active_step_snapshot_timing_validation_manifest.json"
$r24d8DiagnosticsPath = Join-Path (
    $sdkRoot
) "recovery\r24d8_precommit_zero_world_diagnostics_v1.json"
$r24d8FirstOfficialFailurePath = Join-Path (
    $sdkRoot
) "recovery\r24d8_first_official_zero_world_qualification_failure_v1.json"
$r24d8MaintenanceDiagnosticsPath = Join-Path (
    $sdkRoot
) "recovery\r24d8_maintenance_precommit_diagnostics_v1.json"
$r24d8PositiveClosurePath = Join-Path (
    $sdkRoot
) "recovery\r24d8_godot_jolt_active_step_snapshot_timing_positive_closure_v1.json"
$r24d8PositiveClosureDiagnosticsPath = Join-Path (
    $sdkRoot
) "recovery\r24d8_positive_closure_precommit_diagnostics_v1.json"
$r24d8PositiveClosureAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d8_active_step_snapshot_timing_positive_closure.ps1"
$r24d8CombinedPatchPath = Join-Path (
    $sdkRoot
) "adapters\godot\engine_patches\godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch"
$r24d8FreezeAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d8_godot_jolt_active_step_snapshot_timing_freeze.ps1"
$r24d8PredecessorCompatibilityAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d8_predecessor_evidence_compatibility.ps1"
$r24d9PreregistrationPath = Join-Path (
    $sdkRoot
) (
    "recovery\r24d9_godot_jolt_one_hinge_numerical_telemetry_" +
    "characterization_preregistration_v1.json"
)
$r24d9DeclarationAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d9_numerical_telemetry_preregistration.ps1"
$r24d9PrecommitDiagnosticsPath = Join-Path (
    $sdkRoot
) "recovery\r24d9_precommit_zero_world_diagnostics_v1.json"
$r24d9ValidationManifestPath = Join-Path (
    $sdkRoot
) (
    "recovery\r24d9_godot_jolt_one_hinge_numerical_telemetry_" +
    "validation_manifest.json"
)
$r24d9FreezeAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_freeze.ps1"
$r24d9SupervisorPath = Join-Path (
    $sdkRoot
) "run_qsdk_r24d9_one_hinge_numerical_telemetry_characterization.ps1"
$r24d9PhysicalFailureClosurePath = Join-Path (
    $sdkRoot
) (
    "recovery\r24d9_godot_jolt_one_hinge_numerical_telemetry_" +
    "physical_failure_closure_v1.json"
)
$r24d9PhysicalFailureClosureAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) (
    "tests\test_qsdk_r24d9_one_hinge_numerical_telemetry_" +
    "physical_failure_closure.ps1"
)
$r24d10ZeroWorldPositiveClosurePath = Join-Path (
    $sdkRoot
) (
    "recovery\r24d10_godot_jolt_exact_step_numerical_telemetry_" +
    "zero_world_positive_closure_v1.json"
)
$r24d10ZeroWorldPositiveClosureAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) (
    "tests\test_qsdk_r24d10_exact_step_numerical_telemetry_" +
    "zero_world_positive_closure.ps1"
)
$r24d10ZeroWorldPositiveClosureImplementationPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) (
    "tests\test_qsdk_r24d10_exact_step_numerical_telemetry_" +
    "zero_world_positive_closure.py"
)
$r24d10PhysicalSupervisorContractPath = Join-Path (
    $sdkRoot
) (
    "recovery\r24d10_godot_jolt_exact_step_numerical_telemetry_" +
    "physical_supervisor_contract_v2.json"
)
$r24d10PhysicalSupervisorManifestPath = Join-Path (
    $sdkRoot
) (
    "recovery\r24d10_godot_jolt_exact_step_numerical_telemetry_" +
    "physical_supervisor_manifest_v2.json"
)
$r24d10PhysicalSupervisorPath = Join-Path (
    $sdkRoot
) "run_qsdk_r24d10_exact_step_numerical_telemetry_characterization.ps1"
$r24d10PhysicalSupervisorSourceAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) (
    "tests\test_qsdk_r24d10_exact_step_numerical_telemetry_" +
    "physical_supervisor_source_v2.py"
)
$r24d10FirstSupervisorAdoptionRefusalPath = Join-Path (
    $sdkRoot
) (
    "recovery\r24d10_first_physical_supervisor_qualification_" +
    "adoption_refusal_v1.json"
)
$r24d10FirstSupervisorAdoptionRefusalAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) (
    "tests\test_qsdk_r24d10_first_physical_supervisor_qualification_" +
    "adoption_refusal.py"
)
$r24d10PhysicalSupervisorQualificationClosurePath = Join-Path (
    $sdkRoot
) (
    "recovery\r24d10_godot_jolt_exact_step_numerical_telemetry_" +
    "physical_supervisor_qualification_positive_closure_v2.json"
)
$r24d10PhysicalSupervisorQualificationClosureAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) (
    "tests\test_qsdk_r24d10_physical_supervisor_qualification_" +
    "positive_closure_v2.py"
)
$r24d10PhysicalAuthorizationPath = Join-Path (
    $sdkRoot
) (
    "recovery\r24d10_godot_jolt_exact_step_numerical_telemetry_" +
    "physical_authorization_v2.json"
)
$r24d10PhysicalCharacterizationClosurePath = Join-Path (
    $sdkRoot
) (
    "recovery\r24d10_godot_jolt_exact_step_numerical_telemetry_" +
    "physical_characterization_closure_v1.json"
)
$r24d10PhysicalCharacterizationClosureAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) (
    "tests\test_qsdk_r24d10_exact_step_numerical_telemetry_" +
    "physical_characterization_closure.py"
)
$r24d11ProfilePromotionDecisionPath = Join-Path (
    $sdkRoot
) (
    "recovery\r24d11_godot_jolt_instrumented_profile_promotion_" +
    "decision_v1.json"
)
$r24d11ProfilePromotionDecisionAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) (
    "tests\test_qsdk_r24d11_godot_jolt_instrumented_profile_" +
    "promotion_decision.py"
)
$r24d12PreregistrationPath = Join-Path (
    $sdkRoot
) "recovery\r24d12_godot_jolt_braking_mechanism_activation_preregistration_v1.json"
$r24d12ValidationManifestPath = Join-Path (
    $sdkRoot
) "recovery\r24d12_godot_jolt_braking_mechanism_activation_validation_manifest.json"
$r24d12EvaluatorPath = Join-Path (
    $sdkRoot
) "recovery\r24d12_godot_jolt_braking_mechanism_activation_evaluator.py"
$r24d12RigPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "scripts\lab\rigs\r24d12_godot_jolt_braking_mechanism_activation_rig.gd"
$r24d12WorkerPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_sdk_qsdk_r24d12_godot_jolt_braking_mechanism_activation_worker.gd"
$r24d12ZeroWorldRunnerPath = Join-Path (
    $sdkRoot
) "run_qsdk_r24d12_braking_mechanism_activation_zero_world_gate.ps1"
$r24d12FreezeAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d12_godot_jolt_braking_mechanism_activation_freeze.py"
$r24d12ZeroWorldPositiveClosurePath = Join-Path (
    $sdkRoot
) "recovery\r24d12_godot_jolt_braking_mechanism_activation_zero_world_positive_closure_v1.json"
$r24d12ZeroWorldPositiveClosureAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d12_braking_mechanism_activation_zero_world_positive_closure.py"
$r24d12PhysicalSupervisorContractPath = Join-Path (
    $sdkRoot
) "recovery\r24d12_godot_jolt_braking_mechanism_activation_physical_supervisor_contract_v1.json"
$r24d12PhysicalSupervisorManifestPath = Join-Path (
    $sdkRoot
) "recovery\r24d12_godot_jolt_braking_mechanism_activation_physical_supervisor_manifest_v1.json"
$r24d12PhysicalSupervisorPath = Join-Path (
    $sdkRoot
) "run_qsdk_r24d12_braking_mechanism_activation_characterization.ps1"
$r24d12PhysicalSupervisorSourceAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d12_braking_mechanism_activation_physical_supervisor_source.py"
$r24d12PhysicalSupervisorQualificationClosurePath = Join-Path (
    $sdkRoot
) "recovery\r24d12_godot_jolt_braking_mechanism_activation_physical_supervisor_qualification_positive_closure_v1.json"
$r24d12PhysicalAuthorizationPath = Join-Path (
    $sdkRoot
) "recovery\r24d12_godot_jolt_braking_mechanism_activation_physical_authorization_v1.json"
$r24d12PhysicalSupervisorQualificationAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d12_braking_mechanism_activation_physical_supervisor_qualification.py"
$r24d12PhysicalAttemptClosurePath = Join-Path (
    $sdkRoot
) "recovery\r24d12_godot_jolt_braking_mechanism_activation_physical_attempt_closure_v1.json"
$r24d12PhysicalAttemptClosureAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d12_braking_mechanism_activation_physical_attempt_closure.py"
$r24d13PreregistrationPath = Join-Path (
    $sdkRoot
) "recovery\r24d13_godot_jolt_braking_mechanism_activation_preregistration_v1.json"
$r24d13ValidationManifestPath = Join-Path (
    $sdkRoot
) "recovery\r24d13_godot_jolt_braking_mechanism_activation_validation_manifest.json"
$r24d13EvaluatorPath = Join-Path (
    $sdkRoot
) "recovery\r24d13_godot_jolt_braking_mechanism_activation_evaluator.py"
$r24d13RigPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "scripts\lab\rigs\r24d13_godot_jolt_braking_mechanism_activation_rig.gd"
$r24d13WorkerPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_sdk_qsdk_r24d13_godot_jolt_braking_mechanism_activation_worker.gd"
$r24d13PhysicalSupervisorContractPath = Join-Path (
    $sdkRoot
) "recovery\r24d13_godot_jolt_braking_mechanism_activation_physical_supervisor_contract_v1.json"
$r24d13PhysicalSupervisorManifestPath = Join-Path (
    $sdkRoot
) "recovery\r24d13_godot_jolt_braking_mechanism_activation_physical_supervisor_manifest_v1.json"
$r24d13PhysicalSupervisorPath = Join-Path (
    $sdkRoot
) "run_qsdk_r24d13_braking_mechanism_activation_characterization.ps1"
$r24d13PhysicalSupervisorSourceAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d13_braking_mechanism_activation_physical_supervisor_source.py"
$r24d13PhysicalSupervisorQualificationClosurePath = Join-Path (
    $sdkRoot
) "recovery\r24d13_godot_jolt_braking_mechanism_activation_physical_supervisor_qualification_positive_closure_v1.json"
$r24d13PhysicalAuthorizationPath = Join-Path (
    $sdkRoot
) "recovery\r24d13_godot_jolt_braking_mechanism_activation_physical_authorization_v1.json"
$r24d13PhysicalSupervisorQualificationAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d13_braking_mechanism_activation_physical_supervisor_qualification.py"
$r24d13PhysicalAttemptClosurePath = Join-Path (
    $sdkRoot
) "recovery\r24d13_godot_jolt_braking_mechanism_activation_physical_attempt_closure_v1.json"
$r24d13PhysicalAttemptClosureAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d13_braking_mechanism_activation_physical_attempt_closure.py"
$r24d13PhysicalSupervisorQualificationReceiptPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "qsdk-r24d13-braking-mechanism-activation\physical-supervisor-qualification\" +
    "20260826T232142657Z-12317012-c29272f7b41c\receipt.json"
)
$r24d13FailedDevelopmentReceiptPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "qsdk-r24d13-braking-mechanism-activation\development\" +
    "20260826T225920368Z-5e641f829a8c\development-failure-receipt-v2.json"
)
$r24d13PassingDevelopmentReceiptPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "qsdk-r24d13-braking-mechanism-activation\development\" +
    "20260826T230200899Z-01307724e80d\development-receipt.json"
)
$r24d14PreregistrationPath = Join-Path (
    $sdkRoot
) "recovery\r24d14_godot_native_float_projection_preregistration_v1.json"
$r24d14ValidationManifestPath = Join-Path (
    $sdkRoot
) "recovery\r24d14_godot_native_float_projection_validation_manifest.json"
$r24d14EvaluatorPath = Join-Path (
    $sdkRoot
) "recovery\r24d14_godot_jolt_braking_mechanism_activation_evaluator.py"
$r24d14WorkerPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_sdk_qsdk_r24d14_godot_native_float_projection_worker.gd"
$r24d14QualificationRunnerPath = Join-Path (
    $sdkRoot
) "run_qsdk_r24d14_native_float_projection_qualification.ps1"
$r24d14SourceAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d14_godot_native_float_projection_source.py"
$r24d14QualificationClosurePath = Join-Path (
    $sdkRoot
) "recovery\r24d14_godot_native_float_projection_qualification_positive_closure_v1.json"
$r24d14QualificationClosureAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d14_godot_native_float_projection_qualification_closure.py"
$r24d14QualificationReceiptPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "qsdk-r24d14-native-float-projection\qualification\" +
    "20260827T000809847Z-4f4d9f49-5da8edfa32af\receipt.json"
)
$r24d14PhysicalSupervisorContractPath = Join-Path (
    $sdkRoot
) "recovery\r24d14_godot_jolt_braking_mechanism_activation_physical_supervisor_contract_v1.json"
$r24d14PhysicalSupervisorManifestPath = Join-Path (
    $sdkRoot
) "recovery\r24d14_godot_jolt_braking_mechanism_activation_physical_supervisor_manifest_v1.json"
$r24d14PhysicalEvaluatorPath = Join-Path (
    $sdkRoot
) "recovery\r24d14_godot_jolt_braking_mechanism_activation_physical_evaluator.py"
$r24d14PhysicalWorkerPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_sdk_qsdk_r24d14_godot_jolt_braking_mechanism_activation_worker.gd"
$r24d14PhysicalSupervisorPath = Join-Path (
    $sdkRoot
) "run_qsdk_r24d14_braking_mechanism_activation_characterization.ps1"
$r24d14PhysicalSupervisorSourceAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d14_braking_mechanism_activation_physical_supervisor_source.py"
$r24d14DevelopmentPreflightReceiptPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "qsdk-r24d14-braking-mechanism-activation\development\" +
    "20260827T003554775Z-d939af3a-7b873c8ea594\receipt.json"
)
$r24d14PhysicalSupervisorQualificationReceiptPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "qsdk-r24d14-braking-mechanism-activation\physical-supervisor-qualification\" +
    "20260827T004357759Z-f0f250b9-ec92f7a9f79f\receipt.json"
)
$r24d14PhysicalSupervisorQualificationClosurePath = Join-Path (
    $sdkRoot
) "recovery\r24d14_godot_jolt_braking_mechanism_activation_physical_supervisor_qualification_positive_closure_v1.json"
$r24d14PhysicalAuthorizationPath = Join-Path (
    $sdkRoot
) "recovery\r24d14_godot_jolt_braking_mechanism_activation_physical_authorization_v1.json"
$r24d14PhysicalSupervisorQualificationAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d14_braking_mechanism_activation_physical_supervisor_qualification.py"
$r24d14PhysicalCharacterizationClosurePath = Join-Path (
    $sdkRoot
) "recovery\r24d14_godot_jolt_braking_mechanism_activation_physical_characterization_closure_v1.json"
$r24d14PhysicalCharacterizationClosureAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d14_braking_mechanism_activation_physical_characterization_closure.py"
$r24d14PhysicalReceiptPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "qsdk-r24d14-braking-mechanism-activation\physical\" +
    "20260827T005329324Z-a6be6727-bd015eb4a2ea\receipt.json"
)
$r24d14PhysicalAttemptPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "qsdk-r24d14-braking-mechanism-activation\physical\" +
    "20260827T005329324Z-a6be6727-bd015eb4a2ea\attempt.json"
)
$r24d14PhysicalRawReportPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "qsdk-r24d14-braking-mechanism-activation\physical\" +
    "20260827T005329324Z-a6be6727-bd015eb4a2ea\raw-report.json"
)
$r24d14PhysicalEvaluationPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "qsdk-r24d14-braking-mechanism-activation\physical\" +
    "20260827T005329324Z-a6be6727-bd015eb4a2ea\evaluation.json"
)
$r24d15ProfilePromotionDecisionPath = Join-Path (
    $sdkRoot
) "recovery\r24d15_godot_jolt_instrumented_profile_promotion_decision_v1.json"
$r24d15ProfilePromotionDecisionAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d15_godot_jolt_instrumented_profile_promotion_decision.py"
$r24d16CapabilityContractPath = Join-Path (
    $sdkRoot
) "recovery\r24d16_godot_jolt_profile_scoped_recovery_capability_contract_v1.json"
$r24d16CapabilityMappingPath = Join-Path (
    $sdkRoot
) "adapters\godot\gdscript\recovery_capability_instrumented_v2.gd"
$r24d16CapabilitySourceAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d16_godot_jolt_profile_scoped_recovery_capability_source.py"
$r24d16CapabilityRunnerPath = Join-Path (
    $sdkRoot
) "run_qsdk_r24d16_profile_scoped_recovery_capability_zero_world.ps1"
$r24d16CapabilityWorkerPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_sdk_qsdk_r24d16_godot_profile_scoped_recovery_capability_zero_world.gd"
$r24d16CapabilityClosurePath = Join-Path (
    $sdkRoot
) "recovery\r24d16_godot_jolt_profile_scoped_recovery_capability_qualification_closure_v1.json"
$r24d16CapabilityClosureAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d16_godot_jolt_profile_scoped_recovery_capability_qualification_closure.py"
$r24d16CapabilityReceiptPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "qsdk-r24d16-profile-scoped-recovery-capability\qualification\" +
    "20260827T014757688Z-4ed7ad93-1405c8b1cd40\receipt.json"
)
$r24d17RuntimeContractPath = Join-Path (
    $sdkRoot
) "recovery\r24d17_native_recovery_runtime_and_physical_profile_contract_v1.json"
$r24d17RuntimeSourceAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d17_native_recovery_runtime_source.py"
$r24d17RuntimeRunnerPath = Join-Path (
    $sdkRoot
) "run_qsdk_r24d17_native_recovery_runtime_zero_world.ps1"
$r24d17RuntimeGodotWorkerPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_sdk_qsdk_r24d17_godot_recovery_runtime_zero_world.gd"
$r24d17RuntimeClosurePath = Join-Path (
    $sdkRoot
) "recovery\r24d17_native_recovery_runtime_qualification_closure_v1.json"
$r24d17RuntimeClosureAuditPath = Join-Path (
    (Split-Path -Parent $sdkRoot)
) "tests\test_qsdk_r24d17_native_recovery_runtime_qualification_closure.py"
$r24d17RuntimeReceiptPath = (
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "qsdk-r24d17-qualification-20260827T024026086Z-576e7086\receipt.json"
)
$headingValidationManifestPath = Join-Path (
    $sdkRoot
) "turning\heading_command_validation_manifest.json"
$checkpointPath = Join-Path (
    $sdkRoot
) "release\quadruped_readiness_checkpoint_manifest.json"
$twoStageCheckpointPath = Join-Path (
    $sdkRoot
) "release\quadruped_two_stage_readiness_checkpoint_manifest.json"
$systemTempRoot = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::GetTempPath()
).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
)
$testRoot = Join-Path (
    $systemTempRoot
) (
    "sporespore_quadruped_release_test_" +
    [Guid]::NewGuid().ToString("N")
)
$testRoot = [System.IO.Path]::GetFullPath($testRoot)

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw "ASSERTION FAILED: $Message"
    }
}

function Get-GitBlobIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Commit,
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    Assert-True (
        $Commit -cmatch '^[0-9a-f]{40}$'
    ) "Historical Git commit identity is not a full lowercase object ID"
    $normalizedPath = $RelativePath.Replace('\', '/')
    Assert-True (
        -not [string]::IsNullOrWhiteSpace($normalizedPath) -and
        -not $normalizedPath.StartsWith('/') -and
        -not $normalizedPath.Contains('..')
    ) "Historical Git blob path is unsafe: $RelativePath"

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = "git"
    $startInfo.WorkingDirectory = $repoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $null = $startInfo.ArgumentList.Add("-C")
    $null = $startInfo.ArgumentList.Add($repoRoot)
    $null = $startInfo.ArgumentList.Add("cat-file")
    $null = $startInfo.ArgumentList.Add("blob")
    $null = $startInfo.ArgumentList.Add("${Commit}:$normalizedPath")

    $process = $null
    $stream = $null
    $sha256 = $null
    try {
        $process = [System.Diagnostics.Process]::Start($startInfo)
        Assert-True ($null -ne $process) "Could not start Git blob reader"
        $stream = [System.IO.MemoryStream]::new()
        $process.StandardOutput.BaseStream.CopyTo($stream)
        $standardError = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-True (
            $process.ExitCode -eq 0
        ) "Could not read historical Git blob ${Commit}:$normalizedPath`: $standardError"

        $bytes = $stream.ToArray()
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $digest = $sha256.ComputeHash($bytes)
        return [pscustomobject]@{
            sha256 = "sha256:" + (
                [System.Convert]::ToHexString($digest).ToLowerInvariant()
            )
            byte_length = [long]$bytes.Length
        }
    } finally {
        if ($null -ne $sha256) {
            $sha256.Dispose()
        }
        if ($null -ne $stream) {
            $stream.Dispose()
        }
        if ($null -ne $process) {
            $process.Dispose()
        }
    }
}

function Invoke-ReadinessCompiler {
    param(
        [string]$ContractFile = $contractPath,
        [string]$SupportMatrixFile = $supportMatrixPath,
        [string]$OutputFile = ""
    )
    $arguments = @{
        Contract = $ContractFile
        SupportMatrix = $SupportMatrixFile
    }
    if (-not [string]::IsNullOrWhiteSpace($OutputFile)) {
        $arguments.Output = $OutputFile
    }
    $lines = @(& $compilerPath @arguments 6>$null)
    $prefix = "QUADRUPED_SDK_RELEASE_READINESS "
    $reportLines = @(
        $lines |
            Where-Object {
                $_ -is [string] -and $_.StartsWith(
                    $prefix,
                    [StringComparison]::Ordinal
                )
            }
    )
    Assert-True (
        $reportLines.Count -eq 1
    ) "Expected exactly one readiness report line"
    return (
        $reportLines[0].Substring($prefix.Length) |
            ConvertFrom-Json
    )
}

function Invoke-Sdk1MilestoneCompiler {
    $lines = @(& $sdk1CompilerPath 6>$null)
    $prefix = "QUADRUPED_SDK1_MILESTONE_READINESS "
    $reportLines = @(
        $lines |
            Where-Object {
                $_ -is [string] -and $_.StartsWith(
                    $prefix,
                    [StringComparison]::Ordinal
                )
            }
    )
    Assert-True (
        $reportLines.Count -eq 1
    ) "Expected exactly one SDK1 milestone readiness report line"
    return (
        $reportLines[0].Substring($prefix.Length) |
            ConvertFrom-Json -Depth 100
    )
}

try {
    [void][System.IO.Directory]::CreateDirectory($testRoot)

    Assert-True (
        Test-Path -LiteralPath $headingValidationManifestPath -PathType Leaf
    ) "Heading-command validation manifest is missing"
    $headingValidation = Get-Content `
        -Raw `
        -LiteralPath $headingValidationManifestPath | ConvertFrom-Json
    Assert-True (
        [string]$headingValidation.schema_version -ceq
        "sporespore_heading_command_validation_manifest_v1" -and
        [string]$headingValidation.status -ceq
        "accepted_source_precondition_only_qsdk_r23_still_missing" -and
        [string]$headingValidation.gate_id -ceq "QSDK-R23" -and
        [bool]$headingValidation.source_clean -and
        [bool]$headingValidation.source_matches_origin_main -and
        -not [bool]$headingValidation.release_gate_satisfied -and
        -not [bool]$headingValidation.turning_acceptance -and
        -not [bool]$headingValidation.physical_acceptance_authority
    ) "Heading-command validation authority drifted"
    $headingReportPath = [System.IO.Path]::GetFullPath(
        [string]$headingValidation.report.path
    )
    Assert-True (
        Test-Path -LiteralPath $headingReportPath -PathType Leaf
    ) "Retained heading-command report is missing"
    $headingReportSha256 = "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $headingReportPath
    ).Hash.ToLowerInvariant()
    Assert-True (
        $headingReportSha256 -ceq [string]$headingValidation.report.sha256
    ) "Retained heading-command report digest drifted"
    $headingReport = Get-Content `
        -Raw `
        -LiteralPath $headingReportPath | ConvertFrom-Json
    Assert-True (
        [string]$headingReport.schema_version -ceq
        "sporespore_heading_command_turning_conformance_report_v1" -and
        [bool]$headingReport.ok -and
        [string]$headingReport.source.commit -ceq
        [string]$headingValidation.source_commit -and
        [bool]$headingReport.source.clean -and
        [bool]$headingReport.source.matches_origin_main -and
        [int]$headingReport.passed_cells -eq 9 -and
        [int]$headingReport.failed_cells -eq 0 -and
        [int]$headingReport.descriptor_vertex_count -eq 64 -and
        [int]$headingReport.world_build_count -eq 0 -and
        -not [bool]$headingReport.release_gate_satisfied -and
        -not [bool]$headingReport.turning_acceptance -and
        -not [bool]$headingReport.physical_acceptance_authority
    ) "Retained heading-command report predicates drifted"

    $releaseContractRaw = Get-Content -Raw -LiteralPath $contractPath
    $supportMatrixRaw = Get-Content -Raw -LiteralPath $supportMatrixPath
    $releaseContract = $releaseContractRaw | ConvertFrom-Json
    $supportMatrix = $supportMatrixRaw | ConvertFrom-Json
    $r24d1Design = Get-Content -Raw -LiteralPath $r24d1DesignPath |
        ConvertFrom-Json
    $r24d2Semantics = Get-Content -Raw -LiteralPath $r24d2SemanticsPath |
        ConvertFrom-Json -Depth 100
    $r24d2Manifest = Get-Content -Raw -LiteralPath $r24d2ManifestPath |
        ConvertFrom-Json -Depth 100
    $r24d3Source = Get-Content -Raw -LiteralPath $r24d3SourcePath |
        ConvertFrom-Json -Depth 100
    $r24d3Manifest = Get-Content -Raw -LiteralPath $r24d3ManifestPath |
        ConvertFrom-Json -Depth 100
    $r24d3Adoption = Get-Content -Raw -LiteralPath $r24d3AdoptionPath |
        ConvertFrom-Json -Depth 100
    $r24d3FullColdQualification = Get-Content -Raw `
        -LiteralPath $r24d3FullColdQualificationPath |
        ConvertFrom-Json -Depth 100
    $r24d4Preregistration = Get-Content -Raw `
        -LiteralPath $r24d4PreregistrationPath |
        ConvertFrom-Json -Depth 100
    $r24d4Manifest = Get-Content -Raw -LiteralPath $r24d4ManifestPath |
        ConvertFrom-Json -Depth 100
    $r24d4Closure = Get-Content -Raw -LiteralPath $r24d4ClosurePath |
        ConvertFrom-Json -Depth 100
    $r24d5Preregistration = Get-Content -Raw `
        -LiteralPath $r24d5PreregistrationPath |
        ConvertFrom-Json -Depth 100
    $r24d5Manifest = Get-Content -Raw -LiteralPath $r24d5ManifestPath |
        ConvertFrom-Json -Depth 100
    $r24d5Diagnostics = Get-Content -Raw -LiteralPath $r24d5DiagnosticsPath |
        ConvertFrom-Json -Depth 100
    $r24d5PhysicalClosure = Get-Content -Raw `
        -LiteralPath $r24d5PhysicalClosurePath |
        ConvertFrom-Json -Depth 100
    $r24d6Preregistration = Get-Content -Raw `
        -LiteralPath $r24d6PreregistrationPath |
        ConvertFrom-Json -Depth 100
    $r24d6Manifest = Get-Content -Raw -LiteralPath $r24d6ManifestPath |
        ConvertFrom-Json -Depth 100
    $r24d6Diagnostics = Get-Content -Raw -LiteralPath $r24d6DiagnosticsPath |
        ConvertFrom-Json -Depth 100
    $r24d6FirstQualificationFailure = Get-Content -Raw `
        -LiteralPath $r24d6FirstQualificationFailurePath |
        ConvertFrom-Json -Depth 100
    $r24d6ZeroWorldFailureClosure = Get-Content -Raw `
        -LiteralPath $r24d6ZeroWorldFailureClosurePath |
        ConvertFrom-Json -Depth 100
    $r24d7Preregistration = Get-Content -Raw `
        -LiteralPath $r24d7PreregistrationPath |
        ConvertFrom-Json -Depth 100
    $r24d7Manifest = Get-Content -Raw -LiteralPath $r24d7ManifestPath |
        ConvertFrom-Json -Depth 100
    $r24d7IntegralSchema = Get-Content -Raw `
        -LiteralPath $r24d7IntegralSchemaPath |
        ConvertFrom-Json -Depth 100
    $r24d7Diagnostics = Get-Content -Raw -LiteralPath $r24d7DiagnosticsPath |
        ConvertFrom-Json -Depth 100
    $r24d7PhysicalClosure = Get-Content -Raw `
        -LiteralPath $r24d7PhysicalClosurePath |
        ConvertFrom-Json -Depth 100
    $r24d8Preregistration = Get-Content -Raw `
        -LiteralPath $r24d8PreregistrationPath |
        ConvertFrom-Json -Depth 100
    $r24d8Manifest = Get-Content -Raw -LiteralPath $r24d8ManifestPath |
        ConvertFrom-Json -Depth 100
    $r24d8Diagnostics = Get-Content -Raw -LiteralPath $r24d8DiagnosticsPath |
        ConvertFrom-Json -Depth 100
    $r24d8FirstOfficialFailure = Get-Content -Raw `
        -LiteralPath $r24d8FirstOfficialFailurePath |
        ConvertFrom-Json -Depth 100
    $r24d8MaintenanceDiagnostics = Get-Content -Raw `
        -LiteralPath $r24d8MaintenanceDiagnosticsPath |
        ConvertFrom-Json -Depth 100
    $r24d8PositiveClosure = Get-Content -Raw `
        -LiteralPath $r24d8PositiveClosurePath |
        ConvertFrom-Json -Depth 100
    $r24d8PositiveClosureDiagnostics = Get-Content -Raw `
        -LiteralPath $r24d8PositiveClosureDiagnosticsPath |
        ConvertFrom-Json -Depth 100
    $r24d9Preregistration = Get-Content -Raw `
        -LiteralPath $r24d9PreregistrationPath |
        ConvertFrom-Json -Depth 100
    $r24d9PrecommitDiagnostics = Get-Content -Raw `
        -LiteralPath $r24d9PrecommitDiagnosticsPath |
        ConvertFrom-Json -Depth 100
    $r24d9ValidationManifest = Get-Content -Raw `
        -LiteralPath $r24d9ValidationManifestPath |
        ConvertFrom-Json -Depth 100
    $r24d9PhysicalFailureClosure = Get-Content -Raw `
        -LiteralPath $r24d9PhysicalFailureClosurePath |
        ConvertFrom-Json -Depth 100
    $r24d10ZeroWorldPositiveClosure = Get-Content -Raw `
        -LiteralPath $r24d10ZeroWorldPositiveClosurePath |
        ConvertFrom-Json -Depth 100
    $r24d10PhysicalSupervisorContract = Get-Content -Raw `
        -LiteralPath $r24d10PhysicalSupervisorContractPath |
        ConvertFrom-Json -Depth 100
    $r24d10PhysicalSupervisorManifest = Get-Content -Raw `
        -LiteralPath $r24d10PhysicalSupervisorManifestPath |
        ConvertFrom-Json -Depth 100
    $r24d10FirstSupervisorAdoptionRefusal = Get-Content -Raw `
        -LiteralPath $r24d10FirstSupervisorAdoptionRefusalPath |
        ConvertFrom-Json -Depth 100
    $r24d10PhysicalSupervisorQualificationClosure = Get-Content -Raw `
        -LiteralPath $r24d10PhysicalSupervisorQualificationClosurePath |
        ConvertFrom-Json -Depth 100
    $r24d10PhysicalAuthorization = Get-Content -Raw `
        -LiteralPath $r24d10PhysicalAuthorizationPath |
        ConvertFrom-Json -Depth 100
    $r24d10PhysicalCharacterizationClosure = Get-Content -Raw `
        -LiteralPath $r24d10PhysicalCharacterizationClosurePath |
        ConvertFrom-Json -Depth 100
    $r24d11ProfilePromotionDecision = Get-Content -Raw `
        -LiteralPath $r24d11ProfilePromotionDecisionPath |
        ConvertFrom-Json -Depth 100
    $r24d12Preregistration = Get-Content -Raw `
        -LiteralPath $r24d12PreregistrationPath |
        ConvertFrom-Json -Depth 100
    $r24d12ValidationManifest = Get-Content -Raw `
        -LiteralPath $r24d12ValidationManifestPath |
        ConvertFrom-Json -Depth 100
    $r24d12ZeroWorldPositiveClosure = Get-Content -Raw `
        -LiteralPath $r24d12ZeroWorldPositiveClosurePath |
        ConvertFrom-Json -Depth 100
    $r24d12PhysicalSupervisorQualificationClosure = Get-Content -Raw `
        -LiteralPath $r24d12PhysicalSupervisorQualificationClosurePath |
        ConvertFrom-Json -Depth 100
    $r24d12PhysicalAuthorization = Get-Content -Raw `
        -LiteralPath $r24d12PhysicalAuthorizationPath |
        ConvertFrom-Json -Depth 100
    $r24d12PhysicalAttemptClosure = Get-Content -Raw `
        -LiteralPath $r24d12PhysicalAttemptClosurePath |
        ConvertFrom-Json -Depth 100
    $r24d13PhysicalAttemptClosure = Get-Content -Raw `
        -LiteralPath $r24d13PhysicalAttemptClosurePath |
        ConvertFrom-Json -Depth 100
    $r24d14QualificationClosure = Get-Content -Raw `
        -LiteralPath $r24d14QualificationClosurePath |
        ConvertFrom-Json -Depth 100
    $r24d14PhysicalCharacterizationClosure = Get-Content -Raw `
        -LiteralPath $r24d14PhysicalCharacterizationClosurePath |
        ConvertFrom-Json -Depth 100
    $r24d15ProfilePromotionDecision = Get-Content -Raw `
        -LiteralPath $r24d15ProfilePromotionDecisionPath |
        ConvertFrom-Json -Depth 100
    $r24d16CapabilityContract = Get-Content -Raw `
        -LiteralPath $r24d16CapabilityContractPath |
        ConvertFrom-Json -Depth 100
    $r24d16CapabilityClosure = Get-Content -Raw `
        -LiteralPath $r24d16CapabilityClosurePath |
        ConvertFrom-Json -Depth 100
    $r24d16CapabilityReceipt = Get-Content -Raw `
        -LiteralPath $r24d16CapabilityReceiptPath |
        ConvertFrom-Json -Depth 100
    $r24d17RuntimeContract = Get-Content -Raw `
        -LiteralPath $r24d17RuntimeContractPath |
        ConvertFrom-Json -Depth 100
    $r24d17RuntimeClosure = Get-Content -Raw `
        -LiteralPath $r24d17RuntimeClosurePath |
        ConvertFrom-Json -Depth 100
    $r24d17RuntimeReceipt = Get-Content -Raw `
        -LiteralPath $r24d17RuntimeReceiptPath |
        ConvertFrom-Json -Depth 100
    $r24Gate = @(
        $releaseContract.gates |
            Where-Object { [string]$_.gate_id -ceq "QSDK-R24" }
    )
    Assert-True (
        $r24Gate.Count -eq 1 -and
        [string]$r24Gate[0].proof.kind -ceq "repo_json" -and
        [string]$r24Gate[0].proof.path -ceq
            "sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json" -and
        [string]$r24Gate[0].proof.sha256 -ceq
            "sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f" -and
        [int]$r24Gate[0].proof.predicates.Count -eq 23 -and
        [string]$r24Gate[0].proof.reason_scope -ceq
            "historical_pre_r173_chronology_only_superseded_for_current_disposition_by_the_r24d173_decision" -and
        [string]$r24Gate[0].proof.current_reason -like
            "R24D173 binds the immutable R24D44 MuJoCo*" -and
        [string]$r24Gate[0].proof.current_reason -like
            "*no controller-identity, equivalence, repeatability, population, broad recovery, physical-acceptance, or release claim is made.*"
    ) "QSDK-R24 R173 finite positive proof binding drifted"
    $matrixR24D2 = $supportMatrix.locomotion_modes.canonical_prone_to_standing_design
    Assert-True (
        [string]$matrixR24D2.gate_id -ceq "QSDK-R24D2" -and
        [string]$matrixR24D2.predecessor_gate_id -ceq "QSDK-R24D1" -and
        [string]$matrixR24D2.initial_scope -ceq
            "exact_qsdk_r05_generated_s169_only" -and
        [int]$matrixR24D2.required_native_engines.Count -eq 3 -and
        [int]$matrixR24D2.required_gate_family_count -eq 7 -and
        [int]$matrixR24D2.required_observation_channel_count -eq 10 -and
        [int]$matrixR24D2.ordered_success_phase_count -eq 6 -and
        [int]$matrixR24D2.exact_zero_no_cheat_counter_count -eq 13 -and
        [int]$matrixR24D2.required_negative_control_count -eq 12 -and
        [int]$matrixR24D2.passed_negative_control_count -eq 12 -and
        [int]$matrixR24D2.r24d1_mutation_rejection_count -eq 38 -and
        [bool]$matrixR24D2.portable_observation_schema_implemented -and
        [bool]$matrixR24D2.portable_pose_classifier_implemented -and
        [bool]$matrixR24D2.portable_phase_supervisor_implemented -and
        [bool]$matrixR24D2.portable_result_evaluator_implemented -and
        [bool]$matrixR24D2.adapter_capability_mappings_implemented -and
        [int]$matrixR24D2.godot_supported_channel_count -eq 8 -and
        [int]$matrixR24D2.godot_unsupported_channel_count -eq 2 -and
        -not [bool]$matrixR24D2.native_capability_conjunction_complete -and
        [int]$matrixR24D2.godot_exact_instrumented_profile_supported_channel_count -eq 10 -and
        [int]$matrixR24D2.godot_stock_or_unqualified_supported_channel_count -eq 8 -and
        [bool]$matrixR24D2.godot_profile_scoped_mapping_qualified -and
        [bool]$matrixR24D2.exact_instrumented_profile_native_capability_conjunction_complete -and
        -not [bool]$matrixR24D2.thresholds_and_cohorts_frozen -and
        -not [bool]$matrixR24D2.prone_to_standing -and
        -not [bool]$matrixR24D2.physical_acceptance_authority
    ) "QSDK-R24 support-matrix implementation boundary drifted"
    $releaseR24D3 = $r24Gate[0].proof.active_zero_world_boundary.instrumented_godot_motor_telemetry_source_boundary
    $matrixR24D3 = (
        $matrixR24D2.instrumented_godot_motor_telemetry_source_boundary
    )
    Assert-True (
        [string]$releaseR24D3.gate_id -ceq "QSDK-R24D3" -and
        [string]$releaseR24D3.status -ceq
            "artifact_complete_cold_build_and_post_adoption_full_conformance_qualified_characterization_withheld" -and
        [string]$releaseR24D3.godot_source_commit -ceq
            "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88" -and
        [string]$releaseR24D3.patch_raw_sha256 -ceq
            "sha256:f067543bc6237a38c0c0935a56b3bbebcd318dc6d82cec1321ea5d52e45dae2f" -and
        [int]$releaseR24D3.patched_file_count -eq 7 -and
        [int]$releaseR24D3.receipt_field_count -eq 11 -and
        [int]$releaseR24D3.source_mutation_rejection_count -eq 12 -and
        [bool]$releaseR24D3.source_compile_passed -and
        [bool]$releaseR24D3.zero_world_binding_passed -and
        [int]$releaseR24D3.stock_godot_supported_channel_count -eq 8 -and
        [int]$releaseR24D3.instrumented_source_field_count -eq 10 -and
        [int]$releaseR24D3.cold_build_attempt_count -eq 2 -and
        [string]$releaseR24D3.incomplete_cold_build_receipt_schema -ceq
            "sporespore_qsdk_r24d3_instrumented_zero_world_gate_receipt_v1" -and
        [string]$releaseR24D3.incomplete_cold_build_source_commit -ceq
            "5f01d8ef3babb1132d341ee92f3773e653046d33" -and
        [string]$releaseR24D3.incomplete_cold_build_receipt_raw_sha256 -ceq
            "sha256:6b1c507e07024912d33171f859fc8c0fe5937b00bf67e372a2414dc42fd4b4b1" -and
        -not [bool]$releaseR24D3.incomplete_cold_build_artifact_retention_adequate -and
        -not [bool]$releaseR24D3.artifact_complete_successor_required -and
        [bool]$releaseR24D3.artifact_complete_successor_observed -and
        [string]$releaseR24D3.artifact_complete_successor_receipt_schema -ceq
            "sporespore_qsdk_r24d3_instrumented_zero_world_gate_receipt_v2" -and
        [int]$releaseR24D3.required_retained_binary_count -eq 2 -and
        [string]$releaseR24D3.artifact_complete_source_commit -ceq
            "2ca77925147db4ef381737b17aedc4af723130b4" -and
        [string]$releaseR24D3.artifact_complete_receipt_raw_sha256 -ceq
            "sha256:a72e1c6c5b51799bec46fe76737ea23f9998c0af6778bb52dc0b7ed2cd9f36d9" -and
        [string]$releaseR24D3.artifact_complete_engine_binary_raw_sha256 -ceq
            "sha256:d0bb895b996fa98ec69a68b9f98ca6ed99af2eb18ef67a0b176ad1a55220278d" -and
        [int]$releaseR24D3.retained_binary_count -eq 2 -and
        [bool]$releaseR24D3.artifact_complete_binary_pair_retained -and
        [bool]$releaseR24D3.execution_used_retained_binary_pair -and
        [bool]$releaseR24D3.clean_pushed_cold_build_qualified -and
        [bool]$releaseR24D3.post_adoption_full_cold_conformance_qualified -and
        [string]$releaseR24D3.post_adoption_full_cold_source_commit -ceq
            "e0626fad670e74f1f6b195eb771892e7de054624" -and
        [string]$releaseR24D3.post_adoption_full_cold_receipt_raw_sha256 -ceq
            "sha256:1ab1342391ceaf972500b2221781ce52d2e266cf52ddb0c863f02c52c6c46157" -and
        [string]$releaseR24D3.post_adoption_full_cold_attestation_raw_sha256 -ceq
            "sha256:15692faad3f5fdd20d4a8c32fbf650457120a90e398c41208d00374bc7ccfcff" -and
        [int]$releaseR24D3.post_adoption_full_cold_stage_count -eq 8 -and
        -not [bool]$releaseR24D3.post_adoption_full_cold_result_reused -and
        -not [bool]$releaseR24D3.post_adoption_full_cold_physical_campaign_executed -and
        -not [bool]$releaseR24D3.reproducible_build_claimed -and
        -not [bool]$releaseR24D3.result_reuse_authority -and
        -not [bool]$releaseR24D3.instrumented_native_sign_characterized -and
        -not [bool]$releaseR24D3.instrumented_work_energy_characterized -and
        -not [bool]$releaseR24D3.stock_godot_capability_promoted -and
        -not [bool]$releaseR24D3.instrumented_godot_capability_promoted -and
        -not [bool]$releaseR24D3.native_capability_conjunction_complete -and
        [int]$releaseR24D3.world_build_count -eq 0 -and
        -not [bool]$releaseR24D3.q_sdk_r24_satisfied -and
        -not [bool]$releaseR24D3.release_authority -and
        [string]$matrixR24D3.gate_id -ceq [string]$releaseR24D3.gate_id -and
        [string]$matrixR24D3.status -ceq [string]$releaseR24D3.status -and
        [string]$matrixR24D3.patch_raw_sha256 -ceq
            [string]$releaseR24D3.patch_raw_sha256 -and
        -not [bool]$matrixR24D3.instrumented_godot_capability_promoted
    ) "QSDK-R24D3 source candidate was promoted beyond its evidence."
    $releaseR24D4 = (
        $releaseR24D3.prospective_one_hinge_telemetry_characterization_boundary
    )
    $matrixR24D4 = (
        $matrixR24D3.prospective_one_hinge_telemetry_characterization_boundary
    )
    Assert-True (
        ($releaseR24D4 | ConvertTo-Json -Depth 100 -Compress) -ceq
            ($matrixR24D4 | ConvertTo-Json -Depth 100 -Compress) -and
        [string]$releaseR24D4.gate_id -ceq "QSDK-R24D4" -and
        [string]$releaseR24D4.work_id -ceq
            "QSDK-R24D4-GODOT-JOLT-ONE-HINGE-TELEMETRY-CHARACTERIZATION" -and
        [string]$releaseR24D4.question_class -ceq "development" -and
        [string]$releaseR24D4.status -ceq
            "valid_zero_world_negative_source_oracle_axis_mismatch" -and
        [string]$releaseR24D4.closure_path -ceq
            "sdk/recovery/r24d4_godot_jolt_one_hinge_telemetry_zero_world_failure_closure_v1.json" -and
        [string]$releaseR24D4.closure_raw_sha256 -ceq
            "sha256:07b64a61e85269f71030e999b9dfa23e5802b918e9765dbc4003e6449612747f" -and
        [string]$releaseR24D4.source_commit -ceq
            "6e24a729bac03e02cf247583f5e321040b4b011a" -and
        [int]$releaseR24D4.retained_zero_world_file_count -eq 11 -and
        [int]$releaseR24D4.content_addressed_zero_world_file_count -eq 11 -and
        (@($releaseR24D4.pre_registered_axis_parent_local) -join ",") -ceq
            "0,0,1" -and
        (@($releaseR24D4.frozen_evaluator_expected_axis_parent_local) -join ",") -ceq
            "0,0,-1" -and
        [bool]$releaseR24D4.failure_preceded_world_construction -and
        [bool]$releaseR24D4.same_source_physical_open_forbidden -and
        -not [bool]$releaseR24D4.same_source_rerun_allowed -and
        [string]$releaseR24D4.required_successor_gate_id -ceq "QSDK-R24D5" -and
        [string]$releaseR24D4.parent_gate_id -ceq "QSDK-R24D3" -and
        [string]$releaseR24D4.runtime_profile_id -ceq
            "godot_4_7_jolt_sporespore_motor_telemetry_v1" -and
        [string]$releaseR24D4.console_binary_raw_sha256 -ceq
            "sha256:762ed7137d06284742b53abdde9b98c692ab1e8d3a184458db4d8e7a39782462" -and
        [string]$releaseR24D4.engine_binary_raw_sha256 -ceq
            "sha256:d0bb895b996fa98ec69a68b9f98ca6ed99af2eb18ef67a0b176ad1a55220278d" -and
        [int]$releaseR24D4.source_binding_count -eq 7 -and
        [int]$releaseR24D4.fixture_world_count -eq 1 -and
        [int]$releaseR24D4.fixture_cell_count -eq 9 -and
        [int]$releaseR24D4.retained_sample_count -eq 68 -and
        [int]$releaseR24D4.evaluator_negative_control_count -eq 22 -and
        [int]$releaseR24D4.accepted_outcome_mutation_count -eq 2 -and
        [int]$releaseR24D4.contract_mutation_rejection_count -eq 12 -and
        [int]$releaseR24D4.empirical_acceptance_threshold_count -eq 0 -and
        [int]$releaseR24D4.superiority_margin_count -eq 0 -and
        [int]$releaseR24D4.equivalence_or_non_inferiority_margin_count -eq 0 -and
        [int]$releaseR24D4.validation_cohort_identity_count -eq 0 -and
        [int]$releaseR24D4.population_claim_count -eq 0 -and
        -not [bool]$releaseR24D4.complete_zero_world_gate_passed -and
        -not [bool]$releaseR24D4.physical_characterization_executed -and
        -not [bool]$releaseR24D4.native_sign_characterized -and
        -not [bool]$releaseR24D4.native_impulse_cap_characterized -and
        -not [bool]$releaseR24D4.native_work_energy_characterized -and
        -not [bool]$releaseR24D4.native_limit_separation_characterized -and
        -not [bool]$releaseR24D4.native_motor_disabled_zero_characterized -and
        -not [bool]$releaseR24D4.native_refusal_and_freshness_characterized -and
        -not [bool]$releaseR24D4.instrumented_profile_promoted -and
        -not [bool]$releaseR24D4.stock_godot_profile_promoted -and
        [int]$releaseR24D4.world_attempt_count -eq 0 -and
        [int]$releaseR24D4.world_build_count -eq 0 -and
        [int]$releaseR24D4.solver_step_count -eq 0 -and
        -not [bool]$releaseR24D4.recovery_world_opened -and
        -not [bool]$releaseR24D4.prone_to_standing_world_opened -and
        -not [bool]$releaseR24D4.q_sdk_r24_satisfied -and
        -not [bool]$releaseR24D4.physical_acceptance_authority -and
        -not [bool]$releaseR24D4.release_authority
    ) "QSDK-R24D4 zero-world negative boundary drifted."
    $releaseR24D5 = $releaseR24D4.prospective_axis_consistent_successor_boundary
    $matrixR24D5 = $matrixR24D4.prospective_axis_consistent_successor_boundary
    Assert-True (
        ($releaseR24D5 | ConvertTo-Json -Depth 100 -Compress) -ceq
            ($matrixR24D5 | ConvertTo-Json -Depth 100 -Compress) -and
        [string]$releaseR24D5.gate_id -ceq "QSDK-R24D5" -and
        [string]$releaseR24D5.question_class -ceq "development" -and
        [string]$releaseR24D5.status -ceq
            "closed_consumed_invalid_after_worker_execution_fixture_json_identity_mismatch_distinct_successor_required" -and
        [string]$releaseR24D5.predecessor_gate_id -ceq "QSDK-R24D4" -and
        [string]$releaseR24D5.source_commit -ceq
            "fffb773b408b0cf8bb4a3ba78e773b62c3a0e52a" -and
        [int]$releaseR24D5.source_binding_count -eq 10 -and
        [int]$releaseR24D5.declared_fixture_world_count -eq 1 -and
        [int]$releaseR24D5.fixture_cell_count -eq 9 -and
        [int]$releaseR24D5.retained_sample_count -eq 68 -and
        (@($releaseR24D5.hinge_axis_parent_local) -join ",") -ceq "0,0,1" -and
        (@(
            $releaseR24D5.child_inertia_default_json_stringify_diagonal_kg_m2
        ) -join ",") -ceq
            "0.0500000007450581,0.0500000007450581,0.0500000007450581" -and
        @(
            $releaseR24D5.child_inertia_physical_full_precision_json_diagonal_kg_m2
        ).Count -eq 3 -and
        [regex]::Matches(
            $releaseContractRaw,
            '"child_inertia_physical_full_precision_json_diagonal_kg_m2"\s*:\s*\[\s*' +
                '0\.05000000074505806\s*,\s*0\.05000000074505806\s*,\s*' +
                '0\.05000000074505806\s*\]'
        ).Count -eq 1 -and
        [regex]::Matches(
            $supportMatrixRaw,
            '"child_inertia_physical_full_precision_json_diagonal_kg_m2"\s*:\s*\[\s*' +
                '0\.05000000074505806\s*,\s*0\.05000000074505806\s*,\s*' +
                '0\.05000000074505806\s*\]'
        ).Count -eq 1 -and
        [int]$releaseR24D5.evaluator_negative_control_count -eq 24 -and
        [int]$releaseR24D5.accepted_outcome_mutation_count -eq 2 -and
        [int]$releaseR24D5.contract_mutation_rejection_count -eq 14 -and
        [int]$releaseR24D5.precommit_diagnostic_attempt_count -eq 4 -and
        [int]$releaseR24D5.official_zero_world_qualification_count -eq 1 -and
        [string]$releaseR24D5.official_zero_world_receipt_raw_sha256 -ceq
            "sha256:607aae658fcac12fd92e0997e763780b9791e54e27f5a416aa66671477e74749" -and
        [int]$releaseR24D5.empirical_acceptance_threshold_count -eq 0 -and
        [int]$releaseR24D5.validation_cohort_identity_count -eq 0 -and
        [bool]$releaseR24D5.complete_zero_world_gate_passed -and
        -not [bool]$releaseR24D5.zero_world_gate_adequate_for_physical_full_precision_serialization_identity -and
        -not [bool]$releaseR24D5.physical_authorization_permitted_now -and
        -not [bool]$releaseR24D5.physical_characterization_executed -and
        [bool]$releaseR24D5.physical_worker_execution_completed -and
        -not [bool]$releaseR24D5.physical_result_valid -and
        [int]$releaseR24D5.evaluator_exit_code -eq 2 -and
        [string]$releaseR24D5.evaluator_terminal_error -ceq
            "QSDK_R24D5_EVALUATION_ERROR fixture_inertia_representation" -and
        -not [bool]$releaseR24D5.instrumented_profile_promoted -and
        [bool]$releaseR24D5.scientifically_distinct_successor_required -and
        [bool]$releaseR24D5.prospective_successor_declared -and
        [int]$releaseR24D5.world_attempt_count -eq 1 -and
        [int]$releaseR24D5.world_build_count -eq 1 -and
        [int]$releaseR24D5.solver_step_count -eq 20 -and
        -not [bool]$releaseR24D5.prone_to_standing_world_opened -and
        -not [bool]$releaseR24D5.q_sdk_r24_satisfied -and
        -not [bool]$releaseR24D5.physical_acceptance_authority -and
        -not [bool]$releaseR24D5.release_authority -and
        [string]$releaseR24D5.physical_failure_closure_path -ceq
            "sdk/recovery/r24d5_godot_jolt_one_hinge_telemetry_physical_failure_closure_v1.json" -and
        [string]$releaseR24D5.physical_failure_closure_raw_sha256 -ceq
            "sha256:d6cf0c9c2aa65e4310d02f5681fb4ba91bd62ae56f215b8417703fbd9ecb1719" -and
        [string]$releaseR24D5.physical_failure_closure_audit_path -ceq
            "tests/test_qsdk_r24d5_one_hinge_telemetry_physical_failure_closure.ps1" -and
        [string]$releaseR24D5.physical_failure_closure_audit_raw_sha256 -ceq
            "sha256:6c0fb1c60488820e264000ba82a7219582a6160ea1caad3dc9a62f803df0876d"
    ) "QSDK-R24D5 consumed invalid characterization boundary drifted."
    $releaseR24D6 =
        $releaseR24D5.prospective_serialized_envelope_successor_boundary
    $matrixR24D6 =
        $matrixR24D5.prospective_serialized_envelope_successor_boundary
    Assert-True (
        ($releaseR24D6 | ConvertTo-Json -Depth 100 -Compress) -ceq
            ($matrixR24D6 | ConvertTo-Json -Depth 100 -Compress) -and
        [string]$releaseR24D6.gate_id -ceq "QSDK-R24D6" -and
        [string]$releaseR24D6.question_class -ceq "development" -and
        [string]$releaseR24D6.status -ceq
            "closed_valid_zero_world_negative_integral_variant_type_loss_distinct_successor_required_physical_execution_forbidden" -and
        [string]$releaseR24D6.predecessor_gate_id -ceq "QSDK-R24D5" -and
        [string]$releaseR24D6.source_commit -ceq
            "55032839756cc8a9089a2a4eb4e06db71ab99ca4" -and
        [bool]$releaseR24D6.source_frozen_and_pushed -and
        [int]$releaseR24D6.source_binding_count -eq 11 -and
        [int]$releaseR24D6.pinned_godot_numeric_source_file_count -eq 5 -and
        [int]$releaseR24D6.declared_fixture_world_count -eq 1 -and
        [int]$releaseR24D6.fixture_cell_count -eq 9 -and
        [int]$releaseR24D6.retained_sample_count -eq 68 -and
        (@($releaseR24D6.hinge_axis_parent_local) -join ",") -ceq "0,0,1" -and
        @(
            $releaseR24D6.child_inertia_real_t_full_precision_json_diagonal_kg_m2
        ).Count -eq 3 -and
        [regex]::Matches(
            $releaseContractRaw,
            '"child_inertia_real_t_full_precision_json_diagonal_kg_m2"\s*:\s*\[\s*' +
                '0\.05000000074505806\s*,\s*0\.05000000074505806\s*,\s*' +
                '0\.05000000074505806\s*\]'
        ).Count -eq 1 -and
        [regex]::Matches(
            $supportMatrixRaw,
            '"child_inertia_real_t_full_precision_json_diagonal_kg_m2"\s*:\s*\[\s*' +
                '0\.05000000074505806\s*,\s*0\.05000000074505806\s*,\s*' +
                '0\.05000000074505806\s*\]'
        ).Count -eq 1 -and
        (@(
            $releaseR24D6.child_inertia_default_precision_negative_control_diagonal_kg_m2
        ) -join ",") -ceq
            "0.0500000007450581,0.0500000007450581,0.0500000007450581" -and
        [int]$releaseR24D6.evaluator_negative_control_count -eq 29 -and
        [int]$releaseR24D6.accepted_outcome_mutation_count -eq 2 -and
        [int]$releaseR24D6.contract_mutation_rejection_count -eq 18 -and
        [int]$releaseR24D6.binary32_projection_control_count -eq 5 -and
        [int]$releaseR24D6.serialized_runtime_negative_control_count -eq 1 -and
        [int]$releaseR24D6.synthetic_full_precision_envelope_evaluation_count -eq 1 -and
        [int]$releaseR24D6.precommit_parser_attempt_count -eq 2 -and
        [int]$releaseR24D6.precommit_parser_negative_count -eq 1 -and
        [int]$releaseR24D6.precommit_parser_pass_count -eq 1 -and
        [string]$releaseR24D6.first_official_zero_world_qualification_failure_path -ceq
            "sdk/recovery/r24d6_first_official_zero_world_qualification_failure_v1.json" -and
        [int]$releaseR24D6.first_official_zero_world_qualification_failure_count -eq 1 -and
        [string]$releaseR24D6.first_official_zero_world_qualification_failure_source_commit -ceq
            "ef540fa50ce9d155aa5d78bbef04070b62dc0a76" -and
        [string]$releaseR24D6.first_official_zero_world_qualification_failure_status -ceq
            "incomplete_static_dependency_manifest_drift_before_worker_launch" -and
        [int]$releaseR24D6.first_official_zero_world_attempted_static_stage_count -eq 3 -and
        [int]$releaseR24D6.first_official_zero_world_passed_static_stage_count -eq 2 -and
        [int]$releaseR24D6.first_official_zero_world_failed_static_stage_count -eq 1 -and
        [int]$releaseR24D6.first_official_zero_world_worker_launch_count -eq 0 -and
        [int]$releaseR24D6.first_official_zero_world_godot_process_launch_count -eq 0 -and
        [int]$releaseR24D6.first_official_zero_world_real_evaluator_envelope_invocation_count -eq 0 -and
        [int]$releaseR24D6.first_official_zero_world_world_attempt_count -eq 0 -and
        [int]$releaseR24D6.official_zero_world_attempt_count -eq 2 -and
        [int]$releaseR24D6.official_zero_world_valid_negative_count -eq 1 -and
        [int]$releaseR24D6.official_zero_world_qualification_count -eq 0 -and
        $null -eq $releaseR24D6.official_zero_world_receipt_path -and
        [string]$releaseR24D6.second_official_zero_world_source_commit -ceq
            "55032839756cc8a9089a2a4eb4e06db71ab99ca4" -and
        [string]$releaseR24D6.second_official_zero_world_status -ceq
            "valid_zero_world_negative_full_precision_integral_variant_type_loss" -and
        [int]$releaseR24D6.second_official_zero_world_static_stage_pass_count -eq 5 -and
        [int]$releaseR24D6.second_official_zero_world_worker_launch_count -eq 1 -and
        [int]$releaseR24D6.second_official_zero_world_godot_process_launch_count -eq 1 -and
        [int]$releaseR24D6.second_official_zero_world_serializer_call_count -eq 2 -and
        [int]$releaseR24D6.second_official_zero_world_real_evaluator_envelope_invocation_count -eq 2 -and
        [int]$releaseR24D6.second_official_zero_world_default_precision_evaluator_exit_code -eq 2 -and
        [string]$releaseR24D6.second_official_zero_world_default_precision_terminal_error -ceq
            "QSDK_R24D6_EVALUATION_ERROR fixture_inertia_representation" -and
        [int]$releaseR24D6.second_official_zero_world_full_precision_evaluator_exit_code -eq 2 -and
        [string]$releaseR24D6.second_official_zero_world_full_precision_terminal_error -ceq
            "QSDK_R24D6_EVALUATION_ERROR fixture_collision_layer" -and
        [int]$releaseR24D6.second_official_zero_world_integer_to_double_projection_count -eq 313 -and
        [int]$releaseR24D6.second_official_zero_world_integer_to_double_normalized_path_count -eq 21 -and
        [int]$releaseR24D6.second_official_zero_world_strict_integer_projection_count -eq 234 -and
        [int]$releaseR24D6.second_official_zero_world_strict_integer_normalized_path_count -eq 9 -and
        [int]$releaseR24D6.second_official_zero_world_retained_file_count -eq 18 -and
        [int]$releaseR24D6.second_official_zero_world_retained_unique_digest_count -eq 17 -and
        [bool]$releaseR24D6.same_source_zero_world_rerun_forbidden -and
        [bool]$releaseR24D6.same_source_physical_open_forbidden -and
        [bool]$releaseR24D6.scientifically_distinct_successor_required -and
        [string]$releaseR24D6.zero_world_failure_closure_path -ceq
            "sdk/recovery/r24d6_godot_jolt_one_hinge_telemetry_zero_world_failure_closure_v1.json" -and
        [string]$releaseR24D6.zero_world_failure_closure_raw_sha256 -ceq
            "sha256:7873aa69926c464f1b93a98516c314a742a43cb16b7fa71b8b908fd00b06f229" -and
        [string]$releaseR24D6.zero_world_failure_closure_audit_path -ceq
            "tests/test_qsdk_r24d6_one_hinge_telemetry_zero_world_failure_closure.ps1" -and
        [string]$releaseR24D6.zero_world_failure_closure_audit_raw_sha256 -ceq
            "sha256:48d150501785de227ce1a1097efe20e6b952f6759b77d34a3f8df1da6e09851a" -and
        [int]$releaseR24D6.empirical_acceptance_threshold_count -eq 0 -and
        [int]$releaseR24D6.superiority_margin_count -eq 0 -and
        [int]$releaseR24D6.equivalence_or_non_inferiority_margin_count -eq 0 -and
        [int]$releaseR24D6.validation_cohort_identity_count -eq 0 -and
        [int]$releaseR24D6.population_claim_count -eq 0 -and
        -not [bool]$releaseR24D6.complete_zero_world_gate_passed -and
        -not [bool]$releaseR24D6.serialized_full_precision_envelope_zero_world_qualified -and
        [bool]$releaseR24D6.default_precision_negative_control_passed -and
        -not [bool]$releaseR24D6.full_precision_positive_control_passed -and
        [int]$releaseR24D6.actual_world_attempt_count -eq 0 -and
        [int]$releaseR24D6.actual_world_build_count -eq 0 -and
        [int]$releaseR24D6.actual_solver_step_count -eq 0 -and
        -not [bool]$releaseR24D6.physical_authorization_permitted_now -and
        -not [bool]$releaseR24D6.physical_characterization_executed -and
        -not [bool]$releaseR24D6.instrumented_profile_promoted -and
        -not [bool]$releaseR24D6.recovery_world_opened -and
        -not [bool]$releaseR24D6.prone_to_standing_world_opened -and
        -not [bool]$releaseR24D6.turning_claim_changed -and
        -not [bool]$releaseR24D6.q_sdk_r24_satisfied -and
        -not [bool]$releaseR24D6.physical_acceptance_authority -and
        -not [bool]$releaseR24D6.release_authority -and
        [bool]$releaseR24D6.prospective_successor_declared
    ) "QSDK-R24D6 prospective serialized-envelope boundary drifted."
    $releaseR24D7 = $releaseR24D6.distinct_integral_variant_successor_boundary
    $matrixR24D7 = $matrixR24D6.distinct_integral_variant_successor_boundary
    Assert-True (
        ($releaseR24D7 | ConvertTo-Json -Depth 100 -Compress) -ceq
            ($matrixR24D7 | ConvertTo-Json -Depth 100 -Compress) -and
        [string]$releaseR24D7.gate_id -ceq "QSDK-R24D7" -and
        [string]$releaseR24D7.work_id -ceq
            "QSDK-R24D7-GODOT-JOLT-ONE-HINGE-TELEMETRY-CHARACTERIZATION" -and
        [string]$releaseR24D7.question_class -ceq "development" -and
        [string]$releaseR24D7.status -ceq
            "closed_zero_world_qualified_physical_attempt_implementation_invalid_callback_outside_stepping_window_distinct_successor_required" -and
        [string]$releaseR24D7.predecessor_gate_id -ceq "QSDK-R24D6" -and
        [string]$releaseR24D7.predecessor_closure_raw_sha256 -ceq
            "sha256:7873aa69926c464f1b93a98516c314a742a43cb16b7fa71b8b908fd00b06f229" -and
        [string]$releaseR24D7.predecessor_closure_audit_raw_sha256 -ceq
            "sha256:48d150501785de227ce1a1097efe20e6b952f6759b77d34a3f8df1da6e09851a" -and
        [string]$releaseR24D7.source_commit -ceq
            "ab6e763e466db86ea1d6fea6b72a23a68ff63587" -and
        [bool]$releaseR24D7.source_frozen_and_pushed -and
        [int]$releaseR24D7.source_binding_count -eq 11 -and
        [int]$releaseR24D7.declared_fixture_world_count -eq 1 -and
        [int]$releaseR24D7.fixture_cell_count -eq 9 -and
        [int]$releaseR24D7.retained_sample_count -eq 68 -and
        [int]$releaseR24D7.declared_integral_variant_path_family_count -eq 21 -and
        [int]$releaseR24D7.declared_integral_variant_occurrence_count -eq 313 -and
        [int]$releaseR24D7.predecessor_strict_integral_path_family_count -eq 9 -and
        [int]$releaseR24D7.predecessor_strict_integral_occurrence_count -eq 234 -and
        [int]$releaseR24D7.inherited_evaluator_negative_control_count -eq 29 -and
        [int]$releaseR24D7.integral_family_type_loss_negative_control_count -eq 21 -and
        [int]$releaseR24D7.total_evaluator_negative_control_count -eq 50 -and
        [int]$releaseR24D7.accepted_outcome_mutation_count -eq 2 -and
        [int]$releaseR24D7.contract_mutation_rejection_count -eq 22 -and
        [int]$releaseR24D7.precommit_parser_attempt_count -eq 1 -and
        [int]$releaseR24D7.precommit_parser_negative_count -eq 0 -and
        [int]$releaseR24D7.precommit_parser_pass_count -eq 1 -and
        [int]$releaseR24D7.official_zero_world_attempt_count -eq 1 -and
        [int]$releaseR24D7.official_zero_world_qualification_count -eq 1 -and
        [string]$releaseR24D7.official_zero_world_receipt_raw_sha256 -ceq
            "sha256:1ac77255e6441c6b3e68dbabf8ee5adc3b5d49e0c9a1257b0b8bce2454f75862" -and
        [int]$releaseR24D7.official_zero_world_retained_file_count -eq 21 -and
        [int]$releaseR24D7.official_zero_world_retained_unique_digest_count -eq 20 -and
        [int]$releaseR24D7.official_physical_attempt_count -eq 1 -and
        [int]$releaseR24D7.official_physical_valid_characterization_count -eq 0 -and
        [int]$releaseR24D7.official_physical_invalid_result_count -eq 1 -and
        [int]$releaseR24D7.physical_attempt_evaluator_exit_code -eq 2 -and
        [string]$releaseR24D7.physical_attempt_evaluator_terminal_error -ceq
            "QSDK_R24D7_EVALUATION_ERROR sample_drive_positive_1_unsafe_read_not_refused" -and
        [int]$releaseR24D7.physical_attempt_retained_file_count -eq 27 -and
        [int]$releaseR24D7.physical_attempt_retained_unique_digest_count -eq 24 -and
        [int]$releaseR24D7.integrate_forces_callback_attempt_count -eq 65 -and
        [int]$releaseR24D7.integrate_forces_callback_refusal_count -eq 0 -and
        -not [bool]$releaseR24D7.timing_control_realized -and
        -not [bool]$releaseR24D7.native_active_step_read_safety_established -and
        [int]$releaseR24D7.empirical_acceptance_threshold_count -eq 0 -and
        [int]$releaseR24D7.superiority_margin_count -eq 0 -and
        [int]$releaseR24D7.equivalence_or_non_inferiority_margin_count -eq 0 -and
        [int]$releaseR24D7.validation_cohort_identity_count -eq 0 -and
        [int]$releaseR24D7.population_claim_count -eq 0 -and
        [bool]$releaseR24D7.complete_zero_world_gate_passed -and
        [bool]$releaseR24D7.serialized_full_precision_envelope_zero_world_qualified -and
        [int]$releaseR24D7.actual_world_attempt_count -eq 1 -and
        [int]$releaseR24D7.actual_world_build_count -eq 1 -and
        [int]$releaseR24D7.actual_solver_step_count -eq 20 -and
        -not [bool]$releaseR24D7.physical_authorization_permitted_now -and
        [bool]$releaseR24D7.physical_world_executed -and
        [bool]$releaseR24D7.physical_worker_report_completed -and
        -not [bool]$releaseR24D7.physical_result_valid -and
        -not [bool]$releaseR24D7.physical_characterization_executed -and
        -not [bool]$releaseR24D7.native_telemetry_characterized -and
        -not [bool]$releaseR24D7.instrumented_profile_promoted -and
        -not [bool]$releaseR24D7.recovery_world_opened -and
        -not [bool]$releaseR24D7.prone_to_standing_world_opened -and
        -not [bool]$releaseR24D7.turning_claim_changed -and
        -not [bool]$releaseR24D7.q_sdk_r24_satisfied -and
        -not [bool]$releaseR24D7.physical_acceptance_authority -and
        -not [bool]$releaseR24D7.release_authority
    ) "QSDK-R24D7 closed integral-Variant/timing-control boundary drifted."
    Assert-True (
        [string]$releaseR24D7.physical_failure_closure_path -ceq
            "sdk/recovery/r24d7_godot_jolt_one_hinge_telemetry_physical_failure_closure_v1.json" -and
        [string]$releaseR24D7.physical_failure_closure_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d7PhysicalClosurePath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D7.physical_failure_closure_audit_path -ceq
            "tests/test_qsdk_r24d7_one_hinge_telemetry_physical_failure_closure.ps1" -and
        [string]$releaseR24D7.physical_failure_closure_audit_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d7PhysicalClosureAuditPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$r24d7PhysicalClosure.schema_version -ceq
            "sporespore_qsdk_r24d7_one_hinge_telemetry_physical_failure_closure_v1" -and
        [string]$r24d7PhysicalClosure.result_class -ceq
            "invalid_development_result_no_characterization" -and
        [bool]$r24d7PhysicalClosure.claims.complete_zero_world_gate_passed -and
        -not [bool]$r24d7PhysicalClosure.claims.valid_descriptive_development_characterization -and
        -not [bool]$r24d7PhysicalClosure.claims.native_read_during_active_step_safety_established -and
        -not [bool]$r24d7PhysicalClosure.claims.prone_to_standing_world_opened -and
        -not [bool]$r24d7PhysicalClosure.claims.release_authority
    ) "QSDK-R24D7 physical failure closure binding drifted."
    $releaseR24D8 =
        $releaseR24D7.prospective_active_step_snapshot_successor_boundary
    $matrixR24D8 =
        $matrixR24D7.prospective_active_step_snapshot_successor_boundary
    Assert-True (
        [bool]$releaseR24D7.prospective_successor_declared -and
        ($releaseR24D8 | ConvertTo-Json -Depth 100 -Compress) -ceq
            ($matrixR24D8 | ConvertTo-Json -Depth 100 -Compress) -and
        [string]$releaseR24D8.gate_id -ceq "QSDK-R24D8" -and
        [string]$releaseR24D8.work_id -ceq
            "QSDK-R24D8-GODOT-JOLT-ACTIVE-STEP-SNAPSHOT-TIMING" -and
        [string]$releaseR24D8.question_class -ceq "development" -and
        [string]$releaseR24D8.status -ceq
            "historical_positive_closure_preserved_later_step_token_audit_found_exact_eight_step_contract_violation_no_valid_campaign_authority" -and
        [string]$releaseR24D8.result_class -ceq
            "subsequently_disqualified_implementation_invalid_development_result" -and
        [string]$releaseR24D8.historical_closure_status -ceq
            "closed_finite_native_active_step_snapshot_timing_positive_distinct_full_numerical_characterization_pending_recovery_and_prone_to_standing_not_opened" -and
        [string]$releaseR24D8.historical_closure_result_class -ceq
            "valid_finite_descriptive_development_timing_result" -and
        [string]$releaseR24D8.predecessor_gate_id -ceq "QSDK-R24D7" -and
        [string]$releaseR24D8.godot_source_commit -ceq
            "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88" -and
        [string]$releaseR24D8.runtime_profile_id -ceq
            "godot_4_7_jolt_sporespore_motor_telemetry_active_step_snapshot_v2" -and
        [string]$releaseR24D8.first_official_zero_world_source_commit -ceq
            "49c643dec947088bffbec4703c3fe076b9768a9f" -and
        [string]$releaseR24D8.first_official_zero_world_source_tree_git_oid -ceq
            "9e3c0a6fa1934bd26a027ec5ee2e77c3039c4d51" -and
        [bool]$releaseR24D8.first_official_zero_world_source_frozen_and_pushed -and
        -not [bool]$releaseR24D8.first_official_zero_world_same_source_rerun_allowed -and
        [string]$releaseR24D8.sporespore_source_commit -ceq
            "b17a6677e711625061726279a1b0287c57fa82ec" -and
        [string]$releaseR24D8.sporespore_source_tree_git_oid -ceq
            "6902d1cb7076e01192c3065074809897a64246c4" -and
        [bool]$releaseR24D8.source_frozen_and_pushed -and
        [int]$releaseR24D8.source_binding_count -eq 15 -and
        [int]$releaseR24D8.patched_file_count -eq 10 -and
        [int]$releaseR24D8.telemetry_receipt_field_count -eq 15 -and
        [int]$releaseR24D8.contract_mutation_rejection_count -eq 18 -and
        [int]$releaseR24D8.source_mutation_rejection_count -eq 17 -and
        [int]$releaseR24D8.evaluator_negative_control_count -eq 25 -and
        [int]$releaseR24D8.accepted_surprising_outcome_count -eq 2 -and
        [int]$releaseR24D8.precommit_diagnostic_attempt_count -eq 3 -and
        [int]$releaseR24D8.maintenance_precommit_attempt_count -eq 6 -and
        [int]$releaseR24D8.maintenance_precommit_negative_count -eq 5 -and
        [int]$releaseR24D8.maintenance_precommit_positive_count -eq 1 -and
        [int]$releaseR24D8.first_official_failure_mutation_rejection_count -eq 8 -and
        [int]$releaseR24D8.maintenance_diagnostic_mutation_rejection_count -eq 7 -and
        [int]$releaseR24D8.predecessor_compatibility_source_mutation_rejection_count -eq 14 -and
        [int]$releaseR24D8.positive_closure_mutation_rejection_count -eq 39 -and
        [int]$releaseR24D8.positive_closure_diagnostic_attempt_count -eq 5 -and
        [int]$releaseR24D8.positive_closure_diagnostic_negative_count -eq 4 -and
        [int]$releaseR24D8.positive_closure_diagnostic_positive_count -eq 1 -and
        [int]$releaseR24D8.positive_closure_diagnostic_mutation_rejection_count -eq 7 -and
        [int]$releaseR24D8.official_zero_world_attempt_count -eq 2 -and
        [int]$releaseR24D8.official_zero_world_incomplete_count -eq 1 -and
        [int]$releaseR24D8.official_zero_world_qualification_count -eq 1 -and
        [int]$releaseR24D8.first_official_zero_world_retained_file_count -eq 2 -and
        [int]$releaseR24D8.first_official_zero_world_retained_unique_digest_count -eq 2 -and
        [int]$releaseR24D8.first_official_zero_world_cold_build_count -eq 0 -and
        [int]$releaseR24D8.first_official_zero_world_worker_launch_count -eq 0 -and
        [string]$releaseR24D8.qualification_zero_world_receipt_raw_sha256 -ceq
            "sha256:f89f37b077e329c57fde787ddd4adae307dc7ead033b6f896b9497d764014855" -and
        [int]$releaseR24D8.qualification_zero_world_retained_file_count -eq 17 -and
        [int]$releaseR24D8.qualification_zero_world_retained_unique_digest_count -eq 16 -and
        [int]$releaseR24D8.qualification_zero_world_static_stage_count -eq 5 -and
        [int]$releaseR24D8.qualification_zero_world_static_stage_pass_count -eq 5 -and
        [int]$releaseR24D8.qualification_zero_world_cold_build_count -eq 1 -and
        [int]$releaseR24D8.qualification_zero_world_worker_launch_count -eq 1 -and
        [int]$releaseR24D8.qualification_zero_world_world_attempt_count -eq 0 -and
        [int]$releaseR24D8.qualification_zero_world_world_build_count -eq 0 -and
        [int]$releaseR24D8.qualification_zero_world_solver_step_count -eq 0 -and
        [int]$releaseR24D8.declared_fixture_world_count -eq 1 -and
        [int]$releaseR24D8.maximum_physics_step_count -eq 8 -and
        [int]$releaseR24D8.fresh_active_sample_count -eq 4 -and
        [int]$releaseR24D8.sleeping_stale_sample_count -eq 4 -and
        [int]$releaseR24D8.retained_sample_count -eq 8 -and
        [int]$releaseR24D8.pre_sample_physics_frame_count -eq 1 -and
        [int]$releaseR24D8.terminal_physics_server_deactivation_count -eq 1 -and
        [int]$releaseR24D8.empirical_acceptance_threshold_count -eq 0 -and
        [int]$releaseR24D8.superiority_margin_count -eq 0 -and
        [int]$releaseR24D8.equivalence_or_non_inferiority_margin_count -eq 0 -and
        [int]$releaseR24D8.validation_cohort_identity_count -eq 0 -and
        [int]$releaseR24D8.population_claim_count -eq 0 -and
        [bool]$releaseR24D8.complete_zero_world_gate_passed -and
        -not [bool]$releaseR24D8.physical_authorization_permitted_now -and
        [bool]$releaseR24D8.physical_timing_question_executed -and
        [string]$releaseR24D8.physical_result -ceq
            "finite_native_active_step_snapshot_timing_positive" -and
        [string]$releaseR24D8.physical_receipt_raw_sha256 -ceq
            "sha256:a4bf658df837eaa991aa4421cbba1398949d1267558c738d5c5eb930800d886b" -and
        [int]$releaseR24D8.physical_retained_file_count -eq 13 -and
        [int]$releaseR24D8.physical_retained_unique_digest_count -eq 12 -and
        [int]$releaseR24D8.cross_run_unique_digest_count -eq 24 -and
        [int]$releaseR24D8.actual_world_attempt_count -eq 1 -and
        [int]$releaseR24D8.actual_world_build_count -eq 1 -and
        [int]$releaseR24D8.historical_closure_reported_solver_step_count -eq 8 -and
        [int]$releaseR24D8.actual_solver_step_count -eq 9 -and
        [int]$releaseR24D8.unretained_post_activation_solver_step_count -eq 1 -and
        -not [bool]$releaseR24D8.declared_exact_step_contract_satisfied -and
        [int]$releaseR24D8.actual_sample_count -eq 8 -and
        (@($releaseR24D8.fresh_telemetry_sequences) -join ",") -ceq "2,3,4,5" -and
        (@($releaseR24D8.fresh_capture_space_step_sequences) -join ",") -ceq "2,3,4,5" -and
        (@($releaseR24D8.fresh_read_space_step_sequences) -join ",") -ceq "2,3,4,5" -and
        (@($releaseR24D8.sleeping_telemetry_sequences) -join ",") -ceq "5,5,5,5" -and
        (@($releaseR24D8.sleeping_capture_space_step_sequences) -join ",") -ceq "5,5,5,5" -and
        (@($releaseR24D8.sleeping_read_space_step_sequences) -join ",") -ceq "6,7,8,9" -and
        [bool]$releaseR24D8.active_step_capture_observed_physically -and
        [bool]$releaseR24D8.sleeping_stale_preservation_observed_physically -and
        [bool]$releaseR24D8.observed_current_and_stale_snapshot_tokens_preserved -and
        -not [bool]$releaseR24D8.valid_finite_descriptive_development_timing_result -and
        -not [bool]$releaseR24D8.native_active_step_snapshot_timing_established_for_exact_fixture -and
        -not [bool]$releaseR24D8.sleeping_stale_snapshot_preservation_established_for_exact_fixture -and
        -not [bool]$releaseR24D8.native_numerical_telemetry_characterized -and
        -not [bool]$releaseR24D8.numerical_accuracy_or_telemetry_values_accepted -and
        -not [bool]$releaseR24D8.instrumented_profile_promoted -and
        -not [bool]$releaseR24D8.recovery_world_opened -and
        -not [bool]$releaseR24D8.prone_to_standing_world_opened -and
        -not [bool]$releaseR24D8.turning_claim_changed -and
        -not [bool]$releaseR24D8.cross_engine_equivalence_claimed -and
        [string]$releaseR24D8.next_work -ceq
            "distinct_prospectively_frozen_exact_step_scheduled_one_hinge_numerical_telemetry_characterization" -and
        [string]$releaseR24D8.next_question_class -ceq "development" -and
        -not [bool]$releaseR24D8.next_declaration_authorized -and
        -not [bool]$releaseR24D8.next_physical_execution_authorized -and
        -not [bool]$releaseR24D8.q_sdk_r24_satisfied -and
        -not [bool]$releaseR24D8.physical_acceptance_authority -and
        -not [bool]$releaseR24D8.release_authority
    ) "QSDK-R24D8 preserved historical closure and later validity correction drifted."
    Assert-True (
        [string]$releaseR24D8.preregistration_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d8PreregistrationPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D8.validation_manifest_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d8ManifestPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D8.precommit_diagnostics_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d8DiagnosticsPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D8.first_official_zero_world_failure_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d8FirstOfficialFailurePath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D8.maintenance_precommit_diagnostics_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d8MaintenanceDiagnosticsPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D8.positive_closure_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d8PositiveClosurePath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D8.positive_closure_diagnostics_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d8PositiveClosureDiagnosticsPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D8.positive_closure_audit_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d8PositiveClosureAuditPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D8.subsequent_step_count_correction_path -ceq
            "sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_physical_failure_closure_v1.json" -and
        [string]$releaseR24D8.subsequent_step_count_correction_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d9PhysicalFailureClosurePath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        -not [bool]$releaseR24D8.historical_positive_closure_rewritten -and
        [string]$releaseR24D8.combined_patch_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d8CombinedPatchPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D8.freeze_audit_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d8FreezeAuditPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D8.predecessor_compatibility_audit_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d8PredecessorCompatibilityAuditPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$r24d8Preregistration.gate_id -ceq "QSDK-R24D8" -and
        [string]$r24d8Preregistration.question_class -ceq "development" -and
        [int]$r24d8Preregistration.finite_physical_question.world_count -eq 1 -and
        [int]$r24d8Preregistration.finite_physical_question.maximum_physics_step_count -eq 8 -and
        [int]$r24d8Preregistration.exact_structural_evaluation.empirical_acceptance_threshold_count -eq 0 -and
        -not [bool]$r24d8Preregistration.claims.complete_zero_world_gate_passed -and
        -not [bool]$r24d8Preregistration.claims.physical_timing_question_executed -and
        -not [bool]$r24d8Preregistration.claims.release_authority -and
        [string]$r24d8Manifest.gate_id -ceq "QSDK-R24D8" -and
        [string]$r24d8Manifest.status -ceq
            "prospective_maintenance_source_bytes_bound_after_one_incomplete_official_zero_world_attempt_official_zero_world_pending" -and
        [int]$r24d8Manifest.source_binding_count -eq 15 -and
        [int]$r24d8Manifest.first_official_zero_world_attempt_count -eq 1 -and
        [int]$r24d8Manifest.first_official_zero_world_incomplete_count -eq 1 -and
        [int]$r24d8Manifest.maintenance_precommit_attempt_count -eq 6 -and
        [int]$r24d8Manifest.official_zero_world_qualification_count -eq 0 -and
        [int]$r24d8Manifest.world_attempt_count -eq 0 -and
        [int]$r24d8Manifest.world_build_count -eq 0 -and
        [int]$r24d8Manifest.solver_step_count -eq 0 -and
        -not [bool]$r24d8Manifest.physical_timing_question_executed -and
        -not [bool]$r24d8Manifest.release_authority -and
        [int]$r24d8Diagnostics.finite_counts.diagnostic_attempt_count -eq 3 -and
        [int]$r24d8Diagnostics.finite_counts.runtime_freeze_negative_count -eq 1 -and
        [int]$r24d8Diagnostics.finite_counts.synthetic_zero_world_pass_count -eq 1 -and
        [int]$r24d8Diagnostics.finite_counts.parser_pass_count -eq 1 -and
        [int]$r24d8Diagnostics.finite_counts.world_attempt_count -eq 0 -and
        [int]$r24d8Diagnostics.finite_counts.world_build_count -eq 0 -and
        [int]$r24d8Diagnostics.finite_counts.solver_step_count -eq 0 -and
        -not [bool]$r24d8Diagnostics.claims.complete_zero_world_gate_passed -and
        -not [bool]$r24d8Diagnostics.claims.release_authority -and
        [string]$r24d8FirstOfficialFailure.status -ceq
            "closed_incomplete_predecessor_live_source_audit_mismatch_before_cold_build_or_worker" -and
        [int]$r24d8FirstOfficialFailure.attempt.attempted_stage_count -eq 1 -and
        [int]$r24d8FirstOfficialFailure.attempt.cold_build_launch_count -eq 0 -and
        [int]$r24d8FirstOfficialFailure.attempt.worker_launch_count -eq 0 -and
        [int]$r24d8FirstOfficialFailure.attempt.world_attempt_count -eq 0 -and
        -not [bool]$r24d8FirstOfficialFailure.claims.complete_zero_world_gate_passed -and
        [int]$r24d8MaintenanceDiagnostics.attempt_count -eq 6 -and
        [int]$r24d8MaintenanceDiagnostics.negative_attempt_count -eq 5 -and
        [int]$r24d8MaintenanceDiagnostics.passing_attempt_count -eq 1 -and
        [int]$r24d8MaintenanceDiagnostics.actual_counts.world_attempt_count -eq 0 -and
        -not [bool]$r24d8MaintenanceDiagnostics.claims.release_authority -and
        [string]$r24d8PositiveClosure.status -ceq
            "zero_world_passed_physical_timing_positive_exact_finite_active_and_sleeping_semantics" -and
        [string]$r24d8PositiveClosure.source.commit -ceq
            "b17a6677e711625061726279a1b0287c57fa82ec" -and
        [int]$r24d8PositiveClosure.prerequisite_zero_world.world_attempt_count -eq 0 -and
        [int]$r24d8PositiveClosure.physical_attempt.world_attempt_count -eq 1 -and
        [int]$r24d8PositiveClosure.physical_attempt.world_build_count -eq 1 -and
        [int]$r24d8PositiveClosure.physical_attempt.solver_step_count -eq 8 -and
        [int]$r24d8PositiveClosure.physical_attempt.retained_sample_count -eq 8 -and
        [bool]$r24d8PositiveClosure.claims.native_active_step_snapshot_timing_established_for_exact_fixture -and
        -not [bool]$r24d8PositiveClosure.claims.native_numerical_telemetry_characterized -and
        -not [bool]$r24d8PositiveClosure.claims.prone_to_standing_world_opened -and
        -not [bool]$r24d8PositiveClosure.claims.release_authority -and
        [int]$r24d8PositiveClosureDiagnostics.attempt_count -eq 5 -and
        [int]$r24d8PositiveClosureDiagnostics.negative_attempt_count -eq 4 -and
        [int]$r24d8PositiveClosureDiagnostics.passing_attempt_count -eq 1 -and
        [int]$r24d8PositiveClosureDiagnostics.actual_counts.world_attempt_count -eq 0
    ) "QSDK-R24D8 source lineage or positive closure binding drifted."
    $releaseR24D9 =
        $releaseR24D8.prospective_numerical_telemetry_successor_boundary
    $matrixR24D9 =
        $matrixR24D8.prospective_numerical_telemetry_successor_boundary
    Assert-True (
        [bool]$releaseR24D8.prospective_numerical_telemetry_successor_declared -and
        ($releaseR24D9 | ConvertTo-Json -Depth 100 -Compress) -ceq
            ($matrixR24D9 | ConvertTo-Json -Depth 100 -Compress) -and
        [string]$releaseR24D9.gate_id -ceq "QSDK-R24D9" -and
        [string]$releaseR24D9.work_id -ceq
            "QSDK-R24D9-GODOT-JOLT-ONE-HINGE-NUMERICAL-TELEMETRY-CHARACTERIZATION" -and
        [string]$releaseR24D9.question_class -ceq "development" -and
        [string]$releaseR24D9.status -ceq
            "zero_world_passed_physical_attempt_implementation_invalid_extra_unretained_post_activation_solver_step_closed_no_characterization" -and
        [string]$releaseR24D9.predecessor_gate_id -ceq "QSDK-R24D8" -and
        [string]$releaseR24D9.authorization_closure_publication_commit -ceq
            "4088881d92ea335c1cb70ff42e15abe5bf5d42c5" -and
        [string]$releaseR24D9.runtime_profile_id -ceq
            "godot_4_7_jolt_sporespore_motor_telemetry_active_step_snapshot_v2" -and
        [string]$releaseR24D9.godot_source_commit -ceq
            "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88" -and
        [string]$releaseR24D9.cell_design_source_gate_id -ceq "QSDK-R24D7" -and
        [int]$releaseR24D9.declared_fixture_world_count -eq 1 -and
        [int]$releaseR24D9.isolated_cell_count -eq 9 -and
        [int]$releaseR24D9.maximum_physics_step_count -eq 20 -and
        [int]$releaseR24D9.retained_sample_count -eq 68 -and
        [int]$releaseR24D9.required_raw_measurement_count_per_sample -eq 23 -and
        [int]$releaseR24D9.declared_evaluator_negative_control_count -eq 46 -and
        [int]$releaseR24D9.declaration_mutation_rejection_count -eq 33 -and
        [int]$releaseR24D9.empirical_acceptance_threshold_count -eq 0 -and
        [int]$releaseR24D9.superiority_margin_count -eq 0 -and
        [int]$releaseR24D9.equivalence_or_non_inferiority_margin_count -eq 0 -and
        [int]$releaseR24D9.held_out_validation_cohort_count -eq 0 -and
        [int]$releaseR24D9.population_claim_count -eq 0 -and
        [int]$releaseR24D9.source_derived_hard_configuration_bound_count -eq 1 -and
        [int]$releaseR24D9.implementation_source_file_count_at_declaration -eq 0 -and
        [int]$releaseR24D9.implementation_source_file_count_at_implementation_freeze -eq 7 -and
        [int]$releaseR24D9.validation_manifest_source_binding_count -eq 15 -and
        [int]$releaseR24D9.evaluator_negative_control_rejection_count -eq 46 -and
        [int]$releaseR24D9.accepted_adverse_finite_descriptive_outcome_mutation_count -eq 3 -and
        [int]$releaseR24D9.source_mutation_rejection_count -eq 20 -and
        [int]$releaseR24D9.precommit_diagnostic_attempt_count -eq 5 -and
        [int]$releaseR24D9.precommit_diagnostic_negative_count -eq 4 -and
        [int]$releaseR24D9.precommit_diagnostic_compatibility_pass_count -eq 1 -and
        [int]$releaseR24D9.precommit_diagnostic_retained_file_count -eq 40 -and
        [bool]$releaseR24D9.implementation_complete -and
        [bool]$releaseR24D9.precommit_freeze_passed -and
        -not [bool]$releaseR24D9.prospective_implementation_source_freeze_pending -and
        -not [bool]$releaseR24D9.official_zero_world_qualification_pending -and
        [bool]$releaseR24D9.complete_zero_world_gate_passed -and
        [int]$releaseR24D9.zero_world_retained_file_count -eq 21 -and
        [int]$releaseR24D9.zero_world_unique_content_digest_count -eq 18 -and
        [int]$releaseR24D9.physical_retained_file_count -eq 14 -and
        [int]$releaseR24D9.physical_unique_content_digest_count -eq 13 -and
        [int]$releaseR24D9.cross_run_unique_content_digest_count -eq 27 -and
        [int]$releaseR24D9.world_attempt_count -eq 1 -and
        [int]$releaseR24D9.world_build_count -eq 1 -and
        [int]$releaseR24D9.reported_solver_step_count -eq 20 -and
        [int]$releaseR24D9.solver_step_count -eq 21 -and
        [int]$releaseR24D9.retained_sample_count_observed -eq 68 -and
        [int]$releaseR24D9.unretained_post_activation_solver_step_count -eq 1 -and
        -not [bool]$releaseR24D9.physical_execution_forbidden_until_complete_zero_world_and_clean_pushed_freeze -and
        [bool]$releaseR24D9.same_source_physical_execution_forbidden -and
        -not [bool]$releaseR24D9.physical_execution_authorized -and
        [bool]$releaseR24D9.physical_execution_performed -and
        [bool]$releaseR24D9.immutable_attempt_and_evaluator_reported_valid -and
        -not [bool]$releaseR24D9.posthoc_execution_validity_audit_passed -and
        -not [bool]$releaseR24D9.declared_initial_state_preserved_until_first_retained_sample -and
        -not [bool]$releaseR24D9.r24d8_parent_exact_step_contract_satisfied -and
        -not [bool]$releaseR24D9.r24d8_parent_authorization_adequate_for_r24d9_physical_execution -and
        -not [bool]$releaseR24D9.native_numerical_telemetry_characterized -and
        -not [bool]$releaseR24D9.numerical_accuracy_or_telemetry_values_accepted -and
        -not [bool]$releaseR24D9.instrumented_profile_promoted -and
        -not [bool]$releaseR24D9.recovery_world_opened -and
        -not [bool]$releaseR24D9.prone_to_standing_world_opened -and
        -not [bool]$releaseR24D9.turning_claim_changed -and
        -not [bool]$releaseR24D9.cross_engine_equivalence_claimed -and
        [string]$releaseR24D9.next_gate_id -ceq "QSDK-R24D10" -and
        [string]$releaseR24D9.next_question_class -ceq "development" -and
        [string]$releaseR24D9.next_work -ceq
            "r24d10_closed_valid_finite_descriptive_native_exact_step_characterization_distinct_profile_promotion_decision_declaration_next" -and
        -not [bool]$releaseR24D9.q_sdk_r24_satisfied -and
        -not [bool]$releaseR24D9.physical_acceptance_authority -and
        -not [bool]$releaseR24D9.release_authority
    ) "QSDK-R24D9 consumed invalid numerical-telemetry closure boundary drifted."
    Assert-True (
        [string]$releaseR24D9.authorization_closure_path -ceq
            "sdk/recovery/r24d8_godot_jolt_active_step_snapshot_timing_positive_closure_v1.json" -and
        [string]$releaseR24D9.authorization_closure_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d8PositiveClosurePath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D9.preregistration_path -ceq
            "sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_characterization_preregistration_v1.json" -and
        [string]$releaseR24D9.preregistration_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d9PreregistrationPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D9.declaration_audit_path -ceq
            "tests/test_qsdk_r24d9_numerical_telemetry_preregistration.ps1" -and
        [string]$releaseR24D9.declaration_audit_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d9DeclarationAuditPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D9.precommit_diagnostics_path -ceq
            "sdk/recovery/r24d9_precommit_zero_world_diagnostics_v1.json" -and
        [string]$releaseR24D9.precommit_diagnostics_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d9PrecommitDiagnosticsPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D9.validation_manifest_path -ceq
            "sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_validation_manifest.json" -and
        [string]$releaseR24D9.validation_manifest_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d9ValidationManifestPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D9.freeze_audit_path -ceq
            "tests/test_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_freeze.ps1" -and
        [string]$releaseR24D9.freeze_audit_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d9FreezeAuditPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D9.supervisor_path -ceq
            "sdk/run_qsdk_r24d9_one_hinge_numerical_telemetry_characterization.ps1" -and
        [string]$releaseR24D9.supervisor_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d9SupervisorPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D9.physical_failure_closure_path -ceq
            "sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_physical_failure_closure_v1.json" -and
        [string]$releaseR24D9.physical_failure_closure_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d9PhysicalFailureClosurePath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D9.physical_failure_closure_audit_path -ceq
            "tests/test_qsdk_r24d9_one_hinge_numerical_telemetry_physical_failure_closure.ps1" -and
        [string]$releaseR24D9.physical_failure_closure_audit_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d9PhysicalFailureClosureAuditPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D9.zero_world_receipt_raw_sha256 -ceq
            "sha256:c0aacb88def170019585c81563e4f1c92e20d003cabc75fdba3260518d7cc64c" -and
        [string]$releaseR24D9.physical_attempt_raw_sha256 -ceq
            "sha256:e652a5ae759e829b39d74a66a26bed93d23f8c46ed74cca2d53bb1f3bf6dae25" -and
        [string]$releaseR24D9.physical_raw_report_raw_sha256 -ceq
            "sha256:c34158a59dfb4f932fa74373d8893cccfc96008bb46578dfbf61da5ce07804d8" -and
        [string]$releaseR24D9.physical_evaluation_raw_sha256 -ceq
            "sha256:f60d1c188077accaaabd90e057aa3f1189bdb70260ff6e0a1c25bbdc857cf909" -and
        [string]$releaseR24D9.physical_receipt_raw_sha256 -ceq
            "sha256:db5070bb486695c2ca4aff0ec85bc847986ff0f0946eaaa1d189bcf943c4646a" -and
        [string]$releaseR24D9.combined_patch_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d8CombinedPatchPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$r24d9Preregistration.gate_id -ceq "QSDK-R24D9" -and
        [string]$r24d9Preregistration.question_class -ceq "development" -and
        [int]$r24d9Preregistration.fixture_freeze.world_count -eq 1 -and
        [int]$r24d9Preregistration.fixture_freeze.isolated_cell_count -eq 9 -and
        [int]$r24d9Preregistration.fixture_freeze.maximum_physics_step_count -eq 20 -and
        [int]$r24d9Preregistration.fixture_freeze.retained_sample_count -eq 68 -and
        [int]$r24d9Preregistration.negative_controls.declared_count -eq 46 -and
        -not [bool]$r24d9Preregistration.implementation_state_at_declaration.rig_implemented -and
        -not [bool]$r24d9Preregistration.implementation_state_at_declaration.evaluator_implemented -and
        -not [bool]$r24d9Preregistration.implementation_state_at_declaration.complete_zero_world_gate_implemented -and
        -not [bool]$r24d9Preregistration.physical_authorization.permitted_now -and
        -not [bool]$r24d9Preregistration.claims.complete_zero_world_gate_passed -and
        -not [bool]$r24d9Preregistration.claims.native_numerical_telemetry_characterized -and
        -not [bool]$r24d9Preregistration.claims.prone_to_standing_world_opened -and
        -not [bool]$r24d9Preregistration.claims.release_authority
    ) "QSDK-R24D9 declaration artifact binding drifted."
    Assert-True (
        [string]$r24d9PhysicalFailureClosure.schema_version -ceq
            "sporespore_qsdk_r24d9_one_hinge_numerical_telemetry_physical_failure_closure_v1" -and
        [string]$r24d9PhysicalFailureClosure.closure_id -ceq
            "QSDK-R24D9-PH1-CLOSURE" -and
        [string]$r24d9PhysicalFailureClosure.question_class -ceq
            "development" -and
        [string]$r24d9PhysicalFailureClosure.result_class -ceq
            "invalid_development_result_no_native_numerical_characterization" -and
        [bool]$r24d9PhysicalFailureClosure.claims.complete_zero_world_gate_passed -and
        [bool]$r24d9PhysicalFailureClosure.claims.physical_world_executed -and
        [bool]$r24d9PhysicalFailureClosure.claims.frozen_evaluator_completed_and_reported_valid -and
        -not [bool]$r24d9PhysicalFailureClosure.claims.posthoc_execution_validity_audit_passed -and
        -not [bool]$r24d9PhysicalFailureClosure.claims.valid_descriptive_development_characterization -and
        -not [bool]$r24d9PhysicalFailureClosure.claims.native_numerical_telemetry_characterized -and
        -not [bool]$r24d9PhysicalFailureClosure.claims.prone_to_standing_world_opened -and
        -not [bool]$r24d9PhysicalFailureClosure.claims.release_authority -and
        [int]$r24d9PhysicalFailureClosure.diagnosis.declared_maximum_physics_step_count -eq 20 -and
        [int]$r24d9PhysicalFailureClosure.diagnosis.observed_exact_jolt_space_step_count -eq 21 -and
        [int]$r24d9PhysicalFailureClosure.diagnosis.unretained_post_activation_solver_step_count -eq 1 -and
        -not [bool]$r24d9PhysicalFailureClosure.diagnosis.step_count_contract_satisfied -and
        -not [bool]$r24d9PhysicalFailureClosure.diagnosis.declared_initial_rate_state_preserved_until_first_retained_pre_rate -and
        [int]$r24d9PhysicalFailureClosure.parent_authorization_correction.parent_preregistration_declared_exact_jolt_space_step_count -eq 8 -and
        [int]$r24d9PhysicalFailureClosure.parent_authorization_correction.parent_observed_exact_jolt_space_step_count -eq 9 -and
        -not [bool]$r24d9PhysicalFailureClosure.parent_authorization_correction.parent_exact_step_contract_satisfied -and
        -not [bool]$r24d9PhysicalFailureClosure.parent_authorization_correction.parent_authorization_was_adequate_for_r24d9_physical_execution
    ) "QSDK-R24D9 physical failure closure binding drifted."
    Assert-True (
        [string]$r24d9PrecommitDiagnostics.gate_id -ceq "QSDK-R24D9" -and
        [string]$r24d9PrecommitDiagnostics.question_class -ceq
            "non_physical_development_diagnostic" -and
        [int]$r24d9PrecommitDiagnostics.finite_counts.diagnostic_attempt_count -eq 5 -and
        [int]$r24d9PrecommitDiagnostics.finite_counts.strict_serialization_negative_count -eq 3 -and
        [int]$r24d9PrecommitDiagnostics.finite_counts.synthetic_zero_world_compatibility_pass_count -eq 1 -and
        [int]$r24d9PrecommitDiagnostics.finite_counts.retained_file_count -eq 40 -and
        [int]$r24d9PrecommitDiagnostics.finite_counts.world_attempt_count -eq 0 -and
        [int]$r24d9PrecommitDiagnostics.finite_counts.world_build_count -eq 0 -and
        [int]$r24d9PrecommitDiagnostics.finite_counts.solver_step_count -eq 0 -and
        -not [bool]$r24d9PrecommitDiagnostics.claims.complete_zero_world_gate_passed -and
        [string]$r24d9ValidationManifest.gate_id -ceq "QSDK-R24D9" -and
        [int]$r24d9ValidationManifest.source_binding_count -eq 15 -and
        [int]$r24d9ValidationManifest.declared_evaluator_negative_control_count -eq 46 -and
        [int]$r24d9ValidationManifest.official_zero_world_qualification_count -eq 0 -and
        [int]$r24d9ValidationManifest.world_attempt_count -eq 0 -and
        [int]$r24d9ValidationManifest.world_build_count -eq 0 -and
        [int]$r24d9ValidationManifest.solver_step_count -eq 0 -and
        -not [bool]$r24d9ValidationManifest.physical_acceptance_authority -and
        -not [bool]$r24d9ValidationManifest.release_authority
    ) "QSDK-R24D9 implementation freeze boundary drifted."
    $releaseR24D10 = $releaseR24D9.exact_step_successor_boundary
    $matrixR24D10 = $matrixR24D9.exact_step_successor_boundary
    Assert-True (
        ($releaseR24D10 | ConvertTo-Json -Depth 100 -Compress) -ceq
            ($matrixR24D10 | ConvertTo-Json -Depth 100 -Compress) -and
        [string]$releaseR24D10.gate_id -ceq "QSDK-R24D10" -and
        [string]$releaseR24D10.work_id -ceq
            "QSDK-R24D10-GODOT-JOLT-EXACT-STEP-NUMERICAL-TELEMETRY-CHARACTERIZATION" -and
        [string]$releaseR24D10.question_class -ceq "development" -and
        [string]$releaseR24D10.status -ceq
            "complete_valid_finite_descriptive_native_exact_step_characterization_r24d11_profile_promotion_refused_r24d12_and_r24d13_consumed_invalid_r24d14_required" -and
        [string]$releaseR24D10.current_next_work -ceq
            "r24d14_native_projection_qualified_distinct_physical_supervisor_source_required" -and
        [string]$releaseR24D10.predecessor_closure_path -ceq
            "sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_physical_failure_closure_v1.json" -and
        [string]$releaseR24D10.predecessor_closure_raw_sha256 -ceq
            "sha256:ef054432bf3aa15673a49c9765a3221ffd337c2becb9ba96f1951c81f87b4fde" -and
        [string]$releaseR24D10.source_commit -ceq
            "9d2f8d59834c7cb9bf8271d0a10b3c2edcef7d22" -and
        [string]$releaseR24D10.source_tree_git_oid -ceq
            "60fd3bb03bedc032211e275d4bf995beafeae8c5" -and
        [string]$releaseR24D10.zero_world_positive_closure_path -ceq
            "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_zero_world_positive_closure_v1.json" -and
        [string]$releaseR24D10.zero_world_positive_closure_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d10ZeroWorldPositiveClosurePath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D10.zero_world_positive_closure_audit_path -ceq
            "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_zero_world_positive_closure.ps1" -and
        [string]$releaseR24D10.zero_world_positive_closure_audit_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d10ZeroWorldPositiveClosureAuditPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D10.zero_world_positive_closure_audit_implementation_path -ceq
            "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_zero_world_positive_closure.py" -and
        [string]$releaseR24D10.zero_world_positive_closure_audit_implementation_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d10ZeroWorldPositiveClosureImplementationPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D10.physical_supervisor_contract_path -ceq
            "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_physical_supervisor_contract_v2.json" -and
        [string]$releaseR24D10.physical_supervisor_contract_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d10PhysicalSupervisorContractPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D10.physical_supervisor_manifest_path -ceq
            "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_physical_supervisor_manifest_v2.json" -and
        [string]$releaseR24D10.physical_supervisor_manifest_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d10PhysicalSupervisorManifestPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D10.physical_supervisor_path -ceq
            "sdk/run_qsdk_r24d10_exact_step_numerical_telemetry_characterization.ps1" -and
        [string]$releaseR24D10.physical_supervisor_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d10PhysicalSupervisorPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D10.physical_supervisor_source_audit_path -ceq
            "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_physical_supervisor_source_v2.py" -and
        [string]$releaseR24D10.physical_supervisor_source_audit_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d10PhysicalSupervisorSourceAuditPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D10.physical_supervisor_generation -ceq
            "v2_parent_bound_authorization_transition" -and
        [int]$releaseR24D10.physical_supervisor_source_binding_count -eq 19 -and
        [int]$releaseR24D10.physical_supervisor_source_mutation_rejection_count -eq 17 -and
        [int]$releaseR24D10.physical_supervisor_declared_preflight_stage_count -eq 7 -and
        [bool]$releaseR24D10.physical_authorization_only_check_supported -and
        [bool]$releaseR24D10.physical_supervisor_preflight_passed -and
        [string]$releaseR24D10.v2_physical_supervisor_source_commit -ceq
            "b2bccdb76041a46a5d51ba56129f014e6c0dbf95" -and
        [string]$releaseR24D10.v2_physical_supervisor_source_tree_git_oid -ceq
            "3e19ff30cb1a07dbee60f32fe35b8e6f6ac0050d" -and
        [string]$releaseR24D10.physical_supervisor_qualification.receipt_raw_sha256 -ceq
            "sha256:a260a3c1a883487e5615fd1de82d8d6b05a5deefbf484bf82e266b4a73412cd7" -and
        [int]$releaseR24D10.physical_supervisor_qualification.receipt_byte_length -eq 91463 -and
        [string]$releaseR24D10.physical_supervisor_qualification.closure_path -ceq
            "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_physical_supervisor_qualification_positive_closure_v2.json" -and
        [string]$releaseR24D10.physical_supervisor_qualification.closure_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d10PhysicalSupervisorQualificationClosurePath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D10.physical_supervisor_qualification.closure_audit_path -ceq
            "tests/test_qsdk_r24d10_physical_supervisor_qualification_positive_closure_v2.py" -and
        [string]$releaseR24D10.physical_supervisor_qualification.closure_audit_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d10PhysicalSupervisorQualificationClosureAuditPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [int]$releaseR24D10.physical_supervisor_qualification.stage_count -eq 7 -and
        [int]$releaseR24D10.physical_supervisor_qualification.retained_file_count -eq 21 -and
        [int]$releaseR24D10.physical_supervisor_qualification.retained_unique_content_digest_count -eq 17 -and
        [int]$releaseR24D10.physical_supervisor_qualification.embedded_cas_reference_count -eq 14 -and
        [int]$releaseR24D10.physical_supervisor_qualification.embedded_unique_cas_digest_count -eq 11 -and
        [int]$releaseR24D10.physical_supervisor_qualification.world_attempt_count -eq 0 -and
        [int]$releaseR24D10.physical_supervisor_qualification.world_build_count -eq 0 -and
        [int]$releaseR24D10.physical_supervisor_qualification.solver_step_count -eq 0 -and
        [bool]$releaseR24D10.physical_supervisor_qualification.preflight_passed -and
        -not [bool]$releaseR24D10.physical_supervisor_qualification.physical_authority -and
        [string]$releaseR24D10.physical_authorization.path -ceq
            "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_physical_authorization_v2.json" -and
        [string]$releaseR24D10.physical_authorization.raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d10PhysicalAuthorizationPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D10.physical_authorization.authorization_parent_commit -ceq
            "b2bccdb76041a46a5d51ba56129f014e6c0dbf95" -and
        [bool]$releaseR24D10.physical_authorization.authorization_commit_derived_from_current_head -and
        -not [bool]$releaseR24D10.physical_authorization.authorization_json_contains_self_commit_identity -and
        [bool]$releaseR24D10.physical_authorization.authorization_only_check_required_before_physical_attempt -and
        [bool]$releaseR24D10.physical_authorization.authorization_only_check_passed -and
        [int]$releaseR24D10.physical_authorization.physical_attempt_limit -eq 1 -and
        [bool]$releaseR24D10.physical_authorization.physical_attempt_consumed -and
        [int]$releaseR24D10.physical_authorization.world_count -eq 1 -and
        [int]$releaseR24D10.physical_authorization.fixture_cell_count -eq 9 -and
        [int]$releaseR24D10.physical_authorization.solver_step_count -eq 20 -and
        [int]$releaseR24D10.physical_authorization.retained_sample_count -eq 68 -and
        [int]$releaseR24D10.physical_authorization.threshold_count -eq 0 -and
        [int]$releaseR24D10.physical_authorization.margin_count -eq 0 -and
        [int]$releaseR24D10.physical_authorization.population_claim_count -eq 0 -and
        -not [bool]$releaseR24D10.physical_authorization.physical_execution_authorized -and
        -not [bool]$releaseR24D10.physical_authorization.physical_acceptance_authority -and
        [string]$releaseR24D10.physical_characterization.source_commit -ceq
            "9d2f8d59834c7cb9bf8271d0a10b3c2edcef7d22" -and
        [string]$releaseR24D10.physical_characterization.source_tree_git_oid -ceq
            "60fd3bb03bedc032211e275d4bf995beafeae8c5" -and
        [string]$releaseR24D10.physical_characterization.run_root -ceq
            "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d10-exact-step-numerical-telemetry/physical/20260826T204714579Z-9d2f8d59-6ccc8d1496a5" -and
        [string]$releaseR24D10.physical_characterization.execution_nonce -ceq
            "6ccc8d1496a5409a918c3dee501814a4" -and
        [string]$releaseR24D10.physical_characterization.receipt_raw_sha256 -ceq
            "sha256:1b75e51e8299b2b7a35ddff26db3059a9fea93e49a95e6feb170744a7a309f1b" -and
        [string]$releaseR24D10.physical_characterization.closure_path -ceq
            "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_physical_characterization_closure_v1.json" -and
        [string]$releaseR24D10.physical_characterization.closure_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d10PhysicalCharacterizationClosurePath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D10.physical_characterization.closure_audit_path -ceq
            "tests/test_qsdk_r24d10_exact_step_numerical_telemetry_physical_characterization_closure.py" -and
        [string]$releaseR24D10.physical_characterization.closure_audit_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d10PhysicalCharacterizationClosureAuditPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D10.physical_characterization.result -ceq
            "complete_valid_finite_descriptive_native_exact_step_numerical_characterization" -and
        [int]$releaseR24D10.physical_characterization.stage_count -eq 5 -and
        [int]$releaseR24D10.physical_characterization.retained_file_count -eq 17 -and
        [int]$releaseR24D10.physical_characterization.retained_total_byte_length -eq 408396 -and
        [int]$releaseR24D10.physical_characterization.retained_unique_content_digest_count -eq 16 -and
        [int]$releaseR24D10.physical_characterization.embedded_cas_reference_count -eq 25 -and
        [int]$releaseR24D10.physical_characterization.embedded_unique_cas_digest_count -eq 20 -and
        [int]$releaseR24D10.physical_characterization.world_attempt_count -eq 1 -and
        [int]$releaseR24D10.physical_characterization.world_build_count -eq 1 -and
        [int]$releaseR24D10.physical_characterization.solver_step_count -eq 20 -and
        [int]$releaseR24D10.physical_characterization.cell_count -eq 9 -and
        [int]$releaseR24D10.physical_characterization.retained_sample_count -eq 68 -and
        [int]$releaseR24D10.physical_characterization.current_numerical_aggregate_sample_count -eq 65 -and
        [int]$releaseR24D10.physical_characterization.sleeping_stale_excluded_sample_count -eq 3 -and
        [int]$releaseR24D10.physical_characterization.first_retained_space_step_sequence -eq 1 -and
        [int]$releaseR24D10.physical_characterization.last_retained_space_step_sequence -eq 20 -and
        [double]$releaseR24D10.physical_characterization.maximum_absolute_impulse_residual_nms -eq
            0.05999999679625034 -and
        [double]$releaseR24D10.physical_characterization.maximum_absolute_work_residual_j -eq
            0.03599999602884063 -and
        [int]$releaseR24D10.physical_characterization.empirical_acceptance_threshold_count -eq 0 -and
        [int]$releaseR24D10.physical_characterization.superiority_margin_count -eq 0 -and
        [int]$releaseR24D10.physical_characterization.equivalence_or_non_inferiority_margin_count -eq 0 -and
        [int]$releaseR24D10.physical_characterization.held_out_validation_cohort_count -eq 0 -and
        [int]$releaseR24D10.physical_characterization.population_claim_count -eq 0 -and
        -not [bool]$releaseR24D10.physical_characterization.same_source_rerun_allowed -and
        -not [bool]$releaseR24D10.physical_characterization.numerical_accuracy_accepted -and
        -not [bool]$releaseR24D10.physical_characterization.instrumented_profile_promoted -and
        -not [bool]$releaseR24D10.physical_characterization.physical_acceptance_authority -and
        -not [bool]$releaseR24D10.physical_characterization.release_authority -and
        [string]$releaseR24D10.first_physical_supervisor_qualification_adoption_refusal.source_commit -ceq
            "be6365cea71351519c796cefa4ec3900eed77539" -and
        [string]$releaseR24D10.first_physical_supervisor_qualification_adoption_refusal.qualification_receipt_raw_sha256 -ceq
            "sha256:fd380507caa22c5bb15c4e98a9235e5528436f92148603534ff6c8bea2925119" -and
        [int]$releaseR24D10.first_physical_supervisor_qualification_adoption_refusal.stage_count -eq 6 -and
        [int]$releaseR24D10.first_physical_supervisor_qualification_adoption_refusal.retained_file_count -eq 20 -and
        [int]$releaseR24D10.first_physical_supervisor_qualification_adoption_refusal.retained_unique_content_digest_count -eq 16 -and
        [int]$releaseR24D10.first_physical_supervisor_qualification_adoption_refusal.embedded_cas_reference_count -eq 13 -and
        [int]$releaseR24D10.first_physical_supervisor_qualification_adoption_refusal.world_attempt_count -eq 0 -and
        [int]$releaseR24D10.first_physical_supervisor_qualification_adoption_refusal.world_build_count -eq 0 -and
        [int]$releaseR24D10.first_physical_supervisor_qualification_adoption_refusal.solver_step_count -eq 0 -and
        [bool]$releaseR24D10.first_physical_supervisor_qualification_adoption_refusal.preflight_passed -and
        [bool]$releaseR24D10.first_physical_supervisor_qualification_adoption_refusal.adoption_refused -and
        [string]$releaseR24D10.first_physical_supervisor_qualification_adoption_refusal.failure_class -ceq
            "prospective_integration_authorization_transition_invalid" -and
        [string]$releaseR24D10.first_physical_supervisor_qualification_adoption_refusal.closure_path -ceq
            "sdk/recovery/r24d10_first_physical_supervisor_qualification_adoption_refusal_v1.json" -and
        [string]$releaseR24D10.first_physical_supervisor_qualification_adoption_refusal.closure_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d10FirstSupervisorAdoptionRefusalPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D10.first_physical_supervisor_qualification_adoption_refusal.closure_audit_path -ceq
            "tests/test_qsdk_r24d10_first_physical_supervisor_qualification_adoption_refusal.py" -and
        [string]$releaseR24D10.first_physical_supervisor_qualification_adoption_refusal.closure_audit_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d10FirstSupervisorAdoptionRefusalAuditPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        -not [bool]$releaseR24D10.first_physical_supervisor_qualification_adoption_refusal.v1_qualification_reusable_for_v2 -and
        -not [bool]$releaseR24D10.first_physical_supervisor_qualification_adoption_refusal.physical_execution_authorized -and
        -not [bool]$releaseR24D10.first_physical_supervisor_qualification_adoption_refusal.release_authority -and
        [string]$releaseR24D10.zero_world_receipt_raw_sha256 -ceq
            "sha256:093db061d3bb4799c4ac6a0a4c30364031297aee4b27608ef797cea05c6bb34f" -and
        [int]$releaseR24D10.declaration_mutation_rejection_count -eq 26 -and
        [int]$releaseR24D10.inherited_evaluator_negative_control_rejection_count -eq 46 -and
        [int]$releaseR24D10.new_exact_step_negative_control_rejection_count -eq 12 -and
        [int]$releaseR24D10.accepted_adverse_finite_descriptive_outcome_mutation_count -eq 3 -and
        [int]$releaseR24D10.source_mutation_rejection_count -eq 14 -and
        [int]$releaseR24D10.supervisor_mutation_rejection_count -eq 8 -and
        [int]$releaseR24D10.validation_manifest_source_binding_count -eq 19 -and
        [int]$releaseR24D10.zero_world_stage_count -eq 7 -and
        [int]$releaseR24D10.zero_world_retained_file_count -eq 23 -and
        [int]$releaseR24D10.zero_world_unique_content_digest_count -eq 19 -and
        [bool]$releaseR24D10.complete_zero_world_gate_passed -and
        [bool]$releaseR24D10.exact_step_schedule_source_qualified -and
        [int]$releaseR24D10.world_attempt_count -eq 1 -and
        [int]$releaseR24D10.world_build_count -eq 1 -and
        [int]$releaseR24D10.solver_step_count -eq 20 -and
        [bool]$releaseR24D10.physical_world_executed -and
        [bool]$releaseR24D10.valid_finite_descriptive_development_result -and
        -not [bool]$releaseR24D10.physical_execution_authorized -and
        [bool]$releaseR24D10.distinct_explicit_physical_authorization_satisfied -and
        [bool]$releaseR24D10.distinct_explicit_physical_authorization_required -and
        [bool]$releaseR24D10.native_numerical_telemetry_characterized -and
        -not [bool]$releaseR24D10.instrumented_profile_promoted -and
        -not [bool]$releaseR24D10.recovery_world_opened -and
        -not [bool]$releaseR24D10.prone_to_standing_world_opened -and
        -not [bool]$releaseR24D10.turning_claim_changed -and
        -not [bool]$releaseR24D10.cross_engine_equivalence_claimed -and
        -not [bool]$releaseR24D10.q_sdk_r24_satisfied -and
        -not [bool]$releaseR24D10.physical_acceptance_authority -and
        -not [bool]$releaseR24D10.release_authority -and
        [string]$releaseR24D10.profile_promotion_decision_boundary.gate_id -ceq
            "QSDK-R24D11" -and
        [string]$releaseR24D10.profile_promotion_decision_boundary.question_class -ceq
            "finite_decision" -and
        [string]$releaseR24D10.profile_promotion_decision_boundary.status -ceq
            "complete_finite_decision_instrumented_profile_promotion_refused_missing_absorbed_motor_work_witness" -and
        [string]$releaseR24D10.profile_promotion_decision_boundary.decision_path -ceq
            "sdk/recovery/r24d11_godot_jolt_instrumented_profile_promotion_decision_v1.json" -and
        [string]$releaseR24D10.profile_promotion_decision_boundary.decision_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d11ProfilePromotionDecisionPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D10.profile_promotion_decision_boundary.decision_audit_path -ceq
            "tests/test_qsdk_r24d11_godot_jolt_instrumented_profile_promotion_decision.py" -and
        [string]$releaseR24D10.profile_promotion_decision_boundary.decision_audit_raw_sha256 -ceq
            ("sha256:" + (
                Get-FileHash -LiteralPath $r24d11ProfilePromotionDecisionAuditPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()) -and
        [int]$releaseR24D10.profile_promotion_decision_boundary.decision_mutation_rejection_count -eq 21 -and
        [int]$releaseR24D10.profile_promotion_decision_boundary.empirical_performance_threshold_count -eq 0 -and
        [int]$releaseR24D10.profile_promotion_decision_boundary.source_derived_mechanism_witness_rule_count -eq 1 -and
        [int]$releaseR24D10.profile_promotion_decision_boundary.positive_motor_work_witness_count -eq 48 -and
        [int]$releaseR24D10.profile_promotion_decision_boundary.brake_positive_absorbed_work_witness_count -eq 0 -and
        [int]$releaseR24D10.profile_promotion_decision_boundary.brake_negative_absorbed_work_witness_count -eq 0 -and
        [bool]$releaseR24D10.profile_promotion_decision_boundary.brake_enabled_and_disabled_motor_telemetry_vectors_identical -and
        [string]$releaseR24D10.profile_promotion_decision_boundary.outcome -ceq
            "refuse_instrumented_profile_promotion" -and
        [int]$releaseR24D10.profile_promotion_decision_boundary.new_world_attempt_count -eq 0 -and
        [int]$releaseR24D10.profile_promotion_decision_boundary.new_world_build_count -eq 0 -and
        [int]$releaseR24D10.profile_promotion_decision_boundary.new_solver_step_count -eq 0 -and
        -not [bool]$releaseR24D10.profile_promotion_decision_boundary.instrumented_profile_promoted -and
        -not [bool]$releaseR24D10.profile_promotion_decision_boundary.stock_godot_profile_promoted -and
        -not [bool]$releaseR24D10.profile_promotion_decision_boundary.native_capability_conjunction_complete -and
        -not [bool]$releaseR24D10.profile_promotion_decision_boundary.recovery_world_opened -and
        -not [bool]$releaseR24D10.profile_promotion_decision_boundary.prone_to_standing_world_opened -and
        -not [bool]$releaseR24D10.profile_promotion_decision_boundary.release_authority -and
        [string]$releaseR24D10.profile_promotion_decision_boundary.next_gate_id -ceq
            "QSDK-R24D12" -and
        [string]$releaseR24D10.profile_promotion_decision_boundary.next_question_class -ceq
            "development" -and
        [string]$releaseR24D10.profile_promotion_decision_boundary.next_work -ceq
            "distinct_minimal_native_braking_mechanism_activation_characterization"
    ) "QSDK-R24D10 physical characterization release/support boundary drifted."
    Assert-True (
        [string]$r24d11ProfilePromotionDecision.schema_version -ceq
            "sporespore_qsdk_r24d11_godot_jolt_instrumented_profile_promotion_decision_v1" -and
        [string]$r24d11ProfilePromotionDecision.gate_id -ceq "QSDK-R24D11" -and
        [string]$r24d11ProfilePromotionDecision.question_class -ceq "finite_decision" -and
        [string]$r24d11ProfilePromotionDecision.status -ceq
            "complete_finite_decision_instrumented_profile_promotion_refused_missing_absorbed_motor_work_witness" -and
        [int]$r24d11ProfilePromotionDecision.complete_finite_observation.retained_sample_count -eq 68 -and
        [int]$r24d11ProfilePromotionDecision.complete_finite_observation.positive_motor_work_witness_count -eq 48 -and
        [int]$r24d11ProfilePromotionDecision.complete_finite_observation.brake_positive_absorbed_work_witness_count -eq 0 -and
        [int]$r24d11ProfilePromotionDecision.complete_finite_observation.brake_negative_absorbed_work_witness_count -eq 0 -and
        [bool]$r24d11ProfilePromotionDecision.complete_finite_observation.brake_and_paired_disabled_motor_telemetry_vectors_identical -and
        [string]$r24d11ProfilePromotionDecision.decision.outcome -ceq
            "refuse_instrumented_profile_promotion" -and
        -not [bool]$r24d11ProfilePromotionDecision.decision.instrumented_profile_promoted -and
        -not [bool]$r24d11ProfilePromotionDecision.decision.stock_godot_profile_promoted -and
        -not [bool]$r24d11ProfilePromotionDecision.decision.three_engine_native_capability_conjunction_complete -and
        -not [bool]$r24d11ProfilePromotionDecision.claims.new_physical_world_opened -and
        -not [bool]$r24d11ProfilePromotionDecision.claims.prone_to_standing_world_opened -and
        -not [bool]$r24d11ProfilePromotionDecision.claims.release_authority
    ) "QSDK-R24D11 finite profile-promotion decision drifted."
    $releaseR24D12 = $releaseR24D10.braking_mechanism_development_boundary
    $matrixR24D12 = $matrixR24D10.braking_mechanism_development_boundary
    Assert-True (
        ($releaseR24D12 | ConvertTo-Json -Depth 100 -Compress) -ceq
            ($matrixR24D12 | ConvertTo-Json -Depth 100 -Compress) -and
        [string]$releaseR24D12.gate_id -ceq "QSDK-R24D12" -and
        [string]$releaseR24D12.work_id -ceq
            "QSDK-R24D12-GODOT-JOLT-BRAKING-MECHANISM-ACTIVATION-CHARACTERIZATION" -and
        [string]$releaseR24D12.question_class -ceq "development" -and
        [string]$releaseR24D12.status -ceq
            "closed_consumed_invalid_incomplete_after_one_world_float32_readback_exactness_rejection_distinct_successor_required" -and
        [string]$releaseR24D12.preregistration_path -ceq
            "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_preregistration_v1.json" -and
        [string]$releaseR24D12.preregistration_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d12PreregistrationPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D12.validation_manifest_path -ceq
            "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_validation_manifest.json" -and
        [string]$releaseR24D12.validation_manifest_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d12ValidationManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D12.evaluator_path -ceq
            "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_evaluator.py" -and
        [string]$releaseR24D12.evaluator_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d12EvaluatorPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D12.rig_path -ceq
            "scripts/lab/rigs/r24d12_godot_jolt_braking_mechanism_activation_rig.gd" -and
        [string]$releaseR24D12.rig_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d12RigPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D12.worker_path -ceq
            "tests/test_sdk_qsdk_r24d12_godot_jolt_braking_mechanism_activation_worker.gd" -and
        [string]$releaseR24D12.worker_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d12WorkerPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D12.zero_world_runner_path -ceq
            "sdk/run_qsdk_r24d12_braking_mechanism_activation_zero_world_gate.ps1" -and
        [string]$releaseR24D12.zero_world_runner_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d12ZeroWorldRunnerPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D12.freeze_audit_path -ceq
            "tests/test_qsdk_r24d12_godot_jolt_braking_mechanism_activation_freeze.py" -and
        [string]$releaseR24D12.freeze_audit_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d12FreezeAuditPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D12.zero_world_positive_closure_path -ceq
            "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_zero_world_positive_closure_v1.json" -and
        [string]$releaseR24D12.zero_world_positive_closure_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d12ZeroWorldPositiveClosurePath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D12.zero_world_positive_closure_audit_path -ceq
            "tests/test_qsdk_r24d12_braking_mechanism_activation_zero_world_positive_closure.py" -and
        [string]$releaseR24D12.zero_world_positive_closure_audit_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d12ZeroWorldPositiveClosureAuditPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D12.physical_supervisor_contract_path -ceq
            "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_physical_supervisor_contract_v1.json" -and
        [string]$releaseR24D12.physical_supervisor_contract_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d12PhysicalSupervisorContractPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D12.physical_supervisor_manifest_path -ceq
            "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_physical_supervisor_manifest_v1.json" -and
        [string]$releaseR24D12.physical_supervisor_manifest_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d12PhysicalSupervisorManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D12.physical_supervisor_path -ceq
            "sdk/run_qsdk_r24d12_braking_mechanism_activation_characterization.ps1" -and
        [string]$releaseR24D12.physical_supervisor_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d12PhysicalSupervisorPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D12.physical_supervisor_source_audit_path -ceq
            "tests/test_qsdk_r24d12_braking_mechanism_activation_physical_supervisor_source.py" -and
        [string]$releaseR24D12.physical_supervisor_source_audit_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d12PhysicalSupervisorSourceAuditPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D12.physical_supervisor_freeze_commit -ceq
            "a9f6eaad2ef59558bdee4ba87187ed0d27555f66" -and
        [string]$releaseR24D12.physical_supervisor_freeze_tree_git_oid -ceq
            "725131306a08689a2e5448d1bebd732ebb9fea24" -and
        [string]$releaseR24D12.physical_supervisor_qualification_receipt_path -ceq
            "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d12-braking-mechanism-activation/physical-supervisor-qualification/20260826T222820198Z-a9f6eaad-fa6080b18d73/receipt.json" -and
        [string]$releaseR24D12.physical_supervisor_qualification_receipt_raw_sha256 -ceq
            "sha256:cc4112fafa1fefd2d39627832851ae3780cf536eba539ea631b658cf04f99020" -and
        [int]$releaseR24D12.physical_supervisor_qualification_receipt_byte_length -eq 22821 -and
        [string]$releaseR24D12.physical_supervisor_qualification_closure_path -ceq
            "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_physical_supervisor_qualification_positive_closure_v1.json" -and
        [string]$releaseR24D12.physical_supervisor_qualification_closure_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d12PhysicalSupervisorQualificationClosurePath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D12.physical_authorization_path -ceq
            "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_physical_authorization_v1.json" -and
        [string]$releaseR24D12.physical_authorization_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d12PhysicalAuthorizationPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D12.physical_supervisor_qualification_audit_path -ceq
            "tests/test_qsdk_r24d12_braking_mechanism_activation_physical_supervisor_qualification.py" -and
        [string]$releaseR24D12.physical_supervisor_qualification_audit_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d12PhysicalSupervisorQualificationAuditPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D12.physical_attempt_closure_path -ceq
            "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_physical_attempt_closure_v1.json" -and
        [string]$releaseR24D12.physical_attempt_closure_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d12PhysicalAttemptClosurePath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D12.physical_attempt_closure_audit_path -ceq
            "tests/test_qsdk_r24d12_braking_mechanism_activation_physical_attempt_closure.py" -and
        [string]$releaseR24D12.physical_attempt_closure_audit_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d12PhysicalAttemptClosureAuditPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D12.physical_attempt_run_root -ceq
            "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d12-braking-mechanism-activation/physical/20260826T223912889Z-0a15d68a-f58e60297ec4" -and
        [string]$releaseR24D12.physical_attempt_raw_sha256 -ceq
            "sha256:33d371a01bcf15656882d44723284be0ff87dd90fb34ffec34b8d867c222c264" -and
        [string]$releaseR24D12.physical_raw_report_raw_sha256 -ceq
            "sha256:93584a7b5a828e799092a52ca921cce6599612eb399d71471fe90674a275b27c" -and
        [int]$releaseR24D12.physical_attempt_retained_file_count -eq 15 -and
        [int]$releaseR24D12.physical_attempt_retained_total_byte_length -eq 78778 -and
        [int]$releaseR24D12.physical_attempt_unique_content_digest_count -eq 13 -and
        [int]$releaseR24D12.physical_attempt_closure_mutation_rejection_count -eq 17 -and
        [string]$releaseR24D12.physical_attempt_evaluator_rejection_code -ceq
            "FIXTURE_CHILD_INERTIA_DIAGONAL_KG_M2" -and
        [string]$releaseR24D12.native_diagnosis_raw_sha256 -ceq
            "sha256:36842eb8765e1a4abe9eb2fbb20d85ab14b653c7333bd043beb2c6cab5392408" -and
        [string]$releaseR24D12.native_diagnosis_git_blob_oid -ceq
            "1b563c74fc31a37f1bdb6113548aaaa63871243e" -and
        [string]$releaseR24D12.runtime_reuse_scope -ceq
            "exact_unchanged_cold_built_runtime_bytes_only_no_campaign_evidence_reused" -and
        [int]$releaseR24D12.source_binding_count -eq 15 -and
        [int]$releaseR24D12.source_mutation_rejection_count -eq 18 -and
        [int]$releaseR24D12.evaluator_invalid_mutation_rejection_count -eq 25 -and
        [int]$releaseR24D12.accepted_adverse_finite_outcome_count -eq 4 -and
        [int]$releaseR24D12.runtime_reuse_mutation_rejection_count -eq 8 -and
        [int]$releaseR24D12.closure_semantic_mutation_rejection_count -eq 38 -and
        [int]$releaseR24D12.physical_supervisor_source_binding_count -eq 16 -and
        [int]$releaseR24D12.physical_supervisor_contract_mutation_rejection_count -eq 23 -and
        [int]$releaseR24D12.physical_supervisor_qualification_mutation_rejection_count -eq 24 -and
        [int]$releaseR24D12.physical_supervisor_preflight_stage_count -eq 6 -and
        [int]$releaseR24D12.physical_supervisor_preflight_retained_file_count -eq 20 -and
        [int]$releaseR24D12.physical_supervisor_preflight_unique_content_digest_count -eq 16 -and
        [int]$releaseR24D12.physical_supervisor_preflight_embedded_cas_reference_count -eq 15 -and
        [int]$releaseR24D12.physical_supervisor_preflight_unique_cas_digest_count -eq 12 -and
        [int]$releaseR24D12.isolated_cell_count -eq 4 -and
        [int]$releaseR24D12.maximum_physics_step_count -eq 1 -and
        [int]$releaseR24D12.retained_sample_count -eq 4 -and
        [string]$releaseR24D12.zero_world_source_commit -ceq
            "7b807819a6ed1d1864f5a5410bbb9b17667624e1" -and
        [string]$releaseR24D12.zero_world_source_tree_git_oid -ceq
            "b07a5f72720e69d542d0c44bd932dde63e4546a8" -and
        [string]$releaseR24D12.zero_world_receipt_raw_sha256 -ceq
            "sha256:f8fd379f95f89197b1742efeeed41b55d0c71948634aaaf6d7a62d661f3aeb77" -and
        [int]$releaseR24D12.zero_world_stage_count -eq 5 -and
        [int]$releaseR24D12.zero_world_retained_file_count -eq 19 -and
        [int]$releaseR24D12.zero_world_unique_content_digest_count -eq 15 -and
        [int]$releaseR24D12.zero_world_embedded_cas_reference_count -eq 14 -and
        [int]$releaseR24D12.zero_world_unique_cas_digest_count -eq 11 -and
        [int]$releaseR24D12.empirical_performance_threshold_count -eq 0 -and
        [int]$releaseR24D12.official_zero_world_qualification_count -eq 1 -and
        [int]$releaseR24D12.world_attempt_count -eq 1 -and
        [int]$releaseR24D12.world_build_count -eq 1 -and
        [int]$releaseR24D12.solver_step_count -eq 1 -and
        [bool]$releaseR24D12.source_diagnosis_bound -and
        [bool]$releaseR24D12.corrected_activation_route_source_implemented -and
        [bool]$releaseR24D12.complete_zero_world_gate_source_implemented -and
        [bool]$releaseR24D12.complete_zero_world_gate_passed -and
        [bool]$releaseR24D12.physical_supervisor_source_implemented -and
        [bool]$releaseR24D12.physical_supervisor_preflight_passed -and
        [bool]$releaseR24D12.physical_authorization -and
        -not [bool]$releaseR24D12.physical_execution_authorized -and
        [bool]$releaseR24D12.physical_attempt_consumed -and
        -not [bool]$releaseR24D12.same_source_rerun_allowed -and
        [bool]$releaseR24D12.physical_characterization_executed -and
        -not [bool]$releaseR24D12.accepted_physical_characterization -and
        -not [bool]$releaseR24D12.braking_mechanism_activated -and
        -not [bool]$releaseR24D12.instrumented_profile_promoted -and
        -not [bool]$releaseR24D12.recovery_world_opened -and
        -not [bool]$releaseR24D12.prone_to_standing_world_opened -and
        -not [bool]$releaseR24D12.release_authority -and
        [string]$releaseR24D12.next_gate_id -ceq "QSDK-R24D13" -and
        [string]$releaseR24D12.next_question_class -ceq "development" -and
        [string]$releaseR24D12.next_work -ceq
            "r24d13_closed_consumed_invalid_r24d14_distinct_successor_required"
    ) "QSDK-R24D12 release/support consumed-invalid closure boundary drifted."
    $releaseR24D13 = $releaseR24D12.native_serializer_successor_boundary
    $matrixR24D13 = $matrixR24D12.native_serializer_successor_boundary
    Assert-True (
        ($releaseR24D13 | ConvertTo-Json -Depth 100 -Compress) -ceq
            ($matrixR24D13 | ConvertTo-Json -Depth 100 -Compress) -and
        [string]$releaseR24D13.gate_id -ceq "QSDK-R24D13" -and
        [string]$releaseR24D13.work_id -ceq
            "QSDK-R24D13-GODOT-JOLT-BRAKING-MECHANISM-ACTIVATION-NATIVE-SERIALIZATION-CORRECTION" -and
        [string]$releaseR24D13.question_class -ceq "development" -and
        [string]$releaseR24D13.status -ceq
            "closed_consumed_invalid_incomplete_after_one_world_native_float32_projection_exactness_rejection_distinct_successor_required" -and
        [string]$releaseR24D13.predecessor_gate_id -ceq "QSDK-R24D12" -and
        [string]$releaseR24D13.predecessor_physical_closure_path -ceq
            "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_physical_attempt_closure_v1.json" -and
        [string]$releaseR24D13.predecessor_physical_closure_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d12PhysicalAttemptClosurePath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D13.preregistration_path -ceq
            "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_preregistration_v1.json" -and
        [string]$releaseR24D13.preregistration_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d13PreregistrationPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D13.validation_manifest_path -ceq
            "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_validation_manifest.json" -and
        [string]$releaseR24D13.validation_manifest_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d13ValidationManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D13.evaluator_path -ceq
            "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_evaluator.py" -and
        [string]$releaseR24D13.evaluator_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d13EvaluatorPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D13.rig_path -ceq
            "scripts/lab/rigs/r24d13_godot_jolt_braking_mechanism_activation_rig.gd" -and
        [string]$releaseR24D13.rig_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d13RigPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D13.worker_path -ceq
            "tests/test_sdk_qsdk_r24d13_godot_jolt_braking_mechanism_activation_worker.gd" -and
        [string]$releaseR24D13.worker_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d13WorkerPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D13.physical_supervisor_contract_path -ceq
            "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_physical_supervisor_contract_v1.json" -and
        [string]$releaseR24D13.physical_supervisor_contract_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d13PhysicalSupervisorContractPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D13.physical_supervisor_manifest_path -ceq
            "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_physical_supervisor_manifest_v1.json" -and
        [string]$releaseR24D13.physical_supervisor_manifest_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d13PhysicalSupervisorManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D13.physical_supervisor_path -ceq
            "sdk/run_qsdk_r24d13_braking_mechanism_activation_characterization.ps1" -and
        [string]$releaseR24D13.physical_supervisor_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d13PhysicalSupervisorPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D13.physical_supervisor_source_audit_path -ceq
            "tests/test_qsdk_r24d13_braking_mechanism_activation_physical_supervisor_source.py" -and
        [string]$releaseR24D13.physical_supervisor_source_audit_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d13PhysicalSupervisorSourceAuditPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D13.physical_supervisor_freeze_commit -ceq
            "1231701240fe5c85f59ec74a610dc806ad6e2a2a" -and
        [string]$releaseR24D13.physical_supervisor_freeze_tree_git_oid -ceq
            "cf25e319a6c03daa8b3ce36b69a2e75a63f511e2" -and
        [string]$releaseR24D13.physical_supervisor_qualification_receipt_path -ceq
            "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d13-braking-mechanism-activation/physical-supervisor-qualification/20260826T232142657Z-12317012-c29272f7b41c/receipt.json" -and
        [string]$releaseR24D13.physical_supervisor_qualification_receipt_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d13PhysicalSupervisorQualificationReceiptPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [int]$releaseR24D13.physical_supervisor_qualification_receipt_byte_length -eq 23632 -and
        [string]$releaseR24D13.physical_supervisor_qualification_closure_path -ceq
            "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_physical_supervisor_qualification_positive_closure_v1.json" -and
        [string]$releaseR24D13.physical_supervisor_qualification_closure_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d13PhysicalSupervisorQualificationClosurePath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D13.physical_authorization_path -ceq
            "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_physical_authorization_v1.json" -and
        [string]$releaseR24D13.physical_authorization_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d13PhysicalAuthorizationPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D13.physical_supervisor_qualification_audit_path -ceq
            "tests/test_qsdk_r24d13_braking_mechanism_activation_physical_supervisor_qualification.py" -and
        [string]$releaseR24D13.physical_supervisor_qualification_audit_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d13PhysicalSupervisorQualificationAuditPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D13.physical_attempt_closure_path -ceq
            "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_physical_attempt_closure_v1.json" -and
        [string]$releaseR24D13.physical_attempt_closure_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d13PhysicalAttemptClosurePath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D13.physical_attempt_closure_audit_path -ceq
            "tests/test_qsdk_r24d13_braking_mechanism_activation_physical_attempt_closure.py" -and
        [string]$releaseR24D13.physical_attempt_closure_audit_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d13PhysicalAttemptClosureAuditPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D13.physical_attempt_run_root -ceq
            "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d13-braking-mechanism-activation/physical/20260826T233359861Z-b2b63ab4-1a34fab456d7" -and
        [string]$releaseR24D13.physical_attempt_raw_sha256 -ceq
            "sha256:3968159bc852b9ef5a11a660eb8d9b1fbab822cbb800079614f12c7309c4dedb" -and
        [string]$releaseR24D13.physical_raw_report_raw_sha256 -ceq
            "sha256:fee9372b0f69ca2399d49f93329a9f3b058d9ddd38d10062da63dbd65dd5b069" -and
        [string]$releaseR24D13.physical_evaluator_rejection_code -ceq
            "PARAMETER_brake_positive_public_maximum_motor_impulse_nms" -and
        [int]$releaseR24D13.physical_attempt_retained_file_count -eq 16 -and
        [int]$releaseR24D13.physical_attempt_total_byte_length -eq 84223 -and
        [int]$releaseR24D13.physical_attempt_unique_content_digest_count -eq 14 -and
        [string]$releaseR24D13.development_calibration.failed_run_root -ceq
            "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d13-braking-mechanism-activation/development/20260826T225920368Z-5e641f829a8c" -and
        [string]$releaseR24D13.development_calibration.failed_run_receipt_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d13FailedDevelopmentReceiptPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D13.development_calibration.failed_run_code -ceq
            "PARAMETER_brake_positive_public_maximum_motor_impulse_nms" -and
        [string]$releaseR24D13.development_calibration.passing_run_root -ceq
            "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d13-braking-mechanism-activation/development/20260826T230200899Z-01307724e80d" -and
        [string]$releaseR24D13.development_calibration.passing_run_receipt_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d13PassingDevelopmentReceiptPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D13.development_calibration.passing_result -ceq
            "synthetic_shape_conforms_zero_world_only" -and
        [int]$releaseR24D13.development_calibration.development_run_count -eq 2 -and
        [int]$releaseR24D13.development_calibration.world_attempt_count -eq 0 -and
        [int]$releaseR24D13.development_calibration.world_build_count -eq 0 -and
        [int]$releaseR24D13.development_calibration.solver_step_count -eq 0 -and
        -not [bool]$releaseR24D13.development_calibration.official_qualification -and
        [string]$releaseR24D13.native_serializer_identity.child_inertia_binary32_hex -ceq "3d4ccccd" -and
        [string]$releaseR24D13.native_serializer_identity.child_inertia_full_precision_json_text -ceq
            "0.05000000074505806" -and
        [string]$releaseR24D13.native_serializer_identity.maximum_motor_impulse_binary32_hex -ceq "3b03126f" -and
        [string]$releaseR24D13.native_serializer_identity.maximum_motor_impulse_full_precision_json_text -ceq
            "0.0020000000949949" -and
        [string]$releaseR24D13.native_serializer_identity.maximum_motor_impulse_native_property_readback_json_text -ceq
            "0.0020000000949949026" -and
        [string]$releaseR24D13.native_serializer_identity.solver_step_binary32_hex -ceq "3c088889" -and
        [string]$releaseR24D13.native_serializer_identity.solver_step_full_precision_json_text -ceq
            "0.00833333376795053" -and
        [string]$releaseR24D13.native_serializer_identity.solver_step_native_telemetry_json_text -ceq
            "0.008333333767950535" -and
        -not [bool]$releaseR24D13.native_serializer_identity.zero_object_projection_matched_native_readback -and
        [bool]$releaseR24D13.native_serializer_identity.comparison_is_exact_not_toleranced -and
        [double]$releaseR24D13.native_serializer_identity.tolerance -eq 0.0 -and
        [int]$releaseR24D13.validation_manifest_source_binding_count -eq 23 -and
        [int]$releaseR24D13.physical_supervisor_source_binding_count -eq 18 -and
        [int]$releaseR24D13.physical_supervisor_contract_mutation_rejection_count -eq 26 -and
        [int]$releaseR24D13.evaluator_invalid_mutation_rejection_count -eq 28 -and
        [int]$releaseR24D13.accepted_adverse_finite_outcome_count -eq 4 -and
        [int]$releaseR24D13.declared_preflight_stage_count -eq 6 -and
        [int]$releaseR24D13.physical_supervisor_qualification_mutation_rejection_count -eq 26 -and
        [int]$releaseR24D13.physical_supervisor_preflight_retained_file_count -eq 20 -and
        [int]$releaseR24D13.physical_supervisor_preflight_unique_content_digest_count -eq 17 -and
        [int]$releaseR24D13.physical_supervisor_preflight_embedded_cas_reference_count -eq 15 -and
        [int]$releaseR24D13.physical_supervisor_preflight_unique_cas_digest_count -eq 13 -and
        [int]$releaseR24D13.empirical_performance_threshold_count -eq 0 -and
        [int]$releaseR24D13.superiority_margin_count -eq 0 -and
        [int]$releaseR24D13.equivalence_or_non_inferiority_margin_count -eq 0 -and
        [int]$releaseR24D13.held_out_validation_cohort_count -eq 0 -and
        [int]$releaseR24D13.population_claim_count -eq 0 -and
        [int]$releaseR24D13.official_zero_world_qualification_count -eq 1 -and
        [int]$releaseR24D13.world_attempt_count -eq 1 -and
        [int]$releaseR24D13.world_build_count -eq 1 -and
        [int]$releaseR24D13.solver_step_count -eq 1 -and
        [bool]$releaseR24D13.predecessor_result_preserved -and
        [bool]$releaseR24D13.source_derived_native_serializer_contract_implemented -and
        [bool]$releaseR24D13.development_native_serializer_route_passed -and
        [bool]$releaseR24D13.complete_zero_world_gate_passed -and
        [bool]$releaseR24D13.physical_supervisor_source_implemented -and
        [bool]$releaseR24D13.physical_supervisor_preflight_passed -and
        [bool]$releaseR24D13.physical_authorization -and
        -not [bool]$releaseR24D13.physical_execution_authorized -and
        [bool]$releaseR24D13.physical_attempt_consumed -and
        -not [bool]$releaseR24D13.same_source_rerun_allowed -and
        [bool]$releaseR24D13.physical_characterization_executed -and
        -not [bool]$releaseR24D13.accepted_physical_characterization -and
        [bool]$releaseR24D13.evaluator_rejected_before_classification -and
        [bool]$releaseR24D13.development_zero_object_route_was_not_native_property_readback_equivalent -and
        [bool]$releaseR24D13.distinct_successor_required -and
        -not [bool]$releaseR24D13.native_braking_mechanism_characterized -and
        -not [bool]$releaseR24D13.native_braking_mechanism_activation_observed -and
        -not [bool]$releaseR24D13.numerical_accuracy_accepted -and
        -not [bool]$releaseR24D13.instrumented_profile_promoted -and
        -not [bool]$releaseR24D13.stock_godot_profile_promoted -and
        -not [bool]$releaseR24D13.native_capability_conjunction_complete -and
        -not [bool]$releaseR24D13.recovery_world_opened -and
        -not [bool]$releaseR24D13.prone_to_standing_world_opened -and
        -not [bool]$releaseR24D13.turning_claim_changed -and
        -not [bool]$releaseR24D13.cross_engine_equivalence_claimed -and
        -not [bool]$releaseR24D13.q_sdk_r24_satisfied -and
        -not [bool]$releaseR24D13.physical_acceptance_authority -and
        -not [bool]$releaseR24D13.release_authority -and
        [string]$releaseR24D13.next_gate_id -ceq "QSDK-R24D14" -and
        [string]$releaseR24D13.next_question_class -ceq "development" -and
        [string]$releaseR24D13.current_next_work -ceq
            "r24d15_profile_promotion_decision_closed_positive_r24d16_profile_scoped_mapping_next"
    ) "QSDK-R24D13 release/support consumed-invalid native-projection boundary drifted."
    $releaseR24D14 = $releaseR24D13.native_projection_qualification_successor_boundary
    $matrixR24D14 = $matrixR24D13.native_projection_qualification_successor_boundary
    Assert-True (
        ($releaseR24D14 | ConvertTo-Json -Depth 100 -Compress) -ceq
            ($matrixR24D14 | ConvertTo-Json -Depth 100 -Compress) -and
        [string]$releaseR24D14.gate_id -ceq "QSDK-R24D14" -and
        [string]$releaseR24D14.work_id -ceq
            "QSDK-R24D14-GODOT-NATIVE-PROPERTY-AND-TELEMETRY-FLOAT-PROJECTION" -and
        [string]$releaseR24D14.question_class -ceq "development" -and
        [string]$releaseR24D14.status -ceq
            "closed_complete_valid_finite_native_braking_mechanism_activation_positive_profile_promotion_decision_next" -and
        [string]$releaseR24D14.predecessor_gate_id -ceq "QSDK-R24D13" -and
        [string]$releaseR24D14.predecessor_closure_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d13PhysicalAttemptClosurePath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D14.preregistration_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14PreregistrationPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D14.validation_manifest_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14ValidationManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D14.evaluator_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14EvaluatorPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D14.worker_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14WorkerPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D14.qualification_runner_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14QualificationRunnerPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D14.source_audit_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14SourceAuditPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D14.qualification_source_commit -ceq
            "4f4d9f4900689bd7b452383d75b1eb8021b41e28" -and
        [string]$releaseR24D14.qualification_receipt_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14QualificationReceiptPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [int]$releaseR24D14.qualification_receipt_byte_length -eq 17469 -and
        [string]$releaseR24D14.qualification_closure_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14QualificationClosurePath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D14.qualification_closure_audit_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14QualificationClosureAuditPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [int]$releaseR24D14.source_binding_count -eq 17 -and
        [int]$releaseR24D14.native_source_binding_count -eq 6 -and
        [int]$releaseR24D14.source_mutation_rejection_count -eq 18 -and
        [int]$releaseR24D14.evaluator_invalid_mutation_rejection_count -eq 12 -and
        [int]$releaseR24D14.development_attempt_count -eq 4 -and
        [int]$releaseR24D14.official_qualification_count -eq 1 -and
        [int]$releaseR24D14.qualification_retained_file_count -eq 18 -and
        [int]$releaseR24D14.qualification_total_byte_length -eq 117384 -and
        [int]$releaseR24D14.qualification_unique_content_digest_count -eq 16 -and
        [int]$releaseR24D14.qualification_embedded_cas_reference_count -eq 10 -and
        [int]$releaseR24D14.qualification_unique_cas_digest_count -eq 8 -and
        [int]$releaseR24D14.native_joint_allocation_count -eq 1 -and
        [int]$releaseR24D14.native_joint_release_call_count -eq 1 -and
        [string]$releaseR24D14.native_impulse_binary64_hex -ceq "3f60624de0000000" -and
        [string]$releaseR24D14.native_timestep_binary64_hex -ceq "3f81111120000000" -and
        [int]$releaseR24D14.empirical_performance_threshold_count -eq 0 -and
        [int]$releaseR24D14.superiority_margin_count -eq 0 -and
        [int]$releaseR24D14.equivalence_or_non_inferiority_margin_count -eq 0 -and
        [int]$releaseR24D14.held_out_validation_cohort_count -eq 0 -and
        [int]$releaseR24D14.population_claim_count -eq 0 -and
        [int]$releaseR24D14.world_attempt_count -eq 0 -and
        [int]$releaseR24D14.world_build_count -eq 0 -and
        [int]$releaseR24D14.solver_step_count -eq 0 -and
        [bool]$releaseR24D14.predecessor_result_preserved -and
        [bool]$releaseR24D14.native_property_readback_projection_qualified -and
        [bool]$releaseR24D14.telemetry_float32_variant_projection_qualified -and
        [bool]$releaseR24D14.complete_zero_step_qualification_passed -and
        [string]$releaseR24D14.physical_supervisor_contract_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14PhysicalSupervisorContractPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D14.physical_supervisor_manifest_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14PhysicalSupervisorManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D14.physical_evaluator_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14PhysicalEvaluatorPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D14.physical_worker_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14PhysicalWorkerPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D14.physical_supervisor_runner_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14PhysicalSupervisorPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D14.physical_supervisor_source_audit_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14PhysicalSupervisorSourceAuditPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [int]$releaseR24D14.physical_supervisor_source_binding_count -eq 20 -and
        [int]$releaseR24D14.physical_supervisor_source_mutation_rejection_count -eq 28 -and
        [int]$releaseR24D14.development_preflight_attempt_count -eq 2 -and
        [int]$releaseR24D14.development_preflight_incomplete_count -eq 1 -and
        [int]$releaseR24D14.development_preflight_pass_count -eq 1 -and
        [string]$releaseR24D14.development_preflight_receipt_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14DevelopmentPreflightReceiptPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D14.physical_supervisor_qualification_source_commit -ceq
            "f0f250b92c7aeae027331cc1c9813d3eb9f163b1" -and
        [string]$releaseR24D14.physical_supervisor_qualification_receipt_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14PhysicalSupervisorQualificationReceiptPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [int]$releaseR24D14.physical_supervisor_qualification_receipt_byte_length -eq 25801 -and
        [string]$releaseR24D14.physical_supervisor_qualification_closure_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14PhysicalSupervisorQualificationClosurePath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D14.physical_authorization_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14PhysicalAuthorizationPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D14.physical_supervisor_qualification_audit_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14PhysicalSupervisorQualificationAuditPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D14.physical_characterization_closure_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14PhysicalCharacterizationClosurePath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D14.physical_characterization_closure_audit_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14PhysicalCharacterizationClosureAuditPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D14.physical_attempt_run_root -ceq
            "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d14-braking-mechanism-activation/physical/20260827T005329324Z-a6be6727-bd015eb4a2ea" -and
        [string]$releaseR24D14.physical_attempt_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14PhysicalAttemptPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D14.physical_raw_report_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14PhysicalRawReportPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D14.physical_raw_report_canonical_sha256 -ceq
            "sha256:4a07dd326c060f5d4768e760ca607da2fd5ec3ad626c689d70f8dc0f31cbc2e0" -and
        [string]$releaseR24D14.physical_evaluation_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14PhysicalEvaluationPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D14.physical_receipt_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d14PhysicalReceiptPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [int]$releaseR24D14.physical_receipt_byte_length -eq 67405 -and
        [int]$releaseR24D14.physical_retained_file_count -eq 18 -and
        [int]$releaseR24D14.physical_retained_total_byte_length -eq 157599 -and
        [int]$releaseR24D14.physical_unique_content_digest_count -eq 16 -and
        [int]$releaseR24D14.physical_embedded_cas_reference_count -eq 28 -and
        [int]$releaseR24D14.physical_unique_cas_digest_count -eq 23 -and
        [int]$releaseR24D14.physical_characterization_mutation_rejection_count -eq 37 -and
        [int]$releaseR24D14.physical_supervisor_official_preflight_count -eq 1 -and
        [int]$releaseR24D14.physical_supervisor_preflight_stage_count -eq 7 -and
        [int]$releaseR24D14.physical_supervisor_qualification_retained_file_count -eq 21 -and
        [int]$releaseR24D14.physical_supervisor_qualification_total_byte_length -eq 148649 -and
        [int]$releaseR24D14.physical_supervisor_qualification_unique_content_digest_count -eq 18 -and
        [int]$releaseR24D14.physical_supervisor_qualification_embedded_cas_reference_count -eq 16 -and
        [int]$releaseR24D14.physical_supervisor_qualification_unique_cas_digest_count -eq 14 -and
        [int]$releaseR24D14.physical_supervisor_qualification_native_joint_allocation_count -eq 1 -and
        [int]$releaseR24D14.physical_supervisor_qualification_native_joint_release_call_count -eq 1 -and
        [int]$releaseR24D14.physical_supervisor_qualification_mutation_rejection_count -eq 32 -and
        [bool]$releaseR24D14.physical_supervisor_source_implemented -and
        [bool]$releaseR24D14.physical_supervisor_development_preflight_passed -and
        [bool]$releaseR24D14.physical_supervisor_preflight_passed -and
        [bool]$releaseR24D14.physical_authorization -and
        -not [bool]$releaseR24D14.physical_execution_authorized -and
        [bool]$releaseR24D14.physical_attempt_consumed -and
        -not [bool]$releaseR24D14.same_source_rerun_allowed -and
        [bool]$releaseR24D14.physical_characterization_executed -and
        [bool]$releaseR24D14.accepted_physical_characterization -and
        [bool]$releaseR24D14.native_braking_mechanism_characterized -and
        [bool]$releaseR24D14.native_braking_mechanism_activation_observed -and
        [int]$releaseR24D14.motor_enabled_braking_witness_count -eq 2 -and
        [int]$releaseR24D14.motor_disabled_zero_witness_count -eq 2 -and
        [int]$releaseR24D14.physical_world_attempt_count -eq 1 -and
        [int]$releaseR24D14.physical_world_build_count -eq 1 -and
        [int]$releaseR24D14.physical_solver_step_count -eq 1 -and
        [int]$releaseR24D14.physical_retained_sample_count -eq 4 -and
        -not [bool]$releaseR24D14.numerical_accuracy_accepted -and
        -not [bool]$releaseR24D14.instrumented_profile_promoted -and
        -not [bool]$releaseR24D14.stock_godot_profile_promoted -and
        -not [bool]$releaseR24D14.native_capability_conjunction_complete -and
        -not [bool]$releaseR24D14.recovery_world_opened -and
        -not [bool]$releaseR24D14.prone_to_standing_world_opened -and
        -not [bool]$releaseR24D14.turning_claim_changed -and
        -not [bool]$releaseR24D14.cross_engine_equivalence_claimed -and
        -not [bool]$releaseR24D14.q_sdk_r24_satisfied -and
        -not [bool]$releaseR24D14.physical_acceptance_authority -and
        -not [bool]$releaseR24D14.release_authority -and
        [string]$releaseR24D14.next_gate_id -ceq "QSDK-R24D15" -and
        [string]$releaseR24D14.next_question_class -ceq "finite_decision" -and
        [string]$releaseR24D14.current_next_work -ceq
            "r24d15_profile_promotion_decision_closed_positive_r24d16_profile_scoped_mapping_next"
    ) "QSDK-R24D14 release/support physical-characterization boundary drifted."
    $releaseR24D15 = $releaseR24D14.instrumented_profile_promotion_successor_boundary
    $matrixR24D15 = $matrixR24D14.instrumented_profile_promotion_successor_boundary
    Assert-True (
        ($releaseR24D15 | ConvertTo-Json -Depth 100 -Compress) -ceq
            ($matrixR24D15 | ConvertTo-Json -Depth 100 -Compress) -and
        [string]$releaseR24D15.gate_id -ceq "QSDK-R24D15" -and
        [string]$releaseR24D15.work_id -ceq
            "QSDK-R24D15-GODOT-JOLT-INSTRUMENTED-PROFILE-PROMOTION-DECISION" -and
        [string]$releaseR24D15.question_class -ceq "finite_decision" -and
        [string]$releaseR24D15.status -ceq
            "complete_finite_decision_exact_instrumented_profile_promoted_mapping_implementation_next" -and
        [string]$releaseR24D15.decision_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d15ProfilePromotionDecisionPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [int]$releaseR24D15.decision_byte_length -eq 12491 -and
        [string]$releaseR24D15.decision_audit_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d15ProfilePromotionDecisionAuditPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D15.decision_parent_commit -ceq
            "540ad05b0dc2627bedeeb04a21a3d6f2ea11ab6a" -and
        [string]$releaseR24D15.decision_parent_tree_git_oid -ceq
            "7e243e9a5c1d5dd4ef65a33b0eaa0bcff2b6f0ef" -and
        [int]$releaseR24D15.bound_authority_count -eq 5 -and
        [int]$releaseR24D15.source_requirement_count -eq 8 -and
        [int]$releaseR24D15.satisfied_source_requirement_count -eq 8 -and
        [int]$releaseR24D15.r24d10_cell_count -eq 9 -and
        [int]$releaseR24D15.r24d10_retained_sample_count -eq 68 -and
        [int]$releaseR24D15.r24d14_world_attempt_count -eq 1 -and
        [int]$releaseR24D15.r24d14_world_build_count -eq 1 -and
        [int]$releaseR24D15.r24d14_solver_step_count -eq 1 -and
        [int]$releaseR24D15.r24d14_retained_sample_count -eq 4 -and
        [int]$releaseR24D15.motor_enabled_braking_witness_count -eq 2 -and
        [int]$releaseR24D15.motor_disabled_zero_witness_count -eq 2 -and
        [int]$releaseR24D15.decision_mutation_rejection_count -eq 33 -and
        [string]$releaseR24D15.instrumented_profile_id -ceq
            "godot_4_7_jolt_sporespore_motor_telemetry_active_step_snapshot_v2" -and
        [int]$releaseR24D15.empirical_performance_threshold_count -eq 0 -and
        [int]$releaseR24D15.superiority_margin_count -eq 0 -and
        [int]$releaseR24D15.equivalence_or_non_inferiority_margin_count -eq 0 -and
        [int]$releaseR24D15.held_out_validation_cohort_count -eq 0 -and
        [int]$releaseR24D15.population_claim_count -eq 0 -and
        -not [bool]$releaseR24D15.new_physical_world_opened -and
        -not [bool]$releaseR24D15.new_model_constructed -and
        -not [bool]$releaseR24D15.new_solver_step_executed -and
        [bool]$releaseR24D15.instrumented_profile_promoted -and
        [bool]$releaseR24D15.applied_actuation_receipts_measurement_profile_promoted -and
        [bool]$releaseR24D15.energy_balance_ledger_measurement_profile_promoted -and
        -not [bool]$releaseR24D15.stock_godot_profile_promoted -and
        -not [bool]$releaseR24D15.numerical_accuracy_accepted -and
        -not [bool]$releaseR24D15.adapter_capability_mapping_implemented -and
        -not [bool]$releaseR24D15.adapter_capability_mapping_qualified -and
        -not [bool]$releaseR24D15.native_capability_conjunction_complete -and
        -not [bool]$releaseR24D15.native_recovery_collector_implemented -and
        -not [bool]$releaseR24D15.recovery_controller_implemented -and
        -not [bool]$releaseR24D15.recovery_world_opened -and
        -not [bool]$releaseR24D15.prone_to_standing_world_opened -and
        -not [bool]$releaseR24D15.turning_claim_changed -and
        -not [bool]$releaseR24D15.cross_engine_equivalence_claimed -and
        -not [bool]$releaseR24D15.q_sdk_r24_satisfied -and
        -not [bool]$releaseR24D15.physical_acceptance_authority -and
        -not [bool]$releaseR24D15.release_authority -and
        [string]$releaseR24D15.sdk1_milestone_score_after -ceq "11/20" -and
        [string]$releaseR24D15.full_program_score_after -ceq "11/25" -and
        [string]$releaseR24D15.next_gate_id -ceq "QSDK-R24D16" -and
        [string]$releaseR24D15.next_question_class -ceq
            "non_physical_source_conformance" -and
        [string]$releaseR24D15.current_next_work -ceq
            "r24d16_profile_scoped_mapping_qualified_r24d17_collectors_controller_threshold_cohort_zero_world_next"
    ) "QSDK-R24D15 release/support profile-promotion decision boundary drifted."
    $releaseR24D16 = $releaseR24D15.profile_scoped_capability_mapping_successor_boundary
    $matrixR24D16 = $matrixR24D15.profile_scoped_capability_mapping_successor_boundary
    $r24d16CapabilityMappingCanonicalGitBlob = [string](& git -C (Split-Path -Parent $sdkRoot) hash-object -- $r24d16CapabilityMappingPath)
    Assert-True (
        ($releaseR24D16 | ConvertTo-Json -Depth 100 -Compress) -ceq
            ($matrixR24D16 | ConvertTo-Json -Depth 100 -Compress) -and
        [string]$releaseR24D16.gate_id -ceq "QSDK-R24D16" -and
        [string]$releaseR24D16.work_id -ceq
            "QSDK-R24D16-GODOT-JOLT-PROFILE-SCOPED-RECOVERY-CAPABILITY-MAPPING" -and
        [string]$releaseR24D16.question_class -ceq
            "non_physical_source_conformance" -and
        [string]$releaseR24D16.status -ceq
            "qualified_exact_profile_mapping_positive_stock_refusal_preserved" -and
        [string]$releaseR24D16.contract_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d16CapabilityContractPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [int]$releaseR24D16.contract_byte_length -eq 11553 -and
        [string]$releaseR24D16.mapping_raw_sha256 -ceq
            "sha256:e6d1ee07f403db5b00fb2431846d9dc84e233a44e44b77a8bbea23aec0319d8a" -and
        $r24d16CapabilityMappingCanonicalGitBlob.Trim() -ceq
            "9c3dac0d36f1252440b8f8def6ac127f42f41752" -and
        [int]$releaseR24D16.mapping_byte_length -eq 12760 -and
        [string]$releaseR24D16.source_audit_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d16CapabilitySourceAuditPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D16.runner_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d16CapabilityRunnerPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D16.worker_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d16CapabilityWorkerPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D16.closure_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d16CapabilityClosurePath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [int]$releaseR24D16.closure_byte_length -eq 12274 -and
        [string]$releaseR24D16.closure_audit_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d16CapabilityClosureAuditPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D16.source_freeze_commit -ceq
            "4ed7ad937235296a4d940794548621a549c1fe6d" -and
        [string]$releaseR24D16.source_freeze_tree_git_oid -ceq
            "913e34f88f5a6a1f0326efb4d138bb4d73af79fc" -and
        [string]$releaseR24D16.qualification_run_id -ceq
            "20260827T014757688Z-4ed7ad93-1405c8b1cd40" -and
        [string]$releaseR24D16.qualification_receipt_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d16CapabilityReceiptPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [int]$releaseR24D16.qualification_receipt_byte_length -eq 15420 -and
        [int]$releaseR24D16.source_inventory_count -eq 10 -and
        [int]$releaseR24D16.qualification_stage_count -eq 4 -and
        [int]$releaseR24D16.qualification_passed_stage_count -eq 4 -and
        [int]$releaseR24D16.runtime_process_count -eq 2 -and
        [int]$releaseR24D16.instrumented_positive_count -eq 1 -and
        [int]$releaseR24D16.stock_negative_control_count -eq 1 -and
        [int]$releaseR24D16.capability_mutation_count -eq 8 -and
        [int]$releaseR24D16.capability_mutation_rejection_count -eq 8 -and
        [int]$releaseR24D16.artifact_reference_count -eq 12 -and
        [int]$releaseR24D16.unique_artifact_count -eq 9 -and
        [int]$releaseR24D16.retained_artifact_total_byte_length -eq 25702 -and
        [int]$releaseR24D16.instrumented_required_channel_count -eq 10 -and
        [int]$releaseR24D16.instrumented_supported_channel_count -eq 10 -and
        [string]$releaseR24D16.instrumented_core_support_status -ceq
            "supported_exact" -and
        [int]$releaseR24D16.stock_required_channel_count -eq 10 -and
        [int]$releaseR24D16.stock_supported_channel_count -eq 8 -and
        [string]$releaseR24D16.stock_core_support_status -ceq
            "unsupported_capability" -and
        [bool]$releaseR24D16.profile_scoped_mapping_qualified -and
        [bool]$releaseR24D16.exact_profile_native_capability_conjunction_complete -and
        -not [bool]$releaseR24D16.stock_profile_promoted -and
        -not [bool]$releaseR24D16.numerical_accuracy_accepted -and
        -not [bool]$releaseR24D16.native_recovery_observation_collectors_complete -and
        -not [bool]$releaseR24D16.recovery_controller_implemented -and
        [int]$releaseR24D16.model_construction_count -eq 0 -and
        [int]$releaseR24D16.world_attempt_count -eq 0 -and
        [int]$releaseR24D16.world_build_count -eq 0 -and
        [int]$releaseR24D16.solver_step_count -eq 0 -and
        -not [bool]$releaseR24D16.physics_state_modified -and
        -not [bool]$releaseR24D16.recovery_world_opened -and
        -not [bool]$releaseR24D16.prone_to_standing_world_opened -and
        -not [bool]$releaseR24D16.turning_claim_changed -and
        -not [bool]$releaseR24D16.cross_engine_equivalence_claimed -and
        -not [bool]$releaseR24D16.q_sdk_r24_satisfied -and
        -not [bool]$releaseR24D16.physical_acceptance_authority -and
        -not [bool]$releaseR24D16.release_authority -and
        [string]$releaseR24D16.sdk1_milestone_score_after -ceq "11/20" -and
        [string]$releaseR24D16.full_program_score_after -ceq "11/25" -and
        [string]$releaseR24D16.next_gate_id -ceq "QSDK-R24D17" -and
        [string]$releaseR24D16.next_question_class -ceq
            "non_physical_source_conformance" -and
        [string]$releaseR24D16.current_next_work -ceq
            "r24d17_runtime_source_qualification_closed_r24d18_native_route_development_commissioning_next"
    ) "QSDK-R24D16 release/support profile-scoped mapping boundary drifted."
    $releaseR24D17 = $releaseR24D16.native_recovery_runtime_successor_boundary
    $matrixR24D17 = $matrixR24D16.native_recovery_runtime_successor_boundary
    Assert-True (
        ($releaseR24D17 | ConvertTo-Json -Depth 100 -Compress) -ceq
            ($matrixR24D17 | ConvertTo-Json -Depth 100 -Compress) -and
        [string]$releaseR24D17.gate_id -ceq "QSDK-R24D17" -and
        [string]$releaseR24D17.work_id -ceq
            "QSDK-R24D17-NATIVE-RECOVERY-RUNTIME-AND-PHYSICAL-PROFILE" -and
        [string]$releaseR24D17.question_class -ceq
            "non_physical_source_conformance" -and
        [string]$releaseR24D17.status -ceq
            "qualified_native_validation_surfaces_controller_and_prospective_physical_profile_physics_not_opened" -and
        [string]$releaseR24D17.contract_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d17RuntimeContractPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [int]$releaseR24D17.contract_byte_length -eq 20125 -and
        [string]$releaseR24D17.source_audit_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d17RuntimeSourceAuditPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D17.runner_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d17RuntimeRunnerPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D17.godot_worker_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d17RuntimeGodotWorkerPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [string]$releaseR24D17.closure_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d17RuntimeClosurePath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [int]$releaseR24D17.closure_byte_length -eq 16569 -and
        [string]$releaseR24D17.closure_audit_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d17RuntimeClosureAuditPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [int]$releaseR24D17.closure_audit_byte_length -eq 32350 -and
        [string]$releaseR24D17.source_freeze_commit -ceq
            "576e70861d77f1ea547344c5e4fcf10ed09fe954" -and
        [string]$releaseR24D17.source_freeze_tree_git_oid -ceq
            "72e2f352aa7bf19e79fe8ff6986d991bceb10e67" -and
        [string]$releaseR24D17.source_freeze_parent_commit -ceq
            "7c76aa69b32511c9bcec0c77930f418f41dbc0ed" -and
        [string]$releaseR24D17.qualification_run_id -ceq
            "20260827T024026086Z-576e7086" -and
        [string]$releaseR24D17.qualification_receipt_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d17RuntimeReceiptPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [int]$releaseR24D17.qualification_receipt_byte_length -eq 17727 -and
        [int]$releaseR24D17.source_inventory_count -eq 25 -and
        [int]$releaseR24D17.qualification_process_count -eq 6 -and
        [int]$releaseR24D17.qualification_passed_process_count -eq 6 -and
        [int]$releaseR24D17.core_recovery_test_count -eq 5 -and
        [int]$releaseR24D17.rapier_surface_test_count -eq 2 -and
        [int]$releaseR24D17.python_test_count -eq 4 -and
        [int]$releaseR24D17.godot_process_count -eq 1 -and
        [int]$releaseR24D17.native_engine_identity_count -eq 3 -and
        [int]$releaseR24D17.required_channel_count_per_engine -eq 10 -and
        [int]$releaseR24D17.runtime_mutation_refusal_count -eq 8 -and
        [int]$releaseR24D17.controller_mutation_refusal_count -eq 1 -and
        [int]$releaseR24D17.threshold_count -eq 16 -and
        [int]$releaseR24D17.threshold_provenance_count -eq 16 -and
        [int]$releaseR24D17.threshold_adequacy_argument_count -eq 16 -and
        [string]$releaseR24D17.development_question_class -ceq "development" -and
        [int]$releaseR24D17.development_cell_count -eq 3 -and
        [string]$releaseR24D17.held_out_question_class -ceq "finite_decision" -and
        [int]$releaseR24D17.held_out_engine_count -eq 3 -and
        [int]$releaseR24D17.held_out_cell_count -eq 9 -and
        [int]$releaseR24D17.held_out_cells_executed -eq 0 -and
        -not [bool]$releaseR24D17.held_out_seed_use_during_development_permitted -and
        [int]$releaseR24D17.retained_file_reference_count -eq 14 -and
        [int]$releaseR24D17.unique_retained_artifact_count -eq 11 -and
        [int]$releaseR24D17.retained_file_total_byte_length -eq 21844 -and
        [bool]$releaseR24D17.all_retained_files_content_addressed_at_closure -and
        [bool]$releaseR24D17.native_observation_validation_surfaces_qualified -and
        [bool]$releaseR24D17.native_adapter_collection_surfaces_qualified -and
        [bool]$releaseR24D17.deterministic_controller_candidate_implemented -and
        [bool]$releaseR24D17.prospective_threshold_profile_frozen -and
        [bool]$releaseR24D17.prospective_cohorts_frozen -and
        -not [bool]$releaseR24D17.physical_route_implemented -and
        -not [bool]$releaseR24D17.native_runtime_observation_collection_executed -and
        -not [bool]$releaseR24D17.controller_physical_viability_proven -and
        [int]$releaseR24D17.model_construction_count -eq 0 -and
        [int]$releaseR24D17.world_attempt_count -eq 0 -and
        [int]$releaseR24D17.world_build_count -eq 0 -and
        [int]$releaseR24D17.solver_step_count -eq 0 -and
        -not [bool]$releaseR24D17.physics_state_modified -and
        -not [bool]$releaseR24D17.recovery_world_opened -and
        -not [bool]$releaseR24D17.prone_to_standing_world_opened -and
        -not [bool]$releaseR24D17.turning_claim_changed -and
        -not [bool]$releaseR24D17.cross_engine_recovery_claimed -and
        -not [bool]$releaseR24D17.cross_engine_equivalence_claimed -and
        -not [bool]$releaseR24D17.q_sdk_r24_satisfied -and
        -not [bool]$releaseR24D17.physical_acceptance_authority -and
        -not [bool]$releaseR24D17.release_authority -and
        [string]$releaseR24D17.sdk1_milestone_score_after -ceq "11/20" -and
        [string]$releaseR24D17.full_program_score_after -ceq "11/25" -and
        [string]$releaseR24D17.next_gate_id -ceq "QSDK-R24D18" -and
        [string]$releaseR24D17.next_question_class -ceq "development"
    ) "QSDK-R24D17 release/support recovery-runtime boundary drifted."
    Assert-True (
        [string]$r24d17RuntimeContract.schema_version -ceq
            "sporespore_qsdk_r24d17_native_recovery_runtime_and_physical_profile_contract_v1" -and
        [string]$r24d17RuntimeContract.declaration_parent_commit -ceq
            "7c76aa69b32511c9bcec0c77930f418f41dbc0ed" -and
        [string]$r24d17RuntimeContract.question_class -ceq
            "non_physical_source_conformance_no_physical_question_opened" -and
        @($r24d17RuntimeContract.native_runtime_bindings).Count -eq 3 -and
        @($r24d17RuntimeContract.threshold_profile.thresholds).Count -eq 16 -and
        [int]$r24d17RuntimeContract.cohort_profile.development.cell_count -eq 3 -and
        [int]$r24d17RuntimeContract.cohort_profile.held_out.cell_count -eq 9 -and
        -not [bool]$r24d17RuntimeContract.cohort_profile.held_out.development_access_permitted -and
        -not [bool]$r24d17RuntimeContract.collector_boundary.current_gate_executes_native_sampling -and
        -not [bool]$r24d17RuntimeContract.collector_boundary.current_gate_executes_physics -and
        [string]$r24d17RuntimeClosure.schema_version -ceq
            "sporespore_qsdk_r24d17_native_recovery_runtime_qualification_closure_v1" -and
        [string]$r24d17RuntimeClosure.source_freeze.commit -ceq
            "576e70861d77f1ea547344c5e4fcf10ed09fe954" -and
        [int]$r24d17RuntimeClosure.source_freeze.source_inventory_count -eq 25 -and
        [int]$r24d17RuntimeClosure.qualification.passed_process_count -eq 6 -and
        [int]$r24d17RuntimeClosure.qualification.retained_file_reference_count -eq 14 -and
        [int]$r24d17RuntimeClosure.qualification.unique_retained_artifact_count -eq 11 -and
        [bool]$r24d17RuntimeClosure.qualification.all_retained_files_content_addressed_at_closure -and
        [bool]$r24d17RuntimeClosure.decision.native_observation_validation_surfaces_qualified -and
        [bool]$r24d17RuntimeClosure.decision.deterministic_controller_candidate_qualified_for_physical_development -and
        -not [bool]$r24d17RuntimeClosure.decision.native_runtime_observation_collection_executed -and
        -not [bool]$r24d17RuntimeClosure.decision.controller_physical_viability_proven -and
        [string]$r24d17RuntimeReceipt.status -ceq
            "qualification_passed_physics_not_opened" -and
        [string]$r24d17RuntimeReceipt.source_boundary.head -ceq
            "576e70861d77f1ea547344c5e4fcf10ed09fe954" -and
        [bool]$r24d17RuntimeReceipt.source_boundary.clean_pushed -and
        [int]$r24d17RuntimeReceipt.process_count -eq 6 -and
        @($r24d17RuntimeReceipt.processes | Where-Object { -not [bool]$_.ok }).Count -eq 0 -and
        [int]$r24d17RuntimeReceipt.held_out_cells_executed -eq 0 -and
        -not [bool]$r24d17RuntimeReceipt.native_runtime_observation_collection_executed -and
        [int]$r24d17RuntimeReceipt.model_construction_count -eq 0 -and
        [int]$r24d17RuntimeReceipt.world_attempt_count -eq 0 -and
        [int]$r24d17RuntimeReceipt.world_build_count -eq 0 -and
        [int]$r24d17RuntimeReceipt.solver_step_count -eq 0 -and
        -not [bool]$r24d17RuntimeReceipt.prone_to_standing_claimed -and
        -not [bool]$r24d17RuntimeReceipt.release_authority
    ) "QSDK-R24D17 immutable contract, closure, or receipt drifted."
    Assert-True (
        [string]$r24d16CapabilityContract.schema_version -ceq
            "sporespore_qsdk_r24d16_godot_jolt_profile_scoped_recovery_capability_contract_v1" -and
        [string]$r24d16CapabilityContract.status -ceq
            "implemented_prospective_source_freeze_qualification_pending" -and
        [string]$r24d16CapabilityContract.source_boundary.parent_commit -ceq
            "b8c5ec5919d9d890946262d923f79259a6c8662a" -and
        [bool]$r24d16CapabilityContract.claims.profile_scoped_mapping_implemented -and
        -not [bool]$r24d16CapabilityContract.claims.profile_scoped_mapping_qualified -and
        [string]$r24d16CapabilityClosure.schema_version -ceq
            "sporespore_qsdk_r24d16_godot_jolt_profile_scoped_recovery_capability_qualification_closure_v1" -and
        [string]$r24d16CapabilityClosure.source_freeze.commit -ceq
            "4ed7ad937235296a4d940794548621a549c1fe6d" -and
        [int]$r24d16CapabilityClosure.qualification.passed_stage_count -eq 4 -and
        [int]$r24d16CapabilityClosure.qualification.artifact_reference_count -eq 12 -and
        [bool]$r24d16CapabilityClosure.decision.profile_scoped_mapping_qualified -and
        [bool]$r24d16CapabilityClosure.decision.exact_profile_native_capability_conjunction_complete -and
        -not [bool]$r24d16CapabilityClosure.decision.stock_profile_promoted -and
        -not [bool]$r24d16CapabilityClosure.decision.native_recovery_observation_collectors_complete -and
        [string]$r24d16CapabilityReceipt.status -ceq
            "qualified_exact_profile_mapping_positive_stock_refusal_preserved" -and
        [bool]$r24d16CapabilityReceipt.ok -and
        [bool]$r24d16CapabilityReceipt.profile_scoped_mapping_qualified -and
        [bool]$r24d16CapabilityReceipt.exact_profile_native_capability_conjunction_complete -and
        [int]$r24d16CapabilityReceipt.world_attempt_count -eq 0 -and
        [int]$r24d16CapabilityReceipt.solver_step_count -eq 0 -and
        -not [bool]$r24d16CapabilityReceipt.prone_to_standing_world_opened -and
        -not [bool]$r24d16CapabilityReceipt.release_authority
    ) "QSDK-R24D16 immutable contract, closure, or receipt drifted."
    Assert-True (
        [string]$r24d15ProfilePromotionDecision.schema_version -ceq
            "sporespore_qsdk_r24d15_godot_jolt_instrumented_profile_promotion_decision_v1" -and
        [string]$r24d15ProfilePromotionDecision.decision_id -ceq
            "QSDK-R24D15-PROFILE-PROMOTION-DECISION" -and
        [string]$r24d15ProfilePromotionDecision.question_class -ceq
            "finite_decision" -and
        [string]$r24d15ProfilePromotionDecision.status -ceq
            "complete_finite_decision_exact_instrumented_profile_promoted_mapping_implementation_next" -and
        [string]$r24d15ProfilePromotionDecision.source_boundary.decision_parent_commit -ceq
            "540ad05b0dc2627bedeeb04a21a3d6f2ea11ab6a" -and
        @($r24d15ProfilePromotionDecision.bound_authorities).Count -eq 5 -and
        [bool]$r24d15ProfilePromotionDecision.runtime_identity_conjunction.executed_binary_pair_matches -and
        -not [bool]$r24d15ProfilePromotionDecision.runtime_identity_conjunction.stock_godot_substitution_permitted -and
        [int]$r24d15ProfilePromotionDecision.combined_requirement_decision.required_characterization_count -eq 8 -and
        [int]$r24d15ProfilePromotionDecision.combined_requirement_decision.satisfied_characterization_count -eq 8 -and
        [bool]$r24d15ProfilePromotionDecision.combined_requirement_decision.all_previously_declared_r24d3_mechanism_requirements_observed -and
        -not [bool]$r24d15ProfilePromotionDecision.combined_requirement_decision.combined_fixtures_reinterpreted_as_one_population -and
        [int]$r24d15ProfilePromotionDecision.decision_rule_provenance.empirical_performance_threshold_count -eq 0 -and
        [int]$r24d15ProfilePromotionDecision.decision_rule_provenance.population_claim_count -eq 0 -and
        [string]$r24d15ProfilePromotionDecision.decision.outcome -ceq
            "promote_exact_instrumented_profile_for_recovery_capability_mapping" -and
        [bool]$r24d15ProfilePromotionDecision.decision.instrumented_profile_promoted -and
        -not [bool]$r24d15ProfilePromotionDecision.decision.stock_godot_profile_promoted -and
        -not [bool]$r24d15ProfilePromotionDecision.decision.numerical_accuracy_accepted -and
        -not [bool]$r24d15ProfilePromotionDecision.decision.adapter_capability_mapping_implemented -and
        -not [bool]$r24d15ProfilePromotionDecision.decision.three_engine_native_capability_conjunction_complete -and
        [string]$r24d15ProfilePromotionDecision.next_boundary.gate_id -ceq "QSDK-R24D16" -and
        -not [bool]$r24d15ProfilePromotionDecision.next_boundary.physical_execution_authorized -and
        -not [bool]$r24d15ProfilePromotionDecision.claims.prone_to_standing_world_opened -and
        -not [bool]$r24d15ProfilePromotionDecision.claims.release_authority
    ) "QSDK-R24D15 immutable finite profile-promotion decision drifted."
    Assert-True (
        [string]$r24d14PhysicalCharacterizationClosure.schema_version -ceq
            "sporespore_qsdk_r24d14_godot_jolt_braking_mechanism_activation_physical_characterization_closure_v1" -and
        [string]$r24d14PhysicalCharacterizationClosure.closure_id -ceq
            "QSDK-R24D14-PH1-CLOSURE" -and
        [string]$r24d14PhysicalCharacterizationClosure.question_class -ceq "development" -and
        [string]$r24d14PhysicalCharacterizationClosure.status -ceq
            "closed_complete_valid_finite_native_braking_mechanism_activation_positive_profile_promotion_decision_next" -and
        [string]$r24d14PhysicalCharacterizationClosure.source.authorization_commit -ceq
            "a6be67273c113d4768fa8930cd47ab0eab21be15" -and
        [string]$r24d14PhysicalCharacterizationClosure.source.authorization_parent_commit -ceq
            "f0f250b92c7aeae027331cc1c9813d3eb9f163b1" -and
        [bool]$r24d14PhysicalCharacterizationClosure.physical_authorization.physical_attempt_consumed -and
        -not [bool]$r24d14PhysicalCharacterizationClosure.physical_authorization.same_source_rerun_allowed -and
        [string]$r24d14PhysicalCharacterizationClosure.physical_attempt.result -ceq
            "complete_valid_finite_native_braking_mechanism_activation_positive" -and
        [bool]$r24d14PhysicalCharacterizationClosure.physical_attempt.execution_valid -and
        [int]$r24d14PhysicalCharacterizationClosure.physical_attempt.world_attempt_count -eq 1 -and
        [int]$r24d14PhysicalCharacterizationClosure.physical_attempt.world_build_count -eq 1 -and
        [int]$r24d14PhysicalCharacterizationClosure.physical_attempt.solver_step_count -eq 1 -and
        [int]$r24d14PhysicalCharacterizationClosure.physical_attempt.retained_sample_count -eq 4 -and
        [int]$r24d14PhysicalCharacterizationClosure.mechanism_characterization.motor_enabled_braking_witness_count -eq 2 -and
        [int]$r24d14PhysicalCharacterizationClosure.mechanism_characterization.motor_disabled_zero_witness_count -eq 2 -and
        [bool]$r24d14PhysicalCharacterizationClosure.mechanism_characterization.native_braking_mechanism_activation_observed -and
        [int]$r24d14PhysicalCharacterizationClosure.retention.physical_retained_file_count -eq 18 -and
        [int]$r24d14PhysicalCharacterizationClosure.retention.physical_retained_total_byte_length -eq 157599 -and
        [int]$r24d14PhysicalCharacterizationClosure.retention.physical_unique_content_digest_count -eq 16 -and
        [int]$r24d14PhysicalCharacterizationClosure.retention.embedded_cas_reference_count -eq 28 -and
        [int]$r24d14PhysicalCharacterizationClosure.retention.embedded_unique_cas_digest_count -eq 23 -and
        [int]$r24d14PhysicalCharacterizationClosure.statistical_claim_boundary.empirical_acceptance_threshold_count -eq 0 -and
        [int]$r24d14PhysicalCharacterizationClosure.statistical_claim_boundary.population_claim_count -eq 0 -and
        [bool]$r24d14PhysicalCharacterizationClosure.claims.accepted_physical_characterization -and
        [bool]$r24d14PhysicalCharacterizationClosure.claims.native_braking_mechanism_characterized -and
        [bool]$r24d14PhysicalCharacterizationClosure.claims.native_braking_mechanism_activation_observed -and
        -not [bool]$r24d14PhysicalCharacterizationClosure.claims.numerical_accuracy_accepted -and
        -not [bool]$r24d14PhysicalCharacterizationClosure.claims.instrumented_profile_promoted -and
        -not [bool]$r24d14PhysicalCharacterizationClosure.claims.recovery_world_opened -and
        -not [bool]$r24d14PhysicalCharacterizationClosure.claims.prone_to_standing_world_opened -and
        -not [bool]$r24d14PhysicalCharacterizationClosure.claims.q_sdk_r24_satisfied -and
        -not [bool]$r24d14PhysicalCharacterizationClosure.claims.physical_acceptance_authority -and
        -not [bool]$r24d14PhysicalCharacterizationClosure.claims.release_authority -and
        [string]$r24d14PhysicalCharacterizationClosure.next_boundary.gate_id -ceq "QSDK-R24D15" -and
        [string]$r24d14PhysicalCharacterizationClosure.next_boundary.question_class -ceq "finite_decision" -and
        -not [bool]$r24d14PhysicalCharacterizationClosure.next_boundary.new_physical_execution_required -and
        -not [bool]$r24d14PhysicalCharacterizationClosure.next_boundary.physical_execution_authorized
    ) "QSDK-R24D14 immutable physical-characterization closure drifted."
    Assert-True (
        [string]$r24d14QualificationClosure.schema_version -ceq
            "sporespore_qsdk_r24d14_godot_native_float_projection_qualification_positive_closure_v1" -and
        [string]$r24d14QualificationClosure.closure_id -ceq
            "QSDK-R24D14-NATIVE-PROJECTION-QUALIFICATION-CLOSURE-V1" -and
        [string]$r24d14QualificationClosure.status -ceq
            "complete_clean_pushed_zero_step_native_property_and_telemetry_projection_qualified_physical_supervisor_pending" -and
        [string]$r24d14QualificationClosure.source.commit -ceq
            "4f4d9f4900689bd7b452383d75b1eb8021b41e28" -and
        [int]$r24d14QualificationClosure.retained_evidence.file_count -eq 18 -and
        [int]$r24d14QualificationClosure.retained_evidence.total_byte_length -eq 117384 -and
        [int]$r24d14QualificationClosure.retained_evidence.unique_content_digest_count -eq 16 -and
        [int]$r24d14QualificationClosure.qualification.native_joint_allocation_count -eq 1 -and
        [int]$r24d14QualificationClosure.qualification.world_attempt_count -eq 0 -and
        [int]$r24d14QualificationClosure.qualification.world_build_count -eq 0 -and
        [int]$r24d14QualificationClosure.qualification.solver_step_count -eq 0 -and
        [bool]$r24d14QualificationClosure.claims.complete_zero_step_qualification_passed -and
        -not [bool]$r24d14QualificationClosure.claims.physical_characterization_executed -and
        -not [bool]$r24d14QualificationClosure.disposition.physical_execution_authorized_now
    ) "QSDK-R24D14 immutable zero-step qualification closure drifted."
    Assert-True (
        [string]$r24d13PhysicalAttemptClosure.schema_version -ceq
            "sporespore_qsdk_r24d13_braking_mechanism_activation_physical_attempt_closure_v1" -and
        [string]$r24d13PhysicalAttemptClosure.closure_id -ceq
            "QSDK-R24D13-PHYSICAL-CLOSURE-V1" -and
        [string]$r24d13PhysicalAttemptClosure.status -ceq
            "closed_consumed_invalid_incomplete_after_one_world_native_float32_projection_exactness_rejection" -and
        [string]$r24d13PhysicalAttemptClosure.authorization.authorization_commit -ceq
            "b2b63ab4a28d9ac45525d9ba33907bb33adfe785" -and
        [string]$r24d13PhysicalAttemptClosure.authorization.authorization_parent_commit -ceq
            "1231701240fe5c85f59ec74a610dc806ad6e2a2a" -and
        -not [bool]$r24d13PhysicalAttemptClosure.authorization.same_source_rerun_allowed -and
        [int]$r24d13PhysicalAttemptClosure.retained_evidence.file_count -eq 16 -and
        [int]$r24d13PhysicalAttemptClosure.retained_evidence.total_byte_length -eq 84223 -and
        [int]$r24d13PhysicalAttemptClosure.retained_evidence.unique_content_digest_count -eq 14 -and
        -not [bool]$r24d13PhysicalAttemptClosure.retained_evidence.receipt_published -and
        -not [bool]$r24d13PhysicalAttemptClosure.retained_evidence.evaluation_published -and
        [int]$r24d13PhysicalAttemptClosure.execution.world_attempt_count -eq 1 -and
        [int]$r24d13PhysicalAttemptClosure.execution.world_build_count -eq 1 -and
        [int]$r24d13PhysicalAttemptClosure.execution.solver_step_count -eq 1 -and
        [int]$r24d13PhysicalAttemptClosure.execution.retained_sample_count -eq 4 -and
        [string]$r24d13PhysicalAttemptClosure.failure_diagnosis.evaluator_error_code -ceq
            "PARAMETER_brake_positive_public_maximum_motor_impulse_nms" -and
        [double]$r24d13PhysicalAttemptClosure.failure_diagnosis.native_serialized_public_maximum_motor_impulse_nms -eq
            [double]0.0020000000949949026 -and
        [double]$r24d13PhysicalAttemptClosure.failure_diagnosis.unreached_native_serialized_solver_step_s -eq
            [double]0.008333333767950535 -and
        -not [bool]$r24d13PhysicalAttemptClosure.failure_diagnosis.physics_negative -and
        [bool]$r24d13PhysicalAttemptClosure.failure_diagnosis.infrastructure_invalid_or_incomplete -and
        [bool]$r24d13PhysicalAttemptClosure.disposition.attempt_consumed -and
        [bool]$r24d13PhysicalAttemptClosure.disposition.same_source_rerun_forbidden -and
        -not [bool]$r24d13PhysicalAttemptClosure.disposition.raw_report_may_be_selectively_promoted -and
        [bool]$r24d13PhysicalAttemptClosure.claims.physical_characterization_executed -and
        -not [bool]$r24d13PhysicalAttemptClosure.claims.accepted_physical_characterization -and
        -not [bool]$r24d13PhysicalAttemptClosure.claims.native_braking_mechanism_activation_observed -and
        -not [bool]$r24d13PhysicalAttemptClosure.claims.release_authority -and
        [string]$r24d13PhysicalAttemptClosure.next_boundary.next_gate_id -ceq
            "QSDK-R24D14"
    ) "QSDK-R24D13 consumed-invalid physical closure drifted."
    Assert-True (
        [string]$r24d12PhysicalSupervisorQualificationClosure.schema_version -ceq
            "sporespore_qsdk_r24d12_physical_supervisor_qualification_positive_closure_v1" -and
        [string]$r24d12PhysicalSupervisorQualificationClosure.closure_id -ceq
            "QSDK-R24D12-PSQ1-CLOSURE" -and
        [string]$r24d12PhysicalSupervisorQualificationClosure.status -ceq
            "complete_physical_supervisor_preflight_passed_zero_world_only_authorization_separate" -and
        [string]$r24d12PhysicalSupervisorQualificationClosure.qualified_source_commit -ceq
            "a9f6eaad2ef59558bdee4ba87187ed0d27555f66" -and
        [string]$r24d12PhysicalSupervisorQualificationClosure.qualified_source_tree_git_oid -ceq
            "725131306a08689a2e5448d1bebd732ebb9fea24" -and
        [string]$r24d12PhysicalSupervisorQualificationClosure.qualification_receipt_raw_sha256 -ceq
            "sha256:cc4112fafa1fefd2d39627832851ae3780cf536eba539ea631b658cf04f99020" -and
        [int]$r24d12PhysicalSupervisorQualificationClosure.stage_count -eq 6 -and
        [int]$r24d12PhysicalSupervisorQualificationClosure.qualification.retained_file_count -eq 20 -and
        [int]$r24d12PhysicalSupervisorQualificationClosure.qualification.retained_unique_content_digest_count -eq 16 -and
        [int]$r24d12PhysicalSupervisorQualificationClosure.qualification.embedded_cas_reference_count -eq 15 -and
        [int]$r24d12PhysicalSupervisorQualificationClosure.qualification.embedded_unique_cas_digest_count -eq 12 -and
        [int]$r24d12PhysicalSupervisorQualificationClosure.world_attempt_count -eq 0 -and
        [int]$r24d12PhysicalSupervisorQualificationClosure.world_build_count -eq 0 -and
        [int]$r24d12PhysicalSupervisorQualificationClosure.solver_step_count -eq 0 -and
        [bool]$r24d12PhysicalSupervisorQualificationClosure.next_boundary.separate_parent_bound_authorization_commit_required -and
        [bool]$r24d12PhysicalSupervisorQualificationClosure.next_boundary.authorization_commit_must_be_direct_single_parent_child_of_qualified_source -and
        -not [bool]$r24d12PhysicalSupervisorQualificationClosure.next_boundary.physical_execution_authorized_by_this_closure -and
        [bool]$r24d12PhysicalSupervisorQualificationClosure.claims.physical_supervisor_preflight_passed -and
        -not [bool]$r24d12PhysicalSupervisorQualificationClosure.claims.physical_authorization -and
        -not [bool]$r24d12PhysicalSupervisorQualificationClosure.claims.release_authority -and
        [string]$r24d12PhysicalAuthorization.schema_version -ceq
            "sporespore_qsdk_r24d12_physical_authorization_v1" -and
        [string]$r24d12PhysicalAuthorization.status -ceq
            "authorized_one_bounded_native_development_attempt_parent_bound" -and
        [string]$r24d12PhysicalAuthorization.authorization_parent_commit -ceq
            "a9f6eaad2ef59558bdee4ba87187ed0d27555f66" -and
        -not ($r24d12PhysicalAuthorization.PSObject.Properties.Name -ccontains
            "authorization_commit") -and
        [bool]$r24d12PhysicalAuthorization.authorization_commit_derived_from_current_head -and
        [string]$r24d12PhysicalAuthorization.qualification_closure_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d12PhysicalSupervisorQualificationClosurePath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [int]$r24d12PhysicalAuthorization.physical_attempt_limit -eq 1 -and
        -not [bool]$r24d12PhysicalAuthorization.same_source_rerun_allowed -and
        [int]$r24d12PhysicalAuthorization.world_count -eq 1 -and
        [int]$r24d12PhysicalAuthorization.fixture_cell_count -eq 4 -and
        [int]$r24d12PhysicalAuthorization.solver_step_count -eq 1 -and
        [int]$r24d12PhysicalAuthorization.retained_sample_count -eq 4 -and
        [int]$r24d12PhysicalAuthorization.threshold_count -eq 0 -and
        [bool]$r24d12PhysicalAuthorization.physical_execution_authorized -and
        -not [bool]$r24d12PhysicalAuthorization.physical_acceptance_authority -and
        -not [bool]$r24d12PhysicalAuthorization.release_authority
    ) "QSDK-R24D12 physical-supervisor qualification and authorization drifted."
    Assert-True (
        [string]$r24d12PhysicalAttemptClosure.schema_version -ceq
            "sporespore_qsdk_r24d12_braking_mechanism_activation_physical_attempt_closure_v1" -and
        [string]$r24d12PhysicalAttemptClosure.closure_id -ceq
            "QSDK-R24D12-PHYSICAL-CLOSURE-V1" -and
        [string]$r24d12PhysicalAttemptClosure.status -ceq
            "closed_consumed_invalid_incomplete_after_one_world_float32_readback_exactness_rejection" -and
        [string]$r24d12PhysicalAttemptClosure.authorization.authorization_commit -ceq
            "0a15d68acef43d632089e1df15d2a0260848d826" -and
        [string]$r24d12PhysicalAttemptClosure.authorization.authorization_parent_commit -ceq
            "a9f6eaad2ef59558bdee4ba87187ed0d27555f66" -and
        -not [bool]$r24d12PhysicalAttemptClosure.authorization.same_source_rerun_allowed -and
        [int]$r24d12PhysicalAttemptClosure.retained_evidence.file_count -eq 15 -and
        [int]$r24d12PhysicalAttemptClosure.retained_evidence.total_byte_length -eq 78778 -and
        [int]$r24d12PhysicalAttemptClosure.retained_evidence.unique_content_digest_count -eq 13 -and
        -not [bool]$r24d12PhysicalAttemptClosure.retained_evidence.receipt_published -and
        -not [bool]$r24d12PhysicalAttemptClosure.retained_evidence.evaluation_published -and
        [int]$r24d12PhysicalAttemptClosure.execution.world_attempt_count -eq 1 -and
        [int]$r24d12PhysicalAttemptClosure.execution.world_build_count -eq 1 -and
        [int]$r24d12PhysicalAttemptClosure.execution.solver_step_count -eq 1 -and
        [int]$r24d12PhysicalAttemptClosure.execution.retained_sample_count -eq 4 -and
        [string]$r24d12PhysicalAttemptClosure.failure_diagnosis.evaluator_error_code -ceq
            "FIXTURE_CHILD_INERTIA_DIAGONAL_KG_M2" -and
        -not [bool]$r24d12PhysicalAttemptClosure.failure_diagnosis.physics_negative -and
        [bool]$r24d12PhysicalAttemptClosure.failure_diagnosis.infrastructure_invalid_or_incomplete -and
        [bool]$r24d12PhysicalAttemptClosure.disposition.attempt_consumed -and
        [bool]$r24d12PhysicalAttemptClosure.disposition.same_source_rerun_forbidden -and
        -not [bool]$r24d12PhysicalAttemptClosure.disposition.raw_report_may_be_selectively_promoted -and
        [bool]$r24d12PhysicalAttemptClosure.claims.physical_characterization_executed -and
        -not [bool]$r24d12PhysicalAttemptClosure.claims.accepted_physical_characterization -and
        -not [bool]$r24d12PhysicalAttemptClosure.claims.native_braking_mechanism_activation_observed -and
        -not [bool]$r24d12PhysicalAttemptClosure.claims.release_authority -and
        [string]$r24d12PhysicalAttemptClosure.next_boundary.next_gate_id -ceq
            "QSDK-R24D13"
    ) "QSDK-R24D12 consumed-invalid physical closure drifted."
    Assert-True (
        [string]$r24d12Preregistration.schema_version -ceq
            "sporespore_qsdk_r24d12_godot_jolt_braking_mechanism_activation_preregistration_v1" -and
        [string]$r24d12Preregistration.gate_id -ceq "QSDK-R24D12" -and
        [string]$r24d12Preregistration.question_class -ceq "development" -and
        [string]$r24d12Preregistration.status -ceq
            "prospective_minimal_braking_mechanism_source_implemented_zero_world_qualification_pending" -and
        [int]$r24d12Preregistration.fixture_freeze.world_count -eq 1 -and
        [int]$r24d12Preregistration.fixture_freeze.isolated_cell_count -eq 4 -and
        [int]$r24d12Preregistration.fixture_freeze.maximum_physics_step_count -eq 1 -and
        [int]$r24d12Preregistration.fixture_freeze.retained_sample_count -eq 4 -and
        [int]$r24d12Preregistration.adequacy.empirical_acceptance_threshold_count -eq 0 -and
        -not [bool]$r24d12Preregistration.execution_boundary.physical_execution_authorized_now -and
        -not [bool]$r24d12Preregistration.claims.complete_zero_world_gate_passed -and
        -not [bool]$r24d12Preregistration.claims.release_authority
    ) "QSDK-R24D12 preregistration drifted."
    Assert-True (
        [string]$r24d12ValidationManifest.schema_version -ceq
            "sporespore_qsdk_r24d12_godot_jolt_braking_mechanism_activation_validation_manifest_v1" -and
        [string]$r24d12ValidationManifest.gate_id -ceq "QSDK-R24D12" -and
        [string]$r24d12ValidationManifest.question_class -ceq "development" -and
        [string]$r24d12ValidationManifest.status -ceq
            "prospective_minimal_source_bytes_bound_zero_world_qualification_pending" -and
        @($r24d12ValidationManifest.source_bindings).Count -eq 15 -and
        [int]$r24d12ValidationManifest.source_mutation_rejection_count -eq 18 -and
        [int]$r24d12ValidationManifest.evaluator_invalid_mutation_rejection_count -eq 25 -and
        [int]$r24d12ValidationManifest.accepted_adverse_finite_outcome_count -eq 4 -and
        [int]$r24d12ValidationManifest.runtime_reuse_mutation_rejection_count -eq 8 -and
        [int]$r24d12ValidationManifest.official_zero_world_qualification_count -eq 0 -and
        [int]$r24d12ValidationManifest.world_attempt_count -eq 0 -and
        [int]$r24d12ValidationManifest.world_build_count -eq 0 -and
        [int]$r24d12ValidationManifest.solver_step_count -eq 0 -and
        [bool]$r24d12ValidationManifest.source_diagnosis_bound -and
        [bool]$r24d12ValidationManifest.complete_zero_world_gate_source_implemented -and
        -not [bool]$r24d12ValidationManifest.complete_zero_world_gate_passed -and
        -not [bool]$r24d12ValidationManifest.physical_authorization -and
        -not [bool]$r24d12ValidationManifest.release_authority
    ) "QSDK-R24D12 validation manifest drifted."
    Assert-True (
        [string]$r24d12ZeroWorldPositiveClosure.schema_version -ceq
            "sporespore_qsdk_r24d12_braking_mechanism_activation_zero_world_positive_closure_v1" -and
        [string]$r24d12ZeroWorldPositiveClosure.closure_id -ceq
            "QSDK-R24D12-ZW1-CLOSURE" -and
        [string]$r24d12ZeroWorldPositiveClosure.gate_id -ceq "QSDK-R24D12" -and
        [string]$r24d12ZeroWorldPositiveClosure.question_class -ceq "development" -and
        [string]$r24d12ZeroWorldPositiveClosure.status -ceq
            "complete_zero_world_gate_passed_physical_execution_still_forbidden_pending_explicit_separate_authorization" -and
        [string]$r24d12ZeroWorldPositiveClosure.source.commit -ceq
            "7b807819a6ed1d1864f5a5410bbb9b17667624e1" -and
        [string]$r24d12ZeroWorldPositiveClosure.source.tree_git_oid -ceq
            "b07a5f72720e69d542d0c44bd932dde63e4546a8" -and
        [bool]$r24d12ZeroWorldPositiveClosure.source.clean_pushed_before_qualification -and
        [bool]$r24d12ZeroWorldPositiveClosure.runtime_reuse.engine_build_reused -and
        -not [bool]$r24d12ZeroWorldPositiveClosure.runtime_reuse.campaign_result_reused -and
        -not [bool]$r24d12ZeroWorldPositiveClosure.runtime_reuse.physical_evidence_reused -and
        [int]$r24d12ZeroWorldPositiveClosure.zero_world_qualification.stage_count -eq 5 -and
        [int]$r24d12ZeroWorldPositiveClosure.zero_world_qualification.world_attempt_count -eq 0 -and
        [int]$r24d12ZeroWorldPositiveClosure.zero_world_qualification.world_build_count -eq 0 -and
        [int]$r24d12ZeroWorldPositiveClosure.zero_world_qualification.solver_step_count -eq 0 -and
        [int]$r24d12ZeroWorldPositiveClosure.zero_world_evaluation.cell_count -eq 4 -and
        [int]$r24d12ZeroWorldPositiveClosure.zero_world_evaluation.retained_sample_count -eq 4 -and
        -not [bool]$r24d12ZeroWorldPositiveClosure.zero_world_evaluation.native_braking_mechanism_activation_observed -and
        [int]$r24d12ZeroWorldPositiveClosure.retention.run_file_count -eq 19 -and
        [int]$r24d12ZeroWorldPositiveClosure.retention.run_unique_content_digest_count -eq 15 -and
        [int]$r24d12ZeroWorldPositiveClosure.retention.receipt_embedded_cas_reference_count -eq 14 -and
        [int]$r24d12ZeroWorldPositiveClosure.retention.receipt_embedded_unique_cas_digest_count -eq 11 -and
        [int]$r24d12ZeroWorldPositiveClosure.audit_contract.minimum_semantic_mutation_rejection_count -eq 30 -and
        [string]$r24d12ZeroWorldPositiveClosure.audit_contract.implementation_raw_sha256 -ceq
            ("sha256:" + (Get-FileHash -LiteralPath $r24d12ZeroWorldPositiveClosureAuditPath -Algorithm SHA256).Hash.ToLowerInvariant()) -and
        [bool]$r24d12ZeroWorldPositiveClosure.claims.complete_zero_world_gate_passed -and
        [bool]$r24d12ZeroWorldPositiveClosure.claims.corrected_activation_route_source_qualified -and
        -not [bool]$r24d12ZeroWorldPositiveClosure.claims.physical_characterization_executed -and
        -not [bool]$r24d12ZeroWorldPositiveClosure.claims.braking_mechanism_activated -and
        -not [bool]$r24d12ZeroWorldPositiveClosure.claims.prone_to_standing_world_opened -and
        -not [bool]$r24d12ZeroWorldPositiveClosure.claims.release_authority
    ) "QSDK-R24D12 zero-world positive closure drifted."
    Assert-True (
        [string]$r24d10PhysicalCharacterizationClosure.schema_version -ceq
            "sporespore_qsdk_r24d10_exact_step_numerical_telemetry_physical_characterization_closure_v1" -and
        [string]$r24d10PhysicalCharacterizationClosure.closure_id -ceq
            "QSDK-R24D10-PH1-CLOSURE" -and
        [string]$r24d10PhysicalCharacterizationClosure.question_class -ceq "development" -and
        [string]$r24d10PhysicalCharacterizationClosure.source.authorization_commit -ceq
            "9d2f8d59834c7cb9bf8271d0a10b3c2edcef7d22" -and
        [int]$r24d10PhysicalCharacterizationClosure.physical_attempt.world_attempt_count -eq 1 -and
        [int]$r24d10PhysicalCharacterizationClosure.physical_attempt.world_build_count -eq 1 -and
        [int]$r24d10PhysicalCharacterizationClosure.physical_attempt.solver_step_count -eq 20 -and
        [int]$r24d10PhysicalCharacterizationClosure.physical_attempt.retained_sample_count -eq 68 -and
        [int]$r24d10PhysicalCharacterizationClosure.statistical_claim_boundary.empirical_acceptance_threshold_count -eq 0 -and
        [int]$r24d10PhysicalCharacterizationClosure.statistical_claim_boundary.population_claim_count -eq 0 -and
        [bool]$r24d10PhysicalCharacterizationClosure.claims.valid_finite_descriptive_development_result -and
        [bool]$r24d10PhysicalCharacterizationClosure.claims.native_numerical_telemetry_characterized_for_exact_fixture -and
        -not [bool]$r24d10PhysicalCharacterizationClosure.claims.numerical_accuracy_accepted -and
        -not [bool]$r24d10PhysicalCharacterizationClosure.claims.instrumented_profile_promoted -and
        -not [bool]$r24d10PhysicalCharacterizationClosure.claims.prone_to_standing_world_opened -and
        -not [bool]$r24d10PhysicalCharacterizationClosure.claims.q_sdk_r24_satisfied -and
        -not [bool]$r24d10PhysicalCharacterizationClosure.claims.physical_acceptance_authority -and
        -not [bool]$r24d10PhysicalCharacterizationClosure.claims.release_authority
    ) "QSDK-R24D10 immutable physical characterization closure binding drifted."
    Assert-True (
        [string]$r24d10ZeroWorldPositiveClosure.schema_version -ceq
            "sporespore_qsdk_r24d10_exact_step_numerical_telemetry_zero_world_positive_closure_v1" -and
        [string]$r24d10ZeroWorldPositiveClosure.closure_id -ceq
            "QSDK-R24D10-ZW1-CLOSURE" -and
        [string]$r24d10ZeroWorldPositiveClosure.question_class -ceq "development" -and
        [string]$r24d10ZeroWorldPositiveClosure.source.commit -ceq
            "11df9b566dda911c6c3f1a8ad76369c8ee0c340e" -and
        [int]$r24d10ZeroWorldPositiveClosure.zero_world_qualification.stage_count -eq 7 -and
        [int]$r24d10ZeroWorldPositiveClosure.zero_world_qualification.world_attempt_count -eq 0 -and
        [int]$r24d10ZeroWorldPositiveClosure.zero_world_qualification.world_build_count -eq 0 -and
        [int]$r24d10ZeroWorldPositiveClosure.zero_world_qualification.solver_step_count -eq 0 -and
        [int]$r24d10ZeroWorldPositiveClosure.retention.run_file_count -eq 23 -and
        [int]$r24d10ZeroWorldPositiveClosure.retention.run_unique_content_digest_count -eq 19 -and
        [bool]$r24d10ZeroWorldPositiveClosure.claims.complete_zero_world_gate_passed -and
        -not [bool]$r24d10ZeroWorldPositiveClosure.claims.native_numerical_telemetry_characterized -and
        -not [bool]$r24d10ZeroWorldPositiveClosure.claims.prone_to_standing_world_opened -and
        -not [bool]$r24d10ZeroWorldPositiveClosure.claims.q_sdk_r24_satisfied -and
        -not [bool]$r24d10ZeroWorldPositiveClosure.claims.physical_authorization -and
        -not [bool]$r24d10ZeroWorldPositiveClosure.claims.release_authority
    ) "QSDK-R24D10 immutable zero-world positive closure binding drifted."
    Assert-True (
        [string]$r24d10PhysicalSupervisorContract.schema_version -ceq
            "sporespore_qsdk_r24d10_physical_supervisor_contract_v2" -and
        [string]$r24d10PhysicalSupervisorContract.question_class -ceq "development" -and
        [string]$r24d10PhysicalSupervisorContract.runtime_identity.executed_console_binary_raw_sha256 -ceq
            "sha256:ff655a567d31f51628d5b21742a0618e53f9fbf8a94937dd07d9882a0739872f" -and
        [string]$r24d10PhysicalSupervisorContract.runtime_identity.executed_engine_binary_raw_sha256 -ceq
            "sha256:2d68ed7ae53704ffb532cd5633241c74d599d69e3bf1968de0ef261553030ffb" -and
        [bool]$r24d10PhysicalSupervisorContract.runtime_identity.toolchain_provenance_is_not_executed_binary_identity -and
        [int]$r24d10PhysicalSupervisorContract.physical_schedule.world_count -eq 1 -and
        [int]$r24d10PhysicalSupervisorContract.physical_schedule.solver_step_count -eq 20 -and
        -not [bool]$r24d10PhysicalSupervisorContract.supervisor_preflight.separate_shortened_physics_ghost_required -and
        [int]$r24d10PhysicalSupervisorContract.supervisor_preflight.declared_stage_count -eq 7 -and
        -not [bool]$r24d10PhysicalSupervisorContract.authorization_boundary.physical_execution_authorized -and
        [bool]$r24d10PhysicalSupervisorContract.authorization_boundary.authorization_commit_must_be_direct_single_parent_child_of_qualified_source -and
        [bool]$r24d10PhysicalSupervisorContract.authorization_boundary.authorization_json_must_not_embed_its_own_commit_identity -and
        [bool]$r24d10PhysicalSupervisorContract.authorization_boundary.production_authorization_only_check_supported_before_attempt -and
        [string]$r24d10PhysicalSupervisorManifest.schema_version -ceq
            "sporespore_qsdk_r24d10_physical_supervisor_manifest_v2" -and
        [int]$r24d10PhysicalSupervisorManifest.source_binding_count -eq 19 -and
        [int]$r24d10PhysicalSupervisorManifest.declared_preflight_stage_count -eq 7 -and
        -not [bool]$r24d10PhysicalSupervisorManifest.physical_authorization -and
        -not [bool]$r24d10PhysicalSupervisorManifest.release_authority
    ) "QSDK-R24D10 prospective physical-supervisor source boundary drifted."
    Assert-True (
        [string]$r24d10FirstSupervisorAdoptionRefusal.schema_version -ceq
            "sporespore_qsdk_r24d10_first_physical_supervisor_qualification_adoption_refusal_v1" -and
        [string]$r24d10FirstSupervisorAdoptionRefusal.question_class -ceq
            "development" -and
        [string]$r24d10FirstSupervisorAdoptionRefusal.source.commit -ceq
            "be6365cea71351519c796cefa4ec3900eed77539" -and
        [string]$r24d10FirstSupervisorAdoptionRefusal.qualification.receipt_raw_sha256 -ceq
            "sha256:fd380507caa22c5bb15c4e98a9235e5528436f92148603534ff6c8bea2925119" -and
        [int]$r24d10FirstSupervisorAdoptionRefusal.qualification.stage_count -eq 6 -and
        [int]$r24d10FirstSupervisorAdoptionRefusal.qualification.world_attempt_count -eq 0 -and
        [int]$r24d10FirstSupervisorAdoptionRefusal.qualification.world_build_count -eq 0 -and
        [int]$r24d10FirstSupervisorAdoptionRefusal.qualification.solver_step_count -eq 0 -and
        [bool]$r24d10FirstSupervisorAdoptionRefusal.claims.v1_physical_supervisor_preflight_passed -and
        [bool]$r24d10FirstSupervisorAdoptionRefusal.claims.v1_adoption_refused -and
        -not [bool]$r24d10FirstSupervisorAdoptionRefusal.claims.physical_authorization -and
        -not [bool]$r24d10FirstSupervisorAdoptionRefusal.claims.physical_characterization_executed -and
        -not [bool]$r24d10FirstSupervisorAdoptionRefusal.claims.release_authority
    ) "QSDK-R24D10 v1 qualification adoption-refusal boundary drifted."
    Assert-True (
        [string]$r24d10PhysicalSupervisorQualificationClosure.schema_version -ceq
            "sporespore_qsdk_r24d10_physical_supervisor_qualification_positive_closure_v2" -and
        [string]$r24d10PhysicalSupervisorQualificationClosure.qualified_source_commit -ceq
            "b2bccdb76041a46a5d51ba56129f014e6c0dbf95" -and
        [string]$r24d10PhysicalSupervisorQualificationClosure.qualification_receipt_raw_sha256 -ceq
            "sha256:a260a3c1a883487e5615fd1de82d8d6b05a5deefbf484bf82e266b4a73412cd7" -and
        [int]$r24d10PhysicalSupervisorQualificationClosure.stage_count -eq 7 -and
        [int]$r24d10PhysicalSupervisorQualificationClosure.world_attempt_count -eq 0 -and
        [int]$r24d10PhysicalSupervisorQualificationClosure.world_build_count -eq 0 -and
        [int]$r24d10PhysicalSupervisorQualificationClosure.solver_step_count -eq 0 -and
        [bool]$r24d10PhysicalSupervisorQualificationClosure.claims.v2_physical_supervisor_preflight_passed -and
        -not [bool]$r24d10PhysicalSupervisorQualificationClosure.claims.physical_authorization -and
        -not [bool]$r24d10PhysicalSupervisorQualificationClosure.claims.release_authority -and
        [string]$r24d10PhysicalAuthorization.schema_version -ceq
            "sporespore_qsdk_r24d10_physical_authorization_v2" -and
        [string]$r24d10PhysicalAuthorization.authorization_parent_commit -ceq
            "b2bccdb76041a46a5d51ba56129f014e6c0dbf95" -and
        -not ($r24d10PhysicalAuthorization.PSObject.Properties.Name -ccontains
            "authorization_commit") -and
        [bool]$r24d10PhysicalAuthorization.authorization_commit_derived_from_current_head -and
        [int]$r24d10PhysicalAuthorization.physical_attempt_limit -eq 1 -and
        [int]$r24d10PhysicalAuthorization.world_count -eq 1 -and
        [int]$r24d10PhysicalAuthorization.solver_step_count -eq 20 -and
        [bool]$r24d10PhysicalAuthorization.physical_execution_authorized -and
        -not [bool]$r24d10PhysicalAuthorization.physical_acceptance_authority -and
        -not [bool]$r24d10PhysicalAuthorization.release_authority
    ) "QSDK-R24D10 v2 qualification and authorization boundary drifted."
    Assert-True (
        [string]$r24d1Design.schema_version -ceq
            "sporespore_qsdk_r24d1_canonical_prone_to_standing_design_v1" -and
        [string]$r24d1Design.question_class -ceq
            "non_physical_source_conformance" -and
        [bool]$r24d1Design.complete_zero_world_program.design_declaration_gate_passed -and
        -not [bool]$r24d1Design.complete_zero_world_program.complete_prephysical_gate_passed -and
        [int]$r24d1Design.complete_zero_world_program.world_attempt_count -eq 0 -and
        [int]$r24d1Design.complete_zero_world_program.world_build_count -eq 0 -and
        -not [bool]$r24d1Design.claim_boundary.canonical_prone_to_standing -and
        -not [bool]$r24d1Design.claim_boundary.q_sdk_r24_satisfied
    ) "QSDK-R24D1 declaration was promoted beyond design authority"
    Assert-True (
        [string]$r24d2Semantics.schema_version -ceq
            "sporespore_qsdk_r24d2_portable_recovery_semantics_contract_v1" -and
        [string]$r24d2Semantics.question_class -ceq
            "non_physical_source_conformance" -and
        [string]$r24d2Semantics.answer -ceq "partial_fail_closed" -and
        [bool]$r24d2Semantics.portable_semantics.observation_schema_implemented -and
        [bool]$r24d2Semantics.portable_semantics.pose_and_contact_classifier_implemented -and
        [bool]$r24d2Semantics.portable_semantics.ordered_phase_supervisor_implemented -and
        [bool]$r24d2Semantics.portable_semantics.candidate_and_matched_zero_evaluator_implemented -and
        [int]$r24d2Semantics.adapter_capabilities.godot_jolt4_7.supported_channel_count -eq 8 -and
        [int]$r24d2Semantics.adapter_capabilities.godot_jolt4_7.unsupported_channel_count -eq 2 -and
        -not [bool]$r24d2Semantics.native_capability_conjunction.complete -and
        -not [bool]$r24d2Semantics.complete_zero_world_program.complete_prephysical_gate_passed -and
        [int]$r24d2Semantics.complete_zero_world_program.world_build_count -eq 0 -and
        -not [bool]$r24d2Semantics.claim_boundary.canonical_prone_to_standing -and
        -not [bool]$r24d2Semantics.claim_boundary.q_sdk_r24_satisfied -and
        [string]$r24d2Manifest.gate_id -ceq "QSDK-R24D2" -and
        -not [bool]$r24d2Manifest.release_authority
    ) "QSDK-R24D2 source boundary was promoted beyond its partial result"
    Assert-True (
        [string]$r24d3Source.schema_version -ceq
            "sporespore_qsdk_r24d3_godot_jolt_motor_telemetry_source_contract_v1" -and
        [string]$r24d3Source.gate_id -ceq "QSDK-R24D3" -and
        [string]$r24d3Source.question_class -ceq
            "non_physical_source_conformance" -and
        [bool]$r24d3Source.claims.custom_engine_compiles -and
        [bool]$r24d3Source.claims.zero_world_binding_reachable -and
        -not [bool]$r24d3Source.claims.instrumented_godot_capability_promoted -and
        -not [bool]$r24d3Source.claims.native_measurement_accuracy_claimed -and
        -not [bool]$r24d3Source.claims.physical_recovery_world_opened -and
        -not [bool]$r24d3Source.claims.q_sdk_r24_satisfied -and
        [string]$r24d3Manifest.gate_id -ceq "QSDK-R24D3" -and
        [int]$r24d3Manifest.source_binding_count -eq 14 -and
        -not [bool]$r24d3Manifest.instrumented_capability_promoted -and
        -not [bool]$r24d3Manifest.release_authority -and
        [string]$r24d3Adoption.status -ceq
            "adopted_artifact_complete_cold_build_characterization_withheld" -and
        [bool]$r24d3Adoption.adopted_claim_boundary.clean_pushed_cold_build_qualified -and
        -not [bool]$r24d3Adoption.adopted_claim_boundary.instrumented_godot_capability_promoted -and
        -not [bool]$r24d3Adoption.adopted_claim_boundary.release_authority -and
        [string]$r24d3FullColdQualification.status -ceq
            "qualified_exact_adoption_source_full_cold_conformance_characterization_withheld" -and
        [bool]$r24d3FullColdQualification.adequacy_and_claim_boundary.post_adoption_full_cold_conformance_prerequisite_satisfied -and
        -not [bool]$r24d3FullColdQualification.adequacy_and_claim_boundary.instrumented_godot_capability_promoted -and
        -not [bool]$r24d3FullColdQualification.adequacy_and_claim_boundary.release_authority
    ) "QSDK-R24D3 source contract or manifest boundary drifted."
    Assert-True (
        [string]$r24d4Preregistration.schema_version -ceq
            "sporespore_qsdk_r24d4_godot_jolt_one_hinge_telemetry_characterization_preregistration_v1" -and
        [string]$r24d4Preregistration.gate_id -ceq "QSDK-R24D4" -and
        [string]$r24d4Preregistration.question_class -ceq "development" -and
        [string]$r24d4Preregistration.status -ceq
            "prospectively_frozen_zero_world_gate_pending_physical_execution_forbidden" -and
        [int]$r24d4Preregistration.threshold_margin_cohort_and_population_adequacy.empirical_acceptance_threshold_count -eq 0 -and
        [int]$r24d4Preregistration.threshold_margin_cohort_and_population_adequacy.superiority_margin_count -eq 0 -and
        [int]$r24d4Preregistration.threshold_margin_cohort_and_population_adequacy.equivalence_or_non_inferiority_margin_count -eq 0 -and
        [int]$r24d4Preregistration.threshold_margin_cohort_and_population_adequacy.validation_cohort_identity_count -eq 0 -and
        [int]$r24d4Preregistration.threshold_margin_cohort_and_population_adequacy.population_claim_count -eq 0 -and
        -not [bool]$r24d4Preregistration.physical_authorization.permitted_now -and
        [int]$r24d4Preregistration.physical_authorization.world_attempt_count -eq 0 -and
        [int]$r24d4Preregistration.physical_authorization.world_build_count -eq 0 -and
        -not [bool]$r24d4Preregistration.physical_authorization.physical_result_exists -and
        [bool]$r24d4Preregistration.claims.source_and_oracle_freeze_declared -and
        -not [bool]$r24d4Preregistration.claims.complete_zero_world_gate_passed -and
        -not [bool]$r24d4Preregistration.claims.physical_characterization_executed -and
        -not [bool]$r24d4Preregistration.claims.instrumented_profile_promoted -and
        -not [bool]$r24d4Preregistration.claims.recovery_world_opened -and
        -not [bool]$r24d4Preregistration.claims.prone_to_standing_world_opened -and
        -not [bool]$r24d4Preregistration.claims.q_sdk_r24_satisfied -and
        -not [bool]$r24d4Preregistration.claims.physical_acceptance_authority -and
        -not [bool]$r24d4Preregistration.claims.release_authority -and
        [string]$r24d4Manifest.gate_id -ceq "QSDK-R24D4" -and
        [string]$r24d4Manifest.question_class -ceq "development" -and
        [int]$r24d4Manifest.source_binding_count -eq 7 -and
        [int]$r24d4Manifest.fixture_cell_count -eq 9 -and
        [int]$r24d4Manifest.retained_sample_count -eq 68 -and
        [int]$r24d4Manifest.evaluator_negative_control_count -eq 22 -and
        [int]$r24d4Manifest.accepted_outcome_mutation_count -eq 2 -and
        [int]$r24d4Manifest.empirical_acceptance_threshold_count -eq 0 -and
        [int]$r24d4Manifest.superiority_margin_count -eq 0 -and
        [int]$r24d4Manifest.equivalence_or_non_inferiority_margin_count -eq 0 -and
        [int]$r24d4Manifest.population_claim_count -eq 0 -and
        -not [bool]$r24d4Manifest.complete_zero_world_gate_passed -and
        -not [bool]$r24d4Manifest.physical_characterization_executed -and
        -not [bool]$r24d4Manifest.instrumented_profile_promoted -and
        [int]$r24d4Manifest.world_attempt_count -eq 0 -and
        [int]$r24d4Manifest.world_build_count -eq 0 -and
        [int]$r24d4Manifest.solver_step_count -eq 0 -and
        -not [bool]$r24d4Manifest.recovery_world_opened -and
        -not [bool]$r24d4Manifest.prone_to_standing_world_opened -and
        -not [bool]$r24d4Manifest.physical_acceptance_authority -and
        -not [bool]$r24d4Manifest.release_authority
    ) "QSDK-R24D4 source freeze or validation manifest was promoted."
    Assert-True (
        [string]$r24d4Closure.schema_version -ceq
            "sporespore_qsdk_r24d4_one_hinge_telemetry_zero_world_failure_closure_v1" -and
        [string]$r24d4Closure.status -ceq
            "valid_zero_world_negative_source_oracle_axis_mismatch" -and
        [string]$r24d4Closure.source.commit -ceq
            "6e24a729bac03e02cf247583f5e321040b4b011a" -and
        -not [bool]$r24d4Closure.attempt.worker_receipt_ok -and
        [int]$r24d4Closure.attempt.world_attempt_count -eq 0 -and
        [int]$r24d4Closure.attempt.world_build_count -eq 0 -and
        [int]$r24d4Closure.attempt.solver_step_count -eq 0 -and
        [bool]$r24d4Closure.diagnosis.failure_occurred_before_world_construction -and
        [bool]$r24d4Closure.immutability.same_source_physical_open_forbidden -and
        -not [bool]$r24d4Closure.claims.release_authority
    ) "QSDK-R24D4 zero-world failure closure was promoted."
    Assert-True (
        [string]$r24d5Preregistration.schema_version -ceq
            "sporespore_qsdk_r24d5_godot_jolt_one_hinge_telemetry_characterization_preregistration_v1" -and
        [string]$r24d5Preregistration.gate_id -ceq "QSDK-R24D5" -and
        [string]$r24d5Preregistration.question_class -ceq "development" -and
        [string]$r24d5Preregistration.status -ceq
            "prospectively_frozen_axis_oracle_successor_zero_world_gate_pending_physical_execution_forbidden" -and
        (@($r24d5Preregistration.fixture_freeze.hinge_axis_parent_local) -join ",") -ceq
            "0,0,1" -and
        [int]$r24d5Preregistration.negative_controls.declared_count -eq 24 -and
        -not [bool]$r24d5Preregistration.physical_authorization.permitted_now -and
        [int]$r24d5Preregistration.physical_authorization.world_attempt_count -eq 0 -and
        -not [bool]$r24d5Preregistration.claims.complete_zero_world_gate_passed -and
        -not [bool]$r24d5Preregistration.claims.release_authority -and
        [string]$r24d5Manifest.gate_id -ceq "QSDK-R24D5" -and
        [int]$r24d5Manifest.source_binding_count -eq 10 -and
        [int]$r24d5Manifest.evaluator_negative_control_count -eq 24 -and
        [int]$r24d5Manifest.contract_mutation_rejection_count -eq 14 -and
        [int]$r24d5Manifest.world_attempt_count -eq 0 -and
        -not [bool]$r24d5Manifest.complete_zero_world_gate_passed -and
        -not [bool]$r24d5Manifest.physical_characterization_executed -and
        -not [bool]$r24d5Manifest.release_authority -and
        [string]$r24d5Diagnostics.status -ceq
            "retained_invalid_and_incomplete_precommit_diagnostics" -and
        [int]$r24d5Diagnostics.finite_counts.diagnostic_attempt_count -eq 4 -and
        [int]$r24d5Diagnostics.finite_counts.physical_world_count -eq 0 -and
        -not [bool]$r24d5Diagnostics.claims.release_authority -and
        [string]$r24d5PhysicalClosure.schema_version -ceq
            "sporespore_qsdk_r24d5_one_hinge_telemetry_physical_failure_closure_v1" -and
        [string]$r24d5PhysicalClosure.status -ceq
            "worker_execution_complete_evaluation_invalid_fixture_json_identity_mismatch" -and
        [string]$r24d5PhysicalClosure.source.commit -ceq
            "fffb773b408b0cf8bb4a3ba78e773b62c3a0e52a" -and
        [int]$r24d5PhysicalClosure.attempt.world_attempt_count -eq 1 -and
        [int]$r24d5PhysicalClosure.attempt.world_build_count -eq 1 -and
        [int]$r24d5PhysicalClosure.attempt.physics_step_count -eq 20 -and
        [int]$r24d5PhysicalClosure.attempt.retained_sample_count -eq 68 -and
        [int]$r24d5PhysicalClosure.attempt.evaluator_exit_code -eq 2 -and
        -not [bool]$r24d5PhysicalClosure.attempt.same_source_rerun_allowed -and
        -not [bool]$r24d5PhysicalClosure.claims.valid_descriptive_development_characterization -and
        -not [bool]$r24d5PhysicalClosure.claims.turning_claim_changed -and
        -not [bool]$r24d5PhysicalClosure.claims.prone_to_standing_world_opened -and
        -not [bool]$r24d5PhysicalClosure.claims.release_authority -and
        ("sha256:" + (
            Get-FileHash -LiteralPath $r24d5PhysicalClosurePath -Algorithm SHA256
        ).Hash.ToLowerInvariant()) -ceq
            [string]$releaseR24D5.physical_failure_closure_raw_sha256 -and
        ("sha256:" + (
            Get-FileHash -LiteralPath $r24d5PhysicalClosureAuditPath -Algorithm SHA256
        ).Hash.ToLowerInvariant()) -ceq
            [string]$releaseR24D5.physical_failure_closure_audit_raw_sha256
    ) "QSDK-R24D5 frozen source or consumed invalid result was promoted."
    Assert-True (
        [string]$r24d6Preregistration.schema_version -ceq
            "sporespore_qsdk_r24d6_godot_jolt_one_hinge_telemetry_characterization_preregistration_v1" -and
        [string]$r24d6Preregistration.gate_id -ceq "QSDK-R24D6" -and
        [string]$r24d6Preregistration.question_class -ceq "development" -and
        [string]$r24d6Preregistration.status -ceq
            "prospectively_frozen_serialized_envelope_successor_zero_world_gate_pending_physical_execution_forbidden" -and
        [string]$r24d6Preregistration.predecessor_implementation_invalid_result.gate_id -ceq
            "QSDK-R24D5" -and
        [bool]$r24d6Preregistration.predecessor_implementation_invalid_result.r24d5_source_evaluator_worker_or_result_repair_forbidden -and
        [int]$r24d6Preregistration.pinned_godot_numeric_source_provenance.files.Count -eq 5 -and
        [int]$r24d6Preregistration.negative_controls.declared_count -eq 29 -and
        [int]$r24d6Preregistration.threshold_margin_cohort_and_population_adequacy.empirical_acceptance_threshold_count -eq 0 -and
        [int]$r24d6Preregistration.threshold_margin_cohort_and_population_adequacy.validation_cohort_identity_count -eq 0 -and
        -not [bool]$r24d6Preregistration.physical_authorization.permitted_now -and
        [int]$r24d6Preregistration.physical_authorization.world_attempt_count -eq 0 -and
        -not [bool]$r24d6Preregistration.claims.complete_zero_world_gate_passed -and
        -not [bool]$r24d6Preregistration.claims.release_authority -and
        [string]$r24d6Manifest.gate_id -ceq "QSDK-R24D6" -and
        [string]$r24d6Manifest.status -ceq
            "prospective_serialized_envelope_maintenance_successor_after_incomplete_static_dependency_failure_official_zero_world_pending_physical_execution_forbidden" -and
        [int]$r24d6Manifest.source_binding_count -eq 11 -and
        [int]$r24d6Manifest.prior_official_zero_world_qualification_failure_count -eq 1 -and
        [string]$r24d6Manifest.prior_official_zero_world_qualification_failure_source_commit -ceq
            "ef540fa50ce9d155aa5d78bbef04070b62dc0a76" -and
        [int]$r24d6Manifest.official_zero_world_qualification_count -eq 0 -and
        [int]$r24d6Manifest.pinned_godot_numeric_source_binding_count -eq 5 -and
        [int]$r24d6Manifest.evaluator_negative_control_count -eq 29 -and
        [int]$r24d6Manifest.contract_mutation_rejection_count -eq 18 -and
        [int]$r24d6Manifest.binary32_projection_control_count -eq 5 -and
        [int]$r24d6Manifest.serialized_runtime_negative_control_count -eq 1 -and
        [int]$r24d6Manifest.serialized_runtime_positive_control_count -eq 1 -and
        [int]$r24d6Manifest.world_attempt_count -eq 0 -and
        [int]$r24d6Manifest.world_build_count -eq 0 -and
        [int]$r24d6Manifest.solver_step_count -eq 0 -and
        -not [bool]$r24d6Manifest.complete_zero_world_gate_passed -and
        -not [bool]$r24d6Manifest.physical_characterization_executed -and
        -not [bool]$r24d6Manifest.release_authority -and
        [string]$r24d6Diagnostics.status -ceq
            "retained_one_parser_negative_then_passing_distinct_source_revision" -and
        [int]$r24d6Diagnostics.finite_counts.parser_attempt_count -eq 2 -and
        [int]$r24d6Diagnostics.finite_counts.parser_negative_count -eq 1 -and
        [int]$r24d6Diagnostics.finite_counts.parser_pass_count -eq 1 -and
        [int]$r24d6Diagnostics.finite_counts.official_zero_world_qualification_count -eq 0 -and
        [int]$r24d6Diagnostics.finite_counts.physical_world_count -eq 0 -and
        -not [bool]$r24d6Diagnostics.claims.complete_zero_world_gate_passed -and
        -not [bool]$r24d6Diagnostics.claims.release_authority -and
        [string]$r24d6FirstQualificationFailure.schema_version -ceq
            "sporespore_qsdk_r24d6_first_official_zero_world_qualification_failure_v1" -and
        [string]$r24d6FirstQualificationFailure.status -ceq
            "incomplete_static_dependency_manifest_drift_before_worker_launch" -and
        [string]$r24d6FirstQualificationFailure.attempt.source_commit -ceq
            "ef540fa50ce9d155aa5d78bbef04070b62dc0a76" -and
        [int]$r24d6FirstQualificationFailure.attempt.attempted_static_stage_count -eq 3 -and
        [int]$r24d6FirstQualificationFailure.attempt.passed_static_stage_count -eq 2 -and
        [int]$r24d6FirstQualificationFailure.attempt.failed_static_stage_count -eq 1 -and
        [int]$r24d6FirstQualificationFailure.attempt.worker_launch_count -eq 0 -and
        [int]$r24d6FirstQualificationFailure.attempt.godot_process_launch_count -eq 0 -and
        [int]$r24d6FirstQualificationFailure.attempt.real_evaluator_envelope_invocation_count -eq 0 -and
        [int]$r24d6FirstQualificationFailure.attempt.world_attempt_count -eq 0 -and
        -not [bool]$r24d6FirstQualificationFailure.claims.complete_zero_world_gate_passed -and
        -not [bool]$r24d6FirstQualificationFailure.claims.release_authority -and
        [string]$r24d6ZeroWorldFailureClosure.schema_version -ceq
            "sporespore_qsdk_r24d6_one_hinge_telemetry_zero_world_failure_closure_v1" -and
        [string]$r24d6ZeroWorldFailureClosure.status -ceq
            "valid_zero_world_negative_full_precision_integral_variant_type_loss" -and
        [string]$r24d6ZeroWorldFailureClosure.source.commit -ceq
            "55032839756cc8a9089a2a4eb4e06db71ab99ca4" -and
        [int]$r24d6ZeroWorldFailureClosure.attempt.static_audit_stage_pass_count -eq 5 -and
        [int]$r24d6ZeroWorldFailureClosure.attempt.serializer_call_count -eq 2 -and
        [int]$r24d6ZeroWorldFailureClosure.diagnosis.integer_to_double_projection_count -eq 313 -and
        [int]$r24d6ZeroWorldFailureClosure.diagnosis.strict_evaluator_integer_projection_count -eq 234 -and
        [int]$r24d6ZeroWorldFailureClosure.retained_file_count -eq 18 -and
        [int]$r24d6ZeroWorldFailureClosure.retained_unique_digest_count -eq 17 -and
        [int]$r24d6ZeroWorldFailureClosure.attempt.world_attempt_count -eq 0 -and
        [int]$r24d6ZeroWorldFailureClosure.attempt.world_build_count -eq 0 -and
        [int]$r24d6ZeroWorldFailureClosure.attempt.solver_step_count -eq 0 -and
        [bool]$r24d6ZeroWorldFailureClosure.claims.default_precision_negative_control_passed -and
        -not [bool]$r24d6ZeroWorldFailureClosure.claims.full_precision_positive_control_passed -and
        -not [bool]$r24d6ZeroWorldFailureClosure.claims.prone_to_standing_world_opened -and
        -not [bool]$r24d6ZeroWorldFailureClosure.claims.turning_claim_changed -and
        -not [bool]$r24d6ZeroWorldFailureClosure.claims.release_authority -and
        ("sha256:" + (
            Get-FileHash -LiteralPath $r24d6ZeroWorldFailureClosurePath -Algorithm SHA256
        ).Hash.ToLowerInvariant()) -ceq
            [string]$releaseR24D6.zero_world_failure_closure_raw_sha256 -and
        ("sha256:" + (
            Get-FileHash -LiteralPath $r24d6ZeroWorldFailureClosureAuditPath -Algorithm SHA256
        ).Hash.ToLowerInvariant()) -ceq
            [string]$releaseR24D6.zero_world_failure_closure_audit_raw_sha256
    ) "QSDK-R24D6 source freeze, diagnostics, or immutable zero-world result was promoted."
    Assert-True (
        [string]$r24d7Preregistration.schema_version -ceq
            "sporespore_qsdk_r24d7_godot_jolt_one_hinge_telemetry_characterization_preregistration_v1" -and
        [string]$r24d7Preregistration.gate_id -ceq "QSDK-R24D7" -and
        [string]$r24d7Preregistration.question_class -ceq "development" -and
        [string]$r24d7Preregistration.status -ceq
            "prospectively_declared_integral_variant_successor_zero_world_gate_pending_physical_execution_forbidden" -and
        [string]$r24d7Preregistration.predecessor_zero_world_negative.gate_id -ceq
            "QSDK-R24D6" -and
        [int]$r24d7Preregistration.predecessor_zero_world_negative.observed_integer_to_double_projection_count -eq 313 -and
        [int]$r24d7Preregistration.serialized_runtime_controls.declared_integral_path_family_count -eq 21 -and
        [int]$r24d7Preregistration.serialized_runtime_controls.declared_integral_occurrence_count -eq 313 -and
        [int]$r24d7Preregistration.serialized_runtime_controls.predecessor_strict_integral_occurrence_count -eq 234 -and
        [int]$r24d7Preregistration.negative_controls.total_declared_count -eq 50 -and
        -not [bool]$r24d7Preregistration.physical_authorization.permitted_now -and
        [int]$r24d7Preregistration.physical_authorization.world_attempt_count -eq 0 -and
        -not [bool]$r24d7Preregistration.claims.complete_zero_world_gate_passed -and
        -not [bool]$r24d7Preregistration.claims.release_authority -and
        [string]$r24d7Manifest.gate_id -ceq "QSDK-R24D7" -and
        [int]$r24d7Manifest.source_binding_count -eq 11 -and
        [int]$r24d7Manifest.integral_path_family_count -eq 21 -and
        [int]$r24d7Manifest.integral_occurrence_count -eq 313 -and
        [int]$r24d7Manifest.predecessor_strict_integral_occurrence_count -eq 234 -and
        [int]$r24d7Manifest.evaluator_total_negative_control_count -eq 50 -and
        [int]$r24d7Manifest.contract_mutation_rejection_count -eq 22 -and
        [int]$r24d7Manifest.world_attempt_count -eq 0 -and
        [int]$r24d7Manifest.world_build_count -eq 0 -and
        [int]$r24d7Manifest.solver_step_count -eq 0 -and
        -not [bool]$r24d7Manifest.complete_zero_world_gate_passed -and
        -not [bool]$r24d7Manifest.release_authority -and
        [string]$r24d7IntegralSchema.schema_id -ceq
            "QSDK-R24D7-INTEGRAL-VARIANT-SCHEMA-V1" -and
        [int]$r24d7IntegralSchema.finite_counts.path_family_count -eq 21 -and
        [int]$r24d7IntegralSchema.finite_counts.concrete_occurrence_count -eq 313 -and
        [int]$r24d7IntegralSchema.finite_counts.predecessor_strict_occurrence_count -eq 234 -and
        [int]$r24d7IntegralSchema.finite_counts.r24d7_strict_occurrence_count -eq 313 -and
        [int]$r24d7IntegralSchema.finite_counts.family_type_loss_negative_control_count -eq 21 -and
        [int]$r24d7IntegralSchema.finite_counts.physical_world_count -eq 0 -and
        -not [bool]$r24d7IntegralSchema.claims.complete_zero_world_gate_passed -and
        -not [bool]$r24d7IntegralSchema.claims.release_authority -and
        [string]$r24d7Diagnostics.status -ceq
            "retained_single_parser_pass_current_prospective_source" -and
        [int]$r24d7Diagnostics.finite_counts.parser_attempt_count -eq 1 -and
        [int]$r24d7Diagnostics.finite_counts.parser_negative_count -eq 0 -and
        [int]$r24d7Diagnostics.finite_counts.parser_pass_count -eq 1 -and
        [int]$r24d7Diagnostics.finite_counts.official_zero_world_qualification_count -eq 0 -and
        [int]$r24d7Diagnostics.finite_counts.physical_world_count -eq 0 -and
        -not [bool]$r24d7Diagnostics.claims.complete_zero_world_gate_passed -and
        -not [bool]$r24d7Diagnostics.claims.release_authority
    ) "QSDK-R24D7 prospective source was promoted beyond its zero-world authority."

    $reportPath = Join-Path $testRoot "current\report.json"
    $report = Invoke-ReadinessCompiler -OutputFile $reportPath
    Assert-True (
        Test-Path -LiteralPath $reportPath -PathType Leaf
    ) "Compiler did not atomically retain report.json"
    Assert-True (
        [string]$report.schema_version -ceq
        "sporespore_quadruped_sdk_release_readiness_report_v1"
    ) "Unexpected readiness report schema"
    Assert-True (
        [string]$report.status -ceq "blocked"
    ) "Incomplete quadruped SDK must remain blocked"
    Assert-True (
        -not [bool]$report.release_ready -and
        -not [bool]$report.package_authorized -and
        -not [bool]$report.publication_authorized -and
        -not [bool]$report.clean_room_candidate_authorized -and
        -not [bool]$report.clean_room_candidate_publication_authorized
    ) "Blocked evidence must not authorize release, packaging, or publication"
    Assert-True (
        [int]$report.gate_counts.total -eq 29 -and
        [int]$report.gate_counts.informational -eq 4 -and
        [int]$report.gate_counts.required_for_release -eq 25 -and
        [int]$report.gate_counts.required_passed -eq 14 -and
        [int]$report.gate_counts.required_missing -eq 8 -and
        [int]$report.gate_counts.required_contradicted -eq 3 -and
        [int]$report.gate_counts.required_invalid_proof -eq 0 -and
        [int]$report.gate_counts.informational_invalid_proof -eq 0
    ) "Current gate disposition counts drifted"

    $expectedBlockers = @(
        "QSDK-R01",
        "QSDK-R06",
        "QSDK-R07",
        "QSDK-R09",
        "QSDK-R10",
        "QSDK-R11",
        "QSDK-R12",
        "QSDK-R16",
        "QSDK-R19",
        "QSDK-R20",
        "QSDK-R25"
    )
    Assert-True (
        (@($report.blocking_gate_ids) -join "|") -ceq
        ($expectedBlockers -join "|")
    ) "Blocking gate IDs drifted"
    $expectedCandidateBlockers = @(
        "QSDK-R06",
        "QSDK-R07",
        "QSDK-R09",
        "QSDK-R10",
        "QSDK-R11",
        "QSDK-R12",
        "QSDK-R19",
        "QSDK-R25"
    )
    Assert-True (
        (@($report.clean_room_candidate_validation_gate_ids) -join "|") -ceq
        "QSDK-R01|QSDK-R16|QSDK-R20"
    ) "Clean-room candidate validation gate IDs drifted"
    Assert-True (
        [int]$report.clean_room_candidate_prerequisite_gate_count -eq 22 -and
        [int]$report.clean_room_candidate_validation_gate_count -eq 3 -and
        [bool]$report.two_stage_package_flow_satisfiable
    ) "Two-stage package flow is structurally unsatisfiable"
    Assert-True (
        (@($report.clean_room_candidate_blocking_gate_ids) -join "|") -ceq
        ($expectedCandidateBlockers -join "|")
    ) "Clean-room candidate blocking gate IDs drifted"
    Assert-True (
        -not [bool]$report.claims.standalone_quadruped_sdk_released -and
        -not [bool]$report.claims.arbitrary_quadruped_coverage -and
        -not [bool]$report.claims.continuous_full_volume_coverage -and
        -not [bool]$report.claims.formal_cross_engine_comparative_inference -and
        [bool]$report.claims.command_conditioned_turning -and
        [bool]$report.claims.prone_to_standing -and
        -not [bool]$report.claims.tier2_learned_adaptation -and
        -not [bool]$report.claims.tier3_online_adaptation -and
        -not [bool]$report.claims.completed_engine_neutral_sdk -and
        -not [bool]$report.claims.physical_acceptance_authority
    ) "A blocked compiler result promoted an unsupported claim"
    Assert-True (
        [bool]$report.support_matrix.consistent_with_gate_dispositions -and
        @($report.support_matrix.failures).Count -eq 0
    ) "Current support matrix disagrees with current gate dispositions"

    Assert-True (
        (Test-Path -LiteralPath $sdk1MappingPath -PathType Leaf) -and
        (Test-Path -LiteralPath $sdk1CompilerPath -PathType Leaf)
    ) "SDK1 milestone mapping or compiler is missing"
    $sdk1Report = Invoke-Sdk1MilestoneCompiler
    Assert-True (
        [string]$sdk1Report.schema_version -ceq
            "sporespore_quadruped_sdk1_milestone_readiness_report_v1" -and
        [string]$sdk1Report.status -ceq "blocked" -and
        -not [bool]$sdk1Report.sdk1_milestones_complete -and
        -not [bool]$sdk1Report.mapping_completion_authorizes_release
    ) "SDK1 milestone compiler escaped its bounded tracking authority"
    Assert-True (
        [int]$sdk1Report.sdk1_counts.total -eq 20 -and
        [int]$sdk1Report.sdk1_counts.passed -eq 14 -and
        [int]$sdk1Report.sdk1_counts.missing -eq 5 -and
        [int]$sdk1Report.sdk1_counts.contradicted -eq 1 -and
        [int]$sdk1Report.sdk1_counts.invalid_proof -eq 0 -and
        [int]$sdk1Report.full_program.required_passed -eq 14 -and
        [int]$sdk1Report.full_program.required_total -eq 25 -and
        -not [bool]$sdk1Report.full_program.denominator_changed
    ) "SDK1 14/20 milestone disposition drifted"
    Assert-True (
        (@($sdk1Report.deferred_full_program_gate_ids) -join "|") -ceq
        "QSDK-R06|QSDK-R07|QSDK-R09|QSDK-R11|QSDK-R12|QSDK-R25"
    ) "SDK1 deferred full-program gate population drifted"
    Assert-True (
        -not [bool]$sdk1Report.clean_room_candidate_authorized -and
        -not [bool]$sdk1Report.clean_room_candidate_release_authorized -and
        -not [bool]$sdk1Report.clean_room_candidate_publication_authorized -and
        [string]$sdk1Report.clean_room_candidate_artifact_role -ceq
            "sdk1_clean_room_conformance_candidate"
    ) "Blocked SDK1 state escaped its candidate claim boundary"
    Assert-True (
        (@($sdk1Report.clean_room_candidate_validation_milestone_ids) -join "|") -ceq
            "SDK1-M01|SDK1-M11|SDK1-M15" -and
        (@($sdk1Report.clean_room_candidate_validation_gate_ids) -join "|") -ceq
            "QSDK-R01|QSDK-R16|QSDK-R20" -and
        [int]$sdk1Report.clean_room_candidate_prerequisite_milestone_count -eq 17 -and
        [int]$sdk1Report.clean_room_candidate_validation_milestone_count -eq 3 -and
        [bool]$sdk1Report.two_stage_package_flow_satisfiable
    ) "SDK1 candidate stage no longer proves its exact 17+3 partition"
    Assert-True (
        (@($sdk1Report.clean_room_candidate_blocking_milestone_ids) -join "|") -ceq
            "SDK1-M07|SDK1-M14|SDK1-M20" -and
        (@($sdk1Report.clean_room_candidate_deferred_full_program_gate_ids_ignored) -join "|") -ceq
            "QSDK-R06|QSDK-R07|QSDK-R09|QSDK-R11|QSDK-R12|QSDK-R25" -and
        -not [bool]$sdk1Report.claims.clean_room_candidate_is_full_program_candidate -and
        -not [bool]$sdk1Report.claims.clean_room_candidate_is_release
    ) "SDK1 candidate prerequisites or full-program boundary drifted"
    $sdk1Morphology = @($sdk1Report.milestones | Where-Object {
        [string]$_.milestone_id -ceq "SDK1-M05"
    })
    $sdk1GodotEnvelope = @($sdk1Report.milestones | Where-Object {
        [string]$_.milestone_id -ceq "SDK1-M08"
    })
    $sdk1Turning = @($sdk1Report.milestones | Where-Object {
        [string]$_.milestone_id -ceq "SDK1-M18"
    })
    $sdk1Prone = @($sdk1Report.milestones | Where-Object {
        [string]$_.milestone_id -ceq "SDK1-M19"
    })
    $sdk1Explorer = @($sdk1Report.milestones | Where-Object {
        [string]$_.milestone_id -ceq "SDK1-M20"
    })
    Assert-True (
        $sdk1Morphology.Count -eq 1 -and
        [string]$sdk1Morphology[0].disposition -ceq "passed" -and
        $sdk1GodotEnvelope.Count -eq 1 -and
        [string]$sdk1GodotEnvelope[0].disposition -ceq "passed" -and
        $sdk1Turning.Count -eq 1 -and
        [string]$sdk1Turning[0].disposition -ceq "passed" -and
        $sdk1Prone.Count -eq 1 -and
        [string]$sdk1Prone[0].disposition -ceq "passed" -and
        $sdk1Explorer.Count -eq 1 -and
        [string]$sdk1Explorer[0].disposition -ceq "missing" -and
        -not [bool]$sdk1Report.claims.formal_cross_engine_equivalence_required_for_sdk1 -and
        -not [bool]$sdk1Report.claims.arbitrary_or_continuous_morphology_required_for_sdk1 -and
        [bool]$sdk1Report.claims.same_canonical_semantics_in_three_native_engines_required -and
        -not [bool]$sdk1Report.claims.sdk1_released -and
        -not [bool]$sdk1Report.claims.publication_authorized
    ) "SDK1 movement, scope, or release claims drifted"

    $sdk1RequireCandidateRefused = $false
    try {
        & $sdk1CompilerPath -RequireCandidate 6>$null | Out-Null
    } catch {
        $sdk1RequireCandidateRefused = (
            $_.Exception.Message -like
                "*Quadruped SDK1 clean-room candidate is blocked by:*"
        )
    }
    Assert-True (
        $sdk1RequireCandidateRefused
    ) "SDK1 -RequireCandidate did not fail closed"

    $tamperedSdk1Mapping = (
        Get-Content -Raw -LiteralPath $sdk1MappingPath |
            ConvertFrom-Json -Depth 100
    )
    $tamperedSdk1Mapping.clean_room_candidate_stage.validation_milestone_ids = @(
        "SDK1-M01",
        "SDK1-M02",
        "SDK1-M15"
    )
    $tamperedSdk1MappingPath = Join-Path $testRoot "tampered_sdk1_mapping.json"
    [System.IO.File]::WriteAllText(
        $tamperedSdk1MappingPath,
        ($tamperedSdk1Mapping | ConvertTo-Json -Depth 100) + "`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    $tamperedSdk1CandidateStageRefused = $false
    try {
        & $sdk1CompilerPath `
            -Mapping $tamperedSdk1MappingPath `
            6>$null |
            Out-Null
    } catch {
        $tamperedSdk1CandidateStageRefused = (
            $_.Exception.Message -like
                "*validation milestones must be exactly M01, M11, and M15*"
        )
    }
    Assert-True (
        $tamperedSdk1CandidateStageRefused
    ) "SDK1 compiler accepted a mutated candidate-stage partition"

    Assert-True (
        Test-Path -LiteralPath $sdk1CandidateAuthorityClosurePath -PathType Leaf
    ) "SDK1 candidate-authority closure is missing"
    $sdk1CandidateClosure = (
        Get-Content -Raw -LiteralPath $sdk1CandidateAuthorityClosurePath |
            ConvertFrom-Json -Depth 100
    )
    Assert-True (
        [string]$sdk1CandidateClosure.schema_version -ceq
            "sporespore_quadruped_sdk1_candidate_authority_closure_v1" -and
        [string]$sdk1CandidateClosure.status -ceq
            "closed_zero_world_sdk1_candidate_authority_candidate_blocked" -and
        [string]$sdk1CandidateClosure.ledger_scope.subsystem -ceq "release" -and
        [string]$sdk1CandidateClosure.ledger_scope.engine_scope -ceq
            "engine_neutral" -and
        [string]$sdk1CandidateClosure.ledger_scope.question_class -ceq
            "development"
    ) "SDK1 candidate-authority closure identity or ledger scope drifted"
    $sdk1CandidateReportPath = [System.IO.Path]::GetFullPath(
        [string]$sdk1CandidateClosure.retained_readiness_report.path
    )
    Assert-True (
        Test-Path -LiteralPath $sdk1CandidateReportPath -PathType Leaf
    ) "SDK1 candidate-authority retained report is missing"
    Assert-True (
        ("sha256:" + (
            Get-FileHash -Algorithm SHA256 -LiteralPath $sdk1CandidateReportPath
        ).Hash.ToLowerInvariant()) -ceq
            [string]$sdk1CandidateClosure.retained_readiness_report.sha256 -and
        (Get-Item -LiteralPath $sdk1CandidateReportPath).Length -eq
            [long]$sdk1CandidateClosure.retained_readiness_report.byte_length
    ) "SDK1 candidate-authority retained report identity drifted"
    $sdk1CandidateRetainedReport = (
        Get-Content -Raw -LiteralPath $sdk1CandidateReportPath |
            ConvertFrom-Json -Depth 100
    )
    Assert-True (
        [string]$sdk1CandidateRetainedReport.source.commit -ceq
            [string]$sdk1CandidateClosure.implementation_source.commit -and
        [string]$sdk1CandidateRetainedReport.source.origin_main -ceq
            [string]$sdk1CandidateClosure.implementation_source.origin_main -and
        [bool]$sdk1CandidateRetainedReport.source.clean -and
        [bool]$sdk1CandidateRetainedReport.source.matches_origin_main -and
        -not [bool]$sdk1CandidateRetainedReport.clean_room_candidate_authorized
    ) "SDK1 candidate-authority report source or authorization drifted"
    # This closure is immutable historical evidence. Verify the exact blobs at
    # the commit that added the closure rather than requiring today's mutable
    # release ledger and tests to remain byte-identical forever.
    $sdk1CandidateClosureCommit =
        "79be0f9c62944ccbed581e72c84fc5ec84fac1af"
    $sdk1CandidateClosureParent = @(
        & git -C $repoRoot rev-parse "$sdk1CandidateClosureCommit^" 2>$null
    )
    Assert-True (
        $LASTEXITCODE -eq 0 -and
        $sdk1CandidateClosureParent.Count -eq 1 -and
        [string]$sdk1CandidateClosureParent[0] -ceq
            [string]$sdk1CandidateClosure.implementation_source.commit
    ) "SDK1 candidate-authority closure topology drifted"
    $sdk1CandidateClosureIdentity = Get-GitBlobIdentity `
        -Commit $sdk1CandidateClosureCommit `
        -RelativePath (
            "sdk/release/" +
            "quadruped_sdk1_candidate_authority_closure_v1.json"
        )
    Assert-True (
        $sdk1CandidateClosureIdentity.sha256 -ceq (
            "sha256:" + (
                Get-FileHash `
                    -Algorithm SHA256 `
                    -LiteralPath $sdk1CandidateAuthorityClosurePath
            ).Hash.ToLowerInvariant()
        ) -and
        $sdk1CandidateClosureIdentity.byte_length -eq
            (Get-Item -LiteralPath $sdk1CandidateAuthorityClosurePath).Length
    ) "SDK1 candidate-authority closure no longer matches its historical blob"
    foreach ($authority in @($sdk1CandidateClosure.bound_authorities)) {
        $authorityIdentity = Get-GitBlobIdentity `
            -Commit $sdk1CandidateClosureCommit `
            -RelativePath ([string]$authority.path)
        Assert-True (
            [string]$authorityIdentity.sha256 -ceq [string]$authority.sha256 -and
            [long]$authorityIdentity.byte_length -eq
                [long]$authority.byte_length
        ) "SDK1 candidate historical authority drifted: $($authority.path)"
    }
    Assert-True (
        [int]$sdk1CandidateClosure.candidate_partition.prerequisite_milestone_count -eq
            17 -and
        [int]$sdk1CandidateClosure.candidate_partition.validation_milestone_count -eq
            3 -and
        (@($sdk1CandidateClosure.candidate_partition.validation_milestone_ids) -join "|") -ceq
            "SDK1-M01|SDK1-M11|SDK1-M15" -and
        (@($sdk1CandidateClosure.observed_readiness.candidate_blocking_milestone_ids) -join "|") -ceq
            "SDK1-M05|SDK1-M07|SDK1-M08|SDK1-M14|SDK1-M20" -and
        -not [bool]$sdk1CandidateClosure.claims.release_authorized -and
        -not [bool]$sdk1CandidateClosure.claims.publication_authorized -and
        -not [bool]$sdk1CandidateClosure.claims.physical_acceptance_authority
    ) "SDK1 candidate-authority closure partition or claim boundary drifted"
    Assert-True (
        [int]$sdk1CandidateClosure.execution.physics_engine_process_count -eq 0 -and
        [int]$sdk1CandidateClosure.execution.physics_model_construction_count -eq 0 -and
        [int]$sdk1CandidateClosure.execution.world_build_count -eq 0 -and
        [int]$sdk1CandidateClosure.execution.native_physics_read_count -eq 0 -and
        [int]$sdk1CandidateClosure.execution.solver_step_count -eq 0
    ) "SDK1 candidate-authority closure is not zero-world"

    $overwriteRefused = $false
    try {
        Invoke-ReadinessCompiler -OutputFile $reportPath | Out-Null
    } catch {
        $overwriteRefused = (
            $_.Exception.Message -like
            "*Refusing to overwrite quadruped readiness output*"
        )
    }
    Assert-True $overwriteRefused "Existing report.json was not protected"

    $requireReadyRefused = $false
    try {
        & $compilerPath -RequireReady 6>$null | Out-Null
    } catch {
        $requireReadyRefused = (
            $_.Exception.Message -like
            "*Quadruped SDK release is blocked by:*"
        )
    }
    Assert-True (
        $requireReadyRefused
    ) "-RequireReady did not fail closed"
    $requireCandidateRefused = $false
    try {
        & $compilerPath -RequireCandidate 6>$null | Out-Null
    } catch {
        $requireCandidateRefused = (
            $_.Exception.Message -like
            "*Quadruped SDK clean-room candidate is blocked by:*"
        )
    }
    Assert-True (
        $requireCandidateRefused
    ) "-RequireCandidate did not fail closed"

    $tamperedContractPath = Join-Path $testRoot "tampered_contract.json"
    $tamperedContract = (
        Get-Content -Raw -LiteralPath $contractPath |
            ConvertFrom-Json
    )
    $rapierGate = @(
        $tamperedContract.gates |
            Where-Object { $_.gate_id -ceq "QSDK-I03" }
    )
    Assert-True (
        $rapierGate.Count -eq 1
    ) "Could not find the Rapier informational proof"
    $passedCellsPredicate = @(
        $rapierGate[0].proof.predicates |
            Where-Object { $_.path -ceq "passed_cells" }
    )
    Assert-True (
        $passedCellsPredicate.Count -eq 1
    ) "Could not find the Rapier passed_cells predicate"
    $passedCellsPredicate[0].equals = 999
    [System.IO.File]::WriteAllText(
        $tamperedContractPath,
        (
            $tamperedContract |
                ConvertTo-Json -Depth 100
        ) + "`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    $tamperedReport = Invoke-ReadinessCompiler `
        -ContractFile $tamperedContractPath
    Assert-True (
        [int]$tamperedReport.gate_counts.informational_invalid_proof -eq 1
    ) "Tampered evidence predicate was not rejected"
    $invalidGateIds = @(
        $tamperedReport.gates |
            Where-Object { $_.disposition -ceq "invalid_proof" } |
            ForEach-Object { $_.gate_id }
    )
    Assert-True (
        ($invalidGateIds -join "|") -ceq "QSDK-I03"
    ) "Tampered proof did not fail at the expected gate"

    $tamperedMatrixPath = Join-Path $testRoot "tampered_support_matrix.json"
    $tamperedMatrix = (
        Get-Content -Raw -LiteralPath $supportMatrixPath |
            ConvertFrom-Json
    )
    $tamperedMatrix.release_authorized = $true
    [System.IO.File]::WriteAllText(
        $tamperedMatrixPath,
        (
            $tamperedMatrix |
                ConvertTo-Json -Depth 100
        ) + "`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    $tamperedMatrixReport = Invoke-ReadinessCompiler `
        -SupportMatrixFile $tamperedMatrixPath
    Assert-True (
        -not [bool](
            $tamperedMatrixReport.support_matrix.
                consistent_with_gate_dispositions
        )
    ) "Premature support-matrix authorization was not rejected"
    Assert-True (
        @(
            $tamperedMatrixReport.support_matrix.failures |
                Where-Object {
                    $_.path -ceq "release_authorized" -and
                    $_.failure_code -ceq
                    "SUPPORT_MATRIX_GATE_DISAGREEMENT"
                }
        ).Count -eq 1
    ) "Support-matrix disagreement did not identify release_authorized"
    Assert-True (
        @($tamperedMatrixReport.blocking_conditions) -contains
        "QSDK-SUPPORT-MATRIX-CONSISTENCY"
    ) "Support-matrix disagreement was not release-blocking"

    $checkpoint = (
        Get-Content -Raw -LiteralPath $checkpointPath |
            ConvertFrom-Json
    )
    Assert-True (
        [string]$checkpoint.schema_version -ceq
        "sporespore_quadruped_sdk_readiness_checkpoint_manifest_v1"
    ) "Unexpected readiness checkpoint manifest schema"
    Assert-True (
        Test-Path -LiteralPath ([string]$checkpoint.report.path) -PathType Leaf
    ) "Durable readiness checkpoint report is missing"
    $checkpointReportHash = (
        "sha256:" +
        (
            Get-FileHash `
                -Algorithm SHA256 `
                -LiteralPath ([string]$checkpoint.report.path)
        ).Hash.ToLowerInvariant()
    )
    Assert-True (
        $checkpointReportHash -ceq [string]$checkpoint.report.sha256
    ) "Durable readiness checkpoint report hash drifted"
    $checkpointReport = (
        Get-Content -Raw -LiteralPath ([string]$checkpoint.report.path) |
            ConvertFrom-Json
    )
    Assert-True (
        [string]$checkpointReport.source.commit -ceq
        [string]$checkpoint.source_commit -and
        [bool]$checkpointReport.source.clean -and
        [bool]$checkpointReport.source.matches_origin_main
    ) "Checkpoint no longer proves clean pushed source"
    Assert-True (
        [string]$checkpointReport.contract.sha256 -ceq
        [string]$checkpoint.contract.sha256 -and
        [string]$checkpointReport.support_matrix.sha256 -ceq
        [string]$checkpoint.support_matrix.sha256
    ) "Checkpoint contract or support-matrix identity drifted"
    Assert-True (
        [int]$checkpointReport.gate_counts.required_passed -eq 11 -and
        [int]$checkpointReport.gate_counts.required_missing -eq 10 -and
        [int]$checkpointReport.gate_counts.required_contradicted -eq 4 -and
        [int]$checkpointReport.gate_counts.required_invalid_proof -eq 0 -and
        [int]$checkpointReport.gate_counts.informational_invalid_proof -eq 0
    ) "Checkpoint gate disposition counts drifted"
    Assert-True (
        [int]$checkpoint.clean_room_candidate.prerequisite_gate_count -eq
        22 -and
        [int]$checkpoint.clean_room_candidate.validation_gate_count -eq 3 -and
        [bool]$checkpoint.clean_room_candidate.two_stage_package_flow_satisfiable -and
        -not (
            @($checkpoint.clean_room_candidate.blocking_gate_ids) -contains
            "QSDK-R02"
        )
    ) "Current checkpoint does not preserve the 22/3 package partition"

    $twoStageCheckpoint = (
        Get-Content -Raw -LiteralPath $twoStageCheckpointPath |
            ConvertFrom-Json
    )
    Assert-True (
        [string]$twoStageCheckpoint.schema_version -ceq
        "sporespore_quadruped_sdk_two_stage_readiness_checkpoint_manifest_v1"
    ) "Unexpected two-stage readiness checkpoint schema"
    Assert-True (
        Test-Path `
            -LiteralPath ([string]$twoStageCheckpoint.report.path) `
            -PathType Leaf
    ) "Durable two-stage readiness report is missing"
    $twoStageReportHash = (
        "sha256:" +
        (
            Get-FileHash `
                -Algorithm SHA256 `
                -LiteralPath ([string]$twoStageCheckpoint.report.path)
        ).Hash.ToLowerInvariant()
    )
    Assert-True (
        $twoStageReportHash -ceq
        [string]$twoStageCheckpoint.report.sha256
    ) "Durable two-stage readiness report hash drifted"
    $twoStageReport = (
        Get-Content `
            -Raw `
            -LiteralPath ([string]$twoStageCheckpoint.report.path) |
                ConvertFrom-Json
    )
    Assert-True (
        [string]$twoStageReport.source.commit -ceq
        [string]$twoStageCheckpoint.source_commit -and
        [bool]$twoStageReport.source.clean -and
        [bool]$twoStageReport.source.matches_origin_main
    ) "Two-stage checkpoint no longer proves clean pushed source"
    Assert-True (
        [bool]$twoStageReport.two_stage_package_flow_satisfiable -and
        [int]$twoStageReport.clean_room_candidate_prerequisite_gate_count -eq
        17 -and
        [int]$twoStageReport.clean_room_candidate_validation_gate_count -eq
        3 -and
        (
            @($twoStageReport.clean_room_candidate_validation_gate_ids) -join
            "|"
        ) -ceq "QSDK-R01|QSDK-R16|QSDK-R20"
    ) "Two-stage checkpoint does not prove a 17+3 satisfiable partition"
    Assert-True (
        [string]$twoStageReport.contract.sha256 -ceq
        [string]$twoStageCheckpoint.contract.sha256 -and
        [string]$twoStageReport.support_matrix.sha256 -ceq
        [string]$twoStageCheckpoint.support_matrix.sha256
    ) "Two-stage checkpoint source identities drifted"

    $forgedReport = (
        Get-Content -Raw -LiteralPath $reportPath |
            ConvertFrom-Json
    )
    $forgedReport.status = "ready"
    $forgedReport.release_ready = $true
    $forgedReport.package_authorized = $true
    $forgedReport.publication_authorized = $true
    $forgedReport.blocking_gate_ids = @()
    $forgedReportPath = Join-Path $testRoot "forged_report.json"
    [System.IO.File]::WriteAllText(
        $forgedReportPath,
        (
            $forgedReport |
                ConvertTo-Json -Depth 100
        ) + "`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    $forgedOutputPath = Join-Path $testRoot "forged_package"
    $forgedReportRefused = $false
    try {
        & $packagerPath `
            -ReadinessReport $forgedReportPath `
            -OutputDirectory $forgedOutputPath `
            6>$null |
            Out-Null
    } catch {
        $forgedReportRefused = $true
    }
    Assert-True (
        $forgedReportRefused
    ) "Packager trusted a forged ready report"
    Assert-True (
        -not (Test-Path -LiteralPath $forgedOutputPath)
    ) "Blocked packager created an output directory"

    $forgedCandidate = (
        Get-Content -Raw -LiteralPath $reportPath |
            ConvertFrom-Json
    )
    $forgedCandidate.clean_room_candidate_authorized = $true
    $forgedCandidate.clean_room_candidate_blocking_gate_ids = @()
    $forgedCandidatePath = Join-Path $testRoot "forged_candidate.json"
    [System.IO.File]::WriteAllText(
        $forgedCandidatePath,
        (
            $forgedCandidate |
                ConvertTo-Json -Depth 100
        ) + "`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    $forgedCandidateOutputPath = Join-Path $testRoot "forged_candidate"
    $forgedCandidateRefused = $false
    try {
        & $packagerPath `
            -ReadinessReport $forgedCandidatePath `
            -OutputDirectory $forgedCandidateOutputPath `
            -CleanRoomCandidate `
            6>$null |
            Out-Null
    } catch {
        $forgedCandidateRefused = $true
    }
    Assert-True (
        $forgedCandidateRefused
    ) "Packager trusted a forged clean-room candidate authorization"
    Assert-True (
        -not (Test-Path -LiteralPath $forgedCandidateOutputPath)
    ) "Blocked clean-room candidate created an output directory"

    & pwsh `
        -NoProfile `
        -File $qsdkR01Sdk1CandidateBridgeTestPath `
        6>$null |
        Out-Null
    Assert-True (
        $LASTEXITCODE -eq 0
    ) "QSDK-R01 bounded SDK1 candidate bridge audit failed"

    Write-Host (
        "Quadruped SDK release-readiness tests passed: " +
        "33/33 contract gates classified, satisfiable two-stage package " +
        "flow, bounded SDK1 bridge, and fail-closed interlocks verified."
    )
} finally {
    $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
    $expectedPrefix = $systemTempRoot + [System.IO.Path]::DirectorySeparatorChar
    Assert-True (
        $resolvedTestRoot.StartsWith(
            $expectedPrefix,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        [System.IO.Path]::GetFileName($resolvedTestRoot).StartsWith(
            "sporespore_quadruped_release_test_",
            [StringComparison]::Ordinal
        )
    ) "Refusing to clean an unexpected test path: $resolvedTestRoot"
    if (Test-Path -LiteralPath $resolvedTestRoot) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}

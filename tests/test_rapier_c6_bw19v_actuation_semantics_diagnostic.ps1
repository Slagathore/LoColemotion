#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$diagnosticPath = Join-Path (
    $repoRoot
) "sdk\rapier_c6_bw19v_actuation_semantics_diagnostic.json"
$expectedDiagnosticRawSha256 = (
    "a42888f04c9a42af78ab3796dee9cc98365592470f81d0153bc55ab2a375ca57"
)
$expectedSourceCommit = "22ca385a80070c3cbbc1d71a341dd4a879f8bfce"
$expectedEd1ReportSha256 = (
    "145431d9ba1583e3c65c2d86460aa06c4d3dbd7f4f45be6d11580383a4f4e1fd"
)

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Near {
    param(
        [double]$Actual,
        [double]$Expected,
        [string]$Message,
        [double]$Tolerance = 1.0e-14
    )
    Assert-Exact (
        [double]::IsFinite($Actual) -and
        [Math]::Abs($Actual - $Expected) -le $Tolerance
    ) "$Message actual=$Actual expected=$Expected"
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Get-ByteSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return [Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-GitBlobBytes {
    param(
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$Path
    )
    $gitPath = (Get-Command git -ErrorAction Stop).Source
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $gitPath
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    [void]$startInfo.ArgumentList.Add("-C")
    [void]$startInfo.ArgumentList.Add($repoRoot)
    [void]$startInfo.ArgumentList.Add("cat-file")
    [void]$startInfo.ArgumentList.Add("blob")
    [void]$startInfo.ArgumentList.Add("$Commit`:$Path")

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $stream = [System.IO.MemoryStream]::new()
    try {
        [void]$process.Start()
        $process.StandardOutput.BaseStream.CopyTo($stream)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-Exact (
            $process.ExitCode -eq 0
        ) "Unable to read source blob $Commit`:$Path`: $stderr"
        [byte[]]$bytes = $stream.ToArray()
        return ,$bytes
    } finally {
        $stream.Dispose()
        $process.Dispose()
    }
}

function Assert-ContainsExact {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Needle,
        [Parameter(Mandatory)][string]$Message
    )
    Assert-Exact ($Text.Contains($Needle)) $Message
}

function Copy-JsonObject {
    param([Parameter(Mandatory)][object]$Value)
    return $Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json
}

function Get-DiagnosticGateFailures {
    param([Parameter(Mandatory)][object]$Candidate)
    $failures = [System.Collections.Generic.List[string]]::new()

    if (
        [string]$Candidate.schema_version -cne
            "sporespore_rapier_c6_bw19v_actuation_semantics_diagnostic_v1" -or
        [string]$Candidate.diagnostic_id -cne "C6-RAP-BW19V-ASD1" -or
        [string]$Candidate.status -cne
            "retained_zero_world_and_existing_trace_source_diagnostic_not_acceptance" -or
        [string]$Candidate.study_class -cne
            "posthoc_source_and_retained_trace_semantics_diagnostic"
    ) {
        $failures.Add("identity")
    }
    if (
        [string]$Candidate.audited_source.commit -cne $expectedSourceCommit -or
        -not [bool]$Candidate.audited_source.clean -or
        -not [bool]$Candidate.audited_source.matches_origin_main
    ) {
        $failures.Add("audited_source")
    }
    if (
        [int]$Candidate.world_build_count -ne 0 -or
        [int]$Candidate.scene_insertion_count -ne 0 -or
        [int]$Candidate.physics_state_mutation_count -ne 0 -or
        [int]$Candidate.new_physical_observation_count -ne 0
    ) {
        $failures.Add("zero_world_boundary")
    }
    if (
        [string]$Candidate.source_artifacts.repository_sha256_scope -cne
            "git_blob_bytes_at_audited_source_commit" -or
        [string]$Candidate.source_artifacts.rapier_source_sha256_scope -cne
            "installed_registry_source_file_bytes"
    ) {
        $failures.Add("source_hash_scope")
    }

    $portable = $Candidate.source_reconstruction.portable_selected_policy
    if (
        [double]$portable.position_gain_per_s -ne 8.0 -or
        [double]$portable.rate_damping -ne 0.65 -or
        [double]$portable.legacy_motor_direction_sign -ne -1.0 -or
        -not [bool]$portable.target_velocity_is_already_complete_closed_loop_feedback -or
        [bool]$portable.emitted_target_velocity_is_canonical -or
        -not [bool]$portable.host_specific_sign_is_embedded_in_portable_core
    ) {
        $failures.Add("portable_reconstruction")
    }

    $godot = $Candidate.source_reconstruction.godot_jolt_realization
    if (
        [string]$godot.declared_actuator_model -cne
            "hinge_target_velocity_with_impulse_cap" -or
        [string]$godot.declared_position_target_route -cne
            "adapter_pd_to_velocity" -or
        [double]$godot.declared_host_target_velocity_sign_per_canonical_positive -ne
            -1.0 -or
        [string]$godot.load_bearing_native_parameter -cne
            "HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY" -or
        [bool]$godot.independent_native_position_spring_applied -or
        -not [bool]$godot.existing_portable_emitted_velocity_matches_legacy_host_command
    ) {
        $failures.Add("godot_reconstruction")
    }

    $rapier = $Candidate.source_reconstruction.rapier_realization
    if (
        [double]$rapier.declared_canonical_to_host_velocity_sign -ne 1.0 -or
        [bool]$rapier.base_velocity_sign_conversion_applied -or
        -not [bool]$rapier.canonical_residual_sign_conversion_applied -or
        -not [bool]$rapier.base_and_residual_velocity_spaces_mixed -or
        [string]$rapier.motor_model -cne "ForceBased" -or
        [double]$rapier.stiffness_nm_per_rad -ne 40.0 -or
        [double]$rapier.damping_nm_s_per_rad -ne 10.0 -or
        -not [bool]$rapier.portable_position_applied_as_native_spring_target -or
        -not [bool]$rapier.portable_velocity_applied_as_native_velocity_target -or
        -not [bool]$rapier.additional_native_position_feedback_present
    ) {
        $failures.Add("rapier_reconstruction")
    }

    $counterexample = $Candidate.source_reconstruction.analytic_zero_state_counterexample
    if (
        [double]$counterexample.requested_target_position_rad -ne 0.3 -or
        [double]$counterexample.measured_position_rad -ne 0.0 -or
        [double]$counterexample.measured_velocity_rad_s -ne 0.0 -or
        [double]$counterexample.raw_canonical_velocity_rad_s -ne 2.4 -or
        [double]$counterexample.portable_emitted_legacy_godot_host_velocity_rad_s -ne
            -2.4 -or
        [double]$counterexample.rapier_unlimited_nominal_force_nm -ne -12.0 -or
        [bool]$counterexample.rapier_force_sign_matches_position_error
    ) {
        $failures.Add("analytic_counterexample")
    }

    $trace = $Candidate.retained_ed1_step_zero_observation
    if (
        [string]$trace.arm_id -cne "ED1-A" -or
        [int]$trace.semantic_step -ne 0 -or
        [int]$trace.nonzero_position_target_count -ne 5 -or
        [int]$trace.opposite_position_and_velocity_target_sign_count -ne 5 -or
        [int]$trace.opposite_position_target_and_post_step_angle_sign_count -ne 5 -or
        [int]$trace.matching_velocity_target_and_post_step_angle_sign_count -ne 5 -or
        -not [bool]$trace.semantic_mismatch_physically_active -or
        [bool]$trace.whole_body_failure_causation_established -or
        [bool]$trace.posthoc_acceptance_threshold
    ) {
        $failures.Add("retained_trace_boundary")
    }

    $diagnosis = $Candidate.diagnosis
    if (
        [string]$diagnosis.classification -cne
            "confirmed_cross_host_actuation_semantics_defect_with_unresolved_whole_body_causal_effect" -or
        [bool]$diagnosis.working_godot_architecture_killed -or
        [bool]$diagnosis.rapier_engine_architecture_killed -or
        [bool]$diagnosis.portable_policy_mechanism_disproved -or
        [bool]$diagnosis.ed1_reclassified -or
        [bool]$diagnosis.cross_engine_selected_policy_equivalence_at_audited_source -or
        [bool]$diagnosis.additional_rapier_physical_world_allowed_before_successor_freeze
    ) {
        $failures.Add("diagnosis_boundary")
    }

    foreach ($property in $Candidate.successor_contract.PSObject.Properties) {
        if ($property.Name -eq "classification") {
            if (
                [string]$property.Value -cne
                    "new_versioned_semantic_correction_then_distinct_host_characterization"
            ) {
                $failures.Add("successor_classification")
            }
        } elseif (-not [bool]$property.Value) {
            $failures.Add("successor_requirement:$($property.Name)")
        }
    }
    foreach ($property in $Candidate.negative_controls.PSObject.Properties) {
        if (-not [bool]$property.Value) {
            $failures.Add("negative_control:$($property.Name)")
        }
    }
    foreach ($property in $Candidate.claims.PSObject.Properties) {
        if ([bool]$property.Value) {
            $failures.Add("claim_inflation:$($property.Name)")
        }
    }
    return @($failures)
}

Assert-Exact (
    (Test-Path -LiteralPath $diagnosticPath -PathType Leaf) -and
    (Get-RawSha256 $diagnosticPath) -ceq $expectedDiagnosticRawSha256
) "The retained actuation-semantics diagnostic is missing or byte-changed"
$diagnostic = Get-Content -Raw -LiteralPath $diagnosticPath | ConvertFrom-Json
$gateFailures = @(Get-DiagnosticGateFailures $diagnostic)
Assert-Exact (
    $gateFailures.Count -eq 0
) "The actuation-semantics diagnostic gate failed: $($gateFailures -join ',')"

& git -C $repoRoot cat-file -e "$expectedSourceCommit`^{commit}"
Assert-Exact ($LASTEXITCODE -eq 0) "The audited source commit is missing"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit HEAD
Assert-Exact ($LASTEXITCODE -eq 0) "HEAD is not descended from the audited source"
& git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit origin/main
Assert-Exact (
    $LASTEXITCODE -eq 0
) "origin/main is not descended from the audited source"

$repositorySources = @($diagnostic.source_artifacts.repository_sources)
Assert-Exact ($repositorySources.Count -eq 11) "Repository source count changed"
$sourceTextByPath = @{}
foreach ($source in $repositorySources) {
    $path = [string]$source.path
    Assert-Exact (
        -not $sourceTextByPath.ContainsKey($path)
    ) "Duplicate repository source path: $path"
    $blobOid = (& git -C $repoRoot rev-parse "$expectedSourceCommit`:$path").Trim()
    Assert-Exact ($LASTEXITCODE -eq 0) "Missing audited source path: $path"
    Assert-Exact (
        $blobOid -ceq [string]$source.git_blob_oid
    ) "Git blob identity changed for audited source: $path"
    [byte[]]$blobBytes = Get-GitBlobBytes $expectedSourceCommit $path
    Assert-Exact (
        (Get-ByteSha256 $blobBytes) -ceq [string]$source.sha256
    ) "Raw SHA-256 changed for audited source: $path"
    $sourceTextByPath[$path] = [System.Text.Encoding]::UTF8.GetString($blobBytes)
}

$runtimeSource = [string]$sourceTextByPath["sdk/core/src/runtime.rs"]
foreach ($token in @(
    "const MOTOR_POSITION_GAIN_PER_S: f64 = 8.0;",
    "const MOTOR_RATE_DAMPING: f64 = 0.65;",
    "const MOTOR_DIRECTION_SIGN: f64 = -1.0;",
    "let raw_unsigned_velocity = MOTOR_POSITION_GAIN_PER_S",
    "* (requested_target_position_rad - measured_position)",
    "- MOTOR_RATE_DAMPING * measured_velocity;",
    "let target_velocity_rad_s = final_unsigned_velocity * MOTOR_DIRECTION_SIGN;"
)) {
    Assert-ContainsExact $runtimeSource $token "Portable runtime semantic token missing: $token"
}

$protocolSource = [string]$sourceTextByPath["sdk/core/src/protocol.rs"]
foreach ($token in @(
    "pub struct ActuatorCommand {",
    "pub requested_target_position_rad: f64,",
    "pub clamped_target_position_rad: f64,",
    "pub target_velocity_rad_s: f64,"
)) {
    Assert-ContainsExact $protocolSource $token "ActuatorCommand token missing: $token"
}

$contract = [string]$sourceTextByPath["sdk/adapter_kit/adapter_contract_v1.json"] |
    ConvertFrom-Json
Assert-Exact (
    @($contract.authority_partition.host_adapter_owns) -ccontains
        "canonical_to_host_actuation_mapping"
) "The adapter contract no longer assigns host actuation mapping to the adapter"

$godotSource = [string]$sourceTextByPath[
    "scripts/lab/gait/sdk_godot_jolt_adapter.gd"
]
foreach ($token in @(
    "const CHARACTERIZED_HOST_TARGET_SIGN_PER_CANONICAL_POSITIVE := -1.0",
    '"actuator_model": "hinge_target_velocity_with_impulse_cap"',
    '"position_target": "adapter_pd_to_velocity"'
)) {
    Assert-ContainsExact $godotSource $token "Godot/Jolt semantic token missing: $token"
}
$godotAuthorityStart = $godotSource.IndexOf("func apply_authority(")
$godotAuthorityEnd = $godotSource.IndexOf(
    "func apply_stability_contribution(",
    $godotAuthorityStart
)
Assert-Exact (
    $godotAuthorityStart -ge 0 -and $godotAuthorityEnd -gt $godotAuthorityStart
) "Godot/Jolt authority function boundary changed"
$godotAuthority = $godotSource.Substring(
    $godotAuthorityStart,
    $godotAuthorityEnd - $godotAuthorityStart
)
Assert-ContainsExact (
    $godotAuthority
) "HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY" (
    "Godot/Jolt authority no longer writes the retained velocity motor parameter"
)
Assert-Exact (
    -not $godotAuthority.Contains("clamped_target_position_rad") -and
    -not $godotAuthority.Contains("requested_target_position_rad")
) "Godot/Jolt authority unexpectedly gained an independent position application"

$compositionSource = [string]$sourceTextByPath[
    "sdk/adapters/rapier/src/bw19v_composition.rs"
]
foreach ($token in @(
    "RAPIER_BW19V_CANONICAL_TO_HOST_VELOCITY_SIGN: f64 = 1.0;",
    "RAPIER_BW19V_CANONICAL_TO_HOST_VELOCITY_SIGN * influence.applied_velocity_delta_rad_s;",
    "let unbounded = base.target_velocity_rad_s + requested_host_delta;"
)) {
    Assert-ContainsExact $compositionSource $token "Rapier composition token missing: $token"
}

$locomotionSource = [string]$sourceTextByPath[
    "sdk/adapters/rapier/src/locomotion.rs"
]
foreach ($token in @(
    "const MOTOR_STIFFNESS: f32 = 40.0;",
    "const MOTOR_DAMPING: f32 = 10.0;",
    "command.base_target_position_rad as f32,",
    "command.combined_target_velocity_rad_s as f32,",
    ".set_motor_model(MotorModel::ForceBased)"
)) {
    Assert-ContainsExact $locomotionSource $token "Rapier locomotion token missing: $token"
}

$referenceSource = [string]$sourceTextByPath[
    "sdk/adapter_kit/reference_adapter.py"
]
foreach ($token in @(
    '"applied_target_position_rad": command[',
    '"clamped_target_position_rad"',
    '"applied_target_velocity_rad_s": command[',
    '"target_velocity_rad_s"',
    '"world_build_count": 0'
)) {
    Assert-ContainsExact $referenceSource $token "Reference-adapter token missing: $token"
}

$semanticsSource = [string]$sourceTextByPath["docs/LOCOMOTION_SEMANTICS_V1.md"]
Assert-ContainsExact (
    $semanticsSource
) "apply only the returned ordered actuator commands" (
    "Frozen v1 adapter application rule changed"
)
Assert-ContainsExact (
    $semanticsSource
) "actuator`nmodel, and coordinate conversion are conformance data" (
    "Frozen v1 host-conversion rule changed"
)

$architectureSource = [string]$sourceTextByPath["docs/LOCOMOTION_ARCHITECTURE.md"]
Assert-ContainsExact (
    $architectureSource
) "plan → track → emergent" "Architecture reference-tracking decision changed"
Assert-ContainsExact (
    $architectureSource
) "capped joint torque" "Architecture bounded-actuation boundary changed"

$ed1Closure = [string]$sourceTextByPath[
    "sdk/rapier_c6_bw19v_early_horizon_mechanism_development_ed1_closure.json"
] | ConvertFrom-Json
Assert-Exact (
    [string]$ed1Closure.status -ceq
        "closed_complete_both_arms_failed_residual_not_necessary_exact_pair" -and
    -not [bool]$ed1Closure.causal_interpretation.base_controller_intrinsic_cause_identified -and
    -not [bool]$ed1Closure.causal_interpretation.rapier_host_mapping_intrinsic_cause_identified -and
    -not [bool]$ed1Closure.causal_interpretation.base_host_interaction_cause_identified
) "ED1 closure lost its unresolved causal boundary"

$cargoLockSource = [string]$sourceTextByPath["sdk/Cargo.lock"]
Assert-ContainsExact $cargoLockSource 'name = "rapier3d"' "Rapier lock entry missing"
Assert-ContainsExact $cargoLockSource 'version = "0.34.0"' "Rapier version changed"
Assert-ContainsExact (
    $cargoLockSource
) 'checksum = "4592f61e65aa81ecb8701576336c8e66e893f4ad6a1238efe9ff17f2c77006ef"' (
    "Rapier registry checksum changed"
)

$rapierVersion = [string]$diagnostic.source_artifacts.rapier_version
$rapierSourceCandidates = @(
    Get-ChildItem -Path (Join-Path $env:USERPROFILE ".cargo\registry\src") `
        -Directory -Recurse -Filter "rapier3d-$rapierVersion" -ErrorAction Stop
)
Assert-Exact (
    $rapierSourceCandidates.Count -gt 0
) "The installed Rapier $rapierVersion source is unavailable"
$rapierRoot = $null
foreach ($candidate in $rapierSourceCandidates) {
    $allHashesMatch = $true
    foreach ($source in @($diagnostic.source_artifacts.rapier_sources)) {
        $path = Join-Path $candidate.FullName ([string]$source.path)
        if (
            -not (Test-Path -LiteralPath $path -PathType Leaf) -or
            (Get-RawSha256 $path) -cne [string]$source.sha256
        ) {
            $allHashesMatch = $false
            break
        }
    }
    if ($allHashesMatch) {
        $rapierRoot = $candidate.FullName
        break
    }
}
Assert-Exact ($null -ne $rapierRoot) "No installed Rapier source matches the retained hashes"

$rapierSourceText = @{}
foreach ($source in @($diagnostic.source_artifacts.rapier_sources)) {
    $relativePath = [string]$source.path
    $sourcePath = Join-Path $rapierRoot $relativePath
    Assert-Exact (
        (Get-RawSha256 $sourcePath) -ceq [string]$source.sha256
    ) "Installed Rapier source changed: $relativePath"
    $rapierSourceText[$relativePath] = Get-Content -Raw -LiteralPath $sourcePath
}

$motorModelSource = [string]$rapierSourceText[
    "src/dynamics/joint/motor_model.rs"
]
foreach ($token in @(
    "force = stiffness × error + damping × velocity_error",
    "MotorModel::ForceBased => {",
    "let erp_inv_dt = stiffness * crate::utils::inv(dt * stiffness + damping);"
)) {
    Assert-ContainsExact $motorModelSource $token "Rapier ForceBased token missing: $token"
}

$jointSource = [string]$rapierSourceText[
    "src/dynamics/joint/generic_joint.rs"
]
foreach ($token in @(
    "You can combine both for precise control.",
    "target_pos: self.target_pos,",
    "target_vel: self.target_vel,",
    "max_impulse: self.max_force * dt,"
)) {
    Assert-ContainsExact $jointSource $token "Rapier JointMotor token missing: $token"
}

$solverSource = [string]$rapierSourceText[
    "src/dynamics/solver/joint_constraint/joint_constraint_builder.rs"
]
foreach ($token in @(
    "if motor_params.erp_inv_dt != N::zero() {",
    "let target_ang = motor_params.target_pos;",
    "* motor_params.erp_inv_dt;",
    "rhs_wo_bias += -motor_params.target_vel;"
)) {
    Assert-ContainsExact $solverSource $token "Rapier angular-motor solver token missing: $token"
}

$registryChecksum = [string]$diagnostic.source_artifacts.rapier_registry_checksum
$rapierArchives = @(
    Get-ChildItem -Path (Join-Path $env:USERPROFILE ".cargo\registry\cache") `
        -File -Recurse -Filter "rapier3d-$rapierVersion.crate" -ErrorAction Stop
)
Assert-Exact (
    @($rapierArchives | Where-Object { (Get-RawSha256 $_.FullName) -ceq $registryChecksum }).Count -gt 0
) "No cached Rapier crate archive matches the locked registry checksum"

$ed1ReportPath = [string]$diagnostic.source_artifacts.retained_ed1_report_path
Assert-Exact (
    (Test-Path -LiteralPath $ed1ReportPath -PathType Leaf) -and
    (Get-RawSha256 $ed1ReportPath) -ceq $expectedEd1ReportSha256 -and
    [string]$diagnostic.source_artifacts.retained_ed1_report_sha256 -ceq
        $expectedEd1ReportSha256
) "The retained ED1 physical report is missing or byte-changed"
$ed1Report = Get-Content -Raw -LiteralPath $ed1ReportPath | ConvertFrom-Json
Assert-Exact (
    [string]$ed1Report.campaign_id -ceq
        "C6-RAPIER-BW19V-EARLY-HORIZON-MECHANISM-DEVELOPMENT-ED1" -and
    @($ed1Report.arms).Count -eq 2 -and
    [string]$ed1Report.arms[0].arm_id -ceq "ED1-A"
) "The retained ED1 report identity changed"
$stepZero = @($ed1Report.arms[0].ordered_trace)[0]
Assert-Exact ([int]$stepZero.semantic_step -eq 0) "ED1-A trace no longer starts at step zero"
$baseByActuator = @{}
$observationByActuator = @{}
foreach ($command in @($stepZero.ordered_base_commands)) {
    $baseByActuator[[string]$command.actuator_id] = $command
}
foreach ($observation in @($stepZero.ordered_post_step_host_observations)) {
    $observationByActuator[[string]$observation.actuator_id] = $observation
}
Assert-Exact (
    $baseByActuator.Count -eq 8 -and $observationByActuator.Count -eq 8
) "ED1 step-zero actuator coverage changed"

$nonzeroPositionCount = 0
$opposedPositionVelocityCount = 0
$opposedPositionAngleCount = 0
$matchingVelocityAngleCount = 0
foreach ($actuatorId in $baseByActuator.Keys) {
    $command = $baseByActuator[$actuatorId]
    $position = [double]$command.clamped_target_position_rad
    if ($position -eq 0.0) {
        continue
    }
    $nonzeroPositionCount++
    $velocity = [double]$command.target_velocity_rad_s
    $angle = [double]$observationByActuator[$actuatorId].joint_angle_rad
    if ([Math]::Sign($position) -eq -[Math]::Sign($velocity)) {
        $opposedPositionVelocityCount++
    }
    if ([Math]::Sign($position) -eq -[Math]::Sign($angle)) {
        $opposedPositionAngleCount++
    }
    if ([Math]::Sign($velocity) -eq [Math]::Sign($angle)) {
        $matchingVelocityAngleCount++
    }
}
Assert-Exact (
    $nonzeroPositionCount -eq 5 -and
    $opposedPositionVelocityCount -eq 5 -and
    $opposedPositionAngleCount -eq 5 -and
    $matchingVelocityAngleCount -eq 5
) "ED1 step-zero sign reconstruction changed"

$representativeCommand = $baseByActuator["front_right_hip_motor"]
$representativeObservation = $observationByActuator["front_right_hip_motor"]
Assert-Near (
    [double]$representativeCommand.clamped_target_position_rad
) 0.32291965834746944 "Representative ED1 position changed"
Assert-Near (
    [double]$representativeCommand.target_velocity_rad_s
) -2.5806550975692217 "Representative ED1 velocity changed"
Assert-Near (
    [double]$representativeObservation.joint_angle_rad
) -0.004242065828293562 "Representative ED1 post-step angle changed"

$targetPosition = 0.3
$rawCanonicalVelocity = 8.0 * ($targetPosition - 0.0) - 0.65 * 0.0
$portableHostVelocity = $rawCanonicalVelocity * -1.0
$rapierNominalForce = 40.0 * ($targetPosition - 0.0) + 10.0 * ($portableHostVelocity - 0.0)
Assert-Near $rawCanonicalVelocity 2.4 "Analytic canonical velocity changed"
Assert-Near $portableHostVelocity -2.4 "Analytic portable host velocity changed"
Assert-Near $rapierNominalForce -12.0 "Analytic Rapier nominal force changed"
Assert-Exact (
    [Math]::Sign($rapierNominalForce) -ne [Math]::Sign($targetPosition)
) "Analytic semantic counterexample no longer opposes the position error"

$negativeCanaries = @(
    @{
        name = "world_count_inflation"
        mutate = { param($value) $value.world_build_count = 1 }
    },
    @{
        name = "canonical_output_relabel"
        mutate = {
            param($value)
            $value.source_reconstruction.portable_selected_policy.emitted_target_velocity_is_canonical = $true
        }
    },
    @{
        name = "cross_host_equivalence_relabel"
        mutate = {
            param($value)
            $value.diagnosis.cross_engine_selected_policy_equivalence_at_audited_source = $true
        }
    },
    @{
        name = "whole_body_causation_relabel"
        mutate = {
            param($value)
            $value.retained_ed1_step_zero_observation.whole_body_failure_causation_established = $true
        }
    },
    @{
        name = "ed1_reclassification"
        mutate = { param($value) $value.diagnosis.ed1_reclassified = $true }
    },
    @{
        name = "architecture_killed_relabel"
        mutate = { param($value) $value.diagnosis.working_godot_architecture_killed = $true }
    },
    @{
        name = "physical_authority_inflation"
        mutate = { param($value) $value.claims.physical_acceptance_authority = $true }
    }
)
foreach ($canary in $negativeCanaries) {
    $mutated = Copy-JsonObject $diagnostic
    & $canary.mutate $mutated
    $failures = @(Get-DiagnosticGateFailures $mutated)
    Assert-Exact (
        $failures.Count -gt 0
    ) "Diagnostic negative control was accepted: $($canary.name)"
}

Write-Output (
    "C6_RAP_BW19V_ACTUATION_SEMANTICS_DIAGNOSTIC_PASS " +
    "sources=$($repositorySources.Count) rapier_sources=" +
    "$(@($diagnostic.source_artifacts.rapier_sources).Count) worlds=0 " +
    "step0_opposed=$opposedPositionVelocityCount/$nonzeroPositionCount " +
    "canonical_velocity=False cross_host_equivalence=False " +
    "physical_authority=False negative_controls=$($negativeCanaries.Count)"
)

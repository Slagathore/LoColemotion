[CmdletBinding()]
param(
    [string]$Contract = (
        Join-Path $PSScriptRoot "release\quadruped_release_contract.json"
    ),
    [string]$SupportMatrix = (
        Join-Path $PSScriptRoot "release\quadruped_support_matrix.json"
    ),
    [string]$EvidenceRoot = (
        Join-Path (
            Split-Path -Parent (
                [System.IO.Path]::GetFullPath(
                    (Split-Path -Parent $PSScriptRoot)
                )
            )
        ) "SporeSpore_Evidence"
    ),
    [string]$Output = "",
    [switch]$RequireReady,
    [switch]$RequireCandidate
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$contractPath = [System.IO.Path]::GetFullPath($Contract)
$evidenceRootPath = [System.IO.Path]::GetFullPath($EvidenceRoot)
$supportMatrixPath = [System.IO.Path]::GetFullPath($SupportMatrix)

function Assert-Exact {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Get-Sha256 {
    param([string]$Path)
    return (
        "sha256:" +
        (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
    )
}

function Read-JsonObject {
    param([string]$Path)
    try {
        $value = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    } catch {
        throw "Invalid JSON at ${Path}: $($_.Exception.Message)"
    }
    Assert-Exact (
        $null -ne $value -and
        $value -is [pscustomobject]
    ) "Expected a JSON object at $Path"
    return $value
}

function Resolve-ProofPath {
    param(
        [string]$PathKind,
        [string]$Path
    )
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    switch ($PathKind) {
        "evidence_relative" {
            return [System.IO.Path]::GetFullPath(
                (Join-Path $evidenceRootPath $Path)
            )
        }
        "repo_relative" {
            return [System.IO.Path]::GetFullPath(
                (Join-Path $repoRoot $Path)
            )
        }
        default {
            throw "Unsupported proof path_kind '$PathKind' for '$Path'"
        }
    }
}

function Get-JsonPathValue {
    param(
        [object]$Object,
        [string]$Path
    )
    $current = $Object
    foreach ($segment in ($Path -split "\.")) {
        if ($null -eq $current -or -not ($current -is [pscustomobject])) {
            return [pscustomobject]@{
                found = $false
                value = $null
            }
        }
        $property = @(
            $current.PSObject.Properties |
                Where-Object { $_.Name -ceq $segment }
        )
        if ($property.Count -ne 1) {
            return [pscustomobject]@{
                found = $false
                value = $null
            }
        }
        $current = $property[0].Value
    }
    return [pscustomobject]@{
        found = $true
        value = $current
    }
}

function ConvertTo-ComparisonJson {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) {
        return "null"
    }
    return ($Value | ConvertTo-Json -Compress -Depth 100)
}

function Test-ComparisonEqual {
    param(
        [AllowNull()][object]$Actual,
        [AllowNull()][object]$Expected
    )
    $numericTypes = @(
        [byte],
        [sbyte],
        [int16],
        [uint16],
        [int32],
        [uint32],
        [int64],
        [uint64],
        [single],
        [double],
        [decimal]
    )
    $actualIsNumeric = $false
    $expectedIsNumeric = $false
    if ($null -ne $Actual) {
        $actualIsNumeric = $numericTypes -contains $Actual.GetType()
    }
    if ($null -ne $Expected) {
        $expectedIsNumeric = $numericTypes -contains $Expected.GetType()
    }
    if ($actualIsNumeric -and $expectedIsNumeric) {
        try {
            return [decimal]$Actual -eq [decimal]$Expected
        } catch {
            return [double]$Actual -eq [double]$Expected
        }
    }
    if ($actualIsNumeric -ne $expectedIsNumeric) {
        return $false
    }
    return (
        (ConvertTo-ComparisonJson -Value $Actual) -ceq
        (ConvertTo-ComparisonJson -Value $Expected)
    )
}

function Test-JsonPredicates {
    param(
        [pscustomobject]$Json,
        [object[]]$Predicates
    )
    $failures = @()
    foreach ($predicate in $Predicates) {
        $path = [string]$predicate.path
        $resolved = Get-JsonPathValue -Object $Json -Path $path
        if (-not [bool]$resolved.found) {
            $failures += [ordered]@{
                path = $path
                failure_code = "JSON_PATH_MISSING"
                expected = $predicate.equals
                actual = $null
            }
            continue
        }
        if (
            -not (
                Test-ComparisonEqual `
                    -Actual $resolved.value `
                    -Expected $predicate.equals
            )
        ) {
            $failures += [ordered]@{
                path = $path
                failure_code = "JSON_VALUE_MISMATCH"
                expected = $predicate.equals
                actual = $resolved.value
            }
        }
    }
    return $failures
}

function Test-JsonEvidence {
    param([pscustomobject]$Proof)
    $pathKind = [string]$Proof.path_kind
    if ([string]::IsNullOrWhiteSpace($pathKind)) {
        $pathKind = "repo_relative"
    }
    $resolvedPath = Resolve-ProofPath -PathKind $pathKind -Path ([string]$Proof.path)
    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        return [pscustomobject]@{
            valid = $false
            resolved_path = $resolvedPath
            sha256 = $null
            failures = @(
                [ordered]@{
                    failure_code = "EVIDENCE_FILE_MISSING"
                    path = $resolvedPath
                }
            )
        }
    }
    $actualHash = Get-Sha256 -Path $resolvedPath
    $failures = @()
    if (
        -not [string]::IsNullOrWhiteSpace([string]$Proof.sha256) -and
        $actualHash -cne [string]$Proof.sha256
    ) {
        $failures += [ordered]@{
            failure_code = "EVIDENCE_SHA256_MISMATCH"
            expected = [string]$Proof.sha256
            actual = $actualHash
        }
    }
    try {
        $json = Read-JsonObject -Path $resolvedPath
        $failures += @(
            Test-JsonPredicates -Json $json -Predicates @($Proof.predicates)
        )
    } catch {
        $failures += [ordered]@{
            failure_code = "EVIDENCE_JSON_INVALID"
            detail = $_.Exception.Message
        }
    }
    return [pscustomobject]@{
        valid = $failures.Count -eq 0
        resolved_path = $resolvedPath
        sha256 = $actualHash
        failures = $failures
    }
}

function Test-GateProof {
    param([pscustomobject]$Gate)
    $proof = $Gate.proof
    $kind = [string]$proof.kind
    switch ($kind) {
        "missing" {
            return [ordered]@{
                disposition = "missing"
                proof_valid = $true
                detail = [string]$proof.reason
                evidence = @()
                failures = @()
            }
        }
        "repo_file_set" {
            $evidence = @()
            $failures = @()
            foreach ($relativePath in @($proof.paths)) {
                $resolvedPath = Resolve-ProofPath `
                    -PathKind "repo_relative" `
                    -Path ([string]$relativePath)
                $exists = Test-Path -LiteralPath $resolvedPath -PathType Leaf
                $record = [ordered]@{
                    path = [string]$relativePath
                    resolved_path = $resolvedPath
                    exists = $exists
                    sha256 = $null
                }
                if ($exists) {
                    $record.sha256 = Get-Sha256 -Path $resolvedPath
                } else {
                    $failures += [ordered]@{
                        failure_code = "REQUIRED_SOURCE_FILE_MISSING"
                        path = [string]$relativePath
                    }
                }
                $evidence += $record
            }
            $disposition = "passed"
            if ($failures.Count -ne 0) {
                $disposition = "invalid_proof"
            }
            return [ordered]@{
                disposition = $disposition
                proof_valid = $failures.Count -eq 0
                detail = ""
                evidence = $evidence
                failures = $failures
            }
        }
        "repo_json" {
            $normalizedProof = [pscustomobject]@{
                path_kind = "repo_relative"
                path = [string]$proof.path
                sha256 = [string]$proof.sha256
                predicates = @($proof.predicates)
            }
            $checked = Test-JsonEvidence -Proof $normalizedProof
            $disposition = "passed"
            if (-not $checked.valid) {
                $disposition = "invalid_proof"
            }
            return [ordered]@{
                disposition = $disposition
                proof_valid = [bool]$checked.valid
                detail = ""
                evidence = @(
                    [ordered]@{
                        resolved_path = $checked.resolved_path
                        sha256 = $checked.sha256
                    }
                )
                failures = @($checked.failures)
            }
        }
        "json_report" {
            $checked = Test-JsonEvidence -Proof $proof
            $disposition = "passed"
            if (-not $checked.valid) {
                $disposition = "invalid_proof"
            }
            return [ordered]@{
                disposition = $disposition
                proof_valid = [bool]$checked.valid
                detail = ""
                evidence = @(
                    [ordered]@{
                        resolved_path = $checked.resolved_path
                        sha256 = $checked.sha256
                    }
                )
                failures = @($checked.failures)
            }
        }
        "contradicted_json_report" {
            $checked = Test-JsonEvidence -Proof $proof
            $disposition = "contradicted"
            if (-not $checked.valid) {
                $disposition = "invalid_proof"
            }
            return [ordered]@{
                disposition = $disposition
                proof_valid = [bool]$checked.valid
                detail = [string]$proof.reason
                evidence = @(
                    [ordered]@{
                        resolved_path = $checked.resolved_path
                        sha256 = $checked.sha256
                    }
                )
                failures = @($checked.failures)
            }
        }
        "json_report_set" {
            $evidence = @()
            $failures = @()
            foreach ($reportProof in @($proof.reports)) {
                $checked = Test-JsonEvidence -Proof $reportProof
                $evidence += [ordered]@{
                    resolved_path = $checked.resolved_path
                    sha256 = $checked.sha256
                    valid = [bool]$checked.valid
                }
                $failures += @($checked.failures)
            }
            $disposition = "passed"
            if ($failures.Count -ne 0) {
                $disposition = "invalid_proof"
            }
            return [ordered]@{
                disposition = $disposition
                proof_valid = $failures.Count -eq 0
                detail = ""
                evidence = $evidence
                failures = $failures
            }
        }
        default {
            return [ordered]@{
                disposition = "invalid_proof"
                proof_valid = $false
                detail = "Unsupported proof kind '$kind'"
                evidence = @()
                failures = @(
                    [ordered]@{
                        failure_code = "UNSUPPORTED_PROOF_KIND"
                        proof_kind = $kind
                    }
                )
            }
        }
    }
}

Assert-Exact (
    Test-Path -LiteralPath $contractPath -PathType Leaf
) "Quadruped release contract not found: $contractPath"
Assert-Exact (
    Test-Path -LiteralPath $evidenceRootPath -PathType Container
) "Evidence root not found: $evidenceRootPath"

$contractObject = Read-JsonObject -Path $contractPath
Assert-Exact (
    [string]$contractObject.schema_version -ceq
    "sporespore_quadruped_sdk_release_contract_v1"
) "Unsupported quadruped release contract schema"
Assert-Exact (
    @($contractObject.gates).Count -gt 0
) "Quadruped release contract has no gates"
Assert-Exact (
    -not ($RequireReady -and $RequireCandidate)
) "-RequireReady and -RequireCandidate are mutually exclusive"
Assert-Exact (
    Test-Path -LiteralPath $supportMatrixPath -PathType Leaf
) "Quadruped support matrix not found: $supportMatrixPath"
$supportMatrixObject = Read-JsonObject -Path $supportMatrixPath
Assert-Exact (
    [string]$supportMatrixObject.schema_version -ceq
    "sporespore_quadruped_sdk_support_matrix_v1"
) "Unsupported quadruped support matrix schema"
Assert-Exact (
    [string]$supportMatrixObject.release_id -ceq
    [string]$contractObject.release_id
) "Quadruped support matrix and release contract IDs differ"

$gateIds = @($contractObject.gates | ForEach-Object { [string]$_.gate_id })
Assert-Exact (
    @($gateIds | Select-Object -Unique).Count -eq $gateIds.Count
) "Quadruped release contract gate IDs are not unique"
$candidateValidationGateIds = @(
    $contractObject.clean_room_candidate_stage.validation_gate_ids |
        ForEach-Object { [string]$_ }
)
$candidateDependentGateIds = @(
    $contractObject.gates |
        Where-Object {
            [bool]$_.required_for_release -and
            [bool]$_.requires_clean_room_candidate
        } |
        ForEach-Object { [string]$_.gate_id }
)
Assert-Exact (
    ($candidateValidationGateIds -join "|") -ceq
    "QSDK-R01|QSDK-R16|QSDK-R20"
) "Clean-room candidate validation gates must be exactly R01, R16, and R20"
Assert-Exact (
    ($candidateDependentGateIds -join "|") -ceq
    ($candidateValidationGateIds -join "|")
) "Every and only clean-room-dependent gate must be deferred to candidate validation"
Assert-Exact (
    -not [bool](
        $contractObject.clean_room_candidate_stage.publication_authority
    )
) "A clean-room candidate must never carry publication authority"
foreach ($candidateValidationGateId in $candidateValidationGateIds) {
    $matches = @(
        $contractObject.gates |
            Where-Object {
                [string]$_.gate_id -ceq $candidateValidationGateId -and
                [bool]$_.required_for_release
            }
    )
    Assert-Exact (
        $matches.Count -eq 1
    ) "Clean-room candidate validation gate '$candidateValidationGateId' is not a unique required gate"
}

$sourceStatus = @(
    & git -C $repoRoot status --porcelain=v1 --untracked-files=all
)
Assert-Exact ($LASTEXITCODE -eq 0) "Could not read repository status"
$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    -not [string]::IsNullOrWhiteSpace($sourceCommit)
) "Could not resolve repository HEAD"
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
$originResolved = (
    $LASTEXITCODE -eq 0 -and
    -not [string]::IsNullOrWhiteSpace($originMain)
)
$sourceClean = $sourceStatus.Count -eq 0
$sourceMatchesOriginMain = $originResolved -and $sourceCommit -ceq $originMain

$gateResults = @()
foreach ($gate in @($contractObject.gates)) {
    $checked = Test-GateProof -Gate $gate
    $gateResults += [ordered]@{
        gate_id = [string]$gate.gate_id
        category = [string]$gate.category
        required_for_release = [bool]$gate.required_for_release
        requirement = [string]$gate.requirement
        disposition = [string]$checked.disposition
        proof_kind = [string]$gate.proof.kind
        proof_valid = [bool]$checked.proof_valid
        detail = [string]$checked.detail
        evidence = @($checked.evidence)
        failures = @($checked.failures)
    }
}

$requiredResults = @($gateResults | Where-Object { $_.required_for_release })
$requiredPassed = @(
    $requiredResults | Where-Object { $_.disposition -ceq "passed" }
).Count
$requiredMissing = @(
    $requiredResults | Where-Object { $_.disposition -ceq "missing" }
).Count
$requiredContradicted = @(
    $requiredResults | Where-Object { $_.disposition -ceq "contradicted" }
).Count
$requiredInvalid = @(
    $requiredResults | Where-Object { $_.disposition -ceq "invalid_proof" }
).Count
$informationalInvalid = @(
    $gateResults |
        Where-Object {
            -not $_.required_for_release -and
            $_.disposition -ceq "invalid_proof"
        }
).Count
$allRequiredEvidencePassed = (
    $requiredPassed -eq $requiredResults.Count -and
    $requiredMissing -eq 0 -and
    $requiredContradicted -eq 0 -and
    $requiredInvalid -eq 0
)
$evidenceComplete = (
    $allRequiredEvidencePassed -and $informationalInvalid -eq 0
)
$candidatePrerequisiteResults = @(
    $requiredResults |
        Where-Object {
            $candidateValidationGateIds -cnotcontains $_.gate_id
        }
)
$candidatePrerequisitesPassed = @(
    $candidatePrerequisiteResults |
        Where-Object { $_.disposition -ceq "passed" }
).Count -eq $candidatePrerequisiteResults.Count

function Test-GatePassed {
    param([string]$GateId)
    $matches = @(
        $gateResults |
            Where-Object { $_.gate_id -ceq $GateId }
    )
    Assert-Exact (
        $matches.Count -eq 1
    ) "Support-matrix mapping references unknown gate '$GateId'"
    return [string]$matches[0].disposition -ceq "passed"
}

$r02Passed = Test-GatePassed -GateId "QSDK-R02"
$r05Passed = Test-GatePassed -GateId "QSDK-R05"
$r06Passed = Test-GatePassed -GateId "QSDK-R06"
$r07Passed = Test-GatePassed -GateId "QSDK-R07"
$r08Passed = Test-GatePassed -GateId "QSDK-R08"
$r09Passed = Test-GatePassed -GateId "QSDK-R09"
$r10Passed = Test-GatePassed -GateId "QSDK-R10"
$r11Passed = Test-GatePassed -GateId "QSDK-R11"
$r12Passed = Test-GatePassed -GateId "QSDK-R12"
$r13Passed = Test-GatePassed -GateId "QSDK-R13"
$r14Passed = Test-GatePassed -GateId "QSDK-R14"
$r15Passed = Test-GatePassed -GateId "QSDK-R15"
$r16Passed = Test-GatePassed -GateId "QSDK-R16"
$r18Passed = Test-GatePassed -GateId "QSDK-R18"
$r20Passed = Test-GatePassed -GateId "QSDK-R20"
$r21Passed = Test-GatePassed -GateId "QSDK-R21"
$r22Passed = Test-GatePassed -GateId "QSDK-R22"
$r23Passed = Test-GatePassed -GateId "QSDK-R23"
$r24Passed = Test-GatePassed -GateId "QSDK-R24"
$r25Passed = Test-GatePassed -GateId "QSDK-R25"
$crossEngineC6 = $r13Passed -and $r14Passed -and $r15Passed

$matrixExpectations = @(
    [ordered]@{ path = "release_authorized"; expected = $evidenceComplete },
    [ordered]@{ path = "completed_engine_neutral_sdk"; expected = $false },
    [ordered]@{
        path = "scope.continuous_full_volume_physical_coverage"
        expected = $r07Passed
    },
    [ordered]@{
        path = "scope.arbitrary_quadruped_physical_coverage"
        expected = $r06Passed
    },
    [ordered]@{
        path = "portable_surfaces.rust_core.public_release_packaged"
        expected = $r20Passed
    },
    [ordered]@{
        path = "portable_surfaces.c_abi.public_release_packaged"
        expected = $r20Passed
    },
    [ordered]@{
        path = "portable_surfaces.python_binding.public_release_packaged"
        expected = $r20Passed
    },
    [ordered]@{
        path = "portable_surfaces.adapter_authoring_contract.implemented"
        expected = $r02Passed
    },
    [ordered]@{
        path = "portable_surfaces.adapter_authoring_contract.public_release_packaged"
        expected = ($r02Passed -and $r20Passed)
    },
    [ordered]@{
        path = "portable_surfaces.record_replay.implemented"
        expected = $r16Passed
    },
    [ordered]@{
        path = "portable_surfaces.schema_migration.implemented"
        expected = $r18Passed
    },
    [ordered]@{
        path = "portable_surfaces.capability_negotiation.public_release_packaged"
        expected = $r20Passed
    },
    [ordered]@{
        path = "portable_surfaces.adaptation_provider_interface.implemented"
        expected = $r21Passed
    },
    [ordered]@{
        path = "portable_surfaces.adaptation_provider_interface.provider_optional_at_runtime"
        expected = $true
    },
    [ordered]@{
        path = "portable_surfaces.adaptation_provider_interface.zero_provider_baseline_preservation_required"
        expected = $true
    },
    [ordered]@{
        path = "portable_surfaces.adaptation_provider_interface.direct_native_world_mutation_permitted"
        expected = $false
    },
    [ordered]@{
        path = "portable_surfaces.adaptation_provider_interface.public_release_packaged"
        expected = ($r21Passed -and $r20Passed)
    },
    [ordered]@{
        path = "adaptation.tier2.executable_architecture_contract_implemented"
        expected = $r22Passed
    },
    [ordered]@{
        path = "adaptation.tier2.episode_feedback_can_create_candidate_chapters"
        expected = $true
    },
    [ordered]@{
        path = "adaptation.tier2.automatic_live_encyclopedia_rewrite_permitted"
        expected = $false
    },
    [ordered]@{
        path = "adaptation.tier2.promotion_requires_frozen_data_model_and_cross_engine_validation"
        expected = $true
    },
    [ordered]@{
        path = "adaptation.tier3.roadmap_required"
        expected = $true
    },
    [ordered]@{
        path = "adaptation.tier3.immutable_base_and_rollback_required"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_source.implemented"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_source.source_development_conformance_passed"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_source.clean_pushed_source_conformance_retained"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_source.turning_acceptance"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_source.physical_acceptance_authority"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.contract_implemented"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.shared_evaluator_implemented"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.declared_cell_count"
        expected = 9
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.required_normalized_report_schema"
        expected = "sporespore_qsdk_r23d1_engine_cell_report_v2"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.native_command_validation_provenance_required"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.design_cell_negative_control_count"
        expected = 26
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.actual_engine_worker_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.actual_worker_engine_ids"
        expected = @("godot_jolt", "rapier_parry", "mujoco")
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.actual_worker_entrypoint_preflight_passed"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.actual_worker_entrypoint_count"
        expected = 9
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.actual_worker_normalized_report_count"
        expected = 9
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.actual_worker_production_evaluator_pass_count"
        expected = 9
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.actual_worker_native_validation_provenance_pass_count"
        expected = 9
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.actual_worker_negative_control_count"
        expected = 6
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.actual_worker_world_build_count"
        expected = 0
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.aggregate_supervisor_implemented"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.supervisor_freeze_implemented"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.supervisor_preflight_passed"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.supervisor_source_binding_count"
        expected = 24
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.supervisor_retained_test_cas_cell_report_count"
        expected = 9
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.supervisor_production_aggregate_pass_count"
        expected = 1
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.supervisor_aggregate_negative_control_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.physical_authorization_freeze_passed"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.preauthorization_full_godot_v2_attestation_verified"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.authorization_launch_requires_clean_pushed_live_source"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.authorization_launch_requires_matching_current_full_godot_v2_attestation"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.authorization_launch_requirements_were_satisfied"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.launch_full_godot_v2_attestation_verified"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.supervisor_unattested_launch_refusal_count"
        expected = 1
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.physical_authorization_consumed"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.physical_execution_authorized"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.physical_identity_consumed"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.same_identity_rerun_allowed"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.replacement_or_selective_rerun_allowed"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.aggregate_supervisor_closure_interlock"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.individual_physical_worker_closure_interlock_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.selective_completion_mechanically_refused"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.physical_process_launch_count"
        expected = 9
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.complete_cell_report_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.valid_complete_aggregate_present"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientific_result_exists"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.development_result_exists"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.immutable_closure.status"
        expected = "closed_consumed_implementation_invalid_incomplete_no_three_engine_result"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor_id"
        expected = "QSDK-R23D2"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_oracle_preregistered"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.oracle_canary_count"
        expected = 7
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.nonzero_cross_track_canary_count"
        expected = 6
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.legacy_raw_offset_oracle_rejection_count"
        expected = 6
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.predicate_negative_control_count"
        expected = 35
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.failure_stage_control_count"
        expected = 6
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.actual_engine_worker_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.rapier_worker.zero_world_commissioned"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.rapier_worker.contract_sha256"
        expected = "sha256:15815f8fe7e167c36bed1ae9c161b5fadec9da1dbf3ddc3c5180f4e016ecdf29"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.rapier_worker.physical_implementation_present"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.rapier_worker.physical_world_loop_dormant_behind_shared_authorization"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.rapier_worker.physical_world_loop_supervisor_only_authorized"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.rapier_worker.arm_entrypoint_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.rapier_worker.oracle_canary_count"
        expected = 21
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.rapier_worker.arm_command_boundary_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.rapier_worker.native_controller_step_count"
        expected = 24
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.rapier_worker.native_command_count"
        expected = 192
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.rapier_worker.host_mapping_validation_count"
        expected = 24
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.rapier_worker.synthetic_success_report_canary_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.rapier_worker.synthetic_failure_stage_canary_count"
        expected = 18
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.rapier_worker.direct_physical_bypass_refused"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.rapier_worker.world_attempt_count"
        expected = 0
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.rapier_worker.world_build_count"
        expected = 0
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.mujoco_worker.zero_world_commissioned"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.mujoco_worker.contract_sha256"
        expected = "sha256:1af7cb45c7de3af9d773701038b75b7b19f7208663eb160c9c13dbe97bcd3184"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.mujoco_worker.physical_implementation_present"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.mujoco_worker.physical_world_loop_dormant_behind_shared_authorization"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.mujoco_worker.physical_world_loop_supervisor_only_authorized"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.mujoco_worker.engine_version"
        expected = "3.11.0"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.mujoco_worker.arm_entrypoint_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.mujoco_worker.arm_command_boundary_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.mujoco_worker.oracle_canary_count"
        expected = 21
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.mujoco_worker.native_controller_step_count"
        expected = 24
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.mujoco_worker.native_command_count"
        expected = 192
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.mujoco_worker.host_mapping_validation_count"
        expected = 24
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.mujoco_worker.model_xml_validation_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.mujoco_worker.synthetic_success_report_canary_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.mujoco_worker.synthetic_failure_stage_canary_count"
        expected = 18
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.mujoco_worker.direct_physical_bypass_refused"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.mujoco_worker.world_attempt_count"
        expected = 0
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.mujoco_worker.world_build_count"
        expected = 0
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.mujoco_worker.model_construction_count"
        expected = 0
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.contract_sha256"
        expected = "sha256:42e24e52dad30eda8a44d052bd56be069d48cd7a78a834e027935c8dc5ddb04d"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.zero_world_commissioned"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.physical_implementation_present"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.physical_world_loop_dormant_behind_shared_authorization"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.physical_world_loop_supervisor_only_authorized"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.godot_version"
        expected = "4.7-stable-mono"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.physics_engine"
        expected = "Jolt Physics"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.arm_entrypoint_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.arm_command_boundary_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.adapter_start_count"
        expected = 24
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.oracle_canary_count"
        expected = 21
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.native_controller_step_count"
        expected = 24
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.native_command_count"
        expected = 192
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.host_mapping_validation_count"
        expected = 24
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.host_parameter_write_count"
        expected = 192
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.host_object_creation_count"
        expected = 192
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.scene_tree_insertion_count"
        expected = 0
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.zero_world_oracle_trace_canary_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.synthetic_success_report_canary_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.synthetic_failure_stage_canary_count"
        expected = 18
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.direct_physical_bypass_refused"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.world_attempt_count"
        expected = 0
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_worker.world_build_count"
        expected = 0
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.all_engine_workers_zero_world_commissioned"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.physical_worker_implementation_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.development_contract_sha256"
        expected = "sha256:a33d1ac34856a2358b7a3133495e5b4b7b8e8591f3ec235d903cf68f8684b436"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.shared_evaluator.implemented"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.shared_evaluator.independent_from_closed_r23d1_evaluator"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.shared_evaluator.valid_positive_negative_and_invalid_classifications_distinct"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.shared_evaluator.aggregate_sums_actual_worker_counts"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.shared_evaluator.cross_language_oracle_expected_receipts_tolerance_bound"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.shared_evaluator.rejected_projection_canonicalized_before_hashing"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.shared_evaluator.structural_negative_control_rejection_count"
        expected = 18
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.shared_evaluator.valid_outcome_negative_control_count"
        expected = 9
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.shared_evaluator.failure_stage_control_count"
        expected = 6
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.shared_evaluator.failure_provenance_mutation_rejection_count"
        expected = 5
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.aggregate_supervisor.zero_world_commissioned"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.aggregate_supervisor.serialized_worker_gate_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.aggregate_supervisor.worker_entrypoint_count"
        expected = 9
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.aggregate_supervisor.content_addressed_synthetic_report_count"
        expected = 9
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.aggregate_supervisor.content_addressed_failure_receipt_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.aggregate_supervisor.synthetic_valid_negative_aggregate_count"
        expected = 1
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.aggregate_supervisor.aggregate_negative_control_rejection_count"
        expected = 4
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.aggregate_supervisor.stage_aggregate_control_pass_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.aggregate_supervisor.physical_authorization_refusal_count"
        expected = 1
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.physical_workers_complete"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.full_source_runtime_freeze_exists"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.preauthorization_full_godot_v2_attestation_exists"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.source_exact_full_godot_v2_attestation_exists"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.physical_execution_authorized"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.physical_launch_operationally_blocked_pending_clean_pushed_live_identity_and_current_attestation"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.aggregate_supervisor.attempt_runtime_artifacts_revalidated_after_zero_world_gates"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.aggregate_supervisor.attempt_runtime_artifacts_materialized_by_pinned_reproducible_recipe_before_validation"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.aggregate_supervisor.cargo_target_root_remapped_to_constant_virtual_prefix"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.world_build_count"
        expected = 9
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.physical_identity_consumed"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.same_identity_rerun_allowed"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.physical_process_launch_count"
        expected = 9
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.process_timeout_count"
        expected = 0
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.complete_cell_report_count"
        expected = 6
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.worker_failure_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.valid_positive_cell_count"
        expected = 4
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.valid_negative_cell_count"
        expected = 2
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_complete_report_count"
        expected = 0
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_common_failure_code"
        expected = "QSDK_R23D2_GJT_SDK_EXECUTION_INVALID"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.godot_jolt_exact_failed_execution_subpredicate_retained"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.rapier_complete_report_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.mujoco_complete_report_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.aggregate_result_classification"
        expected = "invalid_or_incomplete"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.valid_complete_three_engine_aggregate_present"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.three_engine_scientific_result_exists"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.source_binding_count"
        expected = 48
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.source_bindings_git_blob_or_uniform_crlf_reproducible_count"
        expected = 46
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.source_bindings_exact_checkout_bytes_retained_only_by_attempt_cas_count"
        expected = 2
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.immutable_closure.status"
        expected = "closed_consumed_invalid_incomplete_three_engine_aggregate_with_six_bounded_cell_results"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.scientifically_distinct_successor_id"
        expected = "QSDK-R23D3"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.successor_requires_full_godot_failure_summary_retention"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.successor_requires_negative_heading_mechanism_diagnosis"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.successor_requires_git_reproducible_source_checkout_projection"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.campaign_id"
        expected = "QSDK-R23D3-PHASE-BALANCED-BILATERAL-TURN-DEVELOPMENT"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.gate_id"
        expected = "QSDK-R23D3"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.status"
        expected = "closed_consumed_infrastructure_invalid_after_valid_none_stage_a"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.one_shot_identity_consumed"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.same_identity_rerun_allowed"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.preregistration_sha256"
        expected = "sha256:a20ce471f8d23bbce0317483b0a398c57842a5f4d7e280645276aca7359d7819"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.two_stage_adaptive_design_preregistered"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.stage_a_declared_cell_count"
        expected = 8
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.stage_a_valid_none_distinct_from_invalid"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.stage_a_actual_terminal_entry_count"
        expected = 8
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.stage_a_actual_world_attempt_count"
        expected = 8
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.stage_a_actual_world_build_count"
        expected = 8
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.stage_a_evaluation_valid"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.stage_a_evaluation_classification"
        expected = "valid_none_stage_a"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.stage_a_selected_onset_id"
        expected = "NONE"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.stage_a_positive_heading_outcome_pass_count"
        expected = 4
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.stage_a_negative_heading_signed_yaw_pass_count"
        expected = 4
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.stage_a_negative_heading_outcome_pass_count"
        expected = 0
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.stage_a_negative_heading_maximum_tilt_failure_count"
        expected = 4
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.stage_b_projected_cell_count_if_launched"
        expected = 9
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.stage_b_fresh_mujoco_reports_required"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.stage_b_launched"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.stage_b_actual_world_attempt_count"
        expected = 0
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.stage_b_actual_world_build_count"
        expected = 0
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.signed_yaw_response_recomputed_from_observed_delta"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.production_evaluator_recomputes_all_outcome_gates"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.worker_authored_pass_bits_are_not_selection_authority"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.exact_value_types_required"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.trace_hash_projection"
        expected = "sha256_canonical_sorted_key_ndjson_rows_v1"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.trace_validation_count"
        expected = 17
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.trace_row_validation_count"
        expected = 50864
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.trace_negative_control_rejection_count"
        expected = 10
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.selector_canary_pass_count"
        expected = 4
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.complete_evaluation_canary_pass_count"
        expected = 5
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.godot_execution_predicate_count"
        expected = 7
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.godot_execution_predicate_mutation_rejection_count"
        expected = 7
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.godot_fixed_horizon_forensic_hypothesis_preregistered"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.godot_fixed_horizon_controller_step_count"
        expected = 2992
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.godot_contact_gated_terminal_end_for_controller_trace_forbidden"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.zero_world_godot_execution_predicate_projector_implemented"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.physical_godot_execution_predicate_projector_implemented"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.godot_fixed_horizon_zero_world_worker_preflight_implemented"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.godot_fixed_horizon_physical_worker_implemented"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.physical_worker_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.physical_process_launch_count"
        expected = 8
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.world_attempt_count"
        expected = 8
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.world_build_count"
        expected = 8
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.immutable_completion_status"
        expected = "invalid_or_incomplete_first_attempt"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.immutable_completion_failure_code"
        expected = "SUPERVISOR_INFRASTRUCTURE_EXCEPTION"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.complete_campaign_report_exists"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.immutable_closure.path"
        expected = "sdk/turning/r23d3_physical_closure_v1.json"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.immutable_closure.status"
        expected = "closed_consumed_infrastructure_invalid_after_valid_none_stage_a"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.closure_audit.path"
        expected = "tests/test_qsdk_r23d3_closure.ps1"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.scientifically_distinct_successor_id"
        expected = "QSDK-R23D4"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.onset_timing_alone_sufficient"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.campaign_id"
        expected = "QSDK-R23D4-TERMINAL-STABILIZED-BILATERAL-TURN-DEVELOPMENT"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.gate_id"
        expected = "QSDK-R23D4"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.status"
        expected = "closed_consumed_implementation_invalid_zero_world"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.preregistration_path"
        expected = "sdk/turning/r23d4_terminal_stabilization_preregistration_v1.json"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.preregistration_sha256"
        expected = "sha256:64a2c3bd2bc9194338e62e66bc557d51a3661ed12de77b86d05ebe876891530a"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.preflight_path"
        expected = "sdk/run_qsdk_r23d4_terminal_stabilization_preflight.ps1"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.predecessor_identity_reused"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.numeric_outcome_thresholds_changed"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.terminal_restoration_policy_added"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.passive_terminal_challenge_removed_or_reclassified"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.outcome_measurement_horizon_expanded_to_include_restoration"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.fixed_outcome_exposed_onset_id"
        expected = "onset_600"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.controller_step_count"
        expected = 2992
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.terminal_restoration_step_count"
        expected = 540
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.passive_settle_trace_step_count"
        expected = 240
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.total_trace_step_count_per_cell"
        expected = 3772
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.stage_a_declared_cell_count"
        expected = 2
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.stage_b_projected_cell_count"
        expected = 9
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.trace_validation_count"
        expected = 11
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.trace_row_validation_count"
        expected = 41492
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.trace_negative_control_rejection_count"
        expected = 8
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.selector_canary_pass_count"
        expected = 4
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.empty_manifest_canary_pass_count"
        expected = 2
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.evaluator_transport_canary_pass_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.physical_worker_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.physical_process_launch_count"
        expected = 1
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.consumed_attempt_count"
        expected = 1
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.completed_cell_count"
        expected = 0
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.scientific_positive"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.scientific_negative"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.immutable_closure.path"
        expected = "sdk/turning/r23d4_physical_closure_v1.json"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.immutable_closure.sha256"
        expected = "sha256:da1534dfd2f12ac0901b323d6907e98e8f2e8a31d162484fbaba594b634be176"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.immutable_closure.status"
        expected = "closed_consumed_implementation_invalid_zero_world"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.closure_audit.path"
        expected = "tests/test_qsdk_r23d4_closure.ps1"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.closure_audit.sha256"
        expected = "sha256:094f5bb7b2e600983fa4eea5050429a8f29446091f90d7439cb063764f0ec4a0"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.scientifically_distinct_successor_id"
        expected = "QSDK-R23D5"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.campaign_id"
        expected = "QSDK-R23D5-DEPENDENCY-CLOSED-TERMINAL-STABILIZED-BILATERAL-TURN-DEVELOPMENT"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.gate_id"
        expected = "QSDK-R23D5"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.status"
        expected = "closed_consumed_implementation_invalid_after_stage_a_worlds"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.declaration_path"
        expected = "sdk/turning/r23d5_dependency_closed_preregistration_v1.json"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.declaration_sha256"
        expected = "sha256:cf450d770d442ee0b8551f4f1633e5c3b8a9a33a57198ccf9eea6065edfa22a8"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.declared_worker_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.unique_declared_dependency_count"
        expected = 21
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.dependency_removal_negative_control_count_required"
        expected = 21
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.terminal_marker_family_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.stage_a_declared_cell_count"
        expected = 2
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.stage_b_projected_cell_count"
        expected = 9
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.physical_worker_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.production_evaluator_implemented"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.aggregate_supervisor_implemented"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.complete_zero_world_gate_passed"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.possible_worker_identity_count"
        expected = 11
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.implementation_source_binding_count"
        expected = 70
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.production_evaluator_test_count"
        expected = 8
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.physical_process_launch_count"
        expected = 2
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.stage_a_terminal_entry_count"
        expected = 2
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.stage_b_worker_process_count"
        expected = 0
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.world_attempt_count"
        expected = 2
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.world_build_count"
        expected = 2
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.immutable_closure.path"
        expected = "sdk/turning/r23d5_physical_closure_v1.json"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.immutable_closure.sha256"
        expected = "sha256:d45905782e59f20ca6dd88028818fccd37eb2b2964d2af4b0d1a933833e45d40"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.closure_audit.path"
        expected = "tests/test_qsdk_r23d5_closure.ps1"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.closure_audit.sha256"
        expected = "sha256:125e59dae467a5242f7029b2f91f531451df652830a5d6b3fccac459ac964b71"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.scientifically_distinct_successor_id"
        expected = "QSDK-R23D6"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.campaign_id"
        expected = "QSDK-R23D6-POLICY-COMPATIBLE-TERMINAL-STABILIZED-BILATERAL-TURN-DEVELOPMENT"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.gate_id"
        expected = "QSDK-R23D6"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.status"
        expected = "closed_consumed_valid_none_stage_a_terminal_restoration_negative"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.declaration_path"
        expected = "sdk/turning/r23d6_policy_compatible_restoration_preregistration_v1.json"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.declaration_sha256"
        expected = "sha256:14a7b6dd82a2642bb2f86b4caffdf87573d138e8410855619628c36f2eb63503"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.implementation_contract_path"
        expected = "sdk/turning/r23d6_implementation_contract_v1.json"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.complete_zero_world_gate_path"
        expected = "sdk/run_qsdk_r23d6_zero_world_gate.ps1"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.predecessor_identity_reused"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.same_unresolved_physical_estimand_retained"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.numeric_outcome_thresholds_changed"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.terminal_restoration_policy_id_changed"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.policy_composition_derivation_changed"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.supported_turning_policy_id"
        expected = "sporespore_balanced_wave_bw5r_b_v1"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.policy_derivation_authority_count"
        expected = 5
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.independent_oracle_canary_count"
        expected = 5
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.required_oracle_mutation_control_count"
        expected = 8
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.production_shaped_bw5r_b_restoration_preflight_required"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.stage_a_declared_cell_count"
        expected = 2
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.stage_b_projected_cell_count"
        expected = 9
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.physical_worker_count"
        expected = 3
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.production_evaluator_implemented"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.aggregate_supervisor_implemented"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.declared_worker_dependency_count"
        expected = 23
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.complete_zero_world_gate_passed"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.immutable_closure.path"
        expected = "sdk/turning/r23d6_physical_closure_v1.json"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.immutable_closure.sha256"
        expected = "sha256:8d3c1f2e916dc51fe44a3c549e26742f8b077e22f37fdba47191d8007a4c5dfd"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.closure_audit.path"
        expected = "tests/test_qsdk_r23d6_closure.ps1"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.closure_audit.sha256"
        expected = "sha256:8e9146590f22098e8dab2c372d103d9cf6d14d3db9d31e45aa7dd863144718fd"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.stage_a_result_classification"
        expected = "valid_none_stage_a"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.selected_terminal_restoration_policy_id"
        expected = "NONE"
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.exact_finite_scientific_positive"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.exact_finite_scientific_negative"
        expected = $true
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.stage_a_completed_cell_count"
        expected = 2
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.stage_b_launched"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.same_identity_rerun_allowed"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.world_attempt_count"
        expected = 2
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.world_build_count"
        expected = 2
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.physical_execution_authorized"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.policy_compatible_restoration_successor.command_conditioned_turning"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.physical_execution_authorized"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.dependency_closed_successor.command_conditioned_turning"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.world_attempt_count"
        expected = 0
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.world_build_count"
        expected = 0
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.physical_execution_authorized"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.command_conditioned_turning"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.bilateral_signed_turning"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.portable_basic_turning"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.cross_engine_equivalence"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.q_sdk_r23_satisfied"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.release_authorized"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.terminal_stabilization_successor.physical_acceptance_authority"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.physical_execution_authorized"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.portable_basic_turning"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.command_conditioned_turning"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.bilateral_signed_turning"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.cross_engine_equivalence"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.q_sdk_r23_satisfied"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.release_authorized"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.scientifically_distinct_successor.stage_zero_successor.physical_acceptance_authority"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.heading_command_physical_development.q_sdk_r23_satisfied"
        expected = $false
    },
    [ordered]@{
        path = "locomotion_modes.command_conditioned_turning"
        expected = $r23Passed
    },
    [ordered]@{
        path = "locomotion_modes.prone_to_standing"
        expected = $r24Passed
    },
    [ordered]@{
        path = "comparative_inference.release_comparative_gate_passed"
        expected = $r25Passed
    },
    [ordered]@{
        path = "morphology.same_selected_policy_independent_morphology_evidence"
        expected = $r05Passed
    },
    [ordered]@{
        path = "morphology.arbitrary_quadruped_physical_evidence"
        expected = $r06Passed
    },
    [ordered]@{
        path = "morphology.continuous_full_volume_physical_evidence"
        expected = $r07Passed
    },
    [ordered]@{
        path = "environmental_robustness.godot_jolt_bounded_discrete_material_values.accepted"
        expected = $r08Passed
    },
    [ordered]@{
        path = "environmental_robustness.rough_terrain.accepted"
        expected = $r09Passed
    },
    [ordered]@{
        path = "environmental_robustness.external_pushes.accepted"
        expected = $r10Passed
    },
    [ordered]@{
        path = "environmental_robustness.sensor_noise.accepted"
        expected = $r11Passed
    },
    [ordered]@{
        path = "environmental_robustness.sensor_latency.accepted"
        expected = $r12Passed
    },
    [ordered]@{
        path = "engines.godot_jolt.selected_policy_physical_c6"
        expected = $r13Passed
    },
    [ordered]@{
        path = "engines.godot_jolt.quadruped_submission_advertised"
        expected = $r13Passed
    },
    [ordered]@{
        path = "engines.rapier_parry.selected_policy_physical_c6"
        expected = $r14Passed
    },
    [ordered]@{
        path = "engines.rapier_parry.quadruped_submission_advertised"
        expected = $r14Passed
    },
    [ordered]@{
        path = "engines.mujoco.selected_policy_physical_c6"
        expected = $r15Passed
    },
    [ordered]@{
        path = "engines.mujoco.quadruped_submission_advertised"
        expected = $r15Passed
    },
    [ordered]@{
        path = "claim_boundary.walking_acceptance"
        expected = $evidenceComplete
    },
    [ordered]@{
        path = "claim_boundary.command_conditioned_turning"
        expected = $r23Passed
    },
    [ordered]@{
        path = "claim_boundary.prone_to_standing"
        expected = $r24Passed
    },
    [ordered]@{
        path = "claim_boundary.physical_balance_recovery"
        expected = $false
    },
    [ordered]@{
        path = "claim_boundary.rough_terrain_robustness"
        expected = $r09Passed
    },
    [ordered]@{
        path = "claim_boundary.external_push_recovery"
        expected = $r10Passed
    },
    [ordered]@{
        path = "claim_boundary.sensor_noise_robustness"
        expected = $r11Passed
    },
    [ordered]@{
        path = "claim_boundary.sensor_latency_robustness"
        expected = $r12Passed
    },
    [ordered]@{
        path = "claim_boundary.cross_engine_c6"
        expected = $crossEngineC6
    },
    [ordered]@{
        path = "claim_boundary.formal_cross_engine_comparative_inference"
        expected = $r25Passed
    },
    [ordered]@{
        path = "claim_boundary.tier2_learned_adaptation"
        expected = $false
    },
    [ordered]@{
        path = "claim_boundary.tier3_online_adaptation"
        expected = $false
    },
    [ordered]@{
        path = "claim_boundary.arbitrary_quadruped_coverage"
        expected = $r06Passed
    },
    [ordered]@{
        path = "claim_boundary.continuous_full_volume_coverage"
        expected = $r07Passed
    },
    [ordered]@{
        path = "claim_boundary.submission_ready"
        expected = $evidenceComplete
    },
    [ordered]@{
        path = "claim_boundary.physical_acceptance_authority"
        expected = $evidenceComplete
    }
)
$matrixFailures = @()
foreach ($expectation in $matrixExpectations) {
    $resolved = Get-JsonPathValue `
        -Object $supportMatrixObject `
        -Path ([string]$expectation.path)
    if (-not [bool]$resolved.found) {
        $matrixFailures += [ordered]@{
            path = [string]$expectation.path
            failure_code = "SUPPORT_MATRIX_PATH_MISSING"
            expected = $expectation.expected
            actual = $null
        }
        continue
    }
    if (
        -not (
            Test-ComparisonEqual `
                -Actual $resolved.value `
                -Expected $expectation.expected
        )
    ) {
        $matrixFailures += [ordered]@{
            path = [string]$expectation.path
            failure_code = "SUPPORT_MATRIX_GATE_DISAGREEMENT"
            expected = $expectation.expected
            actual = $resolved.value
        }
    }
}
$supportMatrixConsistent = $matrixFailures.Count -eq 0
$candidatePackageAuthorized = (
    $candidatePrerequisitesPassed -and
    $informationalInvalid -eq 0 -and
    $supportMatrixConsistent -and
    $sourceClean -and
    $sourceMatchesOriginMain
)
$releaseReady = (
    $evidenceComplete -and
    $supportMatrixConsistent -and
    $sourceClean -and
    $sourceMatchesOriginMain
)
$reportStatus = "blocked"
if ($releaseReady) {
    $reportStatus = "ready"
}
$reportOriginMain = $null
if ($originResolved) {
    $reportOriginMain = $originMain
}
$blockingConditions = @(
    $requiredResults |
        Where-Object { $_.disposition -cne "passed" } |
        ForEach-Object { $_.gate_id }
)
$candidateBlockingGateIds = @(
    $candidatePrerequisiteResults |
        Where-Object { $_.disposition -cne "passed" } |
        ForEach-Object { $_.gate_id }
)
if ($informationalInvalid -ne 0) {
    $blockingConditions += "QSDK-INFORMATIONAL-PROOF-INTEGRITY"
}
if (-not $supportMatrixConsistent) {
    $blockingConditions += "QSDK-SUPPORT-MATRIX-CONSISTENCY"
}
if (-not $sourceClean) {
    $blockingConditions += "QSDK-SOURCE-CLEAN"
}
if (-not $sourceMatchesOriginMain) {
    $blockingConditions += "QSDK-SOURCE-ORIGIN-MAIN"
}
$candidateBlockingConditions = @($candidateBlockingGateIds)
if ($informationalInvalid -ne 0) {
    $candidateBlockingConditions += "QSDK-INFORMATIONAL-PROOF-INTEGRITY"
}
if (-not $supportMatrixConsistent) {
    $candidateBlockingConditions += "QSDK-SUPPORT-MATRIX-CONSISTENCY"
}
if (-not $sourceClean) {
    $candidateBlockingConditions += "QSDK-SOURCE-CLEAN"
}
if (-not $sourceMatchesOriginMain) {
    $candidateBlockingConditions += "QSDK-SOURCE-ORIGIN-MAIN"
}

$report = [ordered]@{
    schema_version = "sporespore_quadruped_sdk_release_readiness_report_v1"
    release_id = [string]$contractObject.release_id
    status = $reportStatus
    release_ready = $releaseReady
    package_authorized = $releaseReady
    publication_authorized = $releaseReady
    clean_room_candidate_authorized = $candidatePackageAuthorized
    clean_room_candidate_publication_authorized = $false
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    source = [ordered]@{
        commit = $sourceCommit
        origin_main = $reportOriginMain
        clean = $sourceClean
        matches_origin_main = $sourceMatchesOriginMain
        status_entries = $sourceStatus
    }
    contract = [ordered]@{
        path = $contractPath
        sha256 = Get-Sha256 -Path $contractPath
        schema_version = [string]$contractObject.schema_version
    }
    support_matrix = [ordered]@{
        path = $supportMatrixPath
        sha256 = Get-Sha256 -Path $supportMatrixPath
        schema_version = [string]$supportMatrixObject.schema_version
        consistent_with_gate_dispositions = $supportMatrixConsistent
        failures = $matrixFailures
    }
    evidence_root = $evidenceRootPath
    gate_counts = [ordered]@{
        total = $gateResults.Count
        informational = $gateResults.Count - $requiredResults.Count
        required_for_release = $requiredResults.Count
        required_passed = $requiredPassed
        required_missing = $requiredMissing
        required_contradicted = $requiredContradicted
        required_invalid_proof = $requiredInvalid
        informational_invalid_proof = $informationalInvalid
    }
    blocking_gate_ids = @(
        $requiredResults |
            Where-Object { $_.disposition -cne "passed" } |
            ForEach-Object { $_.gate_id }
    )
    clean_room_candidate_validation_gate_ids = $candidateValidationGateIds
    clean_room_candidate_prerequisite_gate_count = (
        $candidatePrerequisiteResults.Count
    )
    clean_room_candidate_validation_gate_count = (
        $candidateValidationGateIds.Count
    )
    two_stage_package_flow_satisfiable = (
        $candidatePrerequisiteResults.Count -gt 0 -and
        $candidateValidationGateIds.Count -gt 0 -and
        (
            $candidatePrerequisiteResults.Count +
            $candidateValidationGateIds.Count
        ) -eq $requiredResults.Count
    )
    clean_room_candidate_blocking_gate_ids = $candidateBlockingGateIds
    clean_room_candidate_blocking_conditions = $candidateBlockingConditions
    blocking_conditions = $blockingConditions
    gates = $gateResults
    claims = [ordered]@{
        standalone_quadruped_sdk_released = $releaseReady
        arbitrary_quadruped_coverage = [bool](
            $supportMatrixObject.claim_boundary.arbitrary_quadruped_coverage
        )
        continuous_full_volume_coverage = [bool](
            $supportMatrixObject.claim_boundary.continuous_full_volume_coverage
        )
        rough_terrain_robustness = [bool](
            $supportMatrixObject.claim_boundary.rough_terrain_robustness
        )
        external_push_recovery = [bool](
            $supportMatrixObject.claim_boundary.external_push_recovery
        )
        sensor_noise_robustness = [bool](
            $supportMatrixObject.claim_boundary.sensor_noise_robustness
        )
        sensor_latency_robustness = [bool](
            $supportMatrixObject.claim_boundary.sensor_latency_robustness
        )
        cross_engine_c6 = [bool](
            $supportMatrixObject.claim_boundary.cross_engine_c6
        )
        formal_cross_engine_comparative_inference = [bool](
            $supportMatrixObject.claim_boundary.formal_cross_engine_comparative_inference
        )
        command_conditioned_turning = [bool](
            $supportMatrixObject.claim_boundary.command_conditioned_turning
        )
        prone_to_standing = [bool](
            $supportMatrixObject.claim_boundary.prone_to_standing
        )
        tier2_learned_adaptation = [bool](
            $supportMatrixObject.claim_boundary.tier2_learned_adaptation
        )
        tier3_online_adaptation = [bool](
            $supportMatrixObject.claim_boundary.tier3_online_adaptation
        )
        completed_engine_neutral_sdk = [bool](
            $supportMatrixObject.completed_engine_neutral_sdk
        )
        bipedal_creatures = [bool](
            $supportMatrixObject.topologies_outside_this_release.biped
        )
        physical_acceptance_authority = [bool](
            $supportMatrixObject.claim_boundary.physical_acceptance_authority
        )
    }
}

$reportJson = $report | ConvertTo-Json -Depth 100
if (-not [string]::IsNullOrWhiteSpace($Output)) {
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    Assert-Exact (
        [System.IO.Path]::GetFileName($outputPath) -ceq "report.json"
    ) "Quadruped readiness output filename must be exactly report.json"
    Assert-Exact (
        -not (Test-Path -LiteralPath $outputPath)
    ) "Refusing to overwrite quadruped readiness output: $outputPath"
    $outputDirectory = Split-Path -Parent $outputPath
    [void][System.IO.Directory]::CreateDirectory($outputDirectory)
    $temporaryPath = "$outputPath.tmp"
    Assert-Exact (
        -not (Test-Path -LiteralPath $temporaryPath)
    ) "Quadruped readiness temporary path already exists: $temporaryPath"
    [System.IO.File]::WriteAllText(
        $temporaryPath,
        "$reportJson`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    Move-Item -LiteralPath $temporaryPath -Destination $outputPath
}

Write-Output (
    "QUADRUPED_SDK_RELEASE_READINESS " +
    ($report | ConvertTo-Json -Compress -Depth 100)
)
Write-Host (
    "Quadruped SDK readiness: status=$($report.status) " +
    "required=$requiredPassed/$($requiredResults.Count) " +
    "missing=$requiredMissing contradicted=$requiredContradicted " +
    "invalid=$requiredInvalid"
)

if ($RequireReady -and -not $releaseReady) {
    throw (
        "Quadruped SDK release is blocked by: " +
        ($report.blocking_gate_ids -join ", ")
    )
}
if ($RequireCandidate -and -not $candidatePackageAuthorized) {
    throw (
        "Quadruped SDK clean-room candidate is blocked by: " +
        ($report.clean_room_candidate_blocking_conditions -join ", ")
    )
}

#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet("P5M1R1", "BW3", "BW3R", "BW4", "BW5V", "BW5C", "BW20F")]
    [string]$Campaign = "P5M1R1",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_sdk_godot_jolt_friction_ladder"
    ),
    [string]$Output = "",
    [switch]$PreflightOnly,
    [switch]$Bw20fSupervisorAuthorized,
    [string]$Bw20fSupervisorAttempt = ""
)

$ErrorActionPreference = "Stop"
$isBw3 = $Campaign -ceq "BW3"
$isBw3r = $Campaign -ceq "BW3R"
$isBw4 = $Campaign -ceq "BW4"
$isBw5v = $Campaign -ceq "BW5V"
$isBw5c = $Campaign -ceq "BW5C"
$isBw20f = $Campaign -ceq "BW20F"
$isProspective = (
    $isBw3 -or $isBw3r -or $isBw4 -or $isBw5v -or $isBw5c -or $isBw20f
)
if ($isBw20f -and $PreflightOnly) {
    throw (
        "BW20F preflight is owned by the complete campaign supervisor; " +
        "invoke run_balanced_wave_bw20f_material_characterization.ps1"
    )
}
if ($isBw20f -and -not $Bw20fSupervisorAuthorized) {
    throw "BW20F physical characterization requires its campaign supervisor"
}
if ($isBw20f -and [string]::IsNullOrWhiteSpace($Bw20fSupervisorAttempt)) {
    throw "BW20F worker requires the supervisor's durable attempt receipt"
}
if (
    -not $isBw20f -and
    ($Bw20fSupervisorAuthorized -or
        -not [string]::IsNullOrWhiteSpace($Bw20fSupervisorAttempt))
) {
    throw "BW20F supervisor authorization cannot be used by another campaign"
}
if ($PreflightOnly -and -not $isProspective) {
    throw "PreflightOnly is defined only for prospective characterization"
}
if ($PreflightOnly -and -not [string]::IsNullOrWhiteSpace($Output)) {
    throw "Prospective preflight cannot retain a physics report"
}
$campaignLabel = if ($isBw20f) {
    "BW20F BW19V-B cold material characterization"
} elseif ($isBw5c) {
    "BW5C cold material characterization"
} elseif ($isBw5v) {
    "BW5V independent-validation material characterization"
} elseif ($isBw4) {
    "BW4 cold material characterization"
} elseif ($isBw3r) {
    "BW3R material characterization"
} elseif ($isBw3) {
    "BW3 material characterization"
} else {
    "P5M.1-R1 friction ladder"
}
$receiptPrefix = if ($PreflightOnly) {
    if ($isBw5c) {
        "BALANCED_WAVE_BW5C_MATERIAL_CHARACTERIZATION_PREFLIGHT_RECEIPT "
    } elseif ($isBw5v) {
        "BALANCED_WAVE_BW5V_MATERIAL_CHARACTERIZATION_PREFLIGHT_RECEIPT "
    } elseif ($isBw4) {
        "BALANCED_WAVE_BW4_MATERIAL_CHARACTERIZATION_PREFLIGHT_RECEIPT "
    } elseif ($isBw3r) {
        "BALANCED_WAVE_BW3R_MATERIAL_CHARACTERIZATION_PREFLIGHT_RECEIPT "
    } else {
        "BALANCED_WAVE_BW3_MATERIAL_CHARACTERIZATION_PREFLIGHT_RECEIPT "
    }
} elseif ($isBw20f) {
    "BALANCED_WAVE_BW20F_MATERIAL_CHARACTERIZATION_RECEIPT "
} elseif ($isBw5c) {
    "BALANCED_WAVE_BW5C_MATERIAL_CHARACTERIZATION_RECEIPT "
} elseif ($isBw5v) {
    "BALANCED_WAVE_BW5V_MATERIAL_CHARACTERIZATION_RECEIPT "
} elseif ($isBw4) {
    "BALANCED_WAVE_BW4_MATERIAL_CHARACTERIZATION_RECEIPT "
} elseif ($isBw3r) {
    "BALANCED_WAVE_BW3R_MATERIAL_CHARACTERIZATION_RECEIPT "
} elseif ($isBw3) {
    "BALANCED_WAVE_BW3_MATERIAL_CHARACTERIZATION_RECEIPT "
} else {
    "SDK_FRICTION_LADDER_RECEIPT "
}
$expectedSchema = if ($PreflightOnly) {
    if ($isBw5c) {
        "sporespore_balanced_wave_bw5c_material_characterization_preflight_receipt_v1"
    } elseif ($isBw5v) {
        "sporespore_balanced_wave_bw5v_material_characterization_preflight_receipt_v1"
    } elseif ($isBw4) {
        "sporespore_balanced_wave_bw4_material_characterization_preflight_receipt_v1"
    } elseif ($isBw3r) {
        "sporespore_balanced_wave_bw3r_material_characterization_preflight_receipt_v1"
    } else {
        "sporespore_balanced_wave_bw3_material_characterization_preflight_receipt_v1"
    }
} elseif ($isBw20f) {
    "sporespore_balanced_wave_bw20f_material_characterization_receipt_v1"
} elseif ($isBw5c) {
    "sporespore_balanced_wave_bw5c_material_characterization_receipt_v1"
} elseif ($isBw5v) {
    "sporespore_balanced_wave_bw5v_material_characterization_receipt_v1"
} elseif ($isBw4) {
    "sporespore_balanced_wave_bw4_material_characterization_receipt_v1"
} elseif ($isBw3r) {
    "sporespore_balanced_wave_bw3r_material_characterization_receipt_v1"
} elseif ($isBw3) {
    "sporespore_balanced_wave_bw3_material_characterization_receipt_v1"
} else {
    "sporespore_godot_jolt_friction_ladder_r1_receipt_v1"
}
$expectedGateCount = if ($PreflightOnly) {
    6
} elseif ($isBw4 -or $isBw5c -or $isBw20f) {
    23
} elseif ($isProspective) {
    19
} else {
    31
}
$expectedWorldCount = if ($PreflightOnly) {
    0
} elseif ($isBw4 -or $isBw5c -or $isBw20f) {
    13
} elseif ($isProspective) {
    10
} else {
    19
}
$expectedPositiveCellCount = if ($isBw4 -or $isBw5c -or $isBw20f) {
    4
} elseif ($isProspective) {
    3
} else {
    6
}
$expectedFixtureCount = if ($isBw4 -or $isBw5c -or $isBw20f) { 5 } else { 4 }
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$godotPath = [System.IO.Path]::GetFullPath($Godot)
if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable not found: $godotPath"
}
$bw20fPreregistration = $null
$bw20fPrerequisiteEvidence = $null
$bw20fReferenceCharacterization = $null
$bw20fGodotExecutableSha256 = $null
$bw20fGodotVersion = $null
$bw20fAttempt = $null
if ($isBw20f) {
    if ([string]::IsNullOrWhiteSpace($Output)) {
        throw "BW20F physical characterization requires a retained report path"
    }
    $earlyOutputPath = [System.IO.Path]::GetFullPath($Output)
    if ([System.IO.Path]::GetFileName($earlyOutputPath) -cne "report.json") {
        throw "The retained BW20F report filename must be exactly report.json"
    }
    if (Test-Path -LiteralPath $earlyOutputPath) {
        throw "Refusing to overwrite an existing BW20F report: $earlyOutputPath"
    }
    $earlyOutputDirectory = [System.IO.Path]::GetFullPath(
        (Split-Path -Parent $earlyOutputPath)
    )
    $bw20fAttemptPath = [System.IO.Path]::GetFullPath($Bw20fSupervisorAttempt)
    $expectedAttemptPath = Join-Path $earlyOutputDirectory "attempt.json"
    if (
        $bw20fAttemptPath -cne $expectedAttemptPath -or
        -not (Test-Path -LiteralPath $bw20fAttemptPath -PathType Leaf)
    ) {
        throw "BW20F worker requires the exact sibling supervisor attempt receipt"
    }
    $bw20fAttempt = Get-Content -Raw -LiteralPath $bw20fAttemptPath |
        ConvertFrom-Json -AsHashtable
    if (
        [string]$bw20fAttempt.schema_version -cne
            "sporespore_balanced_wave_bw20f_attempt_v1" -or
        [string]$bw20fAttempt.campaign_id -cne
            "BW20F-BW19V-COLD-MATERIAL" -or
        [string]$bw20fAttempt.gate_id -cne "BW20F" -or
        -not [bool]$bw20fAttempt.physical_process_launch_reserved_identity_consumed -or
        [bool]$bw20fAttempt.same_identity_rerun_allowed -or
        [int]$bw20fAttempt.expected_world_count -ne 13 -or
        [int]$bw20fAttempt.expected_gate_count -ne 23 -or
        [int]$bw20fAttempt.locomotion_seed_world_count -ne 0 -or
        [bool]$bw20fAttempt.physical_acceptance_authority
    ) {
        throw "BW20F supervisor attempt receipt is invalid"
    }
    $bw20fPreregistrationPath = Join-Path $sdkRoot (
        "balanced_wave_bw20f_cold_material_preregistration.json"
    )
    if (-not (Test-Path -LiteralPath $bw20fPreregistrationPath -PathType Leaf)) {
        throw "BW20F preregistration is missing"
    }
    $bw20fPreregistration = (
        Get-Content -Raw -LiteralPath $bw20fPreregistrationPath |
            ConvertFrom-Json -AsHashtable
    )
    $bw20fCharacterization = $bw20fPreregistration.material_characterization
    $bw20fCandidate = $bw20fPreregistration.candidate_identity
    $bw20fReservation = $bw20fPreregistration.cold_reservation
    $bw20fHost = $bw20fPreregistration.host_identity
    $bw20fGodotExecutableSha256 = (
        Get-FileHash -Algorithm SHA256 -LiteralPath $godotPath
    ).Hash.ToLowerInvariant()
    $bw20fGodotVersion = (& $godotPath --version 2>&1 | Out-String).Trim()
    $bw20fGodotVersionExitCode = $LASTEXITCODE
    if (
        [string]$bw20fPreregistration.schema_version -cne
            "sporespore_balanced_wave_bw20f_cold_material_preregistration_v1" -or
        [string]$bw20fPreregistration.status -cne
            "frozen_before_first_bw20f_characterization_world" -or
        [string]$bw20fPreregistration.campaign_id -cne
            "BW20F-BW19V-COLD-MATERIAL" -or
        [string]$bw20fPreregistration.gate_id -cne "BW20F" -or
        $bw20fGodotVersionExitCode -ne 0 -or
        [string]$bw20fHost.godot_version -cne $bw20fGodotVersion -or
        [string]$bw20fHost.godot_executable_sha256 -cne
            $bw20fGodotExecutableSha256 -or
        [string]$bw20fHost.adapter_id -cne "godot_jolt_gdextension_v1" -or
        [string]$bw20fHost.physics_engine -cne "Jolt Physics" -or
        [int]$bw20fHost.physics_hz -ne 120 -or
        [int]$bw20fHost.solver_velocity_steps -ne 20 -or
        [int]$bw20fHost.solver_position_steps -ne 7 -or
        [string]$bw20fPreregistration.study_class.classification -cne
            "exact_finite_cell_adapter_material_characterization" -or
        -not [bool]$bw20fPreregistration.study_class.finite_decision -or
        [bool]$bw20fPreregistration.study_class.population_inference -or
        [bool]$bw20fPreregistration.study_class.superiority_study -or
        [bool]$bw20fPreregistration.study_class.noninferiority_or_equivalence_study -or
        [string]$bw20fCandidate.candidate_id -cne "BW19V-B" -or
        [string]$bw20fCandidate.candidate_composition_digest -cne
            "sha256:3d0fc7ac8da2de811bbc890a4a2a7b32ffc5f59fb9ee36a3e391cdec65548c77" -or
        [double]$bw20fCandidate.global_requested_correction_scale -ne 0.5 -or
        @($bw20fCandidate.branch_surfaces).Count -ne 0 -or
        [string]$bw20fCharacterization.fixture_id -cne
            "SDK.BW20F.godot_jolt_material_sled.v1" -or
        (@($bw20fCharacterization.authored_friction_values) -join ",") -cne
            "0.09,0.37,0.76,1.18" -or
        [int]$bw20fCharacterization.expected_world_count -ne 13 -or
        [int]$bw20fCharacterization.expected_gate_count -ne 23 -or
        (@($bw20fReservation.locomotion_campaign_seeds) -join ",") -cne
            "23001,23002,23003" -or
        -not [bool]$bw20fReservation.stage_1_does_not_open_locomotion_seeds
    ) {
        throw "BW20F frozen identity, matrix, or claim class changed"
    }
    $bw20fBindings = @(
        @($bw20fCandidate.source_bindings.Values),
        @($bw20fReservation.initial_reservation),
        @($bw20fReservation.unopened_continuity),
        @($bw20fPreregistration.numeric_threshold_provenance.inherited_contract),
        @($bw20fPreregistration.numeric_threshold_provenance.accepted_reference_manifest)
    ) | ForEach-Object { $_ }
    foreach ($binding in $bw20fBindings) {
        $bindingPath = Join-Path $repoRoot ([string]$binding.path)
        if (-not (Test-Path -LiteralPath $bindingPath -PathType Leaf)) {
            throw "BW20F pinned source is missing: $bindingPath"
        }
        $bindingHash = (
            Get-FileHash -Algorithm SHA256 -LiteralPath $bindingPath
        ).Hash.ToLowerInvariant()
        if ($bindingHash -cne [string]$binding.raw_sha256) {
            throw "BW20F pinned source changed: $bindingPath"
        }
    }
    $bw20fReferenceCharacterization = (
        $bw20fPreregistration.numeric_threshold_provenance.accepted_reference_manifest
    )
    $bw20fReferencePath = [System.IO.Path]::GetFullPath(
        [string]$bw20fReferenceCharacterization.retained_characterization_report
    )
    if (-not (Test-Path -LiteralPath $bw20fReferencePath -PathType Leaf)) {
        throw "BW20F retained threshold-provenance report is missing"
    }
    $bw20fReferenceHash = (
        Get-FileHash -Algorithm SHA256 -LiteralPath $bw20fReferencePath
    ).Hash.ToLowerInvariant()
    if (
        $bw20fReferenceHash -cne
            [string]$bw20fReferenceCharacterization.retained_characterization_sha256
    ) {
        throw "BW20F retained threshold-provenance report changed"
    }
    $sourceStatus = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    )
    $sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    $originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
    $remoteLine = (& git -C $repoRoot ls-remote origin refs/heads/main).Trim()
    $remoteMain = ($remoteLine -split "\s+")[0]
    if (
        $LASTEXITCODE -ne 0 -or
        $sourceStatus.Count -ne 0 -or
        $sourceCommit -cnotmatch "^[0-9a-f]{40}$" -or
        $sourceCommit -ceq
            [string]$bw20fPreregistration.implementation_parent_commit -or
        $sourceCommit -cne $originMain -or
        $sourceCommit -cne $remoteMain -or
        [string]$bw20fAttempt.source_commit -cne $sourceCommit -or
        [string]$bw20fAttempt.origin_main_commit -cne $originMain -or
        [string]$bw20fAttempt.remote_main_commit -cne $remoteMain -or
        [string]$bw20fAttempt.godot_version -cne $bw20fGodotVersion -or
        [string]$bw20fAttempt.godot_executable_sha256 -cne
            $bw20fGodotExecutableSha256 -or
        [string]$bw20fAttempt.preregistration_raw_sha256 -cne
            (Get-FileHash -Algorithm SHA256 -LiteralPath $bw20fPreregistrationPath).Hash.ToLowerInvariant()
    ) {
        throw "BW20F requires clean, pushed source distinct from its parent"
    }
    $evidenceRoot = [System.IO.Path]::GetFullPath(
        (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
    )
    $evidencePrefix = $evidenceRoot.TrimEnd("\") + "\"
    $expectedDirectoryName = (
        "balanced-wave-bw20f-material-characterization-" +
        $sourceCommit.Substring(0, 7)
    )
    if (
        -not $earlyOutputDirectory.StartsWith(
            $evidencePrefix,
            [StringComparison]::OrdinalIgnoreCase
        ) -or
        (Split-Path -Leaf $earlyOutputDirectory) -cne $expectedDirectoryName
    ) {
        throw "BW20F worker output is outside the supervisor's source-named evidence root"
    }
    $bw20fPrerequisiteEvidence = (
        $bw20fCandidate.source_bindings.bw19v_closure
    )
}
$bw4ValidationEvidence = $null
if ($isBw4) {
    $bw4PreregistrationPath = Join-Path $sdkRoot (
        "balanced_wave_bw4_preregistration.json"
    )
    $bw4Preregistration = (
        Get-Content -LiteralPath $bw4PreregistrationPath -Raw |
            ConvertFrom-Json -AsHashtable
    )
    $bw4ValidationEvidence = (
        $bw4Preregistration.prerequisite_evidence.bw3r_validation
    )
    $bw4ValidationPath = [string]$bw4ValidationEvidence.path
    if (-not (Test-Path -LiteralPath $bw4ValidationPath -PathType Leaf)) {
        throw "BW4 prerequisite BW3R report is missing: $bw4ValidationPath"
    }
    $bw4ValidationHash = (
        Get-FileHash -Algorithm SHA256 -LiteralPath $bw4ValidationPath
    ).Hash.ToLowerInvariant()
    $bw4ValidationReport = (
        Get-Content -LiteralPath $bw4ValidationPath -Raw |
            ConvertFrom-Json -AsHashtable
    )
    if (
        $bw4ValidationHash -cne [string]$bw4ValidationEvidence.sha256 -or
        [string]$bw4ValidationReport.schema_version -cne
            "sporespore_balanced_wave_bw3r_validation_report_v1" -or
        -not [bool]$bw4ValidationReport.accepted -or
        [string]$bw4ValidationReport.source_commit -cne
            [string]$bw4ValidationEvidence.source_commit -or
        [int]$bw4ValidationReport.receipt.observed_world_count -ne 12 -or
        [int]$bw4ValidationReport.receipt.passed_gate_count -ne 22 -or
        [int]$bw4ValidationReport.receipt.failed_gate_count -ne 0
    ) {
        throw "BW4 prerequisite BW3R report identity or acceptance is invalid"
    }
}
$bw5vSelectionEvidence = $null
if ($isBw5v) {
    $bw5vPreregistrationPath = Join-Path $sdkRoot (
        "balanced_wave_bw5v_preregistration.json"
    )
    $bw5vPreregistration = (
        Get-Content -LiteralPath $bw5vPreregistrationPath -Raw |
            ConvertFrom-Json -AsHashtable
    )
    $bw5vSelectionEvidence = $bw5vPreregistration.selection_evidence
    $bw5vSelectionPath = [string]$bw5vSelectionEvidence.path
    if (-not (Test-Path -LiteralPath $bw5vSelectionPath -PathType Leaf)) {
        throw "BW5V prerequisite BW5R selection is missing: $bw5vSelectionPath"
    }
    $bw5vSelectionHash = (
        Get-FileHash -Algorithm SHA256 -LiteralPath $bw5vSelectionPath
    ).Hash.ToLowerInvariant()
    $bw5vSelectionReport = (
        Get-Content -LiteralPath $bw5vSelectionPath -Raw |
            ConvertFrom-Json -AsHashtable
    )
    if (
        $bw5vSelectionHash -cne [string]$bw5vSelectionEvidence.sha256 -or
        [string]$bw5vSelectionReport.schema_version -cne
            "sporespore_balanced_wave_bw5r_selection_report_v1" -or
        -not [bool]$bw5vSelectionReport.accepted -or
        -not [bool]$bw5vSelectionReport.development_data_only -or
        [string]$bw5vSelectionReport.source_commit -cne
            [string]$bw5vSelectionEvidence.source_commit -or
        [string]$bw5vSelectionReport.selected_candidate_id -cne "BW5R-B" -or
        [string]$bw5vSelectionReport.selected_policy_id -cne
            "sporespore_balanced_wave_bw5r_b_v1" -or
        [string]$bw5vSelectionReport.selected_candidate_policy_digest -cne
            "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f" -or
        [int]$bw5vSelectionReport.input_report_count -ne 15 -or
        [int]$bw5vSelectionReport.observed_world_count -ne 174 -or
        -not [bool]$bw5vSelectionReport.complete_matrix_per_candidate -or
        [bool]$bw5vSelectionReport.early_stop_triggered
    ) {
        throw "BW5V prerequisite BW5R selection identity is invalid"
    }
}
$bw5cValidationEvidence = $null
if ($isBw5c) {
    $bw5cPreregistrationPath = Join-Path $sdkRoot (
        "balanced_wave_bw5c_preregistration.json"
    )
    $bw5cPreregistration = (
        Get-Content -LiteralPath $bw5cPreregistrationPath -Raw |
            ConvertFrom-Json -AsHashtable
    )
    $bw5cValidationEvidence = (
        $bw5cPreregistration.prerequisite_evidence.bw5v_validation
    )
    $bw5cValidationPath = [string]$bw5cValidationEvidence.path
    if (-not (Test-Path -LiteralPath $bw5cValidationPath -PathType Leaf)) {
        throw "BW5C prerequisite BW5V report is missing: $bw5cValidationPath"
    }
    $bw5cValidationHash = (
        Get-FileHash -Algorithm SHA256 -LiteralPath $bw5cValidationPath
    ).Hash.ToLowerInvariant()
    $bw5cValidationReport = (
        Get-Content -LiteralPath $bw5cValidationPath -Raw |
            ConvertFrom-Json -AsHashtable
    )
    $bw5cReceipt = $bw5cValidationReport.receipt
    $bw5cManifestReceipt = $bw5cReceipt.validation_manifest
    $bw5cSelectedPolicy = $bw5cPreregistration.selected_policy
    $bw5cSelectedPolicyPath = Join-Path $repoRoot (
        [string]$bw5cSelectedPolicy.manifest_path
    )
    $bw5cSelectedPolicyHash = (
        Get-FileHash -Algorithm SHA256 -LiteralPath $bw5cSelectedPolicyPath
    ).Hash.ToLowerInvariant()
    $bw5cReservationPreregistration = (
        $bw5cPreregistration.reservation_provenance.bw5v_preregistration
    )
    $bw5cReservationPreregistrationPath = Join-Path $repoRoot (
        [string]$bw5cReservationPreregistration.path
    )
    $bw5cReservationPreregistrationHash = (
        Get-FileHash -Algorithm SHA256 `
            -LiteralPath $bw5cReservationPreregistrationPath
    ).Hash.ToLowerInvariant()
    $bw5cReservationManifest = (
        $bw5cPreregistration.reservation_provenance.bw5v_validation_manifest
    )
    $bw5cReservationManifestPath = Join-Path $repoRoot (
        [string]$bw5cReservationManifest.path
    )
    $bw5cReservationManifestHash = (
        Get-FileHash -Algorithm SHA256 `
            -LiteralPath $bw5cReservationManifestPath
    ).Hash.ToLowerInvariant()
    if (
        [string]$bw5cPreregistration.schema_version -cne
            "sporespore_balanced_wave_bw5c_preregistration_v1" -or
        [string]$bw5cPreregistration.status -cne
            "frozen_before_first_bw5c_characterization_world" -or
        -not [bool]$bw5cPreregistration.cold_characterization -or
        [bool]$bw5cPreregistration.cold_acceptance -or
        [string]$bw5cSelectedPolicy.candidate_id -cne "BW5R-B" -or
        [string]$bw5cSelectedPolicy.policy_id -cne
            "sporespore_balanced_wave_bw5r_b_v1" -or
        [string]$bw5cSelectedPolicy.policy_digest -cne
            "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f" -or
        [string]$bw5cSelectedPolicy.runtime_profile_digest -cne
            "sha256:e02fa9c7599cffe8b331f7d8c10b6cc4dbffe7408e319169c09cbcb7d9b3890e" -or
        -not [bool]$bw5cSelectedPolicy.branch_surfaces_required_empty -or
        $bw5cSelectedPolicyHash -cne
            [string]$bw5cSelectedPolicy.manifest_sha256 -or
        $bw5cReservationPreregistrationHash -cne
            [string]$bw5cReservationPreregistration.sha256 -or
        $bw5cReservationManifestHash -cne
            [string]$bw5cReservationManifest.sha256 -or
        $bw5cValidationHash -cne [string]$bw5cValidationEvidence.sha256 -or
        [string]$bw5cValidationReport.schema_version -cne
            "sporespore_balanced_wave_bw5v_validation_report_v1" -or
        -not [bool]$bw5cValidationReport.accepted -or
        [string]$bw5cValidationReport.result_status -cne
            "validation_passed" -or
        [string]$bw5cValidationReport.source_commit -cne
            [string]$bw5cValidationEvidence.source_commit -or
        -not [bool]$bw5cValidationReport.development_data_only -or
        [string]$bw5cValidationReport.campaign_partition -cne
            "independent_bw5v_validation" -or
        -not [bool]$bw5cValidationReport.validation_data_only -or
        [bool]$bw5cValidationReport.opened_validation_replay -or
        [bool]$bw5cValidationReport.cold_acceptance -or
        [string]$bw5cValidationReport.candidate_id -cne "BW5R-B" -or
        [string]$bw5cValidationReport.policy_id -cne
            "sporespore_balanced_wave_bw5r_b_v1" -or
        [string]$bw5cValidationReport.candidate_policy_digest -cne
            "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f" -or
        [int]$bw5cReceipt.observed_world_count -ne 12 -or
        [int]$bw5cReceipt.passed_gate_count -ne 22 -or
        [int]$bw5cReceipt.failed_gate_count -ne 0 -or
        [int]$bw5cReceipt.observed_treatment_pass_count -ne 9 -or
        [int]$bw5cReceipt.observed_control_pass_count -ne 3 -or
        [int]$bw5cReceipt.observed_pair_pass_count -ne 3 -or
        [int]$bw5cReceipt.integrity_failure_count -ne 0 -or
        -not [bool]$bw5cManifestReceipt.ok -or
        -not [bool]$bw5cManifestReceipt.cold_reservation_exact -or
        [bool]$bw5cManifestReceipt.locomotion_outcome_exposed
    ) {
        throw "BW5C prerequisite identity, reservation, or acceptance is invalid"
    }
}

$timestamp = Get-Date -Format "yyyyMMddTHHmmssfff"
$runRoot = Join-Path ([System.IO.Path]::GetFullPath($LogRoot)) $timestamp
$projectRoot = Join-Path $runRoot "project"
[void][System.IO.Directory]::CreateDirectory($projectRoot)

foreach ($directory in @("scripts", "tests", "sdk")) {
    $linkPath = Join-Path $projectRoot $directory
    $targetPath = Join-Path $repoRoot $directory
    [void](New-Item -ItemType Junction -Path $linkPath -Target $targetPath)
}

$projectText = @"
; Isolated SporeSpore $campaignLabel.

config_version=5

[application]

config/name="sporespore-sdk-godot-jolt-friction-characterization"
config/features=PackedStringArray("4.7", "Forward Plus")

[debug]

gdscript/warnings/shadowed_global_identifier=0

[physics]

3d/physics_engine="Jolt Physics"
jolt_physics_3d/simulation/velocity_steps=20
jolt_physics_3d/simulation/position_steps=7
"@
[System.IO.File]::WriteAllText(
    (Join-Path $projectRoot "project.godot"),
    $projectText,
    [System.Text.UTF8Encoding]::new($false)
)

$appData = Join-Path $runRoot "worker\appdata"
$localAppData = Join-Path $runRoot "worker\localappdata"
[void][System.IO.Directory]::CreateDirectory($appData)
[void][System.IO.Directory]::CreateDirectory($localAppData)
$transcriptPath = Join-Path $runRoot "transcript.log"
$engineLogPath = Join-Path $runRoot "engine.log"
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = $appData
    $env:LOCALAPPDATA = $localAppData
    $godotArguments = @(
        "--headless",
        "--path", $projectRoot,
        "--log-file", $engineLogPath,
        "--script", (
            "res://tests/" +
            "test_sdk_godot_jolt_friction_ladder_characterization.gd"
        )
    )
    if ($isProspective) {
        $campaignArgument = if ($isBw20f) {
            "--bw20f"
        } elseif ($isBw5c) {
            "--bw5c"
        } elseif ($isBw5v) {
            "--bw5v"
        } elseif ($isBw4) {
            "--bw4"
        } elseif ($isBw3r) {
            "--bw3r"
        } else {
            "--bw3"
        }
        $godotArguments += @("--", $campaignArgument)
        if ($PreflightOnly) {
            $godotArguments += "--preflight-only"
        }
    }
    & $godotPath @godotArguments 2>&1 |
        Tee-Object -FilePath $transcriptPath
    $godotExitCode = $LASTEXITCODE
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}

$receiptLines = @(
    Get-Content -LiteralPath $transcriptPath |
        Where-Object { $_.StartsWith($receiptPrefix) }
)
if ($receiptLines.Count -ne 1) {
    throw (
        "Expected exactly one $receiptPrefix line, found " +
        "$($receiptLines.Count). Transcript: $transcriptPath"
    )
}
$receiptJson = $receiptLines[0].Substring($receiptPrefix.Length)
$receipt = $receiptJson | ConvertFrom-Json -AsHashtable
if ($isBw20f) {
    $receipt.engine["godot_version"] = $bw20fGodotVersion
    $receipt.engine["godot_executable_sha256"] = $bw20fGodotExecutableSha256
}
$receiptPassed = (
    $godotExitCode -eq 0 -and
    [string]$receipt.schema_version -ceq $expectedSchema -and
    [bool]$receipt.ok -and
    [int]$receipt.passed_gate_count -eq $expectedGateCount -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.expected_gate_count -eq $expectedGateCount -and
    -not [bool]$receipt.walking -and
    -not [bool]$receipt.physical_acceptance_authority -and
    -not [bool]$receipt.completed_engine_neutral_sdk
)
if ($isBw4 -or $isBw5c -or $isBw20f) {
    $receiptPassed = (
        $receiptPassed -and
        [bool]$receipt.cold_characterization -and
        -not [bool]$receipt.development_data_only -and
        -not [bool]$receipt.material_robustness
    )
}
if ($isBw5v) {
    $receiptPassed = (
        $receiptPassed -and
        [bool]$receipt.development_data_only -and
        -not [bool]$receipt.cold_characterization -and
        -not [bool]$receipt.material_robustness
    )
}
if ($PreflightOnly) {
    $receiptPassed = (
        $receiptPassed -and
        [int]$receipt.world_build_count -eq 0 -and
        [int]$receipt.scene_tree_insertion_count -eq 0 -and
        -not [bool]$receipt.physical_outcome_opened -and
        -not [bool]$receipt.material_robustness -and
        [int]$receipt.fixture_receipts.Count -eq $expectedFixtureCount
    )
} else {
    $receiptPassed = (
        $receiptPassed -and
        [int]$receipt.expected_world_count -eq $expectedWorldCount -and
        [int]$receipt.observed_world_count -eq $expectedWorldCount -and
        [bool]$receipt.frictionless_control.ok -and
        [int]$receipt.positive_cells.Count -eq $expectedPositiveCellCount -and
        [bool]$receipt.monotonicity.ok -and
        -not [bool]$receipt.adapter_actuation_applied -and
        -not [bool]$receipt.physics_transform_or_velocity_written -and
        -not [bool]$receipt.balance_improvement -and
        -not [bool]$receipt.physical_balance_recovery -and
        -not [bool]$receipt.friction_material_locomotion_robustness -and
        -not [bool]$receipt.continuous_friction_coverage -and
        -not [bool]$receipt.cross_engine_equivalence -and
        -not [bool]$receipt.rough_terrain_robustness -and
        -not [bool]$receipt.external_push_recovery -and
        -not [bool]$receipt.sensor_fault_robustness -and
        -not [bool]$receipt.fresh_morphology_validation
    )
}

$bw20fProductionGate = $null
if ($isBw20f) {
    $bw20fGatePath = Join-Path $sdkRoot (
        "balanced_wave_bw20f_material_characterization_gate.ps1"
    )
    . $bw20fGatePath
    $bw20fProductionGate = Test-Bw20fMaterialCharacterizationReceipt `
        -Receipt $receipt
    $receiptPassed = $receiptPassed -and [bool]$bw20fProductionGate.ok
}

if (-not [string]::IsNullOrWhiteSpace($Output)) {
    $worktreeStatus = @(
        & git -C $repoRoot status --porcelain=v1 --untracked-files=all
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect the source worktree"
    }
    if ($worktreeStatus.Count -ne 0) {
        throw (
            "Refusing to retain evidence from a dirty worktree. " +
            "Commit the implementation and rerun."
        )
    }
    $sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sourceCommit)) {
        throw "Unable to resolve the source commit"
    }
    $originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
    if ($LASTEXITCODE -ne 0 -or $originMain -cne $sourceCommit) {
        throw (
            "Refusing retained evidence because HEAD is not the locally " +
            "verified origin/main revision"
        )
    }
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    if ([System.IO.Path]::GetFileName($outputPath) -cne "report.json") {
        throw "The retained $campaignLabel report filename must be exactly report.json"
    }
    if (Test-Path -LiteralPath $outputPath) {
        throw "Refusing to overwrite an existing $campaignLabel report: $outputPath"
    }
    $outputDirectory = Split-Path -Parent $outputPath
    [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
    $retainedTranscriptPath = Join-Path $outputDirectory "transcript.log"
    $retainedEngineLogPath = Join-Path $outputDirectory "engine.log"
    [System.IO.File]::Copy($transcriptPath, $retainedTranscriptPath, $false)
    [System.IO.File]::Copy($engineLogPath, $retainedEngineLogPath, $false)
    $sourcePaths = [ordered]@{
        bootstrap = $(if ($isProspective) {
            "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md"
        } else {
            "docs/SDK_GODOT_JOLT_FRICTION_MATERIAL_ROBUSTNESS_BOOTSTRAP.md"
        })
        test = (
            "tests/test_sdk_godot_jolt_friction_ladder_characterization.gd"
        )
        runner = (
            "sdk/run_godot_jolt_friction_ladder_characterization.ps1"
        )
        rig = "scripts/lab/rigs/sdk_friction_ladder_sled_rig.gd"
        base_rig = "scripts/lab/rigs/friction_sled_rig.gd"
        capture_clock = "scripts/lab/capture_clock.gd"
        observer_profile = "scripts/lab/observer_profile.gd"
        observed_rigid_body = "scripts/lab/mechanics/observed_rigid_body.gd"
        contact_capacity = "scripts/lab/mechanics/contact_capacity.gd"
        canonicalizer = "scripts/lab/mechanics/contact_canonicalizer.gd"
        slip_observer = "scripts/lab/mechanics/contact_slip_observer.gd"
        breakaway_analyzer = (
            "scripts/lab/mechanics/friction_breakaway_analyzer.gd"
        )
        canonical_json = "scripts/lab/canonical_json.gd"
        frozen_value = "scripts/lab/frozen_value.gd"
        failure_codes = "scripts/lab/failure_codes.gd"
        finite_sanitizer = "scripts/lab/finite_sanitizer.gd"
    }
    if ($isProspective) {
        $sourcePaths["campaign_runner"] = if ($isBw20f) {
            "sdk/run_balanced_wave_bw20f_material_characterization.ps1"
        } elseif ($isBw5c) {
            "sdk/run_balanced_wave_bw5c_material_characterization.ps1"
        } elseif ($isBw5v) {
            "sdk/run_balanced_wave_bw5v_material_characterization.ps1"
        } elseif ($isBw4) {
            "sdk/run_balanced_wave_bw4_material_characterization.ps1"
        } elseif ($isBw3r) {
            "sdk/run_balanced_wave_bw3r_material_characterization.ps1"
        } else {
            "sdk/run_balanced_wave_bw3_material_characterization.ps1"
        }
        $sourcePaths["preregistration"] = if ($isBw20f) {
            "sdk/balanced_wave_bw20f_cold_material_preregistration.json"
        } elseif ($isBw5c) {
            "sdk/balanced_wave_bw5c_preregistration.json"
        } elseif ($isBw5v) {
            "sdk/balanced_wave_bw5v_preregistration.json"
        } elseif ($isBw4) {
            "sdk/balanced_wave_bw4_preregistration.json"
        } elseif ($isBw3r) {
            "sdk/balanced_wave_bw3r_preregistration.json"
        } else {
            "sdk/balanced_wave_bw3_preregistration.json"
        }
        $sourcePaths["selected_policy"] = if ($isBw20f) {
            "sdk/balanced_wave_bw15f_selected_policy.json"
        } else {
            "sdk/balanced_wave_selected_policy.json"
        }
        if ($isBw20f) {
            $sourcePaths["production_gate"] =
                "sdk/balanced_wave_bw20f_material_characterization_gate.ps1"
            $sourcePaths["fixture_preflight"] =
                "tests/test_sdk_balanced_wave_bw20f_material_characterization_preflight.gd"
            $sourcePaths["bw19v_closure"] =
                "sdk/balanced_wave_bw19v_closure_manifest.json"
        }
        if ($isBw5c) {
            $sourcePaths["reservation_preregistration"] =
                "sdk/balanced_wave_bw5v_preregistration.json"
            $sourcePaths["reservation_validation_manifest"] =
                "sdk/balanced_wave_bw5v_validation_manifest.json"
        }
    }
    $sources = [ordered]@{}
    foreach ($entry in $sourcePaths.GetEnumerator()) {
        $absolutePath = Join-Path $repoRoot $entry.Value
        $sources[$entry.Key] = [ordered]@{
            path = $entry.Value
            sha256 = (
                Get-FileHash -Algorithm SHA256 -LiteralPath $absolutePath
            ).Hash.ToLowerInvariant()
        }
    }
    $report = [ordered]@{
        schema_version = $(if ($isBw20f) {
            "sporespore_balanced_wave_bw20f_material_characterization_report_v1"
        } elseif ($isBw5c) {
            "sporespore_balanced_wave_bw5c_material_characterization_report_v1"
        } elseif ($isBw5v) {
            "sporespore_balanced_wave_bw5v_material_characterization_report_v1"
        } elseif ($isBw4) {
            "sporespore_balanced_wave_bw4_material_characterization_report_v1"
        } elseif ($isBw3r) {
            "sporespore_balanced_wave_bw3r_material_characterization_report_v1"
        } elseif ($isBw3) {
            "sporespore_balanced_wave_bw3_material_characterization_report_v1"
        } else {
            "sporespore_godot_jolt_friction_ladder_r1_report_v1"
        })
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        source_commit = $sourceCommit
        source_worktree_clean = $true
        source_matches_origin_main = $true
        campaign = $Campaign
        host_identity = $(if ($isBw20f) {
            [ordered]@{
                godot_version = $bw20fGodotVersion
                godot_executable_sha256 = $bw20fGodotExecutableSha256
                physics_engine = "Jolt Physics"
                physics_hz = 120
                solver_velocity_steps = 20
                solver_position_steps = 7
            }
        } else {
            $null
        })
        development_data_only = (
            $isProspective -and -not ($isBw4 -or $isBw5c -or $isBw20f)
        )
        cold_characterization = $isBw4 -or $isBw5c -or $isBw20f
        prerequisite_evidence = $(if ($isBw20f) {
            [ordered]@{
                bw19v_closure = [ordered]@{
                    path = [string]$bw20fPrerequisiteEvidence.path
                    sha256 = [string]$bw20fPrerequisiteEvidence.raw_sha256
                    experiment_source_commit = (
                        [string]$bw20fPrerequisiteEvidence.experiment_source_commit
                    )
                }
                bw5c_material_characterization = [ordered]@{
                    path = [string](
                        $bw20fReferenceCharacterization.retained_characterization_report
                    )
                    sha256 = [string](
                        $bw20fReferenceCharacterization.retained_characterization_sha256
                    )
                    threshold_use = "inherited_operational_contract_only"
                }
            }
        } elseif ($isBw5c) {
            [ordered]@{
                bw5v_validation = [ordered]@{
                    path = [string]$bw5cValidationEvidence.path
                    sha256 = [string]$bw5cValidationEvidence.sha256
                    source_commit =
                        [string]$bw5cValidationEvidence.source_commit
                }
            }
        } elseif ($isBw5v) {
            [ordered]@{
                bw5r_selection = [ordered]@{
                    path = [string]$bw5vSelectionEvidence.path
                    sha256 = [string]$bw5vSelectionEvidence.sha256
                    source_commit =
                        [string]$bw5vSelectionEvidence.source_commit
                }
            }
        } elseif ($isBw4) {
            [ordered]@{
                bw3r_validation = [ordered]@{
                    path = [string]$bw4ValidationEvidence.path
                    sha256 = [string]$bw4ValidationEvidence.sha256
                    source_commit =
                        [string]$bw4ValidationEvidence.source_commit
                }
            }
        } else {
            [ordered]@{}
        })
        accepted = $receiptPassed
        result_status = $(if ($receiptPassed) { "passed" } else { "rejected" })
        godot_exit_code = $godotExitCode
        stopping_rule =
            "no_selective_replicate_rerun_or_post_result_gate_edit"
        godot = [ordered]@{
            executable_path = $godotPath
            executable_sha256 = (
                Get-FileHash -Algorithm SHA256 -LiteralPath $godotPath
            ).Hash.ToLowerInvariant()
            version = (& $godotPath --version).Trim()
            physics_engine = "Jolt Physics"
            physics_hz = 120
            solver_velocity_steps = 20
            solver_position_steps = 7
        }
        sources = $sources
        transcript = [ordered]@{
            path = "transcript.log"
            sha256 = (
                Get-FileHash -Algorithm SHA256 `
                    -LiteralPath $retainedTranscriptPath
            ).Hash.ToLowerInvariant()
        }
        engine_log = [ordered]@{
            path = "engine.log"
            sha256 = (
                Get-FileHash -Algorithm SHA256 `
                    -LiteralPath $retainedEngineLogPath
            ).Hash.ToLowerInvariant()
        }
        receipt = $receipt
        production_gate_evaluation = $bw20fProductionGate
    }
    $temporaryPath = "$outputPath.tmp"
    $json = $report | ConvertTo-Json -Depth 32
    [System.IO.File]::WriteAllText(
        $temporaryPath,
        "$json`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    [System.IO.File]::Move($temporaryPath, $outputPath, $false)
    Write-Host "Retained $campaignLabel report: $outputPath"
}

if (-not $receiptPassed) {
    throw (
        "The $campaignLabel result was rejected. " +
        "Godot exit code: $godotExitCode. Transcript: $transcriptPath"
    )
}

Write-Host "Godot/Jolt $campaignLabel passed."
Write-Host "Transcript: $transcriptPath"

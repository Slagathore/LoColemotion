#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Bw4Characterization = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "balanced-wave-bw4-material-characterization-4de55aa\report.json"
    ),
    [string]$Bw5vCharacterization = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "balanced-wave-bw5v-material-characterization-2a5eb94\report.json"
    ),
    [string]$Bw5cCharacterization = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "balanced-wave-bw5c-material-characterization-dca2618\report.json"
    ),
    [string]$Bw20fCharacterization = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "balanced-wave-bw20f-material-characterization-476aa4e\report.json"
    ),
    [string]$Bw22mCharacterization = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "balanced-wave-bw22m-material-characterization-ff9a2cc\report.json"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_sdk_godot_jolt_material_profiles"
    ),
    [string]$Output = "",
    [switch]$Bw20fPublicationAuthorized,
    [string]$Bw20fPublicationAttempt = "",
    [switch]$Bw22mPublicationAuthorized,
    [string]$Bw22mPublicationAttempt = "",
    [switch]$Bw24mPublicationAuthorized,
    [string]$Bw24mPublicationAttempt = ""
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$godotPath = [System.IO.Path]::GetFullPath($Godot)
if (
    $Bw24mPublicationAuthorized -or
    -not [string]::IsNullOrWhiteSpace($Bw24mPublicationAttempt)
) {
    if ([string]::IsNullOrWhiteSpace($Output)) {
        throw "Profile-publication authorization is valid only with -Output"
    }
    throw (
        "BW24M retained publication requires the distinct " +
        "run_godot_jolt_bw24m_material_profile_conformance.ps1 route"
    )
}
if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable not found: $godotPath"
}

$expectedBw20fProfileIds = @(
    "godot_jolt_bw20f_mu009_v1",
    "godot_jolt_bw20f_mu037_v1",
    "godot_jolt_bw20f_mu076_v1",
    "godot_jolt_bw20f_mu118_v1"
)
$expectedBw20fProfileSha256 = @(
    "sha256:92891cfbed2b30c5d6c72fa02a30770fcf75880416a92fe2f69d9ece8246ee55",
    "sha256:690e5c2f035a7a3efc32fa31c86cfab03299f8c539500e110b5ddf9e35b6dfb9",
    "sha256:76f42bc89da95e09d081d17d5e3aa520de25fa6a352067dd8c30ace3834667b0",
    "sha256:e0c6a6d78ae63a129e7ae44088aeb86da44941dba8cfcfd5680f73a236c9b297"
)
$expectedBw22mProfileIds = @(
    "godot_jolt_bw22m_mu057_v1",
    "godot_jolt_bw22m_mu069_v1",
    "godot_jolt_bw22m_mu081_v1"
)
$expectedBw22mProfileSha256 = @(
    "sha256:754c2f45b19dea315bd3527db8b8b87041be57cb7e4999412710d82c7c57903f",
    "sha256:a66f00fb0836a0838ab20e3f54c531ee5e9a6ea50180780e81e4f6106aad5ff3",
    "sha256:9446ba227a7a80f7592ffb7e358b8903a4e7afeb7297d5ba94dab87be8e33cbd"
)
$expectedBw24mProfileIds = @(
    "godot_jolt_bw24m_mu059_v1",
    "godot_jolt_bw24m_mu071_v1",
    "godot_jolt_bw24m_mu083_v1"
)
$expectedBw24mProfileSha256 = @(
    "sha256:2d8a2571c129dbe7b2b894bae1aa28f5650fdbea27fcb65a149566c54a536173",
    "sha256:a8efdd111b740391931219d720079beffeea8181e5c46fd00ea7acb6108ab8ee",
    "sha256:e5916d9e17f87120e5cc04ff03e8688c4dea3919715a68854a8dce29e4d9c2a0"
)
$profilePreregistrationPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_profile_publication_preregistration.json"
$profilePreregistration = Get-Content -Raw -LiteralPath (
    $profilePreregistrationPath
) | ConvertFrom-Json -AsHashtable
$declaredProfiles = @($profilePreregistration.profiles)
if (-not (
    [string]$profilePreregistration.schema_version -ceq
        "sporespore_balanced_wave_bw20f_material_profile_publication_preregistration_v1" -and
    [string]$profilePreregistration.status -ceq
        "frozen_before_first_bw20f_profile_publication_receipt" -and
    [string]$profilePreregistration.implementation_parent_commit -ceq
        "78c11e7abe3c33e95aa11398ce28632ff6b450f7" -and
    [string]$profilePreregistration.study_classification -ceq
        "deterministic_zero_world_adapter_profile_publication" -and
    [int]$profilePreregistration.world_build_count -eq 0 -and
    [int]$profilePreregistration.locomotion_seed_world_count -eq 0 -and
    $declaredProfiles.Count -eq 4 -and
    (@($declaredProfiles | ForEach-Object {
        [string]$_.profile_id
    }) -join "|") -ceq ($expectedBw20fProfileIds -join "|") -and
    (@($declaredProfiles | ForEach-Object {
        [string]$_.expected_profile_sha256
    }) -join "|") -ceq ($expectedBw20fProfileSha256 -join "|") -and
    -not [bool]$profilePreregistration.claims.profile_published -and
    -not [bool]$profilePreregistration.claims.friction_or_material_locomotion_robustness -and
    -not [bool]$profilePreregistration.claims.continuous_friction_coverage -and
    -not [bool]$profilePreregistration.claims.cross_engine_equivalence -and
    -not [bool]$profilePreregistration.claims.release_authorized -and
    -not [bool]$profilePreregistration.claims.physical_acceptance_authority
)) {
    throw "BW20F profile-publication preregistration changed or is incomplete"
}

$bw22mProfilePreregistrationPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw22m_material_profile_publication_preregistration.json"
$bw22mProfilePreregistration = Get-Content -Raw -LiteralPath (
    $bw22mProfilePreregistrationPath
) | ConvertFrom-Json -AsHashtable
$declaredBw22mProfiles = @($bw22mProfilePreregistration.profiles)
if (-not (
    [string]$bw22mProfilePreregistration.schema_version -ceq
        "sporespore_balanced_wave_bw22m_material_profile_publication_preregistration_v1" -and
    [string]$bw22mProfilePreregistration.status -ceq
        "frozen_before_first_bw22m_profile_publication_receipt" -and
    [string]$bw22mProfilePreregistration.implementation_parent_commit -ceq
        "de92b10a275c682dd9a6fc18be6408a24acf2c50" -and
    [string]$bw22mProfilePreregistration.study_classification -ceq
        "deterministic_zero_world_adapter_profile_publication" -and
    [int]$bw22mProfilePreregistration.world_build_count -eq 0 -and
    [int]$bw22mProfilePreregistration.locomotion_seed_world_count -eq 0 -and
    [bool]$bw22mProfilePreregistration.prerequisite_evidence.material_characterization_closure.post_closure_full_conformance_passed -and
    $declaredBw22mProfiles.Count -eq 3 -and
    (@($declaredBw22mProfiles | ForEach-Object {
        [string]$_.profile_id
    }) -join "|") -ceq ($expectedBw22mProfileIds -join "|") -and
    (@($declaredBw22mProfiles | ForEach-Object {
        [string]$_.expected_profile_sha256
    }) -join "|") -ceq ($expectedBw22mProfileSha256 -join "|") -and
    -not [bool]$bw22mProfilePreregistration.claims.profile_published -and
    -not [bool]$bw22mProfilePreregistration.claims.walking_acceptance -and
    -not [bool]$bw22mProfilePreregistration.claims.friction_or_material_locomotion_robustness -and
    -not [bool]$bw22mProfilePreregistration.claims.continuous_friction_coverage -and
    -not [bool]$bw22mProfilePreregistration.claims.portable_material_coefficient -and
    -not [bool]$bw22mProfilePreregistration.claims.cross_engine_equivalence -and
    -not [bool]$bw22mProfilePreregistration.claims.release_authorized -and
    -not [bool]$bw22mProfilePreregistration.claims.physical_acceptance_authority
)) {
    throw "BW22M profile-publication preregistration changed or is incomplete"
}

$bw4CharacterizationPath = [System.IO.Path]::GetFullPath(
    $Bw4Characterization
)
$expectedBw4CharacterizationHash =
    "f4a7291849d53540f31d58f40be97f26f01ad9cb76a2e2ae6fedabd56e0925c3"
if (-not (
    Test-Path -LiteralPath $bw4CharacterizationPath -PathType Leaf
)) {
    throw (
        "Pinned BW4 characterization report not found: " +
        $bw4CharacterizationPath
    )
}
$observedBw4CharacterizationHash = (
    Get-FileHash -Algorithm SHA256 -LiteralPath $bw4CharacterizationPath
).Hash.ToLowerInvariant()
if ($observedBw4CharacterizationHash -cne $expectedBw4CharacterizationHash) {
    throw (
        "Pinned BW4 characterization report hash mismatch. Expected " +
        "$expectedBw4CharacterizationHash, observed " +
        "$observedBw4CharacterizationHash"
    )
}
$bw4CharacterizationReport = (
    Get-Content -Raw -LiteralPath $bw4CharacterizationPath |
        ConvertFrom-Json -AsHashtable
)
$bw4Receipt = $bw4CharacterizationReport.receipt
$bw4EvidenceChecks = [ordered]@{
    report_schema = (
        [string]$bw4CharacterizationReport.schema_version -ceq
            "sporespore_balanced_wave_bw4_material_characterization_report_v1"
    )
    source_commit = (
        [string]$bw4CharacterizationReport.source_commit -ceq
            "4de55aa4521afa9ed2cd596199d809a0781b8ba2"
    )
    source_worktree_clean = (
        [bool]$bw4CharacterizationReport.source_worktree_clean
    )
    source_matches_origin_main = (
        [bool]$bw4CharacterizationReport.source_matches_origin_main
    )
    report_accepted = [bool]$bw4CharacterizationReport.accepted
    result_status = (
        [string]$bw4CharacterizationReport.result_status -ceq "passed"
    )
    campaign = [string]$bw4CharacterizationReport.campaign -ceq "BW4"
    report_not_development = (
        -not [bool]$bw4CharacterizationReport.development_data_only
    )
    report_cold = [bool]$bw4CharacterizationReport.cold_characterization
    receipt_schema = (
        [string]$bw4Receipt.schema_version -ceq
            "sporespore_balanced_wave_bw4_material_characterization_receipt_v1"
    )
    receipt_ok = [bool]$bw4Receipt.ok
    passed_gate_count = [int]$bw4Receipt.passed_gate_count -eq 23
    failed_gate_count = [int]$bw4Receipt.failed_gate_count -eq 0
    expected_gate_count = [int]$bw4Receipt.expected_gate_count -eq 23
    observed_world_count = [int]$bw4Receipt.observed_world_count -eq 13
    receipt_cold = [bool]$bw4Receipt.cold_characterization
    receipt_not_development = (
        -not [bool]$bw4Receipt.development_data_only
    )
    no_material_claim = -not [bool]$bw4Receipt.material_robustness
    positive_cell_count = [int]$bw4Receipt.positive_cells.Count -eq 4
}
$failedBw4EvidenceChecks = @(
    $bw4EvidenceChecks.GetEnumerator() |
        Where-Object { -not [bool]$_.Value } |
        ForEach-Object { [string]$_.Key }
)
if ($failedBw4EvidenceChecks.Count -ne 0) {
    throw (
        "Pinned BW4 characterization report failed its publication contract: " +
        ($failedBw4EvidenceChecks -join ", ")
    )
}
$expectedBw4Cells = @(
    [ordered]@{
        authored_friction = 0.15
        controller_mu = 0.12
        minimum_lower_ratio = 0.12744362813307736
        lower_force_n = 5.0
        upper_force_n = 7.0
    },
    [ordered]@{
        authored_friction = 0.5
        controller_mu = 0.48
        minimum_lower_ratio = 0.4844417851229055
        lower_force_n = 19.0
        upper_force_n = 21.0
    },
    [ordered]@{
        authored_friction = 0.9
        controller_mu = 0.89
        minimum_lower_ratio = 0.8925120993227881
        lower_force_n = 35.0
        upper_force_n = 36.0
    },
    [ordered]@{
        authored_friction = 1.4
        controller_mu = 1.0
        minimum_lower_ratio = 1.376945500678404
        lower_force_n = 54.0
        upper_force_n = 56.0
    }
)
for ($cellIndex = 0; $cellIndex -lt $expectedBw4Cells.Count; $cellIndex++) {
    $expectedCell = $expectedBw4Cells[$cellIndex]
    $observedCell = $bw4Receipt.positive_cells[$cellIndex]
    $observedDerivation = $observedCell.coefficient_derivation
    $cellPassed = (
        [Math]::Abs(
            [double]$observedCell.authored_friction -
            [double]$expectedCell.authored_friction
        ) -le 1.0e-12 -and
        [Math]::Abs(
            [double]$observedDerivation.controller_mu -
            [double]$expectedCell.controller_mu
        ) -le 1.0e-12 -and
        [Math]::Abs(
            [double]$observedDerivation.minimum_lower_ratio -
            [double]$expectedCell.minimum_lower_ratio
        ) -le 1.0e-12 -and
        [bool]$observedCell.ok -and
        [bool]$observedDerivation.ok -and
        [int]$observedCell.replicates.Count -eq 3
    )
    if (-not $cellPassed) {
        throw "BW4 characterization cell $cellIndex failed publication binding"
    }
    foreach ($replicate in $observedCell.replicates) {
        $bracketPassed = (
            [double]$replicate.breakaway_analysis.breakaway_force_lower_n -eq
                [double]$expectedCell.lower_force_n -and
            [double]$replicate.breakaway_analysis.breakaway_force_upper_n -eq
                [double]$expectedCell.upper_force_n
        )
        if (-not $bracketPassed) {
            throw (
                "BW4 characterization replicate bracket failed publication " +
                "binding for cell $cellIndex"
            )
        }
    }
}

$bw5vCharacterizationPath = [System.IO.Path]::GetFullPath(
    $Bw5vCharacterization
)
$expectedBw5vCharacterizationHash =
    "a99a7f2aa9798d26c7a4df9e9b218a5979195eb05dc97b02cd36a5dc21d45d84"
if (-not (
    Test-Path -LiteralPath $bw5vCharacterizationPath -PathType Leaf
)) {
    throw (
        "Pinned BW5V characterization report not found: " +
        $bw5vCharacterizationPath
    )
}
$observedBw5vCharacterizationHash = (
    Get-FileHash -Algorithm SHA256 -LiteralPath $bw5vCharacterizationPath
).Hash.ToLowerInvariant()
if (
    $observedBw5vCharacterizationHash -cne
        $expectedBw5vCharacterizationHash
) {
    throw (
        "Pinned BW5V characterization report hash mismatch. Expected " +
        "$expectedBw5vCharacterizationHash, observed " +
        "$observedBw5vCharacterizationHash"
    )
}
$bw5vCharacterizationReport = (
    Get-Content -Raw -LiteralPath $bw5vCharacterizationPath |
        ConvertFrom-Json -AsHashtable
)
$bw5vReceipt = $bw5vCharacterizationReport.receipt
$bw5vEvidenceChecks = [ordered]@{
    report_schema = (
        [string]$bw5vCharacterizationReport.schema_version -ceq
            "sporespore_balanced_wave_bw5v_material_characterization_report_v1"
    )
    source_commit = (
        [string]$bw5vCharacterizationReport.source_commit -ceq
            "2a5eb94dca81a8c638e31a0d7c9692c270b44ca6"
    )
    source_worktree_clean = (
        [bool]$bw5vCharacterizationReport.source_worktree_clean
    )
    source_matches_origin_main = (
        [bool]$bw5vCharacterizationReport.source_matches_origin_main
    )
    report_accepted = [bool]$bw5vCharacterizationReport.accepted
    result_status = (
        [string]$bw5vCharacterizationReport.result_status -ceq "passed"
    )
    campaign = [string]$bw5vCharacterizationReport.campaign -ceq "BW5V"
    report_development = (
        [bool]$bw5vCharacterizationReport.development_data_only
    )
    report_not_cold = (
        -not [bool]$bw5vCharacterizationReport.cold_characterization
    )
    receipt_schema = (
        [string]$bw5vReceipt.schema_version -ceq
            "sporespore_balanced_wave_bw5v_material_characterization_receipt_v1"
    )
    receipt_ok = [bool]$bw5vReceipt.ok
    passed_gate_count = [int]$bw5vReceipt.passed_gate_count -eq 19
    failed_gate_count = [int]$bw5vReceipt.failed_gate_count -eq 0
    expected_gate_count = [int]$bw5vReceipt.expected_gate_count -eq 19
    observed_world_count = [int]$bw5vReceipt.observed_world_count -eq 10
    receipt_development = [bool]$bw5vReceipt.development_data_only
    receipt_not_cold = -not [bool]$bw5vReceipt.cold_characterization
    no_material_claim = -not [bool]$bw5vReceipt.material_robustness
    positive_cell_count = [int]$bw5vReceipt.positive_cells.Count -eq 3
}
$failedBw5vEvidenceChecks = @(
    $bw5vEvidenceChecks.GetEnumerator() |
        Where-Object { -not [bool]$_.Value } |
        ForEach-Object { [string]$_.Key }
)
if ($failedBw5vEvidenceChecks.Count -ne 0) {
    throw (
        "Pinned BW5V characterization report failed its publication contract: " +
        ($failedBw5vEvidenceChecks -join ", ")
    )
}
$expectedBw5vCells = @(
    [ordered]@{
        authored_friction = 0.05
        controller_mu = 0.05
        minimum_lower_ratio = 0.051014061933156406
        lower_force_n = 2.0
        upper_force_n = 3.0
    },
    [ordered]@{
        authored_friction = 0.65
        controller_mu = 0.63
        minimum_lower_ratio = 0.6374671361558075
        lower_force_n = 25.0
        upper_force_n = 26.0
    },
    [ordered]@{
        authored_friction = 1.3
        controller_mu = 1.0
        minimum_lower_ratio = 1.3011857646200224
        lower_force_n = 51.0
        upper_force_n = 52.0
    }
)
for (
    $cellIndex = 0;
    $cellIndex -lt $expectedBw5vCells.Count;
    $cellIndex++
) {
    $expectedCell = $expectedBw5vCells[$cellIndex]
    $observedCell = $bw5vReceipt.positive_cells[$cellIndex]
    $observedDerivation = $observedCell.coefficient_derivation
    $cellPassed = (
        [Math]::Abs(
            [double]$observedCell.authored_friction -
            [double]$expectedCell.authored_friction
        ) -le 1.0e-12 -and
        [Math]::Abs(
            [double]$observedDerivation.controller_mu -
            [double]$expectedCell.controller_mu
        ) -le 1.0e-12 -and
        [Math]::Abs(
            [double]$observedDerivation.minimum_lower_ratio -
            [double]$expectedCell.minimum_lower_ratio
        ) -le 1.0e-12 -and
        [bool]$observedCell.ok -and
        [bool]$observedDerivation.ok -and
        [int]$observedCell.replicates.Count -eq 3
    )
    if (-not $cellPassed) {
        throw "BW5V characterization cell $cellIndex failed publication binding"
    }
    foreach ($replicate in $observedCell.replicates) {
        $bracketPassed = (
            [double]$replicate.breakaway_analysis.breakaway_force_lower_n -eq
                [double]$expectedCell.lower_force_n -and
            [double]$replicate.breakaway_analysis.breakaway_force_upper_n -eq
                [double]$expectedCell.upper_force_n
        )
        if (-not $bracketPassed) {
            throw (
                "BW5V characterization replicate bracket failed publication " +
                "binding for cell $cellIndex"
            )
        }
    }
}

$bw5cCharacterizationPath = [System.IO.Path]::GetFullPath(
    $Bw5cCharacterization
)
$expectedBw5cCharacterizationHash =
    "067b033266166b15eb0e9f98a5962fdfe7bc199a0af335a64bbb44cc18a09143"
if (-not (
    Test-Path -LiteralPath $bw5cCharacterizationPath -PathType Leaf
)) {
    throw (
        "Pinned BW5C characterization report not found: " +
        $bw5cCharacterizationPath
    )
}
$observedBw5cCharacterizationHash = (
    Get-FileHash -Algorithm SHA256 -LiteralPath $bw5cCharacterizationPath
).Hash.ToLowerInvariant()
if (
    $observedBw5cCharacterizationHash -cne
        $expectedBw5cCharacterizationHash
) {
    throw (
        "Pinned BW5C characterization report hash mismatch. Expected " +
        "$expectedBw5cCharacterizationHash, observed " +
        "$observedBw5cCharacterizationHash"
    )
}
$bw5cCharacterizationReport = (
    Get-Content -Raw -LiteralPath $bw5cCharacterizationPath |
        ConvertFrom-Json -AsHashtable
)
$bw5cReceipt = $bw5cCharacterizationReport.receipt
$bw5cEvidenceChecks = [ordered]@{
    report_schema = (
        [string]$bw5cCharacterizationReport.schema_version -ceq
            "sporespore_balanced_wave_bw5c_material_characterization_report_v1"
    )
    source_commit = (
        [string]$bw5cCharacterizationReport.source_commit -ceq
            "dca2618bd1cb42768235bc69711eb3dab6b2379a"
    )
    source_worktree_clean = (
        [bool]$bw5cCharacterizationReport.source_worktree_clean
    )
    source_matches_origin_main = (
        [bool]$bw5cCharacterizationReport.source_matches_origin_main
    )
    report_accepted = [bool]$bw5cCharacterizationReport.accepted
    result_status = (
        [string]$bw5cCharacterizationReport.result_status -ceq "passed"
    )
    campaign = [string]$bw5cCharacterizationReport.campaign -ceq "BW5C"
    report_not_development = (
        -not [bool]$bw5cCharacterizationReport.development_data_only
    )
    report_cold = [bool]$bw5cCharacterizationReport.cold_characterization
    recovered_complete_engine_log = (
        [bool]$bw5cCharacterizationReport.recovery.recovered_from_completed_engine_log
    )
    no_physics_rerun = (
        -not [bool]$bw5cCharacterizationReport.recovery.physics_rerun
    )
    complete_receipt_count = (
        [int]$bw5cCharacterizationReport.recovery.complete_receipt_count -eq 1
    )
    receipt_source = (
        [string]$bw5cCharacterizationReport.recovery.receipt_source -ceq
            "engine.log"
    )
    receipt_schema = (
        [string]$bw5cReceipt.schema_version -ceq
            "sporespore_balanced_wave_bw5c_material_characterization_receipt_v1"
    )
    receipt_ok = [bool]$bw5cReceipt.ok
    passed_gate_count = [int]$bw5cReceipt.passed_gate_count -eq 23
    failed_gate_count = [int]$bw5cReceipt.failed_gate_count -eq 0
    expected_gate_count = [int]$bw5cReceipt.expected_gate_count -eq 23
    observed_world_count = [int]$bw5cReceipt.observed_world_count -eq 13
    receipt_cold = [bool]$bw5cReceipt.cold_characterization
    receipt_not_development = (
        -not [bool]$bw5cReceipt.development_data_only
    )
    no_material_claim = -not [bool]$bw5cReceipt.material_robustness
    positive_cell_count = [int]$bw5cReceipt.positive_cells.Count -eq 4
}
$failedBw5cEvidenceChecks = @(
    $bw5cEvidenceChecks.GetEnumerator() |
        Where-Object { -not [bool]$_.Value } |
        ForEach-Object { [string]$_.Key }
)
if ($failedBw5cEvidenceChecks.Count -ne 0) {
    throw (
        "Pinned BW5C characterization report failed its publication contract: " +
        ($failedBw5cEvidenceChecks -join ", ")
    )
}
$expectedBw5cCells = @(
    [ordered]@{
        authored_friction = 0.12
        controller_mu = 0.1
        minimum_lower_ratio = 0.10195638022257647
        lower_force_n = 4.0
        upper_force_n = 6.0
    },
    [ordered]@{
        authored_friction = 0.48
        controller_mu = 0.45
        minimum_lower_ratio = 0.4589432881202321
        lower_force_n = 18.0
        upper_force_n = 20.0
    },
    [ordered]@{
        authored_friction = 0.95
        controller_mu = 0.94
        minimum_lower_ratio = 0.9435280065673369
        lower_force_n = 37.0
        upper_force_n = 38.0
    },
    [ordered]@{
        authored_friction = 1.5
        controller_mu = 1.0
        minimum_lower_ratio = 1.4788371649976932
        lower_force_n = 58.0
        upper_force_n = 60.0
    }
)
for (
    $cellIndex = 0;
    $cellIndex -lt $expectedBw5cCells.Count;
    $cellIndex++
) {
    $expectedCell = $expectedBw5cCells[$cellIndex]
    $observedCell = $bw5cReceipt.positive_cells[$cellIndex]
    $observedDerivation = $observedCell.coefficient_derivation
    $cellPassed = (
        [Math]::Abs(
            [double]$observedCell.authored_friction -
            [double]$expectedCell.authored_friction
        ) -le 1.0e-12 -and
        [Math]::Abs(
            [double]$observedDerivation.controller_mu -
            [double]$expectedCell.controller_mu
        ) -le 1.0e-12 -and
        [Math]::Abs(
            [double]$observedDerivation.minimum_lower_ratio -
            [double]$expectedCell.minimum_lower_ratio
        ) -le 1.0e-12 -and
        [bool]$observedCell.ok -and
        [bool]$observedDerivation.ok -and
        [int]$observedCell.replicates.Count -eq 3
    )
    if (-not $cellPassed) {
        throw "BW5C characterization cell $cellIndex failed publication binding"
    }
    foreach ($replicate in $observedCell.replicates) {
        $bracketPassed = (
            [double]$replicate.breakaway_analysis.breakaway_force_lower_n -eq
                [double]$expectedCell.lower_force_n -and
            [double]$replicate.breakaway_analysis.breakaway_force_upper_n -eq
                [double]$expectedCell.upper_force_n
        )
        if (-not $bracketPassed) {
            throw (
                "BW5C characterization replicate bracket failed publication " +
                "binding for cell $cellIndex"
            )
        }
    }
}

$bw20fClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_characterization_closure.json"
$expectedBw20fClosureHash =
    "68d1ba699d1dcfd9b190423fd542b18843823374cdd8f69029c4e05548e3bf2a"
if (-not (Test-Path -LiteralPath $bw20fClosurePath -PathType Leaf)) {
    throw "Pinned BW20F characterization closure not found: $bw20fClosurePath"
}
$observedBw20fClosureHash = (
    Get-FileHash -Algorithm SHA256 -LiteralPath $bw20fClosurePath
).Hash.ToLowerInvariant()
if ($observedBw20fClosureHash -cne $expectedBw20fClosureHash) {
    throw (
        "Pinned BW20F characterization closure hash mismatch. Expected " +
        "$expectedBw20fClosureHash, observed $observedBw20fClosureHash"
    )
}
$bw20fClosure = Get-Content -Raw -LiteralPath $bw20fClosurePath |
    ConvertFrom-Json -AsHashtable
if (-not (
    [string]$bw20fClosure.status -ceq
        "closed_complete_valid_positive_exact_finite_adapter_material_characterization" -and
    [string]$bw20fClosure.physical_source_commit -ceq
        "476aa4ea521a519a6cd91ef12f265cdb26245839" -and
    [bool]$bw20fClosure.scientific_disposition.adapter_profile_publication_authorized -and
    -not [bool]$bw20fClosure.same_identity_rerun_allowed -and
    -not [bool]$bw20fClosure.claims.friction_or_material_locomotion_robustness -and
    -not [bool]$bw20fClosure.claims.continuous_friction_coverage -and
    -not [bool]$bw20fClosure.claims.physical_acceptance_authority
)) {
    throw "Pinned BW20F closure does not authorize bounded profile publication"
}

$bw20fCharacterizationPath = [System.IO.Path]::GetFullPath(
    $Bw20fCharacterization
)
$expectedBw20fCharacterizationHash =
    "f0a279fb9660554a0d4997c6b8adb5c767bc3f92f2497694448429f142155030"
if (-not (
    Test-Path -LiteralPath $bw20fCharacterizationPath -PathType Leaf
)) {
    throw (
        "Pinned BW20F characterization report not found: " +
        $bw20fCharacterizationPath
    )
}
$observedBw20fCharacterizationHash = (
    Get-FileHash -Algorithm SHA256 -LiteralPath $bw20fCharacterizationPath
).Hash.ToLowerInvariant()
if (
    $observedBw20fCharacterizationHash -cne
        $expectedBw20fCharacterizationHash
) {
    throw (
        "Pinned BW20F characterization report hash mismatch. Expected " +
        "$expectedBw20fCharacterizationHash, observed " +
        "$observedBw20fCharacterizationHash"
    )
}
$bw20fCharacterizationReport = (
    Get-Content -Raw -LiteralPath $bw20fCharacterizationPath |
        ConvertFrom-Json -AsHashtable
)
$bw20fReceipt = $bw20fCharacterizationReport.receipt
$bw20fEvidenceChecks = [ordered]@{
    report_schema = (
        [string]$bw20fCharacterizationReport.schema_version -ceq
            "sporespore_balanced_wave_bw20f_material_characterization_report_v1"
    )
    source_commit = (
        [string]$bw20fCharacterizationReport.source_commit -ceq
            "476aa4ea521a519a6cd91ef12f265cdb26245839"
    )
    source_worktree_clean = (
        [bool]$bw20fCharacterizationReport.source_worktree_clean
    )
    source_matches_origin_main = (
        [bool]$bw20fCharacterizationReport.source_matches_origin_main
    )
    report_accepted = [bool]$bw20fCharacterizationReport.accepted
    result_status = (
        [string]$bw20fCharacterizationReport.result_status -ceq "passed"
    )
    campaign = [string]$bw20fCharacterizationReport.campaign -ceq "BW20F"
    report_not_development = (
        -not [bool]$bw20fCharacterizationReport.development_data_only
    )
    report_cold = [bool]$bw20fCharacterizationReport.cold_characterization
    receipt_schema = (
        [string]$bw20fReceipt.schema_version -ceq
            "sporespore_balanced_wave_bw20f_material_characterization_receipt_v1"
    )
    receipt_ok = [bool]$bw20fReceipt.ok
    passed_gate_count = [int]$bw20fReceipt.passed_gate_count -eq 23
    failed_gate_count = [int]$bw20fReceipt.failed_gate_count -eq 0
    expected_gate_count = [int]$bw20fReceipt.expected_gate_count -eq 23
    observed_world_count = [int]$bw20fReceipt.observed_world_count -eq 13
    receipt_cold = [bool]$bw20fReceipt.cold_characterization
    receipt_not_development = -not [bool]$bw20fReceipt.development_data_only
    no_material_claim = -not [bool]$bw20fReceipt.material_robustness
    no_continuous_claim = -not [bool]$bw20fReceipt.continuous_friction_coverage
    no_cross_engine_claim = -not [bool]$bw20fReceipt.cross_engine_equivalence
    no_physical_authority = -not [bool]$bw20fReceipt.physical_acceptance_authority
    positive_cell_count = [int]$bw20fReceipt.positive_cells.Count -eq 4
}
$failedBw20fEvidenceChecks = @(
    $bw20fEvidenceChecks.GetEnumerator() |
        Where-Object { -not [bool]$_.Value } |
        ForEach-Object { [string]$_.Key }
)
if ($failedBw20fEvidenceChecks.Count -ne 0) {
    throw (
        "Pinned BW20F characterization report failed its publication " +
        "contract: " + ($failedBw20fEvidenceChecks -join ", ")
    )
}
$expectedBw20fCells = @(
    [ordered]@{
        authored_friction = 0.09
        controller_mu = 0.07
        minimum_lower_ratio = 0.07647180229187284
        lower_force_n = 3.0
        upper_force_n = 4.0
    },
    [ordered]@{
        authored_friction = 0.37
        controller_mu = 0.35
        minimum_lower_ratio = 0.35691676077326845
        lower_force_n = 14.0
        upper_force_n = 15.0
    },
    [ordered]@{
        authored_friction = 0.76
        controller_mu = 0.73
        minimum_lower_ratio = 0.7395363279264746
        lower_force_n = 29.0
        upper_force_n = 31.0
    },
    [ordered]@{
        authored_friction = 1.18
        controller_mu = 1.0
        minimum_lower_ratio = 1.1730118440718895
        lower_force_n = 46.0
        upper_force_n = 47.0
    }
)
for (
    $cellIndex = 0;
    $cellIndex -lt $expectedBw20fCells.Count;
    $cellIndex++
) {
    $expectedCell = $expectedBw20fCells[$cellIndex]
    $observedCell = $bw20fReceipt.positive_cells[$cellIndex]
    $observedDerivation = $observedCell.coefficient_derivation
    $cellPassed = (
        [Math]::Abs(
            [double]$observedCell.authored_friction -
            [double]$expectedCell.authored_friction
        ) -le 1.0e-12 -and
        [Math]::Abs(
            [double]$observedDerivation.controller_mu -
            [double]$expectedCell.controller_mu
        ) -le 1.0e-12 -and
        [Math]::Abs(
            [double]$observedDerivation.minimum_lower_ratio -
            [double]$expectedCell.minimum_lower_ratio
        ) -le 1.0e-12 -and
        [bool]$observedCell.ok -and
        [bool]$observedDerivation.ok -and
        -not [bool]$observedDerivation.cross_engine_equivalent -and
        -not [bool]$observedDerivation.locomotion_robustness -and
        [int]$observedCell.replicates.Count -eq 3
    )
    if (-not $cellPassed) {
        throw "BW20F characterization cell $cellIndex failed publication binding"
    }
    foreach ($replicate in $observedCell.replicates) {
        $bracketPassed = (
            [double]$replicate.breakaway_analysis.breakaway_force_lower_n -eq
                [double]$expectedCell.lower_force_n -and
            [double]$replicate.breakaway_analysis.breakaway_force_upper_n -eq
                [double]$expectedCell.upper_force_n
        )
        if (-not $bracketPassed) {
            throw (
                "BW20F characterization replicate bracket failed " +
                "publication binding for cell $cellIndex"
            )
        }
    }
}

$bw22mClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw22m_material_characterization_closure.json"
$expectedBw22mClosureHash =
    "86e309bf68098338b570884429d608ac659916690c21b00f2c6077c4a35b09e6"
if (-not (Test-Path -LiteralPath $bw22mClosurePath -PathType Leaf)) {
    throw "Pinned BW22M characterization closure not found: $bw22mClosurePath"
}
$observedBw22mClosureHash = (
    Get-FileHash -Algorithm SHA256 -LiteralPath $bw22mClosurePath
).Hash.ToLowerInvariant()
if ($observedBw22mClosureHash -cne $expectedBw22mClosureHash) {
    throw (
        "Pinned BW22M characterization closure hash mismatch. Expected " +
        "$expectedBw22mClosureHash, observed $observedBw22mClosureHash"
    )
}
$bw22mClosure = Get-Content -Raw -LiteralPath $bw22mClosurePath |
    ConvertFrom-Json -AsHashtable
if (-not (
    [string]$bw22mClosure.status -ceq
        "closed_complete_valid_positive_exact_finite_adapter_material_characterization" -and
    [string]$bw22mClosure.physical_source_commit -ceq
        "ff9a2cca466984e863ffb4c9063267231186618f" -and
    [bool]$bw22mClosure.scientific_disposition.adapter_profile_publication_authorized -and
    -not [bool]$bw22mClosure.same_identity_rerun_allowed -and
    -not [bool]$bw22mClosure.claims.friction_or_material_locomotion_robustness -and
    -not [bool]$bw22mClosure.claims.continuous_friction_coverage -and
    -not [bool]$bw22mClosure.claims.physical_acceptance_authority
)) {
    throw "Pinned BW22M closure does not authorize bounded profile publication"
}

$bw22mCharacterizationPath = [System.IO.Path]::GetFullPath(
    $Bw22mCharacterization
)
$expectedBw22mCharacterizationHash =
    "cfce09d78192aaf280f44e4ec310e0c5760c687892b5f8b3d346cbaa13a1c03c"
if (-not (
    Test-Path -LiteralPath $bw22mCharacterizationPath -PathType Leaf
)) {
    throw (
        "Pinned BW22M characterization report not found: " +
        $bw22mCharacterizationPath
    )
}
$observedBw22mCharacterizationHash = (
    Get-FileHash -Algorithm SHA256 -LiteralPath $bw22mCharacterizationPath
).Hash.ToLowerInvariant()
if (
    $observedBw22mCharacterizationHash -cne
        $expectedBw22mCharacterizationHash
) {
    throw (
        "Pinned BW22M characterization report hash mismatch. Expected " +
        "$expectedBw22mCharacterizationHash, observed " +
        "$observedBw22mCharacterizationHash"
    )
}
$bw22mCharacterizationReport = (
    Get-Content -Raw -LiteralPath $bw22mCharacterizationPath |
        ConvertFrom-Json -AsHashtable
)
$bw22mReceipt = $bw22mCharacterizationReport.receipt
$bw22mEvidenceChecks = [ordered]@{
    report_schema = (
        [string]$bw22mCharacterizationReport.schema_version -ceq
            "sporespore_balanced_wave_bw22m_material_characterization_report_v1"
    )
    source_commit = (
        [string]$bw22mCharacterizationReport.source_commit -ceq
            "ff9a2cca466984e863ffb4c9063267231186618f"
    )
    source_worktree_clean = [bool]$bw22mCharacterizationReport.source_worktree_clean
    source_matches_origin_main = [bool]$bw22mCharacterizationReport.source_matches_origin_main
    source_matches_live_github_main = [bool]$bw22mCharacterizationReport.source_matches_live_github_main
    report_accepted = [bool]$bw22mCharacterizationReport.accepted
    result_status = [string]$bw22mCharacterizationReport.result_status -ceq "passed"
    receipt_schema = (
        [string]$bw22mReceipt.schema_version -ceq
            "sporespore_balanced_wave_bw22m_material_characterization_receipt_v1"
    )
    receipt_ok = [bool]$bw22mReceipt.ok
    passed_gate_count = [int]$bw22mReceipt.passed_gate_count -eq 19
    failed_gate_count = [int]$bw22mReceipt.failed_gate_count -eq 0
    expected_gate_count = [int]$bw22mReceipt.expected_gate_count -eq 19
    observed_world_count = [int]$bw22mReceipt.observed_world_count -eq 10
    no_locomotion_worlds = [int]$bw22mCharacterizationReport.locomotion_world_count -eq 0
    no_material_claim = -not [bool]$bw22mReceipt.material_robustness
    no_continuous_claim = -not [bool]$bw22mReceipt.continuous_friction_coverage
    no_cross_engine_claim = -not [bool]$bw22mReceipt.cross_engine_equivalence
    no_physical_authority = -not [bool]$bw22mReceipt.physical_acceptance_authority
    positive_cell_count = [int]$bw22mReceipt.positive_cells.Count -eq 3
}
$failedBw22mEvidenceChecks = @(
    $bw22mEvidenceChecks.GetEnumerator() |
        Where-Object { -not [bool]$_.Value } |
        ForEach-Object { [string]$_.Key }
)
if ($failedBw22mEvidenceChecks.Count -ne 0) {
    throw (
        "Pinned BW22M characterization report failed its publication " +
        "contract: " + ($failedBw22mEvidenceChecks -join ", ")
    )
}
$expectedBw22mCells = @(
    [ordered]@{
        authored_friction = 0.57
        controller_mu = 0.56
        minimum_lower_ratio = 0.5609241215877279
        lower_force_n = 22.0
        upper_force_n = 23.0
    },
    [ordered]@{
        authored_friction = 0.69
        controller_mu = 0.68
        minimum_lower_ratio = 0.6884900746592023
        lower_force_n = 27.0
        upper_force_n = 28.0
    },
    [ordered]@{
        authored_friction = 0.81
        controller_mu = 0.79
        minimum_lower_ratio = 0.7905503689593908
        lower_force_n = 31.0
        upper_force_n = 33.0
    }
)
for (
    $cellIndex = 0;
    $cellIndex -lt $expectedBw22mCells.Count;
    $cellIndex++
) {
    $expectedCell = $expectedBw22mCells[$cellIndex]
    $observedCell = $bw22mReceipt.positive_cells[$cellIndex]
    $observedDerivation = $observedCell.coefficient_derivation
    $closureCell = $bw22mClosure.result.cells[$cellIndex]
    $cellPassed = (
        [Math]::Abs(
            [double]$observedCell.authored_friction -
            [double]$expectedCell.authored_friction
        ) -le 1.0e-12 -and
        [Math]::Abs(
            [double]$observedDerivation.controller_mu -
            [double]$expectedCell.controller_mu
        ) -le 1.0e-12 -and
        [Math]::Abs(
            [double]$observedDerivation.minimum_lower_ratio -
            [double]$expectedCell.minimum_lower_ratio
        ) -le 1.0e-12 -and
        [bool]$observedCell.ok -and
        [bool]$observedDerivation.ok -and
        -not [bool]$observedDerivation.cross_engine_equivalent -and
        -not [bool]$observedDerivation.locomotion_robustness -and
        [int]$observedCell.replicates.Count -eq 3 -and
        [double]$closureCell.authored_friction -eq
            [double]$expectedCell.authored_friction -and
        [double]$closureCell.controller_mu -eq
            [double]$expectedCell.controller_mu -and
        [bool]$closureCell.passed
    )
    if (-not $cellPassed) {
        throw "BW22M characterization cell $cellIndex failed publication binding"
    }
    foreach ($replicate in $observedCell.replicates) {
        if (-not (
            [double]$replicate.breakaway_analysis.breakaway_force_lower_n -eq
                [double]$expectedCell.lower_force_n -and
            [double]$replicate.breakaway_analysis.breakaway_force_upper_n -eq
                [double]$expectedCell.upper_force_n
        )) {
            throw (
                "BW22M characterization replicate bracket failed " +
                "publication binding for cell $cellIndex"
            )
        }
    }
}

Push-Location -LiteralPath $sdkRoot
try {
    & cargo build -p sporespore-godot-adapter --offline
    if ($LASTEXITCODE -ne 0) {
        throw "Godot adapter build failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
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

$projectText = @'
; Isolated P5M.2 Godot/Jolt immutable material-profile conformance.

config_version=5

[application]

config/name="sporespore-sdk-godot-jolt-material-profiles"
config/features=PackedStringArray("4.7", "Forward Plus")

[debug]

gdscript/warnings/shadowed_global_identifier=0

[physics]

3d/physics_engine="Jolt Physics"
jolt_physics_3d/simulation/velocity_steps=20
jolt_physics_3d/simulation/position_steps=7
'@
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
    & $godotPath `
        --headless `
        --path $projectRoot `
        --log-file $engineLogPath `
        --script "res://tests/test_sdk_godot_jolt_material_profiles.gd" `
        2>&1 | Tee-Object -FilePath $transcriptPath
    $godotExitCode = $LASTEXITCODE
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}

$receiptLines = @(
    Get-Content -LiteralPath $transcriptPath |
        Where-Object { $_.StartsWith("SDK_MATERIAL_PROFILE_RECEIPT ") }
)
if ($receiptLines.Count -ne 1) {
    throw (
        "Expected exactly one SDK_MATERIAL_PROFILE_RECEIPT line, found " +
        "$($receiptLines.Count). Transcript: $transcriptPath"
    )
}
$receiptJson = $receiptLines[0].Substring(
    "SDK_MATERIAL_PROFILE_RECEIPT ".Length
)
$receipt = $receiptJson | ConvertFrom-Json -AsHashtable
$receiptPassed = (
    $godotExitCode -eq 0 -and
    [string]$receipt.schema_version -ceq
        "sporespore_godot_jolt_material_profile_receipt_v1" -and
    [bool]$receipt.ok -and
    [int]$receipt.passed_gate_count -eq 46 -and
    [int]$receipt.failed_gate_count -eq 0 -and
    [int]$receipt.expected_gate_count -eq 46 -and
    [int]$receipt.expected_profile_count -eq 35 -and
    [int]$receipt.observed_profile_count -eq 35 -and
    [int]$receipt.expected_adapter_start_count -eq 36 -and
    [int]$receipt.observed_adapter_start_count -eq 36 -and
    [int]$receipt.expected_world_count -eq 0 -and
    [int]$receipt.observed_world_count -eq 0 -and
    [int]$receipt.observed_sample_count -eq 0 -and
    [int]$receipt.observed_command_count -eq 0 -and
    [int]$receipt.profile_ids.Count -eq 35 -and
    [int]$receipt.profile_sha256.Count -eq 35 -and
    (@($receipt.profile_ids | Select-Object -Last 3) -join "|") -ceq
        ($expectedBw24mProfileIds -join "|") -and
    (@($receipt.profile_sha256 | Select-Object -Last 3) -join "|") -ceq
        ($expectedBw24mProfileSha256 -join "|") -and
    [int]$receipt.bw4_profile_count -eq 4 -and
    [int]$receipt.bw5v_profile_count -eq 3 -and
    [int]$receipt.bw5c_profile_count -eq 4 -and
    [int]$receipt.bw20f_profile_count -eq 4 -and
    [int]$receipt.bw22m_profile_count -eq 3 -and
    [int]$receipt.bw24m_profile_count -eq 3 -and
    [bool]$receipt.bw5v_validation_profile_publication -and
    [bool]$receipt.bw5c_cold_profile_publication -and
    [bool]$receipt.bw20f_cold_successor_profile_publication -and
    [bool]$receipt.bw22m_fresh_material_profile_publication -and
    [bool]$receipt.bw24m_fresh_material_profile_publication -and
    -not [bool]$receipt.material_robustness -and
    [string]$receipt.physics_engine -ceq "Jolt Physics" -and
    [int]$receipt.physics_hz -eq 120 -and
    [int]$receipt.solver_velocity_steps -eq 20 -and
    [int]$receipt.solver_position_steps -eq 7 -and
    -not [bool]$receipt.adapter_actuation_applied -and
    -not [bool]$receipt.physics_transform_or_velocity_written -and
    -not [bool]$receipt.walking -and
    -not [bool]$receipt.locomotion_robustness -and
    -not [bool]$receipt.continuous_friction_coverage -and
    -not [bool]$receipt.cross_engine_equivalence -and
    -not [bool]$receipt.rough_terrain_robustness -and
    -not [bool]$receipt.external_push_recovery -and
    -not [bool]$receipt.sensor_fault_robustness -and
    -not [bool]$receipt.fresh_morphology_validation -and
    -not [bool]$receipt.physical_acceptance_authority -and
    -not [bool]$receipt.completed_engine_neutral_sdk -and
    -not [bool]$receipt.formal_milestone_acceptance_authorized -and
    -not [bool]$receipt.encyclopedia_admission_authorized
)

if ([string]::IsNullOrWhiteSpace($Output)) {
    if (
        $Bw20fPublicationAuthorized -or
        -not [string]::IsNullOrWhiteSpace($Bw20fPublicationAttempt) -or
        $Bw22mPublicationAuthorized -or
        -not [string]::IsNullOrWhiteSpace($Bw22mPublicationAttempt) -or
        $Bw24mPublicationAuthorized -or
        -not [string]::IsNullOrWhiteSpace($Bw24mPublicationAttempt)
    ) {
        throw "Profile-publication authorization is valid only with -Output"
    }
} else {
    if (
        $Bw24mPublicationAuthorized -or
        -not [string]::IsNullOrWhiteSpace($Bw24mPublicationAttempt)
    ) {
        throw (
            "BW24M retained publication requires the distinct " +
            "run_godot_jolt_bw24m_material_profile_conformance.ps1 route"
        )
    }
    if (
        $Bw22mPublicationAuthorized -or
        -not [string]::IsNullOrWhiteSpace($Bw22mPublicationAttempt)
    ) {
        throw (
            "BW22M retained publication requires the distinct " +
            "run_godot_jolt_bw22m_material_profile_conformance.ps1 route"
        )
    }
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    $outputDirectory = Split-Path -Parent $outputPath
    $expectedAttemptPath = Join-Path $outputDirectory "attempt.json"
    $bw20fPublicationRequested = (
        [bool]$Bw20fPublicationAuthorized -or
        -not [string]::IsNullOrWhiteSpace($Bw20fPublicationAttempt)
    )
    $bw22mPublicationRequested = (
        [bool]$Bw22mPublicationAuthorized -or
        -not [string]::IsNullOrWhiteSpace($Bw22mPublicationAttempt)
    )
    if ($bw20fPublicationRequested -eq $bw22mPublicationRequested) {
        throw "Retained publication requires exactly one campaign authority"
    }
    $resolvedAttemptPath = if (
        $bw22mPublicationRequested -and
        -not [string]::IsNullOrWhiteSpace($Bw22mPublicationAttempt)
    ) {
        [System.IO.Path]::GetFullPath($Bw22mPublicationAttempt)
    } elseif (
        $bw20fPublicationRequested -and
        -not [string]::IsNullOrWhiteSpace($Bw20fPublicationAttempt)
    ) {
        [System.IO.Path]::GetFullPath($Bw20fPublicationAttempt)
    } else {
        ""
    }
    $authorizationPresent = if ($bw22mPublicationRequested) {
        [bool]$Bw22mPublicationAuthorized
    } else {
        [bool]$Bw20fPublicationAuthorized
    }
    if (-not (
        $authorizationPresent -and
        $resolvedAttemptPath -ceq $expectedAttemptPath -and
        (Test-Path -LiteralPath $resolvedAttemptPath -PathType Leaf)
    )) {
        $publicationName = if ($bw22mPublicationRequested) {
            "BW22M"
        } else {
            "BW20F"
        }
        throw (
            "Retained $publicationName material-profile publication " +
            "requires the supervisor's exact sibling attempt receipt"
        )
    }
    $publicationAttempt = Get-Content -Raw -LiteralPath $resolvedAttemptPath |
        ConvertFrom-Json -AsHashtable
    if ($bw22mPublicationRequested) {
        if (-not (
            [string]$publicationAttempt.schema_version -ceq
                "sporespore_balanced_wave_bw22m_material_profile_publication_attempt_v1" -and
            [string]$publicationAttempt.campaign_id -ceq
                "BW22M-BW21L-FRESH-MATERIAL-PROFILE-PUBLICATION" -and
            [string]$publicationAttempt.gate_id -ceq "BW22M-PROFILE" -and
            [bool]$publicationAttempt.source_worktree_clean -and
            [bool]$publicationAttempt.source_matches_live_github_main -and
            [bool]$publicationAttempt.complete_zero_world_gate_passed -and
            [int]$publicationAttempt.expected_profile_count -eq 32 -and
            [int]$publicationAttempt.expected_gate_count -eq 43 -and
            [int]$publicationAttempt.expected_world_count -eq 0 -and
            [int]$publicationAttempt.expected_sample_count -eq 0 -and
            [int]$publicationAttempt.expected_command_count -eq 0 -and
            [int]$publicationAttempt.locomotion_seed_world_count -eq 0 -and
            [bool]$publicationAttempt.publication_identity_consumed -and
            -not [bool]$publicationAttempt.same_identity_rerun_allowed -and
            -not [bool]$publicationAttempt.physical_acceptance_authority
        )) {
            throw "BW22M material-profile publication attempt receipt is invalid"
        }
        $publicationCampaign = "BW22M"
    } else {
        if (-not (
            [string]$publicationAttempt.schema_version -ceq
                "sporespore_balanced_wave_bw20f_material_profile_publication_attempt_v1" -and
            [string]$publicationAttempt.campaign_id -ceq
                "BW20F-BW19V-COLD-MATERIAL-PROFILE-PUBLICATION" -and
            [string]$publicationAttempt.gate_id -ceq "BW20F-PROFILE" -and
            [bool]$publicationAttempt.source_worktree_clean -and
            [bool]$publicationAttempt.source_matches_live_github_main -and
            [bool]$publicationAttempt.complete_zero_world_gate_passed -and
            [int]$publicationAttempt.expected_profile_count -eq 29 -and
            [int]$publicationAttempt.expected_gate_count -eq 40 -and
            [int]$publicationAttempt.expected_world_count -eq 0 -and
            -not [bool]$publicationAttempt.same_identity_rerun_allowed -and
            -not [bool]$publicationAttempt.physical_acceptance_authority
        )) {
            throw "BW20F material-profile publication attempt receipt is invalid"
        }
        $publicationCampaign = "BW20F"
    }
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
    if ([string]$publicationAttempt.source_commit -cne $sourceCommit) {
        throw "$publicationCampaign publication attempt/source commit mismatch"
    }
    if ([System.IO.Path]::GetFileName($outputPath) -cne "report.json") {
        throw "The retained P5M.2 report filename must be exactly report.json"
    }
    if (Test-Path -LiteralPath $outputPath) {
        throw "Refusing to overwrite an existing P5M.2 report: $outputPath"
    }
    [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
    $retainedTranscriptPath = Join-Path $outputDirectory "transcript.log"
    $retainedEngineLogPath = Join-Path $outputDirectory "engine.log"
    [System.IO.File]::Copy($transcriptPath, $retainedTranscriptPath, $false)
    [System.IO.File]::Copy($engineLogPath, $retainedEngineLogPath, $false)
    $sourcePaths = [ordered]@{
        bootstrap = (
            "docs/SDK_GODOT_JOLT_FRICTION_MATERIAL_ROBUSTNESS_BOOTSTRAP.md"
        )
        bw3_bootstrap = (
            "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md"
        )
        bw3_preregistration = "sdk/balanced_wave_bw3_preregistration.json"
        bw3r_preregistration = "sdk/balanced_wave_bw3r_preregistration.json"
        bw4_preregistration = "sdk/balanced_wave_bw4_preregistration.json"
        bw5v_preregistration = "sdk/balanced_wave_bw5v_preregistration.json"
        bw5c_preregistration = "sdk/balanced_wave_bw5c_preregistration.json"
        bw20f_profile_preregistration = (
            "sdk/balanced_wave_bw20f_material_profile_publication_" +
            "preregistration.json"
        )
        bw20f_characterization_closure = (
            "sdk/balanced_wave_bw20f_material_characterization_closure.json"
        )
        bw20f_characterization_closure_audit = (
            "tests/test_bw20f_material_characterization_closure.ps1"
        )
        bw22m_profile_preregistration = (
            "sdk/balanced_wave_bw22m_material_profile_publication_" +
            "preregistration.json"
        )
        bw22m_characterization_closure = (
            "sdk/balanced_wave_bw22m_material_characterization_closure.json"
        )
        bw22m_characterization_closure_audit = (
            "tests/test_bw22m_material_characterization_closure.ps1"
        )
        bw5c_recovery_finalizer = (
            "sdk/finalize_balanced_wave_bw5c_completed_run.ps1"
        )
        profiles = (
            "scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
        )
        adapter = "scripts/lab/gait/sdk_godot_jolt_adapter.gd"
        walker = "scripts/lab/gait/physical_wave_gait_quadruped.gd"
        canonical_json = "scripts/lab/canonical_json.gd"
        test = "tests/test_sdk_godot_jolt_material_profiles.gd"
        runner = "sdk/run_godot_jolt_material_profile_conformance.ps1"
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
        schema_version =
            "sporespore_godot_jolt_material_profile_report_v1"
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        source_commit = $sourceCommit
        source_worktree_clean = $true
        source_matches_origin_main = $true
        accepted = $receiptPassed
        result_status = $(if ($receiptPassed) { "passed" } else { "rejected" })
        godot_exit_code = $godotExitCode
        stopping_rule =
            "zero_world_profile_conformance_after_bw22m_characterization_closure_before_stage3_locomotion"
        prerequisite_evidence = [ordered]@{
            bw4_material_characterization = [ordered]@{
                path = $bw4CharacterizationPath
                sha256 = $observedBw4CharacterizationHash
                source_commit = (
                    [string]$bw4CharacterizationReport.source_commit
                )
            }
            bw5v_material_characterization = [ordered]@{
                path = $bw5vCharacterizationPath
                sha256 = $observedBw5vCharacterizationHash
                source_commit = (
                    [string]$bw5vCharacterizationReport.source_commit
                )
            }
            bw5c_material_characterization = [ordered]@{
                path = $bw5cCharacterizationPath
                sha256 = $observedBw5cCharacterizationHash
                source_commit = (
                    [string]$bw5cCharacterizationReport.source_commit
                )
                packaging_commit = (
                    [string]$bw5cCharacterizationReport.packaging_commit
                )
                recovered_from_completed_engine_log = [bool](
                    $bw5cCharacterizationReport.recovery.recovered_from_completed_engine_log
                )
                physics_rerun = [bool](
                    $bw5cCharacterizationReport.recovery.physics_rerun
                )
            }
            bw20f_material_characterization = [ordered]@{
                path = $bw20fCharacterizationPath
                sha256 = $observedBw20fCharacterizationHash
                source_commit = (
                    [string]$bw20fCharacterizationReport.source_commit
                )
                closure_path = $bw20fClosurePath
                closure_sha256 = $observedBw20fClosureHash
                profile_publication_authorized = [bool](
                    $bw20fClosure.scientific_disposition.adapter_profile_publication_authorized
                )
            }
            bw22m_material_characterization = [ordered]@{
                path = $bw22mCharacterizationPath
                sha256 = $observedBw22mCharacterizationHash
                source_commit = (
                    [string]$bw22mCharacterizationReport.source_commit
                )
                closure_path = $bw22mClosurePath
                closure_sha256 = $observedBw22mClosureHash
                profile_publication_authorized = [bool](
                    $bw22mClosure.scientific_disposition.adapter_profile_publication_authorized
                )
                post_closure_full_conformance_passed = [bool](
                    $bw22mProfilePreregistration.prerequisite_evidence.material_characterization_closure.post_closure_full_conformance_passed
                )
            }
        }
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
    }
    $temporaryPath = "$outputPath.tmp"
    $json = $report | ConvertTo-Json -Depth 32
    [System.IO.File]::WriteAllText(
        $temporaryPath,
        "$json`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    [System.IO.File]::Move($temporaryPath, $outputPath, $false)
    Write-Host "Retained P5M.2 material-profile report: $outputPath"
}

if (-not $receiptPassed) {
    throw (
        "The P5M.2 material-profile result was rejected. " +
        "Godot exit code: $godotExitCode. Transcript: $transcriptPath"
    )
}

Write-Host "Godot/Jolt P5M.2 material-profile conformance passed."
Write-Host "Transcript: $transcriptPath"

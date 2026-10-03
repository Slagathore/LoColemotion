#requires -Version 7.0

<#
.SYNOPSIS
Runs a preregistered BR14A.7 single-mass-axis controller-policy probe.

.DESCRIPTION
Creates one fresh minimal Jolt 20/6 project per committed mass-axis cell.
Only the declared normalized fixture axis varies. Geometry, contact material,
motor limits, walking gates, and solver settings remain fixed. The selected
preregistered controller configuration or mass-adaptive policy is fixed across
the grid.

Walking true/false is recorded as a development outcome. A boundary report
does not promote a milestone, admit knowledge, establish morphology-general
walking, or authorize automatic creature guidance.
#>

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [Alias("MassCellsKg")]
    [double[]]$TorsoMassCellsKg = @(),
    [ValidateSet("torso_mass", "symmetric_upper_mass")]
    [string]$FixtureVariationAxis = "torso_mass",
    [ValidateSet(
        "TM1",
        "TM2",
        "TC1G005",
        "TC1G010",
        "TC1G015",
        "TC1G020",
        "TC1G025",
        "TC2",
        "S1A",
        "S1B",
        "S1C",
        "S1D",
        "S2A",
        "S2B",
        "S2C",
        "S2D",
        "UM2A",
        "UM2B",
        "UM2C",
        "UM3A",
        "UM3B",
        "UM3C",
        "UM4A",
        "UM4B",
        "UM4C",
        "UM5A",
        "UM5B",
        "UM5C",
        "UM6A",
        "UM6B",
        "UM6C",
        "UM7A",
        "UM7B",
        "UM7C",
        "UM8A",
        "UM8B",
        "UM8C",
        "UM9A",
        "UM9B",
        "UM9C",
        "UM10A",
        "UM10B",
        "UM10C"
    )]
    [string]$ControllerEvidenceFamily = "TM1",
    [switch]$S2HeldOutValidation,
    [ValidateRange(0, 3)]
    [int]$S2HeldOutRepetition = 0,
    [switch]$UM1HeldOutValidation,
    [ValidateRange(0, 3)]
    [int]$UM1HeldOutRepetition = 0,
    [switch]$UM2HeldOutValidation,
    [ValidateRange(0, 3)]
    [int]$UM2HeldOutRepetition = 0,
    [switch]$UM3HeldOutValidation,
    [ValidateRange(0, 3)]
    [int]$UM3HeldOutRepetition = 0,
    [switch]$UM4HeldOutValidation,
    [ValidateRange(0, 3)]
    [int]$UM4HeldOutRepetition = 0,
    [switch]$UM5HeldOutValidation,
    [ValidateRange(0, 3)]
    [int]$UM5HeldOutRepetition = 0,
    [switch]$UM6HeldOutValidation,
    [ValidateRange(0, 3)]
    [int]$UM6HeldOutRepetition = 0,
    [switch]$UM7HeldOutValidation,
    [ValidateRange(0, 3)]
    [int]$UM7HeldOutRepetition = 0,
    [switch]$UM8HeldOutValidation,
    [ValidateRange(0, 3)]
    [int]$UM8HeldOutRepetition = 0,
    [switch]$UM9HeldOutValidation,
    [ValidateRange(0, 3)]
    [int]$UM9HeldOutRepetition = 0,
    [switch]$UM10HeldOutValidation,
    [ValidateRange(0, 3)]
    [int]$UM10HeldOutRepetition = 0,
    [ValidateRange(10, 300)]
    [int]$TestTimeoutSeconds = 90,
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_br14a_torso_mass_probe"
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
$isUm2Family = $ControllerEvidenceFamily.StartsWith("UM2")
$isUm3Family = $ControllerEvidenceFamily.StartsWith("UM3")
$isUm4Family = $ControllerEvidenceFamily.StartsWith("UM4")
$isUm5Family = $ControllerEvidenceFamily.StartsWith("UM5")
$isUm6Family = $ControllerEvidenceFamily.StartsWith("UM6")
$isUm7Family = $ControllerEvidenceFamily.StartsWith("UM7")
$isUm8Family = $ControllerEvidenceFamily.StartsWith("UM8")
$isUm9Family = $ControllerEvidenceFamily.StartsWith("UM9")
$isUm10Family = $ControllerEvidenceFamily.StartsWith("UM10")
$isAdaptiveUpperMassFamily = (
    $isUm2Family -or
    $isUm3Family -or
    $isUm4Family -or
    $isUm5Family -or
    $isUm6Family -or
    $isUm7Family -or
    $isUm8Family -or
    $isUm9Family -or
    $isUm10Family
)

if ($S2HeldOutValidation) {
    if (-not $ControllerEvidenceFamily.StartsWith("S2")) {
        throw "S2 held-out validation requires an S2 controller family."
    }
    if ($S2HeldOutRepetition -lt 1) {
        throw "S2 held-out validation requires repetition 1, 2, or 3."
    }
} elseif ($S2HeldOutRepetition -ne 0) {
    throw "S2HeldOutRepetition is valid only with S2HeldOutValidation."
}
if ($UM1HeldOutValidation) {
    if (
        $FixtureVariationAxis -ne "symmetric_upper_mass" -or
        $ControllerEvidenceFamily -ne "S2B"
    ) {
        throw (
            "UM1 held-out validation requires symmetric_upper_mass and S2B."
        )
    }
    if ($UM1HeldOutRepetition -lt 1) {
        throw "UM1 held-out validation requires repetition 1, 2, or 3."
    }
} elseif ($UM1HeldOutRepetition -ne 0) {
    throw "UM1HeldOutRepetition is valid only with UM1HeldOutValidation."
}
if ($UM2HeldOutValidation) {
    if (
        $FixtureVariationAxis -ne "symmetric_upper_mass" -or
        -not $isUm2Family
    ) {
        throw (
            "UM2 held-out validation requires symmetric_upper_mass and UM2."
        )
    }
    if ($UM2HeldOutRepetition -lt 1) {
        throw "UM2 held-out validation requires repetition 1, 2, or 3."
    }
} elseif ($UM2HeldOutRepetition -ne 0) {
    throw "UM2HeldOutRepetition is valid only with UM2HeldOutValidation."
}
if ($UM3HeldOutValidation) {
    if (
        $FixtureVariationAxis -ne "symmetric_upper_mass" -or
        -not $isUm3Family
    ) {
        throw (
            "UM3 held-out validation requires symmetric_upper_mass and UM3."
        )
    }
    if ($UM3HeldOutRepetition -lt 1) {
        throw "UM3 held-out validation requires repetition 1, 2, or 3."
    }
} elseif ($UM3HeldOutRepetition -ne 0) {
    throw "UM3HeldOutRepetition is valid only with UM3HeldOutValidation."
}
if ($UM4HeldOutValidation) {
    if (
        $FixtureVariationAxis -ne "symmetric_upper_mass" -or
        -not $isUm4Family
    ) {
        throw (
            "UM4 held-out validation requires symmetric_upper_mass and UM4."
        )
    }
    if ($UM4HeldOutRepetition -lt 1) {
        throw "UM4 held-out validation requires repetition 1, 2, or 3."
    }
} elseif ($UM4HeldOutRepetition -ne 0) {
    throw "UM4HeldOutRepetition is valid only with UM4HeldOutValidation."
}
if ($UM5HeldOutValidation) {
    if (
        $FixtureVariationAxis -ne "symmetric_upper_mass" -or
        -not $isUm5Family
    ) {
        throw (
            "UM5 held-out validation requires symmetric_upper_mass and UM5."
        )
    }
    if ($UM5HeldOutRepetition -lt 1) {
        throw "UM5 held-out validation requires repetition 1, 2, or 3."
    }
} elseif ($UM5HeldOutRepetition -ne 0) {
    throw "UM5HeldOutRepetition is valid only with UM5HeldOutValidation."
}
if ($UM6HeldOutValidation) {
    if (
        $FixtureVariationAxis -ne "symmetric_upper_mass" -or
        -not $isUm6Family
    ) {
        throw (
            "UM6 held-out validation requires symmetric_upper_mass and UM6."
        )
    }
    if ($UM6HeldOutRepetition -lt 1) {
        throw "UM6 held-out validation requires repetition 1, 2, or 3."
    }
} elseif ($UM6HeldOutRepetition -ne 0) {
    throw "UM6HeldOutRepetition is valid only with UM6HeldOutValidation."
}
if ($UM7HeldOutValidation) {
    if (
        $FixtureVariationAxis -ne "symmetric_upper_mass" -or
        -not $isUm7Family
    ) {
        throw (
            "UM7 held-out validation requires symmetric_upper_mass and UM7."
        )
    }
    if ($UM7HeldOutRepetition -lt 1) {
        throw "UM7 held-out validation requires repetition 1, 2, or 3."
    }
} elseif ($UM7HeldOutRepetition -ne 0) {
    throw "UM7HeldOutRepetition is valid only with UM7HeldOutValidation."
}
if ($UM8HeldOutValidation) {
    if (
        $FixtureVariationAxis -ne "symmetric_upper_mass" -or
        -not $isUm8Family
    ) {
        throw (
            "UM8 held-out validation requires symmetric_upper_mass and UM8."
        )
    }
    if ($UM8HeldOutRepetition -lt 1) {
        throw "UM8 held-out validation requires repetition 1, 2, or 3."
    }
} elseif ($UM8HeldOutRepetition -ne 0) {
    throw "UM8HeldOutRepetition is valid only with UM8HeldOutValidation."
}
if ($UM9HeldOutValidation) {
    if (
        $FixtureVariationAxis -ne "symmetric_upper_mass" -or
        -not $isUm9Family
    ) {
        throw (
            "UM9 held-out validation requires symmetric_upper_mass and UM9."
        )
    }
    if ($UM9HeldOutRepetition -lt 1) {
        throw "UM9 held-out validation requires repetition 1, 2, or 3."
    }
} elseif ($UM9HeldOutRepetition -ne 0) {
    throw "UM9HeldOutRepetition is valid only with UM9HeldOutValidation."
}
if ($UM10HeldOutValidation) {
    if (
        $FixtureVariationAxis -ne "symmetric_upper_mass" -or
        -not $isUm10Family
    ) {
        throw (
            "UM10 held-out validation requires symmetric_upper_mass and UM10."
        )
    }
    if ($UM10HeldOutRepetition -lt 1) {
        throw "UM10 held-out validation requires repetition 1, 2, or 3."
    }
} elseif ($UM10HeldOutRepetition -ne 0) {
    throw "UM10HeldOutRepetition is valid only with UM10HeldOutValidation."
}
$heldOutModeCount = @(
    $S2HeldOutValidation,
    $UM1HeldOutValidation,
    $UM2HeldOutValidation,
    $UM3HeldOutValidation,
    $UM4HeldOutValidation,
    $UM5HeldOutValidation,
    $UM6HeldOutValidation,
    $UM7HeldOutValidation,
    $UM8HeldOutValidation,
    $UM9HeldOutValidation,
    $UM10HeldOutValidation
).Where({ $_ }).Count
if ($heldOutModeCount -gt 1) {
    throw "Only one held-out validation mode may be active."
}
if (
    $FixtureVariationAxis -eq "symmetric_upper_mass" -and
    $ControllerEvidenceFamily -ne "S2B" -and
    -not $isAdaptiveUpperMassFamily
) {
    throw "The preregistered symmetric upper-mass axis uses S2B or UM2-UM10."
}
if (
    $FixtureVariationAxis -eq "torso_mass" -and
    $isAdaptiveUpperMassFamily
) {
    throw "UM2-UM10 are preregistered only for the symmetric_upper_mass axis."
}
if (
    $S2HeldOutValidation -and
    $FixtureVariationAxis -ne "torso_mass"
) {
    throw "S2 torso held-out validation requires the torso_mass axis."
}

$expectedAssertionsPerCell = if (
    $ControllerEvidenceFamily -eq "TC2" -or
    $ControllerEvidenceFamily.StartsWith("S1") -or
    $ControllerEvidenceFamily.StartsWith("S2") -or
    $isAdaptiveUpperMassFamily
) {
    16
} else {
    15
}
$expectedLockedS2BControllerDigest = (
    "sha256:" +
    "7478184503ca25fe591675afdee7366615e885763ecb0ed0e57e0bf82a3445cc"
)
$referenceMassKg = if ($FixtureVariationAxis -eq "torso_mass") {
    3.00
} else {
    0.25
}
$massGridFamilies = @("TM1", "TM2")
$expectedCellsKg = if (
    $UM1HeldOutValidation -or
    $UM2HeldOutValidation -or
    $UM3HeldOutValidation -or
    $UM4HeldOutValidation -or
    $UM5HeldOutValidation -or
    $UM6HeldOutValidation -or
    $UM7HeldOutValidation -or
    $UM8HeldOutValidation -or
    $UM9HeldOutValidation -or
    $UM10HeldOutValidation
) {
    [double[]]@(0.2125, 0.2625, 0.2875)
} elseif ($FixtureVariationAxis -eq "symmetric_upper_mass") {
    [double[]]@(0.2000, 0.2250, 0.2500, 0.2750, 0.3000)
} elseif ($S2HeldOutValidation) {
    [double[]]@(3.05, 3.15, 3.25)
} elseif (
    $massGridFamilies -contains $ControllerEvidenceFamily
) {
    [double[]]@(2.40, 2.70, 3.00, 3.30, 3.60)
} elseif ($ControllerEvidenceFamily -eq "TC2") {
    [double[]]@(3.10, 3.20, 3.40)
} else {
    [double[]]@(3.00, 3.30)
}
if ($TorsoMassCellsKg.Count -eq 0) {
    $TorsoMassCellsKg = $expectedCellsKg
}
$controllerFamilyId = switch ($ControllerEvidenceFamily) {
    "TM1" { "tm1_contact_gated" }
    "TM2" { "tm2_exact_reference" }
    "TC1G005" { "tc1_gain_005" }
    "TC1G010" { "tc1_gain_010" }
    "TC1G015" { "tc1_gain_015" }
    "TC1G020" { "tc1_gain_020" }
    "TC1G025" { "tc1_gain_025" }
    "TC2" { "tc2_linear_mass_adaptive" }
    "S1A" { "s1_path_a" }
    "S1B" { "s1_path_b" }
    "S1C" { "s1_path_c" }
    "S1D" { "s1_path_d" }
    "S2A" { "s2_gated_path_a" }
    "S2B" { "s2_gated_path_b" }
    "S2C" { "s2_gated_path_c" }
    "S2D" { "s2_gated_path_d" }
    "UM2A" { "um2_adaptive_actuator_a" }
    "UM2B" { "um2_adaptive_actuator_b" }
    "UM2C" { "um2_adaptive_actuator_c" }
    "UM3A" { "um3_joint_specific_actuator_a" }
    "UM3B" { "um3_joint_specific_actuator_b" }
    "UM3C" { "um3_joint_specific_actuator_c" }
    "UM4A" { "um4_bidirectional_knee_attenuation_a" }
    "UM4B" { "um4_bidirectional_knee_attenuation_b" }
    "UM4C" { "um4_bidirectional_knee_attenuation_c" }
    "UM5A" { "um5_bidirectional_dual_attenuation_a" }
    "UM5B" { "um5_bidirectional_dual_attenuation_b" }
    "UM5C" { "um5_bidirectional_dual_attenuation_c" }
    "UM6A" { "um6_heavy_knee_trajectory_a" }
    "UM6B" { "um6_heavy_knee_trajectory_b" }
    "UM6C" { "um6_heavy_knee_trajectory_c" }
    "UM7A" { "um7_heavy_swing_timing_a" }
    "UM7B" { "um7_heavy_swing_timing_b" }
    "UM7C" { "um7_heavy_swing_timing_c" }
    "UM8A" { "um8_contact_loaded_knee_rate_a" }
    "UM8B" { "um8_contact_loaded_knee_rate_b" }
    "UM8C" { "um8_contact_loaded_knee_rate_c" }
    "UM9A" { "um9_post_release_loaded_knee_rate_a" }
    "UM9B" { "um9_post_release_loaded_knee_rate_b" }
    "UM9C" { "um9_post_release_loaded_knee_rate_c" }
    "UM10A" { "um10_release_gate_notch_a" }
    "UM10B" { "um10_release_gate_notch_b" }
    "UM10C" { "um10_release_gate_notch_c" }
}
$upperMassCandidateExponent = switch ($ControllerEvidenceFamily) {
    "UM2A" { 0.5 }
    "UM2B" { 1.0 }
    "UM2C" { 1.5 }
    "UM3A" { 0.5 }
    "UM3B" { 1.0 }
    "UM3C" { 1.5 }
    "UM4A" { 0.5 }
    "UM4B" { 1.0 }
    "UM4C" { 1.5 }
    "UM5A" { 0.5 }
    "UM5B" { 1.0 }
    "UM5C" { 1.5 }
    "UM6A" { 1.0 }
    "UM6B" { 1.0 }
    "UM6C" { 1.0 }
    "UM7A" { 1.0 }
    "UM7B" { 1.0 }
    "UM7C" { 1.0 }
    "UM8A" { 1.0 }
    "UM8B" { 1.0 }
    "UM8C" { 1.0 }
    "UM9A" { 1.0 }
    "UM9B" { 1.0 }
    "UM9C" { 1.0 }
    "UM10A" { 1.0 }
    "UM10B" { 1.0 }
    "UM10C" { 1.0 }
    default { $null }
}
$um6EndpointKneeFlexionScale = switch ($ControllerEvidenceFamily) {
    "UM6A" { 1.60 }
    "UM6B" { 1.45 }
    "UM6C" { 1.30 }
    default { $null }
}
$um7EndpointSwingTicks = switch ($ControllerEvidenceFamily) {
    "UM7A" { 68 }
    "UM7B" { 64 }
    "UM7C" { 60 }
    default { $null }
}
$um8EndpointSpeedRadS = switch ($ControllerEvidenceFamily) {
    "UM8A" { 2.50 }
    "UM8B" { 1.50 }
    "UM8C" { 0.75 }
    default { $null }
}
$um9ActivationStartOffsetTicks = switch ($ControllerEvidenceFamily) {
    "UM9A" { 1 }
    "UM9B" { 3 }
    "UM9C" { 6 }
    default { $null }
}
$um10PreReleaseLeadTicks = switch ($ControllerEvidenceFamily) {
    "UM10A" { 4 }
    "UM10B" { 6 }
    "UM10C" { 9 }
    default { $null }
}
$campaignId = if ($UM10HeldOutValidation) {
    "G1-$ControllerEvidenceFamily-HELDOUT-R$UM10HeldOutRepetition"
} elseif ($isUm10Family) {
    "G1-$ControllerEvidenceFamily-SELECTION"
} elseif ($UM9HeldOutValidation) {
    "G1-$ControllerEvidenceFamily-HELDOUT-R$UM9HeldOutRepetition"
} elseif ($isUm9Family) {
    "G1-$ControllerEvidenceFamily-SELECTION"
} elseif ($UM8HeldOutValidation) {
    "G1-$ControllerEvidenceFamily-HELDOUT-R$UM8HeldOutRepetition"
} elseif ($isUm8Family) {
    "G1-$ControllerEvidenceFamily-SELECTION"
} elseif ($UM7HeldOutValidation) {
    "G1-$ControllerEvidenceFamily-HELDOUT-R$UM7HeldOutRepetition"
} elseif ($isUm7Family) {
    "G1-$ControllerEvidenceFamily-SELECTION"
} elseif ($UM6HeldOutValidation) {
    "G1-$ControllerEvidenceFamily-HELDOUT-R$UM6HeldOutRepetition"
} elseif ($isUm6Family) {
    "G1-$ControllerEvidenceFamily-SELECTION"
} elseif ($UM5HeldOutValidation) {
    "G1-$ControllerEvidenceFamily-HELDOUT-R$UM5HeldOutRepetition"
} elseif ($isUm5Family) {
    "G1-$ControllerEvidenceFamily-SELECTION"
} elseif ($UM4HeldOutValidation) {
    "G1-$ControllerEvidenceFamily-HELDOUT-R$UM4HeldOutRepetition"
} elseif ($isUm4Family) {
    "G1-$ControllerEvidenceFamily-SELECTION"
} elseif ($UM3HeldOutValidation) {
    "G1-$ControllerEvidenceFamily-HELDOUT-R$UM3HeldOutRepetition"
} elseif ($isUm3Family) {
    "G1-$ControllerEvidenceFamily-SELECTION"
} elseif ($UM2HeldOutValidation) {
    "G1-$ControllerEvidenceFamily-HELDOUT-R$UM2HeldOutRepetition"
} elseif ($isUm2Family) {
    "G1-$ControllerEvidenceFamily-SELECTION"
} elseif ($UM1HeldOutValidation) {
    "G1-UM1-S2B-HELDOUT-R$UM1HeldOutRepetition"
} elseif ($FixtureVariationAxis -eq "symmetric_upper_mass") {
    "G1-UM1-S2B-EXPLORATORY"
} elseif ($S2HeldOutValidation) {
    "G1-$ControllerEvidenceFamily-HELDOUT-R$S2HeldOutRepetition"
} else {
    "G1-$ControllerEvidenceFamily"
}
$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$godotPath = [System.IO.Path]::GetFullPath($Godot)
$processRunner = Join-Path $PSScriptRoot "process_runner.ps1"
$testRelativePath = (
    "tests\" +
    "test_experimental_br14a_7_physical_wave_gait_torso_mass_probe.gd"
)
$runnerRelativePath = (
    "scripts\run_br14a_physical_wave_gait_torso_mass_probe.ps1"
)
$sourceRelativePaths = @(
    "scripts\lab\gait\physical_wave_gait_quadruped.gd",
    "scripts\lab\gait\physical_quadruped_fixture_spec.gd",
    "scripts\lab\mechanics\semantic_contact_rigid_body.gd",
    "scripts\lab\canonical_json.gd",
    "scripts\lab\finite_sanitizer.gd",
    "scripts\process_runner.ps1",
    "scripts\process_runner_containment_host.ps1",
    $testRelativePath,
    $runnerRelativePath
)

if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable not found: $godotPath"
}
if (-not (Test-Path -LiteralPath $processRunner -PathType Leaf)) {
    throw "Process runner not found: $processRunner"
}
. $processRunner
if ($TorsoMassCellsKg.Count -ne $expectedCellsKg.Count) {
    throw "The preregistered mass-axis grid cannot be resized."
}
for ($index = 0; $index -lt $expectedCellsKg.Count; $index++) {
    if (
        -not [double]::IsFinite($TorsoMassCellsKg[$index]) -or
        [Math]::Abs(
            $TorsoMassCellsKg[$index] - $expectedCellsKg[$index]
        ) -gt 1.0e-12
    ) {
        throw (
            "Mass-axis cell {0} must remain exactly {1} kg." -f @(
                $index,
                $expectedCellsKg[$index]
            )
        )
    }
}
foreach ($relativePath in $sourceRelativePaths) {
    $sourcePath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Required source file not found: $sourcePath"
    }
}

$suiteMutexName = "Local\SporeSpore.RunLabTests.Serial.v1"
$suiteMutex = [System.Threading.Mutex]::new($false, $suiteMutexName)
$suiteMutexAcquired = $false
$suiteMutexWasAbandoned = $false
try {
    $suiteMutexAcquired = $suiteMutex.WaitOne(0)
} catch [System.Threading.AbandonedMutexException] {
    $suiteMutexAcquired = $true
    $suiteMutexWasAbandoned = $true
}
if (-not $suiteMutexAcquired) {
    throw (
        "Another SporeSpore lab-test harness owns the suite mutex " +
        "'$suiteMutexName'. Refusing overlapping physics execution."
    )
}

try {
$runStamp = Get-Date -Format "yyyyMMddTHHmmssfff"
$campaignRoot = Join-Path (
    [System.IO.Path]::GetFullPath($LogRoot)
) $runStamp
[void][System.IO.Directory]::CreateDirectory($campaignRoot)

$projectText = @'
; Isolated SporeSpore BR14A.7 native-controller torso-mass probe.

config_version=5

[application]

config/name="sporespore-br14a-torso-mass-probe"
config/features=PackedStringArray("4.7", "Forward Plus")

[debug]

gdscript/warnings/shadowed_global_identifier=0

[physics]

3d/physics_engine="Jolt Physics"
jolt_physics_3d/simulation/velocity_steps=20
jolt_physics_3d/simulation/position_steps=6
'@

$sourceHashes = [ordered]@{}
foreach ($relativePath in $sourceRelativePaths) {
    $normalizedRelativePath = $relativePath.Replace("\", "/")
    $hash = Get-FileHash `
        -LiteralPath (Join-Path $repoRoot $relativePath) `
        -Algorithm SHA256
    $sourceHashes[$normalizedRelativePath] = (
        "sha256:" + $hash.Hash.ToLowerInvariant()
    )
}
$godotHash = Get-FileHash -LiteralPath $godotPath -Algorithm SHA256
$sourceSnapshotRoot = Join-Path $campaignRoot "_source_snapshot"
[void][System.IO.Directory]::CreateDirectory($sourceSnapshotRoot)
foreach ($relativePath in $sourceRelativePaths) {
    $sourcePath = Join-Path $repoRoot $relativePath
    $snapshotPath = Join-Path $sourceSnapshotRoot $relativePath
    [void][System.IO.Directory]::CreateDirectory(
        (Split-Path -Parent $snapshotPath)
    )
    Copy-Item `
        -LiteralPath $sourcePath `
        -Destination $snapshotPath `
        -Force
    $normalizedRelativePath = $relativePath.Replace("\", "/")
    $snapshotHash = Get-FileHash `
        -LiteralPath $snapshotPath `
        -Algorithm SHA256
    $snapshotDigest = "sha256:" + $snapshotHash.Hash.ToLowerInvariant()
    if ($snapshotDigest -ne $sourceHashes[$normalizedRelativePath]) {
        throw (
            "Source changed while creating the immutable campaign snapshot: " +
            $relativePath
        )
    }
}

Push-Location $repoRoot
try {
    $sourceCommit = (& git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sourceCommit)) {
        throw "Unable to resolve the source commit."
    }
    $scopedStatus = @(
        & git status --porcelain=v1 -- @sourceRelativePaths
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect the scoped source status."
    }
} finally {
    Pop-Location
}

function ConvertFrom-GodotLimbReceipt {
    param([System.Text.RegularExpressions.Match]$Match)
    if (-not $Match.Success) {
        return $null
    }
    try {
        return ($Match.Groups[1].Value | ConvertFrom-Json)
    } catch {
        return $null
    }
}

function Test-NonnegativeLimbReceipt {
    param([object]$Receipt)
    if ($null -eq $Receipt) {
        return $false
    }
    foreach ($limbId in @(
        "front_left",
        "front_right",
        "rear_left",
        "rear_right"
    )) {
        $property = $Receipt.PSObject.Properties[$limbId]
        if ($null -eq $property) {
            return $false
        }
        try {
            $value = [int]$property.Value
        } catch {
            return $false
        }
        if ($value -lt 0) {
            return $false
        }
    }
    return $true
}

$results = @()
foreach ($massKg in $TorsoMassCellsKg) {
    $massText = $massKg.ToString(
        "0.0000",
        [System.Globalization.CultureInfo]::InvariantCulture
    )
    $expectedMassRatio = if ($isAdaptiveUpperMassFamily) {
        ($massKg + 0.18) / (0.25 + 0.18)
    } else {
        1.0
    }
    $expectedHipActuatorExponent = if ($isAdaptiveUpperMassFamily) {
        if ($isUm4Family) {
            0.5
        } elseif (
            $isUm6Family -or
            $isUm7Family -or
            $isUm8Family -or
            $isUm9Family -or
            $isUm10Family
        ) {
            1.0
        } else {
            [double]$upperMassCandidateExponent
        }
    } else {
        0.0
    }
    $expectedKneeActuatorExponent = if ($isUm2Family) {
        $expectedHipActuatorExponent
    } elseif ($isUm4Family) {
        [double]$upperMassCandidateExponent
    } elseif (
        $isUm5Family -or
        $isUm6Family -or
        $isUm7Family -or
        $isUm8Family -or
        $isUm9Family -or
        $isUm10Family
    ) {
        0.5
    } else {
        0.0
    }
    $expectedAttenuationRatio = if (
        $isUm4Family -or
        $isUm5Family -or
        $isUm6Family -or
        $isUm7Family -or
        $isUm8Family -or
        $isUm9Family -or
        $isUm10Family
    ) {
        [Math]::Min(
            $expectedMassRatio,
            1.0 / $expectedMassRatio
        )
    } else {
        1.0
    }
    $expectedHipActuatorScale = if (
        $isUm5Family -or
        $isUm6Family -or
        $isUm7Family -or
        $isUm8Family -or
        $isUm9Family -or
        $isUm10Family
    ) {
        [Math]::Clamp(
            [Math]::Pow(
                $expectedAttenuationRatio,
                $expectedHipActuatorExponent
            ),
            0.80,
            1.0
        )
    } elseif ($isAdaptiveUpperMassFamily) {
        [Math]::Clamp(
            [Math]::Pow(
                $expectedMassRatio,
                $expectedHipActuatorExponent
            ),
            0.80,
            1.25
        )
    } else {
        1.0
    }
    $expectedKneeAttenuationRatio = $expectedAttenuationRatio
    $expectedKneeActuatorScale = if ($isUm2Family) {
        $expectedHipActuatorScale
    } elseif (
        $isUm4Family -or
        $isUm5Family -or
        $isUm6Family -or
        $isUm7Family -or
        $isUm8Family -or
        $isUm9Family -or
        $isUm10Family
    ) {
        [Math]::Clamp(
            [Math]::Pow(
                $expectedKneeAttenuationRatio,
                $expectedKneeActuatorExponent
            ),
            0.80,
            1.0
        )
    } else {
        1.0
    }
    $expectedHipMaxImpulseNms = 0.055 * $expectedHipActuatorScale
    $expectedKneeMaxImpulseNms = (
        0.045 * 10.0 * $expectedKneeActuatorScale
    )
    $expectedHeavyFraction = if (
        $isUm6Family -or
        $isUm7Family -or
        $isUm8Family -or
        $isUm9Family -or
        $isUm10Family
    ) {
        [Math]::Clamp(
            ($massKg - 0.25) / (0.30 - 0.25),
            0.0,
            1.0
        )
    } else {
        0.0
    }
    $expectedEndpointKneeFlexionScale = if ($isUm6Family) {
        [double]$um6EndpointKneeFlexionScale
    } elseif (
        $isUm7Family -or
        $isUm8Family -or
        $isUm9Family -or
        $isUm10Family
    ) {
        1.30
    } else {
        1.75
    }
    $expectedKneeFlexionScale = if (
        $isUm6Family -or
        $isUm7Family -or
        $isUm8Family -or
        $isUm9Family -or
        $isUm10Family
    ) {
        1.75 + (
            $expectedEndpointKneeFlexionScale - 1.75
        ) * $expectedHeavyFraction
    } else {
        1.75
    }
    $expectedEndpointSwingTicks = if ($isUm7Family) {
        [int]$um7EndpointSwingTicks
    } elseif ($isUm8Family -or $isUm9Family -or $isUm10Family) {
        60
    } else {
        72
    }
    $expectedSwingTicks = if (
        $isUm7Family -or
        $isUm8Family -or
        $isUm9Family -or
        $isUm10Family
    ) {
        [int][Math]::Round(
            72.0 + (
                [double]$expectedEndpointSwingTicks - 72.0
            ) * $expectedHeavyFraction,
            [System.MidpointRounding]::AwayFromZero
        )
    } else {
        72
    }
    $expectedReleaseGateTick = [Math]::Floor(
        $expectedSwingTicks * 3.0 / 4.0
    )
    $expectedRecontactGateTick = (
        $expectedSwingTicks +
        [Math]::Floor((360.0 - $expectedSwingTicks) / 4.0)
    )
    $expectedEndpointContactLoadedKneeSpeedRadS = if ($isUm8Family) {
        [double]$um8EndpointSpeedRadS
    } elseif ($isUm9Family -or $isUm10Family) {
        2.5
    } else {
        3.5
    }
    $expectedContactLoadedKneeSpeedRadS = if (
        $isUm8Family -or
        $isUm9Family -or
        $isUm10Family
    ) {
        3.5 + (
            $expectedEndpointContactLoadedKneeSpeedRadS - 3.5
        ) * $expectedHeavyFraction
    } else {
        3.5
    }
    $expectedSpeedCapActive = (
        ($isUm8Family -or $isUm9Family -or $isUm10Family) -and
        $massKg -gt 0.25
    )
    $expectedActivationStartOffsetTicks = if ($isUm9Family) {
        [int]$um9ActivationStartOffsetTicks
    } else {
        0
    }
    $expectedActivationStartPhaseTick = if (
        $isUm9Family -and
        $massKg -gt 0.25
    ) {
        [int]$expectedReleaseGateTick +
        $expectedActivationStartOffsetTicks
    } else {
        0
    }
    $expectedPreReleaseLeadTicks = if ($isUm10Family) {
        [int]$um10PreReleaseLeadTicks
    } else {
        0
    }
    if ($isUm10Family -and $massKg -gt 0.25) {
        $expectedActivationStartPhaseTick = (
            [int]$expectedReleaseGateTick -
            $expectedPreReleaseLeadTicks
        )
    }
    $expectedFullSpeedOverridePhaseTick = if (
        $isUm10Family -and
        $massKg -gt 0.25
    ) {
        [int]$expectedReleaseGateTick
    } else {
        -1
    }
    $cellId = "mass-" + $massText.Replace(".", "p")
    $runRoot = Join-Path $campaignRoot $cellId
    $directories = @(
        $runRoot,
        (Join-Path $runRoot "scripts\lab\gait"),
        (Join-Path $runRoot "scripts\lab\mechanics"),
        (Join-Path $runRoot "tests"),
        (Join-Path $runRoot "worker\appdata"),
        (Join-Path $runRoot "worker\localappdata")
    )
    foreach ($directory in $directories) {
        [void][System.IO.Directory]::CreateDirectory($directory)
    }
    [System.IO.File]::WriteAllText(
        (Join-Path $runRoot "project.godot"),
        $projectText,
        [System.Text.UTF8Encoding]::new($false)
    )
    foreach ($relativePath in $sourceRelativePaths) {
        Copy-Item `
            -LiteralPath (Join-Path $sourceSnapshotRoot $relativePath) `
            -Destination (Join-Path $runRoot $relativePath) `
            -Force
    }

    $transcriptPath = Join-Path $runRoot "transcript.log"
    $engineLogPath = Join-Path $runRoot "godot.log"
    $previousAppData = $env:APPDATA
    $previousLocalAppData = $env:LOCALAPPDATA
    try {
        $env:APPDATA = Join-Path $runRoot "worker\appdata"
        $env:LOCALAPPDATA = Join-Path $runRoot "worker\localappdata"
        $invocation = Invoke-ProcessWithTimeout `
            -FilePath $godotPath `
            -ArgumentList @(
                "--headless",
                "--path",
                $runRoot,
                "--script",
                "res://$($testRelativePath.Replace('\', '/'))",
                "--log-file",
                $engineLogPath,
                "--",
                $massText,
                $controllerFamilyId,
                $FixtureVariationAxis
            ) `
            -TimeoutSeconds $TestTimeoutSeconds `
            -TranscriptPath $transcriptPath
    } finally {
        $env:APPDATA = $previousAppData
        $env:LOCALAPPDATA = $previousLocalAppData
    }

    $outputText = @($invocation.Lines) -join [Environment]::NewLine
    $engineLogExists = Test-Path `
        -LiteralPath $engineLogPath `
        -PathType Leaf
    $engineLogText = if ($engineLogExists) {
        Get-Content -LiteralPath $engineLogPath -Raw
    } else {
        ""
    }
    $footerMatches = [regex]::Matches(
        $outputText,
        '(?m)^===\s+(\d+)\s+passed,\s+(\d+)\s+failed\s+===\s*$'
    )
    $assertionsPassed = if ($footerMatches.Count -eq 1) {
        [int]$footerMatches[0].Groups[1].Value
    } else {
        $null
    }
    $assertionsFailed = if ($footerMatches.Count -eq 1) {
        [int]$footerMatches[0].Groups[2].Value
    } else {
        $null
    }
    $engineErrors = @(
        [regex]::Matches(
            $outputText + [Environment]::NewLine + $engineLogText,
            '(?im)^\s*(?:SCRIPT ERROR:|ERROR:).*$'
        ) |
            ForEach-Object { $_.Value.Trim() } |
            Sort-Object -Unique
    )
    $resultMatches = [regex]::Matches(
        $outputText,
        '(?m)^MASS_AXIS_RESULT .*$'
    )
    $resultLine = if ($resultMatches.Count -eq 1) {
        $resultMatches[0].Value
    } else {
        ""
    }
    $walkingMatch = [regex]::Match(
        $resultLine,
        '\bwalking=(true|false)\b'
    )
    $controllerFamilyMatch = [regex]::Match(
        $resultLine,
        '\bcontroller_family=([a-z0-9_]+)\b'
    )
    $fixtureVariationAxisMatch = [regex]::Match(
        $resultLine,
        '\bvariation_axis=([a-z0-9_]+)\b'
    )
    $walkingObserved = if ($walkingMatch.Success) {
        [bool]::Parse($walkingMatch.Groups[1].Value)
    } else {
        $null
    }
    $fixtureDigestMatch = [regex]::Match(
        $resultLine,
        '\bfixture_digest=(sha256:[0-9a-f]{64})\b'
    )
    $controllerDigestMatch = [regex]::Match(
        $resultLine,
        '\bcontroller_digest=(sha256:[0-9a-f]{64})\b'
    )
    $policyDigestMatch = [regex]::Match(
        $resultLine,
        '\bpolicy_digest=(none|sha256:[0-9a-f]{64})\b'
    )
    $massRatioMatch = [regex]::Match(
        $resultLine,
        '\bmass_ratio=([0-9]+\.[0-9]+)\b'
    )
    $actuatorExponentMatch = [regex]::Match(
        $resultLine,
        '\bexponent=([0-9]+\.[0-9]+)\b'
    )
    $actuatorScaleMatch = [regex]::Match(
        $resultLine,
        '\bactuator_scale=([0-9]+\.[0-9]+)\b'
    )
    $hipExponentMatch = [regex]::Match(
        $resultLine,
        '\bhip_exponent=([0-9]+\.[0-9]+)\b'
    )
    $kneeExponentMatch = [regex]::Match(
        $resultLine,
        '\bknee_exponent=([0-9]+\.[0-9]+)\b'
    )
    $kneeAttenuationRatioMatch = [regex]::Match(
        $resultLine,
        '\bknee_attenuation_ratio=([0-9]+\.[0-9]+)\b'
    )
    $attenuationRatioMatch = [regex]::Match(
        $resultLine,
        '\battenuation_ratio=([0-9]+\.[0-9]+)\b'
    )
    $hipScaleMatch = [regex]::Match(
        $resultLine,
        '\bhip_scale=([0-9]+\.[0-9]+)\b'
    )
    $kneeScaleMatch = [regex]::Match(
        $resultLine,
        '\bknee_scale=([0-9]+\.[0-9]+)\b'
    )
    $heavyFractionMatch = [regex]::Match(
        $resultLine,
        '\bheavy_fraction=([0-9]+\.[0-9]+)\b'
    )
    $endpointKneeFlexionScaleMatch = [regex]::Match(
        $resultLine,
        '\bendpoint_knee_flexion_scale=([0-9]+\.[0-9]+)\b'
    )
    $kneeFlexionScaleMatch = [regex]::Match(
        $resultLine,
        '\bknee_flexion_scale=([0-9]+\.[0-9]+)\b'
    )
    $endpointSwingTicksMatch = [regex]::Match(
        $resultLine,
        '\bendpoint_swing_ticks=([0-9]+)\b'
    )
    $swingTicksMatch = [regex]::Match(
        $resultLine,
        '\bswing_ticks=([0-9]+)\b'
    )
    $releaseGateTickMatch = [regex]::Match(
        $resultLine,
        '\brelease_gate_tick=([0-9]+)\b'
    )
    $recontactGateTickMatch = [regex]::Match(
        $resultLine,
        '\brecontact_gate_tick=([0-9]+)\b'
    )
    $endpointContactLoadedKneeSpeedMatch = [regex]::Match(
        $resultLine,
        '\bendpoint_contact_loaded_knee_speed=([0-9]+\.[0-9]+)\b'
    )
    $contactLoadedKneeSpeedMatch = [regex]::Match(
        $resultLine,
        '\bcontact_loaded_knee_speed=([0-9]+\.[0-9]+)\b'
    )
    $speedCapActivationsMatch = [regex]::Match(
        $resultLine,
        '\bspeed_cap_activations=([0-9]+)\b'
    )
    $activationStartPhaseTickMatch = [regex]::Match(
        $resultLine,
        '\bactivation_start_phase_tick=([0-9]+)\b'
    )
    $activationStartOffsetTicksMatch = [regex]::Match(
        $resultLine,
        '\bactivation_start_offset_ticks=([0-9]+)\b'
    )
    $fullSpeedOverridePhaseTickMatch = [regex]::Match(
        $resultLine,
        '\bfull_speed_override_phase_tick=(-?[0-9]+)\b'
    )
    $preReleaseLeadTicksMatch = [regex]::Match(
        $resultLine,
        '\bpre_release_lead_ticks=([0-9]+)\b'
    )
    $maximumContactLoadedKneeCommandSpeedMatch = [regex]::Match(
        $resultLine,
        '\bmax_contact_loaded_knee_command_speed=([0-9]+\.[0-9]+)\b'
    )
    $maximumHipCommandSpeedMatch = [regex]::Match(
        $resultLine,
        '\bmax_hip_command_speed=([0-9]+\.[0-9]+)\b'
    )
    $maximumKneeCommandSpeedMatch = [regex]::Match(
        $resultLine,
        '\bmax_knee_command_speed=([0-9]+\.[0-9]+)\b'
    )
    $gateReleaseHoldsMatch = [regex]::Match(
        $resultLine,
        '\bgate_release_holds=(\{.*?\}) gate_recontact_holds='
    )
    $gateRecontactHoldsMatch = [regex]::Match(
        $resultLine,
        '\bgate_recontact_holds=(\{.*?\}) gate_timeouts='
    )
    $gateTimeoutsMatch = [regex]::Match(
        $resultLine,
        '\bgate_timeouts=(\{.*?\}) gate_sync_holds='
    )
    $gateSyncHoldsMatch = [regex]::Match(
        $resultLine,
        '\bgate_sync_holds=(\{.*?\}) evidence_gait_advance='
    )
    $evidenceGaitAdvanceMatch = [regex]::Match(
        $resultLine,
        '\bevidence_gait_advance=(\{.*?\}) gates='
    )
    $hipImpulseMatch = [regex]::Match(
        $resultLine,
        '\bhip_impulse=([0-9]+\.[0-9]+)\b'
    )
    $kneeImpulseMatch = [regex]::Match(
        $resultLine,
        '\bknee_impulse=([0-9]+\.[0-9]+)\b'
    )
    $anchorJointMatch = [regex]::Match(
        $resultLine,
        '\banchor_joint=([a-z_]+(?:\.[a-z_]+)?)\b'
    )
    $anchorTickMatch = [regex]::Match(
        $resultLine,
        '\banchor_tick=(-?[0-9]+)\b'
    )
    $realizedActuatorScale = if ($actuatorScaleMatch.Success) {
        [double]::Parse(
            $actuatorScaleMatch.Groups[1].Value,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } else {
        [double]::NaN
    }
    $realizedMassRatio = if ($massRatioMatch.Success) {
        [double]::Parse(
            $massRatioMatch.Groups[1].Value,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } else {
        [double]::NaN
    }
    $realizedActuatorExponent = if ($actuatorExponentMatch.Success) {
        [double]::Parse(
            $actuatorExponentMatch.Groups[1].Value,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } else {
        [double]::NaN
    }
    $realizedHipActuatorExponent = if ($hipExponentMatch.Success) {
        [double]::Parse(
            $hipExponentMatch.Groups[1].Value,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } else {
        [double]::NaN
    }
    $realizedKneeActuatorExponent = if ($kneeExponentMatch.Success) {
        [double]::Parse(
            $kneeExponentMatch.Groups[1].Value,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } else {
        [double]::NaN
    }
    $realizedKneeAttenuationRatio = if (
        $kneeAttenuationRatioMatch.Success
    ) {
        [double]::Parse(
            $kneeAttenuationRatioMatch.Groups[1].Value,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } else {
        [double]::NaN
    }
    $realizedAttenuationRatio = if ($attenuationRatioMatch.Success) {
        [double]::Parse(
            $attenuationRatioMatch.Groups[1].Value,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } else {
        [double]::NaN
    }
    $realizedHipActuatorScale = if ($hipScaleMatch.Success) {
        [double]::Parse(
            $hipScaleMatch.Groups[1].Value,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } else {
        [double]::NaN
    }
    $realizedKneeActuatorScale = if ($kneeScaleMatch.Success) {
        [double]::Parse(
            $kneeScaleMatch.Groups[1].Value,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } else {
        [double]::NaN
    }
    $realizedHeavyFraction = if ($heavyFractionMatch.Success) {
        [double]::Parse(
            $heavyFractionMatch.Groups[1].Value,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } else {
        [double]::NaN
    }
    $realizedEndpointKneeFlexionScale = if (
        $endpointKneeFlexionScaleMatch.Success
    ) {
        [double]::Parse(
            $endpointKneeFlexionScaleMatch.Groups[1].Value,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } else {
        [double]::NaN
    }
    $realizedKneeFlexionScale = if ($kneeFlexionScaleMatch.Success) {
        [double]::Parse(
            $kneeFlexionScaleMatch.Groups[1].Value,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } else {
        [double]::NaN
    }
    $realizedEndpointSwingTicks = if ($endpointSwingTicksMatch.Success) {
        [int]$endpointSwingTicksMatch.Groups[1].Value
    } else {
        -1
    }
    $realizedSwingTicks = if ($swingTicksMatch.Success) {
        [int]$swingTicksMatch.Groups[1].Value
    } else {
        -1
    }
    $realizedReleaseGateTick = if ($releaseGateTickMatch.Success) {
        [int]$releaseGateTickMatch.Groups[1].Value
    } else {
        -1
    }
    $realizedRecontactGateTick = if ($recontactGateTickMatch.Success) {
        [int]$recontactGateTickMatch.Groups[1].Value
    } else {
        -1
    }
    $realizedEndpointContactLoadedKneeSpeedRadS = if (
        $endpointContactLoadedKneeSpeedMatch.Success
    ) {
        [double]::Parse(
            $endpointContactLoadedKneeSpeedMatch.Groups[1].Value,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } else {
        [double]::NaN
    }
    $realizedContactLoadedKneeSpeedRadS = if (
        $contactLoadedKneeSpeedMatch.Success
    ) {
        [double]::Parse(
            $contactLoadedKneeSpeedMatch.Groups[1].Value,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } else {
        [double]::NaN
    }
    $realizedSpeedCapActivations = if (
        $speedCapActivationsMatch.Success
    ) {
        [int]$speedCapActivationsMatch.Groups[1].Value
    } else {
        -1
    }
    $realizedActivationStartPhaseTick = if (
        $activationStartPhaseTickMatch.Success
    ) {
        [int]$activationStartPhaseTickMatch.Groups[1].Value
    } else {
        -1
    }
    $realizedActivationStartOffsetTicks = if (
        $activationStartOffsetTicksMatch.Success
    ) {
        [int]$activationStartOffsetTicksMatch.Groups[1].Value
    } else {
        -1
    }
    $realizedFullSpeedOverridePhaseTick = if (
        $fullSpeedOverridePhaseTickMatch.Success
    ) {
        [int]$fullSpeedOverridePhaseTickMatch.Groups[1].Value
    } else {
        -2
    }
    $realizedPreReleaseLeadTicks = if (
        $preReleaseLeadTicksMatch.Success
    ) {
        [int]$preReleaseLeadTicksMatch.Groups[1].Value
    } else {
        -1
    }
    $realizedMaximumContactLoadedKneeCommandSpeedRadS = if (
        $maximumContactLoadedKneeCommandSpeedMatch.Success
    ) {
        [double]::Parse(
            $maximumContactLoadedKneeCommandSpeedMatch.Groups[1].Value,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } else {
        [double]::NaN
    }
    $realizedMaximumHipCommandSpeedRadS = if (
        $maximumHipCommandSpeedMatch.Success
    ) {
        [double]::Parse(
            $maximumHipCommandSpeedMatch.Groups[1].Value,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } else {
        [double]::NaN
    }
    $realizedMaximumKneeCommandSpeedRadS = if (
        $maximumKneeCommandSpeedMatch.Success
    ) {
        [double]::Parse(
            $maximumKneeCommandSpeedMatch.Groups[1].Value,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } else {
        [double]::NaN
    }
    $realizedGateReleaseHolds = ConvertFrom-GodotLimbReceipt `
        -Match $gateReleaseHoldsMatch
    $realizedGateRecontactHolds = ConvertFrom-GodotLimbReceipt `
        -Match $gateRecontactHoldsMatch
    $realizedGateTimeouts = ConvertFrom-GodotLimbReceipt `
        -Match $gateTimeoutsMatch
    $realizedGateSyncHolds = ConvertFrom-GodotLimbReceipt `
        -Match $gateSyncHoldsMatch
    $realizedEvidenceGaitAdvance = ConvertFrom-GodotLimbReceipt `
        -Match $evidenceGaitAdvanceMatch
    $realizedHipMaxImpulseNms = if ($hipImpulseMatch.Success) {
        [double]::Parse(
            $hipImpulseMatch.Groups[1].Value,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } else {
        [double]::NaN
    }
    $realizedKneeMaxImpulseNms = if ($kneeImpulseMatch.Success) {
        [double]::Parse(
            $kneeImpulseMatch.Groups[1].Value,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } else {
        [double]::NaN
    }
    $actuatorReceiptsExact = (
        $massRatioMatch.Success -and
        $actuatorExponentMatch.Success -and
        $actuatorScaleMatch.Success -and
        $hipExponentMatch.Success -and
        $kneeExponentMatch.Success -and
        $kneeAttenuationRatioMatch.Success -and
        $attenuationRatioMatch.Success -and
        $hipScaleMatch.Success -and
        $kneeScaleMatch.Success -and
        $heavyFractionMatch.Success -and
        $endpointKneeFlexionScaleMatch.Success -and
        $kneeFlexionScaleMatch.Success -and
        $endpointSwingTicksMatch.Success -and
        $swingTicksMatch.Success -and
        $releaseGateTickMatch.Success -and
        $recontactGateTickMatch.Success -and
        $hipImpulseMatch.Success -and
        $kneeImpulseMatch.Success -and
        $anchorJointMatch.Success -and
        $anchorTickMatch.Success -and
        [Math]::Abs(
            $realizedMassRatio - $expectedMassRatio
        ) -le 1.0e-10 -and
        [Math]::Abs(
            $realizedActuatorExponent - $expectedHipActuatorExponent
        ) -le 1.0e-10 -and
        [Math]::Abs(
            $realizedActuatorScale - $expectedHipActuatorScale
        ) -le 1.0e-8 -and
        [Math]::Abs(
            $realizedHipActuatorExponent - $expectedHipActuatorExponent
        ) -le 1.0e-10 -and
        [Math]::Abs(
            $realizedKneeActuatorExponent - $expectedKneeActuatorExponent
        ) -le 1.0e-10 -and
        [Math]::Abs(
            $realizedKneeAttenuationRatio - $expectedKneeAttenuationRatio
        ) -le 1.0e-10 -and
        [Math]::Abs(
            $realizedAttenuationRatio - $expectedAttenuationRatio
        ) -le 1.0e-10 -and
        [Math]::Abs(
            $realizedHipActuatorScale - $expectedHipActuatorScale
        ) -le 1.0e-8 -and
        [Math]::Abs(
            $realizedKneeActuatorScale - $expectedKneeActuatorScale
        ) -le 1.0e-8 -and
        [Math]::Abs(
            $realizedHeavyFraction - $expectedHeavyFraction
        ) -le 1.0e-8 -and
        [Math]::Abs(
            $realizedEndpointKneeFlexionScale -
            $expectedEndpointKneeFlexionScale
        ) -le 1.0e-8 -and
        [Math]::Abs(
            $realizedKneeFlexionScale - $expectedKneeFlexionScale
        ) -le 1.0e-8 -and
        $realizedEndpointSwingTicks -eq $expectedEndpointSwingTicks -and
        $realizedSwingTicks -eq $expectedSwingTicks -and
        $realizedReleaseGateTick -eq $expectedReleaseGateTick -and
        $realizedRecontactGateTick -eq $expectedRecontactGateTick -and
        $endpointContactLoadedKneeSpeedMatch.Success -and
        $contactLoadedKneeSpeedMatch.Success -and
        $speedCapActivationsMatch.Success -and
        $activationStartPhaseTickMatch.Success -and
        $activationStartOffsetTicksMatch.Success -and
        $fullSpeedOverridePhaseTickMatch.Success -and
        $preReleaseLeadTicksMatch.Success -and
        $maximumContactLoadedKneeCommandSpeedMatch.Success -and
        $maximumHipCommandSpeedMatch.Success -and
        $maximumKneeCommandSpeedMatch.Success -and
        [Math]::Abs(
            $realizedEndpointContactLoadedKneeSpeedRadS -
            $expectedEndpointContactLoadedKneeSpeedRadS
        ) -le 1.0e-8 -and
        [Math]::Abs(
            $realizedContactLoadedKneeSpeedRadS -
            $expectedContactLoadedKneeSpeedRadS
        ) -le 1.0e-8 -and
        $realizedActivationStartPhaseTick -eq (
            $expectedActivationStartPhaseTick
        ) -and
        $realizedActivationStartOffsetTicks -eq (
            $expectedActivationStartOffsetTicks
        ) -and
        $realizedFullSpeedOverridePhaseTick -eq (
            $expectedFullSpeedOverridePhaseTick
        ) -and
        $realizedPreReleaseLeadTicks -eq (
            $expectedPreReleaseLeadTicks
        ) -and
        (
            (
                $realizedSpeedCapActivations -gt 0 -and
                $realizedMaximumContactLoadedKneeCommandSpeedRadS -gt 0.0 -and
                $realizedMaximumContactLoadedKneeCommandSpeedRadS -le (
                    $expectedContactLoadedKneeSpeedRadS + 1.0e-8
                )
            ) -eq $expectedSpeedCapActive
        ) -and
        (
            (
                $realizedSpeedCapActivations -eq 0 -and
                $realizedMaximumContactLoadedKneeCommandSpeedRadS -eq 0.0
            ) -eq (-not $expectedSpeedCapActive)
        ) -and
        $realizedMaximumHipCommandSpeedRadS -gt 0.0 -and
        $realizedMaximumHipCommandSpeedRadS -le 3.5 -and
        $realizedMaximumKneeCommandSpeedRadS -gt 0.0 -and
        $realizedMaximumKneeCommandSpeedRadS -le 3.5 -and
        (Test-NonnegativeLimbReceipt $realizedGateReleaseHolds) -and
        (Test-NonnegativeLimbReceipt $realizedGateRecontactHolds) -and
        (Test-NonnegativeLimbReceipt $realizedGateTimeouts) -and
        (Test-NonnegativeLimbReceipt $realizedGateSyncHolds) -and
        (Test-NonnegativeLimbReceipt $realizedEvidenceGaitAdvance) -and
        [Math]::Abs(
            $realizedHipMaxImpulseNms - $expectedHipMaxImpulseNms
        ) -le 1.0e-8 -and
        [Math]::Abs(
            $realizedKneeMaxImpulseNms - $expectedKneeMaxImpulseNms
        ) -le 1.0e-8
    )
    $policyDigestExpected = if (
        $ControllerEvidenceFamily -eq "TC2" -or
        $isAdaptiveUpperMassFamily
    ) {
        $policyDigestMatch.Success -and
        $policyDigestMatch.Groups[1].Value.StartsWith("sha256:")
    } else {
        $policyDigestMatch.Success -and
        $policyDigestMatch.Groups[1].Value -eq "none"
    }
    $harnessPassed = (
        -not $invocation.TimedOut -and
        [string]::IsNullOrWhiteSpace($invocation.StartError) -and
        [string]::IsNullOrWhiteSpace($invocation.TerminationError) -and
        $invocation.ExitCode -eq 0 -and
        $invocation.ContainmentTreeClosed -and
        $invocation.ExitMarkerObserved -and
        $engineLogExists -and
        $footerMatches.Count -eq 1 -and
        $assertionsPassed -eq $expectedAssertionsPerCell -and
        $assertionsFailed -eq 0 -and
        $engineErrors.Count -eq 0 -and
        $resultMatches.Count -eq 1 -and
        $fixtureVariationAxisMatch.Success -and
        $fixtureVariationAxisMatch.Groups[1].Value -eq (
            $FixtureVariationAxis
        ) -and
        $controllerFamilyMatch.Success -and
        $controllerFamilyMatch.Groups[1].Value -eq $controllerFamilyId -and
        $walkingMatch.Success -and
        $fixtureDigestMatch.Success -and
        $controllerDigestMatch.Success -and
        $policyDigestExpected -and
        $actuatorReceiptsExact
    )
    $transcriptHash = Get-FileHash `
        -LiteralPath $transcriptPath `
        -Algorithm SHA256
    $engineLogHash = if ($engineLogExists) {
        Get-FileHash -LiteralPath $engineLogPath -Algorithm SHA256
    } else {
        $null
    }
    $results += [pscustomobject][ordered]@{
        fixture_variation_axis = $FixtureVariationAxis
        varied_mass_kg = $massKg
        torso_mass_kg = if (
            $FixtureVariationAxis -eq "torso_mass"
        ) { $massKg } else { $null }
        symmetric_upper_mass_kg = if (
            $FixtureVariationAxis -eq "symmetric_upper_mass"
        ) { $massKg } else { $null }
        controller_evidence_family = $ControllerEvidenceFamily
        controller_family_id = $controllerFamilyId
        harness_passed = $harnessPassed
        walking_observed = $walkingObserved
        timed_out = $invocation.TimedOut
        process_exit_code = $invocation.ExitCode
        killed_process_tree = $invocation.KilledProcessTree
        containment_tree_closed = $invocation.ContainmentTreeClosed
        assertions_passed = $assertionsPassed
        assertions_failed = $assertionsFailed
        engine_errors = $engineErrors
        fixture_spec_sha256 = if ($fixtureDigestMatch.Success) {
            $fixtureDigestMatch.Groups[1].Value
        } else {
            ""
        }
        controller_configuration_sha256 = if (
            $controllerDigestMatch.Success
        ) {
            $controllerDigestMatch.Groups[1].Value
        } else {
            ""
        }
        controller_policy_sha256 = if ($policyDigestMatch.Success) {
            $policyDigestMatch.Groups[1].Value
        } else {
            ""
        }
        expected_mass_ratio = $expectedMassRatio
        realized_mass_ratio = $realizedMassRatio
        expected_actuator_exponent = $expectedHipActuatorExponent
        realized_actuator_exponent = $realizedActuatorExponent
        expected_actuator_impulse_scale = $expectedHipActuatorScale
        realized_actuator_impulse_scale = $realizedActuatorScale
        expected_hip_actuator_exponent = $expectedHipActuatorExponent
        realized_hip_actuator_exponent = $realizedHipActuatorExponent
        expected_knee_actuator_exponent = $expectedKneeActuatorExponent
        realized_knee_actuator_exponent = $realizedKneeActuatorExponent
        expected_knee_attenuation_ratio = $expectedKneeAttenuationRatio
        realized_knee_attenuation_ratio = $realizedKneeAttenuationRatio
        expected_attenuation_ratio = $expectedAttenuationRatio
        realized_attenuation_ratio = $realizedAttenuationRatio
        expected_hip_actuator_impulse_scale = $expectedHipActuatorScale
        realized_hip_actuator_impulse_scale = $realizedHipActuatorScale
        expected_knee_actuator_impulse_scale = $expectedKneeActuatorScale
        realized_knee_actuator_impulse_scale = $realizedKneeActuatorScale
        expected_heavy_fraction = $expectedHeavyFraction
        realized_heavy_fraction = $realizedHeavyFraction
        expected_endpoint_knee_flexion_scale = (
            $expectedEndpointKneeFlexionScale
        )
        realized_endpoint_knee_flexion_scale = (
            $realizedEndpointKneeFlexionScale
        )
        expected_knee_flexion_scale = $expectedKneeFlexionScale
        realized_knee_flexion_scale = $realizedKneeFlexionScale
        expected_endpoint_swing_ticks = $expectedEndpointSwingTicks
        realized_endpoint_swing_ticks = $realizedEndpointSwingTicks
        expected_swing_ticks = $expectedSwingTicks
        realized_swing_ticks = $realizedSwingTicks
        expected_release_gate_tick = $expectedReleaseGateTick
        realized_release_gate_tick = $realizedReleaseGateTick
        expected_recontact_gate_tick = $expectedRecontactGateTick
        realized_recontact_gate_tick = $realizedRecontactGateTick
        expected_endpoint_contact_loaded_knee_speed_rad_s = (
            $expectedEndpointContactLoadedKneeSpeedRadS
        )
        realized_endpoint_contact_loaded_knee_speed_rad_s = (
            $realizedEndpointContactLoadedKneeSpeedRadS
        )
        expected_contact_loaded_knee_speed_rad_s = (
            $expectedContactLoadedKneeSpeedRadS
        )
        realized_contact_loaded_knee_speed_rad_s = (
            $realizedContactLoadedKneeSpeedRadS
        )
        expected_speed_cap_active = $expectedSpeedCapActive
        realized_speed_cap_activation_count = (
            $realizedSpeedCapActivations
        )
        expected_activation_start_phase_tick = (
            $expectedActivationStartPhaseTick
        )
        realized_activation_start_phase_tick = (
            $realizedActivationStartPhaseTick
        )
        expected_activation_start_offset_ticks = (
            $expectedActivationStartOffsetTicks
        )
        realized_activation_start_offset_ticks = (
            $realizedActivationStartOffsetTicks
        )
        expected_full_speed_override_phase_tick = (
            $expectedFullSpeedOverridePhaseTick
        )
        realized_full_speed_override_phase_tick = (
            $realizedFullSpeedOverridePhaseTick
        )
        expected_pre_release_lead_ticks = $expectedPreReleaseLeadTicks
        realized_pre_release_lead_ticks = $realizedPreReleaseLeadTicks
        maximum_contact_loaded_knee_command_speed_rad_s = (
            $realizedMaximumContactLoadedKneeCommandSpeedRadS
        )
        maximum_hip_command_speed_rad_s = (
            $realizedMaximumHipCommandSpeedRadS
        )
        maximum_knee_command_speed_rad_s = (
            $realizedMaximumKneeCommandSpeedRadS
        )
        contact_gate_release_hold_tick_count_by_limb = (
            $realizedGateReleaseHolds
        )
        contact_gate_recontact_hold_tick_count_by_limb = (
            $realizedGateRecontactHolds
        )
        contact_gate_timeout_count_by_limb = $realizedGateTimeouts
        contact_gate_phase_sync_hold_tick_count_by_limb = (
            $realizedGateSyncHolds
        )
        evidence_gait_advance_ticks_by_limb = (
            $realizedEvidenceGaitAdvance
        )
        expected_hip_max_impulse_nms = $expectedHipMaxImpulseNms
        realized_hip_max_impulse_nms = $realizedHipMaxImpulseNms
        expected_knee_max_impulse_nms = $expectedKneeMaxImpulseNms
        realized_knee_max_impulse_nms = $realizedKneeMaxImpulseNms
        maximum_anchor_error_joint_id = if ($anchorJointMatch.Success) {
            $anchorJointMatch.Groups[1].Value
        } else {
            ""
        }
        maximum_anchor_error_tick = if ($anchorTickMatch.Success) {
            [int]$anchorTickMatch.Groups[1].Value
        } else {
            -1
        }
        result_receipt = $resultLine
        transcript_sha256 = (
            "sha256:" + $transcriptHash.Hash.ToLowerInvariant()
        )
        engine_log_sha256 = if ($null -ne $engineLogHash) {
            "sha256:" + $engineLogHash.Hash.ToLowerInvariant()
        } else {
            ""
        }
        run_root = $runRoot
    }
    Write-Host (
        "mass_kg={0} harness={1} walking={2} assertions={3}/{4} errors={5}" -f @(
            $massText,
            $harnessPassed,
            $walkingObserved,
            $assertionsPassed,
            $assertionsFailed,
            $engineErrors.Count
        )
    )
    Write-Host $resultLine
}

$allHarnessPassed = (
    $scopedStatus.Count -eq 0 -and
    $results.Count -eq $TorsoMassCellsKg.Count -and
    @($results | Where-Object { -not $_.harness_passed }).Count -eq 0
)
$controllerDigests = @(
    $results |
        Where-Object { $_.harness_passed } |
        ForEach-Object { $_.controller_configuration_sha256 } |
        Sort-Object -Unique
)
$policyDigests = @(
    $results |
        Where-Object { $_.harness_passed } |
        ForEach-Object { $_.controller_policy_sha256 } |
        Sort-Object -Unique
)
$fixtureDigests = @(
    $results |
        Where-Object { $_.harness_passed } |
        ForEach-Object { $_.fixture_spec_sha256 } |
        Sort-Object -Unique
)
$controllerDigestConsistent = (
    $allHarnessPassed -and
    $controllerDigests.Count -eq 1
)
$controllerDigestContractSatisfied = if (
    $ControllerEvidenceFamily -eq "S2B"
) {
    $controllerDigestConsistent -and
    $controllerDigests[0] -eq $expectedLockedS2BControllerDigest
} elseif (
    $ControllerEvidenceFamily -eq "TC2" -or
    $isAdaptiveUpperMassFamily
) {
    $allHarnessPassed -and
    $controllerDigests.Count -eq $TorsoMassCellsKg.Count
} else {
    $controllerDigestConsistent
}
$policyDigestConsistent = if (
    $ControllerEvidenceFamily -eq "TC2" -or
    $isAdaptiveUpperMassFamily
) {
    $allHarnessPassed -and
    $policyDigests.Count -eq 1 -and
    $policyDigests[0].StartsWith("sha256:")
} else {
    $allHarnessPassed -and
    $policyDigests.Count -eq 1 -and
    $policyDigests[0] -eq "none"
}
$fixtureDigestDistinctByMass = (
    $allHarnessPassed -and
    $fixtureDigests.Count -eq $TorsoMassCellsKg.Count
)
$exploratoryScanComplete = (
    $allHarnessPassed -and
    $controllerDigestContractSatisfied -and
    $policyDigestConsistent -and
    $fixtureDigestDistinctByMass
)
$referenceResult = @(
    $results |
        Where-Object {
            [Math]::Abs($_.varied_mass_kg - $referenceMassKg) -le 1.0e-12
        }
)
$referenceWalking = (
    $referenceResult.Count -eq 1 -and
    $referenceResult[0].harness_passed -and
    $referenceResult[0].walking_observed
)
$passingMasses = @(
    $results |
        Where-Object { $_.harness_passed -and $_.walking_observed } |
        ForEach-Object { $_.varied_mass_kg }
)
$failingMasses = @(
    $results |
        Where-Object {
            $_.harness_passed -and -not $_.walking_observed
        } |
        ForEach-Object { $_.varied_mass_kg }
)
$tc1SelectionEligible = (
    $FixtureVariationAxis -eq "torso_mass" -and
    $ControllerEvidenceFamily.StartsWith("TC1") -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$s1SelectionEligible = (
    $FixtureVariationAxis -eq "torso_mass" -and
    $ControllerEvidenceFamily.StartsWith("S1") -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$s2SelectionEligible = (
    $FixtureVariationAxis -eq "torso_mass" -and
    $ControllerEvidenceFamily.StartsWith("S2") -and
    -not $S2HeldOutValidation -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$s2HeldOutRepetitionPassed = (
    $FixtureVariationAxis -eq "torso_mass" -and
    $S2HeldOutValidation -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$um1ExploratoryAllCellsPassed = (
    $FixtureVariationAxis -eq "symmetric_upper_mass" -and
    $ControllerEvidenceFamily -eq "S2B" -and
    -not $UM1HeldOutValidation -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$um2SelectionEligible = (
    $FixtureVariationAxis -eq "symmetric_upper_mass" -and
    $isUm2Family -and
    -not $UM2HeldOutValidation -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$um2HeldOutRepetitionPassed = (
    $UM2HeldOutValidation -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$um3SelectionEligible = (
    $FixtureVariationAxis -eq "symmetric_upper_mass" -and
    $isUm3Family -and
    -not $UM3HeldOutValidation -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$um3HeldOutRepetitionPassed = (
    $UM3HeldOutValidation -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$um4SelectionEligible = (
    $FixtureVariationAxis -eq "symmetric_upper_mass" -and
    $isUm4Family -and
    -not $UM4HeldOutValidation -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$um4HeldOutRepetitionPassed = (
    $UM4HeldOutValidation -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$um5SelectionEligible = (
    $FixtureVariationAxis -eq "symmetric_upper_mass" -and
    $isUm5Family -and
    -not $UM5HeldOutValidation -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$um5HeldOutRepetitionPassed = (
    $UM5HeldOutValidation -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$um6SelectionEligible = (
    $FixtureVariationAxis -eq "symmetric_upper_mass" -and
    $isUm6Family -and
    -not $UM6HeldOutValidation -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$um6HeldOutRepetitionPassed = (
    $UM6HeldOutValidation -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$um7SelectionEligible = (
    $FixtureVariationAxis -eq "symmetric_upper_mass" -and
    $isUm7Family -and
    -not $UM7HeldOutValidation -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$um7HeldOutRepetitionPassed = (
    $UM7HeldOutValidation -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$um8SelectionEligible = (
    $FixtureVariationAxis -eq "symmetric_upper_mass" -and
    $isUm8Family -and
    -not $UM8HeldOutValidation -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$um8HeldOutRepetitionPassed = (
    $UM8HeldOutValidation -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$um9SelectionEligible = (
    $FixtureVariationAxis -eq "symmetric_upper_mass" -and
    $isUm9Family -and
    -not $UM9HeldOutValidation -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$um9HeldOutRepetitionPassed = (
    $UM9HeldOutValidation -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$um10SelectionEligible = (
    $FixtureVariationAxis -eq "symmetric_upper_mass" -and
    $isUm10Family -and
    -not $UM10HeldOutValidation -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$um10HeldOutRepetitionPassed = (
    $UM10HeldOutValidation -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$um1HeldOutRepetitionPassed = (
    $UM1HeldOutValidation -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$tc2ExploratoryAllHeldOutPassed = (
    $FixtureVariationAxis -eq "torso_mass" -and
    $ControllerEvidenceFamily -eq "TC2" -and
    $exploratoryScanComplete -and
    $passingMasses.Count -eq $TorsoMassCellsKg.Count -and
    $failingMasses.Count -eq 0
)
$boundaryBrackets = @()
for ($index = 0; $index -lt $results.Count - 1; $index++) {
    $left = $results[$index]
    $right = $results[$index + 1]
    if (
        $left.harness_passed -and
        $right.harness_passed -and
        $left.walking_observed -ne $right.walking_observed
    ) {
        $boundaryBrackets += [pscustomobject][ordered]@{
            lower_mass_kg = $left.varied_mass_kg
            lower_walking = $left.walking_observed
            upper_mass_kg = $right.varied_mass_kg
            upper_walking = $right.walking_observed
        }
    }
}
$boundaryObserved = (
    $exploratoryScanComplete -and
    $referenceWalking -and
    $passingMasses.Count -gt 0 -and
    $failingMasses.Count -gt 0 -and
    $boundaryBrackets.Count -gt 0
)
$totalAssertionsPassed = (
    $results |
        Measure-Object -Property assertions_passed -Sum
).Sum
$totalAssertionsFailed = (
    $results |
        Measure-Object -Property assertions_failed -Sum
).Sum
$report = [ordered]@{
    schema_version = (
        "sporespore_br14a_single_mass_axis_probe_report_v14"
    )
    generated_utc = (Get-Date).ToUniversalTime().ToString("o")
    source_commit = $sourceCommit
    source_scope_clean = $scopedStatus.Count -eq 0
    scoped_source_tree_dirty = $scopedStatus.Count -gt 0
    scoped_source_status = $scopedStatus
    source_sha256 = $sourceHashes
    immutable_source_snapshot = $true
    source_snapshot_root = $sourceSnapshotRoot
    godot_path = $godotPath
    godot_sha256 = "sha256:" + $godotHash.Hash.ToLowerInvariant()
    physics_project_settings = [ordered]@{
        engine = "Jolt Physics"
        physics_hz = 120
        velocity_steps = 20
        position_steps = 6
    }
    suite_mutex_name = $suiteMutexName
    suite_mutex_acquired = $suiteMutexAcquired
    suite_mutex_was_abandoned = $suiteMutexWasAbandoned
    execution_policy = "serialized_contained_workers_v1"
    test_program = $testRelativePath.Replace("\", "/")
    campaign_id = $campaignId
    campaign_role = if ($UM10HeldOutValidation) {
        "um10_heldout_validation"
    } elseif ($isUm10Family) {
        "um10_policy_selection"
    } elseif ($UM9HeldOutValidation) {
        "um9_heldout_validation"
    } elseif ($isUm9Family) {
        "um9_policy_selection"
    } elseif ($UM8HeldOutValidation) {
        "um8_heldout_validation"
    } elseif ($isUm8Family) {
        "um8_policy_selection"
    } elseif ($UM7HeldOutValidation) {
        "um7_heldout_validation"
    } elseif ($isUm7Family) {
        "um7_policy_selection"
    } elseif ($UM6HeldOutValidation) {
        "um6_heldout_validation"
    } elseif ($isUm6Family) {
        "um6_policy_selection"
    } elseif ($UM5HeldOutValidation) {
        "um5_heldout_validation"
    } elseif ($isUm5Family) {
        "um5_policy_selection"
    } elseif ($UM4HeldOutValidation) {
        "um4_heldout_validation"
    } elseif ($isUm4Family) {
        "um4_policy_selection"
    } elseif ($UM3HeldOutValidation) {
        "um3_heldout_validation"
    } elseif ($isUm3Family) {
        "um3_policy_selection"
    } elseif ($UM2HeldOutValidation) {
        "um2_heldout_validation"
    } elseif ($isUm2Family) {
        "um2_policy_selection"
    } elseif ($UM1HeldOutValidation) {
        "um1_heldout_validation"
    } elseif ($FixtureVariationAxis -eq "symmetric_upper_mass") {
        "um1_exploratory"
    } elseif ($S2HeldOutValidation) {
        "s2_heldout_validation"
    } else {
        "controller_development"
    }
    s2_heldout_repetition = $S2HeldOutRepetition
    um1_heldout_repetition = $UM1HeldOutRepetition
    um2_heldout_repetition = $UM2HeldOutRepetition
    um3_heldout_repetition = $UM3HeldOutRepetition
    um4_heldout_repetition = $UM4HeldOutRepetition
    um5_heldout_repetition = $UM5HeldOutRepetition
    um6_heldout_repetition = $UM6HeldOutRepetition
    um7_heldout_repetition = $UM7HeldOutRepetition
    um8_heldout_repetition = $UM8HeldOutRepetition
    um9_heldout_repetition = $UM9HeldOutRepetition
    um10_heldout_repetition = $UM10HeldOutRepetition
    fixture_variation_axis = $FixtureVariationAxis
    controller_evidence_family = $ControllerEvidenceFamily
    controller_family_id = $controllerFamilyId
    preregistered_mass_cells_kg = $TorsoMassCellsKg
    preregistered_torso_mass_cells_kg = if (
        $FixtureVariationAxis -eq "torso_mass"
    ) { $TorsoMassCellsKg } else { @() }
    preregistered_symmetric_upper_mass_cells_kg = if (
        $FixtureVariationAxis -eq "symmetric_upper_mass"
    ) { $TorsoMassCellsKg } else { @() }
    varied_fixture_fields = if (
        $FixtureVariationAxis -eq "torso_mass"
    ) { @("torso.mass_kg") } else { @("limbs[*].upper_mass_kg") }
    fixed_geometry = $true
    fixed_contact_material = $true
    fixed_fixture_motor_fields = $true
    fixed_motor_limits = -not $isAdaptiveUpperMassFamily
    mass_adaptive_realized_motor_limits = $isAdaptiveUpperMassFamily
    fixed_controller_configuration = (
        $ControllerEvidenceFamily -ne "TC2" -and
        -not $isAdaptiveUpperMassFamily
    )
    fixed_controller_policy = $true
    morphology_adaptive_controller_policy = (
        $ControllerEvidenceFamily -eq "TC2" -or
        $isAdaptiveUpperMassFamily
    )
    um2_policy_exponent = if ($isUm2Family) {
        $upperMassCandidateExponent
    } else {
        $null
    }
    um3_hip_policy_exponent = if ($isUm3Family) {
        $upperMassCandidateExponent
    } else {
        $null
    }
    um3_knee_policy_exponent = if ($isUm3Family) { 0.0 } else { $null }
    um4_hip_policy_exponent = if ($isUm4Family) { 0.5 } else { $null }
    um4_knee_policy_exponent = if ($isUm4Family) {
        $upperMassCandidateExponent
    } else {
        $null
    }
    um5_hip_policy_exponent = if ($isUm5Family) {
        $upperMassCandidateExponent
    } else {
        $null
    }
    um5_knee_policy_exponent = if ($isUm5Family) { 0.5 } else { $null }
    um6_hip_policy_exponent = if ($isUm6Family) { 1.0 } else { $null }
    um6_knee_policy_exponent = if ($isUm6Family) { 0.5 } else { $null }
    um6_endpoint_knee_flexion_scale = if ($isUm6Family) {
        $um6EndpointKneeFlexionScale
    } else {
        $null
    }
    um7_hip_policy_exponent = if ($isUm7Family) { 1.0 } else { $null }
    um7_knee_policy_exponent = if ($isUm7Family) { 0.5 } else { $null }
    um7_endpoint_knee_flexion_scale = if ($isUm7Family) { 1.30 } else { $null }
    um7_endpoint_swing_ticks = if ($isUm7Family) {
        $um7EndpointSwingTicks
    } else {
        $null
    }
    um8_hip_policy_exponent = if ($isUm8Family) { 1.0 } else { $null }
    um8_knee_policy_exponent = if ($isUm8Family) { 0.5 } else { $null }
    um8_endpoint_knee_flexion_scale = if ($isUm8Family) {
        1.30
    } else {
        $null
    }
    um8_endpoint_swing_ticks = if ($isUm8Family) { 60 } else { $null }
    um8_endpoint_contact_loaded_knee_speed_rad_s = if ($isUm8Family) {
        $um8EndpointSpeedRadS
    } else {
        $null
    }
    um8_activation_predicate_id = if ($isUm8Family) {
        "contact_loaded_swing_knee"
    } else {
        $null
    }
    um9_hip_policy_exponent = if ($isUm9Family) { 1.0 } else { $null }
    um9_knee_policy_exponent = if ($isUm9Family) { 0.5 } else { $null }
    um9_endpoint_knee_flexion_scale = if ($isUm9Family) {
        1.30
    } else {
        $null
    }
    um9_endpoint_swing_ticks = if ($isUm9Family) { 60 } else { $null }
    um9_endpoint_contact_loaded_knee_speed_rad_s = if ($isUm9Family) {
        2.5
    } else {
        $null
    }
    um9_activation_start_offset_ticks = if ($isUm9Family) {
        $um9ActivationStartOffsetTicks
    } else {
        $null
    }
    um9_activation_predicate_id = if ($isUm9Family) {
        "phase_windowed_contact_loaded_swing_knee"
    } else {
        $null
    }
    um10_hip_policy_exponent = if ($isUm10Family) { 1.0 } else { $null }
    um10_knee_policy_exponent = if ($isUm10Family) { 0.5 } else { $null }
    um10_endpoint_knee_flexion_scale = if ($isUm10Family) {
        1.30
    } else {
        $null
    }
    um10_endpoint_swing_ticks = if ($isUm10Family) { 60 } else { $null }
    um10_endpoint_contact_loaded_knee_speed_rad_s = if ($isUm10Family) {
        2.5
    } else {
        $null
    }
    um10_pre_release_lead_ticks = if ($isUm10Family) {
        $um10PreReleaseLeadTicks
    } else {
        $null
    }
    um10_release_gate_full_speed_override = if ($isUm10Family) {
        $true
    } else {
        $null
    }
    um10_activation_predicate_id = if ($isUm10Family) {
        "release_gate_notched_contact_loaded_swing_knee"
    } else {
        $null
    }
    expected_assertions_per_cell = $expectedAssertionsPerCell
    total_assertions_passed = $totalAssertionsPassed
    total_assertions_failed = $totalAssertionsFailed
    all_harnesses_passed = $allHarnessPassed
    exploratory_boundary_scan_complete = $exploratoryScanComplete
    controller_configuration_sha256 = if (
        $controllerDigests.Count -eq 1
    ) {
        $controllerDigests[0]
    } else {
        ""
    }
    controller_digest_consistent_across_masses = (
        $controllerDigestConsistent
    )
    controller_digest_contract_satisfied = (
        $controllerDigestContractSatisfied
    )
    expected_locked_s2b_controller_sha256 = (
        $expectedLockedS2BControllerDigest
    )
    controller_policy_sha256 = if ($policyDigests.Count -eq 1) {
        $policyDigests[0]
    } else {
        ""
    }
    controller_policy_digest_consistent = $policyDigestConsistent
    fixture_digest_distinct_by_mass = $fixtureDigestDistinctByMass
    reference_cell_walked = $referenceWalking
    passing_masses_kg = $passingMasses
    failing_masses_kg = $failingMasses
    passing_torso_masses_kg = if (
        $FixtureVariationAxis -eq "torso_mass"
    ) { $passingMasses } else { @() }
    failing_torso_masses_kg = if (
        $FixtureVariationAxis -eq "torso_mass"
    ) { $failingMasses } else { @() }
    passing_symmetric_upper_masses_kg = if (
        $FixtureVariationAxis -eq "symmetric_upper_mass"
    ) { $passingMasses } else { @() }
    failing_symmetric_upper_masses_kg = if (
        $FixtureVariationAxis -eq "symmetric_upper_mass"
    ) { $failingMasses } else { @() }
    tc1_selection_eligible = $tc1SelectionEligible
    s1_selection_eligible = $s1SelectionEligible
    s2_selection_eligible = $s2SelectionEligible
    s2_heldout_repetition_passed = $s2HeldOutRepetitionPassed
    um1_exploratory_all_cells_passed = $um1ExploratoryAllCellsPassed
    um1_heldout_repetition_passed = $um1HeldOutRepetitionPassed
    um2_selection_eligible = $um2SelectionEligible
    um2_heldout_repetition_passed = $um2HeldOutRepetitionPassed
    um3_selection_eligible = $um3SelectionEligible
    um3_heldout_repetition_passed = $um3HeldOutRepetitionPassed
    um4_selection_eligible = $um4SelectionEligible
    um4_heldout_repetition_passed = $um4HeldOutRepetitionPassed
    um5_selection_eligible = $um5SelectionEligible
    um5_heldout_repetition_passed = $um5HeldOutRepetitionPassed
    um6_selection_eligible = $um6SelectionEligible
    um6_heldout_repetition_passed = $um6HeldOutRepetitionPassed
    um7_selection_eligible = $um7SelectionEligible
    um7_heldout_repetition_passed = $um7HeldOutRepetitionPassed
    um8_selection_eligible = $um8SelectionEligible
    um8_heldout_repetition_passed = $um8HeldOutRepetitionPassed
    um9_selection_eligible = $um9SelectionEligible
    um9_heldout_repetition_passed = $um9HeldOutRepetitionPassed
    um10_selection_eligible = $um10SelectionEligible
    um10_heldout_repetition_passed = $um10HeldOutRepetitionPassed
    tc2_exploratory_all_heldout_passed = (
        $tc2ExploratoryAllHeldOutPassed
    )
    boundary_brackets = $boundaryBrackets
    walking_outcome_boundary_observed = $boundaryObserved
    observation_scope = (
        (
            "one preregistered single-mass-axis grid with every other fixture " +
            "field fixed and one declared controller family held fixed"
        )
    )
    exploratory_development_only = $true
    bounded_torso_mass_robustness_observed = $false
    bounded_symmetric_upper_mass_robustness_observed = $false
    g1_complete = $false
    morphology_generalization_established = $false
    formal_milestone_acceptance_authorized = $false
    encyclopedia_admission_authorized = $false
    automatic_creature_guidance_allowed = $false
    results = $results
}
$reportPath = Join-Path $campaignRoot "report.json"
$reportJson = $report | ConvertTo-Json -Depth 12
[System.IO.File]::WriteAllText(
    $reportPath,
    $reportJson + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)
$reportHash = Get-FileHash -LiteralPath $reportPath -Algorithm SHA256

Write-Host "REPORT=$reportPath"
Write-Host (
    "REPORT_SHA256=sha256:" + $reportHash.Hash.ToLowerInvariant()
)
Write-Host (
    (
        "CAMPAIGN={0} AXIS={1} CAMPAIGN_PASSED={2} ASSERTIONS={3}/{4} " +
        "PASSING={5} FAILING={6} BOUNDARY_OBSERVED={7} " +
        "TC1_SELECTION_ELIGIBLE={8} S1_SELECTION_ELIGIBLE={9} " +
        "S2_SELECTION_ELIGIBLE={10} S2_HELDOUT_REPETITION_PASSED={11} " +
        "UM1_EXPLORATORY_ALL_CELLS_PASSED={12} " +
        "UM1_HELDOUT_REPETITION_PASSED={13} UM2_SELECTION_ELIGIBLE={14} " +
        "UM2_HELDOUT_REPETITION_PASSED={15} UM3_SELECTION_ELIGIBLE={16} " +
        "UM3_HELDOUT_REPETITION_PASSED={17} UM4_SELECTION_ELIGIBLE={18} " +
        "UM4_HELDOUT_REPETITION_PASSED={19} UM5_SELECTION_ELIGIBLE={20} " +
        "UM5_HELDOUT_REPETITION_PASSED={21} UM6_SELECTION_ELIGIBLE={22} " +
        "UM6_HELDOUT_REPETITION_PASSED={23} UM7_SELECTION_ELIGIBLE={24} " +
        "UM7_HELDOUT_REPETITION_PASSED={25} UM8_SELECTION_ELIGIBLE={26} " +
        "UM8_HELDOUT_REPETITION_PASSED={27} UM9_SELECTION_ELIGIBLE={28} " +
        "UM9_HELDOUT_REPETITION_PASSED={29} UM10_SELECTION_ELIGIBLE={30} " +
        "UM10_HELDOUT_REPETITION_PASSED={31} TC2_ALL_HELDOUT_PASSED={32}"
    ) -f @(
            $campaignId,
            $FixtureVariationAxis,
            $exploratoryScanComplete,
            $totalAssertionsPassed,
            $totalAssertionsFailed,
            ($passingMasses -join ","),
            ($failingMasses -join ","),
            $boundaryObserved,
            $tc1SelectionEligible,
            $s1SelectionEligible,
            $s2SelectionEligible,
            $s2HeldOutRepetitionPassed,
            $um1ExploratoryAllCellsPassed,
            $um1HeldOutRepetitionPassed,
            $um2SelectionEligible,
            $um2HeldOutRepetitionPassed,
            $um3SelectionEligible,
            $um3HeldOutRepetitionPassed,
            $um4SelectionEligible,
            $um4HeldOutRepetitionPassed,
            $um5SelectionEligible,
            $um5HeldOutRepetitionPassed,
            $um6SelectionEligible,
            $um6HeldOutRepetitionPassed,
            $um7SelectionEligible,
            $um7HeldOutRepetitionPassed,
            $um8SelectionEligible,
            $um8HeldOutRepetitionPassed,
            $um9SelectionEligible,
            $um9HeldOutRepetitionPassed,
            $um10SelectionEligible,
            $um10HeldOutRepetitionPassed,
            $tc2ExploratoryAllHeldOutPassed
    )
)
if ($exploratoryScanComplete) {
    exit 0
}
exit 1
} finally {
    if ($suiteMutexAcquired) {
        $suiteMutex.ReleaseMutex()
    }
    $suiteMutex.Dispose()
}

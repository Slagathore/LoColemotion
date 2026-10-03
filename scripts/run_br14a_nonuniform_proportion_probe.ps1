#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [ValidateSet(
        "G3-GP1",
        "G3-GP2",
        "G3-GP3",
        "G3-GP4",
        "G3-GP5",
        "G4-GQ1",
        "G4-GQ2",
        "G4-GQ3",
        "G4-GQ4",
        "G4-GQ5",
        "G4-GQ6",
        "G4-GQ7",
        "G4-GQ8",
        "G4-GQ9",
        "G4-GQ10",
        "G4-GQ11",
        "G4-GQ12",
        "G4-GQ13",
        "G4-GQ14",
        "G4-GQ15"
    )]
    [string]$Campaign = "G3-GP1",
    [switch]$HeldOutValidation,
    [ValidateRange(1, 3)]
    [int]$HeldOutRepetition = 1,
    [string[]]$DevelopmentMorphologies = @(),
    [switch]$SdkNativeAuthority,
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_br14a_nonuniform_proportion_probe"
    ),
    [ValidateRange(1, 1800)]
    [int]$TestTimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"
if ($SdkNativeAuthority -and $Campaign -ne "G4-GQ15") {
    throw "SdkNativeAuthority is supported only for the G4-GQ15 campaign."
}
$selectionMorphologies = if ($Campaign -eq "G4-GQ15") {
    @(
        "gq15_generated_s157",
        "gq15_generated_s158",
        "gq15_generated_s159",
        "gq15_generated_s160",
        "gq15_generated_s161",
        "gq15_generated_s162",
        "gq15_generated_s163",
        "gq15_generated_s164",
        "gq15_generated_s165",
        "gq15_generated_s166",
        "gq15_generated_s167",
        "gq15_generated_s168"
    )
} elseif ($Campaign -eq "G4-GQ14") {
    @(
        "gq14_generated_s145",
        "gq14_generated_s146",
        "gq14_generated_s147",
        "gq14_generated_s148",
        "gq14_generated_s149",
        "gq14_generated_s150",
        "gq14_generated_s151",
        "gq14_generated_s152",
        "gq14_generated_s153",
        "gq14_generated_s154",
        "gq14_generated_s155",
        "gq14_generated_s156"
    )
} elseif ($Campaign -eq "G4-GQ13") {
    @(
        "gq13_generated_s133",
        "gq13_generated_s134",
        "gq13_generated_s135",
        "gq13_generated_s136",
        "gq13_generated_s137",
        "gq13_generated_s138",
        "gq13_generated_s139",
        "gq13_generated_s140",
        "gq13_generated_s141",
        "gq13_generated_s142",
        "gq13_generated_s143",
        "gq13_generated_s144"
    )
} elseif ($Campaign -eq "G4-GQ12") {
    @(
        "gq12_generated_s121",
        "gq12_generated_s122",
        "gq12_generated_s123",
        "gq12_generated_s124",
        "gq12_generated_s125",
        "gq12_generated_s126",
        "gq12_generated_s127",
        "gq12_generated_s128",
        "gq12_generated_s129",
        "gq12_generated_s130",
        "gq12_generated_s131",
        "gq12_generated_s132"
    )
} elseif ($Campaign -eq "G4-GQ11") {
    @(
        "gq11_generated_s109",
        "gq11_generated_s110",
        "gq11_generated_s111",
        "gq11_generated_s112",
        "gq11_generated_s113",
        "gq11_generated_s114",
        "gq11_generated_s115",
        "gq11_generated_s116",
        "gq11_generated_s117",
        "gq11_generated_s118",
        "gq11_generated_s119",
        "gq11_generated_s120"
    )
} elseif ($Campaign -eq "G4-GQ10") {
    @(
        "gq10_generated_s097",
        "gq10_generated_s098",
        "gq10_generated_s099",
        "gq10_generated_s100",
        "gq10_generated_s101",
        "gq10_generated_s102",
        "gq10_generated_s103",
        "gq10_generated_s104",
        "gq10_generated_s105",
        "gq10_generated_s106",
        "gq10_generated_s107",
        "gq10_generated_s108"
    )
} elseif ($Campaign -eq "G4-GQ9") {
    @(
        "gq9_generated_s085",
        "gq9_generated_s086",
        "gq9_generated_s087",
        "gq9_generated_s088",
        "gq9_generated_s089",
        "gq9_generated_s090",
        "gq9_generated_s091",
        "gq9_generated_s092",
        "gq9_generated_s093",
        "gq9_generated_s094",
        "gq9_generated_s095",
        "gq9_generated_s096"
    )
} elseif ($Campaign -eq "G4-GQ8") {
    @(
        "gq8_generated_s073",
        "gq8_generated_s074",
        "gq8_generated_s075",
        "gq8_generated_s076",
        "gq8_generated_s077",
        "gq8_generated_s078",
        "gq8_generated_s079",
        "gq8_generated_s080",
        "gq8_generated_s081",
        "gq8_generated_s082",
        "gq8_generated_s083",
        "gq8_generated_s084"
    )
} elseif ($Campaign -eq "G4-GQ7") {
    @(
        "gq7_generated_s061",
        "gq7_generated_s062",
        "gq7_generated_s063",
        "gq7_generated_s064",
        "gq7_generated_s065",
        "gq7_generated_s066",
        "gq7_generated_s067",
        "gq7_generated_s068",
        "gq7_generated_s069",
        "gq7_generated_s070",
        "gq7_generated_s071",
        "gq7_generated_s072"
    )
} elseif ($Campaign -eq "G4-GQ6") {
    @(
        "gq6_generated_s049",
        "gq6_generated_s050",
        "gq6_generated_s051",
        "gq6_generated_s052",
        "gq6_generated_s053",
        "gq6_generated_s054",
        "gq6_generated_s055",
        "gq6_generated_s056",
        "gq6_generated_s057",
        "gq6_generated_s058",
        "gq6_generated_s059",
        "gq6_generated_s060"
    )
} elseif ($Campaign -eq "G4-GQ5") {
    @(
        "gq5_generated_s037",
        "gq5_generated_s038",
        "gq5_generated_s039",
        "gq5_generated_s040",
        "gq5_generated_s041",
        "gq5_generated_s042",
        "gq5_generated_s043",
        "gq5_generated_s044",
        "gq5_generated_s045",
        "gq5_generated_s046",
        "gq5_generated_s047",
        "gq5_generated_s048"
    )
} elseif ($Campaign -eq "G4-GQ4") {
    @(
        "gq4_generated_s025",
        "gq4_generated_s026",
        "gq4_generated_s027",
        "gq4_generated_s028",
        "gq4_generated_s029",
        "gq4_generated_s030",
        "gq4_generated_s031",
        "gq4_generated_s032",
        "gq4_generated_s033",
        "gq4_generated_s034",
        "gq4_generated_s035",
        "gq4_generated_s036"
    )
} elseif ($Campaign -eq "G4-GQ3") {
    @(
        "gq3_generated_s013",
        "gq3_generated_s014",
        "gq3_generated_s015",
        "gq3_generated_s016",
        "gq3_generated_s017",
        "gq3_generated_s018",
        "gq3_generated_s019",
        "gq3_generated_s020",
        "gq3_generated_s021",
        "gq3_generated_s022",
        "gq3_generated_s023",
        "gq3_generated_s024"
    )
} elseif ($Campaign -eq "G4-GQ2") {
    @(
        "gq2_generated_s001",
        "gq2_generated_s002",
        "gq2_generated_s003",
        "gq2_generated_s004",
        "gq2_generated_s005",
        "gq2_generated_s006",
        "gq2_generated_s007",
        "gq2_generated_s008",
        "gq2_generated_s009",
        "gq2_generated_s010",
        "gq2_generated_s011",
        "gq2_generated_s012"
    )
} elseif ($Campaign -eq "G4-GQ1") {
    @(
        "gq1_generated_s001",
        "gq1_generated_s002",
        "gq1_generated_s003",
        "gq1_generated_s004",
        "gq1_generated_s005",
        "gq1_generated_s006",
        "gq1_generated_s007",
        "gq1_generated_s008",
        "gq1_generated_s009",
        "gq1_generated_s010",
        "gq1_generated_s011",
        "gq1_generated_s012"
    )
} elseif ($Campaign -eq "G3-GP5") {
    @(
        "gp5_reference",
        "gp5_torso_length_0p900",
        "gp5_torso_length_1p100",
        "gp5_torso_width_0p900",
        "gp5_torso_width_1p100",
        "gp5_upper_share_0p500",
        "gp5_upper_share_0p550",
        "gp5_hip_span_0p900",
        "gp5_hip_span_1p100",
        "gp5_foot_radius_0p975",
        "gp5_foot_radius_1p100",
        "gp5_front_mass_0p900",
        "gp5_front_mass_1p050"
    )
} elseif ($Campaign -eq "G3-GP4") {
    @(
        "gp4_reference",
        "gp4_torso_length_0p900",
        "gp4_torso_length_1p100",
        "gp4_torso_width_0p900",
        "gp4_torso_width_1p100",
        "gp4_upper_share_0p500",
        "gp4_upper_share_0p550",
        "gp4_hip_span_0p900",
        "gp4_hip_span_1p100",
        "gp4_foot_radius_0p975",
        "gp4_foot_radius_1p100",
        "gp4_front_mass_0p900",
        "gp4_front_mass_1p050"
    )
} elseif ($Campaign -eq "G3-GP3") {
    @(
        "gp3_reference",
        "gp3_torso_length_0p900",
        "gp3_torso_length_1p100",
        "gp3_torso_width_0p900",
        "gp3_torso_width_1p100",
        "gp3_upper_share_0p500",
        "gp3_upper_share_0p550",
        "gp3_hip_span_0p900",
        "gp3_hip_span_1p100",
        "gp3_foot_radius_0p975",
        "gp3_foot_radius_1p100",
        "gp3_front_mass_0p900",
        "gp3_front_mass_1p050"
    )
} elseif ($Campaign -eq "G3-GP2") {
    @(
        "gp2_reference",
        "gp2_torso_length_0p900",
        "gp2_torso_length_1p100",
        "gp2_torso_width_0p900",
        "gp2_torso_width_1p100",
        "gp2_upper_share_0p500",
        "gp2_upper_share_0p550",
        "gp2_hip_span_0p900",
        "gp2_hip_span_1p100",
        "gp2_foot_radius_0p975",
        "gp2_foot_radius_1p100",
        "gp2_front_mass_0p900",
        "gp2_front_mass_1p050"
    )
} else {
    @(
        "reference",
        "torso_length_0p900",
        "torso_length_1p100",
        "torso_width_0p900",
        "torso_width_1p100",
        "upper_share_0p480",
        "upper_share_0p550",
        "hip_span_0p900",
        "hip_span_1p100",
        "foot_radius_0p900",
        "foot_radius_1p100",
        "front_mass_0p900",
        "front_mass_1p100"
    )
}
$heldOutMorphologies = if ($Campaign -eq "G4-GQ15") {
    @(
        "gq15_generated_s1401",
        "gq15_generated_s1402",
        "gq15_generated_s1403",
        "gq15_generated_s1404",
        "gq15_generated_s1405",
        "gq15_generated_s1406",
        "gq15_generated_s1407",
        "gq15_generated_s1408"
    )
} elseif ($Campaign -eq "G4-GQ14") {
    @(
        "gq14_generated_s1301",
        "gq14_generated_s1302",
        "gq14_generated_s1303",
        "gq14_generated_s1304",
        "gq14_generated_s1305",
        "gq14_generated_s1306",
        "gq14_generated_s1307",
        "gq14_generated_s1308"
    )
} elseif ($Campaign -eq "G4-GQ13") {
    @(
        "gq13_generated_s1201",
        "gq13_generated_s1202",
        "gq13_generated_s1203",
        "gq13_generated_s1204",
        "gq13_generated_s1205",
        "gq13_generated_s1206",
        "gq13_generated_s1207",
        "gq13_generated_s1208"
    )
} elseif ($Campaign -eq "G4-GQ12") {
    @(
        "gq12_generated_s1101",
        "gq12_generated_s1102",
        "gq12_generated_s1103",
        "gq12_generated_s1104",
        "gq12_generated_s1105",
        "gq12_generated_s1106",
        "gq12_generated_s1107",
        "gq12_generated_s1108"
    )
} elseif ($Campaign -eq "G4-GQ11") {
    @(
        "gq11_generated_s1001",
        "gq11_generated_s1002",
        "gq11_generated_s1003",
        "gq11_generated_s1004",
        "gq11_generated_s1005",
        "gq11_generated_s1006",
        "gq11_generated_s1007",
        "gq11_generated_s1008"
    )
} elseif ($Campaign -eq "G4-GQ10") {
    @(
        "gq10_generated_s901",
        "gq10_generated_s902",
        "gq10_generated_s903",
        "gq10_generated_s904",
        "gq10_generated_s905",
        "gq10_generated_s906",
        "gq10_generated_s907",
        "gq10_generated_s908"
    )
} elseif ($Campaign -eq "G4-GQ9") {
    @(
        "gq9_generated_s801",
        "gq9_generated_s802",
        "gq9_generated_s803",
        "gq9_generated_s804",
        "gq9_generated_s805",
        "gq9_generated_s806",
        "gq9_generated_s807",
        "gq9_generated_s808"
    )
} elseif ($Campaign -eq "G4-GQ8") {
    @(
        "gq8_generated_s701",
        "gq8_generated_s702",
        "gq8_generated_s703",
        "gq8_generated_s704",
        "gq8_generated_s705",
        "gq8_generated_s706",
        "gq8_generated_s707",
        "gq8_generated_s708"
    )
} elseif ($Campaign -eq "G4-GQ7") {
    @(
        "gq7_generated_s601",
        "gq7_generated_s602",
        "gq7_generated_s603",
        "gq7_generated_s604",
        "gq7_generated_s605",
        "gq7_generated_s606",
        "gq7_generated_s607",
        "gq7_generated_s608"
    )
} elseif ($Campaign -eq "G4-GQ6") {
    @(
        "gq6_generated_s501",
        "gq6_generated_s502",
        "gq6_generated_s503",
        "gq6_generated_s504",
        "gq6_generated_s505",
        "gq6_generated_s506",
        "gq6_generated_s507",
        "gq6_generated_s508"
    )
} elseif ($Campaign -eq "G4-GQ5") {
    @(
        "gq5_generated_s401",
        "gq5_generated_s402",
        "gq5_generated_s403",
        "gq5_generated_s404",
        "gq5_generated_s405",
        "gq5_generated_s406",
        "gq5_generated_s407",
        "gq5_generated_s408"
    )
} elseif ($Campaign -eq "G4-GQ4") {
    @(
        "gq4_generated_s301",
        "gq4_generated_s302",
        "gq4_generated_s303",
        "gq4_generated_s304",
        "gq4_generated_s305",
        "gq4_generated_s306",
        "gq4_generated_s307",
        "gq4_generated_s308"
    )
} elseif ($Campaign -eq "G4-GQ3") {
    @(
        "gq3_generated_s201",
        "gq3_generated_s202",
        "gq3_generated_s203",
        "gq3_generated_s204",
        "gq3_generated_s205",
        "gq3_generated_s206",
        "gq3_generated_s207",
        "gq3_generated_s208"
    )
} elseif ($Campaign -eq "G4-GQ2") {
    @(
        "gq2_generated_s101",
        "gq2_generated_s102",
        "gq2_generated_s103",
        "gq2_generated_s104",
        "gq2_generated_s105",
        "gq2_generated_s106",
        "gq2_generated_s107",
        "gq2_generated_s108"
    )
} elseif ($Campaign -eq "G4-GQ1") {
    @(
        "gq1_generated_s101",
        "gq1_generated_s102",
        "gq1_generated_s103",
        "gq1_generated_s104",
        "gq1_generated_s105",
        "gq1_generated_s106",
        "gq1_generated_s107",
        "gq1_generated_s108"
    )
} elseif ($Campaign -eq "G3-GP5") {
    @("gp5_mixed_a", "gp5_mixed_b", "gp5_mixed_c", "gp5_mixed_d")
} elseif ($Campaign -eq "G3-GP4") {
    @("gp4_mixed_a", "gp4_mixed_b", "gp4_mixed_c", "gp4_mixed_d")
} elseif ($Campaign -eq "G3-GP3") {
    @("gp3_mixed_a", "gp3_mixed_b", "gp3_mixed_c", "gp3_mixed_d")
} elseif ($Campaign -eq "G3-GP2") {
    @("gp2_mixed_a", "gp2_mixed_b", "gp2_mixed_c", "gp2_mixed_d")
} else {
    @("mixed_a", "mixed_b", "mixed_c", "mixed_d")
}
$isGeneratedCampaign = (
    $Campaign -eq "G4-GQ1" -or
    $Campaign -eq "G4-GQ2" -or
    $Campaign -eq "G4-GQ3" -or
    $Campaign -eq "G4-GQ4" -or
    $Campaign -eq "G4-GQ5" -or
    $Campaign -eq "G4-GQ6" -or
    $Campaign -eq "G4-GQ7" -or
    $Campaign -eq "G4-GQ8" -or
    $Campaign -eq "G4-GQ9" -or
    $Campaign -eq "G4-GQ10" -or
    $Campaign -eq "G4-GQ11" -or
    $Campaign -eq "G4-GQ12" -or
    $Campaign -eq "G4-GQ13" -or
    $Campaign -eq "G4-GQ14" -or
    $Campaign -eq "G4-GQ15"
)
$expectedAssertionsPerCell = if ($SdkNativeAuthority) { 33 } else { 25 }
$expectedControllerSha256 = if (
    $Campaign -eq "G3-GP5" -or
    $Campaign -eq "G4-GQ1" -or
    $Campaign -eq "G4-GQ2" -or
    $Campaign -eq "G4-GQ3" -or
    $Campaign -eq "G4-GQ4" -or
    $Campaign -eq "G4-GQ5" -or
    $Campaign -eq "G4-GQ6" -or
    $Campaign -eq "G4-GQ7" -or
    $Campaign -eq "G4-GQ8" -or
    $Campaign -eq "G4-GQ9" -or
    $Campaign -eq "G4-GQ10" -or
    $Campaign -eq "G4-GQ11" -or
    $Campaign -eq "G4-GQ12" -or
    $Campaign -eq "G4-GQ13" -or
    $Campaign -eq "G4-GQ14" -or
    $Campaign -eq "G4-GQ15"
) {
    ""
} elseif (
    $Campaign -eq "G3-GP3" -or $Campaign -eq "G3-GP4"
) {
    "sha256:7e505e23b8c0967bf2702de3aa711986deca9cc5862284e6646e9a9bc7a61172"
} else {
    "sha256:9c6d7962e81da4d1831ac0a99999db46cd87ce3271600e0f8bb5a72beaed4ef6"
}
$solverPositionSteps = if (
    $Campaign -eq "G3-GP4" -or
    $Campaign -eq "G4-GQ6" -or
    $Campaign -eq "G4-GQ7" -or
    $Campaign -eq "G4-GQ8" -or
    $Campaign -eq "G4-GQ9" -or
    $Campaign -eq "G4-GQ10" -or
    $Campaign -eq "G4-GQ11" -or
    $Campaign -eq "G4-GQ12" -or
    $Campaign -eq "G4-GQ13" -or
    $Campaign -eq "G4-GQ14" -or
    $Campaign -eq "G4-GQ15"
) { 7 } else { 6 }
$campaignReceiptPattern = '\bcampaign=(G3-GP[1-5]|G4-GQ(?:[1-9]|1[0-5]))\b'
foreach (
    $campaignParserSelfCheck in @(
        "G3-GP5",
        "G4-GQ1",
        "G4-GQ2",
        "G4-GQ3",
        "G4-GQ4",
        "G4-GQ5",
        "G4-GQ6",
        "G4-GQ7",
        "G4-GQ8",
        "G4-GQ9",
        "G4-GQ10",
        "G4-GQ11",
        "G4-GQ12",
        "G4-GQ13",
        "G4-GQ14",
        "G4-GQ15"
    )
) {
    if (
        [regex]::Match(
            "campaign=$campaignParserSelfCheck",
            $campaignReceiptPattern
        ).Groups[1].Value -ne $campaignParserSelfCheck
    ) {
        throw "Campaign receipt parser does not recognize $campaignParserSelfCheck."
    }
}
$campaignRole = if ($HeldOutValidation) { "heldout" } else { "selection" }
$repetition = if ($HeldOutValidation) { $HeldOutRepetition } else { 0 }
$campaignId = if ($HeldOutValidation) {
    "$Campaign-HELDOUT-R$HeldOutRepetition"
} else {
    "$Campaign-SELECTION"
}
$morphologies = if ($HeldOutValidation) {
    $heldOutMorphologies
} else {
    $selectionMorphologies
}
$DevelopmentMorphologies = @(
    $DevelopmentMorphologies |
        ForEach-Object { $_ -split "," } |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
)
$developmentSubsetUsed = $DevelopmentMorphologies.Count -gt 0
if ($developmentSubsetUsed) {
    $unknownDevelopmentMorphologies = @(
        $DevelopmentMorphologies |
            Where-Object { $_ -notin $morphologies } |
            Sort-Object -Unique
    )
    if ($unknownDevelopmentMorphologies.Count -gt 0) {
        throw (
            "DevelopmentMorphologies contains cells outside the selected " +
            "campaign role: " +
            ($unknownDevelopmentMorphologies -join ", ")
        )
    }
    $morphologies = @($DevelopmentMorphologies)
}

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$godotPath = [System.IO.Path]::GetFullPath($Godot)
$processRunner = Join-Path $PSScriptRoot "process_runner.ps1"
$testRelativePath = (
    "tests\" +
    "test_experimental_br14a_11_physical_wave_gait_nonuniform_proportion_probe.gd"
)
$compilerTestRelativePath = (
    "tests\test_experimental_br14a_10_nonuniform_proportion_compilers.gd"
)
$runnerRelativePath = "scripts\run_br14a_nonuniform_proportion_probe.ps1"
$preregistrationRelativePath = (
    "docs\BR14A_QUADRUPED_GENERALIZATION_BOOTSTRAP.md"
)
$sdkPreregistrationRelativePath = (
    "docs\ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md"
)
$sdkNativeBinaryRelativePath = (
    "sdk\target\debug\sporespore_godot_adapter.dll"
)
$sourceRelativePaths = @(
    $preregistrationRelativePath,
    "scripts\lab\gait\physical_wave_gait_quadruped.gd",
    "scripts\lab\gait\physical_quadruped_fixture_spec.gd",
    "scripts\lab\gait\physical_quadruped_proportion_spec.gd",
    "scripts\lab\gait\physical_gait_clock_spec.gd",
    "scripts\lab\gait\morphology_feature_receipt.gd",
    "scripts\lab\gait\morphology_coverage_receipt.gd",
    "scripts\lab\mechanics\spatial_dynamic_support_observer.gd",
    "scripts\lab\mechanics\dynamic_support_diagnostic_receipt.gd",
    "scripts\lab\mechanics\semantic_contact_rigid_body.gd",
    "scripts\lab\canonical_json.gd",
    "scripts\lab\finite_sanitizer.gd",
    "scripts\process_runner.ps1",
    "scripts\process_runner_containment_host.ps1",
    $compilerTestRelativePath,
    $testRelativePath,
    $runnerRelativePath
)
if ($SdkNativeAuthority) {
    $sourceRelativePaths += @(
        $sdkPreregistrationRelativePath,
        "scripts\lab\gait\sdk_godot_jolt_adapter.gd",
        "sdk\Cargo.toml",
        "sdk\Cargo.lock",
        "sdk\core\Cargo.toml",
        "sdk\core\src\canonical.rs",
        "sdk\core\src\controller.rs",
        "sdk\core\src\coverage.rs",
        "sdk\core\src\ffi.rs",
        "sdk\core\src\lib.rs",
        "sdk\core\src\protocol.rs",
        "sdk\core\src\quadruped.rs",
        "sdk\core\src\runtime.rs",
        "sdk\core\src\scheduler.rs",
        "sdk\core\src\schema.rs",
        "sdk\adapters\godot\Cargo.toml",
        "sdk\adapters\godot\src\lib.rs",
        "sdk\adapters\godot\sporespore_locomotion.gdextension",
        "sdk\include\sporespore_locomotion.h",
        "sdk\conformance\golden\candidate35_gq15_v1.json",
        "sdk\tests\test_godot_jolt_phase_offset_authority.gd",
        "sdk\run_godot_jolt_c6_campaign.ps1",
        $sdkNativeBinaryRelativePath
    )
    $sourceRelativePaths = @($sourceRelativePaths | Sort-Object -Unique)
}

if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable not found: $godotPath"
}
if (-not (Test-Path -LiteralPath $processRunner -PathType Leaf)) {
    throw "Process runner not found: $processRunner"
}
if ($SdkNativeAuthority) {
    Push-Location (Join-Path $repoRoot "sdk")
    try {
        & cargo build -p sporespore-godot-adapter --offline
        if ($LASTEXITCODE -ne 0) {
            throw "The Godot SDK adapter build failed."
        }
    } finally {
        Pop-Location
    }
}
. $processRunner
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

    $runStamp = Get-Date -Format "yyyyMMddTHHmmssfff"
    $campaignRoot = Join-Path (
        [System.IO.Path]::GetFullPath($LogRoot)
    ) $runStamp
    [void][System.IO.Directory]::CreateDirectory($campaignRoot)
    $sourceSnapshotRoot = Join-Path $campaignRoot "_source_snapshot"
    [void][System.IO.Directory]::CreateDirectory($sourceSnapshotRoot)

    Push-Location $repoRoot
    try {
        $sourceCommit = (& git rev-parse HEAD).Trim()
        if (
            $LASTEXITCODE -ne 0 -or
            [string]::IsNullOrWhiteSpace($sourceCommit)
        ) {
            throw "Unable to resolve the source commit."
        }
        $scopedStatus = @(
            & git status --porcelain=v1 -- @sourceRelativePaths
        )
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to inspect scoped source status."
        }
    } finally {
        Pop-Location
    }

    $sourceHashes = [ordered]@{}
    foreach ($relativePath in $sourceRelativePaths) {
        $sourcePath = Join-Path $repoRoot $relativePath
        $normalizedRelativePath = $relativePath.Replace("\", "/")
        $sourceHash = Get-FileHash `
            -LiteralPath $sourcePath `
            -Algorithm SHA256
        $sourceDigest = "sha256:" + $sourceHash.Hash.ToLowerInvariant()
        $sourceHashes[$normalizedRelativePath] = $sourceDigest
        $snapshotPath = Join-Path $sourceSnapshotRoot $relativePath
        [void][System.IO.Directory]::CreateDirectory(
            (Split-Path -Parent $snapshotPath)
        )
        Copy-Item `
            -LiteralPath $sourcePath `
            -Destination $snapshotPath `
            -Force
        $snapshotHash = Get-FileHash `
            -LiteralPath $snapshotPath `
            -Algorithm SHA256
        $snapshotDigest = "sha256:" + $snapshotHash.Hash.ToLowerInvariant()
        if ($snapshotDigest -ne $sourceDigest) {
            throw (
                "Source changed while creating immutable snapshot: " +
                $relativePath
            )
        }
    }
    $godotHash = Get-FileHash `
        -LiteralPath $godotPath `
        -Algorithm SHA256

$projectText = @'
; Isolated SporeSpore BR14A.11 nonuniform-proportion probe.

config_version=5

[application]

config/name="sporespore-br14a-nonuniform-proportion-probe"
config/features=PackedStringArray("4.7", "Forward Plus")

[debug]

gdscript/warnings/shadowed_global_identifier=0

[physics]

3d/physics_engine="Jolt Physics"
jolt_physics_3d/simulation/velocity_steps=20
jolt_physics_3d/simulation/position_steps=__SOLVER_POSITION_STEPS__
'@
$projectText = $projectText.Replace(
    "__SOLVER_POSITION_STEPS__",
    [string]$solverPositionSteps
)

    $results = @()
    foreach ($morphologyId in $morphologies) {
        $runRoot = Join-Path $campaignRoot $morphologyId
        [void][System.IO.Directory]::CreateDirectory($runRoot)
        [System.IO.File]::WriteAllText(
            (Join-Path $runRoot "project.godot"),
            $projectText,
            [System.Text.UTF8Encoding]::new($false)
        )
        foreach ($relativePath in $sourceRelativePaths) {
            $destination = Join-Path $runRoot $relativePath
            [void][System.IO.Directory]::CreateDirectory(
                (Split-Path -Parent $destination)
            )
            Copy-Item `
                -LiteralPath (Join-Path $sourceSnapshotRoot $relativePath) `
                -Destination $destination `
                -Force
        }
        $appData = Join-Path $runRoot "worker\appdata"
        $localAppData = Join-Path $runRoot "worker\localappdata"
        [void][System.IO.Directory]::CreateDirectory($appData)
        [void][System.IO.Directory]::CreateDirectory($localAppData)
        $transcriptPath = Join-Path $runRoot "transcript.log"
        $engineLogPath = Join-Path $runRoot "godot.log"
        $previousAppData = $env:APPDATA
        $previousLocalAppData = $env:LOCALAPPDATA
        try {
            $env:APPDATA = $appData
            $env:LOCALAPPDATA = $localAppData
            $godotArguments = @(
                "--headless",
                "--path",
                $runRoot,
                "--script",
                "res://$($testRelativePath.Replace('\', '/'))",
                "--log-file",
                $engineLogPath,
                "--",
                $Campaign,
                $morphologyId,
                $campaignRole,
                $repetition.ToString(
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
            )
            if ($SdkNativeAuthority) {
                $godotArguments += "sdk-native-authority"
            }
            $invocation = Invoke-ProcessWithTimeout `
                -FilePath $godotPath `
                -ArgumentList $godotArguments `
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
            '(?m)^NONUNIFORM_PROPORTION_RESULT .*$'
        )
        $resultLine = if ($resultMatches.Count -eq 1) {
            $resultMatches[0].Value
        } else {
            ""
        }
        $campaignMatch = [regex]::Match(
            $resultLine,
            $campaignReceiptPattern
        )
        $morphologyMatch = [regex]::Match(
            $resultLine,
            '\bmorphology=([a-z0-9_]+)\b'
        )
        $roleMatch = [regex]::Match(
            $resultLine,
            '\brole=([a-z0-9_]+)\b'
        )
        $repetitionMatch = [regex]::Match(
            $resultLine,
            '\brepetition=(\d+)\b'
        )
        $walkingMatch = [regex]::Match(
            $resultLine,
            '\bwalking=(true|false)\b'
        )
        $policyMatch = [regex]::Match(
            $resultLine,
            '\bpolicy_digest=(sha256:[0-9a-f]{64})\b'
        )
        $parameterMatch = [regex]::Match(
            $resultLine,
            '\bparameter_digest=(sha256:[0-9a-f]{64})\b'
        )
        $fixtureMatch = [regex]::Match(
            $resultLine,
            '\bfixture_digest=(sha256:[0-9a-f]{64})\b'
        )
        $staticMatch = [regex]::Match(
            $resultLine,
            '\bstatic_digest=(sha256:[0-9a-f]{64})\b'
        )
        $controllerMatch = [regex]::Match(
            $resultLine,
            '\bcontroller_digest=(sha256:[0-9a-f]{64})\b'
        )
        $thresholdMatch = [regex]::Match(
            $resultLine,
            '\bthreshold_digest=(sha256:[0-9a-f]{64})\b'
        )
        $interactionScoreMatch = [regex]::Match(
            $resultLine,
            '\binteraction_score=([-+0-9.eE]+)\b'
        )
        $generationDigestMatch = [regex]::Match(
            $resultLine,
            '\bgenerator_digest=(sha256:[0-9a-f]{64})\b'
        )
        $featureDigestMatch = [regex]::Match(
            $resultLine,
            '\bfeature_digest=(sha256:[0-9a-f]{64})\b'
        )
        $coverageDigestMatch = [regex]::Match(
            $resultLine,
            '\bcoverage_digest=(sha256:[0-9a-f]{64})\b'
        )
        $coverageStatusMatch = [regex]::Match(
            $resultLine,
            '\bcoverage_status=(SUPPORTED|EDGE|OUT_OF_DISTRIBUTION)\b'
        )
        $dynamicSupportDigestMatch = [regex]::Match(
            $resultLine,
            '\bdynamic_support_digest=(sha256:[0-9a-f]{64})\b'
        )
        $dynamicSupportSamplesMatch = [regex]::Match(
            $resultLine,
            '\bdynamic_support_samples=(\d+)\b'
        )
        $evidenceMatch = [regex]::Match(
            $resultLine,
            '\bevidence=\(([-+0-9.eE]+),([-+0-9.eE]+),([-+0-9.eE]+)\)'
        )
        $finalMatch = [regex]::Match(
            $resultLine,
            '\bfinal=\(([-+0-9.eE]+),([-+0-9.eE]+),([-+0-9.eE]+)\)'
        )
        $anchorMatch = [regex]::Match(
            $resultLine,
            '\banchor=([-+0-9.eE]+)\b'
        )
        $hingeMatch = [regex]::Match(
            $resultLine,
            '\bhinge=([-+0-9.eE]+)\b'
        )
        $heightMatch = [regex]::Match(
            $resultLine,
            '\bheight=([-+0-9.eE]+)\b'
        )
        $supportMatch = [regex]::Match(
            $resultLine,
            '\bsupport_margin=([-+0-9.eE]+)\b'
        )
        $sdkNativeAuthorityMatch = [regex]::Match(
            $resultLine,
            '\bsdk_native_authority=(true|false)\b'
        )
        $sdkOkMatch = [regex]::Match(
            $resultLine,
            '\bsdk_ok=(true|false)\b'
        )
        $sdkStepsMatch = [regex]::Match(
            $resultLine,
            '\bsdk_steps=(-?\d+)\b'
        )
        $sdkComparedCommandsMatch = [regex]::Match(
            $resultLine,
            '\bsdk_compared_commands=(-?\d+)\b'
        )
        $sdkNativeCommandsMatch = [regex]::Match(
            $resultLine,
            '\bsdk_native_commands=(-?\d+)\b'
        )
        $sdkLegacyPostSettleMatch = [regex]::Match(
            $resultLine,
            '\bsdk_legacy_post_settle=(-?\d+)\b'
        )
        $sdkLegacyEvidenceMatch = [regex]::Match(
            $resultLine,
            '\bsdk_legacy_evidence=(-?\d+)\b'
        )
        $sdkMismatchesMatch = [regex]::Match(
            $resultLine,
            '\bsdk_mismatches=(-?\d+)\b'
        )
        $sdkSafeNoActuationMatch = [regex]::Match(
            $resultLine,
            '\bsdk_safe_no_actuation=(-?\d+)\b'
        )
        $sdkSafeDisablesMatch = [regex]::Match(
            $resultLine,
            '\bsdk_safe_disables=(-?\d+)\b'
        )
        $sdkPhaseErrorMatch = [regex]::Match(
            $resultLine,
            '\bsdk_phase_error_steps=(-?\d+)\b'
        )
        $sdkPositionErrorMatch = [regex]::Match(
            $resultLine,
            '\bsdk_position_error_rad=([-+0-9.eE]+)\b'
        )
        $sdkVelocityErrorMatch = [regex]::Match(
            $resultLine,
            '\bsdk_velocity_error_rad_s=([-+0-9.eE]+)\b'
        )
        $sdkSpeedLimitErrorMatch = [regex]::Match(
            $resultLine,
            '\bsdk_speed_limit_error_rad_s=([-+0-9.eE]+)\b'
        )
        $sdkSteeringErrorMatch = [regex]::Match(
            $resultLine,
            '\bsdk_steering_error=([-+0-9.eE]+)\b'
        )
        $sdkCapabilityHashMatch = [regex]::Match(
            $resultLine,
            '\bsdk_capability_hash=(sha256:[0-9a-f]{64})\b'
        )
        $sdkNumericMatchesComplete = (
            $sdkPositionErrorMatch.Success -and
            $sdkVelocityErrorMatch.Success -and
            $sdkSpeedLimitErrorMatch.Success -and
            $sdkSteeringErrorMatch.Success
        )
        $sdkPositionError = if ($sdkPositionErrorMatch.Success) {
            [double]::Parse(
                $sdkPositionErrorMatch.Groups[1].Value,
                [System.Globalization.CultureInfo]::InvariantCulture
            )
        } else { [double]::NaN }
        $sdkVelocityError = if ($sdkVelocityErrorMatch.Success) {
            [double]::Parse(
                $sdkVelocityErrorMatch.Groups[1].Value,
                [System.Globalization.CultureInfo]::InvariantCulture
            )
        } else { [double]::NaN }
        $sdkSpeedLimitError = if ($sdkSpeedLimitErrorMatch.Success) {
            [double]::Parse(
                $sdkSpeedLimitErrorMatch.Groups[1].Value,
                [System.Globalization.CultureInfo]::InvariantCulture
            )
        } else { [double]::NaN }
        $sdkSteeringError = if ($sdkSteeringErrorMatch.Success) {
            [double]::Parse(
                $sdkSteeringErrorMatch.Groups[1].Value,
                [System.Globalization.CultureInfo]::InvariantCulture
            )
        } else { [double]::NaN }
        $sdkReceiptComplete = (
            -not $SdkNativeAuthority -or
            (
                $sdkNativeAuthorityMatch.Success -and
                $sdkNativeAuthorityMatch.Groups[1].Value -eq "true" -and
                $sdkOkMatch.Success -and
                $sdkOkMatch.Groups[1].Value -eq "true" -and
                $sdkStepsMatch.Success -and
                [int]$sdkStepsMatch.Groups[1].Value -gt 0 -and
                $sdkComparedCommandsMatch.Success -and
                [int]$sdkComparedCommandsMatch.Groups[1].Value -eq (
                    [int]$sdkStepsMatch.Groups[1].Value * 8
                ) -and
                $sdkNativeCommandsMatch.Success -and
                [int]$sdkNativeCommandsMatch.Groups[1].Value -eq (
                    [int]$sdkStepsMatch.Groups[1].Value * 8
                ) -and
                $sdkLegacyPostSettleMatch.Success -and
                [int]$sdkLegacyPostSettleMatch.Groups[1].Value -eq 0 -and
                $sdkLegacyEvidenceMatch.Success -and
                [int]$sdkLegacyEvidenceMatch.Groups[1].Value -eq 0 -and
                $sdkMismatchesMatch.Success -and
                [int]$sdkMismatchesMatch.Groups[1].Value -eq 0 -and
                $sdkSafeNoActuationMatch.Success -and
                [int]$sdkSafeNoActuationMatch.Groups[1].Value -eq 0 -and
                $sdkSafeDisablesMatch.Success -and
                [int]$sdkSafeDisablesMatch.Groups[1].Value -eq 0 -and
                $sdkPhaseErrorMatch.Success -and
                [int]$sdkPhaseErrorMatch.Groups[1].Value -eq 0 -and
                $sdkNumericMatchesComplete -and
                $sdkPositionError -le 2.0e-8 -and
                $sdkVelocityError -le 2.5e-7 -and
                $sdkSpeedLimitError -le 1.0e-12 -and
                $sdkSteeringError -le 2.0e-8 -and
                $sdkCapabilityHashMatch.Success
            )
        )
        $receiptComplete = (
            $campaignMatch.Success -and
            $morphologyMatch.Success -and
            $roleMatch.Success -and
            $repetitionMatch.Success -and
            $walkingMatch.Success -and
            $policyMatch.Success -and
            $parameterMatch.Success -and
            $fixtureMatch.Success -and
            $staticMatch.Success -and
            $controllerMatch.Success -and
            $thresholdMatch.Success -and
            $evidenceMatch.Success -and
            $finalMatch.Success -and
            $anchorMatch.Success -and
            $hingeMatch.Success -and
            $heightMatch.Success -and
            $supportMatch.Success -and
            (
                -not $isGeneratedCampaign -or
                (
                    $interactionScoreMatch.Success -and
                    $generationDigestMatch.Success
                )
            ) -and
            (
                (
                    $Campaign -ne "G4-GQ13" -and
                    $Campaign -ne "G4-GQ14" -and
                    $Campaign -ne "G4-GQ15"
                ) -or
                (
                    $featureDigestMatch.Success -and
                    $coverageDigestMatch.Success -and
                    $coverageStatusMatch.Success -and
                    $dynamicSupportDigestMatch.Success -and
                    $dynamicSupportSamplesMatch.Success -and
                    [int]$dynamicSupportSamplesMatch.Groups[1].Value -gt 0
                )
            ) -and
            $sdkReceiptComplete
        )
        $walking = (
            $walkingMatch.Success -and
            $walkingMatch.Groups[1].Value -eq "true"
        )
        $controllerDigestAccepted = (
            $Campaign -eq "G3-GP5" -or
            $Campaign -eq "G4-GQ1" -or
            $Campaign -eq "G4-GQ2" -or
            $Campaign -eq "G4-GQ3" -or
            $Campaign -eq "G4-GQ4" -or
            $Campaign -eq "G4-GQ5" -or
            $Campaign -eq "G4-GQ6" -or
            $Campaign -eq "G4-GQ7" -or
            $Campaign -eq "G4-GQ8" -or
            $Campaign -eq "G4-GQ9" -or
            $Campaign -eq "G4-GQ10" -or
            $Campaign -eq "G4-GQ11" -or
            $Campaign -eq "G4-GQ12" -or
            $Campaign -eq "G4-GQ13" -or
            $Campaign -eq "G4-GQ14" -or
            $Campaign -eq "G4-GQ15" -or
            $controllerMatch.Groups[1].Value -eq $expectedControllerSha256
        )
        $harnessPassed = (
            -not $invocation.TimedOut -and
            $invocation.ExitCode -eq 0 -and
            $invocation.ContainmentTreeClosed -and
            -not $invocation.KilledProcessTree -and
            $footerMatches.Count -eq 1 -and
            $assertionsPassed -eq $expectedAssertionsPerCell -and
            $assertionsFailed -eq 0 -and
            $engineErrors.Count -eq 0 -and
            $resultMatches.Count -eq 1 -and
            $receiptComplete -and
            $campaignMatch.Groups[1].Value -eq $Campaign -and
            $morphologyMatch.Groups[1].Value -eq $morphologyId -and
            $roleMatch.Groups[1].Value -eq $campaignRole -and
            [int]$repetitionMatch.Groups[1].Value -eq $repetition -and
            $controllerDigestAccepted
        )
        $transcriptSha256 = if (
            Test-Path -LiteralPath $transcriptPath -PathType Leaf
        ) {
            "sha256:" + (
                Get-FileHash `
                    -LiteralPath $transcriptPath `
                    -Algorithm SHA256
            ).Hash.ToLowerInvariant()
        } else {
            ""
        }
        $engineLogSha256 = if ($engineLogExists) {
            "sha256:" + (
                Get-FileHash `
                    -LiteralPath $engineLogPath `
                    -Algorithm SHA256
            ).Hash.ToLowerInvariant()
        } else {
            ""
        }

        $results += [ordered]@{
            campaign_id = $Campaign
            morphology_id = $morphologyId
            campaign_role = $campaignRole
            held_out_repetition = $repetition
            harness_passed = $harnessPassed
            walking_observed = $walking
            timed_out = $invocation.TimedOut
            process_exit_code = $invocation.ExitCode
            killed_process_tree = $invocation.KilledProcessTree
            containment_tree_closed = $invocation.ContainmentTreeClosed
            assertions_passed = $assertionsPassed
            assertions_failed = $assertionsFailed
            engine_errors = $engineErrors
            policy_sha256 = if ($policyMatch.Success) {
                $policyMatch.Groups[1].Value
            } else { "" }
            proportion_spec_sha256 = if ($parameterMatch.Success) {
                $parameterMatch.Groups[1].Value
            } else { "" }
            fixture_spec_sha256 = if ($fixtureMatch.Success) {
                $fixtureMatch.Groups[1].Value
            } else { "" }
            static_screen_sha256 = if ($staticMatch.Success) {
                $staticMatch.Groups[1].Value
            } else { "" }
            controller_configuration_sha256 = if (
                $controllerMatch.Success
            ) {
                $controllerMatch.Groups[1].Value
            } else { "" }
            evidence_threshold_sha256 = if ($thresholdMatch.Success) {
                $thresholdMatch.Groups[1].Value
            } else { "" }
            morphology_interaction_score = if (
                $interactionScoreMatch.Success
            ) {
                [double]::Parse(
                    $interactionScoreMatch.Groups[1].Value,
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
            } else { $null }
            generator_receipt_sha256 = if (
                $generationDigestMatch.Success
            ) {
                $generationDigestMatch.Groups[1].Value
            } else { "" }
            morphology_feature_receipt_sha256 = if (
                $featureDigestMatch.Success
            ) {
                $featureDigestMatch.Groups[1].Value
            } else { "" }
            morphology_coverage_receipt_sha256 = if (
                $coverageDigestMatch.Success
            ) {
                $coverageDigestMatch.Groups[1].Value
            } else { "" }
            morphology_coverage_status = if (
                $coverageStatusMatch.Success
            ) {
                $coverageStatusMatch.Groups[1].Value
            } else { "" }
            dynamic_support_receipt_sha256 = if (
                $dynamicSupportDigestMatch.Success
            ) {
                $dynamicSupportDigestMatch.Groups[1].Value
            } else { "" }
            dynamic_support_sample_count = if (
                $dynamicSupportSamplesMatch.Success
            ) {
                [int]$dynamicSupportSamplesMatch.Groups[1].Value
            } else { 0 }
            evidence_forward_m = if ($evidenceMatch.Success) {
                [double]::Parse(
                    $evidenceMatch.Groups[1].Value,
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
            } else { [double]::NaN }
            final_forward_m = if ($finalMatch.Success) {
                [double]::Parse(
                    $finalMatch.Groups[1].Value,
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
            } else { [double]::NaN }
            final_lateral_m = if ($finalMatch.Success) {
                [double]::Parse(
                    $finalMatch.Groups[3].Value,
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
            } else { [double]::NaN }
            maximum_anchor_error_m = if ($anchorMatch.Success) {
                [double]::Parse(
                    $anchorMatch.Groups[1].Value,
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
            } else { [double]::NaN }
            maximum_hinge_axis_error_rad = if ($hingeMatch.Success) {
                [double]::Parse(
                    $hingeMatch.Groups[1].Value,
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
            } else { [double]::NaN }
            minimum_torso_height_m = if ($heightMatch.Success) {
                [double]::Parse(
                    $heightMatch.Groups[1].Value,
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
            } else { [double]::NaN }
            minimum_support_polygon_margin_m = if ($supportMatch.Success) {
                [double]::Parse(
                    $supportMatch.Groups[1].Value,
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
            } else { [double]::NaN }
            sdk_native_authority = [bool]$SdkNativeAuthority
            sdk_c6_confirmed = (
                $SdkNativeAuthority -and
                $sdkReceiptComplete -and
                $harnessPassed -and
                $walking
            )
            sdk_step_count = if ($sdkStepsMatch.Success) {
                [int]$sdkStepsMatch.Groups[1].Value
            } else { 0 }
            sdk_compared_command_count = if (
                $sdkComparedCommandsMatch.Success
            ) {
                [int]$sdkComparedCommandsMatch.Groups[1].Value
            } else { 0 }
            sdk_native_command_count = if ($sdkNativeCommandsMatch.Success) {
                [int]$sdkNativeCommandsMatch.Groups[1].Value
            } else { 0 }
            sdk_legacy_post_settle_command_count = if (
                $sdkLegacyPostSettleMatch.Success
            ) {
                [int]$sdkLegacyPostSettleMatch.Groups[1].Value
            } else { 0 }
            sdk_legacy_evidence_command_count = if (
                $sdkLegacyEvidenceMatch.Success
            ) {
                [int]$sdkLegacyEvidenceMatch.Groups[1].Value
            } else { 0 }
            sdk_mismatch_count = if ($sdkMismatchesMatch.Success) {
                [int]$sdkMismatchesMatch.Groups[1].Value
            } else { 0 }
            sdk_safe_no_actuation_count = if (
                $sdkSafeNoActuationMatch.Success
            ) {
                [int]$sdkSafeNoActuationMatch.Groups[1].Value
            } else { 0 }
            sdk_safe_disable_count = if ($sdkSafeDisablesMatch.Success) {
                [int]$sdkSafeDisablesMatch.Groups[1].Value
            } else { 0 }
            sdk_maximum_phase_error_steps = if (
                $sdkPhaseErrorMatch.Success
            ) {
                [int]$sdkPhaseErrorMatch.Groups[1].Value
            } else { 0 }
            sdk_maximum_position_error_rad = $sdkPositionError
            sdk_maximum_velocity_error_rad_s = $sdkVelocityError
            sdk_maximum_speed_limit_error_rad_s = $sdkSpeedLimitError
            sdk_maximum_steering_error = $sdkSteeringError
            sdk_adapter_capability_sha256 = if (
                $sdkCapabilityHashMatch.Success
            ) {
                $sdkCapabilityHashMatch.Groups[1].Value
            } else { "" }
            result_receipt = $resultLine
            transcript_sha256 = $transcriptSha256
            engine_log_sha256 = $engineLogSha256
            run_root = $runRoot
        }
        Write-Output (
            "morphology=$morphologyId harness=$harnessPassed " +
            "walking=$walking assertions=$assertionsPassed/" +
            "$assertionsFailed errors=$($engineErrors.Count)"
        )
    }

    $policyDigests = @(
        $results.policy_sha256 |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
    $parameterDigests = @(
        $results.proportion_spec_sha256 |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
    $fixtureDigests = @(
        $results.fixture_spec_sha256 |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
    $staticDigests = @(
        $results.static_screen_sha256 |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
    $controllerDigests = @(
        $results.controller_configuration_sha256 |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
    $generationDigests = @(
        $results.generator_receipt_sha256 |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
    $featureDigests = @(
        $results.morphology_feature_receipt_sha256 |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
    $coverageDigests = @(
        $results.morphology_coverage_receipt_sha256 |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
    $coverageStatuses = @(
        $results.morphology_coverage_status |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
    $dynamicSupportDigests = @(
        $results.dynamic_support_receipt_sha256 |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
    $sdkCapabilityDigests = @(
        $results.sdk_adapter_capability_sha256 |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
    $sdkReceiptSetExact = (
        -not $SdkNativeAuthority -or
        (
            $sdkCapabilityDigests.Count -eq 1 -and
            @(
                $results |
                    Where-Object { -not $_.sdk_c6_confirmed }
            ).Count -eq 0
        )
    )
    $controllerDigestSetExact = if ($isGeneratedCampaign) {
        $controllerDigests.Count -ge 2
    } else {
        $controllerDigests.Count -eq 1 -and
        (
            $Campaign -eq "G3-GP5" -or
            $controllerDigests[0] -eq $expectedControllerSha256
        )
    }
    $generationDigestSetExact = (
        -not $isGeneratedCampaign -or
        $generationDigests.Count -eq $morphologies.Count
    )
    $diagnosticDigestSetsExact = (
        (
            $Campaign -ne "G4-GQ13" -and
            $Campaign -ne "G4-GQ14" -and
            $Campaign -ne "G4-GQ15"
        ) -or
        (
            $featureDigests.Count -eq $morphologies.Count -and
            $coverageDigests.Count -eq $morphologies.Count -and
            $dynamicSupportDigests.Count -eq $morphologies.Count -and
            $coverageStatuses.Count -ge 1 -and
            @(
                $results |
                    Where-Object { [int]$_.dynamic_support_sample_count -le 0 }
            ).Count -eq 0
        )
    )
    $allCellsPassed = (
        $scopedStatus.Count -eq 0 -and
        $results.Count -eq $morphologies.Count -and
        @(
            $results |
                Where-Object {
                    -not $_.harness_passed -or
                    -not $_.walking_observed
                }
        ).Count -eq 0 -and
        $policyDigests.Count -eq 1 -and
        $parameterDigests.Count -eq $morphologies.Count -and
        $fixtureDigests.Count -eq $morphologies.Count -and
        $staticDigests.Count -eq $morphologies.Count -and
        $controllerDigestSetExact -and
        $generationDigestSetExact -and
        $diagnosticDigestSetsExact -and
        $sdkReceiptSetExact
    )
    $totalAssertionsPassed = (
        $results |
            ForEach-Object { [int]$_.assertions_passed } |
            Measure-Object -Sum
    ).Sum
    $totalAssertionsFailed = (
        $results |
            ForEach-Object { [int]$_.assertions_failed } |
            Measure-Object -Sum
    ).Sum
    $reportSchemaVersion = if ($SdkNativeAuthority) {
        "sporespore_sdk_godot_jolt_c6_phase_report_v1"
    } elseif ($Campaign -eq "G4-GQ15") {
        "sporespore_br14a_nonuniform_proportion_probe_report_v20"
    } elseif ($Campaign -eq "G4-GQ14") {
        "sporespore_br14a_nonuniform_proportion_probe_report_v19"
    } elseif ($Campaign -eq "G4-GQ13") {
        "sporespore_br14a_nonuniform_proportion_probe_report_v18"
    } elseif ($Campaign -eq "G4-GQ12") {
        "sporespore_br14a_nonuniform_proportion_probe_report_v17"
    } elseif ($Campaign -eq "G4-GQ11") {
        "sporespore_br14a_nonuniform_proportion_probe_report_v16"
    } elseif ($Campaign -eq "G4-GQ10") {
        "sporespore_br14a_nonuniform_proportion_probe_report_v15"
    } elseif ($Campaign -eq "G4-GQ9") {
        "sporespore_br14a_nonuniform_proportion_probe_report_v14"
    } elseif ($Campaign -eq "G4-GQ8") {
        "sporespore_br14a_nonuniform_proportion_probe_report_v13"
    } elseif ($Campaign -eq "G4-GQ7") {
        "sporespore_br14a_nonuniform_proportion_probe_report_v12"
    } elseif ($Campaign -eq "G4-GQ6") {
        "sporespore_br14a_nonuniform_proportion_probe_report_v11"
    } elseif ($Campaign -eq "G4-GQ5") {
        "sporespore_br14a_nonuniform_proportion_probe_report_v10"
    } elseif ($Campaign -eq "G4-GQ4") {
        "sporespore_br14a_nonuniform_proportion_probe_report_v9"
    } elseif ($Campaign -eq "G4-GQ3") {
        "sporespore_br14a_nonuniform_proportion_probe_report_v8"
    } elseif ($Campaign -eq "G4-GQ2") {
        "sporespore_br14a_nonuniform_proportion_probe_report_v7"
    } elseif ($Campaign -eq "G4-GQ1") {
        "sporespore_br14a_nonuniform_proportion_probe_report_v6"
    } elseif ($Campaign -eq "G3-GP5") {
        "sporespore_br14a_nonuniform_proportion_probe_report_v5"
    } elseif ($Campaign -eq "G3-GP4") {
        "sporespore_br14a_nonuniform_proportion_probe_report_v4"
    } elseif ($Campaign -eq "G3-GP3") {
        "sporespore_br14a_nonuniform_proportion_probe_report_v3"
    } elseif ($Campaign -eq "G3-GP2") {
        "sporespore_br14a_nonuniform_proportion_probe_report_v2"
    } else {
        "sporespore_br14a_nonuniform_proportion_probe_report_v1"
    }
    $report = [ordered]@{
        schema_version = $reportSchemaVersion
        generated_utc = (Get-Date).ToUniversalTime().ToString("o")
        source_commit = $sourceCommit
        source_scope_clean = $scopedStatus.Count -eq 0
        scoped_source_tree_dirty = $scopedStatus.Count -gt 0
        scoped_source_status = $scopedStatus
        source_sha256 = $sourceHashes
        immutable_source_snapshot = $true
        source_snapshot_root = $sourceSnapshotRoot
        sdk_native_authority = [bool]$SdkNativeAuthority
        sdk_native_binary_relative_path = if ($SdkNativeAuthority) {
            $sdkNativeBinaryRelativePath.Replace("\", "/")
        } else { "" }
        sdk_native_binary_sha256 = if ($SdkNativeAuthority) {
            $sourceHashes[$sdkNativeBinaryRelativePath.Replace("\", "/")]
        } else { "" }
        sdk_adapter_capability_sha256 = if (
            $SdkNativeAuthority -and $sdkCapabilityDigests.Count -eq 1
        ) {
            $sdkCapabilityDigests[0]
        } else { "" }
        sdk_receipts_complete_and_consistent = $sdkReceiptSetExact
        godot_path = $godotPath
        godot_sha256 = "sha256:" + $godotHash.Hash.ToLowerInvariant()
        physics_project_settings = [ordered]@{
            engine = "Jolt Physics"
            physics_hz = 120
            velocity_steps = 20
            position_steps = $solverPositionSteps
        }
        suite_mutex_name = $suiteMutexName
        suite_mutex_acquired = $suiteMutexAcquired
        suite_mutex_was_abandoned = $suiteMutexWasAbandoned
        test_program = $testRelativePath.Replace("\", "/")
        campaign_id = $campaignId
        campaign_generation = $Campaign
        campaign_role = $campaignRole
        held_out_repetition = $repetition
        preregistered_selection_morphologies = $selectionMorphologies
        preregistered_held_out_morphologies = $heldOutMorphologies
        development_subset_used = $developmentSubsetUsed
        executed_morphologies = $morphologies
        expected_assertions_per_cell = $expectedAssertionsPerCell
        total_assertions_passed = $totalAssertionsPassed
        total_assertions_failed = $totalAssertionsFailed
        all_harnesses_passed = (
            @($results | Where-Object { -not $_.harness_passed }).Count -eq 0
        )
        all_cells_walked = (
            @($results | Where-Object { -not $_.walking_observed }).Count -eq 0
        )
        formula_policy_sha256 = if ($policyDigests.Count -eq 1) {
            $policyDigests[0]
        } else { "" }
        formula_policy_digest_consistent = $policyDigests.Count -eq 1
        proportion_digest_distinct_by_morphology = (
            $parameterDigests.Count -eq $morphologies.Count
        )
        fixture_digest_distinct_by_morphology = (
            $fixtureDigests.Count -eq $morphologies.Count
        )
        static_screen_digest_distinct_by_morphology = (
            $staticDigests.Count -eq $morphologies.Count
        )
        controller_digest_fixed_across_morphologies = (
            $controllerDigests.Count -eq 1 -and
            (
                $Campaign -eq "G3-GP5" -or
                $controllerDigests[0] -eq $expectedControllerSha256
            )
        )
        controller_digest_formula_derived_by_morphology = (
            $isGeneratedCampaign -and
            $controllerDigests.Count -ge 2
        )
        generator_receipt_distinct_by_morphology = (
            $isGeneratedCampaign -and
            $generationDigests.Count -eq $morphologies.Count
        )
        morphology_feature_receipt_distinct_by_morphology = (
            (
                $Campaign -eq "G4-GQ13" -or
                $Campaign -eq "G4-GQ14" -or
                $Campaign -eq "G4-GQ15"
            ) -and
            $featureDigests.Count -eq $morphologies.Count
        )
        morphology_coverage_receipt_distinct_by_morphology = (
            (
                $Campaign -eq "G4-GQ13" -or
                $Campaign -eq "G4-GQ14" -or
                $Campaign -eq "G4-GQ15"
            ) -and
            $coverageDigests.Count -eq $morphologies.Count
        )
        morphology_coverage_statuses_observed = $coverageStatuses
        dynamic_support_receipt_distinct_by_morphology = (
            (
                $Campaign -eq "G4-GQ13" -or
                $Campaign -eq "G4-GQ14" -or
                $Campaign -eq "G4-GQ15"
            ) -and
            $dynamicSupportDigests.Count -eq $morphologies.Count
        )
        diagnostic_receipts_complete = (
            (
                $Campaign -eq "G4-GQ13" -or
                $Campaign -eq "G4-GQ14" -or
                $Campaign -eq "G4-GQ15"
            ) -and
            $diagnosticDigestSetsExact
        )
        diagnostic_receipts_report_only_no_controller_or_acceptance_authority = (
            $Campaign -eq "G4-GQ13" -or
            $Campaign -eq "G4-GQ14" -or
            $Campaign -eq "G4-GQ15"
        )
        selection_eligible = (
            -not $HeldOutValidation -and
            -not $developmentSubsetUsed -and
            $allCellsPassed
        )
        held_out_repetition_passed = (
            $HeldOutValidation -and
            -not $developmentSubsetUsed -and
            $allCellsPassed
        )
        sdk_c6_selection_eligible = (
            $SdkNativeAuthority -and
            -not $HeldOutValidation -and
            -not $developmentSubsetUsed -and
            $morphologies.Count -eq 12 -and
            $totalAssertionsPassed -eq 396 -and
            $totalAssertionsFailed -eq 0 -and
            $allCellsPassed
        )
        sdk_c6_held_out_repetition_passed = (
            $SdkNativeAuthority -and
            $HeldOutValidation -and
            -not $developmentSubsetUsed -and
            $morphologies.Count -eq 8 -and
            $totalAssertionsPassed -eq 264 -and
            $totalAssertionsFailed -eq 0 -and
            $allCellsPassed
        )
        finite_gq15_godot_jolt_sdk_c6_confirmed = $false
        engine_neutrality_established = $false
        arbitrary_quadruped_coverage_established = $false
        continuous_physical_morphology_coverage_established = $false
        g3_complete = $false
        gq1_complete = $false
        gq2_complete = $false
        gq3_complete = $false
        gq4_complete = $false
        gq5_complete = $false
        gq6_complete = $false
        gq7_complete = $false
        gq8_complete = $false
        gq9_complete = $false
        gq10_complete = $false
        gq11_complete = $false
        gq12_complete = $false
        gq13_complete = $false
        gq14_complete = $false
        gq15_complete = $false
        morphology_generalization_established = $false
        formal_milestone_acceptance_authorized = $false
        encyclopedia_admission_authorized = $false
        automatic_creature_guidance_allowed = $false
        results = $results
    }
    $reportPath = Join-Path $campaignRoot "report.json"
    $reportJson = $report | ConvertTo-Json -Depth 30
    [System.IO.File]::WriteAllText(
        $reportPath,
        $reportJson + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
    $reportHash = Get-FileHash `
        -LiteralPath $reportPath `
        -Algorithm SHA256
    Write-Output "REPORT=$reportPath"
    Write-Output (
        "REPORT_SHA256=sha256:" +
        $reportHash.Hash.ToLowerInvariant()
    )
    Write-Output (
        "CAMPAIGN=$campaignId PASSED=$allCellsPassed " +
        "ASSERTIONS=$($report.total_assertions_passed)/" +
        "$($report.total_assertions_failed)"
    )
    if (-not $allCellsPassed) {
        exit 1
    }
    exit 0
} finally {
    if ($suiteMutexAcquired) {
        $suiteMutex.ReleaseMutex()
    }
    $suiteMutex.Dispose()
}

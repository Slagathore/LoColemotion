param(
    [string]$Python = "python",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [switch]$SkipGodot
)

$ErrorActionPreference = "Stop"

function Assert-R23D59([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "QSDK-R23D59 preregistration audit failed: $Message"
    }
}

function Get-R23D59Sha256([string]$Path) {
    return "sha256:$((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant())"
}

function Assert-R23D59VectorEqual($Actual, $Expected, [string]$Label) {
    Assert-R23D59 (@($Actual).Count -eq @($Expected).Count) "$Label length changed"
    for ($index = 0; $index -lt @($Expected).Count; $index++) {
        Assert-R23D59 (
            [BitConverter]::DoubleToInt64Bits([double]$Actual[$index]) -eq
            [BitConverter]::DoubleToInt64Bits([double]$Expected[$index])
        ) "$Label value $index changed"
    }
}

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$expectedRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$designPath = Join-Path $repoRoot (
    "sdk\turning\r23d59_godot_knee_source_finite_decision.py"
)
$declarationPath = Join-Path $repoRoot (
    "sdk\turning\r23d59_godot_knee_source_finite_decision_preregistration_v1.json"
)
$seedCompilerPath = Join-Path $repoRoot "sdk\turning\r23d59_seed_fixture_compiler.gd"

Assert-R23D59 ($repoRoot.TrimEnd("\") -ceq $expectedRoot) "repository root changed"
Assert-R23D59 (
    (& git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
    $expectedRoot
) "Git top-level changed"
Assert-R23D59 (
    (& git -C $repoRoot remote get-url origin).Trim() -ceq $expectedRemote
) "origin remote changed"
Assert-R23D59 (Test-Path -LiteralPath $designPath -PathType Leaf) "design missing"
Assert-R23D59 (Test-Path -LiteralPath $declarationPath -PathType Leaf) "declaration missing"
Assert-R23D59 (Test-Path -LiteralPath $seedCompilerPath -PathType Leaf) "seed compiler missing"
$attributes = Get-Content -Raw -LiteralPath (Join-Path $repoRoot ".gitattributes")
foreach ($rule in @(
    "sdk/turning/r23d59_* text eol=lf",
    "sdk/run_qsdk_r23d59_* text eol=lf",
    "tests/test_qsdk_r23d59_* text eol=lf",
    "tests/test_sdk_qsdk_r23d59_* text eol=lf"
)) {
    Assert-R23D59 ($attributes.Contains($rule)) "missing byte-stable rule: $rule"
}

$declaration = Get-Content -Raw -LiteralPath $declarationPath | ConvertFrom-Json -AsHashtable
Assert-R23D59 (
    [string]$declaration.question_class -ceq "finite_decision"
) "physical question is not classified as a finite decision"
Assert-R23D59 (-not [bool]$declaration.physical_campaign_opened) "R23D59 is physically open"
Assert-R23D59 (
    -not [bool]$declaration.reserved_r23d60_held_out_turning_validation.physical_campaign_opened
) "R23D60 is physically open"
Assert-R23D59 (
    @($declaration.frozen_matrix.cells).Count -eq 6 -and
    [int]$declaration.frozen_matrix.declared_world_count -eq 6
) "six-cell matrix changed"
Assert-R23D59 (
    (@($declaration.frozen_matrix.ordered_campaign_seeds) -join ",") -ceq
    "21513,21514,21515"
) "decision seeds changed"
Assert-R23D59 (
    [int]$declaration.reserved_r23d60_held_out_turning_validation.campaign_seed -eq 21516
) "held-out seed changed"
Assert-R23D59 (
    [bool]$declaration.claims.r23d59_local_declaration_gate_passed -and
    @(
        $declaration.claims.GetEnumerator() |
            Where-Object {
                $_.Key -cne "r23d59_local_declaration_gate_passed" -and [bool]$_.Value
            }
    ).Count -eq 0
) "local declaration claim or false claim boundary changed"

foreach ($seed in @(21513, 21514, 21515, 21516)) {
    $pattern = "(^|[^0-9])$seed([^0-9]|`$)"
    $priorUses = @(
        & git -C $repoRoot grep -n -E $pattern fb24fe080387b919ff5ba3ecbb22a6bca0220ff2 `
            -- sdk tests docs 2>$null
    )
    Assert-R23D59 ($LASTEXITCODE -in @(0, 1)) "Git seed reservation scan failed for $seed"
    Assert-R23D59 ($priorUses.Count -eq 0) "seed $seed was already used before R23D59"
}

$oldNoBytecode = $env:PYTHONDONTWRITEBYTECODE
try {
    $env:PYTHONDONTWRITEBYTECODE = "1"
    $pythonOutput = @(
        & $Python $designPath --declaration $declarationPath 2>&1
    )
    Assert-R23D59 ($LASTEXITCODE -eq 0) "Python declaration audit failed"
} finally {
    if ($null -eq $oldNoBytecode) {
        Remove-Item Env:PYTHONDONTWRITEBYTECODE -ErrorAction SilentlyContinue
    } else {
        $env:PYTHONDONTWRITEBYTECODE = $oldNoBytecode
    }
}
$auditMarker = @($pythonOutput | Where-Object {
    [string]$_ -like "QSDK_R23D59_PREREGISTRATION_AUDIT *"
})
Assert-R23D59 ($auditMarker.Count -eq 1) "Python audit marker changed"
$audit = ([string]$auditMarker[0]).Substring(
    "QSDK_R23D59_PREREGISTRATION_AUDIT ".Length
) | ConvertFrom-Json -AsHashtable
Assert-R23D59 (
    [int]$audit.declared_cell_count -eq 6 -and
    [int]$audit.decision_seed_count -eq 3 -and
    [int]$audit.reserved_held_out_seed_count -eq 1 -and
    [int]$audit.selection_case_count -eq 5 -and
    [int]$audit.mutation_rejection_count -eq 14 -and
    [int]$audit.model_construction_count -eq 0 -and
    [int]$audit.world_attempt_count -eq 0 -and
    [int]$audit.world_build_count -eq 0 -and
    -not [bool]$audit.physical_campaign_opened -and
    -not [bool]$audit.r23d60_physical_campaign_opened
) "Python audit receipt changed"

$compilerText = Get-Content -Raw -LiteralPath $seedCompilerPath
foreach ($forbidden in @(
    "WaveGaitScript.new(",
    ".run(",
    "add_child(",
    "RigidBody3D",
    "StaticBody3D",
    "PackedScene",
    "instantiate(",
    "await "
)) {
    Assert-R23D59 (-not $compilerText.Contains($forbidden)) (
        "seed compiler contains physical construction token: $forbidden"
    )
}

$godotCompilerRun = $false
if (-not $SkipGodot) {
    Assert-R23D59 (Test-Path -LiteralPath $Godot -PathType Leaf) "Godot executable missing"
    $godotOutput = @(
        & $Godot --headless --path $repoRoot --script `
            "res://sdk/turning/r23d59_seed_fixture_compiler.gd" 2>&1
    )
    Assert-R23D59 ($LASTEXITCODE -eq 0) "Godot seed compiler failed"
    $seedMarker = @($godotOutput | Where-Object {
        [string]$_ -like "QSDK_R23D59_SEED_FIXTURES *"
    })
    Assert-R23D59 ($seedMarker.Count -eq 1) "Godot seed fixture marker changed"
    $receipt = ([string]$seedMarker[0]).Substring(
        "QSDK_R23D59_SEED_FIXTURES ".Length
    ) | ConvertFrom-Json -AsHashtable
    Assert-R23D59 (
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        (@($receipt.r23d59_decision_seeds) -join ",") -ceq "21513,21514,21515" -and
        (@($receipt.r23d60_unopened_held_out_seeds) -join ",") -ceq "21516" -and
        @($receipt.fixtures).Count -eq 4
    ) "Godot seed compiler receipt changed"

    $expectedFixtures = @($declaration.frozen_matrix.initial_perturbations) + @(
        $declaration.reserved_r23d60_held_out_turning_validation.initial_perturbation
    )
    for ($index = 0; $index -lt $expectedFixtures.Count; $index++) {
        $actual = $receipt.fixtures[$index]
        $expected = $expectedFixtures[$index]
        Assert-R23D59 ([int]$actual.campaign_seed -eq [int]$expected.campaign_seed) (
            "compiled seed $index changed"
        )
        foreach ($key in @("fixture_vertical_clearance_m", "fixture_yaw_rad")) {
            Assert-R23D59 (
                [BitConverter]::DoubleToInt64Bits([double]$actual[$key]) -eq
                [BitConverter]::DoubleToInt64Bits([double]$expected[$key])
            ) "compiled $key for seed $($expected.campaign_seed) changed"
        }
        Assert-R23D59VectorEqual $actual.initial_linear_velocity_world_m_s `
            $expected.initial_linear_velocity_world_m_s "compiled linear velocity"
        Assert-R23D59VectorEqual $actual.initial_torso_angular_velocity_world_rad_s `
            $expected.initial_torso_angular_velocity_world_rad_s "compiled angular velocity"
        Assert-R23D59 (
            [int]$actual.gait_phase_offset_ticks -eq [int]$expected.gait_phase_offset_ticks
        ) "compiled gait phase for seed $($expected.campaign_seed) changed"
    }
    $godotCompilerRun = $true
}

Write-Output (
    "QSDK_R23D59_PREREGISTRATION_PASS " +
    "question=finite_decision cells=6 decision_seeds=3 held_out_seeds=1 " +
    "selection_cases=5 mutations=14 godot_seed_compiler=$godotCompilerRun " +
    "models=0 worlds=0 physical=False r23d60_open=False " +
    "design=$(Get-R23D59Sha256 $designPath) " +
    "declaration=$(Get-R23D59Sha256 $declarationPath) " +
    "seed_compiler=$(Get-R23D59Sha256 $seedCompilerPath)"
)

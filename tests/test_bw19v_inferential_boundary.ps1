#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$manifestPath = Join-Path $repoRoot (
    "sdk\balanced_wave_bw19v_closure_manifest.json"
)
$preregistrationPath = Join-Path $repoRoot (
    "sdk\balanced_wave_bw19v_independent_validation_preregistration.json"
)

function Assert-Exact {
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,
        [Parameter(Mandatory)]
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Get-Sha256 {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Get-BinomialCoefficient {
    param(
        [Parameter(Mandatory)]
        [int]$N,
        [Parameter(Mandatory)]
        [int]$K
    )
    if ($K -lt 0 -or $K -gt $N) {
        return 0.0
    }
    $reducedK = [Math]::Min($K, $N - $K)
    $coefficient = 1.0
    for ($index = 1; $index -le $reducedK; $index += 1) {
        $coefficient *= ($N - $reducedK + $index) / $index
    }
    return $coefficient
}

function Get-HalfProbability {
    param(
        [Parameter(Mandatory)]
        [int]$N,
        [Parameter(Mandatory)]
        [int]$K
    )
    return (Get-BinomialCoefficient -N $N -K $K) / [Math]::Pow(2.0, $N)
}

Assert-Exact (
    Test-Path -LiteralPath $manifestPath -PathType Leaf
) "The BW19V closure manifest is missing"
Assert-Exact (
    Test-Path -LiteralPath $preregistrationPath -PathType Leaf
) "The BW19V preregistration is missing"

$manifest = (
    Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable
)
$preregistration = (
    Get-Content -Raw -LiteralPath $preregistrationPath |
        ConvertFrom-Json -AsHashtable
)

Assert-Exact (
    [string]$manifest.status -ceq
        "complete_finite_independent_validation_hypothesis_confirmed" -and
    [bool]$manifest.claims.finite_independent_validation_hypothesis_confirmed -and
    [bool]$manifest.claims.bounded_independent_validation_authority -and
    -not [bool]$manifest.claims.arbitrary_quadruped_coverage -and
    -not [bool]$manifest.claims.continuous_full_volume_coverage -and
    -not [bool]$manifest.claims.walking_acceptance -and
    -not [bool]$manifest.claims.physical_acceptance_authority
) "The immutable BW19V finite-claim boundary changed"

Assert-Exact (
    [string]$preregistration.controlled_hypothesis.hypothesis -ceq
        "The BW18G scale-0.5 development observation predicts fewer production walking-conjunction failures than exact-zero residual control on this unopened morphology cohort under fresh paired seeds." -and
    [string]$preregistration.selection.primary_metric -ceq
        "walking_conjunction_failure_count" -and
    [bool]$preregistration.selection.treatment_walking_failure_count_must_be_strictly_lower_than_control -and
    [bool]$preregistration.selection.walking_failure_tie_or_worse_rejects_hypothesis -and
    [bool]$preregistration.report_aggregation.paired_by_generator_index_and_seed
) "BW19V was not retained as the load-bearing paired strict-failure comparison"

$candidateReports = @($manifest.complete_attempt.candidate_reports)
Assert-Exact (
    $candidateReports.Count -eq 2 -and
    [string]$candidateReports[0].candidate_id -ceq "BW19V-A" -and
    [string]$candidateReports[1].candidate_id -ceq "BW19V-B"
) "The BW19V candidate report order changed"

$reports = @()
foreach ($candidateReport in $candidateReports) {
    $path = [System.IO.Path]::GetFullPath([string]$candidateReport.path)
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "A retained BW19V report is missing: $path"
    Assert-Exact (
        (Get-Sha256 -Path $path) -ceq [string]$candidateReport.sha256
    ) "A retained BW19V report changed: $path"
    $reports += ,(
        Get-Content -Raw -LiteralPath $path |
            ConvertFrom-Json -AsHashtable
    )
}

$controlByKey = @{}
foreach ($result in @($reports[0].results)) {
    $key = "$([string]$result.morphology_id)|$([int]$result.seed)"
    Assert-Exact (
        -not $controlByKey.ContainsKey($key)
    ) "The BW19V control contains duplicate paired key $key"
    $controlByKey[$key] = $result
}

$treatmentByKey = @{}
foreach ($result in @($reports[1].results)) {
    $key = "$([string]$result.morphology_id)|$([int]$result.seed)"
    Assert-Exact (
        -not $treatmentByKey.ContainsKey($key)
    ) "The BW19V treatment contains duplicate paired key $key"
    $treatmentByKey[$key] = $result
}

Assert-Exact (
    $controlByKey.Count -eq 36 -and
    $treatmentByKey.Count -eq 36
) "BW19V no longer contains exactly 36 paired cells"

$bothPass = 0
$controlOnly = 0
$treatmentOnly = 0
$bothFail = 0
foreach ($key in @($controlByKey.Keys | Sort-Object)) {
    Assert-Exact (
        $treatmentByKey.ContainsKey($key)
    ) "BW19V treatment is missing paired key $key"
    $controlWalked = [bool]$controlByKey[$key].walking_observed
    $treatmentWalked = [bool]$treatmentByKey[$key].walking_observed
    if ($controlWalked -and $treatmentWalked) {
        $bothPass += 1
    } elseif ($controlWalked) {
        $controlOnly += 1
    } elseif ($treatmentWalked) {
        $treatmentOnly += 1
    } else {
        $bothFail += 1
    }
}

Assert-Exact (
    $bothPass -eq 30 -and
    $controlOnly -eq 1 -and
    $treatmentOnly -eq 3 -and
    $bothFail -eq 2
) "The retained BW19V paired outcome table changed"

$discordantCount = $controlOnly + $treatmentOnly
$oneSidedExactP = 0.0
for ($wins = $treatmentOnly; $wins -le $discordantCount; $wins += 1) {
    $oneSidedExactP += Get-HalfProbability -N $discordantCount -K $wins
}
$lowerTail = 0.0
for ($wins = 0; $wins -le $controlOnly; $wins += 1) {
    $lowerTail += Get-HalfProbability -N $discordantCount -K $wins
}
$twoSidedExactP = [Math]::Min(1.0, 2.0 * [Math]::Min(
    $oneSidedExactP,
    $lowerTail
))

Assert-Exact (
    [Math]::Abs($oneSidedExactP - 0.3125) -le 1.0e-12 -and
    [Math]::Abs($twoSidedExactP - 0.625) -le 1.0e-12
) "The exact paired BW19V probability reconstruction changed"

$selectionPath = [System.IO.Path]::GetFullPath(
    [string]$manifest.selection.path
)
Assert-Exact (
    Test-Path -LiteralPath $selectionPath -PathType Leaf
) "The retained BW19V selection is missing"
Assert-Exact (
    (Get-Sha256 -Path $selectionPath) -ceq [string]$manifest.selection.sha256
) "The retained BW19V selection changed"
$selection = (
    Get-Content -Raw -LiteralPath $selectionPath |
        ConvertFrom-Json -AsHashtable
)
Assert-Exact (
    [bool]$selection.validation_hypothesis_confirmed -and
    [int]$selection.control_walking_conjunction_failure_count -eq 5 -and
    [int]$selection.treatment_walking_conjunction_failure_count -eq 3 -and
    [int]$selection.control_minus_treatment_walking_failure_count -eq 2 -and
    [string]$selection.selected_candidate_id -ceq "BW19V-B"
) "The frozen finite-cohort selector disposition changed"

Write-Output (
    "BW19V_INFERENTIAL_BOUNDARY_PASS pairs=36 both_pass=$bothPass " +
    "control_only=$controlOnly treatment_only=$treatmentOnly " +
    "both_fail=$bothFail one_sided_exact_p=$oneSidedExactP " +
    "two_sided_exact_p=$twoSidedExactP finite_predicate=True " +
    "population_superiority=False noninferiority=False"
)

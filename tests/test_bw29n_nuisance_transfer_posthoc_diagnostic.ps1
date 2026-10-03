#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath(
    (Split-Path -Parent $PSScriptRoot)
)
$compilerPath = Join-Path $repoRoot (
    "sdk\balanced_wave_bw29n_nuisance_transfer_posthoc_diagnostic.ps1"
)
$temporaryRoot = Join-Path (
    [System.IO.Path]::GetTempPath()
) ("sporespore-bw29n-posthoc-" + [guid]::NewGuid().ToString("N"))
$outputPath = Join-Path $temporaryRoot "diagnostic.json"

try {
    [void](New-Item -ItemType Directory -Path $temporaryRoot)
    & $compilerPath -OutputPath $outputPath
    $diagnostic = Get-Content -Raw -LiteralPath $outputPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    if (
        [string]$diagnostic.classification -cne
            "posthoc_diagnostic_only_not_a_reclassification_or_selection" -or
        [int]$diagnostic.retained_physical_evidence.parsed_receipt_count -ne 24 -or
        [int]$diagnostic.observed_challenge_realization_defect.invalid_cell_count -ne 3 -or
        [int]$diagnostic.projected_frozen_evaluator_diagnostic.passed_gate_count -ne 10 -or
        [int]$diagnostic.projected_frozen_evaluator_diagnostic.failed_gate_count -ne 2 -or
        [string]$diagnostic.projected_frozen_evaluator_diagnostic.selected_candidate_id -cne "NONE" -or
        [bool]$diagnostic.projected_frozen_evaluator_diagnostic.development_selection_authority -or
        [bool]$diagnostic.projected_frozen_evaluator_diagnostic.physical_acceptance_authority -or
        -not [bool]$diagnostic.immutability.status_remains_implementation_invalid -or
        [bool]$diagnostic.immutability.campaign_reclassified -or
        [bool]$diagnostic.claim_boundary.walking_acceptance -or
        [bool]$diagnostic.claim_boundary.nuisance_acceptance -or
        [bool]$diagnostic.claim_boundary.release_authorized
    ) {
        throw "BW29N posthoc diagnostic authority or exact result drifted"
    }
} finally {
    if (Test-Path -LiteralPath $temporaryRoot -PathType Container) {
        $resolvedTemporaryRoot = [System.IO.Path]::GetFullPath($temporaryRoot)
        $resolvedSystemTemp = [System.IO.Path]::GetFullPath(
            [System.IO.Path]::GetTempPath()
        )
        if (-not $resolvedTemporaryRoot.StartsWith(
            $resolvedSystemTemp,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            throw "Refusing to remove an unexpected BW29N test directory"
        }
        Remove-Item -LiteralPath $resolvedTemporaryRoot -Recurse -Force
    }
}

Write-Host (
    "BW29N_POSTHOC_DIAGNOSTIC_TEST_PASS receipts=24 invalid_cells=3 " +
    "projected=10/12 selector=NONE authority=False reclassified=False"
)

#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [switch]$SkipGodotActualPath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$gateId = "DRP1"
$regressionId = "BW31N-DYNAMIC-RECEIPT-PROJECTION-REGRESSION-DRP1"
$declarationAuditPath = Join-Path $repoRoot `
    "tests\test_drp1_dynamic_receipt_projection_declaration.ps1"
$evaluatorPath = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_gate.ps1"
$runnerPath = Join-Path $repoRoot `
    "sdk\run_balanced_wave_dynamic_receipt_projection_drp1.ps1"
$referenceWorkerPath = Join-Path $repoRoot `
    "tests\test_sdk_drp1_reference_worker.gd"
$successorWorkerPath = Join-Path $repoRoot `
    "tests\test_sdk_drp1_successor_worker.gd"
$preflightPrefix = "DRP1_WORKER_PREFLIGHT "
$rawPrefix = "DRP1_DYNAMIC_RECEIPT_RAW_CELL "

function Assert-Drp1ZeroWorld {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-Drp1ZeroWorldProcess {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [switch]$ClearDrp1Authorization,
        [int]$TimeoutMilliseconds = 120000
    )
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FileName
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $ArgumentList) {
        [void]$startInfo.ArgumentList.Add($argument)
    }
    if ($ClearDrp1Authorization.IsPresent) {
        [void]$startInfo.Environment.Remove("SPORESPORE_DRP1_REGRESSION_TOKEN")
        [void]$startInfo.Environment.Remove("SPORESPORE_DRP1_CELL")
        [void]$startInfo.Environment.Remove("SPORESPORE_DRP1_ROUTE")
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        Assert-Drp1ZeroWorld $process.Start() "failed to start $FileName"
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $exited = $process.WaitForExit($TimeoutMilliseconds)
        if (-not $exited) {
            try { $process.Kill($true) } catch {}
            $process.WaitForExit()
        }
        return [ordered]@{
            exit_code = if ($exited) { $process.ExitCode } else { -999 }
            timed_out = -not $exited
            stdout = $stdoutTask.GetAwaiter().GetResult()
            stderr = $stderrTask.GetAwaiter().GetResult()
        }
    } finally {
        $process.Dispose()
    }
}

foreach ($path in @(
    $declarationAuditPath,
    $evaluatorPath,
    $runnerPath,
    $referenceWorkerPath,
    $successorWorkerPath
)) {
    Assert-Drp1ZeroWorld (Test-Path -LiteralPath $path -PathType Leaf) (
        "$gateId zero-world dependency is missing: $path"
    )
}

& pwsh -NoLogo -NoProfile -File $declarationAuditPath
Assert-Drp1ZeroWorld ($LASTEXITCODE -eq 0) "$gateId declaration audit failed"

& pwsh -NoLogo -NoProfile -File $evaluatorPath -SelfTest
Assert-Drp1ZeroWorld ($LASTEXITCODE -eq 0) "$gateId evaluator self-test failed"

& pwsh -NoLogo -NoProfile -File $runnerPath -PreflightOnly
Assert-Drp1ZeroWorld ($LASTEXITCODE -eq 0) "$gateId runner preflight failed"

$actualEntrypoints = 0
$authorizationCanaries = 0
$constructedReceiptRejections = 0
$nestedWalkingSchemaPreflights = 0
$crossRouteSchemaRejections = 0
if (-not $SkipGodotActualPath.IsPresent) {
    Assert-Drp1ZeroWorld (Test-Path -LiteralPath $Godot -PathType Leaf) (
        "$gateId Godot executable is missing: $Godot"
    )
    foreach ($worker in @(
        [ordered]@{
            path = $referenceWorkerPath
            route = "DRP1-REFERENCE-ROUTE"
            cell = "baseline_s22001_drp1_reference"
            refusal = "DRP1 reference regression requires exact conformance-owned authorization"
        },
        [ordered]@{
            path = $successorWorkerPath
            route = "DRP1-SUCCESSOR-ROUTE"
            cell = "baseline_s22001_drp1_successor"
            refusal = "DRP1 successor regression requires exact conformance-owned authorization"
        }
    )) {
        $aggregateProcess = Invoke-Drp1ZeroWorldProcess `
            -FileName $Godot `
            -ArgumentList @(
                "--headless", "--path", $repoRoot,
                "--script", [string]$worker.path,
                "--", "preflight-all"
            ) `
            -WorkingDirectory $repoRoot `
            -ClearDrp1Authorization
        $aggregateCombined = [string]$aggregateProcess.stdout +
            [Environment]::NewLine + [string]$aggregateProcess.stderr
        $aggregateLines = @(
            $aggregateCombined -split "\r?\n" |
                Where-Object {
                    $_.StartsWith($preflightPrefix, [StringComparison]::Ordinal)
                }
        )
        Assert-Drp1ZeroWorld (
            -not [bool]$aggregateProcess.timed_out -and
            [int]$aggregateProcess.exit_code -eq 0 -and
            $aggregateLines.Count -eq 1
        ) "$gateId actual worker aggregate preflight failed: $($worker.route)"
        $aggregate = $aggregateLines[0].Substring($preflightPrefix.Length) |
            ConvertFrom-Json -AsHashtable -Depth 100
        $receipts = @($aggregate.entrypoint_receipts)
        Assert-Drp1ZeroWorld (
            [string]$aggregate.schema_version -ceq
                "sporespore_drp1_worker_preflight_aggregate_v1" -and
            [bool]$aggregate.ok -and
            [string]$aggregate.regression_id -ceq $regressionId -and
            [string]$aggregate.gate_id -ceq $gateId -and
            [string]$aggregate.route_id -ceq [string]$worker.route -and
            [int]$aggregate.entrypoint_count -eq 12 -and
            $receipts.Count -eq 12 -and
            [int]$aggregate.actual_world_build_count -eq 0 -and
            -not [bool]$aggregate.physics_state_modified -and
            -not [bool]$aggregate.selection_authority -and
            -not [bool]$aggregate.physical_acceptance_authority
        ) "$gateId worker aggregate inflated or malformed: $($worker.route)"
        foreach ($receipt in $receipts) {
            $expectedActuationKey = if (
                [string]$worker.route -ceq "DRP1-REFERENCE-ROUTE"
            ) {
                "sdk_stability_overlay_evidence_actuation"
            } else {
                "native_sdk_exclusive_post_settle_actuation"
            }
            Assert-Drp1ZeroWorld (
                [bool]$receipt.ok -and
                [int]$receipt.actual_world_build_count -eq 0 -and
                [bool]$receipt.constructed_final_receipt_rejected -and
                [bool]$receipt.nested_walking_schema_route_specific -and
                [int]$receipt.nested_walking_schema_key_count -eq 26 -and
                [string]$receipt.route_actuation_key -ceq $expectedActuationKey -and
                [bool]$receipt.cross_route_nested_schema_rejected -and
                -not [bool]$receipt.selection_authority -and
                -not [bool]$receipt.physical_acceptance_authority
            ) "$gateId worker entrypoint preflight failed: $($receipt.cell_id)"
            $actualEntrypoints++
            $constructedReceiptRejections++
            $nestedWalkingSchemaPreflights++
            $crossRouteSchemaRejections++
        }

        $refusalProcess = Invoke-Drp1ZeroWorldProcess `
            -FileName $Godot `
            -ArgumentList @(
                "--headless", "--path", $repoRoot,
                "--script", [string]$worker.path,
                "--", "regression", [string]$worker.cell
            ) `
            -WorkingDirectory $repoRoot `
            -ClearDrp1Authorization
        $refusalCombined = [string]$refusalProcess.stdout +
            [Environment]::NewLine + [string]$refusalProcess.stderr
        Assert-Drp1ZeroWorld (
            -not [bool]$refusalProcess.timed_out -and
            [int]$refusalProcess.exit_code -ne 0 -and
            $refusalCombined.Contains([string]$worker.refusal) -and
            -not $refusalCombined.Contains($rawPrefix)
        ) "$gateId unauthorized regression was not refused before world creation"
        $authorizationCanaries++
    }
}

Write-Host (
    "DRP1_ZERO_WORLD_GATE_PASS gates=12 evaluator_canaries=12 " +
    "entrypoints=$actualEntrypoints authorization_canaries=$authorizationCanaries " +
    "constructed_receipts_rejected=$constructedReceiptRejections worlds=0 " +
    "nested_walking_schemas=$nestedWalkingSchemaPreflights " +
    "cross_route_schema_rejections=$crossRouteSchemaRejections " +
    "one_shot=False selection_authority=False walking_authority=False " +
    "physical_authority=False"
)

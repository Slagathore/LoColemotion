#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunRegression,
    [string]$ConformanceToken = "",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$regressionId = "BW31N-DYNAMIC-RECEIPT-PROJECTION-REGRESSION-DRP1"
$gateId = "DRP1"
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$declarationPath = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_preregistration.json"
$freezePath = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_freeze_v3.json"
$closurePath = Join-Path $repoRoot `
    "sdk\balanced_wave_bw31n_authority_horizon_closure.json"
$evaluatorPath = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_gate.ps1"
$referenceWorkerPath = Join-Path $repoRoot `
    "tests\test_sdk_drp1_reference_worker.gd"
$successorWorkerPath = Join-Path $repoRoot `
    "tests\test_sdk_drp1_successor_worker.gd"
$rawPrefix = "DRP1_DYNAMIC_RECEIPT_RAW_CELL "
$referenceRouteId = "DRP1-REFERENCE-ROUTE"
$successorRouteId = "DRP1-SUCCESSOR-ROUTE"
$profileIds = @(
    "bw6n_baseline_v1",
    "bw6n_rough_v1",
    "bw6n_push_v1",
    "bw6n_sensor_noise_v1"
)
$profilePrefixes = [ordered]@{
    bw6n_baseline_v1 = "baseline"
    bw6n_rough_v1 = "rough"
    bw6n_push_v1 = "push"
    bw6n_sensor_noise_v1 = "sensor_noise"
}
$regressionSeeds = @(22001, 22002, 22003)
$routeIds = @($referenceRouteId, $successorRouteId)
$expectedDeclarationSha256 = (
    "7356b162cfd75f55ab2f75436cf827c05815b6473d84ba0653f96c2433792626"
)
$expectedClosureSha256 = (
    "b92320e3122257829cebab3ae08c6dacc0aa2def055a649c1345e78b0a51e65f"
)

function Assert-Drp1Runner {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Drp1RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Get-Drp1OrderedCells {
    $cells = [System.Collections.Generic.List[object]]::new()
    foreach ($profileId in $profileIds) {
        foreach ($seed in $regressionSeeds) {
            foreach ($routeId in $routeIds) {
                $suffix = if ($routeId -ceq $referenceRouteId) {
                    "reference"
                } else {
                    "successor"
                }
                $cells.Add([ordered]@{
                    cell_id = "$($profilePrefixes[$profileId])_s${seed}_drp1_$suffix"
                    route_id = $routeId
                    regression_seed = $seed
                    challenge_profile_id = $profileId
                    worker_path = if ($routeId -ceq $referenceRouteId) {
                        $referenceWorkerPath
                    } else {
                        $successorWorkerPath
                    }
                })
            }
        }
    }
    return @($cells)
}

function Invoke-Drp1CapturedProcess {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [hashtable]$Environment = @{},
        [int]$TimeoutMilliseconds = 600000
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
    foreach ($entry in $Environment.GetEnumerator()) {
        $startInfo.Environment[[string]$entry.Key] = [string]$entry.Value
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        Assert-Drp1Runner $process.Start() "failed to start $FileName"
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

function Test-Drp1FreezeBindings {
    param([System.Collections.IDictionary]$Freeze)
    $bindings = [System.Collections.IDictionary]$Freeze.source_bindings
    if ($null -eq $bindings -or $bindings.Count -lt 20) { return $false }
    foreach ($entry in $bindings.GetEnumerator()) {
        $record = [System.Collections.IDictionary]$entry.Value
        $path = [IO.Path]::GetFullPath(
            (Join-Path $repoRoot ([string]$record.path))
        )
        $prefix = $repoRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
        if (
            -not $path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or
            -not (Test-Path -LiteralPath $path -PathType Leaf) -or
            (Get-Drp1RawSha256 -Path $path) -cne [string]$record.raw_sha256
        ) { return $false }
    }
    return $true
}

function Test-Drp1CleanPushedLiveSource {
    $root = (git -C $repoRoot rev-parse --show-toplevel).Trim()
    $originUrl = (git -C $repoRoot remote get-url origin).Trim()
    $head = (git -C $repoRoot rev-parse HEAD).Trim()
    $originMain = (git -C $repoRoot rev-parse origin/main).Trim()
    $dirty = @(git -C $repoRoot status --porcelain=v1 --untracked-files=all)
    $remoteRows = @(git -C $repoRoot ls-remote origin refs/heads/main)
    $liveMain = if ($remoteRows.Count -eq 1) {
        ([string]$remoteRows[0] -split "\s+")[0]
    } else {
        ""
    }
    return (
        $LASTEXITCODE -eq 0 -and
        $root -ceq $repoRoot.Replace("\", "/") -and
        $originUrl -ceq "https://github.com/Slagathore/sporespore.git" -and
        $dirty.Count -eq 0 -and
        $head -ceq $originMain -and
        $head -ceq $liveMain
    )
}

Assert-Drp1Runner (
    $PreflightOnly.IsPresent -xor $RunRegression.IsPresent
) "Specify exactly one of -PreflightOnly or -RunRegression"
Assert-Drp1Runner (
    (Test-Path -LiteralPath $declarationPath -PathType Leaf) -and
    (Test-Path -LiteralPath $closurePath -PathType Leaf) -and
    (Test-Path -LiteralPath $evaluatorPath -PathType Leaf) -and
    (Test-Path -LiteralPath $referenceWorkerPath -PathType Leaf) -and
    (Test-Path -LiteralPath $successorWorkerPath -PathType Leaf) -and
    (Get-Drp1RawSha256 -Path $declarationPath) -ceq $expectedDeclarationSha256 -and
    (Get-Drp1RawSha256 -Path $closurePath) -ceq $expectedClosureSha256
) "$gateId declaration, predecessor closure, evaluator, or worker source changed"

$declaration = Get-Content -Raw -LiteralPath $declarationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Drp1Runner (
    [string]$declaration.regression_id -ceq $regressionId -and
    [string]$declaration.gate_id -ceq $gateId -and
    [int]$declaration.regression_matrix.expected_world_count -eq 24 -and
    -not [bool]$declaration.classification.scientific_campaign -and
    -not [bool]$declaration.classification.one_shot_identity -and
    -not [bool]$declaration.classification.candidate_selection_permitted
) "$gateId declaration authority changed"

if ($PreflightOnly.IsPresent) {
    Assert-Drp1Runner ([string]::IsNullOrWhiteSpace($ConformanceToken)) (
        "$gateId preflight may not receive a conformance execution token"
    )
    Write-Host (
        "DRP1_RUNNER_PREFLIGHT_PASS cells=24 routes=2 evaluator=True " +
        "freeze_required_for_regression=True worlds=0 one_shot=False " +
        "selection_authority=False walking_authority=False physical_authority=False"
    )
    exit 0
}

Assert-Drp1Runner (
    -not [string]::IsNullOrWhiteSpace($ConformanceToken) -and
    $ConformanceToken -ceq $env:SPORESPORE_DRP1_CONFORMANCE_TOKEN -and
    $env:SPORESPORE_DRP1_FULL_GODOT_CONFORMANCE -ceq "1"
) "$gateId regression physics is authorized only by full Godot conformance"
Assert-Drp1Runner (
    (Test-Path -LiteralPath $Godot -PathType Leaf) -and
    (Test-Path -LiteralPath $freezePath -PathType Leaf)
) "$gateId Godot executable or stage-one freeze is missing"
$freeze = Get-Content -Raw -LiteralPath $freezePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Drp1Runner (
    [string]$freeze.schema_version -ceq
        "sporespore_balanced_wave_dynamic_receipt_projection_drp1_freeze_v3" -and
    [string]$freeze.regression_id -ceq $regressionId -and
    [string]$freeze.gate_id -ceq $gateId -and
    [bool]$freeze.full_godot_conformance_regression_ready_after_clean_push -and
    -not [bool]$freeze.standalone_regression_physics_authorized -and
    (Test-Drp1FreezeBindings -Freeze $freeze)
) "$gateId stage-one freeze or source bindings changed"
Assert-Drp1Runner (Test-Drp1CleanPushedLiveSource) (
    "$gateId regression requires clean pushed source equal to live GitHub main"
)
$sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim()
Assert-Drp1Runner ($sourceCommit -cmatch "^[0-9a-f]{40}$") (
    "$gateId could not capture the exact conformance source commit"
)

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) (
    "sporespore_drp1_regression_" + [Guid]::NewGuid().ToString("N")
)
$tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd("\", "/") +
    [IO.Path]::DirectorySeparatorChar
$tempRoot = [IO.Path]::GetFullPath($tempRoot)
Assert-Drp1Runner (
    $tempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and
    -not (Test-Path -LiteralPath $tempRoot)
) "$gateId ephemeral regression path is unsafe"
[void][IO.Directory]::CreateDirectory($tempRoot)
$authorizationPath = Join-Path $tempRoot "conformance-authorization.json"
$authorizationCells = @(
    Get-Drp1OrderedCells | ForEach-Object {
        [ordered]@{
            cell_id = [string]$_.cell_id
            route_id = [string]$_.route_id
        }
    }
)
$authorization = [ordered]@{
    schema_version = "sporespore_drp1_conformance_authorization_v1"
    regression_id = $regressionId
    gate_id = $gateId
    source_commit = $sourceCommit
    authorization_token = $ConformanceToken
    created_by = "sdk/run_balanced_wave_dynamic_receipt_projection_drp1.ps1"
    full_godot_conformance = $true
    authorized_cells = $authorizationCells
    scientific_evidence_retained = $false
    one_shot_identity_consumed = $false
    physical_acceptance_authority = $false
}
[IO.File]::WriteAllText(
    $authorizationPath,
    (($authorization | ConvertTo-Json -Depth 100) + [Environment]::NewLine),
    [Text.UTF8Encoding]::new($false)
)

try {
    $receipts = [System.Collections.Generic.List[object]]::new()
    $exitCodes = [System.Collections.Generic.List[int]]::new()
    $worldBuildCount = 0
    $cellIndex = 0
    foreach ($cell in Get-Drp1OrderedCells) {
        $cellIndex++
        Write-Host (
            "DRP1_REGRESSION_CELL_START index=$cellIndex/24 " +
            "cell=$($cell.cell_id) route=$($cell.route_id)"
        )
        $receipt = Invoke-Drp1CapturedProcess `
            -FileName $Godot `
            -ArgumentList @(
                "--headless",
                "--path", $repoRoot,
                "--script", [string]$cell.worker_path,
                "--",
                "regression", [string]$cell.cell_id
            ) `
            -WorkingDirectory $repoRoot `
            -Environment @{
                SPORESPORE_DRP1_REGRESSION_TOKEN = $ConformanceToken
                SPORESPORE_DRP1_CONFORMANCE_TOKEN = $ConformanceToken
                SPORESPORE_DRP1_FULL_GODOT_CONFORMANCE = "1"
                SPORESPORE_DRP1_SOURCE_COMMIT = $sourceCommit
                SPORESPORE_DRP1_AUTHORIZATION_PATH = $authorizationPath
                SPORESPORE_DRP1_CELL = [string]$cell.cell_id
                SPORESPORE_DRP1_ROUTE = [string]$cell.route_id
            } `
            -TimeoutMilliseconds 900000
        $exitCodes.Add([int]$receipt.exit_code)
        $combined = [string]$receipt.stdout + [Environment]::NewLine +
            [string]$receipt.stderr
        $rawLines = @(
            $combined -split "\r?\n" |
                Where-Object { $_.StartsWith($rawPrefix, [StringComparison]::Ordinal) }
        )
        if ($rawLines.Count -eq 1) {
            try {
                $parsed = $rawLines[0].Substring($rawPrefix.Length) |
                    ConvertFrom-Json -AsHashtable -Depth 100
                $receipts.Add($parsed)
                $worldBuildCount += [int]$parsed.world_build_count
            } catch {
                $receipts.Add([ordered]@{})
            }
        } else {
            $receipts.Add([ordered]@{})
        }
        Write-Host (
            "DRP1_REGRESSION_CELL_COMPLETE index=$cellIndex/24 " +
            "cell=$($cell.cell_id) exit=$($receipt.exit_code) " +
            "receipt=$($rawLines.Count -eq 1) timeout=$([bool]$receipt.timed_out)"
        )
    }

    $evaluationInput = [ordered]@{
        schema_version = "sporespore_drp1_regression_input_v1"
        regression_id = $regressionId
        gate_id = $gateId
        test_fixture_only = $false
        complete_matrix_execution_requested = $true
        receipts = @($receipts)
        worker_exit_codes = @($exitCodes)
        world_build_count = $worldBuildCount
        scientific_evidence_retained = $false
        one_shot_identity_consumed = $false
        candidate_or_policy_selection_authorized = $false
        walking_claim_authorized = $false
        nuisance_acceptance_claim_authorized = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
    $inputPath = Join-Path $tempRoot "evaluation-input.json"
    $outputPath = Join-Path $tempRoot "evaluation.json"
    [IO.File]::WriteAllText(
        $inputPath,
        (($evaluationInput | ConvertTo-Json -Depth 100) + [Environment]::NewLine),
        [Text.UTF8Encoding]::new($false)
    )
    $evaluationProcess = Invoke-Drp1CapturedProcess `
        -FileName (Get-Command pwsh -ErrorAction Stop).Source `
        -ArgumentList @(
            "-NoLogo", "-NoProfile", "-File", $evaluatorPath,
            "-InputPath", $inputPath,
            "-OutputPath", $outputPath
        ) `
        -WorkingDirectory $repoRoot `
        -TimeoutMilliseconds 120000
    Assert-Drp1Runner (
        -not [bool]$evaluationProcess.timed_out -and
        (Test-Path -LiteralPath $outputPath -PathType Leaf)
    ) "$gateId evaluator did not complete"
    $evaluation = Get-Content -Raw -LiteralPath $outputPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-Drp1Runner (
        [int]$evaluationProcess.exit_code -eq 0 -and
        [bool]$evaluation.ok -and
        [bool]$evaluation.complete_regression_passed -and
        [int]$evaluation.passed_gate_count -eq 12 -and
        [int]$evaluation.receipt_count -eq 24 -and
        [int]$evaluation.world_build_count -eq 24 -and
        -not [bool]$evaluation.walking_count_used_by_evaluator -and
        -not [bool]$evaluation.candidate_or_policy_selection_authorized -and
        -not [bool]$evaluation.walking_claim_authorized -and
        -not [bool]$evaluation.physical_acceptance_authority
    ) (
        "$gateId complete regression failed: " +
        (@($evaluation.failed_gate_ids) -join ",")
    )
    Write-Host (
        "DRP1_FULL_GODOT_REGRESSION_PASS worlds=24 receipts=24 gates=12/12 " +
        "walking_descriptive=$($evaluation.walking_observed_count_descriptive_only)/24 " +
        "walking_used_by_evaluator=False retained_evidence=False one_shot=False " +
        "selection_authority=False walking_authority=False physical_authority=False"
    )
} finally {
    if (
        (Test-Path -LiteralPath $tempRoot -PathType Container) -and
        $tempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)
    ) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

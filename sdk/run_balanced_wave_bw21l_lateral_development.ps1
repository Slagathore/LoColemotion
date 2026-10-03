#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$LogRoot = (
        Join-Path $env:TEMP "sporespore_bw21l_lateral_development_preflight"
    ),
    [string]$OutputRoot = "",
    [int]$CellTimeoutSeconds = 300
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$campaignId = "BW21L-MATERIAL-LATERAL-DEVELOPMENT"
$gateId = "BW21L"
$preregistrationPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw21l_lateral_development_preregistration.json"
$candidatesPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw21l_lateral_development_candidates.json"
$productionGatePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw21l_lateral_development_gate.ps1"
$gateTestPath = Join-Path (
    $repoRoot
) "tests\test_bw21l_lateral_development_gate.ps1"
$authorityContractPath = Join-Path (
    $repoRoot
) "tests\test_sdk_balanced_wave_bw21l_authority_contract.gd"
$physicalHarnessPath = Join-Path (
    $repoRoot
) "tests\test_sdk_balanced_wave_bw21l_lateral_development.gd"
$bw20fClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_locomotion_closure.json"
$bw20fReportPath = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "balanced-wave-bw20f-material-locomotion-452c11d\report.json"
)
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw21l_lateral_development_closure.json"
$expectedHashes = [ordered]@{
    $preregistrationPath = "f27b2fd29b81b8e661163f7b991417b7858631190cdeb866fc11437f024ab1da"
    $candidatesPath = "4cdb98b341a932ccd69d85839301b54d039e3680cd67a44baeea2b77136d913b"
    $productionGatePath = "76b2d28e5b1ba815e2987f2b332566d8ac195141aa57ca1db767b8a9a62d8ccf"
    $gateTestPath = "f93ed37123c2ab9a2304e0ed75373e973ca1397661a3c914f0c9a421d201d095"
    $authorityContractPath = "5ad5000d0f713af65bc57bd4d8a8d2a11e0b794173a186c3b2babf18980501aa"
    $physicalHarnessPath = "561b31f35b2eb19777289baab95ec699d7510f73a0f0538c01d700b09c9f782e"
    $bw20fClosurePath = "bd18cd9a4905182673459b7b203ff7b7ae4cd5f954f00175f14fc721980bc1ef"
    $bw20fReportPath = "69400655be32d09404222a647601aa7a1a0856c5c4f3c0cd6a07dac3841caf03"
}
$preflightPrefix = "BW21L_LATERAL_DEVELOPMENT_PREFLIGHT "
$authorizationPreflightPrefix = (
    "BW21L_LATERAL_DEVELOPMENT_AUTHORIZATION_PREFLIGHT "
)
$cellPrefix = "BW21L_LATERAL_DEVELOPMENT_CELL "

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )
    [System.IO.File]::WriteAllText(
        $Path,
        $Text,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Write-NewJsonArtifact {
    param(
        [Parameter(Mandatory)][object]$Value,
        [Parameter(Mandatory)][string]$Path
    )
    Assert-Exact (-not (Test-Path -LiteralPath $Path)) (
        "Refusing to overwrite a $gateId artifact: $Path"
    )
    [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    $temporaryPath = $Path + ".tmp"
    Assert-Exact (-not (Test-Path -LiteralPath $temporaryPath)) (
        "Refusing stale $gateId temporary artifact: $temporaryPath"
    )
    Write-Utf8NoBom `
        -Path $temporaryPath `
        -Text (($Value | ConvertTo-Json -Depth 64) + [Environment]::NewLine)
    Move-Item -LiteralPath $temporaryPath -Destination $Path
}

function Get-ReceiptFromOutput {
    param(
        [Parameter(Mandatory)][string]$OutputText,
        [Parameter(Mandatory)][string]$Prefix
    )
    $lines = @(
        $OutputText -split "\r?\n" |
            Where-Object { $_.StartsWith($Prefix) }
    )
    if ($lines.Count -ne 1) {
        throw "Expected one '$Prefix' receipt, found $($lines.Count)"
    }
    return (
        $lines[0].Substring($Prefix.Length) |
            ConvertFrom-Json -AsHashtable
    )
}

function Invoke-GodotCaptured {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkerRoot,
        [Parameter(Mandatory)][int]$TimeoutSeconds,
        [string]$AttemptPath = "",
        [string]$AuthorizationToken = "",
        [string]$CellId = ""
    )
    $appData = Join-Path $WorkerRoot "appdata"
    $localAppData = Join-Path $WorkerRoot "localappdata"
    [void][System.IO.Directory]::CreateDirectory($appData)
    [void][System.IO.Directory]::CreateDirectory($localAppData)
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $godotPath
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment["APPDATA"] = $appData
    $start.Environment["LOCALAPPDATA"] = $localAppData
    if (-not [string]::IsNullOrWhiteSpace($AttemptPath)) {
        $start.Environment["SPORESPORE_BW21L_ATTEMPT"] = $AttemptPath
        $start.Environment["SPORESPORE_BW21L_TOKEN"] = $AuthorizationToken
        $start.Environment["SPORESPORE_BW21L_CELL"] = $CellId
    }
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    $startedUtc = [DateTime]::UtcNow
    Assert-Exact ($process.Start()) "Failed to start isolated Godot"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    $killedTree = $false
    if ($timedOut) {
        try {
            $process.Kill($true)
            $killedTree = $true
        } catch {
            $killedTree = $false
        }
        [void]$process.WaitForExit(10000)
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($process.HasExited) { $process.ExitCode } else { -1 }
    $durationSeconds = ([DateTime]::UtcNow - $startedUtc).TotalSeconds
    $process.Dispose()
    return [ordered]@{
        exit_code = $exitCode
        timed_out = $timedOut
        killed_process_tree = $killedTree
        duration_seconds = $durationSeconds
        stdout = $stdout
        stderr = $stderr
    }
}

function Assert-NoPriorAttempt {
    $priorAttempts = @()
    if (Test-Path -LiteralPath $evidenceRoot -PathType Container) {
        $priorAttempts = @(
            Get-ChildItem `
                -LiteralPath $evidenceRoot `
                -Recurse `
                -File `
                -Filter "attempt.json" |
            Where-Object {
                try {
                    $attempt = Get-Content -Raw -LiteralPath $_.FullName |
                        ConvertFrom-Json
                    [string]$attempt.campaign_id -ceq $campaignId
                } catch {
                    $false
                }
            }
        )
    }
    Assert-Exact ($priorAttempts.Count -eq 0) (
        "$gateId prior physical attempt exists; this identity may not rerun"
    )
}

Assert-Exact (
    [bool]$PreflightOnly -xor [bool]$RunPhysical
) "Specify exactly one of -PreflightOnly or -RunPhysical"
Assert-Exact (
    $CellTimeoutSeconds -ge 30 -and $CellTimeoutSeconds -le 900
) "$gateId CellTimeoutSeconds must be in [30,900]"
if ($RunPhysical) {
    Assert-Exact (-not [string]::IsNullOrWhiteSpace($OutputRoot)) (
        "$gateId -RunPhysical requires an explicit durable OutputRoot"
    )
    Assert-Exact (-not (Test-Path -LiteralPath $closurePath -PathType Leaf)) (
        "$gateId campaign is already closed and may not rerun"
    )
}

foreach ($entry in $expectedHashes.GetEnumerator()) {
    Assert-Exact (
        (Test-Path -LiteralPath $entry.Key -PathType Leaf) -and
        (Get-RawSha256 -Path $entry.Key) -ceq [string]$entry.Value
    ) "$gateId frozen source or prerequisite changed: $($entry.Key)"
}
Assert-NoPriorAttempt

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable
$cells = @($preregistration.matrix.ordered_cells)
$orderedCellIds = @($cells | ForEach-Object { [string]$_.cell_id })
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw21l_lateral_development_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw21l_lateral_development_world" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    $cells.Count -eq 53 -and
    @($cells | Where-Object role -CEQ "candidate").Count -eq 48 -and
    @($cells | Where-Object role -CEQ "control").Count -eq 4 -and
    @($cells | Where-Object role -CEQ "safety").Count -eq 1
) "$gateId frozen manifest identity or matrix changed"

& pwsh -NoProfile -File $gateTestPath
Assert-Exact ($LASTEXITCODE -eq 0) (
    "$gateId complete production evaluator and canary test failed"
)

$godotPath = [System.IO.Path]::GetFullPath($Godot)
Assert-Exact (
    (Test-Path -LiteralPath $godotPath -PathType Leaf) -and
    (Get-RawSha256 -Path $godotPath) -ceq
        "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
) "$gateId pinned Godot executable changed"

& cargo build `
    --manifest-path (Join-Path $sdkRoot "Cargo.toml") `
    -p sporespore-godot-adapter `
    --offline
Assert-Exact ($LASTEXITCODE -eq 0) "$gateId Godot adapter build failed"

$preflightRoot = [System.IO.Path]::GetFullPath($LogRoot)
[void][System.IO.Directory]::CreateDirectory($preflightRoot)
$authority = Invoke-GodotCaptured `
    -Arguments @(
        "--headless", "--path", $repoRoot,
        "--script", "res://tests/test_sdk_balanced_wave_bw21l_authority_contract.gd"
    ) `
    -WorkerRoot (Join-Path $preflightRoot "authority") `
    -TimeoutSeconds 120
Assert-Exact (
    -not [bool]$authority.timed_out -and [int]$authority.exit_code -eq 0 -and
    ([string]$authority.stdout).Contains(
        "SDK BW21L authority summary: 9 passed, 0 failed",
        [StringComparison]::Ordinal
    )
) "$gateId zero-world authority contract failed"

$entrypoint = Invoke-GodotCaptured `
    -Arguments @(
        "--headless", "--path", $repoRoot,
        "--script", "res://tests/test_sdk_balanced_wave_bw21l_lateral_development.gd",
        "--", "preflight"
    ) `
    -WorkerRoot (Join-Path $preflightRoot "entrypoint") `
    -TimeoutSeconds 180
Assert-Exact (
    -not [bool]$entrypoint.timed_out -and [int]$entrypoint.exit_code -eq 0
) "$gateId real worker entrypoint preflight failed"
$entrypointReceipt = Get-ReceiptFromOutput `
    -OutputText ([string]$entrypoint.stdout) `
    -Prefix $preflightPrefix
Assert-Exact (
    [bool]$entrypointReceipt.ok -and
    [int]$entrypointReceipt.entrypoint_count -eq 53 -and
    [int]$entrypointReceipt.candidate_entrypoint_count -eq 48 -and
    [int]$entrypointReceipt.control_entrypoint_count -eq 4 -and
    [int]$entrypointReceipt.safety_entrypoint_count -eq 1 -and
    [int]$entrypointReceipt.adapter_start_count -eq 52 -and
    [int]$entrypointReceipt.actual_world_build_count -eq 0 -and
    [int]$entrypointReceipt.scene_tree_insertion_count -eq 0 -and
    -not [bool]$entrypointReceipt.physics_state_modified -and
    -not [bool]$entrypointReceipt.locomotion_outcome_exposed -and
    -not [bool]$entrypointReceipt.physical_acceptance_authority -and
    (@($entrypointReceipt.cell_ids) -join "|") -ceq ($orderedCellIds -join "|")
) "$gateId complete 53-cell no-world entrypoint receipt changed"

$authorizationToken = [Guid]::NewGuid().ToString("N")
$authorizationCellId = [string]$orderedCellIds[0]
$authorizationAttemptPath = Join-Path (
    $preflightRoot
) ("authorization-attempt-" + [Guid]::NewGuid().ToString("N") + ".json")
$authorizationAttempt = [ordered]@{
    schema_version = "sporespore_balanced_wave_bw21l_lateral_development_attempt_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    authorization_token = $authorizationToken
    source_commit = ("0" * 40)
    source_worktree_clean = $true
    source_matches_live_github_main = $true
    complete_zero_world_gate_passed = $true
    authority_contract_passed = $true
    expected_world_count = 53
    ordered_cell_ids = $orderedCellIds
    physical_identity_consumed = $true
    same_identity_rerun_allowed = $false
}
Write-NewJsonArtifact `
    -Value $authorizationAttempt `
    -Path $authorizationAttemptPath
$authorization = Invoke-GodotCaptured `
    -Arguments @(
        "--headless", "--path", $repoRoot,
        "--script", "res://tests/test_sdk_balanced_wave_bw21l_lateral_development.gd",
        "--", "authorization_preflight", $authorizationCellId
    ) `
    -WorkerRoot (Join-Path $preflightRoot "authorization") `
    -TimeoutSeconds 60 `
    -AttemptPath $authorizationAttemptPath `
    -AuthorizationToken $authorizationToken `
    -CellId $authorizationCellId
Assert-Exact (
    -not [bool]$authorization.timed_out -and
    [int]$authorization.exit_code -eq 0
) "$gateId valid supervisor authorization preflight failed"
$authorizationReceipt = Get-ReceiptFromOutput `
    -OutputText ([string]$authorization.stdout) `
    -Prefix $authorizationPreflightPrefix
Assert-Exact (
    [bool]$authorizationReceipt.cell_declared -and
    [bool]$authorizationReceipt.authorization_exact -and
    [int]$authorizationReceipt.actual_world_build_count -eq 0 -and
    [int]$authorizationReceipt.scene_tree_insertion_count -eq 0 -and
    -not [bool]$authorizationReceipt.physics_state_modified -and
    -not [bool]$authorizationReceipt.locomotion_outcome_exposed -and
    -not [bool]$authorizationReceipt.physical_acceptance_authority
) "$gateId valid authorization path changed or exposed a world"

$bypass = Invoke-GodotCaptured `
    -Arguments @(
        "--headless", "--path", $repoRoot,
        "--script", "res://tests/test_sdk_balanced_wave_bw21l_lateral_development.gd",
        "--", "physical", [string]$orderedCellIds[0]
    ) `
    -WorkerRoot (Join-Path $preflightRoot "bypass") `
    -TimeoutSeconds 60
Assert-Exact (
    -not [bool]$bypass.timed_out -and [int]$bypass.exit_code -ne 0 -and
    (([string]$bypass.stdout) + ([string]$bypass.stderr)).Contains(
        "physical entry requires exact retained supervisor authorization",
        [StringComparison]::Ordinal
    ) -and
    -not (([string]$bypass.stdout).Contains($cellPrefix, [StringComparison]::Ordinal))
) "$gateId direct physical-worker bypass did not fail before a world"

if ($PreflightOnly) {
    Write-Host (
        "$gateId PREFLIGHT_PASS worlds=0 entrypoints=53 adapter_starts=52 " +
        "candidates=48 controls=4 safety=1 production_gates=73 canaries=18 " +
        "authority=9/9 authorization=1/1 bypass_canaries=1 outcomes_exposed=False " +
        "validation_authority=False physical_authority=False"
    )
    exit 0
}

$status = @(& git -C $repoRoot status --porcelain=v1 --untracked-files=all)
$head = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
$liveLine = (& git -C $repoRoot ls-remote origin refs/heads/main).Trim()
$liveMain = if ([string]::IsNullOrWhiteSpace($liveLine)) {
    ""
} else {
    ($liveLine -split "\s+")[0]
}
Assert-Exact (
    $LASTEXITCODE -eq 0 -and $status.Count -eq 0 -and
    $head -cmatch "^[0-9a-f]{40}$" -and
    $head -ceq $originMain -and $head -ceq $liveMain
) "$gateId requires clean source with HEAD equal to live GitHub main"

$resolvedOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$tempRoot = [System.IO.Path]::GetFullPath($env:TEMP)
Assert-Exact (
    -not $resolvedOutputRoot.StartsWith(
        $tempRoot + [System.IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    -not (Test-Path -LiteralPath $resolvedOutputRoot)
) "$gateId OutputRoot must be new, durable, and outside the temp tree"
$expectedLeaf = "balanced-wave-bw21l-lateral-development-" + $head.Substring(0, 7)
Assert-Exact (
    [System.IO.Path]::GetFileName($resolvedOutputRoot) -ceq $expectedLeaf
) "$gateId OutputRoot leaf must be '$expectedLeaf'"
[void][System.IO.Directory]::CreateDirectory($resolvedOutputRoot)

$attemptPath = Join-Path $resolvedOutputRoot "attempt.json"
$authorizationToken = [Guid]::NewGuid().ToString("N")
$attempt = [ordered]@{
    schema_version =
        "sporespore_balanced_wave_bw21l_lateral_development_attempt_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    opened_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $head
    source_worktree_clean = $true
    source_matches_live_github_main = $true
    authorization_token = $authorizationToken
    complete_zero_world_gate_passed = $true
    authority_contract_passed = $true
    expected_world_count = 53
    ordered_cell_ids = $orderedCellIds
    physical_identity_consumed = $true
    same_identity_rerun_allowed = $false
}
Write-NewJsonArtifact -Value $attempt -Path $attemptPath

$cellAttempts = [System.Collections.Generic.List[object]]::new()
$receipts = [System.Collections.Generic.List[object]]::new()
$integrityFailureCount = 0
for ($index = 0; $index -lt $cells.Count; $index += 1) {
    $cell = $cells[$index]
    $cellId = [string]$cell.cell_id
    $cellRoot = Join-Path (
        $resolvedOutputRoot
    ) (("cell-{0:D2}-" -f ($index + 1)) + $cellId)
    [void][System.IO.Directory]::CreateDirectory($cellRoot)
    $process = Invoke-GodotCaptured `
        -Arguments @(
            "--headless", "--path", $repoRoot,
            "--script", "res://tests/test_sdk_balanced_wave_bw21l_lateral_development.gd",
            "--", "physical", $cellId
        ) `
        -WorkerRoot $cellRoot `
        -TimeoutSeconds $CellTimeoutSeconds `
        -AttemptPath $attemptPath `
        -AuthorizationToken $authorizationToken `
        -CellId $cellId
    $transcriptPath = Join-Path $cellRoot "transcript.log"
    $stderrPath = Join-Path $cellRoot "stderr.log"
    Write-Utf8NoBom -Path $transcriptPath -Text ([string]$process.stdout)
    Write-Utf8NoBom -Path $stderrPath -Text ([string]$process.stderr)
    $receipt = $null
    $parseError = ""
    try {
        $receipt = Get-ReceiptFromOutput `
            -OutputText ([string]$process.stdout) `
            -Prefix $cellPrefix
        $receipts.Add($receipt)
    } catch {
        $parseError = $_.Exception.Message
        $integrityFailureCount += 1
    }
    if ([bool]$process.timed_out) { $integrityFailureCount += 1 }
    $cellAttempts.Add([ordered]@{
        ordinal = $index + 1
        cell_id = $cellId
        process_exit_code = [int]$process.exit_code
        timed_out = [bool]$process.timed_out
        killed_process_tree = [bool]$process.killed_process_tree
        duration_seconds = [double]$process.duration_seconds
        receipt_parsed = $null -ne $receipt
        receipt_parse_error = $parseError
        transcript_path = $transcriptPath
        transcript_raw_sha256 = Get-RawSha256 -Path $transcriptPath
        stderr_path = $stderrPath
        stderr_raw_sha256 = Get-RawSha256 -Path $stderrPath
    })
}

. $productionGatePath
$claims = [ordered]@{}
foreach ($name in $script:Bw21lClaimNames) { $claims[$name] = $false }
$rawResult = [ordered]@{
    schema_version = $script:Bw21lResultSchema
    campaign_id = $campaignId
    gate_id = $gateId
    study_classification = $script:Bw21lStudyClassification
    expected_gate_count = 73
    expected_world_count = 53
    observed_world_count = $cellAttempts.Count
    integrity_failure_count = $integrityFailureCount
    engine = [ordered]@{
        physics_engine = "Jolt Physics"
        godot_version = $script:Bw21lGodotVersion
        godot_executable_sha256 = $script:Bw21lGodotExecutableSha256
        physics_hz = 120
        solver_velocity_steps = 20
        solver_position_steps = 7
    }
    source = [ordered]@{
        commit = $head
        worktree_clean = $true
        matches_live_github_main = $true
    }
    prerequisites = [ordered]@{
        bw20f_closure_raw_sha256 = $script:Bw21lBw20fClosureRawSha256
        bw20f_report_raw_sha256 = $script:Bw21lBw20fReportRawSha256
        bw20f_accepted = $false
        bw20f_same_identity_reuse_forbidden = $true
        outcomes_are_exposed_development_only = $true
    }
    declarations = [ordered]@{
        preregistration_raw_sha256 = $script:Bw21lPreregistrationRawSha256
        candidates_raw_sha256 = $script:Bw21lCandidatesRawSha256
        candidate_order = @("BW21L-A", "BW21L-B", "BW21L-C", "BW21L-D")
        baseline_candidate_id = "BW21L-A"
    }
    selector_declaration = [ordered]@{
        selection_mode =
            "complete_preregistered_lexicographic_development_selection"
        baseline_candidate_id = "BW21L-A"
        selection_vector = @(
            "walking_conjunction_failure_count",
            "aggregate_failed_production_walking_gate_count",
            "maximum_absolute_cross_track_error_m",
            "aggregate_cumulative_absolute_cross_track_error_m_s",
            "candidate_order"
        )
        strict_baseline_improvement_required = $true
        maximum_paired_regression_count = 0
    }
    cells = @($receipts)
    declared_claims = $claims
}
$rawResultPath = Join-Path $resolvedOutputRoot "raw-result.json"
Write-NewJsonArtifact -Value $rawResult -Path $rawResultPath
$evaluation = Test-Bw21lLateralDevelopmentResult -Result $rawResult
$evaluationPath = Join-Path $resolvedOutputRoot "evaluation.json"
Write-NewJsonArtifact -Value $evaluation -Path $evaluationPath

$attempt.physical_identity_consumed = $true
$attempt.completed_at_utc = [DateTime]::UtcNow.ToString("o")
$attempt.completed_cell_attempt_count = $cellAttempts.Count
$attempt.parsed_receipt_count = $receipts.Count
$attempt.integrity_failure_count = $integrityFailureCount
$attempt.evaluation_ok = [bool]$evaluation.ok
Write-Utf8NoBom `
    -Path $attemptPath `
    -Text (($attempt | ConvertTo-Json -Depth 64) + [Environment]::NewLine)

$completion = [ordered]@{
    schema_version =
        "sporespore_balanced_wave_bw21l_lateral_development_completion_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    completed_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $head
    expected_world_count = 53
    attempted_world_count = $cellAttempts.Count
    parsed_receipt_count = $receipts.Count
    integrity_failure_count = $integrityFailureCount
    evaluation_ok = [bool]$evaluation.ok
    selected_candidate_id = [string]$evaluation.selected_candidate_id
    development_selection_authority = [bool]$evaluation.development_selection_authority
    independent_validation_authority = $false
    same_identity_rerun_allowed = $false
    physical_acceptance_authority = $false
}
$completionPath = Join-Path $resolvedOutputRoot "completion.json"
Write-NewJsonArtifact -Value $completion -Path $completionPath

$report = [ordered]@{
    schema_version = "sporespore_balanced_wave_bw21l_lateral_development_report_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    completed_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $head
    first_complete_result_final_for_source_identity = $true
    evaluation_ok = [bool]$evaluation.ok
    result_status = $(if ([bool]$evaluation.ok) {
        if ([string]$evaluation.selected_candidate_id -ceq "NONE") {
            "valid_development_no_selection"
        } else {
            "valid_development_hypothesis_selected_requires_fresh_validation"
        }
    } else {
        "invalid_development_execution"
    })
    selected_candidate_id = [string]$evaluation.selected_candidate_id
    development_selection_authority = [bool]$evaluation.development_selection_authority
    independent_validation_authority = $false
    attempt_path = $attemptPath
    attempt_raw_sha256 = Get-RawSha256 -Path $attemptPath
    raw_result_path = $rawResultPath
    raw_result_raw_sha256 = Get-RawSha256 -Path $rawResultPath
    evaluation_path = $evaluationPath
    evaluation_raw_sha256 = Get-RawSha256 -Path $evaluationPath
    completion_path = $completionPath
    completion_raw_sha256 = Get-RawSha256 -Path $completionPath
    cell_attempts = @($cellAttempts)
    evaluation = $evaluation
    claim_scope = (
        "Outcome-exposed finite development evidence only. Any selected arm " +
        "requires a new campaign, fresh unexposed material values, and fresh " +
        "unexposed seeds before any validation or robustness claim."
    )
    physical_acceptance_authority = $false
}
$reportPath = Join-Path $resolvedOutputRoot "report.json"
Write-NewJsonArtifact -Value $report -Path $reportPath

if (-not [bool]$evaluation.ok) {
    throw "$gateId first complete physical result was retained but failed its integrity gate"
}
Write-Host (
    "$gateId PHYSICAL_COMPLETE worlds=53 selected=$($evaluation.selected_candidate_id) " +
    "development_selection=$($evaluation.development_selection_authority) " +
    "validation_authority=False report=$reportPath"
)

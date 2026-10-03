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
        Join-Path $env:TEMP "sporespore_bw20f_material_locomotion_preflight"
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
$campaignId = "BW20F-BW19V-COLD-MATERIAL-LOCOMOTION"
$gateId = "BW20F-LOCOMOTION"
$implementationParentCommit = "283a868e24dbbe87661289560fd3a06cba31f8e6"
$preregistrationPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_locomotion_preregistration.json"
$productionGatePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_locomotion_gate.ps1"
$gateTestPath = Join-Path (
    $repoRoot
) "tests\test_bw20f_material_locomotion_gate.ps1"
$physicalHarnessPath = Join-Path (
    $repoRoot
) "tests\test_sdk_balanced_wave_bw20f_material_locomotion.gd"
$freezeAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw20f_material_locomotion_freeze.ps1"
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_locomotion_closure.json"
$bw19vClosurePath = Join-Path $sdkRoot "balanced_wave_bw19v_closure_manifest.json"
$stage1ClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_characterization_closure.json"
$stage2ClosurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw20f_material_profile_publication_closure.json"
$profileRegistryPath = Join-Path (
    $repoRoot
) "scripts\lab\gait\sdk_godot_jolt_material_profiles.gd"
$bw19vHarnessPath = Join-Path (
    $repoRoot
) "tests\test_sdk_balanced_wave_bw19v_independent_validation.gd"
$morphologyHarnessPath = Join-Path (
    $repoRoot
) "tests\test_sdk_qsdk_independent_morphology_v2.gd"
$stage1ReportPath = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "balanced-wave-bw20f-material-characterization-476aa4e\report.json"
)
$stage2ReportPath = [System.IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
    "balanced-wave-bw20f-material-profiles-cf9431e\report.json"
)
$expectedHashes = [ordered]@{
    $preregistrationPath = "fc3749e6ce0d7a68603884c89e0ac8d5060aef8f419a375cb1ab3db39975797d"
    $productionGatePath = "354bc346d39774eda41c1c56672c932266a0c6978c535f9c0e7e22616c303257"
    $gateTestPath = "29755f581b17b81f6896655315203d5c5c74904087d47442bae9819fd0d92cb2"
    $physicalHarnessPath = "462f5bb05bf75dd437112da13e72692decd007f2edb9c6bf37b176394b0984d5"
    $bw19vClosurePath = "ea8df6a574e1b9be1050afa8ed57982a102982ada0f0d5babccf3c937c7067f7"
    $stage1ClosurePath = "68d1ba699d1dcfd9b190423fd542b18843823374cdd8f69029c4e05548e3bf2a"
    $stage2ClosurePath = "d5e08e0602f745e78b1c34cc10a95f1399a969f9ccab0fd62ff68f6a53e25f1e"
    $stage1ReportPath = "f0a279fb9660554a0d4997c6b8adb5c767bc3f92f2497694448429f142155030"
    $stage2ReportPath = "96ef9fd50da7e92b668d9552ebf821d8fe02fa8ab0a2247b93cda0a48115968f"
    $profileRegistryPath = "6344363c1218a85ffd5bed79b00e9615a74456f31787c2a8e5c48272e044255d"
    $bw19vHarnessPath = "4024bb8135c5f2b9feccc8c6501fdacfade8d63cfe382937dae4cae5c28ae7c6"
    $morphologyHarnessPath = "3365582b076ccaedf2ec5a4562abed006f42a89af85be9193436f94e179ba90e"
}
$preflightPrefix = "BW20F_MATERIAL_LOCOMOTION_PREFLIGHT "
$cellPrefix = "BW20F_MATERIAL_LOCOMOTION_CELL "

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
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
    Assert-Exact (
        -not (Test-Path -LiteralPath $Path)
    ) "Refusing to overwrite a $gateId artifact: $Path"
    [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    $temporaryPath = $Path + ".tmp"
    Assert-Exact (
        -not (Test-Path -LiteralPath $temporaryPath)
    ) "Refusing stale $gateId temporary artifact: $temporaryPath"
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
        $start.Environment["SPORESPORE_BW20F_LOCOMOTION_ATTEMPT"] = $AttemptPath
        $start.Environment["SPORESPORE_BW20F_LOCOMOTION_TOKEN"] = $AuthorizationToken
        $start.Environment["SPORESPORE_BW20F_LOCOMOTION_CELL"] = $CellId
    }
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    $startedUtc = [DateTime]::UtcNow
    if (-not $process.Start()) {
        throw "Failed to start isolated Godot"
    }
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

Assert-Exact (
    [bool]$PreflightOnly -xor [bool]$RunPhysical
) "Specify exactly one of -PreflightOnly or -RunPhysical"
Assert-Exact (
    $CellTimeoutSeconds -ge 30 -and $CellTimeoutSeconds -le 900
) "$gateId CellTimeoutSeconds must be in [30,900]"
if ($RunPhysical) {
    Assert-Exact (
        -not [string]::IsNullOrWhiteSpace($OutputRoot)
    ) "$gateId -RunPhysical requires an explicit durable OutputRoot"
    Assert-Exact (
        -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
    ) "$gateId campaign is already closed and may not rerun"
}

foreach ($entry in $expectedHashes.GetEnumerator()) {
    Assert-Exact (
        (Test-Path -LiteralPath $entry.Key -PathType Leaf) -and
        (Get-RawSha256 -Path $entry.Key) -ceq [string]$entry.Value
    ) "$gateId frozen source or prerequisite changed: $($entry.Key)"
}

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable
$cells = @($preregistration.matrix.ordered_cells)
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw20f_material_locomotion_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "frozen_before_first_bw20f_material_locomotion_world" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$preregistration.implementation_parent_commit -ceq
        $implementationParentCommit -and
    [string]$preregistration.study_class.classification -ceq
        "exact_finite_cell_material_acceptance_decision" -and
    [bool]$preregistration.study_class.finite_decision -and
    -not [bool]$preregistration.study_class.population_inference -and
    -not [bool]$preregistration.study_class.superiority_study -and
    -not [bool]$preregistration.study_class.noninferiority_or_equivalence_study -and
    [bool]$preregistration.study_class.treatment_need_not_outperform_control -and
    -not [bool]$preregistration.study_class.terminal_outcome_separation_gate -and
    $cells.Count -eq 17 -and
    [int]$preregistration.matrix.treatment_world_count -eq 12 -and
    [int]$preregistration.matrix.control_world_count -eq 4 -and
    [int]$preregistration.matrix.zero_friction_safety_world_count -eq 1 -and
    [int]$preregistration.gate_contract.expected_gate_count -eq 28 -and
    -not [bool]$preregistration.gate_contract.treatment_outcome_superiority_required -and
    -not [bool]$preregistration.gate_contract.terminal_position_separation_required
) "$gateId preregistration identity, study class, matrix, or gate changed"

$godotPath = [System.IO.Path]::GetFullPath($Godot)
Assert-Exact (
    (Test-Path -LiteralPath $godotPath -PathType Leaf) -and
    (Get-RawSha256 -Path $godotPath) -ceq
        "c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896"
) "$gateId pinned Godot executable is missing or changed"
$godotVersion = (& $godotPath --version 2>&1 | Out-String).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $godotVersion -ceq "4.7.stable.mono.official.5b4e0cb0f"
) "$gateId pinned Godot version changed"

# The same pure evaluator used after physical execution must first accept a
# perfect serialized result while all declared canaries fail closed.
& pwsh -NoProfile -File $gateTestPath
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId complete synthetic production-gate preflight failed"
. $productionGatePath
$perfect = New-Bw20fPerfectSyntheticMaterialLocomotionResult
$perfectEvaluation = Test-Bw20fMaterialLocomotionResult -Result $perfect
Assert-Exact (
    [bool]$perfectEvaluation.ok -and
    [int]$perfectEvaluation.reconstructed_passed_gate_count -eq 28 -and
    [int]$perfectEvaluation.observed_world_count -eq 17 -and
    [int]$perfectEvaluation.cell_pass_count -eq 17
) "$gateId production evaluator rejected its perfect synthetic result"

$runToken = (
    (Get-Date -Format "yyyyMMddTHHmmssfff") + "-" +
    [Guid]::NewGuid().ToString("N").Substring(0, 8)
)
$tempRoot = Join-Path ([System.IO.Path]::GetFullPath($LogRoot)) $runToken
$projectRoot = Join-Path $tempRoot "project"
[void][System.IO.Directory]::CreateDirectory($projectRoot)
foreach ($directory in @("scripts", "tests", "sdk")) {
    [void](New-Item `
        -ItemType Junction `
        -Path (Join-Path $projectRoot $directory) `
        -Target (Join-Path $repoRoot $directory))
}
$projectText = @"
; Isolated SporeSpore BW20F material-locomotion campaign.

config_version=5

[application]

config/name="sporespore-bw20f-material-locomotion"
config/features=PackedStringArray("4.7", "Forward Plus")

[debug]

gdscript/warnings/shadowed_global_identifier=0

[physics]

3d/physics_engine="Jolt Physics"
jolt_physics_3d/simulation/velocity_steps=20
jolt_physics_3d/simulation/position_steps=7
"@
Write-Utf8NoBom -Path (Join-Path $projectRoot "project.godot") -Text $projectText

$entrypointExecution = Invoke-GodotCaptured `
    -Arguments @(
        "--headless",
        "--path", $projectRoot,
        "--script", "res://tests/test_sdk_balanced_wave_bw20f_material_locomotion.gd",
        "--", "preflight"
    ) `
    -WorkerRoot (Join-Path $tempRoot "preflight-entrypoint") `
    -TimeoutSeconds 300
$entrypointReceipt = Get-ReceiptFromOutput `
    -OutputText ([string]$entrypointExecution.stdout) `
    -Prefix $preflightPrefix
Assert-Exact (
    [int]$entrypointExecution.exit_code -eq 0 -and
    -not [bool]$entrypointExecution.timed_out -and
    [string]$entrypointReceipt.schema_version -ceq
        "sporespore_balanced_wave_bw20f_material_locomotion_entrypoint_preflight_v1" -and
    [bool]$entrypointReceipt.ok -and
    [string]$entrypointReceipt.campaign_id -ceq $campaignId -and
    [string]$entrypointReceipt.gate_id -ceq $gateId -and
    [int]$entrypointReceipt.entrypoint_count -eq 17 -and
    [int]$entrypointReceipt.treatment_entrypoint_count -eq 12 -and
    [int]$entrypointReceipt.control_entrypoint_count -eq 4 -and
    [int]$entrypointReceipt.safety_entrypoint_count -eq 1 -and
    [int]$entrypointReceipt.adapter_start_count -eq 16 -and
    [int]$entrypointReceipt.actual_world_build_count -eq 0 -and
    [int]$entrypointReceipt.scene_tree_insertion_count -eq 0 -and
    -not [bool]$entrypointReceipt.physics_state_modified -and
    -not [bool]$entrypointReceipt.locomotion_outcome_exposed -and
    -not [bool]$entrypointReceipt.physical_acceptance_authority
) "$gateId real 17-cell entrypoint preflight failed before any world"

if ($PreflightOnly) {
    Write-Host (
        "$gateId PREFLIGHT_PASS production_gates=28 cells=17 " +
        "treatments=12 controls=4 safety=1 adapter_starts=16 canaries=12 " +
        "worlds=0 scene_insertions=0 terminal_separation_gate=False " +
        "superiority=False physical_authority=False"
    )
    return
}

$resolvedOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$evidencePrefix = $evidenceRoot.TrimEnd("\") + "\"
Assert-Exact (
    $resolvedOutputRoot.StartsWith(
        $evidencePrefix,
        [StringComparison]::OrdinalIgnoreCase
    )
) "$gateId OutputRoot must be inside $evidenceRoot"
Assert-Exact (
    -not $resolvedOutputRoot.StartsWith(
        "C:\tmp\",
        [StringComparison]::OrdinalIgnoreCase
    )
) "$gateId retained evidence may not use C:\tmp"
Assert-Exact (
    -not (Test-Path -LiteralPath $resolvedOutputRoot)
) "$gateId OutputRoot already exists: $resolvedOutputRoot"

$sourceStatus = @(
    & git -C $repoRoot status --porcelain=v1 --untracked-files=all
)
$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$originMainCommit = (& git -C $repoRoot rev-parse origin/main).Trim()
$remoteLine = (& git -C $repoRoot ls-remote origin refs/heads/main).Trim()
$remoteMainCommit = ($remoteLine -split "\s+")[0]
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $sourceStatus.Count -eq 0 -and
    $sourceCommit -cmatch "^[0-9a-f]{40}$" -and
    $sourceCommit -cne $implementationParentCommit -and
    $sourceCommit -ceq $originMainCommit -and
    $sourceCommit -ceq $remoteMainCommit
) "$gateId requires clean source with HEAD equal to live GitHub main"
$expectedLeaf = (
    "balanced-wave-bw20f-material-locomotion-" +
    $sourceCommit.Substring(0, 7)
)
Assert-Exact (
    (Split-Path -Leaf $resolvedOutputRoot) -ceq $expectedLeaf
) "$gateId OutputRoot must be named $expectedLeaf"

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
                $prior = Get-Content -Raw -LiteralPath $_.FullName |
                    ConvertFrom-Json
                [string]$prior.campaign_id -ceq $campaignId
            } catch {
                $false
            }
        }
    )
}
Assert-Exact (
    $priorAttempts.Count -eq 0
) "$gateId already has a retained physical attempt and may not rerun"
Assert-Exact (
    Test-Path -LiteralPath $freezeAuditPath -PathType Leaf
) "$gateId prospective freeze audit is missing"
& pwsh -NoProfile -File $freezeAuditPath -SkipSupervisorPreflight
Assert-Exact (
    $LASTEXITCODE -eq 0
) "$gateId executable freeze audit failed before physical entry"

[void][System.IO.Directory]::CreateDirectory($resolvedOutputRoot)
$entrypointTranscriptPath = Join-Path $resolvedOutputRoot "preflight-transcript.log"
$entrypointStderrPath = Join-Path $resolvedOutputRoot "preflight-stderr.log"
Write-Utf8NoBom `
    -Path $entrypointTranscriptPath `
    -Text ([string]$entrypointExecution.stdout)
Write-Utf8NoBom `
    -Path $entrypointStderrPath `
    -Text ([string]$entrypointExecution.stderr)

$attemptPath = Join-Path $resolvedOutputRoot "attempt.json"
$authorizationToken = [Guid]::NewGuid().ToString("N")
$attempt = [ordered]@{
    schema_version =
        "sporespore_balanced_wave_bw20f_material_locomotion_attempt_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    launched_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $sourceCommit
    origin_main_commit = $originMainCommit
    remote_main_commit = $remoteMainCommit
    source_worktree_clean = $true
    source_matches_live_github_main = $true
    godot_version = $godotVersion
    godot_executable_sha256 = Get-RawSha256 -Path $godotPath
    preregistration_raw_sha256 = Get-RawSha256 -Path $preregistrationPath
    production_gate_raw_sha256 = Get-RawSha256 -Path $productionGatePath
    complete_zero_world_gate_passed = $true
    entrypoint_preflight_passed = $true
    expected_gate_count = 28
    expected_world_count = 17
    ordered_cell_ids = @($cells | ForEach-Object { [string]$_.cell_id })
    authorization_token = $authorizationToken
    physical_identity_consumed = $true
    same_identity_rerun_allowed = $false
    physical_acceptance_authority = $false
}
Write-NewJsonArtifact -Value $attempt -Path $attemptPath

$cellAttempts = [System.Collections.Generic.List[object]]::new()
$receipts = [System.Collections.Generic.List[object]]::new()
$worldOrdinal = 0
foreach ($cell in $cells) {
    $worldOrdinal += 1
    $cellId = [string]$cell.cell_id
    Write-Host "$gateId world $worldOrdinal/17: $cellId"
    $cellRoot = Join-Path $resolvedOutputRoot ("cell-{0:D2}-{1}" -f $worldOrdinal, $cellId)
    [void][System.IO.Directory]::CreateDirectory($cellRoot)
    $engineLogPath = Join-Path $cellRoot "engine.log"
    $execution = Invoke-GodotCaptured `
        -Arguments @(
            "--headless",
            "--path", $projectRoot,
            "--log-file", $engineLogPath,
            "--script", "res://tests/test_sdk_balanced_wave_bw20f_material_locomotion.gd",
            "--", "physical", $cellId
        ) `
        -WorkerRoot (Join-Path $tempRoot ("worker-{0:D2}" -f $worldOrdinal)) `
        -TimeoutSeconds $CellTimeoutSeconds `
        -AttemptPath $attemptPath `
        -AuthorizationToken $authorizationToken `
        -CellId $cellId
    $transcriptPath = Join-Path $cellRoot "transcript.log"
    $stderrPath = Join-Path $cellRoot "stderr.log"
    Write-Utf8NoBom -Path $transcriptPath -Text ([string]$execution.stdout)
    Write-Utf8NoBom -Path $stderrPath -Text ([string]$execution.stderr)
    $receipt = $null
    $parseError = ""
    try {
        $receipt = Get-ReceiptFromOutput `
            -OutputText ([string]$execution.stdout) `
            -Prefix $cellPrefix
    } catch {
        $parseError = $_.Exception.Message
    }
    if ($null -ne $receipt) {
        $receipts.Add($receipt)
    } else {
        $receipts.Add([ordered]@{
            cell_id = $cellId
            receipt_missing = $true
            receipt_parse_error = $parseError
        })
    }
    $cellAttempts.Add([ordered]@{
        ordinal = $worldOrdinal
        cell_id = $cellId
        process_exit_code = [int]$execution.exit_code
        timed_out = [bool]$execution.timed_out
        killed_process_tree = [bool]$execution.killed_process_tree
        duration_seconds = [double]$execution.duration_seconds
        receipt_parsed = $null -ne $receipt
        receipt_parse_error = $parseError
        transcript_path = [System.IO.Path]::GetRelativePath(
            $resolvedOutputRoot,
            $transcriptPath
        ).Replace("\", "/")
        transcript_raw_sha256 = Get-RawSha256 -Path $transcriptPath
        stderr_path = [System.IO.Path]::GetRelativePath(
            $resolvedOutputRoot,
            $stderrPath
        ).Replace("\", "/")
        stderr_raw_sha256 = Get-RawSha256 -Path $stderrPath
        engine_log_path = [System.IO.Path]::GetRelativePath(
            $resolvedOutputRoot,
            $engineLogPath
        ).Replace("\", "/")
        engine_log_raw_sha256 = $(if (
            Test-Path -LiteralPath $engineLogPath -PathType Leaf
        ) { Get-RawSha256 -Path $engineLogPath } else { "" })
    })
}

$integrityFailureCount = @($receipts | Where-Object {
    -not [bool](Get-Bw20fLocomotionMapValue (
        $_
    ) "common_execution_integrity" $false)
}).Count
$rawResult = [ordered]@{
    schema_version =
        "sporespore_balanced_wave_bw20f_material_locomotion_result_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    study_classification = "exact_finite_cell_material_acceptance_decision"
    expected_gate_count = 28
    expected_world_count = 17
    observed_world_count = 17
    integrity_failure_count = $integrityFailureCount
    engine = [ordered]@{
        physics_engine = "Jolt Physics"
        godot_version = $godotVersion
        godot_executable_sha256 = Get-RawSha256 -Path $godotPath
        physics_hz = 120
        solver_velocity_steps = 20
        solver_position_steps = 7
    }
    source = [ordered]@{
        commit = $sourceCommit
        worktree_clean = $true
        matches_live_github_main = $true
    }
    prerequisites = [ordered]@{
        bw19v_closure_raw_sha256 = Get-RawSha256 -Path $bw19vClosurePath
        stage_1_closure_raw_sha256 = Get-RawSha256 -Path $stage1ClosurePath
        stage_2_closure_raw_sha256 = Get-RawSha256 -Path $stage2ClosurePath
        stage_1_report_raw_sha256 = Get-RawSha256 -Path $stage1ReportPath
        stage_2_report_raw_sha256 = Get-RawSha256 -Path $stage2ReportPath
        profile_publication_closed_positive = $true
        bw19v_finite_validation_closed_positive = $true
    }
    cells = @($receipts)
    declared_claims = [ordered]@{
        accepted = $false
        walking_acceptance = $false
        bounded_discrete_material_robustness = $false
        material_robustness = $false
        continuous_friction_coverage = $false
        arbitrary_material_robustness = $false
        population_inference = $false
        superiority = $false
        noninferiority_or_equivalence = $false
        rough_terrain_robustness = $false
        external_push_recovery = $false
        sensor_noise_or_latency_robustness = $false
        cross_engine_equivalence = $false
        arbitrary_quadruped_coverage = $false
        continuous_full_volume_coverage = $false
        release_authorized = $false
        completed_engine_neutral_sdk = $false
        physical_acceptance_authority = $false
    }
}
$rawResultPath = Join-Path $resolvedOutputRoot "raw-result.json"
Write-NewJsonArtifact -Value $rawResult -Path $rawResultPath
$evaluation = Test-Bw20fMaterialLocomotionResult -Result $rawResult
$evaluationPath = Join-Path $resolvedOutputRoot "evaluation.json"
Write-NewJsonArtifact -Value $evaluation -Path $evaluationPath

$reportPath = Join-Path $resolvedOutputRoot "report.json"
$report = [ordered]@{
    schema_version =
        "sporespore_balanced_wave_bw20f_material_locomotion_report_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    completed_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $sourceCommit
    source_worktree_clean = $true
    source_matches_live_github_main = $true
    first_complete_result_final_for_source_identity = $true
    accepted = [bool]$evaluation.ok
    result_status = $(if ([bool]$evaluation.ok) {
        "accepted_exact_finite_material_locomotion"
    } else {
        "rejected_exact_finite_material_locomotion"
    })
    attempt_path = "attempt.json"
    attempt_raw_sha256 = Get-RawSha256 -Path $attemptPath
    raw_result_path = "raw-result.json"
    raw_result_raw_sha256 = Get-RawSha256 -Path $rawResultPath
    evaluation_path = "evaluation.json"
    evaluation_raw_sha256 = Get-RawSha256 -Path $evaluationPath
    preflight_transcript_path = "preflight-transcript.log"
    preflight_transcript_raw_sha256 = Get-RawSha256 -Path $entrypointTranscriptPath
    cell_attempts = @($cellAttempts)
    evaluation = $evaluation
    claim_scope = [ordered]@{
        exact_fixed_reference_quadruped = [bool]$evaluation.ok
        exact_four_published_profiles = [bool]$evaluation.ok
        exact_three_treatment_seeds_per_profile = [bool]$evaluation.ok
        continuous_friction_coverage = $false
        arbitrary_material_robustness = $false
        arbitrary_quadruped_coverage = $false
        cross_engine_equivalence = $false
        release_authorized = $false
        completed_engine_neutral_sdk = $false
    }
    physical_acceptance_authority = $false
}
Write-NewJsonArtifact -Value $report -Path $reportPath

$completionPath = Join-Path $resolvedOutputRoot "completion.json"
$completion = [ordered]@{
    schema_version =
        "sporespore_balanced_wave_bw20f_material_locomotion_completion_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    completed_at_utc = [DateTime]::UtcNow.ToString("o")
    source_commit = $sourceCommit
    report_path = "report.json"
    report_raw_sha256 = Get-RawSha256 -Path $reportPath
    accepted = [bool]$evaluation.ok
    expected_world_count = 17
    attempted_world_count = 17
    passed_gate_count = [int]$evaluation.reconstructed_passed_gate_count
    failed_gate_count = [int]$evaluation.reconstructed_failed_gate_count
    same_identity_rerun_allowed = $false
    physical_acceptance_authority = $false
}
Write-NewJsonArtifact -Value $completion -Path $completionPath

Write-Host (
    "$gateId CAMPAIGN_COMPLETE accepted=$([bool]$evaluation.ok) " +
    "gates=$([int]$evaluation.reconstructed_passed_gate_count)/28 worlds=17 " +
    "treatments=$([int]$evaluation.treatment_count)/12 " +
    "controls=$([int]$evaluation.control_count)/4 safety=$([int]$evaluation.safety_count)/1 " +
    "terminal_separation_gate=False superiority=False report=$reportPath"
)
if (-not [bool]$evaluation.ok) {
    throw "$gateId first complete physical result was retained and rejected"
}

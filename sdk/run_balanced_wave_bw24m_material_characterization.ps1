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
        Join-Path $env:TEMP "sporespore_bw24m_material_preflight"
    ),
    [string]$OutputRoot = "",
    [int]$ProcessTimeoutSeconds = 900
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$evidenceRoot = [System.IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$campaignId = "BW24M-BW23Y-FRESH-MATERIAL-CHARACTERIZATION"
$gateId = "BW24M"
$implementationParentCommit = "f6667c153679adb8e66c3e95da30e77435a7976e"
$preregistrationPath = Join-Path (
    $sdkRoot
) "balanced_wave_bw24m_fresh_material_preregistration.json"
$freezePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw24m_material_characterization_freeze.json"
$productionGatePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw24m_material_characterization_gate.ps1"
$gateTestPath = Join-Path (
    $repoRoot
) "tests\test_bw24m_material_characterization_gate.ps1"
$declarationAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw24m_material_declaration.ps1"
$physicalWorkerPath = Join-Path (
    $repoRoot
) "tests\test_sdk_balanced_wave_bw24m_material_characterization.gd"
$freezeAuditPath = Join-Path (
    $repoRoot
) "tests\test_bw24m_material_characterization_freeze.ps1"
$closurePath = Join-Path (
    $sdkRoot
) "balanced_wave_bw24m_material_characterization_closure.json"
$receiptPrefix = "BALANCED_WAVE_BW24M_MATERIAL_CHARACTERIZATION_RECEIPT "
$authorizationPrefix = (
    "BW24M_MATERIAL_CHARACTERIZATION_AUTHORIZATION_PREFLIGHT "
)
$expectedHashes = [ordered]@{
    $preregistrationPath = "7e622d2ef25cc3d0224e95f21cd00fff3a60ac96c8179e6ccfe36f0043375815"
    $productionGatePath = "e9761ddc0c242e108c8ef178bab266f8731ace2f087f05b96304404f3eb4085c"
    $gateTestPath = "51b78130df272dce2c39b3f959305dc7fccd12f3eb3d648b37c0a64d538b8bdf"
    $declarationAuditPath = "834a4b1516f25f0b9bfe51401812efef220692a06fe074df18499a1e9b994fb3"
    (Join-Path $sdkRoot "run_balanced_wave_bw24m_material_declaration_preflight.ps1") =
        "e5376e695e60060c98d63aebae4d01ba39430cd94f20c2c2657283fb25069f38"
    (Join-Path $repoRoot "tests\test_sdk_balanced_wave_bw24m_material_preflight.gd") =
        "bd11397e7062c56232fe29b54c49adf95671bd72281096e92abe9d1af72a07e7"
    $physicalWorkerPath = "9dd5e6e8d4311cdea9dc0f7a87a6cadce2399630eec789bd682176094bc51d39"
    (Join-Path $repoRoot "tests\test_sdk_godot_jolt_friction_ladder_characterization.gd") =
        "2c07053fcce9d0982cf533b1eac65955bb4e3a57e1507fdb20284fc7c6f17c1e"
    (Join-Path $repoRoot "scripts\lab\rigs\sdk_bw24m_friction_ladder_sled_rig.gd") =
        "72170b65a934c47758bdce08e1589ba2e81a7222e1e890554a35c50c1951cf3b"
    (Join-Path $repoRoot "scripts\lab\rigs\sdk_friction_ladder_sled_rig.gd") =
        "bcd40080800669492dbc0633d5aa95ed11461d7ae29756c05e892b3467ccd014"
    (Join-Path $repoRoot "scripts\lab\rigs\friction_sled_rig.gd") =
        "92f7983a47257e7d3ee7e262ad57aee2c7cd5c345f54f6ce9981da8dd3beb487"
    (Join-Path $repoRoot "scripts\lab\capture_clock.gd") =
        "f2f0305ce698d17d892057e160928bbebd29bac21c290aa22bf4b112205f1291"
    (Join-Path $repoRoot "scripts\lab\observer_profile.gd") =
        "645844c8534d8c1c0fe693b7dc2c926a3732c3fa020c81cc2240edc5639f8fd2"
    (Join-Path $repoRoot "scripts\lab\mechanics\observed_rigid_body.gd") =
        "04c95729af1f755f270d07caa97d822d4b86afeeb3b6bcb246b4d68a5284be91"
    (Join-Path $repoRoot "scripts\lab\mechanics\contact_capacity.gd") =
        "8d91b6a9b774f6d51a14fa4eb5672f7779051ed35075cd73d1ac31ecea63c2ca"
    (Join-Path $repoRoot "scripts\lab\mechanics\contact_canonicalizer.gd") =
        "ecc22a205123ef486faa61cbf66c33b6d05b98d3bf1ff2e8b24021bba326089c"
    (Join-Path $repoRoot "scripts\lab\mechanics\contact_slip_observer.gd") =
        "b153ecd8e6d7a4cc867ef8787d9a8cc97ea15cc4a35994dcd4be3640f2c3834b"
    (Join-Path $repoRoot "scripts\lab\mechanics\friction_breakaway_analyzer.gd") =
        "b9efc3397d41609ea6d00d6d3e14c96ea0bb1a61ec0b7a9145a63ab5edcc8a14"
    (Join-Path $repoRoot "scripts\lab\canonical_json.gd") =
        "b1f0f4df813663008824d223165577e281bffb97e81080d33d77c1ffb031501f"
    (Join-Path $repoRoot "scripts\lab\frozen_value.gd") =
        "b45d91510d6f42a3cccc87bb9ea40c602469fed11338860512a832361a835d10"
    (Join-Path $repoRoot "scripts\lab\failure_codes.gd") =
        "9cc79d962ad70b12c932685f8aee3996d62b631d664af57525df8726edfc3456"
    (Join-Path $repoRoot "scripts\lab\finite_sanitizer.gd") =
        "40428eb592bda785be76d32869f63fb55fe8e40ac038a8daf94c976414e6e444"
}

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
    Assert-Exact ($lines.Count -eq 1) (
        "Expected exactly one '$Prefix' receipt, found $($lines.Count)"
    )
    return (
        $lines[0].Substring($Prefix.Length) |
            ConvertFrom-Json -AsHashtable
    )
}

function Invoke-GodotCaptured {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$RunRoot,
        [string]$AttemptPath = "",
        [string]$AuthorizationToken = ""
    )
    $appData = Join-Path $RunRoot "appdata"
    $localAppData = Join-Path $RunRoot "localappdata"
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
        $start.Environment["SPORESPORE_BW24M_ATTEMPT"] = $AttemptPath
        $start.Environment["SPORESPORE_BW24M_TOKEN"] = $AuthorizationToken
    }
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    $startedUtc = [DateTime]::UtcNow
    Assert-Exact ($process.Start()) "Failed to start pinned Godot"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($ProcessTimeoutSeconds * 1000)
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
        combined_output = $stdout + [Environment]::NewLine + $stderr
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
    $ProcessTimeoutSeconds -ge 60 -and $ProcessTimeoutSeconds -le 3600
) "$gateId ProcessTimeoutSeconds must be in [60,3600]"
if ($RunPhysical) {
    Assert-Exact (-not [string]::IsNullOrWhiteSpace($OutputRoot)) (
        "$gateId -RunPhysical requires an explicit durable OutputRoot"
    )
    Assert-Exact (-not (Test-Path -LiteralPath $closurePath -PathType Leaf)) (
        "$gateId characterization is already closed and may not rerun"
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
Assert-Exact (
    [string]$preregistration.schema_version -ceq
        "sporespore_balanced_wave_bw24m_fresh_material_preregistration_v1" -and
    [string]$preregistration.status -ceq
        "prospective_declaration_preflight_only_physical_execution_blocked" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [string]$preregistration.gate_id -ceq $gateId -and
    [string]$preregistration.implementation_parent_commit -ceq
        $implementationParentCommit -and
    [string]$preregistration.pipeline_stages.stage_1_material_characterization.status -ceq
        "blocked_until_complete_production_gate_supervisor_and_freeze_are_committed_and_pushed" -and
    [int]$preregistration.material_characterization.expected_world_count -eq 10 -and
    [int]$preregistration.material_characterization.expected_gate_count -eq 19 -and
    (@($preregistration.material_characterization.authored_friction_values) -join ",") -ceq
        "0.59,0.71,0.83" -and
    -not [bool]$preregistration.claims_if_stage_1_passes.material_robustness -and
    -not [bool]$preregistration.claims_if_stage_1_passes.physical_acceptance_authority
) "$gateId frozen preregistration identity or claim boundary changed"
$freeze = Get-Content -Raw -LiteralPath $freezePath |
    ConvertFrom-Json -AsHashtable
Assert-Exact (
    [string]$freeze.schema_version -ceq
        "sporespore_balanced_wave_bw24m_material_characterization_freeze_v1" -and
    [string]$freeze.status -ceq "frozen_before_first_bw24m_physical_world" -and
    [string]$freeze.campaign_id -ceq $campaignId -and
    [string]$freeze.gate_id -ceq $gateId -and
    [int]$freeze.study_class.expected_world_count -eq 10 -and
    [int]$freeze.study_class.expected_gate_count -eq 19 -and
    -not [bool]$freeze.claims_after_positive_characterization.material_robustness -and
    -not [bool]$freeze.claims_after_positive_characterization.physical_acceptance_authority
) "$gateId stage-one freeze identity or claim boundary changed"

$godotPath = [System.IO.Path]::GetFullPath($Godot)
Assert-Exact (
    Test-Path -LiteralPath $godotPath -PathType Leaf
) "Godot executable not found: $godotPath"
$godotLauncherSha256 = Get-RawSha256 -Path $godotPath
$godotVersion = (& $godotPath --version 2>&1 | Out-String).Trim()
$godotVersionExitCode = $LASTEXITCODE
$runtimePath = [System.Text.RegularExpressions.Regex]::Replace(
    $godotPath,
    "_console\.exe$",
    ".exe",
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)
Assert-Exact (
    $godotVersionExitCode -eq 0 -and
    $godotVersion -ceq [string]$preregistration.host_identity.godot_version -and
    $godotLauncherSha256 -ceq
        [string]$preregistration.host_identity.godot_launcher_executable_sha256 -and
    (Test-Path -LiteralPath $runtimePath -PathType Leaf) -and
    (Get-RawSha256 -Path $runtimePath) -ceq
        [string]$preregistration.host_identity.godot_runtime_executable_sha256
) "$gateId pinned Godot launcher or runtime identity changed"

& pwsh -NoProfile -File $gateTestPath
Assert-Exact ($LASTEXITCODE -eq 0) (
    "$gateId complete synthetic production-gate test failed"
)
. $productionGatePath
$perfectReceipt = New-Bw24mPerfectSyntheticCharacterizationReceipt
$perfectEvaluation = Test-Bw24mMaterialCharacterizationReceipt `
    -Receipt $perfectReceipt
Assert-Exact (
    [bool]$perfectEvaluation.ok -and
    [int]$perfectEvaluation.reconstructed_passed_gate_count -eq 19 -and
    [int]$perfectEvaluation.observed_world_count -eq 10 -and
    @($perfectEvaluation.failure_codes).Count -eq 0
) "$gateId perfect synthetic receipt did not pass its production evaluator"

& pwsh -NoProfile -File $declarationAuditPath -Godot $godotPath
Assert-Exact ($LASTEXITCODE -eq 0) (
    "$gateId stage-zero declaration and fixture preflight failed"
)

$preflightRoot = Join-Path (
    [System.IO.Path]::GetFullPath($LogRoot)
) ((Get-Date -Format "yyyyMMddTHHmmssfff") + "-" + [Guid]::NewGuid().ToString("N"))
[void][System.IO.Directory]::CreateDirectory($preflightRoot)
$preflightAttemptPath = Join-Path $preflightRoot "authorization-attempt.json"
$preflightToken = [Guid]::NewGuid().ToString("N")
$preflightAttempt = [ordered]@{
    schema_version =
        "sporespore_balanced_wave_bw24m_material_characterization_attempt_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    authorization_token = $preflightToken
    source_commit = "0" * 40
    source_worktree_clean = $true
    source_matches_live_github_main = $true
    complete_synthetic_production_gate_passed = $true
    zero_world_fixture_preflight_passed = $true
    physical_process_launch_reserved_identity_consumed = $true
    same_identity_rerun_allowed = $false
    expected_world_count = 10
    expected_gate_count = 19
    physical_acceptance_authority = $false
}
Write-NewJsonArtifact -Value $preflightAttempt -Path $preflightAttemptPath
$workerArguments = @(
    "--headless", "--path", $repoRoot,
    "--script", "res://tests/test_sdk_balanced_wave_bw24m_material_characterization.gd"
)
$authorization = Invoke-GodotCaptured `
    -Arguments ($workerArguments + @("--", "--authorization-preflight")) `
    -RunRoot (Join-Path $preflightRoot "authorization") `
    -AttemptPath $preflightAttemptPath `
    -AuthorizationToken $preflightToken
$authorizationReceipt = Get-ReceiptFromOutput `
    -OutputText $authorization.combined_output `
    -Prefix $authorizationPrefix
Assert-Exact (
    [int]$authorization.exit_code -eq 0 -and
    -not [bool]$authorization.timed_out -and
    [bool]$authorizationReceipt.authorization_exact -and
    [int]$authorizationReceipt.world_build_count -eq 0 -and
    [int]$authorizationReceipt.scene_tree_insertion_count -eq 0 -and
    -not [bool]$authorizationReceipt.physics_state_modified -and
    -not [bool]$authorizationReceipt.characterization_outcome_exposed -and
    -not [bool]$authorizationReceipt.physical_acceptance_authority
) "$gateId exact authorization preflight failed"

$mismatched = Invoke-GodotCaptured `
    -Arguments ($workerArguments + @("--", "--authorization-preflight")) `
    -RunRoot (Join-Path $preflightRoot "mismatched-token") `
    -AttemptPath $preflightAttemptPath `
    -AuthorizationToken ("wrong-" + $preflightToken)
$mismatchedReceipt = Get-ReceiptFromOutput `
    -OutputText $mismatched.combined_output `
    -Prefix $authorizationPrefix
Assert-Exact (
    [int]$mismatched.exit_code -ne 0 -and
    -not [bool]$mismatchedReceipt.authorization_exact -and
    [int]$mismatchedReceipt.world_build_count -eq 0 -and
    -not [bool]$mismatchedReceipt.characterization_outcome_exposed
) "$gateId mismatched authorization token did not fail closed"

$bypass = Invoke-GodotCaptured `
    -Arguments ($workerArguments + @("--", "--run-physical")) `
    -RunRoot (Join-Path $preflightRoot "direct-bypass")
Assert-Exact (
    [int]$bypass.exit_code -ne 0 -and
    $bypass.combined_output.Contains(
        "BW24M_PHYSICAL_AUTHORIZATION_REQUIRED",
        [StringComparison]::Ordinal
    )
) "$gateId direct physical-worker bypass did not fail before world entry"

if ($PreflightOnly) {
    Write-Host (
        "BW24M_MATERIAL_CHARACTERIZATION_PREFLIGHT_PASS " +
        "production_gates=19 fixture_gates=10 canaries=12 worlds=0 " +
        "scene_insertions=0 physical_authority=False"
    )
    return
}

$resolvedOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$evidencePrefix = $evidenceRoot.TrimEnd("\") + "\"
Assert-Exact (
    $resolvedOutputRoot.StartsWith(
        $evidencePrefix,
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    -not $resolvedOutputRoot.StartsWith(
        "C:\tmp\",
        [StringComparison]::OrdinalIgnoreCase
    ) -and
    -not (Test-Path -LiteralPath $resolvedOutputRoot)
) "$gateId OutputRoot must be new and inside $evidenceRoot"

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
    "balanced-wave-bw24m-material-characterization-" +
    $sourceCommit.Substring(0, 7)
)
Assert-Exact (
    (Split-Path -Leaf $resolvedOutputRoot) -ceq $expectedLeaf
) "$gateId OutputRoot must be named $expectedLeaf"

Assert-Exact (
    Test-Path -LiteralPath $freezeAuditPath -PathType Leaf
) "$gateId executable freeze audit is missing"
& pwsh -NoProfile -File $freezeAuditPath -SkipSupervisorPreflight
Assert-Exact ($LASTEXITCODE -eq 0) (
    "$gateId executable freeze audit failed before physical entry"
)
Assert-NoPriorAttempt

[void][System.IO.Directory]::CreateDirectory($resolvedOutputRoot)
$attemptPath = Join-Path $resolvedOutputRoot "attempt.json"
$authorizationToken = [Guid]::NewGuid().ToString("N")
$attempt = [ordered]@{
    schema_version =
        "sporespore_balanced_wave_bw24m_material_characterization_attempt_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    launched_at_utc = [DateTime]::UtcNow.ToString("o")
    authorization_token = $authorizationToken
    source_commit = $sourceCommit
    origin_main_commit = $originMainCommit
    remote_main_commit = $remoteMainCommit
    source_worktree_clean = $true
    source_matches_live_github_main = $true
    godot_version = $godotVersion
    godot_launcher_executable_sha256 = $godotLauncherSha256
    godot_runtime_executable_sha256 = Get-RawSha256 -Path $runtimePath
    preregistration_raw_sha256 = Get-RawSha256 -Path $preregistrationPath
    complete_synthetic_production_gate_passed = $true
    zero_world_fixture_preflight_passed = $true
    physical_process_launch_reserved_identity_consumed = $true
    same_identity_rerun_allowed = $false
    expected_world_count = 10
    expected_gate_count = 19
    locomotion_world_count = 0
    physical_acceptance_authority = $false
}
Write-NewJsonArtifact -Value $attempt -Path $attemptPath

$physical = Invoke-GodotCaptured `
    -Arguments ($workerArguments + @("--", "--run-physical")) `
    -RunRoot (Join-Path $resolvedOutputRoot "worker") `
    -AttemptPath $attemptPath `
    -AuthorizationToken $authorizationToken
$transcriptPath = Join-Path $resolvedOutputRoot "transcript.log"
$engineLogPath = Join-Path $resolvedOutputRoot "engine.log"
Write-Utf8NoBom -Path $transcriptPath -Text $physical.stdout
Write-Utf8NoBom -Path $engineLogPath -Text $physical.stderr

$receipt = $null
$receiptParseFailure = ""
try {
    $receipt = Get-ReceiptFromOutput `
        -OutputText $physical.combined_output `
        -Prefix $receiptPrefix
} catch {
    $receiptParseFailure = $_.Exception.Message
}
$evaluation = [ordered]@{
    ok = $false
    failure_codes = @("BW24M_RECEIPT_MISSING_OR_AMBIGUOUS")
    physical_acceptance_authority = $false
}
if ($null -ne $receipt) {
    $receipt.engine["operating_system_family"] = "windows"
    $receipt.engine["godot_version"] = $godotVersion
    $receipt.engine["godot_launcher_executable_sha256"] = $godotLauncherSha256
    $receipt.engine["godot_runtime_executable_sha256"] =
        Get-RawSha256 -Path $runtimePath
    $receipt.engine["host_attestation_source"] =
        "supervisor_plus_zero_world_runtime_readback"
    $evaluation = Test-Bw24mMaterialCharacterizationReceipt -Receipt $receipt
}
$accepted = (
    [int]$physical.exit_code -eq 0 -and
    -not [bool]$physical.timed_out -and
    $null -ne $receipt -and
    [bool]$evaluation.ok
)

$sources = [ordered]@{}
foreach ($entry in $expectedHashes.GetEnumerator()) {
    $relativePath = [System.IO.Path]::GetRelativePath($repoRoot, $entry.Key)
    $sources[$relativePath.Replace("\", "/")] = [ordered]@{
        path = $relativePath.Replace("\", "/")
        sha256 = Get-RawSha256 -Path $entry.Key
    }
}
foreach ($additionalPath in @(
    $PSCommandPath,
    $freezePath,
    $freezeAuditPath
)) {
    $relativePath = [System.IO.Path]::GetRelativePath($repoRoot, $additionalPath)
    $sources[$relativePath.Replace("\", "/")] = [ordered]@{
        path = $relativePath.Replace("\", "/")
        sha256 = Get-RawSha256 -Path $additionalPath
    }
}
$attempt.completed_at_utc = [DateTime]::UtcNow.ToString("o")
$attempt.process_exit_code = [int]$physical.exit_code
$attempt.process_timed_out = [bool]$physical.timed_out
$attempt.process_tree_killed = [bool]$physical.killed_process_tree
$attempt.receipt_parsed = $null -ne $receipt
$attempt.accepted = $accepted
Write-Utf8NoBom `
    -Path $attemptPath `
    -Text (($attempt | ConvertTo-Json -Depth 64) + [Environment]::NewLine)

$report = [ordered]@{
    schema_version =
        "sporespore_balanced_wave_bw24m_material_characterization_report_v1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    campaign_id = $campaignId
    gate_id = $gateId
    source_commit = $sourceCommit
    source_worktree_clean = $true
    source_matches_origin_main = $true
    source_matches_live_github_main = $true
    accepted = $accepted
    result_status = $(if ($accepted) { "passed" } else { "rejected" })
    first_complete_result_is_final = $true
    selective_replicate_rerun_allowed = $false
    locomotion_world_count = 0
    material_robustness = $false
    continuous_friction_coverage = $false
    cross_engine_equivalence = $false
    physical_acceptance_authority = $false
    godot_process = [ordered]@{
        exit_code = [int]$physical.exit_code
        timed_out = [bool]$physical.timed_out
        killed_process_tree = [bool]$physical.killed_process_tree
        duration_seconds = [double]$physical.duration_seconds
        receipt_parse_failure = $receiptParseFailure
    }
    host_identity = [ordered]@{
        godot_version = $godotVersion
        godot_launcher_executable_sha256 = $godotLauncherSha256
        godot_runtime_executable_sha256 = Get-RawSha256 -Path $runtimePath
        physics_engine = "Jolt Physics"
        physics_hz = 120
        solver_velocity_steps = 20
        solver_position_steps = 7
    }
    sources = $sources
    attempt = [ordered]@{
        path = "attempt.json"
        sha256 = Get-RawSha256 -Path $attemptPath
    }
    transcript = [ordered]@{
        path = "transcript.log"
        sha256 = Get-RawSha256 -Path $transcriptPath
    }
    engine_log = [ordered]@{
        path = "engine.log"
        sha256 = Get-RawSha256 -Path $engineLogPath
    }
    receipt = $receipt
    production_gate_evaluation = $evaluation
}
$reportPath = Join-Path $resolvedOutputRoot "report.json"
Write-NewJsonArtifact -Value $report -Path $reportPath

if (-not $accepted) {
    throw (
        "$gateId physical characterization was retained as rejected; " +
        "same-identity rerun is forbidden. Report: $reportPath"
    )
}
Write-Host (
    "$gateId PHYSICAL_COMPLETE worlds=10 gates=19 accepted=True " +
    "profile_publication_next=True material_robustness=False " +
    "physical_authority=False report=$reportPath"
)

#requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$PreflightOnly,
    [switch]$RunPhysical,
    [string]$CampaignAttestationAdoption = "",
    [string]$OutputRoot = "",
    [string]$Godot = "C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe",
    [string]$Python = "python",
    [string]$PowerShell = "pwsh",
    [ValidateRange(300, 3600)][int]$CellTimeoutSeconds = 900
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$turningRoot = Join-Path $sdkRoot "turning"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$mujocoSitePackages = Join-Path $mujocoRoot ".venv\Lib\site-packages"
$campaignId = "QSDK-R23D63-RECEIPT-SCHEMA-REPAIRED-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION"
$gateId = "QSDK-R23D63"
$stageId = "receipt_schema_repaired_selected_profile_matched_three_engine_turning_validation"
$campaignSeed = 23169
$profileId = "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
$cellProfileTag = "selected_profile"
$engineOrder = @("godot_jolt", "rapier_parry", "mujoco")
$armOffsets = [ordered]@{
    reference_zero = 0.0
    positive_heading = 0.2
    negative_heading = -0.2
}
$cellIds = @(
    foreach ($engineId in $engineOrder) {
        foreach ($armId in $armOffsets.Keys) {
            "$engineId`__s$campaignSeed`__$cellProfileTag`__$armId"
        }
    }
)

$preregistrationPath = Join-Path $turningRoot "r23d63_selected_profile_three_engine_turning_validation_preregistration_v1.json"
$implementationPath = Join-Path $turningRoot "r23d63_selected_profile_three_engine_turning_validation_implementation_v1.json"
$campaignManifestPath = Join-Path $turningRoot "r23d63_campaign_attestation_manifest_v1.json"
$dependencyToolPath = Join-Path $turningRoot "r23d63_dependency_closure.py"
$evaluatorPath = Join-Path $turningRoot "r23d63_selected_profile_three_engine_turning_validation_evaluator_v2.py"
$workerResourcePath = "res://tests/test_sdk_qsdk_r23d63_godot_jolt_physical_worker.gd"
$preregistrationGatePath = Join-Path $repoRoot "tests\test_qsdk_r23d63_preregistration.ps1"
$dependencyGatePath = Join-Path $repoRoot "tests\test_qsdk_r23d63_dependency_closure.ps1"
$receiptSchemaGatePath = Join-Path $repoRoot (
    "tests\test_qsdk_r23d63_authorization_receipt_schema.ps1"
)
$parentClosureGatePath = Join-Path $repoRoot "tests\test_qsdk_r23d61_publication_closure.ps1"
$evaluatorV1GatePath = Join-Path $repoRoot "tests\test_qsdk_r23d63_evaluator.ps1"
$evaluatorV2GatePath = Join-Path $repoRoot "tests\test_qsdk_r23d63_evaluator_v2.ps1"
$godotRouteGatePath = Join-Path $repoRoot "tests\test_qsdk_r23d63_godot_public_profile_physical_route.ps1"
$godotWorkerGatePath = Join-Path $repoRoot "tests\test_qsdk_r23d63_godot_jolt_physical_worker.ps1"
$rapierRouteGatePath = Join-Path $repoRoot "tests\test_qsdk_r23d63_rapier_public_profile_physical_route.ps1"
$rapierWorkerGatePath = Join-Path $repoRoot "tests\test_qsdk_r23d63_rapier_physical_worker.ps1"
$mujocoRouteGatePath = Join-Path $repoRoot "tests\test_qsdk_r23d63_mujoco_public_profile_physical_route.ps1"
$mujocoWorkerGatePath = Join-Path $repoRoot "tests\test_qsdk_r23d63_mujoco_physical_worker.ps1"
$terminalProjectionGatePath = Join-Path $repoRoot "tests\test_locomotion_terminal_execution_projection.ps1"
$runtimeHelperPath = Join-Path $sdkRoot "r23d3_reproducible_runtime_materialization.ps1"
$coreDebugPath = Join-Path $sdkRoot "target\debug\sporespore_locomotion_core.dll"
$coreReleasePath = Join-Path $sdkRoot "target\release\sporespore_locomotion_core.dll"
$godotAdapterPath = Join-Path $sdkRoot "target\debug\sporespore_godot_adapter.dll"
$rapierDebugPath = Join-Path $sdkRoot "target\debug\qsdk_r23d63_physical.exe"
$rapierReleasePath = Join-Path $sdkRoot "target\release\qsdk_r23d63_physical.exe"
$mujocoWorkerModule = "sporespore_mujoco_adapter.qsdk_r23d63_selected_profile_turning"
$godotReadyMarker = "QSDK_R23D63_GODOT_SUPERVISOR_TERMINATION_READY "

$physicalEnvironmentNames = @(
    "SPORESPORE_QSDK_R23D63_FREEZE",
    "SPORESPORE_QSDK_R23D63_ATTEMPT",
    "SPORESPORE_QSDK_R23D63_TOKEN",
    "SPORESPORE_QSDK_R23D63_STAGE",
    "SPORESPORE_QSDK_R23D63_CELL",
    "SPORESPORE_QSDK_R23D63_ENGINE",
    "SPORESPORE_QSDK_R23D63_ATTEMPT_ROOT",
    "SPORESPORE_QSDK_R23D63_AUTHORITY_REPO_ROOT",
    "SPORESPORE_QSDK_R23D63_PYTHON",
    "SPORESPORE_QSDK_R23D63_POWERSHELL",
    "SPORESPORE_QSDK_R23D63_SUPERVISED_TERMINATION",
    "SPORESPORE_QSDK_R23D63_TERMINATION_NONCE",
    "SPORESPORE_QSDK_R23D60_FREEZE",
    "SPORESPORE_QSDK_R23D60_ATTEMPT",
    "SPORESPORE_QSDK_R23D59_FREEZE",
    "SPORESPORE_QSDK_R23D59_ATTEMPT",
    "SPORESPORE_QSDK_R23D58_FREEZE",
    "SPORESPORE_QSDK_R23D58_ATTEMPT",
    "SPORESPORE_QSDK_R23D48_FREEZE",
    "SPORESPORE_QSDK_R23D48_ATTEMPT"
)

. (Join-Path $sdkRoot "content_addressed_artifact_store.ps1")
. (Join-Path $sdkRoot "godot_receipt_terminated_process.ps1")
. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")
. (Join-Path $sdkRoot "locomotion_full_conformance_attestation.ps1")
. (Join-Path $sdkRoot "locomotion_campaign_attestation_adoption.ps1")
. (Join-Path $sdkRoot "locomotion_terminal_execution_projection.ps1")
. $runtimeHelperPath

$terminalSuccessSchemas = @("sporespore_qsdk_r23d63_engine_cell_report_v1")
$terminalFailureSchemas = @(
    "sporespore_qsdk_r23d63_worker_failure_v1",
    "sporespore_qsdk_r23d63_supervisor_failure_v1"
)

function Assert-R23D63([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D63: $Message" }
}

function Assert-R23D63CompleteMatrixProof($Receipt, [string]$EngineId) {
    $valid = (
        $Receipt -is [Collections.IDictionary] -and
        $Receipt.Contains("complete_ordered_nine_cell_matrix_validated") -and
        $Receipt["complete_ordered_nine_cell_matrix_validated"] -is [bool] -and
        [bool]$Receipt["complete_ordered_nine_cell_matrix_validated"]
    )
    if (-not $valid) {
        throw (
            "QSDK-R23D63: " +
            "QSDK_R23D63_AUTHORIZATION_RECEIPT_SCHEMA_INVALID:$EngineId"
        )
    }
}

function Resolve-R23D63Application([string]$Command) {
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R23D63 (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application is missing: $resolved"
        )
        return $resolved
    }
    $candidate = Get-Command $Command -CommandType Application -ErrorAction Stop |
        Select-Object -First 1
    return [IO.Path]::GetFullPath([string]$candidate.Source)
}

function Get-R23D63Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Invoke-R23D63Git([string[]]$Arguments) {
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "QSDK-R23D63 git $($Arguments -join ' ') failed: $($lines -join ' ')"
    }
    return ($lines -join "`n").Trim()
}

function Write-R23D63NewJson([string]$Path, $Value) {
    $resolved = [IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $resolved) {
        throw "QSDK-R23D63 refuses to overwrite: $resolved"
    }
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $resolved))
    [IO.File]::WriteAllText(
        $resolved,
        ($Value | ConvertTo-Json -Depth 100) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
}

function Get-R23D63MediaType([string]$Path) {
    switch ([IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        ".json" { return "application/json" }
        ".ps1" { return "text/x-powershell" }
        ".py" { return "text/x-python" }
        ".gd" { return "text/x-gdscript" }
        ".rs" { return "text/x-rust" }
        ".toml" { return "application/toml" }
        ".dll" { return "application/vnd.microsoft.portable-executable" }
        ".exe" { return "application/vnd.microsoft.portable-executable" }
        default { return "application/octet-stream" }
    }
}

function Invoke-R23D63Process {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [hashtable]$Environment = @{},
        [ValidateRange(1, 7200)][int]$TimeoutSeconds = 900
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FileName
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    foreach ($name in $physicalEnvironmentNames) { [void]$start.Environment.Remove($name) }
    foreach ($entry in $Environment.GetEnumerator()) {
        $start.Environment[[string]$entry.Key] = [string]$entry.Value
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $started = [DateTime]::UtcNow
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) {
        try { $process.Kill($true) } catch {}
        [void]$process.WaitForExit(10000)
    } else {
        $process.WaitForExit()
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($timedOut) { 124 } else { $process.ExitCode }
    $process.Dispose()
    return [ordered]@{
        exit_code = $exitCode
        timed_out = $timedOut
        stdout = $stdout
        stderr = $stderr
        started_utc = $started.ToString("o")
        completed_utc = [DateTime]::UtcNow.ToString("o")
    }
}

function Invoke-R23D63GodotWorkerProcess {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [hashtable]$Environment = @{},
        [ValidateRange(1, 7200)][int]$TimeoutSeconds = 900
    )
    $workerEnvironment = @{}
    foreach ($entry in $Environment.GetEnumerator()) {
        $workerEnvironment[[string]$entry.Key] = [string]$entry.Value
    }
    $terminationNonce = [Guid]::NewGuid().ToString("N")
    $workerEnvironment["SPORESPORE_QSDK_R23D63_SUPERVISED_TERMINATION"] = "1"
    $workerEnvironment["SPORESPORE_QSDK_R23D63_TERMINATION_NONCE"] = $terminationNonce
    return Invoke-SporeSporeGodotReceiptTerminatedProcess -FileName $Godot `
        -Arguments $Arguments -WorkingDirectory $repoRoot `
        -ReadyMarkerPrefix $godotReadyMarker -ExpectedNonce $terminationNonce `
        -Environment $workerEnvironment `
        -ScrubEnvironmentNames $physicalEnvironmentNames `
        -TimeoutSeconds $TimeoutSeconds
}

function Get-R23D63MarkerJson([string]$Text, [string]$Prefix) {
    $lines = @($Text -split "`r?`n" | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D63 ($lines.Count -eq 1) (
        "expected one '$Prefix' marker, observed $($lines.Count)"
    )
    return $lines[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Assert-R23D63PlainMarker(
    [string]$Text,
    [string]$Prefix,
    [string]$GateName
) {
    $matches = @($Text -split "`r?`n" | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D63 ($matches.Count -eq 1) "$GateName marker changed"
    return [string]$matches[0]
}

function Get-R23D63PythonEnvironment([string]$CoreLibrary = "") {
    $environment = @{
        "PYTHONPATH" = (@(
            (Join-Path $sdkRoot "python"),
            $turningRoot,
            $mujocoRoot,
            $mujocoSitePackages
        ) -join [IO.Path]::PathSeparator)
    }
    if (-not [string]::IsNullOrWhiteSpace($CoreLibrary)) {
        $environment["SPORESPORE_LOCOMOTION_LIBRARY"] = (
            [IO.Path]::GetFullPath($CoreLibrary)
        )
    }
    return $environment
}

function Get-R23D63DependencyInventory(
    [string]$PythonHost,
    [bool]$RequireCleanGitBytes
) {
    $arguments = @(
        $dependencyToolPath,
        "--repo-root", $repoRoot,
        "--contract", $implementationPath
    )
    if ($RequireCleanGitBytes) { $arguments += "--require-clean-git-bytes" }
    $process = Invoke-R23D63Process -FileName $PythonHost `
        -Arguments $arguments -WorkingDirectory $repoRoot `
        -Environment (Get-R23D63PythonEnvironment) -TimeoutSeconds 300
    Assert-R23D63 ($process.exit_code -eq 0 -and -not $process.timed_out) (
        "dependency inventory failed: $($process.stderr) $($process.stdout)"
    )
    $receipt = Get-R23D63MarkerJson $process.stdout (
        "QSDK_R23D63_DEPENDENCY_INVENTORY "
    )
    Assert-R23D63 (
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r23d63_dependency_inventory_v1" -and
        [string]$receipt.campaign_id -ceq $campaignId -and
        [string]$receipt.gate_id -ceq $gateId -and
        [bool]$receipt.expected_transitive_path_set_exact -and
        [int]$receipt.transitive_path_count -gt 0 -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        [bool]$receipt.checkout_bytes_equal_git_blobs -eq $RequireCleanGitBytes
    ) "dependency inventory receipt changed"
    return $receipt
}

function Invoke-R23D63Gate(
    [string]$FileName,
    [string[]]$Arguments,
    [string]$Marker,
    [string]$Name,
    [hashtable]$Environment = @{},
    [int]$TimeoutSeconds = 300
) {
    $result = Invoke-R23D63Process -FileName $FileName -Arguments $Arguments `
        -WorkingDirectory $repoRoot -Environment $Environment `
        -TimeoutSeconds $TimeoutSeconds
    Assert-R23D63 ($result.exit_code -eq 0 -and -not $result.timed_out) (
        "$Name failed: $($result.stderr) $($result.stdout)"
    )
    [void](Assert-R23D63PlainMarker $result.stdout $Marker $Name)
    return $result
}

function Invoke-R23D63ZeroWorld(
    [string]$PythonHost,
    [string]$PowerShellHost,
    [string]$CoreLibrary = $coreDebugPath
) {
    $requiredPaths = @(
        $preregistrationPath,
        $implementationPath,
        $dependencyToolPath,
        $dependencyGatePath,
        $receiptSchemaGatePath,
        $parentClosureGatePath,
        $evaluatorPath,
        $evaluatorV1GatePath,
        $evaluatorV2GatePath,
        $godotRouteGatePath,
        $godotWorkerGatePath,
        $rapierRouteGatePath,
        $rapierWorkerGatePath,
        $mujocoRouteGatePath,
        $mujocoWorkerGatePath,
        $terminalProjectionGatePath,
        (Join-Path $repoRoot "tests\test_sdk_qsdk_r23d63_godot_jolt_physical_worker.gd"),
        (Join-Path $repoRoot "sdk\adapters\rapier\src\bin\qsdk_r23d63_physical.rs"),
        (Join-Path $mujocoRoot "sporespore_mujoco_adapter\qsdk_r23d63_selected_profile_turning.py")
    )
    foreach ($path in $requiredPaths) {
        Assert-R23D63 (Test-Path -LiteralPath $path -PathType Leaf) (
            "zero-world dependency is missing: $path"
        )
    }

    $inventory = Get-R23D63DependencyInventory $PythonHost $false
    Assert-R23D63 (Test-Path -LiteralPath $CoreLibrary -PathType Leaf) (
        "zero-world core library is missing: $CoreLibrary"
    )
    $pythonEnvironment = Get-R23D63PythonEnvironment $CoreLibrary
    $gateDefinitions = @(
        [ordered]@{
            name = "R23D63 preregistration"
            path = $preregistrationGatePath
            marker = "QSDK_R23D63_PREREGISTRATION_PASS "
            arguments = @("-Python", $PythonHost, "-Godot", $Godot)
            environment = @{}
            timeout = 600
        },
        [ordered]@{
            name = "R23D63 dependency closure"
            path = $dependencyGatePath
            marker = "QSDK_R23D63_DEPENDENCY_CLOSURE_PASS "
            arguments = @("-Python", $PythonHost)
            environment = $pythonEnvironment
            timeout = 600
        },
        [ordered]@{
            name = "R23D63 authorization-receipt schema conformance"
            path = $receiptSchemaGatePath
            marker = "QSDK_R23D63_AUTHORIZATION_RECEIPT_SCHEMA_PASS "
            arguments = @("-Python", $PythonHost, "-Godot", $Godot)
            environment = $pythonEnvironment
            timeout = 600
        },
        [ordered]@{
            name = "immutable R23D61 publication closure"
            path = $parentClosureGatePath
            marker = "QSDK_R23D61_PUBLICATION_CLOSURE_PASS "
            arguments = @()
            environment = @{}
            timeout = 600
        },
        [ordered]@{
            name = "immutable evaluator-v1 rejection"
            path = $evaluatorV1GatePath
            marker = "QSDK_R23D63_EVALUATOR_PASS "
            arguments = @("-Python", $PythonHost)
            environment = $pythonEnvironment
            timeout = 600
        },
        [ordered]@{
            name = "corrected evaluator-v2"
            path = $evaluatorV2GatePath
            marker = "QSDK_R23D63_EVALUATOR_V2_PASS "
            arguments = @("-Python", $PythonHost)
            environment = $pythonEnvironment
            timeout = 900
        },
        [ordered]@{
            name = "terminal execution projection"
            path = $terminalProjectionGatePath
            marker = "LOCOMOTION_TERMINAL_EXECUTION_PROJECTION_PASS "
            arguments = @()
            environment = @{}
            timeout = 600
        },
        [ordered]@{
            name = "Godot public-profile route"
            path = $godotRouteGatePath
            marker = "QSDK_R23D63_GODOT_PUBLIC_PROFILE_ROUTE_PASS "
            arguments = @("-Godot", $Godot)
            environment = $pythonEnvironment
            timeout = 600
        },
        [ordered]@{
            name = "Godot physical worker"
            path = $godotWorkerGatePath
            marker = "QSDK_R23D63_GODOT_WORKER_ZERO_WORLD_PASS "
            arguments = @("-Godot", $Godot)
            environment = $pythonEnvironment
            timeout = 600
        },
        [ordered]@{
            name = "Rapier public-profile route"
            path = $rapierRouteGatePath
            marker = "QSDK_R23D63_RAPIER_PUBLIC_PROFILE_ROUTE_PASS "
            arguments = @("-Python", $PythonHost)
            environment = $pythonEnvironment
            timeout = 600
        },
        [ordered]@{
            name = "Rapier physical worker"
            path = $rapierWorkerGatePath
            marker = "QSDK_R23D63_RAPIER_WORKER_ZERO_WORLD_PASS "
            arguments = @("-Python", $PythonHost)
            environment = $pythonEnvironment
            timeout = 900
        },
        [ordered]@{
            name = "MuJoCo public-profile route"
            path = $mujocoRouteGatePath
            marker = "QSDK_R23D63_MUJOCO_PUBLIC_PROFILE_ROUTE_PASS "
            arguments = @("-Python", $PythonHost)
            environment = $pythonEnvironment
            timeout = 600
        },
        [ordered]@{
            name = "MuJoCo physical worker"
            path = $mujocoWorkerGatePath
            marker = "QSDK_R23D63_MUJOCO_PHYSICAL_WORKER_PASS "
            arguments = @("-Python", $PythonHost)
            environment = $pythonEnvironment
            timeout = 900
        }
    )
    $gateReceipts = [Collections.Generic.List[object]]::new()
    $receiptSchemaConformance = $null
    foreach ($definition in $gateDefinitions) {
        $arguments = @(
            "-NoLogo",
            "-NoProfile",
            "-File",
            [string]$definition.path
        ) + @($definition.arguments)
        $gate = Invoke-R23D63Gate -FileName $PowerShellHost -Arguments $arguments -Marker ([string]$definition.marker) -Name ([string]$definition.name) -Environment $definition.environment -TimeoutSeconds ([int]$definition.timeout)
        if ([string]$definition.path -ceq $receiptSchemaGatePath) {
            $receiptSchemaConformance = Get-R23D63MarkerJson (
                [string]$gate.stdout
            ) "QSDK_R23D63_AUTHORIZATION_RECEIPT_SCHEMA_PASS "
            Assert-R23D63 (
                [string]$receiptSchemaConformance.schema_version -ceq
                    "sporespore_qsdk_r23d63_authorization_receipt_schema_conformance_v1" -and
                [string]$receiptSchemaConformance.campaign_id -ceq $campaignId -and
                [string]$receiptSchemaConformance.gate_id -ceq $gateId -and
                [string]$receiptSchemaConformance.question_class -ceq
                    "equivalence_non_inferiority" -and
                [int]$receiptSchemaConformance.declared_producer_count -eq 3 -and
                [int]$receiptSchemaConformance.conforming_producer_count -eq 3 -and
                [string]$receiptSchemaConformance.required_field -ceq
                    "complete_ordered_nine_cell_matrix_validated" -and
                $receiptSchemaConformance.required_value -is [bool] -and
                [bool]$receiptSchemaConformance.required_value -and
                [int]$receiptSchemaConformance.equivalence_margin -eq 0 -and
                [int]$receiptSchemaConformance.non_inferiority_margin -eq 0 -and
                -not [bool]$receiptSchemaConformance.sampling_used -and
                [int]$receiptSchemaConformance.total_negative_control_count -eq 12 -and
                [int]$receiptSchemaConformance.negative_controls_passed -eq 12 -and
                [int]$receiptSchemaConformance.model_construction_count -eq 0 -and
                [int]$receiptSchemaConformance.world_attempt_count -eq 0 -and
                [int]$receiptSchemaConformance.world_build_count -eq 0 -and
                -not [bool]$receiptSchemaConformance.physical_equivalence_claimed -and
                -not [bool]$receiptSchemaConformance.physical_acceptance_authority
            ) "authorization-receipt schema conformance receipt changed"
        }
        $stdoutDigest = "sha256:" + [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData(
                [Text.Encoding]::UTF8.GetBytes([string]$gate.stdout)
            )
        ).ToLowerInvariant()
        $gateReceipts.Add([ordered]@{
            name = [string]$definition.name
            path = [IO.Path]::GetRelativePath(
                $repoRoot,
                [string]$definition.path
            ).Replace("\", "/")
            marker = [string]$definition.marker
            stdout_sha256 = $stdoutDigest
            model_construction_count = 0
            world_attempt_count = 0
            world_build_count = 0
            physical_acceptance_authority = $false
        })
    }

    $evaluator = Invoke-R23D63Process -FileName $PythonHost -Arguments @(
        $evaluatorPath,
        "preflight"
    ) -WorkingDirectory $repoRoot -Environment $pythonEnvironment -TimeoutSeconds 900
    Assert-R23D63 ($evaluator.exit_code -eq 0 -and -not $evaluator.timed_out) (
        "R23D63 evaluator-v2 preflight failed: $($evaluator.stderr) $($evaluator.stdout)"
    )
    $evaluatorReceipt = Get-R23D63MarkerJson $evaluator.stdout (
        "QSDK_R23D63_EVALUATOR_V2_PREFLIGHT "
    )
    Assert-R23D63 (
        [string]$evaluatorReceipt.schema_version -ceq
            "sporespore_qsdk_r23d63_evaluator_preflight_v2" -and
        [string]$evaluatorReceipt.campaign_id -ceq $campaignId -and
        [string]$evaluatorReceipt.gate_id -ceq $gateId -and
        [string]$evaluatorReceipt.question_class -ceq "finite_decision" -and
        [int]$evaluatorReceipt.declared_cell_count -eq 9 -and
        [int]$evaluatorReceipt.engine_count -eq 3 -and
        [int]$evaluatorReceipt.valid_trace_canary_count -eq 9 -and
        [int]$evaluatorReceipt.task_origin_and_schedule_mutation_rejection_count -eq 30 -and
        [int]$evaluatorReceipt.actuator_observation_mutation_rejection_count -eq 60 -and
        [int]$evaluatorReceipt.public_profile_projection_mutation_rejection_count -eq 48 -and
        [int]$evaluatorReceipt.per_engine_trace_cap_mutation_rejection_count -eq 3 -and
        [int]$evaluatorReceipt.turning_decision_mutation_rejection_count -eq 8 -and
        [int]$evaluatorReceipt.complete_matrix_order_mutation_rejection_count -eq 9 -and
        [int]$evaluatorReceipt.observation_row_count_per_trace -eq 2992 -and
        [int]$evaluatorReceipt.observation_application_count_per_trace -eq 23936 -and
        [bool]$evaluatorReceipt.genuine_godot_trace_cold_baseline_passed -and
        -not [bool]$evaluatorReceipt.historical_world_reused_as_r23d63_cell -and
        [bool]$evaluatorReceipt.turning_gate_invoked -and
        -not [bool]$evaluatorReceipt.superiority_test_invoked -and
        -not [bool]$evaluatorReceipt.equivalence_or_non_inferiority_test_invoked -and
        -not [bool]$evaluatorReceipt.population_inference_attempted -and
        [int]$evaluatorReceipt.model_construction_count -eq 0 -and
        [int]$evaluatorReceipt.world_attempt_count -eq 0 -and
        [int]$evaluatorReceipt.world_build_count -eq 0 -and
        -not [bool]$evaluatorReceipt.physical_execution_authorized -and
        -not [bool]$evaluatorReceipt.physical_acceptance_authority
    ) "evaluator-v2 preflight receipt changed"

    Assert-R23D63 (
        $gateReceipts.Count -eq 13 -and
        $null -ne $receiptSchemaConformance
    ) (
        "complete zero-world gate cardinality changed"
    )
    return [ordered]@{
        schema_version = "sporespore_qsdk_r23d63_complete_zero_world_receipt_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        question_class = "finite_decision"
        dependency_inventory = $inventory
        ordered_gate_receipts = @($gateReceipts)
        campaign_gate_count = $gateReceipts.Count
        evaluator = $evaluatorReceipt
        authorization_receipt_schema_conformance = $receiptSchemaConformance
        worker_preflight_count = 9
        declared_cell_count = 9
        declared_world_count = 9
        complete_dependency_inventory_proved = $true
        immutable_parent_closure_replayed = $true
        rejected_evaluator_v1_preserved = $true
        evaluator_v2_complete_matrix_proved = $true
        all_three_public_profile_routes_proved = $true
        all_three_worker_zero_world_gates_proved = $true
        all_three_authorization_receipt_producers_conform = $true
        authorization_receipt_schema_negative_controls_passed = 12
        all_worker_cells_preflighted = $true
        complete_negative_controls_proved = $true
        turning_gate_invoked = $true
        superiority_or_equivalence_evaluator_invoked = $false
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
    }
}
function Assert-R23D63FrozenBindings($Freeze) {
    foreach ($binding in @($Freeze.source_bindings)) {
        $relative = [string]$binding.path
        $path = Join-Path $repoRoot $relative
        Assert-R23D63 (
            (Test-Path -LiteralPath $path -PathType Leaf) -and
            [string]$binding.raw_sha256 -ceq (Get-R23D63Sha256 $path) -and
            [string]$binding.git_blob_oid -ceq
                (Invoke-R23D63Git @("rev-parse", "HEAD:$relative")) -and
            [string]$binding.git_blob_oid -ceq
                (Invoke-R23D63Git @("hash-object", "--no-filters", "--", $relative))
        ) "frozen source binding changed: $relative"
    }
    foreach ($runtime in @($Freeze.runtime_artifacts) + @($Freeze.external_runtime_bindings)) {
        $path = [IO.Path]::GetFullPath([string]$runtime.path)
        Assert-R23D63 (
            (Test-Path -LiteralPath $path -PathType Leaf) -and
            [string]$runtime.raw_sha256 -ceq (Get-R23D63Sha256 $path)
        ) "frozen runtime changed: $path"
    }
}

function Publish-R23D63Inputs(
    $SourceBindings,
    $RuntimeArtifacts,
    $ExternalRuntimeBindings,
    [string]$AdoptionPath
) {
    $source = @(
        foreach ($binding in @($SourceBindings)) {
            Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
                -ArtifactPath (Join-Path $repoRoot ([string]$binding.path)) `
                -MediaType (Get-R23D63MediaType ([string]$binding.path))
        }
    )
    $runtime = @(
        foreach ($binding in @($RuntimeArtifacts) + @($ExternalRuntimeBindings)) {
            Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
                -ArtifactPath ([string]$binding.path) `
                -MediaType ([string]$binding.media_type)
        }
    )
    $adoption = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $AdoptionPath -MediaType "application/json"
    return [ordered]@{
        source_bindings = $source
        runtime_bindings = $runtime
        campaign_attestation_adoption = $adoption
        physical_acceptance_authority = $false
    }
}

function Get-R23D63TerminalFailure(
    [string]$EngineId,
    [string]$ArmId,
    [string]$SourceCommit,
    [string]$Code,
    [int]$WorldAttemptCount = 0,
    [int]$WorldBuildCount = 0,
    [bool]$WorldBuildCountExact = $true,
    [int]$WorldBuildCountUpperBound = $WorldBuildCount
) {
    return [ordered]@{
        schema_version = "sporespore_qsdk_r23d63_supervisor_failure_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        stage_id = $stageId
        cell_id = ("{0}__s{1}__{2}__{3}" -f $EngineId, $campaignSeed, $cellProfileTag, $ArmId)
        engine_id = $EngineId
        campaign_seed = $campaignSeed
        profile_id = $profileId
        onset_id = "onset_600"
        turn_start_semantic_step = 600
        arm_id = $ArmId
        turn_heading_offset_rad = [double]$armOffsets[$ArmId]
        source_commit = $SourceCommit
        failure_stage = "supervisor_transport"
        failure_code = $Code
        world_attempt_count = $WorldAttemptCount
        world_build_count = $WorldBuildCount
        world_build_count_exact = $WorldBuildCountExact
        world_build_count_lower_bound = $WorldBuildCount
        world_build_count_upper_bound = $WorldBuildCountUpperBound
        claims = [ordered]@{
            godot_jolt_turning_extended_to_seed_23169 = $false
            fresh_rapier_turning_replication = $false
            fresh_mujoco_turning_replication = $false
            finite_three_engine_turning = $false
            portable_basic_turning = $false
            q_sdk_r23_satisfied = $false
            cross_engine_equivalence = $false
            population_robustness = $false
            prone_to_standing = $false
            release_authority = $false
            physical_acceptance_authority = $false
        }
    }
}

function Invoke-R23D63Cell {
    param(
        [Parameter(Mandatory)][string]$EngineId,
        [Parameter(Mandatory)][string]$ArmId,
        [Parameter(Mandatory)][string]$SourceCommit,
        [Parameter(Mandatory)][string]$FreezePayload,
        [Parameter(Mandatory)][string]$AttemptPayload,
        [Parameter(Mandatory)][string]$Token,
        [Parameter(Mandatory)][string]$AttemptRoot,
        [Parameter(Mandatory)][string]$CellRoot,
        [Parameter(Mandatory)][string]$PythonHost,
        [Parameter(Mandatory)][string]$PowerShellHost
    )
    [void][IO.Directory]::CreateDirectory($CellRoot)
    $cellId = "{0}__s{1}__{2}__{3}" -f (
        $EngineId,
        $campaignSeed,
        $cellProfileTag,
        $ArmId
    )
    $environment = @{
        "SPORESPORE_QSDK_R23D63_FREEZE" = $FreezePayload
        "SPORESPORE_QSDK_R23D63_ATTEMPT" = $AttemptPayload
        "SPORESPORE_QSDK_R23D63_TOKEN" = $Token
        "SPORESPORE_QSDK_R23D63_STAGE" = $stageId
        "SPORESPORE_QSDK_R23D63_CELL" = $cellId
        "SPORESPORE_QSDK_R23D63_ENGINE" = $EngineId
        "SPORESPORE_QSDK_R23D63_ATTEMPT_ROOT" = $AttemptRoot
        "SPORESPORE_QSDK_R23D63_AUTHORITY_REPO_ROOT" = $repoRoot
        "SPORESPORE_QSDK_R23D63_PYTHON" = $PythonHost
        "SPORESPORE_QSDK_R23D63_POWERSHELL" = $PowerShellHost
    }
    if ($EngineId -ceq "godot_jolt") {
        $arguments = @(
            "--headless", "--path", $repoRoot, "--script", $workerResourcePath, "--",
            "--stage", $stageId, "--onset", "onset_600",
            "--seed", [string]$campaignSeed, "--profile", $profileId,
            "--arm", $ArmId, "--source-commit", $SourceCommit
        )
        $process = Invoke-R23D63GodotWorkerProcess -Arguments $arguments -Environment $environment -TimeoutSeconds $CellTimeoutSeconds
        $marker = "QSDK_R23D63_GODOT_JOLT_TERMINAL "
    } elseif ($EngineId -ceq "rapier_parry") {
        $arguments = @(
            "physical", "--stage", $stageId, "--onset", "onset_600",
            "--campaign-seed", [string]$campaignSeed, "--profile", $profileId,
            "--arm", $ArmId, "--source-commit", $SourceCommit
        )
        $process = Invoke-R23D63Process -FileName $rapierReleasePath -Arguments $arguments -WorkingDirectory $repoRoot -Environment $environment -TimeoutSeconds $CellTimeoutSeconds
        $marker = "QSDK_R23D63_RAPIER_TERMINAL "
    } elseif ($EngineId -ceq "mujoco") {
        foreach ($entry in (Get-R23D63PythonEnvironment $coreReleasePath).GetEnumerator()) {
            $environment[[string]$entry.Key] = [string]$entry.Value
        }
        $arguments = @(
            "-m", $mujocoWorkerModule, "physical",
            "--stage", $stageId, "--onset", "onset_600",
            "--campaign-seed", [string]$campaignSeed, "--profile", $profileId,
            "--arm", $ArmId, "--source-commit", $SourceCommit
        )
        $process = Invoke-R23D63Process -FileName $PythonHost -Arguments $arguments -WorkingDirectory $repoRoot -Environment $environment -TimeoutSeconds $CellTimeoutSeconds
        $marker = "QSDK_R23D63_MUJOCO_TERMINAL "
    } else {
        throw "QSDK-R23D63: undeclared engine: $EngineId"
    }

    $stdoutPath = Join-Path $CellRoot "stdout.txt"
    $stderrPath = Join-Path $CellRoot "stderr.txt"
    [IO.File]::WriteAllText(
        $stdoutPath,
        [string]$process.stdout,
        [Text.UTF8Encoding]::new($false)
    )
    [IO.File]::WriteAllText(
        $stderrPath,
        [string]$process.stderr,
        [Text.UTF8Encoding]::new($false)
    )
    $stdoutCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot -ArtifactPath $stdoutPath -MediaType "text/plain"
    $stderrCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot -ArtifactPath $stderrPath -MediaType "text/plain"
    try {
        if ([bool]$process.timed_out) { throw "R23D63_CELL_TIMEOUT" }
        if ($EngineId -ceq "godot_jolt") {
            if (-not [bool]$process.termination_protocol_valid) {
                throw "R23D63_GODOT_TERMINATION_PROTOCOL_INVALID"
            }
            if (-not [bool]$process.supervisor_terminated) {
                throw "R23D63_GODOT_SUPERVISOR_TERMINATION_MISSING"
            }
            if (
                [string]$process.termination_ready_receipt.worker_receipt_kind -cne
                    "terminal"
            ) {
                throw "R23D63_GODOT_TERMINATION_RECEIPT_KIND_INVALID"
            }
        }
        $terminal = Get-R23D63MarkerJson $process.stdout $marker
        if ([string]$terminal.cell_id -cne $cellId) {
            throw "R23D63_CELL_MARKER_ID"
        }
        if ([string]$terminal.engine_id -cne $EngineId) {
            throw "R23D63_CELL_ENGINE"
        }
        if ([int]$terminal.campaign_seed -ne $campaignSeed) {
            throw "R23D63_CELL_SEED"
        }
        if ([string]$terminal.profile_id -cne $profileId) {
            throw "R23D63_CELL_PROFILE"
        }
        if ([string]$terminal.arm_id -cne $ArmId) {
            throw "R23D63_CELL_ARM"
        }
        if (
            [double]$terminal.turn_heading_offset_rad -ne
                [double]$armOffsets[$ArmId]
        ) {
            throw "R23D63_CELL_HEADING_OFFSET"
        }
        $terminalProjection = Get-SporeSporeTerminalExecutionProjection -Terminal $terminal -SuccessSchemas $terminalSuccessSchemas -FailureSchemas $terminalFailureSchemas
    } catch {
        $terminal = Get-R23D63TerminalFailure -EngineId $EngineId -ArmId $ArmId -SourceCommit $SourceCommit -Code ("R23D63_SUPERVISOR_TERMINAL_CAPTURE:" + $_.Exception.Message) -WorldAttemptCount 1 -WorldBuildCount 0 -WorldBuildCountExact $false -WorldBuildCountUpperBound 1
        $terminalProjection = Get-SporeSporeTerminalExecutionProjection -Terminal $terminal -SuccessSchemas $terminalSuccessSchemas -FailureSchemas $terminalFailureSchemas
    }
    $terminalPath = Join-Path $CellRoot "terminal.json"
    Write-R23D63NewJson $terminalPath $terminal
    $terminalCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot -ArtifactPath $terminalPath -MediaType "application/json"
    $godotProcess = $EngineId -ceq "godot_jolt"
    return [ordered]@{
        cell_id = $cellId
        engine_id = $EngineId
        campaign_seed = $campaignSeed
        profile_id = $profileId
        arm_id = $ArmId
        turn_heading_offset_rad = [double]$armOffsets[$ArmId]
        process = [ordered]@{
            exit_code = [int]$process.exit_code
            host_exit_code = if ($godotProcess) {
                [int]$process.host_exit_code
            } else {
                [int]$process.exit_code
            }
            timed_out = [bool]$process.timed_out
            supervisor_terminated = if ($godotProcess) {
                [bool]$process.supervisor_terminated
            } else {
                $false
            }
            termination_protocol_valid = if ($godotProcess) {
                [bool]$process.termination_protocol_valid
            } else {
                $true
            }
            termination_protocol_failure_code = if ($godotProcess) {
                [string]$process.termination_protocol_failure_code
            } else {
                ""
            }
            termination_ready_receipt = if ($godotProcess) {
                $process.termination_ready_receipt
            } else {
                $null
            }
            started_utc = [string]$process.started_utc
            completed_utc = [string]$process.completed_utc
            stdout_cas = $stdoutCas
            stderr_cas = $stderrCas
        }
        terminal_entry_cas = $terminalCas
        terminal_schema = [string]$terminal.schema_version
        terminal_projection_source = [string]$terminalProjection.projection_source
        world_attempt_count = [int]$terminalProjection.world_attempt_count
        world_build_count = [int]$terminalProjection.world_build_count
        world_build_count_exact = [bool]$terminalProjection.world_build_count_exact
        world_build_count_lower_bound = [int]$terminalProjection.world_build_count_lower_bound
        world_build_count_upper_bound = [int]$terminalProjection.world_build_count_upper_bound
        physical_acceptance_authority = $false
    }
}

Assert-R23D63 ($PreflightOnly -xor $RunPhysical) (
    "select exactly one of -PreflightOnly or -RunPhysical"
)
Assert-R23D63 (Test-Path -LiteralPath $Godot -PathType Leaf) (
    "Godot executable is missing"
)
$pythonHost = Resolve-R23D63Application $Python
$powerShellHost = Resolve-R23D63Application $PowerShell

if ($PreflightOnly) {
    Assert-R23D63 ([string]::IsNullOrWhiteSpace($CampaignAttestationAdoption)) (
        "preflight does not accept physical authorization"
    )
    Assert-R23D63 ([string]::IsNullOrWhiteSpace($OutputRoot)) (
        "preflight does not accept a physical output root"
    )
    $receipt = Invoke-R23D63ZeroWorld $pythonHost $powerShellHost
    Write-Host (
        "QSDK_R23D63_ZERO_WORLD_PASS " +
        ($receipt | ConvertTo-Json -Depth 100 -Compress)
    )
    exit 0
}

Assert-R23D63 (-not [string]::IsNullOrWhiteSpace($CampaignAttestationAdoption)) (
    "physical execution requires a campaign-attestation adoption"
)
foreach ($path in @($preregistrationPath, $implementationPath, $campaignManifestPath)) {
    Assert-R23D63 (Test-Path -LiteralPath $path -PathType Leaf) "missing contract: $path"
}
$source = Get-SporeSporeAttestationSourceIdentity -RepoRoot $repoRoot `
    -RequireCleanPushedLive
$adoption = Test-SporeSporeCampaignAttestationAdoptionFile -RepoRoot $repoRoot `
    -ManifestPath $campaignManifestPath `
    -AdoptionPath ([IO.Path]::GetFullPath($CampaignAttestationAdoption)) `
    -Godot $Godot -Python $pythonHost -ExpectedCampaignId $campaignId
Assert-R23D63 ([bool]$adoption.ok) (
    "campaign-attestation adoption failed: $(@($adoption.failure_codes) -join ',')"
)
Assert-R23D63 (
    [string]$adoption.source.commit -ceq [string]$source.commit -and
    [string]$adoption.source.tree_git_oid -ceq [string]$source.tree_git_oid
) "adoption source differs from the live source"

$lock = Enter-SporeSporeLocomotionOperationLock -Role physical
Assert-R23D63 ([bool]$lock.acquired) "global locomotion operation lock is held"
$attemptConsumed = $false
$completionPath = ""
try {
    $evidenceRoot = Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot
    $prior = @(Get-ChildItem -LiteralPath $evidenceRoot -Directory | Where-Object {
        $_.Name -like "qsdk-r23d63-*" -and (
            (Test-Path -LiteralPath (Join-Path $_.FullName "attempt-authorization.json")) -or
            (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json"))
        )
    })
    Assert-R23D63 ($prior.Count -eq 0) "one-shot R23D63 identity already exists"
    $resolvedOutput = if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        Join-Path $evidenceRoot (
            "qsdk-r23d63-" + [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ")
        )
    } else { [IO.Path]::GetFullPath($OutputRoot) }
    $prefix = $evidenceRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    Assert-R23D63 (
        $resolvedOutput.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
        -not (Test-Path -LiteralPath $resolvedOutput)
    ) "output must be a new directory under $evidenceRoot"
    [void][IO.Directory]::CreateDirectory($resolvedOutput)
    $completionPath = Join-Path $resolvedOutput "completion.json"

    $coreBuild = Invoke-SporeSporeR23D3PinnedCargo -RepoRoot $repoRoot `
        -SourceCommit ([string]$source.commit) -TargetRoot (Join-Path $sdkRoot "target") `
        -CargoArguments @(
            "build", "--quiet", "--release", "--locked", "--offline",
            "--manifest-path", (Join-Path $sdkRoot "Cargo.toml"),
            "--package", "sporespore-locomotion-core"
        )
    $godotBuild = Invoke-SporeSporeR23D3PinnedCargo -RepoRoot $repoRoot `
        -SourceCommit ([string]$source.commit) -TargetRoot (Join-Path $sdkRoot "target") `
        -CargoArguments @(
            "build", "--quiet", "--locked", "--offline",
            "--manifest-path", (Join-Path $sdkRoot "Cargo.toml"),
            "--package", "sporespore-godot-adapter"
        )
    $rapierBuild = Invoke-SporeSporeR23D3PinnedCargo -RepoRoot $repoRoot `
        -SourceCommit ([string]$source.commit) -TargetRoot (Join-Path $sdkRoot "target") `
        -CargoArguments @(
            "build", "--quiet", "--release", "--locked", "--offline",
            "--manifest-path", (Join-Path $sdkRoot "adapters\rapier\Cargo.toml"),
            "--bin", "qsdk_r23d63_physical"
        )
    foreach ($artifact in @(
        $coreReleasePath,
        $godotAdapterPath,
        $rapierReleasePath
    )) {
        Assert-R23D63 (Test-Path -LiteralPath $artifact -PathType Leaf) (
            "reproducible runtime artifact is missing: $artifact"
        )
    }
    $zeroWorld = Invoke-R23D63ZeroWorld $pythonHost $powerShellHost $coreReleasePath
    $inventory = Get-R23D63DependencyInventory $pythonHost $true
    $sourceAfter = Get-SporeSporeAttestationSourceIdentity -RepoRoot $repoRoot `
        -RequireCleanPushedLive
    Assert-R23D63 (
        [string]$sourceAfter.commit -ceq [string]$source.commit -and
        [string]$sourceAfter.tree_git_oid -ceq [string]$source.tree_git_oid
    ) "source changed during runtime materialization or zero-world gate"

    $sourceBindings = @($inventory.source_receipts)
    $runtimeArtifacts = @(
        [ordered]@{
            name = "locomotion_core_release"
            path = $coreReleasePath
            raw_sha256 = Get-R23D63Sha256 $coreReleasePath
            media_type = "application/vnd.microsoft.portable-executable"
            build_receipt = $coreBuild
        },
        [ordered]@{
            name = "godot_adapter_debug"
            path = $godotAdapterPath
            raw_sha256 = Get-R23D63Sha256 $godotAdapterPath
            media_type = "application/vnd.microsoft.portable-executable"
            build_receipt = $godotBuild
        },
        [ordered]@{
            name = "rapier_r23d63_release_worker"
            path = $rapierReleasePath
            raw_sha256 = Get-R23D63Sha256 $rapierReleasePath
            media_type = "application/vnd.microsoft.portable-executable"
            build_receipt = $rapierBuild
        }
    )
    $externalRuntimeBindings = @(
        [ordered]@{
            name = "godot_jolt_host"
            path = $Godot
            raw_sha256 = Get-R23D63Sha256 $Godot
            media_type = "application/vnd.microsoft.portable-executable"
        },
        [ordered]@{
            name = "evaluator_python_host"
            path = $pythonHost
            raw_sha256 = Get-R23D63Sha256 $pythonHost
            media_type = "application/vnd.microsoft.portable-executable"
        },
        [ordered]@{
            name = "powershell_trace_host"
            path = $powerShellHost
            raw_sha256 = Get-R23D63Sha256 $powerShellHost
            media_type = "application/vnd.microsoft.portable-executable"
        }
    )
    $inputCas = Publish-R23D63Inputs $sourceBindings $runtimeArtifacts `
        $externalRuntimeBindings ([IO.Path]::GetFullPath($CampaignAttestationAdoption))
    $freeze = [ordered]@{
        schema_version = "sporespore_qsdk_r23d63_physical_freeze_v1"
        status = "frozen_supervisor_only_physical_authorized"
        campaign_id = $campaignId
        gate_id = $gateId
        question_class = "finite_decision"
        preregistration_raw_sha256 = Get-R23D63Sha256 $preregistrationPath
        implementation_contract_raw_sha256 = Get-R23D63Sha256 $implementationPath
        source_commit = [string]$source.commit
        source_tree_git_oid = [string]$source.tree_git_oid
        origin_main_commit = [string]$source.origin_main
        live_github_main_commit = [string]$source.live_github_main
        dependency_inventory_complete = $true
        dependency_inventory = $inventory
        source_bindings = $sourceBindings
        runtime_artifacts = $runtimeArtifacts
        external_runtime_bindings = $externalRuntimeBindings
        content_addressed_inputs = $inputCas
        campaign_attestation_adoption_sha256 = [string]$adoption.sha256
        complete_zero_world_gate_passed = $true
        zero_world_receipt = $zeroWorld
        authorization_receipt_schema_conformance = (
            $zeroWorld.authorization_receipt_schema_conformance
        )
        authorization_receipt_schema_conformance_passed_before_freeze = $true
        declared_world_count = 9
        ordered_matrix_cell_ids = $cellIds
        serial_execution_required = $true
        all_cells_run_regardless_of_intermediate_outcome = $true
        terminal_restoration_or_taper_invoked = $false
        source_checkout_bytes_equal_git_blobs = $true
        reproducible_runtime_materialization_passed = $true
        physical_execution_authorized = $true
        physical_acceptance_authority = $false
    }
    $freezePath = Join-Path $resolvedOutput "physical-freeze.json"
    Write-R23D63NewJson $freezePath $freeze
    $freezeCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $freezePath -MediaType "application/json"
    Assert-R23D63FrozenBindings $freeze

    $attemptId = [Guid]::NewGuid().ToString("N")
    $token = [Guid]::NewGuid().ToString("N")
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_r23d63_attempt_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        attempt_id = $attemptId
        authorization_token = $token
        source_commit = [string]$source.commit
        authority_repo_root = $repoRoot
        freeze_raw_sha256 = [string]$freezeCas.sha256
        attempt_root = $resolvedOutput
        ordered_matrix_cell_ids = $cellIds
        physical_execution_authorized = $true
        single_use_supervisor_authorization = $true
        matrix_authorization_immutable_before_first_world = $true
        source_worktree_clean = $true
        source_matches_live_github_main = $true
        operation_lock_held = $true
        campaign_attestation_adoption_valid = $true
        content_addressed_inputs_retained = $true
        content_addressed_inputs = $inputCas
        authorization_receipt_schema_conformance = (
            $zeroWorld.authorization_receipt_schema_conformance
        )
        authorization_receipt_schema_conformance_passed_before_attempt = $true
        one_shot_attempt_unconsumed = $true
        all_cells_run_regardless_of_intermediate_outcome = $true
        physical_acceptance_authority = $false
    }
    $attemptPath = Join-Path $resolvedOutput "attempt-authorization.json"
    Write-R23D63NewJson $attemptPath $attempt
    $attemptCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $attemptPath -MediaType "application/json"
    $attemptConsumed = $true

    $authorizationPreflights = [Collections.Generic.List[object]]::new()
    foreach ($engineId in $engineOrder) {
        foreach ($armId in $armOffsets.Keys) {
            Assert-R23D63FrozenBindings $freeze
            $cellId = "{0}__s{1}__{2}__{3}" -f (
                $engineId,
                $campaignSeed,
                $cellProfileTag,
                $armId
            )
            $environment = @{
                "SPORESPORE_QSDK_R23D63_FREEZE" = [string]$freezeCas.payload_path
                "SPORESPORE_QSDK_R23D63_ATTEMPT" = [string]$attemptCas.payload_path
                "SPORESPORE_QSDK_R23D63_TOKEN" = $token
                "SPORESPORE_QSDK_R23D63_STAGE" = $stageId
                "SPORESPORE_QSDK_R23D63_CELL" = $cellId
                "SPORESPORE_QSDK_R23D63_ENGINE" = $engineId
                "SPORESPORE_QSDK_R23D63_ATTEMPT_ROOT" = $resolvedOutput
                "SPORESPORE_QSDK_R23D63_AUTHORITY_REPO_ROOT" = $repoRoot
                "SPORESPORE_QSDK_R23D63_PYTHON" = $pythonHost
                "SPORESPORE_QSDK_R23D63_POWERSHELL" = $powerShellHost
            }
            if ($engineId -ceq "godot_jolt") {
                $arguments = @(
                    "--headless", "--path", $repoRoot,
                    "--script", $workerResourcePath, "--",
                    "--authorization-preflight-only",
                    "--stage", $stageId, "--onset", "onset_600",
                    "--seed", [string]$campaignSeed,
                    "--profile", $profileId, "--arm", $armId,
                    "--source-commit", [string]$source.commit
                )
                $authorizationProcess = Invoke-R23D63GodotWorkerProcess -Arguments $arguments -Environment $environment -TimeoutSeconds 300
                $authorizationMarker = "QSDK_R23D63_GODOT_JOLT_AUTHORIZATION_PREFLIGHT "
                $authorizationSchema = "sporespore_qsdk_r23d63_godot_jolt_production_authorization_preflight_v1"
            } elseif ($engineId -ceq "rapier_parry") {
                $arguments = @(
                    "authorization-preflight",
                    "--stage", $stageId, "--onset", "onset_600",
                    "--campaign-seed", [string]$campaignSeed,
                    "--profile", $profileId, "--arm", $armId,
                    "--source-commit", [string]$source.commit
                )
                $authorizationProcess = Invoke-R23D63Process -FileName $rapierReleasePath -Arguments $arguments -WorkingDirectory $repoRoot -Environment $environment -TimeoutSeconds 300
                $authorizationMarker = "QSDK_R23D63_RAPIER_AUTHORIZATION_PREFLIGHT "
                $authorizationSchema = "sporespore_qsdk_r23d63_rapier_production_authorization_preflight_v1"
            } else {
                foreach ($entry in (Get-R23D63PythonEnvironment $coreReleasePath).GetEnumerator()) {
                    $environment[[string]$entry.Key] = [string]$entry.Value
                }
                $arguments = @(
                    "-m", $mujocoWorkerModule,
                    "authorization-preflight",
                    "--stage", $stageId, "--onset", "onset_600",
                    "--campaign-seed", [string]$campaignSeed,
                    "--profile", $profileId, "--arm", $armId,
                    "--source-commit", [string]$source.commit
                )
                $authorizationProcess = Invoke-R23D63Process -FileName $pythonHost -Arguments $arguments -WorkingDirectory $repoRoot -Environment $environment -TimeoutSeconds 300
                $authorizationMarker = "QSDK_R23D63_MUJOCO_AUTHORIZATION_PREFLIGHT "
                $authorizationSchema = "sporespore_qsdk_r23d63_mujoco_production_authorization_preflight_v1"
            }

            $authorizationRoot = Join-Path $resolvedOutput (
                "authorization-preflight\$cellId"
            )
            [void][IO.Directory]::CreateDirectory($authorizationRoot)
            $authorizationStdoutPath = Join-Path $authorizationRoot "stdout.txt"
            $authorizationStderrPath = Join-Path $authorizationRoot "stderr.txt"
            [IO.File]::WriteAllText(
                $authorizationStdoutPath,
                [string]$authorizationProcess.stdout,
                [Text.UTF8Encoding]::new($false)
            )
            [IO.File]::WriteAllText(
                $authorizationStderrPath,
                [string]$authorizationProcess.stderr,
                [Text.UTF8Encoding]::new($false)
            )
            $authorizationStdoutCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot -ArtifactPath $authorizationStdoutPath -MediaType "text/plain"
            $authorizationStderrCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot -ArtifactPath $authorizationStderrPath -MediaType "text/plain"
            Assert-R23D63 (
                [int]$authorizationProcess.exit_code -eq 0 -and
                -not [bool]$authorizationProcess.timed_out
            ) "strict physical authorization preflight process invalid: $cellId"
            if ($engineId -ceq "godot_jolt") {
                Assert-R23D63 (
                    [bool]$authorizationProcess.termination_protocol_valid -and
                    [bool]$authorizationProcess.supervisor_terminated -and
                    [string]$authorizationProcess.termination_ready_receipt.worker_receipt_kind -ceq
                        "authorization_preflight"
                ) "Godot authorization termination invalid: $cellId"
            }
            $authorizationReceipt = Get-R23D63MarkerJson (
                [string]$authorizationProcess.stdout
            ) $authorizationMarker
            Assert-R23D63CompleteMatrixProof $authorizationReceipt $engineId
            Assert-R23D63 (
                [string]$authorizationReceipt.schema_version -ceq $authorizationSchema -and
                [string]$authorizationReceipt.campaign_id -ceq $campaignId -and
                [string]$authorizationReceipt.gate_id -ceq $gateId -and
                [string]$authorizationReceipt.engine_id -ceq $engineId -and
                [string]$authorizationReceipt.stage_id -ceq $stageId -and
                [string]$authorizationReceipt.cell_id -ceq $cellId -and
                [bool]$authorizationReceipt.authorization_passed -and
                [bool]$authorizationReceipt.complete_ordered_nine_cell_matrix_validated -and
                [bool]$authorizationReceipt.returned_before_model -and
                [int]$authorizationReceipt.model_construction_count -eq 0 -and
                [int]$authorizationReceipt.world_attempt_count -eq 0 -and
                [int]$authorizationReceipt.world_build_count -eq 0 -and
                -not [bool]$authorizationReceipt.physical_acceptance_authority
            ) "strict physical authorization preflight receipt invalid: $cellId"
            $godotAuthorization = $engineId -ceq "godot_jolt"
            $authorizationPreflights.Add([ordered]@{
                cell_id = $cellId
                engine_id = $engineId
                worker_receipt = $authorizationReceipt
                process = [ordered]@{
                    exit_code = [int]$authorizationProcess.exit_code
                    host_exit_code = if ($godotAuthorization) {
                        [int]$authorizationProcess.host_exit_code
                    } else {
                        [int]$authorizationProcess.exit_code
                    }
                    timed_out = [bool]$authorizationProcess.timed_out
                    supervisor_terminated = if ($godotAuthorization) {
                        [bool]$authorizationProcess.supervisor_terminated
                    } else {
                        $false
                    }
                    termination_protocol_valid = if ($godotAuthorization) {
                        [bool]$authorizationProcess.termination_protocol_valid
                    } else {
                        $true
                    }
                    termination_ready_receipt = if ($godotAuthorization) {
                        $authorizationProcess.termination_ready_receipt
                    } else {
                        $null
                    }
                    started_utc = [string]$authorizationProcess.started_utc
                    completed_utc = [string]$authorizationProcess.completed_utc
                    stdout_cas = $authorizationStdoutCas
                    stderr_cas = $authorizationStderrCas
                }
                physical_acceptance_authority = $false
            })
        }
    }
    Assert-R23D63 ($authorizationPreflights.Count -eq 9) (
        "strict physical authorization preflight matrix incomplete"
    )

    $authorizationPreflightPath = Join-Path $resolvedOutput (
        "authorization-preflight.json"
    )
    Write-R23D63NewJson $authorizationPreflightPath ([ordered]@{
        schema_version = "sporespore_qsdk_r23d63_authorization_preflight_matrix_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        source_commit = [string]$source.commit
        ordered_receipts = @($authorizationPreflights)
        receipt_count = $authorizationPreflights.Count
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        physical_acceptance_authority = $false
    })
    $authorizationPreflightCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $authorizationPreflightPath `
        -MediaType "application/json"

    $cells = [Collections.Generic.List[object]]::new()
    foreach ($engineId in $engineOrder) {
        foreach ($armId in $armOffsets.Keys) {
            Assert-R23D63FrozenBindings $freeze
            $sourceBeforeCell = Get-SporeSporeAttestationSourceIdentity `
                -RepoRoot $repoRoot -RequireCleanPushedLive
            Assert-R23D63 (
                [string]$sourceBeforeCell.commit -ceq [string]$source.commit -and
                [string]$sourceBeforeCell.tree_git_oid -ceq [string]$source.tree_git_oid
            ) "source changed before cell $engineId/$armId"
            $cellId = "{0}__s{1}__{2}__{3}" -f (
                $engineId,
                $campaignSeed,
                $cellProfileTag,
                $armId
            )
            $cellRoot = Join-Path $resolvedOutput ("cells\$cellId")
            $cells.Add((Invoke-R23D63Cell -EngineId $engineId -ArmId $armId `
                -SourceCommit ([string]$source.commit) `
                -FreezePayload ([string]$freezeCas.payload_path) `
                -AttemptPayload ([string]$attemptCas.payload_path) -Token $token `
                -AttemptRoot $resolvedOutput -CellRoot $cellRoot `
                -PythonHost $pythonHost -PowerShellHost $powerShellHost))
        }
    }

    Assert-R23D63FrozenBindings $freeze
    $sourceAfterCells = Get-SporeSporeAttestationSourceIdentity `
        -RepoRoot $repoRoot -RequireCleanPushedLive
    Assert-R23D63 (
        [string]$sourceAfterCells.commit -ceq [string]$source.commit -and
        [string]$sourceAfterCells.tree_git_oid -ceq [string]$source.tree_git_oid
    ) "source changed during the serialized physical matrix"
    $terminalPaths = @($cells | ForEach-Object {
        [string]$_.terminal_entry_cas.payload_path
    })
    $terminalManifestPath = Join-Path $resolvedOutput "terminal-paths.json"
    Write-R23D63NewJson $terminalManifestPath $terminalPaths
    $terminalManifestCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot -ArtifactPath $terminalManifestPath `
        -MediaType "application/json"
    $evaluationProcess = Invoke-R23D63Process -FileName $pythonHost -Arguments @(
        $evaluatorPath, "evaluate-complete", "--manifest",
        [string]$terminalManifestCas.payload_path, "--expected-source-commit",
        [string]$source.commit, "--authority-repo-root", $repoRoot
    ) -WorkingDirectory $repoRoot `
        -Environment (Get-R23D63PythonEnvironment $coreReleasePath) `
        -TimeoutSeconds 1200
    Assert-R23D63 ($evaluationProcess.exit_code -eq 0 -and -not $evaluationProcess.timed_out) (
        "complete evaluator failed: $($evaluationProcess.stderr) $($evaluationProcess.stdout)"
    )
    $evaluation = Get-R23D63MarkerJson $evaluationProcess.stdout (
        "QSDK_R23D63_COMPLETE_EVALUATION "
    )
    $evaluationPath = Join-Path $resolvedOutput "complete-evaluation.json"
    Write-R23D63NewJson $evaluationPath $evaluation
    $evaluationCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $evaluationPath -MediaType "application/json"
    $worldCountLowerBound = 0
    $worldCountUpperBound = 0
    $worldCountExact = $true
    foreach ($cell in @($cells)) {
        $worldCountLowerBound += [int]$cell.world_build_count_lower_bound
        $worldCountUpperBound += [int]$cell.world_build_count_upper_bound
        $worldCountExact = $worldCountExact -and [bool]$cell.world_build_count_exact
    }
    $report = [ordered]@{
        schema_version = "sporespore_qsdk_r23d63_campaign_report_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        question_class = "finite_decision"
        source = $source
        attempt_id = $attemptId
        freeze_cas = $freezeCas
        attempt_authorization_cas = $attemptCas
        authorization_preflight_cas = $authorizationPreflightCas
        authorization_preflight_count = $authorizationPreflights.Count
        terminal_manifest_cas = $terminalManifestCas
        complete_evaluation_cas = $evaluationCas
        ordered_cells = @($cells)
        complete_evaluation = $evaluation
        result_classification = [string]$evaluation.classification
        all_nine_cells_executed_or_retained_as_failures = $cells.Count -eq 9
        world_build_count_exact = $worldCountExact
        world_build_count_lower_bound = $worldCountLowerBound
        world_build_count_upper_bound = $worldCountUpperBound
        terminal_restoration_or_taper_invoked = $false
        claims = $evaluation.claims
    }
    $reportPath = Join-Path $resolvedOutput "report.json"
    Write-R23D63NewJson $reportPath $report
    $reportCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $reportPath -MediaType "application/json"
    $completion = [ordered]@{
        schema_version = "sporespore_qsdk_r23d63_completion_v1"
        campaign_id = $campaignId
        gate_id = $gateId
        attempt_id = $attemptId
        status = [string]$evaluation.classification
        source_commit = [string]$source.commit
        cell_count = $cells.Count
        world_count = $worldCountLowerBound
        world_count_exact = $worldCountExact
        world_count_lower_bound = $worldCountLowerBound
        world_count_upper_bound = $worldCountUpperBound
        selected_profile_id = [string]$evaluation.selected_public_profile_id
        finite_three_engine_turning_positive = [bool]$evaluation.finite_decision.finite_three_engine_turning_positive
        report_cas = $reportCas
        complete_evaluation_cas = $evaluationCas
        authorization_preflight_cas = $authorizationPreflightCas
        authorization_preflight_count = $authorizationPreflights.Count
        one_shot_attempt_consumed = $true
        replacement_or_selective_rerun_permitted = $false
        completed_utc = [DateTime]::UtcNow.ToString("o")
        physical_acceptance_authority = $false
    }
    Write-R23D63NewJson $completionPath $completion
    $completionCas = Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
        -ArtifactPath $completionPath -MediaType "application/json"
    Write-Host (
        "QSDK_R23D63_PHYSICAL_COMPLETE classification=$($evaluation.classification) " +
        "turning=$($evaluation.finite_decision.finite_three_engine_turning_positive) " +
        "cells=$($cells.Count) report_sha256=$($reportCas.sha256) " +
        "completion_sha256=$($completionCas.sha256) output=$resolvedOutput"
    )
    if (([string]$evaluation.classification).StartsWith(
        "invalid_", [StringComparison]::Ordinal
    )) {
        throw "QSDK-R23D63 retained an invalid complete first attempt: $resolvedOutput"
    }
} catch {
    if ($attemptConsumed -and -not [string]::IsNullOrWhiteSpace($completionPath) -and
        -not (Test-Path -LiteralPath $completionPath)) {
        $emergency = [ordered]@{
            schema_version = "sporespore_qsdk_r23d63_completion_v1"
            campaign_id = $campaignId
            gate_id = $gateId
            status = "invalid_or_incomplete_first_attempt"
            source_commit = [string]$source.commit
            one_shot_attempt_consumed = $true
            replacement_or_selective_rerun_permitted = $false
            failure_message = [string]$_.Exception.Message
            completed_utc = [DateTime]::UtcNow.ToString("o")
            physical_acceptance_authority = $false
        }
        Write-R23D63NewJson $completionPath $emergency
        [void](Publish-SporeSporeContentAddressedArtifact -RepoRoot $repoRoot `
            -ArtifactPath $completionPath -MediaType "application/json")
    }
    throw
} finally {
    Exit-SporeSporeLocomotionOperationLock $lock
}

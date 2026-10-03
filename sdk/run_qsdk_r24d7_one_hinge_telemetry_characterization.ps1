#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet("ZeroWorld", "Physical")]
    [string]$Mode = "ZeroWorld",
    [string]$AuthorizationCommit = "",
    [string]$ZeroWorldReceiptPath = "",
    [string]$Python = "python",
    [string]$EvidenceRoot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$expectedRepoRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$manifestRelative = (
    "sdk/recovery/" +
    "r24d7_godot_jolt_one_hinge_telemetry_validation_manifest.json"
)
$contractRelative = (
    "sdk/recovery/" +
    "r24d7_godot_jolt_one_hinge_telemetry_characterization_" +
    "preregistration_v1.json"
)
$evaluatorRelative = (
    "sdk/recovery/" +
    "r24d7_godot_jolt_one_hinge_telemetry_characterization_evaluator.py"
)
$integralSchemaRelative = "sdk/recovery/r24d7_integral_variant_schema_v1.json"
$rigRelative = (
    "scripts/lab/rigs/" +
    "r24d7_godot_jolt_one_hinge_telemetry_rig.gd"
)
$probeRelative = (
    "scripts/lab/rigs/" +
    "r24d7_godot_jolt_telemetry_stepping_probe_body.gd"
)
$workerRelative = (
    "tests/" +
    "test_sdk_qsdk_r24d7_godot_jolt_one_hinge_telemetry_physical_worker.gd"
)
$freezeAuditRelative = "tests/test_qsdk_r24d7_one_hinge_telemetry_freeze.ps1"
$predecessorClosureAuditRelative = (
    "tests/test_qsdk_r24d6_one_hinge_telemetry_" +
    "zero_world_failure_closure.ps1"
)
$sourceAuditRelative = (
    "tests/test_qsdk_r24d3_godot_jolt_motor_telemetry_source.ps1"
)
$adoptionAuditRelative = (
    "tests/test_qsdk_r24d3_godot_jolt_motor_telemetry_cold_" +
    "qualification_adoption.ps1"
)
$fullColdAuditRelative = (
    "tests/test_qsdk_r24d3_godot_jolt_motor_telemetry_post_adoption_" +
    "full_cold_conformance_qualification.ps1"
)
$adoptionRelative = (
    "sdk/recovery/r24d3_godot_jolt_motor_telemetry_" +
    "cold_qualification_adoption_v2.json"
)
$expectedConsoleHash = (
    "762ed7137d06284742b53abdde9b98c692ab1e8d3a184458db4d8e7a39782462"
)
$expectedEngineHash = (
    "d0bb895b996fa98ec69a68b9f98ca6ed99af2eb18ef67a0b176ad1a55220278d"
)
$expectedConsoleLength = 293376L
$expectedEngineLength = 188826624L
$readyPrefix = "QSDK_R24D7_GODOT_SUPERVISOR_TERMINATION_READY "
$workerZeroPrefix = "QSDK_R24D7_WORKER_ZERO_WORLD "
$workerDefaultEnvelopePrefix = (
    "QSDK_R24D7_ZERO_WORLD_DEFAULT_PRECISION_ENVELOPE "
)
$workerFullEnvelopePrefix = (
    "QSDK_R24D7_ZERO_WORLD_FULL_PRECISION_ENVELOPE "
)
$templatePrefix = "QSDK_R24D7_ZERO_WORLD_TEMPLATE "
$zeroEvaluationPrefix = (
    "QSDK_R24D7_SERIALIZED_ENVELOPE_ZERO_WORLD_EVALUATION "
)
$workerPhysicalPrefix = "QSDK_R24D7_PHYSICAL_RAW_REPORT "

. (Join-Path $sdkRoot "locomotion_operation_lock.ps1")
. (Join-Path $sdkRoot "godot_receipt_terminated_process.ps1")
. (Join-Path $sdkRoot "content_addressed_artifact_store.ps1")

function Assert-R24D7Supervisor {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) { throw "QSDK-R24D7 supervisor: $Code" }
}

function Get-R24D7Path {
    param([Parameter(Mandatory)][string]$Relative)
    return [IO.Path]::GetFullPath((Join-Path $repoRoot $Relative))
}

function Resolve-R24D7Application {
    param([Parameter(Mandatory)][string]$Command)
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R24D7Supervisor (
            Test-Path -LiteralPath $resolved -PathType Leaf
        ) "application_missing:$resolved"
        return $resolved
    }
    $candidate = Get-Command -Name $Command -CommandType Application |
        Select-Object -First 1
    Assert-R24D7Supervisor ($null -ne $candidate) "application_missing:$Command"
    return [IO.Path]::GetFullPath([string]$candidate.Source)
}

function Get-R24D7GitValue {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-R24D7Supervisor ($LASTEXITCODE -eq 0) (
        "git_failed:$($Arguments -join ','):$($output -join '|')"
    )
    return ($output -join "`n").Trim()
}

function Get-R24D7FileReceipt {
    param([Parameter(Mandatory)][string]$Path)
    $item = Get-Item -LiteralPath $Path
    return [ordered]@{
        path = $Path.Replace("\", "/")
        raw_sha256 = "sha256:" + (
            Get-FileHash -LiteralPath $Path -Algorithm SHA256
        ).Hash.ToLowerInvariant()
        byte_length = [long]$item.Length
    }
}

function Assert-R24D7ExactKeys {
    param(
        [Parameter(Mandatory)][hashtable]$Value,
        [Parameter(Mandatory)][string[]]$Expected,
        [Parameter(Mandatory)][string]$Code
    )
    $observed = @($Value.Keys | ForEach-Object { [string]$_ })
    Assert-R24D7Supervisor (
        $observed.Count -eq $Expected.Count -and
        @($Expected | Where-Object { $_ -cnotin $observed }).Count -eq 0
    ) "${Code}_keys"
}

function Assert-R24D7RetainedFileAndCas {
    param(
        [Parameter(Mandatory)][hashtable]$FileReceipt,
        [Parameter(Mandatory)][hashtable]$CasReceipt,
        [Parameter(Mandatory)][string]$ExpectedRunRoot,
        [Parameter(Mandatory)][string]$EvidenceBase,
        [Parameter(Mandatory)][string]$Code
    )
    Assert-R24D7ExactKeys `
        -Value $FileReceipt `
        -Expected @("path", "raw_sha256", "byte_length") `
        -Code "${Code}_file_receipt"
    Assert-R24D7ExactKeys `
        -Value $CasReceipt `
        -Expected @(
            "schema_version",
            "sha256",
            "byte_length",
            "payload_path",
            "manifest_path",
            "already_present",
            "test_only",
            "physical_acceptance_authority"
        ) `
        -Code "${Code}_cas_receipt"
    $runBase = [IO.Path]::GetFullPath($ExpectedRunRoot).TrimEnd("\", "/")
    $filePath = [IO.Path]::GetFullPath([string]$FileReceipt.path)
    Assert-R24D7Supervisor (
        $filePath.StartsWith(
            $runBase + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        (Test-Path -LiteralPath $filePath -PathType Leaf)
    ) "${Code}_file_path"
    $live = Get-R24D7FileReceipt $filePath
    Assert-R24D7Supervisor (
        [string]$FileReceipt.path -ceq [string]$live.path -and
        [string]$FileReceipt.raw_sha256 -ceq [string]$live.raw_sha256 -and
        [long]$FileReceipt.byte_length -eq [long]$live.byte_length
    ) "${Code}_file_bytes"
    $digest = ([string]$live.raw_sha256).Substring(7)
    $expectedCasDirectory = Join-Path $EvidenceBase "artifacts\sha256\$digest"
    $expectedPayload = Join-Path $expectedCasDirectory "payload.bin"
    $expectedManifest = Join-Path $expectedCasDirectory "manifest.json"
    Assert-R24D7Supervisor (
        [string]$CasReceipt.schema_version -ceq
            "sporespore_content_addressed_artifact_receipt_v1" -and
        [string]$CasReceipt.sha256 -ceq [string]$live.raw_sha256 -and
        [long]$CasReceipt.byte_length -eq [long]$live.byte_length -and
        [IO.Path]::GetFullPath([string]$CasReceipt.payload_path) -ceq
            [IO.Path]::GetFullPath($expectedPayload) -and
        [IO.Path]::GetFullPath([string]$CasReceipt.manifest_path) -ceq
            [IO.Path]::GetFullPath($expectedManifest) -and
        -not [bool]$CasReceipt.test_only -and
        -not [bool]$CasReceipt.physical_acceptance_authority -and
        (Test-SporeSporeStoredArtifact `
            -Directory $expectedCasDirectory `
            -ExpectedSha256 $digest `
            -ExpectedByteLength ([long]$live.byte_length))
    ) "${Code}_cas_bytes"
}

function Invoke-R24D7Checked {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$LogPath
    )
    $started = [DateTimeOffset]::UtcNow
    Push-Location -LiteralPath $repoRoot
    try {
        $output = @(& $FileName @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    $finished = [DateTimeOffset]::UtcNow
    $text = @(
        "label=$Label"
        "started_utc=$($started.ToString('o'))"
        "finished_utc=$($finished.ToString('o'))"
        "exit_code=$exitCode"
        "command=$FileName $($Arguments -join ' ')"
        "--- output ---"
        @($output | ForEach-Object { [string]$_ })
    ) -join "`n"
    [IO.File]::WriteAllText(
        $LogPath,
        $text + "`n",
        [Text.UTF8Encoding]::new($false)
    )
    Assert-R24D7Supervisor ($exitCode -eq 0) (
        "$Label failed:$($output -join '|')"
    )
    return [ordered]@{
        output = @($output | ForEach-Object { [string]$_ })
        duration_s = [Math]::Round(($finished - $started).TotalSeconds, 6)
        log = Get-R24D7FileReceipt $LogPath
    }
}

function Invoke-R24D7ExpectedFailure {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$LogPath,
        [Parameter(Mandatory)][int]$ExpectedExitCode,
        [Parameter(Mandatory)][string]$ExpectedMarker
    )
    $started = [DateTimeOffset]::UtcNow
    Push-Location -LiteralPath $repoRoot
    try {
        $output = @(& $FileName @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    $finished = [DateTimeOffset]::UtcNow
    $lines = @($output | ForEach-Object { [string]$_ })
    $text = @(
        "label=$Label"
        "started_utc=$($started.ToString('o'))"
        "finished_utc=$($finished.ToString('o'))"
        "exit_code=$exitCode"
        "command=$FileName $($Arguments -join ' ')"
        "--- output ---"
        $lines
    ) -join "`n"
    [IO.File]::WriteAllText(
        $LogPath,
        $text + "`n",
        [Text.UTF8Encoding]::new($false)
    )
    $matchingMarkers = @($lines | Where-Object {
        [string]$_ -ceq $ExpectedMarker
    })
    Assert-R24D7Supervisor (
        $exitCode -eq $ExpectedExitCode -and $matchingMarkers.Count -eq 1
    ) (
        "$Label expected_exit=$ExpectedExitCode actual_exit=$exitCode " +
        "expected_marker=$ExpectedMarker output=$($lines -join '|')"
    )
    return [ordered]@{
        output = $lines
        exit_code = $exitCode
        expected_marker = $ExpectedMarker
        duration_s = [Math]::Round(($finished - $started).TotalSeconds, 6)
        log = Get-R24D7FileReceipt $LogPath
    }
}

function Get-R24D7Marker {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines,
        [Parameter(Mandatory)][string]$Prefix,
        [Parameter(Mandatory)][string]$Code
    )
    $matches = @($Lines | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R24D7Supervisor ($matches.Count -eq 1) (
        "$Code marker_count=$($matches.Count)"
    )
    return ([string]$matches[0]).Substring($Prefix.Length)
}

function Assert-R24D7ManifestAndBindings {
    param(
        [Parameter(Mandatory)][string]$Head,
        [Parameter(Mandatory)][hashtable]$Manifest
    )
    Assert-R24D7Supervisor (
        [string]$Manifest.schema_version -ceq
        "sporespore_qsdk_r24d7_one_hinge_telemetry_validation_manifest_v1"
    ) "manifest_schema"
    Assert-R24D7Supervisor ([string]$Manifest.gate_id -ceq "QSDK-R24D7") (
        "manifest_gate"
    )
    Assert-R24D7Supervisor (
        [string]$Manifest.question_class -ceq "development"
    ) "manifest_question_class"
    $bindings = @($Manifest.bindings)
    Assert-R24D7Supervisor (
        $bindings.Count -eq 11 -and
        [int]$Manifest.source_binding_count -eq 11
    ) "manifest_binding_count"
    Assert-R24D7Supervisor (
        [string]$Manifest.predecessor_gate_id -ceq "QSDK-R24D6" -and
        [string]$Manifest.predecessor_source_commit -ceq
            "55032839756cc8a9089a2a4eb4e06db71ab99ca4" -and
        [string]$Manifest.predecessor_closure_id -ceq
            "QSDK-R24D6-ZW2-CLOSURE" -and
        [string]$Manifest.predecessor_status -ceq
            "valid_zero_world_negative_full_precision_integral_variant_type_loss" -and
        [string]$Manifest.predecessor_result_class -ceq
            "complete_zero_world_gate_failed_no_qualification_no_physics" -and
        [int]$Manifest.prior_official_zero_world_qualification_failure_count -eq 0 -and
        [int]$Manifest.official_zero_world_qualification_count -eq 0 -and
        [string]$Manifest.integral_variant_schema_id -ceq
            "QSDK-R24D7-INTEGRAL-VARIANT-SCHEMA-V1" -and
        [int]$Manifest.integral_path_family_count -eq 21 -and
        [int]$Manifest.integral_occurrence_count -eq 313 -and
        [int]$Manifest.predecessor_strict_integral_occurrence_count -eq 234 -and
        [int]$Manifest.evaluator_baseline_negative_control_count -eq 29 -and
        [int]$Manifest.integral_family_type_loss_negative_control_count -eq 21 -and
        [int]$Manifest.evaluator_total_negative_control_count -eq 50 -and
        [int]$Manifest.contract_mutation_rejection_count -eq 22
    ) "manifest_successor_boundary"
    $paths = @($bindings | ForEach-Object { [string]$_.path })
    Assert-R24D7Supervisor (
        ($paths | Select-Object -Unique).Count -eq $paths.Count
    ) "manifest_duplicate_path"
    foreach ($binding in $bindings) {
        $relative = [string]$binding.path
        $absolute = Get-R24D7Path $relative
        Assert-R24D7Supervisor (
            Test-Path -LiteralPath $absolute -PathType Leaf
        ) "binding_missing:$relative"
        $live = Get-R24D7FileReceipt $absolute
        Assert-R24D7Supervisor (
            [string]$binding.raw_sha256 -ceq [string]$live.raw_sha256 -and
            [long]$binding.byte_length -eq [long]$live.byte_length
        ) "binding_bytes:$relative"
        $blobOid = Get-R24D7GitValue @("rev-parse", "$Head`:$relative")
        $liveBlobOid = Get-R24D7GitValue @("hash-object", "--", $absolute)
        Assert-R24D7Supervisor (
            $blobOid -ceq [string]$binding.git_blob_oid -and
            $blobOid -ceq $liveBlobOid
        ) "binding_git_blob:$relative"
    }
    foreach ($key in @(
        "complete_zero_world_gate_passed",
        "physical_characterization_executed",
        "instrumented_profile_promoted",
        "physical_acceptance_authority",
        "release_authority"
    )) {
        Assert-R24D7Supervisor (-not [bool]$Manifest[$key]) (
            "manifest_claim:$key"
        )
    }
}

function Assert-R24D7IntegralNormalizationReceipt {
    param(
        [Parameter(Mandatory)][hashtable]$Value,
        [Parameter(Mandatory)][hashtable]$SchemaReceipt,
        [Parameter(Mandatory)][string]$Code
    )
    Assert-R24D7ExactKeys `
        -Value $Value `
        -Expected @(
            "ok",
            "schema_id",
            "schema_raw_sha256",
            "schema_byte_length",
            "declared_path_family_count",
            "declared_occurrence_count",
            "predecessor_strict_occurrence_count",
            "processed_path_family_count",
            "pre_normalization_float_occurrence_count",
            "pre_normalization_non_float_occurrence_count",
            "normalized_occurrence_count",
            "post_normalization_integer_occurrence_count",
            "post_normalization_non_integer_occurrence_count",
            "missing_occurrence_count",
            "count_mismatch_family_count",
            "unexpected_family_count",
            "numeric_value_change_count",
            "family_receipts"
        ) `
        -Code $Code
    $families = @($Value.family_receipts)
    Assert-R24D7Supervisor (
        [bool]$Value.ok -and
        [string]$Value.schema_id -ceq
            "QSDK-R24D7-INTEGRAL-VARIANT-SCHEMA-V1" -and
        [string]$Value.schema_raw_sha256 -ceq [string]$SchemaReceipt.raw_sha256 -and
        [long]$Value.schema_byte_length -eq [long]$SchemaReceipt.byte_length -and
        [int]$Value.declared_path_family_count -eq 21 -and
        [int]$Value.declared_occurrence_count -eq 313 -and
        [int]$Value.predecessor_strict_occurrence_count -eq 234 -and
        [int]$Value.processed_path_family_count -eq 21 -and
        [int]$Value.pre_normalization_float_occurrence_count -eq 313 -and
        [int]$Value.pre_normalization_non_float_occurrence_count -eq 0 -and
        [int]$Value.normalized_occurrence_count -eq 313 -and
        [int]$Value.post_normalization_integer_occurrence_count -eq 313 -and
        [int]$Value.post_normalization_non_integer_occurrence_count -eq 0 -and
        [int]$Value.missing_occurrence_count -eq 0 -and
        [int]$Value.count_mismatch_family_count -eq 0 -and
        [int]$Value.unexpected_family_count -eq 0 -and
        [int]$Value.numeric_value_change_count -eq 0 -and
        $families.Count -eq 21 -and
        @(
            $families |
                ForEach-Object { [string]$_.family_id } |
                Select-Object -Unique
        ).Count -eq 21
    ) $Code
    foreach ($familyValue in $families) {
        $family = [hashtable]$familyValue
        Assert-R24D7ExactKeys `
            -Value $family `
            -Expected @(
                "family_id",
                "scope",
                "field",
                "expected_occurrence_count",
                "observed_container_count",
                "pre_float_count",
                "pre_non_float_count",
                "normalized_count",
                "post_integer_count",
                "post_non_integer_count",
                "missing_count",
                "numeric_value_change_count"
            ) `
            -Code "$Code`:$([string]$family.family_id)"
        $count = [int]$family.expected_occurrence_count
        Assert-R24D7Supervisor (
            -not [string]::IsNullOrWhiteSpace([string]$family.family_id) -and
            $count -gt 0 -and
            [int]$family.observed_container_count -eq $count -and
            [int]$family.pre_float_count -eq $count -and
            [int]$family.pre_non_float_count -eq 0 -and
            [int]$family.normalized_count -eq $count -and
            [int]$family.post_integer_count -eq $count -and
            [int]$family.post_non_integer_count -eq 0 -and
            [int]$family.missing_count -eq 0 -and
            [int]$family.numeric_value_change_count -eq 0
        ) "$Code`:$([string]$family.family_id)"
    }
}

function New-R24D7Project {
    param([Parameter(Mandatory)][string]$ProjectRoot)
    $rigDestination = Join-Path $ProjectRoot (
        "scripts\lab\rigs\r24d7_godot_jolt_one_hinge_telemetry_rig.gd"
    )
    $probeDestination = Join-Path $ProjectRoot (
        "scripts\lab\rigs\r24d7_godot_jolt_telemetry_stepping_probe_body.gd"
    )
    $workerDestination = Join-Path $ProjectRoot (
        "tests\test_sdk_qsdk_r24d7_godot_jolt_one_hinge_telemetry_" +
        "physical_worker.gd"
    )
    $integralSchemaDestination = Join-Path $ProjectRoot "integral_variant_schema.json"
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $rigDestination))
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $workerDestination))
    Copy-Item -LiteralPath (Get-R24D7Path $rigRelative) -Destination $rigDestination
    Copy-Item -LiteralPath (Get-R24D7Path $probeRelative) -Destination $probeDestination
    Copy-Item -LiteralPath (Get-R24D7Path $workerRelative) -Destination $workerDestination
    Copy-Item `
        -LiteralPath (Get-R24D7Path $integralSchemaRelative) `
        -Destination $integralSchemaDestination
    $projectText = @'
; QSDK-R24D7 isolated one-hinge telemetry characterization.
config_version=5

[application]
config/name="qsdk-r24d7-one-hinge-telemetry"
config/features=PackedStringArray("4.7", "Forward Plus")

[debug]
gdscript/warnings/shadowed_global_identifier=0

[physics]
common/physics_ticks_per_second=120
3d/physics_engine="Jolt Physics"
3d/run_on_separate_thread=false
jolt_physics_3d/simulation/velocity_steps=20
jolt_physics_3d/simulation/position_steps=7
'@
    [IO.File]::WriteAllText(
        (Join-Path $ProjectRoot "project.godot"),
        $projectText.Replace("`r`n", "`n") + "`n",
        [Text.UTF8Encoding]::new($false)
    )
}

function Invoke-R24D7Worker {
    param(
        [Parameter(Mandatory)][string]$ConsolePath,
        [Parameter(Mandatory)][string]$ProjectRoot,
        [Parameter(Mandatory)][string]$RunRoot,
        [Parameter(Mandatory)][string]$WorkerMode,
        [Parameter(Mandatory)][string]$Nonce,
        [Parameter(Mandatory)][string]$Head
    )
    $engineLogPath = Join-Path $RunRoot ("godot-$WorkerMode-engine.log")
    $arguments = @(
        "--headless",
        "--path", $ProjectRoot,
        "--log-file", $engineLogPath,
        "--script", (
            "res://tests/" +
            "test_sdk_qsdk_r24d7_godot_jolt_one_hinge_telemetry_" +
            "physical_worker.gd"
        ),
        "--",
        "--mode=$WorkerMode",
        "--nonce=$Nonce",
        "--source_commit=$Head"
    )
    $environment = @{
        SPORESPORE_R24D7_SUPERVISED_TERMINATION = "1"
        SPORESPORE_R24D7_TERMINATION_NONCE = $Nonce
        SPORESPORE_R24D7_EXECUTION_NONCE = $Nonce
        SPORESPORE_R24D7_SOURCE_COMMIT = $Head
        APPDATA = (Join-Path $RunRoot "appdata")
        LOCALAPPDATA = (Join-Path $RunRoot "localappdata")
    }
    [void][IO.Directory]::CreateDirectory([string]$environment.APPDATA)
    [void][IO.Directory]::CreateDirectory([string]$environment.LOCALAPPDATA)
    $result = Invoke-SporeSporeGodotReceiptTerminatedProcess `
        -FileName $ConsolePath `
        -Arguments $arguments `
        -WorkingDirectory $ProjectRoot `
        -ReadyMarkerPrefix $readyPrefix `
        -ExpectedNonce $Nonce `
        -Environment $environment `
        -ScrubEnvironmentNames @(
            "SPORESPORE_R24D7_EXECUTION_NONCE",
            "SPORESPORE_R24D7_SOURCE_COMMIT"
        ) `
        -TimeoutSeconds 180
    $stdoutPath = Join-Path $RunRoot ("godot-$WorkerMode-stdout.log")
    $stderrPath = Join-Path $RunRoot ("godot-$WorkerMode-stderr.log")
    [IO.File]::WriteAllText(
        $stdoutPath,
        [string]$result.stdout,
        [Text.UTF8Encoding]::new($false)
    )
    [IO.File]::WriteAllText(
        $stderrPath,
        [string]$result.stderr,
        [Text.UTF8Encoding]::new($false)
    )
    Assert-R24D7Supervisor (
        [bool]$result.termination_protocol_valid -and
        [bool]$result.supervisor_terminated -and
        [int]$result.exit_code -eq 0
    ) (
        "worker_$WorkerMode`_failed:semantic=$($result.exit_code):" +
        "host=$($result.host_exit_code):protocol=" +
        "$($result.termination_protocol_failure_code)"
    )
    $stdoutLines = @(([string]$result.stdout) -split "`r?`n")
    $errorLines = @(
        $stdoutLines + @(([string]$result.stderr) -split "`r?`n") |
        Where-Object {
            $_ -match "(^|\s)(SCRIPT ERROR|ERROR):"
        }
    )
    Assert-R24D7Supervisor ($errorLines.Count -eq 0) (
        "worker_$WorkerMode`_error_lines:$($errorLines -join '|')"
    )
    return [ordered]@{
        result = $result
        stdout_lines = $stdoutLines
        stdout = Get-R24D7FileReceipt $stdoutPath
        stderr = Get-R24D7FileReceipt $stderrPath
        engine_log = Get-R24D7FileReceipt $engineLogPath
    }
}

function Publish-R24D7Artifact {
    param([Parameter(Mandatory)][string]$Path, [string]$MediaType = "application/json")
    return Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $repoRoot `
        -ArtifactPath $Path `
        -MediaType $MediaType
}

function Get-R24D7MatchingPhysicalAttempts {
    param(
        [Parameter(Mandatory)][string]$PhysicalRoot,
        [Parameter(Mandatory)][string]$SourceCommit,
        [Parameter(Mandatory)][string]$ConsoleSha256,
        [Parameter(Mandatory)][string]$EngineSha256
    )
    if (-not (Test-Path -LiteralPath $PhysicalRoot -PathType Container)) {
        return @()
    }
    $matches = [Collections.Generic.List[string]]::new()
    foreach ($attemptFile in @(
        Get-ChildItem `
            -LiteralPath $PhysicalRoot `
            -Filter "attempt.json" `
            -File `
            -Recurse `
            -ErrorAction Stop
    )) {
        try {
            $attempt = Get-Content -Raw -LiteralPath $attemptFile.FullName |
                ConvertFrom-Json -AsHashtable -Depth 100
        } catch {
            throw "retained_physical_attempt_unreadable:$($attemptFile.FullName)"
        }
        $expectedAttemptKeys = @(
            "schema_version",
            "gate_id",
            "question_class",
            "status",
            "source_commit",
            "execution_nonce",
            "console_binary_sha256",
            "engine_binary_sha256",
            "zero_world_receipt_sha256",
            "declared_world_attempt_count",
            "declared_world_build_count",
            "same_source_rerun_allowed",
            "physical_acceptance_authority",
            "release_authority"
        )
        Assert-R24D7Supervisor (
            @($attempt.Keys).Count -eq $expectedAttemptKeys.Count -and
            @(
                $expectedAttemptKeys |
                    Where-Object { -not $attempt.ContainsKey($_) }
            ).Count -eq 0 -and
            [string]$attempt.schema_version -ceq
                "sporespore_qsdk_r24d7_physical_attempt_v1" -and
            [string]$attempt.gate_id -ceq "QSDK-R24D7" -and
            [string]$attempt.question_class -ceq "development" -and
            [string]$attempt.status -ceq "consumed_before_worker_launch" -and
            -not [string]::IsNullOrWhiteSpace([string]$attempt.execution_nonce) -and
            [int]$attempt.declared_world_attempt_count -eq 1 -and
            [int]$attempt.declared_world_build_count -eq 1 -and
            -not [bool]$attempt.same_source_rerun_allowed -and
            -not [bool]$attempt.physical_acceptance_authority -and
            -not [bool]$attempt.release_authority
        ) "retained_physical_attempt_schema:$($attemptFile.FullName)"
        if (
            [string]$attempt.source_commit -ceq $SourceCommit -and
            [string]$attempt.console_binary_sha256 -ceq $ConsoleSha256 -and
            [string]$attempt.engine_binary_sha256 -ceq $EngineSha256
        ) {
            $matches.Add($attemptFile.FullName)
        }
    }
    return @($matches)
}

$operationLock = $null
$runRoot = ""
$physicalAttemptCreated = $false
try {
    $lockRole = if ($Mode -ceq "Physical") { "physical" } else { "conformance" }
    $operationLock = Enter-SporeSporeLocomotionOperationLock -Role $lockRole
    Assert-R24D7Supervisor ([bool]$operationLock.acquired) (
        "another_physical_or_conformance_workload_owns_the_lock"
    )

    $root = Get-R24D7GitValue @("rev-parse", "--show-toplevel")
    $remote = Get-R24D7GitValue @("remote", "get-url", "origin")
    $branch = Get-R24D7GitValue @("branch", "--show-current")
    $head = Get-R24D7GitValue @("rev-parse", "HEAD")
    $upstream = Get-R24D7GitValue @("rev-parse", "@{upstream}")
    $cached = Get-R24D7GitValue @("rev-parse", "refs/remotes/origin/main")
    $live = (Get-R24D7GitValue @(
        "ls-remote", "--heads", "origin", "refs/heads/main"
    )).Split("`t")[0]
    $status = Get-R24D7GitValue @("status", "--short")
    $worktreeText = Get-R24D7GitValue @("worktree", "list", "--porcelain")
    $worktrees = @($worktreeText -split "`r?`n" | Where-Object {
        $_.StartsWith("worktree ", [StringComparison]::Ordinal)
    })
    Assert-R24D7Supervisor ([IO.Path]::GetFullPath($root) -ceq $expectedRepoRoot) (
        "repository_root"
    )
    Assert-R24D7Supervisor ($repoRoot -ceq $expectedRepoRoot) "script_root"
    Assert-R24D7Supervisor ($remote -ceq $expectedRemote) "repository_remote"
    Assert-R24D7Supervisor ($branch -ceq "main") "branch"
    Assert-R24D7Supervisor ([string]::IsNullOrEmpty($status)) "dirty_worktree"
    Assert-R24D7Supervisor (
        $head -ceq $upstream -and $head -ceq $cached -and $head -ceq $live
    ) "local_upstream_cached_live_inequality"
    Assert-R24D7Supervisor ($worktrees.Count -eq 1) "worktree_count"
    if ($Mode -ceq "Physical") {
        Assert-R24D7Supervisor (
            $AuthorizationCommit -ceq $head
        ) "authorization_commit"
    }

    $manifestPath = Get-R24D7Path $manifestRelative
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D7ManifestAndBindings -Head $head -Manifest $manifest
    $manifestReceipt = Get-R24D7FileReceipt $manifestPath
    $integralSchemaPath = Get-R24D7Path $integralSchemaRelative
    $integralSchemaReceipt = Get-R24D7FileReceipt $integralSchemaPath
    $integralSchema = Get-Content -Raw -LiteralPath $integralSchemaPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D7Supervisor (
        [string]$integralSchema.schema_version -ceq
            "sporespore_qsdk_r24d7_integral_variant_schema_v1" -and
        [string]$integralSchema.schema_id -ceq
            "QSDK-R24D7-INTEGRAL-VARIANT-SCHEMA-V1" -and
        [int]$integralSchema.finite_counts.path_family_count -eq 21 -and
        [int]$integralSchema.finite_counts.concrete_occurrence_count -eq 313 -and
        [int]$integralSchema.finite_counts.predecessor_strict_occurrence_count -eq 234 -and
        [int]$integralSchema.finite_counts.r24d7_strict_occurrence_count -eq 313 -and
        [int]$integralSchema.finite_counts.family_type_loss_negative_control_count -eq 21 -and
        [int]$integralSchema.finite_counts.physical_world_count -eq 0
    ) "integral_variant_schema_identity"

    $adoption = Get-Content -Raw -LiteralPath (Get-R24D7Path $adoptionRelative) |
        ConvertFrom-Json -AsHashtable -Depth 100
    $consolePath = [IO.Path]::GetFullPath(
        [string]$adoption.retained_evidence.console_binary_path
    )
    $enginePath = [IO.Path]::GetFullPath(
        [string]$adoption.retained_evidence.engine_binary_path
    )
    $consoleReceipt = Get-R24D7FileReceipt $consolePath
    $engineReceipt = Get-R24D7FileReceipt $enginePath
    Assert-R24D7Supervisor (
        [string]$consoleReceipt.raw_sha256 -ceq "sha256:$expectedConsoleHash" -and
        [long]$consoleReceipt.byte_length -eq $expectedConsoleLength
    ) "console_binary_identity"
    Assert-R24D7Supervisor (
        [string]$engineReceipt.raw_sha256 -ceq "sha256:$expectedEngineHash" -and
        [long]$engineReceipt.byte_length -eq $expectedEngineLength
    ) "engine_binary_identity"
    Assert-R24D7Supervisor (
        (Split-Path -Parent $consolePath) -ceq (Split-Path -Parent $enginePath)
    ) "binary_pair_directory"

    $evidenceBase = [IO.Path]::GetFullPath($EvidenceRoot).TrimEnd("\", "/")
    $productionEvidence = [IO.Path]::GetFullPath(
        (Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repoRoot)
    ).TrimEnd("\", "/")
    Assert-R24D7Supervisor ($evidenceBase -ceq $productionEvidence) (
        "evidence_root"
    )
    $qualifiedZeroFile = $null
    $qualifiedZeroCas = $null
    if ($Mode -ceq "Physical") {
        Assert-R24D7Supervisor (
            -not [string]::IsNullOrWhiteSpace($ZeroWorldReceiptPath)
        ) "zero_world_receipt_required"
        $qualifiedZeroPath = [IO.Path]::GetFullPath($ZeroWorldReceiptPath)
        Assert-R24D7Supervisor (
            Test-Path -LiteralPath $qualifiedZeroPath -PathType Leaf
        ) "zero_world_receipt_missing"
        $qualifiedZeroRunRoot = [IO.Path]::GetFullPath(
            (Split-Path -Parent $qualifiedZeroPath)
        ).TrimEnd("\", "/")
        $expectedZeroRoot = [IO.Path]::GetFullPath(
            (Join-Path $evidenceBase "qsdk-r24d7-one-hinge-zero-world")
        ).TrimEnd("\", "/")
        Assert-R24D7Supervisor (
            (Split-Path -Leaf $qualifiedZeroPath) -ceq "receipt.json" -and
            $qualifiedZeroRunRoot.StartsWith(
                $expectedZeroRoot + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            )
        ) "zero_world_receipt_path"
        $qualifiedZero = Get-Content -Raw -LiteralPath $qualifiedZeroPath |
            ConvertFrom-Json -AsHashtable -Depth 100
        Assert-R24D7ExactKeys `
            -Value $qualifiedZero `
            -Expected @(
                "schema_version",
                "ok",
                "gate_id",
                "question_class",
                "result",
                "source",
                "runtime",
                "stages",
                "static_audit_stage_count",
                "worker",
                "serialized_envelope_oracle",
                "evaluator_baseline_negative_control_count",
                "integral_family_type_loss_negative_control_count",
                "evaluator_total_negative_control_count",
                "integral_path_family_count",
                "integral_occurrence_count",
                "predecessor_strict_integral_occurrence_count",
                "accepted_outcome_mutation_count",
                "contract_mutation_rejection_count",
                "binary32_projection_control_count",
                "default_precision_serialized_runtime_negative_control_count",
                "serialized_runtime_positive_control_count",
                "empirical_acceptance_threshold_count",
                "world_attempt_count",
                "world_build_count",
                "solver_step_count",
                "physical_characterization_executed",
                "instrumented_profile_promoted",
                "recovery_world_opened",
                "prone_to_standing_world_opened",
                "physical_acceptance_authority",
                "release_authority"
            ) `
            -Code "zero_world_receipt"
        $qualifiedSource = [hashtable]$qualifiedZero.source
        Assert-R24D7ExactKeys `
            -Value $qualifiedSource `
            -Expected @(
                "root",
                "remote",
                "branch",
                "head",
                "upstream",
                "cached_origin_main",
                "live_origin_main",
                "clean",
                "worktree_count",
                "validation_manifest",
                "source_binding_count"
            ) `
            -Code "zero_world_source"
        $qualifiedRuntime = [hashtable]$qualifiedZero.runtime
        Assert-R24D7ExactKeys `
            -Value $qualifiedRuntime `
            -Expected @("profile_id", "console", "engine", "retained_binary_count") `
            -Code "zero_world_runtime"
        Assert-R24D7ExactKeys `
            -Value ([hashtable]$qualifiedSource.validation_manifest) `
            -Expected @("path", "raw_sha256", "byte_length") `
            -Code "zero_world_validation_manifest"
        foreach ($binaryName in @("console", "engine")) {
            Assert-R24D7ExactKeys `
                -Value ([hashtable]$qualifiedRuntime[$binaryName]) `
                -Expected @("path", "raw_sha256", "byte_length") `
                -Code "zero_world_runtime_$binaryName"
        }
        Assert-R24D7Supervisor (
            [string]$qualifiedZero.schema_version -ceq
            "sporespore_qsdk_r24d7_one_hinge_telemetry_zero_world_qualification_receipt_v1" -and
            [bool]$qualifiedZero.ok -and
            [string]$qualifiedZero.gate_id -ceq "QSDK-R24D7" -and
            [string]$qualifiedZero.question_class -ceq
                "non_physical_source_conformance" -and
            [string]$qualifiedZero.result -ceq
                "complete_zero_world_serialized_envelope_gate_passed_physical_characterization_not_executed" -and
            [string]$qualifiedSource.root -ceq $root.Replace("\", "/") -and
            [string]$qualifiedSource.remote -ceq $expectedRemote -and
            [string]$qualifiedSource.branch -ceq "main" -and
            [string]$qualifiedSource.head -ceq $head -and
            [string]$qualifiedSource.upstream -ceq $head -and
            [string]$qualifiedSource.cached_origin_main -ceq $head -and
            [string]$qualifiedSource.live_origin_main -ceq $head -and
            [bool]$qualifiedSource.clean -and
            [int]$qualifiedSource.worktree_count -eq 1 -and
            [int]$qualifiedSource.source_binding_count -eq 11 -and
            [string]$qualifiedSource.validation_manifest.raw_sha256 -ceq
                [string]$manifestReceipt.raw_sha256 -and
            [long]$qualifiedSource.validation_manifest.byte_length -eq
                [long]$manifestReceipt.byte_length -and
            [string]$qualifiedSource.validation_manifest.path -ceq
                [string]$manifestReceipt.path -and
            [string]$qualifiedRuntime.profile_id -ceq
                "godot_4_7_jolt_sporespore_motor_telemetry_v1" -and
            [string]$qualifiedRuntime.console.raw_sha256 -ceq
                "sha256:$expectedConsoleHash" -and
            [long]$qualifiedRuntime.console.byte_length -eq
                $expectedConsoleLength -and
            [string]$qualifiedRuntime.console.path -ceq
                [string]$consoleReceipt.path -and
            [string]$qualifiedRuntime.engine.raw_sha256 -ceq
                "sha256:$expectedEngineHash" -and
            [long]$qualifiedRuntime.engine.byte_length -eq
                $expectedEngineLength -and
            [string]$qualifiedRuntime.engine.path -ceq
                [string]$engineReceipt.path -and
            [int]$qualifiedRuntime.retained_binary_count -eq 2 -and
            [int]$qualifiedZero.static_audit_stage_count -eq 5 -and
            [int]$qualifiedZero.evaluator_baseline_negative_control_count -eq 29 -and
            [int]$qualifiedZero.integral_family_type_loss_negative_control_count -eq 21 -and
            [int]$qualifiedZero.evaluator_total_negative_control_count -eq 50 -and
            [int]$qualifiedZero.integral_path_family_count -eq 21 -and
            [int]$qualifiedZero.integral_occurrence_count -eq 313 -and
            [int]$qualifiedZero.predecessor_strict_integral_occurrence_count -eq 234 -and
            [int]$qualifiedZero.accepted_outcome_mutation_count -eq 2 -and
            [int]$qualifiedZero.contract_mutation_rejection_count -eq 22 -and
            [int]$qualifiedZero.binary32_projection_control_count -eq 5 -and
            [int]$qualifiedZero.default_precision_serialized_runtime_negative_control_count -eq 1 -and
            [int]$qualifiedZero.serialized_runtime_positive_control_count -eq 1 -and
            [int]$qualifiedZero.empirical_acceptance_threshold_count -eq 0 -and
            [int]$qualifiedZero.world_attempt_count -eq 0 -and
            [int]$qualifiedZero.world_build_count -eq 0 -and
            [int]$qualifiedZero.solver_step_count -eq 0 -and
            -not [bool]$qualifiedZero.physical_characterization_executed -and
            -not [bool]$qualifiedZero.instrumented_profile_promoted -and
            -not [bool]$qualifiedZero.recovery_world_opened -and
            -not [bool]$qualifiedZero.prone_to_standing_world_opened -and
            -not [bool]$qualifiedZero.physical_acceptance_authority -and
            -not [bool]$qualifiedZero.release_authority
        ) "zero_world_receipt_identity"
        $expectedZeroStages = @(
            @{
                name = "r24d6_zero_world_failure_closure"
                marker = "QSDK_R24D6_ZERO_WORLD_FAILURE_CLOSURE_PASS "
            },
            @{
                name = "r24d7_freeze_audit"
                marker = "QSDK_R24D7_ONE_HINGE_TELEMETRY_FREEZE_PASS "
            },
            @{
                name = "r24d3_source_audit"
                marker = "QSDK_R24D3_GODOT_JOLT_MOTOR_TELEMETRY_SOURCE_PASS "
            },
            @{
                name = "r24d3_cold_adoption_audit"
                marker = "QSDK_R24D3_COLD_QUALIFICATION_ADOPTION_PASS "
            },
            @{
                name = "r24d3_post_adoption_full_cold_audit"
                marker = "QSDK_R24D3_POST_ADOPTION_FULL_COLD_CONFORMANCE_QUALIFICATION_PASS "
            }
        )
        $qualifiedStages = @($qualifiedZero.stages)
        Assert-R24D7Supervisor ($qualifiedStages.Count -eq 5) (
            "zero_world_stage_count"
        )
        for ($stageIndex = 0; $stageIndex -lt $expectedZeroStages.Count; $stageIndex++) {
            $stage = [hashtable]$qualifiedStages[$stageIndex]
            $expectedStage = [hashtable]$expectedZeroStages[$stageIndex]
            Assert-R24D7ExactKeys `
                -Value $stage `
                -Expected @("stage_index", "stage_name", "duration_s", "log", "cas") `
                -Code "zero_world_stage_$($stageIndex + 1)"
            Assert-R24D7Supervisor (
                [int]$stage.stage_index -eq ($stageIndex + 1) -and
                [string]$stage.stage_name -ceq [string]$expectedStage.name -and
                [double]::IsFinite([double]$stage.duration_s) -and
                [double]$stage.duration_s -ge 0.0
            ) "zero_world_stage_$($stageIndex + 1)_identity"
            Assert-R24D7RetainedFileAndCas `
                -FileReceipt ([hashtable]$stage.log) `
                -CasReceipt ([hashtable]$stage.cas) `
                -ExpectedRunRoot $qualifiedZeroRunRoot `
                -EvidenceBase $evidenceBase `
                -Code "zero_world_stage_$($stageIndex + 1)"
            $stageLines = @(
                Get-Content -LiteralPath ([string]$stage.log.path)
            )
            [void](Get-R24D7Marker `
                -Lines $stageLines `
                -Prefix ([string]$expectedStage.marker) `
                -Code "zero_world_stage_$($stageIndex + 1)_marker")
        }
        $qualifiedWorker = [hashtable]$qualifiedZero.worker
        Assert-R24D7ExactKeys `
            -Value $qualifiedWorker `
            -Expected @(
                "receipt",
                "stdout",
                "stderr",
                "engine_log",
                "stdout_cas",
                "stderr_cas",
                "engine_log_cas",
                "termination_protocol_valid",
                "supervisor_terminated_exact_process_tree"
            ) `
            -Code "zero_world_worker"
        foreach ($artifactName in @("stdout", "stderr", "engine_log")) {
            Assert-R24D7RetainedFileAndCas `
                -FileReceipt ([hashtable]$qualifiedWorker[$artifactName]) `
                -CasReceipt ([hashtable]$qualifiedWorker["${artifactName}_cas"]) `
                -ExpectedRunRoot $qualifiedZeroRunRoot `
                -EvidenceBase $evidenceBase `
                -Code "zero_world_worker_$artifactName"
        }
        $qualifiedWorkerReceipt = [hashtable]$qualifiedWorker.receipt
        Assert-R24D7ExactKeys `
            -Value $qualifiedWorkerReceipt `
            -Expected @(
                "ok",
                "schema_version",
                "fixture_id",
                "cell_count",
                "cell_ids_in_order",
                "engine",
                "telemetry_class_registered",
                "telemetry_method_registered",
                "invalid_rid_refused",
                "engine_freeze_matches",
                "fixture_description_matches",
                "fixture_description_gates",
                "source_commit",
                "execution_nonce",
                "zero_world_template_loaded",
                "zero_world_template_matches_declared_fixture",
                "integral_variant_schema_loaded",
                "integral_variant_schema",
                "serialized_envelope",
                "active_physics_object_count",
                "active_physics_object_count_is_zero",
                "telemetry_schema",
                "physical_characterization_executed",
                "world_attempt_count",
                "world_build_count",
                "solver_step_count",
                "physical_acceptance_authority",
                "release_authority"
            ) `
            -Code "zero_world_worker_receipt"
        $qualifiedWorkerEngine = [hashtable]$qualifiedWorkerReceipt.engine
        $qualifiedWorkerFixtureGates = [hashtable](
            $qualifiedWorkerReceipt.fixture_description_gates
        )
        $qualifiedWorkerEnvelope = [hashtable](
            $qualifiedWorkerReceipt.serialized_envelope
        )
        $qualifiedWorkerIntegral = [hashtable](
            $qualifiedWorkerReceipt.integral_variant_schema
        )
        Assert-R24D7IntegralNormalizationReceipt `
            -Value $qualifiedWorkerIntegral `
            -SchemaReceipt $integralSchemaReceipt `
            -Code "qualified_zero_world_integral_variant_schema"
        $qualifiedWorkerRealT = [hashtable](
            $qualifiedWorkerEnvelope.real_t_projection_receipt
        )
        Assert-R24D7ExactKeys `
            -Value $qualifiedWorkerEnvelope `
            -Expected @(
                "serializer_call_count",
                "default_precision_sort_keys",
                "default_precision_full_precision",
                "full_precision_sort_keys",
                "full_precision_full_precision",
                "envelopes_nonempty_and_distinct",
                "default_precision_raw_sha256",
                "default_precision_byte_length",
                "full_precision_raw_sha256",
                "full_precision_byte_length",
                "synthetic_embedded_declared_world_attempt_count",
                "synthetic_embedded_declared_world_build_count",
                "synthetic_embedded_declared_physics_step_count",
                "synthetic_embedded_declared_retained_sample_count",
                "synthetic_envelope_is_physical_observation",
                "real_t_projection_receipt"
            ) `
            -Code "zero_world_worker_serialized_envelope"
        Assert-R24D7ExactKeys `
            -Value $qualifiedWorkerRealT `
            -Expected @(
                "child_inertia_component_kg_m2",
                "maximum_impulse_0_002_nms",
                "maximum_impulse_0_01_nms",
                "lower_limit_negative_0_02_rad",
                "upper_limit_positive_0_02_rad"
            ) `
            -Code "zero_world_worker_real_t_projection"
        Assert-R24D7ExactKeys `
            -Value $qualifiedWorkerEngine `
            -Expected @(
                "physics_engine",
                "physics_ticks_per_second",
                "solver_velocity_steps",
                "solver_position_steps",
                "thread_model",
                "telemetry_class_registered",
                "telemetry_method_registered"
            ) `
            -Code "zero_world_worker_engine"
        Assert-R24D7ExactKeys `
            -Value $qualifiedWorkerFixtureGates `
            -Expected @(
                "fixture_id_matches",
                "cell_count_matches",
                "cell_ids_match",
                "child_mass_matches",
                "child_inertia_matches",
                "hinge_axis_matches",
                "maximum_physics_step_count_matches",
                "world_attempt_count_is_zero",
                "world_build_count_is_zero",
                "solver_step_count_is_zero"
            ) `
            -Code "zero_world_worker_fixture_gates"
        Assert-R24D7Supervisor (
            [bool]$qualifiedWorker.termination_protocol_valid -and
            [bool]$qualifiedWorker.supervisor_terminated_exact_process_tree -and
            [bool]$qualifiedWorkerReceipt.ok -and
            [string]$qualifiedWorkerReceipt.schema_version -ceq
                "sporespore_qsdk_r24d7_godot_jolt_one_hinge_worker_preflight_v1" -and
            [string]$qualifiedWorkerReceipt.fixture_id -ceq
                "QSDK.R24D7.godot_jolt_one_hinge_telemetry.v1" -and
            [int]$qualifiedWorkerReceipt.cell_count -eq 9 -and
            (@($qualifiedWorkerReceipt.cell_ids_in_order) -join "|") -ceq
                "drive_positive|drive_negative|brake_positive|brake_negative|disabled_positive|disabled_negative|limit_positive|limit_negative|sleep_stale" -and
            [bool]$qualifiedWorkerReceipt.telemetry_class_registered -and
            [bool]$qualifiedWorkerReceipt.telemetry_method_registered -and
            [bool]$qualifiedWorkerReceipt.invalid_rid_refused -and
            [bool]$qualifiedWorkerReceipt.engine_freeze_matches -and
            [bool]$qualifiedWorkerReceipt.fixture_description_matches -and
            [string]$qualifiedWorkerReceipt.source_commit -ceq $head -and
            ([string]$qualifiedWorkerReceipt.execution_nonce).Length -eq 32 -and
            [bool]$qualifiedWorkerReceipt.zero_world_template_loaded -and
            [bool]$qualifiedWorkerReceipt.zero_world_template_matches_declared_fixture -and
            [bool]$qualifiedWorkerReceipt.integral_variant_schema_loaded -and
            @(
                $qualifiedWorkerFixtureGates.Values |
                    Where-Object { -not [bool]$_ }
            ).Count -eq 0 -and
            [double]::IsFinite(
                [double]$qualifiedWorkerReceipt.active_physics_object_count
            ) -and
            [double]$qualifiedWorkerReceipt.active_physics_object_count -eq 0.0 -and
            [bool]$qualifiedWorkerReceipt.active_physics_object_count_is_zero -and
            [string]$qualifiedWorkerReceipt.telemetry_schema -ceq
                "sporespore.godot_jolt_hinge_motor_telemetry.v1" -and
            [string]$qualifiedWorkerEngine.physics_engine -ceq "Jolt Physics" -and
            [int]$qualifiedWorkerEngine.physics_ticks_per_second -eq 120 -and
            [int]$qualifiedWorkerEngine.solver_velocity_steps -eq 20 -and
            [int]$qualifiedWorkerEngine.solver_position_steps -eq 7 -and
            [string]$qualifiedWorkerEngine.thread_model -ceq "single_safe" -and
            [bool]$qualifiedWorkerEngine.telemetry_class_registered -and
            [bool]$qualifiedWorkerEngine.telemetry_method_registered -and
            [int]$qualifiedWorkerEnvelope.serializer_call_count -eq 2 -and
            [bool]$qualifiedWorkerEnvelope.default_precision_sort_keys -and
            -not [bool]$qualifiedWorkerEnvelope.default_precision_full_precision -and
            [bool]$qualifiedWorkerEnvelope.full_precision_sort_keys -and
            [bool]$qualifiedWorkerEnvelope.full_precision_full_precision -and
            [bool]$qualifiedWorkerEnvelope.envelopes_nonempty_and_distinct -and
            [int]$qualifiedWorkerEnvelope.synthetic_embedded_declared_world_attempt_count -eq 1 -and
            [int]$qualifiedWorkerEnvelope.synthetic_embedded_declared_world_build_count -eq 1 -and
            [int]$qualifiedWorkerEnvelope.synthetic_embedded_declared_physics_step_count -eq 20 -and
            [int]$qualifiedWorkerEnvelope.synthetic_embedded_declared_retained_sample_count -eq 68 -and
            -not [bool]$qualifiedWorkerEnvelope.synthetic_envelope_is_physical_observation -and
            [double]$qualifiedWorkerRealT.child_inertia_component_kg_m2 -eq
                [double]0.05000000074505806 -and
            [double]$qualifiedWorkerRealT.maximum_impulse_0_002_nms -eq
                [double]0.0020000000949949026 -and
            [double]$qualifiedWorkerRealT.maximum_impulse_0_01_nms -eq
                [double]0.009999999776482582 -and
            [double]$qualifiedWorkerRealT.lower_limit_negative_0_02_rad -eq
                [double]-0.019999999552965164 -and
            [double]$qualifiedWorkerRealT.upper_limit_positive_0_02_rad -eq
                [double]0.019999999552965164 -and
            -not [bool]$qualifiedWorkerReceipt.physical_characterization_executed -and
            [int]$qualifiedWorkerReceipt.world_attempt_count -eq 0 -and
            [int]$qualifiedWorkerReceipt.world_build_count -eq 0 -and
            [int]$qualifiedWorkerReceipt.solver_step_count -eq 0 -and
            -not [bool]$qualifiedWorkerReceipt.physical_acceptance_authority -and
            -not [bool]$qualifiedWorkerReceipt.release_authority
        ) "zero_world_worker_receipt_identity"
        $qualifiedWorkerStdoutLines = @(
            Get-Content -LiteralPath ([string]$qualifiedWorker.stdout.path)
        )
        $qualifiedWorkerMarker = Get-R24D7Marker `
            -Lines $qualifiedWorkerStdoutLines `
            -Prefix $workerZeroPrefix `
            -Code "zero_world_retained_worker"
        $qualifiedWorkerFromLog = $qualifiedWorkerMarker |
            ConvertFrom-Json -AsHashtable -Depth 100
        Assert-R24D7Supervisor (
            ($qualifiedWorkerFromLog | ConvertTo-Json -Depth 100 -Compress) -ceq
            ($qualifiedWorkerReceipt | ConvertTo-Json -Depth 100 -Compress)
        ) "zero_world_worker_receipt_log_binding"

        $qualifiedOracle = [hashtable]$qualifiedZero.serialized_envelope_oracle
        Assert-R24D7ExactKeys `
            -Value $qualifiedOracle `
            -Expected @(
                "template",
                "integral_variant_normalization",
                "integral_family_type_loss_negative_control_count",
                "default_precision_negative_control",
                "full_precision_positive_control",
                "default_precision_serialized_runtime_negative_control_count",
                "serialized_runtime_positive_control_count",
                "actual_world_attempt_count",
                "actual_world_build_count",
                "actual_solver_step_count",
                "physical_characterization_executed",
                "physical_acceptance_authority",
                "release_authority"
            ) `
            -Code "zero_world_serialized_oracle"
        $qualifiedTemplate = [hashtable]$qualifiedOracle.template
        $qualifiedDefault = [hashtable](
            $qualifiedOracle.default_precision_negative_control
        )
        $qualifiedFull = [hashtable](
            $qualifiedOracle.full_precision_positive_control
        )
        Assert-R24D7ExactKeys `
            -Value $qualifiedTemplate `
            -Expected @("receipt", "file", "cas", "log", "log_cas") `
            -Code "zero_world_template"
        Assert-R24D7ExactKeys `
            -Value $qualifiedDefault `
            -Expected @(
                "envelope",
                "envelope_cas",
                "evaluator_exit_code",
                "evaluator_terminal_error",
                "evaluation_record_written",
                "log",
                "log_cas"
            ) `
            -Code "zero_world_default_control"
        Assert-R24D7ExactKeys `
            -Value $qualifiedFull `
            -Expected @(
                "envelope",
                "envelope_cas",
                "evaluation",
                "evaluation_cas",
                "evaluation_receipt",
                "log",
                "log_cas"
            ) `
            -Code "zero_world_full_control"
        Assert-R24D7RetainedFileAndCas `
            -FileReceipt ([hashtable]$qualifiedTemplate.file) `
            -CasReceipt ([hashtable]$qualifiedTemplate.cas) `
            -ExpectedRunRoot $qualifiedZeroRunRoot `
            -EvidenceBase $evidenceBase `
            -Code "zero_world_template_file"
        Assert-R24D7RetainedFileAndCas `
            -FileReceipt ([hashtable]$qualifiedTemplate.log) `
            -CasReceipt ([hashtable]$qualifiedTemplate.log_cas) `
            -ExpectedRunRoot $qualifiedZeroRunRoot `
            -EvidenceBase $evidenceBase `
            -Code "zero_world_template_log"
        Assert-R24D7RetainedFileAndCas `
            -FileReceipt ([hashtable]$qualifiedDefault.envelope) `
            -CasReceipt ([hashtable]$qualifiedDefault.envelope_cas) `
            -ExpectedRunRoot $qualifiedZeroRunRoot `
            -EvidenceBase $evidenceBase `
            -Code "zero_world_default_envelope"
        Assert-R24D7RetainedFileAndCas `
            -FileReceipt ([hashtable]$qualifiedDefault.log) `
            -CasReceipt ([hashtable]$qualifiedDefault.log_cas) `
            -ExpectedRunRoot $qualifiedZeroRunRoot `
            -EvidenceBase $evidenceBase `
            -Code "zero_world_default_log"
        foreach ($fullArtifact in @(
            @{ file = "envelope"; cas = "envelope_cas"; code = "envelope" },
            @{ file = "evaluation"; cas = "evaluation_cas"; code = "evaluation" },
            @{ file = "log"; cas = "log_cas"; code = "log" }
        )) {
            Assert-R24D7RetainedFileAndCas `
                -FileReceipt ([hashtable]$qualifiedFull[$fullArtifact.file]) `
                -CasReceipt ([hashtable]$qualifiedFull[$fullArtifact.cas]) `
                -ExpectedRunRoot $qualifiedZeroRunRoot `
                -EvidenceBase $evidenceBase `
                -Code "zero_world_full_$($fullArtifact.code)"
        }
        $qualifiedTemplateReceipt = [hashtable]$qualifiedTemplate.receipt
        $qualifiedFullEvaluation = [hashtable]$qualifiedFull.evaluation_receipt
        Assert-R24D7Supervisor (
            [bool]$qualifiedTemplateReceipt.ok -and
            [string]$qualifiedTemplateReceipt.source_commit -ceq $head -and
            [string]$qualifiedTemplateReceipt.execution_nonce -ceq
                [string]$qualifiedWorkerReceipt.execution_nonce -and
            [int]$qualifiedTemplateReceipt.synthetic_cell_count -eq 9 -and
            [int]$qualifiedTemplateReceipt.synthetic_sample_count -eq 68 -and
            [string]$qualifiedWorkerEnvelope.default_precision_raw_sha256 -ceq
                [string]$qualifiedDefault.envelope.raw_sha256 -and
            [long]$qualifiedWorkerEnvelope.default_precision_byte_length -eq
                [long]$qualifiedDefault.envelope.byte_length -and
            [string]$qualifiedWorkerEnvelope.full_precision_raw_sha256 -ceq
                [string]$qualifiedFull.envelope.raw_sha256 -and
            [long]$qualifiedWorkerEnvelope.full_precision_byte_length -eq
                [long]$qualifiedFull.envelope.byte_length -and
            [int]$qualifiedDefault.evaluator_exit_code -eq 2 -and
            [string]$qualifiedDefault.evaluator_terminal_error -ceq
                "QSDK_R24D7_EVALUATION_ERROR fixture_inertia_representation" -and
            -not [bool]$qualifiedDefault.evaluation_record_written -and
            [string]$qualifiedFullEvaluation.schema_version -ceq
                "sporespore_qsdk_r24d7_serialized_envelope_zero_world_evaluation_v1" -and
            [string]$qualifiedFullEvaluation.result_class -ceq
                "complete_valid_synthetic_serialized_envelope_conformance" -and
            [bool]$qualifiedFullEvaluation.execution_valid -and
            -not [bool]$qualifiedFullEvaluation.native_measurements_observed -and
            -not [bool]$qualifiedFullEvaluation.physical_characterization_executed -and
            [int]$qualifiedOracle.integral_family_type_loss_negative_control_count -eq 21 -and
            ([hashtable]$qualifiedOracle.integral_variant_normalization |
                ConvertTo-Json -Depth 100 -Compress) -ceq
                ($qualifiedWorkerIntegral | ConvertTo-Json -Depth 100 -Compress) -and
            [int]$qualifiedOracle.default_precision_serialized_runtime_negative_control_count -eq 1 -and
            [int]$qualifiedOracle.serialized_runtime_positive_control_count -eq 1 -and
            [int]$qualifiedOracle.actual_world_attempt_count -eq 0 -and
            [int]$qualifiedOracle.actual_world_build_count -eq 0 -and
            [int]$qualifiedOracle.actual_solver_step_count -eq 0 -and
            -not [bool]$qualifiedOracle.physical_characterization_executed -and
            -not [bool]$qualifiedOracle.physical_acceptance_authority -and
            -not [bool]$qualifiedOracle.release_authority
        ) "zero_world_serialized_oracle_identity"
        $qualifiedDefaultMarker = Get-R24D7Marker `
            -Lines $qualifiedWorkerStdoutLines `
            -Prefix $workerDefaultEnvelopePrefix `
            -Code "zero_world_retained_default_envelope"
        $qualifiedFullMarker = Get-R24D7Marker `
            -Lines $qualifiedWorkerStdoutLines `
            -Prefix $workerFullEnvelopePrefix `
            -Code "zero_world_retained_full_envelope"
        Assert-R24D7Supervisor (
            [IO.File]::ReadAllText([string]$qualifiedDefault.envelope.path) -ceq
                $qualifiedDefaultMarker -and
            [IO.File]::ReadAllText([string]$qualifiedFull.envelope.path) -ceq
                $qualifiedFullMarker
        ) "zero_world_serialized_envelope_log_binding"
        $qualifiedZeroFile = Get-R24D7FileReceipt $qualifiedZeroPath
        $qualifiedZeroCas = Publish-R24D7Artifact -Path $qualifiedZeroPath
        Assert-R24D7Supervisor (
            Test-SporeSporeStoredArtifact `
                -Directory (Split-Path -Parent ([string]$qualifiedZeroCas.payload_path)) `
                -ExpectedSha256 ([string]$qualifiedZeroFile.raw_sha256).Substring(7) `
                -ExpectedByteLength ([long]$qualifiedZeroFile.byte_length)
        ) "zero_world_receipt_cas"
    }
    $manifestHashShort = ([string]$manifestReceipt.raw_sha256).Substring(7, 12)
    if ($Mode -ceq "Physical") {
        $physicalRoot = Join-Path $evidenceBase (
            "qsdk-r24d7-one-hinge-physical"
        )
        $matchingAttempts = @(Get-R24D7MatchingPhysicalAttempts `
            -PhysicalRoot $physicalRoot `
            -SourceCommit $head `
            -ConsoleSha256 "sha256:$expectedConsoleHash" `
            -EngineSha256 "sha256:$expectedEngineHash")
        Assert-R24D7Supervisor ($matchingAttempts.Count -eq 0) (
            "same_source_physical_attempt_already_exists:" +
            ($matchingAttempts -join "|")
        )
        $physicalRunId = (
            $head + "-" + $expectedConsoleHash.Substring(0, 12) + "-" +
            $expectedEngineHash.Substring(0, 12) + "-" +
            [DateTimeOffset]::UtcNow.ToString("yyyyMMddTHHmmssfffZ") + "-" +
            $manifestHashShort
        )
        $runRoot = Join-Path $physicalRoot $physicalRunId
        Assert-R24D7Supervisor (-not (Test-Path -LiteralPath $runRoot)) (
            "physical_run_path_exists:$runRoot"
        )
    } else {
        $runId = (
            [DateTimeOffset]::UtcNow.ToString("yyyyMMddTHHmmssZ") + "-" +
            $head.Substring(0, 8) + "-" + $manifestHashShort
        )
        $runRoot = Join-Path $evidenceBase (
            "qsdk-r24d7-one-hinge-zero-world\" + $runId
        )
        Assert-R24D7Supervisor (-not (Test-Path -LiteralPath $runRoot)) (
            "zero_world_run_path_exists:$runRoot"
        )
    }
    [void][IO.Directory]::CreateDirectory($runRoot)

    $pythonPath = Resolve-R24D7Application $Python
    $pwshPath = Resolve-R24D7Application "pwsh"
    $stageReceipts = [Collections.Generic.List[object]]::new()
    $stageDefinitions = @(
        @{
            name = "r24d6_zero_world_failure_closure"
            file = $pwshPath
            arguments = @(
                "-NoLogo", "-NoProfile", "-File",
                (Get-R24D7Path $predecessorClosureAuditRelative)
            )
            marker = "QSDK_R24D6_ZERO_WORLD_FAILURE_CLOSURE_PASS "
        },
        @{
            name = "r24d7_freeze_audit"
            file = $pwshPath
            arguments = @(
                "-NoLogo", "-NoProfile", "-File",
                (Get-R24D7Path $freezeAuditRelative), "-Python", $pythonPath
            )
            marker = "QSDK_R24D7_ONE_HINGE_TELEMETRY_FREEZE_PASS "
        },
        @{
            name = "r24d3_source_audit"
            file = $pwshPath
            arguments = @(
                "-NoLogo", "-NoProfile", "-File",
                (Get-R24D7Path $sourceAuditRelative)
            )
            marker = "QSDK_R24D3_GODOT_JOLT_MOTOR_TELEMETRY_SOURCE_PASS "
        },
        @{
            name = "r24d3_cold_adoption_audit"
            file = $pwshPath
            arguments = @(
                "-NoLogo", "-NoProfile", "-File",
                (Get-R24D7Path $adoptionAuditRelative)
            )
            marker = "QSDK_R24D3_COLD_QUALIFICATION_ADOPTION_PASS "
        },
        @{
            name = "r24d3_post_adoption_full_cold_audit"
            file = $pwshPath
            arguments = @(
                "-NoLogo", "-NoProfile", "-File",
                (Get-R24D7Path $fullColdAuditRelative)
            )
            marker = "QSDK_R24D3_POST_ADOPTION_FULL_COLD_CONFORMANCE_QUALIFICATION_PASS "
        }
    )
    $stageIndex = 0
    foreach ($stage in $stageDefinitions) {
        $stageIndex += 1
        $logPath = Join-Path $runRoot (
            "{0:D2}-{1}.log" -f $stageIndex, [string]$stage.name
        )
        $stageResult = Invoke-R24D7Checked `
            -FileName ([string]$stage.file) `
            -Arguments @($stage.arguments) `
            -Label ([string]$stage.name) `
            -LogPath $logPath
        [void](Get-R24D7Marker `
            -Lines $stageResult.output `
            -Prefix ([string]$stage.marker) `
            -Code ([string]$stage.name))
        $stageCas = Publish-R24D7Artifact -Path $logPath -MediaType "text/plain"
        $stageReceipts.Add([ordered]@{
            stage_index = $stageIndex
            stage_name = [string]$stage.name
            duration_s = [double]$stageResult.duration_s
            log = $stageResult.log
            cas = $stageCas
        })
    }

    $projectRoot = Join-Path $runRoot "project"
    [void][IO.Directory]::CreateDirectory($projectRoot)
    New-R24D7Project -ProjectRoot $projectRoot
    $zeroNonce = [guid]::NewGuid().ToString("N")
    $templatePath = Join-Path $projectRoot "zero_world_template.json"
    $templateLogPath = Join-Path $runRoot "06-zero-world-template.log"
    $templateRun = Invoke-R24D7Checked `
        -FileName $pythonPath `
        -Arguments @(
            (Get-R24D7Path $evaluatorRelative),
            "--integral-variant-schema", $integralSchemaPath,
            "--emit-zero-world-template",
            "--output", $templatePath,
            "--source-commit", $head,
            "--execution-nonce", $zeroNonce
        ) `
        -Label "r24d7_zero_world_template" `
        -LogPath $templateLogPath
    $templateMarker = Get-R24D7Marker `
        -Lines $templateRun.output `
        -Prefix $templatePrefix `
        -Code "zero_world_template"
    $templateReceipt = $templateMarker |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D7Supervisor (
        [bool]$templateReceipt.ok -and
        [string]$templateReceipt.source_commit -ceq $head -and
        [string]$templateReceipt.execution_nonce -ceq $zeroNonce -and
        [int]$templateReceipt.synthetic_cell_count -eq 9 -and
        [int]$templateReceipt.synthetic_sample_count -eq 68 -and
        [int]$templateReceipt.actual_world_attempt_count -eq 0 -and
        [int]$templateReceipt.actual_world_build_count -eq 0 -and
        [int]$templateReceipt.actual_solver_step_count -eq 0 -and
        -not [bool]$templateReceipt.physical_acceptance_authority -and
        -not [bool]$templateReceipt.release_authority
    ) "zero_world_template_receipt"
    $templateFile = Get-R24D7FileReceipt $templatePath
    $templateCas = Publish-R24D7Artifact -Path $templatePath
    $templateLogCas = Publish-R24D7Artifact `
        -Path $templateLogPath `
        -MediaType "text/plain"

    $zeroWorker = Invoke-R24D7Worker `
        -ConsolePath $consolePath `
        -ProjectRoot $projectRoot `
        -RunRoot $runRoot `
        -WorkerMode "zero_world_preflight" `
        -Nonce $zeroNonce `
        -Head $head
    $zeroReceiptJson = Get-R24D7Marker `
        -Lines $zeroWorker.stdout_lines `
        -Prefix $workerZeroPrefix `
        -Code "zero_world_worker"
    $zeroReceipt = $zeroReceiptJson |
        ConvertFrom-Json -AsHashtable -Depth 100
    $defaultEnvelopeJson = Get-R24D7Marker `
        -Lines $zeroWorker.stdout_lines `
        -Prefix $workerDefaultEnvelopePrefix `
        -Code "zero_world_default_precision_envelope"
    $fullEnvelopeJson = Get-R24D7Marker `
        -Lines $zeroWorker.stdout_lines `
        -Prefix $workerFullEnvelopePrefix `
        -Code "zero_world_full_precision_envelope"
    $defaultEnvelopePath = Join-Path $runRoot (
        "zero-world-default-precision-envelope.json"
    )
    $fullEnvelopePath = Join-Path $runRoot (
        "zero-world-full-precision-envelope.json"
    )
    [IO.File]::WriteAllText(
        $defaultEnvelopePath,
        $defaultEnvelopeJson,
        [Text.UTF8Encoding]::new($false)
    )
    [IO.File]::WriteAllText(
        $fullEnvelopePath,
        $fullEnvelopeJson,
        [Text.UTF8Encoding]::new($false)
    )
    $defaultEnvelopeFile = Get-R24D7FileReceipt $defaultEnvelopePath
    $fullEnvelopeFile = Get-R24D7FileReceipt $fullEnvelopePath
    $defaultEnvelopeCas = Publish-R24D7Artifact -Path $defaultEnvelopePath
    $fullEnvelopeCas = Publish-R24D7Artifact -Path $fullEnvelopePath
    $zeroFixtureGates = [hashtable]$zeroReceipt.fixture_description_gates
    $zeroSerializedEnvelope = [hashtable]$zeroReceipt.serialized_envelope
    $zeroRealT = [hashtable]$zeroSerializedEnvelope.real_t_projection_receipt
    $zeroIntegral = [hashtable]$zeroReceipt.integral_variant_schema
    Assert-R24D7IntegralNormalizationReceipt `
        -Value $zeroIntegral `
        -SchemaReceipt $integralSchemaReceipt `
        -Code "zero_world_integral_variant_schema"
    Assert-R24D7Supervisor (
        [bool]$zeroReceipt.ok -and
        [int]$zeroReceipt.cell_count -eq 9 -and
        [bool]$zeroReceipt.invalid_rid_refused -and
        [bool]$zeroReceipt.engine_freeze_matches -and
        [bool]$zeroReceipt.fixture_description_matches -and
        [string]$zeroReceipt.source_commit -ceq $head -and
        [string]$zeroReceipt.execution_nonce -ceq $zeroNonce -and
        [bool]$zeroReceipt.zero_world_template_loaded -and
        [bool]$zeroReceipt.zero_world_template_matches_declared_fixture -and
        [bool]$zeroReceipt.integral_variant_schema_loaded -and
        @(
            $zeroFixtureGates.Values |
                Where-Object { -not [bool]$_ }
        ).Count -eq 0 -and
        [double]::IsFinite([double]$zeroReceipt.active_physics_object_count) -and
        [double]$zeroReceipt.active_physics_object_count -eq 0.0 -and
        [bool]$zeroReceipt.active_physics_object_count_is_zero -and
        [string]$zeroReceipt.engine.physics_engine -ceq "Jolt Physics" -and
        [int]$zeroReceipt.engine.physics_ticks_per_second -eq 120 -and
        [int]$zeroReceipt.engine.solver_velocity_steps -eq 20 -and
        [int]$zeroReceipt.engine.solver_position_steps -eq 7 -and
        [string]$zeroReceipt.engine.thread_model -ceq "single_safe" -and
        [bool]$zeroReceipt.engine.telemetry_class_registered -and
        [bool]$zeroReceipt.engine.telemetry_method_registered -and
        [int]$zeroSerializedEnvelope.serializer_call_count -eq 2 -and
        [bool]$zeroSerializedEnvelope.default_precision_sort_keys -and
        -not [bool]$zeroSerializedEnvelope.default_precision_full_precision -and
        [bool]$zeroSerializedEnvelope.full_precision_sort_keys -and
        [bool]$zeroSerializedEnvelope.full_precision_full_precision -and
        [bool]$zeroSerializedEnvelope.envelopes_nonempty_and_distinct -and
        [string]$zeroSerializedEnvelope.default_precision_raw_sha256 -ceq
            [string]$defaultEnvelopeFile.raw_sha256 -and
        [long]$zeroSerializedEnvelope.default_precision_byte_length -eq
            [long]$defaultEnvelopeFile.byte_length -and
        [string]$zeroSerializedEnvelope.full_precision_raw_sha256 -ceq
            [string]$fullEnvelopeFile.raw_sha256 -and
        [long]$zeroSerializedEnvelope.full_precision_byte_length -eq
            [long]$fullEnvelopeFile.byte_length -and
        [int]$zeroSerializedEnvelope.synthetic_embedded_declared_world_attempt_count -eq 1 -and
        [int]$zeroSerializedEnvelope.synthetic_embedded_declared_world_build_count -eq 1 -and
        [int]$zeroSerializedEnvelope.synthetic_embedded_declared_physics_step_count -eq 20 -and
        [int]$zeroSerializedEnvelope.synthetic_embedded_declared_retained_sample_count -eq 68 -and
        -not [bool]$zeroSerializedEnvelope.synthetic_envelope_is_physical_observation -and
        [double]$zeroRealT.child_inertia_component_kg_m2 -eq
            [double]0.05000000074505806 -and
        [double]$zeroRealT.maximum_impulse_0_002_nms -eq
            [double]0.0020000000949949026 -and
        [double]$zeroRealT.maximum_impulse_0_01_nms -eq
            [double]0.009999999776482582 -and
        [double]$zeroRealT.lower_limit_negative_0_02_rad -eq
            [double]-0.019999999552965164 -and
        [double]$zeroRealT.upper_limit_positive_0_02_rad -eq
            [double]0.019999999552965164 -and
        -not [bool]$zeroReceipt.physical_characterization_executed -and
        [int]$zeroReceipt.world_attempt_count -eq 0 -and
        [int]$zeroReceipt.world_build_count -eq 0 -and
        [int]$zeroReceipt.solver_step_count -eq 0 -and
        -not [bool]$zeroReceipt.physical_acceptance_authority -and
        -not [bool]$zeroReceipt.release_authority
    ) "zero_world_worker_receipt"

    $defaultEvaluationPath = Join-Path $runRoot (
        "zero-world-default-precision-evaluation-must-not-exist.json"
    )
    $defaultEvaluationLogPath = Join-Path $runRoot (
        "07-default-precision-negative-control.log"
    )
    $defaultEvaluation = Invoke-R24D7ExpectedFailure `
        -FileName $pythonPath `
        -Arguments @(
            (Get-R24D7Path $evaluatorRelative),
            "--integral-variant-schema", $integralSchemaPath,
            "--zero-world-envelope",
            "--input", $defaultEnvelopePath,
            "--output", $defaultEvaluationPath
        ) `
        -Label "r24d7_default_precision_negative_control" `
        -LogPath $defaultEvaluationLogPath `
        -ExpectedExitCode 2 `
        -ExpectedMarker (
            "QSDK_R24D7_EVALUATION_ERROR fixture_inertia_representation"
        )
    Assert-R24D7Supervisor (
        -not (Test-Path -LiteralPath $defaultEvaluationPath)
    ) "default_precision_negative_wrote_evaluation"
    $defaultEvaluationLogCas = Publish-R24D7Artifact `
        -Path $defaultEvaluationLogPath `
        -MediaType "text/plain"

    $fullEvaluationPath = Join-Path $runRoot (
        "zero-world-full-precision-evaluation.json"
    )
    $fullEvaluationLogPath = Join-Path $runRoot (
        "08-full-precision-evaluator.log"
    )
    $fullEvaluationRun = Invoke-R24D7Checked `
        -FileName $pythonPath `
        -Arguments @(
            (Get-R24D7Path $evaluatorRelative),
            "--integral-variant-schema", $integralSchemaPath,
            "--zero-world-envelope",
            "--input", $fullEnvelopePath,
            "--output", $fullEvaluationPath
        ) `
        -Label "r24d7_full_precision_serialized_envelope" `
        -LogPath $fullEvaluationLogPath
    [void](Get-R24D7Marker `
        -Lines $fullEvaluationRun.output `
        -Prefix $zeroEvaluationPrefix `
        -Code "full_precision_zero_world_evaluation")
    $fullEvaluationReceipt = Get-Content -Raw -LiteralPath $fullEvaluationPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D7Supervisor (
        [string]$fullEvaluationReceipt.schema_version -ceq
            "sporespore_qsdk_r24d7_serialized_envelope_zero_world_evaluation_v1" -and
        [string]$fullEvaluationReceipt.gate_id -ceq "QSDK-R24D7" -and
        [string]$fullEvaluationReceipt.question_class -ceq
            "non_physical_source_conformance" -and
        [string]$fullEvaluationReceipt.result_class -ceq
            "complete_valid_synthetic_serialized_envelope_conformance" -and
        [bool]$fullEvaluationReceipt.execution_valid -and
        [int]$fullEvaluationReceipt.synthetic_embedded_declared_shape.world_attempt_count -eq 1 -and
        [int]$fullEvaluationReceipt.synthetic_embedded_declared_shape.world_build_count -eq 1 -and
        [int]$fullEvaluationReceipt.synthetic_embedded_declared_shape.physics_step_count -eq 20 -and
        [int]$fullEvaluationReceipt.synthetic_embedded_declared_shape.retained_sample_count -eq 68 -and
        [int]$fullEvaluationReceipt.actual_execution.world_attempt_count -eq 0 -and
        [int]$fullEvaluationReceipt.actual_execution.world_build_count -eq 0 -and
        [int]$fullEvaluationReceipt.actual_execution.solver_step_count -eq 0 -and
        -not [bool]$fullEvaluationReceipt.synthetic_envelope_is_physical_observation -and
        -not [bool]$fullEvaluationReceipt.native_measurements_observed -and
        -not [bool]$fullEvaluationReceipt.physical_characterization_executed -and
        -not [bool]$fullEvaluationReceipt.physical_acceptance_authority -and
        -not [bool]$fullEvaluationReceipt.release_authority
    ) "full_precision_zero_world_evaluation_receipt"
    $fullEvaluationFile = Get-R24D7FileReceipt $fullEvaluationPath
    $fullEvaluationCas = Publish-R24D7Artifact -Path $fullEvaluationPath
    $fullEvaluationLogCas = Publish-R24D7Artifact `
        -Path $fullEvaluationLogPath `
        -MediaType "text/plain"
    $zeroStdoutCas = Publish-R24D7Artifact `
        -Path ([string]$zeroWorker.stdout.path) `
        -MediaType "text/plain"
    $zeroStderrCas = Publish-R24D7Artifact `
        -Path ([string]$zeroWorker.stderr.path) `
        -MediaType "text/plain"
    $zeroEngineCas = Publish-R24D7Artifact `
        -Path ([string]$zeroWorker.engine_log.path) `
        -MediaType "text/plain"

    $postZeroHead = Get-R24D7GitValue @("rev-parse", "HEAD")
    $postZeroStatus = Get-R24D7GitValue @("status", "--short")
    $postZeroConsole = Get-R24D7FileReceipt $consolePath
    $postZeroEngine = Get-R24D7FileReceipt $enginePath
    Assert-R24D7Supervisor (
        $postZeroHead -ceq $head -and
        [string]::IsNullOrEmpty($postZeroStatus) -and
        [string]$postZeroConsole.raw_sha256 -ceq "sha256:$expectedConsoleHash" -and
        [string]$postZeroEngine.raw_sha256 -ceq "sha256:$expectedEngineHash"
    ) "post_zero_world_drift"

    if ($Mode -ceq "ZeroWorld") {
        $receipt = [ordered]@{
            schema_version = (
                "sporespore_qsdk_r24d7_one_hinge_telemetry_zero_world_" +
                "qualification_receipt_v1"
            )
            ok = $true
            gate_id = "QSDK-R24D7"
            question_class = "non_physical_source_conformance"
            result = (
                "complete_zero_world_serialized_envelope_gate_passed_" +
                "physical_characterization_not_executed"
            )
            source = [ordered]@{
                root = $root.Replace("\", "/")
                remote = $remote
                branch = $branch
                head = $head
                upstream = $upstream
                cached_origin_main = $cached
                live_origin_main = $live
                clean = $true
                worktree_count = 1
                validation_manifest = $manifestReceipt
                source_binding_count = 11
            }
            runtime = [ordered]@{
                profile_id = "godot_4_7_jolt_sporespore_motor_telemetry_v1"
                console = $consoleReceipt
                engine = $engineReceipt
                retained_binary_count = 2
            }
            stages = @($stageReceipts)
            static_audit_stage_count = $stageReceipts.Count
            worker = [ordered]@{
                receipt = $zeroReceipt
                stdout = $zeroWorker.stdout
                stderr = $zeroWorker.stderr
                engine_log = $zeroWorker.engine_log
                stdout_cas = $zeroStdoutCas
                stderr_cas = $zeroStderrCas
                engine_log_cas = $zeroEngineCas
                termination_protocol_valid = $true
                supervisor_terminated_exact_process_tree = $true
            }
            serialized_envelope_oracle = [ordered]@{
                template = [ordered]@{
                    receipt = $templateReceipt
                    file = $templateFile
                    cas = $templateCas
                    log = $templateRun.log
                    log_cas = $templateLogCas
                }
                integral_variant_normalization = $zeroIntegral
                integral_family_type_loss_negative_control_count = 21
                default_precision_negative_control = [ordered]@{
                    envelope = $defaultEnvelopeFile
                    envelope_cas = $defaultEnvelopeCas
                    evaluator_exit_code = [int]$defaultEvaluation.exit_code
                    evaluator_terminal_error = [string]$defaultEvaluation.expected_marker
                    evaluation_record_written = $false
                    log = $defaultEvaluation.log
                    log_cas = $defaultEvaluationLogCas
                }
                full_precision_positive_control = [ordered]@{
                    envelope = $fullEnvelopeFile
                    envelope_cas = $fullEnvelopeCas
                    evaluation = $fullEvaluationFile
                    evaluation_cas = $fullEvaluationCas
                    evaluation_receipt = $fullEvaluationReceipt
                    log = $fullEvaluationRun.log
                    log_cas = $fullEvaluationLogCas
                }
                default_precision_serialized_runtime_negative_control_count = 1
                serialized_runtime_positive_control_count = 1
                actual_world_attempt_count = 0
                actual_world_build_count = 0
                actual_solver_step_count = 0
                physical_characterization_executed = $false
                physical_acceptance_authority = $false
                release_authority = $false
            }
            evaluator_baseline_negative_control_count = 29
            integral_family_type_loss_negative_control_count = 21
            evaluator_total_negative_control_count = 50
            integral_path_family_count = 21
            integral_occurrence_count = 313
            predecessor_strict_integral_occurrence_count = 234
            accepted_outcome_mutation_count = 2
            contract_mutation_rejection_count = 22
            binary32_projection_control_count = 5
            default_precision_serialized_runtime_negative_control_count = 1
            serialized_runtime_positive_control_count = 1
            empirical_acceptance_threshold_count = 0
            world_attempt_count = 0
            world_build_count = 0
            solver_step_count = 0
            physical_characterization_executed = $false
            instrumented_profile_promoted = $false
            recovery_world_opened = $false
            prone_to_standing_world_opened = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
        $receiptPath = Join-Path $runRoot "receipt.json"
        [IO.File]::WriteAllText(
            $receiptPath,
            ($receipt | ConvertTo-Json -Depth 100) + "`n",
            [Text.UTF8Encoding]::new($false)
        )
        $receiptFile = Get-R24D7FileReceipt $receiptPath
        $receiptCas = Publish-R24D7Artifact -Path $receiptPath
        Write-Output (
            "QSDK_R24D7_ONE_HINGE_ZERO_WORLD_GATE " +
            ([ordered]@{
                ok = $true
                source_commit = $head
                source_binding_count = 11
                static_audit_stage_count = $stageReceipts.Count
                evaluator_baseline_negative_control_count = 29
                integral_family_type_loss_negative_control_count = 21
                evaluator_total_negative_control_count = 50
                integral_path_family_count = 21
                integral_occurrence_count = 313
                predecessor_strict_integral_occurrence_count = 234
                accepted_outcome_mutation_count = 2
                contract_mutation_rejection_count = 22
                binary32_projection_control_count = 5
                default_precision_serialized_runtime_negative_control_count = 1
                serialized_runtime_positive_control_count = 1
                default_precision_negative_control_passed = $true
                full_precision_serialized_envelope_qualified = $true
                receipt_path = $receiptPath.Replace("\", "/")
                receipt_sha256 = [string]$receiptFile.raw_sha256
                receipt_cas_path = [string]$receiptCas.payload_path
                world_attempt_count = 0
                world_build_count = 0
                solver_step_count = 0
                physical_characterization_executed = $false
                instrumented_profile_promoted = $false
                physical_acceptance_authority = $false
                release_authority = $false
            } | ConvertTo-Json -Depth 30 -Compress)
        )
        return
    }

    # This file is written before the launcher starts. Its existence consumes
    # the exact source/runtime physical identity even if the worker later
    # returns a negative, invalid, incomplete, or host-failure terminal.
    $attemptPath = Join-Path $runRoot "attempt.json"
    $executionNonce = [guid]::NewGuid().ToString("N")
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_r24d7_physical_attempt_v1"
        gate_id = "QSDK-R24D7"
        question_class = "development"
        status = "consumed_before_worker_launch"
        source_commit = $head
        execution_nonce = $executionNonce
        console_binary_sha256 = "sha256:$expectedConsoleHash"
        engine_binary_sha256 = "sha256:$expectedEngineHash"
        zero_world_receipt_sha256 = [string]$qualifiedZeroFile.raw_sha256
        declared_world_attempt_count = 1
        declared_world_build_count = 1
        same_source_rerun_allowed = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    [IO.File]::WriteAllText(
        $attemptPath,
        ($attempt | ConvertTo-Json -Depth 40) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
    $physicalAttemptCreated = $true
    $attemptFile = Get-R24D7FileReceipt $attemptPath
    $attemptCas = Publish-R24D7Artifact -Path $attemptPath

    $prePhysicalHead = Get-R24D7GitValue @("rev-parse", "HEAD")
    $prePhysicalLive = (Get-R24D7GitValue @(
        "ls-remote", "--heads", "origin", "refs/heads/main"
    )).Split("`t")[0]
    $prePhysicalStatus = Get-R24D7GitValue @("status", "--short")
    Assert-R24D7Supervisor (
        $prePhysicalHead -ceq $head -and
        $prePhysicalLive -ceq $head -and
        [string]::IsNullOrEmpty($prePhysicalStatus)
    ) "pre_physical_source_drift"
    Assert-R24D7ManifestAndBindings -Head $head -Manifest (
        Get-Content -Raw -LiteralPath $manifestPath |
            ConvertFrom-Json -AsHashtable -Depth 100
    )
    Assert-R24D7Supervisor (
        [string](Get-R24D7FileReceipt $consolePath).raw_sha256 -ceq
            "sha256:$expectedConsoleHash" -and
        [string](Get-R24D7FileReceipt $enginePath).raw_sha256 -ceq
            "sha256:$expectedEngineHash"
    ) "pre_physical_runtime_drift"

    $physicalWorker = Invoke-R24D7Worker `
        -ConsolePath $consolePath `
        -ProjectRoot $projectRoot `
        -RunRoot $runRoot `
        -WorkerMode "physical" `
        -Nonce $executionNonce `
        -Head $head
    $rawJson = Get-R24D7Marker `
        -Lines $physicalWorker.stdout_lines `
        -Prefix $workerPhysicalPrefix `
        -Code "physical_worker"
    $rawEnvelope = $rawJson | ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D7Supervisor (
        [string]$rawEnvelope.schema_version -ceq
            "sporespore_qsdk_r24d7_godot_jolt_one_hinge_raw_report_v1" -and
        [string]$rawEnvelope.gate_id -ceq "QSDK-R24D7" -and
        [string]$rawEnvelope.question_class -ceq "development" -and
        [string]$rawEnvelope.source_commit -ceq $head -and
        [string]$rawEnvelope.execution_nonce -ceq $executionNonce
    ) "physical_raw_identity"
    $rawPath = Join-Path $runRoot "raw_report.json"
    [IO.File]::WriteAllText(
        $rawPath,
        $rawJson + "`n",
        [Text.UTF8Encoding]::new($false)
    )
    $rawFile = Get-R24D7FileReceipt $rawPath
    $rawCas = Publish-R24D7Artifact -Path $rawPath
    $evaluationPath = Join-Path $runRoot "evaluation.json"
    $evaluationLogPath = Join-Path $runRoot "05-evaluation.log"
    $evaluationRun = Invoke-R24D7Checked `
        -FileName $pythonPath `
        -Arguments @(
            (Get-R24D7Path $evaluatorRelative),
            "--integral-variant-schema", $integralSchemaPath,
            "--input", $rawPath,
            "--output", $evaluationPath
        ) `
        -Label "r24d7_physical_evaluation" `
        -LogPath $evaluationLogPath
    $evaluationMarker = Get-R24D7Marker `
        -Lines $evaluationRun.output `
        -Prefix "QSDK_R24D7_EVALUATION " `
        -Code "physical_evaluation"
    $evaluationTerminal = $evaluationMarker |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R24D7Supervisor (
        [bool]$evaluationTerminal.ok -and
        [string]$evaluationTerminal.result_class -ceq
            "complete_valid_descriptive_development_characterization" -and
        [int]$evaluationTerminal.cell_count -eq 9 -and
        [int]$evaluationTerminal.retained_sample_count -eq 68 -and
        [int]$evaluationTerminal.empirical_acceptance_threshold_count -eq 0 -and
        -not [bool]$evaluationTerminal.physical_acceptance_authority -and
        -not [bool]$evaluationTerminal.release_authority
    ) "physical_evaluation_terminal"
    $evaluation = Get-Content -Raw -LiteralPath $evaluationPath |
        ConvertFrom-Json -AsHashtable -Depth 100
    $evaluationFile = Get-R24D7FileReceipt $evaluationPath
    $evaluationCas = Publish-R24D7Artifact -Path $evaluationPath
    $evaluationLogCas = Publish-R24D7Artifact `
        -Path $evaluationLogPath `
        -MediaType "text/plain"
    $physicalStdoutCas = Publish-R24D7Artifact `
        -Path ([string]$physicalWorker.stdout.path) `
        -MediaType "text/plain"
    $physicalStderrCas = Publish-R24D7Artifact `
        -Path ([string]$physicalWorker.stderr.path) `
        -MediaType "text/plain"
    $physicalEngineCas = Publish-R24D7Artifact `
        -Path ([string]$physicalWorker.engine_log.path) `
        -MediaType "text/plain"

    $physicalReceipt = [ordered]@{
        schema_version = (
            "sporespore_qsdk_r24d7_one_hinge_telemetry_physical_" +
            "characterization_receipt_v1"
        )
        ok = $true
        gate_id = "QSDK-R24D7"
        question_class = "development"
        result_class = [string]$evaluation.result_class
        source_commit = $head
        validation_manifest = $manifestReceipt
        runtime = [ordered]@{
            console = $consoleReceipt
            engine = $engineReceipt
            retained_binary_count = 2
        }
        prerequisite_zero_world_receipt = $qualifiedZeroFile
        prerequisite_zero_world_receipt_cas = $qualifiedZeroCas
        attempt = $attemptFile
        attempt_cas = $attemptCas
        raw_report = $rawFile
        raw_report_cas = $rawCas
        evaluation = $evaluationFile
        evaluation_cas = $evaluationCas
        evaluation_log = $evaluationRun.log
        evaluation_log_cas = $evaluationLogCas
        worker = [ordered]@{
            stdout = $physicalWorker.stdout
            stderr = $physicalWorker.stderr
            engine_log = $physicalWorker.engine_log
            stdout_cas = $physicalStdoutCas
            stderr_cas = $physicalStderrCas
            engine_log_cas = $physicalEngineCas
            termination_protocol_valid = $true
            supervisor_terminated_exact_process_tree = $true
        }
        observed_summary = $evaluation.summary
        empirical_acceptance_threshold_count = 0
        numerical_accuracy_accepted = $false
        instrumented_profile_promoted = $false
        world_attempt_count = 1
        world_build_count = 1
        physics_step_count = 20
        retained_sample_count = 68
        recovery_world_opened = $false
        prone_to_standing_world_opened = $false
        cross_engine_equivalence_claimed = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    $physicalReceiptPath = Join-Path $runRoot "receipt.json"
    [IO.File]::WriteAllText(
        $physicalReceiptPath,
        ($physicalReceipt | ConvertTo-Json -Depth 100) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
    $physicalReceiptFile = Get-R24D7FileReceipt $physicalReceiptPath
    $physicalReceiptCas = Publish-R24D7Artifact -Path $physicalReceiptPath
    Write-Output (
        "QSDK_R24D7_ONE_HINGE_PHYSICAL_CHARACTERIZATION " +
        ([ordered]@{
            ok = $true
            source_commit = $head
            result_class = [string]$evaluation.result_class
            receipt_path = $physicalReceiptPath.Replace("\", "/")
            receipt_sha256 = [string]$physicalReceiptFile.raw_sha256
            receipt_cas_path = [string]$physicalReceiptCas.payload_path
            world_attempt_count = 1
            world_build_count = 1
            physics_step_count = 20
            retained_sample_count = 68
            telemetry_sample_count = [int]$evaluation.summary.telemetry_sample_count
            telemetry_missing_sample_count = (
                [int]$evaluation.summary.telemetry_missing_sample_count
            )
            empirical_acceptance_threshold_count = 0
            numerical_accuracy_accepted = $false
            instrumented_profile_promoted = $false
            recovery_world_opened = $false
            prone_to_standing_world_opened = $false
            physical_acceptance_authority = $false
            release_authority = $false
        } | ConvertTo-Json -Depth 40 -Compress)
    )
} catch {
    if ($Mode -ceq "Physical" -and $physicalAttemptCreated -and
        -not [string]::IsNullOrWhiteSpace($runRoot)) {
        $failurePath = Join-Path $runRoot "failure.json"
        $failure = [ordered]@{
            schema_version = "sporespore_qsdk_r24d7_physical_failure_v1"
            gate_id = "QSDK-R24D7"
            question_class = "development"
            status = "retained_incomplete_or_invalid_attempt_no_same_source_rerun"
            message = $_.Exception.Message
            world_attempt_count_lower_bound = 0
            world_attempt_count_upper_bound = 1
            world_build_count_lower_bound = 0
            world_build_count_upper_bound = 1
            same_source_rerun_allowed = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
        [IO.File]::WriteAllText(
            $failurePath,
            ($failure | ConvertTo-Json -Depth 40) + "`n",
            [Text.UTF8Encoding]::new($false)
        )
        try { [void](Publish-R24D7Artifact -Path $failurePath) } catch {}
    }
    throw
} finally {
    if ($null -ne $operationLock) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $operationLock
    }
}

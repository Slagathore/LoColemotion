#requires -Version 7.0
# Source-only bridge. The caller owns qualification origin and runtime preflight.
# Neither helper selects expected identity from the offered worker comparison.
. (Join-Path $PSScriptRoot 'qsdk_r10f_l15_launch_relationship.ps1')

function ConvertFrom-QsdkR10fL15ContextJson {
    param([Parameter(Mandatory)][string]$Text)
    $document = [System.Text.Json.JsonDocument]::Parse($Text)
    try { Assert-QsdkR10fL15JsonElement $document.RootElement } finally { $document.Dispose() }
    return ($Text | ConvertFrom-Json -AsHashtable -Depth 100)
}

function Assert-QsdkR10fL15ContextSourceReceipt {
    param(
        [AllowNull()][object]$Receipt,
        [Parameter(Mandatory)][string]$ExpectedRequestSha256,
        [Parameter(Mandatory)][System.Collections.IDictionary]$ExpectedBinding
    )
    # This is the complete reader contract, not evidence that the bridge ran.
    $proof = @{
        schema_version = 'sporespore_qsdk_r10f_l15_worker_context_integrity_v1'
        ledger_scope = @{
            subsystem = 'recovery'; engine_scope = 'godot_jolt'
            authority_mode = 'read_only_worker_context_against_enclosing_expectation'
            question_class = 'development'
        }
        ok = $true; prepared_context_valid = $true
        context_integrity_establishes_valid_child = $false
        raw_capture_binding = $ExpectedBinding
    }
    $expected = @{
        schema_version = 'sporespore_qsdk_r10f_l15_worker_context_source_receipt_v1'
        gate_id = 'QSDK-R10F'; repair_id = 'QSDK-R10F-L15'
        ledger_scope = @{
            subsystem = 'recovery'; engine_scope = 'godot_jolt'
            authority_mode = 'read_only_worker_context_source_bridge'
            question_class = 'development'
        }
        ok = $true; failure_code = ''
        offered_request_raw_sha256 = $ExpectedRequestSha256
        proof = $proof
    }
    foreach ($value in @($proof, $expected)) {
        foreach ($key in @(
            'compiled_collection_call_count', 'portable_recovery_advance_call_count',
            'model_construction_count', 'world_attempt_count', 'world_build_count',
            'scene_tree_insertion_count', 'native_physics_read_count', 'solver_step_count'
        )) { $value[$key] = 0 }
        foreach ($key in @(
            'expected_context_origin_authenticated_here', 'official_context_qualification',
            'physics_state_modified', 'physical_execution_authorized',
            'physical_acceptance_authority', 'release_authority'
        )) { $value[$key] = $false }
    }
    if (-not (Test-QsdkR10fL15ExactValue $Receipt $expected)) {
        throw 'L15_CONTEXT_SOURCE_COMPLETE_RECEIPT_INVALID'
    }
}

function Get-QsdkR10fL15ContextArguments {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Binding)
    $expected = $null
    if ($Binding.Contains('l15_prepared_context_expectation')) {
        $expected = $Binding.l15_prepared_context_expectation
    }
    return @{
        ExpectedL15ContextBinding = if ($expected -is [System.Collections.IDictionary] -and
            $expected.Contains('raw_capture_binding')) { $expected.raw_capture_binding } else { $null }
        ExpectedL15CollectionIdentity = if ($expected -is [System.Collections.IDictionary] -and
            $expected.Contains('collection_identity')) { $expected.collection_identity } else { $null }
    }
}

function Get-QsdkR10fL15ContextEnvironment {
    param([AllowNull()][object]$ExpectedBinding)
    # Validate before converting to the worker's canonical environment strings.
    # This checks transport shape, not the qualification origin or captured bytes.
    $invalid = 'L15_CONTEXT_ENVIRONMENT_BINDING_INVALID'
    if ($ExpectedBinding -isnot [System.Collections.IDictionary] -or $ExpectedBinding.Count -ne 2) {
        throw $invalid
    }
    foreach ($key in @('utf8_byte_length', 'raw_sha256')) {
        if (@($ExpectedBinding.Keys | Where-Object { $_ -is [string] -and $_ -ceq $key }).Count -ne 1) {
            throw $invalid
        }
    }
    if (-not (Test-QsdkR10fL15Integer $ExpectedBinding.utf8_byte_length -Maximum ([long]::MaxValue)) -or
        $ExpectedBinding.raw_sha256 -isnot [string] -or
        $ExpectedBinding.raw_sha256.Length -ne 71 -or
        $ExpectedBinding.raw_sha256 -cnotmatch '\Asha256:[0-9a-f]{64}\z') {
        throw $invalid
    }
    return @{
        SPORESPORE_GODOT_RECOVERY_L15_CONTEXT_UTF8_BYTE_LENGTH =
            $ExpectedBinding.utf8_byte_length.ToString([Globalization.CultureInfo]::InvariantCulture)
        SPORESPORE_GODOT_RECOVERY_L15_CONTEXT_RAW_SHA256 = $ExpectedBinding.raw_sha256
    }
}

function Get-QsdkR10fL15ContextSourceProof {
    param(
        [AllowNull()][object]$Comparison,
        [AllowNull()][object]$ExpectedBinding,
        [AllowNull()][object]$ExpectedIdentity
    )
    if ($ExpectedBinding -isnot [System.Collections.IDictionary] -or
        $ExpectedIdentity -isnot [System.Collections.IDictionary]) {
        throw 'L15_CONTEXT_SOURCE_EXPECTATIONS_REQUIRED'
    }
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $request = [ordered]@{
        schema_version = 'sporespore_qsdk_r10f_l15_worker_context_source_request_v1'
        comparison = $Comparison
        expected_capture_binding = $ExpectedBinding
        expected_collection_identity = $ExpectedIdentity
    }
    $utf8 = [Text.UTF8Encoding]::new($false, $true)
    $bytes = $utf8.GetBytes(($request | ConvertTo-Json -Depth 100 -Compress))
    $digest = 'sha256:' + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = 'C:\Program Files\Python311\python.exe'
    $start.WorkingDirectory = $root
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardInputEncoding = $utf8
    $start.StandardOutputEncoding = $utf8
    $start.StandardErrorEncoding = $utf8
    $start.ArgumentList.Add('-B')
    $start.ArgumentList.Add((Join-Path $root 'sdk/conformance/qsdk_r10f_l15_context_source_bridge.py'))
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $started = $false
    try {
        $started = $process.Start()
        if (-not $started) { throw 'L15_CONTEXT_SOURCE_START' }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $writeTask = $process.StandardInput.BaseStream.WriteAsync($bytes, 0, $bytes.Length)
        if (-not $writeTask.Wait(60000)) { throw 'L15_CONTEXT_SOURCE_WRITE_TIMEOUT' }
        $process.StandardInput.Close()
        if (-not $process.WaitForExit(60000)) { throw 'L15_CONTEXT_SOURCE_TIMEOUT' }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $lines = @($stdout -split "`r?`n" | Where-Object { $_.Length -gt 0 })
        $marker = 'QSDK_R10F_L15_WORKER_CONTEXT_SOURCE '
        if ($lines.Count -ne 1 -or $stderr.Length -ne 0 -or
            -not $lines[0].StartsWith($marker, [StringComparison]::Ordinal)) {
            throw 'L15_CONTEXT_SOURCE_PROCESS_OUTPUT'
        }
        $receipt = ConvertFrom-QsdkR10fL15ContextJson $lines[0].Substring($marker.Length)
        if ($receipt.schema_version -cne 'sporespore_qsdk_r10f_l15_worker_context_source_receipt_v1' -or
            $receipt.gate_id -cne 'QSDK-R10F' -or $receipt.repair_id -cne 'QSDK-R10F-L15' -or
            $receipt.offered_request_raw_sha256 -cne $digest) {
            throw 'L15_CONTEXT_SOURCE_RESPONSE_BINDING'
        }
        if ($process.ExitCode -ne 0 -or $receipt.ok -isnot [bool] -or -not $receipt.ok) {
            throw ('L15_CONTEXT_SOURCE_REFUSED:' + [string]$receipt.failure_code)
        }
        Assert-QsdkR10fL15ContextSourceReceipt $receipt $digest $ExpectedBinding
        return $receipt.proof
    } finally {
        if ($started -and -not $process.HasExited) {
            $process.Kill($true)
            $process.WaitForExit()
        }
        $process.Dispose()
    }
}

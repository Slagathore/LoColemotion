#requires -Version 7.0
# Shared read-only runtime binder. Dot-sourcing defines functions only.
# The literal is a selected-image contract, not an observed qualification.
function Get-QsdkR10fL14HistoricalRuntimeBinding {
    return ('{"console_and_engine_are_distinct_required_images":true,"file_existence_or_version_string_alone_is_authority":false,"gate_id":"QSDK-R10F","historical_result_reclassified":false,"image_count":5,"images":{"godot_console":{"byte_length":293376,"path":"C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d157-godot-jolt-rotation-integration-energy-v6/development-cold-build-ed4ec00a/godot.windows.editor.dev.x86_64.console.exe","raw_sha256":"sha256:2027bcd4adfce5cdecafa5b02392f859b1c61b0895d4f4588b4edf6eb91e2f9c"},"godot_engine":{"byte_length":188855808,"path":"C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/qsdk-r24d157-godot-jolt-rotation-integration-energy-v6/development-cold-build-ed4ec00a/godot.windows.editor.dev.x86_64.exe","raw_sha256":"sha256:1b365fe5a054e2614e2c063273d6e686593eafac81836475385df14b65177e4b"},"powershell_host":{"byte_length":301368,"path":"C:/Program Files/PowerShell/7/pwsh.exe","raw_sha256":"sha256:362a356ce7f0940ec74f73a8fc2c990a2cc24a38a11c90bbd8eca947110ad139"},"python_helper":{"byte_length":103192,"path":"C:/Program Files/Python311/python.exe","raw_sha256":"sha256:5f7b89a612c9b8af1d6456cdfcd1dbe5ca630849e79aebced9bee9a6694952ec"},"sdk_adapter":{"byte_length":10120192,"path":"C:/Users/Cole/CodeStuff/games/SporeSpore/sdk/target/debug/sporespore_godot_adapter.dll","raw_sha256":"sha256:0170af9b467434e8d750a699d52547dc88ab24148a860a3c82df05a9de777405"}},"ledger_scope":{"authority_mode":"zero_world_exact_runtime_image_binding","engine_scope":"godot_jolt","question_class":"development","subsystem":"recovery"},"model_construction_count":0,"native_readback_count":0,"ok":true,"physical_acceptance_authority":false,"physical_execution_authorized":false,"physics_state_modified":false,"qualified_native_foundation":{"byte_length":21291,"path":"sdk/recovery/r24d157_godot_jolt_rotation_integration_energy_zero_world_qualification_closure_v1.json","raw_sha256":"sha256:b1603f995d83228de1f7331673b35d3a2d56514c467061d408025d64ef1b14de"},"release_authority":false,"repair_id":"QSDK-R10F-L14","scene_tree_insertion_count":0,"schema_version":"sporespore_qsdk_r10f_l14_exact_runtime_image_binding_v1","sdk1_m07_satisfied":false,"selected_images_changed":false,"solver_step_count":0,"world_attempt_count":0,"world_build_count":0}' | ConvertFrom-Json -AsHashtable -Depth 100)
}

function Get-QsdkR10fL14ExpectedRuntimeBinding {
    $hostContractRelative = 'sdk/development/recovery_powershell_host_successor_v1.json'
    $hostContractPath = Join-Path (Split-Path -Parent $PSScriptRoot) $hostContractRelative
    $hostContractSha = 'sha256:64a98bd44a27d89912fcb9fb955d1776d53f19c6f9080f748a03a3d8d8dfac3e'
    if ('sha256:' + (Get-FileHash -LiteralPath $hostContractPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $hostContractSha) {
        throw 'RUNTIME_HOST_SUCCESSOR_SOURCE_BINDING'
    }
    $hostContract = Get-Content -LiteralPath $hostContractPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $policy = Get-QsdkR10fL14HistoricalRuntimeBinding
    if (-not (Test-QsdkR10fL14RuntimeValue $hostContract.previous_host $policy.images.powershell_host)) {
        throw 'RUNTIME_HOST_SUCCESSOR_PREDECESSOR'
    }
    $policy.schema_version = $hostContract.binding_schema
    $policy.images.powershell_host = $hostContract.selected_host
    $policy.selected_images_changed = $true
    $policy.host_successor = @{path=$hostContractRelative;raw_sha256=$hostContractSha}
    return $policy
}

function Test-QsdkR10fL14RuntimeValue {
    param([AllowNull()]$Actual, [AllowNull()]$Expected)
    if ($null -eq $Actual -or $null -eq $Expected) {
        return ($null -eq $Actual -and $null -eq $Expected)
    }
    if ($Expected -is [System.Collections.IDictionary]) {
        if ($Actual -isnot [System.Collections.IDictionary] -or $Actual.Count -ne $Expected.Count) { return $false }
        foreach ($key in $Expected.Keys) {
            $runtimeMatchingKeys = @($Actual.Keys | Where-Object { [string]$_ -ceq [string]$key })
            if ($runtimeMatchingKeys.Count -ne 1 -or -not (Test-QsdkR10fL14RuntimeValue $Actual[$key] $Expected[$key])) { return $false }
        }
        return $true
    }
    if ($Expected -is [System.Collections.IList]) {
        if ($Actual -isnot [System.Collections.IList] -or $Actual.Count -ne $Expected.Count) { return $false }
        for ($i = 0; $i -lt $Expected.Count; $i++) {
            if (-not (Test-QsdkR10fL14RuntimeValue $Actual[$i] $Expected[$i])) { return $false }
        }
        return $true
    }
    if ($Expected -is [bool]) { return ($Actual -is [bool] -and $Actual -eq $Expected) }
    if ($Expected -is [int] -or $Expected -is [long]) {
        return (($Actual -is [int] -or $Actual -is [long]) -and $Actual -eq $Expected)
    }
    if ($Expected -is [string]) { return ($Actual -is [string] -and $Actual -ceq $Expected) }
    return ($Actual.GetType() -eq $Expected.GetType() -and $Actual -eq $Expected)
}

function Assert-QsdkR10fL14RuntimeBinding {
    param([Parameter(Mandatory)][AllowNull()]$Binding)
    if ($Binding -is [System.Collections.IDictionary] -and $Binding.Contains('schema_version') -and
        $Binding.schema_version -ceq 'sporespore_r10ap_diagnostic_runtime_image_binding_v1') {
        . (Join-Path $PSScriptRoot 'r10ap_host_runtime.ps1')
        Assert-R10apRuntimeBinding $Binding
        return
    }
    if ($Binding -is [System.Collections.IDictionary] -and $Binding.Contains('schema_version') -and
        $Binding.schema_version -ceq 'sporespore_r10am_diagnostic_runtime_image_binding_v1') {
        . (Join-Path $PSScriptRoot 'r10am_host_runtime.ps1')
        Assert-R10amRuntimeBinding $Binding
        return
    }
    if ($Binding -is [System.Collections.IDictionary] -and $Binding.Contains('schema_version') -and
        $Binding.schema_version -ceq 'sporespore_r10aj_diagnostic_runtime_image_binding_v1') {
        . (Join-Path $PSScriptRoot 'r10aj_host_runtime.ps1')
        Assert-R10ajRuntimeBinding $Binding
        return
    }
    if ($Binding -is [System.Collections.IDictionary] -and $Binding.Contains('schema_version') -and
        $Binding.schema_version -ceq 'sporespore_r10ai_diagnostic_runtime_image_binding_v1') {
        . (Join-Path $PSScriptRoot 'r10ai_host_runtime.ps1')
        Assert-R10aiRuntimeBinding $Binding
        return
    }
    if ($Binding -is [System.Collections.IDictionary] -and $Binding.Contains('schema_version') -and
        $Binding.schema_version -ceq 'sporespore_r10ag_diagnostic_runtime_image_binding_v1') {
        . (Join-Path $PSScriptRoot 'r10ag_host_runtime.ps1')
        Assert-R10agRuntimeBinding $Binding
        return
    }
    if ($Binding -is [System.Collections.IDictionary] -and $Binding.Contains('schema_version') -and
        $Binding.schema_version -ceq 'sporespore_r10af_diagnostic_runtime_image_binding_v1') {
        . (Join-Path $PSScriptRoot 'r10af_host_runtime.ps1')
        Assert-R10afRuntimeBinding $Binding
        return
    }
    if ($Binding -is [System.Collections.IDictionary] -and $Binding.Contains('schema_version') -and
        $Binding.schema_version -ceq 'sporespore_r10ae_diagnostic_runtime_image_binding_v1') {
        . (Join-Path $PSScriptRoot 'r10ae_host_runtime.ps1')
        Assert-R10aeRuntimeBinding $Binding
        return
    }
    if ($Binding -is [System.Collections.IDictionary] -and $Binding.Contains('schema_version') -and
        $Binding.schema_version -ceq 'sporespore_r10ad_diagnostic_runtime_image_binding_v1') {
        . (Join-Path $PSScriptRoot 'r10ad_host_runtime.ps1')
        Assert-R10adRuntimeBinding $Binding
        return
    }
    if ($Binding -is [System.Collections.IDictionary] -and $Binding.Contains('schema_version') -and
        $Binding.schema_version -ceq 'sporespore_r10ac_diagnostic_runtime_image_binding_v1') {
        . (Join-Path $PSScriptRoot 'r10ac_host_runtime.ps1')
        Assert-R10acRuntimeBinding $Binding
        return
    }
    if (-not (Test-QsdkR10fL14RuntimeValue $Binding (Get-QsdkR10fL14ExpectedRuntimeBinding)) -and
        -not (Test-QsdkR10fL14RuntimeValue $Binding (Get-QsdkR10fL14HistoricalRuntimeBinding))) {
        throw "L14_RUNTIME_BINDING_NOT_EXACT"
    }
}

function Get-QsdkR10fL14RuntimeBinding {
    param(
        [Parameter(Mandatory)][string]$Godot,
        [string]$PythonExecutable = "C:\Program Files\Python311\python.exe",
        [AllowNull()]$ExpectedBinding
    )
    $runtimeRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
    if ($runtimeRoot -cne "C:\Users\Cole\CodeStuff\games\LoColemotion") {
        throw "L14_RUNTIME_ROOT"
    }
    $policy = Get-QsdkR10fL14ExpectedRuntimeBinding
    $verifyQualified = $PSBoundParameters.ContainsKey("ExpectedBinding")
    if ($verifyQualified) { Assert-QsdkR10fL14RuntimeBinding $ExpectedBinding }
    if ($verifyQualified -and -not (Test-QsdkR10fL14RuntimeValue $ExpectedBinding $policy)) {
        throw 'L14_RUNTIME_QUALIFICATION_DRIFT'
    }
    $actualPython = [IO.Path]::GetFullPath($PythonExecutable)
    $actualPowerShell = [IO.Path]::GetFullPath([string](Get-Process -Id $PID).Path)
    $actualGodot = [IO.Path]::GetFullPath($Godot)
    foreach ($entry in @(
        @{ role = "godot_console"; path = $actualGodot },
        @{ role = "python_helper"; path = $actualPython },
        @{ role = "powershell_host"; path = $actualPowerShell }
    )) {
        if (-not [string]::Equals(
            $entry.path, [IO.Path]::GetFullPath([string]$policy.images[$entry.role].path),
            [StringComparison]::OrdinalIgnoreCase
        )) { throw ("L14_RUNTIME_SELECTED_PATH:" + $entry.role) }
    }
    # Check the interpreters before starting even the read-only helper.
    foreach ($role in @("python_helper", "powershell_host")) {
        $image = $policy.images[$role]
        $item = Get-Item -LiteralPath $image.path -ErrorAction Stop
        $digest = "sha256:" + (Get-FileHash -LiteralPath $image.path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($item.Length -ne $image.byte_length -or $digest -cne $image.raw_sha256) {
            throw ("L14_RUNTIME_IMAGE:" + $role)
        }
    }
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $actualPython
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WorkingDirectory = $runtimeRoot
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.RedirectStandardInput = $true
    foreach ($argument in @(
        "-B", (Join-Path $runtimeRoot "sdk/conformance/qsdk_r10f_l14_runtime_binding.py"),
        "--godot", $actualGodot, "--powershell-host", $actualPowerShell
    )) { $start.ArgumentList.Add([string]$argument) }
    if ($verifyQualified) { $start.ArgumentList.Add("--expected-binding-stdin") }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $started = $false
    try {
        if (-not $process.Start()) { throw "L14_RUNTIME_HELPER_START" }
        $started = $true
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if ($verifyQualified) {
            $process.StandardInput.Write(($ExpectedBinding | ConvertTo-Json -Depth 100 -Compress))
        }
        $process.StandardInput.Close()
        if (-not $process.WaitForExit(60000)) { throw "L14_RUNTIME_HELPER_TIMEOUT" }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($stderr)) {
            throw ("L14_RUNTIME_HELPER_REFUSED:" + $stderr.Trim())
        }
        $marker = "QSDK_R10F_L14_EXACT_RUNTIME_BINDING_PASS "
        $lines = @($stdout -split '\r?\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($lines.Count -ne 1 -or -not $lines[0].StartsWith($marker, [StringComparison]::Ordinal)) {
            throw "L14_RUNTIME_HELPER_MARKER"
        }
        $binding = $lines[0].Substring($marker.Length) | ConvertFrom-Json -AsHashtable -Depth 100
        Assert-QsdkR10fL14RuntimeBinding $binding
        if ($verifyQualified -and -not (Test-QsdkR10fL14RuntimeValue $binding $ExpectedBinding)) {
            throw "L14_RUNTIME_QUALIFICATION_DRIFT"
        }
        return $binding
    } finally {
        if ($started -and -not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
        $process.Dispose()
    }
}

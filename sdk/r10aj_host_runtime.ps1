# Dot-sourcing defines only read-only diagnostic image checks.
function Get-R10ajExpectedRuntimeBinding {
    $path = Join-Path $PSScriptRoot 'development/r10aj_host_runtime_contract_v1.json'
    if ('sha256:' + (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne 'sha256:4da10c75087f4efc1958c220b23de2703bebaf02b03aac201fa9101bf4f22e93') {
        throw 'R10AJ_HOST_CONTRACT_DRIFT'
    }
    return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable -Depth 100)
}

function Assert-R10ajRuntimeBinding {
    param([Parameter(Mandatory)][AllowNull()]$Binding)
    if (-not (Test-QsdkR10fL14RuntimeValue $Binding (Get-R10ajExpectedRuntimeBinding))) {
        throw 'R10AJ_HOST_BINDING_NOT_EXACT'
    }
}

function Get-R10ajRuntimeBinding {
    param([Parameter(Mandatory)][string]$Godot,
          [string]$PythonExecutable = 'C:\Program Files\Python311\python.exe')
    $runtimeRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    if ($runtimeRoot -cne 'C:\Users\Cole\CodeStuff\games\SporeSpore' -or
        (& git -C $runtimeRoot rev-parse --show-toplevel) -cne $runtimeRoot.Replace('\', '/') -or
        (& git -C $runtimeRoot remote get-url origin) -cne 'https://github.com/Slagathore/sporespore.git') {
        throw 'R10AJ_HOST_REPOSITORY'
    }
    $value = Get-R10ajExpectedRuntimeBinding
    $offered = @{godot_console=$Godot;python_helper=$PythonExecutable;powershell_host=(Get-Process -Id $PID).Path}
    foreach ($role in $offered.Keys) {
        if (-not [string]::Equals([IO.Path]::GetFullPath($offered[$role]),
            [IO.Path]::GetFullPath($value.images[$role].path), [StringComparison]::OrdinalIgnoreCase)) {
            throw ('R10AJ_HOST_SELECTED_PATH:' + $role)
        }
    }
    foreach ($role in $value.images.Keys) {
        $expected = $value.images[$role]
        if ((Get-Item -LiteralPath $expected.path).Length -ne $expected.byte_length -or
            'sha256:' + (Get-FileHash -LiteralPath $expected.path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $expected.raw_sha256) {
            throw ('R10AJ_HOST_IMAGE:' + $role)
        }
    }
    foreach ($field in @('diagnostic_design', 'observer_component', 'classification_component')) {
        $expected = $value[$field]; $path = Join-Path $runtimeRoot $expected.path
        if ((Get-Item -LiteralPath $path).Length -ne $expected.byte_length -or
            'sha256:' + (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $expected.raw_sha256) {
            throw ('R10AJ_HOST_DEPENDENCY:' + $field)
        }
    }
    return $value
}

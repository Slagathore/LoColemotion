#requires -Version 7.5
# Pure actual response reader: no engine, process executor or identity allocation.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ($root -cne 'C:\Users\Cole\CodeStuff\games\SporeSpore') { throw 'L15_CONTEXT_TEST_ROOT' }
. (Join-Path $root 'sdk/qsdk_r10f_l15_context_source.ps1')
$inputData = [Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable -Depth 100
$results = [Collections.Generic.List[object]]::new()
foreach ($case in $inputData.cases) {
    $failure = ''
    try {
        $receipt = ConvertFrom-QsdkR10fL15ContextJson $case.raw
        Assert-QsdkR10fL15ContextSourceReceipt $receipt $inputData.request_sha256 $inputData.expected_binding
    } catch { $failure = $_.Exception.Message }
    $results.Add(@{ name = $case.name; accepted = $failure.Length -eq 0; failure = $failure })
}
@{
    schema_version = 'sporespore_qsdk_r10f_l15_context_response_reader_zero_world_v1'
    ledger_scope = @{ subsystem = 'recovery'; engine_scope = 'godot_jolt';
        authority_mode = 'zero_world_actual_context_response_reader'; question_class = 'development' }
    results = @($results)
    model_construction_count = 0; world_build_count = 0; solver_step_count = 0
    native_physics_read_count = 0; physical_acceptance_authority = $false; release_authority = $false
} | ConvertTo-Json -Compress -Depth 100

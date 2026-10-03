# Loaded only by the distinct R10V child-retention path.
function Write-R10vCompactChildEnvelope {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Envelope,
        [Parameter(Mandatory)][System.Collections.IDictionary]$ExpectedContext
    )
    $childRoot = [IO.Path]::GetFullPath([string]$Envelope.evidence_path)
    $durableRoot = [IO.Path]::GetFullPath('C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence') + [IO.Path]::DirectorySeparatorChar
    Assert-R10f ($childRoot.StartsWith($durableRoot, [StringComparison]::OrdinalIgnoreCase)) 'R10V_RETENTION_ROOT'
    $path = Join-Path $childRoot 'child_envelope.json'
    # Serialize once using the existing exact transport. Verify the saved bytes
    # against the in-memory serialization before releasing any report object.
    $json = ConvertTo-SporeSporeExactJson -Value $Envelope -Depth 100 -Indented
    $text = $json.Replace("`r`n", "`n") + "`n"
    $expected = Get-QsdkR10fL15TextBinding $text
    Write-Utf8CreateNew -Path $path -Text $text
    $saved = Get-R10fRetainedFileBinding $path
    Assert-R10f ($saved.byte_length -eq $expected.byte_length -and $saved.raw_sha256 -ceq $expected.raw_sha256) 'R10V_ENVELOPE_WRITE_BINDING'
    $json = $null; $text = $null

    $null = Assert-QsdkR10fL15ChildLaunchRelationship $Envelope $ExpectedContext
    foreach ($name in @('termination_protocol_valid', 'engine_health_passed', 'raw_marker_valid')) {
        Assert-R10f ($Envelope[$name] -is [bool] -and $Envelope[$name]) ('R10V_RETENTION_INVALID_' + $name)
    }
    Assert-R10f ($Envelope.exit_code -eq 0 -and $Envelope.child_retry_count -eq 0 -and $Envelope.child_replacement_count -eq 0) 'R10V_RETENTION_EXIT_OR_RETRY'
    Assert-R10f ($Envelope.report -is [System.Collections.IDictionary]) 'R10V_RETENTION_REPORT_MISSING'
    $names = [ordered]@{
        child_attempt_identity='child_attempt_identity.json'; worker_stdout='worker.stdout.txt'
        worker_stderr='worker.stderr.txt'; termination_receipt='termination_receipt.json'
        engine_health='engine_health.json'; worker_report='worker_report.json'
    }
    Assert-R10f ($Envelope.retained_artifact_bindings.Count -eq $names.Count) 'R10V_RETENTION_ARTIFACT_POPULATION'
    foreach ($name in $names.Keys) {
        $actual = Get-R10fRetainedFileBinding (Join-Path $childRoot $names[$name])
        Assert-R10f (Test-QsdkR10fL15ExactValue $Envelope.retained_artifact_bindings[$name] $actual) ('R10V_RETENTION_ARTIFACT_' + $name)
    }
    $compact = [ordered]@{schema_version='sporespore_r10v_compact_child_retention_v1'}
    foreach ($name in @(
        'role', 'child_attempt_id', 'termination_nonce', 'evidence_path',
        'child_retry_count', 'child_replacement_count', 'started_utc', 'completed_utc',
        'process_id', 'worker_process_id', 'exit_code', 'termination_protocol_valid',
        'engine_health_passed', 'raw_marker_valid', 'retained_artifact_bindings',
        'r10f_l15_launch_relationship', 'termination_ready_receipt',
        'physical_acceptance_authority', 'release_authority'
    )) { $compact[$name] = $Envelope[$name] }
    $compact.retained_envelope_binding = $saved
    $compactBytes = [Text.Encoding]::UTF8.GetByteCount((ConvertTo-SporeSporeExactJson -Value $compact -Depth 100))
    Assert-R10f ($compactBytes -le 65536) 'R10V_COMPACT_METADATA_BOUND'
    Write-JsonCreateNew (Join-Path $childRoot 'payload_release_receipt.json') ([ordered]@{
        schema_version='sporespore_r10v_payload_release_receipt_v1'
        ledger_scope=@{subsystem='recovery';engine_scope='godot_jolt';authority_mode='verified_retained_child_payload_release';question_class='development'}
        child_attempt_id=$Envelope.child_attempt_id; role=$Envelope.role
        retained_envelope=$saved; verified_artifacts=$Envelope.retained_artifact_bindings
        launch_relationship_valid=$true; compact_metadata_byte_length=$compactBytes
        report_payload_in_compact_metadata=$false; original_evidence_rewritten=$false
        physical_acceptance_authority=$false; release_authority=$false
    })
    return $compact
}

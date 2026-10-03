#requires -Version 7.5
# R10F-only opt-in host provenance. Dot-sourcing starts no process or world.
. (Join-Path $PSScriptRoot 'process/recovery_interface_contract_v1.ps1')

function Assert-QsdkR10fL15Launch {
    param([bool]$Condition, [string]$Code)
    if (-not $Condition) { throw ('QSDK_R10F_L15_LAUNCH_' + $Code) }
}

function Test-QsdkR10fL15Integer {
    param([AllowNull()]$Value, [long]$Minimum = 1, [long]$Maximum = 2147483647)
    return (($Value -is [int] -or $Value -is [long]) -and
        $Value -ge $Minimum -and $Value -le $Maximum)
}

function Test-QsdkR10fL15ExactValue {
    param([AllowNull()]$Actual, [AllowNull()]$Expected)
    if ($null -eq $Actual -or $null -eq $Expected) {
        return ($null -eq $Actual -and $null -eq $Expected)
    }
    if ($Expected -is [System.Collections.IDictionary]) {
        if ($Actual -isnot [System.Collections.IDictionary] -or $Actual.Count -ne $Expected.Count) { return $false }
        foreach ($key in $Expected.Keys) {
            $matchingKeys = @($Actual.Keys | Where-Object { [string]$_ -ceq [string]$key })
            if ($matchingKeys.Count -ne 1 -or -not (Test-QsdkR10fL15ExactValue $Actual[$key] $Expected[$key])) { return $false }
        }
        return $true
    }
    if ($Expected -is [System.Collections.IList]) {
        if ($Actual -isnot [System.Collections.IList] -or $Actual.Count -ne $Expected.Count) { return $false }
        for ($index = 0; $index -lt $Expected.Count; $index++) {
            if (-not (Test-QsdkR10fL15ExactValue $Actual[$index] $Expected[$index])) { return $false }
        }
        return $true
    }
    if ($Expected -is [bool]) { return ($Actual -is [bool] -and $Actual -eq $Expected) }
    if ($Expected -is [int] -or $Expected -is [long]) {
        return (($Actual -is [int] -or $Actual -is [long]) -and $Actual -eq $Expected)
    }
    return ($Actual.GetType() -eq $Expected.GetType() -and $Actual -ceq $Expected)
}

function Assert-QsdkR10fL15Keys {
    param([AllowNull()]$Value, [string[]]$Keys, [string]$Label)
    Assert-QsdkR10fL15Launch ($Value -is [System.Collections.IDictionary]) ($Label + '_OBJECT')
    Assert-QsdkR10fL15Launch ($Value.Count -eq $Keys.Count) ($Label + '_KEY_COUNT')
    foreach ($key in $Keys) {
        Assert-QsdkR10fL15Launch (@($Value.Keys | Where-Object { [string]$_ -ceq $key }).Count -eq 1) ($Label + '_KEY_' + $key)
    }
}

function Get-QsdkR10fL15TextBinding {
    param([AllowEmptyString()][string]$Text)
    $bytes = [Text.UTF8Encoding]::new($false, $true).GetBytes($Text)
    return [ordered]@{
        byte_length = $bytes.Length
        raw_sha256 = 'sha256:' + [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($bytes)
        ).ToLowerInvariant()
    }
}

function Assert-QsdkR10fL15JsonElement {
    param([System.Text.Json.JsonElement]$Element)
    if ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object) {
        $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($property in $Element.EnumerateObject()) {
            Assert-QsdkR10fL15Launch ($names.Add($property.Name)) 'JSON_DUPLICATE_KEY'
            Assert-QsdkR10fL15JsonElement $property.Value
        }
    } elseif ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Array) {
        foreach ($child in $Element.EnumerateArray()) { Assert-QsdkR10fL15JsonElement $child }
    }
}

function ConvertFrom-QsdkR10fL15ExactJson {
    param([string]$Text)
    $document = [System.Text.Json.JsonDocument]::Parse($Text)
    try {
        Assert-QsdkR10fL15Launch ($document.RootElement.ValueKind -eq [System.Text.Json.JsonValueKind]::Object) 'JSON_ROOT_OBJECT'
        Assert-QsdkR10fL15JsonElement $document.RootElement
    } finally { $document.Dispose() }
    # Keep source timestamps as strings; implicit DateTime conversion would
    # change the exact payload representation during a read-only validation.
    return ($Text | ConvertFrom-Json -AsHashtable -Depth 100 -DateKind String)
}

function ConvertTo-QsdkR10fL15Utc {
    param([AllowNull()]$Value, [string]$Label)
    Assert-QsdkR10fL15Launch ($Value -is [string]) ($Label + '_TYPE')
    $parsed = [DateTimeOffset]::MinValue
    $valid = [DateTimeOffset]::TryParseExact($Value, 'o',
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::RoundtripKind, [ref]$parsed)
    Assert-QsdkR10fL15Launch ($valid -and $parsed.Offset -eq [TimeSpan]::Zero) ($Label + '_UTC')
    return $parsed
}

function Assert-QsdkR10fL15LaunchContext {
    param([AllowNull()]$Context)
    $contract = Get-SporeRecoveryProcessContractV1
    Assert-QsdkR10fL15Keys $Context @(
        'schema_version', 'parent_attempt_id', 'child_attempt_id', 'role',
        'source_commit', 'authority_sha256', 'termination_nonce',
        'ready_marker_prefix', 'root_image', 'worker_image'
    ) 'CONTEXT'
    Assert-QsdkR10fL15Launch ($Context.schema_version -is [string] -and $Context.schema_version -ceq $contract.context_schema) 'CONTEXT_SCHEMA'
    foreach ($key in @('parent_attempt_id', 'child_attempt_id', 'termination_nonce')) {
        Assert-QsdkR10fL15Launch ($Context[$key] -is [string] -and $Context[$key] -cmatch '^[0-9a-f]{32}$') ('CONTEXT_' + $key)
    }
    Assert-QsdkR10fL15Launch ($Context.parent_attempt_id -cne $Context.child_attempt_id) 'CONTEXT_DISTINCT_CHILD'
    Assert-QsdkR10fL15Launch ($Context.role -is [string] -and $Context.role -cin $contract.roles) 'CONTEXT_ROLE'
    Assert-QsdkR10fL15Launch ($Context.source_commit -is [string] -and $Context.source_commit -cmatch '^[0-9a-f]{40}$') 'CONTEXT_SOURCE'
    Assert-QsdkR10fL15Launch ($Context.authority_sha256 -is [string] -and $Context.authority_sha256 -cmatch '^sha256:[0-9a-f]{64}$') 'CONTEXT_AUTHORITY'
    Assert-QsdkR10fL15Launch ($Context.ready_marker_prefix -is [string] -and $Context.ready_marker_prefix.Length -gt 0) 'CONTEXT_MARKER'
    foreach ($key in @('root_image', 'worker_image')) {
        $image = $Context[$key]
        Assert-QsdkR10fL15Keys $image @('path', 'byte_length', 'raw_sha256') ('CONTEXT_' + $key)
        Assert-QsdkR10fL15Launch ($image.path -is [string] -and [IO.Path]::IsPathFullyQualified($image.path)) ('IMAGE_PATH_' + $key)
        Assert-QsdkR10fL15Launch (Test-QsdkR10fL15Integer $image.byte_length -Maximum ([long]::MaxValue)) ('IMAGE_BYTES_' + $key)
        Assert-QsdkR10fL15Launch ($image.raw_sha256 -is [string] -and $image.raw_sha256 -cmatch '^sha256:[0-9a-f]{64}$') ('IMAGE_SHA_' + $key)
    }
}

function Assert-QsdkR10fL15LaunchPayload {
    param(
        [AllowNull()]$Payload, [System.Collections.IDictionary]$ExpectedContext,
        [AllowNull()]$RootProcessId, [AllowNull()]$WorkerProcessId,
        [string]$StartedUtc, [AllowNull()]$ExpectedReadyReceipt
    )
    $contract = Get-SporeRecoveryProcessContractV1
    Assert-QsdkR10fL15LaunchContext $ExpectedContext
    Assert-QsdkR10fL15Keys $Payload @(
        'context', 'root_process_id', 'worker_process_id', 'started_utc',
        'observed_utc', 'relationship', 'process_chain', 'ready_line', 'ready_receipt'
    ) 'PAYLOAD'
    Assert-QsdkR10fL15Launch (Test-QsdkR10fL15ExactValue $Payload.context $ExpectedContext) 'CONTEXT_BINDING'
    foreach ($value in @($RootProcessId, $WorkerProcessId, $Payload.root_process_id, $Payload.worker_process_id)) {
        Assert-QsdkR10fL15Launch (Test-QsdkR10fL15Integer $value) 'PID_TYPE_OR_RANGE'
    }
    Assert-QsdkR10fL15Launch ($Payload.root_process_id -eq $RootProcessId -and $Payload.worker_process_id -eq $WorkerProcessId) 'ENCLOSING_PIDS'
    Assert-QsdkR10fL15Launch ($Payload.started_utc -ceq $StartedUtc) 'START_BINDING'
    $started = ConvertTo-QsdkR10fL15Utc $Payload.started_utc 'STARTED'
    $observed = ConvertTo-QsdkR10fL15Utc $Payload.observed_utc 'OBSERVED'
    Assert-QsdkR10fL15Launch ($observed -ge $started) 'OBSERVATION_TIME'
    Assert-QsdkR10fL15Launch ($Payload.ready_line -is [string] -and $Payload.ready_line.StartsWith(
        [string]$ExpectedContext.ready_marker_prefix, [StringComparison]::Ordinal)) 'READY_LINE'
    $ready = ConvertFrom-QsdkR10fL15ExactJson ($Payload.ready_line.Substring($ExpectedContext.ready_marker_prefix.Length))
    Assert-QsdkR10fL15Launch (Test-QsdkR10fL15ExactValue $ready $Payload.ready_receipt) 'READY_LINE_RECEIPT'
    Assert-QsdkR10fL15Launch (Test-QsdkR10fL15ExactValue $ready $ExpectedReadyReceipt) 'ENCLOSING_READY_RECEIPT'
    Assert-QsdkR10fL15Launch (
        $ready.schema_version -is [string] -and $ready.schema_version -ceq $contract.ready_schema -and
        $ready.termination_protocol_id -is [string] -and $ready.termination_protocol_id -ceq $contract.termination_protocol_id -and
        $ready.termination_nonce -is [string] -and $ready.termination_nonce -ceq $ExpectedContext.termination_nonce -and
        (Test-QsdkR10fL15Integer $ready.process_id) -and $ready.process_id -eq $WorkerProcessId -and
        $ready.worker_receipt_emitted -is [bool] -and $ready.worker_receipt_emitted -and
        (Test-QsdkR10fL15Integer $ready.requested_exit_code -Minimum 0 -Maximum 1)
    ) 'READY_CONTRACT'
    $chain = $Payload.process_chain
    Assert-QsdkR10fL15Launch ($chain -is [System.Collections.IList] -and $chain.Count -ge 1 -and $chain.Count -le $contract.maximum_chain_nodes) 'CHAIN_LENGTH'
    $seen = [Collections.Generic.HashSet[long]]::new()
    $times = [Collections.Generic.List[DateTimeOffset]]::new()
    for ($index = 0; $index -lt $chain.Count; $index++) {
        $node = $chain[$index]
        Assert-QsdkR10fL15Keys $node @('process_id', 'parent_process_id', 'created_utc', 'executable_path') 'NODE'
        Assert-QsdkR10fL15Launch (Test-QsdkR10fL15Integer $node.process_id) 'NODE_PID'
        Assert-QsdkR10fL15Launch (Test-QsdkR10fL15Integer $node.parent_process_id -Minimum 0) 'NODE_PARENT'
        Assert-QsdkR10fL15Launch ($seen.Add([long]$node.process_id)) 'CYCLIC_CHAIN'
        Assert-QsdkR10fL15Launch ($node.executable_path -is [string] -and [IO.Path]::IsPathFullyQualified($node.executable_path)) 'NODE_IMAGE_PATH'
        $created = ConvertTo-QsdkR10fL15Utc $node.created_utc 'NODE_CREATED'
        Assert-QsdkR10fL15Launch ($created -ge $started -and $created -le $observed) 'NODE_LIFETIME'
        $times.Add($created)
        if ($index -gt 0) {
            Assert-QsdkR10fL15Launch ($chain[$index - 1].parent_process_id -eq $node.process_id) 'CHAIN_EDGE'
            Assert-QsdkR10fL15Launch ($times[$index - 1] -ge $created) 'PARENT_NEWER_THAN_CHILD'
        }
    }
    Assert-QsdkR10fL15Launch ($chain[0].process_id -eq $WorkerProcessId -and $chain[-1].process_id -eq $RootProcessId) 'CHAIN_ENDPOINTS'
    $relationship = if ($RootProcessId -eq $WorkerProcessId) { $contract.self_relationship } else { $contract.descendant_relationship }
    Assert-QsdkR10fL15Launch ($Payload.relationship -is [string] -and $Payload.relationship -ceq $relationship -and (($chain.Count -eq 1) -eq ($relationship -ceq $contract.self_relationship))) 'RELATIONSHIP'
    foreach ($endpoint in @(
        @{ node = $chain[-1]; image = $ExpectedContext.root_image },
        @{ node = $chain[0]; image = $ExpectedContext.worker_image }
    )) {
        Assert-QsdkR10fL15Launch ([string]::Equals(
            [IO.Path]::GetFullPath($endpoint.node.executable_path),
            [IO.Path]::GetFullPath($endpoint.image.path), [StringComparison]::OrdinalIgnoreCase
        )) 'ENDPOINT_IMAGE_PATH'
    }
}

function Get-QsdkR10fL15ObservedProcessNode {
    param([int]$ProcessId)
    # The only OS process lookup. It is not a native physics read.
    $process = Get-CimInstance Win32_Process -Filter "ProcessId = $ProcessId" -ErrorAction Stop
    Assert-QsdkR10fL15Launch ($null -ne $process -and [int]$process.ProcessId -eq $ProcessId) 'PROCESS_UNAVAILABLE'
    Assert-QsdkR10fL15Launch ($process.CreationDate -is [DateTime] -and -not [string]::IsNullOrEmpty([string]$process.ExecutablePath)) 'PROCESS_SOURCE_UNREADABLE'
    return [ordered]@{
        process_id = [int]$process.ProcessId
        parent_process_id = [int]$process.ParentProcessId
        created_utc = $process.CreationDate.ToUniversalTime().ToString('o')
        executable_path = [IO.Path]::GetFullPath([string]$process.ExecutablePath).Replace('\', '/')
    }
}

function Get-QsdkR10fL15LaunchRelationshipReceipt {
    param(
        [System.Collections.IDictionary]$Context, [AllowNull()]$RootProcessId,
        [AllowNull()]$WorkerProcessId, [string]$StartedUtc,
        [string]$ReadyLine, [System.Collections.IDictionary]$ReadyReceipt
    )
    $contract = Get-SporeRecoveryProcessContractV1
    Assert-QsdkR10fL15LaunchContext $Context
    Assert-QsdkR10fL15Launch (Test-QsdkR10fL15Integer $RootProcessId) 'ROOT_PID'
    Assert-QsdkR10fL15Launch (Test-QsdkR10fL15Integer $WorkerProcessId) 'WORKER_PID'
    $chain = [Collections.Generic.List[object]]::new()
    $seen = [Collections.Generic.HashSet[int]]::new()
    $cursor = [int]$WorkerProcessId
    for ($depth = 0; $depth -lt $contract.maximum_chain_nodes; $depth++) {
        Assert-QsdkR10fL15Launch ($cursor -gt 0 -and $seen.Add($cursor)) 'LIVE_CHAIN_INVALID'
        $node = Get-QsdkR10fL15ObservedProcessNode $cursor
        $chain.Add($node)
        if ($cursor -eq $RootProcessId) { break }
        $cursor = $node.parent_process_id
    }
    Assert-QsdkR10fL15Launch ($chain[-1].process_id -eq $RootProcessId) 'LIVE_ROOT_NOT_REACHED'
    # Bind actual endpoint images while the owned processes are still alive.
    foreach ($image in @($Context.root_image, $Context.worker_image)) {
        $file = Get-Item -LiteralPath $image.path -ErrorAction Stop
        $digest = 'sha256:' + (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        Assert-QsdkR10fL15Launch ($file.Length -eq $image.byte_length -and $digest -ceq $image.raw_sha256) 'LIVE_IMAGE_BINDING'
    }
    $payload = [ordered]@{
        context = $Context
        root_process_id = $RootProcessId
        worker_process_id = $WorkerProcessId
        started_utc = $StartedUtc
        observed_utc = [DateTime]::UtcNow.ToString('o')
        relationship = $(if ($RootProcessId -eq $WorkerProcessId) { $contract.self_relationship } else { $contract.descendant_relationship })
        process_chain = @($chain)
        ready_line = $ReadyLine
        ready_receipt = $ReadyReceipt
    }
    Assert-QsdkR10fL15LaunchPayload $payload $Context $RootProcessId $WorkerProcessId $StartedUtc $ReadyReceipt
    $text = $payload | ConvertTo-Json -Compress -Depth 100
    $binding = Get-QsdkR10fL15TextBinding $text
    return [ordered]@{
        schema_version = $contract.receipt_schema
        ledger_scope = [ordered]@{
            subsystem = 'recovery'
            engine_scope = 'godot_jolt'
            authority_mode = 'development_host_process_relationship'
            question_class = 'development'
        }
        ok = $true
        payload_json = $text
        payload_byte_length = $binding.byte_length
        payload_raw_sha256 = $binding.raw_sha256
        physical_acceptance_authority = $false
        release_authority = $false
    }
}

function Assert-QsdkR10fL15LaunchRelationshipReceipt {
    param(
        [AllowNull()]$Receipt, [System.Collections.IDictionary]$ExpectedContext,
        [AllowNull()]$RootProcessId, [AllowNull()]$WorkerProcessId,
        [string]$StartedUtc, [System.Collections.IDictionary]$ExpectedReadyReceipt
    )
    $contract = Get-SporeRecoveryProcessContractV1
    Assert-QsdkR10fL15Keys $Receipt @('schema_version', 'ledger_scope', 'ok', 'payload_json',
        'payload_byte_length', 'payload_raw_sha256', 'physical_acceptance_authority',
        'release_authority') 'RECEIPT'
    Assert-QsdkR10fL15Launch ($Receipt.schema_version -is [string] -and $Receipt.schema_version -ceq $contract.receipt_schema) 'RECEIPT_SCHEMA'
    Assert-QsdkR10fL15Launch (Test-QsdkR10fL15ExactValue $Receipt.ledger_scope @{
        subsystem = 'recovery'; engine_scope = 'godot_jolt'
        authority_mode = 'development_host_process_relationship'; question_class = 'development'
    }) 'RECEIPT_LEDGER_SCOPE'
    foreach ($key in @('ok', 'physical_acceptance_authority', 'release_authority')) {
        Assert-QsdkR10fL15Launch ($Receipt[$key] -is [bool] -and $Receipt[$key] -eq ($key -ceq 'ok')) ('RECEIPT_FLAG_' + $key)
    }
    Assert-QsdkR10fL15Launch ($Receipt.payload_json -is [string]) 'PAYLOAD_TEXT'
    $binding = Get-QsdkR10fL15TextBinding $Receipt.payload_json
    Assert-QsdkR10fL15Launch (Test-QsdkR10fL15Integer $Receipt.payload_byte_length -Maximum ([long]::MaxValue)) 'PAYLOAD_BYTES_TYPE'
    Assert-QsdkR10fL15Launch ($Receipt.payload_raw_sha256 -is [string] -and $binding.byte_length -eq $Receipt.payload_byte_length -and $binding.raw_sha256 -ceq $Receipt.payload_raw_sha256) 'PAYLOAD_CONTENT_ADDRESS'
    $payload = ConvertFrom-QsdkR10fL15ExactJson $Receipt.payload_json
    Assert-QsdkR10fL15LaunchPayload $payload $ExpectedContext $RootProcessId $WorkerProcessId $StartedUtc $ExpectedReadyReceipt
    return $payload
}

function New-QsdkR10fL15ProductionLaunchContext {
    param(
        [string]$ParentAttemptId, [System.Collections.IDictionary]$Descriptor,
        [string]$SourceCommit, [string]$AuthoritySha256,
        [System.Collections.IDictionary]$RuntimeBinding
    )
    # The image selection is an enclosing authority, not a field accepted
    # from the child receipt. Keep the already-selected five-image contract.
    . (Join-Path $PSScriptRoot 'qsdk_r10f_l14_runtime_binding.ps1')
    Assert-QsdkR10fL14RuntimeBinding $RuntimeBinding
    $contract = Get-SporeRecoveryProcessContractV1
    $context = [ordered]@{
        schema_version = $contract.context_schema
        parent_attempt_id = $ParentAttemptId
        child_attempt_id = $Descriptor.child_attempt_id
        role = $Descriptor.role
        source_commit = $SourceCommit
        authority_sha256 = $AuthoritySha256
        termination_nonce = $Descriptor.termination_nonce
        ready_marker_prefix = $contract.ready_marker_prefix
        root_image = $RuntimeBinding.images.godot_console
        worker_image = $RuntimeBinding.images.godot_engine
    }
    Assert-QsdkR10fL15LaunchContext $context
    return $context
}

function Assert-QsdkR10fL15ChildLaunchRelationship {
    param(
        [System.Collections.IDictionary]$Envelope,
        [System.Collections.IDictionary]$ExpectedContext
    )
    foreach ($key in @('r10f_l15_launch_relationship', 'termination_ready_receipt')) {
        Assert-QsdkR10fL15Launch ($Envelope.Contains($key)) ('ENVELOPE_MISSING_' + $key)
    }
    foreach ($key in @('role', 'child_attempt_id', 'termination_nonce')) {
        Assert-QsdkR10fL15Launch (Test-QsdkR10fL15ExactValue $Envelope[$key] $ExpectedContext[$key]) ('ENCLOSING_CHILD_' + $key)
    }
    $payload = Assert-QsdkR10fL15LaunchRelationshipReceipt `
        $Envelope.r10f_l15_launch_relationship $ExpectedContext `
        $Envelope.process_id $Envelope.worker_process_id `
        $Envelope.started_utc $Envelope.termination_ready_receipt
    $observed = ConvertTo-QsdkR10fL15Utc $payload.observed_utc 'OBSERVED'
    $completed = ConvertTo-QsdkR10fL15Utc $Envelope.completed_utc 'COMPLETED'
    Assert-QsdkR10fL15Launch ($observed -le $completed) 'OBSERVATION_AFTER_EXIT'
    Assert-QsdkR10fL15Launch (
        (Test-QsdkR10fL15Integer $Envelope.exit_code -Minimum 0 -Maximum 1) -and
        $Envelope.exit_code -eq $Envelope.termination_ready_receipt.requested_exit_code
    ) 'READY_EXIT_BINDING'
    return $payload
}

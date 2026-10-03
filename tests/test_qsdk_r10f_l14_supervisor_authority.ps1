#requires -Version 7.0
<#
Execute the supervisor's actual read-only L14 source binder and pure consumers.
Only selected AST functions are loaded. The supervisor's dispatch, operation
lock, physical launcher and evidence writers are never evaluated.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$SourceCommit)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$script:RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
if ($script:RepoRoot -cne "C:\Users\Cole\CodeStuff\games\SporeSpore") {
    throw "L14_SUPERVISOR_TEST_ROOT"
}
$path = Join-Path $script:RepoRoot "sdk/run_qsdk_r10f_continuous_passive_recovery.ps1"
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw "L14_SUPERVISOR_PARSE_ERRORS:$parseErrors" }
$names = @(
    "Assert-R10f", "Test-ExactInteger", "Test-R10fExactOrdinalPathSet",
    "Get-SingleMarkerJson", "Test-R10fExactSourceValue",
    "Assert-R10fL14ContractReceipt", "Get-L14AuthorityBindings",
    "Assert-R10fL14FrozenAuthorityBindings", "Assert-R10fL14FrozenComponentQualification"
)
foreach ($name in $names) {
    $definitions = @($ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $name
    }, $true))
    if ($definitions.Count -ne 1) { throw "L14_SUPERVISOR_FUNCTION_COUNT:$name" }
    . ([scriptblock]::Create($definitions[0].Extent.Text))
}
# Load the actual literal constants, not a separate test's copy of the hashes.
foreach ($variable in @(
    '$script:RepairId', '$script:ExpectedRepairDesignSha256',
    '$script:ExpectedBranchCompletenessAddendumSha256',
    '$script:ExpectedPredecessorPhysicalClosureSha256', '$script:AuthorityContractPython',
    '$script:ExpectedL14ComponentReceiptJson'
)) {
    $assignments = @($ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left.Extent.Text -ceq $variable
    }, $true))
    if ($assignments.Count -ne 1) { throw "L14_SUPERVISOR_CONSTANT_COUNT:$variable" }
    . ([scriptblock]::Create($assignments[0].Extent.Text))
}

$bindings = Get-L14AuthorityBindings -SourceCommit $SourceCommit
$freeze = $bindings | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100
Assert-R10fL14FrozenAuthorityBindings -Freeze $freeze -Bindings $bindings
$rejected = 0
foreach ($authority in @($bindings.Keys)) {
    foreach ($field in @($bindings[$authority].Keys)) {
        $changed = $freeze | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100
        $changed[$authority].Remove($field)
        $refused = $false
        try {
            Assert-R10fL14FrozenAuthorityBindings -Freeze $changed -Bindings $bindings
        } catch {
            if ($_.Exception.Message -cne "L14_FROZEN_AUTHORITY_BINDINGS") { throw }
            $refused = $true
        }
        if (-not $refused) { throw "L14_SUPERVISOR_MISSING_FIELD_ACCEPTED:$authority/$field" }
        $rejected++
    }
    foreach ($mutation in @("missing_authority", "floating_count", "boolean_count", "extra_permission")) {
        $changed = $freeze | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100
        switch ($mutation) {
            "missing_authority" { $changed.Remove($authority) }
            "floating_count" { $changed[$authority].byte_length = [double]$changed[$authority].byte_length }
            "boolean_count" { $changed[$authority].byte_length = $true }
            "extra_permission" { $changed[$authority].physical_execution_authorized = $true }
        }
        $refused = $false
        try {
            Assert-R10fL14FrozenAuthorityBindings -Freeze $changed -Bindings $bindings
        } catch {
            if ($_.Exception.Message -cne "L14_FROZEN_AUTHORITY_BINDINGS") { throw }
            $refused = $true
        }
        if (-not $refused) { throw "L14_SUPERVISOR_AUTHORITY_MUTATION_ACCEPTED:$authority/$mutation" }
        $rejected++
    }
}

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r10f_l14_authority_contract_receipt_v1"
    gate_id = "QSDK-R10F"
    repair_id = $script:RepairId
    command = "authority-bindings"
    source_commit = $SourceCommit
    ok = $true
    binding = $bindings
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    scene_tree_insertion_count = 0
    native_readback_count = 0
    solver_step_count = 0
    physics_state_modified = $false
    physical_execution_authorized = $false
    physical_acceptance_authority = $false
    release_authority = $false
}
Assert-R10fL14ContractReceipt -Receipt $receipt -SourceCommit $SourceCommit
$receiptRejected = 0
foreach ($key in @($receipt.Keys)) {
    $changed = $receipt | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100
    $changed.Remove($key)
    $refused = $false
    try { Assert-R10fL14ContractReceipt -Receipt $changed -SourceCommit $SourceCommit } catch { $refused = $true }
    if (-not $refused) { throw "L14_SUPERVISOR_RECEIPT_MISSING_ACCEPTED:$key" }
    $receiptRejected++
}
foreach ($key in @(
    "model_construction_count", "world_attempt_count", "world_build_count",
    "scene_tree_insertion_count", "native_readback_count", "solver_step_count"
)) {
    foreach ($replacement in @([double]0, $false, 1)) {
        $changed = $receipt | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100
        $changed[$key] = $replacement
        $refused = $false
        try { Assert-R10fL14ContractReceipt -Receipt $changed -SourceCommit $SourceCommit } catch { $refused = $true }
        if (-not $refused) { throw "L14_SUPERVISOR_COUNTER_MUTATION_ACCEPTED:$key" }
        $receiptRejected++
    }
}
foreach ($key in @("physics_state_modified", "physical_execution_authorized", "physical_acceptance_authority", "release_authority")) {
    foreach ($replacement in @($true, 0, "false")) {
        $changed = $receipt | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100
        $changed[$key] = $replacement
        $refused = $false
        try { Assert-R10fL14ContractReceipt -Receipt $changed -SourceCommit $SourceCommit } catch { $refused = $true }
        if (-not $refused) { throw "L14_SUPERVISOR_CLAIM_MUTATION_ACCEPTED:$key" }
        $receiptRejected++
    }
}
$wrongSource = if ($SourceCommit -ceq ("1" * 40)) { "2" * 40 } else { "1" * 40 }
$refused = $false
try { Assert-R10fL14ContractReceipt -Receipt $receipt -SourceCommit $wrongSource } catch { $refused = $true }
if (-not $refused) { throw "L14_SUPERVISOR_WRONG_SOURCE_ACCEPTED" }
$receiptRejected++

# Source fixtures arrive over stdin; no temporary report or authority is made.
$componentFixtures = [Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable -Depth 100
if ($componentFixtures.corruptions.Count -ne 176) { throw "L14_COMPONENT_FIXTURE_COUNT" }
$launch = @($ast.FindAll({ param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -ceq "Get-PhysicalAuthority"
}, $true))
if ($launch.Count -ne 1 -or
    -not $launch[0].Body.Extent.Text.Contains('Assert-R10fL14FrozenComponentQualification -Document $authority') -or
    -not $launch[0].Body.Extent.Text.Contains('Assert-R10fL14FrozenComponentQualification -Document $freeze')) {
    throw "L14_COMPONENT_GUARD_NOT_IN_ACTUAL_LAUNCH_CONSUMER"
}
$componentPositives = 0; $componentRejections = 0
foreach ($authorityName in @("authority", "freeze")) {
    $document = @{ l14_component_qualification = $componentFixtures.positive }
    Assert-R10fL14FrozenComponentQualification -Document $document -AuthorityName $authorityName
    $componentPositives++
    foreach ($case in @(@{ id = "missing_component"; receipt = $null }) + @($componentFixtures.corruptions)) {
        $document = @{}
        if ($null -ne $case.receipt) { $document.l14_component_qualification = $case.receipt }
        $refused = $false
        try { Assert-R10fL14FrozenComponentQualification -Document $document -AuthorityName $authorityName }
        catch {
            if ($_.Exception.Message -cne ("L14_FROZEN_COMPONENT_QUALIFICATION:" + $authorityName)) { throw }
            $refused = $true
        }
        if (-not $refused) { throw "L14_COMPONENT_LAUNCH_MUTATION_ACCEPTED:$authorityName/$($case.id)" }
        $componentRejections++
    }
}
if ($componentPositives -ne 2 -or $componentRejections -ne 354) {
    throw "L14_COMPONENT_LAUNCH_CONTROL_COUNTS"
}

$result = [ordered]@{
    schema_version = "sporespore_qsdk_r10f_l14_supervisor_authority_zero_world_v1"
    gate_id = "QSDK-R10F"
    repair_id = $script:RepairId
    ledger_scope = [ordered]@{
        subsystem = "recovery"
        engine_scope = "godot_jolt"
        authority_mode = "actual_supervisor_ast_source_binding_and_pure_consumers"
        question_class = "development"
    }
    ok = $true
    loaded_actual_function_count = $names.Count
    source_commit = $SourceCommit
    bindings = $bindings
    positive_control_count = 3
    frozen_binding_mutation_rejection_count = $rejected
    contract_receipt_mutation_rejection_count = $receiptRejected
    component_qualification_positive_count = $componentPositives
    component_qualification_mutation_rejection_count = $componentRejections
    component_guard_called_by_actual_physical_authority_consumer = $true
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    scene_tree_insertion_count = 0
    native_readback_count = 0
    solver_step_count = 0
    physics_state_modified = $false
    physical_execution_authorized = $false
    physical_acceptance_authority = $false
    release_authority = $false
}
Write-Output ("QSDK_R10F_L14_SUPERVISOR_AUTHORITY_ZERO_WORLD_PASS " + ($result | ConvertTo-Json -Depth 100 -Compress))

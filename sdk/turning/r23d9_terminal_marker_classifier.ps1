#requires -Version 7.0

Set-StrictMode -Version Latest

function Assert-R23D9MarkerCondition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D9MarkerFamilyDefinition {
    param([Parameter(Mandatory)][string]$FamilyId)
    switch -CaseSensitive ($FamilyId) {
        "mujoco_single_terminal_prefix" {
            return [ordered]@{
                family_id = $FamilyId
                single_prefix = "QSDK_R23D9_TERMINAL "
                success_prefix = ""
                failure_prefix = ""
            }
        }
        "rapier_single_terminal_prefix" {
            return [ordered]@{
                family_id = $FamilyId
                single_prefix = "QSDK_R23D9_RAPIER_TERMINAL "
                success_prefix = ""
                failure_prefix = ""
            }
        }
        "godot_jolt_single_terminal_prefix" {
            return [ordered]@{
                family_id = $FamilyId
                single_prefix = "QSDK_R23D9_GODOT_JOLT_TERMINAL "
                success_prefix = ""
                failure_prefix = ""
            }
        }
        default { throw "QSDK-R23D9 unknown terminal marker family: $FamilyId" }
    }
}

function Assert-R23D9MarkerRetention {
    param([Parameter(Mandatory)]$RetentionReceipt)
    $shaPattern = '^sha256:[0-9a-f]{64}$'
    Assert-R23D9MarkerCondition (
        [string]$RetentionReceipt.schema_version -ceq
            "sporespore_qsdk_r23d9_process_retention_receipt_v1" -and
        [bool]$RetentionReceipt.retained_before_marker_interpretation -and
        [string]$RetentionReceipt.process_raw_sha256 -cmatch $shaPattern -and
        [string]$RetentionReceipt.stdout_raw_sha256 -cmatch $shaPattern -and
        [string]$RetentionReceipt.stderr_raw_sha256 -cmatch $shaPattern -and
        (
            -not [bool]$RetentionReceipt.engine_log_required -or
            [string]$RetentionReceipt.engine_log_raw_sha256 -cmatch $shaPattern
        ) -and
        [bool]$RetentionReceipt.all_retained_bytes_content_addressed
    ) "QSDK-R23D9 marker interpretation forbidden before complete retention"
}

function New-R23D9MarkerClassification {
    param(
        [string]$FamilyId,
        [string]$Classification,
        [string]$FailureCode,
        [int]$RecognizedMarkerCount,
        [int]$SuccessMarkerCount,
        [int]$FailureMarkerCount,
        [int]$MalformedMarkerCount,
        $Entry = $null
    )
    return [ordered]@{
        schema_version = "sporespore_qsdk_r23d9_terminal_marker_classifier_v1"
        family_id = $FamilyId
        classification = $Classification
        failure_code = $FailureCode
        recognized_marker_count = $RecognizedMarkerCount
        success_marker_count = $SuccessMarkerCount
        failure_marker_count = $FailureMarkerCount
        malformed_marker_count = $MalformedMarkerCount
        terminal_entry = $Entry
        physical_acceptance_authority = $false
    }
}

function Get-R23D9TerminalMarkerClassification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FamilyId,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Stdout,
        [Parameter(Mandatory)][int]$ExitCode,
        [Parameter(Mandatory)]$RetentionReceipt
    )

    Assert-R23D9MarkerRetention $RetentionReceipt
    $definition = Get-R23D9MarkerFamilyDefinition $FamilyId
    $reportSchema = "sporespore_qsdk_r23d9_engine_cell_report_v1"
    $failureSchema = "sporespore_qsdk_r23d9_worker_failure_v1"
    $lines = @($Stdout -split "`r?`n")
    $successEntries = [Collections.Generic.List[object]]::new()
    $failureEntries = [Collections.Generic.List[object]]::new()
    $malformedCount = 0

    $terminalLines = @($lines | Where-Object {
        $_.StartsWith(
            [string]$definition.single_prefix,
            [StringComparison]::Ordinal
        )
    })
    foreach ($line in $terminalLines) {
        try {
            $entry = $line.Substring(
                ([string]$definition.single_prefix).Length
            ) | ConvertFrom-Json -AsHashtable -Depth 100
            if ([string]$entry.schema_version -ceq $reportSchema) {
                $successEntries.Add($entry)
            } elseif ([string]$entry.schema_version -ceq $failureSchema) {
                $failureEntries.Add($entry)
            } else {
                $malformedCount += 1
            }
        } catch {
            $malformedCount += 1
        }
    }
    $recognizedCount = $terminalLines.Count
    $successCount = $successEntries.Count
    $failureCount = $failureEntries.Count

    if ($recognizedCount -eq 0) {
        return New-R23D9MarkerClassification $FamilyId `
            "supervisor_process_failure" "R23D9_TERMINAL_MARKER_ZERO" `
            0 0 0 0
    }
    if ($malformedCount -gt 0) {
        return New-R23D9MarkerClassification $FamilyId `
            "supervisor_process_failure" "R23D9_TERMINAL_MARKER_MALFORMED" `
            $recognizedCount $successCount $failureCount $malformedCount
    }
    if ($successCount -gt 0 -and $failureCount -gt 0) {
        return New-R23D9MarkerClassification $FamilyId `
            "supervisor_process_failure" "R23D9_TERMINAL_MARKER_MIXED" `
            $recognizedCount $successCount $failureCount 0
    }
    if ($recognizedCount -ne 1 -or ($successCount + $failureCount) -ne 1) {
        return New-R23D9MarkerClassification $FamilyId `
            "supervisor_process_failure" "R23D9_TERMINAL_MARKER_MANY" `
            $recognizedCount $successCount $failureCount 0
    }
    if ($successCount -eq 1) {
        if ($ExitCode -ne 0) {
            return New-R23D9MarkerClassification $FamilyId `
                "supervisor_process_failure" "R23D9_TERMINAL_EXIT_MARKER_MISMATCH" `
                1 1 0 0 $successEntries[0]
        }
        return New-R23D9MarkerClassification $FamilyId `
            "success" "" 1 1 0 0 $successEntries[0]
    }
    if ($ExitCode -eq 0) {
        return New-R23D9MarkerClassification $FamilyId `
            "supervisor_process_failure" "R23D9_TERMINAL_EXIT_MARKER_MISMATCH" `
            1 0 1 0 $failureEntries[0]
    }
    return New-R23D9MarkerClassification $FamilyId `
        "worker_failure" ([string]$failureEntries[0].failure_code) `
        1 0 1 0 $failureEntries[0]
}

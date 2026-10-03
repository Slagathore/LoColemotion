#requires -Version 7.0

Set-StrictMode -Version Latest

function Test-Xv2WorkerPreflightProjection {
    param(
        [Parameter(Mandatory)][ValidateSet("rapier", "mujoco")][string]$Engine,
        [Parameter(Mandatory)][object]$WorkerReport
    )

    $requiredSections = if ($Engine -ceq "rapier") {
        @("preflight")
    }
    else {
        @(
            "preworld_real_controller_trace_projection_canary",
            "preworld_engine_neutral_terminal_restoration_canary",
            "preworld_production_kinematic_vector_representation_canary",
            "preworld_material_xml_authoring_canary",
            "preworld_shared_report_assembler_authority_schema_canary"
        )
    }
    foreach ($sectionName in $requiredSections) {
        $section = Get-Xv2MapValue $WorkerReport $sectionName $null
        if ($section -isnot [System.Collections.IDictionary]) {
            return $false
        }
        $ok = Get-Xv2MapValue $section "ok" $null
        if ($ok -isnot [bool] -or -not [bool]$ok) {
            return $false
        }
    }
    return $true
}

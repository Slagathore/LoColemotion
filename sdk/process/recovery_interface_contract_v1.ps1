# Generated from sdk/core/contracts/recovery_interfaces_v1.json; do not edit.
function Get-SporeRecoveryProcessContractV1 {
    return [ordered]@{
        context_schema = 'sporespore_qsdk_r10f_l15_launch_context_v1'
        receipt_schema = 'sporespore_qsdk_r10f_launch_relationship_receipt_v1'
        ready_schema = 'sporespore_godot_supervised_termination_ready_v1'
        termination_protocol_id = 'godot_4_7_gdscript_shutdown_containment_v1'
        ready_marker_prefix = 'QSDK_R10F_CONTINUOUS_PASSIVE_RECOVERY_READY '
        roles = @('matched_no_kick_continuation', 'kick_passive_recovery_resume')
        self_relationship = 'self'
        descendant_relationship = 'descendant'
        maximum_chain_nodes = 17
    }
}

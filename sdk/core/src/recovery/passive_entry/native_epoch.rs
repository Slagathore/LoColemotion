//! Exact global-offset arithmetic used by the production Godot energy epoch.
//! No tolerance, residual balancing, new energy zero, or reconstructed work.
use super::*;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RecoveryPassiveNativeEnergyTotalsV1 {
    /// Digest of the original global source receipt, retained by the host.
    pub source_values_sha256: String,
    pub cumulative_applied_actuator_work_j: f64,
    pub cumulative_signed_external_work_j: f64,
    pub cumulative_signed_constraint_exchange_j: f64,
    pub cumulative_passive_dissipation_j: f64,
}

impl RecoveryPassiveNativeEnergyTotalsV1 {
    fn values(&self) -> [f64; 4] {
        [
            self.cumulative_applied_actuator_work_j,
            self.cumulative_signed_external_work_j,
            self.cumulative_signed_constraint_exchange_j,
            self.cumulative_passive_dissipation_j,
        ]
    }

    fn validate(&self) -> Result<()> {
        require_digest(
            &self.source_values_sha256,
            "passive_entry_global_source_digest",
        )?;
        require(
            self.values().iter().all(|v| v.is_finite())
                && self.cumulative_passive_dissipation_j >= 0.0,
            "passive_entry_global_source_nonfinite_or_negative",
        )
    }
}

fn local_values(ledger: &RecoveryEnergyBalanceLedgerV3) -> [f64; 4] {
    [
        ledger.cumulative_applied_actuator_work_j,
        ledger.cumulative_signed_external_work_j,
        ledger.cumulative_signed_constraint_exchange_j,
        ledger.cumulative_passive_dissipation_j,
    ]
}

pub(super) fn validate_projection(request: &RecoveryPassiveEntryStepRequestV1) -> Result<bool> {
    let declaration = &request.declaration;
    let prior_global = request
        .prior
        .as_ref()
        .and_then(|v| v.last_native_global_energy.as_ref());
    let Some(boundary) = &declaration.native_global_energy_at_boundary else {
        require(
            request.native_global_energy.is_none() && prior_global.is_none(),
            "passive_entry_global_projection_undeclared",
        )?;
        return Ok(false);
    };
    require(
        declaration.initialization.adapter_capability.engine
            == RecoveryNativeEngineV1::GodotJolt4_7
            && request.observation.engine_step_identity.source_kind
                == RecoveryObservationSourceKindV1::NativePostStep
            && declaration.energy_partition_authority.is_some(),
        "passive_entry_global_projection_native_identity",
    )?;
    let current = request
        .native_global_energy
        .as_ref()
        .ok_or_else(|| CoreError::Frame("passive_entry_global_source_missing".to_owned()))?;
    let previous = if request.prior.is_some() {
        prior_global.ok_or_else(|| {
            CoreError::Frame("passive_entry_prior_global_source_missing".to_owned())
        })?
    } else {
        boundary
    };
    boundary.validate()?;
    previous.validate()?;
    current.validate()?;
    let boundary_ledger = &declaration.energy_at_boundary;
    require(
        local_values(boundary_ledger)
            .iter()
            .all(|v| v.to_bits() == 0.0f64.to_bits())
            && boundary_ledger
                .cumulative_signed_discrete_staging_exchange_j
                .to_bits()
                == 0.0f64.to_bits()
            && boundary_ledger.initial_mechanical_energy_j.to_bits()
                == boundary_ledger.current_mechanical_energy_j.to_bits()
            && declaration.energy_boundary_sequence_index == 0,
        "passive_entry_native_boundary_not_epoch_zero",
    )?;
    let previous_ledger = request
        .prior
        .as_ref()
        .map_or(boundary_ledger, |v| &v.last_energy_ledger);
    validate_global_projection(boundary, previous, current, previous_ledger,
        &request.observation.energy_balance, &request.energy_increment)?;
    Ok(true)
}

/// Reuse the exact global-offset arithmetic after a distinct task handoff.
/// This kernel changes neither the original offset nor any source observation.
pub(crate) fn validate_global_projection(
    boundary: &RecoveryPassiveNativeEnergyTotalsV1,
    previous: &RecoveryPassiveNativeEnergyTotalsV1,
    current: &RecoveryPassiveNativeEnergyTotalsV1,
    previous_ledger: &RecoveryEnergyBalanceLedgerV3,
    current_ledger: &RecoveryEnergyBalanceLedgerV3,
    increment: &RecoveryEnergyWorkIncrementV3,
) -> Result<()> {
    boundary.validate()?;
    previous.validate()?;
    current.validate()?;
    let old_local = local_values(previous_ledger);
    let new_local = local_values(current_ledger);
    let offsets = boundary.values();
    let old_global = previous.values();
    let new_global = current.values();
    let deltas = [
        increment.applied_actuator_work_j,
        increment.signed_external_work_j,
        increment.signed_constraint_exchange_j,
        increment.passive_dissipation_j,
    ];
    for index in 0..4 {
        require(
            deltas[index].is_finite()
                && (old_global[index] + deltas[index]).to_bits() == new_global[index].to_bits()
                && (old_global[index] - offsets[index]).to_bits() == old_local[index].to_bits()
                && (new_global[index] - offsets[index]).to_bits() == new_local[index].to_bits(),
            "passive_entry_global_increment_or_projection_discontinuity",
        )?;
    }
    Ok(())
}

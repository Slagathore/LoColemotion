use rapier3d::prelude::*;

use crate::RAPIER_DT_S;

/// SPV1-validated active Rapier solver configuration.
///
/// These values apply to current adapter conformance and locomotion worlds.
/// Closed FB1/LR1/CW1/SPD1/SPV1 campaign modules retain their own frozen
/// experiment-local configurations.
pub const RAPIER_ACTIVE_SOLVER_ITERATIONS: usize = 16;
pub const RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS: usize = 3;
pub const RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS: usize = 5;

pub(crate) fn new_active_world(gravity: Vector) -> PhysicsWorld {
    let mut world = PhysicsWorld::new();
    world.gravity = gravity;
    world.integration_parameters.dt = RAPIER_DT_S;
    world.integration_parameters.length_unit = 1.0;
    world.integration_parameters.num_solver_iterations = RAPIER_ACTIVE_SOLVER_ITERATIONS;
    world.integration_parameters.num_internal_pgs_iterations =
        RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS;
    world
        .integration_parameters
        .num_internal_stabilization_iterations = RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS;
    world
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn active_world_reads_back_the_spv1_validated_configuration() {
        let gravity = Vector::new(1.0, -9.8, 2.0);
        let world = new_active_world(gravity);

        assert_eq!(world.gravity, gravity);
        assert_eq!(world.integration_parameters.dt, RAPIER_DT_S);
        assert_eq!(world.integration_parameters.length_unit, 1.0);
        assert_eq!(
            world.integration_parameters.num_solver_iterations,
            RAPIER_ACTIVE_SOLVER_ITERATIONS
        );
        assert_eq!(
            world.integration_parameters.num_internal_pgs_iterations,
            RAPIER_ACTIVE_INTERNAL_PGS_ITERATIONS
        );
        assert_eq!(
            world
                .integration_parameters
                .num_internal_stabilization_iterations,
            RAPIER_ACTIVE_INTERNAL_STABILIZATION_ITERATIONS
        );
    }
}

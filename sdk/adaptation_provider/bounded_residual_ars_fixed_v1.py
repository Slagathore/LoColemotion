"""Complete-population ARS updates with the deployed input scaling frozen."""
from dataclasses import replace
from . import bounded_residual_ars_v1 as ars


def tell(batch,rollouts):
    # Preserve the original validator, paired update and every observed moment.
    # The intermediate V2-style normalizer is diagnostic, never deployed here.
    intermediate,original=ars.tell(batch,rollouts)
    result=replace(intermediate,moments=batch.policy.moments)
    result.validate()
    return result,dict(schema_version="locolemotion_fixed_normalizer_ars_update_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",
            authority_mode="development_training_component",question_class="development"),
        previous_policy_sha256=batch.policy.sha256,next_policy_sha256=result.sha256,
        underlying_update=original,observed_moments=intermediate.moments.__dict__,
        deployed_moments=result.moments.__dict__,normalizer_updated=False,
        weights_updated_online=False,base_policy_mutated=False,
        world_build_count=0,solver_steps=0,physical_acceptance_authority=False,release_authority=False)

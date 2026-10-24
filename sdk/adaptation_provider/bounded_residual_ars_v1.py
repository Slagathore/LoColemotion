"""Pure, immutable augmented random-search updates for bounded residual policies.

Algorithmic basis: Mania, Guy and Recht (2018), Algorithm 2.
This component has no world access, file I/O, qualification or launch authority.
The caller must bind the actual rollout, training population and reward contract.
"""
from dataclasses import dataclass
import hashlib
import json
import math
import random


def require(condition, message):
    if not condition:
        raise ValueError(message)


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def vector(values, length, name):
    require(isinstance(values, (list, tuple)) and len(values) == length
            and all(finite(x) for x in values), name)
    return tuple(float(x) for x in values)


def digest(value):
    raw = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")
    return "sha256:" + hashlib.sha256(raw).hexdigest()


@dataclass(frozen=True)
class Moments:
    """Population moments; each state counts once, including failed training runs."""
    count: int
    mean: tuple
    m2: tuple

    @classmethod
    def empty(cls, dimension):
        require(type(dimension) is int and dimension > 0, "Moment dimension")
        return cls(0, (0.,)*dimension, (0.,)*dimension)

    def validate(self):
        require(type(self.count) is int and self.count >= 0 and isinstance(self.mean,tuple)
                and isinstance(self.m2,tuple) and len(self.mean) > 0,
                "Moment count/dimension")
        vector(self.mean, len(self.mean), "Moment mean")
        vector(self.m2, len(self.mean), "Moment second moment")
        require(all(v >= 0 for v in self.m2), "Negative second moment")
        require(self.count != 0 or not any(self.mean + self.m2), "Empty moment values")
        require(self.count != 1 or not any(self.m2), "Singleton second moment")

    def add(self, observations, *, partition):
        require(partition == "training", "Only training observations may update moments")
        self.validate()
        n, mean, m2 = self.count, list(self.mean), list(self.m2)
        for observation in observations:
            row = vector(observation, len(mean), "Observation dimensions/finiteness")
            n += 1
            for j, x in enumerate(row):
                delta = x - mean[j]
                mean[j] += delta/n
                m2[j] += delta*(x-mean[j])
        result = Moments(n, tuple(mean), tuple(m2))
        result.validate()
        return result

    def merge(self, other):
        self.validate(); other.validate()
        require(len(self.mean) == len(other.mean), "Crossed moment dimensions")
        if not self.count: return other
        if not other.count: return self
        n = self.count + other.count
        delta = [b-a for a,b in zip(self.mean, other.mean, strict=True)]
        mean = tuple(a+d*other.count/n for a,d in zip(self.mean, delta, strict=True))
        m2 = tuple(a+b+d*d*(self.count*other.count/n)
                   for a,b,d in zip(self.m2, other.m2, delta, strict=True))
        result = Moments(n, mean, m2)
        result.validate()
        return result

    def normalize(self, observation, variance_floor):
        self.validate()
        require(finite(variance_floor) and variance_floor > 0, "Variance floor")
        row = vector(observation, len(self.mean), "Policy observation")
        if self.count == 0: return row  # Initial identity normalization.
        # A constant training coordinate carries no normalized information.
        # This is not an OOD check; a separate support gate must own refusal.
        result = tuple((x-m)/math.sqrt(s/self.count) if s/self.count >= variance_floor else 0.
                       for x,m,s in zip(row, self.mean, self.m2, strict=True))
        return vector(result, len(row), "Finite normalized observation")


@dataclass(frozen=True)
class Policy:
    """Immutable linear map followed by bounded tanh, in canonical output units."""
    weights: tuple
    moments: Moments
    output_limits: tuple
    variance_floor: float

    def validate(self):
        self.moments.validate()
        require(isinstance(self.weights,tuple) and isinstance(self.output_limits,tuple)
                and all(isinstance(row,tuple) for row in self.weights)
                and len(self.weights) > 0 and len(self.weights) == len(self.output_limits),
                "Policy output dimensions")
        for row in self.weights: vector(row, len(self.moments.mean), "Policy weights")
        vector(self.output_limits, len(self.weights), "Policy limits")
        require(all(v > 0 for v in self.output_limits), "Positive output limits")
        require(finite(self.variance_floor) and self.variance_floor > 0, "Variance floor")

    def document(self):
        self.validate()
        return dict(schema_version="locolemotion_bounded_residual_policy_component_v1",
                    weights=self.weights, mean=self.moments.mean, m2=self.moments.m2,
                    count=self.moments.count, output_limits=self.output_limits,
                    variance_floor=self.variance_floor)

    @property
    def sha256(self):
        return digest(self.document())

    def action(self, observation):
        self.validate()
        z = self.moments.normalize(observation, self.variance_floor)
        sums = [math.fsum(w*x for w,x in zip(row,z,strict=True)) for row in self.weights]
        require(all(math.isfinite(v) for v in sums), "Nonfinite policy activation")
        return tuple(limit*math.tanh(v) for limit,v in zip(self.output_limits,sums,strict=True))


@dataclass(frozen=True)
class Plan:
    iteration: int
    seed: int
    groups: tuple
    directions: int
    selected_directions: int
    noise_scale: float
    step_size: float

    def validate(self):
        require(type(self.iteration) is int and self.iteration >= 0, "Iteration")
        require(type(self.seed) is int and 0 <= self.seed < 2**64, "Seed")
        require(isinstance(self.groups, tuple) and len(self.groups) > 0
                and all(isinstance(g,str) and g for g in self.groups)
                and len(set(self.groups)) == len(self.groups), "Training groups")
        require(type(self.directions) is int and type(self.selected_directions) is int
                and 1 <= self.selected_directions <= self.directions, "Direction counts")
        require(finite(self.noise_scale) and self.noise_scale > 0
                and finite(self.step_size) and self.step_size > 0, "Positive step/noise")


@dataclass(frozen=True)
class Batch:
    policy: Policy
    plan: Plan
    perturbations: tuple

    @property
    def sha256(self):
        return digest(dict(schema_version="locolemotion_bounded_residual_ars_batch_v1",
                           policy=self.policy.sha256, plan=self.plan.__dict__,
                           perturbations=self.perturbations))

    def candidate(self, direction, sign):
        require(type(direction) is int and 0 <= direction < self.plan.directions
                and type(sign) is int and sign in (-1,1), "Perturbation index/sign")
        delta = self.perturbations[direction]
        weights = tuple(tuple(w + sign*self.plan.noise_scale*d for w,d in zip(row,dr,strict=True))
                        for row,dr in zip(self.policy.weights,delta,strict=True))
        result = Policy(weights,self.policy.moments,self.policy.output_limits,self.policy.variance_floor)
        result.validate()
        return result

    def identities(self):
        return tuple((direction,sign,group)
                     for direction in range(self.plan.directions)
                     for sign in (1,-1) for group in self.plan.groups)


def ask(policy, plan):
    policy.validate(); plan.validate()
    # Store all perturbation bytes in the batch: a seed alone is not a replay artifact.
    rng = random.Random(plan.seed)
    directions = tuple(tuple(tuple(rng.gauss(0.,1.) for _ in policy.moments.mean)
                             for _ in policy.weights) for _ in range(plan.directions))
    result = Batch(policy,plan,directions)
    for i in range(plan.directions):
        for sign in (1,-1): result.candidate(i,sign)
    return result


@dataclass(frozen=True)
class Rollout:
    batch_sha256: str
    policy_sha256: str
    direction: int
    sign: int
    group: str
    partition: str
    trial_id: str
    reward: float
    observations: Moments


def tell(batch, rollouts):
    """Consume exactly one complete balanced population; return a new model and audit.

    Rewards here are a separately declared training objective, never substituted
    for censored official episode quality. Failed-but-valid training rollouts
    must still supply their declared reward and observations. Missing/invalid
    rollouts reject the entire update rather than shrinking its denominator.
    """
    batch.policy.validate(); batch.plan.validate()
    require(batch == ask(batch.policy,batch.plan), "Batch perturbations changed")
    expected = batch.identities()
    require(len(rollouts) == len(expected), "Incomplete rollout population")
    rows = {}
    trial_ids = set()
    moments = batch.policy.moments
    for item in rollouts:
        key = (item.direction,item.sign,item.group)
        require(type(item.direction) is int and type(item.sign) is int
                and key in expected and key not in rows, "Duplicate/crossed rollout")
        require(item.partition == "training", "Reserved data cannot enter training")
        require(isinstance(item.trial_id,str) and item.trial_id and item.trial_id not in trial_ids,
                "Duplicate/missing trial identity")
        require(item.batch_sha256 == batch.sha256
                and item.policy_sha256 == batch.candidate(item.direction,item.sign).sha256,
                "Crossed batch/policy identity")
        require(finite(item.reward), "Nonfinite training reward")
        item.observations.validate()
        require(item.observations.count > 0, "Missing training observations")
        rows[key] = item; trial_ids.add(item.trial_id)
    # Canonical order makes arrival order irrelevant; every direction contributes
    # state statistics, even when its reward does not enter the top-b update.
    for key in expected: moments = moments.merge(rows[key].observations)
    rewards = []
    for i in range(batch.plan.directions):
        rewards.append(tuple(math.fsum(rows[i,s,g].reward/len(batch.plan.groups)
                                       for g in batch.plan.groups) for s in (1,-1)))
    require(all(finite(v) for pair in rewards for v in pair), "Nonfinite group reward")
    selected = sorted(range(len(rewards)),key=lambda i:(-max(rewards[i]),i))[:batch.plan.selected_directions]
    chosen = [v for i in selected for v in rewards[i]]
    # Scale before computing variance to avoid squaring huge finite rewards.
    scale = max(abs(v) for v in chosen)
    scaled = [v/scale for v in chosen] if scale else chosen
    center = math.fsum(v/len(scaled) for v in scaled)
    sigma = math.sqrt(math.fsum((v-center)**2/len(scaled) for v in scaled))
    if sigma == 0:
        weights = batch.policy.weights
    else:
        coefficients = {i:batch.plan.step_size/len(selected)
                        *((rewards[i][0]/scale-rewards[i][1]/scale)/sigma) for i in selected}
        weights = tuple(tuple(w + math.fsum(coefficients[i]*batch.perturbations[i][a][j] for i in selected)
                              for j,w in enumerate(row)) for a,row in enumerate(batch.policy.weights))
    result = Policy(weights,moments,batch.policy.output_limits,batch.policy.variance_floor)
    result.validate()
    audit = dict(schema_version="locolemotion_bounded_residual_ars_update_v1",
                 ledger_scope=dict(subsystem="adaptation",engine_scope="core",
                                   authority_mode="development_training_component",question_class="development"),
                 iteration=batch.plan.iteration,batch_sha256=batch.sha256,
                 previous_policy_sha256=batch.policy.sha256,next_policy_sha256=result.sha256,
                 rollout_count=len(rollouts),training_groups=list(batch.plan.groups),
                 ordered_trial_ids=[rows[k].trial_id for k in expected],
                 paired_mean_rewards=rewards,selected_directions=selected,
                 reward_scale=scale,scaled_reward_standard_deviation=sigma,
                 zero_reward_variance=sigma==0,normalizer_sample_count=moments.count,
                 base_policy_mutated=False,world_build_count=0,solver_steps=0,
                 physical_acceptance_authority=False,release_authority=False)
    return result,audit

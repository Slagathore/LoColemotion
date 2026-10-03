"""Explain retained R10AI planner refusals without modifying control or physics."""
import argparse
from collections import Counter
import json
import math
from pathlib import Path

import r10ai_concurrent_load_rise_closure as closure
import r10ai_geometry_reference as reference

G = reference.geometry
RECORD = closure.ROOT/'sdk/recovery/r10ai_stall_diagnosis_v1.json'
CLAIMS = dict(world_build_count=0, solver_step_count=0, original_result_regraded=False,
    controller_changed=False, physical_execution_authorized=False,
    physical_acceptance_authority=False, release_authority=False)


def first_refusal(model, targets, position, rotation):
    """First violated constraint in production limb order, not every constraint.

    Independently reconstruct the admissibility branches. Each result is also
    checked against the existing independent geometry solver on the same input.
    """
    for i, target in enumerate(targets):
        local = G.sub(G.rotate(G.inverse(rotation), G.sub(target,position)),model.hip(i))
        if abs(local[2]) > .0005: return f'{i}:lateral'
        cosine = (local[0]**2+local[1]**2-model.upper**2-model.lower**2)/(2*model.upper*model.lower)
        if not -1 <= cosine <= 1: return f'{i}:reach'
        angle, within_limits, allowed = math.acos(cosine), False, False
        for knee in (angle,-angle):
            hip = math.atan2(local[0],-local[1])-math.atan2(model.lower*math.sin(knee),model.upper+model.lower*math.cos(knee))
            if abs(hip) > 1.6 or abs(knee) > 1.1: continue
            within_limits = True
            if max(abs(hip-model.measured[2*i]),abs(knee-model.measured[2*i+1])) <= 4*G.DT:
                allowed = True
        if not allowed: return f'{i}:' + ('speed' if within_limits else 'joint_limit')
    return 'feasible'


def derive():
    report = closure.CHILD/'worker_report.json'
    assert closure.bind(report)['raw_sha256'] == closure.REPORT_SHA
    rows, reasons, mode_changes = [], Counter(), []
    previous_mode = None
    for packet in closure.geometry.records(report,'r10ai_partial_recovery','step_packets'):
        plan = packet['native_receipt']['next_load_plan']
        if plan is None: continue
        request = json.loads(packet['call']['request']['utf8_text'])
        observation, descriptor = request['step']['observation'],request['collection']['descriptor']
        parity = reference.verify(observation,descriptor,plan)
        snapshot = closure.streams.diagnosis.snapshot(packet)
        mode = plan['mode']; counts = Counter()
        if mode != previous_mode:
            mode_changes.append(dict(partial_step=snapshot['partial_step'],mode=mode)); previous_mode=mode
        if mode == 'explicit_v23_fallback':
            rebuilt = reference.search(observation,descriptor); model = rebuilt['model']
            assert rebuilt['feasible'] == 0 and rebuilt['selected'] is None
            assert plan['concurrent_geometry']['hold_reason'] == 'no_feasible_cost_decreasing_candidate'
            for scale in G.SCALES:
                distance = .1*G.DT*scale
                for dx in (-distance,0.,distance):
                    for dy in (-distance,0.,distance):
                        for fraction in (-.6*G.DT*scale,0.,.6*G.DT*scale):
                            position = G.add(model.p,[dx*math.cos(model.yaw),dy,-dx*math.sin(model.yaw)])
                            rotation = G.blend(model.q,model.flat,fraction)
                            targets = [v[:] for v in model.feet]
                            for i in range(4): targets[i][1] -= distance*rebuilt['deficit'][i]
                            reason = first_refusal(model,targets,position,rotation)
                            assert (reason == 'feasible') == (model.solve(targets,position,rotation) is not None)
                            counts[reason] += 1
            assert sum(counts.values()) == 135 and counts['feasible'] == 0
            reasons.update(counts)
        rows.append(dict(partial_step=snapshot['partial_step'],mode=mode,parity=parity,
            qualified_support=plan['qualified_support'], first_refusal_counts=dict(counts),
            joint_overshoot_rad=[max(0.,abs(v)-(1.6 if i%2==0 else 1.1))
                for i,v in enumerate(snapshot['joint_positions_rad'])]))
    assert len(rows) == 600 and sum(reasons.values()) == 266*135 == 35910
    assert dict(reasons) == {'0:lateral':3192,'0:reach':20954,'2:joint_limit':3939,'1:joint_limit':5151,'0:speed':2674}
    paths = [Path(__file__), closure.RECORD, Path(closure.__file__), Path(reference.__file__),
        Path(G.__file__), Path(closure.geometry.__file__), Path(closure.streams.diagnosis.__file__),
        closure.ROOT/'sdk/core/src/recovery_runtime/partial_concurrent_load_rise_control.rs']
    return dict(schema_version='sporespore_r10ai_stall_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_geometry',
            authority_mode='retained_input_offline_diagnosis',question_class='development'),
        bindings=[closure.bind(p) for p in paths], source_report=closure.bind(report),
        original_source_commit=closure.HEAD, original_outcome='valid_development_negative',
        reconstructed_native_plans=600, fallback_commands=266, fallback_candidates=35910,
        first_refusal_counts=dict(reasons), foot_order=['front_left','front_right','rear_left','rear_right'],
        qualified_support_command_counts=[sum(r['qualified_support'][i] for r in rows) for i in range(4)],
        maximum_joint_overshoot_rad=[max(r['joint_overshoot_rad'][i] for r in rows) for i in range(8)],
        mode_changes=mode_changes, rows=rows,
        inference='The planner reaches a kinematic boundary while the front feet lack qualified load. '
            'Front-left reach rejects 20,954 candidates first; front-right and rear-left joint limits '
            'reject another 9,090 first. These are first-refusal counts, not disjoint physical causes. '
            'A successor should evaluate contact placement and posture changes that escape this boundary, '
            'rather than extend the exhausted raise budget.',
        limitations=['Reconstructs exposed observations only; no held-out or causal comparison.',
            'Virtual geometry does not predict contact force or guarantee physical recovery.',
            'Candidate counts are conditional on the existing grid and production foot order.'],**CLAIMS)


def audit():
    record = closure.read(RECORD)
    assert record == derive()
    return dict(ok=True,reconstructed_native_plans=600,fallback_commands=266,
        fallback_candidates=35910,first_refusal_counts=record['first_refusal_counts'],**CLAIMS)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--create',action='store_true')
    args=parser.parse_args()
    if args.create: closure.write_new(RECORD,derive())
    print(json.dumps(audit(),indent=2))

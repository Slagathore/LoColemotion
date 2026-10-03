"""Post-exposure panel analysis and immutable closure. Never launches worlds."""
import argparse
from collections import defaultdict
import gc
import json
import math
from pathlib import Path

import recovery_discovery as D
import recovery_panel as P
import recovery_panel_reader as R
from recovery_discovery_analysis import verify_archive

BEARING_NS = 0.019293  # Existing descriptive threshold; no acceptance authority.
SCOPE = dict(subsystem='recovery', engine_scope='godot_jolt',
             authority_mode='post_exposure_development_analysis', question_class='development')


def contact_sample(record):
    """Use the already independently replayed detection-frame floor contacts."""
    feet = dict.fromkeys(record['packet']['contact_sites_by_body'], 0.0)
    D.require(len(feet) == 4 and record['replay']['ok'] is True, 'PANEL_ANALYSIS_CONTACTS')
    nonfoot = torso = 0.0
    for item in record['replay']['comparisons']:
        load = item['normal_impulse_ns']
        D.require(type(load) in (int, float) and math.isfinite(load) and load >= 0, 'PANEL_ANALYSIS_LOAD')
        if item['classified_as_foot']:
            D.require(item['body_id'] in feet, 'PANEL_ANALYSIS_FOOT_ID')
            feet[item['body_id']] += load
        else:
            nonfoot += load
        if item['body_id'] == 'torso':
            torso += load
    return dict(bearing_feet=sum(x >= BEARING_NS for x in feet.values()),
                foot_impulses_ns=feet, nonfoot_contact=nonfoot > 0,
                torso_contact=torso > 0)


def stage_summary(rows):
    D.require(bool(rows), 'PANEL_ANALYSIS_EMPTY_STAGE')
    return dict(samples=len(rows), first_step=rows[0]['step'], last_step=rows[-1]['step'],
                four_foot_samples=sum(x['bearing_feet'] == 4 for x in rows),
                bearing_histogram={str(n): sum(x['bearing_feet'] == n for x in rows) for n in range(5)},
                nonfoot_contact_samples=sum(x['nonfoot_contact'] for x in rows),
                torso_contact_samples=sum(x['torso_contact'] for x in rows),
                final_30_four_foot_samples=sum(x['bearing_feet'] == 4 for x in rows[-30:]),
                final_window_samples=min(30, len(rows)),
                per_foot_bearing_samples={foot: sum(x['foot_impulses_ns'][foot] >= BEARING_NS for x in rows)
                                         for foot in rows[0]['foot_impulses_ns']},
                first_height_m=rows[0]['height_m'], last_height_m=rows[-1]['height_m'],
                minimum_height_m=min(x['height_m'] for x in rows),
                maximum_height_m=max(x['height_m'] for x in rows),
                first_up_dot=rows[0]['up_dot'], last_up_dot=rows[-1]['up_dot'])


def features(report):
    trace = report['retained_arm']['trace_rows']
    frames = report['r10af_contact_frames']['records']
    D.require(len(trace) == len(frames) == report['solver_step_count'], 'PANEL_ANALYSIS_FRAME_COUNT')
    interactions = [i for i, row in enumerate(trace)
                    if row['orchestrator_phase'] == 'native_kick_or_matched_no_kick_step']
    D.require(len(interactions) == 1 and interactions[0] > 0, 'PANEL_ANALYSIS_INTERACTION')
    boundary = interactions[0]
    states = [frame['packet']['direct_state_source']['ordered_body_states'] for frame in frames[:boundary]]
    D.require(all(len(row) == 9 for row in states), 'PANEL_ANALYSIS_BODY_POPULATION')
    # Compare every pre-interaction native pose, orientation, velocity, mass and
    # semantic clock. Process/model instance IDs are deliberately not substituted.
    prefix_hash = D.digest(json.dumps(states, sort_keys=True, separators=(',', ':')).encode())
    groups, timeline = defaultdict(list), []
    for index, (row, frame) in enumerate(zip(trace, frames, strict=True)):
        step = index + 1
        D.require(row['global_semantic_step'] == frame['packet']['semantic_step'] == step, 'PANEL_ANALYSIS_CLOCK')
        if index < boundary - 1:
            continue
        point = dict(step=step, seconds_after_interaction=(step-boundary)/120,
                     height_m=row['torso_position_world_m'][1],
                     up_dot=math.cos(row['torso_tilt_rad']),
                     phase=row['orchestrator_phase'], application_phase=row['application_phase'],
                     **contact_sample(frame))
        timeline.append(point)
        if index >= boundary:
            groups[(point['phase'], point['application_phase'])].append(point)
    stages = [dict(phase=phase, application_phase=application, **stage_summary(rows))
              for (phase, application), rows in groups.items()]
    state = report['retained_arm']['orchestrator_state']
    return dict(preinteraction_frames=boundary, preinteraction_state_sha256=prefix_hash,
                terminal_reason=state.get('terminal_reason', ''), terminal_phase=state['phase'],
                recovery_counters={k: v for k, v in state.items() if k.endswith('_step_count')},
                stages=stages, timeline=timeline)


def matched_blocks(cells):
    groups = defaultdict(list)
    for row in cells:
        groups[row['cell']['phase']].append(row)
    result = []
    for phase, rows in sorted(groups.items()):
        D.require(len(rows) == 2 and {x['cell']['role'] for x in rows} == set(P.ROLES), 'PANEL_ANALYSIS_PAIR_ROLES')
        keys = {(x['features']['preinteraction_frames'], x['features']['preinteraction_state_sha256']) for x in rows}
        D.require(len(keys) == 1, 'PANEL_ANALYSIS_UNMATCHED_START')
        frames, digest = next(iter(keys))
        result.append(dict(phase=phase, matched_preinteraction_frames=frames,
                           nine_body_state_sha256=digest,
                           both_roles_positive=all(x['measurement']['finite_task_predicates_passed'] for x in rows)))
    return result


def analyze(batch):
    batch = Path(batch)
    manifest = D.read(batch/'manifest.json')
    rows = D.read(batch/'cells.json')
    D.require([r['cell'] for r in rows] == P.cells(manifest['design']), 'PANEL_ANALYSIS_POPULATION')
    D.require(manifest['design'].get('report_publication') == 'direct_file_v1', 'PANEL_ANALYSIS_WIRE')
    cells = []
    for row in rows:
        folder = Path(row['folder']); declaration = D.read(folder/'declaration.json')
        child = Path(declaration['children'][0]['evidence_path'])
        audit = D.read(child/'discovery-audit.json'); native = D.read(child/'full-native-replay.json')
        D.require(audit['valid'] is True and audit['cell'] == row['cell'], 'PANEL_ANALYSIS_INVALID')
        D.verify_binding(audit['report'])
        D.verify_binding(declaration['discovery_manifest'])
        D.verify_binding(declaration['runtime']['images']['candidate_dll'])
        D.require(native['ok'] is True and native['test_only'] is False
                  and native['complete_report_timeline_replayed'] is True
                  and native['world_build_count'] == native['solver_step_count'] == 0
                  and native['input_raw_sha256'] == audit['report']['raw_sha256']
                  and native['runtime_raw_sha256'] == declaration['runtime']['images']['candidate_dll']['raw_sha256'],
                  'PANEL_ANALYSIS_NATIVE_CUSTODY')
        report = D.read(audit['report']['path'])
        R.validate_report_header(report, declaration)
        D.require(report['diagnostic_declaration_sha256'] == D.binding(folder/'declaration.json')['raw_sha256'],
                  'PANEL_ANALYSIS_DECLARATION')
        core = R.LocomotionCore(declaration['runtime']['images']['candidate_dll']['path'])
        measured = R.measure(report, core.compile_bounded_quadruped(report['configuration']['base_descriptor']))
        D.require(measured == audit['measurement'] and native['transition_count'] == audit['solver_steps'],
                  'PANEL_ANALYSIS_MEASUREMENT')
        cells.append(dict(cell=row['cell'], solver_steps=audit['solver_steps'], measurement=measured,
                          features=features(report), report=audit['report'], audit=D.binding(child/'discovery-audit.json'),
                          native_replay=D.binding(child/'full-native-replay.json'),
                          leaf_seconds=D.read(child/'pool-process.json')['seconds']))
        del report, core
        gc.collect()
        print('ANALYZED '+row['cell']['cell_id'], flush=True)
    blocks = matched_blocks(cells)
    return dict(schema_version='sporespore_full_recovery_panel_analysis_v1', ledger_scope=SCOPE,
                analysis_timing='post_exposure', independent_random_replicates=False,
                interpretation='Purposeful finite phase blocks. Roles use different post-interaction policies; this is not an isolated causal kick-effect estimate. Contact summaries are descriptive, not new acceptance thresholds.',
                bearing_impulse_threshold_ns=BEARING_NS, source_manifest=D.binding(batch/'manifest.json'),
                world_count=len(cells), solver_steps=sum(x['solver_steps'] for x in cells),
                positive_cells=sum(x['measurement']['finite_task_predicates_passed'] for x in cells),
                positive_pairs=sum(x['both_roles_positive'] for x in blocks), phase_blocks=blocks, cells=cells,
                physical_acceptance_authority=False, release_authority=False)


def plot(analysis, batch):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    kicked = [r for r in analysis['cells'] if r['cell']['role'] == P.ROLES[0]]
    fig, axes = plt.subplots(len(kicked), 2, figsize=(12, max(5, len(kicked)*2)), sharex=True, squeeze=False)
    for index, row in enumerate(kicked):
        data = row['features']['timeline']; time = [x['seconds_after_interaction'] for x in data]
        outcome = 'PASS' if row['measurement']['finite_task_predicates_passed'] else row['features']['terminal_reason']
        axes[index, 0].plot(time, [x['height_m'] for x in data], color='#216e66')
        axes[index, 0].set(ylim=(0, .48), ylabel='Torso height (m)',
                           title=f"Phase {row['cell']['phase']} / {row['measurement']['recovery']['entry_kind']} / {outcome}")
        axes[index, 1].step(time, [x['bearing_feet'] for x in data], where='post', color='#3665ad', label='Bearing feet')
        axes[index, 1].fill_between(time, 0, 4, where=[x['torso_contact'] for x in data],
                                    color='#c94f4f', alpha=.18, label='Loaded torso contact')
        axes[index, 1].set(ylim=(-.2, 4.2), yticks=range(5), ylabel='Bearing feet')
        for ax in axes[index]: ax.grid(alpha=.2)
    axes[0, 1].legend(loc='lower right', fontsize=8)
    for ax in axes[-1]: ax.set_xlabel('Simulated seconds after the interaction boundary')
    fig.suptitle('Full recovery discovery panel — retained native physics, no SDK acceptance claim', fontsize=13)
    fig.tight_layout(rect=(0, 0, 1, .975))
    for suffix in ('png', 'svg'):
        target = Path(batch)/('recovery-panel-overview-v1.'+suffix)
        D.require(not target.exists(), 'PANEL_PLOT_EXISTS')
        fig.savefig(target, dpi=160)
    plt.close(fig)


def close(batch, closure_path, history_path=None):
    D.repository(); batch = Path(batch); closure_path = Path(closure_path)
    D.require(not closure_path.exists(), 'PANEL_CLOSURE_EXISTS')
    post = D.read(batch/'post-run-source-and-exit.json')
    D.require(post['ok'] and post['source_runtime_unchanged'] and post['all_retained_process_ids_absent_or_exited'], 'PANEL_CLOSURE_POST_RUN')
    analysis = analyze(batch)
    verify_archive(D.read(batch/'manifest.json'))
    output = batch/'descriptive-analysis-v1.json'; D.write_new(output, analysis); plot(analysis, batch)
    history = D.read(history_path) if history_path else []
    roots = [batch] + [Path(r['folder']) for r in D.read(batch/'cells.json')]
    for item in history:
        root = Path(item['path']); roots.append(root)
        if (root/'cells.json').exists(): roots.extend(Path(r['folder']) for r in D.read(root/'cells.json'))
    paths = sorted({p for root in roots for p in root.rglob('*') if p.is_file()}, key=str)
    value = dict(schema_version='sporespore_full_recovery_panel_closure_v1', ledger_scope=SCOPE,
                 status='complete_valid_development_panel', batch=batch.as_posix(),
                 analyzer=D.binding(Path(__file__)), analysis=D.binding(output), source_manifest=analysis['source_manifest'],
                 post_run=D.binding(batch/'post-run-source-and-exit.json'), retained_history=history,
                 artifacts=[D.binding(p) for p in paths], world_count=analysis['world_count'],
                 valid_count=analysis['world_count'], positive_cells=analysis['positive_cells'],
                 negative_cells=analysis['world_count']-analysis['positive_cells'], positive_pairs=analysis['positive_pairs'],
                 solver_steps=analysis['solver_steps'], sdk1_acceptance_score=14,
                 official_qualification=False, physical_acceptance_authority=False, release_authority=False)
    D.write_new(closure_path, value)
    print(json.dumps({k:value[k] for k in ('world_count','positive_cells','negative_cells','positive_pairs','solver_steps')}))


def check(path):
    D.repository(); value = D.read(path)
    D.require(value['schema_version'] == 'sporespore_full_recovery_panel_closure_v1'
              and value['status'] == 'complete_valid_development_panel'
              and value['sdk1_acceptance_score'] == 14 and all(value[k] is False for k in D.FLAGS), 'PANEL_CLOSURE_CLAIMS')
    for binding in [value[k] for k in ('analyzer','analysis','source_manifest','post_run')] + value['artifacts']:
        D.verify_binding(binding)
    verify_archive(D.read(value['source_manifest']['path']))
    analysis = analyze(value['batch'])
    D.require(analysis == D.read(value['analysis']['path']), 'PANEL_ANALYSIS_REPLAY')
    D.require(value['world_count'] == value['valid_count'] == analysis['world_count']
              and value['positive_cells'] == analysis['positive_cells']
              and value['negative_cells'] == analysis['world_count']-analysis['positive_cells']
              and value['positive_pairs'] == analysis['positive_pairs']
              and value['solver_steps'] == analysis['solver_steps'], 'PANEL_CLOSURE_COUNTS')
    print('FULL_RECOVERY_PANEL_CLOSURE_PASS; SDK1 remains 14/20')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('action', choices=('close','check'))
    parser.add_argument('path', type=Path); parser.add_argument('--closure', type=Path); parser.add_argument('--history', type=Path)
    args = parser.parse_args()
    if args.action == 'close':
        D.require(args.closure is not None, 'PANEL_CLOSURE_PATH')
        close(args.path, args.closure, args.history)
    else: check(args.path)

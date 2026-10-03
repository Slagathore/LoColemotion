"""Post-exposure descriptive analysis and immutable Batch A closure; no worlds."""
import argparse
import json
from pathlib import Path
import zipfile

import recovery_discovery as D
import recovery_discovery_reader as R

BATCH = D.EVIDENCE / 'recovery-discovery-f45cbe6cbd59424b868c07d7620e169f'
CLOSURE = D.HERE / 'recovery_batch_a_closure_v1.json'
# Existing contact-bearing threshold, used descriptively; not an acceptance test.
BEARING_NS = 0.019293
BASELINE_KEYS = ('body_id', 'pose', 'callback_pose', 'linear_velocity', 'angular_velocity')


def contact_metrics(report):
    """Classify floor contacts in the engine's retained detection frame.

    Distal contacts at/below the declared foot-cap center are feet. Body-body
    contacts are excluded. The only unknown instance must be the same floor
    throughout the report. This mirrors the production geometric classifier;
    it does not recreate its complete recovery-state or success evaluator.
    """
    ids = {b['instance_id']: b['body_id'] for b in report['disturbance']['baseline']['bodies']}
    floors = {point['body'+side+'_instance_id'] for row in report['tail_rows']
              for point in row['contacts']['points'] for side in ('1', '2')
              if point['body'+side+'_instance_id'] not in ids}
    D.require(len(floors) == 1, 'ANALYSIS_ONE_FLOOR')
    floor = next(iter(floors))
    records = []
    for row in report['tail_rows']:
        feet = dict.fromkeys(report['contact_sites_by_body'], 0.0)
        nonfoot = 0.0
        for point in row['contacts']['points']:
            for side, other in (('1', '2'), ('2', '1')):
                instance = point['body'+side+'_instance_id']
                if instance not in ids or point['body'+other+'_instance_id'] != floor:
                    continue
                body = ids[instance]
                normal = R.vec(point['normal'+side+'_world_unit'])
                length = R.magnitude(normal)
                D.require(length > 0, 'ANALYSIS_NORMAL')
                load = abs(sum(a*b for a, b in zip(normal, R.vec(point['impulse'+side+'_world_ns'])))/length)
                site = report['contact_sites_by_body'].get(body)
                foot = site is not None and point['point'+side+'_body_local_m'][1] <= site['local_center_m']['y'] + 1e-6
                if foot:
                    feet[body] += load
                else:
                    nonfoot += load
        records.append(dict(step=row['local_step'], bearing_feet=sum(v >= BEARING_NS for v in feet.values()),
                            nonfoot_impulse_ns=nonfoot))
    return dict(four_foot_bearing_samples=sum(r['bearing_feet'] == 4 for r in records),
                nonfoot_contact_samples=sum(r['nonfoot_impulse_ns'] > 0 for r in records),
                bearing_foot_count_histogram={str(n): sum(r['bearing_feet'] == n for r in records) for n in range(5)},
                terminal_bearing_feet=records[-1]['bearing_feet'],
                sample_count=len(records), rows=records)


def analyze(batch=BATCH):
    rows = D.read(batch / 'cells.json')
    D.require([r['cell'] for r in rows] == D.cells(D.read(batch/'manifest.json')['design']), 'ANALYSIS_POPULATION')
    groups, results = {}, []
    for row in rows:
        folder = Path(row['folder'])
        child = folder / 'children' / D.ROLE
        declaration = D.read(folder/'declaration.json')
        audit = D.read(child/'discovery-audit.json')
        D.require(audit['valid'] is True, 'ANALYSIS_INVALID_CELL')
        D.verify_binding(audit['report'])
        report = D.read(audit['report']['path'])
        numeric = R.validate_report(report, declaration)
        D.require(all(audit[k] == v for k, v in numeric.items()), 'ANALYSIS_METRIC_DRIFT')
        cold = D.read(child/'contact-replay.json')
        D.require(cold['ok'] is True and cold['row_count'] == 241 and not cold['failures']
                  and cold['world_build_count'] == cold['solver_step_count'] == 0, 'ANALYSIS_COLD_READER')
        baseline = [{k: body[k] for k in BASELINE_KEYS} for body in report['disturbance']['baseline']['bodies']]
        groups.setdefault(row['cell']['phase'], []).append(baseline)
        trace = []
        for sample in [report['disturbance']['baseline']] + report['tail_rows']:
            torso = next(b for b in sample['bodies'] if b['body_id'] == 'torso')
            trace.append(dict(seconds=sample['local_step']/120, height_m=torso['pose']['origin'][1], up_dot=torso['up_dot']))
        results.append(dict(**numeric, contacts=contact_metrics(report), torso_trace=trace,
                            leaf_seconds=D.read(child/'pool-process.json')['seconds']))
    matched = {str(p): len(values) == 4 and all(v == values[0] for v in values) for p, values in groups.items()}
    D.require(all(matched.values()) and len(results) == 24, 'ANALYSIS_UNMATCHED_BASELINES')
    return dict(schema_version='sporespore_discovery_descriptive_analysis_v1',
                analysis_timing='post_exposure', phase_blocks=matched,
                bearing_impulse_threshold_ns=BEARING_NS,
                contacts_interpretation='Detection-frame foot-cap classification and load summaries; no recovery success inference.',
                cells=results, world_count=24, solver_steps=sum(r['solver_steps'] for r in results),
                native_contact_frames=24*241, independent_random_replicates=False,
                physical_acceptance_authority=False, release_authority=False)


def plot(analysis):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    fig, axes = plt.subplots(2, 3, figsize=(13, 7), sharex=True, sharey=True)
    styles = {(0.0, 'passive'): ('#cf4848', '--', 'Passive, no kick'),
              (0.25, 'passive'): ('#c7750a', '-', 'Passive, 0.25 N s'),
              (0.0, 'zero_velocity_brake'): ('#31827a', '--', 'Braked, no kick'),
              (0.25, 'zero_velocity_brake'): ('#2453ae', '-', 'Braked, 0.25 N s')}
    for ax, phase in zip(axes.flat, analysis['phase_blocks']):
        for result in analysis['cells']:
            cell = result['cell']
            if cell['phase'] != int(phase):
                continue
            color, line, label = styles[cell['impulse_ns'], cell['actuation']]
            trace = result['torso_trace']
            ax.plot([r['seconds'] for r in trace], [r['height_m'] for r in trace],
                    color=color, linestyle=line, linewidth=1.8, label=label)
        ax.set_title('Prefix phase '+phase)
        ax.set_ylim(0.035, 0.405)
        ax.grid(alpha=.2)
        ax.set_xlabel('Seconds after disturbance')
        ax.set_ylabel('Torso height (m)')
    fig.suptitle('Joint release dominates height loss; the kick changes some collapse paths', fontsize=14)
    handles, labels = axes.flat[0].get_legend_handles_labels()
    fig.legend(handles, labels, loc='lower center', ncol=4, frameon=False)
    fig.text(.5, .045, '24 fresh worlds; matched starting states within each phase. Two-second development observation; recovery not evaluated.', ha='center', fontsize=9)
    fig.tight_layout(rect=(0, .075, 1, .95))
    for extension in ('png', 'svg'):
        with (BATCH/('height-comparison-v1.'+extension)).open('xb') as stream:
            fig.savefig(stream, format=extension, dpi=170)
    plt.close(fig)


def verify_archive(manifest):
    D.verify_binding(manifest['source_archive'])
    with zipfile.ZipFile(manifest['source_archive']['path']) as archive:
        D.require(sorted(archive.namelist()) == [r['path'] for r in manifest['source_files']], 'ARCHIVE_INVENTORY')
        for row in manifest['source_files']:
            raw = archive.read(row['path'])
            D.require(len(raw) == row['byte_length'] and D.digest(raw) == row['raw_sha256'], 'ARCHIVE_BYTES')


def close():
    D.repository()
    D.require(not CLOSURE.exists(), 'CLOSURE_ALREADY_EXISTS')
    post = D.read(BATCH/'post-run-source-and-exit.json')
    D.require(post['ok'] is True and post['source_runtime_unchanged'] is True and len(post['cells']) == 24, 'POST_RUN')
    analysis = analyze()
    verify_archive(D.read(BATCH/'manifest.json'))
    D.write_new(BATCH/'descriptive-analysis-v1.json', analysis)
    plot(analysis)
    paths = set(p for p in BATCH.rglob('*') if p.is_file())
    for row in D.read(BATCH/'cells.json'):
        paths.update(p for p in Path(row['folder']).rglob('*') if p.is_file())
    history = [
        ('discovery-interface-7d1e3696e1664ea9907036d2324b6961', 'Zero-world test parse failure retained.'),
        ('discovery-interface-b9a3d575fd0b4a0791772c28f1dd83fd', 'Uninserted-body test impulse errors retained; test hook repaired prospectively.'),
        ('recovery-discovery-763f91df305d49688961916784d8ef1e', 'Pre-world schedule refusal; no worlds.'),
        ('recovery-discovery-5183e3a3cf7f4f94b1584e644801bb5b', 'Zero-world qualification stopped for context batching; no worlds.'),
        ('recovery-discovery-a9c7ae12ae7647e3b31339c5bb13bcc8', 'One serial world; original cold-reader audit invalid and unchanged.'),
        ('development-recovery-smoke-9d8e6f897976490cbd050406147f02dd', 'Original serial report and invalid audit; source for later reader regression only.'),
        ('discovery-reader-successor-f3800fca017c445192dae1d761551b71', 'Wrong default DLL reader failure retained.'),
        ('discovery-reader-successor-e5b9799075ec4a7e842b32125cd627ae', 'Post-exposure V2 reader passed 241 saved frames; no retroactive qualification.'),
        ('recovery-discovery-96eed4f878ce440e8a1516074b2383f5', 'Four leaves refused before physics on DateTime serialization; no worlds.'),
        ('development-interfaces-4a2995063fcd461dbc17a206e4c237c8', 'Supplemental legacy interface sweep: 31 tests passed; process fixture timed out before its seven assertions. Broader gate is not green. The remaining two native-owner tests passed separately.'),
        ('l15-owned-process-identity-65a03f8a5a5b4f359c01aec68a49c363', 'Source snapshot of timed-out zero-world legacy process fixture; no physical population.'),
    ]
    for folder, _ in history:
        root = D.EVIDENCE/folder
        D.require(root.is_dir(), 'HISTORY_MISSING')
        paths.update(p for p in root.rglob('*') if p.is_file())
        if (root/'cells.json').exists():
            for row in D.read(root/'cells.json'):
                paths.update(p for p in Path(row['folder']).rglob('*') if p.is_file())
    closure = dict(schema_version='sporespore_discovery_batch_closure_v1',
                   ledger_scope=D.read(BATCH/'manifest.json')['design']['ledger_scope'],
                   status='complete_development_observation_24_of_24_valid', batch=BATCH.as_posix(),
                   analyzer=D.binding(Path(__file__)), analysis=D.binding(BATCH/'descriptive-analysis-v1.json'),
                   source_manifest=D.binding(BATCH/'manifest.json'),
                   original_source_head=D.read(BATCH/'manifest.json')['head'],
                   retained_history=[dict(path=(D.EVIDENCE/p).as_posix(), disposition=d) for p,d in history],
                   artifacts=[D.binding(p) for p in sorted(paths)],
                   world_count=24, valid_count=24, sdk1_acceptance_score=14, sdk1_total=20,
                   supplemental_legacy_interface_gate_passed=False,
                   recovery_evaluated=False, official_qualification=False,
                   physical_acceptance_authority=False, release_authority=False)
    D.write_new(CLOSURE, closure)
    print(json.dumps(dict(closure=CLOSURE.as_posix(), retained_files=len(paths), worlds=24, valid=24)))


def check():
    D.repository()
    closure = D.read(CLOSURE)
    D.require(closure['status'] == 'complete_development_observation_24_of_24_valid'
              and closure['world_count'] == closure['valid_count'] == 24
              and closure['sdk1_acceptance_score'] == 14
              and all(closure[k] is False for k in D.FLAGS + ('recovery_evaluated',)), 'CLOSURE_CLAIM')
    for binding in [closure['analyzer'], closure['analysis'], closure['source_manifest']] + closure['artifacts']:
        D.verify_binding(binding)
    verify_archive(D.read(closure['source_manifest']['path']))
    D.require(analyze() == D.read(closure['analysis']['path']), 'ANALYSIS_REPLAY')
    print('DISCOVERY_CLOSURE_PASS 24/24 valid; 6 matched phase blocks; SDK1 remains 14/20')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--close', action='store_true')
    args = parser.parse_args()
    close() if args.close else check()

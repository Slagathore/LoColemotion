"""Export source-bound integration diagrams and retained force-timing data.

No engine is imported or launched. The first figure explains API units; the
second reopens the first declared cell of the immutable MuJoCo VH4 report.
Neither figure is a new characterization, engine ranking or equivalence test.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path

SDK = Path(__file__).resolve().parents[2]
ROOT = SDK.parent


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_trace():
    closure_path = SDK / 'mujoco_c6_velocity_only_stability_host_characterization_vh4_closure.json'
    closure = json.loads(closure_path.read_text(encoding='utf-8-sig'))
    evidence = closure['physical_evidence']
    binding = next(row for row in evidence['files'] if row['name'] == 'report.json')
    report_path = Path(evidence['evidence_root']) / binding['name']
    if digest(report_path) != binding['raw_sha256']:
        raise ValueError('VH4 retained report digest mismatch')
    report = json.loads(report_path.read_text())
    if report['ok'] is not True or len(report['cells']) != 24 or not all(row['passed'] for row in report['cells']):
        raise ValueError('VH4 retained population/outcome changed')
    cell = report['cells'][0]  # Declaration order, never select the best curve.
    if cell['cell_id'] != 'unloaded_vn075_izero' or len(cell['internal_step_trace']) != 1800:
        raise ValueError('Illustrative cell identity or population changed')
    trace = cell['internal_step_trace']
    if any(len(row) != 17 or row[0] != index for index, row in enumerate(trace)):
        raise ValueError('VH4 trace column/step continuity')
    return closure_path, report_path, report, cell


def export(folder):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.patches import FancyBboxPatch

    closure_path, report_path, report, cell = load_trace()
    folder = folder.resolve()
    if not folder.is_relative_to(ROOT.parent / 'SporeSpore_Evidence'):
        raise ValueError('Durable evidence root required')
    folder.mkdir(parents=True, exist_ok=False)
    plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 11,
                         'axes.spines.top': False, 'axes.spines.right': False})
    fig, ax = plt.subplots(figsize=(12, 5.8), layout='constrained')
    ax.set(xlim=(0, 12), ylim=(0, 6)); ax.axis('off')
    ax.text(6, 5.65, 'One portable budget; three native API mappings', ha='center', fontsize=19, weight='bold')
    ax.text(6, 4.92, 'Illustrative angular-impulse cap B = 0.05 N·m·s over an outer step Δt = 1/120 s', ha='center')
    cards = [
        ('Godot / Jolt', 'Hinge max-impulse parameter\nB = 0.05 N·m·s', 'Canonical velocity sign: −1\nThis adapter’s authored joint convention'),
        ('Rapier', 'ForceBased motor maximum force\nB / Δt = 6 N·m', '16 solver small-steps in the pinned profile\nPer-small-step cap: B / 16 = 0.003125 N·m·s'),
        ('MuJoCo', 'Velocity-actuator forcerange\n[−B / Δt, +B / Δt] = [−6, +6] N·m', 'Five internal steps, each 1/600 s\nPer-internal-step force-time budget: 0.01 N·m·s')]
    for index, (title, mapping, note) in enumerate(cards):
        x = .1 + index * 4
        ax.add_patch(FancyBboxPatch((x, 1.35), 3.8, 2.85, boxstyle='round,pad=0.03', facecolor='#edf3f8', edgecolor='#9eb5c5'))
        ax.annotate('', xy=(x + 1.9, 4.22), xytext=(6, 4.68), arrowprops={'arrowstyle': '->', 'color': '#527588'})
        ax.text(x + 1.9, 3.78, title, ha='center', fontsize=15, weight='bold')
        ax.text(x + 1.9, 2.9, mapping, ha='center', va='center', fontsize=10)
        ax.text(x + 1.9, 1.94, note, ha='center', va='center', fontsize=8.8)
    ax.text(6, .72, 'API mapping illustration, not a new physics result. Solver settings and joint frames are profile-specific.', ha='center', fontsize=10)
    ax.text(6, .25, 'Velocity-only actuation in these profiles: native position stiffness stays zero; portable control owns position feedback.', ha='center', fontsize=10)
    for extension in ['png', 'svg']:
        fig.savefig(folder / f'host-actuation-mapping.{extension}', dpi=160)
    plt.close(fig)

    rows = cell['internal_step_trace'][:12]
    time_ms = [row[3] * 1000 for row in rows]
    fig, axes = plt.subplots(2, 1, figsize=(11, 7.3), layout='constrained', sharex=True)
    fig.suptitle('When you sample changes what “actuator force” means', fontsize=18, weight='bold')
    axes[0].plot(time_ms, [row[6] for row in rows], 'o-', label='Completed-step actuation, before post-state recomputation', color='#b65b27')
    axes[0].plot(time_ms, [row[13] for row in rows], 's--', label='Force recomputed at the post-step state', color='#167783')
    axes[0].axhline(-6, color='#888888', ls=':', label='Declared −6 N·m force limit')
    axes[0].set(ylabel='Actuator force (N·m)', ylim=(-6.6, .45))
    axes[0].legend(loc='lower right', fontsize=9)
    axes[0].annotate('First internal step: −6 N·m was retained.\nA later recomputation reports −1.5 N·m.',
                     xy=(time_ms[0], -6), xytext=(5, -4.3), arrowprops={'arrowstyle': '->'}, fontsize=10)
    axes[1].plot(time_ms, [row[12] for row in rows], 'o-', label='Motor impulse inferred from momentum change', color='#534595')
    axes[1].plot(time_ms, [row[6] / 600 for row in rows], 'x--', label='Completed-step force × internal Δt', color='#b65b27')
    axes[1].plot(time_ms, [row[13] / 600 for row in rows], '+--', label='Post-state recomputed force × internal Δt', color='#167783')
    axes[1].set(xlabel='Post-step simulated time (ms)', ylabel='Angular impulse (N·m·s)')
    axes[1].legend(loc='lower right', fontsize=9)
    for axis in axes:
        axis.grid(alpha=.2)
        axis.axvline(1000 / 120, color='#888888', lw=.8, ls=':')
    fig.supxlabel('Retained VH4 first declared cell: unloaded_vn075_izero. First 12 of 1,800 internal steps; not a new trial.', fontsize=10)
    for extension in ['png', 'svg']:
        fig.savefig(folder / f'mujoco-force-sampling.{extension}', dpi=160)
    plt.close(fig)
    with (folder / 'mujoco-force-sampling.csv').open('w', encoding='utf-8', newline='') as out:
        writer = csv.writer(out)
        writer.writerow(['internal_step', 'post_time_s', 'completed_step_force_nm', 'post_state_recomputed_force_nm',
                         'momentum_inferred_motor_impulse_nms', 'post_joint_velocity_rad_s'])
        for row in cell['internal_step_trace']:
            writer.writerow([row[0], row[3], row[6], row[13], row[12], row[11]])
    paths = [Path(__file__), closure_path, report_path, SDK / 'core/src/canonical_actuation.rs',
             SDK / 'adapters/rapier/src/velocity_only_live_integration.rs',
             SDK / 'adapters/mujoco/sporespore_mujoco_adapter/selected_policy_development.py',
             SDK / 'adapters/mujoco/sporespore_mujoco_adapter/velocity_only_stability_characterization_vh4.py',
             ROOT / 'scripts/lab/gait/sdk_godot_jolt_adapter.gd']
    record = dict(schema_version='sporespore_engine_integration_figures_v1',
                  ledger_scope=dict(subsystem='explorer', engine_scope='3e', authority_mode='retrospective_explanation', question_class='development'),
                  source_bindings={str(p): digest(p) for p in paths},
                  illustrated_cell_id=cell['cell_id'], displayed_internal_steps=12, exported_internal_steps=1800,
                  complete_vh4_population=len(report['cells']),
                  first_step=dict(completed_step_force_nm=rows[0][6], recomputed_force_nm=rows[0][13],
                                  momentum_inferred_motor_impulse_nms=rows[0][12]),
                  files={p.name: digest(p) for p in sorted(folder.iterdir()) if p.is_file()},
                  world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False,
                  interpretation='Read-only diagrams of pinned adapter mappings and a retained finite native trace. No engine ranking, new characterization or trajectory equivalence.')
    (folder / 'manifest.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    return record


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    value = export(args.output)
    print(json.dumps(dict(output=str(args.output), world_build_count=0, files=list(value['files']))))

"""Join real button commands, native application and UI acknowledgements."""
import argparse
import json
import math
from pathlib import Path

from audit_sandbox import audit, require
from showcase_model import impulse


def audit_rows(commands, native, ui):
    require(0 < len(commands) == len(native) == len(ui) <= 16, 'Interaction population')
    commands_by_id = {row['command_id']: row for row in commands}
    native_by_id = {row['command_id']: row for row in native}
    ui_by_id = {row['command_id']: row for row in ui}
    require(len(commands_by_id) == len(commands) and
            set(commands_by_id) == set(native_by_id) == set(ui_by_id), 'Interaction identity')
    result = []
    for command_id, command in commands_by_id.items():
        applied, shown = native_by_id[command_id], ui_by_id[command_id]
        expected = impulse('audit', 1, command['magnitude'], command['direction'], command_id)
        require(expected['impulse_n_s'] == applied['impulse_n_s'], 'Button-to-native impulse vector')
        require(shown['applied_frame'] == applied['apply_at_frame'], 'Button-to-native application frame')
        pressed, observed = shown['ui_pressed_ticks_usec'], shown['ui_observed_ticks_usec']
        require(type(pressed) is int and type(observed) is int and 0 < pressed <= observed, 'UI monotonic clock')
        roundtrip = (observed - pressed) / 1000
        require(math.isclose(roundtrip, shown['button_to_observed_application_ms'], abs_tol=1e-6), 'UI latency calculation')
        timing = applied['interaction_timing']
        application_ms = (timing['native_application_perf_counter_ns'] - timing['owner_received_perf_counter_ns']) / 1e6
        require(0 <= application_ms <= roundtrip + 1, 'UI and native latency ordering')
        result.append(dict(command_id=command_id, applied_frame=applied['apply_at_frame'],
                           owner_receipt_to_native_application_ms=application_ms,
                           button_to_observed_application_ms=roundtrip))
    return result


def audit_desktop(folder):
    sessions = list(folder.glob('sandbox-*/receipt.json'))
    require(len(sessions) == 1, 'One fresh desktop diagnostic session required')
    native_folder = sessions[0].parent
    result = audit(native_folder)
    receipt = json.loads(sessions[0].read_text())
    ui = json.loads((folder / 'interaction.json').read_text())
    commands = [json.loads(path.read_text()) for path in sorted((folder / 'commands').glob('*.consumed'))]
    commands = [row for row in commands if row.get('kind') == 'kick']
    require(all(row['session_id'] == receipt['physical']['session_id'] for row in ui), 'UI session identity')
    result['interactive_latency'] = audit_rows(commands, receipt['physical']['applied_impulses'], ui)
    require('STUDIO_NATIVE_UI_PASS' in (folder / 'ui.stdout.log').read_text(), 'Native UI exercise outcome')
    require(not (folder / 'ui.stderr.log').read_text().strip(), 'UI errors')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path)
    args = parser.parse_args()
    print(json.dumps(audit_desktop(args.folder), indent=2))

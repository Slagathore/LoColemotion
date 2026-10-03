"""Real editor/LSP startup regression; no project scene or simulation is run.

Run directly with --evidence-root pointing to a fresh durable output directory.
This is an editor configuration check, not locomotion qualification.
"""
import argparse
import json
import os
from pathlib import Path
import socket
import subprocess
import time


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_EXTENSION = 'res://sdk/adapters/godot/sporespore_locomotion.gdextension'


def send(sock, message):
    body = json.dumps(message).encode('utf-8')
    sock.sendall(f'Content-Length: {len(body)}\r\n\r\n'.encode() + body)


def response(stream, request_id):
    """Consume framed replies, including notifications preceding our response."""
    for _ in range(2000):
        headers = {}
        while True:
            line = stream.readline()
            if not line:
                raise AssertionError('LSP disconnected before replying')
            if line in (b'\r\n', b'\n'):
                break
            key, value = line.decode().split(':', 1)
            headers[key.lower()] = value.strip()
        length = int(headers['content-length'])
        payload = bytearray()
        while len(payload) < length:
            block = stream.read(length - len(payload))
            if not block:
                raise AssertionError('LSP disconnected inside a response')
            payload.extend(block)
        value = json.loads(payload)
        if value.get('id') == request_id:
            assert 'error' not in value, value
            return value
    raise AssertionError('LSP response not received')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence-root', required=True, type=Path)
    args = parser.parse_args()
    output = args.evidence_root.resolve()
    durable = ROOT.parent / 'SporeSpore_Evidence'
    assert output.is_relative_to(durable), 'Use the durable evidence root'
    output.mkdir(exist_ok=False)
    launch = json.loads((ROOT / '.vscode/launch.json').read_text(encoding='utf-8'))
    configured = Path(launch['configurations'][0]['editor_path'])
    # Run the real editor directly, so a timeout cannot orphan its console child.
    engine = configured.with_name(configured.name.replace('.console.exe', '.exe'))
    assert engine.is_file(), engine
    with socket.socket() as reservation:
        reservation.bind(('127.0.0.1', 0))
        port = reservation.getsockname()[1]
    command = [str(engine), '--path', str(ROOT), '--editor', '--headless',
               '--no-window', '--lsp-port', str(port)]
    (output / 'command.json').write_text(json.dumps(command, indent=2), encoding='utf-8')
    print(f'Editor/LSP startup on isolated port {port}', flush=True)
    with (output / 'stdout.log').open('xb') as stdout, (output / 'stderr.log').open('xb') as stderr:
        process = subprocess.Popen(command, cwd=ROOT, stdout=stdout, stderr=stderr)
        try:
            deadline = time.monotonic() + 120
            while True:
                assert process.poll() is None, 'Editor exited before opening LSP'
                try:
                    sock = socket.create_connection(('127.0.0.1', port), timeout=1)
                    break
                except OSError:
                    assert time.monotonic() < deadline, 'LSP startup timed out'
                    time.sleep(0.2)
            with sock:
                sock.settimeout(120)
                stream = sock.makefile('rb')
                send(sock, {'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {
                    'processId': os.getpid(), 'rootUri': ROOT.as_uri(),
                    'capabilities': {},
                    'workspaceFolders': [{'uri': ROOT.as_uri(), 'name': 'SporeSpore'}],
                }})
                initialized = response(stream, 1)
                (output / 'initialize-response.json').write_text(json.dumps(initialized, indent=2), encoding='utf-8')
                send(sock, {'jsonrpc': '2.0', 'method': 'initialized', 'params': {}})
                # This script directly requires the custom Jolt class that the
                # stock editor could not parse. A real symbol response checks LSP.
                target = ROOT / 'sdk/adapters/godot/gdscript/recovery_native_world_v1.gd'
                send(sock, {'jsonrpc': '2.0', 'id': 2, 'method': 'textDocument/documentSymbol',
                            'params': {'textDocument': {'uri': target.as_uri()}}})
                symbols = response(stream, 2)
                assert symbols.get('result'), 'Native recovery script has no parsed symbols'
                (output / 'native-world-symbols.json').write_text(json.dumps(symbols), encoding='utf-8')
                # Godot's LSP does not implement the generic shutdown request.
                # Close this client and stop only our isolated editor below.
                stream.close()
            print('LSP initialization and native-world symbols passed', flush=True)
        finally:
            if process.poll() is None:
                # This process is our isolated headless editor, never the user's.
                process.terminate()
            process.wait(timeout=15)
    logs = (output / 'stdout.log').read_text(encoding='utf-8', errors='replace')
    logs += (output / 'stderr.log').read_text(encoding='utf-8', errors='replace')
    errors = [line for line in logs.splitlines() if 'ERROR:' in line]
    assert not errors, errors
    extensions = (ROOT / '.godot/extension_list.cfg').read_text(encoding='utf-8').splitlines()
    assert extensions == [DEFAULT_EXTENSION], extensions
    result = {
        'ledger_scope': {'subsystem': 'editor', 'engine_scope': 'godot',
                         'authority_mode': 'editor_startup_regression', 'question_class': 'development'},
        'editor': str(engine), 'startup_error_count': len(errors),
        'startup_extensions': extensions, 'lsp_initialize_passed': True,
        'native_world_symbol_count': len(symbols['result']),
        'simulation_started': False, 'physical_acceptance_authority': False,
    }
    (output / 'result.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print('SDK_EDITOR_STARTUP_PASS ' + json.dumps(result), flush=True)


if __name__ == '__main__':
    main()

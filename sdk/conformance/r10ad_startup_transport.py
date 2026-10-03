"""R10AD helper subprocess transport with explicit, retained standard streams.

Godot can start helpers with unusable inherited stderr. Every subprocess here
receives its own stdin/stdout/stderr handles. This module grants no world claim.
"""
import subprocess


class CommandRefused(RuntimeError):
    def __init__(self, receipt):
        self.receipt = receipt
        super().__init__('R10AD_STARTUP_COMMAND_TIMEOUT' if receipt['timed_out'] else
            'R10AD_STARTUP_COMMAND_EXIT:' + str(receipt['exit_code']))


def run_captured(command, *, cwd, timeout_seconds=45):
    """Bound the child and retain both streams even on refusal or timeout."""
    if not command or not 0 < timeout_seconds <= 120:
        raise ValueError('R10AD_STARTUP_COMMAND_ARGUMENTS')
    receipt = dict(command=list(map(str, command)), working_directory=str(cwd),
        timeout_seconds=timeout_seconds, timed_out=False, exit_code=None,
        stdout='', stderr='')
    try:
        result = subprocess.run(receipt['command'], cwd=cwd, stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout_seconds,
            creationflags=subprocess.CREATE_NO_WINDOW)
        receipt.update(exit_code=result.returncode,
            stdout=result.stdout.decode('utf-8', errors='replace'),
            stderr=result.stderr.decode('utf-8', errors='replace'))
    except subprocess.TimeoutExpired as error:
        receipt.update(timed_out=True, stdout=(error.stdout or b'').decode('utf-8', errors='replace'),
            stderr=(error.stderr or b'').decode('utf-8', errors='replace'))
    return receipt


def checked_output(command, *, cwd, timeout_seconds=45):
    receipt = run_captured(command, cwd=cwd, timeout_seconds=timeout_seconds)
    if receipt['timed_out'] or receipt['exit_code'] != 0:
        raise CommandRefused(receipt)
    return receipt['stdout'].strip()

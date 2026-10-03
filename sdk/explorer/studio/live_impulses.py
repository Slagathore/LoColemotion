"""Studio-only next-step impulses; the accepted scheduled transport is unchanged.

The physics thread chooses the application step when it polls the command,
so a stale display frame cannot make an interactive kick miss its schedule.
The original transport still validates every normalized native command.
"""
import queue
import time
from types import SimpleNamespace

from sporespore_mujoco_adapter.live_explorer_worker import LiveTransport


class InteractiveTransport(LiveTransport):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.command_ids = set()
        self.interactive_timing = {}

    def send(self, message):
        if message.get('message_type') == 'hello':
            message['command_capabilities']['next_native_step_torso_impulse'] = True
            message['interaction_timing_profile'] = 'studio_next_native_step_perf_counter_ns_v1'
        super().send(message)

    def take_due_impulses(self):
        # Validate using a private queue, never replace the reader thread's
        # shared queue. The original scheduled parser remains the oracle.
        batch = queue.Queue()
        while True:
            try:
                value = self.command_queue.get_nowait()
            except queue.Empty:
                break
            if isinstance(value, BaseException):
                raise RuntimeError(f'Studio command stream failed: {value}')
            if not isinstance(value, dict):
                raise ValueError('Studio command must be an object')
            command_id = value.get('command_id')
            if not isinstance(command_id, str) or command_id in self.command_ids:
                raise ValueError('Studio command identity missing or repeated')
            if len(self.command_ids) >= 16:
                raise ValueError('Studio command population exceeded')
            value = dict(value)
            timing = None
            if 'apply_when' in value:
                if value['apply_when'] != 'next_native_step' or 'apply_at_frame' in value:
                    raise ValueError('Ambiguous Studio impulse timing')
                polled = time.perf_counter_ns()
                received = value.get('owner_received_perf_counter_ns')
                sent = value.get('owner_sent_perf_counter_ns')
                if type(received) is not int or type(sent) is not int or not 0 < received <= sent <= polled:
                    raise ValueError('Studio impulse timing clock invalid')
                value['apply_at_frame'] = self.frame_index + 1
                timing = dict(owner_received_perf_counter_ns=received,
                              owner_sent_perf_counter_ns=sent,
                              native_polled_perf_counter_ns=polled,
                              native_polled_after_frame=self.frame_index,
                              application_policy='next_native_step')
            elif type(value.get('apply_at_frame')) is not int:
                raise ValueError('Studio scheduled frame must be an integer')
            self.command_ids.add(command_id)
            if timing is not None:
                self.interactive_timing[command_id] = timing
            batch.put(value)
        oracle = SimpleNamespace(command_queue=batch, session_id=self.session_id,
                                 frame_index=self.frame_index, pending_impulses=self.pending_impulses,
                                 send=self.send)
        due = LiveTransport.take_due_impulses(oracle)
        for item in due:
            timing = self.interactive_timing.get(item['command_id'])
            if timing is not None:
                item['interaction_timing'] = dict(timing)
        return due


def mark_native_application(applied):
    """Timestamp immediately before handing the applied force to the solver."""
    now = time.perf_counter_ns()
    for item in applied:
        if 'interaction_timing' in item:
            item['interaction_timing']['native_application_perf_counter_ns'] = now

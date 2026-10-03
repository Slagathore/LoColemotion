"""SDK1 complete ABI binding; legacy clients and pinned observations stay intact.

The four additive functions are development recovery interfaces. Their presence
does not grant a new physical behavior claim. Older libraries may omit them.
"""
import ctypes

if __package__:
    from . import sporespore_locomotion as legacy
else:
    import sporespore_locomotion as legacy


class LocomotionCore(legacy.LocomotionCore):
    """The legacy convenience API plus signatures for every SDK1 native export."""

    def _configure_signatures(self) -> None:
        super()._configure_signatures()
        byte_pointer = ctypes.POINTER(ctypes.c_uint8)
        size_pointer = ctypes.POINTER(ctypes.c_size_t)
        for name in (
            "ss_recovery_r10aa_partial_entry_control_v1_json",
            "ss_recovery_r10aa_partial_step_control_v1_json",
            "ss_recovery_r10ab_partial_entry_control_v1_json",
            "ss_recovery_r10ab_partial_step_control_v1_json",
        ):
            function = getattr(self._library, name, None)
            if function is not None:
                function.argtypes = [byte_pointer, ctypes.c_size_t, byte_pointer,
                                     ctypes.c_size_t, size_pointer]
                function.restype = ctypes.c_int

    def recovery_r10aa_partial_entry_control_v1(self, value):
        return self._call_json_input("ss_recovery_r10aa_partial_entry_control_v1_json", value)

    def recovery_r10aa_partial_step_control_v1(self, value):
        return self._call_json_input("ss_recovery_r10aa_partial_step_control_v1_json", value)

    def recovery_r10ab_partial_entry_control_v1(self, value):
        return self._call_json_input("ss_recovery_r10ab_partial_entry_control_v1_json", value)

    def recovery_r10ab_partial_step_control_v1(self, value):
        return self._call_json_input("ss_recovery_r10ab_partial_step_control_v1_json", value)

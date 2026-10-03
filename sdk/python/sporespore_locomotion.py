"""Dependency-free Python binding for the SporeSpore locomotion C ABI.

This module is a convenience binding. The checked-in C header and Rust core
remain the semantic/ABI authorities.
"""

from __future__ import annotations

import ctypes
import json
import os
import warnings
from pathlib import Path
from typing import Any, Mapping

SS_OK = 0
SS_INVALID_ARGUMENT = 1
SS_BUFFER_TOO_SMALL = 2
SS_CORE_ERROR = 3
SS_PANIC_CAUGHT = 4
SDK_VERSION = "0.1.0"
ABI_GENERATION = 1
SELECTED_BALANCED_WAVE_CANDIDATE_ID = "BW5R-B"
SELECTED_BALANCED_WAVE_POLICY_ID = "sporespore_balanced_wave_bw5r_b_v1"
R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID = (
    "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
)
R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256 = (
    "sha256:b65d41e3f30c42e0a8207f1385fe00daa8f03975f4e266a0bd0867970f674964"
)
R24D22_RECOVERY_S169_MORPHOLOGY_ID = "qsdk_r24_recovery_s169_v1"


class LocomotionCoreError(RuntimeError):
    """A typed failure returned by the portable locomotion core."""

    def __init__(self, status: int, failure_code: str, detail: str) -> None:
        super().__init__(f"{failure_code}:{detail}")
        self.status = status
        self.failure_code = failure_code
        self.detail = detail


def _warn_deprecated(surface: str, replacement: str) -> None:
    warnings.warn(
        (
            f"{surface} is deprecated since SDK 0.1.0; "
            f"use {replacement}. It will not be removed before 0.3.0."
        ),
        DeprecationWarning,
        stacklevel=3,
    )


def _default_library_candidates() -> list[Path]:
    sdk_root = Path(__file__).resolve().parents[1]
    names = (
        ["sporespore_locomotion_core.dll"]
        if os.name == "nt"
        else [
            "libsporespore_locomotion_core.so",
            "libsporespore_locomotion_core.dylib",
        ]
    )
    configured = os.environ.get("SPORESPORE_LOCOMOTION_LIBRARY")
    candidates = [Path(configured).expanduser()] if configured else []
    for profile in ("release", "debug"):
        candidates.extend(sdk_root / "target" / profile / name for name in names)
    return candidates


def find_library() -> Path:
    """Resolve the first existing SDK library without mutating the process."""

    candidates = _default_library_candidates()
    for candidate in candidates:
        resolved = candidate.resolve()
        if resolved.is_file():
            return resolved
    rendered = "\n".join(f"  - {candidate}" for candidate in candidates)
    raise FileNotFoundError(
        "SporeSpore locomotion core library was not found. "
        "Build it with `cargo build --workspace --release --offline` or set "
        f"SPORESPORE_LOCOMOTION_LIBRARY. Checked:\n{rendered}"
    )


class LocomotionCore:
    """Loaded, versioned view of the portable C ABI."""

    def __init__(self, library_path: str | os.PathLike[str] | None = None) -> None:
        path = Path(library_path).resolve() if library_path else find_library()
        self.library_path = path
        self._library = ctypes.CDLL(str(path))
        self._configure_signatures()

    def _configure_signatures(self) -> None:
        byte_pointer = ctypes.POINTER(ctypes.c_uint8)
        size_pointer = ctypes.POINTER(ctypes.c_size_t)
        self._library.ss_version.argtypes = []
        self._library.ss_version.restype = ctypes.c_char_p
        for name in (
            "ss_canonicalize_json",
            "ss_compile_bounded_quadruped_json",
            "ss_compile_recovery_morphology_v1_json",
            "ss_resolve_actuator_cap_profile_v1_json",
            "ss_recovery_initialize_v1_json",
            "ss_recovery_initialize_v2_json",
            "ss_recovery_step_v1_json",
            "ss_recovery_step_v2_json",
            "ss_recovery_step_v3_json",
            "ss_recovery_step_v4_json",
            "ss_recovery_step_v5_json",
            "ss_recovery_evaluate_trace_v1_json",
            "ss_recovery_evaluate_trace_v2_json",
            "ss_recovery_evaluate_trace_v3_json",
            "ss_recovery_evaluate_trace_v4_json",
            "ss_recovery_evaluate_trace_v5_json",
            "ss_recovery_energy_balance_aggregate_v2_json",
            "ss_recovery_energy_balance_evaluate_v2_json",
            "ss_recovery_energy_balance_aggregate_v3_json",
            "ss_recovery_energy_balance_evaluate_v3_json",
            "ss_recovery_energy_balance_migrate_v1_json",
            "ss_recovery_collect_native_v1_json",
            "ss_recovery_collect_native_v2_json",
            "ss_recovery_collect_native_v3_json",
            "ss_recovery_plan_control_v1_json",
            "ss_recovery_plan_control_v2_json",
            "ss_recovery_plan_control_v3_json",
            "ss_recovery_plan_stance_control_v1_json",
            "ss_recovery_plan_stance_control_v2_json",
            "ss_recovery_plan_stance_control_v3_json",
            "ss_recovery_plan_stance_control_v4_json",
            "ss_canonical_velocity_compose_v1_json",
            "ss_canonical_velocity_host_map_v1_json",
            "ss_resolve_adaptation_v1_json",
            "ss_candidate35_profile_json",
            "ss_candidate35_step_json",
            "ss_balanced_wave_profile_json",
            "ss_balanced_wave_policy_profile_json",
            "ss_balanced_wave_policy_initial_memory_json",
            "ss_balanced_wave_step_json",
            "ss_balanced_wave_policy_step_json",
            "ss_observe_stability_v2_json",
            "ss_plan_scheduled_load_transfer_v1_json",
            "ss_plan_scheduled_load_transfer_v2_json",
            "ss_plan_scheduled_load_transfer_v3_json",
            "ss_command_centroidal_support_v2_json",
            "ss_map_endpoint_force_to_joint_v2_json",
            "ss_map_endpoint_force_to_joint_v3_json",
            "ss_bound_stability_influence_v2_json",
            "ss_bound_stability_influence_v3_json",
        ):
            function = getattr(self._library, name)
            function.argtypes = [
                byte_pointer,
                ctypes.c_size_t,
                byte_pointer,
                ctypes.c_size_t,
                size_pointer,
            ]
            function.restype = ctypes.c_int
        # The additive development entry path is optional on older pinned
        # runtimes; ordinary clients must not stop loading those old binaries.
        for name in ("ss_recovery_passive_entry_step_v1_json",
                     "ss_recovery_collect_passive_native_v1_json",
                     "ss_recovery_r10k_entry_control_v1_json",
                     "ss_recovery_partial_fall_step_control_v1_json",
                     "ss_recovery_r10q_upright_entry_control_v1_json",
                     "ss_recovery_upright_step_control_v1_json",
                     "ss_recovery_r10r_upright_step_control_v1_json",
                     "ss_recovery_r10z_partial_entry_control_v1_json",
                     "ss_recovery_r10z_partial_step_control_v1_json",
                     "ss_recovery_r10y_partial_entry_control_v1_json",
                     "ss_recovery_r10y_partial_step_control_v1_json",
                     "ss_recovery_r10ai_partial_entry_control_v1_json",
                     "ss_recovery_r10ai_partial_step_control_v1_json",
                     "ss_recovery_r10aj_partial_entry_control_v1_json",
                     "ss_recovery_r10aj_partial_step_control_v1_json",
                     "ss_recovery_r10am_partial_entry_control_v1_json",
                     "ss_recovery_r10am_partial_step_control_v1_json",
                     "ss_recovery_r10ap_partial_entry_control_v1_json",
                     "ss_recovery_r10ap_partial_step_control_v1_json",
                     "ss_recovery_r10dd_partial_entry_control_v1_json",
                     "ss_recovery_r10dd_partial_step_control_v1_json"):
            function = getattr(self._library, name, None)
            if function is not None:
                function.argtypes = [byte_pointer, ctypes.c_size_t, byte_pointer,
                                     ctypes.c_size_t, size_pointer]
                function.restype = ctypes.c_int
        self._library.ss_balanced_wave_policy_session_create_json.argtypes = [
            byte_pointer,
            ctypes.c_size_t,
            ctypes.POINTER(ctypes.c_uint64),
        ]
        self._library.ss_balanced_wave_policy_session_create_json.restype = ctypes.c_int
        self._library.ss_balanced_wave_policy_session_step_json.argtypes = [
            ctypes.c_uint64,
            byte_pointer,
            ctypes.c_size_t,
            byte_pointer,
            ctypes.c_size_t,
            size_pointer,
        ]
        self._library.ss_balanced_wave_policy_session_step_json.restype = ctypes.c_int
        self._library.ss_balanced_wave_policy_session_destroy.argtypes = [
            ctypes.c_uint64,
        ]
        self._library.ss_balanced_wave_policy_session_destroy.restype = ctypes.c_int
        for name in (
            "ss_gq15_domain_certificate_json",
            "ss_candidate35_initial_memory_json",
            "ss_balanced_wave_initial_memory_json",
            "ss_recovery_development_profile_v1_json",
        ):
            function = getattr(self._library, name)
            function.argtypes = [
                byte_pointer,
                ctypes.c_size_t,
                size_pointer,
            ]
            function.restype = ctypes.c_int

    @property
    def version(self) -> str:
        raw = self._library.ss_version()
        if raw is None:
            raise LocomotionCoreError(
                SS_PANIC_CAUGHT,
                "INTERNAL_NULL_VERSION",
                "ss_version returned NULL",
            )
        return raw.decode("utf-8", errors="strict")

    @staticmethod
    def _input_bytes(value: Mapping[str, Any]) -> bytes:
        return json.dumps(
            value,
            allow_nan=False,
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        ).encode("utf-8")

    @staticmethod
    def _decode(status: int, output: bytes) -> dict[str, Any]:
        try:
            envelope = json.loads(output.decode("utf-8", errors="strict"))
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise LocomotionCoreError(
                status,
                "ABI_INVALID_JSON",
                str(error),
            ) from error
        if status != SS_OK or envelope.get("ok") is not True:
            raise LocomotionCoreError(
                status,
                str(envelope.get("failure_code", "ABI_UNKNOWN_FAILURE")),
                str(envelope.get("detail", "missing failure detail")),
            )
        value = envelope.get("value")
        if not isinstance(value, dict):
            raise LocomotionCoreError(
                status,
                "ABI_INVALID_ENVELOPE",
                "success envelope value is not an object",
            )
        return value

    def _call_json_input(
        self,
        name: str,
        value: Mapping[str, Any],
    ) -> dict[str, Any]:
        input_bytes = self._input_bytes(value)
        input_array = (ctypes.c_uint8 * len(input_bytes)).from_buffer_copy(input_bytes)
        function = getattr(self._library, name)
        required = ctypes.c_size_t(0)
        first_status = function(
            input_array,
            len(input_bytes),
            None,
            0,
            ctypes.byref(required),
        )
        if first_status != SS_BUFFER_TOO_SMALL or required.value == 0:
            raise LocomotionCoreError(
                first_status,
                "ABI_SIZE_QUERY_FAILED",
                f"{name} did not return a nonzero required length",
            )
        output = (ctypes.c_uint8 * required.value)()
        second_status = function(
            input_array,
            len(input_bytes),
            output,
            len(output),
            ctypes.byref(required),
        )
        return self._decode(second_status, bytes(output[: required.value]))

    def compile_bounded_quadruped(
        self,
        descriptor: Mapping[str, Any],
    ) -> dict[str, Any]:
        return self._call_json_input(
            "ss_compile_bounded_quadruped_json",
            descriptor,
        )

    def compile_recovery_morphology_v1(
        self,
        descriptor: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Compile and evaluate one zero-world recovery morphology.

        Valid descriptors whose canonical prone pose is geometrically
        infeasible return a typed refusal receipt. Malformed descriptors raise
        LocomotionCoreError.
        """

        return self._call_json_input(
            "ss_compile_recovery_morphology_v1_json",
            descriptor,
        )

    def resolve_actuator_cap_profile_v1(
        self,
        profile_id: str,
        descriptor: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Resolve a named exact-scope cap profile or a reasoned refusal.

        A valid descriptor outside the profile's support scope is returned as
        an ordinary receipt with ``support_status=out_of_domain_morphology``.
        Malformed descriptors still raise :class:`LocomotionCoreError`.
        """

        return self._call_json_input(
            "ss_resolve_actuator_cap_profile_v1_json",
            {
                "schema_version": "sporespore_actuator_cap_profile_request_v1",
                "profile_id": profile_id,
                "descriptor": descriptor,
            },
        )

    def canonical_velocity_compose_v1(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Compose the portable command and stability residuals canonically."""

        return self._call_json_input(
            "ss_canonical_velocity_compose_v1_json",
            request,
        )

    def recovery_initialize_v1(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Initialize the exact-scope, zero-world recovery supervisor."""

        return self._call_json_input(
            "ss_recovery_initialize_v1_json",
            request,
        )

    def recovery_initialize_v2(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Initialize recovery with a required versioned morphology context."""

        return self._call_json_input(
            "ss_recovery_initialize_v2_json",
            request,
        )

    def recovery_step_v1(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Classify and advance one supplied recovery observation."""

        return self._call_json_input(
            "ss_recovery_step_v1_json",
            request,
        )

    def recovery_step_v2(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Classify and advance one morphology-aware recovery observation."""

        return self._call_json_input(
            "ss_recovery_step_v2_json",
            request,
        )

    def recovery_step_v3(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Classify and advance one morphology-aware observation-V2 step."""

        return self._call_json_input(
            "ss_recovery_step_v3_json",
            request,
        )

    def recovery_step_v4(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Classify and advance one morphology-aware observation-V3 step."""

        return self._call_json_input(
            "ss_recovery_step_v4_json",
            request,
        )

    def recovery_step_v5(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Advance observation V3 with explicit energy-partition authority."""

        return self._call_json_input(
            "ss_recovery_step_v5_json",
            request,
        )

    def recovery_collect_passive_native_v1(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Validate native owner-none descent without stepping canonical recovery."""
        if not hasattr(self._library, "ss_recovery_collect_passive_native_v1_json"):
            raise LocomotionCoreError(
                SS_INVALID_ARGUMENT, "PASSIVE_NATIVE_COLLECTION_RUNTIME_UNAVAILABLE",
                "This pinned runtime has no passive collector; select a separately bound new build.",
            )
        return self._call_json_input("ss_recovery_collect_passive_native_v1_json", request)

    def recovery_passive_entry_step_v1(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Development-only passive entry; no command, energy reset or claim."""
        if not hasattr(self._library, "ss_recovery_passive_entry_step_v1_json"):
            raise LocomotionCoreError(
                SS_INVALID_ARGUMENT, "PASSIVE_ENTRY_RUNTIME_UNAVAILABLE",
                "This pinned runtime has no passive-entry API; select a separately bound new build.",
            )
        return self._call_json_input("ss_recovery_passive_entry_step_v1_json", request)

    def recovery_r10k_entry_control_v1(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Select genuine prone or a separately supervised partial collapse."""
        name = "ss_recovery_r10k_entry_control_v1_json"
        if not hasattr(self._library, name):
            raise LocomotionCoreError(SS_INVALID_ARGUMENT, "R10K_ENTRY_RUNTIME_UNAVAILABLE",
                                      "This pinned runtime has no R10K entry API.")
        return self._call_json_input(name, request)

    def recovery_partial_fall_step_control_v1(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Validate the partial task and plan V20/V7 without canonical authority."""
        name = "ss_recovery_partial_fall_step_control_v1_json"
        if not hasattr(self._library, name):
            raise LocomotionCoreError(SS_INVALID_ARGUMENT, "PARTIAL_FALL_RUNTIME_UNAVAILABLE",
                                      "This pinned runtime has no partial-fall API.")
        return self._call_json_input(name, request)

    def recovery_r10ai_partial_entry_control_v1(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Select V25 partial control while retaining the original entry receipt."""
        name = "ss_recovery_r10ai_partial_entry_control_v1_json"
        if not hasattr(self._library, name):
            raise LocomotionCoreError(SS_INVALID_ARGUMENT, "R10AI_ENTRY_RUNTIME_UNAVAILABLE",
                                      "This pinned runtime has no R10AI entry API.")
        return self._call_json_input(name, request)

    def recovery_r10ai_partial_step_control_v1(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Validate the original partial task and plan V25/V7 without world work."""
        name = "ss_recovery_r10ai_partial_step_control_v1_json"
        if not hasattr(self._library, name):
            raise LocomotionCoreError(SS_INVALID_ARGUMENT, "R10AI_STEP_RUNTIME_UNAVAILABLE",
                                      "This pinned runtime has no R10AI step API.")
        return self._call_json_input(name, request)

    def recovery_r10aj_partial_entry_control_v1(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Select V26 partial control while retaining the original entry receipt."""
        name = "ss_recovery_r10aj_partial_entry_control_v1_json"
        if not hasattr(self._library, name):
            raise LocomotionCoreError(SS_INVALID_ARGUMENT, "R10AJ_ENTRY_RUNTIME_UNAVAILABLE",
                                      "This pinned runtime has no R10AJ entry API.")
        return self._call_json_input(name, request)

    def recovery_r10aj_partial_step_control_v1(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Validate the original partial task and plan V26/V7 without world work."""
        name = "ss_recovery_r10aj_partial_step_control_v1_json"
        if not hasattr(self._library, name):
            raise LocomotionCoreError(SS_INVALID_ARGUMENT, "R10AJ_STEP_RUNTIME_UNAVAILABLE",
                                      "This pinned runtime has no R10AJ step API.")
        return self._call_json_input(name, request)

    def recovery_r10am_partial_entry_control_v1(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Select V27 partial control while retaining the original entry receipt."""
        name = "ss_recovery_r10am_partial_entry_control_v1_json"
        if not hasattr(self._library, name):
            raise LocomotionCoreError(SS_INVALID_ARGUMENT, "R10AM_ENTRY_RUNTIME_UNAVAILABLE",
                                      "This pinned runtime has no R10AM entry API.")
        return self._call_json_input(name, request)

    def recovery_r10am_partial_step_control_v1(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Validate the original partial task and plan V27/V7 without world work."""
        name = "ss_recovery_r10am_partial_step_control_v1_json"
        if not hasattr(self._library, name):
            raise LocomotionCoreError(SS_INVALID_ARGUMENT, "R10AM_STEP_RUNTIME_UNAVAILABLE",
                                      "This pinned runtime has no R10AM step API.")
        return self._call_json_input(name, request)

    def recovery_r10ap_partial_entry_control_v1(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Select V28 partial control while retaining the original entry receipt."""
        name = "ss_recovery_r10ap_partial_entry_control_v1_json"
        if not hasattr(self._library, name):
            raise LocomotionCoreError(SS_INVALID_ARGUMENT, "R10AP_ENTRY_RUNTIME_UNAVAILABLE",
                                      "This pinned runtime has no R10AP entry API.")
        return self._call_json_input(name, request)

    def recovery_r10ap_partial_step_control_v1(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Validate the original partial task and plan V28/V7 without world work."""
        name = "ss_recovery_r10ap_partial_step_control_v1_json"
        if not hasattr(self._library, name):
            raise LocomotionCoreError(SS_INVALID_ARGUMENT, "R10AP_STEP_RUNTIME_UNAVAILABLE",
                                      "This pinned runtime has no R10AP step API.")
        return self._call_json_input(name, request)

    def recovery_r10dd_partial_entry_control_v1(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Select V29 setup control while retaining the original entry receipt."""
        name = "ss_recovery_r10dd_partial_entry_control_v1_json"
        if not hasattr(self._library, name):
            raise LocomotionCoreError(SS_INVALID_ARGUMENT, "R10DD_ENTRY_RUNTIME_UNAVAILABLE",
                                      "This pinned runtime has no R10DD entry API.")
        return self._call_json_input(name, request)

    def recovery_r10dd_partial_step_control_v1(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Validate the original partial task and plan finite V29 references without world work."""
        name = "ss_recovery_r10dd_partial_step_control_v1_json"
        if not hasattr(self._library, name):
            raise LocomotionCoreError(SS_INVALID_ARGUMENT, "R10DD_STEP_RUNTIME_UNAVAILABLE",
                                      "This pinned runtime has no R10DD step API.")
        return self._call_json_input(name, request)

    def recovery_r10q_upright_entry_control_v1(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Preserve the original entry and admit a distinct upright repair task."""
        name = "ss_recovery_r10q_upright_entry_control_v1_json"
        if not hasattr(self._library, name):
            raise LocomotionCoreError(SS_INVALID_ARGUMENT, "R10Q_UPRIGHT_ENTRY_RUNTIME_UNAVAILABLE",
                                      "This pinned runtime has no R10Q upright entry API.")
        return self._call_json_input(name, request)

    def recovery_upright_step_control_v1(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Validate the upright task and plan V20/V7 without canonical authority."""
        name = "ss_recovery_upright_step_control_v1_json"
        if not hasattr(self._library, name):
            raise LocomotionCoreError(SS_INVALID_ARGUMENT, "UPRIGHT_RECOVERY_RUNTIME_UNAVAILABLE",
                                      "This pinned runtime has no upright-recovery API.")
        return self._call_json_input(name, request)

    def recovery_r10r_upright_step_control_v1(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Validate the upright task and plan the R10R V20/V12/V7 composition without canonical authority."""
        name = "ss_recovery_r10r_upright_step_control_v1_json"
        if not hasattr(self._library, name):
            raise LocomotionCoreError(SS_INVALID_ARGUMENT, "R10R_UPRIGHT_RECOVERY_RUNTIME_UNAVAILABLE",
                                      "This pinned runtime has no R10R upright direct-rise API.")
        return self._call_json_input(name, request)

    def recovery_r10y_partial_entry_control_v1(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Retain original selection and separately plan development V21 control."""
        name = "ss_recovery_r10y_partial_entry_control_v1_json"
        if not hasattr(self._library, name):
            raise LocomotionCoreError(SS_INVALID_ARGUMENT, "R10Y_PARTIAL_RUNTIME_UNAVAILABLE",
                                      "This pinned runtime has no R10Y partial entry API.")
        return self._call_json_input(name, request)

    def recovery_r10y_partial_step_control_v1(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Validate the original partial task and plan development V21/V7 control."""
        name = "ss_recovery_r10y_partial_step_control_v1_json"
        if not hasattr(self._library, name):
            raise LocomotionCoreError(SS_INVALID_ARGUMENT, "R10Y_PARTIAL_RUNTIME_UNAVAILABLE",
                                      "This pinned runtime has no R10Y partial step API.")
        return self._call_json_input(name, request)

    def recovery_r10z_partial_entry_control_v1(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Retain original selection and separately plan development V22 control."""
        name = "ss_recovery_r10z_partial_entry_control_v1_json"
        if not hasattr(self._library, name):
            raise LocomotionCoreError(SS_INVALID_ARGUMENT, "R10Z_PARTIAL_RUNTIME_UNAVAILABLE",
                                      "This pinned runtime has no R10Z partial entry API.")
        return self._call_json_input(name, request)

    def recovery_r10z_partial_step_control_v1(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Validate the original partial task and plan development V22/V7 control."""
        name = "ss_recovery_r10z_partial_step_control_v1_json"
        if not hasattr(self._library, name):
            raise LocomotionCoreError(SS_INVALID_ARGUMENT, "R10Z_PARTIAL_RUNTIME_UNAVAILABLE",
                                      "This pinned runtime has no R10Z partial step API.")
        return self._call_json_input(name, request)

    def recovery_evaluate_trace_v1(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Replay candidate and matched-zero synthetic recovery traces."""

        return self._call_json_input(
            "ss_recovery_evaluate_trace_v1_json",
            request,
        )

    def recovery_evaluate_trace_v2(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Replay paired traces under an exact recovery-morphology context."""

        return self._call_json_input(
            "ss_recovery_evaluate_trace_v2_json",
            request,
        )

    def recovery_evaluate_trace_v3(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Replay paired morphology-aware observation-V2 traces."""

        return self._call_json_input(
            "ss_recovery_evaluate_trace_v3_json",
            request,
        )

    def recovery_evaluate_trace_v4(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Replay paired morphology-aware observation-V3 traces."""

        return self._call_json_input(
            "ss_recovery_evaluate_trace_v4_json",
            request,
        )

    def recovery_evaluate_trace_v5(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Replay observation-V3 traces with a development energy authority."""

        return self._call_json_input(
            "ss_recovery_evaluate_trace_v5_json",
            request,
        )

    def recovery_energy_balance_aggregate_v2(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Aggregate ordered measured work into a versioned V2 ledger."""

        return self._call_json_input(
            "ss_recovery_energy_balance_aggregate_v2_json",
            request,
        )

    def recovery_energy_balance_evaluate_v2(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Evaluate a supplied V2 energy ledger without applying a threshold."""

        return self._call_json_input(
            "ss_recovery_energy_balance_evaluate_v2_json",
            request,
        )

    def recovery_energy_balance_aggregate_v3(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Aggregate measured work and staging exchange into a V3 ledger."""

        return self._call_json_input(
            "ss_recovery_energy_balance_aggregate_v3_json",
            request,
        )

    def recovery_energy_balance_evaluate_v3(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Evaluate a supplied V3 energy ledger without applying a threshold."""

        return self._call_json_input(
            "ss_recovery_energy_balance_evaluate_v3_json",
            request,
        )

    def recovery_energy_balance_migrate_v1(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Explicitly migrate V1/V2 ledgers or return a typed downgrade refusal."""

        return self._call_json_input(
            "ss_recovery_energy_balance_migrate_v1_json",
            request,
        )

    def recovery_collect_native_v1(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Validate one complete, already-sampled native post-step observation."""

        return self._call_json_input(
            "ss_recovery_collect_native_v1_json",
            request,
        )

    def recovery_collect_native_v2(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Validate native recovery data under an exact morphology context."""

        return self._call_json_input(
            "ss_recovery_collect_native_v2_json",
            request,
        )

    def recovery_collect_native_v3(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Validate one source-bound MuJoCo observation-V2 publication."""

        return self._call_json_input(
            "ss_recovery_collect_native_v3_json",
            request,
        )

    def recovery_plan_control_v1(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Plan one deterministic exact-s169 engine-neutral recovery command."""

        return self._call_json_input(
            "ss_recovery_plan_control_v1_json",
            request,
        )

    def recovery_plan_control_v2(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Plan deterministic recovery control under a morphology context."""

        return self._call_json_input(
            "ss_recovery_plan_control_v2_json",
            request,
        )

    def recovery_plan_control_v3(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Plan recovery control from a validated observation V2."""

        return self._call_json_input(
            "ss_recovery_plan_control_v3_json",
            request,
        )

    def recovery_plan_stance_control_v1(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Compose stance control from an observation-V1 recovery handoff."""

        return self._call_json_input(
            "ss_recovery_plan_stance_control_v1_json",
            request,
        )

    def recovery_plan_stance_control_v2(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Compose stance control from a morphology-aware recovery handoff."""

        return self._call_json_input(
            "ss_recovery_plan_stance_control_v2_json",
            request,
        )

    def recovery_plan_stance_control_v3(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Compose stance control from an observation-V2 recovery handoff."""

        return self._call_json_input(
            "ss_recovery_plan_stance_control_v3_json",
            request,
        )

    def recovery_plan_stance_control_v4(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Bind an observation-V3 step to its observation-V2 stance projection."""

        return self._call_json_input(
            "ss_recovery_plan_stance_control_v4_json",
            request,
        )

    def canonical_velocity_host_map_v1(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Map a canonical velocity frame into a strict host profile."""

        return self._call_json_input(
            "ss_canonical_velocity_host_map_v1_json",
            request,
        )

    def resolve_adaptation_v1(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Resolve an optional provider proposal through the portable clamps.

        Provider absence or a rejected provider response is represented by a
        successful deterministic-baseline receipt; malformed host requests
        still raise :class:`LocomotionCoreError`.
        """

        return self._call_json_input(
            "ss_resolve_adaptation_v1_json",
            request,
        )

    def candidate35_profile(
        self,
        descriptor: Mapping[str, Any],
    ) -> dict[str, Any]:
        return self._call_json_input(
            "ss_candidate35_profile_json",
            descriptor,
        )

    def candidate35_step(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        return self._call_json_input(
            "ss_candidate35_step_json",
            request,
        )

    def balanced_wave_profile(
        self,
        descriptor: Mapping[str, Any],
    ) -> dict[str, Any]:
        _warn_deprecated(
            "LocomotionCore.balanced_wave_profile",
            "LocomotionCore.balanced_wave_policy_profile",
        )
        return self._call_json_input(
            "ss_balanced_wave_profile_json",
            descriptor,
        )

    def canonicalize_json(
        self,
        value: Any,
    ) -> dict[str, Any]:
        """Canonicalize and SHA-256 arbitrary JSON through the core authority."""

        return self._call_json_input(
            "ss_canonicalize_json",
            {
                "schema_version": "sporespore_canonical_json_request_v1",
                "value": value,
            },
        )

    def balanced_wave_policy_profile(
        self,
        policy_id: str,
        descriptor: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Derive one explicit named policy profile for a morphology."""

        return self._call_json_input(
            "ss_balanced_wave_policy_profile_json",
            {
                "schema_version": (
                    "sporespore_balanced_wave_policy_profile_request_v1"
                ),
                "policy_id": policy_id,
                "descriptor": descriptor,
            },
        )

    def balanced_wave_policy_initial_memory(
        self,
        policy_id: str,
        descriptor: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Return fresh memory whose schema is selected by the named policy."""

        return self._call_json_input(
            "ss_balanced_wave_policy_initial_memory_json",
            {
                "schema_version": (
                    "sporespore_balanced_wave_policy_initial_memory_request_v1"
                ),
                "policy_id": policy_id,
                "descriptor": descriptor,
            },
        )

    def balanced_wave_step(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        _warn_deprecated(
            "LocomotionCore.balanced_wave_step",
            "LocomotionCore.balanced_wave_policy_step",
        )
        return self._call_json_input(
            "ss_balanced_wave_step_json",
            request,
        )

    def observe_stability_v2(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Observe support geometry without modifying engine state."""

        return self._call_json_input(
            "ss_observe_stability_v2_json",
            request,
        )

    def command_centroidal_support_v2(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Compute bounded contact-force commands, not measured loads."""

        return self._call_json_input(
            "ss_command_centroidal_support_v2_json",
            request,
        )

    def balanced_wave_policy_step(
        self,
        policy_id: str,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Execute one explicit named policy without legacy-ID fallback."""

        strict_request = dict(request)
        strict_request["schema_version"] = (
            "sporespore_balanced_wave_policy_step_request_v1"
        )
        strict_request["policy_id"] = policy_id
        return self._call_json_input(
            "ss_balanced_wave_policy_step_json",
            strict_request,
        )

    def balanced_wave_policy_step_with_measured_body(
        self,
        policy_id: str,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Use v3 with an explicit floor and synchronized measured body frame.

        The native boundary validates both required frames. This helper does
        not manufacture measurements or upgrade the historical v1 request.
        """
        strict_request = dict(request)
        strict_request["schema_version"] = "sporespore_balanced_wave_policy_step_request_v3"
        strict_request["policy_id"] = policy_id
        return self._call_json_input("ss_balanced_wave_policy_step_json", strict_request)

    def create_balanced_wave_policy_session(
        self,
        policy_id: str,
        descriptor: Mapping[str, Any],
    ) -> "BalancedWavePolicySession":
        """Compile one reusable policy/morphology session behind the C ABI."""

        input_bytes = self._input_bytes(
            {
                "schema_version": (
                    "sporespore_balanced_wave_policy_session_create_request_v1"
                ),
                "policy_id": policy_id,
                "descriptor": descriptor,
            }
        )
        input_array = (ctypes.c_uint8 * len(input_bytes)).from_buffer_copy(input_bytes)
        handle = ctypes.c_uint64(0)
        status = self._library.ss_balanced_wave_policy_session_create_json(
            input_array,
            len(input_bytes),
            ctypes.byref(handle),
        )
        if status != SS_OK or handle.value == 0:
            raise LocomotionCoreError(
                status,
                "ABI_CONTROLLER_SESSION_CREATE_FAILED",
                "the core rejected the policy or descriptor",
            )
        return BalancedWavePolicySession(self, handle.value)

    def plan_scheduled_load_transfer_v1(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Plan scheduler-aware load transfer without modifying engine state."""

        _warn_deprecated(
            "LocomotionCore.plan_scheduled_load_transfer_v1",
            "LocomotionCore.plan_scheduled_load_transfer_v3",
        )
        return self._call_json_input(
            "ss_plan_scheduled_load_transfer_v1_json",
            request,
        )

    def plan_scheduled_load_transfer_v2(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Plan load transfer with typed availability and safe-zero receipts."""

        _warn_deprecated(
            "LocomotionCore.plan_scheduled_load_transfer_v2",
            "LocomotionCore.plan_scheduled_load_transfer_v3",
        )
        return self._call_json_input(
            "ss_plan_scheduled_load_transfer_v2_json",
            request,
        )

    def plan_scheduled_load_transfer_v3(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Plan load transfer even when the host observation is unavailable."""

        return self._call_json_input(
            "ss_plan_scheduled_load_transfer_v3_json",
            request,
        )

    def map_endpoint_force_to_joint_v2(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Map endpoint-force commands to generalized joint torques."""

        _warn_deprecated(
            "LocomotionCore.map_endpoint_force_to_joint_v2",
            "LocomotionCore.map_endpoint_force_to_joint_v3",
        )
        return self._call_json_input(
            "ss_map_endpoint_force_to_joint_v2_json",
            request,
        )

    def map_endpoint_force_to_joint_v3(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Map active support forces and explicit inactive-contact zeros."""

        return self._call_json_input(
            "ss_map_endpoint_force_to_joint_v3_json",
            request,
        )

    def bound_stability_influence_v2(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Bound and slew-limit proposed actuator correction contributions."""

        return self._call_json_input(
            "ss_bound_stability_influence_v2_json",
            request,
        )

    def bound_stability_influence_v3(
        self,
        request: Mapping[str, Any],
    ) -> dict[str, Any]:
        """Globally scale, then bound and slew-limit actuator corrections."""

        return self._call_json_input(
            "ss_bound_stability_influence_v3_json",
            request,
        )

    def _call_no_input(self, name: str) -> dict[str, Any]:
        function = getattr(self._library, name)
        required = ctypes.c_size_t(0)
        first_status = function(None, 0, ctypes.byref(required))
        if first_status != SS_BUFFER_TOO_SMALL or required.value == 0:
            raise LocomotionCoreError(
                first_status,
                "ABI_SIZE_QUERY_FAILED",
                f"{name} did not return a nonzero required length",
            )
        output = (ctypes.c_uint8 * required.value)()
        second_status = function(
            output,
            len(output),
            ctypes.byref(required),
        )
        return self._decode(second_status, bytes(output[: required.value]))

    def candidate35_initial_memory(self) -> dict[str, Any]:
        return self._call_no_input("ss_candidate35_initial_memory_json")

    def balanced_wave_initial_memory(self) -> dict[str, Any]:
        return self._call_no_input("ss_balanced_wave_initial_memory_json")

    def gq15_domain_certificate(self) -> dict[str, Any]:
        return self._call_no_input("ss_gq15_domain_certificate_json")

    def recovery_development_profile_v1(self) -> dict[str, Any]:
        """Return the frozen development and held-out recovery profile."""

        return self._call_no_input("ss_recovery_development_profile_v1_json")


class BalancedWavePolicySession:
    """Owned process-local controller handle with explicit per-step memory."""

    def __init__(self, core: LocomotionCore, handle: int) -> None:
        if handle <= 0:
            raise ValueError("session handle must be nonzero")
        self._core = core
        self._handle = handle

    @property
    def closed(self) -> bool:
        return self._handle == 0

    def step(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Step the compiled controller; descriptor and policy are omitted."""

        return self._step_version(request, "sporespore_balanced_wave_policy_session_step_request_v1")

    def step_with_measured_body(self, request: Mapping[str, Any]) -> dict[str, Any]:
        """Step v3 using the caller's explicit floor and measured body frame."""

        return self._step_version(request, "sporespore_balanced_wave_policy_session_step_request_v3")

    def _step_version(self, request: Mapping[str, Any], schema: str) -> dict[str, Any]:

        if self.closed:
            raise LocomotionCoreError(
                SS_INVALID_ARGUMENT,
                "ABI_CONTROLLER_SESSION_CLOSED",
                "the controller session has already been destroyed",
            )
        strict_request = dict(request)
        strict_request["schema_version"] = schema
        input_bytes = self._core._input_bytes(strict_request)
        input_array = (ctypes.c_uint8 * len(input_bytes)).from_buffer_copy(input_bytes)
        function = self._core._library.ss_balanced_wave_policy_session_step_json
        required = ctypes.c_size_t(0)
        first_status = function(
            self._handle,
            input_array,
            len(input_bytes),
            None,
            0,
            ctypes.byref(required),
        )
        if first_status != SS_BUFFER_TOO_SMALL or required.value == 0:
            raise LocomotionCoreError(
                first_status,
                "ABI_SIZE_QUERY_FAILED",
                "session step did not return a nonzero required length",
            )
        output = (ctypes.c_uint8 * required.value)()
        second_status = function(
            self._handle,
            input_array,
            len(input_bytes),
            output,
            len(output),
            ctypes.byref(required),
        )
        return self._core._decode(
            second_status,
            bytes(output[: required.value]),
        )

    def close(self) -> None:
        """Destroy the opaque handle exactly once; repeated close is harmless."""

        if self.closed:
            return
        handle = self._handle
        status = self._core._library.ss_balanced_wave_policy_session_destroy(handle)
        if status != SS_OK:
            raise LocomotionCoreError(
                status,
                "ABI_CONTROLLER_SESSION_DESTROY_FAILED",
                f"session handle {handle} was not destroyed",
            )
        self._handle = 0

    def __enter__(self) -> "BalancedWavePolicySession":
        if self.closed:
            raise LocomotionCoreError(
                SS_INVALID_ARGUMENT,
                "ABI_CONTROLLER_SESSION_CLOSED",
                "cannot enter a closed controller session",
            )
        return self

    def __exit__(self, exc_type: object, exc: object, traceback: object) -> None:
        self.close()

    def __del__(self) -> None:
        if getattr(self, "_handle", 0) == 0:
            return
        try:
            self.close()
        except Exception:
            # Destructors cannot report reliably. Explicit close/context-manager
            # use retains the typed error path.
            pass


def reference_quadruped(morphology_id: str = "python_reference") -> dict[str, Any]:
    """Return the exact GQ15 reference point in descriptor-schema form."""

    return {
        "schema_version": "sporespore_bounded_quadruped_descriptor_v1",
        "morphology_id": morphology_id,
        "torso_length_scale": 1.0,
        "torso_width_scale": 1.0,
        "upper_length_fraction": 18.0 / 35.0,
        "hip_span_scale": 1.0,
        "foot_radius_scale": 1.0,
        "front_limb_mass_scale": 1.0,
    }


def r23d60_selected_s169_quadruped() -> dict[str, Any]:
    """Return the only descriptor supported by the first selected cap profile."""

    return {
        "schema_version": "sporespore_bounded_quadruped_descriptor_v1",
        "morphology_id": "qsdk_r05_generated_s169",
        "torso_length_scale": 1.0041015625,
        "torso_width_scale": 1.0031893004115227,
        "upper_length_fraction": 0.5219571428571428,
        "hip_span_scale": 0.9856413994169096,
        "foot_radius_scale": 0.9987180691209617,
        "front_limb_mass_scale": 0.975022758306782,
    }


def r24d22_recovery_s169_morphology() -> dict[str, Any]:
    """Return the exact zero-world recovery-morphology reference descriptor."""

    return {
        "schema_version": "sporespore_recovery_morphology_descriptor_v1",
        "recovery_morphology_id": R24D22_RECOVERY_S169_MORPHOLOGY_ID,
        "base_descriptor": r23d60_selected_s169_quadruped(),
        "joint_authority": {
            "hip_anchor_parent_y_m": 0.0,
            "hip_limit_magnitude_rad": 1.60,
            "knee_limit_magnitude_rad": 1.10,
        },
        "canonical_prone_pose": {
            "front_hip_angle_rad": 1.55,
            "front_knee_angle_rad": 1.10,
            "rear_hip_angle_rad": -1.55,
            "rear_knee_angle_rad": -1.10,
        },
    }

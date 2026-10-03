"""Fail-closed MuJoCo 3.11 sparse actuator-moment expansion."""

from __future__ import annotations

from dataclasses import dataclass
import math
from typing import Any, Callable, Mapping, Sequence

import mujoco
import numpy as np


PROFILE_ID = "mujoco_3_11_sparse_actuator_moment_to_dense_v1"
RECEIPT_SCHEMA = "sporespore_mujoco_sparse_actuator_moment_expansion_v1"


class SparseActuatorMomentError(ValueError):
    """Stable fail-closed error for malformed sparse transmission data."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise SparseActuatorMomentError(code)


def _dimension(value: Any, name: str, *, permit_zero: bool = False) -> int:
    _require(isinstance(value, int) and not isinstance(value, bool), f"{name}_TYPE")
    _require(value >= 0 if permit_zero else value > 0, f"{name}_RANGE")
    return value


def _integer_vector(value: Any, name: str) -> np.ndarray:
    raw = np.asarray(value)
    _require(raw.ndim == 1, f"{name}_RANK")
    _require(np.issubdtype(raw.dtype, np.integer), f"{name}_INTEGER")
    converted = raw.astype(np.int32, copy=True)
    _require(np.array_equal(raw, converted), f"{name}_INT32_RANGE")
    return converted


@dataclass(frozen=True)
class SparseActuatorMomentExpansionV1:
    """Immutable sparse input plus independently cross-checked dense result."""

    nout: int
    nv: int
    nJmom: int
    values: tuple[float, ...]
    rownnz: tuple[int, ...]
    rowadr: tuple[int, ...]
    colind: tuple[int, ...]
    dense: tuple[tuple[float, ...], ...]

    def dense_array(self) -> np.ndarray:
        return np.asarray(self.dense, dtype=np.float64).copy()

    def receipt_v1(self) -> dict[str, Any]:
        return {
            "schema_version": RECEIPT_SCHEMA,
            "profile_id": PROFILE_ID,
            "public_expansion_function": "mju_sparse2dense",
            "independent_dense_crosscheck_passed": True,
            "nout": self.nout,
            "nv": self.nv,
            "nJmom": self.nJmom,
            "sparse_values": list(self.values),
            "moment_rownnz": list(self.rownnz),
            "moment_rowadr": list(self.rowadr),
            "moment_colind": list(self.colind),
            "dense_actuator_moment": [list(row) for row in self.dense],
        }


def expand_sparse_actuator_moment_v1(
    *,
    values: Sequence[float],
    rownnz: Sequence[int],
    rowadr: Sequence[int],
    colind: Sequence[int],
    nout: int,
    nv: int,
    nJmom: int,
    sparse2dense: Callable[..., Any] | None = None,
) -> SparseActuatorMomentExpansionV1:
    """Validate MuJoCo CSR-like storage, expand it, and cross-check independently."""

    rows = _dimension(nout, "QSDK_R24D35_NOUT")
    columns = _dimension(nv, "QSDK_R24D35_NV")
    nonzeros = _dimension(nJmom, "QSDK_R24D35_NJMOM", permit_zero=True)
    sparse_values = np.asarray(values, dtype=np.float64)
    _require(sparse_values.ndim == 1, "QSDK_R24D35_SPARSE_VALUE_RANK")
    sparse_values = sparse_values.copy()
    row_counts = _integer_vector(rownnz, "QSDK_R24D35_ROWNNZ")
    row_addresses = _integer_vector(rowadr, "QSDK_R24D35_ROWADR")
    column_indices = _integer_vector(colind, "QSDK_R24D35_COLIND")
    _require(sparse_values.shape == (nonzeros,), "QSDK_R24D35_SPARSE_VALUE_COUNT")
    _require(column_indices.shape == (nonzeros,), "QSDK_R24D35_COLIND_COUNT")
    _require(row_counts.shape == (rows,), "QSDK_R24D35_ROWNNZ_COUNT")
    _require(row_addresses.shape == (rows,), "QSDK_R24D35_ROWADR_COUNT")
    _require(bool(np.all(np.isfinite(sparse_values))), "QSDK_R24D35_SPARSE_VALUE_NONFINITE")
    _require(bool(np.all(row_counts >= 0)), "QSDK_R24D35_ROWNNZ_NEGATIVE")
    _require(int(np.sum(row_counts, dtype=np.int64)) == nonzeros, "QSDK_R24D35_ROWNNZ_TOTAL")

    expected_address = 0
    independent = np.zeros((rows, columns), dtype=np.float64)
    for row in range(rows):
        count = int(row_counts[row])
        address = int(row_addresses[row])
        _require(address == expected_address, "QSDK_R24D35_ROWADR_NOT_PACKED")
        end = address + count
        _require(end <= nonzeros, "QSDK_R24D35_ROW_RANGE")
        selected_columns = column_indices[address:end]
        _require(
            bool(np.all((selected_columns >= 0) & (selected_columns < columns))),
            "QSDK_R24D35_COLIND_RANGE",
        )
        _require(
            len(set(int(item) for item in selected_columns)) == count,
            "QSDK_R24D35_COLIND_DUPLICATE",
        )
        independent[row, selected_columns] = sparse_values[address:end]
        expected_address = end
    _require(expected_address == nonzeros, "QSDK_R24D35_ROW_PACKING_INCOMPLETE")

    dense = np.zeros((rows, columns), dtype=np.float64)
    converter = mujoco.mju_sparse2dense if sparse2dense is None else sparse2dense
    _require(callable(converter), "QSDK_R24D35_PUBLIC_EXPANSION_NOT_CALLABLE")
    try:
        converter(dense, sparse_values, row_counts, row_addresses, column_indices)
    except Exception as error:
        raise SparseActuatorMomentError("QSDK_R24D35_PUBLIC_EXPANSION_FAILED") from error
    _require(dense.shape == (rows, columns), "QSDK_R24D35_DENSE_SHAPE")
    _require(bool(np.all(np.isfinite(dense))), "QSDK_R24D35_DENSE_NONFINITE")
    _require(np.array_equal(dense, independent), "QSDK_R24D35_INDEPENDENT_DENSE_MISMATCH")
    return SparseActuatorMomentExpansionV1(
        nout=rows,
        nv=columns,
        nJmom=nonzeros,
        values=tuple(float(item) for item in sparse_values),
        rownnz=tuple(int(item) for item in row_counts),
        rowadr=tuple(int(item) for item in row_addresses),
        colind=tuple(int(item) for item in column_indices),
        dense=tuple(tuple(float(item) for item in row) for row in dense),
    )


def validate_sparse_actuator_moment_receipt_v1(
    receipt: Mapping[str, Any],
) -> SparseActuatorMomentExpansionV1:
    """Re-expand a serialized receipt and require its retained dense matrix exactly."""

    _require(isinstance(receipt, Mapping), "QSDK_R24D35_RECEIPT_MAPPING")
    _require(receipt.get("schema_version") == RECEIPT_SCHEMA, "QSDK_R24D35_RECEIPT_SCHEMA")
    _require(receipt.get("profile_id") == PROFILE_ID, "QSDK_R24D35_RECEIPT_PROFILE")
    _require(receipt.get("public_expansion_function") == "mju_sparse2dense", "QSDK_R24D35_RECEIPT_FUNCTION")
    _require(receipt.get("independent_dense_crosscheck_passed") is True, "QSDK_R24D35_RECEIPT_CROSSCHECK")
    try:
        expanded = expand_sparse_actuator_moment_v1(
            values=receipt["sparse_values"],
            rownnz=receipt["moment_rownnz"],
            rowadr=receipt["moment_rowadr"],
            colind=receipt["moment_colind"],
            nout=receipt["nout"],
            nv=receipt["nv"],
            nJmom=receipt["nJmom"],
        )
        retained = np.asarray(receipt["dense_actuator_moment"], dtype=np.float64)
    except SparseActuatorMomentError:
        raise
    except (KeyError, TypeError, ValueError, OverflowError) as error:
        raise SparseActuatorMomentError("QSDK_R24D35_RECEIPT_MALFORMED") from error
    _require(retained.shape == (expanded.nout, expanded.nv), "QSDK_R24D35_RECEIPT_DENSE_SHAPE")
    _require(bool(np.all(np.isfinite(retained))), "QSDK_R24D35_RECEIPT_DENSE_NONFINITE")
    _require(np.array_equal(retained, expanded.dense_array()), "QSDK_R24D35_RECEIPT_DENSE_MISMATCH")
    _require(all(math.isfinite(value) for row in expanded.dense for value in row), "QSDK_R24D35_EXPANSION_NONFINITE")
    return expanded


def sparse_actuator_moment_zero_world_controls_v1() -> tuple[dict[str, bool], dict[str, Any]]:
    """Exercise the complete reusable sparse-expansion mutation surface."""

    common: dict[str, Any] = {
        "values": [2.0, -1.0, 4.0, 3.0],
        "rownnz": [1, 2, 1],
        "rowadr": [0, 1, 3],
        "colind": [0, 1, 4, 3],
        "nout": 3,
        "nv": 5,
        "nJmom": 4,
    }
    expansion = expand_sparse_actuator_moment_v1(**common)

    def rejected(mutation: Mapping[str, Any], expected: str) -> bool:
        arguments = dict(common)
        arguments.update(mutation)
        try:
            expand_sparse_actuator_moment_v1(**arguments)
        except SparseActuatorMomentError as error:
            return expected in str(error)
        return False

    def corrupt_converter(dense: np.ndarray, *_arguments: object) -> None:
        dense[:] = 1.0

    converter_rejected = False
    try:
        expand_sparse_actuator_moment_v1(
            **common,
            sparse2dense=corrupt_converter,
        )
    except SparseActuatorMomentError as error:
        converter_rejected = "QSDK_R24D35_INDEPENDENT_DENSE_MISMATCH" in str(error)

    expected_dense = (
        (2.0, 0.0, 0.0, 0.0, 0.0),
        (0.0, -1.0, 0.0, 0.0, 4.0),
        (0.0, 0.0, 0.0, 3.0, 0.0),
    )
    controls = {
        "exact_expansion_and_receipt_replay": (
            expansion.dense == expected_dense
            and validate_sparse_actuator_moment_receipt_v1(expansion.receipt_v1())
            == expansion
        ),
        "malformed_sparse_representation_refused": all(
            (
                rejected({"values": [2.0]}, "QSDK_R24D35_SPARSE_VALUE_COUNT"),
                rejected({"rownnz": [1, 1, 1]}, "QSDK_R24D35_ROWNNZ_TOTAL"),
                rejected({"rowadr": [0, 2, 3]}, "QSDK_R24D35_ROWADR_NOT_PACKED"),
                rejected({"colind": [0, 1, 5, 3]}, "QSDK_R24D35_COLIND_RANGE"),
                rejected({"colind": [0, 1, 1, 3]}, "QSDK_R24D35_COLIND_DUPLICATE"),
                rejected({"nout": 0}, "QSDK_R24D35_NOUT_RANGE"),
                rejected({"nv": 0}, "QSDK_R24D35_NV_RANGE"),
                rejected({"nJmom": 3}, "QSDK_R24D35_SPARSE_VALUE_COUNT"),
                rejected(
                    {"values": [2.0, math.nan, 4.0, 3.0]},
                    "QSDK_R24D35_SPARSE_VALUE_NONFINITE",
                ),
            )
        ),
        "public_converter_output_crosschecked": converter_rejected,
    }
    return controls, {
        "profile_id": PROFILE_ID,
        "synthetic_sparse_nonzero_count": expansion.nJmom,
        "synthetic_dense_shape": [expansion.nout, expansion.nv],
        "synthetic_dense_actuator_moment": [list(row) for row in expansion.dense],
    }

from __future__ import annotations

from sdk.conformance.content_addressed_zero_world_closure import core_canonical_bytes


def test_core_canonical_bytes_matches_serde_json_numeric_spelling() -> None:
    value = {
        "fixed_negative_five": 1.234567890123456e-5,
        "negative_exponent": -3.725290298461914e-8,
        "positive_exponent": 1.234567890123456e20,
        "small_positive": 1.4901161193847656e-8,
    }

    assert core_canonical_bytes(value) == (
        b'{"fixed_negative_five":0.000012345678901235,'
        b'"negative_exponent":-3.7252902984619e-8,'
        b'"positive_exponent":1.2345678901235e+20,'
        b'"small_positive":1.4901161193848e-8}'
    )

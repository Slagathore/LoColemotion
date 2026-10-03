"""Exclude synthetic report identities before any R10AM launch or child claim.

This filter grants no authority. Full declaration, source, runtime, safety,
handoff and one-use reservation checks remain mandatory after it passes.
"""
import re

import r10am_report_fixtures as fixtures


def require_physical_declaration(value):
    if type(value) is not dict:
        raise ValueError('R10AM_PHYSICAL_IDENTITY_DECLARATION_KIND')
    # Even a false flag is a fixture-shaped declaration, not a launch proposal.
    if 'report_fixture_only' in value:
        raise ValueError('R10AM_PHYSICAL_IDENTITY_SYNTHETIC_DECLARATION')
    attempt = value.get('attempt_id')
    if type(attempt) is not str or re.fullmatch(r'[0-9a-f]{32}', attempt) is None:
        raise ValueError('R10AM_PHYSICAL_IDENTITY_ATTEMPT_ID')
    try:
        reserved = fixtures.reserved_for_fixture(attempt)
    except (AssertionError, KeyError, TypeError, ValueError, OSError) as error:
        raise ValueError('R10AM_PHYSICAL_IDENTITY_FIXTURE_CATALOG_INVALID') from error
    if reserved:
        raise ValueError('R10AM_PHYSICAL_IDENTITY_RESERVED_FIXTURE_ID')

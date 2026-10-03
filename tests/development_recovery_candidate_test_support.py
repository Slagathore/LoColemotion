"""One explicit test profile for all candidate suites; never a physical selector."""
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import development_recovery_candidate as candidate


def selected():
    path = ROOT / os.environ.get('SPORESPORE_DEVELOPMENT_TEST_CANDIDATE',
                                'sdk/development/recovery_candidates/v8_harness_v1.json')
    return candidate.selection(candidate.reference_for_path(path))


def arguments(selection):
    reference = selection['candidate_profile']
    return [reference['resource'], reference['raw_sha256']]

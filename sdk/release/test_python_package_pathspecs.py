"""Exercise the Python consumer with the packager's inclusion/exclusion cases."""
import json
import sys
from pathlib import Path

SDK = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SDK))
from portable_api.conformance import ConformanceError, validate_package_pathspecs

inventory = json.loads((SDK / "release/quadruped_package_source_inventory_v1.json").read_text())
validate_package_pathspecs(inventory["git_pathspecs"])
bad = ["../scripts/**", "scripts/**", ":(exclude)../scripts/**",
       ":(exclude)sdk/../../scripts/**", "sdk/../scripts/**", "sdk/./core/**",
       "sdk\\core\\**", ":(top)sdk/**", ":(exclude,top)sdk/**", "C:/sdk/**", "sdk/:*/**"]
cases = [["sdk/core/**", value] for value in bad]
cases += [["sdk/core/**", "sdk/core/**"], [], [None]]
for case in cases:
    try:
        validate_package_pathspecs(case)
    except ConformanceError:
        continue
    raise AssertionError(f"Unsafe selector accepted: {case}")
print(f"PYTHON_PACKAGE_PATHSPECS_PASS negative_controls={len(cases)} worlds=0")

"""Select the pinned generic extension before any automatic ProxQP import."""
import importlib
import importlib.metadata as metadata
import importlib.util
from pathlib import Path
import sys
import numpy  # Keep the upstream NumPy/OpenMP initialization order.

def load():
    dist=metadata.distribution("proxsuite")
    if dist.version!="0.7.2":raise ValueError("Generic ProxQP requires the pinned wheel")
    entries=[f for f in dist.files if f.as_posix().endswith("/proxsuite/__init__.py")]
    if len(entries)!=1:raise ValueError("Generic ProxQP package identity")
    directory=Path(dist.locate_file(entries[0])).resolve().parent
    expected=directory/"proxsuite_pywrap.cp311-win_amd64.pyd"
    if not expected.is_file():raise ValueError("Generic ProxQP extension missing")
    if "proxsuite" in sys.modules:
        module=sys.modules["proxsuite"]
        if Path(module.__file__).resolve()!=expected:raise ValueError("A conflicting ProxQP backend is already loaded")
        return module
    # Register the package without running its automatic SIMD selector.
    spec=importlib.util.spec_from_file_location("proxsuite",directory/"__init__.py",
        submodule_search_locations=[str(directory)])
    package=importlib.util.module_from_spec(spec);sys.modules["proxsuite"]=package
    try:
        generic=importlib.import_module("proxsuite.proxsuite_pywrap")
        package.__dict__.update(generic.__dict__)
        if Path(package.__file__).resolve()!=expected:raise ValueError("Generic ProxQP backend identity")
        return package
    except BaseException:
        sys.modules.pop("proxsuite",None)
        raise

"""Selected V25 fixtures and unchanged crossed-input controls; zero worlds."""
import r10ai_native_component as component
import r10ag_native_interface as predecessor

def inputs():
    binding, current, _, _, engine = component.inputs()
    import r10ai_host_runtime as host
    assert engine == host.expected_binding()['images']['godot_engine']
    return binding['runtime'], binding['compiled_fixtures'], current

def cases(fixtures):
    for label, method, request, expected in predecessor.cases(fixtures):
        yield label, method.replace('r10aa', 'r10ai'), request, expected

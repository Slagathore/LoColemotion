"""Selected V28 fixtures and unchanged crossed-input controls; zero worlds."""
import r10ap_native_component as component
import r10ag_native_interface as predecessor

def inputs():
    binding, current, _, _, engine = component.inputs()
    import r10ap_host_runtime as host
    assert engine == host.expected_binding()['images']['godot_engine']
    return binding['runtime'], binding['compiled_fixtures'], current

def cases(fixtures):
    _, current, _, old, _ = component.inputs()
    assert fixtures == current
    for case in component.cases(current, old):
        if case['id'].startswith('abi_'):
            yield case['id'].removeprefix('abi_'), 'ss_' + case['method'] + '_json', case['request'], case['expected']

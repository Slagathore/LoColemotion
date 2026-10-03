"""Read-only audit of the retained R10DB original and complete cold replay."""
import json
from pathlib import Path
import r10db_native_reference_angles as M


def audit():
    matrix=M.C.read(M.C.ROOT/'sdk/release/quadruped_support_matrix.json')
    closure=matrix['locomotion_modes']['r10db_native_reference_angles']
    result=M.C.read(M.RESULT);declaration=M.C.read(M.STUDY)
    for key in ('declaration','implementation','result','closure_audit'):
        binding=closure[key];assert M.C.bind(binding['path'])==binding
    for binding in declaration['dependencies']:assert M.C.bind(binding['path'])==binding
    assert M.runtime()==declaration['runtime_images']
    assert closure['summary']==result['summary'] and closure['controls']==result['controls']
    assert result['declaration']==M.C.bind(M.STUDY)
    assert result['implementation']==M.C.bind(M.__file__)
    assert result['controls']==M.controls()
    for name in ('original_execution','cold_replay'):
        bindings=closure[name]
        for binding in bindings:assert M.C.bind(binding['path'])==binding
        files={Path(b['path']).name:Path(b['path']) for b in bindings}
        assert M.C.read(files['execution.json'])['return_code']==0
        assert M.C.read(files['native_execution.json'])==dict(return_code=0,timed_out=False)
        assert M.C.read(files['native_lock.json'])['acquired'] is True
        assert files['stderr.txt'].read_bytes()==files['native_stderr.txt'].read_bytes()==b''
        assert M.digest(files['native_input.json'].read_bytes())==result['transport']['input']
        assert M.digest(files['native_output.json'].read_bytes())==result['transport']['output']
        for source in (Path(M.__file__),M.STUDY,M.SCRIPT,M.WRAPPER):
            assert source.read_bytes()==files[source.name].read_bytes()
        payload=M.C.read(files['native_input.json']);M.validate_inputs(payload)
        native=M.C.read(files['native_output.json'])
        assert native['checks']==result['native_controls'] and all(native['checks'].values())
        assert [r['native_joint_positions_rad'] for r in native['poses']]==[r['native_joint_positions_rad'] for r in result['poses']]
        assert M.C.read(files['stdout.json'])['summary']==result['summary']
    assert len(result['poses'])==119
    assert [r['admitted'] for r in result['source_phases']]==[69,24,25]
    assert [r['refused_excluded'] for r in result['source_phases']]==[1,0,1]
    for key,value in M.CLAIMS.items():assert result[key]==closure[key]==value
    return dict(ok=True,endpoint_poses=119,complete_cold_replay=True,
        reference_rate_violation_count=len(result['summary']['reference_rate_violations']),**M.CLAIMS)


if __name__=='__main__':print(json.dumps(audit(),indent=2))

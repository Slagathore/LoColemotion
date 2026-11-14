"""Instrument the isolated live diagnostic without changing calls or values.

The timers separate native SDK calls from Godot JSON serialization. This is a
development measurement only; the original scientific source is not edited.
"""
import re


WALKING_STAGES = ('sample', 'controller_step', 'motor_application', 'motor_readback')


def instrument_walking(project):
    """Time the separate walking instance after its first-command handoff.

    Keep each original statement verbatim between timer markers. The returned
    controller values and motor calls remain unchanged; only diagnostics grow.
    """
    walking = project / 'sdk/explorer/studio/godot_live_walking.gd'
    source = walking.read_text(encoding='utf-8-sig')
    if '_studio_profile_' in source:
        raise ValueError('Walking profile already installed')
    statements = [
        '\tvar sample: Dictionary=facade._sample_walking_input_v1(local_step,amplitude,phase_mode)\n',
        '\tvar step: Dictionary=facade._adapter.step(sample,local_step,{},facade._initial_gait_steps,0.0,{},true)\n',
        '\tvar applied: Dictionary=facade._adapter.apply_authority(step,facade._binding.joint_state_by_legacy_id,true,facade._authorized_host_cap_by_actuator_id)\n',
        '\tif not motor_readbacks_valid(step.native_output.actuation.ordered_commands,applied,facade._authorized_host_cap_by_actuator_id):return {"ok":false,"failure_code":"LIVE_WALK_MOTOR_READBACK"}\n',
    ]
    for name, statement in zip(WALKING_STAGES, statements, strict=True):
        if source.count(statement) != 1:
            raise ValueError('Walking timing statement changed: '+name)
        # On a refused readback the original early return still runs. Completed
        # rows measure only successful readbacks; a failed session has no timing
        # comparison authority and retains its original failure.
        before = f'\t# _studio_profile_begin {name}\n\tvar _studio_profile_{name}_start := Time.get_ticks_usec()\n\t# _studio_profile_end\n'
        after = f'\t# _studio_profile_begin {name}\n\t_studio_profile_record("{name}", Time.get_ticks_usec()-_studio_profile_{name}_start)\n\t# _studio_profile_end\n'
        source = source.replace(statement, before+statement+after, 1)
    source += '''
# _studio_profile_begin collector
static var _studio_profile_rows: Dictionary = {}

static func _studio_profile_record(stage: String, elapsed_us: int) -> void:
	var row: Dictionary = _studio_profile_rows.get(stage, {"calls":0,"total_us":0,"maximum_us":0})
	row.calls += 1
	row.total_us += elapsed_us
	row.maximum_us = maxi(row.maximum_us,elapsed_us)
	_studio_profile_rows[stage] = row
# _studio_profile_end
'''
    worker = project / 'sdk/explorer/native_recovery/worker.gd'
    worker_source = worker.read_text(encoding='utf-8-sig')
    start = '\t\t_live_commands=1\n'
    terminal = '\tif value.get("message_type")=="completed":\n'
    if worker_source.count(start) != 1 or worker_source.count(terminal) != 1:
        raise ValueError('Walking profiling handoff or terminal hook changed')
    worker_source = worker_source.replace(start, start+'\t\tLiveWalk._studio_profile_rows.clear()\n', 1)
    worker_source = worker_source.replace(terminal, terminal+'''		# Snapshot before terminal zero-world controls add their own calls.
		value.summary["studio_live_walking_profile"]={"stages":LiveWalk._studio_profile_rows.duplicate(true),
			"first_local_command":2,"last_local_command":_live_commands,
			"preflight_and_first_command_excluded":true,"solver_inputs_changed":false,
			"scope":"Wall timers in the isolated diagnostic; stages partition control_step, not native solver time. Timer overhead is included in the enclosing walking clock."}
''', 1)
    walking.write_text(source, encoding='utf-8', newline='\n')
    worker.write_text(worker_source, encoding='utf-8', newline='\n')
    return list(WALKING_STAGES)


def validate_walking_profile(summary, walking_commands):
    profile = summary['studio_live_walking_profile']
    if (profile['first_local_command'] != 2 or profile['last_local_command'] != walking_commands
            or profile['preflight_and_first_command_excluded'] is not True
            or profile['solver_inputs_changed'] is not False
            or set(profile['stages']) != set(WALKING_STAGES)):
        raise ValueError('Walking profile scope or stage population')
    for row in profile['stages'].values():
        if (row['calls'] != walking_commands-1 or any(type(row[k]) is not int for k in ('calls', 'total_us', 'maximum_us'))
                or not 0 <= row['maximum_us'] <= row['total_us']):
            raise ValueError('Walking profile call population or clocks')
    return profile


def instrument(project):
    wrapper = project / 'sdk/explorer/native_recovery/memoized_sdk.gd'
    source = wrapper.read_text(encoding='utf-8-sig')
    pattern = re.compile(r'\treturn native\.(\w+)\(([^\n]*)\)')
    names = []

    def timed(match):
        name, args = match.groups()
        names.append(name)
        return ('\tvar bridge_start := Time.get_ticks_usec()\n'
                f'\tvar bridge_result = native.{name}({args})\n'
                f'\t_bridge_record("{name}", Time.get_ticks_usec()-bridge_start)\n'
                '\treturn bridge_result')

    updated = pattern.sub(timed, source)
    if len(names) < 70 or len(set(names)) != len(names):
        raise ValueError('Native forwarding surface changed')
    needle = '\tvar duration := Time.get_ticks_usec()-start\n'
    if updated.count(needle) != 1:
        raise ValueError('Canonical serializer timing site changed')
    updated = updated.replace(needle, needle + '\t_bridge_record("canonicalize_json_miss", duration)\n')
    updated += '''
var bridge_profile: Dictionary = {}

func _bridge_record(method: String, elapsed_us: int) -> void:
	var row: Dictionary = bridge_profile.get(method, {"calls":0,"total_us":0,"maximum_us":0})
	row.calls += 1
	row.total_us += elapsed_us
	row.maximum_us = maxi(row.maximum_us,elapsed_us)
	bridge_profile[method] = row
'''
    wrapper.write_text(updated, encoding='utf-8', newline='\n')

    transport = project / 'sdk/trace_analysis/godot_authoritative_json_transport.gd'
    source = transport.read_text(encoding='utf-8-sig')
    needle = '\treturn JSON.stringify(value, "", true, true)'
    if source.count(needle) != 1:
        raise ValueError('Authoritative stringify operation changed')
    source = source.replace(needle, '''	var start := Time.get_ticks_usec()
	var result := JSON.stringify(value, "", true, true)
	var elapsed := Time.get_ticks_usec()-start
	profile.calls += 1
	profile.total_us += elapsed
	profile.maximum_us = maxi(profile.maximum_us,elapsed)
	profile.characters += result.length()
	return result''')
    source += '\nstatic var profile: Dictionary = {"calls":0,"total_us":0,"maximum_us":0,"characters":0}\n'
    transport.write_text(source, encoding='utf-8', newline='\n')

    worker = project / 'sdk/explorer/native_recovery/worker.gd'
    source = worker.read_text(encoding='utf-8-sig')
    needle = '\tsuper._send(value)'
    if source.count(needle) != 1:
        raise ValueError('Diagnostic terminal hook changed')
    source = source.replace(needle, '''	if value.get("message_type")=="completed":
		value.summary["studio_native_bridge_profile"]=_sdk.bridge_profile.duplicate(true)
		value.summary["studio_json_stringify_profile"]=JsonTransportScript.profile.duplicate(true)
	super._send(value)''')
    worker.write_text(source, encoding='utf-8', newline='\n')
    return names

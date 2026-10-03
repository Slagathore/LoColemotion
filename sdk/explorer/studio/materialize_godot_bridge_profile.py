"""Instrument the isolated live diagnostic without changing calls or values.

The timers separate native SDK calls from Godot JSON serialization. This is a
development measurement only; the original scientific source is not edited.
"""
import re


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

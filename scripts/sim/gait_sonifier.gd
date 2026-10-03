class_name GaitSonifier
extends RefCounted

## M53 Toybox (FUN-3) — gait sonification. Maps locomotion telemetry to sound: stride cadence ->
## tempo, contacts -> percussion notes, cost-of-transport -> pitch (efficient = bright). A clean
## trot becomes a steady beat; a limp or skate sounds WRONG before you can see why — an at-a-glance
## health signal that's also delightful. These are the pure MAPPINGS (unit-tested); the actual
## AudioStreamGenerator playback (keyed off the M37 contact/slip channels) is play-tested.

const PENTATONIC: Array[int] = [0, 2, 4, 7, 9]   # major pentatonic scale degrees (semitones)
const ROOT_MIDI := 57                            # A3


# Stride frequency (Hz) -> musical tempo (BPM). One stride = one beat.
static func cadence_to_tempo(stride_hz: float) -> float:
	return clampf(stride_hz * 60.0, 30.0, 300.0)


# Cost-of-transport -> pitch (Hz). LOW cot (efficient) = bright/high; high cot = dull/low.
static func cot_to_pitch(cot: float) -> float:
	return clampf(880.0 / (1.0 + maxf(cot, 0.0)), 110.0, 880.0)


# A foot/contact index -> a MIDI note on the pentatonic scale (so any gait sounds musical).
static func contact_note(foot_index: int) -> int:
	var n := PENTATONIC.size()
	var octave := (foot_index / n) * 12
	return ROOT_MIDI + octave + PENTATONIC[posmod(foot_index, n)]


static func midi_to_hz(midi: int) -> float:
	return 440.0 * pow(2.0, (float(midi) - 69.0) / 12.0)


# Convenience: a compact "score" for a measured rollout (tempo + pitch), for an editor read-out.
static func score_for(measured: Dictionary) -> Dictionary:
	var horizon := maxf(float(measured.get("horizon_s", 1.0)), 0.001)
	# crude stride rate proxy: theta swings per second isn't stored, so use max_omega as a tempo cue
	var stride_hz := clampf(float(measured.get("max_omega", 1.0)) / TAU, 0.2, 5.0)
	return {
		"tempo_bpm": cadence_to_tempo(stride_hz),
		"pitch_hz": cot_to_pitch(float(measured.get("cost_of_transport", 1.0))),
	}

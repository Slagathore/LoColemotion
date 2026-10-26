"""Full native capture with row, stream and whole-attempt byte limits."""
import json
from actuation_recovery_mechanics import require

STREAMS=("controller","trace","timing","contact-force","contact-timing")


def append(stream,name,row,contract,population):
    require(name in STREAMS,"Sequence native capture stream")
    text=json.dumps(row,allow_nan=False,separators=(",",":"))+"\n"
    size=len(text.encode("utf-8"))
    require(size<=contract["maximum_controller_row_bytes"],"Sequence native row byte bound")
    require(stream.tell()+size<=contract["maximum_trace_bytes_per_trial"],"Sequence native stream byte bound")
    before=population["retained_stream_bytes"]
    require(type(before) is int and before>=0 and before+size<=contract["maximum_attempt_stream_bytes"],
        "Sequence native aggregate stream byte bound")
    require(stream.write(text)==len(text),"Sequence native complete row write")
    population["retained_stream_bytes"]=before+size

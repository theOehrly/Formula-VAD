import json
import os

from cffi import FFI


# baseline run plan
FILE = "tmp/plan_debug.json"


# define the Zig (C-like) interface
cffi = FFI()
cffi.cdef(
    """
      char* execute(char* plan_contents_c, char* base_path_c);

    """
)
simulator = cffi.dlopen(os.path.abspath("zig-out/lib/libsimulator.so"))


# print current PID to attach debugger for mixed-mode debugging
print(os.getpid())

# read and update baseline run plan
with open(FILE, "r") as fobj:
    content = fobj.read()

base_path = os.path.dirname(FILE)

config = json.loads(content)

config['config']['vad_config']['alt_vad_machine_configs'] = [
    {'speech_max_freq': 1000},
    {'speech_max_freq': 1500},
    {'speech_max_freq': 2000},
]

# run the simulator
r = simulator.execute(str.encode(json.dumps(config)), str.encode(base_path))

# try to parse results
data = json.loads(cffi.string(r).decode())
if 'error' in data:
    exit(1)
else:
    print(f"\nSimulation finished successfully")
    print([d['f_score'] for d in data['alt']])

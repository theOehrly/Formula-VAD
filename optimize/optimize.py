import json
import os

from cffi import FFI

import numpy as np

from pymoo.core.problem import Problem
from pymoo.algorithms.soo.nonconvex.ga import GA
from pymoo.optimize import minimize


# baseline run plan
FILE = "tmp/plan.json"


# define the Zig (C-like) interface
cffi = FFI()
cffi.cdef(
    """
      char* execute(char* plan_contents_c, char* base_path_c);

    """
)
simulator = cffi.dlopen(os.path.abspath("zig-out/lib/libsimulator.so"))


# read baseline run plan
with open(FILE, "r") as fobj:
    content = fobj.read()

base_path = os.path.dirname(FILE)

config = json.loads(content)


# ############ Set up the actual optimization #######################

class FScoreProblem(Problem):

    def __init__(self):
        super().__init__(n_var=5,
                         n_obj=1,
                         n_constr=0,
                         xl=np.array([50, 500, 2.1, 0.01, 1]),
                         xu=np.array([450, 2500, 500, 2.0, 200]))

    def _evaluate(self, x, out, *args, **kwargs):
        vad_conf = list()
        for i in range(len(x)):
            vad_conf.append(
                {'speech_min_freq': x[i, 0],
                 'speech_max_freq': x[i, 1],
                 'long_term_speech_avg_sec': x[i, 2],
                 'short_term_speech_avg_sec': x[i, 3],
                 'speech_threshold_factor': x[i, 4]}
            )

        config['config']['vad_config']['alt_vad_machine_configs'] = vad_conf

        r = simulator.execute(str.encode(json.dumps(config)), str.encode(base_path))
        s = cffi.string(r).decode()
        s = s.replace('-nan', 'NaN').replace('nan', 'NaN')  # fix mal-formatted NaN
        data = json.loads(s)
        if 'error' in data:
            raise ValueError("Simulation Failed")

        f_score = np.array([d['f_score'] for d in data['alt']])
        f1 = 1.0 - f_score
        # f1[np.isnan(f1)] = 1.0

        out["F"] = f1


problem = FScoreProblem()

algorithm = GA(
    pop_size=50,
    eliminate_duplicates=True)

res = minimize(problem,
               algorithm,
               seed=1,
               verbose=True)


print("Best solution found: \nX = %s\nF = %s" % (res.X, res.F))

import json
import re
from collections import deque
from typing import List
from pathlib import Path

from Resource import Resource
from Operation import Operation
from SiLagoBlock import SiLagoBlock

def _safe_name(value: str) -> str:
    """Make a string safe for filenames."""
    return re.sub(r'[^A-Za-z0-9_.-]+', '_', str(value)).strip('_')

class PowerCharacterizer():
    def __init__(self, epsilon=0, window=0, min_iters=0) -> None:
        self.epsilon = epsilon
        self.window = window
        self.min_iters = min_iters
        self.errors = deque(maxlen=window)

    def get_power(self, resource: dict, operation: Operation) -> float:
        """
        Return instantaneous power for a given resource executing an operation.
        Needs adapting to different simulation techniques.
        Currently supports vsim for activity dump and Innovus for post-layout power
        """
        power = InnovusParser()
        activity = resource.get("count", 1)
        return base_power * activity

    def characterize(self)-> None:
        N = block.valid_neighbor_topology
        for neighbor in N:
            D = neighbor["Design"]
            for operation in neighbor["Operations"]:
                for resource in operation.Resources:
                    output_dir = Path("./Output/power_reports")
                    output_dir.mkdir(parents=True, exist_ok=True)
                    filename = f"{_safe_name(resource.Name)}_{_safe_name(operation.Name)}.json"
                    Pr_op = 0 
                    k = 0
                    converged = False
                    while not converged:
                        Pinst = get_power(D,resource, op)
    
    def run(self, ops, arch)-> None:
        with open(arch, "r") as f:
            data = json.load(f)
        block = SiLagoBlock.load(data)

#                        Pr_op = update_running_average(Pr_op, Pinst, k)
#                        k += 1
#                        converged = tracker.update(Pinst, Pr_op)
#                        key = (
#                            s.name,
#                            tuple(neighbors),
#                            op.name,
#                            resource.get("name")
#                        )
#                    power_results[key] = Pr_op
#
#    def update(self, p_inst: float, p_avg: float) -> bool:
#        self.k += 1
#        if self.k <= self.min_iters:
#            return False
#
#        error = abs(p_inst - p_avg)
#        self.errors.append(error)
#
#        if len(self.errors) < self.window:
#            return False
#
#        return all(e < self.epsilon for e in self.errors)
#
#def update_running_average(prev_avg: float, new_value: float, k: int) -> float:
#    return (k * prev_avg + new_value) / (k + 1)

#    
#    power_char = PowerCharacterizer(block)
#    power_char.characterize()

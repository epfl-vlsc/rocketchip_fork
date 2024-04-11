#!/usr/bin/env python3
import re
import subprocess
from pathlib import Path
import typing
import argparse
import pandas as pd
import tarfile
import itertools
class Runner:
    def __init__(self, bin, args: typing.List[str]):
        self.args = args
        self.bin = bin
    def __parseResult__(self, lines: typing.List[str]):
        pfinish = r"Finished after (?P<CYCLES>\d+) cycles in (?P<TIME>\d+(\.\d+)?) seconds \((?P<RATE>\d+(\.\d+)?)\)"
        for ln in lines:
            # print(ln)
            m = re.match(pfinish, ln)
            if m:
                cylces = int(m["CYCLES"])
                t = float(m["TIME"])
                r = float(m["RATE"])
                return {"Cycles" : cylces, "Time": t, "Rate": r}
        return None
    def run(self, threads: int):
        numacores = "-C" + ','.join([str(x) for x in range(threads)])
        cmd = ["numactl", numacores, self.bin] + self.args
        print(f"Running: {' '.join(cmd)}")
        proc = subprocess.run(cmd, check=False, text=True, capture_output=True)
        print(proc.stdout)
        if proc.returncode == 0:
            return self.__parseResult__(proc.stdout.split("\n"))
        else:
            print(proc.stderr)
            print(proc.stderr)
            raise RuntimeError(f"Return code {proc.returncode}")
class Sim:
    def __init__(self, name):
        self.name = name
        self.df = pd.DataFrame(
            {
                'Config': pd.Series(dtype='str'),
                'Threads': pd.Series(dtype='int'),
                'Cycles': pd.Series(dtype='int'),
                'Time': pd.Series(dtype='float'),
                'Rate': pd.Series(dtype='float'),
            }
        )

    def run(self, rocket_size: int, rocket_cores: int, threads: int, args: typing.List[str]):
        config = f"Parendi{rocket_size}{rocket_cores}CoreConfig"
        binary_file = f"./{self.name}-freechips.rocketchip.system.{config}-{threads}t"
        try:
            results = Runner(binary_file, args).run(threads)
            self.df.loc[len(self.df)] = [
                config,
                threads,
                results["Cycles"],
                results["Time"],
                results["Rate"]
            ]
            self.df.to_string(f"{self.name}_run.txt")
        except RuntimeError as e:
            print(f"Run failed {e}")


if __name__ == "__main__":

    threads = [1, 2]
    rocket_cores = [1, 2]
    rocket_sizes = ["Big", "Small"]
    verilator = Sim("verilator")
    essent = Sim("essent")
    cases = itertools.product([verilator, essent], rocket_sizes, rocket_cores, threads)

    args = "+max-cycles=10000000 +binary=hex/mt-mm_16.hex".split(" ")
    for (sim, size, core, th) in cases:
        sim.run(size, core, th, args)






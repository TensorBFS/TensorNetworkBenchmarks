import json, math
import torch
import time
from copy import deepcopy
import pdb

def myeinsum(ixs, iy, tensors):
    uniquelabels = list(set(sum(ixs, start=[]) + iy))
    allow_ascii = list(range(65, 90)) + list(range(97, 122))
    labelmap = {l:chr(allow_ascii[i]) for i, l in enumerate(uniquelabels)}
    eins = ",".join(["".join([labelmap[l] for l in ix]) for ix in ixs]) + "->" + "".join([labelmap[l] for l in iy])
    return torch.einsum(eins, *tensors)

def contract_recur(tree:dict, inputs):
    if "args" in tree:
        tensors = [contract_recur(arg, inputs) for arg in tree["args"]]
        return myeinsum(tree["eins"]["ixs"], tree["eins"]["iy"], tensors)
    else:
        return inputs[tree["tensorindex"]-1]

def contract(tree:dict, inputs):
    labels = torch.unique(torch.tensor(sum(tree["inputs"], start=[]) + tree["output"]))
    return contract_recur(tree['tree'], inputs)

repeat_times = 10
device = 'cuda:0'

with open("tensornetwork.json", 'r') as f:
    optcode = json.load(f)

torch.cuda.synchronize(device)
mintime = math.inf
for _ in range(repeat_times):
    t0 = time.time()
    tensors = [(0.5**0.4)*torch.ones((2,) * len(ix), dtype=torch.float32, device=device) for ix in optcode["inputs"]]
    res = contract(optcode, tensors)
    torch.cuda.synchronize(device)
    t1 = time.time()
    mintime = min(mintime, t1-t0)
    print(res)
print("minimum time = ", mintime)

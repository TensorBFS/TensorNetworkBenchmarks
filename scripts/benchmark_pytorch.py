import json
import torch
import time
from copy import deepcopy

eqs = []
allow_ascii = list(range(65, 90)) + list(range(97, 122))
device = 'cuda:0'

def read_tree(tree):
    if not tree['isleaf']:
        eqs.append((tree['eins']['ixs'], tree['eins']['iy']))
        for branch in tree['args']:
            read_tree(branch)

def list_duplicates_of(seq,item):
    start_at = -1
    locs = []
    while True:
        try:
            loc = seq.index(item,start_at+1)
        except ValueError:
            break
        else:
            locs.append(loc)
            start_at = loc
    return locs

def pytorch_einsum(tensors, order, einsum_eqs):
    assert len(order) == len(einsum_eqs)
    for i in range(len(order)):
        m, n = order[i]
        eq = einsum_eqs[i]
        tensors[m] = torch.einsum(eq, tensors[m], tensors[n])
    return tensors[m]

with open("tensornetwork.json", 'r') as f:
    optcode = json.load(f)

inputs_eq = optcode['inputs']
tree = optcode['tree']
read_tree(tree)

einsum_eqs, order = [], []

inputs_eq_copy = deepcopy(inputs_eq)
for i in range(len(eqs)-1, -1, -1):
    bonds_i, bonds_j = eqs[i][0]
    bonds_result = eqs[i][1]
    if bonds_i != bonds_j:
        loc_a, loc_b = inputs_eq.index(bonds_i), inputs_eq.index(bonds_j)
    else:
        assert inputs_eq.count(bonds_i) == 2
        loc_a, loc_b = list_duplicates_of(inputs_eq, bonds_i)
    inputs_eq[loc_a] = bonds_result
    all_bonds = list(set(bonds_i) | set(bonds_j))
    eq_current = ''.join([chr(allow_ascii[all_bonds.index(bond)]) for bond in bonds_i]) + ',' + \
                 ''.join([chr(allow_ascii[all_bonds.index(bond)]) for bond in bonds_j]) + '->' + \
                 ''.join([chr(allow_ascii[all_bonds.index(bond)]) for bond in bonds_result])
    einsum_eqs.append(eq_current)
    order.append((loc_a, loc_b))

repeat_times = 10
torch.cuda.synchronize(device)
t0 = time.time()
for _ in range(repeat_times):
    tensors = [(0.5**0.4)*torch.ones((2,) * len(i), dtype=torch.float32, device=device) for i in inputs_eq_copy]
    res = pytorch_einsum(tensors, order, einsum_eqs)
    print(res)

torch.cuda.synchronize(device)
t1 = time.time()
print((t1 - t0) / repeat_times)

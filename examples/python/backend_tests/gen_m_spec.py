#!/usr/binenv python3
# usage gen_m_spec TESTS_DIR spec_filename all_ins_filename

import sys, os
from common import parse_test

import collections

def join(total, new):
    for x in new:
        if x in total:
            total[x][new[x]] += 1
        else:
            total[x] = collections.Counter([new[x]])

def get_test_distribution(test_dir):
    total_entrees = {}
    total_resultats = {}
    total_files = 0

    for x in os.listdir(test_dir):
        total_files += 1
        e, r = parse_test(f"{test_dir}/{x}")
        join(total_entrees, e)
        join(total_resultats, r)
    return total_entrees, total_resultats, total_files

def total_names(total):
    return sorted([x for (x, y) in total.items() if not x.startswith("V_")])

if __name__ == "__main__":
    test_dir = sys.argv[1]
    spec_filename = sys.argv[2]
    entrees_filename = sys.argv[3]
    total_entrees, total_resultats, total_files = get_test_distribution(test_dir)
    entrees = ", ".join(total_names(total_entrees))
    sorties = ", ".join(total_names(total_resultats))
    with open(spec_filename, 'w') as f:
        f.write(f"saisie: {entrees};\n\nconst: non;\n\ncondition:non;\n\nsortie:{sorties};")
    with open(entrees_filename, 'w') as f:
        f.write(entrees)

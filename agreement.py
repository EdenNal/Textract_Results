#!/usr/bin/env python3
"""Cell-by-cell AGREEMENT between Textract and the manual reference transcription.
Measures agreement with the reference, NOT validated accuracy.
Usage: python agreement.py <textract_dir> <manual_dir>"""
import csv, re, sys, os, glob, math

NUM_RE = re.compile(r'-?\d{1,3}(?:,\d{3})+$|-?\d+$')   # integer, optional thousands commas
PLACEHOLDERS = {'-', '..', '', '...'}

def is_numeric(s): return bool(NUM_RE.match(s.strip()))
def classify(m):
    m = m.strip()
    if is_numeric(m):     return 'numeric'
    if m in PLACEHOLDERS: return 'placeholder'
    return 'other'
def norm(s): return re.sub(r'(?<=\d),(?=\d)', '', s.strip())  # strip thousands separators only

def wilson(k, n, z=1.96):
    if n == 0: return (float('nan'),)*3
    p = k/n; d = 1 + z*z/n
    c = (p + z*z/(2*n))/d
    h = (z*math.sqrt(p*(1-p)/n + z*z/(4*n*n)))/d
    return p, c-h, c+h

def new_acc(): return dict(all_n=0,all_ex=0,all_nm=0,num_n=0,num_ex=0,num_nm=0,ph_n=0,ph_nm=0,struct=0)

def compare_pair(tx, man, a):
    for i in range(min(len(tx), len(man))):
        Td = tx[i][2:-1]  if len(tx[i])  >= 3 else []
        Md = man[i][2:-1] if len(man[i]) >= 3 else []
        if len(Td) != len(Md): a['struct'] += abs(len(Td)-len(Md))
        for j in range(min(len(Td), len(Md))):
            cls = classify(Md[j])
            ex = (Td[j].strip() == Md[j].strip())
            nm = (norm(Td[j]) == norm(Md[j]))
            a['all_n']+=1; a['all_ex']+=ex; a['all_nm']+=nm
            if cls=='numeric':      a['num_n']+=1; a['num_ex']+=ex; a['num_nm']+=nm
            elif cls=='placeholder': a['ph_n']+=1;  a['ph_nm']+=nm

def read_csv(p):
    with open(p, newline='', encoding='utf-8', errors='replace') as f:
        return list(csv.reader(f))

def report(name, a):
    def line(lbl,k,n):
        if not n: return f"  {lbl:30s}        -"
        p,lo,hi = wilson(k,n)
        return f"  {lbl:30s} {k:6d}/{n:<6d} {100*p:6.2f}%  [{100*lo:5.2f}, {100*hi:5.2f}]"
    print(f"\n=== {name} ===")
    print(line("Numeric cells, exact",       a['num_ex'], a['num_n']))
    print(line("Numeric cells, normalized",  a['num_nm'], a['num_n']))
    print(line("All data cells, exact",      a['all_ex'], a['all_n']))
    print(line("All data cells, normalized", a['all_nm'], a['all_n']))
    print(line("Placeholder cells, matched", a['ph_nm'],  a['ph_n']))
    print(f"  Structural (length-mismatch) cells: {a['struct']}")



def week_key(fname):
    """Pair on the non-year integers in the filename, so 'tx_1956_week1.csv'
    and 'manual_01.csv' both key to (1)."""
    ints = [int(x) for x in re.findall(r'\d+', os.path.basename(fname))
            if not (1900 <= int(x) <= 2099)]        # drop year-like tokens
    return tuple(ints) if ints else (os.path.basename(fname).lower(),)

def index_dir(d):
    entries = os.listdir(d) if os.path.isdir(d) else []
    csvs = [os.path.join(d, f) for f in entries if f.lower().endswith('.csv')]
    idx = {}
    for p in sorted(csvs): idx.setdefault(week_key(p), p)
    return idx, entries

def main(tx_dir, man_dir):
    tx, tx_all   = index_dir(tx_dir)
    man, man_all = index_dir(man_dir)
    print(f"textract: {len(tx_all)} entries, {len(tx)} csv | manual: {len(man_all)} entries, {len(man)} csv")
    if not tx:  print("  sample textract names:", tx_all[:6])
    if not man: print("  sample manual names:",   man_all[:6])
    common = sorted(set(tx) & set(man))
    print(f"paired: {len(common)}")
    if common and len(common) < max(len(tx), len(man)):
        print("  unmatched textract:", [os.path.basename(tx[k])  for k in sorted(set(tx)-set(man))][:8])
        print("  unmatched manual:  ", [os.path.basename(man[k]) for k in sorted(set(man)-set(tx))][:8])
    a = new_acc()
    for k in common:
        compare_pair(read_csv(tx[k]), read_csv(man[k]), a)
    report(f"{tx_dir} vs {man_dir}", a)

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])